-- MEMEDASH SCREEN X-RAY v2.0
-- Client-side diagnostic only: observes UI, touch regions, camera and local character.
-- It does not change sensitivity or game controls.

local ok, err = pcall(function()
    local Players = game:GetService("Players")
    local UIS = game:GetService("UserInputService")
    local RunService = game:GetService("RunService")
    local Workspace = game:GetService("Workspace")
    local GuiService = game:GetService("GuiService")
    local Stats = game:GetService("Stats")
    local player = Players.LocalPlayer
    assert(player, "LocalPlayer indisponivel; execute no cliente")

    local oldGui = player:WaitForChild("PlayerGui"):FindFirstChild("MemeDashDiagnostic")
    if oldGui then oldGui:Destroy() end

    local gui = Instance.new("ScreenGui")
    gui.Name = "MemeDashDiagnostic"
    gui.ResetOnSpawn = false
    gui.DisplayOrder = 999999
    gui.IgnoreGuiInset = false
    gui.Parent = player:WaitForChild("PlayerGui")

    local root = Instance.new("Frame")
    root.Name = "Root"
    root.Size = UDim2.new(0.94, 0, 0.78, 0)
    root.Position = UDim2.new(0.03, 0, 0.06, 0)
    root.BackgroundColor3 = Color3.fromRGB(18, 20, 27)
    root.BorderSizePixel = 0
    root.Parent = gui
    Instance.new("UICorner", root).CornerRadius = UDim.new(0, 10)

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -12, 0, 30)
    title.Position = UDim2.new(0, 6, 0, 4)
    title.BackgroundTransparency = 1
    title.Text = "MEMEDASH SCREEN X-RAY v2.0"
    title.TextColor3 = Color3.new(1,1,1)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 15
    title.Parent = root

    local status = Instance.new("TextLabel")
    status.Size = UDim2.new(1, -12, 0, 24)
    status.Position = UDim2.new(0, 6, 0, 34)
    status.BackgroundTransparency = 1
    status.Text = "Leitura local: UI + toque + camera + personagem"
    status.TextColor3 = Color3.fromRGB(170, 210, 255)
    status.Font = Enum.Font.Gotham
    status.TextSize = 11
    status.Parent = root

    local tabs = Instance.new("Frame")
    tabs.Size = UDim2.new(1, -12, 0, 34)
    tabs.Position = UDim2.new(0, 6, 0, 60)
    tabs.BackgroundTransparency = 1
    tabs.Parent = root
    local tabLayout = Instance.new("UIListLayout")
    tabLayout.FillDirection = Enum.FillDirection.Horizontal
    tabLayout.Padding = UDim.new(0, 4)
    tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
    tabLayout.Parent = tabs

    local scroll = Instance.new("ScrollingFrame")
    scroll.Name = "ReportScroll"
    scroll.Size = UDim2.new(1, -12, 1, -144)
    scroll.Position = UDim2.new(0, 6, 0, 98)
    scroll.BackgroundColor3 = Color3.fromRGB(8, 10, 15)
    scroll.BorderSizePixel = 0
    scroll.ScrollBarThickness = 8
    scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scroll.Parent = root
    Instance.new("UICorner", scroll).CornerRadius = UDim.new(0, 6)

    local reportLabel = Instance.new("TextLabel")
    reportLabel.Name = "ReportText"
    reportLabel.Size = UDim2.new(1, -12, 0, 0)
    reportLabel.Position = UDim2.new(0, 6, 0, 6)
    reportLabel.AutomaticSize = Enum.AutomaticSize.Y
    reportLabel.BackgroundTransparency = 1
    reportLabel.TextColor3 = Color3.fromRGB(235, 238, 245)
    reportLabel.Font = Enum.Font.Code
    reportLabel.TextSize = 12
    reportLabel.TextXAlignment = Enum.TextXAlignment.Left
    reportLabel.TextYAlignment = Enum.TextYAlignment.Top
    reportLabel.TextWrapped = true
    reportLabel.Parent = scroll

    local bottom = Instance.new("Frame")
    bottom.Size = UDim2.new(1, -12, 0, 38)
    bottom.Position = UDim2.new(0, 6, 1, -42)
    bottom.BackgroundTransparency = 1
    bottom.Parent = root
    local bottomLayout = Instance.new("UIListLayout")
    bottomLayout.FillDirection = Enum.FillDirection.Horizontal
    bottomLayout.Padding = UDim.new(0, 5)
    bottomLayout.SortOrder = Enum.SortOrder.LayoutOrder
    bottomLayout.Parent = bottom

    local function makeButton(parent, text, width, color)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(width, 0, 1, 0)
        b.BackgroundColor3 = color or Color3.fromRGB(48, 105, 175)
        b.TextColor3 = Color3.new(1,1,1)
        b.Text = text
        b.TextSize = 11
        b.Font = Enum.Font.GothamBold
        b.BorderSizePixel = 0
        b.Parent = parent
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
        return b
    end

    local copyButton = makeButton(bottom, "COPIAR", 0.29, Color3.fromRGB(38, 125, 80))
    local refreshButton = makeButton(bottom, "ATUALIZAR", 0.29, Color3.fromRGB(48, 105, 175))
    local closeButton = makeButton(bottom, "FECHAR", 0.29, Color3.fromRGB(100, 60, 65))

    local reportLines = {}
    local activeSection = "RESUMO"
    local function add(s)
        reportLines[#reportLines + 1] = tostring(s)
        print("[MEMEDASH-XRAY] " .. tostring(s))
    end
    local function safe(fn, fallback)
        local success, value = pcall(fn)
        if success then return value end
        return fallback or ("erro: " .. tostring(value))
    end
    local function vec2(v)
        return string.format("%.0f,%.0f", v.X, v.Y)
    end
    local function vec3(v)
        return string.format("%.2f, %.2f, %.2f", v.X, v.Y, v.Z)
    end
    local function setReport(text)
        reportLabel.Text = text
        task.defer(function()
            scroll.CanvasPosition = Vector2.new(0, 0)
        end)
    end

    local function scanUI()
        local out = {}
        local pg = player:FindFirstChildOfClass("PlayerGui")
        if not pg then return {"PlayerGui nao encontrado"} end
        local descendants = pg:GetDescendants()
        table.insert(out, "=== ELEMENTOS DE INTERFACE (PlayerGui) ===")
        table.insert(out, "Total de objetos descendentes: " .. #descendants)
        local count = 0
        for _, obj in ipairs(descendants) do
            if obj:IsA("GuiObject") then
                count = count + 1
                local p, s = obj.AbsolutePosition, obj.AbsoluteSize
                local visible = obj.Visible
                local text = ""
                if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
                    text = tostring(obj.Text):gsub("[%c]", " ")
                    if #text > 70 then text = string.sub(text, 1, 70) .. "..." end
                elseif obj:IsA("ImageLabel") or obj:IsA("ImageButton") then
                    text = " image=" .. tostring(obj.Image)
                end
                table.insert(out, string.format(
                    "%03d %s | %s | vis=%s | pos=(%s) size=(%s) | %s%s",
                    count, obj.ClassName, obj:GetFullName(), tostring(visible),
                    vec2(p), vec2(s), text, obj.Active and " | ACTIVE" or ""
                ))
                if count >= 250 then
                    table.insert(out, "...limite de 250 elementos; use nomes/caminhos para investigar por partes.")
                    break
                end
            end
        end
        if count == 0 then table.insert(out, "Nenhum GuiObject encontrado.") end
        table.insert(out, "")
        table.insert(out, "Nota: isto lista a interface dentro de PlayerGui; CoreGui protegido e interface interna do motor podem nao aparecer.")
        return out
    end

    local touchCounts = {}
    local zones = {"top-left","top-center","top-right","mid-left","center","mid-right","bottom-left","bottom-center","bottom-right"}
    for _, zone in ipairs(zones) do touchCounts[zone] = {starts=0, moves=0, ends=0} end
    local function zoneFor(pos)
        local cam = Workspace.CurrentCamera
        local size = cam and cam.ViewportSize or Vector2.new(1,1)
        local col = math.clamp(math.floor(pos.X / math.max(size.X,1) * 3), 0, 2)
        local row = math.clamp(math.floor(pos.Y / math.max(size.Y,1) * 3), 0, 2)
        return zones[row * 3 + col + 1]
    end

    local touchLog = {}
    local function touchEvent(kind, input, processed)
        local pos = input.Position
        local zone = zoneFor(pos)
        if touchCounts[zone] then touchCounts[zone][kind] = touchCounts[zone][kind] + 1 end
        touchLog[#touchLog + 1] = string.format("%s pos=(%s) zone=%s delta=(%s) processed=%s type=%s",
            string.upper(kind), vec2(pos), zone, vec2(input.Delta), tostring(processed), tostring(input.UserInputType))
        if #touchLog > 500 then table.remove(touchLog, 1) end
    end
    local conns = {}
    conns[#conns+1] = UIS.TouchStarted:Connect(function(input, processed) touchEvent("starts", input, processed) end)
    conns[#conns+1] = UIS.TouchMoved:Connect(function(input, processed) touchEvent("moves", input, processed) end)
    conns[#conns+1] = UIS.TouchEnded:Connect(function(input, processed) touchEvent("ends", input, processed) end)

    local function buildReport(section)
        local out = {}
        local cam = Workspace.CurrentCamera
        local char = player.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        local rootPart = char and char:FindFirstChild("HumanoidRootPart")
        local insetTop, insetBottom = safe(function() return GuiService:GetGuiInset() end, Vector2.zero)
        if section == "RESUMO" then
            table.insert(out, "MEMEDASH SCREEN X-RAY v2.0")
            table.insert(out, "Modo: observacao; nao altera controles nem sensibilidade.")
            table.insert(out, "")
            table.insert(out, "=== TELA / DISPOSITIVO ===")
            table.insert(out, "TouchEnabled: " .. tostring(UIS.TouchEnabled))
            table.insert(out, "MouseEnabled: " .. tostring(UIS.MouseEnabled))
            table.insert(out, "KeyboardEnabled: " .. tostring(UIS.KeyboardEnabled))
            table.insert(out, "GamepadEnabled: " .. tostring(UIS.GamepadEnabled))
            table.insert(out, "PreferredInput: " .. tostring(safe(function() return UIS.PreferredInput end, "indisponivel")))
            table.insert(out, "Viewport: " .. (cam and vec2(cam.ViewportSize) or "sem camera"))
            table.insert(out, "GuiInset top/bottom: " .. vec2(insetTop) .. " / " .. vec2(insetBottom))
            table.insert(out, "ScreenOrientation: " .. tostring(safe(function() return player.PlayerGui.CurrentScreenOrientation end, "indisponivel")))
            table.insert(out, "")
            table.insert(out, "=== CAMERA ===")
            if cam then
                table.insert(out, "CameraType: " .. tostring(cam.CameraType))
                table.insert(out, "CameraSubject: " .. tostring(cam.CameraSubject))
                table.insert(out, "FieldOfView: " .. tostring(cam.FieldOfView))
                table.insert(out, "CFrame position: " .. vec3(cam.CFrame.Position))
                table.insert(out, "LookVector: " .. vec3(cam.CFrame.LookVector))
                table.insert(out, "Focus position: " .. vec3(cam.Focus.Position))
            else table.insert(out, "CurrentCamera: nil") end
            table.insert(out, "")
            table.insert(out, "=== JOGADOR / PERSONAGEM ===")
            table.insert(out, "Player: " .. player.Name .. " | UserId=" .. player.UserId)
            table.insert(out, "Character: " .. tostring(char))
            table.insert(out, "Humanoid: " .. tostring(hum))
            if hum then
                table.insert(out, "MoveDirection: " .. vec3(hum.MoveDirection))
                table.insert(out, "WalkSpeed: " .. tostring(hum.WalkSpeed))
                table.insert(out, "JumpPower: " .. tostring(hum.JumpPower))
                table.insert(out, "UseJumpPower: " .. tostring(hum.UseJumpPower))
                table.insert(out, "FloorMaterial: " .. tostring(hum.FloorMaterial))
                table.insert(out, "State: " .. tostring(hum:GetState()))
            end
            if rootPart then table.insert(out, "Root position: " .. vec3(rootPart.Position)) end
            table.insert(out, "")
            table.insert(out, "=== TOQUES POR REGIAO (grade 3x3) ===")
            for _, zone in ipairs(zones) do
                local z = touchCounts[zone]
                table.insert(out, string.format("%s: starts=%d moves=%d ends=%d", zone, z.starts, z.moves, z.ends))
            end
            table.insert(out, "Total de eventos recentes guardados: " .. #touchLog .. " (max 500)")
            table.insert(out, "")
            table.insert(out, "=== COMO LER ===")
            table.insert(out, "UI lista objetos visiveis/ativos, texto, posicao e tamanho em PlayerGui.")
            table.insert(out, "TOQUES mostra coordenadas e regiao; processed indica se outro sistema marcou o toque como tratado.")
            table.insert(out, "CAMERA mostra orientacao e FOV; movimento pode ser causado por controle do jogo, nao prova sensibilidade.")
            table.insert(out, "O cliente nao revela automaticamente scripts privados, logica do servidor ou todos os elementos CoreGui.")
        elseif section == "UI" then
            return scanUI()
        elseif section == "TOQUES" then
            table.insert(out, "=== EVENTOS DE TOQUE (mais recentes primeiro no fim) ===")
            table.insert(out, "A grade divide a tela em 3 colunas x 3 linhas.")
            for _, zone in ipairs(zones) do
                local z = touchCounts[zone]
                table.insert(out, string.format("%s: starts=%d moves=%d ends=%d", zone, z.starts, z.moves, z.ends))
            end
            table.insert(out, "")
            local start = math.max(1, #touchLog - 179)
            for i = start, #touchLog do table.insert(out, string.format("%03d %s", i, touchLog[i])) end
            table.insert(out, "")
            table.insert(out, "Nota: toques consumidos por interfaces podem nao chegar igualmente a todos os eventos.")
        elseif section == "CAMERA" then
            table.insert(out, "=== CAMERA / OBSERVACAO AO VIVO ===")
            if cam then
                table.insert(out, "CameraType=" .. tostring(cam.CameraType))
                table.insert(out, "CameraSubject=" .. tostring(cam.CameraSubject))
                table.insert(out, "FOV=" .. tostring(cam.FieldOfView))
                table.insert(out, "Viewport=" .. vec2(cam.ViewportSize))
                table.insert(out, "CFrame.Position=" .. vec3(cam.CFrame.Position))
                table.insert(out, "CFrame.LookVector=" .. vec3(cam.CFrame.LookVector))
                table.insert(out, "Focus=" .. vec3(cam.Focus.Position))
            else table.insert(out, "CurrentCamera indisponivel") end
            table.insert(out, "")
            table.insert(out, "Amostragem por 10 segundos sera exibida no console; esta leitura e instantanea.")
            table.insert(out, "O Roblox nao oferece uma propriedade universal de sensibilidade de camera.")
        end
        return out
    end

    local function refresh()
        reportLines = buildReport(activeSection)
        setReport(table.concat(reportLines, "\n"))
        status.Text = "Secao: " .. activeSection .. " | Atualizado: " .. os.date("%H:%M:%S")
    end

    local sectionButtons = {}
    for _, section in ipairs({"RESUMO","UI","TOQUES","CAMERA"}) do
        local b = makeButton(tabs, section, 0.24, Color3.fromRGB(55, 65, 85))
        sectionButtons[#sectionButtons+1] = b
        b.Activated:Connect(function()
            activeSection = section
            refresh()
        end)
    end

    copyButton.Activated:Connect(function()
        local full = table.concat(reportLines, "\n")
        local copied = false
        if typeof(setclipboard) == "function" then
            local success, result = pcall(setclipboard, full)
            copied = success and result ~= false
        elseif typeof(toclipboard) == "function" then
            local success, result = pcall(toclipboard, full)
            copied = success and result ~= false
        end
        if copied then
            status.Text = "Relatorio copiado!"
        else
            -- Put the full report into a selectable TextBox as a fallback.
            local box = root:FindFirstChild("CopyFallback")
            if not box then
                box = Instance.new("TextBox")
                box.Name = "CopyFallback"
                box.Size = UDim2.new(1, -20, 1, -20)
                box.Position = UDim2.new(0, 10, 0, 10)
                box.BackgroundColor3 = Color3.fromRGB(10, 10, 15)
                box.TextColor3 = Color3.new(1,1,1)
                box.TextSize = 12
                box.Font = Enum.Font.Code
                box.TextWrapped = true
                box.TextXAlignment = Enum.TextXAlignment.Left
                box.TextYAlignment = Enum.TextYAlignment.Top
                box.MultiLine = true
                box.ClearTextOnFocus = false
                box.TextEditable = true
                box.Parent = root
                local done = Instance.new("TextButton")
                done.Size = UDim2.new(0, 90, 0, 34)
                done.Position = UDim2.new(1, -100, 0, 5)
                done.BackgroundColor3 = Color3.fromRGB(160, 65, 65)
                done.TextColor3 = Color3.new(1,1,1)
                done.Text = "VOLTAR"
                done.Parent = box
                done.Activated:Connect(function() box:Destroy() end)
            end
            box.Text = full
            box:CaptureFocus()
            status.Text = "Clipboard indisponivel: selecione o texto da caixa para copiar."
        end
    end)
    refreshButton.Activated:Connect(refresh)
    closeButton.Activated:Connect(function()
        for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
        gui:Destroy()
    end)

    local lastCamera = cam
    local lastCFrame = Workspace.CurrentCamera and Workspace.CurrentCamera.CFrame
    local sampleStart = os.clock()
    local sampleLast = 0
    conns[#conns+1] = RunService.RenderStepped:Connect(function()
        local current = Workspace.CurrentCamera
        if current ~= lastCamera then
            add("CAMERA_CHANGED -> " .. tostring(current))
            lastCamera = current
        end
        if current and lastCFrame and os.clock() - sampleLast >= 0.25 then
            local angle = math.deg(math.acos(math.clamp(lastCFrame.LookVector:Dot(current.CFrame.LookVector), -1, 1)))
            if angle > 0.02 then
                add(string.format("CAMERA_DELTA %.3f deg / 0.25s | FOV=%.2f", angle, current.FieldOfView))
            end
            lastCFrame = current.CFrame
            sampleLast = os.clock()
        elseif current then
            lastCFrame = current.CFrame
        end
        if os.clock() - sampleStart >= 10 then
            sampleStart = os.clock()
            add("CAMERA_SAMPLE_WINDOW_END; consulte console [MEMEDASH-XRAY]")
        end
    end)

    add("SCREEN X-RAY v2.0 iniciado")
    add("Este script observa; nao modifica sensibilidade nem controles.")
    refresh()
end)

if not ok then
    warn("[MEMEDASH-XRAY] ERRO: " .. tostring(err))
end
