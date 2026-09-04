# Changelog

This file records the HCOneButton release history. The current feature reference, installation instructions and command documentation live in [`README.md`](README.md).

The current release is `1.29.2`, targeting WoW Classic Era / Hardcore interface `11509`.

## 1.29.2 — 2026-09-04

### Changed — Learning that can change a real choice

- Replaced usage-only priority correlations with local comparisons between confirmed, simultaneously available actions. Safe proc, buff, resource, mitigation, form/aspect and recovery/control opportunities can participate across all nine classes; mandatory emergencies, interrupts and the existing cast/range/aura/swing rules remain protected.
- Separate comparisons by target count, current resource band and finishing phase. Require four chosen and four alternative-choice fights per situation, an eight-fight context, a minimum effect and variability discount before applying quarter-point corrections up to `±12`.
- Evaluate effective damage after overkill, health floor and Rage/Energy cap waste. A materially worse health floor vetoes positive preference. These are observational associations, not a promise or measurement of DPS improvement; there is no random exploration.
- Safe multi-pull/pre-escape spell routes now expose eligible alternatives while preserving their original cold/OFF baseline. No spell is made usable, in range or refreshable by learning.
- Confirmed player alternatives are no longer discarded just for disagreeing with the Advisor. Preserve pending evidence through cast holds; reject stale/changed-target/emergency windows and deduplicate identical spell roles and cast events.

### Changed — Visible evidence and actual impact

- The inspector retains all recorded situations and observed fixed/zero-bias spells, explains protection, shows chosen/alternative counts and uses `−12…+12` bars. Target selection never hides situations.
- Show how many displayed choices differed from the same evaluation's baseline and how many were executed. Reader refreshes are not additional decisions; the display explicitly distinguishes observed impact from a measured DPS gain.
- Preserve local observations, context isolation, ON/OFF and viewing preferences. Previous coefficients are not enlarged or applied without new comparative evidence.

### Fixed — Final review

- Preserve confirmed safe recovery-cast evidence through the dedicated recovery hold, without changing HUD/pixel suppression or permitting another cast.
- Treat unreadable pet HP as unavailable instead of trusting the fallback 100%; Mend Pet retains protected priority. Normalize numeric safety inputs before comparisons.

### Release

- Aligned TOC, runtime/fallback version and documentation to `1.29.2`. Learner revision `3`, adaptive schema `2`, additive telemetry contract `1`; combat-log schemas, secure actions and Diagnostic Pixel Protocol V3 are unchanged.
- Prepared the Classic Era addon ZIP and standalone CurseForge release notes. No SavedVariables reset is required.

### Validation

- Two review/refinement cycles cover all-class decision changes, real Warrior candidate/aura gates, multi-pull routing, emergency/pet protection, cast attribution, data robustness, migration and inspector layout mocks.
- Final automated checks: 46/46 Lua files parse, 25/25 regression harnesses pass, 47/47 TOC references resolve, and root/package documentation matches.
- The new situational UI and behavior still need in-game smoke testing before publication. Automated decision changes do not establish a real-world DPS benefit.

## 1.29.1 — 2026-09-04

### Fixed — Reliable Adaptive Tuning profiles

- The visual inspector and `/hcob tuning status` now resolve the same current-build profile. The command no longer reports corrections from the last learned build while the window displays another context.
- Added explicit `Normal (PvE)` / `PvP` viewing tabs, persisted per character. Target selection never switches profiles, and viewing preferences never alter gameplay. PvP learning remains unsupported and is clearly labeled; its tab never substitutes PvE evidence.
- The inspector refreshes automatically while open, independently of chat notifications. Learned actions at the baseline remain visible with `Active only` off; automatic refresh respects the two-step reset warning and expires it safely.
- Removed the exact level from talent-layout identity so unchanged talents/spells retain their learning inside the same five-level band. Compatible existing `1.29.0` profiles are recovered automatically and re-keyed on the next eligible learning update without resetting counters, repeating announcements or merging independent histories.
- Genuine talent/spellbook, level-band or solo/group changes still use separate contexts. Empty current contexts explicitly explain recalibration and preservation of other saved evidence.
- Friendly heals, friendly buff/debuff applications and unrelated nearby players no longer contaminate PvE combat telemetry as PvP. Actual player/pet PvP damage/misses, hostile control and explicit PvP instances remain excluded; a real PvP transition also stops cached PvE corrections immediately.
- Malformed saved action collections now fail closed in the inspector, status command and bias lookup, instead of causing errors before the next eligible fight can repair the store.

### Changed — Clearer Options and tuning explanations

- Added a persistent on-screen legend above the tuning spell list: left/negative lowers offensive priority, center/zero preserves the baseline and right/positive raises offensive priority. The explanation distinguishes score points from damage percentages and keeps safety rules explicit.
- Grouped smart pre-pull Rend, situational Sunder and the Heroic Strike Rage threshold in a dedicated `Warrior - Combat policy` section, visible only to Warrior characters. Combat logger, Mini DPS meter and Local Adaptive Tuning now sit together in `Combat data and learning`.
- Repositioned utility buttons within the existing Options window size, preserving the separate binding controls and footer. Existing saved values, defaults, callbacks and managed-window navigation are unchanged.
- Aligned TOC, normal/fallback runtime version and current documentation to `1.29.1`. Learner revision is now `2`; adaptive schema `2`, combat-log/fight schemas, secure actions and Diagnostic Pixel Protocol V3 remain unchanged.

### Validation

