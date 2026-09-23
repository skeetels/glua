# Validation / 2026-09-23

Source: supplied Sell Lemons Autofarm 3.3.3. Migrated top-level lexical bindings using the Luau AST; runtime components use an explicit context instead of dynamically rewriting global environments. No Acro/Luarmor code was executed.

Passed:

- Deterministic `tools/build.py --check` against source/integrity manifest.
- Luau bytecode compilation of all 34 source components, private loader and bundled controller.
- 12 numeric/catalogue/observation/recovery-policy scenarios.
- 8 supervisor scenarios, including repeated +1 work requesting a timely review without abandoning a partial pass, cancellation of recovery by manual pause, and no auto-resume during ambiguous transactions.
- Full component initialization, diagnostic report, missing-data handling, idempotent unload, and listener cleanup in a minimal mock engine.
- 3 AntiIdle cleanup/exclusion fixtures, including camera removal between press and release.
- 4 loader fixtures: success, HTTP 401, HTTP 404 and cancellation during a request. The mock asserts the GitHub destination and that authorization is cleared after completion; no real token was used.

Not passed / not performed:

- Full static type inference: standalone Luau lacks Roblox globals, and inference also exceeds its complexity budget in migrated legacy strategy code. Compilation above succeeded; this is not a claim of a clean typecheck.
- Roblox launch, purchases, resets, the real gateway notice, minimized operation, AFK duration, visual QA in the Roblox renderer, or a real private HTTP download through the user's Lua environment.
- Headless game-state integration and concurrent upgrade transactions. The current adapter still requires GUI navigation for authoritative readings and actions.

This is a development release, not a verified always-optimal or always-running controller.
