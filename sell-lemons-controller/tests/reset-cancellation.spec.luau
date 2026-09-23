-- Actual confirmation parser + poll + cancellation, with the captured UIAlert
-- layout: ordinary Option1/Option2 AND a separate Main/Close control.
local function fixture()
    local mock=require('./mock-engine')();local c={S={running=true,resetEnabled=true,epoch=1,logs={},events={},started=0},gui=mock.gui}
    for _,name in ipairs({'config','core/Numeric','adapters/GuiAccess','runtime/Confirmation'})do
        local initialize=require('../src/'..name);setfenv(initialize,mock.env);initialize(c)
    end
    c.CONFIG.AutoEvolution=true;c.CONFIG.HaloSprint=false
    c.BN=c.Core.BN
    local time=0;c.now=function()return time end
    local function node(kind,name,parent,text)
        local o=mock.env.Instance.new(kind);o.Name=name;o.Text=text or '';o.Parent=parent;return o
    end
    local important=node('Frame','Important',mock.gui)
    local alert=node('Frame','Alert',important);alert.Visible=false
    local main=node('Frame','Main',alert);local buttons=node('Frame','Buttons',main)
    node('TextLabel','Message',main,'Are you sure you want to evolve? Most progress will be reset, including investors and powers! (Robux purchases are safe.)')
    local yes=node('TextButton','Option1',buttons,'Evolve!')
    local no=node('TextButton','Option2',buttons,'nvm')
    local close=node('TextButton','Close',main)
    local origin=node('TextButton','Evolve',mock.gui,'Evolve')
    c.ancestorOf=function(o,parent)while o do if o==parent then return true end;o=o.Parent end;return false end
    c.candidateModes=function()return {'fixture'}end
    local clicks={};c.dispatch=function(button,mode,options)
        assert(options.guard() and button==no,'only the matching nvm answer may be clicked')
        clicks[#clicks+1]=button;main.Visible=false;return true
    end
    mock.env.task.spawn=function(fn)fn();return {}end
    local session=assert(c.ResetConfirm.begin('evolve',origin,{authorize=function()return false end}))
    session.sent=true;alert.Visible=true
    return c,session,yes,no,close,buttons,main,clicks,function(t)time=t end,node
end
do
    local c,s,yes,no,close,buttons,main,clicks,clock=fixture()
    local d=assert(c.ResetConfirm.inspect('evolve',yes,s.expected));assert(#d.negatives==2)
    c.ResetConfirm.poll(s)
    assert(#clicks==1 and s.cancelledReason=='RESET_ECONOMY_CHANGED_AT_CONFIRMATION')
    assert(c.S.running and not c.S.resetChildPending,'successful cancel must not pause the worker')
    c.ResetConfirm.poll(s);assert(#clicks==1)
end
print('PASS real UIAlert with nvm plus Close cancels through nvm once without the old five-second stall')
do
    local c,s,yes,no,close,buttons,main,clicks,clock,node=fixture()
    node('TextButton','Option3',buttons,'Cancel')
    c.ResetConfirm.poll(s);assert(#clicks==0)
    assert(s.cancellation.lastIssue=='CANCEL_ANSWERS_AMBIGUOUS')
    clock(6);c.ResetConfirm.poll(s)
    assert(not c.S.running and not s.cancelledReason and s.error=='CANCEL_UNRESOLVED')
    assert(c.S.code=='EVOLUTION_CANCEL_UNRESOLVED')
end
print('PASS ambiguous answers remain unresolved and expose their reason instead of fabricating cancellation')

-- Recreate the second defect from a215b952: pause during cancel, then return
-- from Driver.perform. ResetTransaction must preserve the stopped status.
do
    local c={S={resetEnabled=true,running=true},CONFIG={TabletReserve=400,EvolutionReadyDelay=0,ResetTimeout=5},
        confirmKinds={evolve=true},paths={evolution='Evolution'},Core={evolutionGuard=function()return true end}}
    local r={phase='EVOLVE_RESERVE',halo30={}};c.Strategy={route=function()return r end,
        phase=function(p)r.phase=p end}
    c.now=function()return 0 end;c.live=function()return c.S.running end;c.sleep=function()return true end
    c.g=function()return {}end;c.status=function()end;c.log=function()end
    c.pause=function(code)c.S.running=false;c.S.code=code;c.S.resetSession=nil end
    c.readEvolution=function()return {ready=true,index=1}end
    c.HaloRun={deferEvolution=function()return false end}
    c.ResetConfirm={begin=function()local s={};c.S.resetSession=s;return s end,note=function()end,
        dump=function()end,finish=function()c.S.resetSession=nil end}
    c.Driver={perform=function(_,_,_,options)
        options.onDispatch();local session=c.S.resetSession
        r.lastResetGuardReason='CONTINUE_FUNDED_CONSTRUCTION';session.error='CANCEL_UNRESOLVED'
        c.pause('EVOLUTION_CANCEL_UNRESOLVED');return false,'PAUSED_WITH_ACTION_IN_FLIGHT'
    end}
    require('../src/runtime/ResetTransaction')(c)
    assert(not c.doReset('evolve'))
    assert(c.S.code=='EVOLUTION_CANCEL_UNRESOLVED' and r.phase=='EVOLVE_RESERVE')
    assert(r.lastResetExecution.stage=='unresolved','a failed cancellation must never claim BUY resumed')
end
print('PASS cancellation failure preserves the paused error and unresolved execution stage')


