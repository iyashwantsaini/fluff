import 'dart:async';

import 'package:fluff_ops/fluff_ops.dart';
import 'package:fluff_skin/fluff_skin.dart';
import 'package:fluff_vfs/fluff_vfs.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'conflict_dialog.dart';
import 'progress_sheet.dart';
import 'properties_dialog.dart';

enum _ClipboardKind { copy, cut }

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
  final VoidCallback onToggleBrightness;

  const BrowseScreen({
    super.key,
    required this.provider,
    required this.queue,
    required this.onToggleBrightness,
  });

  @override
  State<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends State<BrowseScreen> {
  late FsPath _cwd = widget.provider.root;
  late Future<List<FsNode>> _listing = widget.provider.list(_cwd);

  final Set<FsPath> _selected = {};
  _Clipboard? _clipboard;

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = WlmTheme.of(context).tokens;
    final width = MediaQuery.sizeOf(context).width;
    final gutter = tokens.spacing.pageGutter(width);

    final hasSelection = _selected.isNotEmpty;
    final hasClipboard = _clipboard != null;

    return Scaffold(
      appBar: _buildAppBar(theme, tokens, hasSelection),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!_searching && !hasSelection)
            _PathBreadcrumbs(path: _cwd, onTap: _navigate, gutter: gutter),
          if (_searching) _searchBar(theme, tokens, gutter),
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
                final items = (snap.data ?? const <FsNode>[])
                    .where(
                      (n) =>
                          _query.isEmpty ||
                          n.name.toLowerCase().contains(_query.toLowerCase()),
                    )
                    .toList();
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
                return ListView.separated(
                  padding: EdgeInsets.symmetric(
                    horizontal: gutter,
                    vertical: tokens.spacing.sm,
                  ),
                  itemBuilder: (_, i) {
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
                          _showProperties(n.path);
                        }
                      },
                      onLongPress: () => _toggleSelect(n.path),
                    );
                  },
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
          : null,
    );
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
          ? const _BrandMark()
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
