-- XeroHub | Universal Silent Aim LAB | Kev
-- Experimental universal adapter:
-- Raycast / FindPartOnRay / Mouse.Hit / Mouse.Target
-- Auto enemy detection: Match/round isolation -> Team -> TeamColor -> attributes -> FFA.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")

local player = Players.LocalPlayer
while not player do
    task.wait()
    player = Players.LocalPlayer
end

local mouse = player:GetMouse()
local env = (getgenv and getgenv()) or _G

-- Clean previous UI/session without reinstalling metamethod hooks.
if env.__XERO_UNIVERSAL_SILENT_RUNTIME
    and env.__XERO_UNIVERSAL_SILENT_RUNTIME.Cleanup
then
    pcall(env.__XERO_UNIVERSAL_SILENT_RUNTIME.Cleanup)
end

local runtime = {
    Alive = true,
    Connections = {},
    ToolConnections = setmetatable({}, {__mode = "k"}),
    PlayerList = Players:GetPlayers(),
    CharacterCache = setmetatable({}, {__mode = "k"}),
    TeamScheme = {Kind = "FFA", Key = nil, Label = "FFA"},
    TeamSchemeAt = 0,
    Target = nil,
    TargetPlayer = nil,
    LastShotAt = 0,
    LastTool = nil,
}

env.__XERO_UNIVERSAL_SILENT_RUNTIME = runtime

local state = {
    Enabled = false,
    FOVEnabled = true,
    ShowFOV = true,
    WallCheck = true,
    RequireTool = true,
    Radius = 140,
    MaxDistance = 5000,
    TargetMode = "Head", -- Head / Torso / Nearest
    DetectionMode = "Auto", -- Auto / FFA
}

local function track(connection)
    if connection then
        runtime.Connections[#runtime.Connections + 1] = connection
    end
    return connection
end

local function safeDisconnect(connection)
    if connection then
        pcall(function() connection:Disconnect() end)
    end
end

local function getCharData(plr)
    if not plr then return nil end
    local char = plr.Character
    if not char then
        runtime.CharacterCache[plr] = nil
        return nil
    end

    local cached = runtime.CharacterCache[plr]
    if not cached
        or cached.Character ~= char
        or not cached.Humanoid
        or cached.Humanoid.Parent ~= char
        or not cached.Root
        or cached.Root.Parent ~= char
    then
        cached = {
            Character = char,
            Humanoid = char:FindFirstChildOfClass("Humanoid"),
            Root = char:FindFirstChild("HumanoidRootPart")
                or char:FindFirstChild("Torso")
                or char:FindFirstChild("UpperTorso"),
        }
        runtime.CharacterCache[plr] = cached
    end

    if not cached.Humanoid
        or cached.Humanoid.Health <= 0
        or not cached.Root
    then
        return nil
    end

    return cached.Character, cached.Humanoid, cached.Root
end

local function isAlive(plr)
    local char, hum, root = getCharData(plr)
    return char ~= nil and hum ~= nil and root ~= nil
end

local function getEquippedTool()
    local char = player.Character
    if not char then
        runtime.LastTool = nil
        return nil
    end

    local tool = runtime.LastTool
    if tool and tool.Parent == char and tool:IsA("Tool") then
        return tool
    end

    tool = char:FindFirstChildOfClass("Tool")
    runtime.LastTool = tool
    return tool
end

local CONTEXT_KEYS = {
    "Match", "MatchId", "match", "matchId",
    "Round", "RoundId", "round", "roundId",
    "Arena", "ArenaId", "arena", "arenaId",
}

local TEAM_ATTR_KEYS = {
    "Team", "team", "TeamId", "teamId",
    "Faction", "faction", "FactionId",
    "Squad", "squad", "SquadId",
    "Side", "side",
}

local function contextCompatible(other)
    for i = 1, #CONTEXT_KEYS do
        local key = CONTEXT_KEYS[i]
        local mine = player:GetAttribute(key)

        if mine ~= nil then
            local theirs = other:GetAttribute(key)
            if theirs ~= nil and theirs ~= mine then
                return false
            end
        end
    end

    return true
end

local function detectTeamScheme(force)
    local now = os.clock()

    if not force and now - runtime.TeamSchemeAt < 1 then
        return runtime.TeamScheme
    end

    runtime.TeamSchemeAt = now

    if state.DetectionMode == "FFA" then
        runtime.TeamScheme = {
            Kind = "FFA",
            Key = nil,
            Label = "FFA (forzado)",
        }
        return runtime.TeamScheme
    end

    -- 1) Roblox Team objects.
    local teamSet = {}
    local teamCount = 0

    for i = 1, #runtime.PlayerList do
        local plr = runtime.PlayerList[i]
        if plr and isAlive(plr) and plr.Team ~= nil then
            if not teamSet[plr.Team] then
                teamSet[plr.Team] = true
                teamCount += 1
            end
        end
    end

    if teamCount >= 2 and player.Team ~= nil then
        runtime.TeamScheme = {
            Kind = "Team",
            Key = nil,
            Label = "Player.Team",
        }
        return runtime.TeamScheme
    end

    -- 2) TeamColor when games use colors without meaningful Team objects.
    local colorSet = {}
    local colorCount = 0

    for i = 1, #runtime.PlayerList do
        local plr = runtime.PlayerList[i]
        if plr and isAlive(plr) and plr.TeamColor then
            local key = tostring(plr.TeamColor.Number)
            if not colorSet[key] then
                colorSet[key] = true
                colorCount += 1
            end
        end
    end

    if colorCount >= 2 and player.TeamColor then
        runtime.TeamScheme = {
            Kind = "TeamColor",
            Key = nil,
            Label = "Player.TeamColor",
        }
        return runtime.TeamScheme
    end

    -- 3) Common team/faction/squad attributes.
    for k = 1, #TEAM_ATTR_KEYS do
        local attr = TEAM_ATTR_KEYS[k]
        local mine = player:GetAttribute(attr)

        if mine ~= nil then
            local values = {}
            local count = 0

            for i = 1, #runtime.PlayerList do
                local plr = runtime.PlayerList[i]
                if plr and isAlive(plr) then
                    local value = plr:GetAttribute(attr)
                    if value ~= nil then
                        local token = typeof(value) .. ":" .. tostring(value)
                        if not values[token] then
                            values[token] = true
                            count += 1
                        end
                    end
                end
            end

            if count >= 2 then
                runtime.TeamScheme = {
                    Kind = "Attribute",
                    Key = attr,
                    Label = "Attribute:" .. attr,
                }
                return runtime.TeamScheme
            end
        end
    end

    runtime.TeamScheme = {
        Kind = "FFA",
        Key = nil,
        Label = "FFA (auto)",
    }
    return runtime.TeamScheme
