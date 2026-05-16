# Screenshots

This folder always holds the **latest** capture of every reachable
state in the app. There are no per-phase subfolders — every new
build overwrites the relevant PNGs in [`latest/`](latest/) so the
docs always show the current UI, not a historical one.

The capture loop and the self-review checklist are codified in
[`.github/instructions/build-tier.skill.md`](../../.github/instructions/build-tier.skill.md).

**Conventions**

- One PNG per state, two themes: `<state>-light.png` and
  `<state>-dark.png` in [`latest/`](latest/).
- Sizes are **detected at capture time** from the VS Code Simple
  Browser viewport (`window.innerWidth` / `window.innerHeight`),
  then pinned with `page.setViewportSize` before the screenshot.
  No hard-coded sizes.
- The table below has **light and dark side by side, one row per
  state**, so reviewers can spot drift at a glance.

> Per-state findings for the current pass live in
> [`../DESIGN.md`](../DESIGN.md) → **Iteration log**.

---

## Latest

| State | Light | Dark |
| ----- | ----- | ---- |
| Browse — root listing | ![Root, light](latest/browse-root-light.png) | ![Root, dark](latest/browse-root-dark.png) |
| Browse — `/Documents` listing | ![Documents, light](latest/browse-documents-light.png) | ![Documents, dark](latest/browse-documents-dark.png) |
| Multi-select action bar (3 folders selected) | ![Selection, light](latest/selection-multi-light.png) | ![Selection, dark](latest/selection-multi-dark.png) |
| Properties dialog (`/Documents/notes.txt`) | ![Properties, light](latest/properties-dialog-light.png) | ![Properties, dark](latest/properties-dialog-dark.png) |
| Conflict dialog (Skip / Keep both / Replace) | ![Conflict, light](latest/conflict-dialog-light.png) | ![Conflict, dark](latest/conflict-dialog-dark.png) |
| Inline search (`note` in `/Documents`) | ![Search, light](latest/search-active-light.png) | ![Search, dark](latest/search-active-dark.png) |
| Progress sheet mid-copy (2 / 3 items, 69 %) | ![Progress, light](latest/progress-sheet-light.png) | ![Progress, dark](latest/progress-sheet-dark.png) |
| Clipboard banner + paste FAB | ![Clipboard, light](latest/clipboard-paste-light.png) | ![Clipboard, dark](latest/clipboard-paste-dark.png) |
| Vault — locked landing | ![Vault locked, light](latest/vault-locked-light.png) | ![Vault locked, dark](latest/vault-locked-dark.png) |
| Vault — create new | ![Vault create, light](latest/vault-create-light.png) | ![Vault create, dark](latest/vault-create-dark.png) |
| Vault — unlocked listing | ![Vault unlocked, light](latest/vault-unlocked-light.png) | ![Vault unlocked, dark](latest/vault-unlocked-dark.png) |

Rows for not-yet-shipped states will render as broken images until
the matching phase lands — that's deliberate, it's the to-do list.
