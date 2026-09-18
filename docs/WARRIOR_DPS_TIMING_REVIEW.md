# Warrior mitigation and DPS timing review

## Scope

Mitigation and display-timing changes prepared for 1.29.15 following the September 18 Warrior log review. No tuning reset. The subsequent dynamic efficiency comparison is documented separately in [WARRIOR_DPR_REVIEW.md](WARRIOR_DPR_REVIEW.md); the initial observations below are not a measured damage increase.

## Findings and decisions

- Equal target level previously qualified as a tough fight and could request Demoralizing Shout at full player health. The new normal mitigation gate requires proven melee reach plus a multi-pull, elite/world boss, or recent incoming melee at <=60% health. A negative or unknown melee-range response suppresses the AoE suggestion. The conservative reach proxy is Heroic Strike, not a self-centered spell's range result.
- Repeated successful shouts do not prove repeated aura application: an AoE can spend Rage before the target is close enough. Range checks address that path; two-second cast acknowledgement and a bounded 0.75-second aura-read grace address transient application/read gaps. Other players' same-name debuffs also count. These protections are target-specific and do not hide a real resist/removal indefinitely.
- Critical-health handling, interrupts, queued Heroic Strike/Cleave budgets and secure macros are unchanged. The later DPR pass separately introduces a likely-finisher threshold override and dynamic optional-spender ranking.
- The recorded 311-damage fight ended offensively at 10.228s but remained flagged in combat until 16.502s. The new meter distinguishes these intervals rather than interpreting a numerical increase as improved combat performance.
- Only confirmed deaths of all observed engaged enemies stop the display timer. Living enemies, swing/cast/resource/CC waits, escapes and incomplete encounters are not trimmed. An additional enemy resumes the full interval including the intervening gap. Player death and interrupted recording retain the full interval. Player/pet damage share the same clock.

## Fight Club DPR reference

Read-only inspection of the user-provided `Copia di Fight Club DPR Sheet (by SAKUJ0 and Beanna).xlsx`, including formulas and cached values. The original workbook was not modified or exported.

- `How To Use!A7:A16` describes a leveling DPR comparison, preset per-level stats/gear and effective Rage costs. This is not an endgame-only reference or an observed DPS benchmark.
- `Theorycraft!F4:G4` and `Damage!H4:I4`: Heroic Strike's incremental damage is compared with the cast cost plus the foregone white-swing Rage, not with a fictitious independent full weapon hit.
- `Theorycraft!F8:G8`, `Damage!H11:I11` and `Comments!B7:B10`: Sunder's modeled value is offensive armor reduction, proportional to remaining target health. It must not automatically inherit Demo Shout's defensive gate or be delayed while reserving Rage for an unqueued Heroic Strike. A preliminary extra Sunder delay/budget restriction was therefore removed before completion. Existing remaining-health/time eligibility, aura suppression and protection of an already queued strike remain.
- The model is parameterized, not restricted to level 55: `Damage!B1` selects the level, and `Damage!W5:W14` contains separately selected talent ranks. For example, `Damage!H4` uses both the selected level's white-swing Rage and the Improved Heroic Strike rank in `W6`. A character's level must not be used to infer invested talent points.
- `Damage!B1` is currently saved as 55; `LevelDB!C18:R18` contains level-16 preset stats and a different weapon. Selected talents and preset NPC armor/health are not the current character's measurements. Several exported formulas use `__xludf.DUMMYFUNCTION` with saved fallback values, including the incremental damage in `Damage!I4`. Some ordinary formulas retain working input references, but changing the level cell alone is not verified recalculation of the complete exported XLSX. This export limitation does not invalidate the original parameterized model.
- Current Warrior affordability/queued-strike budgets already query the localized learned spell's client-reported Rage cost, including talent discounts. If neither cost API answers, the fallback is the conservative undiscounted cost. This accounts for cost modifiers, not every talent's effect on relative damage efficiency. A complete DPR comparison would also need actual learned ranks, invested talents, current weapon/stats and explicit target assumptions, without double-counting bonuses already included by the client.
- No workbook rank is assumed learned merely because the character meets its level requirement. No preset weapon, talent allocation or saved DPR output is imported into gameplay. The follow-on DPR model uses a labeled armor estimate when needed and remains a focused comparison, not a complete port.

## Compatibility

Fight schema 14 adds `damageDuration` and `damageDps`. Existing `duration`, `dps`, damage/overkill and safety measurements keep their full-combat definition. The learner still consumes those original fields. HUD, recent averages and log display use the separate display metric, with the original denominator for legacy records. Feedback reports label both. Temporary opponent identifiers are removed before storage; existing history, learned contexts, options and bindings are preserved.

## Review and verification

The first pass covered eligibility, cast/aura state, live/final display and preserved learning inputs. The second pass added real HUD integration, player/pet spell and periodic-damage routing, chain-pull and death/escape boundaries, legacy compatibility and the recorded timing reproduction. Warrior regressions explicitly preserve early offensive Sunder and ensure only an already queued strike reserves its budget.

Run `tests/run.ps1` for the complete Lua 5.1 parse/regression suite. Focused cases live in `tests/warrior_mitigation.lua`, `tests/damage_meter_timing.lua` and the HUD section of `tests/threat_meter.lua`. Automated checks establish policy/timing behavior under simulated client APIs, not a causal DPS/TTK gain.

Final combined validation: 57/57 addon Lua chunks parsed, 43/43 Lua suites passed (including 173 DPR, 66 mitigation and 118 timing checks), and 19/19 offline release-tooling tests passed. `git diff --check` is clean. Root/package README and changelog copies match.
