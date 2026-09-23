# Validation / 2026-09-23

Source: supplied Sell Lemons Autofarm 3.3.3. Migrated top-level lexical bindings using the Luau AST; runtime components use an explicit context instead of dynamically rewriting global environments. No Acro/Luarmor code was executed.

Passed:

- Deterministic `tools/build.py --check` against source/integrity manifest.
- Luau bytecode compilation of 48 files: 38 controller components, three standalone diagnostic/probe sources, two loaders, controller and four standalone tools.
- 12 numeric/catalogue/observation/recovery-policy scenarios.
- 8 supervisor scenarios, including repeated +1 work requesting a timely review without abandoning a partial pass, cancellation of recovery by manual pause, and no auto-resume during ambiguous transactions.
- Full component initialization, diagnostic report, missing-data handling, idempotent unload, and listener cleanup in a minimal mock engine.
- 3 AntiIdle cleanup/exclusion fixtures, including camera removal between press and release.
- 4 loader fixtures: success, HTTP 401, HTTP 404 and cancellation during a request. The mock asserts the GitHub destination and that authorization is cleared after completion; no real token was used.
- 4 public request-loader fixtures: success without HttpGet, function fallback when request is a table, HTTP rejection before compilation, and compile failure before execution. No credentials attached.
- 9 finish-forecast regression groups. The price-order x10 scenario first failed against the old runtime (optimistic scenario incorrectly acquired FINISH); after the patch it stays an estimate. Cases cover paid-before-effective bonuses, actual gate ordering without mutating the ledger, funded completion without rate data, fresh income invalidation, receipts preserving the deadline, prompt review of an unaffordable tail, retaining the current pass, cash-funded recovery, and preserving a ready evolution. These are offline scenarios, not a completed live Halo.
- 11 direct-upgrade probe groups for v3: a runtime where all game-module require calls fail, scheduling before waiting, owned enabled identities and initial zero levels, pending exclusions, duplicate identity rejection, replicated-level receipts, RPC rejection, reset counters (including previously absent counters), owner changes, and timeout with late completion. This standalone one-round transport probe leaves affordability to the server and is not part of the controller.
- 4 data-inspection fixture groups: formatted cash and exclusions, fresh resampling, explicit limits, and missing-root handling.
- 4 rebirth-confirmation fixture groups: disabled origin with a ready matching dialog, countdown waiting, changed economy cancellation, and rejection of mismatched/stale/undispatched sessions. These are a simulated regression sequence, not a successful live rebirth.
- 8 replicated-state fixture groups using the numeric values observed in the live log: independent encoding calibration, hidden updates and huge exponents, bank isolation, reset invalidation, unknown zero sentinel, linear encoding/mismatch revocation, ownership loss, and absent attributes.
- 6 standalone action-capture fixture groups: absent/broken capabilities, exactly-once passthrough with nil arguments/results, scope/cycle/redaction limits, original errors/yields, ownership loss/manual cleanup, timeout/later-hook preservation. Startup sends no game remote. The user's Xeno subsequently reported absent capture capabilities; no actual game call was captured.

Observed in the user's current Roblox player log on September 23 (UTC+5):

- 05:16:35: controller 4.0.0-dev loaded.
- 05:17:04: inspectData ran successfully. Its original LocalPlayer-only scan inspected 24 objects; found unlock flags, purchase counters and Cash as an omitted string. No current rebirth/evolution amounts were established.
- 05:20:31: controller reported a completed eight-stand pass, 104 purchases and 7,449 levels. This is client log evidence, not independent server-side reconciliation.
- 05:22:02: controller opened a rebirth confirmation then cancelled the intent with REBIRTH_BUTTON_LOCKED. The origin readiness check was reused while a modal owned input. The patch uses the matching, ready confirmation button at this stage while retaining fresh bank/reward, intent, and evolution guards. In-game retesting of this patch is still required.
- 05:32:22 and 05:32:25: standalone probe identified the local base via Owner as Workspace/Tycoon2. Values/Values contained Evolution=5, Ascension=23, Rebirths=5, TotalRebirths=1099, TotalEvolves=161. Raw Cash changed from 208.3515191634644 to 208.3551277583843. Raw Investors stayed 65.63493889154753; eight stand-level attributes were present. This establishes replicated candidates and a changing Cash attribute; it does not establish the encoding or pending reset rewards. Both scans reported truncation in broader branches.
- 05:32:17: original running controller logged UNLOADED. The two diagnostic samples did not restart it or verify the rebirth patch.
- 05:42:45: 4.0.1-dev reported Cash=log10 matching raw 208.7737529124466 and GUI 5.939 e208. At 05:43:05 Investors=log10 matched raw 65.63493889154753 and GUI 4.315 e65. This verifies observed calibrations in the log, not the entire adapter.
- 05:42:46 through 05:42:48: Xeno v1.3.60 supplied no firesignal candidate, getconnections probes failed, and VirtualInput succeeded. Purchases were therefore still using the GUI path. Headless actions and parallel upgrade dispatch have not been implemented.
- 05:43:58: FINISH_PROJECTED_CATALOGUE_ROUTE selected with 271 rows remaining and 50.69 modeled seconds, despite the disabled conditional-finish policy. Later BUY/WAIT_GROWTH loops persisted until the user paused at 05:45:02. This is the observed forecast failure; 4.0.2 removes the override and bounds the commitment.
- 05:58:20: standalone action capture reported hookmetamethod=false, getnamecallmethod=false, decompile=true, getscriptbytecode=true, then UNSUPPORTED. No game action was sent or captured.
- 06:04:44: a staged loader test reported HTTP=false before compilation. Prior one-line launches failed with attempt to call a table value. At 06:07:52 the request-based loader successfully launched the client inspector; it reached DONE at 06:07:57.
- 06:07:52: the new owned base was Workspace.Tycoon3, with INTERNAL_STAND_KEYS LemonStand despite the displayed Lime name. Upgrade RemoteFunctions and ClientTycoonUpgrades/TycoonUpgrades/UIManageTileEarner modules were found. All ten decompile attempts returned Bytecode version (12) unhandled, so no signature was recovered. Inspector v2 can export bounded bytecode for five specific handler modules for offline inspection; that fallback is not yet live-tested.
- 06:13:25 and 06:18:33: bounded bytecode exports succeeded. Nine distinct module blobs passed length and Adler32 verification. A local read-only parser based on official Luau Bytecode.h/lvmload.cpp parsed v12; one opcode interpretation passed structural checks throughout each file. UIManageTileEarner calls Earner:Upgrade(info.Count, true); ClientTycoonEarner.UpgradeAsync calls the stand's UpgradeRemote:InvokeServer(count or 1); RemoteRequest forwards the same arguments to the RemoteFunction. GetUpgradePrice returns price and count; future direct batches must reconcile replicated levels. No bytecode was executed locally. The new probe's live call remains untested.

