# Situational Adaptive Tuning — review record

Status: release preparation for 1.29.2. Local learner revision 3, SavedVariables
schema 2, additive telemetry contract-1 fields. Release artifacts are generated
under the ignored `release/` directory; this review record stays in the repository.

## Acceptance criteria

- Safe choices previously excluded solely by their tag can enter learning.
- Confirmed co-eligible choices, not repeated frames or spell-usage counts,
  provide comparative evidence. At least four chosen and four alternative
  fights are needed in a situation, plus eight fights in the build context.
- A learned preference can reverse a meaningful baseline priority gap.
- OFF/cold behavior and required emergency decisions retain their baseline.
- The user can distinguish a stored coefficient from a changed displayed
  choice and from a changed choice they actually executed.
- Observations remain local, bounded and separated by character/build. Old
  coefficients are not silently enlarged. All recorded situations remain
  inspectable independently of current target selection.

## Review cycle 1 — evidence and decision effect

Implemented the comparative learner, situational policy, wider bounded score
range, persistent rows and actual-choice counters. Reviewed the entire path
from candidate selection through recommendation, successful action and fight
finalization, rather than testing the learner with counters alone.

Findings and refinements:

- A spell can occupy both a proc and normal-damage role. Deduplicate canonical
  spell IDs in each opportunity; one spell is not its own alternative.
- The old adherence gate rejected genuine player alternatives. A confirmed
  cast of another eligible action now supplies evidence without requiring the
  player to agree with the Advisor. Uncorrelated manual casts do not qualify.
- Instant-only attribution lost casts during the nil cast hold. Retain a
  bounded pending choice through that hold, clear it on emergencies/target
  change, and erase transient identity before finalization.
- Decision impact must count recommendation transitions and confirmed actions,
  not polling samples. Duplicate source events cannot count as extra executions.
  Differences caused only by visual stabilization (including with tuning OFF)
  must not be counted as adaptive interventions; this has a regression test.

Validation: nine class-policy scenarios traverse real Engine, TuningTelemetry
and AdaptiveTuner code and learn to reverse a six-point baseline gap. OFF,
emergency precedence, resource-situation isolation and cast-hold correlation
are asserted. The class scenarios are controlled fixtures, not in-game DPS data.

## Review cycle 2 — integration, safety and inspectability

Findings and refinements:

- Direct multi-pull/pre-escape spell returns bypassed the scorer. Safe routes
  now expose already-eligible alternatives, while retaining their original
  winner until a qualified preference changes it. Absent/protected actions
  remain untouched and cannot leak stale candidate snapshots.
- Healthy player HP alone does not make Mend Pet optional. Low/unknown pet HP
  retains fixed recovery priority. Invalid/non-finite health/reserve and
  malformed comparison buckets fail closed.
- Wider coefficients must not inherit old aggregate correlations. Preserve
  observations but require new two-sided evidence; enforce sample gates at
  both runtime lookup and display.
- The objective discounts player/pet overkill and Rage/Energy-cap waste, with
  a health-floor veto on positive preferences.
- The impact card has only 220 pixels of width. Use three explicit short
  lines; keep the original frame geometry, navigation and footer separation.
  Situation labels and fixed/comparison rows have dedicated UI-mock checks.

Validation: existing suite plus `tests/adaptive_situations.lua`; actual Warrior
candidate generation admits safe Thunder Clap/Sunder while a healthy Thunder
Clap debuff still removes the action. Special-route cold/OFF equivalence,
malformed state, choice eligibility, resource/overkill inputs and UI rendering
are tested. Lua 5.1 parser and repository/package-doc parity checks also run.

Final automated result: 46/46 addon Lua files parsed, 25/25 harnesses passed,
47 valid TOC references, matching root/package README and changelog, clean
whitespace check. These checks do not substitute for the in-game steps below.

## Final release review

- Checked the scoring, pending-cast, finalization and inspector paths again.
- Fixed an actual API fallback mismatch: `UnitHealthPct("pet")` may return
  `100, false` for unreadable data. The learner now preserves that distinction
  and cannot classify Mend Pet as optional merely because of the fallback.
- Normalize finite numeric safety values before comparing thresholds.
- Preserve safe recovery-cast attribution through `RECOVERY ACTIVE`, just as
  through offensive cast/channel holds. An unrelated action still cannot
  become evidence, and the original expiry/target checks remain mandatory.
- Added regression assertions for all three cases. Runtime/TOC versions and
  current docs are aligned to 1.29.2; historical release sections are retained.

## Remaining validation in game

1. Back up SavedVariables, install 1.29.2 and verify preserved ON/OFF
   preference, positions and Options/inspector navigation.
2. Play ordinary safe fights. Previously recorded spells should remain visible
   with zero correction while awaiting new comparable choices. Do not provoke
   dangerous pulls to generate samples.
3. Inspect the per-situation 4+4 counts and fixed-action explanations. Reopening,
   selecting another target and reloading must not hide recorded situations.
4. When corrections qualify, compare the Advisor explanation and changed /
   executed counters. Switching OFF must remove new learned score effects.
5. Verify natural cast holds, queued swings, buff/debuff refreshes and existing
   safety behavior; repeat on more than one class.

This validates observable behavior, not causal benefit. A higher observed DPS
or a changed suggestion alone does not prove an improvement. The model still
uses end-of-fight observational outcomes, does not learn new spell eligibility
or spell-specific timing/resource thresholds, and does not train out-of-combat
openers. Missing comparative evidence legitimately leaves a situation unchanged.
