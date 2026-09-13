-- XeroHub | Sound Lab
-- Creador: Kev
-- Laboratorio local para identificar y sustituir el sonido de disparo.

local Core = {}

local function trim(value)
    return tostring(value or ""):match("^%s*(.-)%s*$")
end

function Core.normalizeAssetId(value)
    local text = trim(value)
    local digits = text:match("^(%d+)$")
        or text:match("^rbxassetid://(%d+)$")
        or text:match("[?&]id=(%d+)")

    if not digits or tonumber(digits) == nil or tonumber(digits) <= 0 then
        return nil
    end

    return "rbxassetid://" .. digits
end

function Core.waitForCondition(predicate, timeout, clock, waitStep)
    local readClock = clock or os.clock
    local pause = waitStep or function(seconds)
        task.wait(seconds)
    end
    local deadline = readClock() + math.max(0, tonumber(timeout) or 0)

    while readClock() < deadline do
        if predicate() then
            return true
        end
        pause(0.05)
    end

    return predicate() == true
end

function Core.toCanonicalRawUrl(value)
    local url = trim(value)
    local owner, repository, branch, path = url:match(
        "^https://github%.com/([^/]+)/([^/]+)/raw/refs/heads/([^/]+)/(.+)$"
    )
    if owner then
        return string.format(
            "https://raw.githubusercontent.com/%s/%s/refs/heads/%s/%s",
            owner,
            repository,
            branch,
            path
        )
    end
    return url
end

function Core.isAudioPayload(statusCode, body)
    local status = tonumber(statusCode)
    if not status or status < 200 or status >= 300 or type(body) ~= "string" or #body < 64 then
        return false
    end
    if string.sub(body, 1, 3) == "ID3" then
        return true
    end
    local first, second = string.byte(body, 1, 2)
    return first == 0xFF and second ~= nil and second >= 0xE0
end

function Core.resolveLocalAssetLoader(environmentTable)
    environmentTable = environmentTable or {}
    if type(environmentTable.getcustomasset) == "function" then
        return environmentTable.getcustomasset, "getcustomasset"
    end
    if type(environmentTable.getsynasset) == "function" then
        return environmentTable.getsynasset, "getsynasset"
    end
    return nil, nil
end


local POSITIVE_NAME_HINTS = {
    gun = 28,
    shot = 42,
    shoot = 42,
    fire = 28,
    bang = 36,
    blast = 32,
    pistol = 28,
    revolver = 28,
    rifle = 28,
    laser = 20,
    weapon = 14,
}

local NEGATIVE_NAME_HINTS = {
    reload = 54,
    equip = 42,
    hit = 28,
    impact = 34,
    kill = 28,
    empty = 30,
    music = 70,
    foot = 60,
    step = 60,
    ui = 24,
}

local SCOPE_SCORES = {
    tool = 145,
    character = 88,
    camera = 62,
    workspace = 30,
    soundservice = 18,
    interface = 5,
    unknown = 0,
}

function Core.scoreCandidate(candidate)
    candidate = candidate or {}
    local score = SCOPE_SCORES[candidate.scope] or 0
    local loweredName = string.lower(tostring(candidate.name or ""))

    for hint, value in pairs(POSITIVE_NAME_HINTS) do
        if string.find(loweredName, hint, 1, true) then
            score = score + value
        end
    end

    for hint, value in pairs(NEGATIVE_NAME_HINTS) do
        if string.find(loweredName, hint, 1, true) then
            score = score - value
        end
    end

    if Core.normalizeAssetId(candidate.soundId) then
        score = score + 14
    end

    local distance = tonumber(candidate.distance)
    if distance then
        if distance <= 10 then
            score = score + 28
        elseif distance <= 30 then
            score = score + 14
        elseif distance > 120 then
            score = score - 12
        end
    end

    if candidate.newlyCreated then
        score = score + 16
    end
    if candidate.wasPlaying then
        score = score + 12
    end

    return score
end

function Core.chooseBestCandidate(candidates)
    local best = nil
    local bestScore = -math.huge

    for _, candidate in ipairs(candidates or {}) do
        local score = Core.scoreCandidate(candidate)
        local newer = best and (tonumber(candidate.observedAt) or 0) > (tonumber(best.observedAt) or 0)
        if not best or score > bestScore or (score == bestScore and newer) then
            best = candidate
            bestScore = score
        end
    end

    return best, bestScore
end

function Core.matchesTarget(candidate, target)
    if type(candidate) ~= "table" or type(target) ~= "table" then
        return false
    end

    local candidateId = Core.normalizeAssetId(candidate.soundId)
    local originalId = Core.normalizeAssetId(target.originalId)
    if candidateId and originalId and candidateId == originalId then
        return true
    end

    local candidateName = string.lower(trim(candidate.name))
    local targetName = string.lower(trim(target.name))
    local candidateScoped = candidate.scope == "tool" or candidate.scope == "character"
    local targetScoped = target.scope == "tool" or target.scope == "character"

    return candidateId == nil
        and candidateName ~= ""
        and candidateName == targetName
        and candidateScoped
        and targetScoped
