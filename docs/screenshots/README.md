# Screenshots

Each subfolder corresponds to a phase from
[PLAN.md §5](../../PLAN.md#5-phased-roadmap). Filenames embed the
**actual** VS Code Simple Browser viewport that the screenshot was
rendered at — `<route>-<theme>@<W>x<H>.png`. Width / height are
**detected at capture time** via `window.innerWidth` /
`window.innerHeight`, then pinned into the headless browser with
`page.setViewportSize` so the rendered pixels match the canvas the
user actually sees. No hard-coded sizes — when the Simple Browser is
resized, the next pass captures at the new size.

The capture loop and the self-review checklist are codified in
[`.github/instructions/build-tier.skill.md`](../../.github/instructions/build-tier.skill.md).

---

## Phase 1 — workspace + skeleton browser

**Viewport captured at:** `1233 × 1257` (the Simple Browser
dimensions detected on `2026-05-16`).

**Routes captured:** `/` (root of `MemFsProvider.demo()`),
`/Documents` (nested folder with three sample files).

### Light

| Route | Screenshot |
| ----- | ---------- |
| `/` | ![Root, light](phase-1/browse-root-light@1233x1257.png) |
| `/Documents` | ![Documents, light](phase-1/browse-documents-light@1233x1257.png) |

### Dark

| Route | Screenshot |
| ----- | ---------- |
| `/` | ![Root, dark](phase-1/browse-root-dark@1233x1257.png) |
| `/Documents` | ![Documents, dark](phase-1/browse-documents-dark@1233x1257.png) |

### Review notes for this pass

See [`../DESIGN.md`](../DESIGN.md) → **Iteration log** →
`2026-05-16 — Phase 1`.

---

## Phase 2 — operations, multi-select, dialogs

**Viewport captured at:** `1233 × 1257` (Simple Browser dimensions
detected on `2026-05-16`).

**Routes / states captured** (driven by the `?cwd=…`, `?sel=…`,
`?search=…`, `?props=…`, `?conflict=…`, `?clip=…`, `?fakeOp=…`,
`?dark=…` demo URL handler in `BrowseScreen._applyDemoUrl`):

### Light

| State | Screenshot |
| ----- | ---------- |
| Root (clipboard banner + paste FAB after copy) | ![Clipboard paste, light](phase-2/clipboard-paste-light@1233x1257.png) |
| Three folders multi-selected (action bar: copy / cut / delete / properties) | ![Selection, light](phase-2/selection-multi-light@1233x1257.png) |
| Properties dialog for `/Documents/notes.txt` | ![Properties, light](phase-2/properties-dialog-light@1233x1257.png) |
| Conflict dialog (Skip / Keep both / Replace) | ![Conflict, light](phase-2/conflict-dialog-light@1233x1257.png) |
| Inline search active in `/Documents` (`note`) | ![Search, light](phase-2/search-active-light@1233x1257.png) |
| Progress sheet mid-copy (2 / 3 items, 69 %) | ![Progress, light](phase-2/progress-sheet-light@1233x1257.png) |
| Root (default landing) | ![Root, light](phase-2/browse-root-light@1233x1257.png) |
| `/Documents` listing | ![Documents, light](phase-2/browse-documents-light@1233x1257.png) |

### Dark

| State | Screenshot |
| ----- | ---------- |
| Root | ![Root, dark](phase-2/browse-root-dark@1233x1257.png) |
| Multi-select action bar | ![Selection, dark](phase-2/selection-multi-dark@1233x1257.png) |
| Properties dialog | ![Properties, dark](phase-2/properties-dialog-dark@1233x1257.png) |
| Progress sheet mid-copy | ![Progress, dark](phase-2/progress-sheet-dark@1233x1257.png) |

### Review notes for this pass

See [`../DESIGN.md`](../DESIGN.md) → **Iteration log** →
`2026-05-16 — Phase 2`.
