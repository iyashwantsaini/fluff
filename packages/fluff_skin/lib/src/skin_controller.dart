import 'package:flutter/material.dart';

import 'wlm_theme.dart';
import 'wlm_tokens.dart';

/// Tracks brightness + tokens + (later) loaded skin packs.
///
/// Wrap your app in [SkinScope] to expose a [WlmTheme] inherited
/// widget; the rest of the tree reads it via [WlmTheme.of].
class SkinController extends ChangeNotifier {
  ThemeMode _mode;
  WlmTokens _tokens;

  SkinController({
    ThemeMode mode = ThemeMode.system,
    WlmTokens tokens = const WlmTokens(),
  }) : _mode = mode,
       _tokens = tokens;

  ThemeMode get mode => _mode;
  WlmTokens get tokens => _tokens;

  void setMode(ThemeMode mode) {
    if (mode == _mode) return;
    _mode = mode;
    notifyListeners();
  }

  void toggleBrightness(BuildContext context) {
    final platform = MediaQuery.platformBrightnessOf(context);
    final effective = _mode == ThemeMode.system
        ? platform
        : (_mode == ThemeMode.dark ? Brightness.dark : Brightness.light);
    setMode(effective == Brightness.dark ? ThemeMode.light : ThemeMode.dark);
  }

  void setTokens(WlmTokens tokens) {
    _tokens = tokens;
    notifyListeners();
  }
}

/// Root widget that subscribes to a [SkinController], rebuilds the
/// [MaterialApp]'s [ThemeData] when it changes, and exposes
/// [WlmTheme] via an inherited widget.
class SkinScope extends StatelessWidget {
  final SkinController controller;
  final Widget Function(BuildContext, ThemeData, ThemeData, ThemeMode) builder;

  const SkinScope({super.key, required this.controller, required this.builder});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final tokens = controller.tokens;
        final light = WlmTheme.light(tokens);
        final dark = WlmTheme.dark(tokens);
        final platform = MediaQuery.platformBrightnessOf(context);
        final brightness = switch (controller.mode) {
          ThemeMode.light => Brightness.light,
          ThemeMode.dark => Brightness.dark,
          ThemeMode.system => platform,
        };
        return WlmTheme(
          themeData: brightness == Brightness.dark ? dark : light,
          tokens: tokens,
          brightness: brightness,
          child: builder(context, light, dark, controller.mode),
        );
      },
    );
  }
}
