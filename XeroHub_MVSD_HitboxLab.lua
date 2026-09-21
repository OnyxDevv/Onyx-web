-- XeroHub | MVSD RapidFire Lab | Kev
-- Bounded burst tester. No infinite loop.
-- Captures ONE natural ShootGun call, then repeats it a fixed number of times.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
while not player do
    task.wait()
    player = Players.LocalPlayer
end

local env = (getgenv and getgenv()) or _G

if env.__XERO_MVSD_RAPIDFIRE_CLEANUP then
    pcall(env.__XERO_MVSD_RAPIDFIRE_CLEANUP)
end

local state = {
    Alive = true,
    Armed = false,
    Pending = false,

    Interval = 0.05,
    Count = 8,

    Lines = {},
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

local hookState = env.__XERO_MVSD_RAPIDFIRE_HOOK

if type(hookState) ~= "table" then
    hookState = {Current = state}
    env.__XERO_MVSD_RAPIDFIRE_HOOK = hookState

    local oldNamecall
    oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
        local shared = env.__XERO_MVSD_RAPIDFIRE_HOOK
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

                task.defer(function()
                    if not s.Alive then return end

                    push(string.rep("=", 58))
                    push("[NATURAL SHOT CAPTURED]")
                    push("t = " .. string.format("%.6f", naturalAt))
                    push("Remote: " .. pathOf(self))

                    if typeof(args[1]) == "Vector3" then
                        push("Origin: " .. vec3(args[1]))
                    end

                    push("Hit: " .. pathOf(args[3]))

                    if typeof(args[4]) == "Vector3" then
                        push("HitPos: " .. vec3(args[4]))
                    end

                    push(
                        "Burst: "
                        .. tostring(s.Count)
                        .. " replay(s) cada "
                        .. string.format("%.3f s", s.Interval)
                    )

                    local startedAt = os.clock()
                    local sent = 0
                    local errors = 0

                    for i = 1, s.Count do
                        if not s.Alive then break end

                        task.wait(s.Interval)

                        local stamp = os.clock()

                        local ok, err = pcall(function()
                            self:FireServer(
                                table.unpack(args, 1, args.n)
                            )
                        end)

                        if ok then
                            sent += 1
                            push(
                                ("Replay %d/%d · Δ %.4f s · OK"):format(
                                    i,
                                    s.Count,
                                    stamp - naturalAt
                                )
                            )
                        else
                            errors += 1
                            push(
                                ("Replay %d/%d · ERROR: %s"):format(
                                    i,
                                    s.Count,
                                    tostring(err)
                                )
                            )
                        end
                    end

                    local endedAt = os.clock()

                    push("")
                    push("[RESUMEN]")
                    push("Enviados OK: " .. tostring(sent))
                    push("Errores cliente: " .. tostring(errors))
                    push(
                        "Duración burst: "
                        .. string.format("%.4f s", endedAt - startedAt)
                    )

                    if endedAt > startedAt and sent > 0 then
                        push(
                            "Cadencia enviada aprox: "
                            .. string.format(
                                "%.2f llamadas/s",
                                sent / (endedAt - startedAt)
                            )
                        )
                    end

                    push(
                        "Ojo: FireServer=OK solo confirma envío desde cliente; "
                        .. "mira si el juego muestra múltiples tracers/sonidos."
                    )

                    s.Pending = false
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

local oldGui = guiParent:FindFirstChild("XeroMVSDRapidFireLab")
if oldGui then
    oldGui:Destroy()
end

local gui = Instance.new("ScreenGui")
gui.Name = "XeroMVSDRapidFireLab"
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
title.Text = "XERO | MVSD RAPIDFIRE LAB"
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
subtitle.Text = "Burst limitado de ShootGun · by Kev"
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
status.Size = UDim2.new(1, -32, 0, 50)
status.BackgroundColor3 = Color3.fromRGB(14, 14, 14)
status.TextColor3 = Color3.fromRGB(220, 220, 220)
status.Font = Enum.Font.GothamMedium
status.TextSize = 11
status.TextWrapped = true
status.Parent = frame
Instance.new("UICorner", status).CornerRadius = UDim.new(0, 10)

local function refreshStatus()
    if state.Pending then
        status.Text = "BURST EN CURSO · espera a que termine"
    elseif state.Armed then
        status.Text = (
            "ARMADO · haz UN tiro normal · "
            .. tostring(state.Count)
            .. " replay(s) @ "
            .. string.format("%.3f s", state.Interval)
        )
    else
        status.Text = (
            "Desarmado · "
            .. tostring(state.Count)
            .. " replay(s) @ "
            .. string.format("%.3f s", state.Interval)
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

button("ARMAR", 16, 134, 100, function()
    if not state.Pending then
        state.Armed = true
        push("[SYSTEM] RapidFire Lab armado.")
        refreshStatus()
    end
end)

button("3 tiros", 128, 134, 72, function()
    if not state.Pending then
        state.Count = 3
        refreshStatus()
    end
end)

button("5 tiros", 210, 134, 72, function()
    if not state.Pending then
        state.Count = 5
        refreshStatus()
    end
end)

button("8 tiros", 292, 134, 72, function()
    if not state.Pending then
        state.Count = 8
        refreshStatus()
    end
end)

button("10 tiros", 374, 134, 60, function()
    if not state.Pending then
        state.Count = 10
        refreshStatus()
    end
end)

button("0.20", 16, 182, 76, function()
    if not state.Pending then
        state.Interval = 0.20
        refreshStatus()
    end
end)

button("0.10", 102, 182, 76, function()
    if not state.Pending then
        state.Interval = 0.10
        refreshStatus()
    end
end)

button("0.05", 188, 182, 76, function()
    if not state.Pending then
        state.Interval = 0.05
        refreshStatus()
    end
end)

button("0.02", 274, 182, 76, function()
    if not state.Pending then
        state.Interval = 0.02
        refreshStatus()
    end
end)

button("LIMPIAR", 360, 182, 74, function()
    if not state.Pending then
        table.clear(state.Lines)
        refreshStatus()
    end
end)

button("COPIAR TODO", 16, 230, 418, function()
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
preview.Position = UDim2.fromOffset(16, 278)
preview.Size = UDim2.new(1, -32, 1, -294)
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

env.__XERO_MVSD_RAPIDFIRE_CLEANUP = cleanup

refreshStatus()

print("[XeroHub] MVSD RapidFire Lab cargado | bounded burst | by Kev")