end

local function isEnemy(plr)
    if not plr or plr == player or not isAlive(plr) then
        return false
    end

    -- First isolate same match/round/arena when the game exposes it.
    if not contextCompatible(plr) then
        return false
    end

    local scheme = detectTeamScheme(false)

    if scheme.Kind == "Team" then
        if player.Team ~= nil and plr.Team ~= nil then
            return player.Team ~= plr.Team
        end
        return true

    elseif scheme.Kind == "TeamColor" then
        if player.TeamColor and plr.TeamColor then
            return player.TeamColor ~= plr.TeamColor
        end
        return true

    elseif scheme.Kind == "Attribute" then
        local mine = player:GetAttribute(scheme.Key)
        local theirs = plr:GetAttribute(scheme.Key)

        if mine ~= nil and theirs ~= nil then
            return mine ~= theirs
        end
        return true
    end

    return true
end

local COMMON_BODY_PARTS = {
    "Head",
    "UpperTorso", "Torso", "LowerTorso",
    "HumanoidRootPart",
    "LeftUpperArm", "RightUpperArm",
    "LeftLowerArm", "RightLowerArm",
    "LeftHand", "RightHand",
    "LeftUpperLeg", "RightUpperLeg",
    "LeftLowerLeg", "RightLowerLeg",
    "LeftFoot", "RightFoot",
    "Left Arm", "Right Arm",
    "Left Leg", "Right Leg",
}

