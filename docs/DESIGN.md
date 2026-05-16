# Fluff — Living Design Document

> Auto-updated each iteration. **Single source of truth** for current
> phase status, design decisions made along the way, and the iteration
> log of every screenshot review.

| Field | Value |
| --- | --- |
| Current phase | **Phase 2 — operations + multi-select** (web slice shipped; Android slice deferred to Phase 2.1) |
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