- 46/46 addon Lua chunks parse with Lua 5.1.5; all 24/24 regression harnesses pass through `tests/run.ps1`, and 47/47 TOC references resolve without duplicates.
- Added integration regressions using the real telemetry/learner modules for target changes, leveling, legacy migration, explicit profile persistence, all nine classes and inspector/status consistency.
- Extended panel tests cover live updates, zero-bias row retention, tab switching, reset-confirmation expiry and combat closure; combat-event tests distinguish friendly/bystander activity from real PvP.
- Options layout tests instantiate all nine classes, verify Warrior-only grouping, moved-control persistence/reload, slider-label clearance and CTA/footer separation; inspector tests also check the baseline legend and reserved layout space.
- The Options and tuning-inspector layout passed the user's in-game visual check.

## 1.29.0 — 2026-09-03

### Added — Local Adaptive Tuning

- HCOneButton can now learn locally from the active character's eligible combat history and apply small, evidence-based corrections to offensive Advisor candidate scores across all nine supported classes.
- Learning is zero-configuration and enabled automatically when the old `1.28.6` placeholder store upgrades. `/hcob tuning on|off|status|reset` and the new Options checkbox provide direct control; disabling preserves learned data, while reset clears only the active character's learner state.
- Each learning context separates class, specialization, five-level band, solo/group mode, talent layout and learned spellbook. Target difficulty is normalized through independent easy/even/hard/elite performance baselines so trivial mobs are not compared directly with dangerous targets.
- A context calibrates for at least eight eligible fights, and an individual action needs at least four observed outcomes from accepted recommendations or eligible alternatives actually used by the player before it can influence a priority. Repeated deviations contribute at most one outcome per action and fight. The status command reports calibration progress, learned actions and active adjustments.
- The learner combines relative DPS performance with the fight's surviving HP floor, continuously updates its rolling evidence and can move an adjustment back toward zero as later results change.
- Adjustments are hard-clamped to `±4` Advisor score points and rounded to quarter-point steps. This is enough to resolve close offensive choices without replacing the underlying class rotation.
- Only offensive tags such as damage, DoT, finisher, AoE, burst, efficiency, sustained damage, weapon weaving and setup are tunable. Healing, survival, control, interrupts, escape logic, buffs, forms and other Hardcore safety decisions remain outside the learner.
- A protected winner lock disables offensive bias whenever the deterministic base policy has already selected healing, survival, control, interrupt or another non-tunable priority.
- Active learned corrections are disclosed in the Advisor reason as `Local tuning +N.NN`; calibration completion and the first active adjustment are announced once per context.
- Options now includes `View learned adjustments...`, a visual inspector for the live class/build context with calibration progress, spell icons, accepted/alternative evidence and centered `−4…+4` correction bars. An `Active only` filter, protected-baseline explanation and two-step per-character reset make every learned change inspectable and reversible without editing SavedVariables.
- The inspector is a managed child window: it replaces Options while open, returns through Back, the standard X or Escape, and closes without restoring Options if combat begins.
- Fixed the Options footer layout so the `Configure slot bindings...` CTA no longer overlaps explanatory text; the copy now sits below both columns and correctly distinguishes account-wide settings from per-character Adaptive Tuning data.

### Safety and privacy

- Short, incomplete, PvP, death, context-changing, uncorrelated and very-low-adherence fights are rejected before learning.
- All state remains inside the per-character `HCOB_CharacterDB`; no combat log, identity or gameplay data is uploaded, and no external executable or account is required.
- Context and action stores are bounded, old contexts are evicted deterministically, malformed SavedVariables are clamped at runtime, and a manual reset provides immediate rollback.
- Local Adaptive Tuning changes recommendations only. WoW's secure-action model and the requirement for a player key press/click are unchanged.

### Validation

- 46/46 addon Lua chunks parse with Lua 5.1.5.
- All twenty-one regression harnesses pass through `tests/run.ps1`; 47/47 TOC references resolve without duplicates.
- New deterministic coverage verifies calibration gates, per-action evidence gates, accepted and player-alternative outcomes, live-context visual-model isolation, active-only filtering, Window Manager parent navigation, combat refusal, difficulty baselines, positive/negative learning, hard bias clamps, protected-winner locking, candidate-selection integration, visible explanations, disabled behavior, ineligible-fight rejection, migration, explicit opt-out and Options ON/OFF persistence across reloads, status and reset.

## 1.28.6 — 2026-09-03

### Coming next — HCOneButton learns from the way you fight

> **The next major HCOneButton feature is Local Adaptive Tuning:** an Advisor that will use your own completed combat sessions to become progressively better suited to your character, build and real gameplay—without uploading combat logs, installing an external program or sending personal data anywhere.

Version `1.28.6` builds the complete data foundation for this next step across **all nine supported classes**. The upcoming learner will be able to compare the recommendation shown, the other valid choices available at that moment, the action actually performed and the resulting combat state. This will allow HCOneButton to refine bounded class thresholds and priorities from evidence gathered during normal play instead of relying on a single static profile for every character.

The goal is a more personal Advisor that understands differences between characters, talent builds, equipment and resource patterns while preserving HCOneButton's Hardcore-first safety rules. Learning will remain local and per character, with unsuitable fights filtered out and explicit safeguards preventing a bad session from freely rewriting the rotation.

**Nothing is auto-tuned in `1.28.6` yet.** This release installs and validates the privacy-safe telemetry contract required to deliver the feature without another disruptive combat-log migration when Local Adaptive Tuning is activated in an upcoming release.

### Fixed

- The compact DPS HUD no longer calculates `LAST` or `AVG` values from another class or character on the same account.
- `/hcob log last` and `/hcob log stats` now select only the active character's compatible fights instead of aggregating the latest account-wide entries indiscriminately.
- Last/recent diagnostic reports no longer include fights recorded by another character.
- Two characters of the same class are isolated for every newly recorded fight; class alone is no longer treated as character identity.

### Added

