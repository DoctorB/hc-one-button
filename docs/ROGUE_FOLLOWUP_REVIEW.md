# Rogue follow-up and all-class sample quality — 1.29.7 release review

Date: 2026-09-09. The maintainer requested version bump and publication after
being informed that in-game verification is still pending. Version 1.29.7 is
prepared as an ordinary Release, with this limitation disclosed in its public
notes. Earlier smoke tests are not reused as validation of these changes.

## Evidence and scope

- Inspected the supplied account and Rogue SavedVariables as literal data,
  without executing their Lua or modifying the original files.
- In the current-character 60-fight sample, 14 fights started without readable
  target metadata and were learned as easy because target level was zero.
  One short group fight included Skinning before a late damage event; the
  resulting full-duration DPS was not a representative rotation sample.
- Residual generic BASE-spam guidance appeared in 58 of those 60 fights.
- These observations justify quality/input-hint fixes, not a claimed DPS gain
  or an arbitrary change to the Rogue's combat priorities. Historical tuning
  evidence and coefficients are retained, not silently rewritten or reset.

## Review cycle 1 — behavior and compatibility

- Optional learned Pick Pocket is prepended only to the three existing Rogue
  secure opener macros: Ambush, Garrote and Cheap Shot. BASE is unchanged.
- Require explicit opt-in, out-of-combat Stealth and a live hostile target
  for the optional cast. Preserve learned localized rank-free names; omit the
  optional line if it would exceed the secure macro limit or the opener is
  unlearned. Never add a cast sequence, start auto-attack first, manipulate
  loot CVars or introduce external gameplay input.
- Spell/loot execution remains a client-side live-test requirement. The
  option explains Auto Loot and its modifier, possible resistance/Stealth
  loss and the fact that collection before the opener is not guaranteed.
  A failed Pick Pocket does not become a cast-sequence gate, but loss of
  Stealth can still prevent the opener's own Stealth condition from passing.
- Rogue idle/pull/fallback guidance no longer requests BASE spam. The printed
  plan heading is class-aware. Other classes retain their existing contract.
- New fights acquire level/classification/max-health metadata only from an
  observed opponent, not an unrelated selected unit. Damage/misses in either
  direction, pet activity, hostile control/cast starts and effective healing
  establish participation. Pure overheal and utility cast success do not.
- Reject unresolved opponents and late initial participation (strictly more
  than 4 seconds AND 25% of duration) from DPS/adaptive learning. Known elite
  classification remains meaningful with an unknown numeric level. Unknown
  legacy/direct-contract levels get an unknown difficulty bucket, not easy.
- This is an initial-entry heuristic, not an active-time DPS rewrite or a
  detector for every idle interval. Long energy/control waits after engagement
  are not rejected as late entry. Existing safety exclusions remain intact.

## Review cycle 2 — failure paths, persistence and integration

- Found and fixed overlapping Options utility buttons after adding the Rogue
  section. Both Warrior and Rogue sections now reserve their vertical space;
  the description, controls, report CTA and full-width footer stay separate.
- Found that Reset defaults needed to rebuild secure macros as well as change
  the saved checkbox. Added a rebuild using the existing combat-defer path.
- Checked account-wide opt-in at SavedVariables initialization, malformed
  preference repair to OFF, reload, checkbox refresh and combat-time changes.
- Removed the initial Rogue spam text. Disabled Smart HUD/safe mode now says
  MANUAL CONTROL rather than falsely implying readiness or stopped attacks.
- Removed the temporary opponent GUID before later telemetry finalization
  can fail; tested a deliberately malformed later resource bucket.
- Tested actual combat-event routing across all nine classes, unknown/API-
  failed target metadata, an ally's target, later unrelated target selection,
  boss classification, pet-first events, healing and exact late-entry bounds.
- Exercised the real logger start/sample/finalize/store lifecycle. Recovered
  metadata reaches the learner; excluded late tags still enter raw history;
  historical records retain their identity and values.

## Automated checks

- `./tests/run.ps1`: 49/49 addon Lua files parse; 32/32 harnesses pass;
  50/50 TOC references resolve (49 Lua files and Bindings.xml).
- Rogue: 182 checks; Advisor hints/UI/audio: 97 checks; new all-class
  participation suite: 113 checks. Existing nine-class regressions pass.
- `python -B -m unittest discover -s tests -p test_release_pipeline.py`:
  19/19 offline release-tool tests pass, with no upload or credentials.
- Root/package README and changelog remain identical; TOC/runtime/fallback
  versions agree at 1.29.7. Interface 11509, fixed slots, passive Pixel V3
  encoding, learner revision 4,
  adaptive schema 2 and telemetry contract 1 remain unchanged. The additive
  sample-quality fields apply only to newly recorded fights.

## Pending in-game smoke test

1. On a Rogue, open Options and check the new class section at small and large
   HUD scales; verify utility buttons, explanatory text and footer clearance.
2. Confirm Pick Pocket defaults OFF. Enable it, close/reopen Options and
   `/reload`; verify it stays enabled. Reset defaults must disable it and
   remove it from the existing secure opener macros without a reload.
3. With a learned opener and Pick Pocket, Stealth behind an appropriate NPC
   and manually press the opener's existing binding/button. Test with your
   real Auto Loot/modifier settings; verify both the opening and actual loot.
   Check each available opener and a target without pockets in a safe context.
   Do not assume a failed/resisted attempt is harmless in Hardcore.
4. Verify no-target, friendly/dead target, PULL READY, energy waits and Smart
   HUD OFF do not request Rogue spam. Check that the real attack-stopped notice
   still appears only when needed and uses the current BASE binding.
5. Record normal solo/group fights plus one late group entry. After saving
   with `/reload`, inspect quality reasons and learned outcomes. A normal
   known-target fight can qualify; a late/unknown sample remains in history
   but does not teach the comparative learner. No in-game success or measured
   DPS/TTK improvement is claimed by the automated tests above.
