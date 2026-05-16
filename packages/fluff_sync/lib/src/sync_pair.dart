import 'package:meta/meta.dart';

/// One bidirectional or one-way sync between two folders, each
/// addressed by `(providerId, path)`.
@immutable
class SyncPair {
  SyncPair({
    required this.id,
    required this.label,
    required this.sourceProviderId,
    required this.sourcePath,
    required this.targetProviderId,
    required this.targetPath,
    this.bidirectional = false,
    this.lastRun,
  }) {
    if (id.isEmpty) throw ArgumentError.value(id, 'id', 'must not be empty');
    if (label.isEmpty) {
      throw ArgumentError.value(label, 'label', 'must not be empty');
    }
    if (sourceProviderId.isEmpty) {
      throw ArgumentError.value(sourceProviderId, 'sourceProviderId');
    }
    if (targetProviderId.isEmpty) {
      throw ArgumentError.value(targetProviderId, 'targetProviderId');
    }
  }

  final String id;
  final String label;
  final String sourceProviderId;
  final String sourcePath;
  final String targetProviderId;
  final String targetPath;
  final bool bidirectional;
  final DateTime? lastRun;

  SyncPair copyWith({DateTime? lastRun}) {
    return SyncPair(
      id: id,
      label: label,
      sourceProviderId: sourceProviderId,
      sourcePath: sourcePath,
      targetProviderId: targetProviderId,
      targetPath: targetPath,
      bidirectional: bidirectional,
      lastRun: lastRun ?? this.lastRun,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is SyncPair &&
      other.id == id &&
      other.label == label &&
      other.sourceProviderId == sourceProviderId &&
      other.sourcePath == sourcePath &&
      other.targetProviderId == targetProviderId &&
      other.targetPath == targetPath &&
      other.bidirectional == bidirectional &&
      other.lastRun == lastRun;

  @override
  int get hashCode => Object.hash(
    id,
    label,
    sourceProviderId,
    sourcePath,
    targetProviderId,
    targetPath,
    bidirectional,
    lastRun,
  );
}
