-- XeroHub | MVSD Death Lab | Kev
-- Scanner específico para aislar sonidos alrededor de Humanoid.Died.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local SoundService = game:GetService("SoundService")
local CoreGui = game:GetService("CoreGui")

local player = Players.LocalPlayer
if not player then return end

local playerGui = player:WaitForChild("PlayerGui")
local env = (getgenv and getgenv()) or _G

if env.__XERO_MVSD_DEATH_LAB_CLEANUP then
    pcall(env.__XERO_MVSD_DEATH_LAB_CLEANUP)
end

local state = {
    Alive = true,
    Armed = false,
    DeathAt = nil,
    WindowStart = nil,
    WindowEnd = nil,
    Logs = {},
    Connections = {},
    BoundSounds = setmetatable({}, {__mode = "k"}),
    LastPlayedAt = setmetatable({}, {__mode = "k"}),
    Character = nil,
    Humanoid = nil,
}

local IGNORE_NAMES = {
    Running = true,
    Jumping = true,
    Climbing = true,
    Swimming = true,
    FreeFalling = true,
    Landing = true,
    GettingUp = true,
    Died = false, -- do NOT ignore a real Died sound if MVSD creates one.
}

local function track(connection)
    if connection then
        state.Connections[#state.Connections + 1] = connection
    end
    return connection
end

local function disconnect(connection)
    if connection then
        pcall(function()
            connection:Disconnect()
        end)
    end
end

local function safePath(object)
    if not object then return "nil" end

    local parts = {}
    local current = object
    local guard = 0

    while current and current ~= game and guard < 48 do
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

local function getSoundWorldPosition(sound)
    local current = sound.Parent

    while current and current ~= game do
        if current:IsA("BasePart") then
            return current.Position
        elseif current:IsA("Attachment") then
            return current.WorldPosition
        end

        current = current.Parent
    end

    return nil
end

local function isIgnored(sound)
    if not sound then return true end

    local name = tostring(sound.Name or "")
    if IGNORE_NAMES[name] == true then
        return true
    end

    local id = tostring(sound.SoundId or "")
    if id:find("action_footsteps", 1, true)
        or id:find("action_jump", 1, true)
        or id:find("action_falling", 1, true)
        or id:find("action_get_up", 1, true)
        or id:find("action_swim", 1, true)
    then
        return true
    end

    return false
end

local output
local status

local function refreshOutput()
    if not output then return end

    if #state.Logs == 0 then
        output.Text = "Sin candidatos todavía."
    else
        output.Text = table.concat(state.Logs, "\n\n")
    end
end

local function logCandidate(sound, source, eventTime)
    if not state.Armed or not state.DeathAt then return end
    if not sound or not sound.Parent then return end
    if isIgnored(sound) then return end

    local now = eventTime or os.clock()
    if now < (state.WindowStart or math.huge)
        or now > (state.WindowEnd or -math.huge)
    then
        return
    end

    local last = state.LastPlayedAt[sound] or 0
    if now - last < 0.04 then
        return
    end
    state.LastPlayedAt[sound] = now

    local delta = now - state.DeathAt
    local position = getSoundWorldPosition(sound)
    local distanceText = "N/A"

    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if position and hrp then
        distanceText = string.format("%.2f studs", (position - hrp.Position).Magnitude)
    end

    local score = 0
    local lowerName = tostring(sound.Name or ""):lower()
    local lowerPath = safePath(sound):lower()

    -- Score heuristic only to sort candidates; output still includes raw evidence.
    if lowerName:find("death", 1, true) or lowerName:find("died", 1, true) then
        score += 100
    end
    if lowerPath:find("death", 1, true) or lowerPath:find("died", 1, true) then
        score += 80
    end
    if lowerPath:find("killfx", 1, true) then
        score += 20
    end
    if lowerPath:find("roundresult", 1, true) then
        score += 10
    end

    score += math.max(0, 50 - math.floor(math.abs(delta) * 100))

    local block = {
        string.format("[CANDIDATO · SCORE %d]", score),
        string.format("Δ Died: %+0.3f s", delta),
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

    state.Logs[#state.Logs + 1] = {
        Score = score,
        Delta = delta,
        Text = table.concat(block, "\n"),
    }

    table.sort(state.Logs, function(a, b)
        if a.Score == b.Score then
            return math.abs(a.Delta) < math.abs(b.Delta)
        end
        return a.Score > b.Score
    end)

    if #state.Logs > 40 then
        table.remove(state.Logs)
    end

    task.defer(function()
        local flattened = {}
        for i = 1, #state.Logs do
            flattened[i] = state.Logs[i].Text
        end

        if output then
            output.Text = #flattened > 0
                and table.concat(flattened, "\n\n")
                or "Sin candidatos todavía."
        end
    end)
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
        logCandidate(sound, "Sound.Played", os.clock())
    end))

    track(sound:GetPropertyChangedSignal("Playing"):Connect(function()
        if sound.Playing then
            logCandidate(sound, "Playing=true", os.clock())
        end
    end))

    task.defer(function()
        if state.Alive
            and sound.Parent
            and (sound.Playing or sound.IsPlaying)
        then
            logCandidate(sound, "Creado reproduciéndose", os.clock())
        end
    end)
