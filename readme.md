# HCOneButton

> Smart WoW Classic Hardcore combat assistant with class-aware recommendations, secure clickable actions, survival logic, pet management, profession coaching, cooldown awareness, combat telemetry and passive diagnostics.

**Current version:** `1.21.1`  
**Target client:** World of Warcraft Classic Era / Hardcore  
**Interface:** `11509`

HCOneButton is a quality-of-life combat assistant designed for WoW Classic Hardcore. It analyzes the current combat state and recommends useful actions while keeping the final gameplay input in the player's hands.

The addon combines a compact combat HUD, a class-aware Advisor, fixed secure action buttons, survival-oriented decision logic, profession guidance, Hunter pet management and detailed combat telemetry.

> **Important:** HCOneButton does **not** automatically execute the Advisor's combat decisions. Protected actions still require a player click/key press through WoW's secure action system.

---

## Features

### Unified combat HUD

The main HUD contains:

- **BASE** secure action button;
- class-aware **Advisor**;
- HP/resource/swing information;
- compact live DPS information;
- a secure **Action Panel** directly below the main HUD;
- visual states for `OK`, `CAUTION` and `DANGER`.

The HUD is draggable while unlocked and can be scaled independently from the Action Panel.

### Advisor Engine 2.0

Advisor Engine 2.0 evaluates multiple valid actions instead of simply choosing the first matching rule.

It can consider, depending on class:

- HP and class resource;
- target HP and level;
- number of enemies;
- pet status;
- cooldown availability;
- melee/ranged pressure;
- rolling estimated **TTK** (time to kill);
- rolling estimated **TTD** (time to death);
- class-specific **Survival Reserve**;
- current recommendation stability/hysteresis;
- fight duration and resource efficiency.

Current class coverage:

| Class | Advisor |
|---|---|
| Warrior | ✅ Engine 2.0 |
| Paladin | ✅ Engine 2.0 |
| Hunter | ✅ Engine 2.0 |
| Rogue | ✅ Engine 2.0 |
| Priest | ✅ Engine 2.0 |
| Mage | ✅ Engine 2.0 |
| Warlock | ✅ Engine 2.0 |
| Shaman | ✅ Engine 2.0 |
| Druid | 🔹 Base logic for now |

Emergency states such as interrupts, critical HP and dangerous multi-pulls remain hard-priority safety gates.

### Secure clickable Action Panel

The Action Panel contains fixed `SecureActionButton` slots. The Advisor highlights the recommended action, but never changes a protected action dynamically during combat.

Each icon can display:

- pulsing recommendation highlight;
- radial cooldown sweep;
- numeric cooldown for meaningful cooldowns;
- red range warning;
- desaturation when the action is not currently usable;
- tooltip information.

You can either click the highlighted icon or use its fixed keyboard binding.

### Deterministic action slots

Action slots **never compact or move because of character level or learned spells**.

For example, on Hunter:

- Slot 01 is always Hunter's Mark;
- Slot 02 is always Serpent Sting;
- Slot 03 is always Arcane Shot;
- Slot 04 is always Aimed Shot;
- etc.

If the spell has not been learned yet, the slot stays in place and remains disabled/dim. When the spell is learned, the same slot becomes active.

This guarantees stable slot → key → diagnostic-color mappings for the lifetime of the character.

### Fixed Action Panel bindings

By default, HCOneButton uses the following slot bindings. They can now be changed from **`/hcob options` → Fixed Action Panel bindings → Configure slot bindings...**. The mapping is stored per slot and is shared across classes, while each class keeps its own deterministic spell layout.

| Slot | Default binding |
|---:|---|
| 01 | `SHIFT+1` |
| 02 | `SHIFT+2` |
| 03 | `SHIFT+3` |
| 04 | `SHIFT+4` |
| 05 | `SHIFT+5` |
| 06 | `SHIFT+6` |
| 07 | `SHIFT+7` |
| 08 | `SHIFT+8` |
| 09 | `SHIFT+9` |
| 10 | `SHIFT+0` |
| 11 | `CTRL+SHIFT+1` |
| 12 | `CTRL+SHIFT+2` |
| 13 | `CTRL+SHIFT+3` |
| 14 | `CTRL+SHIFT+4` |
| 15 | `CTRL+SHIFT+5` |
| 16 | `CTRL+SHIFT+6` |
| 17 | `CTRL+SHIFT+7` |
| 18 | `CTRL+SHIFT+8` |

