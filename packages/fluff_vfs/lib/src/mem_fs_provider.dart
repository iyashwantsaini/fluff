import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

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
        '# Fluff demo\n\n'
            'This is a **markdown** file rendered by the in-app viewer.\n\n'
            '## Features\n\n'
            '- Pure-Flutter file manager\n'
            '- Native viewers for images, text, markdown, SVG\n'
            '- APK inspector with manifest + dex stats\n'
            '- Encrypted vault (XChaCha20-Poly1305 + Argon2id)\n\n'
            '> No telemetry. Ever.\n\n'
            'See `notes.txt` for plain-text rendering.\n',
        now,
      )
      .._put(
        '/Pictures/logo.svg',
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 120 120">'
            '<rect width="120" height="120" rx="16" fill="#6750A4"/>'
            '<circle cx="60" cy="60" r="32" fill="#EADDFF"/>'
            '<text x="60" y="70" font-family="sans-serif" font-size="28" '
            'font-weight="700" text-anchor="middle" fill="#21005D">Fl</text>'
            '</svg>',
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
      .._putBytes('/Downloads/installer.apk', _demoApkBytes(), now)
      .._putBytes('/Downloads/photos.zip', _demoZipBytes(), now)
      .._putBytes('/Music/track-01.wav', _demoWavBytes(), now)
      .._putBytes('/Music/track-02.flac', apkLike, now)
      .._putBytes('/Videos/clip.mp4', apkLike, now)
      .._putBytes('/Documents/manual.pdf', _demoPdfBytes(), now)
      .._putBytes('/Books/novel.epub', _demoEpubBytes(), now);
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
      'wav': 'audio/wav',
      'mp3': 'audio/mpeg',
      'mp4': 'video/mp4',
      'epub': 'application/epub+zip',
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

Uint8List _demoZipBytes() {
  final archive = Archive()
    ..addFile(
      ArchiveFile.string(
        'photo-01.jpg.txt',
        'Placeholder for photo-01.jpg in demo ZIP.\n',
      ),
    )
    ..addFile(
      ArchiveFile.string(
        'photo-02.jpg.txt',
        'Placeholder for photo-02.jpg in demo ZIP.\n',
      ),
    )
    ..addFile(
      ArchiveFile.string(
        'README.txt',
        'Demo ZIP shipped with MemFsProvider.\n',
      ),
    );
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

Uint8List _demoApkBytes() {
  final archive = Archive()
    ..addFile(
      ArchiveFile.string(
        'AndroidManifest.xml',
        '<?xml version="1.0"?>\n'
            '<manifest package="dev.fluff.demo" />\n',
      ),
    )
    ..addFile(
      ArchiveFile.bytes(
        'classes.dex',
        Uint8List.fromList(List<int>.generate(256, (i) => i & 0xFF)),
      ),
    )
    ..addFile(
      ArchiveFile.bytes(
        'classes2.dex',
        Uint8List.fromList(List<int>.generate(128, (i) => (i * 3) & 0xFF)),
      ),
    )
    ..addFile(ArchiveFile.string('res/values/strings.xml', '<resources/>'))
    ..addFile(ArchiveFile.string('res/layout/main.xml', '<View/>'))
    ..addFile(
      ArchiveFile.bytes(
        'resources.arsc',
        Uint8List.fromList(List<int>.generate(64, (i) => i & 0xFF)),
      ),
    )
    ..addFile(
      ArchiveFile.string('META-INF/MANIFEST.MF', 'Manifest-Version: 1.0\n'),
    );
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

/// 2-second 8 kHz mono PCM WAV of silence. Just enough for the
/// audio player to mount real controls and report a real duration.
Uint8List _demoWavBytes() {
  const sampleRate = 8000;
  const seconds = 2;
  const samples = sampleRate * seconds;
  const dataSize = samples * 2; // 16-bit mono
  final out = ByteData(44 + dataSize);
  // RIFF header
  out.setUint8(0, 0x52); // R
  out.setUint8(1, 0x49); // I
  out.setUint8(2, 0x46); // F
  out.setUint8(3, 0x46); // F
  out.setUint32(4, 36 + dataSize, Endian.little);
  out.setUint8(8, 0x57); // W
  out.setUint8(9, 0x41); // A
  out.setUint8(10, 0x56); // V
  out.setUint8(11, 0x45); // E
  // fmt chunk
  out.setUint8(12, 0x66); // f
  out.setUint8(13, 0x6d); // m
  out.setUint8(14, 0x74); // t
  out.setUint8(15, 0x20); // ' '
  out.setUint32(16, 16, Endian.little); // fmt chunk size
  out.setUint16(20, 1, Endian.little); // PCM
  out.setUint16(22, 1, Endian.little); // mono
  out.setUint32(24, sampleRate, Endian.little);
  out.setUint32(28, sampleRate * 2, Endian.little); // byte rate
  out.setUint16(32, 2, Endian.little); // block align
  out.setUint16(34, 16, Endian.little); // bits per sample
  // data chunk
  out.setUint8(36, 0x64); // d
  out.setUint8(37, 0x61); // a
  out.setUint8(38, 0x74); // t
  out.setUint8(39, 0x61); // a
  out.setUint32(40, dataSize, Endian.little);
  // Samples already zero — pure silence.
  return out.buffer.asUint8List();
}

/// Minimal valid PDF 1.4 with one page reading "Fluff PDF demo".
/// Hand-rolled to keep the demo asset under a kilobyte.
Uint8List _demoPdfBytes() {
  final objects = <String>[
    '<< /Type /Catalog /Pages 2 0 R >>',
    '<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
    '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] '
        '/Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >>',
    '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>',
  ];
  const stream =
      'BT /F1 24 Tf 72 720 Td (Fluff PDF demo) Tj '
      '0 -36 Td /F1 14 Tf (Rendered by pdfx in the in-app viewer.) Tj ET';
  objects.add('<< /Length ${stream.length} >>\nstream\n$stream\nendstream');
  final buf = StringBuffer('%PDF-1.4\n%\u{00E2}\u{00E3}\u{00CF}\u{00D3}\n');
  final offsets = <int>[];
  for (var i = 0; i < objects.length; i++) {
    offsets.add(buf.length);
    buf.write('${i + 1} 0 obj\n${objects[i]}\nendobj\n');
  }
  final xrefOffset = buf.length;
  buf.write('xref\n0 ${objects.length + 1}\n');
  buf.write('0000000000 65535 f \n');
  for (final o in offsets) {
    buf.write('${o.toString().padLeft(10, '0')} 00000 n \n');
  }
  buf.write(
    'trailer\n<< /Size ${objects.length + 1} /Root 1 0 R >>\n'
    'startxref\n$xrefOffset\n%%EOF\n',
  );
  return Uint8List.fromList(latin1.encode(buf.toString()));
}

/// Minimal valid EPUB 3 with one chapter. Built fresh with the
/// `archive` package so the mimetype entry is the first STORED
/// member, exactly as the spec requires.
Uint8List _demoEpubBytes() {
  Uint8List bytes(String s) => Uint8List.fromList(utf8.encode(s));
  const container =
      '<?xml version="1.0"?>\n'
      '<container version="1.0" '
      'xmlns="urn:oasis:names:tc:opendocument:xmlns:container">\n'
      '  <rootfiles>\n'
      '    <rootfile full-path="OEBPS/content.opf" '
      'media-type="application/oebps-package+xml"/>\n'
      '  </rootfiles>\n'
      '</container>\n';
  const opf =
      '<?xml version="1.0" encoding="UTF-8"?>\n'
      '<package xmlns="http://www.idpf.org/2007/opf" version="3.0" '
      'unique-identifier="bookid">\n'
      '  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">\n'
      '    <dc:identifier id="bookid">fluff-demo-001</dc:identifier>\n'
      '    <dc:title>Fluff Demo Book</dc:title>\n'
      '    <dc:language>en</dc:language>\n'
      '  </metadata>\n'
      '  <manifest>\n'
      '    <item id="ch1" href="chapter1.xhtml" '
      'media-type="application/xhtml+xml"/>\n'
      '    <item id="ch2" href="chapter2.xhtml" '
      'media-type="application/xhtml+xml"/>\n'
      '  </manifest>\n'
      '  <spine>\n'
      '    <itemref idref="ch1"/>\n'
      '    <itemref idref="ch2"/>\n'
      '  </spine>\n'
      '</package>\n';
  const ch1 =
      '<?xml version="1.0" encoding="UTF-8"?>\n'
      '<!DOCTYPE html>\n'
      '<html xmlns="http://www.w3.org/1999/xhtml">\n'
      '<head><title>Chapter 1</title></head>\n'
      '<body>\n'
      '  <h1>Chapter 1 &#8212; A Pure-Flutter Beginning</h1>\n'
      '  <p>Once upon a build, a file manager named '
      '<strong>Fluff</strong> rendered its very first EPUB without '
      'a single line of platform code.</p>\n'
      '  <p>It parsed the spine, hopped through the manifest, and '
      'asked <em>flutter_html</em> to do the heavy lifting.</p>\n'
      '  <p>Swipe right to keep reading.</p>\n'
      '</body>\n'
      '</html>\n';
  const ch2 =
      '<?xml version="1.0" encoding="UTF-8"?>\n'
      '<!DOCTYPE html>\n'
      '<html xmlns="http://www.w3.org/1999/xhtml">\n'
      '<head><title>Chapter 2</title></head>\n'
      '<body>\n'
      '  <h1>Chapter 2 &#8212; The Chapter Bar</h1>\n'
      '  <p>The bottom chevrons let you hop between chapters; the '
      'counter shows where you stand.</p>\n'
      '  <p>That is the whole demo. The rest of the format &#8212; '
      'cover art, CSS stylesheets, embedded fonts &#8212; is '
      'on the Phase 1.x roadmap.</p>\n'
      '</body>\n'
      '</html>\n';
  final mime = ArchiveFile.bytes('mimetype', bytes('application/epub+zip'))
    ..compression = CompressionType.none;
  final archive = Archive()
    ..addFile(mime)
    ..addFile(ArchiveFile.bytes('META-INF/container.xml', bytes(container)))
    ..addFile(ArchiveFile.bytes('OEBPS/content.opf', bytes(opf)))
    ..addFile(ArchiveFile.bytes('OEBPS/chapter1.xhtml', bytes(ch1)))
    ..addFile(ArchiveFile.bytes('OEBPS/chapter2.xhtml', bytes(ch2)));
  return Uint8List.fromList(ZipEncoder().encode(archive));
}
