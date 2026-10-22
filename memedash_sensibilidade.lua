-- MEMEDASH CAMERA SENSITIVITY v1.0
-- Separate script for MemeDash-style Scriptable cameras.
-- Scales camera rotation deltas after the game updates CurrentCamera.CFrame.
-- Does not change movement speed, jump, or character controls.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local ENV = (type(getgenv) == "function" and getgenv()) or _G

local VERSION = "MemeDashCameraSensitivity-1.0"
local GUI_NAME = "MemeDashCameraSensitivityGui"
local BIND_NAME = "__MemeDashCameraSensitivity"
local MIN_MULTIPLIER, MAX_MULTIPLIER, STEP = 0.1, 2.0, 0.1

local player = Players.LocalPlayer
assert(player, "LocalPlayer indisponivel; execute no cliente")
local playerGui = player:WaitForChild("PlayerGui")

local oldCleanup = ENV.__MemeDashCameraSensitivityCleanup
if type(oldCleanup) == "function" then pcall(oldCleanup) end
pcall(function() RunService:UnbindFromRenderStep(BIND_NAME) end)
local oldGui = playerGui:FindFirstChild(GUI_NAME)
if oldGui then pcall(function() oldGui:Destroy() end) end

local multiplier = tonumber(ENV.MemeDashCameraSensitivityMultiplier) or 1
multiplier = math.clamp(multiplier, MIN_MULTIPLIER, MAX_MULTIPLIER)
local enabled = true
local camera = Workspace.CurrentCamera
local lastRawRotation = camera and camera.CFrame.Rotation
local outputRotation = lastRawRotation
local connections = {}
local gui
local valueLabel
local fill
local knob
local enabledButton
local sliding = false
local slideInput = nil
local closed = false

local function setMultiplier(value)
    value = math.clamp(tonumber(value) or 1, MIN_MULTIPLIER, MAX_MULTIPLIER)
    value = math.floor(value / STEP + 0.5) * STEP
    multiplier = math.clamp(math.floor(value * 10 + 0.5) / 10, MIN_MULTIPLIER, MAX_MULTIPLIER)
    ENV.MemeDashCameraSensitivityMultiplier = multiplier
    return multiplier
end

local function refreshUI()
    if not valueLabel or not fill or not knob then return end
    local alpha = (multiplier - MIN_MULTIPLIER) / (MAX_MULTIPLIER - MIN_MULTIPLIER)
    fill.Size = UDim2.fromScale(alpha, 1)
    knob.Position = UDim2.fromScale(alpha, 0.5)
    valueLabel.Text = string.format("%.1fx", multiplier)
    if enabledButton then
        enabledButton.Text = enabled and "SENSIBILIDADE: ON" or "SENSIBILIDADE: OFF"
        enabledButton.BackgroundColor3 = enabled and Color3.fromRGB(42, 126, 82) or Color3.fromRGB(105, 65, 65)
    end
end

local function resetCameraState()
    camera = Workspace.CurrentCamera
    if camera then
        lastRawRotation = camera.CFrame.Rotation
        outputRotation = lastRawRotation
    else
        lastRawRotation = nil
        outputRotation = nil
    end
end

local function setEnabled(value)
    enabled = value ~= false
    resetCameraState()
    refreshUI()
end

local function updateFromX(x)
    local bar = gui and gui:FindFirstChild("Panel") and gui.Panel:FindFirstChild("Slider")
    if not bar then return end
    local width = bar.AbsoluteSize.X
    if width <= 0 then return end
    local alpha = math.clamp((x - bar.AbsolutePosition.X) / width, 0, 1)
    setMultiplier(MIN_MULTIPLIER + (MAX_MULTIPLIER - MIN_MULTIPLIER) * alpha)
    refreshUI()
end

