-- Generated read-only Powers and Buy inspection. No game actions.
local inspect=(function()
-- Read-only evidence for Powers, Buy and replicated-table semantics.
-- Does not require game modules, invoke remotes, change attributes or click UI.
return function()
    local function log(s)print('[SL ACTION DATA] '..s)end
    log('START v2; rebirth, evolution, confirmation and balances; read only')
    assert(game.PlaceId==79268393072444,'Run in Sell Lemons')
    local env=type(getgenv)=='function' and getgenv() or _G
    local read=type(env.getscriptbytecode)=='function' and env.getscriptbytecode or getscriptbytecode
    assert(type(read)=='function','getscriptbytecode unavailable')
    if env.SLActionInspection and env.SLActionInspection.active then log('ALREADY_RUNNING');return end
    local api={active=true};env.SLActionInspection=api
    local player=game:GetService('Players').LocalPlayer
    local own
    for _,o in ipairs(game:GetService('Workspace'):GetChildren())do
        local owner=o:FindFirstChild('Owner')
        if o.Name:match('^Tycoon%d+$') and owner and owner:IsA('ObjectValue') and owner.Value==player then own=o;break end
    end
    local function attributes(o)
        local keys={};for k in pairs(o:GetAttributes())do keys[#keys+1]=k end;table.sort(keys)
        for _,k in ipairs(keys)do
            local v=o:GetAttribute(k)
            if type(v)=='number' or type(v)=='boolean' or type(v)=='string' then
                log('ATTR '..o:GetFullName()..' @'..k..'='..tostring(v):sub(1,180))
            end
        end
    end
    if own then
        log('OWNED '..own:GetFullName())
        local values=own:FindFirstChild('Values')
        if values then
            local list={values};for _,o in ipairs(values:GetDescendants())do list[#list+1]=o end
            for i,o in ipairs(list)do
                if i>160 then log('STATE_LIMIT');break end
                log('STATE '..o:GetFullName()..' ['..o.ClassName..']');attributes(o)
            end
        end
        local count=0
        for _,o in ipairs(own:GetDescendants())do
            if o:HasTag('Tycoon.Purchasable') or o.Name=='BuyNext' or o.Name=='Purchase' then
                count=count+1;if count>30 then log('PURCHASABLE_SAMPLE_LIMIT');break end
                log('PURCHASABLE '..o:GetFullName()..' ['..o.ClassName..']');attributes(o)
                if o.Parent then attributes(o.Parent)end
            end
        end
    end
    local ranks={tycoonbalances=0,clienttycoonbalances=1,tycoonrebirth=2,clienttycoonrebirth=3,
        tycoonevolution=4,clienttycoonevolution=5,tycoonascension=6,clienttycoonascension=7,
        uialert=9,tycoonvalues=10}
    local rows={}
    for _,o in ipairs(game:GetService('ReplicatedStorage'):GetDescendants())do
        if o:IsA('ModuleScript') then
            local n=o.Name:lower();local rank=ranks[n]
            if not rank and (n:find('rebirth',1,true) or n:find('evol',1,true) or n:find('investor',1,true) or n:find('ascen',1,true) or n:find('confirm',1,true))then rank=8 end
            if rank then rows[#rows+1]={o=o,rank=rank,path=o:GetFullName()}end
        end
    end
    table.sort(rows,function(a,b)return a.rank==b.rank and a.path<b.path or a.rank<b.rank end)
    for i,row in ipairs(rows)do log('CANDIDATE '..i..' '..row.path)end
    local total=0
    for id,row in ipairs(rows)do
        if id>28 then log('SOURCE_LIMIT');break end
        local ok,data=pcall(read,row.o)
        if ok and type(data)=='string' and #data>=4 and #data<=65536 and total+#data<=524288 then
            total=total+#data;local a,b=1,0
            for i=1,#data do a=(a+data:byte(i))%65521;b=(b+a)%65521 end
            print('[SL BC] BEGIN '..id..' bytes='..#data..' adler='..(b*65536+a)..' path='..row.path)
            for offset=1,#data,192 do
                local hex=data:sub(offset,offset+191):gsub('.',function(ch)return string.format('%02x',ch:byte())end)
                print('[SL BC] PART '..id..' '..offset..' '..hex)
                if offset%3072==1 then task.wait()end
            end
            print('[SL BC] END '..id)
        else log('BYTECODE_UNAVAILABLE '..row.path..' '..(type(data)=='string' and tostring(#data) or type(data)))end
    end
    api.active=false;log('DONE; read-only inspection complete');return api
end

end)()
return inspect()
