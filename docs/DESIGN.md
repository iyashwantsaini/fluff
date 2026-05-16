# Fluff — Living Design Document

> Auto-updated each iteration. **Single source of truth** for current
> phase status, design decisions made along the way, and the iteration
> log of every screenshot review.

| Field | Value |
| --- | --- |
| Current phase | **Phase 6 web slice** — servers list (HTTP / WebDAV / FTP / SFTP / DLNA) over a mock `ShareServerController`. Real sockets, Quick Settings tiles, home-screen widgets, and boot auto-start deferred to Phase 6.1. |
| Last updated | 2026-05-16 |
| Flutter SDK target | stable (verified per iteration) |
| wloom version | `wolwoloom: ^0.3.5` (pin; vendor if upstream breaks) |
| Default browser viewport for screenshots | **detected at runtime** — never hard-coded |

---

## 1. Spacing tokens (canonical)

Every screen reads these from `WlmTokens` via `fluff_skin`. They are
multiples of 4 so vertical rhythm composes cleanly.

| Token | Value (logical px) | Used for |
| --- | --- | --- |
| `spacing.xs` | 4 | Icon ↔ label, chip padding |
| `spacing.sm` | 8 | List-row inner gap, button padding-y |
| `spacing.md` | 12 | List-row vertical, dialog row gap |
| `spacing.lg` | 16 | Page edge gutter (≤ 600 px viewports) |
| `spacing.xl` | 24 | Page edge gutter (> 600 px viewports), section gap |
| `spacing.xxl` | 32 | Hero spacing, top-of-page padding |

**Page edges:** the outermost padding of any route is `spacing.lg` on
phone widths and `spacing.xl` on tablet+. Anything visually less than
that is a bug — there should never be content visually touching the
viewport edge.

## 2. Radii

| Token | Value | Used for |
| --- | --- | --- |
| `radius.sm` | 6 | Chips, small buttons |
| `radius.md` | 12 | Cards, list-row hover |
| `radius.lg` | 16 | Dialogs, sheets |
| `radius.xl` | 20 | Vault unlock card |

## 3. Typography

