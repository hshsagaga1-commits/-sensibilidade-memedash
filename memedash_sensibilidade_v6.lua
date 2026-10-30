-- MEMEDASH CAMERA SENSITIVITY v6.0 (experimental / X9-informed)
-- Only for the MemeDash Scriptable camera. Client-side only.
-- X9 result: camera yaw and HumanoidRootPart yaw track 1:1.
-- V5.2 failed by comparing consecutive RAW yaw angles while the previous
-- frame's corrected yaw was already fed back to the custom controller.
-- V6 tracks the PREVIOUS OUTPUT yaw for horizontal movement, and RAW pitch
-- increments separately. It does not alter WalkSpeed, joystick or jump.
-- Root YAW is corrected (rotation only) to keep MemeDash body/camera aligned.
-- No promises: this cannot guarantee the internal controller's update order.

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local player = Players.LocalPlayer
assert(player, "Execute no cliente do MemeDash.")
local pg = player:WaitForChild("PlayerGui")
local ENV = (type(getgenv) == "function" and getgenv()) or _G

-- Prevent the incompatible V5.2 and duplicate V6 from running simultaneously.
if type(ENV.__MemeDashCameraSensitivityCleanup) == "function" then
    pcall(ENV.__MemeDashCameraSensitivityCleanup)
end
if type(ENV.__MemeDashSensitivityV6Cleanup) == "function" then
    pcall(ENV.__MemeDashSensitivityV6Cleanup)
end
for _, name in ipairs({"MemeDashCameraSensitivityGui", "MemeDashSensitivityV6"}) do
    local previous = pg:FindFirstChild(name)
    if previous then pcall(function() previous:Destroy() end) end
end

local MIN, MAX, STEP = 0.1, 2.0, 0.1
local PLACE_ID = 134001816760598
local BIND_NAME = "MemeDashSensitivityV6_" .. tostring(player.UserId)
local multiplier = 1.0
local enabled, alive = true, true
local activeTouches, connections = {}, {}
local lastCameraMove = -100
local lastOutputYaw, lastOutputPitch, lastRawPitch = nil, nil, nil
local lastCameraInstance, lastRootInstance = nil, nil
local statusText = "ORIGINAL 1.0x"
local statusClock = 0
local adjustmentFrames = 0
local resetFrames = 0
local skippedFrames = 0
local bound = false

local function connect(signal, fn)
    local c = signal:Connect(fn)
    connections[#connections + 1] = c
    return c
end
local function normalize(a)
    return math.atan2(math.sin(a), math.cos(a))
end
local function yawDifference(a, b)
    return normalize(a - b)
end
local function getRoot()
    local c = player.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end
local function resetReference()
    lastOutputYaw, lastOutputPitch, lastRawPitch = nil, nil, nil
    lastCameraInstance, lastRootInstance = nil, nil
end
local function effectiveSetMultiplier(v)
    local num = math.clamp(tonumber(v) or 1, MIN, MAX)
    num = math.floor(num / STEP + 0.5) * STEP
    multiplier = math.floor(num * 10 + 0.5) / 10
    resetReference()
end

local gui = Instance.new("ScreenGui")
gui.Name = "MemeDashSensitivityV6"
gui.ResetOnSpawn = false
gui.DisplayOrder = 900001
gui.IgnoreGuiInset = false
gui.Parent = pg

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(0.5, 0)
panel.Position = UDim2.new(0.5, 0, 0.10, 0)
panel.Size = UDim2.fromOffset(318, 194)
panel.BackgroundColor3 = Color3.fromRGB(21, 24, 33)
panel.BorderSizePixel = 0
panel.Active = true
panel.Parent = gui
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 11)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -55, 0, 30)
title.Position = UDim2.fromOffset(11, 5)
title.Text = "MEMEDASH SENS • V6"
title.BackgroundTransparency = 1
title.TextColor3 = Color3.fromRGB(167, 215, 255)
title.Font = Enum.Font.GothamBold
title.TextSize = 14
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = panel

local close = Instance.new("TextButton")
close.Size = UDim2.fromOffset(34, 29)
close.Position = UDim2.new(1, -41, 0, 5)
close.Text = "X"
close.TextColor3 = Color3.new(1, 1, 1)
close.BackgroundColor3 = Color3.fromRGB(142, 56, 70)
close.BorderSizePixel = 0
close.Font = Enum.Font.GothamBold
close.TextSize = 14
close.Parent = panel
Instance.new("UICorner", close).CornerRadius = UDim.new(0, 7)

