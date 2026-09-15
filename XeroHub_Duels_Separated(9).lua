--==============================================================
-- Xero | Runtime Emote Spy
-- Creator: Kev
--
-- Ejecutar ANTES del script ofuscado.
-- No modifica llamadas; solamente observa y registra.
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
local connections = {}

local function track(c)
    if c then
        connections[#connections + 1] = c
    end
    return c
end

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

    local kind = typeof(value)

    if kind == "Instance" then
        return "<" .. value.ClassName .. "> " .. fullPath(value)

    elseif kind == "string" then
        if #value > 180 then
            value = value:sub(1, 180) .. "..."
        end
        return '"' .. value .. '"'

    elseif kind == "table" then
        local parts = {}
        local count = 0

        for k, v in pairs(value) do
            count += 1

            if count > 12 then
                parts[#parts + 1] = "..."
                break
            end

            parts[#parts + 1] =
                "[" .. serialize(k, depth + 1) .. "]=" ..
                serialize(v, depth + 1)
        end

        return "{" .. table.concat(parts, ", ") .. "}"

    else
        return tostring(value)
    end
end

local function serializeArgs(...)
    local args = {...}
    local out = {}

    for i = 1, math.min(#args, 15) do
        out[#out + 1] =
            "[" .. i .. "] " .. serialize(args[i])
    end

    return table.concat(out, "\n")
end

--==============================================================
-- UI
--==============================================================

local old = playerGui:FindFirstChild("XeroRuntimeEmoteSpy")
if old then
    old:Destroy()
end

local gui = Instance.new("ScreenGui")
gui.Name = "XeroRuntimeEmoteSpy"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 999999

local guiParent = playerGui

pcall(function()
    if gethui then
        guiParent = gethui()
    end
end)

gui.Parent = guiParent

local main = Instance.new("Frame")
main.Size = UDim2.fromOffset(600, 450)
main.Position = UDim2.new(0.5, -300, 0.5, -225)
main.BackgroundColor3 = Color3.fromRGB(9, 9, 9)
main.BorderSizePixel = 0
main.Parent = gui

Instance.new("UICorner", main).CornerRadius = UDim.new(0, 16)

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(55, 55, 55)
stroke.Parent = main

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -30, 0, 30)
title.Position = UDim2.fromOffset(15, 10)
title.BackgroundTransparency = 1
title.Text = "XERO | RUNTIME EMOTE SPY"
title.TextColor3 = Color3.fromRGB(245, 245, 245)
title.Font = Enum.Font.GothamBold
title.TextSize = 16
title.TextXAlignment = Enum.TextXAlignment.Left
title.Active = true
title.Parent = main

local status = Instance.new("TextLabel")
status.Size = UDim2.new(1, -30, 0, 18)
status.Position = UDim2.fromOffset(15, 39)
status.BackgroundTransparency = 1
status.Text = "DETENIDO · inicia grabación antes de usar el otro script"
status.TextColor3 = Color3.fromRGB(145, 145, 145)
status.Font = Enum.Font.Gotham
status.TextSize = 11
status.TextXAlignment = Enum.TextXAlignment.Left
status.Parent = main

local buttons = Instance.new("Frame")
buttons.Size = UDim2.new(1, -30, 0, 35)
buttons.Position = UDim2.fromOffset(15, 66)
buttons.BackgroundTransparency = 1
buttons.Parent = main

local list = Instance.new("UIListLayout")
list.FillDirection = Enum.FillDirection.Horizontal
list.Padding = UDim.new(0, 7)
list.Parent = buttons

local function makeButton(text, width)
    local b = Instance.new("TextButton")
    b.Size = UDim2.fromOffset(width, 34)
    b.BackgroundColor3 = Color3.fromRGB(24, 24, 24)
    b.BorderSizePixel = 0
    b.Text = text
    b.TextColor3 = Color3.fromRGB(225, 225, 225)
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

local outputLayout = Instance.new("UIListLayout")
outputLayout.Padding = UDim.new(0, 5)
outputLayout.Parent = output

outputLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    output.CanvasSize =
        UDim2.fromOffset(0, outputLayout.AbsoluteContentSize.Y + 16)
end)

local function addLog(category, message)
    if not recording and category ~= "SYSTEM" then
        return
    end

    local final =
        "[" .. tostring(category) .. "]\n" ..
        tostring(message)

    logs[#logs + 1] = final

    print("\n[Xero Runtime Spy]\n" .. final)

    local label = Instance.new("TextLabel")
    label.AutomaticSize = Enum.AutomaticSize.Y
    label.Size = UDim2.new(1, -5, 0, 0)
    label.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    label.BackgroundTransparency = 0.2
    label.BorderSizePixel = 0
    label.Text = final
    label.TextColor3 = Color3.fromRGB(210, 210, 210)
    label.Font = Enum.Font.Code
    label.TextSize = 11
    label.TextWrapped = true
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextYAlignment = Enum.TextYAlignment.Top
    label.Parent = output

    local pad = Instance.new("UIPadding")
    pad.PaddingTop = UDim.new(0, 7)
    pad.PaddingBottom = UDim.new(0, 7)
    pad.PaddingLeft = UDim.new(0, 8)
    pad.PaddingRight = UDim.new(0, 8)
    pad.Parent = label

    Instance.new("UICorner", label).CornerRadius = UDim.new(0, 7)

    task.defer(function()
        output.CanvasPosition = Vector2.new(
            0,
            math.max(0, outputLayout.AbsoluteContentSize.Y)
        )
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

    track(animator.AnimationPlayed:Connect(function(trackObject)
        if not recording then
            return
        end

        local animation = trackObject.Animation

        local id = "?"
        local animationPath = "?"

        if animation then
            id = tostring(animation.AnimationId)
            animationPath = fullPath(animation)
        end

        local priority = "?"
        local looped = "?"

        pcall(function()
            priority = tostring(trackObject.Priority)
            looped = tostring(trackObject.Looped)
        end)

        addLog(
            "ANIMATION PLAYED",
            "Animator: " .. fullPath(animator) ..
            "\nAnimationId: " .. id ..
            "\nAnimation: " .. animationPath ..
            "\nPriority: " .. priority ..
            "\nLooped: " .. looped
        )
    end))
end

local function scanAnimators(root)
    if not root then
        return
    end

    if root:IsA("Animator") then
        watchAnimator(root)
    end

    for _, obj in ipairs(root:GetDescendants()) do
        if obj:IsA("Animator") then
            watchAnimator(obj)
        end
    end
end

scanAnimators(Workspace)
scanAnimators(playerGui)

track(Workspace.DescendantAdded:Connect(function(obj)
    if obj:IsA("Animator") then
        watchAnimator(obj)
    end
end))

track(playerGui.DescendantAdded:Connect(function(obj)
    if obj:IsA("Animator") then
        watchAnimator(obj)
    end
end))

--==============================================================
-- EMOTE-SPECIFIC INSTANCE WATCHER
--==============================================================

local function relevantPath(obj)
    local p = string.lower(fullPath(obj))

    return p:find("emote", 1, true)
        or p:find("emotewheel", 1, true)
        or p:find("emoteanimations", 1, true)
end

local function inspectNewObject(obj)
    if not recording then
        return
    end

    if obj:IsA("Animation") and relevantPath(obj) then
        addLog(
            "NEW ANIMATION",
            "Ruta: " .. fullPath(obj) ..
            "\nAnimationId: " .. tostring(obj.AnimationId)
        )

        track(obj:GetPropertyChangedSignal("AnimationId"):Connect(function()
            if recording then
                addLog(
                    "ANIMATION ID CHANGED",
                    "Ruta: " .. fullPath(obj) ..
                    "\nAnimationId: " .. tostring(obj.AnimationId)
                )
            end
        end))

    elseif relevantPath(obj) then
        if obj:IsA("StringValue")
            or obj:IsA("IntValue")
            or obj:IsA("NumberValue")
            or obj:IsA("BoolValue") then

            addLog(
                "EMOTE OBJECT",
                "Clase: " .. obj.ClassName ..
                "\nRuta: " .. fullPath(obj) ..
                "\nValue: " .. tostring(obj.Value)
            )
        end
    end
end

track(playerGui.DescendantAdded:Connect(inspectNewObject))
track(Workspace.DescendantAdded:Connect(inspectNewObject))
track(ReplicatedStorage.DescendantAdded:Connect(inspectNewObject))

--==============================================================
-- __namecall SPY
--==============================================================

local namecallInstalled = false
local hookBusy = false

if hookmetamethod and getnamecallmethod and newcclosure then
    local oldNamecall

    oldNamecall = hookmetamethod(
        game,
        "__namecall",
        newcclosure(function(self, ...)
            local method = getnamecallmethod()

            if hookBusy or not recording then
                return oldNamecall(self, ...)
            end

            local shouldLog =
                method == "FireServer"
                or method == "InvokeServer"
                or method == "LoadAnimation"

            if shouldLog then
                hookBusy = true

                pcall(function()
                    local origin = "UNKNOWN"

                    if checkcaller then
                        origin = checkcaller() and "EXECUTOR" or "GAME"
                    end

                    if method == "FireServer"
                        or method == "InvokeServer" then

                        addLog(
                            origin .. " REMOTE · " .. method,
                            "Remote: " .. fullPath(self) ..
                            "\nClase: " .. tostring(self.ClassName) ..
                            "\nArgumentos:\n" ..
                            serializeArgs(...)
                        )

                    elseif method == "LoadAnimation" then
                        local args = {...}
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

                hookBusy = false
            end

            return oldNamecall(self, ...)
        end)
    )

    namecallInstalled = true
end

--==============================================================
-- BUTTONS
--==============================================================

recordButton.MouseButton1Click:Connect(function()
    recording = not recording

    if recording then
        recordButton.Text = "DETENER"
        status.Text = "GRABANDO · ahora usa UN emote del script ofuscado"

        addLog(
            "SYSTEM",
            "Grabación iniciada.\n" ..
            "Ahora ejecuta/usa el script ofuscado y activa solamente un emote."
        )
    else
        recordButton.Text = "INICIAR"
        status.Text = "DETENIDO"

        addLog(
            "SYSTEM",
            "Grabación detenida."
        )
    end
end)

clearButton.MouseButton1Click:Connect(function()
    table.clear(logs)

    for _, child in ipairs(output:GetChildren()) do
        if child:IsA("TextLabel") then
            child:Destroy()
        end
    end
end)

copyButton.MouseButton1Click:Connect(function()
    if setclipboard then
        pcall(
            setclipboard,
            table.concat(logs, "\n\n")
        )

        addLog(
            "SYSTEM",
            "Reporte copiado."
        )
    end
end)

--==============================================================
-- DRAG
--==============================================================

local dragging = false
local dragStart
local startingPosition

title.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then

        dragging = true
        dragStart = input.Position
        startingPosition = main.Position
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if not dragging then
        return
    end

    if input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch then

        local delta = input.Position - dragStart

        main.Position = UDim2.new(
            startingPosition.X.Scale,
            startingPosition.X.Offset + delta.X,
            startingPosition.Y.Scale,
            startingPosition.Y.Offset + delta.Y
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
    "Scanner cargado.\n" ..
    "Namecall Spy: " .. (namecallInstalled and "OK" or "NO DISPONIBLE") ..
    "\n\nOrden:\n" ..
    "1. INICIAR\n" ..
    "2. Ejecutar el script ofuscado\n" ..
    "3. Hacer UN emote\n" ..
    "4. DETENER\n" ..
    "5. COPIAR TODO"
)
