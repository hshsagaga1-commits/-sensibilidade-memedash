-- MemeDash | Macro Emote 1 Clique | v1 (iPhone)
-- X12 identificou:
-- 1) PlayerGui/Mobile/Emote [TextButton]
-- 2) PlayerGui/EmotesGui/MainGui/Sector6/ViewportFrame/button [TextButton]
-- Atalho com um toque: abre o menu e escolhe o setor configurado (6 padrao).
-- NAO usa posicoes fixas; procura a UI atual por caminho.
-- NAO escreve remotes do jogo, nao altera CFrame, controles ou camera.
-- Necessita eventos do executor (firesignal) OU clique virtual permitido.
-- Roblox NAO expoe metodo publico GuiButton:Activate().

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local player = Players.LocalPlayer
assert(player, "Execute no cliente Roblox.")
assert(game.PlaceId == 134001816760598, "Este macro e apenas para MemeDash.")
local pg=player:WaitForChild("PlayerGui")
local ENV=(type(getgenv)=="function" and getgenv()) or _G
if type(ENV.__MemeDashEmoteMacroCleanup)=="function" then
    pcall(ENV.__MemeDashEmoteMacroCleanup)
end
local previous=pg:FindFirstChild("MemeDashEmoteMacro")
if previous then previous:Destroy() end

local BUILD="EmoteMacro-1.0-Sector6-X12"
local running,alive=false,true
local sector=6
local lastClick=0
local clicks,successes,failures=0,0,0
local connections={}
local gui, panel, mainButton, sectorLabel, statusLabel

