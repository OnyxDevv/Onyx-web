-- XeroHub Kill Sound Lab
-- Creator: Kev
-- Standalone diagnostic hub: captures/identifies kill/death sound candidates.
-- It does NOT replace or mute any original sound.

local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then
    repeat task.wait() until Players.LocalPlayer
    LocalPlayer = Players.LocalPlayer
end

local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local env = (getgenv and getgenv()) or _G

if env.__XERO_KILL_SOUND_LAB and env.__XERO_KILL_SOUND_LAB.Cleanup then
    pcall(env.__XERO_KILL_SOUND_LAB.Cleanup)
end

local Lab = {
    Alive = true,
    Detecting = false,
    Session = 0,
    CaptureSeconds = 10,
    Connections = {},
    CaptureConnections = {},
    SoundConnections = {},
    CharacterConnections = {},
    Events = {},
    Deaths = {},
    Ranked = {},
    SelectedIndex = nil,
    LastSoundEvent = setmetatable({}, {__mode = "k"}),
    SeenSounds = setmetatable({}, {__mode = "k"}),
    AutoFinishScheduled = false,
}

env.__XERO_KILL_SOUND_LAB = Lab

local function safeDisconnect(connection)
    if connection then
        pcall(function()
            connection:Disconnect()
        end)
    end
end

local function track(connection, bucket)
    if connection then
        table.insert(bucket or Lab.Connections, connection)
    end
    return connection
end

local function clearConnections(bucket)
    for i = #bucket, 1, -1 do
        safeDisconnect(bucket[i])
        bucket[i] = nil
    end
end

local function lower(value)
    return string.lower(tostring(value or ""))
end

local function trim(value)
    return tostring(value or ""):match("^%s*(.-)%s*$")
end

local function safeFullName(instance)
    local ok, result = pcall(function()
        return instance:GetFullName()
    end)
    return ok and tostring(result) or tostring(instance and instance.Name or "?")
end

local function normalizeSoundId(soundId)
    local text = trim(soundId)
    if text == "" then
        return "(sin SoundId)"
    end

    local digits = text:match("^rbxassetid://(%d+)$")
        or text:match("[?&]id=(%d+)")
        or text:match("^(%d+)$")

    return digits or text
end

local function findSoundPosition(sound)
    if not sound or not sound.Parent then
        return nil
    end

    local parent = sound.Parent
    if parent:IsA("BasePart") then
        return parent.Position
    end

    local part = sound:FindFirstAncestorWhichIsA("BasePart")
    if part then
        return part.Position
    end

    local model = sound:FindFirstAncestorWhichIsA("Model")
    if model then
        local primary = model.PrimaryPart
            or model:FindFirstChild("HumanoidRootPart")
            or model:FindFirstChild("Torso")
            or model:FindFirstChild("UpperTorso")
        if primary and primary:IsA("BasePart") then
            return primary.Position
        end
    end

    return nil
end

local function nearestDeathForEvent(event)
    local nearest = nil
    local bestDelta = math.huge

    for _, death in ipairs(Lab.Deaths) do
        local delta = math.abs(event.Time - death.Time)
        if delta < bestDelta then
            bestDelta = delta
            nearest = death
        end
    end

    return nearest, bestDelta
end

local function scoreEvent(event)
    local score = 0
    local haystack = lower((event.Name or "") .. " " .. (event.Path or ""))

    local weightedWords = {
        {"killsound", 65},
        {"kill_sound", 65},
        {"kill sound", 65},
        {"deathsound", 60},
        {"death_sound", 60},
        {"death sound", 60},
        {"eliminate", 52},
        {"eliminated", 52},
        {"elimination", 52},
        {"death", 48},
        {"killed", 46},
        {"kill", 44},
        {"died", 42},
        {"murder", 38},
        {"fatal", 34},
        {"finish", 26},
        {"hitmarker", 18},
        {"hit", 12},
        {"damage", 8},
    }

    for _, entry in ipairs(weightedWords) do
        if string.find(haystack, entry[1], 1, true) then
            score = score + entry[2]
        end
    end

    if string.find(haystack, "gunshot", 1, true)
        or string.find(haystack, "shoot", 1, true)
        or string.find(haystack, "fire", 1, true) then
        score = score - 18
    end

    if event.New then
        score = score + 8
    end

    if event.SoundId and trim(event.SoundId) ~= "" then
        score = score + 2
    end

    local death, delta = nearestDeathForEvent(event)
    event.NearestDeath = death
    event.DeathDelta = delta

    if death then
        if delta <= 0.08 then
            score = score + 65
        elseif delta <= 0.20 then
            score = score + 56
        elseif delta <= 0.40 then
            score = score + 46
        elseif delta <= 0.75 then
            score = score + 34
        elseif delta <= 1.20 then
            score = score + 22
        elseif delta <= 2.00 then
            score = score + 10
        end

        if event.Time >= death.Time and delta <= 0.55 then
            score = score + 8
        end

        if death.PlayerName and string.find(lower(event.Path), lower(death.PlayerName), 1, true) then
            score = score + 24
        end

        if event.Position and death.Position then
            local distance = (event.Position - death.Position).Magnitude
            event.DeathDistance = distance

            if distance <= 12 then
                score = score + 28
            elseif distance <= 30 then
                score = score + 20
            elseif distance <= 60 then
                score = score + 12
            elseif distance <= 120 then
                score = score + 5
            end
        end
    end

    event.Score = score
    return score
