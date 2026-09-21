-- XeroHub | MVSD State Scanner | Kev
-- Compara el estado del cliente entre LOBBY y PARTIDA para encontrar
-- una señal estable que pueda usarse como gate del ESP/Silent Aim.
--
-- Uso:
-- 1) En lobby -> CAPTURAR LOBBY
-- 2) Ya dentro de una ronda -> CAPTURAR PARTIDA
-- 3) COMPARAR
-- 4) COPIAR y mandar el resultado

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")
local Teams = game:GetService("Teams")

local player = Players.LocalPlayer
if not player then return end

local runtimeEnv = (getgenv and getgenv()) or _G
if runtimeEnv.__XERO_MVSD_STATE_SCANNER_CLEANUP then
    pcall(runtimeEnv.__XERO_MVSD_STATE_SCANNER_CLEANUP)
end

local state = {
    Alive = true,
    Connections = {},
    Lobby = nil,
    Match = nil,
}

local function track(c)
    if c then
        state.Connections[#state.Connections + 1] = c
    end
    return c
end

local function safeDestroy(obj)
    if obj then pcall(function() obj:Destroy() end) end
end

local function safePath(obj)
    if not obj then return "nil" end
    local out = {}
    local cur = obj
    local guard = 0
    while cur and cur ~= game and guard < 32 do
        table.insert(out, 1, cur.Name)
        cur = cur.Parent
        guard += 1
    end
    if cur == game then
        table.insert(out, 1, "game")
    end
    return table.concat(out, ".")
end

local function valueToString(v)
    local t = typeof(v)
    if t == "string" then
        return string.format("%q", v)
    elseif t == "number" or t == "boolean" then
        return tostring(v)
    elseif t == "Color3" then
        return string.format("Color3(%.3f,%.3f,%.3f)", v.R, v.G, v.B)
    elseif t == "Vector3" then
        return string.format("Vector3(%.2f,%.2f,%.2f)", v.X, v.Y, v.Z)
    elseif t == "BrickColor" then
        return tostring(v.Name)
    elseif t == "EnumItem" then
        return tostring(v)
    elseif t == "Instance" then
        return "<" .. v.ClassName .. " " .. safePath(v) .. ">"
    end
    return tostring(v)
end

local KEYWORDS = {
    "round", "game", "match", "state", "status", "phase",
    "lobby", "intermission", "waiting", "playing", "play",
    "spect", "alive", "dead", "spawn", "timer", "time",
    "mode", "started", "active", "current", "stage"
}

local function containsKeyword(text)
    text = string.lower(tostring(text or ""))
    for i = 1, #KEYWORDS do
        if string.find(text, KEYWORDS[i], 1, true) then
            return true
        end
    end
    return false
end

local function add(snapshot, key, value)
    if key and value ~= nil then
        snapshot[key] = valueToString(value)
    end
end

local function captureAttributes(snapshot, prefix, obj)
    if not obj then return end
    local ok, attrs = pcall(function() return obj:GetAttributes() end)
    if not ok or type(attrs) ~= "table" then return end

    for name, value in pairs(attrs) do
        add(snapshot, prefix .. ".Attribute." .. tostring(name), value)
    end
end

local function capturePlayerCore(snapshot)
    local char = player.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local tool = char and char:FindFirstChildOfClass("Tool")
    local ff = char and char:FindFirstChildOfClass("ForceField")

    add(snapshot, "Player.Team", player.Team and player.Team.Name or "nil")
    add(snapshot, "Player.TeamColor", player.TeamColor)
    add(snapshot, "Player.Neutral", player.Neutral)
    add(snapshot, "Player.Character", char and char.Name or "nil")

    captureAttributes(snapshot, "Player", player)

    if char then
        captureAttributes(snapshot, "Character", char)
        add(snapshot, "Character.ForceField", ff ~= nil)
        add(snapshot, "Character.Tool", tool and tool.Name or "nil")
        add(snapshot, "Character.HRP", hrp ~= nil)

        if hum then
            add(snapshot, "Humanoid.Health", hum.Health)
            add(snapshot, "Humanoid.MaxHealth", hum.MaxHealth)
            add(snapshot, "Humanoid.Sit", hum.Sit)
            add(snapshot, "Humanoid.PlatformStand", hum.PlatformStand)
            add(snapshot, "Humanoid.State", hum:GetState())
            captureAttributes(snapshot, "Humanoid", hum)
        end
    end
end

local function captureTeams(snapshot)
    local list = Teams:GetTeams()
    add(snapshot, "Teams.Count", #list)
    for i = 1, #list do
        local team = list[i]
        local prefix = "Teams." .. team.Name
        add(snapshot, prefix .. ".Color", team.TeamColor)
        add(snapshot, prefix .. ".AutoAssignable", team.AutoAssignable)
        captureAttributes(snapshot, prefix, team)
    end
end

local function captureCandidateObject(snapshot, obj, rootName)
    local name = obj.Name
    local path = safePath(obj)
    local candidate = containsKeyword(name) or containsKeyword(path)

    if obj:IsA("ValueBase") and candidate then
        add(snapshot, rootName .. ".Value." .. path, obj.Value)
        captureAttributes(snapshot, rootName .. ".ValueAttr." .. path, obj)
        return
    end

    if candidate then
        local attrsOk, attrs = pcall(function() return obj:GetAttributes() end)
        if attrsOk and type(attrs) == "table" then
            for attr, value in pairs(attrs) do
                if containsKeyword(attr) or containsKeyword(name) then
                    add(snapshot, rootName .. ".Attr." .. path .. "." .. attr, value)
                end
            end
        end

        if obj:IsA("ScreenGui") then
            add(snapshot, rootName .. ".ScreenGui." .. path .. ".Enabled", obj.Enabled)
        elseif obj:IsA("GuiObject") then
            add(snapshot, rootName .. ".Gui." .. path .. ".Visible", obj.Visible)
            if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
                local text = obj.Text
                if text and text ~= "" and #text <= 180 then
                    add(snapshot, rootName .. ".GuiText." .. path, text)
                end
            end
        end
    end
end

local function scanRoot(snapshot, root, rootName, maxObjects)
    if not root then return end

    captureAttributes(snapshot, rootName, root)

    local ok, descendants = pcall(function() return root:GetDescendants() end)
    if not ok or type(descendants) ~= "table" then return end

    local limit = math.min(#descendants, maxObjects or 6000)
    for i = 1, limit do
        captureCandidateObject(snapshot, descendants[i], rootName)
    end

    add(snapshot, rootName .. ".DescendantCountScanned", limit)
end

local function captureSnapshot(label)
    local snapshot = {}
    add(snapshot, "Snapshot.Label", label)
    add(snapshot, "Game.PlaceId", game.PlaceId)

    capturePlayerCore(snapshot)
    captureTeams(snapshot)

    local playerGui = player:FindFirstChildOfClass("PlayerGui")
    scanRoot(snapshot, ReplicatedStorage, "ReplicatedStorage", 7000)
    scanRoot(snapshot, Workspace, "Workspace", 7000)
    scanRoot(snapshot, playerGui, "PlayerGui", 5000)

    return snapshot
end

local function sortedKeys(map)
    local keys = {}
    for k in pairs(map or {}) do
        keys[#keys + 1] = k
    end
    table.sort(keys)
    return keys
end

local function compareSnapshots(a, b)
    if not a or not b then
        return "Falta capturar Lobby o Partida."
    end

    local keys = {}
    local seen = {}

    for k in pairs(a) do
        if not seen[k] then
            seen[k] = true
            keys[#keys + 1] = k
        end
    end
    for k in pairs(b) do
        if not seen[k] then
            seen[k] = true
            keys[#keys + 1] = k
        end
    end

    table.sort(keys)

    local changed = {}
    local onlyLobby = {}
    local onlyMatch = {}

    for i = 1, #keys do
        local k = keys[i]
        local av = a[k]
        local bv = b[k]

        if av ~= nil and bv ~= nil then
            if av ~= bv then
                changed[#changed + 1] =
                    k .. "\n  LOBBY:   " .. tostring(av)
                    .. "\n  PARTIDA: " .. tostring(bv)
            end
        elseif av ~= nil then
            onlyLobby[#onlyLobby + 1] = k .. " = " .. tostring(av)
        elseif bv ~= nil then
            onlyMatch[#onlyMatch + 1] = k .. " = " .. tostring(bv)
        end
    end

    local lines = {
        "===== XEROHUB MVSD STATE DIFF =====",
        "",
        "CAMBIOS (" .. #changed .. "):"
    }

    if #changed == 0 then
        lines[#lines + 1] = "(ninguno)"
    else
        for i = 1, #changed do
            lines[#lines + 1] = changed[i]
        end
    end

    lines[#lines + 1] = ""
    lines[#lines + 1] = "SOLO EN LOBBY (" .. #onlyLobby .. "):"
    for i = 1, #onlyLobby do
        lines[#lines + 1] = onlyLobby[i]
    end

    lines[#lines + 1] = ""
    lines[#lines + 1] = "SOLO EN PARTIDA (" .. #onlyMatch .. "):"
    for i = 1, #onlyMatch do
        lines[#lines + 1] = onlyMatch[i]
    end

    return table.concat(lines, "\n")
end

-- ==========================
-- UI
-- ==========================

local parent = player:WaitForChild("PlayerGui")
pcall(function()
    if gethui then
        parent = gethui()
    else
        parent = CoreGui
    end
end)

local old = parent:FindFirstChild("XeroHub_MVSD_StateScanner")
if old then old:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name = "XeroHub_MVSD_StateScanner"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 2147483647
gui.Parent = parent

local frame = Instance.new("Frame")
frame.Size = UDim2.fromOffset(560, 430)
frame.Position = UDim2.new(0.5, -280, 0.5, -215)
frame.BackgroundColor3 = Color3.fromRGB(12, 12, 12)
frame.BorderSizePixel = 0
frame.Active = true
frame.Parent = gui
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 14)

local stroke = Instance.new("UIStroke", frame)
stroke.Color = Color3.fromRGB(58, 58, 58)
stroke.Thickness = 1

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -30, 0, 36)
title.Position = UDim2.fromOffset(15, 8)
title.BackgroundTransparency = 1
title.Text = "XeroHub · MVSD State Scanner"
title.TextColor3 = Color3.fromRGB(245,245,245)
title.Font = Enum.Font.GothamBold
title.TextSize = 16
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = frame

local status = Instance.new("TextLabel")
status.Size = UDim2.new(1, -30, 0, 42)
status.Position = UDim2.fromOffset(15, 42)
status.BackgroundTransparency = 1
status.Text = "1) Lobby → Capturar Lobby   2) Partida → Capturar Partida   3) Comparar"
status.TextColor3 = Color3.fromRGB(165,165,165)
status.Font = Enum.Font.Gotham
status.TextSize = 12
status.TextWrapped = true
status.TextXAlignment = Enum.TextXAlignment.Left
status.Parent = frame

local output = Instance.new("TextBox")
output.Size = UDim2.new(1, -30, 1, -160)
output.Position = UDim2.fromOffset(15, 88)
output.BackgroundColor3 = Color3.fromRGB(18,18,18)
output.BorderSizePixel = 0
output.ClearTextOnFocus = false
output.MultiLine = true
output.TextEditable = false
output.TextWrapped = false
output.TextXAlignment = Enum.TextXAlignment.Left
output.TextYAlignment = Enum.TextYAlignment.Top
output.TextColor3 = Color3.fromRGB(220,220,220)
output.Font = Enum.Font.Code
output.TextSize = 10
output.Text = "Esperando capturas..."
output.Parent = frame
Instance.new("UICorner", output).CornerRadius = UDim.new(0, 10)

local function makeButton(text, x, w)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(w, -6, 0, 38)
    b.Position = UDim2.new(x, 15, 1, -50)
    b.BackgroundColor3 = Color3.fromRGB(25,25,25)
    b.BorderSizePixel = 0
    b.Text = text
    b.TextColor3 = Color3.fromRGB(235,235,235)
    b.Font = Enum.Font.GothamMedium
    b.TextSize = 11
    b.Parent = frame
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 10)
    return b
end

local lobbyBtn = makeButton("CAPTURAR LOBBY", 0.00, 0.235)
local matchBtn = makeButton("CAPTURAR PARTIDA", 0.245, 0.255)
local compareBtn = makeButton("COMPARAR", 0.51, 0.22)
local copyBtn = makeButton("COPIAR", 0.74, 0.22)

local dragging = false
local dragStart
local startPos

track(frame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch
    then
        dragging = true
        dragStart = input.Position
        startPos = frame.Position
    end
end))

track(game:GetService("UserInputService").InputChanged:Connect(function(input)
    if not dragging then return end
    if input.UserInputType ~= Enum.UserInputType.MouseMovement
        and input.UserInputType ~= Enum.UserInputType.Touch
    then
        return
    end

    local delta = input.Position - dragStart
    frame.Position = UDim2.new(
        startPos.X.Scale,
        startPos.X.Offset + delta.X,
        startPos.Y.Scale,
        startPos.Y.Offset + delta.Y
    )
end))

track(game:GetService("UserInputService").InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch
    then
        dragging = false
    end
end))

lobbyBtn.MouseButton1Click:Connect(function()
    status.Text = "Capturando estado de LOBBY..."
    task.spawn(function()
        state.Lobby = captureSnapshot("LOBBY")
        local count = #sortedKeys(state.Lobby)
        output.Text = "LOBBY capturado.\nEntradas: " .. tostring(count)
        status.Text = "Lobby capturado. Ahora entra a una partida y pulsa CAPTURAR PARTIDA."
    end)
end)

matchBtn.MouseButton1Click:Connect(function()
    status.Text = "Capturando estado de PARTIDA..."
    task.spawn(function()
        state.Match = captureSnapshot("PARTIDA")
        local count = #sortedKeys(state.Match)
        output.Text = "PARTIDA capturada.\nEntradas: " .. tostring(count)
        status.Text = "Partida capturada. Pulsa COMPARAR."
    end)
end)

compareBtn.MouseButton1Click:Connect(function()
    local diff = compareSnapshots(state.Lobby, state.Match)
    output.Text = diff
    status.Text = "Comparación lista. Pulsa COPIAR y mándame el resultado."
end)

copyBtn.MouseButton1Click:Connect(function()
    local text = output.Text
    if type(setclipboard) == "function" then
        pcall(setclipboard, text)
        status.Text = "Resultado copiado."
    else
        output.TextEditable = true
        output:CaptureFocus()
        status.Text = "Tu ejecutor no tiene setclipboard; copia manualmente del cuadro."
    end
end)

runtimeEnv.__XERO_MVSD_STATE_SCANNER_CLEANUP = function()
    if not state.Alive then return end
    state.Alive = false

    for i = #state.Connections, 1, -1 do
        pcall(function() state.Connections[i]:Disconnect() end)
        state.Connections[i] = nil
    end

    safeDestroy(gui)
end

print("[XeroHub] MVSD State Scanner cargado.")
