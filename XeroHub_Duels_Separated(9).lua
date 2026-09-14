-- XeroHub | DUELS MURDERS VS SHERIFF | Kev
-- Runtime optimizer for XeroHub_Duels_Separated(9).lua
-- Applies conservative performance/lifecycle fixes in memory, then executes the patched source.

local RAW_URL = "https://raw.githubusercontent.com/OnyxDevv/Onyx-web/refs/heads/main/XeroHub_Duels_Separated(9).lua"

local source = game:HttpGet(RAW_URL)
assert(type(source) == "string" and #source > 1000, "XeroHub Optimizer: no se pudo descargar el script base")
source = source:gsub("\r\n", "\n")
assert(source:find("-- XeroHub | DUELS MURDERS VS SHERIFF | Kev --", 1, true), "XeroHub Optimizer: versión base inesperada")

local patchesApplied = 0
local function replaceOnce(old, new, label, required)
    local s, e = source:find(old, 1, true)
    if not s then
        if required ~= false then
            error("XeroHub Optimizer: no encontré el bloque: " .. tostring(label))
        end
        return false
    end
    source = source:sub(1, s - 1) .. new .. source:sub(e + 1)
    patchesApplied = patchesApplied + 1
    return true
end

local function replaceBetween(startMarker, endMarker, replacement, label)
    local s = source:find(startMarker, 1, true)
    if not s then error("XeroHub Optimizer: falta inicio de " .. tostring(label)) end
    local e = source:find(endMarker, s + #startMarker, true)
    if not e then error("XeroHub Optimizer: falta fin de " .. tostring(label)) end
    source = source:sub(1, s - 1) .. replacement .. "\n\n" .. source:sub(e)
    patchesApplied = patchesApplied + 1
end

-- 1) Conservamos los aliases globales del script base.
-- El chunk ya está cerca del límite clásico de locales; volverlos local podría romper la compilación.

-- 2) Lifecycle: scopes para conexiones por Character/Player + drawings removibles.
replaceOnce(
[[local runtime = {
    Alive = true,
    Connections = {},
    Drawings = {},
    InfectedTexts = {},
}]],
[[local runtime = {
    Alive = true,
    Connections = {},
    ScopedConnections = {},
    Drawings = {},
    InfectedTexts = {},
}]],
"runtime lifecycle table", true)