local value = Instance.new("TextLabel")
value.Size = UDim2.new(1, -22, 0, 30)
value.Position = UDim2.fromOffset(11, 37)
value.Text = "1.0x • ORIGINAL"
value.Font = Enum.Font.GothamBold
value.TextSize = 18
value.TextColor3 = Color3.new(1,1,1)
value.BackgroundTransparency = 1
value.Parent = panel

local slider = Instance.new("Frame")
slider.Name = "Slider"
slider.Position = UDim2.fromOffset(16, 80)
slider.Size = UDim2.new(1, -32, 0, 10)
slider.BackgroundColor3 = Color3.fromRGB(70, 78, 94)
slider.BorderSizePixel = 0
slider.Active = true
slider.Parent = panel
Instance.new("UICorner", slider).CornerRadius = UDim.new(1,0)

local fill = Instance.new("Frame")
fill.Size = UDim2.new(0,0,1,0)
fill.BackgroundColor3 = Color3.fromRGB(67, 171, 252)
fill.BorderSizePixel = 0
fill.Parent = slider
Instance.new("UICorner", fill).CornerRadius = UDim.new(1,0)

local knob = Instance.new("Frame")
knob.AnchorPoint = Vector2.new(0.5,0.5)
knob.Position = UDim2.new(0.5,0,0.5,0)
knob.Size = UDim2.fromOffset(20,20)
knob.BackgroundColor3 = Color3.new(1,1,1)
knob.Active = true
knob.BorderSizePixel = 0
knob.Parent = slider
Instance.new("UICorner", knob).CornerRadius = UDim.new(1,0)

local function makeLabel(txt, pos, size)
    local l = Instance.new("TextLabel")
    l.Position = pos
    l.Size = size
    l.Text = txt
    l.Font = Enum.Font.Gotham
    l.TextColor3 = Color3.fromRGB(162, 174, 191)
    l.TextSize = 10
    l.BackgroundTransparency = 1
    l.Parent = panel
    return l
end
local leftLabel = makeLabel("0.1x", UDim2.fromOffset(16,98), UDim2.fromOffset(40,17))
local rightLabel = makeLabel("2.0x", UDim2.new(1,-56,0,98), UDim2.fromOffset(40,17))
rightLabel.TextXAlignment = Enum.TextXAlignment.Right

local function button(txt, pos, size, color)
    local b = Instance.new("TextButton")
    b.Size = size
    b.Position = pos
    b.Text = txt
    b.TextColor3 = Color3.new(1,1,1)
    b.Font = Enum.Font.GothamBold
    b.TextSize = 11
    b.BackgroundColor3 = color
    b.BorderSizePixel = 0
    b.Parent = panel
    Instance.new("UICorner", b).CornerRadius = UDim.new(0,7)
    return b
end
local half = button("0.5x", UDim2.fromOffset(11,121), UDim2.new(0.20,0,0,29), Color3.fromRGB(63, 75, 94))
local normal = button("1.0x", UDim2.new(.23,0,0,121), UDim2.new(.20,0,0,29), Color3.fromRGB(63, 75, 94))
local double = button("2.0x", UDim2.new(.45,0,0,121), UDim2.new(.20,0,0,29), Color3.fromRGB(63, 75, 94))
local toggle = button("ON", UDim2.new(.68,0,0,121), UDim2.new(.29,0,0,29), Color3.fromRGB(30, 132, 89))

local status = makeLabel("ORIGINAL 1.0x", UDim2.fromOffset(11,155), UDim2.new(1,-22,0,30))
status.TextSize = 10
status.TextWrapped = true
status.TextXAlignment = Enum.TextXAlignment.Left

local function renderUI()
    if not alive then return end
    local a = (multiplier - MIN) / (MAX - MIN)
    fill.Size = UDim2.new(a,0,1,0)
    knob.Position = UDim2.new(a,0,0.5,0)
    value.Text = string.format("%.1fx", multiplier) .. (multiplier == 1 and " • ORIGINAL" or " • EXPERIMENTAL")
    toggle.Text = enabled and "ON" or "OFF"
    toggle.BackgroundColor3 = enabled and Color3.fromRGB(30,132,89) or Color3.fromRGB(147,59,73)
    status.Text = statusText
end

local sliding, sliderInput = false, nil
local dragging, dragInput, dragStart, panelStart = false, nil, nil, nil
local function sliderUpdate(x)
    if slider.AbsoluteSize.X <= 0 then return end
    local a = math.clamp((x - slider.AbsolutePosition.X) / slider.AbsoluteSize.X, 0, 1)
    effectiveSetMultiplier(MIN + (MAX - MIN) * a)
    statusText = "AJUSTADO • verificando camera"
    renderUI()
