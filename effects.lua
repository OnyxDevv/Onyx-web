-- Xero | AIM COMPARE LAB
-- Creator: Kev
-- Objetivo: comparar de forma pasiva el comportamiento observable de distintos sistemas de aim.
-- Genera reportes separados para Xero y Yisus y los guarda tras cada disparo.
-- No instala hooks de __namecall/__index ni modifica raycasts/remotes.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera
local mouse = player:GetMouse()

local SAVE_FOLDER = "XeroHub"
local SAVE_FILE = SAVE_FOLDER .. "/AimCompareLab.json"
local REPORT_FOLDER = SAVE_FOLDER .. "/AimReports"
local XERO_REPORT_FILE = REPORT_FOLDER .. "/Xero_Report.txt"
local YISUS_REPORT_FILE = REPORT_FOLDER .. "/Yisus_Report.txt"
local SESSION_VERSION = 2

local state = {
    alive = true,
    mode = nil,
    modes = {
        BASELINE = {shots = {}, started = nil, fingerprint = nil},
        XERO = {shots = {}, started = nil, fingerprint = nil},
        YISUS = {shots = {}, started = nil, fingerprint = nil},
    },
    connections = {},
    humanoids = setmetatable({}, {__mode = "k"}),
    lastShot = nil,
    lastShotAt = 0,
    status = "Listo",
}

-- Forward declarations: se usan desde markMode/recordShot antes de que
-- aparezca su implementación más abajo en el archivo.
local writeModeReport
local flushActiveReport

local function track(c)
    if c then table.insert(state.connections, c) end
    return c
end

local function safe(fn, default)
    local ok, value = pcall(fn)
    if ok then return value end
    return default
end

local function round(n, p)
    if type(n) ~= "number" then return n end
    local m = 10 ^ (p or 2)
    return math.floor(n * m + 0.5) / m
end

local function vec(v)
    if typeof(v) ~= "Vector3" then return nil end
    return {x = round(v.X, 3), y = round(v.Y, 3), z = round(v.Z, 3)}
end

local function angleDeg(a, b)
    if typeof(a) ~= "Vector3" or typeof(b) ~= "Vector3" then return nil end
    if a.Magnitude < 1e-6 or b.Magnitude < 1e-6 then return nil end
    local dot = math.clamp(a.Unit:Dot(b.Unit), -1, 1)
    return math.deg(math.acos(dot))
end

local function shortPath(obj)
    if not obj then return "nil" end
    local parts = {}
    local cur = obj
    for _ = 1, 6 do
        if not cur then break end
        table.insert(parts, 1, cur.Name)
        cur = cur.Parent
    end
    return table.concat(parts, ".")
end

local function fnFingerprint(fn)
    local out = {kind = type(fn), tostring = tostring(fn)}
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
        result.reason = "No se pudo leer el metatable"
        return result
    end

    result.available = true
    result.namecall = fnFingerprint(rawget(mt, "__namecall"))
    result.index = fnFingerprint(rawget(mt, "__index"))
    return result
end

local function fingerprintKey(fp, field)
    if type(fp) ~= "table" or not fp.available then return "N/A" end
    local v = fp[field]
    if type(v) ~= "table" then return "N/A" end
    return table.concat({
        tostring(v.tostring or "?"),
        tostring(v.cclosure),
        tostring(v.lclosure),
        tostring(v.source or "?"),
        tostring(v.name or "?")
    }, "|")
end

local function getEquippedTool()
    local char = player.Character
    return char and char:FindFirstChildOfClass("Tool") or nil
end

local function snapshotTool(tool)
    if not tool then return nil end
    local snap = {
        name = tool.Name,
        path = shortPath(tool),
        attrs = {},
        values = {},
    }

    for k, v in pairs(safe(function() return tool:GetAttributes() end, {}) or {}) do
        local tv = typeof(v)
        if tv == "Vector3" then
            snap.attrs[k] = vec(v)
        elseif tv == "CFrame" then
            snap.attrs[k] = {pos = vec(v.Position), look = vec(v.LookVector)}
        elseif tv == "Instance" then
            snap.attrs[k] = shortPath(v)
        else
            snap.attrs[k] = tostring(v)
        end
    end

    local descendants = safe(function() return tool:GetDescendants() end, {}) or {}
    for _, obj in ipairs(descendants) do
        if obj:IsA("ValueBase") then
            local value = safe(function() return obj.Value end, nil)
            local tv = typeof(value)
            if tv == "Vector3" then
                value = vec(value)
            elseif tv == "CFrame" then
                value = {pos = vec(value.Position), look = vec(value.LookVector)}
            elseif tv == "Instance" then
                value = shortPath(value)
            else
                value = tostring(value)
            end
            snap.values[shortPath(obj)] = value
        end
    end
    return snap