replaceOnce(
[[function runtime.Track(connection)
    if connection then table.insert(runtime.Connections, connection) end
    return connection
end

function runtime.TrackDrawing(drawing)
    if drawing then table.insert(runtime.Drawings, drawing) end
    return drawing
end]],
[[function runtime.Track(connection)
    if connection then
        local list = runtime.Connections
        list[#list + 1] = connection

        -- Varios toggles desconectan manualmente y antes dejaban la referencia
        -- muerta en esta lista hasta reejecutar todo el hub. Compactamos de forma
        -- muy ocasional para que una sesión larga no acumule basura.
        if #list >= 512 then
            local write = 1
            for read = 1, #list do
                local current = list[read]
                local keep = current ~= nil
                if keep then
                    local ok, connected = pcall(function() return current.Connected end)
                    if ok and connected == false then keep = false end
                end
                if keep then
                    if write ~= read then list[write] = current end
                    write = write + 1
                end
            end
            for i = #list, write, -1 do list[i] = nil end
        end
    end
    return connection
end

function runtime.TrackScoped(scope, connection)
    if not scope or not connection then return connection end
    local bucket = runtime.ScopedConnections[scope]
    if not bucket then
        bucket = {}
        runtime.ScopedConnections[scope] = bucket
    end
    bucket[#bucket + 1] = connection
    return connection
end

function runtime.ClearScope(scope)
    local bucket = scope and runtime.ScopedConnections[scope]
    if not bucket then return end
    for i = #bucket, 1, -1 do
        local connection = bucket[i]
        pcall(function() connection:Disconnect() end)
        bucket[i] = nil
    end
    runtime.ScopedConnections[scope] = nil
end

function runtime.TrackDrawing(drawing)
    if drawing then runtime.Drawings[drawing] = true end
    return drawing
end

function runtime.RemoveDrawing(drawing)
    if not drawing then return end
    runtime.Drawings[drawing] = nil
    pcall(function() drawing:Remove() end)
end]],
"runtime trackers", true)

replaceOnce(
[[    if runtime.SoundCleanup then pcall(runtime.SoundCleanup) end]],
[[    if runtime.SoundCleanup then pcall(runtime.SoundCleanup) end

    -- Primero cerramos scopes de vida corta (Character/Player) para no mantener
    -- referencias a personajes viejos durante una reejecución.
    while next(runtime.ScopedConnections) do
        runtime.ClearScope(next(runtime.ScopedConnections))
    end]],
"cleanup scoped connections", true)

replaceOnce(
[[    for i = #runtime.Drawings, 1, -1 do
        local drawing = runtime.Drawings[i]
        pcall(function() drawing:Remove() end)
        runtime.Drawings[i] = nil
    end]],
[[    for drawing in pairs(runtime.Drawings) do
        pcall(function() drawing:Remove() end)
        runtime.Drawings[drawing] = nil
    end]],
"cleanup drawings registry", true)

-- 3) ForceField del Character local: las conexiones del Character anterior ya no
-- quedan retenidas en runtime.Connections tras cada ronda/respawn.
replaceBetween(
"-- 2. Actualiza el caché SOLO cuando te ponen o quitan un campo de fuerza",
"-- 3. La función maestra ahora es 1000x más rápida",
[[-- 2. Actualiza el caché SOLO cuando te ponen o quitan un campo de fuerza
runtime.ForceFieldScope = runtime.ForceFieldScope or {}

function runtime.BindForceFieldCache(char)
    runtime.ClearScope(runtime.ForceFieldScope)
    hasForceField = char and char:FindFirstChildOfClass("ForceField") ~= nil or false
    if not char then return end

    runtime.TrackScoped(runtime.ForceFieldScope, char.ChildAdded:Connect(function(child)
        if char == player.Character and child:IsA("ForceField") then
            hasForceField = true
        end
    end))
    runtime.TrackScoped(runtime.ForceFieldScope, char.ChildRemoved:Connect(function(child)
        if char == player.Character and child:IsA("ForceField") then
            hasForceField = false
        end
    end))
end

runtime.Track(player.CharacterAdded:Connect(runtime.BindForceFieldCache))
runtime.Track(player.CharacterRemoving:Connect(function(char)
    runtime.ClearScope(runtime.ForceFieldScope)
    if char == player.Character then hasForceField = false end
end))
if player.Character then runtime.BindForceFieldCache(player.Character) end]],
"forcefield scoped cache")

-- 4) Team cache: watchers de jugadores que salen se desconectan y liberan.
replaceBetween(
"function setupPlayerEvents(p)",
"function isEnemy(targetPlayer)",
[[runtime.EnemyEventScopes = runtime.EnemyEventScopes or setmetatable({}, {__mode = "k"})
function setupPlayerEvents(p)
    if not p or p == player then return end

    local previous = runtime.EnemyEventScopes[p]
    if previous then runtime.ClearScope(previous) end

    local scope = {}
    runtime.EnemyEventScopes[p] = scope
    runtime.TrackScoped(scope, p:GetPropertyChangedSignal("Team"):Connect(function() updateEnemy(p) end))
    runtime.TrackScoped(scope, p:GetPropertyChangedSignal("TeamColor"):Connect(function() updateEnemy(p) end))
    runtime.TrackScoped(scope, p:GetAttributeChangedSignal("Team"):Connect(function() updateEnemy(p) end))
    runtime.TrackScoped(scope, p:GetAttributeChangedSignal("team"):Connect(function() updateEnemy(p) end))
end

for _, p in ipairs(listaJugadores) do
    if p ~= player then setupPlayerEvents(p) end
end
runtime.Track(Players.PlayerAdded:Connect(function(p) setupPlayerEvents(p) end))
runtime.Track(Players.PlayerRemoving:Connect(function(p)
    updateEnemy(p)
    local scope = runtime.EnemyEventScopes[p]
    if scope then runtime.ClearScope(scope) end
    runtime.EnemyEventScopes[p] = nil
end))]],
"enemy scoped watchers")

