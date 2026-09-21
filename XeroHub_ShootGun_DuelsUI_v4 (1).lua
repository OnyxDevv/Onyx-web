-- XeroHub | ShootGun v2 | Kev
-- UI Duels + ESP de partida + Silent Aim Duels-style + AutoShoot independiente del FOV + FOV centrado
-- NO modifica ShootGun:FireServer.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
if not player then return end

local playerGui = player:WaitForChild("PlayerGui")
local mouse = player:GetMouse()
local runtimeEnv = (getgenv and getgenv()) or _G

-- Limpieza de versiones anteriores.
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
    Tool = nil,
    ToolActivatedConnection = nil,
    TargetCache = {
        SilentAim = setmetatable({}, {__mode = "k"}),
        AutoShoot = setmetatable({}, {__mode = "k"}),
    },
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

local state = {
    SilentAim = false,
    AutoShoot = false,
    ESP = false,
    TeamCheck = true,

    FOVEnabled = true,
    ShowFOV = true,
    FOVRadius = 140,

    -- No pinta a gente del otro extremo del servidor.
    ESPMaxDistance = 650,
    TargetMaxDistance = 800,

    InLobby = true,
    LobbyReason = "Inicializando",
    LobbyTimer = 1,

    SilentTarget = nil,
    SilentTargetPlayer = nil,
    AutoTarget = nil,
    AutoTargetPlayer = nil,

    SilentAccumulator = 0,
    AutoAccumulator = 0,
    ESPAccumulator = 0,
    AutoShootInterval = 0.15,

    -- El hook sólo se activa alrededor de un disparo real.
    ShotGateUntil = 0,
    LastAutoShotAt = 0,
}

-- ==========================================
-- SELECTOR CORPORAL (MISMO CONCEPTO DE DUELS)
-- ==========================================

runtime.TargetBodyOrder = {
    "Cabeza",
    "Torso superior",
    "Torso inferior",
    "Brazo izquierdo",
    "Brazo derecho",
    "Pierna izquierda",
    "Pierna derecha",
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
    AutoShoot = {["Cabeza"] = true},
}

runtime.TargetSelectionVersion = {
    SilentAim = 1,
    AutoShoot = 1,
}

function runtime.GetTargetSelectionArray(mode)
    local result = {}
    local selected = runtime.TargetSelections[mode] or {}

    for _, name in ipairs(runtime.TargetBodyOrder) do
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

    if type(value) == "table" then
        for _, name in ipairs(value) do
            if runtime.TargetBodyGroups[name] then
                selected[name] = true
            end
        end
    elseif type(value) == "string" and runtime.TargetBodyGroups[value] then
        selected[value] = true
    end

    if not next(selected) then
        selected["Cabeza"] = true
    end

    runtime.TargetSelectionVersion[mode] =
        (runtime.TargetSelectionVersion[mode] or 0) + 1

    runtime.TargetCache[mode] =
        setmetatable({}, {__mode = "k"})

    if runtime.BodySelector and runtime.BodySelector.Refresh then
        runtime.BodySelector.Refresh()
    end
end

