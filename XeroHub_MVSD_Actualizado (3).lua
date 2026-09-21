-- XeroHub | MVSD | Kev
-- UI DUELS + Silent Aim + Auto Shoot Delay + Rapid Fire + Hitbox + ESP Lines/Skeleton + Modo Fantasma.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")
local ContentProvider = game:GetService("ContentProvider")
local SoundService = game:GetService("SoundService")

local player = Players.LocalPlayer
if not player then return end

local playerGui = player:WaitForChild("PlayerGui")
local mouse = player:GetMouse()
local runtimeEnv = (getgenv and getgenv()) or _G

-- Limpieza de versiones previas.
if runtimeEnv.__XERO_MVSD_HUB_CLEANUP then
    pcall(runtimeEnv.__XERO_MVSD_HUB_CLEANUP)
end
if runtimeEnv.__XERO_MVSD_UNIFIED_HITBOX_CLEANUP then
    pcall(runtimeEnv.__XERO_MVSD_UNIFIED_HITBOX_CLEANUP)
end
-- Compatibilidad: limpia también builds anteriores que todavía usaban el nombre ShootGun.
if runtimeEnv.__XERO_SHOOTGUN_COMBAT_CLEANUP then
    pcall(runtimeEnv.__XERO_SHOOTGUN_COMBAT_CLEANUP)
end
if runtimeEnv.__XERO_SHOOTGUN_SILENT_CLEANUP then
    pcall(runtimeEnv.__XERO_SHOOTGUN_SILENT_CLEANUP)
end
if runtimeEnv.__XERO_SHOOTGUN_HUB_CLEANUP then
    pcall(runtimeEnv.__XERO_SHOOTGUN_HUB_CLEANUP)
end

local runtime = {
    Alive = true,
    Connections = {},
    Drawings = {},
    Highlights = {},
    Billboards = {},
}

runtime.NextConnectionPruneAt = 96

function runtime.PruneConnections()
    local list = runtime.Connections
    local writeIndex = 1

    for readIndex = 1, #list do
        local connection = list[readIndex]
        local connected = false

        if connection then
            pcall(function()
                connected = connection.Connected == true
            end)
        end

        if connected then
            list[writeIndex] = connection
            writeIndex = writeIndex + 1
        end
    end

    for index = #list, writeIndex, -1 do
        list[index] = nil
    end

    runtime.NextConnectionPruneAt = #list + 64
end