- Added adaptive telemetry contract `1` for all nine supported classes. Every new fight records an anonymous build/policy context, the stabilized Advisor decisions, all eligible candidate alternatives and scores, player inputs, confirmed actions, reaction time and recommendation adherence.
- Resource sampling is now class-neutral and form-aware: active resource types are kept in separate buckets while hidden mana, combo points, player/target health, enemy pressure and pet health remain available to future class tuners.
- Candidate metadata and generic counter/distribution extension points let any class expose a future tuning threshold without changing the combat-log schema again. Warrior Heroic Strike/Cleave currently attach their base/effective Rage thresholds, Execute-pooling state and swing timing through this common contract.
- Each completed fight receives explicit safety, DPS and adaptive eligibility flags. Short, incomplete, PvP, death, context-changing, uncorrelated and very-low-adherence samples are marked so a future learner cannot silently train on unsuitable data.
- `HCOB_CharacterDB.adaptive` is initialized as a versioned per-character context store with automatic tuning disabled. This release collects the required evidence but does not alter Advisor priorities or player settings.

### Changed

- New fight schema `13` and combat-log schema `12` retain the random local profile identifier supplied by the per-character `HCOB_CharacterDB` and add the bounded adaptive telemetry contract. Identifiers and build hashes are omitted from sanitized diagnostic reports.
- Existing pre-`1.28.6` fights remain visible through a class-only compatibility fallback because their originating character cannot be reconstructed retroactively.
- `/hcob log max N` is now a per-character retention quota. The account-wide store has a final hard ceiling of 600 fights so alt histories remain useful without allowing unbounded SavedVariables growth.
- `/hcob log clear` removes only the active character's compatible records. `/hcob log clear all` explicitly resets the complete account-wide store.
- `/hcob log session NAME` now stores a per-character session label. Existing custom account session text is adopted when a character profile is initialized.
- `/hcob log` status reports the active-character count separately from total account storage.

### Compatibility

- Existing `HCOB_DB` settings and `HCOB_CombatLog` history are preserved in place. The additive `HCOB_CharacterDB.adaptive` store is repaired safely and remains disabled until the complete local learner, controls and rollback policy are released.
- Advisor priorities, Warrior swing/Execute/Cleave behavior, deterministic Action Panel slots/default bindings, secure macros and Diagnostic Pixel Protocol V3 encoding are unchanged.
- Raw combat-log export remains account-wide; normal last/recent exports are character-scoped and continue to omit character identity, target identity, zone and equipment IDs.

### Validation

- 44/44 addon Lua chunks parse with Lua 5.1.5.
- All eighteen regression harnesses pass through `tests/run.ps1`; 45/45 TOC references resolve without duplicates.
- New coverage verifies different-class and same-class-alt isolation, legacy fallback, current-version DPS selection, chronological last/recent selection, per-character quotas, scoped clearing, explicit account clearing and account/per-character SavedVariables rebinding.
- Adaptive-contract coverage verifies anonymous context/policy snapshots, candidate alternatives, recommendation/action correlation, reaction and adherence metrics, bounded traces, resource-mode separation, generic class extensions, eligibility filters and PvP exclusion.

## 1.28.5 — 2026-09-03

### Fixed

- Warrior Heroic Strike is no longer requested throughout an entire slow weapon swing. The Advisor exposes it only near the next main-hand attack and suppresses it as soon as the client reports the strike already queued.
- Heroic Strike and Cleave damage or miss events now reset the tracked main-hand swing timer just like a white hit or miss. A consumed queued strike therefore starts a fresh timing cycle instead of leaving Heroic Strike permanently eligible.
- An acknowledged on-next-swing queue bypasses normal display swap confirmation, immediately clearing the obsolete recommendation and Diagnostic Pixel request for a 50 Hz external reader.
- Healthy controlled two-target pulls no longer remain permanently on a non-action `PREPARE ESCAPE` state after defensive setup. They yield to the normal Mortal Strike, Bloodthirst and Whirlwind scorer; low HP, low Survival Reserve and 3+ enemy pressure retain escape priority.
- Thunder Clap and Demoralizing Shout are no longer repeatedly requested while their target debuff is healthy. They become refreshable only in their final `3` seconds.
- Retaliation, Pummel and Shield Bash recommendations now require actual usability, preventing dead instructions in the wrong stance or without the required equipment.

### Changed

- The Heroic Strike queue window scales with current main-hand speed and is clamped to `0.45–0.65` seconds. Normal `0.20`-second recommendation confirmation leaves a short, stable reader-visible input window without occupying the complete swing.
- Queue-safe `!Heroic Strike` and `!Cleave` macros prevent duplicate key samples from toggling an already armed strike back off.
- When Execute is learned, queued Rage dumps pause between `21%` and `30%` target HP. `POOL FOR EXECUTE` keeps auto attacks running and releases spending at `85` Rage to avoid wasting generation near the cap; efficient core strikes remain available.
- Cleave now occupies the appended deterministic Warrior slot 20 (`CTRL+SHIFT+0`) and is preferred over Heroic Strike as the queued dump when at least two enemies are actively engaged. Existing Warrior slots 1–19 do not move.

### Compatibility

- `/hcob hsrage` retains its persistent `20`–`70` range. Execute pooling and Cleave apply bounded overrides without changing the stored setting.
- SavedVariables and existing Action Panel slots/default bindings are unchanged. Cleave uses the previously empty Warrior slot 20 and its existing default `CTRL+SHIFT+0` binding.
- Diagnostic Pixel Protocol V3 encoding is unchanged; Cleave uses the already-defined slot-20 color `#F060E0`.
- The `1.28.4` combat-only aura policy and all earlier cast-timing, range, consumable and survival behavior remain compatible.

