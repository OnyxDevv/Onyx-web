--[[
XeroHub | DUELS Death Effects FINAL Renderer Lab
Kev

Remote layout expected:
OnyxDevv/Onyx-web/main/death_effects_final/
  renderer_base/
    manifest.json
    v2/<Effect>.json
    v3/<Effect>.json
    v3_weak_reference/Frostbite.json

Default raw root:
https://raw.githubusercontent.com/OnyxDevv/Onyx-web/main/death_effects_final

Optional override BEFORE executing:
getgenv().XERO_DEATH_FINAL_ROOT =
    "https://raw.githubusercontent.com/USER/REPO/BRANCH/death_effects_final"

Behavior modes:
- v3_body_timeline     -> V2 assets + V3 body/material/clothing timeline
- v3_runtime_filtered  -> V2 assets + filtered V3 runtime + body timeline
- v2_primary           -> V2 only
- v2_primary_rescue    -> V2 only (Frostbite rescue)
]]

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local ENV = (getgenv and getgenv()) or _G
local ROOT = ENV.XERO_DEATH_FINAL_ROOT
    or "https://raw.githubusercontent.com/OnyxDevv/Onyx-web/main/death_effects_final"

local MANIFEST_URL = ROOT .. "/renderer_base/manifest.json"
local CACHE_FOLDER = "XeroHub/DeathEffectsFinalR1"

local requestFn = (syn and syn.request)
    or (http and http.request)
    or http_request
    or request

local function safeDestroy(obj)
    if obj then
        pcall(function() obj:Destroy() end)
    end
end

local function ensureCacheFolder()
    if type(makefolder) ~= "function" then return false end
    pcall(function()
        if not isfolder or not isfolder("XeroHub") then
            makefolder("XeroHub")
        end
        if not isfolder or not isfolder(CACHE_FOLDER) then
            makefolder(CACHE_FOLDER)
        end
    end)
    return true
end

local function safeFileName(path)
    return tostring(path or ""):gsub("[^%w%._%-]", "_")
end

local function readCache(path)
    if type(isfile) ~= "function" or type(readfile) ~= "function" then
        return nil
    end
    local file = CACHE_FOLDER .. "/" .. safeFileName(path)
    if not isfile(file) then return nil end
    local ok, data = pcall(readfile, file)
    return ok and data or nil
end

local function writeCache(path, body)
    if type(writefile) ~= "function" or type(body) ~= "string" then return end
    ensureCacheFolder()
    pcall(function()
        writefile(CACHE_FOLDER .. "/" .. safeFileName(path), body)
    end)
end

