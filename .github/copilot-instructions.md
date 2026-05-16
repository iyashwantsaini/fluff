# Copilot instructions — Fluff

> These rules apply to **every** Copilot session in this repository.
> Read [README.md](../README.md) and [PLAN.md](../PLAN.md) before
> proposing any change. PRs are reviewed against PLAN.md — diverging
> from it requires an RFC.

## Project facts

- Fluff is a **pure-Flutter / Dart** Android file manager.
- UI uses the **wloom** design system (`wolwoloom` on pub.dev).
- Workspace is managed by **melos**; packages live in `packages/`,
  the app lives in `app/`.
- Phases are defined in [PLAN.md §5](../PLAN.md#5-phased-roadmap).
  Current phase is tracked at the top of
  [docs/DESIGN.md](../docs/DESIGN.md).

## Hard rules (failing any of these blocks merge)

1. **No `dart:io.File` in `app/`.** All storage access goes through
   `FsProvider`. Use `LocalFsProvider` for local paths.
2. **No app-side Kotlin / Java / Swift / Objective-C** in
   `app/android/app/src/main/kotlin/` (or the iOS equivalent). Native
   code lives in pub.dev plugins or in our own published shim plugins
   under `packages/fluff_native_shims/`.
3. **No telemetry.** Not opt-in. Not opt-out. Not for crashes.
4. **All user-visible strings come from ARB** in `app/lib/l10n/`.
   Hard-coded English in widgets fails review.
5. **`fluff_vault` is special**: 90%+ line coverage, property tests
   with `glados`, and a benchmark number in every PR description.
6. **Conventional Commits**: `feat(fluff_vfs): …`, `fix(app): …`,
   `docs(plan): …`, `chore: …`. One concern per PR.
7. **Never run `git push --force`, `git reset --hard` on shared
   branches, or amend commits already on `origin/main`** without
   explicit user confirmation.
8. **Never commit anything under `external/`.** That folder holds
   research artifacts and is in `.gitignore`.

## Architecture invariants

- `FsProvider` is the seam between storage and the UI. Adding a new
  storage = adding a new `FsProvider` impl, not new UI code.
- Long-running operations (copy, move, extract, upload, sync) live in
  a foreground task via `flutter_foreground_task`. The UI subscribes
  to events; closing a screen never cancels work.
- Theming reads from `WlmTheme` + `FluffSyntaxColors` only. No
  hard-coded `Color(0x…)` outside `packages/fluff_skin/`.
- One screen per heavyweight viewer (image, video, text, hex, ebook,
  PDF). They share `FsProvider` and `SkinController`.

## Build / iterate workflow (skill-driven)

For each feature batch, follow the
**[build-tier](../.github/instructions/build-tier.skill.md)** skill:

1. Build the tier (a coherent batch of features mapped to a phase).
2. Run the app via `flutter run -d chrome --web-port=8765` and open
   `http://localhost:8765` in the **VS Code Simple Browser**.
3. Detect the actual viewport size in the Simple Browser
   (do **not** hard-code 1280×720 — the user may have resized it).
4. Capture screenshots of every reachable state — light **and**
   dark for each — into `docs/screenshots/latest/<state>-{light,dark}.png`
   at the detected viewport. There are no per-phase subfolders;
   every pass overwrites the PNGs it touches so the docs always
   show the current UI.
5. Self-review each screenshot for **whitespace at edges**, clipped
   content, alignment glitches, contrast issues, and inconsistent
   spacing. Document findings in
   [docs/DESIGN.md](../docs/DESIGN.md) under "Iteration log".
6. Fix issues, re-screenshot, repeat until clean.
7. Commit per
   [CONTRIBUTING.md](../CONTRIBUTING.md) commit-style rules and push.

## Style

- Two-space indentation in Dart (the formatter handles it).
- `dart format` on save; `dart analyze` clean before commit.
- Public APIs documented with `///`; private helpers don't need it.
- Tests live next to the code (`test/` in each package).

## When in doubt

Open an RFC in `docs/rfcs/NNNN-title.md`. Do **not** invent
architecture on the fly for anything touching `fluff_vfs`,
`fluff_vault`, `fluff_addons_api`, the nearby-transfer wire protocol,
or the skin-pack schema.
