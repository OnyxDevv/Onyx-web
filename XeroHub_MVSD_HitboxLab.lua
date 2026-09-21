-- XeroHub | MVSD Server-Ack Lab | Kev
-- Controlled probe:
-- 1 natural ShootGun + 1 replay.
-- Logs incoming RemoteEvents and nearby UI sound/effect signals.
-- No continuous spam.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
while not player do
    task.wait()
    player = Players.LocalPlayer
end

local env = (getgenv and getgenv()) or _G

if env.__XERO_MVSD_ACKLAB_CLEANUP then
    pcall(env.__XERO_MVSD_ACKLAB_CLEANUP)
end

local state = {
    Alive = true,
    Armed = false,
    Pending = false,
    Delay = 0.18,
    NaturalAt = 0,
    ReplayAt = 0,
    CaptureUntil = 0,
    Lines = {},
    Connections = {},
    RemoteConnections = setmetatable({}, {__mode = "k"}),
    SoundConnections = setmetatable({}, {__mode = "k"}),
}

local function track(c)
    if c then
        state.Connections[#state.Connections + 1] = c
    end
    return c
end

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

local function serialize(v, depth)
    depth = depth or 0
    if depth > 2 then
        return "<depth>"
    end

    local t = typeof(v)

    if t == "nil" then
        return "nil"
    elseif t == "string" then
        return string.format("%q", v)
    elseif t == "number" or t == "boolean" then
        return tostring(v)
    elseif t == "Vector3" then
        return vec3(v)
    elseif t == "Instance" then
        return "<" .. v.ClassName .. " " .. pathOf(v) .. ">"
    elseif t == "table" then
        local out = {}
        local n = 0
        for k, value in pairs(v) do
            n += 1
            if n > 12 then
                out[#out + 1] = "..."
                break
            end
            out[#out + 1] =
                "[" .. serialize(k, depth + 1) .. "]="
                .. serialize(value, depth + 1)
        end
        return "{" .. table.concat(out, ", ") .. "}"
    end

    return "<" .. t .. ":" .. tostring(v) .. ">"
end

local function duringCapture()
    return state.CaptureUntil > 0 and os.clock() <= state.CaptureUntil
end

local function labelDelta(stamp)
    if state.ReplayAt > 0 and stamp >= state.ReplayAt then
        return string.format(
            "POST-REPLAY Δ %+0.4f s",
            stamp - state.ReplayAt
        )
    end

    return string.format(
        "POST-NATURAL Δ %+0.4f s",
        stamp - state.NaturalAt
    )
end

local function bindRemote(remote)
    if not remote:IsA("RemoteEvent")
        or state.RemoteConnections[remote]
    then
        return
    end

    local c = remote.OnClientEvent:Connect(function(...)
        if not state.Alive or not duringCapture() then
            return
        end

        local stamp = os.clock()
        local args = table.pack(...)

        push("")
        push("[SERVER EVENT · " .. labelDelta(stamp) .. "]")
        push("Remote: " .. pathOf(remote))
        push("Args:")

        if args.n == 0 then
            push("  (sin argumentos)")
        else
            for i = 1, args.n do
                push(
                    "  [" .. i .. "] "
                    .. "(" .. typeof(args[i]) .. ") "
                    .. serialize(args[i])
                )
            end
        end
    end)

    state.RemoteConnections[remote] = c
    track(c)
end

local function scanRemotes(container)
    for _, obj in ipairs(container:GetDescendants()) do
        if obj:IsA("RemoteEvent") then
            bindRemote(obj)
        end
    end
end

scanRemotes(ReplicatedStorage)

track(ReplicatedStorage.DescendantAdded:Connect(function(obj)
    if obj:IsA("RemoteEvent") then
        bindRemote(obj)
    end
end))

local playerGui = player:WaitForChild("PlayerGui")

local function bindSound(sound)
    if not sound:IsA("Sound")
        or state.SoundConnections[sound]
    then
        return
    end

    local c = sound.Played:Connect(function()
        if not state.Alive or not duringCapture() then
            return
        end

        local stamp = os.clock()

        push("")
        push("[SOUND · " .. labelDelta(stamp) .. "]")
        push("Ruta: " .. pathOf(sound))
        push("SoundId: " .. tostring(sound.SoundId))
        push("Volume: " .. tostring(sound.Volume))
    end)

    state.SoundConnections[sound] = c
    track(c)
end

for _, obj in ipairs(playerGui:GetDescendants()) do
    if obj:IsA("Sound") then
        bindSound(obj)
    end
end

track(playerGui.DescendantAdded:Connect(function(obj)
    if obj:IsA("Sound") then
        bindSound(obj)
    end

    if state.Alive and duringCapture() then
        local stamp = os.clock()

        if obj:IsA("GuiObject") then
            push("")
            push("[UI ADD · " .. labelDelta(stamp) .. "]")
            push("Ruta: " .. pathOf(obj))
            push("Clase: " .. obj.ClassName)
        end
    end
end))

local hookState = env.__XERO_MVSD_ACKLAB_HOOK

if type(hookState) ~= "table" then
    hookState = {Current = state}
    env.__XERO_MVSD_ACKLAB_HOOK = hookState

    local oldNamecall
    oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
        local shared = env.__XERO_MVSD_ACKLAB_HOOK
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
                local naturalAt = os.clock()

                s.Armed = false
                s.Pending = true
                s.NaturalAt = naturalAt
                s.ReplayAt = 0
                s.CaptureUntil = naturalAt + 0.90

                task.defer(function()
                    if not s.Alive then
                        return
                    end

                    push(string.rep("=", 58))
                    push("[NATURAL SHOOTGUN]")
                    push("t = " .. string.format("%.6f", naturalAt))

                    if typeof(args[1]) == "Vector3" then
                        push("Origin: " .. vec3(args[1]))
                    end

                    if typeof(args[2]) == "Vector3" then
                        push("Aim: " .. vec3(args[2]))
                    end

                    push("Hit: " .. pathOf(args[3]))

                    if typeof(args[4]) == "Vector3" then
                        push("HitPos: " .. vec3(args[4]))
                    end

                    push(
                        "Replay único en "
                        .. string.format("%.3f s", s.Delay)
                    )

                    task.delay(s.Delay, function()
                        local current = env.__XERO_MVSD_ACKLAB_HOOK
                        if not current or current.Current ~= s or not s.Alive then
                            s.Pending = false
                            return
                        end

                        s.ReplayAt = os.clock()

                        local ok, err = pcall(function()
                            self:FireServer(
                                table.unpack(args, 1, args.n)
                            )
                        end)

                        push("")
                        push("[REPLAY SHOOTGUN]")
                        push("t = " .. string.format("%.6f", s.ReplayAt))
                        push(
                            "Δ real = "
                            .. string.format(
                                "%.4f s",
                                s.ReplayAt - naturalAt
                            )
                        )
                        push(
                            "FireServer: "
                            .. (
                                ok
                                and "OK"
                                or ("ERROR: " .. tostring(err))
                            )
                        )

                        task.delay(0.72, function()
                            if not s.Alive then return end

                            push("")
                            push("[FIN]")
                            push(
                                "Ventana de respuestas terminada. "
                                .. "Revisa eventos POST-NATURAL y POST-REPLAY."
                            )

                            s.Pending = false
                            s.CaptureUntil = 0
                        end)
                    end)
                end)
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

local guiParent = playerGui
pcall(function()
    if gethui then
        guiParent = gethui()
    end
end)

local oldGui = guiParent:FindFirstChild("XeroMVSDServerAckLab")
if oldGui then
    oldGui:Destroy()
end

local gui = Instance.new("ScreenGui")
gui.Name = "XeroMVSDServerAckLab"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 2147483647
gui.Parent = guiParent

local frame = Instance.new("Frame")
frame.AnchorPoint = Vector2.new(0.5, 0.5)
frame.Position = UDim2.fromScale(0.5, 0.5)
frame.Size = UDim2.fromOffset(440, 410)
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
title.Text = "XERO | MVSD SERVER-ACK LAB"
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
subtitle.Text = "Respuesta del servidor · by Kev"
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
status.Size = UDim2.new(1, -32, 0, 48)
status.BackgroundColor3 = Color3.fromRGB(14, 14, 14)
status.TextColor3 = Color3.fromRGB(220, 220, 220)
status.Font = Enum.Font.GothamMedium
status.TextSize = 11
status.TextWrapped = true
status.Parent = frame
Instance.new("UICorner", status).CornerRadius = UDim.new(0, 10)

local function refreshStatus()
    if state.Pending then
        status.Text = "PRUEBA EN CURSO · capturando respuestas del servidor"
    elseif state.Armed then
        status.Text = (
            "ARMADO · haz UN disparo normal · replay en "
            .. string.format("%.2f s", state.Delay)
        )
    else
        status.Text = (
            "Desarmado · delay "
            .. string.format("%.2f s", state.Delay)
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
    return b
end

button("ARMAR", 16, 132, 110, function()
    if not state.Pending then
        state.Armed = true
        push("[SYSTEM] Server-Ack Lab armado.")
        refreshStatus()
    end
end)

button("0.10", 138, 132, 74, function()
    if not state.Pending then
        state.Delay = 0.10
        refreshStatus()
    end
end)

button("0.18", 222, 132, 74, function()
    if not state.Pending then
        state.Delay = 0.18
        refreshStatus()
    end
end)

button("0.30", 306, 132, 74, function()
    if not state.Pending then
        state.Delay = 0.30
        refreshStatus()
    end
end)

button("LIMPIAR", 16, 178, 110, function()
    if not state.Pending then
        table.clear(state.Lines)
        refreshStatus()
    end
end)

button("COPIAR TODO", 138, 178, 242, function()
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
preview.Position = UDim2.fromOffset(16, 226)
preview.Size = UDim2.new(1, -32, 1, -242)
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

-- Mobile/PC drag
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

track(UserInputService.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement then
        updateDrag(input)
    end
end))

track(UserInputService.TouchMoved:Connect(function(input)
    updateDrag(input)
end))

track(UserInputService.InputEnded:Connect(function(input)
    if input == activeInput
        or input.UserInputType == Enum.UserInputType.MouseButton1
    then
        dragging = false
        activeInput = nil
        dragStart = nil
        frameStart = nil
    end
end))

track(UserInputService.TouchEnded:Connect(function(input)
    if input == activeInput then
        dragging = false
        activeInput = nil
        dragStart = nil
        frameStart = nil
    end
end))

local function cleanup()
    if not state.Alive then
        return
    end

    state.Alive = false
    state.Armed = false
    state.Pending = false
    state.CaptureUntil = 0

    if hookState and hookState.Current == state then
        hookState.Current = nil
    end

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

env.__XERO_MVSD_ACKLAB_CLEANUP = cleanup

refreshStatus()

print("[XeroHub] MVSD Server-Ack Lab cargado | by Kev")