> **Warning:** both default and custom combinations may already be used by the WoW UI or another addon. HCOneButton can overwrite the existing binding when auto-bind is enabled. The binding editor rejects duplicate keys between HCOB slots, but it may intentionally replace a non-HCOB WoW binding. Turning auto-bind off stops HCOneButton from applying slot bindings again, but does not automatically restore bindings that were previously replaced.

In the binding editor, click a slot key and press the desired combination. `ESC` cancels capture, `DELETE`/`BACKSPACE` leaves that slot unbound, **Default** resets one slot, and **Reset all** restores the full default layout.

Use:

```text
/hcob actions binds
```

to print the current slot → key → action mapping.

---

## Class action layouts

The following layouts are deterministic. Unknown spells keep their slot.

<details>
<summary><strong>Warrior</strong></summary>

| Slot | Action |
|---:|---|
| 01 | Rend |
| 02 | Overpower |
| 03 | Execute |
| 04 | Heroic Strike |
| 05 | Sunder Armor |
| 06 | Thunder Clap |
| 07 | Demoralizing Shout |
| 08 | Battle Shout |
| 09 | Bloodrage |
| 10 | Hamstring |
| 11 | Mortal Strike |
| 12 | Bloodthirst |
| 13 | Whirlwind |
| 14 | Pummel |
| 15 | Shield Bash |
| 16 | Berserker Rage |
| 17 | Retaliation |
| 18 | Shield Wall |

</details>

<details>
<summary><strong>Paladin</strong></summary>

| Slot | Action |
|---:|---|
| 01 | Seal of Righteousness |
| 02 | Seal of Command |
| 03 | Judgement |
| 04 | Blessing of Might |
| 05 | Consecration |
| 06 | Hammer of Justice |
| 07 | Exorcism |
| 08 | Hammer of Wrath |
| 09 | Divine Protection |
| 10 | Lay on Hands |
| 11 | Holy Light |
| 12 | Flash of Light |
| 13 | Divine Shield |
| 14 | Seal of the Crusader |

</details>

<details>
<summary><strong>Hunter</strong></summary>

| Slot | Action |
|---:|---|
| 01 | Hunter's Mark |
| 02 | Serpent Sting |
| 03 | Arcane Shot |
| 04 | Aimed Shot |
| 05 | Multi-Shot |
| 06 | Concussive Shot |
| 07 | Scatter Shot |
| 08 | Wing Clip |
| 09 | Raptor Strike |
| 10 | Mongoose Bite |
| 11 | Mend Pet |
| 12 | Feed Pet |
| 13 | Feign Death |
| 14 | Intimidation |
| 15 | Bestial Wrath |
| 16 | Rapid Fire |
| 17 | Freezing Trap |
| 18 | Aspect of the Hawk |

</details>

<details>
<summary><strong>Rogue</strong></summary>

| Slot | Action |
|---:|---|
| 01 | Sinister Strike |
| 02 | Hemorrhage |
| 03 | Eviscerate |
| 04 | Gouge |
| 05 | Kick |
| 06 | Stealth |
| 07 | Sprint |
| 08 | Evasion |
| 09 | Vanish |
| 10 | Blade Flurry |
| 11 | Slice and Dice |
| 12 | Garrote |
| 13 | Cheap Shot |
| 14 | Kidney Shot |
| 15 | Blind |
| 16 | Adrenaline Rush |

</details>

<details>
<summary><strong>Priest</strong></summary>

| Slot | Action |
|---:|---|
| 01 | Shadow Word: Pain |
| 02 | Mind Blast |
| 03 | Mind Flay |
| 04 | Power Word: Shield |
| 05 | Renew |
| 06 | Psychic Scream |
| 07 | Silence |
| 08 | Fade |
| 09 | Power Word: Fortitude |
| 10 | Shoot |
| 11 | Lesser Heal |
| 12 | Heal |
| 13 | Flash Heal |
| 14 | Inner Fire |
| 15 | Holy Fire |
| 16 | Smite |

</details>

<details>
<summary><strong>Mage</strong></summary>

