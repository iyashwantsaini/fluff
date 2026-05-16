import 'package:meta/meta.dart';

/// POSIX-style path used by every [FsProvider]. Always uses `/` and
/// always starts with `/`. Construction normalises `.` and `..`.
@immutable
class FsPath {
  /// Root path (`/`).
  static const FsPath root = FsPath._(['']);

  final List<String> _segments;

  const FsPath._(this._segments);

  /// Parse a slash-separated string. Leading `/` is implicit.
  factory FsPath.parse(String raw) {
    final parts = raw.split('/').where((p) => p.isNotEmpty).toList();
    final stack = <String>[];
    for (final p in parts) {
      if (p == '.') continue;
      if (p == '..') {
        if (stack.isNotEmpty) stack.removeLast();
        continue;
      }
      stack.add(p);
    }
    return FsPath._(['', ...stack]);
  }

  /// The last path segment, or empty for root.
  String get name => _segments.isEmpty ? '' : _segments.last;

  /// Whether this is the root path.
  bool get isRoot => _segments.length <= 1;

  /// Parent path. Root's parent is itself.
  FsPath get parent {
    if (isRoot) return this;
    return FsPath._(_segments.sublist(0, _segments.length - 1));
  }

  /// Append a single child segment.
  FsPath child(String name) {
    if (name.contains('/')) {
      throw ArgumentError.value(name, 'name', 'cannot contain "/"');
    }
    return FsPath._([..._segments, name]);
  }

  /// Display string. Always starts with `/`.
  @override
  String toString() => _segments.length <= 1 ? '/' : _segments.join('/');

  @override
  bool operator ==(Object other) =>
      other is FsPath && other.toString() == toString();

  @override
  int get hashCode => toString().hashCode;
}
