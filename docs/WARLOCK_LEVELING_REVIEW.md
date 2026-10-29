# Warlock leveling — review

Date: 2026-10-28. Request: check the Warlock policy and improve it where needed.
Scope: class policy, single-press BASE, pre-pull pet readiness, one Action Panel slot, focused
regression tests and documentation. Released in 1.29.21 (2026-10-28) without an in-game check.

## Baseline findings

- `close` (CheckInteractDistance ~10 yards, or a melee hit on the player in the
  last 2.5 s) excluded Shadow Bolt, Immolate, wand and Drain Soul even while the
  pet held the mob. A warlock standing near its Voidwalker had only DoTs and
  Drain Life left.
- Drain Soul scored 82, below the finishing wand (73–93), so it was almost never
  recommended with a wand equipped and Soul Shards were not farmed.
- Shadowburn (91–99) spent the last Soul Shard on any target below 24%.
- A tanking pet at 24% HP or less raised Drain Life, which heals only the player.
  Health Funnel was not in the spell catalog.
- Without a wand, Shadow Bolt stopped below 28% target HP and below 42% mana.
  The generic fallback then asked for BASE, i.e. the same declined Shadow Bolt.
- Out of combat the only suggestion was Life Tap; with a wand BASE the pull
  opened with a single wand tick.
- Spell Lock was offered whenever the Felhunter had it, including on cooldown.
- Pre-pull readiness reported a missing/hurt Warlock pet as text only.

## New policy

1. `exposed = close and (mob on player or pet not tanking)` replaces `close` for
   Shadow Bolt, Immolate, wand and Drain Soul. Survival logic (Death Coil, Curse
   of Weakness, Fear, Drain Life, Life Tap) is unchanged.
2. Drain Soul scores 95 at target HP <=12% while below five Soul Shards, above
   the finishing wand and below Shadowburn at <=14% target HP.
3. Shadowburn requires more than two Soul Shards, unless survival reserve <45.
4. Health Funnel (score 88–104) when the pet tanks at <=40% HP, player HP >=55%,
   the mob is not on the player, target HP >20% and reserve >=45. Drain Life
   keeps the critical-pet trigger only when Health Funnel is not learned.
   Death Coil and other survival actions still outrank it.
5. Without a wand: Shadow Bolt at mana >=30% and at any target HP; when nothing
   qualifies in combat the Advisor shows `LET DOTS AND PET WORK / WAIT / RECOVER`.
   Wand users keep the 42% gate and the shared wand fallback.
6. Out of combat with a hostile target: Life Tap first (mana <=45%, HP >=82%),
   otherwise Shadow Bolt opener (mana >=35%), otherwise Corruption opener.
   The BASE macro is unchanged: pet attack stays combat-gated.
7. Spell Lock is skipped while `GetPetActionCooldown` reports it cooling down;
   without that API the previous behavior is kept.
8. Readiness asks `Class:GetPetRecoverySpell`: Summon Voidwalker with a shard,
   otherwise Summon Imp, for a missing pet; Health Funnel for a hurt pet.
9. Health Funnel is appended as Action Panel slot 16; existing slots are unchanged.

## Single-press BASE

Follow-up request: with the pixel reader in use, Shadow Bolt should come from
the Advisor rather than from BASE spam, as for the Warrior single-press BASE.

- Spamming a Shadow Bolt BASE overrode the Advisor (mob on the player, mana
  kept for Fear/Death Coil, Drain Soul, Health Funnel, wait states) and its
  casts delayed the slot key the reader presses.
- BASE is now `/petattack [combat,harm]` plus `/cast [harm] !Shoot` in every
  tree when a wand is equipped (Destruction included); without a wand it is
  only the pet command. `GetBaseActionInfo` returns `nil, "PET ATTACK"`;
  `IsRangedBaseAction` is false; the BASE button uses a pet-attack icon through
  the new optional `GetBaseIcon` class hook. Doctor no longer warns about a
  missing BASE spell when the class describes a spell-less BASE.
- Without a wand, out of combat with no affordable opener the Advisor shows
  `NO OPENER READY / WAIT / RECOVER` instead of `PULL READY / PRESS BASE`.