### Validation

- 43/43 addon Lua chunks parse with Lua 5.1.5.
- All sixteen regression harnesses pass through `tests/run.ps1`; 44/44 TOC references resolve without duplicates.
- New coverage verifies the adaptive swing window, queued Heroic Strike/Cleave suppression, special hit/miss timer reset, first-swing fallback, immediate display acknowledgement, Execute pooling/release boundaries, slot-20 Cleave priority and queue-safe macros.
- Multi-pull coverage verifies defensive-debuff refresh boundaries, healthy x2 return to the core DPS scorer, low-reserve escape preservation and stance/equipment-aware Retaliation and interrupt selection.

## 1.28.4 — 2026-09-02

### Fixed

- Maintained self auras no longer generate idle/out-of-combat Advisor and Diagnostic Pixel requests. Battle Shout, long class buffs, Paladin seals, Hunter aspects and Shaman weapon imbues now remain manual outside combat.
- Active auras no longer re-enter the combat rotation because of a short Classic `UNIT_AURA` miss. A bounded shared observation cache keeps a previously confirmed player or pet aura stable for the API race without hiding a genuine removal.
- A successful aura refresh now overrides the stale near-expiry aura frame that can remain visible immediately after the cast, preventing the same refresh from being requested again.
- Mage Mana Shield, Priest Power Word: Shield/Renew, Rogue Slice and Dice and Hunter Mend Pet now explicitly suppress recommendations while their aura is already active.

### Changed

- Missing maintenance auras are handled in combat by their class policy. Healthy active auras are ignored; finite long buffs become refreshable only in their final `10` seconds.
- The combat-only policy covers Warrior Battle Shout; Paladin Blessing of Might and seals; Priest Inner Fire/Fortitude and protective auras; Mage armor, Arcane Intellect and shields; Warlock Demon Armor/Skin; Druid Mark of the Wild; Shaman Lightning Shield/weapon imbues; Hunter aspects/Mend Pet; and Rogue Slice and Dice.
- Paladin Crusader-seal setup now begins after combat starts on a suitable durable target instead of occupying the pre-pull reader.
- Proc auras, Stealth, Druid forms, class openers and hostile target debuffs remain contextual mechanics and are not treated as idle maintenance reminders.

### Compatibility

- SavedVariables, deterministic Action Panel slots/default bindings, secure macros and Diagnostic Pixel Protocol V3 colors are unchanged.
- The `1.28.3` Warrior Rage/escape balance and all earlier cast-timing, range, consumable and survival behavior remain compatible.

### Validation

- 43/43 addon Lua chunks parse with Lua 5.1.5.
- All fourteen regression harnesses pass through `tests/run.ps1`; 44/44 TOC references resolve without duplicates.
- New coverage verifies the combat/OOC policy and final-ten-second boundary across Paladin, Priest, Mage, Warlock, Druid, Shaman and Warrior, plus rank-safe cast acknowledgement, stale refresh metadata and bounded player/pet aura debouncing.

## 1.28.3 — 2026-09-01

### Fixed

- Warrior preventive escape guidance no longer preempts the complete damage rotation indefinitely and leaves generated Rage unused. Once Rage is excessive, the Advisor recommends a high-value spender and then returns to the escape plan.
- Controlled two-target pulls can spend excess Rage after Thunder Clap and Demoralizing Shout setup instead of remaining permanently on a non-action `PREPARE ESCAPE` state.

### Changed

- The preventive escape Rage threshold starts at the greater of `40` or `/hcob hsrage + 5`. It adds a safety margin below `35` Survival Reserve and relaxes near the target's execute range.
- Excess-Rage priority is `Execute`, `Overpower`, `Mortal Strike`, `Bloodthirst`, `Whirlwind`, then `Heroic Strike`, so procs and efficient core attacks are used before a queued swing dump.
- Low-Rage caution still prepares Hamstring first. Multi-pulls at `50%` HP or lower, 3+ enemy pulls and genuine panic states continue to preempt offensive spending.

### Compatibility

- `/hcob hsrage` remains persistent and keeps its existing `20`–`70` range. No SavedVariables shape, deterministic Action Panel slot, default binding, secure macro or Diagnostic Pixel Protocol V3 color changed.
- All `1.28.2` cast-timing and Paladin survival behavior remains compatible.

### Validation

- 43/43 addon Lua chunks parse with Lua 5.1.5.
- All eleven regression harnesses pass through `tests/run.ps1`; 44/44 TOC references resolve without duplicates.
- New Warrior coverage verifies low-Rage escape priority, excess-Rage spenders, proc/core/queued-strike ordering, controlled two-target behavior and strict low-HP/3+ enemy panic preemption.

## 1.28.2 — 2026-08-31

### Fixed

- Advisor rotation timing now follows every active player cast and channel reported by the client. Non-instant offensive spells clear the Action Panel highlight and Diagnostic Pixel just like healing casts, and the next recommendation appears only after completion or interruption.
- Paladin Divine Shield is no longer the unconditional first response to every global danger state. Healthy 3+ enemy warnings and moderate unfavorable-fight trends now preserve the cooldown.

### Changed

- Divine Shield remains immediate at `25%` HP or lower. From `26%` through `35%`, it requires at least two active enemies, Survival Reserve at `28` or lower, or a confident TTD estimate of `6` seconds or less.
- Lay on Hands keeps priority at `18%` HP or lower. Less severe Paladin danger states prefer Divine Protection, Hammer of Justice, a usable heal or escape guidance instead of prematurely spending Divine Shield or Lay on Hands.
- The Paladin 3+ enemy warning is now `3+ MOBS - STABILIZE`; it no longer tells the player to bubble regardless of current HP.

### Compatibility