-- 5) Clon: precomputa qué visual pertenece a Head/Korblox/Hair una sola vez.
-- Además evita recorrer todos los visuales cada frame cuando transparencia/capas no cambiaron.
replaceBetween(
"function runtime.AvatarCloneBuildNativeTransparencyMap(char, overlay)",
"function runtime.AvatarCloneBindNativeTransparency(char, overlay)",
[[function runtime.AvatarCloneBuildNativeTransparencyMap(char, overlay)
    local state = runtime.Appearance.AvatarClone
    table.clear(state.NativeTransparencyPairs)
    table.clear(state.NativeEffectPairs)
    state.NativeAppliedTransparency = nil
    state.NativeLayerSignatureLast = nil

    if not char or not char.Parent or not overlay or not overlay.Parent then return false end

    for _, object in ipairs(overlay:GetDescendants()) do
        if object:IsA("BasePart") then
            local accessory = object:FindFirstAncestorWhichIsA("Accoutrement")
            local original = state.OverlayVisualCache[object]
            local direct = object.Parent == overlay
            local name = object.Name
            state.NativeTransparencyPairs[#state.NativeTransparencyPairs + 1] = {
                ClonePart = object,
                BaseLTM = original and tonumber(original.LocalTransparencyModifier)
                    or tonumber(object.LocalTransparencyModifier)
                    or 0,
                IsHead = direct and name == "Head",
                IsKorbloxPart = direct and (name == "RightUpperLeg" or name == "RightLowerLeg" or name == "RightFoot"),
                IsHair = accessory ~= nil and isHairAccessory(accessory) == true or false,
            }
        elseif object:IsA("ParticleEmitter") or object:IsA("Trail") or object:IsA("Beam")
            or object:IsA("Smoke") or object:IsA("Fire") or object:IsA("Sparkles") then
            local accessory = object:FindFirstAncestorWhichIsA("Accoutrement")
            local original = state.OverlayVisualCache[object]
            state.NativeEffectPairs[#state.NativeEffectPairs + 1] = {
                Effect = object,
                BaseEnabled = original and original.Enabled ~= false or object.Enabled,
                IsHair = accessory ~= nil and isHairAccessory(accessory) == true or false,
            }
        end
    end

    return #state.NativeTransparencyPairs > 0
end

function runtime.AvatarCloneNativeLayerHidden(pair)
    if not pair then return false end
    local enabled = runtime.Appearance.Enabled
    return (enabled.Headless and pair.IsHead)
        or (enabled.Korblox and pair.IsKorbloxPart)
        or (enabled.HideHair and pair.IsHair)
        or false
end

function runtime.AvatarCloneSyncNativeTransparency(char, overlay, dt)
    local state = runtime.Appearance.AvatarClone
    if state.Overlay ~= overlay or not overlay or not overlay.Parent or not char or not char.Parent then return end

    local currentCamera = workspace.CurrentCamera
    local humanoid = state.NativeSyncHumanoid
    if not humanoid or humanoid.Parent ~= char then
        humanoid = char:FindFirstChildOfClass("Humanoid")
        state.NativeSyncHumanoid = humanoid
    end

    local subject = currentCamera and currentCamera.CameraSubject
    local cameraOwnsCharacter = currentCamera and humanoid and (
        subject == humanoid
        or subject == char
        or (subject and subject:IsDescendantOf(char))
    )

    local transparency = 0
    if cameraOwnsCharacter and currentCamera then
        local focusPos = currentCamera.Focus.Position
        local cameraPos = currentCamera.CFrame.Position
        local delta = focusPos - cameraPos
        local distance = math.sqrt(delta:Dot(delta))
        transparency = (distance < 2) and (1 - (distance - 0.5) / 1.5) or 0
        transparency = math.clamp(transparency, 0, 1)
    end

    state.NativeCameraTransparencyLast = transparency

    local enabled = runtime.Appearance.Enabled
    local layerSignature = (enabled.Headless and 1 or 0)
        + (enabled.Korblox and 2 or 0)
        + (enabled.HideHair and 4 or 0)

    if state.NativeAppliedTransparency == transparency
        and state.NativeLayerSignatureLast == layerSignature then
        return
    end

    state.NativeAppliedTransparency = transparency
    state.NativeLayerSignatureLast = layerSignature

    for i = 1, #state.NativeTransparencyPairs do
        local pair = state.NativeTransparencyPairs[i]
        local clonePart = pair.ClonePart
        if clonePart and clonePart.Parent then
            local baseLTM = pair.BaseLTM or 0
            local desired = runtime.AvatarCloneNativeLayerHidden(pair)
                and 1
                or (1 - ((1 - baseLTM) * (1 - transparency)))
            if clonePart.LocalTransparencyModifier ~= desired then
                clonePart.LocalTransparencyModifier = desired
            end
        end
    end

    for i = 1, #state.NativeEffectPairs do
        local pair = state.NativeEffectPairs[i]
        local effect = pair.Effect
        if effect and effect.Parent then
            local hiddenByLayer = enabled.HideHair and pair.IsHair
            local desired = pair.BaseEnabled == true and transparency < 0.95 and not hiddenByLayer
            if effect.Enabled ~= desired then effect.Enabled = desired end
        end
    end
end]],
"clone native transparency hot path")

