# Party click-healing — 1.29.12 review

## Scope and contract

- Four healer classes: Priest, Paladin, Shaman and Druid. Advice is optional and account-persisted; the party panel and click assignments are character-persisted.
- Fixed player/party1–4 secure actions, separate mouseover keyboard buttons and unchanged self-heal slots. No health-based protected target selection or event-driven casting.
- Rank-free localized native casts, supported learned spell-family upgrades, deferred protected configuration after combat.
- Independent panel anchor and scale, real player row while solo, party membership visibility and raid hiding; configuration follows WindowManager navigation and combat closure.

## Final review — 2026-09-14

Read the advisor, class contracts, spell and aura helpers, cast-event integration, secure UI, options, panel and regression fixtures. Rechecked learner isolation, existing emergency/cast precedence, invalid/missing range and cost data, disabled advice versus preserved manual actions, modifier no-ops and saved defaults.

Reviewed the mouse-input path separately: inherited secure enter/leave/show/hide handlers remain intact through tooltip hooks. Temporary middle/side-button overrides belong to the hovered row; leave/hide clears only its own bindings. Native execution is release-only, and unassigned combinations do not fall through to permanent actions. Tests model the restricted snippets and ownership lifecycle, not the client's physical hit-testing implementation.

The final pass also moved group-heal glow/reason coloring from an incorrectly scoped telemetry branch into SetDisplay. Added regression checks for immediate group styling without a logger and danger counters unaffected by an unrelated global named group. The tested secure click/binding implementation is unchanged.

The maintainer confirmed successful in-game panel use, including left/right/middle clicks, and authorized publication. The reported middle-click failure was traced by the maintainer to the mouse and disappeared after replacement. No further mouse-path change follows that confirmation. This is a panel smoke test, separate from four-class automated coverage.

## Release validation

- Lua parse: 56/56 addon chunks; shared runner: 38/38 harnesses.
- Party panel: 1,261 checks; group-healing advice/actions: 198 checks; Advisor UI: 162 checks.
- All four healer fixtures exercise supported learned roles/ranks, modifiers, fixed targeting, solo/party/raid lifecycle, persistence, independent position, combat deferral and hover-binding cleanup. Non-healer options remain free of the new section.
- Existing all-class regressions remain green. Offline release tooling: 19/19 tests.
- TOC: 57 references; package: 61 files, one HCOneButton root, verified CRC/SHA256 and matching root/package documentation.
- Version 1.29.12; Interface 11509; learner revision 4; adaptive schema 2; telemetry contract 1. No settings/history reset, no permanent binding overwrite.

## Publication

Use tag `v1.29.12`, title `HCOneButton v1.29.12`, stable Release, and the exact body from `docs/releases/1.29.12.md`. Publish through the existing GitHub Release → CurseForge workflow for project 1666468. Check the workflow upload receipt separately from CurseForge approval; do not retry an uncertain upload.