local function resolveActualHitbox(bodyPart)
    if not bodyPart then return nil end

    -- En este juego ShootGun usa Head.Part / UpperTorso.Part / RightLowerLeg.Part.
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

    local version = runtime.TargetSelectionVersion[mode] or 1
    local modeCache = runtime.TargetCache[mode]
    local cached = modeCache and modeCache[char]

    if cached and cached.Version == version then
        local valid = true

        for i = 1, #cached.Parts do
            local part = cached.Parts[i]
            if not part or not part.Parent then
                valid = false
                break
            end
        end

        if valid then
            return cached.Parts
        end
    end

    local result = {}
    local seen = {}
    local selected = runtime.TargetSelections[mode] or {}

    for _, groupName in ipairs(runtime.TargetBodyOrder) do
        if selected[groupName] then
            local names = runtime.TargetBodyGroups[groupName]

            for i = 1, #names do
                local bodyPart = char:FindFirstChild(names[i])
                local hitbox = resolveActualHitbox(bodyPart)

                if hitbox and not seen[hitbox] then
                    seen[hitbox] = true
                    result[#result + 1] = hitbox
                end
            end
        end
    end

    if #result == 0 then
        local fallback =
            resolveActualHitbox(char:FindFirstChild("Head"))
            or char:FindFirstChild("HumanoidRootPart")

        if fallback then result[1] = fallback end
    end

    if modeCache then
        modeCache[char] = {
            Version = version,
            Parts = result,
        }
    end

    return result
end

-- ==========================================
-- LOBBY / PARTIDA
-- ==========================================

local LOBBY_TEAM_WORDS = {
    "lobby", "spectator", "spectators", "spectating",
    "waiting", "intermission", "menu", "dead"
}

local ROUND_TRUE_ATTRS = {
    "InRound", "InGame", "Playing", "IsPlaying",
    "RoundActive", "GameActive"
}

local LOBBY_TRUE_ATTRS = {
    "InLobby", "Lobby", "IsLobby",
    "Spectating", "IsSpectating"
}

local function containsLobbyWord(text)
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

    local ok, value = pcall(function()
        return object:GetAttribute(name)
    end)

    if ok and type(value) == "boolean" then
        return value
    end

    return nil
end

local function playerLobbyState(plr)
    local char = plr and plr.Character
    if not char then return true, "Sin personaje" end

    local hum = char:FindFirstChildOfClass("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")

    if not hum or hum.Health <= 0 or not hrp then
        return true, "Fuera de partida"
    end

    if char:FindFirstChildOfClass("ForceField") then
        return true, "ForceField"
    end

    for i = 1, #LOBBY_TRUE_ATTRS do
        local attr = LOBBY_TRUE_ATTRS[i]

        if boolAttribute(plr, attr) == true
            or boolAttribute(char, attr) == true
        then
            return true, attr
        end
    end

    for i = 1, #ROUND_TRUE_ATTRS do
        local attr = ROUND_TRUE_ATTRS[i]
        local pValue = boolAttribute(plr, attr)
        local cValue = boolAttribute(char, attr)

        if pValue ~= nil then
            return not pValue, attr
        end

        if cValue ~= nil then
            return not cValue, attr
        end
    end

    if plr.Team and containsLobbyWord(plr.Team.Name) then
        return true, "Team " .. plr.Team.Name
    end

    return false, "Partida"
end

local function refreshLobbyState()
    local inLobby, reason = playerLobbyState(player)

    state.InLobby = inLobby
    state.LobbyReason = reason

    if inLobby then
        state.SilentTarget = nil
        state.SilentTargetPlayer = nil
        state.AutoTarget = nil
        state.AutoTargetPlayer = nil
    end
end

-- ==========================================
-- ENEMIES
-- ==========================================

local function isEnemy(targetPlayer)
    if not targetPlayer or targetPlayer == player then
        return false
    end

    if not state.TeamCheck then
        return true
    end

    if player.Team ~= nil and targetPlayer.Team ~= nil then
        return player.Team ~= targetPlayer.Team
    end

    local pAttr =
        player:GetAttribute("Team")
        or player:GetAttribute("team")

    local tAttr =
        targetPlayer:GetAttribute("Team")
        or targetPlayer:GetAttribute("team")

    if pAttr ~= nil and tAttr ~= nil then
        return pAttr ~= tAttr
    end

    if player.TeamColor
        and targetPlayer.TeamColor
        and player.TeamColor.Name ~= "White"
        and player.TeamColor.Name ~= "Medium stone grey"
    then
        return player.TeamColor ~= targetPlayer.TeamColor
    end

    return true
end

local function getCharacterData(plr)
    local char = plr and plr.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local hrp = char and char:FindFirstChild("HumanoidRootPart")

    if not char or not hum or hum.Health <= 0 or not hrp then
        return nil
    end

    return char, hum, hrp
end

local function targetIsActuallyInMatch(targetPlayer, distance)
    if not isEnemy(targetPlayer) then
        return false
    end

    local inLobby = playerLobbyState(targetPlayer)
    if inLobby then
        return false
    end

    if distance and distance > state.TargetMaxDistance then
        return false
    end

    return true
end

-- ==========================================
-- TOOL CACHE / SHOT GATE
-- ==========================================

local function currentTool()
    local char = player.Character
    return char and char:FindFirstChildOfClass("Tool")
end

function runtime.OpenShotGate(duration)
    state.ShotGateUntil =
        math.max(
            state.ShotGateUntil or 0,
            os.clock() + (duration or 0.20)
        )
end

function runtime.BindTool(tool)
    if runtime.ToolActivatedConnection then
        pcall(function()
            runtime.ToolActivatedConnection:Disconnect()
        end)
        runtime.ToolActivatedConnection = nil
    end

    runtime.Tool = tool

    if tool then
        runtime.ToolActivatedConnection =
            runtime.Track(
                tool.Activated:Connect(function()
                    runtime.OpenShotGate(0.22)
                end)
            )
    end
end

local function refreshTool()
    local tool = currentTool()

    if tool ~= runtime.Tool then
        runtime.BindTool(tool)
    end

    return tool
end

runtime.Track(player.CharacterAdded:Connect(function(char)
    runtime.BindTool(nil)

    runtime.Track(char.ChildAdded:Connect(function(child)
        if child:IsA("Tool") then
            runtime.BindTool(child)
        end
    end))

    runtime.Track(char.ChildRemoved:Connect(function(child)
        if child == runtime.Tool then
            runtime.BindTool(char:FindFirstChildOfClass("Tool"))
        end
    end))
end))

if player.Character then
    runtime.Track(player.Character.ChildAdded:Connect(function(child)
        if child:IsA("Tool") then
            runtime.BindTool(child)
        end
    end))

    runtime.Track(player.Character.ChildRemoved:Connect(function(child)
        if child == runtime.Tool then
            runtime.BindTool(player.Character:FindFirstChildOfClass("Tool"))
        end
    end))

    runtime.BindTool(currentTool())
end

-- PC + móvil: abre el hook un instante justo cuando empieza una entrada de disparo.
runtime.Track(UserInputService.InputBegan:Connect(function(input, processed)
    if processed or state.InLobby then return end
    if not (state.SilentAim or state.AutoShoot) then return end
    if not refreshTool() then return end

    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch
    then
        runtime.OpenShotGate(0.18)
    end
end))

local function aimHookCallAllowed()
    if os.clock() <= (state.ShotGateUntil or 0) then
        return true
    end

    -- Si el ejecutor sabe quién hizo la llamada, sólo confiamos en scripts
    -- obviamente asociados al arma.
    if type(getcallingscript) == "function" then
        local ok, caller = pcall(getcallingscript)

        if ok and caller then
            local tool = runtime.Tool

            if tool and caller:IsDescendantOf(tool) then
                return true
            end

            local name = string.lower(caller.Name)
            if string.find(name, "gun", 1, true)
                or string.find(name, "shoot", 1, true)
                or string.find(name, "weapon", 1, true)
                or string.find(name, "bullet", 1, true)
            then
                return true
            end
        end
    end

    return false
end

-- ==========================================
-- TARGET SELECTION / FOV
-- ==========================================

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = true
local rayIgnore = {}

local function visibleTarget(localChar, enemyChar, targetPart, origin)
    rayIgnore[1] = localChar
    rayIgnore[2] = enemyChar
    rayParams.FilterDescendantsInstances = rayIgnore

    local delta = targetPart.Position - origin
    if delta.Magnitude <= 0.01 then return true end

    return workspace:Raycast(origin, delta, rayParams) == nil
end

local function chooseTarget(mode, useFOV)
    if state.InLobby then return nil, nil end

    local camera = workspace.CurrentCamera
    local localChar = player.Character
    local localHum = localChar and localChar:FindFirstChildOfClass("Humanoid")
    local localRoot = localChar and localChar:FindFirstChild("HumanoidRootPart")
    local localHead = localChar and localChar:FindFirstChild("Head")

    if not camera
        or not localChar
        or not localHum
        or localHum.Health <= 0
        or not localRoot
        or not refreshTool()
    then
        return nil, nil
    end

    local origin =
        localHead and localHead.Position
        or localRoot.Position

    local viewport = camera.ViewportSize
    local centerX = viewport.X * 0.5
    local centerY = viewport.Y * 0.5
    local fovSq = state.FOVRadius * state.FOVRadius

    local bestPlayer, bestPart
    local bestMetric = math.huge

    for _, targetPlayer in ipairs(Players:GetPlayers()) do
        if targetPlayer ~= player and isEnemy(targetPlayer) then
            local char, hum, hrp =
                getCharacterData(targetPlayer)

            if char and hum and hrp then
                local deltaRoot =
                    hrp.Position - localRoot.Position

                local distanceSq =
                    deltaRoot:Dot(deltaRoot)

                local maxDistanceSq =
                    state.TargetMaxDistance
                    * state.TargetMaxDistance

                if distanceSq <= maxDistanceSq
                    and targetIsActuallyInMatch(
                        targetPlayer,
                        math.sqrt(distanceSq)
                    )
                then
                    local parts =
                        runtime.CollectTargetParts(
                            char,
                            mode
                        )

                    for i = 1, #parts do
                        local part = parts[i]

                        if part and part.Parent then
                            local metric
                            local passes = true

                            local shouldUseFOV = useFOV
                            if shouldUseFOV == nil then
                                shouldUseFOV = state.FOVEnabled
                            end

                            if shouldUseFOV then
                                local point, onScreen =
                                    camera:WorldToViewportPoint(
                                        part.Position
                                    )

                                if not onScreen or point.Z <= 0 then
                                    passes = false
                                else
                                    local dx =
                                        point.X - centerX

                                    local dy =
                                        point.Y - centerY

                                    metric =
                                        dx * dx + dy * dy

                                    if metric > fovSq then
                                        passes = false
                                    end
                                end
                            else
                                local delta =
                                    part.Position
                                    - localRoot.Position

                                metric = delta:Dot(delta)
                            end

                            if passes
                                and metric < bestMetric
                                and visibleTarget(
                                    localChar,
                                    char,
                                    part,
                                    origin
                                )
                            then
                                bestMetric = metric
                                bestPlayer = targetPlayer
                                bestPart = part
                            end
                        end
                    end
                end
            end
        end
    end

    return bestPlayer, bestPart
end


local function silentHasVisiblePartInsideFOV()
    if not state.SilentAim
        or not state.FOVEnabled
        or state.InLobby
    then
        return false
    end

    local camera = workspace.CurrentCamera
    local localChar = player.Character
    local localHum = localChar and localChar:FindFirstChildOfClass("Humanoid")
    local localRoot = localChar and localChar:FindFirstChild("HumanoidRootPart")
    local localHead = localChar and localChar:FindFirstChild("Head")

    if not camera
        or not localChar
        or not localHum
        or localHum.Health <= 0
        or not localRoot
        or not refreshTool()
    then
        return false
    end

    local origin = localHead and localHead.Position or localRoot.Position
    local viewport = camera.ViewportSize
    local centerX = viewport.X * 0.5
    local centerY = viewport.Y * 0.5
    local fovSq = state.FOVRadius * state.FOVRadius
    local maxDistanceSq = state.TargetMaxDistance * state.TargetMaxDistance

    for _, targetPlayer in ipairs(Players:GetPlayers()) do
        if targetPlayer ~= player and isEnemy(targetPlayer) then
            local char, hum, hrp = getCharacterData(targetPlayer)

            if char and hum and hrp then
                local rootDelta = hrp.Position - localRoot.Position
                local distanceSq = rootDelta:Dot(rootDelta)

                if distanceSq <= maxDistanceSq
                    and targetIsActuallyInMatch(targetPlayer, math.sqrt(distanceSq))
                then
                    local parts = runtime.CollectTargetParts(char, "SilentAim")

                    for i = 1, #parts do
                        local part = parts[i]

                        if part and part.Parent then
                            local point, onScreen = camera:WorldToViewportPoint(part.Position)

                            if onScreen and point.Z > 0 then
                                local dx = point.X - centerX
                                local dy = point.Y - centerY

                                if (dx * dx + dy * dy) <= fovSq
                                    and visibleTarget(localChar, char, part, origin)
                                then
                                    return true
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    return false
end

-- ==========================================
-- SILENT AIM HOOK
-- Sólo se activa alrededor del disparo para NO TOCAR la cámara/zoom.
-- ==========================================

-- Neutraliza el hook de la versión anterior sin volver a darle targets.
-- Ese hook queda instalado por el executor, pero con Target=nil se vuelve pass-through.
local legacyAimHookState =
    runtimeEnv.__XERO_SHOOTGUN_DUELS_STYLE_AIM_STATE

if legacyAimHookState then
    legacyAimHookState.Target = nil
end

local aimHookState =
    runtimeEnv.__XERO_SHOOTGUN_DUELS_STYLE_AIM_STATE_V2

if not aimHookState then
    aimHookState = {
        Target = nil,
        Mouse = mouse,
    }

    runtimeEnv.__XERO_SHOOTGUN_DUELS_STYLE_AIM_STATE_V2 =
        aimHookState

    local oldNamecall

    oldNamecall =
        hookmetamethod(
            game,
            "__namecall",
            function(self, ...)
                local target =
                    aimHookState.Target

                if not checkcaller()
                    and target
                    and target.Parent
                    and aimHookCallAllowed()
                then
                    local method =
                        getnamecallmethod()

                    if self == workspace then
                        if method == "Raycast" then
                            local origin, direction, params =
                                ...

                            if typeof(origin) == "Vector3"
                                and typeof(direction) == "Vector3"
                                and direction.Magnitude > 5
                            then
                                local camera =
                                    workspace.CurrentCamera

                                -- Conservamos también la protección de Duels.
                                if not camera
                                    or (
                                        origin
                                        - camera.CFrame.Position
                                    ).Magnitude > 1
                                then
                                    local delta =
                                        target.Position - origin

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
                            local ray, p2, p3, p4 =
                                ...

                            if typeof(ray) == "Ray"
                                and ray.Direction.Magnitude > 5
                            then
                                local camera =
                                    workspace.CurrentCamera

                                if not camera
                                    or (
                                        ray.Origin
                                        - camera.CFrame.Position
                                    ).Magnitude > 1
                                then
                                    local delta =
                                        target.Position
                                        - ray.Origin

                                    if delta.Magnitude > 0.01 then
                                        return oldNamecall(
                                            self,
                                            Ray.new(
                                                ray.Origin,
                                                delta.Unit * 5000
                                            ),
                                            p2,
                                            p3,
                                            p4
                                        )
                                    end
                                end
                            end
                        end
                    end
                elseif target and not target.Parent then
                    aimHookState.Target = nil
                end

                return oldNamecall(self, ...)
            end
        )

    local oldIndex

    oldIndex =
        hookmetamethod(
            game,
            "__index",
            function(object, key)
                local target =
                    aimHookState.Target

                if not checkcaller()
                    and object == aimHookState.Mouse
                    and target
                    and target.Parent
                    and aimHookCallAllowed()
                then
                    if key == "Hit" or key == "hit" then
                        return target.CFrame

                    elseif key == "Target"
                        or key == "target"
                    then
                        return target
                    end
                end

                return oldIndex(object, key)
            end
        )
else
    aimHookState.Target = nil
    aimHookState.Mouse = mouse
end

-- ==========================================
-- AUTOSHOOT | TOOL REAL (SIN SIMULAR CLIC)
-- ==========================================

local function fireCurrentGun(tool, targetPart)
    if not tool
        or not tool.Parent
        or not targetPart
        or not targetPart.Parent
    then
        return false
    end

    -- Igual que la versión que sí usábamos antes:
    -- fijamos primero el target del Silent y dejamos que el Tool real dispare.
    aimHookState.Target = targetPart
    runtime.OpenShotGate(0.25)

    local ok = pcall(function()
        tool:Activate()

        task.delay(0.025, function()
            if runtime.Alive
                and tool
                and tool.Parent == player.Character
            then
                pcall(function()
                    tool:Deactivate()
                end)
            end
        end)
    end)

    return ok
end

-- ==========================================
-- ESP DE PARTIDA
-- ==========================================

local function removeESP(targetPlayer)
    if runtime.Highlights[targetPlayer] then
        safeDestroy(runtime.Highlights[targetPlayer])
        runtime.Highlights[targetPlayer] = nil
    end

    if runtime.Billboards[targetPlayer] then
        safeDestroy(runtime.Billboards[targetPlayer])
        runtime.Billboards[targetPlayer] = nil
    end
end

local function clearESP()
    local players = {}

    for targetPlayer in pairs(runtime.Highlights) do
        players[#players + 1] = targetPlayer
    end

    for i = 1, #players do
        removeESP(players[i])
    end
end

local function shouldShowESP(targetPlayer)
    if not state.ESP
        or state.InLobby
        or not isEnemy(targetPlayer)
    then
        return false
    end

    local char, hum, hrp =
        getCharacterData(targetPlayer)

    local myRoot =
        player.Character
        and player.Character:FindFirstChild(
            "HumanoidRootPart"
        )

    if not char or not hum or not hrp or not myRoot then
        return false
    end

    local distance =
        (hrp.Position - myRoot.Position).Magnitude

    -- Primero distancia: evita pintar literalmente todo el servidor.
    if distance > state.ESPMaxDistance then
        return false
    end

    local targetInLobby =
        playerLobbyState(targetPlayer)

    if targetInLobby then
        return false
    end

    return true, char, hum, hrp, distance
end

local function ensureESP(targetPlayer)
    local visible, char, hum, hrp, distance =
        shouldShowESP(targetPlayer)

    if not visible then
        removeESP(targetPlayer)
        return
    end

    local highlight =
        runtime.Highlights[targetPlayer]

    if not highlight
        or not highlight.Parent
    then
        highlight =
            Instance.new("Highlight")

        highlight.Name =
            "XeroEnemyESP"

        highlight.FillColor =
            Color3.fromRGB(255, 255, 255)

        highlight.FillTransparency = 0.72
        highlight.OutlineTransparency = 1

        highlight.DepthMode =
            Enum.HighlightDepthMode.AlwaysOnTop

        highlight.Adornee = char

        -- Fuera del Character, igual que Duels.
        highlight.Parent = ReplicatedStorage

        runtime.Highlights[targetPlayer] =
            highlight
    else
        highlight.Adornee = char
        highlight.Enabled = true
    end

    local billboard =
        runtime.Billboards[targetPlayer]

    if not billboard
        or not billboard.Parent
    then
        billboard =
            Instance.new("BillboardGui")

        billboard.Name =
            "XeroEnemyInfo"

        billboard.Size =
            UDim2.fromOffset(180, 38)

        billboard.StudsOffset =
            Vector3.new(0, 3.3, 0)

        billboard.AlwaysOnTop = true
        billboard.Adornee = hrp
        billboard.Parent = playerGui

        local label =
            Instance.new("TextLabel")

        label.Name = "Info"
        label.Size = UDim2.fromScale(1, 1)
        label.BackgroundTransparency = 1

        label.TextColor3 =
            Color3.fromRGB(245,245,245)

        label.TextStrokeTransparency = 0.45
        label.Font = Enum.Font.GothamMedium
        label.TextSize = 12
        label.Parent = billboard

        runtime.Billboards[targetPlayer] =
            billboard
    else
        billboard.Adornee = hrp
    end

    local label =
        billboard:FindFirstChild("Info")

    if label then
        label.Text =
            string.format(
                "%s  |  %d HP  |  %dm",
                targetPlayer.Name,
                math.max(
                    0,
                    math.floor(hum.Health + 0.5)
                ),
                math.floor(distance + 0.5)
            )
    end
end

runtime.Track(
    Players.PlayerRemoving:Connect(
        removeESP
    )
)

-- ==========================================
-- FOV VERDE CENTRADO
-- ==========================================

local FOVCircle = nil

if Drawing and Drawing.new then
    FOVCircle =
        runtime.TrackDrawing(
            Drawing.new("Circle")
        )

    FOVCircle.Filled = false
    FOVCircle.Color =
        Color3.fromRGB(255, 255, 255)

    FOVCircle.Visible = false
    FOVCircle.Thickness = 2.5
    FOVCircle.NumSides = 96
    FOVCircle.Transparency = 0.9
end

local function updateFOVCircle()
    if not FOVCircle then return end

    local camera = workspace.CurrentCamera

    -- El círculo pertenece solamente al Silent Aim.
    local visible =
        state.ShowFOV
        and not state.InLobby
        and state.SilentAim
        and state.FOVEnabled

    FOVCircle.Visible = visible

    if visible and camera then
        local viewport = camera.ViewportSize

        FOVCircle.Position =
            Vector2.new(
                viewport.X * 0.5,
                viewport.Y * 0.5
            )

        FOVCircle.Radius = state.FOVRadius

        -- Verde ÚNICAMENTE si una de las partes seleccionadas del Silent
        -- está visible y dentro del círculo.
        if silentHasVisiblePartInsideFOV() then
            FOVCircle.Color =
                Color3.fromRGB(0, 255, 0)
        else
            FOVCircle.Color =
                Color3.fromRGB(255, 255, 255)
        end
    end
end

-- ==========================================
-- MASTER LOOP
-- ==========================================

runtime.Track(
    RunService.Heartbeat:Connect(function(dt)
        if not runtime.Alive then return end

        state.LobbyTimer =
            state.LobbyTimer + dt

        if state.LobbyTimer >= 0.35 then
            state.LobbyTimer = 0
            local oldLobby = state.InLobby
            refreshLobbyState()

            if state.InLobby and not oldLobby then
                aimHookState.Target = nil
                clearESP()
            end
        end

        -- Silent target.
        if state.SilentAim then
            state.SilentAccumulator =
                state.SilentAccumulator + dt

            if state.SilentAccumulator >= 0.03 then
                state.SilentAccumulator = 0

                if not state.InLobby then
                    local targetPlayer, part =
                        chooseTarget("SilentAim", state.FOVEnabled)

                    state.SilentTargetPlayer =
                        targetPlayer

                    state.SilentTarget =
                        part

                    if not state.AutoShoot then
                        aimHookState.Target = part
                    end
                else
                    state.SilentTargetPlayer = nil
                    state.SilentTarget = nil

                    if not state.AutoShoot then
                        aimHookState.Target = nil
                    end
                end
            end
        else
            state.SilentAccumulator = 0
            state.SilentTargetPlayer = nil
            state.SilentTarget = nil

            if not state.AutoShoot then
                aimHookState.Target = nil
            end
        end

        -- AutoShoot.
        if state.AutoShoot then
            state.AutoAccumulator =
                state.AutoAccumulator + dt

            if state.AutoAccumulator
                >= state.AutoShootInterval
            then
                state.AutoAccumulator = 0

                if not state.InLobby then
                    local tool = refreshTool()
                    local targetPlayer, part =
                        chooseTarget("AutoShoot", false)

                    state.AutoTargetPlayer =
                        targetPlayer

                    state.AutoTarget =
                        part

                    if tool and part then
                        state.LastAutoShotAt =
                            os.clock()

                        fireCurrentGun(
                            tool,
                            part
                        )
                    else
                        if state.SilentAim then
                            aimHookState.Target =
                                state.SilentTarget
                        else
                            aimHookState.Target = nil
                        end
                    end
                else
                    state.AutoTargetPlayer = nil
                    state.AutoTarget = nil
                    aimHookState.Target = nil
                end
            end
        else
            state.AutoAccumulator = 0
            state.AutoTargetPlayer = nil
            state.AutoTarget = nil

            if state.SilentAim then
                aimHookState.Target =
                    state.SilentTarget
            else
                aimHookState.Target = nil
            end
        end

        -- ESP ~20 Hz.
        state.ESPAccumulator =
            state.ESPAccumulator + dt

        if state.ESPAccumulator >= 0.05 then
            state.ESPAccumulator = 0

            if state.ESP and not state.InLobby then
                for _, targetPlayer in ipairs(
                    Players:GetPlayers()
                ) do
                    if targetPlayer ~= player then
                        ensureESP(targetPlayer)
                    end
                end
            else
                clearESP()
            end
        end
    end)
)

runtime.Track(
    RunService.RenderStepped:Connect(
        updateFOVCircle
    )
)

-- ==========================================
-- UI DUELS
-- ==========================================

local WindUI
local NOX_UI_URL =
    runtimeEnv.NOX_UI_URL
    or "https://raw.githubusercontent.com/OnyxDevv/Onyx-web/refs/heads/main/main%20(3).lua"

local okUI, resultUI =
    pcall(function()
        local source

        if isfile
            and readfile
            and isfile("XeroHub_UI.lua")
        then
            source =
                readfile("XeroHub_UI.lua")
        else
            source =
                game:HttpGet(NOX_UI_URL)
        end

        local chunk, compileError =
            loadstring(source)

        if not chunk then
            error(
                "No se pudo compilar UI: "
                .. tostring(compileError)
            )
        end

        return chunk()
    end)

if not okUI or not resultUI then
    warn("[XeroHub] UI error:", resultUI)
    return
end

WindUI = resultUI

local Window = WindUI:CreateWindow({
    Title = "Xero | SHOOTGUN",
    Subtitle = "SHOOTGUN",
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

local MainSection =
    Window:Section({
        Title = "PRINCIPAL",
        Opened = true,
    })

local TrollSection =
    Window:Section({
        Title = "PERSONAL",
        Opened = true,
    })

local Tabs = {
    Inicio = MainSection:Tab({
        Title = "Inicio",
        Icon = "solar:home-bold",
    }),

    Aim = MainSection:Tab({
        Title = "Aimbot",
        Icon = "solar:target-bold",
    }),

    Vis = MainSection:Tab({
        Title = "Visuales",
        Icon = "solar:eye-bold",
    }),

    Config = TrollSection:Tab({
        Title = "Configuración",
        Icon = "solar:settings-bold",
    }),

    Creditos = TrollSection:Tab({
        Title = "Créditos",
        Icon = "solar:user-bold",
    }),
}

local UIElements = {}

Tabs.Inicio:Paragraph({
    Title = "XeroHub",
    Desc = "ShootGun · Silent Aim, Auto Shoot y ESP.",
})

local lobbyParagraph =
    Tabs.Inicio:Paragraph({
        Title = "Estado",
        Desc = "Comprobando partida...",
    })

-- ==========================================
-- SELECTOR CORPORAL 2D (PORTADO DE DUELS)
-- ==========================================

function runtime.EnsureBodySelector()
    if runtime.BodySelectorGui
        and runtime.BodySelectorGui.Parent
    then
        return
    end

    local parent = playerGui

    pcall(function()
        parent =
            gethui and gethui()
            or game:GetService("CoreGui")
    end)

    local gui =
        Instance.new("ScreenGui")

    gui.Name = "Xero_BodySelector"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.DisplayOrder = 2147483647
    gui.ZIndexBehavior =
        Enum.ZIndexBehavior.Sibling

    pcall(function()
        gui.ScreenInsets =
            Enum.ScreenInsets.None

        gui.ClipToDeviceSafeArea =
            false

        gui.SafeAreaCompatibility =
            Enum.SafeAreaCompatibility.None
    end)

    gui.Parent = parent
    runtime.BodySelectorGui = gui

    local overlay =
        Instance.new("Frame")

    overlay.Size =
        UDim2.fromScale(1, 1)

    overlay.BackgroundColor3 =
        Color3.fromRGB(0, 0, 0)

    overlay.BackgroundTransparency =
        0.36

    overlay.Visible = false
    overlay.Active = true
    overlay.ZIndex = 400
    overlay.Parent = gui

    local card =
        Instance.new("CanvasGroup")

    card.AnchorPoint =
        Vector2.new(0.5, 0.5)

    card.Position =
        UDim2.fromScale(0.5, 0.5)

    card.Size =
        UDim2.fromOffset(440, 360)

    card.BackgroundColor3 =
        Color3.fromRGB(17, 18, 20)

    card.BorderSizePixel = 0
    card.ZIndex = 401
    card.Parent = overlay

    Instance.new(
        "UICorner",
        card
    ).CornerRadius =
        UDim.new(0, 22)

    local cardStroke =
        Instance.new("UIStroke")

    cardStroke.Color =
        Color3.fromRGB(94, 99, 106)

    cardStroke.Transparency = 0.35
    cardStroke.Parent = card

    local scale =
        Instance.new("UIScale")

    scale.Scale = 1
    scale.Parent = card

    local title =
        Instance.new("TextLabel")

    title.Size =
        UDim2.new(1, -88, 0, 24)

    title.Position =
        UDim2.fromOffset(18, 14)

    title.BackgroundTransparency = 1
    title.Text = "Selector corporal"
    title.TextColor3 =
        Color3.fromRGB(247,248,249)

    title.Font = Enum.Font.GothamBold
    title.TextSize = 15
    title.TextXAlignment =
        Enum.TextXAlignment.Left

    title.ZIndex = 402
    title.Parent = card

    local closeButton =
        Instance.new("TextButton")

    closeButton.Size =
        UDim2.fromOffset(28, 28)

    closeButton.Position =
        UDim2.new(1, -42, 0, 12)

    closeButton.BackgroundColor3 =
        Color3.fromRGB(37,39,43)

    closeButton.BorderSizePixel = 0
    closeButton.Text = "×"
    closeButton.TextColor3 =
        Color3.fromRGB(231,231,231)

    closeButton.Font = Enum.Font.GothamBold
    closeButton.TextSize = 16
    closeButton.ZIndex = 405
    closeButton.Parent = card

    Instance.new(
        "UICorner",
        closeButton
    ).CornerRadius =
        UDim.new(0, 9)

    local subtitle =
        Instance.new("TextLabel")

    subtitle.Size =
        UDim2.new(1, -36, 0, 28)

    subtitle.Position =
        UDim2.fromOffset(18, 39)

    subtitle.BackgroundTransparency = 1
    subtitle.Text =
        "Toca varias zonas del cuerpo. Las partes activas se iluminan al instante."

    subtitle.TextColor3 =
        Color3.fromRGB(157,163,171)

    subtitle.Font = Enum.Font.Gotham
    subtitle.TextSize = 10
    subtitle.TextWrapped = true
    subtitle.TextXAlignment =
        Enum.TextXAlignment.Left

    subtitle.ZIndex = 402
    subtitle.Parent = card

    local figure =
        Instance.new("Frame")

    figure.Size =
        UDim2.fromOffset(160, 220)

    figure.Position =
        UDim2.fromOffset(18, 74)

    figure.BackgroundColor3 =
        Color3.fromRGB(9,10,12)

    figure.BackgroundTransparency = 0.08
    figure.BorderSizePixel = 0
    figure.ZIndex = 402
    figure.Parent = card

    Instance.new(
        "UICorner",
        figure
    ).CornerRadius =
        UDim.new(0, 14)

    runtime.BodySelector = {
        Mode = "AutoShoot",
        Segments = {},
        Rows = {},
        Overlay = overlay,
        Card = card,
        Scale = scale,
        Title = title,
        Subtitle = subtitle,
        CloseButton = closeButton,
        Figure = figure,
    }

    closeButton.Activated:Connect(function()
        overlay.Visible = false
    end)

    local function toggle(name)
        local selected =
            runtime.TargetSelections[
                runtime.BodySelector.Mode
            ]

        selected[name] =
            not selected[name]
            or nil

        runtime.BodySelector.Refresh()
    end

    local function segment(
        name,
        x,
        y,
        w,
        h,
        radius
    )
        local button =
            Instance.new("TextButton")

        button.Name = name
        button.Size =
            UDim2.fromOffset(w, h)

        button.Position =
            UDim2.fromOffset(x, y)

        button.BackgroundColor3 =
            Color3.fromRGB(36,38,42)

        button.BorderSizePixel = 0
        button.Text = ""
        button.AutoButtonColor = false
        button.ZIndex = 404
        button.Parent = figure

        Instance.new(
            "UICorner",
            button
        ).CornerRadius =
            UDim.new(0, radius or 10)

        local stroke =
            Instance.new("UIStroke")

        stroke.Color =
            Color3.fromRGB(75,80,87)

        stroke.Transparency = 0.35
        stroke.Parent = button

        runtime.BodySelector.Segments[name] = {
            Button = button,
            Stroke = stroke,
        }

        button.Activated:Connect(function()
            toggle(name)
        end)
    end

    segment("Cabeza", 59, 8, 42, 42, 21)
    segment("Torso superior", 46, 55, 68, 45, 11)
    segment("Torso inferior", 50, 104, 60, 32, 9)
    segment("Brazo izquierdo", 20, 58, 20, 78, 10)
    segment("Brazo derecho", 120, 58, 20, 78, 10)
    segment("Pierna izquierda", 49, 143, 25, 66, 11)
    segment("Pierna derecha", 86, 143, 25, 66, 11)

    local list =
        Instance.new("ScrollingFrame")

    list.Size =
        UDim2.fromOffset(232, 220)

    list.Position =
        UDim2.fromOffset(190, 74)

    list.BackgroundTransparency = 1
    list.BorderSizePixel = 0
    list.ScrollBarThickness = 2
    list.CanvasSize =
        UDim2.fromOffset(0, 210)

    list.ZIndex = 402
    list.Parent = card

    runtime.BodySelector.List = list

    for index, name in ipairs(
        runtime.TargetBodyOrder
    ) do
        local row =
            Instance.new("TextButton")

        row.Size =
            UDim2.new(1, 0, 0, 27)

        row.Position =
            UDim2.fromOffset(
                0,
                (index - 1) * 30
            )

        row.BackgroundColor3 =
            Color3.fromRGB(28,30,33)

        row.BorderSizePixel = 0
        row.TextColor3 =
            Color3.fromRGB(231,231,231)

        row.Font = Enum.Font.GothamMedium
        row.TextSize = 10
        row.TextXAlignment =
            Enum.TextXAlignment.Left

        row.AutoButtonColor = false
        row.ZIndex = 403
        row.Parent = list

        Instance.new(
            "UICorner",
            row
        ).CornerRadius =
            UDim.new(0, 10)

        local pad =
            Instance.new("UIPadding")

        pad.PaddingLeft =
            UDim.new(0, 12)

        pad.Parent = row

        runtime.BodySelector.Rows[name] =
            row

        row.Activated:Connect(function()
            toggle(name)
        end)
    end

    local function action(
        text,
        x,
        width,
        callback
    )
        local button =
            Instance.new("TextButton")

        button.Size =
            UDim2.fromOffset(
                width,
                32
            )

        button.Position =
            UDim2.new(
                0,
                x,
                1,
                -42
            )

        button.BackgroundColor3 =
            Color3.fromRGB(37,39,43)

        button.BorderSizePixel = 0
        button.Text = text
        button.TextColor3 =
            Color3.fromRGB(242,243,245)

        button.Font = Enum.Font.GothamBold
        button.TextSize = 10
        button.ZIndex = 403
        button.Parent = card

        Instance.new(
            "UICorner",
            button
        ).CornerRadius =
            UDim.new(0, 11)

        button.Activated:Connect(
            callback
        )

        return button
    end

    runtime.BodySelector.SelectAllButton =
        action("Todo", 18, 74, function()
            local selected =
                runtime.TargetSelections[
                    runtime.BodySelector.Mode
                ]

            for _, name in ipairs(
                runtime.TargetBodyOrder
            ) do
                selected[name] = true
            end

            runtime.BodySelector.Refresh()
        end)

    runtime.BodySelector.ClearButton =
        action("Limpiar", 98, 78, function()
            table.clear(
                runtime.TargetSelections[
                    runtime.BodySelector.Mode
                ]
            )

            runtime.BodySelector.Refresh()
        end)

    runtime.BodySelector.DoneButton =
        action("Aplicar", 330, 92, function()
            local mode =
                runtime.BodySelector.Mode

            local selected =
                runtime.TargetSelections[mode]

            if not next(selected) then
                selected["Cabeza"] = true
            end

            runtime.SetTargetSelection(
                mode,
                runtime.GetTargetSelectionArray(
                    mode
                )
            )

            overlay.Visible = false
        end)

    runtime.BodySelector.DoneButton.BackgroundColor3 =
        Color3.fromRGB(230,233,236)

    runtime.BodySelector.DoneButton.TextColor3 =
        Color3.fromRGB(17,18,20)

    function runtime.ApplyBodySelectorResponsiveLayout()
        local selector =
            runtime.BodySelector

        if not selector then
            return 1
        end

        local bounds =
            selector.Overlay.AbsoluteSize

        if bounds.X < 1 or bounds.Y < 1 then
            local camera =
                workspace.CurrentCamera

            bounds =
                camera
                and camera.ViewportSize
                or Vector2.new(800,600)
        end

        local margin =
            math.clamp(
                math.floor(
                    math.min(
                        bounds.X,
                        bounds.Y
                    ) * 0.025
                ),
                6,
                14
            )

        local availableW =
            math.max(
                240,
                bounds.X - margin * 2
            )

        local availableH =
            math.max(
                260,
                bounds.Y - margin * 2
            )

        local portrait =
            availableW < 470
            or (
                availableW
                / math.max(1, availableH)
            ) < 1.05

        if not portrait then
            selector.Card.Size =
                UDim2.fromOffset(
                    440,
                    360
                )

            selector.Figure.Position =
                UDim2.fromOffset(
                    18,
                    74
                )

            selector.List.Position =
                UDim2.fromOffset(
                    190,
                    74
                )

            selector.List.Size =
                UDim2.fromOffset(
                    232,
                    220
                )

            selector.SelectAllButton.Position =
                UDim2.new(
                    0,
                    18,
                    1,
                    -42
                )

            selector.ClearButton.Position =
                UDim2.new(
                    0,
                    98,
                    1,
                    -42
                )

            selector.DoneButton.Position =
                UDim2.new(
                    0,
                    330,
                    1,
                    -42
                )

            local targetScale =
                math.min(
                    1,
                    availableW / 440,
                    availableH / 360
                )

            selector.Scale.Scale =
                targetScale

            return targetScale
        end

        local cardW =
            math.min(
                420,
                availableW
            )

        local cardH =
            math.max(
                360,
                math.min(
                    620,
                    availableH
                )
            )

        selector.Card.Size =
            UDim2.fromOffset(
                cardW,
                cardH
            )

        local targetScale =
            math.min(
                1,
                availableW / cardW,
                availableH / cardH
            )

        selector.Scale.Scale =
            targetScale

        selector.Figure.Position =
            UDim2.fromOffset(
                math.floor(
                    (cardW - 160) / 2
                ),
                72
            )

        local listY = 300
        local actionsY =
            cardH - 42

        selector.List.Position =
            UDim2.fromOffset(
                14,
                listY
            )

        selector.List.Size =
            UDim2.new(
                1,
                -28,
                0,
                math.max(
                    58,
                    actionsY
                    - listY
                    - 8
                )
            )

        local gap = 7
        local buttonW =
            math.floor(
                (
                    cardW
                    - 28
                    - gap * 2
                ) / 3
            )

        selector.SelectAllButton.Size =
            UDim2.fromOffset(
                buttonW,
                32
            )

        selector.SelectAllButton.Position =
            UDim2.fromOffset(
                14,
                actionsY
            )

        selector.ClearButton.Size =
            UDim2.fromOffset(
                buttonW,
                32
            )

        selector.ClearButton.Position =
            UDim2.fromOffset(
                14 + buttonW + gap,
                actionsY
            )

        selector.DoneButton.Size =
            UDim2.fromOffset(
                buttonW,
                32
            )

        selector.DoneButton.Position =
            UDim2.fromOffset(
                14 + (buttonW + gap) * 2,
                actionsY
            )

        return targetScale
    end

    runtime.Track(
        overlay:GetPropertyChangedSignal(
            "AbsoluteSize"
        ):Connect(function()
            if overlay.Visible
                and runtime.BodySelector
            then
                runtime.ApplyBodySelectorResponsiveLayout()
            end
        end)
    )

    function runtime.BodySelector.Refresh()
        local selector =
            runtime.BodySelector

        if not selector then return end

        local selected =
            runtime.TargetSelections[
                selector.Mode
            ] or {}

        for _, name in ipairs(
            runtime.TargetBodyOrder
        ) do
            local active =
                selected[name] == true

            local segment =
                selector.Segments[name]

            if segment then
                segment.Button.BackgroundColor3 =
                    active
                    and Color3.fromRGB(230,233,236)
                    or Color3.fromRGB(36,38,42)

                segment.Stroke.Color =
                    active
                    and Color3.fromRGB(255,255,255)
                    or Color3.fromRGB(75,80,87)

                segment.Stroke.Transparency =
                    active and 0.05 or 0.35
            end

            local row =
                selector.Rows[name]

            if row then
                row.Text =
                    (active and "✓  " or "○  ")
                    .. name

                row.BackgroundColor3 =
                    active
                    and Color3.fromRGB(52,55,60)
                    or Color3.fromRGB(28,30,33)

                row.TextColor3 =
                    active
                    and Color3.fromRGB(255,255,255)
                    or Color3.fromRGB(185,190,197)
            end
        end
    end
end

function runtime.OpenBodySelector(mode)
    runtime.EnsureBodySelector()

    runtime.BodySelector.Mode = mode

    runtime.BodySelector.Title.Text =
        "Selector corporal · "
        .. (
            mode == "AutoShoot"
            and "Auto Shoot"
            or "Silent Aim"
        )

    runtime.BodySelector.Refresh()
    runtime.BodySelector.Overlay.Visible = true

    local targetScale =
        runtime.ApplyBodySelectorResponsiveLayout()

    runtime.BodySelector.Scale.Scale =
        targetScale * 0.965

    runtime.BodySelector.Card.GroupTransparency =
        0.12

    TweenService:Create(
        runtime.BodySelector.Scale,
        TweenInfo.new(
            0.16,
            Enum.EasingStyle.Quint,
            Enum.EasingDirection.Out
        ),
        {Scale = targetScale}
    ):Play()

    TweenService:Create(
        runtime.BodySelector.Card,
        TweenInfo.new(
            0.14,
            Enum.EasingStyle.Quad,
            Enum.EasingDirection.Out
        ),
        {GroupTransparency = 0}
    ):Play()
end

-- ==========================================
-- AIM TAB
-- ==========================================

Tabs.Aim:Section({
    Title = "Auto Shoot",
})

UIElements.TogAutoShoot =
    Tabs.Aim:Toggle({
        Title = "Auto Shoot",
        Desc = "Dispara automáticamente a cualquier enemigo visible y válido; no depende del FOV.",
        Value = false,

        Callback = function(value)
            state.AutoShoot = value

            if not value then
                state.AutoTarget = nil
                state.AutoTargetPlayer = nil

                if state.SilentAim then
                    aimHookState.Target =
                        state.SilentTarget
                else
                    aimHookState.Target = nil
                end
            end
        end,
    })

Tabs.Aim:Button({
    Title = "Selector corporal · Auto Shoot",
    Desc = "Abre el monito 2D y permite seleccionar varias partes.",
    Callback = function()
        runtime.OpenBodySelector(
            "AutoShoot"
        )
    end,
})

Tabs.Aim:Section({
    Title = "Silent Aim",
})

UIElements.TogSilentAim =
    Tabs.Aim:Toggle({
        Title = "Silent Aim",
        Desc = "Método Duels; no toca ShootGun directamente.",
        Value = false,

        Callback = function(value)
            state.SilentAim = value

            if not value then
                state.SilentTarget = nil
                state.SilentTargetPlayer = nil

                if not state.AutoShoot then
                    aimHookState.Target = nil
                end
            end
        end,
    })

Tabs.Aim:Button({
    Title = "Selector corporal · Silent Aim",
    Desc = "Selecciona cabeza, torso, brazos y piernas con el monito 2D.",
    Callback = function()
        runtime.OpenBodySelector(
            "SilentAim"
        )
    end,
})

Tabs.Aim:Section({
    Title = "Campo de visión",
})

UIElements.TogFOV =
    Tabs.Aim:Toggle({
        Title = "Filtro de círculo FOV",
        Desc = "Solo afecta Silent Aim. Auto Shoot funciona independiente del FOV.",
        Value = true,

        Callback = function(value)
            state.FOVEnabled = value
        end,
    })

UIElements.TogShowFOV =
    Tabs.Aim:Toggle({
        Title = "Mostrar Círculo FOV",
        Desc = "Se pone verde solo cuando una parte seleccionada del enemigo entra visible al FOV.",
        Value = true,

        Callback = function(value)
            state.ShowFOV = value
        end,
    })

UIElements.SliFOV =
    Tabs.Aim:Slider({
        Title = "Tamaño del FOV",
        Step = 1,

        Value = {
            Min = 10,
            Max = 800,
            Default = state.FOVRadius,
        },

        Callback = function(value)
            state.FOVRadius =
                tonumber(value) or 140
        end,
    })

-- ==========================================
-- VISUALES
-- ==========================================

Tabs.Vis:Section({
    Title = "ESP de jugadores",
})

UIElements.TogESP =
    Tabs.Vis:Toggle({
        Title = "ESP Enemies",
        Desc = "Solo enemigos cercanos y realmente dentro de partida.",
        Value = false,

        Callback = function(value)
            state.ESP = value

            if not value
                or state.InLobby
            then
                clearESP()
            end
        end,
    })

UIElements.SliESPDistance =
    Tabs.Vis:Slider({
        Title = "Distancia máxima ESP",
        Desc = "Evita pintar jugadores al otro lado del servidor.",
        Step = 25,

        Value = {
            Min = 100,
            Max = 1500,
            Default = state.ESPMaxDistance,
        },

        Callback = function(value)
            state.ESPMaxDistance =
                tonumber(value) or 650
        end,
    })

UIElements.TogTeamCheck =
    Tabs.Vis:Toggle({
        Title = "Team Check",
        Desc = "Ignora jugadores del mismo equipo.",
        Value = true,

        Callback = function(value)
            state.TeamCheck = value
        end,
    })

Tabs.Config:Paragraph({
    Title = "Validación de partida",
    Desc = "ESP/Silent/AutoShoot ignoran lobby, espectador, ForceField y jugadores fuera del rango.",
})

Tabs.Creditos:Paragraph({
    Title = "Kev",
    Desc = "XeroHub · gracias por usar el hub.",
})

runtime.Track(
    RunService.Heartbeat:Connect(function(dt)
        runtime.StatusTimer =
            (runtime.StatusTimer or 0) + dt

        if runtime.StatusTimer < 0.5 then
            return
        end

        runtime.StatusTimer = 0

        pcall(function()
            if lobbyParagraph
                and lobbyParagraph.SetDesc
            then
                if state.InLobby then
                    lobbyParagraph:SetDesc(
                        "Lobby · "
                        .. tostring(
                            state.LobbyReason
                        )
                    )
                else
                    local target =
                        state.AutoTargetPlayer
                        or state.SilentTargetPlayer

                    lobbyParagraph:SetDesc(
                        target
                        and (
                            "Partida · Target: "
                            .. target.Name
                        )
                        or "Partida · Sin target"
                    )
                end
            end
        end)
    end)
)

pcall(function()
    Window:OnDestroy(function()
        if runtimeEnv.__XERO_SHOOTGUN_HUB_CLEANUP then
            runtimeEnv.__XERO_SHOOTGUN_HUB_CLEANUP()
        end
    end)
end)

-- ==========================================
-- CLEANUP
-- ==========================================

runtimeEnv.__XERO_SHOOTGUN_HUB_CLEANUP =
    function()
        if not runtime.Alive then return end

        runtime.Alive = false
        state.SilentAim = false
        state.AutoShoot = false
        state.ESP = false
        aimHookState.Target = nil

        clearESP()

        if runtime.ToolActivatedConnection then
            pcall(function()
                runtime.ToolActivatedConnection:Disconnect()
            end)

            runtime.ToolActivatedConnection = nil
        end

        if runtime.BodySelectorGui then
            safeDestroy(
                runtime.BodySelectorGui
            )

            runtime.BodySelectorGui = nil
        end

        for i = #runtime.Connections, 1, -1 do
            local connection =
                runtime.Connections[i]

            pcall(function()
                connection:Disconnect()
            end)

            runtime.Connections[i] = nil
        end

        for i = #runtime.Drawings, 1, -1 do
            removeDrawing(
                runtime.Drawings[i]
            )

            runtime.Drawings[i] = nil
        end
    end

refreshLobbyState()

print("[XeroHub] ShootGun v2 cargado | ESP limitado | AutoShoot real-click | selector 2D | camera-safe")
