-- Component initialized with an explicit shared service context.
return function(__slctx)
__slctx.ResetConfirm = {}
__slctx.confirmKinds = {rebirth=true, evolve=true, halo=true}
__slctx.positiveLabels = {['upgrade!']=true,yes=true,ok=true,okay=true,confirm=true,accept=true,continue=true,
    proceed=true,['do it']=true,['да']=true,['ок']=true,['подтвердить']=true,
    ['подтверждаю']=true,['продолжить']=true,['хорошо']=true}
__slctx.purchaseLabels={buy=true,purchase=true,upgrade=true,['купить']=true,['улучшить']=true}
__slctx.purchaseKinds={buy=true,upgrade=true,power=true,tablet=true}
__slctx.negativeLabels = {nvm=true,['never mind']=true,no=true,cancel=true,back=true,decline=true,close=true,x=true,['not now']=true,
    ['нет']=true,['отмена']=true,['назад']=true,['не сейчас']=true}
__slctx.operationLabels = {rebirth='rebirth',evolve='evolve',evolution='evolve',
    ascend='halo',ascension='halo',halo='halo',['переродиться']='rebirth',
    ['перерождение']='rebirth',['эволюция']='evolve',['эволюционировать']='evolve'}
__slctx.russianUpper = {'А','Б','В','Г','Д','Е','Ё','Ж','З','И','Й','К','Л','М','Н','О','П','Р','С','Т','У','Ф','Х','Ц','Ч','Ш','Щ','Ъ','Ы','Ь','Э','Ю','Я'}
__slctx.russianLower = {'а','б','в','г','д','е','ё','ж','з','и','й','к','л','м','н','о','п','р','с','т','у','ф','х','ц','ч','ш','щ','ъ','ы','ь','э','ю','я'}
function __slctx.ResetConfirm.normalize(value)
    local s=__slctx.Core.clean(value):lower()
    for i,u in ipairs(__slctx.russianUpper) do s=s:gsub(u,__slctx.russianLower[i]) end
    return s:gsub('[%p]',' '):gsub('%s+',' '):match('^%s*(.-)%s*$')
end
function __slctx.word(s,w) return (' '..s..' '):find(' '..w..' ',1,true)~=nil end
function __slctx.ResetConfirm.operation(s)
    s=__slctx.ResetConfirm.normalize(s)
    local matches={}
    for term,kind in pairs(__slctx.operationLabels) do if __slctx.word(s,term) then matches[kind]=true end end
    local found=nil
    for kind in pairs(matches) do if found then return nil,'multiple' end;found=kind end
    return found
