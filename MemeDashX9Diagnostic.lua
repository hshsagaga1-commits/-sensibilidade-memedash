-- MEMEDASH X9 v2.0 - camera + touch forensic diagnostic
-- Read-only: never writes Camera.CFrame, HumanoidRootPart.CFrame or game controls.
-- Based on X9 v1 and the reported unstable sensitivity V6 video.
-- To prevent data loss, the original is backed up as MemeDashX9Diagnostic_v1.lua.

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local player = Players.LocalPlayer
assert(player, "Run on the client")
local pg = player:WaitForChild("PlayerGui")
local ENV = (type(getgenv) == "function" and getgenv()) or _G

if type(ENV.__MemeDashX9Cleanup) == "function" then
    pcall(ENV.__MemeDashX9Cleanup)
end
local stale = pg:FindFirstChild("MemeDashX9Diagnostic")
if stale then stale:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name = "MemeDashX9Diagnostic"
gui.DisplayOrder = 998000
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.Parent = pg

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(.5, 0)
panel.Position = UDim2.new(.5, 0, .08, 0)
panel.Size = UDim2.fromOffset(350, 193)
panel.BackgroundColor3 = Color3.fromRGB(17, 22, 33)
panel.BorderSizePixel = 0
panel.Active = true
panel.Parent = gui
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 11)

local constraint = Instance.new("UISizeConstraint")
constraint.MaxSize = Vector2.new(350, 193)
constraint.MinSize = Vector2.new(275, 193)
constraint.Parent = panel

local function label(value, y, h, fontSize, color)
    local v = Instance.new("TextLabel")
    v.Position = UDim2.fromOffset(10, y)
    v.Size = UDim2.new(1, -20, 0, h)
    v.BackgroundTransparency = 1
    v.TextXAlignment = Enum.TextXAlignment.Left
    v.TextYAlignment = Enum.TextYAlignment.Center
    v.TextWrapped = true
    v.Font = Enum.Font.Gotham
    v.TextSize = fontSize
    v.TextColor3 = color or Color3.fromRGB(230,236,250)
    v.Text = value
    v.Parent = panel
    return v
end
local heading = label("MEMEDASH X9 v2 • CAMERA LAB", 7, 27, 14, Color3.fromRGB(134,205,255))
heading.Font = Enum.Font.GothamBold
local guide = label("12s: arraste a camera para os lados e para cima/baixo. Solte o dedo varias vezes.", 35, 42, 11)
local status = label("PRONTO • somente leitura", 80, 27, 12, Color3.fromRGB(142,236,177))

local function button(value, fraction, color)
    local b = Instance.new("TextButton")
    b.Position = UDim2.new(fraction, 0, 0, 119)
    b.Size = UDim2.new(.306, -4, 0, 34)
    b.BackgroundColor3 = color
    b.BorderSizePixel = 0
    b.Text = value
    b.TextColor3 = Color3.new(1,1,1)
    b.Font = Enum.Font.GothamBold
    b.TextSize = 11
    b.Parent = panel
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
    return b
end
local startBtn = button("INICIAR", .027, Color3.fromRGB(38,138,104))
local copyBtn = button("COPIAR", .35, Color3.fromRGB(51,107,192))
local closeBtn = button("FECHAR", .675, Color3.fromRGB(150,65,76))
local footer = label("Nao muda sensibilidade, corpo, joystick ou FOV.", 160, 22, 10, Color3.fromRGB(169,183,202))

local alive = true
local collecting = false
local connections = {}
local duration = 12
local startedAt = 0
local textReport = "Execute INICIAR e depois COPIAR."
local trackedTouches = {}
local activeRightTouches = 0
local remainingPixelRight = 0
local remainingPixelAll = 0
local releaseAt = -9999
local hadRightFingerPrevious = false
local lastCam, lastRoot, lastCamType = nil, nil, nil
local prevCamCF, prevRootCF = nil, nil
local records = {}
local cameraPaths = {}
local stats = {}
local modeAtStart, modeAtEnd = "", ""
local lastWarn = 0

