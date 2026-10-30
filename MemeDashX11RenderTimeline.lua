-- MemeDash X11 Render Timeline Diagnostic v1.0
-- READ ONLY. No CFrame writes, hooks, disabled scripts, or touch injection.
-- Purpose: find the frame interval in which camera/root rotation is updated.
-- "camera.Disabled=true" means the named LocalScript isn't currently enabled.
-- Observed timing CANNOT identify the exact code that wrote a CFrame.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local player = Players.LocalPlayer
assert(player, "MemeDash X11: execute no cliente.")
assert(game.PlaceId == 134001816760598, "MemeDash X11: jogo diferente.")
local guiParent = player:WaitForChild("PlayerGui")
local env = (type(getgenv) == "function" and getgenv()) or _G
if type(env.__MemeDashX11Cleanup)=="function" then
    pcall(env.__MemeDashX11Cleanup)
end
local old = guiParent:FindFirstChild("MemeDashX11")
if old then old:Destroy() end

local BUILD = "X11-TIMELINE-20261030"
local DURATION = 10.0
local stages = {
    {name="First(0)", priority=0},
    {name="PreInput(99)", priority=99},
    {name="PostInput(101)", priority=101},
    {name="PreCamera(199)", priority=199},
    {name="PostCamera(201)", priority=201},
    {name="AfterCamera(250)", priority=250},
    {name="PreChar(299)", priority=299},
    {name="PostChar(301)", priority=301},
    {name="Late(1000)", priority=1000},
    {name="AfterLast(2001)", priority=2001}
}
local connections, bindings = {}, {}
local alive, recording, finished = true, false, false
local startTime, frames, prev, currentCamera = 0, 0, nil, nil
local cameraCFrameChanges, cameraSignal, cameraTypeChanges = 0, nil, 0
local hasRight, movedPx, movedEvents, lastMove = {}, 0, 0, -999
local samples, sampleCount, cameraChangeFrame = {}, 0, 0
local stageMetrics = {}
for _,s in ipairs(stages) do
    stageMetrics[s.name] = {
        cameraUpdates=0, rootUpdates=0,
        yaw=0, pitch=0, root=0,
        maxYaw=0, maxRoot=0, cameraTravel=0,
        withTouch=0, withoutTouch=0,
        n=0
    }
end