-- Invalida el fast-path si otra rutina acaba de tocar visuales del overlay.
replaceOnce(
[[function runtime.UpdateAvatarCloneLayers()
    local state = runtime.Appearance.AvatarClone
    local overlay = state.Overlay
    if not overlay or not overlay.Parent then return end]],
[[function runtime.UpdateAvatarCloneLayers()
    local state = runtime.Appearance.AvatarClone
    local overlay = state.Overlay
    if not overlay or not overlay.Parent then return end
    state.NativeAppliedTransparency = nil
    state.NativeLayerSignatureLast = nil]],
"clone layer invalidation", true)

replaceOnce(
[[    state.NativeTransparencyBindName = bindName
    state.NativeCameraTransparencyLast = nil]],
[[    state.NativeTransparencyBindName = bindName
    state.NativeCameraTransparencyLast = nil
    state.NativeAppliedTransparency = nil
    state.NativeLayerSignatureLast = nil
    state.NativeSyncHumanoid = nil]],
"clone bind reset", true)

replaceOnce(
[[    table.clear(state.NativeTransparencyPairs)
    table.clear(state.NativeEffectPairs)
    state.NativeCameraTransparencyLast = nil]],
[[    table.clear(state.NativeTransparencyPairs)
    table.clear(state.NativeEffectPairs)
    state.NativeCameraTransparencyLast = nil
    state.NativeAppliedTransparency = nil
    state.NativeLayerSignatureLast = nil
    state.NativeSyncHumanoid = nil]],
"clone disconnect reset", true)