local function getTargetParts(char)
    if not char then return nil end

    if state.TargetMode == "Head" then
        local head = char:FindFirstChild("Head")
        local root = char:FindFirstChild("HumanoidRootPart")
        if head and head:IsA("BasePart") then
            return {head}
        elseif root and root:IsA("BasePart") then
            return {root}
        end

    elseif state.TargetMode == "Torso" then
        local names = {"UpperTorso", "Torso", "LowerTorso", "HumanoidRootPart"}
        local result = {}

        for i = 1, #names do
            local part = char:FindFirstChild(names[i])
            if part and part:IsA("BasePart") then
                result[#result + 1] = part
            end
        end

        if #result > 0 then return result end

    else
        local result = {}
        local seen = {}

        for i = 1, #COMMON_BODY_PARTS do
            local part = char:FindFirstChild(COMMON_BODY_PARTS[i])

            if part and part:IsA("BasePart") and not seen[part] then
                seen[part] = true
                result[#result + 1] = part
            end
        end

        if #result > 0 then return result end
    end

    return nil
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = true

local function hasLineOfSight(localChar, enemyChar, targetPart)
    if not state.WallCheck then return true end

    local camera = workspace.CurrentCamera
    if not camera or not localChar or not enemyChar or not targetPart then
        return false
    end

    local origin = camera.CFrame.Position
    local delta = targetPart.Position - origin

    if delta.Magnitude <= 0.01 then
        return true
    end

    rayParams.FilterDescendantsInstances = {localChar}
    local result = workspace:Raycast(origin, delta, rayParams)

    if not result then
        return true
    end

    return result.Instance
        and result.Instance:IsDescendantOf(enemyChar)
        or false
end

local function getFovCenter()
    local camera = workspace.CurrentCamera
    if not camera then return Vector2.zero end
    local size = camera.ViewportSize
    return Vector2.new(size.X * 0.5, size.Y * 0.5)
end

local function chooseTarget()
    if not state.Enabled then
        return nil, nil
    end

    local camera = workspace.CurrentCamera
    local localChar, localHum, localRoot = getCharData(player)

    if not camera or not localChar or not localHum or not localRoot then
        return nil, nil
    end

    if state.RequireTool and not getEquippedTool() then
        return nil, nil
    end

    local center = getFovCenter()
    local radiusSq = state.Radius * state.Radius
    local maxDistanceSq = state.MaxDistance * state.MaxDistance
    local bestPlayer, bestPart
    local bestMetric = math.huge

    for i = 1, #runtime.PlayerList do
        local plr = runtime.PlayerList[i]

        if isEnemy(plr) then
            local char, hum, root = getCharData(plr)

            if char and hum and root
                and not char:FindFirstChildOfClass("ForceField")
            then
                local worldDelta = root.Position - localRoot.Position

                if worldDelta:Dot(worldDelta) <= maxDistanceSq then
                    local parts = getTargetParts(char)

                    if parts then
                        for j = 1, #parts do
                            local part = parts[j]

                            if part and part.Parent then
                                local screen, onScreen = camera:WorldToViewportPoint(part.Position)

                                if onScreen and screen.Z > 0 then
                                    local dx = screen.X - center.X
                                    local dy = screen.Y - center.Y
                                    local metric = dx * dx + dy * dy

                                    if (not state.FOVEnabled or metric <= radiusSq)
                                        and metric < bestMetric
                                        and hasLineOfSight(localChar, char, part)
                                    then
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

    return bestPlayer, bestPart
end

-- ==========================================================
-- Shot timing / Tool compatibility
-- ==========================================================

local function markShot()
    runtime.LastShotAt = os.clock()
end

track(UserInputService.InputBegan:Connect(function(input, processed)
    if processed or not state.Enabled then return end

    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        if not state.RequireTool or getEquippedTool() then
            markShot()
        end
    end
end))

local function bindTool(tool)
    if not tool or not tool:IsA("Tool") or runtime.ToolConnections[tool] then
        return
    end

    runtime.ToolConnections[tool] = tool.Activated:Connect(function()
        runtime.LastTool = tool
        if state.Enabled then
            markShot()
        end
    end)

    track(runtime.ToolConnections[tool])
end

local function scanTools(char)
    if not char then return end

    for _, child in ipairs(char:GetChildren()) do
        if child:IsA("Tool") then
            bindTool(child)
        end
    end
end

local function bindCharacter(char)
    runtime.LastTool = nil
    task.defer(function()
        scanTools(char)
    end)

    track(char.ChildAdded:Connect(function(child)
        if child:IsA("Tool") then
            runtime.LastTool = child
            bindTool(child)
        end
    end))
end

if player.Character then
    bindCharacter(player.Character)
end

track(player.CharacterAdded:Connect(bindCharacter))

local backpack = player:FindFirstChildOfClass("Backpack")
if backpack then
    for _, child in ipairs(backpack:GetChildren()) do
        if child:IsA("Tool") then bindTool(child) end
    end

    track(backpack.ChildAdded:Connect(function(child)
        if child:IsA("Tool") then bindTool(child) end
    end))
end

-- ==========================================================
-- Shared metamethod hook. Re-execution only updates this table.
-- ==========================================================

local hook = env.__XERO_UNIVERSAL_SILENT_HOOK

if not hook then
    hook = {
        Target = nil,
        Mouse = mouse,
        Runtime = runtime,
        State = state,
    }
    env.__XERO_UNIVERSAL_SILENT_HOOK = hook

    local oldNamecall
    oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
        local h = env.__XERO_UNIVERSAL_SILENT_HOOK
        local target = h and h.Target
        local rt = h and h.Runtime
        local st = h and h.State

        if h and rt and st
            and rt.Alive
            and st.Enabled
            and target
            and target.Parent
            and not checkcaller()
        then
            local method = getnamecallmethod()

            if self == workspace then
                if method == "Raycast" then
                    local origin, direction, params = ...

                    if typeof(origin) == "Vector3"
                        and typeof(direction) == "Vector3"
                        and direction.Magnitude > 5
                    then
                        local camera = workspace.CurrentCamera
                        local nearCamera = camera
                            and (origin - camera.CFrame.Position).Magnitude <= 1.5

                        local recentShot = os.clock() - (rt.LastShotAt or 0) <= 0.35

                        if not nearCamera or recentShot then
                            local delta = target.Position - origin

                            if delta.Magnitude > 0.01 then
                                return oldNamecall(
                                    self,
                                    origin,
                                    delta.Unit * math.max(direction.Magnitude, 5000),
                                    params
                                )
                            end
                        end
                    end

                elseif method == "FindPartOnRay"
                    or method == "FindPartOnRayWithIgnoreList"
                    or method == "FindPartOnRayWithWhitelist"
                then
                    local ray, p2, p3, p4 = ...

                    if typeof(ray) == "Ray" and ray.Direction.Magnitude > 5 then
                        local camera = workspace.CurrentCamera
                        local nearCamera = camera
                            and (ray.Origin - camera.CFrame.Position).Magnitude <= 1.5

                        local recentShot = os.clock() - (rt.LastShotAt or 0) <= 0.35

                        if not nearCamera or recentShot then
                            local delta = target.Position - ray.Origin

                            if delta.Magnitude > 0.01 then
                                local newRay = Ray.new(
                                    ray.Origin,
                                    delta.Unit * math.max(ray.Direction.Magnitude, 5000)
                                )

                                return oldNamecall(self, newRay, p2, p3, p4)
                            end
                        end
                    end
                end
            end
        elseif h and target and not target.Parent then
            h.Target = nil
        end

        return oldNamecall(self, ...)
    end)

    local oldIndex
    oldIndex = hookmetamethod(game, "__index", function(object, key)
        local h = env.__XERO_UNIVERSAL_SILENT_HOOK
        local target = h and h.Target
        local rt = h and h.Runtime
        local st = h and h.State

        if h and rt and st
            and rt.Alive
            and st.Enabled
            and target
            and target.Parent
            and not checkcaller()
            and object == h.Mouse
        then
            if not st.RequireTool or getEquippedTool() then
                if key == "Hit" or key == "hit" then
                    return target.CFrame
                elseif key == "Target" or key == "target" then
                    return target
                end
            end
        end

        return oldIndex(object, key)
    end)
else
    hook.Target = nil
    hook.Mouse = mouse
    hook.Runtime = runtime
    hook.State = state
end

runtime.Hook = hook

-- ==========================================================
-- UI · self-contained Xero style
-- ==========================================================

local guiParent = player:WaitForChild("PlayerGui")
pcall(function()
    if gethui then
        guiParent = gethui()
    elseif CoreGui then
        guiParent = CoreGui
    end
end)

local oldGui = guiParent:FindFirstChild("XeroUniversalSilent")
if oldGui then oldGui:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name = "XeroUniversalSilent"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = guiParent
runtime.Gui = gui

local main = Instance.new("Frame")
main.Name = "Main"
main.AnchorPoint = Vector2.new(0.5, 0.5)
main.Position = UDim2.fromScale(0.5, 0.5)
main.Size = UDim2.fromOffset(420, 480)
main.BackgroundColor3 = Color3.fromRGB(8, 8, 8)
main.BorderSizePixel = 0
main.Parent = gui
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 16)

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(48, 48, 48)
stroke.Thickness = 1
stroke.Transparency = 0.15
stroke.Parent = main

