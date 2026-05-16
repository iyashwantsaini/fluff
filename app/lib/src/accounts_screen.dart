import 'package:fluff_remote/fluff_remote.dart';
import 'package:fluff_skin/fluff_skin.dart';
import 'package:flutter/material.dart';

/// Phase 4 web slice: lists [RemoteAccount]s, supports adding a new
/// account through a small dialog, and opens an account into a
/// [MockRemoteFsProvider]-backed BrowseScreen via [onOpen].
class AccountsScreen extends StatefulWidget {
  const AccountsScreen({
    super.key,
    required this.store,
    required this.drawer,
    required this.onOpen,
    this.onToggleBrightness,
  });

  final RemoteAccountStore store;
  final Drawer drawer;
  final void Function(RemoteAccount account) onOpen;
  final VoidCallback? onToggleBrightness;

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  @override
  void initState() {
    super.initState();
    widget.store.changes.listen((_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _addAccount() async {
    final created = await showDialog<RemoteAccount>(
      context: context,
      builder: (_) => const _AddAccountDialog(),
    );
    if (created != null) {
      widget.store.upsert(created);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = WlmTheme.of(context).tokens;
    final accounts = widget.store.accounts;
    return Scaffold(
      drawer: widget.drawer,
      appBar: AppBar(
        title: const Text('Remote accounts'),
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
        onPressed: _addAccount,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add account'),
      ),
      body: accounts.isEmpty
          ? _EmptyState(onAdd: _addAccount)
          : ListView.separated(
              padding: EdgeInsets.symmetric(
                horizontal: tokens.spacing.lg,
                vertical: tokens.spacing.md,
              ),
              itemCount: accounts.length,
              separatorBuilder: (_, _) => SizedBox(height: tokens.spacing.sm),
              itemBuilder: (context, i) {
                final a = accounts[i];
                return _AccountTile(
                  account: a,
                  onOpen: () => widget.onOpen(a),
                  onDelete: () => widget.store.remove(a.id),
                );
              },
            ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_outlined, size: 56, color: cs.primary),
            const SizedBox(height: 12),
            Text(
              'No remote accounts yet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Add an SMB share or SFTP server to browse it alongside '
              'your local storage.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add account'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({
    required this.account,
    required this.onOpen,
    required this.onDelete,
  });

  final RemoteAccount account;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final icon = account.kind == RemoteKind.smb
        ? Icons.dns_outlined
        : Icons.terminal_rounded;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: cs.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: cs.primaryContainer,
          foregroundColor: cs.onPrimaryContainer,
          child: Icon(icon),
        ),
        title: Text(
          account.label,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(account.summary),
        trailing: IconButton(
          tooltip: 'Remove',
          icon: const Icon(Icons.delete_outline_rounded),
          onPressed: onDelete,
        ),
        onTap: onOpen,
      ),
    );
  }
}

class _AddAccountDialog extends StatefulWidget {
  const _AddAccountDialog();

  @override
  State<_AddAccountDialog> createState() => _AddAccountDialogState();
}

class _AddAccountDialogState extends State<_AddAccountDialog> {
  RemoteKind _kind = RemoteKind.sftp;
  final _label = TextEditingController();
  final _host = TextEditingController();
  final _port = TextEditingController();
  final _share = TextEditingController();
  final _user = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _label.dispose();
    _host.dispose();
    _port.dispose();
    _share.dispose();
    _user.dispose();
    super.dispose();
  }

  void _submit() {
    try {
      final acc = RemoteAccount(
        id: 'acc-${DateTime.now().microsecondsSinceEpoch}',
        label: _label.text.trim(),
        kind: _kind,
        host: _host.text.trim(),
        port: _port.text.trim().isEmpty
            ? null
            : int.tryParse(_port.text.trim()),
        share: _kind == RemoteKind.smb && _share.text.trim().isNotEmpty
            ? _share.text.trim()
            : null,
        username: _user.text.trim().isEmpty ? null : _user.text.trim(),
      );
      Navigator.of(context).pop(acc);
    } catch (e) {
      setState(() => _error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add account'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<RemoteKind>(
              segments: const [
                ButtonSegment(value: RemoteKind.sftp, label: Text('SFTP')),
                ButtonSegment(value: RemoteKind.smb, label: Text('SMB')),
              ],
              selected: {_kind},
              onSelectionChanged: (s) => setState(() => _kind = s.first),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _label,
              decoration: const InputDecoration(
                labelText: 'Label',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _host,
              decoration: const InputDecoration(
                labelText: 'Host',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _port,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Port (default ${_kind.defaultPort})',
                border: const OutlineInputBorder(),
              ),
            ),
            if (_kind == RemoteKind.smb) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _share,
                decoration: const InputDecoration(
                  labelText: 'Share',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
            const SizedBox(height: 8),
            TextField(
              controller: _user,
              decoration: const InputDecoration(
                labelText: 'Username (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
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

// Phase 4.1 will replace this with a Keystore-backed JSON serializer.
@visibleForTesting
RemoteAccountStore demoAccountStore() => RemoteAccountStore();
