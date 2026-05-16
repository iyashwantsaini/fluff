import 'dart:async';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:fluff_vfs/fluff_vfs.dart';

/// Supported archive formats for the Phase 5 web slice.
enum ArchiveFormat {
  zip('zip', 'application/zip'),
  tar('tar', 'application/x-tar'),
  tarGz('tar.gz', 'application/gzip');

  const ArchiveFormat(this.extension, this.mimeType);

  /// Canonical file extension (no leading dot).
  final String extension;

  /// IANA media type.
  final String mimeType;

  /// Best-guess format from a file name's extension, or `null`.
  static ArchiveFormat? sniff(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.zip')) return zip;
    if (lower.endsWith('.tar.gz') || lower.endsWith('.tgz')) return tarGz;
    if (lower.endsWith('.tar')) return tar;
    return null;
  }
}

/// Read-only [FsProvider] backed by the contents of an in-memory
/// archive blob. Write operations throw `UnsupportedError` — to edit
/// an archive in Phase 5 you copy entries to another provider, edit
/// there, and re-pack.
class ArchiveFsProvider implements FsProvider {
  ArchiveFsProvider._({
    required this.id,
    required this.displayName,
    required Map<String, Uint8List> files,
    required Set<String> dirs,
    required Map<String, DateTime> modified,
  }) : _files = files,
       _dirs = dirs,
       _modified = modified;

  /// Decode [bytes] as [format] and return a provider whose root is
  /// the archive's root.
  factory ArchiveFsProvider.fromBytes({
    required Uint8List bytes,
    required ArchiveFormat format,
    required String displayName,
    String idSuffix = 'archive',
  }) {
    final Archive archive = switch (format) {
      ArchiveFormat.zip => ZipDecoder().decodeBytes(bytes),
      ArchiveFormat.tar => TarDecoder().decodeBytes(bytes),
      ArchiveFormat.tarGz => TarDecoder().decodeBytes(
        GZipDecoder().decodeBytes(bytes),
      ),
    };
    final files = <String, Uint8List>{};
    final dirs = <String>{'/'};
    final modified = <String, DateTime>{};
    for (final entry in archive) {
      final normalised = _normalise(entry.name);
      if (normalised == '/') continue;
      // Register parent dirs.
      _registerParents(normalised, dirs);
      if (entry.isFile) {
        final content = entry.readBytes();
        files[normalised] = content == null
            ? Uint8List(0)
            : Uint8List.fromList(content);
      } else {
        dirs.add(normalised);
      }
      final ms = entry.lastModTime;
      modified[normalised] = DateTime.fromMillisecondsSinceEpoch(
        ms * 1000,
        isUtc: true,
      );
    }
    return ArchiveFsProvider._(
      id: 'archive:$idSuffix',
      displayName: displayName,
      files: files,
      dirs: dirs,
      modified: modified,
    );
  }

  @override
  final String id;

  @override
  final String displayName;

  @override
  FsCapabilities get capabilities => FsCapabilities.readOnly;

  @override
  FsPath get root => FsPath.root;

  final Map<String, Uint8List> _files;
  final Set<String> _dirs;
  final Map<String, DateTime> _modified;

  @override
  Future<FsNode?> stat(FsPath path) async {
    final key = path.toString();
    if (_files.containsKey(key)) {
      return FsNode(
        path: path,
        kind: FsNodeKind.file,
        size: _files[key]!.length,
        modified: _modified[key],
        mimeType: _guessMime(path.name),
        isHidden: path.name.startsWith('.'),
      );
    }
    if (_dirs.contains(key)) {
      return FsNode(
        path: path,
        kind: FsNodeKind.directory,
        size: 0,
        modified: _modified[key],
        isHidden: path.name.startsWith('.'),
      );
    }
    return null;
  }

  @override
  Future<List<FsNode>> list(FsPath dir) async {
    final key = dir.toString();
    if (!_dirs.contains(key)) {
      throw StateError('not a directory: $dir');
    }
    final prefix = key == '/' ? '/' : '$key/';
    final out = <FsNode>[];
    final seen = <String>{};
    void emit(String childKey) {
      if (!seen.add(childKey)) return;
      // ignore: discarded_futures
      final node = _statSync(childKey);
      if (node != null) out.add(node);
    }

    for (final f in _files.keys) {
      if (!f.startsWith(prefix) || f == key) continue;
      final rest = f.substring(prefix.length);
      if (rest.isEmpty) continue;
      final slash = rest.indexOf('/');
      final childKey = slash < 0
          ? f
          : '${prefix.substring(0, prefix.length - 1)}/${rest.substring(0, slash)}'
                .replaceFirst('//', '/');
      emit(childKey);
    }
    for (final d in _dirs) {
      if (!d.startsWith(prefix) || d == key) continue;
      final rest = d.substring(prefix.length);
      if (rest.isEmpty || rest.contains('/')) continue;
      emit(d);
    }
    out.sort((a, b) {
      if (a.isDirectory != b.isDirectory) return a.isDirectory ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return out;
  }

  FsNode? _statSync(String key) {
    final path = FsPath.parse(key);
    if (_files.containsKey(key)) {
      return FsNode(
        path: path,
        kind: FsNodeKind.file,
        size: _files[key]!.length,
        modified: _modified[key],
        mimeType: _guessMime(path.name),
        isHidden: path.name.startsWith('.'),
      );
    }
    if (_dirs.contains(key)) {
      return FsNode(
        path: path,
        kind: FsNodeKind.directory,
        size: 0,
        modified: _modified[key],
        isHidden: path.name.startsWith('.'),
      );
    }
    return null;
  }

  @override
  Future<Uint8List> readBytes(FsPath file) async {
    final bytes = _files[file.toString()];
    if (bytes == null) {
      throw StateError('not a file: $file');
    }
    return bytes;
  }

  @override
  Future<void> writeBytes(FsPath file, Uint8List bytes) {
    throw UnsupportedError('ArchiveFsProvider is read-only');
  }

  @override
  Future<void> delete(FsPath path, {bool recursive = false}) {
    throw UnsupportedError('ArchiveFsProvider is read-only');
  }

  @override
  Future<void> rename(FsPath from, FsPath to) {
    throw UnsupportedError('ArchiveFsProvider is read-only');
  }

  @override
  Future<void> mkdir(FsPath path, {bool recursive = false}) {
    throw UnsupportedError('ArchiveFsProvider is read-only');
  }

  static String _normalise(String entryName) {
    var s = entryName.replaceAll('\\', '/').trim();
    while (s.startsWith('./')) {
      s = s.substring(2);
    }
    if (s.endsWith('/')) s = s.substring(0, s.length - 1);
    if (s.isEmpty) return '/';
    return s.startsWith('/') ? s : '/$s';
  }

  static void _registerParents(String key, Set<String> dirs) {
    final segs = key.split('/').where((s) => s.isNotEmpty).toList();
    if (segs.length <= 1) return;
    var cur = '';
    for (var i = 0; i < segs.length - 1; i++) {
      cur = '$cur/${segs[i]}';
      dirs.add(cur);
    }
  }

  static String? _guessMime(String name) {
    final dot = name.lastIndexOf('.');
    if (dot < 0) return null;
    final ext = name.substring(dot + 1).toLowerCase();
    return const {
      'txt': 'text/plain',
      'md': 'text/markdown',
      'csv': 'text/csv',
      'json': 'application/json',
      'png': 'image/png',
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'pdf': 'application/pdf',
    }[ext];
  }
}
