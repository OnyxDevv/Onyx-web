--========================================================--
-- Xero | DUELS Emote Inspector
-- Creator: Kev
--
-- OBJETIVO:
-- 1. Ejecutar este script.
-- 2. Presionar "Escanear".
-- 3. Hacer manualmente un emote que SÍ tengas.
-- 4. Revisar PLAYED para obtener AnimationId + ruta.
--========================================================--

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

--========================================================--
-- ESTADO
--========================================================--

local connections = {}
local seen = {}
local lastResult = ""

local function trackConnection(connection)
    table.insert(connections, connection)
    return connection
end

local function disconnectAll()
    for _, connection in ipairs(connections) do
        pcall(function()
            connection:Disconnect()
        end)
    end

    table.clear(connections)
end

--========================================================--
-- HELPERS
--========================================================--

local function getPath(object)
    if not object then
        return "[sin objeto]"
    end

    local ok, result = pcall(function()
        return object:GetFullName()
    end)

    if ok then
        return result
    end

    return object.Name or "[desconocido]"
end

local function cleanAnimationId(animationId)
    animationId = tostring(animationId or "")

    return animationId:match("%d+") or animationId
end

--========================================================--
-- UI
--========================================================--

local old = playerGui:FindFirstChild("XeroEmoteInspector")

if old then
    old:Destroy()
end

local gui = Instance.new("ScreenGui")
gui.Name = "XeroEmoteInspector"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 999999

local parent = playerGui

pcall(function()
    if gethui then
        parent = gethui()
    end
end)

gui.Parent = parent

local main = Instance.new("Frame")
main.Name = "Main"
main.Size = UDim2.fromOffset(520, 390)
main.Position = UDim2.new(0.5, -260, 0.5, -195)
main.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
main.BorderSizePixel = 0
main.Parent = gui

Instance.new("UICorner", main).CornerRadius = UDim.new(0, 16)

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(50, 50, 50)
stroke.Thickness = 1
stroke.Parent = main

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -40, 0, 28)
title.Position = UDim2.fromOffset(18, 12)
title.BackgroundTransparency = 1
title.Text = "XERO | EMOTE INSPECTOR"
title.TextColor3 = Color3.fromRGB(245, 245, 245)
title.TextSize = 16
title.Font = Enum.Font.GothamBold
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = main

local subtitle = Instance.new("TextLabel")
subtitle.Size = UDim2.new(1, -40, 0, 18)
subtitle.Position = UDim2.fromOffset(18, 38)
subtitle.BackgroundTransparency = 1
subtitle.Text = "Haz un emote y mira qué Animation se reproduce."
subtitle.TextColor3 = Color3.fromRGB(140, 140, 140)
subtitle.TextSize = 11
subtitle.Font = Enum.Font.Gotham
subtitle.TextXAlignment = Enum.TextXAlignment.Left
subtitle.Parent = main

--========================================================--
-- BOTONES
--========================================================--

local buttonHolder = Instance.new("Frame")
buttonHolder.Size = UDim2.new(1, -36, 0, 34)
buttonHolder.Position = UDim2.fromOffset(18, 67)
buttonHolder.BackgroundTransparency = 1
buttonHolder.Parent = main

local buttonLayout = Instance.new("UIListLayout")
buttonLayout.FillDirection = Enum.FillDirection.Horizontal
buttonLayout.Padding = UDim.new(0, 7)
buttonLayout.Parent = buttonHolder

local function createButton(text, width)
    local button = Instance.new("TextButton")
    button.Size = UDim2.fromOffset(width or 100, 34)
    button.BackgroundColor3 = Color3.fromRGB(24, 24, 24)
    button.BorderSizePixel = 0
    button.Text = text
    button.TextColor3 = Color3.fromRGB(225, 225, 225)
    button.Font = Enum.Font.GothamMedium
    button.TextSize = 11
    button.AutoButtonColor = true
    button.Parent = buttonHolder

    Instance.new("UICorner", button).CornerRadius = UDim.new(0, 9)

    return button
end

local scanButton = createButton("Escanear", 105)
local clearButton = createButton("Limpiar", 95)
local copyButton = createButton("Copiar último", 120)

--========================================================--
-- RESULTADOS
--========================================================--

local results = Instance.new("ScrollingFrame")
results.Size = UDim2.new(1, -36, 1, -126)
results.Position = UDim2.fromOffset(18, 112)
results.BackgroundColor3 = Color3.fromRGB(14, 14, 14)
results.BorderSizePixel = 0
results.ScrollBarThickness = 3
results.ScrollBarImageColor3 = Color3.fromRGB(90, 90, 90)
results.CanvasSize = UDim2.new()
results.Parent = main