end

local function makeGuiParent()
    local parent = PlayerGui
    pcall(function()
        if gethui then
            parent = gethui()
        else
            parent = game:GetService("CoreGui")
        end
    end)
    return parent
end

local parent = makeGuiParent()
local old = parent and parent:FindFirstChild("XeroHub_KillSoundLab")
if old then
    old:Destroy()
end

local Gui = Instance.new("ScreenGui")
Gui.Name = "XeroHub_KillSoundLab"
Gui.ResetOnSpawn = false
Gui.IgnoreGuiInset = true
Gui.DisplayOrder = 2147483647
Gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
Gui.Parent = parent

Lab.Gui = Gui

local Main = Instance.new("Frame")
Main.Name = "Main"
Main.AnchorPoint = Vector2.new(0.5, 0.5)
Main.Position = UDim2.fromScale(0.5, 0.5)
Main.Size = UDim2.fromOffset(680, 470)
Main.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
Main.BorderSizePixel = 0
Main.ClipsDescendants = true
Main.Parent = Gui

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 18)
mainCorner.Parent = Main

local mainStroke = Instance.new("UIStroke")
mainStroke.Color = Color3.fromRGB(54, 54, 54)
mainStroke.Transparency = 0.12
mainStroke.Thickness = 1
mainStroke.Parent = Main

local Header = Instance.new("Frame")
Header.Name = "Header"
Header.Size = UDim2.new(1, 0, 0, 58)
Header.BackgroundColor3 = Color3.fromRGB(13, 13, 13)
Header.BorderSizePixel = 0
Header.Parent = Main

local Title = Instance.new("TextLabel")
Title.BackgroundTransparency = 1
Title.Position = UDim2.fromOffset(18, 10)
Title.Size = UDim2.new(1, -100, 0, 23)
Title.Text = "XERO | KILL SOUND LAB"
Title.TextColor3 = Color3.fromRGB(245, 245, 245)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 17
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = Header

local Subtitle = Instance.new("TextLabel")
Subtitle.BackgroundTransparency = 1
Subtitle.Position = UDim2.fromOffset(18, 32)
Subtitle.Size = UDim2.new(1, -100, 0, 16)
Subtitle.Text = "Detector de sonido de muerte · by Kev"
Subtitle.TextColor3 = Color3.fromRGB(132, 132, 132)
Subtitle.Font = Enum.Font.Gotham
Subtitle.TextSize = 11
Subtitle.TextXAlignment = Enum.TextXAlignment.Left
Subtitle.Parent = Header

local Close = Instance.new("TextButton")
Close.AnchorPoint = Vector2.new(1, 0.5)
Close.Position = UDim2.new(1, -14, 0.5, 0)
Close.Size = UDim2.fromOffset(34, 34)
Close.BackgroundColor3 = Color3.fromRGB(24, 24, 24)
Close.BorderSizePixel = 0
Close.Text = "×"
Close.TextColor3 = Color3.fromRGB(210, 210, 210)
Close.Font = Enum.Font.GothamMedium
Close.TextSize = 22
Close.AutoButtonColor = false
Close.Parent = Header

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 10)
closeCorner.Parent = Close

local function addHover(button, normal, hover)
    track(button.MouseEnter:Connect(function()
        if not Lab.Alive then return end
        TweenService:Create(button, TweenInfo.new(0.12), {BackgroundColor3 = hover}):Play()
    end))
    track(button.MouseLeave:Connect(function()
        if not Lab.Alive then return end
        TweenService:Create(button, TweenInfo.new(0.12), {BackgroundColor3 = normal}):Play()
    end))
