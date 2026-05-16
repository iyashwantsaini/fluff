import 'package:fluff_ops/fluff_ops.dart';
import 'package:fluff_skin/fluff_skin.dart';
import 'package:fluff_vfs/fluff_vfs.dart';
import 'package:flutter/material.dart';

/// Choice returned by [ConflictDialog].
enum ConflictChoice { overwrite, skip, renameAuto }

class ConflictDialog extends StatelessWidget {
  final Conflict conflict;

  const ConflictDialog({super.key, required this.conflict});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = WlmTheme.of(context).tokens;
    final scheme = theme.colorScheme;

    Widget pathRow(IconData icon, String label, FsPath p) => Padding(
      padding: EdgeInsets.symmetric(vertical: tokens.spacing.xs),
      child: Row(
        children: [
          Icon(icon, size: 18, color: scheme.onSurfaceVariant),
          SizedBox(width: tokens.spacing.sm),
          SizedBox(
            width: 64,
            child: Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              p.toString(),
              style: theme.textTheme.bodyMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.radius.lg),
      ),
      title: const Text('Replace existing file?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'A file already exists at the destination.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          SizedBox(height: tokens.spacing.md),
          pathRow(Icons.upload_file_outlined, 'Source', conflict.source),
          pathRow(Icons.save_outlined, 'Target', conflict.destination),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(ConflictChoice.skip),
          child: const Text('Skip'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(ConflictChoice.renameAuto),
          child: const Text('Keep both'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(ConflictChoice.overwrite),
          child: const Text('Replace'),
        ),
      ],
    );
  }
}
