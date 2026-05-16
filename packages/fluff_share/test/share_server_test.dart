import 'package:fluff_share/fluff_share.dart';
import 'package:test/test.dart';

void main() {
  group('ShareServer', () {
    test('defaults port to kind.defaultPort', () {
      final s = ShareServer(id: 'a', kind: ShareServerKind.http, label: 'Web');
      expect(s.port, ShareServerKind.http.defaultPort);
      expect(s.isRunning, isFalse);
      expect(s.bytesServed, 0);
    });

    test('rejects empty label and out-of-range port', () {
      expect(
        () => ShareServer(id: 'a', kind: ShareServerKind.http, label: ''),
        throwsArgumentError,
      );
      expect(
        () => ShareServer(
          id: 'a',
          kind: ShareServerKind.http,
          label: 'Web',
          port: 0,
        ),
        throwsArgumentError,
      );
    });

    test('requiresAuth implies non-empty username', () {
      expect(
        () => ShareServer(
          id: 'a',
          kind: ShareServerKind.webdav,
          label: 'Dav',
          requiresAuth: true,
        ),
        throwsArgumentError,
      );
      final s = ShareServer(
        id: 'a',
        kind: ShareServerKind.webdav,
        label: 'Dav',
        requiresAuth: true,
        username: 'me',
      );
      expect(s.username, 'me');
    });

    test('loopbackUrl picks the right scheme per kind', () {
      for (final kind in ShareServerKind.values) {
        final s = ShareServer(id: kind.name, kind: kind, label: kind.label);
        expect(s.loopbackUrl, contains(':${kind.defaultPort}'));
      }
    });
  });

  group('ShareServerController', () {
    test('upsert + remove emit change events', () async {
      final c = ShareServerController();
      final batches = <List<ShareServer>>[];
      final sub = c.changes.listen(batches.add);

      c.upsert(ShareServer(id: 'a', kind: ShareServerKind.http, label: 'Web'));
      c.upsert(ShareServer(id: 'b', kind: ShareServerKind.ftp, label: 'Drop'));
      expect(c.remove('a'), isTrue);
      expect(c.remove('missing'), isFalse);

      await Future<void>.delayed(Duration.zero);
      await sub.cancel();
      await c.dispose();

      expect(batches, hasLength(3));
      expect(batches.last.single.id, 'b');
    });

    test('servers sorted by kind index then label', () {
      final c = ShareServerController(
        seed: [
          ShareServer(id: 'z', kind: ShareServerKind.webdav, label: 'Zed'),
          ShareServer(id: 'a', kind: ShareServerKind.webdav, label: 'Apple'),
          ShareServer(id: 'm', kind: ShareServerKind.http, label: 'Main'),
        ],
      );
      expect(c.servers.map((s) => s.id), ['m', 'a', 'z']);
    });

    test('start/stop/toggle flip isRunning and reset bytes', () {
      final c = ShareServerController(
        seed: [ShareServer(id: 'h', kind: ShareServerKind.http, label: 'Web')],
      );
      expect(c.start('h')?.isRunning, isTrue);
      c.tick(bytes: 1024);
      c.tick(bytes: 1024);
      expect(c.byId('h')!.bytesServed, 2048);
      expect(c.stop('h')?.isRunning, isFalse);
      expect(c.byId('h')!.bytesServed, 0);
      expect(c.toggle('h')?.isRunning, isTrue);
    });

    test('tick only mutates running servers', () {
      final c = ShareServerController(
        seed: [
          ShareServer(id: 'on', kind: ShareServerKind.http, label: 'On'),
          ShareServer(id: 'off', kind: ShareServerKind.ftp, label: 'Off'),
        ],
      );
      c.start('on');
      c.tick();
      expect(c.byId('on')!.bytesServed, greaterThan(0));
      expect(c.byId('off')!.bytesServed, 0);
    });

    test('defaultSeedServers covers every kind exactly once', () {
      final seeded = defaultSeedServers();
      expect(seeded.map((s) => s.kind).toSet(), ShareServerKind.values.toSet());
      expect(seeded, hasLength(ShareServerKind.values.length));
    });
  });
}
