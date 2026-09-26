-- Xero | AIM COMPARE LAB v3
-- Creator: Kev
-- Comparador PASIVO para Xero/Yisus.
-- No instala __namecall/__index hooks y no modifica raycasts/remotes.
-- Flujo correcto por sesión:
--   1) Ejecuta este Lab ANTES del hub a probar.
--   2) Pulsa "FIJAR BASELINE".
--   3) Carga Xero o Yisus.
--   4) Pulsa "ESCANEAR XERO" o "ESCANEAR YISUS".
--   5) Dispara. El reporte se reescribe después de cada captura.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")

local player = Players.LocalPlayer
local mouse = player:GetMouse()
local camera = Workspace.CurrentCamera

local SAVE_FOLDER = "XeroHub"
local REPORT_FOLDER = SAVE_FOLDER .. "/AimReports"
local STATE_FILE = SAVE_FOLDER .. "/AimCompareLab_v3.json"
local XERO_REPORT = REPORT_FOLDER .. "/Xero_Report.txt"
local YISUS_REPORT = REPORT_FOLDER .. "/Yisus_Report.txt"

local function safe(fn, fallback)
    local ok, value = pcall(fn)
    if ok then return value end
    return fallback
end

local function round(n, p)
    if type(n) ~= "number" then return n end
    local m = 10 ^ (p or 3)
    return math.floor(n * m + 0.5) / m
end

local function shortPath(obj)
    if not obj then return "nil" end
    local parts = {}
    local cur = obj
    for _ = 1, 8 do
        if not cur then break end
        table.insert(parts, 1, cur.Name)
        cur = cur.Parent
    end
    return table.concat(parts, ".")
end

local function vec(v)
    if typeof(v) ~= "Vector3" then return nil end
    return {x = round(v.X), y = round(v.Y), z = round(v.Z)}
end

local function angleDeg(a, b)
    if typeof(a) ~= "Vector3" or typeof(b) ~= "Vector3" then return nil end
    if a.Magnitude < 1e-6 or b.Magnitude < 1e-6 then return nil end
    return math.deg(math.acos(math.clamp(a.Unit:Dot(b.Unit), -1, 1)))
end

local function ensureFolders()
    if type(makefolder) ~= "function" then return end
    if type(isfolder) ~= "function" or not safe(function() return isfolder(SAVE_FOLDER) end, false) then
        pcall(makefolder, SAVE_FOLDER)
    end
    if type(isfolder) ~= "function" or not safe(function() return isfolder(REPORT_FOLDER) end, false) then
        pcall(makefolder, REPORT_FOLDER)
    end
end
ensureFolders()

local function serializeSimple(v)
    local tv = typeof(v)
    if tv == "nil" or tv == "boolean" or tv == "number" or tv == "string" then
        return v
    elseif tv == "Vector3" then
        return vec(v)
    elseif tv == "CFrame" then
        return {pos = vec(v.Position), look = vec(v.LookVector)}
    elseif tv == "Instance" then
        return shortPath(v)
    end
    return tostring(v)
end

local function functionFingerprint(fn)
    local out = {
        type = type(fn),
        pointer = tostring(fn),
    }
    if type(fn) ~= "function" then return out end

    if type(iscclosure) == "function" then
        out.cclosure = safe(function() return iscclosure(fn) end, nil)
    end
    if type(islclosure) == "function" then
        out.lclosure = safe(function() return islclosure(fn) end, nil)
    end
    if debug and type(debug.info) == "function" then
        out.source = safe(function() return debug.info(fn, "s") end, nil)
        out.name = safe(function() return debug.info(fn, "n") end, nil)
    end
    return out
end

local function metamethodFingerprint()
    local result = {available = false}
    if type(getrawmetatable) ~= "function" then
        result.reason = "getrawmetatable no disponible"
        return result
    end

    local mt = safe(function() return getrawmetatable(game) end, nil)
    if type(mt) ~= "table" then
        result.reason = "No se pudo leer raw metatable"
        return result
    end

    result.available = true
    result.namecall = functionFingerprint(rawget(mt, "__namecall"))
    result.index = functionFingerprint(rawget(mt, "__index"))
    return result
end

