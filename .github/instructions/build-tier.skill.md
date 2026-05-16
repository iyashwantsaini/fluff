---
description: The canonical build-tier-screenshot-iterate loop for Fluff. Use whenever you are asked to build a phase, tier, or batch of features.
---

# Skill — build-tier (run, screenshot, analyze, iterate)

This is **the** workflow for landing a feature batch in Fluff. Do not
skip steps. Do not hard-code viewport sizes. Do not push until the
screenshots are clean.

## When to use

- A user request maps to a phase / tier in
  [PLAN.md §5](../../PLAN.md#5-phased-roadmap), e.g. "build Phase 2",
  "ship Tier 1 archives", "add the vault unlock screen".
- A user request adds a new screen, a new viewer, or a new mount type.
- A user request asks for a visual fix.

## Inputs

- The phase / tier name (e.g. `phase-1`).
- The set of routes the batch is supposed to render.
- Optionally a specific viewport (otherwise: detect from Simple Browser).

## Steps

### 1. Plan the batch

- Read the matching section of [PLAN.md](../../PLAN.md).
- Update [docs/DESIGN.md](../../docs/DESIGN.md) "Current phase"
  pointer and add a new entry under "Iteration log" with today's date
  and the batch scope.
- Write or update a todo list with the steps below.

### 2. Implement

- Touch only the packages this batch needs.
- Honour every hard rule in
  [.github/copilot-instructions.md](../copilot-instructions.md).
- Add unit tests in the same PR for any pure-Dart logic.

### 3. Run locally on Flutter web

```powershell
cd app
flutter pub get
flutter run -d chrome --web-port=8765
```

If the Chrome window isn't useful, build + serve instead:

```powershell
flutter build web --no-tree-shake-icons
# then serve build/web/ on :8765 with `dart pub global run dhttpd --port 8765`
```

### 4. Open in VS Code Simple Browser at the user's actual viewport

- Open `http://localhost:8765` in the **Simple Browser** via
  `run_vscode_command` → `simpleBrowser.show`.
- **Detect the viewport** with the browser tool of choice
  (`open_browser_page` → `read_page` for `window.innerWidth`,
  `window.innerHeight`, or `run_playwright_code` with
  `page.evaluate('({w:innerWidth,h:innerHeight})')`).
- **Pin the driver's render viewport to the detected size** before
  any screenshot — e.g. `page.setViewportSize({width:w, height:h})`.
  Skipping this step lets the headless driver render at its own
  default (typically `1280×720`) while the Flutter canvas renders at
  the smaller Simple Browser size, producing PNGs with an
  asymmetric whitespace strip on the right. Always detect, then pin,
  then screenshot.
- Use that detected size as the screenshot resolution. Do **not**
  assume any fixed dimensions.

### 5. Walk every reachable route and screenshot

Screenshots live in **one** folder: [`docs/screenshots/latest/`](../../docs/screenshots/latest/).
There are no per-phase subfolders. Every pass **overwrites** the
PNGs for the states it touches, so the docs always reflect the
current UI — never a historical one.

- For each reachable state in the batch:
  1. Navigate to it (use the relevant demo-URL handler if Flutter
     web won't honour pointer gestures, e.g. long-press).
  2. Wait for `networkidle` + 250 ms settle.
  3. Capture **both themes** by toggling `?dark=0` / `?dark=1` and
     write to:
     - `docs/screenshots/latest/<state-slug>-light.png`
     - `docs/screenshots/latest/<state-slug>-dark.png`
  4. Filenames carry **no** resolution suffix — the size is
     intrinsic to the PNG and the viewport is detected fresh on
     every pass.
- The full state inventory (one row per state, light + dark in
  side-by-side columns) lives in
  [`docs/screenshots/README.md`](../../docs/screenshots/README.md).
  Add a row there for any new state this batch introduces.
- If the batch introduces a responsive breakpoint, also capture a
  phone width (≤ 480) using `-phone-light.png` / `-phone-dark.png`
  suffixes.

### 6. Self-review the screenshots

For each screenshot, check:

- [ ] **No accidental whitespace** at any edge (left, right, top, bottom)
      beyond the documented page padding in
      [docs/DESIGN.md](../../docs/DESIGN.md) §"Spacing".
- [ ] **No clipped content** (overflow chevrons, truncated text where
      not intended).
- [ ] **Consistent vertical rhythm** — list rows the same height,
      section gaps the same multiple of the spacing token.
- [ ] **Touch / click targets ≥ 40 px**.
- [ ] **Hairline borders visible** on the chosen surface — bump
      `outlineVariant` if not.
- [ ] **Contrast** at the docs' baseline (light + dark).
- [ ] **wloom widgets used** where the
      [PLAN §8 mapping](../../PLAN.md#8-ui-mapping-wloom) says so.

Append findings to [docs/DESIGN.md](../../docs/DESIGN.md) "Iteration
log" with the screenshot path and the verdict.

### 7. Fix and re-screenshot

- Apply the smallest possible fix.
- Re-run step 5 only for affected routes.
- Repeat until the checklist is clean.

### 8. Commit and push

- One commit per logical change (Conventional Commits).
- A final `chore(docs): screenshots for <phase>` commit for the docs
  delta.
- Push to `origin/main` (or a feature branch for larger work).

## Outputs

- Working code under the relevant `packages/` / `app/`.
- Refreshed PNGs in [`docs/screenshots/latest/`](../../docs/screenshots/latest/)
  (light + dark for every touched state).
- An updated [`docs/screenshots/README.md`](../../docs/screenshots/README.md)
  inventory with any new rows.
- An updated [docs/DESIGN.md](../../docs/DESIGN.md) with the
  iteration log entry (use this as the historical record — the PNG
  folder itself is **not** historical).
- A clean `flutter analyze` and `melos run test`.

## Anti-patterns

- ❌ Hard-coding `1280x720` (or any other size) as the screenshot
  viewport. The browser is the source of truth.
- ❌ Per-phase subfolders (`phase-1/`, `phase-2/`, …). One
  `latest/` folder; overwrite, don't accumulate.
- ❌ Resolution suffixes in filenames (`…@1233x1257.png`). The PNG
  metadata carries the size; the filename should not.
- ❌ Capturing only light *or* only dark. Both per state, every pass.
- ❌ Screenshotting one route and calling it done.
- ❌ "I'll add the screenshots later." Screenshots are part of the
  same commit / PR as the feature.
- ❌ Touching multiple phases in one batch. One phase per pass.
- ❌ Adding telemetry, analytics, "anonymous usage", or crash uploads.
