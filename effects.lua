-- XeroHub | Remote Death Effect Test Hub | Kev
-- Compact / draggable / remote catalog.
-- Loads effect dumps from GitHub on demand and ALWAYS uses FORCE VFX.
-- No ReplicatedSkins root required.

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local Debris = game:GetService("Debris")

local LP = Players.LocalPlayer
if not LP then return end

local BASE_URL = "https://raw.githubusercontent.com/OnyxDevv/Onyx-web/main/death_effects"
local MANIFEST_URL = BASE_URL .. "/manifest.json"

local ENV = (getgenv and getgenv()) or _G
if ENV.__XERO_REMOTE_DEATH_EFFECT_HUB and ENV.__XERO_REMOTE_DEATH_EFFECT_HUB.Destroy then
    pcall(ENV.__XERO_REMOTE_DEATH_EFFECT_HUB.Destroy)
end

local App = {
    Alive = true,
    Connections = {},
    Spawned = {},
    Cache = {},
    Manifest = nil,
    Selected = nil,
    Search = "",
}
ENV.__XERO_REMOTE_DEATH_EFFECT_HUB = App

local function track(c)
    if c then App.Connections[#App.Connections + 1] = c end
    return c
end

local function requestText(url)
    local req = (syn and syn.request) or (http and http.request) or http_request or request
    if req then
        local ok, response = pcall(function()
            return req({
                Url = url,
                Method = "GET",
                Headers = {
                    ["User-Agent"] = "Roblox/XeroHub-DeathEffects"
                }
            })
        end)
        if ok and response then
            local status = tonumber(response.StatusCode or response.Status) or (response.Success and 200)
            local body = response.Body or response.body
            if status and status >= 200 and status < 300 and type(body) == "string" then
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

    return nil, "HTTP failed: " .. tostring(url)
end

local function fetchJson(url)
    local body, err = requestText(url)
    if not body then return nil, err end

    local ok, decoded = pcall(function()
        return HttpService:JSONDecode(body)
    end)
    if not ok then
        return nil, "JSON inválido: " .. tostring(decoded)
    end
    return decoded
end

local function loadManifest()
    if App.Manifest then return App.Manifest end
    local data, err = fetchJson(MANIFEST_URL)
    if not data then return nil, err end
    if type(data.effects) ~= "table" then
        return nil, "manifest.json no trae effects[]"
    end
    App.Manifest = data
    return data
end

local function loadEffect(meta)
    if App.Cache[meta.name] then
        return App.Cache[meta.name]
    end

    local url = BASE_URL .. "/effects/" .. tostring(meta.file or (meta.name .. ".json"))
    local data, err = fetchJson(url)
    if not data then return nil, err end

    App.Cache[meta.name] = data
    return data
end

local function trim(s)
    return tostring(s or ""):match("^%s*(.-)%s*$")
end

local function numberTokens(s)
    local out = {}
    for token in tostring(s or ""):gmatch("[^,%s]+") do
        local n = tonumber(token)
        if n then out[#out + 1] = n end
    end
    return out
end

local function parseEnum(raw)
    local enumType, enumItem = tostring(raw):match("^Enum%.([^.]+)%.(.+)$")
    if not enumType then return nil end
    local ok, value = pcall(function() return Enum[enumType][enumItem] end)
    return ok and value or nil
end

local function parseColor3(raw)
    local r,g,b = tostring(raw):match("^Color3%(([-%d%.eE]+),([-%d%.eE]+),([-%d%.eE]+)%)$")
    if r then return Color3.fromRGB(tonumber(r) or 0, tonumber(g) or 0, tonumber(b) or 0) end
end

local function parseVector3(raw)
    local n = numberTokens(raw)
    if #n >= 3 then return Vector3.new(n[1],n[2],n[3]) end
end

local function parseVector2(raw)
    local n = numberTokens(raw)
    if #n >= 2 then return Vector2.new(n[1],n[2]) end
end

local function parseNumberRange(raw)
    local n = numberTokens(raw)
    if #n >= 2 then return NumberRange.new(n[1],n[2]) end
    if #n == 1 then return NumberRange.new(n[1]) end
end

local function parseNumberSequence(raw)
    local n = numberTokens(raw)
    if #n < 3 then return nil end
    local kp = {}
    for i = 1, #n - 2, 3 do
        kp[#kp+1] = NumberSequenceKeypoint.new(n[i],n[i+1],n[i+2])
    end
    local ok, seq = pcall(NumberSequence.new, kp)
    return ok and seq or nil
end

local function parseColorSequence(raw)
    local n = numberTokens(raw)
    if #n < 5 then return nil end
    local kp = {}
    for i = 1, #n - 4, 5 do
        kp[#kp+1] = ColorSequenceKeypoint.new(
            n[i],
            Color3.new(n[i+1],n[i+2],n[i+3])
        )
    end
    local ok, seq = pcall(ColorSequence.new, kp)
    return ok and seq or nil
end

local vector3Props = {
    Size=true, Position=true, Orientation=true, Axis=true, SecondaryAxis=true,
    Acceleration=true, Scale=true, Offset=true, VertexColor=true,
}
local vector2Props = {SpreadAngle=true}
local numberRangeProps = {Lifetime=true,Speed=true,Rotation=true,RotSpeed=true}
local numberSequenceProps = {Transparency=true,Size=true,Squash=true,WidthScale=true}
local color3Props = {FillColor=true,OutlineColor=true,SparkleColor=true}

local function parseGeneric(raw)
    raw = trim(raw)
    if raw == "true" then return true end
    if raw == "false" then return false end
    if raw == "nil" then return nil end

    local quoted = raw:match('^"(.*)"$')
    if quoted ~= nil then return quoted end

    local enum = parseEnum(raw)
    if enum ~= nil then return enum end

    local color = parseColor3(raw)
    if color ~= nil then return color end

    local n = tonumber(raw)
    if n ~= nil then return n end

    return raw
end

local function parseProperty(className, property, raw)
    if property == "Color" then
        local c3 = parseColor3(raw)
        if c3 then return c3 end
        if className == "ParticleEmitter" or className == "Trail" or className == "Beam" then
            return parseColorSequence(raw)
        end
    end

    if color3Props[property] then return parseColor3(raw) end
    if vector3Props[property] then return parseVector3(raw) end
    if vector2Props[property] then return parseVector2(raw) end
    if numberRangeProps[property] then return parseNumberRange(raw) end
    if numberSequenceProps[property] then return parseNumberSequence(raw) end
    if className == "Vector3Value" and property == "Value" then return parseVector3(raw) end
    return parseGeneric(raw)
end

local function safeSet(obj, prop, value)
    if value == nil then return end
    pcall(function() obj[prop] = value end)
end

local supported = {
    Folder=true,Model=true,Part=true,MeshPart=true,UnionOperation=true,
    Attachment=true,Bone=true,ParticleEmitter=true,Sound=true,Trail=true,
    Beam=true,Highlight=true,SpecialMesh=true,Vector3Value=true,CFrameValue=true,
    BoolValue=true,NumberValue=true,StringValue=true,IntValue=true,
    Fire=true,Smoke=true,Sparkles=true,PointLight=true,SpotLight=true,SurfaceLight=true,
}

local function leaf(path)
    return tostring(path):match("([^.]+)$") or tostring(path)
end

local function parentPath(path)
    return tostring(path):match("^(.*)%.[^.]+$")
end

local function addPath(map, path, obj)
    map[path] = map[path] or {}
    table.insert(map[path], obj)
end

local function latestPath(map, path)
    local list = map[path]
    return list and list[#list] or nil
end

local function instantiate(className)
    if not supported[className] then return nil end
    local ok, obj = pcall(Instance.new, className)
    return ok and obj or nil
end

local function applyProps(obj, entry)
    if type(entry.r) == "table" then
        for prop, raw in pairs(entry.r) do
            safeSet(obj, prop, parseProperty(entry.c, prop, raw))
        end
    end
    if type(entry.a) == "table" then
        for key, raw in pairs(entry.a) do
            local value = parseGeneric(raw)
            if value ~= nil then
                pcall(function() obj:SetAttribute(key, value) end)
            end
        end
    end
end

local function buildEffect(def)
    if type(def) ~= "table" or type(def.entries) ~= "table" or #def.entries == 0 then
        return nil, "Effect sin entries reconstruibles."
    end

    local first = def.entries[1]
    local root = instantiate(first.c) or Instance.new("Folder")
    root.Name = def.name or leaf(first.p)
    applyProps(root, first)

    local pathMap = {}
    addPath(pathMap, first.p, root)

    for i = 2, #def.entries do
        local entry = def.entries[i]
        local obj = instantiate(entry.c)
        if obj then
            obj.Name = leaf(entry.p)
            obj.Parent = latestPath(pathMap, parentPath(entry.p)) or root
            addPath(pathMap, entry.p, obj)
            applyProps(obj, entry)

            if obj:IsA("BasePart") then
                obj.CanCollide = false
                obj.CanTouch = false
                obj.CanQuery = false
            end
        end
    end

    return root
end

local BODY_STYLE = {
    BlackvalkEffect={Color=Color3.fromRGB(255,190,60),Material=Enum.Material.Neon},
    Freeze={Color=Color3.fromRGB(4,175,236),Material=Enum.Material.SmoothPlastic},
    Frostbite={Color=Color3.fromRGB(53,124,133),Material=Enum.Material.SmoothPlastic},
    Heartache={Color=Color3.fromRGB(255,0,0),Material=Enum.Material.Plastic},
    Heartbeat={Color=Color3.fromRGB(255,102,204),Material=Enum.Material.Neon,Transparency=.2},
    IcemanEffect={Color=Color3.fromRGB(152,219,255),Material=Enum.Material.Ice},
    LEffect={Color=Color3.fromRGB(255,43,44),Material=Enum.Material.Neon},
    LavaEffect={Color=Color3.fromRGB(255,60,0),Material=Enum.Material.Neon},
    PhoenixEffect={Color=Color3.fromRGB(255,80,35),Material=Enum.Material.Neon},
    SandEffect={Color=Color3.fromRGB(212,196,154),Material=Enum.Material.Sand},
    SlimeEffect={Color=Color3.fromRGB(85,255,127),Material=Enum.Material.Plastic},
    SpiritOverload={Color=Color3.fromRGB(0,48,8),Material=Enum.Material.SmoothPlastic},
}

local function getChar()
    local c = LP.Character
    if c and c.Parent then return c end
    return LP.CharacterAdded:Wait()
end

local function anchorOf(model)
    return model:FindFirstChild("HumanoidRootPart")
        or model:FindFirstChild("LowerTorso")
        or model:FindFirstChild("UpperTorso")
        or model:FindFirstChild("Torso")
        or model:FindFirstChild("Head")
end

local function makeDummy()
    local char = getChar()
    if not char then return nil,"No character." end

    local old = char.Archivable
    char.Archivable = true
    local ok,dummy = pcall(function() return char:Clone() end)
    char.Archivable = old
    if not ok or not dummy then return nil,"No pude clonar character." end

    dummy.Name = "Xero_RemoteDeathEffectDummy"
    for _,obj in ipairs(dummy:GetDescendants()) do
        if obj:IsA("Script") or obj:IsA("LocalScript") or obj:IsA("Tool") then
            obj:Destroy()
        elseif obj:IsA("BasePart") then
            obj.Anchored = true
            obj.CanCollide = false
            obj.CanTouch = false
            obj.CanQuery = false
        elseif obj:IsA("Humanoid") then
            obj.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
            obj.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
        end
    end
    dummy.Parent = Workspace

    local anchor = anchorOf(char)
    if anchor then
        pcall(function() dummy:PivotTo(anchor.CFrame * CFrame.new(0,0,-7)) end)
    end

    table.insert(App.Spawned,dummy)
    Debris:AddItem(dummy,18)
    return dummy
end

local function applyBodyStyle(dummy,name)
    local style = BODY_STYLE[name]
    if not style then return end
    for _,obj in ipairs(dummy:GetDescendants()) do
        if obj:IsA("BasePart") and obj.Name ~= "HumanoidRootPart" then
            if style.Color then obj.Color = style.Color end
            if style.Material then obj.Material = style.Material end
            if style.Transparency ~= nil then obj.Transparency = style.Transparency end
        end
    end
end

local function baseParts(root)
    local out = {}
    if root:IsA("BasePart") then out[#out+1] = root end
    for _,o in ipairs(root:GetDescendants()) do
        if o:IsA("BasePart") then out[#out+1] = o end
    end
    return out
end

local function referencePart(root)
    if root:IsA("BasePart") then return root end
    local first,preferred
    for _,part in ipairs(baseParts(root)) do
        first = first or part
        local n = string.lower(part.Name)
        if n == "effect" then return part end
        if string.find(n,"effect",1,true) or string.find(n,"vfx",1,true) then
            preferred = preferred or part
        end
    end
    return preferred or first
end

local function placeEffect(root,dummy)
    local anchor = anchorOf(dummy)
    local ref = referencePart(root)
    if not anchor or not ref then return false,"Sin anchor/reference part." end

    local placement = nil
    pcall(function() placement = ref:GetAttribute("Placement") end)
    placement = type(placement) == "string" and string.lower(placement) or ""

    local target = anchor.CFrame
    if placement == "ground" then target = anchor.CFrame * CFrame.new(0,-2.9,0)
    elseif placement == "feet" then target = anchor.CFrame * CFrame.new(0,-2.4,0)
    elseif placement == "head" then target = anchor.CFrame * CFrame.new(0,2.6,0)
    end

    local refCF = ref.CFrame
    for _,part in ipairs(baseParts(root)) do
        local relative = refCF:ToObjectSpace(part.CFrame)
        part.Anchored = true
        part.CanCollide = false
        part.CanTouch = false
        part.CanQuery = false
        part.CFrame = target * relative
    end
    return true
end

local function autoWire(root)
    local attachments = {}
    for _,o in ipairs(root:GetDescendants()) do
        if o:IsA("Attachment") then attachments[#attachments+1] = o end
    end
    if #attachments < 2 then return end
    for _,o in ipairs(root:GetDescendants()) do
        if o:IsA("Beam") or o:IsA("Trail") then
            pcall(function()
                if not o.Attachment0 then o.Attachment0 = attachments[1] end
                if not o.Attachment1 then o.Attachment1 = attachments[2] end
            end)
        end
    end
end

local function emit(root)
    autoWire(root)
    for _,o in ipairs(root:GetDescendants()) do
        if o:IsA("ParticleEmitter") then
            local count = tonumber(o:GetAttribute("EmitCount")) or 0
            local delaySec = tonumber(o:GetAttribute("EmitDelay")) or 0
            local duration = tonumber(o:GetAttribute("EmitDuration")) or 0

            task.delay(math.max(delaySec,0),function()
                if not o.Parent then return end
                if count > 0 then
                    pcall(function() o:Emit(math.max(1,math.floor(count+.5))) end)
                elseif o.Rate > 0 then
                    o.Enabled = true
                    local life = 0.6
                    pcall(function() life = math.max(life,o.Lifetime.Max) end)
                    task.delay(math.max(duration,life),function()
                        if o.Parent then o.Enabled = false end
                    end)
                end
            end)
        elseif o:IsA("Sound") then
            task.defer(function()
                if o.Parent then pcall(function() o:Play() end) end
            end)
        elseif o:IsA("Trail") or o:IsA("Beam") or o:IsA("Highlight") or
               o:IsA("Fire") or o:IsA("Smoke") or o:IsA("Sparkles") or
               o:IsA("PointLight") or o:IsA("SpotLight") or o:IsA("SurfaceLight") then
            local old = false
            pcall(function() old = o.Enabled end)
            pcall(function() o.Enabled = true end)
            task.delay(1.2,function()
                if o.Parent then pcall(function() o.Enabled = old end) end
            end)
        end
    end
end

local function clearSpawned()
    for i = #App.Spawned,1,-1 do
        local obj = App.Spawned[i]
        App.Spawned[i] = nil
        pcall(function() obj:Destroy() end)
    end
end

local function forceSelected(meta)
    clearSpawned()

    local def,err = loadEffect(meta)
    if not def then return false,err end

    local root,buildErr = buildEffect(def)
    if not root then return false,buildErr end

    local dummy,dummyErr = makeDummy()
    if not dummy then
        root:Destroy()
        return false,dummyErr
    end

    applyBodyStyle(dummy,meta.name)

    root.Name = "XeroRemote_" .. meta.name
    root.Parent = Workspace
    table.insert(App.Spawned,root)
    Debris:AddItem(root,12)

    local okPlace,placeErr = placeEffect(root,dummy)
    if not okPlace then return false,placeErr end

    emit(root)
    return true
end

-- ================= UI compacta / responsive =================

local parent = CoreGui
pcall(function() if gethui then parent = gethui() end end)

local oldGui = parent:FindFirstChild("XeroRemoteDeathEffectHub")
if oldGui then oldGui:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name = "XeroRemoteDeathEffectHub"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 2147483647
gui.Parent = parent

local card = Instance.new("Frame")
card.AnchorPoint = Vector2.new(.5,.5)
card.Position = UDim2.fromScale(.5,.5)
card.BackgroundColor3 = Color3.fromRGB(8,8,10)
card.BorderSizePixel = 0
card.Parent = gui
Instance.new("UICorner",card).CornerRadius = UDim.new(0,16)
local stroke = Instance.new("UIStroke",card)
stroke.Color = Color3.fromRGB(44,44,50)

local function resizeCard()
    local cam = Workspace.CurrentCamera
    local vp = cam and cam.ViewportSize or Vector2.new(1280,720)
    local w = math.clamp(vp.X - 36, 360, 620)
    local h = math.clamp(vp.Y - 70, 310, 410)
    card.Size = UDim2.fromOffset(w,h)
end
resizeCard()
if Workspace.CurrentCamera then
    track(Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(resizeCard))
end

local header = Instance.new("Frame")
header.Size = UDim2.new(1,0,0,48)
header.BackgroundTransparency = 1
header.Active = true
header.Parent = card

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Position = UDim2.fromOffset(14,7)
title.Size = UDim2.new(1,-70,0,20)
title.Font = Enum.Font.GothamBold
title.TextSize = 14
title.TextColor3 = Color3.fromRGB(245,245,247)
title.TextXAlignment = Enum.TextXAlignment.Left
title.Text = "XERO · DEATH EFFECT LAB"
title.Parent = header

local subtitle = Instance.new("TextLabel")
subtitle.BackgroundTransparency = 1
subtitle.Position = UDim2.fromOffset(14,26)
subtitle.Size = UDim2.new(1,-70,0,15)
subtitle.Font = Enum.Font.Gotham
subtitle.TextSize = 9
subtitle.TextColor3 = Color3.fromRGB(145,145,153)
subtitle.TextXAlignment = Enum.TextXAlignment.Left
subtitle.Text = "GitHub remoto · FORCE VFX"
subtitle.Parent = header

local close = Instance.new("TextButton")
close.AnchorPoint = Vector2.new(1,0)
close.Position = UDim2.new(1,-8,0,7)
close.Size = UDim2.fromOffset(34,34)
close.BackgroundColor3 = Color3.fromRGB(19,19,22)
close.BorderSizePixel = 0
close.Text = "×"
close.Font = Enum.Font.GothamBold
close.TextSize = 17
close.TextColor3 = Color3.fromRGB(235,235,238)
close.Parent = header
Instance.new("UICorner",close).CornerRadius = UDim.new(0,9)

local search = Instance.new("TextBox")
search.Position = UDim2.fromOffset(12,52)
search.Size = UDim2.new(.50,-18,0,34)
search.BackgroundColor3 = Color3.fromRGB(15,15,18)
search.BorderSizePixel = 0
search.ClearTextOnFocus = false
search.PlaceholderText = "Buscar effect..."
search.Text = ""
search.Font = Enum.Font.Gotham
search.TextSize = 10
search.TextColor3 = Color3.fromRGB(235,235,239)
search.PlaceholderColor3 = Color3.fromRGB(125,125,134)
search.Parent = card
Instance.new("UICorner",search).CornerRadius = UDim.new(0,9)
local searchPad = Instance.new("UIPadding",search)
searchPad.PaddingLeft = UDim.new(0,10)
searchPad.PaddingRight = UDim.new(0,10)

local force = Instance.new("TextButton")
force.Position = UDim2.new(.50,2,0,52)
force.Size = UDim2.new(.27,-8,0,34)
force.BackgroundColor3 = Color3.fromRGB(22,22,25)
force.BorderSizePixel = 0
force.Text = "FORCE VFX"
force.Font = Enum.Font.GothamBold
force.TextSize = 10
force.TextColor3 = Color3.fromRGB(245,245,247)
force.Parent = card
Instance.new("UICorner",force).CornerRadius = UDim.new(0,9)

local clear = Instance.new("TextButton")
clear.Position = UDim2.new(.77,2,0,52)
clear.Size = UDim2.new(.23,-14,0,34)
clear.BackgroundColor3 = Color3.fromRGB(18,18,21)
clear.BorderSizePixel = 0
clear.Text = "CLEAR"
clear.Font = Enum.Font.GothamMedium
clear.TextSize = 10
clear.TextColor3 = Color3.fromRGB(225,225,230)
clear.Parent = card
Instance.new("UICorner",clear).CornerRadius = UDim.new(0,9)

local list = Instance.new("ScrollingFrame")
list.Position = UDim2.fromOffset(12,96)
list.Size = UDim2.new(.46,-18,1,-108)
list.BackgroundColor3 = Color3.fromRGB(11,11,13)
list.BorderSizePixel = 0
list.ScrollBarThickness = 3
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
list.CanvasSize = UDim2.fromOffset(0,0)
list.Parent = card
Instance.new("UICorner",list).CornerRadius = UDim.new(0,11)
local listPad = Instance.new("UIPadding",list)
listPad.PaddingTop = UDim.new(0,6)
listPad.PaddingBottom = UDim.new(0,6)
listPad.PaddingLeft = UDim.new(0,6)
listPad.PaddingRight = UDim.new(0,6)
local layout = Instance.new("UIListLayout",list)
layout.Padding = UDim.new(0,4)

local detail = Instance.new("TextBox")
detail.Position = UDim2.new(.46,2,0,96)
detail.Size = UDim2.new(.54,-14,1,-108)
detail.BackgroundColor3 = Color3.fromRGB(10,10,12)
detail.BorderSizePixel = 0
detail.ClearTextOnFocus = false
detail.MultiLine = true
detail.TextEditable = false
detail.TextWrapped = true
detail.Font = Enum.Font.Code
detail.TextSize = 10
detail.TextColor3 = Color3.fromRGB(215,215,221)
detail.TextXAlignment = Enum.TextXAlignment.Left
detail.TextYAlignment = Enum.TextYAlignment.Top
detail.Text = "Cargando manifest de GitHub..."
detail.Parent = card
Instance.new("UICorner",detail).CornerRadius = UDim.new(0,11)
local dp = Instance.new("UIPadding",detail)
dp.PaddingTop = UDim.new(0,9)
dp.PaddingBottom = UDim.new(0,9)
dp.PaddingLeft = UDim.new(0,9)
dp.PaddingRight = UDim.new(0,9)

local buttons = {}

local function setSelected(meta)
    App.Selected = meta
    local cached = App.Cache[meta.name] ~= nil
    detail.Text = table.concat({
        "Effect: " .. tostring(meta.name),
        "Root: " .. tostring(meta.rootClass or "?"),
        "Captured descendants: " .. tostring(meta.capturedDescendants or "?"),
        "Objects in dump: " .. tostring(meta.objects or "?"),
        "",
        "Source: GitHub",
        "Cached this session: " .. tostring(cached),
        "Replication required: NO",
        "",
        "Pulsa FORCE VFX."
    },"\n")
end

local function rebuildList()
    for _,b in ipairs(buttons) do b:Destroy() end
    table.clear(buttons)

    local manifest = App.Manifest
    if not manifest then return end

    local q = string.lower(search.Text or "")
    local shown = 0
    for _,meta in ipairs(manifest.effects) do
        if q == "" or string.find(string.lower(meta.name),q,1,true) then
            shown = shown + 1
            local b = Instance.new("TextButton")
            b.LayoutOrder = shown
            b.Size = UDim2.new(1,0,0,34)
            b.BackgroundColor3 = Color3.fromRGB(17,17,20)
            b.BorderSizePixel = 0
            b.AutoButtonColor = false
            b.Font = Enum.Font.GothamMedium
            b.TextSize = 9
            b.TextColor3 = Color3.fromRGB(235,235,239)
            b.TextXAlignment = Enum.TextXAlignment.Left
            b.Text = "  " .. meta.name
            b.Parent = list
            Instance.new("UICorner",b).CornerRadius = UDim.new(0,8)
            b.MouseButton1Click:Connect(function() setSelected(meta) end)
            buttons[#buttons+1] = b
        end
    end
end

search:GetPropertyChangedSignal("Text"):Connect(rebuildList)

force.MouseButton1Click:Connect(function()
    local meta = App.Selected
    if not meta then
        detail.Text = "Selecciona un effect primero."
        return
    end

    detail.Text = "Descargando/reconstruyendo " .. meta.name .. "..."
    task.spawn(function()
        local ok,err = forceSelected(meta)
        if ok then
            detail.Text = table.concat({
                "✅ FORCE VFX",
                "",
                "Effect: " .. meta.name,
                "Replication required: NO",
                "Loaded from GitHub: YES",
                "Cached this session: YES",
                "",
                "Mira el dummy enfrente."
            },"\n")
        else
            detail.Text = "❌ " .. meta.name .. "\n\n" .. tostring(err)
        end
    end)
end)

clear.MouseButton1Click:Connect(function()
    clearSpawned()
    if App.Selected then
        setSelected(App.Selected)
    else
        detail.Text = "Limpio."
    end
end)

-- Drag: toda la barra superior.
local dragging = false
local dragStart, startPos

header.InputBegan:Connect(function(input)
    if input.UserInputType ~= Enum.UserInputType.MouseButton1
        and input.UserInputType ~= Enum.UserInputType.Touch then
        return
    end
    dragging = true
    dragStart = input.Position
    startPos = card.Position
end)

track(UserInputService.InputChanged:Connect(function(input)
    if not dragging then return end
    if input.UserInputType ~= Enum.UserInputType.MouseMovement
        and input.UserInputType ~= Enum.UserInputType.Touch then
        return
    end

    local delta = input.Position - dragStart
    card.Position = UDim2.new(
        startPos.X.Scale,
        startPos.X.Offset + delta.X,
        startPos.Y.Scale,
        startPos.Y.Offset + delta.Y
    )
end))

track(UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end))

function App.Destroy()
    if not App.Alive then return end
    App.Alive = false
    clearSpawned()
    for i = #App.Connections,1,-1 do
        pcall(function() App.Connections[i]:Disconnect() end)
        App.Connections[i] = nil
    end
    pcall(function() gui:Destroy() end)
    if ENV.__XERO_REMOTE_DEATH_EFFECT_HUB == App then
        ENV.__XERO_REMOTE_DEATH_EFFECT_HUB = nil
    end
end

close.MouseButton1Click:Connect(App.Destroy)

task.spawn(function()
    local manifest,err = loadManifest()
    if not manifest then
        detail.Text =
            "❌ No pude cargar manifest.json\n\n" ..
            tostring(err) ..
            "\n\nSube la carpeta death_effects del ZIP al root del repo."
        return
    end

    table.sort(manifest.effects,function(a,b) return a.name < b.name end)
    rebuildList()

    if manifest.effects[1] then
        setSelected(manifest.effects[1])
    end
end)
