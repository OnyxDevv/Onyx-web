--[[
XeroHub | DUELS Death Effects · Stable Base R23 · Local Kills + Dummy Bridge
Kev

Objetivo:
- VOLVER al comportamiento que ya funcionaba.
- Descarga el V2 limpio del catálogo final.
- Reconstruye el asset faltante bajo ReplicatedStorage.ReplicatedSkins.Effects.
- Observa a los jugadores enemigos durante la ronda.
- Cuando un enemigo muere, sólo continúa si el kill puede atribuirse al jugador local.
- Usa SU Character real como víctima.
- Llama la lógica NATIVA del juego:
      DeathEffectPreview.play(victimCharacter, effectName, cleaner)
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
local CACHE_FOLDER = "XeroHub/DeathEffectsNativeEnemyR18"

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

local function isJellyEffect(name)
    return type(name) == "string"
        and string.find(name, "Jelly", 1, true) ~= nil
end

for _, entry in ipairs(manifest.effects) do
    if type(entry) == "table"
        and type(entry.name) == "string"
        and type(entry.v2) == "string"
        and not isJellyEffect(entry.name)
        and entry.name ~= "Heartbeat"
        and entry.name ~= "SoulReaper"
        and entry.name ~= "BlackvalkEffect"
        and entry.name ~= "GhostbringerEffect"
        and entry.name ~= "Decorated"
        and entry.name ~= "ClanFlagEffect" then
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
-- R14 STARTUP PRELOAD
-- Descarga todos los V2 seleccionables al ejecutar el script.
-- Así fetchEffect() al seleccionar ya sale de decodedCache.
-- ============================================================

local PRELOAD_STATS = {
    total = #EFFECTS,
    loaded = 0,
    failed = 0,
    errors = {},
}

local function makePreloadGui()
    local old = PlayerGui:FindFirstChild("XeroDeathPreload")
    if old then old:Destroy() end

    local gui = Instance.new("ScreenGui")
    gui.Name = "XeroDeathPreload"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.Parent = PlayerGui

    local frame = Instance.new("Frame")
    frame.Size = UDim2.fromOffset(360, 96)
    frame.Position = UDim2.new(.5, -180, .5, -48)
    frame.BackgroundColor3 = Color3.fromRGB(12,12,12)
    frame.BorderSizePixel = 0
    frame.Parent = gui
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 12)

    local title = Instance.new("TextLabel")
    title.BackgroundTransparency = 1
    title.Position = UDim2.fromOffset(14, 12)
    title.Size = UDim2.new(1, -28, 0, 22)
    title.Text = "XERO · PRECARGANDO DEATH EFFECTS"
    title.TextColor3 = Color3.fromRGB(245,245,245)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 13
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = frame

    local status = Instance.new("TextLabel")
    status.BackgroundTransparency = 1
    status.Position = UDim2.fromOffset(14, 41)
    status.Size = UDim2.new(1, -28, 0, 40)
    status.Text = "Preparando..."
    status.TextColor3 = Color3.fromRGB(155,155,155)
    status.Font = Enum.Font.Gotham
    status.TextSize = 11
    status.TextWrapped = true
    status.TextXAlignment = Enum.TextXAlignment.Left
    status.Parent = frame

    return gui, status
end

local function preloadAllEffectData()
    if #EFFECTS == 0 then return end

    local preloadGui, preloadStatus = makePreloadGui()

    local nextIndex = 1
    local workersDone = 0
    local workerCount = math.min(5, #EFFECTS)

    local function updateStatus(currentName)
        if not preloadStatus or not preloadStatus.Parent then return end

        preloadStatus.Text =
            string.format(
                "%d/%d cargados · %d fallos\n%s",
                PRELOAD_STATS.loaded,
                PRELOAD_STATS.total,
                PRELOAD_STATS.failed,
                tostring(currentName or "")
            )
    end

    for _ = 1, workerCount do
        task.spawn(function()
            while true do
                -- No yield between reading/incrementing nextIndex, so each
                -- cooperative worker claims a unique slot.
                local i = nextIndex
                if i > #EFFECTS then break end
                nextIndex += 1

                local name = EFFECTS[i]
                updateStatus("Descargando " .. tostring(name) .. "...")

                local data, err = fetchEffect(name)

                if not data then
                    -- One retry at startup. We prefer paying the pause here,
                    -- not later when the user selects the effect.
                    task.wait(.08)
                    data, err = fetchEffect(name)
                end

                if data then
                    PRELOAD_STATS.loaded += 1
                else
                    PRELOAD_STATS.failed += 1
                    PRELOAD_STATS.errors[name] = tostring(err)
                end

                updateStatus(name)
                task.wait()
            end

            workersDone += 1
        end)
    end

    repeat
        task.wait(.03)
    until workersDone >= workerCount

    if preloadStatus and preloadStatus.Parent then
        preloadStatus.Text =
            string.format(
                "Listo · %d/%d precargados%s",
                PRELOAD_STATS.loaded,
                PRELOAD_STATS.total,
                PRELOAD_STATS.failed > 0
                    and (" · " .. PRELOAD_STATS.failed .. " fallos")
                    or ""
            )
    end

    task.wait(.16)

    if preloadGui and preloadGui.Parent then
        preloadGui:Destroy()
    end
end

preloadAllEffectData()

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
-- Real enemy victims
-- ============================================================
local victimCleaners = setmetatable({}, {__mode = "k"})

local function safeDestroy(obj)
    if obj then pcall(function() obj:Destroy() end) end
end

local function cleanVictim(victim)
    local cleaner = victim and victimCleaners[victim]
    if cleaner then
        pcall(function() cleaner:Clean() end)
        victimCleaners[victim] = nil
    end
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
        Reflectance = 0.35,
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

local function getUpvaluesSafe(fn)
    local getter = (debug and debug.getupvalues) or getupvalues
    if type(getter) ~= "function" or type(fn) ~= "function" then
        return nil
    end

    local ok, values = pcall(getter, fn)
    if ok and type(values) == "table" then
        return values
    end
end

local function findNativeConfigTable()
    local ups = getUpvaluesSafe(getConfigFunction)
    if not ups then return nil end

    local best
    local bestCount = 0

    for _, value in pairs(ups) do
        if type(value) == "table" then
            local count = 0
            local stringKeys = 0

            for key in pairs(value) do
                count += 1
                if type(key) == "string" then
                    stringKeys += 1
                end
            end

            if stringKeys >= 20 and count > bestCount then
                best = value
                bestCount = count
            end
        end
    end

    return best
end

local NATIVE_CONFIGS = findNativeConfigTable()

local function nativeConfigFor(name)
    if type(NATIVE_CONFIGS) == "table" then
        local cfg = NATIVE_CONFIGS[name]
        if type(cfg) == "table" then
            return cfg
        end
    end
end

local function bodyStyleFromConfig(name)
    local cfg = nativeConfigFor(name)

    if type(cfg) == "table"
        and type(cfg.BodyStyle) == "table" then
        return cfg.BodyStyle, "BodyStyle nativo"
    end

    local fallback = BODY_STYLE_FALLBACK[name]
    if fallback then
        return fallback, "BodyStyle fallback"
    end
end

-- Stable helper kept local to this bridge. The renderer calls this from
-- BodyStyle patches, so it must exist before any effect can reach that path.
local REAL_BODY_PART_NAMES = {
    Head=true, UpperTorso=true, LowerTorso=true, Torso=true,
    LeftUpperArm=true, LeftLowerArm=true, LeftHand=true,
    RightUpperArm=true, RightLowerArm=true, RightHand=true,
    LeftUpperLeg=true, LeftLowerLeg=true, LeftFoot=true,
    RightUpperLeg=true, RightLowerLeg=true, RightFoot=true,
    ["Left Arm"]=true, ["Right Arm"]=true,
    ["Left Leg"]=true, ["Right Leg"]=true,
}

local function isRealBodyPart(dummy, obj)
    if not dummy or not obj or not obj:IsA("BasePart") then return false end
    if obj.Name == "HumanoidRootPart" then return false end
    if not REAL_BODY_PART_NAMES[obj.Name] then return false end
    if obj:FindFirstAncestorOfClass("Accessory") then return false end
    if obj:FindFirstAncestorOfClass("Tool") then return false end

    local current = obj
    while current and current ~= dummy do
        current = current.Parent
    end
    return current == dummy
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
    local style, source = bodyStyleFromConfig(name)
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
    -- R6: generic V3 replay is intentionally disabled.
    -- Some captures include reassembly/body noise that can color or hide
    -- individual limbs even when the real effect does not.
    -- We now rely on the native renderer + explicit effect rules only.
    return false, 0
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
-- R7 FULL-VICTIM FIDELITY
-- ============================================================

local function allBaseParts(dummy)
    local out = {}
    for _, obj in ipairs(dummy:GetDescendants()) do
        if obj:IsA("BasePart")
            and obj.Name ~= "HumanoidRootPart" then
            out[#out+1] = obj
        end
    end
    return out
end

local function bodyPartsOnly(dummy)
    local out = {}

    for _, obj in ipairs(dummy:GetDescendants()) do
        if obj:IsA("BasePart")
            and obj.Name ~= "HumanoidRootPart"
            and not obj:FindFirstAncestorOfClass("Accessory")
            and not obj:FindFirstAncestorOfClass("Tool") then
            out[#out+1] = obj
        end
    end

    return out
end

local function accessoryParts(dummy)
    local out = {}

    for _, accessory in ipairs(dummy:GetChildren()) do
        if accessory:IsA("Accessory") then
            for _, obj in ipairs(accessory:GetDescendants()) do
                if obj:IsA("BasePart") then
                    out[#out+1] = obj
                end
            end
        end
    end

    return out
end

local function removeSurfaceAppearance(root)
    for _, obj in ipairs(root:GetDescendants()) do
        if obj:IsA("SurfaceAppearance") then
            pcall(function() obj:Destroy() end)
        end
    end
end

local function setTextureTint(root, color, removeTexture)
    for _, obj in ipairs(root:GetDescendants()) do
        if obj:IsA("SpecialMesh") then
            if removeTexture then
                pcall(function() obj.TextureId = "" end)
            end
            pcall(function()
                obj.VertexColor = Vector3.new(color.R, color.G, color.B)
            end)

        elseif obj:IsA("Decal") or obj:IsA("Texture") then
            pcall(function()
                obj.Color3 = color
            end)
        end
    end
end

local function forceSolidPart(part, color, material, reflectance)
    if not part or not part.Parent or not part:IsA("BasePart") then return end

    pcall(function()
        part.Color = color
        part.Material = material
        part.MaterialVariant = ""
        if type(reflectance) == "number" then
            part.Reflectance = reflectance
        end
    end)

    if part:IsA("MeshPart") then
        pcall(function()
            part.TextureID = ""
        end)
    end

    removeSurfaceAppearance(part)
    setTextureTint(part, color, true)
end

local function removeClassicClothes(dummy)
    for _, child in ipairs(dummy:GetChildren()) do
        if child:IsA("Shirt")
            or child:IsA("Pants")
            or child:IsA("ShirtGraphic") then
            pcall(function() child:Destroy() end)
        end
    end
end

local function removeFaceCompletely(dummy)
    local head = dummy and dummy:FindFirstChild("Head")
    if not head then return end

    for _, obj in ipairs(head:GetDescendants()) do
        if obj:IsA("Decal")
            or obj:IsA("Texture")
            or obj:IsA("SurfaceAppearance") then
            pcall(function() obj:Destroy() end)

        elseif obj:IsA("SpecialMesh") then
            pcall(function() obj.TextureId = "" end)
        end
    end

    if head:IsA("MeshPart") then
        pcall(function()
            head.TextureID = ""
        end)
    end
end

local function forceFreezePass(dummy)
    if not dummy or not dummy.Parent then return end

    local style =
        BODY_STYLE_FALLBACK.Freeze
        or {
            Color = Color3.fromRGB(4,175,236),
            Material = Enum.Material.SmoothPlastic,
            Reflectance = .35,
        }

    local color = style.Color
    if typeof(color) == "BrickColor" then color = color.Color end
    color = typeof(color) == "Color3" and color or Color3.fromRGB(4,175,236)

    local material =
        typeof(style.Material) == "EnumItem"
        and style.Material
        or Enum.Material.SmoothPlastic

    -- Classic clothes cannot actually be recolored uniformly, so removing them
    -- is the only way the complete victim can become the frozen material.
    removeClassicClothes(dummy)

    for _, part in ipairs(allBaseParts(dummy)) do
        forceSolidPart(
            part,
            color,
            material,
            style.Reflectance
        )
    end

    -- The face remains, but is tinted with the same frozen color.
    local head = dummy:FindFirstChild("Head")
    if head then
        setTextureTint(head, color, false)
    end
end

local function scheduleFreezeReal(dummy)
    -- Re-apply because native preview can add/re-parent visual avatar pieces
    -- asynchronously after play() returns.
    for _, delayTime in ipairs({0, .05, .14, .30, .55, .90, 1.35, 1.80}) do
        task.delay(delayTime, function()
            forceFreezePass(dummy)
        end)
    end

    local conn
    conn = dummy.DescendantAdded:Connect(function()
        task.defer(function()
            forceFreezePass(dummy)
        end)
    end)

    task.delay(2.0, function()
        pcall(function() conn:Disconnect() end)
    end)
end

local function tintTreeColorOnly(root, color)
    if not root then return end

    local function tint(obj)
        if obj:IsA("BasePart") then
            pcall(function()
                obj.Color = color
            end)

            -- Preserve Material/MaterialVariant, but remove texture overlays
            -- that visually hide the requested color.
            if obj:IsA("MeshPart") then
                pcall(function()
                    obj.TextureID = ""
                end)
            end

        elseif obj:IsA("Decal") or obj:IsA("Texture") then
            pcall(function()
                obj.Color3 = color
            end)

        elseif obj:IsA("SpecialMesh") then
            pcall(function()
                obj.VertexColor =
                    Vector3.new(color.R, color.G, color.B)
                obj.TextureId = ""
            end)

        elseif obj:IsA("SurfaceAppearance") then
            -- Keep the BasePart material intact; just stop the appearance maps
            -- from covering the color underneath.
            pcall(function() obj.ColorMap = "" end)
            pcall(function() obj.MetalnessMap = "" end)
            pcall(function() obj.NormalMap = "" end)
            pcall(function() obj.RoughnessMap = "" end)
        end
    end

    tint(root)

    for _, obj in ipairs(root:GetDescendants()) do
        tint(obj)
    end
end

local function blackenAccessory(accessory)
    if not accessory or not accessory:IsA("Accessory") then return end

    -- R15: Frostbite deja Material/MaterialVariant intactos.
    -- Se limpian sólo overlays/texturas que impiden que el negro sea visible.
    tintTreeColorOnly(accessory, Color3.new(0,0,0))
end

local function forceFrostbitePass(dummy)
    if not dummy or not dummy.Parent then return end

    local style =
        BODY_STYLE_FALLBACK.Frostbite
        or {
            Color = Color3.fromRGB(53,124,133),
            Material = Enum.Material.SmoothPlastic,
        }

    local color = style.Color
    if typeof(color) == "BrickColor" then color = color.Color end
    color = typeof(color) == "Color3" and color or Color3.fromRGB(53,124,133)

    local material =
        typeof(style.Material) == "EnumItem"
        and style.Material
        or Enum.Material.SmoothPlastic

    removeClassicClothes(dummy)
    removeFaceCompletely(dummy)

    for _, part in ipairs(bodyPartsOnly(dummy)) do
        forceSolidPart(part, color, material, 0)
    end

    for _, accessory in ipairs(dummy:GetChildren()) do
        if accessory:IsA("Accessory") then
            blackenAccessory(accessory)
        end
    end
end

local function scheduleFrostbiteReal(dummy)
    for _, delayTime in ipairs({0, .04, .12, .28, .52, .86, 1.25, 1.70, 2.15}) do
        task.delay(delayTime, function()
            forceFrostbitePass(dummy)
        end)
    end

    local conn
    conn = dummy.DescendantAdded:Connect(function(obj)
        task.defer(function()
            if not dummy.Parent then return end

            if obj:IsA("Shirt")
                or obj:IsA("Pants")
                or obj:IsA("ShirtGraphic") then
                pcall(function() obj:Destroy() end)
                return
            end

            forceFrostbitePass(dummy)
        end)
    end)

    task.delay(2.35, function()
        pcall(function() conn:Disconnect() end)
    end)
end

local function setGhostTransparency(dummy, alpha)
    for _, part in ipairs(allBaseParts(dummy)) do
        pcall(function()
            part.Transparency = alpha
        end)

        for _, obj in ipairs(part:GetDescendants()) do
            if obj:IsA("Decal") or obj:IsA("Texture") then
                pcall(function()
                    obj.Transparency = alpha
                end)
            end
        end
    end
end

local function prepareGhostedBody(dummy)
    if not dummy or not dummy.Parent then return end

    local green = Color3.fromRGB(32,255,69)

    -- This is the body state present in the captured real Ghosted death:
    -- Neon green, textureless and already at ~0.30 transparency.
    removeClassicClothes(dummy)

    for _, part in ipairs(allBaseParts(dummy)) do
        forceSolidPart(
            part,
            green,
            Enum.Material.Neon,
            0
        )
        pcall(function() part.Transparency = .30 end)
    end

    local hum = dummy:FindFirstChildOfClass("Humanoid")
    if hum then
        local animator = hum:FindFirstChildOfClass("Animator")
        if animator then
            pcall(function()
                for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
                    track:Stop(0)
                end
            end)
        end

        pcall(function()
            hum.AutoRotate = false
            hum.PlatformStand = true
            hum:ChangeState(Enum.HumanoidStateType.Ragdoll)
        end)
    end

    local root = dummy:FindFirstChild("HumanoidRootPart")
    if root then
        pcall(function()
            root.Anchored = false
        end)
    end
end

local function playGhostedCapturedNativeFade(dummy)
    if not dummy or not dummy.Parent then return end

    prepareGhostedBody(dummy)

    local root = dummy:FindFirstChild("HumanoidRootPart")
    if root then
        -- V3 captured the real fade but did not store CFrame/velocity.
        -- Rebuild the missing "fly away" motion as one continuous corpse move
        -- so the entire victim rises together instead of only fading in place.
        pcall(function()
            root.Anchored = true
        end)

        local startCF = root.CFrame
        local targetCF =
            startCF
            * CFrame.new(0, 11.5, -1.25)
            * CFrame.Angles(math.rad(-12), 0, math.rad(4))

        pcall(function()
            TweenService:Create(
                root,
                TweenInfo.new(
                    1.48,
                    Enum.EasingStyle.Quad,
                    Enum.EasingDirection.In
                ),
                {CFrame = targetCF}
            ):Play()
        end)
    end

    -- Transparency samples come from the real Ghosted capture.
    local points = {
        {0.000, 0.3000000},
        {0.209, 0.4036046},
        {0.292, 0.4776512},
        {0.578, 0.6622272},
        {0.963, 0.9094248},
        {1.449, 1.0000000},
    }

    for i = 2, #points do
        local prev = points[i-1]
        local current = points[i]
        local delayTime = prev[1]
        local duration = math.max(0.01, current[1] - prev[1])
        local targetAlpha = current[2]

        task.delay(delayTime, function()
            if not dummy or not dummy.Parent then return end

            for _, part in ipairs(allBaseParts(dummy)) do
                pcall(function()
                    TweenService:Create(
                        part,
                        TweenInfo.new(
                            duration,
                            Enum.EasingStyle.Linear,
                            Enum.EasingDirection.Out
                        ),
                        {Transparency = targetAlpha}
                    ):Play()
                end)

                for _, obj in ipairs(part:GetDescendants()) do
                    if obj:IsA("Decal") or obj:IsA("Texture") then
                        pcall(function()
                            TweenService:Create(
                                obj,
                                TweenInfo.new(
                                    duration,
                                    Enum.EasingStyle.Linear,
                                    Enum.EasingDirection.Out
                                ),
                                {Transparency = targetAlpha}
                            ):Play()
                        end)
                    end
                end
            end
        end)
    end
end


-- ============================================================
-- R9 native BodyStyle + external weld helpers
-- ============================================================

local nativeCaptureBodyAppearance =
    findFunction("captureBodyAppearance", "DeathEffectPreview")

local nativeApplyBodyStyle =
    findFunction("applyBodyStyle", "DeathEffectPreview")

local function applyExactNativeBodyStyle(dummy, effectName)
    local cfg = nativeConfigFor(effectName)
    if type(cfg) ~= "table" or type(cfg.BodyStyle) ~= "table" then
        return false, "sin BodyStyle nativo"
    end

    if type(nativeCaptureBodyAppearance) == "function"
        and type(nativeApplyBodyStyle) == "function" then

        local okCapture, appearance =
            pcall(nativeCaptureBodyAppearance, dummy)

        if okCapture and appearance ~= nil then
            local okApply = pcall(
                nativeApplyBodyStyle,
                appearance,
                cfg.BodyStyle
            )

            if okApply then
                return true, "BodyStyle nativo directo"
            end
        end
    end

    -- Safe fallback to our local implementation.
    local style = cfg.BodyStyle
    applyBodyStyleOnly(dummy, style, false)

    task.delay(.30, function()
        if dummy and dummy.Parent then
            applyBodyStyleOnly(dummy, style, true)
        end
    end)

    return true, "BodyStyle nativo fallback"
end

local function callNativeAdapter(effectName, dummy, asset, cleaner)
    local cfg = nativeConfigFor(effectName)
    local adapter = type(cfg) == "table" and cfg.Adapter or nil

    if type(adapter) ~= "function" then
        return false
    end

    -- renderOnce already calls Adapter, but this second call is only used
    -- for effects where the preview has been observed to miss body choreography.
    local attempts = {
        {dummy},
        {dummy, asset},
        {dummy, asset, cleaner},
    }

    for _, args in ipairs(attempts) do
        local ok = pcall(function()
            adapter(table.unpack(args))
        end)

        if ok then
            return true
        end
    end

    return false
end

local function findExternalWeld(root)
    if not root then return nil end

    for _, obj in ipairs(root:GetDescendants()) do
        if obj:IsA("Weld") then
            if obj.Part0 == nil and obj.Part1 ~= nil then
                return obj, "Part0"
            elseif obj.Part1 == nil and obj.Part0 ~= nil then
                return obj, "Part1"
            end
        end
    end
end

local function attachExternalWeldPiece(dummy, sourcePart, targetPart)
    if not dummy or not sourcePart or not targetPart then return nil end
    if not sourcePart:IsA("BasePart") then return nil end

    local templateWeld, missingSide = findExternalWeld(sourcePart)
    if not templateWeld then return nil end

    local clone = sourcePart:Clone()
    clone.Name = "XeroEffect_" .. sourcePart.Name
    clone.Parent = dummy

    local weld = findExternalWeld(clone)

    if weld then
        if missingSide == "Part0" then
            weld.Part0 = targetPart
        else
            weld.Part1 = targetPart
        end
    end

    local function sanitize(obj)
        if obj:IsA("BasePart") then
            obj.Anchored = false
            obj.CanCollide = false
            obj.CanTouch = false
            obj.CanQuery = false
            obj.Massless = true
        end
    end

    sanitize(clone)
    for _, obj in ipairs(clone:GetDescendants()) do
        sanitize(obj)
    end

    return clone
end

local function installDecoratedFullModel(dummy, asset)
    if not dummy or not asset then return 0 end

    local root =
        dummy:FindFirstChild("HumanoidRootPart")
        or dummy:FindFirstChild("UpperTorso")
        or dummy:FindFirstChild("Torso")

    if not root then return 0 end

    local decoratedRoot = asset:FindFirstChild("WeldToRoot")
    if not decoratedRoot or not decoratedRoot:IsA("BasePart") then
        return 0
    end

    -- Native preview can miss the external Part0 reference because it was
    -- outside the captured effect folder. Reconnect the whole ornament rig.
    local existing = dummy:FindFirstChild("XeroEffect_WeldToRoot")
    if existing then
        pcall(function() existing:Destroy() end)
    end

    return attachExternalWeldPiece(dummy, decoratedRoot, root) and 1 or 0
end


local function installDecoratedRigR15(dummy, asset)
    if not dummy or not dummy.Parent or not asset then
        return 0, "sin dummy/asset"
    end

    local source = asset:FindFirstChild("WeldToRoot")
    if not source or not source:IsA("BasePart") then
        return 0, "WeldToRoot ausente"
    end

    local target =
        dummy:FindFirstChild("UpperTorso")
        or dummy:FindFirstChild("Torso")
        or dummy:FindFirstChild("HumanoidRootPart")

    if not target or not target:IsA("BasePart") then
        return 0, "torso/root ausente"
    end

    local old = dummy:FindFirstChild("XeroDecoratedRig")
    if old then
        pcall(function() old:Destroy() end)
    end

    local sourceWeld, sourceMissing = findExternalWeld(source)

    local desiredCF =
        target.CFrame
        * CFrame.new(0, -1.5475876331329346, 0)

    if sourceWeld then
        if sourceMissing == "Part0"
            and sourceWeld.Part1 == source then

            desiredCF =
                target.CFrame
                * sourceWeld.C0
                * sourceWeld.C1:Inverse()

        elseif sourceMissing == "Part1"
            and sourceWeld.Part0 == source then

            desiredCF =
                target.CFrame
                * sourceWeld.C1
                * sourceWeld.C0:Inverse()
        end
    end

    local clone = source:Clone()
    clone.Name = "XeroDecoratedRig"

    -- R15: the reconstructed Star was the visual bug (giant star).
    -- Remove only that piece; keep garlands + red/green balls.
    for _, obj in ipairs(clone:GetDescendants()) do
        if string.lower(obj.Name) == "star" then
            pcall(function() obj:Destroy() end)
        end
    end

    local delta = desiredCF * source.CFrame:Inverse()

    local cloneParts = {clone}
    for _, obj in ipairs(clone:GetDescendants()) do
        if obj:IsA("BasePart") then
            cloneParts[#cloneParts + 1] = obj
        end
    end

    for _, part in ipairs(cloneParts) do
        pcall(function()
            part.CFrame = delta * part.CFrame
            part.Anchored = false
            part.CanCollide = false
            part.CanTouch = false
            part.CanQuery = false
            part.Massless = true
        end)
    end

    clone.Parent = dummy

    local weld, missingSide = findExternalWeld(clone)

    if weld then
        if missingSide == "Part0" then
            weld.Part0 = target
        elseif missingSide == "Part1" then
            weld.Part1 = target
        end
    else
        local fallbackWeld = Instance.new("Weld")
        fallbackWeld.Name = "XeroDecoratedWeld"
        fallbackWeld.Part0 = target
        fallbackWeld.Part1 = clone
        fallbackWeld.C0 =
            target.CFrame:ToObjectSpace(desiredCF)
        fallbackWeld.C1 = CFrame.new()
        fallbackWeld.Parent = clone
    end

    pcall(function()
        clone.CFrame = desiredCF
    end)

    return 1, "Decorated adornos sin estrella"
end

local function forceAllMarkedEmitters(root)
    if not root then return 0 end

    local count = 0

    local function inspect(obj)
        if not obj:IsA("ParticleEmitter") then return end

        local emitCount =
            tonumber(obj:GetAttribute("EmitCount"))
            or tonumber(obj:GetAttribute("KillEffectEmitCount"))

        local duration =
            tonumber(obj:GetAttribute("EmitDuration"))
            or 0

        local delayTime =
            tonumber(obj:GetAttribute("EmitDelay"))
            or 0

        if emitCount ~= nil or duration > 0 then
            count += 1

            task.delay(math.max(0, delayTime), function()
                if not obj.Parent then return end

                if emitCount and emitCount > 0 then
                    pcall(function()
                        obj:Emit(math.max(1, math.floor(emitCount + .5)))
                    end)
                end

                if duration > 0 then
                    pcall(function() obj.Enabled = true end)

                    task.delay(duration, function()
                        if obj.Parent then
                            pcall(function() obj.Enabled = false end)
                        end
                    end)
                end
            end)
        end
    end

    inspect(root)
    for _, obj in ipairs(root:GetDescendants()) do
        inspect(obj)
    end

    return count
end

local function rescanMarkedEmittersNearDummy(dummy, duration)
    local root = dummy and dummy:FindFirstChild("HumanoidRootPart")
    if not root then return end

    local seen = setmetatable({}, {__mode="k"})
    local alive = true

    local function scan()
        if not alive or not dummy.Parent then return end

        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj:IsA("ParticleEmitter") and not seen[obj] then
                local carrier = nearestPart(obj)

                if carrier
                    and (carrier.Position - root.Position).Magnitude <= 45 then

                    seen[obj] = true

                    local emitCount =
                        tonumber(obj:GetAttribute("EmitCount"))
                        or tonumber(obj:GetAttribute("KillEffectEmitCount"))

                    local emitDuration =
                        tonumber(obj:GetAttribute("EmitDuration"))
                        or 0

                    if emitCount ~= nil or emitDuration > 0 then
                        forceMarkedEmitter(obj)
                    end
                end
            end
        end
    end

    for _, delayTime in ipairs({.03, .10, .22, .42, .70, 1.05, 1.45}) do
        task.delay(delayTime, scan)
    end

    task.delay(duration or 1.7, function()
        alive = false
    end)
end

local function installGhostbringerAggressiveCarrierGuard(dummy)
    local root = dummy and dummy:FindFirstChild("HumanoidRootPart")
    if not root then return end

    local baselineParts = setmetatable({}, {__mode="k"})
    local watched = setmetatable({}, {__mode="k"})
    local propConnections = setmetatable({}, {__mode="k"})
    local conns = {}

    local function rememberTree(tree)
        if not tree then return end
        if tree:IsA("BasePart") then
            baselineParts[tree] = true
        end
        for _, obj in ipairs(tree:GetDescendants()) do
            if obj:IsA("BasePart") then
                baselineParts[obj] = true
            end
        end
    end

    -- Real body, accessories, equipped weapon and map geometry that already
    -- exist before Ghostbringer starts must stay visible.
    rememberTree(Workspace)
    rememberTree(Workspace.CurrentCamera)

    local function closeEnough(part)
        if not part or not part.Parent then return false end
        return (part.Position - root.Position).Magnitude <= 70
    end

    local function shouldHide(part)
        if not part
            or not part.Parent
            or not part:IsA("BasePart")
            or not closeEnough(part) then
            return false
        end

        if part.Name == "ghostbringer VFX" then
            return true
        end

        -- R14: Ghostbringer V2 contains no legitimate visible 3D model.
        -- Therefore every NEW nearby BasePart produced by this render pass is
        -- a carrier/square and can safely be hidden while keeping descendants
        -- (ParticleEmitter/Beam/Trail) alive.
        return not baselineParts[part]
    end

    local function forceHidden(part)
        if not watched[part] and not shouldHide(part) then return end
        watched[part] = true

        pcall(function()
            part.Transparency = 1
            part.LocalTransparencyModifier = 1
            part.CanCollide = false
            part.CanTouch = false
            part.CanQuery = false
            part.CastShadow = false
        end)

        if not propConnections[part] then
            local ok, conn = pcall(function()
                return part:GetPropertyChangedSignal("Transparency"):Connect(function()
                    if part.Parent and part.Transparency < .999 then
                        pcall(function()
                            part.Transparency = 1
                            part.LocalTransparencyModifier = 1
                        end)
                    end
                end)
            end)

            if ok and conn then
                propConnections[part] = conn
            end
        end
    end

    local function inspect(obj)
        if obj and obj:IsA("BasePart") and shouldHide(obj) then
            forceHidden(obj)
        end
    end

    conns[#conns+1] =
        Workspace.DescendantAdded:Connect(function(obj)
            task.defer(function()
                if obj:IsA("BasePart") then
                    inspect(obj)
                else
                    local carrier = nearestPart(obj)
                    if carrier then inspect(carrier) end
                end
            end)
        end)

    local camera = Workspace.CurrentCamera
    if camera then
        conns[#conns+1] =
            camera.DescendantAdded:Connect(function(obj)
                task.defer(function()
                    if obj:IsA("BasePart") then
                        inspect(obj)
                    else
                        local carrier = nearestPart(obj)
                        if carrier then inspect(carrier) end
                    end
                end)
            end)
    end

    local function rescan()
        if not dummy or not dummy.Parent then return end

        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj:IsA("BasePart")
                and (watched[obj] or shouldHide(obj)) then
                forceHidden(obj)
            end
        end

        local cam = Workspace.CurrentCamera
        if cam then
            for _, obj in ipairs(cam:GetDescendants()) do
                if obj:IsA("BasePart")
                    and (watched[obj] or shouldHide(obj)) then
                    forceHidden(obj)
                end
            end
        end

        for part in pairs(watched) do
            forceHidden(part)
        end
    end

    for _, t in ipairs({
        0, .01, .025, .05, .09, .15, .24, .36,
        .52, .74, 1.02, 1.36, 1.75, 2.20, 2.70
    }) do
        task.delay(t, rescan)
    end

    task.delay(3.0, function()
        for _, conn in ipairs(conns) do
            pcall(function() conn:Disconnect() end)
        end

        for _, conn in pairs(propConnections) do
            pcall(function() conn:Disconnect() end)
        end
    end)
end

local function prepareBlackvalkVictim(dummy, asset, cleaner)
    if not dummy or not dummy.Parent then return false, "sin dummy" end

    local root = dummy:FindFirstChild("HumanoidRootPart")
    local hum = dummy:FindFirstChildOfClass("Humanoid")

    -- Let native choreography move the victim. R8 kept the dummy root anchored.
    if root then
        pcall(function()
            root.Anchored = false
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
        end)
    end

    if hum then
        pcall(function()
            hum.AutoRotate = false
            hum.PlatformStand = true
        end)
    end

    local styled, styleSource =
        applyExactNativeBodyStyle(dummy, "BlackvalkEffect")

    -- Force the exact Adapter once more after unanchoring. If the native
    -- renderOnce already succeeded this is harmless on the disposable dummy.
    local adapterRan =
        callNativeAdapter(
            "BlackvalkEffect",
            dummy,
            asset,
            cleaner
        )

    rescanMarkedEmittersNearDummy(dummy, 1.8)

    return styled or adapterRan,
        (styled and styleSource or "Blackvalk")
        .. (adapterRan and " + Adapter" or "")
end

-- ============================================================
-- Explicit body effects that Preview.play does not faithfully reproduce.
-- ============================================================

local function forceWholeAvatarSolid(dummy, color, material, transparency)
    if not dummy or not dummy.Parent then return end

    removeClassicClothes(dummy)

    for _, part in ipairs(allBaseParts(dummy)) do
        forceSolidPart(
            part,
            color,
            material or Enum.Material.SmoothPlastic,
            0
        )

        pcall(function()
            part.Transparency = transparency or 0
        end)
    end

    -- Tint any face/decal that survived forceSolidPart.
    for _, obj in ipairs(dummy:GetDescendants()) do
        if obj:IsA("Decal") or obj:IsA("Texture") then
            pcall(function()
                obj.Color3 = color
                if transparency ~= nil then
                    obj.Transparency = transparency
                end
            end)
        end
    end
end


local function forceWholeAvatarColorOnly(
    dummy,
    color,
    removeClothes
)
    if not dummy or not dummy.Parent then return end

    if removeClothes then
        removeClassicClothes(dummy)
    end

    -- Body parts: color only, no Material changes.
    for _, part in ipairs(allBaseParts(dummy)) do
        pcall(function()
            part.Color = color
        end)
    end

    -- Hair/accessories: their textures can completely hide BasePart.Color.
    -- Tint them strongly while preserving Material/MaterialVariant.
    for _, child in ipairs(dummy:GetChildren()) do
        if child:IsA("Accessory") then
            tintTreeColorOnly(child, color)
        end
    end

    -- Face / visible textures on the body.
    for _, obj in ipairs(dummy:GetDescendants()) do
        if obj:IsA("Decal") or obj:IsA("Texture") then
            pcall(function()
                obj.Color3 = color
            end)

        elseif obj:IsA("SpecialMesh")
            and not obj:FindFirstAncestorOfClass("Accessory") then

            pcall(function()
                obj.VertexColor =
                    Vector3.new(color.R, color.G, color.B)
            end)
        end
    end
end

local function ghostbringerColor()
    -- R14: force Ghostbringer's green palette explicitly.
    -- Do not trust unrelated/mixed BodyStyle snapshots here.
    return Color3.fromRGB(50, 255, 148)
end

local function scheduleWholeVictimColorLockR14(
    dummy,
    color,
    duration,
    removeClothes
)
    duration = duration or 2.25
    local alive = true

    local function apply()
        if alive and dummy and dummy.Parent then
            forceWholeAvatarColorOnly(
                dummy,
                color,
                removeClothes
            )
        end
    end

    local conn = dummy.DescendantAdded:Connect(function()
        task.defer(apply)
    end)

    task.spawn(function()
        local deadline = os.clock() + duration

        repeat
            apply()
            task.wait(.045)
        until not alive
            or not dummy
            or not dummy.Parent
            or os.clock() >= deadline

        apply()
    end)

    task.delay(duration + .12, function()
        alive = false
        pcall(function() conn:Disconnect() end)
    end)
end


local function schedule1x1x1x1Color(dummy)
    -- Native VFX green captured from 1x1x1x1Effect:
    -- Color = 0.129291, 1, 0.137588
    -- Material is intentionally preserved.
    local green = Color3.new(
        0.129291,
        1,
        0.137588
    )

    local alive = true

    local function apply()
        if not alive or not dummy or not dummy.Parent then return end

        removeClassicClothes(dummy)

        -- Strong tint across the whole victim so MeshPart/accessory textures
        -- cannot hide the effect color. tintTreeColorOnly preserves Material
        -- and MaterialVariant.
        tintTreeColorOnly(dummy, green)
    end

    local conn = dummy.DescendantAdded:Connect(function()
        task.defer(apply)
    end)

    task.spawn(function()
        local deadline = os.clock() + 2.35

        repeat
            apply()
            task.wait(.045)
        until not alive
            or not dummy
            or not dummy.Parent
            or os.clock() >= deadline

        apply()
    end)

    task.delay(2.48, function()
        alive = false
        pcall(function() conn:Disconnect() end)
    end)
end

local function scheduleHeartacheReal(dummy)
    -- Color only. Preserve every BasePart's original Material.
    scheduleWholeVictimColorLockR14(
        dummy,
        Color3.fromRGB(255, 0, 0),
        2.20,
        true
    )
end

local function scheduleLightningBlack(dummy)
    -- Color only. Preserve every BasePart's original Material.
    scheduleWholeVictimColorLockR14(
        dummy,
        Color3.new(0, 0, 0),
        2.40,
        true
    )
end

local function scheduleGhostbringerGreen(dummy)
    -- Paint the entire victim with Ghostbringer's green while preserving
    -- the avatar's Materials. The carrier guard handles the visible squares.
    scheduleWholeVictimColorLockR14(
        dummy,
        ghostbringerColor(),
        2.65,
        true
    )
end

local function scheduleSpiritOverloadReal(dummy)
    -- V2 root color = RGB(36,75,26), SmoothPlastic.
    local spiritColor = Color3.fromRGB(36,75,26)

    for _, delayTime in ipairs({0, .05, .16, .34, .70, 1.15}) do
        task.delay(delayTime, function()
            forceWholeAvatarSolid(
                dummy,
                spiritColor,
                Enum.Material.SmoothPlastic,
                0
            )
        end)
    end

    local conn
    conn = dummy.DescendantAdded:Connect(function()
        task.defer(function()
            forceWholeAvatarSolid(
                dummy,
                spiritColor,
                Enum.Material.SmoothPlastic,
                0
            )
        end)
    end)

    task.delay(1.5, function()
        pcall(function() conn:Disconnect() end)
    end)
end

local function setWholeAvatarTransparency(dummy, alpha)
    if not dummy or not dummy.Parent then return end

    for _, part in ipairs(allBaseParts(dummy)) do
        pcall(function()
            part.Transparency = alpha
        end)

        for _, obj in ipairs(part:GetDescendants()) do
            if obj:IsA("Decal") or obj:IsA("Texture") then
                pcall(function()
                    obj.Transparency = alpha
                end)
            end
        end
    end
end

local function playSoulReaperCapturedBody(dummy)
    if not dummy or not dummy.Parent then return end

    -- Real V3 capture: lime green Neon body followed by a progressive fade.
    local soulColor = Color3.fromRGB(32,255,69)

    forceWholeAvatarSolid(
        dummy,
        soulColor,
        Enum.Material.Neon,
        .30
    )

    local hum = dummy:FindFirstChildOfClass("Humanoid")
    if hum then
        pcall(function()
            hum.AutoRotate = false
            hum.PlatformStand = true
            hum:ChangeState(Enum.HumanoidStateType.Ragdoll)
        end)
    end

    -- Real captured SoulReaper timing, normalized to the full avatar.
    local points = {
        {0.000, 0.3000000},
        {0.240, 0.3929472},
        {0.319, 0.4399051},
        {0.600, 0.6155688},
        {0.932, 0.8830000},
        {1.495, 1.0000000},
    }

    for i = 2, #points do
        local prev = points[i-1]
        local current = points[i]

        task.delay(prev[1], function()
            if not dummy or not dummy.Parent then return end

            local duration = math.max(.01, current[1] - prev[1])
            local alpha = current[2]

            for _, part in ipairs(allBaseParts(dummy)) do
                pcall(function()
                    TweenService:Create(
                        part,
                        TweenInfo.new(
                            duration,
                            Enum.EasingStyle.Linear,
                            Enum.EasingDirection.Out
                        ),
                        {Transparency = alpha}
                    ):Play()
                end)

                for _, obj in ipairs(part:GetDescendants()) do
                    if obj:IsA("Decal") or obj:IsA("Texture") then
                        pcall(function()
                            TweenService:Create(
                                obj,
                                TweenInfo.new(
                                    duration,
                                    Enum.EasingStyle.Linear,
                                    Enum.EasingDirection.Out
                                ),
                                {Transparency = alpha}
                            ):Play()
                        end)
                    end
                end
            end
        end)
    end
end

local function collectInvisibleCarrierNames(asset)
    local names = {}

    local function hasVfx(root)
        for _, obj in ipairs(root:GetDescendants()) do
            if obj:IsA("ParticleEmitter")
                or obj:IsA("Beam")
                or obj:IsA("Trail") then
                return true
            end
        end
        return false
    end

    local function inspect(obj)
        if obj:IsA("BasePart")
            and obj.Transparency >= .98
            and hasVfx(obj) then
            names[obj.Name] = true
        end
    end

    inspect(asset)
    for _, obj in ipairs(asset:GetDescendants()) do
        inspect(obj)
    end

    return names
end

local EXTRA_CARRIER_NAMES = {
    GhostbringerEffect = {
        ["ghostbringer VFX"] = true,
    },
    Heartbeat = {
        ["Heartbeat"] = true,
        ["EmitterGround"] = true,
    },
    SpiritOverload = {
        ["SpiritOverload"] = true,
        ["EmitterGround"] = true,
    },
    SoulReaper = {
        ["SoulReaper"] = true,
        ["EmitterGround"] = true,
    },
    Ghosted = {
        ["Ghosted"] = true,
        ["EmitterGround"] = true,
    },
}

local function enforceInvisibleCarriers(dummy, asset, effectName)
    local names = collectInvisibleCarrierNames(asset)

    for name in pairs(EXTRA_CARRIER_NAMES[effectName] or {}) do
        names[name] = true
    end

    if not next(names) then return end

    local root = dummy and dummy:FindFirstChild("HumanoidRootPart")
    local locked = setmetatable({}, {__mode="k"})
    local propertyConnections = setmetatable({}, {__mode="k"})

    local function nearDummy(part)
        if not root or not part:IsA("BasePart") then return true end
        return (part.Position - root.Position).Magnitude <= 45
    end

    local function forceHidden(part)
        if not part or not part.Parent or not part:IsA("BasePart") then return end

        pcall(function()
            part.Transparency = 1
            part.LocalTransparencyModifier = 1
            part.CanCollide = false
            part.CanTouch = false
            part.CanQuery = false
        end)

        if not propertyConnections[part] then
            local ok, conn = pcall(function()
                return part:GetPropertyChangedSignal("Transparency"):Connect(function()
                    if part.Parent and part.Transparency < .999 then
                        pcall(function()
                            part.Transparency = 1
                            part.LocalTransparencyModifier = 1
                        end)
                    end
                end)
            end)

            if ok and conn then
                propertyConnections[part] = conn
            end
        end
    end

    local function inspect(obj)
        if obj:IsA("BasePart")
            and names[obj.Name]
            and nearDummy(obj) then
            locked[obj] = true
            forceHidden(obj)
        end
    end

    local conns = {
        Workspace.DescendantAdded:Connect(inspect),
        dummy.DescendantAdded:Connect(inspect),
    }

    local camera = Workspace.CurrentCamera
    if camera then
        conns[#conns+1] = camera.DescendantAdded:Connect(inspect)
    end

    local function rescan()
        if not dummy or not dummy.Parent then return end

        for _, obj in ipairs(dummy:GetDescendants()) do
            inspect(obj)
        end

        local cameraNow = Workspace.CurrentCamera
        if cameraNow then
            for _, obj in ipairs(cameraNow:GetDescendants()) do
                inspect(obj)
            end
        end

        -- Selected effect only; short scan window.
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj:IsA("BasePart")
                and names[obj.Name]
                and nearDummy(obj) then
                inspect(obj)
            end
        end

        for part in pairs(locked) do
            forceHidden(part)
        end
    end

    for _, delayTime in ipairs({
        0, .03, .08, .16, .28, .45, .70, 1.0, 1.35, 1.75, 2.20
    }) do
        task.delay(delayTime, rescan)
    end

    task.delay(2.45, function()
        for _, conn in ipairs(conns) do
            pcall(function() conn:Disconnect() end)
        end

        for part, conn in pairs(propertyConnections) do
            pcall(function() conn:Disconnect() end)
            propertyConnections[part] = nil
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


local function cleanupLegacyDecoratedArtifacts()
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj.Name == "XeroEffect_WeldToRoot" then
            pcall(function() obj:Destroy() end)
        end
    end
end

local function runNativeOnVictim(name, victim, statusLabel)
    if not victim or not victim.Parent then
        if statusLabel then statusLabel.Text = "✕ La víctima ya no existe." end
        return false
    end

    if isJellyEffect(name) then
        if statusLabel then statusLabel.Text = "Jelly eliminado del renderer." end
        return false
    end

    if name == "Heartbeat"
        or name == "SoulReaper"
        or name == "BlackvalkEffect"
        or name == "GhostbringerEffect"
        or name == "Decorated" then
        if statusLabel then
            statusLabel.Text = tostring(name) .. " eliminado del renderer."
        end
        return false
    end

    local asset, injected, assetStatus = ensureNativeAsset(name)
    if not asset then
        if statusLabel then statusLabel.Text = "✕ Asset: " .. tostring(assetStatus) end
        return false
    end

    local hum = victim:FindFirstChildOfClass("Humanoid")
    if not hum then
        if statusLabel then statusLabel.Text = "✕ La víctima no tiene Humanoid." end
        return false
    end

    cleanVictim(victim)

    local before = snapshotDummyState(victim)

    observeNativeParticles(victim)
    enforceInvisibleCarriers(victim, asset, name)

    local clothesV2 = applyV2Clothing(victim, asset)
    local hatsV2 = attachV2HatIfNeeded(victim, asset)

    local cleaner = makeCleaner()
    victimCleaners[victim] = cleaner

    if statusLabel then
        statusLabel.Text =
            "Aplicando " .. tostring(name) .. " a " .. tostring(victim.Name) .. "...\n" ..
            tostring(assetStatus)
    end

    -- This is the important part: the native preview is executed on the
    -- actual dead enemy character rather than on a disposable preview dummy.
    local ok, result = pcall(function()
        return Preview.play(victim, name, cleaner)
    end)

    local bodyPatched = false
    local bodyPatchSource = nil

    if name == "1x1x1x1Effect" then
        schedule1x1x1x1Color(victim)
        bodyPatched = true
        bodyPatchSource = "1x1x1x1 · verde nativo completo"

    elseif name == "Freeze" then
        scheduleFreezeReal(victim)
        bodyPatched = true
        bodyPatchSource = "Freeze · TODO sólido"

    elseif name == "Frostbite" then
        scheduleFrostbiteReal(victim)
        bodyPatched = true
        bodyPatchSource = "Frostbite · sin cara/ropa + accesorios negros"

    elseif name == "Ghosted" then
        playGhostedCapturedNativeFade(victim)
        bodyPatched = true
        bodyPatchSource = "Ghosted · fade + vuelo"

    elseif name == "SpiritOverload" then
        scheduleSpiritOverloadReal(victim)
        bodyPatched = true
        bodyPatchSource = "SpiritOverload · TODO RGB 36,75,26"

    elseif name == "Heartache" then
        scheduleHeartacheReal(victim)
        bodyPatched = true
        bodyPatchSource = "Heartache · TODO rojo · material intacto"

    elseif name == "LightningStrike"
        or name == "LightningEffect" then
        scheduleLightningBlack(victim)
        bodyPatched = true
        bodyPatchSource = "Lightning · TODO negro · material intacto"

    else
        bodyPatched, bodyPatchSource =
            scheduleBodyStylePatch(victim, name, asset)
    end

    if clothesV2 > 0
        and name ~= "1x1x1x1Effect"
        and name ~= "Freeze"
        and name ~= "Frostbite"
        and name ~= "Ghosted"
        and name ~= "SpiritOverload"
        and name ~= "SoulReaper"
        and name ~= "Heartache"
        and name ~= "LightningStrike"
        and name ~= "LightningEffect" then
        scheduleV2ClothingLock(victim, asset)
    end

    if not ok then
        if statusLabel then
            statusLabel.Text = "✕ DeathEffectPreview falló:\n" .. tostring(result)
        end
        cleanVictim(victim)
        return false
    end

    if statusLabel then
        statusLabel.Text =
            "3/3 · EFECTO APLICADO\n" ..
            tostring(name) .. " → " .. tostring(victim.Name)
    end

    task.delay(.90, function()
        if not victim or not victim.Parent or not statusLabel or not statusLabel.Parent then
            return
        end

        local mutations = countMutations(before, snapshotDummyState(victim))
        statusLabel.Text =
            "✓ " .. name ..
            " · " .. tostring(victim.Name) ..
            " · body " .. tostring(mutations) ..
            (bodyPatched and (" · " .. tostring(bodyPatchSource)) or "") ..
            (clothesV2 > 0 and (" · ropa V2 " .. tostring(clothesV2)) or "") ..
            (hatsV2 > 0 and (" · 3D " .. tostring(hatsV2)) or "")
    end)

    -- Death effects are short-lived. Keep cleanup isolated per victim so one
    -- kill never cancels the visuals of another kill.
    task.delay(10, function()
        if victimCleaners[victim] == cleaner then
            cleanVictim(victim)
        end
    end)

    return true
end

-- ============================================================
-- Compact UI + enemy death listener
-- ============================================================
local oldGui = PlayerGui:FindFirstChild("XeroDeathNativeBridge")
if oldGui then oldGui:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name = "XeroDeathNativeBridge"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = PlayerGui

local frame = Instance.new("Frame")
frame.Size = UDim2.fromOffset(430, 220)
frame.Position = UDim2.new(.5, -215, .72, -110)
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
title.Text = "XERO · DEATH EFFECTS · INSTANT STABLE R25"
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
status.Position = UDim2.fromOffset(16, 151)
status.Size = UDim2.new(1,-32,0,54)
status.Text =
    string.format(
        "%d efectos · %d precargados · esperando activación",
        #EFFECTS,
        PRELOAD_STATS.loaded
    )
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
local toggle = mkButton("MIS KILLS: OFF", 68, 302)
local nxt = mkButton("›", 378, 36)

local index = 1
for i, effectName in ipairs(EFFECTS) do
    if effectName == "Frostbite" then
        index = i
        break
    end
end

local enabled = false
local trackedHumanoids = setmetatable({}, {__mode = "k"})
local playerConnections = {}
local localTeamConnections = {}

-- A death is NOT enough anymore. We keep it pending until we can attribute
-- the elimination to LocalPlayer through a native killer tag, a local kill
-- counter increment, or the local weapon's kill-confirm sound.
local pendingDeaths = {}
local pendingByHumanoid = setmetatable({}, {__mode = "k"})
local killSignalConnections = {}
local hookedKillValues = setmetatable({}, {__mode = "k"})
local hookedKillSounds = setmetatable({}, {__mode = "k"})
local recentKillCredits = {}
local recentDeathModels = setmetatable({}, {__mode = "k"})
local lastAcceptedSignalAt = 0
local lastAcceptedSignalSource = nil
local lastAppliedAt = 0

local PENDING_LIFETIME = 1.35
local CREDIT_LIFETIME = 0.85
local SIGNAL_DEDUPE_WINDOW = 0.28

local function selectedEffect()
    return EFFECTS[index]
end

local function refresh()
    effectLabel.Text = selectedEffect() or "Sin efectos"
end
refresh()

local function isEnemyPlayer(player)
    if not player or player == LP then return false end

    -- DUELS exposes lobby vs. round cleanly through Neutral/Team.
    -- This also prevents the death hook from doing anything in the lobby.
    if LP.Neutral == true or player.Neutral == true then
        return false
    end

    if LP.Team ~= nil and player.Team ~= nil then
        return LP.Team ~= player.Team
    end

    return LP.TeamColor ~= player.TeamColor
end

local function refreshHumanoidDeathMode(player, hum)
    -- R20: do NOT alter BreakJointsOnDeath. DUELS can replace the live Character
    -- with its own visible corpse/dummy and we need that native pipeline intact.
    local info = trackedHumanoids[hum]
    if not info or not hum.Parent then return end
    if info.originalBreakJoints ~= nil and hum.BreakJointsOnDeath ~= info.originalBreakJoints then
        pcall(function() hum.BreakJointsOnDeath = info.originalBreakJoints end)
    end
end

local function normalized(s)
    return string.lower(tostring(s or "")):gsub("[%s_%-]", "")
end

local function isKillKey(name)
    local n = normalized(name)
    return n == "creator"
        or n == "killer"
        or n == "killedby"
        or n == "lastdamager"
        or n == "lastattacker"
        or n == "damager"
        or n == "attacker"
        or n == "owner"
        or n == "creatorid"
        or n == "killerid"
        or n == "lastdamagerid"
end

local function valueMatchesLocal(v)
    if typeof(v) == "Instance" then
        return v == LP
    end

    if type(v) == "number" then
        return v == LP.UserId
    end

    if type(v) == "string" then
        local x = string.lower(v)
        return x == string.lower(LP.Name)
            or x == tostring(LP.UserId)
    end

    return false
end

local function objectValueMatchesLocal(obj)
    if not obj then return false end

    if obj:IsA("ObjectValue") then
        local ok, v = pcall(function() return obj.Value end)
        return ok and v == LP
    end

    if obj:IsA("IntValue") or obj:IsA("NumberValue") then
        local ok, v = pcall(function() return obj.Value end)
        return ok and tonumber(v) == LP.UserId
    end

    if obj:IsA("StringValue") then
        local ok, v = pcall(function() return obj.Value end)
        return ok and valueMatchesLocal(v)
    end

    return false
end

local function attributesPointToLocal(obj)
    if not obj then return false end
    local ok, attrs = pcall(function() return obj:GetAttributes() end)
    if not ok or type(attrs) ~= "table" then return false end

    for key, value in pairs(attrs) do
        if isKillKey(key) and valueMatchesLocal(value) then
            return true
        end
    end
    return false
end

local function hasLocalKillerTag(character, hum)
    if attributesPointToLocal(hum) or attributesPointToLocal(character) then
        return true
    end

    for _, root in ipairs({hum, character}) do
        if root then
            for _, obj in ipairs(root:GetDescendants()) do
                if isKillKey(obj.Name) and objectValueMatchesLocal(obj) then
                    return true
                end
            end
        end
    end

    return false
end

local function removePending(entry)
    if not entry or entry.removed then return end
    entry.removed = true
    if entry.hum then pendingByHumanoid[entry.hum] = nil end
end

local function prunePending()
    local now = os.clock()
    local write = 1
    for read = 1, #pendingDeaths do
        local entry = pendingDeaths[read]
        if entry
            and not entry.removed
            and now - entry.at <= PENDING_LIFETIME then
            pendingDeaths[write] = entry
            write += 1
        else
            if entry then removePending(entry) end
        end
    end
    for i = write, #pendingDeaths do pendingDeaths[i] = nil end
end

local function pruneCredits()
    local now = os.clock()
    local write = 1
    for read = 1, #recentKillCredits do
        local credit = recentKillCredits[read]
        if credit and now - credit.at <= CREDIT_LIFETIME then
            recentKillCredits[write] = credit
            write += 1
        end
    end
    for i = write, #recentKillCredits do recentKillCredits[i] = nil end
end

local function modelPosition(model)
    if not model then return nil end
    local root = model:FindFirstChild("HumanoidRootPart", true)
        or model:FindFirstChild("UpperTorso", true)
        or model:FindFirstChild("Torso", true)
        or model:FindFirstChild("Head", true)
    if root and root:IsA("BasePart") then return root.Position end
    local ok, pivot = pcall(function() return model:GetPivot() end)
    return ok and pivot.Position or nil
end

local function isCurrentPlayerCharacter(model)
    if not model then return false end
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Character == model then return true end
    end
    return false
end

local function looksLikeBody(model)
    if not model or not model:IsA("Model") or not model.Parent then return false end
    local bodyParts, totalParts = 0, 0
    for _, obj in ipairs(model:GetDescendants()) do
        if obj:IsA("BasePart") then
            totalParts += 1
            local n = normalized(obj.Name)
            if n == "head" or n == "humanoidrootpart" or n == "torso"
                or n == "uppertorso" or n == "lowertorso"
                or string.find(n, "arm", 1, true) or string.find(n, "leg", 1, true)
                or string.find(n, "hand", 1, true) or string.find(n, "foot", 1, true) then
                bodyParts += 1
            end
        end
    end
    return bodyParts >= 3 and totalParts >= 4
end

local function rememberDeathModel(model)
    if model and model:IsA("Model") and model.Parent then
        recentDeathModels[model] = os.clock()
    end
end

local function scoreDeathModel(model, player, originalCharacter, deathPosition, deathAt)
    if not model or model == originalCharacter or not model.Parent then return nil end
    if isCurrentPlayerCharacter(model) then
        -- Some games briefly promote the corpse/dummy to Player.Character.
        -- Exclude only a LIVE character; a dead replacement is still a valid target.
        local liveHum = model:FindFirstChildOfClass("Humanoid")
        if liveHum and liveHum.Health > 0 then return nil end
    end

    local createdAt = recentDeathModels[model]
    if deathAt and createdAt and createdAt < deathAt - 0.20 then return nil end
    if not looksLikeBody(model) then return nil end

    local pos = modelPosition(model)
    if not pos or not deathPosition then return nil end
    local distance = (pos - deathPosition).Magnitude
    if distance > 24 then return nil end

    local score = 80 - distance * 2.5
    local modelName = normalized(model.Name)
    local victimName = normalized(player and player.Name or "")
    local displayName = normalized(player and player.DisplayName or "")

    if victimName ~= "" and (modelName == victimName or string.find(modelName, victimName, 1, true)) then
        score += 80
    end
    if displayName ~= "" and displayName ~= victimName and string.find(modelName, displayName, 1, true) then
        score += 35
    end
    if string.find(modelName, "dummy", 1, true)
        or string.find(modelName, "corpse", 1, true)
        or string.find(modelName, "ragdoll", 1, true)
        or string.find(modelName, "dead", 1, true)
        or string.find(modelName, "body", 1, true) then
        score += 35
    end
    if model:FindFirstChildOfClass("Humanoid") then score += 25 end
    if createdAt and deathAt and math.abs(createdAt - deathAt) <= 0.90 then score += 45 end

    local okAttrs, attrs = pcall(function() return model:GetAttributes() end)
    if okAttrs and type(attrs) == "table" and player then
        for key, value in pairs(attrs) do
            local k = normalized(key)
            if (k == "userid" or k == "playerid" or k == "ownerid")
                and tonumber(value) == player.UserId then
                score += 120
            elseif (k == "player" or k == "owner" or k == "username")
                and normalized(value) == victimName then
                score += 100
            end
        end
    end

    return score
end

local function findBestDeathModel(player, originalCharacter, deathPosition, deathAt)
    local best, bestScore = nil, -math.huge
    for model in pairs(recentDeathModels) do
        if model and model.Parent then
            local score = scoreDeathModel(model, player, originalCharacter, deathPosition, deathAt)
            if score and score > bestScore then
                best, bestScore = model, score
            end
        end
    end
    return best, bestScore
end

local function nearbyNewModelSummary(deathPosition, deathAt)
    if not deathPosition then return "ninguno" end
    local found = {}
    for model, createdAt in pairs(recentDeathModels) do
        if model and model.Parent and (not deathAt or createdAt >= deathAt - 0.20) then
            local pos = modelPosition(model)
            if pos then
                local distance = (pos - deathPosition).Magnitude
                if distance <= 35 then
                    found[#found + 1] = {
                        name = tostring(model.Name),
                        distance = distance,
                        humanoid = model:FindFirstChildOfClass("Humanoid") ~= nil,
                    }
                end
            end
        end
    end
    table.sort(found, function(a, b) return a.distance < b.distance end)
    if #found == 0 then return "ninguno" end
    local parts = {}
    for i = 1, math.min(#found, 4) do
        local x = found[i]
        parts[#parts + 1] = string.format("%s %.1fst H:%s", x.name, x.distance, x.humanoid and "sí" or "no")
    end
    return table.concat(parts, " | ")
end

local function waitForDeathTarget(player, originalCharacter, deathPosition, deathAt)
    local deadline = os.clock() + 0.90
    repeat
        local best, score = findBestDeathModel(player, originalCharacter, deathPosition, deathAt)
        if best and score >= 55 then
            task.wait(0.03)
            return best, "dummy/cadáver"
        end
        task.wait(0.025)
    until os.clock() >= deadline

    if originalCharacter and originalCharacter.Parent
        and originalCharacter:FindFirstChildOfClass("Humanoid") then
        return originalCharacter, "Character original"
    end

    return nil, "sin cuerpo visual"
end

local function triggerVictim(player, character, hum, proof)
    local info = trackedHumanoids[hum]
    if not info or info.triggered then return false end
    if not enabled or info.deathEligible ~= true then return false end

    info.triggered = true
    local pending = pendingByHumanoid[hum]
    if pending then removePending(pending) end

    local effectName = selectedEffect()
    if not effectName then return false end

    lastAppliedAt = os.clock()

    local deathPosition = info.deathPosition or modelPosition(character)
    local deathAt = info.deathAt or os.clock()
    local appliedToOriginal = false

    -- R25: keep R23's proven detection/render pipeline, but DO NOT wait for
    -- DUELS to spawn its visible corpse before starting the effect. As soon as
    -- the local kill is confirmed, run the native renderer on the enemy's
    -- original Character while it is still present.
    if character and character.Parent
        and character:FindFirstChildOfClass("Humanoid") then

        status.Text =
            "2/3 · KILL CONFIRMADO · APLICANDO YA\n" ..
            tostring(effectName) .. " → " .. tostring(player.Name) ..
            (proof and ("\n" .. tostring(proof)) or "")

        local ok, result = pcall(function()
            return runNativeOnVictim(effectName, character, status)
        end)
        appliedToOriginal = ok and result == true
    end

    -- DUELS may replace that Character with a separate corpse/dummy a moment
    -- later. Keep the old R23 search only as a background bridge so the visual
    -- continues on the body that actually falls; it no longer delays frame 1.
    task.spawn(function()
        local target, targetKind =
            waitForDeathTarget(player, character, deathPosition, deathAt)

        if target and target.Parent and target ~= character then
            local hasHumanoid = target:FindFirstChildOfClass("Humanoid") ~= nil
            status.Text =
                "3/3 · CONTINUANDO EN CUERPO/DUMMY\n" ..
                tostring(targetKind) .. " · " .. tostring(target.Name) ..
                " · Humanoid: " .. (hasHumanoid and "sí" or "no")

            local ok, result = pcall(function()
                return runNativeOnVictim(effectName, target, status)
            end)

            if not ok or result ~= true then
                if not appliedToOriginal then
                    status.Text =
                        "✕ Kill confirmado, pero no se pudo aplicar el efecto.\n" ..
                        "Nuevos cerca: " .. nearbyNewModelSummary(deathPosition, deathAt)
                end
            end
            return
        end

        -- If the original Character vanished before the kill-confirm signal,
        -- preserve R23's reliable fallback instead of inventing another path.
        if not appliedToOriginal then
            if target and target.Parent then
                local ok, result = pcall(function()
                    return runNativeOnVictim(effectName, target, status)
                end)
                if ok and result == true then return end
            end

            status.Text =
                "✕ Kill confirmado, pero el cuerpo desapareció antes del efecto.\n" ..
                "Nuevos cerca: " .. nearbyNewModelSummary(deathPosition, deathAt)
        end
    end)

    return true
end

local function newestPending()
    prunePending()
    for i = #pendingDeaths, 1, -1 do
        local entry = pendingDeaths[i]
        if entry
            and not entry.removed
            and enabled
            and entry.wasEligible == true then
            return entry
        end
    end
    return nil
end

local queueVictimDeath

local function queueMostLikelyDeadEnemy()
    local now = os.clock()
    local bestPlayer, bestCharacter, bestHum, bestScore

    for hum, info in pairs(trackedHumanoids) do
        if hum and info and not info.triggered then
            local p = info.player
            local model = info.character or hum.Parent

            if p and p ~= LP and model then
                local score = 0
                local health = math.huge
                pcall(function() health = hum.Health end)

                if health <= 0 then score += 100 end
                if not model.Parent then score += 80 end

                if info.deathAt and now - info.deathAt <= PENDING_LIFETIME then
                    score += 70 - math.min(60, (now - info.deathAt) * 50)
                end

                if info.deathEligible == true then
                    score += 45
                elseif enabled and isEnemyPlayer(p) then
                    score += 20
                end

                if score > (bestScore or -math.huge) then
                    bestPlayer, bestCharacter, bestHum, bestScore =
                        p, model, hum, score
                end
            end
        end
    end

    if bestHum and bestScore and bestScore >= 70 then
        local info = trackedHumanoids[bestHum]
        if info then
            info.deathAt = info.deathAt or now
            info.deathPosition = info.deathPosition or modelPosition(bestCharacter)
            info.deathEligible = true
        end

        if queueVictimDeath then
            queueVictimDeath(bestPlayer, bestCharacter, bestHum)
            return true
        end
    end

    return false
end

local function consumeOnePending(proof)
    local entry = newestPending()
    if not entry then return false end
    removePending(entry)
    return triggerVictim(entry.player, entry.character, entry.hum, proof)
end

local function consumeFreshCredit(player, character, hum)
    pruneCredits()
    if #recentKillCredits == 0 then return false end

    local credit = table.remove(recentKillCredits, 1)
    if not credit then return false end
    return triggerVictim(player, character, hum, credit.source)
end

local function recordLocalKillSignal(source, count)
    if not enabled then return end
    count = math.max(1, math.floor(tonumber(count) or 1))
    local now = os.clock()

    status.Text =
        "1/3 · TU KILL CONFIRMADO\n" ..
        tostring(source) .. " · buscando víctima/cuerpo..."

    -- GunKill + Kills counter often fire for the same elimination. Do not
    -- convert the second native confirmation into a credit for the next death.
    if lastAcceptedSignalSource ~= source
        and now - lastAcceptedSignalAt <= SIGNAL_DEDUPE_WINDOW then
        return
    end

    -- A direct creator/killer tag may already have applied the effect before
    -- the sound/stat arrives. Ignore the trailing confirmation in that case.
    if now - lastAppliedAt <= SIGNAL_DEDUPE_WINDOW and not newestPending() then
        lastAcceptedSignalAt = now
        lastAcceptedSignalSource = source
        return
    end

    lastAcceptedSignalAt = now
    lastAcceptedSignalSource = source

    for _ = 1, count do
        if not consumeOnePending(source) then
            -- If Died was invisible client-side, CharacterRemoving/AncestryChanged
            -- may have marked the enemy without creating a normal pending entry yet.
            queueMostLikelyDeadEnemy()

            if not consumeOnePending(source) then
                pruneCredits()
                recentKillCredits[#recentKillCredits + 1] = {
                    at = now,
                    source = source,
                }
            end
        end
    end
end

queueVictimDeath = function(player, character, hum)
    local info = trackedHumanoids[hum]
    if not info or info.triggered then return end
    local eligibleNow = enabled and (info.deathEligible == true or isEnemyPlayer(player))
    if not eligibleNow then return end
    if not character or pendingByHumanoid[hum] then return end

    info.deathAt = info.deathAt or os.clock()
    info.deathPosition = info.deathPosition or modelPosition(character)
    info.deathEligible = true

    -- Best case: the game already stamped the killer/creator on the Humanoid.
    if hasLocalKillerTag(character, hum) then
        triggerVictim(player, character, hum, "killer/creator nativo")
        return
    end

    -- Some local kill-confirm signals arrive a fraction before Humanoid.Died.
    if consumeFreshCredit(player, character, hum) then
        return
    end

    local entry = {
        player = player,
        character = character,
        hum = hum,
        at = info.deathAt or os.clock(),
        deathPosition = info.deathPosition,
        wasEligible = true,
        removed = false,
    }
    pendingByHumanoid[hum] = entry
    pendingDeaths[#pendingDeaths + 1] = entry

    status.Text = "Muerte detectada: " .. tostring(player.Name) .. " · esperando confirmar TU kill..."

    -- Killer tags can be attached just after Died, so recheck briefly.
    task.defer(function()
        for _, delayTime in ipairs({0.03, 0.09, 0.18, 0.32}) do
            task.wait(delayTime)
            if info.triggered or entry.removed then return end
            if hasLocalKillerTag(character, hum) then
                removePending(entry)
                triggerVictim(player, character, hum, "killer/creator nativo")
                return
            end
        end
    end)

    task.delay(PENDING_LIFETIME + 0.05, function()
        if entry.removed or info.triggered then return end
        removePending(entry)
        if enabled then
            status.Text = "Muerte ignorada: no se confirmó que el kill fuera tuyo."
        end
    end)
end

local function hookCharacter(player, character)
    if player == LP or not character then return end

    task.spawn(function()
        local hum = character:FindFirstChildOfClass("Humanoid")
            or character:WaitForChild("Humanoid", 10)
        if not hum or trackedHumanoids[hum] then return end

        local info = {
            player = player,
            character = character,
            originalBreakJoints = hum.BreakJointsOnDeath,
            triggered = false,
            connections = {},
        }
        trackedHumanoids[hum] = info

        refreshHumanoidDeathMode(player, hum)

        info.connections[#info.connections + 1] = hum.Died:Connect(function()
            queueVictimDeath(player, character, hum)
        end)

        info.connections[#info.connections + 1] = hum.HealthChanged:Connect(function(health)
            if health <= 0 then
                queueVictimDeath(player, character, hum)
            end
        end)

        info.connections[#info.connections + 1] = character.AncestryChanged:Connect(function(_, parent)
            if parent == nil then
                -- Fallback for games that replace the Character without exposing
                -- Humanoid.Died locally. Queue it while we still have its last body data.
                if not info.triggered and enabled and isEnemyPlayer(player) then
                    info.deathAt = info.deathAt or os.clock()
                    info.deathPosition = info.deathPosition or modelPosition(character)
                    info.deathEligible = true
                    queueVictimDeath(player, character, hum)
                end

                -- Do not cancel the pending kill here: DUELS can remove the live
                -- Character first and spawn the visible death dummy immediately after.
                cleanVictim(character)
                task.delay(PENDING_LIFETIME + 0.25, function()
                    if trackedHumanoids[hum] == info and not info.triggered then
                        for _, conn in ipairs(info.connections) do
                            pcall(function() conn:Disconnect() end)
                        end
                        trackedHumanoids[hum] = nil
                    end
                end)
            end
        end)
    end)
end

local function hookPlayer(player)
    if player == LP or playerConnections[player] then return end

    local conns = {}
    playerConnections[player] = conns

    conns[#conns + 1] = player.CharacterAdded:Connect(function(character)
        hookCharacter(player, character)
    end)

    -- DUELS can remove/replace the live Character without Humanoid.Died being
    -- observable on the client. CharacterRemoving fires early enough to keep
    -- the old position and pair it with GunKill / kill-counter confirmation.
    conns[#conns + 1] = player.CharacterRemoving:Connect(function(character)
        local hum = character and character:FindFirstChildOfClass("Humanoid")
        local info = hum and trackedHumanoids[hum]
        if hum and info and not info.triggered then
            info.deathAt = info.deathAt or os.clock()
            info.deathPosition = info.deathPosition or modelPosition(character)
            info.deathEligible = enabled and isEnemyPlayer(player)
            if info.deathEligible then
                queueVictimDeath(player, character, hum)
            end
        end
    end)

    local function refreshPlayerHumanoid()
        local character = player.Character
        local hum = character and character:FindFirstChildOfClass("Humanoid")
        if hum then refreshHumanoidDeathMode(player, hum) end
    end

    conns[#conns + 1] = player:GetPropertyChangedSignal("Team"):Connect(refreshPlayerHumanoid)
    conns[#conns + 1] = player:GetPropertyChangedSignal("TeamColor"):Connect(refreshPlayerHumanoid)
    conns[#conns + 1] = player:GetPropertyChangedSignal("Neutral"):Connect(refreshPlayerHumanoid)

    if player.Character then
        hookCharacter(player, player.Character)
    end
end

local function refreshAllTracked()
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LP then
            hookPlayer(player)
            local character = player.Character
            local hum = character and character:FindFirstChildOfClass("Humanoid")
            if hum then refreshHumanoidDeathMode(player, hum) end
        end
    end
end

-- ===== Local kill confirmations =============================================
local function looksLikeKillCounter(obj)
    if not (obj:IsA("IntValue") or obj:IsA("NumberValue")) then return false end
    local n = normalized(obj.Name)
    return n == "kills"
        or n == "kill"
        or n == "eliminations"
        or n == "elimination"
        or n == "elims"
        or n == "kos"
end

local function hookKillCounter(obj)
    if not looksLikeKillCounter(obj) or hookedKillValues[obj] then return end
    hookedKillValues[obj] = true

    local previous = tonumber(obj.Value) or 0
    local conn = obj:GetPropertyChangedSignal("Value"):Connect(function()
        local current = tonumber(obj.Value) or previous
        local delta = current - previous
        previous = current
        if delta > 0 then
            recordLocalKillSignal("contador " .. tostring(obj.Name), delta)
        end
    end)
    killSignalConnections[#killSignalConnections + 1] = conn
end

local function isKillConfirmSound(sound)
    if not sound:IsA("Sound") then return false end
    local n = normalized(sound.Name)
    local digits = tostring(sound.SoundId or ""):match("(%d+)")
    -- Confirmed native DUELS signal: DefaultGun.Handle.GunKill / 296102734.
    return n == "gunkill"
        or digits == "296102734"
        or n == "killconfirm"
        or n == "killsound"
        or n == "knifekill"
end

local function localOwnsKillSound(sound)
    local character = LP.Character
    local backpack = LP:FindFirstChildOfClass("Backpack")
    local function under(root)
        if not root then return false end
        local ok, yes = pcall(function() return sound:IsDescendantOf(root) end)
        return ok and yes == true
    end
    return under(character) or under(backpack)
end

local function hookKillSound(sound)
    if not isKillConfirmSound(sound) or hookedKillSounds[sound] then return end
    hookedKillSounds[sound] = true

    local wasLocal = localOwnsKillSound(sound)
    local function confirm()
        wasLocal = wasLocal or localOwnsKillSound(sound)
        if enabled and wasLocal then
            recordLocalKillSignal("sonido " .. tostring(sound.Name), 1)
        end
    end

    killSignalConnections[#killSignalConnections + 1] = sound.AncestryChanged:Connect(function()
        wasLocal = wasLocal or localOwnsKillSound(sound)
    end)
    killSignalConnections[#killSignalConnections + 1] = sound.Played:Connect(confirm)
    killSignalConnections[#killSignalConnections + 1] = sound:GetPropertyChangedSignal("Playing"):Connect(function()
        if sound.Playing then confirm() end
    end)

    if sound.Playing or sound.IsPlaying then confirm() end
end

local function scanLocalKillSignals(root)
    if not root then return end
    hookKillCounter(root)
    hookKillSound(root)
    for _, obj in ipairs(root:GetDescendants()) do
        hookKillCounter(obj)
        hookKillSound(obj)
    end
end

-- Death body watcher: only models CREATED after the script starts are remembered.
-- This avoids repeatedly scanning the whole Workspace on every kill.
killSignalConnections[#killSignalConnections + 1] = Workspace.DescendantAdded:Connect(function(obj)
    if obj:IsA("Model") then
        rememberDeathModel(obj)
    elseif obj:IsA("Humanoid") and obj.Parent and obj.Parent:IsA("Model") then
        rememberDeathModel(obj.Parent)
    elseif obj:IsA("BasePart") or obj:IsA("Accessory") or obj:IsA("Motor6D") then
        -- If DUELS builds a corpse inside an existing container, the Model itself
        -- may not be the descendant that triggered this event. Remember its ancestor.
        local model = obj:FindFirstAncestorOfClass("Model")
        if model and not isCurrentPlayerCharacter(model) then
            rememberDeathModel(model)
        end
    elseif obj:IsA("Sound") then
        -- DUELS can briefly clone GunKill outside the Character/Backpack tree.
        hookKillSound(obj)
    end
end)

scanLocalKillSignals(LP)
scanLocalKillSignals(LP.Character)
scanLocalKillSignals(LP:FindFirstChildOfClass("Backpack"))

killSignalConnections[#killSignalConnections + 1] = LP.DescendantAdded:Connect(function(obj)
    hookKillCounter(obj)
    hookKillSound(obj)
end)

killSignalConnections[#killSignalConnections + 1] = LP.CharacterAdded:Connect(function(character)
    task.defer(function()
        scanLocalKillSignals(character)
    end)
end)

for _, propertyName in ipairs({"Team", "TeamColor", "Neutral"}) do
    localTeamConnections[#localTeamConnections + 1] =
        LP:GetPropertyChangedSignal(propertyName):Connect(refreshAllTracked)
end

Players.PlayerAdded:Connect(hookPlayer)
Players.PlayerRemoving:Connect(function(player)
    local conns = playerConnections[player]
    if conns then
        for _, conn in ipairs(conns) do
            pcall(function() conn:Disconnect() end)
        end
        playerConnections[player] = nil
    end
end)

refreshAllTracked()

prev.MouseButton1Click:Connect(function()
    index -= 1
    if index < 1 then index = #EFFECTS end
    refresh()
    status.Text = "Efecto seleccionado: " .. tostring(selectedEffect())
end)

nxt.MouseButton1Click:Connect(function()
    index += 1
    if index > #EFFECTS then index = 1 end
    refresh()
    status.Text = "Efecto seleccionado: " .. tostring(selectedEffect())
end)

toggle.MouseButton1Click:Connect(function()
    enabled = not enabled
    toggle.Text = enabled and "MIS KILLS: ON" or "MIS KILLS: OFF"
    refreshAllTracked()

    if enabled then
        status.Text =
            "✓ Activo · " .. tostring(selectedEffect()) ..
            "\nTU kill → dummy/cadáver de DUELS → efecto."
    else
        for _, entry in ipairs(pendingDeaths) do
            removePending(entry)
        end
        table.clear(pendingDeaths)
        table.clear(recentKillCredits)
        table.clear(recentDeathModels)
        status.Text = "Desactivado · no se aplicarán efectos nuevos."
    end
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

print(
    "[Xero Death Effects R25 InstantStable]",
    #EFFECTS,
    "efectos ·",
    PRELOAD_STATS.loaded,
    "precargados ·",
    BASE
)

