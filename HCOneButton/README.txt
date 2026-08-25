HC ONE BUTTON v1.27.0 - FEEDBACK & TELEMETRY RELEASE
=====================================================

RELEASE GOAL
- Turn real in-game testing into structured, copy/paste-ready CurseForge issue reports without requiring users to browse the WTF/SavedVariables folder.
- Keep combat behavior stable: class modules, Fixed Action Panel layouts, default bindings and Diagnostic Pixel Protocol V3 are unchanged from v1.26.1.
- Keep feedback telemetry non-critical: a report/trace failure must never disable the secure button or alter an Advisor recommendation.

REPORT A PROBLEM WINDOW
- Added a "Report a problem..." button to /hcob options.
- Added /hcob report and /hcob feedback aliases to open the same window directly.
- The window explains the complete workflow: reproduce the issue, generate a report, select it, press Ctrl+C, open the HCOneButton CurseForge Issues page, create an issue and paste the report.
- CurseForge Issues URL is displayed in a selectable field: https://www.curseforge.com/wow/addons/hconebutton/issues
- "Generate Last Fight" creates the preferred compact bug report for a single suspicious combat.
- "Generate Recent Fights" includes the latest three fights, or up to five when Detailed telemetry is enabled.
- "Detailed telemetry" adds the complete stored Advisor trace, top candidate scores and ability telemetry.
- The report generator deliberately omits character name/realm, target names/GUIDs, zone/subzone and equipment item IDs.
- WoW addons cannot place arbitrary text directly on the operating-system clipboard or reliably open a browser, so the UI selects the report/URL and instructs the user to press Ctrl+C.

ADVISOR TRACE / TELEMETRY 1.27
- Combat fight schema is now 11 and the combat-log database schema is 10.
- Each fight stores a compact, change-only Advisor trace capped at 32 recommendation changes to keep SavedVariables bounded.
- A trace entry can contain elapsed fight time, deterministic slot, recommendation title/kind/reason, player HP, target HP when readable, active enemy count and Survival Reserve.
- When rolling dynamics are valid, the trace also records TTK, TTD and confidence.
- When the recommendation came directly from class candidate scoring, the top three candidate names/slots/scores are stored for tuning analysis.
- Recommendation trace recording is protected with pcall and runtime fail-safe logging; feedback telemetry cannot become a new Smart HUD failure path.
- Stale rolling dynamics are explicitly cleared when the dynamics engine resets, preventing an old target's TTK/TTD from leaking into a later diagnostic trace.

COMMANDS / COMPATIBILITY
- /hcob log export now opens the report window for the last fight.
- /hcob log export recent opens the recent-fights report.
- /hcob log export raw preserves the old SavedVariables workflow for advanced debugging.
- Existing combat history remains readable; fights recorded before 1.27.0 simply show that an Advisor recommendation trace is unavailable.
- The combat logger remains optional and bounded by the existing /hcob log max setting.

