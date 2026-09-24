-- Generated read-only game version compatibility audit. No game actions.
local inspect=(function()
-- Read-only bytecode identity audit after a Sell Lemons update.
-- Reads game ModuleScripts; never requires one or invokes a game remote.
return function()
    assert(game.PlaceId==79268393072444,'Run in Sell Lemons')
    local env=type(getgenv)=='function' and getgenv() or _G
    local reader=type(env.getscriptbytecode)=='function' and env.getscriptbytecode or getscriptbytecode
    assert(type(reader)=='function','getscriptbytecode unavailable')
    local rs=game:GetService('ReplicatedStorage')
    local specs={
        {'Balance',340421,914084511},{'Config',19699,154165715},
        {'Modules.Huge',8091,539421471},
        {'Modules.Tycoon.Component.TycoonValues',1214,285065225},
        {'Modules.Tycoon.Entity.TycoonEarner',5781,1426949448},
        {'Modules.Tycoon.Entity.Client.ClientTycoonEarner',9539,1200172661},
        {'Modules.Tycoon.Component.TycoonIncome',7049,3274092081},
        {'Modules.Tycoon.Component.TycoonPowers',3681,2346706770},
        {'Core.InstanceTable',13745,871009961},
        {'Modules.Tycoon.Component.TycoonInversion',4321,2891158939},
        {'Modules.Tycoon.Component.TycoonAscension',3824,2161590675},
        {'Modules.Tycoon.Component.Client.ClientTycoonPowers',1499,4053663912},
        {'Modules.Tycoon.Entity.Client.ClientTycoonPurchase',9384,2072785969},
        {'Modules.Tycoon.Entity.TycoonPurchase',3004,2893670776},
        {'Modules.Tycoon.Component.TycoonPurchases',2551,2335596492},
        {'Modules.UI.Layers.HUD.UIPowerBuyNext',4310,3175981909},
        {'Modules.Tycoon.Component.TycoonBalances',4280,537675623},
        {'Modules.Tycoon.Component.TycoonRebirth',6310,4193420756},
        {'Modules.Tycoon.Component.Client.ClientTycoonRebirth',1232,3294875325},
        {'Modules.Tycoon.Component.TycoonEvolution',6812,3704414728},
        {'Modules.Player.PremiumPurchases',2741,3733814504},
        {'Config.PlaceDifferences',128,3292598373},
        {'Modules.Service.PlaceDifferenceService',1131,2205924379},
        {'Modules.UI.Layers.Rebirth.UIEvolutionMenu',7634,4240708282},
        {'Modules.Tycoon.Component.Client.ClientTycoonEvolution',1229,3782527611},
        {'Modules.UI.Layers.Rebirth.UIAscensionMenu',11995,1534588081},
        {'Modules.Tycoon.Component.Client.ClientTycoonAscension',1176,3761947570},
        {'Core.RemoteRequest',4201,653841906},
    }
    local function object(path)
        local o=rs
        for part in path:gmatch('[^.]+')do o=o and o:FindFirstChild(part)end
        return o
    end
    local function adler(bytes)
        local a,b=1,0
        for i=1,#bytes do a=(a+bytes:byte(i))%65521;b=(b+a)%65521 end
        return b*65536+a
    end
    print('[SL COMPAT] START game='..tostring(game.PlaceVersion)..' modules='..#specs)
    local config
    for _,spec in ipairs(specs)do
        local o=object(spec[1]);local ok,bytes=pcall(reader,o)
        if not ok or type(bytes)~='string'then
            print('[SL COMPAT] ERROR '..spec[1]..' '..tostring(bytes))
        else
            local hash=adler(bytes)
            print('[SL COMPAT] '..(hash==spec[3] and #bytes==spec[2] and 'MATCH ' or 'CHANGED ')..spec[1]..' bytes='..#bytes..' adler='..hash)
            if spec[1]=='Config' and (hash~=spec[3] or #bytes~=spec[2])then config=bytes end
        end
        task.wait()
    end
    if config and #config<=65536 then
        print('[SL COMPAT] CONFIG_BEGIN bytes='..#config..' adler='..adler(config))
        for offset=1,#config,192 do
            local hex=config:sub(offset,offset+191):gsub('.',function(ch)return string.format('%02x',ch:byte())end)
            print('[SL COMPAT] CONFIG_PART '..offset..' '..hex)
            if offset%3072==1 then task.wait()end
        end
        print('[SL COMPAT] CONFIG_END')
    end
    print('[SL COMPAT] DONE')
end

end)()
return inspect()
