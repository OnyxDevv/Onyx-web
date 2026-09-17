-- XeroHub | Texture Probe | Kev
-- Herramienta de prueba para inspeccionar texturas/meshes de armas y probar Negro mate.
-- No usa bucles permanentes.

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WEAPON_KEYS = {
    "gun", "pistol", "revolver", "uzi", "rifle", "sniper", "bow",
    "knife", "blade", "sword", "reaper", "arrow", "mod",
    "lightgun", "darknessgun", "kitsune", "bling", "dusk", "spider",
    "spectral", "stardust", "matcha", "eclipse", "infernal", "ghostbringer",
    "dragon", "harpon", "harpoon", "nail", "toxic", "galaxy", "gems", "water", "arma",
}

local function looksWeapon(name)
    name = string.lower(tostring(name or ""))
    for i = 1, #WEAPON_KEYS do
        if string.find(name, WEAPON_KEYS[i], 1, true) then return true end
    end
    return false
end

local player = Players.LocalPlayer
while not player do
    task.wait()
    player = Players.LocalPlayer
end

local BLACK = Color3.fromRGB(14, 14, 18)
local EDGE = Color3.fromRGB(28, 28, 34)
local VERT = Vector3.new(0.07, 0.07, 0.08)

local originals = setmetatable({}, {__mode = "k"})
local currentReport = nil

-- Textura personalizada de prueba (plantilla del cuchillo de lobby)
local CUSTOM_KNIFE_TEXTURE_ID = "122114929807745"


local function parentGui()
    local ok, gui = pcall(function()
        return gethui and gethui() or CoreGui
    end)
    if ok and gui then return gui end
    return player:WaitForChild("PlayerGui")
end

local old = parentGui():FindFirstChild("Xero_TextureProbe")
if old then old:Destroy() end

local function relativePath(root, object)
    if object == root then return root.Name end
    local parts = {}
    local cursor = object
    while cursor and cursor ~= root do
        table.insert(parts, 1, cursor.Name)
        cursor = cursor.Parent
    end
    return root.Name .. "/" .. table.concat(parts, "/")
end

local function contentId(value)
    local text = tostring(value or "")
    return text:match("rbxassetid://(%d+)")
        or text:match("[?&]id=(%d+)")
        or text:match("^%s*(%d+)%s*$")
end

local function safeRead(object, property)
    local ok, value = pcall(function() return object[property] end)
    if not ok then return nil end
    return tostring(value or "")
end

local function describeVisual(root, object)
    local item = {
        path = relativePath(root, object),
        class = object.ClassName,
        name = object.Name,
    }

    if object:IsA("MeshPart") then
        item.meshId = safeRead(object, "MeshId")
        item.meshAssetId = contentId(item.meshId)
        item.textureId = safeRead(object, "TextureID")
        item.textureAssetId = contentId(item.textureId)
    elseif object:IsA("SpecialMesh") then
        item.meshId = safeRead(object, "MeshId")
        item.meshAssetId = contentId(item.meshId)
        item.textureId = safeRead(object, "TextureId")
        item.textureAssetId = contentId(item.textureId)
    elseif object:IsA("Decal") or object:IsA("Texture") then
        item.texture = safeRead(object, "Texture")
        item.textureAssetId = contentId(item.texture)
    elseif object:IsA("SurfaceAppearance") then
        item.colorMap = safeRead(object, "ColorMap")
        item.colorMapAssetId = contentId(item.colorMap)
        item.normalMap = safeRead(object, "NormalMap")
        item.normalMapAssetId = contentId(item.normalMap)
        item.metalnessMap = safeRead(object, "MetalnessMap")
        item.metalnessMapAssetId = contentId(item.metalnessMap)
        item.roughnessMap = safeRead(object, "RoughnessMap")
        item.roughnessMapAssetId = contentId(item.roughnessMap)
    else
        return nil
    end

    return item
end