end

addHover(Close, Color3.fromRGB(24, 24, 24), Color3.fromRGB(40, 40, 40))

local dragging = false
local dragStart
local startPosition
local dragInput

track(Header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPosition = Main.Position
        dragInput = input
    end
end))

track(Header.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end))

track(UserInputService.InputChanged:Connect(function(input)
    if dragging and input == dragInput and dragStart and startPosition then
        local delta = input.Position - dragStart
        Main.Position = UDim2.new(
            startPosition.X.Scale,
            startPosition.X.Offset + delta.X,
            startPosition.Y.Scale,
            startPosition.Y.Offset + delta.Y
        )
    end
end))

track(UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
        dragInput = nil
    end
end))

local Body = Instance.new("Frame")
Body.Position = UDim2.fromOffset(0, 58)
Body.Size = UDim2.new(1, 0, 1, -58)
Body.BackgroundTransparency = 1
Body.Parent = Main

local StatusCard = Instance.new("Frame")
StatusCard.Position = UDim2.fromOffset(14, 14)
StatusCard.Size = UDim2.new(1, -28, 0, 72)
StatusCard.BackgroundColor3 = Color3.fromRGB(16, 16, 16)
StatusCard.BorderSizePixel = 0
StatusCard.Parent = Body

local statusCorner = Instance.new("UICorner")
statusCorner.CornerRadius = UDim.new(0, 13)
statusCorner.Parent = StatusCard

local statusStroke = Instance.new("UIStroke")
statusStroke.Color = Color3.fromRGB(45, 45, 45)
statusStroke.Transparency = 0.25
statusStroke.Thickness = 1
statusStroke.Parent = StatusCard

local StatusDot = Instance.new("Frame")
StatusDot.Position = UDim2.fromOffset(16, 20)
StatusDot.Size = UDim2.fromOffset(8, 8)
StatusDot.BackgroundColor3 = Color3.fromRGB(120, 120, 120)
StatusDot.BorderSizePixel = 0
StatusDot.Parent = StatusCard
Instance.new("UICorner", StatusDot).CornerRadius = UDim.new(1, 0)

local StatusTitle = Instance.new("TextLabel")
StatusTitle.BackgroundTransparency = 1
StatusTitle.Position = UDim2.fromOffset(34, 12)
StatusTitle.Size = UDim2.new(1, -50, 0, 22)
StatusTitle.Text = "Listo para detectar"
StatusTitle.TextColor3 = Color3.fromRGB(238, 238, 238)
StatusTitle.Font = Enum.Font.GothamMedium
StatusTitle.TextSize = 13
StatusTitle.TextXAlignment = Enum.TextXAlignment.Left
StatusTitle.Parent = StatusCard

local StatusDesc = Instance.new("TextLabel")
StatusDesc.BackgroundTransparency = 1
StatusDesc.Position = UDim2.fromOffset(16, 38)
StatusDesc.Size = UDim2.new(1, -32, 0, 22)
StatusDesc.Text = "Pulsa Iniciar detección y mata a un jugador una sola vez."
StatusDesc.TextColor3 = Color3.fromRGB(132, 132, 132)
StatusDesc.Font = Enum.Font.Gotham
StatusDesc.TextSize = 11
StatusDesc.TextXAlignment = Enum.TextXAlignment.Left
StatusDesc.TextTruncate = Enum.TextTruncate.AtEnd
StatusDesc.Parent = StatusCard

local Controls = Instance.new("Frame")
Controls.Position = UDim2.fromOffset(14, 96)
Controls.Size = UDim2.new(1, -28, 0, 42)
Controls.BackgroundTransparency = 1
Controls.Parent = Body

local controlLayout = Instance.new("UIListLayout")
controlLayout.FillDirection = Enum.FillDirection.Horizontal
controlLayout.Padding = UDim.new(0, 8)
controlLayout.SortOrder = Enum.SortOrder.LayoutOrder
controlLayout.Parent = Controls

