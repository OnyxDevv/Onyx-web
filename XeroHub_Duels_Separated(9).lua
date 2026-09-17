local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
while not LocalPlayer do task.wait() LocalPlayer = Players.LocalPlayer end

local KNIFE_TEXTURE_ID = "rbxassetid://122114929807745"
local GUN_TEXTURE_ID = "rbxassetid://77978665403713"

local ORIGINAL_KNIFE_TEXTURE = "121944805"
local ORIGINAL_GUN_TEXTURE = "91723031"
local ORIGINAL_KNIFE_MESH = "121944778"
local ORIGINAL_GUN_MESH = "10881397417"

local state = {
    KnifeEnabled = false,
    GunEnabled = false,
    Saved = setmetatable({}, {__mode = "k"}),
    Connections = {},
}

local function assetDigits(value)
    return tostring(value or ""):match("(%d+)") or ""
end

local function lowerContains(text, part)
    return string.find(string.lower(tostring(text or "")), string.lower(part), 1, true) ~= nil
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
                if data.Class == "SpecialMesh" then
                    obj.TextureId = data.TextureId or ""
                elseif data.Class == "MeshPart" then
                    obj.TextureID = data.TextureID or ""
                elseif data.Class == "SurfaceAppearance" then
                    obj.ColorMap = data.ColorMap or ""
                end
            end)
        end
    end
end

local function shouldTreatAsKnife(obj)
    local name = string.lower(tostring(obj.Name or ""))
    if name:find("knife", 1, true) or name:find("blade", 1, true) then return true end
    local anc = obj:FindFirstAncestorOfClass("Tool")
    if anc then
        local tname = string.lower(anc.Name)
        return tname:find("knife", 1, true) or tname:find("blade", 1, true)
    end
    return obj:FindFirstAncestor("KnifePartsFolder") ~= nil
end

local function shouldTreatAsGun(obj)
    local name = string.lower(tostring(obj.Name or ""))
    if name:find("gun", 1, true) or name:find("pistol", 1, true) or name:find("revolver", 1, true) then return true end
    local anc = obj:FindFirstAncestorOfClass("Tool")
    if anc then
        local tname = string.lower(anc.Name)
        return tname:find("gun", 1, true) or tname:find("pistol", 1, true) or tname:find("revolver", 1, true)
    end
    return obj:FindFirstAncestor("GunPartsFolder") ~= nil
end

local function applyKnifeToObject(obj)
    if not state.KnifeEnabled or not obj then return false end
    local changed = false
    pcall(function()
        if obj:IsA("SpecialMesh") then
            local tex = assetDigits(obj.TextureId)
            local mesh = assetDigits(obj.MeshId)
            if tex == ORIGINAL_KNIFE_TEXTURE or mesh == ORIGINAL_KNIFE_MESH or shouldTreatAsKnife(obj) then
                saveOriginal(obj, "knife")
                obj.TextureId = KNIFE_TEXTURE_ID
                changed = true
            end
        elseif obj:IsA("MeshPart") then
            local tex = assetDigits(obj.TextureID)
            local mesh = assetDigits(obj.MeshId)
            if tex == ORIGINAL_KNIFE_TEXTURE or mesh == ORIGINAL_KNIFE_MESH or shouldTreatAsKnife(obj) then
                saveOriginal(obj, "knife")
                obj.TextureID = KNIFE_TEXTURE_ID
                changed = true
            end
        elseif obj:IsA("SurfaceAppearance") then
            if shouldTreatAsKnife(obj) then
                saveOriginal(obj, "knife")
                obj.ColorMap = KNIFE_TEXTURE_ID
                changed = true
            end
        end
    end)
    return changed
end

local function applyGunToObject(obj)
    if not state.GunEnabled or not obj then return false end
    local changed = false
    pcall(function()
        if obj:IsA("SpecialMesh") then
            local tex = assetDigits(obj.TextureId)
            local mesh = assetDigits(obj.MeshId)
            if tex == ORIGINAL_GUN_TEXTURE or mesh == ORIGINAL_GUN_MESH or shouldTreatAsGun(obj) then
                saveOriginal(obj, "gun")
                obj.TextureId = GUN_TEXTURE_ID
                changed = true
            end
        elseif obj:IsA("MeshPart") then
            local tex = assetDigits(obj.TextureID)
            local mesh = assetDigits(obj.MeshId)
            if tex == ORIGINAL_GUN_TEXTURE or mesh == ORIGINAL_GUN_MESH or shouldTreatAsGun(obj) then
                saveOriginal(obj, "gun")
                obj.TextureID = GUN_TEXTURE_ID
                changed = true
            end
        elseif obj:IsA("SurfaceAppearance") then
            if shouldTreatAsGun(obj) then
                saveOriginal(obj, "gun")
                obj.ColorMap = GUN_TEXTURE_ID
                changed = true
            end
        end
    end)
    return changed
