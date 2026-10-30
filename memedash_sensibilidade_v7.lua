-- MemeDash Sensibilidade V7 - CAMERA ONLY / TWO PASS
-- Experimental test based on X9 v2 telemetry.
-- X9 v2 found that the body may rotate independently from camera.
-- V7 NEVER CHANGES HumanoidRootPart, WalkSpeed, jump or joystick.
-- It restores the unmodified camera BEFORE the game runs its next
-- camera update, and applies only a bounded visual angle correction AFTER.
-- Important: custom game controller order is unknown, so not guaranteed.

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local player = Players.LocalPlayer
assert(player, "Execute no cliente.")
assert(game.PlaceId == 134001816760598, "Esta versao e apenas para o MemeDash.")
local pg = player:WaitForChild("PlayerGui")
local ENV = (type(getgenv) == "function" and getgenv()) or _G

-- Avoid old modifiers (reload the place if the camera was already broken).
for _, key in ipairs({"__MemeDashCameraSensitivityCleanup",
                      "__MemeDashSensitivityV6Cleanup",
                      "__MemeDashSensitivityV7Cleanup"}) do
    if type(ENV[key]) == "function" then pcall(ENV[key]) end
end
for _, name in ipairs({"MemeDashCameraSensitivityGui",
                       "MemeDashSensitivityV6",
                       "MemeDashSensitivityV7"}) do
    local old = pg:FindFirstChild(name)
    if old then pcall(function() old:Destroy() end) end
end

