import 'dart:async';

import 'share_server.dart';
import 'share_server_kind.dart';

/// Source-of-truth for the user's [ShareServer] list and their
/// running state.
///
/// The web slice mocks every transition synchronously and bumps a
/// fake [ShareServer.bytesServed] counter on each `tick` so the UI
/// can demo a running server. Phase 6.1 swaps the body of
/// [start] / [stop] / [tick] for real socket lifecycles.
class ShareServerController {
  ShareServerController({Iterable<ShareServer> seed = const []}) {
    for (final s in seed) {
      _servers[s.id] = s;
    }
  }

  final Map<String, ShareServer> _servers = {};
  final StreamController<List<ShareServer>> _events =
      StreamController<List<ShareServer>>.broadcast();

  /// Snapshot, sorted by kind then label (case-insensitive).
  List<ShareServer> get servers {
    final list = _servers.values.toList();
    list.sort((a, b) {
      final byKind = a.kind.index.compareTo(b.kind.index);
      if (byKind != 0) return byKind;
      return a.label.toLowerCase().compareTo(b.label.toLowerCase());
    });
    return list;
  }

  /// Emits a fresh snapshot after every mutation.
  Stream<List<ShareServer>> get changes => _events.stream;

  /// Add or replace a server (matched by [ShareServer.id]).
  void upsert(ShareServer server) {
    _servers[server.id] = server;
    _emit();
  }

  /// Remove a server by id. Returns `true` if it was present.
  bool remove(String id) {
    final removed = _servers.remove(id);
    if (removed == null) return false;
    _emit();
    return true;
  }

  /// Mark [id] as running. No-op if already running. Returns the
  /// resulting [ShareServer] (or null if the id is unknown).
  ShareServer? start(String id) {
    final current = _servers[id];
    if (current == null) return null;
    if (current.isRunning) return current;
    final next = current.copyWith(isRunning: true);
    _servers[id] = next;
    _emit();
    return next;
  }

  /// Mark [id] as stopped and clear its byte counter.
  ShareServer? stop(String id) {
    final current = _servers[id];
    if (current == null) return null;
    if (!current.isRunning) return current;
    final next = current.copyWith(isRunning: false, bytesServed: 0);
    _servers[id] = next;
    _emit();
    return next;
  }

  /// Toggle the running flag of [id].
  ShareServer? toggle(String id) {
    final current = _servers[id];
    if (current == null) return null;
    return current.isRunning ? stop(id) : start(id);
  }

  /// Web-slice traffic simulator: adds [bytes] to every running
  /// server's [ShareServer.bytesServed] counter.
  void tick({int bytes = 4096}) {
    var changed = false;
    for (final entry in _servers.entries.toList()) {
      final s = entry.value;
      if (!s.isRunning) continue;
      _servers[entry.key] = s.copyWith(bytesServed: s.bytesServed + bytes);
      changed = true;
    }
    if (changed) _emit();
  }

  /// Lookup helper used by the UI.
  ShareServer? byId(String id) => _servers[id];

  /// Release the event controller.
  Future<void> dispose() => _events.close();

  void _emit() => _events.add(servers);
}

/// Convenience: returns one entry per [ShareServerKind] with stable
/// ids and the kind's default port. Used to seed the demo UI and
/// the tests.
List<ShareServer> defaultSeedServers() {
  return [
    for (final kind in ShareServerKind.values)
      ShareServer(
        id: 'srv-${kind.name}-default',
        kind: kind,
        label: '${kind.label} share',
      ),
  ];
}
