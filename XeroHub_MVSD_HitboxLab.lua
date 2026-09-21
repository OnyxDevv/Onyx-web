-- XeroHub | MVSD Hitbox Lab | Kev
-- Passive inspector: no modifica Parts, no cambia Size, no dispara nada.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
while not player do
    task.wait()
    player = Players.LocalPlayer
end

local env = (getgenv and getgenv()) or _G

if env.__XERO_MVSD_HITBOXLAB_CLEANUP then
    pcall(env.__XERO_MVSD_HITBOXLAB_CLEANUP)
end

local state = {
    Alive = true,
    Connections = {},
    Lines = {},
    LastScan = {},
    SelectedMode = "TODOS",
}

local function track(c)
    if c then
        state.Connections[#state.Connections + 1] = c
    end
    return c
end

local function push(text)
    state.Lines[#state.Lines + 1] = tostring(text)
end

local function sep()
    push(string.rep("=", 64))
end

local function pathOf(inst)
    if typeof(inst) ~= "Instance" then
        return tostring(inst)
    end

    local names = {}
    local node = inst
    local guard = 0

    while node and guard < 64 do
        guard += 1
        names[#names + 1] = tostring(node.Name)
        node = node.Parent
    end

    local out = {}
    for i = #names, 1, -1 do
        out[#out + 1] = names[i]
    end

    return table.concat(out, ".")
end

local function vec3(v)
    return string.format(
        "Vector3.new(%.4f, %.4f, %.4f)",
        v.X, v.Y, v.Z
    )
end

local function cfShort(cf)
    local p = cf.Position
    local rx, ry, rz = cf:ToOrientation()
    return string.format(
        "Pos(%.4f, %.4f, %.4f) Rot(%.2f, %.2f, %.2f)",
        p.X, p.Y, p.Z,
        math.deg(rx), math.deg(ry), math.deg(rz)
    )
end

local function sameMatch(plr)
    local myMatch = player:GetAttribute("Match")
    local theirMatch = plr:GetAttribute("Match")

    if myMatch ~= nil and theirMatch ~= nil then
        return myMatch == theirMatch
    end

    return true
end

local function getBodyReference(char)
    if not char then return nil end

    return char:FindFirstChild("UpperTorso")
        or char:FindFirstChild("Torso")
        or char:FindFirstChild("HumanoidRootPart")
end

local function looksInteresting(part)
    if not part or not part:IsA("BasePart") then
        return false
    end

    local name = string.lower(part.Name)
    local parentName = part.Parent and string.lower(part.Parent.Name) or ""

    if name == "part"
        or name:find("hit")
        or name:find("box")
        or name:find("torso")
        or parentName == "uppertorso"
        or parentName == "torso"
        or parentName == "humanoidrootpart"
    then
        return true
    end

    return false
end

local function partSignature(part, reference)
    local rel = "N/A"

    if reference and reference:IsA("BasePart") then
        local ok, result = pcall(function()
            return reference.CFrame:ToObjectSpace(part.CFrame)
        end)

        if ok and result then
            rel = cfShort(result)
        end
    end

    return table.concat({
        "Ruta: " .. pathOf(part),
        "Clase: " .. tostring(part.ClassName),
        "Name: " .. tostring(part.Name),
        "Size: " .. vec3(part.Size),
        "Transparency: " .. tostring(part.Transparency),
        "CanQuery: " .. tostring(part.CanQuery),
        "CanTouch: " .. tostring(part.CanTouch),
        "CanCollide: " .. tostring(part.CanCollide),
        "Massless: " .. tostring(part.Massless),
        "Anchored: " .. tostring(part.Anchored),
        "Material: " .. tostring(part.Material),
        "CollisionGroup: " .. tostring(part.CollisionGroup),
        "AssemblyMass: " .. string.format("%.4f", part.AssemblyMass),
        "RelativeToBody: " .. rel,
    }, "\n")
end

local function scanPlayer(plr)
    if not plr or plr == player then return end
    if not sameMatch(plr) then return end

    local char = plr.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")

    if not char or not hum or hum.Health <= 0 then
        return
    end

    local reference = getBodyReference(char)
    local interesting = {}

    for _, obj in ipairs(char:GetDescendants()) do
        if obj:IsA("BasePart") and looksInteresting(obj) then
            interesting[#interesting + 1] = obj
        end
    end

    if #interesting == 0 then
        return
    end

    sep()
    push("[JUGADOR] " .. plr.Name)
    push("DisplayName: " .. tostring(plr.DisplayName))
    push("Match: " .. tostring(plr:GetAttribute("Match")))
    push("Team: " .. tostring(plr.Team))
    push("Neutral: " .. tostring(plr.Neutral))
    push("Reference: " .. (reference and pathOf(reference) or "N/A"))
    push("Parts interesantes: " .. tostring(#interesting))

    table.sort(interesting, function(a, b)
        return pathOf(a) < pathOf(b)
    end)

    for i = 1, #interesting do
        local part = interesting[i]
        push("")
        push(("[PART %d]"):format(i))
        push(partSignature(part, reference))
    end
end

local function scanAll()
    table.clear(state.Lines)

    push("[SYSTEM]")
    push("XeroHub MVSD Hitbox Lab")
    push("Escaneo pasivo de hitboxes/Parts internas.")
    push("PlaceId: " .. tostring(game.PlaceId))
    push("LocalPlayer: " .. tostring(player.Name))
    push("Local Match: " .. tostring(player:GetAttribute("Match")))

    local count = 0

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= player and sameMatch(plr) then
            local char = plr.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")

            if char and hum and hum.Health > 0 then
                count += 1
                scanPlayer(plr)
            end
        end
    end

    sep()
    push("[RESUMEN]")
    push("Jugadores vivos inspeccionados: " .. tostring(count))
end

local function scanTarget()
    table.clear(state.Lines)

    push("[SYSTEM]")
    push("XeroHub MVSD Hitbox Lab")
    push("Modo: jugador más cercano")

    local myChar = player.Character
    local myRoot = myChar and (
        myChar:FindFirstChild("HumanoidRootPart")
        or myChar:FindFirstChild("UpperTorso")
        or myChar:FindFirstChild("Torso")
    )

    if not myRoot then
        push("No se encontró tu RootPart.")
        return
    end

    local best
    local bestDist = math.huge

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= player and sameMatch(plr) then
            local char = plr.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            local root = char and (
                char:FindFirstChild("HumanoidRootPart")
                or char:FindFirstChild("UpperTorso")
                or char:FindFirstChild("Torso")
            )

            if hum and hum.Health > 0 and root then
                local d = (root.Position - myRoot.Position).Magnitude

                if d < bestDist then
                    bestDist = d
                    best = plr
                end
            end
        end
    end

    if not best then
        push("No se encontró otro jugador vivo en tu Match.")
        return
    end

    push("Objetivo: " .. best.Name)
    push("Distancia: " .. string.format("%.2f", bestDist))
    scanPlayer(best)
end

-- =========================
-- UI
-- =========================

local guiParent = player:WaitForChild("PlayerGui")
pcall(function()
    if gethui then
        guiParent = gethui()
    end
end)

local oldGui = guiParent:FindFirstChild("XeroMVSDHitboxLab")
if oldGui then oldGui:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name = "XeroMVSDHitboxLab"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 2147483647
gui.Parent = guiParent

local frame = Instance.new("Frame")
frame.AnchorPoint = Vector2.new(0.5, 0.5)
frame.Position = UDim2.fromScale(0.5, 0.5)
frame.Size = UDim2.fromOffset(450, 430)
frame.BackgroundColor3 = Color3.fromRGB(8, 8, 8)
frame.BorderSizePixel = 0
frame.Parent = gui
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 16)

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(55, 55, 55)
stroke.Transparency = 0.2
stroke.Parent = frame

local title = Instance.new("TextLabel")
title.Position = UDim2.fromOffset(16, 12)
title.Size = UDim2.new(1, -32, 0, 26)
title.BackgroundTransparency = 1
title.Text = "XERO | MVSD HITBOX LAB"
title.TextColor3 = Color3.fromRGB(245, 245, 245)
title.Font = Enum.Font.GothamBold
title.TextSize = 17
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = frame

local subtitle = Instance.new("TextLabel")
subtitle.Position = UDim2.fromOffset(16, 38)
subtitle.Size = UDim2.new(1, -32, 0, 18)
subtitle.BackgroundTransparency = 1
subtitle.Text = "Inspector pasivo · by Kev"
subtitle.TextColor3 = Color3.fromRGB(125, 125, 125)
subtitle.Font = Enum.Font.Gotham
subtitle.TextSize = 11
subtitle.TextXAlignment = Enum.TextXAlignment.Left
subtitle.Parent = frame

local status = Instance.new("TextLabel")
status.Position = UDim2.fromOffset(16, 68)
status.Size = UDim2.new(1, -32, 0, 44)
status.BackgroundColor3 = Color3.fromRGB(14, 14, 14)
status.TextColor3 = Color3.fromRGB(220, 220, 220)
status.Font = Enum.Font.GothamMedium
status.TextSize = 11
status.TextWrapped = true
status.Text = "Escanea cuando estés dentro de una ronda."
status.Parent = frame
Instance.new("UICorner", status).CornerRadius = UDim.new(0, 10)

local function button(label, x, y, w, cb)
    local b = Instance.new("TextButton")
    b.Position = UDim2.fromOffset(x, y)
    b.Size = UDim2.fromOffset(w, 36)
    b.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    b.TextColor3 = Color3.fromRGB(235, 235, 235)
    b.Text = label
    b.Font = Enum.Font.GothamMedium
    b.TextSize = 11
    b.AutoButtonColor = false
    b.Parent = frame
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 10)
    b.Activated:Connect(cb)
end

button("ESCANEAR TODOS", 16, 126, 132, function()
    scanAll()
    status.Text = "Escaneo completo."
end)

button("MÁS CERCANO", 159, 126, 132, function()
    scanTarget()
    status.Text = "Jugador más cercano inspeccionado."
end)

button("COPIAR TODO", 302, 126, 132, function()
    local data = table.concat(state.Lines, "\n")
    local clip = setclipboard or toclipboard

    if data == "" then
        status.Text = "Primero escanea."
    elseif clip then
        pcall(clip, data)
        status.Text = "Copiado. Pégamelo aquí."
    else
        status.Text = "Tu executor no tiene setclipboard."
    end
end)

local preview = Instance.new("TextLabel")
preview.Position = UDim2.fromOffset(16, 176)
preview.Size = UDim2.new(1, -32, 1, -192)
preview.BackgroundColor3 = Color3.fromRGB(11, 11, 11)
preview.TextColor3 = Color3.fromRGB(150, 150, 150)
preview.Font = Enum.Font.Code
preview.TextSize = 10
preview.TextWrapped = true
preview.TextXAlignment = Enum.TextXAlignment.Left
preview.TextYAlignment = Enum.TextYAlignment.Top
preview.Text = "Esperando escaneo..."
preview.Parent = frame
Instance.new("UICorner", preview).CornerRadius = UDim.new(0, 10)

track(RunService.Heartbeat:Connect(function()
    local n = #state.Lines

    if n == 0 then
        preview.Text = "Esperando escaneo..."
        return
    end

    local first = math.max(1, n - 14)
    local lines = {}

    for i = first, n do
        lines[#lines + 1] = state.Lines[i]
    end

    preview.Text = table.concat(lines, "\n")
end))

local dragging = false
local dragInput
local dragStart
local startPos

title.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch
    then
        dragging = true
        dragInput = input
        dragStart = input.Position
        startPos = frame.Position
    end
end)

title.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch
    then
        dragInput = input
    end
end)

track(game:GetService("UserInputService").InputChanged:Connect(function(input)
    if dragging and input == dragInput then
        local delta = input.Position - dragStart
        frame.Position = UDim2.new(
            startPos.X.Scale,
            startPos.X.Offset + delta.X,
            startPos.Y.Scale,
            startPos.Y.Offset + delta.Y
        )
    end
end))

track(game:GetService("UserInputService").InputEnded:Connect(function(input)
    if input == dragInput then
        dragging = false
    end
end))

local function cleanup()
    if not state.Alive then return end
    state.Alive = false

    for i = #state.Connections, 1, -1 do
        local c = state.Connections[i]
        pcall(function() c:Disconnect() end)
        state.Connections[i] = nil
    end

    pcall(function() gui:Destroy() end)
end

env.__XERO_MVSD_HITBOXLAB_CLEANUP = cleanup

push("[SYSTEM]")
push("MVSD Hitbox Lab cargado.")
push("Entra a ronda y pulsa ESCANEAR TODOS o MÁS CERCANO.")
push("Después pulsa COPIAR TODO.")

print("[XeroHub] MVSD Hitbox Lab cargado | Passive Inspector | by Kev")
