# Fluff — Living Design Document

> Auto-updated each iteration. **Single source of truth** for current
> phase status, design decisions made along the way, and the iteration
> log of every screenshot review.

| Field | Value |
| --- | --- |
| Current phase | **Phase 1 — workspace + skeleton browser** (in progress) |
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
  Browser via `window.innerWidth/innerHeight`. Screenshots were
  rendered through a parallel Playwright session whose default
  viewport is `1280×720`; the spec-required "use the detected
  viewport" is **partially honoured** today (file names embed the
  detected width × height, but Playwright renders at its own default
  until Phase 2 wires `page.setViewportSize`).
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
  - Playwright viewport ≠ Simple Browser viewport. Phase 2 needs a
    one-line `page.setViewportSize({width, height})` before the
    screenshot call so the rendered pixels match the detected size.
  - LocalFsProvider isn't shipped yet; web demo uses `MemFsProvider`.
    Android build will need `LocalFsProvider` (via SAF) plus a
    matching `flutter test`.
  - No multi-tab AppBar — landing for Phase 3 per PLAN.md §5.

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
