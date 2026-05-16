import 'package:meta/meta.dart';

/// A streamed progress sample for one [Operation].
@immutable
class OperationProgress {
  /// Operation id.
  final String id;

  /// Items processed so far (files + dirs).
  final int itemsDone;

  /// Total items the queue knows about. `null` while still discovering.
  final int? itemsTotal;

  /// Bytes processed so far.
  final int bytesDone;

  /// Bytes total. `null` while still discovering.
  final int? bytesTotal;

  /// Path of whatever the operation is touching right now.
  final String currentItem;

  const OperationProgress({
    required this.id,
    required this.itemsDone,
    required this.bytesDone,
    required this.currentItem,
    this.itemsTotal,
    this.bytesTotal,
  });

  /// Fraction in `[0.0, 1.0]`, or `null` while still discovering.
  double? get fraction {
    if (bytesTotal == null || bytesTotal == 0) {
      if (itemsTotal == null || itemsTotal == 0) return null;
      return itemsDone / itemsTotal!;
    }
    return bytesDone / bytesTotal!;
  }
}