local function scanRoot(root, source)
    if not root then return nil end
    local report = {
        root = root.Name,
        class = root.ClassName,
        fullName = root:GetFullName(),
        source = source,
        visuals = {},
    }

    local function add(object)
        if object:IsA("MeshPart")
            or object:IsA("SpecialMesh")
            or object:IsA("Decal")
            or object:IsA("Texture")
            or object:IsA("SurfaceAppearance") then
            local data = describeVisual(root, object)
            if data then table.insert(report.visuals, data) end
        end
    end

    add(root)
    for _, object in ipairs(root:GetDescendants()) do add(object) end
    return report
end

local function topChild(container, object)
    if not container or not object then return nil end
    local cursor, previous = object, object
    while cursor and cursor ~= container do
        previous = cursor
        cursor = cursor.Parent
    end
    return cursor == container and previous or nil
end

local function candidateRoot(container, object, forceChildren)
    if not container or not object then return nil end
    if forceChildren then return topChild(container, object) end

    local cursor = object
    local candidate = nil
    while cursor and cursor ~= container do
        if cursor:IsA("Tool") or looksWeapon(cursor.Name) then
            candidate = cursor
        end
        cursor = cursor.Parent
    end
    return candidate
end

local function collectWeaponRoots(container, forceChildren)
    local result = {}
    if not container then return result end
    local seen = setmetatable({}, {__mode = "k"})

    local descendants = container:GetDescendants()
    for i = 1, #descendants do
        local root = candidateRoot(container, descendants[i], forceChildren)
        if root and not seen[root] then
            seen[root] = true
            table.insert(result, root)
        end
    end

    local children = container:GetChildren()
    for i = 1, #children do
        local root = candidateRoot(container, children[i], forceChildren)
        if root and not seen[root] then
            seen[root] = true
            table.insert(result, root)
        end
    end
    return result
end

local function scanRoots(roots, source)
    local weapons = {}
    for _, root in ipairs(roots or {}) do
        local report = scanRoot(root, source)
        if report and #report.visuals > 0 then table.insert(weapons, report) end
    end
    return weapons
end

local function scanEquipped()
    local char = player.Character
    local tool = char and char:FindFirstChildOfClass("Tool")
    if not tool then return {error = "No tienes un Tool equipado."} end
    return {
        generatedAt = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        scope = "equipped",
        count = 1,
        weapons = {scanRoot(tool, "character-equipped")},
    }
end

local function scanBackpack()
    local bag = player:FindFirstChildOfClass("Backpack")
    local weapons = scanRoots(collectWeaponRoots(bag, false), "backpack")
    return {
        generatedAt = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        scope = "backpack",
        count = #weapons,
        weapons = weapons,
    }
end

local function scanReplicatedWeapons()
    local skins = ReplicatedStorage:FindFirstChild("ReplicatedSkins")
    local weaponsFolder = skins and skins:FindFirstChild("Weapons")
    local weapons = scanRoots(collectWeaponRoots(weaponsFolder, true), "ReplicatedSkins/Weapons")
    return {
        generatedAt = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        scope = "replicated-weapons",
        count = #weapons,
        weapons = weapons,
    }
end

local function scanLobby()
    local char = player.Character
    local bag = player:FindFirstChildOfClass("Backpack")
    local skins = ReplicatedStorage:FindFirstChild("ReplicatedSkins")
    local weaponsFolder = skins and skins:FindFirstChild("Weapons")

    local characterWeapons = scanRoots(collectWeaponRoots(char, false), "character/lobby")
    local backpackWeapons = scanRoots(collectWeaponRoots(bag, false), "backpack")
    local replicatedWeapons = scanRoots(collectWeaponRoots(weaponsFolder, true), "ReplicatedSkins/Weapons")

    local combined = {}
    for _, list in ipairs({characterWeapons, backpackWeapons, replicatedWeapons}) do
        for _, item in ipairs(list) do table.insert(combined, item) end
    end

    return {
        generatedAt = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        scope = "lobby",
        count = #combined,
        characterCount = #characterWeapons,
        backpackCount = #backpackWeapons,
        replicatedCount = #replicatedWeapons,
        weapons = combined,
    }
end