Instance.new("UICorner", results).CornerRadius = UDim.new(0, 11)

local padding = Instance.new("UIPadding")
padding.PaddingTop = UDim.new(0, 8)
padding.PaddingBottom = UDim.new(0, 8)
padding.PaddingLeft = UDim.new(0, 8)
padding.PaddingRight = UDim.new(0, 8)
padding.Parent = results

local resultLayout = Instance.new("UIListLayout")
resultLayout.Padding = UDim.new(0, 5)
resultLayout.Parent = results

resultLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    results.CanvasSize = UDim2.fromOffset(
        0,
        resultLayout.AbsoluteContentSize.Y + 16
    )
end)

local function addResult(category, text, key)
    key = key or (category .. ":" .. text)

    if seen[key] then
        return
    end

    seen[key] = true

    local container = Instance.new("Frame")
    container.AutomaticSize = Enum.AutomaticSize.Y
    container.Size = UDim2.new(1, -2, 0, 0)
    container.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    container.BorderSizePixel = 0
    container.Parent = results

    Instance.new("UICorner", container).CornerRadius = UDim.new(0, 8)

    local label = Instance.new("TextLabel")
    label.AutomaticSize = Enum.AutomaticSize.Y
    label.Size = UDim2.new(1, -18, 0, 0)
    label.Position = UDim2.fromOffset(9, 7)
    label.BackgroundTransparency = 1

    label.Text =
        "[" .. tostring(category) .. "]\n" ..
        tostring(text)

    label.TextColor3 =
        category == "PLAYED"
        and Color3.fromRGB(255, 255, 255)
        or Color3.fromRGB(185, 185, 185)

    label.Font = Enum.Font.Code
    label.TextSize = 11
    label.TextWrapped = true
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextYAlignment = Enum.TextYAlignment.Top
    label.Parent = container

    local bottom = Instance.new("UIPadding")
    bottom.PaddingBottom = UDim.new(0, 7)
    bottom.Parent = container

    lastResult = tostring(text)

    task.defer(function()
        results.CanvasPosition = Vector2.new(
            0,
            math.max(0, resultLayout.AbsoluteContentSize.Y)
        )
    end)
end

--========================================================--
-- DETECTOR DE ANIMACIONES
--========================================================--

local function inspectAnimation(animation, origin)
    if not animation or not animation:IsA("Animation") then
        return
    end

    local id = cleanAnimationId(animation.AnimationId)
    local path = getPath(animation)

    addResult(
        "STORED",
        "Nombre: " .. animation.Name ..
        "\nID: " .. tostring(id) ..
        "\nRuta: " .. path ..
        "\nOrigen: " .. tostring(origin),
        "animation:" .. path .. ":" .. tostring(id)
    )
end

--========================================================--
-- CONTENEDORES SOSPECHOSOS
--========================================================--

local interestingWords = {
    "emote",
    "emotes",
    "dance",
    "dances",
    "animation",
    "animations"
}

local function isInterestingName(name)
    name = string.lower(tostring(name))

    for _, word in ipairs(interestingWords) do
        if string.find(name, word, 1, true) then
            return true
        end
    end

    return false
end

local function inspectCandidate(object)
    if not object then
        return
    end

    if (
        object:IsA("Folder")
        or object:IsA("Model")
        or object:IsA("Configuration")
        or object:IsA("ModuleScript")
    ) and isInterestingName(object.Name) then

        local path = getPath(object)

        addResult(
            "CANDIDATE",
            object.ClassName .. "\n" .. path,
            "candidate:" .. path
        )
    end
end

--========================================================--
-- ESCANEO
--========================================================--

local function scanRoot(root, rootName)
    if not root then
        return
    end

    inspectCandidate(root)

    local ok, descendants = pcall(function()
        return root:GetDescendants()
    end)

    if not ok then
        return
    end

    for index, object in ipairs(descendants) do

        if object:IsA("Animation") then
            inspectAnimation(object, rootName)
        else
            inspectCandidate(object)
        end

        -- Evita congelar el cliente en árboles grandes.
        if index % 600 == 0 then
            task.wait()
        end
    end
end

local function fullScan()
    addResult(
        "INFO",
        "Escaneo iniciado...",
        "scan:" .. tostring(os.clock())
    )

    task.spawn(function()
        scanRoot(ReplicatedStorage, "ReplicatedStorage")
        scanRoot(Workspace, "Workspace")
        scanRoot(playerGui, "PlayerGui")

        local backpack = player:FindFirstChildOfClass("Backpack")

        if backpack then
            scanRoot(backpack, "Backpack")
        end

        if player.Character then
            scanRoot(player.Character, "Character")
        end

        addResult(
            "INFO",
            "Escaneo terminado. Ahora reproduce manualmente tu emote.",
            "scanComplete:" .. tostring(os.clock())
        )
    end)
