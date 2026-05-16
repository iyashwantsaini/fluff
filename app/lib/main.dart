import 'package:archive/archive.dart';
import 'package:fluff_archive/fluff_archive.dart';
import 'package:fluff_ops/fluff_ops.dart';
import 'package:fluff_remote/fluff_remote.dart';
import 'package:fluff_share/fluff_share.dart';
import 'package:fluff_skin/fluff_skin.dart';
import 'package:fluff_vfs/fluff_vfs.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'src/accounts_screen.dart';
import 'src/browse_screen.dart';
import 'src/servers_screen.dart';
import 'src/vault_screen.dart';

void main() {
  runApp(const FluffApp());
}

/// Top-level shell state: which mount is active.
enum _Mount { storage, vault, remote, archive, servers }

class FluffApp extends StatefulWidget {
  const FluffApp({super.key});

  @override
  State<FluffApp> createState() => _FluffAppState();
}

class _FluffAppState extends State<FluffApp> {
  final SkinController _skin = SkinController(
    mode: Uri.base.queryParameters['dark'] == '1'
        ? ThemeMode.dark
        : ThemeMode.system,
  );

  late final FsProvider _fs = MemFsProvider.demo();

  /// Backing FS for the encrypted vault container.
  late final FsProvider _vaultBacking = MemFsProvider(
    id: 'vault-backing',
    displayName: 'Vault container',
  );

  /// Phase 4 web slice: in-memory account store seeded with two
  /// representative mock accounts (one SMB, one SFTP).
  late final RemoteAccountStore _accounts = RemoteAccountStore(
    seed: [
      RemoteAccount(
        id: 'demo-smb',
        label: 'Home NAS',
        kind: RemoteKind.smb,
        host: 'nas.lan',
        share: 'media',
        username: 'guest',
      ),
      RemoteAccount(
        id: 'demo-sftp',
        label: 'VPS deploy',
        kind: RemoteKind.sftp,
        host: 'deploy.example',
        username: 'root',
      ),
    ],
  );

  /// Active remote provider (built lazily when a remote account is
  /// selected from the Accounts screen).
  MockRemoteFsProvider? _remoteProvider;

  /// Phase 5 web slice: a synthetic in-memory zip mounted via
  /// [ArchiveFsProvider].
  late final ArchiveFsProvider _archive = _buildDemoArchive();

  /// Phase 6 web slice: mock controller seeded with one entry per
  /// supported wire protocol (HTTP / WebDAV / FTP / SFTP / DLNA).
  late final ShareServerController _servers = ShareServerController(
    seed: defaultSeedServers(),
  );

  late final OperationQueue _queue = OperationQueue(
    providerLookup: (id) {
      if (id == _fs.id) return _fs;
      if (id == _vaultBacking.id) return _vaultBacking;
      if (id == _archive.id) return _archive;
      final rp = _remoteProvider;
      if (rp != null && id == rp.id) return rp;
      return null;
    },
  );

