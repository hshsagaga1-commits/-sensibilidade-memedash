-- MEMEDASH CAMERA X9 DIAGNOSTIC v1.0
-- Read-only camera/body diagnostics. Does not change camera or character movement.
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ENV = (type(getgenv) == "function" and getgenv()) or _G
local player = Players.LocalPlayer
assert(player, "Execute no cliente do jogo.")
local playerGui = player:WaitForChild("PlayerGui")
local GUI_NAME = "MemeDashCameraX9Gui"

-- Stop the sensitivity script so this test measures the game's original behavior.
if type(ENV.__MemeDashCameraSensitivityCleanup) == "function" then
    pcall(ENV.__MemeDashCameraSensitivityCleanup)
end
if type(ENV.MemeDashCameraSensitivity) == "table" and type(ENV.MemeDashCameraSensitivity.Cleanup) == "function" then
    pcall(ENV.MemeDashCameraSensitivity.Cleanup)
end
for _, parent in ipairs({playerGui, game:GetService("CoreGui")}) do
    local old = parent:FindFirstChild(GUI_NAME)
    if old then pcall(function() old:Destroy() end) end
end

local running = false
local samples = {}
local inputCounts = {}
local inputDeltas = {}
local connections = {}
local startClock = 0
local duration = 12
local statusLabel
local reportText = ""

local function deg(x) return math.deg(x or 0) end
local function yawPitch(cf)
    if not cf then return 0, 0 end
    local _, y, _ = cf:ToOrientation()
    local x, _, _ = cf:ToOrientation()
    return deg(y), deg(x)
end
local function wrapDeg(x)
    return math.deg(math.atan2(math.sin(math.rad(x)), math.cos(math.rad(x))))
end
local function angleDelta(a, b) return wrapDeg(b - a) end
local function getRig()
    local char = player.Character
    if not char then return nil, nil, nil, nil end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart")
    local head = char:FindFirstChild("Head")
    return char, hum, root, head
end
local function readState(t)
    local cam = workspace.CurrentCamera
    local char, hum, root, head = getRig()
    local cy, cp = yawPitch(cam and cam.CFrame)
    local ry = root and yawPitch(root.CFrame) or 0
    local hy = head and yawPitch(head.CFrame) or 0
    local relativeHead = 0
    if root and head then
        local localHead = root.CFrame:ToObjectSpace(head.CFrame)
        relativeHead = yawPitch(localHead)
    end
    local move = hum and hum.MoveDirection or Vector3.zero
    return {
        t = t,
        camType = cam and cam.CameraType.Name or "nil",
        subject = cam and cam.CameraSubject and cam.CameraSubject.ClassName or "nil",
        fov = cam and cam.FieldOfView or 0,
        cy = cy, cp = cp, ry = ry, hy = hy, headRel = relativeHead,
        autoRotate = hum and tostring(hum.AutoRotate) or "nil",
        moveMag = move.Magnitude,
        camX = cam and cam.CFrame.Position.X or 0,
        camY = cam and cam.CFrame.Position.Y or 0,
        camZ = cam and cam.CFrame.Position.Z or 0,
    }
end
local function fmt(n) return string.format("%.1f", n or 0) end
local function makeReport()
    local lines = {}
    table.insert(lines, "MEMEDASH CAMERA X9 REPORT v1.0")
    table.insert(lines, "PlaceId=" .. tostring(game.PlaceId) .. " | samples=" .. #samples .. " | duration=" .. duration .. "s")
    local cam = workspace.CurrentCamera
    local _, hum, root, head = getRig()
    table.insert(lines, "NOW: cameraType=" .. tostring(cam and cam.CameraType.Name) ..
        " subject=" .. tostring(cam and cam.CameraSubject and cam.CameraSubject.ClassName) ..
        " FOV=" .. tostring(cam and cam.FieldOfView) ..
        " AutoRotate=" .. tostring(hum and hum.AutoRotate) ..
        " root=" .. tostring(root ~= nil) .. " head=" .. tostring(head ~= nil))
    table.insert(lines, "INPUT EVENTS: " .. (#inputDeltas > 0 and table.concat((function()
        local a = {}
        for k,v in pairs(inputCounts) do table.insert(a, k .. "=" .. tostring(v)) end
        table.sort(a)
        return a
    end)(), ", ") or "nenhum registrado"))
    local totalCam, totalRoot, totalHead, maxCamStep = 0, 0, 0, 0
    for i = 2, #samples do
        local a, b = samples[i-1], samples[i]
        local dc = math.abs(angleDelta(a.cy, b.cy)) + math.abs(b.cp - a.cp)
        local dr = math.abs(angleDelta(a.ry, b.ry))
        local dh = math.abs(angleDelta(a.hy, b.hy))
        totalCam = totalCam + dc
        totalRoot = totalRoot + dr
        totalHead = totalHead + dh
        if dc > maxCamStep then maxCamStep = dc end
    end
    table.insert(lines, "TOTAL ABS DELTA (sampled): camera=" .. fmt(totalCam) ..
        "deg | body/root=" .. fmt(totalRoot) .. "deg | head=" .. fmt(totalHead) ..
        "deg | max camera step=" .. fmt(maxCamStep) .. "deg")
    table.insert(lines, "INPUT DELTA totals: " .. (#inputDeltas > 0 and (function()
        local x,y=0,0
        for _,d in ipairs(inputDeltas) do x=x+math.abs(d.x); y=y+math.abs(d.y) end
        return "X="..fmt(x).." Y="..fmt(y)
    end)() or "X/Y unavailable"))
    table.insert(lines, "SAMPLES: t,camYaw,camPitch,rootYaw,headYaw,headRelativeYaw,moveMagnitude,cameraType")
    for i, s in ipairs(samples) do
        if i == 1 or i == #samples or i % 3 == 0 then
            table.insert(lines, fmt(s.t) .. "," .. fmt(s.cy) .. "," .. fmt(s.cp) .. "," ..
                fmt(s.ry) .. "," .. fmt(s.hy) .. "," .. fmt(s.headRel) .. "," ..
                fmt(s.moveMag) .. "," .. s.camType)
        end
    end
    return table.concat(lines, "\n")
