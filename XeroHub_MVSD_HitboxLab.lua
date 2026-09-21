-- XeroHub | MVSD Local Shot Lab | Kev
-- Passive inspector for local shot effects.
-- Logs Tool.Activated, Sound.Played, Animator.AnimationPlayed,
-- ParticleEmitter:Emit, new Beam/Trail/Part/Sound instances, and ShootGun timing.
-- Does NOT alter shots.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
while not player do
    task.wait()
    player = Players.LocalPlayer
end

local env = (getgenv and getgenv()) or _G

if env.__XERO_MVSD_LOCALSHOT_CLEANUP then
    pcall(env.__XERO_MVSD_LOCALSHOT_CLEANUP)
end

local state = {
    Alive = true,
    Armed = false,
    ShotAt = 0,
    CaptureUntil = 0,
    Connections = {},
    Bound = setmetatable({}, {__mode = "k"}),
    Lines = {},
}

local function track(c)
    if c then
        state.Connections[#state.Connections + 1] = c
    end
    return c
end

local function push(s)
    state.Lines[#state.Lines + 1] = tostring(s)
end

local function pathOf(inst)
    if typeof(inst) ~= "Instance" then
        return tostring(inst)
    end

    local names = {}
    local node = inst
    local guard = 0

    while node and guard < 64 do
        guard += 1
        names[#names + 1] = tostring(node.Name)
        node = node.Parent
    end

    local out = {}
    for i = #names, 1, -1 do
        out[#out + 1] = names[i]
    end

    return table.concat(out, ".")
end

local function delta()
    return os.clock() - state.ShotAt
end

local function active()
    return state.Armed and state.CaptureUntil > 0 and os.clock() <= state.CaptureUntil
end

local function beginShot(source)
    if not state.Armed then return end

    state.ShotAt = os.clock()
    state.CaptureUntil = state.ShotAt + 0.80

    push(string.rep("=", 58))
    push("[SHOT]")
    push("Fuente: " .. tostring(source))
    push("t = " .. string.format("%.6f", state.ShotAt))
end

local function bindSound(sound)
    if not sound:IsA("Sound") or state.Bound[sound] then return end

    state.Bound[sound] = true

    track(sound.Played:Connect(function()
        if not active() then return end

        push("")
        push("[SOUND · Δ " .. string.format("%+.4f s", delta()) .. "]")
        push("Ruta: " .. pathOf(sound))
        push("SoundId: " .. tostring(sound.SoundId))
        push("Volume: " .. tostring(sound.Volume))
        push("PlaybackSpeed: " .. tostring(sound.PlaybackSpeed))
    end))
end

local function bindAnimator(animator)
    if not animator:IsA("Animator") or state.Bound[animator] then return end

    state.Bound[animator] = true

    track(animator.AnimationPlayed:Connect(function(trackObj)
        if not active() then return end

        local anim = trackObj.Animation

        push("")
        push("[ANIMATION · Δ " .. string.format("%+.4f s", delta()) .. "]")
        push("Animator: " .. pathOf(animator))
        push("Track: " .. tostring(trackObj.Name))
        push("AnimationId: " .. tostring(anim and anim.AnimationId))
        push("Priority: " .. tostring(trackObj.Priority))
    end))
end

local function bindObject(obj)
    if obj:IsA("Sound") then
        bindSound(obj)
    elseif obj:IsA("Animator") then
        bindAnimator(obj)
    end
end

local function scan(container)
    if not container then return end

    for _, obj in ipairs(container:GetDescendants()) do
        bindObject(obj)
    end
end

local function getEquippedTool()
    local char = player.Character
    return char and char:FindFirstChildOfClass("Tool")
end

local function bindTool(tool)
    if not tool or not tool:IsA("Tool") then return end
    if state.Bound[tool] then return end

    state.Bound[tool] = true

    track(tool.Activated:Connect(function()
        beginShot("Tool.Activated · " .. tostring(tool.Name))
    end))
end

local function scanTools(container)
    if not container then return end

    for _, child in ipairs(container:GetChildren()) do
        if child:IsA("Tool") then
            bindTool(child)
        end
    end
end

local function bindCharacter(char)
    if not char then return end

    scan(char)
    scanTools(char)

    track(char.DescendantAdded:Connect(function(obj)
        bindObject(obj)

        if active() then
            if obj:IsA("Beam")
                or obj:IsA("Trail")
                or obj:IsA("ParticleEmitter")
                or obj:IsA("Attachment")
                or obj:IsA("Part")
                or obj:IsA("MeshPart")
                or obj:IsA("Sound")
            then
                push("")
                push("[CHAR ADD · Δ " .. string.format("%+.4f s", delta()) .. "]")
                push("Clase: " .. obj.ClassName)
                push("Ruta: " .. pathOf(obj))
            end
        end
    end))
end

if player.Character then
    bindCharacter(player.Character)
end

track(player.CharacterAdded:Connect(bindCharacter))

local backpack = player:FindFirstChildOfClass("Backpack")
if backpack then
    scan(backpack)
    scanTools(backpack)

    track(backpack.DescendantAdded:Connect(function(obj)
        bindObject(obj)
        if obj:IsA("Tool") then bindTool(obj) end
    end))
end

local playerGui = player:WaitForChild("PlayerGui")
scan(playerGui)

track(playerGui.DescendantAdded:Connect(function(obj)
    bindObject(obj)

    if active() and (
        obj:IsA("Sound")
        or obj:IsA("Frame")
        or obj:IsA("ImageLabel")
        or obj:IsA("ParticleEmitter")
    ) then
        push("")
        push("[GUI ADD · Δ " .. string.format("%+.4f s", delta()) .. "]")
        push("Clase: " .. obj.ClassName)
        push("Ruta: " .. pathOf(obj))
    end
end))

scan(Workspace)

track(Workspace.DescendantAdded:Connect(function(obj)
    bindObject(obj)

    if active() and (
        obj:IsA("Beam")
        or obj:IsA("Trail")
        or obj:IsA("ParticleEmitter")
        or obj:IsA("Attachment")
        or obj:IsA("Part")
        or obj:IsA("MeshPart")
        or obj:IsA("Sound")
    ) then
        push("")
        push("[WORKSPACE ADD · Δ " .. string.format("%+.4f s", delta()) .. "]")
        push("Clase: " .. obj.ClassName)
        push("Ruta: " .. pathOf(obj))
    end
end))

-- Passive namecall hook for Emit/Play/ShootGun.
local hookState = env.__XERO_MVSD_LOCALSHOT_HOOK

if type(hookState) ~= "table" then
    hookState = {Current = state}
    env.__XERO_MVSD_LOCALSHOT_HOOK = hookState

    local oldNamecall
    oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
        local shared = env.__XERO_MVSD_LOCALSHOT_HOOK
        local s = shared and shared.Current

        if s and s.Alive and not checkcaller() then
            local method = getnamecallmethod()

            if s.Armed and method == "FireServer"
                and self.ClassName == "RemoteEvent"
                and self.Name == "ShootGun"
            then
                if s.ShotAt == 0 or os.clock() > s.CaptureUntil then
                    beginShot("ShootGun:FireServer")
                end

                push("")
                push("[SHOOTGUN · Δ " .. string.format("%+.4f s", delta()) .. "]")
                push("Ruta: " .. pathOf(self))

            elseif active() and method == "Emit"
                and self.ClassName == "ParticleEmitter"
            then
                local amount = ...

                push("")
                push("[PARTICLE EMIT · Δ " .. string.format("%+.4f s", delta()) .. "]")
                push("Ruta: " .. pathOf(self))
                push("Cantidad: " .. tostring(amount))

            elseif active() and method == "Play"
                and self.ClassName == "Sound"
            then
                push("")
                push("[SOUND:PLAY · Δ " .. string.format("%+.4f s", delta()) .. "]")
                push("Ruta: " .. pathOf(self))
                push("SoundId: " .. tostring(self.SoundId))
            end
        end

        return oldNamecall(self, ...)
    end)
else
    hookState.Current = state
end

-- Mouse1 fallback
track(UserInputService.InputBegan:Connect(function(input, processed)
    if processed or not state.Armed then return end

    if input.UserInputType == Enum.UserInputType.MouseButton1
        and getEquippedTool()
    then
        beginShot("MouseButton1")
    end
end))

-- UI
local guiParent = playerGui
pcall(function()
    if gethui then guiParent = gethui() end
end)

local oldGui = guiParent:FindFirstChild("XeroMVSDLocalShotLab")
if oldGui then oldGui:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name = "XeroMVSDLocalShotLab"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 2147483647
gui.Parent = guiParent

local frame = Instance.new("Frame")
frame.AnchorPoint = Vector2.new(0.5, 0.5)
frame.Position = UDim2.fromScale(0.5, 0.5)
frame.Size = UDim2.fromOffset(450, 410)
frame.BackgroundColor3 = Color3.fromRGB(8, 8, 8)
frame.BorderSizePixel = 0
frame.Parent = gui
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 16)

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(55,55,55)
stroke.Transparency = 0.2
stroke.Parent = frame

local title = Instance.new("TextLabel")
title.Position = UDim2.fromOffset(16, 12)
title.Size = UDim2.new(1, -32, 0, 26)
title.BackgroundTransparency = 1
title.Text = "XERO | MVSD LOCAL SHOT LAB"
title.TextColor3 = Color3.fromRGB(245,245,245)
title.Font = Enum.Font.GothamBold
title.TextSize = 17
title.TextXAlignment = Enum.TextXAlignment.Left
title.ZIndex = 21
title.Parent = frame

local subtitle = Instance.new("TextLabel")
subtitle.Position = UDim2.fromOffset(16, 38)
subtitle.Size = UDim2.new(1, -32, 0, 18)
subtitle.BackgroundTransparency = 1
subtitle.Text = "Detecta tracer/sonido/animación local · by Kev"
subtitle.TextColor3 = Color3.fromRGB(125,125,125)
subtitle.Font = Enum.Font.Gotham
subtitle.TextSize = 11
subtitle.TextXAlignment = Enum.TextXAlignment.Left
subtitle.ZIndex = 21
subtitle.Parent = frame

local dragBar = Instance.new("Frame")
dragBar.Size = UDim2.new(1, 0, 0, 62)
dragBar.BackgroundTransparency = 1
dragBar.Active = true
dragBar.ZIndex = 20
dragBar.Parent = frame

local status = Instance.new("TextLabel")
status.Position = UDim2.fromOffset(16, 68)
status.Size = UDim2.new(1, -32, 0, 50)
status.BackgroundColor3 = Color3.fromRGB(14,14,14)
status.TextColor3 = Color3.fromRGB(220,220,220)
status.Font = Enum.Font.GothamMedium
status.TextSize = 11
status.TextWrapped = true
status.Text = "Pulsa INICIAR y haz UN disparo normal."
status.Parent = frame
Instance.new("UICorner", status).CornerRadius = UDim.new(0, 10)

local function button(label, x, y, w, cb)
    local b = Instance.new("TextButton")
    b.Position = UDim2.fromOffset(x, y)
    b.Size = UDim2.fromOffset(w, 36)
    b.BackgroundColor3 = Color3.fromRGB(20,20,20)
    b.TextColor3 = Color3.fromRGB(235,235,235)
    b.Text = label
    b.Font = Enum.Font.GothamMedium
    b.TextSize = 11
    b.AutoButtonColor = false
    b.Parent = frame
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 10)
    b.Activated:Connect(cb)
end

button("INICIAR", 16, 134, 126, function()
    table.clear(state.Lines)
    state.Armed = true
    state.ShotAt = 0
    state.CaptureUntil = 0
    push("[SYSTEM] Local Shot Lab armado.")
    status.Text = "ARMADO · haz UN disparo normal."
end)

button("DETENER", 154, 134, 126, function()
    state.Armed = false
    state.CaptureUntil = 0
    status.Text = "Captura detenida."
end)

button("COPIAR TODO", 292, 134, 142, function()
    local data = table.concat(state.Lines, "\n")
    local clip = setclipboard or toclipboard

    if data == "" then
        status.Text = "No hay datos."
    elseif clip then
        pcall(clip, data)
        status.Text = "Copiado. Pégamelo aquí."
    else
        status.Text = "Tu executor no tiene setclipboard."
    end
end)

local preview = Instance.new("TextLabel")
preview.Position = UDim2.fromOffset(16, 184)
preview.Size = UDim2.new(1, -32, 1, -200)
preview.BackgroundColor3 = Color3.fromRGB(11,11,11)
preview.TextColor3 = Color3.fromRGB(150,150,150)
preview.Font = Enum.Font.Code
preview.TextSize = 10
preview.TextWrapped = true
preview.TextXAlignment = Enum.TextXAlignment.Left
preview.TextYAlignment = Enum.TextYAlignment.Top
preview.Text = "Esperando captura..."
preview.Parent = frame
Instance.new("UICorner", preview).CornerRadius = UDim.new(0, 10)

task.spawn(function()
    while state.Alive do
        local n = #state.Lines

        if n == 0 then
            preview.Text = "Esperando captura..."
        else
            local first = math.max(1, n - 18)
            local lines = {}
            for i = first, n do
                lines[#lines + 1] = state.Lines[i]
            end
            preview.Text = table.concat(lines, "\n")
        end

        task.wait(0.10)
    end
end)

-- Mobile + PC drag
local dragging = false
local activeInput = nil
local dragStart = nil
local frameStart = nil

dragBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch
    then
        dragging = true
        activeInput = input
        dragStart = input.Position
        frameStart = frame.Position
    end
end)

local function updateDrag(input)
    if not dragging or not dragStart or not frameStart then return end

    if input.UserInputType == Enum.UserInputType.Touch
        and activeInput
        and input ~= activeInput
    then
        return
    end

    local delta = input.Position - dragStart

    frame.Position = UDim2.new(
        frameStart.X.Scale,
        frameStart.X.Offset + delta.X,
        frameStart.Y.Scale,
        frameStart.Y.Offset + delta.Y
    )
end

track(UserInputService.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement then
        updateDrag(input)
    end
end))

track(UserInputService.TouchMoved:Connect(function(input)
    updateDrag(input)
end))

track(UserInputService.InputEnded:Connect(function(input)
    if input == activeInput
        or input.UserInputType == Enum.UserInputType.MouseButton1
    then
        dragging = false
        activeInput = nil
        dragStart = nil
        frameStart = nil
    end
end))

track(UserInputService.TouchEnded:Connect(function(input)
    if input == activeInput then
        dragging = false
        activeInput = nil
        dragStart = nil
        frameStart = nil
    end
end))

local function cleanup()
    if not state.Alive then return end

    state.Alive = false
    state.Armed = false
    state.CaptureUntil = 0

    if hookState and hookState.Current == state then
        hookState.Current = nil
    end

    for i = #state.Connections, 1, -1 do
        local c = state.Connections[i]
        pcall(function() c:Disconnect() end)
        state.Connections[i] = nil
    end

    pcall(function() gui:Destroy() end)
end

env.__XERO_MVSD_LOCALSHOT_CLEANUP = cleanup

print("[XeroHub] MVSD Local Shot Lab cargado | Passive | by Kev")