local function fpString(fp, field)
    if type(fp) ~= "table" or not fp.available then return "N/D" end
    local v = fp[field]
    if type(v) ~= "table" then return "N/D" end
    return table.concat({
        tostring(v.pointer or "?"),
        "C=" .. tostring(v.cclosure),
        "L=" .. tostring(v.lclosure),
        "src=" .. tostring(v.source or "?"),
        "name=" .. tostring(v.name or "?")
    }, " | ")
end

local function compareFingerprints(base, current)
    local result = {
        available = false,
        namecallChanged = nil,
        indexChanged = nil,
    }
    if type(base) ~= "table" or type(current) ~= "table"
        or not base.available or not current.available then
        return result
    end

    result.available = true
    result.namecallChanged = fpString(base, "namecall") ~= fpString(current, "namecall")
    result.indexChanged = fpString(base, "index") ~= fpString(current, "index")
    return result
end

local function getEquippedTool()
    local char = player.Character
    if not char then return nil end
    return char:FindFirstChildOfClass("Tool")
end

local function relevantWeaponObject(obj)
    if not obj then return false end
    if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction")
        or obj:IsA("Sound") or obj:IsA("Beam") or obj:IsA("Trail")
        or obj:IsA("Attachment") or obj:IsA("ValueBase") then
        return true
    end

    local n = string.lower(obj.Name)
    return string.find(n, "shot", 1, true)
        or string.find(n, "beam", 1, true)
        or string.find(n, "bullet", 1, true)
        or string.find(n, "projectile", 1, true)
        or string.find(n, "throw", 1, true)
        or string.find(n, "knife", 1, true)
        or string.find(n, "ray", 1, true)
end

local function snapshotWeaponSignals(tool)
    local list = {}
    if not tool then return list end

    for _, obj in ipairs(safe(function() return tool:GetDescendants() end, {}) or {}) do
        if relevantWeaponObject(obj) then
            local item = {
                path = shortPath(obj),
                name = obj.Name,
                class = obj.ClassName,
            }

            if obj:IsA("Sound") then
                item.soundId = tostring(obj.SoundId)
                item.volume = round(obj.Volume)
                item.playing = safe(function() return obj.IsPlaying or obj.Playing end, false)
                item.timePosition = round(safe(function() return obj.TimePosition end, 0))
            elseif obj:IsA("Beam") or obj:IsA("Trail") then
                item.enabled = safe(function() return obj.Enabled end, nil)
            elseif obj:IsA("ValueBase") then
                item.value = serializeSimple(safe(function() return obj.Value end, nil))
            end

            local attrs = safe(function() return obj:GetAttributes() end, {}) or {}
            if next(attrs) then
                item.attributes = {}
                for k, v in pairs(attrs) do
                    item.attributes[k] = serializeSimple(v)
                end
            end

            table.insert(list, item)
        end
    end

    table.sort(list, function(a, b)
        if a.path == b.path then return a.class < b.class end
        return a.path < b.path
    end)
    return list
end

local function snapshotToolState(tool)
    if not tool then return nil end

    local out = {
        name = tool.Name,
        path = shortPath(tool),
        attributes = {},
        values = {},
        signals = snapshotWeaponSignals(tool),
    }

    for k, v in pairs(safe(function() return tool:GetAttributes() end, {}) or {}) do
        out.attributes[k] = serializeSimple(v)
    end

    for _, obj in ipairs(safe(function() return tool:GetDescendants() end, {}) or {}) do
        if obj:IsA("ValueBase") then
            out.values[shortPath(obj)] = serializeSimple(safe(function() return obj.Value end, nil))
        end
    end

    return out
end

local function stableString(v)
    if type(v) == "table" then
        return safe(function() return HttpService:JSONEncode(v) end, tostring(v))
    end
    return tostring(v)
end

local function diffMap(prefix, a, b, out)
    local seen = {}
    for k, v in pairs(a or {}) do
        seen[k] = true
        local av = stableString(v)
        local bv = stableString((b or {})[k])
        if av ~= bv then
            table.insert(out, prefix .. " " .. tostring(k) .. ": " .. av .. " -> " .. bv)
        end
    end
    for k, v in pairs(b or {}) do
        if not seen[k] then
            table.insert(out, prefix .. " " .. tostring(k) .. ": <nil> -> " .. stableString(v))
        end
    end
end