function runtime.Track(connection)
    if connection then
        local list = runtime.Connections
        list[#list + 1] = connection

        if #list >= (runtime.NextConnectionPruneAt or 96) then
            runtime.PruneConnections()
        end
    end

    return connection
end

function runtime.TrackDrawing(drawing)
    if drawing then
        runtime.Drawings[#runtime.Drawings + 1] = drawing
    end
    return drawing
end

local function safeDestroy(object)
    if object then pcall(function() object:Destroy() end) end
end

local function removeDrawing(object)
    if object then pcall(function() object:Remove() end) end
end

-- ==========================================
-- ESTADO / CACHÉS
-- ==========================================

local state = {
    SilentAim = false,
    AutoShoot = false,
    AutoShootAccumulator = 0,
    AutoShootScanInterval = 0.03,
    AutoShootDelay = 0.3,
    AutoShootNextAllowedAt = 0,

    ESP = false,
    ESPLines = false,
    ESPSkeleton = false,
    TeamCheck = true,

    HitboxExpander = false,
    HitboxSize = 8,
    HitboxVisible = false,
    HitboxAccumulator = 0,

    RapidFire = false,
    RapidFireButtonVisible = true,
    SpamFireButtonVisible = true,
    RapidFireRate = 16,
    RapidFireAccumulator = 0,

    RoundStartSpam = false,
    RoundStartSpamRate = 45,
    RoundStartSpamAccumulator = 0,

    FOVFilter = true,
    ShowFOV = true,
    FOVRadius = 140,
    FOVHasCandidate = false,

    ESPGlow = true,
    ESPName = true,
    ESPHealth = true,
    ESPDistance = true,
    ESPColor = Color3.fromRGB(255, 255, 255),
    OpenButtonGhost = false,

    InLobby = true,
    LobbyReason = "Inicializando",
    LobbyTimer = 1,
    MatchId = nil,

    SilentTarget = nil,
    SilentTargetPlayer = nil,

    SilentAccumulator = 0,
    ESPAccumulator = 0,

    EquippedTool = nil,
    CombatMaxDistance = 800,
}

-- Multiselección corporal idéntica en concepto a DUELS.
runtime.TargetBodyOrder = {
    "Cabeza", "Torso superior", "Torso inferior",
    "Brazo izquierdo", "Brazo derecho", "Pierna izquierda", "Pierna derecha"
}

runtime.TargetBodyGroups = {
    ["Cabeza"] = {"Head"},
    ["Torso superior"] = {"UpperTorso", "Torso"},
    ["Torso inferior"] = {"LowerTorso", "Torso", "HumanoidRootPart"},
    ["Brazo izquierdo"] = {"LeftUpperArm", "LeftLowerArm", "LeftHand", "Left Arm", "LeftArm"},
    ["Brazo derecho"] = {"RightUpperArm", "RightLowerArm", "RightHand", "Right Arm", "RightArm"},
    ["Pierna izquierda"] = {"LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "Left Leg", "LeftLeg"},
    ["Pierna derecha"] = {"RightUpperLeg", "RightLowerLeg", "RightFoot", "Right Leg", "RightLeg"},
}

runtime.TargetSelections = {
    SilentAim = {["Cabeza"] = true},
}

runtime.TargetPartNameCache = {
    SilentAim = {"Head"},
}

runtime.TargetSelectionVersion = {
    SilentAim = 1,
}

runtime.TargetPartCache = {
    SilentAim = setmetatable({}, {__mode = "k"}),
}

function runtime.RebuildTargetPartNameCache(mode)
    local selected = runtime.TargetSelections[mode] or {}
    local result = runtime.TargetPartNameCache[mode] or {}
    table.clear(result)

    local seen = {}
    for i = 1, #runtime.TargetBodyOrder do
        local groupName = runtime.TargetBodyOrder[i]
        if selected[groupName] then
            local names = runtime.TargetBodyGroups[groupName]
            for j = 1, #names do
                local partName = names[j]
                if not seen[partName] then
                    seen[partName] = true
                    result[#result + 1] = partName
                end
            end
        end
    end

    if #result == 0 then
        result[1] = "Head"
    end

    runtime.TargetPartNameCache[mode] = result
    return result
end

function runtime.GetTargetSelectionArray(mode)
    local result = {}
    local selected = runtime.TargetSelections[mode] or {}

    for i = 1, #runtime.TargetBodyOrder do
        local name = runtime.TargetBodyOrder[i]
        if selected[name] then
            result[#result + 1] = name
        end
    end

    return result
end

function runtime.SetTargetSelection(mode, value)
    local selected = runtime.TargetSelections[mode]
    if not selected then return end

    table.clear(selected)

    local function enable(name)
        if runtime.TargetBodyGroups[name] then
            selected[name] = true
        end
    end

    if type(value) == "table" then
        for i = 1, #value do
            enable(value[i])
        end
    elseif value == "Torso" then
        enable("Torso superior")
        enable("Torso inferior")
    elseif value == "Cuerpo Completo" then
        for i = 1, #runtime.TargetBodyOrder do
            enable(runtime.TargetBodyOrder[i])
        end
    elseif type(value) == "string" then
        enable(value)
    end

    if not next(selected) then
        selected["Cabeza"] = true
    end

    runtime.RebuildTargetPartNameCache(mode)
    runtime.TargetSelectionVersion[mode] = (runtime.TargetSelectionVersion[mode] or 0) + 1

    local cache = runtime.TargetPartCache[mode]
    if cache then
        table.clear(cache)
    end

    if runtime.BodySelector and runtime.BodySelector.Refresh then
        runtime.BodySelector.Refresh()
    end
end

-- Players:GetPlayers() crea una tabla nueva; mantenemos una sola lista viva.
runtime.PlayerList = Players:GetPlayers()

local function addCachedPlayer(plr)
    if not plr or plr == player then return end
    for i = 1, #runtime.PlayerList do
        if runtime.PlayerList[i] == plr then return end
    end
    runtime.PlayerList[#runtime.PlayerList + 1] = plr
end

local function removeCachedPlayer(plr)
    runtime.CharacterCache[plr] = nil

    for i = #runtime.PlayerList, 1, -1 do
        if runtime.PlayerList[i] == plr then
            runtime.PlayerList[i] = runtime.PlayerList[#runtime.PlayerList]
            runtime.PlayerList[#runtime.PlayerList] = nil
            break
        end
    end
end

runtime.CharacterCache = setmetatable({}, {__mode = "k"})

-- Hitbox Expander nativo.
runtime.HitboxOriginal = setmetatable({}, {__mode = "k"})
runtime.HitboxAdornments = setmetatable({}, {__mode = "k"})
runtime.HitboxSizeWatchers = setmetatable({}, {__mode = "k"})
runtime.HitboxReapplying = setmetatable({}, {__mode = "k"})

-- ESP 2D extra.
runtime.ESPTracerLines = setmetatable({}, {__mode = "k"})
runtime.ESPSkeletonLines = setmetatable({}, {__mode = "k"})
runtime.DrawingSupported = false

pcall(function()
    runtime.DrawingSupported =
        Drawing ~= nil
        and type(Drawing.new) == "function"
end)

runtime.Track(Players.PlayerAdded:Connect(addCachedPlayer))
runtime.Track(Players.PlayerRemoving:Connect(removeCachedPlayer))

-- ==========================================
-- LOBBY / ROUND VALIDATION
-- ==========================================

local function estaEnLobby()
    local char = player.Character
    if not char then
        return true, "Sin personaje"
    end

    local hum = char:FindFirstChildOfClass("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hum or hum.Health <= 0 or not hrp then
        return true, "Sin personaje activo"
    end

    -- Estado nativo detectado con el State Scanner:
    -- Lobby: Match=nil, MatchStartTime=nil, Neutral=true
    -- Partida: Match=<id>, MatchStartTime=<timestamp>, Neutral=false
    local matchId = player:GetAttribute("Match")
    local matchStartTime = player:GetAttribute("MatchStartTime")

    if matchId == nil then
        return true, "Sin Match"
    end

    if matchStartTime == nil then
        return true, "Sin MatchStartTime"
    end

    if player.Neutral == true then
        return true, "Neutral"
    end

    return false, "Partida #" .. tostring(matchId)
end

local function refreshLobbyState()
    local inLobby, reason = estaEnLobby()
    state.InLobby = inLobby
    state.LobbyReason = reason
    state.MatchId = inLobby and nil or player:GetAttribute("Match")

    if inLobby then
        state.SilentTarget = nil
        state.SilentTargetPlayer = nil
    end
end

-- Actualiza el gate de lobby inmediatamente cuando MVSD cambia de estado.
runtime.Track(player:GetAttributeChangedSignal("Match"):Connect(refreshLobbyState))
runtime.Track(player:GetAttributeChangedSignal("MatchStartTime"):Connect(refreshLobbyState))
runtime.Track(player:GetPropertyChangedSignal("Neutral"):Connect(refreshLobbyState))

-- ==========================================
-- ENEMIES / HITBOXES / TARGET CACHE
-- ==========================================

local function isEnemy(plr)
    if not plr or plr == player or state.InLobby then
        return false
    end

    -- MVSD aloja varias partidas dentro del mismo servidor.
    -- Sólo jugadores del MISMO Match pueden ser target/ESP.
    local myMatch = state.MatchId
    local theirMatch = plr:GetAttribute("Match")

    if myMatch == nil or theirMatch ~= myMatch then
        return false
    end

    -- Team Check fijo: siempre activo internamente.
    if player.Team ~= nil and plr.Team ~= nil then
        return player.Team ~= plr.Team
    end

    local myTeam = player:GetAttribute("Team") or player:GetAttribute("team")
    local theirTeam = plr:GetAttribute("Team") or plr:GetAttribute("team")
    if myTeam ~= nil and theirTeam ~= nil then
        return myTeam ~= theirTeam
    end

    return true
end

local function getCharacterData(plr)
    if not plr then return nil end

    local char = plr.Character
    if not char then
        runtime.CharacterCache[plr] = nil
        return nil
    end

    local cached = runtime.CharacterCache[plr]
    if not cached or cached.Character ~= char
        or not cached.Humanoid or cached.Humanoid.Parent ~= char
        or not cached.Root or cached.Root.Parent ~= char
    then
        cached = {
            Character = char,
            Humanoid = char:FindFirstChildOfClass("Humanoid"),
            Root = char:FindFirstChild("HumanoidRootPart"),
        }
        runtime.CharacterCache[plr] = cached
    end

    local hum = cached.Humanoid
    local hrp = cached.Root
    if not hum or hum.Health <= 0 or not hrp then
        return nil
    end

    return char, hum, hrp
end

local function playerIsInActiveRound(plr, char, hrp, hum)
    if not plr or plr == player or state.InLobby
        or not char or not hrp or not hum or hum.Health <= 0
    then
        return false
    end

    -- isEnemy ya se ejecutó antes de llegar aquí:
    -- mismo Match + Team Check fijo.
    if char:FindFirstChildOfClass("ForceField") then
        return false
    end

    return true
end

local function resolveActualHitbox(bodyPart)
    if not bodyPart then return nil end

    local nested = bodyPart:FindFirstChild("Part")
    if nested and nested:IsA("BasePart") then
        return nested
    end

    if bodyPart:IsA("BasePart") then
        return bodyPart
    end

    return nil
end

function runtime.CollectTargetParts(char, mode)
    if not char then return nil end

    local modeCache = runtime.TargetPartCache[mode]
    local version = runtime.TargetSelectionVersion[mode] or 1
    local cached = modeCache and modeCache[char]

    if cached and cached.Version == version then
        local parts = cached.Parts
        local valid = parts and #parts > 0

        if valid then
            for i = 1, #parts do
                local part = parts[i]
                if not part or not part.Parent or not part:IsDescendantOf(char) then
                    valid = false
                    break
                end
            end
        end

        if valid then
            return parts
        end

        modeCache[char] = nil
    end

    local parts = {}
    local seen = {}
    local names = runtime.TargetPartNameCache[mode] or runtime.RebuildTargetPartNameCache(mode)

    for i = 1, #names do
        local body = char:FindFirstChild(names[i])
        local hitbox = resolveActualHitbox(body)

        if hitbox and not seen[hitbox] then
            seen[hitbox] = true
            parts[#parts + 1] = hitbox
        end
    end

    if #parts == 0 then
        local fallback = resolveActualHitbox(char:FindFirstChild("Head"))
            or char:FindFirstChild("HumanoidRootPart")
        if fallback then
            parts[1] = fallback
        end
    end

    if modeCache and #parts > 0 then
        modeCache[char] = {
            Version = version,
            Parts = parts,
        }
    end

    return parts
end

local function getEquippedTool()
    local char = player.Character
    if not char then
        state.EquippedTool = nil
        return nil
    end

    local tool = state.EquippedTool
    if tool and tool.Parent == char and tool:IsA("Tool") then
        return tool
    end

    tool = char:FindFirstChildOfClass("Tool")
    state.EquippedTool = tool
    return tool
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = true
local rayIgnore = {}

-- WallCheck único para Silent Aim y color del FOV.
-- 1) Sólo ignora nuestro Character: si el primer impacto es mundo/estructura, bloquea.
-- 2) Repite desde la cámara para cubrir esquinas donde cabeza/cámara no comparten línea.
-- 3) GetPartsObscuringTarget añade una segunda comprobación para piezas que algunos
--    raycasts del mapa pueden omitir.
local function lineClearFrom(origin, localChar, enemyChar, targetPart)
    if not origin or not localChar or not enemyChar or not targetPart or not targetPart.Parent then
        return false
    end

    local delta = targetPart.Position - origin
    if delta:Dot(delta) <= 0.0001 then
        return true
    end

    rayIgnore[1] = localChar
    rayIgnore[2] = nil
    rayParams.FilterDescendantsInstances = rayIgnore

    local result = workspace:Raycast(origin, delta, rayParams)
    if result then
        local hit = result.Instance
        return hit ~= nil and hit:IsDescendantOf(enemyChar)
    end

    -- Si el rig enemigo usa hitboxes con CanQuery=false, un raycast puede no
    -- golpearlo. En ese caso comprobamos que tampoco haya mundo ocultándolo.
    local camera = workspace.CurrentCamera
    if camera then
        local ok, blockers = pcall(function()
            return camera:GetPartsObscuringTarget(
                {targetPart.Position},
                {localChar, enemyChar}
            )
        end)

        if ok and blockers then
            for i = 1, #blockers do
                local blocker = blockers[i]
                if blocker
                    and blocker.Parent
                    and not blocker:IsDescendantOf(localChar)
                    and not blocker:IsDescendantOf(enemyChar)
                    and blocker.Transparency < 0.98
                then
                    return false
                end
            end
        end
    end

    return true
end

local function visibleTarget(localChar, enemyChar, targetPart, origin)
    if not lineClearFrom(origin, localChar, enemyChar, targetPart) then
        return false
    end

    local camera = workspace.CurrentCamera
    if camera then
        local camOrigin = camera.CFrame.Position
        if (camOrigin - origin):Dot(camOrigin - origin) > 0.01 then
            if not lineClearFrom(camOrigin, localChar, enemyChar, targetPart) then
                return false
            end
        end
    end

    return true
end

local function getCenter()
    local camera = workspace.CurrentCamera
    if not camera then return 0, 0 end
    local viewport = camera.ViewportSize
    return viewport.X * 0.5, viewport.Y * 0.5
end

-- Devuelve target + si cualquier parte seleccionada de Silent Aim está dentro del FOV.
-- Así RenderStepped no vuelve a escanear jugadores solo para cambiar el color del círculo.
local function chooseTarget(mode, useFOV)
    if state.InLobby then return nil, nil, false end

    local camera = workspace.CurrentCamera
    local localChar = player.Character
    local localHum = localChar and localChar:FindFirstChildOfClass("Humanoid")
    local localRoot = localChar and localChar:FindFirstChild("HumanoidRootPart")
    local localHead = localChar and localChar:FindFirstChild("Head")

    if not camera or not localChar or not localHum or localHum.Health <= 0 or not localRoot then
        return nil, nil, false
    end

    if not getEquippedTool() then
        return nil, nil, false
    end

    local origin = localHead and localHead.Position or localRoot.Position
    local centerX, centerY = getCenter()
    local fovSq = state.FOVRadius * state.FOVRadius
    local combatRangeSq = state.CombatMaxDistance * state.CombatMaxDistance

    local bestPlayer, bestPart
    local bestMetric = math.huge
    local fovCandidate = false

    for i = 1, #runtime.PlayerList do
        local plr = runtime.PlayerList[i]

        if plr ~= player and isEnemy(plr) then
            local char, hum, hrp = getCharacterData(plr)

            if char and hum and hrp and playerIsInActiveRound(plr, char, hrp, hum) then
                local rootDelta = hrp.Position - localRoot.Position

                if rootDelta:Dot(rootDelta) <= combatRangeSq then
                    local parts = runtime.CollectTargetParts(char, mode)

                    if parts then
                        for j = 1, #parts do
                            local part = parts[j]

                            if part and part.Parent then
                                local metric
                                local passes = true
                                local inFOV = false

                                if mode == "SilentAim" then
                                    local screen, onScreen = camera:WorldToViewportPoint(part.Position)

                                    if onScreen and screen.Z > 0 then
                                        local dx = screen.X - centerX
                                        local dy = screen.Y - centerY
                                        local screenMetric = dx * dx + dy * dy
                                        inFOV = screenMetric <= fovSq

                                        if useFOV then
                                            metric = screenMetric
                                            passes = inFOV
                                        end
                                    elseif useFOV then
                                        passes = false
                                    end

                                    if not useFOV then
                                        local delta = part.Position - localRoot.Position
                                        metric = delta:Dot(delta)
                                    end
                                else
                                    local delta = part.Position - localRoot.Position
                                    metric = delta:Dot(delta)
                                end

                                if passes and metric then
                                    local hasLOS = visibleTarget(localChar, char, part, origin)

                                    -- El círculo sólo se pone verde si la MISMA parte
                                    -- que está dentro del FOV también pasa el wallcheck.
                                    if mode == "SilentAim" and inFOV and hasLOS then
                                        fovCandidate = true
                                    end

                                    if hasLOS and metric < bestMetric then
                                        bestMetric = metric
                                        bestPlayer = plr
                                        bestPart = part
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    return bestPlayer, bestPart, fovCandidate
end

-- ==========================================
-- HITBOX EXPANDER NATIVO · UpperTorso.Part
-- ==========================================

do
local function getUnifiedNativeHitbox(char)
    if not char then return nil end

    local torso = char:FindFirstChild("UpperTorso")
        or char:FindFirstChild("Torso")

    if not torso then
        return nil
    end

    local part = torso:FindFirstChild("Part")
    if part and part:IsA("BasePart") then
        return part
    end

    return nil
end

local function getWantedHitboxSize()
    local size = math.clamp(
        tonumber(state.HitboxSize) or 8,
        2,
        50
    )
    return Vector3.new(size, size, size)
end

local function ensureHitboxAdornment(part)
    local box = runtime.HitboxAdornments[part]

    if box and box.Parent == part then
        return box
    end

    local ok, created = pcall(function()
        local newBox = Instance.new("BoxHandleAdornment")
        newBox.Name = "XeroNativeHitboxBox"
        newBox.Adornee = part
        newBox.AlwaysOnTop = true
        newBox.ZIndex = 10
        newBox.Color3 = Color3.fromRGB(255, 255, 255)
        newBox.Transparency = 0.68
        newBox.Size = part.Size
        newBox.Visible = state.HitboxVisible
        newBox.Parent = part
        return newBox
    end)

    if not ok or not created then
        return nil
    end

    runtime.HitboxAdornments[part] = created
    return created
end

local function ensureHitboxSizeWatcher(part)
    if runtime.HitboxSizeWatchers[part] then
        return
    end

    local connection
    connection = part:GetPropertyChangedSignal("Size"):Connect(function()
        if not runtime.Alive
            or not state.HitboxExpander
            or not part
            or not part.Parent
            or not runtime.HitboxOriginal[part]
            or runtime.HitboxReapplying[part]
        then
            return
        end

        local wanted = getWantedHitboxSize()

        if part.Size ~= wanted then
            runtime.HitboxReapplying[part] = true

            task.defer(function()
                if runtime.Alive
                    and state.HitboxExpander
                    and part
                    and part.Parent
                    and runtime.HitboxOriginal[part]
                then
                    local currentSize = getWantedHitboxSize()
                    pcall(function()
                        part.Size = currentSize
                    end)

                    local box = runtime.HitboxAdornments[part]
                    if box and box.Parent == part then
                        pcall(function()
                            box.Size = currentSize
                        end)
                    end
                end

                runtime.HitboxReapplying[part] = nil
            end)
        end
    end)

    runtime.HitboxSizeWatchers[part] = connection
end

local function restoreExpandedHitbox(part)
    local watcher = runtime.HitboxSizeWatchers[part]
    if watcher then
        pcall(function()
            watcher:Disconnect()
        end)
        runtime.HitboxSizeWatchers[part] = nil
    end

    runtime.HitboxReapplying[part] = nil

    local original = runtime.HitboxOriginal[part]
    if part and part.Parent and original then
        pcall(function()
            part.Size = original.Size
            part.CanCollide = original.CanCollide
            part.CanQuery = original.CanQuery
            part.Transparency = original.Transparency
            part.Massless = original.Massless
        end)
    end

    local box = runtime.HitboxAdornments[part]
    if box then
        safeDestroy(box)
        runtime.HitboxAdornments[part] = nil
    end

    runtime.HitboxOriginal[part] = nil
end

function runtime.RestoreAllExpandedHitboxes()
    local list = {}

    for part in pairs(runtime.HitboxOriginal) do
        list[#list + 1] = part
    end

    for i = 1, #list do
        restoreExpandedHitbox(list[i])
    end
end

local function applyExpandedHitbox(part)
    if not part or not part.Parent then
        return
    end

    if not runtime.HitboxOriginal[part] then
        runtime.HitboxOriginal[part] = {
            Size = part.Size,
            CanCollide = part.CanCollide,
            CanQuery = part.CanQuery,
            Transparency = part.Transparency,
            Massless = part.Massless,
        }
    end

    ensureHitboxSizeWatcher(part)

    local wanted = getWantedHitboxSize()

    if part.Size ~= wanted then
        runtime.HitboxReapplying[part] = true

        pcall(function()
            part.Size = wanted
        end)

        runtime.HitboxReapplying[part] = nil
    end

    -- Mantiene la Part nativa detectable por raycast sin colisión física.
    pcall(function()
        part.CanCollide = false
        part.CanQuery = true
        part.Transparency = 1
        part.Massless = true
    end)

    local box = ensureHitboxAdornment(part)
    if box then
        box.Size = wanted
        box.Visible = state.HitboxVisible
    end
end

function runtime.RefreshExpandedHitboxes()
    if not state.HitboxExpander or state.InLobby then
        runtime.RestoreAllExpandedHitboxes()
        return
    end

    local active = {}

    for i = 1, #runtime.PlayerList do
        local plr = runtime.PlayerList[i]

        if plr ~= player and isEnemy(plr) then
            local char, hum, hrp = getCharacterData(plr)

            if char and hum and hrp
                and playerIsInActiveRound(plr, char, hrp, hum)
            then
                local hitbox = getUnifiedNativeHitbox(char)

                if hitbox then
                    active[hitbox] = true
                    applyExpandedHitbox(hitbox)
                end
            end
        end
    end

    local stale = {}

    for part in pairs(runtime.HitboxOriginal) do
        if not active[part] then
            stale[#stale + 1] = part
        end
    end

    for i = 1, #stale do
        restoreExpandedHitbox(stale[i])
    end
end

end -- Native hitbox scope

-- ==========================================
-- SILENT AIM HOOK | VERSIÓN ESTABLE QUE SÍ REDIRIGE
-- ==========================================

-- Primera persona: el disparo real puede originarse pegado a la cámara.
-- No simulamos input ni tocamos la selección de targets. Sólo abrimos una
-- ventana corta cuando el usuario hace Mouse1 con un Tool equipado.
runtime.LastManualShotInputAt = 0

runtime.Track(UserInputService.InputBegan:Connect(function(input)
    if not state.SilentAim then return end
    if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end

    local char = player.Character
    local tool = char and char:FindFirstChildOfClass("Tool")
    if tool then
        runtime.LastManualShotInputAt = os.clock()
    end
end))

local function allowNearCameraWeaponRay()
    return os.clock() - (runtime.LastManualShotInputAt or 0) <= 0.25
end

local aimHookState = runtimeEnv.__XERO_MVSD_AIM_STATE

if not aimHookState then
    aimHookState = {
        Target = nil,
        Mouse = mouse,
    }
    runtimeEnv.__XERO_MVSD_AIM_STATE = aimHookState

    local oldNamecall
    oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
        local target = aimHookState.Target

        local method = getnamecallmethod()

        if not checkcaller() and target and target.Parent then

            if self == workspace then
                if method == "Raycast" then
                    local origin, direction, params = ...

                    if typeof(origin) == "Vector3"
                        and typeof(direction) == "Vector3"
                        and direction.Magnitude > 5
                    then
                        local camera = workspace.CurrentCamera

                        local nearCamera = camera
                            and (origin - camera.CFrame.Position).Magnitude <= 1

                        if not nearCamera or allowNearCameraWeaponRay() then
                            local delta = target.Position - origin

                            if delta.Magnitude > 0.01 then
                                return oldNamecall(
                                    self,
                                    origin,
                                    delta.Unit * 5000,
                                    params
                                )
                            end
                        end
                    end

                elseif method == "FindPartOnRay"
                    or method == "FindPartOnRayWithIgnoreList"
                then
                    local ray, p2, p3, p4 = ...

                    if typeof(ray) == "Ray" and ray.Direction.Magnitude > 5 then
                        local camera = workspace.CurrentCamera

                        local nearCamera = camera
                            and (ray.Origin - camera.CFrame.Position).Magnitude <= 1

                        if not nearCamera or allowNearCameraWeaponRay() then
                            local delta = target.Position - ray.Origin

                            if delta.Magnitude > 0.01 then
                                local newRay = Ray.new(
                                    ray.Origin,
                                    delta.Unit * 5000
                                )

                                return oldNamecall(self, newRay, p2, p3, p4)
                            end
                        end
                    end
                end
            end
        elseif target and not target.Parent then
            aimHookState.Target = nil
        end

        return oldNamecall(self, ...)
    end)

    local oldIndex
    oldIndex = hookmetamethod(game, "__index", function(object, key)
        local target = aimHookState.Target

        if not checkcaller()
            and object == aimHookState.Mouse
            and target
            and target.Parent
        then
            if key == "Hit" or key == "hit" then
                return target.CFrame
            elseif key == "Target" or key == "target" then
                return target
            end
        end

        return oldIndex(object, key)
    end)
else
    aimHookState.Target = nil
    aimHookState.Mouse = mouse
end

-- ==========================================
-- ESP OPTIMIZADO
-- ==========================================

local function isValidESPTarget(plr)
    if not state.ESP or state.InLobby or not plr or plr == player then
        return false
    end

    if not isEnemy(plr) then
        return false
    end

    local char, hum, hrp = getCharacterData(plr)
    if not char or not hum or not hrp then
        return false
    end

    if not playerIsInActiveRound(plr, char, hrp, hum) then
        return false
    end

    return true, char, hum, hrp
end

local function removeESP(plr)
    if runtime.HideESPGeometry then
        runtime.HideESPGeometry(plr)
    end

    local highlight = runtime.Highlights[plr]
    if highlight then
        safeDestroy(highlight)
        runtime.Highlights[plr] = nil
    end

    local billboard = runtime.Billboards[plr]
    if billboard then
        pcall(function()
            billboard.Enabled = false
            billboard.Adornee = nil
        end)
        safeDestroy(billboard)
        runtime.Billboards[plr] = nil
    end
end

local function clearOrphanESPBillboards()
    for _, child in ipairs(playerGui:GetChildren()) do
        if child:IsA("BillboardGui")
            and child.Name == "XeroEnemyInfo"
        then
            local tracked = false
            for _, billboard in pairs(runtime.Billboards) do
                if billboard == child then
                    tracked = true
                    break
                end
            end

            if not tracked then
                pcall(function()
                    child.Enabled = false
                    child.Adornee = nil
                end)
                safeDestroy(child)
            end
        end
    end
end

local function clearESP()
    local pending = {}
    for plr in pairs(runtime.Highlights) do
        pending[#pending + 1] = plr
    end
    for plr in pairs(runtime.Billboards) do
        if not runtime.Highlights[plr] then
            pending[#pending + 1] = plr
        end
    end

    for i = 1, #pending do
        removeESP(pending[i])
    end

    clearOrphanESPBillboards()

    if runtime.HideAllESPGeometry then
        runtime.HideAllESPGeometry()
    end
end

local function hasESPText()
    return state.ESPName or state.ESPHealth or state.ESPDistance
end

local function ensureESP(plr)
    local valid, char, hum, hrp = isValidESPTarget(plr)
    if not valid then
        removeESP(plr)
        return
    end

    if state.ESPGlow then
        local highlight = runtime.Highlights[plr]
        if not highlight or not highlight.Parent then
            highlight = Instance.new("Highlight")
            highlight.Name = "XeroEnemyESP"
            highlight.FillTransparency = 0.72
            highlight.OutlineTransparency = 1
            highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            highlight.Adornee = char
            -- No insertamos el Highlight dentro del Character remoto.
            highlight.Parent = ReplicatedStorage
            runtime.Highlights[plr] = highlight
        else
            highlight.Adornee = char
        end

        highlight.FillColor = state.ESPColor
        highlight.Enabled = true
    else
        local highlight = runtime.Highlights[plr]
        if highlight then
            safeDestroy(highlight)
            runtime.Highlights[plr] = nil
        end
    end

    if hasESPText() then
        local billboard = runtime.Billboards[plr]

        if not billboard or not billboard.Parent then
            billboard = Instance.new("BillboardGui")
            billboard.Name = "XeroEnemyInfo"
            billboard:SetAttribute("XeroMVSDESP", true)
            billboard.Size = UDim2.fromOffset(190, 38)
            billboard.StudsOffset = Vector3.new(0, 3.3, 0)
            billboard.AlwaysOnTop = true
            billboard.Adornee = hrp
            billboard.Parent = playerGui

            local label = Instance.new("TextLabel")
            label.Name = "Info"
            label.Size = UDim2.fromScale(1, 1)
            label.BackgroundTransparency = 1
            label.TextColor3 = state.ESPColor
            label.TextStrokeTransparency = 0.45
            label.Font = Enum.Font.GothamMedium
            label.TextSize = 12
            label.Parent = billboard

            runtime.Billboards[plr] = billboard
        else
            billboard.Adornee = hrp
        end

        billboard.Enabled = true

        local label = billboard:FindFirstChild("Info")
        if label then
            local fields = {}
            if state.ESPName then
                fields[#fields + 1] = plr.Name
            end
            if state.ESPHealth then
                fields[#fields + 1] = tostring(math.max(0, math.floor(hum.Health + 0.5))) .. " HP"
            end
            if state.ESPDistance then
                local myRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
                local distance = myRoot and (myRoot.Position - hrp.Position).Magnitude or 0
                fields[#fields + 1] = tostring(math.floor(distance + 0.5)) .. "m"
            end

            label.Text = table.concat(fields, "  |  ")
            label.TextColor3 = state.ESPColor
        end
    else
        local billboard = runtime.Billboards[plr]
        if billboard then
            safeDestroy(billboard)
            runtime.Billboards[plr] = nil
        end
    end
end

runtime.Track(Players.PlayerRemoving:Connect(function(plr)
    runtime.CharacterCache[plr] = nil
    removeESP(plr)
    if runtime.DestroyESPGeometry then
        runtime.DestroyESPGeometry(plr)
    end
end))

local function refreshAllESPFilters()
    if not state.ESP then
        clearESP()
        return
    end

    for i = 1, #runtime.PlayerList do
        local plr = runtime.PlayerList[i]
        if plr ~= player then
            ensureESP(plr)
        end
    end
end

runtime.Track(player:GetPropertyChangedSignal("Team"):Connect(refreshAllESPFilters))
runtime.Track(player:GetPropertyChangedSignal("Neutral"):Connect(refreshAllESPFilters))
runtime.Track(player:GetAttributeChangedSignal("Match"):Connect(refreshAllESPFilters))

for i = 1, #runtime.PlayerList do
    local plr = runtime.PlayerList[i]
    if plr ~= player then
        runtime.Track(plr:GetPropertyChangedSignal("Team"):Connect(function()
            ensureESP(plr)
        end))
        runtime.Track(plr:GetAttributeChangedSignal("Match"):Connect(function()
            ensureESP(plr)
        end))
    end
end

runtime.Track(Players.PlayerAdded:Connect(function(plr)
    if plr == player then return end

    runtime.Track(plr:GetPropertyChangedSignal("Team"):Connect(function()
        ensureESP(plr)
    end))

    runtime.Track(plr:GetAttributeChangedSignal("Match"):Connect(function()
        ensureESP(plr)
    end))
end))

-- Limpia nombres huérfanos que hayan quedado de una ejecución anterior.
clearOrphanESPBillboards()

-- ==========================================
-- ESP LÍNEAS + ESQUELETO · estilo DUELS
-- ==========================================

do
runtime.ESPSkeletonPairsR15 = {
    {"Head", "UpperTorso"},
    {"UpperTorso", "LowerTorso"},

    {"UpperTorso", "LeftUpperArm"},
    {"LeftUpperArm", "LeftLowerArm"},
    {"LeftLowerArm", "LeftHand"},

    {"UpperTorso", "RightUpperArm"},
    {"RightUpperArm", "RightLowerArm"},
    {"RightLowerArm", "RightHand"},

    {"LowerTorso", "LeftUpperLeg"},
    {"LeftUpperLeg", "LeftLowerLeg"},
    {"LeftLowerLeg", "LeftFoot"},

    {"LowerTorso", "RightUpperLeg"},
    {"RightUpperLeg", "RightLowerLeg"},
    {"RightLowerLeg", "RightFoot"},
}

runtime.ESPSkeletonPairsR6 = {
    {"Head", "Torso"},
    {"Torso", "Left Arm"},
    {"Torso", "Right Arm"},
    {"Torso", "Left Leg"},
    {"Torso", "Right Leg"},
}

local function newESPLine(thickness, transparency)
    if not runtime.DrawingSupported then
        return nil
    end

    local ok, line = pcall(function()
        return Drawing.new("Line")
    end)

    if not ok or not line then
        runtime.DrawingSupported = false
        return nil
    end

    line.Thickness = thickness or 1.25
    line.Transparency = transparency or 0.92
    line.Color = state.ESPColor
    line.Visible = false

    return line
end

local function hideESPGeometry(plr)
    local tracer = runtime.ESPTracerLines[plr]
    if tracer and tracer.Visible then
        tracer.Visible = false
    end

    local skeleton = runtime.ESPSkeletonLines[plr]
    if skeleton then
        for i = 1, #skeleton do
            local line = skeleton[i]
            if line and line.Visible then
                line.Visible = false
            end
        end
    end
end

local function hideAllESPGeometry()
    for plr in pairs(runtime.ESPTracerLines) do
        hideESPGeometry(plr)
    end

    for plr in pairs(runtime.ESPSkeletonLines) do
        hideESPGeometry(plr)
    end
end

runtime.HideESPGeometry = hideESPGeometry
runtime.HideAllESPGeometry = hideAllESPGeometry

function runtime.DestroyESPGeometry(plr)
    removeDrawing(runtime.ESPTracerLines[plr])
    runtime.ESPTracerLines[plr] = nil
    local lines = runtime.ESPSkeletonLines[plr]
    if lines then
        for i = 1, #lines do
            removeDrawing(lines[i])
        end
        runtime.ESPSkeletonLines[plr] = nil
    end
end

function runtime.DestroyAllESPGeometry()
    for plr in pairs(runtime.ESPTracerLines) do
        runtime.DestroyESPGeometry(plr)
    end
    for plr in pairs(runtime.ESPSkeletonLines) do
        runtime.DestroyESPGeometry(plr)
    end
end

local function ensureTracerLine(plr)
    local line = runtime.ESPTracerLines[plr]

    if not line then
        line = newESPLine(1.35, 0.92)
        runtime.ESPTracerLines[plr] = line
    end

    return line
end

local function ensureSkeletonLines(plr, needed)
    local lines = runtime.ESPSkeletonLines[plr]

    if not lines then
        lines = {}
        runtime.ESPSkeletonLines[plr] = lines
    end

    while #lines < needed do
        local line = newESPLine(1.25, 0.9)

        if not line then
            break
        end

        lines[#lines + 1] = line
    end

    return lines
end

local function renderESPGeometry()
    if not state.ESP
        or state.InLobby
        or (not state.ESPLines and not state.ESPSkeleton)
        or not runtime.DrawingSupported
    then
        hideAllESPGeometry()
        return
    end

    local camera = workspace.CurrentCamera
    if not camera then
        hideAllESPGeometry()
        return
    end

    local viewport = camera.ViewportSize
    local tracerOrigin = Vector2.new(
        viewport.X * 0.5,
        viewport.Y - 2
    )

    for i = 1, #runtime.PlayerList do
        local plr = runtime.PlayerList[i]

        if plr ~= player then
            local valid, char, hum, hrp = isValidESPTarget(plr)

            if valid and char and hum and hrp then
                local rootScreen, rootOnScreen =
                    camera:WorldToViewportPoint(hrp.Position)

                if state.ESPLines then
                    local tracer = ensureTracerLine(plr)

                    if tracer and rootOnScreen and rootScreen.Z > 0.05 then
                        tracer.From = tracerOrigin
                        tracer.To = Vector2.new(
                            rootScreen.X,
                            rootScreen.Y
                        )
                        tracer.Color = state.ESPColor
                        tracer.Visible = true
                    elseif tracer then
                        tracer.Visible = false
                    end
                else
                    local tracer = runtime.ESPTracerLines[plr]
                    if tracer then
                        tracer.Visible = false
                    end
                end

                if state.ESPSkeleton then
                    local pairs = hum.RigType == Enum.HumanoidRigType.R6
                        and runtime.ESPSkeletonPairsR6
                        or runtime.ESPSkeletonPairsR15

                    local lines = ensureSkeletonLines(plr, #pairs)

                    for pairIndex = 1, #pairs do
                        local pair = pairs[pairIndex]
                        local a = char:FindFirstChild(pair[1])
                        local b = char:FindFirstChild(pair[2])
                        local line = lines[pairIndex]

                        if line and a and b
                            and a:IsA("BasePart")
                            and b:IsA("BasePart")
                        then
                            local sa, ona =
                                camera:WorldToViewportPoint(a.Position)
                            local sb, onb =
                                camera:WorldToViewportPoint(b.Position)

                            if ona and onb
                                and sa.Z > 0.05
                                and sb.Z > 0.05
                            then
                                line.From = Vector2.new(sa.X, sa.Y)
                                line.To = Vector2.new(sb.X, sb.Y)
                                line.Color = state.ESPColor
                                line.Visible = true
                            else
                                line.Visible = false
                            end
                        elseif line then
                            line.Visible = false
                        end
                    end

                    for extra = #pairs + 1, #lines do
                        local line = lines[extra]
                        if line then
                            line.Visible = false
                        end
                    end
                else
                    local lines = runtime.ESPSkeletonLines[plr]
                    if lines then
                        for j = 1, #lines do
                            if lines[j] then
                                lines[j].Visible = false
                            end
                        end
                    end
                end
            else
                hideESPGeometry(plr)
            end
        end
    end
end

runtime.ESPGeometryAccumulator = 0
runtime.Track(RunService.RenderStepped:Connect(function(dt)
    if not runtime.Alive then return end

    runtime.ESPGeometryAccumulator =
        runtime.ESPGeometryAccumulator + dt

    if runtime.ESPGeometryAccumulator < (1 / 30) then
        return
    end

    runtime.ESPGeometryAccumulator = 0

    local ok, err = pcall(renderESPGeometry)
    if not ok then
        runtime.DrawingSupported = false

        if runtime.HideAllESPGeometry then
            pcall(runtime.HideAllESPGeometry)
        end

        warn("[XeroHub] ESP Lines/Skeleton desactivado:", err)
    end
end))

end -- ESP geometry scope

-- ==========================================
-- FOV CENTRADO · EXCLUSIVO DE SILENT AIM
-- ==========================================

local FOVCircle = nil
if Drawing and Drawing.new then
    FOVCircle = runtime.TrackDrawing(Drawing.new("Circle"))
    FOVCircle.Filled = false
    FOVCircle.Color = Color3.fromRGB(255, 255, 255)
    FOVCircle.Visible = false
    FOVCircle.Thickness = 2.6
    FOVCircle.NumSides = 96
    FOVCircle.Transparency = 0.9
end

local function updateFOVCircle()
    if not FOVCircle then return end

    local camera = workspace.CurrentCamera
    local visible = state.ShowFOV
        and state.SilentAim
        and not state.InLobby

    FOVCircle.Visible = visible

    if visible and camera then
        local viewport = camera.ViewportSize
        FOVCircle.Position = Vector2.new(viewport.X * 0.5, viewport.Y * 0.5)
        FOVCircle.Radius = state.FOVRadius
        FOVCircle.Color = state.FOVHasCandidate
            and Color3.fromRGB(0, 255, 0)
            or Color3.fromRGB(255, 255, 255)
    end
end

-- ==========================================
-- RAPID FIRE AUTOMÁTICO · MVSD
-- ==========================================

runtime.RapidFireRemote = nil
runtime.RapidFireSoundPool = {}
runtime.RapidFireSoundIndex = 0
runtime.RapidFireBeamProps = nil
runtime.RapidFireTargetCooldown = setmetatable({}, {__mode = "k"})
runtime.AutoShootTargetCooldown = setmetatable({}, {__mode = "k"})
runtime.RapidFireTrack = nil
runtime.RapidFireTrackCharacter = nil
runtime.RapidFireFallbackSound = nil
runtime.RapidFireAnimation = Instance.new("Animation")
runtime.RapidFireAnimation.AnimationId = "rbxassetid://14840271900"

local function resolveShootGunRemote()
    local cached = runtime.RapidFireRemote
    if cached and cached.Parent and cached:IsA("RemoteEvent") then
        return cached
    end

    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    local remote = remotes and remotes:FindFirstChild("ShootGun")

    if remote and remote:IsA("RemoteEvent") then
        runtime.RapidFireRemote = remote
        return remote
    end

    runtime.RapidFireRemote = nil
    return nil
end

local function getRapidFireTool()
    local char = player.Character
    if not char then return nil end

    local tool = char:FindFirstChildOfClass("Tool")
    if not tool then return nil end

    -- En MVSD el arma equipada contiene el Sound "Fire".
    -- Así evitamos disparar la Remote mientras el jugador tiene otra Tool.
    local fire = tool:FindFirstChild("Fire", true)
    if fire and fire:IsA("Sound") then
        return tool, fire
    end

    return nil
end

local function findRapidMuzzle(tool)
    if not tool then return nil end

    local preferredNames = {
        "Muzzle", "MuzzleAttachment", "GunTip", "Tip",
        "Barrel", "BarrelEnd", "FirePoint", "ShootPoint"
    }

    for i = 1, #preferredNames do
        local obj = tool:FindFirstChild(preferredNames[i], true)
        if obj then
            if obj:IsA("Attachment") then
                return obj.WorldPosition
            elseif obj:IsA("BasePart") then
                return obj.Position
            end
        end
    end

    local handle = tool:FindFirstChild("Handle", true)
    if handle and handle:IsA("BasePart") then
        return handle.Position
    end

    local firstPart = tool:FindFirstChildWhichIsA("BasePart", true)
    if firstPart then
        return firstPart.Position
    end

    return nil
end

local function getRapidShotOrigin(tool)
    local muzzle = findRapidMuzzle(tool)
    if muzzle then
        return muzzle
    end

    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end

    local camera = workspace.CurrentCamera
    local look = camera and camera.CFrame.LookVector or hrp.CFrame.LookVector

    return hrp.Position + Vector3.new(0, 1.45, 0) + look * 1.8
end

local function getNativeRapidHitbox(char)
    if not char then return nil end

    local torso = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
    if torso then
        local nested = torso:FindFirstChild("Part")
        if nested and nested:IsA("BasePart") then
            return nested
        end

        if torso:IsA("BasePart") then
            return torso
        end
    end

    local head = char:FindFirstChild("Head")
    if head then
        local nested = head:FindFirstChild("Part")
        if nested and nested:IsA("BasePart") then
            return nested
        end

        if head:IsA("BasePart") then
            return head
        end
    end

    return nil
end

local function chooseRapidFireTarget(origin)
    local now = os.clock()
    local bestPlr, bestPart, bestDist = nil, nil, math.huge
    local fallbackPlr, fallbackPart, fallbackDist = nil, nil, math.huge

    for i = 1, #runtime.PlayerList do
        local plr = runtime.PlayerList[i]

        if plr ~= player and isEnemy(plr) then
            local char, hum, hrp = getCharacterData(plr)

            if char and hum and hum.Health > 0 and hrp then
                local part = getNativeRapidHitbox(char)

                if part and part.Parent then
                    local dist = origin and (part.Position - origin).Magnitude or 0

                    if dist < fallbackDist then
                        fallbackDist = dist
                        fallbackPlr = plr
                        fallbackPart = part
                    end

                    local cooldownUntil = runtime.RapidFireTargetCooldown[plr] or 0
                    if cooldownUntil <= now and dist < bestDist then
                        bestDist = dist
                        bestPlr = plr
                        bestPart = part
                    end
                end
            end
        end
    end

    -- Si sólo queda un enemigo y aún está dentro del cooldown local, no lo bloqueamos.
    return bestPlr or fallbackPlr, bestPart or fallbackPart
end

local function rapidSnapshotBeam(beam)
    if not beam or not beam:IsA("Beam") then return end

    local props = {}
    local names = {
        "Color", "Transparency", "Width0", "Width1",
        "CurveSize0", "CurveSize1", "FaceCamera",
        "LightEmission", "LightInfluence", "Segments",
        "Texture", "TextureLength", "TextureMode",
        "TextureSpeed", "ZOffset"
    }

    for i = 1, #names do
        local name = names[i]
        pcall(function()
            props[name] = beam[name]
        end)
    end

    runtime.RapidFireBeamProps = props
end

-- Si el juego u otro jugador genera un BulletBeam, copiamos su estilo.
runtime.Track(workspace.DescendantAdded:Connect(function(obj)
    if obj:IsA("Beam") and obj.Name == "BulletBeam" then
        rapidSnapshotBeam(obj)
    end
end))

-- Intenta encontrar una plantilla ya existente sin depender de un disparo manual.
task.defer(function()
    if not runtime.Alive or runtime.RapidFireBeamProps then return end

    local roots = {workspace, ReplicatedStorage}
    for i = 1, #roots do
        local ok, descendants = pcall(function()
            return roots[i]:GetDescendants()
        end)

        if ok then
            for j = 1, #descendants do
                local obj = descendants[j]
                if obj:IsA("Beam") and obj.Name == "BulletBeam" then
                    rapidSnapshotBeam(obj)
                    return
                end
            end
        end
    end
end)

local function applyRapidBeamProps(beam)
    local props = runtime.RapidFireBeamProps

    if props then
        for name, value in pairs(props) do
            pcall(function()
                beam[name] = value
            end)
        end
        return
    end

    -- Fallback parecido al BulletBeam nativo si aún no pudimos muestrearlo.
    beam.FaceCamera = true
    beam.Width0 = 0.055
    beam.Width1 = 0.035
    beam.LightEmission = 1
    beam.LightInfluence = 0
    beam.Segments = 1
    beam.Color = ColorSequence.new(Color3.new(1, 1, 1))
    beam.Transparency = NumberSequence.new(0)
end

local function rapidCreateTracer(origin, hitPosition)
    if typeof(origin) ~= "Vector3" or typeof(hitPosition) ~= "Vector3" then
        return
    end

    local p0 = Instance.new("Part")
    p0.Name = "AttachPart"
    p0.Size = Vector3.new(0.05, 0.05, 0.05)
    p0.Transparency = 1
    p0.Anchored = true
    p0.CanCollide = false
    p0.CanTouch = false
    p0.CanQuery = false
    p0.CFrame = CFrame.new(origin)
    p0.Parent = workspace

    local p1 = Instance.new("Part")
    p1.Name = "AttachPart"
    p1.Size = Vector3.new(0.05, 0.05, 0.05)
    p1.Transparency = 1
    p1.Anchored = true
    p1.CanCollide = false
    p1.CanTouch = false
    p1.CanQuery = false
    p1.CFrame = CFrame.new(hitPosition)
    p1.Parent = workspace

    local a0 = Instance.new("Attachment")
    a0.Name = "Attachment"
    a0.Parent = p0

    local a1 = Instance.new("Attachment")
    a1.Name = "Attachment"
    a1.Parent = p1

    local beam = Instance.new("Beam")
    beam.Name = "BulletBeam"
    beam.Attachment0 = a0
    beam.Attachment1 = a1
    beam.Enabled = true
    applyRapidBeamProps(beam)
    beam.Parent = p0

    task.delay(0.11, function()
        safeDestroy(p0)
        safeDestroy(p1)
    end)
end

local function getRapidFireTrack()
    local char = player.Character
    if not char then return nil end

    if runtime.RapidFireTrack
        and runtime.RapidFireTrackCharacter == char
    then
        return runtime.RapidFireTrack
    end

    if runtime.RapidFireTrack then
        pcall(function()
            runtime.RapidFireTrack:Stop(0)
            runtime.RapidFireTrack:Destroy()
        end)
    end

    runtime.RapidFireTrack = nil
    runtime.RapidFireTrackCharacter = nil

    local hum = char:FindFirstChildOfClass("Humanoid")
    local animator = hum and hum:FindFirstChildOfClass("Animator")
    if not animator then return nil end

    local ok, track = pcall(function()
        return animator:LoadAnimation(runtime.RapidFireAnimation)
    end)

    if ok and track then
        track.Priority = Enum.AnimationPriority.Action2
        runtime.RapidFireTrack = track
        runtime.RapidFireTrackCharacter = char
        return track
    end

    return nil
end

local function rapidPlayAnimation()
    local track = getRapidFireTrack()
    if not track then return end

    pcall(function()
        track:Play(0.015, 1, 1)
    end)
end

local function rapidPlayFireSound(sourceSound)
    if not sourceSound or not sourceSound:IsA("Sound") then
        return
    end

    local pool = runtime.RapidFireSoundPool
    local poolSize = 10

    runtime.RapidFireSoundIndex = (runtime.RapidFireSoundIndex % poolSize) + 1
    local index = runtime.RapidFireSoundIndex
    local sound = pool[index]

    if not sound or not sound.Parent then
        sound = sourceSound:Clone()
        sound.Name = "XeroRapidFire"
        sound.Looped = false
        sound.Parent = SoundService
        pool[index] = sound
    else
        pcall(function()
            sound.SoundId = sourceSound.SoundId
            sound.Volume = sourceSound.Volume
            sound.PlaybackSpeed = sourceSound.PlaybackSpeed
            sound.RollOffMaxDistance = sourceSound.RollOffMaxDistance
            sound.RollOffMinDistance = sourceSound.RollOffMinDistance
        end)
    end

    pcall(function()
        sound.TimePosition = 0
        sound:Play()
    end)
end

local function getRapidFireFallbackSound()
    local sound = runtime.RapidFireFallbackSound
    if sound and sound.Parent then
        return sound
    end

    sound = Instance.new("Sound")
    sound.Name = "XeroRapidFireFallbackSource"
    sound.SoundId = "rbxassetid://12717436463"
    sound.Volume = 1
    sound.PlaybackSpeed = 1.25
    sound.Looped = false
    sound.Parent = SoundService

    runtime.RapidFireFallbackSound = sound
    return sound
end

local function rapidFireOneShot()
    if not state.RapidFire or state.InLobby then
        return false
    end

    local tool, fireSound = getRapidFireTool()
    if not tool then
        return false
    end

    local remote = resolveShootGunRemote()
    if not remote then
        return false
    end

    local origin = getRapidShotOrigin(tool)
    if not origin then
        return false
    end

    local targetPlayer, hitPart = chooseRapidFireTarget(origin)
    if not targetPlayer or not hitPart or not hitPart.Parent then
        return false
    end

    local hitPosition = hitPart.Position
    local delta = hitPosition - origin
    if delta.Magnitude <= 0.01 then
        return false
    end

    local aimPoint = origin + delta.Unit * 1000

    -- Efectos siempre activos al disparar.
    rapidPlayFireSound(fireSound)
    rapidPlayAnimation()
    rapidCreateTracer(origin, hitPosition)

    local ok = pcall(function()
        remote:FireServer(
            origin,
            aimPoint,
            hitPart,
            hitPosition
        )
    end)

    if ok then
        -- Evita gastar todo el burst en el mismo jugador mientras replica Humanoid.Died.
        runtime.RapidFireTargetCooldown[targetPlayer] = os.clock() + 0.14
        return true
    end

    return false
end

-- ==========================================
-- AUTO SHOOT · sólo cuando alguna parte del enemigo es visible
-- ==========================================

local function chooseAutoShootTarget()
    if not state.AutoShoot or state.InLobby then
        return nil
    end

    -- Auto Shoot NO equipa el arma. Sólo funciona si ya la tienes equipada.
    local tool, fireSound = getRapidFireTool()
    if not tool then
        return nil
    end

    local remote = resolveShootGunRemote()
    if not remote then
        return nil
    end

    local localChar = player.Character
    local localHum = localChar and localChar:FindFirstChildOfClass("Humanoid")
    local localRoot = localChar and localChar:FindFirstChild("HumanoidRootPart")
    local camera = workspace.CurrentCamera

    if not localChar or not localHum or localHum.Health <= 0
        or not localRoot or not camera
    then
        return nil
    end

    local origin = getRapidShotOrigin(tool)
    if not origin then
        return nil
    end

    local now = os.clock()
    local bestPlayer, bestPart
    local bestMetric = math.huge

    for i = 1, #runtime.PlayerList do
        local plr = runtime.PlayerList[i]

        if plr ~= player and isEnemy(plr) then
            local char, hum, hrp = getCharacterData(plr)

            if char and hum and hrp
                and playerIsInActiveRound(plr, char, hrp, hum)
                and (runtime.AutoShootTargetCooldown[plr] or 0) <= now
            then
                -- Auto Shoot comparte EXACTAMENTE el selector corporal de Silent Aim.
                -- No importa si Silent Aim está encendido o apagado:
                -- usa la selección guardada en runtime.TargetSelections.SilentAim.
                local parts = runtime.CollectTargetParts(char, "SilentAim")

                if parts then
                    for j = 1, #parts do
                        local hitbox = parts[j]

                        if hitbox and hitbox.Parent then
                            -- "Visible" significa:
                            -- 1) la parte seleccionada está dentro de la pantalla,
                            -- 2) no hay pared/objeto bloqueándola.
                            local screen, onScreen =
                                camera:WorldToViewportPoint(hitbox.Position)

                            if onScreen and screen.Z > 0
                                and visibleTarget(
                                    localChar,
                                    char,
                                    hitbox,
                                    origin
                                )
                            then
                                local delta = hitbox.Position - origin
                                local metric = delta:Dot(delta)

                                if metric < bestMetric then
                                    bestMetric = metric
                                    bestPlayer = plr
                                    bestPart = hitbox
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    if not bestPlayer or not bestPart then
        return nil
    end

    return bestPlayer, bestPart, tool, fireSound, remote, origin
end

local function autoShootOneShot()
    if os.clock() < (state.AutoShootNextAllowedAt or 0) then
        return false
    end

    local targetPlayer, hitPart, tool, fireSound, remote, origin =
        chooseAutoShootTarget()

    if not targetPlayer or not hitPart or not hitPart.Parent then
        return false
    end

    local hitPosition = hitPart.Position
    local delta = hitPosition - origin

    if delta.Magnitude <= 0.01 then
        return false
    end

    local aimPoint = origin + delta.Unit * 1000

    -- Mismos efectos que el disparo automático que ya te funciona.
    rapidPlayFireSound(fireSound)
    rapidPlayAnimation()
    rapidCreateTracer(origin, hitPosition)

    local ok = pcall(function()
        remote:FireServer(
            origin,
            aimPoint,
            hitPart,
            hitPosition
        )
    end)

    if ok then
        local now = os.clock()

        -- Cooldown local al mismo target.
        runtime.AutoShootTargetCooldown[targetPlayer] =
            now + 0.22

        -- Delay GLOBAL entre disparos/targets. Así no encadena kills
        -- instantáneamente; el usuario controla el tiempo desde el slider.
        state.AutoShootNextAllowedAt =
            now + math.clamp(
                tonumber(state.AutoShootDelay) or 0.3,
                0,
                2
            )

        return true
    end

    return false
end

runtime.AutoShootOneShot = autoShootOneShot

local function roundStartSpamOneShot()
    if not state.RoundStartSpam or state.InLobby then
        return false
    end

    local remote = resolveShootGunRemote()
    if not remote then
        return false
    end

    local tool, fireSound = getRapidFireTool()

    -- getRapidShotOrigin ya tiene fallback a HRP/cámara cuando tool=nil.
    local origin = getRapidShotOrigin(tool)
    if not origin then
        return false
    end

    local targetPlayer, hitPart = chooseRapidFireTarget(origin)
    if not targetPlayer or not hitPart or not hitPart.Parent then
        return false
    end

    local hitPosition = hitPart.Position
    local delta = hitPosition - origin
    if delta.Magnitude <= 0.01 then
        return false
    end

    local aimPoint = origin + delta.Unit * 1000

    -- Efectos siempre activos al disparar.
    rapidPlayFireSound(fireSound or getRapidFireFallbackSound())
    rapidPlayAnimation()
    rapidCreateTracer(origin, hitPosition)

    local ok = pcall(function()
        remote:FireServer(
            origin,
            aimPoint,
            hitPart,
            hitPosition
        )
    end)

    if ok then
        runtime.RapidFireTargetCooldown[targetPlayer] = os.clock() + 0.06
        return true
    end

    return false
end

runtime.RapidFireOneShot = rapidFireOneShot
runtime.RoundStartSpamOneShot = roundStartSpamOneShot

-- ==========================================
-- MASTER LOOP
-- ==========================================

runtime.Track(RunService.Heartbeat:Connect(function(dt)
    if not runtime.Alive then return end

    state.LobbyTimer = state.LobbyTimer + dt
    if state.LobbyTimer >= 0.35 then
        state.LobbyTimer = 0

        local wasLobby = state.InLobby
        local oldMatchId = state.MatchId
        refreshLobbyState()

        if wasLobby ~= state.InLobby or oldMatchId ~= state.MatchId then
            state.AutoShootNextAllowedAt = 0
            state.AutoShootAccumulator = 0
            state.RoundStartSpamAccumulator = 0
            table.clear(runtime.AutoShootTargetCooldown)
            runtime.RestoreAllExpandedHitboxes()
        end

        if state.InLobby and not wasLobby then
            clearESP()
            aimHookState.Target = nil
            state.FOVHasCandidate = false
        end
    end

    -- Silent Aim ~33 Hz. La misma pasada calcula si el FOV debe ponerse verde.
    if state.SilentAim then
        state.SilentAccumulator = state.SilentAccumulator + dt

        if state.SilentAccumulator >= 0.03 then
            state.SilentAccumulator = 0

            if not state.InLobby then
                local plr, part, fovCandidate = chooseTarget(
                    "SilentAim",
                    state.FOVFilter
                )

                state.SilentTargetPlayer = plr
                state.SilentTarget = part
                state.FOVHasCandidate = fovCandidate
                aimHookState.Target = part
            else
                state.SilentTargetPlayer = nil
                state.SilentTarget = nil
                state.FOVHasCandidate = false
                aimHookState.Target = nil
            end
        end
    else
        state.SilentAccumulator = 0
        state.SilentTargetPlayer = nil
        state.SilentTarget = nil
        state.FOVHasCandidate = false
        aimHookState.Target = nil
    end

    -- Auto Shoot ~33 Hz.
    -- Sólo manda ShootGun cuando la gun está equipada y existe
    -- alguna parte del enemigo visible en pantalla + sin pared.
    if state.AutoShoot and not state.InLobby then
        state.AutoShootAccumulator =
            state.AutoShootAccumulator + dt

        if state.AutoShootAccumulator >= state.AutoShootScanInterval then
            state.AutoShootAccumulator = 0
            autoShootOneShot()
        end
    else
        state.AutoShootAccumulator = 0

        if not state.AutoShoot then
            table.clear(runtime.AutoShootTargetCooldown)
        end
    end

    -- Rapid Fire automático. No depende de input/manual shot.
    if state.RapidFire and not state.InLobby then
        state.RapidFireAccumulator = state.RapidFireAccumulator + dt

        local rate = math.clamp(tonumber(state.RapidFireRate) or 16, 1, 30)
        local interval = 1 / rate

        -- Acumulador con tope para evitar bursts enormes tras un freeze de FPS.
        if state.RapidFireAccumulator > interval * 2 then
            state.RapidFireAccumulator = interval * 2
        end

        if state.RapidFireAccumulator >= interval then
            state.RapidFireAccumulator = state.RapidFireAccumulator - interval
            rapidFireOneShot()
        end
    else
        state.RapidFireAccumulator = 0
    end

    -- Spam Fire continuo mientras esté activado y haya partida; no requiere Tool equipado.
    if state.RoundStartSpam
        and not state.InLobby
    then
        state.RoundStartSpamAccumulator =
            state.RoundStartSpamAccumulator + dt

        local rate = math.clamp(
            tonumber(state.RoundStartSpamRate) or 45,
            5,
            60
        )
        local interval = 1 / rate
        local shotsThisFrame = 0

        while state.RoundStartSpamAccumulator >= interval
            and shotsThisFrame < 3
        do
            state.RoundStartSpamAccumulator =
                state.RoundStartSpamAccumulator - interval

            roundStartSpamOneShot()
            shotsThisFrame = shotsThisFrame + 1
        end

        if state.RoundStartSpamAccumulator > interval * 3 then
            state.RoundStartSpamAccumulator = interval * 3
        end
    else
        state.RoundStartSpamAccumulator = 0

    end

    -- Hitbox Expander nativo a 20 Hz.
    state.HitboxAccumulator = state.HitboxAccumulator + dt

    if state.HitboxAccumulator >= 0.05 then
        state.HitboxAccumulator = 0

        if state.HitboxExpander and not state.InLobby then
            local ok, err = pcall(runtime.RefreshExpandedHitboxes)

            if not ok then
                state.HitboxExpander = false
                pcall(runtime.RestoreAllExpandedHitboxes)
                warn("[XeroHub] Hitbox Expander desactivado:", err)
            end
        elseif state.InLobby or not state.HitboxExpander then
            pcall(runtime.RestoreAllExpandedHitboxes)
        end
    end

    -- ESP a 10 Hz: Highlight no requiere reescribirse por frame y el texto no necesita 20/60 Hz.
    if state.ESP and not state.InLobby then
        state.ESPAccumulator = state.ESPAccumulator + dt

        if state.ESPAccumulator >= 0.10 then
            state.ESPAccumulator = 0

            for i = 1, #runtime.PlayerList do
                local plr = runtime.PlayerList[i]
                if plr ~= player then
                    ensureESP(plr)
                end
            end

            -- Evita que un Billboard sobreviva a cambios de Team/Character entre ticks.
            for plr in pairs(runtime.Billboards) do
                if not isValidESPTarget(plr) then
                    removeESP(plr)
                end
            end
        end
    else
        state.ESPAccumulator = 0

        if state.InLobby or not state.ESP then
            clearESP()
        end
    end
end))

runtime.Track(RunService.RenderStepped:Connect(updateFOVCircle))

-- ==========================================
-- UI · PORT DE DUELS PARA MVSD
-- ==========================================

-- Splash inicial estilo DUELS, pero sin bloquear la carga si algún módulo externo falla.
local startupSplashState = {}
do
    local splashParent = playerGui
    pcall(function()
        splashParent = gethui and gethui() or game:GetService("CoreGui")
    end)

    local previous = splashParent and splashParent:FindFirstChild("XeroHub_MVSD_Startup")
    if previous then previous:Destroy() end

    local gui = Instance.new("ScreenGui")
    gui.Name = "XeroHub_MVSD_Startup"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.DisplayOrder = 2147483647
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.Parent = splashParent
    runtime.StartupGui = gui

    local splash = Instance.new("CanvasGroup")
    splash.Size = UDim2.fromScale(1, 1)
    splash.BackgroundColor3 = Color3.new(0, 0, 0)
    splash.BorderSizePixel = 0
    splash.ZIndex = 1
    splash.Parent = gui

    local content = Instance.new("Frame")
    content.AnchorPoint = Vector2.new(0.5, 0.5)
    content.Position = UDim2.fromScale(0.5, 0.5)
    content.Size = UDim2.fromOffset(460, 128)
    content.BackgroundTransparency = 1
    content.ZIndex = 2
    content.Parent = splash

    local brand = Instance.new("TextLabel")
    brand.AnchorPoint = Vector2.new(0.5, 0)
    brand.Size = UDim2.new(1, 0, 0, 46)
    brand.Position = UDim2.new(0.5, 0, 0, 10)
    brand.BackgroundTransparency = 1
    brand.RichText = true
    brand.Text = '<font color="#FFFFFF">XERO</font><font color="#A7A7A7"> HUB</font>'
    brand.TextColor3 = Color3.new(1, 1, 1)
    brand.Font = Enum.Font.GothamBold
    brand.TextSize = 32
    brand.ZIndex = 3
    brand.Parent = content

    local status = Instance.new("TextLabel")
    status.AnchorPoint = Vector2.new(0.5, 0)
    status.Size = UDim2.new(1, -48, 0, 22)
    status.Position = UDim2.new(0.5, 0, 0, 62)
    status.BackgroundTransparency = 1
    status.Text = "Preparando MVSD..."
    status.TextColor3 = Color3.fromHex("#9B9B9B")
    status.Font = Enum.Font.GothamMedium
    status.TextSize = 13
    status.ZIndex = 3
    status.Parent = content

    local track = Instance.new("Frame")
    track.AnchorPoint = Vector2.new(0.5, 0)
    track.Size = UDim2.fromOffset(230, 2)
    track.Position = UDim2.new(0.5, 0, 0, 98)
    track.BackgroundColor3 = Color3.fromHex("#242424")
    track.BorderSizePixel = 0
    track.ZIndex = 3
    track.Parent = content
    Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)

    local progress = Instance.new("Frame")
    progress.Size = UDim2.fromScale(0.08, 1)
    progress.BackgroundColor3 = Color3.fromHex("#E7E7E7")
    progress.BorderSizePixel = 0
    progress.ZIndex = 4
    progress.Parent = track
    Instance.new("UICorner", progress).CornerRadius = UDim.new(1, 0)

    startupSplashState.Gui = gui
    startupSplashState.Group = splash
    startupSplashState.Status = status
    startupSplashState.Progress = progress
end

function startupSplashState.Finish(message)
    local gui = startupSplashState.Gui
    if not gui or not gui.Parent then return end

    if message and startupSplashState.Status then
        startupSplashState.Status.Text = message
    end
    if startupSplashState.Progress then
        startupSplashState.Progress.Size = UDim2.fromScale(1, 1)
    end

    pcall(function() gui:Destroy() end)
    runtime.StartupGui = nil
    startupSplashState.Gui = nil
end

-- Notificaciones monocromáticas estilo DUELS.
do
    local old = playerGui:FindFirstChild("XeroHub_MVSD_Notifications")
    if old then old:Destroy() end

    local gui = Instance.new("ScreenGui")
    gui.Name = "XeroHub_MVSD_Notifications"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.DisplayOrder = 2147483647
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.Parent = playerGui
    runtime.NotificationGui = gui

    local container = Instance.new("Frame")
    container.Size = UDim2.fromScale(1, 1)
    container.BackgroundTransparency = 1
    container.Parent = gui

    runtime.NotificationQueue = {}
    runtime.NotificationBusy = false
    runtime.NotificationsReady = false
    runtime.SuppressNotifications = false

    local function createBanner(text, title)
        local banner = Instance.new("CanvasGroup")
        banner.AnchorPoint = Vector2.new(1, 0)
        banner.Position = UDim2.new(1, 374, 0, 64)
        banner.Size = UDim2.fromOffset(350, 82)
        banner.BackgroundColor3 = Color3.fromRGB(13, 13, 13)
        banner.BackgroundTransparency = 0.02
        banner.BorderSizePixel = 0
        banner.ClipsDescendants = true
        banner.GroupTransparency = 1
        banner.ZIndex = 201
        banner.Parent = container
        Instance.new("UICorner", banner).CornerRadius = UDim.new(0, 12)

        local stroke = Instance.new("UIStroke", banner)
        stroke.Color = Color3.fromRGB(68, 68, 68)
        stroke.Transparency = 0.2
        stroke.Thickness = 1

        local accent = Instance.new("Frame", banner)
        accent.Size = UDim2.new(0, 2, 1, -28)
        accent.Position = UDim2.fromOffset(12, 14)
        accent.BackgroundColor3 = Color3.fromRGB(220, 220, 220)
        accent.BorderSizePixel = 0
        accent.ZIndex = 202
        Instance.new("UICorner", accent).CornerRadius = UDim.new(1, 0)

        local titleLabel = Instance.new("TextLabel", banner)
        titleLabel.Size = UDim2.new(1, -46, 0, 16)
        titleLabel.Position = UDim2.fromOffset(25, 11)
        titleLabel.BackgroundTransparency = 1
        titleLabel.Text = string.upper(title or "XeroHub")
        titleLabel.TextColor3 = Color3.fromRGB(245, 245, 245)
        titleLabel.Font = Enum.Font.GothamMedium
        titleLabel.TextSize = 10
        titleLabel.TextXAlignment = Enum.TextXAlignment.Left
        titleLabel.ZIndex = 202

        local body = Instance.new("TextLabel", banner)
        body.Size = UDim2.new(1, -46, 0, 44)
        body.Position = UDim2.fromOffset(25, 29)
        body.BackgroundTransparency = 1
        body.Text = tostring(text)
        body.TextColor3 = Color3.fromRGB(185, 185, 185)
        body.Font = Enum.Font.Gotham
        body.TextSize = 12
        body.TextWrapped = true
        body.TextXAlignment = Enum.TextXAlignment.Left
        body.TextYAlignment = Enum.TextYAlignment.Top
        body.ZIndex = 202

        return banner
    end

    local function runQueue()
        if runtime.NotificationBusy then return end
        runtime.NotificationBusy = true

        task.spawn(function()
            while runtime.Alive and #runtime.NotificationQueue > 0 do
                local payload = table.remove(runtime.NotificationQueue, 1)
                local banner = createBanner(payload.Text, payload.Title)

                local enter = TweenService:Create(
                    banner,
                    TweenInfo.new(0.18, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
                    {Position = UDim2.new(1, -12, 0, 64), GroupTransparency = 0}
                )
                enter:Play()
                enter.Completed:Wait()

                task.wait(payload.Duration or 0.72)
                if not runtime.Alive or not banner.Parent then break end

                local exitTween = TweenService:Create(
                    banner,
                    TweenInfo.new(0.14, Enum.EasingStyle.Quint, Enum.EasingDirection.In),
                    {Position = UDim2.new(1, 374, 0, 64), GroupTransparency = 1}
                )
                exitTween:Play()
                exitTween.Completed:Wait()

                if banner.Parent then banner:Destroy() end
                task.wait(0.02)
            end

            runtime.NotificationBusy = false
            if runtime.Alive and #runtime.NotificationQueue > 0 then
                runQueue()
            end
        end)
    end

    runtime.Notify = function(text, options)
        options = type(options) == "table" and options or {}
        if not runtime.Alive or runtime.SuppressNotifications then return end
        if not runtime.NotificationsReady and not options.Force then return end

        runtime.NotificationQueue[#runtime.NotificationQueue + 1] = {
            Text = tostring(text or ""),
            Title = tostring(options.Title or options.title or "XeroHub"),
            Duration = tonumber(options.Duration or options.duration) or 0.72,
        }

        while #runtime.NotificationQueue > 4 do
            table.remove(runtime.NotificationQueue, 1)
        end

        runQueue()
    end
end

local WindUI
local NOX_UI_URL = runtimeEnv.NOX_UI_URL
    or "https://raw.githubusercontent.com/OnyxDevv/Onyx-web/refs/heads/main/main%20(3).lua"

local okUI, resultUI = pcall(function()
    local source

    if isfile and readfile and isfile("XeroHub_UI.lua") then
        source = readfile("XeroHub_UI.lua")
    else
        source = game:HttpGet(NOX_UI_URL)
    end

    local chunk, compileError = loadstring(source)
    if not chunk then
        error("No se pudo compilar UI: " .. tostring(compileError))
    end

    return chunk()
end)

if not okUI or not resultUI then
    warn("[XeroHub] UI error:", resultUI)
    startupSplashState.Finish("No se pudo cargar la UI")
    return
end

WindUI = resultUI

local Window = WindUI:CreateWindow({
    Title = "Xero | MVSD",
    Subtitle = "MVSD",
    Theme = "Xero",
    Author = "by Kev",
    Size = UDim2.fromOffset(620, 350),
    MinSize = Vector2.new(330, 270),
    Resizable = true,
    OpenButton = {
        Title = "Abrir XeroHub",
        Enabled = true,
    },
})

if startupSplashState.Progress then
    startupSplashState.Progress.Size = UDim2.fromScale(0.72, 1)
end

local MainSection = Window:Section({Title = "PRINCIPAL", Opened = true})
local PersonalSection = Window:Section({Title = "PERSONAL", Opened = true})

local Tabs = {
    Inicio = MainSection:Tab({Title = "Inicio", Icon = "solar:home-bold"}),
    Aim = MainSection:Tab({Title = "Aimbot", Icon = "solar:target-bold"}),
    Hitbox = MainSection:Tab({Title = "Hitbox", Icon = "solar:box-bold"}),
    KillAll = MainSection:Tab({Title = "Kill All", Icon = "solar:bolt-bold"}),
    Vis = MainSection:Tab({Title = "Visuales", Icon = "solar:eye-bold"}),
    Mov = MainSection:Tab({Title = "Movimiento", Icon = "solar:running-bold"}),
    Graficos = MainSection:Tab({Title = "Gráficos", Icon = "solar:palette-bold"}),
    Sonidos = MainSection:Tab({Title = "Sonidos", Icon = "solar:volume-loud-bold"}),
    Config = PersonalSection:Tab({Title = "Configuración", Icon = "solar:settings-bold"}),
    Creditos = PersonalSection:Tab({Title = "Créditos", Icon = "solar:user-bold"}),
}

local UIElements = {}

-- FIRE QUICK TOGGLE STATE
function runtime.SetFireEnabled(key, value, syncToggle)
    if not runtime.Alive then return end
    if key ~= "RapidFire" and key ~= "RoundStartSpam" then return end
    value = value == true
    local changed = state[key] ~= value
    state[key] = value

    if changed then
        if key == "RapidFire" then
            state.RapidFireAccumulator = 0
            if not value then
                table.clear(runtime.RapidFireTargetCooldown)
            end
        else
            state.RoundStartSpamAccumulator = 0
        end
    end

    if syncToggle then
        local toggle = key == "RapidFire"
            and UIElements.TogRapidFire or UIElements.TogRoundStartSpam
        if toggle and toggle.Set then
            local previous = runtime.SuppressNotifications
            runtime.SuppressNotifications = true
            pcall(function() toggle:Set(value) end)
            runtime.SuppressNotifications = previous
        end
    end

    if runtime.RefreshFireButtons then
        runtime.RefreshFireButtons()
    end
end
-- END FIRE QUICK TOGGLE STATE


-- Notificación automática de toggles, igual que la UI grande de DUELS.
for _, tab in pairs(Tabs) do
    pcall(function()
        local originalToggle = tab.Toggle
        if type(originalToggle) == "function" then
            tab.Toggle = function(self, options)
                options = options or {}
                local callback = options.Callback
                local title = tostring(options.Title or "Función")
                local ready = false

                options.Callback = function(value, ...)
                    if callback then callback(value, ...) end

                    if ready and not runtime.SuppressNotifications then
                        runtime.Notify(
                            title .. (value == true and " activado" or " desactivado"),
                            {Title = "XeroHub · Ajuste"}
                        )
                    end
                end

                local toggle = originalToggle(self, options)
                task.defer(function() ready = true end)
                return toggle
            end
        end
    end)
end

-- Selector corporal 2D responsive copiado/adaptado de DUELS.
function runtime.EnsureBodySelector()
    if runtime.BodySelectorGui and runtime.BodySelectorGui.Parent then return end

    local parent = playerGui
    pcall(function()
        parent = gethui and gethui() or game:GetService("CoreGui")
    end)

    local gui = Instance.new("ScreenGui")
    gui.Name = "XeroHub_MVSD_BodySelector"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.DisplayOrder = 2147483647
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    pcall(function()
        gui.ScreenInsets = Enum.ScreenInsets.None
        gui.ClipToDeviceSafeArea = false
        gui.SafeAreaCompatibility = Enum.SafeAreaCompatibility.None
        gui.OnTopOfCoreBlur = true
    end)
    gui.Parent = parent
    runtime.BodySelectorGui = gui

    local overlay = Instance.new("Frame")
    overlay.Name = "Overlay"
    overlay.Size = UDim2.fromScale(1, 1)
    overlay.BackgroundColor3 = Color3.fromHex("#000000")
    overlay.BackgroundTransparency = 0.36
    overlay.Visible = false
    overlay.Active = true
    overlay.ZIndex = 400
    overlay.Parent = gui

    local card = Instance.new("CanvasGroup")
    card.AnchorPoint = Vector2.new(0.5, 0.5)
    card.Position = UDim2.fromScale(0.5, 0.5)
    card.Size = UDim2.fromOffset(440, 360)
    card.BackgroundColor3 = Color3.fromHex("#111214")
    card.BorderSizePixel = 0
    card.ZIndex = 401
    card.Parent = overlay
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 22)

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromHex("#5E636A")
    stroke.Transparency = 0.35
    stroke.Thickness = 1
    stroke.Parent = card

    local scale = Instance.new("UIScale")
    scale.Scale = 1
    scale.Parent = card

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -88, 0, 24)
    title.Position = UDim2.fromOffset(18, 14)
    title.BackgroundTransparency = 1
    title.Text = "Selector corporal"
    title.TextColor3 = Color3.fromHex("#F7F8F9")
    title.Font = Enum.Font.GothamBold
    title.TextSize = 15
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.ZIndex = 402
    title.Parent = card

    local closeSelector = Instance.new("TextButton")
    closeSelector.Name = "Close"
    closeSelector.Size = UDim2.fromOffset(28, 28)
    closeSelector.Position = UDim2.new(1, -42, 0, 12)
    closeSelector.BackgroundColor3 = Color3.fromHex("#25272B")
    closeSelector.BorderSizePixel = 0
    closeSelector.Text = "×"
    closeSelector.TextColor3 = Color3.fromHex("#E7E7E7")
    closeSelector.Font = Enum.Font.GothamBold
    closeSelector.TextSize = 16
    closeSelector.AutoButtonColor = false
    closeSelector.ZIndex = 405
    closeSelector.Parent = card
    Instance.new("UICorner", closeSelector).CornerRadius = UDim.new(0, 9)
    closeSelector.Activated:Connect(function()
        overlay.Visible = false
    end)

    local subtitle = Instance.new("TextLabel")
    subtitle.Size = UDim2.new(1, -36, 0, 28)
    subtitle.Position = UDim2.fromOffset(18, 39)
    subtitle.BackgroundTransparency = 1
    subtitle.Text = "Toca varias zonas del cuerpo. Las partes activas se iluminan al instante."
    subtitle.TextColor3 = Color3.fromHex("#9DA3AB")
    subtitle.Font = Enum.Font.Gotham
    subtitle.TextSize = 10
    subtitle.TextWrapped = true
    subtitle.TextXAlignment = Enum.TextXAlignment.Left
    subtitle.TextYAlignment = Enum.TextYAlignment.Top
    subtitle.ZIndex = 402
    subtitle.Parent = card

    local figure = Instance.new("Frame")
    figure.Size = UDim2.fromOffset(160, 220)
    figure.Position = UDim2.fromOffset(18, 74)
    figure.BackgroundColor3 = Color3.fromHex("#090A0C")
    figure.BackgroundTransparency = 0.08
    figure.BorderSizePixel = 0
    figure.ZIndex = 402
    figure.Parent = card
    Instance.new("UICorner", figure).CornerRadius = UDim.new(0, 14)

    runtime.BodySelector = {
        Mode = "SilentAim",
        Segments = {},
        Rows = {},
        Overlay = overlay,
        Card = card,
        Scale = scale,
        Title = title,
        Subtitle = subtitle,
        CloseButton = closeSelector,
        Figure = figure,
        List = nil,
    }

    local function toggle(name)
        local selected = runtime.TargetSelections[runtime.BodySelector.Mode]
        selected[name] = not selected[name] or nil
        runtime.BodySelector.Refresh()
    end

    local function segment(name, x, y, w, h, radius)
        local button = Instance.new("TextButton")
        button.Name = name
        button.Size = UDim2.fromOffset(w, h)
        button.Position = UDim2.fromOffset(x, y)
        button.BackgroundColor3 = Color3.fromHex("#24262A")
        button.BorderSizePixel = 0
        button.Text = ""
        button.AutoButtonColor = false
        button.ZIndex = 404
        button.Parent = figure
        Instance.new("UICorner", button).CornerRadius = UDim.new(0, radius or 10)
        local segStroke = Instance.new("UIStroke")
        segStroke.Color = Color3.fromHex("#4B5057")
        segStroke.Transparency = 0.35
        segStroke.Thickness = 1
        segStroke.Parent = button
        runtime.BodySelector.Segments[name] = {Button = button, Stroke = segStroke}
        button.Activated:Connect(function() toggle(name) end)
    end

    segment("Cabeza", 59, 8, 42, 42, 21)
    segment("Torso superior", 46, 55, 68, 45, 11)
    segment("Torso inferior", 50, 104, 60, 32, 9)
    segment("Brazo izquierdo", 20, 58, 20, 78, 10)
    segment("Brazo derecho", 120, 58, 20, 78, 10)
    segment("Pierna izquierda", 49, 143, 25, 66, 11)
    segment("Pierna derecha", 86, 143, 25, 66, 11)

    local list = Instance.new("ScrollingFrame")
    list.Name = "BodyPartList"
    list.Size = UDim2.fromOffset(232, 220)
    list.Position = UDim2.fromOffset(190, 74)
    list.BackgroundTransparency = 1
    list.BorderSizePixel = 0
    list.ScrollBarThickness = 2
    list.ScrollBarImageColor3 = Color3.fromHex("#6E737A")
    list.CanvasSize = UDim2.fromOffset(0, 210)
    list.ScrollingDirection = Enum.ScrollingDirection.Y
    list.ElasticBehavior = Enum.ElasticBehavior.Never
    list.ZIndex = 402
    list.Parent = card
    runtime.BodySelector.List = list

    for index, name in ipairs(runtime.TargetBodyOrder) do
        local row = Instance.new("TextButton")
        row.Size = UDim2.new(1, 0, 0, 27)
        row.Position = UDim2.fromOffset(0, (index - 1) * 30)
        row.BackgroundColor3 = Color3.fromHex("#1C1E21")
        row.BorderSizePixel = 0
        row.TextColor3 = Color3.fromHex("#E7E7E7")
        row.Font = Enum.Font.GothamMedium
        row.TextSize = 10
        row.TextXAlignment = Enum.TextXAlignment.Left
        row.AutoButtonColor = false
        row.ZIndex = 403
        row.Parent = list
        Instance.new("UICorner", row).CornerRadius = UDim.new(0, 10)
        local pad = Instance.new("UIPadding")
        pad.PaddingLeft = UDim.new(0, 12)
        pad.Parent = row
        runtime.BodySelector.Rows[name] = row
        row.Activated:Connect(function() toggle(name) end)
    end

    local function action(text, x, width, callback)
        local b = Instance.new("TextButton")
        b.Size = UDim2.fromOffset(width, 32)
        b.Position = UDim2.new(0, x, 1, -42)
        b.BackgroundColor3 = Color3.fromHex("#25272B")
        b.BorderSizePixel = 0
        b.Text = text
        b.TextColor3 = Color3.fromHex("#F2F3F5")
        b.Font = Enum.Font.GothamBold
        b.TextSize = 10
        b.AutoButtonColor = false
        b.ZIndex = 403
        b.Parent = card
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 11)
        b.Activated:Connect(callback)
        return b
    end

    local selectAllButton = action("Todo", 18, 74, function()
        local selected = runtime.TargetSelections[runtime.BodySelector.Mode]
        for _, name in ipairs(runtime.TargetBodyOrder) do selected[name] = true end
        runtime.BodySelector.Refresh()
    end)
    local clearButton = action("Limpiar", 98, 78, function()
        table.clear(runtime.TargetSelections[runtime.BodySelector.Mode])
        runtime.BodySelector.Refresh()
    end)
    local done = action("Aplicar", 330, 92, function()
        local mode = runtime.BodySelector.Mode
        local selected = runtime.TargetSelections[mode]
        if not next(selected) then selected["Cabeza"] = true end
        runtime.SetTargetSelection(mode, runtime.GetTargetSelectionArray(mode))
        overlay.Visible = false
        runtime.Notify("Silent Aim: selección corporal aplicada.")
    end)
    done.BackgroundColor3 = Color3.fromHex("#E6E9EC")
    done.TextColor3 = Color3.fromHex("#111214")
    runtime.BodySelector.SelectAllButton = selectAllButton
    runtime.BodySelector.ClearButton = clearButton
    runtime.BodySelector.DoneButton = done

    -- Reflow real del selector. En portrait apila el muñeco y la lista; en
    -- landscape/desktop conserva las dos columnas. Sólo usa UIScale como último
    -- recurso si el viewport es físicamente menor que el layout base.
    function runtime.ApplyBodySelectorResponsiveLayout()
        local selector = runtime.BodySelector
        if not selector then return 1 end
        local bounds = selector.Overlay.AbsoluteSize
        if bounds.X < 1 or bounds.Y < 1 then
            local currentCamera = workspace.CurrentCamera
            bounds = currentCamera and currentCamera.ViewportSize or Vector2.new(800, 600)
        end

        local margin = math.clamp(math.floor(math.min(bounds.X, bounds.Y) * 0.025), 6, 14)
        local rawAvailableW = math.max(1, bounds.X - margin * 2)
        local rawAvailableH = math.max(1, bounds.Y - margin * 2)
        local availableW = math.max(240, rawAvailableW)
        local availableH = math.max(260, rawAvailableH)
        local portrait = availableW < 470 or (availableW / math.max(1, availableH)) < 1.05

        if not portrait then
            selector.Card.Size = UDim2.fromOffset(440, 360)
            selector.Title.Position = UDim2.fromOffset(18, 14)
            selector.Title.Size = UDim2.new(1, -88, 0, 24)
            selector.Title.TextSize = 15
            selector.Subtitle.Position = UDim2.fromOffset(18, 39)
            selector.Subtitle.Size = UDim2.new(1, -36, 0, 28)
            selector.Subtitle.TextSize = 10
            selector.CloseButton.Position = UDim2.new(1, -42, 0, 12)
            selector.Figure.Position = UDim2.fromOffset(18, 74)
            selector.Figure.Size = UDim2.fromOffset(160, 220)
            selector.List.Position = UDim2.fromOffset(190, 74)
            selector.List.Size = UDim2.fromOffset(232, 220)
            selector.List.CanvasSize = UDim2.fromOffset(0, 210)

            for index, name in ipairs(runtime.TargetBodyOrder) do
                local row = selector.Rows[name]
                if row then
                    row.Size = UDim2.new(1, 0, 0, 27)
                    row.Position = UDim2.fromOffset(0, (index - 1) * 30)
                    row.TextSize = 10
                end
            end

            selector.SelectAllButton.Size = UDim2.fromOffset(74, 32)
            selector.SelectAllButton.Position = UDim2.new(0, 18, 1, -42)
            selector.ClearButton.Size = UDim2.fromOffset(78, 32)
            selector.ClearButton.Position = UDim2.new(0, 98, 1, -42)
            selector.DoneButton.Size = UDim2.fromOffset(92, 32)
            selector.DoneButton.Position = UDim2.new(0, 330, 1, -42)

            local targetScale = math.min(1, availableW / 440, availableH / 360)
            selector.Scale.Scale = targetScale
            selector.LayoutMode = "wide"
            selector.TargetScale = targetScale
            return targetScale
        end

        local cardW = math.min(420, availableW)
        local cardH = math.min(620, availableH)
        cardH = math.max(360, cardH)
        selector.Card.Size = UDim2.fromOffset(cardW, cardH)
        local portraitScale = math.min(1, rawAvailableW / cardW, rawAvailableH / cardH)
        portraitScale = math.max(0.55, portraitScale)
        selector.Scale.Scale = portraitScale
        selector.TargetScale = portraitScale
        selector.LayoutMode = "portrait"

        selector.Title.Position = UDim2.fromOffset(14, 12)
        selector.Title.Size = UDim2.new(1, -58, 0, 22)
        selector.Title.TextSize = cardW < 330 and 12 or 14
        selector.Title.TextTruncate = Enum.TextTruncate.AtEnd
        selector.Subtitle.Position = UDim2.fromOffset(14, 35)
        selector.Subtitle.Size = UDim2.new(1, -28, 0, 32)
        selector.Subtitle.TextSize = cardW < 330 and 9 or 10
        selector.CloseButton.Position = UDim2.new(1, -40, 0, 10)

        local figureY = 72
        selector.Figure.Size = UDim2.fromOffset(160, 220)
        selector.Figure.Position = UDim2.fromOffset(math.floor((cardW - 160) / 2), figureY)

        local listY = figureY + 228
        local actionsY = cardH - 42
        local listH = math.max(58, actionsY - listY - 8)
        selector.List.Position = UDim2.fromOffset(14, listY)
        selector.List.Size = UDim2.new(1, -28, 0, listH)

        local rowHeight = cardH < 520 and 25 or 27
        local rowStep = rowHeight + 3
        selector.List.CanvasSize = UDim2.fromOffset(0, #runtime.TargetBodyOrder * rowStep)
        for index, name in ipairs(runtime.TargetBodyOrder) do
            local row = selector.Rows[name]
            if row then
                row.Size = UDim2.new(1, -3, 0, rowHeight)
                row.Position = UDim2.fromOffset(0, (index - 1) * rowStep)
                row.TextSize = 10
            end
        end

        local gap = 7
        local buttonW = math.floor((cardW - 28 - gap * 2) / 3)
        selector.SelectAllButton.Size = UDim2.fromOffset(buttonW, 32)
        selector.SelectAllButton.Position = UDim2.fromOffset(14, actionsY)
        selector.ClearButton.Size = UDim2.fromOffset(buttonW, 32)
        selector.ClearButton.Position = UDim2.fromOffset(14 + buttonW + gap, actionsY)
        selector.DoneButton.Size = UDim2.fromOffset(buttonW, 32)
        selector.DoneButton.Position = UDim2.fromOffset(14 + (buttonW + gap) * 2, actionsY)

        return portraitScale
    end

    runtime.Track(overlay:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
        if overlay.Visible and runtime.BodySelector then
            runtime.ApplyBodySelectorResponsiveLayout()
        end
    end))

    function runtime.BodySelector.Refresh()
        if not runtime.BodySelector then return end
        runtime.RebuildTargetPartNameCache(runtime.BodySelector.Mode)
        local selected = runtime.TargetSelections[runtime.BodySelector.Mode] or {}
        for _, name in ipairs(runtime.TargetBodyOrder) do
            local active = selected[name] == true
            local seg = runtime.BodySelector.Segments[name]
            if seg then
                seg.Button.BackgroundColor3 = active and Color3.fromHex("#E6E9EC") or Color3.fromHex("#24262A")
                seg.Stroke.Color = active and Color3.fromHex("#FFFFFF") or Color3.fromHex("#4B5057")
                seg.Stroke.Transparency = active and 0.05 or 0.35
            end
            local row = runtime.BodySelector.Rows[name]
            if row then
                row.Text = (active and "✓  " or "○  ") .. name
                row.BackgroundColor3 = active and Color3.fromHex("#34373C") or Color3.fromHex("#1C1E21")
                row.TextColor3 = active and Color3.fromHex("#FFFFFF") or Color3.fromHex("#B9BEC5")
            end
        end
    end
end

function runtime.OpenBodySelector(mode)
    mode = "SilentAim"
    runtime.EnsureBodySelector()
    if runtime.BodySelectorGui then
        runtime.BodySelectorGui.DisplayOrder = 2147483647
    end
    runtime.BodySelector.Mode = mode
    runtime.BodySelector.Title.Text = "Selector corporal · Silent Aim"
    runtime.BodySelector.Refresh()
    runtime.BodySelector.Overlay.Visible = true

    local targetScale = runtime.ApplyBodySelectorResponsiveLayout()
    runtime.BodySelector.Scale.Scale = targetScale * 0.965
    runtime.BodySelector.Card.GroupTransparency = 0.12
    TweenService:Create(
        runtime.BodySelector.Scale,
        TweenInfo.new(0.16, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
        {Scale = targetScale}
    ):Play()
    TweenService:Create(
        runtime.BodySelector.Card,
        TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {GroupTransparency = 0}
    ):Play()
end


-- ==========================================
-- INICIO
-- ==========================================

local executorName = identifyexecutor and identifyexecutor() or "Desconocido"
Tabs.Inicio:Paragraph({
    Title = tostring(player.DisplayName),
    Desc = "@" .. tostring(player.Name)
        .. "\nEjecutor: " .. tostring(executorName),
    Image = "rbxthumb://type=AvatarHeadShot&id=" .. tostring(player.UserId) .. "&w=150&h=150",
    ImageSize = 58,
    CircleImage = true,
    ImageAlign = "left",
    ImageStrokeColor = Color3.fromRGB(244, 244, 244),
    ImageStrokeThickness = 1,
    Gothic = true,
    DecorText = "PROFILE",
    Color = Color3.fromRGB(11, 11, 14),
    StrokeColor = Color3.fromRGB(44, 44, 50),
})

local lobbyParagraph = Tabs.Inicio:Paragraph({
    Title = "Estado de la ronda",
    Desc = "Comprobando partida...",
})

-- ==========================================
-- AIMBOT
-- ==========================================

Tabs.Aim:Section({Title = "Silent Aim"})

UIElements.TogSilentAim = Tabs.Aim:Toggle({
    Title = "Silent Aim",
    Desc = "Redirige tus disparos al enemigo.",
    Value = false,
    Callback = function(value)
        state.SilentAim = value

        if not value then
            state.SilentTarget = nil
            state.SilentTargetPlayer = nil
            state.FOVHasCandidate = false

            aimHookState.Target = nil
        end
    end,
})

Tabs.Aim:Button({
    Title = "Selector corporal · Silent Aim",
    Desc = "Elige las partes para Silent Aim y Auto Shoot.",
    Callback = function()
        runtime.OpenBodySelector("SilentAim")
    end,
})

Tabs.Aim:Section({Title = "Auto Shoot"})

UIElements.TogAutoShoot = Tabs.Aim:Toggle({
    Title = "Auto Shoot",
    Desc = "Dispara si una parte seleccionada en Silent Aim está visible. Requiere la gun equipada.",
    Value = false,
    Callback = function(value)
        state.AutoShoot = value
        state.AutoShootAccumulator = 0
        state.AutoShootNextAllowedAt = 0

        if not value then
            table.clear(runtime.AutoShootTargetCooldown)
        end
    end,
})

UIElements.SliAutoShootDelay = Tabs.Aim:Slider({
    Title = "Delay entre disparos",
    Desc = "Pausa global de Auto Shoot en segundos, incluso al cambiar de enemigo.",
    Step = 0.05,
    Value = {
        Min = 0,
        Max = 2,
        Default = state.AutoShootDelay,
    },
    Callback = function(value)
        state.AutoShootDelay =
            math.clamp(tonumber(value) or 0.3, 0, 2)
    end,
})

Tabs.Aim:Section({Title = "Rapid Fire"})

UIElements.TogRapidFire = Tabs.Aim:Toggle({
    Title = "Rapid Fire automático",
    Desc = "Dispara al enemigo válido más cercano. Sólo funciona con la gun equipada.",
    Value = false,
    Callback = function(value)
        runtime.SetFireEnabled("RapidFire", value, false)
    end,
})

UIElements.TogRapidFireButton = Tabs.Aim:Toggle({
    Title = "Botón flotante de Rapid Fire",
    Desc = "Muestra u oculta el botón sin cambiar la función.",
    Value = state.RapidFireButtonVisible,
    Callback = function(value)
        state.RapidFireButtonVisible = value == true
        if runtime.RefreshFireButtons then runtime.RefreshFireButtons() end
    end,
})

UIElements.SliRapidFireRate = Tabs.Aim:Slider({
    Title = "Disparos por segundo",
    Desc = "Cadencia del Rapid Fire.",
    Step = 1,
    Value = {
        Min = 1,
        Max = 30,
        Default = state.RapidFireRate,
    },
    Callback = function(value)
        state.RapidFireRate = math.clamp(tonumber(value) or 16, 1, 30)
        state.RapidFireAccumulator = 0
    end,
})

Tabs.KillAll:Section({Title = "Spam Fire"})

UIElements.TogRoundStartSpam = Tabs.KillAll:Toggle({
    Title = "Spam Fire",
    Desc = "Dispara continuamente hasta que lo apagues. Se pausa en el lobby; no requiere la gun equipada.",
    Value = false,
    Callback = function(value)
        runtime.SetFireEnabled("RoundStartSpam", value, false)
    end,
})

UIElements.TogSpamFireButton = Tabs.KillAll:Toggle({
    Title = "Botón flotante de Spam Fire",
    Desc = "Muestra u oculta el botón sin cambiar la función.",
    Value = state.SpamFireButtonVisible,
    Callback = function(value)
        state.SpamFireButtonVisible = value == true
        if runtime.RefreshFireButtons then runtime.RefreshFireButtons() end
    end,
})

UIElements.SliRoundStartSpamRate = Tabs.KillAll:Slider({
    Title = "Cadencia de Spam Fire",
    Desc = "Disparos por segundo mientras Spam Fire esté activo.",
    Step = 1,
    Value = {
        Min = 5,
        Max = 60,
        Default = state.RoundStartSpamRate,
    },
    Callback = function(value)
        state.RoundStartSpamRate =
            math.clamp(tonumber(value) or 45, 5, 60)
        state.RoundStartSpamAccumulator = 0
    end,
})

-- BOTONES FLOTANTES · SPAM FIRE / RAPID FIRE
-- Alcance propio para conservar los registros locales del hub.
do
    local parent = playerGui
    pcall(function()
        if gethui then parent = gethui() or playerGui end
    end)
    safeDestroy(parent:FindFirstChild("XeroHub_MVSD_FireButtons"))

    local gui = Instance.new("ScreenGui")
    gui.Name = "XeroHub_MVSD_FireButtons"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.DisplayOrder = 2147483600
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.Parent = parent
    runtime.FireButtonsGui = gui

    local controls = {}
    local function createButton(key, title, yOffset)
        local button = Instance.new("TextButton")
        button.Name = key .. "QuickToggle"
        button.Size = UDim2.fromOffset(156, 48)
        button.Position = UDim2.new(0.8, -150, 0.5, yOffset)
        button.BackgroundColor3 = Color3.fromRGB(14, 14, 14)
        button.BackgroundTransparency = 0.06
        button.BorderSizePixel = 0
        button.Text = ""
        button.AutoButtonColor = false
        button.ZIndex = 50
        button.Parent = gui
        Instance.new("UICorner", button).CornerRadius = UDim.new(0, 12)

        local stroke = Instance.new("UIStroke", button)
        stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        stroke.Thickness = 1
        stroke.Transparency = 0.2

        local heading = Instance.new("TextLabel", button)
        heading.Name = "ControlTitle"
        heading.BackgroundTransparency = 1
        heading.Position = UDim2.fromOffset(14, 6)
        heading.Size = UDim2.new(1, -42, 0, 20)
        heading.Font = Enum.Font.GothamMedium
        heading.Text = title
        heading.TextSize = 12
        heading.TextColor3 = Color3.fromRGB(240, 240, 240)
        heading.TextXAlignment = Enum.TextXAlignment.Left
        heading.ZIndex = 51

        local label = Instance.new("TextLabel", button)
        label.Name = "ControlState"
        label.BackgroundTransparency = 1
        label.Position = UDim2.fromOffset(14, 26)
        label.Size = UDim2.new(1, -42, 0, 14)
        label.Font = Enum.Font.GothamMedium
        label.TextSize = 8
        label.TextColor3 = Color3.fromRGB(135, 135, 135)
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.ZIndex = 51

        local dot = Instance.new("Frame", button)
        dot.Name = "StateDot"
        dot.AnchorPoint = Vector2.new(1, 0.5)
        dot.Position = UDim2.new(1, -14, 0.5, 0)
        dot.Size = UDim2.fromOffset(6, 6)
        dot.BorderSizePixel = 0
        dot.ZIndex = 51
        Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)
        controls[key] = {Button = button, Label = label, Dot = dot, Stroke = stroke}

        local gesture = {Moved = false, SuppressUntil = 0}
        runtime.Track(button.InputBegan:Connect(function(input)
            if gesture.Input then return end
            if input.UserInputType ~= Enum.UserInputType.MouseButton1
                and input.UserInputType ~= Enum.UserInputType.Touch then return end
            gesture.Input = input
            gesture.Start = input.Position
            gesture.Position = button.Position
            gesture.Moved = false
            gesture.SuppressUntil = 0
        end))

        runtime.Track(UserInputService.InputChanged:Connect(function(input)
            local active = gesture.Input
            if not active then return end
            local touch = active.UserInputType == Enum.UserInputType.Touch
            if touch and input ~= active then return end
            if not touch and input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
            local delta = input.Position - gesture.Start
            if delta.Magnitude > 5 then gesture.Moved = true end
            if gesture.Moved then
                button.Position = UDim2.new(
                    gesture.Position.X.Scale, gesture.Position.X.Offset + delta.X,
                    gesture.Position.Y.Scale, gesture.Position.Y.Offset + delta.Y
                )
            end
        end))

        runtime.Track(UserInputService.InputEnded:Connect(function(input)
            local active = gesture.Input
            if not active then return end
            local sameMouse = active.UserInputType == Enum.UserInputType.MouseButton1
                and input.UserInputType == Enum.UserInputType.MouseButton1
            if input ~= active and not sameMouse then return end
            if gesture.Moved then gesture.SuppressUntil = os.clock() + 0.2 end
            gesture.Input = nil
            gesture.Moved = false
        end))

        runtime.Track(button.Activated:Connect(function()
            if gesture.Moved or os.clock() < gesture.SuppressUntil then return end
            runtime.SetFireEnabled(key, not state[key], true)
        end))
    end

    function runtime.RefreshFireButtons()
        if not gui.Parent then return end
        for key, control in pairs(controls) do
            local visible
            if key == "RapidFire" then
                visible = state.RapidFireButtonVisible
            else
                visible = state.SpamFireButtonVisible
            end
            control.Button.Visible = visible == true
            local enabled = state[key] == true
            local status = enabled and "ACTIVO" or "INACTIVO"
            if key == "RoundStartSpam" and enabled then
                status = state.InLobby and "EN ESPERA" or "ACTIVO"
            end
            if control.Label.Text ~= status then control.Label.Text = status end
            if control.Enabled ~= enabled then
                control.Enabled = enabled
                control.Dot.BackgroundColor3 = enabled
                    and Color3.fromRGB(242, 242, 242) or Color3.fromRGB(80, 80, 80)
                control.Stroke.Color = enabled
                    and Color3.fromRGB(175, 175, 175) or Color3.fromRGB(60, 60, 60)
            end
        end
    end

    createButton("RoundStartSpam", "Spam Fire", -112)
    createButton("RapidFire", "Rapid Fire", -56)
    runtime.RefreshFireButtons()

    local elapsed = 0
    runtime.Track(RunService.Heartbeat:Connect(function(dt)
        if not runtime.Alive then return end
        elapsed = elapsed + dt
        if elapsed < 0.1 then return end
        elapsed = 0
        runtime.RefreshFireButtons()
    end))

    function runtime.FireButtonsCleanup()
        safeDestroy(gui)
        table.clear(controls)
        runtime.FireButtonsGui = nil
        runtime.RefreshFireButtons = nil
    end
end
-- FIN BOTONES FLOTANTES FIRE

Tabs.Aim:Section({Title = "Campo de visión"})

UIElements.TogFOVFilter = Tabs.Aim:Toggle({
    Title = "Filtro de círculo FOV",
    Desc = "Limita Silent Aim al círculo.",
    Value = state.FOVFilter,
    Callback = function(value)
        state.FOVFilter = value
    end,
})

UIElements.TogShowFOV = Tabs.Aim:Toggle({
    Title = "Mostrar Círculo FOV",
    Desc = "Muestra el círculo del FOV.",
    Value = state.ShowFOV,
    Callback = function(value)
        state.ShowFOV = value
    end,
})

UIElements.SliFOV = Tabs.Aim:Slider({
    Title = "Tamaño del FOV",
    Step = 1,
    Value = {
        Min = 10,
        Max = 800,
        Default = state.FOVRadius,
    },
    Callback = function(value)
        state.FOVRadius = tonumber(value) or 140
    end,
})

-- ==========================================
-- VISUALES
-- ==========================================

Tabs.Vis:Section({Title = "ESP de jugadores"})

UIElements.TogESP = Tabs.Vis:Toggle({
    Title = "ESP Jugadores",
    Desc = "Muestra enemigos durante la partida.",
    Value = false,
    Callback = function(value)
        state.ESP = value
        if not value or state.InLobby then
            clearESP()
        end
    end,
})

UIElements.TogESPGlow = Tabs.Vis:Toggle({
    Title = "Mostrar Resplandor (Glow)",
    Desc = "Resalta a los enemigos.",
    Value = state.ESPGlow,
    Callback = function(value)
        state.ESPGlow = value
        if state.ESP then
            for i = 1, #runtime.PlayerList do ensureESP(runtime.PlayerList[i]) end
        end
    end,
})

UIElements.TogESPName = Tabs.Vis:Toggle({
    Title = "Mostrar Nombre",
    Value = state.ESPName,
    Callback = function(value)
        state.ESPName = value
        if state.ESP then
            for i = 1, #runtime.PlayerList do
                ensureESP(runtime.PlayerList[i])
            end
        end
    end,
})

UIElements.TogESPHealth = Tabs.Vis:Toggle({
    Title = "Mostrar Vida",
    Value = state.ESPHealth,
    Callback = function(value)
        state.ESPHealth = value
        if state.ESP then
            for i = 1, #runtime.PlayerList do
                ensureESP(runtime.PlayerList[i])
            end
        end
    end,
})

UIElements.TogESPDistance = Tabs.Vis:Toggle({
    Title = "Mostrar Distancia",
    Value = state.ESPDistance,
    Callback = function(value)
        state.ESPDistance = value
        if state.ESP then
            for i = 1, #runtime.PlayerList do
                ensureESP(runtime.PlayerList[i])
            end
        end
    end,
})

UIElements.TogESPLines = Tabs.Vis:Toggle({
    Title = "Mostrar Líneas",
    Desc = "Traza una línea desde abajo de la pantalla hasta cada enemigo.",
    Value = state.ESPLines,
    Callback = function(value)
        state.ESPLines = value

        if not value and runtime.HideAllESPGeometry then
            pcall(runtime.HideAllESPGeometry)
        end
    end,
})

UIElements.TogESPSkeleton = Tabs.Vis:Toggle({
    Title = "ESP Esqueleto",
    Desc = "Dibuja el esqueleto R6/R15 del enemigo.",
    Value = state.ESPSkeleton,
    Callback = function(value)
        state.ESPSkeleton = value

        if not value and runtime.HideAllESPGeometry then
            pcall(runtime.HideAllESPGeometry)
        end
    end,
})

UIElements.ColESP = Tabs.Vis:Colorpicker({
    Title = "Color del ESP",
    Default = state.ESPColor,
    Callback = function(color)
        state.ESPColor = color
    end,
})

Tabs.Hitbox:Section({Title = "Hitbox Expander"})

UIElements.TogHitboxExpander = Tabs.Hitbox:Toggle({
    Title = "Hitbox Expander",
    Desc = "Expande únicamente UpperTorso.Part nativa de los enemigos.",
    Value = state.HitboxExpander,
    Callback = function(value)
        state.HitboxExpander = value
        state.HitboxAccumulator = 999

        if not value then
            pcall(runtime.RestoreAllExpandedHitboxes)
        else
            local ok, err = pcall(runtime.RefreshExpandedHitboxes)

            if not ok then
                state.HitboxExpander = false
                pcall(runtime.RestoreAllExpandedHitboxes)
                warn("[XeroHub] Hitbox Expander no disponible:", err)
            end
        end
    end,
})

UIElements.SliHitboxSize = Tabs.Hitbox:Slider({
    Title = "Tamaño del Hitbox",
    Desc = "Tamaño absoluto de la caja nativa.",
    Step = 1,
    Value = {
        Min = 2,
        Max = 50,
        Default = state.HitboxSize,
    },
    Callback = function(value)
        state.HitboxSize =
            math.clamp(tonumber(value) or 8, 2, 50)

        if state.HitboxExpander then
            local ok, err = pcall(runtime.RefreshExpandedHitboxes)

            if not ok then
                state.HitboxExpander = false
                pcall(runtime.RestoreAllExpandedHitboxes)
                warn("[XeroHub] Hitbox resize falló:", err)
            end
        end
    end,
})

UIElements.TogHitboxVisible = Tabs.Hitbox:Toggle({
    Title = "Mostrar caja del Hitbox",
    Desc = "Solo visual; permite ver el tamaño expandido.",
    Value = state.HitboxVisible,
    Callback = function(value)
        state.HitboxVisible = value

        pcall(function()
            for part, box in pairs(runtime.HitboxAdornments) do
                if box and box.Parent == part then
                    box.Visible = value
                end
            end
        end)
    end,
})



-- ==========================================
-- MOVIMIENTO
-- ==========================================

Tabs.Mov:Section({Title = "Modo Fantasma"})

-- Botón flotante compacto, inspirado en el control rápido de DUELS.
local ghostFloatParent = playerGui
pcall(function()
    if gethui then ghostFloatParent = gethui() end
end)

local previousGhostFloat = ghostFloatParent
    and ghostFloatParent:FindFirstChild("XeroHub_MVSD_GhostButton")
if previousGhostFloat then
    previousGhostFloat:Destroy()
end

local ghostFloatGui = Instance.new("ScreenGui")
ghostFloatGui.Name = "XeroHub_MVSD_GhostButton"
ghostFloatGui.ResetOnSpawn = false
ghostFloatGui.IgnoreGuiInset = true
ghostFloatGui.DisplayOrder = 2147483600
ghostFloatGui.Parent = ghostFloatParent
runtime.GhostFloatGui = ghostFloatGui

local ghostFloatButton = Instance.new("TextButton")
ghostFloatButton.Name = "GhostQuickToggle"
ghostFloatButton.Size = UDim2.fromOffset(156, 48)
ghostFloatButton.Position = UDim2.new(0.8, -150, 0.5, 0)
ghostFloatButton.BackgroundColor3 = Color3.fromRGB(14, 14, 14)
ghostFloatButton.BackgroundTransparency = 0.06
ghostFloatButton.BorderSizePixel = 0
ghostFloatButton.Text = ""
ghostFloatButton.AutoButtonColor = false
ghostFloatButton.Visible = true
ghostFloatButton.ZIndex = 50
ghostFloatButton.Parent = ghostFloatGui
Instance.new("UICorner", ghostFloatButton).CornerRadius = UDim.new(0, 12)

local ghostFloatStroke = Instance.new("UIStroke")
ghostFloatStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
ghostFloatStroke.Thickness = 1
ghostFloatStroke.Color = Color3.fromRGB(60, 60, 60)
ghostFloatStroke.Transparency = 0.2
ghostFloatStroke.Parent = ghostFloatButton

local ghostFloatTitle = Instance.new("TextLabel")
ghostFloatTitle.Name = "ControlTitle"
ghostFloatTitle.BackgroundTransparency = 1
ghostFloatTitle.Position = UDim2.fromOffset(14, 6)
ghostFloatTitle.Size = UDim2.new(1, -42, 0, 20)
ghostFloatTitle.Font = Enum.Font.GothamMedium
ghostFloatTitle.Text = "Fantasma"
ghostFloatTitle.TextSize = 12
ghostFloatTitle.TextColor3 = Color3.fromRGB(240, 240, 240)
ghostFloatTitle.TextXAlignment = Enum.TextXAlignment.Left
ghostFloatTitle.ZIndex = 51
ghostFloatTitle.Parent = ghostFloatButton

local ghostFloatState = Instance.new("TextLabel")
ghostFloatState.Name = "ControlState"
ghostFloatState.BackgroundTransparency = 1
ghostFloatState.Position = UDim2.fromOffset(14, 26)
ghostFloatState.Size = UDim2.new(1, -42, 0, 14)
ghostFloatState.Font = Enum.Font.GothamMedium
ghostFloatState.Text = "INACTIVO"
ghostFloatState.TextSize = 8
ghostFloatState.TextColor3 = Color3.fromRGB(135, 135, 135)
ghostFloatState.TextXAlignment = Enum.TextXAlignment.Left
ghostFloatState.ZIndex = 51
ghostFloatState.Parent = ghostFloatButton

local ghostFloatDot = Instance.new("Frame")
ghostFloatDot.Name = "StateDot"
ghostFloatDot.AnchorPoint = Vector2.new(1, 0.5)
ghostFloatDot.Position = UDim2.new(1, -14, 0.5, 0)
ghostFloatDot.Size = UDim2.fromOffset(6, 6)
ghostFloatDot.BorderSizePixel = 0
ghostFloatDot.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
ghostFloatDot.ZIndex = 51
ghostFloatDot.Parent = ghostFloatButton
Instance.new("UICorner", ghostFloatDot).CornerRadius = UDim.new(1, 0)

local ghostFloatHovered = false
local ghostFloatDragging = false
local ghostFloatMoved = false
local ghostFloatDragStart = nil
local ghostFloatStartPosition = nil
local ghostFloatActiveInput = nil

local function updateGhostFloatVisual(enabled)
    enabled = enabled == true
    ghostFloatState.Text = enabled and "ACTIVO" or "INACTIVO"
    ghostFloatDot.BackgroundColor3 = enabled
        and Color3.fromRGB(242, 242, 242)
        or Color3.fromRGB(80, 80, 80)
    ghostFloatStroke.Color = enabled
        and Color3.fromRGB(175, 175, 175)
        or Color3.fromRGB(60, 60, 60)
    ghostFloatButton.BackgroundColor3 = ghostFloatHovered
        and Color3.fromRGB(25, 25, 25)
        or Color3.fromRGB(14, 14, 14)
end

runtime.Track(ghostFloatButton.MouseEnter:Connect(function()
    ghostFloatHovered = true
    updateGhostFloatVisual(runtime.GhostEnabled == true)
end))

runtime.Track(ghostFloatButton.MouseLeave:Connect(function()
    ghostFloatHovered = false
    updateGhostFloatVisual(runtime.GhostEnabled == true)
end))

runtime.Track(ghostFloatButton.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch
    then
        ghostFloatDragging = true
        ghostFloatMoved = false
        ghostFloatDragStart = input.Position
        ghostFloatStartPosition = ghostFloatButton.Position
        ghostFloatActiveInput = input
    end
end))

runtime.Track(UserInputService.InputChanged:Connect(function(input)
    if not ghostFloatDragging
        or not ghostFloatDragStart
        or not ghostFloatStartPosition
        or not ghostFloatActiveInput
    then
        return
    end

    local sameTouch = ghostFloatActiveInput.UserInputType == Enum.UserInputType.Touch
        and input == ghostFloatActiveInput

    local sameMouse = ghostFloatActiveInput.UserInputType == Enum.UserInputType.MouseButton1
        and input.UserInputType == Enum.UserInputType.MouseMovement

    if not sameTouch and not sameMouse then
        return
    end

    local delta = input.Position - ghostFloatDragStart
    if delta.Magnitude > 5 then
        ghostFloatMoved = true
    end

    ghostFloatButton.Position = UDim2.new(
        ghostFloatStartPosition.X.Scale,
        ghostFloatStartPosition.X.Offset + delta.X,
        ghostFloatStartPosition.Y.Scale,
        ghostFloatStartPosition.Y.Offset + delta.Y
    )
end))

runtime.Track(UserInputService.InputEnded:Connect(function(input)
    if not ghostFloatActiveInput then return end

    local sameTouch = ghostFloatActiveInput.UserInputType == Enum.UserInputType.Touch
        and input == ghostFloatActiveInput

    local sameMouse = ghostFloatActiveInput.UserInputType == Enum.UserInputType.MouseButton1
        and input.UserInputType == Enum.UserInputType.MouseButton1

    if sameTouch or sameMouse then
        ghostFloatDragging = false
        ghostFloatActiveInput = nil
    end
end))

local ghostHeartbeat = nil
local ghostHidden = false
local ghostOffset = 5000
local ghostEnabled = false
runtime.GhostEnabled = false
runtime.GhostOriginalTransparency = setmetatable({}, {__mode = "k"})

function runtime.RestoreGhostTransparency(char)
    if not char then return end

    for part, original in pairs(runtime.GhostOriginalTransparency) do
        if part and part.Parent and part:IsDescendantOf(char) then
            pcall(function()
                part.Transparency = original
            end)
        end
        runtime.GhostOriginalTransparency[part] = nil
    end
end

runtime.GhostCleanup = function()
    if ghostHeartbeat then
        pcall(function() ghostHeartbeat:Disconnect() end)
        ghostHeartbeat = nil
    end

    pcall(function()
        RunService:UnbindFromRenderStep("XeroMVSDGhost")
    end)

    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")

    if ghostHidden and hrp then
        pcall(function()
            hrp.CFrame = hrp.CFrame - Vector3.new(0, ghostOffset, 0)
        end)
        ghostHidden = false
    end

    runtime.RestoreGhostTransparency(char)
    ghostEnabled = false
    runtime.GhostEnabled = false
    updateGhostFloatVisual(false)
end

UIElements.TogGhostMode = Tabs.Mov:Toggle({
    Title = "Modo Fantasma",
    Desc = "Te hace invisible para los demás.",
    Value = false,
    Callback = function(value)
        ghostEnabled = value == true
        runtime.GhostEnabled = ghostEnabled
        updateGhostFloatVisual(ghostEnabled)

        local char = player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChildOfClass("Humanoid")

        if ghostEnabled then
            if not char or not hrp or not hum or hum.Health <= 0 then
                ghostEnabled = false
                runtime.GhostEnabled = false
                updateGhostFloatVisual(false)
                task.defer(function()
                    if UIElements.TogGhostMode then
                        pcall(function() UIElements.TogGhostMode:Set(false) end)
                    end
                end)
                return
            end

            if ghostHeartbeat then
                pcall(function() ghostHeartbeat:Disconnect() end)
                ghostHeartbeat = nil
            end

            ghostHeartbeat = runtime.Track(RunService.Heartbeat:Connect(function()
                if not ghostEnabled then return end

                if not char.Parent or hum.Health <= 0 or not hrp.Parent then
                    return
                end

                if not ghostHidden then
                    hrp.AssemblyAngularVelocity = Vector3.zero
                    hrp.CFrame = hrp.CFrame + Vector3.new(0, ghostOffset, 0)
                    ghostHidden = true
                end
            end))

            pcall(function()
                RunService:UnbindFromRenderStep("XeroMVSDGhost")
            end)

            RunService:BindToRenderStep("XeroMVSDGhost", 150, function()
                if not ghostEnabled then return end

                if ghostHidden and hrp and hrp.Parent and hum and hum.Health > 0 then
                    hrp.CFrame = hrp.CFrame - Vector3.new(0, ghostOffset, 0)
                    ghostHidden = false
                end
            end)

            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart")
                    and part.Name ~= "HumanoidRootPart"
                    and not part:FindFirstAncestorWhichIsA("Tool")
                then
                    if runtime.GhostOriginalTransparency[part] == nil then
                        runtime.GhostOriginalTransparency[part] = part.Transparency
                    end
                    part.Transparency = math.max(part.Transparency, 0.5)
                end
            end
        else
            if ghostHeartbeat then
                pcall(function() ghostHeartbeat:Disconnect() end)
                ghostHeartbeat = nil
            end

            pcall(function()
                RunService:UnbindFromRenderStep("XeroMVSDGhost")
            end)

            if ghostHidden and hrp and hrp.Parent then
                pcall(function()
                    hrp.CFrame = hrp.CFrame - Vector3.new(0, ghostOffset, 0)
                end)
                ghostHidden = false
            end

            runtime.RestoreGhostTransparency(char)
        end
    end,
})


runtime.Track(ghostFloatButton.MouseButton1Click:Connect(function()
    if ghostFloatMoved then
        ghostFloatMoved = false
        return
    end

    if UIElements.TogGhostMode then
        local oldSuppress = runtime.SuppressNotifications
        runtime.SuppressNotifications = true
        pcall(function()
            UIElements.TogGhostMode:Set(not ghostEnabled)
        end)
        runtime.SuppressNotifications = oldSuppress
    end
end))

UIElements.ToggleGhostButton = Tabs.Mov:Toggle({
    Title = "Botón flotante",
    Desc = "Muestra el acceso rápido al Fantasma.",
    Value = true,
    Callback = function(value)
        ghostFloatButton.Visible = value == true
    end,
})

Tabs.Mov:Section({Title = "Noclip"})

local noclipEnabled = false
local noclipConnection = nil
local noclipDescendantAddedConnection = nil
local noclipCharacter = nil
local noclipParts = {}
local noclipPartSet = setmetatable({}, {__mode = "k"})
local noclipOriginalCollisions = setmetatable({}, {__mode = "k"})

local function cacheNoclipPart(object)
    if not object or not object:IsA("BasePart") or noclipPartSet[object] then
        return
    end

    noclipPartSet[object] = true
    noclipParts[#noclipParts + 1] = object

    if noclipOriginalCollisions[object] == nil then
        noclipOriginalCollisions[object] = object.CanCollide
    end

    if noclipEnabled and object.CanCollide then
        object.CanCollide = false
    end
end

local function bindNoclipCharacter(char)
    if noclipDescendantAddedConnection then
        pcall(function()
            noclipDescendantAddedConnection:Disconnect()
        end)
        noclipDescendantAddedConnection = nil
    end

    noclipCharacter = char
    table.clear(noclipParts)
    table.clear(noclipPartSet)

    if not char then
        return
    end

    for _, object in ipairs(char:GetDescendants()) do
        cacheNoclipPart(object)
    end

    noclipDescendantAddedConnection = runtime.Track(
        char.DescendantAdded:Connect(function(object)
            cacheNoclipPart(object)
        end)
    )
end

local function applyNoclipCached()
    if not noclipEnabled then
        return
    end

    local char = player.Character
    if char ~= noclipCharacter then
        bindNoclipCharacter(char)
    end

    local writeIndex = 1

    for readIndex = 1, #noclipParts do
        local part = noclipParts[readIndex]

        if part and part.Parent and char and part:IsDescendantOf(char) then
            noclipParts[writeIndex] = part
            writeIndex = writeIndex + 1

            if part.CanCollide then
                part.CanCollide = false
            end
        elseif part then
            noclipPartSet[part] = nil
        end
    end

    for index = #noclipParts, writeIndex, -1 do
        noclipParts[index] = nil
    end
end

local function restoreNoclip()
    for part, original in pairs(noclipOriginalCollisions) do
        if part and part.Parent then
            pcall(function()
                part.CanCollide = original
            end)
        end

        noclipOriginalCollisions[part] = nil
    end

    table.clear(noclipParts)
    table.clear(noclipPartSet)
    noclipCharacter = nil
end

local function startNoclip()
    if noclipConnection then
        pcall(function()
            noclipConnection:Disconnect()
        end)
        noclipConnection = nil
    end

    bindNoclipCharacter(player.Character)
    applyNoclipCached()

    noclipConnection = runtime.Track(RunService.Stepped:Connect(function()
        if noclipEnabled then
            applyNoclipCached()
        end
    end))
end

local function stopNoclip()
    if noclipConnection then
        pcall(function()
            noclipConnection:Disconnect()
        end)
        noclipConnection = nil
    end

    if noclipDescendantAddedConnection then
        pcall(function()
            noclipDescendantAddedConnection:Disconnect()
        end)
        noclipDescendantAddedConnection = nil
    end

    restoreNoclip()
end

UIElements.TogNoclip = Tabs.Mov:Toggle({
    Title = "Noclip",
    Desc = "Atraviesa paredes y objetos.",
    Value = false,
    Callback = function(value)
        noclipEnabled = value == true

        if noclipEnabled then
            startNoclip()
        else
            stopNoclip()
        end
    end,
})

Tabs.Mov:Section({Title = "Velocidad"})

local moveSpeedEnabled = false
local moveSpeedValue = 32
local moveSpeedHeartbeat = nil
local moveSpeedHumanoid = nil
local originalWalkSpeeds = setmetatable({}, {__mode = "k"})

local function bindMoveSpeedHumanoid()
    local char = player.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid") or nil

    if hum ~= moveSpeedHumanoid then
        moveSpeedHumanoid = hum

        if hum and originalWalkSpeeds[hum] == nil then
            originalWalkSpeeds[hum] = hum.WalkSpeed
        end
    end

    return hum
end

local function applyMoveSpeed()
    local hum = moveSpeedHumanoid

    if not hum or not hum.Parent then
        hum = bindMoveSpeedHumanoid()
    end

    if not hum then
        return
    end

    if originalWalkSpeeds[hum] == nil then
        originalWalkSpeeds[hum] = hum.WalkSpeed
    end

    if hum.WalkSpeed ~= moveSpeedValue then
        hum.WalkSpeed = moveSpeedValue
    end
end

local function stopMoveSpeed()
    if moveSpeedHeartbeat then
        pcall(function()
            moveSpeedHeartbeat:Disconnect()
        end)
        moveSpeedHeartbeat = nil
    end

    local hum = moveSpeedHumanoid

    if hum and originalWalkSpeeds[hum] ~= nil then
        pcall(function()
            hum.WalkSpeed = originalWalkSpeeds[hum]
        end)
        originalWalkSpeeds[hum] = nil
    end

    moveSpeedHumanoid = nil
end

UIElements.TogMoveSpeed = Tabs.Mov:Toggle({
    Title = "Velocidad",
    Desc = "Aumenta tu velocidad al caminar.",
    Value = false,
    Callback = function(value)
        moveSpeedEnabled = value == true

        if moveSpeedEnabled then
            bindMoveSpeedHumanoid()
            applyMoveSpeed()

            if moveSpeedHeartbeat then
                pcall(function() moveSpeedHeartbeat:Disconnect() end)
            end

            moveSpeedHeartbeat = runtime.Track(RunService.Heartbeat:Connect(function()
                if moveSpeedEnabled then
                    applyMoveSpeed()
                end
            end))
        else
            stopMoveSpeed()
        end
    end,
})

UIElements.SliMoveSpeed = Tabs.Mov:Slider({
    Title = "Velocidad de movimiento",
    Desc = "Ajusta la velocidad.",
    Step = 1,
    Value = {Min = 16, Max = 100, Default = moveSpeedValue},
    Callback = function(value)
        moveSpeedValue = tonumber(value) or 32
        if moveSpeedEnabled then
            applyMoveSpeed()
        end
    end,
})

Tabs.Mov:Section({Title = "Fly"})

local flyEnabled = false
local flySpeedValue = 50
local flyConnection = nil
local flyVelocity = nil
local flyGyro = nil
local flyHumanoid = nil
local flyRoot = nil
local flyOriginalAutoRotate = true
local flyControls = nil

pcall(function()
    local playerScripts = player:FindFirstChild("PlayerScripts")
        or player:WaitForChild("PlayerScripts", 3)

    local playerModuleObject = playerScripts
        and playerScripts:FindFirstChild("PlayerModule")

    if playerModuleObject then
        local playerModule = require(playerModuleObject)
        if playerModule and playerModule.GetControls then
            flyControls = playerModule:GetControls()
        end
    end
end)

local function destroyFlyPhysics()
    if flyConnection then
        pcall(function() flyConnection:Disconnect() end)
        flyConnection = nil
    end

    if flyVelocity then
        safeDestroy(flyVelocity)
        flyVelocity = nil
    end

    if flyGyro then
        safeDestroy(flyGyro)
        flyGyro = nil
    end

    if flyRoot and flyRoot.Parent then
        pcall(function()
            flyRoot.AssemblyLinearVelocity = Vector3.zero
            flyRoot.AssemblyAngularVelocity = Vector3.zero
        end)
    end

    if flyHumanoid and flyHumanoid.Parent then
        pcall(function()
            flyHumanoid.PlatformStand = false
            flyHumanoid.AutoRotate = flyOriginalAutoRotate
            flyHumanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
        end)
    end

    flyHumanoid = nil
    flyRoot = nil
end

local function startFly()
    destroyFlyPhysics()

    local char = player.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not char or not hum or hum.Health <= 0 or not hrp then
        return false
    end

    flyHumanoid = hum
    flyRoot = hrp
    flyOriginalAutoRotate = hum.AutoRotate

    hum.AutoRotate = false
    hum.PlatformStand = true

    flyVelocity = Instance.new("BodyVelocity")
    flyVelocity.Name = "XeroMVSD_FlyVelocity"
    flyVelocity.MaxForce = Vector3.new(1e9, 1e9, 1e9)
    flyVelocity.P = 12500
    flyVelocity.Velocity = Vector3.zero
    flyVelocity.Parent = hrp

    flyGyro = Instance.new("BodyGyro")
    flyGyro.Name = "XeroMVSD_FlyGyro"
    flyGyro.MaxTorque = Vector3.new(1e9, 1e9, 1e9)
    flyGyro.P = 9000
    flyGyro.D = 250
    flyGyro.CFrame = hrp.CFrame
    flyGyro.Parent = hrp

    flyConnection = runtime.Track(RunService.RenderStepped:Connect(function()
        if not flyEnabled
            or not flyRoot
            or not flyRoot.Parent
            or not flyHumanoid
            or flyHumanoid.Health <= 0
        then
            return
        end

        local camera = workspace.CurrentCamera
        if not camera then return end

        local move = Vector3.zero
        local cf = camera.CFrame
        local rawMove = nil

        -- Funciona con joystick táctil, gamepad y teclado.
        if flyControls and flyControls.GetMoveVector then
            local ok, value = pcall(function()
                return flyControls:GetMoveVector()
            end)

            if ok and typeof(value) == "Vector3" then
                rawMove = value
            end
        end

        if rawMove and rawMove.Magnitude > 0.01 then
            move = (cf.RightVector * rawMove.X)
                + (cf.LookVector * -rawMove.Z)
        else
            -- Fallback móvil/universal.
            local humanoidMove = flyHumanoid.MoveDirection

            if humanoidMove.Magnitude > 0.01 then
                local flatLook = Vector3.new(
                    cf.LookVector.X,
                    0,
                    cf.LookVector.Z
                )
                local flatRight = Vector3.new(
                    cf.RightVector.X,
                    0,
                    cf.RightVector.Z
                )

                if flatLook.Magnitude > 0.001 then
                    flatLook = flatLook.Unit
                end
                if flatRight.Magnitude > 0.001 then
                    flatRight = flatRight.Unit
                end

                local forward = humanoidMove:Dot(flatLook)
                local side = humanoidMove:Dot(flatRight)

                move = (cf.LookVector * forward)
                    + (cf.RightVector * side)
            end
        end

        -- Extra para PC.
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
            move = move + Vector3.new(0, 1, 0)
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
            move = move - Vector3.new(0, 1, 0)
        end

        if move.Magnitude > 0.001 then
            move = move.Unit * flySpeedValue
        else
            move = Vector3.zero
        end

        flyVelocity.Velocity = move

        local look = cf.LookVector
        if look.Magnitude > 0.001 then
            flyGyro.CFrame = CFrame.lookAt(
                flyRoot.Position,
                flyRoot.Position + look
            )
        end
    end))

    return true
end

UIElements.TogFly = Tabs.Mov:Toggle({
    Title = "Fly",
    Desc = "Joystick en móvil o WASD en PC.",
    Value = false,
    Callback = function(value)
        flyEnabled = value == true

        if flyEnabled then
            if not startFly() then
                flyEnabled = false
                task.defer(function()
                    if UIElements.TogFly then
                        pcall(function() UIElements.TogFly:Set(false) end)
                    end
                end)
            end
        else
            destroyFlyPhysics()
        end
    end,
})

UIElements.SliFlySpeed = Tabs.Mov:Slider({
    Title = "Velocidad de Fly",
    Desc = "Ajusta la velocidad de vuelo.",
    Step = 5,
    Value = {Min = 20, Max = 200, Default = flySpeedValue},
    Callback = function(value)
        flySpeedValue = tonumber(value) or 50
    end,
})

runtime.MovementCleanup = function()
    noclipEnabled = false
    stopNoclip()

    moveSpeedEnabled = false
    stopMoveSpeed()

    flyEnabled = false
    destroyFlyPhysics()

    if runtime.GhostFloatGui then
        safeDestroy(runtime.GhostFloatGui)
        runtime.GhostFloatGui = nil
    end
end

-- Evita quedar desplazado/invisible después de respawn.
runtime.Track(player.CharacterAdded:Connect(function()
    if ghostEnabled then
        ghostHidden = false
        task.defer(function()
            if UIElements.TogGhostMode then
                pcall(function() UIElements.TogGhostMode:Set(false) end)
            else
                runtime.GhostCleanup()
            end
        end)
    end

    if noclipEnabled then
        task.defer(function()
            task.wait(0.10)
            if noclipEnabled then
                bindNoclipCharacter(player.Character)
                applyNoclipCached()
            end
        end)
    end

    if moveSpeedEnabled then
        task.defer(function()
            task.wait(0.15)
            if moveSpeedEnabled then
                bindMoveSpeedHumanoid()
                applyMoveSpeed()
            end
        end)
    end

    if flyEnabled then
        -- MVSD recrea el Character entre rondas.
        -- Limpiamos la física del avatar viejo pero mantenemos Fly activado
        -- y lo volvemos a montar automáticamente en el nuevo Character.
        destroyFlyPhysics()

        local respawnedCharacter = player.Character
        task.spawn(function()
            local deadline = os.clock() + 4

            while runtime.Alive
                and flyEnabled
                and os.clock() < deadline
            do
                if player.Character == respawnedCharacter
                    and respawnedCharacter
                    and respawnedCharacter.Parent
                then
                    local hum = respawnedCharacter:FindFirstChildOfClass("Humanoid")
                    local hrp = respawnedCharacter:FindFirstChild("HumanoidRootPart")

                    if hum and hum.Health > 0 and hrp then
                        if startFly() then
                            return
                        end
                    end
                end

                task.wait(0.05)
            end
        end)
    end
end))

-- ==========================================
-- GRÁFICOS · SKYBOX
-- Sólo sustituye objetos Sky. No toca Lighting,
-- Atmosphere, Clouds ni postprocesado del juego.
-- ==========================================

Tabs.Graficos:Section({Title = "Skyboxes"})

local skyState = {
    Active = nil,
    OwnedSky = nil,
    Parked = {},
    ParkedSet = setmetatable({}, {__mode = "k"}),
    ChildAddedConnection = nil,
    RemoteNames = {},
    Presets = {},
    RemoteCache = {},
    CustomId = "92427017914292",
    Dropdown = nil,
    Syncing = false,
}
runtime.SkyState = skyState

local SKY_FACE_KEYS = {"bk", "dn", "ft", "lf", "rt", "up"}
local SKY_PROPERTIES = {
    "SkyboxBk",
    "SkyboxDn",
    "SkyboxFt",
    "SkyboxLf",
    "SkyboxRt",
    "SkyboxUp",
}

local skyEnv = (getgenv and getgenv()) or _G
local SKYBOX_REPO_BASE = tostring(
    skyEnv.XERO_SKYBOX_BASE_URL
    or "https://raw.githubusercontent.com/OnyxDevv/Onyx-web/refs/heads/main/skyboxes"
):gsub("/+$", "")

local skyCustomAsset = getcustomasset
    or getsynasset
    or (syn and (syn.getcustomasset or syn.getsynasset))

local function skyHttpGet(url)
    local req = (syn and syn.request)
        or (http and http.request)
        or http_request
        or request

    if req then
        local ok, response = pcall(function()
            return req({
                Url = url,
                Method = "GET",
                Headers = {
                    ["User-Agent"] = "XeroHub-MVSD-Skybox/1.0",
                },
            })
        end)

        if ok and type(response) == "table" then
            local status = tonumber(response.StatusCode or response.Status or 200) or 200
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

local function ensureSkyFolder(path)
    if type(makefolder) ~= "function" then
        return
    end

    local current = ""

    for part in string.gmatch(path, "[^/]+") do
        current = current == "" and part or (current .. "/" .. part)

        local exists = false
        if type(isfolder) == "function" then
            pcall(function()
                exists = isfolder(current) == true
            end)
        end

        if not exists then
            pcall(makefolder, current)
        end
    end
end

local function safeSkyRepoToken(value)
    value = tostring(value or "")

    if value:match("^[%w%._%-]+$") then
        return value
    end

    return nil
end

local function parkSky(object)
    if not object
        or not object:IsA("Sky")
        or object == skyState.OwnedSky
        or skyState.ParkedSet[object]
    then
        return
    end

    skyState.ParkedSet[object] = true
    skyState.Parked[#skyState.Parked + 1] = {
        Object = object,
        Parent = object.Parent,
    }

    object.Parent = nil
end

local function restoreParkedSkies()
    for i = 1, #skyState.Parked do
        local entry = skyState.Parked[i]
        local object = entry and entry.Object

        if object then
            pcall(function()
                if object.Parent == nil then
                    object.Parent = entry.Parent or Lighting
                end
            end)
        end

        if object then
            skyState.ParkedSet[object] = nil
        end
    end

    table.clear(skyState.Parked)
end

local function disconnectSkyWatcher()
    if skyState.ChildAddedConnection then
        pcall(function()
            skyState.ChildAddedConnection:Disconnect()
        end)
        skyState.ChildAddedConnection = nil
    end
end

local function removeOwnedSky()
    local sky = skyState.OwnedSky
    skyState.OwnedSky = nil

    if sky then
        safeDestroy(sky)
    end
end

local function restoreOriginalSky()
    disconnectSkyWatcher()
    removeOwnedSky()
    restoreParkedSkies()
    skyState.Active = nil
end

local function watchGameSkies()
    disconnectSkyWatcher()

    skyState.ChildAddedConnection = runtime.Track(
        Lighting.ChildAdded:Connect(function(object)
            if not skyState.Active or object == skyState.OwnedSky then
                return
            end

            if object:IsA("Sky") then
                task.defer(function()
                    if skyState.Active
                        and object.Parent == Lighting
                        and object ~= skyState.OwnedSky
                    then
                        parkSky(object)
                    end
                end)
            end
        end)
    )
end

local function loadSkyManifest()
    skyState.RemoteNames = {}
    skyState.Presets = {}

    if not skyCustomAsset or type(writefile) ~= "function" then
        return false
    end

    local raw = skyHttpGet(SKYBOX_REPO_BASE .. "/manifest.json")
    if not raw then
        return false
    end

    local ok, decoded = pcall(function()
        return HttpService:JSONDecode(raw)
    end)

    if not ok or type(decoded) ~= "table" then
        return false
    end

    local list = decoded.skyboxes or decoded
    if type(list) ~= "table" then
        return false
    end

    local names = {}

    for _, pack in ipairs(list) do
        if type(pack) == "table" then
            local name = tostring(pack.name or "")
            local folder = safeSkyRepoToken(pack.folder)

            if name ~= "" and folder then
                local files = {}
                local valid = true

                for _, face in ipairs(SKY_FACE_KEYS) do
                    local fileName = pack.files
                        and safeSkyRepoToken(pack.files[face])
                        or (face .. ".png")

                    if not fileName then
                        valid = false
                        break
                    end

                    files[face] = fileName
                end

                if valid then
                    local displayName = "Skybox · " .. name

                    skyState.Presets[displayName] = {
                        Folder = folder,
                        RepoName = name,
                        Files = files,
                    }

                    names[#names + 1] = displayName
                end
            end
        end
    end

    table.sort(names)
    skyState.RemoteNames = names

    return #names > 0
end

local function loadRemoteSkyFaces(preset)
    if not skyCustomAsset or type(writefile) ~= "function" then
        error("Tu ejecutor necesita getcustomasset/getsynasset + writefile.")
    end

    local cacheKey = tostring(preset.Folder)

    if skyState.RemoteCache[cacheKey] then
        return skyState.RemoteCache[cacheKey]
    end

    local root = "XeroHub/skybox_cache_mvsd"
    ensureSkyFolder(root)

    local result = {}

    for index, face in ipairs(SKY_FACE_KEYS) do
        local remoteName = preset.Files[face]
        local extension = remoteName:match("(%.[%w]+)$") or ".png"
        local safeFolder = tostring(preset.Folder):gsub("[^%w%._%-]", "_")
        local uniqueName = "xero_mvds_" .. safeFolder .. "_" .. face .. extension
        local localPath = root .. "/" .. uniqueName

        local exists = false

        if type(isfile) == "function" then
            pcall(function()
                exists = isfile(localPath) == true
            end)
        end

        if not exists then
            local body = skyHttpGet(
                SKYBOX_REPO_BASE
                .. "/"
                .. preset.Folder
                .. "/"
                .. remoteName
            )

            if not body or #body < 64 then
                error(
                    "No se pudo descargar la cara "
                    .. face
                    .. " de "
                    .. tostring(preset.RepoName)
                )
            end

            local wrote, err = pcall(writefile, localPath, body)

            if not wrote then
                error("No se pudo guardar " .. localPath .. ": " .. tostring(err))
            end
        end

        local ok, asset = pcall(skyCustomAsset, localPath)

        if not ok or type(asset) ~= "string" or asset == "" then
            error("getcustomasset falló con " .. localPath)
        end

        result[index] = asset
    end

    skyState.RemoteCache[cacheKey] = result
    return result
end

local function applySkyFaces(name, faces, localAssets)
    restoreOriginalSky()

    local sky = Instance.new("Sky")
    sky.Name = "XeroHub_MVSD_Sky"
    sky.CelestialBodiesShown = false
    sky.StarCount = 0

    for index, property in ipairs(SKY_PROPERTIES) do
        local value = faces[index]

        if localAssets then
            sky[property] = value
        else
            sky[property] = "rbxassetid://" .. tostring(value)
        end
    end

    -- Guarda/aparta exclusivamente los Sky que ya tenía el juego.
    for _, object in ipairs(Lighting:GetChildren()) do
        if object:IsA("Sky") then
            parkSky(object)
        end
    end

    skyState.OwnedSky = sky
    skyState.Active = name
    sky.Parent = Lighting

    watchGameSkies()

    local selectedSky = sky
    task.spawn(function()
        pcall(function()
            ContentProvider:PreloadAsync({selectedSky})
        end)
    end)
end

local function applySkySelection(value)
    local selected = type(value) == "table" and value[1] or value
    selected = tostring(selected or "Ninguno")

    if selected == "Ninguno" then
        restoreOriginalSky()
        return
    end

    if selected == "Cielo personalizado" then
        local faces = {}

        for i = 1, 6 do
            faces[i] = skyState.CustomId
        end

        applySkyFaces(selected, faces, false)
        return
    end

    local preset = skyState.Presets[selected]
    if not preset then
        return
    end

    local ok, result = pcall(function()
        return loadRemoteSkyFaces(preset)
    end)

    if not ok then
        restoreOriginalSky()
        runtime.Notify(
            "No se pudo cargar " .. selected .. ".",
            {Title = "XeroHub · Skybox"}
        )
        warn("[XeroHub] Skybox: " .. tostring(result))
        return
    end

    applySkyFaces(selected, result, true)
end

pcall(loadSkyManifest)

local skyDropdownValues = {"Ninguno"}

for _, name in ipairs(skyState.RemoteNames) do
    skyDropdownValues[#skyDropdownValues + 1] = name
end

skyDropdownValues[#skyDropdownValues + 1] = "Cielo personalizado"

skyState.Dropdown = Tabs.Graficos:Dropdown({
    Title = "Skybox",
    Desc = "Elige un cielo.",
    Values = skyDropdownValues,
    Value = "Ninguno",
    Callback = function(value)
        if skyState.Syncing then
            return
        end

        applySkySelection(value)
    end,
})

Tabs.Graficos:Input({
    Title = "ID de cielo",
    Desc = "Usa la misma imagen en las 6 caras.",
    Placeholder = "92427017914292",
    Value = "92427017914292",
    Callback = function(value)
        skyState.CustomId = tostring(value or "")
    end,
})

Tabs.Graficos:Button({
    Title = "Aplicar cielo personalizado",
    Desc = "Aplica el ID escrito arriba.",
    Callback = function()
        local raw = tostring(skyState.CustomId or ""):match("^%s*(.-)%s*$") or ""
        local id = raw:match("^(%d+)$")
            or raw:match("^rbxassetid://(%d+)$")

        if not id or not id:find("[1-9]") then
            runtime.Notify(
                "Escribe un ID válido.",
                {Title = "XeroHub · Skybox"}
            )
            return
        end

        skyState.CustomId = id

        local faces = {}
        for i = 1, 6 do
            faces[i] = id
        end

        applySkyFaces("Cielo personalizado", faces, false)

        if skyState.Dropdown then
            skyState.Syncing = true
            pcall(function()
                skyState.Dropdown:Select("Cielo personalizado")
            end)
            skyState.Syncing = false
        end
    end,
})

Tabs.Graficos:Button({
    Title = "Restaurar cielo",
    Desc = "Vuelve al cielo original del juego.",
    Callback = function()
        restoreOriginalSky()

        if skyState.Dropdown then
            skyState.Syncing = true
            pcall(function()
                skyState.Dropdown:Select("Ninguno")
            end)
            skyState.Syncing = false
        end
    end,
})

runtime.SkyCleanup = function()
    restoreOriginalSky()
end

-- ==========================================
-- SONIDOS · MVSD
-- Disparo confirmado: LocalCharacter.Default.Fire · 12717436463
-- Muerte: Humanoid.Died dentro del mismo Match.
-- KillFx/round result se silencian mientras el death sound está activo
-- para evitar dobles reproducciones.
-- ==========================================

do
    local soundEnv = (getgenv and getgenv()) or _G
    local assetLoader = getcustomasset
        or getsynasset
        or (syn and (syn.getcustomasset or syn.getsynasset))
    local Debris = game:GetService("Debris")

    local CATALOG_URL =
        "https://api.github.com/repos/OnyxDevv/Onyx-web/contents/sounds?ref=main"
    local CACHE_FOLDER = "XeroHub/Sounds_MVSD"
    local CATALOG_CACHE = CACHE_FOLDER .. "/catalog.json"

    local LOCAL_FIRE_ID = "12717436463"
    local KILL_FX_ID = "13192012298"
    local ROUND_RESULT_ID = "13146903391"

    local soundState = {
        Catalog = {},
        ByLabel = {},
        SelectedShot = nil,
        SelectedDeath = nil,

        ShotEnabled = false,
        ShotDesired = false,
        MuteShot = false,
        DeathEnabled = false,
        DeathDesired = false,

        ShotAsset = nil,
        DeathAsset = nil,
        ShotReadySound = nil,
        DeathReadySound = nil,
        ShotActiveKey = nil,
        DeathActiveKey = nil,
        ShotLoadToken = 0,
        DeathLoadToken = 0,

        ShotVolume = 1,
        DeathVolume = 1,

        ShotBindings = setmetatable({}, {__mode = "k"}),
        ShotOriginalVolumes = setmetatable({}, {__mode = "k"}),
        NativeDeathBindings = setmetatable({}, {__mode = "k"}),
        NativeDeathOriginalVolumes = setmetatable({}, {__mode = "k"}),
        HumanoidBindings = setmetatable({}, {__mode = "k"}),
        PlayerCharacterBindings = setmetatable({}, {__mode = "k"}),
        ActiveOneShots = setmetatable({}, {__mode = "k"}),

        ShotDropdown = nil,
        DeathDropdown = nil,
        ShotToggle = nil,
        MuteToggle = nil,
        DeathToggle = nil,
        ShotSlider = nil,
        DeathSlider = nil,

        PendingConfig = nil,
        CatalogLoading = false,
        CatalogLoaded = false,
        LastMatchId = nil,

        MutatingShotVolume = setmetatable({}, {__mode = "k"}),
        MutatingDeathVolume = setmetatable({}, {__mode = "k"}),
    }

    runtime.SoundState = soundState

    local function trim(value)
        return tostring(value or ""):match("^%s*(.-)%s*$") or ""
    end

    local function extensionOf(fileName)
        local extension = string.lower(
            tostring(fileName or ""):match("%.([%w]+)$") or ""
        )

        if extension == "mp3" or extension == "ogg" then
            return extension
        end

        return nil
    end

    local function prettyName(fileName)
        local extension = extensionOf(fileName)
        local name = tostring(fileName or "")

        if extension then
            name = name:sub(1, #name - #extension - 1)
        end

        name = name:gsub("%s*%(%d+%)%s*$", "")
        name = name:gsub("[_%-]+", " "):gsub("%s+", " ")
        name = trim(name)

        name = name:gsub("%S+", function(word)
            return word:sub(1, 1):upper() .. word:sub(2):lower()
        end)

        return name ~= "" and name or "Sonido sin nombre"
    end

    local function entryKey(entry)
        entry = type(entry) == "table" and entry or {}
        return tostring(entry.name or "") .. "@" .. tostring(entry.sha or "")
    end

    local function parseCatalog(items)
        local result = {}

        for _, item in ipairs(type(items) == "table" and items or {}) do
            local extension = type(item) == "table"
                and extensionOf(item.name)
                or nil

            if extension
                and item.type == "file"
                and type(item.download_url) == "string"
                and item.download_url ~= ""
            then
                result[#result + 1] = {
                    name = tostring(item.name),
                    label = prettyName(item.name),
                    extension = extension,
                    sha = tostring(item.sha or ""),
                    url = item.download_url,
                }
            end
        end

        table.sort(result, function(a, b)
            local left = a.label:lower()
            local right = b.label:lower()

            if left == right then
                return a.name:lower() < b.name:lower()
            end

            return left < right
        end)

        local totals = {}
        local seen = {}

        for _, entry in ipairs(result) do
            local key = entry.label:lower()
            totals[key] = (totals[key] or 0) + 1
        end

        for _, entry in ipairs(result) do
            local key = entry.label:lower()

            if totals[key] > 1 then
                seen[key] = (seen[key] or 0) + 1
                entry.label = entry.label .. " [" .. tostring(seen[key]) .. "]"
            end
        end

        return result
    end

    local function ensureFolder()
        if type(makefolder) ~= "function" then
            return false
        end

        local xeroExists = false
        if type(isfolder) == "function" then
            pcall(function()
                xeroExists = isfolder("XeroHub") == true
            end)
        end

        if not xeroExists then
            pcall(makefolder, "XeroHub")
        end

        local cacheExists = false
        if type(isfolder) == "function" then
            pcall(function()
                cacheExists = isfolder(CACHE_FOLDER) == true
            end)
        end

        if not cacheExists then
            pcall(makefolder, CACHE_FOLDER)
        end

        return true
    end

    local function soundHttpGet(url)
        local req = (syn and syn.request)
            or (http and http.request)
            or http_request
            or soundEnv.request

        if req then
            local ok, response = pcall(function()
                return req({
                    Url = url,
                    Method = "GET",
                    Headers = {
                        ["User-Agent"] = "XeroHub-MVSD-Sounds/1.0",
                        ["Accept"] = "application/vnd.github+json",
                    },
                })
            end)

            if ok and type(response) == "table" then
                local status = tonumber(
                    response.StatusCode or response.Status or 0
                ) or 0
                local body = response.Body or response.body

                if status == 0 and response.Success == true then
                    status = 200
                end

                if type(body) == "string"
                    and status >= 200
                    and status < 300
                then
                    return body, status
                end
            end
        end

        local ok, body = pcall(function()
            return game:HttpGet(url)
        end)

        if ok and type(body) == "string" then
            return body, 200
        end

        return nil, 0
    end

    local function assetIdDigits(value)
        local text = tostring(value or "")

        return text:match("^rbxassetid://(%d+)$")
            or text:match("^(%d+)$")
            or text:match("[?&]id=(%d+)")
    end

    local function cachePath(entry)
        local extension = entry.extension or extensionOf(entry.name) or "mp3"
        local token = tostring(entry.sha or ""):gsub("[^%w]", ""):sub(1, 12)

        if token == "" then
            token = tostring(entry.name or "sound")
                :gsub("[^%w]", "_")
                :sub(1, 40)
        end

        return CACHE_FOLDER .. "/" .. token .. "." .. extension
    end

    local function isValidAudioPayload(statusCode, body, extension)
        local status = tonumber(statusCode)

        if not status
            or status < 200
            or status >= 300
            or type(body) ~= "string"
            or #body < 64
        then
            return false
        end

        extension = string.lower(tostring(extension or "")):gsub("^%.", "")

        local isOgg = body:sub(1, 4) == "OggS"
        local first, second = string.byte(body, 1, 2)
        local isMp3 = body:sub(1, 3) == "ID3"
            or (first == 0xFF and second ~= nil and second >= 0xE0)

        if extension == "ogg" then
            return isOgg
        end

        if extension == "mp3" then
            return isMp3
        end

        return isMp3 or isOgg
    end

    local function waitForSoundLoaded(sound, timeout)
        if not sound or not sound.Parent then
            return false
        end

        task.spawn(function()
            pcall(function()
                ContentProvider:PreloadAsync({sound})
            end)
        end)

        local deadline = os.clock() + (tonumber(timeout) or 8)

        while runtime.Alive
            and sound
            and sound.Parent
            and os.clock() < deadline
        do
            if sound.IsLoaded then
                return true
            end

            task.wait(0.05)
        end

        return sound
            and sound.Parent
            and sound.IsLoaded == true
    end

    local function createLoadedSound(asset, objectName, volume)
        if type(asset) ~= "string" or asset == "" then
            return nil, "Asset de sonido inválido."
        end

        local sound = Instance.new("Sound")
        sound.Name = objectName or "XeroHub_MVSD_Sound"
        sound.SoundId = asset
        sound.Volume = math.clamp(tonumber(volume) or 1, 0, 2)
        sound.PlaybackSpeed = 1
        sound.Looped = false
        sound.Parent = SoundService

        if not waitForSoundLoaded(sound, 8) then
            safeDestroy(sound)
            return nil, "El archivo se registró, pero Roblox no terminó de cargarlo."
        end

        return sound
    end

    local function loadEntryAsset(entry)
        if not assetLoader
            or type(writefile) ~= "function"
        then
            return nil, "Tu ejecutor necesita getcustomasset/getsynasset + writefile."
        end

        ensureFolder()

        local path = cachePath(entry)
        local validCache = false

        if type(isfile) == "function"
            and type(readfile) == "function"
        then
            local exists = false

            pcall(function()
                exists = isfile(path) == true
            end)

            if exists then
                local ok, cached = pcall(readfile, path)

                validCache = ok
                    and isValidAudioPayload(
                        200,
                        cached,
                        entry.extension
                    )
            end
        end

        if not validCache then
            local body, status = soundHttpGet(entry.url)

            if not isValidAudioPayload(status, body, entry.extension) then
                return nil,
                    "GitHub no devolvió un "
                    .. string.upper(tostring(entry.extension or "audio"))
                    .. " válido (HTTP "
                    .. tostring(status)
                    .. ")."
            end

            local ok, err = pcall(writefile, path, body)

            if not ok then
                return nil, "No se pudo guardar el sonido: " .. tostring(err)
            end
        end

        local ok, asset = pcall(assetLoader, path)

        if not ok or type(asset) ~= "string" or asset == "" then
            return nil, "El ejecutor no pudo registrar el audio local."
        end

        return asset, path
    end

    local function playOneShot(asset, volume, name)
        if not runtime.Alive
            or type(asset) ~= "string"
            or asset == ""
        then
            return false
        end

        local sound, err = createLoadedSound(
            asset,
            name or "XeroHub_MVSD_OneShot",
            volume
        )

        if not sound then
            warn("[XeroHub] Sound preview/load failed: " .. tostring(err))
            return false, err
        end

        soundState.ActiveOneShots[sound] = true

        runtime.Track(sound.Ended:Connect(function()
            soundState.ActiveOneShots[sound] = nil
            safeDestroy(sound)
        end))

        local ok = pcall(function()
            sound.TimePosition = 0
            sound:Play()
        end)

        if not ok then
            soundState.ActiveOneShots[sound] = nil
            safeDestroy(sound)
            return false, "Sound:Play() falló."
        end

        Debris:AddItem(sound, 15)
        return true
    end

    local function setControlSilently(control, value, select)
        if not control then return end

        local previous = runtime.SuppressNotifications
        runtime.SuppressNotifications = true

        pcall(function()
            if select and control.Select then
                control:Select(value)
            elseif control.Set then
                control:Set(value)
            elseif control.Select then
                control:Select(value)
            end
        end)

        runtime.SuppressNotifications = previous
    end

    local function applyShotMute(sound)
        if not sound or not sound.Parent then return end

        local mustMute = soundState.ShotEnabled or soundState.MuteShot

        if mustMute then
            if soundState.ShotOriginalVolumes[sound] == nil then
                soundState.ShotOriginalVolumes[sound] = sound.Volume
            end

            if sound.Volume ~= 0 then
                soundState.MutatingShotVolume[sound] = true
                sound.Volume = 0
                soundState.MutatingShotVolume[sound] = nil
            end
        else
            local original = soundState.ShotOriginalVolumes[sound]

            if original ~= nil then
                soundState.MutatingShotVolume[sound] = true
                pcall(function()
                    sound.Volume = original
                end)
                soundState.MutatingShotVolume[sound] = nil
                soundState.ShotOriginalVolumes[sound] = nil
            end
        end
    end

    local function isLocalGunshot(sound)
        if not sound or not sound:IsA("Sound") then
            return false
        end

        if sound.Name ~= "Fire"
            or assetIdDigits(sound.SoundId) ~= LOCAL_FIRE_ID
        then
            return false
        end

        local char = player.Character
        return char ~= nil and sound:IsDescendantOf(char)
    end

    local function bindGunshot(sound)
        if not isLocalGunshot(sound)
            or soundState.ShotBindings[sound]
        then
            return false
        end

        soundState.ShotBindings[sound] = true
        applyShotMute(sound)

        runtime.Track(sound.Played:Connect(function()
            if soundState.ShotEnabled
                and soundState.ShotReadySound
                and soundState.ShotReadySound.Parent
            then
                local shot = soundState.ShotReadySound:Clone()
                shot.Name = "XeroHub_CustomGunshot"
                shot.Volume = soundState.ShotVolume
                shot.Parent = SoundService
                soundState.ActiveOneShots[shot] = true

                runtime.Track(shot.Ended:Connect(function()
                    soundState.ActiveOneShots[shot] = nil
                    safeDestroy(shot)
                end))

                pcall(function()
                    shot.TimePosition = 0
                    shot:Play()
                end)

                Debris:AddItem(shot, 15)
            end
        end))

        runtime.Track(sound:GetPropertyChangedSignal("Volume"):Connect(function()
            if soundState.MutatingShotVolume[sound] then
                return
            end

            if soundState.ShotEnabled or soundState.MuteShot then
                if sound.Volume ~= 0 then
                    -- Si el juego actualiza su volumen base, conservamos ese valor.
                    soundState.ShotOriginalVolumes[sound] = sound.Volume
                    applyShotMute(sound)
                end
            end
        end))

        return true
    end

    local function scanLocalGunshots()
        local char = player.Character
        if not char then return 0 end

        local count = 0

        for _, object in ipairs(char:GetDescendants()) do
            if bindGunshot(object) then
                count += 1
            end
        end

        return count
    end

    local function restoreGunshots()
        for sound, original in pairs(soundState.ShotOriginalVolumes) do
            if sound and sound.Parent then
                soundState.MutatingShotVolume[sound] = true
                pcall(function()
                    sound.Volume = original
                end)
                soundState.MutatingShotVolume[sound] = nil
            end

            soundState.ShotOriginalVolumes[sound] = nil
        end
    end

    local function isNativeDeathUiSound(sound)
        if not sound
            or not sound:IsA("Sound")
            or not sound:IsDescendantOf(playerGui)
        then
            return false
        end

        local id = assetIdDigits(sound.SoundId)

        return id == KILL_FX_ID or id == ROUND_RESULT_ID
    end

    local function applyNativeDeathMute(sound)
        if not sound or not sound.Parent then return end

        if soundState.DeathEnabled then
            if soundState.NativeDeathOriginalVolumes[sound] == nil then
                soundState.NativeDeathOriginalVolumes[sound] = sound.Volume
            end

            if sound.Volume ~= 0 then
                soundState.MutatingDeathVolume[sound] = true
                sound.Volume = 0
                soundState.MutatingDeathVolume[sound] = nil
            end
        else
            local original = soundState.NativeDeathOriginalVolumes[sound]

            if original ~= nil then
                soundState.MutatingDeathVolume[sound] = true
                pcall(function()
                    sound.Volume = original
                end)
                soundState.MutatingDeathVolume[sound] = nil
                soundState.NativeDeathOriginalVolumes[sound] = nil
            end
        end
    end

    local function bindNativeDeathUiSound(sound)
        if not isNativeDeathUiSound(sound)
            or soundState.NativeDeathBindings[sound]
        then
            return false
        end

        soundState.NativeDeathBindings[sound] = true
        applyNativeDeathMute(sound)

        runtime.Track(sound:GetPropertyChangedSignal("Volume"):Connect(function()
            if soundState.MutatingDeathVolume[sound] then
                return
            end

            if soundState.DeathEnabled and sound.Volume ~= 0 then
                soundState.NativeDeathOriginalVolumes[sound] = sound.Volume
                applyNativeDeathMute(sound)
            end
        end))

        return true
    end

    local function scanNativeDeathUiSounds()
        local count = 0

        for _, object in ipairs(playerGui:GetDescendants()) do
            if bindNativeDeathUiSound(object) then
                count += 1
            end
        end

        return count
    end

    local function restoreNativeDeathUiSounds()
        for sound, original in pairs(soundState.NativeDeathOriginalVolumes) do
            if sound and sound.Parent then
                soundState.MutatingDeathVolume[sound] = true
                pcall(function()
                    sound.Volume = original
                end)
                soundState.MutatingDeathVolume[sound] = nil
            end

            soundState.NativeDeathOriginalVolumes[sound] = nil
        end
    end

    local function sameActiveMatch(plr, boundMatch)
        local myMatch = state.MatchId or player:GetAttribute("Match")

        if myMatch ~= nil then
            soundState.LastMatchId = myMatch
        end

        local theirMatch = plr:GetAttribute("Match") or boundMatch

        return myMatch ~= nil
            and theirMatch ~= nil
            and theirMatch == myMatch
    end

    local function bindHumanoidDeath(plr, char)
        if not plr or not char then return end

        local hum = char:FindFirstChildOfClass("Humanoid")
            or char:WaitForChild("Humanoid", 3)

        if not hum or soundState.HumanoidBindings[hum] then
            return
        end

        local boundMatch = plr:GetAttribute("Match")
        soundState.HumanoidBindings[hum] = true

        runtime.Track(hum.Died:Connect(function()
            if not soundState.DeathEnabled
                or not soundState.DeathAsset
                or not sameActiveMatch(plr, boundMatch)
            then
                return
            end

            if soundState.DeathReadySound
                and soundState.DeathReadySound.Parent
            then
                local deathSound = soundState.DeathReadySound:Clone()
                deathSound.Name = "XeroHub_CustomDeathSound"
                deathSound.Volume = soundState.DeathVolume
                deathSound.Parent = SoundService
                soundState.ActiveOneShots[deathSound] = true

                runtime.Track(deathSound.Ended:Connect(function()
                    soundState.ActiveOneShots[deathSound] = nil
                    safeDestroy(deathSound)
                end))

                pcall(function()
                    deathSound.TimePosition = 0
                    deathSound:Play()
                end)

                Debris:AddItem(deathSound, 15)
            end
        end))
    end

    local function bindDeathPlayer(plr)
        if not plr or soundState.PlayerCharacterBindings[plr] then
            return
        end

        soundState.PlayerCharacterBindings[plr] = true

        if plr.Character then
            task.defer(function()
                bindHumanoidDeath(plr, plr.Character)
            end)
        end

        runtime.Track(plr.CharacterAdded:Connect(function(char)
            task.defer(function()
                bindHumanoidDeath(plr, char)
            end)
        end))
    end

    local function getEntry(label)
        return soundState.ByLabel[label]
    end

    local function selectedEntry(channel)
        if channel == "shot" then
            return getEntry(soundState.SelectedShot)
        end

        return getEntry(soundState.SelectedDeath)
    end

    local function activateChannel(channel, silent)
        local isShot = channel == "shot"
        local entry = selectedEntry(channel)

        if not entry then
            if not silent then
                runtime.Notify(
                    "Selecciona un sonido del catálogo.",
                    {Title = "XeroHub · Sonidos"}
                )
            end

            if isShot then
                soundState.ShotDesired = false
                soundState.ShotEnabled = false
                setControlSilently(soundState.ShotToggle, false)
            else
                soundState.DeathDesired = false
                soundState.DeathEnabled = false
                setControlSilently(soundState.DeathToggle, false)
            end

            return
        end

        if not assetLoader or type(writefile) ~= "function" then
            runtime.Notify(
                "Tu ejecutor no soporta sonidos personalizados locales.",
                {Title = "XeroHub · Sonidos"}
            )

            if isShot then
                soundState.ShotDesired = false
                soundState.ShotEnabled = false
                setControlSilently(soundState.ShotToggle, false)
            else
                soundState.DeathDesired = false
                soundState.DeathEnabled = false
                setControlSilently(soundState.DeathToggle, false)
            end

            return
        end

        local token

        if isShot then
            soundState.ShotLoadToken += 1
            token = soundState.ShotLoadToken
            soundState.ShotDesired = true
        else
            soundState.DeathLoadToken += 1
            token = soundState.DeathLoadToken
            soundState.DeathDesired = true
        end

        local key = entryKey(entry)

        task.spawn(function()
            local asset, err = loadEntryAsset(entry)

            if not runtime.Alive then
                return
            end

            if isShot then
                if soundState.ShotLoadToken ~= token
                    or not soundState.ShotDesired
                then
                    return
                end
            else
                if soundState.DeathLoadToken ~= token
                    or not soundState.DeathDesired
                then
                    return
                end
            end

            if not asset then
                runtime.Notify(
                    tostring(err or "No se pudo cargar el sonido."),
                    {Title = "XeroHub · Sonidos"}
                )

                if isShot then
                    soundState.ShotEnabled = false
                    soundState.ShotDesired = false
                    setControlSilently(soundState.ShotToggle, false)
                    restoreGunshots()
                else
                    soundState.DeathEnabled = false
                    soundState.DeathDesired = false
                    setControlSilently(soundState.DeathToggle, false)
                    restoreNativeDeathUiSounds()
                end

                return
            end

            local readySound, readyErr = createLoadedSound(
                asset,
                isShot and "XeroHub_CustomGunshotReady"
                    or "XeroHub_CustomDeathReady",
                isShot and soundState.ShotVolume
                    or soundState.DeathVolume
            )

            if not readySound then
                runtime.Notify(
                    tostring(readyErr or "No se pudo precargar el sonido."),
                    {Title = "XeroHub · Sonidos"}
                )

                if isShot then
                    soundState.ShotEnabled = false
                    soundState.ShotDesired = false
                    setControlSilently(soundState.ShotToggle, false)
                    restoreGunshots()
                else
                    soundState.DeathEnabled = false
                    soundState.DeathDesired = false
                    setControlSilently(soundState.DeathToggle, false)
                    restoreNativeDeathUiSounds()
                end

                return
            end

            if isShot then
                if soundState.ShotReadySound then
                    safeDestroy(soundState.ShotReadySound)
                end

                soundState.ShotReadySound = readySound
                soundState.ShotAsset = asset
                soundState.ShotActiveKey = key
                soundState.ShotEnabled = true
                soundState.MuteShot = false
                setControlSilently(soundState.MuteToggle, false)
                scanLocalGunshots()

                for sound in pairs(soundState.ShotBindings) do
                    applyShotMute(sound)
                end
            else
                if soundState.DeathReadySound then
                    safeDestroy(soundState.DeathReadySound)
                end

                soundState.DeathReadySound = readySound
                soundState.DeathAsset = asset
                soundState.DeathActiveKey = key
                soundState.DeathEnabled = true
                scanNativeDeathUiSounds()

                for sound in pairs(soundState.NativeDeathBindings) do
                    applyNativeDeathMute(sound)
                end
            end

            if not silent then
                runtime.Notify(
                    (isShot and "Sonido de disparo: " or "Sonido de muerte: ")
                        .. tostring(entry.label),
                    {Title = "XeroHub · Sonidos"}
                )
            end
        end)
    end

    local function disableShot()
        soundState.ShotDesired = false
        soundState.ShotEnabled = false
        soundState.ShotLoadToken += 1
        soundState.ShotAsset = nil
        soundState.ShotActiveKey = nil

        if soundState.ShotReadySound then
            safeDestroy(soundState.ShotReadySound)
            soundState.ShotReadySound = nil
        end

        restoreGunshots()

        if soundState.MuteShot then
            for sound in pairs(soundState.ShotBindings) do
                applyShotMute(sound)
            end
        end
    end

    local function setMuteShot(enabled)
        soundState.MuteShot = enabled == true

        if soundState.MuteShot and soundState.ShotEnabled then
            disableShot()
            setControlSilently(soundState.ShotToggle, false)
        end

        scanLocalGunshots()

        for sound in pairs(soundState.ShotBindings) do
            applyShotMute(sound)
        end
    end

    local function disableDeath()
        soundState.DeathDesired = false
        soundState.DeathEnabled = false
        soundState.DeathLoadToken += 1
        soundState.DeathAsset = nil
        soundState.DeathActiveKey = nil

        if soundState.DeathReadySound then
            safeDestroy(soundState.DeathReadySound)
            soundState.DeathReadySound = nil
        end

        restoreNativeDeathUiSounds()
    end

    local function refreshDropdowns()
        local values = {}

        for _, entry in ipairs(soundState.Catalog) do
            values[#values + 1] = entry.label
        end

        if #values == 0 then
            values = {"Sin sonidos disponibles"}
        end

        local firstValid = soundState.ByLabel[values[1]] and values[1] or nil

        if not soundState.ByLabel[soundState.SelectedShot] then
            soundState.SelectedShot =
                soundEnv.XERO_MVSD_SELECTED_SHOT_SOUND
                or firstValid
        end

        if not soundState.ByLabel[soundState.SelectedShot] then
            soundState.SelectedShot = firstValid
        end

        if not soundState.ByLabel[soundState.SelectedDeath] then
            soundState.SelectedDeath =
                soundEnv.XERO_MVSD_SELECTED_DEATH_SOUND
                or firstValid
        end

        if not soundState.ByLabel[soundState.SelectedDeath] then
            soundState.SelectedDeath = firstValid
        end

        if soundState.ShotDropdown then
            pcall(function()
                soundState.ShotDropdown:Refresh(values)
            end)

            if soundState.SelectedShot then
                setControlSilently(
                    soundState.ShotDropdown,
                    soundState.SelectedShot,
                    true
                )
            end
        end

        if soundState.DeathDropdown then
            pcall(function()
                soundState.DeathDropdown:Refresh(values)
            end)

            if soundState.SelectedDeath then
                setControlSilently(
                    soundState.DeathDropdown,
                    soundState.SelectedDeath,
                    true
                )
            end
        end
    end

    local function applyPendingConfig()
        local data = soundState.PendingConfig

        if type(data) ~= "table"
            or not soundState.CatalogLoaded
        then
            return
        end

        soundState.PendingConfig = nil

        if soundState.ByLabel[data.ShotLabel] then
            soundState.SelectedShot = data.ShotLabel
            setControlSilently(
                soundState.ShotDropdown,
                soundState.SelectedShot,
                true
            )
        end

        if soundState.ByLabel[data.DeathLabel] then
            soundState.SelectedDeath = data.DeathLabel
            setControlSilently(
                soundState.DeathDropdown,
                soundState.SelectedDeath,
                true
            )
        end

        if data.ShotVolume ~= nil then
            soundState.ShotVolume = math.clamp(
                tonumber(data.ShotVolume) or 1,
                0,
                1
            )
            setControlSilently(
                soundState.ShotSlider,
                math.floor(soundState.ShotVolume * 100 + 0.5)
            )
        end

        if data.DeathVolume ~= nil then
            soundState.DeathVolume = math.clamp(
                tonumber(data.DeathVolume) or 1,
                0,
                1
            )
            setControlSilently(
                soundState.DeathSlider,
                math.floor(soundState.DeathVolume * 100 + 0.5)
            )
        end

        if data.MuteShot == true then
            setControlSilently(soundState.MuteToggle, true)
            setMuteShot(true)
        else
            setControlSilently(soundState.MuteToggle, false)
            setMuteShot(false)

            if data.ShotEnabled == true then
                setControlSilently(soundState.ShotToggle, true)
                soundState.ShotDesired = true
                activateChannel("shot", true)
            else
                setControlSilently(soundState.ShotToggle, false)
                disableShot()
            end
        end

        if data.DeathEnabled == true then
            setControlSilently(soundState.DeathToggle, true)
            soundState.DeathDesired = true
            activateChannel("death", true)
        else
            setControlSilently(soundState.DeathToggle, false)
            disableDeath()
        end
    end

    local function applyCatalog(catalog)
        soundState.Catalog = catalog
        soundState.ByLabel = {}

        for _, entry in ipairs(catalog) do
            soundState.ByLabel[entry.label] = entry
        end

        soundState.CatalogLoaded = #catalog > 0
        refreshDropdowns()
        applyPendingConfig()
    end

    local function loadCatalog(force)
        if soundState.CatalogLoading then
            return
        end

        soundState.CatalogLoading = true

        task.spawn(function()
            ensureFolder()

            local body = nil

            if not force
                and type(isfile) == "function"
                and type(readfile) == "function"
            then
                local exists = false
                pcall(function()
                    exists = isfile(CATALOG_CACHE) == true
                end)

                if exists then
                    pcall(function()
                        body = readfile(CATALOG_CACHE)
                    end)
                end
            end

            -- Siempre intentamos actualizar desde GitHub.
            local remoteBody = soundHttpGet(CATALOG_URL)
            if type(remoteBody) == "string" and remoteBody ~= "" then
                body = remoteBody

                if type(writefile) == "function" then
                    pcall(writefile, CATALOG_CACHE, remoteBody)
                end
            end

            local catalog = {}

            if type(body) == "string" and body ~= "" then
                local ok, decoded = pcall(function()
                    return HttpService:JSONDecode(body)
                end)

                if ok then
                    catalog = parseCatalog(decoded)
                end
            end

            soundState.CatalogLoading = false
            applyCatalog(catalog)

            if force then
                runtime.Notify(
                    #catalog > 0
                        and ("Sonidos actualizados: " .. tostring(#catalog))
                        or "No se pudo cargar el catálogo de sonidos.",
                    {Title = "XeroHub · Sonidos"}
                )
            end
        end)
    end

    -- --------------------------------------------------------
    -- UI
    -- --------------------------------------------------------

    Tabs.Sonidos:Section({Title = "Sonido de disparo"})

    soundState.ShotDropdown = Tabs.Sonidos:Dropdown({
        Title = "Sonido del arma",
        Desc = "Elige el sonido al disparar.",
        Values = {"Cargando catálogo…"},
        Value = "Cargando catálogo…",
        Callback = function(value)
            local label = type(value) == "table" and value[1] or value

            if not soundState.ByLabel[label] then
                return
            end

            local changed = soundState.SelectedShot ~= label
            soundState.SelectedShot = label
            soundEnv.XERO_MVSD_SELECTED_SHOT_SOUND = label

            if changed and soundState.ShotDesired then
                activateChannel("shot", true)
            end
        end,
    })

    Tabs.Sonidos:Button({
        Title = "Actualizar sonidos",
        Desc = "Carga sonidos nuevos del repo.",
        Callback = function()
            loadCatalog(true)
        end,
    })

    Tabs.Sonidos:Button({
        Title = "Probar disparo",
        Desc = "Escucha el sonido seleccionado.",
        Callback = function()
            local entry = selectedEntry("shot")

            if not entry then
                runtime.Notify(
                    "Selecciona un sonido.",
                    {Title = "XeroHub · Sonidos"}
                )
                return
            end

            task.spawn(function()
                local asset, err = loadEntryAsset(entry)

                if asset then
                    local played, playErr = playOneShot(
                        asset,
                        soundState.ShotVolume,
                        "XeroHub_GunshotPreview"
                    )

                    if not played then
                        runtime.Notify(
                            tostring(playErr or "No se pudo reproducir el sonido."),
                            {Title = "XeroHub · Sonidos"}
                        )
                    end
                else
                    runtime.Notify(
                        tostring(err),
                        {Title = "XeroHub · Sonidos"}
                    )
                end
            end)
        end,
    })

    soundState.ShotSlider = Tabs.Sonidos:Slider({
        Title = "Volumen de disparo",
        Desc = "Ajusta el volumen personalizado.",
        Step = 1,
        Value = {Min = 0, Max = 100, Default = 100},
        Callback = function(value)
            soundState.ShotVolume = math.clamp(
                (tonumber(value) or 100) / 100,
                0,
                1
            )

            if soundState.ShotReadySound and soundState.ShotReadySound.Parent then
                soundState.ShotReadySound.Volume = soundState.ShotVolume
            end
        end,
    })
    UIElements.SliWeaponSoundVolume = soundState.ShotSlider

    soundState.ShotToggle = Tabs.Sonidos:Toggle({
        Title = "Cambiar sonido",
        Desc = "Usa el sonido elegido al disparar.",
        Value = false,
        Callback = function(enabled)
            if enabled then
                soundState.MuteShot = false
                setControlSilently(soundState.MuteToggle, false)
                soundState.ShotDesired = true
                activateChannel("shot", false)
            else
                disableShot()
            end
        end,
    })
    UIElements.TogWeaponSound = soundState.ShotToggle

    soundState.MuteToggle = Tabs.Sonidos:Toggle({
        Title = "Desactivar sonido de disparo",
        Desc = "Dispara sin sonido.",
        Value = false,
        Callback = function(enabled)
            setMuteShot(enabled == true)
        end,
    })
    UIElements.TogMuteGunshot = soundState.MuteToggle

    Tabs.Sonidos:Section({Title = "Sonido de muerte"})

    soundState.DeathDropdown = Tabs.Sonidos:Dropdown({
        Title = "Sonido de muerte",
        Desc = "Suena cuando muere alguien de tu partida.",
        Values = {"Cargando catálogo…"},
        Value = "Cargando catálogo…",
        Callback = function(value)
            local label = type(value) == "table" and value[1] or value

            if not soundState.ByLabel[label] then
                return
            end

            local changed = soundState.SelectedDeath ~= label
            soundState.SelectedDeath = label
            soundEnv.XERO_MVSD_SELECTED_DEATH_SOUND = label

            if changed and soundState.DeathDesired then
                activateChannel("death", true)
            end
        end,
    })

    Tabs.Sonidos:Button({
        Title = "Probar sonido de muerte",
        Desc = "Escucha el sonido seleccionado.",
        Callback = function()
            local entry = selectedEntry("death")

            if not entry then
                runtime.Notify(
                    "Selecciona un sonido.",
                    {Title = "XeroHub · Sonidos"}
                )
                return
            end

            task.spawn(function()
                local asset, err = loadEntryAsset(entry)

                if asset then
                    local played, playErr = playOneShot(
                        asset,
                        soundState.DeathVolume,
                        "XeroHub_DeathPreview"
                    )

                    if not played then
                        runtime.Notify(
                            tostring(playErr or "No se pudo reproducir el sonido."),
                            {Title = "XeroHub · Sonidos"}
                        )
                    end
                else
                    runtime.Notify(
                        tostring(err),
                        {Title = "XeroHub · Sonidos"}
                    )
                end
            end)
        end,
    })

    soundState.DeathSlider = Tabs.Sonidos:Slider({
        Title = "Volumen de muerte",
        Desc = "Ajusta el volumen personalizado.",
        Step = 1,
        Value = {Min = 0, Max = 100, Default = 100},
        Callback = function(value)
            soundState.DeathVolume = math.clamp(
                (tonumber(value) or 100) / 100,
                0,
                1
            )

            if soundState.DeathReadySound and soundState.DeathReadySound.Parent then
                soundState.DeathReadySound.Volume = soundState.DeathVolume
            end
        end,
    })
    UIElements.SliKillSoundVolume = soundState.DeathSlider

    soundState.DeathToggle = Tabs.Sonidos:Toggle({
        Title = "Cambiar sonido de muerte",
        Desc = "Reproduce el sonido en muertes de la partida.",
        Value = false,
        Callback = function(enabled)
            if enabled then
                soundState.DeathDesired = true
                activateChannel("death", false)
            else
                disableDeath()
            end
        end,
    })
    UIElements.TogKillSound = soundState.DeathToggle

    -- --------------------------------------------------------
    -- Bindings
    -- --------------------------------------------------------

    for _, plr in ipairs(Players:GetPlayers()) do
        bindDeathPlayer(plr)
    end

    runtime.Track(Players.PlayerAdded:Connect(function(plr)
        bindDeathPlayer(plr)
    end))

    runtime.Track(playerGui.DescendantAdded:Connect(function(object)
        if object:IsA("Sound") then
            bindNativeDeathUiSound(object)
        end
    end))

    runtime.Track(player.CharacterAdded:Connect(function(char)
        task.defer(function()
            for _, object in ipairs(char:GetDescendants()) do
                bindGunshot(object)
            end

            runtime.Track(char.DescendantAdded:Connect(function(object)
                if object:IsA("Sound") then
                    bindGunshot(object)
                end
            end))
        end)
    end))

    local currentChar = player.Character
    if currentChar then
        for _, object in ipairs(currentChar:GetDescendants()) do
            bindGunshot(object)
        end

        runtime.Track(currentChar.DescendantAdded:Connect(function(object)
            if object:IsA("Sound") then
                bindGunshot(object)
            end
        end))
    end

    scanNativeDeathUiSounds()

    runtime.Track(player:GetAttributeChangedSignal("Match"):Connect(function()
        local matchId = player:GetAttribute("Match")
        if matchId ~= nil then
            soundState.LastMatchId = matchId
        end
    end))

    -- --------------------------------------------------------
    -- Config bridge
    -- --------------------------------------------------------

    runtime.SoundExportConfig = function()
        return {
            ShotLabel = soundState.SelectedShot,
            DeathLabel = soundState.SelectedDeath,
            ShotEnabled = soundState.ShotEnabled or soundState.ShotDesired,
            DeathEnabled = soundState.DeathEnabled or soundState.DeathDesired,
            MuteShot = soundState.MuteShot,
            ShotVolume = soundState.ShotVolume,
            DeathVolume = soundState.DeathVolume,
        }
    end

    runtime.SoundLoadConfig = function(data)
        if type(data) ~= "table" then
            return false
        end

        soundState.PendingConfig = data
        applyPendingConfig()
        return true
    end

    runtime.SoundCleanup = function()
        soundState.ShotDesired = false
        soundState.DeathDesired = false
        soundState.ShotEnabled = false
        soundState.DeathEnabled = false
        soundState.MuteShot = false
        soundState.ShotLoadToken += 1
        soundState.DeathLoadToken += 1

        restoreGunshots()
        restoreNativeDeathUiSounds()

        for sound in pairs(soundState.ActiveOneShots) do
            soundState.ActiveOneShots[sound] = nil
            safeDestroy(sound)
        end

        soundState.ShotAsset = nil
        soundState.DeathAsset = nil

        if soundState.ShotReadySound then
            safeDestroy(soundState.ShotReadySound)
            soundState.ShotReadySound = nil
        end

        if soundState.DeathReadySound then
            safeDestroy(soundState.DeathReadySound)
            soundState.DeathReadySound = nil
        end
    end

    loadCatalog(false)
end

-- ==========================================
-- CONFIGURACIÓN
-- ==========================================

Tabs.Config:Section({Title = "Personalización de Interfaz"})

local currentInterfaceTheme = (Window.GetTheme and Window:GetTheme()) or "Xero"
runtime.InterfaceTheme = currentInterfaceTheme

UIElements.ThemeDropdown = Tabs.Config:Dropdown({
    Title = "Tema de Interfaz",
    Desc = "Cambia entre oscuro y blanco.",
    Values = {"Oscuro", "Blanco"},
    Value = currentInterfaceTheme == "Blanco" and "Blanco" or "Oscuro",
    Callback = function(value)
        local selected = type(value) == "table" and value[1] or value
        local targetTheme = selected == "Blanco" and "Blanco" or "Xero"
        runtime.InterfaceTheme = targetTheme

        if Window.SetTheme then
            Window:SetTheme(targetTheme)
        elseif WindUI.SetTheme then
            WindUI:SetTheme(targetTheme)
        end
    end,
})

UIElements.ToggleOpenButtonGhost = Tabs.Config:Toggle({
    Title = "Ocultar Botón Flotante",
    Desc = "Oculta el botón para abrir XeroHub.",
    Value = false,
    Callback = function(value)
        state.OpenButtonGhost = value == true
        if Window.SetOpenButtonGhosted then
            Window:SetOpenButtonGhosted(state.OpenButtonGhost)
        end
    end,
})

-- Gestor de configs adaptado de DUELS.
Tabs.Config:Section({Title = "Gestor de Configs"})

local configFolder = "XeroHub_Configs_MVSD"
if type(isfolder) == "function" and type(makefolder) == "function" and not isfolder(configFolder) then
    pcall(makefolder, configFolder)
end

local availableConfigs = {"Ninguna"}
local selectedConfig = "Ninguna"
local customConfigName = ""
local configPaths = {}
local configDropdownSyncing = false
local autoLoadSyncing = false
local autoLoadToggle
local autoLoadPath = configFolder .. "/_autoload.xero"
local autoLoadEnabled = false
local autoLoadConfigName = nil

local function saveAutoLoadState()
    if type(writefile) ~= "function" then return false end

    local ok, encoded = pcall(function()
        return HttpService:JSONEncode({
            Enabled = autoLoadEnabled == true,
            Config = autoLoadConfigName,
        })
    end)

    if not ok then return false end
    return pcall(writefile, autoLoadPath, encoded)
end

local function readAutoLoadState()
    if type(isfile) ~= "function"
        or type(readfile) ~= "function"
        or not isfile(autoLoadPath)
    then
        return
    end

    local ok, decoded = pcall(function()
        return HttpService:JSONDecode(readfile(autoLoadPath))
    end)

    if ok and type(decoded) == "table" then
        autoLoadEnabled = decoded.Enabled == true

        if type(decoded.Config) == "string"
            and decoded.Config ~= ""
            and decoded.Config ~= "Ninguna"
        then
            autoLoadConfigName = decoded.Config
            if autoLoadEnabled then
                selectedConfig = decoded.Config
            end
        end
    end
end

readAutoLoadState()

local configDropdown = Tabs.Config:Dropdown({
    Title = "Seleccionar Configuración",
    Values = availableConfigs,
    Value = "Ninguna",
    Callback = function(value)
        local selected = type(value) == "table" and value[1] or value
        selectedConfig = tostring(selected or "Ninguna")

        if not configDropdownSyncing
            and autoLoadEnabled
            and selectedConfig ~= "Ninguna"
        then
            autoLoadConfigName = selectedConfig
            saveAutoLoadState()
        end
    end,
})

local function refreshConfigs()
    local list = {}
    local seen = {}
    configPaths = {}

    if type(listfiles) == "function" then
        pcall(function()
            for _, file in ipairs(listfiles(configFolder)) do
                if file:match("%.json$") then
                    local name = file:match("([^/\\]+)%.json$")
                    if name and not seen[name] then
                        seen[name] = true
                        configPaths[name] = file
                        list[#list + 1] = name
                    end
                end
            end
        end)
    end

    table.sort(list)
    if #list == 0 then
        list[1] = "Ninguna"
    end

    pcall(function()
        configDropdown:Refresh(list)

        local desired = selectedConfig
        if autoLoadEnabled
            and autoLoadConfigName
            and table.find(list, autoLoadConfigName)
        then
            desired = autoLoadConfigName
        end

        if not table.find(list, desired) then
            desired = list[1]
        end

        configDropdownSyncing = true
        configDropdown:Select(desired)
        configDropdownSyncing = false
        selectedConfig = desired
    end)
end

autoLoadToggle = Tabs.Config:Toggle({
    Title = "Auto Load Config",
    Desc = "Carga esta config al iniciar.",
    Value = autoLoadEnabled,
    Callback = function(value)
        if autoLoadSyncing then return end

        if value then
            if selectedConfig == "" or selectedConfig == "Ninguna" then
                autoLoadEnabled = false
                autoLoadConfigName = nil
                saveAutoLoadState()
                runtime.Notify("Selecciona una configuración antes de activar Auto Load.", {Title = "XeroHub · Config"})

                task.defer(function()
                    if not autoLoadToggle then return end
                    runtime.SuppressNotifications = true
                    autoLoadSyncing = true
                    pcall(function() autoLoadToggle:Set(false) end)
                    autoLoadSyncing = false
                    runtime.SuppressNotifications = false
                end)
                return
            end

            autoLoadEnabled = true
            autoLoadConfigName = selectedConfig
            saveAutoLoadState()
            runtime.Notify("Auto Load: " .. selectedConfig, {Title = "XeroHub · Config"})
        else
            autoLoadEnabled = false
            saveAutoLoadState()
            runtime.Notify("Auto Load desactivado.", {Title = "XeroHub · Config"})
        end
    end,
})
UIElements.ToggleAutoLoadConfig = autoLoadToggle

Tabs.Config:Button({
    Title = "Actualizar Lista",
    Callback = function()
        refreshConfigs()
        runtime.Notify("Lista de configuraciones actualizada.", {Title = "XeroHub · Config"})
    end,
})

Tabs.Config:Input({
    Title = "Nombre para Guardar",
    Placeholder = "Ej: Legit, Full, Config 1...",
    Callback = function(text)
        customConfigName = tostring(text or "")
    end,
})

local function serializeConfig(name)
    return {
        ConfigName = name,
        Toggles = {
            SilentAim = state.SilentAim,
            AutoShoot = state.AutoShoot,
            RapidFire = state.RapidFire,
            RapidFireButtonVisible = state.RapidFireButtonVisible,
            SpamFireButtonVisible = state.SpamFireButtonVisible,
            RoundStartSpam = state.RoundStartSpam,
            ESP = state.ESP,
            FOVFilter = state.FOVFilter,
            ShowFOV = state.ShowFOV,
            ESPGlow = state.ESPGlow,
            ESPName = state.ESPName,
            ESPHealth = state.ESPHealth,
            ESPDistance = state.ESPDistance,
            ESPLines = state.ESPLines,
            ESPSkeleton = state.ESPSkeleton,
            HitboxExpander = state.HitboxExpander,
            HitboxVisible = state.HitboxVisible,
            OpenButtonGhost = state.OpenButtonGhost,
        },
        Sliders = {
            FOVRadius = state.FOVRadius,
            AutoShootDelay = state.AutoShootDelay,
            RapidFireRate = state.RapidFireRate,
            RoundStartSpamRate = state.RoundStartSpamRate,
            HitboxSize = state.HitboxSize,
        },
        Colors = {
            ESP = {
                R = state.ESPColor.R,
                G = state.ESPColor.G,
                B = state.ESPColor.B,
            },
        },
        TargetParts = {
            SilentAim = runtime.GetTargetSelectionArray("SilentAim"),
        },
        Interface = {
            Theme = runtime.InterfaceTheme or "Xero",
        },
        Sounds = runtime.SoundExportConfig
            and runtime.SoundExportConfig()
            or nil,
    }
end

local function setElement(element, value)
    if not element or value == nil then return end

    local old = runtime.SuppressNotifications
    runtime.SuppressNotifications = true

    pcall(function()
        if element.Set then
            element:Set(value)
        elseif element.Select then
            element:Select(value)
        end
    end)

    runtime.SuppressNotifications = old
end

local function applyConfig(decoded)
    if type(decoded) ~= "table" then return false end

    local toggles = type(decoded.Toggles) == "table" and decoded.Toggles or {}
    local sliders = type(decoded.Sliders) == "table" and decoded.Sliders or {}
    local colors = type(decoded.Colors) == "table" and decoded.Colors or {}
    local targetParts = type(decoded.TargetParts) == "table" and decoded.TargetParts or {}
    local interface = type(decoded.Interface) == "table" and decoded.Interface or {}

    if toggles.SilentAim ~= nil then
        state.SilentAim = toggles.SilentAim == true
        setElement(UIElements.TogSilentAim, state.SilentAim)
    end
    if toggles.AutoShoot ~= nil then
        state.AutoShoot = toggles.AutoShoot == true
        state.AutoShootAccumulator = 0
        state.AutoShootNextAllowedAt = 0
        table.clear(runtime.AutoShootTargetCooldown)
        setElement(UIElements.TogAutoShoot, state.AutoShoot)
    end
    if toggles.ESP ~= nil then
        state.ESP = toggles.ESP == true
        setElement(UIElements.TogESP, state.ESP)
    end
    if toggles.FOVFilter ~= nil then
        state.FOVFilter = toggles.FOVFilter == true
        setElement(UIElements.TogFOVFilter, state.FOVFilter)
    end
    if toggles.ShowFOV ~= nil then
        state.ShowFOV = toggles.ShowFOV == true
        setElement(UIElements.TogShowFOV, state.ShowFOV)
    end
    if toggles.ESPGlow ~= nil then
        state.ESPGlow = toggles.ESPGlow == true
        setElement(UIElements.TogESPGlow, state.ESPGlow)
    end
    if toggles.ESPName ~= nil then
        state.ESPName = toggles.ESPName == true
        setElement(UIElements.TogESPName, state.ESPName)
    end
    if toggles.ESPHealth ~= nil then
        state.ESPHealth = toggles.ESPHealth == true
        setElement(UIElements.TogESPHealth, state.ESPHealth)
    end
    if toggles.ESPDistance ~= nil then
        state.ESPDistance = toggles.ESPDistance == true
        setElement(UIElements.TogESPDistance, state.ESPDistance)
    end
    if toggles.ESPLines ~= nil then
        state.ESPLines = toggles.ESPLines == true
        setElement(UIElements.TogESPLines, state.ESPLines)
    end
    if toggles.ESPSkeleton ~= nil then
        state.ESPSkeleton = toggles.ESPSkeleton == true
        setElement(UIElements.TogESPSkeleton, state.ESPSkeleton)
    end
    if toggles.HitboxExpander ~= nil then
        state.HitboxExpander = toggles.HitboxExpander == true
        setElement(UIElements.TogHitboxExpander, state.HitboxExpander)
    end
    if toggles.HitboxVisible ~= nil then
        state.HitboxVisible = toggles.HitboxVisible == true
        setElement(UIElements.TogHitboxVisible, state.HitboxVisible)
    end
    if toggles.OpenButtonGhost ~= nil then
        state.OpenButtonGhost = toggles.OpenButtonGhost == true
        setElement(UIElements.ToggleOpenButtonGhost, state.OpenButtonGhost)
    end

    if sliders.FOVRadius ~= nil then
        state.FOVRadius = tonumber(sliders.FOVRadius) or state.FOVRadius
        setElement(UIElements.SliFOV, state.FOVRadius)
    end
    if sliders.AutoShootDelay ~= nil then
        state.AutoShootDelay = math.clamp(
            tonumber(sliders.AutoShootDelay) or state.AutoShootDelay,
            0,
            2
        )
        state.AutoShootNextAllowedAt = 0
        setElement(UIElements.SliAutoShootDelay, state.AutoShootDelay)
    end
    if sliders.RapidFireRate ~= nil then
        state.RapidFireRate = math.clamp(tonumber(sliders.RapidFireRate) or state.RapidFireRate, 1, 30)
        state.RapidFireAccumulator = 0
        setElement(UIElements.SliRapidFireRate, state.RapidFireRate)
    end
    if sliders.RoundStartSpamRate ~= nil then
        state.RoundStartSpamRate = math.clamp(
            tonumber(sliders.RoundStartSpamRate) or state.RoundStartSpamRate,
            5,
            60
        )
        state.RoundStartSpamAccumulator = 0
        setElement(UIElements.SliRoundStartSpamRate, state.RoundStartSpamRate)
    end
    if sliders.HitboxSize ~= nil then
        state.HitboxSize = math.clamp(
            tonumber(sliders.HitboxSize) or state.HitboxSize,
            2,
            50
        )
        setElement(UIElements.SliHitboxSize, state.HitboxSize)
    end

    if state.HitboxExpander then
        local ok, err = pcall(runtime.RefreshExpandedHitboxes)

        if not ok then
            state.HitboxExpander = false
            pcall(runtime.RestoreAllExpandedHitboxes)
                warn("[XeroHub] Hitbox config ignorado:", err)
        end
    else
        pcall(runtime.RestoreAllExpandedHitboxes)
    end

    if type(colors.ESP) == "table" then
        local ok, color = pcall(function()
            return Color3.new(
                tonumber(colors.ESP.R) or 1,
                tonumber(colors.ESP.G) or 1,
                tonumber(colors.ESP.B) or 1
            )
        end)

        if ok and color then
            state.ESPColor = color
            setElement(UIElements.ColESP, color)
        end
    end

    if targetParts.SilentAim then
        runtime.SetTargetSelection("SilentAim", targetParts.SilentAim)
    end

    if interface.Theme then
        local targetTheme = tostring(interface.Theme) == "Blanco" and "Blanco" or "Xero"
        runtime.InterfaceTheme = targetTheme

        if Window.SetTheme then
            Window:SetTheme(targetTheme, true)
        elseif WindUI.SetTheme then
            WindUI:SetTheme(targetTheme)
        end

        pcall(function()
            UIElements.ThemeDropdown:Select(targetTheme == "Blanco" and "Blanco" or "Oscuro")
        end)
    end

    if runtime.SoundLoadConfig and type(decoded.Sounds) == "table" then
        runtime.SoundLoadConfig(decoded.Sounds)
    end

    if not state.ESP then
        clearESP()
    end

    if toggles.RapidFireButtonVisible ~= nil then
        state.RapidFireButtonVisible = toggles.RapidFireButtonVisible == true
        setElement(UIElements.TogRapidFireButton, state.RapidFireButtonVisible)
    end
    if toggles.SpamFireButtonVisible ~= nil then
        state.SpamFireButtonVisible = toggles.SpamFireButtonVisible == true
        setElement(UIElements.TogSpamFireButton, state.SpamFireButtonVisible)
    end
    if runtime.RefreshFireButtons then runtime.RefreshFireButtons() end
    if toggles.RapidFire ~= nil then
        runtime.SetFireEnabled("RapidFire", toggles.RapidFire, true)
    end
    if toggles.RoundStartSpam ~= nil then
        runtime.SetFireEnabled("RoundStartSpam", toggles.RoundStartSpam, true)
    end

    return true
end

Tabs.Config:Button({
    Title = "Guardar Configuración",
    Callback = function()
        if type(writefile) ~= "function" then
            runtime.Notify("Tu ejecutor no soporta writefile.", {Title = "XeroHub · Config"})
            return
        end

        local finalName = customConfigName:gsub("[^%w%s%-_]", "")
        if finalName == "" then
            finalName = selectedConfig
        end

        if finalName == "" or finalName == "Ninguna" then
            runtime.Notify("Escribe un nombre válido o selecciona una config.", {Title = "XeroHub · Config"})
            return
        end

        local ok, encoded = pcall(function()
            return HttpService:JSONEncode(serializeConfig(finalName))
        end)

        if not ok then
            runtime.Notify("No se pudo serializar la configuración.", {Title = "XeroHub · Config"})
            return
        end

        local path = configFolder .. "/" .. finalName .. ".json"
        local wrote = pcall(writefile, path, encoded)

        if wrote then
            selectedConfig = finalName
            refreshConfigs()
            pcall(function() configDropdown:Select(finalName) end)
            runtime.Notify("Guardado como: " .. finalName, {Title = "XeroHub · Config"})
        else
            runtime.Notify("No se pudo escribir el archivo.", {Title = "XeroHub · Config"})
        end
    end,
})

local function loadConfigByName(name, auto)
    name = tostring(name or selectedConfig or "Ninguna")
    if name == "" or name == "Ninguna" then
        if not auto then
            runtime.Notify("No hay configuración seleccionada.", {Title = "XeroHub · Config"})
        end
        return false
    end

    local path = configPaths[name] or (configFolder .. "/" .. name .. ".json")
    if type(isfile) ~= "function" or type(readfile) ~= "function" or not isfile(path) then
        runtime.Notify("La configuración no existe: " .. name, {Title = "XeroHub · Config"})
        return false
    end

    local ok, decoded = pcall(function()
        return HttpService:JSONDecode(readfile(path))
    end)

    if not ok or type(decoded) ~= "table" then
        runtime.Notify("Error al leer la configuración.", {Title = "XeroHub · Config"})
        return false
    end

    runtime.SuppressNotifications = true
    local applied = applyConfig(decoded)
    runtime.SuppressNotifications = false

    if applied then
        selectedConfig = name
        runtime.Notify(
            (auto and "Auto Load: " or "Cargada: ") .. name,
            {Title = "XeroHub · Config"}
        )
    end

    return applied
end

Tabs.Config:Button({
    Title = "Cargar Configuración",
    Callback = function()
        loadConfigByName(selectedConfig, false)
    end,
})

Tabs.Config:Button({
    Title = "Eliminar Configuración",
    Desc = "Borra la config seleccionada.",
    Callback = function()
        if selectedConfig == "" or selectedConfig == "Ninguna" then
            runtime.Notify("Selecciona una configuración primero.", {Title = "XeroHub · Config"})
            return
        end

        local path = configPaths[selectedConfig] or (configFolder .. "/" .. selectedConfig .. ".json")
        if type(delfile) ~= "function" or type(isfile) ~= "function" then
            runtime.Notify("Tu ejecutor no soporta eliminar archivos.", {Title = "XeroHub · Config"})
            return
        end

        if isfile(path) then
            local oldName = selectedConfig
            pcall(delfile, path)
            selectedConfig = "Ninguna"

            if autoLoadConfigName == oldName then
                autoLoadEnabled = false
                autoLoadConfigName = nil
                saveAutoLoadState()
            end

            refreshConfigs()
            runtime.Notify("Eliminada: " .. oldName, {Title = "XeroHub · Config"})
        end
    end,
})

-- ==========================================
-- CRÉDITOS
-- ==========================================

local XERO_CREDITS_PROFILE = "rbxassetid://74846094133538"
local XERO_CREDITS_ALEX_PROFILE = "rbxassetid://77826666877085"

Tabs.Creditos:Paragraph({
    Title = "Kev",
    Desc = "Creador de XeroHub\nTikTok: @kevzzx_",
    Image = XERO_CREDITS_PROFILE,
    ImageSize = 72,
    CircleImage = true,
    ImageAlign = "left",
    ImageStrokeColor = Color3.fromRGB(248, 248, 248),
    ImageStrokeThickness = 1,
    Gothic = true,
    BadgeText = "CREATOR",
    DecorText = "XERO",
    Color = Color3.fromRGB(9, 9, 12),
    StrokeColor = Color3.fromRGB(54, 54, 62),
})

Tabs.Creditos:Paragraph({
    Title = "Alex",
    Desc = "TikTok: @onyxdevv",
    Image = XERO_CREDITS_ALEX_PROFILE,
    ImageSize = 72,
    CircleImage = true,
    ImageAlign = "left",
    ImageStrokeColor = Color3.fromRGB(248, 248, 248),
    ImageStrokeThickness = 1,
    Gothic = true,
    BadgeText = "CREDITS",
    DecorText = "ONYX",
    Color = Color3.fromRGB(9, 9, 12),
    StrokeColor = Color3.fromRGB(54, 54, 62),
})

Tabs.Creditos:Paragraph({
    Title = "Agradecimientos",
    Desc = "Gracias por usar XeroHub, su apoyo ayuda a mejorarlo más.",
    Gothic = true,
    DecorText = "THANKS",
    Color = Color3.fromRGB(11, 11, 14),
    StrokeColor = Color3.fromRGB(44, 44, 50),
})

-- Estado visible sin recrear controles.
runtime.Track(RunService.Heartbeat:Connect(function(dt)
    runtime.StatusTimer = (runtime.StatusTimer or 0) + dt
    if runtime.StatusTimer < 0.5 then return end
    runtime.StatusTimer = 0

    pcall(function()
        if lobbyParagraph and lobbyParagraph.SetDesc then
            if state.InLobby then
                lobbyParagraph:SetDesc("Lobby · " .. tostring(state.LobbyReason))
            else
                local target = state.SilentTargetPlayer
                lobbyParagraph:SetDesc(
                    target
                    and ("Partida · Target: " .. target.Name)
                    or "Partida · Sin target"
                )
            end
        end
    end)
end))

-- Contador de activos no bloqueante, igual que DUELS.
task.spawn(function()
    local req = (syn and syn.request) or (http and http.request) or http_request or request
    if not req then return end

    local lastCount = nil
    while runtime.Alive do
        local ok, response = pcall(function()
            return req({
                Url = "https://hub.onyx-scripts.com/ping?user="
                    .. tostring(player.Name)
                    .. "&jobid="
                    .. tostring(game.JobId),
                Method = "GET",
                Headers = {
                    ["Astra-Auth"] = "OnyxHub!",
                    ["User-Agent"] = "Roblox/XeroHub-MVSD",
                },
            })
        end)

        if ok and response and tonumber(response.StatusCode) == 200 then
            local count = tonumber(response.Body)
            if count and count ~= lastCount then
                lastCount = count
                pcall(function()
                    Window:SetTitle("XERO | MVSD · " .. tostring(count) .. " activos")
                end)
            end
        end

        task.wait(10)
    end
end)

-- Configs y Auto Load se preparan después de mostrar la UI para no dejar
-- la pantalla pegada en "Preparando controles..." por I/O del ejecutor.
refreshConfigs()
startupSplashState.Finish()
runtime.NotificationsReady = true

task.spawn(function()
    if autoLoadToggle then
        runtime.SuppressNotifications = true
        autoLoadSyncing = true
        pcall(function() autoLoadToggle:Set(autoLoadEnabled) end)
        autoLoadSyncing = false
        runtime.SuppressNotifications = false
    end

    if autoLoadEnabled and autoLoadConfigName then
        task.wait(0.10)
        refreshConfigs()
        loadConfigByName(autoLoadConfigName, true)
    end
end)

pcall(function()
    Window:OnDestroy(function()
        if runtimeEnv.__XERO_MVSD_HUB_CLEANUP then
            runtimeEnv.__XERO_MVSD_HUB_CLEANUP()
        end
    end)
end)

-- ==========================================
-- CLEANUP
-- ==========================================

runtimeEnv.__XERO_MVSD_HUB_CLEANUP = function()
    if not runtime.Alive then return end
    runtime.Alive = false

    state.SilentAim = false
    state.AutoShoot = false
    state.AutoShootAccumulator = 0
    state.AutoShootNextAllowedAt = 0
    state.RapidFire = false
    state.RoundStartSpam = false
    state.RoundStartSpamAccumulator = 0
    state.RapidFireAccumulator = 0
    state.ESP = false
    state.ESPLines = false
    state.ESPSkeleton = false
    state.HitboxExpander = false
    aimHookState.Target = nil

    table.clear(runtime.AutoShootTargetCooldown)
    pcall(runtime.RestoreAllExpandedHitboxes)

    if runtime.HideAllESPGeometry then
        runtime.HideAllESPGeometry()
    end

    if runtime.RapidFireTrack then
        pcall(function()
            runtime.RapidFireTrack:Stop(0)
            runtime.RapidFireTrack:Destroy()
        end)
        runtime.RapidFireTrack = nil
    end

    if runtime.RapidFireAnimation then
        safeDestroy(runtime.RapidFireAnimation)
        runtime.RapidFireAnimation = nil
    end

    if runtime.RapidFireFallbackSound then
        safeDestroy(runtime.RapidFireFallbackSound)
        runtime.RapidFireFallbackSound = nil
    end

    for i = 1, #(runtime.RapidFireSoundPool or {}) do
        safeDestroy(runtime.RapidFireSoundPool[i])
        runtime.RapidFireSoundPool[i] = nil
    end

    if runtime.FireButtonsCleanup then
        pcall(runtime.FireButtonsCleanup)
    end

    if runtime.GhostCleanup then
        pcall(runtime.GhostCleanup)
    end

    if runtime.MovementCleanup then
        pcall(runtime.MovementCleanup)
    end

    if runtime.SkyCleanup then
        pcall(runtime.SkyCleanup)
    end

    if runtime.SoundCleanup then
        pcall(runtime.SoundCleanup)
    end

    clearESP()
    runtime.DestroyAllESPGeometry()

    if runtime.BodySelectorGui then
        safeDestroy(runtime.BodySelectorGui)
        runtime.BodySelectorGui = nil
        runtime.BodySelector = nil
    end

    if runtime.NotificationGui then
        safeDestroy(runtime.NotificationGui)
        runtime.NotificationGui = nil
    end

    if runtime.StartupGui then
        safeDestroy(runtime.StartupGui)
        runtime.StartupGui = nil
    end

    for i = #runtime.Connections, 1, -1 do
        local connection = runtime.Connections[i]
        pcall(function() connection:Disconnect() end)
        runtime.Connections[i] = nil
    end

    for i = #runtime.Drawings, 1, -1 do
        removeDrawing(runtime.Drawings[i])
        runtime.Drawings[i] = nil
    end
end

refreshLobbyState()

print("[XeroHub] MVSD cargado | AutoShoot Delay | Rapid Fire | Hitbox | ESP Lines/Skeleton | by Kev")
