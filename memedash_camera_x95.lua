-- MemeDash Camera X9.5 — read-only diagnostic
-- Does not modify camera, character, or input. Uses only ordinary accessible Roblox instances.
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
if not player then return end

local old = player:FindFirstChildOfClass("PlayerGui"):FindFirstChild("MemeDashX95")
if old then old:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name = "MemeDashX95"
gui.ResetOnSpawn = false
gui.DisplayOrder = 999
gui.Parent = player:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.Size = UDim2.fromOffset(320, 230)
frame.Position = UDim2.new(0.5, -160, 0.5, -115)
frame.BackgroundColor3 = Color3.fromRGB(22, 24, 30)
frame.BorderSizePixel = 0
frame.Parent = gui
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 10)

local function label(text, y, h)
    local l = Instance.new("TextLabel")
    l.BackgroundTransparency = 1
    l.Position = UDim2.fromOffset(12, y)
    l.Size = UDim2.new(1, -24, 0, h or 24)
    l.Font = Enum.Font.Gotham
    l.TextSize = 13
    l.TextColor3 = Color3.fromRGB(235, 238, 245)
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.TextWrapped = true
    l.Text = text
    l.Parent = frame
    return l
end

label("MEMEDASH CAMERA X9.5", 10, 25).Font = Enum.Font.GothamBold
local status = label("Pronto para coletar 12 segundos.", 38, 32)
local scan = Instance.new("TextButton")
scan.Position = UDim2.fromOffset(12, 77)
scan.Size = UDim2.fromOffset(142, 34)
scan.BackgroundColor3 = Color3.fromRGB(48, 104, 170)
scan.TextColor3 = Color3.new(1,1,1)
scan.Font = Enum.Font.GothamBold
scan.TextSize = 12
scan.Text = "INICIAR X9.5"
scan.Parent = frame
Instance.new("UICorner", scan).CornerRadius = UDim.new(0, 7)

local copy = Instance.new("TextButton")
copy.Position = UDim2.fromOffset(164, 77)
copy.Size = UDim2.fromOffset(142, 34)
copy.BackgroundColor3 = Color3.fromRGB(62, 70, 83)
copy.TextColor3 = Color3.new(1,1,1)
copy.Font = Enum.Font.GothamBold
copy.TextSize = 12
copy.Text = "COPIAR RELATÓRIO"
copy.Parent = frame
Instance.new("UICorner", copy).CornerRadius = UDim.new(0, 7)
label("Somente leitura • não altera a câmera", 119, 20)
local close = Instance.new("TextButton")
close.Position = UDim2.fromOffset(12, 155)
close.Size = UDim2.new(1, -24, 0, 30)
close.BackgroundColor3 = Color3.fromRGB(80, 45, 49)
close.TextColor3 = Color3.new(1,1,1)
close.Font = Enum.Font.GothamBold
close.TextSize = 12
close.Text = "FECHAR"
close.Parent = frame
Instance.new("UICorner", close).CornerRadius = UDim.new(0, 7)

local report = "MEMEDASH CAMERA X9.5\nNenhuma coleta feita."
local running = false
local touchEvents, touchMoved, inputDx, inputDy = 0, 0, 0, 0
local lastTouch = {}
local samples = {}
local function getYaw(cf)
    local _, y, _ = cf:ToOrientation()
    return math.deg(y)
end
local function wrapDelta(a, b)
    return (a - b + 180) % 360 - 180
end
local function listScripts(root, rootName, out)
    if not root then return end
    for _, obj in ipairs(root:GetDescendants()) do
        if obj:IsA("LocalScript") or obj:IsA("ModuleScript") then
            local n = obj.Name:lower()
            if n:find("camera") or n:find("input") or n:find("control") or n:find("touch")
                or n:find("shift") or n:find("player") or n:find("mobile") or n:find("sens") then
                table.insert(out, rootName .. "/" .. obj:GetFullName() .. " [" .. obj.ClassName .. "]")
            end
        end
    end
end

