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
