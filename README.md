<div align="center">

<img src="docs/branding/fluff-icon.png" alt="Fluff icon" width="128" height="128"/>

# Fluff

**A modern, open-source file manager for Android — built entirely in pure [Flutter](https://flutter.dev) with the [wloom](https://github.com/iyashwantsaini/wloom) design system.**

[![CI](https://github.com/iyashwantsaini/fluff/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/iyashwantsaini/fluff/actions/workflows/ci.yml)
[![Release](https://github.com/iyashwantsaini/fluff/actions/workflows/release.yml/badge.svg)](https://github.com/iyashwantsaini/fluff/actions/workflows/release.yml)
[![Latest release](https://img.shields.io/github/v/release/iyashwantsaini/fluff?include_prereleases&sort=semver)](https://github.com/iyashwantsaini/fluff/releases)
[![License](https://img.shields.io/github/license/iyashwantsaini/fluff)](LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-stable-02569B?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.11%2B-0175C2?logo=dart)](https://dart.dev)
[![No telemetry](https://img.shields.io/badge/telemetry-none-success)](#how-the-vault-really-works)

</div>

> **Status:** active pre-1.0 development. Designing in the open. Code
> lands in small, reviewable PRs against the plan in [PLAN.md](PLAN.md).
> Signed APK + AAB are produced on every `v*.*.*` tag — see
> [Releases](https://github.com/iyashwantsaini/fluff/releases).

---

## Why another file manager?

Most Android file managers fall into one of two buckets:

- **Stock pickers** (Files by Google, OEM apps) — clean, but you outgrow
  them the first time you need SMB, an archive, or a dual-pane copy.
- **Power-user apps** — feature-rich, but visually dated, ad-supported, or
  closed-source.

Fluff aims to be the third option: **power-user surface area, modern
typography-first UI, open source, no ads, no tracking, encrypted by default
when you want it**.

The headline differentiator is a built-in **Vault**: a folder that, when
locked, looks like high-entropy noise to every other app on the device;
when unlocked, behaves exactly like a normal folder inside Fluff with
on-the-fly streaming decryption. Think VeraCrypt, but the explorer is
baked in. Full spec in [PLAN.md §6](PLAN.md#6-vault--on-the-fly-encryption).

---

## Feature pillars

### Core browser
- Tabbed, dual-pane file browser with drag-and-drop between panes.
- One unified virtual filesystem: local, SAF, USB-OTG, archives, cloud,
  SMB / FTP / SFTP / WebDAV, app sandbox, recycle bin — every viewer and
  every operation talks to the same abstraction.
- Bookmarks, recents, multi-select, multi-paste clipboard, recursive
  search (glob + regex), bulk rename with EXIF/ID3 tokens.
- Copy / move / delete / hash / compare with conflict resolution, all
  running in a foreground task with structured progress, undo, and
  resume-after-kill.

### Vault (encrypted, on-the-fly)
- Per-file XChaCha20-Poly1305 with Argon2id KDF, chunked streaming AEAD.
- Filenames, sizes hints, and thumbnails live inside the encrypted
  header — on disk you see only opaque blobs.
- Unlocked vault appears as a normal mount; every viewer (image, video,
  PDF, text, hex, ebook) works unchanged.
- Auto-lock on background / screen-off / process death; biometric unlock
  backed by Android Keystore; `FLAG_SECURE` while unlocked.

### Network & remote
- SMB2/3, SFTP, FTP, WebDAV, HTTP browse, plus the major cloud providers
  via OAuth.
- Built-in inbound servers: HTTP / WebDAV / FTP / SFTP / SMB / DLNA, each
  toggleable from a Quick Settings tile or homescreen widget.
- Bidirectional folder sync with chunked, resumable transfers.
- Nearby device transfer (mDNS + TLS Wi-Fi direct) — open protocol so
  desktop / other clients can interop.

### Viewers & editors
- Text & code editor with syntax highlighting.
- Image viewer including RAW, PSD, JPEG XL.
- Audio + video player with lock-screen controls.
- PDF and EPUB / MOBI readers.
- Hex viewer, SQLite editor, archive (zip / 7z / tar / gz / bz2 / zstd /
  RAR-read).

### Modern touches
- On-device OCR + semantic search ("find the PDF where I mentioned X").
- AI rename / organize, with every action shown as a reviewable diff
  before executing — never silent.
- Storage analyzer treemap, duplicate finder, junk cleaner.
- Tags, colors, notes as a sidecar metadata layer that survives renames.
- Versioned snapshots for chosen folders.
- One-time encrypted share links via the embedded HTTP server.

### Platform
- Android phone, tablet, foldable, DeX / desktop windowing, Android TV,
  Wear OS companion.
- Tasker plugin + documented intent API for automations.
- User-installable skin packs (`*.fluff-skin`).

For the full prioritised list and what is in/out of v1, see
[PLAN.md §3](PLAN.md#3-feature-pillars--prioritisation).

---

## Architecture in one line

A Dart workspace of small packages around a single `FsProvider`
abstraction, a Flutter app built from wloom widgets, with `dart:ffi` for
performance-critical C libraries and a tiny set of generic plugins we
publish for the few Android surfaces that the system instantiates before
any Flutter engine exists.

Full module graph and rationale in [PLAN.md §4](PLAN.md#4-architecture).

---

## Project status & roadmap

| Phase | Milestone | Status |
| ----- | --------- | ------ |
| 0 | Spec & plan locked | ✅ |
| 1 | Workspace + `fluff_vfs` + `fluff_skin` + minimal browse screen | ✅ |
| 2 | `fluff_ops` (queue, copy/move/delete, conflicts) + multi-select + dialogs (web slice; Android foreground-task + journalled resume deferred to Phase 2.1) | ✅ |
| 3 | `fluff_vault` (encrypted streaming AEAD) | ✅ (web slice; biometric / FLAG_SECURE / Move-to-vault → Phase 3.1) |
| 4 | `fluff_remote` (SMB + SFTP) + foreground operations | ✅ (web slice with mock provider + accounts UI; real `smb_connect` / `dartssh2` + foreground operations → Phase 4.1) |
| 5 | `fluff_ffi` + `libarchive` (7z / RAR-read / zstd) | ✅ (Phase 5 web slice: `fluff_archive` read-only zip/tar/tar.gz viewer; libarchive 7z/RAR/zstd + write support → Phase 5.1) |
| 6 | `fluff_documents_provider` shim plugin | 🟡 scaffold ([packages/fluff_native_shims/fluff_documents_provider](packages/fluff_native_shims/fluff_documents_provider/)) |
| 7 | Servers + Quick Settings tiles + homescreen widgets | ✅ (Phase 6 web slice: `fluff_share` model + `ShareServerController` + Servers screen; real `shelf` / `dart:io` sockets, Quick Tiles, home widgets, boot auto-start → Phase 6.1) |
| 8 | Sync, nearby transfer, share links | ✅ (Phase 7 web slice: `fluff_sync` with `SyncEngine` diff + `NearbyDiscovery` + Sync / Nearby screens; real mDNS, TLS Wi-Fi Direct, resumable transfers, scheduling, encrypted share links + QR → Phase 7.1) |
| 9 | OCR + semantic search + AI organise | ✅ (Phase 8 web slice: `fluff_intel` with `SemanticIndex` + `OrganisePlanner` + Search / AI-organise screens; real ML Kit OCR, on-device embeddings, Gemini organise → Phase 8.1) |
| 10 | Public 1.0 (F-Droid + GitHub Releases) | ✅ (Phase 9 web slice: Settings + About with theme / a11y toggles, version 1.0.0-rc.1, zero-telemetry promise; real persistence + fastlane metadata + skin marketplace → Phase 9.1) |

Detailed PR-by-PR plan: [PLAN.md §5](PLAN.md#5-phased-roadmap).

### Remaining work after the v0.1 web slice

The phase table above shows the web-slice progress. The Android-only and
hardware-bound features tracked for `0.2`+ releases are:

- **2.1** — `flutter_foreground_task` runner + journalled resume for
  copy / move / hash so closing a screen never aborts work.
- **3.1** — biometric unlock via Android Keystore, `FLAG_SECURE` while
  vault is open, "Move to vault" SAF intent, anti-screenshot toggle.
- **4.1** — real `smb_connect` + `dartssh2` providers, WebDAV/FTP/HTTP
  Auth, credential vault entries, foreground transfer queue.
- **5.1** — `fluff_ffi` + bundled `libarchive` for 7z / RAR-read / zstd
  read + write, multi-volume splits.
- **6** — `fluff_documents_provider` shim plugin (publish Fluff vaults
  and remotes to Android's system document picker).
- **6.1** — embedded `shelf` HTTP / WebDAV / FTP / SFTP / SMB / DLNA
  servers, Quick Settings tiles, homescreen widgets, boot auto-start.
- **7.1** — real mDNS + TLS Wi-Fi Direct nearby transfer, resumable
  uploads, scheduling, encrypted share-link generation with QR.
- **8.1** — ML Kit OCR, on-device embedding model, Gemini "organise"
  with reviewable diff.
- **9.1** — native viewers for video (`video_player`), audio
  (`just_audio`), PDF (`pdfx`), EPUB / MOBI (`epub_view`).
- **9.2** — Share intent (`share_plus`), `Intent.ACTION_INSTALL_PACKAGE`
  for APKs, "Open with…" chooser, file-association registration.
- **10** — skin marketplace, F-Droid metadata, fastlane, real
  `shared_preferences` settings persistence.

---

## How the vault really works

The user-facing question matters: **if someone else picks up your phone,
or you uninstall Fluff, what happens to vaulted files?**

- The vault is a single opaque container on disk. Other apps (and
  `adb pull`) see only ciphertext — file names, sizes, mtimes are
  encrypted inside the tree blob. No part of the plaintext name ever
  hits the filesystem.
- Each file is split into 64 KiB chunks; each chunk is sealed with
  **XChaCha20-Poly1305**. The master key is wrapped by a key derived
  from your passphrase via **Argon2id** (memory-hard, side-channel
  resistant). Brute-forcing the container without the passphrase is the
  cost of Argon2id × number of guesses.
- **If you clear app data, the vault container is deleted** — by default
  it lives in Fluff's private storage (`/data/data/dev.fluff/...`),
  which Android wipes on "Clear data" / uninstall. **If that is not
  what you want**, point the vault at a path you control (SAF folder,
  SD card, USB-OTG) when you create it; that container survives Fluff
  being uninstalled, and any device with Fluff installed can open it
  with the right passphrase.
- Auto-lock fires on background, screen-off, or process death. While
  unlocked, the activity sets `FLAG_SECURE` (Phase 3.1) so the vault
  doesn't appear in the recents thumbnail and screen-recording APIs.
- The vault format is specified in
  [PLAN.md §6](PLAN.md#6-vault--on-the-fly-encryption). It is intended
  to remain readable by any third-party implementation.

---

## Releases & CI

CI lives in [.github/workflows/](.github/workflows/) and has zero
third-party runners — everything runs on the GitHub-hosted `windows`
and `ubuntu` images.

- **`ci.yml`** runs on every push and PR. It boots Flutter stable,
  bootstraps the melos workspace, runs `dart format --set-exit-if-changed`,
  `dart analyze`, every package's tests, and uploads a `web` build as an
  artifact so reviewers can click through the UI without a checkout.
- **`release.yml`** runs on a `v*.*.*` tag push. It builds the web
  bundle, a per-ABI split APK, and an AAB; signs both Android artifacts
  with the production keystore; bundles a checksums file; and creates a
  GitHub Release with all of it attached.

### Signing

A release keystore is generated once and never committed. Generate
yours with [`scripts/gen-keystore.ps1`](scripts/gen-keystore.ps1), which
prints the base64-encoded keystore to stdout. The four secrets the
release workflow consumes are:

| Secret | Description |
| ------ | ----------- |
| `KEYSTORE_BASE64` | Base64 of `release.jks` (entire file). |
| `KEYSTORE_PASSWORD` | Keystore store password. |
| `KEY_ALIAS` | Key alias inside the keystore (default `fluff-release`). |
| `KEY_PASSWORD` | Per-key password (commonly = `KEYSTORE_PASSWORD`). |

Upload them via `gh secret set <name>` or the repo Settings UI. The
workflow drops the decoded keystore into a temp file at runtime and
references it from `app/android/key.properties`.

The production release-signing fingerprint is:

```
SHA-256: B4:58:64:4E:4C:E6:64:5F:EC:12:DA:13:79:9D:14:49:69:29:20:51:64:26:F9:63:71:C7:C1:D2:A5:76:80:1A
```

### Cutting a release

```powershell
git tag v0.1.0
git push origin v0.1.0
```

That triggers `release.yml`. When it finishes, the signed APK + AAB +
web bundle + checksums show up on the
[Releases page](https://github.com/iyashwantsaini/fluff/releases).

---

## Tech stack

| Layer | Technology |
| ----- | ---------- |
| Language | Dart 3.11+, Flutter stable channel |
| Monorepo | [melos](https://melos.invertase.dev) |
| UI / design system | [wloom](https://github.com/iyashwantsaini/wloom) (`wolwoloom`) |
| Storage abstraction | `FsProvider` (in `fluff_vfs`) |
| Crypto | `cryptography` (XChaCha20-Poly1305 + Argon2id) |
| Archives | `archive` (zip/tar/gz, APK inspection); `libarchive` via FFI in Phase 5.1 |
| Markdown / SVG / images | `flutter_markdown`, `flutter_svg`, built-in `Image.memory` |
| Long-running ops | `flutter_foreground_task` (Phase 2.1) |
| Networking | `dartssh2`, `smb_connect`, `shelf` (planned in 4.1 / 6.1) |
| Testing | `test`, `glados` (property tests for `fluff_vault`) |
| Native shims | published as separate pub.dev plugins under `packages/fluff_native_shims/` (no inline Kotlin in `app/`) |
| Telemetry | **none.** Not opt-in. Not opt-out. Not for crashes. |

---

## Screenshots

Every phase produces a fresh set of screenshots captured at the
**actual** VS Code Simple Browser viewport (no hard-coded sizes).
Browse them in [docs/screenshots/](docs/screenshots/) — the index
there groups them by phase, by route, and by light / dark theme, and
links back to the iteration review in [docs/DESIGN.md](docs/DESIGN.md).

The loop that produces them is codified in
[`.github/instructions/build-tier.skill.md`](.github/instructions/build-tier.skill.md);
run it any time via the `/build-tier` prompt.

---

## Building

```powershell
# Prereqs: Flutter stable, Android SDK + NDK, melos, PowerShell 7+.
git clone https://github.com/iyashwantsaini/fluff.git
cd fluff
dart pub global activate melos
melos bootstrap

# Run the web slice (used for design iteration + this repo's screenshots).
cd app
flutter run -d chrome --web-port=8765

# Or run on a connected Android device.
flutter run
```

Tests:

```powershell
melos run test          # unit tests across all packages
melos run integration   # device / emulator integration tests (Phase 2.1+)
```

Generate the app icon (deterministic, pure PowerShell + GDI+):

```powershell
pwsh scripts/gen-icon.ps1
```

Generate a release keystore once (interactive prompts for passwords):

```powershell
pwsh scripts/gen-keystore.ps1
```

---

## Contributing

Fluff is open from day one. The [PLAN.md](PLAN.md) and the issue tracker
are the contract.

- Read [CONTRIBUTING.md](CONTRIBUTING.md) first.
- Look for issues labelled `good first issue` or `help wanted`.
- Before starting a non-trivial change, open an issue describing the
  approach so we don’t duplicate work.
- Match the architectural decisions in [PLAN.md §4](PLAN.md#4-architecture)
  — most importantly, **never reach for `dart:io` paths directly from UI
  code; everything goes through `FsProvider`**.
- One package per PR where possible; tests required for `fluff_vfs`,
  `fluff_vault`, `fluff_ffi`, `fluff_sync`.

### Translations

Strings live in `app/lib/l10n/`. We accept PRs against any ARB file. A
Crowdin / Weblate project will go up once the UI stabilises.

### Skins

A skin is a zip of `theme.json + fonts/ + icons/`. See
[PLAN.md §7](PLAN.md#7-theming--skin-packs) for the schema. Drop a
`*.fluff-skin` file onto Fluff to install it.

---

## License

Apache-2.0. See [LICENSE](LICENSE).

The vault format and the nearby-transfer wire protocol are specified in
PLAN.md and intended to remain open and interoperable across forks /
re-implementations.

---

## Acknowledgements

- [wloom](https://github.com/iyashwantsaini/wloom) — the design system
  that makes Fluff look the way it does.
- The Flutter, Dart and pub.dev communities — every plugin Fluff
  depends on is listed in
  [PLAN.md §4.4](PLAN.md#44-third-party-dependencies).
