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
| Remote accounts — list | ![Accounts, light](latest/accounts-list-light.png) | ![Accounts, dark](latest/accounts-list-dark.png) |
| Remote — SFTP mock (`VPS deploy`) | ![SFTP, light](latest/remote-sftp-light.png) | ![SFTP, dark](latest/remote-sftp-dark.png) |
| Remote — SMB mock (`Home NAS`) | ![SMB, light](latest/remote-smb-light.png) | ![SMB, dark](latest/remote-smb-dark.png) |
| Archive viewer — `fluff-demo.zip` root | ![Archive root, light](latest/archive-root-light.png) | ![Archive root, dark](latest/archive-root-dark.png) |
| Archive viewer — `/src` inside zip | ![Archive src, light](latest/archive-src-light.png) | ![Archive src, dark](latest/archive-src-dark.png) |
| Servers — list (all stopped) | ![Servers, light](latest/servers-list-light.png) | ![Servers, dark](latest/servers-list-dark.png) |
| Servers — HTTP running with traffic | ![HTTP running, light](latest/server-http-running-light.png) | ![HTTP running, dark](latest/server-http-running-dark.png) |
| Servers — WebDAV running with traffic | ![WebDAV running, light](latest/server-webdav-running-light.png) | ![WebDAV running, dark](latest/server-webdav-running-dark.png) |
| Sync — pre-execution plan diff | ![Sync, light](latest/sync-plan-light.png) | ![Sync, dark](latest/sync-plan-dark.png) |
| Nearby devices — list (Pixel paired) | ![Nearby, light](latest/nearby-list-light.png) | ![Nearby, dark](latest/nearby-list-dark.png) |
| Search — empty landing | ![Search empty, light](latest/search-empty-light.png) | ![Search empty, dark](latest/search-empty-dark.png) |
| Search — `invoice internet` results | ![Search results, light](latest/search-results-light.png) | ![Search results, dark](latest/search-results-dark.png) |
| AI organise — Tidy `/Downloads` plan | ![Organise, light](latest/organise-plan-light.png) | ![Organise, dark](latest/organise-plan-dark.png) |
| Settings — Appearance / a11y / About | ![Settings, light](latest/settings-light.png) | ![Settings, dark](latest/settings-dark.png) |

Rows for not-yet-shipped states will render as broken images until
the matching phase lands — that's deliberate, it's the to-do list.