local function diffTool(before, after)
    local out = {}
    if not before and not after then return out end
    if not before or not after then
        table.insert(out, "Tool apareció/desapareció")
        return out
    end

    diffMap("Attr", before.attributes, after.attributes, out)
    diffMap("Value", before.values, after.values, out)

    local beforeSignals = {}
    local afterSignals = {}
    for _, item in ipairs(before.signals or {}) do
        beforeSignals[item.path] = item
    end
    for _, item in ipairs(after.signals or {}) do
        afterSignals[item.path] = item
    end
    diffMap("Signal", beforeSignals, afterSignals, out)

    return out
end

local function readMouse()
    local out = {}
    local hit = safe(function() return mouse.Hit end, nil)
    local target = safe(function() return mouse.Target end, nil)

    if typeof(hit) == "CFrame" then
        out.hit = hit
        out.hitPos = vec(hit.Position)
    end
    if typeof(target) == "Instance" then
        out.target = target
        out.targetPath = shortPath(target)
    end
    return out
end

local function shotContext()
    camera = Workspace.CurrentCamera or camera
    local cf = camera and camera.CFrame or CFrame.new()
    local tool = getEquippedTool()
    local m = readMouse()

    local out = {
        clock = os.clock(),
        cameraPos = cf.Position,
        cameraLook = cf.LookVector,
        cameraPosJson = vec(cf.Position),
        cameraLookJson = vec(cf.LookVector),
        mouseHit = m.hit,
        mouseHitJson = m.hitPos,
        mouseTarget = m.target,
        mouseTargetPath = m.targetPath,
        tool = tool,
        toolName = tool and tool.Name or "nil",
        toolState = snapshotToolState(tool),
    }

    if m.hit then
        out.cameraToMouseDeg = round(angleDeg(cf.LookVector, m.hit.Position - cf.Position), 3)
    end
    return out
end

local function publicContext(ctx)
    if not ctx then return nil end
    return {
        clock = round(ctx.clock, 4),
        cameraPos = ctx.cameraPosJson,
        cameraLook = ctx.cameraLookJson,
        mouseHit = ctx.mouseHitJson,
        mouseTarget = ctx.mouseTargetPath,
        tool = ctx.toolName,
        cameraToMouseDeg = ctx.cameraToMouseDeg,
        toolState = ctx.toolState,
    }
end

local state = {
    alive = true,
    connections = {},
    mode = nil,
    baselineCurrent = nil,
    baselineSetAt = nil,
    rolling = nil,
    pendingMouse = nil,
    lastShot = nil,
    lastShotAt = 0,
    status = "Listo",
    modes = {
        XERO = {
            shots = {},
            baseline = nil,
            postHubFingerprint = nil,
            started = nil,
        },
        YISUS = {
            shots = {},
            baseline = nil,
            postHubFingerprint = nil,
            started = nil,
        },
    },
    humanoids = setmetatable({}, {__mode = "k"}),
}

local function track(c)
    if c then table.insert(state.connections, c) end
    return c
end

local function setStatus(msg)
    state.status = msg
    if state.statusLabel then state.statusLabel.Text = msg end
end

local function sanitize(value, seen)
    local tv = typeof(value)
    if tv == "nil" or tv == "boolean" or tv == "number" or tv == "string" then
        return value
    elseif tv == "Vector3" then
        return vec(value)
    elseif tv == "CFrame" then
        return {pos = vec(value.Position), look = vec(value.LookVector)}
    elseif tv == "Instance" then
        return shortPath(value)
    elseif tv ~= "table" then
        return tostring(value)
    end

    seen = seen or {}
    if seen[value] then return "<cycle>" end
    seen[value] = true

    local out = {}
    for k, v in pairs(value) do
        if not (type(k) == "string" and string.sub(k, 1, 1) == "_") then
            out[k] = sanitize(v, seen)
        end
    end
    seen[value] = nil
    return out
end

local function saveState()
    if type(writefile) ~= "function" then return false end
    ensureFolders()
    local payload = sanitize({
        version = 3,
        modes = state.modes,
    })
    local encoded = safe(function() return HttpService:JSONEncode(payload) end, nil)
    if not encoded then return false end
    return pcall(writefile, STATE_FILE, encoded)
end

