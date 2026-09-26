--[[
XeroHub | DUELS Death Effects · Native Dummy Bridge R5 Fidelity Fix
Kev

Objetivo:
- VOLVER al comportamiento que ya funcionaba.
- Descarga el V2 limpio del catálogo final.
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
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local LP = Players.LocalPlayer
local PlayerGui = LP:WaitForChild("PlayerGui")

local ENV = (getgenv and getgenv()) or _G
local BASE = ENV.XERO_DEATH_FINAL_ROOT
    or "https://raw.githubusercontent.com/OnyxDevv/Onyx-web/main/death_effects_final"

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
local CACHE_FOLDER = "XeroHub/DeathEffectsNativeDummyR5"

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

local manifestBody = httpGet(BASE .. "/renderer_base/manifest.json")
if not manifestBody then
    error("Xero Native Bridge: no pude descargar manifest.json")
end

local okManifest, manifest = pcall(function()
    return HttpService:JSONDecode(manifestBody)
end)
if not okManifest or type(manifest) ~= "table" or type(manifest.effects) ~= "table" then
    error("Xero Native Bridge: manifest inválido")
end


local EFFECTS = {}
local BY_NAME = {}
for _, entry in ipairs(manifest.effects) do
    if type(entry) == "table"
        and type(entry.name) == "string"
        and type(entry.v2) == "string" then
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
    if not entry then return nil, "No existe en manifest final." end

    local path = entry.v2
    local body = readCache(path)
    local data = decodeWrapper(body)

    if not data then
        body = httpGet(BASE .. "/" .. path)
        data = decodeWrapper(body)
        if data and body then writeCache(path, body) end
    end

    if not data then
        return nil, "No pude bajar V2 final: " .. tostring(path)
    end

    decodedCache[name] = data
    return data
end

-- ============================================================

local decodedV3Cache = {}

local function fetchBehavior(entry)
    if not entry or type(entry.v3) ~= "string" or entry.v3 == "" then
        return nil
    end

    local name = entry.name
    if decodedV3Cache[name] then
        return decodedV3Cache[name]
    end

    local path = entry.v3
    local cacheKey = "v3_" .. path
    local body = readCache(cacheKey)
    local data

    if body then
        local ok, parsed = pcall(function()
            return HttpService:JSONDecode(body)
        end)
        if ok then data = parsed end
    end

    if type(data) ~= "table" then
        body = httpGet(BASE .. "/" .. path)
        if body then
            local ok, parsed = pcall(function()
                return HttpService:JSONDecode(body)
            end)
            if ok then
                data = parsed
                writeCache(cacheKey, body)
            end
        end
    end

    if type(data) ~= "table"
        or tonumber(data.schemaVersion) ~= 3
        or type(data.behavior) ~= "table" then
        return nil
    end

    decodedV3Cache[name] = data
    return data
end

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
local previewInjected = {}
local previewBackups = {}

local function ensureSkinsFolders()
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

    local preview = skins:FindFirstChild("PreviewEffects")
    if not preview then
        preview = Instance.new("Folder")
        preview.Name = "PreviewEffects"
        preview.Parent = skins
    end

    return skins, effects, preview
end

local function cleanPreviousR3PreviewState()
    local skins, _, preview = ensureSkinsFolders()

    -- Restore backups from an earlier execution in the same session.
    local oldBackups = skins:FindFirstChild("XeroNativePreviewBackups")
    if oldBackups then
        for _, child in ipairs(oldBackups:GetChildren()) do
            local current = preview:FindFirstChild(child.Name)
            if current and current:GetAttribute("XeroFullPreviewInjected") then
                pcall(function() current:Destroy() end)
                current = nil
            end

            if not current then
                pcall(function() child.Parent = preview end)
            end
        end
        pcall(function() oldBackups:Destroy() end)
    end

    -- Remove stale mirrors that had no backup.
    for _, child in ipairs(preview:GetChildren()) do
        if child:GetAttribute("XeroFullPreviewInjected") then
            pcall(function() child:Destroy() end)
        end
    end
end

cleanPreviousR3PreviewState()

local function descendantCount(root)
    if not root then return -1 end
    local ok, descendants = pcall(function()
        return root:GetDescendants()
    end)
    return ok and #descendants or -1
end

local function makeBackupFolder()
    local skins = select(1, ensureSkinsFolders())
    local folder = skins:FindFirstChild("XeroNativePreviewBackups")
    if not folder then
        folder = Instance.new("Folder")
        folder.Name = "XeroNativePreviewBackups"
        folder.Parent = skins
    end
    return folder
end

local function putIntoPreview(name, sourceRoot, statusText)
    local _, _, preview = ensureSkinsFolders()
    local current = preview:FindFirstChild(name)

    if current and current ~= sourceRoot then
        local backupFolder = makeBackupFolder()
        current.Parent = backupFolder
        previewBackups[name] = current
    end

    local root = sourceRoot
    if root.Parent then
        local ok, clone = pcall(function() return root:Clone() end)
        if ok and clone then root = clone end
    end

    root.Name = name
    pcall(function()
        root:SetAttribute("XeroFullPreviewInjected", true)
    end)
    root.Parent = preview

    previewInjected[name] = root
    return root, statusText
end

local function reconstructV2Root(name, wrapper)
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
                            if prop == "Position"
                                or prop == "Orientation"
                                or prop == "Rotation" then
                                -- CFrame below is source of truth.
                            elseif prop == "CFrame"
                                and typeof(value) == "CFrame" then
                                value = normalize * value
                                pcall(function() obj.CFrame = value end)
                            else
                                pcall(function() obj[prop] = value end)
                            end
                        elseif (obj:IsA("Attachment") or obj:IsA("Bone"))
                            and string.sub(prop, 1, 5) == "World" then
                            -- Keep local attachment transform.
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
        return nil, "no pude reconstruir root V2"
    end

    root.Name = name
    pcall(function() root:SetAttribute("XeroV2Injected", true) end)
    return root
end

local function ensureNativeAsset(name)
    local _, effectsFolder, previewFolder = ensureSkinsFolders()

    local wrapper, err = fetchEffect(name)
    if not wrapper then return nil, false, err end

    local expectedDescendants =
        math.max(0, #(wrapper.snapshot.nodes or {}) - 1)

    local inPreview = previewFolder:FindFirstChild(name)
    local inEffects = effectsFolder:FindFirstChild(name)

    local previewCount = descendantCount(inPreview)
    local effectsCount = descendantCount(inEffects)

    -- DeathEffectPreview searches PreviewEffects before Effects.
    -- If PreviewEffects already has an equally/richer asset, keep the real one.
    if inPreview and previewCount >= expectedDescendants then
        return inPreview, false,
            string.format(
                "preview nativo completo (%d/%d nodos)",
                previewCount + 1,
                expectedDescendants + 1
            )
    end

    -- If Effects has the richer native copy, mirror THAT into PreviewEffects
    -- so DeathEffectPreview cannot accidentally choose a poorer preview copy.
    if inEffects
        and effectsCount >= expectedDescendants
        and effectsCount >= previewCount then

        local mirror, why =
            putIntoPreview(
                name,
                inEffects,
                string.format(
                    "mirror del asset nativo a PreviewEffects (%d nodos)",
                    effectsCount + 1
                )
            )

        injectedRoots[name] = mirror
        return mirror, true, why
    end

    -- Neither folder has the complete asset: reconstruct V2 and put it
    -- directly in PreviewEffects, which is what findEffectFolder checks first.
    local rebuilt, rebuildErr = reconstructV2Root(name, wrapper)
    if not rebuilt then
        return nil, false, rebuildErr
    end

    local mirror, why =
        putIntoPreview(
            name,
            rebuilt,
            string.format(
                "V2 completo inyectado en PreviewEffects (%d nodos)",
                expectedDescendants + 1
            )
        )

    if rebuilt ~= mirror and not rebuilt.Parent then
        pcall(function() rebuilt:Destroy() end)
    end

    injectedRoots[name] = mirror
    return mirror, true, why
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


-- ============================================================
-- Native body-style recovery
-- ============================================================
-- The preview module has its own config table and applyBodyStyle helper.
-- V2 snapshots contain the visual assets, but not that Lua config.
-- We recover the native config when possible and only patch BODY parts,
-- never Accessory handles.

local getConfigFunction = findFunction("getConfig", "DeathEffectPreview")

local BODY_STYLE_FALLBACK = {
    BlackvalkEffect = {
        Color = Color3.fromRGB(255,190,60),
        Material = Enum.Material.Neon,
    },
    Freeze = {
        Color = Color3.fromRGB(4,175,236),
        Material = Enum.Material.SmoothPlastic,
    },
    Frostbite = {
        Color = Color3.fromRGB(53,124,133),
        Material = Enum.Material.SmoothPlastic,
    },
    Heartache = {
        Color = Color3.fromRGB(255,0,0),
        Material = Enum.Material.Plastic,
    },
    Heartbeat = {
        Color = Color3.fromRGB(255,102,204),
        Material = Enum.Material.Neon,
        Transparency = .2,
    },
    IcemanEffect = {
        Color = Color3.fromRGB(152,219,255),
        Material = Enum.Material.Ice,
    },
    LEffect = {
        Color = Color3.fromRGB(255,43,44),
        Material = Enum.Material.Neon,
    },
    LavaEffect = {
        Color = Color3.fromRGB(255,60,0),
        Material = Enum.Material.Neon,
    },
    PhoenixEffect = {
        Color = Color3.fromRGB(255,80,35),
        Material = Enum.Material.Neon,
    },
    SandEffect = {
        Color = Color3.fromRGB(212,196,154),
        Material = Enum.Material.Sand,
    },
    SlimeEffect = {
        Color = Color3.fromRGB(85,255,127),
        Material = Enum.Material.Plastic,
    },
    SpiritOverload = {
        Color = Color3.fromRGB(0,48,8),
        Material = Enum.Material.SmoothPlastic,
    },
}

local function nativeConfigFor(name, asset)
    if type(getConfigFunction) ~= "function" then return nil end

    local attempts = {
        {name, asset},
        {name, nil},
        {name, {}},
        {asset, name},
    }

    for _, args in ipairs(attempts) do
        local ok, result = pcall(function()
            return getConfigFunction(table.unpack(args))
        end)

        if ok and type(result) == "table" then
            return result
        end
    end
end

local function bodyStyleFromConfig(name, asset)
    local cfg = nativeConfigFor(name, asset)
    if type(cfg) == "table" and type(cfg.BodyStyle) == "table" then
        return cfg.BodyStyle, "BodyStyle nativo"
    end

    local fallback = BODY_STYLE_FALLBACK[name]
    if fallback then
        return fallback, "BodyStyle fallback confirmado"
    end
end

local function isRealBodyPart(dummy, obj)
    if not obj:IsA("BasePart") then return false end
    if obj.Name == "HumanoidRootPart" then return false end
    if obj:FindFirstAncestorOfClass("Accessory") then return false end
    if obj:FindFirstAncestorOfClass("Tool") then return false end
    if not obj:IsDescendantOf(dummy) then return false end
    return true
end

local function applyBodyStyleOnly(dummy, style, snap)
    if not dummy or not dummy.Parent or type(style) ~= "table" then
        return 0
    end

    local targetColor = style.Color
    if typeof(targetColor) == "BrickColor" then
        targetColor = targetColor.Color
    end

    local startColor = style.StartColor
    if typeof(startColor) == "BrickColor" then
        startColor = startColor.Color
    end

    local tweenInfo = style.TweenInfo
    if typeof(tweenInfo) ~= "TweenInfo" then
        tweenInfo = TweenInfo.new(
            snap and 0 or 0.18,
            Enum.EasingStyle.Quad,
            Enum.EasingDirection.Out
        )
    end

    local changed = 0

    for _, obj in ipairs(dummy:GetDescendants()) do
        if isRealBodyPart(dummy, obj) then
            changed += 1

            if typeof(startColor) == "Color3" and not snap then
                pcall(function() obj.Color = startColor end)
            end

            local goals = {}

            if typeof(targetColor) == "Color3" then
                goals.Color = targetColor
            end

            if type(style.Transparency) == "number" then
                goals.Transparency = style.Transparency
            end

            if type(style.Reflectance) == "number" then
                goals.Reflectance = style.Reflectance
            end

            if typeof(style.Material) == "EnumItem"
                and style.Material.EnumType == Enum.Material then
                pcall(function() obj.Material = style.Material end)
            end

            if type(style.MaterialVariant) == "string" then
                pcall(function() obj.MaterialVariant = style.MaterialVariant end)
            end

            if next(goals) then
                if snap then
                    for prop, value in pairs(goals) do
                        pcall(function() obj[prop] = value end)
                    end
                else
                    pcall(function()
                        TweenService:Create(obj, tweenInfo, goals):Play()
                    end)
                end
            end
        end
    end

    return changed
end

local function scheduleBodyStylePatch(dummy, name, asset)
    local style, source = bodyStyleFromConfig(name, asset)
    if not style then
        return false, "sin BodyStyle"
    end

    -- Preview.play spawns work asynchronously. First pass mimics the color tween,
    -- second pass makes sure async native work did not restore the avatar colors.
    task.delay(0.04, function()
        if dummy and dummy.Parent then
            applyBodyStyleOnly(dummy, style, false)
        end
    end)

    task.delay(0.34, function()
        if dummy and dummy.Parent then
            applyBodyStyleOnly(dummy, style, true)
        end
    end)

    return true, source
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


-- ============================================================
-- R4 HYBRID COMPLETER
-- Preview.play remains the renderer. We only fill missing body/clothes/hat/VFX.
-- ============================================================

local BODY_PART_NAMES = {
    Head=true, UpperTorso=true, LowerTorso=true, Torso=true,
    LeftUpperArm=true, LeftLowerArm=true, LeftHand=true,
    RightUpperArm=true, RightLowerArm=true, RightHand=true,
    LeftUpperLeg=true, LeftLowerLeg=true, LeftFoot=true,
    RightUpperLeg=true, RightLowerLeg=true, RightFoot=true,
    ["Left Arm"]=true, ["Right Arm"]=true,
    ["Left Leg"]=true, ["Right Leg"]=true,
}

local SAFE_BODY_PROPS = {
    Color=true, BrickColor=true,
    Material=true, MaterialVariant=true,
    Transparency=true, Reflectance=true,
    Size=true, MeshId=true, TextureID=true, TextureId=true,
    DoubleSided=true,
}

local SAFE_CLOTHING_PROPS = {
    ShirtTemplate=true, PantsTemplate=true, Graphic=true, Color3=true,
    HeadColor=true, TorsoColor=true,
    LeftArmColor=true, RightArmColor=true,
    LeftLegColor=true, RightLegColor=true,
}

local function splitBodyPath(path)
    local out = {}
    for segment in string.gmatch(tostring(path or ""), "[^/]+") do
        out[#out+1] = segment
    end
    return out
end

local function decodedSegmentName(segment)
    local raw = tostring(segment or ""):match("^(.-)<[^<>]+>#%d+$")
        or tostring(segment or "")
    raw = raw:gsub("%%2F", "/")
    raw = raw:gsub("%%%%", "%%")
    return raw
end

local function pathTouchesAccessory(path)
    local s = tostring(path or "")
    return string.find(s, "<Accessory>", 1, true) ~= nil
        or string.find(s, "/Accessory ", 1, true) ~= nil
        or string.find(s, "/Accessory(", 1, true) ~= nil
end

local function resolveBodyPath(dummy, path)
    local segments = splitBodyPath(path)
    if #segments == 0 or segments[1] ~= "$BODY" then return nil end

    local current = dummy

    for i = 2, #segments do
        local segment = segments[i]
        local _, className, index =
            segment:match("^(.-)<([^<>]+)>#(%d+)$")
        if not className then return nil end

        local name = decodedSegmentName(segment)
        index = tonumber(index) or 1

        local count = 0
        local found

        for _, child in ipairs(current:GetChildren()) do
            if child.Name == name and child.ClassName == className then
                count += 1
                if count == index then
                    found = child
                    break
                end
            end
        end

        if not found then return nil end
        current = found
    end

    return current
end

local function applyAllowedProps(obj, props, allowed)
    if not obj or type(props) ~= "table" then return 0 end
    local n = 0

    for prop, raw in pairs(props) do
        if allowed[prop] then
            local value, ok = decodeTyped(raw)
            if ok == true then
                local success = pcall(function()
                    obj[prop] = value
                end)
                if success then n += 1 end
            end
        end
    end

    return n
end

local function ensureDirectClothing(dummy, path, entry)
    local segments = splitBodyPath(path)
    if #segments ~= 2 then return nil end

    local className = tostring(entry.class or "")
    if className ~= "Shirt"
        and className ~= "Pants"
        and className ~= "ShirtGraphic"
        and className ~= "BodyColors" then
        return nil
    end

    local name = decodedSegmentName(segments[2])

    for _, child in ipairs(dummy:GetChildren()) do
        if child.ClassName == className then
            child.Name = name
            return child
        end
    end

    local ok, obj = pcall(Instance.new, className)
    if not ok or not obj then return nil end

    obj.Name = name
    obj.Parent = dummy
    return obj
end

local function rawDeepEqual(a, b, depth)
    if a == b then return true end
    if type(a) ~= type(b) then return false end
    if type(a) ~= "table" then return false end

    depth = (depth or 0) + 1
    if depth > 10 then return false end

    for key, value in pairs(a) do
        if not rawDeepEqual(value, b[key], depth) then
            return false
        end
    end

    for key in pairs(b) do
        if a[key] == nil then return false end
    end

    return true
end

local function applySelectiveV3Diff(dummy, path, oldEntry, newEntry)
    if type(newEntry) ~= "table" or pathTouchesAccessory(path) then
        return 0
    end

    local obj = resolveBodyPath(dummy, path)
    if not obj then return 0 end

    local oldProps =
        type(oldEntry) == "table"
        and type(oldEntry.props) == "table"
        and oldEntry.props
        or {}

    local newProps =
        type(newEntry.props) == "table"
        and newEntry.props
        or {}

    local allowed

    if obj:IsA("BasePart") then
        if not BODY_PART_NAMES[obj.Name] then return 0 end
        allowed = SAFE_BODY_PROPS

    elseif obj:IsA("Shirt")
        or obj:IsA("Pants")
        or obj:IsA("ShirtGraphic")
        or obj:IsA("BodyColors") then

        -- R5 intentionally does NOT trust clothing from V3.
        -- Reassembly after death can insert the scanned victim's clothes.
        return 0

    else
        return 0
    end

    local applied = 0

    for prop in pairs(allowed) do
        local raw = newProps[prop]

        if raw ~= nil and not rawDeepEqual(oldProps[prop], raw) then
            local value, ok = decodeTyped(raw)
            if ok == true then
                local success = pcall(function()
                    obj[prop] = value
                end)
                if success then applied += 1 end
            end
        end
    end

    return applied
end

local function startSelectiveV3Replay(dummy, entry)
    local v3 = fetchBehavior(entry)
    if not v3 then return false, 0 end

    local behavior = v3.behavior or {}
    local timeline = behavior.timeline

    if type(timeline) ~= "table" or #timeline == 0 then
        return false, 0
    end

    local state = {}
    for path, baselineEntry in pairs(behavior.baseline or {}) do
        state[path] = baselineEntry
    end

    local token = HttpService:GenerateGUID(false)
    dummy:SetAttribute("XeroR5ReplayToken", token)

    task.spawn(function()
        local started = os.clock()

        table.sort(timeline, function(a,b)
            return (tonumber(a.t) or 0) < (tonumber(b.t) or 0)
        end)

        for _, frame in ipairs(timeline) do
            if not dummy.Parent
                or dummy:GetAttribute("XeroR5ReplayToken") ~= token then
                return
            end

            local waitFor = (tonumber(frame.t) or 0) - (os.clock() - started)
            if waitFor > 0 then task.wait(waitFor) end
            if not dummy.Parent then return end

            for path, newEntry in pairs(frame.changed or {}) do
                local oldEntry = state[path]
                applySelectiveV3Diff(dummy, path, oldEntry, newEntry)
                state[path] = newEntry
            end

            -- IMPORTANT:
            -- Do NOT replay frame.added from V3 here.
            -- Gifted proved that death/reassembly can add the scanned player's
            -- Shirt/Pants/BodyColors/Accessory and contaminate the effect.
        end
    end)

    return true, #timeline
end

local function applyV2Clothing(dummy, asset)
    local applied = 0

    for _, child in ipairs(asset:GetChildren()) do
        if child:IsA("Shirt")
            or child:IsA("Pants")
            or child:IsA("ShirtGraphic")
            or child:IsA("BodyColors") then

            local useful = true
            if child:IsA("Shirt") then
                useful = tostring(child.ShirtTemplate or "") ~= ""
            elseif child:IsA("Pants") then
                useful = tostring(child.PantsTemplate or "") ~= ""
            elseif child:IsA("ShirtGraphic") then
                useful = tostring(child.Graphic or "") ~= ""
            end

            if useful then
                for _, old in ipairs(dummy:GetChildren()) do
                    if old.ClassName == child.ClassName then
                        pcall(function() old:Destroy() end)
                    end
                end

                child:Clone().Parent = dummy
                applied += 1
            end
        end
    end

    return applied
end

local function nilExternalWeld(root)
    for _, obj in ipairs(root:GetDescendants()) do
        if obj:IsA("Weld") then
            if (obj.Part0 == nil and obj.Part1 ~= nil)
                or (obj.Part1 == nil and obj.Part0 ~= nil) then
                return obj
            end
        end
    end
end

local function attachV2HatIfNeeded(dummy, asset)
    local head = dummy:FindFirstChild("Head")
    if not head or not head:IsA("BasePart") then return 0 end

    local count = 0

    for _, child in ipairs(asset:GetChildren()) do
        if child:IsA("BasePart")
            and string.find(string.lower(child.Name), "hat", 1, true)
            and nilExternalWeld(child)
            and not dummy:FindFirstChild(child.Name) then

            local clone = child:Clone()
            clone.Parent = dummy

            local weld = nilExternalWeld(clone)
            if weld then
                if weld.Part0 == nil then
                    weld.Part0 = head
                elseif weld.Part1 == nil then
                    weld.Part1 = head
                end
            end

            local function safePart(obj)
                if obj:IsA("BasePart") then
                    obj.CanCollide = false
                    obj.CanTouch = false
                    obj.CanQuery = false
                end
            end

            safePart(clone)
            for _, d in ipairs(clone:GetDescendants()) do safePart(d) end

            count += 1
        end
    end

    return count
end

local function nearestPart(obj)
    local x = obj
    while x do
        if x:IsA("BasePart") then return x end
        x = x.Parent
    end
end

local function emitterIsNear(dummy, emitter)
    local p = nearestPart(emitter)
    local root = dummy and dummy:FindFirstChild("HumanoidRootPart")
    if not p or not root then return true end
    return (p.Position - root.Position).Magnitude <= 35
end

local function forceMarkedEmitter(emitter)
    local emitCount =
        tonumber(emitter:GetAttribute("EmitCount"))
        or tonumber(emitter:GetAttribute("KillEffectEmitCount"))

    local emitDelay = tonumber(emitter:GetAttribute("EmitDelay")) or 0
    local emitDuration = tonumber(emitter:GetAttribute("EmitDuration")) or 0

    task.delay(math.max(0, emitDelay), function()
        if not emitter.Parent then return end

        if emitCount and emitCount > 0 then
            pcall(function()
                emitter:Emit(math.max(1, math.floor(emitCount + .5)))
            end)
        end

        if emitDuration > 0 then
            pcall(function() emitter.Enabled = true end)
            task.delay(emitDuration, function()
                if emitter.Parent then
                    pcall(function() emitter.Enabled = false end)
                end
            end)
        end
    end)
end

local function observeNativeParticles(dummy)
    local active = true
    local seen = setmetatable({}, {__mode="k"})
    local baselineTop = setmetatable({}, {__mode="k"})
    local connections = {}

    for _, child in ipairs(Workspace:GetChildren()) do
        baselineTop[child] = true
    end

    local function inspect(obj)
        if not active or not obj or not obj.Parent then return end
        if not obj:IsA("ParticleEmitter") then return end
        if seen[obj] or not emitterIsNear(dummy, obj) then return end

        seen[obj] = true

        if obj:GetAttribute("EmitCount") ~= nil
            or obj:GetAttribute("EmitDuration") ~= nil
            or obj:GetAttribute("KillEffectEmitCount") ~= nil then
            forceMarkedEmitter(obj)
        end
    end

    local function scanRoot(root)
        if not root or not root.Parent then return end
        inspect(root)
        for _, obj in ipairs(root:GetDescendants()) do
            inspect(obj)
        end
    end

    connections[#connections+1] =
        Workspace.DescendantAdded:Connect(inspect)

    local camera = Workspace.CurrentCamera
    if camera then
        connections[#connections+1] =
            camera.DescendantAdded:Connect(inspect)
    end

    local function rescan()
        if not active then return end

        scanRoot(dummy)

        local cam = Workspace.CurrentCamera
        if cam then scanRoot(cam) end

        -- Only scan Workspace roots that appeared AFTER the preview started.
        -- This avoids walking the whole map repeatedly.
        for _, child in ipairs(Workspace:GetChildren()) do
            if not baselineTop[child] and child ~= dummy then
                scanRoot(child)
            end
        end
    end

    task.delay(.06, rescan)
    task.delay(.20, rescan)
    task.delay(.48, rescan)
    task.delay(.90, rescan)

    task.delay(1.65, function()
        active = false
        for _, conn in ipairs(connections) do
            pcall(function() conn:Disconnect() end)
        end
    end)
end

-- ============================================================
-- R5 appearance fidelity helpers
-- ============================================================

local ICE_ACCESSORY_PRESERVE = {
    Freeze = true,
    Frostbite = true,
    IcemanEffect = true,
}

local function captureAccessoryAppearance(dummy)
    local snap = setmetatable({}, {__mode="k"})

    for _, accessory in ipairs(dummy:GetChildren()) do
        if accessory:IsA("Accessory") then
            for _, obj in ipairs(accessory:GetDescendants()) do
                if obj:IsA("BasePart") then
                    snap[obj] = {
                        Color = obj.Color,
                        Material = obj.Material,
                        MaterialVariant = obj.MaterialVariant,
                        Transparency = obj.Transparency,
                        Reflectance = obj.Reflectance,
                    }
                end
            end
        end
    end

    return snap
end

local function restoreAccessoryAppearance(snapshot)
    for obj, state in pairs(snapshot or {}) do
        if obj and obj.Parent then
            pcall(function()
                obj.Color = state.Color
                obj.Material = state.Material
                obj.MaterialVariant = state.MaterialVariant
                obj.Transparency = state.Transparency
                obj.Reflectance = state.Reflectance
            end)
        end
    end
end

local function scheduleAccessoryRestore(snapshot)
    for _, delayTime in ipairs({.08, .22, .44, .82, 1.30}) do
        task.delay(delayTime, function()
            restoreAccessoryAppearance(snapshot)
        end)
    end
end

local function stripFrostbiteAvatarVisuals(dummy)
    if not dummy or not dummy.Parent then return end

    -- Frostbite/"hipotermia": original behavior removes classic clothes/face,
    -- while accessories remain present and keep their own appearance.
    for _, child in ipairs(dummy:GetChildren()) do
        if child:IsA("Shirt")
            or child:IsA("Pants")
            or child:IsA("ShirtGraphic") then
            pcall(function() child:Destroy() end)
        end
    end

    local head = dummy:FindFirstChild("Head")
    if head then
        for _, child in ipairs(head:GetChildren()) do
            if child:IsA("Decal")
                or child:IsA("Texture") then
                pcall(function() child:Destroy() end)
            end
        end
    end
end

local function scheduleFrostbiteStrip(dummy)
    for _, delayTime in ipairs({.03, .20, .45, .90}) do
        task.delay(delayTime, function()
            stripFrostbiteAvatarVisuals(dummy)
        end)
    end
end

local function allVisibleCharacterParts(dummy, includeAccessories)
    local out = {}

    for _, obj in ipairs(dummy:GetDescendants()) do
        if obj:IsA("BasePart")
            and obj.Name ~= "HumanoidRootPart" then

            local inAccessory =
                obj:FindFirstAncestorOfClass("Accessory") ~= nil

            if includeAccessories or not inAccessory then
                out[#out+1] = obj
            end
        end
    end

    return out
end

local function playGhostedFullFade(dummy)
    if not dummy or not dummy.Parent then return end

    -- V2 Ghosted is explicitly neon green. V3 confirms that its actual body
    -- timeline is a progressive fade to Transparency=1.
    local ghostGreen = Color3.fromRGB(32,255,69)

    -- Body gets the ghost tint; accessories keep their textures/colors.
    for _, part in ipairs(allVisibleCharacterParts(dummy, false)) do
        pcall(function()
            part.Color = ghostGreen
            part.Material = Enum.Material.Neon
        end)
    end

    -- The death animation itself fades the complete visible avatar away.
    task.delay(.08, function()
        if not dummy.Parent then return end

        for _, part in ipairs(allVisibleCharacterParts(dummy, true)) do
            local duration = 1.30
            pcall(function()
                TweenService:Create(
                    part,
                    TweenInfo.new(
                        duration,
                        Enum.EasingStyle.Quad,
                        Enum.EasingDirection.In
                    ),
                    {Transparency = 1}
                ):Play()
            end)
        end
    end)
end

local function scheduleV2ClothingLock(dummy, asset)
    -- Reapply effect-owned clothing AFTER native async work.
    -- This prevents the scanned victim's clothing from winning later.
    for _, delayTime in ipairs({.08, .28, .62}) do
        task.delay(delayTime, function()
            if dummy and dummy.Parent and asset and asset.Parent then
                applyV2Clothing(dummy, asset)
            end
        end)
    end
end

local function runNative(name, statusLabel)
    -- IMPORTANTE R5:
    -- Preview.play sigue siendo el renderer principal.
    -- R5 corrige sólo contaminación/fidelidad del dummy.
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

    local accessoryAppearance
    if ICE_ACCESSORY_PRESERVE[name] then
        accessoryAppearance = captureAccessoryAppearance(dummy)
    end

    -- Starts BEFORE native renderer creates visual clones.
    observeNativeParticles(dummy)

    -- V2 is authoritative for effect-owned clothing and 3D hats.
    local clothesV2 = applyV2Clothing(dummy, asset)
    local hatsV2 = attachV2HatIfNeeded(dummy, asset)

    local cleaner = makeCleaner()
    activeCleaner = cleaner

    statusLabel.Text =
        "Aplicando NATIVO + fidelity fix...\n" ..
        tostring(assetStatus)

    local ok, result = pcall(function()
        return Preview.play(dummy, name, cleaner)
    end)

    local bodyPatched, bodyPatchSource =
        scheduleBodyStylePatch(dummy, name, asset)

    local entry = BY_NAME[name]
    local v3Replayed, v3Frames =
        startSelectiveV3Replay(dummy, entry)

    -- Effect-specific fidelity rules confirmed from the collected assets/
    -- behavior and the in-game result.
    if name == "Frostbite" then
        scheduleFrostbiteStrip(dummy)
    end

    if name == "Ghosted" then
        playGhostedFullFade(dummy)
    end

    if accessoryAppearance then
        scheduleAccessoryRestore(accessoryAppearance)
    end

    if clothesV2 > 0 then
        scheduleV2ClothingLock(dummy, asset)
    end

    -- Jelly has a separate DestroyBody path.
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
        "\nCorrigiendo fidelidad..."

    task.delay(.78, function()
        if not dummy.Parent then return end

        local mutations =
            countMutations(before, snapshotDummyState(dummy))

        statusLabel.Text =
            "✓ " .. name ..
            " · body " .. tostring(mutations) ..
            (bodyPatched
                and (" · " .. tostring(bodyPatchSource))
                or "") ..
            (v3Replayed
                and (" · V3-diff " .. tostring(v3Frames) .. "f")
                or "") ..
            (clothesV2 > 0
                and (" · ropa V2 " .. tostring(clothesV2))
                or "") ..
            (hatsV2 > 0
                and (" · 3D " .. tostring(hatsV2))
                or "") ..
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
title.Text = "XERO · DEATH EFFECT · NATIVE DUMMY R5"
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
status.Text = tostring(#EFFECTS) .. " efectos · dummy tratado por lógica NATIVA"
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
for i, effectName in ipairs(EFFECTS) do
    if effectName == "Frostbite" then
        index = i
        break
    end
end

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

print("[Xero Death Native Dummy R3]", #EFFECTS, "efectos ·", BASE)
