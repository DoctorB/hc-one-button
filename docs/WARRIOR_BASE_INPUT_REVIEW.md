# Warrior single-press BASE review — 1.29.20

## Finding

Warrior BASE was `/startattack [harm]`, Charge out of combat and, on targets
judged worth it when the macro was rebuilt, `/castsequence [combat,harm]
reset=target/combat Rend, null`. Heroic Strike was never part of it. In combat,
repeated presses therefore did nothing after the first Rend: auto-attack was
already on and the sequence sat on `null`. Melee abilities pressed from their
slots start auto-attack anyway. The HUD nevertheless asked for `SPAM <key>` /
`KEEP SPAMMING`.

The BASE Rend also coupled the Advisor to the spam: while it was in the macro
(`currentWarriorAutoRend`), the Advisor withheld its own Rend. A player who
stopped spamming lost Rend entirely, and the macro decision ignored target
lifetime and the DPR model.

The only real need for BASE after the pull is restarting a stopped attack with
no affordable strike, typically after tabbing to the next mob with little Rage.

## Contract

- BASE: `/startattack [harm]` and `/cast [nocombat,harm] Charge`. No Rend, no
  modifier branches (unchanged since 1.29.14), no Heroic Strike.
- Advisor Rend: no longer gated by the macro; governed by `warriorAutoRend`
  (UI **Smart opener Rend**, default ON, saved key unchanged). Existing opener
  rules apply: level/efficiency gate, seven-second window, Execute pooling,
  queued-strike budget, DPR override.
- Restart request (`NeedsAutoAttackRestart`): in combat, live hostile target in
  combat, no cast/channel/recovery hold, Heroic Strike range check exactly
  `true`, and the shared `AutoAttackActive()` read exactly `false`. It is only
  evaluated after the scorer finds no candidate. Output: nil spell,
  `ATTACK STOPPED / PRESS BASE ONCE`, kind `action`, reusing the Rogue HUD
  notice, sound and black pixel.
- Settled states (`GetSettledRecommendation`, after pull/ranged routes):
  `SELECT TARGET` without a hostile target; `OUT OF MELEE RANGE / ADJUST
  DISTANCE` when reach is known false; otherwise `AUTO ATTACK / LET IT RUN`.
  Risk warnings decorate it like the former `BASE OK`.
- Execute pooling key becomes `LET IT RUN`.
- Advisor UI, tooltip, `/hcob plan` and BASE label treat Warrior like Rogue
  (single press). Other classes keep their BASE texts.

## Verification

`tests/warrior_base_input.lua` (50 checks) runs the real Warrior, engine,
spell utilities and macro builder: BASE content for normal/elite targets with
the option on/off, restart true/false/unknown, reach unknown/out, unengaged
target, cast hold, `C_Spell` fallback and missing API, funded-strike priority,
no-target/pooling/risk states and the Advisor Rend with option and window.
`tests/advisor_input_hints.lua` (172 checks) renders the Warrior states on the
real HUD and pixel, including the notice and its withdrawal. The Rogue suite
keeps passing on the shared attack-state read.

These are simulated-client tests, not an in-game result.

## In-game checklist

1. Pull with one BASE press: Charge, attack. Do not press BASE again; confirm
   Rage builds and the HUD shows `AUTO ATTACK / LET IT RUN` with nothing funded.
2. Confirm the Advisor highlights Rend early on a durable target and that
   **Smart opener Rend** OFF removes it.
3. Kill a mob next to another one, tab to it with low Rage: the amber notice
   asks for one press and disappears after it. It must not appear while out of
   reach, during a bandage, or on a mob not yet in combat.
4. With an affordable strike the strike is highlighted, not the notice.