-- 6) Respawn: limiteds/Headless/Korblox/face YA NO esperan al clon estable.
-- El clon mantiene su máscara y hace el rebind pesado en paralelo.
replaceBetween(
"function runtime.FastRestoreAppearanceOnRespawn(char, generation)",
"function runtime.SetAppearance(key, state)",
[[function runtime.QueueAvatarCloneGuard(char, generation)
    local state = runtime.Appearance.AvatarClone
    state.GuardWorkers = state.GuardWorkers or {}
    local key = generation or runtime.Appearance.RespawnGeneration
    local worker = state.GuardWorkers[key]
    if worker then
        worker.Rerun = true
        return
    end

    worker = {Rerun = false}
    state.GuardWorkers[key] = worker
    task.spawn(function()
        repeat
            worker.Rerun = false
            runtime.GuardAvatarCloneAfterRespawn(char, key)
        until not (
            runtime.Alive
            and char and char.Parent
            and player.Character == char
            and key == runtime.Appearance.RespawnGeneration
            and worker.Rerun
        )
        if state.GuardWorkers[key] == worker then
            state.GuardWorkers[key] = nil
        end
    end)
end

function runtime.FastRestoreAppearanceOnRespawn(char, generation)
    if not runtime.Alive or not char or not char.Parent then return end

    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not humanoid then humanoid = char:WaitForChild("Humanoid", 0.35) end
    if not runtime.Alive or not humanoid or not char.Parent then return end
    if generation and generation ~= runtime.Appearance.RespawnGeneration then return end

    -- Sólo esperamos las piezas mínimas que realmente necesitan las capas locales.
    if runtime.Appearance.Enabled.Headless or runtime.GetActiveFaceKey() or hasEnabledAppearanceAccessory() then
        if not char:FindFirstChild("Head") then char:WaitForChild("Head", 0.35) end
    end
    if runtime.Appearance.Enabled.Korblox and humanoid.RigType == Enum.HumanoidRigType.R15 then
        if not char:FindFirstChild("RightUpperLeg") then char:WaitForChild("RightUpperLeg", 0.35) end
    end

    if not runtime.Alive or not char.Parent then return end
    if generation and generation ~= runtime.Appearance.RespawnGeneration then return end

    local cloneState = runtime.Appearance.AvatarClone
    local clonePending = cloneState.Active
        and cloneState.KeepOnRespawn
        and cloneState.Template ~= nil

    -- Mantener la máscara evita mostrar el avatar base durante el freeze de Duels,
    -- pero ya no bloquea los limiteds/capas durante 1.8 + hasta 7 segundos.
    if clonePending then
        runtime.BeginAvatarCloneRespawnMask(char, generation)
    end

    runtime.Appearance.AttachmentCache[char] = nil
    runtime.ReapplyAppearanceLayers(char)

    -- Si el overlay anterior sigue vivo, actualizamos sus capas de inmediato.
    -- El bind definitivo al rig nuevo lo resuelve QueueAvatarCloneGuard en paralelo.
    if clonePending and cloneState.Overlay and cloneState.Overlay.Parent then
        runtime.UpdateAvatarCloneLayers()
        runtime.AvatarCloneHideBase(char)
    end
end]],
"instant appearance restore")

replaceOnce(
[[    task.spawn(function()
        runtime.FastRestoreAppearanceOnRespawn(char, generation)

        -- El primer apply puede coincidir con el freeze/teleport de inicio de ronda.
        -- La guardia de 10 s corrige cualquier reconstrucción tardía sin que el
        -- usuario tenga que pulsar "Clonar" de nuevo.
        runtime.GuardAvatarCloneAfterRespawn(char, generation)
    end)]],
[[    -- Las capas visuales se restauran inmediatamente; el clon se estabiliza aparte.
    task.spawn(function()
        runtime.FastRestoreAppearanceOnRespawn(char, generation)
    end)
    runtime.QueueAvatarCloneGuard(char, generation)]],
"characteradded parallel clone guard", true)

replaceOnce(
[[                        runtime.BeginAvatarCloneRespawnMask(char, generation)
                        task.spawn(function()
                            runtime.GuardAvatarCloneAfterRespawn(char, generation)
                        end)]],
[[                        runtime.BeginAvatarCloneRespawnMask(char, generation)
                        runtime.QueueAvatarCloneGuard(char, generation)]],
"appearance loaded dedupe guard", true)