Defaults come from wloom (`JetBrainsMono` everywhere). Overrides
planned for non-Latin scripts — see
[PLAN.md §8 risks](../PLAN.md#risks-worth-tracking).

| Role | Size / weight |
| --- | --- |
| `display` | 28 / 500 |
| `title` | 20 / 500 |
| `body` | 14 / 400 |
| `label` | 12 / 500, +0.4 letter-spacing |
| `mono` | 13 / 400, tabular |

## 4. Architectural decisions made during build

> Each entry is a one-line note when a build decision diverges from
> PLAN.md or fleshes out something PLAN.md left open. Bigger changes
> need an RFC.

| Date | Decision | Why |
| --- | --- | --- |
| 2026-05-16 | Default route is `BrowseScreen` over `LocalFsProvider` rooted at the platform home directory (`Directory.systemTemp.parent` on web stub). | Phase 1 doesn't have SAF yet; web build needs a path that exists. |
| 2026-05-16 | `OperationQueue` lives on the main isolate for the web slice; deferred the `flutter_foreground_task` wrap + journalled resume to **Phase 2.1** (Android-only). | The PLAN.md "10 GB / kill / resume" acceptance gate is Android-specific. Web demo can't go to disk anyway. |
| 2026-05-16 | Recursive directory copy in `OperationQueue._copyAll` is one level deep for the web slice (single `provider.list`). Multi-level recursion ships with Phase 2.1. | Avoid building a partial recursive walker now and replace it later with one that runs inside the foreground task. |
| 2026-05-16 | Added a `?cwd=…&sel=…&search=…&props=…&conflict=…&clip=…&fakeOp=…&dark=…` demo-URL handler in `BrowseScreen._applyDemoUrl` (web-only via `kIsWeb`). | Flutter web's CanvasKit renderer doesn't surface long-press through Playwright mouse events, so screenshot routes need a deterministic state seed. |

## 5. Iteration log

Each pass of the **build-tier** skill appends an entry here with:

- date,
- batch / phase,
- viewport detected from the Simple Browser,
- screenshots taken,
- review findings,
- fixes applied.

### 2026-05-16 — Phase 1, first pass

- **Scope**: workspace bootstrap; `fluff_vfs` (`FsPath`, `FsNode`,
  `FsCapabilities`, `FsProvider`, `MemFsProvider.demo`);
  `fluff_skin` (`WlmTokens`, `WlmTheme`, `SkinController`,
  `SkinScope`); `app/` with a single `BrowseScreen` that lists the
  demo tree and supports breadcrumb navigation + light/dark toggle.
- **Routes**: `/` (root), `/Documents` (sample nested folder).
- **Viewport**: detected `1233×1257` in the user's VS Code Simple
  Browser via `window.innerWidth` / `window.innerHeight`. That value
  is then pinned into the headless screenshot driver with
  `page.setViewportSize(...)` **before** capture, so the saved PNGs
  are exactly `1233×1257` pixels with no asymmetric right-edge
  whitespace from a default-viewport mismatch. Resize the Simple
  Browser → the next pass captures at the new size automatically.
- **Screenshots**:
  - `docs/screenshots/phase-1/browse-root-light@1233x1257.png`
  - `docs/screenshots/phase-1/browse-root-dark@1233x1257.png`
  - `docs/screenshots/phase-1/browse-documents-light@1233x1257.png`
  - `docs/screenshots/phase-1/browse-documents-dark@1233x1257.png`
- **Findings (per checklist)**:
  - ✅ No content touches any viewport edge — gutter looks correct
    on left (`16 px`), right (`16 px`), and top (AppBar bottom border
    at the spec position).
  - ✅ No clipping — file / folder names render in full, no overflow
    chevrons appear unexpectedly.
  - ✅ Vertical rhythm — list rows are uniform height; the `8 px`
    inter-row gap reads cleanly.
  - ✅ Hit-targets — list rows are ~56 px tall, well above the
    40 px minimum.
  - ✅ Hairline border on cards is visible in both light and dark.
  - ✅ Contrast — body text against the card background reads well
    in both modes (eyeballed; needs a Lighthouse run in Phase 2).
  - ✅ wloom mapping — Phase 1 wraps the Material 3 theme with the
    wloom tokens. Swap to `wolwoloom` planned for Phase 2 once we
    verify the package version compatibility.
- **Fixes applied during this pass**:
  - Cleaned one `unnecessary_underscores` lint flagged by
    `flutter analyze`.
- **Known limitations to address next iteration**:
  - LocalFsProvider isn't shipped yet; web demo uses `MemFsProvider`.
    Android build will need `LocalFsProvider` (via SAF) plus a
    matching `flutter test`.
  - No multi-tab AppBar — landing for Phase 3 per PLAN.md §5.

- **Fix re-applied on re-review (same date)**:
  - User flagged residual right-edge whitespace and a missing
    screenshots index. Root cause: the screenshot driver was using
    its default `1280×720` headless viewport instead of the detected
    Simple Browser viewport, so the saved PNG was wider than the
    rendered Flutter canvas. Fixed by reading
    `window.innerWidth/innerHeight` and calling
    `page.setViewportSize(...)` before every screenshot. Re-captured
    all four PNGs at true `1233×1257`. Added
    [`docs/screenshots/README.md`](screenshots/README.md) as the
    structured index and linked it from the top-level README.

### 2026-05-16 — Phase 2, first pass

- **Scope**: new `packages/fluff_ops/` (pure Dart, no Flutter dep)
  with `OperationKind`, `Operation`, `OperationStatus`,
  `OperationProgress`, `ConflictPolicy`, `Conflict`, and
  `OperationQueue` (sequential runner, broadcast progress + conflict
  streams, auto-rename-on-conflict default). App-side: multi-select
  (long-press → tap-toggle), in-app cut / copy clipboard with a
  paste FAB, recursive delete, inline search (filters current
  listing by substring), a `PropertiesDialog`, a `ConflictDialog`
  (Skip / Keep both / Replace), and a bottom `ProgressSheet` driven
  by `OperationQueue` streams.
- **Routes / states**: root, `/Documents`, multi-select, properties,
  conflict, search, progress sheet, clipboard banner — both light
  and dark for the high-value ones.
- **Viewport**: detected `1233×1257`, pinned with
  `page.setViewportSize` before every capture (no hard-coded sizes).
- **Screenshots**:
  - `docs/screenshots/phase-2/browse-root-light@1233x1257.png`
  - `docs/screenshots/phase-2/browse-root-dark@1233x1257.png`
  - `docs/screenshots/phase-2/browse-documents-light@1233x1257.png`
  - `docs/screenshots/phase-2/selection-multi-light@1233x1257.png`
  - `docs/screenshots/phase-2/selection-multi-dark@1233x1257.png`
  - `docs/screenshots/phase-2/properties-dialog-light@1233x1257.png`
  - `docs/screenshots/phase-2/properties-dialog-dark@1233x1257.png`
  - `docs/screenshots/phase-2/conflict-dialog-light@1233x1257.png`
  - `docs/screenshots/phase-2/search-active-light@1233x1257.png`
  - `docs/screenshots/phase-2/progress-sheet-light@1233x1257.png`
  - `docs/screenshots/phase-2/progress-sheet-dark@1233x1257.png`
  - `docs/screenshots/phase-2/clipboard-paste-light@1233x1257.png`
- **Findings (per checklist)**:
  - ✅ No content touches any viewport edge in any state. Selection
    rows, dialogs, and the progress sheet all respect the
    `spacing.lg` / `spacing.xl` page gutter.
  - ✅ Action bar icons (copy / cut / delete / properties) have a
    consistent 48 × 48 hit area and align with the AppBar baseline.
  - ✅ Selected-row treatment reads cleanly in both modes — primary
    border at 1.5 px plus a 35 %-alpha primary-container fill, with
    an explicit check chip on the leading edge.
  - ✅ Properties dialog: fixed 110-px label gutter, monospaced
    path, light divider, close button right-aligned. No clipping
    even on the long `/Documents/notes.txt` path.
  - ✅ Conflict dialog: source + target labelled and aligned, the
    primary action ("Replace") is filled, escape actions
    ("Skip" / "Keep both") are text buttons. No ambiguous defaults.
  - ✅ Progress sheet: lives in the Scaffold body (above the bottom
    safe area), 4-px linear indicator, shows percentage on the
    right, current item path truncated with ellipsis.
- **Deferred to Phase 2.1 (Android)**:
  - `flutter_foreground_task` hosting of `OperationQueue` (so
    operations survive activity destruction).
  - On-disk journal so a relaunch after kill resumes pending ops.
  - SEND / VIEW intent receivers (`receive_sharing_intent` +
    `app_links`).
  - Recursive directory copy (vs the current shallow web copy).
  - PLAN.md "10 GB / kill / resume" acceptance gate runs against
    `LocalFsProvider` once SAF lands.
- **Tests**: 6 / 6 green in `dart test packages/fluff_ops` —
  copy, move, delete, auto-rename on conflict, progress emission,
  failure surfacing.

### 2026-05-16 — Phase 3, first pass

- **Scope**: new `packages/fluff_vault/` (pure Dart, no Flutter dep)
  implementing PLAN.md §6.4 + §6.5 — `VaultHeader` (magic +
  Argon2id KDF params + AEAD wrapped master key + encrypted tree),
  `VaultKeys` with `HKDF-SHA256` per-file subkeys, chunked
  `XChaCha20-Poly1305` streaming AEAD at 64 KiB per chunk with a
  little-endian counter nonce, `Vault.create / unlock /
  reencryptHeader`, and `VaultFsProvider` which mounts on any
  backing `FsProvider` so files at rest are only ciphertext blobs.
  App-side: new top-level Mount switcher (`Storage` | `Vault`) in
  `main.dart` driven by a shared `Drawer`, new `VaultScreen` with
  `locked` / `create` / `unlocked` phases, `BrowseScreen` now
  accepts optional `leadingDrawer` + `appBarSuffix` so the vault
  view can host its own drawer and lock button, and a `?vault=`
  URL handler that boots a demo unlocked vault (password `demo`,
  two folders, three files including a 900 KiB PDF) so the encrypted
  state can be screenshotted end-to-end.
- **Routes / states**: storage root + `/Documents`, multi-select,
  properties, conflict, search, progress sheet, clipboard banner,
  vault locked, vault create, vault unlocked — light **and** dark
  for every state.
- **Viewport**: detected `1233×1257`, pinned with
  `page.setViewportSize` before every capture (no hard-coded sizes).
- **Screenshots** — all in `docs/screenshots/latest/`, overwritten
  each pass, no per-phase subfolder, no resolution suffix, light +
  dark side by side in [the README table](screenshots/README.md):
  `browse-root`, `browse-documents`, `selection-multi`,
  `properties-dialog`, `conflict-dialog`, `search-active`,
  `progress-sheet`, `clipboard-paste`, `vault-locked`,
  `vault-create`, `vault-unlocked` — each `{light,dark}.png`.
- **Findings (per checklist)**:
  - ✅ Vault locked + create screens center a 420-px max-width
    column; the shield / lock glyph + heading + body + inputs +
    primary button all share the `spacing.lg` vertical rhythm.
    No content touches the viewport edges; in dark the elevated
    surface contrasts cleanly with the body background.
  - ✅ Vault unlocked screen reuses `BrowseScreen` so list rows,
    breadcrumb, and AppBar treatment are identical to storage —
    only the AppBar title (`Vault`) and the extra lock-icon suffix
    distinguish them. The hamburger reveals the same Mount drawer.
  - ✅ Re-captured darks for `clipboard-paste`, `conflict-dialog`,
    and `search-active` that Phase 2 had skipped, so the table is
    now complete.
  - ✅ Lock icon is `lock_outline_rounded` in both themes; spacing
    against the brightness toggle matches the `spacing.sm` AppBar
    action gap used elsewhere.
- **Deferred to Phase 3.1**:
  - Biometric unlock (`local_auth`) + recent-unlock cache.
  - `FLAG_SECURE` on the vault route so screenshots are blocked at
    the OS level on Android.
  - "Move to vault" quick action on storage list rows, including
    the secure-wipe of the source file via `LocalFsProvider`.
  - CBOR tree encoding (currently JSON for the web slice).
  - Property tests via `glados` over libsodium reference vectors,
    plus a benchmark number in the PR description per the
    `fluff_vault` hard rule.
  - Change-password flow (KEK rewrap without re-encrypting blobs).
- **Tests**: 9 / 9 green in `dart test packages/fluff_vault` —
  header round-trip, header rejects wrong magic, AEAD on a small
  payload, AEAD across 4 × 64 KiB chunks, single-byte tamper is
  rejected with `SecretBoxAuthenticationError`, vault create →
  reencrypt → unlock preserves the master key, wrong password is
  rejected, and `VaultFsProvider` write/list/read round-trip on a
  `MemFsProvider` backing where the resulting blob contains no
  plaintext substring.

### 2026-05-16 — Phases 4 + 5, first pass (web slices)

- **Scope**: two new packages and a shell refactor so the top-level
  shell can host an arbitrary set of mounts.
  - `packages/fluff_remote/` — pure-Dart `RemoteAccount`
    (`RemoteKind.smb` | `RemoteKind.sftp`, host, port, share,
    username, validation), in-memory `RemoteAccountStore` with a
    broadcast `changes` stream, and `MockRemoteFsProvider` that
    wraps a seeded `MemFsProvider` so each account kind exposes a
    distinct tree (`/Shared`, `/Public` for SMB; `/home`, `/var`
    for SFTP). The real `SmbFsProvider` (`smb_connect`) and
    `SftpFsProvider` (`dartssh2`) land in Phase 4.1 on Android.
  - `packages/fluff_archive/` — `ArchiveFsProvider.fromBytes`
    decodes a zip / tar / tar.gz blob using the `archive` package
    and exposes the contents through the standard `FsProvider`
    seam. Capabilities are `FsCapabilities.readOnly`; write /
    delete / rename / mkdir throw `UnsupportedError`. Phase 5.1
    adds write support, plus 7z / RAR / zstd via `libarchive` FFI.
  - App shell: `main.dart` grew an `_Mount` enum
    (`storage | vault | remote | archive`) with a single shared
    `Drawer` source of truth that lights up the current row. The
    vault screen now accepts that `Drawer` from the parent instead
    of building its own. New `AccountsScreen` lists stored
    accounts in a card layout, exposes an empty state with a CTA,
    a `SegmentedButton`-based "Add account" dialog (SFTP / SMB
    with auto port hint), and a per-row delete button. URL
    handlers added: `?accounts=1`, `?remote=<id>`, `?archive=1`.
- **Routes / states added** (light + dark each):
  `accounts-list`, `remote-sftp`, `remote-smb`,
  `archive-root`, `archive-src`.
- **Viewport**: detected `1233×1257`, pinned with
  `page.setViewportSize` before every capture.
- **Findings (per checklist)**:
  - ✅ Account cards use a 1-px `outlineVariant` border and a
    primary-container CircleAvatar, rhythm matches the storage
    list rows. Subtitle stays on one line for both kinds; long
    `user@host:port/share` strings ellipsize gracefully.
  - ✅ AppBar of the active remote mount swaps the brightness
    button for a `logout_rounded` action that snaps back to the
    Accounts list without leaking the mock provider.
  - ✅ Archive viewer reuses `BrowseScreen` so breadcrumb, row
    treatment, size formatting, and modified-date column are
    identical to Storage. `fluff-demo.zip` shows directory-first
    sort, with the `assets` / `src` synthesised parent dirs ahead
    of `CHANGELOG.md` and `README.txt`.
  - ✅ Hamburger lives on every mount; selected row is
    primary-tinted. Drawer dismisses on tap before `setState`
    fires.
  - ✅ No content touches viewport edges in any new state; FAB on
    the Accounts screen respects the safe-area inset.
- **Deferred to Phase 4.1 (Android)**:
  - Real `SmbFsProvider` via `smb_connect`.
  - Real `SftpFsProvider` via `dartssh2` (key-based + password).
  - Keystore-backed JSON persistence for `RemoteAccountStore`
    (currently in-memory).
  - Drag-and-drop between a local tab and a remote tab.
- **Deferred to Phase 5.1**:
  - Write support inside `ArchiveFsProvider` (entries currently
    throw `UnsupportedError`).
  - `libarchive` FFI in `fluff_ffi` for 7z, RAR-read, zstd.
  - Cross-compiled `.so`s in CI for `arm64-v8a` + `x86_64`.
  - `DocumentsProvider` shim plugin exposing local + SMB through
    the system file picker.
- **Tests**:
  - `dart test packages/fluff_remote` — 9 / 9 green
    (account validation: SFTP defaults to 22, SMB requires a
    share, invalid port rejected, summary embeds user + share;
    store: upsert/remove emit events, list sorts case-insensitively;
    provider: SMB and SFTP seeds expose the expected roots, and a
    writeBytes/readBytes round-trip survives through the seam).
  - `dart test packages/fluff_archive` — 7 / 7 green
    (format sniffing, read-only capabilities, root + nested
    listing, byte round-trip, all mutation methods throw, missing
    paths return `null` from `stat`).

### 2026-05-16 — Phase 6, first pass (web slice)

- **Scope**: `packages/fluff_share/` (pure Dart) ships a
  `ShareServerKind` enum (`http`, `webdav`, `ftp`, `sftp`, `dlna`)
  with per-kind default ports, an immutable `ShareServer` model
  (id / kind / label / port / requiresAuth / username /
  isRunning / bytesServed with `copyWith` + value equality), and a
  `ShareServerController` that holds the list, emits a broadcast
  `changes` snapshot per mutation, and exposes
  `start` / `stop` / `toggle` / `tick(bytes:)` so the UI can demo
  traffic without a real socket. `defaultSeedServers()` produces
  one entry per kind with stable ids.
- **App changes**: `_Mount` gained a fifth value `servers`;
  Drawer gained an `Icons.dns_outlined` "Servers" row.
  `ServersScreen` (web-slice equivalent of `AccountsScreen`)
  lists `ShareServer`s with a kind-specific icon, a primary-
  tinted CircleAvatar when running, a status pill, the loopback
  URL in monospace, a bytes-served counter, a `Switch` wired to
  `controller.toggle`, and a delete button. `_AddServerDialog`
  uses a 5-segment `SegmentedButton`; the port field hints the
  selected kind's default. URL handlers added:
  `?servers=1` and `?server=<id>` (the latter starts that server
  and pumps two 48 KiB ticks so the running tile looks live).
- **Routes / states added** (light + dark each): `servers-list`,
  `server-http-running`, `server-webdav-running`.
- **Viewport**: detected `1233×1257`, pinned with
  `page.setViewportSize` before every capture.
- **Findings**:
  - ✅ Tile layout absorbs the longer "WebDAV share" / "DLNA share"
    labels without wrapping; status pill and switch stay aligned.
  - ✅ The "running" colour treatment (primary avatar + primary
    pill + filled switch) reads as one logical group; stopped
    rows recede into `surfaceContainerHighest`.
  - ✅ Loopback URLs use monospace so the port digits don't kern
    away from the host.
  - ✅ Drawer "Servers" row lights up when active; switching back
    to Storage from Servers does not leak the controller stream.
- **Deferred to Phase 6.1 (Android)**:
  - Real HTTP / WebDAV servers over `shelf`.
  - FTP and SFTP servers over `dart:io` sockets.
  - DLNA: raw SSDP via `RawDatagramSocket` + `shelf` for HTTP.
  - `flutter_foreground_task` integration so a running server
    survives screen-off; status pill colour stays in sync.
  - `fluff_quick_tile` shim for one-tap Quick Settings toggles.
  - `home_widget` integration for a server-toggle widget.
  - `android_alarm_manager_plus` opt-in boot auto-start.
  - One-time encrypted share links + QR (overlaps with Phase 7).
- **Tests**: `dart test packages/fluff_share` — 9 / 9 green
  (default port, validation rejects empty label / out-of-range
  port / auth-without-username, `loopbackUrl` carries port for
  every kind, controller emits an event per mutation, list sorts
  by kind index then label, `start` / `stop` / `toggle` flip the
  flag and reset bytes on stop, `tick` only mutates running
  servers, `defaultSeedServers()` covers every kind exactly once).

---

## Appendices

### A. Glossary

See [PLAN.md Appendix A](../PLAN.md#a-glossary).

### B. Where things live

| Thing | Path |
| --- | --- |
| Public-facing intro | [README.md](../README.md) |
| Build contract / roadmap | [PLAN.md](../PLAN.md) |
| Contribution rules | [CONTRIBUTING.md](../CONTRIBUTING.md) |
| Workspace-wide Copilot rules | [.github/copilot-instructions.md](../.github/copilot-instructions.md) |
| Build-tier loop | [.github/instructions/build-tier.skill.md](../.github/instructions/build-tier.skill.md) |
| Dart / Flutter style | [.github/instructions/dart.instructions.md](../.github/instructions/dart.instructions.md) |
| Reusable `/build-tier` prompt | [.github/prompts/build-tier.prompt.md](../.github/prompts/build-tier.prompt.md) |
| Screenshots | [docs/screenshots/](screenshots) |
| RFCs | [docs/rfcs/](rfcs) |
