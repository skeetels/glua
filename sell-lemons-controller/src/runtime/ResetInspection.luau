-- One retained, read-only capture for Evolution and one for Halo per client session.
return function(ctx)
    local previous=ctx.previousCycleState and ctx.previousCycleState.resetScans
    local book=previous and previous.version==1 and previous.gameVersion==game.PlaceVersion and previous
        or {version=1,gameVersion=game.PlaceVersion,rows={},sources={},bytes=0,sourceBytes=0,nextId=1000}
    ctx.S.resetScans=book
    local api={};ctx.ResetInspection=api
    local capturedSessions={}
    local function emit(lines,text)
        if book.bytes+#text>524288 then return false end
        lines[#lines+1]=text;book.bytes=book.bytes+#text;return true
    end
    local function clean(value)return tostring(value):gsub('[\r\n]',' '):sub(1,500)end
    local function path(o)return o and o:GetFullName() or 'MISSING'end
    local function note(row,text)emit(row.lines,'[SL RESET SCAN] '..row.kind..' '..text)end
    local function ownState(row)
        for _,o in ipairs(game:GetService('Workspace'):GetChildren())do
            local owner=o:FindFirstChild('Owner')
            if o.Name:match('^Tycoon%d+$') and owner and owner:IsA('ObjectValue') and owner.Value==ctx.player then
                note(row,'OWNED '..path(o))
                local remotes=o:FindFirstChild('Remotes')
                for _,name in ipairs(row.kind=='evolve' and {'Evolve','Evolved'} or {'Ascend','Ascended'})do
                    local remote=remotes and remotes:FindFirstChild(name)
                    note(row,'REMOTE '..name..' '..path(remote)..' class='..tostring(remote and remote.ClassName))
                end
                local values=o:FindFirstChild('Values');values=values and values:FindFirstChild('Values')
                for _,key in ipairs({'Evolution','Ascension','Rebirths','TotalRebirths','TotalEvolves','Cash','CashSpent','Investors','InvestorsSpent'})do
                    note(row,'VALUE '..key..'='..clean(values and values:GetAttribute(key)))
                end
                return
            end
        end
        note(row,'OWNED_NOT_FOUND')
    end
    local function control(row,role,o)
        note(row,role..' '..path(o)..' class='..tostring(o and o.ClassName)..' label='..clean(o and ctx.ResetConfirm.buttonLabel(o)))
        if not o then return end
        note(row,'CONTROL visible='..tostring(ctx.visible(o))..' active='..tostring(ctx.prop(o,'Active'))
            ..' interactable='..tostring(ctx.prop(o,'Interactable')))
        for _,key in ipairs({'Disabled','Locked','Busy','Ready','CanConfirm','CountdownRemaining'})do
            local v=ctx.attr(o,key);if v~=nil then note(row,'CONTROL_ATTR '..key..'='..clean(v))end
        end
    end
    local function modules(row)
        local read=ctx.env and ctx.env.getscriptbytecode or getscriptbytecode
        if type(read)~='function'then note(row,'BYTECODE_UNAVAILABLE getscriptbytecode');row.sourceStatus='unavailable';return end
        row.sourceStatus='running'
        local targets=row.kind=='evolve' and {UIEvolutionMenu=true,ClientTycoonEvolution=true,TycoonEvolution=true}
            or {UIAscensionMenu=true,ClientTycoonAscension=true,TycoonAscension=true}
        targets.UIAlert=true;targets.RemoteRequest=true
        row.sourceThread=task.spawn(function()
            local ok,err=pcall(function()
                local stack={game:GetService('ReplicatedStorage')};local visited=0;local matches=0
                while #stack>0 and row.sourceStatus=='running' and not ctx.S.unloaded do
                    local o=table.remove(stack);visited=visited+1
                    if visited>12000 then note(row,'MODULE_SCAN_LIMIT');break end
                    if o:IsA('ModuleScript') and targets[o.Name] then
                        matches=matches+1;if matches>12 then note(row,'MODULE_MATCH_LIMIT');break end
                        local name=path(o);note(row,'MODULE '..name)
                        if not book.sources[name] then
                            local lines={};book.sources[name]=lines
                            local good,data=pcall(read,o)
                            if row.sourceStatus~='running' or ctx.S.unloaded then return end
                            if good and type(data)=='string' and #data>=4 and #data<=65536 and book.sourceBytes+#data<=196608 then
                                book.sourceBytes=book.sourceBytes+#data;book.nextId=book.nextId+1;local id=book.nextId
                                local a,b=1,0;for i=1,#data do a=(a+data:byte(i))%65521;b=(b+a)%65521 end
                                emit(lines,'[SL BC] BEGIN '..id..' bytes='..#data..' adler='..(b*65536+a)..' path='..name)
                                for offset=1,#data,192 do
                                    local hex=data:sub(offset,offset+191):gsub('.',function(ch)return string.format('%02x',ch:byte())end)
                                    emit(lines,'[SL BC] PART '..id..' '..offset..' '..hex)
                                end
                                emit(lines,'[SL BC] END '..id)
                            else emit(lines,'[SL RESET SCAN] BYTECODE_UNAVAILABLE '..name..' reason='..(good and 'size/budget/type' or clean(data)))end
                        end
                    end
                    for _,child in ipairs(o:GetChildren())do stack[#stack+1]=child end
                    if visited%100==0 then task.wait()end
                end
                note(row,'MODULE_SCAN_DONE matches='..matches)
            end)
            if row.sourceStatus=='running'then row.sourceStatus=ok and 'complete' or 'error' end
            if not ok then note(row,'MODULE_SCAN_ERROR '..clean(err))end
        end)
        task.delay(5,function()
            if row.sourceStatus=='running'then
                row.sourceStatus='timeout';note(row,'MODULE_SCAN_TIMEOUT; controller continues')
                if row.sourceThread and type(task.cancel)=='function'then pcall(task.cancel,row.sourceThread)end
            end
        end)
    end
    local function capture(kind,stage,fn)
        if kind~='evolve' and kind~='halo' then return end
        local row=book.rows[kind]
        if not row then row={kind=kind,lines={},stages={}};book.rows[kind]=row end
        if row.stages[stage]then return end
        row.stages[stage]=true
        local ok,err=pcall(fn,row)
        if not ok then note(row,'CAPTURE_ERROR '..stage..' '..clean(err))end
    end
    function api.origin(kind,button)
        capture(kind,'origin',function(row)
            note(row,'START v1; game='..game.PlaceVersion..'; read only')
            control(row,'ORIGIN',button);ownState(row);modules(row)
        end)
    end
    function api.dialog(session,d)
        capture(session.kind,'confirmation',function(row)
            capturedSessions[session.kind]=session
            note(row,'CONFIRMATION '..clean(d.text)..' fingerprint='..clean(d.fingerprint))
            control(row,'POSITIVE',d.button)
            for i,o in ipairs(d.negatives or {})do if i>12 then break end;control(row,'NEGATIVE '..i,o)end
            local negative,why=ctx.ResetConfirm.cancelButton(d)
            note(row,'CANCEL_SELECTED '..path(negative)..' reason='..tostring(why))
            ownState(row);note(row,'BUTTONS_DONE; retained in F7 report')
        end)
    end
    function api.finish(session,ok)
        if capturedSessions[session.kind]~=session then return end
        capturedSessions[session.kind]=nil
        capture(session.kind,'outcome',function(row)
            note(row,'OUTCOME receipt='..tostring(ok)..' cancelled='..tostring(session.cancelledReason)..' error='..tostring(session.error))
            ownState(row)
        end)
    end
    function api.report()
        local lines={'--- RETAINED EVOLUTION / HALO SCANS v1 ---'}
        for _,kind in ipairs({'evolve','halo'})do
            local row=book.rows[kind]
            lines[#lines+1]='[SL RESET SCAN] '..kind..' status='..(row and ('origin='..tostring(row.stages.origin)..'; confirmation='..tostring(row.stages.confirmation)..'; sources='..tostring(row.sourceStatus)) or 'waiting for first automatic reset')
            for _,line in ipairs(row and row.lines or {})do lines[#lines+1]=line end
        end
        local paths={};for name in pairs(book.sources)do paths[#paths+1]=name end;table.sort(paths)
        for _,name in ipairs(paths)do for _,line in ipairs(book.sources[name])do lines[#lines+1]=line end end
        return table.concat(lines,'\n')
    end
    function api.dispose()
        for _,row in pairs(book.rows)do
            if row.sourceStatus=='running'then
                row.sourceStatus='interrupted';note(row,'MODULE_SCAN_INTERRUPTED')
                if row.sourceThread and type(task.cancel)=='function'then pcall(task.cancel,row.sourceThread)end
            end
        end
    end
end
