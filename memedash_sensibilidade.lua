-- MEMEDASH CAMERA INPUT SENSITIVITY v2.0
-- Native input-path approach adapted from the user's Evade camera controller.
-- IMPORTANT: this does NOT overwrite CurrentCamera.CFrame, preventing camera tug-of-war.
-- Works only if MemeDash consumes Roblox PlayerModule CameraInput.getRotation.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local ENV = (type(getgenv) == "function" and getgenv()) or _G

local VERSION = "MemeDashCameraInputSensitivity-2.0"
local GUI_NAME = "MemeDashCameraSensitivityGui"
local MIN, MAX, STEP = 0.1, 2.0, 0.1
local player = Players.LocalPlayer
assert(player, "Execute no cliente do jogo.")
local playerGui = player:WaitForChild("PlayerGui")

-- Remove stale copies left by older versions before building the interface.
for _, parent in ipairs({playerGui, CoreGui}) do
    local stale = parent:FindFirstChild(GUI_NAME)
    if stale then pcall(function() stale:Destroy() end) end
end

local previous = ENV.__MemeDashCameraSensitivityCleanup
if type(previous) == "function" then pcall(previous) end

local multiplier = math.clamp(tonumber(ENV.MemeDashCameraSensitivityMultiplier) or 1, MIN, MAX)
local enabled = true
local cameraInput, originalGetRotation, wrapper
local gui, valueLabel, fill, knob, toggleButton
local connections = {}
local closed = false
local hookStatus = "procurando CameraInput..."

local function findCameraInput()
    local scripts = player:FindFirstChild("PlayerScripts")
    local pm = scripts and scripts:FindFirstChild("PlayerModule")
    local cm = pm and pm:FindFirstChild("CameraModule")
    if not cm then return nil end
    local direct = cm:FindFirstChild("CameraInput")
    if direct and direct:IsA("ModuleScript") then return direct end
    for _, obj in ipairs(cm:GetDescendants()) do
        if obj:IsA("ModuleScript") and obj.Name == "CameraInput" then return obj end
    end
    return nil
end

local function attach()
    local module = findCameraInput()
    if not module then
        hookStatus = "CameraInput nao encontrado"
        return false
    end
    local ok, result = pcall(require, module)
    if not ok or type(result) ~= "table" or type(result.getRotation) ~= "function" then
        hookStatus = "CameraInput sem getRotation"
        return false
    end
    if cameraInput == result and result.getRotation == wrapper then
        hookStatus = "hook ativo"
        return true
    end
    if cameraInput and originalGetRotation and cameraInput.getRotation == wrapper then
        pcall(function() cameraInput.getRotation = originalGetRotation end)
    end
    cameraInput = result
    originalGetRotation = result.getRotation
    wrapper = function(...)
        local rotation = originalGetRotation(...)
        if not enabled or typeof(rotation) ~= "Vector2" then return rotation end
        return rotation * multiplier
    end
    local setOk = pcall(function() cameraInput.getRotation = wrapper end)
    hookStatus = setOk and "hook ativo" or "nao foi possivel instalar hook"
    return setOk
end

local function setMultiplier(value)
    multiplier = math.clamp(math.floor((tonumber(value) or 1) / STEP + 0.5) * STEP, MIN, MAX)
    multiplier = math.floor(multiplier * 10 + 0.5) / 10
    ENV.MemeDashCameraSensitivityMultiplier = multiplier
end

local function refresh()
    if not valueLabel or not fill or not knob or not toggleButton then return end
    local alpha = math.clamp((multiplier - MIN) / (MAX - MIN), 0, 1)
    valueLabel.Text = string.format("%.1fx", multiplier)
    local status = gui and gui:FindFirstChild("Panel") and gui.Panel:FindFirstChild("HookStatus")
    if status then status.Text = hookStatus end
    fill.Size = UDim2.new(alpha, 0, 1, 0)
    knob.Position = UDim2.new(alpha, 0, 0.5, 0)
    toggleButton.Text = enabled and "CAMERA: ON" or "CAMERA: OFF"
    toggleButton.BackgroundColor3 = enabled and Color3.fromRGB(42,126,82) or Color3.fromRGB(105,65,65)
end