end

local function serializeValue(v)
    if type(v) == "table" then
        return safe(function() return HttpService:JSONEncode(v) end, tostring(v))
    end
    return tostring(v)
end

local function diffTool(before, after)
    local diffs = {}
    if not before and not after then return diffs end
    if not before or not after then
        table.insert(diffs, "Tool apareció/desapareció")
        return diffs
    end

    local function compareMaps(prefix, a, b)
        local seen = {}
        for k, v in pairs(a or {}) do
            seen[k] = true
            local av, bv = serializeValue(v), serializeValue((b or {})[k])
            if av ~= bv then
                table.insert(diffs, prefix .. " " .. k .. ": " .. av .. " -> " .. bv)
            end
        end
        for k, v in pairs(b or {}) do
            if not seen[k] then
                table.insert(diffs, prefix .. " " .. k .. ": <nil> -> " .. serializeValue(v))
            end
        end
    end

    compareMaps("Attr", before.attrs, after.attrs)
    compareMaps("Value", before.values, after.values)
    return diffs
end

local function snapshotPlayers()
    local out = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player and p.Character then
            local hrp = p.Character:FindFirstChild("HumanoidRootPart")
            local hum = p.Character:FindFirstChildOfClass("Humanoid")
            if hrp and hum then
                out[tostring(p.UserId)] = {
                    name = p.Name,
                    pos = vec(hrp.Position),
                    rawPos = hrp.Position,
                    health = round(hum.Health, 2),
                }
            end
        end
    end
    return out
end

local function readMouse()
    local data = {}
    local hit = safe(function() return mouse.Hit end, nil)
    local target = safe(function() return mouse.Target end, nil)
    if typeof(hit) == "CFrame" then
        data.hitPos = vec(hit.Position)
        data.rawHitPos = hit.Position
    end
    if typeof(target) == "Instance" then
        data.target = shortPath(target)
    end
    return data
end

local function activeModeData()
    return state.mode and state.modes[state.mode] or nil
end

local function setStatus(text)
    state.status = text
    if state.statusLabel then
        state.statusLabel.Text = text
    end
end

local function sanitizeForJson(value, seen)
    local tv = typeof(value)
    if tv == "nil" or tv == "boolean" or tv == "number" or tv == "string" then
        return value
    end
    if tv == "Vector3" then return vec(value) end
    if tv == "CFrame" then return {pos = vec(value.Position), look = vec(value.LookVector)} end
    if tv == "Instance" then return shortPath(value) end
    if tv ~= "table" then return tostring(value) end

    seen = seen or {}
    if seen[value] then return "<cycle>" end
    seen[value] = true

    local out = {}
    for k, v in pairs(value) do
        if type(k) == "string" and string.sub(k, 1, 1) == "_" then
            -- Campos runtime: no se guardan, pero tampoco se modifican en memoria.
        else
            out[k] = sanitizeForJson(v, seen)
        end
    end
    seen[value] = nil
    return out
end

local function saveState()
    if type(writefile) ~= "function" then return false end
    if type(makefolder) == "function" then
        if type(isfolder) ~= "function" or not safe(function() return isfolder(SAVE_FOLDER) end, false) then
            pcall(makefolder, SAVE_FOLDER)
        end
        if type(isfolder) ~= "function" or not safe(function() return isfolder(REPORT_FOLDER) end, false) then
            pcall(makefolder, REPORT_FOLDER)
        end
    end

    local data = sanitizeForJson({
        version = SESSION_VERSION,
        modes = state.modes,
    })

    local encoded = safe(function() return HttpService:JSONEncode(data) end, nil)
    if not encoded then return false end
    return pcall(writefile, SAVE_FILE, encoded)
end

local function loadState()
    if type(readfile) ~= "function" or type(isfile) ~= "function" then return end
    if not safe(function() return isfile(SAVE_FILE) end, false) then return end
    local raw = safe(function() return readfile(SAVE_FILE) end, nil)
    if type(raw) ~= "string" or raw == "" then return end
    local decoded = safe(function() return HttpService:JSONDecode(raw) end, nil)
    if type(decoded) ~= "table" or type(decoded.modes) ~= "table" then return end

    for _, name in ipairs({"BASELINE", "XERO", "YISUS"}) do
        local src = decoded.modes[name]
        if type(src) == "table" then
            state.modes[name].shots = type(src.shots) == "table" and src.shots or {}
            state.modes[name].started = src.started
            state.modes[name].fingerprint = src.fingerprint
        end
    end
