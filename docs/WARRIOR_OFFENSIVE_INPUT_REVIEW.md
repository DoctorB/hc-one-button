# Warrior offensive input and Rage-budget review

Target: 1.29.14 stable release, authorized on 2026-09-16. Two review/refinement passes completed; publication acceptance is verified separately through CI.

## Evidence and scope

Local character-scoped SavedVariables show funded Heroic Strike use with no Rage
cap pressure. They also show 16 Battle Shout casts outside matched suggestions
among 21 casts. BASE input overlaps dedicated slot input; BASE's SHIFT branch
was Battle Shout. Modifier state was not recorded, so the observed activation
mechanism remains a strongly supported inference rather than a full live replay.
The user explicitly approved making Warrior BASE independent of all modifiers.

No raw character/account data is committed. No changes to files installed in WoW
or SavedVariables are performed by this source change.

## Changes

- Warrior-only `baseIgnoresModifiers` contract; all eight secure attribute
  combinations use identical BASE text, installed only outside combat. Existing
  slot numbers/keys are unchanged and old secure branches are overwritten.
- No obsolete modifier hints for Warrior recommendations, tooltip or `/hcob plan`.
  Other class contracts retain their modifier actions.
- Maintenance candidates reserve the live queued HS/Cleave cost. Native costs
  use localized names (learned rank and client discounts); invalid/unavailable
  costs fall back to known undiscounted Classic costs. No native resource or
  usability check is bypassed.
- Only Battle Shout/Rend/Sunder/Clap/Demo maintenance is constrained. Proc/core
  choices, interrupts and critical defense can still supersede a queued dump.
  This is not a global wait and does not raise the ordinary HS threshold.

## Review pass 1

Checked secure attribute generation across every modifier state, fresh/stale
attributes, with/without opener Rend and combat lockdown. Verified Warrior
dedicated slots still use their existing queue-safe macros and all other class
contracts remain unchanged. Queried cost APIs only when a queue reservation is
actually needed; tested discounts, zero cost, missing APIs and invalid numbers.

## Review pass 2

Found that native usability alone could retain a displayed maintenance spell for
the 200ms stabilization interval after an attack was queued. Added a class-owned
pending-eligibility check to clear the now-unfunded hint immediately. Verified
critical/interrupt preemption and no blanket suppression of funded maintenance.
Updated the printed plan so it does not advertise removed/nil modifier shortcuts.

## Verification and limitations

The full Lua suite includes the new `tests/warrior_offensive_budget.lua` plus
existing 491 Warrior leveling assertions, deterministic-slot tests and all-class
regressions. Tests execute real local policy/macro code with simulated client
inputs; they do not quantify a DPS improvement or replay an entire combat log.

Final run: 56/56 addon Lua files parsed, 40/40 Lua harnesses passed, 134 focused
offensive-budget/input assertions passed, and 19/19 offline release-tool tests
passed. Root/packaged README and changelog match; `git diff --check` is clean.

The queue reservation governs Advisor maintenance recommendations, not arbitrary
manual casts or the preconfigured optional opener Rend in BASE. Core attacks can
intentionally consume Rage ahead of the dump. Do not turn this into a promise
that every queued strike will land. Rage thresholds and tuning coefficients
remain unchanged.