local function remember(object)
    if originals[object] then return originals[object] end
    local data = {class = object.ClassName}
    local ok = pcall(function()
        if object:IsA("MeshPart") then
            data.TextureID = object.TextureID
            data.Color = object.Color
            data.Material = object.Material
            data.Reflectance = object.Reflectance
        elseif object:IsA("BasePart") then
            data.Color = object.Color
            data.Material = object.Material
            data.Reflectance = object.Reflectance
        elseif object:IsA("SpecialMesh") then
            data.TextureId = object.TextureId
            data.VertexColor = object.VertexColor
        elseif object:IsA("Decal") or object:IsA("Texture") then
            data.Texture = object.Texture
            data.Transparency = object.Transparency
        elseif object:IsA("SurfaceAppearance") then
            data.ColorMap = object.ColorMap
            data.NormalMap = object.NormalMap
            data.MetalnessMap = object.MetalnessMap
            data.RoughnessMap = object.RoughnessMap
        end
    end)
    if not ok then return nil end
    originals[object] = data
    return data
end

local function applyBlackObject(object)
    if not remember(object) then return end
    pcall(function()
        if object:IsA("MeshPart") then
            object.TextureID = ""
            object.Color = BLACK
            object.Material = Enum.Material.SmoothPlastic
            object.Reflectance = 0.08
        elseif object:IsA("BasePart") then
            object.Color = BLACK
            object.Material = Enum.Material.SmoothPlastic
            object.Reflectance = 0.08
        elseif object:IsA("SpecialMesh") then
            object.TextureId = ""
            object.VertexColor = VERT
        elseif object:IsA("Decal") or object:IsA("Texture") then
            object.Texture = ""
            object.Transparency = 1
        elseif object:IsA("SurfaceAppearance") then
            object.ColorMap = ""
            object.NormalMap = ""
            object.MetalnessMap = ""
            object.RoughnessMap = ""
        end
    end)
end

local function applyBlack(tool)
    if not tool then return false end
    applyBlackObject(tool)
    for _, object in ipairs(tool:GetDescendants()) do
        applyBlackObject(object)
    end
    local handle = tool:FindFirstChild("Handle", true)
    if handle and handle:IsA("BasePart") then
        pcall(function()
            handle.Color = EDGE
            handle.Reflectance = 0.12
        end)
    end
    return true
end

local function applyBlackRoots(roots)
    local changed = 0
    for _, root in ipairs(roots or {}) do
        if applyBlack(root) then changed = changed + 1 end
    end
    return changed
end

local function applyBlackLobby()
    local changed = 0
    changed = changed + applyBlackRoots(collectWeaponRoots(player.Character, false))
    changed = changed + applyBlackRoots(collectWeaponRoots(player:FindFirstChildOfClass("Backpack"), false))
    local skins = ReplicatedStorage:FindFirstChild("ReplicatedSkins")
    local weaponsFolder = skins and skins:FindFirstChild("Weapons")
    changed = changed + applyBlackRoots(collectWeaponRoots(weaponsFolder, true))
    return changed
end

local function applyXeroKnifeTexture()
    local char = player.Character
    if not char then
        return false, "No hay Character cargado."
    end

    local knifeFolder = char:FindFirstChild("KnifePartsFolder", true)
    if not knifeFolder then
        return false, "No encontré KnifePartsFolder en tu personaje."
    end

    local knifeDisplay = knifeFolder:FindFirstChild("KnifeDisplay", true)
    if not knifeDisplay then
        return false, "Encontré KnifePartsFolder, pero no KnifeDisplay."
    end

    local mesh = knifeDisplay:FindFirstChildWhichIsA("SpecialMesh", true)
    if not mesh then
        return false, "Encontré KnifeDisplay, pero no su SpecialMesh."
    end

    -- Guardamos el original para que el botón Restaurar siga funcionando.
    remember(mesh)

    local ok, err = pcall(function()
        -- Evita que una prueba previa de Negro mate deje la textura oscurecida.
        mesh.VertexColor = Vector3.new(1, 1, 1)
        mesh.TextureId = "rbxassetid://" .. CUSTOM_KNIFE_TEXTURE_ID
    end)

    if not ok then
        return false, tostring(err)
    end

    return true, mesh:GetFullName()
end