| Slot | Action |
|---:|---|
| 01 | Frostbolt |
| 02 | Fireball |
| 03 | Fire Blast |
| 04 | Frost Nova |
| 05 | Blink |
| 06 | Counterspell |
| 07 | Polymorph |
| 08 | Ice Barrier |
| 09 | Mana Shield |
| 10 | Ice Block |
| 11 | Cold Snap |
| 12 | Evocation |
| 13 | Pyroblast |
| 14 | Scorch |
| 15 | Cone of Cold |
| 16 | Arcane Explosion |
| 17 | Blizzard |
| 18 | Shoot |

`Frost Nova` is intentionally prepared with its explicit learned rank from the low-rank identifier used by HCOneButton for efficient control. Other normal `/cast SpellName` actions use the highest learned rank selected by the WoW client.

</details>

<details>
<summary><strong>Warlock</strong></summary>

| Slot | Action |
|---:|---|
| 01 | Corruption |
| 02 | Curse of Agony |
| 03 | Immolate |
| 04 | Shadow Bolt |
| 05 | Fear |
| 06 | Drain Life |
| 07 | Life Tap |
| 08 | Shadowburn |
| 09 | Death Coil |
| 10 | Spell Lock |
| 11 | Demon Armor |
| 12 | Demon Skin |
| 13 | Shoot |
| 14 | Drain Soul |
| 15 | Curse of Weakness |

</details>

<details>
<summary><strong>Druid</strong></summary>

| Slot | Action |
|---:|---|
| 01 | Moonfire |
| 02 | Wrath |
| 03 | Rake |
| 04 | Claw |
| 05 | Ferocious Bite |
| 06 | Maul |
| 07 | Entangling Roots |
| 08 | Feral Charge |
| 09 | Bash |
| 10 | Barkskin |
| 11 | Nature's Grasp |
| 12 | Dash |
| 13 | Travel Form |
| 14 | Mark of the Wild |

> Druid currently uses the older/base Advisor logic rather than Advisor Engine 2.0.

</details>

<details>
<summary><strong>Shaman</strong></summary>

| Slot | Action |
|---:|---|
| 01 | Flame Shock |
| 02 | Earth Shock |
| 03 | Lightning Bolt |
| 04 | Stormstrike |
| 05 | Lightning Shield |
| 06 | Earthbind Totem |
| 07 | Stoneclaw Totem |
| 08 | Healing Wave |
| 09 | Ghost Wolf |
| 10 | Frost Shock |
| 11 | Searing Totem |
| 12 | Fire Nova Totem |
| 13 | Chain Lightning |

</details>

---

## Hunter pet management

HCOneButton contains additional Hunter-specific logic for pet management.

### Smart pet feeding

The addon can:

- read pet happiness;
- read the pet's supported food categories;
- scan bags for compatible food;
- avoid quest items and blocked bag slots;
- avoid obviously poor low-level food choices;
- prefer useful/basic food before more valuable cooking materials when possible;
- avoid repeatedly consuming food while the Feed Pet effect is already active.

Use:

```text
/hcob petfood
```

to print the current pet happiness, diet and selected food.

The fixed Hunter Action Panel uses:

- Slot 11: Mend Pet;
- Slot 12: Feed Pet;
- Slot 13: Feign Death.

Feign Death's secure action also prepares pet passive/follow before the spell.

### Hunter Auto Shot philosophy

Hunter BASE is designed to **start the pull/Auto Shot**, not to spam Auto Shot continuously.

Typical flow:

1. select a target;
2. press the Hunter BASE action once to start the pull;
3. let Auto Shot continue;
4. follow the Advisor for situational abilities.

---

## Profession Coach

Profession Coach is an event-driven module and does not continuously scan professions during combat.

It detects learned Classic professions, including secondary professions such as:

- First Aid;
- Cooking;
- Fishing.

### First Aid

The coach includes an embedded 1–300 First Aid progression and can consider:

- current skill;
- cloth in bags;
- appropriate bandage tier;
- trainer/book progression gates;
- Artisan/Triage progression.

### Crafting professions

When a supported profession window is open, the coach can evaluate known recipes using:

- recipe difficulty color;
- available reagents;
- craftable quantity;
- small-batch progression.

General priority is:

```text
Orange > Yellow > Green > Grey
```

Grey recipes are not recommended for skill-ups.

The module also contains guidance for gathering professions such as Mining, Herbalism and Skinning, and progression guidance for Fishing.

Commands:

```text
/hcob prof
/hcob prof on
/hcob prof off
/hcob prof refresh
```

