--[[
XeroHub | DUELS Death Effects V2 Remote Lab

Expected GitHub layout:
death_effects/
  manifest.json
  effects/
    Frostbite.json
    ...

Default repo:
https://github.com/OnyxDevv/Onyx-web
branch: main
folder: death_effects

You can override before executing:
getgenv().XERO_DEATH_EFFECTS_BASE =
    "https://raw.githubusercontent.com/USER/REPO/BRANCH/death_effects"
]]

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local env = (getgenv and getgenv()) or _G
local BASE = env.XERO_DEATH_EFFECTS_BASE
    or "https://raw.githubusercontent.com/OnyxDevv/Onyx-web/main/death_effects"

local requestFn = (syn and syn.request) or (http and http.request) or http_request or request

local function httpGet(url)
    if requestFn then
        local ok, response = pcall(function()
            return requestFn({
                Url = url,
                Method = "GET",
                Headers = {
                    ["User-Agent"] = "XeroHub-DeathEffectsV2/1.0",
                    ["Accept"] = "application/json",
                },
            })
        end)
        if ok and response then
            local status = tonumber(response.StatusCode or response.Status or 0) or 0
            local body = response.Body or response.body
            if status >= 200 and status < 300 and type(body) == "string" then
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

local CACHE_FOLDER = "XeroHub/DeathEffectsV2"

local function ensureCacheFolder()
    if type(makefolder) ~= "function" then return false end
    pcall(function()
        if not isfolder or not isfolder("XeroHub") then makefolder("XeroHub") end
        if not isfolder or not isfolder(CACHE_FOLDER) then makefolder(CACHE_FOLDER) end
    end)
    return true
end

local function safeFileName(name)
    return tostring(name or ""):gsub("[^%w%._%-]", "_")
end

local function readCachedEffect(fileName)
    if type(isfile) ~= "function" or type(readfile) ~= "function" then return nil end
    local path = CACHE_FOLDER .. "/" .. safeFileName(fileName)
    if not isfile(path) then return nil end
    local ok, body = pcall(readfile, path)
    return ok and body or nil
end

local function writeCachedEffect(fileName, body)
    if type(writefile) ~= "function" or type(body) ~= "string" then return end
    ensureCacheFolder()
    pcall(writefile, CACHE_FOLDER .. "/" .. safeFileName(fileName), body)
end

local manifestBody = httpGet(BASE .. "/manifest.json")
if not manifestBody then
    error("Xero Death V2: no pude descargar manifest.json. Sube primero la carpeta death_effects al repo.")
end

local okManifest, manifest = pcall(function()
    return HttpService:JSONDecode(manifestBody)
end)
if not okManifest or type(manifest) ~= "table" or type(manifest.effects) ~= "table" then
    error("Xero Death V2: manifest inválido.")
end

