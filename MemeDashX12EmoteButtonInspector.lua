-- MemeDash X12 | EMOTE UI BUTTON INSPECTOR v1
-- Diagnostico read-only para criar um futuro atalho de emote.
-- Captura 2 toques reais: abrir menu de emotes, selecionar um emote.
-- NAO simula toques; nao dispara botoes nem altera interfaces do jogo.
-- A selecao precisa ser feita pelo usuario, usando os botoes originais.
-- O relatorio mostra apenas caminhos de UI visiveis ao PlayerGui.
-- GetGuiObjectsAtPosition e API oficial, mas CoreGui pode estar inacessivel.

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local Workspace = game:GetService("Workspace")
local player = Players.LocalPlayer
assert(player, "X12 precisa ser executado no cliente.")
assert(game.PlaceId == 134001816760598, "X12 e exclusivo para MemeDash.")
local pg = player:WaitForChild("PlayerGui")
local ENV = (type(getgenv) == "function" and getgenv()) or _G

if type(ENV.__MemeDashX12Cleanup)=="function" then
    pcall(ENV.__MemeDashX12Cleanup)
end
local previous = pg:FindFirstChild("MemeDashX12EmoteInspector")
if previous then previous:Destroy() end

local BUILD = "X12-EMOTE-TAP-20261030"
local connections = {}
local alive, step = true, 0
local armedAt = 0
local captures = {}
local lastInfo = "PRONTO"
local startedAt = os.clock()
local report = "Clique INICIAR e use os dois botoes originais."

local gui = Instance.new("ScreenGui")
gui.Name = "MemeDashX12EmoteInspector"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.DisplayOrder = 900001
gui.Parent = pg
local panel = Instance.new("Frame")
panel.Name = "ControlPanel"
panel.Size = UDim2.fromOffset(346, 164)
panel.AnchorPoint = Vector2.new(.5,0)
panel.Position = UDim2.new(.5,0,.06,0)
panel.BackgroundColor3 = Color3.fromRGB(19,25,36)
panel.BorderSizePixel = 0
panel.Active = true
panel.Parent = gui
Instance.new("UICorner",panel).CornerRadius = UDim.new(0,11)

local function label(t,x,y,w,h,fontSize,color)
    local l=Instance.new("TextLabel")
    l.BackgroundTransparency=1
    l.Text=t
    l.Position=UDim2.fromOffset(x,y)
    l.Size=UDim2.fromOffset(w,h)
    l.TextXAlignment=Enum.TextXAlignment.Left
    l.TextYAlignment=Enum.TextYAlignment.Center
    l.TextWrapped=true
    l.Font=Enum.Font.Gotham
    l.TextSize=fontSize
    l.TextColor3=color or Color3.new(1,1,1)
    l.Parent=panel
    return l
end
local heading = label("MEMEDASH • X12 EMOTE INSPECTOR",10,5,323,23,13,
    Color3.fromRGB(131,209,252))
heading.Font=Enum.Font.GothamBold
local instructions = label(
    "1. Toque INICIAR. 2. Toque o botao original de emotes. 3. Toque um emote do menu.",
    10,28,326,48,11,Color3.fromRGB(225,234,246))
local state = label("PRONTO • apenas observacao",10,76,327,32,11,
    Color3.fromRGB(169,242,194))
local function button(text,x,w,color)
    local b=Instance.new("TextButton")
    b.Text=text
    b.Size=UDim2.fromOffset(w,33)
    b.Position=UDim2.fromOffset(x,118)
    b.BackgroundColor3=color
    b.TextColor3=Color3.new(1,1,1)
    b.Font=Enum.Font.GothamBold
    b.TextSize=11
    b.BorderSizePixel=0
    b.Parent=panel
    Instance.new("UICorner",b).CornerRadius=UDim.new(0,7)
    return b
end
local startButton=button("INICIAR",10,88,Color3.fromRGB(29,135,100))
local redoButton=button("REFAZER",103,88,Color3.fromRGB(75,87,112))
local copyButton=button("COPIAR",196,76,Color3.fromRGB(49,112,194))
local closeButton=button("X",279,56,Color3.fromRGB(161,67,85))

