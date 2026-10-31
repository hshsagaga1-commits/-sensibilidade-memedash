-- MemeDash Sensibilidade V8.3: touch natural nos eixos X e Y + corpo sincronizado
-- Experimental replacement, not a CFrame offset filter.
-- Based on X9 (0.917 deg/px at viewport height 375)
-- and X11 (original updates in priority window 199..201).
-- Only when multiplier ~= 1 and ON: temporarily disables the observed
-- Workspace.<player>.camera LocalScript, updates our camera at 199,
-- and retains Workspace.<player>.bodyrotation as-is.
-- V8.3 adjusts BOTH camera axis signs so gestures match camera movement.
-- Camera right = finger right; camera left = finger left.
-- Camera up = finger up; camera down = finger down.
-- Retains body sync from V8.1. No forced +180 avatar facing.
-- Root position, translational velocity, WalkSpeed and joystick remain untouched.
-- OFF/X/1.0x restores the original camera LocalScript Enabled state.
-- Rejoin if the game's camera doesn't recover after re-enabling it.
-- NOTE: Some game-specific camera features will not be reproduced.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local player = Players.LocalPlayer
assert(player, "V8 requires client execution.")
assert(game.PlaceId == 134001816760598, "V8 is only for MemeDash.")
local pg = player:WaitForChild("PlayerGui")
local ENV = (type(getgenv) == "function" and getgenv()) or _G

-- Never run the old camera-offset experiments concurrently.
for _,key in ipairs({
    "__MemeDashSensitivityV83Cleanup",
    "__MemeDashSensitivityV82Cleanup",
    "__MemeDashSensitivityV81Cleanup",
    "__MemeDashSensitivityV8Cleanup",
    "__MemeDashSensitivityV7Cleanup",
    "__MemeDashSensitivityV6Cleanup",
    "__MemeDashCameraSensitivityCleanup"
}) do
    if type(ENV[key])=="function" then pcall(ENV[key]) end
end
local old=pg:FindFirstChild("MemeDashSensitivityV83")
if old then old:Destroy() end

local VERSION="8.3-camera-xy-natural-prototype"
local BASE_DEGREES_PER_PIXEL=0.9166666667
local MIN,MAX=0.1,2.0
local STEP_NAME="MemeDash_V83_OwnCamera_"..tostring(player.UserId)
local VERIFY_NAME="MemeDash_V83_ConflictCheck_"..tostring(player.UserId)
local SYNC_NAME="MemeDash_V83_RootYawSync_"..tostring(player.UserId)
local connected={}
local bound=false
local verifying=false
local syncBound=false
local alive=true
local enabled=true
local multiplier=1.0
-- The V8.2 user test showed BOTH camera axes reversed.
-- Explicit fix: change the sign of BOTH touch movement deltas.
-- Leave these as true by default to match requested natural directions.
local invertX=true
local invertY=true
local syncBody=true
-- The problem was with CAMERA, not the avatar facing.
-- Do not add a spurious 180-degree body-facing correction.
local flipBodyFacing=false
-- Independent option for the OTHER possible meaning of 'ao contrario':
-- avatar rotates left when camera rotates right.
local reverseBodyTurn=false
-- World yaw anchors avoid depending on potentially incorrect zero-offset.
local baseCameraYaw,baseBodyYaw=0,0
local rootYawOffset=0
local bodySyncTurns=0
local bodySyncErrors=0
local active=false
local nativeScript=nil
local nativeInitiallyEnabled=false
local trackedCamera=nil
local trackedRoot=nil
local yaw,pitch,roll=0,0,0
local rootInCameraSpace=Vector3.zero
local pendingX,pendingY=0,0
local touchPrev={}
local trackedRightFingerCount=0
local lastWrittenCF=nil
local overrideFrames=0
local conflictFrames=0
local touchPixels=0
local reason="1.0x = camera original (OFF automatico)"
local lastButtonUpdate=-1

