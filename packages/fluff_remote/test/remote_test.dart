import 'dart:typed_data';

import 'package:fluff_remote/fluff_remote.dart';
import 'package:fluff_vfs/fluff_vfs.dart';
import 'package:test/test.dart';

void main() {
  group('RemoteAccount', () {
    test('SFTP defaults to port 22', () {
      final a = RemoteAccount(
        id: 'a',
        label: 'home',
        kind: RemoteKind.sftp,
        host: '10.0.0.5',
      );
      expect(a.port, 22);
      expect(a.summary, contains('SFTP'));
      expect(a.summary, contains('10.0.0.5:22'));
    });

    test('SMB requires a share', () {
      expect(
        () => RemoteAccount(
          id: 'a',
          label: 'nas',
          kind: RemoteKind.smb,
          host: '10.0.0.10',
        ),
        throwsArgumentError,
      );
    });

    test('rejects invalid port', () {
      expect(
        () => RemoteAccount(
          id: 'a',
          label: 'x',
          kind: RemoteKind.sftp,
          host: 'h',
          port: 70000,
        ),
        throwsArgumentError,
      );
    });

    test('summary embeds username + share', () {
      final a = RemoteAccount(
        id: 'a',
        label: 'nas',
        kind: RemoteKind.smb,
        host: 'nas.local',
        share: 'media',
        username: 'guest',
      );
      expect(a.summary, contains('guest@nas.local:445/media'));
    });
  });

  group('RemoteAccountStore', () {
    test('upsert + remove emit events', () async {
      final store = RemoteAccountStore();
      final events = <int>[];
      final sub = store.changes.listen((list) => events.add(list.length));
      store.upsert(
        RemoteAccount(id: '1', label: 'a', kind: RemoteKind.sftp, host: 'h'),
      );
      store.upsert(
        RemoteAccount(id: '2', label: 'b', kind: RemoteKind.sftp, host: 'h'),
      );
      store.remove('1');
      await Future<void>.delayed(Duration.zero);
      expect(events, [1, 2, 1]);
      await sub.cancel();
      await store.dispose();
    });

    test('accounts list is sorted by label', () {
      final store = RemoteAccountStore();
      store.upsert(
        RemoteAccount(id: '1', label: 'Zeta', kind: RemoteKind.sftp, host: 'h'),
      );
      store.upsert(
        RemoteAccount(
          id: '2',
          label: 'alpha',
          kind: RemoteKind.sftp,
          host: 'h',
        ),
      );
      expect(store.accounts.map((a) => a.label), ['alpha', 'Zeta']);
    });
  });

  group('MockRemoteFsProvider', () {
    test('SMB seed exposes /Shared and /Public', () async {
      final p = MockRemoteFsProvider(
        account: RemoteAccount(
          id: 'a',
          label: 'nas',
          kind: RemoteKind.smb,
          host: 'h',
          share: 'media',
        ),
      );
      final root = await p.list(FsPath.root);
      final names = root.map((n) => n.name).toList()..sort();
      expect(names, ['Public', 'Shared']);
    });

    test('SFTP seed exposes /home and /var', () async {
      final p = MockRemoteFsProvider(
        account: RemoteAccount(
          id: 'a',
          label: 'box',
          kind: RemoteKind.sftp,
          host: 'h',
        ),
      );
      final root = await p.list(FsPath.root);
      final names = root.map((n) => n.name).toList()..sort();
      expect(names, ['home', 'var']);
    });

    test('writeBytes / readBytes round-trip', () async {
      final p = MockRemoteFsProvider(
        account: RemoteAccount(
          id: 'a',
          label: 'box',
          kind: RemoteKind.sftp,
          host: 'h',
        ),
      );
      final path = FsPath.parse('/home/deploy/note.txt');
      await p.writeBytes(path, Uint8List.fromList('hello remote'.codeUnits));
      final got = await p.readBytes(path);
      expect(String.fromCharCodes(got), 'hello remote');
    });
  });
}
