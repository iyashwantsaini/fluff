# Fluff

A modern, open-source file manager for Android — built entirely in
[Flutter](https://flutter.dev) with the [wloom](https://github.com/iyashwantsaini/wloom)
design system.

> **Status:** pre-alpha. Designing in the open. Code lands in small,
> reviewable PRs against the plan in [PLAN.md](PLAN.md).

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
| 2 | `fluff_vault` (encrypted streaming AEAD) | ⬜ |
| 3 | `fluff_remote` (SMB + SFTP) + foreground operations | ⬜ |
| 4 | `fluff_ffi` + `libarchive` (7z / RAR-read / zstd) | ⬜ |
| 5 | `fluff_documents_provider` shim plugin | ⬜ |
| 6 | Servers + Quick Settings tiles + homescreen widgets | ⬜ |
| 7 | Sync, nearby transfer, share links | ⬜ |
| 8 | OCR + semantic search + AI organise | ⬜ |
| 9 | Public 1.0 (F-Droid + GitHub Releases) | ⬜ |

Detailed PR-by-PR plan: [PLAN.md §5](PLAN.md#5-phased-roadmap).

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

> Coming with Phase 1. The bullets below describe the **intended**
> developer experience.

```powershell
# Prereqs: Flutter stable, Android SDK + NDK, melos.
git clone https://github.com/<you>/fluff.git
cd fluff
dart pub global activate melos
melos bootstrap
cd app
flutter run
```

Tests:

```powershell
melos run test          # unit tests across all packages
melos run integration   # device / emulator integration tests
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