local function cleanup()
    if closed then return end
    closed = true
    for _, c in ipairs(connections) do pcall(function() c:Disconnect() end) end
    table.clear(connections)
    if cameraInput and originalGetRotation and cameraInput.getRotation == wrapper then
        pcall(function() cameraInput.getRotation = originalGetRotation end)
    end
    if gui then pcall(function() gui:Destroy() end) end
    ENV.MemeDashCameraSensitivity = nil
    ENV.__MemeDashCameraSensitivityCleanup = nil
end

local function makeButton(parent, text, size, pos, color)
    local b = Instance.new("TextButton")
    b.Size = size
    b.Position = pos
    b.BackgroundColor3 = color
    b.BorderSizePixel = 0
    b.Text = text
    b.TextColor3 = Color3.new(1,1,1)
    b.Font = Enum.Font.GothamMedium
    b.TextSize = 12
    b.Parent = parent
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0,8)
    corner.Parent = b
    return b
end

-- Interface simples restaurada: título, valor, slider e botão.
-- A lógica da sensibilidade continua separada no hook CameraInput.
gui = Instance.new("ScreenGui")
gui.Name = GUI_NAME
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.DisplayOrder = 1000000
gui.Parent = playerGui

local frame = Instance.new("Frame")
frame.Name = "Panel"
frame.Size = UDim2.fromOffset(238,122)
frame.Position = UDim2.new(0.5,-119,0.14,0)
frame.BackgroundColor3 = Color3.fromRGB(24,24,27)
frame.BorderSizePixel = 0
frame.Active = true
frame.Parent = gui
local frameCorner = Instance.new("UICorner")
frameCorner.CornerRadius = UDim.new(0,10)
frameCorner.Parent = frame

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Position = UDim2.fromOffset(10,5)
title.Size = UDim2.new(1,-70,0,26)
title.Text = "MemeDash Sensibilidade"
title.TextColor3 = Color3.new(1,1,1)
title.Font = Enum.Font.GothamSemibold
title.TextSize = 13
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = frame

valueLabel = Instance.new("TextLabel")
valueLabel.BackgroundTransparency = 1
valueLabel.Position = UDim2.new(1,-62,0,5)
valueLabel.Size = UDim2.fromOffset(52,26)
valueLabel.TextColor3 = Color3.new(1,1,1)
valueLabel.Font = Enum.Font.GothamMedium
valueLabel.TextSize = 13
valueLabel.TextXAlignment = Enum.TextXAlignment.Right
valueLabel.Parent = frame

local bar = Instance.new("Frame")
bar.Name = "Slider"
bar.Position = UDim2.fromOffset(12,49)
bar.Size = UDim2.new(1,-24,0,8)
bar.BackgroundColor3 = Color3.fromRGB(72,72,78)
bar.BorderSizePixel = 0
bar.Active = true
bar.Parent = frame
local barCorner = Instance.new("UICorner")
barCorner.CornerRadius = UDim.new(1,0)
barCorner.Parent = bar

fill = Instance.new("Frame")
fill.Name = "Fill"
fill.BackgroundColor3 = Color3.fromRGB(235,235,240)
fill.BorderSizePixel = 0
fill.Size = UDim2.new(0,0,1,0)
fill.Parent = bar
local fillCorner = Instance.new("UICorner")
fillCorner.CornerRadius = UDim.new(1,0)
fillCorner.Parent = fill

knob = Instance.new("Frame")
knob.Name = "Knob"
knob.AnchorPoint = Vector2.new(0.5,0.5)
knob.Size = UDim2.fromOffset(18,18)
knob.BackgroundColor3 = Color3.fromRGB(250,250,250)
knob.BorderSizePixel = 0
knob.Active = true
knob.Parent = bar
local knobCorner = Instance.new("UICorner")
knobCorner.CornerRadius = UDim.new(1,0)
knobCorner.Parent = knob

local minLabel = Instance.new("TextLabel")
minLabel.BackgroundTransparency = 1
minLabel.Position = UDim2.fromOffset(12,62)
minLabel.Size = UDim2.fromOffset(40,16)
minLabel.Text = "0.1x"
minLabel.TextColor3 = Color3.fromRGB(160,160,168)
minLabel.Font = Enum.Font.Gotham
minLabel.TextSize = 10
minLabel.TextXAlignment = Enum.TextXAlignment.Left
minLabel.Parent = frame