end

-- El intérprete de pruebas no tiene el objeto `game`; Roblox continúa debajo.
if game == nil then
    return Core
end


local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
while not player do
    task.wait()
    player = Players.LocalPlayer
end

local playerGui = player:WaitForChild("PlayerGui")
local environment = (getgenv and getgenv()) or _G
local CUSTOM_SOUND_URL = Core.toCanonicalRawUrl(
    "https://github.com/OnyxDevv/Onyx-web/raw/refs/heads/main/sounds/anime-magic-sound-effect%20(1).mp3"
)
local LOCAL_AUDIO_FOLDER = "XeroHub/Sounds"
local LOCAL_AUDIO_PATH = LOCAL_AUDIO_FOLDER .. "/anime_magic_057d16da.mp3"
local localAssetLoader, localAssetLoaderName = Core.resolveLocalAssetLoader({
    getcustomasset = getcustomasset,
    getsynasset = getsynasset or (syn and syn.getcustomasset),
})
local httpRequest = (syn and syn.request)
    or (http and http.request)
    or http_request
    or request
local previousRuntime = environment.__ILUNX_SOUNDLAB_RUNTIME
if previousRuntime and previousRuntime.cleanup then
    pcall(previousRuntime.cleanup)
end

local runtime = {
    alive = true,
    connections = {},
    captureConnections = {},
    liveConnections = {},
    soundWatchers = setmetatable({}, { __mode = "k" }),
    originals = setmetatable({}, { __mode = "k" }),
    applying = setmetatable({}, { __mode = "k" }),
    candidates = {},
    candidateBySound = setmetatable({}, { __mode = "k" }),
    selectedIndex = 0,
    captureToken = 0,
    target = nil,
    localAssetId = nil,
    localAssetUrl = nil,
    liveEnabled = false,
}

local function disconnectList(list)
    for index = #list, 1, -1 do
        local connection = list[index]
        pcall(function()
            connection:Disconnect()
        end)
        list[index] = nil
    end
end

local function track(connection, list)
    if connection then
        table.insert(list or runtime.connections, connection)
    end
    return connection
end

local gui
local previewSound
local customShotSound

local function restoreOriginals()
    runtime.liveEnabled = false
    disconnectList(runtime.liveConnections)

    for sound, originalState in pairs(runtime.originals) do
        if sound and sound.Parent then
            runtime.applying[sound] = true
            pcall(function()
                sound.Volume = originalState.volume
            end)
            runtime.applying[sound] = nil
        end
        runtime.originals[sound] = nil
    end

    for sound, bundle in pairs(runtime.soundWatchers) do
        for _, connection in pairs(bundle) do
            pcall(function()
                connection:Disconnect()
            end)
        end
        runtime.soundWatchers[sound] = nil
    end

    if customShotSound then
        pcall(function()
            customShotSound:Destroy()
        end)
        customShotSound = nil
    end
end

function runtime.cleanup()
    if not runtime.alive then
        return
    end

    runtime.alive = false
    runtime.captureToken = runtime.captureToken + 1
    runtime.loadToken = (runtime.loadToken or 0) + 1
    disconnectList(runtime.captureConnections)
    restoreOriginals()
    disconnectList(runtime.connections)

    if previewSound then
        pcall(function()
            previewSound:Destroy()
        end)
        previewSound = nil
    end

    if gui then
        pcall(function()
            gui:Destroy()
        end)
        gui = nil
    end

    if environment.__ILUNX_SOUNDLAB_RUNTIME == runtime then
        environment.__ILUNX_SOUNDLAB_RUNTIME = nil
    end
end

environment.__ILUNX_SOUNDLAB_RUNTIME = runtime


local COLORS = {
    background = Color3.fromRGB(8, 8, 9),
    panel = Color3.fromRGB(14, 14, 16),
    card = Color3.fromRGB(20, 20, 23),
    cardHover = Color3.fromRGB(27, 27, 30),
    border = Color3.fromRGB(48, 48, 54),
    text = Color3.fromRGB(244, 244, 246),
    secondary = Color3.fromRGB(158, 158, 168),
    muted = Color3.fromRGB(104, 104, 114),
    accent = Color3.fromRGB(235, 235, 238),
    darkText = Color3.fromRGB(18, 18, 20),
    success = Color3.fromRGB(141, 219, 157),
    warning = Color3.fromRGB(235, 199, 118),
    error = Color3.fromRGB(235, 126, 126),
}

local function addCorner(object, radius)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, radius or 12)
    corner.Parent = object
    return corner
end

local function addStroke(object, color, transparency)
    local stroke = Instance.new("UIStroke")
    stroke.Color = color or COLORS.border
    stroke.Transparency = transparency or 0
    stroke.Thickness = 1
    stroke.Parent = object
    return stroke
