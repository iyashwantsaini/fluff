import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fluff_skin/fluff_skin.dart';
import 'package:permission_handler/permission_handler.dart';

import 'prefs.dart';

/// First-run wizard. Shown once, on the first launch after install,
/// before the main shell is reachable. Persists completion in
/// [Prefs.firstRunComplete].
///
/// Pages: welcome → storage permission → theme pick → feature tour
/// → done. On non-Android platforms the permission page is skipped.
class OnboardingScreen extends StatefulWidget {
  /// Fired when the user finishes (or skips through) the wizard.
  final VoidCallback onFinished;

  /// Controller for live theme changes from the theme page.
  final SkinController skin;

  const OnboardingScreen({
    super.key,
    required this.onFinished,
    required this.skin,
  });

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pc = PageController();
  int _index = 0;

  bool get _isAndroid {
    if (kIsWeb) return false;
    try {
      return Platform.isAndroid;
    } on UnsupportedError {
      return false;
    }
  }

  List<Widget> _pages(BuildContext context) {
    return [
      const _WelcomePage(),
      if (_isAndroid) const _PermissionPage(),
      _ThemePage(skin: widget.skin),
      const _FeaturePage(),
      _DonePage(onFinish: _finish),
    ];
  }

  Future<void> _finish() async {
    await Prefs.instance.setFirstRunComplete(true);
    if (!mounted) return;
    widget.onFinished();
  }

