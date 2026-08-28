# Changelog

This file records the HCOneButton release history. The current feature reference, installation instructions and command documentation live in [`README.md`](README.md).

The current release is `1.27.8`, targeting WoW Classic Era / Hardcore interface `11509`.

## 1.27.8 — 2026-08-27

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

### Validation

- 40/40 addon Lua chunks and all six regression harnesses parse with Lua 5.1.5.
- 41/41 TOC references resolve with no duplicates.
- Automated regression coverage verifies transient/sustained recommendation swaps, danger bypass, invalid-action replacement, global-cooldown stability, localized-name recovery from incomplete rank-1 bounds, explicit ranged BASE ready/out states, Warlock combat-gated pet attack, and exclusion of friendly/melee actions.
- Binding-save regression coverage verifies account/character sets, temporary `0`/`nil`/invalid values, numeric-string compatibility and contained API failures.
- SavedVariables lifecycle coverage exercises `ADDON_LOADED`, the direct `PLAYER_LOGIN` fallback, persistent-table identity, defaults, repairs and login hooks.
- Class-contract coverage loads all nine modules and validates BASE macro construction, ranged/hybrid BASE classification and the Warrior/Warlock secure-macro safety invariants.
- Action Panel layout coverage validates stable per-class slot counts, known/unique spell IDs, unique default keys, the 20-slot ceiling and Diagnostic Pixel V3 encodability.
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
