import 'dart:typed_data';

import 'package:fluff_skin/fluff_skin.dart';
import 'package:fluff_sync/fluff_sync.dart';
import 'package:fluff_vfs/fluff_vfs.dart';
import 'package:flutter/material.dart';

/// Phase 7 web slice: shows a pre-execution diff between two
/// in-memory [FsProvider]s.
class SyncScreen extends StatefulWidget {
  const SyncScreen({
    super.key,
    required this.source,
    required this.target,
    required this.pair,
    required this.drawer,
    this.onToggleBrightness,
  });

  final FsProvider source;
  final FsProvider target;
  final SyncPair pair;
  final Drawer drawer;
  final VoidCallback? onToggleBrightness;

  @override
  State<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends State<SyncScreen> {
  Future<SyncPlan>? _planFuture;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _planFuture = const SyncEngine().plan(
        source: widget.source,
        target: widget.target,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: widget.drawer,
      appBar: AppBar(
        title: const Text('Sync'),
        actions: [
          IconButton(
            tooltip: 'Recompute',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _refresh,
          ),
          if (widget.onToggleBrightness != null)
            IconButton(
              tooltip: 'Toggle theme',
              icon: const Icon(Icons.brightness_6_outlined),
              onPressed: widget.onToggleBrightness,
            ),
        ],
      ),
      body: FutureBuilder<SyncPlan>(
        future: _planFuture,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final plan = snap.data!;
          return _PlanView(pair: widget.pair, plan: plan);
        },
      ),
    );
  }
}

class _PlanView extends StatelessWidget {
  const _PlanView({required this.pair, required this.plan});
  final SyncPair pair;
  final SyncPlan plan;

  @override
  Widget build(BuildContext context) {
    final tokens = WlmTheme.of(context).tokens;
    return ListView(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.lg,
        vertical: tokens.spacing.md,
      ),
      children: [
        _PairHeader(pair: pair),
        SizedBox(height: tokens.spacing.md),
        _SummaryRow(plan: plan),
        SizedBox(height: tokens.spacing.md),
        ...plan.entries.map((e) => _EntryTile(entry: e)),
      ],
    );
  }
}

class _PairHeader extends StatelessWidget {
  const _PairHeader({required this.pair});
  final SyncPair pair;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tokens = WlmTheme.of(context).tokens;
    return Container(
      padding: EdgeInsets.all(tokens.spacing.md),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(tokens.radius.md),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: cs.primaryContainer,
            foregroundColor: cs.onPrimaryContainer,
            child: const Icon(Icons.sync_rounded),
          ),
          SizedBox(width: tokens.spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pair.label,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  '${pair.sourceProviderId}:${pair.sourcePath}'
                  '  ${pair.bidirectional ? '↔' : '→'}  '
                  '${pair.targetProviderId}:${pair.targetPath}',
                  style: TextStyle(
                    color: cs.onSurfaceVariant,
                    fontFamily: 'monospace',
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.plan});
  final SyncPlan plan;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _Badge(label: 'copy', count: plan.copyCount, kind: SyncAction.copy),
        _Badge(
          label: 'replace',
          count: plan.replaceCount,
          kind: SyncAction.replace,
        ),
        _Badge(
          label: 'delete',
          count: plan.deleteCount,
          kind: SyncAction.delete,
        ),
        _Badge(label: 'skip', count: plan.skipCount, kind: SyncAction.skip),
        _Badge(
          label: 'bytes',
          count: plan.bytesToTransfer,
          kind: SyncAction.copy,
          isByte: true,
        ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.label,
    required this.count,
    required this.kind,
    this.isByte = false,
  });
  final String label;
  final int count;
  final SyncAction kind;
  final bool isByte;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final (bg, fg) = switch (kind) {
      SyncAction.copy => (cs.primaryContainer, cs.onPrimaryContainer),
      SyncAction.replace => (cs.tertiaryContainer, cs.onTertiaryContainer),
      SyncAction.delete => (cs.errorContainer, cs.onErrorContainer),
      SyncAction.skip => (cs.surfaceContainerHighest, cs.onSurfaceVariant),
    };
    final text = isByte ? _humanBytes(count) : '$count';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label · $text',
        style: TextStyle(color: fg, fontWeight: FontWeight.w600, fontSize: 12),
      ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.entry});
  final SyncEntry entry;

  IconData get _icon => switch (entry.action) {
    SyncAction.copy => Icons.add_circle_outline,
    SyncAction.replace => Icons.compare_arrows_rounded,
    SyncAction.delete => Icons.remove_circle_outline,
    SyncAction.skip => Icons.check_circle_outline,
  };

  Color _color(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return switch (entry.action) {
      SyncAction.copy => cs.primary,
      SyncAction.replace => cs.tertiary,
      SyncAction.delete => cs.error,
      SyncAction.skip => cs.onSurfaceVariant,
    };
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final subtitle = switch (entry.action) {
      SyncAction.copy =>
        'copy · ${_humanBytes(entry.sourceSize ?? 0)}',
      SyncAction.replace =>
        'replace · ${_humanBytes(entry.targetSize ?? 0)} → '
            '${_humanBytes(entry.sourceSize ?? 0)}',
      SyncAction.delete =>
        'delete · ${_humanBytes(entry.targetSize ?? 0)}',
      SyncAction.skip =>
        'unchanged · ${_humanBytes(entry.sourceSize ?? 0)}',
    };
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(_icon, color: _color(context)),
      title: Text(
        entry.relativePath,
        style: const TextStyle(fontFamily: 'monospace'),
      ),
      subtitle: Text(subtitle, style: TextStyle(color: cs.onSurfaceVariant)),
    );
  }
}

