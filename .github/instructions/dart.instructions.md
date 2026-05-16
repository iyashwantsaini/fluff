---
applyTo: "**/*.dart"
---

# Dart / Flutter rules

- Two-space indentation. `dart format` on save.
- `dart analyze` must be clean before commit.
- Public APIs documented with `///`; private helpers don't need it.
- Prefer `const` constructors when arguments are compile-time constants.
- No `print()` in committed code — use `dart:developer`'s `log()` or a
  shared `FluffLogger`.
- No `Color(0x…)` outside `packages/fluff_skin/`. Colours come from
  `WlmTheme` or `FluffSyntaxColors`.
- No `Random()` in `packages/fluff_vault/`. Use the `cryptography`
  package's `SecureRandom`.
- No `dart:io.File` under `app/lib/`. Go through `FsProvider`.
- Tests live next to the code in `test/`.