end

local function makeLabel(parent, text, size, color, font)
    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Text = text or ""
    label.TextColor3 = color or COLORS.text
    label.TextSize = size or 13
    label.Font = font or Enum.Font.Gotham
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextYAlignment = Enum.TextYAlignment.Center
    label.Parent = parent
    return label
end

local function makeButton(parent, text, primary)
    local button = Instance.new("TextButton")
    button.AutoButtonColor = false
    button.BackgroundColor3 = primary and COLORS.accent or COLORS.card
    button.BorderSizePixel = 0
    button.Text = text
    button.TextColor3 = primary and COLORS.darkText or COLORS.text
    button.TextSize = 12
    button.Font = Enum.Font.GothamMedium
    button.Parent = parent
    addCorner(button, 11)
    addStroke(button, primary and Color3.fromRGB(255, 255, 255) or COLORS.border, primary and 0.72 or 0)

    local baseColor = button.BackgroundColor3
    local hoverColor = primary and Color3.fromRGB(214, 214, 220) or COLORS.cardHover
    track(button.MouseEnter:Connect(function()
        TweenService:Create(button, TweenInfo.new(0.12), { BackgroundColor3 = hoverColor }):Play()
    end))
    track(button.MouseLeave:Connect(function()
        TweenService:Create(button, TweenInfo.new(0.12), { BackgroundColor3 = baseColor }):Play()
    end))

    return button
end

local parent = playerGui
pcall(function()
    if gethui then
        parent = gethui()
    else
        parent = game:GetService("CoreGui")
    end
end)

local oldGui = parent:FindFirstChild("iLunXHub_SoundLab")
if oldGui then
    oldGui:Destroy()
end

gui = Instance.new("ScreenGui")
gui.Name = "iLunXHub_SoundLab"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder = 2147483000
pcall(function()
    if syn and syn.protect_gui then
        syn.protect_gui(gui)
    end
end)

local parented = pcall(function()
    gui.Parent = parent
end)
if not parented then
    gui.Parent = playerGui
end

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.fromOffset(440, 520)
panel.BackgroundColor3 = COLORS.panel
panel.BorderSizePixel = 0
panel.ClipsDescendants = true
panel.Parent = gui
addCorner(panel, 18)
addStroke(panel, Color3.fromRGB(58, 58, 65), 0.08)

local panelScale = Instance.new("UIScale")
panelScale.Parent = panel

local function updateScale()
    local camera = Workspace.CurrentCamera
    local viewport = camera and camera.ViewportSize or Vector2.new(1280, 720)
    panelScale.Scale = math.min(1, (viewport.X - 24) / 440, (viewport.Y - 24) / 520)
end
updateScale()
track(Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(updateScale))
if Workspace.CurrentCamera then
    track(Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale))
end

local topGlow = Instance.new("Frame")
topGlow.Size = UDim2.new(1, 0, 0, 2)
topGlow.BackgroundColor3 = COLORS.accent
topGlow.BackgroundTransparency = 0.16
topGlow.BorderSizePixel = 0
topGlow.Parent = panel

local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 68)
header.BackgroundTransparency = 1
header.Active = true
header.Parent = panel

local mark = Instance.new("Frame")
mark.Size = UDim2.fromOffset(34, 34)
mark.Position = UDim2.fromOffset(18, 17)
mark.BackgroundColor3 = COLORS.accent
mark.BorderSizePixel = 0
mark.Parent = header
addCorner(mark, 10)

local markText = makeLabel(mark, "X", 15, COLORS.darkText, Enum.Font.GothamBold)
markText.Size = UDim2.fromScale(1, 1)
markText.TextXAlignment = Enum.TextXAlignment.Center

local title = makeLabel(header, "XeroHub", 17, COLORS.text, Enum.Font.GothamBold)
title.Position = UDim2.fromOffset(64, 14)
title.Size = UDim2.new(1, -118, 0, 23)

local subtitle = makeLabel(header, "SOUND LAB  ·  KEV", 9, COLORS.secondary, Enum.Font.GothamMedium)
subtitle.Position = UDim2.fromOffset(64, 36)
subtitle.Size = UDim2.new(1, -118, 0, 17)

local closeButton = Instance.new("TextButton")
closeButton.AutoButtonColor = false
closeButton.Size = UDim2.fromOffset(32, 32)
closeButton.Position = UDim2.new(1, -48, 0, 18)
closeButton.BackgroundColor3 = COLORS.card
closeButton.BorderSizePixel = 0
closeButton.Text = "×"
closeButton.TextColor3 = COLORS.secondary
closeButton.TextSize = 20
closeButton.Font = Enum.Font.Gotham
closeButton.Parent = header
addCorner(closeButton, 10)
track(closeButton.Activated:Connect(runtime.cleanup))

local dragging = false
local dragStart
local startPosition

