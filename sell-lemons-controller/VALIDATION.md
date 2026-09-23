# Validation / 2026-09-23

Source: supplied Sell Lemons Autofarm 3.3.3. Migrated top-level lexical bindings using the Luau AST; runtime components use an explicit context instead of dynamically rewriting global environments. No Acro/Luarmor code was executed.

Passed:

- Deterministic `tools/build.py --check` against source/integrity manifest.
- Luau bytecode compilation of 38 files: 34 source components, two loaders, controller and standalone diagnostic.
- 12 numeric/catalogue/observation/recovery-policy scenarios.
- 8 supervisor scenarios, including repeated +1 work requesting a timely review without abandoning a partial pass, cancellation of recovery by manual pause, and no auto-resume during ambiguous transactions.
- Full component initialization, diagnostic report, missing-data handling, idempotent unload, and listener cleanup in a minimal mock engine.
- 3 AntiIdle cleanup/exclusion fixtures, including camera removal between press and release.
- 4 loader fixtures: success, HTTP 401, HTTP 404 and cancellation during a request. The mock asserts the GitHub destination and that authorization is cleared after completion; no real token was used.
- 4 data-inspection fixture groups: formatted cash and exclusions, fresh resampling, explicit limits, and missing-root handling.
- 4 rebirth-confirmation fixture groups: disabled origin with a ready matching dialog, countdown waiting, changed economy cancellation, and rejection of mismatched/stale/undispatched sessions. These are a simulated regression sequence, not a successful live rebirth.

Observed in the user's current Roblox player log on September 23 (UTC+5):

- 05:16:35: controller 4.0.0-dev loaded.
- 05:17:04: inspectData ran successfully. Its original LocalPlayer-only scan inspected 24 objects; found unlock flags, purchase counters and Cash as an omitted string. No current rebirth/evolution amounts were established.
- 05:20:31: controller reported a completed eight-stand pass, 104 purchases and 7,449 levels. This is client log evidence, not independent server-side reconciliation.
- 05:22:02: controller opened a rebirth confirmation then cancelled the intent with REBIRTH_BUTTON_LOCKED. The origin readiness check was reused while a modal owned input. The patch uses the matching, ready confirmation button at this stage while retaining fresh bank/reward, intent, and evolution guards. In-game retesting of this patch is still required.

Not passed / not performed:

- Full static type inference: standalone Luau lacks Roblox globals, and inference also exceeds its complexity budget in migrated legacy strategy code. Compilation above succeeded; this is not a claim of a clean typecheck.
- Successful live reset after the patch, the real gateway notice, minimized operation, AFK duration, visual QA in the Roblox renderer, or a real private HTTP download through the user's Lua environment. Launch and purchase evidence is limited to the log observations above.
- Headless game-state integration and concurrent upgrade transactions. The current adapter still requires GUI navigation for authoritative readings and actions.

This is a development release, not a verified always-optimal or always-running controller.
