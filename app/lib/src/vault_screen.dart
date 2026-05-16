import 'package:fluff_ops/fluff_ops.dart';
import 'package:fluff_skin/fluff_skin.dart';
import 'package:fluff_vault/fluff_vault.dart';
import 'package:fluff_vfs/fluff_vfs.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'browse_screen.dart';

/// Three explicit states for the Vault screen.
enum _VaultPhase { locked, create, unlocked }

/// Encrypted-vault landing.
///
/// Web demo: uses an in-memory backing [MemFsProvider] for the
/// blob container so the password flow can be exercised
/// end-to-end without writing anything to disk.
class VaultScreen extends StatefulWidget {
  const VaultScreen({
    super.key,
    required this.backing,
    required this.queue,
    required this.onSwitchToStorage,
    this.onToggleBrightness,
  });

  /// Provider used to persist the encrypted vault container.
  final FsProvider backing;
  final OperationQueue queue;
  final VoidCallback onSwitchToStorage;
  final VoidCallback? onToggleBrightness;

  @override
  State<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends State<VaultScreen> {
  _VaultPhase _phase = _VaultPhase.locked;
  VaultFsProvider? _provider;
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirm = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      final q = Uri.base.queryParameters;
      final v = q['vault'];
      if (v == 'create') _phase = _VaultPhase.create;
      if (v == 'unlocked') {
        _phase = _VaultPhase.unlocked;
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          await _bootstrapDemoUnlockedState();
          if (mounted) setState(() {});
        });
      }
    }
  }

  Future<void> _bootstrapDemoUnlockedState() async {
    final vault = await Vault.create(password: 'demo');
    final p = VaultFsProvider(
      backing: widget.backing,
      containerDir: FsPath.parse('/.fluff-vault'),
      vault: vault,
    );
    await p.persistInitial();
    await p.mkdir(FsPath.parse('/Personal'));
    await p.mkdir(FsPath.parse('/Tax'));
    await p.writeBytes(
      FsPath.parse('/Personal/passport.pdf'),
      Uint8List.fromList(List.filled(512 * 1024, 0x50)),
    );
    await p.writeBytes(
      FsPath.parse('/Personal/recovery-codes.txt'),
      Uint8List.fromList('one-two-three-four\n'.codeUnits),
    );
    await p.writeBytes(
      FsPath.parse('/Tax/2025-return.pdf'),
      Uint8List.fromList(List.filled(900 * 1024, 0x42)),
    );
    _provider = p;
  }

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_password.text.isEmpty || _password.text != _confirm.text) {
      setState(() => _error = 'Passwords don\'t match');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final vault = await Vault.create(password: _password.text);
      final p = VaultFsProvider(
        backing: widget.backing,
        containerDir: FsPath.parse('/.fluff-vault'),
        vault: vault,
      );
      await p.persistInitial();
      if (!mounted) return;
      setState(() {
        _provider = p;
        _phase = _VaultPhase.unlocked;
        _password.clear();
        _confirm.clear();
      });
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _unlock() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final p = await VaultFsProvider.unlockFromBacking(
        backing: widget.backing,
        containerDir: FsPath.parse('/.fluff-vault'),
        password: _password.text,
      );
      if (!mounted) return;
      setState(() {
        _provider = p;
        _phase = _VaultPhase.unlocked;
        _password.clear();
      });
    } catch (_) {
      setState(() => _error = 'Wrong password — try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _lock() {
    setState(() {
      _provider = null;
      _phase = _VaultPhase.locked;
      _password.clear();
    });
  }

  bool _vaultExistsOnBacking() => false; // placeholder for Phase 3.1

  // ignore: unused_element
  bool get _suppressUnused => _vaultExistsOnBacking();

  @override
  Widget build(BuildContext context) {
    if (_phase == _VaultPhase.unlocked && _provider != null) {
      return BrowseScreen(
        provider: _provider!,
        queue: widget.queue,
        onToggleBrightness: widget.onToggleBrightness,
        leadingDrawer: _buildDrawer(context),
        appBarSuffix: IconButton(
          tooltip: 'Lock vault',
          icon: const Icon(Icons.lock_outline_rounded),
          onPressed: _lock,
        ),
      );
    }
    return _buildLockedOrCreateScaffold(context);
  }

  Scaffold _buildLockedOrCreateScaffold(BuildContext context) {
    final tokens = WlmTheme.of(context).tokens;
    final cs = Theme.of(context).colorScheme;
    final creating = _phase == _VaultPhase.create;
    return Scaffold(
      drawer: _buildDrawer(context),
      appBar: AppBar(
        title: const Text('Vault'),
        actions: [
          if (widget.onToggleBrightness != null)
            IconButton(
              tooltip: 'Toggle theme',
              icon: const Icon(Icons.brightness_6_outlined),
              onPressed: widget.onToggleBrightness,
            ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: tokens.spacing.lg,
              vertical: tokens.spacing.xl,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  creating ? Icons.shield_outlined : Icons.lock_rounded,
                  size: 56,
                  color: cs.primary,
                ),
                SizedBox(height: tokens.spacing.md),
                Text(
                  creating ? 'Create your vault' : 'Vault is locked',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                SizedBox(height: tokens.spacing.sm),
                Text(
                  creating
                      ? 'Choose a password. Files inside the vault '
                            'are encrypted with XChaCha20-Poly1305; '
                            'this password is never written to disk.'
                      : 'Enter your password to decrypt the index.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                SizedBox(height: tokens.spacing.lg),
                TextField(
                  controller: _password,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    border: const OutlineInputBorder(),
                    errorText: _error,
                  ),
                  onSubmitted: (_) => creating ? _create() : _unlock(),
                ),
                if (creating) ...[
                  SizedBox(height: tokens.spacing.md),
                  TextField(
                    controller: _confirm,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Confirm password',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _create(),
                  ),
                ],
                SizedBox(height: tokens.spacing.lg),
                FilledButton.icon(
                  onPressed: _busy ? null : (creating ? _create : _unlock),
                  icon: Icon(
                    creating ? Icons.shield_rounded : Icons.lock_open_rounded,
                  ),
                  label: Text(creating ? 'Create vault' : 'Unlock'),
                ),
                SizedBox(height: tokens.spacing.sm),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => setState(() {
                          _phase = creating
                              ? _VaultPhase.locked
                              : _VaultPhase.create;
                          _error = null;
                        }),
                  child: Text(
                    creating
                        ? 'I already have a vault'
                        : 'Create a new vault instead',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Drawer _buildDrawer(BuildContext context) {
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
              leading: const Icon(Icons.folder_outlined),
              title: const Text('Storage'),
              onTap: () {
                Navigator.of(context).pop();
                widget.onSwitchToStorage();
              },
            ),
            ListTile(
              leading: Icon(Icons.lock_rounded, color: cs.primary),
              title: const Text('Vault'),
              selected: true,
              onTap: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}
