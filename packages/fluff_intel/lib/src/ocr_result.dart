import 'package:meta/meta.dart';

/// A single block of text recognised inside an image. Bounding box
/// is normalised to `[0, 1]` so it can be drawn on any preview size.
@immutable
class OcrBlock {
  const OcrBlock({
    required this.text,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    this.confidence = 1.0,
  });

  final String text;
  final double left;
  final double top;
  final double width;
  final double height;
  final double confidence;
}

/// Aggregated OCR result for a single source file.
@immutable
class OcrResult {
  const OcrResult({
    required this.sourcePath,
    required this.language,
    required this.blocks,
  });

  final String sourcePath;
  final String language;
  final List<OcrBlock> blocks;

  String get fullText => blocks.map((b) => b.text).join('\n');
}
