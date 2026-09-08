# Rogue preparation and interrupt context — 1.29.6 release review

Scope: incremental leveling improvements without new player combat logs. This
review covers learned Stealth openers, optional weapon preparation advice and
shared target-cast context. It does not claim measured DPS/TTK gains. The prior
Rogue baseline and 1.29.5 smoke-test record remain in `ROGUE_LEVELING_REVIEW.md`.

## Review cycle 1 — eligibility and compatibility

- Checked the real Rogue scorer, spell-cost helpers, secure macros, fixed slot
  layout, shared interrupt path and existing class contracts.
- Appended Ambush at Rogue slot 18; slots 1–17 are unchanged. Slot 18 retains the
  existing V3 color `(216, 96, 224)` / `#D860E0` and default `CTRL+SHIFT+8` key.
- Required a readable main-hand weapon class/subclass before suggesting Ambush.
  An off-hand dagger, empty main hand or unreadable item API cannot qualify it.
- Preserved learned spell/cost/cooldown/range checks and localized rank-free
  casts. Improved Ambush/Opportunity contribute bounded preference; Dirty Deeds
  adjusts fallback Garrote/Cheap Shot cost. Client cost information wins.
- Kept difficult-target Cheap Shot priority, explained Garrote's bleed versus
  Gouge recovery tradeoff, and used Stealth-only macros with no preceding
  auto-attack. Without an eligible opener, CHECK OPENER remains passive.
- Refined direct-interrupt immunity versus control: Kick should not be
  suggested against an explicitly uninterruptible cast, but that flag alone
  does not establish immunity to Gouge, Hammer of Justice or other existing
  class-owned control fallbacks. No universal NPC control-immunity classifier
  was added.
- Added tests through the real Rogue module and shared wrapper, preserving
  all existing nine-class regressions and emergency behavior.

## Review cycle 2 — adverse APIs, event ordering and UI

- Classic signatures may omit the interruptibility flag and shift spell ID
  left. A numeric ID is never truth-tested as immunity; unknown stays unknown.
- Readable live target casts/channels use actual start/end times. Classic Era
  APIs can return nil for other units, so the bounded combat-event fallback
  remains when no live API cast was observed. Removed its extra 0.35s grace.
- Preserved cast identity across refreshes. A delayed stop for an earlier cast
  cannot clear a newer same-spell cast. A confirmed stop suppresses stale
  positive API data; target changes and combat end invalidate cached context.
- Tested channels, delayed end times, expired/unreadable data, missing GUIDs,
  fallback expiry and the final 0.15s interrupt cutoff. Energy is not reserved
  indefinitely for hypothetical future casts.
- Kept weapon advice optional under the existing persisted pre-pull toggle,
  out of combat and alive only. Warn at a readable skill deficit of at least
  ten points; deduplicate the same skill across hands. Cache scans for up to
  one second and invalidate on equipment/skill updates.
- Require level 20+ and learned poisons before coating advice. Recognize the
  Classic nil/false no-enchant convention, inspect only equipped weapons and
  accept other valid coatings. API failures stay quiet; zero charges alone do
  not prove a missing coating. Advice does not select the best poison.
- Checked the CHECK GEAR label's reserved upper-right area and the BASE tooltip.
  The badge preserves the action/reason, highlight, diagnostic signal and sound
  behavior; it clears when hidden or no longer applicable. It never changes
  PULL READY and requires no SavedVariables migration or new setting.
- Corrected test-fixture state leakage and nil fallback assumptions uncovered
  during review; retained targeted regression cases for the runtime edge cases.

## Final automated validation

- `./tests/run.ps1`: 48/48 addon Lua chunks parse, 31/31 Lua harnesses pass and
  49/49 TOC references resolve (48 Lua files plus Bindings.xml).
- Rogue: 151 checks; Advisor UI/hint/audio: 85 checks; target casts: 81 checks.
- Shared coverage includes all nine classes; the new target-cast suite tests
  class-contract forwarding and interrupt/control distinctions, not a live
  simulation of every class against every NPC.
- `python -B -m unittest discover -s tests -p test_release_pipeline.py`: 19/19
  offline release-tool tests pass, without credentials or network use.
- Runtime/TOC/fallback/current documentation versions agree. Root/package
  README, CHANGELOG and LICENSE match; the package allowlist contains 53 files.
- Two commits separate the functional change from version/documentation work.

## In-game status and retained checklist

**Pending for 1.29.6.** On 2026-09-08 the maintainer explicitly chose publication
as an ordinary Release rather than a draft or Beta, with this limitation in the
public release notes. The 1.29.5 smoke test is not reused as validation of the
new code. Automated tests cannot fully reproduce Classic client events, secure
frames, localized API results, bindings or every HUD configuration.

Use ordinary safe targets; do not deliberately create dangerous Hardcore pulls.

1. On a Rogue with learned Ambush, check a main-hand dagger versus another
   weapon, including an off-hand-only dagger. In Stealth, position behind a safe
   target and manually use the suggested opener; confirm slot 18 and old keys.
2. Confirm BASE preserves Stealth and CHECK OPENER appears when requirements are
   unmet. When relevant abilities are learned, check Garrote/Cheap Shot guidance
   and the existing Gouge recovery/restart flow without breaking control early.
3. Check naturally occurring enemy casts: Kick in range, completed/interrupted
   casts, target changes and readable channels. Verify no stale interrupt hint
   after a cast stops; record an exception rather than assuming every channel
   or immunity is exposed by the client.
4. If a weapon skill naturally trails its cap, check CHECK GEAR and the BASE
   tooltip. At level 20+ with poisons learned, verify each equipped hand before
   and after coating; a valid sharpening stone should not count as uncoated.
5. Disable/enable Pre-pull safety gate and reload: the existing choice persists.
   Confirm the badge stays out of combat, never blocks PULL READY, creates no
   new sounds/chat, and clears after fixing the condition.
6. Check HUD scales 0.7/1.0/1.6, visibility, dragging/reload and BASE tooltip
   readability. Check `/hcob errors`; retain a report if something disagrees.

## Player-input and release boundaries

HCOneButton recommends; the player executes secure clicks/key presses. Movement,
rear positioning, equipment changes and casts remain manual. Diagnostic Pixel
and an external reader are documented only for passive observation. No external
executable, input generator or gameplay-data upload is part of this change.

Public notes are `docs/releases/1.29.6.md`; publication uses the existing
authorized GitHub Release → CurseForge workflow. A successful upload receipt
confirms acceptance, not moderation approval. Local ZIP preparation does not
upload anything. Previously published release bodies are not edited by this
documentation cleanup.

## API and spell references checked during implementation

- [ClassicCastbars source](https://github.com/wardz/ClassicCastbars/blob/master/ClassicCastbars/ClassicCastbars.lua): Classic target/channel API limitations and fallback handling.
- [Original Classic API signature report](https://github.com/Stanzilla/WoWUIBugs/issues/184): omitted interruptibility field and shifted spell ID.
- [Ambush spell data](https://www.wowhead.com/classic/spell=8676/ambush), [Garrote spell data](https://www.wowhead.com/classic/spell=703/garrote) and [Kick spell data](https://www.wowhead.com/classic/spell=1766/kick): ability requirements and baseline costs, not empirical performance evidence.
