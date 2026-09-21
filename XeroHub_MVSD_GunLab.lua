-- XeroHub | MVSD Gun Lab | Kev
-- Captura pasiva: NO dispara remotes, NO modifica balas.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
while not player do
    task.wait()
    player = Players.LocalPlayer
end

local env = (getgenv and getgenv()) or _G

if env.__XERO_MVSD_GUNLAB_CLEANUP then
    pcall(env.__XERO_MVSD_GUNLAB_CLEANUP)
end

local state = {
    Alive = true,
    Armed = false,
    Label = "SIN ETIQUETA",
    ShotAt = 0,
    CaptureUntil = 0,
    Serial = 0,
    Connections = {},
    ToolConnections = setmetatable({}, {__mode = "k"}),
    Lines = {},
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
    push(string.rep("=", 56))
end

local function instancePath(inst)
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
    return string.format(
        "Vector3.new(%.4f, %.4f, %.4f)",
        v.X, v.Y, v.Z
    )
end

local function vec2(v)
    return string.format(
        "Vector2.new(%.4f, %.4f)",
        v.X, v.Y
    )
end

local function cfText(cf)
    local a = {cf:GetComponents()}
    local out = {}
    for i = 1, #a do
        out[i] = string.format("%.5f", a[i])
    end
    return "CFrame.new(" .. table.concat(out, ", ") .. ")"
end

local function serialize(value, depth, seen)
    depth = depth or 0
    seen = seen or {}

    if depth > 3 then
        return "<max-depth>"
    end

    local t = typeof(value)

    if t == "nil" then
        return "nil"
    elseif t == "string" then
        return string.format("%q", value)
    elseif t == "number" or t == "boolean" then
        return tostring(value)
    elseif t == "Vector3" then
        return vec3(value)
    elseif t == "Vector2" then
        return vec2(value)
    elseif t == "CFrame" then
        return cfText(value)
    elseif t == "Instance" then
        return "<" .. tostring(value.ClassName) .. " " .. instancePath(value) .. ">"
    elseif t == "Ray" then
        return "Ray.new(" .. vec3(value.Origin) .. ", " .. vec3(value.Direction) .. ")"
    elseif t == "EnumItem" then
        return tostring(value)
    elseif t == "table" then
        if seen[value] then
            return "<recursive-table>"
        end

        seen[value] = true
        local out = {}
        local count = 0

        for k, v in pairs(value) do
            count += 1
            if count > 20 then
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

    return "<" .. t .. ":" .. tostring(value) .. ">"
end

local function dumpArgs(args)
    if args.n == 0 then
        push("(sin argumentos)")
        return
    end

    for i = 1, args.n do
        push(
            ("[%d] (%s) %s"):format(
                i,
                typeof(args[i]),
                serialize(args[i])
            )
        )
    end
end

local function beginShot(source)
    if not state.Armed then return end

    state.Serial += 1
    state.ShotAt = os.clock()
    state.CaptureUntil = state.ShotAt + 1.20

    sep()
    push(("[SHOT %d · %s]"):format(state.Serial, state.Label))
    push("Fuente: " .. tostring(source))
    push("PlaceId: " .. tostring(game.PlaceId))
    push("Tiempo: " .. string.format("%.6f", state.ShotAt))
end

local function captureRemote(remote, method, args, stamp)
    task.defer(function()
        if not state.Alive then return end

        push("")
        push(
            ("[REMOTE · %s · Δ %+0.4f s]"):format(
                method,
                stamp - state.ShotAt
            )
        )
        push("Clase: " .. tostring(remote.ClassName))
        push("Nombre: " .. tostring(remote.Name))
        push("Ruta: " .. instancePath(remote))
        push("Argumentos:")
        dumpArgs(args)
    end)
end

local function captureRaycast(origin, direction, params, stamp)
    task.defer(function()
        if not state.Alive then return end

        push("")
        push(
            ("[RAYCAST · Δ %+0.4f s]"):format(
                stamp - state.ShotAt
            )
        )
        push("Origen: " .. serialize(origin))
        push("Dirección: " .. serialize(direction))
        push("Magnitud: " .. string.format("%.4f", direction.Magnitude))

        if params then
            push("FilterType: " .. tostring(params.FilterType))
            push("IgnoreWater: " .. tostring(params.IgnoreWater))
        end
    end)
end

local hookState = env.__XERO_MVSD_GUNLAB_HOOK

if type(hookState) ~= "table" then
    hookState = {Current = state}
    env.__XERO_MVSD_GUNLAB_HOOK = hookState

    local oldNamecall
    oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
        local shared = env.__XERO_MVSD_GUNLAB_HOOK
        local s = shared and shared.Current

        if s and s.Alive and not checkcaller() then
            local method = getnamecallmethod()
            local stamp = os.clock()

            if s.Armed and stamp <= s.CaptureUntil then
                if (self.ClassName == "RemoteEvent" and method == "FireServer")
                    or (self.ClassName == "RemoteFunction" and method == "InvokeServer")
                then
                    local args = table.pack(...)
                    task.defer(function()
                        local current = env.__XERO_MVSD_GUNLAB_HOOK
                        if current and current.Current == s and s.Alive then
                            captureRemote(self, method, args, stamp)
                        end
                    end)

                elseif self == workspace and method == "Raycast" then
                    local origin, direction, params = ...

                    if typeof(origin) == "Vector3"
                        and typeof(direction) == "Vector3"
                    then
                        task.defer(function()
                            local current = env.__XERO_MVSD_GUNLAB_HOOK
                            if current and current.Current == s and s.Alive then
                                captureRaycast(origin, direction, params, stamp)
                            end
                        end)
                    end
                end
            end
        end

        return oldNamecall(self, ...)
    end)
