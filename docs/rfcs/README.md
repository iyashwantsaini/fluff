# RFCs

Architectural change proposals for stable Fluff surfaces. Filename
convention: `NNNN-short-title.md` (`NNNN` is the next free 4-digit
sequence number).

A change needs an RFC when it touches:

- `FsProvider` shape or semantics
- the vault on-disk format
- the nearby-transfer wire protocol
- `fluff_addons_api`
- the skin-pack schema

Template:

```markdown
# NNNN — Title

- **Status:** draft | accepted | rejected | superseded
- **Author(s):** @handle
- **Created:** YYYY-MM-DD
- **Affects:** package(s) / surface

## Summary
One paragraph.

## Motivation
Why the existing design isn't enough.

## Proposal
The concrete change. Include code / format diffs.

## Alternatives considered
At least two, even if rejected immediately.

## Migration / compatibility
What breaks, what users need to do.

## Open questions
Anything the discussion still needs to resolve.
```
