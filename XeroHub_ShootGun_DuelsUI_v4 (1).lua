-- XeroHub | MVSD | Kev
-- UI portada desde DUELS + selector corporal 2D + configs + ESP de ronda + Silent Aim + FOV exclusivo de Silent Aim.
-- Método de Silent Aim: igual que Duels (Raycast/Mouse spoof), NO toca ShootGun:FireServer.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")

local player = Players.LocalPlayer
if not player then return end

local playerGui = player:WaitForChild("PlayerGui")
local mouse = player:GetMouse()
local runtimeEnv = (getgenv and getgenv()) or _G

-- Limpieza de versiones previas.
if runtimeEnv.__XERO_MVSD_HUB_CLEANUP then
    pcall(runtimeEnv.__XERO_MVSD_HUB_CLEANUP)
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

function runtime.Track(connection)
    if connection then
        runtime.Connections[#runtime.Connections + 1] = connection
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
    ESP = false,
    TeamCheck = true,

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
    for i = #runtime.PlayerList, 1, -1 do
        if runtime.PlayerList[i] == plr then
            runtime.PlayerList[i] = runtime.PlayerList[#runtime.PlayerList]
            runtime.PlayerList[#runtime.PlayerList] = nil
            break
        end
    end
end

runtime.Track(Players.PlayerAdded:Connect(addCachedPlayer))
runtime.Track(Players.PlayerRemoving:Connect(removeCachedPlayer))

runtime.CharacterCache = setmetatable({}, {__mode = "k"})

-- ==========================================
-- LOBBY / ROUND VALIDATION
-- ==========================================

local LOBBY_TEAM_WORDS = {
    "lobby", "spectator", "spectators", "spectating",
    "waiting", "intermission", "menu", "dead"
}

local function textContainsLobbyWord(text)
    text = string.lower(tostring(text or ""))
    for i = 1, #LOBBY_TEAM_WORDS do
        if string.find(text, LOBBY_TEAM_WORDS[i], 1, true) then
            return true
        end
    end
    return false
end

local function boolAttribute(object, name)
    if not object then return nil end
    local ok, value = pcall(function() return object:GetAttribute(name) end)
    if ok and type(value) == "boolean" then return value end
    return nil
end

local ROUND_TRUE_ATTRS = {
    "InRound", "InGame", "Playing", "IsPlaying", "RoundActive", "GameActive"
}
local LOBBY_TRUE_ATTRS = {
    "InLobby", "Lobby", "IsLobby", "Spectating", "IsSpectating"
}

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
    if not plr or plr == player then return false end
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

local function playerIsInActiveRound(plr, char, hrp)
    if not plr or plr == player or state.InLobby then
        return false
    end

    char = char or plr.Character
    if not char then return false end

    local hum = char:FindFirstChildOfClass("Humanoid")
    hrp = hrp or char:FindFirstChild("HumanoidRootPart")
    if not hum or hum.Health <= 0 or not hrp then
        return false
    end

    if char:FindFirstChildOfClass("ForceField") then
        return false
    end

    for i = 1, #LOBBY_TRUE_ATTRS do
        local attr = LOBBY_TRUE_ATTRS[i]
        if boolAttribute(plr, attr) == true or boolAttribute(char, attr) == true then
            return false
        end
    end

    local sawRoundFlag = false
    local roundFlagTrue = false

    for i = 1, #ROUND_TRUE_ATTRS do
        local attr = ROUND_TRUE_ATTRS[i]
        local pValue = boolAttribute(plr, attr)
        local cValue = boolAttribute(char, attr)

        if pValue ~= nil then
            sawRoundFlag = true
            roundFlagTrue = roundFlagTrue or pValue
        end
        if cValue ~= nil then
            sawRoundFlag = true
            roundFlagTrue = roundFlagTrue or cValue
        end
    end

    if sawRoundFlag and not roundFlagTrue then
        return false
    end

    if plr.Team and textContainsLobbyWord(plr.Team.Name) then
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

            if char and hum and hrp and playerIsInActiveRound(plr, char, hrp) then
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
-- SILENT AIM HOOK | MISMO MÉTODO QUE DUELS
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

local function removeESP(plr)
    local highlight = runtime.Highlights[plr]
    if highlight then
        safeDestroy(highlight)
        runtime.Highlights[plr] = nil
    end

    local billboard = runtime.Billboards[plr]
    if billboard then
        safeDestroy(billboard)
        runtime.Billboards[plr] = nil
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
end

local function hasESPText()
    return state.ESPName or state.ESPHealth or state.ESPDistance
end

local function ensureESP(plr)
    if not state.ESP or state.InLobby or not isEnemy(plr) then
        removeESP(plr)
        return
    end

    local char, hum, hrp = getCharacterData(plr)
    if not char or not hum or not hrp
        or not playerIsInActiveRound(plr, char, hrp)
    then
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
end))

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
-- MASTER LOOP
-- ==========================================

runtime.Track(RunService.Heartbeat:Connect(function(dt)
    if not runtime.Alive then return end

    state.LobbyTimer = state.LobbyTimer + dt
    if state.LobbyTimer >= 0.35 then
        state.LobbyTimer = 0

        local wasLobby = state.InLobby
        refreshLobbyState()

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
    Vis = MainSection:Tab({Title = "Visuales", Icon = "solar:eye-bold"}),
    Config = PersonalSection:Tab({Title = "Configuración", Icon = "solar:settings-bold"}),
    Creditos = PersonalSection:Tab({Title = "Créditos", Icon = "solar:user-bold"}),
}

local UIElements = {}

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

Tabs.Inicio:Paragraph({
    Title = "Bienvenido a XeroHub",
    Desc = "MVSD usa la misma base visual de DUELS, con controles organizados y selector corporal 2D.",
})

local executorName = identifyexecutor and identifyexecutor() or "Desconocido"
local accountPlan = "Free"
pcall(function()
    if player.MembershipType == Enum.MembershipType.Premium then
        accountPlan = "Premium"
    end
end)

Tabs.Inicio:Paragraph({
    Title = tostring(player.DisplayName),
    Desc = "@" .. tostring(player.Name)
        .. "\nEjecutor: " .. tostring(executorName)
        .. "\nCuenta: " .. tostring(player.AccountAge or 0) .. " días"
        .. "\nPlan: " .. tostring(accountPlan),
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

Tabs.Inicio:Section({Title = "Novedades de MVSD"})

Tabs.Inicio:Paragraph({
    Title = "Selector corporal 2D",
    Desc = "Silent Aim acepta varias partes simultáneas con caché por personaje.",
    Image = "solar:target-bold",
    ImageSize = 34,
    Color = Color3.fromHex("#20252C"),
})

Tabs.Inicio:Paragraph({
    Title = "Rendimiento",
    Desc = "FOV y wallcheck comparten el mismo target; ESP actualizado a baja frecuencia.",
    Image = "solar:bolt-bold",
    ImageSize = 34,
    Color = Color3.fromHex("#20252C"),
})

Tabs.Inicio:Section({Title = "Información del Servidor"})

local gameName = "Desconocido"
pcall(function()
    gameName = MarketplaceService:GetProductInfo(game.PlaceId).Name
end)

Tabs.Inicio:Paragraph({
    Title = "Juego Actual",
    Desc = tostring(gameName) .. "\nPlace ID: " .. tostring(game.PlaceId),
    Image = "rbxthumb://type=GameIcon&id=" .. tostring(game.GameId) .. "&w=150&h=150",
    ImageSize = 48,
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
    Desc = "Redirige el disparo a las partes seleccionadas mediante Raycast/Mouse spoof.",
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
    Desc = "Selecciona cabeza, torso, brazos y piernas con multiselección visual.",
    Callback = function()
        runtime.OpenBodySelector("SilentAim")
    end,
})

Tabs.Aim:Section({Title = "Campo de visión"})

UIElements.TogFOVFilter = Tabs.Aim:Toggle({
    Title = "Filtro de círculo FOV",
    Desc = "Solo Silent Aim limita sus objetivos al círculo.",
    Value = state.FOVFilter,
    Callback = function(value)
        state.FOVFilter = value
    end,
})

UIElements.TogShowFOV = Tabs.Aim:Toggle({
    Title = "Mostrar Círculo FOV",
    Desc = "Blanco sin candidato y verde cuando una parte seleccionada entra al círculo.",
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
    Desc = "Solo enemigos activos de la ronda; limpia lobby, spawn protegido y personajes lejanos.",
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
    Desc = "Relleno sin contorno para los enemigos válidos.",
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
    end,
})

UIElements.TogESPHealth = Tabs.Vis:Toggle({
    Title = "Mostrar Vida",
    Value = state.ESPHealth,
    Callback = function(value)
        state.ESPHealth = value
    end,
})

UIElements.TogESPDistance = Tabs.Vis:Toggle({
    Title = "Mostrar Distancia",
    Value = state.ESPDistance,
    Callback = function(value)
        state.ESPDistance = value
    end,
})


UIElements.ColESP = Tabs.Vis:Colorpicker({
    Title = "Color del ESP",
    Default = state.ESPColor,
    Callback = function(color)
        state.ESPColor = color
    end,
})


Tabs.Vis:Paragraph({
    Title = "Rendimiento",
    Desc = "El ESP actualiza a 10 Hz y reutiliza Highlight/Billboard; no crea objetos cada frame.",
})

-- ==========================================
-- CONFIGURACIÓN
-- ==========================================

Tabs.Config:Section({Title = "Personalización de Interfaz"})

Tabs.Config:Paragraph({
    Title = "Xero",
    Desc = "Negro, blanco y la misma base visual usada por DUELS.",
})

local currentInterfaceTheme = (Window.GetTheme and Window:GetTheme()) or "Xero"
runtime.InterfaceTheme = currentInterfaceTheme

UIElements.ThemeDropdown = Tabs.Config:Dropdown({
    Title = "Tema de Interfaz",
    Desc = "Cambia entre el tema oscuro de Xero y el tema blanco.",
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
    Desc = "Lo deja invisible pero conserva su zona para volver a abrir XeroHub.",
    Value = false,
    Callback = function(value)
        state.OpenButtonGhost = value == true
        if Window.SetOpenButtonGhosted then
            Window:SetOpenButtonGhosted(state.OpenButtonGhost)
        end
    end,
})

Tabs.Config:Section({Title = "Validación de partida"})

Tabs.Config:Paragraph({
    Title = "Lobby Guard",
    Desc = "Silent Aim y ESP sólo corren cuando MVSD expone Match + MatchStartTime y Neutral=false.",
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
    Desc = "Carga automáticamente la configuración seleccionada al ejecutar XeroHub.",
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
            ESP = state.ESP,
            FOVFilter = state.FOVFilter,
            ShowFOV = state.ShowFOV,
            ESPGlow = state.ESPGlow,
            ESPName = state.ESPName,
            ESPHealth = state.ESPHealth,
            ESPDistance = state.ESPDistance,
            OpenButtonGhost = state.OpenButtonGhost,
        },
        Sliders = {
            FOVRadius = state.FOVRadius,
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
    if toggles.OpenButtonGhost ~= nil then
        state.OpenButtonGhost = toggles.OpenButtonGhost == true
        setElement(UIElements.ToggleOpenButtonGhost, state.OpenButtonGhost)
    end

    if sliders.FOVRadius ~= nil then
        state.FOVRadius = tonumber(sliders.FOVRadius) or state.FOVRadius
        setElement(UIElements.SliFOV, state.FOVRadius)
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

    if not state.ESP then
        clearESP()
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
    Desc = "Borra la configuración seleccionada del gestor MVSD.",
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
    state.ESP = false
    aimHookState.Target = nil

    clearESP()

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

print("[XeroHub] MVSD cargado | Silent estable | Match State real | Team Check fijo | ESP sin límite de distancia")
