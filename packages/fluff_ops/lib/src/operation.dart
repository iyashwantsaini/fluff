import 'package:fluff_vfs/fluff_vfs.dart';
import 'package:meta/meta.dart';

/// What an [Operation] is doing.
enum OperationKind { copy, move, delete, rename, hash }

/// What an [Operation] is currently in.
enum OperationStatus { pending, running, succeeded, failed, cancelled }

/// One queued action. Operations are values — the queue owns mutation.
@immutable
class Operation {
  /// Stable id assigned by the queue. Use it to cross-reference
  /// progress events.
  final String id;

  final OperationKind kind;

  /// Source paths. Multi-select copy collapses to many sources.
  final List<FsPath> sources;

  /// Destination directory (copy / move) or new name (rename).
  /// `null` for delete / hash.
  final FsPath? destination;

  /// Owning provider id; `OperationQueue` looks it up.
  final String providerId;

  final OperationStatus status;

  /// Human-readable error message if [status] is `failed`.
  final String? error;

  const Operation({
    required this.id,
    required this.kind,
    required this.sources,
    required this.providerId,
    this.destination,
    this.status = OperationStatus.pending,
    this.error,
  });

  Operation copyWith({OperationStatus? status, String? error}) => Operation(
    id: id,
    kind: kind,
    sources: sources,
    providerId: providerId,
    destination: destination,
    status: status ?? this.status,
    error: error ?? this.error,
  );

  /// Short label for UI rendering. Localised in `app/`.
  String get label => switch (kind) {
    OperationKind.copy => 'Copy ${sources.length} item(s)',
    OperationKind.move => 'Move ${sources.length} item(s)',
    OperationKind.delete => 'Delete ${sources.length} item(s)',
    OperationKind.rename => 'Rename ${sources.first.name}',
    OperationKind.hash => 'Hash ${sources.length} item(s)',
  };
}
