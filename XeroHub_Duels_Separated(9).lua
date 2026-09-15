--[[
    XeroHub | ESP / Glow Diagnostic
    Creator: Kev

    Purpose:
    - Isolate Highlight/Glow behavior from the main hub.
    - Does NOT hook metamethods, modify remotes, or bypass anti-cheat.
    - Lets you test different Highlight parents and see whether the object
      survives, stays enabled, and keeps its Adornee.

    Recommended use:
    1) Join a test server with at least one other player.
    2) Pick a target.
    3) Test each mode one at a time.
    4) Watch the status panel and your game's anti-cheat output.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local LogService = game:GetService("LogService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then
    Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
    LocalPlayer = Players.LocalPlayer
end

local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- =========================================================
-- Runtime cleanup
-- =========================================================

local env = (getgenv and getgenv()) or _G
if env.__XERO_GLOW_DIAGNOSTIC and env.__XERO_GLOW_DIAGNOSTIC.Cleanup then
    pcall(env.__XERO_GLOW_DIAGNOSTIC.Cleanup)
end

local runtime = {
    Connections = {},
    CurrentHighlight = nil,
    CurrentTarget = nil,
    CurrentMode = "Ninguno",
    CreatedAt = 0,
    LastEvent = "Listo",
    LastACMessage = "Ninguno",
    Destroyed = false,
}

env.__XERO_GLOW_DIAGNOSTIC = runtime

local function track(connection)
    table.insert(runtime.Connections, connection)
    return connection
end

local function disconnectAll()
    for i = #runtime.Connections, 1, -1 do
        local c = runtime.Connections[i]
        pcall(function() c:Disconnect() end)
        runtime.Connections[i] = nil
    end
end

local oldGui = PlayerGui:FindFirstChild("XeroGlowDiagnostic")
if oldGui then oldGui:Destroy() end

local diagnosticFolder = PlayerGui:FindFirstChild("XeroGlowDiagnosticObjects")
if diagnosticFolder then diagnosticFolder:Destroy() end
diagnosticFolder = Instance.new("Folder")
diagnosticFolder.Name = "XeroGlowDiagnosticObjects"
diagnosticFolder.Parent = PlayerGui

local function destroyGlow()
    local h = runtime.CurrentHighlight
    runtime.CurrentHighlight = nil
    if h then
        pcall(function() h:Destroy() end)
    end
    runtime.CurrentMode = "Ninguno"
    runtime.CreatedAt = 0
    runtime.Destroyed = false
    runtime.LastEvent = "Glow limpiado"
end

runtime.Cleanup = function()
    destroyGlow()
    disconnectAll()
    if diagnosticFolder and diagnosticFolder.Parent then
        diagnosticFolder:Destroy()
    end
    local gui = PlayerGui:FindFirstChild("XeroGlowDiagnostic")
    if gui then gui:Destroy() end
    if env.__XERO_GLOW_DIAGNOSTIC == runtime then
        env.__XERO_GLOW_DIAGNOSTIC = nil
    end
end

-- =========================================================
-- Target helpers
-- =========================================================

local function isValidTarget(p)
    return p
        and p ~= LocalPlayer
        and p.Parent == Players
        and p.Character
        and p.Character.Parent
end

local function getCandidates()
    local list = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if isValidTarget(p) then
            table.insert(list, p)
        end
    end
    table.sort(list, function(a, b)
        return a.Name:lower() < b.Name:lower()
    end)
    return list
end

local function chooseFirstTarget()
    local candidates = getCandidates()
    runtime.CurrentTarget = candidates[1]
    return runtime.CurrentTarget
end

local function nextTarget()
    local candidates = getCandidates()
    if #candidates == 0 then
        runtime.CurrentTarget = nil
        destroyGlow()
        runtime.LastEvent = "No hay otros jugadores"
        return nil
    end

    local currentIndex = 0
    for i, p in ipairs(candidates) do
        if p == runtime.CurrentTarget then
            currentIndex = i
            break
        end
    end

    currentIndex = currentIndex + 1
    if currentIndex > #candidates then currentIndex = 1 end

    runtime.CurrentTarget = candidates[currentIndex]
    destroyGlow()
    runtime.LastEvent = "Target cambiado a " .. runtime.CurrentTarget.Name
    return runtime.CurrentTarget
end

chooseFirstTarget()

-- =========================================================
-- Glow creation
-- =========================================================

