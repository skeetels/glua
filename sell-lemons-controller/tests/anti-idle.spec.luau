local factory=require('../src/runtime/AntiIdle')
local make=require('./mock-engine')
local function setup()
    local m=make();local releases=0
    m.env.workspace.CurrentCamera.CFrame={fixture=true}
    m.services.VirtualUser.Button2Up=function(_,_,frame)assert(frame.fixture);releases=releases+1 end
    local ctx={S={connections={}},API={},Driver={},player=m.player,now=function()return 100 end}
    setfenv(factory,m.env);factory(ctx)
    return ctx,m,function()return releases end
end
do
    local c,m,releases=setup();m.player.Idled:Fire()
    assert(c.AntiIdle.pending);m.env.workspace.CurrentCamera=nil
    m.tasks[1]();assert(not c.AntiIdle.pending and releases()==1)
end
do
    local c,m=setup();c.S.actionPending={};m.player.Idled:Fire()
    assert(#m.tasks==0 and c.AntiIdle.status=='DEFERRED_DURING_TRANSACTION')
end
do
    local c,m=setup();c.API.antiIdle(false);m.player.Idled:Fire();assert(#m.tasks==0)
end
print('PASS 3 anti-idle cleanup / exclusion fixtures')