- No deterministic Action Panel slot, default binding, secure macro, SavedVariables shape or Diagnostic Pixel Protocol V3 color changed.
- The `1.28.1` HUD-position, recovery hold and `60 ms` pixel acknowledgement fixes remain compatible.

### Validation

- 43/43 addon Lua chunks parse with Lua 5.1.5.
- All ten regression harnesses pass through `tests/run.ps1`; 44/44 TOC references resolve without duplicates.
- New Paladin policy coverage verifies the immediate and conditional Divine Shield boundaries, TTD/reserve/multi-pull pressure, Lay on Hands priority and moderate-danger fallbacks. Active-cast coverage now includes a non-instant offensive spell and post-cast rotation resumption.

## 1.28.1 — 2026-08-29

### Fixed

- HUD dragging now persists the complete anchor pair and offsets directly to the TOC-declared SavedVariables root; `/reload` restores the exact moved position instead of reinterpreting its coordinates as a centered anchor.
- While the player is channeling (including a bandage) or casting a helpful spell in combat, the Advisor displays `LET IT FINISH`, clears the Action Panel highlight and emits black/no-action through Diagnostic Pixel until the recovery action ends.
- After the currently encoded Advisor spell succeeds, Diagnostic Pixel emits a rank-safe `60 ms` black acknowledgement edge before the latest recommendation. A 50 Hz reader can distinguish consecutive suggestions even when they resolve to the same slot/color.

### Compatibility

- The acknowledgement edge changes only the temporal signal: Diagnostic Pixel Protocol V3 slot colors and deterministic class mappings are unchanged.
- Advisor class priorities, secure BASE/Action Panel behavior, Pre-pull Safety, Survival consumables and SavedVariables from `1.28.0` remain compatible.

### Validation

- 43/43 addon Lua chunks parse with Lua 5.1.5.
- All nine regression harnesses pass through `tests/run.ps1`; 44/44 TOC references resolve without duplicates.
- New coverage verifies global SavedVariables position rebinding with full anchors, immediate recovery/channel hold behavior, stabilization bypass to a nil pixel, rank-safe cast acknowledgement and the observable same-slot black edge at 50 Hz.

## 1.28.0 — 2026-08-28

### Added

- Added the all-class Pre-pull Safety Advisor and Recovery Gate. Before displaying `PULL READY`, it checks player HP, mana/energy where applicable, level-10+ Hunter/Warlock pet condition, and learned primary escape/control cooldowns on tough targets.
- Added explicit `RECOVER FIRST`, `PREPARE`, `HIGH RISK` and `PULL READY` states. Elite/world-boss and +3-level targets keep immediate danger priority; ranged classes still require the shared spell-range check and Hunter retains its dead-zone states.
- Added a four-slot Survival consumables strip for the best usable healing potion, Healthstone, mana potion and bandage in the player's bags.
- Added quantity, cooldown sweep/text, current usability, empty/restock state, tooltips and Advisor-driven highlighting. Out-of-combat recovery prefers a bandage; combat danger prefers Healthstone then healing potion, while critically low mana can highlight a mana potion.
- Added all standard and improved Classic Healthstone item variants, level-safe potion selection and `Recently Bandaged` awareness.
- Added persistent **Pre-pull safety gate** and **Survival consumables strip** controls to Options, plus `/hcob prep on|off` and `/hcob consumables [on|off]` commands.

### Secure-action safety

- Survival item buttons use `SecureActionButtonTemplate` and require a real player click. HCOneButton never consumes an item automatically and installs no consumable bindings.
- Best-item protected attributes are assigned only outside combat. The exact assignment remains frozen during combat lockdown even if a stack is exhausted or the bag changes.
- Counts, cooldowns, usability and highlights may update visually in combat without changing the protected action. A pending best-item assignment is applied on `PLAYER_REGEN_ENABLED`.
- Diagnostic Pixel Protocol V3 continues to encode only deterministic class spell slots; item IDs never enter the spell/slot/pixel path.

### Changed

- Melee classes now receive the same universal `PULL READY / PRESS BASE` confirmation as ranged classes once recovery checks and higher-priority class preparation are complete.
- Missing healing stock becomes `HIGH RISK` for a +1-or-harder normal target. Stocked healing tools and learned primary escape/control abilities still gate a tough pull while their cooldown is unavailable; routine equal/lower-level pulls are not blocked solely by inventory.
- `PULL READY` reasons now include available HP/mana and healing-tool readiness context.
- Profession Coach anchors below the Survival strip when it is visible and returns directly below the Action Panel when the strip is disabled.
- Bag and item-cooldown changes request Advisor refreshes for every class.

### Fixed

- Using a bandage now immediately desaturates its Survival button and displays the full `Recently Bandaged` countdown instead of making the button look ready again.
- Healing, mana potion and Healthstone cooldown feedback now reconciles both available Classic item-cooldown API paths and retains the active shared cooldown during transient ready-state updates.

### Compatibility

- Rage is not treated as a missing pre-pull resource. Energy produces only a short preparation prompt.
- Existing class scoring, secure BASE macros, deterministic Action Panel slots/bindings, recommendation stabilization, hostile-spell range handling, Warlock pet pull protection, SavedVariables repair and Doctor behavior remain intact.
- Both new options default to enabled on fresh installations and persist through `HCOB_DB`.

### Validation

- 43/43 addon Lua chunks parse with Lua 5.1.5.
- All eight regression harnesses pass through `tests/run.ps1`; 44/44 TOC references resolve without duplicates.
- New coverage verifies strongest usable item selection, improved Healthstone variants, combat/out-of-combat recovery priority, Recently Bandaged, unavailable-item highlight suppression, low HP/mana/energy and pet gates, tough-target stock/healing/escape cooldown warnings, SavedVariables defaults, secure deferred configuration and melee `PULL READY` integration.