local EFFECTS = {}
local EFFECT_BY_NAME = {}
for _, entry in ipairs(manifest.effects) do
    if type(entry) == "table" and type(entry.name) == "string" and type(entry.file) == "string" then
        EFFECTS[#EFFECTS + 1] = entry.name
        EFFECT_BY_NAME[entry.name] = entry
    end
end
table.sort(EFFECTS)

local activeRoot
local currentIndex = 1
local renderSerial = 0
local decodedCache = {}

local function safeDestroy(obj)
    if obj then pcall(function() obj:Destroy() end) end
end

local function fetchEffect(name)
    if decodedCache[name] then return decodedCache[name] end

    local entry = EFFECT_BY_NAME[name]
    if not entry then return nil, "No existe en manifest." end

    local body = readCachedEffect(entry.file)
    if not body then
        body = httpGet(BASE .. "/effects/" .. entry.file)
        if body then writeCachedEffect(entry.file, body) end
    end
    if not body then return nil, "No pude descargar " .. tostring(entry.file) end

    local ok, data = pcall(function()
        return HttpService:JSONDecode(body)
    end)
    if not ok or type(data) ~= "table" then
        return nil, "JSON inválido: " .. tostring(entry.file)
    end

    decodedCache[name] = data
    return data
end

local function decodeTyped(value)
    if type(value) ~= "table" then
        return value, true
    end

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
            pts[#pts+1] = NumberSequenceKeypoint.new(
                kp.time or 0, kp.value or 0, kp.envelope or 0
            )
        end
        if #pts >= 2 then return NumberSequence.new(pts), true end
        if #pts == 1 then return NumberSequence.new(pts[1].Value), true end
    elseif t == "ColorSequence" then
        local pts = {}
        for _, kp in ipairs(value.keypoints or {}) do
            local c = kp.color or {}
            pts[#pts+1] = ColorSequenceKeypoint.new(
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
        return UDim2.new(x.scale or 0, x.offset or 0, y.scale or 0, y.offset or 0), true
    elseif t == "Rect" then
        local mn, mx = value.min or {}, value.max or {}
        return Rect.new(mn.x or 0, mn.y or 0, mx.x or 0, mx.y or 0), true
    elseif t == "InstanceRef" then
        return value, "ref"
    end

    return nil, false
end

local function setAttributes(instance, attributes)
    for name, raw in pairs(attributes or {}) do
        local value, ok = decodeTyped(raw)
        if ok == true then
            pcall(function() instance:SetAttribute(name, value) end)
        elseif type(raw) ~= "table" then
            pcall(function() instance:SetAttribute(name, raw) end)
        end
    end
end

local function targetCFrame()
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if hrp then return hrp.CFrame * CFrame.new(0, -2.4, -7) end
    local cam = Workspace.CurrentCamera
    return cam and cam.CFrame * CFrame.new(0, 0, -10) or CFrame.new()
end

local function rawCFrame(raw)
    if type(raw) == "table" and raw.t == "CFrame" then
        local value, ok = decodeTyped(raw)
        if ok == true then return value end
    end
end

local function sourceAnchor(nodes)
    for _, node in ipairs(nodes) do
        if node.class == "Part" or node.class == "MeshPart" then
            local cf = rawCFrame((node.properties or {}).CFrame)
            if cf then return cf end
        end
    end
    return CFrame.new()
end

local SKIP_PROPERTIES = {
    Parent = true,
    WorldPivot = true,
    PhysicsRepRootRef = true,
    AudioContent = true,
    AnimationContent = true,
}

local function applyProperty(instance, propertyName, raw, transform)
    if SKIP_PROPERTIES[propertyName] then return end
    local value, ok = decodeTyped(raw)
    if ok ~= true then return end

    if propertyName == "CFrame" and instance:IsA("BasePart") and typeof(value) == "CFrame" then
        value = transform * value
    end

    pcall(function()
        instance[propertyName] = value
    end)
end

local function stabilize(root)
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
    for _, obj in ipairs(root:GetDescendants()) do one(obj) end
end

local function triggerParticles(root, serial)
    local emitters = {}
    if root:IsA("ParticleEmitter") then emitters[#emitters+1] = root end
    for _, obj in ipairs(root:GetDescendants()) do
        if obj:IsA("ParticleEmitter") then emitters[#emitters+1] = obj end
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
                    pcall(function() emitter:Emit(math.max(1, math.floor(count + .5))) end)
                end
                task.delay(duration, function()
                    if serial == renderSerial and emitter.Parent then
                        pcall(function() emitter.Enabled = false end)
                    end
                end)
            elseif count and count > 0 then
                pcall(function() emitter:Emit(math.max(1, math.floor(count + .5))) end)
            elseif not emitter.Enabled then
                local fallback = math.clamp(math.floor((emitter.Rate or 4) * .25 + .5), 1, 12)
                pcall(function() emitter:Emit(fallback) end)
            end
        end)
    end
end

local function triggerSounds(root)
    local played = 0
    local function one(sound)
        if played >= 5 or sound.SoundId == "" then return end
        played += 1
        pcall(function()
            sound.TimePosition = 0
            sound:Play()
        end)
    end
    if root:IsA("Sound") then one(root) end
    for _, obj in ipairs(root:GetDescendants()) do
        if obj:IsA("Sound") then one(obj) end
    end
end

local function renderEffect(name)
    renderSerial += 1
    local serial = renderSerial
    safeDestroy(activeRoot)
    activeRoot = nil

    local wrapper, fetchError = fetchEffect(name)
    if not wrapper then return false, fetchError end

    local snapshot = wrapper.snapshot
    local nodes = snapshot and snapshot.nodes
    if type(nodes) ~= "table" or #nodes == 0 then
        return false, "Snapshot vacío."
    end

    local transform = targetCFrame() * sourceAnchor(nodes):Inverse()

    local idMap = {}
    local deferredRefs = {}

    for _, node in ipairs(nodes) do
        local ok, obj = pcall(Instance.new, node.class)
        if ok and obj then
            idMap[node.id] = obj
            pcall(function() obj.Name = tostring(node.name or node.class) end)
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
                if type(raw) == "table" and raw.t == "InstanceRef" then
                    deferredRefs[#deferredRefs+1] = {
                        Object = obj,
                        Property = prop,
                        TargetId = raw.id,
                    }
                else
                    applyProperty(obj, prop, raw, transform)
                end
            end
        end
    end

    for _, ref in ipairs(deferredRefs) do
        local target = idMap[ref.TargetId]
        if ref.Object and target then
            pcall(function() ref.Object[ref.Property] = target end)
        end
    end

    local root = idMap[snapshot.rootId]
    if not root then
        for _, node in ipairs(nodes) do
            if idMap[node.id] then root = idMap[node.id] break end
        end
    end
    if not root then return false, "No pude crear root." end

    root.Name = "XeroV2Remote_" .. name
    root.Parent = Workspace
    activeRoot = root

    stabilize(root)
    triggerParticles(root, serial)
    triggerSounds(root)

    task.delay(12, function()
        if serial == renderSerial and activeRoot == root then
            safeDestroy(root)
            activeRoot = nil
        end
    end)

    local meta = wrapper.meta or snapshot.stats or {}
    return true, string.format(
        "%s · %s nodos · %s props · %s refs",
        name,
        tostring(meta.nodes or #nodes),
        tostring(meta.properties or "?"),
        tostring(meta.references or "?")
    )
end

-- Minimal UI
local old = PlayerGui:FindFirstChild("XeroDeathV2RemoteLab")
if old then old:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name = "XeroDeathV2RemoteLab"
gui.ResetOnSpawn = false
gui.Parent = PlayerGui

local frame = Instance.new("Frame")
frame.Size = UDim2.fromOffset(420, 190)
frame.Position = UDim2.new(.5, -210, .72, -95)
frame.BackgroundColor3 = Color3.fromRGB(12,12,12)
frame.BorderSizePixel = 0
frame.Parent = gui
Instance.new("UICorner", frame).CornerRadius = UDim.new(0,14)

local stroke = Instance.new("UIStroke", frame)
stroke.Color = Color3.fromRGB(55,55,55)
stroke.Transparency = .25

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Position = UDim2.fromOffset(16, 12)
title.Size = UDim2.new(1,-32,0,22)
title.Text = "XERO · DEATH EFFECT V2 REMOTE"
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
status.Position = UDim2.fromOffset(16, 142)
status.Size = UDim2.new(1,-32,0,30)
status.Text = tostring(#EFFECTS) .. " efectos desde GitHub"
status.TextColor3 = Color3.fromRGB(145,145,145)
status.Font = Enum.Font.Gotham
status.TextSize = 11
status.TextWrapped = true
status.TextXAlignment = Enum.TextXAlignment.Left
status.Parent = frame

local function button(txt, x, w)
    local b = Instance.new("TextButton")
    b.Size = UDim2.fromOffset(w, 36)
    b.Position = UDim2.fromOffset(x, 98)
    b.BackgroundColor3 = Color3.fromRGB(26,26,26)
    b.BorderSizePixel = 0
    b.Text = txt
    b.TextColor3 = Color3.fromRGB(235,235,235)
    b.Font = Enum.Font.GothamMedium
    b.TextSize = 12
    b.Parent = frame
    Instance.new("UICorner", b).CornerRadius = UDim.new(0,9)
    return b
end

local prev = button("‹", 16, 46)
local play = button("DESCARGAR / PROBAR", 70, 196)
local clear = button("LIMPIAR", 274, 82)
local nxt = button("›", 364, 40)

local function refresh()
    effectLabel.Text = EFFECTS[currentIndex] or "Sin efectos"
end
refresh()

prev.MouseButton1Click:Connect(function()
    currentIndex -= 1
    if currentIndex < 1 then currentIndex = #EFFECTS end
    refresh()
end)

nxt.MouseButton1Click:Connect(function()
    currentIndex += 1
    if currentIndex > #EFFECTS then currentIndex = 1 end
    refresh()
end)

play.MouseButton1Click:Connect(function()
    local name = EFFECTS[currentIndex]
    status.Text = "Descargando/reconstruyendo " .. tostring(name) .. "..."
    task.spawn(function()
        local ok, msg = renderEffect(name)
        status.Text = (ok and "✓ " or "✕ ") .. tostring(msg)
    end)
end)

clear.MouseButton1Click:Connect(function()
    renderSerial += 1
    safeDestroy(activeRoot)
    activeRoot = nil
    status.Text = "Preview limpiado."
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
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch) then
        local d = input.Position - dragStart
        frame.Position = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + d.X,
            startPos.Y.Scale, startPos.Y.Offset + d.Y
        )
    end
end)

print("[Xero Death V2 Remote] manifest:", #EFFECTS, "efectos ·", BASE)