local function createButton(text, width)
    local button = Instance.new("TextButton")
    button.Size = UDim2.fromOffset(width, 42)
    button.BackgroundColor3 = Color3.fromRGB(23, 23, 23)
    button.BorderSizePixel = 0
    button.Text = text
    button.TextColor3 = Color3.fromRGB(225, 225, 225)
    button.Font = Enum.Font.GothamMedium
    button.TextSize = 11
    button.AutoButtonColor = false
    button.Parent = Controls
    Instance.new("UICorner", button).CornerRadius = UDim.new(0, 11)

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(52, 52, 52)
    stroke.Transparency = 0.25
    stroke.Thickness = 1
    stroke.Parent = button

    addHover(button, Color3.fromRGB(23, 23, 23), Color3.fromRGB(34, 34, 34))
    return button
end

local DetectButton = createButton("Iniciar detección", 150)
local ClearButton = createButton("Limpiar", 92)
local PreviewButton = createButton("Probar seleccionado", 146)
local CopyButton = createButton("Copiar info", 112)

local Left = Instance.new("Frame")
Left.Position = UDim2.fromOffset(14, 150)
Left.Size = UDim2.new(0.54, -20, 1, -164)
Left.BackgroundColor3 = Color3.fromRGB(14, 14, 14)
Left.BorderSizePixel = 0
Left.Parent = Body
Instance.new("UICorner", Left).CornerRadius = UDim.new(0, 13)

local leftStroke = Instance.new("UIStroke")
leftStroke.Color = Color3.fromRGB(45, 45, 45)
leftStroke.Transparency = 0.25
leftStroke.Thickness = 1
leftStroke.Parent = Left

local ListTitle = Instance.new("TextLabel")
ListTitle.BackgroundTransparency = 1
ListTitle.Position = UDim2.fromOffset(12, 8)
ListTitle.Size = UDim2.new(1, -24, 0, 24)
ListTitle.Text = "CANDIDATOS"
ListTitle.TextColor3 = Color3.fromRGB(170, 170, 170)
ListTitle.Font = Enum.Font.GothamMedium
ListTitle.TextSize = 10
ListTitle.TextXAlignment = Enum.TextXAlignment.Left
ListTitle.Parent = Left

local CandidateList = Instance.new("ScrollingFrame")
CandidateList.Position = UDim2.fromOffset(8, 34)
CandidateList.Size = UDim2.new(1, -16, 1, -42)
CandidateList.BackgroundTransparency = 1
CandidateList.BorderSizePixel = 0
CandidateList.ScrollBarThickness = 3
CandidateList.ScrollBarImageColor3 = Color3.fromRGB(90, 90, 90)
CandidateList.CanvasSize = UDim2.fromOffset(0, 0)
CandidateList.AutomaticCanvasSize = Enum.AutomaticSize.Y
CandidateList.Parent = Left

local candidateLayout = Instance.new("UIListLayout")
candidateLayout.Padding = UDim.new(0, 6)
candidateLayout.SortOrder = Enum.SortOrder.LayoutOrder
candidateLayout.Parent = CandidateList

local Right = Instance.new("Frame")
Right.AnchorPoint = Vector2.new(1, 0)
Right.Position = UDim2.new(1, -14, 0, 150)
Right.Size = UDim2.new(0.46, -8, 1, -164)
Right.BackgroundColor3 = Color3.fromRGB(14, 14, 14)
Right.BorderSizePixel = 0
Right.Parent = Body
Instance.new("UICorner", Right).CornerRadius = UDim.new(0, 13)

local rightStroke = Instance.new("UIStroke")
rightStroke.Color = Color3.fromRGB(45, 45, 45)
rightStroke.Transparency = 0.25
rightStroke.Thickness = 1
rightStroke.Parent = Right

local DetailTitle = Instance.new("TextLabel")
DetailTitle.BackgroundTransparency = 1
DetailTitle.Position = UDim2.fromOffset(12, 8)
DetailTitle.Size = UDim2.new(1, -24, 0, 24)
DetailTitle.Text = "DETALLES"
DetailTitle.TextColor3 = Color3.fromRGB(170, 170, 170)
DetailTitle.Font = Enum.Font.GothamMedium
DetailTitle.TextSize = 10
DetailTitle.TextXAlignment = Enum.TextXAlignment.Left
DetailTitle.Parent = Right

local Detail = Instance.new("TextLabel")
Detail.BackgroundTransparency = 1
Detail.Position = UDim2.fromOffset(12, 36)
Detail.Size = UDim2.new(1, -24, 1, -48)
Detail.Text = "Aún no hay resultados."
Detail.TextColor3 = Color3.fromRGB(195, 195, 195)
Detail.Font = Enum.Font.Code
Detail.TextSize = 11
Detail.TextWrapped = true
Detail.TextXAlignment = Enum.TextXAlignment.Left
Detail.TextYAlignment = Enum.TextYAlignment.Top
Detail.Parent = Right