end

local function scanRoot(root)
    if not root then return end

    if root:IsA("Sound") then
        bindSound(root)
    end

    for _, obj in ipairs(root:GetDescendants()) do
        if obj:IsA("Sound") then
            bindSound(obj)
        end
    end

    track(root.DescendantAdded:Connect(function(obj)
        if obj:IsA("Sound") then
            bindSound(obj)
        end
    end))
end

scanRoot(workspace)
scanRoot(SoundService)
scanRoot(playerGui)

local backpack = player:FindFirstChildOfClass("Backpack")
if backpack then
    scanRoot(backpack)
end

local deathConnection = nil

local function bindCharacter(char)
    state.Character = char
    state.Humanoid = nil
    disconnect(deathConnection)
    deathConnection = nil

    if not char then return end

    scanRoot(char)

    local hum = char:FindFirstChildOfClass("Humanoid")
        or char:WaitForChild("Humanoid", 5)

    if not hum then return end
    state.Humanoid = hum

    deathConnection = hum.Died:Connect(function()
        if not state.Armed then return end

        local now = os.clock()
        state.DeathAt = now
        state.WindowStart = now - 0.65
        state.WindowEnd = now + 1.25

        if status then
            status.Text = "MUERTE DETECTADA · capturando ventana de sonidos..."
            status.TextColor3 = Color3.fromRGB(120, 230, 140)
        end

        task.delay(1.35, function()
            if not state.Alive or not state.Armed then return end

            state.Armed = false

            if status then
                status.Text = #state.Logs > 0
                    and ("Listo · " .. tostring(#state.Logs) .. " candidato(s). Pulsa COPIAR.")
                    or "Listo · no apareció ningún sonido claro alrededor de Humanoid.Died."
                status.TextColor3 = Color3.fromRGB(190, 190, 190)
            end
        end)
    end)
end

bindCharacter(player.Character)

track(player.CharacterAdded:Connect(function(char)
    task.defer(function()
        bindCharacter(char)
    end)
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

local oldGui = parent:FindFirstChild("XeroHub_MVSD_DeathLab")
if oldGui then oldGui:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name = "XeroHub_MVSD_DeathLab"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 2147483647
gui.Parent = parent

local frame = Instance.new("Frame")
frame.Size = UDim2.fromOffset(575, 430)
frame.Position = UDim2.new(0.5, -287, 0.5, -215)
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
title.Size = UDim2.new(1, -30, 0, 34)
title.Position = UDim2.fromOffset(15, 8)
title.BackgroundTransparency = 1
title.Text = "XeroHub · MVSD Death Lab"
title.TextColor3 = Color3.fromRGB(245, 245, 245)
title.Font = Enum.Font.GothamBold
title.TextSize = 16
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = frame

status = Instance.new("TextLabel")
status.Size = UDim2.new(1, -30, 0, 46)
status.Position = UDim2.fromOffset(15, 40)
status.BackgroundTransparency = 1
status.Text = "Pulsa ARMAR y deja que te maten una vez."
status.TextColor3 = Color3.fromRGB(165, 165, 165)
status.Font = Enum.Font.Gotham
status.TextSize = 12
status.TextWrapped = true
status.TextXAlignment = Enum.TextXAlignment.Left
status.Parent = frame

output = Instance.new("TextBox")
output.Size = UDim2.new(1, -30, 1, -158)
output.Position = UDim2.fromOffset(15, 87)
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
output.Text = "Sin candidatos todavía."
output.Parent = frame
Instance.new("UICorner", output).CornerRadius = UDim.new(0, 10)

local function makeButton(label, x, width)
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(width, -5, 0, 36)
    button.Position = UDim2.new(x, 15, 1, -48)
    button.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    button.BorderSizePixel = 0
    button.Text = label
    button.TextColor3 = Color3.fromRGB(235, 235, 235)
    button.Font = Enum.Font.GothamMedium
    button.TextSize = 10
    button.Parent = frame
    Instance.new("UICorner", button).CornerRadius = UDim.new(0, 9)
    return button
end

local armBtn = makeButton("ARMAR", 0.00, 0.25)
local clearBtn = makeButton("LIMPIAR", 0.26, 0.24)
local copyBtn = makeButton("COPIAR", 0.51, 0.46)

armBtn.MouseButton1Click:Connect(function()
    state.Logs = {}
    state.DeathAt = nil
    state.WindowStart = nil
    state.WindowEnd = nil
    state.Armed = true

    if output then
        output.Text = "Esperando Humanoid.Died..."
    end

    status.Text = "ARMADO · deja que te maten una vez."
    status.TextColor3 = Color3.fromRGB(120, 230, 140)
end)

clearBtn.MouseButton1Click:Connect(function()
    state.Logs = {}
    state.DeathAt = nil
    state.WindowStart = nil
    state.WindowEnd = nil
    state.Armed = false

    output.Text = "Sin candidatos todavía."
    status.Text = "Limpio. Pulsa ARMAR para otra prueba."
    status.TextColor3 = Color3.fromRGB(165, 165, 165)
end)

copyBtn.MouseButton1Click:Connect(function()
    local result

    if #state.Logs == 0 then
        result = "Sin candidatos capturados."
    else
        local blocks = {}
        for i = 1, #state.Logs do
            blocks[i] = state.Logs[i].Text
        end

        result = table.concat(blocks, "\n\n")
    end

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
local dragInput = nil
local dragStart = nil
local frameStart = nil

track(frame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch
    then
        dragging = true
        dragInput = input
        dragStart = input.Position
        frameStart = frame.Position
    end
end))

track(UserInputService.InputChanged:Connect(function(input)
    if not dragging or not dragInput or not dragStart or not frameStart then
        return
    end

    local sameTouch = dragInput.UserInputType == Enum.UserInputType.Touch
        and input == dragInput

    local sameMouse = dragInput.UserInputType == Enum.UserInputType.MouseButton1
        and input.UserInputType == Enum.UserInputType.MouseMovement

    if not sameTouch and not sameMouse then
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
    if not dragInput then return end

    local sameTouch = dragInput.UserInputType == Enum.UserInputType.Touch
        and input == dragInput

    local sameMouse = dragInput.UserInputType == Enum.UserInputType.MouseButton1
        and input.UserInputType == Enum.UserInputType.MouseButton1

    if sameTouch or sameMouse then
        dragging = false
        dragInput = nil
    end
end))

env.__XERO_MVSD_DEATH_LAB_CLEANUP = function()
    if not state.Alive then return end

    state.Alive = false
    state.Armed = false

    disconnect(deathConnection)
    deathConnection = nil

    for i = #state.Connections, 1, -1 do
        disconnect(state.Connections[i])
        state.Connections[i] = nil
    end

    if gui and gui.Parent then
        gui:Destroy()
    end
end

print("[XeroHub] MVSD Death Lab cargado.")
