-- XeroHub | MVSD Shoot Lab | Kev
-- Diagnóstico pasivo: registra las llamadas RemoteEvent/RemoteFunction que hace el juego
-- durante un disparo manual. NO bloquea ni modifica la llamada original.

local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local runtimeEnv = (getgenv and getgenv()) or _G

if runtimeEnv.__XERO_MVSD_SHOOT_LAB_CLEANUP then
    pcall(runtimeEnv.__XERO_MVSD_SHOOT_LAB_CLEANUP)
end

local state = {
    Alive = true,
    Recording = false,
    Logs = {},
    Connections = {},
}

local function track(c)
    if c then
        state.Connections[#state.Connections + 1] = c
    end
    return c
end

local function safePath(obj)
    if not obj then return "nil" end
    local parts = {}
    local current = obj
    local guard = 0

    while current and current ~= game and guard < 32 do
        table.insert(parts, 1, current.Name)
        current = current.Parent
        guard += 1
    end

    if current == game then
        table.insert(parts, 1, "game")
    end

    return table.concat(parts, ".")
end

local function serialize(value, depth, seen)
    depth = depth or 0
    seen = seen or {}

    if depth > 3 then
        return "<max-depth>"
    end

    local kind = typeof(value)

    if kind == "nil" then
        return "nil"
    elseif kind == "string" then
        return string.format("%q", value)
    elseif kind == "number" or kind == "boolean" then
        return tostring(value)
    elseif kind == "Vector3" then
        return string.format(
            "Vector3.new(%.6f, %.6f, %.6f)",
            value.X, value.Y, value.Z
        )
    elseif kind == "Vector2" then
        return string.format(
            "Vector2.new(%.6f, %.6f)",
            value.X, value.Y
        )
    elseif kind == "CFrame" then
        local comps = {value:GetComponents()}
        local text = {}
        for i = 1, #comps do
            text[i] = string.format("%.6f", comps[i])
        end
        return "CFrame.new(" .. table.concat(text, ", ") .. ")"
    elseif kind == "Instance" then
        return string.format(
            "<Instance %s | %s>",
            value.ClassName,
            safePath(value)
        )
    elseif kind == "EnumItem" then
        return tostring(value)
    elseif kind == "Ray" then
        return "Ray.new(" .. serialize(value.Origin, depth + 1, seen)
            .. ", " .. serialize(value.Direction, depth + 1, seen) .. ")"
    elseif kind == "table" then
        if seen[value] then return "<cycle>" end
        seen[value] = true

        local out = {}
        local count = 0
        for k, v in pairs(value) do
            count += 1
            if count > 24 then
                out[#out + 1] = "..."
                break
            end
            out[#out + 1] =
                "[" .. serialize(k, depth + 1, seen) .. "]="
                .. serialize(v, depth + 1, seen)
        end

        seen[value] = nil
        return "{" .. table.concat(out, ", ") .. "}"
    end

    return "<" .. kind .. ":" .. tostring(value) .. ">"
end

local function addLog(text)
    state.Logs[#state.Logs + 1] = text
    print(text)
end

local parent = player:WaitForChild("PlayerGui")
pcall(function()
    if gethui then
        parent = gethui()
    else
        parent = CoreGui
    end
end)

local oldGui = parent:FindFirstChild("XeroHub_MVSD_ShootLab")
if oldGui then oldGui:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name = "XeroHub_MVSD_ShootLab"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 2147483647
gui.Parent = parent

local frame = Instance.new("Frame")
frame.Size = UDim2.fromOffset(420, 330)
frame.Position = UDim2.new(0.5, -210, 0.5, -165)
frame.BackgroundColor3 = Color3.fromRGB(12, 12, 12)
frame.BorderSizePixel = 0
frame.Active = true
frame.Parent = gui
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 14)

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(58, 58, 58)
stroke.Thickness = 1
stroke.Parent = frame

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -30, 0, 38)
title.Position = UDim2.fromOffset(15, 8)
title.BackgroundTransparency = 1
title.Text = "XeroHub · MVSD Shoot Lab"
title.TextColor3 = Color3.fromRGB(245, 245, 245)
title.Font = Enum.Font.GothamBold
title.TextSize = 16
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = frame

local status = Instance.new("TextLabel")
status.Size = UDim2.new(1, -30, 0, 24)
status.Position = UDim2.fromOffset(15, 42)
status.BackgroundTransparency = 1
status.Text = "Listo. Pulsa INICIAR y haz 1 disparo manual."
status.TextColor3 = Color3.fromRGB(165, 165, 165)
status.Font = Enum.Font.Gotham
status.TextSize = 12
status.TextXAlignment = Enum.TextXAlignment.Left
status.Parent = frame

local output = Instance.new("TextBox")
output.Size = UDim2.new(1, -30, 1, -132)
output.Position = UDim2.fromOffset(15, 72)
output.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
output.BorderSizePixel = 0
output.ClearTextOnFocus = false
output.MultiLine = true
output.TextEditable = false
output.TextWrapped = false
output.TextXAlignment = Enum.TextXAlignment.Left
output.TextYAlignment = Enum.TextYAlignment.Top
output.TextColor3 = Color3.fromRGB(220, 220, 220)
output.Font = Enum.Font.Code
output.TextSize = 11
output.Text = "Los RemoteEvent/RemoteFunction aparecerán aquí.\n"
output.Parent = frame
Instance.new("UICorner", output).CornerRadius = UDim.new(0, 10)

local function makeButton(text, xScale, widthScale)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(widthScale, -6, 0, 36)
    b.Position = UDim2.new(xScale, 15, 1, -48)
    b.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    b.BorderSizePixel = 0
    b.Text = text
    b.TextColor3 = Color3.fromRGB(235, 235, 235)
    b.Font = Enum.Font.GothamMedium
    b.TextSize = 12
    b.Parent = frame
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 10)
    return b
end

local startBtn = makeButton("INICIAR", 0, 0.30)
local stopBtn = makeButton("DETENER", 0.32, 0.30)
local copyBtn = makeButton("COPIAR TODO", 0.64, 0.32)

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

track(UserInputService.InputChanged:Connect(function(input)
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

track(UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch
    then
        dragging = false
    end
end))

local function refreshOutput()
    output.Text = #state.Logs > 0
        and table.concat(state.Logs, "\n\n")
        or "Sin llamadas registradas todavía."
end

startBtn.MouseButton1Click:Connect(function()
    table.clear(state.Logs)
    state.Recording = true
    status.Text = "GRABANDO · haz UN disparo manual ahora."
    status.TextColor3 = Color3.fromRGB(120, 230, 140)
    refreshOutput()
end)

stopBtn.MouseButton1Click:Connect(function()
    state.Recording = false
    status.Text = "Detenido · copia el log y mándamelo."
    status.TextColor3 = Color3.fromRGB(180, 180, 180)
    refreshOutput()
end)

copyBtn.MouseButton1Click:Connect(function()
    local text = #state.Logs > 0
        and table.concat(state.Logs, "\n\n")
        or "Sin llamadas registradas."

    if type(setclipboard) == "function" then
        pcall(setclipboard, text)
        status.Text = "Log copiado."
    else
        status.Text = "Tu ejecutor no tiene setclipboard; copia desde el cuadro."
        output.TextEditable = true
        output:CaptureFocus()
        output.CursorPosition = 1
    end
end)

local oldNamecall
oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
    local method = getnamecallmethod()

    if state.Alive
        and state.Recording
        and not checkcaller()
        and (method == "FireServer" or method == "InvokeServer")
        and typeof(self) == "Instance"
        and (self:IsA("RemoteEvent")
            or self:IsA("UnreliableRemoteEvent")
            or self:IsA("RemoteFunction"))
    then
        local args = {...}
        local lines = {
            "[" .. method .. "]",
            "Clase: " .. self.ClassName,
            "Nombre: " .. self.Name,
            "Ruta: " .. safePath(self),
            "Argumentos:"
        }

        for i = 1, #args do
            lines[#lines + 1] = "[" .. i .. "] " .. serialize(args[i])
        end

        if #args == 0 then
            lines[#lines + 1] = "(sin argumentos)"
        end

        local entry = table.concat(lines, "\n")
        addLog(entry)

        task.defer(refreshOutput)
    end

    return oldNamecall(self, ...)
end)

runtimeEnv.__XERO_MVSD_SHOOT_LAB_CLEANUP = function()
    if not state.Alive then return end
    state.Alive = false
    state.Recording = false

    for i = #state.Connections, 1, -1 do
        local c = state.Connections[i]
        pcall(function() c:Disconnect() end)
        state.Connections[i] = nil
    end

    if gui and gui.Parent then
        gui:Destroy()
    end
end

print("[XeroHub] MVSD Shoot Lab cargado. INICIAR -> 1 disparo manual -> DETENER -> COPIAR TODO.")
