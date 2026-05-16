import 'dart:typed_data';

import 'package:fluff_skin/fluff_skin.dart';
import 'package:fluff_vfs/fluff_vfs.dart';
import 'package:flutter/material.dart';

/// Returns true if [name] looks like a file Fluff can show inline.
String? viewerKindFor(String name) {
  final lower = name.toLowerCase();
  final ext = lower.contains('.') ? lower.split('.').last : '';
  if ({'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'heic'}.contains(ext)) {
    return 'image';
  }
  if ({
    'txt',
    'md',
    'markdown',
    'json',
    'yaml',
    'yml',
    'xml',
    'csv',
    'tsv',
    'log',
    'ini',
    'conf',
    'cfg',
    'gitignore',
    'dart',
    'kt',
    'java',
    'js',
    'ts',
    'py',
    'go',
    'rs',
    'rb',
    'sh',
    'ps1',
    'html',
    'css',
    'sql',
    'toml',
  }.contains(ext)) {
    return 'text';
  }
  if ({'mp4', 'mkv', 'webm', 'mov'}.contains(ext)) return 'video';
  if ({'mp3', 'flac', 'ogg', 'wav', 'm4a', 'opus'}.contains(ext)) {
    return 'audio';
  }
  if (ext == 'pdf') return 'pdf';
  if ({'epub', 'mobi', 'azw3'}.contains(ext)) return 'ebook';
  return 'hex';
}

/// Web-slice viewer screen. Decides what to render based on the
/// file extension; everything that isn't a recognised image / text
/// falls back to a hex dump.
class ViewerScreen extends StatefulWidget {
  const ViewerScreen({
    super.key,
    required this.provider,
    required this.path,
    this.onToggleBrightness,
  });

  final FsProvider provider;
  final FsPath path;
  final VoidCallback? onToggleBrightness;

  @override
  State<ViewerScreen> createState() => _ViewerScreenState();
}

class _ViewerScreenState extends State<ViewerScreen> {
  late final Future<Uint8List> _bytes = widget.provider.readBytes(widget.path);

  @override
  Widget build(BuildContext context) {
    final name = widget.path.name;
    final kind = viewerKindFor(name);
    return Scaffold(
      appBar: AppBar(
        title: Text(name, overflow: TextOverflow.ellipsis),
        actions: [
          if (widget.onToggleBrightness != null)
            IconButton(
              tooltip: 'Toggle theme',
              icon: const Icon(Icons.brightness_6_outlined),
              onPressed: widget.onToggleBrightness,
            ),
        ],
      ),
      body: FutureBuilder<Uint8List>(
        future: _bytes,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snap.data!;
          return switch (kind) {
            'image' => _ImageView(bytes: data),
            'text' => _TextView(bytes: data),
            'video' ||
            'audio' ||
            'pdf' ||
            'ebook' => _UnsupportedView(name: name, kind: kind!, bytes: data),
            _ => _HexView(bytes: data),
          };
        },
      ),
    );
  }
}

class _ImageView extends StatelessWidget {
  const _ImageView({required this.bytes});
  final Uint8List bytes;

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      maxScale: 8,
      child: Center(
        child: Image.memory(
          bytes,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => const Text('Could not decode image bytes'),
        ),
      ),
    );
  }
}

class _TextView extends StatelessWidget {
  const _TextView({required this.bytes});
  final Uint8List bytes;

  @override
  Widget build(BuildContext context) {
    final tokens = WlmTheme.of(context).tokens;
    String text;
    try {
      text = String.fromCharCodes(bytes);
    } catch (_) {
      text = '<non-UTF8 content; ${bytes.length} bytes>';
    }
    return SingleChildScrollView(
      padding: EdgeInsets.all(tokens.spacing.lg),
      child: SelectableText(
        text,
        style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
      ),
    );
  }
}

class _HexView extends StatelessWidget {
  const _HexView({required this.bytes});
  final Uint8List bytes;

  static const _bytesPerRow = 16;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final rows = (bytes.length + _bytesPerRow - 1) ~/ _bytesPerRow;
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: rows,
      itemBuilder: (context, i) {
        final start = i * _bytesPerRow;
        final end = (start + _bytesPerRow).clamp(0, bytes.length);
        final slice = bytes.sublist(start, end);
        final hex = slice
            .map((b) => b.toRadixString(16).padLeft(2, '0'))
            .join(' ');
        final ascii = slice
            .map((b) => (b >= 32 && b < 127) ? String.fromCharCode(b) : '.')
            .join();
        return DefaultTextStyle(
          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          child: Row(
            children: [
              SizedBox(
                width: 88,
                child: Text(
                  start.toRadixString(16).padLeft(8, '0'),
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
              ),
              Expanded(flex: 5, child: Text(hex)),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: Text(ascii, style: TextStyle(color: cs.primary)),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _UnsupportedView extends StatelessWidget {
  const _UnsupportedView({
    required this.name,
    required this.kind,
    required this.bytes,
  });
  final String name;
  final String kind;
  final Uint8List bytes;

  IconData get _icon => switch (kind) {
    'video' => Icons.movie_outlined,
    'audio' => Icons.music_note_outlined,
    'pdf' => Icons.picture_as_pdf_outlined,
    'ebook' => Icons.menu_book_outlined,
    _ => Icons.insert_drive_file_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tokens = WlmTheme.of(context).tokens;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_icon, size: 72, color: cs.primary),
            SizedBox(height: tokens.spacing.md),
            Text(
              '$kind preview lands in Phase 9.1',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              '$name · ${bytes.length} bytes',
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
