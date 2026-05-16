import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'fs_capabilities.dart';
import 'fs_node.dart';
import 'fs_path.dart';
import 'fs_provider.dart';

/// In-memory [FsProvider]. Backed by a simple map.
///
/// Used by tests and by the Flutter-web demo build (the browser
/// can't open `/storage/emulated/0/`).
class MemFsProvider implements FsProvider {
  @override
  final String id;

  @override
  final String displayName;

  @override
  final FsCapabilities capabilities = FsCapabilities.full;

  @override
  final FsPath root = FsPath.root;

  // Path string → bytes (for files) OR null (for directories).
  final Map<String, Uint8List?> _entries = {'/': null};

  // Per-path metadata.
  final Map<String, DateTime> _modified = {};

  MemFsProvider({this.id = 'mem', this.displayName = 'Demo storage'});

  /// Convenience: pre-populate with a tiny realistic tree so the
  /// browse screen has something to render on web.
  factory MemFsProvider.demo() {
    final p = MemFsProvider();
    final now = DateTime.now();
    // 1x1 solid-red PNG (real, base64-decoded so the bytes are
    // guaranteed valid) so the image viewer has something to show
    // on the in-memory demo. Pure-Dart packages shouldn't ship
    // image assets; a real device build pulls real previews from
    // disk.
    final redPng = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQ'
      'DwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
    );
    // Tiny "fake" binary that's clearly not text — enough to fill
    // the hex viewer with something to scroll through.
    final apkLike = Uint8List.fromList(
      List<int>.generate(512, (i) => (i * 37 + 13) & 0xFF),
    );
    p
      .._mkdir('/Documents')
      .._mkdir('/Pictures')
      .._mkdir('/Downloads')
      .._mkdir('/Music')
      .._mkdir('/Videos')
      .._mkdir('/Books')
      .._mkdir('/Pictures/Screenshots')
      .._put(
        '/Documents/notes.txt',
        'A pure-Flutter file manager, made of fluff.',
        now,
      )
      .._put(
        '/Documents/budget.csv',
        'item,cost\ncoffee,3.50\nbagel,4.00\n',
        now,
      )
      .._put(
        '/Documents/README.md',
        '# Hello\n\nThis is a demo file inside MemFsProvider.',
        now,
      )
      .._put(
        '/Documents/config.json',
        '{\n  "theme": "auto",\n  "telemetry": false\n}\n',
        now,
      )
      .._putBytes('/Pictures/sunset.jpg', redPng, now)
      .._putBytes('/Pictures/portrait.png', redPng, now)
      .._putBytes('/Pictures/Screenshots/screen-01.png', redPng, now)
      .._putBytes('/Downloads/installer.apk', apkLike, now)
      .._putBytes('/Music/track-01.flac', apkLike, now)
      .._putBytes('/Music/track-02.flac', apkLike, now)
      .._putBytes('/Videos/clip.mp4', apkLike, now)
      .._putBytes('/Documents/manual.pdf', apkLike, now)
      .._putBytes('/Books/novel.epub', apkLike, now);
    return p;
  }

  void _mkdir(String p) {
    _entries[p] = null;
    _modified[p] = DateTime.now();
  }

  void _put(String p, String content, DateTime mod) {
    _entries[p] = Uint8List.fromList(content.codeUnits);
    _modified[p] = mod;
  }

  void _putBytes(String p, Uint8List bytes, DateTime mod) {
    _entries[p] = bytes;
    _modified[p] = mod;
  }

  FsNodeKind _kind(String key) =>
      _entries[key] == null ? FsNodeKind.directory : FsNodeKind.file;

  String? _guessMime(String name) {
    final dot = name.lastIndexOf('.');
    if (dot < 0) return null;
    final ext = name.substring(dot + 1).toLowerCase();
    return const {
      'txt': 'text/plain',
      'md': 'text/markdown',
      'csv': 'text/csv',
      'png': 'image/png',
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'webp': 'image/webp',
      'flac': 'audio/flac',
      'mp3': 'audio/mpeg',
      'apk': 'application/vnd.android.package-archive',
      'pdf': 'application/pdf',
    }[ext];
  }

  @override
  Future<FsNode?> stat(FsPath path) async {
    final key = path.toString();
    if (!_entries.containsKey(key)) return null;
    final kind = _kind(key);
    final bytes = _entries[key];
    return FsNode(
      path: path,
      kind: kind,
      size: bytes?.length ?? 0,
      modified: _modified[key],
      mimeType: kind == FsNodeKind.file ? _guessMime(path.name) : null,
      isHidden: path.name.startsWith('.'),
    );
  }

  @override
  Future<List<FsNode>> list(FsPath dir) async {
    final prefix = dir.isRoot ? '/' : '${dir.toString()}/';
    final out = <FsNode>[];
    for (final key in _entries.keys) {
      if (key == dir.toString()) continue;
      if (!key.startsWith(prefix)) continue;
      final remainder = key.substring(prefix.length);
      if (remainder.isEmpty || remainder.contains('/')) continue;
      final p = FsPath.parse(key);
      final node = await stat(p);
      if (node != null) out.add(node);
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
    final bytes = _entries[file.toString()];
    if (bytes == null) {
      throw StateError('not a file: $file');
    }
    return bytes;
  }

  @override
  Future<void> writeBytes(FsPath file, Uint8List bytes) async {
    _entries[file.toString()] = bytes;
    _modified[file.toString()] = DateTime.now();
  }

  @override
  Future<void> delete(FsPath path, {bool recursive = false}) async {
    final key = path.toString();
    if (!_entries.containsKey(key)) return;
    if (_kind(key) == FsNodeKind.directory) {
      final prefix = '$key/';
      final children = _entries.keys
          .where((k) => k.startsWith(prefix))
          .toList();
      if (children.isNotEmpty && !recursive) {
        throw StateError('directory not empty: $path');
      }
      for (final c in children) {
        _entries.remove(c);
        _modified.remove(c);
      }
    }
    _entries.remove(key);
    _modified.remove(key);
  }

  @override
  Future<void> rename(FsPath from, FsPath to) async {
    final fromKey = from.toString();
    final toKey = to.toString();
    if (!_entries.containsKey(fromKey)) {
      throw StateError('source missing: $from');
    }
    final keys = _entries.keys
        .where((k) => k == fromKey || k.startsWith('$fromKey/'))
        .toList();
    for (final k in keys) {
      final newKey = toKey + k.substring(fromKey.length);
      _entries[newKey] = _entries[k];
      final mod = _modified.remove(k);
      if (mod != null) _modified[newKey] = mod;
      _entries.remove(k);
    }
  }

  @override
  Future<void> mkdir(FsPath path, {bool recursive = false}) async {
    if (recursive) {
      final segs = path.toString().split('/').where((s) => s.isNotEmpty);
      var cur = '';
      for (final s in segs) {
        cur = '$cur/$s';
        _entries.putIfAbsent(cur, () => null);
        _modified.putIfAbsent(cur, () => DateTime.now());
      }
    } else {
      _entries[path.toString()] = null;
      _modified[path.toString()] = DateTime.now();
    }
  }
}
