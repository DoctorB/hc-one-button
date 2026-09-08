# Rogue leveling baseline — 1.29.5 release review

Scope: version 1.29.5, leveling with the character's actual learned abilities and invested talents, including level 10's first point. The user has reported a successful in-game smoke test; local release preparation does not confirm publication. No SavedVariables schema, fixed action slot, binding or protocol change is required.

## Evidence and first review

The supplied 1.29.4 Rogue sample contained 60 fights (41 grouped, 19 solo), 206 Sinister Strike casts, 47 Slice and Dice casts, 16 Eviscerate casts and one Gouge. Forty-five Slice and Dice casts spent one combo point. Six confirmed Sinister Strike actions were attributed while Eviscerate was recommended. These counts do not establish the optimal rotation or a counterfactual DPS gain.

The original resource Gouge branch required energy <=25 and client usability despite its 45-energy cost. Unknown TTK admitted Slice and Dice, normal finishers waited for four CP or two CP at <=22% target HP, and builders disappeared at <=20% target HP. The scorer also used a 40-energy builder gate and dominant-tree checks rather than all learned active talents.

Implementation now reads individual talent ranks with localized-name matching and event invalidation. Client costs take precedence over Classic fallback values. Improved Eviscerate adjusts heuristic spending windows; no exact damage/armor/crit prediction is claimed. Improved Slice and Dice affects small-CP useful duration; Improved Gouge affects proactive eligibility and the fallback control duration. Existing client usability, live health/TTK and learned active abilities reflect other build effects; this is not an exhaustive talent simulator.

## Refinement review

- Retain emergency HP and multi-attacker priority above the Rogue control hold. Clear a normal old action immediately through the existing caution priority; all other classes retain their normal routing.
- Use a 0.20-second cast-to-aura bridge, actual remaining aura duration, an 80-energy release and a bounded fallback. Do not invent a full stun after a miss or keep a hold across target changes.
- Known Gouge range failures override the coarser melee-proximity estimate. Proactive pooling needs a solo NPC attacking the player, sufficient target life and no known Rogue bleed/Deadly Poison. Interrupt fallback also needs a target attacking the player; no general positional API is assumed.
- Preserve credible lifetime decisions when Combat logger is OFF using one ephemeral target-health trend. Reset on healing, target change and combat end; do not save GUIDs/trend state to SavedVariables.
- Preserve rank-free localized secure casts and the existing 17 Rogue slots. No new position-dependent Ambush/Backstab suggestions or external reader code are introduced.
- Distinguish an actual energy wait from an otherwise unusable ability. Retain the caution warning while allowing useful offensive actions during a moderate trend.
- Limit the expanded HP-percentage finishing shortcuts to normal NPCs no more than one level above the character. Elites, higher-level enemies and players retain the old finishing fallback or need credible short remaining lifetime, rather than treating the same percentage as the same amount of health.

## Manual restart follow-up

- Read the actual melee attack toggle (`IsCurrentSpell(6603)`, with `C_Spell.IsCurrentSpell` fallback); only an explicit readable false can request a restart. Do not infer this state from swing timing. Unknown or failed reads suppress the hint.
- Only offer `ATTACK STOPPED / PRESS BASE ONCE` after the scorer finds no available action, on a live hostile target already engaged and confirmed within the learned builder's melee range. Preserve stealth, cast/channel recovery and Gouge/Blind/Sap from any source. This is HUD-only guidance with a nil spell, no highlighted slot and a black pixel.
- Resolve the real WoW BASE binding (for example BUTTON4), or show `CLICK BASE ONCE` when unbound. Withdraw the restart hint without the normal 0.20s display-swap delay when the next recommendation differs. Keep energy/requirement waits visible instead of falling through to `SPAM`.
- The human-facing cue fills the existing Advisor area (282x82), with a 26-point outlined input label (fitted down for long bindings), `ATTACK STOPPED` heading and `ONCE TO RESUME ATTACK` footer. The 3-pixel amber border pulses over 1.4 seconds, while text/background remain readable. Parenting to the Advisor inherits scale/position/visibility and leaves BASE, HP/resources, DPS and the diagnostic pixel untouched. No mouse input is intercepted. Cast/control waits, normal spell suggestions and danger/interrupt states hide the notice.
- No protected macro, saved setting or pixel slot is changed by this follow-up. Existing SS/Hemorrhage slots remain player-operated through their secure buttons or bindings; the restart notice uses the BASE binding configured in WoW.
- A native `READY_CHECK` cue (fallback `ALARM_CLOCK_WARNING_3`) accompanies a newly displayed notice, once per appearance and no more often than every five seconds. It uses the shared **Alert sounds** setting and Master channel; danger/interrupt timers remain independent. There is no spoken/hardcoded button name, repeated loop, new asset or SavedVariables field. Muted/hidden notices remain silent, and audio API failures cannot disable the visual HUD.

## Automated verification

Final release checks: 47/47 addon Lua files parse, 30/30 Lua regression harnesses pass (110 Rogue checks and 78 restart HUD/audio checks), 48/48 TOC references resolve, and 19/19 offline release-tool tests pass. Root/package README, CHANGELOG and LICENSE match. Shared regression coverage includes all nine classes. No in-game result is inferred from these tests.