end

--========================================================--
-- ANIMATOR LIVE WATCHER
--========================================================--

local animatorConnection

local function watchCharacter(character)
    if animatorConnection then
        animatorConnection:Disconnect()
        animatorConnection = nil
    end

    local humanoid =
        character:FindFirstChildOfClass("Humanoid")
        or character:WaitForChild("Humanoid", 10)

    if not humanoid then
        addResult(
            "ERROR",
            "No se encontró Humanoid."
        )

        return
    end

    local animator =
        humanoid:FindFirstChildOfClass("Animator")
        or humanoid:WaitForChild("Animator", 10)

    if not animator then
        addResult(
            "ERROR",
            "No se encontró Animator."
        )

        return
    end

    -- Animaciones que ya estaban reproduciéndose.
    pcall(function()
        for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
            local animation = track.Animation

            if animation then
                local id = cleanAnimationId(animation.AnimationId)

                addResult(
                    "PLAYING",
                    "ID: " .. tostring(id) ..
                    "\nNombre: " .. tostring(animation.Name) ..
                    "\nRuta: " .. getPath(animation),
                    "playing:" .. tostring(id)
                )
            end
        end
    end)

    animatorConnection = animator.AnimationPlayed:Connect(function(track)
        local animation = track.Animation

        local id = "desconocido"
        local name = "desconocido"
        local path = "[Animation no expuesta]"

        if animation then
            id = cleanAnimationId(animation.AnimationId)
            name = animation.Name
            path = getPath(animation)
        end

        local priority = "?"
        local looped = "?"

        pcall(function()
            priority = tostring(track.Priority)
            looped = tostring(track.Looped)
        end)

        local data =
            "ID: " .. tostring(id) ..
            "\nNombre: " .. tostring(name) ..
            "\nRuta: " .. tostring(path) ..
            "\nPrioridad: " .. tostring(priority) ..
            "\nLooped: " .. tostring(looped)

        -- PLAYED no se deduplica a propósito.
        addResult(
            "PLAYED",
            data,
            "played:" .. tostring(id) .. ":" .. tostring(os.clock())
        )

        print("\n[Xero Emote Inspector]")
        print(data)
    end)

    addResult(
        "WATCHER",
        "Animator conectado.\nHaz ahora el emote que compraste.",
        "animator:" .. tostring(character)
    )
end

--========================================================--
-- NUEVOS OBJETOS
--========================================================--

local function watchRoot(root, rootName)
    if not root then
        return
    end

    trackConnection(root.DescendantAdded:Connect(function(object)
        if object:IsA("Animation") then
            inspectAnimation(object, rootName .. " · nuevo")
        else
            inspectCandidate(object)
        end
    end))
end

watchRoot(ReplicatedStorage, "ReplicatedStorage")
watchRoot(Workspace, "Workspace")
watchRoot(playerGui, "PlayerGui")

if player.Character then
    watchCharacter(player.Character)
end

trackConnection(player.CharacterAdded:Connect(function(character)
    task.wait(1)
    watchCharacter(character)
end))

--========================================================--
-- BOTONES
--========================================================--

scanButton.MouseButton1Click:Connect(fullScan)

clearButton.MouseButton1Click:Connect(function()
    table.clear(seen)
    lastResult = ""

    for _, child in ipairs(results:GetChildren()) do
        if child:IsA("Frame") then
            child:Destroy()
        end
    end
end)

copyButton.MouseButton1Click:Connect(function()
    if lastResult == "" then
        return
    end

    if setclipboard then
        pcall(setclipboard, lastResult)

        addResult(
            "INFO",
            "Último resultado copiado.",
            "copied:" .. tostring(os.clock())
        )
    end
end)

--========================================================--
-- DRAG
--========================================================--

local dragging = false
local dragStart
local startPosition

title.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then

        dragging = true
        dragStart = input.Position
        startPosition = main.Position
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if not dragging then
        return
    end

    if input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch then

        local delta = input.Position - dragStart

        main.Position = UDim2.new(
            startPosition.X.Scale,
            startPosition.X.Offset + delta.X,
            startPosition.Y.Scale,
            startPosition.Y.Offset + delta.Y
        )
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then

        dragging = false
    end
end)

addResult(
    "READY",
    "Inspector iniciado.\nPulsa Escanear y después reproduce tu emote.",
    "ready"
)
