-- MemeDash X9 - diagnostico de sensibilidade touch/camera (somente leitura)
-- Nao altera camera, CFrame, HumanoidRootPart, movimento ou controles.
-- Feito para a camera Scriptable do MemeDash (iPhone / touch).
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
assert(player, "Execute no cliente.")
local pg = player:WaitForChild("PlayerGui")
local env = (type(getgenv) == "function" and getgenv()) or _G
if type(env.__MemeDashX9Cleanup) == "function" then
    pcall(env.__MemeDashX9Cleanup)
end
local previous = pg:FindFirstChild("MemeDashX9Diagnostic")
if previous then previous:Destroy() end

local alive, recording = true, false
local connections = {}
local sessionId = 0
local report = "MemeDash X9: clique em INICIAR, arraste a camera e solte o dedo."
local startTime, duration = 0, 12
local cameraPrev, rootPrev = nil, nil
local touchPositions, touchStates = {}, {}
local accumulatedPixels, lastTouchEvents = 0, 0
local samples = {}
local total = {}
local phaseFrames, lastCamera = 0, ""
local cameraTypeChanges, cameraChanges = 0, 0
local maxSamples = 900

local function on(signal, fn)
    local c = signal:Connect(fn)
    connections[#connections + 1] = c
    return c
end
local function makeStats()
    return {frames=0, touchPixels=0, touchMoves=0, touchStarts=0, touchEnds=0,
        cameraYaw=0, cameraPitch=0, cameraRoll=0, cameraRotation=0, rootYaw=0,
        yawAbs=0, pitchAbs=0, maxYaw=0, maxPitch=0, maxRootYaw=0, 
        untouchedCameraFrames=0, zeroTouchCameraFrames=0, deltaFrames=0,
        fpsSum=0, largeJumps=0, releasedJumps=0, maxReleasedJump=0,
        noTouchYawAbs=0, withTouchYawAbs=0, maxFps=0, minFps=9999}
end
local function fmt(n) return string.format("%.3f", n or 0) end
local function wrapAngle(a) return math.atan2(math.sin(a), math.cos(a)) end
local function orientation(cf)
    if not cf then return nil end
    local pitch, yaw, roll = cf:ToOrientation()
    return pitch, yaw, roll
end
local function readRoot()
    local character = player.Character
    return character and character:FindFirstChild("HumanoidRootPart")
end
local function insidePanel(position, panel)
    local p, s = panel.AbsolutePosition, panel.AbsoluteSize
    return position.X >= p.X and position.X <= p.X + s.X
       and position.Y >= p.Y and position.Y <= p.Y + s.Y
end
local function countKeys(tab)
    local n = 0
    for _ in pairs(tab) do n = n + 1 end
    return n
end

local gui = Instance.new("ScreenGui")
gui.Name = "MemeDashX9Diagnostic"
gui.ResetOnSpawn = false
gui.DisplayOrder = 950000
gui.IgnoreGuiInset = false
gui.Parent = pg

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(0.5, 0)
panel.Size = UDim2.fromOffset(350, 213)
panel.Position = UDim2.new(0.5, 0, 0.10, 0)
panel.BackgroundColor3 = Color3.fromRGB(18, 22, 33)
panel.BorderSizePixel = 0
panel.Active = true
panel.Parent = gui
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 12)
local limit = Instance.new("UISizeConstraint")
limit.MaxSize = Vector2.new(350, 240)
limit.MinSize = Vector2.new(270, 200)
limit.Parent = panel

local function label(text, y, height, size, color)
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1, -20, 0, height)
    l.Position = UDim2.fromOffset(10, y)
    l.BackgroundTransparency = 1
    l.TextWrapped = true
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.TextYAlignment = Enum.TextYAlignment.Center
    l.Font = Enum.Font.Gotham
    l.TextSize = size
    l.TextColor3 = color or Color3.fromRGB(225, 234, 248)
    l.Text = text
    l.Parent = panel
    return l
end
local title = label("MEMEDASH • X9 CAMERA LAB", 8, 25, 15, Color3.fromRGB(137, 202, 255))
title.Font = Enum.Font.GothamBold
local info = label("Observacao pura • nao mexe nos controles.", 36, 22, 11)
local status = label("PRONTO • toque INICIAR", 62, 30, 12, Color3.fromRGB(142, 240, 190))
local instruction = label("Durante 12s: arraste a camera na direita, pare e solte o dedo 2 vezes.", 94, 41, 11)

local function button(text, x, color)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0.31, -4, 0, 37)
    b.Position = UDim2.new(x, 0, 0, 149)
    b.BackgroundColor3 = color
    b.TextColor3 = Color3.new(1, 1, 1)
    b.BorderSizePixel = 0
    b.Text = text
    b.Font = Enum.Font.GothamBold
    b.TextSize = 11
    b.Parent = panel
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
    return b
