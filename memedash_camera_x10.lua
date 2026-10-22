-- MemeDash Camera X10 — passive frame-level diagnostic
-- Read-only: observes touch input and camera rotation; does not modify camera or character.
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
if not player then return end
local pg = player:WaitForChild("PlayerGui")
local old = pg:FindFirstChild("MemeDashX10")
if old then old:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name = "MemeDashX10"
gui.ResetOnSpawn = false
gui.DisplayOrder = 1000
gui.Parent = pg
local frame = Instance.new("Frame")
frame.Size = UDim2.fromOffset(320, 190)
frame.Position = UDim2.new(0.5, -160, 0.5, -95)
frame.BackgroundColor3 = Color3.fromRGB(22,24,30)
frame.BorderSizePixel = 0
frame.Parent = gui
Instance.new("UICorner", frame).CornerRadius = UDim.new(0,10)
local function makeLabel(txt, y, h)
    local l = Instance.new("TextLabel")
    l.BackgroundTransparency = 1
    l.Position = UDim2.fromOffset(12,y)
    l.Size = UDim2.new(1,-24,0,h or 24)
    l.Font = Enum.Font.Gotham
    l.TextSize = 13
    l.TextColor3 = Color3.fromRGB(235,238,245)
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.TextWrapped = true
    l.Text = txt
    l.Parent = frame
    return l
end
makeLabel("MEMEDASH CAMERA X10",10,24).Font = Enum.Font.GothamBold
local status = makeLabel("Registra rotação entre frames e toque.",36,30)
local function button(txt, x, width, color)
    local b = Instance.new("TextButton")
    b.Position = UDim2.fromOffset(x,75)
    b.Size = UDim2.fromOffset(width,34)
    b.BackgroundColor3 = color
    b.TextColor3 = Color3.new(1,1,1)
    b.Font = Enum.Font.GothamBold
    b.TextSize = 12
    b.Text = txt
    b.Parent = frame
    Instance.new("UICorner", b).CornerRadius = UDim.new(0,7)
    return b
end
local startBtn = button("INICIAR 10s",12,142,Color3.fromRGB(48,104,170))
local copyBtn = button("COPIAR RELATÓRIO",164,144,Color3.fromRGB(62,70,83))
makeLabel("Somente leitura • sem alterações na câmera",117,20)
local closeBtn = Instance.new("TextButton")
closeBtn.Position = UDim2.fromOffset(12,148)
closeBtn.Size = UDim2.new(1,-24,0,28)
closeBtn.BackgroundColor3 = Color3.fromRGB(80,45,49)
closeBtn.TextColor3 = Color3.new(1,1,1)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 12
closeBtn.Text = "FECHAR"
closeBtn.Parent = frame
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0,7)

local report = "MEMEDASH CAMERA X10\nNenhuma coleta feita."
local running = false
local activeTouches = {}
local touchBegan, touchChanged, sumDx, sumDy = 0,0,0,0
local rows = {}
local function cameraAngleDelta(a,b)
    if not a or not b then return 0 end
    local rel = a:ToObjectSpace(b)
    local _, angle = rel:ToAxisAngle()
    return math.deg(math.abs(angle))
end
UIS.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch then
        touchBegan += 1
        activeTouches[input] = input.Position
    end
end)
UIS.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch then
        touchChanged += 1
        local p = input.Position
        local prev = activeTouches[input]
        if prev then
            sumDx += p.X-prev.X
            sumDy += p.Y-prev.Y
        end
        activeTouches[input] = p
    end
end)
UIS.InputEnded:Connect(function(input)
    activeTouches[input] = nil
end)

local function runScan()
    if running then return end
    running = true
    touchBegan,touchChanged,sumDx,sumDy,rows = 0,0,0,0,{}
    startBtn.Text = "COLETANDO..."
    status.Text = "Mova a câmera normalmente por 10 segundos."
    local t0 = os.clock()
    local prevCF = workspace.CurrentCamera and workspace.CurrentCamera.CFrame
    local prevT = t0
    local maxAngle, totalAngle, samples = 0,0,0
    local lastPrint = -1
    while os.clock()-t0 < 10 do
        RunService.RenderStepped:Wait()
        local now = os.clock()
        local cam = workspace.CurrentCamera
        local cf = cam and cam.CFrame
        if cf and prevCF then
            local dt = now-prevT
            local angle = cameraAngleDelta(prevCF,cf)
            totalAngle += angle
            maxAngle = math.max(maxAngle,angle)
            samples += 1
            if now-t0 >= lastPrint+0.1 then
                local relative = prevCF:ToObjectSpace(cf)
                local rx,ry,rz = relative:ToOrientation()
                table.insert(rows,string.format("%.2f,dt=%.3f,camStep=%.2fdeg,relX=%.2f,relY=%.2f,relZ=%.2f,touchBegan=%d,touchChanged=%d",
                    now-t0,dt,angle,math.deg(rx),math.deg(ry),math.deg(rz),touchBegan,touchChanged))
                lastPrint = now-t0
            end
        end
        prevCF = cf
        prevT = now
    end
    local char = player.Character
    local cameraScript = char and char:FindFirstChild("camera")
    report = "MEMEDASH CAMERA X10 REPORT\n"
      .. "PlaceId="..tostring(game.PlaceId).." | duration=10s | frameSamples="..samples.."\n"
      .. "CAMERA: type="..tostring(workspace.CurrentCamera and workspace.CurrentCamera.CameraType.Name)
      .. " subject="..tostring(workspace.CurrentCamera and workspace.CurrentCamera.CameraSubject and workspace.CurrentCamera.CameraSubject.ClassName)
      .. " FOV="..tostring(workspace.CurrentCamera and workspace.CurrentCamera.FieldOfView).."\n"
      .. "CHARACTER CAMERA SCRIPT INSTANCE: "..tostring(cameraScript and cameraScript:GetFullName() or "not found")
      .. " | class="..tostring(cameraScript and cameraScript.ClassName or "nil").."\n"
      .. "TOUCH EVENTS: began="..touchBegan.." changed="..touchChanged
      .. " | summed delta X="..string.format("%.1f",sumDx).." Y="..string.format("%.1f",sumDy).."\n"
      .. "CAMERA RELATIVE ROTATION: accumulated="..string.format("%.1f",totalAngle)
      .. "deg | max single frame step="..string.format("%.2f",maxAngle).."deg\n"
      .. "SAMPLES: t,dt,camStep,relative Euler deltas, cumulative touch event counts\n"
      .. table.concat(rows,"\n")
      .. "\nNOTE: This observes camera motion only; it does not read hidden script source or change input/camera."
    status.Text = "Concluído! Copie o relatório."
    startBtn.Text = "INICIAR DE NOVO"
    running = false
end
startBtn.MouseButton1Click:Connect(runScan)
copyBtn.MouseButton1Click:Connect(function()
    if typeof(setclipboard)=="function" then
        setclipboard(report)
        status.Text = "Relatório copiado!"
    else
        status.Text = "Clipboard indisponível neste executor."
    end
end)
closeBtn.MouseButton1Click:Connect(function() gui:Destroy() end)