local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 58)
header.BackgroundTransparency = 1
header.Parent = main

local title = Instance.new("TextLabel")
title.Position = UDim2.fromOffset(18, 10)
title.Size = UDim2.new(1, -60, 0, 24)
title.BackgroundTransparency = 1
title.Text = "XERO | UNIVERSAL"
title.TextColor3 = Color3.fromRGB(245, 245, 245)
title.Font = Enum.Font.GothamBold
title.TextSize = 18
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = header

local subtitle = Instance.new("TextLabel")
subtitle.Position = UDim2.fromOffset(18, 33)
subtitle.Size = UDim2.new(1, -60, 0, 16)
subtitle.BackgroundTransparency = 1
subtitle.Text = "Silent Aim LAB · by Kev"
subtitle.TextColor3 = Color3.fromRGB(130, 130, 130)
subtitle.Font = Enum.Font.Gotham
subtitle.TextSize = 11
subtitle.TextXAlignment = Enum.TextXAlignment.Left
subtitle.Parent = header

local close = Instance.new("TextButton")
close.AnchorPoint = Vector2.new(1, 0)
close.Position = UDim2.new(1, -14, 0, 14)
close.Size = UDim2.fromOffset(30, 30)
close.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
close.Text = "×"
close.TextColor3 = Color3.fromRGB(220, 220, 220)
close.Font = Enum.Font.GothamBold
close.TextSize = 18
close.AutoButtonColor = false
close.Parent = header
Instance.new("UICorner", close).CornerRadius = UDim.new(0, 9)

