# HCOneButton

> Smart WoW Classic Hardcore combat assistant with class-aware recommendations, secure clickable actions, survival logic, pet management, profession coaching, cooldown awareness, combat telemetry and passive diagnostics.

- **Current version:** `1.29.11`
- **Target client:** World of Warcraft Classic Era / Hardcore
- **Interface:** `11509`

Version `1.29.11` brings more aggressive Priest leveling: prioritize useful DoTs, Mind Blast and learned fillers before ordinary wand fallback, while preserving recovery mana and emergency handling.

HCOneButton is a quality-of-life combat assistant designed for WoW Classic Hardcore. It analyzes the current combat state and recommends useful actions while keeping the final gameplay input in the player's hands.

The addon combines a compact combat HUD, **Advisor Engine 2.0 for all nine classes**, deterministic secure action slots, survival-oriented decision logic, profession guidance, Hunter pet management and detailed combat telemetry.

> **Important:** HCOneButton does **not** automatically execute the Advisor's combat decisions. Protected actions still require a player click/key press through WoW's secure action system.

---

## README contents

- [What HCOneButton does](#what-hconebutton-does)
- [Wand combat flow](#wand-combat-flow)
- [Between-pull recovery](#between-pull-recovery)
- [Bag Quick Delete](#bag-quick-delete)
- [DPS and aggro meter](#dps-and-aggro-meter)
- [Local Adaptive Tuning](#local-adaptive-tuning)
- [Pre-pull Safety Advisor and Recovery Gate](#pre-pull-safety-advisor-and-recovery-gate)
- [Survival consumables strip](#survival-consumables-strip)
- [Supported classes and deterministic action layouts](#supported-classes-and-deterministic-action-layouts)
- [Rogue leveling flow](#rogue-leveling-flow)
- [Priest leveling flow](#priest-leveling-flow)
- [Hunter pet management](#hunter-pet-management)
- [Installation](#installation)
- [Basic usage](#basic-usage)
- [Complete command reference](#complete-command-reference)
- [Diagnostic Pixel and external reader protocol](#diagnostic-pixel-and-external-reader-protocol)
- [Current baseline validation](#current-baseline-validation)
- [Release history](CHANGELOG.md)

---

## Current release

Version `1.29.11` gives the Priest a more offensive leveling policy. **Mind Blast and learned Smite/Mind Flay** keep priority while casting is useful and funded; the wand no longer takes over just because mana or target HP crossed the halfway mark. Smite remains available after the first Shadow talent point. Native learned-rank costs and cast times help preserve recovery mana and avoid spells that cannot land in time.

**Upgrade without resetting:** settings, HUD position, combat history, tuning data and ON/OFF preferences are preserved. Learner revision `4`, adaptive schema `2`, other class policies, Rogue Pick Pocket, Bag Quick Delete, recovery controls, DPS/aggro HUD, action slots and bindings are unchanged. Protected actions still require player input. The maintainer confirmed the Priest update in game on 2026-09-13.

## Wand combat flow

For **Priest, Mage and Warlock**, a Shoot recommendation asks for a **single click/press** to start the wand. Once the client reports auto-repeat active, the Advisor displays **WAND ACTIVE / LET IT RUN** with no repeated Shoot highlight. BASE feedback agrees, including when a Mage or Destruction Warlock has a normal spell assigned to BASE.

Wanding is not a cast/channel hold: healing, control, procs and offensive spells can still take priority. Follow their normal secure button/key when recommended. During a real cast, channel or bandage, the existing **LET IT FINISH** protection remains. The addon does not automatically interrupt Shoot or another cast, and native cooldowns and spell requirements still apply.

Range warnings remain authoritative. An unavailable wand start displays **WAND NOT READY / WAIT / RECOVER**; stopped auto-repeat allows a new start when appropriate. Missing targets and disabled Smart HUD no longer invite wand spam. No new setting, binding or window is required; Hunter Auto Shot and other classes keep their existing behavior.

**Example:** a Priest finishes applying a useful DoT and starts Shoot once. The Advisor shows LET IT RUN while wanding is preferred. If Shield or a heal becomes the next priority, that spell replaces the active-wand message; a real healing cast then shows LET IT FINISH.

## Priest leveling flow

The following offensive policy is included in `1.29.11`.

The Priest now favors **useful Shadow Word: Pain setup → Mind Blast → learned Mind Flay or Smite filler**, with Holy Fire when it is learned, usable and has enough remaining target lifetime. Smite remains available after the first Shadow talent point and before Mind Flay is learned; a learned Mind Flay remains eligible in mixed builds. Native usability, learned-rank cost/cast-time data and actual cooldowns determine availability rather than assuming that the winning talent tab grants a spell.

Wand no longer takes over simply at 55% target HP, 52% mana or on Spirit Tap. It has higher priority at **25% mana or below**, or when the target is at **20% HP or below** and its estimated remaining life is at most four seconds (or unavailable). Otherwise, it is the fallback after funded offensive casts. Existing active-wand feedback and single-start behavior remain.

When the client exposes the learned spell's mana cost and maximum mana, damage spending retains **15% of maximum mana after the cast**, increased to **25%** at HP <=72% or Survival Reserve <52. If readable, the least expensive currently usable Shield/heal cost also raises that reserve; Weakened Soul excludes Shield from that comparison. Missing cost data uses percentage gates instead of assuming free casts: 35% before Mind Blast, 30% for Pain/Smite/Mind Flay and 45% for Holy Fire, with a minimum 35% under pressure.

Real emergencies, necessary heals and control keep their existing safety handling. Shield allows closer-range offensive casting; unshielded close channels and unsafe hard casts remain excluded. Pain needs at least nine seconds of estimated target lifetime when known; Holy Fire needs its cast time plus six seconds and is not reapplied over its active DoT. Hard casts must have time to land. Without a usable wand or eligible spell, the Advisor waits rather than bypassing its own mana reserve through the BASE fallback.

**Tradeoff:** more offensive casting spends more mana and may require more drinking between pulls. This is a more aggressive priority policy, not a claim of a measured DPS/TTK gain. Existing settings, learned data, ranks, action slots and secure macros are preserved; no extra option is added.

## Between-pull recovery

FOOD and DRINK extend the existing Survival consumables strip without adding another panel. Use the existing **Survival consumables strip** option to show/hide all six buttons; the original four button names, HUD anchor/scale and saved settings are retained.

Selection chooses the highest usable tier of supported plain Classic food or water from your bags, preferring conjured items at equal tier. Common unbuffed cooked food is included, using the live item requirement rather than assuming it unlocks at the vendor tier's level. Buff food, raw cooking materials, alcohol, battleground-only and unrecognized special refreshments are excluded from automatic selection; they remain usable manually from your bags. Missing item metadata waits for the cache instead of guessing.

**Left-click FOOD or DRINK once outside combat.** Quantity, cooldown/usability and EAT / DRNK labels reflect the selected item. Food can be followed by water with a second manual click when both resources need recovery. The same active aura, full corresponding resource and rapid repeated clicks suppress another use. Movement, mounting, death, casting/channeling and Druid forms also prevent recovery clicks; there is no automatic dismount or form change. DRINK is N/A for Warriors and Rogues.

Food is highlighted at HP <=85% before out-of-combat bandages/potions; water can be highlighted below 60% mana. Actual Food/Drink auras produce **EATING / DRINKING / EAT + DRINK — LET IT FINISH** in the Advisor while recovery is useful. Existing HP/resource bars show progress. The hold clears when you interrupt recovery or the corresponding resources are full, even if the aura has not expired. Well Fed is not mistaken for eating. No click alone is treated as proof of recovery, and no spell/action is added to the passive diagnostic pixel.

Food/water are never used in combat and do not count as emergency healing stock. Combat freezes secure assignments and updates counts; bag changes take effect afterward. All item use remains player-operated, independent of ElvUI. The review record and regression checklist are in `docs/RECOVERY_REVIEW.md` in the repository.

## Bag Quick Delete

Enable **Quick delete bag items** under **Appearance and behavior** in `/hcob options`. The account-wide `HCOB_DB.bagQuickDelete` preference is **OFF by default**, persists across reload/logout and returns to OFF with **Reset defaults**. It appears for all nine classes.

Outside combat, hold **Ctrl + Alt**, without Shift, and hover a supported bag item. A red **DEL** overlay identifies the armed shortcut. Right-click once:

- **Gray / poor:** destroy the selected **entire stack** immediately, without an extra addon confirmation.
- **White / common and higher:** confirm the displayed item and quantity before pickup/deletion. Cancel or Escape leaves it untouched. Mandatory native client dialogs and restrictions are not bypassed.

Normal right-click retains use/equip behavior. Left/middle and extra mouse buttons pass through unchanged. Standard WoW bags and optional ElvUI bags are supported integration targets; other bag replacements are not guaranteed compatible, and unrecognized widgets are not intercepted. No separate bag window, external program or automatic cleanup is required.

Only the backpack and four equipped bags are eligible, not bank/equipped slots. Items identified as quest items, Hearthstone, locked items and containers still holding loot are protected. Missing metadata, an occupied cursor or active spell targeting blocks the shortcut. Combat, death, logout, option OFF and inventory changes cancel pending addon confirmations. Bag, slot, hyperlink, identity and count are rechecked; a stale confirmation cannot follow an item or delete its replacement.

**Destruction is not selling, and the addon cannot undo it.** A stack of eight gray items is removed in full. Useful non-quest materials are not automatically protected. No inventory event or timer deletes anything, and there is no bulk deletion or automatic retry. If the client blocks the action after pickup, return the item from the cursor to your bag; HCOB does not clear it automatically. Unavailable mouse integration disables this convenience for the session, leaving original click handlers intact.

The implementation has simulated standard/ElvUI regression coverage. See `docs/BAG_QUICK_DELETE_REVIEW.md` in the repository for the review record and disposable-item regression checklist.

## Local Adaptive Tuning

**Situational Adaptive Tuning**, introduced in `1.29.2`, compares confirmed choices that were available at the same decision across all nine supported classes. Safe proc, buff, resource, mitigation and recovery/control priorities can participate alongside ordinary damage choices.

The inspector groups recorded roles/situations beneath each spell, with chosen/alternative evidence, fixed-action explanations and bounded `−12…+12` corrections. It also reports displayed choices changed by tuning and how many were executed. Explicit `Normal (PvE)` / `PvP` views, automatic refresh, the baseline legend and class-specific Options grouping remain available; PvP learning remains unsupported.

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
- a successful eligible player alternative is useful even when it disagrees with the Advisor. Repeated inputs, duplicate cast events and two roles of the same spell are not independent comparisons. Input/cast-start/queue snapshots retain the original choice while the HUD advances. Pending actions have bounded cast/swing-aware expiry, are discarded on target changes and are cancelled on a matching failure/interruption. A failed repeat does not cancel a different in-progress cast or an armed swing;
- safety escalation discards unstarted comparison opportunities. A previously captured action can still be attributed to the safe decision made when it started; this never delays or displaces the emergency recommendation. Runtime target/cast identities are erased before saving the fight;
- later evidence can reduce or reverse an earlier adjustment automatically;
- disabling tuning stops both learning and application but preserves the data; reset clears the active character's learned contexts;
- learning never executes a spell: every protected action still requires the player's input.

The `Local Adaptive Tuning` checkbox in `/hcob options` exposes the ON/OFF flag directly; the choice is stored per character and survives `/reload` and logout. The same flag is available through `/hcob tuning on|off`. `/hcob tuning status` and the visual inspector use the same explicitly selected view and current class/build context, never the most recently learned context from another build. `/hcob tuning reset` provides an immediate per-character rollback without deleting the normal combat history.

`View learned adjustments...` opens the inspector for the current character/build. It refreshes on opening and every second while visible. The main list contains one entry per spell; click `[+]` to inspect separate roles and situations, their `−12…+12` corrections and chosen/alternative counts. Observed spells and fixed actions remain visible unless `Active only` is checked. Previously unclassified history is labelled separately and is not merged into training evidence. Tooltips explain protection; reset still requires a second confirmation and clears only the character's learner state.

The legend explains left/negative (lower priority), center/zero (baseline) and right/positive (higher priority). These are score points, not damage percentages. A summary marked `VARIES` spans different recorded situational corrections: expand it to see exactly which applies where. Opposite corrections are not averaged away, and comparison-fight counts are not summed across roles/situations. **Observed impact** separately reports changed displayed choices against the same evaluation's baseline and how many changed choices were executed; it is not a measured DPS gain.

The shared inspector/status states are `OBSERVING` (no usable comparisons yet), `COMPARING` (comparisons exist but no situation meets both sample gates), `BASELINE` (at least one situation meets the gates, with zero current correction), and `ADAPTED` (learned corrections exist). OFF and unsupported PvP are explicit overrides. The fight-baseline progress bar is not a training-completion percentage. Eight eligible fights are necessary but insufficient: each situation needs 4 chosen + 4 alternative fights. With only one eligible action there is no comparison to learn, and the addon does not randomly explore spells to fill gaps.

Openers and out-of-combat-only preparation are not trained by this combat-choice model. Actions without a class candidate remain outside it. Existing observations and opt-out preferences survive upgrade, but revision-1/2 coefficients are not applied or enlarged: the broader policy requires new comparative evidence. The model changes eligible priorities, not spell-specific HP/Rage/DoT thresholds or rotation code.

The `Normal (PvE)` and `PvP` tabs are explicit viewing preferences, saved per character across reload/logout. Selecting yourself, a friendly player or any other target never switches the view. These tabs do not change gameplay mode or enable learning: **PvP tuning is not supported**, and its tab says so instead of displaying PvE corrections or misleading calibration progress. Actual PvP damage/miss exchanges involving the player or pet, hostile control events and battleground/arena instances remain excluded from learning; nearby players, friendly heals and friendly buff/debuff applications do not mark a PvE fight as PvP.

Leveling within the same five-level band preserves the profile when talents and the learned spellbook remain unchanged. Compatible `1.29.0` exact-level profiles are recovered automatically; if several match, only the most recently updated profile is reused, without merging or double-counting evidence. Other saved profiles are preserved. Actual talent/spellbook changes, a new five-level band or switching between solo and group play select a separate context: both the inspector and status command clearly report calibration for that context, not active corrections from the previous build. Learned corrections remain inspectable while tuning is disabled, but are not applied.

### Preserved combat baseline

The `1.28.5` **Warrior Swing Queue Update** remains part of the current baseline. Heroic Strike is treated as an on-next-swing ability instead of a normal instant action: the Advisor exposes it only during a short window before the next main-hand attack and stops requesting it immediately once the client reports it queued.

The queue window scales with the equipped main-hand speed and is clamped to `0.45–0.65` seconds. Heroic Strike and Cleave hit/miss events realign the swing timer, an armed queued strike suppresses further requests, and queue-safe `!` macros prevent duplicate input samples from toggling it back off. Cleave is now the appended deterministic Warrior slot 20 and becomes the preferred queued Rage dump during controlled multi-target pressure.

When Execute is learned and the target is between `21%` and `30%` HP, queued Rage dumps pause and the Advisor displays `POOL FOR EXECUTE`. Spending is released at `85` Rage to avoid wasting generation near the cap; Execute, Overpower and efficient core strikes retain priority. Healthy two-target pulls now return to Mortal Strike/Bloodthirst/Whirlwind after defensive setup, while low HP, low Survival Reserve and 3+ enemy states retain escape priority. Active Thunder Clap and Demoralizing Shout debuffs are not repeatedly requested before their final `3` seconds.

The `1.28.4` combat-only aura policy remains part of the baseline. It covers Battle Shout, Blessing of Might and Paladin seals, Inner Fire/Fortitude/Power Word: Shield/Renew, Mage armor/Arcane Intellect/Ice Barrier/Mana Shield, Demon Armor/Demon Skin, Mark of the Wild, Lightning Shield and weapon imbues, Hunter aspects/Mend Pet, and Slice and Dice. A shared stabilization layer absorbs short Classic aura-API races and the stale near-expiry frame that can follow a successful refresh, preventing duplicate requests without hiding a genuinely removed aura.

The **Survival consumables strip** provides six secure click buttons for the best usable healing potion, Healthstone, mana potion, bandage, supported plain food and water currently in the bags. It shows quantities, cooldown sweeps/text, availability and restock state. Food/water support recovery between pulls; the original emergency-tool priorities remain available for combat danger.

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

#### Rogue leveling flow

The Rogue baseline targets ordinary leveling fights from the first learned abilities, including the first talent point at level 10. It does not wait for a complete endgame build or for Local Adaptive Tuning to learn a usable rotation.

- Read individual invested talent ranks by localized name across all three trees; refresh on login, talent updates and spell changes. Improved Sinister Strike affects the fallback energy cost (`45 / 42 / 40`), Improved Eviscerate modestly widens short-fight spending windows, and Improved Slice and Dice / Improved Gouge affect duration-dependent decisions. Actual client energy costs take precedence; learned Hemorrhage, Blade Flurry and Adrenaline Rush are not gated by the tree with the most points.
- Spend Eviscerate at four or more combo points, or earlier in finishing windows: on normal nearby-level NPCs, three CP at approximately `45%` target HP, two CP at approximately `30%`, or one CP at `12%`. Improved Eviscerate adjusts the three/two-CP HP thresholds by its damage bonus. A credible remaining lifetime of `6s` / `3s` also permits three/two-CP finishers; elite, much higher-level and player targets do not inherit the new normal-mob percentage shortcuts. The original two-CP / `22%` fallback remains available. These are leveling heuristics, not exact lethal-damage predictions. Required finishing windows cannot be displaced by tuning.
- Slice and Dice requires a missing buff, one or two CP, a credible remaining lifetime of at least `11s`, at least `10s` of useful buff duration, and enough energy left for the next builder. Unknown TTK is not evidence of a long fight. A small, target-scoped health trend also works with Combat logger off; target changes, healing and combat end reset that fallback.
- Builders use actual affordability and continue below `20%` target HP when a finisher is not appropriate. Healthy two-target pulls and moderate caution can retain offensive guidance; low-HP emergencies and dangerous multi-pulls still take precedence. Energy waits are explicit, and unmet requirements are not mislabeled as low energy.
- Gouge is affordable control, not a mandatory DPS cooldown. Proactive energy recovery requires solo melee pressure, suitable energy, enough target life and no detected Garrote/Rupture/Deadly Poison; it is suppressed in groups and against player targets. Improved Gouge can make a moderate-pressure window eligible. Kick remains the preferred interrupt; an affordable, in-range Gouge can substitute against a target facing the player when Kick is unavailable.
- A confirmed Gouge clears the recommendation/pixel while its actual control aura lasts, until `80` energy or an emergency. The cast-to-aura grace is only `0.20s`; misses, aura breaks, expiry and target changes cannot leave a full-duration phantom hold. Multiple attackers bypass the single-target pause. Gouge's secure slot/modifier macro stops rather than restarts auto-attacks.
- If no ability is available and the client confirms auto-attack is stopped, the HUD shows `ATTACK STOPPED / PRESS <BASE binding> ONCE` (for example, `PRESS BUTTON4 ONCE`). With no BASE binding it shows `CLICK BASE ONCE`. The hint requires a live, engaged target in confirmed melee range; it is suppressed during stealth, casts/channels and Rogue breakable control. Unknown attack/range data never becomes a restart request. The hint is withdrawn on the next refresh once attacks resume or another recommendation takes over; its pixel remains black and no new slot is allocated. Energy waits display `WAIT FOR ENERGY`, not a generic BASE-spam instruction.

**Stealth openings:** a learned, affordable, ready Ambush is a burst option only with a confirmed main-hand dagger; a dagger in the off hand is not sufficient. The HUD explicitly says `AMBUSH - BEHIND`: move behind the target yourself. Improved Ambush and Opportunity add bounded opener preference; actual client costs take precedence, with Dirty Deeds reflected in Garrote/Cheap Shot fallback costs. Cheap Shot retains required opening-control priority against difficult targets when available. Garrote remains a bleed alternative, with a reminder that its damage takes time and prevents a planned Gouge recovery pause. Known out-of-range spells are excluded. Without a usable opener, `CHECK OPENER` asks you to check energy, equipment and position rather than press BASE.

Ambush, Garrote and Cheap Shot use Stealth-only secure casts without a preceding auto-attack command. There is no reliable behind-target inference: positioning, weapon changes and the actual cast remain manual. Highest-learned-rank localized name casting is preserved. Rogue slots `1–17` and their bindings are unchanged; slot `18` is Ambush (default `CTRL+SHIFT+8`). Backstab is not added.

**Optional Pick Pocket:** enable **Options → Rogue - Stealth openers → Pick Pocket with openers** to prepend learned Pick Pocket to these three secure opener slots. It defaults **OFF**, persists account-wide in `HCOB_DB.roguePickPocket`, and resets to OFF with **Reset defaults**. Its conditions require out-of-combat Stealth and a live hostile target; BASE and other actions are unchanged. Each opener still requires your click/key press. Localized rank-free spell names are used; an unlearned or oversized optional line is omitted, preserving the opener and the secure macro limit. No cast sequence waits for successful pickpocketing, and no global loot setting is changed. Check Auto Loot and its modifier key: the macro attempts Pick Pocket but cannot guarantee collection before the opener. A resisted attempt can compromise Stealth. This is optional convenience, not a guaranteed safe pull or guaranteed extra loot. Secure macro changes made during combat are deferred until combat ends.

**Consistent Rogue input hints:** idle/no-target guidance says `SELECT TARGET`; normal pulls ask for a single BASE press. Remaining Rogue fallback hints no longer say to spam BASE. With Smart HUD disabled or in safe mode, `ADVISOR OFF / MANUAL CONTROL` does not infer that attacks need restarting. The existing binding-aware attack-stopped alarm and energy/control waits remain unchanged.

**Interrupts:** Kick checks known range and explicit interrupt immunity. When supplied by the client, target cast/channel timestamps reflect delays and updates; confirmed stops, failures and target changes clear obsolete casts. Recommendations are suppressed in the final `0.15s`. Classic Era targets without readable cast APIs retain a bounded combat-event fallback. Unknown immunity is not treated as confirmed immunity, and immunity to Kick does not automatically exclude a class-owned Gouge/control fallback; this is not a guarantee that control will land.

**Optional preparation:** with **Options → Pre-pull safety gate** enabled, an out-of-combat `CHECK GEAR` badge appears in the upper-right Advisor area when an equipped weapon skill trails its readable maximum by at least `10` points, or a weapon lacks a temporary coating after poisons are learned at level `20+`. Hover **BASE** for full advice, including the affected hand and skill values. A valid sharpening stone or other coating is not mislabeled as missing poison; the check does not identify the optimal poison. Missing APIs/data stay quiet. Checks are cached for up to one second and invalidated on relevant equipment/skill events. This badge never blocks `PULL READY`, replaces an action, plays a sound or creates chat reminders. It uses the existing persisted toggle; no extra setting or reset is needed.

Secure actions require the player's click or key press. During a Gouge recovery window, allow the pause to work rather than manually breaking it with another attack. Diagnostic Pixel and external readers are documented exclusively for passive observation, not input generation.

The restart request is a prominent amber notice covering the existing `282 x 82` Advisor area: `ATTACK STOPPED`, a large outlined `PRESS BUTTON4` (actual binding), and `ONCE TO RESUME ATTACK`. Only its thick border pulses slowly; the instruction stays fully readable. It follows HUD position/scale, fits long binding names, hides with the HUD/Advisor and does not cover BASE, HP/energy or DPS. Gouge, healing waits and higher-priority recommendations clear it. The diagnostic pixel is for the external reader, not the player's cue to resume.

With **Alert sounds** enabled, a distinct native sound accompanies the restart notice once when it appears, with at least `5s` between restart sounds. It does not repeat while the notice stays visible or when its binding label changes. Muted/hidden notices, Gouge and recovery waits do not play a restart cue; danger and interrupt sounds keep their separate throttles. This is an attention sound, not a spoken button name. No extra audio file or saved option is required.

Sinister Strike and learned Hemorrhage use fixed slots `1` and `2`, including when their Advisor key hint says `BASE`. Execute the suggested action with its secure button or binding. If attacks remain stopped during an energy wait, follow the one-press restart hint. The addon displays the BASE key bound in WoW; movement, facing and target selection remain manual.

**Example — ordinary pull, starting outside Stealth:** select a hostile target, move into melee range and press BASE once to start auto-attacks. Follow the supported SS/Hemorrhage and finisher suggestions; wait when the HUD asks for energy. If Gouge creates a control window, let it finish. Resume through the next offensive action, or press BASE once if the large restart notice appears. Movement and targeting remain manual. If Stealth has already been applied, BASE will not break it: use an appropriate opener instead of assuming the same one-press pull path.

The Rogue behavior has automated regression coverage for leveling decisions, talents, openers and control. No measured DPS/TTK improvement is claimed.

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

The strip contains six manual mouse-click actions, including [between-pull recovery](#between-pull-recovery):

| Slot | Selection policy |
|---|---|
| `HEAL` | Strongest healing potion in the bags that the current level can use |
| `STONE` | Strongest available Healthstone, including improved-rank item variants |
| `MANA` | Strongest mana potion in the bags that the current level can use |
| `BANDAGE` | Strongest available bandage |
| `FOOD` | Strongest usable supported plain-food tier; conjured preferred at equal tier |
| `DRINK` | Strongest usable water tier; conjured preferred at equal tier; N/A for non-mana classes |

Each slot shows its current quantity, cooldown and usability. Empty slots show `0`: the original four retain level-appropriate reference icons, while FOOD/DRINK use generic recovery icons. Usable food takes priority for out-of-combat HP recovery at 85% or below, with the original bandage/healing-item fallback when food is unavailable and recovery is not already active. Healthstone/healing potion priority in combat is unchanged; neither food/water nor bandages are recommended as emergency combat actions. The `Recently Bandaged` lock drives the bandage's unavailable state and full 60-second visual countdown as well as participating in readiness checks.

The buttons use WoW's protected item-action system. Their selected item ID is refreshed on login, bag/item-data changes, level changes and after combat. If bags change during combat, the old protected assignment remains authoritative until `PLAYER_REGEN_ENABLED`; visual counts and cooldowns can still update safely. HCOneButton never clicks, consumes or binds these items automatically.

Use `/hcob consumables` to print current assignments, `/hcob consumables on|off` to control visibility, or the **Survival consumables strip** checkbox in Options.

### Class-owned combat policy

The modular architecture keeps the central Advisor class-agnostic. Each class owns its own combat policy through `Classes/<Class>.lua`, including recommendation candidates, survival reserve, panic/multi-pull behavior, interrupt choice and class-specific secure macro policy.

The shared Advisor is responsible for context, scoring, hysteresis and final selection rather than hard-coding individual spells such as Serpent Sting, Overpower or Life Tap.

Maintained self auras follow one cross-class contract. They are never requested out of combat, keeping idle buff upkeep out of the HUD and diagnostic signal. In combat, missing maintenance can compete with the current class actions; an active aura is ignored until its final `10` seconds. Player spellcast acknowledgement and a bounded aura-observation cache absorb transient `UNIT_AURA` misses and stale pre-refresh durations. Proc auras, class forms, Stealth and hostile target debuffs remain contextual combat/opening mechanics rather than maintenance reminders.

For Paladin, Divine Shield is immediate at `25%` HP or lower. From `26%` through `35%`, it requires concrete lethal pressure: at least two active enemies, Survival Reserve at `28` or lower, or a confident estimated TTD of `6` seconds or less. Above `35%`, an unfavorable trend or a healthy 3+ enemy pull preserves Divine Shield and prefers Divine Protection, Hammer of Justice, healing or escape guidance. Lay on Hands retains priority at `18%` HP or lower.

For Warrior, preventive `UNFAVORABLE FIGHT` and controlled two-target escape guidance preserves enough Rage for Hamstring/control but no longer allows Rage to accumulate unused. Excess Rage passes through `Execute`, `Overpower`, `Mortal Strike`, `Bloodthirst`, `Whirlwind`, Cleave or `Heroic Strike` in that priority order before escape guidance resumes. The threshold starts at the greater of `40` or the configured `/hcob hsrage` value plus `5`, rises when Survival Reserve is critical and falls near the target's execute range. HP at `50%` or lower during a multi-pull and every 3+ enemy panic continue to preempt offensive spending. Heroic Strike and Cleave are offered only in the final `0.45–0.65` seconds before a tracked main-hand swing; an already queued strike suppresses the request immediately. Between `21–30%` target HP, queued dumps are pooled until `85` Rage when Execute is learned. Healthy controlled x2 pulls resume the core DPS scorer after Thunder Clap/Demoralizing Shout setup; those debuffs refresh only in their final `3` seconds.

### Coherent standalone windows

Options separates general appearance/behavior, combat data and learning, and Fixed Action Panel bindings. Only Warrior characters see `Warrior - Combat policy`, grouping `Smart pre-pull Rend`, `Situational Sunder` and the `Heroic Strike rage threshold` slider. Rogue characters see a separate Rogue-only `Rogue - Stealth openers` section for Pick Pocket. Other classes show neither section nor reserve its space. Utility buttons sit below the visible class section and remain separate from the explanatory footer; hidden class settings are preserved.

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
| 18 | Ambush |

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
│   ├── RoguePreparation.lua
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
│   ├── BagQuickDelete.lua
│   ├── AdaptiveTuning.lua
│   ├── Feedback.lua
│   └── DiagnosticPixel.lua
├── Systems/
│   ├── Bindings.lua
│   ├── Consumables.lua
│   ├── Recovery.lua
│   ├── BagQuickDelete.lua
│   ├── TuningTelemetry.lua
│   ├── TuningParticipation.lua
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

Fight schema `13` embeds adaptive telemetry contract `1`. The contract is shared by Warrior, Paladin, Hunter, Rogue, Priest, Mage, Warlock, Druid and Shaman: it stores anonymous build/policy signatures and combat context, selected and alternative candidates, input/action correlation, reaction/adherence, resource buckets and explicit eligibility filters. Learner revision `4` retains bounded `choiceEvidence` and displayed-choice `impact` fields, with stable role attribution and separate bounded pending executions. Raw target/cast identities and pending/recent snapshots are erased before finalization. Confirmed co-eligible player alternatives can qualify independently of the old adherence-percentage gate; all fight safety/context exclusions remain.

**New-fight sample quality:** every class records bounded `tuning.sampleQuality` participation evidence. Unknown/nonpositive target levels are not treated as easy enemies. Level, classification and maximum health are recovered only from an opponent actually observed in combat (including the player's pet), via the current target, its target or the pet's target. An unrelated selection cannot supply difficulty. Unresolved opponents are excluded from comparative DPS/adaptive learning. A first meaningful participation event later than both `4 seconds` and `25%` of the fight is also excluded as `late_participation`; outgoing/incoming damage or misses, hostile control/cast starts and effective healing count, while utility casts and pure overheal do not. This checks initial participation, not every idle interval; energy/control waits after engagement are not treated as late entry. Exclusion reasons are saved. Raw fight history, damage, duration and safety eligibility remain available; past fights and learned contexts are not retroactively rewritten or reset. Temporary opponent identity is removed during finalization.

### Diagnostics and fail-safe

| Command | Description |
|---|---|
| `/hcob errors` | Print errors intercepted by HCOneButton's runtime fail-safe. |
| `/hcob reseterrors` | Clear runtime fail-safe state and retry smart components. |
| `/hcob diagpixel on` | Show the diagnostic RGB pixel. |
| `/hcob diagpixel off` | Hide the diagnostic RGB pixel. |

---

## Diagnostic Pixel and external reader protocol

HCOneButton can expose a small diagnostic pixel intended for passive external diagnostics. A reader observes recommendation state only; this documentation does not describe input automation. Combat actions remain player-executed through WoW's secure buttons and bindings.

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

`HCOB_DB` and `HCOB_CombatLog` remain account-wide. `HCOB_CharacterDB` is stored in WoW's character-specific SavedVariables path and contains the anonymous telemetry profile, that character's session label and the versioned `adaptive` context store. Adaptive schema `2` preserves explicit opt-out and the inspection tab, with at most 24 contexts, 64 action-role records per context and 12 comparison situations per record. Version `1.29.11` uses learner revision `4` and preserves valid revision-3 comparisons; older aggregate-only coefficients are not promoted into comparative learning. Inspector grouping does not merge saved records. Deleting the account-wide `WTF/.../SavedVariables/HCOneButton.lua` resets addon configuration and shared fight telemetry; deleting the character-specific copy resets that character's anonymous profile and learner state. Back up files first to retain history.

`/hcob log clear` removes the active character's records in place; `/hcob log clear all` resets the complete combat-log table in place. Both preserve the live WoW SavedVariable identity across `/reload` and logout.

---

## Current baseline validation

Version `1.29.11` passes the following automated checks:

- **52/52 Lua chunks** pass syntax parsing in the current validation environment;
- **36/36 Lua 5.1 regression harnesses** pass through the shared `tests/run.ps1` runner;
- **53/53 TOC references** resolved (`52 Lua + Bindings.xml`);
- **19/19 offline Python release tests** pass, including inherited-runner-summary isolation and explicit validation/upload summaries;
- **250 wand checks** cover Priest/Mage/Warlock auto-repeat detection, real event dispatch, localized queries, missing/error API fallback, cooldown cycles, start/stop and range transitions, preserved efficiency scoring, healing/proc/cast/channel precedence and consistent BASE feedback;
- **114 Priest leveling checks** cover all three talent-tree classifications, early/mixed learned spells, rank/talent-adjusted mana costs and cast times, reserve boundaries, DoT lifetime, close casting, recovery priority, no-wand fallback and extreme adaptive biases; see `docs/PRIEST_LEVELING_REVIEW.md` for the policy review;
- threat-meter coverage verifies 48 API states across all nine classes, scaled versus raw percentage, 85% warning boundary, status-only fallback, unknown/restricted/invalid data, pet-first pulls, target/OOC reset, real DPS-history integration, saved visibility and shared-scale/layout clearance;
- 163 Bag Quick Delete checks use simulated inventories to cover standard/ElvUI click routing, complete-stack confirmation, stale identity/count rejection, protected items, missing data/APIs, cursor ownership, scale and lifecycle safety; no live inventory is modified;
- 192 focused recovery checks cover all nine classes, tier/level/conjured selection, secure single-edge use, active/full-resource/no-stock guards, localized auras, simultaneous eating/drinking, emergency precedence, frozen assignments and six-button layout;
- no duplicate TOC entry;
- SavedVariables lifecycle validation: account-wide and per-character bootstrap tables are replaced by the TOC-loaded globals at `ADDON_LOADED`, existing values are preserved and missing defaults are filled on the persistent table;
- malformed SavedVariables recovery, including invalid roots, settings, binding maps and combat-log structures;
- malformed adaptive action collections fail closed in the inspector, status command and offensive-bias lookup without crashing;
- Options layout tests instantiate all nine classes and verify Warrior/Rogue-only grouping, setting persistence/reload/reset, deferred secure updates, slider-label spacing and CTA/footer separation; inspector tests verify the visible baseline legend and its reserved space;
- fresh-install binding-path verification: auto-bind defaults to enabled and is applied during `PLAYER_LOGIN`;
- all nine deterministic class layouts remain within the 20-slot limit, without duplicate action IDs or missing spell constants;
- Advisor stability/range regression coverage: transient normal recommendations are discarded, sustained changes commit after confirmation, safety escalation remains immediate, global cooldown does not force a swap, localized learned-spell range overrides incomplete rank-1 metadata, explicit ranged BASE contracts remain protected, and friendly/melee actions are excluded from ranged warnings;
- Warlock pull-safety regression coverage verifies that BASE pet attack requires combat and the former unconditional out-of-combat pet command is absent;
- binding-save regression coverage: account/character binding sets remain unchanged, while `0`, `nil`, invalid values and API failures safely fall back to set `1` without passing an invalid argument to `SaveBindings`;
- SavedVariables lifecycle coverage verifies normal `ADDON_LOADED` rebinding, direct `PLAYER_LOGIN` fallback, preservation/defaults, malformed-root repair and all login initialization hooks;
- character-scoped telemetry coverage verifies anonymous profile filtering across different classes and same-class alts, legacy class fallback, current-version DPS averages, per-character retention, current-character clearing and explicit account-wide clearing;
- adaptive telemetry coverage verifies the all-class contract, anonymous build/policy context, stabilized decisions and alternative candidates, secure input versus confirmed action, reaction/adherence, resource-mode separation, pet/combo/hidden-mana context, bounded traces, generic class metrics, adaptive-store repair and PvP/eligibility exclusion;
- attribution regressions cover stabilized roles across all nine classes, Heroic Strike/Cleave queue events and input ordering, slow swings, learned-rank damage/misses through the real combat-log handler, interleaved duplicate confirmations, five caster-class fixtures, interruption/expiry/target invalidation, failed repeated inputs and runtime-identity cleanup;
- inspector regressions cover distinct-spell grouping, expandable details, opposite correction ranges, legacy preservation without invented comparisons, malformed IDs, evidence-based status, OFF/PvP isolation, profile-switch expansion reset and matching slash/visual state;
- Local Adaptive Tuning coverage verifies preserved opt-out and observations, context/migration isolation, explicit PvE/PvP inspection, 4+4 comparison gates, changed decisions across all nine class policy examples, real Warrior Clap/Sunder eligibility, cast-hold attribution, manual alternatives, same-spell role deduplication, special-route cold/OFF equivalence, emergency/pet protection, invalid-state and malformed-store rejection, resource/overkill objectives, frame-independent impact counters, live inspector/fixed-row rendering and reset/navigation behavior. The development review record is in the repository's `docs/ADAPTIVE_REVIEW.md` (not part of the addon package);
- all nine class modules load in isolation and expose the required Advisor/secure-macro contracts; ranged BASE recognition, hybrid melee transitions, macro size and Warrior/Warlock safety invariants are checked;
- all nine deterministic Action Panel layouts are checked for stable slot counts, known/unique spell IDs, the 20-slot limit, unique default keys and Diagnostic Pixel V3 encodability;
- Doctor report coverage verifies BASE/range API probes, macro/pet/binding/SavedVariables diagnostics, slash-command dispatch, error containment/path sanitization, privacy exclusions and absence of SavedVariables mutation;
- consumable/readiness coverage verifies level-safe best-item selection, improved Healthstone variants, combat/OOC healing priorities, low HP/mana/energy and pet gates, tough-target stock/healing/escape cooldown warnings, `Recently Bandaged`, unavailable-item highlight suppression, secure deferred assignment and universal melee `PULL READY` integration;
- active-cast coverage verifies that channels, helpful casts and non-instant offensive casts clear the next recommendation until the current action ends, after which rotation guidance resumes;
- 81 target-cast checks cover live casts/channels, Classic shifted API signatures, delay/expiry, stop versus stale API data, old same-spell stop events, target changes, bounded combat-event fallback and shared interrupt/control contracts across all nine classes;
- 182 Rogue checks include dagger versus non-dagger/empty-hand equipment, learned openers, talent-aware costs, range/immunity, optional localized Pick Pocket macros and length limits, low skill/coating advice, API failures, caching and existing leveling decisions; 136 Advisor checks cover wand start/active/wait/disabled-HUD feedback, the gear badge, preserved action text, passive opener/disabled-Advisor hints and restart display/audio;
- 113 participation checks cover all nine classes, observed-opponent recovery, unknown/API-failed levels, elite classification, pet/healing/control participation, late-tag boundaries, runtime-identity cleanup and the full logger lifecycle. Excluded fights remain in history and older records are untouched;
- Paladin survival-policy coverage verifies the `25%` immediate Divine Shield boundary, conditional `26–35%` pressure gates, six-second lethal forecast, Lay on Hands priority and preservation of Divine Shield during moderate trends or healthy multi-pulls;
- Warrior escape-Rage coverage verifies low-Rage Hamstring priority, excess-Rage spending, proc/core/queued-strike ordering, controlled two-target spending and strict panic preemption at low HP or 3+ enemies;
- Warrior multi-pull coverage verifies defensive-debuff refresh boundaries, healthy x2 return to the core DPS scorer, low-reserve escape preservation and stance/equipment-aware Retaliation and interrupt selection;
- Warrior swing-queue coverage verifies the adaptive Heroic Strike/Cleave window, immediate queue suppression, special hit/miss timer reset, first-swing fallback, Execute pooling/release boundaries, slot-20 Cleave priority and queue-safe secure actions;
- Rogue leveling coverage verifies first-point talents/respec, localized rank-safe costs/macros, mixed-tree learned actives, early finishers, affordable Slice and Dice, logger-independent target trends, Gouge affordability/control/range/expiry and immediate pause display, emergency precedence and protected finishing windows under tuning. Restart-hint coverage checks actual attack state, unknown data, range/control/cast guards, immediate withdrawal and the real HUD/pixel renderer with changed or missing bindings and no-spam energy waits. The development checklist is in `docs/ROGUE_LEVELING_REVIEW.md` (repository only);
- cross-class aura coverage verifies combat-only maintenance for Paladin, Priest, Mage, Warlock, Druid and Shaman, healthy-aura suppression, the final-ten-second refresh boundary, Warrior Battle Shout policy, Hunter/Rogue aura guards, rank-safe cast acknowledgement, stale refresh metadata and bounded player/pet aura-miss debouncing;
- Diagnostic Pixel acknowledgement coverage verifies rank-safe cast matching, an observable `60 ms` black edge at 50 Hz, suppression of an already-computed next suggestion during that edge and same-slot re-emission afterward;
- TOC order, referenced files, runtime/TOC/documentation version parity and packaged README/CHANGELOG/LICENSE consistency are checked automatically.

Release-specific historical validation belongs in [`CHANGELOG.md`](CHANGELOG.md). Two Priest review/refinement passes, the user-confirmed in-game smoke test and the regression checklist are recorded in `docs/PRIEST_LEVELING_REVIEW.md`; earlier review records remain in `docs/WAND_REVIEW.md`, `docs/RECOVERY_REVIEW.md`, `docs/BAG_QUICK_DELETE_REVIEW.md`, `docs/ROGUE_FOLLOWUP_REVIEW.md`, `docs/ROGUE_1296_REVIEW.md`, `docs/ROGUE_LEVELING_REVIEW.md` and `docs/ADAPTIVE_REVIEW.md` (repository only). Automated checks cover simulated APIs and do not establish a measured DPS improvement.

---

Curated public notes are in `docs/releases/1.29.11.md` (repository only). Publication uses the GitHub Release body unchanged as the CurseForge file changelog; an accepted upload is distinct from CurseForge moderation approval.

## License

This project is intended to be distributed under the **MIT License**.

See [`LICENSE`](LICENSE) for the full license text.

---

## Disclaimer

HCOneButton is an independent community addon and is not affiliated with or endorsed by Blizzard Entertainment.

World of Warcraft and Blizzard Entertainment are trademarks or registered trademarks of Blizzard Entertainment, Inc.