track(header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPosition = panel.Position
    end
end))

track(header.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end))

track(UserInputService.InputChanged:Connect(function(input)
    if not dragging then
        return
    end
    if input.UserInputType ~= Enum.UserInputType.MouseMovement
        and input.UserInputType ~= Enum.UserInputType.Touch then
        return
    end

    local scale = math.max(panelScale.Scale, 0.01)
    local delta = (input.Position - dragStart) / scale
    panel.Position = UDim2.new(
        startPosition.X.Scale,
        startPosition.X.Offset + delta.X,
        startPosition.Y.Scale,
        startPosition.Y.Offset + delta.Y
    )
end))

local body = Instance.new("Frame")
body.Position = UDim2.fromOffset(14, 68)
body.Size = UDim2.new(1, -28, 1, -82)
body.BackgroundTransparency = 1
body.Parent = panel

local intro = makeLabel(
    body,
    "Equipa el arma, inicia la detección y dispara una sola vez.",
    11,
    COLORS.secondary,
    Enum.Font.Gotham
)
intro.Size = UDim2.new(1, 0, 0, 30)
intro.TextWrapped = true
intro.TextYAlignment = Enum.TextYAlignment.Top

local detectButton = makeButton(body, "1  ·  DETECTAR DISPARO", true)
detectButton.Position = UDim2.fromOffset(0, 38)
detectButton.Size = UDim2.new(1, 0, 0, 42)

local statusCard = Instance.new("Frame")
statusCard.Position = UDim2.fromOffset(0, 90)
statusCard.Size = UDim2.new(1, 0, 0, 110)
statusCard.BackgroundColor3 = COLORS.card
statusCard.BorderSizePixel = 0
statusCard.Parent = body
addCorner(statusCard, 13)
addStroke(statusCard, COLORS.border, 0.08)

local statusDot = Instance.new("Frame")
statusDot.Size = UDim2.fromOffset(7, 7)
statusDot.Position = UDim2.fromOffset(14, 15)
statusDot.BackgroundColor3 = COLORS.muted
statusDot.BorderSizePixel = 0
statusDot.Parent = statusCard
addCorner(statusDot, 7)

local statusLabel = makeLabel(statusCard, "Esperando detección", 10, COLORS.secondary, Enum.Font.GothamMedium)
statusLabel.Position = UDim2.fromOffset(28, 8)
statusLabel.Size = UDim2.new(1, -42, 0, 22)

local detectedLabel = makeLabel(statusCard, "Todavía no hay un sonido seleccionado.", 11, COLORS.text, Enum.Font.Gotham)
detectedLabel.Position = UDim2.fromOffset(14, 34)
detectedLabel.Size = UDim2.new(1, -28, 0, 64)
detectedLabel.TextWrapped = true
detectedLabel.TextYAlignment = Enum.TextYAlignment.Top

local navigation = Instance.new("Frame")
navigation.Position = UDim2.fromOffset(0, 210)
navigation.Size = UDim2.new(1, 0, 0, 34)
navigation.BackgroundTransparency = 1
navigation.Parent = body

local previousButton = makeButton(navigation, "‹  ANTERIOR", false)
previousButton.Size = UDim2.new(0.32, 0, 1, 0)

local candidateCount = makeLabel(navigation, "0 candidatos", 10, COLORS.muted, Enum.Font.GothamMedium)
candidateCount.Position = UDim2.new(0.32, 8, 0, 0)
candidateCount.Size = UDim2.new(0.36, -16, 1, 0)
candidateCount.TextXAlignment = Enum.TextXAlignment.Center

local nextButton = makeButton(navigation, "SIGUIENTE  ›", false)
nextButton.Position = UDim2.new(0.68, 0, 0, 0)
nextButton.Size = UDim2.new(0.32, 0, 1, 0)

local fieldTitle = makeLabel(body, "MP3 LOCAL · GITHUB RAW", 9, COLORS.secondary, Enum.Font.GothamMedium)
fieldTitle.Position = UDim2.fromOffset(2, 258)
fieldTitle.Size = UDim2.new(1, -4, 0, 18)

local replacementBox = Instance.new("TextBox")
replacementBox.Position = UDim2.fromOffset(0, 280)
replacementBox.Size = UDim2.new(1, 0, 0, 42)
replacementBox.BackgroundColor3 = COLORS.card
replacementBox.BorderSizePixel = 0
replacementBox.ClearTextOnFocus = false
replacementBox.PlaceholderText = "URL raw del archivo .mp3"
replacementBox.PlaceholderColor3 = COLORS.muted
replacementBox.Text = CUSTOM_SOUND_URL
replacementBox.TextEditable = false
replacementBox.TextColor3 = COLORS.text
replacementBox.TextSize = 10
replacementBox.Font = Enum.Font.Code
replacementBox.TextXAlignment = Enum.TextXAlignment.Left
replacementBox.Parent = body
addCorner(replacementBox, 11)
addStroke(replacementBox, COLORS.border, 0.08)

