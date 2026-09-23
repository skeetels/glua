local c={};require('../src/core/Numeric')(c);c.BN=c.Core.BN
require('../src/core/UpgradeMath')(c);require('../src/core/PrestigeMath')(c)
local P=c.PrestigeMath;local function log(x)return x==0 and -math.huge or math.log10(x)end
local function near(a,b)assert(math.abs(a-b)<1e-8,tostring(a)..' versus '..tostring(b))end
-- Independent ordinary-number calculation, including the game's spent cap.
for _,x in ipairs({{2e20,8e20,0,0},{1e40,2e39,1e8,1e9},{1e35,1e34,1e8,1e12},{1e30,0,1e5,0}})do
    local total=x[1]+x[2];local prior=x[3]+math.min(x[4],x[3]*10)
    local expected=((total/1.8e17)+prior^(1/.44))^.44-prior
    near(P.reward(log(x[1]),log(x[2]),log(x[3]),log(x[4])),log(expected))
end
near(P.reward(10,-math.huge,100,100),100+log(2)+log(.44)+10-log(1.8e17)-(100+log(2))/.44)
assert(P.reward(-math.huge,-math.huge,-math.huge,-math.huge)==nil)
assert(P.reward(nil,nil,nil,nil)==nil)
near(P.reward(30,nil,nil,nil),log((1e30/1.8e17)^.44))
near(P.reward(30,nil,5,nil),P.reward(30,-math.huge,5,-math.huge))
local huge=P.reward(2000,1999,200,190);assert(huge>800 and huge<900)
-- Evolution preview uses all spent investors, unlike the rebirth discount cap.
local progress,bonus,target,total=P.evolution(3,59,60,-math.huge)
near(target,58.5);near(total,log(1e59+1e60));near(progress,1)
near(bonus,log(500*58.5*(total-58.5)^2))
local p,b=P.evolution(3,58.5,-math.huge,-math.huge);near(p,1);assert(b==nil)
local p,b=P.evolution(3,58.5-13.6,-math.huge,-math.huge);near(p,.1);assert(b==nil)
local p,b=P.evolution(0,nil,nil,nil);assert(p==0 and b==nil)
local p,b=P.evolution(2,44.9+math.sqrt(400/(500*44.9)),-math.huge,-math.huge)
near(p,1);near(b,log(400))
print('PASS independent rebirth arithmetic, spent-investor cap, tiny reward, huge balances and evolution bonus boundary')
