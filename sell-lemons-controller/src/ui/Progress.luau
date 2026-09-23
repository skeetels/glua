-- Component initialized with an explicit shared service context.
return function(__slctx)
-- Display-only observer. Never changes reset gates or opens a menu.
__slctx.evolutionView=nil
function __slctx.evolutionProgressView(route)
    local e=route.evo
    if not e then __slctx.evolutionView=nil;return 'До следующей эволюции: считываю прогресс…',0 end
    if not __slctx.evolutionView or __slctx.evolutionView.index~=e.index then
        __slctx.evolutionView={index=e.index,pct=e.pct,time=e.time,sourceTime=e.time}
    elseif (e.time or 0)>(__slctx.evolutionView.sourceTime or 0) then
        __slctx.evolutionView.pct=e.pct;__slctx.evolutionView.time=e.time;__slctx.evolutionView.sourceTime=e.time
    end
    local v=__slctx.evolutionView
    local base=__slctx.paths.evolution..'/Body/'
    local index=tonumber(__slctx.t(base..'Current/What'):lower():match('evolution%s+(%d+)'))
    local raw=__slctx.t(base..'Progress');local current=__slctx.Core.percent(raw)
    -- Hidden labels may stop updating. Use changed text or a visible menu,
    -- otherwise retain the timestamp from the last actual observation.
    if not __slctx.S.resetSession and index==e.index and current~=nil
        and (__slctx.visible(__slctx.g(__slctx.paths.evolution)) or v.raw~=nil and raw~=v.raw) then
        v.pct=current;v.time=__slctx.now()
    end
    v.raw=raw
    local pct=v.pct and math.max(0,math.min(100,v.pct)) or nil
    local heading='До E'..tostring(e.index+1)..(route.targetFruit and (' · '..route.targetFruit) or '')
        ..': '..(pct and string.format('%.2f%%',pct) or 'процент пока недоступен')
    local total=__slctx.Planner.totalMinimum(route.latestInvestors,route.spent)
    local target=route.target
    local amounts='Инвесторы: считываю количество…'
    if total and target then
        amounts='Инвесторы: '..(route.spentUnknown and '≥ ' or '≈ ')..__slctx.BN.format(total)..' / ≈ '..__slctx.BN.format(target)
            ..'\nОсталось: '..(route.spentUnknown and 'не больше ≈ ' or '≈ ')..__slctx.BN.format(__slctx.BN.sub(target,total))
    elseif total then
        amounts='Инвесторы: '..(route.spentUnknown and '≥ ' or '≈ ')..__slctx.BN.format(total)..'; цель уточняется в игре'
    end
    local age=v.time and math.max(0,math.floor(__slctx.now()-v.time)) or nil
    if age and age>=2 then heading=heading..' ('..age..' с назад)' end
    return heading..'\n'..amounts,(pct or 0)/100
end


end