local function cleanup()
    if closed then return end
    closed = true
    pcall(function() RunService:UnbindFromRenderStep(BIND_NAME) end)
    for _, connection in ipairs(connections) do
        pcall(function() connection:Disconnect() end)
    end
    table.clear(connections)
    if camera and lastRawRotation and outputRotation then
        -- Leave the camera at its latest raw/game-provided orientation when closing.
        pcall(function() camera.CFrame = CFrame.new(camera.CFrame.Position) * lastRawRotation end)
    end
    if gui then pcall(function() gui:Destroy() end) end
    ENV.MemeDashCameraSensitivity = nil
    ENV.__MemeDashCameraSensitivityCleanup = nil
end

local function createButton(parent, text, size, position, color)
    local button = Instance.new("TextButton")
    button.Size = size
    button.Position = position
    button.BackgroundColor3 = color
    button.BorderSizePixel = 0
    button.Text = text
    button.TextColor3 = Color3.new(1, 1, 1)
    button.Font = Enum.Font.GothamBold
    button.TextSize = 11
    button.AutoButtonColor = true
    button.Parent = parent
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 7)
    corner.Parent = button
    return button
end

gui = Instance.new("ScreenGui")
gui.Name = GUI_NAME
gui.ResetOnSpawn = false
gui.DisplayOrder = 1000000
gui.IgnoreGuiInset = false
gui.Parent = playerGui

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.Size = UDim2.fromOffset(252, 136)
panel.Position = UDim2.new(0.5, -126, 0.12, 0)
panel.BackgroundColor3 = Color3.fromRGB(23, 25, 31)
panel.BorderSizePixel = 0
panel.Active = true
panel.Parent = gui
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 10)

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Position = UDim2.fromOffset(10, 5)
title.Size = UDim2.new(1, -54, 0, 24)
title.Text = "MEMEDASH • SENSIBILIDADE"
title.TextColor3 = Color3.fromRGB(245, 245, 248)
title.Font = Enum.Font.GothamBold
title.TextSize = 12
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = panel

local closeButton = createButton(panel, "X", UDim2.fromOffset(28, 24), UDim2.new(1, -34, 0, 5), Color3.fromRGB(105, 58, 62))
closeButton.Activated:Connect(cleanup)

valueLabel = Instance.new("TextLabel")
valueLabel.BackgroundTransparency = 1
valueLabel.Position = UDim2.fromOffset(12, 32)
valueLabel.Size = UDim2.new(1, -24, 0, 20)
valueLabel.TextColor3 = Color3.fromRGB(225, 230, 240)
valueLabel.Font = Enum.Font.GothamMedium
valueLabel.TextSize = 13
valueLabel.TextXAlignment = Enum.TextXAlignment.Left
valueLabel.Parent = panel

local bar = Instance.new("Frame")
bar.Name = "Slider"
bar.Position = UDim2.fromOffset(14, 59)
bar.Size = UDim2.new(1, -28, 0, 10)
bar.BackgroundColor3 = Color3.fromRGB(68, 72, 82)
bar.BorderSizePixel = 0
bar.Active = true
bar.Parent = panel
Instance.new("UICorner", bar).CornerRadius = UDim.new(1, 0)

fill = Instance.new("Frame")
fill.Name = "Fill"
fill.Size = UDim2.fromScale(0.4737, 1)
fill.BackgroundColor3 = Color3.fromRGB(90, 165, 255)
fill.BorderSizePixel = 0
fill.Parent = bar
Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)

knob = Instance.new("Frame")
knob.Name = "Knob"
knob.AnchorPoint = Vector2.new(0.5, 0.5)
knob.Position = UDim2.fromScale(0.4737, 0.5)
knob.Size = UDim2.fromOffset(18, 18)
knob.BackgroundColor3 = Color3.fromRGB(250, 250, 252)
knob.BorderSizePixel = 0
knob.Active = true
knob.Parent = bar
Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

