import 'package:fluff_ops/fluff_ops.dart';
import 'package:fluff_skin/fluff_skin.dart';
import 'package:flutter/material.dart';

/// Bottom sheet that lists running and recent operations.
class ProgressSheet extends StatelessWidget {
  final List<Operation> operations;
  final OperationProgress? latest;

  const ProgressSheet({
    super.key,
    required this.operations,
    required this.latest,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tokens = WlmTheme.of(context).tokens;

    final visible = operations
        .where(
          (o) =>
              o.status == OperationStatus.running ||
              o.status == OperationStatus.pending,
        )
        .toList();
    if (visible.isEmpty) return const SizedBox.shrink();

    return Material(
      elevation: 4,
      color: scheme.surfaceContainerHigh,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: tokens.spacing.lg,
            vertical: tokens.spacing.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final op in visible) _row(context, op, theme, tokens),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(
    BuildContext context,
    Operation op,
    ThemeData theme,
    dynamic tokens,
  ) {
    final scheme = theme.colorScheme;
    final isCurrent = latest?.id == op.id;
    final value = isCurrent ? latest?.fraction : null;
    final detail = isCurrent && latest != null
        ? '${latest!.itemsDone}/${latest!.itemsTotal ?? '?'}  ·  '
              '${latest!.currentItem}'
        : op.status == OperationStatus.running
        ? 'Running…'
        : 'Queued';

    return Padding(
      padding: EdgeInsets.symmetric(vertical: tokens.spacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bolt_outlined, size: 16, color: scheme.primary),
              SizedBox(width: tokens.spacing.sm),
              Expanded(
                child: Text(
                  op.label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                value == null
                    ? ''
                    : '${(value * 100).clamp(0, 100).toStringAsFixed(0)}%',
                style: theme.textTheme.labelSmall,
              ),
            ],
          ),
          SizedBox(height: tokens.spacing.xs),
          ClipRRect(
            borderRadius: BorderRadius.circular(tokens.radius.sm),
            child: LinearProgressIndicator(
              value: value,
              minHeight: 4,
              backgroundColor: scheme.surfaceContainerHighest,
            ),
          ),
          SizedBox(height: tokens.spacing.xs),
          Text(
            detail,
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
