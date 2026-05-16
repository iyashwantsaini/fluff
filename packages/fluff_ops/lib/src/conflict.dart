import 'package:fluff_vfs/fluff_vfs.dart';
import 'package:meta/meta.dart';

/// What to do when a copy / move target already exists.
enum ConflictPolicy {
  /// Stop the operation and surface a [Conflict] for the UI to resolve.
  ask,

  /// Overwrite the destination silently.
  overwrite,

  /// Skip this item and continue.
  skip,

  /// Add a numeric suffix (`name (1).ext`, `name (2).ext`, …).
  renameAuto,
}

/// A single unresolved collision. Surface via
/// `OperationQueue.conflicts` so the UI can prompt the user.
@immutable
class Conflict {
  final String operationId;
  final FsPath source;
  final FsPath destination;
  const Conflict({
    required this.operationId,
    required this.source,
    required this.destination,
  });
}