Run `./tests/run.ps1`. The dedicated `tests/rogue_leveling.lua` loads the real Rogue scorer, spell helpers, macro builder, Advisor engine and final tuning policy against deterministic client mocks. It covers costs at 0/1/2 invested points, talent invalidation, localized higher-rank recognition/trainer upgrades, mixed-tree active talents, levels 1 through 60, short-fight CP decisions, maintained Slice and Dice, logger-independent lifetime, Gouge damage/target/range guards, missed/broken/expired control, immediate display clearing, emergencies and adverse tuning biases. Shared aura maintenance coverage uses a credible long-fight/small-CP fixture.

The full suite also covers other class contracts, aura policies, cast holds, stable displays, pixel edges, secure bindings, adaptive evidence and package metadata parity. These are offline state tests, not in-game combat measurements.

The restart extension tests real Rogue/engine transitions (stopped/active, affordable next spell, energy pooling, range unknown/out, control grace, channel/cast, danger and failed/unreadable APIs). `tests/advisor_input_hints.lua` loads the real HUD and diagnostic pixel: changed/missing binding labels, single-press/energy-wait text, black restart state, unchanged SS/Hemorrhage slots and preserved Hunter/Warrior input modes.

Large-cue regressions cover label size/long-key fitting, opaque high-contrast display, non-overlapping text geometry, slow border-only pulse/reset, frame parenting/input passthrough, hidden HUD/Advisor, and replacement by recovery/emergency/normal action states. The real Core HUD scale test verifies inherited scaling at 0.7, 1.0 and 1.6. The user-reported in-game result is recorded below; it does not establish live coverage at every scale.

The same real engine/HUD test exercises sound on first appearance (including session time zero), repeated refreshes, binding changes, five-second throttle boundaries, long-lived notices, mute/unmute, independent danger/interrupt throttles, hidden/control/recovery states, missing APIs/kits, fallback sound and caught playback failures.

## In-game smoke test and regression checklist

On 2026-09-07, after the prepared build was handed over for in-game verification, the user reported: "ok tutto a posto". Record this as a successful user-reported smoke test of `1.29.5`, not confirmation that every scenario below was exercised or a measured DPS/TTK improvement. No runtime code or version changed after that result; only validation documentation and local artifacts were refreshed. Keep the checklist for future regressions. The ordinary one-press pull example assumes the Rogue is not already in Stealth; BASE does not break it and a stealth opener has its own requirements.

1. On the level 15/16 Rogue, record short solo fights with similar mobs/equipment. Check earlier 2/3-CP Eviscerate, continued builder availability at low target HP and absence of automatic first-CP Slice and Dice on an unknown/short lifetime.
2. Check actual talent ranks, especially Improved Sinister Strike at one/two points. Train a new spell rank or change a talent: costs/eligibility must update without a custom rank-bound macro or resetting tuning.
3. On a longer target, confirm Slice and Dice appears only when its small-CP duration and remaining energy justify it, and disappears while the buff is active. Repeat with Combat logger OFF.
4. Gouge a single attacker with energy below 80. Confirm immediate `GOUGE - RECOVER`, cleared highlight and black pixel, then normal guidance on aura break/expiry or 80 energy. Test a missed Gouge and a target change. Bandaging remains governed by the existing real channel hold.
5. Check Kick cooldown fallback, poor range, bleed-covered targets, healthy two-target pulls, dangerous multi-pulls and low player HP. Real danger must remain visible and actionable.
6. Compare like-for-like solo TTK, damage taken and surviving HP; do not mix grouped and solo DPS as a performance verdict. No numerical DPS improvement is established until measured.
7. Without an independent mouse BASE loop, Gouge and let the control end while energy is low. If auto-attack remains stopped, confirm a prominent amber `ATTACK STOPPED / PRESS BUTTON4 / ONCE TO RESUME ATTACK` notice (actual bound key), visible without inspecting the pixel. Check readability at HUD scales 0.7/1.0/1.6, a slow border-only pulse and no overlap with BASE/HP/energy/DPS. The pixel stays black with no highlighted spell. Press once: the notice must disappear at the next HUD refresh. It must not appear during Gouge/bandaging, with no live target, out of melee range, or merely because a swing is slow. An affordable next offensive spell must take precedence. Check an alternate/long BASE binding, the unbound `CLICK BASE` fallback, and toggling HUD/Advisor visibility.

8. Enable **Alert sounds** and trigger the restart notice: hear one distinct cue, then silence while the notice stays visible. Rapid stop/resume sequences must sound at most once per five seconds. Disable **Alert sounds** and repeat: visual guidance remains, sound is muted. Confirm the choice survives reload and existing danger/interrupt sounds still work when enabled. Actual volume/audibility requires this client check.

## Player input and passive diagnostics

The secure BASE macro cannot be rewritten or conditionally disabled in combat based on Lua combo points or auras. The addon only provides recommendations; protected actions require player input. Respect the displayed control/recovery pause: another manual attack can break Gouge or spend energy before a finisher. The diagnostic pixel is for passive observation only. The 1.29.5 smoke-test report is not exhaustive live coverage; the newer review is in `ROGUE_1296_REVIEW.md`.
