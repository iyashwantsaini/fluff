import 'package:meta/meta.dart';

import 'share_server_kind.dart';

/// One sharing endpoint the user can flip on or off.
///
/// The web slice keeps the model fully immutable; transitions go
/// through [ShareServerController] which returns a new [ShareServer]
/// for every change.
@immutable
class ShareServer {
  ShareServer({
    required this.id,
    required this.kind,
    required this.label,
    int? port,
    this.requiresAuth = false,
    this.username,
    this.isRunning = false,
    this.bytesServed = 0,
  }) : port = port ?? kind.defaultPort {
    if (id.isEmpty) {
      throw ArgumentError.value(id, 'id', 'must not be empty');
    }
    if (label.isEmpty) {
      throw ArgumentError.value(label, 'label', 'must not be empty');
    }
    if (this.port < 1 || this.port > 65535) {
      throw ArgumentError.value(this.port, 'port', 'must be 1..65535');
    }
    if (bytesServed < 0) {
      throw ArgumentError.value(
        bytesServed,
        'bytesServed',
        'must be non-negative',
      );
    }
    if (requiresAuth && (username == null || username!.isEmpty)) {
      throw ArgumentError('username is required when requiresAuth is true');
    }
  }

  /// Stable, opaque identifier (e.g. `srv-http-default`).
  final String id;

  /// Wire protocol exposed by this server.
  final ShareServerKind kind;

  /// Human-facing label shown in the UI.
  final String label;

  /// Port the server will bind to. Defaults to `kind.defaultPort`.
  final int port;

  /// Whether the server demands credentials.
  final bool requiresAuth;

  /// Username when [requiresAuth] is true; null otherwise.
  final String? username;

  /// Current running flag. Maintained by the controller.
  final bool isRunning;

  /// Cumulative bytes served since start. Web slice fakes this.
  final int bytesServed;

  /// Loopback URL that demos the running state in the UI.
  String get loopbackUrl => switch (kind) {
    ShareServerKind.http => 'http://0.0.0.0:$port/',
    ShareServerKind.webdav => 'http://0.0.0.0:$port/dav/',
    ShareServerKind.ftp => 'ftp://0.0.0.0:$port/',
    ShareServerKind.sftp => 'sftp://0.0.0.0:$port/',
    ShareServerKind.dlna => 'upnp://0.0.0.0:$port/',
  };

  /// Convenience copy-with used by [ShareServerController].
  ShareServer copyWith({
    String? label,
    int? port,
    bool? requiresAuth,
    String? username,
    bool? isRunning,
    int? bytesServed,
  }) {
    return ShareServer(
      id: id,
      kind: kind,
      label: label ?? this.label,
      port: port ?? this.port,
      requiresAuth: requiresAuth ?? this.requiresAuth,
      username: username ?? this.username,
      isRunning: isRunning ?? this.isRunning,
      bytesServed: bytesServed ?? this.bytesServed,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ShareServer &&
        other.id == id &&
        other.kind == kind &&
        other.label == label &&
        other.port == port &&
        other.requiresAuth == requiresAuth &&
        other.username == username &&
        other.isRunning == isRunning &&
        other.bytesServed == bytesServed;
  }

  @override
  int get hashCode => Object.hash(
    id,
    kind,
    label,
    port,
    requiresAuth,
    username,
    isRunning,
    bytesServed,
  );
}