local fieldPadding = Instance.new("UIPadding")
fieldPadding.PaddingLeft = UDim.new(0, 14)
fieldPadding.PaddingRight = UDim.new(0, 14)
fieldPadding.Parent = replacementBox

local actionRow = Instance.new("Frame")
actionRow.Position = UDim2.fromOffset(0, 332)
actionRow.Size = UDim2.new(1, 0, 0, 42)
actionRow.BackgroundTransparency = 1
actionRow.Parent = body

local previewButton = makeButton(actionRow, "DESCARGAR Y PROBAR", false)
previewButton.Size = UDim2.new(0.42, -5, 1, 0)

local applyButton = makeButton(actionRow, "2  ·  ACTIVAR", true)
applyButton.Position = UDim2.new(0.42, 5, 0, 0)
applyButton.Size = UDim2.new(0.58, -5, 1, 0)

local restoreButton = makeButton(body, "RESTAURAR SONIDO ORIGINAL", false)
restoreButton.Position = UDim2.fromOffset(0, 384)
restoreButton.Size = UDim2.new(1, 0, 0, 38)

local footer = makeLabel(
    body,
    "El MP3 se descarga una vez y queda guardado en la carpeta de XeroHub.",
    9,
    COLORS.muted,
    Enum.Font.Gotham
)
footer.Position = UDim2.fromOffset(0, 428)
footer.Size = UDim2.new(1, 0, 0, 22)
footer.TextXAlignment = Enum.TextXAlignment.Center

local function setStatus(text, color)
    statusLabel.Text = tostring(text)
    statusLabel.TextColor3 = color or COLORS.secondary
    statusDot.BackgroundColor3 = color or COLORS.muted
end

local function downloadAndLoadLocalAsset(sourceUrl)
    if not localAssetLoader then
        return nil, "Tu executor no incluye getcustomasset ni getsynasset."
    end
    if type(writefile) ~= "function" then
        return nil, "Tu executor no permite guardar archivos con writefile."
    end

    local localPath = LOCAL_AUDIO_PATH
    if type(makefolder) == "function" then
        pcall(makefolder, "XeroHub")
        pcall(makefolder, LOCAL_AUDIO_FOLDER)
    else
        localPath = "XeroHub_anime_magic_057d16da.mp3"
    end

    local body = nil
    if type(isfile) == "function" and type(readfile) == "function" and isfile(localPath) then
        local okRead, cached = pcall(readfile, localPath)
        if okRead and Core.isAudioPayload(200, cached) then
            body = cached
        end
    end

    if not body then
        local statusCode = 0
        if httpRequest then
            local okRequest, response = pcall(httpRequest, {
                Url = Core.toCanonicalRawUrl(sourceUrl),
                Method = "GET",
                Headers = {
                    ["User-Agent"] = "XeroHub-SoundLab",
                },
            })
            if okRequest and type(response) == "table" then
                statusCode = tonumber(response.StatusCode or response.Status) or 0
                body = response.Body or response.body
            end
        else
            local okHttpGet, responseBody = pcall(function()
                return game:HttpGet(Core.toCanonicalRawUrl(sourceUrl))
            end)
            if okHttpGet then
                statusCode = 200
                body = responseBody
            end
        end

        if not Core.isAudioPayload(statusCode, body) then
            return nil, "GitHub no devolvió un MP3 válido (HTTP " .. tostring(statusCode) .. ")."
        end

        local okWrite, writeError = pcall(writefile, localPath, body)
        if not okWrite then
            return nil, "No se pudo guardar el MP3: " .. tostring(writeError)
        end
    end

    local okAsset, assetId = pcall(localAssetLoader, localPath)
    if not okAsset or type(assetId) ~= "string" or assetId == "" then
        return nil, tostring(localAssetLoaderName) .. " no pudo registrar el MP3 local."
    end

    return assetId, localPath
end

local function safeFullName(instance)
    local ok, name = pcall(function()
        return instance:GetFullName()
    end)
    return ok and name or tostring(instance and instance.Name or "Sound")
end

local function getEquippedTool()
    local character = player.Character
    return character and character:FindFirstChildOfClass("Tool") or nil
end

local function isDescendantOf(instance, ancestor)
    return instance and ancestor and instance:IsDescendantOf(ancestor)
end

local function getScope(sound)
    local tool = sound:FindFirstAncestorWhichIsA("Tool")
    if tool then
        return "tool"
    end

    local character = player.Character
    if isDescendantOf(sound, character) then
        return "character"
    end
    if isDescendantOf(sound, Workspace.CurrentCamera) then
        return "camera"
    end
    if isDescendantOf(sound, playerGui) then
        return "interface"
    end
    if isDescendantOf(sound, SoundService) then
        return "soundservice"
    end
    if isDescendantOf(sound, Workspace) then
        return "workspace"
    end
    return "unknown"