local function httpGet(url)
    if requestFn then
        local ok, response = pcall(function()
            return requestFn({
                Url = url,
                Method = "GET",
                Headers = {
                    ["User-Agent"] = "XeroHub-DeathFinalRenderer/1.0",
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

local function decodeJson(body)
    if type(body) ~= "string" then return nil end
    local ok, data = pcall(function()
        return HttpService:JSONDecode(body)
    end)
    return ok and data or nil
end

local manifestBody = httpGet(MANIFEST_URL)
if not manifestBody then
    error("Xero Final Renderer: no pude bajar renderer_base/manifest.json")
end

local manifest = decodeJson(manifestBody)
if type(manifest) ~= "table" or type(manifest.effects) ~= "table" then
    error("Xero Final Renderer: manifest inválido.")
end

local EFFECTS = {}
local EFFECT_BY_NAME = {}

for _, entry in ipairs(manifest.effects) do
    if type(entry) == "table"
        and type(entry.name) == "string"
        and type(entry.v2) == "string" then
        EFFECTS[#EFFECTS + 1] = entry.name
        EFFECT_BY_NAME[entry.name] = entry
    end
end

table.sort(EFFECTS, function(a, b)
    return string.lower(a) < string.lower(b)
end)

if #EFFECTS == 0 then
    error("Xero Final Renderer: manifest sin efectos.")
end

local decodedV2 = {}
local decodedV3 = {}

local function fetchPath(path, force)
    if type(path) ~= "string" or path == "" then
        return nil, "ruta vacía"
    end

    local body
    if not force then
        body = readCache(path)
    end

    if not body then
        body = httpGet(ROOT .. "/" .. path)
        if body then
            writeCache(path, body)
        end
    end

    if not body then
        return nil, "no pude descargar " .. path
    end

    local data = decodeJson(body)
    if type(data) ~= "table" then
        return nil, "JSON inválido: " .. path
    end

    return data
end

local function fetchV2(entry, force)
    local name = entry.name
    if not force and decodedV2[name] then
        return decodedV2[name]
    end

    local data, err = fetchPath(entry.v2, force)
    if not data then return nil, err end

    if tonumber(data.schemaVersion) ~= 2
        or type(data.snapshot) ~= "table"
        or type(data.snapshot.nodes) ~= "table"
        or #data.snapshot.nodes == 0 then
        return nil, "V2 inválido: " .. tostring(name)
    end

    decodedV2[name] = data
    return data
end

local function fetchV3(entry, force)
    local name = entry.name
    if not entry.v3 or entry.v3 == "" then
        return nil, "sin V3"
    end

    if not force and decodedV3[name] then
        return decodedV3[name]
    end

    local data, err = fetchPath(entry.v3, force)
    if not data then return nil, err end

    if tonumber(data.schemaVersion) ~= 3
        or type(data.behavior) ~= "table" then
        return nil, "V3 inválido: " .. tostring(name)
    end

    decodedV3[name] = data
    return data
end

-- ============================================================
-- Typed decoder
-- ============================================================

local function decodeTyped(value)
    if type(value) ~= "table" then
        return value, true
    end

    local t = value.t
    if not t then
        return value, true
    end

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
        return NumberRange.new(
            value.min or 0,
            value.max or value.min or 0
        ), true

    elseif t == "NumberSequence" then
        local points = {}
        local lastTime

        for _, kp in ipairs(value.keypoints or {}) do
            local time = math.clamp(tonumber(kp.time) or 0, 0, 1)
            local newPoint = NumberSequenceKeypoint.new(
                time,
                tonumber(kp.value) or 0,
                tonumber(kp.envelope) or 0
            )

            if lastTime and math.abs(time - lastTime) < 0.000001 then
                points[#points] = newPoint
            else
                points[#points + 1] = newPoint
                lastTime = time
            end
        end

        if #points == 1 then
            return NumberSequence.new(points[1].Value), true
        elseif #points >= 2 then
            local ok, seq = pcall(NumberSequence.new, points)
            if ok then return seq, true end
        end

    elseif t == "ColorSequence" then
        local points = {}
        local lastTime

        for _, kp in ipairs(value.keypoints or {}) do
            local c = kp.color or {}
            local time = math.clamp(tonumber(kp.time) or 0, 0, 1)
            local newPoint = ColorSequenceKeypoint.new(
                time,
                Color3.new(c.r or 0, c.g or 0, c.b or 0)
            )

            if lastTime and math.abs(time - lastTime) < 0.000001 then
                points[#points] = newPoint
            else
                points[#points + 1] = newPoint
                lastTime = time
            end
        end

        if #points == 1 then
            return ColorSequence.new(points[1].Value), true
        elseif #points >= 2 then
            local ok, seq = pcall(ColorSequence.new, points)
            if ok then return seq, true end
        end

    elseif t == "EnumItem" then
        local enumType = Enum[value.enum or ""]
        if enumType then
            local ok, item = pcall(function()
                return enumType[value.name or ""]
            end)
            if ok and item then
                return item, true
            end
        end

    elseif t == "BrickColor" then
        local ok, brick = pcall(
            BrickColor.new,
            value.name or "Medium stone grey"
        )
        if ok then return brick, true end

    elseif t == "UDim" then
        return UDim.new(value.scale or 0, value.offset or 0), true

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
            value.density or 0.7,
            value.friction or 0.3,
            value.elasticity or 0.5,
            value.frictionWeight or 1,
            value.elasticityWeight or 1
        )
        if ok then return result, true end

    elseif t == "Faces" then
        local items = {}
        for name in string.gmatch(tostring(value.v or ""), "[^,%s]+") do
            local ok, normal = pcall(function()
                return Enum.NormalId[name]
            end)
            if ok and normal then
                items[#items + 1] = normal
            end
        end

        if #items > 0 then
            local ok, faces = pcall(function()
                return Faces.new(table.unpack(items))
            end)
            if ok then return faces, true end
        end

    elseif t == "InstanceRef" then
        return value, "ref"
    end

    -- Content / InstanceHandle / hidden values are intentionally ignored.
    return nil, false
end

local function rawCFrame(raw)
    if type(raw) == "table" and raw.t == "CFrame" then
        local value, ok = decodeTyped(raw)
        if ok == true and typeof(value) == "CFrame" then
            return value
        end
    end
end

local function setAttributes(instance, attrs)
    for key, raw in pairs(attrs or {}) do
        local value, ok = decodeTyped(raw)
        if ok == true then
            pcall(function()
                instance:SetAttribute(key, value)
            end)
        elseif type(raw) ~= "table" then
            pcall(function()
                instance:SetAttribute(key, raw)
            end)
        end
    end
end

-- ============================================================
-- Dummy
-- ============================================================

local activeDummy
local effectRoots = {}
local renderSerial = 0

local function clearEffectRoots()
    for i = #effectRoots, 1, -1 do
        safeDestroy(effectRoots[i])
        effectRoots[i] = nil
    end
end

local function clearDummy()
    if activeDummy then
        safeDestroy(activeDummy)
        activeDummy = nil
    end
end

local function createDummy()
    clearDummy()

    local character = LocalPlayer.Character
    local ownHrp = character and character:FindFirstChild("HumanoidRootPart")

    if not character or not ownHrp then
        return nil, "tu personaje no está listo"
    end

    local oldArchivable = character.Archivable
    character.Archivable = true

    local ok, dummy = pcall(function()
        return character:Clone()
    end)

    character.Archivable = oldArchivable

    if not ok or not dummy then
        return nil, "no pude clonar tu avatar"
    end

    dummy.Name = "XeroFinalDeathDummy"

    for _, obj in ipairs(dummy:GetDescendants()) do
        if obj:IsA("LocalScript")
            or obj:IsA("Script")
            or obj:IsA("Tool")
            or obj:IsA("ForceField") then
            safeDestroy(obj)

        elseif obj:IsA("BasePart") then
            obj.CanCollide = false
            obj.CanTouch = false
            obj.CanQuery = false
            obj.Massless = true
        end
    end

    local humanoid = dummy:FindFirstChildOfClass("Humanoid")
    if humanoid then
        pcall(function()
            humanoid.DisplayDistanceType =
                Enum.HumanoidDisplayDistanceType.None
            humanoid.NameDisplayDistance = 0
            humanoid.HealthDisplayDistance = 0
            humanoid.BreakJointsOnDeath = false
            humanoid.AutoRotate = false
            humanoid.Health = humanoid.MaxHealth
        end)
    end

    local hrp = dummy:FindFirstChild("HumanoidRootPart")
    if not hrp then
        safeDestroy(dummy)
        return nil, "dummy sin HumanoidRootPart"
    end

    dummy.Parent = Workspace

    local dummyCF =
        ownHrp.CFrame
        * CFrame.new(0, 0, -8)
        * CFrame.Angles(0, math.rad(180), 0)

    pcall(function()
        dummy:PivotTo(dummyCF)
    end)

    hrp.Anchored = true
    hrp.Transparency = 1

    activeDummy = dummy
    return dummy
end

local function ensureDummy()
    if not activeDummy or not activeDummy.Parent then
        return createDummy()
    end
    return activeDummy
end

local function dummyRootCFrame()
    local dummy = activeDummy
    local hrp = dummy and dummy:FindFirstChild("HumanoidRootPart")
    if hrp then
        return hrp.CFrame
    end

    local character = LocalPlayer.Character
    local ownHrp = character and character:FindFirstChild("HumanoidRootPart")
    if ownHrp then
        return ownHrp.CFrame * CFrame.new(0, 0, -8)
    end

    local cam = Workspace.CurrentCamera
    return cam and cam.CFrame * CFrame.new(0, 0, -10) or CFrame.new()
end

local function restabilizeDummy()
    local dummy = activeDummy
    if not dummy then return end

    for _, obj in ipairs(dummy:GetDescendants()) do
        if obj:IsA("BasePart") then
            pcall(function()
                obj.CanCollide = false
                obj.CanTouch = false
                obj.CanQuery = false
            end)
        end
    end

    local hrp = dummy:FindFirstChild("HumanoidRootPart")
    if hrp then
        hrp.Anchored = true
    end
end

-- ============================================================
-- V2 reconstruction
-- ============================================================

local SKIP_V2_PROPERTIES = {
    Parent = true,
    WorldPivot = true,
    PhysicsRepRootRef = true,
    AudioContent = true,
    AnimationContent = true,
    TextureContent = true,
    MeshContent = true,

    WorldPosition = true,
    WorldOrientation = true,
    WorldCFrame = true,
    WorldAxis = true,
    WorldSecondaryAxis = true,
    TransformedWorldCFrame = true,

    PredictionMode = true,
    SourceAssetId = true,
    PropertyStatusStudio = true,
    SerializedOverrides = true,
    numExpectedDirectChildren = true,
    className = true,
    IsInSandbox = true,
    archivable = true,
    Attributes = true,
}

local function sourceAnchor(nodes)
    local byId = {}
    for _, node in ipairs(nodes) do
        byId[node.id] = node
    end

    for _, node in ipairs(nodes) do
        if node.class == "Model" then
            local raw = (node.properties or {}).PrimaryPart
            if type(raw) == "table" and raw.t == "InstanceRef" then
                local partNode = byId[raw.id]
                if partNode
                    and (partNode.class == "Part"
                        or partNode.class == "MeshPart"
                        or partNode.class == "UnionOperation") then
                    local cf = rawCFrame(
                        (partNode.properties or {}).CFrame
                    )
                    if cf then return cf end
                end
            end
        end
    end

    local bestNode
    local bestScore = -1

    for _, node in ipairs(nodes) do
        if node.class == "Part"
            or node.class == "MeshPart"
            or node.class == "UnionOperation" then

            local name = string.lower(tostring(node.name or ""))
            local score = 0

            if name == "effect" then score = 100
            elseif name == "weldtoroot" then score = 95
            elseif string.find(name, "root", 1, true) then score = 90
            elseif string.find(name, "maindeath", 1, true) then score = 88
            elseif string.find(name, "death", 1, true) then score = 80
            elseif string.find(name, "effect", 1, true) then score = 75
            end

            if score > bestScore
                and rawCFrame((node.properties or {}).CFrame) then
                bestScore = score
                bestNode = node
            end
        end
    end

    if bestNode then
        return rawCFrame((bestNode.properties or {}).CFrame)
    end

    for _, node in ipairs(nodes) do
        if node.class == "Part"
            or node.class == "MeshPart"
            or node.class == "UnionOperation" then
            local cf = rawCFrame((node.properties or {}).CFrame)
            if cf then return cf end
        end
    end

    return CFrame.new()
end

local function applyV2Property(instance, propertyName, raw, transform)
    if SKIP_V2_PROPERTIES[propertyName] then return end

    if instance:IsA("BasePart") then
        if propertyName == "Position"
            or propertyName == "Orientation"
            or propertyName == "Rotation" then
            return
        end
    end

    if (instance:IsA("Attachment") or instance:IsA("Bone"))
        and string.sub(propertyName, 1, 5) == "World" then
        return
    end

    local value, ok = decodeTyped(raw)
    if ok ~= true then return end

    if propertyName == "CFrame"
        and instance:IsA("BasePart")
        and typeof(value) == "CFrame" then
        value = transform * value
    end

    pcall(function()
        instance[propertyName] = value
    end)
end

local function stabilizeEffectRoot(root)
    local function one(obj)
        if obj:IsA("BasePart") then
            pcall(function()
                obj.Anchored = true
                obj.CanCollide = false
                obj.CanTouch = false
                obj.CanQuery = false
            end)
        end
    end

    one(root)
    for _, obj in ipairs(root:GetDescendants()) do
        one(obj)
    end
end

local function triggerParticles(root, serial)
    local emitters = {}

    if root:IsA("ParticleEmitter") then
        emitters[#emitters + 1] = root
    end

    for _, obj in ipairs(root:GetDescendants()) do
        if obj:IsA("ParticleEmitter") then
            emitters[#emitters + 1] = obj
        end
    end

    for _, emitter in ipairs(emitters) do
        local count = tonumber(emitter:GetAttribute("EmitCount"))
        local delayTime = tonumber(emitter:GetAttribute("EmitDelay")) or 0
        local duration = tonumber(emitter:GetAttribute("EmitDuration")) or 0

        task.delay(math.max(0, delayTime), function()
            if serial ~= renderSerial or not emitter.Parent then return end

            if duration > 0 then
                pcall(function() emitter.Enabled = true end)

                if count and count > 0 then
                    pcall(function()
                        emitter:Emit(math.max(1, math.floor(count + 0.5)))
                    end)
                end

                task.delay(duration, function()
                    if serial == renderSerial and emitter.Parent then
                        pcall(function() emitter.Enabled = false end)
                    end
                end)

            elseif count and count > 0 then
                pcall(function()
                    emitter:Emit(math.max(1, math.floor(count + 0.5)))
                end)

            elseif not emitter.Enabled then
                local fallback =
                    math.clamp(
                        math.floor((emitter.Rate or 4) * 0.25 + 0.5),
                        1,
                        16
                    )
                pcall(function() emitter:Emit(fallback) end)
            end
        end)
    end
end

local function triggerSounds(root)
    local played = 0

    local function one(sound)
        if played >= 8 or sound.SoundId == "" then return end
        played += 1

        pcall(function()
            sound.TimePosition = 0
            sound:Play()
        end)
    end

    if root:IsA("Sound") then one(root) end

    for _, obj in ipairs(root:GetDescendants()) do
        if obj:IsA("Sound") then
            one(obj)
        end
    end
end

local function triggerAnimations(root)
    local animator = root:FindFirstChildWhichIsA("Animator", true)

    if not animator then
        local controller =
            root:FindFirstChildWhichIsA("AnimationController", true)

        if controller then
            animator = Instance.new("Animator")
            animator.Parent = controller
        end
    end

    if not animator then return end

    local played = 0
    for _, obj in ipairs(root:GetDescendants()) do
        if obj:IsA("Animation") and obj.AnimationId ~= "" then
            played += 1
            if played > 8 then break end

            pcall(function()
                local track = animator:LoadAnimation(obj)
                track:Play(0.05)
            end)
        end
    end
end

local function buildV2Root(wrapper, serial)
    local snapshot = wrapper.snapshot
    local nodes = snapshot and snapshot.nodes

    if type(nodes) ~= "table" or #nodes == 0 then
        return nil, "snapshot V2 vacío"
    end

    local transform =
        dummyRootCFrame()
        * sourceAnchor(nodes):Inverse()

    local idMap = {}
    local deferredRefs = {}

    for _, node in ipairs(nodes) do
        local ok, obj = pcall(Instance.new, node.class)
        if ok and obj then
            idMap[node.id] = obj
            pcall(function()
                obj.Name = tostring(node.name or node.class)
            end)
        end
    end

    for _, node in ipairs(nodes) do
        local obj = idMap[node.id]
        local parent = node.parent and idMap[node.parent] or nil

        if obj and parent then
            pcall(function()
                obj.Parent = parent
            end)
        end
    end

    for _, node in ipairs(nodes) do
        local obj = idMap[node.id]
        if obj then
            setAttributes(obj, node.attributes)

            for prop, raw in pairs(node.properties or {}) do
                if type(raw) == "table" and raw.t == "InstanceRef" then
                    deferredRefs[#deferredRefs + 1] = {
                        object = obj,
                        property = prop,
                        targetId = raw.id,
                    }
                else
                    applyV2Property(obj, prop, raw, transform)
                end
            end

            for prop, raw in pairs(node.references or {}) do
                if type(raw) == "table" and raw.t == "InstanceRef" then
                    deferredRefs[#deferredRefs + 1] = {
                        object = obj,
                        property = prop,
                        targetId = raw.id,
                    }
                end
            end
        end
    end

    for _, ref in ipairs(deferredRefs) do
        local target = idMap[ref.targetId]
        if ref.object and target then
            pcall(function()
                ref.object[ref.property] = target
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
        return nil, "no pude crear root V2"
    end

    root.Parent = Workspace
    effectRoots[#effectRoots + 1] = root

    stabilizeEffectRoot(root)
    triggerParticles(root, serial)
    triggerSounds(root)
    triggerAnimations(root)

    return root
end

-- ============================================================
-- V3 body timeline
-- ============================================================

local function deepEqual(a, b, depth)
    if a == b then return true end
    if type(a) ~= type(b) then return false end
    if type(a) ~= "table" then return false end

    depth = (depth or 0) + 1
    if depth > 10 then return false end

    for key, value in pairs(a) do
        if not deepEqual(value, b[key], depth) then
            return false
        end
    end

    for key in pairs(b) do
        if a[key] == nil then
            return false
        end
    end

    return true
end

local function unescapeBodyName(name)
    name = tostring(name or "")
    name = name:gsub("%%2F", "/")
    name = name:gsub("%%%%", "%%")
    return name
end

local function parseBodySegment(segment)
    local name, className, index =
        tostring(segment):match("^(.-)<([^<>]+)>#(%d+)$")

    if not name then return nil end

    return {
        name = unescapeBodyName(name),
        className = className,
        index = tonumber(index) or 1,
    }
end

local function resolveBodyPath(root, path)
    if not root or type(path) ~= "string" then return nil end
    if path == "$BODY" then return root end

    local current = root
    local first = true

    for segment in string.gmatch(path, "[^/]+") do
        if first then
            first = false
            if segment ~= "$BODY" then
                return nil
            end
        else
            local info = parseBodySegment(segment)
            if not info then return nil end

            local found
            local fallback
            local count = 0

            for _, child in ipairs(current:GetChildren()) do
                if child.Name == info.name
                    and child.ClassName == info.className then
                    count += 1
                    fallback = fallback or child

                    if count == info.index then
                        found = child
                        break
                    end
                end
            end

            current = found or fallback
            if not current then return nil end
        end
    end

    return current
end

local function parentBodyPath(path)
    if type(path) ~= "string" then return "$BODY" end
    local parent = path:match("^(.*)/[^/]+$")
    return parent or "$BODY"
end

local function lastBodySegment(path)
    return tostring(path or ""):match("([^/]+)$")
end

local V3_SKIP_PROPERTIES = {
    Parent = true,
    BreakJointsOnDeath = true,
    UseJumpPower = true,

    CanCollide = true,
    CanTouch = true,
    CanQuery = true,
    Massless = true,
    RootPriority = true,

    WorldPosition = true,
    WorldOrientation = true,
    WorldCFrame = true,
    WorldAxis = true,
    WorldSecondaryAxis = true,
}

local function applyV3Property(obj, prop, raw)
    if V3_SKIP_PROPERTIES[prop] then return end

    if prop == "__attributes" then
        if type(raw) == "table" then
            setAttributes(obj, raw)
        end
        return
    end

    local value, ok = decodeTyped(raw)
    if ok ~= true then return end

    pcall(function()
        obj[prop] = value
    end)
end

local SAFE_ADDED_CLASSES = {
    Shirt = true,
    Pants = true,
    ShirtGraphic = true,
    BodyColors = true,
    SurfaceAppearance = true,
    SpecialMesh = true,
    Decal = true,
    Texture = true,
    Attachment = true,
    Vector3Value = true,
    StringValue = true,
    NumberValue = true,
    Color3Value = true,
    WrapLayer = true,
    WrapTarget = true,
}

local SAFE_REMOVABLE_CLASSES = {
    Shirt = true,
    Pants = true,
    ShirtGraphic = true,
    BodyColors = true,
    SurfaceAppearance = true,
    SpecialMesh = true,
    Decal = true,
    Texture = true,
    Attachment = true,
    Vector3Value = true,
    StringValue = true,
    NumberValue = true,
    Color3Value = true,
    WrapLayer = true,
    WrapTarget = true,
}

local function createTimelineObject(dummy, path, entry, created)
    if type(entry) ~= "table" then return nil end

    local className = tostring(entry.class or "")
    if not SAFE_ADDED_CLASSES[className] then
        return nil
    end

    local parent = resolveBodyPath(dummy, parentBodyPath(path))
    if not parent then return nil end

    local info = parseBodySegment(lastBodySegment(path))
    if not info then return nil end

    local ok, obj = pcall(Instance.new, className)
    if not ok or not obj then return nil end

    obj.Name = tostring(entry.name or info.name or className)
    obj.Parent = parent
    created[obj] = true

    for prop, raw in pairs(entry.props or {}) do
        applyV3Property(obj, prop, raw)
    end

    return obj
end

local function applyTimelineFrame(dummy, frame, state, created)
    local changed = frame.changed
    if type(changed) == "table" then
        for path, newEntry in pairs(changed) do
            if type(newEntry) == "table" then
                local obj = resolveBodyPath(dummy, path)
                local oldEntry = state[path]
                local oldProps =
                    type(oldEntry) == "table"
                    and type(oldEntry.props) == "table"
                    and oldEntry.props
                    or {}

                local newProps =
                    type(newEntry.props) == "table"
                    and newEntry.props
                    or {}

                if obj then
                    for prop, raw in pairs(newProps) do
                        if not deepEqual(oldProps[prop], raw) then
                            applyV3Property(obj, prop, raw)
                        end
                    end
                end

                state[path] = newEntry
            end
        end
    end

    local added = frame.added
    if type(added) == "table" then
        -- Parents normally appear before descendants in body traversal,
        -- but we do two passes to give nested cosmetics another chance.
        for pass = 1, 2 do
            for path, entry in pairs(added) do
                if not state[path] then
                    local obj =
                        resolveBodyPath(dummy, path)
                        or createTimelineObject(dummy, path, entry, created)

                    if obj then
                        for prop, raw in pairs(entry.props or {}) do
                            applyV3Property(obj, prop, raw)
                        end
                        state[path] = entry
                    end
                end
            end
        end
    end

    local removed = frame.removed
    if type(removed) == "table" then
        for _, path in ipairs(removed) do
            local obj = resolveBodyPath(dummy, path)

            if obj then
                if created[obj]
                    or SAFE_REMOVABLE_CLASSES[obj.ClassName] then
                    created[obj] = nil
                    safeDestroy(obj)
                end
            end

            state[path] = nil
        end
    end

    restabilizeDummy()
end

local function startBodyTimeline(v3, serial, onDone)
    local behavior = v3.behavior or {}
    local timeline = behavior.timeline

    if type(timeline) ~= "table" or #timeline == 0 then
        if onDone then onDone(0) end
        return
    end

    local dummy = activeDummy
    if not dummy or not dummy.Parent then
        if onDone then onDone(0) end
        return
    end

    local state = {}
    for path, entry in pairs(behavior.baseline or {}) do
        state[path] = entry
    end

    local created = setmetatable({}, {__mode = "k"})

    task.spawn(function()
        local started = os.clock()
        local applied = 0

        table.sort(timeline, function(a, b)
            return (tonumber(a.t) or 0) < (tonumber(b.t) or 0)
        end)

        for _, frame in ipairs(timeline) do
            if serial ~= renderSerial
                or not dummy.Parent then
                return
            end

            local targetTime = tonumber(frame.t) or 0
            local remaining = targetTime - (os.clock() - started)

            if remaining > 0 then
                task.wait(remaining)
            end

            if serial ~= renderSerial
                or not dummy.Parent then
                return
            end

            applyTimelineFrame(dummy, frame, state, created)
            applied += 1
        end

        if onDone and serial == renderSerial then
            onDone(applied)
        end
    end)
end

-- ============================================================
-- V3 runtime roots
-- ============================================================

local RUNTIME_SKIP = {
    Parent = true,
    __attributes = true,
}

local function buildRuntimeRoot(snapshot, serial)
    local nodes = snapshot and snapshot.nodes
    if type(nodes) ~= "table" or #nodes == 0 then return nil end

    local idMap = {}
    local deferredRefs = {}
    local baseCF = dummyRootCFrame()

    for _, node in ipairs(nodes) do
        local ok, obj = pcall(Instance.new, node.class)
        if ok and obj then
            idMap[node.id] = obj
            pcall(function()
                obj.Name = tostring(node.name or node.class)
            end)
        end
    end

    for _, node in ipairs(nodes) do
        local obj = idMap[node.id]
        local parent = node.parent and idMap[node.parent] or nil

        if obj and parent then
            pcall(function() obj.Parent = parent end)
        end
    end

    for _, node in ipairs(nodes) do
        local obj = idMap[node.id]
        if obj then
            setAttributes(obj, node.attributes)

            for prop, raw in pairs(node.properties or {}) do
                if not RUNTIME_SKIP[prop] then
                    if prop == "RelativeCFrame"
                        and obj:IsA("BasePart") then
                        local rel = rawCFrame(raw)
                        if rel then
                            pcall(function()
                                obj.CFrame = baseCF * rel
                            end)
                        end

                    elseif type(raw) == "table"
                        and raw.t == "InstanceRef" then
                        deferredRefs[#deferredRefs + 1] = {
                            object = obj,
                            property = prop,
                            targetId = raw.id,
                        }

                    else
                        local value, ok = decodeTyped(raw)
                        if ok == true then
                            pcall(function()
                                obj[prop] = value
                            end)
                        end
                    end
                end
            end

            for prop, raw in pairs(node.references or {}) do
                if type(raw) == "table" and raw.t == "InstanceRef" then
                    deferredRefs[#deferredRefs + 1] = {
                        object = obj,
                        property = prop,
                        targetId = raw.id,
                    }
                end
            end
        end
    end

    for _, ref in ipairs(deferredRefs) do
        local target = idMap[ref.targetId]
        if ref.object and target then
            pcall(function()
                ref.object[ref.property] = target
            end)
        end
    end

    local root = idMap[1]
    if not root then
        for _, node in ipairs(nodes) do
            if idMap[node.id] then
                root = idMap[node.id]
                break
            end
        end
    end

    if not root then return nil end

    root.Parent = Workspace
    effectRoots[#effectRoots + 1] = root

    stabilizeEffectRoot(root)
    triggerParticles(root, serial)
    triggerSounds(root)
    triggerAnimations(root)

    return root
end

local function startRuntimeTimeline(v3, serial)
    local roots = (v3.behavior or {}).runtimeRoots
    if type(roots) ~= "table" or #roots == 0 then return end

    for _, snapshot in ipairs(roots) do
        local delayTime = math.max(0, tonumber(snapshot.t) or 0)

        task.delay(delayTime, function()
            if serial ~= renderSerial then return end
            buildRuntimeRoot(snapshot, serial)
        end)
    end
end

-- ============================================================
-- Render controller
-- ============================================================

local useV3 = true
local currentIndex = 1
local statusLabel
local modeLabel
local effectLabel
local searchBox
local v3Button

for i, name in ipairs(EFFECTS) do
    if name == "Frostbite" then
        currentIndex = i
        break
    end
end

local MODE_NAMES = {
    v3_body_timeline = "V2 + V3 BODY",
    v3_runtime_filtered = "V2 + V3 RUNTIME",
    v2_primary = "V2 PRIMARY",
    v2_primary_rescue = "V2 RESCUE",
}

local function currentEntry()
    return EFFECT_BY_NAME[EFFECTS[currentIndex]]
end

local function refreshLabels()
    local name = EFFECTS[currentIndex] or "?"
    local entry = EFFECT_BY_NAME[name] or {}

    if effectLabel then
        effectLabel.Text = name
    end

    if modeLabel then
        local q = tonumber(entry.qualityV4) or 0
        local mode =
            MODE_NAMES[entry.behaviorMode]
            or tostring(entry.behaviorMode or "V2")

        modeLabel.Text =
            string.format(
                "%s  ·  Q%d  ·  %d/%d",
                mode,
                q,
                currentIndex,
                #EFFECTS
            )
    end

    if searchBox and not searchBox:IsFocused() then
        searchBox.Text = ""
        searchBox.PlaceholderText = "Buscar efecto..."
    end
end

local function selectBySearch(query)
    query = string.lower(tostring(query or ""))
    if query == "" then return false end

    for i, name in ipairs(EFFECTS) do
        if string.find(string.lower(name), query, 1, true) then
            currentIndex = i
            refreshLabels()
            return true
        end
    end

    return false
end

local function renderCurrent(forceRemote)
    renderSerial += 1
    local serial = renderSerial

    clearEffectRoots()
    clearDummy()

    local name = EFFECTS[currentIndex]
    local entry = EFFECT_BY_NAME[name]

    if not entry then
        return false, "entrada no encontrada"
    end

    if statusLabel then
        statusLabel.Text = "Preparando " .. name .. "..."
    end

    local dummy, dummyErr = createDummy()
    if not dummy then
        return false, dummyErr
    end

    local v2, v2Err = fetchV2(entry, forceRemote)
    if not v2 then
        return false, v2Err
    end

    local v2Root, buildErr = buildV2Root(v2, serial)
    if not v2Root then
        return false, buildErr
    end

    local mode = tostring(entry.behaviorMode or "v2_primary")
    local wantsV3 =
        useV3
        and (
            mode == "v3_body_timeline"
            or mode == "v3_runtime_filtered"
        )

    local v3Started = false

    if wantsV3 then
        local v3 = fetchV3(entry, forceRemote)

        if v3 then
            v3Started = true

            startBodyTimeline(v3, serial, function(frames)
                if statusLabel
                    and serial == renderSerial then
                    statusLabel.Text =
                        string.format(
                            "✓ %s · V3 aplicado (%d frames)",
                            name,
                            frames
                        )
                end
            end)

            local collectorVersion =
                tostring((v3.meta or {}).collectorVersion or "")

            if mode == "v3_runtime_filtered"
                or string.sub(collectorVersion, 1, 3) == "3.4" then
                startRuntimeTimeline(v3, serial)
            end
        end
    end

    if statusLabel then
        if mode == "v2_primary_rescue" then
            statusLabel.Text =
                "✓ " .. name .. " · Frostbite rescue V2"

        elseif wantsV3 and not v3Started then
            statusLabel.Text =
                "✓ " .. name .. " · V2 OK · V3 no disponible"

        elseif not wantsV3 then
            statusLabel.Text =
                "✓ " .. name .. " · V2"

        else
            statusLabel.Text =
                "✓ " .. name .. " · V2 + V3 iniciados"
        end
    end

    task.delay(14, function()
        if serial == renderSerial then
            clearEffectRoots()
        end
    end)

    return true
end

-- ============================================================
-- Compact UI
-- ============================================================

local oldGui = PlayerGui:FindFirstChild("XeroFinalDeathRenderer")
if oldGui then
    oldGui:Destroy()
end

local gui = Instance.new("ScreenGui")
gui.Name = "XeroFinalDeathRenderer"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.Parent = PlayerGui

local frame = Instance.new("Frame")
frame.Name = "Main"
frame.Size = UDim2.fromOffset(430, 286)
frame.Position = UDim2.new(0.5, -215, 0.72, -143)
frame.BackgroundColor3 = Color3.fromRGB(11, 11, 11)
frame.BorderSizePixel = 0
frame.Parent = gui
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 14)

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(58, 58, 58)
stroke.Transparency = 0.25
stroke.Parent = frame

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Position = UDim2.fromOffset(16, 12)
title.Size = UDim2.new(1, -32, 0, 22)
title.Text = "XERO · FINAL DEATH EFFECTS"
title.TextColor3 = Color3.fromRGB(245, 245, 245)
title.Font = Enum.Font.GothamBold
title.TextSize = 14
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = frame

searchBox = Instance.new("TextBox")
searchBox.Position = UDim2.fromOffset(16, 44)
searchBox.Size = UDim2.new(1, -32, 0, 34)
searchBox.BackgroundColor3 = Color3.fromRGB(21, 21, 21)
searchBox.BorderSizePixel = 0
searchBox.PlaceholderText = "Buscar efecto..."
searchBox.PlaceholderColor3 = Color3.fromRGB(110, 110, 110)
searchBox.Text = ""
searchBox.TextColor3 = Color3.fromRGB(235, 235, 235)
searchBox.ClearTextOnFocus = false
searchBox.Font = Enum.Font.Gotham
searchBox.TextSize = 12
searchBox.Parent = frame
Instance.new("UICorner", searchBox).CornerRadius = UDim.new(0, 9)

effectLabel = Instance.new("TextLabel")
effectLabel.BackgroundTransparency = 1
effectLabel.Position = UDim2.fromOffset(16, 88)
effectLabel.Size = UDim2.new(1, -32, 0, 24)
effectLabel.TextColor3 = Color3.fromRGB(245, 245, 245)
effectLabel.Font = Enum.Font.GothamBold
effectLabel.TextSize = 16
effectLabel.TextXAlignment = Enum.TextXAlignment.Left
effectLabel.Parent = frame

modeLabel = Instance.new("TextLabel")
modeLabel.BackgroundTransparency = 1
modeLabel.Position = UDim2.fromOffset(16, 112)
modeLabel.Size = UDim2.new(1, -32, 0, 18)
modeLabel.TextColor3 = Color3.fromRGB(145, 145, 145)
modeLabel.Font = Enum.Font.Gotham
modeLabel.TextSize = 10
modeLabel.TextXAlignment = Enum.TextXAlignment.Left
modeLabel.Parent = frame

local function makeButton(text, x, y, w, h)
    local button = Instance.new("TextButton")
    button.Position = UDim2.fromOffset(x, y)
    button.Size = UDim2.fromOffset(w, h)
    button.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    button.BorderSizePixel = 0
    button.Text = text
    button.TextColor3 = Color3.fromRGB(235, 235, 235)
    button.Font = Enum.Font.GothamMedium
    button.TextSize = 11
    button.AutoButtonColor = true
    button.Parent = frame
    Instance.new("UICorner", button).CornerRadius = UDim.new(0, 9)
    return button
end

local prevButton = makeButton("‹", 16, 140, 44, 38)
local playButton = makeButton("PROBAR", 68, 140, 190, 38)
local nextButton = makeButton("›", 266, 140, 44, 38)
v3Button = makeButton("V3: ON", 318, 140, 96, 38)

local dummyButton = makeButton("RECREAR DUMMY", 16, 188, 150, 34)
local clearButton = makeButton("LIMPIAR", 174, 188, 100, 34)
local reloadButton = makeButton("RECARGAR JSON", 282, 188, 132, 34)

statusLabel = Instance.new("TextLabel")
statusLabel.BackgroundTransparency = 1
statusLabel.Position = UDim2.fromOffset(16, 232)
statusLabel.Size = UDim2.new(1, -32, 0, 38)
statusLabel.Text =
    tostring(#EFFECTS)
    .. " efectos · Frostbite seleccionado por defecto"
statusLabel.TextColor3 = Color3.fromRGB(145, 145, 145)
statusLabel.Font = Enum.Font.Gotham
statusLabel.TextSize = 10
statusLabel.TextWrapped = true
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.TextYAlignment = Enum.TextYAlignment.Top
statusLabel.Parent = frame

refreshLabels()

searchBox.FocusLost:Connect(function(enterPressed)
    local query = searchBox.Text

    if query ~= "" then
        local found = selectBySearch(query)
        if not found then
            statusLabel.Text =
                "No encontré efecto con: " .. tostring(query)
        elseif enterPressed then
            task.spawn(function()
                local ok, err = renderCurrent(false)
                if not ok then
                    statusLabel.Text = "✕ " .. tostring(err)
                end
            end)
        end
    end
end)

prevButton.MouseButton1Click:Connect(function()
    currentIndex -= 1
    if currentIndex < 1 then
        currentIndex = #EFFECTS
    end
    refreshLabels()
end)

nextButton.MouseButton1Click:Connect(function()
    currentIndex += 1
    if currentIndex > #EFFECTS then
        currentIndex = 1
    end
    refreshLabels()
end)

playButton.MouseButton1Click:Connect(function()
    task.spawn(function()
        local ok, err = renderCurrent(false)
        if not ok then
            statusLabel.Text = "✕ " .. tostring(err)
        end
    end)
end)

v3Button.MouseButton1Click:Connect(function()
    useV3 = not useV3
    v3Button.Text = useV3 and "V3: ON" or "V3: OFF"
    statusLabel.Text =
        useV3
        and "V3 timeline activado."
        or "V3 desactivado: sólo V2."
end)

dummyButton.MouseButton1Click:Connect(function()
    renderSerial += 1
    clearEffectRoots()

    local dummy, err = createDummy()
    statusLabel.Text =
        dummy
        and "✓ Dummy recreado."
        or ("✕ " .. tostring(err))
end)

clearButton.MouseButton1Click:Connect(function()
    renderSerial += 1
    clearEffectRoots()
    clearDummy()
    statusLabel.Text = "Preview limpiado."
end)

reloadButton.MouseButton1Click:Connect(function()
    decodedV2 = {}
    decodedV3 = {}

    statusLabel.Text =
        "Recargando JSON remoto para "
        .. tostring(EFFECTS[currentIndex])
        .. "..."

    task.spawn(function()
        local ok, err = renderCurrent(true)
        if not ok then
            statusLabel.Text = "✕ " .. tostring(err)
        end
    end)
end)

-- Drag
local dragging = false
local dragStart
local startPosition

frame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPosition = frame.Position
    end
end)

frame.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if dragging
        and (
            input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch
        ) then

        local delta = input.Position - dragStart

        frame.Position = UDim2.new(
            startPosition.X.Scale,
            startPosition.X.Offset + delta.X,
            startPosition.Y.Scale,
            startPosition.Y.Offset + delta.Y
        )
    end
end)

task.defer(function()
    local dummy, err = createDummy()

    if dummy then
        statusLabel.Text =
            tostring(#EFFECTS)
            .. " efectos · ✓ dummy listo · prueba Frostbite"
    else
        statusLabel.Text =
            "✕ Dummy: " .. tostring(err)
    end
end)