local function resolveParent(mode, char)
    if mode == "Character" then
        return char
    elseif mode == "Workspace" then
        return workspace
    elseif mode == "ReplicatedStorage" then
        return ReplicatedStorage
    elseif mode == "CurrentCamera" then
        return workspace.CurrentCamera
    elseif mode == "PlayerGuiFolder" then
        return diagnosticFolder
    end
    return nil
end

local function attachWatchers(highlight)
    track(highlight.AncestryChanged:Connect(function(_, parent)
        if runtime.CurrentHighlight ~= highlight then return end
        if parent then
            runtime.LastEvent = "AncestryChanged → " .. parent:GetFullName()
        else
            runtime.LastEvent = "AncestryChanged → nil"
            runtime.Destroyed = true
        end
    end))

    track(highlight:GetPropertyChangedSignal("Enabled"):Connect(function()
        if runtime.CurrentHighlight ~= highlight then return end
        runtime.LastEvent = "Enabled cambió → " .. tostring(highlight.Enabled)
    end))

    track(highlight:GetPropertyChangedSignal("Adornee"):Connect(function()
        if runtime.CurrentHighlight ~= highlight then return end
        runtime.LastEvent = "Adornee cambió"
    end))

    pcall(function()
        track(highlight.Destroying:Connect(function()
            if runtime.CurrentHighlight ~= highlight then return end
            runtime.Destroyed = true
            runtime.LastEvent = "Highlight.Destroying disparado"
        end))
    end)
end

local function createGlow(mode)
    destroyGlow()

    local target = runtime.CurrentTarget
    if not isValidTarget(target) then
        target = chooseFirstTarget()
    end

    if not target or not target.Character then
        runtime.LastEvent = "No hay target válido"
        return
    end

    local char = target.Character
    local parent = resolveParent(mode, char)
    if not parent then
        runtime.LastEvent = "Parent inválido"
        return
    end

    local h = Instance.new("Highlight")
    h.Name = "XeroDiagnosticHighlight"
    h.FillColor = Color3.fromRGB(255, 255, 255)
    h.FillTransparency = 0.35
    h.OutlineColor = Color3.fromRGB(255, 255, 255)
    h.OutlineTransparency = 0
    h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    h.Adornee = char
    h.Enabled = true

    local ok, err = pcall(function()
        h.Parent = parent
    end)

    if not ok then
        runtime.LastEvent = "Error parentando: " .. tostring(err)
        pcall(function() h:Destroy() end)
        return
    end

    runtime.CurrentHighlight = h
    runtime.CurrentMode = mode
    runtime.CreatedAt = os.clock()
    runtime.Destroyed = false
    runtime.LastEvent = "Glow creado en " .. mode

    attachWatchers(h)
end

-- =========================================================
-- UI helpers
-- =========================================================

local function corner(obj, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius or 10)
    c.Parent = obj
    return c
end

local function stroke(obj, transparency)
    local s = Instance.new("UIStroke")
    s.Thickness = 1
    s.Color = Color3.fromRGB(65, 65, 65)
    s.Transparency = transparency or 0
    s.Parent = obj
    return s
end

local gui = Instance.new("ScreenGui")
gui.Name = "XeroGlowDiagnostic"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = PlayerGui

local main = Instance.new("Frame")
main.Name = "Main"
main.AnchorPoint = Vector2.new(0, 0.5)
main.Position = UDim2.new(0, 24, 0.5, 0)
main.Size = UDim2.fromOffset(430, 500)
main.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
main.BorderSizePixel = 0
main.Parent = gui
corner(main, 16)
stroke(main, 0.1)

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Position = UDim2.fromOffset(18, 14)
title.Size = UDim2.new(1, -70, 0, 26)
title.Font = Enum.Font.GothamBold
title.Text = "XERO | GLOW DIAGNOSTIC"
title.TextColor3 = Color3.fromRGB(245, 245, 245)
title.TextSize = 16
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = main

local subtitle = Instance.new("TextLabel")
subtitle.BackgroundTransparency = 1
subtitle.Position = UDim2.fromOffset(18, 40)
subtitle.Size = UDim2.new(1, -36, 0, 20)
subtitle.Font = Enum.Font.Gotham
subtitle.Text = "Prueba aislada de Highlight · by Kev"
subtitle.TextColor3 = Color3.fromRGB(150, 150, 150)
subtitle.TextSize = 11
subtitle.TextXAlignment = Enum.TextXAlignment.Left
subtitle.Parent = main

