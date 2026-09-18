local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer
while not LocalPlayer do task.wait() LocalPlayer = Players.LocalPlayer end

-- ==========================================
-- XEROHUB TEXTURES · DEFAULT WEAPONS ONLY
-- Official textures: auto-listed from GitHub folders (NO catalog.json)
-- User textures: Roblox Asset ID
-- ==========================================
local TEXTURE_API = {
    knife = "https://api.github.com/repos/OnyxDevv/Onyx-web/contents/textures/default/knife?ref=main",
    gun = "https://api.github.com/repos/OnyxDevv/Onyx-web/contents/textures/default/gun?ref=main",
}
local CACHE_FOLDER = "XeroHub/Textures"

local ORIGINAL = {
    knifeTexture = "121944805",
    gunTexture = "91723031",
    knifeMesh = "121944778",
    gunMesh = "10881397417",
}

local assetLoader = getcustomasset
    or getsynasset
    or (syn and (syn.getcustomasset or syn.getsynasset))

local state = {
    target = "knife", -- knife / gun
    source = "official", -- official / custom
    enabled = {knife = false, gun = false},
    activeTexture = {knife = nil, gun = nil},
    selectedIndex = {knife = 1, gun = 1},
    library = {knife = {}, gun = {}},
    librarySource = "GitHub",
    Saved = setmetatable({}, {__mode = "k"}),
    Connections = {},
}

local function assetDigits(value)
    return tostring(value or ""):match("(%d+)") or ""
end

local function safeName(value)
    value = tostring(value or "texture"):gsub("[^%w%-_]+", "_")
    return value:sub(1, 64)
end