local function restore()
    for object, data in pairs(originals) do
        pcall(function()
            if object:IsA("MeshPart") then
                object.TextureID = data.TextureID
                object.Color = data.Color
                object.Material = data.Material
                object.Reflectance = data.Reflectance
            elseif object:IsA("BasePart") then
                object.Color = data.Color
                object.Material = data.Material
                object.Reflectance = data.Reflectance
            elseif object:IsA("SpecialMesh") then
                object.TextureId = data.TextureId
                object.VertexColor = data.VertexColor
            elseif object:IsA("Decal") or object:IsA("Texture") then
                object.Texture = data.Texture
                object.Transparency = data.Transparency
            elseif object:IsA("SurfaceAppearance") then
                object.ColorMap = data.ColorMap
                object.NormalMap = data.NormalMap
                object.MetalnessMap = data.MetalnessMap
                object.RoughnessMap = data.RoughnessMap
            end
        end)
        originals[object] = nil
    end
end

-- UI -------------------------------------------------------------------------

local gui = Instance.new("ScreenGui")
gui.Name = "Xero_TextureProbe"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = parentGui()

local frame = Instance.new("Frame")
frame.Size = UDim2.fromOffset(620, 468)
frame.Position = UDim2.new(0.5, -310, 0.5, -234)
frame.BackgroundColor3 = Color3.fromRGB(12, 12, 15)
frame.BorderSizePixel = 0
frame.Parent = gui
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 16)

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(45, 45, 52)
stroke.Thickness = 1
stroke.Parent = frame

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -50, 0, 48)
title.Position = UDim2.fromOffset(18, 8)
title.BackgroundTransparency = 1
title.Text = "XERO | TEXTURE PROBE"
title.TextColor3 = Color3.fromRGB(245, 245, 245)
title.Font = Enum.Font.GothamBold
title.TextSize = 18
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = frame

local sub = Instance.new("TextLabel")
sub.Size = UDim2.new(1, -36, 0, 34)
sub.Position = UDim2.fromOffset(18, 46)
sub.BackgroundTransparency = 1
sub.Text = "Escanea texturas y prueba la skin XeroHub del cuchillo. By Kev"
sub.TextColor3 = Color3.fromRGB(155, 155, 165)
sub.Font = Enum.Font.Gotham
sub.TextSize = 11
sub.TextXAlignment = Enum.TextXAlignment.Left
sub.Parent = frame

local close = Instance.new("TextButton")
close.Size = UDim2.fromOffset(30, 30)
close.Position = UDim2.new(1, -42, 0, 14)
close.Text = "×"
close.TextSize = 22
close.TextColor3 = Color3.fromRGB(220, 220, 220)
close.BackgroundColor3 = Color3.fromRGB(28, 28, 34)
close.BorderSizePixel = 0
close.Parent = frame
Instance.new("UICorner", close).CornerRadius = UDim.new(0, 8)
close.MouseButton1Click:Connect(function()
    restore()
    gui:Destroy()
end)

local buttonRow = Instance.new("Frame")
buttonRow.Size = UDim2.new(1, -36, 0, 102)
buttonRow.Position = UDim2.fromOffset(18, 84)
buttonRow.BackgroundTransparency = 1
buttonRow.Parent = frame

local layout = Instance.new("UIGridLayout")
layout.CellPadding = UDim2.fromOffset(8, 8)
layout.CellSize = UDim2.new(0.25, -6, 0, 30)
layout.FillDirectionMaxCells = 4
layout.Parent = buttonRow

local output = Instance.new("TextBox")
output.Size = UDim2.new(1, -36, 1, -208)
output.Position = UDim2.fromOffset(18, 190)
output.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
output.BorderSizePixel = 0
output.TextColor3 = Color3.fromRGB(220, 220, 225)
output.Font = Enum.Font.Code
output.TextSize = 11
output.TextXAlignment = Enum.TextXAlignment.Left
output.TextYAlignment = Enum.TextYAlignment.Top
output.TextWrapped = false
output.MultiLine = true
output.ClearTextOnFocus = false
output.TextEditable = false
output.Text = "En lobby usa «Escanear lobby»: revisa Character + Backpack + ReplicatedSkins/Weapons."
output.Parent = frame
Instance.new("UICorner", output).CornerRadius = UDim.new(0, 10)

