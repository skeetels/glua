local initialize=require('../src/adapters/SignalInput')
local tests,focusCalls=0,0
local ctx={Driver={},S={},CONFIG={},live=function()return true end,status=function()end,
    usable=function()return true end,paid=function()return false end,
    Focus={await=function()focusCalls=focusCalls+1;return false end}}
initialize(ctx)
ctx.selfTest=function()tests=tests+1;return false,'INPUT_API_MISSING'end
local ok,why=ctx.Driver.perform({},'navigation',function()return false end)
assert(not ok and why=='INPUT_API_MISSING' and tests==1 and focusCalls==0)
ctx.S.actionPending={}
ok,why=ctx.Driver.perform({},'navigation',function()return false end)
assert(not ok and why=='PREVIOUS_CALLBACK_PENDING' and tests==1)
ctx.S.actionPending=nil
ctx.selfTest=function()tests=tests+1;ctx.Driver.fire=function()end;return true end
ok,why=ctx.Driver.perform({},'navigation',function()return false end)
assert(not ok and why=='PAUSED' and tests==2 and focusCalls==1)
ctx.Driver.perform({},'navigation',function()return false end)
assert(tests==2 and focusCalls==2,'a tested GUI backend is reused; GUI focus gate stays active')
print('PASS GUI input is tested lazily, unavailable input never dispatches, pending work excludes probes and focus guard remains active')