- `PET NOT ATTACKING / PRESS BASE ONCE` (no spell, so the pixel stays black;
  caution, score 96) appears after one continuous second when the living pet
  is not on the target, the mob is not on the pet, and only one enemy is
  active. Multi-mob fights are excluded because the pet may tank another mob
  while the warlock DoTs its own target. Leaving combat resets the timer.

## Verification

- 57/57 addon Lua chunks parse; 47/47 Lua 5.1 harnesses pass.
- New `tests/warlock_leveling.lua` (101 checks) drives the real Warlock module and
  Engine selection: pet-held vs exposed proximity, Drain Soul vs wand, Shadowburn
  shard reserve, Health Funnel vs Drain Life/Death Coil, no-wand filler and idle,
  openers, Spell Lock cooldown, pet recovery spells, single-press BASE in all
  trees with and without a wand, and the pet-off-target notice.
- `tests/consumables_readiness.lua` covers the Warlock readiness hook;
  `tests/wand_transitions.lua` keeps its "no class candidate" case by making the
  close mob not pet-held; `tests/action_panel_layout.lua` expects 16 slots;
  `tests/class_contracts.lua` checks the wand/pet-only Warlock BASE.

These are simulated-client tests, not DPS measurements.

## In-game checks to do

- Voidwalker tanking with the warlock 5–10 yards away: Shadow Bolt/wand still
  suggested; mob switching to the warlock: they disappear.
- Low-health target with fewer than five shards: Drain Soul, and a shard gained.
- Pet at 30–40% while tanking: Health Funnel, and Drain Life not suggested.
- No wand, low mana: `LET DOTS AND PET WORK` rather than a BASE request.
- Before a pull: Shadow Bolt opener, then BASE sends the pet after combat starts.
- BASE pressed repeatedly never casts Shadow Bolt; Destruction with a wand starts
  the wand; without a wand BASE only sends the pet.
- Opening with a cast and not pressing BASE: after about a second the amber
  `PRESS <key> ONCE` notice appears; one press sends the pet and clears it.
- Pet tanking an add while you DoT another mob: no pet notice.
- Felhunter: Spell Lock disappears from interrupt advice while on cooldown.

## Follow-up: BASE is the decision to pull

Date: 2026-10-29. Owner feedback on 1.29.21: selecting a target must not pull;
the rotation starts only after BASE, and the pet must attack at once on that
press, as for the Hunter. Released in 1.29.22 (2026-10-29) without an in-game check.

- Cause: out of combat the Advisor showed the Shadow Bolt/Corruption opener (an
  Action Panel slot) as soon as a hostile target was selected, so the pixel
  reader cast it; BASE was `/petattack [combat,harm]` and did not send the pet
  before combat. A wand user also got `PULL READY` with Shoot, another slot.
- BASE is now `/petattack [harm]` (plus `!Shoot` with a wand), as for the Hunter.
- Out of combat, the opener is offered only once the player has engaged: a BASE
  press on this target (recorded by the new optional `OnBaseInput` class hook
  from the BASE `PostClick`, by target GUID) or the pet already on the target.
  Before that the Advisor shows `PULL READY / PRESS BASE` without a spell, so
  the pixel stays black. Pre-pull Life Tap is still offered since it does not
  pull. Entering combat clears the mark; the next pull needs a new press.
- `tests/warlock_leveling.lua` (128 checks) covers the fresh target with and
  without a wand, Life Tap before the pull, the BASE press starting the opener,
  a new target needing a new press, engaging without a pet, non-hostile presses
  and the reset at combat start. `tests/class_contracts.lua` and
  `tests/advisor_stability_range.lua` now require the ungated pet attack.
  47/47 harnesses pass.

In-game checks to do:

- Target a mob out of combat: nothing is cast, the panel shows `PULL READY`.
- Press BASE: the pet runs in at once and Shadow Bolt (or Corruption) appears.
- With a wand: BASE sends the pet and starts Shoot; no Shoot before the press.
- After the kill, target the next mob: again nothing until BASE.
