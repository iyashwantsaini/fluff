import 'package:meta/meta.dart';

/// What the engine wants to do for a given relative path.
enum SyncAction { copy, replace, delete, skip }

@immutable
class SyncEntry {
  const SyncEntry({
    required this.relativePath,
    required this.action,
    this.sourceSize,
    this.targetSize,
  });

  final String relativePath;
  final SyncAction action;
  final int? sourceSize;
  final int? targetSize;

  @override
  bool operator ==(Object other) =>
      other is SyncEntry &&
      other.relativePath == relativePath &&
      other.action == action &&
      other.sourceSize == sourceSize &&
      other.targetSize == targetSize;

  @override
  int get hashCode =>
      Object.hash(relativePath, action, sourceSize, targetSize);
}

/// A plan is an immutable list of entries plus pre-computed summary
/// counts so the UI can render badges without re-iterating.
@immutable
class SyncPlan {
  SyncPlan(List<SyncEntry> entries)
    : entries = List.unmodifiable(entries),
      copyCount = entries.where((e) => e.action == SyncAction.copy).length,
      replaceCount =
          entries.where((e) => e.action == SyncAction.replace).length,
      deleteCount = entries.where((e) => e.action == SyncAction.delete).length,
      skipCount = entries.where((e) => e.action == SyncAction.skip).length;

  final List<SyncEntry> entries;
  final int copyCount;
  final int replaceCount;
  final int deleteCount;
  final int skipCount;

  /// Bytes the engine would copy or rewrite on the target side.
  int get bytesToTransfer {
    var total = 0;
    for (final e in entries) {
      if (e.action == SyncAction.copy || e.action == SyncAction.replace) {
        total += e.sourceSize ?? 0;
      }
    }
    return total;
  }

  bool get isEmpty => entries.isEmpty;
  bool get hasChanges =>
      copyCount > 0 || replaceCount > 0 || deleteCount > 0;
}
