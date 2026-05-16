/// Fluff design-system bridge.
///
/// All UI in `app/` reads its colours, spacing and typography through
/// the [WlmTheme] + [WlmTokens] surfaces exposed from this package.
/// Concrete renderers (today: a self-contained Material 3 theme;
/// tomorrow: `wolwoloom`) live behind this seam.
library;

export 'src/skin_controller.dart';
export 'src/wlm_theme.dart';
export 'src/wlm_tokens.dart';
