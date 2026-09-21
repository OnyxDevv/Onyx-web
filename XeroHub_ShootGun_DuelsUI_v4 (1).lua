-- XeroHub | MVSD Sound Lab | Kev
-- Captura sonidos reproducidos durante: disparo, kill y muerte.

local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")

local player = Players.LocalPlayer
if not player then return end

local playerGui = player:WaitForChild("PlayerGui")
local runtimeEnv = (getgenv and getgenv()) or _G

if runtimeEnv.__XERO_MVSD_SOUND_LAB_CLEANUP then
    pcall(runtimeEnv.__XERO_MVSD_SOUND_LAB_CLEANUP)
end

local state = {
    Alive = true,
    Recording = false,
    Label = "SIN ETIQUETA",
    Logs = {},
    Connections = {},
    BoundSounds = setmetatable({}, {__mode = "k"}),
    LastPlayedAt = setmetatable({}, {__mode = "k"}),
}

local function track(connection)
    if connection then
        state.Connections[#state.Connections + 1] = connection
    end
    return connection
end

local function safePath(object)
    if not object then return "nil" end

    local parts = {}
    local current = object
    local guard = 0

    while current and current ~= game and guard < 40 do
        table.insert(parts, 1, current.Name)
        current = current.Parent
        guard += 1
    end

    if current == game then
        table.insert(parts, 1, "game")
    end

    return table.concat(parts, ".")
end

local function resolveOwner(sound)
    for _, plr in ipairs(Players:GetPlayers()) do
        local char = plr.Character
        if char and sound:IsDescendantOf(char) then
            return plr.Name
        end
    end
    return "Ninguno"
end

local function resolveWorldPosition(sound)
    local object = sound.Parent
    while object and object ~= game do
        if object:IsA("BasePart") then
            return object.Position
        elseif object:IsA("Attachment") then
            return object.WorldPosition
        end
        object = object.Parent
    end
    return nil
end

local output
local status

local function refreshOutput()
    if not output then return end

    if #state.Logs == 0 then
        output.Text = "Sin sonidos capturados."
    else
        output.Text = table.concat(state.Logs, "\n\n")
    end
end

local function emitSound(sound, source)
    if not state.Recording or not sound or not sound.Parent then return end

    local now = os.clock()
    local previous = state.LastPlayedAt[sound] or 0
    if now - previous < 0.04 then
        return
    end
    state.LastPlayedAt[sound] = now

    local position = resolveWorldPosition(sound)
    local distanceText = "N/A"

    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if position and hrp then
        distanceText = string.format("%.2f studs", (position - hrp.Position).Magnitude)
    end

    local lines = {
        "[" .. state.Label .. "]",
        "Fuente: " .. tostring(source),
        "Nombre: " .. tostring(sound.Name),
        "SoundId: " .. tostring(sound.SoundId),
        "Ruta: " .. safePath(sound),
        "Dueño del Character: " .. resolveOwner(sound),
        "Distancia local: " .. distanceText,
        "Volume: " .. tostring(sound.Volume),
        "PlaybackSpeed: " .. tostring(sound.PlaybackSpeed),
        "TimePosition: " .. string.format("%.3f", tonumber(sound.TimePosition) or 0),
    }

    state.Logs[#state.Logs + 1] = table.concat(lines, "\n")

    if #state.Logs > 120 then
        table.remove(state.Logs, 1)
    end

    print(state.Logs[#state.Logs])
    task.defer(refreshOutput)
end

local function bindSound(sound)
    if not sound
        or not sound:IsA("Sound")
        or state.BoundSounds[sound]
    then
        return
    end

    state.BoundSounds[sound] = true

    track(sound.Played:Connect(function()
        emitSound(sound, "Sound.Played")
    end))

    track(sound:GetPropertyChangedSignal("Playing"):Connect(function()
        if sound.Playing then
            emitSound(sound, "Playing=true")
        end
    end))

    task.defer(function()
        if state.Alive and state.Recording
            and sound.Parent
            and (sound.Playing or sound.IsPlaying)
        then
            emitSound(sound, "Creado reproduciéndose")
        end
    end)
end

local function scanRoot(root)
    if not root then return end

    if root:IsA("Sound") then
        bindSound(root)
    end

    for _, object in ipairs(root:GetDescendants()) do
        if object:IsA("Sound") then
            bindSound(object)
        end
    end

    track(root.DescendantAdded:Connect(function(object)
        if object:IsA("Sound") then
            bindSound(object)
        end
    end))
end

scanRoot(workspace)
scanRoot(SoundService)
scanRoot(playerGui)
scanRoot(player:FindFirstChildOfClass("Backpack"))

track(player.CharacterAdded:Connect(function(char)
    scanRoot(char)
end))

-- ============================================================
-- UI
-- ============================================================

local parent = playerGui
pcall(function()
    if gethui then
        parent = gethui()
    else
        parent = CoreGui
    end
end)

local oldGui = parent:FindFirstChild("XeroHub_MVSD_SoundLab")
if oldGui then oldGui:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name = "XeroHub_MVSD_SoundLab"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 2147483647
gui.Parent = parent

local frame = Instance.new("Frame")
frame.Size = UDim2.fromOffset(560, 430)
frame.Position = UDim2.new(0.5, -280, 0.5, -215)
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
title.Size = UDim2.new(1, -30, 0, 36)
title.Position = UDim2.fromOffset(15, 8)
title.BackgroundTransparency = 1
title.Text = "XeroHub · MVSD Sound Lab"
title.TextColor3 = Color3.fromRGB(245, 245, 245)
title.Font = Enum.Font.GothamBold
title.TextSize = 16
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = frame

status = Instance.new("TextLabel")
status.Size = UDim2.new(1, -30, 0, 42)
status.Position = UDim2.fromOffset(15, 42)
status.BackgroundTransparency = 1
status.Text = "Selecciona una captura, haz la acción y pulsa DETENER."
status.TextColor3 = Color3.fromRGB(165, 165, 165)
status.Font = Enum.Font.Gotham
status.TextSize = 12
status.TextWrapped = true
status.TextXAlignment = Enum.TextXAlignment.Left
status.Parent = frame

output = Instance.new("TextBox")
output.Size = UDim2.new(1, -30, 1, -164)
output.Position = UDim2.fromOffset(15, 88)
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
output.TextSize = 10
output.Text = "Sin sonidos capturados."
output.Parent = frame
Instance.new("UICorner", output).CornerRadius = UDim.new(0, 10)

local function makeButton(text, x, width)
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(width, -5, 0, 36)
    button.Position = UDim2.new(x, 15, 1, -48)
    button.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    button.BorderSizePixel = 0
    button.Text = text
    button.TextColor3 = Color3.fromRGB(235, 235, 235)
    button.Font = Enum.Font.GothamMedium
    button.TextSize = 10
    button.Parent = frame
    Instance.new("UICorner", button).CornerRadius = UDim.new(0, 9)
    return button
end

local shotBtn = makeButton("DISPARO", 0.00, 0.18)
local killBtn = makeButton("KILL", 0.19, 0.15)
local deathBtn = makeButton("MUERTE", 0.35, 0.17)
local stopBtn = makeButton("DETENER", 0.53, 0.19)
local copyBtn = makeButton("COPIAR", 0.73, 0.23)

local function startCapture(label)
    state.Label = label
    state.Recording = true
    status.Text = "GRABANDO " .. label .. " · haz la acción una vez y pulsa DETENER."
    status.TextColor3 = Color3.fromRGB(120, 230, 140)
end

shotBtn.MouseButton1Click:Connect(function()
    startCapture("DISPARO")
end)

killBtn.MouseButton1Click:Connect(function()
    startCapture("KILL")
end)

deathBtn.MouseButton1Click:Connect(function()
    startCapture("MUERTE")
end)

stopBtn.MouseButton1Click:Connect(function()
    state.Recording = false
    status.Text = "Detenido. Puedes capturar otra acción o COPIAR."
    status.TextColor3 = Color3.fromRGB(180, 180, 180)
end)

copyBtn.MouseButton1Click:Connect(function()
    local result = #state.Logs > 0
        and table.concat(state.Logs, "\n\n")
        or "Sin sonidos capturados."

    if type(setclipboard) == "function" then
        pcall(setclipboard, result)
        status.Text = "Log copiado."
    else
        output.TextEditable = true
        output.Text = result
        output:CaptureFocus()
        status.Text = "Sin setclipboard: copia manualmente del cuadro."
    end
end)

-- Drag
local dragging = false
local dragStart
local frameStart

track(frame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch
    then
        dragging = true
        dragStart = input.Position
        frameStart = frame.Position
    end
end))

track(UserInputService.InputChanged:Connect(function(input)
    if not dragging or not dragStart or not frameStart then return end

    if input.UserInputType ~= Enum.UserInputType.MouseMovement
        and input.UserInputType ~= Enum.UserInputType.Touch
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
end))

track(UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch
    then
        dragging = false
    end
end))

runtimeEnv.__XERO_MVSD_SOUND_LAB_CLEANUP = function()
    if not state.Alive then return end
    state.Alive = false
    state.Recording = false

    for i = #state.Connections, 1, -1 do
        local connection = state.Connections[i]
        pcall(function() connection:Disconnect() end)
        state.Connections[i] = nil
    end

    if gui and gui.Parent then
        gui:Destroy()
    end
end

print("[XeroHub] MVSD Sound Lab cargado.")