-- 7) ESP 3D: no calcules sqrt/distancia si la distancia está apagada.
replaceOnce(
[[                                local dist = math.sqrt(distSq)
                                if activeESPs[p] and activeESPs[p].Char ~= char then cleanESP(p) end]],
[[                                local dist = espSettings.Distance and math.sqrt(distSq) or 0
                                if activeESPs[p] and activeESPs[p].Char ~= char then cleanESP(p) end]],
"esp conditional sqrt", true)

replaceOnce(
[[                                local distanceInt = math_floor(dist)]],
[[                                local distanceInt = espSettings.Distance and math_floor(dist) or 0]],
"esp conditional distance int", true)

-- 8) ESP 2D: si sólo está visible el círculo FOV + ESP 3D, no escanear jugadores a 30 Hz.
replaceOnce(
[[    if not espEnabled or enLobby then
        hideTracersOnce()
        runtime.HideAllESP2D()
        return
    end]],
[[    if not espLinesEnabled and not wantsESP2D then
        hideTracersOnce()
        runtime.HideAllESP2D()
        return
    end

    if not espEnabled or enLobby then
        hideTracersOnce()
        runtime.HideAllESP2D()
        return
    end]],
"esp2d fov-only early out", true)

-- Sólo recalcular HSV cuando cambia de verdad el ratio de vida.
replaceOnce(
[[                        entry.Health.From = Vector2_new(bx, byBottom)
                        entry.Health.To = Vector2_new(bx, byHealth)
                        entry.Health.Color = Color3.fromHSV(ratio * 0.33, 0.92, 1)
                        if not entry.Health.Visible then entry.Health.Visible = true end]],
[[                        entry.Health.From = Vector2_new(bx, byBottom)
                        entry.Health.To = Vector2_new(bx, byHealth)
                        if entry.LastHealthRatio ~= ratio then
                            entry.Health.Color = Color3.fromHSV(ratio * 0.33, 0.92, 1)
                            entry.LastHealthRatio = ratio
                        end
                        if not entry.Health.Visible then entry.Health.Visible = true end]],
"esp2d health color cache", true)

-- 9) Al salir un jugador, sacar sus Drawing del registry además de Remove().
replaceOnce(
[[runtime.Track(Players.PlayerRemoving:Connect(function(p)
    if tracerLines[p] then pcall(function() tracerLines[p]:Remove() end); tracerLines[p] = nil end
    local entry = runtime.ESP2D[p]
    if entry then
        for _, drawing in pairs(entry) do
            if typeof(drawing) ~= "function" then pcall(function() drawing:Remove() end) end
        end
        runtime.ESP2D[p] = nil
    end
    cleanESP(p)
end))]],
[[runtime.Track(Players.PlayerRemoving:Connect(function(p)
    if tracerLines[p] then
        runtime.RemoveDrawing(tracerLines[p])
        tracerLines[p] = nil
    end
    local entry = runtime.ESP2D[p]
    if entry then
        runtime.RemoveDrawing(entry.Box)
        runtime.RemoveDrawing(entry.HealthBg)
        runtime.RemoveDrawing(entry.Health)
        runtime.ESP2D[p] = nil
    end
    cleanESP(p)
end))]],
"drawing player cleanup", true)

-- Si GitHub cambia el archivo base y alguno de los 18 puntos deja de coincidir,
-- es mejor fallar aquí que ejecutar una mezcla parcial de versiones.
assert(patchesApplied == 18, "XeroHub Optimizer: parche incompleto (" .. tostring(patchesApplied) .. "/18)")

-- Exponer sólo un dato pequeño para diagnóstico; no crea loops extra.
local env = (getgenv and getgenv()) or _G
env.__XERO_OPTIMIZER_PATCHES = patchesApplied

local chunk, compileError = loadstring(source, "XeroHub_Duels_Separated_9_Optimized")
assert(chunk, "XeroHub Optimizer: error compilando versión parcheada: " .. tostring(compileError))
return chunk()