local close = Instance.new("TextButton")
close.BackgroundColor3 = Color3.fromRGB(22, 22, 22)
close.Position = UDim2.new(1, -48, 0, 14)
close.Size = UDim2.fromOffset(30, 30)
close.Text = "×"
close.TextColor3 = Color3.fromRGB(220, 220, 220)
close.Font = Enum.Font.GothamBold
close.TextSize = 19
close.AutoButtonColor = true
close.Parent = main
corner(close, 9)
stroke(close, 0.35)

local divider = Instance.new("Frame")
divider.BorderSizePixel = 0
divider.BackgroundColor3 = Color3.fromRGB(37, 37, 37)
divider.Position = UDim2.fromOffset(18, 70)
divider.Size = UDim2.new(1, -36, 0, 1)
divider.Parent = main

local targetLabel = Instance.new("TextLabel")
targetLabel.BackgroundTransparency = 1
targetLabel.Position = UDim2.fromOffset(18, 82)
targetLabel.Size = UDim2.new(1, -128, 0, 30)
targetLabel.Font = Enum.Font.GothamMedium
targetLabel.TextColor3 = Color3.fromRGB(235, 235, 235)
targetLabel.TextSize = 12
targetLabel.TextXAlignment = Enum.TextXAlignment.Left
targetLabel.Text = "Target: ..."
targetLabel.Parent = main

local nextButton = Instance.new("TextButton")
nextButton.BackgroundColor3 = Color3.fromRGB(22, 22, 22)
nextButton.Position = UDim2.new(1, -112, 0, 82)
nextButton.Size = UDim2.fromOffset(94, 30)
nextButton.Text = "Siguiente"
nextButton.TextColor3 = Color3.fromRGB(235, 235, 235)
nextButton.Font = Enum.Font.GothamMedium
nextButton.TextSize = 11
nextButton.Parent = main
corner(nextButton, 9)
stroke(nextButton, 0.3)

local modeTitle = Instance.new("TextLabel")
modeTitle.BackgroundTransparency = 1
modeTitle.Position = UDim2.fromOffset(18, 124)
modeTitle.Size = UDim2.new(1, -36, 0, 20)
modeTitle.Font = Enum.Font.GothamBold
modeTitle.Text = "PRUEBAS DE PARENT"
modeTitle.TextColor3 = Color3.fromRGB(170, 170, 170)
modeTitle.TextSize = 10
modeTitle.TextXAlignment = Enum.TextXAlignment.Left
modeTitle.Parent = main

local modes = {
    {"Character", "Character"},
    {"Workspace", "Workspace"},
    {"ReplicatedStorage", "ReplicatedStorage"},
    {"CurrentCamera", "CurrentCamera"},
    {"PlayerGui folder", "PlayerGuiFolder"},
}

local y = 151
local buttons = {}

for _, info in ipairs(modes) do
    local btn = Instance.new("TextButton")
    btn.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    btn.Position = UDim2.fromOffset(18, y)
    btn.Size = UDim2.new(1, -36, 0, 34)
    btn.Text = "Probar · " .. info[1]
    btn.TextColor3 = Color3.fromRGB(235, 235, 235)
    btn.Font = Enum.Font.GothamMedium
    btn.TextSize = 11
    btn.AutoButtonColor = true
    btn.Parent = main
    corner(btn, 9)
    stroke(btn, 0.45)

    track(btn.MouseButton1Click:Connect(function()
        createGlow(info[2])
    end))

    table.insert(buttons, btn)
    y = y + 40
end

local clearButton = Instance.new("TextButton")
clearButton.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
clearButton.Position = UDim2.fromOffset(18, y + 2)
clearButton.Size = UDim2.new(1, -36, 0, 34)
clearButton.Text = "Limpiar Glow"
clearButton.TextColor3 = Color3.fromRGB(235, 235, 235)
clearButton.Font = Enum.Font.GothamMedium
clearButton.TextSize = 11
clearButton.Parent = main
corner(clearButton, 9)
stroke(clearButton, 0.35)

local statusBox = Instance.new("Frame")
statusBox.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
statusBox.BorderSizePixel = 0
statusBox.Position = UDim2.fromOffset(18, y + 48)
statusBox.Size = UDim2.new(1, -36, 0, 122)
statusBox.Parent = main
corner(statusBox, 11)
stroke(statusBox, 0.35)

local statusText = Instance.new("TextLabel")
statusText.BackgroundTransparency = 1
statusText.Position = UDim2.fromOffset(12, 10)
statusText.Size = UDim2.new(1, -24, 1, -20)
statusText.Font = Enum.Font.Code
statusText.TextColor3 = Color3.fromRGB(205, 205, 205)
statusText.TextSize = 11
statusText.TextWrapped = false
statusText.TextXAlignment = Enum.TextXAlignment.Left
statusText.TextYAlignment = Enum.TextYAlignment.Top
statusText.Text = ""
statusText.Parent = statusBox

