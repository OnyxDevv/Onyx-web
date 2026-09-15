--==============================================================
-- Xero | Runtime Emote Spy V2
-- Creator: Kev
--==============================================================

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local recording = false
local logs = {}
local hookedAnimators = setmetatable({}, {__mode = "k"})

--==============================================================
-- HELPERS
--==============================================================

local function fullPath(obj)
    if typeof(obj) ~= "Instance" then
        return tostring(obj)
    end

    local ok, result = pcall(function()
        return obj:GetFullName()
    end)

    return ok and result or tostring(obj)
end

local function serialize(value, depth)
    depth = depth or 0

    if depth >= 2 then
        return "..."
    end

    local t = typeof(value)

    if t == "Instance" then
        return "<" .. value.ClassName .. "> " .. fullPath(value)

    elseif t == "string" then
        if #value > 150 then
            value = value:sub(1, 150) .. "..."
        end

        return '"' .. value .. '"'

    elseif t == "table" then
        local result = {}
        local count = 0

        for k, v in pairs(value) do
            count += 1

            if count > 10 then
                result[#result + 1] = "..."
                break
            end

            result[#result + 1] =
                "[" .. serialize(k, depth + 1) .. "]=" ..
                serialize(v, depth + 1)
        end

        return "{" .. table.concat(result, ", ") .. "}"
    end

    return tostring(value)
end

local function serializePackedArgs(args)
    local out = {}

    local count = args.n or #args

    for i = 1, math.min(count, 15) do
        out[#out + 1] =
            "[" .. i .. "] " .. serialize(args[i])
    end

    if #out == 0 then
        return "(sin argumentos)"
    end

    return table.concat(out, "\n")
end

--==============================================================
-- GUI
--==============================================================

local guiParent = playerGui

pcall(function()
    if gethui then
        guiParent = gethui()
    end
end)

local old =
    guiParent:FindFirstChild("XeroRuntimeEmoteSpy")
    or playerGui:FindFirstChild("XeroRuntimeEmoteSpy")

if old then
    old:Destroy()
end

local gui = Instance.new("ScreenGui")
gui.Name = "XeroRuntimeEmoteSpy"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 999999
gui.Parent = guiParent

local main = Instance.new("Frame")
main.Size = UDim2.fromOffset(600, 440)
main.Position = UDim2.new(0.5, -300, 0.5, -220)
main.BackgroundColor3 = Color3.fromRGB(9, 9, 9)
main.BorderSizePixel = 0
main.Parent = gui

Instance.new("UICorner", main).CornerRadius = UDim.new(0, 16)

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(60, 60, 60)
stroke.Thickness = 1
stroke.Parent = main

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -30, 0, 28)
title.Position = UDim2.fromOffset(15, 11)
title.BackgroundTransparency = 1
title.Text = "XERO | RUNTIME EMOTE SPY V2"
title.TextColor3 = Color3.fromRGB(245, 245, 245)
title.Font = Enum.Font.GothamBold
title.TextSize = 15
title.TextXAlignment = Enum.TextXAlignment.Left
title.Active = true
title.Parent = main

local status = Instance.new("TextLabel")
status.Size = UDim2.new(1, -30, 0, 18)
status.Position = UDim2.fromOffset(15, 40)
status.BackgroundTransparency = 1
status.Text = "DETENIDO"
status.TextColor3 = Color3.fromRGB(140, 140, 140)
status.Font = Enum.Font.Gotham
status.TextSize = 11
status.TextXAlignment = Enum.TextXAlignment.Left
status.Parent = main

local buttons = Instance.new("Frame")
buttons.Size = UDim2.new(1, -30, 0, 35)
buttons.Position = UDim2.fromOffset(15, 67)
buttons.BackgroundTransparency = 1
buttons.Parent = main

local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Horizontal
layout.Padding = UDim.new(0, 7)
layout.Parent = buttons

local function makeButton(text, width)
    local b = Instance.new("TextButton")
    b.Size = UDim2.fromOffset(width, 34)
    b.BackgroundColor3 = Color3.fromRGB(24, 24, 24)
    b.BorderSizePixel = 0
    b.Text = text
    b.TextColor3 = Color3.fromRGB(230, 230, 230)
    b.Font = Enum.Font.GothamMedium
    b.TextSize = 11
    b.Parent = buttons

    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 9)

    return b
end

local recordButton = makeButton("INICIAR", 100)
local clearButton = makeButton("LIMPIAR", 90)
local copyButton = makeButton("COPIAR TODO", 115)

local output = Instance.new("ScrollingFrame")
output.Size = UDim2.new(1, -30, 1, -120)
output.Position = UDim2.fromOffset(15, 110)
output.BackgroundColor3 = Color3.fromRGB(14, 14, 14)
output.BorderSizePixel = 0
output.ScrollBarThickness = 3
output.CanvasSize = UDim2.new()
output.Parent = main

Instance.new("UICorner", output).CornerRadius = UDim.new(0, 10)

local padding = Instance.new("UIPadding")
padding.PaddingTop = UDim.new(0, 8)
padding.PaddingBottom = UDim.new(0, 8)
padding.PaddingLeft = UDim.new(0, 8)
padding.PaddingRight = UDim.new(0, 8)
padding.Parent = output

local list = Instance.new("UIListLayout")
list.Padding = UDim.new(0, 5)
list.Parent = output

list:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    output.CanvasSize =
        UDim2.fromOffset(0, list.AbsoluteContentSize.Y + 16)
end)

