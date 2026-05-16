---
mode: agent
description: Build, run, screenshot and self-review one phase / tier of Fluff. Follows the build-tier skill end-to-end.
---

# /build-tier

Build the next (or named) phase of Fluff following the
[build-tier skill](../instructions/build-tier.skill.md). At the end,
push the code + screenshots and update
[docs/DESIGN.md](../../docs/DESIGN.md).

## Steps

1. Read [PLAN.md §5](../../PLAN.md#5-phased-roadmap) and identify the
   target phase (default: the next one listed as `⬜` in the table in
   [README.md](../../README.md#project-status--roadmap)).
2. Implement the phase per
   [PLAN.md §5](../../PLAN.md#5-phased-roadmap), touching only the
   packages it names.
3. Run `flutter run -d chrome --web-port=8765` in `app/`.
4. Open `http://localhost:8765` in the VS Code Simple Browser.
5. Detect the real viewport (`window.innerWidth` /
   `window.innerHeight`) — do **not** hard-code.
6. Screenshot every reachable route into
   `docs/screenshots/<phase>/<route>@<w>x<h>.png`.
7. Self-review against the build-tier skill checklist (edges,
   whitespace, alignment, contrast, hit-targets). Log findings in
   `docs/DESIGN.md` "Iteration log".
8. Fix issues; re-screenshot; repeat until clean.
9. Commit per Conventional Commits and push.
10. Update the phase status in `README.md` and `docs/DESIGN.md`.