end
local startBtn = button("INICIAR", 0.025, Color3.fromRGB(35, 128, 105))
local copyBtn = button("COPIAR", 0.35, Color3.fromRGB(40, 103, 175))
local closeBtn = button("FECHAR", 0.675, Color3.fromRGB(145, 64, 79))
local foot = label("Relatorio nao inclui nome, UserId, chat ou textos privados.", 191, 16, 9, Color3.fromRGB(159, 172, 191))

local function controllerInfo()
    local found = {}
    local function probe(folder)
        if not folder then return end
        local seen = 0
        for _, obj in ipairs(folder:GetDescendants()) do
            seen = seen + 1
            if seen > 4500 then break end
            if obj:IsA("LocalScript") or obj:IsA("ModuleScript") then
                local name = string.lower(obj.Name)
                if name == "camera" or name == "camerainput"
                    or name == "cameramodule" or name == "playermodule"
                    or name == "tpcamera" then
                    if #found < 25 then
                        found[#found + 1] = obj:GetFullName() .. " [" .. obj.ClassName .. "]"
                    end
                end
            end
        end
    end
    probe(Workspace)
    local ps = player:FindFirstChild("PlayerScripts")
    probe(ps)
    if #found == 0 then return {"(nenhum script de camera visivel pelo cliente)"} end
    return found
end

local function reset()
    sessionId = sessionId + 1
    total = makeStats()
    samples = {}
    touchPositions, touchStates = {}, {}
    accumulatedPixels, lastTouchEvents = 0, 0
    cameraPrev, rootPrev = nil, nil
    cameraTypeChanges, cameraChanges = 0, 0
    phaseFrames, lastCamera = 0, ""
end

local function handleTouch(kind, input)
    if not alive or not recording then return end
    local pos = input.Position
    if kind == "start" then
        if insidePanel(pos, panel) then
            touchStates[input] = "ui"
            return
        end
        touchStates[input] = pos.X >= (Workspace.CurrentCamera and Workspace.CurrentCamera.ViewportSize.X or 800) * 0.42
            and "camera-candidate" or "other"
        touchPositions[input] = pos
        total.touchStarts = total.touchStarts + 1
    elseif kind == "move" then
        if touchStates[input] == "ui" then return end
        local last = touchPositions[input]
        if last then
            local distance = (Vector2.new(pos.X, pos.Y) - Vector2.new(last.X, last.Y)).Magnitude
            -- evitar teletransporte espurio do toque
            if distance < 500 then
                accumulatedPixels = accumulatedPixels + distance
                total.touchPixels = total.touchPixels + distance
            end
        end
        touchPositions[input] = pos
        total.touchMoves = total.touchMoves + 1
        lastTouchEvents = lastTouchEvents + 1
    elseif kind == "end" then
        if touchStates[input] ~= "ui" then
            total.touchEnds = total.touchEnds + 1
        end
        touchPositions[input], touchStates[input] = nil, nil
    end
end
on(UIS.TouchStarted, function(i) handleTouch("start", i) end)
on(UIS.TouchMoved, function(i) handleTouch("move", i) end)
on(UIS.TouchEnded, function(i) handleTouch("end", i) end)

local function makeReport()
    local t = total
    local lines = {
        "===== MEMEDASH X9 - CAMERA / TOUCH =====",
        "Versao X9-2026.10.30 | Somente leitura | 12s",
        "PlaceId=" .. tostring(game.PlaceId) .. " | JobId omitido",
        "Platform: Touch=" .. tostring(UIS.TouchEnabled) .. " Keyboard=" .. tostring(UIS.KeyboardEnabled),
        "CameraType=" .. (Workspace.CurrentCamera and tostring(Workspace.CurrentCamera.CameraType) or "nil"),
        "FOV=" .. (Workspace.CurrentCamera and tostring(Workspace.CurrentCamera.FieldOfView) or "nil"),
        "Viewport=" .. (Workspace.CurrentCamera and tostring(Workspace.CurrentCamera.ViewportSize) or "nil"),
        "CameraTypeChanges=" .. cameraTypeChanges .. " CurrentCameraSwaps=" .. cameraChanges,
        "",
        "[AMOSTRAS / TOQUES]",
        "frames=" .. t.frames .. " touchStarts=" .. t.touchStarts .. " touchMoves=" .. t.touchMoves .. " touchEnds=" .. t.touchEnds,
        "touchDistancePixels=" .. fmt(t.touchPixels) .. " cameraDragCandidates=" .. countKeys(touchPositions),
        "FPS avg=" .. fmt(t.frames > 0 and t.fpsSum / t.frames or 0) ..
           " min=" .. fmt(t.minFps == 9999 and 0 or t.minFps) .. " max=" .. fmt(t.maxFps),
        "",
        "[DELTA CAMERA (GRAUS, VALORES ABSOLUTOS)]",
        "yawTotal=" .. fmt(t.yawAbs) .. " pitchTotal=" .. fmt(t.pitchAbs) ..
           " maxYawFrame=" .. fmt(t.maxYaw) .. " maxPitchFrame=" .. fmt(t.maxPitch),
        "rootYawTotal=" .. fmt(t.rootYaw) .. " maxRootYawFrame=" .. fmt(t.maxRootYaw),
        "cameraMovementWithTouch=" .. fmt(t.withTouchYawAbs) ..
           " cameraMovementWithoutTouch=" .. fmt(t.noTouchYawAbs),
        "cameraFramesWithoutTouch=" .. t.zeroTouchCameraFrames ..
           " cameraJumpOver15deg=" .. t.largeJumps,
        "jumpAfterRelease=" .. t.releasedJumps .. " maxAfterRelease=" .. fmt(t.maxReleasedJump),
        "",
        "[ESTIMATIVA — NAO E MULTIPLICADOR]",
        "grausYawPorPixelDeToque=" .. fmt(t.touchPixels > 0 and t.yawAbs/t.touchPixels or 0),
        "NOTA: relacao aproximada: inclui toques de joystick e camera, tempo e jogo.",
        "Se ha movimento sem toque, pode ser camera Scriptable, recuo, corpo ou atualizacao do jogo.",
        "",
        "[SCRIPTS DE CAMERA VISIVEIS]"
    }
    for _, path in ipairs(controllerInfo()) do lines[#lines + 1] = path end
    lines[#lines + 1] = ""
    lines[#lines + 1] = "[AMOSTRAS TEMPORAIS (max 900, 1 a cada 3 frames)]"
    lines[#lines + 1] = "t;fingerPxSinceLast;activeTouches;dYaw;dPitch;dRoll;rootYaw;fps"
    for _, s in ipairs(samples) do lines[#lines + 1] = s end
    lines[#lines + 1] = ""
    lines[#lines + 1] = "SEM ESCRITA EM CFrame / ROTACAO / PERSONAGEM."
    return table.concat(lines, "\n")
end

local lastWasReleased = false
on(RunService.RenderStepped, function(dt)
    if not alive or not recording then return end
    local cam = Workspace.CurrentCamera
    if not cam then return end
    local c = cam.CFrame
    local root = readRoot()
    local r = root and root.CFrame or nil
    local framePixels, activeTouch = accumulatedPixels, countKeys(touchPositions)
    accumulatedPixels = 0
    local fps = dt > 0 and math.min(1000, 1 / dt) or 0
    total.frames = total.frames + 1
    total.fpsSum = total.fpsSum + fps
    total.minFps = math.min(total.minFps, fps)
    total.maxFps = math.max(total.maxFps, fps)
    if lastCamera ~= "" and lastCamera ~= tostring(cam) then cameraChanges = cameraChanges + 1 end
    lastCamera = tostring(cam)
    if cameraPrev and cameraPrev.typeName ~= tostring(cam.CameraType) then
        cameraTypeChanges = cameraTypeChanges + 1
    end
    local dy, dp, dr, ry = 0, 0, 0, 0
    if cameraPrev and cameraPrev.instance == cam then
        local p1,y1,roll1 = orientation(cameraPrev.cf)
        local p2,y2,roll2 = orientation(c)
        dy = math.deg(wrapAngle(y2 - y1))
        dp = math.deg(wrapAngle(p2 - p1))
        dr = math.deg(wrapAngle(roll2 - roll1))
    end
    if rootPrev and r and rootPrev.instance == root then
        local _, a = orientation(rootPrev.cf)
        local _, b = orientation(r)
        ry = math.deg(wrapAngle(b-a))
    end
    total.yawAbs = total.yawAbs + math.abs(dy)
    total.pitchAbs = total.pitchAbs + math.abs(dp)
    total.rootYaw = total.rootYaw + math.abs(ry)
    total.maxYaw = math.max(total.maxYaw, math.abs(dy))
    total.maxPitch = math.max(total.maxPitch, math.abs(dp))
    total.maxRootYaw = math.max(total.maxRootYaw, math.abs(ry))
    local moving = math.abs(dy) > 0.02 or math.abs(dp) > 0.02
    if activeTouch == 0 then
        total.noTouchYawAbs = total.noTouchYawAbs + math.abs(dy)
        if moving then total.zeroTouchCameraFrames = total.zeroTouchCameraFrames + 1 end
    else
        total.withTouchYawAbs = total.withTouchYawAbs + math.abs(dy)
    end
    if math.abs(dy) > 15 or math.abs(dp) > 15 then total.largeJumps = total.largeJumps + 1 end
    if activeTouch == 0 and lastWasReleased and moving then
        total.releasedJumps = total.releasedJumps + 1
        total.maxReleasedJump = math.max(total.maxReleasedJump, math.abs(dy), math.abs(dp))
    end
    lastWasReleased = (activeTouch > 0)
    if total.frames % 3 == 0 and #samples < maxSamples then
        samples[#samples + 1] = string.format("%.2f;%s;%d;%s;%s;%s;%s;%s",
            os.clock() - startTime, fmt(framePixels), activeTouch, fmt(dy),
            fmt(dp), fmt(dr), fmt(ry), fmt(fps))
    end
    cameraPrev = {instance=cam,cf=c,typeName=tostring(cam.CameraType)}
    rootPrev = r and {instance=root,cf=r} or nil
    if total.frames % 24 == 0 then
        local left = math.max(0, duration - (os.clock() - startTime))
        status.Text = string.format("GRAVANDO • %.1fs | toques=%d | frames=%d", left, total.touchMoves, total.frames)
    end
    if os.clock() - startTime >= duration then
        recording = false
        report = makeReport()
        status.Text = "PRONTO • relatorio gerado (" .. #report .. " caracteres)"
        startBtn.Text = "REFAZER"
        print("[MemeDash X9] Relatorio pronto. Clique COPIAR.")
    end
end)

local function copyReport()
    if recording then
        status.Text = "Termine a coleta antes de copiar."
        return
    end
    if not report:find("===== MEMEDASH X9", 1, true) then
        report = makeReport()
    end
    local copy = (type(setclipboard) == "function" and setclipboard)
        or (type(toclipboard) == "function" and toclipboard)
    if copy then
        local ok, err = pcall(copy, report)
        if ok then
            status.Text = "COPIADO! Cole o relatorio na conversa."
            return
        end
        warn("[MemeDash X9] Copia indisponivel: " .. tostring(err))
    end
    -- Fallback: caixa selecionavel para copiar manualmente no iOS.
    local modal = Instance.new("Frame")
    modal.Size = UDim2.new(0.96, 0, 0.94, 0)
    modal.Position = UDim2.new(0.02, 0, 0.03, 0)
    modal.BackgroundColor3 = Color3.fromRGB(10, 14, 20)
    modal.ZIndex = 10
    modal.Parent = gui
    Instance.new("UICorner", modal).CornerRadius = UDim.new(0, 10)
    local field = Instance.new("TextBox")
    field.Size = UDim2.new(1, -20, 1, -64)
    field.Position = UDim2.fromOffset(10, 10)
    field.Text = report
    field.TextWrapped = false
    field.MultiLine = true
    field.ClearTextOnFocus = false
    field.TextEditable = true
    field.TextSize = 11
    field.Font = Enum.Font.Code
    field.TextXAlignment = Enum.TextXAlignment.Left
    field.TextYAlignment = Enum.TextYAlignment.Top
    field.BackgroundColor3 = Color3.fromRGB(26, 31, 43)
    field.TextColor3 = Color3.new(1,1,1)
    field.ZIndex = 11
    field.Parent = modal
    local hint = Instance.new("TextLabel")
    hint.Size = UDim2.new(1,-70,0,35)
    hint.Position = UDim2.new(0,10,1,-44)
    hint.Text = "Selecione todo o texto e copie."
    hint.TextColor3 = Color3.new(1,1,1)
    hint.TextSize = 12
    hint.BackgroundTransparency = 1
    hint.ZIndex = 11
    hint.Parent = modal
    local x = Instance.new("TextButton")
    x.Size = UDim2.fromOffset(48, 30)
    x.Position = UDim2.new(1,-56,1,-39)
    x.Text = "X"
    x.TextSize = 15
    x.TextColor3 = Color3.new(1,1,1)
    x.BackgroundColor3 = Color3.fromRGB(135,55,70)
    x.ZIndex = 12
    x.Parent = modal
    on(x.Activated, function() modal:Destroy() end)
    status.Text = "Clipboard indisponivel • selecione e copie."
end

local function cleanup()
    if not alive then return end
    alive, recording = false, false
    sessionId = sessionId + 1
    for _, c in ipairs(connections) do pcall(function() c:Disconnect() end) end
    table.clear(connections)
    if gui then gui:Destroy() end
    env.__MemeDashX9Cleanup = nil
end
env.__MemeDashX9Cleanup = cleanup

on(startBtn.Activated, function()
    reset()
    recording = true
    startTime = os.clock()
    lastWasReleased = false
    startBtn.Text = "GRAVANDO"
    status.Text = "GRAVANDO • arraste e solte a camera"
end)
on(copyBtn.Activated, copyReport)
on(closeBtn.Activated, cleanup)
print("[MemeDash X9] Diagnostico pronto. Nao altera sensibilidade.")
