import 'package:fluff_skin/fluff_skin.dart';
import 'package:fluff_sync/fluff_sync.dart';
import 'package:flutter/material.dart';

/// Phase 7 web slice: lists nearby devices from a [NearbyDiscovery]
/// mock and lets the user pair / unpair / forget them.
class NearbyScreen extends StatefulWidget {
  const NearbyScreen({
    super.key,
    required this.discovery,
    required this.drawer,
    this.onToggleBrightness,
  });

  final NearbyDiscovery discovery;
  final Drawer drawer;
  final VoidCallback? onToggleBrightness;

  @override
  State<NearbyScreen> createState() => _NearbyScreenState();
}

class _NearbyScreenState extends State<NearbyScreen> {
  @override
  void initState() {
    super.initState();
    widget.discovery.changes.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = WlmTheme.of(context).tokens;
    final devices = widget.discovery.devices;
    return Scaffold(
      drawer: widget.drawer,
      appBar: AppBar(
        title: const Text('Nearby devices'),
        actions: [
          if (widget.onToggleBrightness != null)
            IconButton(
              tooltip: 'Toggle theme',
              icon: const Icon(Icons.brightness_6_outlined),
              onPressed: widget.onToggleBrightness,
            ),
        ],
      ),
      body: devices.isEmpty
          ? const _EmptyState()
          : ListView.separated(
              padding: EdgeInsets.symmetric(
                horizontal: tokens.spacing.lg,
                vertical: tokens.spacing.md,
              ),
              itemCount: devices.length,
              separatorBuilder: (_, _) => SizedBox(height: tokens.spacing.sm),
              itemBuilder: (context, i) {
                final d = devices[i];
                return _DeviceTile(
                  device: d,
                  onToggle: () => d.paired
                      ? widget.discovery.unpair(d.id)
                      : widget.discovery.pair(d.id),
                  onForget: () => widget.discovery.forget(d.id),
                );
              },
            ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.wifi_tethering, size: 56, color: cs.primary),
          const SizedBox(height: 16),
          Text(
            'Looking for devices on your network…',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ),
    );
  }
}

class _DeviceTile extends StatelessWidget {
  const _DeviceTile({
    required this.device,
    required this.onToggle,
    required this.onForget,
  });

  final NearbyDevice device;
  final VoidCallback onToggle;
  final VoidCallback onForget;

  IconData get _icon => switch (device.kind) {
    NearbyDeviceKind.phone => Icons.smartphone_rounded,
    NearbyDeviceKind.tablet => Icons.tablet_mac_rounded,
    NearbyDeviceKind.laptop => Icons.laptop_mac_rounded,
    NearbyDeviceKind.desktop => Icons.desktop_windows_rounded,
    NearbyDeviceKind.tv => Icons.tv_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tokens = WlmTheme.of(context).tokens;
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.radius.md),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: tokens.spacing.md,
          vertical: tokens.spacing.sm,
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: device.paired
                  ? cs.primaryContainer
                  : cs.surfaceContainerHighest,
              foregroundColor: device.paired
                  ? cs.onPrimaryContainer
                  : cs.onSurfaceVariant,
              child: Icon(_icon),
            ),
            SizedBox(width: tokens.spacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    device.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${device.kind.name} · ${device.address}',
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                  ),
                ],
              ),
            ),
            FilledButton.tonal(
              onPressed: onToggle,
              child: Text(device.paired ? 'Unpair' : 'Pair'),
            ),
            IconButton(
              tooltip: 'Forget',
              icon: const Icon(Icons.close_rounded),
              onPressed: onForget,
            ),
          ],
        ),
      ),
    );
  }
}
