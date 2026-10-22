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
    if not valueLabel then return end
    local alpha = (multiplier - MIN) / (MAX - MIN)
    valueLabel.Text = string.format("%.1fx  |  %s", multiplier, hookStatus)
    fill.Size = UDim2.fromScale(alpha, 1)
    knob.Position = UDim2.fromScale(alpha, 0.5)
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

local function button(parent, text, size, pos, color)
    local b = Instance.new("TextButton")
    b.Size, b.Position = size, pos
    b.BackgroundColor3, b.BorderSizePixel = color, 0
    b.Text, b.TextColor3 = text, Color3.new(1,1,1)
    b.Font, b.TextSize = Enum.Font.GothamBold, 11
    b.Parent = parent
    Instance.new("UICorner", b).CornerRadius = UDim.new(0,7)
    return b
end

local parent
pcall(function() if type(gethui) == "function" then parent = gethui() end end)
if not parent then parent = playerGui end
gui = Instance.new("ScreenGui")
gui.Name, gui.ResetOnSpawn, gui.DisplayOrder = GUI_NAME, false, 1000000
gui.Parent = playerGui

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.Size = UDim2.fromOffset(265, 142)
panel.Position = UDim2.new(0.5,-132,0.12,0)
panel.BackgroundColor3, panel.BorderSizePixel = Color3.fromRGB(23,25,31), 0
panel.Active, panel.Parent = true, gui
Instance.new("UICorner", panel).CornerRadius = UDim.new(0,10)

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Position, title.Size = UDim2.fromOffset(10,5), UDim2.new(1,-48,0,22)
title.Text, title.TextColor3 = "MEMEDASH • CAMERA INPUT", Color3.fromRGB(245,245,248)
title.Font, title.TextSize, title.TextXAlignment = Enum.Font.GothamBold, 12, Enum.TextXAlignment.Left
title.Parent = panel
local close = button(panel,"X",UDim2.fromOffset(26,22),UDim2.new(1,-32,0,5),Color3.fromRGB(105,58,62))
close.Activated:Connect(cleanup)

valueLabel = Instance.new("TextLabel")
valueLabel.BackgroundTransparency = 1
valueLabel.Position, valueLabel.Size = UDim2.fromOffset(12,29), UDim2.new(1,-24,0,24)
valueLabel.TextColor3, valueLabel.Font, valueLabel.TextSize = Color3.fromRGB(225,230,240), Enum.Font.GothamMedium, 11
valueLabel.TextXAlignment = Enum.TextXAlignment.Left
valueLabel.Parent = panel

-- Cria os controles principais ANTES do slider, para um erro visual não deixar só metade do painel.
local toggle = button(panel,"CAMERA: ON",UDim2.new(1,-24,0,28),UDim2.fromOffset(12,98),Color3.fromRGB(42,126,82))
toggleButton = toggle
toggle.Activated:Connect(function()
    enabled = not enabled
    refresh()
end)

local bar = Instance.new("Frame")
bar.Name = "Slider"
bar.Position = UDim2.fromOffset(14,59)
bar.Size = UDim2.new(1,-28,0,12)
bar.BackgroundColor3 = Color3.fromRGB(68,72,82)
bar.BorderSizePixel = 0
bar.Active = true
bar.ClipsDescendants = false
bar.Parent = panel

fill = Instance.new("Frame")
fill.Name = "Fill"
fill.BackgroundColor3 = Color3.fromRGB(90,165,255)
fill.BorderSizePixel = 0
fill.Size = UDim2.new((multiplier-MIN)/(MAX-MIN),0,1,0)
fill.Position = UDim2.new(0,0,0,0)
fill.ZIndex = bar.ZIndex + 1
fill.Parent = bar

knob = Instance.new("Frame")
knob.Name = "Knob"
knob.AnchorPoint = Vector2.new(0.5,0.5)
knob.Position = UDim2.new((multiplier-MIN)/(MAX-MIN),0,0.5,0)
knob.Size = UDim2.fromOffset(18,18)
knob.BackgroundColor3 = Color3.fromRGB(250,250,252)
knob.BorderSizePixel = 0
knob.ZIndex = fill.ZIndex + 1
knob.Active = true
knob.Parent = bar

pcall(function() Instance.new("UICorner", bar).CornerRadius = UDim.new(1,0) end)
pcall(function() Instance.new("UICorner", fill).CornerRadius = UDim.new(1,0) end)
pcall(function() Instance.new("UICorner", knob).CornerRadius = UDim.new(1,0) end)

local sliding, slideInput = false, nil
local function updateX(x)
    local width = bar.AbsoluteSize.X
    if width <= 0 then return end
    setMultiplier(MIN + (MAX-MIN) * math.clamp((x-bar.AbsolutePosition.X)/width,0,1))
    refresh()
end
connections[#connections+1] = bar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
        sliding, slideInput = true, input
        updateX(input.Position.X)
    end
end)
connections[#connections+1] = knob.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
        sliding, slideInput = true, input
        updateX(input.Position.X)
    end
end)
connections[#connections+1] = UserInputService.InputChanged:Connect(function(input)
    if sliding and (input == slideInput or (slideInput and slideInput.UserInputType == Enum.UserInputType.MouseButton1 and input.UserInputType == Enum.UserInputType.MouseMovement)) then
        updateX(input.Position.X)
    end
end)
connections[#connections+1] = UserInputService.InputEnded:Connect(function(input)
    if input == slideInput or (slideInput and slideInput.UserInputType == Enum.UserInputType.MouseButton1 and input.UserInputType == Enum.UserInputType.MouseButton1) then
        sliding, slideInput = false, nil
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