end
local function makeButton(parent, text, pos, size, color)
    local b = Instance.new("TextButton")
    b.Position = pos; b.Size = size; b.BackgroundColor3 = color
    b.BorderSizePixel = 0; b.Text = text; b.TextColor3 = Color3.new(1,1,1)
    b.Font = Enum.Font.GothamMedium; b.TextSize = 12; b.Parent = parent
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,7); c.Parent = b
    return b
end

local gui = Instance.new("ScreenGui")
gui.Name = GUI_NAME; gui.ResetOnSpawn = false; gui.DisplayOrder = 1000001; gui.Parent = playerGui
local panel = Instance.new("Frame")
panel.Name = "Panel"; panel.Size = UDim2.fromOffset(285,155)
panel.Position = UDim2.new(0.5,-142,0.12,0); panel.BackgroundColor3 = Color3.fromRGB(24,24,27)
panel.BorderSizePixel = 0; panel.Active = true; panel.Parent = gui
local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(0,10); corner.Parent = panel
local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1; title.Position = UDim2.fromOffset(10,6)
title.Size = UDim2.new(1,-20,0,22); title.Text = "MemeDash Camera X9"
title.TextColor3 = Color3.new(1,1,1); title.Font = Enum.Font.GothamBold
title.TextSize = 14; title.Parent = panel
statusLabel = Instance.new("TextLabel")
statusLabel.BackgroundTransparency = 1; statusLabel.Position = UDim2.fromOffset(10,30)
statusLabel.Size = UDim2.new(1,-20,0,34); statusLabel.TextWrapped = true
statusLabel.Text = "Teste original: toque INICIAR e mova a câmera por 12s."
statusLabel.TextColor3 = Color3.fromRGB(220,220,220); statusLabel.Font = Enum.Font.Gotham
statusLabel.TextSize = 11; statusLabel.Parent = panel
local startBtn = makeButton(panel, "INICIAR TESTE", UDim2.fromOffset(10,72), UDim2.fromOffset(125,29), Color3.fromRGB(42,126,82))
local copyBtn = makeButton(panel, "COPIAR RELATÓRIO", UDim2.fromOffset(145,72), UDim2.fromOffset(130,29), Color3.fromRGB(65,91,140))
local closeBtn = makeButton(panel, "FECHAR", UDim2.fromOffset(10,109), UDim2.fromOffset(265,28), Color3.fromRGB(105,65,65))

local function stopTest()
    running = false
    reportText = makeReport()
    statusLabel.Text = "Teste pronto (" .. #samples .. " amostras). Toque COPIAR RELATÓRIO."
    print(reportText)
end
startBtn.Activated:Connect(function()
    if running then return end
    samples, inputCounts, inputDeltas = {}, {}, {}
    running = true
    startClock = os.clock()
    statusLabel.Text = "GRAVANDO 12s: gire devagar e depois rápido; não use slider."
    task.spawn(function()
        local nextSample = 0
        while running and os.clock() - startClock < duration do
            local elapsed = os.clock() - startClock
            if elapsed >= nextSample then
                table.insert(samples, readState(elapsed))
                nextSample = nextSample + 0.1
            end
            task.wait(0.02)
        end
        if running then stopTest() end
    end)
end)
copyBtn.Activated:Connect(function()
    if #samples == 0 then
        statusLabel.Text = "Primeiro toque INICIAR TESTE."
        return
    end
    reportText = makeReport()
    local copied = false
    if type(setclipboard) == "function" then copied = pcall(setclipboard, reportText) end
    if copied then
        statusLabel.Text = "Relatório copiado! Cola aqui no chat."
    else
        statusLabel.Text = "Relatório no console (F9); copie e mande aqui."
        print(reportText)
    end
end)
closeBtn.Activated:Connect(function()
    if type(ENV.__MemeDashCameraX9Cleanup) == "function" then
        ENV.__MemeDashCameraX9Cleanup()
    else
        running = false
        pcall(function() gui:Destroy() end)
    end
end)

connections[#connections+1] = UIS.InputChanged:Connect(function(input)
    if not running then return end
    local key = input.UserInputType.Name
    inputCounts[key] = (inputCounts[key] or 0) + 1
    local delta = input.Delta
    if delta and (#inputDeltas < 5000) then
        table.insert(inputDeltas, {x=delta.X or 0, y=delta.Y or 0})
    end
end)
connections[#connections+1] = UIS.TouchMoved:Connect(function(touch, processed)
    if not running then return end
    local key = "TouchMoved"
    inputCounts[key] = (inputCounts[key] or 0) + 1
    local delta = touch.Delta
    if delta and #inputDeltas < 5000 then
        table.insert(inputDeltas, {x=delta.X or 0, y=delta.Y or 0})
    end
end)
ENV.__MemeDashCameraX9Cleanup = function()
    running = false
    for _, c in ipairs(connections) do pcall(function() c:Disconnect() end) end
    pcall(function() gui:Destroy() end)
    ENV.__MemeDashCameraX9Cleanup = nil
end
print("[MEMEDASH-X9] Pronto. Inicie o teste e mova a câmera por 12 segundos.")
