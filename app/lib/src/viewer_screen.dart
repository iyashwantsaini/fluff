import 'dart:async';
import 'dart:convert';
import 'dart:io' show File;

import 'package:archive/archive.dart';
import 'package:chewie/chewie.dart';
import 'package:fluff_skin/fluff_skin.dart';
import 'package:fluff_vfs/fluff_vfs.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:just_audio/just_audio.dart' as ja;
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

/// Returns a viewer kind for [name], based on extension. Recognised
/// kinds: image, svg, markdown, text, video, audio, pdf, ebook,
/// archive (incl. apk), hex (fallback).
String viewerKindFor(String name) {
  final lower = name.toLowerCase();
  final ext = lower.contains('.') ? lower.split('.').last : '';
  if ({
    'jpg',
    'jpeg',
    'png',
    'gif',
    'webp',
    'bmp',
    'heic',
    'avif',
    'ico',
  }.contains(ext)) {
    return 'image';
  }
  if (ext == 'svg') return 'svg';
  if ({'md', 'markdown', 'mdown'}.contains(ext)) return 'markdown';
  if ({
    'txt',
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
    'env',
    'dart',
    'kt',
    'java',
    'js',
    'ts',
    'tsx',
    'jsx',
    'py',
    'go',
    'rs',
    'rb',
    'sh',
    'ps1',
    'bat',
    'html',
    'htm',
    'css',
    'scss',
    'sql',
    'toml',
    'lock',
    'gradle',
    'properties',
    'c',
    'cpp',
    'h',
    'hpp',
    'cs',
    'php',
    'swift',
    'm',
    'mm',
    'lua',
    'vim',
    'r',
    'pl',
  }.contains(ext)) {
    return 'text';
  }
  if ({'mp4', 'mkv', 'webm', 'mov', 'avi', '3gp', 'm4v'}.contains(ext)) {
    return 'video';
  }
  if ({
    'mp3',
    'flac',
    'ogg',
    'wav',
    'm4a',
    'opus',
    'aac',
    'wma',
  }.contains(ext)) {
    return 'audio';
  }
  if (ext == 'pdf') return 'pdf';
  if ({'epub', 'mobi', 'azw3', 'fb2'}.contains(ext)) return 'ebook';
  if ({'apk', 'zip', 'jar', 'aar', 'apks', 'xapk'}.contains(ext)) {
    return 'archive';
  }
  return 'hex';
}

/// Viewer screen. Routes to the right inline viewer based on extension.
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
          IconButton(
            tooltip: 'Share',
            icon: const Icon(Icons.share_outlined),
            onPressed: () => _snack(context, 'Share lands in Phase 9.2'),
          ),
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
            'svg' => _SvgView(bytes: data),
            'markdown' => _MarkdownView(bytes: data),
            'text' => _TextView(bytes: data),
            'archive' => _ArchiveView(name: name, bytes: data),
            'audio' => _AudioView(name: name, bytes: data),
            'video' => _VideoView(name: name, bytes: data),
            'pdf' ||
            'ebook' => _MediaPlaceholder(name: name, kind: kind, bytes: data),
            _ => _HexView(bytes: data),
          };
        },
      ),
    );
  }
}

void _snack(BuildContext context, String msg) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
  );
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
          filterQuality: FilterQuality.none,
          width: 256,
          height: 256,
          errorBuilder: (_, _, _) => const Text('Could not decode image bytes'),
        ),
      ),
    );
  }
}

class _SvgView extends StatelessWidget {
  const _SvgView({required this.bytes});
  final Uint8List bytes;

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      maxScale: 8,
      child: Center(
        child: SvgPicture.memory(
          bytes,
          fit: BoxFit.contain,
          placeholderBuilder: (_) =>
              const Center(child: CircularProgressIndicator()),
        ),
      ),
    );
  }
}

class _MarkdownView extends StatelessWidget {
  const _MarkdownView({required this.bytes});
  final Uint8List bytes;

