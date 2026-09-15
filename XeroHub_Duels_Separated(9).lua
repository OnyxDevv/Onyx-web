-- Xero | EmoteAnimations Scanner
-- Kev

local Players = game:GetService("Players")

local player = Players.LocalPlayer

local function getCharacter()
    return player.Character or player.CharacterAdded:Wait()
end

local function getPath(obj)
    local ok, path = pcall(function()
        return obj:GetFullName()
    end)

    return ok and path or tostring(obj)
end

local function printAttributes(obj)
    local attrs = obj:GetAttributes()

    for name, value in pairs(attrs) do
        print("      ATTRIBUTE:", name, "=", value)
    end
end

local function inspect(obj)
    print("------------------------------------------------")
    print("Nombre:", obj.Name)
    print("Clase:", obj.ClassName)
    print("Ruta:", getPath(obj))

    if obj:IsA("Animation") then
        print("AnimationId:", obj.AnimationId)

    elseif obj:IsA("StringValue")
        or obj:IsA("IntValue")
        or obj:IsA("NumberValue")
        or obj:IsA("BoolValue")
        or obj:IsA("ObjectValue")
        or obj:IsA("CFrameValue")
        or obj:IsA("Vector3Value") then

        local ok, value = pcall(function()
            return obj.Value
        end)

        if ok then
            print("Value:", value)
        end
    end

    printAttributes(obj)
end

local character = getCharacter()

local folder =
    character:FindFirstChild("EmoteAnimations")
    or character:WaitForChild("EmoteAnimations", 10)

if not folder then
    warn("[Xero] No encontré Character.EmoteAnimations")
    return
end

print("")
print("================================================")
print("       XERO | EMOTE ANIMATIONS SCANNER")
print("================================================")
print("CARPETA:")
print(getPath(folder))
print("")

-- Inspeccionar la propia carpeta
inspect(folder)

-- Todo lo que ya existe
local descendants = folder:GetDescendants()

print("")
print("OBJETOS ENCONTRADOS:", #descendants)
print("")

for _, obj in ipairs(descendants) do
    inspect(obj)
end

-- Vigilar cosas nuevas
folder.DescendantAdded:Connect(function(obj)
    task.wait()

    print("")
    print("++++++++++++ NUEVO OBJETO ++++++++++++")
    inspect(obj)
end)

folder.DescendantRemoving:Connect(function(obj)
    print("")
    print("------------ ELIMINADO ---------------")
    print("Nombre:", obj.Name)
    print("Clase:", obj.ClassName)
    print("Ruta anterior:", getPath(obj))
end)

print("")
print("ESCÁNER ACTIVO.")
print("Ahora abre el menú EMOTES, ciérralo,")
print("haz tu emote y vuelve a detenerlo.")
print("Mira si aparecen nuevos objetos.")