## 1.27.8 — 2026-08-27

### Added

- Added `/hcob doctor`, a read-only live diagnostic snapshot shown in the existing Report window.
- Doctor compares the normalized BASE/range decision with raw `IsSpellInRange` and `C_Spell.IsSpellInRange` results and reports learned spell resolution, macro, cooldown/usability, unit/pet combat state, bindings, Action Panel slot, SavedVariables identity, Advisor display and fail-safe errors.
- Doctor omits character/realm and target identity, zone and equipment IDs; contained API errors are sanitized so local Lua source paths are not exported.

### Fixed

- Normal Advisor changes now require `0.20` seconds of consistent observations before replacing a still-valid action, preventing one-refresh candidate changes from flashing two different spell suggestions.
- Normal transitions from idle, buff or another action use the same confirmation path; returning to the current recommendation discards the pending change.
- Short global-cooldown windows no longer make the current recommendation look invalid and trigger a premature swap.
- Target changes clear both candidate hysteresis and display stabilization so a new target never inherits a pending recommendation from the previous one.
- Binding persistence now normalizes `GetCurrentBindingSet()` to `1` (account) or `2` (character) before calling `SaveBindings`; temporary values such as `0`, `nil` or invalid numbers fall back safely to account bindings.
- Action Panel auto-bind, legacy migration and slash-command binding paths now share the guarded save helper, preventing `PLAYER_TALENT_UPDATE` and similar refresh events from recording `Usage: SaveBindings(1|2)` errors.
- Warlock BASE no longer sends the pet while out of combat. The first successful Shadow Bolt/wand cast starts the pull, and a following BASE press sends the pet after combat begins, preventing a failed out-of-range cast from becoming a pet-led pull.

### Range and castability

- Added one rank-safe hostile-spell range query shared by Advisor, BASE, Fixed Action Panel and Hunter behavior.
- Hostile spells whose actual maximum range exceeds melee distance are checked before the Advisor presents them as executable. Friendly/self spells and melee abilities are excluded.
- An out-of-range ranged recommendation now becomes an explicit `OUT OF RANGE / MOVE CLOSER` state, is removed from the Action Panel highlight and emits no executable Diagnostic Pixel recommendation.
- Ranged BASE feedback is now available across Mage, Priest, Warlock, Hunter and caster Druid/Shaman states, as well as any other genuinely ranged hostile class action: green is ready, red is out of range, and amber is unavailable/unknown.
- Existing Hunter and Action Panel range checks now use the same shared implementation, preserving name-first higher-rank handling on Classic.
- Spell bounds and harmful classification now query the localized learned spell name before the stored rank-1 ID, avoiding false non-ranged results when Classic reports an incomplete `0` maximum range for the ID.
- Ranged class modules explicitly identify their current BASE action. Advisor and BASE therefore retain ready/out/unavailable/unknown feedback even when generic spell metadata cannot classify that rank reliably.
- With a hostile target and no higher-priority action, ranged classes now receive explicit `PULL READY`, `OUT OF RANGE`, `BASE NOT READY` or `RANGE UNKNOWN` Advisor feedback; Hunter keeps its specialized dead-zone states.

### Compatibility

- `CAUTION`, `INTERRUPT` and `DANGER` escalation still bypasses normal recommendation confirmation.
- A spent, unusable or out-of-range old action can still be replaced immediately.
- Class candidate scores and rotations, deterministic slots, bindings, SavedVariables schemas and Diagnostic Pixel Protocol V3 encoding are unchanged.
- Doctor collection does not rebuild macros, refresh protected frames, save bindings, initialize combat history or mutate SavedVariables.

### Validation

- 40/40 addon Lua chunks and all seven regression harnesses parse with Lua 5.1.5.
- 41/41 TOC references resolve with no duplicates.
- Automated regression coverage verifies transient/sustained recommendation swaps, danger bypass, invalid-action replacement, global-cooldown stability, localized-name recovery from incomplete rank-1 bounds, explicit ranged BASE ready/out states, Warlock combat-gated pet attack, and exclusion of friendly/melee actions.
- Binding-save regression coverage verifies account/character sets, temporary `0`/`nil`/invalid values, numeric-string compatibility and contained API failures.
- SavedVariables lifecycle coverage exercises `ADDON_LOADED`, the direct `PLAYER_LOGIN` fallback, persistent-table identity, defaults, repairs and login hooks.
- Class-contract coverage loads all nine modules and validates BASE macro construction, ranged/hybrid BASE classification and the Warrior/Warlock secure-macro safety invariants.
- Action Panel layout coverage validates stable per-class slot counts, known/unique spell IDs, unique default keys, the 20-slot ceiling and Diagnostic Pixel V3 encodability.
- Doctor regression coverage validates report fields, raw range API failure containment, slash dispatch, local-path sanitization, privacy exclusions and SavedVariables immutability.
- Manifest coverage validates TOC order/references, version parity and synchronization of repository/package documentation and license text; `tests/run.ps1` provides the single local entry point.

## 1.27.7 — 2026-08-26

### Fixed

- Fixed SavedVariables initialization order: `HCOB_DB` and `HCOB_CombatLog` are now rebound from the real TOC-declared globals when `ADDON_LOADED` fires.
- Defaults, shape validation and one-shot migrations now run only after that rebind, so persistent settings are written to the table WoW actually serializes.
- Hunter management defaults now use the same post-`ADDON_LOADED` initialization path instead of writing into the temporary bootstrap database.
- HUD position is explicitly restored from the persistent database at `PLAYER_LOGIN`; the pre-login secure frame now uses literal bootstrap coordinates until SavedVariables are available.
- Added a `PLAYER_LOGIN` fallback for test harnesses/unusual load paths that omit `ADDON_LOADED`.
- Fixes settings such as HUD scale reverting after `/reload` even though other UI changes appeared to work during the current session.

