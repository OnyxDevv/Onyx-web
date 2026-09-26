-- XeroHub | DUELS Team HUD Finder
-- Kev test pruebas
-- Ejecutar durante una ronda

local Players = game:GetService("Players")
local LP = Players.LocalPlayer
local PlayerGui = LP:WaitForChild("PlayerGui")

local output = {}

local function log(...)
    local args = {...}
    for i = 1, #args do
        args[i] = tostring(args[i])
    end

    local msg = table.concat(args, " ")
    print(msg)
    output[#output + 1] = msg
end

log("===== XERO TEAM HUD FINDER =====")

local found = 0

for _, obj in ipairs(PlayerGui:GetDescendants()) do
    if obj:IsA("GuiObject") or obj:IsA("Folder") then
        local left = obj:FindFirstChild("LeftContainer", true)
        local right = obj:FindFirstChild("RightContainer", true)

        if left and right then
            found += 1

            log("")
            log("CANDIDATO #" .. found)
            log("ROOT:", obj:GetFullName())
            log("LEFT:", left:GetFullName())
            log("RIGHT:", right:GetFullName())
        end
    end
end

log("")
log("TOTAL:", found)

log("")
log("===== NOMBRES SOSPECHOSOS =====")

for _, obj in ipairs(PlayerGui:GetDescendants()) do
    local n = string.lower(obj.Name)

    if string.find(n, "kill", 1, true)
        or string.find(n, "player", 1, true)
        or string.find(n, "team", 1, true)
        or string.find(n, "hud", 1, true) then

        if obj:IsA("Frame")
            or obj:IsA("Folder")
            or obj:IsA("ScreenGui") then

            log(obj.ClassName, obj:GetFullName())
        end
    end
end

local result = table.concat(output, "\n")

if setclipboard then
    pcall(setclipboard, result)
    print("[Xero] Resultado copiado al portapapeles.")
end
