-- XeroHub | Team Detector Debug
-- Ejecutar DURANTE una ronda 4v4

local Players = game:GetService("Players")
local Teams = game:GetService("Teams")

local LP = Players.LocalPlayer
local PlayerGui = LP:WaitForChild("PlayerGui")

local output = {}

local function log(...)
    local args = {...}
    for i = 1, #args do
        args[i] = tostring(args[i])
    end

    local text = table.concat(args, " ")
    print(text)
    output[#output + 1] = text
end

local function safeTeamName(p)
    if not p.Team then
        return "nil"
    end

    return p.Team.Name
end

local function interestingAttributeDump(obj)
    if not obj then
        return "nil"
    end

    local result = {}

    for name, value in pairs(obj:GetAttributes()) do
        local lower = string.lower(name)

        if string.find(lower, "team", 1, true)
            or string.find(lower, "squad", 1, true)
            or string.find(lower, "side", 1, true)
            or string.find(lower, "group", 1, true)
            or string.find(lower, "faction", 1, true)
            or string.find(lower, "party", 1, true) then

            result[#result + 1] =
                tostring(name) .. "=" .. tostring(value)
        end
    end

    if #result == 0 then
        return "ninguno"
    end

    return table.concat(result, ", ")
end

local function findInterestingValues(root)
    if not root then
        return {}
    end

    local result = {}

    for _, obj in ipairs(root:GetDescendants()) do
        if obj:IsA("ValueBase") then
            local lower = string.lower(obj.Name)

            if string.find(lower, "team", 1, true)
                or string.find(lower, "squad", 1, true)
                or string.find(lower, "side", 1, true)
                or string.find(lower, "group", 1, true)
                or string.find(lower, "faction", 1, true)
                or string.find(lower, "party", 1, true) then

                local ok, value = pcall(function()
                    return obj.Value
                end)

                if ok then
                    result[#result + 1] =
                        obj:GetFullName() .. " = " .. tostring(value)
                end
            end
        end
    end

    return result
end

local function findPlayerInGui(p)
    local matches = {}

    local targets = {
        string.lower(p.Name),
        string.lower(p.DisplayName)
    }

    for _, obj in ipairs(PlayerGui:GetDescendants()) do
        if obj:IsA("TextLabel")
            or obj:IsA("TextButton")
            or obj:IsA("TextBox") then

            local text = string.lower(tostring(obj.Text or ""))

            for _, target in ipairs(targets) do
                if target ~= ""
                    and string.find(text, target, 1, true) then

                    matches[#matches + 1] = obj:GetFullName()
                    break
                end
            end
        end
    end

    return matches
end

log("")
log("==========================================")
log("       XEROHUB TEAM DETECTOR")
log("==========================================")
log("LocalPlayer:", LP.Name)
log("")

log("======= TEAMS SERVICE =======")

for _, team in ipairs(Teams:GetChildren()) do
    if team:IsA("Team") then
        log(
            "TEAM:",
            team.Name,
            "| Color:",
            team.TeamColor.Name
        )
    end
end

log("")
log("======= PLAYERS =======")

for _, p in ipairs(Players:GetPlayers()) do
    log("")
    log("------------------------------------------")
    log("PLAYER:", p.Name)
    log("DisplayName:", p.DisplayName)

    if p == LP then
        log("*** ESTE ERES TÚ ***")
    end

    log("Team:", safeTeamName(p))
    log("TeamColor:", p.TeamColor.Name)
    log("Neutral:", tostring(p.Neutral))

    log(
        "Player Attributes:",
        interestingAttributeDump(p)
    )

    if p.Character then
        log(
            "Character Attributes:",
            interestingAttributeDump(p.Character)
        )
    else
        log("Character Attributes: SIN CHARACTER")
    end

    local playerValues = findInterestingValues(p)

    for _, value in ipairs(playerValues) do
        log("Player Value:", value)
    end

    if p.Character then
        local characterValues = findInterestingValues(p.Character)

        for _, value in ipairs(characterValues) do
            log("Character Value:", value)
        end
    end

    local guiMatches = findPlayerInGui(p)

    if #guiMatches > 0 then
        log("GUI ENTRIES:")

        for i = 1, math.min(#guiMatches, 8) do
            log("  ", guiMatches[i])
        end
    else
        log("GUI ENTRIES: ninguno")
    end
end

log("")
log("==========================================")
log("FIN TEAM DETECTOR")
log("==========================================")

local finalText = table.concat(output, "\n")

if setclipboard then
    pcall(setclipboard, finalText)
    log("✓ Resultado copiado al portapapeles.")
else
    log("Tu ejecutor no tiene setclipboard.")
end
