import 'dart:async';

import 'remote_account.dart';

/// In-memory store of [RemoteAccount]s. The Android build will back
/// this with a Keystore-protected JSON file in Phase 4.1.
class RemoteAccountStore {
  RemoteAccountStore({List<RemoteAccount> seed = const []}) {
    for (final a in seed) {
      _accounts[a.id] = a;
    }
  }

  final Map<String, RemoteAccount> _accounts = {};
  final StreamController<List<RemoteAccount>> _events =
      StreamController<List<RemoteAccount>>.broadcast();

  /// Snapshot of the current accounts, ordered by label.
  List<RemoteAccount> get accounts {
    final list = _accounts.values.toList();
    list.sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
    return list;
  }

  /// Notifications when the account set changes.
  Stream<List<RemoteAccount>> get changes => _events.stream;

  /// Insert or replace [account].
  void upsert(RemoteAccount account) {
    _accounts[account.id] = account;
    _events.add(accounts);
  }

  /// Remove the account with [id]. No-op if it isn't present.
  void remove(String id) {
    if (_accounts.remove(id) != null) {
      _events.add(accounts);
    }
  }

  /// Lookup by id.
  RemoteAccount? byId(String id) => _accounts[id];

  /// Close internal streams.
  Future<void> dispose() => _events.close();
}
