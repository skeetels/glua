# Validation / 2026-09-23

Source: supplied Sell Lemons Autofarm 3.3.3. Migrated top-level lexical bindings using the Luau AST; runtime components use an explicit context instead of dynamically rewriting global environments. No Acro/Luarmor code was executed.

Passed:

- Deterministic `tools/build.py --check` against source/integrity manifest.
- Luau bytecode compilation of 41 files: 35 controller components, one standalone capture source, two loaders, controller and two standalone diagnostics.
- 12 numeric/catalogue/observation/recovery-policy scenarios.
- 8 supervisor scenarios, including repeated +1 work requesting a timely review without abandoning a partial pass, cancellation of recovery by manual pause, and no auto-resume during ambiguous transactions.
- Full component initialization, diagnostic report, missing-data handling, idempotent unload, and listener cleanup in a minimal mock engine.
- 3 AntiIdle cleanup/exclusion fixtures, including camera removal between press and release.
- 4 loader fixtures: success, HTTP 401, HTTP 404 and cancellation during a request. The mock asserts the GitHub destination and that authorization is cleared after completion; no real token was used.
- 4 data-inspection fixture groups: formatted cash and exclusions, fresh resampling, explicit limits, and missing-root handling.
- 4 rebirth-confirmation fixture groups: disabled origin with a ready matching dialog, countdown waiting, changed economy cancellation, and rejection of mismatched/stale/undispatched sessions. These are a simulated regression sequence, not a successful live rebirth.
- 8 replicated-state fixture groups using the numeric values observed in the live log: independent encoding calibration, hidden updates and huge exponents, bank isolation, reset invalidation, unknown zero sentinel, linear encoding/mismatch revocation, ownership loss, and absent attributes.
- 6 standalone action-capture fixture groups: absent/broken capabilities, exactly-once passthrough with nil arguments/results, scope/cycle/redaction limits, original errors/yields, ownership loss/manual cleanup, timeout/later-hook preservation. Startup sends no game remote. Real Xeno hook support and visibility of game-script calls remain untested.

Observed in the user's current Roblox player log on September 23 (UTC+5):

- 05:16:35: controller 4.0.0-dev loaded.
- 05:17:04: inspectData ran successfully. Its original LocalPlayer-only scan inspected 24 objects; found unlock flags, purchase counters and Cash as an omitted string. No current rebirth/evolution amounts were established.
- 05:20:31: controller reported a completed eight-stand pass, 104 purchases and 7,449 levels. This is client log evidence, not independent server-side reconciliation.
- 05:22:02: controller opened a rebirth confirmation then cancelled the intent with REBIRTH_BUTTON_LOCKED. The origin readiness check was reused while a modal owned input. The patch uses the matching, ready confirmation button at this stage while retaining fresh bank/reward, intent, and evolution guards. In-game retesting of this patch is still required.
- 05:32:22 and 05:32:25: standalone probe identified the local base via Owner as Workspace/Tycoon2. Values/Values contained Evolution=5, Ascension=23, Rebirths=5, TotalRebirths=1099, TotalEvolves=161. Raw Cash changed from 208.3515191634644 to 208.3551277583843. Raw Investors stayed 65.63493889154753; eight stand-level attributes were present. This establishes replicated candidates and a changing Cash attribute; it does not establish the encoding or pending reset rewards. Both scans reported truncation in broader branches.
- 05:32:17: original running controller logged UNLOADED. The two diagnostic samples did not restart it or verify the rebirth patch.
- 05:42:45: 4.0.1-dev reported Cash=log10 matching raw 208.7737529124466 and GUI 5.939 e208. At 05:43:05 Investors=log10 matched raw 65.63493889154753 and GUI 4.315 e65. This verifies observed calibrations in the log, not the entire adapter.
- 05:42:46 through 05:42:48: Xeno v1.3.60 supplied no firesignal candidate, getconnections probes failed, and VirtualInput succeeded. Purchases were therefore still using the GUI path. Headless actions and parallel upgrade dispatch have not been implemented.

Not passed / not performed:

- Full static type inference: standalone Luau lacks Roblox globals, and inference also exceeds its complexity budget in migrated legacy strategy code. Compilation above succeeded; this is not a claim of a clean typecheck.
- Successful live reset after the patch, the real gateway notice, minimized operation, AFK duration, visual QA in the Roblox renderer, or a real private HTTP download through the user's Lua environment. Launch and purchase evidence is limited to the log observations above.
- Live acceptance of the new replicated-state integration and its encoding calibration, pending reset reward/evolution readiness without menus, and concurrent upgrade transactions. GUI navigation remains necessary for those unknown fields and current actions.

This is a development release, not a verified always-optimal or always-running controller.
