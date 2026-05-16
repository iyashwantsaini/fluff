import 'package:fluff_skin/fluff_skin.dart';
import 'package:fluff_vfs/fluff_vfs.dart';
import 'package:flutter/material.dart';

/// Phase 1 browse screen. Lists the contents of the current
/// directory inside a single [FsProvider]. No multi-tab, no toolbar
/// actions yet — those land in Phase 2.
class BrowseScreen extends StatefulWidget {
  final FsProvider provider;
  final VoidCallback onToggleBrightness;

  const BrowseScreen({
    super.key,
    required this.provider,
    required this.onToggleBrightness,
  });

  @override
  State<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends State<BrowseScreen> {
  late FsPath _cwd = widget.provider.root;
  late Future<List<FsNode>> _listing = widget.provider.list(_cwd);

  void _navigate(FsPath path) {
    setState(() {
      _cwd = path;
      _listing = widget.provider.list(path);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = WlmTheme.of(context).tokens;
    final width = MediaQuery.sizeOf(context).width;
    final gutter = tokens.spacing.pageGutter(width);

    return Scaffold(
      appBar: AppBar(
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
            icon: const Icon(Icons.brightness_6_outlined),
            tooltip: 'Toggle brightness',
            onPressed: widget.onToggleBrightness,
          ),
          SizedBox(width: tokens.spacing.xs),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PathBreadcrumbs(path: _cwd, onTap: _navigate, gutter: gutter),
          const Divider(),
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
                final items = snap.data ?? const <FsNode>[];
                if (items.isEmpty) {
                  return Center(
                    child: Text(
                      'Empty folder',
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
                  itemBuilder: (_, i) => _FsNodeTile(
                    node: items[i],
                    onTap: () {
                      if (items[i].isDirectory) _navigate(items[i].path);
                    },
                  ),
                  separatorBuilder: (_, _) =>
                      SizedBox(height: tokens.spacing.xs),
                  itemCount: items.length,
                );
              },
            ),
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
  final VoidCallback onTap;

  const _FsNodeTile({required this.node, required this.onTap});

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
        borderRadius: BorderRadius.circular(tokens.radius.md),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: tokens.spacing.md,
            vertical: tokens.spacing.md,
          ),
          decoration: BoxDecoration(
            border: Border.all(color: scheme.outlineVariant),
            borderRadius: BorderRadius.circular(tokens.radius.md),
            color: scheme.surfaceContainerLow,
          ),
          child: Row(
            children: [
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
              if (node.isDirectory)
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
