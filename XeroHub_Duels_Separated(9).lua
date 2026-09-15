-- Xero | DUELS EmoteAnimations Watcher
-- Kev

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer

local watchedFolders = {}
local watchedObjects = {}

local function path(obj)
    local ok, result = pcall(function()
        return obj:GetFullName()
    end)

    return ok and result or tostring(obj)
end

local function printAttributes(obj)
    local attrs = obj:GetAttributes()

    for key, value in pairs(attrs) do
        print("   [ATTR]", key, "=", value)
    end
end

local function inspect(obj, prefix)
    if watchedObjects[obj] then
        return
    end

    watchedObjects[obj] = true

    print("")
    print("==============================================")
    print(prefix or "[OBJETO]")
    print("Nombre:", obj.Name)
    print("Clase:", obj.ClassName)
    print("Ruta:", path(obj))

    if obj:IsA("Animation") then
        print("AnimationId:", obj.AnimationId)

    elseif obj:IsA("StringValue")
        or obj:IsA("IntValue")
        or obj:IsA("NumberValue")
        or obj:IsA("BoolValue") then

        print("Value:", obj.Value)
    end

    printAttributes(obj)
end

local function watchEmoteFolder(folder)
    if watchedFolders[folder] then
        return
    end

    watchedFolders[folder] = true

    print("")
    print("##############################################")
    print("EMOTE FOLDER ENCONTRADO")
    print("Ruta:", path(folder))
    print("##############################################")

    printAttributes(folder)

    local descendants = folder:GetDescendants()

    print("")
    print("Objetos actualmente dentro:", #descendants)

    for _, obj in ipairs(descendants) do
        inspect(obj, "[YA EXISTÍA]")
    end

    folder.DescendantAdded:Connect(function(obj)
        task.wait()

        inspect(obj, "[NUEVO OBJETO]")
    end)

    folder.DescendantRemoving:Connect(function(obj)
        print("")
        print("[ELIMINADO]")
        print("Nombre:", obj.Name)
        print("Clase:", obj.ClassName)
    end)
end

local function check(obj)
    if obj.Name == "EmoteAnimations" then

        -- Preferentemente sólo el árbol de nuestro jugador.
        local character = player.Character
        local workspaceCharacter = Workspace:FindFirstChild(player.Name)

        if (character and obj:IsDescendantOf(character))
            or (workspaceCharacter and obj:IsDescendantOf(workspaceCharacter)) then

            watchEmoteFolder(obj)
        end
    end
end

-- Por si ya existe cuando ejecutamos el scanner.
for _, obj in ipairs(Workspace:GetDescendants()) do
    check(obj)
end

-- Detectar si DUELS la crea DESPUÉS.
Workspace.DescendantAdded:Connect(function(obj)
    check(obj)
end)

player.CharacterAdded:Connect(function()
    print("")
    print("[Xero] Nuevo Character detectado.")
    print("[Xero] Esperando EmoteAnimations...")
end)

print("==============================================")
print("XERO | EMOTE WATCHER")
print("==============================================")
print("Esperando que DUELS cree EmoteAnimations...")
print("")
print("AHORA HAZ TU EMOTE.")