local footer = Instance.new("TextLabel")
footer.BackgroundTransparency = 1
footer.Position = UDim2.new(0, 18, 1, -25)
footer.Size = UDim2.new(1, -36, 0, 16)
footer.Font = Enum.Font.Gotham
footer.Text = "Si el objeto desaparece/se desactiva, revisa qué script lo modificó."
footer.TextColor3 = Color3.fromRGB(115, 115, 115)
footer.TextSize = 9
footer.TextXAlignment = Enum.TextXAlignment.Left
footer.Parent = main

-- =========================================================
-- Dragging
-- =========================================================

do
    local dragging = false
    local dragInput
    local dragStart
    local startPos

    track(title.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = main.Position
        end
    end))

    track(title.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end))

    track(UserInputService.InputChanged:Connect(function(input)
        if dragging and input == dragInput then
            local delta = input.Position - dragStart
            main.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
        end
    end))

    track(UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end))
end

-- =========================================================
-- Diagnostic log watcher
-- =========================================================

local AC_KEYWORDS = {
    "anticheat",
    "anti-cheat",
    "anti cheat",
    "cheat detected",
    "exploit detected",
    "detected",
}

local function looksLikeACMessage(message)
    local lower = tostring(message or ""):lower()
    for _, key in ipairs(AC_KEYWORDS) do
        if string.find(lower, key, 1, true) then
            return true
        end
    end
    return false
end

track(LogService.MessageOut:Connect(function(message)
    if looksLikeACMessage(message) then
        runtime.LastACMessage = tostring(message)
        runtime.LastEvent = "Log de anticheat detectado"
    end
end))

-- =========================================================
-- Respawn / target lifecycle
-- =========================================================

track(Players.PlayerRemoving:Connect(function(p)
    if p == runtime.CurrentTarget then
        destroyGlow()
        runtime.CurrentTarget = nil
        chooseFirstTarget()
    end
end))

track(RunService.Heartbeat:Connect(function()
    local target = runtime.CurrentTarget
    if target and (not target.Parent or not target.Character) then
        destroyGlow()
    end
end))

-- =========================================================
-- Buttons
-- =========================================================

track(nextButton.MouseButton1Click:Connect(function()
    nextTarget()
end))

track(clearButton.MouseButton1Click:Connect(function()
    destroyGlow()
end))

track(close.MouseButton1Click:Connect(function()
    runtime.Cleanup()
end))

-- =========================================================
-- Live status
-- =========================================================

local accumulator = 0
track(RunService.RenderStepped:Connect(function(dt)
    accumulator = accumulator + dt
    if accumulator < 0.10 then return end
    accumulator = 0

    local target = runtime.CurrentTarget
    if not isValidTarget(target) then
        targetLabel.Text = "Target: ninguno"
    else
        targetLabel.Text = "Target: " .. target.Name
    end

    local h = runtime.CurrentHighlight
    local exists = h ~= nil
    local parentName = "nil"
    local enabled = "nil"
    local adorneeName = "nil"
    local alive = false
    local age = 0

    if h then
        local okParent, parent = pcall(function() return h.Parent end)
        if okParent and parent then
            parentName = parent:GetFullName()
            alive = true
        end

        local okEnabled, value = pcall(function() return h.Enabled end)
        if okEnabled then enabled = tostring(value) end

        local okAdornee, adornee = pcall(function() return h.Adornee end)
        if okAdornee and adornee then
            adorneeName = adornee:GetFullName()
        end

        if runtime.CreatedAt > 0 then
            age = os.clock() - runtime.CreatedAt
        end
    end

    local lastAC = runtime.LastACMessage
    if #lastAC > 42 then
        lastAC = lastAC:sub(1, 39) .. "..."
    end

    statusText.Text = string.format(
        "Modo: %s\nHighlight existe: %s\nParent: %s\nEnabled: %s\nAdornee: %s\nEdad: %.1fs\nEvento: %s\nAC log: %s",
        tostring(runtime.CurrentMode),
        tostring(exists and alive),
        tostring(parentName),
        tostring(enabled),
        tostring(adorneeName),
        age,
        tostring(runtime.LastEvent),
        tostring(lastAC)
    )
end))

runtime.LastEvent = "Hub de diagnóstico iniciado"
