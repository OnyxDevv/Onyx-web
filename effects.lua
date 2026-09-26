-- XeroHub | DUELS HUD Team Detector
-- Kev
-- Ejecutar DURANTE una ronda

local Players = game:GetService("Players")
local LP = Players.LocalPlayer
local PlayerGui = LP:WaitForChild("PlayerGui")

local lines = {}

local function log(...)
    local args = {...}

    for i = 1, #args do
        args[i] = tostring(args[i])
    end

    local msg = table.concat(args, " ")
    print(msg)
    lines[#lines + 1] = msg
end

local function lower(v)
    return string.lower(tostring(v or ""))
end

local function contains(haystack, needle)
    haystack = lower(haystack)
    needle = lower(needle)

    return needle ~= ""
        and string.find(haystack, needle, 1, true) ~= nil
end

-- Busca TODOS los KillsHUD porque DUELS a veces los mete
-- dentro de estructuras raras del PlayerGui.
local huds = {}

for _, obj in ipairs(PlayerGui:GetDescendants()) do
    if obj.Name == "KillsHUD" then
        huds[#huds + 1] = obj
    end
end

log("")
log("==========================================")
log(" XERO | DUELS HUD TEAM DETECTOR")
log("==========================================")
log("KillsHUD encontrados:", #huds)

if #huds == 0 then
    log("ERROR: No encontré KillsHUD.")
    return
end

local function findNamedDescendant(root, wanted)
    for _, obj in ipairs(root:GetDescendants()) do
        if obj.Name == wanted then
            return obj
        end
    end
end

local function scorePlayerInside(root, plr)
    if not root then
        return 0, {}
    end

    local score = 0
    local evidence = {}

    local name = tostring(plr.Name)
    local display = tostring(plr.DisplayName)
    local userId = tostring(plr.UserId)

    local function add(points, reason)
        score += points
        evidence[#evidence + 1] =
            "+" .. tostring(points) .. " " .. reason
    end

    for _, obj in ipairs(root:GetDescendants()) do
        -- Nombre del Instance
        if obj.Name == name then
            add(15, "Instance.Name = username → " .. obj:GetFullName())

        elseif obj.Name == userId then
            add(15, "Instance.Name = UserId → " .. obj:GetFullName())
        end

        -- Attributes
        for attrName, attrValue in pairs(obj:GetAttributes()) do
            local value = tostring(attrValue)

            if value == name then
                add(18,
                    "Attribute " .. attrName ..
                    " = username → " .. obj:GetFullName())

            elseif value == userId then
                add(20,
                    "Attribute " .. attrName ..
                    " = UserId → " .. obj:GetFullName())

            elseif display ~= name and value == display then
                add(10,
                    "Attribute " .. attrName ..
                    " = DisplayName → " .. obj:GetFullName())
            end
        end

        -- ObjectValue directo al Player
        if obj:IsA("ObjectValue") then
            local ok, value = pcall(function()
                return obj.Value
            end)

            if ok and value == plr then
                add(30, "ObjectValue → Player → " .. obj:GetFullName())
            end
        end

        -- Values
        if obj:IsA("StringValue") then
            local value = tostring(obj.Value)

            if value == name then
                add(20, "StringValue=username → " .. obj:GetFullName())

            elseif value == userId then
                add(20, "StringValue=UserId → " .. obj:GetFullName())

            elseif display ~= name and value == display then
                add(12, "StringValue=DisplayName → " .. obj:GetFullName())
            end

        elseif obj:IsA("IntValue") or obj:IsA("NumberValue") then
            if tonumber(obj.Value) == plr.UserId then
                add(25, "NumberValue=UserId → " .. obj:GetFullName())
            end
        end

        -- Textos
        if obj:IsA("TextLabel")
            or obj:IsA("TextButton")
            or obj:IsA("TextBox") then

            local text = tostring(obj.Text or "")

            if contains(text, name) then
                add(12,
                    "Text contiene username → " ..
                    obj:GetFullName() ..
                    " [" .. text .. "]")

            elseif display ~= name and contains(text, display) then
                add(8,
                    "Text contiene DisplayName → " ..
                    obj:GetFullName() ..
                    " [" .. text .. "]")
            end
        end

        -- Thumbnails
        if obj:IsA("ImageLabel") or obj:IsA("ImageButton") then
            local image = tostring(obj.Image or "")

            if contains(image, userId) then
                add(25,
                    "Imagen contiene UserId → " ..
                    obj:GetFullName() ..
                    " [" .. image .. "]")
            end
        end
    end

    return score, evidence
end

local bestHUD

for _, hud in ipairs(huds) do
    local left = findNamedDescendant(hud, "LeftContainer")
    local right = findNamedDescendant(hud, "RightContainer")

    if left and right then
        bestHUD = hud
        break
    end
end

if not bestHUD then
    log("")
    log("ERROR: Encontré KillsHUD pero no LeftContainer/RightContainer.")

    for _, hud in ipairs(huds) do
        log("HUD:", hud:GetFullName())
    end

    return
end

local left = findNamedDescendant(bestHUD, "LeftContainer")
local right = findNamedDescendant(bestHUD, "RightContainer")

log("")
log("HUD USADO:")
log(bestHUD:GetFullName())

log("")
log("LEFT:")
log(left:GetFullName())

log("")
log("RIGHT:")
log(right:GetFullName())

local detectedSides = {}

log("")
log("============== RESULTADOS ==============")

for _, plr in ipairs(Players:GetPlayers()) do
    local leftScore, leftEvidence =
        scorePlayerInside(left, plr)

    local rightScore, rightEvidence =
        scorePlayerInside(right, plr)

    local side = "UNKNOWN"

    if leftScore > rightScore and leftScore > 0 then
        side = "LEFT"

    elseif rightScore > leftScore and rightScore > 0 then
        side = "RIGHT"

    elseif leftScore > 0 and rightScore > 0 then
        side = "AMBIGUO"
    end

    detectedSides[plr] = side

    log("")
    log("------------------------------------------")
    log(
        plr == LP and "*** LOCALPLAYER ***" or "PLAYER",
        plr.Name
    )

    log(
        "Display:",
        plr.DisplayName,
        "| UserId:",
        plr.UserId
    )

    log(
        "LEFT SCORE:",
        leftScore,
        "| RIGHT SCORE:",
        rightScore
    )

    log("SIDE:", side)

    if #leftEvidence > 0 then
        log("LEFT EVIDENCE:")

        for i = 1, math.min(#leftEvidence, 5) do
            log(" ", leftEvidence[i])
        end
    end

    if #rightEvidence > 0 then
        log("RIGHT EVIDENCE:")

        for i = 1, math.min(#rightEvidence, 5) do
            log(" ", rightEvidence[i])
        end
    end
end

local mySide = detectedSides[LP]

log("")
log("==========================================")
log("TU LADO DETECTADO:", mySide)
log("==========================================")

if mySide == "LEFT" or mySide == "RIGHT" then
    log("")
    log("CLASIFICACIÓN:")

    for plr, side in pairs(detectedSides) do
        if plr ~= LP then
            if side == mySide then
                log(
                    "ALIADO:",
                    plr.Name,
                    "(" .. side .. ")"
                )

            elseif side == "LEFT" or side == "RIGHT" then
                log(
                    "ENEMIGO:",
                    plr.Name,
                    "(" .. side .. ")"
                )

            else
                log(
                    "SIN RESOLVER:",
                    plr.Name,
                    "(" .. side .. ")"
                )
            end
        end
    end
end

local result = table.concat(lines, "\n")

if setclipboard then
    pcall(setclipboard, result)
    print("[Xero] Resultado copiado.")
end
