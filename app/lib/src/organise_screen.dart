import 'package:fluff_intel/fluff_intel.dart';
import 'package:fluff_skin/fluff_skin.dart';
import 'package:flutter/material.dart';

/// Phase 8 web slice: shows a mocked [OrganisePlan] diff and lets
/// the user toggle each action before "applying".
class OrganiseScreen extends StatefulWidget {
  const OrganiseScreen({
    super.key,
    required this.plan,
    required this.drawer,
    this.onToggleBrightness,
  });

  final OrganisePlan plan;
  final Drawer drawer;
  final VoidCallback? onToggleBrightness;

  @override
  State<OrganiseScreen> createState() => _OrganiseScreenState();
}

class _OrganiseScreenState extends State<OrganiseScreen> {
  late final Set<int> _accepted = Set.from(
    List.generate(widget.plan.actions.length, (i) => i),
  );

  @override
  Widget build(BuildContext context) {
    final tokens = WlmTheme.of(context).tokens;
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      drawer: widget.drawer,
      appBar: AppBar(
        title: const Text('AI organise'),
        actions: [
          if (widget.onToggleBrightness != null)
            IconButton(
              tooltip: 'Toggle theme',
              icon: const Icon(Icons.brightness_6_outlined),
              onPressed: widget.onToggleBrightness,
            ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.symmetric(
          horizontal: tokens.spacing.lg,
          vertical: tokens.spacing.md,
        ),
        children: [
          Container(
            padding: EdgeInsets.all(tokens.spacing.md),
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(tokens.radius.md),
            ),
            child: Row(
              children: [
                Icon(Icons.auto_awesome_rounded, color: cs.onPrimaryContainer),
                SizedBox(width: tokens.spacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.plan.title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(color: cs.onPrimaryContainer),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${widget.plan.actions.length} suggestions · '
                        '${widget.plan.moveCount} move · '
                        '${widget.plan.renameCount} rename',
                        style: TextStyle(color: cs.onPrimaryContainer),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: tokens.spacing.md),
          for (var i = 0; i < widget.plan.actions.length; i++)
            _ActionTile(
              action: widget.plan.actions[i],
              accepted: _accepted.contains(i),
              onChanged: (v) => setState(() {
                if (v) {
                  _accepted.add(i);
                } else {
                  _accepted.remove(i);
                }
              }),
            ),
          SizedBox(height: tokens.spacing.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => setState(_accepted.clear),
                child: const Text('Reject all'),
              ),
              SizedBox(width: tokens.spacing.sm),
              FilledButton.icon(
                onPressed: _accepted.isEmpty ? null : () {},
                icon: const Icon(Icons.check_rounded),
                label: Text('Apply ${_accepted.length}'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.action,
    required this.accepted,
    required this.onChanged,
  });

  final OrganiseAction action;
  final bool accepted;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tokens = WlmTheme.of(context).tokens;
    return Container(
      margin: EdgeInsets.only(bottom: tokens.spacing.sm),
      padding: EdgeInsets.all(tokens.spacing.md),
      decoration: BoxDecoration(
        color: accepted ? cs.surfaceContainerHighest : cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(tokens.radius.md),
        border: Border.all(
          color: accepted ? cs.primary : cs.outlineVariant,
          width: accepted ? 1.5 : 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(value: accepted, onChanged: (v) => onChanged(v ?? false)),
          SizedBox(width: tokens.spacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  action.sourcePath,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: cs.onSurfaceVariant,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
                Row(
                  children: [
                    Icon(
                      action.isRename
                          ? Icons.edit_rounded
                          : Icons.drive_file_move_rounded,
                      size: 14,
                      color: cs.primary,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        action.targetPath,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          color: cs.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  action.reason,
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
