import 'package:fluff_skin/fluff_skin.dart';
import 'package:flutter/material.dart';

/// Phase 9 web slice: Settings + About screen. Surfaces theme
/// mode, accessibility toggles (mock), and release-channel info.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.skin,
    required this.drawer,
    this.onToggleBrightness,
  });

  final SkinController skin;
  final Drawer drawer;
  final VoidCallback? onToggleBrightness;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Mock accessibility prefs (web slice — not persisted).
  bool _largeText = false;
  bool _reduceMotion = false;
  bool _highContrast = false;
  bool _hapticOnLongPress = true;

  @override
  Widget build(BuildContext context) {
    final tokens = WlmTheme.of(context).tokens;
    return Scaffold(
      drawer: widget.drawer,
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          if (widget.onToggleBrightness != null)
            IconButton(
              tooltip: 'Toggle theme',
              icon: const Icon(Icons.brightness_6_outlined),
              onPressed: widget.onToggleBrightness,
            ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.symmetric(
          horizontal: tokens.spacing.lg,
          vertical: tokens.spacing.md,
        ),
        children: [
          _Section(
            title: 'Appearance',
            children: [_ThemeModeRow(skin: widget.skin)],
          ),
          SizedBox(height: tokens.spacing.lg),
          _Section(
            title: 'Accessibility',
            children: [
              SwitchListTile(
                value: _largeText,
                onChanged: (v) => setState(() => _largeText = v),
                title: const Text('Large text'),
                subtitle: const Text('Scale body copy to 125 %.'),
                contentPadding: EdgeInsets.zero,
              ),
              SwitchListTile(
                value: _reduceMotion,
                onChanged: (v) => setState(() => _reduceMotion = v),
                title: const Text('Reduce motion'),
                subtitle: const Text('Disable list-shuffle animations.'),
                contentPadding: EdgeInsets.zero,
              ),
              SwitchListTile(
                value: _highContrast,
                onChanged: (v) => setState(() => _highContrast = v),
                title: const Text('High contrast'),
                subtitle: const Text('Bump outline + text contrast ratios.'),
                contentPadding: EdgeInsets.zero,
              ),
              SwitchListTile(
                value: _hapticOnLongPress,
                onChanged: (v) => setState(() => _hapticOnLongPress = v),
                title: const Text('Haptic on long-press'),
                subtitle: const Text('Vibrate when entering multi-select.'),
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
          SizedBox(height: tokens.spacing.lg),
          _Section(
            title: 'About',
            children: const [
              _AboutRow(label: 'App', value: 'Fluff'),
              _AboutRow(label: 'Version', value: '1.0.0-rc.1'),
              _AboutRow(label: 'Channel', value: 'F-Droid · stable'),
              _AboutRow(
                label: 'Source',
                value: 'github.com/iyashwantsaini/fluff',
              ),
              _AboutRow(label: 'Telemetry', value: 'None. Ever.'),
            ],
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tokens = WlmTheme.of(context).tokens;
    return Container(
      padding: EdgeInsets.all(tokens.spacing.md),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(tokens.radius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: cs.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          ...children,
        ],
      ),
    );
  }
}

class _ThemeModeRow extends StatelessWidget {
  const _ThemeModeRow({required this.skin});
  final SkinController skin;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: skin,
      builder: (context, _) {
        final mode = skin.mode;
        return SegmentedButton<ThemeMode>(
          segments: const [
            ButtonSegment(
              value: ThemeMode.light,
              icon: Icon(Icons.light_mode_outlined),
              label: Text('Light'),
            ),
            ButtonSegment(
              value: ThemeMode.system,
              icon: Icon(Icons.brightness_auto_outlined),
              label: Text('System'),
            ),
            ButtonSegment(
              value: ThemeMode.dark,
              icon: Icon(Icons.dark_mode_outlined),
              label: Text('Dark'),
            ),
          ],
          selected: {mode},
          onSelectionChanged: (s) => skin.setMode(s.first),
        );
      },
    );
  }
}

class _AboutRow extends StatelessWidget {
  const _AboutRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: TextStyle(color: cs.onSurfaceVariant)),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
