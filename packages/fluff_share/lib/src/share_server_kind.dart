/// Wire-protocol kind for a [ShareServer].
enum ShareServerKind {
  http('HTTP', 8080),
  webdav('WebDAV', 8081),
  ftp('FTP', 2121),
  sftp('SFTP', 2222),
  dlna('DLNA', 1900);

  const ShareServerKind(this.label, this.defaultPort);

  /// Short user-facing label (e.g. `HTTP`, `WebDAV`).
  final String label;

  /// Port the real Phase 6.1 implementation will bind to by
  /// default. Web-slice consumers can still override per server.
  final int defaultPort;
}