local function setStatus(titleText, descText, active)
    StatusTitle.Text = titleText or ""
    StatusDesc.Text = descText or ""
    StatusDot.BackgroundColor3 = active and Color3.fromRGB(235, 235, 235)
        or Color3.fromRGB(120, 120, 120)
end

local function formatDelta(value)
    if not value or value == math.huge then
        return "sin muerte detectada"
    end
    return string.format("%.3f s", value)
end

local function formatDistance(value)
    if not value then
        return "n/a"
    end
    return string.format("%.1f studs", value)
end

local function selectedEvent()
    if not Lab.SelectedIndex then
        return nil
    end
    return Lab.Ranked[Lab.SelectedIndex]
end

local function updateDetail()
    local event = selectedEvent()
    if not event then
        Detail.Text = "Aún no hay un candidato seleccionado."
        return
    end

    local deathName = event.NearestDeath and event.NearestDeath.PlayerName or "n/a"
    Detail.Text = table.concat({
        "Nombre: " .. tostring(event.Name),
        "SoundId: " .. normalizeSoundId(event.SoundId),
        "Score: " .. tostring(event.Score or 0),
        "Ruta: " .. tostring(event.Path),
        "",
        "Evento: " .. tostring(event.Reason),
        "Nuevo: " .. (event.New and "sí" or "no"),
        "Muerte cercana: " .. tostring(deathName),
        "Δ muerte: " .. formatDelta(event.DeathDelta),
        "Distancia: " .. formatDistance(event.DeathDistance),
    }, "\n")
end

local function clearCandidateRows()
    for _, child in ipairs(CandidateList:GetChildren()) do
        if child:IsA("GuiButton") then
            child:Destroy()
        end
    end
end

local function renderCandidates()
    clearCandidateRows()

    if #Lab.Ranked == 0 then
        Lab.SelectedIndex = nil
        updateDetail()
        return
    end

    if not Lab.SelectedIndex or not Lab.Ranked[Lab.SelectedIndex] then
        Lab.SelectedIndex = 1
    end

    for index, event in ipairs(Lab.Ranked) do
        if index > 30 then
            break
        end

        local row = Instance.new("TextButton")
        row.Name = "Candidate_" .. tostring(index)
        row.Size = UDim2.new(1, -2, 0, 52)
        row.BackgroundColor3 = index == Lab.SelectedIndex
            and Color3.fromRGB(34, 34, 34)
            or Color3.fromRGB(20, 20, 20)
        row.BorderSizePixel = 0
        row.Text = ""
        row.AutoButtonColor = false
        row.LayoutOrder = index
        row.Parent = CandidateList
        Instance.new("UICorner", row).CornerRadius = UDim.new(0, 10)

        local name = Instance.new("TextLabel")
        name.BackgroundTransparency = 1
        name.Position = UDim2.fromOffset(10, 7)
        name.Size = UDim2.new(1, -20, 0, 18)
        name.Text = string.format("#%d  %s", index, tostring(event.Name))
        name.TextColor3 = Color3.fromRGB(232, 232, 232)
        name.Font = Enum.Font.GothamMedium
        name.TextSize = 11
        name.TextXAlignment = Enum.TextXAlignment.Left
        name.TextTruncate = Enum.TextTruncate.AtEnd
        name.Parent = row

        local meta = Instance.new("TextLabel")
        meta.BackgroundTransparency = 1
        meta.Position = UDim2.fromOffset(10, 27)
        meta.Size = UDim2.new(1, -20, 0, 17)
        meta.Text = string.format(
            "score %d  ·  Δ %s  ·  %s",
            event.Score or 0,
            event.DeathDelta and string.format("%.2fs", event.DeathDelta) or "n/a",
            normalizeSoundId(event.SoundId)
        )
        meta.TextColor3 = Color3.fromRGB(125, 125, 125)
        meta.Font = Enum.Font.Gotham
        meta.TextSize = 9
        meta.TextXAlignment = Enum.TextXAlignment.Left
        meta.TextTruncate = Enum.TextTruncate.AtEnd
        meta.Parent = row

        track(row.MouseButton1Click:Connect(function()
            Lab.SelectedIndex = index
            renderCandidates()
            updateDetail()
        end))
    end

    updateDetail()