local function connect(signal,fn)
    local c=signal:Connect(fn)
    connections[#connections+1]=c
    return c
end
local function setStatus(t)
    if statusLabel and statusLabel.Parent then
        statusLabel.Text=t
    end
    print("[MemeDash Macro] "..t)
end
local function findOpenButton()
    local mobile=pg:FindFirstChild("Mobile")
    local button=mobile and mobile:FindFirstChild("Emote")
    if button and button:IsA("GuiButton") then return button end
end
local function findSectorButton(n)
    local emotes=pg:FindFirstChild("EmotesGui")
    local main=emotes and emotes:FindFirstChild("MainGui")
    local frame=main and main:FindFirstChild("Sector"..tostring(n))
    local viewport=frame and frame:FindFirstChild("ViewportFrame")
    local button=viewport and viewport:FindFirstChild("button")
    if button and button:IsA("GuiButton") then return button end
end
local function isVisibleOnScreen(button)
    if not button or not button.Parent then return false end
    local obj=button
    local screenGui=nil
    while obj and obj~=pg do
        if obj:IsA("GuiObject") and not obj.Visible then return false end
        if obj:IsA("ScreenGui") then screenGui=obj;break end
        obj=obj.Parent
    end
    if not screenGui or not screenGui.Enabled then return false end
    local pos,size=button.AbsolutePosition,button.AbsoluteSize
    local cam=Workspace.CurrentCamera
    local view=cam and cam.ViewportSize or Vector2.new(724,375)
    return size.X>1 and size.Y>1
        and pos.X<view.X and pos.X+size.X>0
        and pos.Y<view.Y and pos.Y+size.Y>0
end
local function buttonCenter(btn)
    return btn.AbsolutePosition+btn.AbsoluteSize*.5
end
local function activeConnections(signal)
    if type(getconnections)~="function" then return nil end
    local ok,list=pcall(getconnections,signal)
    if not ok or type(list)~="table" then return nil end
    local count=0
    for _,conn in ipairs(list) do
        local okEnabled,enabled=pcall(function() return conn.Enabled end)
        if not okEnabled or enabled~=false then count=count+1 end
    end
    return count
end
local function emitSignal(btn, name)
    if type(firesignal)~="function" then return false, "firesignal indisponivel" end
    local okSignal,signal=pcall(function() return btn[name] end)
    if not okSignal then return false,"evento "..name.." indisponivel" end
    local ok,err
    if name=="Activated" then
        -- Some scripts ignore these arguments; callbacks that REQUIRE a
        -- real InputObject may not work with firesignal.
        ok,err=pcall(firesignal,signal,nil,0)
    else
        ok,err=pcall(firesignal,signal)
    end
    if ok then return true,"firesignal:"..name end
    return false,"firesignal:"..name.." "..tostring(err)
end
local function virtualClick(btn)
    if not isVisibleOnScreen(btn) then
        return false,"botao nao visivel para clique virtual"
    end
    local pos=buttonCenter(btn)
    local x,y=math.floor(pos.X+.5),math.floor(pos.Y+.5)
    -- The legacy VIM service is not normally accessible to a standard
    -- LocalScript. Some executors allow it; others will reject it.
    local serviceOK,service=pcall(function()
        return game:GetService("VirtualInputManager")
    end)
    if serviceOK and service then
        local down=pcall(function()
            service:SendMouseButtonEvent(x,y,0,true,game,0)
        end)
        if down then
            task.wait(.055)
            local up=pcall(function()
                service:SendMouseButtonEvent(x,y,0,false,game,0)
            end)
            if up then return true,"VirtualInputManager" end
            return false,"clique virtual DOWN sem UP (bloqueado)"
        end
    end
    -- Older local virtual-user service: blocked or unreliable on many iOS
    -- builds; leave this as a best-effort alternative, not a guarantee.
    local vuOK,vu=pcall(function() return game:GetService("VirtualUser") end)
    if vuOK and vu then
        local cf=Workspace.CurrentCamera and Workspace.CurrentCamera.CFrame
            or CFrame.identity
        local ok=pcall(function() vu:ClickButton1(Vector2.new(x,y),cf) end)
        if ok then return true,"VirtualUser" end
    end
    return false,"executor sem firesignal/clique virtual permitido"
end

local function activateButton(btn)
    if not btn or not btn.Parent then
        return false,"botao nao encontrado"
    end
    -- Do NOT fire multiple event types on the same button:
    -- doing that might open and then immediately close the menu.
    if type(firesignal)=="function" then
        local activated=activeConnections(btn.Activated)
        local clicked=activeConnections(btn.MouseButton1Click)
        if activated and activated>0 then
            local ok,method=emitSignal(btn,"Activated")
            if ok then return true,method end
        end
        if clicked and clicked>0 then
            local ok,method=emitSignal(btn,"MouseButton1Click")
            if ok then return true,method end
        end
        -- If getconnections isn't available, only try ONE signal.
        if activated==nil and clicked==nil then
            local ok,method=emitSignal(btn,"MouseButton1Click")
            if ok then return true,method.." (sem confirmar listeners)" end
            local okAct,methodAct=emitSignal(btn,"Activated")
            if okAct then return true,methodAct.." (sem confirmar listeners)" end
        end
    end
    return virtualClick(btn)
end

local function waitUntil(check,seconds)
    local deadline=os.clock()+seconds
    while alive and os.clock()<deadline do
        local found=check()
        if found then return found end
        task.wait(.035)
    end
    return nil
end
local function finish(ok,message)
    running=false
    if mainButton and mainButton.Parent then
        mainButton.Text="🎭 EMOTE "..sector
    end
    if ok then successes=successes+1
    else failures=failures+1 end
    setStatus(message)
end
local function doMacro()
    if running or not alive then return end
    if os.clock()-lastClick<.65 then
        setStatus("Aguarde antes de repetir o emote")
        return
    end
    lastClick=os.clock()
    clicks=clicks+1
    running=true
    if mainButton then mainButton.Text="EM EXECUCAO..." end
    task.spawn(function()
        local ok,err=pcall(function()
            local btn=findSectorButton(sector)
            local menuAlreadyOpen=btn and isVisibleOnScreen(btn)
            local openMethod="ja estava aberto"
            if not menuAlreadyOpen then
                local openButton=findOpenButton()
                if not openButton then
                    finish(false,"NAO ACHEI PlayerGui/Mobile/Emote")
                    return
                end
                setStatus("1/2 Abrindo menu de emotes...")
                local fired,method=activateButton(openButton)
                if not fired then
                    finish(false,"Falha ao abrir: "..tostring(method))
                    return
                end
                openMethod=method
                btn=waitUntil(function()
                    local b=findSectorButton(sector)
                    return (b and isVisibleOnScreen(b)) and b or nil
                end,1.75)
                if not btn then
                    finish(false,"Menu nao apareceu; metodo="..openMethod..
                        " | executor pode bloquear evento")
                    return
                end
            end
            if not alive then return end
            setStatus("2/2 Selecionando Setor "..sector.."...")
            task.wait(.12)
            -- The menu can recreate its buttons upon opening.
            btn=findSectorButton(sector)
            if not btn or not isVisibleOnScreen(btn) then
                finish(false,"Setor "..sector.." ficou invisivel/sumiu")
                return
            end
            local fired,method=activateButton(btn)
            if not fired then
                finish(false,"Falha no setor "..sector..": "..tostring(method))
                return
            end
            -- An actual animation/emote may not close the menu. This
            -- measures GUI feedback only; never invent gameplay success.
            task.wait(.32)
            local after=findSectorButton(sector)
            if not after or not isVisibleOnScreen(after) then
                finish(true,"Setor "..sector.." enviado; menu fechou! ["..method.."]")
            else
                finish(true,"Setor "..sector.." acionado ["..method..
                    "] - emote NAO confirmado visualmente")
            end
        end)
        if not ok and alive then
            finish(false,"Erro: "..tostring(err):sub(1,90))
        end
    end)
end
local function cleanup()
    if not alive then return end
    alive=false
    for _,c in ipairs(connections) do
        pcall(function() c:Disconnect() end)
    end
    table.clear(connections)
    if gui then gui:Destroy() end
    if ENV.__MemeDashEmoteMacroCleanup==cleanup then
        ENV.__MemeDashEmoteMacroCleanup=nil
    end
    ENV.MemeDashEmoteMacro=nil
end
ENV.__MemeDashEmoteMacroCleanup=cleanup

gui=Instance.new("ScreenGui")
gui.Name="MemeDashEmoteMacro"
gui.DisplayOrder=999700
gui.IgnoreGuiInset=false
gui.ResetOnSpawn=false
gui.Parent=pg
panel=Instance.new("Frame")
panel.Name="Panel"
panel.Size=UDim2.fromOffset(160,113)
panel.Position=UDim2.new(.08,0,.52,0)
panel.BackgroundColor3=Color3.fromRGB(20,26,39)
panel.BorderSizePixel=0
panel.Active=true
panel.Parent=gui
Instance.new("UICorner",panel).CornerRadius=UDim.new(0,12)
local stroke=Instance.new("UIStroke")
stroke.Color=Color3.fromRGB(86,158,214)
stroke.Thickness=1
stroke.Parent=panel

local function makeButton(text,pos,size,color,fontSize)
    local b=Instance.new("TextButton")
    b.Text=text
    b.Position=pos
    b.Size=size
    b.TextColor3=Color3.new(1,1,1)
    b.BackgroundColor3=color
    b.BorderSizePixel=0
    b.Font=Enum.Font.GothamBold
    b.TextSize=fontSize or 12
    b.Parent=panel
    Instance.new("UICorner",b).CornerRadius=UDim.new(0,8)
    return b
end
local title=Instance.new("TextLabel")
title.Size=UDim2.new(1,-29,0,22)
title.Position=UDim2.fromOffset(8,2)
title.BackgroundTransparency=1
title.Text="🎭 MACRO EMOTE"
title.Font=Enum.Font.GothamBold
title.TextSize=11
title.TextColor3=Color3.fromRGB(163,219,251)
title.TextXAlignment=Enum.TextXAlignment.Left
title.Active=true
title.Parent=panel
local close=makeButton("X",UDim2.new(1,-27,0,2),
    UDim2.fromOffset(24,23),Color3.fromRGB(151,64,81),11)
mainButton=makeButton("🎭 EMOTE 6",UDim2.fromOffset(7,27),
    UDim2.fromOffset(146,36),Color3.fromRGB(28,141,114),14)
local minus=makeButton("−",UDim2.fromOffset(7,68),
    UDim2.fromOffset(28,25),Color3.fromRGB(71,89,115),16)
sectorLabel=Instance.new("TextLabel")
sectorLabel.Position=UDim2.fromOffset(40,68)
sectorLabel.Size=UDim2.fromOffset(78,25)
sectorLabel.BackgroundTransparency=1
sectorLabel.TextColor3=Color3.new(1,1,1)
sectorLabel.Text="SETOR 6"
sectorLabel.Font=Enum.Font.GothamBold
sectorLabel.TextSize=11
sectorLabel.Parent=panel
local plus=makeButton("+",UDim2.fromOffset(124,68),
    UDim2.fromOffset(29,25),Color3.fromRGB(71,89,115),16)

statusLabel=Instance.new("TextLabel")
statusLabel.BackgroundTransparency=1
statusLabel.Position=UDim2.fromOffset(7,97)
statusLabel.Size=UDim2.fromOffset(146,14)
statusLabel.TextColor3=Color3.fromRGB(178,197,214)
statusLabel.TextXAlignment=Enum.TextXAlignment.Left
statusLabel.TextSize=9
statusLabel.Font=Enum.Font.Gotham
statusLabel.Text="1 toque = abrir + selecionar"
statusLabel.TextTruncate=Enum.TextTruncate.AtEnd
statusLabel.Parent=panel

local function changeSector(n)
    if running then return end
    sector=math.clamp(n,1,8)
    sectorLabel.Text="SETOR "..sector
    mainButton.Text="🎭 EMOTE "..sector
    setStatus("Emote do Setor "..sector.." selecionado")
end
connect(minus.Activated,function() changeSector(sector-1) end)
connect(plus.Activated,function() changeSector(sector+1) end)
connect(mainButton.Activated,doMacro)
connect(close.Activated,cleanup)

-- Optional drag by the little title only, to avoid blocking camera swipes.
local dragging=false
local dragInput=nil
local dragOrigin=nil
local panelOrigin=nil
connect(title.InputBegan,function(input)
    if input.UserInputType==Enum.UserInputType.Touch
        or input.UserInputType==Enum.UserInputType.MouseButton1 then
        dragging=true
        dragInput=input
        dragOrigin=input.Position
        panelOrigin=panel.Position
    end
end)
connect(UIS.InputChanged,function(input)
    if not dragging or not dragInput or not panelOrigin then return end
    if input==dragInput or (dragInput.UserInputType==Enum.UserInputType.MouseButton1
        and input.UserInputType==Enum.UserInputType.MouseMovement) then
        local d=input.Position-dragOrigin
        panel.Position=UDim2.new(
            panelOrigin.X.Scale,panelOrigin.X.Offset+d.X,
            panelOrigin.Y.Scale,panelOrigin.Y.Offset+d.Y)
    end
end)
connect(UIS.InputEnded,function(input)
    if input==dragInput then
        dragging,dragInput,dragOrigin,panelOrigin=false,nil,nil,nil
    end
end)
ENV.MemeDashEmoteMacro={
    Version=BUILD,
    Fire=doMacro,
    SetSector=changeSector,
    GetSector=function() return sector end,
    GetCounters=function() return {
        attempts=clicks,stageDispatches=successes,failedAttempts=failures
    } end,
    Cleanup=cleanup
}
print("[MemeDash Macro] "..BUILD.."; touch EMOTE 6. firesignal or virtual click required.")
