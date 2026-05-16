import 'dart:async';
import 'dart:typed_data';

import 'fs_capabilities.dart';
import 'fs_node.dart';
import 'fs_path.dart';

/// The storage seam. Every Fluff screen talks to one of these and
/// nothing else — `dart:io.File` is forbidden in `app/`.
///
/// Implementations: [MemFsProvider] (in-memory mock, ships in this
/// package), `LocalFsProvider` (`dart:io`, lands in Phase 2),
/// archive / cloud / vault providers added per phase.
abstract class FsProvider {
  /// Human-readable provider id, e.g. `local`, `mem`, `archive:foo.zip`.
  String get id;

  /// Human-readable display name (e.g. `Internal Storage`).
  String get displayName;

  /// What this provider can do.
  FsCapabilities get capabilities;

  /// Default root for this provider.
  FsPath get root;

  /// Stat a single path. Returns `null` if it doesn't exist.
  Future<FsNode?> stat(FsPath path);

  /// List the children of [dir]. Throws if [dir] isn't a directory.
  Future<List<FsNode>> list(FsPath dir);

  /// Read the full contents of [file].
  Future<Uint8List> readBytes(FsPath file);

  /// Write [bytes] to [file], creating it if needed.
  Future<void> writeBytes(FsPath file, Uint8List bytes);

  /// Delete [path]. If it's a directory, [recursive] must be true.
  Future<void> delete(FsPath path, {bool recursive = false});

  /// Rename / move [from] to [to] within this provider.
  Future<void> rename(FsPath from, FsPath to);

  /// Create a directory at [path]. If [recursive], creates parents.
  Future<void> mkdir(FsPath path, {bool recursive = false});
}