The Profession Coach panel is hidden automatically in combat.

---

## Installation

1. Close World of Warcraft.
2. Extract the addon so the directory is:

```text
World of Warcraft/_classic_era_/Interface/AddOns/HCOneButton/
```

3. Verify that the folder directly contains:

```text
HCOneButton.toc
HCOneButton.lua
PetFoodDB.lua
ProfessionCoach.lua
Bindings.xml
```

4. Start WoW and enable **HC One Button** in the AddOns list.
5. Enter the world and run:

```text
/hcob status
```

If upgrading from an older HCOneButton build, replace the complete addon folder. SavedVariables are stored separately and are preserved unless you delete them manually.

---

## Basic usage

### Main HCOneButton binding

Bind the main BASE secure button, for example:

```text
/hcob bind BUTTON4
```

or:

```text
/hcob bind Q
```

Check it with:

```text
/hcob bindtest BUTTON4
```

Print active HCOB keys:

```text
/hcob keys
```

Remove a specific BASE binding:

```text
/hcob unbind BUTTON4
```

### Advisor

The Advisor analyzes the current situation and highlights an action in the Action Panel when applicable.

You can execute the recommendation by:

- clicking the highlighted secure icon; or
- pressing the fixed key corresponding to that action slot.

Debug the Advisor decision engine with:

```text
/hcob advisor debug
```

This can print information such as Survival Reserve, rolling TTK/TTD and the highest-scoring candidate actions.

---

## Commands

Both aliases are supported:

```text
/hcob
/hconebutton
```

### Binding and rotation

| Command | Description |
|---|---|
| `/hcob bind KEY` | Bind the main HCOB secure button to a key/mouse button. Must be done out of combat. |
| `/hcob unbind KEY` | Remove a specific main HCOB binding. |
| `/hcob keys` | Print current HCOB bindings. |
| `/hcob bindtest [KEY]` | Verify that a key points to the HCOB secure frame. Defaults to `BUTTON4`. |
| `/hcob plan` | Print the currently generated BASE macro/rotation plan. |
| `/hcob mods` | Print the current class modifier-action descriptions. |
| `/hcob status` | Print addon/class/spec/runtime status. |

### Action Panel

| Command | Description |
|---|---|
| `/hcob actions on` | Enable the secure clickable Action Panel. |
| `/hcob actions off` | Disable the Action Panel. |
| `/hcob actions scale 1.0` | Set independent Action Panel scale (`0.8`–`1.5`). |
| `/hcob actions bind on` | Enable/reapply the configured slot bindings. |
| `/hcob actions bind off` | Stop HCOneButton from automatically applying slot bindings. Existing saved bindings are not restored automatically. |
| `/hcob actions binds` | Print slot → key → action mapping. |

### Advisor and HUD

| Command | Description |
|---|---|
| `/hcob advisor on` | Show Advisor. |
| `/hcob advisor off` | Hide Advisor. |
| `/hcob advisor debug` | Print Advisor Engine diagnostic information. |
| `/hcob smart on` | Enable Smart HUD updates. |
| `/hcob smart off` | Disable Smart HUD display logic while leaving the secure BASE button active. |
| `/hcob dps on\|off` | Show/hide compact DPS information. |
| `/hcob swing on\|off` | Show/hide swing timer. |
| `/hcob sound on\|off` | Enable/disable sound alerts. |
| `/hcob danger N` | Set danger HP threshold (`20`–`70`). |
| `/hcob critical N` | Set critical HP threshold (`10`–`40`). |

### Layout

| Command | Description |
|---|---|
| `/hcob options` | Open HCOneButton's own options window. |
| `/hcob config` | Alias for `/hcob options`. |
| `/hcob settings` | Open the Blizzard settings/category bridge. |
| `/hcob center` | Center the HUD. |
| `/hcob show` | Show HCOneButton. |
| `/hcob hide` | Hide HCOneButton. |
| `/hcob lock` | Lock HUD position. |
| `/hcob unlock` | Unlock HUD position for dragging. |
| `/hcob scale 1.0` | Set main HUD scale (`0.7`–`1.6`). Must be changed out of combat. |

### Profession Coach

| Command | Description |
|---|---|
| `/hcob prof` | Print detected professions and prioritized progression recommendations. |
| `/hcob prof on` | Enable Profession Coach. |
| `/hcob prof off` | Disable Profession Coach. |
| `/hcob prof refresh` | Force a profession/material refresh. |