  @override
  Widget build(BuildContext context) {
    final tokens = WlmTheme.of(context).tokens;
    String text;
    try {
      text = String.fromCharCodes(bytes);
    } catch (_) {
      text = '<non-UTF8 markdown; ${bytes.length} bytes>';
    }
    return Markdown(
      data: text,
      padding: EdgeInsets.all(tokens.spacing.lg),
      selectable: true,
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

/// Archive / APK inspector. Decodes the ZIP, shows a header card,
/// APK-specific stats (manifest, classes.dex count, res count),
/// an Install affordance, and the file listing.
class _ArchiveView extends StatelessWidget {
  const _ArchiveView({required this.name, required this.bytes});
  final String name;
  final Uint8List bytes;

  bool get _isApk {
    final n = name.toLowerCase();
    return n.endsWith('.apk') || n.endsWith('.apks') || n.endsWith('.xapk');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tokens = WlmTheme.of(context).tokens;
    Archive? archive;
    String? error;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } catch (e) {
      error = '$e';
    }
    if (archive == null) {
      return _MediaPlaceholder(
        name: name,
        kind: 'archive',
        bytes: bytes,
        extra: 'Could not parse archive: ${error ?? "unknown error"}',
      );
    }
    final files = archive.files;
    final dexCount = files.where((f) => f.name.endsWith('.dex')).length;
    final resCount = files.where((f) => f.name.startsWith('res/')).length;
    final hasManifest = files.any((f) => f.name == 'AndroidManifest.xml');
    final totalUncompressed = files.fold<int>(0, (a, f) => a + f.size);
    return ListView(
      padding: EdgeInsets.all(tokens.spacing.lg),
      children: [
        Container(
          padding: EdgeInsets.all(tokens.spacing.lg),
          decoration: BoxDecoration(
            color: cs.surfaceContainerLow,
            borderRadius: BorderRadius.circular(tokens.radius.md),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(tokens.radius.sm),
                ),
                alignment: Alignment.center,
                child: Icon(
                  _isApk ? Icons.android_rounded : Icons.archive_outlined,
                  color: cs.onPrimaryContainer,
                  size: 28,
                ),
              ),
              SizedBox(width: tokens.spacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: theme.textTheme.titleMedium),
                    Text(
                      '${files.length} entries · '
                      '${_kb(totalUncompressed)} uncompressed · '
                      '${_kb(bytes.length)} on disk',
                      style: theme.textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
              if (_isApk)
                FilledButton.icon(
                  onPressed: () =>
                      _snack(context, 'Install intent wires up in Phase 9.2'),
                  icon: const Icon(Icons.install_mobile_rounded),
                  label: const Text('Install'),
                ),
            ],
          ),
        ),
        if (_isApk) ...[
          SizedBox(height: tokens.spacing.md),
          _StatRow(
            icon: Icons.description_outlined,
            label: 'AndroidManifest.xml',
            value: hasManifest ? 'present' : 'missing',
          ),
          _StatRow(
            icon: Icons.code_rounded,
            label: 'classes*.dex',
            value: '$dexCount',
          ),
          _StatRow(
            icon: Icons.folder_zip_outlined,
            label: 'res/ entries',
            value: '$resCount',
          ),
        ],
        SizedBox(height: tokens.spacing.lg),
        Text('Contents', style: theme.textTheme.titleSmall),
        SizedBox(height: tokens.spacing.sm),
        for (final f in files.take(500))
          ListTile(
            dense: true,
            visualDensity: VisualDensity.compact,
            leading: Icon(
              f.isFile
                  ? Icons.insert_drive_file_outlined
                  : Icons.folder_outlined,
              size: 18,
              color: cs.onSurfaceVariant,
            ),
            title: Text(
              f.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
            trailing: Text(_kb(f.size), style: theme.textTheme.labelSmall),
          ),
        if (files.length > 500)
          Padding(
            padding: EdgeInsets.all(tokens.spacing.md),
            child: Text(
              '… and ${files.length - 500} more entries',
              style: theme.textTheme.labelSmall,
            ),
          ),
      ],
    );
  }

  static String _kb(int b) {
    if (b < 1024) return '$b B';
    if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)} KB';
    return '${(b / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 16, color: cs.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(child: Text(label)),
          Text(value, style: TextStyle(color: cs.primary)),
        ],
      ),
    );
  }
}

