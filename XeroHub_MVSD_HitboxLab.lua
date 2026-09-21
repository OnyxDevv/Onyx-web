-- XeroHub | MVSD Wall -> Target Probe | Kev
-- Controlled test:
-- 1) Arm
-- 2) Fire ONE natural shot at a wall/environment
-- 3) After short delay, sends ONE ShootGun call to nearest enemy native hitbox
-- 4) Auto-disarms
-- No continuous spam.
--estsss

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
while not player do
    task.wait()
    player = Players.LocalPlayer
end

local env = (getgenv and getgenv()) or _G

if env.__XERO_MVSD_WALLTARGET_CLEANUP then
    pcall(env.__XERO_MVSD_WALLTARGET_CLEANUP)
end

local state = {
    Alive = true,
    Armed = false,
    Pending = false,
    Delay = 0.18,
    Lines = {},
    TargetName = nil,
}

local function push(s)
    state.Lines[#state.Lines + 1] = tostring(s)
end

local function pathOf(inst)
    if typeof(inst) ~= "Instance" then
        return tostring(inst)
    end

    local parts = {}
    local node = inst
    local guard = 0

    while node and guard < 64 do
        guard += 1
        parts[#parts + 1] = tostring(node.Name)
        node = node.Parent
    end

    local out = {}
    for i = #parts, 1, -1 do
        out[#out + 1] = parts[i]
    end

    return table.concat(out, ".")
end

local function vec3(v)
    return string.format("(%.3f, %.3f, %.3f)", v.X, v.Y, v.Z)
end

local function getHumanoidFromInstance(inst)
    if typeof(inst) ~= "Instance" then
        return nil, nil
    end

    local node = inst

    for _ = 1, 8 do
        if not node then break end

        local hum = node:FindFirstChildOfClass("Humanoid")
        if hum then
            return hum, node
        end

        node = node.Parent
    end

    return nil, nil
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

local function getNativeHitbox(char)
    if not char then return nil end

    local torso = char:FindFirstChild("UpperTorso")
        or char:FindFirstChild("Torso")

    if not torso then
        return nil
    end

    local part = torso:FindFirstChild("Part")

    if part and part:IsA("BasePart") then
        return part
    end

    return nil
end

local function getNearestEnemy(origin)
    local bestPlr, bestHum, bestPart
    local bestDist = math.huge

    for _, plr in ipairs(Players:GetPlayers()) do
        if isEnemy(plr) then
            local char = plr.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            local part = char and getNativeHitbox(char)

            if hum and hum.Health > 0 and part then
                local d = (part.Position - origin).Magnitude

                if d < bestDist then
                    bestDist = d
                    bestPlr = plr
                    bestHum = hum
                    bestPart = part
                end
            end
        end
    end

    return bestPlr, bestHum, bestPart, bestDist
end

local hookState = env.__XERO_MVSD_WALLTARGET_HOOK

if type(hookState) ~= "table" then
    hookState = {Current = state}
    env.__XERO_MVSD_WALLTARGET_HOOK = hookState

    local oldNamecall
    oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
        local shared = env.__XERO_MVSD_WALLTARGET_HOOK
        local s = shared and shared.Current

        if s
            and s.Alive
            and s.Armed
            and not s.Pending
            and not checkcaller()
        then
            local method = getnamecallmethod()

            if self.ClassName == "RemoteEvent"
                and self.Name == "ShootGun"
                and method == "FireServer"
            then
                local args = table.pack(...)
                local origin = args[1]
                local naturalHit = args[3]
                local naturalAt = os.clock()

                -- Only continue if natural shot did NOT hit a humanoid.
                local naturalHum = getHumanoidFromInstance(naturalHit)

                if naturalHum then
                    s.Armed = false
                    push("[ABORTADO] El tiro natural pegó a un jugador. Prueba apuntando a pared.")
                elseif typeof(origin) ~= "Vector3" then
                    s.Armed = false
                    push("[ABORTADO] ShootGun no trajo origin Vector3.")
                else
                    s.Armed = false
                    s.Pending = true

                    task.defer(function()
                        if not s.Alive then return end

                        push(string.rep("=", 58))
                        push("[NATURAL -> PARED]")
                        push("t = " .. string.format("%.6f", naturalAt))
                        push("Origin: " .. vec3(origin))
                        push("Hit natural: " .. pathOf(naturalHit))

                        local targetPlr, targetHum, targetPart, dist =
                            getNearestEnemy(origin)

                        if not targetPlr or not targetHum or not targetPart then
                            push("[ABORTADO] No encontré enemigo válido en tu Match.")
                            s.Pending = false
                            return
                        end

                        s.TargetName = targetPlr.Name

                        push("")
                        push("[TARGET SELECCIONADO]")
                        push("Jugador: " .. targetPlr.Name)
                        push("Health antes: " .. tostring(targetHum.Health))
                        push("Hitbox: " .. pathOf(targetPart))
                        push("Distancia: " .. string.format("%.2f", dist))
                        push("Replay en: " .. string.format("%.3f s", s.Delay))

                        local died = false
                        local diedAt = nil

                        local diedConn
                        diedConn = targetHum.Died:Connect(function()
                            died = true
                            diedAt = os.clock()
                        end)

                        task.delay(s.Delay, function()
                            local current = env.__XERO_MVSD_WALLTARGET_HOOK

                            if not current
                                or current.Current ~= s
                                or not s.Alive
                            then
                                pcall(function()
                                    diedConn:Disconnect()
                                end)
                                s.Pending = false
                                return
                            end

                            if not targetPart.Parent
                                or not targetHum.Parent
                                or targetHum.Health <= 0
                            then
                                push("[ABORTADO] Target dejó de ser válido antes del replay.")
                                pcall(function()
                                    diedConn:Disconnect()
                                end)
                                s.Pending = false
                                return
                            end

                            local hitPos = targetPart.Position
                            local delta = hitPos - origin

                            if delta.Magnitude <= 0.01 then
                                push("[ABORTADO] Dirección inválida.")
                                pcall(function()
                                    diedConn:Disconnect()
                                end)
                                s.Pending = false
                                return
                            end

                            -- Arg[2] observed in MVSD is a point farther along the shot line.
                            -- Use a long point on the same ray; arg[3]/arg[4] are the native
                            -- hitbox and actual impact position.
                            local aimPoint = origin + delta.Unit * 1000

                            local replayAt = os.clock()

                            local ok, err = pcall(function()
                                self:FireServer(
                                    origin,
                                    aimPoint,
                                    targetPart,
                                    hitPos
                                )
                            end)

                            push("")
                            push("[REPLAY -> ENEMIGO]")
                            push("t = " .. string.format("%.6f", replayAt))
                            push(
                                "Δ real = "
                                .. string.format("%.4f s", replayAt - naturalAt)
                            )
                            push("Aim: " .. vec3(aimPoint))
                            push("Hit: " .. pathOf(targetPart))
                            push("HitPos: " .. vec3(hitPos))
                            push(
                                "FireServer: "
                                .. (
                                    ok
                                    and "OK"
                                    or ("ERROR: " .. tostring(err))
                                )
                            )

                            task.delay(0.55, function()
                                if not s.Alive then return end

                                push("")
                                push("[RESULTADO]")
                                push("Target: " .. targetPlr.Name)
                                push("Health después: " .. tostring(targetHum.Health))
                                push("Died observado: " .. tostring(died))

                                if diedAt then
                                    push(
                                        "Died Δ desde replay: "
                                        .. string.format("%.4f s", diedAt - replayAt)
                                    )
                                end

                                if died then
                                    push(
                                        "CONFIRMACIÓN FUERTE: el enemigo murió después "
                                        .. "del replay, mientras el tiro natural fue a pared."
                                    )
                                else
                                    push(
                                        "No se confirmó kill con este replay. "
                                        .. "Puede existir validación adicional."
                                    )
                                end

                                push("Prueba terminada y desarmada.")

                                pcall(function()
                                    diedConn:Disconnect()
                                end)

                                s.Pending = false
                            end)
                        end)
                    end)
                end
            end
        end

        return oldNamecall(self, ...)
    end)
else
    hookState.Current = state
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

local oldGui = guiParent:FindFirstChild("XeroMVSDWallTargetProbe")
if oldGui then
    oldGui:Destroy()
end

local gui = Instance.new("ScreenGui")
gui.Name = "XeroMVSDWallTargetProbe"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 2147483647
gui.Parent = guiParent

local frame = Instance.new("Frame")
frame.AnchorPoint = Vector2.new(0.5, 0.5)
frame.Position = UDim2.fromScale(0.5, 0.5)
frame.Size = UDim2.fromOffset(440, 405)
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
title.Text = "XERO | MVSD WALL → TARGET"
title.TextColor3 = Color3.fromRGB(245, 245, 245)
title.Font = Enum.Font.GothamBold
title.TextSize = 17
title.TextXAlignment = Enum.TextXAlignment.Left
title.ZIndex = 21
title.Parent = frame

local subtitle = Instance.new("TextLabel")
subtitle.Position = UDim2.fromOffset(16, 38)
subtitle.Size = UDim2.new(1, -32, 0, 18)
subtitle.BackgroundTransparency = 1
subtitle.Text = "Prueba definitiva de cooldown · by Kev"
subtitle.TextColor3 = Color3.fromRGB(125, 125, 125)
subtitle.Font = Enum.Font.Gotham
subtitle.TextSize = 11
subtitle.TextXAlignment = Enum.TextXAlignment.Left
subtitle.ZIndex = 21
subtitle.Parent = frame

local dragBar = Instance.new("Frame")
dragBar.Size = UDim2.new(1, 0, 0, 62)
dragBar.BackgroundTransparency = 1
dragBar.Active = true
dragBar.ZIndex = 20
dragBar.Parent = frame

local status = Instance.new("TextLabel")
status.Position = UDim2.fromOffset(16, 68)
status.Size = UDim2.new(1, -32, 0, 52)
status.BackgroundColor3 = Color3.fromRGB(14, 14, 14)
status.TextColor3 = Color3.fromRGB(220, 220, 220)
status.Font = Enum.Font.GothamMedium
status.TextSize = 11
status.TextWrapped = true
status.Parent = frame
Instance.new("UICorner", status).CornerRadius = UDim.new(0, 10)

local function refreshStatus()
    if state.Pending then
        status.Text = "PRUEBA EN CURSO · espera el resultado"
    elseif state.Armed then
        status.Text = (
            "ARMADO · apunta a una PARED y haz UN disparo · replay "
            .. string.format("%.2f s", state.Delay)
        )
    else
        status.Text = (
            "Desarmado · selecciona delay y pulsa ARMAR"
        )
    end
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
end

button("ARMAR", 16, 136, 110, function()
    if not state.Pending then
        state.Armed = true
        push("[SYSTEM] Wall -> Target Probe armado.")
        refreshStatus()
    end
end)

button("0.10", 138, 136, 76, function()
    if not state.Pending then
        state.Delay = 0.10
        refreshStatus()
    end
end)

button("0.18", 224, 136, 76, function()
    if not state.Pending then
        state.Delay = 0.18
        refreshStatus()
    end
end)

button("0.30", 310, 136, 76, function()
    if not state.Pending then
        state.Delay = 0.30
        refreshStatus()
    end
end)

button("LIMPIAR", 16, 184, 110, function()
    if not state.Pending then
        table.clear(state.Lines)
        refreshStatus()
    end
end)

button("COPIAR TODO", 138, 184, 248, function()
    local data = table.concat(state.Lines, "\n")
    local clip = setclipboard or toclipboard

    if data == "" then
        status.Text = "No hay datos."
    elseif clip then
        pcall(clip, data)
        status.Text = "Copiado. Pégamelo aquí."
    else
        status.Text = "Tu executor no tiene setclipboard."
    end
end)

local preview = Instance.new("TextLabel")
preview.Position = UDim2.fromOffset(16, 232)
preview.Size = UDim2.new(1, -32, 1, -248)
preview.BackgroundColor3 = Color3.fromRGB(11, 11, 11)
preview.TextColor3 = Color3.fromRGB(150, 150, 150)
preview.Font = Enum.Font.Code
preview.TextSize = 10
preview.TextWrapped = true
preview.TextXAlignment = Enum.TextXAlignment.Left
preview.TextYAlignment = Enum.TextYAlignment.Top
preview.Text = "Esperando prueba..."
preview.Parent = frame
Instance.new("UICorner", preview).CornerRadius = UDim.new(0, 10)

task.spawn(function()
    while state.Alive do
        refreshStatus()

        local n = #state.Lines
        if n == 0 then
            preview.Text = "Esperando prueba..."
        else
            local first = math.max(1, n - 18)
            local lines = {}

            for i = first, n do
                lines[#lines + 1] = state.Lines[i]
            end

            preview.Text = table.concat(lines, "\n")
        end

        task.wait(0.10)
    end
end)

-- Mobile + PC drag
local dragging = false
local activeInput = nil
local dragStart = nil
local frameStart = nil

dragBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch
    then
        dragging = true
        activeInput = input
        dragStart = input.Position
        frameStart = frame.Position
    end
end)

local function updateDrag(input)
    if not dragging or not dragStart or not frameStart then
        return
    end

    if input.UserInputType == Enum.UserInputType.Touch
        and activeInput
        and input ~= activeInput
    then
        return
    end

    local delta = input.Position - dragStart

    frame.Position = UDim2.new(
        frameStart.X.Scale,
        frameStart.X.Offset + delta.X,
        frameStart.Y.Scale,
        frameStart.Y.Offset + delta.Y
    )
end

UserInputService.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement then
        updateDrag(input)
    end
end)

UserInputService.TouchMoved:Connect(function(input)
    updateDrag(input)
end)

UserInputService.InputEnded:Connect(function(input)
    if input == activeInput
        or input.UserInputType == Enum.UserInputType.MouseButton1
    then
        dragging = false
        activeInput = nil
        dragStart = nil
        frameStart = nil
    end
end)

UserInputService.TouchEnded:Connect(function(input)
    if input == activeInput then
        dragging = false
        activeInput = nil
        dragStart = nil
        frameStart = nil
    end
end)

local function cleanup()
    if not state.Alive then
        return
    end

    state.Alive = false
    state.Armed = false
    state.Pending = false

    if hookState and hookState.Current == state then
        hookState.Current = nil
    end

    pcall(function()
        gui:Destroy()
    end)
end

env.__XERO_MVSD_WALLTARGET_CLEANUP = cleanup

refreshStatus()

print("[XeroHub] MVSD Wall -> Target Probe cargado | one replay only | by Kev")