### Hunter

| Command | Description |
|---|---|
| `/hcob petfood` | Print pet happiness, supported diet and currently selected compatible food. |

### Warrior-specific tuning

| Command | Description |
|---|---|
| `/hcob hsrage N` | Set Heroic Strike recommendation threshold (`20`–`70` rage). |
| `/hcob rendspam on\|off` | Enable/disable intelligent pre-pull Rend preparation. |
| `/hcob sunder on\|off` | Enable/disable Warrior base Sunder behavior where applicable. |
| `/hcob hsspam` | Compatibility command; Heroic Strike BASE spam remains intentionally disabled. |

### Combat telemetry

| Command | Description |
|---|---|
| `/hcob log` | Show logging status. |
| `/hcob log on` | Enable combat telemetry. |
| `/hcob log off` | Disable combat telemetry. |
| `/hcob log last` | Print the last recorded fight. |
| `/hcob log stats` | Print aggregate recent combat statistics. |
| `/hcob log export` | Print instructions for locating SavedVariables after `/reload`. |
| `/hcob log clear` | Clear saved fight history. |
| `/hcob log max N` | Set maximum retained fights (`10`–`200`). |
| `/hcob log session NAME` | Set/read the combat-log session name. |

Saved data is stored in:

```text
WTF/Account/<account>/SavedVariables/HCOneButton.lua
```

The main telemetry table is:

```text
HCOB_CombatLog
```

### Diagnostics and fail-safe

| Command | Description |
|---|---|
| `/hcob errors` | Print errors intercepted by HCOneButton's runtime fail-safe. |
| `/hcob reseterrors` | Clear runtime fail-safe state and retry smart components. |
| `/hcob diagpixel on` | Show the diagnostic RGB pixel. |
| `/hcob diagpixel off` | Hide the diagnostic RGB pixel. |

---

## Diagnostic pixel protocol

HCOneButton can expose a small diagnostic pixel intended for passive external diagnostics.

Protocol v3 is **slot-only**. It intentionally does not encode class or spell names.

For action slots 1–18:

```text
R = slot × 12
G = 96
B = 224
```

Special states:

| State | RGB | HEX |
|---|---|---|
| None | `0, 0, 0` | `#000000` |
| Unmapped Advisor recommendation | `255, 255, 255` | `#FFFFFF` |

Examples:

| Slot | RGB | HEX |
|---:|---|---|
| 01 | `12, 96, 224` | `#0C60E0` |
| 02 | `24, 96, 224` | `#1860E0` |
| 03 | `36, 96, 224` | `#2460E0` |
| 10 | `120, 96, 224` | `#7860E0` |
| 18 | `216, 96, 224` | `#D860E0` |

The meaning of each slot is guaranteed by HCOneButton's deterministic class layout, not by the external reader.

---

## Combat-lockdown / secure-action design

WoW restricts protected combat actions. HCOneButton is designed around those restrictions:

- secure action attributes are prepared outside combat;
- the Advisor may change its visual recommendation during combat;
- it does **not** dynamically rewrite a secure button into a different spell during combat;
- the Action Panel therefore uses permanent class-specific spell slots;
- the player still performs the final click/key press.

This separation is intentional and is fundamental to the addon's architecture.

---

## Performance

HCOneButton avoids heavy continuous scans where possible:

- Profession Coach is event-driven;
- profession panels hide in combat;
- Action Panel state/cooldown updates are throttled;
- combat telemetry is compact and retained with a configurable fight limit;
- smart components include runtime fail-safe handling.

If something appears wrong, run:

```text
/hcob errors
/hcob status
```

---

## SavedVariables

HCOneButton currently uses:

```text
HCOB_DB
HCOB_CombatLog
```

Deleting `WTF/.../SavedVariables/HCOneButton.lua` resets saved addon configuration and telemetry. Back it up first if you want to keep combat history.

---

## License

This project is intended to be distributed under the **MIT License**.

See [`LICENSE`](LICENSE) for the full license text.

---

## Disclaimer

HCOneButton is an independent community addon and is not affiliated with or endorsed by Blizzard Entertainment.

World of Warcraft and Blizzard Entertainment are trademarks or registered trademarks of Blizzard Entertainment, Inc.