else
    hookState.Current = state
end

local function bindTool(tool)
    if not tool
        or not tool:IsA("Tool")
        or state.ToolConnections[tool]
    then
        return
    end

    local c = tool.Activated:Connect(function()
        beginShot("Tool.Activated · " .. tostring(tool.Name))
    end)

    state.ToolConnections[tool] = c
    track(c)
end

local function scanTools(container)
    if not container then return end
    for _, child in ipairs(container:GetChildren()) do
        if child:IsA("Tool") then
            bindTool(child)
        end
    end
end

local function bindCharacter(char)
    scanTools(char)
    track(char.ChildAdded:Connect(function(child)
        if child:IsA("Tool") then
            bindTool(child)
        end
    end))
end

if player.Character then
    bindCharacter(player.Character)
end

track(player.CharacterAdded:Connect(bindCharacter))

local backpack = player:FindFirstChildOfClass("Backpack")
if backpack then
    scanTools(backpack)
    track(backpack.ChildAdded:Connect(function(child)
        if child:IsA("Tool") then
            bindTool(child)
        end
    end))
end

track(UserInputService.InputBegan:Connect(function(input, processed)
    if processed or not state.Armed then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        beginShot("MouseButton1")
    end
end))

-- UI
local guiParent = player:WaitForChild("PlayerGui")
pcall(function()
    if gethui then guiParent = gethui() end
end)

local oldGui = guiParent:FindFirstChild("XeroMVSDGunLab")
if oldGui then oldGui:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name = "XeroMVSDGunLab"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 2147483647
gui.Parent = guiParent

local frame = Instance.new("Frame")
frame.AnchorPoint = Vector2.new(0.5, 0.5)
frame.Position = UDim2.fromScale(0.5, 0.5)
frame.Size = UDim2.fromOffset(430, 390)
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
title.Text = "XERO | MVSD GUN LAB"
title.TextColor3 = Color3.fromRGB(245, 245, 245)
title.Font = Enum.Font.GothamBold
title.TextSize = 17
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = frame

local subtitle = Instance.new("TextLabel")
subtitle.Position = UDim2.fromOffset(16, 38)
subtitle.Size = UDim2.new(1, -32, 0, 18)
subtitle.BackgroundTransparency = 1
subtitle.Text = "Captura pasiva · by Kev"
subtitle.TextColor3 = Color3.fromRGB(125, 125, 125)
subtitle.Font = Enum.Font.Gotham
subtitle.TextSize = 11
subtitle.TextXAlignment = Enum.TextXAlignment.Left
subtitle.Parent = frame

local status = Instance.new("TextLabel")
status.Position = UDim2.fromOffset(16, 67)
status.Size = UDim2.new(1, -32, 0, 44)
status.BackgroundColor3 = Color3.fromRGB(14, 14, 14)
status.TextColor3 = Color3.fromRGB(220, 220, 220)
status.Font = Enum.Font.GothamMedium
status.TextSize = 11
status.TextWrapped = true
status.Text = "Selecciona AIRE / PARED / ENEMIGO."
status.Parent = frame
Instance.new("UICorner", status).CornerRadius = UDim.new(0, 10)

local function makeButton(label, x, y, w, cb)
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

local function arm(label)
    state.Armed = true
    state.Label = label
    state.CaptureUntil = math.huge
    status.Text = "ARMADO: " .. label .. " · Haz UN solo disparo."
end

makeButton("AIRE", 16, 124, 124, function() arm("AIRE") end)
makeButton("PARED", 153, 124, 124, function() arm("PARED") end)
makeButton("ENEMIGO", 290, 124, 124, function() arm("ENEMIGO") end)

makeButton("DETENER", 16, 172, 124, function()
    state.Armed = false
    state.CaptureUntil = 0
    status.Text = "Captura detenida."
end)

makeButton("LIMPIAR", 153, 172, 124, function()
    table.clear(state.Lines)
    state.Serial = 0
    status.Text = "Log limpiado."
end)

makeButton("COPIAR TODO", 290, 172, 124, function()
    local data = table.concat(state.Lines, "\n")
    if data == "" then
        status.Text = "No hay datos."
        return
    end

    local clip = setclipboard or toclipboard
    if clip then
        pcall(clip, data)
        status.Text = "Copiado. Pégamelo aquí."
    else
        status.Text = "Tu executor no tiene setclipboard."
    end
end)

local preview = Instance.new("TextLabel")
preview.Position = UDim2.fromOffset(16, 220)
preview.Size = UDim2.new(1, -32, 1, -236)
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

track(RunService.Heartbeat:Connect(function()
    local n = #state.Lines
    if n == 0 then
        preview.Text = "Esperando captura..."
        return
    end

    local first = math.max(1, n - 12)
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
    state.Armed = false

    if hookState and hookState.Current == state then
        hookState.Current = nil
    end

    for i = #state.Connections, 1, -1 do
        local c = state.Connections[i]
        pcall(function() c:Disconnect() end)
        state.Connections[i] = nil
    end

    pcall(function() gui:Destroy() end)
end

env.__XERO_MVSD_GUNLAB_CLEANUP = cleanup

push("[SYSTEM]")
push("MVSD Gun Lab cargado.")
push("AIRE -> 1 tiro -> DETENER")
push("PARED -> 1 tiro -> DETENER")
push("ENEMIGO -> 1 tiro -> DETENER")
push("Luego COPIAR TODO.")

print("[XeroHub] MVSD Gun Lab cargado | Passive Capture | by Kev")
