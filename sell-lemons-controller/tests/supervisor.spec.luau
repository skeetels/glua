local factory=require('../src/runtime/Supervisor')
local policy=require('../src/core/RecoveryPolicy')
local function make()
    local time=100
    local route={phase='UPGRADE',pass={index=4,purchases=18}}
    local halo={mode='PREPARE',lastReview=0}
    local c={S={running=true,epoch=5,counts={buy=0,upgrade=0,rebirth=0,evolve=0,halo=0}},
        CONFIG={AutoRebirth=true},Driver={},Observer={poll=function()end,store={invalidate=function()end}},
        API={report=function()return ''end},log=function()end,status=function()end,
        now=function()return time end,step=function()end}
    c.pause=function(code) c.S.running=false;c.S.epoch=c.S.epoch+1;c.S.resetSession=nil end
    c.Strategy={route=function()return route end,afterReset=function()end}
    c.HaloRun={state=function()return halo end,requestReview=function(destination)
        halo.returnPhase=destination;route.phase='CAPABILITY'
    end}
    policy(c);factory(c)
    return c,route,halo,function(t)time=t end
end
local count=0
local function test(name,fn)local ok,e=pcall(fn);assert(ok,name..': '..tostring(e));count=count+1 end
test('transient failure resumes retained pass',function()
    local c,r,h,set=make();local pass=r.pass
    c.pause('UPGRADE_MENU_NOT_READY','view missing');assert(not c.S.running)
    set(102);c.Supervisor.tick();assert(c.S.running and r.pass==pass and r.pass.index==4)
end)
test('manual pause cancels scheduled recovery',function()
    local c,r,h,set=make();c.pause('UPGRADE_MENU_NOT_READY');c.pause('PAUSED')
    set(120);c.Supervisor.tick();assert(not c.S.running)
end)
test('active confirmation blocks recovery even when pause clears it',function()
    local c=make();c.S.resetSession={};c.pause('INVESTORS_READ_FAILED')
    assert(c.Supervisor.pending==nil)
end)
test('unknown transaction result does not recover',function()
    local c=make();c.pause('BUY_FAILED');assert(c.Supervisor.pending==nil)
end)
test('review preserves partial pass',function()
    local c,r,h=make();c.S.resetEnabled=true;local pass=r.pass
    c.step();assert(r.phase=='CAPABILITY' and h.returnPhase=='UPGRADE' and r.pass==pass)
end)
test('finish blocks periodic rebirth review',function()
    local c,r,h=make();c.S.resetEnabled=true;h.mode='FINISH'
    c.step();assert(r.phase=='UPGRADE')
end)
test('four retries then stop',function()
    local c,r,h,set=make()
    for i=1,4 do c.pause('BATCH_VIEW_NOT_READY');set(100+20*i);c.Supervisor.tick();assert(c.S.running) end
    c.pause('BATCH_VIEW_NOT_READY');assert(c.Supervisor.pending==nil and not c.S.running)
end)
test('idle input excludes economic step',function()
    local c,r,h=make();c.AntiIdle={pending=true};c.S.resetEnabled=true
    c.step();assert(r.phase=='UPGRADE' and c.Supervisor.steps==0)
end)
test('unknown Buy frontier does not preempt available upgrades with a reset review',function()
    local c,r,h=make();c.S.resetEnabled=true;h.buyUnavailableReason='BUY_NOT_REPLICATED_OR_ENABLED'
    c.step();assert(r.phase=='UPGRADE' and c.Supervisor.reviews==0)
end)
print('PASS '..count..' supervisor scenarios')
