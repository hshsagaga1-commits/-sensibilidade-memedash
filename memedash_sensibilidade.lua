-- MEMEDASH CAMERA SENSITIVITY v4.0
-- Applies sensitivity to Scriptable camera rotation deltas only; does not change character movement.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local ENV = (type(getgenv) == "function" and getgenv()) or _G

local VERSION = "MemeDashScriptableCameraSensitivity-4.0"
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
local gui, valueLabel, fill, knob, toggleButton
local connections = {}
local closed = false
local hookStatus = "aguardando camera Scriptable"
local renderName = "MemeDashCameraSensitivityRender"
local lastRawCFrame = nil
local lastAdjustedRotation = nil
local bound = false

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
    if bound then
        pcall(function() RunService:UnbindFromRenderStep(renderName) end)
        pcall(function() RunService:UnbindFromRenderStep(renderName .. "_Pre") end)
        bound = false
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

-- Camera Scriptable sensitivity: capture before the game's camera update,
-- then scale that frame's delta after the game has applied it.
local cameraBefore = nil
local preName = renderName .. "_Pre"

local preOk = pcall(function()
    RunService:BindToRenderStep(preName, Enum.RenderPriority.Camera.Value - 1, function()
        if closed then return end
        local cam = workspace.CurrentCamera
        if not cam or cam.CameraType ~= Enum.CameraType.Scriptable then
            cameraBefore = nil
            return
        end
        cameraBefore = cam.CFrame
    end)
end)

local postOk = pcall(function()
    RunService:BindToRenderStep(renderName, Enum.RenderPriority.Camera.Value + 1, function()
        if closed then return end
        local cam = workspace.CurrentCamera
        if not cam then
            cameraBefore = nil
            hookStatus = "aguardando camera"
            refresh()
            return
        end

        local current = cam.CFrame
        if cam.CameraType ~= Enum.CameraType.Scriptable then
            cameraBefore = current
            hookStatus = "camera nao Scriptable"
            refresh()
            return
        end

        if not enabled then
            cameraBefore = current
            hookStatus = "camera: sensibilidade OFF"
            refresh()
            return
        end

        if not cameraBefore then
            cameraBefore = current
            hookStatus = "sensibilidade ativa; calibrando"
            refresh()
            return
        end

        -- Scale only the camera's frame rotation delta. Do not rotate the
        -- HumanoidRootPart: the game's own controller remains responsible for body alignment.
        local delta = cameraBefore.Rotation:ToObjectSpace(current.Rotation)
        local axis, angle = delta:ToAxisAngle()

        -- Ignore large discontinuities caused by respawn/camera resets.
        if angle > math.rad(90) then
            cameraBefore = current
            hookStatus = "reset de camera ignorado"
            refresh()
            return
        end

        local output = current
        if angle > 0.00001 then
            local scaledDelta = CFrame.fromAxisAngle(axis, angle * multiplier)
            output = CFrame.new(current.Position) * (cameraBefore.Rotation * scaledDelta)
            cam.CFrame = output
        end

        cameraBefore = output
        hookStatus = preOk and postOk and "sensibilidade Scriptable ativa" or "erro ao ligar captura"
        refresh()
    end)
end)

local bindOk = preOk and postOk
bound = bindOk
if not bindOk then
    pcall(function() RunService:UnbindFromRenderStep(preName) end)
    pcall(function() RunService:UnbindFromRenderStep(renderName) end)
end

if not bindOk then hookStatus = "erro ao iniciar sensibilidade Scriptable" end
refresh()

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