local scroll = Instance.new("ScrollingFrame")
scroll.Position = UDim2.fromOffset(10, 62)
scroll.Size = UDim2.new(1, -20, 1, -72)
scroll.BackgroundTransparency = 1
scroll.BorderSizePixel = 0
scroll.ScrollBarThickness = 3
scroll.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 80)
scroll.CanvasSize = UDim2.new()
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroll.Parent = main

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 8)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = scroll

local pad = Instance.new("UIPadding")
pad.PaddingLeft = UDim.new(0, 4)
pad.PaddingRight = UDim.new(0, 4)
pad.PaddingBottom = UDim.new(0, 10)
pad.Parent = scroll

local function rowBase(height)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, -8, 0, height or 54)
    row.BackgroundColor3 = Color3.fromRGB(14, 14, 14)
    row.BorderSizePixel = 0
    row.Parent = scroll
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 12)

    local s = Instance.new("UIStroke")
    s.Color = Color3.fromRGB(38, 38, 38)
    s.Transparency = 0.3
    s.Parent = row

    return row
end

local function addSection(text)
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -8, 0, 25)
    label.BackgroundTransparency = 1
    label.Text = string.upper(text)
    label.TextColor3 = Color3.fromRGB(105, 105, 105)
    label.Font = Enum.Font.GothamBold
    label.TextSize = 10
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = scroll
end

local function addToggle(name, desc, default, callback)
    local row = rowBase(60)

    local label = Instance.new("TextLabel")
    label.Position = UDim2.fromOffset(14, 9)
    label.Size = UDim2.new(1, -78, 0, 20)
    label.BackgroundTransparency = 1
    label.Text = name
    label.TextColor3 = Color3.fromRGB(235, 235, 235)
    label.Font = Enum.Font.GothamMedium
    label.TextSize = 13
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = row

    local sub = Instance.new("TextLabel")
    sub.Position = UDim2.fromOffset(14, 30)
    sub.Size = UDim2.new(1, -78, 0, 16)
    sub.BackgroundTransparency = 1
    sub.Text = desc
    sub.TextColor3 = Color3.fromRGB(115, 115, 115)
    sub.Font = Enum.Font.Gotham
    sub.TextSize = 10
    sub.TextXAlignment = Enum.TextXAlignment.Left
    sub.TextTruncate = Enum.TextTruncate.AtEnd
    sub.Parent = row

    local button = Instance.new("TextButton")
    button.AnchorPoint = Vector2.new(1, 0.5)
    button.Position = UDim2.new(1, -14, 0.5, 0)
    button.Size = UDim2.fromOffset(44, 25)
    button.BackgroundColor3 = Color3.fromRGB(32, 32, 32)
    button.Text = ""
    button.AutoButtonColor = false
    button.Parent = row
    Instance.new("UICorner", button).CornerRadius = UDim.new(1, 0)

    local dot = Instance.new("Frame")
    dot.AnchorPoint = Vector2.new(0, 0.5)
    dot.Position = UDim2.new(0, 3, 0.5, 0)
    dot.Size = UDim2.fromOffset(19, 19)
    dot.BackgroundColor3 = Color3.fromRGB(145, 145, 145)
    dot.BorderSizePixel = 0
    dot.Parent = button
    Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)

    local value = default == true

    local function render()
        button.BackgroundColor3 = value
            and Color3.fromRGB(232, 232, 232)
            or Color3.fromRGB(32, 32, 32)
        dot.BackgroundColor3 = value
            and Color3.fromRGB(14, 14, 14)
            or Color3.fromRGB(145, 145, 145)
        dot.Position = value
            and UDim2.new(1, -22, 0.5, 0)
            or UDim2.new(0, 3, 0.5, 0)
    end

    button.Activated:Connect(function()
        value = not value
        render()
        callback(value)
    end)

    render()

    return {
        Set = function(_, v)
            value = v == true
            render()
            callback(value)
        end,
        Get = function()
            return value
        end,
    }
