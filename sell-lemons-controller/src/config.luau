-- Component initialized with an explicit shared service context.
return function(__slctx)
-- Sell Lemons Autofarm 3.3.3 Route Economy / Halo controller.
-- Stalled growth: bounded post-rebuild output comparison and immediate weak-upgrade allocation review.
-- Repairs: post-purchase Nice callback ordering, late notices, throughput resets,
-- failed power-scan retry and repeated empty review tours. Offline regressions only.
-- Input: no extra upgrade throttle; bounded native BUY holds with conservative receipt accounting.
-- Explicit permanent factors; future catalogue cash flow; transaction-stage observations.
-- Fixes interrupted-pass starvation, repeated no-op shop tours and attachment bootstrap deadlock.
-- Requested policy: prepare using short investment cycles, then commit to financing
-- every remaining catalogue button and The End without incidental resets.
-- Catalogue: 452 rows from the user's supplied Buttons/List markdown; no remote fetch.
-- Price prior C(H)=C(0)*3.33^H is inferred from supplied H21/H22 logs, then checked live.
-- Readiness is funding capacity, not a purchase count or a percentage of elapsed time.
-- Model-based routing, not a verified game simulator or proof of global optimality.
-- GUI/transaction and capital-accounting adapters retained from supplied 2.8.2.
-- F6 start/pause; F7 diagnostics; F8 hide panel. No automatic start.
__slctx.CONFIG = {
    -- 3.0 catalogue objective. Expected donor values are metadata, not extra multipliers.
    ExpectedInvestorBonus = 0.08,
    ExpectedTimeMultiplier = 16, -- Display/decomposition metadata only. Observed income ALREADY includes this.
    -- Price hypothesis inferred from the supplied v6916 logs at H21 and H22.
    -- It must match independent live quotes before it can authorize FINISH.
    HaloPriceBase = 3.33,
    HaloPriceMinimumAnchors = 3,
    HaloPriceLogTolerance = 0.003,
    ReadinessInvestorMaxAge = 120, -- Display-only scenario; live reset gates remain stricter.
    CatalogueMinimumAnchors = 5,
    CatalogueMinimumSpan = 8,
    CatalogueFitError = 0.025,
    CatalogueCostMargin = 0.15,
    CatalogueIncomeMargin = 0.75,
    CataloguePlanSeconds = 2,
    CatalogueSnapshotSeconds = 20,
    FinishMaximumWaitSeconds = 60,
    FinishMinimumWaitSeconds = 8,
    FinishWaitFraction = 0.35,
    AllowConditionalFinish = false, -- Unknown unlock order never certifies an optimistic final run.
    RouteResetMargin = 0.25,
    PreparationReviewMinimumSeconds = 12,
    PreparationReviewGrowthDecades = 0.9,
    PreparationReviewBuys = 48,
    PreparationWatchdogSeconds = 90,
    PreparationIdleObservationSeconds = 0.75,
    PreparationReviewUpgradePurchases = 96,
    PreparationNoChangeBackoffSeconds = 30,
    BootstrapGainConfidence = 0.60,
    PowerScanRetrySeconds = 45, -- Retry failed navigation, NOT an unchanged empty shop.
    CapitalCreditStableSeconds = 0.15,
    HaloObservationRetrySeconds = 1,
    HaloFinishGraceSeconds = 4,
    HaloCompletionBackoffSeconds = 3,
    RuntimeControllerVersion = 333,
    EvolutionSpeedBase = 42, -- Each evolution: x42 income speed (game UI).
    HaloCashBase = 7.77, -- Each Halo: x7.77 cash; prices separately use x3.33.
    RouteIncomeSearchSteps = 14,
    TerminalLevelBudgetFraction = .01, -- Per source; future level spending is included, not free.
    LevelProjectionMaxUnits = 4000,
    LevelExtrapolationFactor = 8,
    LevelNodesPerSource = 16,
    EnableCatalogueRouteProjection = true,
    ProjectedFinishRequiresCompleteLedger = true,
    PendingProgressReadSeconds = 0.5,
    ResetObservationOpenLimit = 2,
    ResetObservationStartSeconds = 6,
    SnapshotAfterResetGraceSeconds = 2,
    CatalogueObjectiveWatchdogSeconds = 120,

    ClickMode = "Auto",
    EnableVirtualInput = true,
    ResetsEnabledAtStart = true,
    AllowInputPair = true,
    AutoRebirth = true, AutoEvolution = true, AutoHalo = true,
    TabletReserve = 400,
    MaxWaitSeconds = 30, -- One non-renewable budget per quoted base target.
    EconomicPlanning = true,
    CapabilityRebirth = true,
    CapabilityReviewPurchases = 32, -- Review boundaries never complete or discard a partial pass.
    CapabilityReviewSeconds = 12,
    MacroRebirthReviews = false,
    BuyBurstReviewSeconds = 16,
    ObjectiveVersion = 28, -- Capital/observation schema remains compatible.
    ConstructionPolicy = 282,
    BuildQuoteFreshSeconds = 12, -- Valid quote carried across menu-only navigation, not an extra wait.
    BuildShortWaitSeconds = 8,
    BuildWallConfirmSeconds = 8, -- Only for a repeated funding wall BEFORE the former build frontier.
    BuildWallWeakGain = 0.05,
    ProgressMaxBuild = true, -- Continue milestone MAX checks after income parity, not only during recovery.
    ProgressBuildMinimumBuys = 32,
    ProgressBuildFallbackBuys = 96,
    ResetIntentSeconds = 12, -- Fixed lease for unchanged state; never renewed by validation.
    InitialFullLayoutSeconds = 150, -- Unmeasured FULL-layout fallback, never parity time.
    UnobservedResetGainConfidence = 0.60,
    MaximumReplaySeconds = 86400,
    FrontierTracePoints = 240,
    GoalAdvantageSeconds = 3,
    GoalForecastGrowthSeconds = 15,
    RewardCurveExtrapolationDecades = 3,
    EvolutionProbeSeconds = 30, -- Independent of the expensive rebirth review.
    IncomeFreshSeconds = 2.5,
    PassiveObservationSeconds = 0.25,
    RecoveryStableSeconds = 0.60,
    ReviewIncomeDecades = 0.30,
    ReviewMinimumBuys = 48,
    ReviewMaximumSeconds = 60,
    FastMaxRecovery = true,
    FastBuildMinimumSeconds = 10,
    FastBuildMinimumBuys = 12,
    FastBuildFallbackBuys = 48,
    FastBuildEmptyBackoffSeconds = 15,
    OptionalPowerAllowlist = {}, -- Stack is intrinsic; other powers require explicit opt-in.
    AdaptiveBuyReceipts = true,
    BuyReceiptWarmup = 64,
    FastBuyReceiptStableSeconds = 0.025, -- Still requires unchanged new quote across polls.

    ResetEvaluationHorizonSeconds = 120,
    PlanningHorizonSeconds = 60,
    PlanningDepth = 4,
    PlanningBeamWidth = 5,
    PlanningMaxLocalWaitSeconds = 4,
    AdaptiveStandAllocation = true,
    AllocationMinimumPurchases = 12,
    BreakthroughBuys = true,
    BreakthroughMinimumMultiplier = 2,
    BreakthroughMinimumAdvantage = 0.02,
    InitialMenuTripSeconds = 1.2, -- Startup estimate; not measured Roblox latency.
    ChainStackPowers = true,
    DiagnosticSeconds = 10,
    DiagnosticLines = 360,
    PowerSavingsConfidence = 0.60, -- Heuristic haircut on projected avoided input time.
    PowerNextBatchHints = {[5]=25}, -- User-supplied example, not a claimed complete game tier table.
    InitialRebuildSeconds = 60, -- Explicit fallback until comparable recovery is measured.
    InitialResetSeconds = 5,
    RankStandsByReturn = true,
    DecisionAdvantageSeconds = 0.25,
    DecisionRelativeMargin = 0.04,
    ResetDecisionMargin = 0.08,
    ResetPaybackHorizonSeconds = 120, -- Minimum horizon; grows for observed long rebuilds.
    OrdinaryTargetWaitSeconds = 4,
    UnknownEvolutionReviewSeconds = 12,
    EvolutionReserveWaitSeconds = 2,
    UpgradeActionEstimate = 0.18, -- Replaced with measured successful receipt latency.
    IncomeSampleSeconds = 0.12,
    MajorMultiplier = 100000,
    NearInvestorTargetFraction = 0.90, -- Only used at a growth wall, not as a readiness claim.
    EvolutionReadyDelay = 0.3,
    UseSingleUpgradeAtWall = true, -- Smaller affordable batches are always considered.
    PreferredUpgradeBatch = 100,
    MinimumUpgradeBatch = 1,
    UpgradeBatches = {100, 25, 5, 1},
    AutoInvestorPowers = true,
    PowerMaxEpochFraction = 0.05, -- CUMULATIVE optional spend; ordinary rebirth does NOT reset U/G.
    -- The mandatory tablet is a separate bootstrap cost, excluded from optional retention.
    PowerPassLimit = 16,
    PurchaseAttempts = 3,
    RecoverySettleSeconds = 0.6,
    BackgroundMode = "Probe", -- "Probe" or "Pause"; no OS cursor/input APIs.
    AutoResumeOnFocus = true,
    IncomeObservationSeconds = 3.2,
    MenuSettle = 0.3, -- only after opening/changing a menu, never after each purchase.
    RequestedClickInterval = 0, -- No extra throttle; the worker still yields to Roblox between operations.
    BuyHoldEnabled = true,
    BuyHoldBurstSeconds = 2, -- Real native hold, then a planning/reconciliation boundary.
    BuyHoldPollSeconds = 0, -- Check the actual GUI every available scheduler frame.
    BuyHoldNoProgressSeconds = 0.75,
    ClickHoldSeconds = 0,
    ConfirmationPollSeconds = 0, -- task.wait(0) yields to the next engine scheduler frame.
    ReceiptStableSeconds = 0.05,
    ActionTimeout = 5.0,
    BackgroundActionTimeout = 15,
    BackgroundRetrySeconds = 5,
    IdleStepSeconds = 0.25,
    ConfirmScanSeconds = 0.25,
    ScanYieldEvery = 100,
    ResetTimeout = 45,
    AutoConfirmResets = true, -- only dialogs appearing after the script's chosen reset.
    ConfirmStableSeconds = 0.2, -- allow the dialog to finish appearing before input.
    ConfirmPollSeconds = 0.25,
    ConfirmMaxStages = 4, -- distinct dialogs, not attempts on one still-open dialog.
    AutoConfirmPurchases = true, -- cash upgrades, Remote Buy, tablet and investor powers.
    ConfirmInitialDelaySeconds = 0.8, -- minimum dialog age; NOT the game's unknown timer.
    ConfirmReadyStableSeconds = 0.25,
    ConfirmRetrySeconds = 1.0, -- only same still-open dialog, no receipt and no pending callback.
    ConfirmMaxAttempts = 8, -- per unchanged dialog; originating purchase/reset is NOT reissued.
    ConfirmWaitTimeout = 45, -- extra bounded budget only after a confirmation is found.
    ConfirmScanLimit = 6000,
    AfterResetWait = 2,
    UIUnavailableTimeout = 10,
    LogLines = 400,
    EventLogLines = 800, -- Strategic events only; no per-click background receipts.
    VerboseClickPoints = false,
    ConsoleTransactionLogs = false, -- Full bounded transaction log remains available through F7.
    StartIncomeWhenIdle = true,
    IncomeRetrySeconds = 12,
    IncomeAttemptTimeout = 0.7,
}


end
