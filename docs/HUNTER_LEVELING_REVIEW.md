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
