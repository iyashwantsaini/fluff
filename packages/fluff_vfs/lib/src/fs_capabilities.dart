/// Capabilities advertised by an [FsProvider]. UIs use this to decide
/// which actions are enabled — e.g. only show the "Rename" menu item
/// if the provider supports it.
class FsCapabilities {
  /// Provider can list directory contents.
  final bool canList;

  /// Provider can read file bytes.
  final bool canRead;

  /// Provider can create / overwrite files.
  final bool canWrite;

  /// Provider can delete entries.
  final bool canDelete;

  /// Provider can rename / move entries.
  final bool canRename;

  /// Provider can produce a thumbnail for a node.
  final bool canThumbnail;

  /// Provider can stream-read very large files efficiently.
  final bool canStreamRead;

  const FsCapabilities({
    this.canList = false,
    this.canRead = false,
    this.canWrite = false,
    this.canDelete = false,
    this.canRename = false,
    this.canThumbnail = false,
    this.canStreamRead = false,
  });

  /// All capabilities on. Useful default for fully-fledged providers.
  static const FsCapabilities full = FsCapabilities(
    canList: true,
    canRead: true,
    canWrite: true,
    canDelete: true,
    canRename: true,
    canThumbnail: true,
    canStreamRead: true,
  );

  /// Read-only. Useful for archive providers.
  static const FsCapabilities readOnly = FsCapabilities(
    canList: true,
    canRead: true,
    canStreamRead: true,
  );
}
