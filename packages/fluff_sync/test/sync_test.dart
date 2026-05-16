import 'dart:typed_data';

import 'package:fluff_sync/fluff_sync.dart';
import 'package:fluff_vfs/fluff_vfs.dart';
import 'package:test/test.dart';

Uint8List _b(String s) => Uint8List.fromList(s.codeUnits);

Future<MemFsProvider> _seedSource() async {
  final m = MemFsProvider(id: 'src', displayName: 'src');
  await m.mkdir(FsPath.parse('/docs'), recursive: true);
  await m.writeBytes(FsPath.parse('/docs/a.txt'), _b('alpha-source'));
  await m.writeBytes(FsPath.parse('/docs/b.txt'), _b('beta'));
  await m.writeBytes(FsPath.parse('/readme.md'), _b('hello'));
  return m;
}

Future<MemFsProvider> _seedTargetMissingAndStale() async {
  final m = MemFsProvider(id: 'tgt', displayName: 'tgt');
  await m.mkdir(FsPath.parse('/docs'), recursive: true);
  // b.txt is identical to source; a.txt has different bytes (size mismatch);
  // readme.md is absent (will become copy); leftover.txt is extraneous.
  await m.writeBytes(FsPath.parse('/docs/a.txt'), _b('old'));
  await m.writeBytes(FsPath.parse('/docs/b.txt'), _b('beta'));
  await m.writeBytes(FsPath.parse('/leftover.txt'), _b('stale'));
  return m;
}

void main() {
  group('SyncPair', () {
    test('rejects empty fields', () {
      expect(
        () => SyncPair(
          id: '',
          label: 'X',
          sourceProviderId: 's',
          sourcePath: '/',
          targetProviderId: 't',
          targetPath: '/',
        ),
        throwsArgumentError,
      );
    });

    test('copyWith preserves identity', () {
      final p = SyncPair(
        id: 'p1',
        label: 'pics',
        sourceProviderId: 's',
        sourcePath: '/',
        targetProviderId: 't',
        targetPath: '/',
      );
      final now = DateTime.now();
      expect(p.copyWith(lastRun: now).lastRun, now);
      expect(p.copyWith(lastRun: now).id, p.id);
    });
  });

  group('SyncEngine.plan', () {
    test('classifies copy / replace / skip / delete correctly', () async {
      final src = await _seedSource();
      final tgt = await _seedTargetMissingAndStale();

      final plan = await const SyncEngine().plan(source: src, target: tgt);
      final byPath = {for (final e in plan.entries) e.relativePath: e};

      expect(byPath['docs/a.txt']!.action, SyncAction.replace);
      expect(byPath['docs/b.txt']!.action, SyncAction.skip);
      expect(byPath['readme.md']!.action, SyncAction.copy);
      expect(byPath['leftover.txt']!.action, SyncAction.delete);

      expect(plan.copyCount, 1);
      expect(plan.replaceCount, 1);
      expect(plan.skipCount, 1);
      expect(plan.deleteCount, 1);
      expect(plan.hasChanges, isTrue);
    });

    test('bytesToTransfer sums copy + replace source sizes', () async {
      final src = await _seedSource();
      final tgt = await _seedTargetMissingAndStale();
      final plan = await const SyncEngine().plan(source: src, target: tgt);
      // readme.md = 'hello' (5) + docs/a.txt = 'alpha-source' (12).
      expect(plan.bytesToTransfer, 5 + 12);
    });

    test('deleteExtraneous=false skips delete entries', () async {
      final src = await _seedSource();
      final tgt = await _seedTargetMissingAndStale();
      final plan = await const SyncEngine().plan(
        source: src,
        target: tgt,
        deleteExtraneous: false,
      );
      expect(plan.deleteCount, 0);
      expect(plan.entries.any((e) => e.relativePath == 'leftover.txt'),
          isFalse);
    });

    test('identical trees produce only skips', () async {
      final src = await _seedSource();
      final tgt = MemFsProvider(id: 'tgt', displayName: 'tgt');
      await tgt.mkdir(FsPath.parse('/docs'), recursive: true);
      await tgt.writeBytes(FsPath.parse('/docs/a.txt'), _b('alpha-source'));
      await tgt.writeBytes(FsPath.parse('/docs/b.txt'), _b('beta'));
      await tgt.writeBytes(FsPath.parse('/readme.md'), _b('hello'));

      final plan = await const SyncEngine().plan(source: src, target: tgt);
      expect(plan.hasChanges, isFalse);
      expect(plan.skipCount, 3);
    });
  });

  group('NearbyDiscovery', () {
    test('announce + pair emit events', () async {
      final d = NearbyDiscovery();
      final snaps = <List<NearbyDevice>>[];
      final sub = d.changes.listen(snaps.add);

      d.announce(NearbyDevice(
        id: 'a',
        name: 'Phone',
        kind: NearbyDeviceKind.phone,
        address: '10.0.0.2',
      ));
      d.pair('a');
      d.unpair('a');
      d.forget('a');

      await Future<void>.delayed(Duration.zero);
      await sub.cancel();
      await d.dispose();

      expect(snaps, hasLength(4));
      expect(snaps.last, isEmpty);
    });

    test('default seed has 3 devices sorted by name', () {
      final d = NearbyDiscovery(seed: defaultSeedNearbyDevices());
      final names = d.devices.map((x) => x.name).toList();
      expect(names, hasLength(3));
      expect(names, equals(List<String>.from(names)..sort((a, b) =>
          a.toLowerCase().compareTo(b.toLowerCase()))));
    });
  });
}
