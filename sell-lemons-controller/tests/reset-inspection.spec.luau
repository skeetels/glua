local function fixture(supported)
    local mock=require('./mock-engine')();local c={S={},env=mock.globals,player=mock.player}
    local function node(class,name,parent)
        local o=mock.env.Instance.new(class);o.Name=name;if parent then o.Parent=parent end;return o
    end
    local world=node('Folder','Workspace');mock.services.Workspace=world
    local root=node('Folder','Tycoon9',world);local owner=node('ObjectValue','Owner',root);owner.Value=mock.player
    local values=node('Folder','Values',node('Folder','Values',root))
    values.GetAttribute=function(_,key)return ({Evolution=1,Ascension=27})[key]end
    local remotes=node('Folder','Remotes',root)
    for _,name in ipairs({'Evolve','Evolved','Ascend','Ascended'})do
        local o=node('RemoteFunction',name,remotes)
        o.InvokeServer=function()error('scanner invoked a remote')end
    end
    local rs=node('Folder','ReplicatedStorage');mock.services.ReplicatedStorage=rs
    for _,path in ipairs({'Modules.UI.Layers.Rebirth.UIEvolutionMenu','Modules.UI.Layers.Rebirth.UIAscensionMenu',
        'Modules.Tycoon.Component.Client.ClientTycoonEvolution','Modules.Tycoon.Component.Client.ClientTycoonAscension',
        'Modules.Tycoon.Component.TycoonEvolution','Modules.Tycoon.Component.TycoonAscension',
        'Modules.UI.Layers.Important.UIAlert','Core.RemoteRequest'})do
        local parent=rs;local parts=path:split('.')
        for i,name in ipairs(parts)do parent=parent:FindFirstChild(name) or node(i==#parts and 'ModuleScript' or 'Folder',name,parent)end
    end
    -- Real report hit the old 12000-node limit before visiting Modules.
    local models=node('Folder','Models',rs)
    for i=1,12005 do node('Folder','Asset'..i,models)end
    local reads=0
    if supported then mock.globals.getscriptbytecode=function(o)reads=reads+1;return '\12\0'..o.Name..'\255' end end
    c.ResetConfirm={buttonLabel=function(o)return o.Name end,cancelButton=function(d)return d.negatives[1]end}
    c.visible=function()return true end;c.prop=function(o,key)return o[key]end;c.attr=function()return nil end
    local initialize=require('../src/runtime/ResetInspection');setfenv(initialize,mock.env);initialize(c)
    return c,mock,node,rs,function()return reads end,initialize
end
do
    local c,m,node,rs,reads,initialize=fixture(true)
    local origin=node('TextButton','Evolve');local yes=node('TextButton','Option1');local no=node('TextButton','Option2')
    local d={button=yes,negatives={no},text='Evolve! | nvm',fingerprint='evolve:fixture'}
    local session={kind='evolve'}
    c.ResetInspection.origin('evolve',origin);c.ResetInspection.dialog(session,d);c.ResetInspection.finish(session,true)
    local initialCount=#c.S.resetScans.rows.evolve.lines
    for i=1,5 do c.ResetInspection.origin('evolve',origin);c.ResetInspection.dialog(session,d);c.ResetInspection.finish(session,true)end
    assert(#c.S.resetScans.rows.evolve.lines==initialCount,'repeated cycles must not duplicate the capture')
    -- Run only source jobs, then their timeout checks; no game worker is involved.
    m.tasks[1]();m.tasks[2]();assert(reads()==5)
    session={kind='halo'};d.text='Ascend! | nvm';d.fingerprint='halo:fixture'
    c.ResetInspection.origin('halo',origin);c.ResetInspection.dialog(session,d);c.ResetInspection.finish(session,false)
    m.tasks[3]();m.tasks[4]();assert(reads()==8,'shared UIAlert/RemoteRequest are read once')
    local report=c.ResetInspection.report()
    assert(report:find('evolve CONFIRMATION',1,true) and report:find('halo CONFIRMATION',1,true))
    assert(report:find('[SL BC] BEGIN',1,true) and report:find('[SL BC] END',1,true))
    assert(not report:find('Unrelated',1,true))
    c.S.logs={};c.S.route={};assert(c.ResetInspection.report()==report,'farm log trimming/reset must preserve captures')
    local replacement={S={},env=c.env,player=c.player,previousCycleState={resetScans=c.S.resetScans}}
    initialize(replacement);assert(replacement.ResetInspection.report()==report,'same-client reload retains completed scans')
end
print('PASS one Evolution and one Halo capture; shared bounded bytecode; journal survives log rotation, reset and reload')
do
    local c,m,node=fixture(false)
    c.ResetInspection.origin('evolve',node('TextButton','Evolve'))
    assert(c.ResetInspection.report():find('BYTECODE_UNAVAILABLE',1,true) and #m.tasks==0)
    c.ResetInspection.origin('rebirth',node('TextButton','Rebirth'));assert(c.S.resetScans.rows.rebirth==nil)
    local c2,m2,node2=fixture(true);c2.ResetInspection.origin('halo',node2('TextButton','Ascend'))
    m2.tasks[2]();assert(c2.S.resetScans.rows.halo.sourceStatus=='timeout')
    m2.tasks[1]();assert(c2.S.resetScans.rows.halo.sourceStatus=='timeout','late diagnostic callback cannot overwrite timeout')
    assert(c2.S.running==nil and c2.S.epoch==nil,'diagnostic failure cannot change controller lifecycle')
end
print('PASS missing bytecode API and stalled source scan are reported without affecting farm actions')
do
    local c,m,node,rs,reads,initialize=fixture(true)
    local folder=rs:FindFirstChild('Modules'):FindFirstChild('UI'):FindFirstChild('Layers'):FindFirstChild('Rebirth')
    for i,o in ipairs(folder.children)do if o.Name=='UIEvolutionMenu'then table.remove(folder.children,i);break end end
    c.ResetInspection.origin('evolve',node('TextButton','Evolve'));m.tasks[1]();m.tasks[2]()
    assert(c.S.resetScans.rows.evolve.sourceStatus=='partial' and reads()==4)
    local row=c.S.resetScans.rows.evolve
    row.sourceStatus='complete';row.sourceRevision=nil -- 4.0.11 falsely reported zero matches as complete.
    local replacement={S={},env=c.env,player=c.player,previousCycleState={resetScans=c.S.resetScans}}
    initialize(replacement);m.tasks[3]();m.tasks[4]()
    assert(row.stages.origin and row.sourceStatus=='partial' and reads()==4,'migration retains GUI stages and deduplicates complete sources')
    assert(replacement.ResetInspection.report():find('MODULE_MISSING',1,true))
end
print('PASS targeted module capture bypasses asset traversal; missing modules stay partial and v1 false-complete scans retry')
do
    local c,m,node,rs,reads=fixture(true)
    local session={}
    c.ResetInspection.direct('evolve','sent',session)
    c.ResetInspection.direct('evolve','receipt',{})
    assert(not c.S.resetScans.rows.evolve.stages['direct-receipt'],'a different reset cannot supply the first capture outcome')
    c.ResetInspection.direct('evolve','receipt',session)
    c.ResetInspection.direct('evolve','sent',{});c.ResetInspection.direct('evolve','receipt',{})
    m.tasks[1]();m.tasks[2]()
    local report=c.ResetInspection.report()
    assert(reads()==5 and c.S.resetScans.rows.evolve.sourceStatus=='complete')
    assert(not c.S.resetScans.rows.evolve.stages.confirmation,'direct transport cannot claim a GUI confirmation')
    local _,sent=report:gsub('DIRECT sent','');local _,receipt=report:gsub('DIRECT receipt','')
    assert(sent==1 and receipt==1)
end
print('PASS direct reset observations and source capture run once without inventing button confirmation')