local function connect(signal, fn)
    local c=signal:Connect(fn)
    connections[#connections+1]=c
    return c
end
local function addSample(txt)
    if sampleCount >= 45 then return end
    sampleCount=sampleCount+1
    samples[#samples+1]=txt
end
local function clampAngle(deg)
    return (deg+180)%360-180
end
local function orientation(cf)
    local x,y,z=cf:ToOrientation()
    return math.deg(y),math.deg(x),math.deg(z)
end
local function rootCFrame()
    local character=player.Character
    local root=character and character:FindFirstChild("HumanoidRootPart")
    return root and root.CFrame or nil
end
local function takeSnapshot()
    local cam=Workspace.CurrentCamera
    if not cam then return nil end
    local cf=cam.CFrame
    local yaw,pitch,roll=orientation(cf)
    local root=rootCFrame()
    local rootYaw=root and select(1,orientation(root)) or nil
    return {time=os.clock(),cam=cam,
        yaw=yaw,pitch=pitch,roll=roll,
        camPos=cf.Position, rootYaw=rootYaw,
        camType=cam.CameraType}
end
local function capture(stage)
    if not recording or not alive then return end
    local cur=takeSnapshot()
    if not cur then return end
    if not prev then
        prev=cur
        return
    end
    local s=stageMetrics[stage.name]
    local dy=math.abs(clampAngle(cur.yaw-prev.yaw))
    local dp=math.abs(clampAngle(cur.pitch-prev.pitch))
    local dr=0
    if cur.rootYaw~=nil and prev.rootYaw~=nil then
        dr=math.abs(clampAngle(cur.rootYaw-prev.rootYaw))
    end
    local dist=(cur.camPos-prev.camPos).Magnitude
    if prev.cam~=cur.cam or prev.camType~=cur.camType then
        cameraTypeChanges=cameraTypeChanges+1
        addSample(string.format("%.3fs %s camera replaced/type changed",
            os.clock()-startTime,stage.name))
        prev=cur
        return
    end
    s.n=s.n+1
    s.yaw=s.yaw+dy
    s.pitch=s.pitch+dp
    s.root=s.root+dr
    s.cameraTravel=s.cameraTravel+dist
    s.maxYaw=math.max(s.maxYaw,dy)
    s.maxRoot=math.max(s.maxRoot,dr)
    local camChanged=dy>.04 or dp>.04
    if camChanged then
        s.cameraUpdates=s.cameraUpdates+1
        cameraChangeFrame=cameraChangeFrame+1
        if os.clock()-lastMove < .15 then
            s.withTouch=s.withTouch+1
        else
            s.withoutTouch=s.withoutTouch+1
        end
    end
    if dr>.04 then s.rootUpdates=s.rootUpdates+1 end
    if camChanged and dy > 3 and sampleCount<45 then
        addSample(string.format("%.3f;%s;%.2f;%.2f;%.2f",
            os.clock()-startTime,stage.name,dy,dp,dr))
    elseif dr>8 and sampleCount<45 then
        addSample(string.format("%.3f;%s;%.2f;%.2f;%.2f;ROOT",
            os.clock()-startTime,stage.name,dy,dp,dr))
    end
    prev=cur
end

local function guiText(t, pos, size, color, txtSize)
    local l=Instance.new("TextLabel")
    l.BackgroundTransparency=1
    l.Text=t
    l.TextColor3=color or Color3.new(1,1,1)
    l.Font=Enum.Font.Gotham
    l.TextSize=txtSize or 12
    l.TextWrapped=true
    l.TextXAlignment=Enum.TextXAlignment.Left
    l.Position=pos
    l.Size=size
    return l
end
local gui=Instance.new("ScreenGui")
gui.Name="MemeDashX11"
gui.ResetOnSpawn=false
gui.DisplayOrder=990001
gui.Parent=guiParent
local panel=Instance.new("Frame")
panel.BackgroundColor3=Color3.fromRGB(20,25,36)
panel.BorderSizePixel=0
panel.Size=UDim2.fromOffset(335,196)
panel.Position=UDim2.new(.5,0,.12,0)
panel.AnchorPoint=Vector2.new(.5,0)
panel.Active=true
panel.Parent=gui
Instance.new("UICorner",panel).CornerRadius=UDim.new(0,11)
local title=guiText("MEMEDASH X11 • TIMELINE",
    UDim2.fromOffset(10,4),UDim2.new(1,-20,0,27),
    Color3.fromRGB(127,203,253),14)
title.Font=Enum.Font.GothamBold;title.Parent=panel
local subtitle=guiText("Detecta QUANDO a camera e o corpo mudam em cada frame. Nao modifica nada.",
    UDim2.fromOffset(10,33),UDim2.new(1,-20,0,44),
    Color3.fromRGB(223,228,239),11)
subtitle.Parent=panel
local status=guiText("PRONTO • 10 segundos de observacao",
    UDim2.fromOffset(10,79),UDim2.new(1,-20,0,27),
    Color3.fromRGB(171,239,188),11)
status.Parent=panel
local function newButton(txt,x,col)
    local b=Instance.new("TextButton")
    b.Position=UDim2.new(x,0,0,113)
    b.Size=UDim2.new(.31,-5,0,35)
    b.BackgroundColor3=col
    b.TextColor3=Color3.new(1,1,1)
    b.Font=Enum.Font.GothamBold
    b.TextSize=11
    b.Text=txt
    b.BorderSizePixel=0
    b.Parent=panel
    Instance.new("UICorner",b).CornerRadius=UDim.new(0,8)
    return b
end
local startBtn=newButton("INICIAR",.025,Color3.fromRGB(32,135,99))
local copyBtn=newButton("COPIAR",.35,Color3.fromRGB(39,103,180))
local closeBtn=newButton("FECHAR",.675,Color3.fromRGB(151,63,77))
local foot=guiText("X11-TIMELINE-20261030 • somente leitura",
    UDim2.fromOffset(10,157),UDim2.new(1,-20,0,29),
    Color3.fromRGB(158,175,194),10)
foot.Parent=panel
local report="Clique INICIAR, mexa a camera e caminhe por 10 segundos."
local function clearSignals()
    if cameraSignal then cameraSignal:Disconnect();cameraSignal=nil end
end
local function attachCamera()
    clearSignals()
    currentCamera=Workspace.CurrentCamera
    if currentCamera then
        cameraSignal=currentCamera:GetPropertyChangedSignal("CFrame"):Connect(function()
            if recording then cameraCFrameChanges=cameraCFrameChanges+1 end
        end)
    end
end
local function scriptState(obj)
    if not obj then return "not found" end
    local ok,value=pcall(function() return obj.Enabled end)
    return (ok and tostring(value) or "unknown").." ["..obj.ClassName.."]"
end
local function buildReport()
    local lines={
        "===== MEMEDASH X11 / RENDER TIMELINE =====",
        "Build="..BUILD,
        "Read-only: NO CFrame writes, no module hooks, no disabled-script changes.",
        "Duration="..tostring(DURATION),
        "PlaceId="..tostring(game.PlaceId),
        "TouchEnabled="..tostring(UIS.TouchEnabled),
        "FramesObserved="..tostring(frames),
        "Camera CFrame property change events="..tostring(cameraCFrameChanges),
        "Total rotations observed between checkpoints="..tostring(cameraChangeFrame),
        "Camera instance/type changes="..tostring(cameraTypeChanges),
        "RightTouchMoveEvents="..tostring(movedEvents),
        string.format("RightTouchPixels=%.1f",movedPx),
        ""
    }
    local folder=Workspace:FindFirstChild(player.Name)
    local cameraScript=folder and folder:FindFirstChild("camera")
    local bodyScript=folder and folder:FindFirstChild("bodyrotation")
    lines[#lines+1]="[VISIBLE LOCAL SCRIPT STATES]"
    lines[#lines+1]="Workspace.player.camera Enabled="..scriptState(cameraScript)
    lines[#lines+1]="Workspace.player.bodyrotation Enabled="..scriptState(bodyScript)
    lines[#lines+1]="CameraType="..tostring(Workspace.CurrentCamera and Workspace.CurrentCamera.CameraType)
    lines[#lines+1]="WARNING: timings alone do not identify which script wrote a CFrame."
    lines[#lines+1]=""
    lines[#lines+1]="[CHANGE BY CHECKPOINT]"
    lines[#lines+1]="Checkpoint;observations;camUpdates;rootUpdates;camYawAbs;camPitchAbs;rootYawAbs;maxYaw;maxRoot;camMotionUnits;touchCamChanges;noTouchCamChanges"
    for _,item in ipairs(stages) do
        local m=stageMetrics[item.name]
        lines[#lines+1]=string.format("%s;%d;%d;%d;%.2f;%.2f;%.2f;%.2f;%.2f;%.2f;%d;%d",
            item.name,m.n,m.cameraUpdates,m.rootUpdates,
            m.yaw,m.pitch,m.root,m.maxYaw,m.maxRoot,
            m.cameraTravel,m.withTouch,m.withoutTouch)
    end
    lines[#lines+1]=""
    lines[#lines+1]="[SELECTED CHANGES - time;checkpoint;absYaw;absPitch;absRootYaw]"
    for _,line in ipairs(samples) do lines[#lines+1]=line end
    lines[#lines+1]=""
    lines[#lines+1]="[INTERPRETATION]"
    lines[#lines+1]="Each checkpoint records the difference FROM THE PREVIOUS checkpoint,"
    lines[#lines+1]="including the previous frame's last checkpoint for First(0)."
    lines[#lines+1]="If camera updates cluster in one checkpoint, a controller"
    lines[#lines+1]="probably runs between those priorities. It may also run after"
    lines[#lines+1]="the last checkpoint or in other scheduling phases."
    lines[#lines+1]="Root changes and camera updates need not share a source."
    lines[#lines+1]="No settings, body, camera or input values changed."
    lines[#lines+1]="===== END X11 ====="
    return table.concat(lines,"\n")
end
local function finish()
    if not alive or not recording then return end
    recording=false
    finished=true
    report=buildReport()
    status.Text="CONCLUIDO • "..tostring(#report).." caracteres"
    startBtn.Text="REFAZER"
end
local function begin()
    if not alive or recording then return end
    recording=false
    finished=false
    prev=nil
    frames,cameraCFrameChanges,cameraTypeChanges=0,0,0
    movedPx,movedEvents,cameraChangeFrame=0,0,0
    startTime=os.clock()
    lastMove=-999
    samples,sampleCount={},0
    for _,m in pairs(stageMetrics) do
        for k in pairs(m) do m[k]=0 end
    end
    hasRight={}
    attachCamera()
    recording=true
    status.Text="GRAVANDO • mexa camera + personagem"
    startBtn.Text="MEDINDO..."
    task.delay(DURATION,function()
        if alive and recording then finish() end
    end)
end
local function cleanup()
    if not alive then return end
    recording=false
    alive=false
    clearSignals()
    for _,c in ipairs(connections) do pcall(function() c:Disconnect() end) end
    for _,name in ipairs(bindings) do
        pcall(function() RunService:UnbindFromRenderStep(name) end)
    end
    if env.__MemeDashX11Cleanup==cleanup then
        env.__MemeDashX11Cleanup=nil
    end
    gui:Destroy()
end
env.__MemeDashX11Cleanup=cleanup
connect(startBtn.Activated,begin)
connect(closeBtn.Activated,cleanup)

local function touchInPanel(input)
    local p=panel.AbsolutePosition
    local size=panel.AbsoluteSize
    local a=input.Position
    return a.X>=p.X and a.X<=p.X+size.X
        and a.Y>=p.Y and a.Y<=p.Y+size.Y
end
connect(UIS.TouchStarted,function(input)
    if touchInPanel(input) then return end
    local cam=Workspace.CurrentCamera
    local width=cam and cam.ViewportSize.X or 724
    if input.Position.X>width*.43 then
        hasRight[input]=input.Position
    end
end)
connect(UIS.TouchMoved,function(input)
    if not recording then return end
    local before=hasRight[input]
    if before then
        local d=input.Position-before
        local amount=d.Magnitude
        if amount>.05 and amount<100 then
            movedEvents=movedEvents+1
            movedPx=movedPx+amount
            lastMove=os.clock()
        end
        hasRight[input]=input.Position
    end
end)
connect(UIS.TouchEnded,function(input)hasRight[input]=nil end)
connect(Workspace:GetPropertyChangedSignal("CurrentCamera"),function()
    if recording then cameraTypeChanges=cameraTypeChanges+1 end
    attachCamera()
end)
connect(RunService.Heartbeat,function()
    if recording then
        frames=frames+1
        status.Text=string.format("GRAVANDO %.1f/10 s • mova camera e corpo",
            math.min(DURATION,os.clock()-startTime))
    end
end)
connect(copyBtn.Activated,function()
    if recording then
        status.Text="Ainda gravando; espere terminar"
        return
    end
    if not finished then status.Text="Toque INICIAR primeiro";return end
    local clip=(type(setclipboard)=="function" and setclipboard)
        or (type(toclipboard)=="function" and toclipboard)
    if clip then
        local ok=pcall(clip,report)
        if ok then status.Text="COPIADO • cole na conversa";return end
    end
    local modal=Instance.new("Frame")
    modal.Size=UDim2.new(.96,0,.92,0)
    modal.Position=UDim2.new(.02,0,.04,0)
    modal.BackgroundColor3=Color3.fromRGB(17,21,30)
    modal.ZIndex=10
    modal.Parent=gui
    local field=Instance.new("TextBox")
    field.Size=UDim2.new(1,-16,1,-54)
    field.Position=UDim2.fromOffset(8,8)
    field.Text=report
    field.MultiLine=true
    field.ClearTextOnFocus=false
    field.TextWrapped=false
    field.TextEditable=true
    field.TextColor3=Color3.new(1,1,1)
    field.BackgroundColor3=Color3.fromRGB(33,38,52)
    field.Font=Enum.Font.Code
    field.TextSize=11
    field.TextXAlignment=Enum.TextXAlignment.Left
    field.TextYAlignment=Enum.TextYAlignment.Top
    field.ZIndex=11
    field.Parent=modal
    local dismiss=Instance.new("TextButton")
    dismiss.Size=UDim2.fromOffset(85,37)
    dismiss.Position=UDim2.new(1,-95,1,-44)
    dismiss.Text="FECHAR"
    dismiss.TextColor3=Color3.new(1,1,1)
    dismiss.BackgroundColor3=Color3.fromRGB(140,56,78)
    dismiss.ZIndex=12
    dismiss.Parent=modal
    connect(dismiss.Activated,function()modal:Destroy() end)
    status.Text="Copie o relatorio manualmente."
end)

for _,s in ipairs(stages) do
    local name="MemeDashX11_"..tostring(player.UserId).."_"..s.name
    local stage=s
    local ok,err=pcall(function()
        RunService:BindToRenderStep(name,stage.priority,function()
            capture(stage)
        end)
    end)
    if ok then
        bindings[#bindings+1]=name
    else
        status.Text="Bind error: "..tostring(err)
        warn("[MemeDash X11] Bind error "..tostring(err))
    end
end
print("[MemeDash X11] Ready. Read-only. Click INICIAR then COPIAR.")
