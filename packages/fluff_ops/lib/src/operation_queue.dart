import 'dart:async';

import 'package:fluff_vfs/fluff_vfs.dart';

import 'conflict.dart';
import 'operation.dart';
import 'progress.dart';

/// Resolves a [providerId] to its live [FsProvider].
typedef ProviderLookup = FsProvider? Function(String providerId);

/// Owns the queue of [Operation]s, runs them serially, and broadcasts
/// progress + conflicts. Lives on the main isolate today; a future
/// foreground-task wrapper will host the queue off-main-isolate.
class OperationQueue {
  final ProviderLookup _lookup;
  ConflictPolicy defaultPolicy;

  final _operations = <Operation>[];
  final _operationsCtrl = StreamController<List<Operation>>.broadcast();
  final _progressCtrl = StreamController<OperationProgress>.broadcast();
  final _conflictsCtrl = StreamController<Conflict>.broadcast();

  Future<void>? _runner;
  int _nextId = 1;

  OperationQueue({
    required ProviderLookup providerLookup,
    this.defaultPolicy = ConflictPolicy.renameAuto,
  }) : _lookup = providerLookup;

  /// Read-only snapshot of every operation, newest first.
  List<Operation> get operations => List.unmodifiable(_operations);

  /// Whole-list updates whenever any operation transitions state.
  Stream<List<Operation>> get operationStream => _operationsCtrl.stream;

  /// Granular progress samples (one [OperationProgress] per tick).
  Stream<OperationProgress> get progress => _progressCtrl.stream;

  /// Conflicts that the UI needs to resolve.
  Stream<Conflict> get conflicts => _conflictsCtrl.stream;

  /// Enqueue a new operation and start the runner if idle.
  /// Returns the assigned [Operation.id].
  String enqueue({
    required OperationKind kind,
    required List<FsPath> sources,
    required String providerId,
    FsPath? destination,
  }) {
    final id = '#${_nextId++}';
    final op = Operation(
      id: id,
      kind: kind,
      sources: sources,
      providerId: providerId,
      destination: destination,
    );
    _operations.insert(0, op);
    _emit();
    _runner ??= _drain();
    return id;
  }

  /// True iff something is currently running.
  bool get isBusy => _runner != null;

  // ---- internals -------------------------------------------------------

  void _emit() {
    if (!_operationsCtrl.isClosed) {
      _operationsCtrl.add(operations);
    }
  }

  void _update(String id, Operation Function(Operation) f) {
    final i = _operations.indexWhere((o) => o.id == id);
    if (i == -1) return;
    _operations[i] = f(_operations[i]);
    _emit();
  }

  Future<void> _drain() async {
    try {
      while (true) {
        final next = _operations
            .where((o) => o.status == OperationStatus.pending)
            .toList()
            .reversed
            .toList();
        if (next.isEmpty) return;
        final op = next.first;
        _update(op.id, (o) => o.copyWith(status: OperationStatus.running));
        try {
          await _execute(op);
          _update(op.id, (o) => o.copyWith(status: OperationStatus.succeeded));
        } catch (e) {
          _update(
            op.id,
            (o) =>
                o.copyWith(status: OperationStatus.failed, error: e.toString()),
          );
        }
      }
    } finally {
      _runner = null;
    }
  }

  Future<void> _execute(Operation op) async {
    final provider = _lookup(op.providerId);
    if (provider == null) {
      throw StateError('No provider registered for ${op.providerId}');
    }
    switch (op.kind) {
      case OperationKind.copy:
        await _copyAll(provider, op);
      case OperationKind.move:
        await _copyAll(provider, op, delete: true);
      case OperationKind.delete:
        await _deleteAll(provider, op);
      case OperationKind.rename:
        await _rename(provider, op);
      case OperationKind.hash:
        await _hash(provider, op);
    }
  }