local pad = Instance.new("UIPadding")
pad.PaddingTop = UDim.new(0, 10)
pad.PaddingBottom = UDim.new(0, 10)
pad.PaddingLeft = UDim.new(0, 10)
pad.PaddingRight = UDim.new(0, 10)
pad.Parent = output

local function button(text, callback)
    local b = Instance.new("TextButton")
    b.Text = text
    b.TextColor3 = Color3.fromRGB(235, 235, 240)
    b.Font = Enum.Font.GothamMedium
    b.TextSize = 11
    b.BackgroundColor3 = Color3.fromRGB(28, 28, 34)
    b.BorderSizePixel = 0
    b.Parent = buttonRow
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
    b.MouseButton1Click:Connect(callback)
    return b
end

local function showReport(report)
    currentReport = report
    local ok, encoded = pcall(function()
        return HttpService:JSONEncode(report)
    end)
    output.Text = ok and encoded or ("No se pudo convertir el reporte: " .. tostring(encoded))
end

button("Escanear lobby", function()
    showReport(scanLobby())
end)

button("Escanear equipada", function()
    showReport(scanEquipped())
end)

button("Escanear mochila", function()
    showReport(scanBackpack())
end)

button("Escanear Replicated", function()
    showReport(scanReplicatedWeapons())
end)

button("XeroHub cuchillo", function()
    local ok, info = applyXeroKnifeTexture()
    if ok then
        output.Text = "Textura XeroHub aplicada al cuchillo del lobby.\n\nID: " .. CUSTOM_KNIFE_TEXTURE_ID .. "\nRuta: " .. tostring(info) .. "\n\nSi no aparece, revisa que el asset ya haya terminado moderación."
    else
        output.Text = "No se pudo aplicar la textura XeroHub.\n\n" .. tostring(info)
    end
end)

button("Negro lobby", function()
    local changed = applyBlackLobby()
    output.Text = "Negro mate aplicado a " .. tostring(changed) .. " raíz/raíces detectadas en Character + Backpack + ReplicatedSkins.\n\nPulsa Restaurar para volver al original."
end)

button("Restaurar", function()
    restore()
    output.Text = "Valores originales restaurados."
end)

button("Copiar JSON", function()
    if not currentReport then
        output.Text = "Primero genera un reporte."
        return
    end
    local encoded = HttpService:JSONEncode(currentReport)
    if setclipboard then
        pcall(setclipboard, encoded)
        output.Text = "Reporte copiado al portapapeles.\n\n" .. encoded
    else
        output.Text = "Tu ejecutor no tiene setclipboard.\n\n" .. encoded
    end
end)

button("Guardar JSON", function()
    if not currentReport then
        output.Text = "Primero genera un reporte."
        return
    end
    if not writefile then
        output.Text = "Tu ejecutor no soporta writefile."
        return
    end

    if makefolder then
        if not isfolder or not isfolder("XeroHub") then pcall(makefolder, "XeroHub") end
        if not isfolder or not isfolder("XeroHub/TextureScans") then pcall(makefolder, "XeroHub/TextureScans") end
    end

    local name = "XeroHub/TextureScans/scan_" .. tostring(os.time()) .. ".json"
    local ok, err = pcall(writefile, name, HttpService:JSONEncode(currentReport))
    output.Text = ok and ("Guardado en:\n" .. name) or ("No se pudo guardar:\n" .. tostring(err))
end)

button("Limpiar", function()
    currentReport = nil
    output.Text = ""
end)

button("Cerrar", function()
    restore()
    gui:Destroy()
end)

-- Arrastre simple
local UIS = game:GetService("UserInputService")
local dragging, dragStart, startPos
title.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = input
        dragStart = input.Position
        startPos = frame.Position
    end
end)
title.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        dragging = input
    end
end)
UIS.InputChanged:Connect(function(input)
    if dragging and input == dragging then
        local delta = input.Position - dragStart
        frame.Position = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + delta.X,
            startPos.Y.Scale, startPos.Y.Offset + delta.Y
        )
    end
end)
UIS.InputEnded:Connect(function(input)
    if input == dragging then dragging = nil end
end)