REGRESSION GUARANTEES
- All nine Classes/*.lua files are byte-identical to v1.26.1.
- UI/ActionPanel.lua, UI/DiagnosticPixel.lua, Systems/Bindings.lua, Bindings.xml and Data/Spells.lua are byte-identical to v1.26.1.
- No Fixed Action Panel slot was added, removed or renumbered.
- Default slot bindings are unchanged.
- Diagnostic Pixel Protocol V3 remains R = slot * 12, G = 96, B = 224.
- No AddCandidate score, class rotation, secure Action Panel macro or class survival/interrupt policy is intentionally changed by this release.

VALIDATION COMPLETED FOR 1.27.0
- 39/39 Lua chunks parse with a real Lua compiler.
- All 40 TOC references exist (39 Lua + Bindings.xml).
- Feedback report formatter unit test passes for last-fight and recent-fights output.
- Detailed recent-fights output is capped by the built-in 18,000-character report limit and truncates cleanly when necessary.
- Feedback UI construction/open/generate smoke test passes with the report and URL fields present.
- All 9 Classes/*.lua files plus ActionPanel.lua, DiagnosticPixel.lua, Systems/Bindings.lua, Bindings.xml and Data/Spells.lua are byte-identical to v1.26.1.
- Telemetry trace recording is isolated behind pcall so diagnostic collection cannot directly become a Smart HUD failure path.
- Combat-log fight schema 11 / database schema 10 are present and older fights remain reportable without a trace.

RELEASE 1.27.0 - 2026-08-25
----------------------------
- Added in-game CurseForge-ready feedback/report workflow.
- Added anonymized last-fight/recent-fights report generation and detailed telemetry mode.
- Added compact per-fight Advisor recommendation trace and top-candidate snapshots.
- Preserved raw SavedVariables export as /hcob log export raw.
- Updated README.txt and README.md for the new tester/issue workflow.


HC ONE BUTTON v1.26.1 - FULL CLASS STABILITY REVIEW
====================================================

RELEASE STATUS
- Stability release on top of v1.26.0 after a full architecture/runtime review.
- No Fixed Action Panel slot, default binding, Diagnostic Pixel V3, scoring weight or AddCandidate definition was intentionally changed.
- Warrior, Hunter, Mage, Warlock, Priest, Rogue, Paladin and Shaman are byte-identical to v1.26.0.
- Druid keeps the exact same 20-slot mapping and Advisor candidate set; this patch hardens form detection and secure modifier behavior.

DRUID FORM / MACRO HARDENING
- Removed runtime dependence on numeric GetShapeshiftForm() stance indexes. Druid combat logic now uses stable shapeshift-form IDs when available, with a resource-type fallback that still distinguishes Cat (Energy) from Bear/Dire Bear (Rage).
- Explicitly treats Classic Dire Bear form as Bear for Survival Reserve, Frenzied Regeneration, Feral Charge/Bash interrupt and Bear/Cat transition decisions.
- Removed hard-coded [form:1] / [form:3] conditions from Druid class macros.
- ALT mobility now discovers Cat's actual stance-bar index from GetNumShapeshiftForms()/GetShapeshiftFormInfo(): Dash is used in Cat and Travel Form outside Cat without assuming a fixed Cat slot.
- CTRL+SHIFT interrupt macro now contains Feral Charge followed by Bash, so Bash remains a valid fallback when Charge is known but cannot be used for the current range/cooldown situation.
- Feral and caster openers now work when entering combat from another non-Bear/non-Cat form instead of assuming caster form index zero only.
- Core now listens to both UPDATE_SHAPESHIFT_FORM (current form changed) and UPDATE_SHAPESHIFT_FORMS (available form set changed), rebuilding secure macros only when out of combat through the existing BuildMacros guard.

REVIEW / REGRESSION AUDIT
- 37/37 Lua chunks parse with a real Lua compiler.
- All 38 TOC references exist (37 Lua + Bindings.xml) and exact TOC-order loading succeeds.
- PLAYER_LOGIN and primary class contracts pass for all 9 classes.
- Fault-injection/inaccessible-value tests pass for all 9 classes.
- Secure-lockdown test confirms main macros, Action Panel configuration and slot bindings remain unchanged while InCombatLockdown() is true.
- Generated main/modifier/Action Panel macros stay within the 255-character macrotext limit in the test harness.
- All class Action Panels remain within 20 slots and contain no duplicate spell IDs.
- Druid has zero unmapped concrete Advisor actions and passes 13 dedicated scenarios, including Cat/Bear logic, Dire Bear interrupt behavior and Cat stance-index changes.
- Private cross-file environment audit reports 125 unique shared functions with no duplicate definitions.
- No missing S.* spell constants, no Core/Runtime.lua and no class decision chains reintroduced into Core/Advisor.
- ActionPanel.lua, DiagnosticPixel.lua, Bindings.xml and Systems/Bindings.lua are byte-identical to v1.26.0.
- Diagnostic Pixel Protocol V3 remains R = slot * 12, G = 96, B = 224.

RELEASE 1.26.1 - 2026-08-25
----------------------------
- Completed the post-Druid full stability review and promoted this build as the development baseline.
- Corrected Druid form/index assumptions and modifier fallback behavior discovered by the review.
- Added the plural shapeshift-list update event so secure Druid macros rebuild after the available form set changes.
- Corrected internal documentation around defensive inaccessible-value guards: Secret Values are currently documented as disabled on Classic clients; the guards remain transparent defense-in-depth.
- Updated README with all substantial review findings and validation results.


HC ONE BUTTON v1.26.0 - DRUID ADVISOR 2.0 / FULL CLASS PARITY
===============================================================

RELEASE GOAL
- Migrate Druid from the final legacy recommendation path to the same Advisor Engine 2.0 design standard used by the other eight classes.
- Preserve all 14 existing Druid Fixed Action Panel slots exactly and use only the six previously unused slots 15-20 for new Advisor-visible actions.
- Keep the other eight class implementations unchanged from v1.25.0; no rotation retuning outside Druid is part of this release.
- With this release all 9 classes use scored Advisor candidates, shared hysteresis, class-owned survival/interrupt contracts and deterministic panel mapping.

DRUID ADVISOR 2.0
- Replaced the old form-based legacy if/return recommendation path with scored candidates using HP, mana, current form resource, combo points, Survival Reserve, TTK/TTD, target durability, target pressure and active-enemy count.
- Feral: Cat Form is the normal efficient solo opener; Bear Form becomes a deliberate safety transition when HP/reserve collapses.
- Cat: Faerie Fire (Feral) is treated as a free long-target setup; Rake and Rip are gated by expected target lifetime; Ferocious Bite is a true cash-out/finisher instead of automatically beating Rip at 5 combo points; Claw avoids Energy capping.
- Bear: Maul is a rage-surplus spender, Faerie Fire (Feral) remains free setup, and Frenzied Regeneration becomes a high-priority emergency conversion of Rage into health.
- Balance/Restoration caster form: Moonfire and Wrath are mana/reserve-aware, Entangling Roots is preferred when melee pressure needs to be reset, and Healing Touch is recommended only when the cast window is plausibly safe.
- Healing Touch Fixed Action Panel macro cancels form before self-casting. Druid Roots/Nature's Grasp panel actions also cancel form first, avoiding recommendations that would otherwise fail only because Cat/Bear Form is still active.
- Added a Druid-specific Survival Reserve model that values Bear armor, available Barkskin/Nature's Grasp, Cat Dash and Bear Frenzied Regeneration instead of using the generic fallback.
- Added Druid-specific caution, panic and multi-pull policies: Nature's Grasp/root one target, Bear for armor, Barkskin before collapse, Dash/Travel for escape, and no attempt to damage-race large accidental pulls.
- Interrupt contract now correctly offers Feral Charge/Bash only while in Bear Form, matching their usable form requirement.

FIXED ACTION PANEL - APPEND ONLY
- Existing Druid slots 01-14 are byte-order identical to v1.25.0.
- SLOT 15 = Cat Form
- SLOT 16 = Bear Form
- SLOT 17 = Rip
- SLOT 18 = Faerie Fire (Feral)
- SLOT 19 = Healing Touch
- SLOT 20 = Frenzied Regeneration
- Every concrete Druid spell that can be returned by Advisor, caution, panic, multi-pull, interrupt or buff logic maps to one of the 20 deterministic slots.
- Default physical bindings are unchanged and Diagnostic Pixel Protocol V3 is unchanged: R = slot * 12, G = 96, B = 224.

CLASSIC HARDCORE DESIGN NOTES
- Current Classic leveling guidance continues to favor Cat Form for efficient solo single-target leveling and Bear Form for tanking/survival, with Faerie Fire (Feral) as a free armor debuff/pull tool.
- Hardcore guidance emphasizes controlling accidental multi-pulls with Entangling Roots/Nature's Grasp, using Bear/Bash/Frenzied Regeneration to survive pressure, and using movement tools such as Dash/Travel Form to disengage rather than attempting to race unsafe pulls.
- HCOneButton remains an advisor only: protected actions still require explicit player input through fixed secure buttons/bindings.

VALIDATION COMPLETED FOR THIS RELEASE
- 37/37 Lua chunks parse independently with a real Lua parser/compiler.
- All 38 TOC references exist (37 Lua + Bindings.xml).
- Exact TOC-order load, PLAYER_LOGIN and primary class contracts pass for all 9 classes.
- Fault-injection/inaccessible-value smoke test passes for all 9 classes.
- Dedicated Druid Advisor scenarios pass: Feral Cat opener, long-target Rip, low-target Ferocious Bite, emergency Bear transition, Bear Frenzied Regeneration, Balance melee Root, Balance ranged Moonfire, Restoration safe Healing Touch, Bear interrupt and 3+ mob Nature's Grasp.
- Druid recommendation-to-slot audit reports zero unmapped concrete actions and exactly 20 fixed Druid slots.
- Warrior, Hunter, Mage, Warlock, Priest, Rogue, Paladin and Shaman class files are byte-identical to v1.25.0.
- v1.25.0 Druid slot 01-14 ordering is preserved exactly; only slots 15-20 are appended.
- Default slot-key table is byte-equivalent to v1.25.0 and UI/DiagnosticPixel.lua is byte-identical.


HC ONE BUTTON v1.25.0 - CLASS PARITY / HARDCORE ADVISOR PASS
===========================================================

RELEASE GOAL
- Bring Warrior, Mage, Warlock, Priest, Rogue, Paladin and Shaman to the same design standard as Hunter: each class now reasons about opener, resource economy, survival reserve, control, finisher, long-fight value, spec/talent direction and multi-pull risk.
- Druid intentionally remains the only legacy Advisor class and is not changed in this release.
- Existing Fixed Action Panel slots are never renumbered. New actions are append-only, so the Diagnostic Pixel V3 slot protocol remains deterministic.

CLASS PARITY CHANGES
- Warrior: Advisor-visible Charge opener, proactive Retaliation on deteriorating hard fights, single-target Whirlwind fallback, and a more accurate Rend 36-45 long-fight gate.
- Mage: Clearcasting consumption, safe in-combat Evocation window, Arcane Missiles/Scorch/core-nuke candidates, improved spec-aware mana economy, while preserving the existing Nova/Blink/Barrier/Block control model.
- Warlock: pre-pull Life Tap, Soul Shard reserve-aware Drain Soul, stronger pet-threat/wand conservation behavior and spec-aware Shadow Bolt filler without weakening the existing Nightfall/DoT/Drain/Death Coil safety model.
- Priest: explicit Holy/Discipline Smite filler, stronger Spirit Tap + wand cadence, and refined mana-aware filler selection on top of Shield/heal/Scream/Fade logic.
- Rogue: reactive Riposte, energy pooling through Gouge, Blind/Sprint reset layers, Blade Flurry gating, spec-aware builders and tighter combo-point/finisher economics.
- Paladin: durable-target Seal of the Crusader -> Judgement setup, stronger seal/judgement mana economy and conservative Consecration use while preserving healing/bubble/LoH priority.
- Shaman: group-aware weapon-imbue supervision (Rockbiter solo; Windfury in groups when known), ranged Lightning Bolt opener/filler, shared-Shock cooldown reservation for interrupts, Chain Lightning gating and the existing Stoneclaw/Earthbind/Ghost Wolf escape model.

FIXED ACTION PANEL APPEND-ONLY SLOTS
- Warrior: Charge appended after the existing 18 slots.
- Mage: Arcane Missiles appended after the existing 18 slots.
- Rogue: Riposte appended after the existing 16 slots.
- Shaman: Rockbiter Weapon and Windfury Weapon appended after the existing 13 slots.
- No pre-existing class slot moved or changed meaning. Default physical bindings and Diagnostic Pixel V3 RGB formula are unchanged.

DESIGN REFERENCES
- Classic Hardcore Warrior leveling emphasizes Charge, Battle Shout, Overpower, Rend into the mid-levels, Sunder windows, Mortal Strike/Whirlwind and conservative Heroic Strike usage.
- Classic Hardcore Mage leveling emphasizes Frostbolt efficiency, Nova/kiting, wand finishing, Evocation and conservative Mana Shield use.
- Classic Hardcore Priest/Warlock/Rogue/Paladin/Shaman leveling guidance was used to tune resource conservation and safety decisions; HCOneButton remains an advisor, never an automation layer.

HC ONE BUTTON v1.24.1 - REFACTOR STABILITY REVIEW
=================================================

RELEASE STATUS
- Final stability patch on top of the v1.24.0 deep architecture refactor.
- No intentional rotation-score, Fixed Action Panel slot, default binding or Diagnostic Pixel V3 protocol changes.
- This release supersedes v1.24.0 as the recommended development baseline.

STABILITY / REGRESSION FIXES
- Fixed Hunter/Pet.lua and Hunter/Ammo.lua chunk-local namespace ownership: each chunk now declares its own HCOB.Hunter alias.
  Lua locals never cross file/chunk boundaries, so the old code could fail at load time when H.* functions were defined.
- Fixed Priest.lua and Warlock.lua private-environment consistency. Both now use HCOneButton.Internal like the other seven class modules,
  so shared helpers used by survival/macro contracts resolve reliably.
- Fixed Systems/CombatLog.lua Mage melee-state reference: it now addresses HCOB.Classes.MAGE instead of a local alias owned by Mage.lua.
- Fixed ClearCombatLog() SavedVariable identity. The persistent HCOB_CombatLog table is cleared in place instead of being replaced only
  inside the private environment; /reload/logout now persists the cleared history correctly.
- Fixed stale Fixed Action Panel bindings for inactive slots. Account-wide slot bindings belonging exactly to an inactive HCOB slot are
  released safely; keys rebound by the user to any other action are never touched.
- Added defense-in-depth combat-lock protection to generic secure macro attribute application.

CLASS-AGNOSTIC OWNERSHIP CLEANUP
- Removed the class fallback-spec table from Core state. Each Classes/<Class>.lua now owns Class.fallbackSpec.
- Moved Paladin seal selection out of Core/Utils.lua into Classes/Paladin.lua.
- Moved Warlock pet-spell detection out of Core/Utils.lua into Classes/Warlock.lua.
- Core/Advisor therefore remain free of these class-specific policy helpers.

CLASSIC ERA / HARDCORE 1.15.9 API HARDENING
- Patch 1.15.9 uses the newer shared WoW UI/API surface (TOC 11509), while Blizzard currently documents the Secret Values security system
  itself as disabled on Classic clients. The addon therefore does not rely on secret-value behavior being active in normal Classic play.
- Added centralized defensive access guards (canaccessvalue/issecretvalue and table equivalents when present). On Classic values that are
  normally accessible, these guards are transparent; they also make shared API reads fail safely if a future/restricted context makes a value inaccessible.
- Health, power, GUID, level, classification, aura duration/expiration, cooldown/range/threat and combat-log numeric reads are sanitized
  before arithmetic, comparison, tostring or table-key use. Older Classic branches without these helper APIs keep normal behavior.
- If essential live combat HP/power/target data ever becomes inaccessible, the smart Advisor pauses and reports DATA LIMITED / BASE SPAM ONLY
  instead of calculating from fabricated values or throwing Lua errors. Secure player input remains unchanged.
- Combat telemetry fails closed: inaccessible numeric payloads contribute zero and inaccessible GUID/name data is ignored/sanitized rather
  than contaminating SavedVariables or enemy-tracking tables.

VALIDATION COMPLETED FOR THIS RELEASE
- 37/37 Lua chunks parse independently with a real Lua compiler/parser.
- All 37 TOC Lua files load successfully in exact TOC order in the WoW API smoke harness.
- PLAYER_LOGIN and the primary class contracts complete successfully for all 9 classes.
- Fault-injection simulation of inaccessible values completes successfully for all 9 classes; Advisor degrades to DATA LIMITED instead of erroring.
- SavedVariable identity test confirms ClearCombatLog() clears the persistent table in place.
- Binding regression test confirms stale HCOB inactive-slot bindings are removed while user-rebound keys are preserved.
- No missing TOC entry/file, no Core/Runtime.lua, no legacy subsystem aliases, and no duplicated private-environment function definitions.
- Fixed Action Panel action tables, default slot keys and Diagnostic Pixel V3 formula match the v1.23.0/v1.24.0 baselines.
- All 114 class AddCandidate calls and all 23 class /cast + /use macro command literals match v1.24.0, detecting no intentional rotation/macro drift.


HC ONE BUTTON v1.24.0 - ARCHITECTURE REFACTOR
===============================================

DEEP ARCHITECTURE REFACTOR
- Removed Core/Runtime.lua: the previous ~295 KB monolithic runtime no longer exists.
- Runtime logic is distributed across 37 real Lua files; no Classes/*.lua file is a facade.
- All 9 classes have real implementations registered under HCOB.Classes.<CLASS>.
- Core/Init.lua owns the single HCOneButton global namespace and the private
  HCOneButton.Internal environment. SavedVariables remain global only because WoW requires it.
- The shared private environment preserves cross-chunk runtime state without recreating the
  old single-chunk local-variable limit and without leaking dozens of implementation symbols to _G.
- Core/State.lua contains shared runtime state; Core/Utils.lua, SpellUtils.lua, Range.lua
  and Auras.lua contain real shared implementations.
- Core/Macros.lua now owns only generic macro helpers and secure orchestration.
  Main/modifier/base-action choices are implemented by the individual class modules.
- Core/Events.lua is class-agnostic and forwards lifecycle events to the active class through
  HandleEvent when required; Hunter-specific state is no longer hardcoded in Core.
- Advisor/Engine.lua is class-agnostic and owns scoring, hysteresis, context and candidate selection.
- Advisor/Survival.lua is class-agnostic and delegates reserve, panic and multi-pull decisions
  to the active class contract.
- Advisor/Threat.lua tracks enemies/casts/threat and delegates interrupt choice to the class.
- Advisor/Dynamics.lua owns rolling TTK/TTD, confidence and fight-trend state.
- Core/* and Advisor/* contain no `PLAYER_CLASS == ...` decision chains.
- UI/ActionPanel.lua owns slot mapping, bindings, rendering and secure configuration;
  Hunter/Mage special macro text is delegated to the corresponding class module.
- Hunter remains a dedicated subsystem: Pet.lua, Ammo.lua, Aspects.lua, PetFood.lua and
  Management.lua. Classes/Hunter.lua orchestrates those services for the Advisor.
- Systems/Bindings.lua, CombatLog.lua and ProfessionCoach.lua remain independent systems.
- UI is separated into CoreHUD.lua, Advisor.lua, ActionPanel.lua, Options.lua and DiagnosticPixel.lua.
- Static data is separated into Data/Spells.lua and Data/PetFoodDB.lua.

CLASS CONTRACT
Each Classes/<Class>.lua can implement these entry points without Core/Advisor knowing
class-specific spells or decision chains:
- GetRecommendation / GetCandidates
- GetBuffRecommendation
- GetCautionRecommendation
- GetSurvivalReserve
- GetPanicRecommendation
- GetMultiPullRecommendation
- GetInterruptRecommendation
- BuildMainMacro
- BuildModifierMacros
- GetBaseActionInfo
- HandleEvent (only when the class owns special state/events)
- BuildActionPanelMacro (only for class-specific secure macro exceptions)

1.24.0 STRUCTURE
Core/
  Init.lua, State.lua, Utils.lua, SpellUtils.lua, Range.lua, Auras.lua,
  Macros.lua, Commands.lua, Events.lua
Advisor/
  Dynamics.lua, Threat.lua, Survival.lua, Engine.lua
Classes/
  Warrior.lua, Hunter.lua, Mage.lua, Warlock.lua, Priest.lua,
  Rogue.lua, Paladin.lua, Shaman.lua, Druid.lua
Hunter/
  Pet.lua, Ammo.lua, Aspects.lua, PetFood.lua, Management.lua
UI/
  CoreHUD.lua, Advisor.lua, ActionPanel.lua, Options.lua, DiagnosticPixel.lua
Systems/
  Bindings.lua, CombatLog.lua, ProfessionCoach.lua
Data/
  Spells.lua, PetFoodDB.lua

COMPATIBILITY PRESERVED
- Fixed Action Panel class-slot mapping is unchanged from 1.23.0.
- Default slot bindings are unchanged.
- Diagnostic Pixel protocol v3 is unchanged: R=slot*12, G=96, B=224.
- SavedVariables remain HCOB_DB and HCOB_CombatLog.
- Secure macro model is unchanged: protected spell actions are never dynamically replaced in combat.
- No protected automation was added; Advisor remains read-only/recommendation only.

RELEASE 1.24.0 - 2026-08-25
----------------------------
- Completed the deep architecture refactor before adding further class features.
- Permanently removed Core/Runtime.lua.
- Removed class facades: every class now owns recommendation, safety and macro policy.
- Extracted all class main/modifier macro builders from Core.
- Extracted class-specific reserve, panic and multi-pull models from Advisor/Survival.
- Extracted class-specific interrupt selection from Advisor/Threat.
- Extracted Hunter-specific lifecycle/event state from Core/Events.
- Extracted Hunter/Mage secure macro exceptions from UI/ActionPanel.
- Removed a duplicate ClassAPI definition and localized temporary event/management state.
- Updated Hunter Management to the 1.24.0 baseline.
- Updated README with all substantial refactor changes.

HCOneButton 1.23.0 - WARLOCK / PRIEST ADVISOR REFINEMENT

HCOneButton is a WoW Classic Era / Hardcore combat assistant built around secure player input.
It provides class-aware recommendations, deterministic clickable action slots, survival-aware Advisor Engine 2.0 logic, Hunter pet management, profession coaching, combat telemetry, and passive diagnostic output.

LANGUAGE POLICY
- All addon UI text is English.
- All chat/debug/help output is English.
- All source-code comments are English.
- Embedded documentation is English.
- Author: DoctorB.

CORE HUD
- Unified BASE + Advisor Core HUD.
- Fixed Action Panel uses deterministic class layouts.
- Learned and unlearned spells never shift slot positions.
- Unlearned actions remain reserved and disabled until learned.
- Cooldown sweep, numeric cooldown text, range state, usability state, and highlighted recommendation are shown directly on action icons.

FIXED ACTION PANEL DEFAULT BINDINGS
- Slots 01-09: SHIFT+1 through SHIFT+9
- Slot 10: SHIFT+0
- Slots 11-20: CTRL+SHIFT+1 through CTRL+SHIFT+0
- Bindings can be customized from the addon options while out of combat.
- Bindings are slot-based, not spell-based, so muscle memory remains stable across levels and characters.

ADVISOR ENGINE 2.0
Full Engine 2.0 class logic:
- Warrior
- Hunter
- Mage
- Warlock
- Priest
- Rogue
- Paladin
- Shaman

Druid intentionally remains on the simpler legacy Advisor logic for now.

Engine 2.0 includes:
- Scored action candidates instead of first-match rule chains
- Recommendation hysteresis to reduce flicker
- Rolling TTK / TTD estimates
- Class-specific Survival Reserve
- Multi-pull and fight-trend warnings
- Hard priority gates for interrupts and critical survival situations

WARLOCK - REFINED IN 1.23.0
- Warlock Advisor logic now lives in Classes/Warlock.lua instead of Core/Runtime.lua.
- Detects the Nightfall / Shadow Trance proc and prioritizes the instant Shadow Bolt window.
- Survival Reserve now distinguishes pet tanking, player tanking, missing pet, and critically low pet HP.
- Curse of Weakness can replace Curse of Agony defensively when the player is taking melee pressure.
- Curse of Agony is reserved for long, stable fights where the player is not tanking the target.
- Corruption remains the primary efficient DoT and uses TTK to avoid wasting mana on short fights.
- Immolate is more conservative outside Destruction and requires safe distance/resources.
- Drain Life scales upward with player pressure, low reserve, and unstable pet state.
- Life Tap now requires safer HP/reserve, threat geometry, and TTD conditions; it is suppressed while the player is actively tanking.
- Wand finishing is favored when mana is low or the target is already near death.
- Drain Soul remains a safe low-HP execute/shard recommendation without changing fixed action slots.

PRIEST - REFINED IN 1.23.0
- Priest Advisor logic now lives in Classes/Priest.lua instead of Core/Runtime.lua.
- Pre-pull preparation now waits for long-duration self buffs before suggesting the combat opener.
- Power Word: Shield is staged as a pre-pull safety action, followed by Mind Blast for Shadow or Holy Fire for Discipline/Holy when appropriate.
- Inner Fire and Power Word: Fortitude are both supervised out of combat.
- Survival Reserve now accounts for Shield availability, Weakened Soul, Inner Fire, target pressure, healing availability, and Psychic Scream readiness.
- Fade is recommended only when grouped and the hostile target is actually on the Priest.
- Psychic Scream gains an emergency single-target control window when reserve/HP become unsafe, with an explicit nearby-pack warning.
- Healing selection continues to respect projected TTD and cast time, with Flash Heal reserved for tighter emergency windows.
- Shadow Word: Pain, Mind Blast, Mind Flay, Holy Fire, Renew and wand usage are gated by mana, TTK, distance, reserve and spec.
- Spirit Tap is detected and incorporated into wand/mana-conservation recommendations.

HUNTER
- Hybrid ranged/melee attack recovery
- Auto Shot range-aware pull state and auto-repeat state tracking
- Accurate live multi-aggro tracking based on real combat exchanges
- Per-target chain-pull timing and rolling TTK/TTD state
- Serpent Sting live range/usability/cooldown validation
- Range-safe Scatter Shot and Concussive Shot recommendations
- Melee finisher logic for Raptor Strike plus reactive Mongoose Bite
- Freezing Trap pre-pull guidance for dangerous targets
- Auto Shot weaving-aware recommendations
- Pet health, threat, Mend Pet, Feign Death and smart pet feeding
- Pet food selection based on diet, level usefulness, bag contents and food priority


HUNTER MANAGEMENT
- Predictive pet threat state: STABLE / RISING / UNSTABLE / LOST
- High player threat suppresses burst recommendations before aggro actually flips
- Ammo logistics for bows/crossbows/guns with remaining-shot and estimated-time warnings
- Pet training-point supervision and Growl/autocast checks
- Pet skill inventory for Growl, Bite, Claw, Dash and Dive
- /hcob hunter      full Hunter management status
- /hcob ammo        ammo status
- /hcob petskills   pet skill/training status

PROFESSION COACH
- Event-driven; no profession scanning in the combat update loop
- Detects learned Classic professions
- First Aid 1-300 route with cloth requirements and training gates
- Crafting recommendation based on recipe difficulty, reagent availability and estimated material value
- Gathering route guidance for Herbalism, Mining and Skinning
- Fishing and Cooking guidance
- The coach only recommends actions; it does not craft, gather, buy, or use items automatically

DIAGNOSTIC PIXEL PROTOCOL V3
- Passive RGB protocol that encodes only the currently recommended fixed Action Panel slot
- Black: no recommendation
- White: unmapped recommendation
- Fixed slot color: R = slot * 12, G = 96, B = 224
- External readers do not need to know class or spell names

IMPORTANT COMMANDS
/hcob
/hcob status
/hcob plan
/hcob options
/hcob actions on|off
/hcob actions scale <value>
/hcob actions binds
/hcob advisor debug
/hcob petfood
/hcob prof
/hcob prof on|off
/hcob prof refresh
/hcob log last
/hcob log summary
/hcob errors
/hcob bind <KEY>
/hcob unbind <KEY>
/hcob bindtest [KEY]
/hcob diagpixel on|off

SECURE GAMEPLAY MODEL
HCOneButton never dynamically replaces a protected spell action during combat. Fixed Action Panel buttons are configured securely out of combat, and the Advisor only changes visual recommendations during combat. The player remains responsible for the input that executes protected gameplay actions.

RELEASE 1.23.0 - 2026-08-25
----------------------------
Architecture / maintainability:
- Promoted the architecture working build into a release baseline.
- The addon uses one HCOneButton namespace with Core/Data/Advisor/Classes/Hunter/UI/Systems modules.
- Core/Init.lua remains the only namespace/bootstrap owner.
- Static spell IDs live in Data/Spells.lua and pet-food data lives in Data/PetFoodDB.lua.
- HunterManagement and ProfessionCoach remain isolated in their subsystem directories.
- Warlock and Priest are the first class Advisor implementations physically extracted from Core/Runtime.lua into Classes/Warlock.lua and Classes/Priest.lua.
- Added a shared class context generated by Advisor Engine with player, target, combat, TTK/TTD, reserve and pet state.
- Added a small Core.ClassAPI bridge for rank-safe spell/aura/usability helpers while the remaining classes are migrated.
- Existing compatibility aliases remain available during the incremental refactor.

Gameplay logic:
- Refined Warlock and Priest Advisor Engine 2.0 behavior as documented in their class sections above.
- Added Shadow Trance (Nightfall proc aura) and Spirit Tap aura tracking.
- Warlock Survival Reserve is now pet/threat-state aware.
- Priest buff supervision now includes Inner Fire as well as Power Word: Fortitude.
- Replaced the remaining legacy Italian combat-log clear message with English output.

Compatibility / protocol guarantees:
- Fixed Action Panel spell ordering is unchanged for every class.
- Existing Warlock and Priest slot numbers are unchanged.
- Default slot bindings are unchanged.
- Diagnostic Pixel Protocol V3 is unchanged: black = none, white = unmapped, fixed slot RGB = (slot*12, 96, 224).
- No protected action is automatically executed; all recommendations still require player input.

Version:
- Release version: 1.23.0.