end

loadState()

local function markMode(name)
    if not state.modes[name] then return end
    state.mode = name
    state.modes[name].started = os.time()
    state.modes[name].fingerprint = metamethodFingerprint()
    setStatus("ESCANEANDO " .. name .. " · dispara 3-5 veces")
    saveState()
    if name == "XERO" or name == "YISUS" then
        writeModeReport(name)
    end
end

local function recordShot(reason)
    local mode = activeModeData()
    if not mode then return end

    local now = os.clock()
    if now - state.lastShotAt < 0.08 then return end
    state.lastShotAt = now

    camera = Workspace.CurrentCamera or camera
    local cf = camera and camera.CFrame or CFrame.new()
    local tool = getEquippedTool()
    local m = readMouse()
    local playersNow = snapshotPlayers()

    local shot = {
        t = round(now, 4),
        reason = reason,
        tool = tool and tool.Name or "nil",
        cameraPos = vec(cf.Position),
        cameraLook = vec(cf.LookVector),
        mouse = {
            hitPos = m.hitPos,
            target = m.target,
        },
        cameraToMouseDeg = nil,
        fingerprint = metamethodFingerprint(),
        toolBefore = snapshotTool(tool),
        toolAfter = nil,
        toolDiff = {},
        damage = {},
        projectiles = {},
        cameraDelta50ms = nil,
        cameraDelta150ms = nil,
        mode = state.mode,
        _cameraPos = cf.Position,
        _cameraLook = cf.LookVector,
        _playersRaw = playersNow,
    }

    if m.rawHitPos then
        shot.cameraToMouseDeg = round(angleDeg(cf.LookVector, m.rawHitPos - cf.Position), 3)
    end

    table.insert(mode.shots, shot)
    state.lastShot = shot
    setStatus(state.mode .. " · disparo #" .. tostring(#mode.shots) .. " capturado")

    -- Guardado CRÍTICO inmediato: si Xero provoca kick tras el disparo,
    -- al menos esta captura base ya quedó escrita.
    saveState()
    flushActiveReport()

    task.delay(0.05, function()
        if not state.alive or not shot then return end
        local cam = Workspace.CurrentCamera
        if cam then
            shot.cameraDelta50ms = round(angleDeg(shot._cameraLook, cam.CFrame.LookVector), 3)
        end
        saveState()
        flushActiveReport()
    end)

    task.delay(0.15, function()
        if not state.alive or not shot then return end
        local cam = Workspace.CurrentCamera
        if cam then
            shot.cameraDelta150ms = round(angleDeg(shot._cameraLook, cam.CFrame.LookVector), 3)
        end
        shot.toolAfter = snapshotTool(getEquippedTool())
        shot.toolDiff = diffTool(shot.toolBefore, shot.toolAfter)
        saveState()
        flushActiveReport()
    end)
end

local function attachHumanoid(p, hum)
    if not hum or state.humanoids[hum] then return end
    state.humanoids[hum] = hum.Health
    local last = hum.Health

    track(hum.HealthChanged:Connect(function(newHealth)
        local old = last
        last = newHealth
        state.humanoids[hum] = newHealth

        local shot = state.lastShot
        if not shot or not state.mode then return end
        local dt = os.clock() - (shot.t or 0)
        if dt < 0 or dt > 0.7 or newHealth >= old then return end

        local uid = tostring(p.UserId)
        local pdata = shot._playersRaw and shot._playersRaw[uid]
        local victimPos = pdata and pdata.rawPos
        local aimAngle = nil
        if victimPos and shot._cameraPos and shot._cameraLook then
            aimAngle = round(angleDeg(shot._cameraLook, victimPos - shot._cameraPos), 3)
        end

        table.insert(shot.damage, {
            player = p.Name,
            delta = round(old - newHealth, 2),
            after = round(newHealth, 2),
            delay = round(dt, 3),
            cameraToVictimDeg = aimAngle,
        })
        saveState()
        flushActiveReport()
    end))
end

local function watchPlayer(p)
    if p == player then return end
    local function onChar(char)
        local hum = char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid", 5)
        if hum then attachHumanoid(p, hum) end
    end
    if p.Character then task.defer(onChar, p.Character) end
    track(p.CharacterAdded:Connect(onChar))
end

for _, p in ipairs(Players:GetPlayers()) do watchPlayer(p) end
track(Players.PlayerAdded:Connect(watchPlayer))

local projectileWords = {
    "bullet", "projectile", "tracer", "beam", "laser", "shot", "ray", "pellet", "knife", "throw"
}
local function projectileLike(obj)
    local name = string.lower(obj.Name)
    for _, w in ipairs(projectileWords) do
        if string.find(name, w, 1, true) then return true end
    end
    if obj:IsA("BasePart") then
        local vel = safe(function() return obj.AssemblyLinearVelocity.Magnitude end, 0)
        if vel and vel > 25 then return true end
    end
    return obj:IsA("Beam") or obj:IsA("Trail")
end

track(Workspace.DescendantAdded:Connect(function(obj)
    local shot = state.lastShot
    if not shot or not state.mode then return end
    local dt = os.clock() - (shot.t or 0)
    if dt < 0 or dt > 0.35 then return end
    if not projectileLike(obj) then return end
    if #shot.projectiles >= 12 then return end

    local item = {
        delay = round(dt, 3),
        class = obj.ClassName,
        name = obj.Name,
        path = shortPath(obj),
    }

    if obj:IsA("BasePart") then
        item.pos = vec(obj.Position)
        item.velocity = vec(obj.AssemblyLinearVelocity)
        if shot._cameraPos and obj.AssemblyLinearVelocity.Magnitude > 0.1 then
            item.cameraToVelocityDeg = round(angleDeg(shot._cameraLook, obj.AssemblyLinearVelocity), 3)
        end
    end

    table.insert(shot.projectiles, item)
    saveState()
    flushActiveReport()
end))

local toolConnections = {}
local function bindTool(tool)
    if not tool or not tool:IsA("Tool") or toolConnections[tool] then return end
    local c = tool.Activated:Connect(function()
        recordShot("Tool.Activated")
    end)
    toolConnections[tool] = c
    track(c)
end

local function bindCharacter(char)
    for _, c in pairs(toolConnections) do
        -- las conexiones viejas quedan en cleanup global
    end
    for _, obj in ipairs(char:GetChildren()) do
        if obj:IsA("Tool") then bindTool(obj) end
    end
    track(char.ChildAdded:Connect(function(obj)
        if obj:IsA("Tool") then bindTool(obj) end
    end))
end

if player.Character then bindCharacter(player.Character) end
track(player.CharacterAdded:Connect(bindCharacter))

track(mouse.Button1Down:Connect(function()
    task.delay(0.015, function()
        if os.clock() - state.lastShotAt > 0.06 then
            recordShot("Mouse.Button1Down")
        end
    end)
end))

local function avg(list)
    local total, count = 0, 0
    for _, n in ipairs(list) do
        if type(n) == "number" then
            total += n
            count += 1
        end
    end
    return count > 0 and total / count or nil
end

local function summarizeMode(name, mode, baselineFp)
    local camMouse, camMove50, camMove150, victimAngles = {}, {}, {}, {}
    local damageCount, projectileCount, toolDiffCount = 0, 0, 0

    for _, s in ipairs(mode.shots or {}) do
        table.insert(camMouse, s.cameraToMouseDeg)
        table.insert(camMove50, s.cameraDelta50ms)
        table.insert(camMove150, s.cameraDelta150ms)
        projectileCount += #(s.projectiles or {})
        toolDiffCount += #(s.toolDiff or {})
        for _, d in ipairs(s.damage or {}) do
            damageCount += 1
            table.insert(victimAngles, d.cameraToVictimDeg)
        end
    end

    local fp = mode.fingerprint
    local baseNC = fingerprintKey(baselineFp, "namecall")
    local baseIX = fingerprintKey(baselineFp, "index")
    local nc = fingerprintKey(fp, "namecall")
    local ix = fingerprintKey(fp, "index")

    return {
        name = name,
        shots = #(mode.shots or {}),
        namecallChanged = baselineFp and baseNC ~= "N/A" and nc ~= "N/A" and nc ~= baseNC or nil,
        indexChanged = baselineFp and baseIX ~= "N/A" and ix ~= "N/A" and ix ~= baseIX or nil,
        avgCameraToMouse = avg(camMouse),
        avgCameraMove50 = avg(camMove50),
        avgCameraMove150 = avg(camMove150),
        avgCameraToVictim = avg(victimAngles),
        damageCount = damageCount,
        projectileCount = projectileCount,
        toolDiffCount = toolDiffCount,
    }
end

local function yn(v)
    if v == nil then return "N/D" end
    return v and "SÍ" or "NO"
end

local function num(v)
    return type(v) == "number" and string.format("%.2f", v) or "N/D"
end

local function buildReport()
    local baseline = state.modes.BASELINE
    local xero = summarizeMode("XERO", state.modes.XERO, baseline.fingerprint)
    local yisus = summarizeMode("YISUS", state.modes.YISUS, baseline.fingerprint)
    local base = summarizeMode("BASELINE", baseline, baseline.fingerprint)

    local lines = {}
    table.insert(lines, "===== XERO AIM COMPARE LAB =====")
    table.insert(lines, "Comparación pasiva · no instala hooks")
    table.insert(lines, "")
    table.insert(lines, string.format("%-10s | shots | __namecall | __index | cam->mouse | cam50ms | cam->victim | damage | projectiles | toolDiff",
        "MODO"))

    local function row(s)
        table.insert(lines, string.format(
            "%-10s | %5d | %10s | %7s | %10s | %7s | %11s | %6d | %11d | %8d",
            s.name, s.shots, yn(s.namecallChanged), yn(s.indexChanged),
            num(s.avgCameraToMouse), num(s.avgCameraMove50), num(s.avgCameraToVictim),
            s.damageCount, s.projectileCount, s.toolDiffCount
        ))
    end

    row(base)
    row(xero)
    row(yisus)
    table.insert(lines, "")
    table.insert(lines, "INTERPRETACIÓN AUTOMÁTICA:")

    if xero.namecallChanged == true then
        table.insert(lines, "- Xero cambia la huella de __namecall respecto al baseline.")
    end
    if xero.indexChanged == true then
        table.insert(lines, "- Xero cambia la huella de __index respecto al baseline.")
    end

    if yisus.namecallChanged == false and yisus.indexChanged == false and (yisus.shots or 0) > 0 then
        table.insert(lines, "- Yisus no deja la misma huella global de metamethods; probablemente usa otra ruta observable.")
    elseif yisus.namecallChanged == true or yisus.indexChanged == true then
        table.insert(lines, "- Yisus también altera al menos un metamethod global; hay que comparar la conducta de disparo, no solo la existencia del hook.")
    end

    if type(yisus.avgCameraToVictim) == "number" and yisus.avgCameraToVictim > 8 then
        table.insert(lines, "- Yisus consiguió daño con víctimas bastante fuera de la dirección de cámara; el comportamiento es realmente 'silent'.")
    end

    if yisus.projectileCount > xero.projectileCount + 2 then
        table.insert(lines, "- Yisus genera/modifica más objetos de proyectil/tracer visibles que Xero.")
    end

    if yisus.toolDiffCount > xero.toolDiffCount + 2 then
        table.insert(lines, "- Yisus produce más cambios observables dentro del Tool/Values/Attributes.")
    end

    if xero.shots < 2 or yisus.shots < 2 then
        table.insert(lines, "- Faltan muestras. Usa al menos 3 disparos por modo para sacar una diferencia confiable.")
    end

    table.insert(lines, "")
    table.insert(lines, "DETALLE POR DISPARO:")

    for _, modeName in ipairs({"BASELINE", "XERO", "YISUS"}) do
        local mode = state.modes[modeName]
        table.insert(lines, "")
        table.insert(lines, "[" .. modeName .. "]")
        for i, s in ipairs(mode.shots or {}) do
            local dmg = {}
            for _, d in ipairs(s.damage or {}) do
                table.insert(dmg, string.format("%s(-%.1f, %.1f°, %.3fs)", d.player, d.delta or 0, d.cameraToVictimDeg or -1, d.delay or -1))
            end
            table.insert(lines, string.format(
                "#%d %s tool=%s cam->mouse=%s° camΔ50=%s° damage=%s projectiles=%d toolDiff=%d",
                i, tostring(s.reason), tostring(s.tool), num(s.cameraToMouseDeg), num(s.cameraDelta50ms),
                #dmg > 0 and table.concat(dmg, ", ") or "none",
                #(s.projectiles or {}), #(s.toolDiff or {})
            ))
            for _, diff in ipairs(s.toolDiff or {}) do
                table.insert(lines, "  TOOL " .. diff)
            end
            for _, p in ipairs(s.projectiles or {}) do
                table.insert(lines, string.format("  PROJ %s %s velAngle=%s°", p.class or "?", p.name or "?", num(p.cameraToVelocityDeg)))
            end
        end
    end

    return table.concat(lines, "\n")
end


local function modeReportPath(modeName)
    if modeName == "XERO" then return XERO_REPORT_FILE end
    if modeName == "YISUS" then return YISUS_REPORT_FILE end
    return nil
end

local function buildSingleModeReport(modeName)
    local mode = state.modes[modeName]
    if not mode then return "Modo inválido: " .. tostring(modeName) end

    local baseline = state.modes.BASELINE
    local baselineFp = baseline and baseline.fingerprint or nil
    local summary = summarizeMode(modeName, mode, baselineFp)

    local lines = {}
    table.insert(lines, "===== XERO AIM COMPARE LAB · " .. modeName .. " =====")
    table.insert(lines, "Reporte independiente · guardado automático")
    table.insert(lines, "Creator: Kev")
    table.insert(lines, "PlaceId: " .. tostring(game.PlaceId))
    table.insert(lines, "JobId: " .. tostring(game.JobId))
    table.insert(lines, "User: " .. tostring(player.Name))
    table.insert(lines, "Shots captured: " .. tostring(summary.shots))
    table.insert(lines, "")

    table.insert(lines, "[HUELLA GLOBAL]")
    table.insert(lines, "__namecall changed vs baseline: " .. yn(summary.namecallChanged))
    table.insert(lines, "__index changed vs baseline: " .. yn(summary.indexChanged))

    if mode.fingerprint then
        table.insert(lines, "__namecall fingerprint: " .. fingerprintKey(mode.fingerprint, "namecall"))
        table.insert(lines, "__index fingerprint: " .. fingerprintKey(mode.fingerprint, "index"))
    else
        table.insert(lines, "__namecall fingerprint: N/D")
        table.insert(lines, "__index fingerprint: N/D")
    end

    table.insert(lines, "")
    table.insert(lines, "[RESUMEN]")
    table.insert(lines, "Avg camera -> Mouse.Hit: " .. num(summary.avgCameraToMouse) .. " deg")
    table.insert(lines, "Avg camera movement @50ms: " .. num(summary.avgCameraMove50) .. " deg")
    table.insert(lines, "Avg camera movement @150ms: " .. num(summary.avgCameraMove150) .. " deg")
    table.insert(lines, "Avg camera -> damaged victim: " .. num(summary.avgCameraToVictim) .. " deg")
    table.insert(lines, "Damage events: " .. tostring(summary.damageCount))
    table.insert(lines, "Projectile/tracer observations: " .. tostring(summary.projectileCount))
    table.insert(lines, "Tool Attribute/Value changes: " .. tostring(summary.toolDiffCount))

    table.insert(lines, "")
    table.insert(lines, "[DISPAROS]")
    for i, shot in ipairs(mode.shots or {}) do
        local dmg = {}
        for _, d in ipairs(shot.damage or {}) do
            table.insert(dmg, string.format(
                "%s(-%.1f HP, cam=%.2f deg, +%.3fs)",
                tostring(d.player),
                tonumber(d.delta) or 0,
                tonumber(d.cameraToVictimDeg) or -1,
                tonumber(d.delay) or -1
            ))
        end

        table.insert(lines, string.format(
            "#%d | %s | tool=%s | cam->mouse=%s deg | camD50=%s deg | camD150=%s deg | damage=%s | projectiles=%d | toolDiff=%d",
            i,
            tostring(shot.reason),
            tostring(shot.tool),
            num(shot.cameraToMouseDeg),
            num(shot.cameraDelta50ms),
            num(shot.cameraDelta150ms),
            #dmg > 0 and table.concat(dmg, ", ") or "none",
            #(shot.projectiles or {}),
            #(shot.toolDiff or {})
        ))

        if shot.mouse then
            table.insert(lines, "  Mouse.Target: " .. tostring(shot.mouse.target or "nil"))
            if shot.mouse.hitPos then
                table.insert(lines, "  Mouse.Hit: " .. serializeValue(shot.mouse.hitPos))
            end
        end

        for _, diff in ipairs(shot.toolDiff or {}) do
            table.insert(lines, "  TOOL: " .. tostring(diff))
        end

        for _, projectile in ipairs(shot.projectiles or {}) do
            table.insert(lines, string.format(
                "  PROJECTILE: %s | %s | path=%s | velAngle=%s deg",
                tostring(projectile.class or "?"),
                tostring(projectile.name or "?"),
                tostring(projectile.path or "?"),
                num(projectile.cameraToVelocityDeg)
            ))
        end
    end

    table.insert(lines, "")
    table.insert(lines, "[NOTAS]")
    if summary.shots == 0 then
        table.insert(lines, "- Aún no se capturó ningún disparo.")
    elseif summary.shots < 3 then
        table.insert(lines, "- Muestra pequeña; 3-5 disparos dan una comparación más estable.")
    end

    if modeName == "XERO" then
        table.insert(lines, "- Este archivo se reescribe inmediatamente después de cada evento capturado.")
        table.insert(lines, "- Si el juego expulsa al cliente, la última escritura completada permanece en disco.")
    elseif modeName == "YISUS" then
        table.insert(lines, "- Este reporte es independiente del de Xero; no necesitas ejecutar ambos hubs en la misma sesión.")
    end

    return table.concat(lines, "\n")
end

writeModeReport = function(modeName)
    local path = modeReportPath(modeName)
    if not path or type(writefile) ~= "function" then return false end

    if type(makefolder) == "function" then
        if type(isfolder) ~= "function" or not safe(function() return isfolder(SAVE_FOLDER) end, false) then
            pcall(makefolder, SAVE_FOLDER)
        end
        if type(isfolder) ~= "function" or not safe(function() return isfolder(REPORT_FOLDER) end, false) then
            pcall(makefolder, REPORT_FOLDER)
        end
    end

    local report = buildSingleModeReport(modeName)
    local ok = pcall(writefile, path, report)
    return ok
end

flushActiveReport = function()
    if state.mode == "XERO" or state.mode == "YISUS" then
        writeModeReport(state.mode)
    end
end

-- =========================
-- UI
-- =========================
local guiParent = player:WaitForChild("PlayerGui")
if type(gethui) == "function" then
    guiParent = safe(gethui, guiParent)
else
    guiParent = CoreGui
end

local old = safe(function() return guiParent:FindFirstChild("XeroAimCompareLab") end, nil)
if old then old:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name = "XeroAimCompareLab"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 2147483000
gui.Parent = guiParent

local main = Instance.new("Frame")
main.Size = UDim2.fromOffset(520, 390)
main.Position = UDim2.new(0.5, -260, 0.5, -195)
main.BackgroundColor3 = Color3.fromRGB(10,10,10)
main.BorderSizePixel = 0
main.Parent = gui
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 16)

local stroke = Instance.new("UIStroke", main)
stroke.Color = Color3.fromRGB(55,55,55)
stroke.Thickness = 1

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -30, 0, 28)
title.Position = UDim2.fromOffset(15, 11)
title.BackgroundTransparency = 1
title.Text = "XERO | AIM COMPARE LAB"
title.TextColor3 = Color3.fromRGB(245,245,245)
title.Font = Enum.Font.GothamBold
title.TextSize = 17
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = main