  void _next() {
    final last = _pages(context).length - 1;
    if (_index >= last) {
      _finish();
      return;
    }
    _pc.nextPage(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
  }

  void _back() {
    if (_index == 0) return;
    _pc.previousPage(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final pages = _pages(context);
    final isLast = _index == pages.length - 1;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pc,
                onPageChanged: (i) => setState(() => _index = i),
                children: pages,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(pages.length, (i) {
                      final on = i == _index;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        height: 8,
                        width: on ? 24 : 8,
                        decoration: BoxDecoration(
                          color: on
                              ? cs.primary
                              : cs.primary.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      TextButton(
                        onPressed: _index == 0 ? null : _back,
                        child: const Text('Back'),
                      ),
                      const Spacer(),
                      if (!isLast)
                        TextButton(
                          onPressed: _finish,
                          child: const Text('Skip'),
                        ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: _next,
                        child: Text(isLast ? 'Open Fluff' : 'Continue'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _WelcomePage extends StatelessWidget {
  const _WelcomePage();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 48, 28, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFB69DF8), Color(0xFF4F378B)],
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            alignment: Alignment.center,
            child: const Text(
              'Fl',
              style: TextStyle(
                fontSize: 44,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Welcome to Fluff',
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Text(
            'A pure-Flutter file manager for your Android device. '
            'No telemetry, no ads, no account.',
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          _bullet(
            context,
            Icons.folder_outlined,
            'Browse, copy, move, rename, and search your files.',
          ),
          _bullet(
            context,
            Icons.lock_rounded,
            'Encrypted vault for sensitive documents.',
          ),
          _bullet(
            context,
            Icons.cloud_outlined,
            'Connect to remote shares (SMB, SFTP, WebDAV, FTP).',
          ),
          _bullet(
            context,
            Icons.wifi_tethering,
            'Nearby transfer with other devices on your network.',
          ),
        ],
      ),
    );
  }

  Widget _bullet(BuildContext context, IconData icon, String text) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: cs.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _PermissionPage extends StatefulWidget {
  const _PermissionPage();

  @override
  State<_PermissionPage> createState() => _PermissionPageState();
}

class _PermissionPageState extends State<_PermissionPage> {
  bool _busy = false;
  bool? _granted;

  Future<void> _request() async {
    setState(() => _busy = true);
    // Try all-files access first; fall back to legacy storage perms.
    var status = await Permission.manageExternalStorage.request();
    if (!status.isGranted) {
      status = await Permission.storage.request();
    }
    if (!mounted) return;
    setState(() {
      _granted = status.isGranted;
      _busy = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 48, 28, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.folder_open_rounded, size: 56, color: cs.primary),
          const SizedBox(height: 24),
          Text(
            'Storage access',
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Text(
            'Fluff needs access to your device storage so it can list, '
            'open, and modify your real files. Permissions are checked '
            'locally; nothing is sent off-device.',
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _busy ? null : _request,
            icon: const Icon(Icons.shield_outlined),
            label: Text(
              _granted == true
                  ? 'Granted'
                  : _granted == false
                  ? 'Try again'
                  : 'Grant access',
            ),
          ),
          const SizedBox(height: 12),
          if (_granted == false)
            Text(
              'Permission denied. You can grant it later in '
              'system Settings → Apps → Fluff.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: cs.error),
            ),
          if (_granted == true)
            Text(
              'You\'re all set. Internal storage will appear on the '
              'next screen.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: cs.primary),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _ThemePage extends StatefulWidget {
  final SkinController skin;
  const _ThemePage({required this.skin});

  @override
  State<_ThemePage> createState() => _ThemePageState();
}

class _ThemePageState extends State<_ThemePage> {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final mode = widget.skin.mode;
    Widget tile(ThemeMode m, IconData icon, String title, String subtitle) {
      final selected = mode == m;
      return Card(
        elevation: 0,
        color: selected ? cs.primaryContainer : cs.surfaceContainerHighest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: selected ? cs.primary : Colors.transparent,
            width: 2,
          ),
        ),
        child: ListTile(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          leading: Icon(icon, color: selected ? cs.primary : null),
          title: Text(title),
          subtitle: Text(subtitle),
          trailing: selected
              ? Icon(Icons.check_circle_rounded, color: cs.primary)
              : null,
          onTap: () {
            setState(() {});
            widget.skin.setMode(m);
          },
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 48, 28, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.palette_outlined, size: 56, color: cs.primary),
          const SizedBox(height: 24),
          Text(
            'Pick a theme',
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Text(
            'You can change this any time from Settings.',
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          tile(
            ThemeMode.system,
            Icons.brightness_auto_rounded,
            'System',
            'Follows your device setting.',
          ),
          const SizedBox(height: 8),
          tile(
            ThemeMode.light,
            Icons.light_mode_rounded,
            'Light',
            'Bright surfaces, dark text.',
          ),
          const SizedBox(height: 8),
          tile(
            ThemeMode.dark,
            Icons.dark_mode_rounded,
            'Dark',
            'Easy on the eyes at night.',
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _FeaturePage extends StatelessWidget {
  const _FeaturePage();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 48, 28, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.auto_awesome_rounded, size: 56, color: cs.primary),
          const SizedBox(height: 24),
          Text(
            'What\'s inside',
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          _feat(
            context,
            Icons.lock_rounded,
            'Encrypted vault',
            'XChaCha20-Poly1305 + Argon2id. Your passphrase never '
                'leaves the device.',
          ),
          _feat(
            context,
            Icons.cloud_outlined,
            'Remote storage',
            'Mount SMB shares, SFTP servers, WebDAV and FTP — '
                'browse them like any local folder.',
          ),
          _feat(
            context,
            Icons.sync_rounded,
            'Two-way sync',
            'Diff and reconcile folders between any two mounts. '
                'Conflicts get a clear resolve sheet.',
          ),
          _feat(
            context,
            Icons.wifi_tethering,
            'Nearby transfer',
            'Send files to nearby devices over the local network '
                'with no internet round-trip.',
          ),
          _feat(
            context,
            Icons.image_outlined,
            'Native viewers',
            'Images, text, markdown, hex, PDF, EPUB, archives — '
                'all open in-app, no third-party redirects.',
          ),
        ],
      ),
    );
  }

  Widget _feat(BuildContext context, IconData icon, String title, String body) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 20, color: cs.onPrimaryContainer),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _DonePage extends StatelessWidget {
  final VoidCallback onFinish;
  const _DonePage({required this.onFinish});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 48, 28, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_rounded, size: 96, color: cs.primary),
          const SizedBox(height: 24),
          Text(
            'You\'re ready',
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Tap "Open Fluff" to start browsing your device storage.',
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
