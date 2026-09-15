--========================================================--
-- Xero | DUELS Emote Catalog Scanner V3
-- Creator: Kev
--
-- PASOS:
-- 1. Ejecutar con el menú EMOTES cerrado.
-- 2. "Capturar antes".
-- 3. Abrir el menú EMOTES del juego.
-- 4. "Comparar después".
-- 5. "Buscar ID conocido".
--========================================================--

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local KNOWN_EMOTE_ID = "125804051938799"

local beforeSnapshot = {}
local reportLines = {}
local liveConnections = {}

--========================================================--
-- HELPERS
--========================================================--

local function path(obj)
    local ok, result = pcall(function()
        return obj:GetFullName()
    end)

    return ok and result or tostring(obj)
end

local function lower(v)
    return string.lower(tostring(v or ""))
end

local keywords = {
    "emote",
    "emotes",
    "dance",
    "dances",
    "animation",
    "animations",
    "gesture"
}

local function interestingText(value)
    value = lower(value)

    if value:find(KNOWN_EMOTE_ID, 1, true) then
        return true
    end

    for _, word in ipairs(keywords) do
        if value:find(word, 1, true) then
            return true
        end
    end

    return false
end

local function objectInteresting(obj)
    if interestingText(obj.Name) then
        return true
    end

    local p = lower(path(obj))

    for _, word in ipairs(keywords) do
        if p:find(word, 1, true) then
            return true
        end
    end

    return false
end

--========================================================--
-- LEER PROPIEDADES SEGURAS
--========================================================--

local function inspectProperties(obj)
    local data = {}

    if obj:IsA("Animation") then
        data.AnimationId = obj.AnimationId

    elseif obj:IsA("StringValue")
        or obj:IsA("IntValue")
        or obj:IsA("NumberValue")
        or obj:IsA("BoolValue") then

        data.Value = tostring(obj.Value)

    elseif obj:IsA("ObjectValue") then
        data.Value = obj.Value and path(obj.Value) or "nil"

    elseif obj:IsA("TextLabel")
        or obj:IsA("TextButton")
        or obj:IsA("TextBox") then

        data.Text = obj.Text

    elseif obj:IsA("ImageLabel")
        or obj:IsA("ImageButton") then

        data.Image = obj.Image
    end

    local ok, attrs = pcall(function()
        return obj:GetAttributes()
    end)

    if ok then
        for name, value in pairs(attrs) do
            data["Attribute." .. tostring(name)] = tostring(value)
        end
    end

    return data
end

local function signature(obj)
    local pieces = {
        obj.ClassName,
        obj.Name
    }

    local props = inspectProperties(obj)

    for key, value in pairs(props) do
        table.insert(
            pieces,
            tostring(key) .. "=" .. tostring(value)
        )
    end

    table.sort(pieces)

    return table.concat(pieces, "|")
end

--========================================================--
-- UI
--========================================================--

local previous = playerGui:FindFirstChild("XeroEmoteCatalogScanner")

if previous then
    previous:Destroy()
end

local gui = Instance.new("ScreenGui")
gui.Name = "XeroEmoteCatalogScanner"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 999999

local guiParent = playerGui

pcall(function()
    if gethui then
        guiParent = gethui()
    end
end)

gui.Parent = guiParent

local main = Instance.new("Frame")
main.Size = UDim2.fromOffset(580, 430)
main.Position = UDim2.new(0.5, -290, 0.5, -215)
main.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
main.BorderSizePixel = 0
main.Parent = gui

Instance.new("UICorner", main).CornerRadius = UDim.new(0, 16)

local border = Instance.new("UIStroke")
border.Color = Color3.fromRGB(60, 60, 60)
border.Parent = main

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -30, 0, 28)
title.Position = UDim2.fromOffset(15, 12)
title.BackgroundTransparency = 1
title.Text = "XERO | EMOTE CATALOG SCANNER V3"
title.TextColor3 = Color3.fromRGB(245, 245, 245)
title.Font = Enum.Font.GothamBold
title.TextSize = 15
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = main

local subtitle = Instance.new("TextLabel")
subtitle.Size = UDim2.new(1, -30, 0, 18)
subtitle.Position = UDim2.fromOffset(15, 39)
subtitle.BackgroundTransparency = 1
subtitle.Text = "Compara el cliente antes y después de abrir EMOTES"
subtitle.TextColor3 = Color3.fromRGB(140, 140, 140)
subtitle.Font = Enum.Font.Gotham
subtitle.TextSize = 11
subtitle.TextXAlignment = Enum.TextXAlignment.Left
subtitle.Parent = main

local buttons = Instance.new("Frame")
buttons.Size = UDim2.new(1, -30, 0, 36)
buttons.Position = UDim2.fromOffset(15, 67)
buttons.BackgroundTransparency = 1
buttons.Parent = main

local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Horizontal
layout.Padding = UDim.new(0, 6)
layout.Parent = buttons

