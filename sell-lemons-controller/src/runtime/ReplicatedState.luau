-- Schema observed in the user's live log, 2026-09-23. Never invokes remotes.
-- Encodings are calibrated independently against visible GUI values before use.
return function(ctx)
    local data={modes={},evidence={},revision=0,nextPoll=0}
    ctx.Data=data
    local guiCash=ctx.cash
    local counters={'Evolution','Ascension','Rebirths','TotalRebirths','TotalEvolves'}
    local amounts={'Cash','CashSpent','Investors','InvestorsSpent'}
    local function children(o)
        local ok,v=pcall(function()return o:GetChildren()end)
        return ok and v or {}
    end
    local function child(o,name)
        local ok,v=pcall(function()return o:FindFirstChild(name)end)
        return ok and v or nil
    end
    local function attributes(o)
        local ok,v=pcall(function()return o:GetAttributes()end)
        return ok and v or {}
    end
    local function finite(v)return type(v)=='number' and v==v and math.abs(v)<math.huge end
    local function integer(v)return finite(v) and v>=0 and v%1==0 end
    local function owned(root,world)
        local owner=child(root,'Owner')
        return root and root.Parent==world and owner and ctx.prop(owner,'Value')==ctx.player
    end
    local function clear()
        data.root=nil;data.values=nil;data.snapshot=nil;data.modes={};data.evidence={};data.lastGate=nil;data.reported=nil
    end
    local function bind()
        local ok,world=pcall(function()return game:GetService('Workspace')end)
        if not ok then clear();return false end
        if owned(data.root,world) and data.values==child(child(data.root,'Values'),'Values') then return true end
        clear()
        for _,root in ipairs(children(world)) do
            if tostring(root.Name):match('^Tycoon%d+$') and owned(root,world) then
                local values=child(child(root,'Values'),'Values')
                if values then
                    data.root=root;data.values=values
                    ctx.log('DATA_SOURCE','Workspace/'..root.Name..'/Values/Values; owned by LocalPlayer; amounts await calibration')
                    return true
                end
            end
        end
        return false
    end
    local function decode(raw,mode)
        if not finite(raw) then return nil end
        if mode=='linear' then return raw>=0 and ctx.BN.new(raw) or nil end
        -- Raw zero/negative values may be game-specific sentinels. Leave them unknown.
        if mode=='log10' and raw>0 and raw<1e12 then
            local exponent=math.floor(raw)
            return ctx.BN.new(10^(raw-exponent),exponent)
        end
    end
    local function agrees(a,b)
        return a and b and a.m>0 and b.m>0 and math.abs(ctx.BN.log(a)-ctx.BN.log(b))<=0.002
    end
    local function calibrate(field,raw,reference)
        if not reference or reference.m<=0 or not finite(raw) then return end
        local linear=agrees(decode(raw,'linear'),reference)
        local logarithmic=agrees(decode(raw,'log10'),reference)
        local match=linear~=logarithmic and (linear and 'linear' or 'log10') or nil
        local old=data.modes[field]
        if old and match~=old then
            data.modes[field]=nil;data.evidence[field]=nil
            ctx.log('DATA_ENCODING_REVOKED',field..'; visible reference no longer matches')
        end
        if not match then data.evidence[field]=nil;return end
        local e=data.evidence[field]
        if not e or e.mode~=match then e={mode=match,count=0,at=-math.huge};data.evidence[field]=e end
        if ctx.now()-e.at>=0.2 then e.count=e.count+1;e.at=ctx.now() end
        if e.count>=3 and not data.modes[field] then
            data.modes[field]=match
            ctx.log('DATA_ENCODING_VERIFIED',field..'='..match..'; raw='..raw..'; GUI='..ctx.BN.format(reference)..'; samples='..e.count)
        end
    end
    function data.poll(force)
        if ctx.S.unloaded then return nil end
        if not force and ctx.now()<data.nextPoll then return data.snapshot end
        data.nextPoll=ctx.now()+0.25
        if not bind() then return nil end
        local attrs=attributes(data.values)
        local snapshot={source='Workspace/'..data.root.Name..'/Values/Values',time=ctx.now(),raw={},counters={},upgrades={},amounts={},encodings={}}
        for _,name in ipairs(counters) do if integer(attrs[name]) then snapshot.counters[name]=attrs[name] end end
        for _,name in ipairs(amounts) do if finite(attrs[name]) then snapshot.raw[name]=attrs[name] end end
        local upgrades=attributes(child(child(data.root,'Values'),'Upgrades'))
        for name,value in pairs(upgrades) do if integer(value) then snapshot.upgrades[name]=value end end
        local gate=table.concat({tostring(attrs.Evolution),tostring(attrs.Ascension),tostring(attrs.Rebirths)},'|')
        if data.lastGate and gate~=data.lastGate then
            data.modes={};data.evidence={}
            if ctx.Observer then ctx.Observer.store:invalidate('replicated reset counters changed') end
        end
        local changed=data.snapshot and (gate~=data.lastGate or data.snapshot.raw.Investors~=snapshot.raw.Investors)
        data.lastGate=gate
        if not ctx.S.resetSession and not ctx.S.resetChildPending then
            calibrate('Cash',attrs.Cash,guiCash())
            local base=ctx.paths.investors..'/Body/'
            if ctx.visible(ctx.g(ctx.paths.investors)) and ctx.t(base..'Amount/What'):lower()=='investors' then
                calibrate('Investors',attrs.Investors,ctx.BN.parse(ctx.t(base..'Amount/Quantity')))
            end
        end
        for name,mode in pairs(data.modes) do
            snapshot.amounts[name]=decode(snapshot.raw[name],mode);snapshot.encodings[name]=mode
        end
        data.revision=data.revision+1;snapshot.revision=data.revision;data.snapshot=snapshot
        if not data.reported then
            data.reported=true
            ctx.log('DATA_SNAPSHOT','Evolution='..tostring(attrs.Evolution)..'; Ascension='..tostring(attrs.Ascension)
                ..'; Rebirths='..tostring(attrs.Rebirths)..'; Cash raw='..tostring(attrs.Cash)..'; Investors raw='..tostring(attrs.Investors))
        end
        if changed and ctx.S.route and ctx.S.route.halo30 then ctx.S.route.halo30.progressReviewHint=true end
        return snapshot
    end
    function ctx.cash()
        local snapshot=data.poll(true)
        return snapshot and snapshot.amounts.Cash or guiCash()
    end
    function ctx.API.dataSnapshot()return data.poll(true) end
    function ctx.API.dataReport()
        local snapshot=data.poll(true)
        if not snapshot then return '[SL STATE] owned replicated state unavailable; GUI fallback' end
        local out={'[SL STATE] '..snapshot.source}
        for _,name in ipairs(counters) do out[#out+1]=name..'='..tostring(snapshot.counters[name]) end
        for _,name in ipairs(amounts) do
            out[#out+1]=name..' raw='..tostring(snapshot.raw[name])..'; mode='..tostring(snapshot.encodings[name])
                ..'; decoded='..ctx.BN.format(snapshot.amounts[name])
        end
        local names={};for name in pairs(snapshot.upgrades)do names[#names+1]=name end;table.sort(names)
        for _,name in ipairs(names)do out[#out+1]='Upgrade '..name..'='..snapshot.upgrades[name]end
        out[#out+1]='Pending rebirth reward and evolution readiness still require GUI evidence.'
        return table.concat(out,'\n')
    end
end
