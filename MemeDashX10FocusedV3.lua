-- MEMEDASH X10 V3 | Focused Camera Inspector (new filename)
-- Read-only standard Roblox instance inspection: no decompilation.
-- Created because camera-only V7 accumulated visual offsets and failed.
-- Does not change touch, camera, body, FOV or player controls.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local UIS = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
assert(player, "Execute no cliente do MemeDash.")
local pg = player:WaitForChild("PlayerGui")
local ENV = (type(getgenv) == "function" and getgenv()) or _G

if type(ENV.__MemeDashX10Cleanup) == "function" then
    pcall(ENV.__MemeDashX10Cleanup)
end
if type(ENV.__MemeDashX10V3Cleanup) == "function" then
    pcall(ENV.__MemeDashX10V3Cleanup)
end
local old = pg:FindFirstChild("MemeDashX10")
if old then old:Destroy() end
local previousV3 = pg:FindFirstChild("MemeDashX10V3")
if previousV3 then previousV3:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name = "MemeDashX10V3"
gui.DisplayOrder = 1000000
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.Parent = pg
local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.Size = UDim2.fromOffset(346,192)
panel.AnchorPoint = Vector2.new(.5,0)
panel.Position = UDim2.new(.5,0,.10,0)
panel.BackgroundColor3 = Color3.fromRGB(21,24,35)
panel.Active = true
panel.BorderSizePixel = 0
panel.Parent = gui
Instance.new("UICorner",panel).CornerRadius = UDim.new(0,10)

local function label(t,y,h,size,color)
    local l = Instance.new("TextLabel")
    l.Position = UDim2.fromOffset(10,y)
    l.Size = UDim2.new(1,-20,0,h)
    l.BackgroundTransparency = 1
    l.TextWrapped = true
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.TextYAlignment = Enum.TextYAlignment.Center
    l.TextColor3 = color or Color3.new(1,1,1)
    l.Font = Enum.Font.Gotham
    l.TextSize = size
    l.Text = t
    l.Parent = panel
    return l
end
local title = label("MEMEDASH X10 V3 • FOCUSED CAMERA",7,27,13,
    Color3.fromRGB(145,207,255))
title.Font = Enum.Font.GothamBold
local desc = label("Busca focada: camera + bodyrotation. Ignora emotes. Apenas leitura.",40,42,11)
local status = label("PRONTO • toque INSPECIONAR",84,28,12,
    Color3.fromRGB(149,238,178))
local foot = label("Sem alterar camera, personagem ou botoes do jogo.",161,22,10,
    Color3.fromRGB(155,171,194))
local function button(t,x,color)
    local b = Instance.new("TextButton")
    b.Position = UDim2.new(x,0,0,121)
    b.Size = UDim2.new(.306,-4,0,34)
    b.BorderSizePixel = 0
    b.BackgroundColor3 = color
    b.TextColor3 = Color3.new(1,1,1)
    b.Font = Enum.Font.GothamBold
    b.TextSize = 10
    b.Text = t
    b.Parent = panel
    Instance.new("UICorner",b).CornerRadius = UDim.new(0,7)
    return b