end

local function getDistance(sound)
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local part = sound:FindFirstAncestorWhichIsA("BasePart")
    if not root or not part then
        return nil
    end
    return (part.Position - root.Position).Magnitude
end

local function describeSound(sound, newlyCreated, observedAt)
    local soundId = ""
    pcall(function()
        soundId = sound.SoundId
    end)

    return {
        instance = sound,
        name = sound.Name,
        soundId = soundId,
        path = safeFullName(sound),
        scope = getScope(sound),
        distance = getDistance(sound),
        newlyCreated = newlyCreated == true,
        wasPlaying = sound.IsPlaying == true,
        observedAt = observedAt or 0,
    }
end

local function updateSelectedCandidate(index)
    local count = #runtime.candidates
    candidateCount.Text = tostring(count) .. (count == 1 and " candidato" or " candidatos")

    if count == 0 then
        runtime.selectedIndex = 0
        detectedLabel.Text = "No se detectó ningún sonido. Equipa el arma y vuelve a intentarlo."
        return
    end

    if index < 1 then
        index = count
    elseif index > count then
        index = 1
    end

    runtime.selectedIndex = index
    local candidate = runtime.candidates[index]
    local normalized = Core.normalizeAssetId(candidate.soundId) or "ID vacío/no disponible"
    local path = candidate.path
    if #path > 66 then
        path = "…" .. string.sub(path, -65)
    end

    detectedLabel.Text = string.format(
        "%s  ·  %s\n%s\n%s",
        candidate.name,
        string.upper(candidate.scope),
        normalized,
        path
    )
end

local function addCandidate(sound, newlyCreated, captureStartedAt)
    if not runtime.alive or not sound or not sound:IsA("Sound") then
        return
    end

    local candidate = runtime.candidateBySound[sound]
    if candidate then
        candidate.wasPlaying = sound.IsPlaying == true
        candidate.observedAt = os.clock() - captureStartedAt
        return
    end

    candidate = describeSound(sound, newlyCreated, os.clock() - captureStartedAt)
    runtime.candidateBySound[sound] = candidate
    table.insert(runtime.candidates, candidate)

    local best = Core.chooseBestCandidate(runtime.candidates)
    for index, current in ipairs(runtime.candidates) do
        if current == best then
            updateSelectedCandidate(index)
            break
        end
    end
end

local function beginCapture()
    runtime.captureToken = runtime.captureToken + 1
    local token = runtime.captureToken
    disconnectList(runtime.captureConnections)
    runtime.candidates = {}
    runtime.candidateBySound = setmetatable({}, { __mode = "k" })
    runtime.selectedIndex = 0
    updateSelectedCandidate(0)

    local equippedTool = getEquippedTool()
    if not equippedTool then
        setStatus("Equipa un arma antes de detectar", COLORS.warning)
        detectedLabel.Text = "No encontré ningún Tool equipado en tu personaje."
        return
    end

    setStatus("Escuchando 4 s · dispara una vez", COLORS.warning)
    detectedLabel.Text = "Capturando sonidos reproducidos por " .. equippedTool.Name .. "…"
    detectButton.Text = "ESCUCHANDO… DISPARA AHORA"

    local captureStartedAt = os.clock()
    local observed = setmetatable({}, { __mode = "k" })

    local function observe(sound, newlyCreated)
        if observed[sound] or not sound:IsA("Sound") then
            return
        end
        observed[sound] = true

        local okPlayed, playedConnection = pcall(function()
            return sound.Played:Connect(function()
                if runtime.captureToken == token then
                    addCandidate(sound, newlyCreated, captureStartedAt)
                end
            end)
        end)
        if okPlayed then
            track(playedConnection, runtime.captureConnections)
        end

        local okPlaying, playingConnection = pcall(function()
            return sound:GetPropertyChangedSignal("Playing"):Connect(function()
                if runtime.captureToken == token and sound.Playing then
                    addCandidate(sound, newlyCreated, captureStartedAt)
                end
            end)
        end)
        if okPlaying then
            track(playingConnection, runtime.captureConnections)
        end

        if newlyCreated then
            task.defer(function()
                if runtime.captureToken == token and sound.Parent and sound.IsPlaying then
                    addCandidate(sound, true, captureStartedAt)
                end
            end)
        end
    end

    local roots = {
        equippedTool,
        player.Character,
        player:FindFirstChildOfClass("Backpack"),
        Workspace.CurrentCamera,
        SoundService,
        playerGui,
    }

    for _, root in ipairs(roots) do
        if root then
            if root:IsA("Sound") then
                observe(root, false)
            end
            for _, descendant in ipairs(root:GetDescendants()) do
                if descendant:IsA("Sound") then
                    observe(descendant, false)
                end
            end
        end
    end

    track(game.DescendantAdded:Connect(function(descendant)
        if runtime.captureToken == token and descendant:IsA("Sound") then
            observe(descendant, true)
        end
    end), runtime.captureConnections)

    task.delay(4, function()
        if not runtime.alive or runtime.captureToken ~= token then
            return
        end

        disconnectList(runtime.captureConnections)
        detectButton.Text = "1  ·  DETECTAR DISPARO"

        if #runtime.candidates == 0 then
            setStatus("No se detectó sonido", COLORS.error)
            updateSelectedCandidate(0)
            return
        end

        local best = Core.chooseBestCandidate(runtime.candidates)
        for index, candidate in ipairs(runtime.candidates) do
            if candidate == best then
                updateSelectedCandidate(index)
                break
            end
        end
        setStatus("Disparo detectado · revisa el resultado", COLORS.success)
    end)
