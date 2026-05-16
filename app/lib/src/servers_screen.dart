import 'package:fluff_share/fluff_share.dart';
import 'package:fluff_skin/fluff_skin.dart';
import 'package:flutter/material.dart';

/// Phase 6 web slice: lists [ShareServer]s in a [ShareServerController]
/// and lets the user start / stop / delete each one.
///
/// The Phase 6.1 work replaces the controller's body with real
/// `dart:io` socket lifecycles; this screen does not change.
class ServersScreen extends StatefulWidget {
  const ServersScreen({
    super.key,
    required this.controller,
    required this.drawer,
    this.onToggleBrightness,
  });

  final ShareServerController controller;
  final Drawer drawer;
  final VoidCallback? onToggleBrightness;

  @override
  State<ServersScreen> createState() => _ServersScreenState();
}

class _ServersScreenState extends State<ServersScreen> {
  @override
  void initState() {
    super.initState();
    widget.controller.changes.listen((_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _addServer() async {
    final created = await showDialog<ShareServer>(
      context: context,
      builder: (_) => const _AddServerDialog(),
    );
    if (created != null) {
      widget.controller.upsert(created);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = WlmTheme.of(context).tokens;
    final servers = widget.controller.servers;
    return Scaffold(
      drawer: widget.drawer,
      appBar: AppBar(
        title: const Text('Servers'),
        actions: [
          if (widget.onToggleBrightness != null)
            IconButton(
              tooltip: 'Toggle theme',
              icon: const Icon(Icons.brightness_6_outlined),
              onPressed: widget.onToggleBrightness,
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addServer,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add server'),
      ),
      body: servers.isEmpty
          ? const _EmptyState()
          : ListView.separated(
              padding: EdgeInsets.symmetric(
                horizontal: tokens.spacing.lg,
                vertical: tokens.spacing.md,
              ),
              itemCount: servers.length,
              separatorBuilder: (_, _) => SizedBox(height: tokens.spacing.sm),
              itemBuilder: (context, i) {
                final s = servers[i];
                return _ServerTile(
                  server: s,
                  onToggle: () => widget.controller.toggle(s.id),
                  onDelete: () => widget.controller.remove(s.id),
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
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.dns_outlined, size: 56, color: cs.primary),
            const SizedBox(height: 16),
            Text(
              'No servers yet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Add an HTTP, WebDAV, FTP, SFTP or DLNA endpoint to '
              'serve your files over the network.',
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _ServerTile extends StatelessWidget {
  const _ServerTile({
    required this.server,
    required this.onToggle,
    required this.onDelete,
  });

  final ShareServer server;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  IconData get _icon => switch (server.kind) {
    ShareServerKind.http => Icons.public_rounded,
    ShareServerKind.webdav => Icons.cloud_done_outlined,
    ShareServerKind.ftp => Icons.upload_file_outlined,
    ShareServerKind.sftp => Icons.shield_outlined,
    ShareServerKind.dlna => Icons.cast_outlined,
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
              backgroundColor: server.isRunning
                  ? cs.primary
                  : cs.surfaceContainerHighest,
              foregroundColor: server.isRunning
                  ? cs.onPrimary
                  : cs.onSurfaceVariant,
              child: Icon(_icon),
            ),
            SizedBox(width: tokens.spacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          server.label,
                          style: Theme.of(context).textTheme.titleMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _StatusChip(running: server.isRunning),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    server.loopbackUrl,
                    style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (server.isRunning) ...[
                    const SizedBox(height: 2),
                    Text(
                      '${_humanBytes(server.bytesServed)} served',
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Switch(value: server.isRunning, onChanged: (_) => onToggle()),
            IconButton(
              tooltip: 'Remove',
              icon: const Icon(Icons.delete_outline),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.running});
  final bool running;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = running ? cs.primaryContainer : cs.surfaceContainerHighest;
    final fg = running ? cs.onPrimaryContainer : cs.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        running ? 'running' : 'stopped',
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}

String _humanBytes(int n) {
  const units = ['B', 'KiB', 'MiB', 'GiB'];
  var v = n.toDouble();
  var i = 0;
  while (v >= 1024 && i < units.length - 1) {
    v /= 1024;
    i++;
  }
  return '${v.toStringAsFixed(v >= 100 || i == 0 ? 0 : 1)} ${units[i]}';
}

class _AddServerDialog extends StatefulWidget {
  const _AddServerDialog();

  @override
  State<_AddServerDialog> createState() => _AddServerDialogState();
}

class _AddServerDialogState extends State<_AddServerDialog> {
  ShareServerKind _kind = ShareServerKind.http;
  final _label = TextEditingController();
  final _port = TextEditingController();
  final _username = TextEditingController();
  bool _requiresAuth = false;

  @override
  void dispose() {
    _label.dispose();
    _port.dispose();
    _username.dispose();
    super.dispose();
  }

  void _submit() {
    final label = _label.text.trim();
    if (label.isEmpty) return;
    final portText = _port.text.trim();
    final port = portText.isEmpty ? null : int.tryParse(portText);
    try {
      final s = ShareServer(
        id: 'srv-${DateTime.now().microsecondsSinceEpoch}',
        kind: _kind,
        label: label,
        port: port,
        requiresAuth: _requiresAuth,
        username: _requiresAuth ? _username.text.trim() : null,
      );
      Navigator.of(context).pop(s);
    } on ArgumentError catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add server'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<ShareServerKind>(
              segments: const [
                ButtonSegment(
                  value: ShareServerKind.http,
                  label: Text('HTTP'),
                ),
                ButtonSegment(
                  value: ShareServerKind.webdav,
                  label: Text('WebDAV'),
                ),
                ButtonSegment(value: ShareServerKind.ftp, label: Text('FTP')),
                ButtonSegment(
                  value: ShareServerKind.sftp,
                  label: Text('SFTP'),
                ),
                ButtonSegment(
                  value: ShareServerKind.dlna,
                  label: Text('DLNA'),
                ),
              ],
              selected: {_kind},
              onSelectionChanged: (set) => setState(() => _kind = set.first),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _label,
              decoration: const InputDecoration(labelText: 'Label'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _port,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Port',
                hintText: '${_kind.defaultPort}',
              ),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Require authentication'),
              value: _requiresAuth,
              onChanged: (v) => setState(() => _requiresAuth = v),
            ),
            if (_requiresAuth)
              TextField(
                controller: _username,
                decoration: const InputDecoration(labelText: 'Username'),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Add')),
      ],
    );
  }
}