local function track(conn)
    state.Connections[#state.Connections + 1] = conn
    return conn
end

local function disconnectAll()
    for i = #state.Connections, 1, -1 do
        pcall(function() state.Connections[i]:Disconnect() end)
        state.Connections[i] = nil
    end
end

local function ensureFolder()
    if type(makefolder) ~= "function" then return false end
    if not isfolder or not isfolder("XeroHub") then pcall(makefolder, "XeroHub") end
    if not isfolder or not isfolder(CACHE_FOLDER) then pcall(makefolder, CACHE_FOLDER) end
    return true
end

local function requestUrl(url)
    local req = (syn and syn.request) or (http and http.request) or http_request or request
    if req then
        local ok, response = pcall(function()
            return req({
                Url = url,
                Method = "GET",
                Headers = { ["User-Agent"] = "XeroHub-Textures/1.0" }
            })
        end)
        if ok and type(response) == "table" then
            local status = tonumber(response.StatusCode or response.Status or 0) or 0
            local body = response.Body or response.body
            if status == 0 and response.Success == true then status = 200 end
            if status >= 200 and status < 300 and type(body) == "string" then
                return body, status
            end
        end
    end
    local ok, body = pcall(function() return game:HttpGet(url) end)
    if ok and type(body) == "string" then return body, 200 end
    return nil, 0
end

local function prettyTextureName(fileName)
    local name = tostring(fileName or "")
    name = name:gsub("%.[Pp][Nn][Gg]$", "")
    name = name:gsub("[_%-]+", " "):gsub("%s+", " ")
    name = name:match("^%s*(.-)%s*$") or name
    name = name:gsub("%S+", function(word)
        return word:sub(1,1):upper() .. word:sub(2):lower()
    end)
    return name ~= "" and name or "Textura"
end

local function fetchTextureFolder(weapon)
    local url = TEXTURE_API[weapon]
    if not url then return {}, "Ruta inválida" end

    local body, status = requestUrl(url)
    if not body or status < 200 or status >= 300 then
        return {}, "GitHub HTTP " .. tostring(status)
    end

    local ok, decoded = pcall(function() return HttpService:JSONDecode(body) end)
    if not ok or type(decoded) ~= "table" then
        return {}, "Respuesta inválida de GitHub"
    end

    local list = {}
    for _, item in ipairs(decoded) do
        if type(item) == "table"
            and item.type == "file"
            and type(item.name) == "string"
            and string.lower(item.name):match("%.png$")
            and type(item.download_url) == "string"
            and item.download_url ~= "" then
            list[#list + 1] = {
                name = prettyTextureName(item.name),
                fileName = item.name,
                url = item.download_url,
                sha = tostring(item.sha or ""),
            }
        end
    end

    table.sort(list, function(a, b)
        return string.lower(a.name) < string.lower(b.name)
    end)
    return list, nil
end

local function loadLibrary()
    local knife, knifeErr = fetchTextureFolder("knife")
    local gun, gunErr = fetchTextureFolder("gun")
    state.library.knife = knife
    state.library.gun = gun
    state.selectedIndex.knife = math.min(state.selectedIndex.knife or 1, math.max(#knife, 1))
    state.selectedIndex.gun = math.min(state.selectedIndex.gun or 1, math.max(#gun, 1))
    return (#knife + #gun), knifeErr or gunErr
end

local function downloadOfficial(entry, weapon)
    if type(entry) ~= "table" or type(entry.url) ~= "string" or entry.url == "" then
        return nil, "Entrada de GitHub inválida"
    end
    if type(assetLoader) ~= "function" then
        return nil, "Tu ejecutor no soporta getcustomasset/getsynasset"
    end
    if type(writefile) ~= "function" then
        return nil, "Tu ejecutor no permite guardar PNGs con writefile"
    end

    ensureFolder()
    local token = tostring(entry.sha or ""):gsub("[^%w]", ""):sub(1, 12)
    if token == "" then token = safeName(entry.fileName or entry.name or weapon) end
    local fileName = safeName(weapon .. "_" .. token) .. ".png"
    local path = CACHE_FOLDER .. "/" .. fileName

    local cached = type(isfile) == "function" and isfile(path)
    if not cached then
        local body, status = requestUrl(entry.url)
        if status < 200 or status >= 300 or type(body) ~= "string" or #body < 64 then
            return nil, "No se pudo descargar el PNG de GitHub"
        end
        local ok = pcall(writefile, path, body)
        if not ok then return nil, "No se pudo guardar el PNG" end
    end

    local ok, asset = pcall(assetLoader, path)
    if ok and type(asset) == "string" and asset ~= "" then
        return asset, "GitHub PNG"
    end
    return nil, "El ejecutor no pudo registrar el PNG local"
end

local function saveOriginal(obj, key)
    if not obj or state.Saved[obj] then return end
    if obj:IsA("SpecialMesh") then
        state.Saved[obj] = {Class = "SpecialMesh", Key = key, TextureId = obj.TextureId}
    elseif obj:IsA("MeshPart") then
        state.Saved[obj] = {Class = "MeshPart", Key = key, TextureID = obj.TextureID}
    elseif obj:IsA("SurfaceAppearance") then
        state.Saved[obj] = {Class = "SurfaceAppearance", Key = key, ColorMap = obj.ColorMap}
    end
end

local function restoreKey(key)
    for obj, data in pairs(state.Saved) do
        if data and data.Key == key and obj and obj.Parent then
            pcall(function()
                if data.Class == "SpecialMesh" then obj.TextureId = data.TextureId or ""
                elseif data.Class == "MeshPart" then obj.TextureID = data.TextureID or ""
                elseif data.Class == "SurfaceAppearance" then obj.ColorMap = data.ColorMap or "" end
            end)
        end
    end
end

local function isKnife(obj)
    if not obj then return false end
    local name = string.lower(tostring(obj.Name or ""))
    if name:find("knife", 1, true) or name:find("blade", 1, true) then return true end
    local tool = obj:FindFirstAncestorOfClass("Tool")
    if tool then
        local n = string.lower(tool.Name)
        if n:find("knife", 1, true) or n:find("blade", 1, true) then return true end
    end
    return obj:FindFirstAncestor("KnifePartsFolder") ~= nil
end

local function isGun(obj)
    if not obj then return false end
    local name = string.lower(tostring(obj.Name or ""))
    if name:find("gun", 1, true) or name:find("pistol", 1, true) or name:find("revolver", 1, true) then return true end
    local tool = obj:FindFirstAncestorOfClass("Tool")
    if tool then
        local n = string.lower(tool.Name)
        if n:find("gun", 1, true) or n:find("pistol", 1, true) or n:find("revolver", 1, true) then return true end
    end
    return obj:FindFirstAncestor("GunPartsFolder") ~= nil
end

local function applyObject(obj, weapon)
    if not state.enabled[weapon] or not obj then return false end
    local texture = state.activeTexture[weapon]
    if type(texture) ~= "string" or texture == "" then return false end

    local changed = false
    pcall(function()
        if weapon == "knife" then
            if obj:IsA("SpecialMesh") then
                local tex, mesh = assetDigits(obj.TextureId), assetDigits(obj.MeshId)
                if tex == ORIGINAL.knifeTexture or mesh == ORIGINAL.knifeMesh or isKnife(obj) then
                    saveOriginal(obj, "knife")
                    obj.TextureId = texture
                    changed = true
                end
            elseif obj:IsA("MeshPart") then
                local tex, mesh = assetDigits(obj.TextureID), assetDigits(obj.MeshId)
                if tex == ORIGINAL.knifeTexture or mesh == ORIGINAL.knifeMesh or isKnife(obj) then
                    saveOriginal(obj, "knife")
                    obj.TextureID = texture
                    changed = true
                end
            elseif obj:IsA("SurfaceAppearance") and isKnife(obj) then
                saveOriginal(obj, "knife")
                obj.ColorMap = texture
                changed = true
            end
        else
            if obj:IsA("SpecialMesh") then
                local tex, mesh = assetDigits(obj.TextureId), assetDigits(obj.MeshId)
                if tex == ORIGINAL.gunTexture or mesh == ORIGINAL.gunMesh or isGun(obj) then
                    saveOriginal(obj, "gun")
                    obj.TextureId = texture
                    changed = true
                end
            elseif obj:IsA("MeshPart") then
                local tex, mesh = assetDigits(obj.TextureID), assetDigits(obj.MeshId)
                if tex == ORIGINAL.gunTexture or mesh == ORIGINAL.gunMesh or isGun(obj) then
                    saveOriginal(obj, "gun")
                    obj.TextureID = texture
                    changed = true
                end
            elseif obj:IsA("SurfaceAppearance") and isGun(obj) then
                saveOriginal(obj, "gun")
                obj.ColorMap = texture
                changed = true
            end
        end
    end)
    return changed
end

local function processRoot(root)
    if not root then return end
    applyObject(root, "knife")
    applyObject(root, "gun")
    for _, d in ipairs(root:GetDescendants()) do
        applyObject(d, "knife")
        applyObject(d, "gun")
    end
end

local function scanAll()
    local char = LocalPlayer.Character
    if char then processRoot(char) end
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    if backpack then processRoot(backpack) end
end

local function rebuildHooks()
    disconnectAll()

    local function hookRoot(root)
        if not root then return end
        track(root.DescendantAdded:Connect(function(obj)
            task.defer(function()
                applyObject(obj, "knife")
                applyObject(obj, "gun")
            end)
        end))
    end

    hookRoot(LocalPlayer.Character)
    hookRoot(LocalPlayer:FindFirstChild("Backpack"))

    track(LocalPlayer.CharacterAdded:Connect(function(char)
        task.wait(0.15)
        processRoot(char)
        hookRoot(char)
    end))

    track(LocalPlayer.ChildAdded:Connect(function(obj)
        if obj.Name == "Backpack" then
            task.wait(0.05)
            processRoot(obj)
            hookRoot(obj)
        end
    end))
end

local function notify(text)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "XeroHub Texturas",
            Text = text,
            Duration = 4,
        })
    end)
end

-- Load GitHub folders once on startup. Each PNG becomes a texture automatically.
loadLibrary()

-- ==========================================
-- SIMPLE TEST UI
-- ==========================================
local guiParent = LocalPlayer:WaitForChild("PlayerGui")
local old = guiParent:FindFirstChild("XeroHub_TextureFolderTest")
if old then old:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name = "XeroHub_TextureFolderTest"
gui.ResetOnSpawn = false
gui.Parent = guiParent

local frame = Instance.new("Frame")
frame.Size = UDim2.fromOffset(320, 478)
frame.Position = UDim2.new(1, -335, 0.5, -239)
frame.BackgroundColor3 = Color3.fromRGB(12,12,16)
frame.BorderSizePixel = 0
frame.Parent = gui
Instance.new("UICorner", frame).CornerRadius = UDim.new(0,16)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1,-20,0,36)
title.Position = UDim2.fromOffset(10,8)
title.BackgroundTransparency = 1
title.Text = "XERO | TEXTURAS"
title.TextColor3 = Color3.fromRGB(245,245,245)
title.Font = Enum.Font.GothamBold
title.TextSize = 21
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = frame

local subtitle = Instance.new("TextLabel")
subtitle.Size = UDim2.new(1,-20,0,42)
subtitle.Position = UDim2.fromOffset(10,43)
subtitle.BackgroundTransparency = 1
subtitle.Text = "Solo armas default por ahora.\nLos PNG aparecen solos desde GitHub."
subtitle.TextWrapped = true
subtitle.TextColor3 = Color3.fromRGB(170,170,175)
subtitle.Font = Enum.Font.Gotham
subtitle.TextSize = 12
subtitle.TextXAlignment = Enum.TextXAlignment.Left
subtitle.TextYAlignment = Enum.TextYAlignment.Top
subtitle.Parent = frame

local targetLabel = Instance.new("TextLabel")
targetLabel.Size = UDim2.new(1,-20,0,24)
targetLabel.Position = UDim2.fromOffset(10,92)
targetLabel.BackgroundTransparency = 1
targetLabel.Text = "Arma default: Cuchillo"
targetLabel.TextColor3 = Color3.fromRGB(230,230,230)
targetLabel.Font = Enum.Font.GothamMedium
targetLabel.TextSize = 13
targetLabel.TextXAlignment = Enum.TextXAlignment.Left
targetLabel.Parent = frame

local selectedLabel = Instance.new("TextLabel")
selectedLabel.Size = UDim2.new(1,-20,0,36)
selectedLabel.Position = UDim2.fromOffset(10,120)
selectedLabel.BackgroundTransparency = 1
selectedLabel.TextColor3 = Color3.fromRGB(190,190,190)
selectedLabel.Font = Enum.Font.Gotham
selectedLabel.TextSize = 12
selectedLabel.TextWrapped = true
selectedLabel.TextXAlignment = Enum.TextXAlignment.Left
selectedLabel.Parent = frame

local function currentList()
    local list = state.library[state.target]
    return type(list) == "table" and list or {}
end

local function currentEntry()
    local list = currentList()
    local total = #list
    if total == 0 then return nil, 0, 0 end
    local idx = state.selectedIndex[state.target] or 1
    if idx < 1 then idx = 1 end
    if idx > total then idx = total end
    state.selectedIndex[state.target] = idx
    return list[idx], idx, total
end

local function refreshText()
    targetLabel.Text = "Arma default: " .. (state.target == "knife" and "Cuchillo" or "Pistola")
    local entry, idx, total = currentEntry()
    if entry then
        selectedLabel.Text = "GitHub: " .. tostring(entry.name) .. "  [" .. idx .. "/" .. total .. "]"
    else
        selectedLabel.Text = "GitHub: no hay PNGs en esta carpeta"
    end
end

local function makeButton(text, y, callback, width, x)
    local b = Instance.new("TextButton")
    b.Size = UDim2.fromOffset(width or 300, 34)
    b.Position = UDim2.fromOffset(x or 10, y)
    b.BackgroundColor3 = Color3.fromRGB(25,25,32)
    b.TextColor3 = Color3.fromRGB(255,255,255)
    b.Font = Enum.Font.GothamMedium
    b.TextSize = 13
    b.Text = text
    b.Parent = frame
    Instance.new("UICorner", b).CornerRadius = UDim.new(0,11)
    b.MouseButton1Click:Connect(callback)
    return b
end

makeButton("Cambiar arma default", 160, function()
    state.target = state.target == "knife" and "gun" or "knife"
    refreshText()
end)

makeButton("<", 202, function()
    local _, idx, total = currentEntry()
    if total == 0 then return notify("No hay PNGs para esta arma") end
    idx = idx - 1
    if idx < 1 then idx = total end
    state.selectedIndex[state.target] = idx
    refreshText()
end, 54, 10)

makeButton("Siguiente textura >", 202, function()
    local _, idx, total = currentEntry()
    if total == 0 then return notify("No hay PNGs para esta arma") end
    idx = idx + 1
    if idx > total then idx = 1 end
    state.selectedIndex[state.target] = idx
    refreshText()
end, 236, 74)

makeButton("Aplicar textura de GitHub", 244, function()
    local entry = currentEntry()
    if not entry then return notify("Sube al menos un PNG a la carpeta de esta arma") end
    local texture, source = downloadOfficial(entry, state.target)
    if not texture then return notify(source or "No se pudo cargar la textura") end
    state.activeTexture[state.target] = texture
    state.enabled[state.target] = true
    scanAll()
    rebuildHooks()
    notify("Aplicada a " .. (state.target == "knife" and "cuchillo default" or "pistola default") .. " · " .. source)
end)

makeButton("Actualizar carpetas de GitHub", 286, function()
    local total, err = loadLibrary()
    refreshText()
    if total > 0 then
        notify("GitHub actualizado · " .. tostring(total) .. " textura(s)")
    else
        notify(err or "No se encontraron PNGs")
    end
end)

local custom = Instance.new("TextBox")
custom.Size = UDim2.new(1,-20,0,36)
custom.Position = UDim2.fromOffset(10,336)
custom.BackgroundColor3 = Color3.fromRGB(19,19,25)
custom.TextColor3 = Color3.fromRGB(245,245,245)
custom.PlaceholderColor3 = Color3.fromRGB(125,125,135)
custom.PlaceholderText = "Asset ID personalizado"
custom.Text = ""
custom.ClearTextOnFocus = false
custom.Font = Enum.Font.Gotham
custom.TextSize = 13
custom.Parent = frame
Instance.new("UICorner", custom).CornerRadius = UDim.new(0,11)

makeButton("Aplicar ID personalizado", 380, function()
    local id = assetDigits(custom.Text)
    if id == "" then return notify("Introduce un Asset ID válido") end
    state.activeTexture[state.target] = "rbxassetid://" .. id
    state.enabled[state.target] = true
    scanAll()
    rebuildHooks()
    notify("Textura personalizada aplicada al arma default")
end)

makeButton("Restaurar arma seleccionada", 422, function()
    local key = state.target
    state.enabled[key] = false
    state.activeTexture[key] = nil
    restoreKey(key)
    rebuildHooks()
    notify("Textura original restaurada")
end)

refreshText()

-- Drag
local UIS = game:GetService("UserInputService")
local dragging, dragInput, dragStart, startPos
frame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = frame.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then dragging = false end
        end)
    end
end)
frame.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then dragInput = input end
end)
UIS.InputChanged:Connect(function(input)
    if dragging and input == dragInput then
        local delta = input.Position - dragStart
        frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

notify("Texturas GitHub cargadas · solo armas default")