end
local scan = button("INSPECIONAR",.028,Color3.fromRGB(36,139,104))
local copy = button("COPIAR",.35,Color3.fromRGB(43,107,187))
local close = button("FECHAR",.675,Color3.fromRGB(149,65,76))
local connections = {}
local alive = true
local running = false
local report = "Execute INSPECIONAR primeiro."
local function connect(signal,fn)
    local c = signal:Connect(fn)
    connections[#connections+1] = c
end
local function cleanup()
    if not alive then return end
    alive = false
    for _,c in ipairs(connections) do pcall(function() c:Disconnect() end) end
    table.clear(connections)
    gui:Destroy()
    if ENV.__MemeDashX10V3Cleanup == cleanup then
        ENV.__MemeDashX10V3Cleanup = nil
    end
end
ENV.__MemeDashX10V3Cleanup = cleanup
connect(close.Activated,cleanup)

local function safeName(obj)
    local ok,v = pcall(function() return obj:GetFullName() end)
    if ok then
        -- Avoid unnecessarily putting a username into the public report.
        return tostring(v):gsub(player.Name, "<LocalPlayer>")
    end
    return tostring(obj)
end
local function safeValue(obj)
    local ok,val = pcall(function() return obj.Value end)
    if not ok then return "(inaccessible)" end
    local str = tostring(val)
    -- Only include simple scalar values, no arbitrary text, URLs or IDs.
    if obj:IsA("StringValue") then
        return "(string omitted)"
    end
    return str:sub(1,120)
end
local function relevantName(s)
    s = tostring(s):lower()
    return s:find("camera",1,true) or s:find("sens",1,true)
        or s:find("look",1,true) or s:find("pitch",1,true)
        or s:find("yaw",1,true) or s:find("input",1,true)
        or s:find("touch",1,true) or s:find("aim",1,true)
        or s:find("rotat",1,true) or s:find("bodyrotation",1,true)
end
local function attrs(obj,out)
    local ok, values = pcall(function() return obj:GetAttributes() end)
    if not ok then
        out[#out+1] = "  Attributes: permission unavailable"
        return
    end
    local keys = {}
    for k in pairs(values) do keys[#keys+1] = k end
    table.sort(keys)
    if #keys == 0 then
        out[#out+1] = "  Attributes: none"
    end
    for _,key in ipairs(keys) do
        local value = values[key]
        local typeValue = typeof(value)
        local str
        if typeValue == "number" or typeValue == "boolean" then
            str = tostring(value)
        else
            str = "("..typeValue.." omitted)"
        end
        out[#out+1] = "  Attr "..key.." = "..str
    end
end
local function inspect()
    local out = {
        "===== MEMEDASH X10 V3 / FOCUSED CAMERA CONFIG =====",
        "Mode = read-only; NO source reading, hooks or camera mutations.",
        "Build=X10-V3-FOCUSED-20261030; new filename; no emote asset scan.",
        "PlaceId="..tostring(game.PlaceId),
        "TouchEnabled="..tostring(UIS.TouchEnabled),
        "Viewport="..tostring(Workspace.CurrentCamera and Workspace.CurrentCamera.ViewportSize),
        "CameraType="..tostring(Workspace.CurrentCamera and Workspace.CurrentCamera.CameraType),
        ""
    }
    local function add(s) out[#out+1] = tostring(s) end
    local cam = Workspace.CurrentCamera
    if cam then
        add("[CURRENT CAMERA]")
        add("Object="..safeName(cam))
        add("FOV="..tostring(cam.FieldOfView))
        attrs(cam,out)
        add("")
    end
    local okMouse, mouse = pcall(function() return UIS.MouseDeltaSensitivity end)
    add("[ROBLOX LOCAL INPUT SETTINGS]")
    add("UserInputService.MouseDeltaSensitivity="..
        (okMouse and tostring(mouse) or "(inaccessible)"))
    local okGame, settings = pcall(function() return UserSettings():GetService("UserGameSettings") end)
    if okGame and settings then
        for _,name in ipairs({"MouseSensitivity","GamepadCameraSensitivity"}) do
            local ok,v=pcall(function() return settings[name] end)
            add("UserGameSettings."..name.."="..
                (ok and tostring(v) or "(inaccessible)"))
        end
    end
    add("NOTE: mouse/gamepad settings may NOT affect mobile touch.")
    add("Input controls in settings are NOT evidence of the custom script using them.")
    add("")
    -- X10 v2: prioritize only the specific player camera scripts and nearby
    -- public configuration. Emote assets deliberately excluded.
    local workspaceFolder = Workspace:FindFirstChild(player.Name)
    local roots = {
        {"Workspace player folder", workspaceFolder},
        {"Character", player.Character},
        {"PlayerScripts", player:FindFirstChild("PlayerScripts")},
        {"PlayerGui (limited settings)", pg},
        {"ReplicatedFirst", game:GetService("ReplicatedFirst")}
    }
    local paths, values, candidates = {}, {}, {}
    local visitedCount, relevantCount = 0, 0
    local unique, skippedRoots, interruptedRoots = {}, {}, {}
    local function check(obj)
        if unique[obj] then return end
        unique[obj] = true
        visitedCount = visitedCount + 1
        local n = obj.Name:lower()
        local named = relevantName(n)
        local isScript = obj:IsA("LocalScript") or obj:IsA("ModuleScript")
        local isValue = obj:IsA("ValueBase")
        local isConfiguration = obj:IsA("Configuration")
        if named then relevantCount = relevantCount + 1 end
        local parentNamed = obj.Parent and relevantName(obj.Parent.Name)
        if isScript and named and #paths < 90 then
            paths[#paths+1] = safeName(obj) .. " [" .. obj.ClassName .. "]"
        end
        if isValue and (named or parentNamed) and #values < 90 then
            values[#values+1] = safeName(obj) .. " [" .. obj.ClassName ..
                "] = " .. safeValue(obj)
        end
        if (named and (isScript or isConfiguration or isValue or obj:IsA("Folder")))
            or (isValue and parentNamed) then
            if #candidates < 90 then candidates[#candidates+1] = obj end
        end
    end
    -- A bounded per-root traversal avoids a giant unhelpful inventory of emotes.
    local function walk(root, title, budget)
        if not root then
            skippedRoots[#skippedRoots+1] = title .. " (unavailable)"
            return
        end
        local queue, head, seen = {root}, 1, 0
        while head <= #queue do
            if seen >= budget then
                interruptedRoots[#interruptedRoots+1] =
                    title .. " (budget " .. tostring(budget) .. " reached)"
                return
            end
            local obj = queue[head]
            head = head + 1
            seen = seen + 1
            local lowName = obj.Name:lower()
            local isEmotes = lowName == "emotes" or lowName == "items"
            if not isEmotes then
                check(obj)
                local ok, children = pcall(function() return obj:GetChildren() end)
                if ok then
                    for _,child in ipairs(children) do
                        queue[#queue+1] = child
                    end
                end
            end
            if seen % 400 == 0 then task.wait() end
        end
    end
    for _,entry in ipairs(roots) do
        walk(entry[2], entry[1], 4500)
    end
    -- Only inspect ReplicatedStorage top-level or folders with promising names.
    check(ReplicatedStorage)
    local ok, top = pcall(function() return ReplicatedStorage:GetChildren() end)
    if ok then
        for _,obj in ipairs(top) do
            if relevantName(obj.Name) or obj.Name:lower()=="settings"
                or obj.Name:lower()=="config" or obj.Name:lower()=="options" then
                walk(obj, "ReplicatedStorage."..obj.Name, 1600)
            end
        end
    end
    -- Important: never infer that a public configuration is actually read by
    -- the custom LocalScript. Only the script's author/source can confirm it.
    local camera = workspaceFolder and workspaceFolder:FindFirstChild("camera")
    local rotation = workspaceFolder and workspaceFolder:FindFirstChild("bodyrotation")
    add("[DIRECT MEMEDASH CONTROLLERS]")
    add("Workspace player camera=" ..
        (camera and safeName(camera).." ["..camera.ClassName.."]" or "not found"))
    add("Workspace player bodyrotation=" ..
        (rotation and safeName(rotation).." ["..rotation.ClassName.."]" or "not found"))
    if camera then
        add("camera Disabled="..tostring((function()
            local ok2, v=pcall(function() return camera.Enabled end)
            return ok2 and v or "unavailable"
        end)()))
        attrs(camera,out)
        for _,child in ipairs(camera:GetChildren()) do
            add("camera child: "..safeName(child).." ["..child.ClassName.."]" ..
                (child:IsA("ValueBase") and (" = "..safeValue(child)) or ""))
            attrs(child,out)
        end
    end
    if rotation then attrs(rotation,out) end
    add("")
    add("[SCOPE]")
    add("Skipped large emote/item asset trees.")
    if #skippedRoots>0 then add("Unavailable roots: "..table.concat(skippedRoots," | ")) end
    if #interruptedRoots>0 then
        add("WARNING: incomplete bounded scans: "..table.concat(interruptedRoots," | "))
    else
        add("All selected root scans completed within per-root limits.")
    end
    add("")
    table.sort(paths)
    table.sort(values)
    add("[COUNTS]")
    add("Instances scanned (focused)="..tostring(visitedCount))
    add("Relevant named instances="..tostring(relevantCount))
    add("Relevant scripts="..tostring(#paths))
    add("Relevant ValueBase="..tostring(#values))
    add("")
    add("[CAMERA / INPUT SCRIPT PATHS]")
    if #paths==0 then add("(none visible)") end
    for _,v in ipairs(paths) do add(v) end
    add("")
    add("[PUBLIC VALUES]")
    if #values==0 then add("(no exposed sensitivity-related ValueBase found)") end
    for _,v in ipairs(values) do add(v) end
    add("")
    add("[PUBLIC ATTRIBUTES ON RELEVANT OBJECTS]")
    if #candidates==0 then add("(no candidates)") end
    local count=0
    for _,obj in ipairs(candidates) do
        -- Report only candidate objects from focused search.
        local path=safeName(obj)
        local hasAttrs=false
        local ok,at=pcall(function() return obj:GetAttributes() end)
        if ok and next(at) then hasAttrs=true end
        if obj.Name:lower()=="camera" or hasAttrs or relevantName(obj.Name) then
            if count>=55 then add("...attribute scan capped at 55 objects");break end
            count=count+1
            add(path)
            attrs(obj,out)
        end
    end
    add("")
    add("[RESULT INTERPRETATION]")
    add("NumberValue/attribute relating to sensitivity may be useful IF the")
    add("game's camera LocalScript actually reads it; presence alone proves nothing.")
    add("If none exists, ordinary instance APIs cannot show the internal Lua code.")
    add("No game values were changed, and no source was read.")
    add("X10 v2 ignores emote assets. A missing value is not proof one cannot exist.")
    add("===== END X10 =====")
    return table.concat(out,"\n")
end
connect(scan.Activated,function()
    if not alive or running then return end
    running=true
    status.Text="INSPECIONANDO • somente leitura"
    scan.Text="ANALISANDO"
    task.spawn(function()
        local ok,result=pcall(inspect)
        if not alive then return end
        running=false
        scan.Text="REFAZER"
        if ok then
            report=result
            status.Text="PRONTO • "..#report.." caracteres"
        else
            report="MEMEDASH X10 V3 ERROR: "..tostring(result)
            status.Text="Erro de leitura • use COPIAR"
        end
    end)
end)
connect(copy.Activated,function()
    if running then return end
    if not report:find("===== MEMEDASH X10 V3",1,true)
        and not report:find("MEMEDASH X10 V3 ERROR",1,true) then
        status.Text="Clique INSPECIONAR antes."
        return
    end
    local clip=(type(setclipboard)=="function" and setclipboard)
        or (type(toclipboard)=="function" and toclipboard)
    if clip then
        local ok=pcall(clip,report)
        if ok then
            status.Text="COPIADO • cole aqui na conversa"
            return
        end
    end
    local modal = Instance.new("Frame")
    modal.Size=UDim2.new(.96,0,.90,0)
    modal.Position=UDim2.new(.02,0,.05,0)
    modal.BackgroundColor3=Color3.fromRGB(16,20,29)
    modal.ZIndex=10
    modal.Parent=gui
    local field=Instance.new("TextBox")
    field.Position=UDim2.fromOffset(8,8)
    field.Size=UDim2.new(1,-16,1,-58)
    field.MultiLine=true
    field.TextWrapped=false
    field.TextEditable=true
    field.ClearTextOnFocus=false
    field.Text=report
    field.TextSize=11
    field.Font=Enum.Font.Code
    field.TextXAlignment=Enum.TextXAlignment.Left
    field.TextYAlignment=Enum.TextYAlignment.Top
    field.TextColor3=Color3.new(1,1,1)
    field.BackgroundColor3=Color3.fromRGB(28,32,46)
    field.ZIndex=11
    field.Parent=modal
    local dismiss=Instance.new("TextButton")
    dismiss.Position=UDim2.new(1,-88,1,-44)
    dismiss.Size=UDim2.fromOffset(78,33)
    dismiss.Text="FECHAR"
    dismiss.TextColor3=Color3.new(1,1,1)
    dismiss.BackgroundColor3=Color3.fromRGB(141,62,75)
    dismiss.ZIndex=12
    dismiss.Parent=modal
    connect(dismiss.Activated,function() modal:Destroy() end)
    status.Text="Copie o texto da caixa manualmente"
end)
print("[MEMEDASH X10 V3] Read-only camera settings inspection; INSPECIONAR > COPIAR")
