return function(loaderFactory,makeMock)
    local passed=0
    local function run(status,cancel)
        local m=makeMock();local requests=0;local compilations=0;local starts=0
        local capturedOptions
        m.env.request=function(options)
            requests=requests+1;capturedOptions=options
            assert(options.Url=='https://api.github.com/repos/skeetels/glua/contents/sell-lemons-controller/dist/controller.lua?ref=main')
            assert(options.Headers.Authorization=='Bearer github_pat_TEST_ONLY_NOT_A_REAL_TOKEN')
            if cancel then
                for _,o in ipairs(m.gui:GetDescendants()) do if o.Text=='Отмена' then o.Activated:Fire() end end
            end
            return {StatusCode=status,Body='-- Sell Lemons Controller 4.0\nreturn true'}
        end
        m.env.loadstring=function(body)
            compilations=compilations+1
            assert(body:find('github_pat_',1,true)==nil)
            return function()starts=starts+1 end
        end
        setfenv(loaderFactory,m.env);loaderFactory()
        local input,button
        for _,o in ipairs(m.gui:GetDescendants()) do
            if o.ClassName=='TextBox' then input=o elseif o.Text=='Загрузить' then button=o end
        end
        assert(input and button and input.TextTransparency==1)
        input.Text='github_pat_TEST_ONLY_NOT_A_REAL_TOKEN';button.Activated:Fire()
        assert(requests==1 and input.Text=='')
        assert(capturedOptions.Headers.Authorization==nil,'authorization retained after request')
        assert(next(m.globals)==nil,'token leaked into globals')
        if status==200 and not cancel then assert(compilations==1 and starts==1)
        else assert(compilations==0 and starts==0) end
        passed=passed+1
    end
    run(200,false);run(401,false);run(404,false);run(200,true)
    print('PASS '..passed..' loader HTTP / cancellation fixtures')
end