  _Mount _mount = _Mount.storage;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      final q = Uri.base.queryParameters;
      if ((q['vault'] ?? '').isNotEmpty) {
        _mount = _Mount.vault;
      } else if ((q['archive'] ?? '').isNotEmpty) {
        _mount = _Mount.archive;
      } else if ((q['remote'] ?? '').isNotEmpty) {
        _mount = _Mount.remote;
        final id = q['remote']!;
        final a = _accounts.byId(id);
        if (a != null) {
          _remoteProvider = MockRemoteFsProvider(account: a);
        }
      } else if (q['accounts'] == '1') {
        _mount = _Mount.remote;
      } else if (q['servers'] == '1' || (q['server'] ?? '').isNotEmpty) {
        _mount = _Mount.servers;
        final id = q['server'];
        if (id != null && id.isNotEmpty) {
          final s = _servers.byId(id);
          if (s != null && !s.isRunning) {
            _servers.start(s.id);
            // Seed a non-zero counter so the running tile demos
            // meaningful traffic without waiting for ticks.
            _servers.tick(bytes: 48 * 1024);
            _servers.tick(bytes: 48 * 1024);
          }
        }
      }
    }
  }

  @override
  void dispose() {
    _skin.dispose();
    _queue.dispose();
    // ignore: discarded_futures
    _accounts.dispose();
    // ignore: discarded_futures
    _servers.dispose();
    super.dispose();
  }

  ArchiveFsProvider _buildDemoArchive() {
    final archive = Archive()
      ..addFile(
        ArchiveFile.string(
          'README.txt',
          'fluff_archive demo bundle\n\n'
              'Open any text file inside this zip to confirm read-only '
              'streaming works end-to-end.\n',
        ),
      )
      ..addFile(
        ArchiveFile.string(
          'src/main.dart',
          "void main() => print('hello from inside an archive');\n",
        ),
      )
      ..addFile(
        ArchiveFile.string(
          'src/widgets/button.dart',
          '// fluff archive viewer sample\nclass Button {}\n',
        ),
      )
      ..addFile(
        ArchiveFile.string(
          'assets/logo.svg',
          '<svg xmlns="http://www.w3.org/2000/svg" />',
        ),
      )
      ..addFile(
        ArchiveFile.string('CHANGELOG.md', '## 0.1.0\n* initial demo bundle\n'),
      );
    final bytes = Uint8List.fromList(ZipEncoder().encode(archive));
    return ArchiveFsProvider.fromBytes(
      bytes: bytes,
      format: ArchiveFormat.zip,
      displayName: 'fluff-demo.zip',
      idSuffix: 'fluff-demo',
    );
  }

  void _selectMount(_Mount m) {
    setState(() => _mount = m);
  }

  void _openRemote(RemoteAccount account) {
    setState(() {
      _remoteProvider = MockRemoteFsProvider(account: account);
      _mount = _Mount.remote;
    });
  }

  Drawer _drawer(BuildContext context, _Mount selected) {
    final cs = Theme.of(context).colorScheme;
    Widget tile(_Mount m, IconData icon, String label) {
      final isSelected = m == selected;
      return ListTile(
        leading: Icon(icon, color: isSelected ? cs.primary : null),
        title: Text(label),
        selected: isSelected,
        onTap: () {
          Navigator.of(context).pop();
          _selectMount(m);
        },
      );
    }

    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 24, 20, 12),
              child: Text(
                'Fluff',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              ),
            ),
            const Divider(height: 1),
            tile(_Mount.storage, Icons.folder_outlined, 'Storage'),
            tile(_Mount.vault, Icons.lock_rounded, 'Vault'),
            tile(_Mount.remote, Icons.cloud_outlined, 'Remote accounts'),
            tile(_Mount.archive, Icons.archive_outlined, 'Archive viewer'),
            tile(_Mount.servers, Icons.dns_outlined, 'Servers'),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SkinScope(
      controller: _skin,
      builder: (context, light, dark, mode) => MaterialApp(
        title: 'Fluff',
        debugShowCheckedModeBanner: false,
        theme: light,
        darkTheme: dark,
        themeMode: mode,
        home: Builder(
          builder: (context) {
            switch (_mount) {
              case _Mount.storage:
                return BrowseScreen(
                  provider: _fs,
                  queue: _queue,
                  onToggleBrightness: () => _skin.toggleBrightness(context),
                  leadingDrawer: _drawer(context, _Mount.storage),
                );
              case _Mount.vault:
                return VaultScreen(
                  backing: _vaultBacking,
                  queue: _queue,
                  drawer: _drawer(context, _Mount.vault),
                  onToggleBrightness: () => _skin.toggleBrightness(context),
                );
              case _Mount.remote:
                final rp = _remoteProvider;
                if (rp == null) {
                  return AccountsScreen(
                    store: _accounts,
                    drawer: _drawer(context, _Mount.remote),
                    onToggleBrightness: () => _skin.toggleBrightness(context),
                    onOpen: _openRemote,
                  );
                }
                return BrowseScreen(
                  provider: rp,
                  queue: _queue,
                  onToggleBrightness: () => _skin.toggleBrightness(context),
                  leadingDrawer: _drawer(context, _Mount.remote),
                  appBarSuffix: IconButton(
                    tooltip: 'Disconnect',
                    icon: const Icon(Icons.logout_rounded),
                    onPressed: () => setState(() => _remoteProvider = null),
                  ),
                );
              case _Mount.archive:
                return BrowseScreen(
                  provider: _archive,
                  queue: _queue,
                  onToggleBrightness: () => _skin.toggleBrightness(context),
                  leadingDrawer: _drawer(context, _Mount.archive),
                );
              case _Mount.servers:
                return ServersScreen(
                  controller: _servers,
                  drawer: _drawer(context, _Mount.servers),
                  onToggleBrightness: () => _skin.toggleBrightness(context),
                );
            }
          },
        ),
      ),
    );
  }
}
