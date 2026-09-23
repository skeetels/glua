-- Private GitHub bootstrap. No token is saved, printed, or passed to the controller.
-- Enter a fine-grained token for skeetels/glua with Contents: read-only.
local send=request or http_request or (syn and syn.request)
assert(type(send)=='function' and type(loadstring)=='function','HTTP request / loadstring unavailable')
local gui=game:GetService('Players').LocalPlayer:WaitForChild('PlayerGui',15)
assert(gui,'PlayerGui unavailable')
if gui:FindFirstChild('SellLemonsPrivateLoader') then return end
local screen=Instance.new('ScreenGui');screen.Name='SellLemonsPrivateLoader';screen.ResetOnSpawn=false
local box=Instance.new('Frame');box.Size=UDim2.fromOffset(410,194);box.Position=UDim2.new(.5,-205,.5,-97)
box.BackgroundColor3=Color3.fromRGB(21,25,26);box.BorderSizePixel=0;box.Parent=screen
local corner=Instance.new('UICorner');corner.CornerRadius=UDim.new(0,12);corner.Parent=box
local title=Instance.new('TextLabel');title.BackgroundTransparency=1;title.Size=UDim2.new(1,-32,0,50)
title.Position=UDim2.fromOffset(16,12);title.Font=Enum.Font.GothamMedium;title.TextSize=14
title.TextColor3=Color3.fromRGB(220,238,143);title.Text='SELL LEMONS / PRIVATE GITHUB\nТокен: glua · Contents read-only';title.Parent=box
local input=Instance.new('TextBox');input.Size=UDim2.new(1,-32,0,36);input.Position=UDim2.fromOffset(16,72)
input.BackgroundColor3=Color3.fromRGB(38,43,45);input.Text='';input.TextTransparency=1
input.ClearTextOnFocus=false;input.MultiLine=false;input.Parent=box
local mask=Instance.new('TextLabel');mask.Size=input.Size;mask.Position=input.Position;mask.BackgroundTransparency=1
mask.Font=Enum.Font.Gotham;mask.TextSize=12;mask.TextColor3=Color3.fromRGB(190,200,195)
mask.Text='Вставьте токен сюда';mask.Active=false;mask.Parent=box
local load=Instance.new('TextButton');load.Size=UDim2.fromOffset(288,32);load.Position=UDim2.fromOffset(16,124)
load.Text='Загрузить';load.Font=Enum.Font.Gotham;load.TextSize=13
load.BackgroundColor3=Color3.fromRGB(220,238,143);load.Parent=box
local close=Instance.new('TextButton');close.Size=UDim2.fromOffset(74,32);close.Position=UDim2.fromOffset(320,124)
close.Text='Отмена';close.Parent=box
local hint=Instance.new('TextLabel');hint.BackgroundTransparency=1;hint.Size=UDim2.new(1,-20,0,24)
hint.Position=UDim2.fromOffset(10,162);hint.Text='Токен используется только для api.github.com';hint.TextSize=11
hint.TextColor3=Color3.fromRGB(170,181,174);hint.Parent=box
local active=true;local busy=false;local generation=0;local connections={}
local function destroy()
    active=false;generation=generation+1;input.Text=''
    for _,c in ipairs(connections) do c:Disconnect() end
    screen:Destroy()
end
connections[#connections+1]=input:GetPropertyChangedSignal('Text'):Connect(function()
    mask.Text=#input.Text>0 and ('Токен введён ('..#input.Text..' символов)') or 'Вставьте токен сюда'
end)
connections[#connections+1]=close.Activated:Connect(destroy)
connections[#connections+1]=load.Activated:Connect(function()
    if busy or not active then return end
    local token=input.Text:match('^%s*(.-)%s*$');input.Text=''
    if #token<20 or token:find('[%s\r\n]') then hint.Text='Введите действующий GitHub token';return end
    busy=true;generation=generation+1;local ticket=generation
    hint.Text='Загрузка…';load.Text='Подождите'
    task.delay(35,function()
        if active and generation==ticket and busy then
            generation=generation+1;busy=false;load.Text='Загрузить';hint.Text='Тайм-аут. Повторите ввод токена.'
        end
    end)
    local options={Url='https://api.github.com/repos/skeetels/glua/contents/sell-lemons-controller/dist/controller.lua?ref=main',
        Method='GET',Timeout=25,Headers={Authorization='Bearer '..token,
            Accept='application/vnd.github.raw+json',['X-GitHub-Api-Version']='2022-11-28'}}
    token=nil
    local ok,response=pcall(send,options);options.Headers.Authorization=nil;options=nil
    if not active or generation~=ticket then return end
    busy=false;load.Text='Загрузить'
    if not ok then hint.Text='Ошибка HTTP. Проверьте сеть и поддержку request.';return end
    local code=tonumber(response.StatusCode or response.Status)
    if code~=200 then hint.Text='GitHub HTTP '..tostring(code)..': проверьте токен, доступ и срок действия.';return end
    local body=response.Body;response=nil
    if type(body)~='string' or #body>2*1024*1024 or body:find('-- Sell Lemons Controller ',1,true)~=1 then
        hint.Text='Ответ не является сборкой контроллера';return
    end
    local chunk=loadstring(body,'SellLemonsController');body=nil
    if not chunk then hint.Text='Ошибка компиляции. Обновите сборку.';return end
    destroy()
    local started,err=pcall(chunk)
    if not started then warn('[Sell Lemons] Controller startup failed: '..tostring(err)) end
end)
screen.Parent=gui