end

local function addCycle(name, desc, values, initial, callback)
    local row = rowBase(60)

    local label = Instance.new("TextLabel")
    label.Position = UDim2.fromOffset(14, 9)
    label.Size = UDim2.new(1, -155, 0, 20)
    label.BackgroundTransparency = 1
    label.Text = name
    label.TextColor3 = Color3.fromRGB(235, 235, 235)
    label.Font = Enum.Font.GothamMedium
    label.TextSize = 13
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = row

    local sub = Instance.new("TextLabel")
    sub.Position = UDim2.fromOffset(14, 30)
    sub.Size = UDim2.new(1, -155, 0, 16)
    sub.BackgroundTransparency = 1
    sub.Text = desc
    sub.TextColor3 = Color3.fromRGB(115, 115, 115)
    sub.Font = Enum.Font.Gotham
    sub.TextSize = 10
    sub.TextXAlignment = Enum.TextXAlignment.Left
    sub.TextTruncate = Enum.TextTruncate.AtEnd
    sub.Parent = row

    local button = Instance.new("TextButton")
    button.AnchorPoint = Vector2.new(1, 0.5)
    button.Position = UDim2.new(1, -14, 0.5, 0)
    button.Size = UDim2.fromOffset(125, 32)
    button.BackgroundColor3 = Color3.fromRGB(24, 24, 24)
    button.TextColor3 = Color3.fromRGB(220, 220, 220)
    button.Font = Enum.Font.GothamMedium
    button.TextSize = 11
    button.AutoButtonColor = false
    button.Parent = row
    Instance.new("UICorner", button).CornerRadius = UDim.new(0, 9)

    local index = 1
    for i = 1, #values do
        if values[i] == initial then
            index = i
            break
        end
    end

    local function render()
        button.Text = tostring(values[index])
    end

    button.Activated:Connect(function()
        index = (index % #values) + 1
        render()
        callback(values[index])
    end)

    render()
end

local function addStepper(name, desc, min, max, step, initial, callback)
    local row = rowBase(64)

    local label = Instance.new("TextLabel")
    label.Position = UDim2.fromOffset(14, 8)
    label.Size = UDim2.new(1, -150, 0, 20)
    label.BackgroundTransparency = 1
    label.Text = name
    label.TextColor3 = Color3.fromRGB(235, 235, 235)
    label.Font = Enum.Font.GothamMedium
    label.TextSize = 13
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = row

    local sub = Instance.new("TextLabel")
    sub.Position = UDim2.fromOffset(14, 31)
    sub.Size = UDim2.new(1, -150, 0, 16)
    sub.BackgroundTransparency = 1
    sub.Text = desc
    sub.TextColor3 = Color3.fromRGB(115, 115, 115)
    sub.Font = Enum.Font.Gotham
    sub.TextSize = 10
    sub.TextXAlignment = Enum.TextXAlignment.Left
    sub.Parent = row

    local minus = Instance.new("TextButton")
    minus.AnchorPoint = Vector2.new(1, 0.5)
    minus.Position = UDim2.new(1, -108, 0.5, 0)
    minus.Size = UDim2.fromOffset(32, 32)
    minus.BackgroundColor3 = Color3.fromRGB(24, 24, 24)
    minus.Text = "−"
    minus.TextColor3 = Color3.fromRGB(230, 230, 230)
    minus.Font = Enum.Font.GothamBold
    minus.TextSize = 16
    minus.AutoButtonColor = false
    minus.Parent = row
    Instance.new("UICorner", minus).CornerRadius = UDim.new(0, 9)

    local valueLabel = Instance.new("TextLabel")
    valueLabel.AnchorPoint = Vector2.new(1, 0.5)
    valueLabel.Position = UDim2.new(1, -52, 0.5, 0)
    valueLabel.Size = UDim2.fromOffset(50, 32)
    valueLabel.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    valueLabel.TextColor3 = Color3.fromRGB(230, 230, 230)
    valueLabel.Font = Enum.Font.GothamMedium
    valueLabel.TextSize = 11
    valueLabel.Parent = row
    Instance.new("UICorner", valueLabel).CornerRadius = UDim.new(0, 9)

    local plus = Instance.new("TextButton")
    plus.AnchorPoint = Vector2.new(1, 0.5)
    plus.Position = UDim2.new(1, -14, 0.5, 0)
    plus.Size = UDim2.fromOffset(32, 32)
    plus.BackgroundColor3 = Color3.fromRGB(24, 24, 24)
    plus.Text = "+"
    plus.TextColor3 = Color3.fromRGB(230, 230, 230)
    plus.Font = Enum.Font.GothamBold
    plus.TextSize = 16
    plus.AutoButtonColor = false
    plus.Parent = row
    Instance.new("UICorner", plus).CornerRadius = UDim.new(0, 9)

    local value = initial

    local function set(v)
        value = math.clamp(v, min, max)
        valueLabel.Text = tostring(value)
        callback(value)
    end

    minus.Activated:Connect(function()
        set(value - step)
    end)

    plus.Activated:Connect(function()
        set(value + step)
    end)

    set(value)
end

addSection("Silent Aim")

addToggle(
    "Silent Aim",
    "Redirige raycasts/mouse hacia el objetivo.",
    state.Enabled,
    function(v)
        state.Enabled = v
        if not v then
            runtime.Target = nil
            runtime.TargetPlayer = nil
            hook.Target = nil
        end
    end
)

addCycle(
    "Parte objetivo",
    "Cabeza, torso o parte más cercana.",
    {"Head", "Torso", "Nearest"},
    state.TargetMode,
    function(v)
        state.TargetMode = v
    end
)

addToggle(
    "Wall Check",
    "Ignora enemigos detrás de paredes.",
    state.WallCheck,
    function(v)
        state.WallCheck = v
    end
)

addToggle(
    "Requerir Tool",
    "Evita tocar raycasts si no hay arma Tool equipada.",
    state.RequireTool,
    function(v)
        state.RequireTool = v
    end
)

addSection("FOV")

addToggle(
    "Usar FOV",
    "Limita objetivos al círculo central.",
    state.FOVEnabled,
    function(v)
        state.FOVEnabled = v
    end
)

addToggle(
    "Mostrar FOV",
    "Muestra el círculo de búsqueda.",
    state.ShowFOV,
    function(v)
        state.ShowFOV = v
    end
)

addStepper(
    "Radio FOV",
    "Ajusta el radio del círculo.",
    30,
    500,
    10,
    state.Radius,
    function(v)
        state.Radius = v
    end
)

addSection("Detección")

addCycle(
    "Detección de enemigos",
    "Auto intenta equipos; FFA toma a todos.",
    {"Auto", "FFA"},
    state.DetectionMode,
    function(v)
        state.DetectionMode = v
        runtime.TeamSchemeAt = 0
        detectTeamScheme(true)
    end
)

local statusRow = rowBase(82)

local statusTitle = Instance.new("TextLabel")
statusTitle.Position = UDim2.fromOffset(14, 9)
statusTitle.Size = UDim2.new(1, -28, 0, 20)
statusTitle.BackgroundTransparency = 1
statusTitle.Text = "Estado"
statusTitle.TextColor3 = Color3.fromRGB(235, 235, 235)
statusTitle.Font = Enum.Font.GothamMedium
statusTitle.TextSize = 13
statusTitle.TextXAlignment = Enum.TextXAlignment.Left
statusTitle.Parent = statusRow

local detectionLabel = Instance.new("TextLabel")
detectionLabel.Position = UDim2.fromOffset(14, 30)
detectionLabel.Size = UDim2.new(1, -28, 0, 16)
detectionLabel.BackgroundTransparency = 1
detectionLabel.Text = "Detección: ..."
detectionLabel.TextColor3 = Color3.fromRGB(135, 135, 135)
detectionLabel.Font = Enum.Font.Gotham
detectionLabel.TextSize = 10
detectionLabel.TextXAlignment = Enum.TextXAlignment.Left
detectionLabel.Parent = statusRow

local targetLabel = Instance.new("TextLabel")
targetLabel.Position = UDim2.fromOffset(14, 49)
targetLabel.Size = UDim2.new(1, -28, 0, 16)
targetLabel.BackgroundTransparency = 1
targetLabel.Text = "Target: ninguno"
targetLabel.TextColor3 = Color3.fromRGB(135, 135, 135)
targetLabel.Font = Enum.Font.Gotham
targetLabel.TextSize = 10
targetLabel.TextXAlignment = Enum.TextXAlignment.Left
targetLabel.TextTruncate = Enum.TextTruncate.AtEnd
targetLabel.Parent = statusRow

-- FOV circle using ordinary UI so it works without Drawing API.
local fov = Instance.new("Frame")
fov.Name = "FOV"
fov.AnchorPoint = Vector2.new(0.5, 0.5)
fov.BackgroundTransparency = 1
fov.BorderSizePixel = 0
fov.ZIndex = 900
fov.Parent = gui
Instance.new("UICorner", fov).CornerRadius = UDim.new(1, 0)

local fovStroke = Instance.new("UIStroke")
fovStroke.Thickness = 2
fovStroke.Color = Color3.fromRGB(210, 210, 210)
fovStroke.Transparency = 0.18
fovStroke.Parent = fov

local function updateFOV()
    local camera = workspace.CurrentCamera
    if not camera then
        fov.Visible = false
        return
    end

    local viewport = camera.ViewportSize
    local radius = state.Radius

    fov.Position = UDim2.fromOffset(
        viewport.X * 0.5,
        viewport.Y * 0.5
    )
    fov.Size = UDim2.fromOffset(radius * 2, radius * 2)
    fov.Visible = state.ShowFOV and state.Enabled and state.FOVEnabled
    fovStroke.Color = runtime.Target
        and Color3.fromRGB(120, 220, 140)
        or Color3.fromRGB(210, 210, 210)
end

-- Dragging
do
    local dragging = false
    local dragInput
    local startPos
    local startFrame

    header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch
        then
            dragging = true
            dragInput = input
            startPos = input.Position
            startFrame = main.Position
        end
    end)

    header.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch
        then
            dragInput = input
        end
    end)

    track(UserInputService.InputChanged:Connect(function(input)
        if dragging and input == dragInput then
            local delta = input.Position - startPos
            main.Position = UDim2.new(
                startFrame.X.Scale,
                startFrame.X.Offset + delta.X,
                startFrame.Y.Scale,
                startFrame.Y.Offset + delta.Y
            )
        end
    end))

    track(UserInputService.InputEnded:Connect(function(input)
        if dragging and (
            input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch
        ) then
            dragging = false
        end
    end))