local sub = Instance.new("TextLabel")
sub.Size = UDim2.new(1, -30, 0, 18)
sub.Position = UDim2.fromOffset(15, 37)
sub.BackgroundTransparency = 1
sub.Text = "by Kev · comparador pasivo"
sub.TextColor3 = Color3.fromRGB(135,135,135)
sub.Font = Enum.Font.Gotham
sub.TextSize = 11
sub.TextXAlignment = Enum.TextXAlignment.Left
sub.Parent = main

local status = Instance.new("TextLabel")
status.Size = UDim2.new(1, -30, 0, 22)
status.Position = UDim2.fromOffset(15, 61)
status.BackgroundTransparency = 1
status.Text = state.status
status.TextColor3 = Color3.fromRGB(205,205,205)
status.Font = Enum.Font.GothamMedium
status.TextSize = 12
status.TextXAlignment = Enum.TextXAlignment.Left
status.Parent = main
state.statusLabel = status

local buttons = Instance.new("Frame")
buttons.Size = UDim2.new(1, -30, 0, 72)
buttons.Position = UDim2.fromOffset(15, 89)
buttons.BackgroundTransparency = 1
buttons.Parent = main

local grid = Instance.new("UIGridLayout", buttons)
grid.CellSize = UDim2.new(1/3, -6, 0, 31)
grid.CellPadding = UDim2.fromOffset(8, 8)
grid.SortOrder = Enum.SortOrder.LayoutOrder