local function connect(signal, callback)
    local connection = signal:Connect(callback)
    connections[#connections+1] = connection
    return connection
end
local function f(n) return string.format("%.3f", tonumber(n) or 0) end
local function angle(a) return math.atan2(math.sin(a), math.cos(a)) end
local function degreeDiff(a, b) return math.deg(angle(a - b)) end
local function rotation(cf)
    local p,y,r = cf:ToOrientation()
    return p,y,r
end
local function rootPart()
    local character = player.Character
    return character and character:FindFirstChild("HumanoidRootPart") or nil
end
local function pointInFrame(pos, frame)
    local p, s = frame.AbsolutePosition, frame.AbsoluteSize
    return pos.X >= p.X and pos.X <= p.X+s.X and pos.Y >= p.Y and pos.Y <= p.Y+s.Y
end
local function guessMode()
    local v6 = ENV.MemeDashSensitivityV6
    if type(v6) == "table" then
        local okV,value = pcall(function() return v6.GetMultiplier() end)
        local okS, state = pcall(function() return v6.GetStatus() end)
        return "V6 detected: " .. (okV and tostring(value) or "?") .. "x / " ..
            (okS and tostring(state) or "status unavailable")
    end
    local old = ENV.MemeDashCameraSensitivity
    if type(old) == "table" then
        local ok, value = pcall(function() return old.GetMultiplier() end)
        return "Older sensitivity detected: " .. (ok and tostring(value) or "?") .. "x"
    end
    return "No supported sensitivity API detected (could be OFF or external)"
end
local function scanPaths()
    local result = {}
    local seen = {}
    for _,root in ipairs({
        Workspace,
        player:FindFirstChild("PlayerScripts"),
        player.Character,
        game:GetService("ReplicatedStorage"),
        game:GetService("ReplicatedFirst")
    }) do
        if root then
            local ok, children = pcall(function() return root:GetDescendants() end)
            if ok then
                local inspected = 0
                for _,obj in ipairs(children) do
                    inspected = inspected + 1
                    if inspected > 6500 then break end
                    if (obj:IsA("LocalScript") or obj:IsA("ModuleScript"))
                        and not seen[obj] then
                        local n = obj.Name:lower()
                        if n == "camera" or n == "camerainput"
                            or n == "cameramodule" or n == "playermodule"
                            or n:find("camera",1,true) then
                            seen[obj] = true
                            local pathOk, path = pcall(function() return obj:GetFullName() end)
                            result[#result+1] = (pathOk and path or obj.Name) .. " [" .. obj.ClassName .. "]"
                            if #result >= 35 then break end
                        end
                    end
                end
            end
        end
        if #result >= 35 then break end
    end
    table.sort(result)
    if #result == 0 then result[1] = "(none visible)" end
    return result
end
local function reset()
    trackedTouches = {}
    activeRightTouches = 0
    remainingPixelRight, remainingPixelAll = 0, 0
    releaseAt = -9999
    hadRightFingerPrevious = false
    lastCam, lastRoot, lastCamType = nil, nil, nil
    prevCamCF, prevRootCF = nil, nil
    records, cameraPaths = {}, scanPaths()
    stats = {
        frames=0, fpsSum=0, fpsMin=999, fpsMax=0, badDt=0,
        rightStarts=0, otherStarts=0, rightMoves=0, otherMoves=0,
        rightEnds=0, otherEnds=0, rightPixels=0, allPixels=0,
        yawAbs=0, pitchAbs=0, rollAbs=0, rootYawAbs=0,
        cameraRootMaxMismatch=0, cameraRootYawChangeError=0,
        cameraRootYawChangeErrorMax=0, cameraRootMismatchFrames=0,
        maxYawFrame=0, maxPitchFrame=0, maxRootYawFrame=0,
        rightYawAbs=0, rightPitchAbs=0, noRightYawAbs=0, noRightPitchAbs=0,
        afterReleaseFrames=0, maxAfterReleaseYaw=0, maxAfterReleasePitch=0,
        jump15=0, jump30=0, currentCameraSwaps=0, cameraTypeChanges=0,
        cameraPosMaxStep=0, samples=0
    }
    modeAtStart = guessMode()
    modeAtEnd = modeAtStart
end
local function noteTouch(kind, input)
    if not alive or not collecting then return end
    if input.UserInputType ~= Enum.UserInputType.Touch then return end
    local pos = input.Position
    if kind == "start" then
        if pointInFrame(pos, panel) then
            trackedTouches[input] = {last=pos, category="ui"}
        else
            local cam = Workspace.CurrentCamera
            local width = cam and cam.ViewportSize.X or 724
            local category = pos.X >= width * 0.43 and "right" or "other"
            trackedTouches[input] = {last=pos, category=category}
            if category == "right" then
                stats.rightStarts = stats.rightStarts+1
                activeRightTouches = activeRightTouches+1
            else
                stats.otherStarts = stats.otherStarts+1
            end
        end
    elseif kind == "move" then
        local data = trackedTouches[input]
        if not data then return end
        local delta = (Vector2.new(pos.X, pos.Y) - Vector2.new(data.last.X, data.last.Y)).Magnitude
        data.last = pos
        if data.category ~= "ui" then
            if delta < 500 then
                remainingPixelAll = remainingPixelAll+delta
                stats.allPixels = stats.allPixels+delta
                if data.category == "right" then
                    remainingPixelRight = remainingPixelRight+delta
                    stats.rightPixels = stats.rightPixels+delta
                end
            end
            if data.category == "right" then
                stats.rightMoves = stats.rightMoves+1
            else
                stats.otherMoves = stats.otherMoves+1
            end
        end
    elseif kind == "end" then
        local data = trackedTouches[input]
        if data then
            if data.category == "right" then
                activeRightTouches = math.max(0, activeRightTouches-1)
                stats.rightEnds = stats.rightEnds+1
                releaseAt = os.clock()
            elseif data.category == "other" then
                stats.otherEnds = stats.otherEnds+1
            end
            trackedTouches[input] = nil
        end
    end
end
connect(UIS.TouchStarted, function(i) noteTouch("start", i) end)
connect(UIS.TouchMoved, function(i) noteTouch("move", i) end)
connect(UIS.TouchEnded, function(i) noteTouch("end", i) end)

local function reportText()
    local s = stats
    local cam = Workspace.CurrentCamera
    local out = {}
    local function add(t) out[#out+1] = tostring(t) end
    add("===== MEMEDASH X9 v2 | CAMERA / TOUCH =====")
    add("Read-only; collected 12 seconds; no writes to camera/body/controls.")
    add("PlaceId="..tostring(game.PlaceId))
    add("Touch="..tostring(UIS.TouchEnabled).." Keyboard="..tostring(UIS.KeyboardEnabled))
    add("Viewport="..tostring(cam and cam.ViewportSize or "nil"))
    add("CameraType="..tostring(cam and cam.CameraType or "nil"))
    add("FOV="..tostring(cam and cam.FieldOfView or "nil"))
    add("Mode at start="..modeAtStart)
    add("Mode at end="..modeAtEnd)
    add("Important: detected mode is informational, not verified as enabled.")
    add("")
    add("[FRAME HEALTH]")
    add("frames="..s.frames.." FPSavg="..f(s.frames > 0 and s.fpsSum/s.frames or 0)..
        " FPSmin="..f(s.fpsMin == 999 and 0 or s.fpsMin).." FPSmax="..f(s.fpsMax))
    add("dtOver150ms="..s.badDt.." camInstanceChanges="..s.currentCameraSwaps..
        " camTypeChanges="..s.cameraTypeChanges)
    add("[FINGERS - LEFT AND RIGHT SEPARATED]")
    add("Right begins/moves/ends="..s.rightStarts.."/"..s.rightMoves.."/"..s.rightEnds)
    add("Other begins/moves/ends="..s.otherStarts.."/"..s.otherMoves.."/"..s.otherEnds)
    add("Right finger pixels="..f(s.rightPixels).." Other+right pixels="..f(s.allPixels))
    add("NOTE: right side >43% screen width; heuristic, not guaranteed camera-only.")
    add("[CAMERA / BODY]")
    add("camera yaw abs sum="..f(s.yawAbs).." pitch abs sum="..f(s.pitchAbs)..
        " roll abs sum="..f(s.rollAbs))
    add("root yaw abs sum="..f(s.rootYawAbs))
    add("max frame delta yaw="..f(s.maxYawFrame).." pitch="..f(s.maxPitchFrame)..
        " rootYaw="..f(s.maxRootYawFrame))
    add("yaw with right touch="..f(s.rightYawAbs).." yaw without="..f(s.noRightYawAbs))
    add("pitch with right touch="..f(s.rightPitchAbs).." pitch without="..f(s.noRightPitchAbs))
    add("camera/root yaw mismatch max="..f(s.cameraRootMaxMismatch)..
        " frames>5deg="..s.cameraRootMismatchFrames)
    add("cameraYaw-vs-rootYaw DELTA difference sum="..f(s.cameraRootYawChangeError)..
        " maxFrame="..f(s.cameraRootYawChangeErrorMax))
    add("camera position max frame distance="..f(s.cameraPosMaxStep))
    add("jumps>15deg="..s.jump15.." jumps>30deg="..s.jump30)
    add("after-right-release camera movement frames="..s.afterReleaseFrames..
        " maxYaw="..f(s.maxAfterReleaseYaw).." maxPitch="..f(s.maxAfterReleasePitch))
    add("[APPROXIMATE RATIO - NOT A VALID SENSITIVITY FACTOR]")
    add("yawAbsWithRight / rightFingerPixels="..
        f(s.rightPixels>0 and s.rightYawAbs/s.rightPixels or 0))
    add("Multitouch, different frame timing and game behavior can affect this.")
    add("[VISIBLE CAMERA SCRIPTS - NAMES ONLY]")
    for _,path in ipairs(cameraPaths) do add(path) end
    add("[SAMPLES EVERY 2 FRAMES - TIME SERIES]")
    add("time;touchRight;rightPx;allPx;dyaw;dpitch;droll;dRootYaw;cameraRootYawOffset;fps;camStep")
    for _,row in ipairs(records) do add(row) end
    add("=== END X9 v2 ===")
    return table.concat(out,"\n")
end

connect(RunService.RenderStepped, function(dt)
    if not alive or not collecting then return end
    local cam = Workspace.CurrentCamera
    if not cam then return end
    local root = rootPart()
    local camCF, rootCF = cam.CFrame, root and root.CFrame
    local s = stats
    local now = os.clock()
    local rightPx = remainingPixelRight
    local allPx = remainingPixelAll
    remainingPixelRight, remainingPixelAll = 0, 0
    s.frames = s.frames+1
    local fps = dt > 0 and math.min(500,1/dt) or 0
    s.fpsSum = s.fpsSum+fps
    s.fpsMin = math.min(s.fpsMin,fps)
    s.fpsMax = math.max(s.fpsMax,fps)
    if dt > .15 then s.badDt=s.badDt+1 end
    if lastCam and cam ~= lastCam then s.currentCameraSwaps=s.currentCameraSwaps+1 end
    if lastCamType and cam.CameraType ~= lastCamType then s.cameraTypeChanges=s.cameraTypeChanges+1 end
    local yaw, pitch, roll = 0,0,0
    local rootYawDelta, rootYawOffset, camStep = 0,0,0
    local p,y,r=rotation(camCF)
    if prevCamCF and cam==lastCam and dt > 0 and dt < .15 then
        local pp,py,pr=rotation(prevCamCF)
        yaw=degreeDiff(y,py)
        pitch=degreeDiff(p,pp)
        roll=degreeDiff(r,pr)
        camStep=(camCF.Position-prevCamCF.Position).Magnitude
        s.cameraPosMaxStep=math.max(s.cameraPosMaxStep,camStep)
    end
    if rootCF then
        local _,ry=rotation(rootCF)
        rootYawOffset=degreeDiff(y,ry)
        s.cameraRootMaxMismatch=math.max(s.cameraRootMaxMismatch, math.abs(rootYawOffset))
        if math.abs(rootYawOffset)>5 then s.cameraRootMismatchFrames=s.cameraRootMismatchFrames+1 end
        if prevRootCF and lastRoot==root and dt>0 and dt<.15 then
            local _,prevRy=rotation(prevRootCF)
            rootYawDelta=degreeDiff(ry,prevRy)
            local difference=math.abs(yaw-rootYawDelta)
            s.cameraRootYawChangeError=s.cameraRootYawChangeError+difference
            s.cameraRootYawChangeErrorMax=math.max(s.cameraRootYawChangeErrorMax,difference)
        end
    end
    s.yawAbs=s.yawAbs+math.abs(yaw)
    s.pitchAbs=s.pitchAbs+math.abs(pitch)
    s.rollAbs=s.rollAbs+math.abs(roll)
    s.rootYawAbs=s.rootYawAbs+math.abs(rootYawDelta)
    s.maxYawFrame=math.max(s.maxYawFrame,math.abs(yaw))
    s.maxPitchFrame=math.max(s.maxPitchFrame,math.abs(pitch))
    s.maxRootYawFrame=math.max(s.maxRootYawFrame,math.abs(rootYawDelta))
    if activeRightTouches>0 then
        s.rightYawAbs=s.rightYawAbs+math.abs(yaw)
        s.rightPitchAbs=s.rightPitchAbs+math.abs(pitch)
    else
        s.noRightYawAbs=s.noRightYawAbs+math.abs(yaw)
        s.noRightPitchAbs=s.noRightPitchAbs+math.abs(pitch)
    end
    if math.max(math.abs(yaw),math.abs(pitch))>15 then s.jump15=s.jump15+1 end
    if math.max(math.abs(yaw),math.abs(pitch))>30 then s.jump30=s.jump30+1 end
    if activeRightTouches==0 and now-releaseAt<.20 and
        (math.abs(yaw)>.05 or math.abs(pitch)>.05) then
        s.afterReleaseFrames=s.afterReleaseFrames+1
        s.maxAfterReleaseYaw=math.max(s.maxAfterReleaseYaw,math.abs(yaw))
        s.maxAfterReleasePitch=math.max(s.maxAfterReleasePitch,math.abs(pitch))
    end
    if s.frames%2==0 and #records<650 then
        records[#records+1]=table.concat({
            f(now-startedAt),tostring(activeRightTouches),f(rightPx),
            f(allPx),f(yaw),f(pitch),f(roll),f(rootYawDelta),
            f(rootYawOffset),f(fps),f(camStep)
        },";")
    end
    prevCamCF,prevRootCF=camCF,rootCF
    lastCam,lastRoot,lastCamType=cam,root,cam.CameraType
    if s.frames%20==0 then
        status.Text=string.format("GRAVANDO %.1fs • %d frames • %d movimentos direita",
            math.max(0,duration-(now-startedAt)),s.frames,s.rightMoves)
    end
    if now-startedAt>=duration then
        collecting=false
        modeAtEnd=guessMode()
        textReport=reportText()
        status.Text="PRONTO • "..tostring(#textReport).." caracteres"
        startBtn.Text="REFAZER"
        print("[MemeDash X9 v2] Pronto - toque COPIAR")
    end
end)

local function fallbackReport()
    local modal = Instance.new("Frame")
    modal.Size=UDim2.new(.96,0,.92,0)
    modal.Position=UDim2.new(.02,0,.04,0)
    modal.BackgroundColor3=Color3.fromRGB(14,19,30)
    modal.ZIndex=10
    modal.Parent=gui
    Instance.new("UICorner",modal).CornerRadius=UDim.new(0,9)
    local field=Instance.new("TextBox")
    field.Position=UDim2.fromOffset(9,9)
    field.Size=UDim2.new(1,-18,1,-59)
    field.MultiLine=true
    field.ClearTextOnFocus=false
    field.TextEditable=true
    field.TextWrapped=false
    field.Font=Enum.Font.Code
    field.TextSize=11
    field.TextXAlignment=Enum.TextXAlignment.Left
    field.TextYAlignment=Enum.TextYAlignment.Top
    field.Text=textReport
    field.TextColor3=Color3.new(1,1,1)
    field.BackgroundColor3=Color3.fromRGB(28,34,47)
    field.ZIndex=11
    field.Parent=modal
    local dismiss=Instance.new("TextButton")
    dismiss.Size=UDim2.fromOffset(85,37)
    dismiss.Position=UDim2.new(1,-95,1,-45)
    dismiss.BackgroundColor3=Color3.fromRGB(136,59,72)
    dismiss.TextColor3=Color3.new(1,1,1)
    dismiss.Text="FECHAR"
    dismiss.ZIndex=12
    dismiss.Parent=modal
    connect(dismiss.Activated,function() modal:Destroy() end)
    status.Text="Copie manualmente o texto da caixa"
end
local function cleanup()
    if not alive then return end
    alive=false
    collecting=false
    for _,connection in ipairs(connections) do pcall(function() connection:Disconnect() end) end
    table.clear(connections)
    gui:Destroy()
    if ENV.__MemeDashX9Cleanup == cleanup then ENV.__MemeDashX9Cleanup = nil end
end
ENV.__MemeDashX9Cleanup=cleanup
connect(startBtn.Activated,function()
    if collecting then return end
    reset()
    startedAt=os.clock()
    collecting=true
    status.Text="GRAVANDO • arraste e solte a camera"
    startBtn.Text="GRAVANDO"
end)
connect(copyBtn.Activated,function()
    if collecting then status.Text="Termine os 12 segundos antes de copiar";return end
    if not textReport:find("===== MEMEDASH X9 v2",1,true) then
        status.Text="Clique INICIAR primeiro"
        return
    end
    local clipboard=(type(setclipboard)=="function" and setclipboard)
        or (type(toclipboard)=="function" and toclipboard)
    if clipboard then
        local success=pcall(clipboard,textReport)
        if success then status.Text="COPIADO! Cole o relatorio na conversa";return end
    end
    fallbackReport()
end)
connect(closeBtn.Activated,cleanup)
print("[MemeDash X9 v2] Read-only. Start, test 12 seconds, copy report.")
