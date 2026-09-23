local initialize=require('../src/runtime/ResetTransaction')
for _,mode in ipairs({'before-navigation','ready-delay','before-confirmation'})do
    local time=0;local funded=mode=='before-navigation';local starts=0;local confirmations=0
    local r={halo30={}};local c={S={resetEnabled=true},CONFIG={TabletReserve=400,EvolutionReadyDelay=1,ResetTimeout=5},
        confirmKinds={evolve=true},paths={evolution='evolution'},Core={evolutionGuard=function()return true end}}
    c.now=function()return time end;c.live=function()return true end
    c.sleep=function(dt)time=time+dt;if mode=='ready-delay'then funded=true end;return true end
    c.g=function()return {}end;c.status=function()end;c.log=function()end
    c.pause=function()error('an economic cancellation must not become an error pause')end
    c.readEvolution=function()return {ready=true,index=6,bonusVisible=true}end
    c.HaloRun={deferEvolution=function()return funded,'CONTINUE_FUNDED_CONSTRUCTION'end}
    c.Strategy={route=function()return r end,phase=function(phase)r.phase=phase end}
    c.ResetConfirm={begin=function()
        local session={active=true,kind='evolve'};c.S.resetSession=session;return session
    end,note=function()end,dump=function()end,finish=function()c.S.resetSession=nil end}
    c.Driver={perform=function(_,kind,changed,options)
        assert(kind=='evolve')
        if not options.guard()then return false,'STATE_CHANGED_BEFORE_CLICK'end
        starts=starts+1;options.onDispatch()
        funded=true
        local session=c.S.resetSession
        if session.expected and not session.expected.authorize({})then
            session.cancelledReason='CURRENT_ROUTE_PROTECTED';return false,'TRANSACTION_CANCELLED'
        end
        confirmations=confirmations+1
        error('evolution confirmation should have been vetoed')
    end}
    initialize(c)
    assert(not c.doReset('evolve') and r.phase=='BUY' and not c.S.resetSession and confirmations==0)
    assert(starts==(mode=='before-confirmation' and 1 or 0))
end
print('PASS funded construction vetoes evolution before navigation, after ready delay and at final confirmation without an error pause')
