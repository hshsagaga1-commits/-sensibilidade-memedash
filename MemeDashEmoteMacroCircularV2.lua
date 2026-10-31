-- MemeDash | Macro Circular V2 (iPhone) - tap1 play, tap2 stop
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
if type(ENV.__MemeDashEmoteMacroCircularCleanup)=="function" then pcall(ENV.__MemeDashEmoteMacroCircularCleanup) end
if type(ENV.__MemeDashEmoteMacroCleanup)=="function" then
    pcall(ENV.__MemeDashEmoteMacroCleanup)
end
local previous=pg:FindFirstChild("MemeDashEmoteMacro")
if previous then previous:Destroy() end
local prior=pg:FindFirstChild("MemeDashEmoteMacroCircular")
if prior then prior:Destroy() end

local BUILD="EmoteMacroCircularV2-StartStop-20261030"
local running,alive=false,true
local sector=6
local lastClick=0
local clicks,successes,failures=0,0,0
local startedAt=os.clock()
local logLines={}
local connections={}
local gui, panel, mainButton, sectorLabel, statusLabel
local lockButton, settingsButton, settingsPanel
local locked=false
local nextAction="start"
local starts,stops=0,0

local function connect(signal,fn)
    local c=signal:Connect(fn)
    connections[#connections+1]=c
    return c
end
local function setStatus(t)
    local entry=string.format("%.2fs | %s",os.clock()-startedAt,tostring(t))
    logLines[#logLines+1]=entry
    if #logLines>70 then table.remove(logLines,1) end
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
local function refresh()
    if not mainButton or not mainButton.Parent then return end
    if running then
        mainButton.Text="..."
        mainButton.BackgroundColor3=Color3.fromRGB(63,104,160)
    elseif nextAction=="stop" then
        mainButton.Text="■"
        mainButton.BackgroundColor3=Color3.fromRGB(172,63,80)
    else
        mainButton.Text="🎭"
        mainButton.BackgroundColor3=Color3.fromRGB(27,143,106)
    end
end

local function finish(ok,message,toAction)
    running=false
    if ok then
        successes=successes+1
        if toAction then nextAction=toAction end
        if toAction=="stop" then starts=starts+1 end
        if toAction=="start" then stops=stops+1 end
    else
        failures=failures+1
    end
    refresh()
    setStatus(message)
end
local function doMacro()
    if not alive or running then return end
    if os.clock()-lastClick<.55 then return end
    lastClick=os.clock()
    running=true
    clicks=clicks+1
    refresh()
    local action=nextAction
    task.spawn(function()
        local ok,err=pcall(function()
            if action=="stop" then
                -- On second tap, ONLY dispatch Mobile/Emote; NO sector button.
                setStatus("PARAR: apenas Mobile/Emote")
                local b=findOpenButton()
                if not b then
                    finish(false,"Mobile/Emote nao encontrado")
                    return
                end
                local sent,method=activateButton(b)
                if not sent then
                    finish(false,"Erro PARAR: "..tostring(method))
                    return
                end
                finish(true,"Cancelamento enviado ["..method.."] (nao confirmado)","start")
                return
            end
            -- First tap: open native menu and select the chosen emote.
            local b=findSectorButton(sector)
            if not (b and isVisibleOnScreen(b)) then
                local opener=findOpenButton()
                if not opener then
                    finish(false,"Botao original Mobile/Emote nao encontrado")
                    return
                end
                setStatus("INICIAR 1/2: abrir menu")
                local sent,method=activateButton(opener)
                if not sent then
                    finish(false,"Erro abrindo menu: "..tostring(method))
                    return
                end
                b=waitUntil(function()
                    local candidate=findSectorButton(sector)
                    return candidate and isVisibleOnScreen(candidate) and candidate
                end,1.75)
                if not b then
                    finish(false,"Menu/setor nao apareceu (metodo: "..method..")")
                    return
                end
            end
            setStatus("INICIAR 2/2: setor "..sector)
            task.wait(.10)
            b=findSectorButton(sector)
            if not b or not isVisibleOnScreen(b) then
                finish(false,"Setor nao esta visivel")
                return
            end
            local sent,method=activateButton(b)
            if not sent then
                finish(false,"Erro selecionando setor: "..tostring(method))
                return
            end
            finish(true,"Emote "..sector.." enviado ["..method.."] (nao confirmado)","stop")
        end)
        if not ok and alive then
            finish(false,"Erro macro: "..tostring(err):sub(1,110))
        end
    end)
end

local function cleanup()
    if not alive then return end
    alive=false
    for _,item in ipairs(connections) do
        pcall(function() item:Disconnect() end)
    end
    table.clear(connections)
    if gui then gui:Destroy() end
    if ENV.__MemeDashEmoteMacroCircularCleanup==cleanup then
        ENV.__MemeDashEmoteMacroCircularCleanup=nil
    end
    ENV.MemeDashEmoteMacroCircular=nil
end
ENV.__MemeDashEmoteMacroCircularCleanup=cleanup

gui=Instance.new("ScreenGui")
gui.Name="MemeDashEmoteMacroCircular"
gui.ResetOnSpawn=false
gui.IgnoreGuiInset=false
gui.DisplayOrder=999701
gui.Parent=pg

panel=Instance.new("Frame")
panel.Name="FloatingEmoteControl"
panel.Size=UDim2.fromOffset(90,90)
panel.Position=UDim2.new(.14,0,.52,0)
panel.BackgroundTransparency=1
panel.BorderSizePixel=0
panel.Active=true
panel.Parent=gui

local function button(text,pos,size,color,fontSize,parent)
    local b=Instance.new("TextButton")
    b.Text=text
    b.Position=pos
    b.Size=size
    b.TextColor3=Color3.new(1,1,1)
    b.BackgroundColor3=color
    b.BorderSizePixel=0
    b.Font=Enum.Font.GothamBold
    b.TextSize=fontSize or 12
    b.Parent=parent or panel
    Instance.new("UICorner",b).CornerRadius=UDim.new(0,9)
    return b
end

mainButton=button("🎭",UDim2.fromOffset(7,7),UDim2.fromOffset(72,72),
    Color3.fromRGB(27,143,106),29)
mainButton.Name="Circle"
mainButton.Active=true
mainButton:FindFirstChildOfClass("UICorner").CornerRadius=UDim.new(1,0)
local outline=Instance.new("UIStroke")
outline.Thickness=2
outline.Color=Color3.fromRGB(137,220,253)
outline.Parent=mainButton

lockButton=button("🔓",UDim2.fromOffset(61,0),UDim2.fromOffset(27,27),
    Color3.fromRGB(68,81,100),14)
lockButton.Name="LockPosition"
lockButton:FindFirstChildOfClass("UICorner").CornerRadius=UDim.new(1,0)

settingsButton=button("⚙",UDim2.fromOffset(61,62),UDim2.fromOffset(27,27),
    Color3.fromRGB(52,95,143),17)
settingsButton.Name="Settings"
settingsButton:FindFirstChildOfClass("UICorner").CornerRadius=UDim.new(1,0)

settingsPanel=Instance.new("Frame")
settingsPanel.Name="SettingsPanel"
settingsPanel.Size=UDim2.fromOffset(182,145)
settingsPanel.BackgroundColor3=Color3.fromRGB(21,27,40)
settingsPanel.BorderSizePixel=0
settingsPanel.Visible=false
settingsPanel.Parent=gui
Instance.new("UICorner",settingsPanel).CornerRadius=UDim.new(0,10)

local heading=Instance.new("TextLabel")
heading.Size=UDim2.fromOffset(167,25)
heading.Position=UDim2.fromOffset(8,3)
heading.BackgroundTransparency=1
heading.Text="EMOTE • 1 COMECA / 2 PARA"
heading.TextColor3=Color3.fromRGB(153,221,247)
heading.Font=Enum.Font.GothamBold
heading.TextSize=10
heading.TextXAlignment=Enum.TextXAlignment.Left
heading.Parent=settingsPanel

local minus=button("−",UDim2.fromOffset(8,33),UDim2.fromOffset(32,29),
    Color3.fromRGB(62,79,109),16,settingsPanel)
sectorLabel=Instance.new("TextLabel")
sectorLabel.Position=UDim2.fromOffset(43,34)
sectorLabel.Size=UDim2.fromOffset(94,28)
sectorLabel.Text="SETOR 6"
sectorLabel.BackgroundTransparency=1
sectorLabel.TextColor3=Color3.new(1,1,1)
sectorLabel.Font=Enum.Font.GothamBold
sectorLabel.TextSize=12
sectorLabel.Parent=settingsPanel
local plus=button("+",UDim2.fromOffset(140,33),UDim2.fromOffset(33,29),
    Color3.fromRGB(62,79,109),17,settingsPanel)

statusLabel=Instance.new("TextLabel")
statusLabel.Position=UDim2.fromOffset(8,67)
statusLabel.Size=UDim2.fromOffset(167,41)
statusLabel.BackgroundTransparency=1
statusLabel.Text="Circulo: tocar para iniciar/parar"
statusLabel.TextWrapped=true
statusLabel.TextColor3=Color3.fromRGB(184,202,221)
statusLabel.TextXAlignment=Enum.TextXAlignment.Left
statusLabel.Font=Enum.Font.Gotham
statusLabel.TextSize=10
statusLabel.Parent=settingsPanel

local logButton=button("COPIAR LOG",UDim2.fromOffset(8,112),
    UDim2.fromOffset(166,26),Color3.fromRGB(49,110,187),11,settingsPanel)
local function moveSettings()
    local cam=Workspace.CurrentCamera
    local size=cam and cam.ViewportSize or Vector2.new(724,375)
    local x=panel.AbsolutePosition.X+91
    if x+182>size.X-3 then x=math.max(3,panel.AbsolutePosition.X-185) end
    local y=math.clamp(panel.AbsolutePosition.Y,3,math.max(3,size.Y-149))
    settingsPanel.Position=UDim2.fromOffset(x,y)
end

local function showLogText(text)
    local modal=Instance.new("Frame")
    modal.Size=UDim2.new(.94,0,.76,0)
    modal.Position=UDim2.new(.03,0,.12,0)
    modal.BackgroundColor3=Color3.fromRGB(22,28,40)
    modal.ZIndex=10
    modal.Parent=gui
    local field=Instance.new("TextBox")
    field.Size=UDim2.new(1,-12,1,-53)
    field.Position=UDim2.fromOffset(6,6)
    field.Text=text
    field.TextColor3=Color3.new(1,1,1)
    field.TextSize=11
    field.TextXAlignment=Enum.TextXAlignment.Left
    field.TextYAlignment=Enum.TextYAlignment.Top
    field.Font=Enum.Font.Code
    field.MultiLine=true
    field.TextWrapped=false
    field.ClearTextOnFocus=false
    field.BackgroundColor3=Color3.fromRGB(30,35,48)
    field.ZIndex=11
    field.Parent=modal
    local done=Instance.new("TextButton")
    done.Size=UDim2.fromOffset(84,36)
    done.Position=UDim2.new(1,-91,1,-43)
    done.Text="FECHAR"
    done.Font=Enum.Font.GothamBold
    done.TextColor3=Color3.new(1,1,1)
    done.BackgroundColor3=Color3.fromRGB(151,64,81)
    done.ZIndex=12
    done.Parent=modal
    connect(done.Activated,function() modal:Destroy() end)
end
connect(logButton.Activated,function()
    local lines={
        "===== MEMEDASH MACRO LOG =====",
        "Build="..BUILD,
        "Sector="..tostring(sector),
        "firesignal="..tostring(type(firesignal)),
        "getconnections="..tostring(type(getconnections)),
        "Attempts="..tostring(clicks),
        "Dispatched="..tostring(successes),
        "Failures="..tostring(failures),
        "NextAction="..nextAction,
        "Locked="..tostring(locked),
        ""
    }
    for _,entry in ipairs(logLines) do lines[#lines+1]=entry end
    lines[#lines+1]="===== END LOG ====="
    local content=table.concat(lines,"\n")
    local clip=(type(setclipboard)=="function" and setclipboard)
        or (type(toclipboard)=="function" and toclipboard)
    if clip and pcall(clip,content) then
        setStatus("LOG COPIADO! Cole na conversa")
    else
        showLogText(content)
        setStatus("Selecione o log da caixa para copiar")
    end
end)

local function changeSector(n)
    if running then return end
    local n2=math.clamp(tonumber(n) or 6,1,8)
    if n2~=sector then
        sector=n2
        nextAction="start"
        refresh()
    end
    sectorLabel.Text="SETOR "..sector
    setStatus("Setor "..sector.." • proximo clique: "..nextAction)
end
connect(minus.Activated,function() changeSector(sector-1) end)
connect(plus.Activated,function() changeSector(sector+1) end)
connect(lockButton.Activated,function()
    locked=not locked
    lockButton.Text=locked and "🔒" or "🔓"
    lockButton.BackgroundColor3=locked and Color3.fromRGB(33,136,103)
        or Color3.fromRGB(68,81,100)
    setStatus(locked and "Posicao TRANCADA" or "Posicao destrancada")
end)
connect(settingsButton.Activated,function()
    settingsPanel.Visible=not settingsPanel.Visible
    if settingsPanel.Visible then moveSettings() end
end)

-- Only a SHORT touch runs the macro; dragging never does.
local dragInput,downAt,startAnchor=nil,nil,nil
local dragging=false
connect(mainButton.InputBegan,function(input)
    if dragInput then return end
    if input.UserInputType~=Enum.UserInputType.Touch and
        input.UserInputType~=Enum.UserInputType.MouseButton1 then return end
    dragInput=input
    downAt=input.Position
    startAnchor=panel.AbsolutePosition
    dragging=false
end)
connect(UIS.InputChanged,function(input)
    if not dragInput or not downAt or not startAnchor or locked then return end
    if input~=dragInput and not
        (dragInput.UserInputType==Enum.UserInputType.MouseButton1
        and input.UserInputType==Enum.UserInputType.MouseMovement) then
        return
    end
    local delta=input.Position-downAt
    if delta.Magnitude>9 then dragging=true end
    if not dragging then return end
    local camera=Workspace.CurrentCamera
    local vp=camera and camera.ViewportSize or Vector2.new(724,375)
    local size=panel.AbsoluteSize
    panel.Position=UDim2.fromOffset(
        math.clamp(startAnchor.X+delta.X,0,math.max(0,vp.X-size.X)),
        math.clamp(startAnchor.Y+delta.Y,0,math.max(0,vp.Y-size.Y))
    )
    if settingsPanel.Visible then moveSettings() end
end)
connect(UIS.InputEnded,function(input)
    if input~=dragInput then return end
    local moved=downAt and (input.Position-downAt).Magnitude>9 or dragging
    dragInput,downAt,startAnchor=nil,nil,nil
    dragging=false
    if not moved and alive then doMacro() end
end)
refresh()

ENV.MemeDashEmoteMacroCircular={
    Version=BUILD,
    Fire=doMacro,
    GetNextAction=function() return nextAction end,
    GetLocked=function() return locked end,
    SetSector=changeSector,
    GetSector=function() return sector end,
    ResetCycle=function()
        if running then return end
        nextAction="start"
        refresh()
        setStatus("Ciclo reiniciado")
    end,
    GetCounters=function() return {
        attempts=clicks,stageDispatches=successes,failedAttempts=failures,
        startDispatches=starts,stopDispatches=stops
    } end,
    Cleanup=cleanup
}

print("[MemeDash Macro] "..BUILD.."; circle START/STOP; lock position; gear for sector/log.")
