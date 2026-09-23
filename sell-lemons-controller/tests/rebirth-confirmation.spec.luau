-- Reproduce the live sequence: origin click -> dialog -> origin disabled.
local ctx={Strategy={},Core={},S={},CONFIG={ConfirmInitialDelaySeconds=0,ConfirmReadyStableSeconds=0,
    ConfirmStableSeconds=0,ConfirmMaxAttempts=8,ConfirmRetrySeconds=0,ConfirmMaxStages=4,ConfirmWaitTimeout=10},
    paths={investors='Investors'},BN={parse=tonumber},now=function()return 1 end,
    log=function()end,status=function()end,live=function()return true end,
    candidateModes=function()return {}end}
local origin={ready=true};local root={};local button={};local modal={root=root,button=button,fingerprint='rebirth',text='Rebirth!'}
local texts={['Investors/Body/Amount/What']='Investors',['Investors/Body/Amount/Quantity']='100',
    ['Investors/Body/Potential/Quantity']='250',['Investors/Body/Bonus/Quantity']='+8%'}
ctx.g=function(path)return path=='Investors/Body/Rebirth' and origin or root end
ctx.t=function(path)return texts[path] or ''end
ctx.visible=function()return true end
ctx.usable=function(o)return o.ready end
require('../src/runtime/Confirmation')(ctx)
require('../src/strategy/ResetPlanning')(ctx)
local c=ctx.ResetConfirm
c.valid=function(s)return s.active and s==ctx.S.resetSession end
c.scan=function()return {modal},true end
c.weakRebirth=function()return false end
c.note=function()end
c.path=function()return 'Confirm' end
local dialogReady=true
c.ready=function()return dialogReady,'COUNTDOWN'end
local cancelled=false
local cancelReset=c.cancelReset
c.cancelReset=function()cancelled=true;return true end
local session={active=true,sent=true,kind='rebirth',epoch=1,states={},stages=0,attempts=0,clicked={}}
ctx.S.resetSession=session
local authorizations=0
session.expected={authorize=function(d)
    authorizations=authorizations+1
    local inv=ctx.Strategy.peekResetInvestors(session,d)
    return inv and inv.ready and inv.investors==100 and inv.reward>=250
end}
assert(ctx.Strategy.peekResetInvestors().ready)
origin.ready=false
assert(not ctx.Strategy.peekResetInvestors().ready,'pre-dispatch gate must remain strict')
c.poll(session)
assert(authorizations==1 and not cancelled and session.originGateTransferred,
    'matching ready confirmation must not fail solely because origin is disabled')
print('PASS modal disables origin while matched confirmation stays ready')
dialogReady=false
c.poll(session)
assert(authorizations==1 and not cancelled,'countdown must wait, not cancel the intent')
print('PASS confirmation countdown waits before authorization')
dialogReady=true
texts['Investors/Body/Amount/Quantity']='101'
c.poll(session)
assert(cancelled,'fresh changed economy still vetoes confirmation')
print('PASS fresh economy changes still cancel')
assert(ctx.Strategy.peekResetInvestors(session,{root=root,button=button})==nil,'unmatched dialog cannot replace origin gate')
session.sent=false
assert(ctx.Strategy.peekResetInvestors(session,modal)==nil,'undispatched session cannot replace origin gate')
session.sent=true;ctx.S.resetSession=nil
assert(ctx.Strategy.peekResetInvestors(session,modal)==nil,'stale session cannot replace origin gate')
print('PASS unmatched, undispatched and stale confirmation contexts rejected')
do
    cancelled=false
    local evo={active=true,sent=true,kind='evolve',epoch=1,states={},stages=0,attempts=0,clicked={},expected={authorize=function()return false end}}
    ctx.S.resetSession=evo;c.poll(evo)
    assert(cancelled,'evolution economic veto must actively cancel its modal')
    local negative={ready=true};local d={root={visible=true},button={},negatives={negative},text='Evolve!'}
    local clicks=0
    ctx.CONFIG.ActionTimeout=10;ctx.visible=function(o)return o.visible end
    c.ready=function(o)return o.ready end;c.buttonRole=function(o)return o==negative and 'negative' or 'positive' end
    c.inspect=function(kind,button)assert(kind=='evolve' and button==d.button);return d end
    ctx.candidateModes=function()return {'fixture'}end
    ctx.dispatch=function(o,_,options)
        assert(o==negative and options.guard());clicks=clicks+1;d.root.visible=false;return true
    end
    setfenv(cancelReset,setmetatable({task={spawn=function(fn)fn();return {}end}}, {__index=getfenv()}))
    cancelReset(evo,d,'CURRENT_ROUTE_PROTECTED')
    assert(clicks==1 and evo.cancelledReason=='CURRENT_ROUTE_PROTECTED' and not ctx.S.resetChildPending)
    evo.kind='halo';evo.cancellation=nil;evo.cancelDialog=nil;d.root.visible=true
    cancelReset(evo,d,'WRONG_DIALOG');assert(clicks==1,'unrelated ascension must not be cancelled')
end
print('PASS evolution veto closes only its matched negative confirmation; unrelated ascension remains untouched')