class _MediaPlaceholder extends StatelessWidget {
  const _MediaPlaceholder({
    required this.name,
    required this.kind,
    required this.bytes,
    this.extra,
  });
  final String name;
  final String kind;
  final Uint8List bytes;
  final String? extra;

  IconData get _icon => switch (kind) {
    'video' => Icons.movie_outlined,
    'audio' => Icons.music_note_outlined,
    'pdf' => Icons.picture_as_pdf_outlined,
    'ebook' => Icons.menu_book_outlined,
    'archive' => Icons.folder_zip_outlined,
    _ => Icons.insert_drive_file_outlined,
  };

  String get _title => switch (kind) {
    'video' => 'Native video player ships in Phase 9.1',
    'audio' => 'Native audio player ships in Phase 9.1',
    'pdf' => 'Native PDF renderer ships in Phase 9.1',
    'ebook' => 'Ebook reader ships in Phase 9.1',
    'archive' => 'Archive details',
    _ => 'Inline preview not available yet',
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
            Text(_title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              '$name · ${bytes.length} bytes',
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
            if (extra != null) ...[
              SizedBox(height: tokens.spacing.sm),
              Text(extra!, style: TextStyle(color: cs.error)),
            ],
            SizedBox(height: tokens.spacing.lg),
            Wrap(
              spacing: tokens.spacing.sm,
              children: [
                OutlinedButton.icon(
                  onPressed: () =>
                      _snack(context, 'Open with… lands in Phase 9.2'),
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: const Text('Open with…'),
                ),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).pushReplacement(
                    MaterialPageRoute<void>(
                      builder: (_) => Scaffold(
                        appBar: AppBar(title: Text(name)),
                        body: _HexView(bytes: bytes),
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.code_rounded),
                  label: const Text('Open as hex'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// MIME guess for [name] — used when materialising bytes into a
/// data: URL on web so the browser picks the right decoder.
String _guessPlaybackMime(String name) {
  final ext = name.toLowerCase().split('.').last;
  return switch (ext) {
    'mp3' => 'audio/mpeg',
    'wav' => 'audio/wav',
    'ogg' => 'audio/ogg',
    'opus' => 'audio/ogg',
    'flac' => 'audio/flac',
    'm4a' || 'aac' => 'audio/mp4',
    'wma' => 'audio/x-ms-wma',
    'mp4' || 'm4v' => 'video/mp4',
    'mkv' => 'video/x-matroska',
    'webm' => 'video/webm',
    'mov' => 'video/quicktime',
    'avi' => 'video/x-msvideo',
    '3gp' => 'video/3gpp',
    _ => 'application/octet-stream',
  };
}

/// Materialises [bytes] so that [video_player] / [just_audio] can
/// consume them. On native platforms we write to the OS temp dir and
/// return a `file://` path; on web we return a `data:` URL.
Future<String> _materializeForPlayback(Uint8List bytes, String name) async {
  if (kIsWeb) {
    return 'data:${_guessPlaybackMime(name)};base64,${base64.encode(bytes)}';
  }
  final tmp = await getTemporaryDirectory();
  // Sanitise the filename so weird characters never reach the FS.
  final safe = name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
  final file = File('${tmp.path}/fluff_view_$safe');
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}

/// Audio player driven by [just_audio]. Renders the standard
/// transport controls (play / pause, scrub, time, volume) so MP3,
/// FLAC, OGG, WAV, etc. all play through the same UI.
class _AudioView extends StatefulWidget {
  const _AudioView({required this.name, required this.bytes});
  final String name;
  final Uint8List bytes;

  @override
  State<_AudioView> createState() => _AudioViewState();
}

class _AudioViewState extends State<_AudioView> {
  final ja.AudioPlayer _player = ja.AudioPlayer();
  Object? _error;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final url = await _materializeForPlayback(widget.bytes, widget.name);
      await _player.setUrl(kIsWeb ? url : Uri.file(url).toString());
      if (mounted) setState(() => _ready = true);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  void dispose() {
    // ignore: discarded_futures
    _player.dispose();
    super.dispose();
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return d.inHours > 0 ? '${d.inHours}:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tokens = WlmTheme.of(context).tokens;
    if (_error != null) {
      return _MediaPlaceholder(
        name: widget.name,
        kind: 'audio',
        bytes: widget.bytes,
        extra: 'Could not decode audio: $_error',
      );
    }
    if (!_ready) {
      return const Center(child: CircularProgressIndicator());
    }
    return Center(
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(tokens.radius.lg),
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.music_note_rounded,
                size: 88,
                color: cs.onPrimaryContainer,
              ),
            ),
            SizedBox(height: tokens.spacing.lg),
            Text(
              widget.name,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: tokens.spacing.lg),
            StreamBuilder<Duration>(
              stream: _player.positionStream,
              builder: (context, posSnap) {
                final pos = posSnap.data ?? Duration.zero;
                final total = _player.duration ?? Duration.zero;
                final maxMs = total.inMilliseconds == 0
                    ? 1.0
                    : total.inMilliseconds.toDouble();
                return Column(
                  children: [
                    Slider(
                      value: pos.inMilliseconds
                          .clamp(0, maxMs.toInt())
                          .toDouble(),
                      max: maxMs,
                      onChanged: (v) =>
                          _player.seek(Duration(milliseconds: v.toInt())),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: tokens.spacing.md,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [Text(_fmt(pos)), Text(_fmt(total))],
                      ),
                    ),
                  ],
                );
              },
            ),
            SizedBox(height: tokens.spacing.md),
            StreamBuilder<ja.PlayerState>(
              stream: _player.playerStateStream,
              builder: (context, snap) {
                final playing = snap.data?.playing ?? false;
                final processing =
                    snap.data?.processingState ?? ja.ProcessingState.idle;
                final loading =
                    processing == ja.ProcessingState.loading ||
                    processing == ja.ProcessingState.buffering;
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton.filledTonal(
                      tooltip: 'Back 10s',
                      icon: const Icon(Icons.replay_10_rounded),
                      onPressed: () => _player.seek(
                        _player.position - const Duration(seconds: 10),
                      ),
                    ),
                    SizedBox(width: tokens.spacing.md),
                    IconButton.filled(
                      iconSize: 40,
                      tooltip: playing ? 'Pause' : 'Play',
                      onPressed: loading
                          ? null
                          : () => playing ? _player.pause() : _player.play(),
                      icon: loading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              playing
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                            ),
                    ),
                    SizedBox(width: tokens.spacing.md),
                    IconButton.filledTonal(
                      tooltip: 'Forward 10s',
                      icon: const Icon(Icons.forward_10_rounded),
                      onPressed: () => _player.seek(
                        _player.position + const Duration(seconds: 10),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Video player built on [video_player] with the [chewie] controls
/// overlay. Handles mp4 / mkv / webm / mov etc. wherever the
/// underlying platform decoder supports them.
class _VideoView extends StatefulWidget {
  const _VideoView({required this.name, required this.bytes});
  final String name;
  final Uint8List bytes;

  @override
  State<_VideoView> createState() => _VideoViewState();
}

class _VideoViewState extends State<_VideoView> {
  VideoPlayerController? _controller;
  ChewieController? _chewie;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final url = await _materializeForPlayback(widget.bytes, widget.name);
      final VideoPlayerController c;
      if (kIsWeb) {
        c = VideoPlayerController.networkUrl(Uri.parse(url));
      } else {
        c = VideoPlayerController.file(File(url));
      }
      await c.initialize();
      if (!mounted) {
        await c.dispose();
        return;
      }
      setState(() {
        _controller = c;
        _chewie = ChewieController(
          videoPlayerController: c,
          autoPlay: false,
          looping: false,
          allowFullScreen: true,
          allowPlaybackSpeedChanging: true,
          showControls: true,
        );
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  void dispose() {
    _chewie?.dispose();
    // ignore: discarded_futures
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return _MediaPlaceholder(
        name: widget.name,
        kind: 'video',
        bytes: widget.bytes,
        extra: 'Could not decode video: $_error',
      );
    }
    final chewie = _chewie;
    final controller = _controller;
    if (chewie == null || controller == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return Container(
      color: Colors.black,
      child: Center(
        child: AspectRatio(
          aspectRatio: controller.value.aspectRatio == 0
              ? 16 / 9
              : controller.value.aspectRatio,
          child: Chewie(controller: chewie),
        ),
      ),
    );
  }
}