end
local function beginSlide(input)
    if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
        sliding, sliderInput = true, input
        sliderUpdate(input.Position.X)
    end
end
connect(slider.InputBegan, beginSlide)
connect(knob.InputBegan, beginSlide)
connect(title.InputBegan, function(input)
    if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging, dragInput, dragStart, panelStart = true, input, input.Position, panel.Position
    end
end)
connect(UIS.InputChanged, function(input)
    local moveMouse = input.UserInputType == Enum.UserInputType.MouseMovement
    if sliding and (input == sliderInput or (moveMouse and sliderInput
        and sliderInput.UserInputType == Enum.UserInputType.MouseButton1)) then
        sliderUpdate(input.Position.X)
    end
    if dragging and dragStart and panelStart and (input == dragInput or (moveMouse and dragInput
        and dragInput.UserInputType == Enum.UserInputType.MouseButton1)) then
        local d = input.Position - dragStart
        panel.Position = UDim2.new(panelStart.X.Scale, panelStart.X.Offset + d.X,
            panelStart.Y.Scale, panelStart.Y.Offset + d.Y)
    end
end)
connect(UIS.InputEnded, function(input)
    if input == sliderInput or (sliderInput and
        sliderInput.UserInputType == Enum.UserInputType.MouseButton1 and
        input.UserInputType == Enum.UserInputType.MouseButton1) then
        sliding, sliderInput = false, nil
    end
    if input == dragInput or (dragInput and
        dragInput.UserInputType == Enum.UserInputType.MouseButton1 and
        input.UserInputType == Enum.UserInputType.MouseButton1) then
        dragging, dragInput, dragStart, panelStart = false, nil, nil, nil
    end
end)

local function withinPanel(pos)
    local p,s = panel.AbsolutePosition, panel.AbsoluteSize
    return pos.X >= p.X and pos.X <= p.X+s.X and pos.Y >= p.Y and pos.Y <= p.Y+s.Y
end
connect(UIS.TouchStarted, function(input)
    local cam = Workspace.CurrentCamera
    local w = cam and cam.ViewportSize.X or 724
    if not withinPanel(input.Position) and input.Position.X > w * 0.42 then
        activeTouches[input] = input.Position
    end
end)
connect(UIS.TouchMoved, function(input)
    local prev = activeTouches[input]
    if prev then
        if (input.Position - prev).Magnitude > 0.1 then
            lastCameraMove = os.clock()
        end
        activeTouches[input] = input.Position
    end
end)
connect(UIS.TouchEnded, function(input)
    if activeTouches[input] then
        lastCameraMove = os.clock()
        activeTouches[input] = nil
    end
end)
local function cameraGestureActive()
    local now = os.clock()
    if now - lastCameraMove < 0.085 then return true end
    return false
end

local function cleanup()
    if not alive then return end
    alive, enabled = false, false
    if bound then
        pcall(function() RunService:UnbindFromRenderStep(BIND_NAME) end)
        bound = false
    end
    for _, c in ipairs(connections) do pcall(function() c:Disconnect() end) end
    table.clear(connections)
    if gui then gui:Destroy() end
    if ENV.__MemeDashSensitivityV6Cleanup == cleanup then
        ENV.__MemeDashSensitivityV6Cleanup = nil
    end
    ENV.MemeDashSensitivityV6 = nil
end
ENV.__MemeDashSensitivityV6Cleanup = cleanup
connect(close.Activated, cleanup)
connect(toggle.Activated, function()
    enabled = not enabled
    resetReference()
    statusText = enabled and "ATIVADO • aguarde camera" or "DESATIVADO • controle original"
    renderUI()
end)
for b,n in pairs({[half]=0.5,[normal]=1.0,[double]=2.0}) do
    connect(b.Activated, function()
        effectiveSetMultiplier(n)
        statusText = n == 1 and "ORIGINAL 1.0x" or "AJUSTADO • experimental"
        renderUI()
    end)
end