local function loadState()
    if type(isfile) ~= "function" or type(readfile) ~= "function" then return end
    if not safe(function() return isfile(STATE_FILE) end, false) then return end
    local raw = safe(function() return readfile(STATE_FILE) end, nil)
    if type(raw) ~= "string" then return end
    local decoded = safe(function() return HttpService:JSONDecode(raw) end, nil)
    if type(decoded) ~= "table" or type(decoded.modes) ~= "table" then return end

    for _, modeName in ipairs({"XERO", "YISUS"}) do
        local src = decoded.modes[modeName]
        if type(src) == "table" then
            state.modes[modeName].shots = type(src.shots) == "table" and src.shots or {}
            state.modes[modeName].baseline = src.baseline
            state.modes[modeName].postHubFingerprint = src.postHubFingerprint
            state.modes[modeName].started = src.started
        end
    end
end
loadState()

local function yn(v)
    if v == nil then return "N/D" end
    return v and "SÍ" or "NO"
end

local function num(v)
    return type(v) == "number" and string.format("%.2f", v) or "N/D"
end

local function avgFromShots(shots, key)
    local sum, count = 0, 0
    for _, s in ipairs(shots or {}) do
        local v = s[key]
        if type(v) == "number" then
            sum += v
            count += 1
        end
    end
    return count > 0 and sum / count or nil
end

local function reportPath(modeName)
    return modeName == "XERO" and XERO_REPORT or YISUS_REPORT
end

