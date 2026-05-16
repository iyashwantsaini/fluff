import 'package:fluff_ops/fluff_ops.dart';
import 'package:fluff_skin/fluff_skin.dart';
import 'package:fluff_vfs/fluff_vfs.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'src/browse_screen.dart';
import 'src/vault_screen.dart';

void main() {
  runApp(const FluffApp());
}

/// Top-level shell state: which mount is active.
enum _Mount { storage, vault }

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

  late final OperationQueue _queue = OperationQueue(
    providerLookup: (id) {
      if (id == _fs.id) return _fs;
      if (id == _vaultBacking.id) return _vaultBacking;
      return null;
    },
  );

  _Mount _mount = _Mount.storage;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      final v = Uri.base.queryParameters['vault'];
      if (v != null && v.isNotEmpty) {
        _mount = _Mount.vault;
      }
    }
  }

  @override
  void dispose() {
    _skin.dispose();
    _queue.dispose();
    super.dispose();
  }

  Drawer _drawer(BuildContext context, _Mount selected) {
    final cs = Theme.of(context).colorScheme;
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
            ListTile(
              leading: Icon(
                Icons.folder_outlined,
                color: selected == _Mount.storage ? cs.primary : null,
              ),
              title: const Text('Storage'),
              selected: selected == _Mount.storage,
              onTap: () {
                Navigator.of(context).pop();
                setState(() => _mount = _Mount.storage);
              },
            ),
            ListTile(
              leading: Icon(
                Icons.lock_rounded,
                color: selected == _Mount.vault ? cs.primary : null,
              ),
              title: const Text('Vault'),
              selected: selected == _Mount.vault,
              onTap: () {
                Navigator.of(context).pop();
                setState(() => _mount = _Mount.vault);
              },
            ),
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
                  onSwitchToStorage: () =>
                      setState(() => _mount = _Mount.storage),
                  onToggleBrightness: () => _skin.toggleBrightness(context),
                );
            }
          },
        ),
      ),
    );
  }
}
