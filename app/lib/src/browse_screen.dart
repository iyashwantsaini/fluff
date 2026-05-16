import 'dart:async';

import 'package:fluff_ops/fluff_ops.dart';
import 'package:fluff_skin/fluff_skin.dart';
import 'package:fluff_vfs/fluff_vfs.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'conflict_dialog.dart';
import 'progress_sheet.dart';
import 'properties_dialog.dart';
import 'viewer_screen.dart';

enum _ClipboardKind { copy, cut }

enum _SortKey { name, size, modified, type }

enum _ViewMode { list, grid, gallery, details }

enum _FilterKind { all, folders, images, audio, video, docs, archives }

class _Clipboard {
  final _ClipboardKind kind;
  final List<FsPath> paths;
  final String providerId;
  const _Clipboard({
    required this.kind,
    required this.paths,
    required this.providerId,
  });
}

/// Phase 2 browse screen. Adds multi-select, copy / cut / paste / delete,
/// inline search, a properties dialog, a conflict dialog, and a bottom
/// progress sheet driven by [OperationQueue].
class BrowseScreen extends StatefulWidget {
  final FsProvider provider;
  final OperationQueue queue;
  final VoidCallback? onToggleBrightness;

  /// Optional left-side drawer (used by the top-level app shell to
  /// switch between Storage and Vault).
  final Widget? leadingDrawer;

  /// Optional extra widget appended to the AppBar `actions` (e.g.
  /// a "Lock vault" button when this screen is rendering an
  /// unlocked [VaultFsProvider]).
  final Widget? appBarSuffix;

  const BrowseScreen({
    super.key,
    required this.provider,
    required this.queue,
    this.onToggleBrightness,
    this.leadingDrawer,
    this.appBarSuffix,
  });