local function buildReport(modeName)
    local mode = state.modes[modeName]
    if not mode then return "Modo inválido" end

    local diff = compareFingerprints(mode.baseline, mode.postHubFingerprint)
    local shots = mode.shots or {}

    local damageCount, localObjectCount, toolDiffCount = 0, 0, 0
    local victimAngles = {}

    for _, s in ipairs(shots) do
        toolDiffCount += #(s.toolDiff or {})
        localObjectCount += #(s.localObjects or {})
        for _, d in ipairs(s.damageCandidates or {}) do
            damageCount += 1
            if type(d.cameraToVictimDeg) == "number" then
                table.insert(victimAngles, d.cameraToVictimDeg)
            end
        end
    end

    local victimAvg = nil
    if #victimAngles > 0 then
        local total = 0
        for _, v in ipairs(victimAngles) do total += v end
        victimAvg = total / #victimAngles
    end

    local lines = {}
    table.insert(lines, "===== XERO AIM COMPARE LAB v3 · " .. modeName .. " =====")
    table.insert(lines, "Creator: Kev")
    table.insert(lines, "PlaceId: " .. tostring(game.PlaceId))
    table.insert(lines, "JobId: " .. tostring(game.JobId))
    table.insert(lines, "User: " .. tostring(player.Name))
    table.insert(lines, "Shots captured: " .. tostring(#shots))
    table.insert(lines, "")

    table.insert(lines, "[BASELINE DE ESTA SESIÓN]")
    if mode.baseline then
        table.insert(lines, "__namecall baseline: " .. fpString(mode.baseline, "namecall"))
        table.insert(lines, "__index baseline: " .. fpString(mode.baseline, "index"))
    else
        table.insert(lines, "NO HAY BASELINE PARA ESTE MODO")
    end

    table.insert(lines, "")
    table.insert(lines, "[HUELLA DESPUÉS DE CARGAR " .. modeName .. "]")
    if mode.postHubFingerprint then
        table.insert(lines, "__namecall current: " .. fpString(mode.postHubFingerprint, "namecall"))
        table.insert(lines, "__index current: " .. fpString(mode.postHubFingerprint, "index"))
    else
        table.insert(lines, "N/D")
    end
    table.insert(lines, "__namecall changed vs same-session baseline: " .. yn(diff.namecallChanged))
    table.insert(lines, "__index changed vs same-session baseline: " .. yn(diff.indexChanged))

    table.insert(lines, "")
    table.insert(lines, "[RESUMEN]")
    table.insert(lines, "Avg PRE camera -> Mouse.Hit: " .. num(avgFromShots(shots, "preCameraToMouseDeg")) .. " deg")
    table.insert(lines, "Avg POST camera -> Mouse.Hit: " .. num(avgFromShots(shots, "postCameraToMouseDeg")) .. " deg")
    table.insert(lines, "Avg camera movement @50ms: " .. num(avgFromShots(shots, "cameraDelta50ms")) .. " deg")
    table.insert(lines, "Avg camera movement @150ms: " .. num(avgFromShots(shots, "cameraDelta150ms")) .. " deg")
    table.insert(lines, "Avg camera -> damaged victim candidate: " .. num(victimAvg) .. " deg")
    table.insert(lines, "Damage candidates after local shots: " .. tostring(damageCount))
    table.insert(lines, "STRICT local weapon objects added: " .. tostring(localObjectCount))
    table.insert(lines, "Tool/weapon signal changes: " .. tostring(toolDiffCount))

    table.insert(lines, "")
    table.insert(lines, "[IMPORTANTE]")
    table.insert(lines, "- 'STRICT local weapon objects' SOLO cuenta objetos creados bajo TU Character/Tool.")
    table.insert(lines, "- Beams/Parts sueltos creados directamente en Workspace se omiten si no puede atribuirlos al jugador local.")
    table.insert(lines, "- 'Damage candidate' significa daño observado poco después de TU Tool.Activated; no afirma causalidad del servidor.")

    for i, s in ipairs(shots) do
        table.insert(lines, "")
        table.insert(lines, string.format("[SHOT #%d] trigger=%s tool=%s", i, tostring(s.trigger), tostring(s.tool)))
        table.insert(lines, "  PRE  cam->mouse=" .. num(s.preCameraToMouseDeg)
            .. "° Mouse.Target=" .. tostring(s.pre and s.pre.mouseTarget or "nil"))
        table.insert(lines, "  POST cam->mouse=" .. num(s.postCameraToMouseDeg)
            .. "° Mouse.Target=" .. tostring(s.post and s.post.mouseTarget or "nil"))
        table.insert(lines, "  camΔ50=" .. num(s.cameraDelta50ms) .. "° camΔ150=" .. num(s.cameraDelta150ms) .. "°")

        local signals = s.pre and s.pre.toolState and s.pre.toolState.signals or {}
        if #signals > 0 then
            table.insert(lines, "  LOCAL WEAPON SIGNAL INVENTORY (pre-shot):")
            for _, sig in ipairs(signals) do
                local extra = ""
                if sig.soundId then extra ..= " SoundId=" .. tostring(sig.soundId) end
                if sig.playing ~= nil then extra ..= " Playing=" .. tostring(sig.playing) end
                if sig.enabled ~= nil then extra ..= " Enabled=" .. tostring(sig.enabled) end
                if sig.value ~= nil then extra ..= " Value=" .. stableString(sig.value) end
                table.insert(lines, "    " .. sig.class .. " | " .. sig.path .. extra)
            end
        end

        for _, d in ipairs(s.toolDiff or {}) do
            table.insert(lines, "  TOOL DIFF: " .. tostring(d))
        end

        for _, obj in ipairs(s.localObjects or {}) do
            table.insert(lines, "  LOCAL ADDED: " .. tostring(obj.class) .. " | " .. tostring(obj.path)
                .. " | +" .. tostring(obj.delay) .. "s")
        end

        for _, d in ipairs(s.damageCandidates or {}) do
            table.insert(lines, "  DAMAGE CANDIDATE: " .. tostring(d.player)
                .. " -" .. tostring(d.delta)
                .. "HP | cam->victim=" .. num(d.cameraToVictimDeg)
                .. "° | +" .. tostring(d.delay) .. "s")
        end
    end

    return table.concat(lines, "\n")
end

local function writeReport(modeName)
    if type(writefile) ~= "function" then return false end
    ensureFolders()
    return pcall(writefile, reportPath(modeName), buildReport(modeName))
end

local function flush()
    saveState()
    if state.mode then writeReport(state.mode) end
end

local function setBaseline()
    state.baselineCurrent = metamethodFingerprint()
    state.baselineSetAt = os.clock()
    setStatus("Baseline fijado · ahora carga el hub")
end

local function startMode(modeName)
    if not state.baselineCurrent then
        setStatus("PRIMERO fija baseline antes de cargar el hub")
        return
    end

    local mode = state.modes[modeName]
    mode.shots = {}
    mode.baseline = sanitize(state.baselineCurrent)
    mode.postHubFingerprint = sanitize(metamethodFingerprint())
    mode.started = os.time()
    state.mode = modeName
    state.lastShot = nil
    state.lastShotAt = 0

    local diff = compareFingerprints(mode.baseline, mode.postHubFingerprint)
    setStatus(modeName .. " escaneando · NC=" .. yn(diff.namecallChanged) .. " IX=" .. yn(diff.indexChanged))
    flush()
end

-- Snapshot rodante ANTES del siguiente disparo.
local rollingAccumulator = 0
track(RunService.Heartbeat:Connect(function(dt)
    if not state.alive then return end
    rollingAccumulator += dt
    if rollingAccumulator >= 0.03 then
        rollingAccumulator = 0
        state.rolling = shotContext()
    end
end))

local function recordShot(trigger)
    if not state.mode then return end
    local now = os.clock()
    if now - state.lastShotAt < 0.07 then return end
    state.lastShotAt = now

    local pre = nil
    if state.pendingMouse and now - state.pendingMouse.clock <= 0.20 then
        pre = state.pendingMouse
    elseif state.rolling and now - state.rolling.clock <= 0.12 then
        pre = state.rolling
    else
        pre = shotContext()
    end

    local post0 = shotContext()
    local shot = {
        trigger = trigger,
        t = now,
        tool = post0.toolName,
        pre = publicContext(pre),
        post = publicContext(post0),
        preCameraToMouseDeg = pre and pre.cameraToMouseDeg or nil,
        postCameraToMouseDeg = post0.cameraToMouseDeg,
        cameraDelta50ms = nil,
        cameraDelta150ms = nil,
        toolDiff = {},
        localObjects = {},
        damageCandidates = {},
        _cameraPos = post0.cameraPos,
        _cameraLook = post0.cameraLook,
        _toolRef = post0.tool,
    }

    table.insert(state.modes[state.mode].shots, shot)
    state.lastShot = shot
    flush()

    task.delay(0.05, function()
        if not state.alive or not shot then return end
        local cam = Workspace.CurrentCamera
        if cam then
            shot.cameraDelta50ms = round(angleDeg(shot._cameraLook, cam.CFrame.LookVector), 3)
        end
        flush()
    end)

    task.delay(0.15, function()
        if not state.alive or not shot then return end
        local cam = Workspace.CurrentCamera
        if cam then
            shot.cameraDelta150ms = round(angleDeg(shot._cameraLook, cam.CFrame.LookVector), 3)
        end

        local after = shotContext()
        shot.post = publicContext(after)
        shot.postCameraToMouseDeg = after.cameraToMouseDeg

        local beforeTool = shot.pre and shot.pre.toolState or nil
        local afterTool = after.toolState
        shot.toolDiff = diffTool(beforeTool, afterTool)
        flush()
    end)
end

-- MouseDown guarda intención PRE. Tool.Activated es el disparo principal.
track(mouse.Button1Down:Connect(function()
    state.pendingMouse = shotContext()
    task.delay(0.10, function()
        if state.mode and os.clock() - state.lastShotAt > 0.09 then
            -- Fallback para armas que no disparan Tool.Activated.
            recordShot("Mouse.Button1Down fallback")
        end
    end)
end))

local toolConnections = setmetatable({}, {__mode = "k"})
local function bindTool(tool)
    if not tool or not tool:IsA("Tool") or toolConnections[tool] then return end
    local c = tool.Activated:Connect(function()
        recordShot("Tool.Activated")
    end)
    toolConnections[tool] = c
    track(c)
end

local function isStrictLocalWeaponAdded(obj)
    local char = player.Character
    if not char or not obj then return false end
    if not obj:IsDescendantOf(char) then return false end

    local tool = obj:FindFirstAncestorWhichIsA("Tool")
    if not tool then return false end
    return relevantWeaponObject(obj)
end

local function bindCharacter(char)
    for _, obj in ipairs(char:GetChildren()) do
        if obj:IsA("Tool") then bindTool(obj) end
    end

    track(char.ChildAdded:Connect(function(obj)
        if obj:IsA("Tool") then bindTool(obj) end
    end))

    track(char.DescendantAdded:Connect(function(obj)
        if not state.mode or not state.lastShot then return end
        local dt = os.clock() - (state.lastShot.t or 0)
        if dt < 0 or dt > 0.40 then return end
        if not isStrictLocalWeaponAdded(obj) then return end
        if #state.lastShot.localObjects >= 20 then return end

        table.insert(state.lastShot.localObjects, {
            delay = round(dt, 3),
            class = obj.ClassName,
            name = obj.Name,
            path = shortPath(obj),
        })
        flush()
    end))
end

if player.Character then bindCharacter(player.Character) end
track(player.CharacterAdded:Connect(bindCharacter))

local function attachHumanoid(p, hum)
    if not hum or state.humanoids[hum] then return end
    state.humanoids[hum] = true
    local last = hum.Health

    track(hum.HealthChanged:Connect(function(newHealth)
        local old = last
        last = newHealth

        local shot = state.lastShot
        if not state.mode or not shot or newHealth >= old then return end

        local dt = os.clock() - (shot.t or 0)
        if dt < 0 or dt > 0.75 then return end

        local char = p.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local angle = nil
        if hrp and shot._cameraPos and shot._cameraLook then
            angle = round(angleDeg(shot._cameraLook, hrp.Position - shot._cameraPos), 3)
        end

        table.insert(shot.damageCandidates, {
            player = p.Name,
            userId = p.UserId,
            delta = round(old - newHealth, 2),
            healthAfter = round(newHealth, 2),
            delay = round(dt, 3),
            cameraToVictimDeg = angle,
        })
        flush()
    end))
end

local function watchPlayer(p)
    if p == player then return end
    local function onCharacter(char)
        local hum = char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid", 5)
        if hum then attachHumanoid(p, hum) end
    end
    if p.Character then task.defer(onCharacter, p.Character) end
    track(p.CharacterAdded:Connect(onCharacter))
end

for _, p in ipairs(Players:GetPlayers()) do watchPlayer(p) end
track(Players.PlayerAdded:Connect(watchPlayer))

-- ================= UI =================
local guiParent = player:WaitForChild("PlayerGui")
if type(gethui) == "function" then
    guiParent = safe(gethui, guiParent)
else
    guiParent = CoreGui
end

local oldGui = safe(function() return guiParent:FindFirstChild("XeroAimCompareLabV3") end, nil)
if oldGui then oldGui:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name = "XeroAimCompareLabV3"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 2147483000
gui.Parent = guiParent

local main = Instance.new("Frame")
main.Size = UDim2.fromOffset(560, 430)
main.Position = UDim2.new(0.5, -280, 0.5, -215)
main.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
main.BorderSizePixel = 0
main.Parent = gui
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 16)

local stroke = Instance.new("UIStroke", main)
stroke.Color = Color3.fromRGB(55, 55, 55)
stroke.Thickness = 1

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -30, 0, 28)
title.Position = UDim2.fromOffset(15, 11)
title.BackgroundTransparency = 1
title.Text = "XERO | AIM COMPARE LAB v3"
title.TextColor3 = Color3.fromRGB(245, 245, 245)
title.Font = Enum.Font.GothamBold
title.TextSize = 17
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = main