local function addLog(category, message, force)
    if not recording and not force then
        return
    end

    local text =
        "[" .. tostring(category) .. "]\n" ..
        tostring(message)

    logs[#logs + 1] = text

    print("\n[Xero Emote Spy]\n" .. text)

    local label = Instance.new("TextLabel")
    label.AutomaticSize = Enum.AutomaticSize.Y
    label.Size = UDim2.new(1, -5, 0, 0)
    label.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    label.BorderSizePixel = 0
    label.Text = text
    label.TextColor3 = Color3.fromRGB(215, 215, 215)
    label.Font = Enum.Font.Code
    label.TextSize = 11
    label.TextWrapped = true
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextYAlignment = Enum.TextYAlignment.Top
    label.Parent = output

    local p = Instance.new("UIPadding")
    p.PaddingTop = UDim.new(0, 7)
    p.PaddingBottom = UDim.new(0, 7)
    p.PaddingLeft = UDim.new(0, 8)
    p.PaddingRight = UDim.new(0, 8)
    p.Parent = label

    Instance.new("UICorner", label).CornerRadius = UDim.new(0, 7)

    task.defer(function()
        output.CanvasPosition =
            Vector2.new(0, math.max(0, list.AbsoluteContentSize.Y))
    end)
end

--==============================================================
-- ANIMATION WATCHER
--==============================================================

local function watchAnimator(animator)
    if not animator or hookedAnimators[animator] then
        return
    end

    hookedAnimators[animator] = true

    animator.AnimationPlayed:Connect(function(track)
        if not recording then
            return
        end

        local animation = track.Animation

        local id = "?"
        local animPath = "?"

        if animation then
            id = tostring(animation.AnimationId)
            animPath = fullPath(animation)
        end

        local priority = "?"
        local looped = "?"

        pcall(function()
            priority = tostring(track.Priority)
            looped = tostring(track.Looped)
        end)

        addLog(
            "ANIMATION PLAYED",
            "Animator: " .. fullPath(animator) ..
            "\nAnimationId: " .. id ..
            "\nAnimation: " .. animPath ..
            "\nPriority: " .. priority ..
            "\nLooped: " .. looped
        )
    end)
end

local function scanForAnimators(root)
    if not root then
        return
    end

    for _, obj in ipairs(root:GetDescendants()) do
        if obj:IsA("Animator") then
            watchAnimator(obj)
        end
    end
end

scanForAnimators(Workspace)
scanForAnimators(playerGui)

Workspace.DescendantAdded:Connect(function(obj)
    if obj:IsA("Animator") then
        watchAnimator(obj)
    end
end)

playerGui.DescendantAdded:Connect(function(obj)
    if obj:IsA("Animator") then
        watchAnimator(obj)
    end
end)

--==============================================================
-- EMOTE OBJECT WATCHER
--==============================================================

local function isEmotePath(obj)
    local p = string.lower(fullPath(obj))

    return p:find("emote", 1, true) ~= nil
end

local function inspectCreated(obj)
    if not recording then
        return
    end

    if obj:IsA("Animation") and isEmotePath(obj) then
        addLog(
            "EMOTE ANIMATION CREATED",
            "Ruta: " .. fullPath(obj) ..
            "\nAnimationId: " .. tostring(obj.AnimationId)
        )

        obj:GetPropertyChangedSignal("AnimationId"):Connect(function()
            if recording then
                addLog(
                    "ANIMATION ID CHANGED",
                    "Ruta: " .. fullPath(obj) ..
                    "\nAnimationId: " .. tostring(obj.AnimationId)
                )
            end
        end)
    end
end

Workspace.DescendantAdded:Connect(inspectCreated)
playerGui.DescendantAdded:Connect(inspectCreated)
ReplicatedStorage.DescendantAdded:Connect(inspectCreated)

--==============================================================
-- __NAMECALL SPY
--==============================================================

local namecallStatus = "NO SOPORTADO"

if type(hookmetamethod) == "function"
    and type(getnamecallmethod) == "function" then

    local oldNamecall
    local busy = false

    local function hookFunction(self, ...)
        local args = table.pack(...)
        local method = getnamecallmethod()

        if recording and not busy then
            local shouldLog =
                method == "FireServer"
                or method == "InvokeServer"
                or method == "LoadAnimation"

            if shouldLog then
                busy = true

                local ok, err = pcall(function()
                    local origin = "DESCONOCIDO"

                    if type(checkcaller) == "function" then
                        origin =
                            checkcaller()
                            and "EXECUTOR"
                            or "GAME"
                    end

                    if method == "FireServer"
                        or method == "InvokeServer" then

                        addLog(
                            origin .. " REMOTE · " .. method,
                            "Ruta: " .. fullPath(self) ..
                            "\nClase: " .. tostring(self.ClassName) ..
                            "\nArgumentos:\n" ..
                            serializePackedArgs(args)
                        )

                    elseif method == "LoadAnimation" then
                        local animation = args[1]

                        local id = "?"
                        local animPath = "?"

                        if typeof(animation) == "Instance"
                            and animation:IsA("Animation") then

                            id = tostring(animation.AnimationId)
                            animPath = fullPath(animation)
                        end

                        addLog(
                            origin .. " · LoadAnimation",
                            "Objeto: " .. fullPath(self) ..
                            "\nAnimation: " .. animPath ..
                            "\nAnimationId: " .. id
                        )
                    end
                end)

                if not ok then
                    warn("[Xero Spy hook]", err)
                end

                busy = false
            end
        end

        return oldNamecall(
            self,
            table.unpack(args, 1, args.n)
        )
    end

    local wrapper = hookFunction

    if type(newcclosure) == "function" then
        wrapper = newcclosure(hookFunction)
    end

    local success, result = pcall(function()
        oldNamecall = hookmetamethod(
            game,
            "__namecall",
            wrapper
        )
    end)

    if success and oldNamecall then
        namecallStatus = "OK"
    else
        namecallStatus =
            "ERROR: " .. tostring(result)
    end
end

--==============================================================
-- BUTTONS
--==============================================================

recordButton.MouseButton1Click:Connect(function()
    recording = not recording

    if recording then
        recordButton.Text = "DETENER"
        status.Text =
            "GRABANDO · ahora ejecuta el otro script y haz un emote"

        addLog(
            "SYSTEM",
            "Grabación iniciada.",
            true
        )
    else
        recordButton.Text = "INICIAR"
        status.Text = "DETENIDO"

        addLog(
            "SYSTEM",
            "Grabación detenida.",
            true
        )
    end
end)

clearButton.MouseButton1Click:Connect(function()
    table.clear(logs)

    for _, obj in ipairs(output:GetChildren()) do
        if obj:IsA("TextLabel") then
            obj:Destroy()
        end
    end
end)

copyButton.MouseButton1Click:Connect(function()
    if type(setclipboard) == "function" then
        setclipboard(table.concat(logs, "\n\n"))

        addLog(
            "SYSTEM",
            "Reporte copiado.",
            true
        )
    else
        addLog(
            "SYSTEM",
            "setclipboard no disponible.",
            true
        )
    end
end)

--==============================================================
-- DRAG
--==============================================================

local dragging = false
local startMouse
local startPosition

title.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then

        dragging = true
        startMouse = input.Position
        startPosition = main.Position
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if not dragging then
        return
    end

    if input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch then

        local delta = input.Position - startMouse

        main.Position = UDim2.new(
            startPosition.X.Scale,
            startPosition.X.Offset + delta.X,
            startPosition.Y.Scale,
            startPosition.Y.Offset + delta.Y
        )
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then

        dragging = false
    end
end)

--==============================================================

addLog(
    "SYSTEM",
    "Scanner cargado correctamente.\n" ..
    "__namecall: " .. namecallStatus ..
    "\n\n1. Pulsa INICIAR" ..
    "\n2. Ejecuta el script ofuscado" ..
    "\n3. Selecciona UN emote" ..
    "\n4. Pulsa DETENER" ..
    "\n5. COPIAR TODO",
    true
)
