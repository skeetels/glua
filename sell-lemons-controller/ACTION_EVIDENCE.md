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