local sub = Instance.new("TextLabel")
sub.Size = UDim2.new(1, -30, 0, 18)
sub.Position = UDim2.fromOffset(15, 37)
sub.BackgroundTransparency = 1
sub.Text = "by Kev · baseline real + filtro local estricto"
sub.TextColor3 = Color3.fromRGB(135, 135, 135)
sub.Font = Enum.Font.Gotham
sub.TextSize = 11
sub.TextXAlignment = Enum.TextXAlignment.Left
sub.Parent = main

local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, -30, 0, 22)
statusLabel.Position = UDim2.fromOffset(15, 61)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = state.status
statusLabel.TextColor3 = Color3.fromRGB(205, 205, 205)
statusLabel.Font = Enum.Font.GothamMedium
statusLabel.TextSize = 12
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.Parent = main
state.statusLabel = statusLabel

local buttons = Instance.new("Frame")
buttons.Size = UDim2.new(1, -30, 0, 76)
buttons.Position = UDim2.fromOffset(15, 90)
buttons.BackgroundTransparency = 1
buttons.Parent = main

local grid = Instance.new("UIGridLayout", buttons)
grid.CellSize = UDim2.new(1/3, -6, 0, 32)
grid.CellPadding = UDim2.fromOffset(8, 8)
grid.SortOrder = Enum.SortOrder.LayoutOrder

