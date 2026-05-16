import 'dart:typed_data';

import 'package:fluff_ops/fluff_ops.dart';
import 'package:fluff_vfs/fluff_vfs.dart';
import 'package:test/test.dart';

Future<void> _waitFor(bool Function() done, {int maxTicks = 200}) async {
  for (var i = 0; i < maxTicks; i++) {
    if (done()) return;
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  throw StateError('predicate never became true');
}

void main() {
  late MemFsProvider fs;
  late OperationQueue queue;

  setUp(() {
    fs = MemFsProvider.demo();
    queue = OperationQueue(providerLookup: (id) => id == fs.id ? fs : null);
  });

  tearDown(() async {
    await queue.dispose();
  });

  test('copy single file moves bytes and leaves source intact', () async {
    final id = queue.enqueue(
      kind: OperationKind.copy,
      sources: [FsPath.parse('/Documents/notes.txt')],
      providerId: fs.id,
      destination: FsPath.parse('/Downloads'),
    );
    await _waitFor(
      () =>
          queue.operations.firstWhere((o) => o.id == id).status ==
          OperationStatus.succeeded,
    );
    expect(await fs.stat(FsPath.parse('/Downloads/notes.txt')), isNotNull);
    expect(await fs.stat(FsPath.parse('/Documents/notes.txt')), isNotNull);
  });

  test('move deletes source after copy', () async {
    final id = queue.enqueue(
      kind: OperationKind.move,
      sources: [FsPath.parse('/Documents/budget.csv')],
      providerId: fs.id,
      destination: FsPath.parse('/Downloads'),
    );
    await _waitFor(
      () =>
          queue.operations.firstWhere((o) => o.id == id).status ==
          OperationStatus.succeeded,
    );
    expect(await fs.stat(FsPath.parse('/Documents/budget.csv')), isNull);
    expect(await fs.stat(FsPath.parse('/Downloads/budget.csv')), isNotNull);
  });

  test('delete removes folder recursively', () async {
    final id = queue.enqueue(
      kind: OperationKind.delete,
      sources: [FsPath.parse('/Pictures')],
      providerId: fs.id,
    );
    await _waitFor(
      () =>
          queue.operations.firstWhere((o) => o.id == id).status ==
          OperationStatus.succeeded,
    );
    expect(await fs.stat(FsPath.parse('/Pictures')), isNull);
    expect(await fs.stat(FsPath.parse('/Pictures/sunset.jpg')), isNull);
  });

  test('auto-rename on conflict', () async {
    await fs.writeBytes(
      FsPath.parse('/Downloads/notes.txt'),
      Uint8List.fromList('existing'.codeUnits),
    );
    final id = queue.enqueue(
      kind: OperationKind.copy,
      sources: [FsPath.parse('/Documents/notes.txt')],
      providerId: fs.id,
      destination: FsPath.parse('/Downloads'),
    );
    await _waitFor(
      () =>
          queue.operations.firstWhere((o) => o.id == id).status ==
          OperationStatus.succeeded,
    );
    expect(await fs.stat(FsPath.parse('/Downloads/notes (1).txt')), isNotNull);
  });

  test('progress stream emits at least one tick per item', () async {
    final samples = <OperationProgress>[];
    final sub = queue.progress.listen(samples.add);
    final id = queue.enqueue(
      kind: OperationKind.copy,
      sources: [
        FsPath.parse('/Documents/notes.txt'),
        FsPath.parse('/Documents/budget.csv'),
      ],
      providerId: fs.id,
      destination: FsPath.parse('/Music'),
    );
    await _waitFor(
      () =>
          queue.operations.firstWhere((o) => o.id == id).status ==
          OperationStatus.succeeded,
    );
    await sub.cancel();
    expect(samples.length, greaterThanOrEqualTo(2));
    expect(samples.last.fraction, closeTo(1.0, 0.01));
  });

  test('failed op surfaces error on operation snapshot', () async {
    final id = queue.enqueue(
      kind: OperationKind.copy,
      sources: [FsPath.parse('/nope')],
      providerId: fs.id,
      destination: FsPath.parse('/Downloads'),
    );
    await _waitFor(
      () =>
          queue.operations.firstWhere((o) => o.id == id).status ==
          OperationStatus.failed,
    );
    expect(queue.operations.firstWhere((o) => o.id == id).error, isNotNull);
  });
}
