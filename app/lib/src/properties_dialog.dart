import 'package:fluff_skin/fluff_skin.dart';
import 'package:fluff_vfs/fluff_vfs.dart';
import 'package:flutter/material.dart';

/// Modal properties view for a single [FsNode].
class PropertiesDialog extends StatelessWidget {
  final FsNode node;
  final FsProvider provider;

  const PropertiesDialog({
    super.key,
    required this.node,
    required this.provider,
  });

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  String _formatDate(DateTime? d) {
    if (d == null) return '—';
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    final hh = d.hour.toString().padLeft(2, '0');
    final mi = d.minute.toString().padLeft(2, '0');
    return '${d.year}-$mm-$dd  $hh:$mi';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tokens = WlmTheme.of(context).tokens;

    Widget row(String label, String value) => Padding(
      padding: EdgeInsets.symmetric(vertical: tokens.spacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.radius.lg),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            tokens.spacing.xl,
            tokens.spacing.xl,
            tokens.spacing.xl,
            tokens.spacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(tokens.radius.sm),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      node.isDirectory
                          ? Icons.folder_rounded
                          : Icons.insert_drive_file_outlined,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  SizedBox(width: tokens.spacing.md),
                  Expanded(
                    child: Text(
                      node.name,
                      style: theme.textTheme.titleLarge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              SizedBox(height: tokens.spacing.lg),
              const Divider(height: 1),
              SizedBox(height: tokens.spacing.sm),
              row('Path', node.path.toString()),
              row(
                'Kind',
                node.isDirectory ? 'Folder' : (node.mimeType ?? 'Unknown file'),
              ),
              if (!node.isDirectory) row('Size', _formatSize(node.size)),
              row('Modified', _formatDate(node.modified)),
              row('Provider', provider.displayName),
              SizedBox(height: tokens.spacing.md),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
