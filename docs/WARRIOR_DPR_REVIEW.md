# Warrior leveling DPR review — 1.29.15

## Decision model

`Classes/WarriorDPR.lua` implements a bounded, dynamic comparison of Heroic Strike, early Rend and the first Sunder Armor application. It is used for solo, single-NPC combat with one main-hand weapon and no off-hand weapon. Group combat, PvP, multi-pulls, dual wield and incomplete client data retain the previous scoring policy. This is not a full simulation or a claim that every decision in the reference workbook is reproduced.

Inputs are current player level, main-hand damage/speed, melee crit, talent-adjusted spell costs, target health, a confident live TTK when available, and exact learned spell ranks. Native damage already includes AP and applicable weapon/buff bonuses; these are not added again. Crit already includes passive crit talents. Improved Rend (15/25/35%) and Impale (10/20% extra critical bonus) use invested ranks, not the dominant talent tree. Exact-rank and talent caches invalidate on login/world entry, level, spellbook and talent events. Level alone never grants a higher rank.

Enemy armor is read when the client supplies a positive effective value. An unavailable/zero value is not claimed to prove an armorless NPC: the model explicitly estimates 30% mitigation instead. Candidate reasons show `est. DPR` and append `armor estimated` when applicable. Positive armor is still an input to an approximation, not proof that avoidance, immunities or every modifier are known. The model does not invent full weapon skill, a hit table or future proc damage.

## Formula mapping

The user-supplied `Copia di Fight Club DPR Sheet (by SAKUJ0 and Beanna).xlsx` was inspected read-only. The reference is parameterized by level and separately selected talents. No saved level-55 result, preset weapon, talent allocation or NPC health was imported.

- `How To Use!A14:A16`, `Theorycraft!F4:G4`, `Damage!H4:I4`: HS buys incremental damage and replaces a Rage-generating white hit. We compare that bonus (plus Impale's additional crit contribution) against the native cost plus estimated foregone white-hit Rage, not a fictitious full extra weapon swing.
- `LevelDB!P18:Q18`: armor denominator `400 + 85 * level` and Rage conversion `0.0091107836 * level^2 + 3.225598133 * level + 4.2652911`. White-hit Rage uses the sheet's factor 7.5 and current expected weapon damage after armor.
- `Theorycraft!F8:G8`, `Damage!H11:I11`: Sunder's remaining-health benefit is expressed in damage units: `remainingHP * armorReduction / (armor + armorDenominator)`. The reduction cannot exceed reported/estimated armor, and the projection is limited to its 30-second duration. Additional white-hit Rage reduces effective cost, bounded to at least 1 to avoid undefined/negative DPR. This assumes predominantly physical remaining damage; the restriction to solo avoids crediting unknown party damage composition.
- `Damage!I5:J6`, `AbilityDB!A16:H22`: Rend uses the actually learned rank, invested Improved Rend, damage multiplier, and whole ticks available before estimated death. Without a confident TTK, remaining HP divided by expected white DPS supplies an explicit approximation. At least two ticks must fit. The existing first-seven-seconds opener guard remains, and an active own Rend is never repeated.

For setup to qualify, its estimated DPR must exceed HS by 10%. Sunder must have at least two future swings (and three seconds) available. No stacking beyond the first aura is introduced. A same-name Sunder from another caster and Expose Armor suppress redundant application. Cast acknowledgement and short aura-read grace prevent duplicate Sunder requests.

Eligible modeled candidates receive a bounded 62–78 score proportional to DPR. HS receives 82 at >=80 Rage or when a normal modeled HS swing can finish the target; the latter may reduce its threshold to its current cast cost. This is a likely-finisher estimate, not a guaranteed hit. Existing swing windows, usability, committed queue budgets, saved options, core attacks, Overpower, Execute, critical HP and interrupts remain authoritative. Rend/Sunder cannot consume Execute's pooling reserve. The optional secure BASE Rend sequence remains unchanged and is not dynamically rewritten in combat. Existing bounded local tuning can still influence eligible scores.

## Deliberate limits

The focused comparison omits the sheet's hypothetical future Overpower/Deep Wounds/proc credits, glancing/miss/dodge/refund model and whole-rotation scheduling. It does not model Cleave/multi-target positioning or a dual-wield queue hit-table benefit. It does not optimize other classes or replace their rotations. Fallback decisions are retained, not mislabeled as calculated DPR. This release improves decision inputs/efficiency comparisons; no measured DPS/TTK gain is claimed.

Secondary implementation cross-checks (not copied source): [Classic simulator Heroic Strike](https://github.com/wowsims/classic/blob/master/sim/warrior/heroic_strike_cleave.go), [Rend talent multipliers](https://github.com/wowsims/classic/blob/master/sim/warrior/rend.go), and [talent identifiers](https://github.com/wowsims/classic/blob/master/ui/core/talents/trees/warrior.json). Exact-known API semantics were checked against [the Classic Era UI API definitions](https://github.com/Gethe/wow-ui-source/blob/classic_era/Interface/AddOns/Blizzard_APIDocumentationGenerated/SpellBookDocumentation.lua).

## Review and validation

First pass: formula units, lost Rage, absolute remaining HP, client costs, exact learned ranks and real candidate selection. Second pass: first talent point/respec, alternate talent and cost APIs, fallback contexts, missing/error data, no duplicate AP/crit, Execute pooling, bounded Rend opener, finish/cap overrides and unchanged protected priorities.

`tests/warrior_dpr.lua` passes 173 checks, including cases spanning levels 6–60 and real scorer decisions that change between Sunder, Rend and HS as inputs change. The complete runner passes 57/57 Lua chunks, 43/43 Lua harnesses and 58/58 TOC references. Existing 491 leveling, 134 input/budget, 66 mitigation and 118 all-class damage-timing checks pass. See also [the mitigation/timing review](WARRIOR_DPS_TIMING_REVIEW.md). Test results are simulated-client regressions, not gameplay benchmarks.