local minLabel = Instance.new("TextLabel")
minLabel.BackgroundTransparency = 1
minLabel.Position = UDim2.fromOffset(12, 71)
minLabel.Size = UDim2.fromOffset(48, 14)
minLabel.Text = "0.1x"
minLabel.TextColor3 = Color3.fromRGB(155, 160, 170)
minLabel.Font = Enum.Font.Gotham
minLabel.TextSize = 10
minLabel.TextXAlignment = Enum.TextXAlignment.Left
minLabel.Parent = panel

local maxLabel = Instance.new("TextLabel")
maxLabel.BackgroundTransparency = 1
maxLabel.Position = UDim2.new(1, -58, 0, 71)
maxLabel.Size = UDim2.fromOffset(46, 14)
maxLabel.Text = "2.0x"
maxLabel.TextColor3 = Color3.fromRGB(155, 160, 170)
maxLabel.Font = Enum.Font.Gotham
maxLabel.TextSize = 10
maxLabel.TextXAlignment = Enum.TextXAlignment.Right
maxLabel.Parent = panel

enabledButton = createButton(panel, "SENSIBILIDADE: ON", UDim2.new(1, -24, 0, 28), UDim2.fromOffset(12, 96), Color3.fromRGB(42, 126, 82))
enabledButton.Activated:Connect(function()
    setEnabled(not enabled)
end)

local function beginSlide(input)
    if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
        sliding = true
        slideInput = input
        updateFromX(input.Position.X)
    end
end
connections[#connections + 1] = bar.InputBegan:Connect(beginSlide)
connections[#connections + 1] = knob.InputBegan:Connect(beginSlide)
connections[#connections + 1] = UserInputService.InputChanged:Connect(function(input)
    if sliding and (input == slideInput
        or (slideInput and slideInput.UserInputType == Enum.UserInputType.MouseButton1
            and input.UserInputType == Enum.UserInputType.MouseMovement)) then
        updateFromX(input.Position.X)
    end
end)
connections[#connections + 1] = UserInputService.InputEnded:Connect(function(input)
    if input == slideInput
        or (slideInput and slideInput.UserInputType == Enum.UserInputType.MouseButton1
            and input.UserInputType == Enum.UserInputType.MouseButton1) then
        sliding = false
        slideInput = nil
    end
end)

refreshUI()
resetCameraState()

RunService:BindToRenderStep(BIND_NAME, Enum.RenderPriority.Camera.Value + 1, function()
    if closed then return end
    local current = Workspace.CurrentCamera
    if not current then return end
    if current ~= camera or not lastRawRotation or not outputRotation then
        resetCameraState()
        return
    end

    local rawCFrame = current.CFrame
    local rawRotation = rawCFrame.Rotation

    if not enabled then
        lastRawRotation = rawRotation
        outputRotation = rawRotation
        return
    end

    local delta = lastRawRotation:ToObjectSpace(rawRotation)
    local axis, angle = delta:ToAxisAngle()
    if angle == angle and angle > 1e-6 then
        local scaledDelta = CFrame.fromAxisAngle(axis, angle * multiplier)
        outputRotation = outputRotation * scaledDelta
    end

    lastRawRotation = rawRotation
    current.CFrame = CFrame.new(rawCFrame.Position) * outputRotation
end)

ENV.MemeDashCameraSensitivity = {
    Version = VERSION,
    SetEnabled = setEnabled,
    SetMultiplier = function(value)
        local result = setMultiplier(value)
        refreshUI()
        return result
    end,
    GetMultiplier = function() return multiplier end,
    Cleanup = cleanup,
}
ENV.__MemeDashCameraSensitivityCleanup = cleanup

print("[MEMEDASH-SENS] " .. VERSION .. " iniciado | multiplicador=" .. string.format("%.1fx", multiplier))
print("[MEMEDASH-SENS] CameraType atual: " .. tostring(Workspace.CurrentCamera and Workspace.CurrentCamera.CameraType))
return ENV.MemeDashCameraSensitivity
