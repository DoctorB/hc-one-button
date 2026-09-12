# Wand state and spell transitions — 1.29.10 review

Date: 2026-09-12. The maintainer authorized the fix, version bump and ordinary
Release publication through the existing GitHub → CurseForge workflow.

## Evidence and scope

The supplied account-level history contains Priest fights with an equipped
wand. Shoot is repeatedly recommended while auto-repeat is already active;
ready/unavailable BASE states alternate during its cooldown cycle. Successful
Mind Blast and Shield casts also occur: the history does not prove an absolute
client-side inability to cast, nor does it record a reason for every unsuccessful
attempt. Recorded real cast holds belong to ordinary spells, not Shoot.

The former shared caster paths never queried auto-repeat state. A reproduction
using the actual Priest, Engine, Range and macro modules confirmed repeated
Shoot recommendations, including alternation between BASE READY and BASE NOT
READY while the simulated wand remained active.

## Implemented contract

- Scope auto-repeat observation to Priest, Mage and Warlock with a wand equipped.
  Prefer the localized native query, with numeric fallback for an unavailable
  query and start/stop event fallback. A readable false overrides stale event
  state. Clear fallback on login, world transition, death and ranged-slot change.
- Preserve class candidate scoring and the efficiency baseline. An already
  running Shoot is continued damage, not a fresh action: the display shows
  WAND ACTIVE / LET IT RUN with no spell to press. No tuning policy, coefficient
  revision, spell rank or rotation threshold is changed.
- Check range before presenting active feedback. Unavailable Shoot starts show
  WAND NOT READY / WAIT / RECOVER. Never turn a wait into a spam instruction.
- Use active wand feedback as the shared fallback only after class actions and
  buffs are evaluated. This covers Mage and Destruction Warlock even though
  their BASE macro may be a nuke rather than Shoot.
- Drop a stale Shoot immediately when auto-repeat starts. Replace the active
  feedback immediately when a different action or stop/range state supersedes
  it. Other normal recommendation swaps retain their confirmation window.
- Keep actual cast/channel holds, healing/bandage protection, emergency and
  interrupt priority. Wand activity itself is not a global rotation hold.
- Start hints request one click/press. BASE text, tooltip, glow, disabled-HUD
  guidance and range warnings agree with the Advisor. No new window, binding,
  option, protected attribute update or combat-time action is added.

Native spell macros remain localized and rankless where previously rankless.
Do not prepend unconditional `/stopcasting`: repeated input would then cancel
legitimate non-instant casts. This fix removes redundant Shoot requests; it does
not bypass the client's global cooldown, cast requirements or secure input
rules, and it never stops/casts a spell from an event or timer.

## Review and refinement passes

1. Traced class scoring, shared ranged fallback, stabilization, real cast holds
   and secure macro generation. Retained efficiency scoring instead of deleting
   Shoot from candidates and accidentally forcing extra mana expenditure.
   Added unavailable-start guards and immediate removal of stale Shoot output.
2. Checked all three caster policies, safety/proc precedence, API failure/event
   fallback, range/target transitions and all nine class regressions. Refined
   Mage/Destruction BASE feedback so its nuke glow and spam label cannot
   contradict LET IT RUN; removed residual wand spam from initial/disabled HUD
   guidance and the tooltip. Exercised real event dispatch and BASE rendering.

## Automated validation

- 52/52 addon Lua chunks parse; 35/35 Lua 5.1 harnesses pass.
- 250 dedicated wand checks cover actual Priest/Mage/Warlock policy execution,
  cooldown phases, immediate start/stop output, preserved scoring, localized
  queries, API errors/missing data, real event routing, range/target changes,
  healing, offensive casts, channels, Nightfall and Clearcasting precedence,
  BASE rendering, macro size and other-class isolation.
- 136 Advisor UI checks include the existing Rogue/Hunter behavior, wand
  click/modifier hints, active/wait states and disabled-HUD manual guidance.
- 19/19 offline release-pipeline tests pass; 53 TOC references resolve.
- The unchanged package allowlist contains 57 files. Root/package documents
  and version declarations must match before publication.

The tests use simulated game APIs. They establish the addon-side state and
recommendation contract, not a measured DPS improvement or a bypass of native
spell cooldown/cancellation rules.

## Regression sequence

1. On an ordinary safe Priest pull, start Shoot once. While no higher-priority
   spell is selected, expect WAND ACTIVE / LET IT RUN without repeated Shoot
   highlights or BASE-ready/unavailable chatter.
2. Follow a Shield, heal or offensive-spell recommendation. A real cast/channel
   must show the existing LET IT FINISH feedback until completion/interruption.
3. Stop the wand, switch targets, move out of range and return; check that
   stopped/unknown/out-of-range states do not claim an action is active/ready.
4. Check Mage wand use and Warlock wand use across specs, preserving the native
   BASE macro and Warlock's combat-only pet command. Hunter is unchanged.
5. Toggle Smart HUD, inspect the BASE tooltip and check `/hcob errors` without
   resetting saved options, positions or learned data.
