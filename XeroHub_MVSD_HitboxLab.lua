-- XeroHub | MVSD Double-Shot Lab | Kev
-- Controlled server cooldown probe:
-- Captures ONE natural ShootGun call, repeats it ONCE after a short delay,
-- then auto-disarms. No continuous spam.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
while not player do
    task.wait()
    player = Players.LocalPlayer
end

local env = (getgenv and getgenv()) or _G

if env.__XERO_MVSD_DOUBLESHOT_CLEANUP then
    pcall(env.__XERO_MVSD_DOUBLESHOT_CLEANUP)
end

local state = {
    Alive = true,
    Armed = false,
    Delay = 0.18,
    Connections = {},
    Lines = {},
    Pending = false,
    LastNaturalAt = 0,
    LastReplayAt = 0,
    ReplayCount = 0,
}

local function push(s)
    state.Lines[#state.Lines + 1] = tostring(s)
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
    return string.format("(%.3f, %.3f, %.3f)", v.X, v.Y, v.Z)
end

local function getHumanoidFromHit(hit)
    if typeof(hit) ~= "Instance" then
        return nil, nil
    end

    local node = hit
    for _ = 1, 6 do
        if not node then break end

        local hum = node:FindFirstChildOfClass("Humanoid")
        if hum then
            return hum, node
        end

        node = node.Parent
    end

    return nil, nil
end

local hookState = env.__XERO_MVSD_DOUBLESHOT_HOOK

if type(hookState) ~= "table" then
    hookState = {Current = state}
    env.__XERO_MVSD_DOUBLESHOT_HOOK = hookState

    local oldNamecall
    oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
        local shared = env.__XERO_MVSD_DOUBLESHOT_HOOK
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

                s.Pending = true
                s.Armed = false
                s.LastNaturalAt = naturalAt

                task.defer(function()
                    local active = env.__XERO_MVSD_DOUBLESHOT_HOOK
                    if not active or active.Current ~= s or not s.Alive then
                        return
                    end

                    local hitPart = args[3]
                    local hum, char = getHumanoidFromHit(hitPart)
                    local beforeHealth = hum and hum.Health or nil

                    push(string.rep("=", 56))
                    push("[NATURAL SHOT]")
                    push("t = " .. string.format("%.6f", naturalAt))

                    if typeof(args[1]) == "Vector3" then
                        push("Origin: " .. vec3(args[1]))
                    end

                    if typeof(args[2]) == "Vector3" then
                        push("Aim: " .. vec3(args[2]))
                    end

                    push("Hit: " .. pathOf(hitPart))

                    if typeof(args[4]) == "Vector3" then
                        push("HitPos: " .. vec3(args[4]))
                    end

                    if hum then
                        push("Target: " .. tostring(char and char.Name or "?"))
                        push("Health antes: " .. tostring(beforeHealth))
                    else
                        push("Target humanoid: no detectado")
                    end

                    push("Replay programado en: " .. string.format("%.3f s", s.Delay))

                    task.delay(s.Delay, function()
                        local current = env.__XERO_MVSD_DOUBLESHOT_HOOK
                        if not current or current.Current ~= s or not s.Alive then
                            s.Pending = false
                            return
                        end

                        local replayAt = os.clock()
                        s.LastReplayAt = replayAt
                        s.ReplayCount += 1

                        local ok, err = pcall(function()
                            self:FireServer(table.unpack(args, 1, args.n))
                        end)

                        push("")
                        push("[REPLAY SHOT]")
                        push("t = " .. string.format("%.6f", replayAt))
                        push(
                            "Δ real = "
                            .. string.format("%.4f s", replayAt - naturalAt)
                        )
                        push("FireServer: " .. (ok and "OK" or ("ERROR: " .. tostring(err))))

                        task.delay(0.45, function()
                            if not s.Alive then return end

                            if hum and hum.Parent then
                                push("Health después: " .. tostring(hum.Health))

                                if beforeHealth ~= nil then
                                    push(
                                        "Cambio de vida observado: "
                                        .. tostring(beforeHealth - hum.Health)
                                    )
                                end
                            end

                            push("Prueba terminada. Se desarmó automáticamente.")
                            s.Pending = false
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

local guiParent = player:WaitForChild("PlayerGui")
pcall(function()
    if gethui then
        guiParent = gethui()
    end
end)

local oldGui = guiParent:FindFirstChild("XeroMVSDDoubleShotLab")
if oldGui then
    oldGui:Destroy()
end

local gui = Instance.new("ScreenGui")
gui.Name = "XeroMVSDDoubleShotLab"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 2147483647
gui.Parent = guiParent

local frame = Instance.new("Frame")
frame.AnchorPoint = Vector2.new(0.5, 0.5)
frame.Position = UDim2.fromScale(0.5, 0.5)
frame.Size = UDim2.fromOffset(440, 390)
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
title.Text = "XERO | MVSD DOUBLE-SHOT LAB"
title.TextColor3 = Color3.fromRGB(245, 245, 245)
title.Font = Enum.Font.GothamBold
title.TextSize = 17
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = frame

local subtitle = Instance.new("TextLabel")
subtitle.Position = UDim2.fromOffset(16, 38)
subtitle.Size = UDim2.new(1, -32, 0, 18)
subtitle.BackgroundTransparency = 1
subtitle.Text = "Prueba controlada de cooldown · by Kev"
subtitle.TextColor3 = Color3.fromRGB(125, 125, 125)
subtitle.Font = Enum.Font.Gotham
subtitle.TextSize = 11
subtitle.TextXAlignment = Enum.TextXAlignment.Left
subtitle.Parent = frame

local status = Instance.new("TextLabel")
status.Position = UDim2.fromOffset(16, 68)
status.Size = UDim2.new(1, -32, 0, 48)
status.BackgroundColor3 = Color3.fromRGB(14, 14, 14)
status.TextColor3 = Color3.fromRGB(220, 220, 220)
status.Font = Enum.Font.GothamMedium
status.TextSize = 11
status.TextWrapped = true
status.Text = "Desarmado · delay 0.18 s"
status.Parent = frame
Instance.new("UICorner", status).CornerRadius = UDim.new(0, 10)

local function refreshStatus()
    if state.Pending then
        status.Text = "PRUEBA EN CURSO · esperando replay/resultado"
    elseif state.Armed then
        status.Text = (
            "ARMADO · haz UN disparo normal · replay único en "
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

button("ARMAR DOBLE", 16, 132, 126, function()
    if state.Pending then
        refreshStatus()
        return
    end

    state.Armed = true
    push("[SYSTEM] Prueba armada.")
    refreshStatus()
end)

button("0.10 s", 156, 132, 80, function()
    if not state.Pending then
        state.Delay = 0.10
        refreshStatus()
    end
end)

button("0.18 s", 246, 132, 80, function()
    if not state.Pending then
        state.Delay = 0.18
        refreshStatus()
    end
end)

button("0.30 s", 336, 132, 88, function()
    if not state.Pending then
        state.Delay = 0.30
        refreshStatus()
    end
end)

button("LIMPIAR", 16, 180, 126, function()
    if not state.Pending then
        table.clear(state.Lines)
        refreshStatus()
    end
end)

button("COPIAR TODO", 156, 180, 268, function()
    local data = table.concat(state.Lines, "\n")
    local clip = setclipboard or toclipboard

    if data == "" then
        status.Text = "No hay datos todavía."
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
            local first = math.max(1, n - 16)
            local lines = {}

            for i = first, n do
                lines[#lines + 1] = state.Lines[i]
            end

            preview.Text = table.concat(lines, "\n")
        end

        task.wait(0.10)
    end
end)

-- =========================
-- Drag / mover ventana
-- =========================

local dragging = false
local dragInput = nil
local dragStart = nil
local frameStart = nil

title.Active = true

title.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch
    then
        dragging = true
        dragInput = input
        dragStart = input.Position
        frameStart = frame.Position
    end
end)

title.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch
    then
        dragInput = input
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if dragging and input == dragInput and dragStart and frameStart then
        local delta = input.Position - dragStart

        frame.Position = UDim2.new(
            frameStart.X.Scale,
            frameStart.X.Offset + delta.X,
            frameStart.Y.Scale,
            frameStart.Y.Offset + delta.Y
        )
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input == dragInput
        or input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch
    then
        dragging = false
        dragInput = nil
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

env.__XERO_MVSD_DOUBLESHOT_CLEANUP = cleanup

print("[XeroHub] MVSD Double-Shot Lab cargado | One replay only | by Kev")