local function button(text, width)
    local b = Instance.new("TextButton")
    b.Size = UDim2.fromOffset(width, 34)
    b.BackgroundColor3 = Color3.fromRGB(24, 24, 24)
    b.BorderSizePixel = 0
    b.Text = text
    b.TextColor3 = Color3.fromRGB(230, 230, 230)
    b.Font = Enum.Font.GothamMedium
    b.TextSize = 10
    b.Parent = buttons

    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 9)

    return b
end

local beforeButton = button("1 · CAPTURAR ANTES", 130)
local compareButton = button("2 · COMPARAR", 110)
local searchButton = button("BUSCAR ID", 95)
local copyButton = button("COPIAR", 75)
local clearButton = button("LIMPIAR", 75)

local output = Instance.new("ScrollingFrame")
output.Size = UDim2.new(1, -30, 1, -122)
output.Position = UDim2.fromOffset(15, 112)
output.BackgroundColor3 = Color3.fromRGB(14, 14, 14)
output.BorderSizePixel = 0
output.ScrollBarThickness = 3
output.CanvasSize = UDim2.new()
output.Parent = main

Instance.new("UICorner", output).CornerRadius = UDim.new(0, 10)

local outPadding = Instance.new("UIPadding")
outPadding.PaddingTop = UDim.new(0, 8)
outPadding.PaddingBottom = UDim.new(0, 8)
outPadding.PaddingLeft = UDim.new(0, 8)
outPadding.PaddingRight = UDim.new(0, 8)
outPadding.Parent = output

local outLayout = Instance.new("UIListLayout")
outLayout.Padding = UDim.new(0, 4)
outLayout.Parent = output

outLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    output.CanvasSize = UDim2.fromOffset(
        0,
        outLayout.AbsoluteContentSize.Y + 16
    )
end)