local function button(text, order, callback)
    local b = Instance.new("TextButton")
    b.LayoutOrder = order
    b.Text = text
    b.BackgroundColor3 = Color3.fromRGB(23, 23, 23)
    b.TextColor3 = Color3.fromRGB(235, 235, 235)
    b.Font = Enum.Font.GothamMedium
    b.TextSize = 11
    b.Parent = buttons
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 9)
    local st = Instance.new("UIStroke", b)
    st.Color = Color3.fromRGB(48, 48, 48)
    st.Thickness = 1
    b.MouseButton1Click:Connect(callback)
    return b
end

button("1 · FIJAR BASELINE", 1, setBaseline)
button("2 · ESCANEAR XERO", 2, function() startMode("XERO") end)
button("2 · ESCANEAR YISUS", 3, function() startMode("YISUS") end)
button("DETENER", 4, function()
    state.mode = nil
    state.lastShot = nil
    setStatus("Captura detenida")
end)
button("GUARDAR REPORTES", 5, function()
    local okX = writeReport("XERO")
    local okY = writeReport("YISUS")
    setStatus("Xero=" .. (okX and "OK" or "ERR") .. " · Yisus=" .. (okY and "OK" or "ERR"))
end)
button("BORRAR CAPTURAS", 6, function()
    state.modes.XERO = {shots = {}, baseline = nil, postHubFingerprint = nil, started = nil}
    state.modes.YISUS = {shots = {}, baseline = nil, postHubFingerprint = nil, started = nil}
    state.mode = nil
    state.lastShot = nil
    saveState()
    writeReport("XERO")
    writeReport("YISUS")
    setStatus("Capturas borradas")
end)