end

local function addSoundEvent(sound, reason, isNew)
    if not Lab.Detecting or not sound or not sound:IsA("Sound") then
        return
    end

    local now = os.clock()
    local last = Lab.LastSoundEvent[sound] or 0
    if now - last < 0.07 then
        return
    end
    Lab.LastSoundEvent[sound] = now

    local event = {
        Sound = sound,
        Name = tostring(sound.Name or "Sound"),
        SoundId = tostring(sound.SoundId or ""),
        Path = safeFullName(sound),
        Time = now,
        New = isNew == true,
        Reason = tostring(reason or "Played"),
        Position = findSoundPosition(sound),
        Volume = tonumber(sound.Volume) or 1,
        PlaybackSpeed = tonumber(sound.PlaybackSpeed) or 1,
    }

    table.insert(Lab.Events, event)

    if #Lab.Events > 240 then
        table.remove(Lab.Events, 1)
    end

    StatusDesc.Text = string.format(
        "Escuchando… %d sonido(s) capturado(s), %d muerte(s).",
        #Lab.Events,
        #Lab.Deaths
    )
end

local function bindSound(sound, isNew)
    if not Lab.Detecting or not sound or not sound:IsA("Sound") or Lab.SeenSounds[sound] then
        return
    end
    Lab.SeenSounds[sound] = true

    local perSound = {}

    table.insert(perSound, sound.Played:Connect(function()
        addSoundEvent(sound, "Played", isNew)
    end))

    table.insert(perSound, sound:GetPropertyChangedSignal("Playing"):Connect(function()
        if sound.Playing then
            addSoundEvent(sound, "Playing=true", isNew)
        end
    end))

    table.insert(perSound, sound.AncestryChanged:Connect(function(_, newParent)
        if not newParent then
            for _, connection in ipairs(perSound) do
                safeDisconnect(connection)
            end
            Lab.SoundConnections[sound] = nil
            Lab.SeenSounds[sound] = nil
        end
    end))

    Lab.SoundConnections[sound] = perSound

    if sound.IsPlaying or sound.Playing then
        addSoundEvent(sound, "Ya estaba reproduciéndose", isNew)
    end
end

local function bindSoundRoot(root)
    if not root then
        return
    end

    if root:IsA("Sound") then
        bindSound(root, false)
    end

    for _, descendant in ipairs(root:GetDescendants()) do
        if descendant:IsA("Sound") then
            bindSound(descendant, false)
        end
    end

    track(root.DescendantAdded:Connect(function(descendant)
        if Lab.Detecting and descendant:IsA("Sound") then
            bindSound(descendant, true)
        end
    end), Lab.CaptureConnections)
end

local finishDetection

local function recordDeath(player, character)
    if not Lab.Detecting then
        return
    end

    local root = character and (
        character:FindFirstChild("HumanoidRootPart")
        or character:FindFirstChild("Torso")
        or character:FindFirstChild("UpperTorso")
    )

    local death = {
        Player = player,
        PlayerName = player and player.Name or "Jugador",
        Character = character,
        Time = os.clock(),
        Position = root and root:IsA("BasePart") and root.Position or nil,
    }

    table.insert(Lab.Deaths, death)

    setStatus(
        "Muerte detectada: " .. tostring(death.PlayerName),
        "Capturando ~2.3 s extra para incluir el sonido posterior a la muerte.",
        true
    )

    if not Lab.AutoFinishScheduled then
        Lab.AutoFinishScheduled = true
        local session = Lab.Session
        task.delay(2.3, function()
            if Lab.Alive and Lab.Detecting and Lab.Session == session then
                finishDetection("auto")
            end
        end)
    end
end

local function bindCharacter(player, character)
    if not Lab.Detecting or not player or player == LocalPlayer or not character then
        return
    end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
        or character:WaitForChild("Humanoid", 2)

    if not humanoid then
        return
    end

    local connection
    connection = humanoid.Died:Connect(function()
        recordDeath(player, character)
        safeDisconnect(connection)
    end)

    table.insert(Lab.CharacterConnections, connection)
end

local function bindPlayersForDeaths()
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            if player.Character then
                bindCharacter(player, player.Character)
            end

            track(player.CharacterAdded:Connect(function(character)
                if Lab.Detecting then
                    bindCharacter(player, character)
                end
            end), Lab.CaptureConnections)
        end
    end

    track(Players.PlayerAdded:Connect(function(player)
        if player == LocalPlayer then
            return
        end

        track(player.CharacterAdded:Connect(function(character)
            if Lab.Detecting then
                bindCharacter(player, character)
            end
        end), Lab.CaptureConnections)
    end), Lab.CaptureConnections)