UIS.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch then
        touchEvents += 1
        lastTouch[input] = input.Position
    end
end)
UIS.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch then
        touchEvents += 1
        touchMoved += 1
        local prev = lastTouch[input]
        if prev then
            inputDx += input.Position.X - prev.X
            inputDy += input.Position.Y - prev.Y
        end
        lastTouch[input] = input.Position
    end
end)
UIS.InputEnded:Connect(function(input)
    lastTouch[input] = nil
end)

local function collect()
    if running then return end
    running = true
    touchEvents, touchMoved, inputDx, inputDy, samples = 0, 0, 0, 0, {}
    scan.Text = "COLETANDO..."
    status.Text = "Mova a câmera normalmente por 12 segundos."
    local start = os.clock()
    local nextAt = 0
    while os.clock() - start < 12 do
        local t = os.clock() - start
        if t >= nextAt then
            local cam = workspace.CurrentCamera
            local char = player.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            local root = char and char:FindFirstChild("HumanoidRootPart")
            local head = char and char:FindFirstChild("Head")
            table.insert(samples, string.format("%.1f,camYaw=%.1f,camPitch=%.1f,rootYaw=%s,headYaw=%s,camType=%s,FOV=%.1f,AutoRotate=%s",
                t,
                cam and getYaw(cam.CFrame) or 0,
                cam and math.deg(select(1, cam.CFrame:ToOrientation())) or 0,
                root and string.format("%.1f", getYaw(root.CFrame)) or "nil",
                head and string.format("%.1f", getYaw(head.CFrame)) or "nil",
                cam and cam.CameraType.Name or "nil",
                cam and cam.FieldOfView or 0,
                hum and tostring(hum.AutoRotate) or "nil"))
            nextAt += 0.2
        end
        RunService.Heartbeat:Wait()
    end
    local scripts = {}
    listScripts(player:FindFirstChildOfClass("PlayerGui"), "PlayerGui", scripts)
    listScripts(player:FindFirstChild("PlayerScripts"), "PlayerScripts", scripts)
    listScripts(player.Character, "Character", scripts)
    local cam = workspace.CurrentCamera
    local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    report = "MEMEDASH CAMERA X9.5 REPORT\n"
        .. "PlaceId=" .. tostring(game.PlaceId) .. " | samples=" .. #samples .. " | duration=12s\n"
        .. "NOW: cameraType=" .. (cam and cam.CameraType.Name or "nil")
        .. " subject=" .. (cam and cam.CameraSubject and cam.CameraSubject.ClassName or "nil")
        .. " FOV=" .. tostring(cam and cam.FieldOfView or "nil")
        .. " AutoRotate=" .. tostring(hum and hum.AutoRotate or "nil") .. "\n"
        .. "TOUCH: events=" .. touchEvents .. " moved=" .. touchMoved
        .. " | summed delta X=" .. string.format("%.1f", inputDx)
        .. " Y=" .. string.format("%.1f", inputDy) .. "\n"
        .. "ACCESSIBLE SCRIPT NAME MATCHES (" .. #scripts .. "):\n"
        .. (#scripts > 0 and table.concat(scripts, "\n") or "(nenhum script acessível com nome relacionado)") .. "\n"
        .. "SAMPLES: t,camYaw,camPitch,rootYaw,headYaw,camType,FOV,AutoRotate\n"
        .. table.concat(samples, "\n")
        .. "\nNOTE: scripts internos inacessíveis não podem ser enumerados por APIs normais."
    status.Text = "Concluído! Toque em COPIAR RELATÓRIO."
    scan.Text = "INICIAR DE NOVO"
    running = false
end

scan.MouseButton1Click:Connect(collect)
copy.MouseButton1Click:Connect(function()
    if typeof(setclipboard) == "function" then
        setclipboard(report)
        status.Text = "Relatório copiado!"
    else
        status.Text = "Clipboard indisponível; relatório guardado no script."
    end
end)
close.MouseButton1Click:Connect(function() gui:Destroy() end)
