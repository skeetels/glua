return function(loader)
    local function run(options)
        local sends,starts=0,0
        local function send(request)
            sends=sends+1
            assert(request.Method=='GET' and request.Url=='https://raw.githubusercontent.com/skeetels/glua/main/sell-lemons-controller/dist/controller.lua')
            assert(request.Headers==nil,'public loader must not attach credentials')
            if options.httpError then error('request failed')end
            if options.missingBody then return {StatusCode=200}end
            return {StatusCode=options.status or 200,Body='-- fixture source'}
        end
        local env=setmetatable({game={HttpGet=function()error('broken HttpGet must never be called')end},
            request=options.fallback and {} or send,http_request=send,
            loadstring=function(source)
                assert(source=='-- fixture source')
                if options.compileError then return nil,'bad source' end
                return function()starts=starts+1;if options.runError then error('startup failed')end end
            end}, {__index=getfenv()})
        setfenv(loader,env);local ok=pcall(loader)
        assert(sends==1)
        local downloaded=not options.httpError and not options.missingBody and (options.status or 200)==200
        assert(ok==(downloaded and not options.compileError and not options.runError))
        assert(starts==((downloaded and not options.compileError) and 1 or 0))
    end
    run({});run({fallback=true});run({status=404});run({compileError=true});run({httpError=true});run({missingBody=true});run({runError=true})
    print('PASS 7 public request-loader cases including broken HttpGet and staged download/compile/runtime failures')
end
