import 'package:fluff_vfs/fluff_vfs.dart';

import 'sync_plan.dart';

/// Pure-Dart sync planner. Walks two [FsProvider]s rooted at the
/// given paths and emits a [SyncPlan] describing what needs to
/// happen on the target side to make it match the source.
///
/// One-way: target deletions are emitted when [deleteExtraneous] is
/// true (default), so the target ends up as a mirror of the source.
class SyncEngine {
  const SyncEngine();

  Future<SyncPlan> plan({
    required FsProvider source,
    required FsProvider target,
    String sourceRoot = '/',
    String targetRoot = '/',
    bool deleteExtraneous = true,
  }) async {
    final sourceFiles = await _collect(source, FsPath.parse(sourceRoot));
    final targetFiles = await _collect(target, FsPath.parse(targetRoot));

    final entries = <SyncEntry>[];
    final visited = <String>{};

    final sortedSourceKeys = sourceFiles.keys.toList()..sort();
    for (final rel in sortedSourceKeys) {
      visited.add(rel);
      final src = sourceFiles[rel]!;
      final tgt = targetFiles[rel];
      if (tgt == null) {
        entries.add(
          SyncEntry(
            relativePath: rel,
            action: SyncAction.copy,
            sourceSize: src.size,
          ),
        );
      } else if (src.size != tgt.size ||
          (src.modified != null &&
              tgt.modified != null &&
              src.modified!.isAfter(tgt.modified!))) {
        entries.add(
          SyncEntry(
            relativePath: rel,
            action: SyncAction.replace,
            sourceSize: src.size,
            targetSize: tgt.size,
          ),
        );
      } else {
        entries.add(
          SyncEntry(
            relativePath: rel,
            action: SyncAction.skip,
            sourceSize: src.size,
            targetSize: tgt.size,
          ),
        );
      }
    }

    if (deleteExtraneous) {
      final sortedTargetKeys = targetFiles.keys.toList()..sort();
      for (final rel in sortedTargetKeys) {
        if (visited.contains(rel)) continue;
        entries.add(
          SyncEntry(
            relativePath: rel,
            action: SyncAction.delete,
            targetSize: targetFiles[rel]!.size,
          ),
        );
      }
    }

    return SyncPlan(entries);
  }

  Future<Map<String, FsNode>> _collect(FsProvider provider, FsPath root) async {
    final out = <String, FsNode>{};
    Future<void> walk(FsPath dir, String relPrefix) async {
      final nodes = await provider.list(dir);
      for (final n in nodes) {
        final rel = relPrefix.isEmpty ? n.name : '$relPrefix/${n.name}';
        if (n.isDirectory) {
          await walk(n.path, rel);
        } else {
          out[rel] = n;
        }
      }
    }

    await walk(root, '');
    return out;
  }
}