local function connect(sig,fn)
    local conn=sig:Connect(fn)
    connected[#connected+1]=conn
    return conn
end
local function getRoot()
    local char=player.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end
local function findCameraScript()
    local folder=Workspace:FindFirstChild(player.Name)
    local scriptObj=folder and folder:FindFirstChild("camera")
    if scriptObj and scriptObj:IsA("LocalScript") then
        return scriptObj
    end
end
local function clampMultiplier(n)
    n=tonumber(n) or 1.0
    if n~=n then n=1.0 end
    return math.floor(math.clamp(n,MIN,MAX)*10+.5)/10
end
local function resetFingers()
    for k in pairs(touchPrev) do touchPrev[k]=nil end
    trackedRightFingerCount=0
    pendingX,pendingY=0,0
end
local function release(msg)
    active=false
    local oldScript=nativeScript
    local mustResume=nativeInitiallyEnabled
    nativeScript=nil
    nativeInitiallyEnabled=false
    trackedCamera=nil
    trackedRoot=nil
    rootYawOffset=0
    baseCameraYaw,baseBodyYaw=0,0
    lastWrittenCF=nil
    resetFingers()
    if oldScript and oldScript.Parent and mustResume then
        pcall(function() oldScript.Enabled=true end)
    end
    reason=msg or "ORIGINAL restaurada; pode demorar um frame"
end
local function takeover()
    if active or not enabled or multiplier==1.0 or not alive then return end
    local scriptObj=findCameraScript()
    local cam=Workspace.CurrentCamera
    local root=getRoot()
    if not cam or not root or not root:IsA("BasePart") then
        reason="Sem camera/raiz do personagem; V8 nao iniciou"
        return
    end
    if cam.CameraType~=Enum.CameraType.Scriptable then
        reason="Camera nao esta em Scriptable; V8 nao iniciou"
        return
    end
    if not scriptObj then
        reason="LocalScript camera nao foi encontrado; V8 nao iniciou"
        return
    end
    if not scriptObj.Enabled then
        reason="Camera original ja desativada pelo jogo; V8 nao iniciou"
        return
    end
    local cf=cam.CFrame
    local p,y,r=cf:ToOrientation()
    local relativeRoot=cf:PointToObjectSpace(root.Position)
    if relativeRoot.Magnitude>35 or relativeRoot.Magnitude<.05 then
        reason="Distancia camera/personagem incomum; V8 nao iniciou"
        return
    end
    yaw,pitch,roll=y,p,r
    -- Preserve the game's pre-existing camera-to-avatar facing offset.
    -- This makes sync face the same direction as the native camera did
    -- before we took control (instead of blindly assuming 0 degrees).
    local _,nativeBodyYaw = root.CFrame:ToOrientation()
    rootYawOffset=math.atan2(
        math.sin(nativeBodyYaw-yaw),math.cos(nativeBodyYaw-yaw))
    baseCameraYaw=yaw
    baseBodyYaw=nativeBodyYaw
    rootInCameraSpace=relativeRoot
    trackedCamera=cam
    trackedRoot=root
    nativeScript=scriptObj
    nativeInitiallyEnabled=true
    lastWrittenCF=nil
    pendingX,pendingY=0,0
    resetFingers()
    local ok,err=pcall(function()
        scriptObj.Enabled=false
    end)
    if not ok or scriptObj.Enabled then
        nativeScript=nil
        nativeInitiallyEnabled=false
        trackedCamera=nil
        trackedRoot=nil
        reason="Nao foi possivel suspender camera nativa: "..tostring(err)
        return
    end
    active=true
    reason=string.format("V8 PROPRIA ATIVA %.1fx • corpo intocado",multiplier)
end
local function applySettings()
    if not enabled or multiplier==1.0 then
        if active then
            release(enabled and "1.0x = camera nativa" or "OFF = camera nativa")
        else
            reason=enabled and "1.0x = camera nativa" or "OFF = camera nativa"
        end
    else
        if active then
            reason=string.format("V8 PROPRIA ATIVA %.1fx",multiplier)
        else
            takeover()
        end
    end
end
local function cfNear(a,b)
    if not a or not b then return false end
    if (a.Position-b.Position).Magnitude>.09 then return false end
    local delta=a.Rotation:ToObjectSpace(b.Rotation)
    local _,angle=delta:ToAxisAngle()
    return math.abs(angle)<math.rad(.5)
end
local function beforeNative(dt)
    if not active or not alive then return end
    local cam=Workspace.CurrentCamera
    local root=getRoot()
    local s=nativeScript
    if not cam or cam~=trackedCamera or cam.CameraType~=Enum.CameraType.Scriptable
        or not root or root~=trackedRoot or not s or not s.Parent then
        release("Mudanca de camera/personagem; V8 desligou")
        return
    end
    if s.Enabled then
        release("Jogo reativou camera nativa; V8 desligou")
        return
    end
    if dt and dt>.20 then
        pendingX,pendingY=0,0
    end
    local dX,dY=pendingX,pendingY
    pendingX,pendingY=0,0
    local viewportScale=375/math.max(200,cam.ViewportSize.Y)
    local radPerPixel=math.rad(BASE_DEGREES_PER_PIXEL*viewportScale*multiplier)
    yaw=yaw+dX*radPerPixel*(invertX and -1 or 1)
    pitch=math.clamp(pitch+dY*radPerPixel*(invertY and -1 or 1),
        math.rad(-80),math.rad(80))
    -- The root is used ONLY for position. Its yaw is never read here.
    -- Hence bodyrotation tracking the camera cannot feed back into our yaw.
    local rot=CFrame.fromOrientation(pitch,yaw,roll)
    local pos=root.Position-rot:VectorToWorldSpace(rootInCameraSpace)
    local out=CFrame.new(pos)*rot
    cam.CFrame=out
    cam.Focus=CFrame.new(root.Position)
    lastWrittenCF=out
    overrideFrames=overrideFrames+1
end
local function afterNative()
    if not active or not alive or not lastWrittenCF then return end
    local cam=Workspace.CurrentCamera
    if not cam or not cfNear(cam.CFrame,lastWrittenCF) then
        conflictFrames=conflictFrames+1
        release("Outro controlador escreveu camera depois do V8.1; OFF automatico")
    end
end

-- Rotate the existing character in world Y to follow the exact yaw produced
-- by our own camera controller. This is NOT V7's feedback loop:
-- the camera yaw is only advanced by touch; character yaw is never fed into it.
-- 205 comes AFTER the native camera/body window observed in X11 (199..201).
local function syncCharacterYaw()
    if not alive or not active or not enabled or not syncBody then return end
    local root=trackedRoot
    if not root or root~=getRoot() or root.Anchored then return end
    local character=player.Character
    local humanoid=character and character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health<=0 or humanoid.Sit
        or humanoid.SeatPart~=nil then return end
    if Workspace.CurrentCamera~=trackedCamera then return end
    local current=root.CFrame
    local _,currentYaw=current:ToOrientation()
    -- Track camera displacement relative to the moment V8.3 takes over.
    -- No root yaw feeds back into the touch-driven camera yaw.
    local inputYawDelta=yaw-baseCameraYaw
    local targetYaw=baseBodyYaw
        +inputYawDelta*(reverseBodyTurn and -1 or 1)
        +(flipBodyFacing and math.pi or 0)
    local delta=math.atan2(math.sin(targetYaw-currentYaw),
        math.cos(targetYaw-currentYaw))
    -- Skip tiny corrections to reduce unnecessary physics writes.
    if math.abs(delta)<math.rad(.10) then return end
    -- Retain world position AND existing pitch/roll; change only world yaw.
    -- Do not set Humanoid.AutoRotate, assembly velocity or movement input.
    local correction=CFrame.Angles(0,delta,0)
    root.CFrame=CFrame.new(current.Position)*correction*current.Rotation
    bodySyncTurns=bodySyncTurns+1
end

-- GUI
local gui=Instance.new("ScreenGui")
gui.Name="MemeDashSensitivityV83"
gui.ResetOnSpawn=false
gui.DisplayOrder=990000
gui.Parent=pg
local panel=Instance.new("Frame")
panel.Name="Panel"
panel.AnchorPoint=Vector2.new(.5,0)
panel.Position=UDim2.new(.5,0,.10,0)
panel.Size=UDim2.fromOffset(332,284)
panel.BackgroundColor3=Color3.fromRGB(21,26,37)
panel.BorderSizePixel=0
panel.Active=true
panel.Parent=gui
Instance.new("UICorner",panel).CornerRadius=UDim.new(0,11)

local function label(t,pos,size,fontSize,color)
    local l=Instance.new("TextLabel")
    l.Text=t
    l.BackgroundTransparency=1
    l.Position=pos
    l.Size=size
    l.TextXAlignment=Enum.TextXAlignment.Left
    l.TextYAlignment=Enum.TextYAlignment.Center
    l.TextWrapped=true
    l.Font=Enum.Font.Gotham
    l.TextSize=fontSize or 12
    l.TextColor3=color or Color3.new(1,1,1)
    l.Parent=panel
    return l
end
local title=label("MEMEDASH • V8.3 CAMERA NATURAL",
    UDim2.fromOffset(10,4),UDim2.new(1,-52,0,28),13,
    Color3.fromRGB(133,205,253))
title.Font=Enum.Font.GothamBold
local btnClose=Instance.new("TextButton")
btnClose.Text="X"
btnClose.TextColor3=Color3.new(1,1,1)
btnClose.BackgroundColor3=Color3.fromRGB(158,57,79)
btnClose.BorderSizePixel=0
btnClose.Position=UDim2.new(1,-43,0,5)
btnClose.Size=UDim2.fromOffset(36,29)
btnClose.Font=Enum.Font.GothamBold
btnClose.TextSize=14
btnClose.Parent=panel
Instance.new("UICorner",btnClose).CornerRadius=UDim.new(0,8)
local value=label("1.0x • CAMERA ORIGINAL",
    UDim2.fromOffset(10,36),UDim2.new(1,-20,0,34),17)
value.Font=Enum.Font.GothamBold
local track=Instance.new("Frame")
track.Position=UDim2.fromOffset(17,81)
track.Size=UDim2.new(1,-34,0,9)
track.BackgroundColor3=Color3.fromRGB(64,77,99)
track.BorderSizePixel=0
track.Active=true
track.Parent=panel
Instance.new("UICorner",track).CornerRadius=UDim.new(1,0)
local fill=Instance.new("Frame")
fill.BackgroundColor3=Color3.fromRGB(69,169,248)
fill.BorderSizePixel=0
fill.Parent=track
Instance.new("UICorner",fill).CornerRadius=UDim.new(1,0)
local knob=Instance.new("Frame")
knob.Size=UDim2.fromOffset(20,20)
knob.AnchorPoint=Vector2.new(.5,.5)
knob.BackgroundColor3=Color3.new(1,1,1)
knob.BorderSizePixel=0
knob.Active=true
knob.Parent=track
Instance.new("UICorner",knob).CornerRadius=UDim.new(1,0)
label("0.1x",UDim2.fromOffset(15,96),UDim2.fromOffset(45,17),10,
    Color3.fromRGB(165,176,193))
label("2.0x",UDim2.new(1,-55,0,96),UDim2.fromOffset(42,17),10,
    Color3.fromRGB(165,176,193))

local function button(txt,x,w,col)
    local b=Instance.new("TextButton")
    b.Text=txt
    b.Font=Enum.Font.GothamBold
    b.TextSize=11
    b.TextColor3=Color3.new(1,1,1)
    b.BackgroundColor3=col
    b.BorderSizePixel=0
    b.Size=UDim2.new(w,-4,0,30)
    b.Position=UDim2.new(x,0,0,118)
    b.Parent=panel
    Instance.new("UICorner",b).CornerRadius=UDim.new(0,7)
    return b
end
local b01=button("0.1x",.025,.19,Color3.fromRGB(67,80,104))
local b05=button("0.5x",.225,.19,Color3.fromRGB(67,80,104))
local b10=button("1.0x",.425,.19,Color3.fromRGB(67,80,104))
local b20=button("2.0x",.625,.19,Color3.fromRGB(67,80,104))
local toggle=button("ON",.825,.16,Color3.fromRGB(29,136,102))
local flipX=button("X normal",.025,.28,Color3.fromRGB(65,79,103))
flipX.Position=UDim2.new(.025,0,0,153)
local flipY=button("Y normal",.315,.28,Color3.fromRGB(65,79,103))
flipY.Position=UDim2.new(.315,0,0,153)
local syncBtn=button("CORPO ON",.025,.29,Color3.fromRGB(29,136,102))
syncBtn.Position=UDim2.new(.025,0,0,190)
local facingBtn=button("FRENTE +180",.325,.30,Color3.fromRGB(47,114,178))
facingBtn.Position=UDim2.new(.325,0,0,190)
local directionBtn=button("GIRO NORMAL",.635,.34,Color3.fromRGB(67,80,104))
directionBtn.Position=UDim2.new(.635,0,0,190)
local instructions=label("X/Y normal: direita-direita e cima-cima. FRENTE 0 sem giro extra.",
    UDim2.fromOffset(10,226),UDim2.new(1,-20,0,23),10,
    Color3.fromRGB(185,202,224))
local state=label("V8.3: eixos corrigidos",
    UDim2.fromOffset(10,249),UDim2.new(1,-20,0,31),10,
    Color3.fromRGB(181,205,229))

local function refresh()
    if not alive then return end
    local frac=(multiplier-MIN)/(MAX-MIN)
    fill.Size=UDim2.new(frac,0,1,0)
    knob.Position=UDim2.new(frac,0,.5,0)
    value.Text=string.format("%.1fx • %s",multiplier,
        active and "CAMERA V8" or "JOGO ORIGINAL")
    toggle.Text=enabled and "ON" or "OFF"
    toggle.BackgroundColor3=enabled and Color3.fromRGB(29,136,102)
        or Color3.fromRGB(144,61,74)
    -- UI describes what the PLAYER sees, not the internal arithmetic sign.
    flipX.Text=invertX and "X normal" or "X invertido"
    flipY.Text=invertY and "Y normal" or "Y invertido"
    syncBtn.Text=syncBody and "CORPO ON" or "CORPO OFF"
    syncBtn.BackgroundColor3=syncBody and Color3.fromRGB(29,136,102)
        or Color3.fromRGB(144,61,74)
    facingBtn.Text=flipBodyFacing and "FRENTE +180" or "FRENTE 0"
    facingBtn.BackgroundColor3=flipBodyFacing and Color3.fromRGB(47,114,178)
        or Color3.fromRGB(67,80,104)
    directionBtn.Text=reverseBodyTurn and "GIRO INV" or "GIRO NORMAL"
    directionBtn.BackgroundColor3=reverseBodyTurn and Color3.fromRGB(47,114,178)
        or Color3.fromRGB(67,80,104)
    state.Text=reason
end
local movingSlider, sliderInput=false,nil
local dragging, dragInput, dragStart, panelStart=false,nil,nil,nil
local function pickSlider(x)
    local width=track.AbsoluteSize.X
    if width<=0 then return end
    local f=math.clamp((x-track.AbsolutePosition.X)/width,0,1)
    local n=clampMultiplier(MIN+f*(MAX-MIN))
    if n~=multiplier then
        multiplier=n
        applySettings()
    end
    refresh()
end
local function sliderBegin(input)
    if input.UserInputType==Enum.UserInputType.Touch
        or input.UserInputType==Enum.UserInputType.MouseButton1 then
        movingSlider,sliderInput=true,input
        pickSlider(input.Position.X)
    end
end
connect(track.InputBegan,sliderBegin)
connect(knob.InputBegan,sliderBegin)
connect(title.InputBegan,function(input)
    if input.UserInputType==Enum.UserInputType.Touch
        or input.UserInputType==Enum.UserInputType.MouseButton1 then
        dragging,dragInput,dragStart,panelStart=true,input,input.Position,panel.Position
    end
end)
connect(UIS.InputChanged,function(input)
    if movingSlider and input==sliderInput then
        pickSlider(input.Position.X)
    end
    if dragging and input==dragInput then
        local d=input.Position-dragStart
        panel.Position=UDim2.new(panelStart.X.Scale,panelStart.X.Offset+d.X,
            panelStart.Y.Scale,panelStart.Y.Offset+d.Y)
    end
end)
connect(UIS.InputEnded,function(input)
    if input==sliderInput then movingSlider,sliderInput=false,nil end
    if input==dragInput then
        dragging,dragInput,dragStart,panelStart=false,nil,nil,nil
    end
end)
for _,v in ipairs({{b01,.1},{b05,.5},{b10,1},{b20,2}}) do
    connect(v[1].Activated,function()
        multiplier=v[2]
        applySettings()
        refresh()
    end)
end
connect(toggle.Activated,function()
    enabled=not enabled
    applySettings()
    refresh()
end)
connect(flipX.Activated,function() invertX=not invertX; refresh() end)
connect(flipY.Activated,function() invertY=not invertY; refresh() end)
connect(syncBtn.Activated,function()
    syncBody=not syncBody
    reason=syncBody and "CORPO ON: sincronizando yaw" or
        "CORPO OFF: so camera muda"
    refresh()
end)
connect(facingBtn.Activated,function()
    -- Explicitly reverse avatar-facing by 180 degrees.
    flipBodyFacing=not flipBodyFacing
    reason=flipBodyFacing and "FRENTE +180: personagem invertido corrigido"
        or "FRENTE 0: alinhamento V8.1"
    refresh()
end)
connect(directionBtn.Activated,function()
    -- Rebase around CURRENT camera/body to avoid a sudden 2*angle snap
    -- when changing turn direction mid-game.
    if active then
        local root=getRoot()
        if root then
            local _,currentBodyYaw=root.CFrame:ToOrientation()
            baseCameraYaw=yaw
            baseBodyYaw=currentBodyYaw-(flipBodyFacing and math.pi or 0)
        end
    end
    reverseBodyTurn=not reverseBodyTurn
    reason=reverseBodyTurn and "GIRO INV: corpo vira no sentido contrario"
        or "GIRO NORMAL: corpo segue o sentido da camera"
    refresh()
end)

local function panelContains(pos)
    local p,s=panel.AbsolutePosition,panel.AbsoluteSize
    return pos.X>=p.X and pos.X<=p.X+s.X and pos.Y>=p.Y and pos.Y<=p.Y+s.Y
end
connect(UIS.TouchStarted,function(input)
    if not active or panelContains(input.Position) then return end
    local cam=Workspace.CurrentCamera
    local width=cam and cam.ViewportSize.X or 724
    if input.Position.X>width*.43 then
        touchPrev[input]=input.Position
        trackedRightFingerCount=trackedRightFingerCount+1
    end
end)
connect(UIS.TouchMoved,function(input)
    if not active then return end
    local before=touchPrev[input]
    if before then
        local change=input.Position-before
        touchPrev[input]=input.Position
        local dist=change.Magnitude
        if dist>.05 and dist<120 then
            pendingX=pendingX+change.X
            pendingY=pendingY+change.Y
            touchPixels=touchPixels+dist
        end
    end
end)
connect(UIS.TouchEnded,function(input)
    if touchPrev[input] then
        touchPrev[input]=nil
        trackedRightFingerCount=math.max(0,trackedRightFingerCount-1)
    end
end)

local function cleanup()
    if not alive then return end
    release("Fechado; cam original restaurada")
    alive=false
    if bound then
        pcall(function() RunService:UnbindFromRenderStep(STEP_NAME) end)
    end
    if verifying then
        pcall(function() RunService:UnbindFromRenderStep(VERIFY_NAME) end)
    end
    if syncBound then
        pcall(function() RunService:UnbindFromRenderStep(SYNC_NAME) end)
    end
    for _,c in ipairs(connected) do pcall(function() c:Disconnect() end) end
    table.clear(connected)
    gui:Destroy()
    ENV.MemeDashSensitivityV83=nil
    if ENV.__MemeDashSensitivityV83Cleanup==cleanup then
        ENV.__MemeDashSensitivityV83Cleanup=nil
    end
end
ENV.__MemeDashSensitivityV83Cleanup=cleanup
connect(btnClose.Activated,cleanup)

local a,errA=pcall(function()
    RunService:BindToRenderStep(STEP_NAME,199,function(dt)
        local ok,err=pcall(beforeNative,dt)
        if not ok then
            release("Erro no controlador V8: "..tostring(err))
        end
    end)
end)
bound=a
local b,errB=pcall(function()
    RunService:BindToRenderStep(VERIFY_NAME,201,function()
        local ok,err=pcall(afterNative)
        if not ok then
            release("Erro na verificacao V8: "..tostring(err))
        end
    end)
end)
verifying=b
local syncOk,syncErr=pcall(function()
    RunService:BindToRenderStep(SYNC_NAME,205,function()
        local ok,err=pcall(syncCharacterYaw)
        if not ok then
            bodySyncErrors=bodySyncErrors+1
            syncBody=false
            reason="Erro BODY SYNC; camera preservada: "..tostring(err)
            warn("[MemeDash V8.1] "..reason)
        end
    end)
end)
syncBound=syncOk
if not syncOk then
    syncBody=false
    reason="Corpo OFF: falha prioridade 205: "..tostring(syncErr)
end
if not a or not b then
    enabled=false
    reason="Falha bind 199/201; V8 desativada: "..tostring(errA or errB)
end
connect(RunService.Heartbeat,function()
    if not alive then return end
    local now=os.clock()
    if now-lastButtonUpdate>.3 then
        lastButtonUpdate=now
        refresh()
    end
end)
ENV.MemeDashSensitivityV83={
    Version=VERSION,
    GetMultiplier=function() return multiplier end,
    SetMultiplier=function(v)
        multiplier=clampMultiplier(v)
        applySettings()
        refresh()
    end,
    GetStatus=function() return reason end,
    GetBodySync=function() return syncBody end,
    SetBodySync=function(v)
        syncBody=(v~=false) and syncBound
        reason=syncBody and "CORPO ON" or "CORPO OFF"
        refresh()
    end,
    GetBodyFacing180=function() return flipBodyFacing end,
    SetBodyFacing180=function(v)
        flipBodyFacing=(v==true)
        reason=flipBodyFacing and "FRENTE +180" or "FRENTE 0"
        refresh()
    end,
    GetBodyTurnReversed=function() return reverseBodyTurn end,
    GetMetrics=function() return {
        customFrames=overrideFrames,conflicts=conflictFrames,
        touchPixels=touchPixels,rightFingers=trackedRightFingerCount,
        active=active,enabled=enabled,bodySyncEnabled=syncBody,
        bodySyncTurns=bodySyncTurns,bodySyncErrors=bodySyncErrors,
        rootYawOffsetDegrees=math.deg(rootYawOffset),
        facing180=flipBodyFacing,turnReversed=reverseBodyTurn
    } end,
    Cleanup=cleanup
}
refresh()
print("[MemeDash V8.3] Camera X/Y signs corrected by default; body follows camera, no +180 default.")
return ENV.MemeDashSensitivityV83
