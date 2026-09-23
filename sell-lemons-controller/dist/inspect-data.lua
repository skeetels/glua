-- Generated read-only diagnostic. Does not start or reload the controller.
local initialize=(function()
-- Read-only schema discovery. Does not require modules, invoke remotes or open GUI.
return function(ctx)
    local function read(o,key)
        local ok,value=pcall(function() return o[key] end)
        if ok then return value end
    end
    local function call(o,method)
        local ok,value=pcall(function() return o[method](o) end)
        return ok and type(value)=='table' and value or {}
    end
    local function isa(o,class)
        local ok,value=pcall(function() return o:IsA(class) end)
        return ok and value
    end
    local function relevant(name)
        -- CamelCase boundaries avoid matching 'evol' across AmbienceVolume.
        local words=tostring(name):gsub('(%l)(%u)','%1 %2'):lower()
        for word in words:gmatch('%a+') do
            for _,prefix in ipairs({'cash','money','invest','rebirth','evol','halo','income',
                'lemon','level','prestige','ascen','profit','multiplier','currency','balance',
                'bank','stand','tycoon','replica','data','stat','upgrade'}) do
                if word:sub(1,#prefix)==prefix then return true end
            end
        end
        return false
    end
    local function valueText(value)
        if type(value)=='number' or type(value)=='boolean' then return tostring(value) end
        if type(value)=='string' and #value<=96 then
            -- Preserve formatted Cash such as '$3.339 undecillion'.
            -- Other strings remain type-only, including arbitrary user text.
            local s=value:match('^%s*(.-)%s*$')
            if s:match('^[$%+%-]?%d') and s:match('^[%w%s%$%+%-%.,%%{}%[%]:]+$') then
                return string.format('%q',s)
            end
        end
        return '['..type(value)..']'
    end
    function ctx.API.inspectData()
        local out={'[SL DATA v2] BEGIN t='..tostring(os.clock())..' (unverified semantics)'}
        local total=0
        local others={}
        local ok,players=pcall(function() return game:GetService('Players'):GetPlayers() end)
        if ok then
            for _,p in ipairs(players) do
                if p~=ctx.player then others[tostring(p.Name)]=true;others[tostring(p.UserId)]=true end
            end
        end
        local function scan(root,label,maxNodes,maxLines,maxDepth)
            out[#out+1]='[SL DATA v2] ROOT '..label
            local queue={{root,label,0}};local head=1;local examined=0;local lines=0;local limited=false
            local function emit(s)
                if lines<maxLines then out[#out+1]=s;lines=lines+1 else limited=true end
            end
            while head<=#queue and examined<maxNodes and lines<maxLines do
                local item=queue[head];head=head+1
                local o,path,depth=item[1],item[2],item[3]
                if o and (o==ctx.player or (not others[tostring(read(o,'Name'))] and not isa(o,'PlayerGui')
                    and not isa(o,'Backpack') and not isa(o,'Player'))) then
                    examined=examined+1
                    local class=tostring(read(o,'ClassName'))
                    local source=isa(o,'LuaSourceContainer')
                    local remote=isa(o,'RemoteEvent') or isa(o,'RemoteFunction')
                    if depth<=1 or (source or remote) and relevant(path) then
                        emit(path..' ['..class..']'..(source and ' (name only; not required)' or ''))
                    end
                    if not source and not remote then
                        local attrs=call(o,'GetAttributes');local keys={}
                        for key in pairs(attrs) do if relevant(key) then keys[#keys+1]=key end end
                        table.sort(keys)
                        for _,key in ipairs(keys) do emit(path..' @'..key..' = '..valueText(attrs[key])) end
                        if isa(o,'ValueBase') and relevant(path) then
                            emit(path..' .Value = '..valueText(read(o,'Value')))
                        end
                    end
                    if not source and not remote and not isa(o,'BasePart') then
                        local children=call(o,'GetChildren')
                        if depth>=maxDepth and #children>0 then limited=true end
                        if depth<maxDepth then
                            for _,child in ipairs(children) do
                                if #queue>=maxNodes then limited=true;break end
                                queue[#queue+1]={child,path..'/'..tostring(read(child,'Name')),depth+1}
                            end
                        end
                    end
                end
            end
            total=total+examined
            if head<=#queue then limited=true end
            out[#out+1]='[SL DATA v2] END_ROOT '..label..' examined='..examined..' limited='..tostring(limited)
        end
        scan(ctx.player,'LocalPlayer',160,100,7)
        local storageOK,storage=pcall(function() return game:GetService('ReplicatedStorage') end)
        if storageOK then scan(storage,'ReplicatedStorage',700,150,9) end
        -- Only descend into a tycoon explicitly owned by LocalPlayer.
        local worldOK,world=pcall(function() return game:GetService('Workspace') end)
        if worldOK then
            local listed=0
            for _,root in ipairs(call(world,'GetChildren')) do
                if tostring(read(root,'Name')):lower():match('^tycoon') then
                    listed=listed+1;if listed>20 then out[#out+1]='[SL DATA v2] Tycoon root list limited';break end
                    local owner=nil
                    for key,value in pairs(call(root,'GetAttributes')) do
                        local k=tostring(key):lower():gsub('[^%a]','')
                        if k=='owner' or k=='ownerid' or k=='owneruserid' or k=='player' or k=='playerid' or k=='userid' then
                            owner=value;break
                        end
                    end
                    if owner==nil then
                        for _,child in ipairs(call(root,'GetChildren')) do
                            local n=tostring(read(child,'Name')):lower()
                            if (n=='owner' or n=='player') and isa(child,'ValueBase') then owner=read(child,'Value');break end
                        end
                    end
                    local ours=owner~=nil and (owner==ctx.player or owner==ctx.player.UserId
                        or owner==tostring(ctx.player.UserId) or owner==ctx.player.Name)
                    local label='Workspace/'..tostring(read(root,'Name'))
                    out[#out+1]='[SL DATA v2] '..label..' owner='..(ours and 'local' or owner==nil and 'unresolved' or 'other')
                    if ours then scan(root,label,500,100,6) end
                end
            end
        end
        out[#out+1]='[SL DATA v2] END examined='..total..'. No candidates auto-bound; no reset authority. Limits do not prove absence of data.'
        return table.concat(out,'\n')
    end
end

end)()
assert(game.PlaceId==79268393072444,"Run in Sell Lemons")
local context={API={},player=game:GetService("Players").LocalPlayer}
assert(context.player,"LocalPlayer is not ready")
initialize(context)
for sample=1,2 do
    print("[SL DATA v2] SAMPLE "..sample)
    for line in context.API.inspectData():gmatch("[^\n]+") do print(line) end
    if sample==1 then task.wait(3) end
end