  Future<void> _copyAll(
    FsProvider provider,
    Operation op, {
    bool delete = false,
  }) async {
    final dest = op.destination;
    if (dest == null) {
      throw ArgumentError('copy/move requires a destination');
    }
    var done = 0;
    var bytesDone = 0;
    final total = op.sources.length;
    for (final src in op.sources) {
      var target = dest.child(src.name);
      final existing = await provider.stat(target);
      if (existing != null) {
        final resolved = await _resolveConflict(op.id, src, target, provider);
        if (resolved == null) {
          done++;
          _progressCtrl.add(
            OperationProgress(
              id: op.id,
              itemsDone: done,
              itemsTotal: total,
              bytesDone: bytesDone,
              currentItem: src.toString(),
            ),
          );
          continue;
        }
        target = resolved;
      }
      final node = await provider.stat(src);
      if (node == null) {
        throw StateError('source missing: $src');
      }
      if (node.isFile) {
        final bytes = await provider.readBytes(src);
        await provider.writeBytes(target, bytes);
        bytesDone += bytes.length;
        if (delete) await provider.delete(src);
      } else if (node.isDirectory) {
        await provider.mkdir(target, recursive: true);
        // Shallow copy of children for the web demo. A recursive copy
        // ships with Phase 2.1 on Android (with a real foreground task).
        final kids = await provider.list(src);
        for (final k in kids) {
          if (k.isFile) {
            final b = await provider.readBytes(k.path);
            await provider.writeBytes(target.child(k.name), b);
            bytesDone += b.length;
          }
        }
        if (delete) await provider.delete(src, recursive: true);
      }
      done++;
      _progressCtrl.add(
        OperationProgress(
          id: op.id,
          itemsDone: done,
          itemsTotal: total,
          bytesDone: bytesDone,
          currentItem: src.toString(),
        ),
      );
    }
  }

  Future<void> _deleteAll(FsProvider provider, Operation op) async {
    var done = 0;
    final total = op.sources.length;
    for (final src in op.sources) {
      final node = await provider.stat(src);
      if (node != null) {
        await provider.delete(src, recursive: node.isDirectory);
      }
      done++;
      _progressCtrl.add(
        OperationProgress(
          id: op.id,
          itemsDone: done,
          itemsTotal: total,
          bytesDone: 0,
          currentItem: src.toString(),
        ),
      );
    }
  }

  Future<void> _rename(FsProvider provider, Operation op) async {
    final src = op.sources.single;
    final to = op.destination;
    if (to == null) throw ArgumentError('rename requires destination');
    await provider.rename(src, to);
    _progressCtrl.add(
      OperationProgress(
        id: op.id,
        itemsDone: 1,
        itemsTotal: 1,
        bytesDone: 0,
        currentItem: src.toString(),
      ),
    );
  }

  Future<void> _hash(FsProvider provider, Operation op) async {
    var done = 0;
    var bytesDone = 0;
    final total = op.sources.length;
    for (final src in op.sources) {
      final bytes = await provider.readBytes(src);
      bytesDone += bytes.length;
      done++;
      _progressCtrl.add(
        OperationProgress(
          id: op.id,
          itemsDone: done,
          itemsTotal: total,
          bytesDone: bytesDone,
          currentItem: src.toString(),
        ),
      );
    }
  }

  Future<FsPath?> _resolveConflict(
    String opId,
    FsPath src,
    FsPath dest,
    FsProvider provider,
  ) async {
    switch (defaultPolicy) {
      case ConflictPolicy.overwrite:
        return dest;
      case ConflictPolicy.skip:
        return null;
      case ConflictPolicy.renameAuto:
        return _autoRename(provider, dest);
      case ConflictPolicy.ask:
        _conflictsCtrl.add(
          Conflict(operationId: opId, source: src, destination: dest),
        );
        // Without an interactive resolver this falls back to renameAuto
        // so a headless run still completes.
        return _autoRename(provider, dest);
    }
  }

  Future<FsPath> _autoRename(FsProvider provider, FsPath dest) async {
    final name = dest.name;
    final dot = name.lastIndexOf('.');
    final stem = dot > 0 ? name.substring(0, dot) : name;
    final ext = dot > 0 ? name.substring(dot) : '';
    final parent = dest.parent;
    var n = 1;
    while (true) {
      final candidate = parent.child('$stem ($n)$ext');
      if (await provider.stat(candidate) == null) return candidate;
      n++;
      if (n > 9999) {
        throw StateError('could not auto-rename after 9999 attempts');
      }
    }
  }

  Future<void> dispose() async {
    await _operationsCtrl.close();
    await _progressCtrl.close();
    await _conflictsCtrl.close();
  }
}
