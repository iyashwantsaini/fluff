# fluff_documents_provider

> **Status:** 🚧 scaffold only. Tracking issue: Phase 6 of
> [PLAN.md](../../../PLAN.md). The Kotlin shim and Dart bridge below are
> stubs that document the intended shape — they do not run yet.

A reusable Android `ContentProvider` shim that exposes a **Dart-defined**
[`FsProvider`](../../fluff_vfs/) to the system **file picker**
(`Intent.ACTION_OPEN_DOCUMENT` / `ACTION_CREATE_DOCUMENT`) and to other
apps' Storage Access Framework integrations — without forcing the host
Flutter app to write any Kotlin.

## Why this exists

Android instantiates `ContentProvider` from `AndroidManifest.xml`
**before** any Flutter engine boots. So the entry point *must* be JVM
code. This package is the smallest reusable piece that bridges that gap:

1. A `DocumentsProvider` subclass (Kotlin, ~60 lines).
2. A cached background `FlutterEngine` via `FlutterEngineGroup` with an
   entrypoint that the host app registers from Dart.
3. A `MethodChannel` + `ParcelFileDescriptor` pipe between the two
   sides so every callback (`queryRoots`, `queryChildDocuments`,
   `openDocument`, …) round-trips into Dart and back.

The host Flutter app stays 100% Dart.

## Intended usage (forward-looking)

```dart
import 'package:fluff_documents_provider/fluff_documents_provider.dart';
import 'package:fluff_vfs/fluff_vfs.dart';

@pragma('vm:entry-point')
void documentsProviderMain() {
  FluffDocumentsProvider.serve(
    rootsBuilder: () async => [
      DocumentsRoot(
        id: 'vault-default',
        title: 'Fluff vault',
        provider: MyVaultFsProvider(),
      ),
    ],
  );
}
```

Then in `android/app/src/main/AndroidManifest.xml`:

```xml
<provider
  android:name="dev.fluff.documents_provider.FluffDocumentsProvider"
  android:authorities="${applicationId}.documents"
  android:exported="true"
  android:grantUriPermissions="true"
  android:permission="android.permission.MANAGE_DOCUMENTS">
  <intent-filter>
    <action android:name="android.content.action.DOCUMENTS_PROVIDER"/>
  </intent-filter>
</provider>
```

## License

Apache-2.0. See [LICENSE](LICENSE).