local NAME_PRE = "MemeDashSensV7_pre_" .. tostring(player.UserId)
local NAME_POST = "MemeDashSensV7_post_" .. tostring(player.UserId)
local boundPre, boundPost = false, false
local alive, enabled = true, true
local multiplier = 1.0
local MIN, MAX, STEP = .1, 2.0, .1
local LIMIT_YAW = math.rad(65)
local LIMIT_PITCH = math.rad(32)
local connections = {}
local uiClock = 0
local nativeCam, outputCam, trackedCamera, trackedCharacter = nil,nil,nil,nil
local rawYaw, rawPitch = nil, nil
local visualYawOffset, visualPitchOffset = 0,0
local renderedFrames, restoreFrames, lostRestore, safetyResets, cappedFrames = 0,0,0,0,0
local validFrame, outputApplied = false, false
local lastRightMove = -100
local fingerRight = {}
local fingerPixels = 0
local infoText = "1.0x ORIGINAL • aguardando camera"
local function connect(signal, callback)
    local c = signal:Connect(callback)
    connections[#connections+1] = c
    return c
end
local function wrapped(a)
    return math.atan2(math.sin(a), math.cos(a))
end
local function closeEnough(cfA, cfB)
    if not cfA or not cfB then return false end
    if (cfA.Position-cfB.Position).Magnitude > .035 then return false end
    local delta = cfA.Rotation:ToObjectSpace(cfB.Rotation)
    local _, a = delta:ToAxisAngle()
    return math.abs(a) < .012
end
local function clearState(message, clearOffset)
    nativeCam, outputCam = nil,nil
    trackedCamera, trackedCharacter = nil,nil
    rawYaw, rawPitch = nil,nil
    outputApplied, validFrame = false,false
    if clearOffset then
        visualYawOffset,visualPitchOffset = 0,0
        safetyResets=safetyResets+1
    end
    if message then infoText=message end
end
local function restoreNow()
    if nativeCam and outputCam and trackedCamera == Workspace.CurrentCamera
        and closeEnough(trackedCamera.CFrame,outputCam) then
        trackedCamera.CFrame = nativeCam
    end
    nativeCam,outputCam=nil,nil
    outputApplied=false
end
local function setMultiplier(n)
    restoreNow()
    local v = math.clamp(tonumber(n) or 1,MIN,MAX)
    multiplier = math.floor(math.floor(v/STEP+.5)*STEP*10+.5)/10
    clearState("AJUSTE "..string.format("%.1fx",multiplier),true)
end

local gui = Instance.new("ScreenGui")
gui.Name="MemeDashSensitivityV7"
gui.ResetOnSpawn=false
gui.IgnoreGuiInset=false
gui.DisplayOrder=990000
gui.Parent=pg

local frame=Instance.new("Frame")
frame.Name="Panel"
frame.Size=UDim2.fromOffset(315,198)
frame.AnchorPoint=Vector2.new(.5,0)
frame.Position=UDim2.new(.5,0,.12,0)
frame.BackgroundColor3=Color3.fromRGB(19,24,34)
frame.BorderSizePixel=0
frame.Active=true
frame.Parent=gui
Instance.new("UICorner",frame).CornerRadius=UDim.new(0,11)

local function textLabel(t,p,s,z,col)
    local l=Instance.new("TextLabel")
    l.Position=p
    l.Size=s
    l.BackgroundTransparency=1
    l.Text=t
    l.TextColor3=col or Color3.new(1,1,1)
    l.TextSize=z
    l.Font=Enum.Font.Gotham
    l.TextXAlignment=Enum.TextXAlignment.Left
    l.TextWrapped=true
    l.Parent=frame
    return l
end
local header=textLabel("MEMEDASH • SENS V7 TESTE",UDim2.fromOffset(10,5),
    UDim2.new(1,-65,0,28),13,Color3.fromRGB(137,209,255))
header.Font=Enum.Font.GothamBold

local close=Instance.new("TextButton")
close.Size=UDim2.fromOffset(37,29)
close.Position=UDim2.new(1,-43,0,5)
close.Text="X"
close.TextColor3=Color3.new(1,1,1)
close.BackgroundColor3=Color3.fromRGB(156,65,79)
close.BorderSizePixel=0
close.Font=Enum.Font.GothamBold
close.TextSize=15
close.Parent=frame
Instance.new("UICorner",close).CornerRadius=UDim.new(0,7)

local number=textLabel("1.0x • ORIGINAL",UDim2.fromOffset(10,37),
    UDim2.new(1,-20,0,30),18)
number.Font=Enum.Font.GothamBold

local bar=Instance.new("Frame")
bar.Name="Slider"
bar.Position=UDim2.fromOffset(14,77)
bar.Size=UDim2.new(1,-28,0,9)
bar.BackgroundColor3=Color3.fromRGB(67,78,98)
bar.BorderSizePixel=0
bar.Active=true
bar.Parent=frame
Instance.new("UICorner",bar).CornerRadius=UDim.new(1,0)
local fill=Instance.new("Frame")
fill.Size=UDim2.new(0,0,1,0)
fill.BackgroundColor3=Color3.fromRGB(82,176,250)
fill.BorderSizePixel=0
fill.Parent=bar
Instance.new("UICorner",fill).CornerRadius=UDim.new(1,0)
local knob=Instance.new("Frame")
knob.AnchorPoint=Vector2.new(.5,.5)
knob.Size=UDim2.fromOffset(19,19)
knob.Position=UDim2.new(0,0,.5,0)
knob.BackgroundColor3=Color3.new(1,1,1)
knob.BorderSizePixel=0
knob.Active=true
knob.Parent=bar
Instance.new("UICorner",knob).CornerRadius=UDim.new(1,0)

textLabel("0.1x",UDim2.fromOffset(14,92),UDim2.fromOffset(38,17),10,
    Color3.fromRGB(164,175,192))
textLabel("2.0x",UDim2.new(1,-53,0,92),UDim2.fromOffset(39,17),10,
    Color3.fromRGB(164,175,192))

local function button(txt, pos, width, color)
    local b=Instance.new("TextButton")
    b.Size=UDim2.new(width,0,0,31)
    b.Position=pos
    b.Text=txt
    b.TextColor3=Color3.new(1,1,1)
    b.BackgroundColor3=color
    b.BorderSizePixel=0
    b.TextSize=11
    b.Font=Enum.Font.GothamBold
    b.Parent=frame
    Instance.new("UICorner",b).CornerRadius=UDim.new(0,7)
    return b
end
local b05=button("0.5x",UDim2.new(.035,0,0,116),.205,Color3.fromRGB(66,77,101))
local b10=button("1.0x",UDim2.new(.265,0,0,116),.205,Color3.fromRGB(66,77,101))
local b20=button("2.0x",UDim2.new(.495,0,0,116),.205,Color3.fromRGB(66,77,101))
local bOff=button("ON",UDim2.new(.725,0,0,116),.24,Color3.fromRGB(35,130,94))
local status=textLabel("CAMERA ORIGINAL • sem alteracoes",
    UDim2.fromOffset(10,156),UDim2.new(1,-20,0,35),10,
    Color3.fromRGB(173,198,216))

local function updateUI()
    if not alive then return end
    local a=(multiplier-MIN)/(MAX-MIN)
    fill.Size=UDim2.new(a,0,1,0)
    knob.Position=UDim2.new(a,0,.5,0)
    number.Text=string.format("%.1fx",multiplier)..
        (multiplier==1 and " • ORIGINAL" or " • EXPERIMENTAL")
    bOff.Text=enabled and "ON" or "OFF"
    bOff.BackgroundColor3=enabled and Color3.fromRGB(35,130,94)
        or Color3.fromRGB(144,59,74)
    status.Text=infoText
end

local sliding, slideInput = false,nil
local dragging,dragInput,dragStart,panelStart=false,nil,nil,nil
local function slideAt(x)
    if bar.AbsoluteSize.X<1 then return end
    local fraction=math.clamp((x-bar.AbsolutePosition.X)/bar.AbsoluteSize.X,0,1)
    local target=math.floor((MIN+(MAX-MIN)*fraction)*10+.5)/10
    if target~=multiplier then setMultiplier(target) end
    updateUI()
end
local function beginSlide(input)
    if input.UserInputType==Enum.UserInputType.Touch
        or input.UserInputType==Enum.UserInputType.MouseButton1 then
        sliding,slideInput=true,input
        slideAt(input.Position.X)
    end
end
connect(bar.InputBegan,beginSlide)
connect(knob.InputBegan,beginSlide)
connect(header.InputBegan,function(input)
    if input.UserInputType==Enum.UserInputType.Touch
        or input.UserInputType==Enum.UserInputType.MouseButton1 then
        dragging,dragInput,dragStart,panelStart=true,input,input.Position,frame.Position
    end
end)
connect(UIS.InputChanged,function(input)
    local mouse=input.UserInputType==Enum.UserInputType.MouseMovement
    if sliding and (input==slideInput or
        (mouse and slideInput and slideInput.UserInputType==Enum.UserInputType.MouseButton1)) then
        slideAt(input.Position.X)
    end
    if dragging and dragStart and (input==dragInput or
        (mouse and dragInput and dragInput.UserInputType==Enum.UserInputType.MouseButton1)) then
        local d=input.Position-dragStart
        frame.Position=UDim2.new(panelStart.X.Scale,panelStart.X.Offset+d.X,
            panelStart.Y.Scale,panelStart.Y.Offset+d.Y)
    end
end)
connect(UIS.InputEnded,function(input)
    if input==slideInput or (slideInput and
        slideInput.UserInputType==Enum.UserInputType.MouseButton1 and
        input.UserInputType==Enum.UserInputType.MouseButton1) then
        sliding,slideInput=false,nil
    end
    if input==dragInput or (dragInput and
        dragInput.UserInputType==Enum.UserInputType.MouseButton1 and
        input.UserInputType==Enum.UserInputType.MouseButton1) then
        dragging,dragInput,dragStart,panelStart=false,nil,nil,nil
    end
end)

local function inPanel(pos)
    local p,s=frame.AbsolutePosition,frame.AbsoluteSize
    return pos.X>=p.X and pos.X<=p.X+s.X and pos.Y>=p.Y and pos.Y<=p.Y+s.Y
end
connect(UIS.TouchStarted,function(input)
    if inPanel(input.Position) then return end
    local cam=Workspace.CurrentCamera
    local w=cam and cam.ViewportSize.X or 724
    if input.Position.X>w*.43 then fingerRight[input]=input.Position end
end)
connect(UIS.TouchMoved,function(input)
    local prev=fingerRight[input]
    if prev then
        local d=input.Position-prev
        if d.Magnitude>.3 and d.Magnitude<100 then
            lastRightMove=os.clock()
            fingerPixels=fingerPixels+d.Magnitude
        end
        fingerRight[input]=input.Position
    end
end)
connect(UIS.TouchEnded,function(input)
    fingerRight[input]=nil
end)

local function hasRecentFingerMove()
    return os.clock()-lastRightMove < .1
end
local function beforeCamera()
    if not alive or not enabled or multiplier==1 then return end
    if not outputApplied then return end
    local camera=Workspace.CurrentCamera
    if camera~=trackedCamera or not nativeCam or not outputCam then
        clearState("CAMERA SUBSTITUIDA • reset",true)
        return
    end
    if closeEnough(camera.CFrame,outputCam) then
        camera.CFrame=nativeCam
        restoreFrames=restoreFrames+1
        validFrame=true
    else
        -- Some other system wrote the camera after our last pass.
        lostRestore=lostRestore+1
        clearState("OUTRO CONTROLADOR MUDOU CAMERA • reset",true)
    end
    outputApplied=false
end

local function afterCamera(dt)
    if not alive or not enabled or multiplier==1 then return end
    local camera=Workspace.CurrentCamera
    local character=player.Character
    if not camera or camera.CameraType~=Enum.CameraType.Scriptable then
        clearState("Aguardando camera Scriptable",true)
        return
    end
    local raw=camera.CFrame
    local pitch,yaw,roll=raw:ToOrientation()
    if camera~=trackedCamera or character~=trackedCharacter or rawYaw==nil then
        trackedCamera,trackedCharacter=camera,character
        rawYaw,rawPitch=yaw,pitch
        nativeCam=raw
        outputCam=nil
        outputApplied=false
        infoText="V7 sincronizada • movimenta a camera"
        return
    end
    if dt<=0 or dt>.12 then
        clearState("LAG/PAUSA • reset seguro",true)
        return
    end
    local dYaw=wrapped(yaw-rawYaw)
    local dPitch=wrapped(pitch-rawPitch)
    if math.abs(dYaw)>math.rad(22) or math.abs(dPitch)>math.rad(16)
        or (nativeCam and (raw.Position-nativeCam.Position).Magnitude>8) then
        clearState("GIRO BRUSCO/TELEPORTE • reset seguro",true)
        return
    end

    -- Original camera receives game input; only its own measured delta is scaled.
    -- No root writes, and no serial correction of an already-modified CFrame.
    if hasRecentFingerMove() then
        visualYawOffset=math.clamp(visualYawOffset+dYaw*(multiplier-1),
            -LIMIT_YAW,LIMIT_YAW)
        visualPitchOffset=math.clamp(visualPitchOffset+dPitch*(multiplier-1),
            -LIMIT_PITCH,LIMIT_PITCH)
    end
    if math.abs(visualYawOffset)>=LIMIT_YAW-.001
        or math.abs(visualPitchOffset)>=LIMIT_PITCH-.001 then
        cappedFrames=cappedFrames+1
    end
    rawYaw,rawPitch=yaw,pitch
    nativeCam=raw

    local outPitch=math.clamp(pitch+visualPitchOffset,
        math.rad(-82),math.rad(82))
    local outYaw=wrapped(yaw+visualYawOffset)
    local output=CFrame.new(raw.Position)*CFrame.fromOrientation(outPitch,outYaw,roll)
    local _,angle=(raw.Rotation:ToObjectSpace(output.Rotation)):ToAxisAngle()
    if math.abs(angle)>math.rad(75) then
        clearState("ANGULO LIMITE • reset",true)
        return
    end
    camera.CFrame=output
    outputCam=output
    outputApplied=true
    renderedFrames=renderedFrames+1
    if cappedFrames>0 and renderedFrames%20==0 then
        infoText="LIMITADO (65/32 graus) • FPS normal"
    elseif renderedFrames%20==0 then
        infoText=string.format("ATIVO %.1fx | restore %d | reset %d",
            multiplier,restoreFrames,safetyResets)
    end
end

local function cleanup()
    if not alive then return end
    restoreNow()
    alive,enabled=false,false
    if boundPre then
        pcall(function() RunService:UnbindFromRenderStep(NAME_PRE) end)
    end
    if boundPost then
        pcall(function() RunService:UnbindFromRenderStep(NAME_POST) end)
    end
    for _,c in ipairs(connections) do pcall(function() c:Disconnect() end) end
    table.clear(connections)
    gui:Destroy()
    ENV.MemeDashSensitivityV7=nil
    if ENV.__MemeDashSensitivityV7Cleanup==cleanup then
        ENV.__MemeDashSensitivityV7Cleanup=nil
    end
end
ENV.__MemeDashSensitivityV7Cleanup=cleanup
connect(close.Activated,cleanup)
connect(bOff.Activated,function()
    if enabled then restoreNow() end
    enabled=not enabled
    clearState(enabled and "ON • sincronizando" or "OFF • camera original",true)
    updateUI()
end)
for _,item in ipairs({{b05,.5},{b10,1.0},{b20,2.0}}) do
    connect(item[1].Activated,function()
        setMultiplier(item[2])
        updateUI()
    end)
end

local okPre,errPre=pcall(function()
    RunService:BindToRenderStep(NAME_PRE,
        Enum.RenderPriority.First.Value-10,beforeCamera)
end)
boundPre=okPre
local okPost,errPost=pcall(function()
    RunService:BindToRenderStep(NAME_POST,
        Enum.RenderPriority.Last.Value+100,afterCamera)
end)
boundPost=okPost
if not okPre or not okPost then
    infoText="FALHA DE INICIALIZACAO • codigo desativado"
    enabled=false
    if boundPre then pcall(function() RunService:UnbindFromRenderStep(NAME_PRE) end) end
    if boundPost then pcall(function() RunService:UnbindFromRenderStep(NAME_POST) end) end
    warn("[MemeDash V7] Bind failure: "..tostring(errPre).." | "..tostring(errPost))
end
connect(RunService.Heartbeat,function(dt)
    uiClock=uiClock+dt
    if uiClock>=.3 then
        uiClock=0
        updateUI()
    end
end)
ENV.MemeDashSensitivityV7={
    Version="7.0-prototype",
    SetMultiplier=function(v) setMultiplier(v);updateUI() end,
    GetMultiplier=function() return multiplier end,
    SetEnabled=function(v)
        if not v then restoreNow() end
        enabled=v~=false
        clearState(enabled and "ON" or "OFF",true)
        updateUI()
    end,
    GetStatus=function() return infoText end,
    GetMetrics=function()
        return {
            visualFrames=renderedFrames,
            nativeCameraRestores=restoreFrames,
            restoreConflicts=lostRestore,
            safetyResets=safetyResets,
            limitFrames=cappedFrames,
            capturedFingerPixels=fingerPixels
        }
    end,
    Cleanup=cleanup
}
updateUI()
print("[MemeDash V7] Camera-only, two-pass, safe bounds. Start at 1x.")
return ENV.MemeDashSensitivityV7
