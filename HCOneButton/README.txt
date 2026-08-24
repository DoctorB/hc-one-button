HCOneButton 1.21.5 - ENGLISH-ONLY LOCALIZATION

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
- Slots 11-18: CTRL+SHIFT+1 through CTRL+SHIFT+8
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

HUNTER
- Hybrid ranged/melee attack recovery
- Auto Shot range-aware pull state
- Accurate live multi-aggro tracking based on real combat exchanges
- Serpent Sting live range/usability validation
- Auto Shot weaving-aware recommendations
- Pet health, threat, Mend Pet, Feign Death and smart pet feeding
- Pet food selection based on diet, level usefulness, bag contents and food priority

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