local function connect(signal,callback)
    local con=signal:Connect(callback)
    connections[#connections+1]=con
    return con
end
local function cleanup()
    if not alive then return end
    alive=false
    for _,con in ipairs(connections) do
        pcall(function() con:Disconnect() end)
    end
    table.clear(connections)
    if ENV.__MemeDashX12Cleanup==cleanup then
        ENV.__MemeDashX12Cleanup=nil
    end
    gui:Destroy()
end
ENV.__MemeDashX12Cleanup=cleanup
connect(closeButton.Activated,cleanup)

local function screenPosition()
    local c=Workspace.CurrentCamera
    if c then
        return string.format("%d,%d",c.ViewportSize.X,c.ViewportSize.Y)
    end
    return "unknown"
end
local function safePath(obj)
    if not obj then return "(none)" end
    local nodes={}
    local current=obj
    local iterations=0
    while current and current~=pg and iterations<24 do
        nodes[#nodes+1]=tostring(current.Name)
        current=current.Parent
        iterations=iterations+1
    end
    if current~=pg then return "(outside PlayerGui): "..obj.ClassName end
    local ordered={}
    for i=#nodes,1,-1 do ordered[#ordered+1]=nodes[i] end
    return "PlayerGui/"..table.concat(ordered,"/")
end
local function safeText(obj)
    if not obj then return "" end
    if not (obj:IsA("TextButton") or obj:IsA("TextLabel")
        or obj:IsA("TextBox")) then return "" end
    local ok,t=pcall(function()return obj.Text end)
    if not ok then return "(unavailable)" end
    t=tostring(t):gsub("[%c]", " ")
    return t:sub(1,80)
end
local function property(obj,key)
    local ok,val=pcall(function() return obj[key] end)
    if ok then return tostring(val) end
    return "unavailable"
end
local function imageInfo(obj)
    if not (obj:IsA("ImageButton") or obj:IsA("ImageLabel")) then return "" end
    local ok,id=pcall(function() return obj.Image end)
    if ok then
        -- Public Roblox asset URI; avoid arbitrary external links in report.
        id=tostring(id)
        if id:match("^rbxasset") then return id:sub(1,90) end
        return "(non-asset image omitted)"
    end
    return "(inaccessible)"
end
local function rootScreenGui(obj)
    local curr=obj
    while curr and curr~=pg do
        if curr:IsA("ScreenGui") then return curr end
        curr=curr.Parent
    end
    return nil
end
local function describe(obj,rank)
    if not obj then return "NONE" end
    local parts={
        string.format("Candidate #%d",rank),
        "  Path="..safePath(obj),
        "  Class="..obj.ClassName,
        "  Name="..obj.Name,
        "  IsGuiButton="..tostring(obj:IsA("GuiButton")),
        "  Visible="..property(obj,"Visible"),
        "  Active="..property(obj,"Active"),
        "  Interactable="..property(obj,"Interactable"),
        "  ZIndex="..property(obj,"ZIndex"),
        "  AbsolutePosition="..property(obj,"AbsolutePosition"),
        "  AbsoluteSize="..property(obj,"AbsoluteSize")
    }
    local text=safeText(obj)
    if text~="" then parts[#parts+1]="  Text="..text end
    local im=imageInfo(obj)
    if im~="" then parts[#parts+1]="  Image="..im end
    local screen=rootScreenGui(obj)
    if screen then
        parts[#parts+1]="  ScreenGui="..safePath(screen)
        parts[#parts+1]="  ScreenGui.Enabled="..property(screen,"Enabled")
        parts[#parts+1]="  ScreenGui.DisplayOrder="..property(screen,"DisplayOrder")
    end
    local parent=obj.Parent
    if parent and parent:IsA("GuiObject") then
        parts[#parts+1]="  Parent="..safePath(parent)
    end
    return table.concat(parts,"\n")
end
local function candidateFromHit(hit)
    -- The actual button is often the parent of an ImageLabel or TextLabel.
    local current=hit
    local n=0
    while current and current~=pg and n<15 do
        if current:IsA("GuiButton") then return current end
        current=current.Parent
        n=n+1
    end
    return hit
end
local function fromPlayerGui(x,y)
    local ok,res=pcall(function()
        return pg:GetGuiObjectsAtPosition(math.floor(x+.5), math.floor(y+.5))
    end)
    if not ok or type(res)~="table" then
        return nil, tostring(res), 0
    end
    local collected={}
    for _,obj in ipairs(res) do
        if typeof(obj)=="Instance" and obj:IsA("GuiObject")
            and not obj:IsDescendantOf(gui) then
            collected[#collected+1]=obj
        end
    end
    return collected,nil,#res
end
local function pick(pos)
    local inset=Vector2.zero
    local ok,topLeft=pcall(function()
        local top=GuiService:GetGuiInset()
        return top
    end)
    if ok and typeof(topLeft)=="Vector2" then inset=topLeft end
    local trials={
        {label="InputPosition",x=pos.X,y=pos.Y},
        {label="InputPositionMinusGuiInset",x=pos.X,y=pos.Y-inset.Y}
    }
    local bestHits,bestSource,bestTotal=nil,nil,0
    local errors={}
    for _,trial in ipairs(trials) do
        local hits,err,total=fromPlayerGui(trial.x,trial.y)
        if hits and (not bestHits or #hits>#bestHits) then
            bestHits,bestSource,bestTotal=hits,trial.label,total
        end
        if err then errors[#errors+1]=trial.label..": "..err end
    end
    bestHits=bestHits or {}
    local candidates={}
    local already={}
    local interactive=0
    for _,hit in ipairs(bestHits) do
        local o=candidateFromHit(hit)
        if not already[o] then
            already[o]=true
            candidates[#candidates+1]=o
            if o:IsA("GuiButton") then interactive=interactive+1 end
        end
        if #candidates>=10 then break end
    end
    local best=nil
    for _,o in ipairs(candidates) do
        if o:IsA("GuiButton") then best=o;break end
    end
    if not best then best=candidates[1] end
    return {
        x=pos.X,y=pos.Y,
        insetY=inset.Y,
        hitSource=bestSource or "(failed)",
        totalAtPosition=bestTotal,
        filteredHits=#bestHits,
        interactiveCount=interactive,
        errors=errors,
        candidates=candidates,
        selected=best,
        timestamp=os.clock()-startedAt,
    }
end
local function captureLines(title,cap)
    local lines={"["..title.."]"}
    if not cap then
        lines[#lines+1]="NOT CAPTURED"
        return lines
    end
    lines[#lines+1]=string.format("TouchPosition=%.1f,%.1f",cap.x,cap.y)
    lines[#lines+1]=string.format("GuiInsetY=%.1f",cap.insetY)
    lines[#lines+1]="LookupMode="..cap.hitSource
    lines[#lines+1]="ObjectsAtPositionTotal="..tostring(cap.totalAtPosition)
    lines[#lines+1]="GameObjectsAtPosition="..tostring(cap.filteredHits)
    lines[#lines+1]="ActionableCandidateCount="..tostring(cap.interactiveCount)
    lines[#lines+1]="BestCandidate="..safePath(cap.selected)
    lines[#lines+1]=string.format("Elapsed=%.3fs",cap.timestamp)
    for _,e in ipairs(cap.errors) do lines[#lines+1]="LookupError="..e end
    if #cap.candidates==0 then
        lines[#lines+1]="No PlayerGui objects found. Button may be CoreGui, 3D,"
        lines[#lines+1]="or GUI location may not match touch coordinates."
    end
    for i,obj in ipairs(cap.candidates) do
        lines[#lines+1]=describe(obj,i)
    end
    return lines
end
local function makeReport()
    local lines={
        "===== MEMEDASH X12 / EMOTE BUTTONS =====",
        "Build="..BUILD,
        "Read-only=true (no synthetic taps, no GUI actions).",
        "PlaceId="..tostring(game.PlaceId),
        "TouchEnabled="..tostring(UIS.TouchEnabled),
        "CameraViewport="..screenPosition(),
        "FinishedStages="..tostring(math.min(step,3)),
        ""
    }
    local a=captureLines("STEP 1 - OPEN EMOTES MENU",captures[1])
    for _,line in ipairs(a) do lines[#lines+1]=line end
    lines[#lines+1]=""
    local b=captureLines("STEP 2 - SELECT AN EMOTE",captures[2])
    for _,line in ipairs(b) do lines[#lines+1]=line end
    lines[#lines+1]=""
    lines[#lines+1]="[IMPORTANT]"
    lines[#lines+1]="GUI path identifies a candidate, NOT the internal callback."
    lines[#lines+1]="The GUI might be recreated each time the menu opens."
    lines[#lines+1]="If buttons are in CoreGui, PlayerGui cannot report them."
    lines[#lines+1]="No macro was installed; this diagnostic only observes taps."
    lines[#lines+1]="===== END X12 ====="
    return table.concat(lines,"\n")
end
local function setState(text)
    lastInfo=text
    if alive then state.Text=text end
end
local function begin()
    if not alive then return end
    table.clear(captures)
    step=1
    armedAt=os.clock()+.28
    report="Capture em andamento."
    setState("ETAPA 1/2 • toque o botao ORIGINAL de emotes")
    startButton.Text="CAPTURANDO"
end
connect(startButton.Activated,begin)
connect(redoButton.Activated,begin)

local function isInsidePanel(pos)
    local p,s=panel.AbsolutePosition,panel.AbsoluteSize
    return pos.X>=p.X and pos.X<=p.X+s.X
        and pos.Y>=p.Y and pos.Y<=p.Y+s.Y
end
connect(UIS.InputBegan,function(input,wasProcessed)
    if not alive or (step~=1 and step~=2) then return end
    if input.UserInputType~=Enum.UserInputType.Touch and
        input.UserInputType~=Enum.UserInputType.MouseButton1 then return end
    if os.clock()<armedAt then return end
    if isInsidePanel(input.Position) then return end
    local phase=step
    local ok,cap=pcall(pick,input.Position)
    if not ok then
        setState("Erro de captura: "..tostring(cap):sub(1,62))
        return
    end
    cap.wasProcessed=wasProcessed
    captures[phase]=cap
    if phase==1 then
        step=2
        armedAt=os.clock()+.24
        setState("ETAPA 2/2 • agora selecione um EMOTE no menu")
    else
        step=3
        report=makeReport()
        startButton.Text="NOVO TESTE"
        setState("PRONTO! "..#report.." caracteres • toque COPIAR")
    end
end)

local function clipboardFallback()
    local modal=Instance.new("Frame")
    modal.Size=UDim2.new(.96,0,.94,0)
    modal.Position=UDim2.new(.02,0,.03,0)
    modal.BackgroundColor3=Color3.fromRGB(17,21,30)
    modal.ZIndex=10
    modal.Parent=gui
    local field=Instance.new("TextBox")
    field.Size=UDim2.new(1,-16,1,-55)
    field.Position=UDim2.fromOffset(8,8)
    field.BackgroundColor3=Color3.fromRGB(30,35,49)
    field.TextColor3=Color3.new(1,1,1)
    field.Font=Enum.Font.Code
    field.TextSize=11
    field.TextXAlignment=Enum.TextXAlignment.Left
    field.TextYAlignment=Enum.TextYAlignment.Top
    field.TextWrapped=false
    field.MultiLine=true
    field.ClearTextOnFocus=false
    field.TextEditable=true
    field.Text=report
    field.ZIndex=11
    field.Parent=modal
    local exit=Instance.new("TextButton")
    exit.Position=UDim2.new(1,-96,1,-44)
    exit.Size=UDim2.fromOffset(85,35)
    exit.BackgroundColor3=Color3.fromRGB(143,59,82)
    exit.TextColor3=Color3.new(1,1,1)
    exit.Text="FECHAR"
    exit.Font=Enum.Font.GothamBold
    exit.ZIndex=12
    exit.Parent=modal
    connect(exit.Activated,function()modal:Destroy() end)
    setState("Sem clipboard: copie o texto da caixa.")
end
connect(copyButton.Activated,function()
    if not alive then return end
    if step<3 then
        setState("Falta tocar o botao de abrir e selecionar um emote.")
        return
    end
    report=makeReport()
    local clip=(type(setclipboard)=="function" and setclipboard)
        or (type(toclipboard)=="function" and toclipboard)
    if clip then
        local ok=pcall(clip,report)
        if ok then
            setState("COPIADO! Cole aqui na conversa.")
            return
        end
    end
    clipboardFallback()
end)
print("[MemeDash X12] Emote buttons: INICIAR > original menu > actual emote > COPIAR.")
