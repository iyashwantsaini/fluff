# Fluff — Build Plan

The architecture, scope, and phased roadmap for Fluff. This is the
contract that PRs are reviewed against. Companion to [README.md](README.md).

---

## Table of contents

1. [Goals & non-goals](#1-goals--non-goals)
2. [Mental model](#2-mental-model)
3. [Feature pillars & prioritisation](#3-feature-pillars--prioritisation)
4. [Architecture](#4-architecture)
5. [Phased roadmap](#5-phased-roadmap)
6. [Vault & on-the-fly encryption](#6-vault--on-the-fly-encryption)
7. [Theming & skin packs](#7-theming--skin-packs)
8. [UI mapping (wloom)](#8-ui-mapping-wloom)
9. [Quality bar](#9-quality-bar)
10. [Governance & contribution flow](#10-governance--contribution-flow)

---

## 1. Goals & non-goals

### Goals

- **Power-user file manager** for Android first; desktop and TV as
  follow-ons enabled by Flutter.
- **Open source, no ads, no telemetry.** Apache-2.0.
- **Pure Flutter / Dart** for everything we write. We depend on pub.dev
  plugins (which ship their own native shims — that is how Flutter works)
  and we link C libraries through `dart:ffi`. We do **not** write Kotlin /
  Java / Swift / Objective-C ourselves in `app/`.
- **Encrypted by default when the user asks for it** — the vault is a
  first-class mount, not a bolted-on feature.
- **One virtual filesystem** behind every screen.
- **Skinnable** via user-installable theme packs.

### Non-goals

- A built-in web browser. We use Custom Tabs.
- A general video editor. Trim + transcode is enough.
- A Termux clone. We bridge to it via intents.
- A cloud-backed gallery competing with Google Photos.
- Our own hosted cloud storage. We integrate; we don't host.
- Plausible-deniability hidden vaults in v1 (reserved in the format).

---

## 2. Mental model

Four ideas. Get these right and the rest falls into place.

1. **`FsProvider` is the abstraction.** Every storage — local, SAF,
   USB-OTG, archive interior, vault, cloud, SMB / FTP / SFTP / WebDAV,
   recycle bin — implements the same interface. Every viewer and every
   operation talks to that interface, never to `dart:io.File` directly.
2. **One browse screen, N tabs, optional split.** A single Flutter
   route hosts an arbitrary number of tabs; each tab is one folder in
   one `FsProvider`. The dual-pane split is just two of them side by
   side sharing a clipboard.
3. **Skinnable from day one.** Colours, fonts, dimensions, syntax
   palette — everything reads from a `WlmTheme` + a `FluffSyntaxColors`
   theme extension. Skin packs are zips that produce a `WlmTheme.copyWith`.
4. **Long work lives in a foreground task with structured progress.**
   Copy, move, extract, upload, sync, scan and the network servers
   outlive any screen. Activities subscribe to events; closing a screen
   never cancels work.

---

## 3. Feature pillars & prioritisation

Tiers are *intent*, not strict dependency order — phases in §5 decide
what ships when.

### Tier 0 — must exist before we call anything "v1"

- Tabbed dual-pane browser with drag-and-drop between panes.
- Local FS, SAF tree, USB-OTG (via SAF in v1), app sandbox.
- Hidden-files toggle, sort, filter, search (recursive + glob + regex).
- Bookmarks, recents, bulk select, multi-paste clipboard.
- Copy / move / delete / rename with conflict resolution running in a
  foreground task.
- Hash (MD5 / SHA-1 / SHA-256) and compare; properties dialog.
- Built-in text editor, hex viewer, image viewer, audio + video player.
- Theme engine (§7) with one light + one dark default.
- **Vault** with on-the-fly per-file encryption (§6).
- i18n scaffolding (English first; rest community-driven).

### Tier 1 — what makes power users switch

- Archives read+write: zip, 7z (incl. zstd), tar, gz, bz2, xz, RAR
  (read). Via `dart:ffi` to `libarchive`.
- Network protocols: SMB2/3, FTP, SFTP, WebDAV, HTTP browse.
- Network servers: HTTP / WebDAV / FTP / SFTP / SMB / DLNA — each with
  a Quick Settings tile and homescreen widget.
- Cloud accounts: Dropbox, OneDrive, Google Drive, MEGA, Yandex, pCloud,
  Box. Each is just another `FsProvider`.
- **`DocumentsProvider`** so other apps see Fluff's mounts in the system
  picker (delivered via our own generic shim plugin — see §4.3).

### Tier 2 — power-user moats

- Shizuku integration for rootless privileged ops.
- Root mode for the same things when actually rooted (`su` shell-out).
- Recycle bin per mount (including for SAF and cloud).
- App manager: list, extract APK, batch uninstall, signature inspector.
- Audio / image / video tag editor.
- Code editor with multi-tab, encoding picker, hex toggle.
- EBook reader (epub + mobi), PDF viewer, SQLite editor.
- RAW / PSD / JXL image support via `dart:ffi`.
- Chromecast send.
- Termux RUN_COMMAND bridge (`android_intent_plus`).
- APK installer with split / AAB support.
- Duplicate finder background scan.

### Tier 3 — small touches with outsized impact

- Quick Settings tiles for every server.
- Homescreen widgets to toggle servers.
- Boot-time auto-start of servers (user-opt-in).
- Full keyboard navigation + DeX / desktop windowing.
- Android TV / Leanback browse.
- Wear OS companion.
- Per-skin status / navigation bar tints.

### Tier A — beyond what existing file managers ship

- **Storage analyzer** (treemap / sunburst) with drill-down + facets +
  "select all dupes / empty / over-1-year".
- **Bidirectional folder sync** (rsync-style) with chunked resumable
  transfers, scheduling (Wi-Fi only, charging only), conflict strategy
  and a pre-execution diff.
- **Nearby transfer** to other Fluff devices via mDNS + TLS, with an
  open documented protocol.
- **On-device semantic search** — OCR on images / PDFs, EXIF / ID3
  index, tiny embedding index. Inside the vault, the index is encrypted
  next to the header.
- **AI rename + organise**, on-device first (Gemini Nano / MLKit),
  optional cloud LLM with explicit consent. Every action shown as a
  diff before applying.
- **Versioned snapshots** for whitelisted folders (hardlink-based local
  history with a "restore previous version" sheet).

### Tier B — quality-of-life that compounds

- Tags / colours / notes sidecar (SQLite, keyed so it survives renames).
- Folder-level "lock without moving" (lightweight per-folder transparent
  encryption).
- One-time encrypted share links via the embedded HTTP server (URL +
  QR + auto-expire).
- Image / PDF / audio mini-tools (crop, rotate, merge, split, trim,
  EXIF strip, format convert).
- Subtitle download (OpenSubtitles by hash).
- Visual diff (text + image).
- Scriptable batch rename with regex + EXIF / ID3 tokens.
- Workflow / macro recorder + Tasker plugin.

### Tier C — engineering hygiene that ships as features

- Network-aware throttling + metered awareness.
- Recycle bin retention policy + restore-to-original-location.
- Verify-after-copy (re-hash on destination, on by default for SMB/FTP).
- Honest battery + indexing manners (defer to charging / Wi-Fi).
- Undo for the last destructive operation.
- Accessibility from day one (TalkBack, hit targets, large fonts).
- Plugin / skin marketplace inside the app (signed index over GitHub
  releases — no Play Store dependency).
- Fast `kill -9` recovery (journalled operations).

---

## 4. Architecture

### 4.1 The `FsProvider` interface

```dart
abstract interface class FsProvider {
  String get id;                           // "local", "smb:host/share", ...
  FsCapabilities get capabilities;         // read, write, seek, hash, watch
  Stream<FsNode> list(FsPath dir, {bool recursive = false});
  Future<FsNode> stat(FsPath path);
  Stream<List<int>> read(FsPath path, {int? start, int? end});
  StreamSink<List<int>> write(FsPath path, {bool append = false});
  Future<void> delete(FsPath path, {bool recursive = false});
  Future<void> rename(FsPath src, FsPath dst);
  Stream<FsEvent> watch(FsPath dir);       // best-effort; some providers no-op
}
```

Hard rules:

- **UI never touches `dart:io.File` directly.** Even local paths go
  through `LocalFsProvider`.
- **Every viewer consumes `Stream<List<int>>`.** That is what lets the
  vault, archives, SMB shares and DLNA streams all "just work" with
  the same image / video / text widgets.
- **`watch` is allowed to be a no-op** for providers that can't observe
  changes cheaply (cloud, archives). The UI degrades to manual refresh.

### 4.2 Module graph

A Dart workspace managed by [melos](https://melos.invertase.dev/).

```
fluff/
├── pubspec.yaml              workspace root
├── melos.yaml
├── packages/
│   ├── fluff_vfs/            FsNode, FsProvider, LocalFsProvider, SafFsProvider
│   ├── fluff_vault/          VaultHeader, VaultKeys, VaultFsProvider (§6)
│   ├── fluff_remote/         SMB / SFTP / FTP / WebDAV / cloud FsProviders
│   ├── fluff_archive/        zip / tar / gz / bz2 FsProvider (pure Dart)
│   ├── fluff_ops/            OperationQueue + foreground-task glue
│   ├── fluff_sync/           bidirectional sync engine
│   ├── fluff_share/          embedded shelf server, nearby transfer, share links
│   ├── fluff_intel/          OCR, embeddings, AI organise
│   ├── fluff_meta/           tags / colours / notes / snapshots sidecar
│   ├── fluff_tools/          PDF / image / audio mini-tools
│   ├── fluff_ffi/            ffigen bindings: libarchive, libjxl, LibRaw,
│   │                         libmobi, FatFs, libexfat — prebuilt .so / .dylib /
│   │                         .dll per ABI shipped in package
│   ├── fluff_native_shims/   our generic plugins: fluff_documents_provider,
│   │                         fluff_quick_tile (~60 lines of native each)
│   ├── fluff_skin/           WlmTheme bridge + skin-pack loader
│   └── fluff_addons_api/     stable extension contracts (kept narrow)
└── app/                      the Flutter app — wloom UI + DI wiring
```

Every package targets Android + iOS + desktop + web where it makes
sense. `fluff_vfs` and `fluff_vault` are headlessly testable on the Dart
VM — that is where the most important tests live.

### 4.3 Generic shim plugins (why and how)

Three Android surfaces are instantiated by the system *before* any
Flutter engine exists, so they cannot be pure Dart:

| Surface | Why it needs native | Our solution |
| ------- | ------------------- | ------------ |
| `ContentProvider` (used to expose mounts to other apps' system file pickers) | `ContentProvider` is the entry point — there is no Dart yet | Publish `fluff_documents_provider`: a ~60-line `ContentProvider` that spins up a cached `FlutterEngine` via `FlutterEngineGroup` and proxies all callbacks over a `MethodChannel` + `ParcelFileDescriptor` pipe to our Dart `FsProvider`. Reusable; **our app stays Dart-only.** |
| `TileService` (Quick Settings) | System-instantiated | Publish `fluff_quick_tile` with the same trick (or use a maintained `quick_settings` plugin). |
| `AppWidgetProvider` (homescreen widgets) | Android widgets render via `RemoteViews`, not Flutter's renderer | Use the well-maintained [`home_widget`](https://pub.dev/packages/home_widget) plugin — write the widget layout XML once, push data from Dart, click handlers route back into Flutter. |

These shims live in `packages/fluff_native_shims/` and are published as
their own pub.dev packages so any Flutter app can use them.

### 4.4 Third-party dependencies

Decision table — what we use and why. Updated as the ecosystem moves.

| Capability | Package | Notes |
| ---------- | ------- | ----- |
| UI design system | [`wolwoloom`](https://pub.dev/packages/wolwoloom) | wloom — pin a version, vendor in `packages/` if upstream breaks. |
| State + DI | `riverpod` + `get_it` | Small, testable. |
| Routing | `go_router` | Deep links + tab restoration. |
| Local FS | `dart:io`, `path_provider` | Built in. |
| SAF tree | `saf_util` or `shared_storage` | Pick the most-maintained at impl time. |
| Permissions | `permission_handler` | All runtime perms in one place. |
| Vault crypto | `cryptography` | XChaCha20-Poly1305 + Argon2id + HKDF (pure Dart). |
| Biometric | `local_auth` | |
| Keystore-backed secret blob | `flutter_secure_storage` | |
| SMB2/3 | `smb_connect` | Pure Dart. |
| SFTP / SSH | `dartssh2` | Pure Dart. |
| FTP | `ftpconnect` | |
| WebDAV | `webdav_client` | |
| HTTP / cloud REST | `dio` + `http` | |
| OAuth flows | `flutter_appauth` | |
| Embedded HTTP / WebDAV server | `shelf` + `shelf_router` | Pure Dart. |
| Archives (zip / tar / gz / bz2) | `archive` | Pure Dart. |
| 7z / RAR-read / zstd | `dart:ffi` → `libarchive` | Bundled `.so`s via `fluff_ffi`. |
| Image viewer | `photo_view` | |
| RAW images | `dart:ffi` → `LibRaw` | |
| JPEG XL | `dart:ffi` → `libjxl` | |
| PSD | `psd_codec` (or hand-rolled) | |
| Video / audio playback | `media_kit` (libmpv) | Falls back to `video_player`. |
| MediaSession | `audio_service` | |
| PDF viewer | `pdfx` | MuPDF/PDFium via FFI for richer features later. |
| Text / code editor | `re_editor` + `re_highlight` | |
| EPUB | `epub_view` | |
| MOBI / AZW | `dart:ffi` → `libmobi` | |
| QR codes | `qr_flutter` | |
| mDNS discovery | `multicast_dns` | |
| Foreground tasks | `flutter_foreground_task` | |
| Notifications | `flutter_local_notifications` | |
| Background queue | `workmanager` | |
| Boot auto-start | `android_alarm_manager_plus` | Plugin provides the `BOOT_COMPLETED` receiver. |
| Receive SEND / VIEW intents | `receive_sharing_intent` + `app_links` | |
| Send arbitrary intents (Termux bridge) | `android_intent_plus` | |
| Treemap | `treemap` or custom `CustomPainter` | |
| On-device OCR | `google_mlkit_text_recognition` | |
| Image labelling | `google_mlkit_image_labeling` | |
| On-device LLM | `google_generative_ai` + AICore | Pixel-class devices; degrade gracefully. |
| USB layer (OTG raw mount) | `quick_usb` or `flutter_libusb` | Pairs with FatFs / libexfat FFI. |
| Lottie + TGS | `lottie` + `archive` (gunzip) | No native rlottie needed. |
| Shizuku | `flutter_shizuku` | If maintained; otherwise skip in v1. |
| APK signing | `archive` + `pointycastle` | Our own `fluff_apk_signer`, ~400 lines. |
| DLNA client | `upnp2` / `dart_upnp` | |
| DLNA server | `RawDatagramSocket` + `shelf` + our SOAP envelopes | Pure Dart end-to-end. |

### 4.5 Day-one architectural decisions (call them out loud)

1. `FsProvider` is the public surface of everything storage-related.
2. No `dart:io.File` in UI code, ever.
3. Operations live in `flutter_foreground_task` with structured progress
   events; UI subscribes; closing a screen never cancels work.
4. Single `App` + single `SkinController` + single `FsRegistry`. DI via
   Riverpod / `get_it`; no heavyweight container.
5. Skin packs are zips of `theme.json + fonts/ + icons/`. Intent filter
   on `*.fluff-skin` to install.
6. `fluff_addons_api` is its own package, frozen at a version. Add-ons
   depend on the package; the main app never reaches into add-on code.
7. One screen per heavyweight viewer (image, video, text, hex, ebook,
   PDF) — own back stack, own intent filters, own process-death recovery.
8. Ship `fluff_documents_provider` from Phase 5, even with one back end
   — it is free distribution surface inside every app's "Open" picker.
9. Quick Settings tiles + homescreen widgets are 100-line wins once the
   servers exist; ship the first server with its tile + widget in the
   same PR.
10. Strings come from a single `app/lib/l10n/app_en.arb`. Mark every
    string with translator notes. Crowdin / Weblate once strings stabilise.
11. ABI matrix: `arm64-v8a` + `x86_64` (for emulators). Skip `armeabi-v7a`
    unless install-base analytics demand it.
12. `network_security_config.xml` isolates cleartext domains rather than
    flipping `usesCleartextTraffic` globally.

---

## 5. Phased roadmap

Each phase is an independently shippable internal milestone. Tag each
phase as a GitHub release once it's green.

### Phase 1 — workspace + skeleton browser

- `pubspec.yaml` + `melos.yaml` workspace root.
- `packages/fluff_vfs/` with `FsNode`, `FsCapabilities`, `FsProvider`,
  `LocalFsProvider`, `SafFsProvider`, in-memory `MemFsProvider` for
  tests. 100% line coverage.
- `packages/fluff_skin/` wrapping `WlmTheme` + a `SkinController` that
  loads a zip. One light + one dark default skin. Hot-swap.
- `app/` with `WlmShell` + `WlmAppBar` + `WlmTabBar`, one tab over
  `LocalFsProvider`. Open / list / scroll only.

**Done when:** you can browse `/storage/emulated/0/` on an Android
emulator with light/dark skin toggle.

### Phase 2 — operations + foreground task

- `packages/fluff_ops/` with `OperationQueue`, copy / move / delete /
  rename / hash, conflict resolution dialog.
- Wire into `flutter_foreground_task` with progress notifications.
- Undo for the last destructive op.
- Resume-after-kill via journalled operations on disk.
- Multi-select, multi-paste clipboard, properties dialog, search.
- SEND / VIEW intent receivers (`receive_sharing_intent` + `app_links`).

**Done when:** you can copy 10 GB between folders, kill the app
mid-copy, relaunch and resume.

### Phase 3 — vault

- `packages/fluff_vault/` — pure Dart streaming AEAD on top of
  `cryptography`. Header format frozen (§6.4). `VaultFsProvider`
  registers as just another mount.
- Vault create / unlock / lock / auto-lock + biometric.
- `FLAG_SECURE` on every screen while unlocked.
- Quick-add ("Move to vault") action.
- Property-tested with `glados` against libsodium reference vectors.

**Done when:** the unlocked vault uses the *same* browse screen as
Phase 1 and every viewer (image, video, text, PDF) plays files from
it via on-the-fly decryption.

### Phase 4 — remote (first slice)

- `packages/fluff_remote/` with `SmbFsProvider` (`smb_connect`) and
  `SftpFsProvider` (`dartssh2`).
- Account add UI (server, port, share, credentials, save to Keystore).
- Drag-and-drop between a local tab and an SMB tab — *the* demo.

### Phase 5 — archives + DocumentsProvider

- `packages/fluff_archive/` for zip / tar / gz / bz2 (`archive` package).
- `packages/fluff_ffi/` with `libarchive` bindings for 7z, RAR-read, zstd.
  Cross-compile `.so`s in CI for `arm64-v8a` and `x86_64`.
- `packages/fluff_native_shims/fluff_documents_provider/` published to
  pub.dev. Wire `LocalFsProvider` + `SmbFsProvider` through it.

### Phase 6 — servers + tiles + widgets

- `packages/fluff_share/` with `HttpServer` (over `shelf`), `WebDavServer`,
  plus a minimal SOAP-friendly `DlnaServer` (raw SSDP via
  `RawDatagramSocket` + shelf for HTTP).
- FTP and SFTP servers (Dart sockets on top of `dart:io`).
- `fluff_quick_tile` shim for Quick Settings tiles.
- `home_widget` integration for one server-toggle widget; pattern then
  repeats per server.
- Boot auto-start via `android_alarm_manager_plus` (user-opt-in).

### Phase 7 — sync + nearby + share links

- `packages/fluff_sync/` — bidirectional sync engine, chunked resumable
  transfers, scheduling, conflict strategy, pre-execution diff UI.
- Nearby transfer in `fluff_share/`: mDNS discovery (`multicast_dns`) +
  TLS Wi-Fi direct (`dart:io` sockets). Wire protocol documented in
  `docs/protocols/nearby.md`.
- One-time encrypted share links + QR.

### Phase 8 — intel (OCR + semantic search + AI organise)

- `packages/fluff_intel/` — OCR via `google_mlkit_text_recognition`,
  image labels via `google_mlkit_image_labeling`, a tiny embedding
  index (sqlite vector extension or a Dart impl).
- AI rename + organise via `google_generative_ai`; every plan rendered
  as a diff before execution.
- Inside the vault, the index is encrypted alongside the header.

### Phase 9 — polish, accessibility, F-Droid 1.0

- Accessibility pass (TalkBack labels everywhere, hit targets, large
  fonts).
- DeX / desktop windowing keyboard shortcuts.
- TV / Leanback browse.
- Wear OS companion.
- Plugin / skin marketplace (signed index over GitHub releases).
- F-Droid submission + GitHub Releases.

### Phase 1.x parallel work (not blockers)

- `fluff_ffi`: `libjxl`, `LibRaw`, `libmobi` bindings.
- OTG raw mount: `quick_usb` + FatFs / libexfat FFI.
- `fluff_apk_signer` (`archive` + `pointycastle`).
- Shizuku integration.
- Termux RUN_COMMAND bridge.
- Workflow / macro recorder + Tasker plugin.
- Visual diff viewer.

---

## 6. Vault & on-the-fly encryption

### 6.1 Threat model

**In scope:**

- An attacker with USB / `adb pull` access but no password.
- Another app on the device with broad storage permissions.
- A forensic tool scanning the SD card / Files app screenshot.
- Loss of the unlocked device for a few minutes (auto-lock saves us).

**Out of scope** (and we say so in the docs):

- A rooted, compromised OS running while the vault is unlocked — keys
  are in RAM, nothing helps.
- Rubber-hose attacks. No hidden-volume plausible-deniability in v1.

### 6.2 Primitives

| Concern | Choice | Why |
| ------- | ------ | --- |
| Symmetric AEAD | XChaCha20-Poly1305 | Fast in software (ARM without AES-NI), 192-bit nonces, available in `cryptography`. AES-256-GCM also supported; picked per device. |
| KDF | Argon2id, ~500 ms target, ≥ 64 MiB memory | PBKDF2 / scrypt are weaker against GPUs in 2026. |
| Per-file key derivation | HKDF-SHA-256 (master key + per-file salt) | Compromise of one nonce stream doesn't leak the master. |
| File integrity | Built into the AEAD tag per chunk | No separate HMAC. |
| Random | `SecureRandom` (`/dev/urandom`) | Platform default. |

Perf budget: XChaCha20-Poly1305 streams ≥ 400 MB/s single-threaded on a
Snapdragon 7-class device. Encryption is **never** the bottleneck — IO is.

### 6.3 Container shape

One vault = one directory of opaque files.

- Backing directory contains files named like `0a/0a3f9c…b21.fbf`
  (random 256-bit IDs, sharded by first byte).
- Sibling `vault.hdr` holds the wrapped master key + the encrypted
  directory tree.
- Random-access reads, partial writes, cloud-sync-friendly (only the
  changed blob re-uploads), corruption is per-file.
- Observable: file count and individual file sizes. Optional padding
  mode (round up to next 64 KiB / next power of two) for the paranoid.
- Not observable: filenames, MIME, thumbnails, mtimes (we use
  `O_NOATIME` where possible and never update mtime on read).

### 6.4 The header (`vault.hdr`)

```
+------------------------------------------------------+
| magic       : "FLUFFv1\0"          (8 bytes)         |
| version     : u16                                    |
| kdf_id      : u8   (1 = argon2id)                    |
| kdf_params  : { mem_kib:u32, ops:u32, lanes:u8,      |
|                 salt:32 bytes }                      |
| aead_id     : u8   (1 = XChaCha20-Poly1305,          |
|                     2 = AES-256-GCM)                 |
| header_nonce: 24 bytes                                |
| wrapped_master_key : AEAD( kdf(password), 32-byte mk )|
| tree_nonce  : 24 bytes                                |
| encrypted_directory_tree : AEAD( mk, tree_blob )      |
+------------------------------------------------------+
```

`tree_blob` is CBOR: virtual paths, filenames, sizes, mtimes, MIME
hints, and the random 256-bit `file_id` pointing at the on-disk blob.

`kdf_id = 0xFF` is reserved for a future "two-stage probing" mode so
adding hidden vaults later doesn't break v1 readers.

### 6.5 Per-file layout — chunked streaming AEAD

```
+-----------------------------------------------+
| file_header: 16-byte magic + per-file salt 32B |
| chunk[0]   : ciphertext (64 KiB) + tag(16)     |
| chunk[1]   : ciphertext + tag                  |
| ...                                            |
| chunk[N-1] : ciphertext + tag (final flag set) |
+-----------------------------------------------+
```

- Per-file key = `HKDF(master_key, file_salt, "fluff-file-v1")`.
- Per-chunk nonce = `chunk_index || 0` (counter; file key is fresh).
- 64 KiB chunks: small enough for random access (seek → divide →
  decrypt one chunk), large enough that tag overhead is ~0.025% and
  OS readahead stays effective.
- Implemented as a thin ~150-line wrapper around `cryptography`'s
  `Xchacha20.poly1305Aead()`. The whole spec is in this section;
  property-test against libsodium reference vectors in CI.

### 6.6 Wiring into the VFS

```dart
class VaultFsProvider implements FsProvider {
  VaultFsProvider({
    required FsProvider backing,    // local, SAF, cloud, ...
    required FsPath mountPoint,
    required VaultKeys keys,        // non-null only while unlocked
  });
  // ...
}
```

When **locked**, `VaultFsProvider` is not registered; the user sees
the backing directory of opaque blobs (and, by default, Fluff hides it
from the normal browser unless "Show vault container" is on).

When **unlocked**, it registers as a top-level mount named "Vault".
`list("/Photos")` reads the in-memory tree from the header.
`read("/Photos/IMG_001.jpg")` returns a `Stream<List<int>>` that
decrypts chunks on the fly.

For third-party intents that need a `content://` URL we serve one from
our embedded `shelf` server bound to localhost, decrypting on demand.
**Never** write decrypted bytes to `cacheDir`.

### 6.7 Unlock UX

- Password field + optional biometric. Password is the source of truth;
  biometric unlocks a Keystore-wrapped copy of the master key
  (`KeyGenParameterSpec.setUserAuthenticationRequired(true)`).
- Inside the vault: identical browser, identical viewers. Only chrome
  difference is a lock badge and a "Lock vault" action.
- Auto-lock triggers (all configurable): app backgrounded N seconds
  (default 60), screen off (default on), process death (always),
  manual.
- `FLAG_SECURE` on every screen while unlocked.
- Quick-add: long-press a file outside the vault → "Move to vault".
  Encrypts in place into the backing dir, best-effort overwrite +
  delete of the plaintext. Real secure-delete on flash is a myth;
  document this honestly in settings.

### 6.8 Metadata leakage

| Leak | Mitigation |
| ---- | ---------- |
| Number of files | Acceptable. Documented. |
| Per-file size (within ~80 bytes) | Optional padding mode. Off by default. |
| Total vault size | Trivially observable. Acceptable. |
| Access times | `O_NOATIME` where possible. Don't update mtime on read. |
| Filenames | Zero leak — names live only in the encrypted tree. |
| MIME / extension | Zero leak — all blobs use a uniform `.fbf` extension. |
| Magic bytes at offset 0 | High-entropy salt + tiny magic — looks random. |

### 6.9 Honest costs

- Cloud sync of a vault works; **concurrent edits are your problem.**
  v1: serialise via a `.lock` file with 30 s TTL. v2: CRDT for the tree.
- No partial cloud sharing — decrypt locally first to share one file.
- **Lost password = lost data.** Recovery code (32-char base32) shown
  once at vault creation, never stored by us.
- Full-text search inside the vault is v2 (encrypted SQLite-FTS5
  alongside the header). v1 searches filenames only.

### 6.10 Implementation rules

1. Master key is `Uint8List(32)` in a `Cleanable` holder that zeroes on
   lock. Never a `String`.
2. Single decrypt path — every viewer reads through
   `VaultFsProvider.read()`. No "fast path".
3. No plaintext temp files. Stream from the embedded server, die on
   close.
4. Thumbnails inside the vault are themselves stored encrypted in a
   `/.thumbs/<file_id>` sub-tree of the header.
5. `FLAG_SECURE` on every screen touching the vault.
6. CI benchmark: encrypt 1 GiB of random data on a reference device,
   fail the build if it regresses ±10%.
7. No telemetry while a vault is unlocked. Ever.

---

## 7. Theming & skin packs

The skin engine is the design system: every colour, font and dimension
the UI uses comes from the same place.

### 7.1 Where things come from

- Foundation: `WlmTheme` + `WlmTokens` from wloom (`wolwoloom` on
  pub.dev). Light + dark variants out of the box.
- Extension: a `FluffSyntaxColors extends WlmThemeExtension<FluffSyntaxColors>`
  for the code-editor / hex-viewer palette and any non-wloom roles
  Fluff needs.

### 7.2 Skin pack format

A `*.fluff-skin` is a zip:

```
my-skin.fluff-skin
├── theme.json     required — produces a WlmTheme.copyWith(...)
├── fonts/         optional — *.ttf / *.otf bundled with the pack
└── icons/         optional — SVG/PNG overrides for sidebar / mime icons
```

`theme.json` shape (excerpt):

```jsonc
{
  "name": "Midnight",
  "author": "...",
  "mode": "dark",
  "colors": {
    "surface":          "#0e0f12",
    "surfaceContainer": "#15171b",
    "primary":          "#a5b4fc",
    "onSurface":        "#e6e8ee"
  },
  "type": {
    "primary": "fonts/InterVariable.ttf",
    "mono":    "fonts/JetBrainsMono-Regular.ttf"
  },
  "tokens": {
    "radius.card": 16,
    "spacing.lg":  24
  },
  "syntax": {
    "keyword": "#a5b4fc",
    "string":  "#9be1a1",
    "comment": "#6c7280"
  }
}
```

### 7.3 Install path

- Intent filter on `*.fluff-skin` opens the import dialog.
- Skin packs land in `app-data/skins/<id>/`.
- Hot-swap with no restart — the `SkinController` reads the new theme
  and `WlmTheme` rebuilds.

---

## 8. UI mapping (wloom)

Concrete widget choice per Fluff screen. Lock this before building so
PRs don't disagree on chrome.

| Fluff screen | wloom widgets / patterns |
| ------------ | ------------------------ |
| App shell (drawer, app bar, bottom nav on phone, rail on tablet) | `WlmAppScaffold` + `WlmAppBar` + `WlmDrawer` + `WlmBottomNav` / responsive `WlmShell` |
| Tabbed browser | `WlmTabBar` along the top; reorder via `Draggable` |
| Breadcrumb path bar | `WlmBreadcrumbs` |
| File list | `WlmListTile` in a `ListView.builder`; selection overlay via `WlmCheckboxTile` |
| File grid | `WlmMasonryGrid` + `WlmProgressiveImage` |
| Dual-pane split | Custom `Row` of two `WlmShell`s sharing a clipboard provider |
| Action bar / context menu | `WlmActionSheet` (mobile) or `WlmPopover` (desktop / right-click) |
| Command palette (Ctrl-K) | `WlmCommandPalette` |
| Properties dialog | `WlmDialog` + `WlmSpecRow` grid |
| Operation progress | `WlmProgressBar` + `WlmProgressRing` in a persistent `WlmCallout`; mirrored to a foreground notification |
| Bulk-op result | `WlmToast` (success) / `WlmBanner` (warnings) / `WlmErrorState` (fatal) |
| Empty / no results | `WlmEmptyState` |
| Loading | `WlmGridSkeleton`, `WlmSkeleton`, `WlmLoader`, `WlmRefresh` |
| Search | `WlmSearchField` in the app bar; results in `WlmListTile` with `WlmChip` highlights |
| Storage analyzer | `treemap` painted with `WlmColors`; legend in `WlmStat` + `WlmKpiCard` |
| Text / code editor | `re_editor` styled by `WlmCodeBlock` tokens |
| Hex viewer | Bespoke widget using `WlmCodeBlock` mono + `WlmDivider` hairlines |
| Image viewer | `photo_view` inside a `WlmSurface`; overlay `WlmIconButton`s |
| Video / audio player | `media_kit` widget inside a `WlmCard`; transport from `WlmSlider` + `WlmIconButton` |
| PDF / EPUB viewer | `pdfx` / `epub_view` inside `WlmSurface`; chapter list in `WlmDrawer` |
| Vault unlock | `WlmDialog` with `WlmPinInput` (or `WlmTextField` for long passphrases) + biometric `WlmIconButton` |
| Vault badge | `WlmBadge` + lock icon; `FluffSyntaxColors`-aware accent |
| Settings | `WlmPageHeader` + `WlmSectionLabel` + `WlmSwitchTile` / `WlmRadioTile` / `WlmDropdown` |
| Server config | `WlmForm` + `WlmTextField` + `WlmKeyField` + `WlmSegmentedControl` |
| Cloud account add | `WlmStepDots` wizard, `WlmCallout` for OAuth status |
| Sync rules | `WlmDataTable`; per-row `WlmActionRow` |
| Nearby devices | `WlmAvatarStack` of discovered peers; tap → `WlmBottomSheet` |

### Risks worth tracking

- **Mono-only typography:** wloom defaults to JetBrains Mono. Great
  for code / paths; may look cramped for CJK / Devanagari / Arabic.
  Add a `WlmType` override that swaps to a proportional font for
  non-Latin scripts before locking down strings.
- **Hairline borders + no shadows** read as low-contrast versus
  Material 3. Run a usability pass on low-brightness OLED outdoors;
  bump `outlineVariant` opacity if affordances disappear.
- **wloom is at `0.3.x`** — pin a version, vendor into the workspace,
  treat upstream breakage as a Fluff problem we can patch.
- **No file-manager-specific components in wloom** — we'll build the
  file row, breadcrumb-with-overflow, dual-pane splitter and hex view
  ourselves and contribute them back upstream where useful.

---

## 9. Quality bar

- **Tests:**
  - `fluff_vfs`, `fluff_vault`, `fluff_archive`, `fluff_sync`: 90%+
    line coverage, property tests with `glados` where the input space
    is large (paths, ciphertexts, sync graphs).
  - Integration tests for `app/` exercise the browse → copy → paste →
    delete path on a real emulator in CI.
- **Benchmarks** in CI for vault encrypt/decrypt; fail on ±10% regression.
- **Static analysis:** `dart analyze` clean. Custom lints for "no
  `dart:io.File` in `app/`", "no `Random()` in `fluff_vault`".
- **Accessibility:** TalkBack labels on every interactive widget;
  large-font + tap-target audits in CI via golden tests.
- **i18n:** all user-visible strings come from ARB. PRs that hard-code
  English fail review.
- **Telemetry:** **none** in v1. If we ever add opt-in crash reporting,
  it ships disabled-by-default and never runs while a vault is unlocked.
- **Reproducible builds** for the F-Droid release.
- **Conventional Commits** + semantic versioning per package.

---

## 10. Governance & contribution flow

- License: **Apache-2.0** for code, **CC-BY-4.0** for docs.
- Single maintainer to start (the repo owner). RFC-style proposals for
  anything touching `FsProvider`, the vault format, the nearby-transfer
  wire protocol or `fluff_addons_api`. Drop a markdown file in
  `docs/rfcs/NNNN-title.md`, open a PR, discuss, merge or reject.
- Issue labels: `good first issue`, `help wanted`, `rfc`, `phase-N`,
  `area/<package>`, `kind/{bug,feature,docs,perf,a11y,i18n}`.
- PRs target `main`. Required checks: format, analyze, tests, golden
  diffs.
- Releases: per-package semver in `pubspec.yaml`; app version follows
  phases (Phase 1 → `0.1.x`, Phase 9 / public 1.0 → `1.0.0`).
- Code of Conduct: Contributor Covenant 2.1.

---

## Appendices

### A. Glossary

| Term | Meaning |
| ---- | ------- |
| **VFS** | Virtual filesystem; the `FsProvider` interface and everything that implements it. |
| **Mount** | A registered `FsProvider` with a user-visible name and icon. |
| **Backing storage** | The on-disk directory that holds a vault's ciphertext blobs. |
| **Header** | `vault.hdr` — wrapped master key + encrypted directory tree. |
| **Shim plugin** | A small reusable plugin we publish to bridge an Android surface (e.g. `ContentProvider`) to a Flutter engine. |
| **Skin pack** | A `*.fluff-skin` zip that produces a `WlmTheme.copyWith(...)`. |

### B. Reserved identifiers / formats

| Item | Value |
| ---- | ----- |
| Vault magic | `FLUFFv1\0` |
| Vault file extension | `.fbf` |
| Skin pack extension | `.fluff-skin` |
| Intent host (deep links) | `fluff://` |
| Shim plugin package prefix | `fluff_native_shims/` |
| Add-on contract package | `fluff_addons_api` |