local function log(text)
    text = tostring(text)

    table.insert(reportLines, text)

    local lbl = Instance.new("TextLabel")
    lbl.AutomaticSize = Enum.AutomaticSize.Y
    lbl.Size = UDim2.new(1, -6, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = Color3.fromRGB(210, 210, 210)
    lbl.Font = Enum.Font.Code
    lbl.TextSize = 11
    lbl.TextWrapped = true
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.TextYAlignment = Enum.TextYAlignment.Top
    lbl.Parent = output

    task.defer(function()
        output.CanvasPosition = Vector2.new(
            0,
            math.max(0, outLayout.AbsoluteContentSize.Y)
        )
    end)

    print("[Xero Emotes]", text)
end

--========================================================--
-- ROOTS
--========================================================--

local function roots()
    local result = {
        {
            Name = "ReplicatedStorage",
            Object = ReplicatedStorage
        },
        {
            Name = "PlayerGui",
            Object = playerGui
        }
    }

    local scripts = player:FindFirstChild("PlayerScripts")

    if scripts then
        table.insert(result, {
            Name = "PlayerScripts",
            Object = scripts
        })
    end

    local backpack = player:FindFirstChildOfClass("Backpack")

    if backpack then
        table.insert(result, {
            Name = "Backpack",
            Object = backpack
        })
    end

    local character =
        player.Character
        or Workspace:FindFirstChild(player.Name)

    if character then
        table.insert(result, {
            Name = "Character",
            Object = character
        })
    end

    return result
end

--========================================================--
-- SNAPSHOT
--========================================================--

local function createSnapshot()
    local snapshot = {}
    local total = 0

    for _, rootInfo in ipairs(roots()) do
        local root = rootInfo.Object

        local ok, descendants = pcall(function()
            return root:GetDescendants()
        end)

        if ok then
            for i, obj in ipairs(descendants) do
                local p = path(obj)

                snapshot[p] = {
                    Object = obj,
                    Signature = signature(obj),
                    Root = rootInfo.Name
                }

                total += 1

                if i % 700 == 0 then
                    task.wait()
                end
            end
        end
    end

    return snapshot, total
end

--========================================================--
-- MOSTRAR OBJETO
--========================================================--

local function describe(obj, prefix)
    if not obj then
        return
    end

    log("")
    log(prefix or "[OBJETO]")
    log("Clase: " .. obj.ClassName)
    log("Nombre: " .. obj.Name)
    log("Ruta: " .. path(obj))

    local props = inspectProperties(obj)

    for key, value in pairs(props) do
        log(tostring(key) .. ": " .. tostring(value))
    end
end

--========================================================--
-- CAPTURA ANTES
--========================================================--

beforeButton.MouseButton1Click:Connect(function()
    log("")
    log("========== CAPTURANDO ESTADO ANTES ==========")

    beforeSnapshot = {}

    local snapshot, total = createSnapshot()

    beforeSnapshot = snapshot

    log("Objetos capturados: " .. tostring(total))
    log("")
    log("AHORA ABRE EL MENÚ EMOTES.")
    log("Después presiona COMPARAR.")
end)

--========================================================--
-- COMPARAR
--========================================================--

compareButton.MouseButton1Click:Connect(function()
    if not next(beforeSnapshot) then
        log("Primero usa CAPTURAR ANTES.")
        return
    end

    log("")
    log("========== COMPARACIÓN ==========")

    local afterSnapshot = createSnapshot()

    local newCount = 0
    local changedCount = 0
    local interestingCount = 0

    for p, entry in pairs(afterSnapshot) do
        local previousEntry = beforeSnapshot[p]

        if not previousEntry then
            newCount += 1

            local obj = entry.Object

            if obj and (
                objectInteresting(obj)
                or interestingText(entry.Signature)
            ) then

                interestingCount += 1

                describe(
                    obj,
                    "[NUEVO · POSIBLE EMOTE]"
                )
            end

        elseif previousEntry.Signature ~= entry.Signature then
            changedCount += 1

            local obj = entry.Object

            if obj and (
                objectInteresting(obj)
                or interestingText(entry.Signature)
                or interestingText(previousEntry.Signature)
            ) then

                interestingCount += 1

                describe(
                    obj,
                    "[CAMBIÓ · POSIBLE EMOTE]"
                )
            end
        end
    end

    log("")
    log("RESUMEN:")
    log("Nuevos totales: " .. tostring(newCount))
    log("Modificados totales: " .. tostring(changedCount))
    log("Relacionados con emotes: " .. tostring(interestingCount))

    if interestingCount == 0 then
        log("")
        log("No apareció nada obvio.")
        log("Usa ahora BUSCAR ID.")
    end
end)

--========================================================--
-- BUSCAR EL EMOTE CONOCIDO
--========================================================--

searchButton.MouseButton1Click:Connect(function()
    log("")
    log("========== BUSCANDO ID " .. KNOWN_EMOTE_ID .. " ==========")

    local matches = 0

    for _, rootInfo in ipairs(roots()) do
        local ok, descendants = pcall(function()
            return rootInfo.Object:GetDescendants()
        end)

        if ok then
            for i, obj in ipairs(descendants) do
                local matched = false

                if interestingText(obj.Name) then
                    matched = lower(obj.Name):find(
                        KNOWN_EMOTE_ID,
                        1,
                        true
                    ) ~= nil
                end

                local props = inspectProperties(obj)

                for key, value in pairs(props) do
                    if lower(value):find(
                        KNOWN_EMOTE_ID,
                        1,
                        true
                    ) then

                        matched = true
                        break
                    end
                end

                if matched then
                    matches += 1

                    describe(
                        obj,
                        "[ID CONOCIDO ENCONTRADO]"
                    )

                    -- Mostrar contexto cercano
                    local parent = obj.Parent

                    if parent then
                        log("Padre: " .. path(parent))
                        log("Hijos del padre: " .. tostring(#parent:GetChildren()))
                    end
                end

                if i % 600 == 0 then
                    task.wait()
                end
            end
        end
    end

    log("")
    log("Coincidencias del ID: " .. tostring(matches))
end)

--========================================================--
-- WATCHER EN VIVO
--========================================================--

local function watchRoot(rootInfo)
    local connection = rootInfo.Object.DescendantAdded:Connect(function(obj)
        task.defer(function()
            if objectInteresting(obj) then
                describe(
                    obj,
                    "[LIVE · " .. rootInfo.Name .. "]"
                )
            else
                local props = inspectProperties(obj)

                for _, value in pairs(props) do
                    if interestingText(value) then
                        describe(
                            obj,
                            "[LIVE · " .. rootInfo.Name .. "]"
                        )
                        break
                    end
                end
            end
        end)
    end)

    table.insert(liveConnections, connection)
end

for _, rootInfo in ipairs(roots()) do
    watchRoot(rootInfo)
end

--========================================================--
-- OTROS BOTONES
--========================================================--

clearButton.MouseButton1Click:Connect(function()
    table.clear(reportLines)

    for _, child in ipairs(output:GetChildren()) do
        if child:IsA("TextLabel") then
            child:Destroy()
        end
    end

    log("Panel limpiado.")
end)

copyButton.MouseButton1Click:Connect(function()
    local report = table.concat(reportLines, "\n")

    if setclipboard then
        pcall(setclipboard, report)
        log("Reporte copiado.")
    else
        log("Tu ejecutor no tiene setclipboard.")
    end
end)

--========================================================--
-- DRAG
--========================================================--

local dragging = false
local dragStart
local originalPosition

title.Active = true

title.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then

        dragging = true
        dragStart = input.Position
        originalPosition = main.Position
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
            originalPosition.X.Scale,
            originalPosition.X.Offset + delta.X,
            originalPosition.Y.Scale,
            originalPosition.Y.Offset + delta.Y
        )
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then

        dragging = false
    end
end)

log("Xero Emote Scanner listo.")
log("")
log("1. CIERRA el menú EMOTES.")
log("2. Pulsa CAPTURAR ANTES.")
log("3. ABRE el menú EMOTES.")
log("4. Pulsa COMPARAR.")
log("5. Después pulsa BUSCAR ID.")