end

local function selectedCandidate()
    return runtime.candidates[runtime.selectedIndex]
end

local function metadataForMatch(sound)
    return {
        name = sound.Name,
        soundId = sound.SoundId,
        scope = getScope(sound),
    }
end

local applyToSound

local function playCustomShot(sourceSound)
    if not runtime.liveEnabled or not customShotSound or not customShotSound.Parent then
        return
    end

    local originalState = runtime.originals[sourceSound]
    pcall(function()
        customShotSound:Stop()
        customShotSound.TimePosition = 0
        customShotSound.Volume = originalState and math.max(originalState.volume, 0.35) or 1
        customShotSound:Play()
    end)
end

local function bindTargetSound(sound)
    if runtime.soundWatchers[sound] then
        return true
    end

    runtime.originals[sound] = {
        volume = sound.Volume,
    }

    local bundle = {}
    bundle.played = sound.Played:Connect(function()
        playCustomShot(sound)
    end)
    bundle.volume = sound:GetPropertyChangedSignal("Volume"):Connect(function()
        if runtime.liveEnabled and not runtime.applying[sound] and sound.Parent and sound.Volume ~= 0 then
            runtime.applying[sound] = true
            sound.Volume = 0
            runtime.applying[sound] = nil
        end
    end)
    runtime.soundWatchers[sound] = bundle

    runtime.applying[sound] = true
    local ok = pcall(function()
        sound.Volume = 0
    end)
    runtime.applying[sound] = nil
    return ok
end

applyToSound = function(sound)
    if not runtime.liveEnabled or not runtime.target or not runtime.localAssetId then
        return false
    end
    if not sound or not sound.Parent or not sound:IsA("Sound") then
        return false
    end

    if not Core.matchesTarget(metadataForMatch(sound), runtime.target) then
        return false
    end
    return bindTargetSound(sound)
end

local function scanLikelySounds(callback)
    local roots = {
        getEquippedTool(),
        player.Character,
        player:FindFirstChildOfClass("Backpack"),
        Workspace.CurrentCamera,
        SoundService,
        playerGui,
    }
    local seen = setmetatable({}, { __mode = "k" })

    for _, root in ipairs(roots) do
        if root then
            if root:IsA("Sound") and not seen[root] then
                seen[root] = true
                callback(root)
            end
            for _, descendant in ipairs(root:GetDescendants()) do
                if descendant:IsA("Sound") and not seen[descendant] then
                    seen[descendant] = true
                    callback(descendant)
                end
            end
        end
    end
end

local function applyReplacement()
    local candidate = selectedCandidate()
    if not candidate then
        setStatus("Primero detecta el disparo", COLORS.error)
        return
    end

    runtime.loadToken = (runtime.loadToken or 0) + 1
    local token = runtime.loadToken
    if previewSound then
        pcall(function()
            previewSound:Destroy()
        end)
        previewSound = nil
    end

    setStatus("Descargando y preparando el MP3…", COLORS.warning)
    applyButton.Text = "PREPARANDO MP3…"

    task.spawn(function()
        local localAssetId, result = downloadAndLoadLocalAsset(replacementBox.Text)

        if not runtime.alive or runtime.loadToken ~= token then
            return
        end

        if not localAssetId then
            applyButton.Text = "2  ·  ACTIVAR"
            footer.Text = tostring(result)
            setStatus("No se pudo preparar el MP3 local", COLORS.error)
            return
        end

        restoreOriginals()
        runtime.localAssetId = localAssetId
        runtime.localAssetUrl = replacementBox.Text

        customShotSound = Instance.new("Sound")
        customShotSound.Name = "XeroHub_CustomGunshot"
        customShotSound.SoundId = localAssetId
        customShotSound.Volume = 1
        customShotSound.Parent = SoundService

        local loaded = Core.waitForCondition(function()
            return runtime.alive and customShotSound ~= nil
                and customShotSound.Parent ~= nil and customShotSound.IsLoaded
        end, 6, os.clock, task.wait)

        if not runtime.alive or runtime.loadToken ~= token then
            return
        end
        if not loaded then
            restoreOriginals()
            applyButton.Text = "2  ·  ACTIVAR"
            footer.Text = tostring(localAssetLoaderName) .. " devolvió una ruta, pero Roblox no cargó el archivo."
            setStatus("El executor no pudo cargar el MP3 local", COLORS.error)
            return
        end

        runtime.target = {
            originalId = candidate.soundId,
            name = candidate.name,
            scope = candidate.scope,
        }
        runtime.liveEnabled = true

        local changed = 0
        if candidate.instance and candidate.instance.Parent and applyToSound(candidate.instance) then
            changed = changed + 1
        end

        scanLikelySounds(function(sound)
            if sound ~= candidate.instance and applyToSound(sound) then
                changed = changed + 1
            end
        end)

        track(game.DescendantAdded:Connect(function(descendant)
            if runtime.liveEnabled and descendant:IsA("Sound") then
                applyToSound(descendant)
            end
        end), runtime.liveConnections)

        setStatus("Overlay local activo · dispara ahora", COLORS.success)
        applyButton.Text = "ACTIVO  ·  MP3 LOCAL"
        footer.Text = "Gunshot silenciado: " .. tostring(changed) .. " · loader: " .. tostring(localAssetLoaderName) .. "."
    end)
