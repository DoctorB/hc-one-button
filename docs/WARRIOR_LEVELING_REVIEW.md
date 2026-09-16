# Warrior offensive leveling review — 1.29.13

## Scope and reproduced behavior

The level-6 diagnostic loads the real Warrior, SpellUtils, Survival, Engine
selection/router and Stabilize functions. Only client inputs and the chosen
fight trend are simulated; it does not estimate DPS or reconstruct a live fight.
The original healthy threshold was 35 even with a saved value of 20. Caution
required 40 without learned Hamstring; 37% player HP could require 45. These
policies predated the Priest changes. The old swing/display combination had
a 90ms minimum visible lead over the 60 simulated timing combinations.

## Contract

- Only Warrior opts into `riskWarningsOnly`. Other classes retain their routes.
- Critical HP (default 20, honoring the saved setting) still enters panic.
  Danger HP, trend and multi-pull warnings decorate normal decisions instead
  of returning an escape action. A warning retains the spell, key and selected
  candidate snapshot. No spell is invented when normal eligibility is empty.
- Remove speculative defensive candidates from normal Warrior scoring and
  remove reserve penalties from offensive scores. Mitigation competes normally.
  Bloodrage health/resource safeguards and maintained aura boundaries remain.
- Saved Rage base remains untouched, clamped to 20–70 for evaluation. Before
  any learned MS/BT/Whirlwind, subtract 10 (floor 20); with a developed kit keep
  the base. Without Execute at <=30% target HP, subtract 5 (floor 20). Cleave
  adds 5. No level-difference floor or risk surcharge remains.
- Existing learned-Execute pooling (21–30%, release 85), proc/core priority,
  native usability, rank-name fallback, cast holds and interrupts remain.
- Queue window: `min(speed * .65, clamp(speed * .30, .80, 1.10))`. No repeat
  after queue acknowledgment; no stale unqueued suggestion after a new swing.
- Informational danger colors do not bypass 0.20s normal swap confirmation.
  Real critical HP and interrupt escalation still bypass it immediately.
- No secure action/binding changes, schema reset, learner revision change or
  other-class policy opt-in. Settings and learning history are retained.

## Review/refinement pass 1

Traced normal/caution/multi routes and the old 35/40/45 gates. Consolidated
spending through normal scoring, preserved risk information and made the early
budget depend on learned core abilities rather than character level. Expanded
the swing window while retaining a non-queue portion for fast weapons. Added
real-engine fixtures across levels 1/6/10/19/30/40/60, target-level differences,
custom settings, learned core/proc/Execute, critical boundaries and multi-pulls.

## Review/refinement pass 2

Found that warning severity could bypass normal display stabilization; track
advisory-only risk in display state so normal action swaps still confirm. Also
clear the old queued-spell suggestion as soon as a fresh swing closes eligibility.
Added coverage for both refinements, queue acknowledgment, invalid saved numbers,
numeric strings, tooltip callbacks and persistence. All nine class contracts
assert that only Warrior opts into advisory risk. Existing Priest, aura, group
healing and secure-action suites remain part of the full regression run.

## Validation

- `tests/run.ps1`: 56 addon Lua chunks, 39 harnesses, 57 TOC references.
- `tests/warrior_leveling.lua`: 491 checks, including 60 swing/heartbeat phase
  combinations; minimum visible lead 450ms in this simulated matrix.
- `tests/diagnostics/warrior_low_level.lua`: 133 mechanics assertions and a
  repeatable threshold report (default 25; custom 20; caution 25; 37% HP 25).
- Offline release-tool unit tests: 19. Archive: 61 allowlisted files.
- This establishes policy and timing behavior under mocked inputs, not a
  quantified damage gain. No earlier live test is relabeled as this release's.

## Gameplay acceptance points

Check an early Warrior with maintained Shout/Rend at 20/25/35 Rage; risk warnings
should retain a funded attack. Check warning-to-critical transition at the saved
HP boundary, a two-target pull, a learned core strike, and one queued HS per swing.
Verify tooltip readability and normal Warrior modifiers, then compare actual
session results before drawing DPS conclusions.

Publication is explicitly authorized by the maintainer on 2026-09-16. Use the
stable tag `v1.29.13` and exact `docs/releases/1.29.13.md` body through the existing
authorized GitHub Release workflow. Verify upload acceptance and moderation
separately; do not retry an uncertain upload.
