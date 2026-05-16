/// Fluff operation engine.
///
/// Defines the queued, observable model used for every long-running
/// file-system action — copy, move, delete, rename, hash. UI code
/// subscribes to [OperationQueue.progress] for live updates and to
/// [OperationQueue.conflicts] to resolve overwrite collisions.
library;

export 'src/conflict.dart';
export 'src/operation.dart';
export 'src/operation_queue.dart';
export 'src/progress.dart';
