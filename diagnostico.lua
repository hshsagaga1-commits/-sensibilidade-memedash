-- MEMEDASH DIAGNOSTIC v1.2 - visible on-screen, read-only
local ok, err = pcall(function()
    local Players = game:GetService("Players")
    local UIS = game:GetService("UserInputService")
    local RunService = game:GetService("RunService")
    local Workspace = game:GetService("Workspace")
    local player = Players.LocalPlayer
    assert(player, "LocalPlayer indisponivel; execute no cliente")

    local gui = Instance.new("ScreenGui")
    gui.Name = "MemeDashDiagnostic"
    gui.ResetOnSpawn = false
    gui.DisplayOrder = 999999
    gui.Parent = player:WaitForChild("PlayerGui")

    local panel = Instance.new("TextLabel")
    panel.Name = "DiagnosticPanel"
    panel.Size = UDim2.new(0.88, 0, 0, 220)
    panel.Position = UDim2.new(0.06, 0, 0.08, 0)
    panel.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
    panel.BackgroundTransparency = 0.12
    panel.TextColor3 = Color3.fromRGB(255, 255, 255)
    panel.TextSize = 14
    panel.Font = Enum.Font.Code
    panel.TextXAlignment = Enum.TextXAlignment.Left
    panel.TextYAlignment = Enum.TextYAlignment.Top
    panel.TextWrapped = true
    panel.Active = true
    panel.Text = "MEMEDASH DIAGNOSTIC v1.2\nIniciado; preparando captura..."
    panel.Parent = gui

    local lines = {}
    local function log(s)
        lines[#lines + 1] = tostring(s)
        while #lines > 12 do table.remove(lines, 1) end
        panel.Text = table.concat(lines, "\n")
        print("[MEMEDASH-DIAG] " .. tostring(s))
    end
    local function v2(v) return string.format("(%.0f, %.0f)", v.X, v.Y) end

    log("SCRIPT EXECUTOU OK")
    log("TouchEnabled=" .. tostring(UIS.TouchEnabled))
    log("Viewport=" .. (Workspace.CurrentCamera and v2(Workspace.CurrentCamera.ViewportSize) or "sem camera"))
    log("Arraste o dedo na tela por 12 segundos.")

    local starts, moves, ends = 0, 0, 0
    local processedStarts, processedMoves = 0, 0
    local lastTouch, lastDelta = nil, nil
    local cameraFrames, cameraAngle = 0, 0
    local previous = Workspace.CurrentCamera and Workspace.CurrentCamera.CFrame
    local lastLog = 0
    local startedAt = os.clock()
    local finished = false
    local conns = {}

    conns[#conns + 1] = UIS.TouchStarted:Connect(function(input, processed)
        starts = starts + 1
        if processed then processedStarts = processedStarts + 1 end
        lastTouch = input.Position
        log("TOUCH_START " .. v2(input.Position) .. " processed=" .. tostring(processed))
    end)
    conns[#conns + 1] = UIS.TouchMoved:Connect(function(input, processed)
        moves = moves + 1
        if processed then processedMoves = processedMoves + 1 end
        lastTouch, lastDelta = input.Position, input.Delta
        if os.clock() - lastLog >= 0.5 then
            lastLog = os.clock()
            log("MOVE " .. v2(input.Position) .. " delta=" .. v2(input.Delta))
        end
    end)
    conns[#conns + 1] = UIS.TouchEnded:Connect(function(input)
        ends = ends + 1
        lastTouch = input.Position
        log("TOUCH_END " .. v2(input.Position))
    end)
    conns[#conns + 1] = RunService.RenderStepped:Connect(function()
        local cam = Workspace.CurrentCamera
        if cam and previous then
            local dot = math.clamp(previous.LookVector:Dot(cam.CFrame.LookVector), -1, 1)
            local angle = math.deg(math.acos(dot))
            if angle > 0.001 then
                cameraFrames = cameraFrames + 1
                cameraAngle = cameraAngle + angle
            end
        end
        if cam then previous = cam.CFrame end

        if not finished and os.clock() - startedAt >= 12 then
            finished = true
            for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
            log("--- RESUMO ---")
            log("Starts=" .. starts .. " Ends=" .. ends .. " Moves=" .. moves)
            log("Processed=" .. processedStarts .. "/" .. processedMoves)
            log("LastTouch=" .. (lastTouch and v2(lastTouch) or "none"))
            log("LastDelta=" .. (lastDelta and v2(lastDelta) or "none"))
            log("CameraFrames=" .. cameraFrames)
            log(string.format("CameraAngleTotal=%.2f deg", cameraAngle))
            log("Feche removendo este painel.")
        end
    end)
end)

if not ok then
    warn("[MEMEDASH-DIAG] ERRO: " .. tostring(err))
end
