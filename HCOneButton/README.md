# HCOneButton

> Smart WoW Classic Hardcore combat assistant with class-aware recommendations, secure clickable actions, survival logic, pet management, profession coaching, cooldown awareness, combat telemetry and passive diagnostics.

- **Current version:** `1.29.3`
- **Target client:** World of Warcraft Classic Era / Hardcore
- **Interface:** `11509`

HCOneButton is a quality-of-life combat assistant designed for WoW Classic Hardcore. It analyzes the current combat state and recommends useful actions while keeping the final gameplay input in the player's hands.

The addon combines a compact combat HUD, **Advisor Engine 2.0 for all nine classes**, deterministic secure action slots, survival-oriented decision logic, profession guidance, Hunter pet management and detailed combat telemetry.

> **Important:** HCOneButton does **not** automatically execute the Advisor's combat decisions. Protected actions still require a player click/key press through WoW's secure action system.

---

## README contents

- [What HCOneButton does](#what-hconebutton-does)
- [DPS and aggro meter](#dps-and-aggro-meter)
- [Local Adaptive Tuning](#local-adaptive-tuning)
- [Pre-pull Safety Advisor and Recovery Gate](#pre-pull-safety-advisor-and-recovery-gate)
- [Survival consumables strip](#survival-consumables-strip)
- [Supported classes and deterministic action layouts](#supported-classes-and-deterministic-action-layouts)
- [Hunter pet management](#hunter-pet-management)
- [Installation](#installation)
- [Basic usage](#basic-usage)
- [Complete command reference](#complete-command-reference)
- [Diagnostic Pixel and external reader protocol](#diagnostic-pixel-and-external-reader-protocol)
- [Current baseline validation](#current-baseline-validation)
- [Release history](CHANGELOG.md)

---

## Current release

Version `1.29.3` adds a **live aggro meter alongside DPS**: see your threat against the selected hostile NPC, when you are approaching its aggro threshold, when you have aggro and when your pet holds it. It works across all nine classes, including pet pulls before the owner enters combat, and shows `--` when the client cannot supply a percentage.

The existing **DPS / aggro meter** option and `/hcob dps on|off` control the combined display. Threat is read directly from the client and works with Combat logger disabled. This is informational: it does not change rotation priorities, the pixel protocol or secure actions.

**Upgrade without resetting:** existing settings, HUD position, tuning data and meter visibility are preserved; there is no new learner/schema revision. Release automation now explicitly distinguishes validation-only runs from real uploads, keeps simulated uploads out of the GitHub summary and uses Node 24 actions.

## Local Adaptive Tuning

**Situational Adaptive Tuning**, introduced in `1.29.2`, compares confirmed choices that were available at the same decision across all nine supported classes. Safe proc, buff, resource, mitigation and recovery/control priorities can participate alongside ordinary damage choices.

The inspector shows each recorded situation, chosen/alternative evidence, fixed-action explanations and bounded `−12…+12` corrections. It also reports displayed choices changed by tuning and how many were executed. Explicit `Normal (PvE)` / `PvP` views, automatic refresh, the baseline legend and class-specific Options grouping remain available; PvP learning remains unsupported.

When upgrading from a learner older than `1.29.2`, compatible observations are preserved but previous coefficients are not reused or enlarged: each situation needs new two-sided evidence (at least four chosen and four alternative-choice fights) before a priority correction can apply. A changed suggestion is observable impact, not proof of a DPS increase.

Emergencies, interrupts and cast/range/aura eligibility rules remain fixed. Ordinary proc, buff, resource, mitigation and safe recovery/control opportunities can participate. Short/incomplete fights, PvP, deaths, mid-fight build changes and uncorrelated choices are excluded. Everything remains in local per-character SavedVariables: no upload, external executable or account. Use `/hcob tuning status`, `/hcob tuning off` or `/hcob tuning reset` at any time.

The `1.28.6` character-scoped telemetry foundation remains intact. New fights use an anonymous per-character profile, account storage remains bounded, and different classes or same-class alts cannot contaminate HUD averages, last-fight output, reports or learned contexts.

- contexts are separated by class, specialization, five-level band, solo/group play, talents and learned spellbook;
- easy, even-level, hard and elite targets use separate rolling performance baselines;
- a confirmed cast records the first comparable choice for each action in a fight: choosing that action now versus choosing another available action. Later use of that spell does not turn the earlier choice into a second sample;
- comparisons separate one/multiple targets, low/mid/high current resources (`<=35%`, `35–80%`, `>=80%`) and main/finishing target HP (`>30%` / `<=30%`), with at most 12 situations per action;
- the objective combines difficulty-normalized effective DPS (discounting player/pet overkill), surviving HP floor and a smaller penalty for time capped on Rage/Energy. These are observational associations, not proof that a spell caused a DPS gain;
- a context needs eight eligible fights. Each situation additionally needs at least **four chosen and four alternative-choice fights**. Variability, a minimum-effect margin and gradual confidence scaling reduce noisy corrections; insufficient or indistinguishable evidence stays at zero;
- corrections use quarter-point steps within `±12` score points, enough to change meaningful priority gaps. Candidate eligibility, cooldowns, aura refresh limits, range, cast holds, swing windows and Execute pooling are not learned or relaxed;
- proc, buff, resource, mitigation, form/aspect and safe control/recovery opportunities are eligible across all nine classes. Emergency cooldowns and interrupts stay fixed. Conditional actions are protected at HP `<=60%`, Survival Reserve `<45` or `3+` enemies; recovery-tagged actions additionally require HP `>=75%` and reserve `>=60`. Mend Pet is protected when pet HP is unknown or `<=60%`;
- if the baseline winner is currently protected, tuning cannot displace it. Safe multi-pull/pre-escape spell routes expose alternatives only when their original spell is still eligible; cold/OFF behavior retains the original route's choice;
- a successful eligible player alternative is useful even when it disagrees with the Advisor. Repeated reader polls, duplicate cast events and two roles of the same spell are not independent comparisons. Pending choices survive a valid cast hold, but expire or are discarded on target changes or emergency advice;
- later evidence can reduce or reverse an earlier adjustment automatically;
- disabling tuning stops both learning and application but preserves the data; reset clears the active character's learned contexts;
- learning never executes a spell: every protected action still requires the player's input.

The `Local Adaptive Tuning` checkbox in `/hcob options` exposes the ON/OFF flag directly; the choice is stored per character and survives `/reload` and logout. The same flag is available through `/hcob tuning on|off`. `/hcob tuning status` and the visual inspector use the same explicitly selected view and current class/build context, never the most recently learned context from another build. `/hcob tuning reset` provides an immediate per-character rollback without deleting the normal combat history.

`View learned adjustments...` opens the inspector for the current character/build. It refreshes on opening and every second while visible. Each learned situation has its own persistent `−12…+12` row and chosen/alternative comparison counts; selecting another target does not hide those rows. Observed spells awaiting comparisons and fixed actions remain visible unless `Active only` is checked. Tooltips explain situations and protection. Reset still requires a second confirmation and clears only the character's learner state.

The legend explains left/negative (lower priority), center/zero (baseline) and right/positive (higher priority). These are score points, not damage percentages. **Observed impact** separately reports changed displayed choices against the same evaluation's baseline and how many changed choices were executed. It does not count every frame and is explicitly not a measured DPS gain. A context can be ready while individual situations are still awaiting 4+4 comparisons; the learner does not randomly explore spells to fill missing samples.

Openers and out-of-combat-only preparation are not trained by this combat-choice model. Actions without a class candidate remain outside it. Existing observations and opt-out preferences survive upgrade, but revision-1/2 coefficients are not applied or enlarged: the broader policy requires new comparative evidence. The model changes eligible priorities, not spell-specific HP/Rage/DoT thresholds or rotation code.

The `Normal (PvE)` and `PvP` tabs are explicit viewing preferences, saved per character across reload/logout. Selecting yourself, a friendly player or any other target never switches the view. These tabs do not change gameplay mode or enable learning: **PvP tuning is not supported**, and its tab says so instead of displaying PvE corrections or misleading calibration progress. Actual PvP damage/miss exchanges involving the player or pet, hostile control events and battleground/arena instances remain excluded from learning; nearby players, friendly heals and friendly buff/debuff applications do not mark a PvE fight as PvP.

Leveling within the same five-level band preserves the profile when talents and the learned spellbook remain unchanged. Compatible `1.29.0` exact-level profiles are recovered automatically; if several match, only the most recently updated profile is reused, without merging or double-counting evidence. Other saved profiles are preserved. Actual talent/spellbook changes, a new five-level band or switching between solo and group play select a separate context: both the inspector and status command clearly report calibration for that context, not active corrections from the previous build. Learned corrections remain inspectable while tuning is disabled, but are not applied.

### Preserved combat baseline

The `1.28.5` **Warrior Swing Queue Update** remains part of the current baseline. Heroic Strike is treated as an on-next-swing ability instead of a normal instant action: the Advisor exposes it only during a short window before the next main-hand attack and stops requesting it immediately once the client reports it queued.

The queue window scales with the equipped main-hand speed and is clamped to `0.45–0.65` seconds. Heroic Strike and Cleave hit/miss events realign the swing timer, an armed queued strike suppresses further requests, and queue-safe `!` macros prevent duplicate input samples from toggling it back off. Cleave is now the appended deterministic Warrior slot 20 and becomes the preferred queued Rage dump during controlled multi-target pressure.

When Execute is learned and the target is between `21%` and `30%` HP, queued Rage dumps pause and the Advisor displays `POOL FOR EXECUTE`. Spending is released at `85` Rage to avoid wasting generation near the cap; Execute, Overpower and efficient core strikes retain priority. Healthy two-target pulls now return to Mortal Strike/Bloodthirst/Whirlwind after defensive setup, while low HP, low Survival Reserve and 3+ enemy states retain escape priority. Active Thunder Clap and Demoralizing Shout debuffs are not repeatedly requested before their final `3` seconds.

The `1.28.4` combat-only aura policy remains part of the baseline. It covers Battle Shout, Blessing of Might and Paladin seals, Inner Fire/Fortitude/Power Word: Shield/Renew, Mage armor/Arcane Intellect/Ice Barrier/Mana Shield, Demon Armor/Demon Skin, Mark of the Wild, Lightning Shield and weapon imbues, Hunter aspects/Mend Pet, and Slice and Dice. A shared stabilization layer absorbs short Classic aura-API races and the stale near-expiry frame that can follow a successful refresh, preventing duplicate requests without hiding a genuinely removed aura.

The **Survival consumables strip** provides four secure click buttons for the best usable healing potion, Healthstone, mana potion and bandage currently in the bags. It shows quantities, cooldown sweeps/text, availability and restock state. The Advisor highlights the appropriate healing tool during low-health recovery and combat danger, or a mana potion at critically low mana.

Protected item assignments are selected only outside combat and remain frozen throughout combat lockdown. Bag counts, cooldowns and highlights may continue updating visually, but a newly acquired/lower-tier item is not assigned until combat ends. The strip never consumes an item automatically and adds no key binding; every use requires the player's click.

The `1.28.5` Warrior swing queue, `1.28.4` Combat Aura Discipline, `1.28.3` Warrior Rage/escape balance and `1.28.2` active-cast timing and Paladin Divine Shield policy remain part of the current baseline, together with exact HUD-position persistence, the rank-safe `60 ms` Diagnostic Pixel acknowledgement edge, recommendation stabilization, shared hostile-spell range checks, Warlock pet pull protection, guarded binding saves and read-only `/hcob doctor`. Fresh installations still enable Action Panel auto-bind by default. Deterministic class slots and Diagnostic Pixel Protocol V3 encoding are unchanged.

See [`CHANGELOG.md`](CHANGELOG.md) for the complete release history.

---

## What HCOneButton does

### Unified combat HUD

The main HUD contains:

- **BASE** secure action button;
- class-aware **Advisor**;
- HP/resource/swing information;
- compact live DPS and current-target threat information;
- a secure **Action Panel** directly below the main HUD;
- a secure **Survival consumables strip** below the Action Panel;
- visual states for `OK`, `CAUTION` and `DANGER`.

The HUD is draggable while unlocked. Its complete anchor and offsets are persisted immediately to `HCOB_DB`, so `/reload` restores the exact dragged position even when WoW changes the frame's anchor type while moving it. The primary **HUD scale** resizes BASE, Advisor, telemetry, the Fixed Action Panel, Survival strip and Profession Coach together; `/hcob actions scale` remains available only as an optional relative Action Panel adjustment.

### DPS and aggro meter

Below the Advisor, the first row retains current/last DPS, recent average, damage and fight duration. The second row shows **your threat against the current hostile NPC target**, using the client's scaled threat percentage: **100% is the aggro threshold**, not your share of total group damage or raw threat.

| Display | Meaning |
| --- | --- |
| `LOW` (teal) | Reported threat below the warning threshold; not a guarantee of safety. |
| `HIGH` (amber) | At least 85% of the scaled threshold, or the client reports elevated non-tanking threat. |
| `AGGRO` (red) | The client reports that you hold aggro. Expected when intentionally tanking or playing solo. |
| `PET` / `HIGH / PET` | Your pet holds aggro; the number still describes **your** threat, not the pet's. |
| `THREAT --` | Percentage unavailable. A known aggro/pet status can still be shown without inventing a number. |
| `NO TARGET`, `IDLE`, `N/A`, `NO DATA` | No target, no active combat, an ineligible target (friendly/player/dead), or unavailable threat information. No old percentage is retained. |

Example: while your pet tanks, `THREAT 90%` with `HIGH / PET` warns that you are close to taking aggro. If the mob switches to you and the client reports it, the status becomes `AGGRO`.

Enable/disable the combined panel through **Options → Combat data and learning → DPS / aggro meter** or `/hcob dps on|off`. The existing `showDPSMeter` saved preference is reused. Threat updates even with Combat logger off or the Advisor hidden; DPS statistics still depend on the logger. The new row follows HUD scale/position and does not intercept clicks.

This is a compact, read-only **current-target** display, not a raid threat ranking, all-enemy aggro monitor, taunt timer or PvP predictor. It uses available client threat APIs, not combat-log estimation; missing/failed API reads remain unknown. No learned coefficients, recommendations, bindings or pixel data are changed by the meter.

### Advisor Engine 2.0

Advisor Engine 2.0 evaluates multiple valid actions instead of simply choosing the first matching rule.

It can consider, depending on class:

- HP and class resource;
- target HP and level;
- number of enemies;
- pet status;
- cooldown availability;
- pre-pull HP/resource/pet readiness;
- healing consumable stock and cooldown state on tough pulls;
- learned primary escape/control cooldown readiness on tough pulls;
- melee/ranged pressure;
- rolling estimated **TTK** (time to kill);
- rolling estimated **TTD** (time to death);
- class-specific **Survival Reserve**;
- confirmed recommendation stability/hysteresis;
- rank-safe hostile-spell range and immediate castability;
- fight duration and resource efficiency;
- spec/talent direction where relevant;
- opener, sustain, finisher, interrupt and emergency priorities.

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
| Druid | ✅ Engine 2.0 |

Emergency states such as interrupts, critical HP and dangerous multi-pulls remain hard-priority safety gates.

While `UnitCastingInfo` or `UnitChannelInfo` reports an active player action, the Advisor displays `LET IT FINISH`, clears the Action Panel highlight and emits black/no-action through Diagnostic Pixel. Rotation evaluation resumes only after the real cast/channel ends or is interrupted, so haste, pushback and non-instant offensive spells do not produce an early next suggestion.

Normal action/buff/idle transitions must remain consistent across multiple refreshes for `0.20` seconds before the display changes. A single event spike is discarded if the previous recommendation returns. `CAUTION`, `INTERRUPT` and `DANGER` escalation bypasses confirmation, and an action that is truly spent, unusable or out of range is replaced immediately. The short global cooldown is treated as a temporary valid state rather than proof that the recommendation should flicker.

Range handling for hostile recommendations is spell-based rather than tied to a fixed class list. In addition, Mage, Priest, Warlock, Hunter and caster-form/spec Druid or Shaman explicitly identify their current ranged BASE action, guaranteeing BASE feedback even when rank-1 client metadata is incomplete. Other genuinely ranged hostile actions receive the same protection through spell metadata. Self buffs, heals and melee abilities are deliberately excluded from the generic out-of-range warning.

### Pre-pull Safety Advisor and Recovery Gate

With a live hostile target selected and the player out of combat, the recovery gate runs before class openers:

- **`RECOVER FIRST`** when HP is below `85%`, mana is below `40%`, or a living Hunter/Warlock pet is below `70%`;
- **`PREPARE`** for a partial mana reserve, low energy, a missing level-10+ Hunter/Warlock pet, a pet below `90%`, unavailable healing tools, or all learned primary escape/control options on cooldown before a tough pull;
- **`HIGH RISK`** for elite/world-boss or +3-level targets, and for a +1-or-harder target when no healing potion, Healthstone or bandage is stocked;
- **`PULL READY`** only after the applicable recovery checks pass. Ranged classes must additionally pass their real spell-range/castability check; Hunter keeps its dead-zone states.

The gate never blocks input. It changes only the visual recommendation, and can be disabled persistently from **Options → Pre-pull safety gate** or with `/hcob prep off`. Rage is deliberately not treated as a missing pre-pull resource.

### Survival consumables strip

The strip contains four fixed mouse-click actions:

| Slot | Selection policy |
|---|---|
| `HEAL` | Strongest healing potion in the bags that the current level can use |
| `STONE` | Strongest available Healthstone, including improved-rank item variants |
| `MANA` | Strongest mana potion in the bags that the current level can use |
| `BANDAGE` | Strongest available bandage |

Each slot shows its current quantity, cooldown and usability. Empty slots retain a level-appropriate reference icon and show `0`, making missing stock visible before a dangerous pull. The strip prefers a bandage for out-of-combat HP recovery, preserves Healthstone/healing potion priority in combat, and avoids recommending a bandage as an emergency combat action. The `Recently Bandaged` lock drives the bandage's unavailable state and full 60-second visual countdown as well as participating in readiness checks.

The buttons use WoW's protected item-action system. Their selected item ID is refreshed on login, bag/item-data changes, level changes and after combat. If bags change during combat, the old protected assignment remains authoritative until `PLAYER_REGEN_ENABLED`; visual counts and cooldowns can still update safely. HCOneButton never clicks, consumes or binds these items automatically.

Use `/hcob consumables` to print current assignments, `/hcob consumables on|off` to control visibility, or the **Survival consumables strip** checkbox in Options.

### Class-owned combat policy

The modular architecture keeps the central Advisor class-agnostic. Each class owns its own combat policy through `Classes/<Class>.lua`, including recommendation candidates, survival reserve, panic/multi-pull behavior, interrupt choice and class-specific secure macro policy.

The shared Advisor is responsible for context, scoring, hysteresis and final selection rather than hard-coding individual spells such as Serpent Sting, Overpower or Life Tap.

Maintained self auras follow one cross-class contract. They are never requested out of combat, so an external reader is not kept busy by idle buff upkeep. In combat, missing maintenance can compete with the current class actions; an active aura is ignored until its final `10` seconds. Player spellcast acknowledgement and a bounded aura-observation cache absorb transient `UNIT_AURA` misses and stale pre-refresh durations. Proc auras, class forms, Stealth and hostile target debuffs remain contextual combat/opening mechanics rather than maintenance reminders.

For Paladin, Divine Shield is immediate at `25%` HP or lower. From `26%` through `35%`, it requires concrete lethal pressure: at least two active enemies, Survival Reserve at `28` or lower, or a confident estimated TTD of `6` seconds or less. Above `35%`, an unfavorable trend or a healthy 3+ enemy pull preserves Divine Shield and prefers Divine Protection, Hammer of Justice, healing or escape guidance. Lay on Hands retains priority at `18%` HP or lower.

For Warrior, preventive `UNFAVORABLE FIGHT` and controlled two-target escape guidance preserves enough Rage for Hamstring/control but no longer allows Rage to accumulate unused. Excess Rage passes through `Execute`, `Overpower`, `Mortal Strike`, `Bloodthirst`, `Whirlwind`, Cleave or `Heroic Strike` in that priority order before escape guidance resumes. The threshold starts at the greater of `40` or the configured `/hcob hsrage` value plus `5`, rises when Survival Reserve is critical and falls near the target's execute range. HP at `50%` or lower during a multi-pull and every 3+ enemy panic continue to preempt offensive spending. Heroic Strike and Cleave are offered only in the final `0.45–0.65` seconds before a tracked main-hand swing; an already queued strike suppresses the request immediately. Between `21–30%` target HP, queued dumps are pooled until `85` Rage when Execute is learned. Healthy controlled x2 pulls resume the core DPS scorer after Thunder Clap/Demoralizing Shout setup; those debuffs refresh only in their final `3` seconds.

### Coherent standalone windows

Options separates general appearance/behavior, combat data and learning, and Fixed Action Panel bindings. Only Warrior characters see the dedicated `Warrior - Combat policy` section, which groups `Smart pre-pull Rend`, `Situational Sunder` and the `Heroic Strike rage threshold` slider. Other classes do not display this section or reserve its space. Moving these controls does not change their behavior, defaults or saved settings; utility buttons and explanatory footer remain separate.

HCOneButton uses a small internal window manager for its standalone configuration/report dialogs. Options, the Adaptive Tuning inspector, Fixed Action Panel binding configuration and the feedback/report window never stack on top of one another. A child window opened from Options replaces it temporarily and returns to Options when closed through its Back button, standard frame X or Escape. If combat starts, configuration children close without trying to reopen Options during lockdown.

### Secure clickable Action Panel

The Action Panel contains fixed `SecureActionButton` slots. The Advisor highlights the recommended action, but never changes a protected action dynamically during combat.

Each icon can display:

- pulsing recommendation highlight;
- radial cooldown sweep;
- numeric cooldown for meaningful cooldowns;
- red range warning;
- desaturation when the action is not currently usable;
- tooltip information.

For a ranged BASE action, the main button uses the same state consistently:

- **green:** target in range and action immediately usable;
- **red:** target outside the spell's actual range;
- **amber:** target in range but resource/cooldown is unavailable, or the client reports an unknown range.

When no higher-priority recommendation is active, the Advisor mirrors this state as `PULL READY / PRESS BASE`, `OUT OF RANGE / MOVE CLOSER`, `BASE NOT READY / WAIT / RECOVER` or `RANGE UNKNOWN / ADJUST DISTANCE`. Hunter retains its additional dead-zone-aware states.

You can either click the highlighted icon or use its fixed keyboard binding.

### Deterministic action slots

Action slots **never compact or move because of character level or learned spells**.

For example, on Hunter:

- Slot 01 is always Hunter's Mark;
- Slot 02 is always Serpent Sting;
- Slot 03 is always Arcane Shot;
- Slot 18 is always Aspect of the Hawk;
- Slot 19 is always Aspect of the Monkey;
- Slot 20 is always Aspect of the Cheetah.

If the spell has not been learned yet, the slot stays in place and remains disabled/dim. When the spell is learned, the same slot becomes active.

This guarantees stable slot → key → diagnostic-color mappings for the lifetime of the character.

### Fixed Action Panel bindings

By default, HCOneButton uses the following slot bindings. They can be changed from **`/hcob options` → Fixed Action Panel bindings → Configure slot bindings...**. The mapping is stored per slot and is shared across classes, while each class keeps its own deterministic spell layout.

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
| 19 | `CTRL+SHIFT+9` |
| 20 | `CTRL+SHIFT+0` |

> **Warning:** both default and custom combinations may already be used by the WoW UI or another addon. HCOneButton can overwrite the existing binding when auto-bind is enabled. The binding editor rejects duplicate keys between HCOB slots, but it may intentionally replace a non-HCOB WoW binding. Turning auto-bind off stops HCOneButton from applying slot bindings again, but does not automatically restore bindings that were previously replaced.

When a character/class uses fewer slots than another character, HCOneButton can release stale HCOB slot bindings that are no longer active. It only clears a key if that key still points to the exact HCOB slot command; a key the user has rebound to another action is left untouched.

In the binding editor, click a slot key and press the desired combination. `ESC` cancels capture, `DELETE`/`BACKSPACE` leaves that slot unbound, **Default** resets one slot, and **Reset all** restores the full default layout.

Use:

```text
/hcob actions binds
```

to print the current slot → key → action mapping.

---

## Supported classes and deterministic action layouts

HCOneButton supports all nine WoW Classic classes: **Warrior, Paladin, Hunter, Rogue, Priest, Mage, Warlock, Shaman and Druid**.

The following class layouts are deterministic. Unknown spells keep their slot. Existing slots are preserved across releases; newly introduced actions are appended whenever possible.

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
| 19 | Charge |
| 20 | Cleave |

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
| 19 | Aspect of the Monkey |
| 20 | Aspect of the Cheetah |

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
| 17 | Riposte |

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
| 19 | Arcane Missiles |

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

Warlock BASE uses the equipped wand outside Destruction when available, otherwise Shadow Bolt. Its pet command requires the player to be in combat: the first valid ranged cast begins the pull and a following BASE press engages the pet. Pressing BASE on an out-of-range target while out of combat does not send the pet.

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
| 15 | Cat Form |
| 16 | Bear Form |
| 17 | Rip |
| 18 | Faerie Fire (Feral) |
| 19 | Healing Touch |
| 20 | Frenzied Regeneration |

Druid now uses Advisor Engine 2.0 across Cat, Bear/Dire Bear and caster-form play. The stability layer identifies forms by stable form ID when available, with a resource-type fallback, rather than depending on a fixed stance-bar position.

Relevant secure Druid actions can cancel form before casting when required. Mobility/interrupt modifier macros also use form-aware fallbacks rather than assuming that Cat or Bear always occupies the same numeric stance slot.

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
| 14 | Rockbiter Weapon |
| 15 | Windfury Weapon |

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
- Slot 13: Feign Death;
- Slot 18: Aspect of the Hawk;
- Slot 19: Aspect of the Monkey;
- Slot 20: Aspect of the Cheetah.

Feign Death's secure action also prepares pet passive/follow before the spell.

### Hunter Auto Shot philosophy

Hunter BASE is designed to **start the pull/Auto Shot**, not to spam Auto Shot continuously.

Typical flow:

1. select a target;
2. press the Hunter BASE action once to start the pull;
3. let Auto Shot continue;
4. follow the Advisor for situational abilities.

---

## Feedback & diagnostic reports

HCOneButton `1.27.0` includes an in-game **Report a Problem** workflow intended for testers and normal users who encounter an incorrect recommendation or runtime problem.

Open it from:

```text
/hcob options
```

and click **Report a problem...**, or use:

```text
/hcob report
```

The window provides the HCOneButton CurseForge Issues address and generates a copy/paste-ready diagnostic block. The recommended workflow is:

1. reproduce the suspicious behavior and finish the fight;
2. click **Generate Last Fight**;
3. optionally enable **Detailed telemetry** if more context is needed;
4. click **Select Report (Ctrl+C)** and press `Ctrl+C`;
5. open `https://www.curseforge.com/wow/addons/hconebutton/issues` in a browser;
6. create a new issue, explain what you expected, and paste the diagnostic report.

The standard report contains class/level/spec, client/addon version, fight summary, Survival Reserve, a privacy-safe adaptive eligibility/adherence summary and the recent Advisor recommendation changes. Detailed mode additionally includes the complete stored trace for that fight, top scored candidates when available, resource buckets, generic class metrics and player ability telemetry. Last/recent report selection is scoped to the active character, so changing class or alt cannot insert unrelated fights into the diagnostic block.

The report generator intentionally omits character name/realm, target names/GUIDs, zone/subzone, equipment item IDs, anonymous profile/session identifiers and build hashes. The legacy Advisor trace is change-only and capped at 32 recommendation changes; adaptive action/input traces and decision/candidate aggregates are independently bounded.

Commands:

```text
/hcob doctor
/hcob report
/hcob report recent
/hcob log export
/hcob log export recent
/hcob log export raw
```

`/hcob log export raw` remains available for advanced debugging when the complete `HCOB_CombatLog` SavedVariable is specifically requested.

Use `/hcob doctor` while the suspicious target and character state are still active. The generated snapshot includes:

- current class/spec and class-owned BASE ID, localized name, resolved learned ID/rank and generated secure macro;
- known, usable, cooldown, minimum/maximum range, normalized range state and both raw Classic range API results;
- player/target/pet combat state without unit names or GUIDs;
- main binding, raw/normalized binding set, deterministic Action Panel slot/key and Diagnostic Pixel state;
- SavedVariables table identity/shape, repairs made during the current load, Advisor display state and recent fail-safe errors.

The Doctor does not rebuild macros, refresh protected frames, save bindings, initialize combat history or mutate SavedVariables. Character/realm names, target names/GUIDs, zone information and equipment IDs are not collected.

---

## Profession Coach

Profession Coach is an event-driven module and does not continuously scan professions during combat. It can be enabled or disabled persistently from **`/hcob options` → Profession Coach** or with `/hcob prof on|off`. When disabled, its panel is hidden and profession refresh/scans are suspended.

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

## Modular architecture

HCOneButton no longer uses the former monolithic `HCOneButton.lua` runtime. The addon is split into focused modules with a single public `HCOneButton` namespace and a private shared runtime environment.

Current high-level structure:

```text
HCOneButton/
├── HCOneButton.toc
├── Bindings.xml
├── README.md
├── CHANGELOG.md
├── LICENSE
├── Core/
│   ├── Init.lua
│   ├── State.lua
│   ├── Utils.lua
│   ├── SpellUtils.lua
│   ├── Range.lua
│   ├── Auras.lua
│   ├── Macros.lua
│   ├── Commands.lua
│   └── Events.lua
├── Advisor/
│   ├── Dynamics.lua
│   ├── Threat.lua
│   ├── Survival.lua
│   └── Engine.lua
├── Classes/
│   ├── Warrior.lua
│   ├── Hunter.lua
│   ├── Mage.lua
│   ├── Warlock.lua
│   ├── Priest.lua
│   ├── Rogue.lua
│   ├── Paladin.lua
│   ├── Shaman.lua
│   └── Druid.lua
├── Hunter/
│   ├── Pet.lua
│   ├── Ammo.lua
│   ├── Aspects.lua
│   ├── PetFood.lua
│   └── Management.lua
├── UI/
│   ├── CoreHUD.lua
│   ├── Advisor.lua
│   ├── WindowManager.lua
│   ├── ActionPanel.lua
│   ├── SurvivalStrip.lua
│   ├── Options.lua
│   ├── AdaptiveTuning.lua
│   ├── Feedback.lua
│   └── DiagnosticPixel.lua
├── Systems/
│   ├── Bindings.lua
│   ├── Consumables.lua
│   ├── TuningTelemetry.lua
│   ├── AdaptiveTuner.lua
│   ├── CombatLog.lua
│   ├── Feedback.lua
│   └── ProfessionCoach.lua
└── Data/
    ├── Spells.lua
    └── PetFoodDB.lua
```

`Core/*` and `Advisor/*` do not contain per-class decision chains. Class-specific policy belongs to `Classes/<Class>.lua`, while complex Hunter-only services remain in the dedicated `Hunter/` subsystem.

`Core/Range.lua` owns the shared rank-safe range/castability primitives consumed by the Advisor, BASE, Action Panel and Hunter subsystem. Repository-level Lua 5.1 regression harnesses live in `tests/` and are never loaded by the addon TOC. Run the complete syntax and regression suite from the repository root with `./tests/run.ps1`; explicit interpreter paths can be supplied through `-LuaPath` and `-LuacPath` when Lua 5.1 is not discoverable automatically.

---

## Installation

1. Close World of Warcraft.
2. Remove or replace the previous `HCOneButton` addon directory when upgrading across the architecture-refactor releases.
3. Extract the addon so the directory is:

```text
World of Warcraft/_classic_era_/Interface/AddOns/HCOneButton/
```

4. Verify that the folder directly contains at least:

```text
HCOneButton.toc
Bindings.xml
Core/
Advisor/
Classes/
Hunter/
UI/
Systems/
Data/
```

5. Start WoW and enable **HC One Button** in the AddOns list.
6. Enter the world and run:

```text
/hcob status
```

If upgrading from an older HCOneButton build, replace the complete addon folder instead of copying individual files over it. SavedVariables are stored separately and are preserved unless you delete them manually.

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

If the selected hostile ranged spell cannot reach the current target, the Advisor suppresses the executable highlight and Diagnostic Pixel recommendation and shows `OUT OF RANGE / MOVE CLOSER` instead. Move until the BASE/Action Panel state turns green and the Advisor reports `PULL READY` or `BASE READY`; safety severity remains visible for an out-of-range danger or interrupt recommendation. Range lookup prefers the localized learned spell name, then falls back to its stored rank-1 ID.

Before combat, `PULL READY` is additionally gated by health, class resource and pet recovery checks. On a tough target, healing stock/cooldown and learned primary escape/control cooldowns also participate. `RECOVER FIRST`, `PREPARE` and `HIGH RISK` are visual warnings only; they never prevent the player from pressing BASE or another action.

You can execute the recommendation by:

- clicking the highlighted secure icon; or
- pressing the fixed key corresponding to that action slot.

Debug the Advisor decision engine with:

```text
/hcob advisor debug
```

This can print information such as Survival Reserve, rolling TTK/TTD and the highest-scoring candidate actions.

---

## Complete command reference

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
| `/hcob actions scale 1.0` | Set an optional relative Action Panel scale multiplier (`0.8`–`1.5`) on top of the primary HUD scale. |
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
| `/hcob prep on\|off` | Enable/disable the persistent pre-pull Recovery Gate. |
| `/hcob consumables` | Print current Survival strip item assignments, quantities and cooldowns. |
| `/hcob consumables on\|off` | Show/hide the secure Survival consumables strip. Must be changed out of combat. |
| `/hcob dps on\|off` | Show/hide the combined compact DPS / aggro meter. |
| `/hcob swing on\|off` | Show/hide swing timer. |
| `/hcob sound on\|off` | Enable/disable sound alerts. |
| `/hcob danger N` | Set danger HP threshold (`20`–`70`). |
| `/hcob critical N` | Set critical HP threshold (`10`–`40`). |

### Layout

| Command | Description |
|---|---|
| `/hcob options` | Open HCOneButton's own options window. |
| `/hcob config` | Alias for `/hcob options`. |
| `/hcob report` | Open the in-game CurseForge-ready diagnostic report window. |
| `/hcob feedback` | Alias for `/hcob report`. |
| `/hcob doctor` | Open a read-only live diagnostic snapshot in the Report window. |
| `/hcob settings` | Open the Blizzard settings/category bridge. |
| `/hcob center` | Center the HUD. |
| `/hcob show` | Show HCOneButton. |
| `/hcob hide` | Hide HCOneButton. |
| `/hcob lock` | Lock HUD position. |
| `/hcob unlock` | Unlock HUD position for dragging. |
| `/hcob scale 1.0` | Scale the complete combat HUD (`0.7`–`1.6`): BASE, Advisor, DPS, Action Panel, Survival strip and Profession Coach. Must be changed out of combat. |

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
| `/hcob hsrage N` | Set the Heroic Strike threshold (`20`–`70` Rage); preventive escape logic adds a small safety margin, Cleave adds another `5` Rage, and Execute pooling temporarily overrides queued dumps between `21–30%` target HP below `85` Rage. |
| `/hcob rendspam on\|off` | Enable/disable intelligent pre-pull Rend preparation. |
| `/hcob sunder on\|off` | Enable/disable Warrior base Sunder behavior where applicable. |
| `/hcob hsspam` | Compatibility command; Heroic Strike BASE spam remains intentionally disabled. |

### Local Adaptive Tuning

| Command | Description |
|---|---|
| `/hcob tuning` or `/hcob tuning status` | Show enabled state, eligible fights, saved contexts and current-build calibration/learned corrections for the same Normal (PvE)/PvP view selected in the inspector. |
| `/hcob tuning on` | Enable local comparative learning and bounded situational priority corrections. Combat logging must also be enabled to collect new samples. |
| `/hcob tuning off` | Stop learning and applying adjustments while preserving the character's learned data. |
| `/hcob tuning reset` | Clear the active character's learned contexts and restart calibration; available out of combat. |

### Combat telemetry

| Command | Description |
|---|---|
| `/hcob log` | Show logging status. |
| `/hcob log on` | Enable combat telemetry. |
| `/hcob log off` | Disable combat telemetry. |
| `/hcob log last` | Print the active character's last recorded fight. |
| `/hcob log stats` | Print aggregate statistics from the active character's latest ten fights. |
| `/hcob log export` | Open the report window and generate the last-fight diagnostic report. |
| `/hcob log export recent` | Open the report window for recent fights. |
| `/hcob log export raw` | Print the legacy instructions for locating the complete SavedVariables table after `/reload`. |
| `/hcob log clear` | Clear only the active character's matching fight history. |
| `/hcob log clear all` | Clear the complete account-wide fight store. |
| `/hcob log max N` | Set maximum retained fights per character (`10`–`200`); an account-wide hard ceiling still applies. |
| `/hcob log session NAME` | Set/read the active character's combat-log session name. |

Saved data is stored in:

```text
WTF/Account/<account>/SavedVariables/HCOneButton.lua
```

The main telemetry table is:

```text
HCOB_CombatLog
```

The table is account-wide but every fight recorded by `1.28.6` or newer carries a random local profile identifier. `HCOB_CharacterDB`, stored by WoW as `SavedVariablesPerCharacter`, supplies that identifier and the character-specific session label without retaining a character name, realm or GUID. HUD averages, log commands and sanitized reports select only the active profile. Legacy fights without an identifier use a class-only compatibility fallback.

Retention uses the configured limit independently for the active character and a final hard ceiling of 600 fights for the complete account store. This preserves useful histories across normal alt play without allowing SavedVariables to grow indefinitely.

Fight schema `13` embeds adaptive telemetry contract `1`. The contract is shared by Warrior, Paladin, Hunter, Rogue, Priest, Mage, Warlock, Druid and Shaman: it stores anonymous build/policy signatures and combat context, selected and alternative candidates, input/action correlation, reaction/adherence, resource buckets and explicit eligibility filters. Learner revision `3` adds bounded `choiceEvidence` and displayed-choice `impact` fields; raw targets in pending cast windows are erased before finalization. Confirmed co-eligible player alternatives can qualify independently of the old adherence-percentage gate; all fight safety/context exclusions remain.

### Diagnostics and fail-safe

| Command | Description |
|---|---|
| `/hcob errors` | Print errors intercepted by HCOneButton's runtime fail-safe. |
| `/hcob reseterrors` | Clear runtime fail-safe state and retry smart components. |
| `/hcob diagpixel on` | Show the diagnostic RGB pixel. |
| `/hcob diagpixel off` | Hide the diagnostic RGB pixel. |

---

## Diagnostic Pixel and external reader protocol

HCOneButton can expose a small diagnostic pixel intended for passive external diagnostics.

The current implementation renders it as an unscaled **8×8 frame** so it remains easy for an external reader to sample. The encoded color, not the frame dimensions, is the protocol contract.

### Using an external reader

1. Enable the frame with `/hcob diagpixel on`.
2. Locate it immediately to the right of the Advisor frame, separated by a 4 px gap. It follows the HUD position but is intentionally excluded from HUD scaling.
3. Sample any point inside the solid 8×8 frame and read its 8-bit RGB value.
4. Treat black as no executable recommendation—including an Advisor spell deliberately suppressed because it is out of range or while the player is finishing any cast/channel—and white as an Advisor recommendation that has no deterministic Action Panel slot.
5. For a normal slot color, verify `G = 96` and `B = 224`, then decode `slot = R / 12`. Valid slots are 1–20.
6. Resolve the decoded slot through the current class table in [Supported classes and deterministic action layouts](#supported-classes-and-deterministic-action-layouts).

When the player successfully executes the spell currently encoded by the pixel, HCOneButton emits black for at least `60 ms` before publishing the latest recommendation. A 50 Hz reader therefore observes approximately three `nil` samples between completed and subsequent suggestions. This acknowledgement edge is also emitted when the next recommendation resolves to the same deterministic slot; external readers should treat `color → black → color` as two distinct recommendation cycles. Exact spell IDs and higher ranks are matched through the localized spell name.

Protocol v3 is **slot-only**. It intentionally does not encode class or spell names.

For action slots 1–20:

```text
R = slot × 12
G = 96
B = 224
```

Special states:

| State | RGB | HEX |
|---|---|---|
| No executable recommendation / out of range | `0, 0, 0` | `#000000` |
| Unmapped Advisor recommendation | `255, 255, 255` | `#FFFFFF` |

Examples:

| Slot | RGB | HEX |
|---:|---|---|
| 01 | `12, 96, 224` | `#0C60E0` |
| 02 | `24, 96, 224` | `#1860E0` |
| 03 | `36, 96, 224` | `#2460E0` |
| 10 | `120, 96, 224` | `#7860E0` |
| 18 | `216, 96, 224` | `#D860E0` |
| 19 | `228, 96, 224` | `#E460E0` |
| 20 | `240, 96, 224` | `#F060E0` |

The meaning of each slot is guaranteed by HCOneButton's deterministic class layout, not by the external reader.

---

## Combat-lockdown / secure-action design

WoW restricts protected combat actions. HCOneButton is designed around those restrictions:

- secure action attributes are prepared outside combat;
- secure macro/button configuration is guarded by `InCombatLockdown()`;
- the Advisor may change its visual recommendation during combat;
- it does **not** dynamically rewrite a secure button into a different spell during combat;
- the Action Panel therefore uses permanent class-specific spell slots;
- Survival strip item assignments are also prepared out of combat and remain frozen until combat ends;
- bag counts, cooldowns and recommendation glows may update visually without rewriting the protected item action;
- the player still performs the final click/key press.

This separation is intentional and is fundamental to the addon's architecture.

---

## Performance and runtime safety

HCOneButton avoids heavy continuous scans where possible:

- Profession Coach is event-driven;
- Survival consumable inventory selection is event-driven by login, bag, item-data, level and combat-end events;
- profession panels hide in combat;
- Action Panel state/cooldown updates are throttled;
- combat telemetry is retained with per-character quotas and an account ceiling; the Advisor trace, adaptive action/input traces and decision/candidate aggregates all have independent fixed caps;
- smart components include runtime fail-safe handling;
- shared combat data is collected into a common Advisor context instead of repeatedly querying the same APIs from every class module;
- defensive value-access guards fail closed if a shared API value is unexpectedly unavailable, instead of fabricating combat state.

If essential live combat data cannot be read safely, smart recommendations can degrade to a limited state while secure player input remains available.

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
HCOB_CharacterDB (per character)
```

`HCOB_DB` and `HCOB_CombatLog` remain account-wide. `HCOB_CharacterDB` is stored in WoW's character-specific SavedVariables path and contains the anonymous telemetry profile, that character's session label and the versioned `adaptive` context store. Adaptive schema `2` preserves explicit opt-out and the inspection tab, with at most 24 contexts, 64 actions per context and 12 comparison situations per action. Version `1.29.2` uses learner revision `3`; existing observations survive, but previous coefficients require new comparative evidence before priorities change. Deleting the account-wide `WTF/.../SavedVariables/HCOneButton.lua` resets addon configuration and shared fight telemetry; deleting the character-specific copy resets that character's anonymous profile and learner state. Back up files first to retain history.

`/hcob log clear` removes the active character's records in place; `/hcob log clear all` resets the complete combat-log table in place. Both preserve the live WoW SavedVariable identity across `/reload` and logout.

---

## Current baseline validation

The `1.29.3` source baseline currently passes:

- **47/47 Lua chunks** pass syntax parsing in the current validation environment;
- **26/26 Lua 5.1 regression harnesses** pass through the shared `tests/run.ps1` runner;
- **48/48 TOC references** resolved (`47 Lua + Bindings.xml`);
- **19/19 offline Python release tests** pass, including inherited-runner-summary isolation and explicit validation/upload summaries;
- threat-meter coverage verifies 48 API states across all nine classes, scaled versus raw percentage, 85% warning boundary, status-only fallback, unknown/restricted/invalid data, pet-first pulls, target/OOC reset, real DPS-history integration, saved visibility and shared-scale/layout clearance;
- no duplicate TOC entry;
- SavedVariables lifecycle validation: account-wide and per-character bootstrap tables are replaced by the TOC-loaded globals at `ADDON_LOADED`, existing values are preserved and missing defaults are filled on the persistent table;
- malformed SavedVariables recovery, including invalid roots, settings, binding maps and combat-log structures;
- malformed adaptive action collections fail closed in the inspector, status command and offensive-bias lookup without crashing;
- Options layout tests instantiate all nine classes and verify Warrior-only grouping, setting persistence/reload, slider-label spacing and CTA/footer separation; inspector tests verify the visible baseline legend and its reserved space;
- fresh-install binding-path verification: auto-bind defaults to enabled and is applied during `PLAYER_LOGIN`;
- all nine deterministic class layouts remain within the 20-slot limit, without duplicate action IDs or missing spell constants;
- Advisor stability/range regression coverage: transient normal recommendations are discarded, sustained changes commit after confirmation, safety escalation remains immediate, global cooldown does not force a swap, localized learned-spell range overrides incomplete rank-1 metadata, explicit ranged BASE contracts remain protected, and friendly/melee actions are excluded from ranged warnings;
- Warlock pull-safety regression coverage verifies that BASE pet attack requires combat and the former unconditional out-of-combat pet command is absent;
- binding-save regression coverage: account/character binding sets remain unchanged, while `0`, `nil`, invalid values and API failures safely fall back to set `1` without passing an invalid argument to `SaveBindings`;
- SavedVariables lifecycle coverage verifies normal `ADDON_LOADED` rebinding, direct `PLAYER_LOGIN` fallback, preservation/defaults, malformed-root repair and all login initialization hooks;
- character-scoped telemetry coverage verifies anonymous profile filtering across different classes and same-class alts, legacy class fallback, current-version DPS averages, per-character retention, current-character clearing and explicit account-wide clearing;
- adaptive telemetry coverage verifies the all-class contract, anonymous build/policy context, stabilized decisions and alternative candidates, secure input versus confirmed action, reaction/adherence, resource-mode separation, pet/combo/hidden-mana context, bounded traces, generic class metrics, adaptive-store repair and PvP/eligibility exclusion;
- Local Adaptive Tuning coverage verifies preserved opt-out and observations, context/migration isolation, explicit PvE/PvP inspection, 4+4 comparison gates, changed decisions across all nine class policy examples, real Warrior Clap/Sunder eligibility, cast-hold attribution, manual alternatives, same-spell role deduplication, special-route cold/OFF equivalence, emergency/pet protection, invalid-state and malformed-store rejection, resource/overkill objectives, frame-independent impact counters, live inspector/fixed-row rendering and reset/navigation behavior. The development review record is in the repository's `docs/ADAPTIVE_REVIEW.md` (not part of the addon package);
- all nine class modules load in isolation and expose the required Advisor/secure-macro contracts; ranged BASE recognition, hybrid melee transitions, macro size and Warrior/Warlock safety invariants are checked;
- all nine deterministic Action Panel layouts are checked for stable slot counts, known/unique spell IDs, the 20-slot limit, unique default keys and Diagnostic Pixel V3 encodability;
- Doctor report coverage verifies BASE/range API probes, macro/pet/binding/SavedVariables diagnostics, slash-command dispatch, error containment/path sanitization, privacy exclusions and absence of SavedVariables mutation;
- consumable/readiness coverage verifies level-safe best-item selection, improved Healthstone variants, combat/OOC healing priorities, low HP/mana/energy and pet gates, tough-target stock/healing/escape cooldown warnings, `Recently Bandaged`, unavailable-item highlight suppression, secure deferred assignment and universal melee `PULL READY` integration;
- active-cast coverage verifies that channels, helpful casts and non-instant offensive casts clear the next recommendation until the current action ends, after which rotation guidance resumes;
- Paladin survival-policy coverage verifies the `25%` immediate Divine Shield boundary, conditional `26–35%` pressure gates, six-second lethal forecast, Lay on Hands priority and preservation of Divine Shield during moderate trends or healthy multi-pulls;
- Warrior escape-Rage coverage verifies low-Rage Hamstring priority, excess-Rage spending, proc/core/queued-strike ordering, controlled two-target spending and strict panic preemption at low HP or 3+ enemies;
- Warrior multi-pull coverage verifies defensive-debuff refresh boundaries, healthy x2 return to the core DPS scorer, low-reserve escape preservation and stance/equipment-aware Retaliation and interrupt selection;
- Warrior swing-queue coverage verifies the adaptive Heroic Strike/Cleave window, immediate queue suppression, special hit/miss timer reset, first-swing fallback, Execute pooling/release boundaries, slot-20 Cleave priority and queue-safe secure actions;
- cross-class aura coverage verifies combat-only maintenance for Paladin, Priest, Mage, Warlock, Druid and Shaman, healthy-aura suppression, the final-ten-second refresh boundary, Warrior Battle Shout policy, Hunter/Rogue aura guards, rank-safe cast acknowledgement, stale refresh metadata and bounded player/pet aura-miss debouncing;
- Diagnostic Pixel acknowledgement coverage verifies rank-safe cast matching, an observable `60 ms` black edge at 50 Hz, suppression of an already-computed next suggestion during that edge and same-slot re-emission afterward;
- TOC order, referenced files, runtime/TOC/documentation version parity and packaged README/CHANGELOG/LICENSE consistency are checked automatically.

Release-specific historical validation belongs in [`CHANGELOG.md`](CHANGELOG.md). The user tested the new `1.29.3` aggro meter in game and confirmed it works. This is a reported smoke-test result, not exhaustive live-client coverage of every class and threat state. The prior adaptive review record remains in `docs/ADAPTIVE_REVIEW.md`; no new in-game validation of that feature is claimed here. Automated checks cannot fully reproduce WoW secure-frame, binding and UI behavior or prove a DPS improvement.

---

## License

This project is intended to be distributed under the **MIT License**.

See [`LICENSE`](LICENSE) for the full license text.

---

## Disclaimer

HCOneButton is an independent community addon and is not affiliated with or endorsed by Blizzard Entertainment.

World of Warcraft and Blizzard Entertainment are trademarks or registered trademarks of Blizzard Entertainment, Inc.