end

local function processRoot(root)
    if not root then return end
    applyKnifeToObject(root)
    applyGunToObject(root)
    for _, d in ipairs(root:GetDescendants()) do
        applyKnifeToObject(d)
        applyGunToObject(d)
    end
end

local function scanAll()
    local character = LocalPlayer.Character
    if character then processRoot(character) end
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    if backpack then processRoot(backpack) end
end

local function showMessage(text)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "XeroHub Texturas",
            Text = text,
            Duration = 4,
        })
    end)
end

local function rebuildHooks()
    disconnectAll()

    track(LocalPlayer.CharacterAdded:Connect(function(char)
        task.wait(0.15)
        processRoot(char)
        track(char.DescendantAdded:Connect(function(obj)
            task.defer(function()
                applyKnifeToObject(obj)
                applyGunToObject(obj)
            end)
        end))
    end))

    local char = LocalPlayer.Character
    if char then
        track(char.DescendantAdded:Connect(function(obj)
            task.defer(function()
                applyKnifeToObject(obj)
                applyGunToObject(obj)
            end)
        end))
    end

    local backpack = LocalPlayer:FindFirstChild("Backpack")
    if backpack then
        track(backpack.DescendantAdded:Connect(function(obj)
            task.defer(function()
                applyKnifeToObject(obj)
                applyGunToObject(obj)
            end)
        end))
    end

    track(LocalPlayer.ChildAdded:Connect(function(obj)
        if obj.Name == "Backpack" then
            task.wait(0.05)
            track(obj.DescendantAdded:Connect(function(d)
                task.defer(function()
                    applyKnifeToObject(d)
                    applyGunToObject(d)
                end)
            end))
            processRoot(obj)
        end
    end))
end

-- GUI
local guiParent = LocalPlayer:WaitForChild("PlayerGui")
local old = guiParent:FindFirstChild("XeroHub_TextureProbe")
if old then old:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name = "XeroHub_TextureProbe"
gui.ResetOnSpawn = false
gui.Parent = guiParent

local frame = Instance.new("Frame")
frame.Size = UDim2.fromOffset(270, 260)
frame.Position = UDim2.new(1, -285, 0.5, -130)
frame.BackgroundColor3 = Color3.fromRGB(12, 12, 16)
frame.BorderSizePixel = 0
frame.Parent = gui
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 16)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -20, 0, 40)
title.Position = UDim2.fromOffset(10, 8)
title.BackgroundTransparency = 1
title.Text = "XERO | TEXTURAS"
title.TextColor3 = Color3.fromRGB(245,245,245)
title.Font = Enum.Font.GothamBold
title.TextSize = 22
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = frame

local info = Instance.new("TextLabel")
info.Size = UDim2.new(1, -20, 0, 86)
info.Position = UDim2.fromOffset(10, 44)
info.BackgroundTransparency = 1
info.TextWrapped = true
info.TextYAlignment = Enum.TextYAlignment.Top
info.TextXAlignment = Enum.TextXAlignment.Left
info.TextColor3 = Color3.fromRGB(190,190,190)
info.Font = Enum.Font.Gotham
info.TextSize = 13
info.Text = "Cuchillo: 122114929807745\nPistola: 77978665403713\nAplica cadera + equipada."
info.Parent = frame

local function makeButton(text, y, callback)
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(1, -20, 0, 34)
    button.Position = UDim2.fromOffset(10, y)
    button.BackgroundColor3 = Color3.fromRGB(25, 25, 32)
    button.TextColor3 = Color3.fromRGB(255,255,255)
    button.Font = Enum.Font.GothamMedium
    button.TextSize = 14
    button.Text = text
    button.Parent = frame
    Instance.new("UICorner", button).CornerRadius = UDim.new(0, 12)
    button.MouseButton1Click:Connect(callback)
    return button
end

makeButton("XeroHub cuchillo", 132, function()
    state.KnifeEnabled = true
    scanAll()
    rebuildHooks()
    showMessage("Textura del cuchillo aplicada")
end)

makeButton("XeroHub pistola", 172, function()
    state.GunEnabled = true
    scanAll()
    rebuildHooks()
    showMessage("Textura de la pistola aplicada")
end)

makeButton("Restaurar todo", 212, function()
    state.KnifeEnabled = false
    state.GunEnabled = false
    restoreKey("knife")
    restoreKey("gun")
    disconnectAll()
    showMessage("Texturas originales restauradas")
end)

-- drag simple
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
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)
game:GetService("UserInputService").InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        local delta = input.Position - dragStart
        frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

showMessage("Hub de prueba cargado")
