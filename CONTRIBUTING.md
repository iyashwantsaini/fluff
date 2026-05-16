# Contributing to Fluff

Thanks for being here. Fluff is built in the open and aims to stay
welcoming to first-time contributors.

## Before you start

1. Read [README.md](README.md) for what Fluff is.
2. Read [PLAN.md](PLAN.md) for how it's built and what phase we're in.
3. Look at the open issues — especially anything labelled
   `good first issue`, `help wanted`, or `phase-<current>`.
4. For non-trivial changes, **open an issue first** and let's agree on
   the shape before you write code.

## Development setup

```powershell
# prereqs: Flutter (stable), Android SDK + NDK, melos
git clone https://github.com/<you>/fluff.git
cd fluff
dart pub global activate melos
melos bootstrap

# run the app on a connected device / emulator
cd app
flutter run

# run all tests across the workspace
melos run test
```

## House rules

- **No `dart:io.File` in `app/` code.** Everything storage-related
  goes through `FsProvider`. There is a custom lint that will fail your
  PR if you slip.
- **No app-side Kotlin / Java / Swift / Objective-C.** Native code lives
  in pub.dev plugins or in our own published shim plugins under
  `packages/fluff_native_shims/`, never in `app/android/app/src/main/kotlin/`.
- **No telemetry.** Not opt-in, not opt-out, not "just for crashes".
  Not in v1.
- **Hard-coded English strings** in UI code fail review. All user-visible
  text lives in `app/lib/l10n/app_en.arb` with translator notes.
- **`fluff_vault` is special.** Anything in that package needs:
  - 90%+ line coverage,
  - property tests with `glados`,
  - benchmark numbers in the PR description (vs. the reference run on
    `main`).

## Commit + PR style

- [Conventional Commits](https://www.conventionalcommits.org):
  `feat(fluff_vfs): add SafFsProvider`, `fix(app): handle empty
  clipboard`, `docs(plan): clarify nearby-transfer protocol`.
- One concern per PR. Refactors split from features.
- PR description: what + why + how tested. Screenshots / screencasts
  for UI changes.
- Update `PLAN.md` if you change anything architectural (API surface,
  module boundary, vault format, wire protocol).

## RFCs

Anything touching one of the stable surfaces below goes through a tiny
RFC before code:

- `FsProvider` / `fluff_vfs`
- Vault on-disk format (`fluff_vault`)
- Nearby-transfer wire protocol (`fluff_share`)
- `fluff_addons_api`
- Skin-pack schema (`fluff_skin`)

Drop a markdown file in `docs/rfcs/NNNN-short-title.md`, open a PR,
discuss in the thread, merge or reject.

## Translations

ARB files in `app/lib/l10n/`. PRs against any locale welcome. A Crowdin /
Weblate project will go up once the UI stabilises around Phase 5.

## Skins

A `*.fluff-skin` is a zip of `theme.json + fonts/ + icons/`. Schema is
in [PLAN.md §7.2](PLAN.md#72-skin-pack-format). Open a PR with your
skin under `samples/skins/` and a screenshot.

## Code of Conduct

We follow the
[Contributor Covenant v2.1](https://www.contributor-covenant.org/version/2/1/code_of_conduct/).
Be kind, assume good faith, take disagreement to the issue thread.

## License

By contributing you agree your code is licensed under Apache-2.0 and
docs under CC-BY-4.0.