local maxLabel = Instance.new("TextLabel")
maxLabel.BackgroundTransparency = 1
maxLabel.Position = UDim2.new(1,-52,0,62)
maxLabel.Size = UDim2.fromOffset(40,16)
maxLabel.Text = "2.0x"
maxLabel.TextColor3 = Color3.fromRGB(160,160,168)
maxLabel.Font = Enum.Font.Gotham
maxLabel.TextSize = 10
maxLabel.TextXAlignment = Enum.TextXAlignment.Right
maxLabel.Parent = frame

local statusLabel = Instance.new("TextLabel")
statusLabel.Name = "HookStatus"
statusLabel.BackgroundTransparency = 1
statusLabel.Position = UDim2.fromOffset(12, 64)
statusLabel.Size = UDim2.new(1, -24, 0, 14)
statusLabel.Text = hookStatus
statusLabel.TextColor3 = Color3.fromRGB(160,160,168)
statusLabel.Font = Enum.Font.Gotham
statusLabel.TextSize = 9
statusLabel.TextXAlignment = Enum.TextXAlignment.Center
statusLabel.Parent = frame

-- Keep the status separate from the value, without changing the simple old layout.
toggleButton = makeButton(frame,"CAMERA: ON",UDim2.new(1,-24,0,25),UDim2.fromOffset(12,87),Color3.fromRGB(48,105,175))
toggleButton.Activated:Connect(function()
    enabled = not enabled
    refresh()
end)

local function updateFromX(x)
    local width = bar.AbsoluteSize.X
    if width <= 0 then return end
    local alpha = math.clamp((x-bar.AbsolutePosition.X)/width,0,1)
    setMultiplier(MIN+(MAX-MIN)*alpha)
    refresh()
end

local sliding, slideInput = false, nil
local dragging, dragInput, dragStart, dragPosition = false, nil, nil, nil
local function beginSlide(input)
    if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
        sliding, slideInput = true, input
        updateFromX(input.Position.X)
    end
end
connections[#connections+1] = bar.InputBegan:Connect(beginSlide)
connections[#connections+1] = knob.InputBegan:Connect(beginSlide)
connections[#connections+1] = frame.InputBegan:Connect(function(input)
    if (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1)
        and input.Position.Y < bar.AbsolutePosition.Y-7 then
        dragging, dragInput, dragStart, dragPosition = true, input, input.Position, frame.Position
    end
end)
connections[#connections+1] = UserInputService.InputChanged:Connect(function(input)
    if sliding and (input == slideInput or (slideInput and slideInput.UserInputType == Enum.UserInputType.MouseButton1 and input.UserInputType == Enum.UserInputType.MouseMovement)) then
        updateFromX(input.Position.X)
    end
    if dragging and dragStart and dragPosition and (input == dragInput or (dragInput and dragInput.UserInputType == Enum.UserInputType.MouseButton1 and input.UserInputType == Enum.UserInputType.MouseMovement)) then
        local delta = input.Position-dragStart
        frame.Position = UDim2.new(dragPosition.X.Scale,dragPosition.X.Offset+delta.X,dragPosition.Y.Scale,dragPosition.Y.Offset+delta.Y)
    end
end)
connections[#connections+1] = UserInputService.InputEnded:Connect(function(input)
    if input == slideInput or (slideInput and slideInput.UserInputType == Enum.UserInputType.MouseButton1 and input.UserInputType == Enum.UserInputType.MouseButton1) then
        sliding, slideInput = false, nil
    end
    if input == dragInput or (dragInput and dragInput.UserInputType == Enum.UserInputType.MouseButton1 and input.UserInputType == Enum.UserInputType.MouseButton1) then
        dragging, dragInput, dragStart, dragPosition = false, nil, nil, nil
    end
end)

attach()
refresh()
local retry = 0
connections[#connections+1] = RunService.Heartbeat:Connect(function()
    if closed then return end
    retry += 1
    if retry % 30 == 0 and (not cameraInput or cameraInput.getRotation ~= wrapper) then
        attach()
        refresh()
    end
end)

ENV.MemeDashCameraSensitivity = {
    Version = VERSION,
    SetEnabled = function(v) enabled = v ~= false; refresh() end,
    SetMultiplier = function(v) setMultiplier(v); refresh(); return multiplier end,
    GetMultiplier = function() return multiplier end,
    GetStatus = function() return hookStatus end,
    Cleanup = cleanup,
}
ENV.__MemeDashCameraSensitivityCleanup = cleanup
print("[MEMEDASH-SENS] "..VERSION.." | "..hookStatus.." | multiplier="..string.format("%.1fx",multiplier))
return ENV.MemeDashCameraSensitivity
