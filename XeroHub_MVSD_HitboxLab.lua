-- XeroHub | MVSD Native Hitbox Test | Kev
-- Expande las hitboxes NATIVAS del juego (BodyPart.Part).
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

if env.__XERO_MVSD_NATIVE_HITBOX_CLEANUP then
    pcall(env.__XERO_MVSD_NATIVE_HITBOX_CLEANUP)
end

local state = {
    Alive = true,
    Enabled = false,
    Visible = true,
    Mode = "TORSO",
    Multiplier = 2.5,
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

    if player.TeamColor ~= nil and plr.TeamColor ~= nil
        and player.Neutral == false and plr.Neutral == false
    then
        return player.TeamColor ~= plr.TeamColor
    end

    return true
end

local TORSO_PARENT_NAMES = {
    UpperTorso = true,
    LowerTorso = true,
    HumanoidRootPart = true,
    Head = true,
}

local FULL_PARENT_NAMES = {
    Head = true,
    HumanoidRootPart = true,
    UpperTorso = true,
    LowerTorso = true,
    LeftUpperArm = true,
    LeftLowerArm = true,
    LeftHand = true,
    RightUpperArm = true,
    RightLowerArm = true,
    RightHand = true,
    LeftUpperLeg = true,
    LeftLowerLeg = true,
    LeftFoot = true,
    RightUpperLeg = true,
    RightLowerLeg = true,
    RightFoot = true,
}

local function isNativeHitbox(part)
    if not part
        or not part:IsA("BasePart")
        or part.Name ~= "Part"
        or not part.Parent
    then
        return false
    end

    local parentName = part.Parent.Name

    if state.Mode == "FULL" then
        return FULL_PARENT_NAMES[parentName] == true
    end

    return TORSO_PARENT_NAMES[parentName] == true
end

local function ensureAdornment(part)
    local box = state.Adornments[part]

    if box and box.Parent == part then
        return box
    end

    box = Instance.new("BoxHandleAdornment")
    box.Name = "XeroNativeHitboxBox"
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
        pcall(function() box:Destroy() end)
        state.Adornments[part] = nil
    end

    state.OriginalSize[part] = nil
end

local function restoreAll()
    local parts = {}

    for part in pairs(state.OriginalSize) do
        parts[#parts + 1] = part
    end

    for i = 1, #parts do
        restorePart(parts[i])
    end
end

local function applyToPart(part)
    if not state.OriginalSize[part] then
        state.OriginalSize[part] = part.Size
    end

    local original = state.OriginalSize[part]
    local wanted = original * state.Multiplier

    if part.Size ~= wanted then
        pcall(function()
            part.Size = wanted
        end)
    end

    local box = ensureAdornment(part)
    if box then
        box.Size = part.Size
        box.Visible = state.Visible
    end
end

local function scanAndApply()
    if not state.Enabled then
        return
    end

    local stillValid = {}

    for _, plr in ipairs(Players:GetPlayers()) do
        if isEnemy(plr) then
            local char = plr.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")

            if char and hum and hum.Health > 0
                and not char:FindFirstChildOfClass("ForceField")
            then
                for _, obj in ipairs(char:GetDescendants()) do
                    if isNativeHitbox(obj) then
                        stillValid[obj] = true
                        applyToPart(obj)
                    end
                end
            end
        end
    end

    local stale = {}
    for part in pairs(state.OriginalSize) do
        if not stillValid[part] then
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

-- UI
local guiParent = player:WaitForChild("PlayerGui")
pcall(function()
    if gethui then
        guiParent = gethui()
    end
end)

local oldGui = guiParent:FindFirstChild("XeroMVSDNativeHitbox")
if oldGui then oldGui:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name = "XeroMVSDNativeHitbox"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 2147483647
gui.Parent = guiParent

local frame = Instance.new("Frame")
frame.AnchorPoint = Vector2.new(0.5, 0.5)
frame.Position = UDim2.fromScale(0.5, 0.5)
frame.Size = UDim2.fromOffset(420, 330)
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
title.Text = "XERO | MVSD NATIVE HITBOX"
title.TextColor3 = Color3.fromRGB(245, 245, 245)
title.Font = Enum.Font.GothamBold
title.TextSize = 17
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = frame

local subtitle = Instance.new("TextLabel")
subtitle.Position = UDim2.fromOffset(16, 38)
subtitle.Size = UDim2.new(1, -32, 0, 18)
subtitle.BackgroundTransparency = 1
subtitle.Text = "Prueba hitboxes reales · by Kev"
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
status.Text = "Desactivado · TORSO · x2.5"
status.Parent = frame
Instance.new("UICorner", status).CornerRadius = UDim.new(0, 10)

local function refreshStatus()
    status.Text = (
        (state.Enabled and "ACTIVO" or "DESACTIVADO")
        .. " · "
        .. state.Mode
        .. " · x"
        .. string.format("%.1f", state.Multiplier)
        .. (state.Visible and " · visible" or " · oculto")
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

    if not state.Enabled then
        restoreAll()
    else
        scanAndApply()
    end

    enableButton.Text = state.Enabled and "DESACTIVAR" or "ACTIVAR"
    refreshStatus()
end)

local modeButton
modeButton = button("MODO: TORSO", 150, 126, 120, function()
    restoreAll()
    state.Mode = state.Mode == "TORSO" and "FULL" or "TORSO"
    modeButton.Text = "MODO: " .. state.Mode

    if state.Enabled then
        scanAndApply()
    end

    refreshStatus()
end)

local visibleButton
visibleButton = button("OCULTAR CAJAS", 284, 126, 120, function()
    state.Visible = not state.Visible
    visibleButton.Text = state.Visible and "OCULTAR CAJAS" or "MOSTRAR CAJAS"

    for part, box in pairs(state.Adornments) do
        if part and part.Parent and box and box.Parent then
            box.Visible = state.Visible
        end
    end

    refreshStatus()
end)

button("-0.5", 16, 178, 88, function()
    state.Multiplier = math.max(1, state.Multiplier - 0.5)
    if state.Enabled then scanAndApply() end
    refreshStatus()
end)

button("+0.5", 116, 178, 88, function()
    state.Multiplier = math.min(8, state.Multiplier + 0.5)
    if state.Enabled then scanAndApply() end
    refreshStatus()
end)

button("x2", 216, 178, 88, function()
    state.Multiplier = 2
    if state.Enabled then scanAndApply() end
    refreshStatus()
end)

button("x4", 316, 178, 88, function()
    state.Multiplier = 4
    if state.Enabled then scanAndApply() end
    refreshStatus()
end)

local info = Instance.new("TextLabel")
info.Position = UDim2.fromOffset(16, 230)
info.Size = UDim2.new(1, -32, 0, 78)
info.BackgroundColor3 = Color3.fromRGB(11, 11, 11)
info.TextColor3 = Color3.fromRGB(145, 145, 145)
info.Font = Enum.Font.Gotham
info.TextSize = 10
info.TextWrapped = true
info.TextXAlignment = Enum.TextXAlignment.Left
info.TextYAlignment = Enum.TextYAlignment.Top
info.Text =
    "Este test modifica SOLO las Part invisibles nativas que ya usa MVSD.\n"
    .. "TORSO: Head/UpperTorso/LowerTorso/HRP.Part.\n"
    .. "FULL: también brazos y piernas. Al desactivar restaura el tamaño original."
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
        pcall(function() c:Disconnect() end)
        state.Connections[i] = nil
    end

    pcall(function() gui:Destroy() end)
end

env.__XERO_MVSD_NATIVE_HITBOX_CLEANUP = cleanup

print("[XeroHub] MVSD Native Hitbox Test cargado | by Kev")
