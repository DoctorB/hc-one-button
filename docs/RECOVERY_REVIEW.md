# Between-pull recovery — 1.29.9 review record

Date: 2026-09-11. The maintainer authorized version 1.29.9, commits, push and publication through the existing GitHub → CurseForge pipeline. This record documents code review and automated checks; no live items were consumed by the tests. Public release notes describe functionality and checks actually performed without implying additional validation.

## Implemented contract

- Append FOOD and DRINK to the existing four-role Survival strip. Keep the frame's existing width/58-unit height, HUD scaling, anchor, visibility preference and original four secure button names. Distribute six 34-unit buttons across the same row; no extra panel or persisted option.
- Select from a bounded catalogue of plain Classic food, common cooked equivalents and vendor/conjured water. Prefer the stronger recovery tier, then conjured at equal tier, then a stable item ID. Require carried stock and cached level/consumable metadata. The live use-level requirement is authoritative: tier-3 cooked food can be usable before tier-3 vendor food. Unknown items, buff food, raw cooking materials, alcohol and battleground-only refreshments are not guessed from names or tooltips.
- Quantity and live usability refer to the assigned item. Combat freezes secure attributes; bag changes wait for combat end. Empty selection clears the old item action. Item-cache events can upgrade a selection; aura, health/power, movement and cooldown events update visuals without inventory scans.
- FOOD/DRINK use manual left-button release. Out-of-combat PreClick checks live health/mana, active recovery, current count/cooldown/usability, movement, mount, form and cast state, then prepares a secure macro. The macro retains explicit combat/mount/flying/channel guards if attributes freeze. No direct item-use API is invoked from addon events or timers. Repeated same-role clicks within 0.8 seconds are suppressed pending the aura, but a failed attempt is not treated as proof of eating and does not lock the button indefinitely.
- Existing localized Food/Drink auras drive EATING / DRINKING / EAT + DRINK guidance; Well Fed is not recovery. Water can be started while eating and vice versa if that other resource needs recovery. Full resource, an active same-role aura, movement, mount, death, casting/channeling, Druid form and combat prevent a wasteful recovery click. Warrior/Rogue DRINK is N/A; Druid mana is explicitly read as power type 0, including in forms, but leaving form remains manual.
- At HP <=85%, usable food takes precedence over out-of-combat bandage/potion highlights. Mana <60% can highlight water. A real ongoing recovery prevents replacement-heal suggestions. Food/water never count as emergency healing stock and are never chosen as combat consumables.
- The Advisor clears its spell recommendation during actual out-of-combat recovery, regardless of target or the pre-pull-warning toggle. It resumes when the aura disappears or the corresponding resources are full, without waiting out the aura duration. Combat immediately ignores stale food/drink auras and preserves emergency policy. The diagnostic pixel remains passive, black during the no-spell recovery state; no encoding or action slot is added.

## Review/refinement passes

1. Checked assignment/visibility/scale, original button identities, release-edge input, active-buff and full-resource guards, simultaneous food/water, empty-slot clearing, deferred combat updates and unchanged emergency stock. Expanded the harness from source-string checks to instantiate the real strip with protected-attribute assertions.
2. Cross-checked the bounded catalogue and discovered the distinction between recovery tier and cooked-food use level (e.g. Succulent Pork Ribs at level 10). Removed the incorrect tier-level eligibility prefilter. Checked malformed metadata/resource rejection, the 85% highlight boundary, recovery completion/interruption, localized legacy/structured auras and emergency preemption with stale food/drink buffs.

## Automated validation

- 52/52 addon Lua chunks parse with Lua 5.1.
- 34/34 Lua harnesses pass; the new recovery harness contains 192 focused checks, plus API-contract assertions and catalogue/layout invariants.
- 53/53 TOC references resolve (52 Lua and Bindings.xml); the working-tree package allowlist contains 57 files.
- 19/19 offline Python release-pipeline tests pass; no upload or publication is performed by this check.
- Existing all-class rotation, tuning, range, aura, threat, bag-delete and saved-option tests remain green. Root/package documentation is kept identical.
- Run `./tests/run.ps1` and `python -B -m unittest discover -s tests -p test_release_pipeline.py` before publication.

## In-game regression checklist

1. With ordinary food and water in bags, open the normal HUD. Verify six non-overlapping buttons at 0.7/1/1.6 HUD scales; the Profession Coach must still anchor below the strip. Existing visibility and position settings should work after reload.
2. Below full HP, left-click FOOD once. Verify one item consumed, EAT/EATING feedback and no new pull suggestion. Repeated clicks during the aura must not consume more food. Repeat for DRINK below full mana.
3. With both resources low, start food then water using two manual clicks. Verify both auras, EAT + DRINK, independent quantities and no premature spell/pull cue. The existing resource bars show progress.
4. Stand/move to interrupt recovery; confirm the normal Advisor resumes. Let recovery finish: full resources should release the hold even if an aura remains. Full-health/full-mana clicks should not consume stock.
5. Verify no food/water use in combat, during another cast/channel, while mounted or moving. Check a Druid in form and a Warrior/Rogue with water in bags. Do not initiate a risky Hardcore fight solely to test an edge case.
6. Use the last item, buy a stronger tier or receive conjured equivalents; selection should refresh outside combat, prefer conjured only at equal tier, and clear a missing assignment. Test low-level cooked food and reload with existing options.
7. Check `/hcob consumables` and `/hcob errors`. Neither should introduce binding changes, external-reader input or telemetry upload.

The mocks inspect secure configuration but cannot reproduce the client's exact PreClick/secure-action ordering or every localized/UI interaction. No automatic purchases, conjuring, movement, target changes or food use are introduced; unsupported special food remains manually usable from the bags.

## Data/API references

- [Blizzard Item API signatures](https://github.com/Gethe/wow-ui-source/blob/classic/Interface/AddOns/Blizzard_APIDocumentationGenerated/ItemDocumentation.lua): live item metadata remains authoritative.
- [Food aura 433](https://classicdb.ch/?spell=433), [Drink aura 430](https://classicdb.ch/?spell=430): localized aura identities, not the unrelated Well Fed buff.
- [Classic item dataset](https://github.com/nexus-devs/wow-classic-items): cross-check of catalogue identities, ordinary recovery tiers and earlier cooked-food requirements. The dataset spans expansion data; no numeric healing/mana amount is copied into the runtime or claimed as a measurement.

Only small ID/tier facts are embedded. No external service, parser, addon or network access is required in game.