String _humanBytes(int n) {
  const units = ['B', 'KiB', 'MiB', 'GiB'];
  var v = n.toDouble();
  var i = 0;
  while (v >= 1024 && i < units.length - 1) {
    v /= 1024;
    i++;
  }
  return '${v.toStringAsFixed(v >= 100 || i == 0 ? 0 : 1)} ${units[i]}';
}

/// Web-slice helper that seeds two `MemFsProvider`s with a small
/// asymmetric tree so the sync diff has something interesting to
/// render.
Future<({MemFsProvider source, MemFsProvider target, SyncPair pair})>
buildDemoSyncPair() async {
  final src = MemFsProvider(id: 'sync-src', displayName: 'Phone /Pictures');
  final tgt = MemFsProvider(id: 'sync-tgt', displayName: 'NAS /backup/pics');

  Uint8List bytes(String s) => Uint8List.fromList(s.codeUnits);

  await src.mkdir(FsPath.parse('/2026-04'), recursive: true);
  await src.writeBytes(
    FsPath.parse('/2026-04/sunset.jpg'),
    Uint8List(64 * 1024),
  );
  await src.writeBytes(
    FsPath.parse('/2026-04/family.jpg'),
    Uint8List(48 * 1024),
  );
  await src.writeBytes(FsPath.parse('/notes.txt'), bytes('updated notes'));
  await src.writeBytes(FsPath.parse('/index.md'), bytes('keep me'));

  await tgt.mkdir(FsPath.parse('/2026-04'), recursive: true);
  // family.jpg already present and identical → skip.
  await tgt.writeBytes(
    FsPath.parse('/2026-04/family.jpg'),
    Uint8List(48 * 1024),
  );
  // notes.txt present but smaller → replace.
  await tgt.writeBytes(FsPath.parse('/notes.txt'), bytes('old'));
  // index.md identical → skip.
  await tgt.writeBytes(FsPath.parse('/index.md'), bytes('keep me'));
  // extraneous file → delete.
  await tgt.writeBytes(
    FsPath.parse('/old-cache.bin'),
    Uint8List(12 * 1024),
  );

  final pair = SyncPair(
    id: 'pair-pics',
    label: 'Pictures → NAS backup',
    sourceProviderId: src.id,
    sourcePath: '/',
    targetProviderId: tgt.id,
    targetPath: '/',
  );

  return (source: src, target: tgt, pair: pair);
}
