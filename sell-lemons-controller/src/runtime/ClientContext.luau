-- Component initialized with an explicit shared service context.
return function(__slctx)
__slctx.Strategy={} -- route methods are defined after the GUI/action adapters.

-- Runtime adapter: only existing game GUI controls. No guessed remote payloads.
__slctx.Players=game:GetService('Players')
__slctx.UIS=game:GetService('UserInputService')
__slctx.player=__slctx.Players.LocalPlayer
assert(__slctx.player, '[SL Farm] Run this script in the Roblox client.')
assert(game.PlaceId==79268393072444, '[SL Farm] This adapter is for Sell Lemons (79268393072444).')
__slctx.gui=__slctx.player:WaitForChild('PlayerGui',15)
assert(__slctx.gui, '[SL Farm] PlayerGui did not load.')
__slctx.env=_G
if type(getgenv)=='function' then
    local ok,e=pcall(getgenv)
    if ok and type(e)=='table' then __slctx.env=e end
end
__slctx.previousCycleState=nil
if __slctx.env.SLAutofarm and type(__slctx.env.SLAutofarm.exportCycleState)=='function' then
    local ok,state=pcall(__slctx.env.SLAutofarm.exportCycleState)
    if ok and type(state)=='table' and state.place==game.PlaceId and state.user==__slctx.player.UserId then __slctx.previousCycleState=state end
end
if __slctx.env.SLAutofarm and type(__slctx.env.SLAutofarm.unload)=='function' then
    if type(__slctx.env.SLAutofarm.callbackPending)=='function' and __slctx.env.SLAutofarm.callbackPending() then
        error('[SL Farm] Previous callback is still running. A second worker was not created.')
    end
    pcall(__slctx.env.SLAutofarm.unload)
    task.wait(0.25)
end
__slctx.BN=__slctx.Core.BN
__slctx.S={running=false,unloaded=false,busy=false,epoch=0,started=os.clock(),runStart=os.clock(),
    status='Готов. Нажми «Запуск».',code='READY',logs={},events={},connections={},profile={},
    lastInput=nil,lastRefresh=-math.huge,lastPowers=-math.huge,lastCatalog=-math.huge,
    prestige=nil,tablet=nil,catalog={},rate=__slctx.Core.newRateTracker(),lastSpend=-math.huge,
    episode=nil,goal=nil,stallStart=nil,lastKind='',counts={buy=0,upgrade=0,rebirth=0,evolve=0,halo=0},
    catalogDirty=true,incomeAttempts={},nextIncomeAt=0,upgradeVisited={},
    lastError='',signalCounts={},firstRun=true,resetEnabled=__slctx.CONFIG.ResetsEnabledAtStart,lastSkip=nil,windowFocused=true}
__slctx.Focus={}
__slctx.Safety={}
__slctx.Powers={}
__slctx.API={config=__slctx.CONFIG}
__slctx.env.SLAutofarm=__slctx.API
_G.SLAutofarm=__slctx.API

end
