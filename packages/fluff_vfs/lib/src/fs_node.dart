import 'package:meta/meta.dart';

import 'fs_path.dart';

/// Whether a node is a regular file, a directory, or a symlink.
enum FsNodeKind { file, directory, symlink }

/// A single entry in a virtual filesystem.
@immutable
class FsNode {
  /// Absolute path within the owning [FsProvider].
  final FsPath path;

  /// File / directory / symlink.
  final FsNodeKind kind;

  /// Size in bytes (0 for directories).
  final int size;

  /// Last-modified time, or `null` if the provider doesn't know.
  final DateTime? modified;

  /// MIME type guess for files; `null` for directories.
  final String? mimeType;

  /// Whether the underlying entry is hidden (dotfile, etc.).
  final bool isHidden;

  const FsNode({
    required this.path,
    required this.kind,
    this.size = 0,
    this.modified,
    this.mimeType,
    this.isHidden = false,
  });

  /// Convenience: filename without the path.
  String get name => path.name;

  /// True iff [kind] is [FsNodeKind.directory].
  bool get isDirectory => kind == FsNodeKind.directory;

  /// True iff [kind] is [FsNodeKind.file].
  bool get isFile => kind == FsNodeKind.file;
}