  @override
  State<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends State<BrowseScreen> {
  late FsPath _cwd = widget.provider.root;
  late Future<List<FsNode>> _listing = widget.provider.list(_cwd);

  final Set<FsPath> _selected = {};
  _Clipboard? _clipboard;

  _SortKey _sortKey = _SortKey.name;
  bool _sortAsc = true;
  _ViewMode _viewMode = _ViewMode.list;
  bool _showHidden = false;
  _FilterKind _filter = _FilterKind.all;

  bool _searching = false;
  String _query = '';
  final _searchCtrl = TextEditingController();

  List<Operation> _ops = const [];
  OperationProgress? _latestProgress;

  StreamSubscription<List<Operation>>? _opsSub;
  StreamSubscription<OperationProgress>? _progressSub;
  StreamSubscription<Conflict>? _conflictsSub;

  bool _conflictShown = false;

  @override
  void initState() {
    super.initState();
    _opsSub = widget.queue.operationStream.listen((ops) {
      setState(() => _ops = ops);
      _refresh();
    });
    _progressSub = widget.queue.progress.listen((p) {
      setState(() => _latestProgress = p);
    });
    _conflictsSub = widget.queue.conflicts.listen(_handleConflict);
    if (kIsWeb) _applyDemoUrl();
  }

  /// Seed UI state from query parameters so screenshot harnesses can
  /// land on a specific view without clicking through the whole flow.
  /// Recognised keys: cwd, sel, search, props, conflict, clip, fakeOp.
  void _applyDemoUrl() {
    final q = Uri.base.queryParameters;
    if (q.isEmpty) return;
    final cwdRaw = q['cwd'];
    final cwd = (cwdRaw == null || cwdRaw.isEmpty)
        ? widget.provider.root
        : FsPath.parse(cwdRaw);
    _cwd = cwd;
    _listing = widget.provider.list(_cwd);
    final sel = q['sel'];
    if (sel != null && sel.isNotEmpty) {
      for (final name in sel.split(',')) {
        _selected.add(_cwd.child(name));
      }
    }
    final search = q['search'];
    if (search != null) {
      _searching = true;
      _query = search;
      _searchCtrl.text = search;
    }
    final clip = q['clip'];
    if (clip != null && clip.isNotEmpty) {
      _clipboard = _Clipboard(
        kind: clip == 'cut' ? _ClipboardKind.cut : _ClipboardKind.copy,
        paths: [_cwd.child('Documents'), _cwd.child('Music')],
        providerId: widget.provider.id,
      );
    }
    final props = q['props'];
    if (props != null && props.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showProperties(_cwd.child(props));
      });
    }
    final conflict = q['conflict'];
    if (conflict != null && conflict.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleConflict(
          Conflict(
            operationId: '#demo',
            source: FsPath.parse('/Documents/$conflict'),
            destination: _cwd.child(conflict),
          ),
        );
      });
    }
    final fakeOp = q['fakeOp'];
    if (fakeOp != null && fakeOp.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          _ops = [
            Operation(
              id: '#demo',
              kind: OperationKind.copy,
              sources: [
                FsPath.parse('/Documents/notes.txt'),
                FsPath.parse('/Documents/budget.csv'),
                FsPath.parse('/Music/track.mp3'),
              ],
              providerId: widget.provider.id,
              destination: _cwd,
              status: OperationStatus.running,
            ),
          ];
          _latestProgress = const OperationProgress(
            id: '#demo',
            itemsDone: 2,
            itemsTotal: 3,
            bytesDone: 1450240,
            bytesTotal: 2100480,
            currentItem: '/Music/track.mp3',
          );
        });
      });
    }
  }

  @override
  void dispose() {
    _opsSub?.cancel();
    _progressSub?.cancel();
    _conflictsSub?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _refresh() {
    setState(() {
      _listing = widget.provider.list(_cwd);
    });
  }

  void _navigate(FsPath path) {
    setState(() {
      _cwd = path;
      _selected.clear();
      _searching = false;
      _query = '';
      _searchCtrl.clear();
      _listing = widget.provider.list(path);
    });
  }

  void _toggleSelect(FsPath p) {
    setState(() {
      if (!_selected.add(p)) _selected.remove(p);
    });
  }

  Future<void> _handleConflict(Conflict c) async {
    if (_conflictShown) return;
    _conflictShown = true;
    final choice = await showDialog<ConflictChoice>(
      context: context,
      builder: (_) => ConflictDialog(conflict: c),
    );
    _conflictShown = false;
    if (choice == null) return;
    widget.queue.defaultPolicy = switch (choice) {
      ConflictChoice.overwrite => ConflictPolicy.overwrite,
      ConflictChoice.skip => ConflictPolicy.skip,
      ConflictChoice.renameAuto => ConflictPolicy.renameAuto,
    };
  }

  Future<void> _showProperties(FsPath p) async {
    final node = await widget.provider.stat(p);
    if (node == null || !mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => PropertiesDialog(node: node, provider: widget.provider),
    );
  }

  void _enqueueDelete() {
    if (_selected.isEmpty) return;
    widget.queue.enqueue(
      kind: OperationKind.delete,
      sources: _selected.toList(),
      providerId: widget.provider.id,
    );
    setState(_selected.clear);
  }

  void _copyToClipboard(_ClipboardKind kind) {
    if (_selected.isEmpty) return;
    setState(() {
      _clipboard = _Clipboard(
        kind: kind,
        paths: _selected.toList(),
        providerId: widget.provider.id,
      );
      _selected.clear();
    });
  }

  void _paste() {
    final c = _clipboard;
    if (c == null) return;
    widget.queue.enqueue(
      kind: c.kind == _ClipboardKind.copy
          ? OperationKind.copy
          : OperationKind.move,
      sources: c.paths,
      providerId: c.providerId,
      destination: _cwd,
    );
    if (c.kind == _ClipboardKind.cut) {
      setState(() => _clipboard = null);
    }
  }

  void _openFile(FsNode node) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ViewerScreen(
          provider: widget.provider,
          path: node.path,
          onToggleBrightness: widget.onToggleBrightness,
        ),
      ),
    );
  }

  Future<void> _newFolder() => _createDialog(initialIsFolder: true);

  Future<void> _createDialog({required bool initialIsFolder}) async {
    var isFolder = initialIsFolder;
    final nameCtrl = TextEditingController(
      text: isFolder ? 'New folder' : 'untitled',
    );
    String ext = 'txt';
    const exts = <String>[
      'txt',
      'md',
      'json',
      'yaml',
      'xml',
      'csv',
      'log',
      'sh',
      'ps1',
      'dart',
      'kt',
      'py',
      'js',
      'ts',
      'html',
      'css',
    ];
    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Create new'),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(
                      value: true,
                      label: Text('Folder'),
                      icon: Icon(Icons.create_new_folder_outlined),
                    ),
                    ButtonSegment(
                      value: false,
                      label: Text('File'),
                      icon: Icon(Icons.note_add_outlined),
                    ),
                  ],
                  selected: {isFolder},
                  onSelectionChanged: (s) => setLocal(() {
                    isFolder = s.first;
                    nameCtrl.text = isFolder ? 'New folder' : 'untitled';
                  }),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: nameCtrl,
                        autofocus: true,
                        decoration: InputDecoration(
                          labelText: isFolder ? 'Folder name' : 'File name',
                          isDense: true,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                    if (!isFolder) ...[
                      const SizedBox(width: 8),
                      const Text('.'),
                      const SizedBox(width: 4),
                      DropdownButton<String>(
                        value: ext,
                        items: [
                          for (final e in exts)
                            DropdownMenuItem(value: e, child: Text(e)),
                        ],
                        onChanged: (v) => setLocal(() => ext = v ?? 'txt'),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final raw = nameCtrl.text.trim();
                if (raw.isEmpty) {
                  Navigator.of(ctx).pop(false);
                  return;
                }
                final fullName = isFolder ? raw : '$raw.$ext';
                final target = _cwd.child(fullName);
                try {
                  if (isFolder) {
                    await widget.provider.mkdir(target);
                  } else {
                    await widget.provider.writeBytes(target, Uint8List(0));
                  }
                  if (ctx.mounted) Navigator.of(ctx).pop(true);
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text('Could not create: $e')),
                    );
                  }
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
    if (created == true) _refresh();
  }

  List<FsNode> _applyViewPrefs(List<FsNode> input) {
    final filtered = input.where((n) => _showHidden || !n.name.startsWith('.'));
    final kindFiltered = filtered.where((n) => _matchesFilter(n));
    final searched = kindFiltered.where(
      (n) =>
          _query.isEmpty || n.name.toLowerCase().contains(_query.toLowerCase()),
    );
    final list = searched.toList()
      ..sort((a, b) {
        // Always group folders first.
        if (a.isDirectory != b.isDirectory) {
          return a.isDirectory ? -1 : 1;
        }
        final cmp = switch (_sortKey) {
          _SortKey.name => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          _SortKey.size => a.size.compareTo(b.size),
          _SortKey.modified =>
            (a.modified ?? DateTime.fromMillisecondsSinceEpoch(0)).compareTo(
              b.modified ?? DateTime.fromMillisecondsSinceEpoch(0),
            ),
          _SortKey.type => _extOf(a.name).compareTo(_extOf(b.name)),
        };
        return _sortAsc ? cmp : -cmp;
      });
    return list;
  }

  static String _extOf(String name) {
    final i = name.lastIndexOf('.');
    return i < 0 ? '' : name.substring(i + 1).toLowerCase();
  }

  bool _matchesFilter(FsNode n) {
    if (_filter == _FilterKind.all) return true;
    if (n.isDirectory) return _filter == _FilterKind.folders;
    final ext = _extOf(n.name);
    return switch (_filter) {
      _FilterKind.images => {
        'jpg',
        'jpeg',
        'png',
        'gif',
        'webp',
        'bmp',
        'svg',
        'heic',
      }.contains(ext),
      _FilterKind.audio => {
        'mp3',
        'flac',
        'ogg',
        'wav',
        'm4a',
        'opus',
        'aac',
      }.contains(ext),
      _FilterKind.video => {
        'mp4',
        'mkv',
        'webm',
        'mov',
        'avi',
        '3gp',
      }.contains(ext),
      _FilterKind.docs => {
        'pdf',
        'epub',
        'md',
        'markdown',
        'txt',
        'doc',
        'docx',
        'odt',
      }.contains(ext),
      _FilterKind.archives => {
        'zip',
        'tar',
        'gz',
        '7z',
        'rar',
        'apk',
        'jar',
        'aar',
      }.contains(ext),
      _ => true,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = WlmTheme.of(context).tokens;
    final width = MediaQuery.sizeOf(context).width;
    final gutter = tokens.spacing.pageGutter(width);

    final hasSelection = _selected.isNotEmpty;
    final hasClipboard = _clipboard != null;

    return Scaffold(
      drawer: widget.leadingDrawer,
      appBar: _buildAppBar(theme, tokens, hasSelection),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!_searching && !hasSelection)
            _PathBreadcrumbs(path: _cwd, onTap: _navigate, gutter: gutter),
          if (_searching) _searchBar(theme, tokens, gutter),
          if (!hasSelection) _filterChips(theme, tokens, gutter),
          if (hasClipboard && !hasSelection && !_searching)
            _clipboardBanner(theme, tokens, gutter),
          const Divider(height: 1),
          Expanded(
            child: FutureBuilder<List<FsNode>>(
              future: _listing,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(
                    child: Padding(
                      padding: EdgeInsets.all(gutter),
                      child: Text(
                        'Error: ${snap.error}',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  );
                }
                final items = _applyViewPrefs(snap.data ?? const <FsNode>[]);
                if (items.isEmpty) {
                  return Center(
                    child: Text(
                      _query.isEmpty
                          ? 'Empty folder'
                          : 'No matches for "$_query"',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  );
                }
                Widget tile(int i) {
                  final n = items[i];
                  final isSelected = _selected.contains(n.path);
                  return _FsNodeTile(
                    node: n,
                    selected: isSelected,
                    selectionActive: hasSelection,
                    onTap: () {
                      if (hasSelection) {
                        _toggleSelect(n.path);
                      } else if (n.isDirectory) {
                        _navigate(n.path);
                      } else {
                        _openFile(n);
                      }
                    },
                    onLongPress: () => _toggleSelect(n.path),
                  );
                }

                if (_viewMode == _ViewMode.grid) {
                  final width = MediaQuery.of(context).size.width;
                  final crossAxisCount = (width / 200).floor().clamp(2, 6);
                  return GridView.builder(
                    padding: EdgeInsets.symmetric(
                      horizontal: gutter,
                      vertical: tokens.spacing.sm,
                    ),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: tokens.spacing.sm,
                      mainAxisSpacing: tokens.spacing.sm,
                      mainAxisExtent: 76,
                    ),
                    itemCount: items.length,
                    itemBuilder: (_, i) => tile(i),
                  );
                }
                if (_viewMode == _ViewMode.gallery) {
                  final width = MediaQuery.of(context).size.width;
                  final crossAxisCount = (width / 140).floor().clamp(2, 8);
                  return GridView.builder(
                    padding: EdgeInsets.symmetric(
                      horizontal: gutter,
                      vertical: tokens.spacing.sm,
                    ),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: tokens.spacing.sm,
                      mainAxisSpacing: tokens.spacing.sm,
                      childAspectRatio: 0.9,
                    ),
                    itemCount: items.length,
                    itemBuilder: (_, i) {
                      final n = items[i];
                      final isSelected = _selected.contains(n.path);
                      return _GalleryTile(
                        node: n,
                        selected: isSelected,
                        onTap: () {
                          if (hasSelection) {
                            _toggleSelect(n.path);
                          } else if (n.isDirectory) {
                            _navigate(n.path);
                          } else {
                            _openFile(n);
                          }
                        },
                        onLongPress: () => _toggleSelect(n.path),
                      );
                    },
                  );
                }
                if (_viewMode == _ViewMode.details) {
                  return _DetailsTable(
                    items: items,
                    selected: _selected,
                    selectionActive: hasSelection,
                    onTap: (n) {
                      if (hasSelection) {
                        _toggleSelect(n.path);
                      } else if (n.isDirectory) {
                        _navigate(n.path);
                      } else {
                        _openFile(n);
                      }
                    },
                    onLongPress: (n) => _toggleSelect(n.path),
                    onProperties: _showProperties,
                  );
                }
                return ListView.separated(
                  padding: EdgeInsets.symmetric(
                    horizontal: gutter,
                    vertical: tokens.spacing.sm,
                  ),
                  itemBuilder: (_, i) => tile(i),
                  separatorBuilder: (_, _) =>
                      SizedBox(height: tokens.spacing.xs),
                  itemCount: items.length,
                );
              },
            ),
          ),
          ProgressSheet(operations: _ops, latest: _latestProgress),
        ],
      ),
      floatingActionButton: hasClipboard && !hasSelection && !_searching
          ? FloatingActionButton.extended(
              onPressed: _paste,
              icon: const Icon(Icons.content_paste_go_rounded),
              label: Text(
                _clipboard!.kind == _ClipboardKind.copy
                    ? 'Paste here'
                    : 'Move here',
              ),
            )
          : (!hasSelection && !_searching
                ? FloatingActionButton(
                    onPressed: _newFolder,
                    tooltip: 'New folder',
                    child: const Icon(Icons.create_new_folder_outlined),
                  )
                : null),
    );
  }

  void _handleMenu(String value) {
    switch (value) {
      case 'new':
        _newFolder();
      case 'newfile':
        _createDialog(initialIsFolder: false);
      case 'refresh':
        _refresh();
      case 'hidden':
        setState(() => _showHidden = !_showHidden);
      case 'sort-name':
        setState(() {
          if (_sortKey == _SortKey.name) {
            _sortAsc = !_sortAsc;
          } else {
            _sortKey = _SortKey.name;
            _sortAsc = true;
          }
        });
      case 'sort-size':
        setState(() {
          if (_sortKey == _SortKey.size) {
            _sortAsc = !_sortAsc;
          } else {
            _sortKey = _SortKey.size;
            _sortAsc = false;
          }
        });
      case 'sort-modified':
        setState(() {
          if (_sortKey == _SortKey.modified) {
            _sortAsc = !_sortAsc;
          } else {
            _sortKey = _SortKey.modified;
            _sortAsc = false;
          }
        });
      case 'sort-type':
        setState(() {
          if (_sortKey == _SortKey.type) {
            _sortAsc = !_sortAsc;
          } else {
            _sortKey = _SortKey.type;
            _sortAsc = true;
          }
        });
    }
  }

  PreferredSizeWidget _buildAppBar(
    ThemeData theme,
    WlmTokens tokens,
    bool hasSelection,
  ) {
    if (hasSelection) {
      return AppBar(
        backgroundColor: theme.colorScheme.surfaceContainerHigh,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          tooltip: 'Clear selection',
          onPressed: () => setState(_selected.clear),
        ),
        title: Text('${_selected.length} selected'),
        actions: [
          IconButton(
            icon: const Icon(Icons.content_copy_rounded),
            tooltip: 'Copy',
            onPressed: () => _copyToClipboard(_ClipboardKind.copy),
          ),
          IconButton(
            icon: const Icon(Icons.content_cut_rounded),
            tooltip: 'Cut',
            onPressed: () => _copyToClipboard(_ClipboardKind.cut),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            tooltip: 'Delete',
            onPressed: _enqueueDelete,
          ),
          IconButton(
            icon: const Icon(Icons.info_outline_rounded),
            tooltip: 'Properties',
            onPressed: _selected.length == 1
                ? () => _showProperties(_selected.first)
                : null,
          ),
          SizedBox(width: tokens.spacing.xs),
        ],
      );
    }
    return AppBar(
      leading: _cwd.isRoot
          ? (widget.leadingDrawer != null
                ? Builder(
                    builder: (ctx) => IconButton(
                      icon: const Icon(Icons.menu_rounded),
                      tooltip: 'Menu',
                      onPressed: () => Scaffold.of(ctx).openDrawer(),
                    ),
                  )
                : const _BrandMark())
          : IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              tooltip: 'Up',
              onPressed: () => _navigate(_cwd.parent),
            ),
      title: Text(_cwd.isRoot ? widget.provider.displayName : _cwd.name),
      actions: [
        IconButton(
          icon: Icon(_searching ? Icons.close_rounded : Icons.search_rounded),
          tooltip: _searching ? 'Close search' : 'Search',
          onPressed: () => setState(() {
            _searching = !_searching;
            if (!_searching) {
              _query = '';
              _searchCtrl.clear();
            }
          }),
        ),
        PopupMenuButton<_ViewMode>(
          tooltip: 'View mode',
          initialValue: _viewMode,
          icon: Icon(switch (_viewMode) {
            _ViewMode.list => Icons.view_list_rounded,
            _ViewMode.grid => Icons.grid_view_rounded,
            _ViewMode.gallery => Icons.photo_library_outlined,
            _ViewMode.details => Icons.table_rows_rounded,
          }),
          onSelected: (m) => setState(() => _viewMode = m),
          itemBuilder: (_) => const [
            PopupMenuItem(
              value: _ViewMode.list,
              child: ListTile(
                leading: Icon(Icons.view_list_rounded),
                title: Text('List'),
                dense: true,
              ),
            ),
            PopupMenuItem(
              value: _ViewMode.grid,
              child: ListTile(
                leading: Icon(Icons.grid_view_rounded),
                title: Text('Grid'),
                dense: true,
              ),
            ),
            PopupMenuItem(
              value: _ViewMode.gallery,
              child: ListTile(
                leading: Icon(Icons.photo_library_outlined),
                title: Text('Gallery'),
                dense: true,
              ),
            ),
            PopupMenuItem(
              value: _ViewMode.details,
              child: ListTile(
                leading: Icon(Icons.table_rows_rounded),
                title: Text('Details'),
                dense: true,
              ),
            ),
          ],
        ),
        PopupMenuButton<String>(
          tooltip: 'More',
          icon: const Icon(Icons.more_vert_rounded),
          onSelected: _handleMenu,
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'new', child: Text('New folder')),
            const PopupMenuItem(value: 'newfile', child: Text('New file…')),
            const PopupMenuItem(value: 'refresh', child: Text('Refresh')),
            const PopupMenuDivider(),
            CheckedPopupMenuItem(
              value: 'hidden',
              checked: _showHidden,
              child: const Text('Show hidden'),
            ),
            const PopupMenuDivider(),
            PopupMenuItem(
              value: 'sort-name',
              child: Row(
                children: [
                  Icon(
                    _sortKey == _SortKey.name
                        ? (_sortAsc
                              ? Icons.arrow_upward_rounded
                              : Icons.arrow_downward_rounded)
                        : Icons.sort_by_alpha_rounded,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  const Text('Sort by name'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'sort-size',
              child: Row(
                children: [
                  Icon(
                    _sortKey == _SortKey.size
                        ? (_sortAsc
                              ? Icons.arrow_upward_rounded
                              : Icons.arrow_downward_rounded)
                        : Icons.straighten_rounded,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  const Text('Sort by size'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'sort-modified',
              child: Row(
                children: [
                  Icon(
                    _sortKey == _SortKey.modified
                        ? (_sortAsc
                              ? Icons.arrow_upward_rounded
                              : Icons.arrow_downward_rounded)
                        : Icons.schedule_rounded,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  const Text('Sort by modified'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'sort-type',
              child: Row(
                children: [
                  Icon(
                    _sortKey == _SortKey.type
                        ? (_sortAsc
                              ? Icons.arrow_upward_rounded
                              : Icons.arrow_downward_rounded)
                        : Icons.category_outlined,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  const Text('Sort by type'),
                ],
              ),
            ),
          ],
        ),
        if (widget.appBarSuffix != null) widget.appBarSuffix!,
        if (widget.onToggleBrightness != null)
          IconButton(
            icon: const Icon(Icons.brightness_6_outlined),
            tooltip: 'Toggle brightness',
            onPressed: widget.onToggleBrightness,
          ),
        SizedBox(width: tokens.spacing.xs),
      ],
    );
  }

  Widget _searchBar(ThemeData theme, WlmTokens tokens, double gutter) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        gutter,
        tokens.spacing.sm,
        gutter,
        tokens.spacing.sm,
      ),
      child: TextField(
        controller: _searchCtrl,
        autofocus: true,
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.search_rounded),
          hintText: 'Search in ${_cwd.isRoot ? "/" : _cwd.name}',
          isDense: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(tokens.radius.md),
          ),
        ),
        onChanged: (v) => setState(() => _query = v),
      ),
    );
  }

  Widget _clipboardBanner(ThemeData theme, WlmTokens tokens, double gutter) {
    final c = _clipboard!;
    final scheme = theme.colorScheme;
    return Container(
      color: scheme.surfaceContainer,
      padding: EdgeInsets.symmetric(
        horizontal: gutter,
        vertical: tokens.spacing.sm,
      ),
      child: Row(
        children: [
          Icon(
            c.kind == _ClipboardKind.copy
                ? Icons.content_copy_rounded
                : Icons.content_cut_rounded,
            size: 16,
            color: scheme.onSurfaceVariant,
          ),
          SizedBox(width: tokens.spacing.sm),
          Expanded(
            child: Text(
              '${c.paths.length} item(s) ready to '
              '${c.kind == _ClipboardKind.copy ? "copy" : "move"}',
              style: theme.textTheme.labelSmall,
            ),
          ),
          TextButton(
            onPressed: () => setState(() => _clipboard = null),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Widget _filterChips(ThemeData theme, WlmTokens tokens, double gutter) {
    const all = <(_FilterKind, String, IconData)>[
      (_FilterKind.all, 'All', Icons.apps_rounded),
      (_FilterKind.folders, 'Folders', Icons.folder_outlined),
      (_FilterKind.images, 'Images', Icons.image_outlined),
      (_FilterKind.audio, 'Audio', Icons.music_note_outlined),
      (_FilterKind.video, 'Video', Icons.movie_outlined),
      (_FilterKind.docs, 'Docs', Icons.description_outlined),
      (_FilterKind.archives, 'Archives', Icons.folder_zip_outlined),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(
        horizontal: gutter,
        vertical: tokens.spacing.xs,
      ),
      child: Row(
        children: [
          for (final (kind, label, icon) in all) ...[
            ChoiceChip(
              avatar: Icon(icon, size: 16),
              label: Text(label),
              selected: _filter == kind,
              onSelected: (_) => setState(() => _filter = kind),
              visualDensity: VisualDensity.compact,
            ),
            SizedBox(width: tokens.spacing.xs),
          ],
        ],
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = WlmTheme.of(context).tokens;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: tokens.spacing.lg),
      child: Center(
        child: Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: scheme.primary,
            borderRadius: BorderRadius.circular(tokens.radius.sm),
          ),
          alignment: Alignment.center,
          child: Text(
            'f',
            style: TextStyle(
              color: scheme.onPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 16,
              height: 1.0,
            ),
          ),
        ),
      ),
    );
  }
}

class _PathBreadcrumbs extends StatelessWidget {
  final FsPath path;
  final ValueChanged<FsPath> onTap;
  final double gutter;

  const _PathBreadcrumbs({
    required this.path,
    required this.onTap,
    required this.gutter,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = WlmTheme.of(context).tokens;
    final segments = <_Crumb>[];
    segments.add(_Crumb(label: '/', path: FsPath.root));
    var cur = FsPath.root;
    final parts = path.toString().split('/').where((s) => s.isNotEmpty);
    for (final s in parts) {
      cur = cur.child(s);
      segments.add(_Crumb(label: s, path: cur));
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(
        horizontal: gutter,
        vertical: tokens.spacing.sm,
      ),
      child: Row(
        children: [
          for (var i = 0; i < segments.length; i++) ...[
            InkWell(
              onTap: () => onTap(segments[i].path),
              borderRadius: BorderRadius.circular(tokens.radius.sm),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: tokens.spacing.sm,
                  vertical: tokens.spacing.xs,
                ),
                child: Text(
                  segments[i].label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: i == segments.length - 1
                        ? theme.colorScheme.onSurface
                        : theme.colorScheme.onSurfaceVariant,
                    fontWeight: i == segments.length - 1
                        ? FontWeight.w600
                        : FontWeight.w500,
                  ),
                ),
              ),
            ),
            if (i < segments.length - 1)
              Icon(
                Icons.chevron_right_rounded,
                size: 16,
                color: theme.colorScheme.outline,
              ),
          ],
        ],
      ),
    );
  }
}

class _Crumb {
  final String label;
  final FsPath path;
  _Crumb({required this.label, required this.path});
}

class _FsNodeTile extends StatelessWidget {
  final FsNode node;
  final bool selected;
  final bool selectionActive;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _FsNodeTile({
    required this.node,
    required this.selected,
    required this.selectionActive,
    required this.onTap,
    required this.onLongPress,
  });

  IconData get _icon {
    if (node.isDirectory) return Icons.folder_rounded;
    final mime = node.mimeType ?? '';
    if (mime.startsWith('image/')) return Icons.image_outlined;
    if (mime.startsWith('audio/')) return Icons.music_note_outlined;
    if (mime.startsWith('video/')) return Icons.movie_outlined;
    if (mime == 'application/pdf') return Icons.picture_as_pdf_outlined;
    if (mime.startsWith('text/')) return Icons.description_outlined;
    return Icons.insert_drive_file_outlined;
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _formatDate(DateTime? d) {
    if (d == null) return '';
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$mm-$dd';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tokens = WlmTheme.of(context).tokens;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(tokens.radius.md),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: tokens.spacing.md,
            vertical: tokens.spacing.md,
          ),
          decoration: BoxDecoration(
            border: Border.all(
              color: selected ? scheme.primary : scheme.outlineVariant,
              width: selected ? 1.5 : 1,
            ),
            borderRadius: BorderRadius.circular(tokens.radius.md),
            color: selected
                ? scheme.primaryContainer.withValues(alpha: 0.35)
                : scheme.surfaceContainerLow,
          ),
          child: Row(
            children: [
              if (selectionActive)
                Padding(
                  padding: EdgeInsets.only(right: tokens.spacing.sm),
                  child: Icon(
                    selected
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked,
                    size: 20,
                    color: selected ? scheme.primary : scheme.outline,
                  ),
                ),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(tokens.radius.sm),
                ),
                alignment: Alignment.center,
                child: Icon(_icon, size: 20, color: scheme.onSurfaceVariant),
              ),
              SizedBox(width: tokens.spacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      node.name,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: tokens.spacing.xs / 2),
                    Text(
                      node.isDirectory
                          ? _formatDate(node.modified)
                          : '${_formatSize(node.size)}'
                                '${node.modified != null ? '  ·  ${_formatDate(node.modified)}' : ''}',
                      style: theme.textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
              if (node.isDirectory && !selectionActive)
                Icon(
                  Icons.chevron_right_rounded,
                  color: scheme.outline,
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GalleryTile extends StatelessWidget {
  final FsNode node;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _GalleryTile({
    required this.node,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
  });

  IconData get _icon {
    if (node.isDirectory) return Icons.folder_rounded;
    final ext = node.name.contains('.')
        ? node.name.split('.').last.toLowerCase()
        : '';
    if ({'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'svg'}.contains(ext)) {
      return Icons.image_rounded;
    }
    if ({'mp4', 'mkv', 'webm', 'mov'}.contains(ext)) return Icons.movie_rounded;
    if ({'mp3', 'flac', 'ogg', 'wav', 'm4a'}.contains(ext)) {
      return Icons.music_note_rounded;
    }
    if (ext == 'pdf') return Icons.picture_as_pdf_rounded;
    if ({'apk', 'zip', 'jar'}.contains(ext)) return Icons.folder_zip_rounded;
    return Icons.insert_drive_file_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tokens = WlmTheme.of(context).tokens;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(tokens.radius.md),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: selected ? cs.primary : cs.outlineVariant,
              width: selected ? 1.5 : 1,
            ),
            borderRadius: BorderRadius.circular(tokens.radius.md),
            color: selected
                ? cs.primaryContainer.withValues(alpha: 0.35)
                : cs.surfaceContainerLow,
          ),
          padding: EdgeInsets.all(tokens.spacing.sm),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Expanded(
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(tokens.radius.sm),
                  ),
                  child: Icon(_icon, size: 44, color: cs.onSurfaceVariant),
                ),
              ),
              SizedBox(height: tokens.spacing.xs),
              Text(
                node.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelSmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailsTable extends StatelessWidget {
  final List<FsNode> items;
  final Set<FsPath> selected;
  final bool selectionActive;
  final ValueChanged<FsNode> onTap;
  final ValueChanged<FsNode> onLongPress;
  final ValueChanged<FsPath> onProperties;

  const _DetailsTable({
    required this.items,
    required this.selected,
    required this.selectionActive,
    required this.onTap,
    required this.onLongPress,
    required this.onProperties,
  });

  String _kb(int b) {
    if (b < 1024) return '$b B';
    if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)} KB';
    return '${(b / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _date(DateTime? d) {
    if (d == null) return '—';
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  String _type(FsNode n) {
    if (n.isDirectory) return 'folder';
    final i = n.name.lastIndexOf('.');
    return i < 0 ? 'file' : n.name.substring(i + 1).toLowerCase();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Scrollbar(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: MediaQuery.sizeOf(context).width,
          ),
          child: DataTable(
            headingTextStyle: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: cs.onSurfaceVariant,
            ),
            dataRowMinHeight: 36,
            dataRowMaxHeight: 44,
            showCheckboxColumn: false,
            columns: const [
              DataColumn(label: Text('Name')),
              DataColumn(label: Text('Type')),
              DataColumn(label: Text('Size'), numeric: true),
              DataColumn(label: Text('Modified')),
              DataColumn(label: Text('')),
            ],
            rows: [
              for (final n in items)
                DataRow(
                  selected: selected.contains(n.path),
                  onSelectChanged: (_) => onTap(n),
                  cells: [
                    DataCell(
                      Row(
                        children: [
                          Icon(
                            n.isDirectory
                                ? Icons.folder_outlined
                                : Icons.insert_drive_file_outlined,
                            size: 16,
                            color: cs.onSurfaceVariant,
                          ),
                          const SizedBox(width: 8),
                          Text(n.name),
                        ],
                      ),
                      onLongPress: () => onLongPress(n),
                    ),
                    DataCell(Text(_type(n))),
                    DataCell(Text(n.isDirectory ? '—' : _kb(n.size))),
                    DataCell(Text(_date(n.modified))),
                    DataCell(
                      IconButton(
                        icon: const Icon(Icons.info_outline_rounded, size: 18),
                        tooltip: 'Properties',
                        onPressed: () => onProperties(n.path),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
