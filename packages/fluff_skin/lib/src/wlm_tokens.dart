import 'package:flutter/widgets.dart';

/// Spacing tokens. Multiples of 4 so vertical rhythm composes.
///
/// Mirrors the canonical table in `docs/DESIGN.md` §1.
@immutable
class WlmSpacing {
  final double xs;
  final double sm;
  final double md;
  final double lg;
  final double xl;
  final double xxl;

  const WlmSpacing({
    this.xs = 4,
    this.sm = 8,
    this.md = 12,
    this.lg = 16,
    this.xl = 24,
    this.xxl = 32,
  });

  /// The canonical page-edge gutter for the given viewport width.
  /// Phone (≤ 600) → [lg]; tablet+ → [xl].
  double pageGutter(double width) => width <= 600 ? lg : xl;
}

/// Corner-radius tokens.
@immutable
class WlmRadius {
  final double sm;
  final double md;
  final double lg;
  final double xl;

  const WlmRadius({this.sm = 6, this.md = 12, this.lg = 16, this.xl = 20});
}

/// Aggregated tokens. Read these via `WlmTheme.of(context).tokens`.
@immutable
class WlmTokens {
  final WlmSpacing spacing;
  final WlmRadius radius;

  const WlmTokens({
    this.spacing = const WlmSpacing(),
    this.radius = const WlmRadius(),
  });
}
