# Priest aggressive leveling — 1.29.11 review

Date: 2026-09-13. Request: a more aggressive Priest rotation that favors damage.
Scope: class policy, focused regression tests and documentation. After testing
the Priest changes in game, the maintainer confirmed the result and authorized
version 1.29.11 and publication on 2026-09-13. The tested gameplay code is
unchanged during release preparation; only metadata/documentation is updated.

## Baseline findings

- Old wand eligibility started at target HP <=55%, mana <=52%, or Spirit Tap.
  Its score exceeded ordinary Mind Blast and fillers in many funded fights.
- Smite was excluded whenever the dominant tree was Shadow, including the first
  point at level 10 before Mind Flay was learned. This left little between
  Mind Blast cooldowns and wanding for early Shadow leveling.
- Close-range Smite/Mind Flay were excluded even behind an active Shield.
- Static percentage gates did not compare the cost of the learned spell against
  the mana remaining after a cast.

## New policy

1. Preserve emergency orchestration and existing Shield/heal/control thresholds.
2. Favor a missing useful Pain DoT, then funded Mind Blast and available learned
   fillers. Smite is no longer restricted by talent-tab identity. Learned Mind
   Flay works in mixed builds; native usability still filters inaccessible
   spells. Holy Fire needs time for its cast plus useful ticks and no active DoT.
3. Read mana costs by localized spell name, preferring legacy APIs with modern
   fallback. Use the native learned cost, including reported current modifiers,
   rather than hardcoded rank-1 values. Unknown/negative/non-finite/failed reads
   stay unknown. Preserve 15% maximum mana after damage casts, raised to 25%
   when HP <=72% or reserve <52, and at least one cheapest readable usable
   Shield/heal cost. Weakened Soul excludes Shield from that comparison.
4. Without complete cost/max-mana data use before-cast gates: 35% Mind Blast,
   30% Pain/Smite/Mind Flay, 45% Holy Fire; at least 35% under pressure.
5. Give wand high priority at mana <=25%, or target HP <=20% with TTK <=4 seconds
   or no estimate. Otherwise its score is 45: even maximum opposite +/-12
   adaptive biases plus four-point hysteresis cannot displace funded Smite.
   Do not reset or edit previous learning data.
6. Use localized cast-time data for offensive horizon checks. Require estimated
   remaining target life >= cast time +0.35 seconds when known; require at least
   3.35 seconds for Mind Flay. Pain needs nine seconds; Holy Fire needs its cast
   time plus six seconds. Only credible TTD estimates suppress offensive casts.
7. Permit near-target damage behind Shield. Without Shield, close channels stay
   excluded and hard casts require HP >=80 and reserve >=65. General range and
   real cast/channel hold behavior is unchanged.
8. Keep a usable no-wand finisher at low target HP. If no eligible spell remains,
   explicit wait feedback prevents generic BASE fallback from undoing the
   budget/casting decision. BASE macros and fixed action slots are unchanged.

## Review/refinement passes

First pass: traced actual class scores and learned-spell gating; replaced early
wand preference and restored early/mixed-build filler. Added real cost/reserve
tests and checked that ordinary damage cannot displace required low-HP recovery.

Second pass: found and corrected the no-wand low-HP finisher/fallback gap, used
localized current cast times instead of rank-1 timing, checked missing/failed
resource APIs, and separated ordinary wand score from extreme adaptive bias.
Re-ran all class/aura/range/cast-hold and wand regressions. No shared engine,
macro, saved-option or learner schema modification is needed.

## Verification

- 52/52 addon Lua chunks parse.
- 36/36 Lua 5.1 harnesses pass, including 114 focused Priest checks and the
  existing 250 wand and 136 Advisor UI checks.
- The focused harness exercises the real Priest candidates, Engine selection,
  native macro construction and adaptive safety policy. It covers levels before
  talents, first Shadow point, mixed learned actives, unavailable spells, actual
  rank/talent-cost fixtures, reserve boundaries, active/short-lived DoTs,
  close-range casts, imminent/uncertain TTD, emergency precedence and no-wand
  fallback. All other classes retain their existing modules and regressions.
- 19/19 offline release-pipeline tests pass; 53/53 TOC references resolve.
- README/CHANGELOG root and packaged copies remain identical; release metadata
  is 1.29.11 and the unchanged package allowlist contains 57 files.

## In-game confirmation

On 2026-09-13 the maintainer reported a successful in-game test of the new
Priest policy and asked to publish it. This confirms the reported smoke test,
not an exhaustive all-build comparison or a measured DPS/leveling-speed gain.
The published gameplay changes are the same ones tested before the version bump.

These are API/state fixtures and policy assertions, not DPS measurements.
More casting consumes more mana and may increase between-pull drinking. Native
cooldowns, spell requirements and player-operated secure input still apply.

## Gameplay comparison to observe

On comparable safe mobs, check that a healthy early Shadow Priest uses Mind
Blast and then Smite while the target still has substantial HP and enough mana
is available. Check the transition to wand near the end or at low mana, active
DoT suppression, Shield/heal priority and the existing LET IT FINISH behavior.
Compare both fight duration and drinking downtime; do not infer a measured DPS
or overall leveling-speed gain from priority changes alone.

API contract reference: [Blizzard spell API declarations](https://github.com/Gethe/wow-ui-source/blob/classic/Interface/AddOns/Blizzard_APIDocumentationGenerated/SpellDocumentation.lua).
Native spell identifiers accept names; power-cost results are resource-specific
entries. Actual client reads remain authoritative.
