# Hunter leveling review — 1.29.16

## Review 1: reproduce and correct

The initial focused harness reproduced 21 failing expectations out of 27 against the previous runtime. Findings covered missing normal-melee Raptor, queued-strike recognition, unknown range, moving casted shots, instant-shot gating, stale auto-repeat, Mark eligibility, dominant-tree gating, pre-pet threat and stale Serpent observations.

BASE inspection also found `/startattack` after `!Auto Shot`. Move melee preparation first so the final attack-mode request is ranged. This is a structural secure-macro test, not a simulated proof of actual client attack execution.

## Review 2: transitions and isolation

Extend coverage across levels 1–60, higher learned ranks, immediate queue-display invalidation, movement in the alternate multi-pull route, cast/channel restart holds, missing-native-API fallback, pet aggro preservation, aura refresh/removal and live-aura authority. Correct the multi-pull reason: observing two engaged enemies cannot prove that Multi-Shot will not hit an additional nearby enemy.

No changes to action-slot order, persistent configuration or learning schemas. Shared queue recognition gains only Raptor Strike; Warrior swing timing remains unchanged. Ammunition counting, feeding policy and generic risk thresholds are not redesigned in this release.

## Checks

Run `tests/run.ps1` and the offline Python release-tool suite. Verify root/package documentation equality, TOC/runtime versions and ZIP contents before creating the release. Confirm CurseForge acceptance separately from moderation approval.

## Mechanic references

- [WoWSims Classic Raptor Strike implementation](https://github.com/wowsims/classic/blob/master/sim/hunter/raptor_strike.go): next-melee-swing queue.
- [WoWSims Classic Arcane Shot implementation](https://github.com/wowsims/classic/blob/master/sim/hunter/arcane_shot.go): instant shot with native cooldown/cost.
- [Blizzard forum: Classic Hunter Auto Shot macro](https://us.forums.blizzard.com/en/wow/t/classic-hunter-auto-shot-macro/301555): ranged/melee attack-mode distinction.

## 1.29.18 follow-up: melee suggestion at shooting range

`TargetIsClose()` returned the first non-nil Wing Clip / Raptor Strike range result before any ranged evidence. A melee "in range" report at shooting distance (large combat reach, queued on-swing strike) therefore produced ENABLE MELEE / Raptor Strike and blocked `AutoShotNeedsRestart()`. A positive Auto Shot or ranged-probe result now wins; otherwise any in-range melee spell marks the target close, and a negative melee result still beats stale combat-log evidence. Four regressions cover the precedence and dead-zone transition.

## 1.29.20 pet, aspect and travel follow-up

- `PetState()` returns alive/dead/missing and remembers an observed death, so a
  dead pet whose unit has vanished still asks for Revive Pet, not Call Pet.
  Out of combat (not on a taxi, not dead): Revive Pet 124, Call Pet 121, passive
  pet warning 119, Mend Pet below 70% 97. The pre-pull gate returns the matching
  learned fix spell (Hunter only; Warlock pet advice stays text).
- Pre-pull combat aspect (Hawk, else Monkey) with a hostile target out of combat,
  score 73. Cheetah travel reminder: no hostile target, eight seconds moving on
  foot outdoors, `hunterCheetahReminder` (default ON, reset restores it), score 40,
  idle display.
- In combat: pet off target after 1.5s on a single enemy while the Hunter attacks
  (`PRESS BASE`, which runs `/petattack`); dead pet above 25% target HP asks for
  Concussive Shot or warns; a target flee emote (English text, or any target emote
  at <=35% HP) opens an eight-second window for Concussive, then Arcane Shot.
- Revive Pet and Call Pet have no slot: the Hunter layout already fills the
  20-slot pixel protocol. Concussive keeps the existing `CTRL+SHIFT` hint, whose
  macro tries Scatter Shot first.
- `tests/hunter_pet_safety.lua`: 41 checks. Options layout checks that utility
  buttons clear the new Hunter section. Simulated client only; in-game check pending.