Not passed / not performed:

- At 06:26:36 (UTC+5), direct probe v1 failed before sending a purchase: ClientTycoonEarner could not be required from Xeno's script context. V2 uses tagged instances and recorded levels instead, with no game-module require; live purchase acceptance is pending. It also exports pricing dependencies for local reading.

- Full static type inference: standalone Luau lacks Roblox globals, and inference also exceeds its complexity budget in migrated legacy strategy code. Compilation above succeeded; this is not a claim of a clean typecheck.
- Successful live reset after the patch, the real gateway notice, minimized operation, AFK duration, visual QA in the Roblox renderer, or a real private HTTP download through the user's Lua environment. Launch and purchase evidence is limited to the log observations above.
- Sustained reliability of replicated-state encoding calibration, pending reset reward/evolution readiness without menus, and concurrent upgrade transactions. Initial Cash/Investors matches are recorded above; later Cash calibration churn means sustained reliability is not established. GUI navigation remains necessary for unknown fields and current actions.

This is a development release, not a verified always-optimal or always-running controller.

At 06:38:52 (UTC+5), v2 ran without require errors but sent no requests: the new owned Tycoon7 had an empty upgrade map. TycoonUpgrades.GetLevel explicitly returns zero for an absent key. V3 handles that initial state and checks the nearest Tycoon.Purchasable ancestor Enabled attribute. Seven pricing dependencies exported successfully; the observed 340421-byte Balance exceeded v4 limits, so v5 permits up to 393216 bytes only for that exact module. Live v3 purchase acceptance remains pending.

## 4.0.3 direct upgrade integration

- 06:42:20 (UTC+5): the standalone direct probe sent Upgrade(1) for LemonStand and observed replicated level 2 -> 3. No UI-input function exists in that probe. This proves one direct purchase, not an eight-stand batch.
- 06:44:12: Balance export succeeded, 340421 bytes, Adler32 914084511. Literal table construction recovered 18997 upgrade prices across eight stands. No serialized function was called; unsupported expressions remain symbolic. Config supplied AscensionPenalty=3.33 and UpgradeStack caps 1/5/25/100/MAX.
- Production now includes GameBalance, UpgradeMath and DirectUpgrades (38 components). Upgrade passes reserve shared cash before parallel dispatch and reconcile each exact level delta; reset/owner/quote changes and unknown InversionCard price modifiers block spending. Rebuild passes carry the same direct-mode identity.
- Offline checks cover literal prices, independent cumulative sums, Halo scaling, the post-table price formula, affordable maxima and exponents beyond normal floats. Mock-engine cases cover simultaneous multi-level purchases with shared-cash accounting, zero wallet, no GUI access, late cancellation, rejected/silent replies and reset during dispatch. These checks do not establish live performance or complete-game success.
- Main build purchases, investor-power purchases and resets still use GUI. Full headless operation, new-runtime acceptance and concurrent live upgrades are not yet verified. `live_roblox_tested=false` applies to the complete 4.0.3 controller, not the separately confirmed +1 probe.


## 4.0.4 direct Powers / Buy and live-state regression

- Real 4.0.3 run at 07:02–07:03 (UTC+5) matched all initial bytecode fingerprints but paused with INVERSION_PRICE_STATE_UNAVAILABLE before its stand batch. This is a failed acceptance, not a successful production upgrade run.
- The 07:11 read-only action export recovered 28 client modules with contiguous offsets and matching checksums. InstanceTable.new's optional flag creates an empty detached Configuration on a client when the replicated configuration is absent; GetAll reads its attributes and recognized children. Main-world absent InversionCards with no inversion now follows that observed empty state. Nonzero/malformed inversion remains unverified and blocked.
- Added exact Balance PurchasePrices/PurchaseOrder and Config investor-power prices. Powers and Buy use no game-module require, mouse, UI click, menu visibility, or forever-purchase flag. All participating modules are fingerprinted before dispatch. Reset/reward menus remain.
- Offline fixtures cover real missing-card layout, Buy order/localized names, exact replicated ownership receipts, two Buy steps without GUI, stale quotes, rejected/silent RPCs, reset during dispatch, timeout and late cancellation; Powers tests cover permanent plus temporary levels, exact level increments, fresh funds and cumulative investor retention. All prior forecast and supervisor regressions pass.
- Full live 4.0.4 acceptance is pending. Concurrent stand speed, direct Powers and Buy success, and a complete Halo cycle are not established by offline mocks.
