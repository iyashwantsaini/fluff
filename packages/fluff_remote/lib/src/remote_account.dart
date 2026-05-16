import 'package:meta/meta.dart';

/// Wire protocol of a remote account.
enum RemoteKind {
  smb('SMB'),
  sftp('SFTP');

  const RemoteKind(this.label);

  /// Human-readable label.
  final String label;

  /// Default TCP port for this protocol.
  int get defaultPort => switch (this) {
    RemoteKind.smb => 445,
    RemoteKind.sftp => 22,
  };
}

/// A user-configured remote endpoint.
///
/// In the Phase 4 web slice this is paired with [MockRemoteFsProvider];
/// in Phase 4.1 the Android build pairs the same model with a real
/// `SmbFsProvider` (`smb_connect`) or `SftpFsProvider` (`dartssh2`).
@immutable
class RemoteAccount {
  RemoteAccount({
    required this.id,
    required this.label,
    required this.kind,
    required this.host,
    int? port,
    this.share,
    this.username,
  }) : port = port ?? kind.defaultPort {
    if (id.isEmpty) {
      throw ArgumentError.value(id, 'id', 'must not be empty');
    }
    if (label.trim().isEmpty) {
      throw ArgumentError.value(label, 'label', 'must not be empty');
    }
    if (host.trim().isEmpty) {
      throw ArgumentError.value(host, 'host', 'must not be empty');
    }
    if (this.port <= 0 || this.port > 65535) {
      throw ArgumentError.value(this.port, 'port', 'out of range');
    }
    if (kind == RemoteKind.smb && (share == null || share!.isEmpty)) {
      throw ArgumentError.value(share, 'share', 'SMB requires a share');
    }
  }

  /// Stable identifier (used as the [FsProvider.id] suffix).
  final String id;

  /// User-chosen display label.
  final String label;

  /// Wire protocol.
  final RemoteKind kind;

  /// Hostname or IP.
  final String host;

  /// TCP port.
  final int port;

  /// SMB share name. Required for [RemoteKind.smb], ignored for SFTP.
  final String? share;

  /// Username (optional — anonymous SMB / key-based SFTP allowed).
  final String? username;

  /// Compact one-line summary suitable for an account list subtitle.
  String get summary {
    final auth = (username == null || username!.isEmpty) ? '' : '$username@';
    final tail = kind == RemoteKind.smb && share != null ? '/$share' : '';
    return '${kind.label}  $auth$host:$port$tail';
  }
}
