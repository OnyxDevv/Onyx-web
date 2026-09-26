--[[
XeroHub | DUELS Death Effects V2 · Native Bridge
Kev

Objetivo:
- Descarga Full Snapshot V2 desde tu repo.
- Reconstruye el asset faltante bajo ReplicatedStorage.ReplicatedSkins.Effects.
- Crea un dummy local con TU avatar.
- Llama la lógica NATIVA del juego:
      DeathEffectPreview.play(dummy, effectName, cleaner)
  para que el propio módulo aplique deformaciones, transparencias, cambios del
  cuerpo, animaciones, etc., no sólo partículas/sonidos.

No compra/equipa nada y no llama remotes de tienda.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local LP = Players.LocalPlayer
local PlayerGui = LP:WaitForChild("PlayerGui")

local ENV = (getgenv and getgenv()) or _G
local BASE = ENV.XERO_DEATH_EFFECTS_BASE
    or "https://raw.githubusercontent.com/OnyxDevv/Onyx-web/main/death_effects"

local requestFn = (syn and syn.request) or (http and http.request) or http_request or request

local function httpGet(url)
    if requestFn then
        local ok, response = pcall(function()
            return requestFn({
                Url = url,
                Method = "GET",
                Headers = {
                    ["User-Agent"] = "XeroHub-DeathEffects-NativeBridge/1.0",
                    ["Accept"] = "application/json",
                },
            })
        end)
        if ok and response then
            local code = tonumber(response.StatusCode or response.Status or 0) or 0
            local body = response.Body or response.body
            if code >= 200 and code < 300 and type(body) == "string" then
                return body
            end
        end
    end

    local ok, body = pcall(function()
        return game:HttpGet(url)
    end)
    if ok and type(body) == "string" then
        return body
    end
    return nil
end

-- ============================================================
-- Repo / cache
-- ============================================================
local CACHE_FOLDER = "XeroHub/DeathEffectsV2_NativeBridge"

local function ensureFolder(path)
    if type(makefolder) ~= "function" then return end
    pcall(function()
        if not isfolder or not isfolder(path) then makefolder(path) end
    end)
end

local function ensureCache()
    ensureFolder("XeroHub")
    ensureFolder(CACHE_FOLDER)
end

local function safeFileName(s)
    return tostring(s or ""):gsub("[^%w%._%-]", "_")
end

local function readCache(fileName)
    if type(isfile) ~= "function" or type(readfile) ~= "function" then return nil end
    local path = CACHE_FOLDER .. "/" .. safeFileName(fileName)
    if not isfile(path) then return nil end
    local ok, body = pcall(readfile, path)
    return ok and body or nil
end

local function writeCache(fileName, body)
    if type(writefile) ~= "function" or type(body) ~= "string" then return end
    ensureCache()
    pcall(writefile, CACHE_FOLDER .. "/" .. safeFileName(fileName), body)
end

local manifestBody = httpGet(BASE .. "/manifest.json")
if not manifestBody then
    error("Xero Native Bridge: no pude descargar manifest.json")
end

local okManifest, manifest = pcall(function()
    return HttpService:JSONDecode(manifestBody)
end)
if not okManifest or type(manifest) ~= "table" or type(manifest.effects) ~= "table" then
    error("Xero Native Bridge: manifest inválido")
end

if tonumber(manifest.schemaVersion) ~= 2 then
    error("Xero Native Bridge: tu repo todavía no tiene manifest Full Snapshot V2")
end

local EFFECTS = {}
local BY_NAME = {}
for _, entry in ipairs(manifest.effects) do
    if type(entry) == "table" and type(entry.name) == "string" and type(entry.file) == "string" then
        EFFECTS[#EFFECTS + 1] = entry.name
        BY_NAME[entry.name] = entry
    end
end
table.sort(EFFECTS)

local decodedCache = {}

local function validWrapper(data)
    return type(data) == "table"
        and tonumber(data.schemaVersion) == 2
        and type(data.snapshot) == "table"
        and type(data.snapshot.nodes) == "table"
        and #data.snapshot.nodes > 0
end

local function decodeWrapper(body)
    if type(body) ~= "string" then return nil end
    local ok, data = pcall(function()
        return HttpService:JSONDecode(body)
    end)
    if ok and validWrapper(data) then return data end
    return nil
end

local function fetchEffect(name)
    if decodedCache[name] then return decodedCache[name] end

    local entry = BY_NAME[name]
    if not entry then return nil, "No existe en manifest." end

    local body = readCache(entry.file)
    local data = decodeWrapper(body)

    if not data then
        body = httpGet(BASE .. "/effects/" .. entry.file)
        data = decodeWrapper(body)
        if data and body then writeCache(entry.file, body) end
    end

    if not data then
        return nil, "No pude bajar Full Snapshot V2: " .. tostring(entry.file)
    end

    decodedCache[name] = data
    return data
end

-- ============================================================
-- Typed V2 decoder
-- ============================================================
local function decodeTyped(value)
    if type(value) ~= "table" then return value, true end

    local t = value.t
    if not t then return value, true end

    if t == "nil" then
        return nil, false
    elseif t == "Vector3" then
        return Vector3.new(value.x or 0, value.y or 0, value.z or 0), true
    elseif t == "Vector2" then
        return Vector2.new(value.x or 0, value.y or 0), true
    elseif t == "Color3" then
        return Color3.new(value.r or 0, value.g or 0, value.b or 0), true
    elseif t == "CFrame" then
        local c = value.c
        if type(c) == "table" and #c >= 12 then
            return CFrame.new(
                c[1], c[2], c[3],
                c[4], c[5], c[6],
                c[7], c[8], c[9],
                c[10], c[11], c[12]
            ), true
        end
    elseif t == "NumberRange" then
        return NumberRange.new(value.min or 0, value.max or value.min or 0), true
    elseif t == "NumberSequence" then
        local pts = {}
        for _, kp in ipairs(value.keypoints or {}) do
            pts[#pts + 1] = NumberSequenceKeypoint.new(
                kp.time or 0, kp.value or 0, kp.envelope or 0
            )
        end
        if #pts >= 2 then return NumberSequence.new(pts), true end
        if #pts == 1 then return NumberSequence.new(pts[1].Value), true end
    elseif t == "ColorSequence" then
        local pts = {}
        for _, kp in ipairs(value.keypoints or {}) do
            local c = kp.color or {}
            pts[#pts + 1] = ColorSequenceKeypoint.new(
                kp.time or 0,
                Color3.new(c.r or 0, c.g or 0, c.b or 0)
            )
        end
        if #pts >= 2 then return ColorSequence.new(pts), true end
        if #pts == 1 then return ColorSequence.new(pts[1].Value), true end
    elseif t == "EnumItem" then
        local enumType = Enum[value.enum or ""]
        if enumType then
            local ok, item = pcall(function()
                return enumType[value.name or ""]
            end)
            if ok and item then return item, true end
        end
    elseif t == "BrickColor" then
        local ok, result = pcall(BrickColor.new, value.name or "Medium stone grey")
        if ok then return result, true end
    elseif t == "UDim2" then
        local x, y = value.x or {}, value.y or {}
        return UDim2.new(
            x.scale or 0, x.offset or 0,
            y.scale or 0, y.offset or 0
        ), true
    elseif t == "Rect" then
        local mn, mx = value.min or {}, value.max or {}
        return Rect.new(
            mn.x or 0, mn.y or 0,
            mx.x or 0, mx.y or 0
        ), true
    elseif t == "PhysicalProperties" then
        local ok, result = pcall(
            PhysicalProperties.new,
            value.density or .7,
            value.friction or .3,
            value.elasticity or .5,
            value.frictionWeight or 1,
            value.elasticityWeight or 1
        )
        if ok then return result, true end
    elseif t == "InstanceRef" then
        return value, "ref"
    end

    return nil, false
end

local function rawCFrame(raw)
    if type(raw) == "table" and raw.t == "CFrame" then
        local value, ok = decodeTyped(raw)
        if ok == true then return value end
    end
end

local function sourceAnchor(nodes)
    local byId = {}
    for _, node in ipairs(nodes) do byId[node.id] = node end

    for _, node in ipairs(nodes) do
        if node.class == "Model" then
            local raw = (node.properties or {}).PrimaryPart
            if type(raw) == "table" and raw.t == "InstanceRef" then
                local partNode = byId[raw.id]
                if partNode then
                    local cf = rawCFrame((partNode.properties or {}).CFrame)
                    if cf then return cf end
                end
            end
        end
    end

    local best, bestScore = nil, -1
    for _, node in ipairs(nodes) do
        if node.class == "Part" or node.class == "MeshPart" then
            local n = string.lower(tostring(node.name or ""))
            local score = 0
            if n == "effect" then score = 100
            elseif string.find(n, "root", 1, true) then score = 90
            elseif string.find(n, "death", 1, true) then score = 80
            elseif string.find(n, "effect", 1, true) then score = 75
            end
            if score > bestScore and rawCFrame((node.properties or {}).CFrame) then
                best, bestScore = node, score
            end
        end
    end

    if best then
        return rawCFrame((best.properties or {}).CFrame)
    end

    for _, node in ipairs(nodes) do
        if node.class == "Part" or node.class == "MeshPart" then
            local cf = rawCFrame((node.properties or {}).CFrame)
            if cf then return cf end
        end
    end

    return CFrame.new()
end

local SKIP = {
    Parent = true,
    WorldPivot = true,
    PhysicsRepRootRef = true,
    AudioContent = true,
    AnimationContent = true,
    WorldPosition = true,
    WorldOrientation = true,
    WorldCFrame = true,
    WorldAxis = true,
    WorldSecondaryAxis = true,
    TransformedWorldCFrame = true,
}

local function setAttributes(obj, attrs)
    for name, raw in pairs(attrs or {}) do
        local value, ok = decodeTyped(raw)
        if ok == true then
            pcall(function() obj:SetAttribute(name, value) end)
        elseif type(raw) ~= "table" then
            pcall(function() obj:SetAttribute(name, raw) end)
        end
    end
end

-- ============================================================
-- Rebuild effect as an ASSET TEMPLATE inside ReplicatedStorage.
-- We preserve relative transforms instead of positioning it on the dummy;
-- DeathEffectPreview itself is responsible for attaching/rendering it.
-- ============================================================
local injectedRoots = {}

local function getEffectsFolder()
    local skins = ReplicatedStorage:FindFirstChild("ReplicatedSkins")
    if not skins then
        skins = Instance.new("Folder")
        skins.Name = "ReplicatedSkins"
        skins.Parent = ReplicatedStorage
    end

    local effects = skins:FindFirstChild("Effects")
    if not effects then
        effects = Instance.new("Folder")
        effects.Name = "Effects"
        effects.Parent = skins
    end

    return effects
end

local function ensureNativeAsset(name)
    local effectsFolder = getEffectsFolder()

    -- Prefer real game asset when it already exists.
    local existing = effectsFolder:FindFirstChild(name)
    if existing then
        return existing, false, "asset nativo ya estaba cargado"
    end

    if injectedRoots[name] and injectedRoots[name].Parent then
        return injectedRoots[name], true, "asset V2 ya reconstruido"
    end

    local wrapper, err = fetchEffect(name)
    if not wrapper then return nil, false, err end

    local snapshot = wrapper.snapshot
    local nodes = snapshot.nodes
    local anchor = sourceAnchor(nodes)
    local normalize = anchor:Inverse()

    local idMap = {}
    local refs = {}

    -- Pass 1
    for _, node in ipairs(nodes) do
        local ok, obj = pcall(Instance.new, node.class)
        if ok and obj then
            idMap[node.id] = obj
            pcall(function() obj.Name = tostring(node.name or node.class) end)
        end
    end

    -- Pass 2 hierarchy
    for _, node in ipairs(nodes) do
        local obj = idMap[node.id]
        local parent = node.parent and idMap[node.parent] or nil
        if obj and parent then
            pcall(function() obj.Parent = parent end)
        end
    end

    -- Pass 3 properties
    for _, node in ipairs(nodes) do
        local obj = idMap[node.id]
        if obj then
            setAttributes(obj, node.attributes)

            for prop, raw in pairs(node.properties or {}) do
                if type(raw) == "table" and raw.t == "InstanceRef" then
                    refs[#refs + 1] = {
                        Object = obj,
                        Property = prop,
                        TargetId = raw.id,
                    }
                elseif not SKIP[prop] then
                    local value, ok = decodeTyped(raw)

                    if ok == true then
                        if obj:IsA("BasePart") then
                            if prop == "Position" or prop == "Orientation" or prop == "Rotation" then
                                -- CFrame below is the source of truth.
                            elseif prop == "CFrame" and typeof(value) == "CFrame" then
                                value = normalize * value
                                pcall(function() obj.CFrame = value end)
                            else
                                pcall(function() obj[prop] = value end)
                            end
                        elseif (obj:IsA("Attachment") or obj:IsA("Bone"))
                            and string.sub(prop, 1, 5) == "World" then
                            -- local attachment transform wins
                        else
                            pcall(function() obj[prop] = value end)
                        end
                    end
                end
            end
        end
    end

    -- Pass 4 refs
    for _, ref in ipairs(refs) do
        local target = idMap[ref.TargetId]
        if ref.Object and target then
            pcall(function()
                ref.Object[ref.Property] = target
            end)
        end
    end

    local root = idMap[snapshot.rootId]
    if not root then
        for _, node in ipairs(nodes) do
            if idMap[node.id] then
                root = idMap[node.id]
                break
            end
        end
    end

    if not root then
        return nil, false, "no pude reconstruir root"
    end

    root.Name = name
    pcall(function() root:SetAttribute("XeroV2Injected", true) end)
    root.Parent = effectsFolder
    injectedRoots[name] = root

    return root, true, "asset V2 inyectado localmente"
end

-- ============================================================
-- Cleaner compatible with DeathEffectPreview
-- ============================================================
local function makeCleaner()
    local cleaner = {
        _objects = {},
        _cleaning = false,
    }

    function cleaner:Add(object, method)
        if object == nil then return object end
        self._objects[#self._objects + 1] = {
            Object = object,
            Method = method,
        }
        return object
    end

    function cleaner:Remove(object)
        for i = #self._objects, 1, -1 do
            if self._objects[i].Object == object then
                table.remove(self._objects, i)
                return object
            end
        end
    end

    function cleaner:Extend()
        local child = makeCleaner()
        self:Add(function() child:Clean() end)
        return child
    end

    function cleaner:Clean()
        if self._cleaning then return end
        self._cleaning = true

        for i = #self._objects, 1, -1 do
            local entry = self._objects[i]
            self._objects[i] = nil

            local object = entry.Object
            local method = entry.Method

            pcall(function()
                if method and type(method) == "string" and object and object[method] then
                    object[method](object)
                elseif typeof(object) == "RBXScriptConnection" then
                    object:Disconnect()
                elseif typeof(object) == "Instance" then
                    object:Destroy()
                elseif type(object) == "function" then
                    object()
                elseif type(object) == "thread" then
                    task.cancel(object)
                elseif type(object) == "table" then
                    if type(object.Destroy) == "function" then
                        object:Destroy()
                    elseif type(object.Clean) == "function" then
                        object:Clean()
                    elseif type(object.Disconnect) == "function" then
                        object:Disconnect()
                    end
                end
            end)
        end

        self._cleaning = false
    end

    cleaner.Destroy = cleaner.Clean
    return cleaner
end

-- ============================================================
-- Dummy
-- ============================================================
local activeDummy
local activeCleaner

local function safeDestroy(obj)
    if obj then pcall(function() obj:Destroy() end) end
end

local function cleanCurrent()
    if activeCleaner then
        pcall(function() activeCleaner:Clean() end)
        activeCleaner = nil
    end
    if activeDummy then
        safeDestroy(activeDummy)
        activeDummy = nil
    end
end

local function makeDummy()
    cleanCurrent()

    local char = LP.Character
    local ownRoot = char and char:FindFirstChild("HumanoidRootPart")
    if not char or not ownRoot then
        return nil, "tu personaje aún no está listo"
    end

    local oldArchivable = char.Archivable
    char.Archivable = true
    local ok, dummy = pcall(function() return char:Clone() end)
    char.Archivable = oldArchivable

    if not ok or not dummy then
        return nil, "no pude clonar tu avatar"
    end

    dummy.Name = "XeroNativeDeathDummy"

    for _, obj in ipairs(dummy:GetDescendants()) do
        if obj:IsA("Script") or obj:IsA("LocalScript") or obj:IsA("Tool") then
            safeDestroy(obj)
        elseif obj:IsA("ForceField") then
            safeDestroy(obj)
        elseif obj:IsA("BasePart") then
            obj.CanCollide = false
            obj.CanTouch = false
            obj.CanQuery = false
        end
    end

    local hum = dummy:FindFirstChildOfClass("Humanoid")
    if hum then
        pcall(function()
            hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
            hum.NameDisplayDistance = 0
            hum.HealthDisplayDistance = 0
            hum.BreakJointsOnDeath = false
            hum.AutoRotate = false
        end)
    end

    dummy.Parent = Workspace

    local dummyRoot = dummy:FindFirstChild("HumanoidRootPart")
    if dummyRoot then
        pcall(function()
            dummy:PivotTo(
                ownRoot.CFrame
                * CFrame.new(0, 0, -8)
                * CFrame.Angles(0, math.rad(180), 0)
            )
        end)
        dummyRoot.Anchored = true
        dummyRoot.Transparency = 1
    end

    activeDummy = dummy
    return dummy
end

-- ============================================================
-- Native module
-- ============================================================
local previewModule =
    ReplicatedStorage
    :WaitForChild("Client")
    :WaitForChild("Controllers")
    :WaitForChild("UI")
    :WaitForChild("BundlePreviewUI")
    :WaitForChild("DeathEffectPreview")

local Preview = require(previewModule)

local function findFunction(nameWanted, sourceNeedle)
    if type(getgc) ~= "function" then return nil end
    local ok, arr = pcall(getgc, true)
    if not ok or type(arr) ~= "table" then return nil end

    for _, obj in ipairs(arr) do
        if type(obj) == "function" then
            local name, src = "", ""
            if debug and type(debug.info) == "function" then
                pcall(function()
                    name = tostring(debug.info(obj, "n") or "")
                    src = tostring(debug.info(obj, "s") or "")
                end)
            end

            if name == nameWanted
                and (not sourceNeedle or string.find(src, sourceNeedle, 1, true)) then
                return obj
            end
        end
    end
end

-- Simple before/after mutation counter for the dummy.
local function snapshotDummyState(dummy)
    local state = {}

    local function keyFor(obj)
        local ok, full = pcall(function()
            return obj:GetFullName()
        end)
        return (ok and full or obj.Name) .. "<" .. obj.ClassName .. ">"
    end

    local function add(obj, value)
        state[keyFor(obj)] = value
    end

    for _, obj in ipairs(dummy:GetDescendants()) do
        if obj:IsA("BasePart") then
            add(obj,
                tostring(obj.Size) .. "|" ..
                tostring(obj.Transparency) .. "|" ..
                tostring(obj.Color) .. "|" ..
                tostring(obj.Material)
            )
        elseif obj:IsA("Motor6D") then
            add(obj,
                tostring(obj.C0) .. "|" ..
                tostring(obj.C1) .. "|" ..
                tostring(obj.Transform)
            )
        elseif obj:IsA("SpecialMesh") then
            add(obj, tostring(obj.Scale) .. "|" .. tostring(obj.Offset))
        elseif obj:IsA("Decal") or obj:IsA("Texture") then
            add(obj, tostring(obj.Transparency) .. "|" .. tostring(obj.Color3))
        end
    end

    return state
end

local function countMutations(before, after)
    local count = 0

    for k, v in pairs(before) do
        if after[k] ~= v then count += 1 end
    end
    for k in pairs(after) do
        if before[k] == nil then count += 1 end
    end

    return count
end

local function runNative(name, statusLabel)
    local asset, injected, assetStatus = ensureNativeAsset(name)
    if not asset then
        statusLabel.Text = "✕ Asset: " .. tostring(assetStatus)
        return
    end

    local dummy, dummyErr = makeDummy()
    if not dummy then
        statusLabel.Text = "✕ Dummy: " .. tostring(dummyErr)
        return
    end

    local before = snapshotDummyState(dummy)
    local cleaner = makeCleaner()
    activeCleaner = cleaner

    statusLabel.Text =
        "Llamando NATIVO...\n" ..
        tostring(assetStatus)

    local ok, result = pcall(function()
        return Preview.play(dummy, name, cleaner)
    end)

    -- Jelly tiene una ruta distinta en DestroyBody.
    if not ok and string.find(name, "Jelly", 1, true) then
        local jellyFn = findFunction("spawnJellyCosmetic", "DestroyBody")
        if jellyFn then
            ok, result = pcall(jellyFn, dummy, name)
            if not ok then
                ok, result = pcall(jellyFn, name, dummy)
            end
        end
    end

    if not ok then
        statusLabel.Text =
            "✕ DeathEffectPreview falló:\n" ..
            tostring(result)
        return
    end

    statusLabel.Text =
        "✓ Nativo ejecutado · " .. name ..
        "\nMidiendo cambios del dummy..."

    task.delay(.65, function()
        if not dummy.Parent then return end
        local mutations = countMutations(before, snapshotDummyState(dummy))
        statusLabel.Text =
            "✓ " .. name ..
            " · cambios del cuerpo detectados: " .. tostring(mutations) ..
            "\n" .. tostring(assetStatus)
    end)
end

-- ============================================================
-- Compact UI
-- ============================================================
local oldGui = PlayerGui:FindFirstChild("XeroDeathNativeBridge")
if oldGui then oldGui:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name = "XeroDeathNativeBridge"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = PlayerGui

local frame = Instance.new("Frame")
frame.Size = UDim2.fromOffset(430, 226)
frame.Position = UDim2.new(.5, -215, .72, -113)
frame.BackgroundColor3 = Color3.fromRGB(12,12,12)
frame.BorderSizePixel = 0
frame.Parent = gui
Instance.new("UICorner", frame).CornerRadius = UDim.new(0,14)

local stroke = Instance.new("UIStroke", frame)
stroke.Color = Color3.fromRGB(55,55,55)
stroke.Transparency = .2

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Position = UDim2.fromOffset(16, 12)
title.Size = UDim2.new(1,-32,0,22)
title.Text = "XERO · DEATH EFFECT V2 · NATIVE BRIDGE"
title.TextColor3 = Color3.fromRGB(245,245,245)
title.Font = Enum.Font.GothamBold
title.TextSize = 14
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = frame

local effectLabel = Instance.new("TextLabel")
effectLabel.BackgroundColor3 = Color3.fromRGB(22,22,22)
effectLabel.BorderSizePixel = 0
effectLabel.Position = UDim2.fromOffset(16, 46)
effectLabel.Size = UDim2.new(1,-32,0,42)
effectLabel.TextColor3 = Color3.fromRGB(235,235,235)
effectLabel.Font = Enum.Font.GothamMedium
effectLabel.TextSize = 14
effectLabel.Parent = frame
Instance.new("UICorner", effectLabel).CornerRadius = UDim.new(0,10)

local status = Instance.new("TextLabel")
status.BackgroundTransparency = 1
status.Position = UDim2.fromOffset(16, 157)
status.Size = UDim2.new(1,-32,0,54)
status.Text = tostring(#EFFECTS) .. " efectos V2 · lógica nativa del juego"
status.TextColor3 = Color3.fromRGB(150,150,150)
status.Font = Enum.Font.Gotham
status.TextSize = 11
status.TextWrapped = true
status.TextXAlignment = Enum.TextXAlignment.Left
status.TextYAlignment = Enum.TextYAlignment.Top
status.Parent = frame

local function mkButton(txt, x, w)
    local b = Instance.new("TextButton")
    b.Size = UDim2.fromOffset(w, 38)
    b.Position = UDim2.fromOffset(x, 100)
    b.BackgroundColor3 = Color3.fromRGB(26,26,26)
    b.BorderSizePixel = 0
    b.Text = txt
    b.TextColor3 = Color3.fromRGB(235,235,235)
    b.Font = Enum.Font.GothamMedium
    b.TextSize = 11
    b.Parent = frame
    Instance.new("UICorner", b).CornerRadius = UDim.new(0,9)
    return b
end

local prev = mkButton("‹", 16, 44)
local test = mkButton("PROBAR NATIVO", 68, 182)
local dummyBtn = mkButton("NUEVO DUMMY", 258, 112)
local nxt = mkButton("›", 378, 36)

local index = 1

local function refresh()
    effectLabel.Text = EFFECTS[index] or "Sin efectos"
end
refresh()

prev.MouseButton1Click:Connect(function()
    index -= 1
    if index < 1 then index = #EFFECTS end
    refresh()
end)

nxt.MouseButton1Click:Connect(function()
    index += 1
    if index > #EFFECTS then index = 1 end
    refresh()
end)

test.MouseButton1Click:Connect(function()
    local name = EFFECTS[index]
    status.Text = "Preparando " .. tostring(name) .. "..."
    task.spawn(function()
        runNative(name, status)
    end)
end)

dummyBtn.MouseButton1Click:Connect(function()
    local dummy, err = makeDummy()
    status.Text = dummy
        and "✓ Dummy recreado con tu avatar."
        or ("✕ " .. tostring(err))
end)

-- drag
local dragging, dragStart, startPos
frame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = frame.Position
    end
end)
frame.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if dragging and (
        input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch
    ) then
        local d = input.Position - dragStart
        frame.Position = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + d.X,
            startPos.Y.Scale, startPos.Y.Offset + d.Y
        )
    end
end)

task.defer(function()
    local dummy, err = makeDummy()
    status.Text = dummy
        and (tostring(#EFFECTS) .. " efectos · ✓ dummy listo")
        or ("✕ dummy: " .. tostring(err))
end)

print("[Xero Death V2 Native Bridge]", #EFFECTS, "efectos ·", BASE)
