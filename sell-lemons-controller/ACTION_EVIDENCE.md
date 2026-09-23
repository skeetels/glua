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

At 06:26:36 (UTC+5), probe v1 stopped before any RPC: requiring ClientTycoonEarner failed with `Cannot require a non-RobloxScript module from a RobloxScript`. Probe v2 removes game-module execution. It reads instances tagged Tycoon.Earner, restricts them to the owned root and existing numeric upgrade records, and sends only one round of +1 attempts. The server validates affordability; no client price or aggregate-budget guarantee is claimed for this transport test. Pricing dependencies are then exported for offline reading. Live v2 acceptance is still pending.

The 4.0.2 economic fix is independent: unknown future unlock order no longer certifies FINISH, the observed current purchase precedes hypothetical later bonuses, and financing is rechecked against a fixed route deadline. Completing a new Halo with that change remains unverified in-game.
