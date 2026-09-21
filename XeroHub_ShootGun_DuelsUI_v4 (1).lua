-- XeroHub | MVSD Shoot Lab v2 | Kev
-- Diagnóstico ampliado para descubrir la ruta REAL de disparo.
-- Registra:
--  • RemoteEvent/UnreliableRemoteEvent:FireServer por __namecall
--  • RemoteEvent:FireServer por llamada directa (hookfunction)
--  • RemoteFunction:InvokeServer por ambas rutas
--  • Tool.Activated / Tool.Deactivated
--  • Input MouseButton1
--  • cambios de ValueBase/atributos dentro del Tool equipado
--  • animaciones del Humanoid
--
-- NO bloquea ni modifica llamadas originales.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")

local player = Players.LocalPlayer
local runtimeEnv = (getgenv and getgenv()) or _G

if runtimeEnv.__XERO_MVSD_SHOOT_LAB_V2_CLEANUP then
    pcall(runtimeEnv.__XERO_MVSD_SHOOT_LAB_V2_CLEANUP)
end

local state = {
    Alive = true,
    Recording = false,
    Logs = {},
    Connections = {},
    ToolConnections = {},
    AttributeConnections = {},
    SeenEntries = {},
    LastEntryAt = {},
}

local function now()
    return os.clock()
end