end

local function previewReplacement()
    runtime.loadToken = (runtime.loadToken or 0) + 1
    local token = runtime.loadToken
    if previewSound then
        pcall(function()
            previewSound:Destroy()
        end)
    end

    setStatus("Descargando MP3 desde GitHub…", COLORS.warning)
    previewButton.Text = "DESCARGANDO…"

    task.spawn(function()
        local localAssetId, result = downloadAndLoadLocalAsset(replacementBox.Text)

        if not runtime.alive or runtime.loadToken ~= token then
            return
        end
        if not localAssetId then
            previewButton.Text = "DESCARGAR Y PROBAR"
            footer.Text = tostring(result)
            setStatus("No se pudo preparar el MP3 local", COLORS.error)
            return
        end

        previewSound = Instance.new("Sound")
        local sound = previewSound
        sound.Name = "XeroHub_SoundPreview"
        sound.SoundId = localAssetId
        sound.Volume = 1
        sound.Parent = SoundService

        local loaded = Core.waitForCondition(function()
            return runtime.alive and sound.Parent ~= nil and sound.IsLoaded
        end, 6, os.clock, task.wait)

        if not runtime.alive or runtime.loadToken ~= token then
            if sound.Parent then
                sound:Destroy()
            end
            return
        end

        previewButton.Text = "DESCARGAR Y PROBAR"
        if not loaded then
            if sound.Parent then
                sound:Destroy()
            end
            if previewSound == sound then
                previewSound = nil
            end
            footer.Text = tostring(localAssetLoaderName) .. " no logró cargar el MP3 guardado."
            setStatus("El executor no admite este MP3 local", COLORS.error)
            return
        end

        sound.TimePosition = 0
        sound:Play()
        task.wait(0.1)

        if sound.IsPlaying then
            footer.Text = "MP3 descargado, guardado y cargado con " .. tostring(localAssetLoaderName) .. "."
            setStatus("MP3 local reproduciéndose", COLORS.success)
        else
            footer.Text = "El archivo cargó, pero el executor no inició el Sound."
            setStatus("No se pudo reproducir el MP3 local", COLORS.error)
        end

        task.delay(12, function()
            if sound.Parent then
                sound:Destroy()
            end
            if previewSound == sound then
                previewSound = nil
            end
        end)
    end)
end

track(detectButton.Activated:Connect(beginCapture))
track(previousButton.Activated:Connect(function()
    if #runtime.candidates > 0 then
        updateSelectedCandidate(runtime.selectedIndex - 1)
        setStatus("Candidato anterior seleccionado", COLORS.secondary)
    end
end))
track(nextButton.Activated:Connect(function()
    if #runtime.candidates > 0 then
        updateSelectedCandidate(runtime.selectedIndex + 1)
        setStatus("Candidato siguiente seleccionado", COLORS.secondary)
    end
end))
track(previewButton.Activated:Connect(previewReplacement))
track(applyButton.Activated:Connect(applyReplacement))
track(restoreButton.Activated:Connect(function()
    restoreOriginals()
    applyButton.Text = "2  ·  ACTIVAR"
    footer.Text = "El MP3 queda almacenado localmente para no descargarlo cada vez."
    setStatus("Sonidos originales restaurados", COLORS.secondary)
end))

track(player.CharacterAdded:Connect(function()
    if runtime.liveEnabled then
        setStatus("Reapareciste · esperando el arma nueva", COLORS.secondary)
    end
end))

if localAssetLoader then
    setStatus("Listo · loader local: " .. tostring(localAssetLoaderName), COLORS.success)
else
    footer.Text = "Este executor no expone getcustomasset ni getsynasset."
    setStatus("Executor sin soporte para audio local", COLORS.error)
end

return runtime
