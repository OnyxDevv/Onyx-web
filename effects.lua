-- XeroHub | DUELS Character Team Signature Detector
-- Kev
-- Ejecutar DURANTE una ronda 4v4
-- Sirve para descubrir qué señal interna distingue aliados/enemigos cuando Player.Team no sirve.

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

local LP = Players.LocalPlayer
local output = {}

local function log(...)
    local args = {...}
    for i = 1, #args do
        args[i] = tostring(args[i])
    end
    local s = table.concat(args, " ")
    print(s)
    output[#output + 1] = s
end

local function lower(v)
    return string.lower(tostring(v or ""))
end

local interestingWords = {
    "team", "blue", "red", "ally", "allied", "enemy",
    "side", "squad", "party", "group", "faction", "match",
    "duel", "round", "role"
}

local function interestingName(name)
    local n = lower(name)
    for _, word in ipairs(interestingWords) do
        if string.find(n, word, 1, true) then
            return true
        end
    end
    return false
end

local function attrsToText(obj)
    if not obj then return {} end
    local rows = {}
    for k, v in pairs(obj:GetAttributes()) do
        rows[#rows + 1] = tostring(k) .. "=" .. tostring(v)
    end
    table.sort(rows)
    return rows
end

local function tagsToText(obj)
    if not obj then return {} end
    local ok, tags = pcall(CollectionService.GetTags, CollectionService, obj)
    if not ok or type(tags) ~= "table" then
        return {}
    end
    table.sort(tags)
    return tags
end

local function collisionSignature(char)
    local counts = {}
    if not char then return counts end

    for _, obj in ipairs(char:GetDescendants()) do
        if obj:IsA("BasePart") then
            local group = "?"
            pcall(function()
                group = obj.CollisionGroup
            end)
            counts[group] = (counts[group] or 0) + 1
        end
    end

    return counts
end

local function mapToSortedText(map)
    local rows = {}
    for k, v in pairs(map) do
        rows[#rows + 1] = tostring(k) .. "=" .. tostring(v)
    end
    table.sort(rows)
    return rows
end

local function colorText(c)
    if typeof(c) ~= "Color3" then return tostring(c) end
    return string.format(
        "%.3f,%.3f,%.3f",
        c.R, c.G, c.B
    )
end

local function dumpInterestingDescendants(root, prefix)
    if not root then return end

    for _, obj in ipairs(root:GetDescendants()) do
        local printed = false

        if interestingName(obj.Name) then
            log(prefix, "INTERESTING OBJ:", obj.ClassName, obj:GetFullName())
            printed = true
        end

        if obj:IsA("StringValue") or obj:IsA("IntValue")
            or obj:IsA("NumberValue") or obj:IsA("BoolValue")
            or obj:IsA("ObjectValue") then

            if interestingName(obj.Name) then
                local valueText = "?"
                pcall(function()
                    if obj:IsA("ObjectValue") then
                        valueText = obj.Value and obj.Value:GetFullName() or "nil"
                    else
                        valueText = tostring(obj.Value)
                    end
                end)
                log(prefix, "  VALUE:", obj.Name, "=", valueText)
            end
        end

        if obj:IsA("Highlight") then
            log(
                prefix,
                "HIGHLIGHT:",
                obj:GetFullName(),
                "| Fill:", colorText(obj.FillColor),
                "| Outline:", colorText(obj.OutlineColor),
                "| Enabled:", tostring(obj.Enabled)
            )
            printed = true
        elseif obj:IsA("BillboardGui") then
            log(
                prefix,
                "BILLBOARD:",
                obj:GetFullName(),
                "| Enabled:", tostring(obj.Enabled)
            )
            printed = true
        elseif obj:IsA("SelectionBox") then
            log(
                prefix,
                "SELECTIONBOX:",
                obj:GetFullName(),
                "| Color:", colorText(obj.Color3)
            )
            printed = true
        end

        local attrs = attrsToText(obj)
        if #attrs > 0 then
            local hasInterestingAttr = false
            for _, row in ipairs(attrs) do
                local attrName = row:match("^([^=]+)=") or ""
                if interestingName(attrName) then
                    hasInterestingAttr = true
                    break
                end
            end

            if hasInterestingAttr then
                if not printed then
                    log(prefix, "OBJ ATTR:", obj.ClassName, obj:GetFullName())
                end
                for _, row in ipairs(attrs) do
                    log(prefix, "  ATTR:", row)
                end
            end
        end

        local tags = tagsToText(obj)
        if #tags > 0 then
            if not printed then
                log(prefix, "OBJ TAGS:", obj.ClassName, obj:GetFullName())
            end
            log(prefix, "  TAGS:", table.concat(tags, ", "))
        end
    end
end

local function safePartInfo(part)
    if not part or not part:IsA("BasePart") then
        return "nil"
    end

    local group = "?"
    pcall(function()
        group = part.CollisionGroup
    end)

    return table.concat({
        "Name=" .. part.Name,
        "CollisionGroup=" .. tostring(group),
        "CanCollide=" .. tostring(part.CanCollide),
        "CanTouch=" .. tostring(part.CanTouch),
        "CanQuery=" .. tostring(part.CanQuery),
        "Color=" .. colorText(part.Color),
    }, " | ")
end

local signatures = {}

for _, plr in ipairs(Players:GetPlayers()) do
    local char = plr.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local hrp = char and char:FindFirstChild("HumanoidRootPart")

    log("")
    log("==================================================")
    log(plr == LP and "*** LOCALPLAYER ***" or "PLAYER", plr.Name)
    log("DisplayName:", plr.DisplayName)
    log("UserId:", plr.UserId)
    log("Player.Team:", plr.Team and plr.Team.Name or "nil")
    log("Player.TeamColor:", plr.TeamColor.Name)
    log("Player.Neutral:", tostring(plr.Neutral))

    local pAttrs = attrsToText(plr)
    local pTags = tagsToText(plr)

    log("PLAYER ATTRS:", #pAttrs > 0 and table.concat(pAttrs, " | ") or "none")
    log("PLAYER TAGS:", #pTags > 0 and table.concat(pTags, ", ") or "none")

    if not char then
        log("CHARACTER: nil")
    else
        log("CHARACTER:", char:GetFullName())

        local cAttrs = attrsToText(char)
        local cTags = tagsToText(char)

        log("CHAR ATTRS:", #cAttrs > 0 and table.concat(cAttrs, " | ") or "none")
        log("CHAR TAGS:", #cTags > 0 and table.concat(cTags, ", ") or "none")

        if hum then
            local hAttrs = attrsToText(hum)
            local hTags = tagsToText(hum)
            log("HUMANOID ATTRS:", #hAttrs > 0 and table.concat(hAttrs, " | ") or "none")
            log("HUMANOID TAGS:", #hTags > 0 and table.concat(hTags, ", ") or "none")
        end

        log("HRP:", safePartInfo(hrp))

        local head = char:FindFirstChild("Head")
        if head and head:IsA("BasePart") then
            log("HEAD:", safePartInfo(head))
        end

        local torso = char:FindFirstChild("UpperTorso")
            or char:FindFirstChild("Torso")

        if torso and torso:IsA("BasePart") then
            log("TORSO:", safePartInfo(torso))
        end

        local collision = collisionSignature(char)
        local collisionRows = mapToSortedText(collision)
        log(
            "COLLISION SIGNATURE:",
            #collisionRows > 0 and table.concat(collisionRows, " | ") or "none"
        )

        signatures[plr] = table.concat(collisionRows, ";")

        dumpInterestingDescendants(char, "  ")
    end
end

log("")
log("==================================================")
log(" COMPARACIÓN CONTRA LOCALPLAYER")
log("==================================================")

local mySig = signatures[LP]

for plr, sig in pairs(signatures) do
    if plr ~= LP then
        log(
            plr.Name,
            "| CollisionSignature igual a la tuya:",
            tostring(sig == mySig),
            "|",
            sig
        )
    end
end

log("")
log("NOTA: ya sabemos que SxAlxss era ENEMIGO en la prueba anterior.")
log("Busca si su firma/tags/attrs difieren de la tuya y si tus aliados comparten la tuya.")

local final = table.concat(output, "\n")

if setclipboard then
    pcall(setclipboard, final)
    print("[Xero] Resultado copiado al portapapeles.")
end
