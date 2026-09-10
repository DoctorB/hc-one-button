# Bag Quick Delete — 1.29.8 review record

Date: 2026-09-10. Scope: an optional, player-clicked, single-stack bag deletion shortcut. No live inventory was modified. Two local review/refinement passes were performed; no independent reviewer or in-game validation is claimed.

## Pass 1 — destructive action and compatibility boundaries

- Checked contemporary Blizzard Classic container templates and the ElvUI registered item-widget layout. Integration uses an independent mouse overlay; no global secure handler or existing bag OnClick script is replaced or invoked by the delete path.
- Restricted resolution to registered standard `ContainerFrameNItemN` widgets and ElvUI's actual `ElvUI_ContainerFrame.Bags[bag][slot]` member. Use widget slot IDs, not visual item indices. Reject banks, arbitrary addon widgets and invalid bag/slot coordinates.
- Only a paired right mouse-down/up can begin a request. Keep non-right mouse buttons on the original widget through pass-through. Red DEL identifies the armed gesture; no overlay or OnUpdate polling remains after modifier release.
- Gray deletion goes directly from a hardware click; higher qualities need an addon confirmation. Preserve Blizzard's own dialogs/restrictions. Confirmations re-read bag, slot, hyperlink, item ID, count, quality and inventory revision. No queued deletion, bulk operation, automatic retry or cursor clearing.
- Refinements: contain failed popup creation and unavailable/restricted mouse APIs; stop the feature for the session rather than retain an input blocker or emit repeated errors. Combat/death/logout events cancel immediately without waiting for unit flags to update.

## Pass 2 — lifecycle, metadata and regression checks

- Strengthened missing-data rejection: unreadable lock/loot flags and unknown quest status are not treated as safe. Require cached quality, class and bind type, protect quest/quest-bound items and Hearthstone, and reject occupied cursor/spell targeting.
- Confirmed bag revision invalidation also handles same-ID replacement, frame reuse, stack-count changes and bag updates between mouse-down/up. Confirmation callbacks are identity-bound and consumed once. Native popup ownership/cursor is left intact on API failure.
- Screen-coordinate overlay positioning respects different bag/UI scales without parenting or anchoring to secure bag frames. Closed bags, loss of hover, changed modifiers and unexpected UI failures remove the overlay. Dynamic lookup supports ElvUI initialized after HCOneButton without load-order dependency.
- Options remains 700 x 760; ten general checkboxes fit before the existing class section, and utility/binding CTAs remain clear of the footer. The new option appears for all classes, uses an account-wide boolean, defaults OFF, repairs malformed values to OFF and is disabled by Reset defaults.
- No combat rotation, learner, action binding, pixel encoding, workflow or secret modification is included.

## Automated validation

- Lua 5.1 parse: 51/51 addon chunks.
- Lua harnesses: 33/33, including 163 Bag Quick Delete checks using simulated inventory only.
- Existing nine-class contracts, Options, SavedVariables, combat, tuning, pixel and threat regressions pass.
- TOC references: 52/52 (51 Lua plus Bindings.xml); package allowlist: 56 files.
- Offline Python release pipeline: 19/19 tests. Root/package README and CHANGELOG must be identical.

Commands: `./tests/run.ps1` and `python -B -m unittest discover -s tests -p test_release_pipeline.py`.

## Pending in-game smoke test

Use disposable items only, and perform the same checks separately with standard bags and the installed ElvUI version:

1. Confirm fresh upgrade defaults OFF and ordinary use/equip, left-click and drag are unchanged.
2. Enable the option, `/reload`, verify ON persists. Hold Ctrl+Alt (no Shift): DEL should align with the hovered item at different UI/ElvUI scales.
3. Delete a disposable gray stack with one right-click. Verify its complete count disappears, not a different slot, and the cursor is empty after success.
4. Request a disposable white stack, verify name/count and cancel/Escape. Repeat and accept. Check native confirmations/restrictions on higher quality without using valuable gear.
5. Move/sort items while a confirmation is open: it must cancel. Retry with a fresh click. Check an already occupied cursor, an identified quest item, Hearthstone and a locked/loot-containing item do not get deleted.
6. Enter combat or die with an addon confirmation open: it must cancel. Turning the option OFF or Reset defaults must also remove the overlay and cancel it.
7. Release modifiers, close bags and check `/hcob errors`; no input blocker, taint error, repeating warning or changed ordinary click behavior should remain.

Publication as a Release was requested on 2026-09-10. Live validation remains pending and is disclosed in public notes. API mocks cannot certify every native deletion restriction, mouse dispatch order, third-party skin or ElvUI version. Do not claim a successful actual deletion from pcall success alone; the code intentionally prints no unverified deletion-success message.

## Source/API references inspected

- [Blizzard Classic bag template](https://github.com/Gethe/wow-ui-source/blob/classic/Interface/AddOns/Blizzard_UIPanels_Game/Classic/ContainerFrame.xml)
- [Blizzard Vanilla bag scripts](https://github.com/Gethe/wow-ui-source/blob/classic/Interface/AddOns/Blizzard_UIPanels_Game/Vanilla/ContainerFrame.lua)
- [Container API signatures](https://github.com/Gethe/wow-ui-source/blob/classic/Interface/AddOns/Blizzard_APIDocumentationGenerated/ContainerDocumentation.lua)
- [Mouse pass-through API](https://github.com/Gethe/wow-ui-source/blob/classic/Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleScriptRegionAPIDocumentation.lua)
- [ElvUI bag-widget layout](https://github.com/tukui-org/ElvUI/blob/main/ElvUI/Game/Shared/Modules/Bags/Bags.lua)
- [Dejunk manual destruction service](https://github.com/moody/Dejunk/blob/master/src/services/destroyer.lua)

These were used to verify API/interface expectations, not imported as addon code. HCOB's cursor ownership checks and confirmation policy are its own implementation.
