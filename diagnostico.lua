--[[
    SENSIBILIDADE MEMEDASH
    Diagnostico universal de tela / Roblox mobile
    v1.0 - somente leitura; nao altera a sensibilidade.
    
    O que coleta:
    - recursos de entrada do dispositivo e dimensoes da tela
    - CameraType, CameraMode, FOV e movimento da camera
    - elementos GUI visiveis e seus limites
    - posicoes/deltas de toque durante uma janela curta
    
    Limites:
    - nao consegue ler scripts privados do jogo nem identificar com certeza
      qual script consome cada toque.
    - os logs de TouchMoved sao resumidos para evitar excesso.
]]

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
if not player then
    warn("[MEMEDASH-DIAG] LocalPlayer indisponivel; execute em contexto local.")
    return
end

local report = {}
local function log(message)
    local line = tostring(message)
    report[#report + 1] = line
    print("[MEMEDASH-DIAG] " .. line)
end

local function vec2(v)
    return string.format("(%.1f, %.1f)", v.X, v.Y)
end

local function inspectCamera()
    local cam = Workspace.CurrentCamera
    if not cam then
        log("Camera: indisponivel")
        return nil
    end
    log("--- CAMERA ---")
    log("CameraType=" .. tostring(cam.CameraType))
    log("CameraMode=" .. tostring(player.CameraMode))
    log("FOV=" .. tostring(cam.FieldOfView))
    log("Viewport=" .. vec2(cam.ViewportSize))
    log("CFrame=" .. tostring(cam.CFrame))
    log("Focus=" .. tostring(cam.Focus))
    log("Subject=" .. tostring(cam.CameraSubject))
    return cam
end

log("=== MEMEDASH SCREEN DIAGNOSTIC v1.0 ===")
log("TouchEnabled=" .. tostring(UIS.TouchEnabled))
log("MouseEnabled=" .. tostring(UIS.MouseEnabled))
log("KeyboardEnabled=" .. tostring(UIS.KeyboardEnabled))
log("GamepadEnabled=" .. tostring(UIS.GamepadEnabled))
log("MaxTouchCount=" .. tostring(UIS.MaxTouchCount))
log("ScreenResolution=" .. vec2(Workspace.CurrentCamera and Workspace.CurrentCamera.ViewportSize or Vector2.zero))

local topLeft, bottomRight = GuiService:GetGuiInset()
log("GuiInsetTopLeft=" .. vec2(topLeft))
log("GuiInsetBottomRight=" .. vec2(bottomRight))

local cam = inspectCamera()

log("--- VISIBLE GUI OBJECTS ---")
local playerGui = player:FindFirstChildOfClass("PlayerGui")
local guiCount, visibleCount = 0, 0
if playerGui then
    for _, obj in ipairs(playerGui:GetDescendants()) do
        if obj:IsA("GuiObject") then
            guiCount += 1
            if obj.Visible then
                visibleCount += 1
                log(string.format("%s | %s | pos=%s | size=%s | z=%d | active=%s",
                    obj:GetFullName(), obj.ClassName,
                    vec2(obj.AbsolutePosition), vec2(obj.AbsoluteSize),
                    obj.ZIndex, tostring(obj.Active)))
            end
        end
    end
else
    log("PlayerGui indisponivel")
end
log("GuiObjectsTotal=" .. guiCount .. " Visible=" .. visibleCount)

log("--- TOUCH SAMPLE: 12 SECONDS ---")
log("Arraste o dedo em varias areas da tela, inclusive onde gira a camera.")
log("Toques serao resumidos; nenhuma configuracao sera alterada.")

local touchStarts, touchMoves, touchEnds = 0, 0, 0
local processedStarts, processedMoves = 0, 0
local firstTouch, lastTouch, lastDelta = nil, nil, nil
local cameraMovingFrames, cameraAngleTotal = 0, 0
local previousCamera = Workspace.CurrentCamera and Workspace.CurrentCamera.CFrame
local connections = {}
local startTime = os.clock()
local lastMoveLog = 0
local finished = false

connections[#connections + 1] = UIS.TouchStarted:Connect(function(input, processed)
    touchStarts += 1
    if processed then processedStarts += 1 end
    firstTouch = firstTouch or input.Position
    lastTouch = input.Position
    log(string.format("TOUCH_START pos=%s processed=%s", vec2(input.Position), tostring(processed)))
end)

connections[#connections + 1] = UIS.TouchMoved:Connect(function(input, processed)
    touchMoves += 1
    if processed then processedMoves += 1 end
    lastTouch = input.Position
    lastDelta = input.Delta
    if os.clock() - lastMoveLog >= 0.5 then
        lastMoveLog = os.clock()
        log(string.format("TOUCH_MOVE pos=%s delta=%s processed=%s",
            vec2(input.Position), vec2(input.Delta), tostring(processed)))
    end
end)

connections[#connections + 1] = UIS.TouchEnded:Connect(function(input, processed)
    touchEnds += 1
    lastTouch = input.Position
    log(string.format("TOUCH_END pos=%s processed=%s", vec2(input.Position), tostring(processed)))
end)

connections[#connections + 1] = RunService.RenderStepped:Connect(function()
    local current = Workspace.CurrentCamera
    if current and previousCamera then
        local a, b = previousCamera.LookVector, current.CFrame.LookVector
        local angle = math.deg(math.acos(math.clamp(a:Dot(b), -1, 1)))
        if angle > 0.001 then
            cameraMovingFrames += 1
            cameraAngleTotal += angle
        end
    end
    if current then previousCamera = current.CFrame end

    if not finished and os.clock() - startTime >= 12 then
        finished = true
        for _, connection in ipairs(connections) do
            connection:Disconnect()
        end

        log("--- SUMMARY ---")
        log("TouchStarts=" .. touchStarts .. " TouchEnds=" .. touchEnds)
        log("TouchMoves=" .. touchMoves)
        log("ProcessedStarts=" .. processedStarts .. " ProcessedMoves=" .. processedMoves)
        log("FirstTouch=" .. (firstTouch and vec2(firstTouch) or "none"))
        log("LastTouch=" .. (lastTouch and vec2(lastTouch) or "none"))
        log("LastDelta=" .. (lastDelta and vec2(lastDelta) or "none"))
        log("CameraMovingFrames=" .. cameraMovingFrames)
        log(string.format("AccumulatedLookAngleDegrees=%.3f", cameraAngleTotal))
        log("=== END REPORT ===")
        log("Copie os logs com prefixo [MEMEDASH-DIAG] e envie aqui.")
    end
end)