end

local function disconnectCapture()
    clearConnections(Lab.CaptureConnections)
    clearConnections(Lab.CharacterConnections)

    for sound, connections in pairs(Lab.SoundConnections) do
        for _, connection in ipairs(connections) do
            safeDisconnect(connection)
        end
        Lab.SoundConnections[sound] = nil
    end

    Lab.SeenSounds = setmetatable({}, {__mode = "k"})
    Lab.LastSoundEvent = setmetatable({}, {__mode = "k"})
end

local function rankEvents()
    local ranked = {}
    local bestByKey = {}

    for _, event in ipairs(Lab.Events) do
        scoreEvent(event)

        local key = tostring(event.Path) .. "|" .. tostring(event.SoundId)
        local previous = bestByKey[key]
        if not previous or (event.Score or 0) > (previous.Score or 0) then
            bestByKey[key] = event
        elseif previous and (event.Score or 0) == (previous.Score or 0)
            and event.DeathDelta and previous.DeathDelta
            and event.DeathDelta < previous.DeathDelta then
            bestByKey[key] = event
        end
    end

    for _, event in pairs(bestByKey) do
        table.insert(ranked, event)
    end

    table.sort(ranked, function(a, b)
        if (a.Score or 0) == (b.Score or 0) then
            local da = a.DeathDelta or math.huge
            local db = b.DeathDelta or math.huge
            if da == db then
                return tostring(a.Name) < tostring(b.Name)
            end
            return da < db
        end
        return (a.Score or 0) > (b.Score or 0)
    end)

    Lab.Ranked = ranked
end