local function track(c, bucket)
    if c then
        bucket = bucket or state.Connections
        bucket[#bucket + 1] = c
    end
    return c
end

local function disconnectList(list)
    for i = #list, 1, -1 do
        local c = list[i]
        pcall(function() c:Disconnect() end)
        list[i] = nil
    end
end

local function safePath(obj)
    if not obj then return "nil" end
    local parts = {}
    local current = obj
    local guard = 0

    while current and current ~= game and guard < 40 do
        table.insert(parts, 1, current.Name)
        current = current.Parent
        guard += 1
    end
    if current == game then
        table.insert(parts, 1, "game")
    end
    return table.concat(parts, ".")
end

local function serialize(value, depth, seen)
    depth = depth or 0
    seen = seen or {}

    if depth > 3 then
        return "<max-depth>"
    end

    local kind = typeof(value)

    if kind == "nil" then
        return "nil"
    elseif kind == "string" then
        return string.format("%q", value)
    elseif kind == "number" or kind == "boolean" then
        return tostring(value)
    elseif kind == "Vector3" then
        return string.format("Vector3.new(%.5f, %.5f, %.5f)", value.X, value.Y, value.Z)
    elseif kind == "Vector2" then
        return string.format("Vector2.new(%.5f, %.5f)", value.X, value.Y)
    elseif kind == "CFrame" then
        local comps = {value:GetComponents()}
        local out = table.create(#comps)
        for i = 1, #comps do
            out[i] = string.format("%.5f", comps[i])
        end
        return "CFrame.new(" .. table.concat(out, ", ") .. ")"
    elseif kind == "Instance" then
        return "<" .. value.ClassName .. " " .. safePath(value) .. ">"
    elseif kind == "EnumItem" then
        return tostring(value)
    elseif kind == "Ray" then
        return "Ray.new(" .. serialize(value.Origin, depth + 1, seen)
            .. ", " .. serialize(value.Direction, depth + 1, seen) .. ")"
    elseif kind == "table" then
        if seen[value] then return "<cycle>" end
        seen[value] = true

        local out = {}
        local n = 0
        for k, v in pairs(value) do
            n += 1
            if n > 24 then
                out[#out + 1] = "..."
                break
            end
            out[#out + 1] =
                "[" .. serialize(k, depth + 1, seen) .. "]="
                .. serialize(v, depth + 1, seen)
        end

        seen[value] = nil
        return "{" .. table.concat(out, ", ") .. "}"
    end

    return "<" .. kind .. ":" .. tostring(value) .. ">"
end

local output
local status

local function refreshOutput()
    if not output then return end
    output.Text = #state.Logs > 0
        and table.concat(state.Logs, "\n\n")
        or "Sin eventos todavía."
end

local function emit(category, lines, dedupeKey, dedupeWindow)
    if not state.Recording then return end

    local t = now()
    if dedupeKey then
        local prev = state.LastEntryAt[dedupeKey]
        if prev and t - prev < (dedupeWindow or 0.01) then
            return
        end
        state.LastEntryAt[dedupeKey] = t
    end

    local body
    if type(lines) == "table" then
        body = table.concat(lines, "\n")
    else
        body = tostring(lines)
    end

    local entry = string.format("[%.4f] [%s]\n%s", t, category, body)
    state.Logs[#state.Logs + 1] = entry

    if #state.Logs > 160 then
        table.remove(state.Logs, 1)
    end

    print(entry)
    task.defer(refreshOutput)
end

local function logRemote(source, self, method, args)
    local lines = {
        "Origen hook: " .. tostring(source),
        "Método: " .. tostring(method),
        "Clase: " .. tostring(self.ClassName),
        "Nombre: " .. tostring(self.Name),
        "Ruta: " .. safePath(self),
        "Argumentos:"
    }

    for i = 1, #args do
        lines[#lines + 1] = "[" .. i .. "] " .. serialize(args[i])
    end
    if #args == 0 then
        lines[#lines + 1] = "(sin argumentos)"
    end

    emit(
        "REMOTE",
        lines,
        tostring(self) .. ":" .. tostring(method) .. ":" .. tostring(source),
        0.002
    )
end

-- ==========================================================
-- UI
-- ==========================================================

local parent = player:WaitForChild("PlayerGui")
pcall(function()
    if gethui then
        parent = gethui()
    else
        parent = CoreGui
    end
end)

local oldGui = parent:FindFirstChild("XeroHub_MVSD_ShootLabV2")
if oldGui then oldGui:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name = "XeroHub_MVSD_ShootLabV2"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 2147483647
gui.Parent = parent

local frame = Instance.new("Frame")
frame.Size = UDim2.fromOffset(510, 390)
frame.Position = UDim2.new(0.5, -255, 0.5, -195)
frame.BackgroundColor3 = Color3.fromRGB(12, 12, 12)
frame.BorderSizePixel = 0
frame.Active = true
frame.Parent = gui
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 14)

local stroke = Instance.new("UIStroke", frame)
stroke.Color = Color3.fromRGB(58, 58, 58)
stroke.Thickness = 1

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -30, 0, 38)
title.Position = UDim2.fromOffset(15, 8)
title.BackgroundTransparency = 1
title.Text = "XeroHub · MVSD Shoot Lab v2"
title.TextColor3 = Color3.fromRGB(245, 245, 245)
title.Font = Enum.Font.GothamBold
title.TextSize = 16
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = frame

status = Instance.new("TextLabel")
status.Size = UDim2.new(1, -30, 0, 38)
status.Position = UDim2.fromOffset(15, 42)
status.BackgroundTransparency = 1
status.Text = "Pulsa INICIAR → haz 1 disparo manual → DETENER."
status.TextColor3 = Color3.fromRGB(165, 165, 165)
status.Font = Enum.Font.Gotham
status.TextSize = 12
status.TextWrapped = true
status.TextXAlignment = Enum.TextXAlignment.Left
status.Parent = frame

output = Instance.new("TextBox")
output.Size = UDim2.new(1, -30, 1, -154)
output.Position = UDim2.fromOffset(15, 83)
output.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
output.BorderSizePixel = 0
output.ClearTextOnFocus = false
output.MultiLine = true
output.TextEditable = false
output.TextWrapped = false
output.TextXAlignment = Enum.TextXAlignment.Left
output.TextYAlignment = Enum.TextYAlignment.Top
output.TextColor3 = Color3.fromRGB(220, 220, 220)
output.Font = Enum.Font.Code
output.TextSize = 11
output.Text = "Esperando..."
output.Parent = frame
Instance.new("UICorner", output).CornerRadius = UDim.new(0, 10)

local function makeButton(text, xScale, widthScale)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(widthScale, -6, 0, 38)
    b.Position = UDim2.new(xScale, 15, 1, -52)
    b.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    b.BorderSizePixel = 0
    b.Text = text
    b.TextColor3 = Color3.fromRGB(235, 235, 235)
    b.Font = Enum.Font.GothamMedium
    b.TextSize = 12
    b.Parent = frame
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 10)
    return b
end

local startBtn = makeButton("INICIAR", 0, 0.30)
local stopBtn  = makeButton("DETENER", 0.32, 0.30)
local copyBtn  = makeButton("COPIAR", 0.64, 0.32)

local dragging = false
local dragStart
local startPos

track(frame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = frame.Position
    end
end))

track(UserInputService.InputChanged:Connect(function(input)
    if not dragging then return end
    if input.UserInputType ~= Enum.UserInputType.MouseMovement
        and input.UserInputType ~= Enum.UserInputType.Touch then
        return
    end
    local delta = input.Position - dragStart
    frame.Position = UDim2.new(
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

-- ==========================================================
-- TOOL WATCHER
-- ==========================================================

local currentTool

local function watchAttributes(obj, prefix)
    if not obj then return end

    local ok, attrs = pcall(function() return obj:GetAttributes() end)
    if ok and attrs then
        for name in pairs(attrs) do
            track(obj:GetAttributeChangedSignal(name):Connect(function()
                emit(
                    "ATTRIBUTE",
                    {
                        "Objeto: " .. safePath(obj),
                        "Atributo: " .. name,
                        "Valor: " .. serialize(obj:GetAttribute(name))
                    }
                )
            end), state.AttributeConnections)
        end
    end
end

local function bindTool(tool)
    disconnectList(state.ToolConnections)
    disconnectList(state.AttributeConnections)
    currentTool = tool

    if not tool then
        emit("TOOL", "Sin Tool equipado.")
        return
    end

    emit("TOOL", {
        "Equipado: " .. tool.Name,
        "Ruta: " .. safePath(tool)
    })

    track(tool.Activated:Connect(function()
        emit("TOOL.ACTIVATED", {
            "Tool: " .. tool.Name,
            "Ruta: " .. safePath(tool)
        }, "toolact", 0.005)
    end), state.ToolConnections)

    track(tool.Deactivated:Connect(function()
        emit("TOOL.DEACTIVATED", {
            "Tool: " .. tool.Name,
            "Ruta: " .. safePath(tool)
        }, "tooldeact", 0.005)
    end), state.ToolConnections)

    watchAttributes(tool, "Tool")

    local function watchObject(obj)
        if obj:IsA("ValueBase") then
            track(obj:GetPropertyChangedSignal("Value"):Connect(function()
                emit("VALUE", {
                    "Ruta: " .. safePath(obj),
                    "Clase: " .. obj.ClassName,
                    "Valor: " .. serialize(obj.Value)
                })
            end), state.ToolConnections)
        end

        if obj:IsA("Sound") then
            track(obj.Played:Connect(function()
                emit("SOUND", {
                    "Ruta: " .. safePath(obj),
                    "SoundId: " .. tostring(obj.SoundId)
                })
            end), state.ToolConnections)
        end

        watchAttributes(obj, "Desc")
    end

    watchObject(tool)
    for _, obj in ipairs(tool:GetDescendants()) do
        watchObject(obj)
    end

    track(tool.DescendantAdded:Connect(function(obj)
        emit("DESCENDANT+", {
            "Tool: " .. tool.Name,
            "Objeto: " .. obj.ClassName .. " " .. safePath(obj)
        })
        watchObject(obj)
    end), state.ToolConnections)

    track(tool.DescendantRemoving:Connect(function(obj)
        emit("DESCENDANT-", {
            "Tool: " .. tool.Name,
            "Objeto: " .. obj.ClassName .. " " .. safePath(obj)
        })
    end), state.ToolConnections)
end

local function refreshTool()
    local char = player.Character
    local tool = char and char:FindFirstChildOfClass("Tool") or nil
    if tool ~= currentTool then
        bindTool(tool)
    end
end

local charConnections = {}

local function bindCharacter(char)
    disconnectList(charConnections)
    currentTool = nil
    bindTool(nil)

    if not char then return end

    track(char.ChildAdded:Connect(function(child)
        if child:IsA("Tool") then
            bindTool(child)
        end
    end), charConnections)

    track(char.ChildRemoved:Connect(function(child)
        if child == currentTool then
            task.defer(refreshTool)
        end
    end), charConnections)

    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then
        track(hum.AnimationPlayed:Connect(function(trackObj)
            local anim = trackObj.Animation
            emit("ANIMATION", {
                "NombreTrack: " .. tostring(trackObj.Name),
                "AnimationId: " .. tostring(anim and anim.AnimationId or ""),
                "Priority: " .. tostring(trackObj.Priority)
            })
        end), charConnections)
    end

    task.defer(refreshTool)
end

track(player.CharacterAdded:Connect(bindCharacter))
bindCharacter(player.Character)

-- ==========================================================
-- INPUT WATCHER
-- ==========================================================

track(UserInputService.InputBegan:Connect(function(input, processed)
    if not state.Recording then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        emit("INPUT.DOWN", {
            "MouseButton1",
            "gameProcessed: " .. tostring(processed)
        }, "mb1down", 0.001)
    end
end))

track(UserInputService.InputEnded:Connect(function(input, processed)
    if not state.Recording then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        emit("INPUT.UP", {
            "MouseButton1",
            "gameProcessed: " .. tostring(processed)
        }, "mb1up", 0.001)
    end
end))

-- ==========================================================
-- REMOTE HOOK #1: __namecall
-- ==========================================================

local oldNamecall
oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
    local method = getnamecallmethod()
    if state.Alive and state.Recording and not checkcaller()
        and typeof(self) == "Instance"
        and (method == "FireServer" or method == "InvokeServer")
        and (
            self:IsA("RemoteEvent")
            or self:IsA("UnreliableRemoteEvent")
            or self:IsA("RemoteFunction")
        )
    then
        logRemote("__namecall", self, method, {...})
    end
    return oldNamecall(self, ...)
end)

-- ==========================================================
-- REMOTE HOOK #2: direct-method hookfunction
-- Captura remote.FireServer(remote, ...) y remote.InvokeServer(remote, ...)
-- ==========================================================

local directHooks = {}

local function tryHookDirectRemoteMethods()
    if type(hookfunction) ~= "function" then
        emit("SYSTEM", "hookfunction no disponible; solo __namecall estará activo.")
        return
    end

    -- RemoteEvent.FireServer
    pcall(function()
        local dummy = Instance.new("RemoteEvent")
        local method = dummy.FireServer
        dummy:Destroy()

        local original
        original = hookfunction(method, function(self, ...)
            if state.Alive and state.Recording and not checkcaller()
                and typeof(self) == "Instance"
                and (self:IsA("RemoteEvent") or self:IsA("UnreliableRemoteEvent"))
            then
                logRemote("hookfunction.FireServer", self, "FireServer", {...})
            end
            return original(self, ...)
        end)
        directHooks[#directHooks + 1] = original
    end)

    -- RemoteFunction.InvokeServer
    pcall(function()
        local dummy = Instance.new("RemoteFunction")
        local method = dummy.InvokeServer
        dummy:Destroy()

        local original
        original = hookfunction(method, function(self, ...)
            if state.Alive and state.Recording and not checkcaller()
                and typeof(self) == "Instance"
                and self:IsA("RemoteFunction")
            then
                logRemote("hookfunction.InvokeServer", self, "InvokeServer", {...})
            end
            return original(self, ...)
        end)
        directHooks[#directHooks + 1] = original
    end)

    -- UnreliableRemoteEvent may expose a distinct closure on some executors/builds.
    pcall(function()
        local dummy = Instance.new("UnreliableRemoteEvent")
        local method = dummy.FireServer
        dummy:Destroy()

        local original
        original = hookfunction(method, function(self, ...)
            if state.Alive and state.Recording and not checkcaller()
                and typeof(self) == "Instance"
                and self:IsA("UnreliableRemoteEvent")
            then
                logRemote("hookfunction.Unreliable.FireServer", self, "FireServer", {...})
            end
            return original(self, ...)
        end)
        directHooks[#directHooks + 1] = original
    end)

    emit("SYSTEM", "Hooks directos instalados si el ejecutor los soporta.")
end

tryHookDirectRemoteMethods()

-- ==========================================================
-- BUTTONS
-- ==========================================================

startBtn.MouseButton1Click:Connect(function()
    table.clear(state.Logs)
    table.clear(state.LastEntryAt)
    state.Recording = true
    status.Text = "GRABANDO · haz UN disparo manual y espera medio segundo."
    status.TextColor3 = Color3.fromRGB(120, 230, 140)
    refreshTool()
    refreshOutput()
end)

stopBtn.MouseButton1Click:Connect(function()
    state.Recording = false
    status.Text = "Detenido · COPIAR y mándame TODO el log."
    status.TextColor3 = Color3.fromRGB(180, 180, 180)
    refreshOutput()
end)

copyBtn.MouseButton1Click:Connect(function()
    local text = #state.Logs > 0
        and table.concat(state.Logs, "\n\n")
        or "Sin eventos registrados."

    if type(setclipboard) == "function" then
        pcall(setclipboard, text)
        status.Text = "Log copiado."
    else
        output.TextEditable = true
        output.Text = text
        output:CaptureFocus()
        status.Text = "Sin setclipboard: copia manualmente del cuadro."
    end
end)

-- ==========================================================
-- CLEANUP
-- ==========================================================

runtimeEnv.__XERO_MVSD_SHOOT_LAB_V2_CLEANUP = function()
    if not state.Alive then return end
    state.Alive = false
    state.Recording = false

    disconnectList(state.ToolConnections)
    disconnectList(state.AttributeConnections)
    disconnectList(charConnections)
    disconnectList(state.Connections)

    if gui and gui.Parent then
        gui:Destroy()
    end
end

print("[XeroHub] MVSD Shoot Lab v2 cargado.")
print("INICIAR -> 1 disparo manual -> esperar ~0.5s -> DETENER -> COPIAR.")