local function sample(dt)
    if not alive then return end
    if not enabled or multiplier == 1 then
        resetReference()
        statusText = enabled and "ORIGINAL 1.0x • sem alteracoes" or "DESATIVADO • sem alteracoes"
        return
    end
    local cam = Workspace.CurrentCamera
    local root = getRoot()
    if not cam or cam.CameraType ~= Enum.CameraType.Scriptable or not root then
        resetReference()
        statusText = "Aguardando camera Scriptable / personagem"
        return
    end
    local raw = cam.CFrame
    local pitch, yaw, roll = raw:ToOrientation()
    local _, rootYaw = root.CFrame:ToOrientation()
    if cam ~= lastCameraInstance or root ~= lastRootInstance or lastOutputYaw == nil then
        lastCameraInstance, lastRootInstance = cam, root
        lastOutputYaw, lastOutputPitch, lastRawPitch = yaw, pitch, pitch
        statusText = "SINCRONIZADO • camera e corpo"
        return
    end
    if dt <= 0 or dt > 0.15 then
        resetFrames = resetFrames + 1
        resetReference()
        statusText = "Pausa/lag detectado • referencia reiniciada"
        return
    end
    local rawYawChange = yawDifference(yaw, lastOutputYaw)
    local rawPitchChange = yawDifference(pitch, lastRawPitch)
    if math.abs(rawYawChange) > math.rad(65) or math.abs(rawPitchChange) > math.rad(50) then
        resetFrames = resetFrames + 1
        resetReference()
        statusText = "Giro brusco/teleporte • referencia reiniciada"
        return
    end
    -- X9 proved the body's YAW and the camera's YAW should match.
    -- If they do not, it is unsafe to force the root direction.
    if math.abs(yawDifference(rootYaw, yaw)) > math.rad(6) then
        skippedFrames = skippedFrames + 1
        resetReference()
        statusText = "Camera/corpo divergentes • ajuste suspenso"
        return
    end

    -- Crucial fix vs V5.2:
    -- Yaw is relative to the previous CORRECTED yaw (the in-game root
    -- tracks that yaw). Pitch is relative to the previous RAW pitch
    -- (the custom controller likely maintains its own pitch).
    -- Do not multiply the same prior correction a second time.
    local gesture = cameraGestureActive()
    local factor = gesture and multiplier or 1
    local outputYaw = normalize(lastOutputYaw + rawYawChange * factor)
    local outputPitch = math.clamp(lastOutputPitch + rawPitchChange * factor,
        math.rad(-85), math.rad(85))
    local yawCorrection = yawDifference(outputYaw, yaw)
    local pitchCorrection = outputPitch - pitch

    if math.abs(yawCorrection) > math.rad(18) then
        skippedFrames = skippedFrames + 1
        resetReference()
        statusText = "Correcao acima do limite • reset de seguranca"
        return
    end

    if math.abs(yawCorrection) > 0.000001 or math.abs(pitchCorrection) > 0.000001 then
        -- Preserve original camera POSITION, FOV and roll.
        cam.CFrame = CFrame.new(raw.Position) * CFrame.fromOrientation(
            outputPitch, outputYaw, roll)
        if math.abs(yawCorrection) > 0.000001 then
            -- Only yaw rotation: never change translation or movement speed.
            root.CFrame = CFrame.new(root.Position)
                * CFrame.Angles(0, yawCorrection, 0)
                * root.CFrame.Rotation
        end
        adjustmentFrames = adjustmentFrames + 1
    end
    lastOutputYaw = outputYaw
    lastOutputPitch = outputPitch
    lastRawPitch = pitch
    if gesture then
        statusText = string.format("ATIVO %.1fx • ajustes:%d", multiplier, adjustmentFrames)
    else
        statusText = "ESTAVEL • aguardando movimento do dedo"
    end
end

local ok, err = pcall(function()
    RunService:BindToRenderStep(BIND_NAME, Enum.RenderPriority.Last.Value + 55, sample)
end)
bound = ok
if not ok then
    statusText = "ERRO no BindToRenderStep: " .. tostring(err)
    warn("[MemeDash V6] " .. tostring(err))
end

-- Avoid expensive UI work at every render frame.
connect(RunService.Heartbeat, function(dt)
    statusClock = statusClock + dt
    if statusClock >= 0.25 then
        statusClock = 0
        renderUI()
    end
end)

if game.PlaceId ~= PLACE_ID then
    statusText = "AVISO: nao parece ser o MemeDash (PlaceId diferente)"
end
renderUI()

ENV.MemeDashSensitivityV6 = {
    Version = "6.0",
    SetMultiplier = function(n) effectiveSetMultiplier(n); renderUI() end,
    GetMultiplier = function() return multiplier end,
    SetEnabled = function(b) enabled = b ~= false; resetReference(); renderUI() end,
    GetStatus = function() return statusText end,
    GetMetrics = function()
        return {adjustmentFrames=adjustmentFrames, resetFrames=resetFrames,
            skippedFrames=skippedFrames}
    end,
    Cleanup = cleanup
}
print("[MemeDash V6] X9-informed. 1.0x default. To disable, tap OFF or X.")
return ENV.MemeDashSensitivityV6