end

-- Open button after hiding hub.
local open = Instance.new("TextButton")
open.AnchorPoint = Vector2.new(0, 0.5)
open.Position = UDim2.new(0, 14, 0.5, 0)
open.Size = UDim2.fromOffset(112, 38)
open.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
open.Text = "Open XeroHub"
open.TextColor3 = Color3.fromRGB(235, 235, 235)
open.Font = Enum.Font.GothamMedium
open.TextSize = 11
open.AutoButtonColor = false
open.Visible = false
open.Parent = gui
Instance.new("UICorner", open).CornerRadius = UDim.new(0, 12)

close.Activated:Connect(function()
    main.Visible = false
    open.Visible = true
end)

open.Activated:Connect(function()
    main.Visible = true
    open.Visible = false
end)

-- ==========================================================
-- Player cache + target loop
-- ==========================================================

local function addPlayer(plr)
    for i = 1, #runtime.PlayerList do
        if runtime.PlayerList[i] == plr then return end
    end
    runtime.PlayerList[#runtime.PlayerList + 1] = plr
    runtime.TeamSchemeAt = 0
end

local function removePlayer(plr)
    runtime.CharacterCache[plr] = nil

    for i = #runtime.PlayerList, 1, -1 do
        if runtime.PlayerList[i] == plr then
            runtime.PlayerList[i] = runtime.PlayerList[#runtime.PlayerList]
            runtime.PlayerList[#runtime.PlayerList] = nil
            break
        end
    end

    runtime.TeamSchemeAt = 0
end

track(Players.PlayerAdded:Connect(addPlayer))
track(Players.PlayerRemoving:Connect(removePlayer))

local accumulator = 0
track(RunService.Heartbeat:Connect(function(dt)
    if not runtime.Alive then return end

    accumulator += dt
    if accumulator < 0.03 then return end
    accumulator = 0

    detectTeamScheme(false)

    local plr, part = chooseTarget()
    runtime.TargetPlayer = plr
    runtime.Target = part
    hook.Target = part

    detectionLabel.Text = "Detección: " .. runtime.TeamScheme.Label

    if plr and part then
        targetLabel.Text = "Target: @" .. plr.Name .. " · " .. part.Name
    else
        targetLabel.Text = "Target: ninguno"
    end
end))

track(RunService.RenderStepped:Connect(updateFOV))

runtime.Cleanup = function()
    if not runtime.Alive then return end
    runtime.Alive = false

    if runtime.Hook and runtime.Hook.Runtime == runtime then
        runtime.Hook.Target = nil
    end

    for i = #runtime.Connections, 1, -1 do
        safeDisconnect(runtime.Connections[i])
        runtime.Connections[i] = nil
    end

    if runtime.Gui then
        pcall(function() runtime.Gui:Destroy() end)
        runtime.Gui = nil
    end
end

print("[XeroHub] Universal Silent Aim LAB cargado | Auto Enemy Detection | by Kev")