end
function __slctx.ResetConfirm.buttonLabel(button)
    local own=__slctx.txt(button)
    if own~='' then return own end
    for _,name in ipairs({'Title','Label','Text','TextLabel'}) do
        local child=button:FindFirstChild(name)
        if child and __slctx.visible(child) and __slctx.txt(child)~='' then return __slctx.txt(child) end
    end
    local texts={}
    for _,o in ipairs(button:GetDescendants()) do
        if o:IsA('TextLabel') and __slctx.visible(o) and __slctx.txt(o)~='' then texts[#texts+1]=__slctx.txt(o) end
        if #texts>=8 then break end
    end
    if #texts>0 then return table.concat(texts,' ') end
    return tostring(button.Name)
end
function __slctx.ResetConfirm.caption(button)
    local raw=__slctx.Core.clean(__slctx.ResetConfirm.buttonLabel(button)):lower()
    for i,u in ipairs(__slctx.russianUpper) do raw=raw:gsub(u,__slctx.russianLower[i]) end
    local seconds=nil
    local function duration(tail)
        local n,unit=tail:match('^%s*(%d+%.?%d*)%s*([^%d]-)%s*$')
        unit=unit and unit:match('^%s*(.-)%s*$')
        if n and (unit=='' or unit=='s' or unit=='sec' or unit=='secs' or unit=='seconds'
            or unit=='second' or unit=='с' or unit=='сек' or unit=='сек.' or unit=='секунд') then
            return tonumber(n)
        end
    end
    local base,tail=raw:match('^(.-)%s*%((.-)%)%s*$')
    if not base then base,tail=raw:match('^(.-)%s*%[(.-)%]%s*$') end
    if base and duration(tail) then seconds=duration(tail);raw=base end
    local stem,number,unit=raw:match('^(.-)%s+in%s+(%d+%.?%d*)%s*(%a*)%s*$')
    if not stem then stem,number,unit=raw:match('^(.-)%s+через%s+(%d+%.?%d*)%s*(.-)%s*$') end
    if stem and duration(number..' '..(unit or '')) then seconds=duration(number..' '..(unit or ''));raw=stem end
    -- A bare numeric suffix is a countdown only on a recognized confirmation caption.
    local simple,n=raw:match('^(.-)%s+(%d+%.?%d*)%s*$')
    if not simple then simple,n=raw:match('^(.-)%s+(%d+%.?%d*)%s*s%s*$') end
    if simple then
        local normalized=__slctx.ResetConfirm.normalize(simple)
        if __slctx.positiveLabels[normalized] or __slctx.operationLabels[normalized] then seconds=tonumber(n);raw=simple end
    end
    return __slctx.ResetConfirm.normalize(raw),seconds
end
function __slctx.ResetConfirm.buttonRole(button)
    local label=__slctx.ResetConfirm.caption(button)
    if __slctx.negativeLabels[label] then return 'negative',label end
    if __slctx.positiveLabels[label] or __slctx.purchaseLabels[label] then return 'positive',label end
    if label==__slctx.ResetConfirm.normalize(button.Name) then
        label=label:gsub('button$',''):gsub('%s+$','')
        if __slctx.negativeLabels[label] then return 'negative',label end
        if __slctx.positiveLabels[label] then return 'positive',label end
    end
    local kind=__slctx.operationLabels[label]
    if kind then return 'positive',label,kind end
    local rest=label:match('^yes%s+(.+)$') or label:match('^confirm%s+(.+)$')
        or label:match('^да%s+(.+)$') or label:match('^подтвердить%s+(.+)$')
    if rest and __slctx.operationLabels[rest] then return 'positive',label,__slctx.operationLabels[rest] end
    if rest and __slctx.purchaseLabels[rest] then return 'positive',label end
    return nil,label
end
function __slctx.ResetConfirm.countdown(button,root)
    local _,seconds=__slctx.ResetConfirm.caption(button)
    local maximum=seconds or 0
    for _,o in ipairs({button,root}) do
        for _,key in ipairs({'CountdownRemaining','SecondsRemaining','TimeLeft','RemainingSeconds'}) do
            local n=tonumber(__slctx.attr(o,key))
            if n and n>maximum and n<3600 then maximum=n end
        end
    end
    -- Dedicated visible timer labels may sit next to the affirmative button.
    for _,o in ipairs(root:GetDescendants()) do
        local name=tostring(o.Name):lower()
        if o:IsA('TextLabel') and __slctx.visible(o) and (name:find('countdown',1,true)
            or name=='timer' or name=='timeleft' or name=='remaining') then
            local value=__slctx.Core.clean(__slctx.txt(o)):lower()
            local n=tonumber(value:match('^%s*(%d+%.?%d*)%s*[a-z]*%s*$'))
                or tonumber(value:match('^%s*(%d+%.?%d*)%s*сек'))
            local m,sec=value:match('^(%d+):(%d%d)$')
            if m then n=tonumber(m)*60+tonumber(sec) end
            if n and n>maximum and n<3600 then maximum=n end
        end
    end
    return maximum
end
function __slctx.ResetConfirm.ready(button,root)
    if not __slctx.usable(button) then return false,'BUTTON_DISABLED' end
    for _,o in ipairs({button,root}) do
        for _,key in ipairs({'Disabled','Locked','CooldownActive','Processing','Busy'}) do
            if __slctx.attr(o,key)==true then return false,key end
        end
        if __slctx.attr(o,'CanConfirm')==false or __slctx.attr(o,'Ready')==false then return false,'NOT_READY' end
    end
    local left=__slctx.ResetConfirm.countdown(button,root)
    if left>0 then return false,'COUNTDOWN '..tostring(left) end
    return true
end
function __slctx.ResetConfirm.excluded(o)
    local p=o
    for _=1,80 do
        if not p or p==__slctx.gui then break end
        local n=tostring(p.Name):lower()
        if n:find('chat',1,true) or n:find('bubble',1,true) or n:find('slautofarm',1,true)
            or n:find('sldiagnostic',1,true) or n=='phone' or n=='slvirtualinputprobe' then return true end
        p=__slctx.prop(p,'Parent')
    end
    return false
end
function __slctx.ResetConfirm.path(o)
    local parts={}
    for _=1,80 do
        if not o or o==__slctx.gui then break end
        table.insert(parts,1,tostring(o.Name));o=__slctx.prop(o,'Parent')
    end
    return 'PlayerGui/'..table.concat(parts,'/')
end
function __slctx.ResetConfirm.buttons(scope)
    local out,modals,stack={}, {}, {scope or __slctx.gui};local visited=0
    while #stack>0 do
        local o=table.remove(stack);visited=visited+1
        if visited>__slctx.CONFIG.ConfirmScanLimit then return out,false,modals end
        if not __slctx.ResetConfirm.excluded(o) and (o==__slctx.gui or __slctx.visible(o)) then
            if o:IsA('GuiButton') then out[#out+1]=o end
            local n=tostring(o.Name):lower()
            if o:IsA('GuiObject') and (n=='alert' or n:find('dialog',1,true)
                or n:find('confirmation',1,true) or n=='prompt' or n=='popup' or n=='modal') then
                modals[#modals+1]=o
            end
            for _,child in ipairs(o:GetChildren()) do stack[#stack+1]=child end
        end
        if visited%__slctx.CONFIG.ScanYieldEvery==0 then task.wait() end
    end
    return out,true,modals
end
function __slctx.ResetConfirm.describe(root)
    local texts,contextTexts,headers,positives,negatives={}, {}, {}, {}, {}
    local stack={root};local visited=0;local paidContent=false
    while #stack>0 do
        local o=table.remove(stack);visited=visited+1
        if visited>300 then return nil,'DIALOG_TOO_LARGE' end
        if visited%__slctx.CONFIG.ScanYieldEvery==0 then task.wait() end
        -- Live v6916: Main/Sale is a separate optional Robux offer, outside
        -- Main/Buttons. Exclude only that exact sibling subtree from context.
        local separateSale=root==__slctx.g('Important/Alert/Main') and o==__slctx.at(root,'Sale')
        if not separateSale and __slctx.visible(o) and not __slctx.ResetConfirm.excluded(o) then
            local asset=tostring(__slctx.attr(o,'AssetName') or ''):lower()
            local method=tostring(__slctx.attr(o,'Method') or ''):lower()
            if asset:find('robux',1,true) or method:find('prompt',1,true) and method:find('purchase',1,true) then paidContent=true end
            if o:IsA('TextLabel') or o:IsA('TextButton') then
                local value=__slctx.txt(o)
                if value~='' then
                    texts[#texts+1]=value
                    local control=o;local insideButton=false
                    for _=1,20 do
                        if not control then break end
                        if control:IsA('GuiButton') then insideButton=true;break end
                        if control==root then break end
                        control=__slctx.prop(control,'Parent')
                    end
                    if not insideButton and not tostring(o.Name):lower():find('countdown',1,true)
                        and tostring(o.Name):lower()~='timer' and tostring(o.Name):lower()~='timeleft' then
                        contextTexts[#contextTexts+1]=value
                        local n=tostring(o.Name):lower()
                        if n=='title' or n=='heading' or n=='header' then headers[#headers+1]=value end
                    end
                end
            end
            if o:IsA('GuiButton') then
                local role=__slctx.ResetConfirm.buttonRole(o)
                if role=='positive' then positives[#positives+1]=o
                elseif role=='negative' then negatives[#negatives+1]=o end
            end
            for _,child in ipairs(o:GetChildren()) do stack[#stack+1]=child end
        end
    end
    table.sort(texts);table.sort(contextTexts);table.sort(headers)
    return {root=root,text=table.concat(texts,' | '),context=table.concat(contextTexts,' | '),header=table.concat(headers,' | '),
        positives=positives,negatives=negatives,paid=paidContent}
end
-- Live v6916 informational notice, not a reset or another purchase.
function __slctx.ResetConfirm.staircaseNotice()
    local alert=__slctx.g('Important/Alert');local main=__slctx.g('Important/Alert/Main')
    if not __slctx.visible(alert) or not __slctx.visible(main) then return nil end
    local d=__slctx.ResetConfirm.describe(main)
    if not d or d.paid then return nil end
    local intro='by the way that purchase was permanent'
    local body='staircase purchases survive both rebirth and evolution'
    local context=__slctx.ResetConfirm.normalize(d.context)
    if context~=intro..' '..body and context~=body..' '..intro then return nil end
    local controls=__slctx.at(main,'Buttons');local chosen=nil
    for _,b in ipairs(controls and controls:GetChildren() or {}) do
        if b:IsA('GuiButton') and __slctx.visible(b) then
            local role,label=__slctx.ResetConfirm.buttonRole(b)
            if label=='nice' then
                if chosen then return nil end
                chosen=b
            elseif role~='negative' then return nil end
        end
    end
    if not chosen or #d.positives>0 then return nil end
    d.button=chosen;d.notice=true
    d.fingerprint='staircase-notice|'..__slctx.ResetConfirm.path(main)..'|'..context..'|nice'
    return d
end
function __slctx.ResetConfirm.dismissNotice(d)
    if not d then return true end
    if not __slctx.live() or __slctx.S.resetSession or __slctx.S.resetChildPending or __slctx.S.actionPending then return false end
    __slctx.status('NOTICE_CLOSE','Закрываю сообщение о постоянной покупке Staircase…')
    local alert=__slctx.g('Important/Alert')
    local deadline=__slctx.now()+__slctx.CONFIG.ConfirmWaitTimeout
    -- The notice can become visible before its Nice button is active. A disabled
    -- button during the animation is not a failed click or a reason to pause.
    while __slctx.live() and __slctx.visible(alert) do
        local fresh=__slctx.ResetConfirm.staircaseNotice()
        if not fresh or fresh.fingerprint~=d.fingerprint then return false,'NOTICE_CONTEXT_CHANGED' end
        d=fresh
        if __slctx.ResetConfirm.ready(d.button,d.root) then break end
        if __slctx.now()>=deadline then __slctx.pause('NOTICE_NOT_READY','Кнопка Nice не разблокировалась. F7 — журнал.');return false,'NOTICE_NOT_READY' end
        if not __slctx.sleep(__slctx.CONFIG.ConfirmPollSeconds) then return false,'PAUSED' end
    end
    if not __slctx.live() then return false,'PAUSED' end
    if not __slctx.visible(alert) then return true end
    local ok,err=__slctx.Driver.navigate(d.button,function() return not __slctx.visible(alert) end,
        {once=true,guard=function()
            local fresh=__slctx.ResetConfirm.staircaseNotice()
            return fresh and fresh.button==d.button and fresh.fingerprint==d.fingerprint
                and __slctx.ResetConfirm.ready(fresh.button,fresh.root)
        end})
    if not ok then
        if __slctx.live() then __slctx.pause('NOTICE_CLOSE_FAILED',tostring(err)) end
        return false
    end
    __slctx.log('NOTICE_DISMISSED','Staircase permanence notice; re-read game state, no purchase inferred')
    local hide=tonumber(__slctx.attr(alert,'HideTime')) or 0.4
    return __slctx.sleep(math.min(3,math.max(0.5,hide+0.15)))
end

function __slctx.ResetConfirm.beforeNavigation(waitForLateNotice)
    if __slctx.S.resetSession or __slctx.S.resetChildPending or __slctx.S.actionPending then return false,'PREVIOUS_CALLBACK_PENDING' end
    local settling=waitForLateNotice or __slctx.visible(__slctx.g('Important/Alert'))
    local deadline=__slctx.now()+(settling and math.min(__slctx.CONFIG.ActionTimeout,1.5) or 0)
    repeat
        if not __slctx.live() then return false,'PAUSED' end
        local notice=__slctx.ResetConfirm.staircaseNotice()
        if notice then
            local closed,why=__slctx.ResetConfirm.dismissNotice(notice)
            return closed,why or (closed and 'NOTICE_DISMISSED' or 'NOTICE_CLOSE_FAILED')
        end
        if __slctx.now()>=deadline then break end
        if not __slctx.sleep(math.min(.05,deadline-__slctx.now())) then return false,'PAUSED' end
    until false
    if __slctx.visible(__slctx.g('Important/Alert')) then return false,'UNRECOGNIZED_DIALOG_BLOCKS_NAVIGATION' end
    return true
end

function __slctx.ResetConfirm.matchDialog(kind,button,root,expected)
    local d,why=__slctx.ResetConfirm.describe(root);if not d then return nil,why end
    if d.context=='' then return nil,'DIALOG_CONTEXT_MISSING' end
    local text=__slctx.ResetConfirm.normalize(d.context)
    local heading=__slctx.ResetConfirm.normalize(d.header)
    local _,label,buttonKind=__slctx.ResetConfirm.buttonRole(button)
    -- Reject purchase/wipe dialogs without rejecting ordinary reset warnings such as
    -- "your purchases will reset" / "+1 forever purchase".
    local path=__slctx.ResetConfirm.path(root):lower()
    if d.paid or path:find('marketplace',1,true) or (__slctx.confirmKinds[kind] and path:find('purchaseprompt',1,true))
        or path:find('robloxplus',1,true) then return nil,'PAID_DIALOG' end
    local restrictedText,restrictedAll=text,d.text:lower()
    if __slctx.confirmKinds[kind] and buttonKind==kind and root==__slctx.g('Important/Alert/Main')
        and __slctx.ancestorOf(button,__slctx.at(root,'Buttons')) then
        -- Live Evolve/Ascend warnings describe retention of prior purchases.
        -- Strip only observed preservation wording inside ordinary reset controls.
        -- Paid assets and any remaining currency/purchase text still reject.
        local function withoutPreservationNotice(value)
            local result=value:lower():gsub('%(robux purchases are safe%.%)','',1)
            if kind=='halo' then
                result=result:gsub('all progress will be reset,%s+except for robux purchases%.',
                    'all progress will be reset.',1)
            end
            return result
        end
        restrictedText=__slctx.ResetConfirm.normalize(withoutPreservationNotice(d.context))
        restrictedAll=withoutPreservationNotice(d.text)
    end
    for _,term in ipairs({'robux','r$','game pass','gamepass',
        'subscription','subscribe','roblox plus','reset data','delete data','wipe data','erase data',
        'delete save','wipe save','erase save','удалить данные','стереть данные','сброс данных',
        'очистить данные','удалить сохранение','delete all progress','erase all progress',
        'inversion','invert'}) do
        if restrictedText:find(term,1,true) or restrictedAll:find(term,1,true) then return nil,'UNRELATED_OR_PAID_DIALOG' end
    end
    if __slctx.confirmKinds[kind] then
        for _,term in ipairs({'buy now','purchase for','buy for'}) do
            if text:find(term,1,true) then return nil,'UNRELATED_OR_PAID_DIALOG' end
        end
    else
        return __slctx.ResetConfirm.matchPurchase(kind,button,d,expected)
    end
    if buttonKind and buttonKind~=kind then return nil,'OTHER_RESET_BUTTON' end
    local headerKind,headerError=__slctx.ResetConfirm.operation(heading)
    if headerKind and headerKind~=kind then return nil,'OTHER_RESET_HEADER' end
    local bodyKind,bodyError=__slctx.ResetConfirm.operation(text)
    local cue=false
    for _,term in ipairs({'are you sure','are you certain','confirm','confirmation','proceed',
        'continue','this will','подтвер','уверен','уверены','продолжить'}) do
        if text:find(term,1,true) or heading:find(term,1,true) then cue=true end
    end
    local named=tostring(root.Name):lower()
    local dialogName=named:find('confirm',1,true) or named:find('dialog',1,true) or named:find('prompt',1,true)
        or named:find('modal',1,true) or named:find('popup',1,true) or named=='alert'
    local pair=#d.negatives>0
    local explicit=buttonKind==kind or headerKind==kind or (not headerError and bodyKind==kind)
    local generic=not buttonKind and not headerKind and not headerError and not bodyKind and not bodyError and cue and pair
    if generic then
        for _,term in ipairs({'buy','purchase','trade','sell','delete','erase','wipe','leave','donate','gift','send',
            'купить','покупка','продать','удалить','стереть','обмен','подарить','отправить','выйти'}) do
            if __slctx.word(text,term) then generic=false;break end
        end
    end
    if not (explicit and (cue or pair or dialogName) or generic) then return nil,'RESET_CONTEXT_NOT_CLEAR' end
    if #d.positives~=1 or d.positives[1]~=button then return nil,'AMBIGUOUS_DIALOG_BUTTONS' end
    d.button=button;d.label=label
    d.fingerprint=kind..'|'..__slctx.ResetConfirm.path(root)..'|'..heading..'|'..text..'|'..label
    d.evidence=explicit and 'matching reset text' or 'new generic confirmation + cancel'
    return d
end
function __slctx.ResetConfirm.matchPurchase(kind,button,d,expected)
    if not __slctx.purchaseKinds[kind] or not expected then return nil,'PURCHASE_CONTEXT_MISSING' end
    local text=__slctx.ResetConfirm.normalize(d.context);local heading=__slctx.ResetConfirm.normalize(d.header)
    local _,label,buttonKind=__slctx.ResetConfirm.buttonRole(button)
    local headerKind=__slctx.ResetConfirm.operation(heading)
    if buttonKind or headerKind then return nil,'OTHER_PURCHASE_CONTEXT' end
    for _,term in ipairs({'trade','sell','gift','donate','delete','wipe','leave','teleport',
        'обмен','продать','подарить','удалить','стереть','выйти'}) do
        if __slctx.word(text,term) then return nil,'OTHER_PURCHASE_CONTEXT' end
    end
    local hasInvestors=text:find('investor',1,true) or text:find('инвестор',1,true)
    local hasCash=d.context:find('$',1,true) or __slctx.word(text,'cash') or __slctx.word(text,'деньги')
    if expected.currency=='cash' and hasInvestors and not hasCash then return nil,'WRONG_PURCHASE_CURRENCY' end
    if expected.currency=='investors' and hasCash and not hasInvestors then return nil,'WRONG_PURCHASE_CURRENCY' end
    if expected.price then
        for _,o in ipairs(d.root:GetDescendants()) do
            local n=tostring(o.Name):lower()
            if o:IsA('TextLabel') and __slctx.visible(o) and (n=='price' or n=='cost' or n=='purchaseprice') then
                local shown=__slctx.BN.parse(__slctx.txt(o))
                if shown and __slctx.BN.cmp(shown,expected.price)~=0 then return nil,'OTHER_PURCHASE_CONTEXT' end
            end
        end
    end
    local names={expected.name or ''}
    for _,name in ipairs(expected.aliases or {}) do names[#names+1]=name end
    local nameMatch=false
    for _,name in ipairs(names) do
        local n=__slctx.ResetConfirm.normalize(name)
        if #n>=3 and __slctx.word(text,n) then nameMatch=true end
    end
    local cue=false
    for _,term in ipairs({'are you sure','are you certain','confirm','confirmation','this will',
        'подтвер','уверен','продолжить'}) do
        if text:find(term,1,true) then cue=true end
    end
    local generic=text=='are you sure' or text=='confirmation are you sure' or text=='are you sure confirmation'
        or text=='confirm are you sure' or text=='are you sure confirm' or text=='вы уверены'
    local economic=__slctx.word(text,'upgrade') or __slctx.word(text,'upgrades') or __slctx.word(text,'ability')
        or __slctx.word(text,'power') or __slctx.word(text,'buy') or __slctx.word(text,'purchase')
        or text:find('улучш',1,true) or text:find('купить',1,true)
    local priceMatch=expected.priceText and #expected.priceText>0
        and __slctx.word(text,__slctx.ResetConfirm.normalize(expected.priceText))
    local currencyMatch=expected.currency=='investors' and hasInvestors or expected.currency=='cash' and hasCash
    local simpleAction=text=='are you sure you want to upgrade' or text=='confirm upgrade'
        or text=='are you sure you want to buy this upgrade'
        or ((heading=='confirm upgrade' or heading=='confirm purchase' or heading=='upgrade confirmation')
            and text:find('are you sure',1,true) and #d.negatives>0)
    local scopedPower=(kind=='power' or kind=='tablet') and d.root==__slctx.g('Important/Alert/Main')
        and label=='upgrade' and hasInvestors and #d.negatives>0 and cue
        and expected.currency=='investors'
    local permitted=scopedPower or (nameMatch and (cue or economic or #d.negatives>0))
        or (generic and #d.negatives>0) or (simpleAction and #d.negatives>0)
        or (cue and economic and currencyMatch and priceMatch)
    if not permitted then return nil,'PURCHASE_CONTEXT_NOT_CLEAR' end
    if #d.positives~=1 or d.positives[1]~=button then return nil,'AMBIGUOUS_DIALOG_BUTTONS' end
    d.button=button;d.label=label
    d.fingerprint=kind..'|'..__slctx.ResetConfirm.path(d.root)..'|'..heading..'|'..text..'|'..label
    d.evidence=nameMatch and 'matching selected item' or 'new scoped economic confirmation'
    return d
end
function __slctx.ResetConfirm.inspect(kind,button,expected)
    local alert=__slctx.g('Important/Alert')
    if alert and __slctx.ancestorOf(button,alert) then
        -- Live Rebirth puts a separate premium 'FREE' offer in Main/Sale.
        -- Only Main/Buttons belongs to the ordinary investor reset transaction.
        local main=__slctx.at(alert,'Main')
        if main and __slctx.ancestorOf(button,__slctx.at(main,'Buttons')) then
            return __slctx.ResetConfirm.matchDialog(kind,button,main,expected)
        end
        return nil,'OUTSIDE_TRANSACTION_MAIN'
    end
    local root=__slctx.prop(button,'Parent');local reason='NO_DIALOG_CONTAINER';local fallback=nil
    for _=1,10 do
        if not root or root==__slctx.gui then break end
        -- Never treat an entire ordinary economic menu as a confirmation dialog.
        if root==__slctx.g(__slctx.paths.manage) or root==__slctx.g(__slctx.paths.investors) or root==__slctx.g(__slctx.paths.evolution)
            or root==__slctx.g(__slctx.paths.halo) or root==__slctx.g('HUD') then break end
        if root:IsA('GuiObject') or root:IsA('LayerCollector') then
            local d,why=__slctx.ResetConfirm.matchDialog(kind,button,root,expected)
            if d then
                fallback=d
                local n=tostring(root.Name):lower()
                -- A generic Body/Actions group must not hide a conflicting header
                -- or a paid currency icon on its actual dialog parent.
                if d.header~='' or n:find('dialog',1,true) or n:find('modal',1,true)
                    or n:find('popup',1,true) or n:find('confirm',1,true) or n=='prompt' or n=='alert' then return d end
            elseif why=='PAID_DIALOG' or why=='UNRELATED_OR_PAID_DIALOG'
                or why=='OTHER_RESET_BUTTON' or why=='OTHER_RESET_HEADER'
                or why=='OTHER_PURCHASE_CONTEXT' or why=='WRONG_PURCHASE_CURRENCY' then return nil,why end
            reason=why or reason
        end
        root=__slctx.prop(root,'Parent')
    end
    return fallback,reason
end
function __slctx.ResetConfirm.begin(kind,origin,expected)
    if not __slctx.confirmKinds[kind] and not __slctx.purchaseKinds[kind] then return nil,'UNKNOWN_RESET_KIND' end
    if __slctx.S.resetSession or __slctx.S.resetChildPending then return nil,'PREVIOUS_RESET_PENDING' end
    local dialogScope=__slctx.g('Important/Alert')
    local buttons,complete,modals=__slctx.ResetConfirm.buttons(dialogScope)
    if not complete then return nil,'CONFIRM_SCAN_LIMIT' end
    if __slctx.visible(__slctx.g('Important/Alert')) then return nil,'PREEXISTING_DIALOG' end
    local session={kind=kind,origin=origin,epoch=__slctx.S.epoch,started=__slctx.now(),baseline={},sent=false,
        active=true,stages=0,clicked={},notes={},pending=nil,lastPoll=-math.huge,
        expected=expected,isReset=__slctx.confirmKinds[kind]==true,attempts=0,states={},sawDialog=false,dialogScope=dialogScope}
    session.baselineModals={}
    for _,m in ipairs(modals or {}) do session.baselineModals[m]=true end
    for _,b in ipairs(buttons) do session.baseline[b]=true end
    __slctx.S.resetSession=session;__slctx.S.lastResetSession=session
    return session
end
function __slctx.ResetConfirm.valid(session)
    if not (session and session.active and session.sent and __slctx.S.resetSession==session and __slctx.live(session.epoch)) then return false end
    if session.isReset then
        return __slctx.S.resetEnabled and __slctx.CONFIG.AutoConfirmResets
            and __slctx.CONFIG[({rebirth='AutoRebirth',evolve='AutoEvolution',halo='AutoHalo'})[session.kind]]==true
    end
    return __slctx.CONFIG.AutoConfirmPurchases and (session.kind~='power' or __slctx.CONFIG.AutoInvestorPowers)
end
function __slctx.ResetConfirm.note(session,code,message)
    local entry=code..' | '..tostring(message or '')
    if session.lastNote==entry then return end
    session.lastNote=entry;session.notes[#session.notes+1]=entry
    if #session.notes>40 then table.remove(session.notes,1) end
    __slctx.log(code,message)
end
function __slctx.ResetConfirm.scan(session,force)
    if not session then return {},false end
    if not force and session.scanCache and __slctx.now()-(session.scanAt or 0)<__slctx.CONFIG.ConfirmScanSeconds then
        return session.scanCache.matches,session.scanCache.blocked,session.scanCache.error
    end
    local notice=__slctx.ResetConfirm.staircaseNotice()
    if notice and not session.baseline[notice.button] then
        session.scanAt=__slctx.now();session.scanCache={matches={notice},blocked=true}
        return {notice},true
    end
    local buttons,complete,modals=__slctx.ResetConfirm.buttons(session.dialogScope);local matches,seen={},{}
    local blocked=false
    if not complete then return {},true,'CONFIRM_SCAN_LIMIT' end
    for _,root in ipairs(modals or {}) do
        if not (session.baselineModals or {})[root] then blocked=true end
    end
    for _,button in ipairs(buttons) do
        if button~=session.origin and not session.baseline[button] then
            local role=__slctx.ResetConfirm.buttonRole(button)
            if role=='positive' then
                local d,why=__slctx.ResetConfirm.inspect(session.kind,button,session.expected)
                if d then
                    blocked=true
                    if not seen[button] then matches[#matches+1]=d;seen[button]=true end
                else
                    local key=__slctx.ResetConfirm.path(button)..' | '..tostring(why)
                    session.rejected=session.rejected or {}
                    if not session.rejected[key] then
                        session.rejected[key]=true
                        __slctx.ResetConfirm.note(session,'RESET_DIALOG_NOT_MATCHED',key)
                    end
                end
            end
        end
    end
    session.scanAt=__slctx.now();session.scanCache={matches=matches,blocked=blocked}
    return matches,blocked
end
function __slctx.ResetConfirm.weakRebirth(d)
    return d and not d.notice and __slctx.ResetConfirm.normalize(d.context):find('that s not very much',1,true)~=nil
end
function __slctx.ResetConfirm.cancelReset(session,d,reason)
    -- Only the matching rebirth/evolution dialog's negative button may be used.
    -- Notices and unrelated purchase/ascension dialogs remain excluded.
    session.cancelReason=session.cancelReason or reason
    session.cancelDialog=session.cancelDialog or d
    d=session.cancelDialog
    local c=session.cancellation
    if not c then
        c={attempts=0,lastAt=-math.huge,started=__slctx.now()};session.cancellation=c
        __slctx.ResetConfirm.note(session,session.kind=='evolve' and 'EVOLUTION_REJECTED' or 'REBIRTH_REJECTED',session.cancelReason..' | '..d.text)
    end
    if not __slctx.visible(d.root) then
        if c.sent then session.cancelledReason=session.cancelReason end
        return true
    end
    if __slctx.now()-c.started>__slctx.CONFIG.ActionTimeout then
        __slctx.pause(session.kind=='evolve' and 'EVOLUTION_CANCEL_UNRESOLVED' or 'REBIRTH_CANCEL_UNRESOLVED','Сброс не подтверждён; кнопка отмены не закрыла окно.');return true
    end
    if c.attempts>=3 or __slctx.now()-c.lastAt<__slctx.CONFIG.ConfirmRetrySeconds then return true end
    local negative=d.negatives and #d.negatives==1 and d.negatives[1]
    if not negative or not __slctx.ResetConfirm.ready(negative,d.root) then return true end
    local function guard()
        if not __slctx.ResetConfirm.valid(session) or (session.kind~='rebirth' and session.kind~='evolve') or not __slctx.visible(d.root)
            or __slctx.ResetConfirm.buttonRole(negative)~='negative' or not __slctx.ResetConfirm.ready(negative,d.root) then return false end
        local fresh=__slctx.ResetConfirm.inspect(session.kind,d.button,session.expected)
        return fresh and fresh.root==d.root and #fresh.negatives==1 and fresh.negatives[1]==negative
    end
    if not guard() then return true end
    local modes=__slctx.candidateModes(negative,'navigation');if not modes[1] then return true end
    c.attempts=c.attempts+1;c.lastAt=__slctx.now()
    local p={done=false,started=__slctx.now()};session.pending=p;__slctx.S.resetChildPending=p
    p.thread=task.spawn(function()
        local ok,result,err=pcall(function() return __slctx.dispatch(negative,modes[((c.attempts-1)%#modes)+1],{guard=guard}) end)
        p.ok=ok and result~=false;p.error=not ok and result or err;p.done=true
        if p.ok then c.sent=true end
        if p.ok and not __slctx.visible(d.root) then session.cancelledReason=session.cancelReason end
        if __slctx.S.resetChildPending==p then __slctx.S.resetChildPending=nil end
    end)
    return true
end
function __slctx.ResetConfirm.hasChild() return __slctx.S.resetChildPending~=nil end
function __slctx.ResetConfirm.poll(session)
    if not session.active or __slctx.S.resetSession~=session or not session.sent then return false end
    -- BUY can update its quote before its callback resumes from the Nice notice.
    -- Still acknowledge that informational notice; never confirm a second purchase.
    if session.changed and session.changed() and not session.pending and not __slctx.ResetConfirm.staircaseNotice() then return false end
    if not __slctx.ResetConfirm.valid(session) then
        session.active=false
        if __slctx.live(session.epoch) then __slctx.pause('RESET_CONFIRM_CANCELED','Подтверждение остановлено: действие или автоподтверждение выключено.') end
        return true
    end
    if session.pending then
        local p=session.pending
        if not p.done then
            if __slctx.now()-(p.started or __slctx.now())>__slctx.CONFIG.ActionTimeout then
                if p.thread and type(task.cancel)=='function' then pcall(task.cancel,p.thread) end
                p.done=true;p.ok=false;p.error='CONFIRM_CALLBACK_TIMEOUT'
                if __slctx.S.resetChildPending==p then __slctx.S.resetChildPending=nil end
                session.error=p.error
                __slctx.pause('CONFIRM_CALLBACK_TIMEOUT','Обработчик подтверждения не завершился. Повтор неизвестной операции остановлен.')
            end
            return true
        end
        session.pending=nil
        if not p.ok then
            session.error=tostring(p.error or 'CONFIRM_DISPATCH_FAILED')
            __slctx.ResetConfirm.note(session,'CONFIRM_DISPATCH_RETRYABLE',session.kind..' | '..session.error)
        end
        -- p.ok means dispatch returned, NOT that the game accepted the confirmation.
    end
    if session.cancelReason then return __slctx.ResetConfirm.cancelReset(session,session.cancelDialog,session.cancelReason) end
    for _,state in pairs(session.states) do
        if state.attempts>0 and not __slctx.visible(state.root) then state.closed=true end
    end
    local matches,blocked,scanError=__slctx.ResetConfirm.scan(session)
    if scanError then session.error=scanError;return true end
    if #matches>1 then
        __slctx.ResetConfirm.note(session,'RESET_CONFIRM_AMBIGUOUS','Несколько новых диалогов; подтверждение не отправлено.')
        return true
    end
    if #matches==0 then session.candidate=nil;return blocked end
    local d=matches[1]
    session.sawDialog=true
    -- The deadline is created once, never extended anew for each retry or countdown tick.
    session.extraDeadline=session.extraDeadline or (__slctx.now()+__slctx.CONFIG.ConfirmWaitTimeout)
    -- Root/button identity retains retry budgets when countdown text changes.
    local key=d.root
    local state=session.states[key]
    if state and state.closed and state.fingerprint~=d.fingerprint then state=nil end
    if not state then
        state={button=d.button,root=d.root,firstSeen=__slctx.now(),attempts=0,lastAt=-math.huge,closed=false,fingerprint=d.fingerprint}
        session.states[key]=state
        __slctx.ResetConfirm.note(session,'RESET_DIALOG_FOUND',session.kind..' | '..__slctx.ResetConfirm.path(d.button)..' | '..d.text)
    elseif state.button~=d.button then
        -- Replacement button on the same dialog: keep attempt budget; require a new readiness window.
        state.button=d.button;state.root=d.root;state.readyAt=nil
    end
    session.candidate=d
    if session.kind=='rebirth' and not d.notice then
        if __slctx.ResetConfirm.weakRebirth(d) then
            return __slctx.ResetConfirm.cancelReset(session,d,'GAME_SAYS_REWARD_TOO_SMALL')
        end
    end
    if state.closed then
        __slctx.status('WAIT_CONFIRM_RESULT','Диалог уже исчезал после клика. Повтор не отправляю; жду результат '..session.kind..'.')
        return true
    end
    local ready,why=__slctx.ResetConfirm.ready(d.button,d.root)
    if not ready then
        state.readyAt=nil
        __slctx.status('WAIT_CONFIRM_TIMER','Подтверждение '..session.kind..': '..tostring(why)..'. Жду разблокировки.')
        return true
    end
    -- A countdown/disabled confirmation is a wait state, not a new economic veto.
    if (session.kind=='rebirth' or session.kind=='evolve') and not d.notice and session.expected and session.expected.authorize
        and not session.expected.authorize(d) then
        return __slctx.ResetConfirm.cancelReset(session,d,'RESET_ECONOMY_CHANGED_AT_CONFIRMATION')
    end
    state.readyAt=state.readyAt or __slctx.now()
    if __slctx.now()-state.firstSeen<__slctx.CONFIG.ConfirmInitialDelaySeconds
        or __slctx.now()-state.readyAt<__slctx.CONFIG.ConfirmReadyStableSeconds
        or __slctx.now()-state.readyAt<__slctx.CONFIG.ConfirmStableSeconds then return true end
    if state.attempts>=__slctx.CONFIG.ConfirmMaxAttempts then
        session.error='CONFIRM_ATTEMPTS_EXHAUSTED'
        __slctx.ResetConfirm.note(session,'CONFIRM_ATTEMPTS_EXHAUSTED',session.kind..' | '..__slctx.ResetConfirm.path(d.button))
        __slctx.status('WAIT_CONFIRM_RESULT','Лимит подтверждений исчерпан. Жду запоздалый результат; новых покупок не отправляю.')
        return true
    end
    if __slctx.now()-state.lastAt<__slctx.CONFIG.ConfirmRetrySeconds then return true end
    if state.attempts==0 and session.stages>=__slctx.CONFIG.ConfirmMaxStages then
        session.error='CONFIRM_STAGE_LIMIT';__slctx.pause('CONFIRM_STAGE_LIMIT','Слишком много разных этапов подтверждения.');return true
    end
    local modes=__slctx.candidateModes(d.button,'confirm_'..session.kind)
    if not modes[1] then session.error='NO_CONFIRM_INPUT_MODE';return true end
    local chosen=d.button;local fingerprint=d.fingerprint
    local mode=modes[(state.attempts % #modes)+1]
    local function guard()
        if not __slctx.ResetConfirm.valid(session) or state.closed or not __slctx.ResetConfirm.ready(chosen,d.root) then return false end
        -- A notice acknowledges a completed action. Its own disappearance
        -- is never used as the economic receipt, and spent cash is not reauthorized.
        if not d.notice and session.changed and session.changed() then return false end
        if not d.notice and session.expected and session.expected.authorize and not session.expected.authorize(d) then return false end
        local fresh
        if d.notice then fresh=__slctx.ResetConfirm.staircaseNotice()
        else fresh=__slctx.ResetConfirm.inspect(session.kind,chosen,session.expected) end
        return fresh~=nil and fresh.fingerprint==fingerprint
    end
    if not guard() then state.readyAt=nil;return true end
    if state.attempts==0 then session.stages=session.stages+1 end
    state.attempts=state.attempts+1;state.lastAt=__slctx.now();session.attempts=session.attempts+1
    session.clicked[chosen]=true -- reporting only; never used as permanent retry suppression.
    local p={done=false,ok=false,started=__slctx.now(),path=__slctx.ResetConfirm.path(chosen)}
    session.pending=p;__slctx.S.resetChildPending=p
    __slctx.ResetConfirm.note(session,'RESET_CONFIRM_CLICK',session.kind..' | stage='..session.stages
        ..' | attempt='..state.attempts..'/'..__slctx.CONFIG.ConfirmMaxAttempts..' | '..p.path)
    p.thread=task.spawn(function()
        local ok,result,err=pcall(function()
            if not guard() then return false,'CONFIRM_CONTEXT_CHANGED' end
            return __slctx.dispatch(chosen,mode,{guard=guard})
        end)
        p.ok=ok and result~=false;p.error=not ok and result or err;p.done=true;session.scanCache=nil
        state.lastAt=__slctx.now()
        if not __slctx.visible(state.root) then state.closed=true end
        if p.ok then __slctx.ResetConfirm.note(session,'RESET_CONFIRM_SENT',session.kind..' | attempt='..state.attempts..' | '..p.path) end
        if __slctx.S.resetChildPending==p then __slctx.S.resetChildPending=nil end
    end)
    return true
end
function __slctx.ResetConfirm.modalVisible(session)
    if session and session.pending and not session.pending.done then return true end
    local matches,blocked=__slctx.ResetConfirm.scan(session)
    return blocked or #matches>0
end
function __slctx.ResetConfirm.dump(session)
    local buttons=__slctx.ResetConfirm.buttons();local count=0
    __slctx.ResetConfirm.note(session,'RESET_CONFIRM_DIAGNOSTIC','Only local visible GUI; no scripts, chat or network data.')
    for _,b in ipairs(buttons) do
        if not session.baseline[b] then
            count=count+1
            if count>24 then break end
            local parent=__slctx.prop(b,'Parent');local d=parent and __slctx.ResetConfirm.describe(parent)
            local message=__slctx.ResetConfirm.path(b)..' | label='..__slctx.ResetConfirm.buttonLabel(b)
                ..' | active='..tostring(__slctx.prop(b,'Active'))..' | nearby='..tostring(d and d.text or ''):sub(1,600)
            __slctx.ResetConfirm.note(session,'RESET_VISIBLE_BUTTON',message)
        end
    end
    if count==0 then __slctx.ResetConfirm.note(session,'RESET_VISIBLE_BUTTON','No newly visible buttons were recorded.') end
end
function __slctx.ResetConfirm.finish(session,ok)
    session.active=false;session.outcome=ok and 'TRANSACTION_RECEIPT_CONFIRMED'
        or session.cancelledReason and 'TRANSACTION_CANCELLED' or 'TRANSACTION_NOT_CONFIRMED'
    if __slctx.S.resetSession==session then __slctx.S.resetSession=nil end
end
function __slctx.ResetConfirm.dismissStale()
    local notice=__slctx.ResetConfirm.staircaseNotice()
    if notice then return __slctx.ResetConfirm.dismissNotice(notice) end
    local alert=__slctx.g('Important/Alert');local main=__slctx.g('Important/Alert/Main')
    if not __slctx.visible(alert) or not __slctx.visible(main) then return true end
    if __slctx.S.resetSession or __slctx.S.resetChildPending or __slctx.S.actionPending then return false end
    -- Cancel a previous run's/manual dialog, then re-read all economic gates.
    local close=__slctx.at(main,'Close')
    if not __slctx.usable(close) then
        local controls=__slctx.at(main,'Buttons')
        for _,b in ipairs(controls and controls:GetChildren() or {}) do
            if b:IsA('GuiButton') and __slctx.usable(b) and __slctx.ResetConfirm.buttonRole(b)=='negative' then close=b;break end
        end
    end
    if not __slctx.usable(close) then __slctx.pause('STALE_DIALOG_BLOCKED','Не удалось найти отмену прежнего диалога.');return false end
    local ok,err=__slctx.Driver.navigate(close,function() return not __slctx.visible(alert) end,{once=true})
    if not ok then __slctx.pause('STALE_DIALOG_BLOCKED',tostring(err));return false end
    __slctx.log('STALE_DIALOG_CANCELLED','old transaction discarded; current game state will be read again')
    return true
end
function __slctx.ResetConfirm.restore(session)
    if not session.sawDialog or session.attempts==0 or __slctx.S.actionPending or __slctx.S.resetChildPending
        or __slctx.ResetConfirm.modalVisible(session) then return end
    if __slctx.now()-(session.lastRestore or -math.huge)<0.75 then return end
    local route=session.expected and session.expected.restore
    if not route then return end
    local opener
    if route=='buy' then
        if not __slctx.visible(__slctx.g(__slctx.paths.buy)) then opener=__slctx.g('HUD/Powers/Toggle') end
    elseif not __slctx.visible(__slctx.g(__slctx.paths.manage)) then opener=__slctx.g(__slctx.openers.manage)
    else
        local tab=route=='powers' and 'Powers' or 'Manage'
        if not __slctx.visible(__slctx.g('Manage/ManageMenu/Body/Frame/'..tab)) then opener=__slctx.g(__slctx.paths.tabs..tab) end
    end
    if not __slctx.usable(opener) then return end
    local modes=__slctx.candidateModes(opener,'navigation');if not modes[1] then return end
    session.lastRestore=__slctx.now()
    local p={done=false};__slctx.S.resetChildPending=p
    task.spawn(function()
        pcall(__slctx.dispatch,opener,modes[1],{guard=function()
            return __slctx.ResetConfirm.valid(session) and not __slctx.ResetConfirm.modalVisible(session)
        end})
        p.done=true;if __slctx.S.resetChildPending==p then __slctx.S.resetChildPending=nil end
    end)
end
function __slctx.ResetConfirm.perform(button,kind,proof,options,expected)
    options=options or {}
    if not __slctx.CONFIG.AutoConfirmPurchases then return __slctx.Driver.perform(button,kind,proof,options) end
    local session,why=__slctx.ResetConfirm.begin(kind,button,expected)
    if not session then return false,why end
    session.changed=proof
    local wrapped={}
    for k,v in pairs(options) do wrapped[k]=v end
    -- Keep the original action's selected backend. Once a modal has appeared, do not
    -- reissue that economic action while waiting for its confirmation.
    wrapped.once=true
    wrapped.onDispatch=function(...)
        session.sent=true
        if options.onDispatch then options.onDispatch(...) end
    end
    wrapped.extraDeadline=function() return session.extraDeadline end
    wrapped.maintenanceInterval=__slctx.CONFIG.ConfirmPollSeconds
    wrapped.maintenance=function()
        local modal=__slctx.ResetConfirm.poll(session)
        if __slctx.live(session.epoch) then modal=modal or __slctx.ResetConfirm.modalVisible(session) end
        if modal then
            session.observedModal=true
            session.extraDeadline=session.extraDeadline or (__slctx.now()+__slctx.CONFIG.ConfirmWaitTimeout)
        end
        if __slctx.live(session.epoch) and not modal then __slctx.ResetConfirm.restore(session) end
        if options.maintenance and __slctx.live(session.epoch) then options.maintenance() end
    end
    local ok,err=__slctx.Driver.perform(button,kind,function()
        return __slctx.S.resetChildPending==nil and proof()
    end,wrapped)
    local unresolved=not ok and (session.sawDialog or session.observedModal)
    if unresolved and __slctx.live() then __slctx.ResetConfirm.dump(session) end
    if ok and session.sawDialog and __slctx.live(session.epoch) then
        local alert=__slctx.g('Important/Alert')
        local hide=tonumber(__slctx.attr(alert,'HideTime')) or 0.4
        __slctx.sleep(math.min(3,math.max(0.5,hide+0.15)))
    end
    __slctx.ResetConfirm.finish(session,ok)
    if unresolved and __slctx.live() then
        -- A leftover or unknown-result modal is not a reason to buy the original item again.
        __slctx.pause('PURCHASE_CONFIRM_UNRESOLVED','Не завершено подтверждение '..kind..': '
            ..tostring(session.error or err)..'. Покупка повторно не отправлена; F7 — журнал.')
    end
    return ok,err
end
-- RESET_CONFIRMATION_END


end
