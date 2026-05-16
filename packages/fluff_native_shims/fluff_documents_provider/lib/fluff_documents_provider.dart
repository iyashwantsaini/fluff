/// Public Dart surface for the Fluff DocumentsProvider shim.
///
/// **Status:** scaffold. The Android bridge is not wired yet — calls to
/// [FluffDocumentsProvider.serve] currently register the builder in
/// memory but no native invocations flow through. Tracking: Phase 6 of
/// `PLAN.md`.
library;

import 'dart:async';

/// A root that will be advertised to the system file picker.
class DocumentsRoot {
  const DocumentsRoot({
    required this.id,
    required this.title,
    this.summary,
    this.iconResource,
  });

  /// Stable id used as the SAF root document id.
  final String id;

  /// Human-readable title shown in the picker.
  final String title;

  /// Optional one-line description.
  final String? summary;

  /// Optional Android drawable resource name (e.g. `ic_fluff_root`).
  final String? iconResource;
}

/// Callback that returns the current set of roots.
///
/// Called on every `queryRoots` from the system.
typedef DocumentsRootsBuilder = FutureOr<List<DocumentsRoot>> Function();

/// Entry point invoked from a `@pragma('vm:entry-point')` function in
/// the host app's main isolate's sibling isolate (started by the shim's
/// `FlutterEngineGroup`).
class FluffDocumentsProvider {
  FluffDocumentsProvider._();

  static DocumentsRootsBuilder? _rootsBuilder;

  /// Register the [rootsBuilder] that the native shim will call to
  /// describe the roots Fluff exposes to the system file picker.
  static void serve({required DocumentsRootsBuilder rootsBuilder}) {
    _rootsBuilder = rootsBuilder;
    // TODO(phase-6): bind a MethodChannel to dev.fluff.documents_provider
    // and dispatch queryRoots/queryChildDocuments/openDocument here.
  }

  /// Internal: returns the currently registered builder (or `null` if
  /// the host app has not called [serve] yet).
  static DocumentsRootsBuilder? get registeredBuilder => _rootsBuilder;
}