local function makeButton(text, order, cb)
    local b = Instance.new("TextButton")
    b.LayoutOrder = order
    b.Text = text
    b.BackgroundColor3 = Color3.fromRGB(23,23,23)
    b.TextColor3 = Color3.fromRGB(235,235,235)
    b.Font = Enum.Font.GothamMedium
    b.TextSize = 11
    b.AutoButtonColor = true
    b.Parent = buttons
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 9)
    local s = Instance.new("UIStroke", b)
    s.Color = Color3.fromRGB(48,48,48)
    s.Thickness = 1
    b.MouseButton1Click:Connect(cb)
    return b
end

makeButton("BASELINE (OPCIONAL)", 1, function() markMode("BASELINE") end)
makeButton("ESCANEAR XERO", 2, function() markMode("XERO") end)
makeButton("ESCANEAR YISUS", 3, function() markMode("YISUS") end)
makeButton("DETENER", 4, function()
    state.mode = nil
    setStatus("Captura detenida")
    saveState()
end)

local reportBox = Instance.new("TextBox")
reportBox.Size = UDim2.new(1, -30, 1, -177)
reportBox.Position = UDim2.fromOffset(15, 171)
reportBox.BackgroundColor3 = Color3.fromRGB(15,15,15)
reportBox.BorderSizePixel = 0
reportBox.TextColor3 = Color3.fromRGB(190,190,190)
reportBox.Font = Enum.Font.Code
reportBox.TextSize = 11
reportBox.TextWrapped = false
reportBox.MultiLine = true
reportBox.ClearTextOnFocus = false
reportBox.TextEditable = false
reportBox.TextXAlignment = Enum.TextXAlignment.Left
reportBox.TextYAlignment = Enum.TextYAlignment.Top
reportBox.Text = "ESCANEAR XERO -> XeroHub/AimReports/Xero_Report.txt\nESCANEAR YISUS -> XeroHub/AimReports/Yisus_Report.txt\n\nCada disparo actualiza SU archivo inmediatamente.\nNo necesitas ejecutar ambos hubs juntos."
reportBox.Parent = main
Instance.new("UICorner", reportBox).CornerRadius = UDim.new(0, 10)
local pad = Instance.new("UIPadding", reportBox)
pad.PaddingLeft = UDim.new(0, 9)
pad.PaddingRight = UDim.new(0, 9)
pad.PaddingTop = UDim.new(0, 8)
pad.PaddingBottom = UDim.new(0, 8)

