-- Bounded, read-only schema report for validating a future data adapter.
-- PlayerGui, scripts, other players and remote invocations are deliberately excluded.
return function(ctx)
    function ctx.API.inspectData()
        local out={'Sell Lemons / client data candidates (unverified semantics)'}
        local examined=0
        local function relevant(name)
            name=name:lower()
            for _,word in ipairs({'cash','money','invest','rebirth','evol','halo','income','lemon','level','prestige'}) do
                if name:find(word,1,true) then return true end
            end
            return false
        end
        local function valueText(value)
            if type(value)=='number' or type(value)=='boolean' then return tostring(value) end
            if type(value)=='string' and #value<=80 and value:match('^[%d%s%+%-%.,eE%%]+$') then return value end
            return '['..type(value)..']'
        end
        local function visit(o,path,depth)
            if examined>=600 or depth>6 or #out>=180 then return end
            examined=examined+1
            if o:IsA('PlayerGui') or o:IsA('LuaSourceContainer') or o:IsA('Backpack') then return end
            local ok,attributes=pcall(o.GetAttributes,o)
            if ok then
                for name,value in pairs(attributes) do
                    if relevant(name) then out[#out+1]=path..' @'..name..' = '..valueText(value) end
                    if #out>=180 then break end
                end
            end
            if o:IsA('ValueBase') and relevant(path) then out[#out+1]=path..' .Value = '..valueText(ctx.prop(o,'Value')) end
            for _,child in ipairs(o:GetChildren()) do visit(child,path..'/'..child.Name,depth+1) end
        end
        visit(ctx.player,'LocalPlayer',0)
        out[#out+1]='Examined '..examined..' objects. No candidates were auto-bound or treated as reset authority.'
        return table.concat(out,'\n')
    end
end
