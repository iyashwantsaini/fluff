/// Sharing servers and nearby-transfer scaffolding for Fluff.
///
/// The Phase 6 web slice exposes a pure-Dart model
/// ([ShareServer], [ShareServerKind]) and an in-memory
/// [ShareServerController] that simulates start/stop and a tiny
/// byte counter. Real `dart:io` socket implementations land in
/// Phase 6.1 on Android.
library;

export 'src/share_server.dart';
export 'src/share_server_controller.dart';
export 'src/share_server_kind.dart';