local info = Instance.new("TextBox")
info.Size = UDim2.new(1, -30, 1, -184)
info.Position = UDim2.fromOffset(15, 176)
info.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
info.BorderSizePixel = 0
info.TextColor3 = Color3.fromRGB(190, 190, 190)
info.Font = Enum.Font.Code
info.TextSize = 11
info.MultiLine = true
info.TextWrapped = true
info.ClearTextOnFocus = false
info.TextEditable = false
info.TextXAlignment = Enum.TextXAlignment.Left
info.TextYAlignment = Enum.TextYAlignment.Top
info.Text = [[FLUJO CORRECTO POR SESIÓN:

1) Ejecuta ESTE LAB antes del hub.
2) Pulsa FIJAR BASELINE.
3) Carga Xero o Yisus.
4) Pulsa su botón ESCANEAR.
5) Dispara 3-5 veces.

Xero:
XeroHub/AimReports/Xero_Report.txt

Yisus:
XeroHub/AimReports/Yisus_Report.txt

El reporte se actualiza después de cada disparo/evento.
Si Xero te expulsa, la última escritura completada queda guardada.

v3 NO cuenta Trails/Beams/Remotes de otros jugadores.
Solo objetos creados bajo tu Character/Tool.]]

info.Parent = main
Instance.new("UICorner", info).CornerRadius = UDim.new(0, 10)
local padding = Instance.new("UIPadding", info)
padding.PaddingLeft = UDim.new(0, 9)
padding.PaddingRight = UDim.new(0, 9)
padding.PaddingTop = UDim.new(0, 8)
padding.PaddingBottom = UDim.new(0, 8)

-- Drag
do
    local dragging = false
    local dragStart, startPos, dragInput

    title.Active = true
    title.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = main.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    title.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)

    track(UserInputService.InputChanged:Connect(function(input)
        if dragging and input == dragInput then
            local d = input.Position - dragStart
            main.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + d.X,
                startPos.Y.Scale,
                startPos.Y.Offset + d.Y
            )
        end
    end))
end

local env = (getgenv and getgenv()) or _G
env.XeroAimCompareLabV3 = {
    SetBaseline = setBaseline,
    ScanXero = function() startMode("XERO") end,
    ScanYisus = function() startMode("YISUS") end,
    ReportXero = function() return buildReport("XERO") end,
    ReportYisus = function() return buildReport("YISUS") end,
    SaveReports = function()
        return writeReport("XERO"), writeReport("YISUS")
    end,
    Destroy = function()
        state.alive = false
        for _, c in ipairs(state.connections) do
            pcall(function() c:Disconnect() end)
        end
        pcall(function() gui:Destroy() end)
    end,
}

setStatus("Ejecuta lab → FIJAR BASELINE → carga hub → ESCANEAR")
