-- MEMEDASH DIAGNOSTIC v1.1 - read-only
-- Prints a startup marker before collecting anything. Does not change sensitivity.
print("[MEMEDASH-DIAG] SCRIPT_INICIADO v1.1")

local ok, fatal = pcall(function()
    local Players = game:GetService("Players")
    local UIS = game:GetService("UserInputService")
    local RunService = game:GetService("RunService")
    local GuiService = game:GetService("GuiService")
    local Workspace = game:GetService("Workspace")
    local player = Players.LocalPlayer

    local function log(s) print("[MEMEDASH-DIAG] " .. tostring(s)) end
    local function v2(v)
        return string.format("(%.1f, %.1f)", v.X, v.Y)
    end

    if not player then
        log("ERRO: LocalPlayer indisponivel. O script precisa executar no cliente.")
        return
    end

    log("=== START v1.1 ===")
    log("TouchEnabled=" .. tostring(UIS.TouchEnabled))
    log("MouseEnabled=" .. tostring(UIS.MouseEnabled))
    log("KeyboardEnabled=" .. tostring(UIS.KeyboardEnabled))
    log("GamepadEnabled=" .. tostring(UIS.GamepadEnabled))

    local maxTouchOk, maxTouch = pcall(function() return UIS.MaxTouchCount end)
    log("MaxTouchCount=" .. (maxTouchOk and tostring(maxTouch) or "propriedade indisponivel"))
    local cam = Workspace.CurrentCamera
    log("Viewport=" .. (cam and v2(cam.ViewportSize) or "camera indisponivel"))

    local insetOk, tl, br = pcall(function()
        local a, b = GuiService:GetGuiInset()
        return a, b
    end)
    if insetOk then
        log("GuiInsetTopLeft=" .. v2(tl))
        log("GuiInsetBottomRight=" .. v2(br))
    else
        log("GuiInset falhou: " .. tostring(tl))
    end

    if cam then
        log("CameraType=" .. tostring(cam.CameraType))
        log("CameraMode=" .. tostring(player.CameraMode))
        log("FOV=" .. tostring(cam.FieldOfView))
        log("CameraSubject=" .. tostring(cam.CameraSubject))
    end

    local guiCount, visibleCount = 0, 0
    local playerGui = player:FindFirstChildOfClass("PlayerGui")
    if playerGui then
        for _, obj in ipairs(playerGui:GetDescendants()) do
            if obj:IsA("GuiObject") then
                guiCount += 1
                if obj.Visible then
                    visibleCount += 1
                    log(string.format("GUI %s | %s | pos=%s | size=%s | z=%d | active=%s",
                        obj:GetFullName(), obj.ClassName, v2(obj.AbsolutePosition),
                        v2(obj.AbsoluteSize), obj.ZIndex, tostring(obj.Active)))
                end
            end
        end
    else
        log("PlayerGui indisponivel")
    end
    log("GUI total=" .. guiCount .. " visiveis=" .. visibleCount)
    log("Agora mova o dedo pela tela por 12 segundos.")

    local starts, moves, ends = 0, 0, 0
    local processedStarts, processedMoves = 0, 0
    local firstTouch, lastTouch, lastDelta
    local cameraMovingFrames, cameraAngleTotal = 0, 0
    local previousCFrame = Workspace.CurrentCamera and Workspace.CurrentCamera.CFrame
    local lastMoveLog = 0
    local connections = {}
    local finished = false
    local startTime = os.clock()

    connections[#connections + 1] = UIS.TouchStarted:Connect(function(input, processed)
        starts += 1
        if processed then processedStarts += 1 end
        firstTouch = firstTouch or input.Position
        lastTouch = input.Position
        log("TOUCH_START pos=" .. v2(input.Position) .. " processed=" .. tostring(processed))
    end)

    connections[#connections + 1] = UIS.TouchMoved:Connect(function(input, processed)
        moves += 1
        if processed then processedMoves += 1 end
        lastTouch, lastDelta = input.Position, input.Delta
        if os.clock() - lastMoveLog >= 0.5 then
            lastMoveLog = os.clock()
            log("TOUCH_MOVE pos=" .. v2(input.Position) .. " delta=" .. v2(input.Delta)
                .. " processed=" .. tostring(processed))
        end
    end)

    connections[#connections + 1] = UIS.TouchEnded:Connect(function(input, processed)
        ends += 1
        lastTouch = input.Position
        log("TOUCH_END pos=" .. v2(input.Position) .. " processed=" .. tostring(processed))
    end)

    connections[#connections + 1] = RunService.RenderStepped:Connect(function()
        local current = Workspace.CurrentCamera
        if current and previousCFrame then
            local a, b = previousCFrame.LookVector, current.CFrame.LookVector
            local dot = math.clamp(a:Dot(b), -1, 1)
            local angle = math.deg(math.acos(dot))
            if angle > 0.001 then
                cameraMovingFrames += 1
                cameraAngleTotal += angle
            end
        end
        if current then previousCFrame = current.CFrame end

        if not finished and os.clock() - startTime >= 12 then
            finished = true
            for _, c in ipairs(connections) do pcall(function() c:Disconnect() end) end
            log("--- RESUMO ---")
            log("TouchStarts=" .. starts .. " TouchEnds=" .. ends .. " TouchMoves=" .. moves)
            log("ProcessedStarts=" .. processedStarts .. " ProcessedMoves=" .. processedMoves)
            log("FirstTouch=" .. (firstTouch and v2(firstTouch) or "none"))
            log("LastTouch=" .. (lastTouch and v2(lastTouch) or "none"))
            log("LastDelta=" .. (lastDelta and v2(lastDelta) or "none"))
            log("CameraMovingFrames=" .. cameraMovingFrames)
            log(string.format("AccumulatedLookAngleDegrees=%.3f", cameraAngleTotal))
            log("=== FIM DO DIAGNOSTICO ===")
        end
    end)
end)

if not ok then
    warn("[MEMEDASH-DIAG] ERRO_FATAL: " .. tostring(fatal))
end
