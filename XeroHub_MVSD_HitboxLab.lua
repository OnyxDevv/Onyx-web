-- XeroHub | MVSD Unified Native Hitbox | Kev
-- Usa SOLO UpperTorso.Part como hitbox nativa principal.
-- No crea hitboxes falsas y no toca ShootGun/FireServer.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
while not player do
    task.wait()
    player = Players.LocalPlayer
end

local env = (getgenv and getgenv()) or _G

if env.__XERO_MVSD_UNIFIED_HITBOX_CLEANUP then
    pcall(env.__XERO_MVSD_UNIFIED_HITBOX_CLEANUP)
end

local state = {
    Alive = true,
    Enabled = false,
    Visible = true,

    -- Tamaño ABSOLUTO de la caja unificada.
    Size = 8,
    MinSize = 2,
    MaxSize = 50,

    Connections = {},
    OriginalSize = setmetatable({}, {__mode = "k"}),
    Adornments = setmetatable({}, {__mode = "k"}),
}

local function track(c)
    if c then
        state.Connections[#state.Connections + 1] = c
    end
    return c
end

local function sameMatch(plr)
    local mine = player:GetAttribute("Match")
    local theirs = plr:GetAttribute("Match")

    if mine ~= nil and theirs ~= nil then
        return mine == theirs
    end

    return true
end

local function isEnemy(plr)
    if not plr or plr == player then
        return false
    end

    if not sameMatch(plr) then
        return false
    end

    if player.Team ~= nil and plr.Team ~= nil then
        return player.Team ~= plr.Team
    end

    if player.TeamColor ~= nil
        and plr.TeamColor ~= nil
        and player.Neutral == false
        and plr.Neutral == false
    then
        return player.TeamColor ~= plr.TeamColor
    end

    return true
end

local function getNativeUnifiedHitbox(char)
    if not char then return nil end

    local upperTorso = char:FindFirstChild("UpperTorso")
        or char:FindFirstChild("Torso")

    if not upperTorso then
        return nil
    end

    local part = upperTorso:FindFirstChild("Part")

    if part and part:IsA("BasePart") then
        return part
    end

    return nil
end

local function ensureAdornment(part)
    local box = state.Adornments[part]

    if box and box.Parent == part then
        return box
    end

    box = Instance.new("BoxHandleAdornment")
    box.Name = "XeroUnifiedNativeHitboxBox"
    box.Adornee = part
    box.AlwaysOnTop = true
    box.ZIndex = 10
    box.Color3 = Color3.fromRGB(255, 255, 255)
    box.Transparency = 0.55
    box.Size = part.Size
    box.Visible = state.Visible
    box.Parent = part

    state.Adornments[part] = box
    return box
end

local function restorePart(part)
    local original = state.OriginalSize[part]

    if part and part.Parent and original then
        pcall(function()
            part.Size = original
        end)
    end

    local box = state.Adornments[part]
    if box then
        pcall(function()
            box:Destroy()
        end)
        state.Adornments[part] = nil
    end

    state.OriginalSize[part] = nil
end

local function restoreAll()
    local list = {}

    for part in pairs(state.OriginalSize) do
        list[#list + 1] = part
    end

    for i = 1, #list do
        restorePart(list[i])
    end
end

local function applyUnified(part)
    if not state.OriginalSize[part] then
        state.OriginalSize[part] = part.Size
    end

    local size = math.clamp(
        tonumber(state.Size) or 8,
        state.MinSize,
        state.MaxSize
    )

    local wanted = Vector3.new(size, size, size)

    if part.Size ~= wanted then
        pcall(function()
            part.Size = wanted
        end)
    end

    -- Conservamos las propiedades nativas que hacen que el raycast
    -- pueda detectar la Part, pero sin colisión física.
    pcall(function()
        part.CanCollide = false
        part.CanQuery = true
        part.Transparency = 1
        part.Massless = true
    end)

    local box = ensureAdornment(part)
    if box then
        box.Size = wanted
        box.Visible = state.Visible
    end
end

local function scanAndApply()
    if not state.Enabled then
        return
    end

    local active = {}

    for _, plr in ipairs(Players:GetPlayers()) do
        if isEnemy(plr) then
            local char = plr.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")

            if char
                and hum
                and hum.Health > 0
                and not char:FindFirstChildOfClass("ForceField")
            then
                local hitbox = getNativeUnifiedHitbox(char)

                if hitbox then
                    active[hitbox] = true
                    applyUnified(hitbox)
                end
            end
        end
    end

    local stale = {}

    for part in pairs(state.OriginalSize) do
        if not active[part] then
            stale[#stale + 1] = part
        end
    end

    for i = 1, #stale do
        restorePart(stale[i])
    end
end

local accumulator = 0

track(RunService.Heartbeat:Connect(function(dt)
    accumulator += dt

    if accumulator < 0.15 then
        return
    end

    accumulator = 0

    if state.Enabled then
        scanAndApply()
    end
end))

-- =========================
-- UI
-- =========================

local guiParent = player:WaitForChild("PlayerGui")
pcall(function()
    if gethui then
        guiParent = gethui()
    end
end)

local oldGui = guiParent:FindFirstChild("XeroMVSDUnifiedHitbox")
if oldGui then
    oldGui:Destroy()
end

local gui = Instance.new("ScreenGui")
gui.Name = "XeroMVSDUnifiedHitbox"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 2147483647
gui.Parent = guiParent

local frame = Instance.new("Frame")
frame.AnchorPoint = Vector2.new(0.5, 0.5)
frame.Position = UDim2.fromScale(0.5, 0.5)
frame.Size = UDim2.fromOffset(420, 350)
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
title.Text = "XERO | MVSD UNIFIED HITBOX"
title.TextColor3 = Color3.fromRGB(245, 245, 245)
title.Font = Enum.Font.GothamBold
title.TextSize = 17
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = frame

local subtitle = Instance.new("TextLabel")
subtitle.Position = UDim2.fromOffset(16, 38)
subtitle.Size = UDim2.new(1, -32, 0, 18)
subtitle.BackgroundTransparency = 1
subtitle.Text = "Una sola hitbox nativa · by Kev"
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
status.Parent = frame
Instance.new("UICorner", status).CornerRadius = UDim.new(0, 10)

local function refreshStatus()
    status.Text = (
        (state.Enabled and "ACTIVO" or "DESACTIVADO")
        .. " · Caja única "
        .. tostring(state.Size)
        .. "x"
        .. tostring(state.Size)
        .. "x"
        .. tostring(state.Size)
        .. (state.Visible and " · visible" or " · oculta")
    )
end

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
    return b
end

local enableButton
enableButton = button("ACTIVAR", 16, 126, 120, function()
    state.Enabled = not state.Enabled

    if state.Enabled then
        scanAndApply()
    else
        restoreAll()
    end

    enableButton.Text = state.Enabled and "DESACTIVAR" or "ACTIVAR"
    refreshStatus()
end)

local visibleButton
visibleButton = button("OCULTAR CAJA", 150, 126, 120, function()
    state.Visible = not state.Visible

    visibleButton.Text = state.Visible
        and "OCULTAR CAJA"
        or "MOSTRAR CAJA"

    for part, box in pairs(state.Adornments) do
        if part and part.Parent and box and box.Parent then
            box.Visible = state.Visible
        end
    end

    refreshStatus()
end)

button("RESET 8", 284, 126, 120, function()
    state.Size = 8
    if state.Enabled then scanAndApply() end
    refreshStatus()
end)

button("-1", 16, 178, 72, function()
    state.Size = math.max(state.MinSize, state.Size - 1)
    if state.Enabled then scanAndApply() end
    refreshStatus()
end)

button("+1", 98, 178, 72, function()
    state.Size = math.min(state.MaxSize, state.Size + 1)
    if state.Enabled then scanAndApply() end
    refreshStatus()
end)

button("+5", 180, 178, 72, function()
    state.Size = math.min(state.MaxSize, state.Size + 5)
    if state.Enabled then scanAndApply() end
    refreshStatus()
end)

button("15", 262, 178, 64, function()
    state.Size = 15
    if state.Enabled then scanAndApply() end
    refreshStatus()
end)

button("25", 336, 178, 68, function()
    state.Size = 25
    if state.Enabled then scanAndApply() end
    refreshStatus()
end)

local sizeBox = Instance.new("TextBox")
sizeBox.Position = UDim2.fromOffset(16, 230)
sizeBox.Size = UDim2.fromOffset(240, 36)
sizeBox.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
sizeBox.TextColor3 = Color3.fromRGB(235, 235, 235)
sizeBox.PlaceholderColor3 = Color3.fromRGB(95, 95, 95)
sizeBox.PlaceholderText = "Tamaño exacto: 2 - 50"
sizeBox.Text = ""
sizeBox.ClearTextOnFocus = false
sizeBox.Font = Enum.Font.Gotham
sizeBox.TextSize = 11
sizeBox.Parent = frame
Instance.new("UICorner", sizeBox).CornerRadius = UDim.new(0, 10)

button("APLICAR", 268, 230, 136, function()
    local value = tonumber(sizeBox.Text)

    if value then
        state.Size = math.clamp(
            math.floor(value + 0.5),
            state.MinSize,
            state.MaxSize
        )

        if state.Enabled then
            scanAndApply()
        end

        sizeBox.Text = ""
        refreshStatus()
    end
end)

local info = Instance.new("TextLabel")
info.Position = UDim2.fromOffset(16, 282)
info.Size = UDim2.new(1, -32, 0, 48)
info.BackgroundColor3 = Color3.fromRGB(11, 11, 11)
info.TextColor3 = Color3.fromRGB(145, 145, 145)
info.Font = Enum.Font.Gotham
info.TextSize = 10
info.TextWrapped = true
info.TextXAlignment = Enum.TextXAlignment.Left
info.TextYAlignment = Enum.TextYAlignment.Top
info.Text =
    "Usa únicamente UpperTorso.Part, la hitbox nativa que vimos en ShootGun. "
    .. "Ahora es UNA sola caja uniforme. Rango: 2 - 50."
info.Parent = frame
Instance.new("UICorner", info).CornerRadius = UDim.new(0, 10)

-- Drag
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

track(UserInputService.InputChanged:Connect(function(input)
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

track(UserInputService.InputEnded:Connect(function(input)
    if input == dragInput then
        dragging = false
    end
end))

local function cleanup()
    if not state.Alive then return end

    state.Alive = false
    state.Enabled = false

    restoreAll()

    for i = #state.Connections, 1, -1 do
        local c = state.Connections[i]
        pcall(function()
            c:Disconnect()
        end)
        state.Connections[i] = nil
    end

    pcall(function()
        gui:Destroy()
    end)
end

env.__XERO_MVSD_UNIFIED_HITBOX_CLEANUP = cleanup

refreshStatus()

print("[XeroHub] MVSD Unified Native Hitbox cargado | by Kev")
