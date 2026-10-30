-- MemeDash Sensibilidade V8: CONTROLADOR PROPRIO / iOS TOUCH
-- Experimental replacement, not a CFrame offset filter.
-- Based on X9 (0.917 deg/px at viewport height 375)
-- and X11 (original updates in priority window 199..201).
-- Only when multiplier ~= 1 and ON: temporarily disables the observed
-- Workspace.<player>.camera LocalScript, updates our camera at 199,
-- and retains Workspace.<player>.bodyrotation as-is.
-- No HumanoidRootPart CFrame changes, no speed or joystick changes.
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
    "__MemeDashSensitivityV7Cleanup",
    "__MemeDashSensitivityV6Cleanup",
    "__MemeDashCameraSensitivityCleanup",
    "__MemeDashSensitivityV8Cleanup"
}) do
    if type(ENV[key])=="function" then pcall(ENV[key]) end
end
local old=pg:FindFirstChild("MemeDashSensitivityV8")
if old then old:Destroy() end

local VERSION="8.0-controller-prototype"
local BASE_DEGREES_PER_PIXEL=0.9166666667
local MIN,MAX=0.1,2.0
local STEP_NAME="MemeDash_V8_OwnCamera_"..tostring(player.UserId)
local VERIFY_NAME="MemeDash_V8_ConflictCheck_"..tostring(player.UserId)
local connected={}
local bound=false
local verifying=false
local alive=true
local enabled=true
local multiplier=1.0
local invertX=false
local invertY=false
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
        release("Outro controlador escreveu camera depois do V8; OFF automatico")
    end
end

-- GUI
local gui=Instance.new("ScreenGui")
gui.Name="MemeDashSensitivityV8"
gui.ResetOnSpawn=false
gui.DisplayOrder=990000
gui.Parent=pg
local panel=Instance.new("Frame")
panel.Name="Panel"
panel.AnchorPoint=Vector2.new(.5,0)
panel.Position=UDim2.new(.5,0,.10,0)
panel.Size=UDim2.fromOffset(332,212)
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
local title=label("MEMEDASH • V8 CAMERA PROPRIA",
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
local state=label("1.0x = jogo original; ajuste X/Y se inverter",
    UDim2.new(.61,0,0,151),UDim2.new(.38,-8,0,52),10,
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
    flipX.Text=invertX and "X invertido" or "X normal"
    flipY.Text=invertY and "Y invertido" or "Y normal"
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
    for _,c in ipairs(connected) do pcall(function() c:Disconnect() end) end
    table.clear(connected)
    gui:Destroy()
    ENV.MemeDashSensitivityV8=nil
    if ENV.__MemeDashSensitivityV8Cleanup==cleanup then
        ENV.__MemeDashSensitivityV8Cleanup=nil
    end
end
ENV.__MemeDashSensitivityV8Cleanup=cleanup
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
ENV.MemeDashSensitivityV8={
    Version=VERSION,
    GetMultiplier=function() return multiplier end,
    SetMultiplier=function(v)
        multiplier=clampMultiplier(v)
        applySettings()
        refresh()
    end,
    GetStatus=function() return reason end,
    GetMetrics=function() return {
        customFrames=overrideFrames,conflicts=conflictFrames,
        touchPixels=touchPixels,rightFingers=trackedRightFingerCount,
        active=active,enabled=enabled
    } end,
    Cleanup=cleanup
}
refresh()
print("[MemeDash V8] Own camera controller. Select 0.5x/2x; OFF or 1x restores native script.")
return ENV.MemeDashSensitivityV8
