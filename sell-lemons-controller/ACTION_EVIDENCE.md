# Direct action evidence, 2026-09-23

Status: signature recovered from the user's running game; production integration and live acceptance are separate steps.

The request-based public loader successfully ran in Xeno. `game:HttpGet` failed before compilation; `hookmetamethod` and `getnamecallmethod` were absent. `decompile` existed but returned an unsupported-bytecode error. `getscriptbytecode` exported the selected client modules successfully.

Exports were reconstructed locally only after contiguous offsets, byte lengths and Adler32 checks matched. A read-only parser based on [Luau's instruction definitions](https://github.com/luau-lang/luau/blob/master/Common/include/Luau/Bytecode.h) and [serialization reader](https://github.com/luau-lang/luau/blob/master/VM/src/lvmload.cpp) decoded version 12. One opcode mapping passed the structural checks for each module. Platform trailer bytes were retained as opaque data. Nothing was executed by the parser.

| Module | Bytes | Adler32 | Relevant observation |
|---|---:|---:|---|
| UIManageTileEarner | 7606 | 176204229 | Click handler passes the calculated Count to Earner.Upgrade, with local feedback enabled. |
| ClientTycoonEarner | 9539 | 1200172661 | Constructor binds Upgrade under the earner instance; UpgradeAsync sends one numeric count. |
| TycoonEarner | 5781 | 1426949448 | GetUpgradePrice takes optional starting level, count and budget; returns price and affordable count. Pricing includes ascension and CashPriceMultiplier. |
| RemoteRequest | 4201 | 653841906 | Client InvokeServer forwards its arguments unchanged to the actual RemoteFunction. |
| ClientTycoonIncome | 1393 | 3750885460 | The LemonLabs warning comes from failed WakeIncomeStream, independently of the diagnostic. |

Derived call shape: the earner instance's `Upgrade` RemoteFunction receives **one argument: the number of levels**. No mouse position, open menu, secret, or displayed fruit name is passed. The owned root must still be resolved from Owner; the Tycoon slot changes. The live Values/Upgrades key was `LemonStand` while the displayed fruit was Lime.

Do not derive a successful purchase from a returned RPC alone. The standalone probe checks the replicated upgrade level against the pre-request value, ownership, the state-container identity and reset counters. It excludes the controller's pending actions and never repeats an unknown result. This probe is not the production upgrade strategy.

At 06:26:36 (UTC+5), probe v1 stopped before any RPC: requiring ClientTycoonEarner failed with `Cannot require a non-RobloxScript module from a RobloxScript`. Probe v2 removes game-module execution. It reads instances tagged Tycoon.Earner, restricts them to the owned root and existing numeric upgrade records, and sends only one round of +1 attempts. The server validates affordability; no client price or aggregate-budget guarantee is claimed for this transport test. Pricing dependencies are then exported for offline reading. V2 ran but skipped an empty upgrade map on the new Tycoon7. V3 uses the observed GetLevel default of zero and the Enabled attribute of the nearest Tycoon.Purchasable ancestor. Live v3 acceptance is pending.

The 4.0.2 economic fix is independent: unknown future unlock order no longer certifies FINISH, the observed current purchase precedes hypothetical later bonuses, and financing is rechecked against a fixed route deadline. Completing a new Halo with that change remains unverified in-game.

At 06:42:20 (UTC+5), a direct Upgrade(1) returned and Values/Upgrades.LemonStand changed from 2 to 3. This is the first live direct-action receipt. It does not prove concurrent actions.

At 06:44:12, the full Balance export passed byte length and Adler32 verification (340421 / 914084511). Straight-line literal table assignments were read statically, with calls kept symbolic; no require, game function or bytecode execution occurred. The extracted upgrade dataset contains 18997 log10 prices. UpgradeMath mirrors the inspected cumulative-price subtraction and tail formula. DirectUpgrades checks the current module fingerprints, reads the owned Values state and dispatches batches whose total quote is funded. Integration acceptance remains pending.


At 07:11 (UTC+5), ActionInspection v1 exported the Powers/Buy dependencies without invoking any game remote. Verified signatures:

| Module | Bytes | Adler32 | Observation |
|---|---:|---:|---|
| InstanceTable | 13745 | 871009961 | A missing optional Configuration is represented by a detached empty instance; GetAll uses attributes and supported children. |
| ClientTycoonPowers | 1499 | 4053663912 | UpgradeAsync forwards (power name, count) to own Remotes.UpgradePowerLevel. |
| UIManageTilePower | 17271 | 1745023080 | Ordinary upgrade count is 1; MaxTier passes the remaining number of levels. |
| ClientTycoonPurchase | 9384 | 2072785969 | Purchase is a RemoteFunction child; TryPurchaseAsync forwards remote-buy and permanent flags. |
| UIPowerBuyNext | 4310 | 3175981909 | Selects first enabled unpurchased entry in Balance.PurchaseOrder and invokes TryPurchaseAsync(true). |
| TycoonPurchase | 3004 | 2893670776 | Cash price uses Balance.PurchasePrices plus ascension penalty and inversion modifier. |
| TycoonPurchases | 2551 | 2335596492 | IsPurchased uses the main Purchases attribute; its second result indicates permanence. |

4.0.4 sends Purchase(true, false) only for ordinary cash purchases with a current quote and available Remote Buy uses. It sends UpgradePowerLevel(name, 1) only within the investor budget. A returned RPC alone never commits either action: the purchase ledger or exact power level must change in the same owned base/reset epoch. New live acceptance remains pending.


## 4.0.5 external reset reconciliation

- Live 4.0.4 at 07:25:34–07:25:35 (UTC+5) recorded two DIRECT_ACTION_RECEIPT events for UpgradeStack and one for Windows. These were replicated-state receipts from code with no GUI action path. A complete parallel stand pass or Halo cycle is still unverified.
- The preceding Mobile App call returned `not purchasable (disabled)`. Between runs the captured state moved E2 -> E3, TotalEvolves 163 -> 164, TotalRebirths 1107 -> 1108. The failed old-cycle purchase incorrectly survived F6 resume and stopped the new route. Whether the reset had already begun when the server rejected Mobile App is not proven.
- 4.0.5 compares owned-base identity and replicated reset counters before the next worker step. A proven external reset starts fresh observations; it neither records a controller reset nor credits the unresolved purchase. Same-cycle failures, incomplete counters and still-pending calls remain blocked. Rebirth retains the cumulative investor budget.
- Regression reproduces a rejected direct Buy, resume in the same cycle, external evolution and a successful fresh Buy. Separate assertions cover balance-only changes, missing counters, pending calls and rebirth spending retention. This is offline reproduction; live acceptance of the fix is pending.
- ActionInspection v2 completed at 07:32:53, exporting all 24 selected reset/confirmation modules with matching sizes, checksums and bytecode structural validation. No reset was sent by the diagnostic. Reset integration remains in progress.


## 4.0.6 direct prestige and successful-pass scheduling

- Live 4.0.5, 07:39:50–07:41:30 UTC+5: 293 direct Buy receipts, 234 direct upgrade receipts, 5097 levels, 41 parallel batches. EXTERNAL_RESET_OBSERVED cleared the obsolete Mobile App block, followed by its successful direct purchase. No unresolved direct-action result appears in this captured interval.
- The user reported slow upgrades and repeated opening of the investor menu. Successful batches often returned in 0.1–0.2 s, followed by roughly a second before the next batch. HaloRun.checkpoint applied the 0.75 s income wait even when purchases succeeded; Lifecycle also applied idle delay to CHECKPOINT. Direct successful passes now continue to BUY without these delays. Empty passes retain backoff and due reviews retain priority.
- TycoonRebirth uses Cash + CashSpent; its prior investor balance includes min(InvestorsSpent, Investors * 10). Cash divisor is 1.8e17 and power is 0.44. Evolution uses the full InvestorsSpent, current bank and potential reward, target log10 17.7 + 13.6 * E, and starting bonus 500 * targetLog * log10(total/target)^2 above threshold. Tests include independent ordinary-number calculations, tiny rewards, huge logarithms and the 400-investor boundary.
- ActionInspection v3 at 07:42:34 exported Config.PlaceDifferences (128/3292598373), PlaceDifferenceService (1131/2205924379), PremiumPurchases (2741/3733814504), PlaceService (7698/3456245933). PlaceDifferences contains only World2 overrides; Main uses Config defaults. LocalPlayer.Purchases.InvestorBoost=2 and ExtraInvestorBoost=true produce 0.01*2^3=0.08 per investor.
- ClientTycoonRebirth binds owned Remotes.Rebirth. The normal UI confirmation passes nil, while the paid/free product branch passes true. New adapter sends nil only; success requires the same base/evolution/ascension and exactly +1 to Rebirths and TotalRebirths. Unknown outcomes remain blocked across resume; no guessed retry or paid product is sent.
- All normal prestige readers use current replicated data without navigating. Evolution/Halo execution temporarily uses the existing GUI transaction and restores the direct readers afterward. A fresh evolution-ready state can veto a stale rebirth intent. The startup closes an already-open legacy menu once, rather than keeping it open for sampling.
- Offline fixtures verify no investor-menu access, changing reward, boost and completion states, one ordinary rebirth receipt, rejection, missing receipt, mismatched reset, timeout, late cancellation, preserved economic guards and retained GUI evolution/Halo execution. New-runtime speed and direct rebirth are not yet live-verified.


## 4.0.6 Buy stall and startup regression checks

- The latest local Roblox log records BUY_QUOTE_UNKNOWN at 07:46:03, 07:51:31 and 07:52:00 UTC+5. The attached report shows a funded Lemon Stand Monument and available stands, but the old Buy worker pauses the entire controller. No newer controller load/compile error appears in the available log; the user's later startup symptom remains unverified.
- ClientTycoonPurchase.TryPurchaseAsync proto 15 instructions 6-10 set the permanent argument to false for Special; TycoonPurchase.GetPrice still uses the ordinary Balance cash price. Removed the overly broad Special rejection. The actual Special attribute of the reported live monument was not captured, so this is a verified code defect and plausible trigger, not proven live causation.
- New regressions failed on the previous code, then passed: ordinary Special purchase with Purchase(true,false); missing Buy quote continues to UPGRADE past the old timeout, pauses briefly after the pass and resumes Buy when the quote returns. Missing frontier data cannot certify FINISH or trigger a timed rebirth review. Existing unknown in-flight transaction locks remain unchanged.
- Direct startup/resume no longer requires GUI input. GUI execution lazily tests its backend and retains focus checks. Initial diagnostic output is protected from aborting worker creation. Public loader reports distinct request/status/body/compile/execute failures. Corrected Lifecycle Russian text encoding.
- Verified prestige counter getters use zero for absent attributes. Normalize those only in prestige snapshots, leaving raw external-reset reconciliation unchanged. Malformed counter values still fail validation.
- Final offline suite: 53 source/loader/dist files compile; all regression fixtures pass, including 11 forecast/scheduling groups, 9 supervisor scenarios, lazy GUI input, direct startup/resume, four direct-prestige groups and seven public-loader cases. Bundle contains 41 modules. live_roblox_tested=false for 4.0.6; offline tests do not prove runtime throughput, direct rebirth completion or a complete Halo run.


## 4.0.7 post-evolution zero expense balances

- User report and Roblox log `20260923T031230Z_Player_C43C8` confirm E3 -> E4 at 08:13:25 UTC+5. At 08:13:27 BOOT paused with EVOLUTION_INIT_FAILED / PRESTIGE_BALANCE_INVALID CashSpent. CashSpent and InvestorsSpent appeared as raw=nil in the old report because its raw field accepted only finite numbers; this does not establish that the actual attributes were absent.
- Exact missing schema rule: TycoonValues.GetHugeNumber proto 2 compares the attribute to the string "0", returning Huge.zero for that sentinel. Numeric 0 remains log10(1), while an absent value falls back to Huge.zero in TycoonBalances. TycoonValues bytecode identity is 1214 bytes / Adler32 285065225 and is now included in runtime verification. This verified rule explains the rejected zero state without attributing it to executor behavior. The raw attribute was not preserved in the supplied report, so its exact live type remains inferred from the schema and error.
- Prestige snapshots and arithmetic handle string/absent zero explicitly. Direct cash and Powers wallet readers also decode the sentinel. Malformed strings, NaN and positive infinity remain invalid. The raw report now preserves the original value and type rather than silently hiding nonnumeric attributes.
- Regression reproduces the same CashSpent error with string "0" in standalone Luau, then passes after decoding is added. Captured E4 cash=57.460962165077184, bank=3.9556394051741783, H=24, Rebirths=0, TotalRebirths=1109 and TotalEvolves=165 feed real confirmed-reset cleanup and HaloRun.boot; BOOT resumes to POWERS without another reset. Further checks cover zero Cash, zero Powers bank, numeric-zero distinction, absent expense fields, malformed values and type-preserving reports.
- All 53 source/loader/dist files compile and the complete offline suite passes. Live 4.0.6 had 18 Buy and 186 upgrade receipts and one confirmed evolution before this failure. Post-evolution recovery with 4.0.7 is still unverified in Roblox: live_roblox_tested=false.

## 4.0.8 direct receipt identity and owned batch throughput

- Buy and stand upgrades now share one dispatch wave. A freshly validated Buy is reserved first; remaining cash funds the per-stand allocation, and every remote is scheduled before waiting. Buy and upgrade outcomes commit independently. A failed peer does not discard confirmed purchases or trigger duplicates. A funded FINISH catalogue retains its reservation. The joint-wave fixture uses the real DirectPurchases/DirectUpgrades adapters and checks both completion orders, independent rejection, construction-only cash and shared service-time accounting.
- Evidence: the user's 4.0.7 report at E4/H24 and the Roblox log on 2026-09-23 08:28–08:31 UTC+5. Four +1 requests at pass 514 (146.99 s) timed out at 155.00 s. The exported levels were exactly the expected 514; UpgradeStack capacity changed from 1 during the run to 5 in the report, with an unaccounted investor debit of 1000. The precise selector/power event was not logged, so its timestamp is inferred rather than captured.
- The reproduced code defect compared current cap with pre-send cap when checking receipts. Archived 4.0.7 fails the new power-change-during-response regression; 4.0.8 passes it. Receipts now check returned successful RPC, same owned instances, all five reset counters and exact per-stand level; cap/price checks remain before dispatch. No success is inferred from a reset or missing state.
- Late direct-upgrade receipts use replicated data through Safety.proof and idempotent Safety.commit. Resume reconciles blocked direct work before BOOT/Powers/Buy dispatch. A tier change before sending causes immediate replanning; outstanding callbacks still lock actions, and unknown sent outcomes are never repeated automatically.
- ClientTycoonEarner.UpgradeAsync sends the requested count. Purchased UpgradeStack determines the direct cap independently of the GUI-selected tier. Tests cover +5/+25/+100/MAX, permanent levels, stale +1 selection, shared cash and exact level receipts. No unowned tier is enabled. Actual server acceptance of larger counts in this release still needs live evidence.
- Rebuild input estimates use maximum per-stand rounds for parallel direct upgrades rather than summing them as serial clicks, and omit GUI menu trips only for direct purchases. Direct levels are zero-based; the existing minimum financing allowance stays. The seven-stand, level-500, 0.14-second fixture no longer charges seven times the parallel upgrade input.
- Complete offline suite passes; all 53 source/loader/dist files compile, bundle has 41 modules. live_roblox_tested=false for 4.0.8. These tests do not prove live network throughput, a complete Halo run or all future game schemas.
