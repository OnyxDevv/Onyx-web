-- XeroHub | MVSD Shoot Cadence Lab | Kev
-- Passive only: records natural ShootGun calls and timing.
-- Does NOT call FireServer and does NOT modify shots.

local Players = game:GetService("Players")

local player = Players.LocalPlayer
while not player do
    task.wait()
    player = Players.LocalPlayer
end

local env = (getgenv and getgenv()) or _G

if env.__XERO_MVSD_CADENCE_CLEANUP then
    pcall(env.__XERO_MVSD_CADENCE_CLEANUP)
end

local state = {
    Alive = true,
    Capturing = false,
    Shots = {},
    Lines = {},
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
    return string.format(
        "(%.3f, %.3f, %.3f)",
        v.X, v.Y, v.Z
    )
end

local hookState = env.__XERO_MVSD_CADENCE_HOOK

if type(hookState) ~= "table" then
    hookState = {Current = state}
    env.__XERO_MVSD_CADENCE_HOOK = hookState

    local oldNamecall
    oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
        local shared = env.__XERO_MVSD_CADENCE_HOOK
        local s = shared and shared.Current

        if s and s.Alive and s.Capturing and not checkcaller() then
            local method = getnamecallmethod()

            if self.ClassName == "RemoteEvent"
                and method == "FireServer"
                and self.Name == "ShootGun"
            then
                local args = table.pack(...)
                local stamp = os.clock()

                task.defer(function()
                    local active = env.__XERO_MVSD_CADENCE_HOOK
                    if not active or active.Current ~= s or not s.Alive then
                        return
                    end

                    local previous = s.Shots[#s.Shots]
                    local delta = previous and (stamp - previous.Time) or nil

                    local shot = {
                        Time = stamp,
                        Delta = delta,
                        Origin = args[1],
                        Aim = args[2],
                        HitPart = args[3],
                        HitPosition = args[4],
                    }

                    s.Shots[#s.Shots + 1] = shot

                    push(
                        ("SHOT %d%s"):format(
                            #s.Shots,
                            delta and (" · Δ " .. string.format("%.4f s", delta)) or ""
                        )
                    )

                    if typeof(args[1]) == "Vector3" then
                        push("  Origin: " .. vec3(args[1]))
                    end

                    if typeof(args[2]) == "Vector3" then
                        push("  Aim: " .. vec3(args[2]))
                    end

                    if typeof(args[3]) == "Instance" then
                        push("  Hit: " .. pathOf(args[3]))
                    else
                        push("  Hit: " .. tostring(args[3]))
                    end

                    if typeof(args[4]) == "Vector3" then
                        push("  HitPos: " .. vec3(args[4]))
                    end
                end)
            end
        end

        return oldNamecall(self, ...)
    end)
else
    hookState.Current = state
end

local function summarize()
    local n = #state.Shots

    push(string.rep("=", 52))
    push("[RESUMEN]")
    push("Disparos capturados: " .. tostring(n))

    if n < 2 then
        push("No hay suficientes tiros para calcular cadencia.")
        return
    end

    local sum = 0
    local minDelta = math.huge
    local maxDelta = 0
    local count = 0

    for i = 2, n do
        local d = state.Shots[i].Delta
        if d then
            sum += d
            count += 1

            if d < minDelta then
                minDelta = d
            end

            if d > maxDelta then
                maxDelta = d
            end
        end
    end

    local avg = count > 0 and (sum / count) or 0

    push("Δ mínimo: " .. string.format("%.4f s", minDelta))
    push("Δ promedio: " .. string.format("%.4f s", avg))
    push("Δ máximo: " .. string.format("%.4f s", maxDelta))

    if minDelta > 0 then
        push("Máx. observado aprox: " .. string.format("%.2f disparos/s", 1 / minDelta))
    end
end

-- UI
local guiParent = player:WaitForChild("PlayerGui")
pcall(function()
    if gethui then guiParent = gethui() end
end)

local oldGui = guiParent:FindFirstChild("XeroMVSDShootCadenceLab")
if oldGui then oldGui:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name = "XeroMVSDShootCadenceLab"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 2147483647
gui.Parent = guiParent

local frame = Instance.new("Frame")
frame.AnchorPoint = Vector2.new(0.5, 0.5)
frame.Position = UDim2.fromScale(0.5, 0.5)
frame.Size = UDim2.fromOffset(430, 360)
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
title.Text = "XERO | MVSD SHOOT CADENCE"
title.TextColor3 = Color3.fromRGB(245, 245, 245)
title.Font = Enum.Font.GothamBold
title.TextSize = 17
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = frame

local subtitle = Instance.new("TextLabel")
subtitle.Position = UDim2.fromOffset(16, 38)
subtitle.Size = UDim2.new(1, -32, 0, 18)
subtitle.BackgroundTransparency = 1
subtitle.Text = "Medición pasiva de ShootGun · by Kev"
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
status.Text = "Pulsa INICIAR y dispara 5–10 veces tan rápido como permita el juego."
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

button("INICIAR", 16, 126, 124, function()
    table.clear(state.Shots)
    table.clear(state.Lines)
    state.Capturing = true

    push("[SYSTEM]")
    push("Captura iniciada.")
    push("Dispara 5–10 veces tan rápido como permita el arma.")

    status.Text = "CAPTURANDO · dispara normalmente."
end)

button("DETENER", 153, 126, 124, function()
    state.Capturing = false
    summarize()
    status.Text = "Captura detenida."
end)

button("COPIAR TODO", 290, 126, 124, function()
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
preview.Position = UDim2.fromOffset(16, 178)
preview.Size = UDim2.new(1, -32, 1, -194)
preview.BackgroundColor3 = Color3.fromRGB(11, 11, 11)
preview.TextColor3 = Color3.fromRGB(150, 150, 150)
preview.Font = Enum.Font.Code
preview.TextSize = 10
preview.TextWrapped = true
preview.TextXAlignment = Enum.TextXAlignment.Left
preview.TextYAlignment = Enum.TextYAlignment.Top
preview.Text = "Esperando captura..."
preview.Parent = frame
Instance.new("UICorner", preview).CornerRadius = UDim.new(0, 10)

task.spawn(function()
    while state.Alive do
        local n = #state.Lines

        if n == 0 then
            preview.Text = "Esperando captura..."
        else
            local first = math.max(1, n - 14)
            local lines = {}

            for i = first, n do
                lines[#lines + 1] = state.Lines[i]
            end

            preview.Text = table.concat(lines, "\n")
        end

        task.wait(0.12)
    end
end)

local function cleanup()
    if not state.Alive then return end

    state.Alive = false
    state.Capturing = false

    if hookState and hookState.Current == state then
        hookState.Current = nil
    end

    pcall(function()
        gui:Destroy()
    end)
end

env.__XERO_MVSD_CADENCE_CLEANUP = cleanup

print("[XeroHub] MVSD Shoot Cadence Lab cargado | Passive | by Kev")