finishDetection = function(reason)
    if not Lab.Detecting then
        return
    end

    Lab.Detecting = false
    Lab.Session = Lab.Session + 1
    DetectButton.Text = "Iniciar detección"
    disconnectCapture()
    rankEvents()
    Lab.SelectedIndex = #Lab.Ranked > 0 and 1 or nil
    renderCandidates()

    if #Lab.Ranked == 0 then
        setStatus(
            "No se capturaron sonidos",
            "Prueba otra vez y realiza una sola kill mientras la detección esté activa.",
            false
        )
    elseif #Lab.Deaths == 0 then
        setStatus(
            "Captura terminada · sin muerte detectada",
            string.format("%d candidato(s). Puedes probarlos, pero la puntuación es menos confiable.", #Lab.Ranked),
            false
        )
    else
        setStatus(
            "Captura terminada",
            string.format(
                "%d candidato(s) ordenados. El #1 es el más probable según muerte, nombre y cercanía.",
                #Lab.Ranked
            ),
            false
        )
    end
end

local function startDetection()
    if Lab.Detecting then
        finishDetection("manual")
        return
    end

    disconnectCapture()
    Lab.Events = {}
    Lab.Deaths = {}
    Lab.Ranked = {}
    Lab.SelectedIndex = nil
    Lab.AutoFinishScheduled = false
    Lab.Detecting = true
    Lab.Session = Lab.Session + 1
    local session = Lab.Session

    clearCandidateRows()
    updateDetail()

    DetectButton.Text = "Detener detección"
    setStatus(
        "Detectando…",
        "Mata a un jugador una sola vez. Se cerrará sola poco después de detectar la muerte.",
        true
    )

    bindPlayersForDeaths()

    local roots = {
        workspace,
        SoundService,
        PlayerGui,
        LocalPlayer.Character,
        LocalPlayer:FindFirstChildOfClass("Backpack"),
        ReplicatedStorage,
        workspace.CurrentCamera,
    }

    local seenRoot = {}
    for _, root in ipairs(roots) do
        if root and not seenRoot[root] then
            seenRoot[root] = true
            bindSoundRoot(root)
        end
    end

    track(LocalPlayer.CharacterAdded:Connect(function(character)
        if Lab.Detecting then
            bindSoundRoot(character)
        end
    end), Lab.CaptureConnections)

    task.spawn(function()
        local started = os.clock()
        while Lab.Alive and Lab.Detecting and Lab.Session == session do
            local elapsed = os.clock() - started
            local remaining = math.max(0, Lab.CaptureSeconds - elapsed)

            if #Lab.Deaths == 0 then
                StatusDesc.Text = string.format(
                    "Mata a un jugador ahora · %.1fs restantes · %d sonido(s) capturado(s).",
                    remaining,
                    #Lab.Events
                )
            end

            if remaining <= 0 then
                finishDetection("timeout")
                break
            end

            task.wait(0.12)
        end
    end)
end

local function clearResults()
    if Lab.Detecting then
        finishDetection("clear")
    end

    Lab.Events = {}
    Lab.Deaths = {}
    Lab.Ranked = {}
    Lab.SelectedIndex = nil
    Lab.AutoFinishScheduled = false
    clearCandidateRows()
    updateDetail()
    setStatus(
        "Listo para detectar",
        "Pulsa Iniciar detección y mata a un jugador una sola vez.",
        false
    )
end

local function previewSelected()
    local event = selectedEvent()
    if not event then
        setStatus("Sin candidato", "Selecciona un resultado para reproducirlo.", false)
        return
    end

    local sound
    if event.Sound and event.Sound.Parent then
        local ok, clone = pcall(function()
            return event.Sound:Clone()
        end)
        if ok then
            sound = clone
        end
    end

    if not sound then
        if not event.SoundId or trim(event.SoundId) == "" then
            setStatus("No se puede reproducir", "Este candidato no tiene un SoundId utilizable.", false)
            return
        end

        sound = Instance.new("Sound")
        sound.SoundId = event.SoundId
        sound.Volume = event.Volume or 1
        sound.PlaybackSpeed = event.PlaybackSpeed or 1
    end

    sound.Name = "XeroHub_KillSoundPreview"
    sound.Looped = false
    sound.PlayOnRemove = false
    sound.Volume = math.clamp(tonumber(sound.Volume) or 1, 0.05, 4)
    sound.Parent = SoundService

    pcall(function()
        sound:Stop()
        sound.TimePosition = 0
        sound:Play()
    end)

    setStatus(
        "Reproduciendo candidato #" .. tostring(Lab.SelectedIndex),
        tostring(event.Name) .. " · " .. normalizeSoundId(event.SoundId),
        false
    )

    task.delay(8, function()
        if sound and sound.Parent then
            pcall(function()
                sound:Destroy()
            end)
        end
    end)
end

local function copySelected()
    local event = selectedEvent()
    if not event then
        setStatus("Sin candidato", "Selecciona un resultado para copiar su información.", false)
        return
    end

    local text = table.concat({
        "XeroHub Kill Sound Lab",
        "Nombre: " .. tostring(event.Name),
        "SoundId: " .. tostring(event.SoundId),
        "SoundId normalizado: " .. normalizeSoundId(event.SoundId),
        "Ruta: " .. tostring(event.Path),
        "Score: " .. tostring(event.Score or 0),
        "Delta muerte: " .. formatDelta(event.DeathDelta),
        "Distancia muerte: " .. formatDistance(event.DeathDistance),
    }, "\n")

    local clipboard = setclipboard or toclipboard
    if clipboard then
        local ok = pcall(clipboard, text)
        if ok then
            setStatus("Información copiada", "Ya puedes pegarme el candidato para integrarlo al hub principal.", false)
            return
        end
    end

    Detail.Text = text .. "\n\nTu ejecutor no expone setclipboard/toclipboard."
    setStatus("Clipboard no disponible", "Dejé toda la información visible en el panel de detalles.", false)
end

function Lab.Cleanup()
    if not Lab.Alive then
        return
    end

    Lab.Alive = false
    Lab.Detecting = false
    Lab.Session = Lab.Session + 1

    disconnectCapture()
    clearConnections(Lab.Connections)

    if Lab.Gui and Lab.Gui.Parent then
        pcall(function()
            Lab.Gui:Destroy()
        end)
    end

    if env.__XERO_KILL_SOUND_LAB == Lab then
        env.__XERO_KILL_SOUND_LAB = nil
    end
end

track(DetectButton.MouseButton1Click:Connect(startDetection))
track(ClearButton.MouseButton1Click:Connect(clearResults))
track(PreviewButton.MouseButton1Click:Connect(previewSelected))
track(CopyButton.MouseButton1Click:Connect(copySelected))
track(Close.MouseButton1Click:Connect(Lab.Cleanup))

setStatus(
    "Listo para detectar",
    "Pulsa Iniciar detección y mata a un jugador una sola vez.",
    false
)

print("[XeroHub Kill Sound Lab] Cargado. by Kev")