### Compatibility

- Existing valid `HCOB_DB` and `HCOB_CombatLog` contents are preserved.
- Malformed-root repair from 1.27.6 remains active, but is now performed at the correct SavedVariables lifecycle point.
- Advisor scores, class rotations, deterministic Action Panel slots, bindings and Diagnostic Pixel Protocol V3 are unchanged.

### Validation

- 40/40 Lua chunks pass syntax parsing in the current validation environment.
- 41/41 TOC references resolve with no duplicates.
- Lifecycle simulation preserves existing scale, Profession Coach state, HUD position and Action Panel scale while adding only missing defaults.
- Advisor, Classes, Data, ActionPanel, Bindings and Diagnostic Pixel behavior files are unchanged from 1.27.6.

## 1.27.6 — 2026-08-26

### Fixed

- Standardized the remaining mixed Italian/English user-facing strings in Options, Profession Coach, combat-log output and binding help.
- HUD scale changes deferred by combat lockdown now report when they are queued, canceled or applied.
- Visual refreshes with an unchanged scale no longer create a false pending scale update.
- SavedVariables roots and essential nested structures are validated before use. Invalid settings, binding maps and combat-log containers are repaired instead of causing startup/runtime errors.
- Invalid combat-log entries are discarded individually while valid fight records are preserved.

### Changed

- Auto-bind now reports existing WoW/addon bindings that it replaces, with a compact conflict summary and instructions for reviewing or disabling automatic reapplication.
- Options, the binding editor and `/hcob bind` now show explicit overwrite warnings.
- SavedVariables repairs are summarized once at login.

### Documentation

- Moved historical release notes out of the README and into this changelog.
- Added README navigation, an explicit all-class support summary and operational external-reader instructions for Diagnostic Pixel Protocol V3.
- Removed the duplicate plaintext release-history file.
- Included the MIT license in the distributable addon directory so packaged documentation links remain valid.

### Compatibility

- Fresh installations still enable Action Panel auto-bind and apply the deterministic class binding set during `PLAYER_LOGIN`.
- Advisor scores, class rotations, deterministic slots, configured slot meanings and Diagnostic Pixel Protocol V3 are unchanged.

### Validation

- 40/40 Lua chunks parse with Lua 5.1.5.
- 41/41 TOC references resolve with no duplicate entry.
- A malformed-SavedVariables recovery test passes for invalid roots, settings, binding maps, fight lists, counters and session values.

## 1.27.5 — 2026-08-26

### Changed

- Confirmed that the dedicated Options panel persists user preferences in `HCOB_DB`.
- Added a persistent **Profession Coach** checkbox to Options.
- `/hcob prof on|off` now controls the same setting.
- Disabling the coach hides its panel and suspends profession refreshes and scans.
- **Reset defaults** re-enables Profession Coach.

### Compatibility

- Advisor scores, class rotations, deterministic slots, configured bindings and Diagnostic Pixel Protocol V3 are unchanged.

## 1.27.4 — 2026-08-26

### Added

- Added `UI/WindowManager.lua` to keep Options, binding configuration and feedback/report dialogs from stacking.
- Child dialogs opened from Options now return to Options when closed, including through the standard frame close button.

### Changed

- Primary HUD scale now applies to BASE, CoreShell, Advisor, DPS meter, Fixed Action Panel and Profession Coach.
- `/hcob actions scale` remains a relative Action Panel multiplier on top of the primary HUD scale.
- Reset defaults now resets both scale values.
- Diagnostic Pixel remains excluded from HUD scaling. The source renders an 8×8 sampling frame; Protocol V3 continues to define only its RGB encoding.

### Validation

- 40/40 Lua chunks parsed.
- 41/41 TOC references resolved.
- Managed-window navigation and HUD-scale propagation checks passed.
- Class, Advisor, Hunter, data, binding and diagnostic protocol behavior remained unchanged from `1.27.3`.

## 1.27.3 — 2026-08-25

### Changed

- Added event-driven Advisor refreshes for important player, target, pet, aura, resource, cooldown, form and hostile-cast changes.
- Coalesced event bursts behind a 35 ms minimum refresh interval.
- Reduced the fallback heartbeat to 120 ms in combat and 300 ms out of combat.
- Reduced normal recommendation hold from 280 ms to 120 ms.
- Reduced previous-candidate hysteresis from +7 for 1.25 s to +4 for 0.65 s.
- Kept rolling TTK/TTD and combat telemetry heartbeat-sampled so event-heavy classes do not bias percentages.

### Compatibility

- Class scores, spell priorities, slots, bindings, secure actions and Diagnostic Pixel Protocol V3 are unchanged.
- Interrupt, caution and danger states continue to bypass normal-action stabilization.

## 1.27.2 — 2026-08-25

### Changed

- Made the CoreShell border alert-only.
- Normal, pull, modifier, automatic and buff states now keep the outer border transparent.
- Caution remains amber and danger/critical remains red.

### Compatibility

- Advisor logic, class rotations, slots, bindings, telemetry and Diagnostic Pixel Protocol V3 are unchanged.

## 1.27.1 — 2026-08-25

### Changed

- Reduced the Fixed Action Panel to a maximum 10-column × 2-row layout with 32 px buttons.
- Added an explicit Profession Coach combat latch covering `PLAYER_REGEN_DISABLED` through `PLAYER_REGEN_ENABLED`.
- Prevented queued coach refresh timers from reopening its panel during combat.
- Reduced the out-of-combat Profession Coach panel height.

