import 'dart:async';
import 'dart:io' as io;
import 'dart:typed_data';

import 'fs_capabilities.dart';
import 'fs_node.dart';
import 'fs_path.dart';
import 'fs_provider.dart';

/// [FsProvider] backed by `dart:io` against a real OS directory.
///
/// This is the only place in the workspace allowed to import
/// `dart:io` for filesystem access — `app/` MUST go through this.
///
/// Paths inside the provider are POSIX-style and rooted at `/`,
/// matching every other provider. They are translated to native
/// paths by joining onto [rootDir].
class LocalFsProvider implements FsProvider {
  @override
  final String id;

  @override
  final String displayName;

  @override
  final FsCapabilities capabilities = FsCapabilities.full;

  /// Native OS directory that path `/` maps to.
  final io.Directory rootDir;

  @override
  final FsPath root = FsPath.root;

  LocalFsProvider({
    required this.rootDir,
    this.id = 'local',
    this.displayName = 'Internal storage',
  });

  // --- path translation -------------------------------------------------

  String _native(FsPath p) {
    final rel = p.toString();
    if (rel == '/') return rootDir.path;
    // Strip leading `/` and join with the OS separator.
    final segs = rel.substring(1).split('/');
    return [rootDir.path, ...segs].join(io.Platform.pathSeparator);
  }

  FsPath _virtual(String native) {
    var rel = native;
    final rootPath = rootDir.path;
    if (rel.startsWith(rootPath)) {
      rel = rel.substring(rootPath.length);
    }
    rel = rel.replaceAll('\\', '/');
    if (rel.isEmpty) return FsPath.root;
    if (!rel.startsWith('/')) rel = '/$rel';
    return FsPath.parse(rel);
  }

  String? _guessMime(String name) {
    final dot = name.lastIndexOf('.');
    if (dot < 0) return null;
    final ext = name.substring(dot + 1).toLowerCase();
    return const {
      'txt': 'text/plain',
      'md': 'text/markdown',
      'csv': 'text/csv',
      'json': 'application/json',
      'xml': 'application/xml',
      'html': 'text/html',
      'png': 'image/png',
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'webp': 'image/webp',
      'gif': 'image/gif',
      'svg': 'image/svg+xml',
      'mp3': 'audio/mpeg',
      'flac': 'audio/flac',
      'ogg': 'audio/ogg',
      'wav': 'audio/wav',
      'mp4': 'video/mp4',
      'mkv': 'video/x-matroska',
      'webm': 'video/webm',
      'pdf': 'application/pdf',
      'epub': 'application/epub+zip',
      'zip': 'application/zip',
      'apk': 'application/vnd.android.package-archive',
    }[ext];
  }

  // --- FsProvider -------------------------------------------------------

  @override
  Future<FsNode?> stat(FsPath path) async {
    final native = _native(path);
    final type = await io.FileSystemEntity.type(native, followLinks: false);
    if (type == io.FileSystemEntityType.notFound) return null;
    return _statNative(native, type);
  }

  Future<FsNode> _statNative(
    String native,
    io.FileSystemEntityType type,
  ) async {
    final p = _virtual(native);
    final isDir = type == io.FileSystemEntityType.directory;
    final isLink = type == io.FileSystemEntityType.link;
    int size = 0;
    DateTime? mod;
    try {
      if (isDir) {
        final s = await io.Directory(native).stat();
        mod = s.modified;
      } else {
        final s = await io.File(native).stat();
        size = s.size;
        mod = s.modified;
      }
    } on io.FileSystemException {
      // Unreadable entry (e.g. /storage/emulated/0/Android/data on
      // recent Android). Still return a node so the UI can render it.
    }
    return FsNode(
      path: p,
      kind: isDir
          ? FsNodeKind.directory
          : isLink
          ? FsNodeKind.symlink
          : FsNodeKind.file,
      size: size,
      modified: mod,
      mimeType: isDir ? null : _guessMime(p.name),
      isHidden: p.name.startsWith('.'),
    );
  }

  @override
  Future<List<FsNode>> list(FsPath dir) async {
    final native = _native(dir);
    final d = io.Directory(native);
    final out = <FsNode>[];
    await for (final entry in d.list(followLinks: false)) {
      try {
        final type = await io.FileSystemEntity.type(
          entry.path,
          followLinks: false,
        );
        out.add(await _statNative(entry.path, type));
      } on io.FileSystemException {
        // Skip entries we can't stat (permission denied on a single
        // child shouldn't kill the whole listing).
      }
    }
    out.sort((a, b) {
      if (a.isDirectory != b.isDirectory) {
        return a.isDirectory ? -1 : 1;
      }
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return out;
  }

  @override
  Future<Uint8List> readBytes(FsPath file) async {
    final bytes = await io.File(_native(file)).readAsBytes();
    return Uint8List.fromList(bytes);
  }

  @override
  Future<void> writeBytes(FsPath file, Uint8List bytes) async {
    final f = io.File(_native(file));
    await f.parent.create(recursive: true);
    await f.writeAsBytes(bytes, flush: true);
  }

  @override
  Future<void> delete(FsPath path, {bool recursive = false}) async {
    final native = _native(path);
    final type = await io.FileSystemEntity.type(native, followLinks: false);
    if (type == io.FileSystemEntityType.notFound) return;
    if (type == io.FileSystemEntityType.directory) {
      await io.Directory(native).delete(recursive: recursive);
    } else {
      await io.File(native).delete();
    }
  }

  @override
  Future<void> rename(FsPath from, FsPath to) async {
    final src = _native(from);
    final dst = _native(to);
    final type = await io.FileSystemEntity.type(src, followLinks: false);
    if (type == io.FileSystemEntityType.directory) {
      await io.Directory(src).rename(dst);
    } else {
      await io.File(src).rename(dst);
    }
  }

  @override
  Future<void> mkdir(FsPath path, {bool recursive = false}) async {
    await io.Directory(_native(path)).create(recursive: recursive);
  }
}