makeButton("GUARDAR REPORTES", 5, function()
    local okX = writeModeReport("XERO")
    local okY = writeModeReport("YISUS")
    local report = "XERO -> " .. XERO_REPORT_FILE .. " [" .. (okX and "OK" or "ERROR") .. "]\n"
        .. "YISUS -> " .. YISUS_REPORT_FILE .. " [" .. (okY and "OK" or "ERROR") .. "]"
    reportBox.Text = report
    setStatus("Reportes independientes actualizados")
    if type(setclipboard) == "function" then
        pcall(setclipboard, report)
    end
end)

makeButton("BORRAR CAPTURAS", 6, function()
    state.modes = {
        BASELINE = {shots = {}, started = nil, fingerprint = nil},
        XERO = {shots = {}, started = nil, fingerprint = nil},
        YISUS = {shots = {}, started = nil, fingerprint = nil},
    }
    state.mode = nil
    state.lastShot = nil
    reportBox.Text = "Capturas en memoria reiniciadas.\nLos .txt existentes se actualizarán al próximo escaneo."
    setStatus("Datos reiniciados")
    saveState()
    writeModeReport("XERO")
    writeModeReport("YISUS")
end)

-- Drag
do
    local dragging, dragStart, startPos, dragInput
    title.Active = true
    title.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = main.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    title.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)
    track(UserInputService.InputChanged:Connect(function(input)
        if dragging and input == dragInput then
            local delta = input.Position - dragStart
            main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end))
end

state.gui = gui

local exportEnv = (getgenv and getgenv()) or _G
exportEnv.XeroAimCompareLab = {
    Report = buildReport,
    ReportXero = function() return buildSingleModeReport("XERO") end,
    ReportYisus = function() return buildSingleModeReport("YISUS") end,
    SaveReports = function()
        return writeModeReport("XERO"), writeModeReport("YISUS")
    end,
    Save = saveState,
    SetMode = markMode,
    Stop = function() state.mode = nil setStatus("Captura detenida") end,
    Destroy = function()
        state.alive = false
        for _, c in ipairs(state.connections) do pcall(function() c:Disconnect() end) end
        pcall(function() gui:Destroy() end)
    end
}

setStatus("Listo · ESCANEAR XERO o ESCANEAR YISUS")