### Compatibility

- Deterministic slot numbering, bindings, Advisor scores and Diagnostic Pixel Protocol V3 are unchanged.

## 1.27.0 — 2026-08-25

### Added

- Added the **Report a problem...** workflow to Options.
- Added `/hcob report` and `/hcob feedback`.
- Added selectable CurseForge issue URL and last-fight/recent-fights report generation.
- Added optional detailed telemetry and a change-only Advisor trace capped at 32 entries per fight.
- Trace entries can include deterministic slot, reason, HP, target HP, enemy count, Survival Reserve, TTK/TTD confidence and top candidate scores.

### Changed

- `/hcob log export` opens the report window.
- `/hcob log export recent` opens a recent-fights report.
- `/hcob log export raw` preserves the original SavedVariables workflow.
- Combat fight schema moved to 11 and combat-log database schema to 10.

### Privacy and safety

- Generated reports omit character name/realm, target names/GUIDs, zone/subzone and equipment item IDs.
- Trace recording is isolated behind protected calls and cannot directly disable the Smart HUD.
- Report output is capped at 18,000 characters.

### Validation

- 39/39 Lua chunks parsed and 40/40 TOC references resolved for the release baseline.
- Feedback formatter and UI construction/generation checks passed.
- Class layouts, default bindings and Diagnostic Pixel Protocol V3 remained unchanged from `1.26.1`.

## 1.26.1 — 2026-08-25

### Fixed

- Hardened Druid form detection by using stable form IDs with resource-type fallback.
- Treated Dire Bear as Bear for survival, Frenzied Regeneration and interrupt decisions.
- Removed hard-coded Druid stance indexes from secure macros.
- Made Cat mobility discover the real Cat stance index.
- Added Bash as the secure fallback after Feral Charge.
- Added `UPDATE_SHAPESHIFT_FORMS` handling so macros rebuild when the available form set changes.

### Validation

- 37/37 Lua chunks parsed and 38/38 TOC references resolved.
- All nine class login/contracts, macro-length checks and secure-lockdown checks passed.
- All Action Panel layouts remained within 20 slots and contained no duplicate spell IDs.

## 1.26.0

### Added

- Migrated Druid to Advisor Engine 2.0, completing scored Advisor coverage for all nine classes.
- Added Druid-specific Survival Reserve, caution, panic, multi-pull and interrupt policies.
- Added Cat Form, Bear Form, Rip, Faerie Fire (Feral), Healing Touch and Frenzied Regeneration in previously unused slots 15–20.

### Changed

- Added form-safe macros for Healing Touch, Roots and Nature's Grasp.
- Added form/resource-aware Feral, Bear and caster recommendations.

### Compatibility

- Existing Druid slots 01–14, all other class files, default bindings and Diagnostic Pixel Protocol V3 remained unchanged.

## 1.25.0

### Added

- Brought Warrior, Mage, Warlock, Priest, Rogue, Paladin and Shaman to the class-owned scored Advisor design already used by Hunter.
- Added opener, resource-economy, survival, control, finisher, long-fight and multi-pull reasoning across those classes.
- Appended Charge for Warrior, Arcane Missiles for Mage, Riposte for Rogue, and Rockbiter/Windfury Weapon for Shaman.

### Compatibility

- Existing slots retained their meaning; new actions were append-only.
- Default bindings and Diagnostic Pixel Protocol V3 remained unchanged.

## 1.24.1

### Fixed

- Corrected chunk-local Hunter namespace ownership in `Hunter/Pet.lua` and `Hunter/Ammo.lua`.
- Made Priest and Warlock private-environment usage consistent with the modular runtime.
- Corrected the Combat Log reference to the Mage class module.
- Made `ClearCombatLog()` mutate the persistent table in place.
- Released stale inactive-slot HCOB bindings without touching keys reassigned by the user.
- Added defense-in-depth combat-lock protection to generic secure macro attributes.

### Changed

- Moved remaining class-specific fallback, Paladin seal and Warlock pet helpers out of Core.
- Added defensive access guards for Classic Era API values and fail-closed `DATA LIMITED` behavior.

### Validation

- 37/37 Lua chunks parsed and loaded in TOC order.
- All class login/contracts, inaccessible-value simulations and binding/SavedVariables regression checks passed.

## 1.24.0 — 2026-08-25

### Changed

- Removed the former monolithic `Core/Runtime.lua`.
- Split runtime ownership across Core, Advisor, Classes, Hunter, UI, Systems and Data modules.
- Established `HCOneButton` as the single addon namespace with a shared private `HCOneButton.Internal` environment.
- Moved class recommendation, survival, interrupt and secure macro policy into real class modules.
- Kept Advisor responsible for shared context, scoring, hysteresis and selection.
- Isolated Hunter pet, food, ammo, aspect and management services.

### Compatibility

- Fixed Action Panel mappings, default bindings, SavedVariables, secure-input behavior and Diagnostic Pixel Protocol V3 remained compatible with `1.23.0`.

## 1.23.0 — 2026-08-25

### Added

- Established the modular release baseline.
- Extracted Warlock and Priest Advisor implementations into their class modules.
- Added a shared class context and the initial `Core.ClassAPI` bridge.
- Added Shadow Trance/Nightfall and Spirit Tap tracking.

### Changed

- Refined Warlock DoT, pet-threat, Life Tap, Drain Life, wand and Drain Soul decisions.
- Refined Priest preparation, buffs, Shield, healing, control, damage and Spirit Tap/wand decisions.
- Replaced the remaining Italian combat-log clear message with English output.

### Compatibility

- Existing class slot order, default bindings and Diagnostic Pixel Protocol V3 remained unchanged.
- All protected actions continued to require explicit player input.
