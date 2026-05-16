import 'package:flutter/material.dart';

import 'wlm_tokens.dart';

/// `WlmTheme` is the only place colours, typography and tokens are
/// assembled. The rest of the app reads `WlmTheme.of(context)`.
///
/// Today this wraps a Material 3 [ThemeData] tuned to look like the
/// wloom design system (hairline borders, periwinkle accent, mono
/// type). In a later iteration we swap in `wolwoloom` without
/// changing any call sites.
@immutable
class WlmTheme extends InheritedWidget {
  final ThemeData themeData;
  final WlmTokens tokens;
  final Brightness brightness;

  const WlmTheme({
    super.key,
    required this.themeData,
    required this.tokens,
    required this.brightness,
    required super.child,
  });

  static WlmTheme of(BuildContext context) {
    final t = context.dependOnInheritedWidgetOfExactType<WlmTheme>();
    assert(t != null, 'WlmTheme.of() called outside a WlmTheme ancestor');
    return t!;
  }

  @override
  bool updateShouldNotify(WlmTheme oldWidget) =>
      brightness != oldWidget.brightness || tokens != oldWidget.tokens;

  // ---- Theme factories -------------------------------------------------

  static const Color _accent = Color(0xFF7C8CFF); // periwinkle
  static const String _monoFamily = 'JetBrainsMono';

  static ThemeData light(WlmTokens tokens) =>
      _buildTheme(Brightness.light, tokens);

  static ThemeData dark(WlmTokens tokens) =>
      _buildTheme(Brightness.dark, tokens);

  static ThemeData _buildTheme(Brightness b, WlmTokens tokens) {
    final scheme = ColorScheme.fromSeed(seedColor: _accent, brightness: b)
        .copyWith(
          // hairline outline — slightly stronger than default M3 for visibility
          outlineVariant: b == Brightness.dark
              ? const Color(0xFF2B2F3A)
              : const Color(0xFFE3E5EE),
        );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      fontFamily: _monoFamily,
      fontFamilyFallback: const ['Roboto', 'Helvetica', 'Arial'],
      visualDensity: VisualDensity.standard,
    );

    final tt = base.textTheme.copyWith(
      displayLarge: base.textTheme.displayLarge?.copyWith(
        fontSize: 28,
        fontWeight: FontWeight.w500,
        letterSpacing: -0.2,
        color: scheme.onSurface,
      ),
      titleLarge: base.textTheme.titleLarge?.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w500,
        color: scheme.onSurface,
      ),
      bodyMedium: base.textTheme.bodyMedium?.copyWith(
        fontSize: 14,
        height: 1.45,
        color: scheme.onSurface,
      ),
      labelSmall: base.textTheme.labelSmall?.copyWith(
        fontSize: 12,
        letterSpacing: 0.4,
        fontWeight: FontWeight.w500,
        color: scheme.onSurfaceVariant,
      ),
    );

    return base.copyWith(
      textTheme: tt,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: tt.titleLarge,
        iconTheme: IconThemeData(color: scheme.onSurface),
        shape: Border(
          bottom: BorderSide(color: scheme.outlineVariant, width: 1),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurfaceVariant,
        textColor: scheme.onSurface,
        minVerticalPadding: tokens.spacing.md,
        contentPadding: EdgeInsets.symmetric(
          horizontal: tokens.spacing.lg,
          vertical: tokens.spacing.xs,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.radius.md),
        ),
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: scheme.outlineVariant),
          borderRadius: BorderRadius.circular(tokens.radius.md),
        ),
      ),
      iconTheme: IconThemeData(color: scheme.onSurfaceVariant, size: 20),
    );
  }
}
