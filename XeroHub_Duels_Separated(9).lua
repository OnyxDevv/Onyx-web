-- XeroHub | DUELS MURDERS VS SHERIFF | Kev --


local MM2_PLACE_ID = 142823291
local MMV_PLACE_ID = 74369636333825
local MMV2_PLACE_ID = 74369636333825
local DUELS_BIMO_PLACE_ID = 116817810725116

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local workspace = game:GetService("Workspace")

-- Estilo iOS: radios consistentes para ventana, controles y overlays.
local IOS_STYLE = {
    WindowRadius = 20,
    ElementRadius = 14,
    OverlayRadius = 14,
    OpenButtonRadius = 16,
}

task_wait = task.wait
task_spawn = task.spawn
task_delay = task.delay
math_floor = math.floor
math_rad = math.rad
string_lower = string.lower
string_find = string.find
table_insert = table.insert
table_sort = table.sort
Vector3_new = Vector3.new
Vector2_new = Vector2.new
CFrame_new = CFrame.new
Color3_fromRGB = Color3.fromRGB
getnamecallmethod = getnamecallmethod
checkcaller = checkcaller
typeof = typeof

-- 🔥 RUTAS DIRECTAS DE MEMORIA BLINDADAS
local function ws_Raycast(ws, origin, dir, params) return ws:Raycast(origin, dir, params) end
local Filter_Exclude = Enum.RaycastFilterType.Exclude

-- NUEVO CACHÉ PARA EVITAR LAG DE MOONVEIL
local function ffc(obj, name) return obj and obj:FindFirstChild(name) end
local function ffcClass(obj, className) return obj and obj:FindFirstChildOfClass(className) end
local getPlayers = Players.GetPlayers
local getChildren = Players.GetChildren
-- ==========================================
-- FILTRO DE ZONAS SEGURAS (Lobby, Votación, etc.)
-- ==========================================
local ZONAS_SEGURAS = {
    {Centro = Vector3.new(-320.50, 280.82, 16.00), Radio = 500}, -- Lobby principal
    {Centro = Vector3.new(1564.14, -155.45, 40.04), Radio = 300}  -- Zona de votación de mapa
}

local player = Players.LocalPlayer
while not player do
    task.wait()
    player = Players.LocalPlayer
end

local camera = workspace.CurrentCamera
local mouse = player:GetMouse()

-- Ciclo de vida único: evita que una reejecución deje Heartbeats, RenderStepped
-- u objetos Drawing de la sesión anterior consumiendo CPU en segundo plano.
local runtimeEnv = (getgenv and getgenv()) or _G
local previousRuntime = runtimeEnv.__ILUNX_RUNTIME
if previousRuntime and previousRuntime.Cleanup then
    pcall(previousRuntime.Cleanup)
end

local runtime = {
    Alive = true,
    Connections = {},
    Drawings = {},
    InfectedTexts = {},
}

function runtime.Track(connection)
    if connection then table.insert(runtime.Connections, connection) end
    return connection
end

function runtime.TrackDrawing(drawing)
    if drawing then table.insert(runtime.Drawings, drawing) end
    return drawing
end

function runtime.TrackInfectedText(textObject)
    if textObject then runtime.InfectedTexts[textObject] = true end
    return textObject
end

function runtime.Cleanup()
    if not runtime.Alive then return end
    runtime.Alive = false

    for i = #runtime.Connections, 1, -1 do
        local connection = runtime.Connections[i]
        pcall(function() connection:Disconnect() end)
        runtime.Connections[i] = nil
    end

    for i = #runtime.Drawings, 1, -1 do
        local drawing = runtime.Drawings[i]
        pcall(function() drawing:Remove() end)
        runtime.Drawings[i] = nil
    end

    for textObject in pairs(runtime.InfectedTexts) do
        pcall(function() textObject:SetAttribute("AstraInfectado", nil) end)
        runtime.InfectedTexts[textObject] = nil
    end

    if runtime.AimState and runtime.AimState.Owner == runtime then
        runtime.AimState.Target = nil
        runtime.AimState.Owner = nil
    end

    if runtime.GhostCleanup then
        pcall(runtime.GhostCleanup)
    end

    if runtime.AvatarThumbnailSpoofCleanup then
        pcall(runtime.AvatarThumbnailSpoofCleanup)
    end

    if runtime.AppearanceCleanup then
        pcall(runtime.AppearanceCleanup)
    end

    if runtime.BodySelectorGui then
        pcall(function() runtime.BodySelectorGui:Destroy() end)
        runtime.BodySelectorGui = nil
    end

    if runtime.AppearanceStudioGui then
        if runtime.AppearanceStudio and runtime.AppearanceStudio.BaseAvatarTemplate then
            pcall(function() runtime.AppearanceStudio.BaseAvatarTemplate:Destroy() end)
        end
        pcall(function() runtime.AppearanceStudioGui:Destroy() end)
        runtime.AppearanceStudioGui = nil
        runtime.AppearanceStudio = nil
    end

    if runtime.StartupGui then
        pcall(function() runtime.StartupGui:Destroy() end)
        runtime.StartupGui = nil
    end

    if runtime.NotificationGui then
        pcall(function() runtime.NotificationGui:Destroy() end)
        runtime.NotificationGui = nil
    end

    if runtime.ScreenGui then
        pcall(function() runtime.ScreenGui:Destroy() end)
        runtime.ScreenGui = nil
    end
end

runtimeEnv.__ILUNX_RUNTIME = runtime

function AstraRequest(ruta)
    local req = (syn and syn.request) or (http and http.request) or http_request or request
    if req then
        local success, response = pcall(function()
            return req({
                Url = "https://hub.onyx-scripts.com" .. ruta,
                Method = "GET",
                Headers = {
                    ["Astra-Auth"] = "OnyxHub!", 
                    ["User-Agent"] = "Roblox/iLunXHub"
                }
            })
        end)
        if success and response then return response.Body end
    end
    return nil
end

task.spawn(function()
    local banStatus = AstraRequest("/check_ban")
    if banStatus == "BANNED" then
        player:Kick("\nXeroHub SECURITY\nTu red (IP) está baneada permanentemente del Hub por intento de robo o violación de reglas.\n\n.")
    end
end)



-- ==========================================
--  VARIABLES GLOBALES DE CONFIGURACIÓN 
-- ==========================================
_G.AstraBotonesOcultos = false
fovVisiblePreference = false
fovRadius = 120
fovFollowsCursor = false
activeTouches = {}
extraFovCircles = {}
aimbotEnabled = false
autoShootEnabled = false
fullAimbotEnabled = false
hitboxEnabled = false
hitboxInvisible = false 
hitboxTransparency = 0.6
hitboxSize = 10
hitboxColor = Color3.fromRGB(255, 255, 255)
teamCheckEnabled = true
espEnabled = false
espColor = Color3.fromRGB(255, 255, 255)
espSettings = { Glow = true, Name = true, Distance = true, Box = false, HealthBar = false }
espLinesEnabled = false
gunKillEnabled = false
knifeKillEnabled = false
flying = false
flySpeed = 50
emoteWalkEnabled = false 
currentEmoteTrack = nil
allEmotes = {}
filteredEmotes = {}
currentPage = 1
emotesPerPage = 12
hideNameEnabled = false
fakeNameEnabled = false
rainbowEnabled = false
creatorTagEnabled = false 
spoofNameText = "Nombre falso"
aimbotTargetPart = "Cabeza"

local UIElements = {} -- Tabla para guardar referencias

local playerGui = player:WaitForChild("PlayerGui")
local previousOverlay = playerGui:FindFirstChild("XeroHub_Overlays") or playerGui:FindFirstChild("iLunXHub_Overlays")
if previousOverlay then
    previousOverlay:Destroy()
end

-- ==========================================
-- ÚNICA ANIMACIÓN: SPLASH REAL AL EJECUTAR
-- ==========================================
local startupSplashState = {}

do
    -- Splash: negro real, nítido y cubriendo todo el viewport.
    local splashParent = playerGui
    pcall(function()
        if gethui then splashParent = gethui() else splashParent = game:GetService("CoreGui") end
    end)

    local previousSplash = splashParent and (splashParent:FindFirstChild("XeroHub_Startup") or splashParent:FindFirstChild("iLunXHub_Startup"))
    if previousSplash then previousSplash:Destroy() end

    local startupGui = Instance.new("ScreenGui")
    startupGui.Name = "XeroHub_Startup"
    startupGui.ResetOnSpawn = false
    startupGui.IgnoreGuiInset = true
    startupGui.DisplayOrder = 2147483647
    startupGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    pcall(function() startupGui.ScreenInsets = Enum.ScreenInsets.None end)
    pcall(function() startupGui.ClipToDeviceSafeArea = false end)

    pcall(function()
        if syn and syn.protect_gui then syn.protect_gui(startupGui) end
    end)

    local parented = pcall(function() startupGui.Parent = splashParent end)
    if not parented then startupGui.Parent = playerGui end
    runtime.StartupGui = startupGui

    local splash = Instance.new("CanvasGroup")
    splash.Name = "Splash"
    splash.Size = UDim2.fromScale(1, 1)
    splash.Position = UDim2.fromScale(0, 0)
    splash.BackgroundColor3 = Color3.new(0, 0, 0)
    splash.BackgroundTransparency = 0
    splash.BorderSizePixel = 0
    splash.GroupTransparency = 0
    splash.Active = true
    splash.ZIndex = 1
    splash.Parent = startupGui

    local content = Instance.new("Frame")
    content.Name = "LoaderContent"
    content.AnchorPoint = Vector2.new(0.5, 0.5)
    content.Position = UDim2.fromScale(0.5, 0.5)
    content.Size = UDim2.fromOffset(460, 128)
    content.BackgroundTransparency = 1
    content.ZIndex = 2
    content.Parent = splash

    local contentScale = Instance.new("UIScale")
    contentScale.Scale = 1
    contentScale.Parent = content

    local brand = Instance.new("TextLabel")
    brand.AnchorPoint = Vector2.new(0.5, 0)
    brand.Size = UDim2.new(1, 0, 0, 46)
    brand.Position = UDim2.new(0.5, 0, 0, 10)
    brand.BackgroundTransparency = 1
    brand.RichText = true
    brand.Text = '<font color="#FFFFFF">XERO</font><font color="#A7A7A7"> HUB</font>'
    brand.TextColor3 = Color3.new(1, 1, 1)
    brand.TextTransparency = 0
    brand.Font = Enum.Font.GothamBold
    brand.TextSize = 32
    brand.TextXAlignment = Enum.TextXAlignment.Center
    brand.ZIndex = 3
    brand.Parent = content

    local status = Instance.new("TextLabel")
    status.AnchorPoint = Vector2.new(0.5, 0)
    status.Size = UDim2.new(1, -48, 0, 22)
    status.Position = UDim2.new(0.5, 0, 0, 62)
    status.BackgroundTransparency = 1
    status.Text = "Cargando XeroHub..."
    status.TextColor3 = Color3.fromHex("#9B9B9B")
    status.Font = Enum.Font.GothamMedium
    status.TextSize = 13
    status.TextXAlignment = Enum.TextXAlignment.Center
    status.ZIndex = 3
    status.Parent = content

    local progressTrack = Instance.new("Frame")
    progressTrack.AnchorPoint = Vector2.new(0.5, 0)
    progressTrack.Size = UDim2.fromOffset(230, 2)
    progressTrack.Position = UDim2.new(0.5, 0, 0, 98)
    progressTrack.BackgroundColor3 = Color3.fromHex("#242424")
    progressTrack.BorderSizePixel = 0
    progressTrack.ZIndex = 3
    progressTrack.Parent = content
    Instance.new("UICorner", progressTrack).CornerRadius = UDim.new(1, 0)

    local progress = Instance.new("Frame")
    progress.Size = UDim2.fromScale(0.04, 1)
    progress.BackgroundColor3 = Color3.fromHex("#E7E7E7")
    progress.BorderSizePixel = 0
    progress.ZIndex = 4
    progress.Parent = progressTrack
    Instance.new("UICorner", progress).CornerRadius = UDim.new(1, 0)

    startupSplashState.Gui = startupGui
    startupSplashState.Group = splash
    startupSplashState.Card = content
    startupSplashState.Status = status

    startupSplashState.Progress = progress
end

function startupSplashState.Finish(message)
    local startupGui = startupSplashState.Gui
    if not startupGui or not startupGui.Parent then return end

    -- Sólo los errores conservan un momento de lectura. La carga correcta
    -- termina inmediatamente, sin duración mínima ni esperar animaciones.
    if message and startupSplashState.Status then
        startupSplashState.Status.Text = message
        task.wait(0.65)
    end
    if startupSplashState.Progress then
        startupSplashState.Progress.Size = UDim2.fromScale(1, 1)
    end
    if startupGui.Parent then startupGui:Destroy() end
    runtime.StartupGui = nil
    startupSplashState.Gui = nil
    startupSplashState.Group = nil
    startupSplashState.Card = nil
    startupSplashState.Status = nil
    startupSplashState.Progress = nil
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "XeroHub_Overlays"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true 
screenGui.DisplayOrder = 999 
screenGui.Parent = playerGui
runtime.ScreenGui = screenGui

local espFolder = Instance.new("Folder")
espFolder.Name = "iLunXESPFolder"
espFolder.Parent = screenGui

local activeDrag = nil

-- Una sola conexión global mueve todos los botones arrastrables. Esto evita
-- acumular listeners cada vez que se crea un nuevo botón flotante.
runtime.Track(UserInputService.InputChanged:Connect(function(input)
    local drag = activeDrag
    if not drag or input ~= drag.Input then return end
    if not drag.Object or not drag.Object.Parent then
        activeDrag = nil
        return
    end

    local delta = input.Position - drag.Start
    drag.Object.Position = UDim2.new(
        drag.Position.X.Scale,
        drag.Position.X.Offset + delta.X,
        drag.Position.Y.Scale,
        drag.Position.Y.Offset + delta.Y
    )
end))

local function makeDraggable(guiObject, objectToMove)
    guiObject.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            activeDrag = {
                Source = guiObject,
                Object = objectToMove,
                Input = input.UserInputType == Enum.UserInputType.Touch and input or nil,
                Start = input.Position,
                Position = objectToMove.Position,
            }

            local endedConnection
            endedConnection = input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    if activeDrag and activeDrag.Source == guiObject then
                        activeDrag = nil
                    end
                    if endedConnection then
                        endedConnection:Disconnect()
                        endedConnection = nil
                    end
                end
            end)
        end
    end)

    guiObject.InputChanged:Connect(function(input)
        if activeDrag and activeDrag.Source == guiObject
            and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            activeDrag.Input = input
        end
    end)
end

-- ==========================================
-- NOXHUB / UI SEPARADA
-- La lógica carga XeroHub_UI.lua por archivo local o URL RAW.
-- ==========================================
local WindUI
-- UI separada: puedes ofuscar este archivo sin mezclar las ~1k líneas visuales.
-- Orden de carga: archivo local XeroHub_UI.lua -> URL RAW oficial de XeroHub.
local NOX_UI_URL = ((getgenv and getgenv()) or _G).NOX_UI_URL or "https://raw.githubusercontent.com/OnyxDevv/Onyx-web/refs/heads/main/main%20(3).lua"
local ok, result = pcall(function()
    local source
    if isfile and readfile and isfile("XeroHub_UI.lua") then
        source = readfile("XeroHub_UI.lua")
    elseif NOX_UI_URL ~= "" then
        source = game:HttpGet(NOX_UI_URL)
    else
        error("Falta XeroHub_UI.lua o getgenv().NOX_UI_URL")
    end
    local chunk, compileError = loadstring(source)
    if not chunk then error("No se pudo compilar XeroHub_UI.lua: " .. tostring(compileError)) end
    return chunk()
end)

if ok and result then
    WindUI = result
else
    warn("[XeroHub] No se pudo iniciar la UI: " .. tostring(result))
    startupSplashState.Finish("No se pudo cargar XeroHub")
    runtime.Cleanup()
    return
end

local Window = WindUI:CreateWindow({
    Title = "Xero | DUELS",
    Subtitle = "DUELS",
    Theme = "Xero",
    Author = "by Kev",
    Size = UDim2.fromOffset(620, 350),
    MinSize = Vector2.new(330, 270),
    Resizable = true,
    OpenButton = {Title = "Abrir XeroHub", Enabled = true},
})

-- La UI ya está cargada; el resto del arranque prepara sus controles.
if startupSplashState.Progress then
    startupSplashState.Progress.Size = UDim2.fromScale(0.65, 1)
    startupSplashState.Status.Text = "Preparando controles..."
end

pcall(function()
    Window:OnDestroy(runtime.Cleanup)
end)


-- ==========================================
-- CONTADOR DE USUARIOS ACTIVOS (CACHÉ OPTIMIZADO)
-- ==========================================
task.spawn(function()
    -- Obtenemos la función HTTP compatible con el ejecutor
    local req = (syn and syn.request) or (http and http.request) or http_request or request
    if not req then return end
    
    
    while runtime.Alive do
        local success, response = pcall(function()
            return req({
                Url = "https://hub.onyx-scripts.com/ping?user=" .. tostring(player.Name) .. "&jobid=" .. tostring(game.JobId),
                Method = "GET",
                Headers = {
                    ["Astra-Auth"] = "OnyxHub!", 
                    ["User-Agent"] = "Roblox/iLunXHub"
                }
            })
        end)
        
        if success and response and response.StatusCode == 200 then
            local vivos = tonumber(response.Body)
            if vivos then
                Window:SetTitle("XERO | DUELS · " .. tostring(vivos) .. " activos")
            end
        end
        if runtime.Alive then task.wait(10) end
    end
end)

-- ==========================================
-- NOTIFICACIONES XERO: tarjetas monocromáticas desde la derecha
-- Entra y sale rápido; la cola corta descarta avisos viejos para no atrasarse.
-- ==========================================
local sendNotification
do
local NOTIFICATION_TIMING = {
    Enter = 0.18,
    Hold = 0.68,
    Exit = 0.14,
    Gap = 0.015,
}

local notificationGui = Instance.new("ScreenGui")
notificationGui.Name = "XeroHub_Notifications"
notificationGui.ResetOnSpawn = false
notificationGui.IgnoreGuiInset = true
notificationGui.DisplayOrder = 2147483647
notificationGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
notificationGui.Parent = playerGui
runtime.NotificationGui = notificationGui

local NotifContainer = Instance.new("Frame")
NotifContainer.Name = "XeroNotifications"
NotifContainer.Size = UDim2.fromScale(1, 1)
NotifContainer.BackgroundTransparency = 1
NotifContainer.Active = false
NotifContainer.ZIndex = 200
NotifContainer.Parent = notificationGui

local notificationQueue = {}
local notificationWorkerRunning = false
local lastNotificationText = nil
local lastNotificationAt = 0
runtime.NotificationSerial = 0
runtime.NotificationsReady = false

local function createMinimalBanner(payload)
    local banner = Instance.new("CanvasGroup")
    banner.Name = "XeroToast"
    banner.AnchorPoint = Vector2.new(1, 0)
    banner.Position = UDim2.new(1, 374, 0, 64)
    banner.Size = UDim2.new(1, -24, 0, 82)
    banner.BackgroundColor3 = Color3.fromRGB(13, 13, 13)
    banner.BackgroundTransparency = 0.02
    banner.BorderSizePixel = 0
    banner.ClipsDescendants = true
    banner.GroupTransparency = 1
    banner.ZIndex = 201
    banner.Parent = NotifContainer
    local limit = Instance.new("UISizeConstraint", banner)
    limit.MaxSize = Vector2.new(350, 82)
    Instance.new("UICorner", banner).CornerRadius = UDim.new(0, 12)
    local stroke = Instance.new("UIStroke", banner)
    stroke.Color = Color3.fromRGB(68, 68, 68)
    stroke.Transparency = 0.2
    stroke.Thickness = 1

    local accent = Instance.new("Frame", banner)
    accent.Size = UDim2.new(0, 2, 1, -28)
    accent.Position = UDim2.fromOffset(12, 14)
    accent.BackgroundColor3 = Color3.fromRGB(220, 220, 220)
    accent.BorderSizePixel = 0
    accent.ZIndex = 202
    Instance.new("UICorner", accent).CornerRadius = UDim.new(1, 0)

    local title = Instance.new("TextLabel", banner)
    title.Size = UDim2.new(1, -46, 0, 16)
    title.Position = UDim2.fromOffset(25, 11)
    title.BackgroundTransparency = 1
    title.Text = string.upper(payload.title)
    title.TextColor3 = Color3.fromRGB(245, 245, 245)
    title.Font = Enum.Font.GothamMedium
    title.TextSize = 10
    title.TextTruncate = Enum.TextTruncate.AtEnd
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.ZIndex = 202

    local body = Instance.new("TextLabel", banner)
    body.Size = UDim2.new(1, -46, 0, 44)
    body.Position = UDim2.fromOffset(25, 29)
    body.BackgroundTransparency = 1
    body.Text = payload.text
    body.TextColor3 = Color3.fromRGB(185, 185, 185)
    body.Font = Enum.Font.Gotham
    body.TextSize = 12
    body.TextWrapped = true
    body.TextXAlignment = Enum.TextXAlignment.Left
    body.TextYAlignment = Enum.TextYAlignment.Top
    body.ZIndex = 202
    -- Grow for longer messages and narrow screens, without clipping their text.
    local function fitText()
        local width = math.max(1, banner.AbsoluteSize.X - 46)
        local measured = game:GetService("TextService"):GetTextSize(
            payload.text, 12, Enum.Font.Gotham, Vector2.new(width, 10000))
        local height = math.max(82, math.ceil(measured.Y) + 44)
        limit.MaxSize = Vector2.new(350, height)
        banner.Size = UDim2.new(1, -24, 0, height)
        body.Size = UDim2.new(1, -46, 1, -40)
    end
    banner:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitText)
    fitText()
    return banner
end

local function runNotificationQueue()
    if notificationWorkerRunning then return end
    notificationWorkerRunning = true

    task.spawn(function()
        while runtime.Alive and #notificationQueue > 0 do
            local payload = table.remove(notificationQueue, 1)
            local banner = createMinimalBanner(payload)

            local enterTween = TweenService:Create(
                banner,
                TweenInfo.new(NOTIFICATION_TIMING.Enter, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
                {Position = UDim2.new(1, -12, 0, 64), GroupTransparency = 0}
            )
            enterTween:Play()
            enterTween.Completed:Wait()

            task.wait(payload.duration)
            if not runtime.Alive or not banner.Parent then break end

            local exitTween = TweenService:Create(
                banner,
                TweenInfo.new(NOTIFICATION_TIMING.Exit, Enum.EasingStyle.Quint, Enum.EasingDirection.In),
                {Position = UDim2.new(1, 374, 0, 64), GroupTransparency = 1}
            )
            exitTween:Play()
            exitTween.Completed:Wait()
            if banner.Parent then banner:Destroy() end
            task.wait(NOTIFICATION_TIMING.Gap)
        end

        notificationWorkerRunning = false
        if runtime.Alive and #notificationQueue > 0 then
            runNotificationQueue()
        end
    end)
end

sendNotification = function(text, options)
    options = type(options) == "table" and options or {}
    if not runtime.Alive then return end
    if (not runtime.NotificationsReady or runtime.SuppressNotifications) and not options.force then return end

    text = tostring(text or "")
    if text == "" then return end

    -- El serial permite que los wrappers sepan que el callback ya avisó,
    -- incluso cuando el texto repetido se descarta visualmente.
    runtime.NotificationSerial = (runtime.NotificationSerial or 0) + 1

    local now = os.clock()
    if text == lastNotificationText and now - lastNotificationAt < 0.25 then return end
    lastNotificationText = text
    lastNotificationAt = now

    local holdDuration = tonumber(options.duration)
    if not holdDuration then
        holdDuration = #text > 90 and 0.95 or (#text > 55 and 0.80 or NOTIFICATION_TIMING.Hold)
    end
    holdDuration = math.clamp(holdDuration, 0.40, 1.20)

    local payload = {
        text = text,
        title = tostring(options.title or "XeroHub"),
        icon = tostring(options.icon or "◇"),
        accent = Color3.fromHex("#E6E6E6"),
        duration = holdDuration,
        key = options.key,
    }

    -- Sustituye estados todavía pendientes del mismo control; no tiene sentido
    -- mostrar "activado" si el usuario ya volvió a desactivarlo.
    if payload.key then
        for index = #notificationQueue, 1, -1 do
            if notificationQueue[index].key == payload.key then
                table.remove(notificationQueue, index)
            end
        end
    end

    if options.priority then
        table.insert(notificationQueue, 1, payload)
    else
        table.insert(notificationQueue, payload)
    end

    -- Máximo cuatro pendientes: los avisos recientes aparecen pronto.
    while #notificationQueue > 4 do
        if options.priority then table.remove(notificationQueue, #notificationQueue)
        else table.remove(notificationQueue, 1) end
    end
    runNotificationQueue()
end
end

-- Conserva el nombre usado por las funciones existentes del script.
function showBottomMessage(text, options)
    sendNotification(text, options)
end




local MainSection = Window:Section({ Title = "PRINCIPAL", Opened = true })
local TrollSection = Window:Section({ Title = "PERSONAL", Opened = true })

local Tabs = {
    Inicio = MainSection:Tab({Title = "Inicio", Icon = "solar:home-bold"}),
    Aim = MainSection:Tab({Title = "Aimbot", Icon = "solar:target-bold"}),
    KillAll = MainSection:Tab({Title = "Kill All", Icon = "solar:target-bold"}), -- 🔥 NUEVA CATEGORÍA AGREGADA
    Vis = MainSection:Tab({Title = "Visuales", Icon = "solar:eye-bold"}),
    Mov = MainSection:Tab({Title = "Movimiento", Icon = "solar:running-bold"}),
    Farm = MainSection:Tab({Title = "AutoFarm", Icon = "solar:dollar-bold"}),
    Graficos = MainSection:Tab({Title = "Gráficos", Icon = "solar:palette-bold"}), -- 🔥 NUEVA PESTAÑA AQUÍ
    Emotes = TrollSection:Tab({Title = "Animaciones", Icon = "solar:smile-circle-bold"}),
    Apariencia = TrollSection:Tab({Title = "Apariencia", Icon = "solar:palette-bold"}),
    Config = TrollSection:Tab({Title = "Configuración", Icon = "solar:settings-bold"}),
    Creditos = TrollSection:Tab({Title = "Créditos", Icon = "solar:user-bold"})
}

-- Todos los toggles avisan automáticamente. Si el callback ya manda un
-- mensaje propio, el serial evita crear un segundo aviso duplicado.
for _, tab in pairs(Tabs) do
    pcall(function()
        local originalToggle = tab.Toggle
        if type(originalToggle) == "function" then
            tab.Toggle = function(self, options)
                options = options or {}
                local originalCallback = options.Callback
                local title = tostring(options.Title or "Función")
                local ready = false

                options.Callback = function(state, ...)
                    local serialBefore = runtime.NotificationSerial or 0
                    if originalCallback then originalCallback(state, ...) end

                    if ready and not runtime.SuppressNotifications
                        and (runtime.NotificationSerial or 0) == serialBefore then
                        local enabled = state == true
                        sendNotification(
                            title .. (enabled and " activado" or " desactivado"),
                            {
                                title = "XeroHub · Ajuste",
                                icon = enabled and "✓" or "–",
                                accent = enabled and Color3.fromHex("#78D98B") or Color3.fromHex("#8E8E93"),
                                key = "toggle:" .. title,
                            }
                        )
                    end
                end

                local toggle = originalToggle(self, options)
                task.defer(function() ready = true end)
                return toggle
            end
        end
    end)
end








Tabs.Inicio:Paragraph({
    Title = "Bienvenido a XeroHub",
    Desc = "Elige una categoría y encuentra cada ajuste con el buscador.",
})

local nombreEjecutor = identifyexecutor and identifyexecutor() or "Desconocido"
local accountPlan = "Free"
pcall(function()
    if player.MembershipType == Enum.MembershipType.Premium then
        accountPlan = "Premium"
    end
end)

Tabs.Inicio:Paragraph({
    Title = tostring(player.DisplayName),
    Desc = "@" .. tostring(player.Name)
        .. "\nEjecutor: " .. tostring(nombreEjecutor)
        .. "\nCuenta: " .. tostring(player.AccountAge or 0) .. " días"
        .. "\nPlan: " .. tostring(accountPlan),
    Image = "rbxthumb://type=AvatarHeadShot&id=" .. tostring(player.UserId) .. "&w=150&h=150",
    ImageSize = 58,
    CircleImage = true,
    ImageAlign = "left",
    ImageStrokeColor = Color3.fromRGB(244, 244, 244),
    ImageStrokeThickness = 1,
    Gothic = true,
    DecorText = "PROFILE",
    Color = Color3.fromRGB(11, 11, 14),
    StrokeColor = Color3.fromRGB(44, 44, 50),
})
-- ==========================================
-- CAMBIOS RECIENTES · INICIO
-- ==========================================
Tabs.Inicio:Section({Title = "Novedades de XeroHub"})

Tabs.Inicio:Paragraph({
    Title = "Apariencia",
    Desc = "Pestaña Apariencia agregada con Korblox, Headless y algunos limiteds.",
    Image = "solar:palette-bold",
    ImageSize = 34,
    Color = Color3.fromHex("#20252C")
})

Tabs.Inicio:Paragraph({
    Title = "Clonador de avatar",
    Desc = "Clona avatares por username o seleccionando jugadores del servidor.",
    Image = "solar:user-id-bold",
    ImageSize = 34,
    Color = Color3.fromHex("#20252C")
})


Tabs.Inicio:Section({Title = "Información del Servidor"})

-- Se carga de forma directa (como en MM2)
local gameNameStr = "Desconocido"
pcall(function() 
    gameNameStr = MarketplaceService:GetProductInfo(game.PlaceId).Name 
end)

Tabs.Inicio:Paragraph({ 
    Title = "Juego Actual", 
    Desc = gameNameStr .. "\nPlace ID: " .. game.PlaceId,
    Image = "rbxthumb://type=GameIcon&id=" .. game.GameId .. "&w=150&h=150", --  Extrae la foto oficial del juego
    ImageSize = 48 
})



local XERO_CREDITS_PROFILE = "rbxassetid://74846094133538" -- Foto del creador para Créditos.

Tabs.Creditos:Paragraph({
    Title = "Kev",
    Desc = "Creador de XeroHub\nTikTok: @kevzzx_",
    Image = XERO_CREDITS_PROFILE,
    ImageSize = 72,
    CircleImage = true,
    ImageAlign = "left",
    ImageStrokeColor = Color3.fromRGB(248, 248, 248),
    ImageStrokeThickness = 1,
    Gothic = true,
    BadgeText = "CREATOR",
    DecorText = "XERO",
    Color = Color3.fromRGB(9, 9, 12),
    StrokeColor = Color3.fromRGB(54, 54, 62),
})
Tabs.Creditos:Paragraph({
    Title = "Agradecimientos",
    Desc = "Gracias por usar XeroHub, su apoyo ayuda a mejorarlo más.",
    Gothic = true,
    DecorText = "THANKS",
    Color = Color3.fromRGB(11, 11, 14),
    StrokeColor = Color3.fromRGB(44, 44, 50),
})

Tabs.Inicio:Section({ Title = "Juegos Soportados" })

local TPS = game:GetService("TeleportService")

function TPSeguro_Duels(placeId, nombreJuego)
    if game.PlaceId == placeId then
        showBottomMessage("Ya estás en " .. nombreJuego .. ", buscando otro servidor...")
        pcall(function() TPS:Teleport(placeId, player) end)
    else
        showBottomMessage("Intentando ir a " .. nombreJuego .. "...")
        -- Copiamos el link por si Roblox bloquea el TP por seguridad
        pcall(function() setclipboard("https://www.roblox.com/games/" .. tostring(placeId)) end)
        task.wait(0.5)
        showBottomMessage("Link copiado. Si no te hace TP, pégalo en tu navegador para entrar.")
        -- Intentamos el TP de todos modos
        pcall(function() TPS:Teleport(placeId, player) end)
    end
end

Tabs.Inicio:Button({
    Title = "Murder Mystery 2",
    Callback = function() TPSeguro_Duels(142823291, "MM2") end
})

Tabs.Inicio:Button({
    Title = "Murderers VS Sheriffs (Duels)",
    Callback = function() TPSeguro_Duels(135856908115931, "Duels") end
})

Tabs.Inicio:Button({
    Title = "Duelos de Asesinato",
    Callback = function() TPSeguro_Duels(120851538706364, "DSA") end
})


Tabs.Inicio:Button({
    Title = "Murder Mystery V (MMV)",
    Callback = function() TPSeguro_Duels(74369636333825, "MMV") end
})


Tabs.Inicio:Section({Title = "Optimización"})

do
local Stats = game:GetService("Stats")
local statsContainer = Instance.new("Frame")
statsContainer.Name = "XeroPerformance"
statsContainer.Size = UDim2.fromOffset(184, 44)
statsContainer.AnchorPoint = Vector2.new(1, 0)
statsContainer.Position = UDim2.new(1, -12, 0, 12)
statsContainer.BackgroundColor3 = Color3.fromRGB(12, 12, 12)
statsContainer.BackgroundTransparency = 0.06
statsContainer.BorderSizePixel = 0
statsContainer.Visible = false
statsContainer.ZIndex = 100
statsContainer.Parent = screenGui
Instance.new("UICorner", statsContainer).CornerRadius = UDim.new(0, 12)
local outline = Instance.new("UIStroke", statsContainer)
outline.Color = Color3.fromRGB(60, 60, 60)
outline.Thickness = 1
local divider = Instance.new("Frame", statsContainer)
divider.Position = UDim2.new(0.5, 0, 0, 12)
divider.Size = UDim2.fromOffset(1, 20)
divider.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
divider.BorderSizePixel = 0
divider.ZIndex = 101
local function metric(caption, x)
    local label = Instance.new("TextLabel", statsContainer)
    label.Size = UDim2.fromOffset(72, 12)
    label.Position = UDim2.fromOffset(x, 6)
    label.BackgroundTransparency = 1
    label.Text = caption
    label.TextColor3 = Color3.fromRGB(140, 140, 140)
    label.Font = Enum.Font.GothamMedium
    label.TextSize = 8
    label.ZIndex = 101
    local value = Instance.new("TextLabel", statsContainer)
    value.Size = UDim2.fromOffset(72, 20)
    value.Position = UDim2.fromOffset(x, 18)
    value.BackgroundTransparency = 1
    value.Text = "--"
    value.TextColor3 = Color3.fromRGB(240, 240, 240)
    value.Font = Enum.Font.GothamMedium
    value.TextSize = 14
    value.ZIndex = 101
    return value
end
local fpsLabel = metric("FPS", 10)
local pingLabel = metric("PING / ms", 102)
local showStatsEnabled = false
local fpsFrames, statsElapsed = 0, 0
Tabs.Inicio:Toggle({
    Title = "Mostrar FPS y Ping",
    Callback = function(Value)
        showStatsEnabled = Value
        statsContainer.Visible = Value
        fpsFrames, statsElapsed = 0, 0
        fpsLabel.Text, pingLabel.Text = "--", "--"
    end,
})
runtime.Track(RunService.RenderStepped:Connect(function(deltaTime)
    if not showStatsEnabled then return end
    fpsFrames = fpsFrames + 1
    statsElapsed = statsElapsed + deltaTime
    if statsElapsed >= 1 then
        fpsLabel.Text = tostring(math.floor(fpsFrames / statsElapsed + 0.5))
        local ok, pingValue = pcall(function()
            return math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue())
        end)
        pingLabel.Text = ok and tostring(pingValue) or "--"
        fpsFrames, statsElapsed = 0, 0
    end
end))
end

local fpsBoostEnabled = false
runtime.FPSBoost = {
    Cache = setmetatable({}, {__mode = "k"}),
    LightingState = nil,
    TerrainState = nil,
    CacheFolder = nil,
    Connection = nil,
}

function runtime.ApplyLowGraphics(v)
    if not fpsBoostEnabled or not v or not v.Parent then return end

    local supported = v:IsA("BasePart") or v:IsA("Decal") or v:IsA("Texture")
        or v:IsA("SpecialMesh") or v:IsA("Light") or v:IsA("PostEffect")
        or v:IsA("SurfaceAppearance") or v:IsA("BaseWrap") or v:IsA("Clothing")
        or v:IsA("ParticleEmitter") or v:IsA("Trail") or v:IsA("Beam")
        or v:IsA("Smoke") or v:IsA("Fire") or v:IsA("Sparkles")
    if not supported then return end

    -- No tocamos avatares: evita ropa/meshes rotos y reduce muchísimo el trabajo.
    local model = v:FindFirstAncestorOfClass("Model")
    if model and model:FindFirstChildOfClass("Humanoid") then return end

    local cache = runtime.FPSBoost.Cache
    if cache[v] then return end
    local data = {}
    cache[v] = data

    if v:IsA("BasePart") and not v:IsA("Terrain") then
        data.Material = v.Material
        data.Reflectance = v.Reflectance
        data.CastShadow = v.CastShadow
        v.Material = Enum.Material.SmoothPlastic
        v.Reflectance = 0
        v.CastShadow = false
        if v:IsA("MeshPart") then
            data.TextureID = v.TextureID
            v.TextureID = ""
        end
    elseif v:IsA("SpecialMesh") then
        data.TextureId = v.TextureId
        v.TextureId = ""
    elseif v:IsA("SurfaceAppearance") or v:IsA("BaseWrap") or v:IsA("Clothing") then
        data.Parent = v.Parent
        v.Parent = runtime.FPSBoost.CacheFolder
    elseif v:IsA("Decal") or v:IsA("Texture") then
        data.Transparency = v.Transparency
        v.Transparency = 1
    elseif v:IsA("Light") or v:IsA("PostEffect") or v:IsA("ParticleEmitter")
        or v:IsA("Trail") or v:IsA("Beam") or v:IsA("Smoke")
        or v:IsA("Fire") or v:IsA("Sparkles") then
        data.Enabled = v.Enabled
        v.Enabled = false
    end
end

function runtime.RestoreLowGraphics()
    for v, data in pairs(runtime.FPSBoost.Cache) do
        if v then
            pcall(function()
                if data.Parent and data.Parent.Parent then v.Parent = data.Parent end
                if data.Material then v.Material = data.Material end
                if data.Reflectance ~= nil then v.Reflectance = data.Reflectance end
                if data.CastShadow ~= nil then v.CastShadow = data.CastShadow end
                if data.TextureID ~= nil then v.TextureID = data.TextureID end
                if data.TextureId ~= nil then v.TextureId = data.TextureId end
                if data.Transparency ~= nil then v.Transparency = data.Transparency end
                if data.Enabled ~= nil then v.Enabled = data.Enabled end
            end)
        end
        runtime.FPSBoost.Cache[v] = nil
    end
end

UIElements.ToggleFPS = Tabs.Graficos:Toggle({
    Title = "FPS Boost",
    Desc = "Reduce materiales, texturas y efectos del mapa sin tocar los avatares.",
    Value = false,
    Callback = function(state)
        fpsBoostEnabled = state
        local Lighting = game:GetService("Lighting")
        local Terrain = workspace:FindFirstChildOfClass("Terrain")

        if state then
            if not runtime.FPSBoost.CacheFolder or not runtime.FPSBoost.CacheFolder.Parent then
                local folder = Instance.new("Folder")
                folder.Name = "iLunX_PBRCache"
                folder.Parent = Lighting
                runtime.FPSBoost.CacheFolder = folder
            end

            runtime.FPSBoost.LightingState = {
                GlobalShadows = Lighting.GlobalShadows,
                FogEnd = Lighting.FogEnd,
                ShadowSoftness = Lighting.ShadowSoftness,
            }
            Lighting.GlobalShadows = false
            Lighting.FogEnd = 9e9
            Lighting.ShadowSoftness = 0

            if Terrain then
                runtime.FPSBoost.TerrainState = {
                    WaterWaveSize = Terrain.WaterWaveSize,
                    WaterWaveSpeed = Terrain.WaterWaveSpeed,
                    WaterReflectance = Terrain.WaterReflectance,
                    WaterTransparency = Terrain.WaterTransparency,
                    Decoration = Terrain.Decoration,
                }
                Terrain.WaterWaveSize = 0
                Terrain.WaterWaveSpeed = 0
                Terrain.WaterReflectance = 0
                Terrain.WaterTransparency = 1
                Terrain.Decoration = false
            end

            task.spawn(function()
                local descendants = workspace:GetDescendants()
                for i = 1, #descendants do
                    runtime.ApplyLowGraphics(descendants[i])
                    if i % 450 == 0 then task.wait() end
                end
                table.clear(descendants)
            end)

            if runtime.FPSBoost.Connection then runtime.FPSBoost.Connection:Disconnect() end
            runtime.FPSBoost.Connection = runtime.Track(workspace.DescendantAdded:Connect(function(v)
                if fpsBoostEnabled then runtime.ApplyLowGraphics(v) end
            end))
            showBottomMessage("FPS Boost aplicado.")
        else
            if runtime.FPSBoost.Connection then
                runtime.FPSBoost.Connection:Disconnect()
                runtime.FPSBoost.Connection = nil
            end

            local lightState = runtime.FPSBoost.LightingState
            if lightState then
                Lighting.GlobalShadows = lightState.GlobalShadows
                Lighting.FogEnd = lightState.FogEnd
                Lighting.ShadowSoftness = lightState.ShadowSoftness
            end

            local terrainState = runtime.FPSBoost.TerrainState
            if Terrain and terrainState then
                Terrain.WaterWaveSize = terrainState.WaterWaveSize
                Terrain.WaterWaveSpeed = terrainState.WaterWaveSpeed
                Terrain.WaterReflectance = terrainState.WaterReflectance
                Terrain.WaterTransparency = terrainState.WaterTransparency
                Terrain.Decoration = terrainState.Decoration
            end

            runtime.RestoreLowGraphics()
            if runtime.FPSBoost.CacheFolder and runtime.FPSBoost.CacheFolder.Parent then
                runtime.FPSBoost.CacheFolder:Destroy()
            end
            runtime.FPSBoost.CacheFolder = nil
            runtime.FPSBoost.LightingState = nil
            runtime.FPSBoost.TerrainState = nil
            showBottomMessage("Gráficos originales restaurados.")
        end
    end
})

Tabs.Inicio:Button({
    Title = "Cambiar de Servidor",
    Callback = function()
        showBottomMessage("Buscando servidor vacío...")
        local TPS = game:GetService("TeleportService")
        local Api = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"
        
        task.spawn(function()
            local success, err = pcall(function()
                local req = request or http_request or (syn and syn.request)
                if req then
                    local res = req({Url = Api, Method = "GET"})
                    if res.StatusCode == 200 then
                        local data = HttpService:JSONDecode(res.Body)
                        local servers = {}
                        if data and data.data then for _, v in pairs(data.data) do if v.playing < v.maxPlayers and v.id ~= game.JobId then table.insert(servers, v.id) end end end
                        if #servers > 0 then
                            local randomServer = servers[math.random(1, #servers)]
                            showBottomMessage("¡Servidor encontrado!...")
                            TPS:TeleportToPlaceInstance(game.PlaceId, randomServer, player)
                        else showBottomMessage("No hay servidores vacíos disponibles.") end
                    else showBottomMessage("Error de conexión con el Proxy.") end
                else showBottomMessage("Tu ejecutor no soporta HTTP Requests.") end
            end)
            if not success then warn("Error en Server Hop:", err) end
        end)
    end,
})

-- ==========================================
-- PESTAÑA AIMBOT
-- ==========================================

-- 🔥 FIX OFUSCADOR: Mover la lista de jugadores AQUÍ ARRIBA antes del macro
local listaJugadores = Players:GetPlayers()
runtime.Track(Players.PlayerAdded:Connect(function(p) table.insert(listaJugadores, p) end))
runtime.Track(Players.PlayerRemoving:Connect(function(p)
    for i, v in ipairs(listaJugadores) do
        if v == p then table.remove(listaJugadores, i) break end
    end
end))

local macroActivo = false
local macroEquipDelay = 0.04
local macroShootDelay = 0.10

Tabs.Aim:Section({Title = "Macro (Pistola)"})
UIElements.TogMacro = Tabs.Aim:Toggle({
    Title = "Activar Macro", 
    Desc = "Dispara con un solo toque.",
    Callback = function(s) macroActivo = s end
})

UIElements.SliMacroEquip = Tabs.Aim:Slider({
    Title = "Delay al Equipar",
    Desc = "Sube esto si la pistola no alcanza a salir. (Segundos)",
    Step = 0.01,
    Value = {Min = 0.01, Max = 0.50, Default = 0.04},
    Callback = function(v) macroEquipDelay = v end
})

UIElements.SliMacroShoot = Tabs.Aim:Slider({
    Title = "Delay de Disparo",
    Desc = "Sube esto si el tiro no cuenta daño. (Segundos)",
    Step = 0.01,
    Value = {Min = 0.05, Max = 0.80, Default = 0.10},
    Callback = function(v) macroShootDelay = v end
})

local deadZoneFrame = Instance.new("Frame")
deadZoneFrame.Size = UDim2.new(0, 150, 0, 150)
deadZoneFrame.Position = UDim2.new(0.8, -75, 0.8, -75) 
deadZoneFrame.BackgroundColor3 = Color3.fromRGB(255, 50, 50) 
deadZoneFrame.BackgroundTransparency = 0.5
deadZoneFrame.Visible = false
deadZoneFrame.ZIndex = 100
deadZoneFrame.Parent = screenGui 
Instance.new("UICorner", deadZoneFrame).CornerRadius = UDim.new(0, IOS_STYLE.WindowRadius)

local dzStroke = Instance.new("UIStroke", deadZoneFrame)
dzStroke.Color = Color3.fromRGB(255, 255, 255)
dzStroke.Thickness = 2
dzStroke.LineJoinMode = Enum.LineJoinMode.Round

local dzLabel = Instance.new("TextLabel", deadZoneFrame)
dzLabel.Size = UDim2.new(1, 0, 1, 0)
dzLabel.BackgroundTransparency = 1
dzLabel.Text = "ZONA MUERTA\n(Arrastrar)"
dzLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
dzLabel.Font = Enum.Font.GothamBold
dzLabel.TextSize = 14
dzLabel.TextWrapped = true

makeDraggable(deadZoneFrame, deadZoneFrame)

UIElements.TogDeadZone = Tabs.Aim:Toggle({
    Title = "Mostrar/Acomodar Zona Muerta", 
    Callback = function(s) deadZoneFrame.Visible = s end
})

UIElements.SliDeadZone = Tabs.Aim:Slider({
    Title = "Tamaño de Zona Muerta", 
    Step = 10,
    Value = {Min = 80, Max = 400, Default = 150}, 
    Callback = function(v) deadZoneFrame.Size = UDim2.new(0, v, 0, v) end
})

local forbiddenKeywords = {"knife", "cuchillo", "blade", "sword", "dagger", "kunai", "toy", "juguete", "balloon", "food", "drink", "pizza", "burger", "teddy", "combat", "punch", "fist", "wallet", "phone", "boombox", "radio"}
local weaponClassificationCache = setmetatable({}, {__mode = "k"})

function esLaPistola(item)
    if not item:IsA("Tool") then return false end
    local cached = weaponClassificationCache[item]
    if cached ~= nil then return cached end

    if item:FindFirstChild("Throw") or item:FindFirstChild("KnifeClient") or item:FindFirstChild("KnifeServer") then
        weaponClassificationCache[item] = false
        return false
    end
    
    local n = string.lower(item.Name)
    for i = 1, #forbiddenKeywords do
        if string.find(n, forbiddenKeywords[i]) then
            weaponClassificationCache[item] = false
            return false
        end
    end
    
    weaponClassificationCache[item] = true
    return true
end

function obtenerPistola()
    local char = player.Character
    local backpack = player:FindFirstChild("Backpack")
    if char then for _, item in ipairs(char:GetChildren()) do if esLaPistola(item) then return item end end end
    if backpack then for _, item in ipairs(backpack:GetChildren()) do if esLaPistola(item) then return item end end end
    return nil 
end

-- ==========================================
-- CACHÉ INTELIGENTE DE LOBBY (0 LAG)
-- ==========================================
local isTeamLobby = false
local hasForceField = false

-- 1. Actualiza el caché SOLO cuando cambias de equipo
local function updateTeamCache()
    if player.Team then
        local tName = string.lower(player.Team.Name)
        if string.find(tName, "lobby") or string.find(tName, "spectat") or string.find(tName, "espectador") or string.find(tName, "menu") or string.find(tName, "dead") then
            isTeamLobby = true
        else
            isTeamLobby = false
        end
    else
        isTeamLobby = false
    end
end

runtime.Track(player:GetPropertyChangedSignal("Team"):Connect(updateTeamCache))
updateTeamCache() -- Escaneo inicial

-- 2. Actualiza el caché SOLO cuando te ponen o quitan un campo de fuerza
runtime.Track(player.CharacterAdded:Connect(function(char)
    hasForceField = char:FindFirstChildOfClass("ForceField") ~= nil
    
    runtime.Track(char.ChildAdded:Connect(function(child)
        if child:IsA("ForceField") then hasForceField = true end
    end))
    runtime.Track(char.ChildRemoved:Connect(function(child)
        if child:IsA("ForceField") then hasForceField = false end
    end))
end))

-- 3. La función maestra ahora es 1000x más rápida
function estaEnLobby()
    local char = player.Character 
    if not char then return true end
    
    -- Leemos las variables del caché en un milisegundo
    if hasForceField or isTeamLobby then return true end
    
    -- Solo hace las matemáticas de distancia si los cachés fallaron
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if hrp then
        local myPos = hrp.Position
        for i = 1, #ZONAS_SEGURAS do
            if (myPos - ZONAS_SEGURAS[i].Centro).Magnitude <= ZONAS_SEGURAS[i].Radio then 
                return true
            end
        end
    end
    
    return false
end

function ejecutarAccionMacro()
    
    if estaEnLobby() then return end

    local hayEnemigos = false
    for i = 1, #listaJugadores do
    local p = listaJugadores[i]
        if p ~= player then
            local pChar = p.Character
            if pChar and pChar:FindFirstChild("Humanoid") and pChar.Humanoid.Health > 0 then
                if player.Team == nil or p.Team == nil or player.Team ~= p.Team then
                    hayEnemigos = true
                    break 
                end
            end
        end
    end

    if not hayEnemigos then return end

    local char = player.Character if not char then return end
    local hum = char:FindFirstChild("Humanoid") if not hum then return end
    local herramientaEnMano = char:FindFirstChildOfClass("Tool")
    if herramientaEnMano and not esLaPistola(herramientaEnMano) then return end

    local pistola = obtenerPistola()
    if not pistola then return end

    task.spawn(function()
        hum:UnequipTools() 
        task.wait() 
        hum:EquipTool(pistola) 
        
        -- Usa la variable del slider para el tiempo de equipar
        task.wait(macroEquipDelay) 
        
        if pistola.Parent == char then 
            pistola:Activate() 
            
            -- Usa la variable del slider para el registro del disparo
            task.wait(macroShootDelay) 
            
            pistola:Deactivate()
            hum:UnequipTools() 
        end
    end)
end


local toquesPantalla = {} 

runtime.Track(UserInputService.InputChanged:Connect(function(input, processed)
    if input.UserInputType == Enum.UserInputType.Touch and toquesPantalla[input] then
        if (toquesPantalla[input].posicion - input.Position).Magnitude > 10 then
            toquesPantalla = {} 
        end
    end
end))

runtime.Track(UserInputService.InputBegan:Connect(function(input, processed)
    if processed or not macroActivo then return end
    
    if input.UserInputType == Enum.UserInputType.MouseButton1 then 
        ejecutarAccionMacro()
    elseif input.UserInputType == Enum.UserInputType.Touch then
        local pos = input.Position
        local dzPos = deadZoneFrame.AbsolutePosition
        local dzSize = deadZoneFrame.AbsoluteSize
        local tocoZonaMuerta = (pos.X >= dzPos.X) and (pos.X <= dzPos.X + dzSize.X) and (pos.Y >= dzPos.Y) and (pos.Y <= dzPos.Y + dzSize.Y)
        
        if not tocoZonaMuerta then 
            toquesPantalla[input] = {posicion = input.Position, tiempo = tick()} 
        end
    end
end))

runtime.Track(UserInputService.InputEnded:Connect(function(input, processed)
    if not macroActivo then return end
    
    if input.UserInputType == Enum.UserInputType.Touch and toquesPantalla[input] then
        local datosToque = toquesPantalla[input] 
        local posicionFinal = input.Position
        local distanciaMovida = (datosToque.posicion - posicionFinal).Magnitude 
        local tiempoPresionado = tick() - datosToque.tiempo
        
        toquesPantalla[input] = nil
        
        if distanciaMovida < 10 and tiempoPresionado < 0.35 and tiempoPresionado > 0.03 then 
            ejecutarAccionMacro() 
        end
    end
end))

-- ==========================================
-- 🚀 OPTIMIZACIÓN EXTREMA: CACHÉ DE ENEMIGOS POR EVENTOS
-- ==========================================



local enemyCache = {}

function updateMyTeam() enemyCache = {} end -- Si el LocalPlayer cambia, reseteamos todo
function updateEnemy(p) enemyCache[p] = nil end -- Borramos solo al enemigo que cambió

runtime.Track(player:GetPropertyChangedSignal("Team"):Connect(updateMyTeam))
runtime.Track(player:GetPropertyChangedSignal("TeamColor"):Connect(updateMyTeam))
runtime.Track(player:GetAttributeChangedSignal("Team"):Connect(updateMyTeam))
runtime.Track(player:GetAttributeChangedSignal("team"):Connect(updateMyTeam))

function setupPlayerEvents(p)
    runtime.Track(p:GetPropertyChangedSignal("Team"):Connect(function() updateEnemy(p) end))
    runtime.Track(p:GetPropertyChangedSignal("TeamColor"):Connect(function() updateEnemy(p) end))
    runtime.Track(p:GetAttributeChangedSignal("Team"):Connect(function() updateEnemy(p) end))
    runtime.Track(p:GetAttributeChangedSignal("team"):Connect(function() updateEnemy(p) end))
end

for _, p in ipairs(listaJugadores) do
    if p ~= player then setupPlayerEvents(p) end
end
runtime.Track(Players.PlayerAdded:Connect(function(p) setupPlayerEvents(p) end))
runtime.Track(Players.PlayerRemoving:Connect(function(p) updateEnemy(p) end))

function isEnemy(targetPlayer)
    if not teamCheckEnabled then return true end
    if targetPlayer == player then return false end
    
    if enemyCache[targetPlayer] ~= nil then return enemyCache[targetPlayer] end

    local isDiff = true
    if player.Team ~= nil and targetPlayer.Team ~= nil then
        isDiff = (player.Team ~= targetPlayer.Team)
    else
        local pAttr = player:GetAttribute("Team") or player:GetAttribute("team") 
        local tAttr = targetPlayer:GetAttribute("Team") or targetPlayer:GetAttribute("team")
        if pAttr ~= nil and tAttr ~= nil then
            isDiff = (pAttr ~= tAttr)
        elseif player.TeamColor.Name ~= "White" and player.TeamColor.Name ~= "Medium stone grey" then
            isDiff = (player.TeamColor ~= targetPlayer.TeamColor)
        end
    end
    
    enemyCache[targetPlayer] = isDiff
    return isDiff
end


-- ==========================================
-- AUTO SHOOT Y SILENT AIM (OPTIMIZADOS AL MÁXIMO)
-- ==========================================
Tabs.Aim:Section({Title = "Auto Shoot"})

local autoShootTargetPart = "Cabeza"
local autoShootCuchilloEnabled = false
local tapToShootEnabled = false
local silentAimPistolaEnabled = false 
local silentAimCuchilloEnabled = false 
local silentAimTargetPart = "Cabeza"
local silentAimFovEnabled = false

-- ==========================================
-- SELECTOR CORPORAL VISUAL + APARIENCIA
-- Todo vive en runtime para no aumentar la presión de locales del chunk principal.
-- ==========================================
runtime.TargetBodyOrder = {
    "Cabeza", "Torso superior", "Torso inferior",
    "Brazo izquierdo", "Brazo derecho", "Pierna izquierda", "Pierna derecha"
}
runtime.TargetBodyGroups = {
    ["Cabeza"] = {"Head"},
    ["Torso superior"] = {"UpperTorso", "Torso"},
    ["Torso inferior"] = {"LowerTorso", "Torso", "HumanoidRootPart"},
    ["Brazo izquierdo"] = {"LeftUpperArm", "LeftLowerArm", "LeftHand", "LeftArm"},
    ["Brazo derecho"] = {"RightUpperArm", "RightLowerArm", "RightHand", "RightArm"},
    ["Pierna izquierda"] = {"LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "LeftLeg"},
    ["Pierna derecha"] = {"RightUpperLeg", "RightLowerLeg", "RightFoot", "RightLeg"},
}
runtime.TargetSelections = {
    AutoShoot = { ["Cabeza"] = true },
    SilentAim = { ["Cabeza"] = true },
}
runtime.TargetPartNameCache = {
    AutoShoot = {"Head"},
    SilentAim = {"Head"},
}
-- OPT: cacheamos las referencias de partes por Character. Silent Aim corre muy
-- seguido, así que evitar FindFirstChild repetido aquí quita bastante trabajo en móvil.
runtime.TargetSelectionVersion = {AutoShoot = 1, SilentAim = 1}
runtime.TargetPartCache = {
    AutoShoot = setmetatable({}, {__mode = "k"}),
    SilentAim = setmetatable({}, {__mode = "k"}),
}

function runtime.RebuildTargetPartNameCache(mode)
    local selected = runtime.TargetSelections[mode] or {}
    local result = runtime.TargetPartNameCache[mode] or {}
    table.clear(result)
    local seenNames = {}
    for _, groupName in ipairs(runtime.TargetBodyOrder) do
        if selected[groupName] then
            local names = runtime.TargetBodyGroups[groupName]
            for i = 1, #names do
                local name = names[i]
                if not seenNames[name] then
                    seenNames[name] = true
                    result[#result + 1] = name
                end
            end
        end
    end
    if #result == 0 then result[1] = "Head" end
    runtime.TargetPartNameCache[mode] = result
    return result
end

function runtime.GetTargetSelectionArray(mode)
    local result = {}
    local selected = runtime.TargetSelections[mode] or {}
    for _, name in ipairs(runtime.TargetBodyOrder) do
        if selected[name] then table_insert(result, name) end
    end
    return result
end

function runtime.SetTargetSelection(mode, value)
    local selected = runtime.TargetSelections[mode]
    if not selected then return end
    table.clear(selected)

    local function enableGroup(name)
        if runtime.TargetBodyGroups[name] then selected[name] = true end
    end

    if type(value) == "table" then
        for _, name in ipairs(value) do enableGroup(name) end
    elseif value == "Cabeza" then
        enableGroup("Cabeza")
    elseif value == "Torso" then
        enableGroup("Torso superior")
        enableGroup("Torso inferior")
    elseif value == "Cuerpo Completo" then
        for _, name in ipairs(runtime.TargetBodyOrder) do enableGroup(name) end
    elseif type(value) == "string" then
        enableGroup(value)
    end

    if not next(selected) then selected["Cabeza"] = true end
    runtime.RebuildTargetPartNameCache(mode)
    runtime.TargetSelectionVersion[mode] = (runtime.TargetSelectionVersion[mode] or 0) + 1
    local cache = runtime.TargetPartCache[mode]
    if cache then table.clear(cache) end
    local names = runtime.GetTargetSelectionArray(mode)
    if mode == "AutoShoot" then
        autoShootTargetPart = table.concat(names, ", ")
    else
        silentAimTargetPart = table.concat(names, ", ")
    end

    if runtime.BodySelector and runtime.BodySelector.Refresh then
        runtime.BodySelector.Refresh()
    end
end

function runtime.CollectTargetParts(char, mode, out, seen)
    table.clear(out)
    table.clear(seen)
    if not char then return out end

    local modeCache = runtime.TargetPartCache[mode]
    local version = runtime.TargetSelectionVersion[mode] or 1
    local cached = modeCache and modeCache[char]
    if cached and cached.Version == version then
        local valid = true
        for i = 1, #cached.Parts do
            local part = cached.Parts[i]
            if not part or part.Parent ~= char then valid = false break end
            out[i] = part
        end
        if valid and #out > 0 then return out end
        table.clear(out)
        modeCache[char] = nil
    end

    local partNames = runtime.TargetPartNameCache[mode] or runtime.RebuildTargetPartNameCache(mode)
    for i = 1, #partNames do
        local part = ffc(char, partNames[i])
        if part and part:IsA("BasePart") and not seen[part] then
            seen[part] = true
            out[#out + 1] = part
        end
    end
    if #out == 0 then
        local fallback = ffc(char, "Head") or ffc(char, "HumanoidRootPart")
        if fallback then out[1] = fallback end
    end

    if modeCache and #out > 0 then
        local parts = table.create and table.create(#out) or {}
        for i = 1, #out do parts[i] = out[i] end
        modeCache[char] = {Version = version, Parts = parts}
    end
    return out
end

function runtime.EnsureBodySelector()
    if runtime.BodySelectorGui and runtime.BodySelectorGui.Parent then return end

    local parent = playerGui
    pcall(function()
        parent = gethui and gethui() or game:GetService("CoreGui")
    end)

    local gui = Instance.new("ScreenGui")
    gui.Name = "iLunX_BodySelector"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.DisplayOrder = 2147483647
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    pcall(function()
        gui.ScreenInsets = Enum.ScreenInsets.None
        gui.ClipToDeviceSafeArea = false
        gui.SafeAreaCompatibility = Enum.SafeAreaCompatibility.None
        gui.OnTopOfCoreBlur = true
    end)
    gui.Parent = parent
    runtime.BodySelectorGui = gui

    local overlay = Instance.new("Frame")
    overlay.Name = "Overlay"
    overlay.Size = UDim2.fromScale(1, 1)
    overlay.BackgroundColor3 = Color3.fromHex("#000000")
    overlay.BackgroundTransparency = 0.36
    overlay.Visible = false
    overlay.Active = true
    overlay.ZIndex = 400
    overlay.Parent = gui

    local card = Instance.new("CanvasGroup")
    card.AnchorPoint = Vector2.new(0.5, 0.5)
    card.Position = UDim2.fromScale(0.5, 0.5)
    card.Size = UDim2.fromOffset(440, 360)
    card.BackgroundColor3 = Color3.fromHex("#111214")
    card.BorderSizePixel = 0
    card.ZIndex = 401
    card.Parent = overlay
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 22)

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromHex("#5E636A")
    stroke.Transparency = 0.35
    stroke.Thickness = 1
    stroke.Parent = card

    local scale = Instance.new("UIScale")
    scale.Scale = 1
    scale.Parent = card

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -88, 0, 24)
    title.Position = UDim2.fromOffset(18, 14)
    title.BackgroundTransparency = 1
    title.Text = "Selector corporal"
    title.TextColor3 = Color3.fromHex("#F7F8F9")
    title.Font = Enum.Font.GothamBold
    title.TextSize = 15
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.ZIndex = 402
    title.Parent = card

    local closeSelector = Instance.new("TextButton")
    closeSelector.Name = "Close"
    closeSelector.Size = UDim2.fromOffset(28, 28)
    closeSelector.Position = UDim2.new(1, -42, 0, 12)
    closeSelector.BackgroundColor3 = Color3.fromHex("#25272B")
    closeSelector.BorderSizePixel = 0
    closeSelector.Text = "×"
    closeSelector.TextColor3 = Color3.fromHex("#E7E7E7")
    closeSelector.Font = Enum.Font.GothamBold
    closeSelector.TextSize = 16
    closeSelector.AutoButtonColor = false
    closeSelector.ZIndex = 405
    closeSelector.Parent = card
    Instance.new("UICorner", closeSelector).CornerRadius = UDim.new(0, 9)
    closeSelector.Activated:Connect(function()
        overlay.Visible = false
    end)

    local subtitle = Instance.new("TextLabel")
    subtitle.Size = UDim2.new(1, -36, 0, 28)
    subtitle.Position = UDim2.fromOffset(18, 39)
    subtitle.BackgroundTransparency = 1
    subtitle.Text = "Toca varias zonas del cuerpo. Las partes activas se iluminan al instante."
    subtitle.TextColor3 = Color3.fromHex("#9DA3AB")
    subtitle.Font = Enum.Font.Gotham
    subtitle.TextSize = 10
    subtitle.TextWrapped = true
    subtitle.TextXAlignment = Enum.TextXAlignment.Left
    subtitle.TextYAlignment = Enum.TextYAlignment.Top
    subtitle.ZIndex = 402
    subtitle.Parent = card

    local figure = Instance.new("Frame")
    figure.Size = UDim2.fromOffset(160, 220)
    figure.Position = UDim2.fromOffset(18, 74)
    figure.BackgroundColor3 = Color3.fromHex("#090A0C")
    figure.BackgroundTransparency = 0.08
    figure.BorderSizePixel = 0
    figure.ZIndex = 402
    figure.Parent = card
    Instance.new("UICorner", figure).CornerRadius = UDim.new(0, 14)

    runtime.BodySelector = {
        Mode = "AutoShoot",
        Segments = {},
        Rows = {},
        Overlay = overlay,
        Card = card,
        Scale = scale,
        Title = title,
        Subtitle = subtitle,
        CloseButton = closeSelector,
        Figure = figure,
        List = nil,
    }

    local function toggle(name)
        local selected = runtime.TargetSelections[runtime.BodySelector.Mode]
        selected[name] = not selected[name] or nil
        runtime.BodySelector.Refresh()
    end

    local function segment(name, x, y, w, h, radius)
        local button = Instance.new("TextButton")
        button.Name = name
        button.Size = UDim2.fromOffset(w, h)
        button.Position = UDim2.fromOffset(x, y)
        button.BackgroundColor3 = Color3.fromHex("#24262A")
        button.BorderSizePixel = 0
        button.Text = ""
        button.AutoButtonColor = false
        button.ZIndex = 404
        button.Parent = figure
        Instance.new("UICorner", button).CornerRadius = UDim.new(0, radius or 10)
        local segStroke = Instance.new("UIStroke")
        segStroke.Color = Color3.fromHex("#4B5057")
        segStroke.Transparency = 0.35
        segStroke.Thickness = 1
        segStroke.Parent = button
        runtime.BodySelector.Segments[name] = {Button = button, Stroke = segStroke}
        button.Activated:Connect(function() toggle(name) end)
    end

    segment("Cabeza", 59, 8, 42, 42, 21)
    segment("Torso superior", 46, 55, 68, 45, 11)
    segment("Torso inferior", 50, 104, 60, 32, 9)
    segment("Brazo izquierdo", 20, 58, 20, 78, 10)
    segment("Brazo derecho", 120, 58, 20, 78, 10)
    segment("Pierna izquierda", 49, 143, 25, 66, 11)
    segment("Pierna derecha", 86, 143, 25, 66, 11)

    local list = Instance.new("ScrollingFrame")
    list.Name = "BodyPartList"
    list.Size = UDim2.fromOffset(232, 220)
    list.Position = UDim2.fromOffset(190, 74)
    list.BackgroundTransparency = 1
    list.BorderSizePixel = 0
    list.ScrollBarThickness = 2
    list.ScrollBarImageColor3 = Color3.fromHex("#6E737A")
    list.CanvasSize = UDim2.fromOffset(0, 210)
    list.ScrollingDirection = Enum.ScrollingDirection.Y
    list.ElasticBehavior = Enum.ElasticBehavior.Never
    list.ZIndex = 402
    list.Parent = card
    runtime.BodySelector.List = list

    for index, name in ipairs(runtime.TargetBodyOrder) do
        local row = Instance.new("TextButton")
        row.Size = UDim2.new(1, 0, 0, 27)
        row.Position = UDim2.fromOffset(0, (index - 1) * 30)
        row.BackgroundColor3 = Color3.fromHex("#1C1E21")
        row.BorderSizePixel = 0
        row.TextColor3 = Color3.fromHex("#E7E7E7")
        row.Font = Enum.Font.GothamMedium
        row.TextSize = 10
        row.TextXAlignment = Enum.TextXAlignment.Left
        row.AutoButtonColor = false
        row.ZIndex = 403
        row.Parent = list
        Instance.new("UICorner", row).CornerRadius = UDim.new(0, 10)
        local pad = Instance.new("UIPadding")
        pad.PaddingLeft = UDim.new(0, 12)
        pad.Parent = row
        runtime.BodySelector.Rows[name] = row
        row.Activated:Connect(function() toggle(name) end)
    end

    local function action(text, x, width, callback)
        local b = Instance.new("TextButton")
        b.Size = UDim2.fromOffset(width, 32)
        b.Position = UDim2.new(0, x, 1, -42)
        b.BackgroundColor3 = Color3.fromHex("#25272B")
        b.BorderSizePixel = 0
        b.Text = text
        b.TextColor3 = Color3.fromHex("#F2F3F5")
        b.Font = Enum.Font.GothamBold
        b.TextSize = 10
        b.AutoButtonColor = false
        b.ZIndex = 403
        b.Parent = card
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 11)
        b.Activated:Connect(callback)
        return b
    end

    local selectAllButton = action("Todo", 18, 74, function()
        local selected = runtime.TargetSelections[runtime.BodySelector.Mode]
        for _, name in ipairs(runtime.TargetBodyOrder) do selected[name] = true end
        runtime.BodySelector.Refresh()
    end)
    local clearButton = action("Limpiar", 98, 78, function()
        table.clear(runtime.TargetSelections[runtime.BodySelector.Mode])
        runtime.BodySelector.Refresh()
    end)
    local done = action("Aplicar", 330, 92, function()
        local mode = runtime.BodySelector.Mode
        local selected = runtime.TargetSelections[mode]
        if not next(selected) then selected["Cabeza"] = true end
        runtime.SetTargetSelection(mode, runtime.GetTargetSelectionArray(mode))
        overlay.Visible = false
        showBottomMessage((mode == "AutoShoot" and "Auto Shoot" or "Silent Aim") .. ": selección corporal aplicada.")
    end)
    done.BackgroundColor3 = Color3.fromHex("#E6E9EC")
    done.TextColor3 = Color3.fromHex("#111214")
    runtime.BodySelector.SelectAllButton = selectAllButton
    runtime.BodySelector.ClearButton = clearButton
    runtime.BodySelector.DoneButton = done

    -- Reflow real del selector. En portrait apila el muñeco y la lista; en
    -- landscape/desktop conserva las dos columnas. Sólo usa UIScale como último
    -- recurso si el viewport es físicamente menor que el layout base.
    function runtime.ApplyBodySelectorResponsiveLayout()
        local selector = runtime.BodySelector
        if not selector then return 1 end
        local bounds = selector.Overlay.AbsoluteSize
        if bounds.X < 1 or bounds.Y < 1 then
            local currentCamera = workspace.CurrentCamera
            bounds = currentCamera and currentCamera.ViewportSize or Vector2.new(800, 600)
        end

        local margin = math.clamp(math.floor(math.min(bounds.X, bounds.Y) * 0.025), 6, 14)
        local rawAvailableW = math.max(1, bounds.X - margin * 2)
        local rawAvailableH = math.max(1, bounds.Y - margin * 2)
        local availableW = math.max(240, rawAvailableW)
        local availableH = math.max(260, rawAvailableH)
        local portrait = availableW < 470 or (availableW / math.max(1, availableH)) < 1.05

        if not portrait then
            selector.Card.Size = UDim2.fromOffset(440, 360)
            selector.Title.Position = UDim2.fromOffset(18, 14)
            selector.Title.Size = UDim2.new(1, -88, 0, 24)
            selector.Title.TextSize = 15
            selector.Subtitle.Position = UDim2.fromOffset(18, 39)
            selector.Subtitle.Size = UDim2.new(1, -36, 0, 28)
            selector.Subtitle.TextSize = 10
            selector.CloseButton.Position = UDim2.new(1, -42, 0, 12)
            selector.Figure.Position = UDim2.fromOffset(18, 74)
            selector.Figure.Size = UDim2.fromOffset(160, 220)
            selector.List.Position = UDim2.fromOffset(190, 74)
            selector.List.Size = UDim2.fromOffset(232, 220)
            selector.List.CanvasSize = UDim2.fromOffset(0, 210)

            for index, name in ipairs(runtime.TargetBodyOrder) do
                local row = selector.Rows[name]
                if row then
                    row.Size = UDim2.new(1, 0, 0, 27)
                    row.Position = UDim2.fromOffset(0, (index - 1) * 30)
                    row.TextSize = 10
                end
            end

            selector.SelectAllButton.Size = UDim2.fromOffset(74, 32)
            selector.SelectAllButton.Position = UDim2.new(0, 18, 1, -42)
            selector.ClearButton.Size = UDim2.fromOffset(78, 32)
            selector.ClearButton.Position = UDim2.new(0, 98, 1, -42)
            selector.DoneButton.Size = UDim2.fromOffset(92, 32)
            selector.DoneButton.Position = UDim2.new(0, 330, 1, -42)

            local targetScale = math.min(1, availableW / 440, availableH / 360)
            selector.Scale.Scale = targetScale
            selector.LayoutMode = "wide"
            selector.TargetScale = targetScale
            return targetScale
        end

        local cardW = math.min(420, availableW)
        local cardH = math.min(620, availableH)
        cardH = math.max(360, cardH)
        selector.Card.Size = UDim2.fromOffset(cardW, cardH)
        local portraitScale = math.min(1, rawAvailableW / cardW, rawAvailableH / cardH)
        portraitScale = math.max(0.55, portraitScale)
        selector.Scale.Scale = portraitScale
        selector.TargetScale = portraitScale
        selector.LayoutMode = "portrait"

        selector.Title.Position = UDim2.fromOffset(14, 12)
        selector.Title.Size = UDim2.new(1, -58, 0, 22)
        selector.Title.TextSize = cardW < 330 and 12 or 14
        selector.Title.TextTruncate = Enum.TextTruncate.AtEnd
        selector.Subtitle.Position = UDim2.fromOffset(14, 35)
        selector.Subtitle.Size = UDim2.new(1, -28, 0, 32)
        selector.Subtitle.TextSize = cardW < 330 and 9 or 10
        selector.CloseButton.Position = UDim2.new(1, -40, 0, 10)

        local figureY = 72
        selector.Figure.Size = UDim2.fromOffset(160, 220)
        selector.Figure.Position = UDim2.fromOffset(math.floor((cardW - 160) / 2), figureY)

        local listY = figureY + 228
        local actionsY = cardH - 42
        local listH = math.max(58, actionsY - listY - 8)
        selector.List.Position = UDim2.fromOffset(14, listY)
        selector.List.Size = UDim2.new(1, -28, 0, listH)

        local rowHeight = cardH < 520 and 25 or 27
        local rowStep = rowHeight + 3
        selector.List.CanvasSize = UDim2.fromOffset(0, #runtime.TargetBodyOrder * rowStep)
        for index, name in ipairs(runtime.TargetBodyOrder) do
            local row = selector.Rows[name]
            if row then
                row.Size = UDim2.new(1, -3, 0, rowHeight)
                row.Position = UDim2.fromOffset(0, (index - 1) * rowStep)
                row.TextSize = 10
            end
        end

        local gap = 7
        local buttonW = math.floor((cardW - 28 - gap * 2) / 3)
        selector.SelectAllButton.Size = UDim2.fromOffset(buttonW, 32)
        selector.SelectAllButton.Position = UDim2.fromOffset(14, actionsY)
        selector.ClearButton.Size = UDim2.fromOffset(buttonW, 32)
        selector.ClearButton.Position = UDim2.fromOffset(14 + buttonW + gap, actionsY)
        selector.DoneButton.Size = UDim2.fromOffset(buttonW, 32)
        selector.DoneButton.Position = UDim2.fromOffset(14 + (buttonW + gap) * 2, actionsY)

        return portraitScale
    end

    runtime.Track(overlay:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
        if overlay.Visible and runtime.BodySelector then
            runtime.ApplyBodySelectorResponsiveLayout()
        end
    end))

    function runtime.BodySelector.Refresh()
        if not runtime.BodySelector then return end
        runtime.RebuildTargetPartNameCache(runtime.BodySelector.Mode)
        local selected = runtime.TargetSelections[runtime.BodySelector.Mode] or {}
        for _, name in ipairs(runtime.TargetBodyOrder) do
            local active = selected[name] == true
            local seg = runtime.BodySelector.Segments[name]
            if seg then
                seg.Button.BackgroundColor3 = active and Color3.fromHex("#E6E9EC") or Color3.fromHex("#24262A")
                seg.Stroke.Color = active and Color3.fromHex("#FFFFFF") or Color3.fromHex("#4B5057")
                seg.Stroke.Transparency = active and 0.05 or 0.35
            end
            local row = runtime.BodySelector.Rows[name]
            if row then
                row.Text = (active and "✓  " or "○  ") .. name
                row.BackgroundColor3 = active and Color3.fromHex("#34373C") or Color3.fromHex("#1C1E21")
                row.TextColor3 = active and Color3.fromHex("#FFFFFF") or Color3.fromHex("#B9BEC5")
            end
        end
    end
end

function runtime.OpenBodySelector(mode)
    runtime.EnsureBodySelector()
    if runtime.BodySelectorGui then
        runtime.BodySelectorGui.DisplayOrder = 2147483647
    end
    runtime.BodySelector.Mode = mode
    runtime.BodySelector.Title.Text = "Selector corporal · " .. (mode == "AutoShoot" and "Auto Shoot" or "Silent Aim")
    runtime.BodySelector.Refresh()
    runtime.BodySelector.Overlay.Visible = true

    local targetScale = runtime.ApplyBodySelectorResponsiveLayout()
    runtime.BodySelector.Scale.Scale = targetScale * 0.965
    runtime.BodySelector.Card.GroupTransparency = 0.12
    TweenService:Create(
        runtime.BodySelector.Scale,
        TweenInfo.new(0.16, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
        {Scale = targetScale}
    ):Play()
    TweenService:Create(
        runtime.BodySelector.Card,
        TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {GroupTransparency = 0}
    ):Play()
end

runtime.AppearanceCatalog = {
    Headless = {Name="Headless Head", Id=134082579, Category="Especiales", Kind="Headless", Badge="OFF-SALE", Desc="Headless local estable"},
    Korblox = {Name="Korblox Right Leg", Id=139607718, Category="Especiales", Kind="Korblox", Badge="OFF-SALE", Desc="Korblox Deathspeaker · reemplazo local R15"},
    HideHair = {Name="Eliminar cabello", Category="Especiales", Kind="HairToggle", Desc="Oculta únicamente el cabello del avatar."},

    RC = {Name="8-Bit Royal Crown", Id=10159600649, Category="8-Bit", Kind="Accessory", Badge="LIMITED"},
    BitTabby = {Name="8-Bit Tabby Cat", Id=10159617728, Category="8-Bit", Kind="Accessory", Badge="LIMITED"},
    BitCoin = {Name="8-Bit Roblox Coin", Id=10159622004, Category="8-Bit", Kind="Accessory", Badge="LIMITED • FX"},
    BitExtraLife = {Name="8-Bit Extra Life", Id=10159606132, Category="8-Bit", Kind="Accessory", Badge="LIMITED • FX"},
    BitHP = {Name="8-Bit HP Bar", Id=10159610478, Category="8-Bit", Kind="Accessory", Badge="LIMITED • FX"},
    BitClockwork = {Name="8-Bit Clockwork Shades", Id=450557238, Category="8-Bit", Kind="Accessory", Badge="LIMITED"},
    BitEyeball = {Name="8-Bit Eyeball", Id=507791112, Category="8-Bit", Kind="Accessory", Badge="LIMITED"},
    BitTentacles = {Name="8-Bit Mr. Tentacles", Id=507795810, Category="8-Bit", Kind="Accessory", Badge="LIMITED • RARE"},
    BitBowler = {Name="8-Bit Rainbow Bowler", Id=323417020, Category="8-Bit", Kind="Accessory", Badge="LIMITED"},
    BitSwordpack = {Name="8-Bit SwordPack", Id=121925647, Category="8-Bit", Kind="Accessory", Badge="LIMITED"},

    FallFairy = {Name="Fall Fairy", Id=128217885, Category="Fairies", Kind="Accessory", Badge="LIMITED • FX"},
    WinterFairy = {Name="Winter Fairy", Id=141742418, Category="Fairies", Kind="Accessory", Badge="LIMITED • FX"},
    PatrickFairy = {Name="St Patrick's Day Fairy", Id=226189871, Category="Fairies", Kind="Accessory", Badge="LIMITED • FX"},
    SpringFairy = {Name="Spring Fairy", Id=150381051, Category="Fairies", Kind="Accessory", Badge="FX"},

    GreenQueen = {Name="Green Queen of the Night", Id=553970961, Category="Queen of the Night", Kind="Accessory", Badge="LIMITED"},
    BlueQueen = {Name="Blue Queen of the Night", Id=553970606, Category="Queen of the Night", Kind="Accessory", Badge="LIMITED"},
    PurpleQueen = {Name="Purple Queen of the Night", Id=553971858, Category="Queen of the Night", Kind="Accessory", Badge="LIMITED • RARE"},
    PinkQueen = {Name="Pink Queen of the Night", Id=553971558, Category="Queen of the Night", Kind="Accessory", Badge="LIMITED • RARE"},
    NavyQueen = {Name="Navy Queen of the Night", Id=501966049, Category="Queen of the Night", Kind="Accessory", Badge="TOY EXCLUSIVE"},

    Fiery = {Name="Fiery Horns of the Netherworld", Id=215718515, Category="Horns", Kind="Accessory", Badge="LIMITED • FX"},
    Poisoned = {Name="Poisoned Horns of the Toxic Wasteland", Id=1744060292, Category="Horns", Kind="Accessory", Badge="LIMITED • FX"},
    Frozen = {Name="Frozen Horns", Id=74891470, Category="Horns", Kind="Accessory", Badge="LIMITED • FX"},
    BlackIronHorns = {Name="Black Iron Horns", Id=628771505, Category="Horns", Kind="Accessory", Badge="LIMITED • CLASSIC"},

    Valk = {Name="Valkyrie Helm", Id=1365767, Category="Valkyries", Kind="Accessory", Badge="LIMITED"},
    SparkleValk = {Name="Sparkle Time Valkyrie", Id=1180433861, Category="Valkyries", Kind="Accessory", Badge="LIMITED U • ULTRA RARE"},
    Blackvalk = {Name="Blackvalk", Id=124730194, Category="Valkyries", Kind="Accessory", Badge="LIMITED • RARE"},
    EmeraldValk = {Name="Emerald Valkyrie", Id=2830437685, Category="Valkyries", Kind="Accessory", Badge="LIMITED • RARE"},
    VioletValk = {Name="Violet Valkyrie", Id=1402432199, Category="Valkyries", Kind="Accessory", Badge="OFF-SALE"},

    ClockworkShades = {Name="Clockwork's Shades", Id=11748356, Category="Clockwork", Kind="Accessory", Badge="LIMITED • CLASSIC"},
    ClockworkHeadphones = {Name="Clockwork's Headphones", Id=1235488, Category="Clockwork", Kind="Accessory", Badge="LIMITED • CLASSIC"},

    DomEmpyreus = {Name="Dominus Empyreus", Id=21070012, Category="Dominus", Kind="Accessory", Badge="LIMITED • RARE"},
    DomInfernus = {Name="Dominus Infernus", Id=31101391, Category="Dominus", Kind="Accessory", Badge="LIMITED • RARE"},
    DomFrigidus = {Name="Dominus Frigidus", Id=48545806, Category="Dominus", Kind="Accessory", Badge="LIMITED • RARE"},
    DomAstra = {Name="Dominus Astra", Id=162067148, Category="Dominus", Kind="Accessory", Badge="LIMITED • RARE"},

    STF = {Name="Sparkle Time Fedora", Id=1285307, Category="Sparkle Time", Kind="Accessory", Badge="LIMITED"},
    RSTF = {Name="Red Sparkle Time Fedora", Id=72082328, Category="Sparkle Time", Kind="Accessory", Badge="LIMITED • RARE"},
    MBSTF = {Name="Midnight Blue STF", Id=119916949, Category="Sparkle Time", Kind="Accessory", Badge="LIMITED • RARE"},
    BSTF = {Name="Black Sparkle Time Fedora", Id=259423244, Category="Sparkle Time", Kind="Accessory", Badge="LIMITED • RARE"},
    PSTF = {Name="Purple Sparkle Time Fedora", Id=63043890, Category="Sparkle Time", Kind="Accessory", Badge="LIMITED • RARE"},
    GSTF = {Name="Green Sparkle Time Fedora", Id=100929604, Category="Sparkle Time", Kind="Accessory", Badge="LIMITED • RARE"},
    TSTF = {Name="Teal Sparkle Time Fedora", Id=147180077, Category="Sparkle Time", Kind="Accessory", Badge="LIMITED • RARE"},
    SBSTF = {Name="Sky Blue Sparkle Time Fedora", Id=493476042, Category="Sparkle Time", Kind="Accessory", Badge="LIMITED • RARE"},
    PISTF = {Name="Pink Sparkle Time Fedora", Id=334663683, Category="Sparkle Time", Kind="Accessory", Badge="LIMITED • RARE"},
    WSTF = {Name="White Sparkle Time Fedora", Id=1016143686, Category="Sparkle Time", Kind="Accessory", Badge="LIMITED"},
    OSTF = {Name="Orange Sparkle Time Fedora", Id=215751161, Category="Sparkle Time", Kind="Accessory", Badge="LIMITED • RARE"},

    Swordpack = {Name="Swordpack", Id=19398258, Category="Espalda", Kind="Accessory", Badge="LIMITED"},
    Daemonshank = {Name="Daemonshank", Id=17521857429, Category="Espalda", Kind="Accessory", Badge="LIMITED"},
    MoltenWings = {Name="Molten Lava Wings", Id=17266515535, Category="Espalda", Kind="Accessory", Badge="LIMITED"},
    Requiem = {Name="The Requiem", Id=107334338147739, Category="Espalda", Kind="Accessory", Badge="LIMITED"},

    KorbloxPauldrons = {Name="Korblox Shoulder Pauldrons", Id=286513125, Category="Hombro", Kind="Accessory", Badge="LIMITED"},
    Raven = {Name="The Raven", Id=20945145, Category="Hombro", Kind="Accessory", Badge="LIMITED"},
    ORLY = {Name="O RLY?", Id=25872570, Category="Hombro", Kind="Accessory", Badge="LIMITED"},
    Headrow = {Name="Headrow", Id=1082935, Category="Hombro", Kind="Accessory", Badge="LIMITED"},
    SparkleBuddy = {Name="RIA 24 Sparkle Buddy", Id=136613436441070, Category="Hombro", Kind="Accessory", Badge="LIMITED"},

    BloxyCreator = {Name="Best Video Content Creator", Id=6736478948, Category="Exclusivos", Kind="Accessory", Badge="BLOXY • OFF-SALE"},
}

runtime.AppearanceOrder = {
    "Headless", "Korblox", "HideHair",
    "RC", "BitTabby", "BitCoin", "BitExtraLife", "BitHP", "BitClockwork", "BitEyeball", "BitTentacles", "BitBowler", "BitSwordpack",
    "FallFairy", "WinterFairy", "PatrickFairy", "SpringFairy",
    "GreenQueen", "BlueQueen", "PurpleQueen", "PinkQueen", "NavyQueen",
    "Fiery", "Poisoned", "Frozen", "BlackIronHorns",
    "Valk", "SparkleValk", "Blackvalk", "EmeraldValk", "VioletValk",
    "ClockworkShades", "ClockworkHeadphones",
    "DomEmpyreus", "DomInfernus", "DomFrigidus", "DomAstra",
    "STF", "RSTF", "MBSTF", "BSTF", "PSTF", "GSTF", "TSTF", "SBSTF", "PISTF", "WSTF", "OSTF",
    "Swordpack", "Daemonshank", "MoltenWings", "Requiem",
    "KorbloxPauldrons", "Raven", "ORLY", "Headrow", "SparkleBuddy",
    "BloxyCreator",
}

runtime.AppearanceCategories = {
    "8-Bit", "Fairies", "Queen of the Night", "Horns", "Valkyries",
    "Clockwork", "Dominus", "Sparkle Time", "Espalda", "Hombro", "Exclusivos"
}

runtime.Appearance = {
    Enabled = {},
    Templates = {},
    ToggleElements = {},
    OriginalHead = setmetatable({}, {__mode = "k"}),
    OriginalKorblox = setmetatable({}, {__mode = "k"}),
    HairVisualCache = setmetatable({}, {__mode = "k"}),

    -- Korblox opcional: por defecto conserva el comportamiento clásico.
    -- El modo Fit crea una pieza visual NO física fuera del rig para evitar
    -- que cuerpos/clones extremos estiren la pierna o afecten la física.
    KorbloxFit = {
        Enabled = false,
        Scale = 1,
        Height = 0,
        Depth = 0,
        Visual = nil,
        Connection = nil,
    },

    -- Clonador de avatar: overlay visual local, sin ApplyDescription.
    -- Headless/Korblox/HideHair/limiteds siguen siendo capas independientes.
    AvatarClone = {
        Active = false,
        KeepOnRespawn = true,
        Applying = false,
        TargetUserId = nil,
        TargetName = nil,
        Template = nil,
        Overlay = nil,
        DriverRig = nil,
        BaseCharacter = nil,
        BaseVisualCache = setmetatable({}, {__mode = "k"}),
        -- Hot-path del clon: listas directas evitan recorrer el hash completo y hacer
        -- búsquedas de ancestros cada RenderStepped. Se actualizan sólo cuando cambia
        -- la topología visual del Character.
        BaseHiddenParts = {},
        BaseHiddenTextures = {},
        BaseHiddenEffects = {},
        BaseHiddenIndex = setmetatable({}, {__mode = "k"}),
        ToolVisualConnections = setmetatable({}, {__mode = "k"}),
        OverlayVisualCache = setmetatable({}, {__mode = "k"}),
        MotorPairs = {},
        -- Transparencia nativa: copiamos al overlay el LTM que CameraModule ya
        -- calcula para el Character real. No hay detección manual de primera persona.
        NativeTransparencyPairs = {},
        NativeEffectPairs = {},
        NativeTransparencyBindName = nil,
        NativeCameraTransparencyLast = nil,
        AnimationConnection = nil,
        RenderAnimationConnection = nil,
        BaseDescendantConnection = nil,
        -- Máscara visual instantánea durante el freeze de inicio de ronda.
        RespawnMaskConnection = nil,
        RespawnMaskDescendantConnection = nil,
        RespawnMaskTopologyConnection = nil,
        RespawnMaskGeneration = nil,
        RespawnMaskPending = false,
        VisualContainer = nil,
        SelectedServerPlayer = nil,
        UsernameInput = "",
    },

    BodyGuardConnections = {},
    AccessoryOffsets = {},
    -- Cachés débiles: evitan buscar el mismo accesorio/weld/attachment en cada tick del slider.
    ActiveAccessories = {},
    AccessoryWeld = setmetatable({}, {__mode = "k"}),
    AccessoryBaseWeld = setmetatable({}, {__mode = "k"}),
    AttachmentCache = setmetatable({}, {__mode = "k"}),
    -- Snapshot visual por clon para escalar sin acumular cambios al mover el slider.
    AccessoryBaseVisual = setmetatable({}, {__mode = "k"}),
    EditorSelectedKey = nil,
    EditorSyncing = false,
    BatchLoading = false,
    RespawnGeneration = 0,
    -- Guard del Character actual: si Roblox reconstruye los accesorios tras respawn,
    -- los visuales de iLunX se reinyectan en el siguiente frame sin polling.
    AccessoryGuardConnections = {},
    AccessoryGuardMutating = {},
    AccessoryGuardPending = false,
    AccessoryGuardCharacter = nil,
    EditorDisplayToKey = {},
    EditorControls = {},
    EditorSlots = {},
}

for _, key in ipairs(runtime.AppearanceOrder) do
    runtime.Appearance.Enabled[key] = false
end

local KORBLOX_UPPER_MESH = "https://assetdelivery.roblox.com/v1/asset/?id=9598310133"
local KORBLOX_TEXTURE = "rbxassetid://902843398"

local function appearanceSafeSet(obj, prop, value)
    if not obj then return end
    pcall(function()
        if obj[prop] ~= value then obj[prop] = value end
    end)
end

function runtime.ClearKorbloxFitVisual()
    local fit = runtime.Appearance and runtime.Appearance.KorbloxFit
    if not fit then return end

    if fit.Connection then
        pcall(function() fit.Connection:Disconnect() end)
        fit.Connection = nil
    end
    if fit.Visual then
        pcall(function() fit.Visual:Destroy() end)
        fit.Visual = nil
    end
end

function runtime.GetKorbloxFitSource()
    local cloneState = runtime.Appearance and runtime.Appearance.AvatarClone
    if cloneState and cloneState.Active then
        local overlay = cloneState.Overlay
        local cloneUpper = overlay and overlay:FindFirstChild("RightUpperLeg")
        if cloneUpper and cloneUpper:IsA("BasePart") then
            return cloneUpper
        end
        -- Si el clon todavía está cambiando/respawneando, no mostramos una
        -- Korblox pegada temporalmente al Character real.
        return nil
    end

    local char = player.Character
    local upper = char and char:FindFirstChild("RightUpperLeg")
    if upper and upper:IsA("BasePart") then return upper end
    return nil
end

function runtime.GetKorbloxFitReferenceSize()
    local char = player.Character
    local snap = char and runtime.Appearance.OriginalKorblox[char]
    if snap and snap.Upper and snap.Upper.Parent then
        return snap.Upper.Size
    end

    local upper = char and char:FindFirstChild("RightUpperLeg")
    if upper and upper:IsA("BasePart") then return upper.Size end
    return Vector3.new(1, 2, 1)
end

function runtime.ComputeKorbloxFitSize(sourceSize, baseSize)
    local fit = runtime.Appearance.KorbloxFit
    baseSize = baseSize or runtime.GetKorbloxFitReferenceSize()
    sourceSize = sourceSize or baseSize

    local safeX = math.max(baseSize.X, 0.05)
    local safeY = math.max(baseSize.Y, 0.05)
    local safeZ = math.max(baseSize.Z, 0.05)

    local widthRatio = ((sourceSize.X / safeX) + (sourceSize.Z / safeZ)) * 0.5
    local heightRatio = sourceSize.Y / safeY

    -- Límites intencionalmente conservadores: skins muy altas/anchas ya no
    -- pueden convertir la Korblox en una pata larguísima. El usuario todavía
    -- puede afinarla con el slider manual.
    widthRatio = math.clamp(widthRatio, 0.82, 1.18)
    heightRatio = math.clamp(heightRatio, 0.82, 1.22)

    local manualScale = math.clamp(tonumber(fit.Scale) or 1, 0.75, 1.35)
    return Vector3.new(
        baseSize.X * widthRatio * manualScale,
        baseSize.Y * heightRatio * manualScale,
        baseSize.Z * widthRatio * manualScale
    )
end

function runtime.UpdateKorbloxFitVisual()
    local fit = runtime.Appearance and runtime.Appearance.KorbloxFit
    if not fit or not fit.Enabled or not runtime.Appearance.Enabled.Korblox then
        return false
    end

    local source = runtime.GetKorbloxFitSource()
    local visual = fit.Visual

    if not source or not source.Parent then
        if visual and visual.Parent then visual.Transparency = 1 end
        return false
    end

    if not visual or not visual.Parent then
        visual = Instance.new("MeshPart")
        visual.Name = "iLunX_KorbloxFitVisual"
        visual.MeshId = KORBLOX_UPPER_MESH
        visual.TextureID = KORBLOX_TEXTURE
        visual.Anchored = true
        visual.CanCollide = false
        visual.CanTouch = false
        visual.CanQuery = false
        visual.Massless = true
        visual.CastShadow = true
        visual.Parent = runtime.GetAvatarCloneVisualContainer()
        fit.Visual = visual
    end

    local baseSize = runtime.GetKorbloxFitReferenceSize()
    local targetSize = runtime.ComputeKorbloxFitSize(source.Size, baseSize)
    local autoHeight = math.clamp((source.Size.Y - targetSize.Y) * 0.5, -0.35, 0.35)
    local manualHeight = math.clamp(tonumber(fit.Height) or 0, -0.65, 0.65)
    local manualDepth = math.clamp(tonumber(fit.Depth) or 0, -0.65, 0.65)

    visual.Size = targetSize
    visual.CFrame = source.CFrame * CFrame.new(0, autoHeight + manualHeight, manualDepth)
    visual.Transparency = 0
    visual.LocalTransparencyModifier = 0
    return true
end

function runtime.EnsureKorbloxFitVisual()
    local fit = runtime.Appearance.KorbloxFit
    if not fit.Enabled or not runtime.Appearance.Enabled.Korblox then
        runtime.ClearKorbloxFitVisual()
        return
    end

    if not fit.Connection then
        fit.Connection = RunService.RenderStepped:Connect(function()
            if runtime.Alive and fit.Enabled and runtime.Appearance.Enabled.Korblox then
                runtime.UpdateKorbloxFitVisual()
            end
        end)
    end
    runtime.UpdateKorbloxFitVisual()
end

function runtime.ClearAppearanceBodyGuards()
    local list = runtime.Appearance.BodyGuardConnections
    for i = #list, 1, -1 do
        pcall(function() list[i]:Disconnect() end)
        list[i] = nil
    end
end

function runtime.GetHeadAppearanceSnapshot(char)
    local snap = runtime.Appearance.OriginalHead[char]
    local head = char and char:FindFirstChild("Head")
    if not head or not head:IsA("BasePart") then return nil end

    if not snap or snap.Head ~= head then
        snap = {
            Head = head,
            Transparency = head.Transparency,
            LocalTransparencyModifier = head.LocalTransparencyModifier,
            Visuals = setmetatable({}, {__mode = "k"}),
        }
        runtime.Appearance.OriginalHead[char] = snap
    end

    return snap
end

function runtime.ApplyHeadlessLayer(char)
    char = char or player.Character
    if not char then return false end
    local snap = runtime.GetHeadAppearanceSnapshot(char)
    if not snap then return false end
    local head = snap.Head

    if runtime.Appearance.Enabled.Headless then
        appearanceSafeSet(head, "Transparency", 1)
        appearanceSafeSet(head, "LocalTransparencyModifier", 1)
        for _, d in ipairs(head:GetDescendants()) do
            if d:IsA("Decal") or d:IsA("Texture") then
                if snap.Visuals[d] == nil then snap.Visuals[d] = d.Transparency end
                appearanceSafeSet(d, "Transparency", 1)
            end
        end
    else
        appearanceSafeSet(head, "Transparency", snap.Transparency)
        appearanceSafeSet(head, "LocalTransparencyModifier", snap.LocalTransparencyModifier)
        for d, old in pairs(snap.Visuals) do
            if d and d.Parent then appearanceSafeSet(d, "Transparency", old) end
        end
        runtime.Appearance.OriginalHead[char] = nil
    end
    return true
end

function runtime.GetKorbloxSnapshot(char)
    local upper = char and char:FindFirstChild("RightUpperLeg")
    local lower = char and char:FindFirstChild("RightLowerLeg")
    local foot = char and char:FindFirstChild("RightFoot")
    if not upper or not upper:IsA("MeshPart") then return nil end

    local snap = runtime.Appearance.OriginalKorblox[char]
    if not snap or snap.Upper ~= upper then
        snap = {
            Upper = upper,
            Lower = lower,
            Foot = foot,
            UpperMeshId = upper.MeshId,
            UpperTextureID = upper.TextureID,
            UpperTransparency = upper.Transparency,
            UpperLTM = upper.LocalTransparencyModifier,
            LowerTransparency = lower and lower.Transparency or nil,
            LowerLTM = lower and lower.LocalTransparencyModifier or nil,
            FootTransparency = foot and foot.Transparency or nil,
            FootLTM = foot and foot.LocalTransparencyModifier or nil,
        }
        runtime.Appearance.OriginalKorblox[char] = snap
    end
    return snap
end

function runtime.ApplyKorbloxLayer(char)
    char = char or player.Character
    if not char then return false end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not humanoid then return false end

    if humanoid.RigType ~= Enum.HumanoidRigType.R15 then
        if runtime.Appearance.Enabled.Korblox then
            showBottomMessage("Korblox local requiere R15.")
        end
        runtime.ClearKorbloxFitVisual()
        return false
    end

    local snap = runtime.GetKorbloxSnapshot(char)
    if not snap then return false end
    local fitEnabled = runtime.Appearance.KorbloxFit.Enabled == true

    if runtime.Appearance.Enabled.Korblox then
        if fitEnabled then
            -- MODO OPCIONAL: no cambiamos el MeshPart corporal. Lo ocultamos y
            -- dibujamos una Korblox externa, anclada y sin física. Así el modo
            -- clásico sigue intacto cuando Auto-ajustar está OFF.
            appearanceSafeSet(snap.Upper, "MeshId", snap.UpperMeshId)
            appearanceSafeSet(snap.Upper, "TextureID", snap.UpperTextureID)
            appearanceSafeSet(snap.Upper, "Transparency", snap.UpperTransparency)
            appearanceSafeSet(snap.Upper, "LocalTransparencyModifier", 1)

            if snap.Lower and snap.Lower.Parent then
                appearanceSafeSet(snap.Lower, "Transparency", snap.LowerTransparency or 0)
                appearanceSafeSet(snap.Lower, "LocalTransparencyModifier", 1)
            end
            if snap.Foot and snap.Foot.Parent then
                appearanceSafeSet(snap.Foot, "Transparency", snap.FootTransparency or 0)
                appearanceSafeSet(snap.Foot, "LocalTransparencyModifier", 1)
            end

            runtime.EnsureKorbloxFitVisual()
        else
            runtime.ClearKorbloxFitVisual()

            -- Comportamiento clásico original.
            appearanceSafeSet(snap.Upper, "MeshId", KORBLOX_UPPER_MESH)
            appearanceSafeSet(snap.Upper, "TextureID", KORBLOX_TEXTURE)
            appearanceSafeSet(snap.Upper, "Transparency", 0)
            appearanceSafeSet(snap.Upper, "LocalTransparencyModifier", 0)

            if snap.Lower and snap.Lower.Parent then
                appearanceSafeSet(snap.Lower, "Transparency", 1)
                appearanceSafeSet(snap.Lower, "LocalTransparencyModifier", 1)
            end
            if snap.Foot and snap.Foot.Parent then
                appearanceSafeSet(snap.Foot, "Transparency", 1)
                appearanceSafeSet(snap.Foot, "LocalTransparencyModifier", 1)
            end
        end
    else
        runtime.ClearKorbloxFitVisual()
        appearanceSafeSet(snap.Upper, "MeshId", snap.UpperMeshId)
        appearanceSafeSet(snap.Upper, "TextureID", snap.UpperTextureID)
        appearanceSafeSet(snap.Upper, "Transparency", snap.UpperTransparency)
        appearanceSafeSet(snap.Upper, "LocalTransparencyModifier", snap.UpperLTM)
        if snap.Lower and snap.Lower.Parent then
            if snap.LowerTransparency ~= nil then appearanceSafeSet(snap.Lower, "Transparency", snap.LowerTransparency) end
            if snap.LowerLTM ~= nil then appearanceSafeSet(snap.Lower, "LocalTransparencyModifier", snap.LowerLTM) end
        end
        if snap.Foot and snap.Foot.Parent then
            if snap.FootTransparency ~= nil then appearanceSafeSet(snap.Foot, "Transparency", snap.FootTransparency) end
            if snap.FootLTM ~= nil then appearanceSafeSet(snap.Foot, "LocalTransparencyModifier", snap.FootLTM) end
        end
        runtime.Appearance.OriginalKorblox[char] = nil
    end
    return true
end

function runtime.EnforceBodyAppearance(char)
    char = char or player.Character
    if not char then return end
    if runtime.Appearance.Enabled.Headless then runtime.ApplyHeadlessLayer(char) end
    if runtime.Appearance.Enabled.Korblox then runtime.ApplyKorbloxLayer(char) end
end

local function appearanceGuard(obj, prop, desired)
    if not obj then return end
    local conn = obj:GetPropertyChangedSignal(prop):Connect(function()
        if not runtime.Alive then return end
        if obj.Parent and obj[prop] ~= desired then
            pcall(function() obj[prop] = desired end)
        end
    end)
    table_insert(runtime.Appearance.BodyGuardConnections, conn)
end

function runtime.RebuildAppearanceBodyGuards(char)
    runtime.ClearAppearanceBodyGuards()
    char = char or player.Character
    if not char then return end

    if runtime.Appearance.Enabled.Headless then
        local head = char:FindFirstChild("Head")
        if head and head:IsA("BasePart") then
            appearanceGuard(head, "Transparency", 1)
            appearanceGuard(head, "LocalTransparencyModifier", 1)
            local childConn = head.DescendantAdded:Connect(function(d)
                if runtime.Appearance.Enabled.Headless and (d:IsA("Decal") or d:IsA("Texture")) then
                    task.defer(function()
                        if d.Parent then appearanceSafeSet(d, "Transparency", 1) end
                    end)
                end
            end)
            table_insert(runtime.Appearance.BodyGuardConnections, childConn)
        end
    end

    if runtime.Appearance.Enabled.Korblox then
        local upper = char:FindFirstChild("RightUpperLeg")
        local lower = char:FindFirstChild("RightLowerLeg")
        local foot = char:FindFirstChild("RightFoot")
        local fitEnabled = runtime.Appearance.KorbloxFit.Enabled == true

        if upper and upper:IsA("MeshPart") then
            if fitEnabled then
                appearanceGuard(upper, "LocalTransparencyModifier", 1)
            else
                appearanceGuard(upper, "Transparency", 0)
                appearanceGuard(upper, "LocalTransparencyModifier", 0)

                -- Duels puede restaurar la pierna normal al volver al lobby sin crear un
                -- Character nuevo. Comparamos el ID numérico porque Roblox normaliza URLs.
                local meshConn = upper:GetPropertyChangedSignal("MeshId"):Connect(function()
                    if not runtime.Alive or not runtime.Appearance.Enabled.Korblox or not upper.Parent then return end
                    if runtime.Appearance.KorbloxFit.Enabled then return end
                    if not string.find(tostring(upper.MeshId), "9598310133", 1, true) then
                        appearanceSafeSet(upper, "MeshId", KORBLOX_UPPER_MESH)
                    end
                end)
                table_insert(runtime.Appearance.BodyGuardConnections, meshConn)

                local textureConn = upper:GetPropertyChangedSignal("TextureID"):Connect(function()
                    if not runtime.Alive or not runtime.Appearance.Enabled.Korblox or not upper.Parent then return end
                    if runtime.Appearance.KorbloxFit.Enabled then return end
                    if not string.find(tostring(upper.TextureID), "902843398", 1, true) then
                        appearanceSafeSet(upper, "TextureID", KORBLOX_TEXTURE)
                    end
                end)
                table_insert(runtime.Appearance.BodyGuardConnections, textureConn)
            end
        end
        if lower and lower:IsA("BasePart") then
            if not fitEnabled then appearanceGuard(lower, "Transparency", 1) end
            appearanceGuard(lower, "LocalTransparencyModifier", 1)
        end
        if foot and foot:IsA("BasePart") then
            if not fitEnabled then appearanceGuard(foot, "Transparency", 1) end
            appearanceGuard(foot, "LocalTransparencyModifier", 1)
        end
        if fitEnabled then runtime.EnsureKorbloxFitVisual() end
    end

    if runtime.Appearance.Enabled.Headless or runtime.Appearance.Enabled.Korblox then
        local conn = char.ChildAdded:Connect(function(child)
            if child.Name == "Head" or child.Name == "RightUpperLeg" or child.Name == "RightLowerLeg" or child.Name == "RightFoot" then
                task.defer(function()
                    if runtime.Alive and char.Parent then
                        runtime.EnforceBodyAppearance(char)
                        runtime.RebuildAppearanceBodyGuards(char)
                    end
                end)
            end
        end)
        table_insert(runtime.Appearance.BodyGuardConnections, conn)
    end
end

function runtime.RemoveAppearanceAccessory(key, char)
    if not char then return end

    -- Evita que el guard de respawn confunda una eliminación intencional
    -- (toggle OFF / reemplazo) con una limpieza hecha por Roblox.
    runtime.Appearance.AccessoryGuardMutating[key] = true

    local cached = runtime.Appearance.ActiveAccessories[key]
    if cached and cached.Parent == char then
        runtime.Appearance.ActiveAccessories[key] = nil
        runtime.Appearance.AccessoryWeld[cached] = nil
        cached:Destroy()
        runtime.Appearance.AccessoryGuardMutating[key] = nil
        return
    end

    runtime.Appearance.ActiveAccessories[key] = nil
    for _, obj in ipairs(char:GetChildren()) do
        if obj:IsA("Accoutrement") and obj:GetAttribute("iLunXAppearanceKey") == key then
            runtime.Appearance.AccessoryWeld[obj] = nil
            obj:Destroy()
        end
    end

    runtime.Appearance.AccessoryGuardMutating[key] = nil
end

function runtime.GetAppearanceTemplate(key)
    local cached = runtime.Appearance.Templates[key]
    if cached then return cached end
    local asset = runtime.AppearanceCatalog[key]
    if not asset or asset.Kind ~= "Accessory" then return nil end

    local ok, objects = pcall(function()
        return game:GetObjects("rbxassetid://" .. tostring(asset.Id))
    end)
    if not ok or type(objects) ~= "table" or #objects == 0 then return nil end

    local template
    for _, root in ipairs(objects) do
        if root:IsA("Accoutrement") then
            template = root:Clone()
        else
            local found = root:FindFirstChildWhichIsA("Accoutrement", true)
            if found then template = found:Clone() end
        end
        if template then break end
    end
    for _, root in ipairs(objects) do pcall(function() root:Destroy() end) end

    if template then
        template.Parent = nil
        runtime.Appearance.Templates[key] = template
    end
    return template
end

local function findAppearanceAttachment(char, name)
    local cache = runtime.Appearance.AttachmentCache[char]
    if not cache then
        cache = {}
        runtime.Appearance.AttachmentCache[char] = cache
        for _, d in ipairs(char:GetDescendants()) do
            if d:IsA("Attachment") and d.Parent and d.Parent:IsA("BasePart") then
                cache[d.Name] = cache[d.Name] or d
            end
        end
    end
    local found = cache[name]
    if found and found.Parent then return found end
    -- Fallback por si el juego reemplazó una pieza/attachment después del snapshot.
    for _, d in ipairs(char:GetDescendants()) do
        if d:IsA("Attachment") and d.Name == name and d.Parent and d.Parent:IsA("BasePart") then
            cache[name] = d
            return d
        end
    end
end

local function manualAttachAppearanceAccessory(char, accessory)
    local handle = accessory and accessory:FindFirstChild("Handle")
    if not handle or not handle:IsA("BasePart") then return false end
    handle.Anchored = false
    handle.CanCollide = false
    handle.CanTouch = false
    handle.CanQuery = false
    handle.Massless = true

    for _, d in ipairs(handle:GetChildren()) do
        if d:IsA("Weld") or d:IsA("WeldConstraint") or d:IsA("Motor6D") then d:Destroy() end
    end

    local ha = handle:FindFirstChildWhichIsA("Attachment")
    if ha then
        local ba = findAppearanceAttachment(char, ha.Name)
        if ba then
            handle.CFrame = ba.Parent.CFrame * ba.CFrame * ha.CFrame:Inverse()
            local weld = Instance.new("Weld")
            weld.Name = "iLunXAppearanceWeld"
            weld.Part0 = handle
            weld.Part1 = ba.Parent
            weld.C0 = ha.CFrame
            weld.C1 = ba.CFrame
            weld.Parent = handle
            return true
        end
    end

    local head = char:FindFirstChild("Head")
    if head and head:IsA("BasePart") then
        local point = CFrame.new()
        pcall(function() point = accessory.AttachmentPoint end)
        handle.CFrame = head.CFrame * point:Inverse()
        local weld = Instance.new("Weld")
        weld.Name = "iLunXAppearanceWeld"
        weld.Part0 = handle
        weld.Part1 = head
        weld.C0 = point
        weld.C1 = CFrame.new()
        weld.Parent = handle
        return true
    end
    return false
end

function runtime.FindAppearanceWeld(accessory)
    if not accessory then return nil end
    local cached = runtime.Appearance.AccessoryWeld[accessory]
    if cached and cached.Parent then return cached end
    local handle = accessory:FindFirstChild("Handle")
    if not handle then return nil end
    local preferred = handle:FindFirstChild("AccessoryWeld") or handle:FindFirstChild("iLunXAppearanceWeld")
    if preferred and preferred:IsA("Weld") then
        runtime.Appearance.AccessoryWeld[accessory] = preferred
        return preferred
    end
    for _, d in ipairs(handle:GetChildren()) do
        if d:IsA("Weld") then
            runtime.Appearance.AccessoryWeld[accessory] = d
            return d
        end
    end
end

function runtime.GetAppearanceOffset(key)
    local state = runtime.Appearance.AccessoryOffsets[key]
    if not state then
        state = {Position = Vector3.new(), Rotation = Vector3.new(), Scale = 1}
        runtime.Appearance.AccessoryOffsets[key] = state
    elseif state.Scale == nil then
        -- Compatibilidad con estados/configs creados antes del slider de tamaño.
        state.Scale = 1
    end
    return state
end

function runtime.ApplyAppearanceScaleToInstance(key, accessory)
    if not accessory or not accessory.Parent then return false end

    local snapshot = runtime.Appearance.AccessoryBaseVisual[accessory]
    if not snapshot then
        snapshot = {
            Parts = setmetatable({}, {__mode = "k"}),
            Meshes = setmetatable({}, {__mode = "k"}),
            LastScale = nil,
        }

        -- Clasificamos una sola vez. Durante el drag ya no buscamos SpecialMesh por pieza.
        for _, obj in ipairs(accessory:GetDescendants()) do
            if obj:IsA("BasePart") then
                local mesh = obj:FindFirstChildOfClass("SpecialMesh")
                if mesh then
                    snapshot.Meshes[mesh] = mesh.Scale
                else
                    snapshot.Parts[obj] = obj.Size
                end
            elseif obj:IsA("SpecialMesh") and snapshot.Meshes[obj] == nil then
                snapshot.Meshes[obj] = obj.Scale
            end
        end

        runtime.Appearance.AccessoryBaseVisual[accessory] = snapshot
    end

    local scale = math.clamp(tonumber(runtime.GetAppearanceOffset(key).Scale) or 1, 0.25, 3)
    if snapshot.LastScale == scale then return true end
    snapshot.LastScale = scale

    for part, baseSize in pairs(snapshot.Parts) do
        if part and part.Parent then part.Size = baseSize * scale end
    end
    for mesh, baseScale in pairs(snapshot.Meshes) do
        if mesh and mesh.Parent then mesh.Scale = baseScale * scale end
    end
    return true
end

function runtime.ApplyAppearanceOffsetToInstance(key, accessory, applyScale)
    if not accessory or not accessory.Parent then return false end
    if applyScale ~= false then runtime.ApplyAppearanceScaleToInstance(key, accessory) end

    local weld = runtime.FindAppearanceWeld(accessory)
    if not weld then
        local char = player.Character
        if char then pcall(function() manualAttachAppearanceAccessory(char, accessory) end) end
        weld = runtime.FindAppearanceWeld(accessory)
    end
    if not weld then return false end

    local base = runtime.Appearance.AccessoryBaseWeld[accessory]
    if not base then
        base = weld.C1
        runtime.Appearance.AccessoryBaseWeld[accessory] = base
    end

    local state = runtime.GetAppearanceOffset(key)
    local p = state.Position
    local r = state.Rotation
    weld.C1 = base
        * CFrame.new(p.X, p.Y, p.Z)
        * CFrame.Angles(math_rad(r.X), math_rad(r.Y), math_rad(r.Z))
    return true
end

function runtime.ApplyAppearanceOffset(key, char, applyScale)
    char = char or player.Character
    if not char then return false end

    local cached = runtime.Appearance.ActiveAccessories[key]
    if cached and cached.Parent == char then
        return runtime.ApplyAppearanceOffsetToInstance(key, cached, applyScale)
    end

    for _, obj in ipairs(char:GetChildren()) do
        if obj:IsA("Accoutrement") and obj:GetAttribute("iLunXAppearanceKey") == key then
            runtime.Appearance.ActiveAccessories[key] = obj
            return runtime.ApplyAppearanceOffsetToInstance(key, obj, applyScale)
        end
    end
    return false
end

function runtime.ApplyAppearanceAccessory(key, char)
    char = char or player.Character
    if not char then return false end
    runtime.RemoveAppearanceAccessory(key, char)
    if not runtime.Appearance.Enabled[key] then return true end

    local humanoid = char:FindFirstChildOfClass("Humanoid")
    local template = runtime.GetAppearanceTemplate(key)
    local asset = runtime.AppearanceCatalog[key]
    if not humanoid or not template or not asset then return false end

    local accessory = template:Clone()
    accessory:SetAttribute("iLunXAppearanceKey", key)

    -- AddAccessory funciona mejor recibiendo el Accessory sin parent. Roblox lo
    -- parenta y crea el weld. Si el rig todavía no está listo, hacemos fallback manual.
    local ok = pcall(function() humanoid:AddAccessory(accessory) end)
    if not ok or accessory.Parent ~= char then
        accessory.Parent = char
        ok = manualAttachAppearanceAccessory(char, accessory)
    end

    if not ok then
        runtime.Appearance.ActiveAccessories[key] = nil
        if accessory.Parent then accessory:Destroy() end
        return false
    end

    runtime.Appearance.ActiveAccessories[key] = accessory

    task.defer(function()
        if not runtime.Alive or accessory.Parent ~= char then return end
        -- Si AddAccessory todavía no generó weld, ApplyAppearanceOffset intenta
        -- adjuntarlo manualmente usando los attachments que ya hayan aparecido.
        runtime.ApplyAppearanceOffsetToInstance(key, accessory, true)
        runtime.EnforceBodyAppearance(char)
    end)
    return true
end

function runtime.ReapplyAppearanceAccessories(char)
    char = char or player.Character
    if not char then return end
    for _, key in ipairs(runtime.AppearanceOrder) do
        local asset = runtime.AppearanceCatalog[key]
        if asset and asset.Kind == "Accessory" and runtime.Appearance.Enabled[key] then
            runtime.ApplyAppearanceAccessory(key, char)
        end
    end
    runtime.EnforceBodyAppearance(char)
end

local function hasEnabledAppearanceAccessory()
    for _, key in ipairs(runtime.AppearanceOrder) do
        local asset = runtime.AppearanceCatalog[key]
        if asset and asset.Kind == "Accessory" and runtime.Appearance.Enabled[key] then
            return true
        end
    end
    return false
end

-- Reaplica únicamente lo que falte. Si el clon existe pero todavía no tiene
-- weld válido, reintenta el attach sobre el mismo clon antes de recrearlo.
function runtime.EnsureAppearanceAccessoryKey(key, char)
    char = char or player.Character
    if not char or not runtime.Appearance.Enabled[key] then return false end

    local current = runtime.Appearance.ActiveAccessories[key]
    if not current or current.Parent ~= char then
        current = nil
        for _, obj in ipairs(char:GetChildren()) do
            if obj:IsA("Accoutrement") and obj:GetAttribute("iLunXAppearanceKey") == key then
                current = obj
                runtime.Appearance.ActiveAccessories[key] = obj
                break
            end
        end
    end

    if current and current.Parent == char then
        if runtime.ApplyAppearanceOffsetToInstance(key, current, true) then
            return true
        end

        runtime.Appearance.AttachmentCache[char] = nil
        if manualAttachAppearanceAccessory(char, current) then
            runtime.Appearance.AccessoryWeld[current] = nil
            return runtime.ApplyAppearanceOffsetToInstance(key, current, true)
        end
        return false
    end

    return runtime.ApplyAppearanceAccessory(key, char)
end



local function isHairAccessory(accessory)
    if not accessory or not accessory:IsA("Accessory") then
        return false
    end

    -- Método moderno
    local isHair = false
    pcall(function()
        isHair = accessory.AccessoryType == Enum.AccessoryType.Hair
    end)

    if isHair then
        return true
    end

    -- Fallback para accesorios antiguos
    local handle = accessory:FindFirstChild("Handle")
    if handle and handle:FindFirstChild("HairAttachment") then
        return true
    end

    return false
end


function runtime.ApplyHairRemoval(char)
    local cache = runtime.Appearance.HairVisualCache
    local enabled = runtime.Appearance.Enabled.HideHair == true

    -- RESTAURAR
    if not enabled then
        for object, original in pairs(cache) do
            if object and object.Parent then
                pcall(function()
                    if original.LocalTransparencyModifier ~= nil
                        and object:IsA("BasePart") then

                        object.LocalTransparencyModifier =
                            original.LocalTransparencyModifier
                    end

                    if original.Enabled ~= nil then
                        object.Enabled = original.Enabled
                    end
                end)
            end

            cache[object] = nil
        end

        return
    end

    -- OCULTAR
    char = char or player.Character
    if not char then return end

    for _, accessory in ipairs(char:GetChildren()) do
        if isHairAccessory(accessory)
            and accessory:GetAttribute("iLunXAppearanceKey") == nil then

            for _, object in ipairs(accessory:GetDescendants()) do

                if object:IsA("BasePart") then

                    if not cache[object] then
                        cache[object] = {
                            LocalTransparencyModifier =
                                object.LocalTransparencyModifier
                        }
                    end

                    object.LocalTransparencyModifier = 1

                elseif object:IsA("ParticleEmitter")
                    or object:IsA("Trail")
                    or object:IsA("Beam") then

                    if not cache[object] then
                        cache[object] = {
                            Enabled = object.Enabled
                        }
                    end

                    object.Enabled = false
                end
            end
        end
    end
end

function runtime.EnsureAppearanceAccessories(char)
    char = char or player.Character
    if not char then return end

    for _, key in ipairs(runtime.AppearanceOrder) do
        local asset = runtime.AppearanceCatalog[key]
        if asset and asset.Kind == "Accessory" and runtime.Appearance.Enabled[key] then
            runtime.EnsureAppearanceAccessoryKey(key, char)
        end
    end

    runtime.EnforceBodyAppearance(char)
end

-- ==========================================
-- CLONADOR DE AVATAR · OVERLAY VISUAL 100% CLIENTE
-- ==========================================
-- IMPORTANTE: no usamos Humanoid:ApplyDescription*(). Esas llamadas pueden estar
-- restringidas al backend del servidor. En su lugar Roblox construye un modelo
-- independiente del avatar y iLunXHub lo sincroniza visualmente sobre el Character.
-- El Character real permanece debajo, por lo que Headless/Korblox/HideHair y los
-- limiteds del hub siguen siendo capas independientes y reversibles.

function runtime.GetHumanoidDescriptionFromUserIdSafe(userId)
    userId = tonumber(userId)
    if not userId or userId <= 0 then return nil, "UserId inválido" end

    local ok, result = pcall(function()
        return Players:GetHumanoidDescriptionFromUserIdAsync(userId)
    end)
    if ok and result then return result end

    ok, result = pcall(function()
        return Players:GetHumanoidDescriptionFromUserId(userId)
    end)
    if ok and result then return result end

    return nil, tostring(result or "No se pudo obtener la apariencia")
end

function runtime.ReapplyAppearanceLayers(char)
    char = char or player.Character
    if not char or not char.Parent then return end

    runtime.EnforceBodyAppearance(char)
    runtime.ApplyHairRemoval(char)
    runtime.EnsureAppearanceAccessories(char)
    runtime.RebuildAppearanceBodyGuards(char)
end

function runtime.PrepareAvatarCloneTemplate(model)
    if not model or not model:IsA("Model") then return nil end

    model.Name = "iLunX_AvatarCloneTemplate"
    model.Archivable = true
    model:SetAttribute("iLunXAvatarClone", true)

    for _, object in ipairs(model:GetDescendants()) do
        if object:IsA("Script") or object:IsA("LocalScript") or object:IsA("ModuleScript")
            or object:IsA("Tool") or object:IsA("ForceField") or object:IsA("BillboardGui") then
            pcall(function() object:Destroy() end)
        elseif object:IsA("BasePart") then
            object.CanCollide = false
            object.CanTouch = false
            object.CanQuery = false
            object.Massless = true
            object.Anchored = false
        end
    end

    local humanoid = model:FindFirstChildOfClass("Humanoid")
    if humanoid then
        pcall(function() humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None end)
        pcall(function() humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff end)
        pcall(function() humanoid.NameDisplayDistance = 0 end)
        pcall(function() humanoid.HealthDisplayDistance = 0 end)
        pcall(function() humanoid.AutoRotate = false end)
        pcall(function() humanoid.PlatformStand = true end)
        pcall(function() humanoid.BreakJointsOnDeath = false end)
        pcall(function() humanoid.RequiresNeck = false end)

        local animator = humanoid:FindFirstChildOfClass("Animator")
        if animator then pcall(function() animator:Destroy() end) end
    end

    return model
end

function runtime.CreateAvatarCloneTemplateFromDescription(description, rigType)
    if not description or not description:IsA("HumanoidDescription") then
        return nil, "Descripción inválida"
    end

    rigType = rigType or Enum.HumanoidRigType.R15
    local ok, model = pcall(function()
        return Players:CreateHumanoidModelFromDescriptionAsync(
            description,
            rigType,
            Enum.AssetTypeVerification.Default
        )
    end)

    if (not ok or not model) then
        ok, model = pcall(function()
            return Players:CreateHumanoidModelFromDescription(
                description,
                rigType,
                Enum.AssetTypeVerification.Default
            )
        end)
    end

    if not ok or not model then
        return nil, tostring(model or "No se pudo construir el avatar")
    end

    return runtime.PrepareAvatarCloneTemplate(model)
end

function runtime.CreateAvatarCloneTemplateFromUserId(userId, rigType)
    userId = tonumber(userId)
    if not userId or userId <= 0 then return nil, "UserId inválido" end

    local description, descriptionError = runtime.GetHumanoidDescriptionFromUserIdSafe(userId)
    if description then
        local model, modelError = runtime.CreateAvatarCloneTemplateFromDescription(description, rigType)
        pcall(function() description:Destroy() end)
        if model then return model end
        descriptionError = modelError or descriptionError
    end

    local ok, model = pcall(function()
        return Players:CreateHumanoidModelFromUserIdAsync(userId)
    end)
    if (not ok or not model) then
        ok, model = pcall(function()
            return Players:CreateHumanoidModelFromUserId(userId)
        end)
    end

    if not ok or not model then
        return nil, tostring(model or descriptionError or "No se pudo construir el avatar")
    end

    local prepared = runtime.PrepareAvatarCloneTemplate(model)
    local sourceHumanoid = prepared and prepared:FindFirstChildOfClass("Humanoid")
    if sourceHumanoid and rigType and sourceHumanoid.RigType ~= rigType then
        pcall(function() prepared:Destroy() end)
        return nil, "El avatar usa un rig incompatible con este personaje"
    end

    return prepared
end

function runtime.AvatarCloneRestoreOverlayVisuals()
    local state = runtime.Appearance.AvatarClone
    for object, original in pairs(state.OverlayVisualCache) do
        if object and object.Parent then
            pcall(function()
                if original.LocalTransparencyModifier ~= nil and object:IsA("BasePart") then
                    object.LocalTransparencyModifier = original.LocalTransparencyModifier
                end
                if original.Transparency ~= nil and (object:IsA("Decal") or object:IsA("Texture")) then
                    object.Transparency = original.Transparency
                end
                if original.Enabled ~= nil then
                    object.Enabled = original.Enabled
                end
            end)
        end
    end
end

function runtime.AvatarCloneCaptureOverlayVisuals(overlay)
    local state = runtime.Appearance.AvatarClone
    state.OverlayVisualCache = setmetatable({}, {__mode = "k"})

    for _, object in ipairs(overlay:GetDescendants()) do
        if object:IsA("BasePart") then
            state.OverlayVisualCache[object] = {
                LocalTransparencyModifier = object.LocalTransparencyModifier,
            }
        elseif object:IsA("Decal") or object:IsA("Texture") then
            state.OverlayVisualCache[object] = {
                Transparency = object.Transparency,
            }
        elseif object:IsA("ParticleEmitter") or object:IsA("Trail") or object:IsA("Beam")
            or object:IsA("Smoke") or object:IsA("Fire") or object:IsA("Sparkles") then
            state.OverlayVisualCache[object] = {
                Enabled = object.Enabled,
            }
        end
    end
end

function runtime.UpdateAvatarCloneLayers()
    local state = runtime.Appearance.AvatarClone
    local overlay = state.Overlay
    if not overlay or not overlay.Parent then return end

    runtime.AvatarCloneRestoreOverlayVisuals()

    if runtime.Appearance.Enabled.Headless then
        local head = overlay:FindFirstChild("Head")
        if head and head:IsA("BasePart") then
            head.LocalTransparencyModifier = 1
            for _, object in ipairs(head:GetDescendants()) do
                if object:IsA("Decal") or object:IsA("Texture") then
                    object.Transparency = 1
                end
            end
        end
    end

    if runtime.Appearance.Enabled.Korblox then
        for _, partName in ipairs({"RightUpperLeg", "RightLowerLeg", "RightFoot"}) do
            local part = overlay:FindFirstChild(partName)
            if part and part:IsA("BasePart") then
                part.LocalTransparencyModifier = 1
            end
        end
    end

    if runtime.Appearance.Enabled.HideHair then
        for _, object in ipairs(overlay:GetChildren()) do
            if isHairAccessory(object) then
                for _, visual in ipairs(object:GetDescendants()) do
                    if visual:IsA("BasePart") then
                        visual.LocalTransparencyModifier = 1
                    elseif visual:IsA("ParticleEmitter") or visual:IsA("Trail") or visual:IsA("Beam")
                        or visual:IsA("Smoke") or visual:IsA("Fire") or visual:IsA("Sparkles") then
                        visual.Enabled = false
                    end
                end
            end
        end
    end
end


-- ==============================================================
-- CLONADOR · TRANSPARENCIA NATIVA DE CÁMARA
-- ==============================================================
-- Roblox CameraModule ya decide cuánto debe desvanecerse el Character en
-- primera persona/zoom. El Character real está oculto por nuestro overlay, así
-- que copiamos ese LocalTransparencyModifier al equivalente visual del clon.
-- No medimos distancia a la cámara, no cambiamos CameraSubject y no guardamos
-- snapshots temporales que puedan pisar Hair/Korblox/Headless.
function runtime.AvatarCloneResolveNativeSourcePart(char, overlay, clonePart)
    if not char or not overlay or not clonePart then return nil, nil end

    if clonePart.Parent == overlay then
        return char:FindFirstChild(clonePart.Name), nil
    end

    local accessory = clonePart:FindFirstAncestorWhichIsA("Accoutrement")
    if accessory and accessory:IsDescendantOf(overlay) then
        local handle = accessory:FindFirstChild("Handle")
        if handle and handle:IsA("BasePart") then
            local preferred = handle:FindFirstChild("AccessoryWeld")
                or handle:FindFirstChild("iLunXAppearanceWeld")

            if preferred and preferred:IsA("Weld") and preferred.Part1 then
                local realPart = char:FindFirstChild(preferred.Part1.Name)
                if realPart and realPart:IsA("BasePart") then
                    return realPart, accessory
                end
            end

            for _, joint in ipairs(handle:GetChildren()) do
                if (joint:IsA("Weld") or joint:IsA("Motor6D")) and joint.Part1 then
                    local realPart = char:FindFirstChild(joint.Part1.Name)
                    if realPart and realPart:IsA("BasePart") then
                        return realPart, accessory
                    end
                end
            end

            local attachment = handle:FindFirstChildWhichIsA("Attachment")
            if attachment then
                for _, bodyPart in ipairs(overlay:GetChildren()) do
                    if bodyPart:IsA("BasePart") and bodyPart:FindFirstChild(attachment.Name) then
                        local realPart = char:FindFirstChild(bodyPart.Name)
                        if realPart and realPart:IsA("BasePart") then
                            return realPart, accessory
                        end
                    end
                end
            end
        end

        local realHead = char:FindFirstChild("Head")
        return realHead and realHead:IsA("BasePart") and realHead or nil, accessory
    end

    local parentPart = clonePart.Parent
    while parentPart and parentPart ~= overlay do
        if parentPart:IsA("BasePart") then
            local realPart = char:FindFirstChild(parentPart.Name)
            if realPart and realPart:IsA("BasePart") then
                return realPart, nil
            end
        end
        parentPart = parentPart.Parent
    end

    return nil, nil
end

function runtime.AvatarCloneBuildNativeTransparencyMap(char, overlay)
    local state = runtime.Appearance.AvatarClone
    table.clear(state.NativeTransparencyPairs)
    table.clear(state.NativeEffectPairs)

    if not char or not char.Parent or not overlay or not overlay.Parent then return false end

    -- CameraModule no necesita leer el LTM del Character real para calcular el fade:
    -- usa únicamente la distancia cámara <-> Focus. Por eso cacheamos sólo los
    -- visuales DEL CLON y conservamos su LTM base para combinarlo con Headless/Korblox.
    for _, object in ipairs(overlay:GetDescendants()) do
        if object:IsA("BasePart") then
            local accessory = object:FindFirstAncestorWhichIsA("Accoutrement")
            local original = state.OverlayVisualCache[object]
            state.NativeTransparencyPairs[#state.NativeTransparencyPairs + 1] = {
                ClonePart = object,
                Accessory = accessory,
                BaseLTM = original and tonumber(original.LocalTransparencyModifier)
                    or tonumber(object.LocalTransparencyModifier)
                    or 0,
            }
        elseif object:IsA("ParticleEmitter") or object:IsA("Trail") or object:IsA("Beam")
            or object:IsA("Smoke") or object:IsA("Fire") or object:IsA("Sparkles") then
            local accessory = object:FindFirstAncestorWhichIsA("Accoutrement")
            local original = state.OverlayVisualCache[object]
            state.NativeEffectPairs[#state.NativeEffectPairs + 1] = {
                Effect = object,
                Accessory = accessory,
                BaseEnabled = original and original.Enabled ~= false or object.Enabled,
            }
        end
    end

    return #state.NativeTransparencyPairs > 0
end

function runtime.AvatarCloneNativeLayerHidden(pair)
    local part = pair and pair.ClonePart
    if not part then return false end

    if runtime.Appearance.Enabled.Headless and part.Name == "Head"
        and part.Parent == runtime.Appearance.AvatarClone.Overlay then
        return true
    end

    if runtime.Appearance.Enabled.Korblox and part.Parent == runtime.Appearance.AvatarClone.Overlay
        and (part.Name == "RightUpperLeg" or part.Name == "RightLowerLeg" or part.Name == "RightFoot") then
        return true
    end

    if runtime.Appearance.Enabled.HideHair and pair.Accessory and isHairAccessory(pair.Accessory) then
        return true
    end

    return false
end

function runtime.AvatarCloneSyncNativeTransparency(char, overlay, dt)
    local state = runtime.Appearance.AvatarClone
    if state.Overlay ~= overlay or not overlay or not overlay.Parent or not char or not char.Parent then return end

    local currentCamera = workspace.CurrentCamera
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    local subject = currentCamera and currentCamera.CameraSubject
    local cameraOwnsCharacter = currentCamera and humanoid and (
        subject == humanoid
        or subject == char
        or (subject and subject:IsDescendantOf(char))
    )

    -- Mismo cálculo usado por TransparencyController de CameraModule.
    -- IMPORTANTE: NO leemos LocalTransparencyModifier del Character real porque
    -- XeroHub lo mantiene en 1 para esconderlo debajo del overlay.
    local transparency = 0
    if cameraOwnsCharacter and currentCamera then
        local distance = (currentCamera.Focus.Position - currentCamera.CFrame.Position).Magnitude
        transparency = (distance < 2) and (1 - (distance - 0.5) / 1.5) or 0
        if transparency < 0.5 then
            transparency = 0
        end

        local last = state.NativeCameraTransparencyLast
        if last ~= nil and transparency < 1 and last < 0.95 then
            local maxDelta = 2.8 * math.max(tonumber(dt) or 0, 0)
            transparency = last + math.clamp(transparency - last, -maxDelta, maxDelta)
        end

        transparency = math.clamp(math.floor(transparency * 100 + 0.5) / 100, 0, 1)
    end

    state.NativeCameraTransparencyLast = transparency

    for i = 1, #state.NativeTransparencyPairs do
        local pair = state.NativeTransparencyPairs[i]
        local clonePart = pair.ClonePart
        if clonePart and clonePart.Parent then
            local layerLTM = runtime.AvatarCloneNativeLayerHidden(pair) and 1
                or math.clamp(tonumber(pair.BaseLTM) or 0, 0, 1)
            local desired = math.max(transparency, layerLTM)
            if clonePart.LocalTransparencyModifier ~= desired then
                clonePart.LocalTransparencyModifier = desired
            end
        end
    end

    for i = 1, #state.NativeEffectPairs do
        local pair = state.NativeEffectPairs[i]
        local effect = pair.Effect
        if effect and effect.Parent then
            local hiddenByLayer = runtime.Appearance.Enabled.HideHair
                and pair.Accessory and isHairAccessory(pair.Accessory)
            local desired = pair.BaseEnabled == true and transparency < 0.95 and not hiddenByLayer
            if effect.Enabled ~= desired then effect.Enabled = desired end
        end
    end
end

function runtime.AvatarCloneBindNativeTransparency(char, overlay)
    local state = runtime.Appearance.AvatarClone
    local oldName = state.NativeTransparencyBindName
    if oldName then
        pcall(function() RunService:UnbindFromRenderStep(oldName) end)
        state.NativeTransparencyBindName = nil
    end

    if not runtime.AvatarCloneBuildNativeTransparencyMap(char, overlay) then return false end

    local bindName = "XeroHub_AvatarCloneNativeTransparency"
    pcall(function() RunService:UnbindFromRenderStep(bindName) end)
    state.NativeTransparencyBindName = bindName
    state.NativeCameraTransparencyLast = nil

    local ok = pcall(function()
        RunService:BindToRenderStep(
            bindName,
            Enum.RenderPriority.Camera.Value + 1,
            function(dt)
                if not runtime.Alive or player.Character ~= char
                    or state.Overlay ~= overlay or not overlay.Parent then
                    return
                end
                runtime.AvatarCloneSyncNativeTransparency(char, overlay, dt)
                -- CameraModule ya terminó de escribir LTM. Reafirmamos el avatar base
                -- aquí, reutilizando ESTE render callback en vez de duplicar el trabajo
                -- dentro del sincronizador de pose.
                runtime.AvatarCloneEnforceBaseHidden(char)
            end
        )
    end)

    if not ok then
        state.NativeTransparencyBindName = nil
        return false
    end

    runtime.AvatarCloneSyncNativeTransparency(char, overlay, 0)
    return true
end

function runtime.AvatarCloneSuspendLocalLayers(char)
    local headless = runtime.Appearance.Enabled.Headless == true
    local korblox = runtime.Appearance.Enabled.Korblox == true
    local hideHair = runtime.Appearance.Enabled.HideHair == true

    if headless then
        runtime.Appearance.Enabled.Headless = false
        runtime.ApplyHeadlessLayer(char)
    end
    if korblox then
        runtime.Appearance.Enabled.Korblox = false
        runtime.ApplyKorbloxLayer(char)
    end
    if hideHair then
        runtime.Appearance.Enabled.HideHair = false
        runtime.ApplyHairRemoval(char)
    end

    return headless, korblox, hideHair
end

function runtime.AvatarCloneResumeLocalLayers(char, headless, korblox, hideHair)
    runtime.Appearance.Enabled.Headless = headless == true
    runtime.Appearance.Enabled.Korblox = korblox == true
    runtime.Appearance.Enabled.HideHair = hideHair == true

    runtime.EnforceBodyAppearance(char)
    runtime.ApplyHairRemoval(char)
end

-- Las armas equipadas también viven dentro del Character. El overlay sólo debe
-- ocultar el avatar base; jamás un Tool ni sus Handles/meshes/efectos.
function runtime.AvatarCloneIsToolVisual(object, char)
    if not object then return false end
    char = char or player.Character

    local tool
    if object:IsA("Tool") then
        tool = object
    else
        tool = object:FindFirstAncestorWhichIsA("Tool")
    end

    return tool ~= nil and (not char or tool:IsDescendantOf(char))
end

function runtime.AvatarCloneResetBaseVisualTracking()
    local state = runtime.Appearance.AvatarClone
    table.clear(state.BaseHiddenParts)
    table.clear(state.BaseHiddenTextures)
    table.clear(state.BaseHiddenEffects)
    state.BaseHiddenIndex = setmetatable({}, {__mode = "k"})
end

function runtime.AvatarCloneTrackHiddenObject(object)
    if not object then return end
    local state = runtime.Appearance.AvatarClone
    if state.BaseHiddenIndex[object] then return end

    local list
    if object:IsA("BasePart") then
        list = state.BaseHiddenParts
    elseif object:IsA("Decal") or object:IsA("Texture") then
        list = state.BaseHiddenTextures
    elseif object:IsA("ParticleEmitter") or object:IsA("Trail") or object:IsA("Beam")
        or object:IsA("Smoke") or object:IsA("Fire") or object:IsA("Sparkles") then
        list = state.BaseHiddenEffects
    end
    if not list then return end

    list[#list + 1] = object
    state.BaseHiddenIndex[object] = {List = list, Index = #list}
end

function runtime.AvatarCloneUntrackHiddenObject(object)
    if not object then return end
    local state = runtime.Appearance.AvatarClone
    local slot = state.BaseHiddenIndex[object]
    if not slot then return end

    local list = slot.List
    local index = slot.Index
    local lastIndex = #list
    local lastObject = list[lastIndex]

    list[index] = lastObject
    list[lastIndex] = nil
    state.BaseHiddenIndex[object] = nil

    if lastObject and lastObject ~= object then
        local lastSlot = state.BaseHiddenIndex[lastObject]
        if lastSlot then lastSlot.Index = index end
    end
end

function runtime.AvatarCloneClearToolVisualGuards()
    local state = runtime.Appearance.AvatarClone
    for tool, bundle in pairs(state.ToolVisualConnections) do
        if bundle then
            if bundle.DescendantAdded then
                pcall(function() bundle.DescendantAdded:Disconnect() end)
            end
            if bundle.AncestryChanged then
                pcall(function() bundle.AncestryChanged:Disconnect() end)
            end
        end
        state.ToolVisualConnections[tool] = nil
    end
end

function runtime.AvatarCloneRestoreCachedVisual(object, cache)
    cache = cache or runtime.Appearance.AvatarClone.BaseVisualCache
    local original = cache and cache[object]
    if not original or not object or not object.Parent then
        if cache and object then cache[object] = nil end
        runtime.AvatarCloneUntrackHiddenObject(object)
        return
    end

    pcall(function()
        if original.LocalTransparencyModifier ~= nil and object:IsA("BasePart") then
            object.LocalTransparencyModifier = original.LocalTransparencyModifier
        end
        if original.Transparency ~= nil and (object:IsA("Decal") or object:IsA("Texture")) then
            object.Transparency = original.Transparency
        end
        if original.Enabled ~= nil then
            object.Enabled = original.Enabled
        end
    end)

    cache[object] = nil
    runtime.AvatarCloneUntrackHiddenObject(object)
end

-- Liberación dirigida: ya no recorremos BaseVisualCache entero por frame. Si se
-- equipa/reparenta un Tool, sólo inspeccionamos ese Tool y restauramos los objetos
-- que realmente estaban cacheados como parte del avatar base.
function runtime.AvatarCloneReleaseToolVisuals(char, specificTool)
    local state = runtime.Appearance.AvatarClone
    local cache = state.BaseVisualCache
    if not cache then return end

    local function releaseObject(object)
        if object and cache[object] then
            runtime.AvatarCloneRestoreCachedVisual(object, cache)
        end
    end

    local function releaseTool(tool)
        if not tool or not tool:IsA("Tool") then return end
        if char and not tool:IsDescendantOf(char) then return end
        releaseObject(tool)
        for _, object in ipairs(tool:GetDescendants()) do
            releaseObject(object)
        end
    end

    if specificTool then
        releaseTool(specificTool)
        return
    end

    char = char or player.Character
    if not char then return end
    for _, child in ipairs(char:GetChildren()) do
        if child:IsA("Tool") then releaseTool(child) end
    end
end

-- Guard 100% event-driven para armas. También cubre el caso raro en el que Duels
-- reparenta una pieza ya cacheada DENTRO de un Tool existente: Tool.DescendantAdded
-- la libera en ese instante, sin un escaneo de todo el cache en RenderStepped.
function runtime.AvatarCloneBindToolVisualGuard(char, tool)
    local state = runtime.Appearance.AvatarClone
    if not char or not tool or not tool:IsA("Tool") or not tool:IsDescendantOf(char) then return end
    if state.ToolVisualConnections[tool] then return end

    local bundle = {}
    state.ToolVisualConnections[tool] = bundle

    runtime.AvatarCloneReleaseToolVisuals(char, tool)

    bundle.DescendantAdded = tool.DescendantAdded:Connect(function(object)
        if state.BaseCharacter ~= char or not state.Active then return end
        if state.BaseVisualCache[object] then
            runtime.AvatarCloneRestoreCachedVisual(object, state.BaseVisualCache)
        end
    end)

    bundle.AncestryChanged = tool.AncestryChanged:Connect(function()
        if tool:IsDescendantOf(char) then return end
        local current = state.ToolVisualConnections[tool]
        if current ~= bundle then return end
        state.ToolVisualConnections[tool] = nil
        if bundle.DescendantAdded then
            pcall(function() bundle.DescendantAdded:Disconnect() end)
        end
        if bundle.AncestryChanged then
            pcall(function() bundle.AncestryChanged:Disconnect() end)
        end
    end)
end

function runtime.AvatarCloneCacheAndHideObject(object, cache)
    if not object or not object.Parent then return end

    -- FIX GUN/KNIFE: Handle, MeshPart, SurfaceAppearance, trails, partículas y
    -- cualquier skin que pertenezca a un Tool equipado deben conservarse visibles.
    if runtime.AvatarCloneIsToolVisual(object, player.Character) then
        runtime.AvatarCloneRestoreCachedVisual(object, cache)
        return
    end

    if cache[object] then
        if object:IsA("BasePart") then
            if runtime.Appearance.Enabled.Korblox and object.Name == "RightUpperLeg"
                and object.Parent == player.Character then
                return
            end
            object.LocalTransparencyModifier = 1
        elseif object:IsA("Decal") or object:IsA("Texture") then
            object.Transparency = 1
        elseif object:IsA("ParticleEmitter") or object:IsA("Trail") or object:IsA("Beam")
            or object:IsA("Smoke") or object:IsA("Fire") or object:IsA("Sparkles") then
            object.Enabled = false
        end
        return
    end

    if object:IsA("BasePart") then
        local originalLTM = object.LocalTransparencyModifier
        local hairOriginal = runtime.Appearance.HairVisualCache[object]
        if hairOriginal and hairOriginal.LocalTransparencyModifier ~= nil then
            originalLTM = hairOriginal.LocalTransparencyModifier
        end
        cache[object] = {LocalTransparencyModifier = originalLTM}
        runtime.AvatarCloneTrackHiddenObject(object)

        if not (runtime.Appearance.Enabled.Korblox and object.Name == "RightUpperLeg"
            and object.Parent == player.Character) then
            object.LocalTransparencyModifier = 1
        end
    elseif object:IsA("Decal") or object:IsA("Texture") then
        cache[object] = {Transparency = object.Transparency}
        runtime.AvatarCloneTrackHiddenObject(object)
        object.Transparency = 1
    elseif object:IsA("ParticleEmitter") or object:IsA("Trail") or object:IsA("Beam")
        or object:IsA("Smoke") or object:IsA("Fire") or object:IsA("Sparkles") then
        local originalEnabled = object.Enabled
        local hairOriginal = runtime.Appearance.HairVisualCache[object]
        if hairOriginal and hairOriginal.Enabled ~= nil then
            originalEnabled = hairOriginal.Enabled
        end
        cache[object] = {Enabled = originalEnabled}
        runtime.AvatarCloneTrackHiddenObject(object)
        object.Enabled = false
    end
end

function runtime.AvatarCloneHideBase(char)
    char = char or player.Character
    if not char or not char.Parent then return false end

    local state = runtime.Appearance.AvatarClone
    if state.BaseCharacter ~= char then
        runtime.AvatarCloneClearToolVisualGuards()
        state.BaseCharacter = char
        state.BaseVisualCache = setmetatable({}, {__mode = "k"})
        runtime.AvatarCloneResetBaseVisualTracking()
    end

    local cache = state.BaseVisualCache
    local firstHide = next(cache) == nil
    local wasHeadless, wasKorblox, wasHideHair

    if firstHide then
        wasHeadless, wasKorblox, wasHideHair = runtime.AvatarCloneSuspendLocalLayers(char)
    end

    for _, child in ipairs(char:GetChildren()) do
        if child:IsA("Tool") then
            -- El arma equipada forma parte del Character, pero NO del avatar base.
            runtime.AvatarCloneBindToolVisualGuard(char, child)
        elseif child:IsA("BasePart") and child.Name ~= "HumanoidRootPart" then
            runtime.AvatarCloneCacheAndHideObject(child, cache)
            for _, visual in ipairs(child:GetDescendants()) do
                if visual:IsA("Decal") or visual:IsA("Texture") then
                    runtime.AvatarCloneCacheAndHideObject(visual, cache)
                end
            end
        elseif child:IsA("Accoutrement") and child:GetAttribute("iLunXAppearanceKey") == nil then
            for _, visual in ipairs(child:GetDescendants()) do
                runtime.AvatarCloneCacheAndHideObject(visual, cache)
            end
        end
    end

    if firstHide then
        runtime.AvatarCloneResumeLocalLayers(char, wasHeadless, wasKorblox, wasHideHair)
    end

    return true
end

function runtime.AvatarCloneRestoreBase(char)
    local state = runtime.Appearance.AvatarClone
    char = char or state.BaseCharacter or player.Character
    if not char then
        runtime.AvatarCloneClearToolVisualGuards()
        state.BaseCharacter = nil
        state.BaseVisualCache = setmetatable({}, {__mode = "k"})
        runtime.AvatarCloneResetBaseVisualTracking()
        return
    end

    local wasHeadless, wasKorblox, wasHideHair = runtime.AvatarCloneSuspendLocalLayers(char)

    for object, original in pairs(state.BaseVisualCache) do
        if object and object.Parent then
            pcall(function()
                if original.LocalTransparencyModifier ~= nil and object:IsA("BasePart") then
                    object.LocalTransparencyModifier = original.LocalTransparencyModifier
                end
                if original.Transparency ~= nil and (object:IsA("Decal") or object:IsA("Texture")) then
                    object.Transparency = original.Transparency
                end
                if original.Enabled ~= nil then
                    object.Enabled = original.Enabled
                end
            end)
        end
    end

    runtime.AvatarCloneClearToolVisualGuards()
    state.BaseCharacter = nil
    state.BaseVisualCache = setmetatable({}, {__mode = "k"})
    runtime.AvatarCloneResetBaseVisualTracking()
    runtime.AvatarCloneResumeLocalLayers(char, wasHeadless, wasKorblox, wasHideHair)
end

function runtime.AvatarCloneDisconnectAnimation()
    local state = runtime.Appearance.AvatarClone
    runtime.AvatarCloneClearToolVisualGuards()
    if state.NativeTransparencyBindName then
        pcall(function() RunService:UnbindFromRenderStep(state.NativeTransparencyBindName) end)
        state.NativeTransparencyBindName = nil
    end
    table.clear(state.NativeTransparencyPairs)
    table.clear(state.NativeEffectPairs)
    state.NativeCameraTransparencyLast = nil
    if state.AnimationConnection then
        pcall(function() state.AnimationConnection:Disconnect() end)
        state.AnimationConnection = nil
    end
    if state.RenderAnimationConnection then
        pcall(function() state.RenderAnimationConnection:Disconnect() end)
        state.RenderAnimationConnection = nil
    end
    if state.BaseDescendantConnection then
        pcall(function() state.BaseDescendantConnection:Disconnect() end)
        state.BaseDescendantConnection = nil
    end
    if state.RespawnMaskConnection then
        pcall(function() state.RespawnMaskConnection:Disconnect() end)
        state.RespawnMaskConnection = nil
    end
    if state.RespawnMaskDescendantConnection then
        pcall(function() state.RespawnMaskDescendantConnection:Disconnect() end)
        state.RespawnMaskDescendantConnection = nil
    end
    if state.RespawnMaskTopologyConnection then
        pcall(function() state.RespawnMaskTopologyConnection:Disconnect() end)
        state.RespawnMaskTopologyConnection = nil
    end
    state.RespawnMaskPending = false
    state.RespawnMaskGeneration = nil
    if state.DriverRig then
        pcall(function() state.DriverRig:Destroy() end)
        state.DriverRig = nil
    end
    table.clear(state.MotorPairs)
end

function runtime.AvatarCloneDestroyOverlay(restoreBase)
    local state = runtime.Appearance.AvatarClone
    runtime.AvatarCloneDisconnectAnimation()

    if state.Overlay then
        pcall(function() state.Overlay:Destroy() end)
        state.Overlay = nil
    end
    state.OverlayVisualCache = setmetatable({}, {__mode = "k"})

    if restoreBase then
        runtime.AvatarCloneRestoreBase(player.Character)
    end
end

function runtime.AvatarCloneEnforceBaseHidden(char)
    local state = runtime.Appearance.AvatarClone
    char = char or state.BaseCharacter or player.Character
    if not char or state.BaseCharacter ~= char then return end

    local cache = state.BaseVisualCache
    local korblox = runtime.Appearance.Enabled.Korblox == true

    -- Hot path: no pairs(BaseVisualCache), no FindFirstAncestorWhichIsA y no pcall
    -- por objeto. Las armas se liberan por eventos en AvatarCloneBindToolVisualGuard.
    local parts = state.BaseHiddenParts
    local i = 1
    while i <= #parts do
        local object = parts[i]
        if not object or not object.Parent or not cache[object] then
            runtime.AvatarCloneUntrackHiddenObject(object)
        else
            if not (korblox
                    and not runtime.Appearance.KorbloxFit.Enabled
                    and object.Name == "RightUpperLeg"
                    and object.Parent == char)
                and object.LocalTransparencyModifier ~= 1 then
                object.LocalTransparencyModifier = 1
            end
            i += 1
        end
    end

    local textures = state.BaseHiddenTextures
    i = 1
    while i <= #textures do
        local object = textures[i]
        if not object or not object.Parent or not cache[object] then
            runtime.AvatarCloneUntrackHiddenObject(object)
        else
            if object.Transparency ~= 1 then object.Transparency = 1 end
            i += 1
        end
    end

    local effects = state.BaseHiddenEffects
    i = 1
    while i <= #effects do
        local object = effects[i]
        if not object or not object.Parent or not cache[object] then
            runtime.AvatarCloneUntrackHiddenObject(object)
        else
            if object.Enabled then object.Enabled = false end
            i += 1
        end
    end
end

function runtime.AvatarCloneBuildMotorSync(char, overlay)
    local state = runtime.Appearance.AvatarClone

    -- HANDOFF SIN CORTE: mientras construimos el rig de referencia dejamos vivo
    -- el sync anterior (la máscara de respawn). Algunas llamadas de avatar pueden
    -- ceder varios frames; desconectarlo aquí arriba era el microcorte al aterrizar.
    local baseHumanoid = char:FindFirstChildOfClass("Humanoid")
    local baseRoot = char:FindFirstChild("HumanoidRootPart")
    local overlayRoot = overlay:FindFirstChild("HumanoidRootPart")
    if not baseHumanoid or not baseRoot or not overlayRoot then
        return false, "El personaje todavía no tiene un rig válido"
    end

    -- --------------------------------------------------------------
    -- DRIVER ESTÁNDAR DE NUESTRO AVATAR
    -- --------------------------------------------------------------
    -- Sólo lo usamos para obtener pivotes estándar si el juego modificó
    -- attachments del Character. Nunca se parenta ni participa en física.
    local driverRig
    local driverError

    local okDescription, baseDescription = pcall(function()
        return baseHumanoid:GetAppliedDescription()
    end)

    if okDescription and baseDescription then
        driverRig, driverError =
            runtime.CreateAvatarCloneTemplateFromDescription(
                baseDescription,
                baseHumanoid.RigType
            )
        pcall(function() baseDescription:Destroy() end)
    end

    if not driverRig then
        driverRig, driverError =
            runtime.CreateAvatarCloneTemplateFromUserId(
                player.UserId,
                baseHumanoid.RigType
            )
    end

    if not driverRig then
        return false, "No se pudo construir el rig de referencia: " .. tostring(driverError or "desconocido")
    end

    -- A partir de aquí no hay yields: hacemos el cambio de máscara -> clon definitivo
    -- de forma atómica dentro del mismo frame.
    runtime.AvatarCloneDisconnectAnimation()
    state.Overlay = overlay
    state.DriverRig = driverRig

    -- --------------------------------------------------------------
    -- FÍSICA DEL OVERLAY
    -- --------------------------------------------------------------
    -- Todas las body parts son coordenadas visuales ancladas. Como el overlay
    -- vive fuera de player.Character, esto no puede empujar al jugador.
    for _, object in ipairs(overlay:GetDescendants()) do
        if object:IsA("BasePart") then
            object.CanCollide = false
            object.CanTouch = false
            object.CanQuery = false
            object.Massless = true
            object.AssemblyLinearVelocity = Vector3.zero
            object.AssemblyAngularVelocity = Vector3.zero

            if object.Parent == overlay then
                object.Anchored = true
            elseif object.Parent and object.Parent:IsA("Accoutrement") then
                -- Los accesorios siguen sus AccessoryWeld sobre la body part.
                object.Anchored = false
            end
        elseif object:IsA("Motor6D") then
            -- Las body parts las colocamos nosotros mediante RigAttachments.
            -- Desactivar joints evita que el solver intente recolocarlas.
            pcall(function() object.Enabled = false end)
        end
    end

    overlayRoot.Anchored = true
    overlayRoot.Transparency = 1
    overlayRoot.LocalTransparencyModifier = 1

    local baseParts = {}
    local cloneParts = {}
    local driverParts = {}

    for _, object in ipairs(char:GetChildren()) do
        if object:IsA("BasePart") then baseParts[object.Name] = object end
    end
    for _, object in ipairs(overlay:GetChildren()) do
        if object:IsA("BasePart") then cloneParts[object.Name] = object end
    end
    for _, object in ipairs(driverRig:GetChildren()) do
        if object:IsA("BasePart") then driverParts[object.Name] = object end
    end

    -- Orden jerárquico. Cada hijo se calcula después de su padre, por lo que
    -- cabeza/brazos/piernas siempre permanecen conectados al bundle clonado.
    local r15Joints = {
        {"HumanoidRootPart", "LowerTorso"},
        {"LowerTorso", "UpperTorso"},
        {"UpperTorso", "Head"},

        {"UpperTorso", "LeftUpperArm"},
        {"LeftUpperArm", "LeftLowerArm"},
        {"LeftLowerArm", "LeftHand"},

        {"UpperTorso", "RightUpperArm"},
        {"RightUpperArm", "RightLowerArm"},
        {"RightLowerArm", "RightHand"},

        {"LowerTorso", "LeftUpperLeg"},
        {"LeftUpperLeg", "LeftLowerLeg"},
        {"LeftLowerLeg", "LeftFoot"},

        {"LowerTorso", "RightUpperLeg"},
        {"RightUpperLeg", "RightLowerLeg"},
        {"RightLowerLeg", "RightFoot"},
    }

    local r6Joints = {
        {"HumanoidRootPart", "Torso"},
        {"Torso", "Head"},
        {"Torso", "Left Arm"},
        {"Torso", "Right Arm"},
        {"Torso", "Left Leg"},
        {"Torso", "Right Leg"},
    }

    local jointSpecs =
        baseHumanoid.RigType == Enum.HumanoidRigType.R15
        and r15Joints
        or r6Joints

    local function findSharedRigAttachment(part0, part1)
        if not part0 or not part1 then return nil, nil end

        for _, object in ipairs(part0:GetChildren()) do
            if object:IsA("Attachment")
                and string.find(object.Name, "RigAttachment", 1, true) then

                local other = part1:FindFirstChild(object.Name)
                if other and other:IsA("Attachment") then
                    return object, other
                end
            end
        end

        return nil, nil
    end

    for _, spec in ipairs(jointSpecs) do
        local parentName = spec[1]
        local childName = spec[2]

        local realParent = baseParts[parentName]
        local realChild = baseParts[childName]
        local cloneParent = cloneParts[parentName]
        local cloneChild = cloneParts[childName]
        local driverParent = driverParts[parentName]
        local driverChild = driverParts[childName]

        if realParent and realChild and cloneParent and cloneChild then
            -- Pivotes del CLON: estos preservan exactamente sus proporciones.
            local cloneA0, cloneA1 =
                findSharedRigAttachment(cloneParent, cloneChild)

            -- Para leer la pose preferimos attachments reales del Character.
            local realA0, realA1 =
                findSharedRigAttachment(realParent, realChild)

            -- Si el juego los quitó/modificó, usamos los del rig estándar.
            local driverA0, driverA1 =
                findSharedRigAttachment(driverParent, driverChild)

            if cloneA0 and cloneA1
                and ((realA0 and realA1) or (driverA0 and driverA1)) then

                table.insert(state.MotorPairs, {
                    RealParent = realParent,
                    RealChild = realChild,
                    CloneParent = cloneParent,
                    CloneChild = cloneChild,

                    CloneC0 = cloneA0.CFrame,
                    CloneC1 = cloneA1.CFrame,
                    CloneC1Inverse = cloneA1.CFrame:Inverse(),

                    RealC0 = realA0 and realA0.CFrame or nil,
                    RealC1 = realA1 and realA1.CFrame or nil,

                    DriverC0 = driverA0 and driverA0.CFrame or nil,
                    DriverC0Inverse = driverA0 and driverA0.CFrame:Inverse() or nil,
                    DriverC1 = driverA1 and driverA1.CFrame or nil,
                })
            end
        end
    end

    -- R6 puede no traer RigAttachments de hombros/caderas. Conservamos un
    -- fallback visual para él; en R15 normalmente entramos por el camino anterior.
    if #state.MotorPairs == 0 and baseHumanoid.RigType == Enum.HumanoidRigType.R6 then
        for _, spec in ipairs(r6Joints) do
            local realParent = baseParts[spec[1]]
            local realChild = baseParts[spec[2]]
            local cloneParent = cloneParts[spec[1]]
            local cloneChild = cloneParts[spec[2]]

            if realParent and realChild and cloneParent and cloneChild then
                table.insert(state.MotorPairs, {
                    RealParent = realParent,
                    RealChild = realChild,
                    CloneParent = cloneParent,
                    CloneChild = cloneChild,
                    R6Fallback = true,
                    InitialRealRelative = realParent.CFrame:ToObjectSpace(realChild.CFrame),
                    InitialRealRelativeInverse = realParent.CFrame:ToObjectSpace(realChild.CFrame):Inverse(),
                    InitialCloneRelative = cloneParent.CFrame:ToObjectSpace(cloneChild.CFrame),
                })
            end
        end
    end

    if #state.MotorPairs == 0 then
        return false, "No se pudieron encontrar pivotes de cuerpo compatibles"
    end

    local function syncPose()
        if not runtime.Alive
            or state.Overlay ~= overlay
            or not overlay.Parent
            or player.Character ~= char then
            return
        end

        -- El root visual sigue exactamente nuestro movimiento global.
        overlayRoot.CFrame = baseRoot.CFrame
        overlayRoot.AssemblyLinearVelocity = Vector3.zero
        overlayRoot.AssemblyAngularVelocity = Vector3.zero

        -- state.MotorPairs ya está en orden raíz -> extremidades.
        for i = 1, #state.MotorPairs do
            local pair = state.MotorPairs[i]

            local realParent = pair.RealParent
            local realChild = pair.RealChild
            local cloneParent = pair.CloneParent
            local cloneChild = pair.CloneChild

            if realParent and realParent.Parent
                and realChild and realChild.Parent
                and cloneParent and cloneParent.Parent
                and cloneChild and cloneChild.Parent then

                pcall(function()
                    if pair.R6Fallback then
                        local currentRelative =
                            realParent.CFrame:ToObjectSpace(realChild.CFrame)

                        local delta =
                            pair.InitialRealRelativeInverse * currentRelative

                        cloneChild.CFrame =
                            cloneParent.CFrame
                            * pair.InitialCloneRelative
                            * delta
                    else
                        local poseTransform

                        if pair.RealC0 and pair.RealC1 then
                            -- Si el Character conserva RigAttachments, ésta es
                            -- la lectura más fiel de la pose visible actual.
                            local parentJointWorld =
                                realParent.CFrame * pair.RealC0
                            local childJointWorld =
                                realChild.CFrame * pair.RealC1

                            poseTransform =
                                parentJointWorld:ToObjectSpace(childJointWorld)
                        else
                            -- El juego quitó sus attachments: usamos pivotes
                            -- estándar del avatar local + CFrames visibles.
                            poseTransform =
                                pair.DriverC0Inverse
                                * realParent.CFrame:Inverse()
                                * realChild.CFrame
                                * pair.DriverC1
                        end

                        -- Ecuación de joint aplicada a LOS PIVOTES DEL CLON:
                        -- P0 * C0 * Transform = P1 * C1
                        cloneChild.CFrame =
                            cloneParent.CFrame
                            * pair.CloneC0
                            * poseTransform
                            * pair.CloneC1Inverse
                    end

                    cloneChild.AssemblyLinearVelocity = Vector3.zero
                    cloneChild.AssemblyAngularVelocity = Vector3.zero
                end)
            end
        end

        -- En condiciones normales la invisibilidad base se reafirma en el bind
        -- Camera+1 de transparencia. Sólo usamos este fallback si ese bind falló.
        if not state.NativeTransparencyBindName then
            runtime.AvatarCloneEnforceBaseHidden(char)
        end
    end

    -- El juego puede terminar su pose tarde en móvil; RenderStepped toma la
    -- posición final que realmente se va a dibujar y actualiza la marioneta.
    state.AnimationConnection = RunService.RenderStepped:Connect(syncPose)

    state.BaseDescendantConnection = char.DescendantAdded:Connect(function(object)
        if state.Overlay ~= overlay or not state.Active then return end
        if object:IsDescendantOf(overlay) then return end

        -- EQUIPPED WEAPON FIX: Character.DescendantAdded también dispara por el
        -- Tool y por TODOS sus descendientes. Nunca los pasamos al hide del avatar.
        local tool = object:IsA("Tool") and object or object:FindFirstAncestorWhichIsA("Tool")
        if tool then
            runtime.AvatarCloneBindToolVisualGuard(char, tool)
            if state.BaseVisualCache[object] then
                runtime.AvatarCloneRestoreCachedVisual(object, state.BaseVisualCache)
            end
            return
        end

        local acc = object:FindFirstAncestorWhichIsA("Accoutrement")
        if acc and acc:GetAttribute("iLunXAppearanceKey") ~= nil then
            return
        end

        if object:IsA("BasePart") then
            if object.Name ~= "HumanoidRootPart" then
                runtime.AvatarCloneCacheAndHideObject(object, state.BaseVisualCache)
            end
        elseif object:IsA("Decal") or object:IsA("Texture")
            or object:IsA("ParticleEmitter") or object:IsA("Trail") or object:IsA("Beam")
            or object:IsA("Smoke") or object:IsA("Fire") or object:IsA("Sparkles") then
            runtime.AvatarCloneCacheAndHideObject(object, state.BaseVisualCache)
        end
    end)

    syncPose()
    return true
end

function runtime.GetAvatarCloneVisualContainer()
    local state = runtime.Appearance.AvatarClone
    local folder = state.VisualContainer

    if folder and folder.Parent then
        return folder
    end

    folder = workspace:FindFirstChild("iLunX_LocalAvatarClones")
    if not folder then
        folder = Instance.new("Folder")
        folder.Name = "iLunX_LocalAvatarClones"
        folder.Parent = workspace
    end

    state.VisualContainer = folder
    return folder
end

function runtime.ApplyAvatarCloneTemplate(char, template)
    char = char or player.Character
    if not char or not char.Parent or not template then
        return false, "Personaje o avatar no disponible"
    end

    local humanoid = char:FindFirstChildOfClass("Humanoid")
    local ownRoot = char:FindFirstChild("HumanoidRootPart")
    if not humanoid or not ownRoot then
        return false, "El personaje todavía no terminó de cargar"
    end

    local state = runtime.Appearance.AvatarClone
    if state.Applying then return false, "Ya se está aplicando otro avatar" end
    state.Applying = true

    -- Conservamos la máscara/overlay anterior hasta que el nuevo clon ya tenga
    -- MotorPairs y pose inicial listos. Así nunca existe un frame entre ambos.
    local previousOverlay = state.Overlay
    local handoffVisualCache = nil

    local ok, result = pcall(function()
        local overlay = template:Clone()
        overlay.Name = "iLunX_AvatarCloneOverlay"
        overlay:SetAttribute("iLunXAvatarClone", true)
        runtime.PrepareAvatarCloneTemplate(overlay)

        local sourceRoot = overlay:FindFirstChild("HumanoidRootPart")
        local sourceHumanoid = overlay:FindFirstChildOfClass("Humanoid")
        if not sourceRoot or not sourceHumanoid then
            overlay:Destroy()
            error("El avatar generado no tiene un rig válido")
        end
        if sourceHumanoid.RigType ~= humanoid.RigType then
            overlay:Destroy()
            error("El rig del avatar no coincide con el personaje actual")
        end

        -- IMPORTANTE: conservamos el Humanoid del clon.
        -- Roblox lo usa para resolver correctamente Shirt/Pants, BodyColors,
        -- CharacterMesh y layered clothing / WrapLayer. Como el overlay vive
        -- fuera de player.Character y todas sus body parts están ancladas,
        -- este Humanoid no participa en la física del jugador real.
        pcall(function()
            sourceHumanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
            sourceHumanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
            sourceHumanoid.NameDisplayDistance = 0
            sourceHumanoid.HealthDisplayDistance = 0
            sourceHumanoid.AutoRotate = false
            sourceHumanoid.PlatformStand = true
            sourceHumanoid.BreakJointsOnDeath = false
            sourceHumanoid.RequiresNeck = false
        end)

        local sourceAnimator = sourceHumanoid:FindFirstChildOfClass("Animator")
        if sourceAnimator then
            pcall(function() sourceAnimator:Destroy() end)
        end

        -- ANTI-FLING DE RESPAWN:
        -- PrepareAvatarCloneTemplate deja las piezas sin Anchored para que el modelo
        -- pueda reutilizar sus welds. Antes de meter el overlay a Workspace las
        -- congelamos TODAS. Así jamás existe ese Heartbeat intermedio en el que el
        -- solver físico puede mover el clon mientras Duels teletransporta/libera al
        -- Character al comenzar una ronda. AvatarCloneBuildMotorSync vuelve a dejar
        -- libres únicamente los handles de accesorios después de fijar el rig visual.
        for _, object in ipairs(overlay:GetDescendants()) do
            if object:IsA("BasePart") then
                object.Anchored = true
                object.CanCollide = false
                object.CanTouch = false
                object.CanQuery = false
                object.Massless = true
                object.AssemblyLinearVelocity = Vector3.zero
                object.AssemblyAngularVelocity = Vector3.zero
            end
        end

        -- Si venimos de la máscara de respawn, el clon nuevo se prepara totalmente
        -- invisible. La máscara vieja sigue animándose mientras Roblox resuelve
        -- clothing/wraps y mientras construimos el rig de referencia.
        if previousOverlay and previousOverlay.Parent then
            handoffVisualCache = setmetatable({}, {__mode = "k"})
            for _, object in ipairs(overlay:GetDescendants()) do
                if object:IsA("BasePart") then
                    handoffVisualCache[object] = {
                        LocalTransparencyModifier = object.LocalTransparencyModifier,
                    }
                    object.LocalTransparencyModifier = 1
                elseif object:IsA("Decal") or object:IsA("Texture") then
                    handoffVisualCache[object] = {Transparency = object.Transparency}
                    object.Transparency = 1
                elseif object:IsA("ParticleEmitter") or object:IsA("Trail") or object:IsA("Beam")
                    or object:IsA("Smoke") or object:IsA("Fire") or object:IsA("Sparkles") then
                    handoffVisualCache[object] = {Enabled = object.Enabled}
                    object.Enabled = false
                end
            end
        end

        -- Nunca vive dentro de player.Character: queda totalmente aislado de
        -- los assemblies y de cualquier script que inspeccione el Character.
        overlay.Parent = runtime.GetAvatarCloneVisualContainer()
        overlay:PivotTo(ownRoot.CFrame)

        -- Un frame para que Roblox resuelva clothing/wraps del modelo ya parentado.
        -- La máscara anterior continúa visible y animada durante esta espera.
        RunService.Heartbeat:Wait()
        if not overlay.Parent then
            error("El avatar visual desapareció durante la carga")
        end

        -- En un handoff el cache original ya se tomó ANTES de esconder el clon
        -- nuevo. En una aplicación normal usamos el capturador habitual.
        if not handoffVisualCache then
            runtime.AvatarCloneCaptureOverlayVisuals(overlay)
        end

        local synced, syncError = runtime.AvatarCloneBuildMotorSync(char, overlay)
        if not synced then
            overlay:Destroy()
            if state.Overlay == overlay then state.Overlay = nil end
            error(syncError or "No se pudo sincronizar la pose del avatar")
        end

        -- BuildMotorSync ya ejecutó syncPose() y no cedió después de desconectar
        -- la máscara. Revelamos el clon definitivo y retiramos el viejo en este
        -- mismo frame: sin pose default, sin flash y sin microcorte al tocar piso.
        if handoffVisualCache then
            state.OverlayVisualCache = handoffVisualCache
            runtime.AvatarCloneRestoreOverlayVisuals()
        end

        if previousOverlay and previousOverlay ~= overlay and previousOverlay.Parent then
            pcall(function() previousOverlay:Destroy() end)
        end

        runtime.ReapplyAppearanceLayers(char)
        runtime.AvatarCloneHideBase(char)
        runtime.UpdateAvatarCloneLayers()
        runtime.AvatarCloneBindNativeTransparency(char, overlay)
    end)

    state.Applying = false

    if not ok then
        runtime.AvatarCloneDestroyOverlay(false)
        if previousOverlay and previousOverlay.Parent then
            pcall(function() previousOverlay:Destroy() end)
        end

        -- Nunca dejamos el Character real oculto si una reaplicación falla.
        -- Antes, durante una reaplicación, el cache podía seguir forzando
        -- LocalTransparencyModifier=1: eso producía el
        -- estado "clon congelado + jugador invisible" hasta clonar otra vez.
        runtime.AvatarCloneRestoreBase(char)
        runtime.ReapplyAppearanceLayers(char)

        return false, tostring(result)
    end

    return true
end

function runtime.SetClonedAvatarTemplate(template, userId, targetName, silent)
    if not template then return false, "No se recibió un avatar válido" end

    local state = runtime.Appearance.AvatarClone
    if state.Applying then return false, "Ya se está aplicando otro avatar" end

    local previousTemplate = state.Template
    local previousUserId = state.TargetUserId
    local previousName = state.TargetName
    local previousActive = state.Active == true

    local ok, err = runtime.ApplyAvatarCloneTemplate(player.Character, template)
    if not ok then
        if previousTemplate then
            pcall(function() runtime.ApplyAvatarCloneTemplate(player.Character, previousTemplate) end)
        end
        pcall(function() template:Destroy() end)
        state.Template = previousTemplate
        state.TargetUserId = previousUserId
        state.TargetName = previousName
        state.Active = previousActive
        return false, err
    end

    state.Template = template
    state.TargetUserId = tonumber(userId)
    state.TargetName = tostring(targetName or userId or "Avatar")
    state.Active = true

    if previousTemplate and previousTemplate ~= template then
        pcall(function() previousTemplate:Destroy() end)
    end

    if runtime.MarkAvatarThumbnailSpoofDirty then
        runtime.MarkAvatarThumbnailSpoofDirty()
    end

    if not silent then
        showBottomMessage("Avatar clonado: " .. state.TargetName)
    end
    return true
end

function runtime.CloneAvatarFromPlayer(targetPlayer, silent)
    if not targetPlayer or not targetPlayer:IsA("Player") then
        return false, "Jugador no válido"
    end

    local char = player.Character
    local ownHumanoid = char and char:FindFirstChildOfClass("Humanoid")
    if not ownHumanoid then return false, "Tu personaje todavía no cargó" end

    local template
    local targetHumanoid = targetPlayer.Character and targetPlayer.Character:FindFirstChildOfClass("Humanoid")
    if targetHumanoid then
        local ok, description = pcall(function()
            return targetHumanoid:GetAppliedDescription()
        end)
        if ok and description then
            template = select(1, runtime.CreateAvatarCloneTemplateFromDescription(description, ownHumanoid.RigType))
            pcall(function() description:Destroy() end)
        end
    end

    if not template then
        local model, err = runtime.CreateAvatarCloneTemplateFromUserId(targetPlayer.UserId, ownHumanoid.RigType)
        if not model then return false, err end
        template = model
    end

    return runtime.SetClonedAvatarTemplate(
        template,
        targetPlayer.UserId,
        targetPlayer.Name,
        silent
    )
end

function runtime.CloneAvatarByUsername(username, silent)
    username = tostring(username or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if username == "" then return false, "Escribe un username" end

    local okId, userId = pcall(function()
        return Players:GetUserIdFromNameAsync(username)
    end)
    if not okId or not userId then
        return false, "No se encontró ese usuario"
    end

    local char = player.Character
    local humanoid = char and char:FindFirstChildOfClass("Humanoid")
    if not humanoid then return false, "Tu personaje todavía no cargó" end

    local template, err = runtime.CreateAvatarCloneTemplateFromUserId(userId, humanoid.RigType)
    if not template then return false, err end

    local resolvedName = username
    pcall(function()
        resolvedName = Players:GetNameFromUserIdAsync(userId)
    end)

    return runtime.SetClonedAvatarTemplate(template, userId, resolvedName, silent)
end

function runtime.RestoreAvatarClone(silent)
    local state = runtime.Appearance.AvatarClone
    if state.Applying then return false, "La apariencia todavía se está aplicando" end

    state.Applying = true
    runtime.AvatarCloneDestroyOverlay(true)

    if state.Template then
        pcall(function() state.Template:Destroy() end)
        state.Template = nil
    end

    state.Active = false
    state.TargetUserId = nil
    state.TargetName = nil
    state.Applying = false

    runtime.ReapplyAppearanceLayers(player.Character)
    if runtime.MarkAvatarThumbnailSpoofDirty then
        runtime.MarkAvatarThumbnailSpoofDirty()
    end

    if not silent then
        showBottomMessage("Tu avatar original fue restaurado.")
    end
    return true
end

-- Mantiene el clon visible desde el primer frame del Character nuevo sin
-- engancharlo todavía a la física/pose del rig. Todas sus piezas quedan ancladas
-- y el modelo completo sólo sigue el CFrame del HumanoidRootPart nuevo.
function runtime.BeginAvatarCloneRespawnMask(char, generation)
    local state = runtime.Appearance.AvatarClone
    if not state or not state.Active or not state.KeepOnRespawn or not state.Template then
        return false
    end
    if not char or not char.Parent then return false end

    if state.RespawnMaskGeneration == generation
        and (state.RespawnMaskPending or state.RespawnMaskConnection) then
        return true
    end

    if state.RespawnMaskConnection then
        pcall(function() state.RespawnMaskConnection:Disconnect() end)
        state.RespawnMaskConnection = nil
    end
    if state.RespawnMaskDescendantConnection then
        pcall(function() state.RespawnMaskDescendantConnection:Disconnect() end)
        state.RespawnMaskDescendantConnection = nil
    end
    if state.RespawnMaskTopologyConnection then
        pcall(function() state.RespawnMaskTopologyConnection:Disconnect() end)
        state.RespawnMaskTopologyConnection = nil
    end

    state.RespawnMaskGeneration = generation
    state.RespawnMaskPending = true

    task.spawn(function()
        local function valid()
            return runtime.Alive
                and char
                and char.Parent
                and player.Character == char
                and state.Active
                and state.KeepOnRespawn
                and state.Template
                and state.RespawnMaskGeneration == generation
                and (not generation or generation == runtime.Appearance.RespawnGeneration)
        end

        if not valid() then
            if state.RespawnMaskGeneration == generation then
                state.RespawnMaskPending = false
            end
            return
        end

        local root = char:FindFirstChild("HumanoidRootPart")
            or char:WaitForChild("HumanoidRootPart", 1.5)
        local humanoid = char:FindFirstChildOfClass("Humanoid")
            or char:WaitForChild("Humanoid", 1.5)

        if not valid() or not root or not root:IsA("BasePart") or not humanoid then
            if state.RespawnMaskGeneration == generation then
                state.RespawnMaskPending = false
            end
            return
        end

        local overlay = state.Overlay
        if not overlay or not overlay.Parent then
            overlay = state.Template:Clone()
            overlay.Name = "iLunX_AvatarCloneOverlay"
            overlay:SetAttribute("iLunXAvatarClone", true)
            runtime.PrepareAvatarCloneTemplate(overlay)

            -- La máscara nace aislada: nunca participa en la física del Character real.
            for _, object in ipairs(overlay:GetDescendants()) do
                if object:IsA("BasePart") then
                    local accessory = object:FindFirstAncestorWhichIsA("Accoutrement")
                    object.Anchored = accessory == nil
                    object.CanCollide = false
                    object.CanTouch = false
                    object.CanQuery = false
                    object.Massless = true
                    object.AssemblyLinearVelocity = Vector3.zero
                    object.AssemblyAngularVelocity = Vector3.zero
                elseif object:IsA("Motor6D") then
                    pcall(function() object.Enabled = false end)
                end
            end

            overlay.Parent = runtime.GetAvatarCloneVisualContainer()
            state.Overlay = overlay
            runtime.AvatarCloneCaptureOverlayVisuals(overlay)
        else
            for _, object in ipairs(overlay:GetDescendants()) do
                if object:IsA("BasePart") then
                    local accessory = object:FindFirstAncestorWhichIsA("Accoutrement")
                    object.Anchored = accessory == nil
                    object.CanCollide = false
                    object.CanTouch = false
                    object.CanQuery = false
                    object.Massless = true
                    object.AssemblyLinearVelocity = Vector3.zero
                    object.AssemblyAngularVelocity = Vector3.zero
                elseif object:IsA("Motor6D") then
                    pcall(function() object.Enabled = false end)
                end
            end
        end

        if not valid() or state.Overlay ~= overlay or not overlay.Parent then
            return
        end

        local overlayRoot = overlay:FindFirstChild("HumanoidRootPart")
        if not overlayRoot or not overlayRoot:IsA("BasePart") then
            if state.RespawnMaskGeneration == generation then
                state.RespawnMaskPending = false
            end
            return
        end
        overlayRoot.Anchored = true
        overlayRoot.Transparency = 1
        overlayRoot.LocalTransparencyModifier = 1

        pcall(function() overlay:PivotTo(root.CFrame) end)

        -- --------------------------------------------------------------
        -- RESPAWN MASK · LIVE MOTOR POSE
        -- --------------------------------------------------------------
        -- Duels reconstruye partes/Motor6D del MISMO Character durante el countdown.
        -- No guardamos referencias a sus piezas: cada frame resolvemos las actuales.
        -- Además usamos Motor6D.Transform directamente, que es la pose que Animator
        -- escribe para caída/idle/salto/caminar incluso durante el freeze inicial.
        local jointSpecs
        if humanoid.RigType == Enum.HumanoidRigType.R15 then
            jointSpecs = {
                {"HumanoidRootPart", "LowerTorso"},
                {"LowerTorso", "UpperTorso"},
                {"UpperTorso", "Head"},

                {"UpperTorso", "LeftUpperArm"},
                {"LeftUpperArm", "LeftLowerArm"},
                {"LeftLowerArm", "LeftHand"},

                {"UpperTorso", "RightUpperArm"},
                {"RightUpperArm", "RightLowerArm"},
                {"RightLowerArm", "RightHand"},

                {"LowerTorso", "LeftUpperLeg"},
                {"LeftUpperLeg", "LeftLowerLeg"},
                {"LeftLowerLeg", "LeftFoot"},

                {"LowerTorso", "RightUpperLeg"},
                {"RightUpperLeg", "RightLowerLeg"},
                {"RightLowerLeg", "RightFoot"},
            }
        else
            jointSpecs = {
                {"HumanoidRootPart", "Torso"},
                {"Torso", "Head"},
                {"Torso", "Left Arm"},
                {"Torso", "Right Arm"},
                {"Torso", "Left Leg"},
                {"Torso", "Right Leg"},
            }
        end

        local function findSharedRigAttachment(part0, part1)
            if not part0 or not part1 then return nil, nil end
            for _, object in ipairs(part0:GetChildren()) do
                if object:IsA("Attachment")
                    and string.find(object.Name, "RigAttachment", 1, true) then

                    local other = part1:FindFirstChild(object.Name)
                    if other and other:IsA("Attachment") then
                        return object, other
                    end
                end
            end
            return nil, nil
        end

        local function findJointMotor(model, part0Name, part1Name)
            for _, object in ipairs(model:GetDescendants()) do
                if object:IsA("Motor6D")
                    and object.Part0 and object.Part1
                    and object.Part0.Name == part0Name
                    and object.Part1.Name == part1Name then
                    return object
                end
            end
            return nil
        end

        -- Sólo cacheamos geometría DEL CLON, porque esa no cambia durante el respawn.
        local cloneJointData = {}
        for i = 1, #jointSpecs do
            local parentName, childName = jointSpecs[i][1], jointSpecs[i][2]
            local cloneParent = overlay:FindFirstChild(parentName)
            local cloneChild = overlay:FindFirstChild(childName)

            if cloneParent and cloneParent:IsA("BasePart")
                and cloneChild and cloneChild:IsA("BasePart") then

                local cloneMotor = findJointMotor(overlay, parentName, childName)
                local cloneC0, cloneC1

                if cloneMotor then
                    cloneC0 = cloneMotor.C0
                    cloneC1 = cloneMotor.C1
                else
                    local a0, a1 = findSharedRigAttachment(cloneParent, cloneChild)
                    if a0 and a1 then
                        cloneC0 = a0.CFrame
                        cloneC1 = a1.CFrame
                    end
                end

                if cloneC0 and cloneC1 then
                    cloneJointData[i] = {
                        ParentName = parentName,
                        ChildName = childName,
                        CloneParent = cloneParent,
                        CloneChild = cloneChild,
                        CloneC0 = cloneC0,
                        CloneC1 = cloneC1,
                        CloneC1Inverse = cloneC1:Inverse(),
                    }
                end
            end
        end

        runtime.AvatarCloneHideBase(char)
        runtime.UpdateAvatarCloneLayers()
        runtime.AvatarCloneBindNativeTransparency(char, overlay)

        -- --------------------------------------------------------------
        -- RESPAWN MASK · EVENT-DRIVEN POSE CACHE
        -- --------------------------------------------------------------
        -- Antes escaneábamos TODOS los descendants y buscábamos 15 partes R15 en
        -- cada RenderStepped. Ahora la topología se resuelve una vez y sólo se
        -- invalida cuando Duels agrega/quita/reemplaza una pieza, attachment o joint.
        local bodyPartNames = {}
        for i = 1, #jointSpecs do
            bodyPartNames[jointSpecs[i][1]] = true
            bodyPartNames[jointSpecs[i][2]] = true
        end

        local posePairs = {}
        local poseCacheDirty = true

        local function isPoseTopologyObject(object)
            if not object then return false end
            if object:IsA("Motor6D") then return true end
            if object:IsA("BasePart") then
                return bodyPartNames[object.Name] == true
            end
            if object:IsA("Attachment")
                and string.find(object.Name, "RigAttachment", 1, true) then
                local parentPart = object.Parent
                return parentPart and parentPart:IsA("BasePart")
                    and bodyPartNames[parentPart.Name] == true
            end
            return false
        end

        local function rebuildRespawnPoseCache()
            if not valid() or state.Overlay ~= overlay or not overlay.Parent then
                return false
            end

            local partsByName = {}
            for _, object in ipairs(char:GetChildren()) do
                if object:IsA("BasePart") and bodyPartNames[object.Name] then
                    partsByName[object.Name] = object
                end
            end

            local liveMotorMap = {}
            for _, object in ipairs(char:GetDescendants()) do
                if object:IsA("Motor6D") and object.Part0 and object.Part1 then
                    liveMotorMap[object.Part0.Name .. ">" .. object.Part1.Name] = object
                end
            end

            local rebuilt = {}
            for i = 1, #jointSpecs do
                local data = cloneJointData[i]
                if data then
                    local realParent = partsByName[data.ParentName]
                    local realChild = partsByName[data.ChildName]
                    local liveMotor = liveMotorMap[data.ParentName .. ">" .. data.ChildName]

                    if liveMotor
                        and (liveMotor.Part0 ~= realParent or liveMotor.Part1 ~= realChild) then
                        liveMotor = nil
                    end

                    if realParent and realChild
                        and data.CloneParent and data.CloneParent.Parent
                        and data.CloneChild and data.CloneChild.Parent then

                        local realC0, realC1
                        if not liveMotor then
                            local realA0, realA1 = findSharedRigAttachment(realParent, realChild)
                            if realA0 and realA1 then
                                realC0 = realA0.CFrame
                                realC1 = realA1.CFrame
                            end
                        end

                        rebuilt[#rebuilt + 1] = {
                            Data = data,
                            RealParent = realParent,
                            RealChild = realChild,
                            LiveMotor = liveMotor,
                            RealC0 = realC0,
                            RealC1 = realC1,
                        }
                    end
                end
            end

            posePairs = rebuilt
            root = partsByName.HumanoidRootPart or root
            poseCacheDirty = false
            return true
        end

        local function hideNewVisual(object)
            if not valid() or state.Overlay ~= overlay then return end
            if object:IsDescendantOf(overlay) then return end

            if isPoseTopologyObject(object) then
                poseCacheDirty = true
            end

            local tool = object:IsA("Tool") and object or object:FindFirstAncestorWhichIsA("Tool")
            if tool then
                runtime.AvatarCloneBindToolVisualGuard(char, tool)
                if state.BaseVisualCache[object] then
                    runtime.AvatarCloneRestoreCachedVisual(object, state.BaseVisualCache)
                end
                return
            end

            local acc = object:FindFirstAncestorWhichIsA("Accoutrement")
            if acc and acc:GetAttribute("iLunXAppearanceKey") ~= nil then
                return
            end

            if object:IsA("BasePart") then
                if object.Name ~= "HumanoidRootPart" then
                    runtime.AvatarCloneCacheAndHideObject(object, state.BaseVisualCache)
                end
            elseif object:IsA("Decal") or object:IsA("Texture")
                or object:IsA("ParticleEmitter") or object:IsA("Trail") or object:IsA("Beam")
                or object:IsA("Smoke") or object:IsA("Fire") or object:IsA("Sparkles") then
                runtime.AvatarCloneCacheAndHideObject(object, state.BaseVisualCache)
            end
        end

        state.RespawnMaskDescendantConnection = char.DescendantAdded:Connect(hideNewVisual)
        state.RespawnMaskTopologyConnection = char.DescendantRemoving:Connect(function(object)
            if isPoseTopologyObject(object) then
                poseCacheDirty = true
            end
        end)

        rebuildRespawnPoseCache()

        state.RespawnMaskConnection = RunService.RenderStepped:Connect(function()
            if not valid() or state.Overlay ~= overlay or not overlay.Parent then
                return
            end

            -- Normalmente esto es falso. Sólo reconstruye el caché cuando Duels
            -- realmente tocó la topología del rig durante el countdown.
            if not poseCacheDirty then
                for i = 1, #posePairs do
                    local pair = posePairs[i]
                    local motor = pair.LiveMotor
                    if not pair.RealParent.Parent
                        or not pair.RealChild.Parent
                        or not pair.Data.CloneParent.Parent
                        or not pair.Data.CloneChild.Parent
                        or (motor and (not motor.Parent
                            or motor.Part0 ~= pair.RealParent
                            or motor.Part1 ~= pair.RealChild)) then
                        poseCacheDirty = true
                        break
                    end
                end
            end

            if poseCacheDirty then
                rebuildRespawnPoseCache()
            end

            if root and root.Parent then
                overlayRoot.CFrame = root.CFrame
                overlayRoot.AssemblyLinearVelocity = Vector3.zero
                overlayRoot.AssemblyAngularVelocity = Vector3.zero
            end

            -- Hot path: sin GetDescendants(), sin FindFirstChild() por joint y sin
            -- construir tablas. Sólo leemos la pose cacheada y actualizamos el clon.
            for i = 1, #posePairs do
                local pair = posePairs[i]
                local data = pair.Data
                local realParent = pair.RealParent
                local realChild = pair.RealChild
                local cloneParent = data.CloneParent
                local cloneChild = data.CloneChild

                pcall(function()
                    local poseTransform
                    local liveMotor = pair.LiveMotor

                    if liveMotor then
                        poseTransform = liveMotor.Transform
                    elseif pair.RealC0 and pair.RealC1 then
                        local parentJointWorld = realParent.CFrame * pair.RealC0
                        local childJointWorld = realChild.CFrame * pair.RealC1
                        poseTransform = parentJointWorld:ToObjectSpace(childJointWorld)
                    end

                    if poseTransform then
                        cloneChild.CFrame = cloneParent.CFrame
                            * data.CloneC0
                            * poseTransform
                            * data.CloneC1Inverse
                    end

                    cloneChild.AssemblyLinearVelocity = Vector3.zero
                    cloneChild.AssemblyAngularVelocity = Vector3.zero
                end)
            end

            if not state.NativeTransparencyBindName then
                runtime.AvatarCloneEnforceBaseHidden(char)
            end
        end)

        state.RespawnMaskPending = false
    end)

    return true
end

function runtime.AvatarCloneResetForRespawn(char, generation)
    local state = runtime.Appearance.AvatarClone

    -- Desconectamos la pose vieja, pero conservamos el overlay si el clon debe
    -- sobrevivir al respawn. Ese mismo overlay cubre el Character nuevo mientras
    -- Duels termina su freeze/teleport interno.
    local keepMask = state.Active
        and state.KeepOnRespawn
        and state.Template
        and state.Overlay
        and state.Overlay.Parent

    runtime.AvatarCloneDisconnectAnimation()
    state.BaseCharacter = nil
    state.BaseVisualCache = setmetatable({}, {__mode = "k"})
    runtime.AvatarCloneResetBaseVisualTracking()

    if keepMask then
        runtime.BeginAvatarCloneRespawnMask(char, generation)
    else
        if state.Overlay then
            pcall(function() state.Overlay:Destroy() end)
            state.Overlay = nil
        end
        state.OverlayVisualCache = setmetatable({}, {__mode = "k"})

        -- Incluso si el overlay anterior ya no existía, podemos crear una máscara
        -- fresca desde el template sin esperar a que termine el countdown.
        if state.Active and state.KeepOnRespawn and state.Template then
            runtime.BeginAvatarCloneRespawnMask(char, generation)
        end
    end
end

function runtime.ClearAppearanceAccessoryGuard()
    local list = runtime.Appearance.AccessoryGuardConnections
    for i = #list, 1, -1 do
        pcall(function() list[i]:Disconnect() end)
        list[i] = nil
    end
    runtime.Appearance.AccessoryGuardPending = false
    runtime.Appearance.AccessoryGuardCharacter = nil
end

function runtime.BindAppearanceAccessoryGuard(char, generation)
    runtime.ClearAppearanceAccessoryGuard()
    if not char or not char.Parent then return end
    runtime.Appearance.AccessoryGuardCharacter = char

    local function queueEnsure()
        if runtime.Appearance.AccessoryGuardPending then return end
        runtime.Appearance.AccessoryGuardPending = true

        task.spawn(function()
            -- Si el lobby limpia la apariencia justo durante un handoff del clon,
            -- no perdemos el evento: esperamos a que termine y reponemos todo.
            local deadline = os.clock() + 2.5
            while runtime.Alive
                and char == player.Character
                and char.Parent
                and (not generation or generation == runtime.Appearance.RespawnGeneration) do

                local cloneState = runtime.Appearance.AvatarClone
                if not (cloneState and cloneState.Applying) then break end
                if os.clock() >= deadline then break end
                RunService.Heartbeat:Wait()
            end

            runtime.Appearance.AccessoryGuardPending = false
            if not runtime.Alive or char ~= player.Character or not char.Parent then return end
            if generation and generation ~= runtime.Appearance.RespawnGeneration then return end

            local cloneState = runtime.Appearance.AvatarClone
            if cloneState and cloneState.Applying then
                task.delay(0.12, queueEnsure)
                return
            end

            runtime.Appearance.AttachmentCache[char] = nil
            runtime.ReapplyAppearanceLayers(char)

            if cloneState and cloneState.Active and cloneState.Overlay and cloneState.Overlay.Parent then
                runtime.AvatarCloneHideBase(char)
                runtime.UpdateAvatarCloneLayers()
                runtime.AvatarCloneBuildNativeTransparencyMap(char, cloneState.Overlay)
            end
        end)
    end

    table_insert(runtime.Appearance.AccessoryGuardConnections, char.ChildRemoved:Connect(function(child)
        if not child:IsA("Accoutrement") then return end
        local key = child:GetAttribute("iLunXAppearanceKey")
        if not key or runtime.Appearance.AccessoryGuardMutating[key] then return end
        if runtime.Appearance.Enabled[key] then
            runtime.Appearance.ActiveAccessories[key] = nil
            queueEnsure()
        end
    end))

    -- Algunos juegos insertan Head/attachments por etapas. En cuanto aparece un
    -- attachment nuevo hacemos una única comprobación en el siguiente frame.
    table_insert(runtime.Appearance.AccessoryGuardConnections, char.DescendantAdded:Connect(function(obj)
        if obj:IsA("Attachment") and hasEnabledAppearanceAccessory() then
            runtime.Appearance.AttachmentCache[char] = nil
            queueEnsure()
        elseif obj:IsA("BasePart")
            and (obj.Name == "Head"
                or obj.Name == "RightUpperLeg"
                or obj.Name == "RightLowerLeg"
                or obj.Name == "RightFoot") then
            queueEnsure()
        end
    end))
end

function runtime.AvatarCloneRigReady(char, humanoid)
    if not char or not humanoid then return false end

    local requiredParts
    if humanoid.RigType == Enum.HumanoidRigType.R15 then
        requiredParts = {
            "HumanoidRootPart", "LowerTorso", "UpperTorso", "Head",
            "LeftUpperArm", "LeftLowerArm", "LeftHand",
            "RightUpperArm", "RightLowerArm", "RightHand",
            "LeftUpperLeg", "LeftLowerLeg", "LeftFoot",
            "RightUpperLeg", "RightLowerLeg", "RightFoot",
        }
    else
        requiredParts = {
            "HumanoidRootPart", "Torso", "Head",
            "Left Arm", "Right Arm", "Left Leg", "Right Leg",
        }
    end

    for i = 1, #requiredParts do
        local part = char:FindFirstChild(requiredParts[i])
        if not part or not part:IsA("BasePart") then
            return false
        end
    end

    return true
end

function runtime.WaitForAvatarCloneRigReady(char, humanoid, generation, maxWait)
    local deadline = os.clock() + (tonumber(maxWait) or 1.5)

    repeat
        if not runtime.Alive
            or not char
            or not char.Parent
            or player.Character ~= char
            or (generation and generation ~= runtime.Appearance.RespawnGeneration) then
            return false
        end

        if runtime.AvatarCloneRigReady(char, humanoid) then
            return true
        end

        RunService.Heartbeat:Wait()
    until os.clock() >= deadline

    return runtime.AvatarCloneRigReady(char, humanoid)
end

-- Espera la salida real de la fase de spawn/teleport de Duels.
-- No modifica el Character: sólo observa que el mismo root permanezca válido y
-- estable durante varios frames antes de construir/reconstruir el overlay.
function runtime.WaitForAvatarCloneSpawnStable(char, humanoid, generation, maxWait)
    local deadline = os.clock() + (tonumber(maxWait) or 6)
    local startedAt = os.clock()
    local stableFrames = 0
    local lastRoot = nil
    local lastPosition = nil

    while runtime.Alive and os.clock() < deadline do
        if not char or not char.Parent or player.Character ~= char
            or (generation and generation ~= runtime.Appearance.RespawnGeneration) then
            return false
        end

        humanoid = humanoid or char:FindFirstChildOfClass("Humanoid")
        local root = char:FindFirstChild("HumanoidRootPart")
        if not humanoid or not root or humanoid.Health <= 0 then
            stableFrames = 0
            RunService.Heartbeat:Wait()
            continue
        end

        local stateType = humanoid:GetState()
        local blockedState =
            stateType == Enum.HumanoidStateType.Dead
            or stateType == Enum.HumanoidStateType.PlatformStanding
            or stateType == Enum.HumanoidStateType.Physics
            or stateType == Enum.HumanoidStateType.FallingDown

        -- Duels deja al jugador suspendido unos segundos antes de soltar la ronda.
        -- Mientras siga anclado, en un estado físico bloqueado o todavía flotando
        -- dentro de esa ventana inicial, NO hacemos el bind definitivo. La máscara
        -- anclada sigue visible sin participar en la física.
        local elapsed = os.clock() - startedAt
        local airborneSpawnWindow =
            humanoid.FloorMaterial == Enum.Material.Air
            and elapsed < 4.5

        local sameRoot = lastRoot == nil or lastRoot == root
        local teleported = false
        if lastPosition and sameRoot then
            teleported = (root.Position - lastPosition).Magnitude > 10
        end

        if root.Anchored or blockedState or airborneSpawnWindow or not sameRoot or teleported then
            stableFrames = 0
        else
            stableFrames += 1
            if stableFrames >= 6 then
                return true
            end
        end

        lastRoot = root
        lastPosition = root.Position
        RunService.Heartbeat:Wait()
    end

    return false
end

function runtime.AvatarCloneIsBoundToCharacter(char)
    local state = runtime.Appearance.AvatarClone
    if not state or not char or state.BaseCharacter ~= char then return false end
    local overlay = state.Overlay
    if not overlay or not overlay.Parent then return false end

    local connectionAlive = false
    if state.AnimationConnection then
        pcall(function()
            connectionAlive = state.AnimationConnection.Connected == true
        end)
    end
    if not connectionAlive or #state.MotorPairs == 0 then return false end

    -- El juego de Duels puede reconstruir piezas del MISMO Character al terminar
    -- el freeze de inicio de ronda. En ese caso RenderStepped sigue conectado,
    -- pero MotorPairs apunta a las piezas viejas y el clon se queda congelado.
    -- Verificamos que cada referencia siga siendo la pieza actual del Character.
    for i = 1, #state.MotorPairs do
        local pair = state.MotorPairs[i]
        local realParent = pair.RealParent
        local realChild = pair.RealChild
        local cloneParent = pair.CloneParent
        local cloneChild = pair.CloneChild

        if not realParent or not realChild or not cloneParent or not cloneChild
            or not realParent.Parent or not realChild.Parent
            or not cloneParent.Parent or not cloneChild.Parent
            or realParent ~= char:FindFirstChild(realParent.Name)
            or realChild ~= char:FindFirstChild(realChild.Name)
            or not cloneParent:IsDescendantOf(overlay)
            or not cloneChild:IsDescendantOf(overlay) then
            return false
        end
    end

    return true
end

function runtime.GuardAvatarCloneAfterRespawn(char, generation)
    -- Primero dejamos que Duels termine SU spawn. Antes este guard podía intentar
    -- reconstruir el overlay cada 0.35 s mientras el jugador seguía suspendido.
    -- Eso hacía coincidir la recreación del rig visual con el teleport/release de
    -- ronda. Ahora no hay ningún apply hasta que el root lleve varios frames estable.
    local humanoid = char and char:FindFirstChildOfClass("Humanoid")
    if not humanoid then
        humanoid = char and char:WaitForChild("Humanoid", 1)
    end
    if not humanoid then return end

    if not runtime.WaitForAvatarCloneSpawnStable(char, humanoid, generation, 7) then
        return
    end

    local deadline = os.clock() + 6
    local nextRetryAt = 0

    while runtime.Alive
        and char
        and char.Parent
        and player.Character == char
        and (not generation or generation == runtime.Appearance.RespawnGeneration)
        and os.clock() < deadline do

        local state = runtime.Appearance.AvatarClone
        if not state.Active or not state.KeepOnRespawn or not state.Template then
            return
        end

        if not runtime.AvatarCloneIsBoundToCharacter(char)
            and not state.Applying
            and os.clock() >= nextRetryAt then

            nextRetryAt = os.clock() + 0.45

            -- Si Duels reemplazó una pieza del rig incluso después de soltar la
            -- ronda, exigimos otra mini ventana estable antes del rebind.
            if runtime.WaitForAvatarCloneRigReady(char, humanoid, generation, 0.8)
                and runtime.WaitForAvatarCloneSpawnStable(char, humanoid, generation, 1.2) then

                -- Conservamos la máscara hasta que el nuevo overlay esté listo.
                local ok = runtime.ApplyAvatarCloneTemplate(char, state.Template)
                if not ok then
                    runtime.AvatarCloneRestoreBase(char)
                    runtime.ReapplyAppearanceLayers(char)
                end
            end
        end

        task.wait(0.18)
    end
end

function runtime.FastRestoreAppearanceOnRespawn(char, generation)
    if not runtime.Alive or not char or not char.Parent then return end

    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not humanoid then
        humanoid = char:WaitForChild("Humanoid", 0.35)
    end
    if not runtime.Alive or not humanoid or not char.Parent then return end
    if generation and generation ~= runtime.Appearance.RespawnGeneration then return end

    if runtime.Appearance.Enabled.Headless or hasEnabledAppearanceAccessory() then
        if not char:FindFirstChild("Head") then
            char:WaitForChild("Head", 0.35)
        end
    end
    if runtime.Appearance.Enabled.Korblox and humanoid.RigType == Enum.HumanoidRigType.R15 then
        if not char:FindFirstChild("RightUpperLeg") then
            char:WaitForChild("RightUpperLeg", 0.35)
        end
    end

    if not runtime.Alive or not char.Parent then return end
    if generation and generation ~= runtime.Appearance.RespawnGeneration then return end

    local cloneState = runtime.Appearance.AvatarClone
    if cloneState.Active
        and cloneState.KeepOnRespawn
        and cloneState.Template then

        -- Durante el freeze de inicio NO mostramos el Character real. Una máscara
        -- visual 100% anclada sigue al root desde el primer frame, mientras el apply
        -- definitivo espera a que el rig/teleport de Duels estén estables.
        runtime.BeginAvatarCloneRespawnMask(char, generation)

        if not runtime.WaitForAvatarCloneRigReady(char, humanoid, generation, 1.8) then
            return
        end
        if not runtime.WaitForAvatarCloneSpawnStable(char, humanoid, generation, 7) then
            return
        end
    end

    if cloneState.Active
        and cloneState.KeepOnRespawn
        and cloneState.Template
        and not cloneState.Applying then

        local ok = runtime.ApplyAvatarCloneTemplate(char, cloneState.Template)
        if not ok then
            runtime.AvatarCloneRestoreBase(char)
            runtime.ReapplyAppearanceLayers(char)
        end
        if generation and generation ~= runtime.Appearance.RespawnGeneration then return end
    else
        runtime.ReapplyAppearanceLayers(char)
    end
end

function runtime.SetAppearance(key, state)
    local asset = runtime.AppearanceCatalog[key]
    if not asset then return end
    runtime.Appearance.Enabled[key] = state == true
    local char = player.Character

    if asset.Kind == "Headless" then
    runtime.ApplyHeadlessLayer(char)
    runtime.EnforceBodyAppearance(char)
    runtime.RebuildAppearanceBodyGuards(char)

    elseif asset.Kind == "Korblox" then
        runtime.ApplyKorbloxLayer(char)
        runtime.EnforceBodyAppearance(char)
        runtime.RebuildAppearanceBodyGuards(char)

    elseif asset.Kind == "HairToggle" then
        runtime.ApplyHairRemoval(char)

    else
        local ok = runtime.ApplyAppearanceAccessory(key, char)
        if state and not ok then
            showBottomMessage("No se pudo cargar " .. asset.Name .. ".")
            runtime.Appearance.Enabled[key] = false
            local toggle = runtime.Appearance.ToggleElements[key]
            if toggle then task.defer(function() pcall(function() toggle:Set(false) end) end) end
        end
    end

    local cloneState = runtime.Appearance.AvatarClone
    if cloneState and cloneState.Active and cloneState.Overlay and cloneState.Overlay.Parent then
        runtime.AvatarCloneHideBase(char)
        runtime.UpdateAvatarCloneLayers()
    end

    if not runtime.Appearance.BatchLoading and runtime.RefreshAppearanceEditor then runtime.RefreshAppearanceEditor() end
    if runtime.RefreshAppearanceStudio then
        task.defer(runtime.RefreshAppearanceStudio)
    end
    if runtime.MarkAvatarThumbnailSpoofDirty then
        runtime.MarkAvatarThumbnailSpoofDirty()
    end
end

function runtime.RestoreAppearance()
    for key in pairs(runtime.Appearance.Enabled) do runtime.Appearance.Enabled[key] = false end

    local cloneState = runtime.Appearance.AvatarClone
    if cloneState and cloneState.Active and runtime.RestoreAvatarClone then
        pcall(function() runtime.RestoreAvatarClone(true) end)
    end

    local char = player.Character
    if char then
        for _, key in ipairs(runtime.AppearanceOrder) do
            local asset = runtime.AppearanceCatalog[key]
            if asset and asset.Kind == "Accessory" then runtime.RemoveAppearanceAccessory(key, char) end
        end
        runtime.ApplyHeadlessLayer(char)
        runtime.ApplyKorbloxLayer(char)
        runtime.ApplyHairRemoval(char)
    end
    runtime.ClearAppearanceBodyGuards()
    table.clear(runtime.Appearance.AccessoryOffsets)
    table.clear(runtime.Appearance.ActiveAccessories)
    runtime.Appearance.EditorSelectedKey = nil
    if runtime.RefreshAppearanceStudio then
        task.defer(runtime.RefreshAppearanceStudio)
    end
    if runtime.MarkAvatarThumbnailSpoofDirty then
        runtime.MarkAvatarThumbnailSpoofDirty()
    end
end

function runtime.SerializeAppearanceConfig()
    local enabled = {}
    for key, state in pairs(runtime.Appearance.Enabled) do enabled[key] = state == true end
    local offsets = {}
    for key, state in pairs(runtime.Appearance.AccessoryOffsets) do
        offsets[key] = {
            X = state.Position.X, Y = state.Position.Y, Z = state.Position.Z,
            RX = state.Rotation.X, RY = state.Rotation.Y, RZ = state.Rotation.Z,
            Scale = tonumber(state.Scale) or 1,
        }
    end
    local fit = runtime.Appearance.KorbloxFit
    return {
        Enabled = enabled,
        Offsets = offsets,
        KorbloxFit = {
            Enabled = fit.Enabled == true,
            Scale = tonumber(fit.Scale) or 1,
            Height = tonumber(fit.Height) or 0,
            Depth = tonumber(fit.Depth) or 0,
        },
        -- compatibilidad con configs anteriores
        Korblox = enabled.Korblox,
        RC = enabled.RC,
        Fiery = enabled.Fiery,
        Poisoned = enabled.Poisoned,
    }
end

function runtime.LoadAppearanceConfig(data)
    if type(data) ~= "table" then return end
    table.clear(runtime.Appearance.AccessoryOffsets)
    if type(data.Offsets) == "table" then
        for key, value in pairs(data.Offsets) do
            if type(value) == "table" and runtime.AppearanceCatalog[key] then
                runtime.Appearance.AccessoryOffsets[key] = {
                    Position = Vector3.new(tonumber(value.X) or 0, tonumber(value.Y) or 0, tonumber(value.Z) or 0),
                    Rotation = Vector3.new(tonumber(value.RX) or 0, tonumber(value.RY) or 0, tonumber(value.RZ) or 0),
                    Scale = math.clamp(tonumber(value.Scale) or 1, 0.25, 3),
                }
            end
        end
    end

    local fit = runtime.Appearance.KorbloxFit
    if type(data.KorbloxFit) == "table" then
        fit.Enabled = data.KorbloxFit.Enabled == true
        fit.Scale = math.clamp(tonumber(data.KorbloxFit.Scale) or 1, 0.75, 1.35)
        fit.Height = math.clamp(tonumber(data.KorbloxFit.Height) or 0, -0.65, 0.65)
        fit.Depth = math.clamp(tonumber(data.KorbloxFit.Depth) or 0, -0.65, 0.65)
    end

    local desired = {}
    if type(data.Enabled) == "table" then
        for key in pairs(runtime.AppearanceCatalog) do desired[key] = data.Enabled[key] == true end
    else
        for key in pairs(runtime.AppearanceCatalog) do desired[key] = false end
        desired.Korblox = data.Korblox == true
        desired.RC = data.RC == true
        desired.Fiery = data.Fiery == true
        desired.Poisoned = data.Poisoned == true
    end

    local wasSuppressed = runtime.SuppressNotifications
    runtime.SuppressNotifications = true
    runtime.Appearance.BatchLoading = true
    for _, key in ipairs(runtime.AppearanceOrder) do
        local wanted = desired[key] == true
        local current = runtime.Appearance.Enabled[key] == true
        if current ~= wanted then
            local toggle = runtime.Appearance.ToggleElements[key]
            if toggle then
                pcall(function() toggle:Set(wanted) end)
            else
                runtime.SetAppearance(key, wanted)
            end
        elseif wanted then
            -- Mismo toggle, nuevos offsets: actualiza sin destruir/reclonar el accesorio.
            local asset = runtime.AppearanceCatalog[key]
            if asset and asset.Kind == "Accessory" then
                runtime.ApplyAppearanceOffset(key, nil, true)
            elseif asset and asset.Kind == "HairToggle" then
                runtime.ApplyHairRemoval(player.Character)
            else
                runtime.EnforceBodyAppearance(player.Character)
            end
        end
    end
    if UIElements.TogKorbloxFit then pcall(function() UIElements.TogKorbloxFit:Set(fit.Enabled, true) end) end
    if UIElements.SliKorbloxFitScale then pcall(function() UIElements.SliKorbloxFitScale:Set(fit.Scale, true) end) end
    if UIElements.SliKorbloxFitHeight then pcall(function() UIElements.SliKorbloxFitHeight:Set(fit.Height, true) end) end
    if UIElements.SliKorbloxFitDepth then pcall(function() UIElements.SliKorbloxFitDepth:Set(fit.Depth, true) end) end

    if runtime.Appearance.Enabled.Korblox then
        runtime.ApplyKorbloxLayer(player.Character)
        runtime.RebuildAppearanceBodyGuards(player.Character)
        runtime.UpdateAvatarCloneLayers()
    else
        runtime.ClearKorbloxFitVisual()
    end

    runtime.Appearance.BatchLoading = false
    runtime.SuppressNotifications = wasSuppressed

    if runtime.RefreshAppearanceEditor then runtime.RefreshAppearanceEditor() end
    if runtime.MarkAvatarThumbnailSpoofDirty then
        runtime.MarkAvatarThumbnailSpoofDirty()
    end
end

runtime.AppearanceCleanup = function()
    pcall(runtime.RestoreAppearance)
    runtime.ClearKorbloxFitVisual()
    runtime.ClearAppearanceBodyGuards()
    runtime.ClearAppearanceAccessoryGuard()

    local cloneState = runtime.Appearance.AvatarClone
    if cloneState then
        pcall(function() runtime.AvatarCloneDestroyOverlay(true) end)
        if cloneState.Template then
            pcall(function() cloneState.Template:Destroy() end)
            cloneState.Template = nil
        end
        cloneState.Active = false
        cloneState.TargetUserId = nil
        cloneState.TargetName = nil

        if cloneState.VisualContainer and cloneState.VisualContainer.Parent then
            pcall(function() cloneState.VisualContainer:Destroy() end)
        end
        cloneState.VisualContainer = nil
    end

    for key, template in pairs(runtime.Appearance.Templates) do
        pcall(function() template:Destroy() end)
        runtime.Appearance.Templates[key] = nil
    end
end

runtime.Track(player.CharacterAdded:Connect(function(char)
    runtime.Appearance.RespawnGeneration = (runtime.Appearance.RespawnGeneration or 0) + 1
    local generation = runtime.Appearance.RespawnGeneration
    runtime.Appearance.AttachmentCache[char] = nil
    table.clear(runtime.Appearance.ActiveAccessories)

    local cloneState = runtime.Appearance.AvatarClone
    runtime.AvatarCloneResetForRespawn(char, generation)
    if cloneState.Active and not cloneState.KeepOnRespawn then
        cloneState.Active = false
        cloneState.TargetUserId = nil
        cloneState.TargetName = nil
        if cloneState.Template then
            pcall(function() cloneState.Template:Destroy() end)
            cloneState.Template = nil
        end
    end

    -- El guard entra desde el primer frame: si Roblox limpia un limited mientras
    -- termina de construir el avatar, se repone sin esperar un timer fijo.
    runtime.BindAppearanceAccessoryGuard(char, generation)

    task.spawn(function()
        runtime.FastRestoreAppearanceOnRespawn(char, generation)

        -- El primer apply puede coincidir con el freeze/teleport de inicio de ronda.
        -- La guardia de 10 s corrige cualquier reconstrucción tardía sin que el
        -- usuario tenga que pulsar "Clonar" de nuevo.
        runtime.GuardAvatarCloneAfterRespawn(char, generation)
    end)
end))

pcall(function()
    runtime.Track(player.CharacterAppearanceLoaded:Connect(function(char)
        if char ~= player.Character then return end
        local generation = runtime.Appearance.RespawnGeneration
        runtime.Appearance.AttachmentCache[char] = nil

        task.defer(function()
            if runtime.Alive and char.Parent and generation == runtime.Appearance.RespawnGeneration then
                local cloneState = runtime.Appearance.AvatarClone
                if cloneState.Active
                    and cloneState.KeepOnRespawn
                    and cloneState.Template
                    and not cloneState.Applying then

                    -- El overlay NO es hijo del Character; vive en
                    -- iLunX_LocalAvatarClones. La comprobación anterior contra
                    -- Overlay.Parent == char siempre daba false y provocaba un
                    -- segundo apply innecesario justo cuando terminaba el respawn.
                    if runtime.AvatarCloneIsBoundToCharacter(char) then
                        runtime.ReapplyAppearanceLayers(char)
                        runtime.AvatarCloneHideBase(char)
                        runtime.UpdateAvatarCloneLayers()
                    else
                        -- CharacterAppearanceLoaded puede disparar DURANTE el countdown.
                        -- Conservamos/recreamos la máscara visual; el guard espera el
                        -- estado físico estable para hacer el bind definitivo.
                        runtime.BeginAvatarCloneRespawnMask(char, generation)
                        task.spawn(function()
                            runtime.GuardAvatarCloneAfterRespawn(char, generation)
                        end)
                    end
                else
                    runtime.ReapplyAppearanceLayers(char)
                end
            end
        end)
    end))
end)

-- También protege el Character que ya existía cuando se ejecutó el hub.
if player.Character and player.Character.Parent then
    runtime.BindAppearanceAccessoryGuard(player.Character, runtime.Appearance.RespawnGeneration)
end

-- =========================
-- UI DE APARIENCIA
-- =========================
-- LayoutOrder explícito permite crear los sliders de forma LAZY y colocarlos
-- debajo de su limited aunque se creen mucho después de arrancar el hub.
local appearanceLayoutOrder = 100

local function placeAppearanceElement(element, order)
    if element and element.ElementFrame then
        element.ElementFrame.LayoutOrder = order
    end
    return element
end

local function nextAppearanceOrder(step)
    local current = appearanceLayoutOrder
    appearanceLayoutOrder = appearanceLayoutOrder + (step or 10)
    return current
end

local introAppearance = Tabs.Apariencia:Paragraph({
    Title = "Equipa accesorios visuales",
    Desc = "Activa tus accesorios visuales y, si quieres ajustarlos fino, abre el editor visual con fondo negro."
})
placeAppearanceElement(introAppearance, nextAppearanceOrder())

runtime.SetupAvatarCloneUI = function()
    local cloneSection = Tabs.Apariencia:Section({Title = "Clonador de avatar"})
    placeAppearanceElement(cloneSection, nextAppearanceOrder())

    local function getAvatarClonePlayerValues()
        local values = {}
        for _, target in ipairs(Players:GetPlayers()) do
            if target ~= player then
                table.insert(values, target.Name)
            end
        end
        table.sort(values, function(a, b)
            return string.lower(a) < string.lower(b)
        end)
        if #values == 0 then
            values[1] = "Sin jugadores"
        end
        return values
    end

    local initialClonePlayers = getAvatarClonePlayerValues()
    runtime.Appearance.AvatarClone.SelectedServerPlayer =
        initialClonePlayers[1] ~= "Sin jugadores" and initialClonePlayers[1] or nil

    local avatarCloneDropdown = Tabs.Apariencia:Dropdown({
        Title = "Jugador del servidor",
        Values = initialClonePlayers,
        Value = initialClonePlayers[1],
        Callback = function(value)
            if value ~= "Sin jugadores" then
                runtime.Appearance.AvatarClone.SelectedServerPlayer = value
            else
                runtime.Appearance.AvatarClone.SelectedServerPlayer = nil
            end
        end,
    })
    placeAppearanceElement(avatarCloneDropdown, nextAppearanceOrder())
    UIElements.DropAvatarClonePlayer = avatarCloneDropdown

    local function refreshAvatarClonePlayers()
        if not avatarCloneDropdown then return end
        local values = getAvatarClonePlayerValues()
        local selected = runtime.Appearance.AvatarClone.SelectedServerPlayer

        local stillExists = false
        for _, name in ipairs(values) do
            if name == selected then
                stillExists = true
                break
            end
        end

        if not stillExists then
            runtime.Appearance.AvatarClone.SelectedServerPlayer =
                values[1] ~= "Sin jugadores" and values[1] or nil
        end

        pcall(function() avatarCloneDropdown:Refresh(values) end)
    end

    runtime.Track(Players.PlayerAdded:Connect(function()
        task.defer(refreshAvatarClonePlayers)
    end))
    runtime.Track(Players.PlayerRemoving:Connect(function()
        task.defer(refreshAvatarClonePlayers)
    end))

    local cloneServerButton = Tabs.Apariencia:Button({
        Title = "Clonar jugador seleccionado",
        Desc = "Copia el avatar.",
        Callback = function()
            local selected = runtime.Appearance.AvatarClone.SelectedServerPlayer
            local target = selected and Players:FindFirstChild(selected) or nil
            if not target or target == player then
                showBottomMessage("Selecciona un jugador válido.")
                return
            end

            task.spawn(function()
                showBottomMessage("Cargando avatar de " .. target.Name .. "...")
                local ok, err = runtime.CloneAvatarFromPlayer(target, true)
                if ok then
                    showBottomMessage("Avatar clonado: " .. target.Name)
                else
                    warn("iLunX AvatarClone:", err)
                    showBottomMessage("No se pudo clonar: " .. tostring(err or "error desconocido"))
                end
            end)
        end,
    })
    placeAppearanceElement(cloneServerButton, nextAppearanceOrder())

    local avatarUsernameInput = Tabs.Apariencia:Input({
        Title = "Clonar por username",
        Placeholder = "Ej: builderman",
        Callback = function(text)
            runtime.Appearance.AvatarClone.UsernameInput = tostring(text or "")
        end,
    })
    placeAppearanceElement(avatarUsernameInput, nextAppearanceOrder())
    UIElements.InputAvatarCloneUsername = avatarUsernameInput

    local cloneUsernameButton = Tabs.Apariencia:Button({
        Title = "Cargar avatar por username",
        Desc = "Funciona aunque el usuario no esté en tu servidor.",
        Callback = function()
            local username = runtime.Appearance.AvatarClone.UsernameInput
            if not username or username:gsub("%s+", "") == "" then
                showBottomMessage("Escribe un username.")
                return
            end

            task.spawn(function()
                showBottomMessage("Buscando @" .. username .. "...")
                local ok, err = runtime.CloneAvatarByUsername(username, true)
                if ok then
                    local targetName = runtime.Appearance.AvatarClone.TargetName or username
                    showBottomMessage("Avatar clonado: " .. targetName)
                else
                    warn("iLunX AvatarClone:", err)
                    showBottomMessage(tostring(err or "No se pudo cargar ese avatar."))
                end
            end)
        end,
    })
    placeAppearanceElement(cloneUsernameButton, nextAppearanceOrder())

    local keepCloneToggle = Tabs.Apariencia:Toggle({
        Title = "Mantener clon al respawnear",
        Desc = "Reaplica el avatar clonado después de morir sin tocar tus limiteds.",
        Value = true,
        Callback = function(state)
            runtime.Appearance.AvatarClone.KeepOnRespawn = state == true
        end,
    })
    placeAppearanceElement(keepCloneToggle, nextAppearanceOrder())
    UIElements.TogKeepAvatarClone = keepCloneToggle

    local restoreOwnAvatarButton = Tabs.Apariencia:Button({
        Title = "Restaurar mi avatar",
        Desc = "Vuelve a tu avatar base y mantiene Headless, Korblox, HideHair y limiteds que estén activos.",
        Callback = function()
            if not runtime.Appearance.AvatarClone.Active then
                showBottomMessage("No tienes un avatar clonado activo.")
                return
            end

            task.spawn(function()
                local ok, err = runtime.RestoreAvatarClone(true)
                if ok then
                    showBottomMessage("Tu avatar original fue restaurado.")
                else
                    warn("iLunX AvatarClone restore:", err)
                    showBottomMessage("No se pudo restaurar tu avatar.")
                end
            end)
        end,
    })
    placeAppearanceElement(restoreOwnAvatarButton, nextAppearanceOrder())
end

runtime.SetupAvatarCloneUI()
runtime.SetupAvatarCloneUI = nil

local bodySection = Tabs.Apariencia:Section({Title = "Cuerpo"})
placeAppearanceElement(bodySection, nextAppearanceOrder())

local appearanceStudioButton = Tabs.Apariencia:Button({
    Title = "Abrir editor visual",
    Desc = "Abre el editor aislado para mover, rotar y cambiar el tamaño de tus limiteds activos.",
    Callback = function()
        if runtime.OpenAppearanceStudio then
            runtime.OpenAppearanceStudio()
        else
            showBottomMessage("El editor visual aún no está listo.")
        end
    end,
})
placeAppearanceElement(appearanceStudioButton, nextAppearanceOrder())

for _, key in ipairs({"Headless", "Korblox", "HideHair"}) do
    local capturedKey = key
    local asset = runtime.AppearanceCatalog[capturedKey]
    local toggle = Tabs.Apariencia:Toggle({
        Title = asset.Name,
        Value = false,
        Callback = function(state) runtime.SetAppearance(capturedKey, state) end,
    })
    placeAppearanceElement(toggle, nextAppearanceOrder())
    runtime.Appearance.ToggleElements[capturedKey] = toggle
    if capturedKey == "Korblox" then UIElements.TogKorblox = toggle end
    if capturedKey == "Headless" then UIElements.TogHeadless = toggle end
    if capturedKey == "HideHair" then UIElements.TogHideHair = toggle end
end

local korbloxFitSection = Tabs.Apariencia:Section({Title = "Ajuste de Korblox"})
placeAppearanceElement(korbloxFitSection, nextAppearanceOrder())

local korbloxFitToggle = Tabs.Apariencia:Toggle({
    Title = "Auto-ajustar Korblox",
    Desc = "Opcional. Ajusta la Korblox al cuerpo visible con límites para evitar patas estiradas.",
    Value = false,
    Callback = function(state)
        runtime.Appearance.KorbloxFit.Enabled = state == true
        if runtime.Appearance.Enabled.Korblox then
            runtime.ApplyKorbloxLayer(player.Character)
            runtime.RebuildAppearanceBodyGuards(player.Character)
            runtime.UpdateAvatarCloneLayers()
        else
            runtime.ClearKorbloxFitVisual()
        end
        if runtime.RefreshAppearanceStudioPreview then task.defer(runtime.RefreshAppearanceStudioPreview) end
    end,
})
placeAppearanceElement(korbloxFitToggle, nextAppearanceOrder())
UIElements.TogKorbloxFit = korbloxFitToggle

local korbloxScaleSlider = Tabs.Apariencia:Slider({
    Title = "Escala Korblox",
    Desc = "Ajuste fino después del auto-acople.",
    Step = 0.01,
    Value = {Min = 0.75, Max = 1.35, Default = 1},
    Callback = function(value)
        runtime.Appearance.KorbloxFit.Scale = math.clamp(tonumber(value) or 1, 0.75, 1.35)
        runtime.UpdateKorbloxFitVisual()
        if runtime.RefreshAppearanceStudioPreview then task.defer(runtime.RefreshAppearanceStudioPreview) end
    end,
})
placeAppearanceElement(korbloxScaleSlider, nextAppearanceOrder())
UIElements.SliKorbloxFitScale = korbloxScaleSlider

local korbloxHeightSlider = Tabs.Apariencia:Slider({
    Title = "Altura Korblox",
    Desc = "Sube o baja únicamente la Korblox visual.",
    Step = 0.01,
    Value = {Min = -0.65, Max = 0.65, Default = 0},
    Callback = function(value)
        runtime.Appearance.KorbloxFit.Height = math.clamp(tonumber(value) or 0, -0.65, 0.65)
        runtime.UpdateKorbloxFitVisual()
        if runtime.RefreshAppearanceStudioPreview then task.defer(runtime.RefreshAppearanceStudioPreview) end
    end,
})
placeAppearanceElement(korbloxHeightSlider, nextAppearanceOrder())
UIElements.SliKorbloxFitHeight = korbloxHeightSlider

local korbloxDepthSlider = Tabs.Apariencia:Slider({
    Title = "Profundidad Korblox",
    Desc = "Mueve la Korblox hacia delante o atrás.",
    Step = 0.01,
    Value = {Min = -0.65, Max = 0.65, Default = 0},
    Callback = function(value)
        runtime.Appearance.KorbloxFit.Depth = math.clamp(tonumber(value) or 0, -0.65, 0.65)
        runtime.UpdateKorbloxFitVisual()
        if runtime.RefreshAppearanceStudioPreview then task.defer(runtime.RefreshAppearanceStudioPreview) end
    end,
})
placeAppearanceElement(korbloxDepthSlider, nextAppearanceOrder())
UIElements.SliKorbloxFitDepth = korbloxDepthSlider

-- Los ajustes de posición/rotación/tamaño de limiteds viven EXCLUSIVAMENTE
-- dentro del editor visual. Se conservan estos hooks para no romper llamadas
-- antiguas de SetAppearance/configs, pero ya no crean sliders debajo del toggle.
function runtime.EnsureInlineAppearanceControls(key)
    return nil
end

function runtime.RefreshAppearanceControls()
    runtime.Appearance.EditorSyncing = false
end

runtime.RefreshAppearanceEditor = runtime.RefreshAppearanceControls

runtime.GetEnabledAppearanceEditorKeys = function()
    local results = {}
    for _, key in ipairs(runtime.AppearanceOrder) do
        local asset = runtime.AppearanceCatalog[key]
        if asset and asset.Kind == "Accessory" and runtime.Appearance.Enabled[key] then
            results[#results + 1] = key
        end
    end
    return results
end

function runtime.EnsureAppearanceStudio()
    if runtime.AppearanceStudioGui and runtime.AppearanceStudioGui.Parent then return end

    local parent = playerGui
    pcall(function()
        parent = gethui and gethui() or game:GetService("CoreGui")
    end)

    local gui = Instance.new("ScreenGui")
    gui.Name = "Xero_AppearanceStudio"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.DisplayOrder = 2147483647
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    pcall(function()
        gui.ScreenInsets = Enum.ScreenInsets.None
        gui.ClipToDeviceSafeArea = false
        gui.SafeAreaCompatibility = Enum.SafeAreaCompatibility.None
        gui.OnTopOfCoreBlur = true
    end)
    gui.Parent = parent
    runtime.AppearanceStudioGui = gui

    local overlay = Instance.new("Frame")
    overlay.Name = "Overlay"
    overlay.Size = UDim2.fromScale(1, 1)
    overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    overlay.BackgroundTransparency = 0.02
    overlay.Visible = false
    overlay.Active = true
    overlay.ZIndex = 600
    overlay.Parent = gui

    local card = Instance.new("Frame")
    card.Name = "Card"
    card.AnchorPoint = Vector2.new(0.5, 0.5)
    card.Position = UDim2.fromScale(0.5, 0.5)
    card.Size = UDim2.fromOffset(860, 500)
    card.BackgroundColor3 = Color3.fromRGB(12, 12, 12)
    card.BorderSizePixel = 0
    card.ClipsDescendants = true
    card.ZIndex = 601
    card.Parent = overlay
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 24)
    local cardStroke = Instance.new("UIStroke")
    cardStroke.Color = Color3.fromRGB(62, 62, 68)
    cardStroke.Transparency = 0.18
    cardStroke.Thickness = 1
    cardStroke.Parent = card

    local studioScale = Instance.new("UIScale")
    studioScale.Scale = 1
    studioScale.Parent = card

    local title = Instance.new("TextLabel")
    title.BackgroundTransparency = 1
    title.Position = UDim2.fromOffset(22, 18)
    title.Size = UDim2.new(1, -96, 0, 26)
    title.Text = "Editor visual de apariencia"
    title.TextColor3 = Color3.fromRGB(244, 244, 244)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 18
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.ZIndex = 603
    title.Parent = card

    local subtitle = Instance.new("TextLabel")
    subtitle.BackgroundTransparency = 1
    subtitle.Position = UDim2.fromOffset(22, 44)
    subtitle.Size = UDim2.new(1, -120, 0, 18)
    subtitle.Text = "Modelo independiente de tu avatar. Ajusta limiteds sin usar al personaje que está dentro del juego."
    subtitle.TextColor3 = Color3.fromRGB(160, 160, 165)
    subtitle.Font = Enum.Font.Gotham
    subtitle.TextSize = 11
    subtitle.TextXAlignment = Enum.TextXAlignment.Left
    subtitle.ZIndex = 603
    subtitle.Parent = card

    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.fromOffset(34, 34)
    closeBtn.Position = UDim2.new(1, -50, 0, 16)
    closeBtn.BackgroundColor3 = Color3.fromRGB(22, 22, 22)
    closeBtn.BorderSizePixel = 0
    closeBtn.Text = "×"
    closeBtn.TextColor3 = Color3.fromRGB(240, 240, 240)
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 18
    closeBtn.AutoButtonColor = false
    closeBtn.ZIndex = 604
    closeBtn.Parent = card
    Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 12)
    closeBtn.Activated:Connect(function()
        if runtime.CancelAppearanceStudioChanges then
            runtime.CancelAppearanceStudioChanges()
        else
            overlay.Visible = false
        end
    end)

    local previewFrame = Instance.new("Frame")
    previewFrame.Name = "PreviewFrame"
    previewFrame.Position = UDim2.fromOffset(18, 76)
    previewFrame.Size = UDim2.fromOffset(430, 466)
    previewFrame.BackgroundColor3 = Color3.fromRGB(6, 6, 6)
    previewFrame.BorderSizePixel = 0
    previewFrame.ZIndex = 602
    previewFrame.Parent = card
    Instance.new("UICorner", previewFrame).CornerRadius = UDim.new(0, 18)
    local previewStroke = Instance.new("UIStroke")
    previewStroke.Color = Color3.fromRGB(48, 48, 52)
    previewStroke.Transparency = 0.2
    previewStroke.Parent = previewFrame

    local previewLabel = Instance.new("TextLabel")
    previewLabel.BackgroundTransparency = 1
    previewLabel.Position = UDim2.fromOffset(14, 9)
    previewLabel.Size = UDim2.new(1, -76, 0, 18)
    previewLabel.Text = "Vista previa · avatar aislado"
    previewLabel.TextColor3 = Color3.fromRGB(240, 240, 240)
    previewLabel.Font = Enum.Font.GothamBold
    previewLabel.TextSize = 12
    previewLabel.TextXAlignment = Enum.TextXAlignment.Left
    previewLabel.ZIndex = 604
    previewLabel.Parent = previewFrame

    local resetView = Instance.new("TextButton")
    resetView.Name = "ResetView"
    resetView.AnchorPoint = Vector2.new(1, 0)
    resetView.Position = UDim2.new(1, -12, 0, 8)
    resetView.Size = UDim2.fromOffset(32, 24)
    resetView.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    resetView.BorderSizePixel = 0
    resetView.Text = "↺"
    resetView.TextColor3 = Color3.fromRGB(225, 225, 225)
    resetView.Font = Enum.Font.GothamBold
    resetView.TextSize = 14
    resetView.AutoButtonColor = false
    resetView.ZIndex = 605
    resetView.Parent = previewFrame
    Instance.new("UICorner", resetView).CornerRadius = UDim.new(0, 8)

    local previewHint = Instance.new("TextLabel")
    previewHint.BackgroundTransparency = 1
    previewHint.Position = UDim2.fromOffset(14, 29)
    previewHint.Size = UDim2.new(1, -28, 0, 16)
    previewHint.Text = "Arrastra: rotar  ·  rueda/pellizca: zoom  ·  clic derecho/2 dedos: mover"
    previewHint.TextColor3 = Color3.fromRGB(126, 126, 132)
    previewHint.Font = Enum.Font.Gotham
    previewHint.TextSize = 9
    previewHint.TextXAlignment = Enum.TextXAlignment.Left
    previewHint.ZIndex = 604
    previewHint.Parent = previewFrame

    local viewport = Instance.new("ViewportFrame")
    viewport.Name = "Viewport"
    viewport.Position = UDim2.fromOffset(12, 48)
    viewport.Size = UDim2.new(1, -24, 1, -60)
    viewport.BackgroundTransparency = 1
    viewport.BorderSizePixel = 0
    viewport.Ambient = Color3.fromRGB(190, 190, 190)
    viewport.LightColor = Color3.fromRGB(255, 255, 255)
    viewport.LightDirection = Vector3.new(-1, -1, -0.75)
    viewport.ZIndex = 603
    viewport.Active = true
    viewport.Parent = previewFrame

    local side = Instance.new("Frame")
    side.Name = "Side"
    side.Position = UDim2.fromOffset(468, 76)
    side.Size = UDim2.new(1, -486, 1, -94)
    side.BackgroundTransparency = 1
    side.ZIndex = 602
    side.Parent = card

    local targetTitle = Instance.new("TextLabel")
    targetTitle.BackgroundTransparency = 1
    targetTitle.Position = UDim2.fromOffset(0, 0)
    targetTitle.Size = UDim2.new(1, 0, 0, 22)
    targetTitle.Text = "Limited activo"
    targetTitle.TextColor3 = Color3.fromRGB(244, 244, 244)
    targetTitle.Font = Enum.Font.GothamBold
    targetTitle.TextSize = 13
    targetTitle.TextXAlignment = Enum.TextXAlignment.Left
    targetTitle.ZIndex = 603
    targetTitle.Parent = side

    local targetHint = Instance.new("TextLabel")
    targetHint.BackgroundTransparency = 1
    targetHint.Position = UDim2.fromOffset(0, 22)
    targetHint.Size = UDim2.new(1, 0, 0, 16)
    targetHint.Text = ""
    targetHint.TextColor3 = Color3.fromRGB(160, 160, 165)
    targetHint.Font = Enum.Font.Gotham
    targetHint.TextSize = 10
    targetHint.TextXAlignment = Enum.TextXAlignment.Left
    targetHint.ZIndex = 603
    targetHint.Visible = false
    targetHint.Parent = side

    -- Selector compacto: no desperdicia media columna mostrando siempre la lista.
    local selectorButton = Instance.new("TextButton")
    selectorButton.Name = "AccessorySelector"
    selectorButton.Position = UDim2.fromOffset(0, 24)
    selectorButton.Size = UDim2.new(1, 0, 0, 36)
    selectorButton.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    selectorButton.BorderSizePixel = 0
    selectorButton.Text = "Seleccionar limited"
    selectorButton.TextColor3 = Color3.fromRGB(240, 240, 240)
    selectorButton.Font = Enum.Font.GothamMedium
    selectorButton.TextSize = 11
    selectorButton.TextXAlignment = Enum.TextXAlignment.Left
    selectorButton.AutoButtonColor = false
    selectorButton.ZIndex = 612
    selectorButton.Parent = side
    Instance.new("UICorner", selectorButton).CornerRadius = UDim.new(0, 10)
    local selectorStroke = Instance.new("UIStroke")
    selectorStroke.Color = Color3.fromRGB(46, 46, 50)
    selectorStroke.Transparency = 0.18
    selectorStroke.Parent = selectorButton
    local selectorPadding = Instance.new("UIPadding")
    selectorPadding.PaddingLeft = UDim.new(0, 12)
    selectorPadding.PaddingRight = UDim.new(0, 38)
    selectorPadding.Parent = selectorButton

    local selectorArrow = Instance.new("TextLabel")
    selectorArrow.Name = "Arrow"
    selectorArrow.AnchorPoint = Vector2.new(1, 0.5)
    selectorArrow.Position = UDim2.new(1, -10, 0.5, 0)
    selectorArrow.Size = UDim2.fromOffset(20, 20)
    selectorArrow.BackgroundTransparency = 1
    selectorArrow.Text = "⌄"
    selectorArrow.TextColor3 = Color3.fromRGB(190, 190, 195)
    selectorArrow.Font = Enum.Font.GothamBold
    selectorArrow.TextSize = 14
    selectorArrow.ZIndex = 613
    selectorArrow.Parent = selectorButton

    local list = Instance.new("ScrollingFrame")
    list.Name = "AccessoryList"
    list.Position = UDim2.fromOffset(0, 64)
    list.Size = UDim2.new(1, 0, 0, 116)
    list.BackgroundColor3 = Color3.fromRGB(13, 13, 13)
    list.BackgroundTransparency = 0
    list.BorderSizePixel = 0
    list.ScrollBarThickness = 3
    list.ScrollBarImageColor3 = Color3.fromRGB(86, 86, 92)
    list.CanvasSize = UDim2.fromOffset(0, 0)
    list.AutomaticCanvasSize = Enum.AutomaticSize.Y
    list.ScrollingDirection = Enum.ScrollingDirection.Y
    list.ElasticBehavior = Enum.ElasticBehavior.Always
    list.ClipsDescendants = true
    list.Visible = false
    list.ZIndex = 620
    list.Parent = side
    Instance.new("UICorner", list).CornerRadius = UDim.new(0, 10)
    local listStroke = Instance.new("UIStroke")
    listStroke.Color = Color3.fromRGB(54, 54, 60)
    listStroke.Transparency = 0.12
    listStroke.Parent = list
    local listPadding = Instance.new("UIPadding")
    listPadding.PaddingTop = UDim.new(0, 5)
    listPadding.PaddingBottom = UDim.new(0, 5)
    listPadding.PaddingLeft = UDim.new(0, 5)
    listPadding.PaddingRight = UDim.new(0, 6)
    listPadding.Parent = list
    local listLayout = Instance.new("UIListLayout")
    listLayout.Padding = UDim.new(0, 5)
    listLayout.Parent = list

    local controlTitle = Instance.new("TextLabel")
    controlTitle.BackgroundTransparency = 1
    controlTitle.Position = UDim2.fromOffset(0, 168)
    controlTitle.Size = UDim2.new(1, 0, 0, 20)
    controlTitle.Text = "Ajustes"
    controlTitle.TextColor3 = Color3.fromRGB(244, 244, 244)
    controlTitle.Font = Enum.Font.GothamBold
    controlTitle.TextSize = 13
    controlTitle.TextXAlignment = Enum.TextXAlignment.Left
    controlTitle.ZIndex = 603
    controlTitle.Parent = side

    local controlsScroll = Instance.new("ScrollingFrame")
    controlsScroll.Name = "Controls"
    controlsScroll.Position = UDim2.fromOffset(0, 192)
    controlsScroll.Size = UDim2.new(1, 0, 1, -244)
    controlsScroll.BackgroundTransparency = 1
    controlsScroll.BorderSizePixel = 0
    controlsScroll.ScrollBarThickness = 4
    controlsScroll.ScrollBarImageColor3 = Color3.fromRGB(92, 92, 98)
    controlsScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    controlsScroll.CanvasSize = UDim2.fromOffset(0, 0)
    controlsScroll.ScrollingDirection = Enum.ScrollingDirection.Y
    controlsScroll.ScrollingEnabled = true
    controlsScroll.Active = true
    controlsScroll.ElasticBehavior = Enum.ElasticBehavior.Always
    controlsScroll.ClipsDescendants = true
    controlsScroll.ZIndex = 603
    controlsScroll.Parent = side
    local controlsPadding = Instance.new("UIPadding")
    controlsPadding.PaddingTop = UDim.new(0, 3)
    controlsPadding.PaddingBottom = UDim.new(0, 12)
    controlsPadding.PaddingLeft = UDim.new(0, 8)
    controlsPadding.PaddingRight = UDim.new(0, 8)
    controlsPadding.Parent = controlsScroll
    local controlsLayout = Instance.new("UIListLayout")
    controlsLayout.Padding = UDim.new(0, 10)
    controlsLayout.Parent = controlsScroll

    local resetButton = Instance.new("TextButton")
    resetButton.Size = UDim2.new(0.30, -4, 0, 34)
    resetButton.Position = UDim2.new(0, 0, 1, -38)
    resetButton.BackgroundColor3 = Color3.fromRGB(24, 24, 24)
    resetButton.BorderSizePixel = 0
    resetButton.Text = "Restablecer"
    resetButton.TextColor3 = Color3.fromRGB(235, 235, 235)
    resetButton.Font = Enum.Font.GothamBold
    resetButton.TextSize = 10
    resetButton.AutoButtonColor = false
    resetButton.ZIndex = 603
    resetButton.Parent = side
    Instance.new("UICorner", resetButton).CornerRadius = UDim.new(0, 12)

    local saveButton = Instance.new("TextButton")
    saveButton.Size = UDim2.new(0.34, -6, 0, 34)
    saveButton.Position = UDim2.new(0.30, 3, 1, -38)
    saveButton.BackgroundColor3 = Color3.fromRGB(236, 236, 236)
    saveButton.BorderSizePixel = 0
    saveButton.Text = "Guardar"
    saveButton.TextColor3 = Color3.fromRGB(14, 14, 14)
    saveButton.Font = Enum.Font.GothamBold
    saveButton.TextSize = 11
    saveButton.AutoButtonColor = false
    saveButton.ZIndex = 603
    saveButton.Parent = side
    Instance.new("UICorner", saveButton).CornerRadius = UDim.new(0, 12)

    local doneButton = Instance.new("TextButton")
    doneButton.Size = UDim2.new(0.36, -3, 0, 34)
    doneButton.Position = UDim2.new(0.64, 3, 1, -38)
    doneButton.BackgroundColor3 = Color3.fromRGB(24, 24, 24)
    doneButton.BorderSizePixel = 0
    doneButton.Text = "Cerrar"
    doneButton.TextColor3 = Color3.fromRGB(235, 235, 235)
    doneButton.Font = Enum.Font.GothamBold
    doneButton.TextSize = 11
    doneButton.AutoButtonColor = false
    doneButton.ZIndex = 603
    doneButton.Parent = side
    Instance.new("UICorner", doneButton).CornerRadius = UDim.new(0, 12)
    doneButton.Activated:Connect(function()
        if runtime.CancelAppearanceStudioChanges then
            runtime.CancelAppearanceStudioChanges()
        else
            list.Visible = false
            overlay.Visible = false
        end
    end)
    saveButton.Activated:Connect(function()
        if runtime.CommitAppearanceStudioChanges then
            runtime.CommitAppearanceStudioChanges()
        else
            list.Visible = false
            overlay.Visible = false
        end
    end)

    local noActive = Instance.new("TextLabel")
    noActive.BackgroundTransparency = 1
    noActive.Position = UDim2.fromOffset(0, 80)
    noActive.Size = UDim2.new(1, 0, 0, 32)
    noActive.Text = "Activa al menos un limited para editarlo aquí."
    noActive.TextColor3 = Color3.fromRGB(168, 168, 173)
    noActive.Font = Enum.Font.Gotham
    noActive.TextSize = 11
    noActive.TextWrapped = true
    noActive.TextXAlignment = Enum.TextXAlignment.Left
    noActive.ZIndex = 603
    noActive.Visible = false
    noActive.Parent = side

    runtime.AppearanceStudio = {
        Overlay = overlay,
        Card = card,
        Scale = studioScale,
        TitleLabel = title,
        SubtitleLabel = subtitle,
        CloseButton = closeBtn,
        PreviewFrame = previewFrame,
        PreviewLabel = previewLabel,
        PreviewHint = previewHint,
        Viewport = viewport,
        ResetViewButton = resetView,
        Side = side,
        AccessoryList = list,
        AccessorySelector = selectorButton,
        AccessorySelectorArrow = selectorArrow,
        TargetTitle = targetTitle,
        TargetHint = targetHint,
        ControlTitle = controlTitle,
        ControlsScroll = controlsScroll,
        ResetButton = resetButton,
        SaveButton = saveButton,
        DoneButton = doneButton,
        NoActiveLabel = noActive,
        Controls = {},
        Buttons = {},
        Syncing = false,
        SelectedKey = nil,
        PreviewCamera = nil,
        PreviewModel = nil,
        BaseAvatarTemplate = nil,
        BaseAvatarTemplateSource = nil,
        CameraState = {
            Yaw = 0,
            Pitch = -0.06,
            Distance = nil,
            DefaultDistance = nil,
            MinDistance = 2,
            MaxDistance = 30,
            Focus = Vector3.new(),
            Pan = Vector3.new(),
        },
    }

    selectorButton.Activated:Connect(function()
        local studio = runtime.AppearanceStudio
        if not studio then return end
        local keys = runtime.GetEnabledAppearanceEditorKeys()
        if #keys == 0 then
            showBottomMessage("Activa un limited primero.")
            return
        end
        studio.AccessoryList.Visible = not studio.AccessoryList.Visible
        studio.AccessorySelectorArrow.Text = studio.AccessoryList.Visible and "⌃" or "⌄"
    end)

    local function copyStudioOffset(state)
        return {
            Position = Vector3.new(state.Position.X, state.Position.Y, state.Position.Z),
            Rotation = Vector3.new(state.Rotation.X, state.Rotation.Y, state.Rotation.Z),
            Scale = tonumber(state.Scale) or 1,
        }
    end

    function runtime.BeginAppearanceStudioChanges()
        local studio = runtime.AppearanceStudio
        if not studio then return end
        studio.OpenSnapshot = {}
        for _, key in ipairs(runtime.GetEnabledAppearanceEditorKeys()) do
            studio.OpenSnapshot[key] = copyStudioOffset(runtime.GetAppearanceOffset(key))
        end
    end

    function runtime.CancelAppearanceStudioChanges()
        local studio = runtime.AppearanceStudio
        if not studio then return end
        if studio.OpenSnapshot then
            for key, state in pairs(studio.OpenSnapshot) do
                runtime.Appearance.AccessoryOffsets[key] = copyStudioOffset(state)
                runtime.ApplyAppearanceOffset(key, nil, true)
            end
        end
        studio.OpenSnapshot = nil
        studio.AccessoryList.Visible = false
        studio.AccessorySelectorArrow.Text = "⌄"
        studio.Overlay.Visible = false
        runtime.RefreshAppearanceControls()
    end

    function runtime.CommitAppearanceStudioChanges()
        local studio = runtime.AppearanceStudio
        if not studio then return end

        -- Guardar no sólo conserva el estado del editor: fuerza que el Character
        -- real vuelva a montar los limiteds usando los offsets actuales. Esto evita
        -- que un AccessoryWeld recreado por Roblox deje el accesorio en su posición
        -- original después de cerrar el Viewport.
        local char = player.Character
        if char and char.Parent then
            runtime.ReapplyAppearanceAccessories(char)

            task.defer(function()
                if not runtime.Alive then return end
                RunService.Heartbeat:Wait()
                if char ~= player.Character or not char.Parent then return end

                for _, key in ipairs(runtime.GetEnabledAppearanceEditorKeys()) do
                    local applied = runtime.ApplyAppearanceOffset(key, char, true)
                    if not applied then
                        runtime.EnsureAppearanceAccessoryKey(key, char)
                    end
                end

                -- Segundo pase corto: algunos juegos/rigs terminan de recrear el
                -- weld un frame tarde, especialmente en móvil.
                task.delay(0.08, function()
                    if not runtime.Alive or char ~= player.Character or not char.Parent then return end
                    for _, key in ipairs(runtime.GetEnabledAppearanceEditorKeys()) do
                        runtime.ApplyAppearanceOffset(key, char, true)
                    end
                    runtime.EnforceBodyAppearance(char)

                    local cloneState = runtime.Appearance.AvatarClone
                    if cloneState and cloneState.Active and cloneState.Overlay and cloneState.Overlay.Parent then
                        runtime.AvatarCloneHideBase(char)
                        runtime.UpdateAvatarCloneLayers()
                    end
                end)
            end)
        end

        studio.OpenSnapshot = nil
        studio.AccessoryList.Visible = false
        studio.AccessorySelectorArrow.Text = "⌄"
        studio.Overlay.Visible = false
        runtime.RefreshAppearanceControls()
        showBottomMessage("Ajustes aplicados y guardados.")
    end

    -- Editor responsive real: escritorio/landscape usa dos columnas; móvil
    -- portrait apila preview + controles sin reducir toda la interfaz a miniatura.
    function runtime.ApplyAppearanceStudioResponsiveLayout()
        local studio = runtime.AppearanceStudio
        if not studio then return 1 end

        local bounds = studio.Overlay.AbsoluteSize
        if bounds.X < 1 or bounds.Y < 1 then
            local currentCamera = workspace.CurrentCamera
            bounds = currentCamera and currentCamera.ViewportSize or Vector2.new(1280, 720)
        end

        local margin = math.clamp(math.floor(math.min(bounds.X, bounds.Y) * 0.035), 8, 18)
        local rawAvailableW = math.max(1, bounds.X - margin * 2)
        local rawAvailableH = math.max(1, bounds.Y - margin * 2)
        local availableW = math.max(250, rawAvailableW)
        local availableH = math.max(280, rawAvailableH)
        local aspect = availableW / math.max(1, availableH)
        local wide = availableW >= 620 and aspect >= 1.18

        -- No ocupa toda la pantalla al abrirse. Se conserva margen real para
        -- que el editor se sienta como una ventana nativa y no como otro juego.
        local cardW
        local cardH
        if wide then
            cardW = math.min(860, math.floor(availableW * 0.94))
            cardH = math.min(500, math.floor(availableH * 0.90))
        else
            cardW = math.min(520, math.floor(availableW * 0.95))
            cardH = math.min(700, math.floor(availableH * 0.94))
        end

        studio.Card.Size = UDim2.fromOffset(cardW, cardH)
        studio.Scale.Scale = 1
        studio.TargetScale = 1
        studio.LayoutMode = wide and "wide" or "portrait"

        local shortWide = wide and cardH < 440
        local headerH = shortWide and 48 or ((not wide and cardW < 350) and 64 or 62)

        studio.TitleLabel.Position = UDim2.fromOffset(wide and 20 or 16, shortWide and 12 or 16)
        studio.TitleLabel.Size = UDim2.new(1, wide and -88 or -70, 0, 24)
        studio.TitleLabel.TextSize = (cardW < 340) and 14 or (shortWide and 15 or 18)
        studio.TitleLabel.TextTruncate = Enum.TextTruncate.AtEnd

        studio.CloseButton.Size = UDim2.fromOffset(shortWide and 30 or 34, shortWide and 30 or 34)
        studio.CloseButton.Position = UDim2.new(1, shortWide and -42 or -50, 0, shortWide and 10 or 14)

        studio.SubtitleLabel.Visible = not shortWide
        studio.SubtitleLabel.Position = UDim2.fromOffset(wide and 20 or 16, 40)
        studio.SubtitleLabel.Size = UDim2.new(1, -78, 0, (not wide and cardW < 360) and 28 or 20)
        studio.SubtitleLabel.TextSize = (not wide and cardW < 360) and 9 or 10
        studio.SubtitleLabel.TextWrapped = not wide and cardW < 430

        if wide then
            local gap = cardW < 760 and 12 or 16
            local sideMin = math.min(390, math.max(280, math.floor(cardW * 0.46)))
            local previewW = math.clamp(
                math.floor(cardW * (cardW < 760 and 0.38 or 0.40)),
                220,
                math.max(220, cardW - sideMin - gap - 36)
            )
            local previewX = 18
            local bodyY = headerH + 8
            local bodyH = math.max(190, cardH - bodyY - 18)
            local sideX = previewX + previewW + gap
            local sideW = math.max(190, cardW - sideX - 18)

            studio.PreviewFrame.Position = UDim2.fromOffset(previewX, bodyY)
            studio.PreviewFrame.Size = UDim2.fromOffset(previewW, bodyH)
            studio.Side.Position = UDim2.fromOffset(sideX, bodyY)
            studio.Side.Size = UDim2.fromOffset(sideW, bodyH)

            studio.PreviewLabel.Position = UDim2.fromOffset(12, 8)
            studio.PreviewLabel.Size = UDim2.new(1, -58, 0, 18)
            studio.PreviewLabel.TextSize = previewW < 300 and 10 or 12
            studio.ResetViewButton.Position = UDim2.new(1, -10, 0, 7)
            studio.ResetViewButton.Size = UDim2.fromOffset(30, 24)

            local showHint = bodyH >= 250 and previewW >= 310
            studio.PreviewHint.Visible = showHint
            studio.PreviewHint.Position = UDim2.fromOffset(12, 28)
            studio.PreviewHint.Size = UDim2.new(1, -24, 0, 15)
            studio.PreviewHint.TextSize = 8

            local viewportY = showHint and 46 or 34
            studio.Viewport.Position = UDim2.fromOffset(8, viewportY)
            studio.Viewport.Size = UDim2.new(1, -16, 1, -(viewportY + 8))

            studio.TargetTitle.Position = UDim2.fromOffset(0, 0)
            studio.TargetTitle.Size = UDim2.new(1, 0, 0, 18)
            studio.TargetTitle.Text = "Limited activo"
            studio.TargetTitle.TextSize = sideW < 250 and 10 or 12
            studio.TargetHint.Visible = false

            studio.AccessorySelector.Position = UDim2.fromOffset(0, 22)
            studio.AccessorySelector.Size = UDim2.new(1, 0, 0, 34)
            studio.AccessoryList.Position = UDim2.fromOffset(0, 60)
            studio.AccessoryList.Size = UDim2.new(1, 0, 0, math.min(126, math.max(76, bodyH - 98)))

            local controlTitleY = 64
            studio.ControlTitle.Position = UDim2.fromOffset(0, controlTitleY)
            studio.ControlTitle.Size = UDim2.new(1, 0, 0, 18)
            studio.ControlTitle.TextSize = 12

            local buttonH = 34
            local buttonsY = bodyH - buttonH
            local controlsY = controlTitleY + 22
            local controlsH = math.max(112, buttonsY - controlsY - 10)
            studio.ControlsScroll.Position = UDim2.fromOffset(0, controlsY)
            studio.ControlsScroll.Size = UDim2.new(1, 0, 0, controlsH)

            local gapB = 6
            studio.ResetButton.Size = UDim2.new(0.30, -4, 0, buttonH)
            studio.ResetButton.Position = UDim2.fromOffset(0, buttonsY)
            studio.SaveButton.Size = UDim2.new(0.34, -6, 0, buttonH)
            studio.SaveButton.Position = UDim2.new(0.30, 3, 0, buttonsY)
            studio.DoneButton.Size = UDim2.new(0.36, -3, 0, buttonH)
            studio.DoneButton.Position = UDim2.new(0.64, 3, 0, buttonsY)

            studio.NoActiveLabel.Visible = false
        else
            local bodyY = headerH + 4
            local bodyH = math.max(250, cardH - bodyY - 14)
            local minSideH = math.min(250, math.max(200, math.floor(bodyH * 0.42)))
            local previewH = math.clamp(
                math.floor(bodyH * 0.48),
                math.min(165, bodyH - minSideH - 10),
                math.max(165, bodyH - minSideH - 10)
            )
            local sideY = bodyY + previewH + 10
            local sideH = math.max(170, cardH - sideY - 12)

            studio.PreviewFrame.Position = UDim2.fromOffset(12, bodyY)
            studio.PreviewFrame.Size = UDim2.new(1, -24, 0, previewH)
            studio.Side.Position = UDim2.fromOffset(12, sideY)
            studio.Side.Size = UDim2.new(1, -24, 0, sideH)

            studio.PreviewLabel.Position = UDim2.fromOffset(12, 7)
            studio.PreviewLabel.Size = UDim2.new(1, -54, 0, 18)
            studio.PreviewLabel.TextSize = cardW < 330 and 10 or 11
            studio.ResetViewButton.Position = UDim2.new(1, -9, 0, 6)
            studio.ResetViewButton.Size = UDim2.fromOffset(29, 23)

            local showHint = previewH >= 215 and cardW >= 350
            studio.PreviewHint.Visible = showHint
            studio.PreviewHint.Position = UDim2.fromOffset(12, 27)
            studio.PreviewHint.Size = UDim2.new(1, -24, 0, 15)
            studio.PreviewHint.TextSize = 8

            local viewportY = showHint and 44 or 32
            studio.Viewport.Position = UDim2.fromOffset(7, viewportY)
            studio.Viewport.Size = UDim2.new(1, -14, 1, -(viewportY + 7))

            studio.TargetTitle.Position = UDim2.fromOffset(0, 0)
            studio.TargetTitle.Size = UDim2.new(1, 0, 0, 18)
            studio.TargetTitle.Text = "Limited activo"
            studio.TargetTitle.TextSize = 11
            studio.TargetHint.Visible = false

            studio.AccessorySelector.Position = UDim2.fromOffset(0, 21)
            studio.AccessorySelector.Size = UDim2.new(1, 0, 0, 34)
            studio.AccessoryList.Position = UDim2.fromOffset(0, 59)
            studio.AccessoryList.Size = UDim2.new(1, 0, 0, math.min(112, math.max(70, sideH - 94)))

            local controlTitleY = 62
            studio.ControlTitle.Position = UDim2.fromOffset(0, controlTitleY)
            studio.ControlTitle.Size = UDim2.new(1, 0, 0, 17)
            studio.ControlTitle.TextSize = 11

            local buttonH = 32
            local buttonsY = sideH - buttonH
            local controlsY = controlTitleY + 20
            local controlsH = math.max(100, buttonsY - controlsY - 8)
            studio.ControlsScroll.Position = UDim2.fromOffset(0, controlsY)
            studio.ControlsScroll.Size = UDim2.new(1, 0, 0, controlsH)

            local gapB = 6
            studio.ResetButton.Size = UDim2.new(0.30, -4, 0, buttonH)
            studio.ResetButton.Position = UDim2.fromOffset(0, buttonsY)
            studio.SaveButton.Size = UDim2.new(0.34, -6, 0, buttonH)
            studio.SaveButton.Position = UDim2.new(0.30, 3, 0, buttonsY)
            studio.DoneButton.Size = UDim2.new(0.36, -3, 0, buttonH)
            studio.DoneButton.Position = UDim2.new(0.64, 3, 0, buttonsY)

            studio.NoActiveLabel.Visible = false
        end

        -- Sólo para viewports extremos (<~280 px), evitando overflow sin hacer
        -- que un teléfono normal vea toda la UI diminuta.
        local targetScale = math.min(1, rawAvailableW / math.max(1, cardW), rawAvailableH / math.max(1, cardH))
        targetScale = math.max(0.55, targetScale)
        studio.TargetScale = targetScale
        studio.Scale.Scale = targetScale
        return targetScale
    end

    runtime.Track(overlay:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
        local studio = runtime.AppearanceStudio
        if overlay.Visible and studio then
            runtime.ApplyAppearanceStudioResponsiveLayout()
            if runtime.UpdateAppearanceStudioCamera then
                task.defer(runtime.UpdateAppearanceStudioCamera)
            end
        end
    end))

    local function updateStudioCamera()
        local studio = runtime.AppearanceStudio
        local state = studio and studio.CameraState
        local cameraPreview = studio and studio.PreviewCamera
        if not state or not cameraPreview then return end

        local distance = math.clamp(
            tonumber(state.Distance) or tonumber(state.DefaultDistance) or 8,
            tonumber(state.MinDistance) or 2,
            tonumber(state.MaxDistance) or 30
        )
        state.Distance = distance

        local focus = state.Focus + state.Pan
        local orbit = CFrame.Angles(state.Pitch, state.Yaw, 0) * Vector3.new(0, 0, distance)
        cameraPreview.CFrame = CFrame.new(focus + orbit, focus)
    end
    runtime.UpdateAppearanceStudioCamera = updateStudioCamera

    local function resetStudioCamera()
        local studio = runtime.AppearanceStudio
        if not studio then return end
        local state = studio.CameraState
        state.Yaw = 0
        state.Pitch = -0.06
        state.Pan = Vector3.new()
        state.Distance = state.DefaultDistance or state.Distance or 8
        updateStudioCamera()
    end
    resetView.Activated:Connect(resetStudioCamera)

    local mouseMode = nil
    local lastMouse = nil
    local touches = {}
    local touchGestureDistance = nil
    local touchGestureCenter = nil

    local function pointInsideViewport(point)
        local pos = viewport.AbsolutePosition
        local size = viewport.AbsoluteSize
        return point.X >= pos.X and point.Y >= pos.Y
            and point.X <= pos.X + size.X and point.Y <= pos.Y + size.Y
    end

    local function rotatePreview(delta)
        local studio = runtime.AppearanceStudio
        if not studio then return end
        local state = studio.CameraState
        state.Yaw -= delta.X * 0.008
        state.Pitch = math.clamp(state.Pitch - delta.Y * 0.006, -1.25, 1.25)
        updateStudioCamera()
    end

    local function panPreview(delta)
        local studio = runtime.AppearanceStudio
        local cameraPreview = studio and studio.PreviewCamera
        if not studio or not cameraPreview then return end
        local state = studio.CameraState
        local factor = math.max(0.0025, (state.Distance or 8) / 1850)
        state.Pan += (-cameraPreview.CFrame.RightVector * delta.X + cameraPreview.CFrame.UpVector * delta.Y) * factor
        updateStudioCamera()
    end

    local function zoomPreview(multiplier)
        local studio = runtime.AppearanceStudio
        if not studio then return end
        local state = studio.CameraState
        state.Distance = math.clamp(
            (state.Distance or state.DefaultDistance or 8) * multiplier,
            state.MinDistance or 2,
            state.MaxDistance or 30
        )
        updateStudioCamera()
    end

    local function getTwoTouches()
        local firstInput, firstPos, secondInput, secondPos
        for inputObject, position in pairs(touches) do
            if not firstInput then
                firstInput, firstPos = inputObject, position
            else
                secondInput, secondPos = inputObject, position
                break
            end
        end
        return firstInput, firstPos, secondInput, secondPos
    end

    viewport.InputBegan:Connect(function(input)
        if not overlay.Visible then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            mouseMode = "rotate"
            lastMouse = input.Position
        elseif input.UserInputType == Enum.UserInputType.MouseButton2
            or input.UserInputType == Enum.UserInputType.MouseButton3 then
            mouseMode = "pan"
            lastMouse = input.Position
        elseif input.UserInputType == Enum.UserInputType.Touch then
            touches[input] = input.Position
            local _, p1, _, p2 = getTwoTouches()
            if p1 and p2 then
                touchGestureDistance = (p2 - p1).Magnitude
                touchGestureCenter = (p1 + p2) * 0.5
            else
                touchGestureDistance = nil
                touchGestureCenter = nil
            end
        end
    end)

    runtime.Track(UserInputService.InputChanged:Connect(function(input)
        if not runtime.Alive or not overlay.Visible then return end

        if input.UserInputType == Enum.UserInputType.MouseMovement and mouseMode and lastMouse then
            local now = input.Position
            local delta = now - lastMouse
            lastMouse = now
            if mouseMode == "rotate" then rotatePreview(delta) else panPreview(delta) end
            return
        end

        if input.UserInputType == Enum.UserInputType.MouseWheel then
            local mouseLocation = UserInputService:GetMouseLocation()
            if pointInsideViewport(mouseLocation) then
                local wheel = input.Position.Z
                if wheel ~= 0 then zoomPreview(wheel > 0 and 0.88 or 1.14) end
            end
            return
        end

        if input.UserInputType == Enum.UserInputType.Touch and touches[input] then
            local previous = touches[input]
            touches[input] = input.Position

            local _, p1, _, p2 = getTwoTouches()
            if p1 and p2 then
                local currentDistance = math.max(1, (p2 - p1).Magnitude)
                local currentCenter = (p1 + p2) * 0.5
                if touchGestureDistance and touchGestureDistance > 1 then
                    zoomPreview(math.clamp(touchGestureDistance / currentDistance, 0.78, 1.28))
                end
                if touchGestureCenter then
                    panPreview(currentCenter - touchGestureCenter)
                end
                touchGestureDistance = currentDistance
                touchGestureCenter = currentCenter
            else
                touchGestureDistance = nil
                touchGestureCenter = nil
                rotatePreview(input.Position - previous)
            end
        end
    end))

    runtime.Track(UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.MouseButton2
            or input.UserInputType == Enum.UserInputType.MouseButton3 then
            mouseMode = nil
            lastMouse = nil
        elseif input.UserInputType == Enum.UserInputType.Touch and touches[input] then
            touches[input] = nil
            local _, p1, _, p2 = getTwoTouches()
            if p1 and p2 then
                touchGestureDistance = (p2 - p1).Magnitude
                touchGestureCenter = (p1 + p2) * 0.5
            else
                touchGestureDistance = nil
                touchGestureCenter = nil
            end
        end
    end))

    local previewRefreshQueued = false
    local function queueAppearancePreviewRefresh()
        if previewRefreshQueued then return end
        previewRefreshQueued = true
        task.delay(0.045, function()
            previewRefreshQueued = false
            if runtime.Alive and runtime.AppearanceStudio and overlay.Visible then
                runtime.RefreshAppearanceStudioPreview()
            end
        end)
    end

    local function updateStudioAccessoryTransform(key)
        local studio = runtime.AppearanceStudio
        local model = studio and studio.PreviewModel
        if not model or not key then return false end

        for _, accessory in ipairs(model:GetChildren()) do
            if accessory:IsA("Accessory") and accessory:GetAttribute("iLunXAppearanceKey") == key then
                local weld = runtime.FindAppearanceWeld(accessory)
                local base = accessory:GetAttribute("XeroPreviewBaseC1")
                if weld and typeof(base) == "CFrame" then
                    local state = runtime.GetAppearanceOffset(key)
                    local p = state.Position
                    local r = state.Rotation
                    weld.C1 = base
                        * CFrame.new(p.X, p.Y, p.Z)
                        * CFrame.Angles(math_rad(r.X), math_rad(r.Y), math_rad(r.Z))
                    return true
                end
            end
        end
        return false
    end

    local function setComponent(component, value)
        local studio = runtime.AppearanceStudio
        if not studio or studio.Syncing then return end
        local key = studio.SelectedKey
        if not key then return end
        local state = runtime.GetAppearanceOffset(key)
        if component == "X" then
            state.Position = Vector3.new(value, state.Position.Y, state.Position.Z)
        elseif component == "Y" then
            state.Position = Vector3.new(state.Position.X, value, state.Position.Z)
        elseif component == "Z" then
            state.Position = Vector3.new(state.Position.X, state.Position.Y, value)
        elseif component == "RX" then
            state.Rotation = Vector3.new(value, state.Rotation.Y, state.Rotation.Z)
        elseif component == "RY" then
            state.Rotation = Vector3.new(state.Rotation.X, value, state.Rotation.Z)
        elseif component == "RZ" then
            state.Rotation = Vector3.new(state.Rotation.X, state.Rotation.Y, value)
        elseif component == "SCALE" then
            state.Scale = math.clamp(tonumber(value) or 1, 0.25, 3)
        end

        runtime.ApplyAppearanceOffset(key, nil, component == "SCALE")
        if runtime.MarkAvatarThumbnailSpoofDirty then
            runtime.MarkAvatarThumbnailSpoofDirty(true)
        end

        -- Posición/rotación se actualizan directamente en el Viewport para que
        -- arrastrar con el dedo sea fluido. Tamaño reconstruye la preview de
        -- forma limitada porque puede modificar MeshPart/SpecialMesh.
        if component == "SCALE" or not updateStudioAccessoryTransform(key) then
            queueAppearancePreviewRefresh()
        end
    end

    local activeStudioSlider = nil

    local function finishStudioSlider(input)
        local active = activeStudioSlider
        if not active then return end
        if input and active.Input ~= input
            and not (active.Input.UserInputType == Enum.UserInputType.MouseButton1
                and input.UserInputType == Enum.UserInputType.MouseButton1) then
            return
        end
        -- Un toque corto sobre el track sigue funcionando como tap-to-set.
        if active.Mode == "pending" and input then
            active.Api:SetFromScreenX(input.Position.X)
        end
        activeStudioSlider = nil
        if controlsScroll and controlsScroll.Parent then
            controlsScroll.ScrollingEnabled = true
        end
        if runtime.MarkAvatarThumbnailSpoofDirty then
            runtime.MarkAvatarThumbnailSpoofDirty(false)
        end
    end

    runtime.Track(UserInputService.InputChanged:Connect(function(input)
        local active = activeStudioSlider
        if not active or not overlay.Visible then return end

        local mouseDrag = active.Input.UserInputType == Enum.UserInputType.MouseButton1
            and input.UserInputType == Enum.UserInputType.MouseMovement
        if mouseDrag then
            active.Mode = "slider"
            active.Api:SetFromScreenX(input.Position.X)
            return
        end

        local touchDrag = active.Input.UserInputType == Enum.UserInputType.Touch and input == active.Input
        if not touchDrag then return end

        local delta = input.Position - active.Start
        if active.Mode == "pending" and delta.Magnitude >= 8 then
            -- Horizontal = mover slider. Vertical = dejar que el ScrollingFrame haga scroll.
            if math.abs(delta.X) > math.abs(delta.Y) * 1.15 then
                active.Mode = "slider"
                controlsScroll.ScrollingEnabled = false
            else
                activeStudioSlider = nil
                controlsScroll.ScrollingEnabled = true
                return
            end
        end
        if active.Mode == "slider" then
            active.Api:SetFromScreenX(input.Position.X)
        end
    end))

    runtime.Track(UserInputService.InputEnded:Connect(function(input)
        if activeStudioSlider then
            finishStudioSlider(input)
        end
    end))

    local function makeStudioSlider(titleText, component, minValue, maxValue, stepValue, defaultValue)
        local row = Instance.new("Frame")
        row.Name = component .. "Slider"
        row.Size = UDim2.new(1, -2, 0, 78)
        row.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
        row.BorderSizePixel = 0
        row.ClipsDescendants = true
        row.ZIndex = 603
        row.Parent = controlsScroll
        Instance.new("UICorner", row).CornerRadius = UDim.new(0, 12)

        local rowStroke = Instance.new("UIStroke")
        rowStroke.Color = Color3.fromRGB(42, 42, 46)
        rowStroke.Transparency = 0.18
        rowStroke.Thickness = 1
        rowStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        rowStroke.Parent = row

        local titleLabel = Instance.new("TextLabel")
        titleLabel.BackgroundTransparency = 1
        titleLabel.Position = UDim2.fromOffset(14, 7)
        titleLabel.Size = UDim2.new(1, -112, 0, 22)
        titleLabel.Text = titleText
        titleLabel.TextColor3 = Color3.fromRGB(236, 236, 236)
        titleLabel.Font = Enum.Font.GothamMedium
        titleLabel.TextSize = 10
        titleLabel.TextXAlignment = Enum.TextXAlignment.Left
        titleLabel.TextTruncate = Enum.TextTruncate.AtEnd
        titleLabel.ZIndex = 604
        titleLabel.Parent = row

        local box = Instance.new("TextBox")
        box.AnchorPoint = Vector2.new(1, 0)
        box.Size = UDim2.fromOffset(72, 24)
        box.Position = UDim2.new(1, -12, 0, 6)
        box.BackgroundColor3 = Color3.fromRGB(9, 9, 9)
        box.BorderSizePixel = 0
        box.ClearTextOnFocus = false
        box.Text = tostring(defaultValue or 0)
        box.TextColor3 = Color3.fromRGB(242, 242, 242)
        box.PlaceholderColor3 = Color3.fromRGB(120, 120, 126)
        box.Font = Enum.Font.GothamMedium
        box.TextSize = 10
        box.ZIndex = 606
        box.Parent = row
        Instance.new("UICorner", box).CornerRadius = UDim.new(0, 8)

        local minus = Instance.new("TextButton")
        minus.Size = UDim2.fromOffset(28, 28)
        minus.Position = UDim2.fromOffset(12, 38)
        minus.BackgroundColor3 = Color3.fromRGB(27, 27, 27)
        minus.BorderSizePixel = 0
        minus.Text = "−"
        minus.TextColor3 = Color3.fromRGB(242, 242, 242)
        minus.Font = Enum.Font.GothamBold
        minus.TextSize = 15
        minus.AutoButtonColor = false
        minus.ZIndex = 606
        minus.Parent = row
        Instance.new("UICorner", minus).CornerRadius = UDim.new(0, 9)

        local plus = Instance.new("TextButton")
        plus.AnchorPoint = Vector2.new(1, 0)
        plus.Size = UDim2.fromOffset(28, 28)
        plus.Position = UDim2.new(1, -12, 0, 38)
        plus.BackgroundColor3 = Color3.fromRGB(27, 27, 27)
        plus.BorderSizePixel = 0
        plus.Text = "+"
        plus.TextColor3 = Color3.fromRGB(242, 242, 242)
        plus.Font = Enum.Font.GothamBold
        plus.TextSize = 15
        plus.AutoButtonColor = false
        plus.ZIndex = 606
        plus.Parent = row
        Instance.new("UICorner", plus).CornerRadius = UDim.new(0, 9)

        local track = Instance.new("Frame")
        track.Name = "Track"
        track.Position = UDim2.fromOffset(54, 49)
        track.Size = UDim2.new(1, -122, 0, 6)
        track.BackgroundColor3 = Color3.fromRGB(48, 48, 52)
        track.BorderSizePixel = 0
        track.ZIndex = 604
        track.Parent = row
        Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)

        local fill = Instance.new("Frame")
        fill.Name = "Fill"
        fill.Size = UDim2.fromScale(0, 1)
        fill.BackgroundColor3 = Color3.fromRGB(236, 236, 236)
        fill.BorderSizePixel = 0
        fill.ZIndex = 605
        fill.Parent = track
        Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)

        local thumb = Instance.new("Frame")
        thumb.Name = "Thumb"
        thumb.AnchorPoint = Vector2.new(0.5, 0.5)
        thumb.Position = UDim2.fromScale(0, 0.5)
        thumb.Size = UDim2.fromOffset(16, 16)
        thumb.BackgroundColor3 = Color3.fromRGB(246, 246, 246)
        thumb.BorderSizePixel = 0
        thumb.ZIndex = 607
        thumb.Parent = track
        Instance.new("UICorner", thumb).CornerRadius = UDim.new(1, 0)
        local thumbStroke = Instance.new("UIStroke")
        thumbStroke.Color = Color3.fromRGB(24, 24, 24)
        thumbStroke.Transparency = 0.15
        thumbStroke.Parent = thumb

        -- Área táctil grande e invisible: el usuario no tiene que acertarle a
        -- una línea de 5 px para deslizar.
        local sliderHit = Instance.new("TextButton")
        sliderHit.Name = "TouchTrack"
        sliderHit.Position = UDim2.fromOffset(48, 39)
        sliderHit.Size = UDim2.new(1, -110, 0, 26)
        sliderHit.BackgroundTransparency = 1
        sliderHit.Text = ""
        sliderHit.AutoButtonColor = false
        sliderHit.ZIndex = 608
        sliderHit.Parent = row

        local stepString = tostring(stepValue)
        local fraction = stepString:match("%.(%d+)")
        local decimals = fraction and #fraction or 0

        local function formatNumber(v)
            if decimals <= 0 then
                return tostring(math.floor(v + (v >= 0 and 0.5 or -0.5)))
            end
            return string.format("%." .. tostring(decimals) .. "f", v)
        end

        local api = {
            Min = minValue,
            Max = maxValue,
            Step = stepValue,
            Default = defaultValue or 0,
            Track = track,
            Fill = fill,
            Thumb = thumb,
        }

        local function quantize(value)
            value = math.clamp(tonumber(value) or api.Default, minValue, maxValue)
            local steps = math.floor(((value - minValue) / stepValue) + 0.5)
            return math.clamp(minValue + steps * stepValue, minValue, maxValue)
        end

        function api:UpdateVisual(value)
            local span = math.max(0.000001, maxValue - minValue)
            local alpha = math.clamp((value - minValue) / span, 0, 1)
            fill.Size = UDim2.fromScale(alpha, 1)
            thumb.Position = UDim2.new(alpha, 0, 0.5, 0)
        end

        function api:Set(value, silent)
            local numeric = quantize(value)
            box.Text = formatNumber(numeric)
            self:UpdateVisual(numeric)
            if not silent then
                setComponent(component, numeric)
            end
        end

        function api:Get()
            return quantize(box.Text)
        end

        function api:SetFromScreenX(screenX)
            local absPos = track.AbsolutePosition
            local absSize = track.AbsoluteSize
            if absSize.X <= 1 then return end
            local alpha = math.clamp((screenX - absPos.X) / absSize.X, 0, 1)
            self:Set(minValue + (maxValue - minValue) * alpha)
        end

        sliderHit.InputBegan:Connect(function(input)
            if input.UserInputType ~= Enum.UserInputType.MouseButton1
                and input.UserInputType ~= Enum.UserInputType.Touch then
                return
            end
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                activeStudioSlider = {Api = api, Input = input, Start = input.Position, Mode = "slider"}
                controlsScroll.ScrollingEnabled = false
                api:SetFromScreenX(input.Position.X)
            else
                -- En touch primero detectamos intención: swipe vertical hace scroll,
                -- swipe horizontal mueve el slider.
                activeStudioSlider = {Api = api, Input = input, Start = input.Position, Mode = "pending"}
                controlsScroll.ScrollingEnabled = true
            end
        end)

        minus.Activated:Connect(function()
            api:Set(api:Get() - stepValue)
        end)

        plus.Activated:Connect(function()
            api:Set(api:Get() + stepValue)
        end)

        box.FocusLost:Connect(function()
            api:Set(box.Text)
        end)

        api:Set(defaultValue or 0, true)
        runtime.AppearanceStudio.Controls[component] = api
    end

    makeStudioSlider("Posición X", "X", -3, 3, 0.05, 0)
    makeStudioSlider("Posición Y", "Y", -3, 3, 0.05, 0)
    makeStudioSlider("Posición Z", "Z", -3, 3, 0.05, 0)
    makeStudioSlider("Rotación X", "RX", -180, 180, 1, 0)
    makeStudioSlider("Rotación Y", "RY", -180, 180, 1, 0)
    makeStudioSlider("Rotación Z", "RZ", -180, 180, 1, 0)
    makeStudioSlider("Tamaño", "SCALE", 0.25, 3, 0.05, 1)

    resetButton.Activated:Connect(function()
        local studio = runtime.AppearanceStudio
        local key = studio and studio.SelectedKey
        if not key then
            showBottomMessage("Selecciona un limited primero.")
            return
        end
        runtime.Appearance.AccessoryOffsets[key] = {
            Position = Vector3.new(),
            Rotation = Vector3.new(),
            Scale = 1,
        }
        runtime.ApplyAppearanceOffset(key, nil, true)
        if runtime.MarkAvatarThumbnailSpoofDirty then
            runtime.MarkAvatarThumbnailSpoofDirty()
        end
        runtime.RefreshAppearanceControls()
        task.defer(runtime.RefreshAppearanceStudio)
        showBottomMessage("Ajustes restaurados: " .. runtime.AppearanceCatalog[key].Name)
    end)
end

local function prepareAppearanceStudioBaseModel(model)
    if not model or not model:IsA("Model") then return nil end
    model.Name = "Xero_AvatarPreviewBase"
    model.Archivable = true

    for _, obj in ipairs(model:GetDescendants()) do
        if obj:IsA("Script") or obj:IsA("LocalScript") or obj:IsA("ModuleScript")
            or obj:IsA("Tool") or obj:IsA("ForceField") or obj:IsA("BillboardGui") then
            pcall(function() obj:Destroy() end)
        elseif obj:IsA("BasePart") then
            obj.CanCollide = false
            obj.CanTouch = false
            obj.CanQuery = false
            obj.Massless = true
        end
    end

    local humanoid = model:FindFirstChildOfClass("Humanoid")
    if humanoid then
        pcall(function() humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None end)
        pcall(function() humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff end)
        pcall(function() humanoid.NameDisplayDistance = 0 end)
        pcall(function() humanoid.HealthDisplayDistance = 0 end)
        pcall(function() humanoid.AutoRotate = false end)
        local animator = humanoid:FindFirstChildOfClass("Animator")
        if animator then pcall(function() animator:Destroy() end) end
    end

    model.Parent = nil
    return model
end

function runtime.GetAppearanceStudioBaseModel()
    local studio = runtime.AppearanceStudio
    if not studio then return nil end

    -- Si hay una skin clonada activa, el editor usa exactamente ese template
    -- como avatar base. Sin clon, conserva el comportamiento original.
    local cloneState = runtime.Appearance and runtime.Appearance.AvatarClone
    local cloneTemplate = cloneState
        and cloneState.Active
        and cloneState.Template
        or nil

    local cached = studio.BaseAvatarTemplate
    local cachedSource = studio.BaseAvatarTemplateSource
    if cached and cached.Parent == nil and cachedSource == cloneTemplate then
        local ok, cloned = pcall(function() return cached:Clone() end)
        if ok then return cloned end
    elseif cached then
        pcall(function() cached:Destroy() end)
        studio.BaseAvatarTemplate = nil
    end

    local rigType = Enum.HumanoidRigType.R15
    local currentHumanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    if currentHumanoid then rigType = currentHumanoid.RigType end

    local model
    if cloneTemplate then
        -- El template ya trae ropa, accesorios y proporciones de la skin clonada.
        local ok, cloned = pcall(function() return cloneTemplate:Clone() end)
        if ok then model = cloned end
    else
        -- Sin clon, muestra tu avatar normal como antes.
        model = runtime.CreateAvatarCloneTemplateFromUserId(player.UserId, rigType)
    end

    if not model then return nil end

    model = prepareAppearanceStudioBaseModel(model)
    if not model then return nil end

    studio.BaseAvatarTemplate = model
    studio.BaseAvatarTemplateSource = cloneTemplate

    local cloneOk, cloned = pcall(function() return model:Clone() end)
    if cloneOk then return cloned end
    return nil
end

local function applyAppearanceStudioBodyLayers(model)
    if not model then return end

    if runtime.Appearance.Enabled.Headless then
        local head = model:FindFirstChild("Head")
        if head and head:IsA("BasePart") then
            head.Transparency = 1
            head.LocalTransparencyModifier = 1
            for _, d in ipairs(head:GetDescendants()) do
                if d:IsA("Decal") or d:IsA("Texture") then d.Transparency = 1 end
            end
        end
    end

    if runtime.Appearance.Enabled.Korblox then
        local humanoid = model:FindFirstChildOfClass("Humanoid")
        local upper = model:FindFirstChild("RightUpperLeg")
        local lower = model:FindFirstChild("RightLowerLeg")
        local foot = model:FindFirstChild("RightFoot")
        if humanoid and humanoid.RigType == Enum.HumanoidRigType.R15 and upper and upper:IsA("MeshPart") then
            if runtime.Appearance.KorbloxFit.Enabled then
                upper.Transparency = 1
                upper.LocalTransparencyModifier = 1
                if lower and lower:IsA("BasePart") then
                    lower.Transparency = 1
                    lower.LocalTransparencyModifier = 1
                end
                if foot and foot:IsA("BasePart") then
                    foot.Transparency = 1
                    foot.LocalTransparencyModifier = 1
                end

                local visual = Instance.new("MeshPart")
                visual.Name = "Xero_KorbloxFitPreview"
                visual.MeshId = KORBLOX_UPPER_MESH
                visual.TextureID = KORBLOX_TEXTURE
                visual.Anchored = true
                visual.CanCollide = false
                visual.CanTouch = false
                visual.CanQuery = false
                visual.Massless = true
                local targetSize = runtime.ComputeKorbloxFitSize(upper.Size, runtime.GetKorbloxFitReferenceSize())
                local autoHeight = math.clamp((upper.Size.Y - targetSize.Y) * 0.5, -0.35, 0.35)
                visual.Size = targetSize
                visual.CFrame = upper.CFrame * CFrame.new(
                    0,
                    autoHeight + runtime.Appearance.KorbloxFit.Height,
                    runtime.Appearance.KorbloxFit.Depth
                )
                visual.Parent = model
            else
                pcall(function() upper.MeshId = KORBLOX_UPPER_MESH end)
                pcall(function() upper.TextureID = KORBLOX_TEXTURE end)
                upper.Transparency = 0
                upper.LocalTransparencyModifier = 0
                if lower and lower:IsA("BasePart") then
                    lower.Transparency = 1
                    lower.LocalTransparencyModifier = 1
                end
                if foot and foot:IsA("BasePart") then
                    foot.Transparency = 1
                    foot.LocalTransparencyModifier = 1
                end
            end
        end
    end

    if runtime.Appearance.Enabled.HideHair then
        for _, accessory in ipairs(model:GetChildren()) do
            if isHairAccessory(accessory) and accessory:GetAttribute("iLunXAppearanceKey") == nil then
                for _, obj in ipairs(accessory:GetDescendants()) do
                    if obj:IsA("BasePart") then
                        obj.Transparency = 1
                        obj.LocalTransparencyModifier = 1
                    elseif obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam") then
                        obj.Enabled = false
                    end
                end
            end
        end
    end
end

local function scaleAppearanceStudioAccessory(key, accessory)
    local state = runtime.GetAppearanceOffset(key)
    local scale = math.clamp(tonumber(state.Scale) or 1, 0.25, 3)
    if math.abs(scale - 1) < 0.0001 then return end

    for _, obj in ipairs(accessory:GetDescendants()) do
        if obj:IsA("BasePart") then
            local mesh = obj:FindFirstChildOfClass("SpecialMesh")
            if mesh then
                mesh.Scale *= scale
            else
                obj.Size *= scale
            end
        elseif obj:IsA("SpecialMesh") and not obj.Parent:IsA("BasePart") then
            obj.Scale *= scale
        end
    end
end

local function addAppearanceStudioAccessory(model, key)
    local template = runtime.GetAppearanceTemplate(key)
    local humanoid = model and model:FindFirstChildOfClass("Humanoid")
    if not template or not humanoid then return end

    local accessory = template:Clone()
    accessory:SetAttribute("iLunXAppearanceKey", key)
    accessory:SetAttribute("XeroPreviewOnly", true)
    scaleAppearanceStudioAccessory(key, accessory)

    local attached = pcall(function()
        humanoid:AddAccessory(accessory)
    end)

    if not attached or accessory.Parent ~= model then
        accessory.Parent = model
        attached = manualAttachAppearanceAccessory(model, accessory)
    end
    if not attached then
        if accessory.Parent then accessory:Destroy() end
        return
    end

    local weld = runtime.FindAppearanceWeld(accessory)
    if not weld then
        manualAttachAppearanceAccessory(model, accessory)
        runtime.Appearance.AccessoryWeld[accessory] = nil
        weld = runtime.FindAppearanceWeld(accessory)
    end

    if weld then
        local state = runtime.GetAppearanceOffset(key)
        local p = state.Position
        local r = state.Rotation
        local base = weld.C1
        accessory:SetAttribute("XeroPreviewBaseC1", base)
        weld.C1 = base
            * CFrame.new(p.X, p.Y, p.Z)
            * CFrame.Angles(math_rad(r.X), math_rad(r.Y), math_rad(r.Z))
    end
end

function runtime.RefreshAppearanceStudioPreview()
    local studio = runtime.AppearanceStudio
    if not studio or not studio.Viewport then return end

    studio.PreviewSerial = (studio.PreviewSerial or 0) + 1
    local serial = studio.PreviewSerial

    task.spawn(function()
        local model = runtime.GetAppearanceStudioBaseModel()
        if not model then return end
        if not runtime.Alive or not runtime.AppearanceStudio
            or runtime.AppearanceStudio.PreviewSerial ~= serial then
            model:Destroy()
            return
        end

        applyAppearanceStudioBodyLayers(model)
        for _, key in ipairs(runtime.GetEnabledAppearanceEditorKeys()) do
            addAppearanceStudioAccessory(model, key)
        end

        local previewRoot = model:FindFirstChild("HumanoidRootPart")
        for _, obj in ipairs(model:GetDescendants()) do
            if obj:IsA("BasePart") then
                -- Anclar todas las piezas rompe Motor6D/AccessoryWeld y deja
                -- cabeza, cabello y extremidades "flotando". Sólo fijamos el root.
                obj.Anchored = obj == previewRoot
                obj.CanCollide = false
                obj.CanTouch = false
                obj.CanQuery = false
                obj.Massless = true
            end
        end

        local viewport = studio.Viewport
        for _, child in ipairs(viewport:GetChildren()) do
            child:Destroy()
        end

        local worldModel = Instance.new("WorldModel")
        worldModel.Name = "PreviewWorld"
        worldModel.Parent = viewport

        model.Name = "Xero_AvatarPreview"
        model.Parent = worldModel
        pcall(function()
            model:PivotTo(CFrame.new())
        end)
        if previewRoot and previewRoot.Parent then
            previewRoot.Anchored = true
        end
        studio.PreviewModel = model

        local cameraPreview = Instance.new("Camera")
        cameraPreview.Name = "PreviewCamera"
        cameraPreview.FieldOfView = 36
        cameraPreview.Parent = viewport
        viewport.CurrentCamera = cameraPreview
        studio.PreviewCamera = cameraPreview

        local cf, size = model:GetBoundingBox()
        local radius = math.max(size.X, size.Y, size.Z)
        local focus = cf.Position + Vector3.new(0, size.Y * 0.06, 0)

        -- Encuadre tipo editor: calcula distancia con el aspecto real del
        -- ViewportFrame para que el avatar no quede cortado al rotar el teléfono.
        local viewportSize = viewport.AbsoluteSize
        local aspect = math.max(0.45, viewportSize.X / math.max(1, viewportSize.Y))
        local verticalHalf = math.max(0.5, size.Y * 0.52)
        local horizontalHalf = math.max(0.5, size.X * 0.58 / aspect)
        local fitHalf = math.max(verticalHalf, horizontalHalf, size.Z * 0.52)
        local halfFov = math_rad(cameraPreview.FieldOfView * 0.5)
        local defaultDistance = math.max(3.8, (fitHalf / math.max(0.12, math.tan(halfFov))) * 1.18)

        local state = studio.CameraState
        state.Focus = focus
        state.DefaultDistance = defaultDistance
        state.MinDistance = math.max(1.6, defaultDistance * 0.34)
        state.MaxDistance = math.max(18, defaultDistance * 5.5)
        if state.Distance == nil then state.Distance = defaultDistance end
        state.Distance = math.clamp(state.Distance, state.MinDistance, state.MaxDistance)

        if runtime.UpdateAppearanceStudioCamera then
            runtime.UpdateAppearanceStudioCamera()
        else
            cameraPreview.CFrame = CFrame.new(focus + Vector3.new(0, 0, defaultDistance), focus)
        end
    end)
end

-- ==============================================================
-- AVATAR THUMBNAIL SPOOF · EVENT-DRIVEN / SIN RENDERSTEP
-- ============================================================== 
-- Roblox genera sus thumbnails oficiales desde el UserId, por lo que un overlay
-- local no puede cambiar la imagen de cuenta en el backend. Este sistema sustituye
-- visualmente, SOLO en este cliente, las miniaturas del usuario local por un
-- ViewportFrame construido con el clon + Headless + Korblox + limiteds activos.
--
-- Coste: cero loops por frame. Se invalida por eventos de apariencia y sólo
-- reconstruye el snapshot cuando aparece una miniatura o se abre el menú de pausa.
do
    local GuiService = game:GetService("GuiService")
    local CoreGui = game:GetService("CoreGui")

    runtime.AvatarThumbnailSpoof = {
        Dirty = true,
        BuildSerial = 0,
        SnapshotTemplate = nil,
        Targets = setmetatable({}, {__mode = "k"}),
        MenuOpen = false,
        MenuDescendantConnection = nil,
        ScanQueued = false,
        ProfileThumbnailCache = {},
    }

    local spoofState = runtime.AvatarThumbnailSpoof
    local localUserIdText = tostring(player.UserId)
    local localUserName = string_lower(tostring(player.Name or ""))
    local localDisplayName = string_lower(tostring(player.DisplayName or ""))

    local function normalizeGuiText(value)
        local s = tostring(value or "")
        s = s:gsub("<[^>]->", "")
        s = s:gsub("^%s+", ""):gsub("%s+$", "")
        return string_lower(s)
    end

    local function isOurSpoofObject(obj)
        return obj and (obj.Name == "Xero_AvatarThumbnailSpoof"
            or obj:FindFirstAncestor("Xero_AvatarThumbnailSpoof") ~= nil)
    end

    local function destroyTargetSpoof(target)
        local entry = spoofState.Targets[target]
        if not entry then return end
        spoofState.Targets[target] = nil

        -- Restauramos la imagen oficial que ocultamos al montar el reemplazo.
        -- Así cerrar el menú/destruir XeroHub no deja thumbnails transparentes.
        if target and target.Parent and entry.OriginalImageTransparency ~= nil then
            pcall(function()
                target.ImageTransparency = entry.OriginalImageTransparency
            end)
        end

        if entry.Viewport and entry.Viewport.Parent then
            pcall(function() entry.Viewport:Destroy() end)
        end
    end

    local function clearSnapshotTemplate()
        local old = spoofState.SnapshotTemplate
        spoofState.SnapshotTemplate = nil
        if old then pcall(function() old:Destroy() end) end
    end

    local function getCloneTargetUserId()
        local cloneState = runtime.Appearance and runtime.Appearance.AvatarClone
        if not cloneState or not cloneState.Active then return nil end
        local userId = tonumber(cloneState.TargetUserId)
        if not userId or userId <= 0 then return nil end
        return userId
    end

    -- Ruta exacta confirmada por el diagnóstico del CoreGui de Personas.
    -- No depende de tamaños, texto, UserId embebido en otros controles ni heurísticas.
    local function isPeopleAvatarThumbnail(target)
        if not target or not target:IsA("ImageLabel") or target.Name ~= "AvatarThumbnail" then
            return false
        end
        local container = target.Parent
        if not container or container.Name ~= "AvatarThumbnailContainer" then return false end
        local cardThumbnail = container.Parent
        if not cardThumbnail or cardThumbnail.Name ~= "CardThumbnail" then return false end
        local cardContent = cardThumbnail.Parent
        if not cardContent or cardContent.Name ~= "CardContent" then return false end
        return target:IsDescendantOf(CoreGui)
    end

    -- Personas usa exactamente type=Avatar a 150x150 y ScaleType.Stretch.
    -- Usamos la misma URL que usa la tarjeta real del jugador clonado; así no existe
    -- posibilidad de coger por accidente una imagen del hub (por ejemplo Créditos).
    local function getPeopleAvatarThumbnailContent()
        local targetUserId = getCloneTargetUserId()
        if not targetUserId then return nil end
        return "rbxthumb://type=Avatar&id=" .. tostring(targetUserId) .. "&w=150&h=150"
    end

    -- El antiguo buscador heurístico de tarjetas fue retirado: Personas usa la URL
    -- rbxthumb directa por UserId, así que no hace falta escanear CoreGui buscando
    -- la tarjeta del jugador clonado.

    -- El thumbnail oficial de otro usuario sí conserva SU pose de perfil. Sin embargo,
    -- las capas locales de XeroHub no existen en los servidores de thumbnails de Roblox.
    -- Por eso usamos la imagen oficial sólo cuando el clon no tiene overrides locales;
    -- si hay Headless/Korblox/limiteds, conservamos el renderer 3D para que sí aparezcan.
    local function hasLocalThumbnailOverrides()
        local appearance = runtime.Appearance
        local enabled = appearance and appearance.Enabled
        if not enabled then return false end
        for _, state in pairs(enabled) do
            if state == true then return true end
        end
        return false
    end

    local function canUseExactCloneProfileThumbnail()
        return getCloneTargetUserId() ~= nil and not hasLocalThumbnailOverrides()
    end

    local function getClonedProfileThumbnail(mode)
        if not canUseExactCloneProfileThumbnail() then return nil end
        local targetUserId = getCloneTargetUserId()
        local cacheKey = tostring(targetUserId) .. ":" .. tostring(mode or "full")
        local cached = spoofState.ProfileThumbnailCache[cacheKey]
        if cached then return cached end

        local thumbnailType = Enum.ThumbnailType.AvatarThumbnail
        if mode == "head" then
            thumbnailType = Enum.ThumbnailType.HeadShot
        elseif mode == "bust" then
            thumbnailType = Enum.ThumbnailType.AvatarBust
        end

        local ok, content = pcall(function()
            local image = Players:GetUserThumbnailAsync(
                targetUserId,
                thumbnailType,
                Enum.ThumbnailSize.Size420x420
            )
            return image
        end)

        if ok and content and content ~= "" then
            spoofState.ProfileThumbnailCache[cacheKey] = content
            return content
        end

        -- Fallback nativo: sigue siendo un thumbnail generado por Roblox y no un rig tieso.
        local typeName = mode == "head" and "AvatarHeadShot"
            or (mode == "bust" and "AvatarBust" or "Avatar")
        content = "rbxthumb://type=" .. typeName
            .. "&id=" .. tostring(targetUserId) .. "&w=420&h=420"
        spoofState.ProfileThumbnailCache[cacheKey] = content
        return content
    end

    -- Si hay limiteds/Headless/Korblox locales no podemos usar la imagen 2D oficial porque
    -- no los contiene. Como fallback 3D, copiamos UNA VEZ la pose animada actual del
    -- jugador clonado (Motor6D.Transform). No crea ninguna conexión por frame.
    local function applyLiveClonePose(model)
        local targetUserId = getCloneTargetUserId()
        if not targetUserId or not model then return false end

        local targetPlayer = nil
        for _, candidate in ipairs(Players:GetPlayers()) do
            if candidate.UserId == targetUserId then
                targetPlayer = candidate
                break
            end
        end
        local sourceChar = targetPlayer and targetPlayer.Character
        if not sourceChar then return false end

        local destinationMotors = {}
        for _, obj in ipairs(model:GetDescendants()) do
            if obj:IsA("Motor6D") then
                local p0 = obj.Part0 and obj.Part0.Name or ""
                local p1 = obj.Part1 and obj.Part1.Name or ""
                destinationMotors[obj.Name .. "|" .. p0 .. "|" .. p1] = obj
            end
        end

        local copied = 0
        for _, sourceMotor in ipairs(sourceChar:GetDescendants()) do
            if sourceMotor:IsA("Motor6D") then
                local p0 = sourceMotor.Part0 and sourceMotor.Part0.Name or ""
                local p1 = sourceMotor.Part1 and sourceMotor.Part1.Name or ""
                local destination = destinationMotors[sourceMotor.Name .. "|" .. p0 .. "|" .. p1]
                if destination then
                    pcall(function() destination.Transform = sourceMotor.Transform end)
                    copied += 1
                end
            end
        end
        return copied > 0
    end

    local function buildSnapshotModel()
        local char = player.Character
        local humanoid = char and char:FindFirstChildOfClass("Humanoid")
        local rigType = humanoid and humanoid.RigType or Enum.HumanoidRigType.R15
        local cloneState = runtime.Appearance and runtime.Appearance.AvatarClone
        local model = nil

        -- Si hay clon activo, ÉSE es la base visual. No usamos el Character real,
        -- porque está escondido debajo del overlay y sigue conservando nuestro avatar.
        if cloneState and cloneState.Active and cloneState.Template then
            local ok, cloned = pcall(function() return cloneState.Template:Clone() end)
            if ok then model = cloned end
        end

        -- Avatar propio: preferimos la descripción ya aplicada para no pedir datos
        -- de red si Roblox ya la tiene en el Humanoid actual.
        if not model and humanoid then
            local okDesc, description = pcall(function()
                return humanoid:GetAppliedDescription()
            end)
            if okDesc and description then
                model = select(1, runtime.CreateAvatarCloneTemplateFromDescription(description, rigType))
                pcall(function() description:Destroy() end)
            end
        end

        if not model then
            model = select(1, runtime.CreateAvatarCloneTemplateFromUserId(player.UserId, rigType))
        end
        if not model then return nil end

        model = prepareAppearanceStudioBaseModel(model)
        if not model then return nil end

        applyAppearanceStudioBodyLayers(model)
        for _, key in ipairs(runtime.GetEnabledAppearanceEditorKeys()) do
            addAppearanceStudioAccessory(model, key)
        end

        if cloneState and cloneState.Active then
            applyLiveClonePose(model)
        end

        local root = model:FindFirstChild("HumanoidRootPart")
        for _, obj in ipairs(model:GetDescendants()) do
            if obj:IsA("BasePart") then
                obj.CanCollide = false
                obj.CanTouch = false
                obj.CanQuery = false
                obj.Massless = true
                obj.AssemblyLinearVelocity = Vector3.zero
                obj.AssemblyAngularVelocity = Vector3.zero
                obj.Anchored = obj == root
            elseif obj:IsA("Script") or obj:IsA("LocalScript") or obj:IsA("ModuleScript") then
                pcall(function() obj:Destroy() end)
            end
        end

        model.Name = "Xero_ThumbnailSnapshot"
        model.Parent = nil
        return model
    end

    local function getAccessoryHeadParts(model, head)
        local parts = {head}
        for _, accessory in ipairs(model:GetChildren()) do
            if accessory:IsA("Accoutrement") then
                local handle = accessory:FindFirstChild("Handle")
                local weld = handle and (handle:FindFirstChild("AccessoryWeld")
                    or handle:FindFirstChild("iLunXAppearanceWeld"))
                local attachedToHead = weld and (weld.Part0 == head or weld.Part1 == head)
                if attachedToHead then
                    for _, obj in ipairs(accessory:GetDescendants()) do
                        if obj:IsA("BasePart") then
                            parts[#parts + 1] = obj
                        end
                    end
                end
            end
        end
        return parts
    end

    local function getPartsAABB(parts)
        local minV, maxV
        for _, part in ipairs(parts) do
            if part and part:IsA("BasePart") and part.Parent then
                local cf = part.CFrame
                local half = part.Size * 0.5
                for sx = -1, 1, 2 do
                    for sy = -1, 1, 2 do
                        for sz = -1, 1, 2 do
                            local p = cf:PointToWorldSpace(Vector3.new(half.X * sx, half.Y * sy, half.Z * sz))
                            if not minV then
                                minV, maxV = p, p
                            else
                                minV = Vector3.new(math.min(minV.X, p.X), math.min(minV.Y, p.Y), math.min(minV.Z, p.Z))
                                maxV = Vector3.new(math.max(maxV.X, p.X), math.max(maxV.Y, p.Y), math.max(maxV.Z, p.Z))
                            end
                        end
                    end
                end
            end
        end
        if not minV then return nil, nil end
        return (minV + maxV) * 0.5, maxV - minV
    end

    local function classifyThumbnail(target, forcedMode)
        if forcedMode then return forcedMode end

        -- El diagnóstico del CoreGui nos dio una ruta estable para Personas.
        -- Esta estructura SIEMPRE es avatar de cuerpo completo, aunque AbsoluteSize
        -- todavía sea 0/20 durante el primer frame de montaje del menú.
        if isPeopleAvatarThumbnail(target) then
            return "full"
        end

        -- IMPORTANTE: el menú Personas puede montar una tarjeta GRANDE usando una
        -- URL interna de HeadShot como placeholder/origen. Si miramos primero la URL,
        -- terminamos pidiendo el HeadShot del avatar clonado y sale la cara gigante.
        -- La geometría del control manda: una tarjeta grande es preview de cuerpo.
        local size = target and target.AbsoluteSize or Vector2.new(0, 0)
        if math.max(size.X, size.Y) >= 130 then return "full" end

        local image = ""
        if target and (target:IsA("ImageLabel") or target:IsA("ImageButton")) then
            pcall(function() image = string_lower(target.Image or "") end)
        end
        if string_find(image, "avatarthumbnail", 1, true) then return "full" end
        if string_find(image, "avatarbust", 1, true) then return "bust" end
        if string_find(image, "headshot", 1, true) then return "head" end
        return "head"
    end

    local function renderSnapshot(viewport, mode)
        if not viewport or not viewport.Parent then return end

        for _, child in ipairs(viewport:GetChildren()) do
            if child.Name == "XeroThumbWorld" or child.Name == "XeroThumbCamera"
                or child.Name == "XeroCloneProfileImage" then
                pcall(function() child:Destroy() end)
            end
        end

        -- PERSONAS: usamos la URL exacta que el propio CoreGui usa para las tarjetas.
        -- Nada de clonar ImageLabels del árbol global: gethui puede vivir bajo CoreGui y
        -- eso permitía que una imagen del hub (como la foto de Créditos) terminara aquí.
        if mode == "full"
            and isPeopleAvatarThumbnail(viewport.Parent)
            and canUseExactCloneProfileThumbnail() then
            local content = getPeopleAvatarThumbnailContent()
            if content then
                local image = Instance.new("ImageLabel")
                image.Name = "XeroCloneProfileImage"
                image.Size = UDim2.fromScale(1, 1)
                image.Position = UDim2.fromScale(0, 0)
                image.AnchorPoint = Vector2.new(0, 0)
                image.BackgroundTransparency = 1
                image.BorderSizePixel = 0
                image.Image = content
                image.ScaleType = Enum.ScaleType.Stretch
                image.ImageRectOffset = Vector2.new(0, 0)
                image.ImageRectSize = Vector2.new(0, 0)
                image.ZIndex = viewport.ZIndex
                image.Active = false
                image.Selectable = false
                pcall(function() image.Interactable = false end)
                image.Parent = viewport
                return
            end
        end

        -- Fallback cuando el usuario clonado no está en la lista visible del servidor:
        -- pedimos el thumbnail oficial de Roblox.
        local clonedProfileImage = getClonedProfileThumbnail(mode)
        if clonedProfileImage then
            local image = Instance.new("ImageLabel")
            image.Name = "XeroCloneProfileImage"
            image.Size = UDim2.fromScale(1, 1)
            image.Position = UDim2.fromScale(0, 0)
            image.BackgroundTransparency = 1
            image.BorderSizePixel = 0
            image.Image = clonedProfileImage
            image.ScaleType = Enum.ScaleType.Fit
            image.ZIndex = viewport.ZIndex
            image.Parent = viewport
            return
        end

        local template = spoofState.SnapshotTemplate
        if not template then return end

        local okClone, model = pcall(function() return template:Clone() end)
        if not okClone or not model then return end

        local worldModel = Instance.new("WorldModel")
        worldModel.Name = "XeroThumbWorld"
        worldModel.Parent = viewport
        model.Parent = worldModel
        pcall(function() model:PivotTo(CFrame.new()) end)

        local cameraPreview = Instance.new("Camera")
        cameraPreview.Name = "XeroThumbCamera"
        cameraPreview.FieldOfView = mode == "head" and 28 or 34
        cameraPreview.Parent = viewport
        viewport.CurrentCamera = cameraPreview

        local focus, size
        if mode == "head" then
            local head = model:FindFirstChild("Head")
            if head and head:IsA("BasePart") then
                focus, size = getPartsAABB(getAccessoryHeadParts(model, head))
            end
        elseif mode == "bust" then
            local parts = {}
            for _, name in ipairs({"Head", "UpperTorso", "Torso", "LeftUpperArm", "RightUpperArm", "Left Arm", "Right Arm"}) do
                local part = model:FindFirstChild(name)
                if part and part:IsA("BasePart") then parts[#parts + 1] = part end
            end
            local head = model:FindFirstChild("Head")
            if head and head:IsA("BasePart") then
                for _, p in ipairs(getAccessoryHeadParts(model, head)) do parts[#parts + 1] = p end
            end
            focus, size = getPartsAABB(parts)
        end

        if not focus or not size then
            local cf, fullSize = model:GetBoundingBox()
            focus, size = cf.Position, fullSize
        end

        if mode == "full" then
            focus += Vector3.new(0, size.Y * 0.04, 0)
        elseif mode == "bust" then
            focus += Vector3.new(0, size.Y * 0.03, 0)
        end

        local vpSize = viewport.AbsoluteSize
        local aspect = math.max(0.55, vpSize.X / math.max(1, vpSize.Y))
        local verticalHalf = math.max(0.35, size.Y * 0.53)
        local horizontalHalf = math.max(0.35, size.X * 0.56 / aspect)
        local depthHalf = math.max(0.2, size.Z * 0.5)
        local fitHalf = math.max(verticalHalf, horizontalHalf, depthHalf)
        local halfFov = math_rad(cameraPreview.FieldOfView * 0.5)
        local distance = math.max(1.5, (fitHalf / math.max(0.12, math.tan(halfFov))) * 1.13)

        -- Los rigs Roblox miran hacia -Z. La cámara debe colocarse delante
        -- (también en -Z), no detrás en +Z; de lo contrario el thumbnail sale de espaldas.
        cameraPreview.CFrame = CFrame.new(focus + Vector3.new(0, 0, -distance), focus)
    end

    local function refreshAllTargets()
        if not canUseExactCloneProfileThumbnail()
            and (spoofState.Dirty or not spoofState.SnapshotTemplate) then return end
        for target, entry in pairs(spoofState.Targets) do
            if not target or not target.Parent or not entry.Viewport or not entry.Viewport.Parent then
                destroyTargetSpoof(target)
            else
                renderSnapshot(entry.Viewport, entry.Mode)
            end
        end
    end

    local function queueSnapshotBuild(delaySeconds)
        if not runtime.Alive then return end
        -- Debounce real por serial: pueden llegar muchos cambios del editor, pero
        -- sólo el último callback llega a construir un Model. Los anteriores salen
        -- antes de tocar HumanoidDescription/assets.
        spoofState.BuildSerial += 1
        local serial = spoofState.BuildSerial

        task.delay(delaySeconds or 0.02, function()
            if not runtime.Alive or serial ~= spoofState.BuildSerial then return end
            local model = buildSnapshotModel()
            if not runtime.Alive or serial ~= spoofState.BuildSerial then
                if model then pcall(function() model:Destroy() end) end
                return
            end
            if not model then return end

            clearSnapshotTemplate()
            spoofState.SnapshotTemplate = model
            spoofState.Dirty = false
            refreshAllTargets()
        end)
    end

    function runtime.MarkAvatarThumbnailSpoofDirty(fromContinuousSlider)
        if not runtime.Alive then return end
        spoofState.Dirty = true
        clearSnapshotTemplate()
        table.clear(spoofState.ProfileThumbnailCache)

        if spoofState.MenuOpen or next(spoofState.Targets) ~= nil then
            if canUseExactCloneProfileThumbnail() then
                -- No hace falta construir ningún rig: el thumbnail del objetivo ya
                -- contiene su pose de perfil y se refresca de inmediato.
                refreshAllTargets()
            else
                -- Sliders esperan a que haya una pausa corta; toggles/clonado refrescan
                -- casi inmediatamente. En ambos casos sigue siendo 100% por eventos.
                queueSnapshotBuild(fromContinuousSlider and 0.18 or 0.025)
            end
        else
            -- También invalida cualquier build pendiente aunque no haya thumbnails.
            spoofState.BuildSerial += 1
        end
    end

    local function imageReferencesLocalUser(target)
        if not target or (not target:IsA("ImageLabel") and not target:IsA("ImageButton")) then
            return false
        end
        local image = ""
        local ok = pcall(function() image = string_lower(target.Image or "") end)
        if not ok or image == "" then return false end
        if not string_find(image, localUserIdText, 1, true) then return false end
        return string_find(image, "avatar", 1, true) ~= nil
            or string_find(image, "headshot", 1, true) ~= nil
            or string_find(image, "thumb", 1, true) ~= nil
    end

    local function attachSpoofToTarget(target, forcedMode)
        if not runtime.Alive or not target or not target.Parent or isOurSpoofObject(target) then return false end
        local current = spoofState.Targets[target]
        local mode = classifyThumbnail(target, forcedMode)
        if current and current.Viewport and current.Viewport.Parent then
            -- CoreGui puede volver a escribir la miniatura al navegar entre paneles.
            -- El reemplazo debe seguir siendo exclusivo: nunca dejamos la imagen
            -- oficial debajo del ViewportFrame, que era lo que generaba dos avatares.
            pcall(function() target.ImageTransparency = 1 end)
            if current.Mode ~= mode then
                current.Mode = mode
                if canUseExactCloneProfileThumbnail() or not spoofState.Dirty then
                    renderSnapshot(current.Viewport, mode)
                end
            end
            return true
        end

        local originalImageTransparency = nil
        pcall(function()
            originalImageTransparency = target.ImageTransparency
            target.ImageTransparency = 1
        end)

        local viewport = Instance.new("ViewportFrame")
        viewport.Name = "Xero_AvatarThumbnailSpoof"
        viewport.Size = UDim2.fromScale(1, 1)
        viewport.Position = UDim2.fromScale(0, 0)
        viewport.AnchorPoint = Vector2.new(0, 0)
        viewport.BackgroundTransparency = 1
        viewport.BorderSizePixel = 0
        viewport.ClipsDescendants = true
        viewport.ZIndex = (target.ZIndex or 1) + 8
        viewport.Active = false
        viewport.Selectable = false
        viewport.Ambient = Color3.fromRGB(185, 185, 185)
        viewport.LightColor = Color3.fromRGB(255, 255, 255)
        viewport.LightDirection = Vector3.new(-1, -1, -1)
        pcall(function() viewport.Interactable = false end)

        local corner = target:FindFirstChildOfClass("UICorner")
        if corner then
            pcall(function()
                local clonedCorner = corner:Clone()
                clonedCorner.Parent = viewport
            end)
        end

        local parented = pcall(function() viewport.Parent = target end)
        if not parented or viewport.Parent ~= target then
            if originalImageTransparency ~= nil then
                pcall(function() target.ImageTransparency = originalImageTransparency end)
            end
            pcall(function() viewport:Destroy() end)
            return false
        end

        spoofState.Targets[target] = {
            Viewport = viewport,
            Mode = mode,
            OriginalImageTransparency = originalImageTransparency,
        }
        runtime.Track(target.AncestryChanged:Connect(function(_, parent)
            if not parent then destroyTargetSpoof(target) end
        end))

        if canUseExactCloneProfileThumbnail() then
            renderSnapshot(viewport, mode)
        elseif spoofState.Dirty or not spoofState.SnapshotTemplate then
            queueSnapshotBuild(0.01)
        else
            renderSnapshot(viewport, mode)
        end
        return true
    end

    local function guiLooksLikeLocalName(obj)
        if not obj or (not obj:IsA("TextLabel") and not obj:IsA("TextButton")) then return false end
        local text = normalizeGuiText(obj.Text)
        if text == "" then return false end
        return text == localUserName
            or text == localDisplayName
            or text == ("@" .. localUserName)
    end

    local function candidateImageScore(gui)
        if not gui or (not gui:IsA("ImageLabel") and not gui:IsA("ImageButton")) then return nil end
        if isOurSpoofObject(gui) then return nil end

        -- ConnectButton/CardDetails son ImageButtons pero no son thumbnails.
        -- El diagnóstico mostró que el fallback por nombre los estaba capturando.
        local image = ""
        pcall(function() image = string_lower(gui.Image or "") end)
        if image == "" then return nil end

        local size = gui.AbsoluteSize
        if size.X < 28 or size.Y < 28 or size.X > 260 or size.Y > 260 then return nil end
        local ratio = size.X / math.max(1, size.Y)
        if ratio < 0.68 or ratio > 1.48 then return nil end
        local area = size.X * size.Y
        local score = area
        if imageReferencesLocalUser(gui) then score += 100000 end
        return score
    end

    local function patchNearestAvatarForNameLabel(label)
        local ancestor = label
        for _ = 1, 7 do
            ancestor = ancestor and ancestor.Parent
            if not ancestor or ancestor == CoreGui then break end
            if ancestor:IsA("GuiObject") then
                local abs = ancestor.AbsoluteSize
                -- Evita subir hasta un contenedor enorme con filas de todos los jugadores.
                if abs.X > 0 and abs.Y > 0 and abs.Y <= 420 then
                    local best, bestScore
                    for _, obj in ipairs(ancestor:GetDescendants()) do
                        local score = candidateImageScore(obj)
                        if score and (not bestScore or score > bestScore) then
                            best, bestScore = obj, score
                        end
                    end
                    if best then
                        attachSpoofToTarget(best)
                        return true
                    end
                end
            end
        end
        return false
    end

    local function scanRoot(root, includeNameFallback)
        if not root then return end
        local ok, descendants = pcall(function() return root:GetDescendants() end)
        if not ok or not descendants then return end

        -- Una sola pasada: antes recorríamos TODO CoreGui dos veces por escaneo.
        for _, obj in ipairs(descendants) do
            if imageReferencesLocalUser(obj) then
                attachSpoofToTarget(obj)
            elseif includeNameFallback and guiLooksLikeLocalName(obj) then
                patchNearestAvatarForNameLabel(obj)
            end
        end
    end

    local function queueMenuScan(delaySeconds)
        if spoofState.ScanQueued then return end
        spoofState.ScanQueued = true
        task.delay(delaySeconds or 0.02, function()
            spoofState.ScanQueued = false
            if not runtime.Alive or not spoofState.MenuOpen then return end
            scanRoot(CoreGui, true)
        end)
    end

    local function bindMenuDescendantWatcher()
        if spoofState.MenuDescendantConnection then
            pcall(function() spoofState.MenuDescendantConnection:Disconnect() end)
            spoofState.MenuDescendantConnection = nil
        end
        spoofState.MenuDescendantConnection = CoreGui.DescendantAdded:Connect(function(obj)
            if not spoofState.MenuOpen or isOurSpoofObject(obj) then return end
            if obj:IsA("ImageLabel") or obj:IsA("ImageButton") then
                task.defer(function()
                    if obj.Parent and imageReferencesLocalUser(obj) then
                        attachSpoofToTarget(obj)
                    else
                        queueMenuScan(0.035)
                    end
                end)
            elseif obj:IsA("TextLabel") or obj:IsA("TextButton") then
                queueMenuScan(0.035)
            end
        end)
    end

    local function clearPauseOnlyTargets()
        -- Las imágenes directas del propio hub pueden seguir mostrando el snapshot.
        -- Al cerrar pausa sólo quitamos objetivos que pertenecen a CoreGui Roblox.
        for target in pairs(spoofState.Targets) do
            if target and target:IsDescendantOf(CoreGui) then
                destroyTargetSpoof(target)
            end
        end
    end

    runtime.Track(GuiService.MenuOpened:Connect(function()
        spoofState.MenuOpen = true
        bindMenuDescendantWatcher()
        if not canUseExactCloneProfileThumbnail()
            and (spoofState.Dirty or not spoofState.SnapshotTemplate) then
            queueSnapshotBuild(0.01)
        end
        task.defer(function() if spoofState.MenuOpen then scanRoot(CoreGui, true) end end)
        -- Un segundo pase coalescido cubre el montaje tardío del menú. DescendantAdded
        -- se encarga de lo que aparezca después, sin un tercer barrido completo fijo.
        queueMenuScan(0.08)
    end))

    runtime.Track(GuiService.MenuClosed:Connect(function()
        spoofState.MenuOpen = false
        if spoofState.MenuDescendantConnection then
            pcall(function() spoofState.MenuDescendantConnection:Disconnect() end)
            spoofState.MenuDescendantConnection = nil
        end
        clearPauseOnlyTargets()
    end))

    -- Miniaturas directas fuera del menú (por ejemplo la tarjeta de perfil del hub).
    -- Sólo reacciona a objetos añadidos; no existe polling.
    local roots = {playerGui}
    local okHidden, hiddenRoot = pcall(function()
        return gethui and gethui() or nil
    end)
    if okHidden and hiddenRoot and hiddenRoot ~= playerGui and hiddenRoot ~= CoreGui then
        roots[#roots + 1] = hiddenRoot
    end

    for _, root in ipairs(roots) do
        scanRoot(root, false)
        runtime.Track(root.DescendantAdded:Connect(function(obj)
            if isOurSpoofObject(obj) then return end
            if obj:IsA("ImageLabel") or obj:IsA("ImageButton") then
                task.delay(0.02, function()
                    if runtime.Alive and obj.Parent and imageReferencesLocalUser(obj) then
                        attachSpoofToTarget(obj)
                    end
                end)
            end
        end))
    end

    runtime.AvatarThumbnailSpoofCleanup = function()
        spoofState.MenuOpen = false
        if spoofState.MenuDescendantConnection then
            pcall(function() spoofState.MenuDescendantConnection:Disconnect() end)
            spoofState.MenuDescendantConnection = nil
        end
        for target in pairs(spoofState.Targets) do
            destroyTargetSpoof(target)
        end
        clearSnapshotTemplate()
    end

    -- Construye una vez después del arranque si ya existe una miniatura propia.
    if next(spoofState.Targets) ~= nil then
        queueSnapshotBuild(0.03)
    end
end

function runtime.RefreshAppearanceStudio()
    local studio = runtime.AppearanceStudio
    if not studio then return end

    local keys = runtime.GetEnabledAppearanceEditorKeys()
    local current = studio.SelectedKey
    local stillValid = false
    for _, key in ipairs(keys) do
        if key == current then
            stillValid = true
            break
        end
    end
    if not stillValid then
        studio.SelectedKey = keys[1]
    end

    for _, child in ipairs(studio.AccessoryList:GetChildren()) do
        if child:IsA("GuiObject") then
            child:Destroy()
        end
    end

    studio.NoActiveLabel.Visible = false
    studio.AccessoryList.Visible = false
    studio.AccessorySelectorArrow.Text = "⌄"

    for _, key in ipairs(keys) do
        local asset = runtime.AppearanceCatalog[key]
        local row = Instance.new("TextButton")
        row.Size = UDim2.new(1, -2, 0, 32)
        row.BackgroundColor3 = (studio.SelectedKey == key) and Color3.fromRGB(236, 236, 236) or Color3.fromRGB(18, 18, 18)
        row.BorderSizePixel = 0
        row.Text = asset and asset.Name or key
        row.TextColor3 = (studio.SelectedKey == key) and Color3.fromRGB(12, 12, 12) or Color3.fromRGB(235, 235, 235)
        row.Font = Enum.Font.GothamMedium
        row.TextSize = 11
        row.AutoButtonColor = false
        row.ZIndex = 604
        row.Parent = studio.AccessoryList
        Instance.new("UICorner", row).CornerRadius = UDim.new(0, 10)
        row.Activated:Connect(function()
            studio.SelectedKey = key
            studio.AccessoryList.Visible = false
            studio.AccessorySelectorArrow.Text = "⌄"
            task.defer(runtime.RefreshAppearanceStudio)
        end)
    end

    studio.Syncing = true
    if studio.SelectedKey then
        local asset = runtime.AppearanceCatalog[studio.SelectedKey]
        local state = runtime.GetAppearanceOffset(studio.SelectedKey)
        studio.TargetTitle.Text = "Limited activo"
        studio.AccessorySelector.Text = asset and asset.Name or studio.SelectedKey
        studio.AccessorySelector.TextColor3 = Color3.fromRGB(240, 240, 240)
        local values = {
            X = state.Position.X,
            Y = state.Position.Y,
            Z = state.Position.Z,
            RX = state.Rotation.X,
            RY = state.Rotation.Y,
            RZ = state.Rotation.Z,
            SCALE = tonumber(state.Scale) or 1,
        }
        for component, control in pairs(studio.Controls) do
            local value = values[component]
            if value ~= nil then
                control:Set(value, true)
            end
        end
    else
        studio.TargetTitle.Text = "Limited activo"
        studio.AccessorySelector.Text = "Sin limiteds activos"
        studio.AccessorySelector.TextColor3 = Color3.fromRGB(132, 132, 138)
        for component, control in pairs(studio.Controls) do
            control:Set(component == "SCALE" and 1 or 0, true)
        end
    end
    studio.Syncing = false

    task.defer(runtime.RefreshAppearanceStudioPreview)
end

function runtime.OpenAppearanceStudio(initialKey)
    runtime.EnsureAppearanceStudio()
    local studio = runtime.AppearanceStudio
    if initialKey then
        studio.SelectedKey = initialKey
    end

    -- Siempre por encima del hub y con fondo negro; sólo se ve el avatar
    -- generado dentro del ViewportFrame, no el Character del juego.
    if runtime.AppearanceStudioGui then
        runtime.AppearanceStudioGui.DisplayOrder = 2147483647
    end

    studio.AccessoryList.Visible = false
    studio.AccessorySelectorArrow.Text = "⌄"
    if runtime.BeginAppearanceStudioChanges then
        runtime.BeginAppearanceStudioChanges()
    end
    studio.Overlay.Visible = true
    local targetScale = runtime.ApplyAppearanceStudioResponsiveLayout()
    studio.Scale.Scale = targetScale * 0.975
    runtime.RefreshAppearanceStudio()
    TweenService:Create(
        studio.Scale,
        TweenInfo.new(0.16, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
        {Scale = targetScale}
    ):Play()
end

for _, category in ipairs(runtime.AppearanceCategories) do
    local categorySection = Tabs.Apariencia:Section({Title = category})
    placeAppearanceElement(categorySection, nextAppearanceOrder())

    for _, key in ipairs(runtime.AppearanceOrder) do
        local asset = runtime.AppearanceCatalog[key]

        if asset and asset.Kind == "Accessory" and asset.Category == category then
            local capturedKey = key
            local baseOrder = nextAppearanceOrder()

            local toggle = Tabs.Apariencia:Toggle({
                Title = asset.Name,
                Value = false,
                Callback = function(state)
                    runtime.SetAppearance(capturedKey, state)
                end,
            })

            placeAppearanceElement(toggle, baseOrder)
            runtime.Appearance.ToggleElements[capturedKey] = toggle
            runtime.Appearance.EditorSlots[capturedKey] = {
                BaseOrder = baseOrder,
                Controls = nil,
            }

            if capturedKey == "RC" then UIElements.TogAppearanceRC = toggle end
            if capturedKey == "Fiery" then UIElements.TogAppearanceFiery = toggle end
            if capturedKey == "Poisoned" then UIElements.TogAppearancePoisoned = toggle end
        end
    end
end

local restoreAppearanceButton = Tabs.Apariencia:Button({
    Title = "Restaurar apariencia completa",
    Desc = "Restaura tu avatar base y quita Headless, Korblox, HideHair y todos los limiteds aplicados por XeroHub.",
    Callback = function()
        runtime.RestoreAppearance()
        local wasSuppressed = runtime.SuppressNotifications
        runtime.SuppressNotifications = true
        for _, key in ipairs(runtime.AppearanceOrder) do
            local toggle = runtime.Appearance.ToggleElements[key]
            if toggle then pcall(function() toggle:Set(false) end) end
        end
        runtime.SuppressNotifications = wasSuppressed
        runtime.RefreshAppearanceControls()
        showBottomMessage("Apariencia restaurada.")
    end,
})
placeAppearanceElement(restoreAppearanceButton, nextAppearanceOrder())

runtime.RefreshAppearanceControls()


local aimHookState = runtimeEnv.__ILUNX_AIM_HOOK_STATE
if not aimHookState then
    aimHookState = {Target = nil, Mouse = mouse, Owner = runtime}
    runtimeEnv.__ILUNX_AIM_HOOK_STATE = aimHookState

    local oldNamecall
    oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
        local target = aimHookState.Target
        if not checkcaller() and target then
            -- 🔥 FIX: Quitamos IsDescendantOf, que era lo que crasheaba el juego
            if target.Parent then 
                local method = getnamecallmethod()
                if self == workspace then
                    if method == "Raycast" then
                        local origin, direction, p3 = ...
                        if typeof(direction) == "Vector3" and direction.Magnitude > 5 and (origin - workspace.CurrentCamera.CFrame.Position).Magnitude > 1 then
                            local newDir = (target.Position - origin).Unit * 5000
                            return oldNamecall(self, origin, newDir, p3)
                        end
                    elseif method == "FindPartOnRay" or method == "FindPartOnRayWithIgnoreList" then
                        local ray, p2, p3, p4 = ...
                        if typeof(ray) == "Ray" and ray.Direction.Magnitude > 5 and (ray.Origin - workspace.CurrentCamera.CFrame.Position).Magnitude > 1 then
                            local newRay = Ray.new(ray.Origin, (target.Position - ray.Origin).Unit * 5000)
                            return oldNamecall(self, newRay, p2, p3, p4)
                        end
                    end
                end
            else
                aimHookState.Target = nil
            end
        end
        return oldNamecall(self, ...)
    end)

    local oldIndex
    oldIndex = hookmetamethod(game, "__index", function(t, k)
        local target = aimHookState.Target
        if not checkcaller() and t == aimHookState.Mouse and target and target.Parent then
            if k == "Hit" or k == "hit" then return target.CFrame
            elseif k == "Target" or k == "target" then return target end
        end
        return oldIndex(t, k)
    end)
else
    aimHookState.Target = nil
    aimHookState.Mouse = mouse
    aimHookState.Owner = runtime
end

runtime.AimState = aimHookState

-- ==========================================
-- MEMORIA DEL ESP (OBLIGATORIO ANTES DEL HILO)
-- ==========================================
local activeESPs = {} 
local MAX_ESP_DISTANCE = 1500 

function cleanESP(targetPlayer)
    if activeESPs[targetPlayer] then
        if activeESPs[targetPlayer].Highlight then activeESPs[targetPlayer].Highlight:Destroy() end
        if activeESPs[targetPlayer].Billboard then activeESPs[targetPlayer].Billboard:Destroy() end
        activeESPs[targetPlayer] = nil
    end
end

local function hideESP(targetPlayer)
    local espObj = activeESPs[targetPlayer]
    if not espObj then return end
    if espObj.Highlight and espObj.Highlight.Enabled then espObj.Highlight.Enabled = false end
    if espObj.Billboard and espObj.Billboard.Enabled then espObj.Billboard.Enabled = false end
    -- Fuerza una sola reconstrucción de texto al volver a ser válido, sin destruir Instances.
    espObj.LastDistance = -1
end


-- ==========================================
-- 🚀 HILO MAESTRO DE OPTIMIZACIÓN (CERO LAG)
-- ==========================================

-- Agrupamos todo en UNA SOLA tabla para no rebasar el límite de 200 locales de Lua
local mState = {
    tHB = 0, tESP = 0, tAS = 0, tSA = 0,
    hbAct = false, espAct = false, asAct = false, saAct = false,
    espHex = "#FFFFFF", lastEspColor = espColor,
    pHB = RaycastParams.new(),
    pAS = RaycastParams.new(),
    pSA = RaycastParams.new(),
    igHB = {},
    igAS = {}, objAS = {}, scAS = {}, seenAS = {},
    poolAS = {},
    igSA = {}, scSA = {}, seenSA = {},
    hbBlockedColor = Color3_fromRGB(255, 50, 50),
    hbByChar = setmetatable({}, {__mode = "k"}),
    hbAdornment = setmetatable({}, {__mode = "k"}),
    charCore = setmetatable({}, {__mode = "k"}),
    vpX = -1, vpY = -1, centerX = 0, centerY = 0,
    maxEspDistanceSq = MAX_ESP_DISTANCE * MAX_ESP_DISTANCE,
}
mState.pHB.FilterType = Enum.RaycastFilterType.Exclude
mState.pAS.FilterType = Enum.RaycastFilterType.Exclude
mState.pSA.FilterType = Enum.RaycastFilterType.Exclude

local function getCharCore(char)
    if not char then return nil end
    local core = mState.charCore[char]
    if core and core.Humanoid and core.Humanoid.Parent == char and core.HRP and core.HRP.Parent == char then
        if not core.Head or core.Head.Parent ~= char then core.Head = ffc(char, "Head") end
        if not core.LeftFoot or core.LeftFoot.Parent ~= char then core.LeftFoot = ffc(char, "LeftFoot") or ffc(char, "LeftLeg") end
        if not core.RightFoot or core.RightFoot.Parent ~= char then core.RightFoot = ffc(char, "RightFoot") or ffc(char, "RightLeg") end
        return core
    end
    core = {
        Humanoid = ffc(char, "Humanoid") or char:FindFirstChildOfClass("Humanoid"),
        HRP = ffc(char, "HumanoidRootPart"),
        Head = ffc(char, "Head"),
        LeftFoot = ffc(char, "LeftFoot") or ffc(char, "LeftLeg"),
        RightFoot = ffc(char, "RightFoot") or ffc(char, "RightLeg"),
    }
    mState.charCore[char] = core
    return core
end

local function enemigoEnLobby(enemyChar, enemyHrp)
    if enemyChar:FindFirstChildOfClass("ForceField") then return true end
    local core = enemyHrp and nil or getCharCore(enemyChar)
    local eHrp = enemyHrp or (core and core.HRP)
    if eHrp then
        for _, zona in ipairs(ZONAS_SEGURAS) do
            local delta = eHrp.Position - zona.Centro
            if delta:Dot(delta) <= (zona.Radio * zona.Radio) then return true end
        end
    end
    return false
end


-- Variables en caché fuera del Heartbeat
local enLobby = false
local timerLobby = 0

runtime.Track(RunService.Heartbeat:Connect(function(deltaTime)
    local camera = workspace.CurrentCamera -- 🔥 FIX: Siempre la cámara actual
    timerLobby = timerLobby + deltaTime
    if timerLobby >= 1 then
        timerLobby = 0
        pcall(function() enLobby = estaEnLobby() end)
    end

    -- ==========================================
    -- 1. HITBOX (0.15s) - FIX VISUAL + WELD
    -- ==========================================
    if hitboxEnabled then
        mState.hbAct = true
        mState.tHB = mState.tHB + deltaTime
        if mState.tHB >= 0.15 then
            mState.tHB = 0
            if not enLobby then
                local myChar = player.Character
                local myHead = myChar and myChar:FindFirstChild("Head")
                local origin = camera.CFrame.Position 
                local targetSize = Vector3_new(hitboxSize, hitboxSize, hitboxSize)
                mState.igHB[1] = myChar
                
                for i = 1, #listaJugadores do
                    local v = listaJugadores[i]
                    local targetChar = v ~= player and v.Character or nil
                    local targetCore = targetChar and getCharCore(targetChar) or nil
                    local hrp = targetCore and targetCore.HRP
                    local targetHum = targetCore and targetCore.Humanoid
                    
                    if hrp and targetHum and targetHum.Health > 0 and isEnemy(v) then
                        -- 1. BUSCAMOS O CREAMOS EL BLOQUE FALSO
                        local fakeHitbox = mState.hbByChar[targetChar]
                        if not (fakeHitbox and fakeHitbox.Parent == targetChar) then
                            fakeHitbox = nil
                            for _, child in ipairs(targetChar:GetChildren()) do
                                if child:GetAttribute("EsAstraHitbox") then
                                    fakeHitbox = child
                                    break
                                end
                            end
                            mState.hbByChar[targetChar] = fakeHitbox
                        end

                        if not fakeHitbox then
                            fakeHitbox = Instance.new("Part")
                            fakeHitbox.Name = "Torso" -- 🔥 EL TRUCO: El juego lo acepta como cuerpo válido y el cuchillo NO rebota
                            fakeHitbox:SetAttribute("EsAstraHitbox", true)
                            fakeHitbox.Shape = Enum.PartType.Block
                            fakeHitbox.Size = targetSize
                            fakeHitbox.CFrame = hrp.CFrame 
                            fakeHitbox.Massless = true
                            fakeHitbox.CanCollide = false
                            fakeHitbox.Anchored = false
                            fakeHitbox.Transparency = 1 
                            fakeHitbox.Parent = targetChar 
                            
                            local weld = Instance.new("WeldConstraint")
                            weld.Part0 = hrp
                            weld.Part1 = fakeHitbox
                            weld.Parent = fakeHitbox
                            
                            local box = Instance.new("BoxHandleAdornment") 
                            box.Name = "AstraHitboxBox" 
                            box.Adornee = fakeHitbox 
                            box.AlwaysOnTop = true 
                            box.ZIndex = 5 
                            box.Parent = fakeHitbox
                            mState.hbByChar[targetChar] = fakeHitbox
                            mState.hbAdornment[fakeHitbox] = box
                        end
                        
                        -- 2. ACTUALIZAMOS TAMAÑO FÍSICO
                        if fakeHitbox.Size ~= targetSize then fakeHitbox.Size = targetSize end
                        
                        -- 3. CÁLCULO DE VISIBILIDAD (Raycast)
                        local aLaVista = false
                        if myHead then
                            local rayDirection = hrp.Position - origin
                            if rayDirection:Dot(rayDirection) < 62500 then
                                mState.igHB[2] = targetChar
                                mState.pHB.FilterDescendantsInstances = mState.igHB
                                local result = ws_Raycast(workspace, origin, rayDirection, mState.pHB)
                                aLaVista = not result 
                            end
                        end
                        
                        -- 4. ACTUALIZAMOS LO VISUAL (Más transparente)
                        local targetColor = aLaVista and espColor or mState.hbBlockedColor
                        
                        -- Leemos el valor del slider (si por alguna razón es nil, usamos 0.6 de respaldo)
                        local currentTrans = hitboxTransparency or 0.6
                        local targetBoxTrans = hitboxInvisible and 1 or currentTrans
                        
                        local box = mState.hbAdornment[fakeHitbox]
                        if not (box and box.Parent == fakeHitbox) then
                            box = fakeHitbox:FindFirstChild("AstraHitboxBox")
                            mState.hbAdornment[fakeHitbox] = box
                        end
                        if box then
                            if box.Size ~= fakeHitbox.Size then box.Size = fakeHitbox.Size end
                            if box.Color3 ~= targetColor then box.Color3 = targetColor end
                            if box.Transparency ~= targetBoxTrans then box.Transparency = targetBoxTrans end
                            if box.Visible ~= not hitboxInvisible then box.Visible = not hitboxInvisible end
                        end -- 🔥 AQUÍ ESTÁ EL END QUE FALTABA
                    elseif targetChar then
                        -- Limpieza automática con caché; el escaneo queda sólo como fallback legacy.
                        local cachedHitbox = mState.hbByChar[targetChar]
                        if cachedHitbox and cachedHitbox.Parent then cachedHitbox:Destroy() end
                        mState.hbByChar[targetChar] = nil
                        if not cachedHitbox then
                            for _, child in ipairs(targetChar:GetChildren()) do
                                if child:GetAttribute("EsAstraHitbox") then child:Destroy() end
                            end
                        end
                    end
                end
            else
                -- 🔥 LIMPIEZA LOBBY: BORRAMOS LAS HITBOXES QUE QUEDARON PEGADAS
                for i = 1, #listaJugadores do
                    local v = listaJugadores[i]
                    if v ~= player and v.Character then
                        local cachedHitbox = mState.hbByChar[v.Character]
                        if cachedHitbox and cachedHitbox.Parent then cachedHitbox:Destroy() end
                        mState.hbByChar[v.Character] = nil
                        if not cachedHitbox then
                            for _, child in ipairs(v.Character:GetChildren()) do
                                if child:GetAttribute("EsAstraHitbox") then child:Destroy() end
                            end
                        end
                    end
                end
            end
        end
    elseif mState.hbAct then
        mState.hbAct = false
        mState.tHB = 0
        -- LIMPIEZA: Destruimos los bloques falsos cuando se apaga el Hitbox
        for i = 1, #listaJugadores do
            local v = listaJugadores[i]
            if v ~= player and v.Character then
                local cachedHitbox = mState.hbByChar[v.Character]
                if cachedHitbox and cachedHitbox.Parent then cachedHitbox:Destroy() end
                mState.hbByChar[v.Character] = nil
                if not cachedHitbox then
                    for _, child in ipairs(v.Character:GetChildren()) do
                        if child:GetAttribute("EsAstraHitbox") then child:Destroy() end
                    end
                end
                
                -- Limpieza por si quedó basura del script anterior
                local hrp = v.Character:FindFirstChild("HumanoidRootPart")
                if hrp then
                    local box = hrp:FindFirstChild("AstraHitboxBox")
                    if box then box:Destroy() end
                    hrp.Transparency = 1
                end
            end
        end
    end

    -- ==========================================
    -- 2. ESP (0.25s): 4 actualizaciones/s son suficientes para etiquetas.
    -- ==========================================
    if espEnabled then
        mState.espAct = true
        mState.tESP = mState.tESP + deltaTime
        if mState.tESP >= 0.25 then
            mState.tESP = 0
            if not enLobby then
                local myChar = player.Character
                local myCore = myChar and getCharCore(myChar) or nil
                local myPos = (myCore and myCore.Head and myCore.Head.Position) or nil

                if mState.lastEspColor ~= espColor then
                    mState.lastEspColor = espColor
                    mState.espHex = string.format(
                        "#%02X%02X%02X",
                        math_floor(espColor.R * 255 + 0.5),
                        math_floor(espColor.G * 255 + 0.5),
                        math_floor(espColor.B * 255 + 0.5)
                    )
                end

                for i = 1, #listaJugadores do
                    local p = listaJugadores[i]
                    if p ~= player then
                        local char = p.Character
                        local core = char and getCharCore(char) or nil
                        local targetHum = core and core.Humanoid
                        local targetHead = core and core.Head
                        if myPos and targetHum and targetHum.Health > 0 and targetHead and isEnemy(p) and not enemigoEnLobby(char, core.HRP) then
                            local delta = targetHead.Position - myPos
                            local distSq = delta:Dot(delta)
                            
                            if distSq <= mState.maxEspDistanceSq then
                                local dist = math.sqrt(distSq)
                                if activeESPs[p] and activeESPs[p].Char ~= char then cleanESP(p) end

                                -- Duels puede reconstruir Head/partes dentro del MISMO Character.
                                -- Si algún objeto del ESP fue destruido o quedó inválido, lo recreamos.
                                if activeESPs[p] then
                                    local cachedESP = activeESPs[p]
                                    if not cachedESP.Highlight or not cachedESP.Highlight.Parent
                                        or not cachedESP.Billboard or not cachedESP.Billboard.Parent
                                        or not cachedESP.Text or not cachedESP.Text.Parent then
                                        cleanESP(p)
                                    end
                                end
                                
                                if not activeESPs[p] then
                                    local highlight = Instance.new("Highlight") 
                                    highlight.Name = p.Name.."_Glow" 
                                    highlight.FillTransparency = 0.6
                                    highlight.OutlineTransparency = 1 
                                    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop 
                                    highlight.Adornee = char 
                                    highlight.Parent = espFolder
                                    
                                    local billboard = Instance.new("BillboardGui") 
                                    billboard.Name = p.Name.."_Tag" 
                                    billboard.Size = UDim2.new(0, 200, 0, 50) 
                                    billboard.StudsOffset = Vector3.new(0, 3.5, 0) 
                                    billboard.AlwaysOnTop = true 
                                    billboard.Adornee = targetHead 
                                    billboard.Parent = espFolder
                                    
                                    local textLabel = Instance.new("TextLabel") 
                                    textLabel.Size = UDim2.new(1, 0, 1, 0) 
                                    textLabel.BackgroundTransparency = 1 
                                    textLabel.TextStrokeTransparency = 1 
                                    textLabel.RichText = true 
                                    textLabel.Font = Enum.Font.SourceSansBold 
                                    textLabel.TextSize = 14
                                    textLabel.TextYAlignment = Enum.TextYAlignment.Bottom 
                                    textLabel.Parent = billboard

                                    local stroke = Instance.new("UIStroke")
                                    stroke.Color = Color3.fromRGB(0, 0, 0)
                                    stroke.Thickness = 1.2
                                    stroke.Parent = textLabel
                                    
                                    activeESPs[p] = {
                                        Highlight = highlight,
                                        Billboard = billboard,
                                        Char = char,
                                        Text = textLabel,
                                        LastDistance = -1,
                                        LastNameEnabled = nil,
                                        LastDistanceEnabled = nil,
                                        LastHex = nil,
                                    }
                                end
                                
                                local espObj = activeESPs[p]
                                if espObj.Highlight.Enabled ~= espSettings.Glow then espObj.Highlight.Enabled = espSettings.Glow end
                                if espObj.Highlight.FillColor ~= espColor then espObj.Highlight.FillColor = espColor end

                                -- El Character puede seguir siendo el mismo aunque Duels reemplace la Head.
                                -- Reengancha el nombre a la cabeza ACTUAL sin destruir/recrear el ESP.
                                if espObj.Billboard.Adornee ~= targetHead then
                                    espObj.Billboard.Adornee = targetHead
                                    espObj.LastDistance = -1
                                end
                                
                                local distanceInt = math_floor(dist)
                                if espObj.LastDistance ~= distanceInt
                                    or espObj.LastNameEnabled ~= espSettings.Name
                                    or espObj.LastDistanceEnabled ~= espSettings.Distance
                                    or espObj.LastHex ~= mState.espHex then
                                    local infoText = ""
                                    if espSettings.Name then
                                        infoText = '<font color="' .. mState.espHex .. '">' .. p.Name .. '</font>'
                                    end
                                    if espSettings.Distance then
                                        infoText = infoText .. (infoText == "" and "" or "\n") .. '<font size="11" color="#bdc3c7">' .. distanceInt .. 'm</font>'
                                    end

                                    espObj.LastDistance = distanceInt
                                    espObj.LastNameEnabled = espSettings.Name
                                    espObj.LastDistanceEnabled = espSettings.Distance
                                    espObj.LastHex = mState.espHex

                                    if infoText ~= "" then
                                        if not espObj.Billboard.Enabled then espObj.Billboard.Enabled = true end
                                        espObj.Text.Text = infoText
                                    elseif espObj.Billboard.Enabled then
                                        espObj.Billboard.Enabled = false
                                    end
                                end
                            else hideESP(p) end
                        else hideESP(p) end
                    end
                end
            end
        end
    elseif mState.espAct then
        mState.espAct = false
        mState.tESP = 0
        for i = 1, #listaJugadores do hideESP(listaJugadores[i]) end
    end

    -- ==========================================
    -- 3. AUTO SHOOT (0.15s)
    -- ==========================================
    if autoShootEnabled or autoShootCuchilloEnabled then
        mState.asAct = true
        mState.tAS = mState.tAS + deltaTime
        if mState.tAS >= 0.15 then
            mState.tAS = 0
            if not enLobby then
                local char = player.Character
                local localCore = char and getCharCore(char) or nil
                local hrp = localCore and localCore.HRP
                if hrp then
                    local arma = char:FindFirstChildOfClass("Tool")
                    if arma and arma:FindFirstChild("Handle") then
                        local esGun = esLaPistola(arma)
                        if (esGun and autoShootEnabled) or (not esGun and autoShootCuchilloEnabled) then
                            local myPos = hrp.Position
                            local headPos = (localCore and localCore.Head and localCore.Head.Position) or myPos
                            
                            table.clear(mState.objAS)
                            for i = 1, #listaJugadores do
                                local p = listaJugadores[i]
                                local enemyChar = p ~= player and p.Character or nil
                                if enemyChar and isEnemy(p) then
                                    local enemyCore = getCharCore(enemyChar)
                                    local enemyHrp = enemyCore and enemyCore.HRP
                                    local enemyHum = enemyCore and enemyCore.Humanoid
                                    local enemyDelta = enemyHrp and (enemyHrp.Position - myPos) or nil
                                    if enemyHum and enemyHum.Health > 0 and enemyDelta and enemyDelta:Dot(enemyDelta) <= 640000 then
                                            runtime.CollectTargetParts(enemyChar, "AutoShoot", mState.scAS, mState.seenAS)
                                            for j = 1, #mState.scAS do
                                                local part = mState.scAS[j]
                                                local partDelta = part.Position - myPos
                                                local record = table.remove(mState.poolAS)
                                                if not record then record = {} end
                                                record.Part = part
                                                record.DistSq = partDelta:Dot(partDelta)
                                                record.Char = enemyChar
                                                table_insert(mState.objAS, record)
                                            end
                                    end
                                end 
                            end 
                            
                            table_sort(mState.objAS, function(a, b) return a.DistSq < b.DistSq end)
                            local closestTargetPart = nil
                            mState.igAS[1] = char
                            
                            for i = 1, #mState.objAS do
                                local obj = mState.objAS[i]
                                mState.igAS[2] = obj.Char
                                mState.pAS.FilterDescendantsInstances = mState.igAS
                                if not ws_Raycast(workspace, headPos, obj.Part.Position - headPos, mState.pAS) then
                                    closestTargetPart = obj.Part
                                    break 
                                end
                            end 

                            -- Recicla los registros de candidatos: después del primer uso ya no
                            -- crea una tabla nueva por parte del cuerpo en cada actualización.
                            for i = #mState.objAS, 1, -1 do
                                local record = mState.objAS[i]
                                record.Part = nil
                                record.Char = nil
                                record.DistSq = 0
                                table_insert(mState.poolAS, record)
                                mState.objAS[i] = nil
                            end

                            if closestTargetPart then
                                aimHookState.Target = closestTargetPart
                                pcall(function() 
                                    arma:Activate() 
                                    task_delay(0.02, function() if arma.Parent == char then arma:Deactivate() end end)
                                end)
                            else
                                aimHookState.Target = nil
                            end
                        else aimHookState.Target = nil end
                    else aimHookState.Target = nil end
                else aimHookState.Target = nil end
            else aimHookState.Target = nil end
        end
    elseif mState.asAct then
        mState.asAct = false
        mState.tAS = 0
        aimHookState.Target = nil
    end

    -- ==========================================
    -- 4. SILENT AIM (0.03s · ~33 Hz)
    -- ==========================================
    if silentAimPistolaEnabled or silentAimCuchilloEnabled then
        mState.saAct = true
        mState.tSA = mState.tSA + deltaTime
        if mState.tSA >= 0.03 then
            mState.tSA = 0
            if not enLobby then
                local char = player.Character
                local localCore = char and getCharCore(char) or nil
                local hrp = localCore and localCore.HRP
                if hrp then
                    local arma = char:FindFirstChildOfClass("Tool")
                    local allowedWeapon = false
                    if arma then
                        local esGun = esLaPistola(arma)
                        if (esGun and silentAimPistolaEnabled) or (not esGun and silentAimCuchilloEnabled) then
                            allowedWeapon = true
                        end
                    end

                    if allowedWeapon then
                        local closestTargetPart = nil
                        local shortestDistToCenter = math.huge 
                        local shortestDistanceFisica = math.huge 
                        local myPos = hrp.Position
                        local headPos = (localCore and localCore.Head and localCore.Head.Position) or myPos
                        local viewport = camera.ViewportSize
                        if viewport.X ~= mState.vpX or viewport.Y ~= mState.vpY then
                            mState.vpX, mState.vpY = viewport.X, viewport.Y
                            mState.centerX, mState.centerY = viewport.X * 0.5, viewport.Y * 0.5
                        end
                        local centerX, centerY = mState.centerX, mState.centerY
                        local fovSq = fovRadius * fovRadius
                        local broadFov = fovRadius + 150
                        local broadFovSq = broadFov * broadFov
                        
                        mState.igSA[1] = char

                        for i = 1, #listaJugadores do 
                            local p = listaJugadores[i]
                            local enemyChar = p ~= player and p.Character or nil
                            if enemyChar and isEnemy(p) then
                                local enemyCore = getCharCore(enemyChar)
                                local enemyHum = enemyCore and enemyCore.Humanoid
                                local enemyHrp = enemyCore and enemyCore.HRP
                                local enemyDelta = enemyHrp and (enemyHrp.Position - myPos) or nil
                                if enemyHum and enemyHum.Health > 0 and enemyDelta and enemyDelta:Dot(enemyDelta) <= 640000 then
                                    if silentAimFovEnabled then
                                        local hrpPos2D, onScreen = camera:WorldToViewportPoint(enemyHrp.Position)
                                        local dx, dy = hrpPos2D.X - centerX, hrpPos2D.Y - centerY
                                        if not onScreen or (dx * dx + dy * dy) > broadFovSq then continue end
                                    end

                                    runtime.CollectTargetParts(enemyChar, "SilentAim", mState.scSA, mState.seenSA)

                                    mState.igSA[2] = enemyChar 
                                    mState.pSA.FilterDescendantsInstances = mState.igSA
                                    
                                    for j = 1, #mState.scSA do
                                        local part = mState.scSA[j]
                                        local pasaFiltro = false
                                        local candidateDistance = math.huge
                                        
                                        if silentAimFovEnabled then
                                            local hrpPos2D, onScreen = camera:WorldToViewportPoint(part.Position)
                                            if onScreen then
                                                -- Cambiamos pos2D por hrpPos2D
                                                local dx, dy = hrpPos2D.X - centerX, hrpPos2D.Y - centerY 
                                                candidateDistance = dx * dx + dy * dy
                                                if candidateDistance <= fovSq and candidateDistance < shortestDistToCenter then pasaFiltro = true end
                                            end
                                        else
                                            local partDelta = part.Position - myPos
                                            candidateDistance = partDelta:Dot(partDelta)
                                            if candidateDistance < shortestDistanceFisica then pasaFiltro = true end
                                        end
                                        
                                        if pasaFiltro and not ws_Raycast(workspace, headPos, part.Position - headPos, mState.pSA) then
                                            if silentAimFovEnabled then shortestDistToCenter = candidateDistance else shortestDistanceFisica = candidateDistance end
                                            closestTargetPart = part
                                        end
                                    end
                                end
                            end
                        end
                        if closestTargetPart then aimHookState.Target = closestTargetPart
                        elseif not autoShootEnabled and not autoShootCuchilloEnabled then aimHookState.Target = nil end
                    elseif not autoShootEnabled and not autoShootCuchilloEnabled then aimHookState.Target = nil end
                elseif not autoShootEnabled and not autoShootCuchilloEnabled then aimHookState.Target = nil end
            end
        end
    elseif mState.saAct then
        mState.saAct = false
        mState.tSA = 0
        if not autoShootEnabled and not autoShootCuchilloEnabled then aimHookState.Target = nil end
    end
end))

-- ================= INTERFAZ =================
UIElements.TogAutoShoot = Tabs.Aim:Toggle({
    Title = "Auto Shoot",
    Desc = "Dispara automáticamente a la parte del cuerpo seleccionada.",
    Value = false,
    Callback = function(Value)
        autoShootEnabled = Value
        showBottomMessage(Value and "Auto Shoot: ACTIVADO" or "Auto Shoot: DESACTIVADO")
         -- ENCIENDE/APAGA EL BUCLE
    end,
})

UIElements.TogAutoShootCuchillo = Tabs.Aim:Toggle({
    Title = "Auto Shoot (Cuchillo)",
    Desc = "Ataca o lanza el cuchillo automáticamente.",
    Value = false,
    Callback = function(Value)
        autoShootCuchilloEnabled = Value
       -- ENCIENDE/APAGA EL BUCLE
    end,
})

Tabs.Aim:Button({
    Title = "Selector corporal · Auto Shoot",
    Desc = "Abre una plantilla visual y permite seleccionar varias partes a la vez.",
    Callback = function() runtime.OpenBodySelector("AutoShoot") end,
})

UIElements.TogSilentAimPistola = Tabs.Aim:Toggle({
    Title = "Silent Aim (Pistola)",
    Desc = "Redirige las balas de tu pistola al enemigo.",
    Value = false,
    Callback = function(Value)
        silentAimPistolaEnabled = Value
        showBottomMessage(Value and "Silent Aim Pistola: ACTIVADO" or "Silent Aim Pistola: DESACTIVADO")
        -- ENCIENDE/APAGA EL BUCLE
    end,
})

UIElements.TogSilentAimCuchillo = Tabs.Aim:Toggle({
    Title = "Silent Aim (Cuchillo)",
    Desc = "Redirige los ataques de tu cuchillo al enemigo.",
    Value = false,
    Callback = function(Value)
        silentAimCuchilloEnabled = Value
        -- ENCIENDE/APAGA EL BUCLE
    end,
})



-- ==========================================
-- KEYBIND PARA SILENT AIM (SOLO PC)
-- ==========================================
local silentAimKey = nil
Tabs.Aim:Section({Title = "Selección y controles"})
Tabs.Aim:Input({
    Title = "Tecla para Activar/Desactivar Silent Aim",
    Placeholder = "Escribe una letra (Ej: Q, E, R...)",
    Callback = function(Text)
        if Text and Text ~= "" then
            silentAimKey = string.upper(Text) -- Lo convierte a mayúscula automáticamente
            showBottomMessage("Tecla Silent Aim asignada a: " .. silentAimKey)
        else
            silentAimKey = nil
        end
    end
})

runtime.Track(UserInputService.InputBegan:Connect(function(input, processed)
    -- Si el jugador está escribiendo en el chat, no hacemos nada
    if processed then return end
    
    if input.UserInputType == Enum.UserInputType.Keyboard and silentAimKey then
        if input.KeyCode.Name == silentAimKey then
            -- Alternamos el estado basado en la pistola
            local newState = not silentAimPistolaEnabled 
            
            -- Aplicamos el nuevo estado a ambas variables
            silentAimPistolaEnabled = newState
            silentAimCuchilloEnabled = newState
            
            -- Actualizamos los toggles de la UI visualmente sin romperlos
            pcall(function() UIElements.TogSilentAimPistola:Set(newState) end)
            pcall(function() UIElements.TogSilentAimCuchillo:Set(newState) end)
            
            -- Sincronizamos el botón flotante si lo tienen en pantalla
            pcall(function()
                if saBtn then
                    if newState then
                        saBtn.Text = "Silent Aim: ON"
                        saBtn.TextColor3 = Color3.fromHex("#DCE0E5")
                        if saStroke then saStroke.Color = Color3.fromRGB(255, 255, 255) end
                    else
                        saBtn.Text = "Silent Aim: OFF"
                        saBtn.TextColor3 = Color3.fromHex("#F3F4F5")
                        if saStroke then saStroke.Color = Color3.fromHex("#464B52") end
                    end
                end
            end)

            -- Avisamos al jugador
            showBottomMessage(newState and "Silent Aim: ACTIVADO ["..silentAimKey.."]" or "Silent Aim: DESACTIVADO ["..silentAimKey.."]")
        end
    end
end))

Tabs.Aim:Button({
    Title = "Selector corporal · Silent Aim",
    Desc = "Selecciona cabeza, torso, brazos y piernas con multiselección visual.",
    Callback = function() runtime.OpenBodySelector("SilentAim") end,
})

UIElements.TogSilentAimFOV = Tabs.Aim:Toggle({
    Title = "Filtro de círculo FOV",
    Desc = "Silent Aim solo considera objetivos dentro del círculo configurado.",
    Value = false,
    Callback = function(Value)
        silentAimFovEnabled = Value
        showBottomMessage(Value and "Filtro FOV: ACTIVADO" or "Filtro FOV: DESACTIVADO")
    end,
})

UIElements.TogShowFOV = Tabs.Aim:Toggle({
    Title = "Mostrar Círculo FOV",
    Desc = "Dibuja un círculo en pantalla para saber dónde funciona tu Silent Aim.",
    Value = false,
    Callback = function(Value) fovVisiblePreference = Value end,
})

Tabs.Aim:Section({Title = "Campo de visión"})
UIElements.SliFOVSize = Tabs.Aim:Slider({
    Title = "Tamaño del FOV", 
    Step = 1,
    Value = {Min = 10, Max = 800, Default = 120}, 
    Callback = function(v) fovRadius = v end
})




-- ==========================================
-- iLunXHub | KILL ALL SINGLE HIT V4
--
--98+/ 0. FLUJO:
--
-- NO SE PUEDE ACTIVAR EN ZONA SEGURA
--              ↓
-- ESPERAR EN BASE ACOSTADO
--              ↓
-- ENEMIGO VULNERABLE
--              ↓
-- EQUIPAR CUCHILLO
--              ↓
-- TP + TRACKING DEL ENEMIGO
--              ↓
-- CONTACTO HRP + HANDLE ESTABLE
--              ↓
-- HOLD EXTRA
--              ↓
-- REVALIDAR CONTACTO
--              ↓
-- UN SOLO CUCHILLAZO
--              ↓
-- SEGUIR PEGADO HASTA MUERTE
--              ↓
-- DIED / HEALTH <= 0
--              ↓
-- BASE UNA SOLA VEZ
--              ↓
-- ACOSTADO SIN MICRO MOVIMIENTOS
-- ==========================================

Tabs.KillAll:Section({
    Title = "Kill all Cuchillo"
})

local KillRunService = game:GetService("RunService")

local killAllEnabled = false
local killAllBaseCFrame = nil
local killAllIdleFree = false
local killAllBaseCharacter = nil

local killAllResting = false
local killAllRestCharacter = nil

local killAllWasSafe = false
local killAllRejectingToggle = false

KILL_RANGE = 600


-- ==========================================
-- CONFIG
-- ==========================================

-- El enemigo debe estar realmente vulnerable
-- durante este tiempo antes de iniciar ataque.
VULNERABLE_STABLE_TIME = 0.10

-- Seguimos apareciendo un poco debajo.
ATTACK_Y_OFFSET = -2.55

-- Ahora tenemos margen de sobra para seguir
-- a enemigos que estén corriendo o saltando.
local ARRIVAL_TIMEOUT = 1.20

-- Más estricto que antes.
-- Antes: 6 / 7 studs.
local HRP_READY_DISTANCE = 5.0
local HANDLE_READY_DISTANCE = 4.8

-- Antes era 0.035.
-- Ahora debe existir contacto REAL visible.
local HANDLE_STABLE_TIME = 0.05

-- Después de confirmar llegada seguimos
-- pegados un poco más ANTES de atacar.
local PRE_HIT_HOLD_TIME = 0.03

-- Máximo esperando la muerte después
-- del único cuchillazo.
local KILL_CONFIRM_TIME = 1.15

-- Reintentar después si el golpe no mató.
local FAILED_RETRY_DELAY = 0.10


local failedTargets = {}


-- ==========================================
-- ROOT
-- ==========================================

function freezeKillRoot(hrp)
    if not hrp or not hrp.Parent then
        return
    end

    hrp.AssemblyLinearVelocity = Vector3.zero
    hrp.AssemblyAngularVelocity = Vector3.zero
end


-- ==========================================
-- ZONA SEGURA DIRECTA
--
-- NO dependemos solamente del caché.
-- Sirve tanto para nosotros como enemigos.
-- ==========================================

function estaEnZonaSeguraKillAll(
    char,
    targetPlayer
)
    if not char or not char.Parent then
        return true
    end


    -- ForceField.
    if char:FindFirstChildOfClass(
        "ForceField"
    ) then
        return true
    end


    -- Equipo de lobby/espectador/etc.
    if targetPlayer
        and targetPlayer.Team
    then

        local teamName =
            string.lower(
                targetPlayer.Team.Name
            )

        if string.find(
            teamName,
            "lobby"
        )
            or string.find(
                teamName,
                "spectat"
            )
            or string.find(
                teamName,
                "espectador"
            )
            or string.find(
                teamName,
                "menu"
            )
            or string.find(
                teamName,
                "dead"
            )
        then
            return true
        end
    end


    -- Coordenadas configuradas en
    -- ZONAS_SEGURAS.
    local hrp =
        char:FindFirstChild(
            "HumanoidRootPart"
        )

    if hrp then

        local pos =
            hrp.Position

        for i = 1, #ZONAS_SEGURAS do

            local zona =
                ZONAS_SEGURAS[i]

            if (
                pos
                - zona.Centro
            ).Magnitude <= zona.Radio
            then
                return true
            end
        end
    end


    return false
end


-- ==========================================
-- PROTECCIÓN
-- ==========================================

local PROTECTION_ATTRIBUTES = {
    "Invulnerable",
    "Protected",
    "SpawnProtected",
    "SpawnProtection",
    "NoDamage",
    "DamageProtected"
}

local PROTECTION_VALUES = {
    "Invulnerable",
    "Protected",
    "SpawnProtected",
    "SpawnProtection",
    "NoDamage"
}


local function tieneProteccionKillAll(char)
    if not char or not char.Parent then
        return true
    end


    if char:FindFirstChildOfClass(
        "ForceField"
    ) then
        return true
    end


    for _, attributeName
        in ipairs(
            PROTECTION_ATTRIBUTES
        )
    do

        local value =
            char:GetAttribute(
                attributeName
            )

        if value == true then
            return true
        end
    end


    for _, valueName
        in ipairs(
            PROTECTION_VALUES
        )
    do

        local object =
            char:FindFirstChild(
                valueName,
                true
            )

        if object
            and object:IsA(
                "BoolValue"
            )
            and object.Value == true
        then
            return true
        end
    end


    return false
end


-- ==========================================
-- VULNERABILIDAD REAL
-- ==========================================

local function estaVulnerableKillAll(
    char,
    targetPlayer
)
    if not char or not char.Parent then
        return false
    end


    if estaEnZonaSeguraKillAll(
        char,
        targetPlayer
    ) then
        return false
    end


    local hum =
        char:FindFirstChildOfClass(
            "Humanoid"
        )

    local hrp =
        char:FindFirstChild(
            "HumanoidRootPart"
        )


    if not hum or not hrp then
        return false
    end


    if hum.Health <= 0 then
        return false
    end


    if tieneProteccionKillAll(
        char
    ) then
        return false
    end


    if hrp.Anchored then
        return false
    end


    if hum.WalkSpeed <= 0 then
        return false
    end


    return true
end


-- ==========================================
-- ESPERAR VULNERABILIDAD
-- ==========================================

local function esperarVulnerabilidadKillAll(
    char,
    targetPlayer
)
    local stableSince = nil


    while runtime.Alive
        and killAllEnabled
        and char
        and char.Parent
    do

        local hum =
            char:FindFirstChildOfClass(
                "Humanoid"
            )


        if not hum
            or hum.Health <= 0
        then
            return false
        end


        if estaEnZonaSeguraKillAll(
            char,
            targetPlayer
        ) then
            return false
        end


        if estaVulnerableKillAll(
            char,
            targetPlayer
        ) then

            if not stableSince then

                stableSince =
                    os.clock()

            elseif (
                os.clock()
                - stableSince
            ) >= VULNERABLE_STABLE_TIME
            then

                return true
            end

        else

            stableSince =
                nil
        end


        task.wait(0.03)
    end


    return false
end


-- ==========================================
-- CUCHILLO
-- ==========================================

local KNIFE_WORDS = {
    "knife",
    "cuchillo",
    "blade",
    "dagger",
    "kunai"
}


local function esCuchilloKillAll(tool)
    if not tool
        or not tool:IsA(
            "Tool"
        )
    then
        return false
    end


    if tool:FindFirstChild(
        "KnifeClient",
        true
    )
        or tool:FindFirstChild(
            "KnifeServer",
            true
        )
        or tool:FindFirstChild(
            "Throw",
            true
        )
        or tool:FindFirstChild(
            "Kill",
            true
        )
    then
        return true
    end


    local nombre =
        string.lower(
            tool.Name
        )


    for _, word
        in ipairs(
            KNIFE_WORDS
        )
    do

        if string.find(
            nombre,
            word,
            1,
            true
        ) then
            return true
        end
    end


    return false
end


-- ==========================================
-- EQUIPAR CUCHILLO
-- ==========================================

local function obtenerCuchilloKillAll(
    char,
    hum
)
    if not char or not hum then
        return nil
    end


    -- Ya equipado.
    for _, tool
        in ipairs(
            char:GetChildren()
        )
    do

        if esCuchilloKillAll(
            tool
        ) then
            return tool
        end
    end


    local backpack =
        player:FindFirstChild(
            "Backpack"
        )

    if not backpack then
        return nil
    end


    local currentTool =
        char:FindFirstChildOfClass(
            "Tool"
        )


    if currentTool
        and not esCuchilloKillAll(
            currentTool
        )
    then

        pcall(function()
            hum:UnequipTools()
        end)

        KillRunService.
            Heartbeat:Wait()
    end


    for _, tool
        in ipairs(
            backpack:GetChildren()
        )
    do

        if esCuchilloKillAll(
            tool
        ) then

            pcall(function()
                hum:EquipTool(
                    tool
                )
            end)


            local deadline =
                os.clock() + 0.65


            while runtime.Alive
                and killAllEnabled
                and tool.Parent ~= char
                and os.clock() < deadline
            do

                KillRunService.
                    Heartbeat:Wait()
            end


            if tool.Parent == char then

                -- Más de un frame para dejar
                -- que RightGrip/Motor6D quede
                -- montado correctamente.
                KillRunService.
                    Heartbeat:Wait()

                KillRunService.
                    Heartbeat:Wait()

                return tool
            end
        end
    end


    return nil
end


-- ==========================================
-- HANDLE
-- ==========================================

local function obtenerHandleKillAll(
    arma
)
    if not arma then
        return nil
    end


    local handle =
        arma:FindFirstChild(
            "Handle",
            true
        )


    if handle
        and handle:IsA(
            "BasePart"
        )
    then
        return handle
    end


    for _, object
        in ipairs(
            arma:GetDescendants()
        )
    do

        if object:IsA(
            "BasePart"
        ) then
            return object
        end
    end


    return nil
end


-- ==========================================
-- PARTE OBJETIVO
-- ==========================================

local function obtenerParteObjetivoKillAll(
    char
)
    if not char then
        return nil
    end


    local upperTorso =
        char:FindFirstChild(
            "UpperTorso"
        )

    if upperTorso
        and upperTorso:IsA(
            "BasePart"
        )
    then
        return upperTorso
    end


    local torso =
        char:FindFirstChild(
            "Torso"
        )

    if torso
        and torso:IsA(
            "BasePart"
        )
    then
        return torso
    end


    return char:FindFirstChild(
        "HumanoidRootPart"
    )
end


-- ==========================================
-- CFRAME ATAQUE
-- ==========================================

local function obtenerAttackCFKillAll(
    enemyHrp
)
    if not enemyHrp
        or not enemyHrp.Parent
    then
        return nil
    end


    return enemyHrp.CFrame
        * CFrame.new(
            0,
            ATTACK_Y_OFFSET,
            0
        )
        * CFrame.Angles(
           math.rad(90),
            0,
            0
        )
end


-- ==========================================
-- SALIR DE REPOSO
--
-- Se llama JUSTO antes de atacar.
-- ==========================================

local function liberarReposoKillAll(
    hum,
    hrp
)
    if hum
        and hum.Parent
    then

        pcall(function()
            hum.PlatformStand =
                false

            hum.AutoRotate =
                true

            hum:ChangeState(
                Enum.HumanoidStateType.GettingUp
            )
        end)
    end


    freezeKillRoot(
        hrp
    )


    killAllResting =
        false

    killAllRestCharacter =
        nil
end



-- ==========================================
-- MODO LIBRE DESPUÉS DE LIMPIAR LA RONDA
--
-- Kill All sigue ENCENDIDO, pero el personaje
-- queda exactamente como si estuviera apagado:
-- puede caminar, saltar, etc.
-- ==========================================

local function liberarMovimientoKillAll(
    myHum,
    myHrp
)
    if myHum
        and myHum.Parent
    then

        pcall(function()

            myHum.PlatformStand =
                false

            myHum.AutoRotate =
                true

            myHum:ChangeState(
                Enum.HumanoidStateType.GettingUp
            )
        end)
    end


    if myHrp
        and myHrp.Parent
    then

        freezeKillRoot(
            myHrp
        )
    end


    killAllResting =
        false

    killAllRestCharacter =
        nil

    killAllIdleFree =
        true
end


-- ==========================================
-- REPOSO EN BASE
--
-- IMPORTANTE:
-- SOLO PivotTo UNA VEZ.
--
-- Después PlatformStand mantiene al mono
-- acostado sin estar corrigiendo CFrame
-- 20 veces por segundo.
-- ==========================================

local function reposarEnBaseKillAll(
    myChar,
    myHum,
    myHrp
)
    if not myChar
        or not myChar.Parent
        or not myHum
        or not myHum.Parent
        or not myHrp
        or not myHrp.Parent
        or not killAllBaseCFrame
    then
        return
    end


    -- Character nuevo = nuevo reposo.
    if killAllRestCharacter
        ~= myChar
    then

        killAllResting =
            false
    end


    if not killAllResting then

        local basePose =
            killAllBaseCFrame
            * CFrame.Angles(
                math.rad(90),
                0,
                0
            )


        pcall(function()
            myChar:PivotTo(
                basePose
            )
        end)


        freezeKillRoot(
            myHrp
        )


        pcall(function()

            myHum.AutoRotate =
                false

            myHum.PlatformStand =
                true

            myHum:ChangeState(
                Enum.HumanoidStateType.Physics
            )
        end)


        killAllResting =
            true

        killAllRestCharacter =
            myChar

    else

        -- NADA DE PivotTo.
        -- Únicamente matar velocidad residual.
        freezeKillRoot(
            myHrp
        )
    end
end


-- ==========================================
-- COMPROBAR CONTACTO REAL
-- ==========================================

local function contactoRealKillAll(
    myHrp,
    arma,
    enemyChar
)
    if not myHrp
        or not myHrp.Parent
        or not arma
        or not arma.Parent
        or not enemyChar
        or not enemyChar.Parent
    then
        return false
    end


    local targetPart =
        obtenerParteObjetivoKillAll(
            enemyChar
        )

    if not targetPart then
        return false
    end


    local hrpDistance =
        (
            myHrp.Position
            - targetPart.Position
        ).Magnitude


    local handle =
        obtenerHandleKillAll(
            arma
        )


    local handleDistance =
        math.huge


    if handle
        and handle.Parent
    then

        handleDistance =
            (
                handle.Position
                - targetPart.Position
            ).Magnitude

    else

        handleDistance =
            hrpDistance
    end


    return (
        hrpDistance
        <= HRP_READY_DISTANCE
    )
        and (
            handleDistance
            <= HANDLE_READY_DISTANCE
        )
end


-- ==========================================
-- SEGUIR AL ENEMIGO
--
-- Esta es la diferencia importante para
-- caminar / correr / saltar.
-- ==========================================

local function seguirObjetivoKillAll(
    myChar,
    myHrp,
    enemyHrp
)
    if not myChar
        or not myChar.Parent
        or not myHrp
        or not myHrp.Parent
        or not enemyHrp
        or not enemyHrp.Parent
    then
        return false
    end


    local attackCF =
        obtenerAttackCFKillAll(
            enemyHrp
        )

    if not attackCF then
        return false
    end


    pcall(function()

        myChar:PivotTo(
            attackCF
        )
    end)


    freezeKillRoot(
        myHrp
    )


    return true
end


-- ==========================================
-- ESPERAR CONTACTO ESTABLE
--
-- TRACKING CADA HEARTBEAT.
-- ==========================================

local function esperarContactoKillAll(
    myChar,
    myHrp,
    arma,
    targetPlayer,
    enemyChar,
    enemyHrp
)
    local deadline =
        os.clock()
        + ARRIVAL_TIMEOUT

    local stableSince =
        nil


    while runtime.Alive
        and killAllEnabled
        and myChar
        and myChar.Parent
        and myHrp
        and myHrp.Parent
        and arma
        and arma.Parent
        and enemyChar
        and enemyChar.Parent
        and enemyHrp
        and enemyHrp.Parent
        and os.clock() < deadline
    do

        local enemyHum =
            enemyChar:
                FindFirstChildOfClass(
                    "Humanoid"
                )


        if not enemyHum
            or enemyHum.Health <= 0
        then
            return false
        end


        -- Si entra en zona segura mientras
        -- lo perseguimos, cancelar.
        if estaEnZonaSeguraKillAll(
            enemyChar,
            targetPlayer
        ) then
            return false
        end


        -- IMPORTANTE:
        -- actualizar posición CADA FRAME.
        seguirObjetivoKillAll(
            myChar,
            myHrp,
            enemyHrp
        )


        -- Dejamos que el rig + Handle
        -- actualicen sus posiciones.
        KillRunService.
            Heartbeat:Wait()


        if contactoRealKillAll(
            myHrp,
            arma,
            enemyChar
        ) then

            if not stableSince then

                stableSince =
                    os.clock()

            elseif (
                os.clock()
                - stableSince
            ) >= HANDLE_STABLE_TIME
            then

                return true
            end

        else

            -- Perdió contacto:
            -- empieza estabilidad de cero.
            stableSince =
                nil
        end
    end


    return false
end


-- ==========================================
-- HOLD FINAL ANTES DEL CUCHILLAZO
--
-- Debe permanecer EN CONTACTO durante
-- TODO el tiempo.
-- ==========================================

local function holdAntesGolpeKillAll(
    myChar,
    myHrp,
    arma,
    targetPlayer,
    enemyChar,
    enemyHrp
)
    local started =
        os.clock()


    while runtime.Alive
        and killAllEnabled
        and (
            os.clock()
            - started
        ) < PRE_HIT_HOLD_TIME
    do

        local enemyHum =
            enemyChar
            and enemyChar:
                FindFirstChildOfClass(
                    "Humanoid"
                )


        if not enemyHum
            or enemyHum.Health <= 0
        then
            return false
        end


        if estaEnZonaSeguraKillAll(
            enemyChar,
            targetPlayer
        ) then
            return false
        end


        if not estaVulnerableKillAll(
            enemyChar,
            targetPlayer
        ) then
            return false
        end


        seguirObjetivoKillAll(
            myChar,
            myHrp,
            enemyHrp
        )


        KillRunService.
            Heartbeat:Wait()


        -- Si en cualquier frame el Handle
        -- dejó de estar cerca, NO atacar.
        if not contactoRealKillAll(
            myHrp,
            arma,
            enemyChar
        ) then
            return false
        end
    end


    return true
end


-- ==========================================
-- ESPERAR MUERTE REAL
--
-- Después del golpe seguimos al enemigo,
-- pero NO volvemos a activar el cuchillo.
-- ==========================================

local function esperarMuerteKillAll(
    myChar,
    myHrp,
    targetPlayer,
    enemyChar,
    enemyHum,
    enemyHrp
)
    local murio =
        false


    local diedConnection =
        enemyHum.Died:Connect(
            function()

                murio =
                    true
            end
        )


    local deadline =
        os.clock()
        + KILL_CONFIRM_TIME


    while runtime.Alive
        and killAllEnabled
        and os.clock() < deadline
    do

        if murio
            or (
                enemyHum
                and enemyHum.Health <= 0
            )
        then

            murio =
                true

            break
        end


        if not enemyHum
            or not enemyHum.Parent
        then
            break
        end


        -- Si por alguna razón entra en
        -- protección/zona segura, dejamos
        -- de perseguirlo.
        if estaEnZonaSeguraKillAll(
            enemyChar,
            targetPlayer
        ) then
            break
        end


        -- Seguirlo caminando / saltando
        -- DESPUÉS del swing también.
        if enemyHrp
            and enemyHrp.Parent
        then

            seguirObjetivoKillAll(
                myChar,
                myHrp,
                enemyHrp
            )
        end


        KillRunService.
            Heartbeat:Wait()
    end


    if diedConnection then

        pcall(function()
            diedConnection:
                Disconnect()
        end)
    end


    if enemyHum
        and enemyHum.Parent
        and enemyHum.Health <= 0
    then

        murio =
            true
    end


    return murio
end


-- ==========================================
-- ATAQUE SINGLE HIT
-- ==========================================

local function atacarUnaVezKillAll(
    targetPlayer,
    myChar,
    myHum,
    myHrp
)
    if not targetPlayer
        or targetPlayer == player
        or not targetPlayer.Character
    then
        return false
    end


    local enemyChar =
        targetPlayer.Character

    local enemyHum =
        enemyChar:
            FindFirstChildOfClass(
                "Humanoid"
            )

    local enemyHrp =
        enemyChar:
            FindFirstChild(
                "HumanoidRootPart"
            )


    if not enemyHum
        or not enemyHrp
        or enemyHum.Health <= 0
    then
        return false
    end


    -- Nunca atacar objetivos en
    -- lobby / zona segura.
    if estaEnZonaSeguraKillAll(
        enemyChar,
        targetPlayer
    ) then
        return false
    end


    -- ======================================
    -- RETRY
    -- ======================================

    local retryAt =
        failedTargets[
            targetPlayer
        ]


    if retryAt
        and os.clock() < retryAt
    then
        return false
    end


    -- ======================================
    -- RANGO
    -- ======================================

    local referenceCF =
        killAllBaseCFrame
        or myHrp.CFrame


    if (
        referenceCF.Position
        - enemyHrp.Position
    ).Magnitude > KILL_RANGE
    then
        return false
    end


    -- ======================================
    -- ESPERAR PROTECCIÓN
    -- ======================================

    local vulnerable =
        esperarVulnerabilidadKillAll(
            enemyChar,
            targetPlayer
        )


    if not vulnerable then
        return false
    end


    -- Releer.
    enemyChar =
        targetPlayer.Character

    if not enemyChar then
        return false
    end


    enemyHum =
        enemyChar:
            FindFirstChildOfClass(
                "Humanoid"
            )

    enemyHrp =
        enemyChar:
            FindFirstChild(
                "HumanoidRootPart"
            )


    if not enemyHum
        or not enemyHrp
        or enemyHum.Health <= 0
        or estaEnZonaSeguraKillAll(
            enemyChar,
            targetPlayer
        )
    then
        return false
    end


    -- ======================================
    -- LEVANTARNOS SOLO PARA ATACAR
    -- ======================================

    liberarReposoKillAll(
        myHum,
        myHrp
    )


    -- ======================================
    -- EQUIPAR CUCHILLO Y PRE-ATAQUE
    -- ======================================

    local arma =
        obtenerCuchilloKillAll(
            myChar,
            myHum
        )

    if not arma then
        reposarEnBaseKillAll(myChar, myHum, myHrp)
        return false
    end

    -- 🔥 DAMOS EL CUCHILLAZO ANTES DE HACER TP 🔥
    pcall(function()
        if arma and arma.Parent == myChar then
            arma:Activate()
        end
    end)
    
    -- Le damos un microsegundo para que la animación/hitbox inicie
    task.wait(0.15)

    -- ======================================
    -- CONTACTO ESTABLE Y TRACKING
    -- ======================================

    local contacto =
        esperarContactoKillAll(
            myChar,
            myHrp,
            arma,
            targetPlayer,
            enemyChar,
            enemyHrp
        )

    if not contacto then

        reposarEnBaseKillAll(
            myChar,
            myHum,
            myHrp
        )

        failedTargets[
            targetPlayer
        ] =
            os.clock()
            + FAILED_RETRY_DELAY

        return false
    end


    -- ======================================
    -- HOLD EXTRA
    -- ======================================

    local holdOk =
        holdAntesGolpeKillAll(
            myChar,
            myHrp,
            arma,
            targetPlayer,
            enemyChar,
            enemyHrp
        )


    -- Si perdió contacto durante el hold,
    -- NO pegar al aire.
    --
    -- Intentamos volver a conseguir
    -- contacto primero.
    if not holdOk then

        contacto =
            esperarContactoKillAll(
                myChar,
                myHrp,
                arma,
                targetPlayer,
                enemyChar,
                enemyHrp
            )


        if contacto then

            holdOk =
                holdAntesGolpeKillAll(
                    myChar,
                    myHrp,
                    arma,
                    targetPlayer,
                    enemyChar,
                    enemyHrp
                )
        end
    end


    if not holdOk then

        reposarEnBaseKillAll(
            myChar,
            myHum,
            myHrp
        )

        failedTargets[
            targetPlayer
        ] =
            os.clock()
            + FAILED_RETRY_DELAY

        return false
    end


    -- ======================================
    -- VALIDACIÓN FINAL ABSOLUTA
    --
    -- NO Activate() si el cuchillo
    -- dejó de estar físicamente cerca.
    -- ======================================

    seguirObjetivoKillAll(
        myChar,
        myHrp,
        enemyHrp
    )


    KillRunService.
        Heartbeat:Wait()


    if not contactoRealKillAll(
        myHrp,
        arma,
        enemyChar
    ) then

        -- Re-adquirir en lugar de
        -- cuchillazo prematuro.
        contacto =
            esperarContactoKillAll(
                myChar,
                myHrp,
                arma,
                targetPlayer,
                enemyChar,
                enemyHrp
            )


        if not contacto then

            reposarEnBaseKillAll(
                myChar,
                myHum,
                myHrp
            )

            failedTargets[
                targetPlayer
            ] =
                os.clock()
                + FAILED_RETRY_DELAY

            return false
        end
    end


    -- Protección una ÚLTIMA vez.
    if not estaVulnerableKillAll(
        enemyChar,
        targetPlayer
    ) then

        reposarEnBaseKillAll(
            myChar,
            myHum,
            myHrp
        )

        return false
    end


    


    -- ======================================
    -- ESPERAR KILL CONFIRMADA
    --
    -- Seguimos encima.
    -- NO SPAM.
    -- NO segundo Activate().
    -- ======================================

    local murio =
        esperarMuerteKillAll(
            myChar,
            myHrp,
            targetPlayer,
            enemyChar,
            enemyHum,
            enemyHrp
        )


    pcall(function()

        if arma
            and arma.Parent == myChar
        then

            arma:Deactivate()
        end
    end)


    -- ======================================
    -- BASE
    --
    -- SOLO UNA VEZ.
    -- Después queda PlatformStand.
    -- ======================================

    reposarEnBaseKillAll(
        myChar,
        myHum,
        myHrp
    )


    if murio then

        failedTargets[
            targetPlayer
        ] =
            nil

    else

        failedTargets[
            targetPlayer
        ] =
            os.clock()
            + FAILED_RETRY_DELAY
    end


    return murio
end


-- ==========================================
-- TOGGLE
-- ==========================================

UIElements.TogKillAll =
    Tabs.KillAll:Toggle({

    Title =
        "Activar Kill All",

    Desc =
        "Mata a los enemigos con cuchillo",

    Value =
        false,

    Callback =
        function(Value)


        -- ==================================
        -- ON
        -- ==================================

        if Value then

            local char =
                player.Character

            local hum =
                char
                and char:
                    FindFirstChildOfClass(
                        "Humanoid"
                    )

            local hrp =
                char
                and char:
                    FindFirstChild(
                        "HumanoidRootPart"
                    )


            -- =================================
            -- BLOQUEO TOTAL DE ZONA SEGURA
            --
            -- No se queda "armado".
            -- Directamente NO permite ON.
            -- =================================

            if not char
                or not hum
                or not hrp
                or hum.Health <= 0
                or estaEnLobby()
                or estaEnZonaSeguraKillAll(
                    char,
                    player
                )
            then

                killAllEnabled =
                    false

                showBottomMessage(
                    "Kill All no se puede activar en zona segura."
                )


                killAllRejectingToggle =
                    true


                task.defer(function()

                    pcall(function()

                        if UIElements.TogKillAll then

                            UIElements.
                                TogKillAll:
                                Set(false)
                        end
                    end)


                    killAllRejectingToggle =
                        false
                end)


                return
            end


            killAllEnabled =
                true


            killAllBaseCFrame =
                hrp.CFrame

            killAllBaseCharacter =
                char

            killAllResting =
                false

            killAllRestCharacter =
                nil

            killAllWasSafe =
                false


            table.clear(
                failedTargets
            )


            showBottomMessage(
                "Kill All: ACTIVADO"
            )


            -- Al encenderlo ya nos ponemos
            -- en posición de reposo.
            reposarEnBaseKillAll(
                char,
                hum,
                hrp
            )


            task.spawn(function()

                while runtime.Alive
                    and killAllEnabled
                do

                    -- =========================
                    -- LOCAL
                    -- =========================

                    local myChar =
                        player.Character

                    local myHum =
                        myChar
                        and myChar:
                            FindFirstChildOfClass(
                                "Humanoid"
                            )

                    local myHrp =
                        myChar
                        and myChar:
                            FindFirstChild(
                                "HumanoidRootPart"
                            )


                    if not myChar
                        or not myHum
                        or not myHrp
                        or myHum.Health <= 0
                    then

                        killAllResting =
                            false

                        killAllRestCharacter =
                            nil

                        task.wait(0.12)

                        continue
                    end


                    -- =========================
                    -- RESPAWN / CHARACTER NUEVO
                    -- =========================

                    if killAllBaseCharacter
                        ~= myChar
                    then

                        killAllBaseCharacter =
                            myChar

                        killAllBaseCFrame =
                            myHrp.CFrame

                        killAllResting =
                            false

                        killAllRestCharacter =
                            nil
                    end


                    -- =========================
                    -- ZONA SEGURA
                    --
                    -- Si entramos DESPUÉS de
                    -- activarlo, no forzamos
                    -- ningún CFrame.
                    --
                    -- Se suspende hasta salir.
                    -- =========================

                    local localSafe =
                        estaEnLobby()
                        or
                        estaEnZonaSeguraKillAll(
                            myChar,
                            player
                        )


                    if localSafe then

                        -- Importante:
                        -- liberar PlatformStand
                        -- para que el juego pueda
                        -- manejar lobby / spawn.
                        if killAllResting then

                            liberarReposoKillAll(
                                myHum,
                                myHrp
                            )
                        end


                        -- La próxima vez que
                        -- salgamos de zona segura,
                        -- la posición actual será
                        -- la nueva base de ronda.
                        killAllBaseCFrame =
                            nil

                        killAllWasSafe =
                            true


                        task.wait(0.10)

                        continue
                    end


                    -- =========================
                    -- ENTRÓ NUEVA RONDA
                    -- =========================

                    if killAllWasSafe
                        or not killAllBaseCFrame
                    then

                        killAllBaseCFrame =
                            myHrp.CFrame

                        killAllBaseCharacter =
                            myChar

                        killAllWasSafe =
                            false

                        killAllResting =
                            false

                        killAllRestCharacter =
                            nil

                        killAllIdleFree =
                            false
                    end


                    -- =========================
                    -- TARGETS
                    -- =========================

                    local encontroObjetivo =
                        false

                    local intentoAtaque =
                        false


                    for _, targetPlayer
                        in ipairs(
                            listaJugadores
                        )
                    do

                        if not runtime.Alive
                            or not killAllEnabled
                        then
                            break
                        end


                        if targetPlayer ~= player
                            and isEnemy(
                                targetPlayer
                            )
                            and targetPlayer.Character
                        then

                            local enemyChar =
                                targetPlayer.Character

                            local enemyHum =
                                enemyChar:
                                    FindFirstChildOfClass(
                                        "Humanoid"
                                    )

                            local enemyHrp =
                                enemyChar:
                                    FindFirstChild(
                                        "HumanoidRootPart"
                                    )


                            if enemyHum
                                and enemyHrp
                                and enemyHum.Health > 0
                                and not estaEnZonaSeguraKillAll(
                                    enemyChar,
                                    targetPlayer
                                )
                            then

                                local distance =
                                    (
                                        killAllBaseCFrame.Position
                                        - enemyHrp.Position
                                    ).Magnitude


                                if distance
                                    <= KILL_RANGE
                                then

                                    encontroObjetivo =
                                        true

                                    -- Salir del modo libre porque
                                    -- ya volvió a aparecer un enemigo.
                                    if killAllIdleFree then
                                        killAllIdleFree =
                                            false
                                    end

                                    local retryAt =
                                        failedTargets[
                                            targetPlayer
                                        ]


                                    if not retryAt
                                        or os.clock()
                                            >= retryAt
                                    then

                                        intentoAtaque =
                                            true


                                        atacarUnaVezKillAll(
                                            targetPlayer,
                                            myChar,
                                            myHum,
                                            myHrp
                                        )


                                        -- Después de cada enemigo
                                        -- atacarUnaVezKillAll YA
                                        -- regresó y dejó reposando.
                                        --
                                        -- NO regresar otra vez.
                                        task.wait(
                                            0.035
                                        )
                                    end
                                end
                            end
                        end
                    end


                    -- =========================
                    -- FIN DE ATAQUES / MODO LIBRE
                    -- =========================

                    if not encontroObjetivo then

                        -- Ya matamos a todos.
                        -- Kill All sigue ON,
                        -- pero devuelve movimiento normal.
                        if not killAllIdleFree then

                            liberarMovimientoKillAll(
                                myHum,
                                myHrp
                            )
                        end

                        task.wait(0.12)

                    elseif not intentoAtaque then

                        -- Sí existe enemigo pero todavía
                        -- no se puede atacar por protección,
                        -- retry, vulnerabilidad, etc.
                        reposarEnBaseKillAll(
                            myChar,
                            myHum,
                            myHrp
                        )

                        task.wait(0.08)

                    else

                        task.wait(0.06)
                    end
                end
            end)


        -- ==================================
        -- OFF
        -- ==================================

        else

            killAllEnabled =
                false


            if not killAllRejectingToggle then

                showBottomMessage(
                    "Kill All: DESACTIVADO"
                )
            end


            local char =
                player.Character

            local hum =
                char
                and char:
                    FindFirstChildOfClass(
                        "Humanoid"
                    )

            local hrp =
                char
                and char:
                    FindFirstChild(
                        "HumanoidRootPart"
                    )


            if hum then

                pcall(function()

                    hum.PlatformStand =
                        false

                    hum.AutoRotate =
                        true

                    hum:ChangeState(
                        Enum.HumanoidStateType.GettingUp
                    )
                end)
            end


            if hrp then

                freezeKillRoot(
                    hrp
                )


                -- Dejar al personaje derecho
                -- exactamente DONDE está.
                local _, rotY, _ =
                    hrp.CFrame:
                        ToEulerAnglesXYZ()


                hrp.CFrame =
                    CFrame.new(
                        hrp.Position
                    )
                    * CFrame.Angles(
                        0,
                        rotY,
                        0
                    )
            end


            killAllBaseCFrame =
                nil

            killAllBaseCharacter =
                nil

            killAllResting =
                false

            killAllRestCharacter =
                nil

            killAllWasSafe =
                false

            killAllIdleFree =
                false

            table.clear(
                failedTargets
            )
        end
    end
})

-- ====================
-- HITBOX EXPANDER OPTIMIZADO (LAZY LOADING)
-- ==========================================
Tabs.Aim:Section({Title = "Expandir Hitbox"})



UIElements.TogHitbox = Tabs.Aim:Toggle({
    Title = "Aumentar Hitbox",
    Desc = "Expande la caja de colisión de los enemigos para que no falles balas.",
    Value = false,
    Callback = function(s) 
        hitboxEnabled = s 
         -- ENCIENDE/APAGA EL BUCLE
    end
})

UIElements.TogHbInv = Tabs.Aim:Toggle({
    Title = "Hitbox Invisible", 
    Desc = "Oculta las cajas de los enemigos.",
    Value = false,
    Callback = function(s) hitboxInvisible = s end
})

UIElements.SliHitbox = Tabs.Aim:Slider({
    Title = "Tamaño de Hitbox",
    Desc = "10 - 20 max recomendado",
    Step = 1,
    Value = {Min = 2, Max = 50, Default = 10}, 
    Callback = function(v) hitboxSize = v end
})

Tabs.Aim:Input({
    Title = "Escribir Tamaño Exacto",
    Placeholder = "Ej: 2, 12, 25...",
    Callback = function(Text)
        local num = tonumber(Text)
        if num then
            hitboxSize = num
            pcall(function() if num >= 2 and num <= 50 then UIElements.SliHitbox:Set(num) end end)
            showBottomMessage("Hitbox fijada en: " .. num)
        end
    end,
})


UIElements.SliHitboxTrans = Tabs.Aim:Slider({
    Title = "Transparencia del Hitbox",
    Desc = "0 = Color Sólido | 1 = Invisible.",
    Step = 0.05,
    Value = {Min = 0.0, Max = 1.0, Default = 0.6}, 
    Callback = function(v) hitboxTransparency = v end
})

-- ==========================================
-- PESTAÑA VISUALES (ESP & SPOOFER)
-- ==========================================


local spoofLoop = nil
local isWorkspaceLooping = false
local originalData = {}

function safeReplace(str, find, replace) local safeFind = find:gsub("[%-%^%$%(%)%%%.%[%]%*%+%?]", "%%%1") return (str:gsub(safeFind, replace)) end
function processText(v, myName, myDisp)
    -- 🔥 ANTI-LAG: Evitamos que el sistema hackee los textos del propio Hub
    local parentGui = v:FindFirstAncestorWhichIsA("ScreenGui")
    if parentGui and (string.find(parentGui.Name, "WindUI") or string.find(parentGui.Name, "iLunX") or string.find(parentGui.Name, "Onyx")) then return end

    if v:IsA("TextLabel") or v:IsA("TextBox") or v:IsA("TextButton") then
        local txt = v.Text local hasName = false
        if txt and txt ~= "" then if string.find(txt, myName, 1, true) or string.find(txt, myDisp, 1, true) then hasName = true end end
        if hasName and not originalData[v] then
            originalData[v] = { Text = txt, Color = v.TextColor3, TextTransp = v.TextTransparency, StrokeTransp = v.TextStrokeTransparency, Strokes = {} }
            for _, obj in pairs(v:GetChildren()) do if obj:IsA("UIStroke") then originalData[v].Strokes[obj] = { Enabled = obj.Enabled, Transp = obj.Transparency, Thickness = obj.Thickness } end end
        end
        if originalData[v] then
            if fakeNameEnabled or creatorTagEnabled then
                local newText = originalData[v].Text local baseName = fakeNameEnabled and spoofNameText or myDisp
                newText = string.gsub(newText, "%[VIP%] ", "") newText = string.gsub(newText, "%[VIP%]", "") newText = string.gsub(newText, "<font color=\"#bee1e7\">%[Content Creator%]</font> ", "") newText = string.gsub(newText, "%[Content Creator%] ", "") newText = string.gsub(newText, "%[Content Creator%]", "")
                local isOverheadTag = false
                if player.Character then
                    if v:IsDescendantOf(player.Character) then isOverheadTag = true
                    else local parentGui = v:FindFirstAncestorWhichIsA("BillboardGui") if parentGui and parentGui.Adornee and parentGui.Adornee:IsDescendantOf(player.Character) then isOverheadTag = true end end
                end
                local finalName = baseName
                if creatorTagEnabled and isOverheadTag then v.RichText = true finalName = '<font color="#bee1e7">[Content Creator]</font> ' .. baseName end
                newText = safeReplace(newText, myName, finalName) newText = safeReplace(newText, myDisp, finalName)
                v.Text = newText v.TextTransparency = originalData[v].TextTransp v.TextStrokeTransparency = originalData[v].StrokeTransp
                for _, obj in pairs(v:GetChildren()) do if obj:IsA("UIStroke") and originalData[v].Strokes[obj] then obj.Enabled = originalData[v].Strokes[obj].Enabled end end
                if rainbowEnabled then v.TextColor3 = Color3.fromHSV(tick() % 4 / 4, 1, 1) else v.TextColor3 = originalData[v].Color end
            elseif hideNameEnabled then
                v.Text = " " v.TextTransparency = 1 v.TextStrokeTransparency = 1
                for _, obj in pairs(v:GetChildren()) do if obj:IsA("UIStroke") then obj.Enabled = false obj.Transparency = 1 obj.Thickness = 0 end end
            else
                v.Text = originalData[v].Text
                if rainbowEnabled then v.TextColor3 = Color3.fromHSV(tick() % 4 / 4, 1, 1) else v.TextColor3 = originalData[v].Color end
                v.TextTransparency = originalData[v].TextTransp v.TextStrokeTransparency = originalData[v].StrokeTransp
                for _, obj in pairs(v:GetChildren()) do if obj:IsA("UIStroke") and originalData[v].Strokes[obj] then obj.Enabled = originalData[v].Strokes[obj].Enabled obj.Transparency = originalData[v].Strokes[obj].Transp obj.Thickness = originalData[v].Strokes[obj].Thickness end end
            end
        end
    end
end
local visualConnections = {} -- 🚀 Nueva tabla para guardar eventos

function updateSystem()
    local myName = player.Name 
    local myDisp = player.DisplayName

    -- Escaneo de un solo toque (Súper ligero)
    task.spawn(function() 
        for _, p in ipairs(listaJugadores) do
            if p.Character then
                for _, v in pairs(p.Character:GetDescendants()) do
                    if v:IsA("TextLabel") or v:IsA("TextBox") then processText(v, myName, myDisp) end
                end
            end
        end
        local pGui = player:FindFirstChild("PlayerGui")
        if pGui then
            for _, v in pairs(pGui:GetDescendants()) do
                if v:IsA("TextLabel") or v:IsA("TextBox") then processText(v, myName, myDisp) end
            end
        end
    end)

    if hideNameEnabled or fakeNameEnabled or rainbowEnabled or creatorTagEnabled then
        if not isWorkspaceLooping then
            isWorkspaceLooping = true
            
            function infectarTextoSeguro(v)
                local parentGui = v:FindFirstAncestorWhichIsA("ScreenGui")
                if parentGui and (string.find(parentGui.Name, "WindUI") or string.find(parentGui.Name, "iLunX") or string.find(parentGui.Name, "Onyx")) then return end

                if v:IsA("TextLabel") or v:IsA("TextBox") or v:IsA("TextButton") then
                    processText(v, myName, myDisp) 
                    if not v:GetAttribute("AstraInfectado") then
                        v:SetAttribute("AstraInfectado", true)
                        runtime.TrackInfectedText(v)
                        runtime.Track(v:GetPropertyChangedSignal("Text"):Connect(function()
                            if isWorkspaceLooping and v.Text ~= spoofNameText and v.Text ~= " " and not string.find(v.Text, spoofNameText) and not string.find(v.Text, "%[Content Creator%]") then
                                originalData[v] = nil 
                                processText(v, myName, myDisp)
                            end
                        end))
                    end
                end
            end

            -- 🚀 OPTIMIZACIÓN: Solo vigilamos lo que "aparece nuevo", no escaneamos lo viejo infinitamente.
            local pGui = player:FindFirstChild("PlayerGui")
            if pGui then
                table.insert(visualConnections, runtime.Track(pGui.DescendantAdded:Connect(function(nuevoObjeto) 
                    if isWorkspaceLooping and (nuevoObjeto:IsA("TextLabel") or nuevoObjeto:IsA("TextBox") or nuevoObjeto:IsA("TextButton")) then 
                        infectarTextoSeguro(nuevoObjeto)
                    end 
                end)))
            end
            
            local successCore, coreGui = pcall(function() return game:GetService("CoreGui") end)
            if successCore and coreGui then
                table.insert(visualConnections, runtime.Track(coreGui.DescendantAdded:Connect(function(nuevoObjeto) 
                    if isWorkspaceLooping and (nuevoObjeto:IsA("TextLabel") or nuevoObjeto:IsA("TextBox") or nuevoObjeto:IsA("TextButton")) then 
                        infectarTextoSeguro(nuevoObjeto)
                    end 
                end)))
            end
        end 
    else
        isWorkspaceLooping = false
        
        for _, conn in ipairs(visualConnections) do conn:Disconnect() end
        visualConnections = {}
        
        local char = player.Character if char then local hum = char:FindFirstChild("Humanoid") if hum then hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer end end
        
        for v, data in pairs(originalData) do
            if v and v.Parent then
                v.Text = data.Text v.TextColor3 = data.Color v.TextTransparency = data.TextTransp v.TextStrokeTransparency = data.StrokeTransp
                for stroke, strokeData in pairs(data.Strokes) do if stroke and stroke.Parent then stroke.Enabled = strokeData.Enabled stroke.Transparency = strokeData.Transp stroke.Thickness = strokeData.Thickness end end
            end
        end
    end
end

UIElements.TogHideName = Tabs.Vis:Toggle({
    Title = "Ocultar mi Nombre (Visual)", 
    Desc = "Vuelve tu nombre invisible en tu pantalla.",
    Callback = function(s) hideNameEnabled = s updateSystem() showBottomMessage(s and "Nombre invisible." or "Nombre visible.") end
})

UIElements.TogFakeName = Tabs.Vis:Toggle({
    Title = "Activar Nombre Falso", 
    Desc = "Reemplaza tu nombre por uno falso (Solo tú lo ves).",
    Callback = function(s) fakeNameEnabled = s updateSystem() showBottomMessage(s and "Nombre falso activado." or "Nombre falso desactivado.") end
})


UIElements.TogTag = Tabs.Vis:Toggle({
    Title = "Tag [Content Creator]", 
    Desc = "Te pone la etiqueta de creador de contenido.",
    Callback = function(s) creatorTagEnabled = s updateSystem() pcall(function() showBottomMessage(s and "Tag de Creador activado." or "Tag de Creador desactivado.") end) end
})

Tabs.Vis:Input({Title = "Nuevo Nombre", Placeholder = "Escribe tu nombre falso...", Callback = function(t) if t ~= "" then spoofNameText = t if fakeNameEnabled then updateSystem() end showBottomMessage("Nombre guardado: " .. spoofNameText) end end})
UIElements.TogRbw = Tabs.Vis:Toggle({
    Title = "Efecto arcoíris en nombre", 
    Desc = "Hace que tu nombre brille cambiando de colores RGB.",
    Callback = function(s) rainbowEnabled = s updateSystem() end
})

-- ==========================================
-- ESP OPTIMIZADO (LAZY LOADING)
-- ==========================================
Tabs.Vis:Section({Title = "ESP de jugadores"})


UIElements.TogEsp = Tabs.Vis:Toggle({
    Title = "ESP de jugadores", 
    Desc = "Activa las capas visuales configuradas para enemigos.",
    Callback = function(s) 
        espEnabled = s 
  
    end
})

UIElements.ColEsp = Tabs.Vis:Colorpicker({Title = "Color del ESP", Default = Color3.fromRGB(255,255,255), Callback = function(c) espColor = c end})

Tabs.Vis:Section({Title = "Capas del ESP"})
UIElements.TogEspGl = Tabs.Vis:Toggle({Title = "Mostrar Resplandor", Value = true, Callback = function(s) espSettings.Glow = s end})
UIElements.TogEspNm = Tabs.Vis:Toggle({Title = "Mostrar Nombre", Value = true, Callback = function(s) espSettings.Name = s end})
UIElements.TogEspDs = Tabs.Vis:Toggle({Title = "Mostrar Distancia", Value = true, Callback = function(s) espSettings.Distance = s end})
UIElements.TogEspBox = Tabs.Vis:Toggle({
    Title = "ESP Box 2D",
    Desc = "Caja estable anclada al cuerpo real; ignora hitbox y accesorios.",
    Value = false,
    Callback = function(s) espSettings.Box = s end,
})
UIElements.TogEspHealth = Tabs.Vis:Toggle({
    Title = "Barra de vida",
    Desc = "Muestra la vida junto a la caja sin crear otro bucle de renderizado.",
    Value = false,
    Callback = function(s) espSettings.HealthBar = s end,
})

UIElements.TogEspLines = Tabs.Vis:Toggle({
    Title = "Mostrar Líneas", 
    Desc = "Dibuja una línea desde el centro de tu pantalla hasta cada enemigo.",
    Callback = function(s) espLinesEnabled = s end
})

-- ==========================================
-- DIBUJADO EN PANTALLA 2D (FOV, Tracers, Box y Vida) - UN SOLO RENDER
-- ==========================================
local FOVCircle = runtime.TrackDrawing(Drawing.new("Circle"))
FOVCircle.Filled = false
FOVCircle.Color = Color3.fromRGB(255, 255, 255)
FOVCircle.Visible = false
FOVCircle.Thickness = 1.7
FOVCircle.NumSides = 64

local tracerLines = {}
local tracersLimpios = true
local tracerAccumulator = 0
local TRACER_INTERVAL = 1 / 30
local MAX_ESP_DISTANCE_SQ = MAX_ESP_DISTANCE * MAX_ESP_DISTANCE
local cachedViewportX, cachedViewportY = -1, -1
local centroVector = Vector2_new(0, 0)
local tracerOrigin = Vector2_new(0, 0)
local fovIdleColor = Color3_fromRGB(255, 255, 255)
local fovTargetColor = Color3_fromRGB(0, 255, 0)
local esp2dClean = true
runtime.ESP2D = {}

function runtime.HideESP2DEntry(entry)
    if not entry then return end
    if entry.Box and entry.Box.Visible then entry.Box.Visible = false end
    if entry.HealthBg and entry.HealthBg.Visible then entry.HealthBg.Visible = false end
    if entry.Health and entry.Health.Visible then entry.Health.Visible = false end
end

function runtime.HideAllESP2D()
    if esp2dClean then return end
    for _, entry in pairs(runtime.ESP2D) do runtime.HideESP2DEntry(entry) end
    esp2dClean = true
end

function runtime.GetESP2DEntry(p)
    local entry = runtime.ESP2D[p]
    if entry then return entry end
    entry = {}

    local okBox, box = pcall(function() return Drawing.new("Square") end)
    if okBox and box then
        box.Filled = false
        box.Thickness = 1.5
        box.Transparency = 1
        box.Visible = false
        runtime.TrackDrawing(box)
        entry.Box = box
    end

    local healthBg = runtime.TrackDrawing(Drawing.new("Line"))
    healthBg.Thickness = 4
    healthBg.Transparency = 0.65
    healthBg.Color = Color3.fromRGB(0, 0, 0)
    healthBg.Visible = false
    entry.HealthBg = healthBg

    local health = runtime.TrackDrawing(Drawing.new("Line"))
    health.Thickness = 2
    health.Transparency = 1
    health.Visible = false
    entry.Health = health

    runtime.ESP2D[p] = entry
    return entry
end

local function hideTracersOnce()
    if tracersLimpios then return end
    for _, tLine in pairs(tracerLines) do
        if tLine.Visible then tLine.Visible = false end
    end
    tracersLimpios = true
end

runtime.Track(RunService.RenderStepped:Connect(function(deltaTime)
    tracerAccumulator = tracerAccumulator + deltaTime
    if tracerAccumulator < TRACER_INTERVAL then return end
    tracerAccumulator = tracerAccumulator - TRACER_INTERVAL

    local camera = workspace.CurrentCamera
    local wantsESP2D = espEnabled and (espSettings.Box or espSettings.HealthBar)
    if not fovVisiblePreference and not espLinesEnabled and not wantsESP2D then
        if FOVCircle.Visible then FOVCircle.Visible = false end
        hideTracersOnce()
        runtime.HideAllESP2D()
        return
    end

    local viewport = camera.ViewportSize
    if viewport.X ~= cachedViewportX or viewport.Y ~= cachedViewportY then
        cachedViewportX, cachedViewportY = viewport.X, viewport.Y
        centroVector = Vector2_new(viewport.X / 2, viewport.Y / 2)
        tracerOrigin = Vector2_new(centroVector.X, viewport.Y - 2)
    end

    if fovVisiblePreference then
        FOVCircle.Position = centroVector
        FOVCircle.Radius = fovRadius
        FOVCircle.Visible = true
        FOVCircle.Color = aimHookState.Target and fovTargetColor or fovIdleColor
    elseif FOVCircle.Visible then
        FOVCircle.Visible = false
    end

    if not espEnabled or enLobby then
        hideTracersOnce()
        runtime.HideAllESP2D()
        return
    end

    tracersLimpios = not espLinesEnabled
    local myChar = player.Character
    local myCore = myChar and getCharCore(myChar) or nil
    local myRoot = myCore and myCore.HRP
    local myPos = myRoot and myRoot.Position or camera.CFrame.Position

    for i = 1, #listaJugadores do
        local p = listaJugadores[i]
        if p ~= player then
            local char = p.Character
            local core = char and getCharCore(char) or nil
            local hrp = core and core.HRP
            local hum = core and core.Humanoid
            local valid = false
            local rootScreen, onScreen

            if hrp and hum and hum.Health > 0 and isEnemy(p) and not enemigoEnLobby(char, hrp) then
                local delta = myPos - hrp.Position
                if delta:Dot(delta) <= MAX_ESP_DISTANCE_SQ then
                    rootScreen, onScreen = camera:WorldToViewportPoint(hrp.Position)
                    valid = onScreen and rootScreen.Z > 0
                end
            end

            local tLine = tracerLines[p]
            if espLinesEnabled and valid then
                if not tLine then
                    tLine = runtime.TrackDrawing(Drawing.new("Line"))
                    tLine.Thickness = 1.35
                    tLine.Transparency = 0.92
                    tLine.Visible = false
                    tracerLines[p] = tLine
                end
                tLine.From = tracerOrigin
                tLine.To = Vector2_new(rootScreen.X, rootScreen.Y)
                tLine.Color = espColor
                tLine.Visible = true
            elseif tLine and tLine.Visible then
                tLine.Visible = false
            end

            local entry = runtime.ESP2D[p]
            if wantsESP2D and valid then
                esp2dClean = false
                entry = entry or runtime.GetESP2DEntry(p)
                -- OPT: caja corporal estable. NO usamos Character:GetBoundingBox(),
                -- porque incluye el Torso falso del Hitbox Expander y accesorios/limiteds.
                local head = core and core.Head
                local up = hrp.CFrame.UpVector
                local topWorld = head and (head.Position + up * (head.Size.Y * 0.55))
                    or (hrp.Position + up * 2.8)

                local leftFoot = core and core.LeftFoot
                local rightFoot = core and core.RightFoot
                local bottomWorld
                if leftFoot or rightFoot then
                    local lfPoint = leftFoot and (leftFoot.Position - up * (leftFoot.Size.Y * 0.5)) or nil
                    local rfPoint = rightFoot and (rightFoot.Position - up * (rightFoot.Size.Y * 0.5)) or nil
                    if lfPoint and rfPoint then
                        -- Escogemos el punto más bajo respecto al eje vertical del propio personaje.
                        bottomWorld = ((lfPoint - hrp.Position):Dot(up) < (rfPoint - hrp.Position):Dot(up)) and lfPoint or rfPoint
                    else
                        bottomWorld = lfPoint or rfPoint
                    end
                else
                    bottomWorld = hrp.Position - up * ((hum.HipHeight or 2) + hrp.Size.Y * 0.5)
                end

                local topScreen = camera:WorldToViewportPoint(topWorld)
                local bottomScreen = camera:WorldToViewportPoint(bottomWorld)
                local geometryValid = topScreen.Z > 0.05 and bottomScreen.Z > 0.05

                if geometryValid then
                    local rawH = math.abs(bottomScreen.Y - topScreen.Y)
                    local maxH = math.max(8, viewport.Y * 0.92)
                    local boxH = math.clamp(rawH, 8, maxH)
                    local ratioW = hum.RigType == Enum.HumanoidRigType.R6 and 0.62 or 0.55
                    local boxW = math.clamp(boxH * ratioW, 6, math.max(6, viewport.X * 0.62))
                    local x = rootScreen.X - boxW * 0.5
                    local y = math.min(topScreen.Y, bottomScreen.Y)

                    if entry.Box then
                        entry.Box.Position = Vector2_new(x, y)
                        entry.Box.Size = Vector2_new(boxW, boxH)
                        if entry.LastBoxColor ~= espColor then
                            entry.Box.Color = espColor
                            entry.LastBoxColor = espColor
                        end
                        if entry.Box.Visible ~= espSettings.Box then entry.Box.Visible = espSettings.Box end
                    end

                    if espSettings.HealthBar then
                        local ratio = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
                        local bx = x - 5
                        local byBottom = y + boxH
                        local byHealth = byBottom - (boxH * ratio)
                        entry.HealthBg.From = Vector2_new(bx, y)
                        entry.HealthBg.To = Vector2_new(bx, byBottom)
                        if not entry.HealthBg.Visible then entry.HealthBg.Visible = true end
                        entry.Health.From = Vector2_new(bx, byBottom)
                        entry.Health.To = Vector2_new(bx, byHealth)
                        entry.Health.Color = Color3.fromHSV(ratio * 0.33, 0.92, 1)
                        if not entry.Health.Visible then entry.Health.Visible = true end
                    else
                        if entry.HealthBg.Visible then entry.HealthBg.Visible = false end
                        if entry.Health.Visible then entry.Health.Visible = false end
                    end
                else
                    runtime.HideESP2DEntry(entry)
                end
            elseif entry then
                runtime.HideESP2DEntry(entry)
            end
        end
    end
end))

runtime.Track(Players.PlayerRemoving:Connect(function(p)
    if tracerLines[p] then pcall(function() tracerLines[p]:Remove() end); tracerLines[p] = nil end
    local entry = runtime.ESP2D[p]
    if entry then
        for _, drawing in pairs(entry) do
            if typeof(drawing) ~= "function" then pcall(function() drawing:Remove() end) end
        end
        runtime.ESP2D[p] = nil
    end
    cleanESP(p)
end))



-- ==========================================
-- PESTAÑA MOVIMIENTO
-- ==========================================


local bg, bv
local Controls

-- FIX: Lo cargamos en segundo plano para que NUNCA congele la interfaz
task.spawn(function()
    local PlayerModule = require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule"))
    Controls = PlayerModule:GetControls()
end)








-- ==========================================
-- SISTEMA DE BOTONES FLOTANTES (ESTILO MM2)
-- ==========================================
_G.EditFloatingButtons = true -- Lo dejamos en true para que puedas moverlo libremente con tu makeDraggable actual
_G.FloatingButtonsShape = "Rectángulo"
local floatingButtonsList = {}

function createFloatingBtn(name, startPos, internalId)
    local btn = Instance.new("TextButton")
    btn.Name = internalId or name
    btn.Size = UDim2.fromOffset(156, 48)
    btn.Position = startPos
    btn.BackgroundColor3 = Color3.fromRGB(14, 14, 14)
    btn.BackgroundTransparency = 0.06
    btn.Text = name
    btn.TextTransparency = 1
    btn.TextSize = 12
    btn.AutoButtonColor = false
    btn.Visible = false
    btn.ZIndex = 50
    btn.Parent = screenGui
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 12)
    local stroke = Instance.new("UIStroke", btn)
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Thickness = 1
    stroke.Color = Color3.fromRGB(60, 60, 60)
    stroke.Transparency = 0.2

    local title = Instance.new("TextLabel", btn)
    title.Name = "ControlTitle"
    title.BackgroundTransparency = 1
    title.Position = UDim2.fromOffset(14, 6)
    title.Size = UDim2.new(1, -42, 0, 20)
    title.Font = Enum.Font.GothamMedium
    title.TextSize = 12
    title.TextColor3 = Color3.fromRGB(240, 240, 240)
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.TextTruncate = Enum.TextTruncate.AtEnd
    title.ZIndex = 51
    local stateLabel = Instance.new("TextLabel", btn)
    stateLabel.Name = "ControlState"
    stateLabel.BackgroundTransparency = 1
    stateLabel.Position = UDim2.fromOffset(14, 26)
    stateLabel.Size = UDim2.new(1, -42, 0, 14)
    stateLabel.Font = Enum.Font.GothamMedium
    stateLabel.TextSize = 8
    stateLabel.TextColor3 = Color3.fromRGB(135, 135, 135)
    stateLabel.TextXAlignment = Enum.TextXAlignment.Left
    stateLabel.ZIndex = 51
    local dot = Instance.new("Frame", btn)
    dot.Name = "StateDot"
    dot.AnchorPoint = Vector2.new(1, 0.5)
    dot.Position = UDim2.new(1, -14, 0.5, 0)
    dot.Size = UDim2.fromOffset(6, 6)
    dot.BorderSizePixel = 0
    dot.ZIndex = 51
    Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)
    local hovered = false
    local function updateVisual()
        local hidden = _G.AstraBotonesOcultos == true
        local enabled = btn.Text:match(":%s*ON$") ~= nil
        title.Text = btn.Text:gsub(":%s*O[NF]+$", ""):gsub("AutoShoot", "Auto Shoot")
        stateLabel.Text = enabled and "ACTIVO" or "INACTIVO"
        title.TextTransparency = hidden and 1 or 0
        stateLabel.TextTransparency = hidden and 1 or 0
        dot.BackgroundTransparency = hidden and 1 or 0
        dot.BackgroundColor3 = enabled and Color3.fromRGB(242, 242, 242) or Color3.fromRGB(80, 80, 80)
        btn.BackgroundTransparency = hidden and 1 or 0.06
        btn.BackgroundColor3 = hovered and Color3.fromRGB(25, 25, 25) or Color3.fromRGB(14, 14, 14)
        stroke.Transparency = hidden and 1 or 0.2
        stroke.Color = enabled and Color3.fromRGB(175, 175, 175) or Color3.fromRGB(60, 60, 60)
        if btn.TextTransparency ~= 1 then btn.TextTransparency = 1 end
    end
    runtime.Track(btn:GetPropertyChangedSignal("Text"):Connect(updateVisual))
    runtime.Track(btn:GetAttributeChangedSignal("Ghosted"):Connect(updateVisual))
    runtime.Track(btn.MouseEnter:Connect(function() hovered = true; updateVisual() end))
    runtime.Track(btn.MouseLeave:Connect(function() hovered = false; updateVisual() end))
    updateVisual()

    makeDraggable(btn, btn)
    
    local dragStartPos = nil; local validClick = false
    btn.InputBegan:Connect(function(input) 
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then 
            dragStartPos = input.Position; validClick = true 
        end 
    end)
    btn.InputChanged:Connect(function(input) 
        if dragStartPos and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then 
            if (input.Position - dragStartPos).Magnitude > 5 then validClick = false end 
        end 
    end)
    
    table.insert(floatingButtonsList, btn)
    return btn, function() return validClick end, stroke
end

Tabs.Mov:Section({Title = "Modo Fantasma y Salto"})

-- ==========================================
-- 1. SALTO INFINITO
-- ==========================================
local infJumpConnection = nil
UIElements.TogInfJump = Tabs.Mov:Toggle({
    Title = "Salto Infinito",
    Desc = "Mantener presionado para saltar infinitamente.",
    Value = false,
    Callback = function(state)
        if state then
            infJumpConnection = runtime.Track(UserInputService.JumpRequest:Connect(function()
                local char = player.Character
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                if hum then
                    hum:ChangeState(Enum.HumanoidStateType.Jumping)
                end
            end))
        else
            if infJumpConnection then 
                infJumpConnection:Disconnect() 
                infJumpConnection = nil 
            end
        end
    end
})

-- ==========================================
-- 2. MODO FANTASMA (FLICKER + ANTI-RESPAWN BUG)
-- ==========================================
local loopHeartbeat = nil
local isHidden = false
local offsetDistance = 5000 -- Distancia estable: evita el error de precisión que aparece a 100k studs.
local ghostEnabled = false
runtime.GhostOriginalTransparency = setmetatable({}, {__mode = "k"})

function runtime.RestoreGhostTransparency(char)
    if not char then return end
    for part, original in pairs(runtime.GhostOriginalTransparency) do
        if part and part.Parent and part:IsDescendantOf(char) then
            part.Transparency = original
        end
        runtime.GhostOriginalTransparency[part] = nil
    end
end

runtime.GhostCleanup = function()
    if loopHeartbeat then pcall(function() loopHeartbeat:Disconnect() end); loopHeartbeat = nil end
    pcall(function() RunService:UnbindFromRenderStep("iLunXGhost") end)
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if isHidden and hrp then
        pcall(function() hrp.CFrame = hrp.CFrame - Vector3.new(0, offsetDistance, 0) end)
        isHidden = false
    end
    runtime.RestoreGhostTransparency(char)
    ghostEnabled = false
end

UIElements.TogGhostMode = Tabs.Mov:Toggle({
    Title = "Activar Modo Fantasma",
    Desc = "Se invisible para los demas.",
    Value = false,
    Callback = function(state)
        ghostEnabled = state
        local char = player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        
        if state then
            if not hrp or not hum then return end
            
            -- FASE DE RED: Te sube en Heartbeat (para engañar al servidor al final del frame)
            loopHeartbeat = runtime.Track(RunService.Heartbeat:Connect(function()
                if not isHidden and hrp and hum and hum.Health > 0 then
                    hrp.AssemblyAngularVelocity = Vector3.zero
                    hrp.CFrame = hrp.CFrame + Vector3.new(0, offsetDistance, 0)
                    isHidden = true
                end
            end))

            -- 🔥 EL FIX MAGISTRAL DE LA CÁMARA 🔥
            -- BindToRenderStep con prioridad 150 obliga a que tu mono baje
            -- ANTES de que el script de la cámara de Roblox (Prioridad 200) se actualice.
            RunService:BindToRenderStep("iLunXGhost", 150, function()
                if isHidden and hrp and hum and hum.Health > 0 then
                    hrp.CFrame = hrp.CFrame - Vector3.new(0, offsetDistance, 0)
                    isHidden = false
                end
            end)
            
            -- Transparencia local
            for _, part in pairs(char:GetDescendants()) do
                if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" and not part:FindFirstAncestorWhichIsA("Tool") then
                    if runtime.GhostOriginalTransparency[part] == nil then
                        runtime.GhostOriginalTransparency[part] = part.Transparency
                    end
                    part.Transparency = math.max(part.Transparency, 0.5)
                end
            end
        else
            -- Apagar bucles
            if loopHeartbeat then loopHeartbeat:Disconnect(); loopHeartbeat = nil end
            pcall(function() RunService:UnbindFromRenderStep("iLunXGhost") end)
            
            -- Rescate de CFrame por si lo apagas a la mitad del frame
            if isHidden and hrp and hum and hum.Health > 0 then
                hrp.CFrame = hrp.CFrame - Vector3.new(0, offsetDistance, 0)
                isHidden = false
            end
            
            -- Restaurar exactamente la transparencia que tenía cada parte.
            runtime.RestoreGhostTransparency(char)
        end
        
        -- Sincronizar el texto del botón flotante
        pcall(function()
            if ghostBtn then
                if state then
                    ghostBtn.Text = "Fantasma: ON"
                    ghostBtn.TextColor3 = Color3.fromHex("#DCE0E5")
                    if ghostStroke then ghostStroke.Color = Color3.fromRGB(255, 255, 255) end
                else
                    ghostBtn.Text = "Fantasma: OFF"
                    ghostBtn.TextColor3 = Color3.fromHex("#F3F4F5")
                    if ghostStroke then ghostStroke.Color = Color3.fromHex("#464B52") end
                end
            end
        end)
    end
})

-- 1. Creamos el botón flotante
ghostBtn, getGhostClick, ghostStroke = createFloatingBtn("Fantasma: OFF", UDim2.new(0.8, -150, 0.5, 0), "BtnFantasma")

-- 2. Lógica del botón flotante (Maneja el Toggle principal sin spam)
ghostBtn.MouseButton1Click:Connect(function() 
    if not getGhostClick() then return end 
    local newState = not ghostEnabled 
    task.spawn(function()
        -- Silenciamos el sistema de notificaciones temporalmente
        local wasSuppressed = runtime.SuppressNotifications
        runtime.SuppressNotifications = true
        
        -- Cambiamos el estado (sin que el menú avise)
        pcall(function() UIElements.TogGhostMode:Set(newState) end)
        
        -- Restauramos las notificaciones a la normalidad
        runtime.SuppressNotifications = wasSuppressed
        
        -- Y borramos el showBottomMessage que estaba aquí abajo
    end)
end)

-- 3. Mostrar/Ocultar Botón Fantasma
UIElements.ToggleGhost = Tabs.Mov:Toggle({
    Title = "Mostrar Botón Flotante",
    Value = false,
    Callback = function(state)
        ghostBtn.Visible = state
        -- Seguridad: Si ocultan el botón y estaban invisibles, se apaga el modo.
        if not state and ghostEnabled then 
            task.spawn(function() pcall(function() UIElements.TogGhostMode:Set(false) end) end)
        end
    end
})

-- Fix de Respawn: Fuerza el apagado del ghost al morir o iniciar ronda
runtime.Track(player.CharacterAdded:Connect(function()
    if ghostEnabled then
        isHidden = false -- Resetea la matemática
        pcall(function() UIElements.TogGhostMode:Set(false) end)
    end
end))




-- ==========================================
-- BOTONES FLOTANTES: AUTO SHOOT Y SILENT AIM
-- ==========================================

-- Botón Auto Shoot (Normal)
local asBtn, getAsClick, asStroke = createFloatingBtn("AutoShoot: OFF", UDim2.new(0.8, -150, 0.35, 0), "BtnAutoShoot")

asBtn.MouseButton1Click:Connect(function() 
    if not getAsClick() then return end 
    local newState = not autoShootEnabled 
    
    task.spawn(function()
        pcall(function() UIElements.TogAutoShoot:Set(newState) end)
        
        if newState then
            asBtn.Text = "AutoShoot: ON"
            asBtn.TextColor3 = Color3.fromHex("#DCE0E5")
            asStroke.Color = Color3.fromRGB(255, 255, 255)
        else
            asBtn.Text = "AutoShoot: OFF"
            asBtn.TextColor3 = Color3.fromHex("#F3F4F5")
            asStroke.Color = Color3.fromHex("#464B52")
        end
    end)
end)

-- Botón Silent Aim (Pistola)
local saBtn, getSaClick, saStroke = createFloatingBtn("Silent Aim: OFF", UDim2.new(0.8, -150, 0.45, 0), "BtnSilentAim")

saBtn.MouseButton1Click:Connect(function() 
    if not getSaClick() then return end 
    local newState = not silentAimPistolaEnabled -- <--- CORREGIDO
    
    task.spawn(function()
        pcall(function() UIElements.TogSilentAimPistola:Set(newState) end) -- <--- CORREGIDO
        
        if newState then
            saBtn.Text = "Silent Aim: ON"
            saBtn.TextColor3 = Color3.fromHex("#DCE0E5")
            saStroke.Color = Color3.fromRGB(255, 255, 255)
        else
            saBtn.Text = "Silent Aim: OFF"
            saBtn.TextColor3 = Color3.fromHex("#F3F4F5")
            saStroke.Color = Color3.fromHex("#464B52")
        end
    end)
end)

-- Toggles para mostrar/ocultar los botones (se agregarán a la pestaña de Aimbot automáticamente)
UIElements.ToggleAsBtn = Tabs.Aim:Toggle({
    Title = "Mostrar Botón Flotante (AutoShoot)",
    Value = false,
    Callback = function(state)
        asBtn.Visible = state
    end
})

UIElements.ToggleSaBtn = Tabs.Aim:Toggle({
    Title = "Mostrar Botón Flotante (Silent Aim)",
    Value = false,
    Callback = function(state)
        saBtn.Visible = state
    end
})





UIElements.SliderGhostSpeed = Tabs.Mov:Slider({
    Title = "Velocidad Fantasma", 
    Step = 1, 
    Value = {Min = 10, Max = 150, Default = 40}, 
    Callback = function(Value) invisFlySpeed = Value end 
})

runtime.Track(player.CharacterAdded:Connect(function()
    isInvisible = false
    if fakeChar then fakeChar:Destroy(); fakeChar = nil end
    if fakePlatform then fakePlatform:Destroy(); fakePlatform = nil end
    if invisBg then invisBg:Destroy(); invisBg = nil end
    if invisBv then invisBv:Destroy(); invisBv = nil end
    
    -- Reseteamos el estilo del botón flotante
    if ghostBtn then
        ghostBtn.Text = "Fantasma: OFF"
        ghostBtn.TextColor3 = Color3.fromHex("#F3F4F5")
        if ghostStroke then ghostStroke.Color = Color3.fromHex("#464B52") end
    end
end))

-- ==========================================
-- PESTAÑA GRÁFICOS (SHADERS Y OPTIMIZACIÓN)
-- ==========================================
Tabs.Graficos:Section({Title = "Modos Visuales (Elige solo uno)"})

local shaderEffects = {}
local tokyowamiEffects = {}
local nightEffects = {}
local pinkEffects = {}
local nightActivo = false
local pinkActivo = false

local shaderAjustes = {
    -- Ajustes Noche
    Exposicion = 0.28,
    Sombras = 5,
    Neon = 0.45,
    LunaPos = 85,          
    Desenfoque = 2,        
    SuavidadSombras = 0.1, 
    ColorSaturacion = 0.15,
    
    -- Ajustes Pink Hour (Vaporwave)
    PinkRosa = 0.8,       -- Intensidad del Rosa
    PinkMorado = 0.7,     -- Intensidad del Morado
    PinkSaturacion = 0.4, -- Saturación
    PinkNeon = 0.3        -- Resplandor
}

-- 🔥 FUNCIÓN MAESTRA PARA ANIQUILAR NUBES Y ATMÓSFERA (OPTIMIZADA ANTI-FREEZE) 🔥
function ToggleNubesYAtmo(apagar, tag)
    local Lighting = game:GetService("Lighting")
    
    -- Las atmósferas solo existen dentro de Lighting, no hay que buscar en todo el mapa
    for _, obj in ipairs(Lighting:GetChildren()) do
        if obj:IsA("Atmosphere") then
            if apagar then
                if not obj:GetAttribute("OrigGuardado_"..tag) then
                    obj:SetAttribute("OrigDensity_"..tag, obj.Density)
                    obj:SetAttribute("OrigCapacity_"..tag, obj.Capacity)
                    obj:SetAttribute("OrigGuardado_"..tag, true)
                end
                obj.Density = 0
                obj.Capacity = 0
            else
                if obj:GetAttribute("OrigGuardado_"..tag) then
                    obj.Density = obj:GetAttribute("OrigDensity_"..tag)
                    obj.Capacity = obj:GetAttribute("OrigCapacity_"..tag)
                    obj:SetAttribute("OrigGuardado_"..tag, nil)
                end
            end
        end
    end
    
    -- Las nubes solo están sueltas en Workspace o Terrain, esto evita escanear 50,000 partes a lo loco
    function checkClouds(parentObj)
        if not parentObj then return end
        for _, obj in ipairs(parentObj:GetChildren()) do
            if obj:IsA("Clouds") then
                if apagar then
                    if not obj:GetAttribute("OrigGuardado_"..tag) then
                        obj:SetAttribute("OrigEnabled_"..tag, obj.Enabled)
                        obj:SetAttribute("OrigGuardado_"..tag, true)
                    end
                    obj.Enabled = false
                else
                    if obj:GetAttribute("OrigGuardado_"..tag) then
                        obj.Enabled = obj:GetAttribute("OrigEnabled_"..tag)
                        obj:SetAttribute("OrigGuardado_"..tag, nil)
                    end
                end
            end
        end
    end
    
    checkClouds(workspace)
    checkClouds(workspace:FindFirstChildOfClass("Terrain"))
end

-- 🔥 FUNCIÓN QUE ACTUALIZA EL PINK HOUR EN TIEMPO REAL 🔥
function UpdatePinkHourVibe()
    if not pinkActivo then return end
    local Lighting = game:GetService("Lighting")
    
    local rosa = shaderAjustes.PinkRosa
    local morado = shaderAjustes.PinkMorado
    
    -- Matemáticas para mezclar rosa y morado sin romper el RGB
    local r = math.clamp(math.floor(255 - (100 * morado)), 0, 255)
    local g = math.clamp(math.floor(255 - (155 * rosa) - (200 * morado)), 0, 255)
    local b = 255
    
    -- 1. Actualizar Efectos
    for _, effect in ipairs(pinkEffects) do
        if effect:IsA("ColorCorrectionEffect") then
            effect.TintColor = Color3.fromRGB(r, g, b)
            effect.Saturation = shaderAjustes.PinkSaturacion
            effect.Contrast = 0.05 + (0.1 * morado) + (0.05 * rosa)
        elseif effect:IsA("BloomEffect") then
            effect.Intensity = shaderAjustes.PinkNeon
        end
    end
    
    -- 2. Actualizar Iluminación del Mundo (Para que el 3D también cambie de color)
    Lighting.ColorShift_Top = Color3.fromRGB(math.floor(255 - (50 * morado)), math.floor(50 + (50 * (1-rosa))), math.floor(150 + (105 * morado)))
    Lighting.ColorShift_Bottom = Color3.fromRGB(math.floor(30 + (70 * rosa)), 0, math.floor(50 + (80 * morado)))
    Lighting.OutdoorAmbient = Color3.fromRGB(math.floor(50 + (80 * rosa)), 0, math.floor(80 + (80 * morado)))
    Lighting.Ambient = Color3.fromRGB(math.floor(60 + (30 * rosa)), math.floor(20 * (1-morado)), math.floor(80 + (40 * morado)))
    
    -- Si hay más morado, oscurecemos ligeramente la cámara para darle vibra nocturna
    Lighting.ExposureCompensation = 0.1 - (0.25 * morado)
end

-- ==========================================
-- 1. SHADERS TOKYOWAMI SHRINE (AESTHETIC)
-- ==========================================
UIElements.TogTokyowami = Tabs.Graficos:Toggle({
    Title = "Shaders Tokyowami",
    Desc = "Aplica Shaders originales.",
    Callback = function(Value)
        local Lighting = game:GetService("Lighting")

        if Value then
            if not Lighting:GetAttribute("OrigSaved") then
                Lighting:SetAttribute("OrigBright", Lighting.Brightness) Lighting:SetAttribute("OrigCSB", Lighting.ColorShift_Bottom) Lighting:SetAttribute("OrigCST", Lighting.ColorShift_Top) Lighting:SetAttribute("OrigOA", Lighting.OutdoorAmbient) Lighting:SetAttribute("OrigTime", Lighting.ClockTime) Lighting:SetAttribute("OrigFogC", Lighting.FogColor) Lighting:SetAttribute("OrigFogE", Lighting.FogEnd) Lighting:SetAttribute("OrigFogS", Lighting.FogStart) Lighting:SetAttribute("OrigExp", Lighting.ExposureCompensation) Lighting:SetAttribute("OrigShadow", Lighting.ShadowSoftness) Lighting:SetAttribute("OrigAmbient", Lighting.Ambient) Lighting:SetAttribute("OrigSaved", true)
            end

            for _, v in ipairs(tokyowamiEffects) do pcall(function() v:Destroy() end) end table.clear(tokyowamiEffects)

            local Bloom = Instance.new("BloomEffect") Bloom.Intensity = 0.1 Bloom.Threshold = 0 Bloom.Size = 100 Bloom.Parent = Lighting table.insert(tokyowamiEffects, Bloom)
            local Tropic = Instance.new("Sky") Tropic.Name = "Tropic" Tropic.SkyboxUp = "http://www.roblox.com/asset/?id=169210149" Tropic.SkyboxLf = "http://www.roblox.com/asset/?id=169210133" Tropic.SkyboxBk = "http://www.roblox.com/asset/?id=169210090" Tropic.SkyboxFt = "http://www.roblox.com/asset/?id=169210121" Tropic.StarCount = 100 Tropic.SkyboxDn = "http://www.roblox.com/asset/?id=169210108" Tropic.SkyboxRt = "http://www.roblox.com/asset/?id=169210143" Tropic.Parent = Lighting table.insert(tokyowamiEffects, Tropic)
            local Sky = Instance.new("Sky") Sky.SkyboxUp = "http://www.roblox.com/asset/?id=196263782" Sky.SkyboxLf = "http://www.roblox.com/asset/?id=196263721" Sky.SkyboxBk = "http://www.roblox.com/asset/?id=196263721" Sky.SkyboxFt = "http://www.roblox.com/asset/?id=196263721" Sky.CelestialBodiesShown = false Sky.SkyboxDn = "http://www.roblox.com/asset/?id=196263643" Sky.SkyboxRt = "http://www.roblox.com/asset/?id=196263721" Sky.Parent = Lighting table.insert(tokyowamiEffects, Sky)
            local Blur = Instance.new("BlurEffect") Blur.Size = 2 Blur.Parent = Lighting table.insert(tokyowamiEffects, Blur)
            local Inaritaisha = Instance.new("ColorCorrectionEffect") Inaritaisha.Name = "Inari taisha" Inaritaisha.Saturation = 0.05 Inaritaisha.TintColor = Color3.fromRGB(255, 224, 219) Inaritaisha.Parent = Lighting table.insert(tokyowamiEffects, Inaritaisha)
            local SunRays = Instance.new("SunRaysEffect") SunRays.Intensity = 0.05 SunRays.Parent = Lighting table.insert(tokyowamiEffects, SunRays)
            local Sunset = Instance.new("Sky") Sunset.Name = "Sunset" Sunset.SkyboxUp = "rbxassetid://323493360" Sunset.SkyboxLf = "rbxassetid://323494252" Sunset.SkyboxBk = "rbxassetid://323494035" Sunset.SkyboxFt = "rbxassetid://323494130" Sunset.SkyboxDn = "rbxassetid://323494368" Sunset.SunAngularSize = 14 Sunset.SkyboxRt = "rbxassetid://323494067" Sunset.Parent = Lighting table.insert(tokyowamiEffects, Sunset)

            Lighting.Brightness = 2.14 Lighting.ColorShift_Bottom = Color3.fromRGB(11, 0, 20) Lighting.ColorShift_Top = Color3.fromRGB(240, 127, 14) Lighting.OutdoorAmbient = Color3.fromRGB(34, 0, 49) Lighting.ClockTime = 6.7 Lighting.FogColor = Color3.fromRGB(94, 76, 106) Lighting.FogEnd = 1000 Lighting.ExposureCompensation = 0.24 Lighting.ShadowSoftness = 0 Lighting.Ambient = Color3.fromRGB(59, 33, 27)
            showBottomMessage("Tokyowami: ON")
        else
            for _, v in ipairs(tokyowamiEffects) do pcall(function() v:Destroy() end) end table.clear(tokyowamiEffects)
            if Lighting:GetAttribute("OrigSaved") then
                Lighting.Brightness = Lighting:GetAttribute("OrigBright") Lighting.ColorShift_Bottom = Lighting:GetAttribute("OrigCSB") Lighting.ColorShift_Top = Lighting:GetAttribute("OrigCST") Lighting.OutdoorAmbient = Lighting:GetAttribute("OrigOA") Lighting.ClockTime = Lighting:GetAttribute("OrigTime") Lighting.FogColor = Lighting:GetAttribute("OrigFogC") Lighting.FogEnd = Lighting:GetAttribute("OrigFogE") Lighting.ExposureCompensation = Lighting:GetAttribute("OrigExp") Lighting.ShadowSoftness = Lighting:GetAttribute("OrigShadow") Lighting.Ambient = Lighting:GetAttribute("OrigAmbient")
            end
            showBottomMessage("Tokyowami: OFF")
        end
    end
})

-- ==========================================
-- 2. SHADERS NOCTURNOS (CUSTOM PBR)
-- ==========================================
UIElements.TogNight = Tabs.Graficos:Toggle({
    Title = "Modo Noche",
    Desc = "Modo noche ajustable.",
    Callback = function(Value)
        local Lighting = game:GetService("Lighting")
        local Terrain = workspace:FindFirstChildOfClass("Terrain")
        nightActivo = Value

        if Value then
            if not Lighting:GetAttribute("OrigSavedNight") then
                Lighting:SetAttribute("OrigBright", Lighting.Brightness) Lighting:SetAttribute("OrigCSB", Lighting.ColorShift_Bottom) Lighting:SetAttribute("OrigCST", Lighting.ColorShift_Top) Lighting:SetAttribute("OrigOA", Lighting.OutdoorAmbient) Lighting:SetAttribute("OrigTime", Lighting.ClockTime) Lighting:SetAttribute("OrigFogC", Lighting.FogColor) Lighting:SetAttribute("OrigFogE", Lighting.FogEnd) Lighting:SetAttribute("OrigExp", Lighting.ExposureCompensation) Lighting:SetAttribute("OrigShadow", Lighting.ShadowSoftness) Lighting:SetAttribute("OrigAmbient", Lighting.Ambient) Lighting:SetAttribute("OrigSpec", Lighting.EnvironmentSpecularScale) Lighting:SetAttribute("OrigDiff", Lighting.EnvironmentDiffuseScale) Lighting:SetAttribute("OrigGlobalS", Lighting.GlobalShadows) Lighting:SetAttribute("OrigGeo", Lighting.GeographicLatitude) Lighting:SetAttribute("OrigSavedNight", true)
            end

            ToggleNubesYAtmo(true, "Night")
            
            if Terrain and not Terrain:GetAttribute("OrigWaterSavedNight") then
                Terrain:SetAttribute("OrigWaveSize", Terrain.WaterWaveSize) Terrain:SetAttribute("OrigWaveSpeed", Terrain.WaterWaveSpeed) Terrain:SetAttribute("OrigReflectance", Terrain.WaterReflectance) Terrain:SetAttribute("OrigTransparency", Terrain.WaterTransparency) Terrain:SetAttribute("OrigWaterColor", Terrain.WaterColor) Terrain:SetAttribute("OrigWaterSavedNight", true)
            end

            for _, v in ipairs(nightEffects) do pcall(function() v:Destroy() end) end table.clear(nightEffects)

            local blur = Instance.new("BlurEffect") blur.Size = shaderAjustes.Desenfoque blur.Parent = Lighting table.insert(nightEffects, blur)
            local bloom = Instance.new("BloomEffect") bloom.Intensity = shaderAjustes.Neon bloom.Size = 40 bloom.Threshold = 0.2 bloom.Parent = Lighting table.insert(nightEffects, bloom)
            local cc = Instance.new("ColorCorrectionEffect") cc.Brightness = 0.02 cc.Contrast = 0.15 cc.Saturation = shaderAjustes.ColorSaturacion cc.TintColor = Color3.fromRGB(210, 225, 255) cc.Parent = Lighting table.insert(nightEffects, cc)
            local moonRays = Instance.new("SunRaysEffect") moonRays.Intensity = 0.15 moonRays.Spread = 0.75 moonRays.Parent = Lighting table.insert(nightEffects, moonRays)
            local Tropic = Instance.new("Sky") Tropic.Name = "iLunXTokyowamiNight" Tropic.SkyboxUp = "http://www.roblox.com/asset/?id=169210149" Tropic.SkyboxLf = "http://www.roblox.com/asset/?id=169210133" Tropic.SkyboxBk = "http://www.roblox.com/asset/?id=169210090" Tropic.SkyboxFt = "http://www.roblox.com/asset/?id=169210121" Tropic.SkyboxDn = "http://www.roblox.com/asset/?id=169210108" Tropic.SkyboxRt = "http://www.roblox.com/asset/?id=169210143" Tropic.StarCount = 5000 Tropic.MoonAngularSize = 18 Tropic.Parent = Lighting table.insert(nightEffects, Tropic)

            Lighting.ClockTime = 0 
            Lighting.Brightness = 4 Lighting.EnvironmentSpecularScale = 1 Lighting.EnvironmentDiffuseScale = 1 Lighting.GlobalShadows = true 
            Lighting.GeographicLatitude = shaderAjustes.LunaPos Lighting.ShadowSoftness = shaderAjustes.SuavidadSombras Lighting.ExposureCompensation = shaderAjustes.Exposicion Lighting.OutdoorAmbient = Color3.fromRGB(50, 65, 95) 
            local s = shaderAjustes.Sombras Lighting.Ambient = Color3.fromRGB(s, s + 3, s + 10) 
            Lighting.ColorShift_Bottom = Color3.fromRGB(25, 40, 60) Lighting.ColorShift_Top = Color3.fromRGB(160, 180, 240) Lighting.FogColor = Color3.fromRGB(15, 20, 30) Lighting.FogEnd = 2500

            if Terrain then Terrain.WaterWaveSize = 0.12 Terrain.WaterWaveSpeed = 8 Terrain.WaterReflectance = 1 Terrain.WaterTransparency = 0.85 Terrain.WaterColor = Color3.fromRGB(15, 25, 45) end
            showBottomMessage("Noche: ON (Cielo despejado)")
        else
            for _, v in ipairs(nightEffects) do pcall(function() v:Destroy() end) end table.clear(nightEffects)
            if Lighting:GetAttribute("OrigSavedNight") then
                Lighting.Brightness = Lighting:GetAttribute("OrigBright") Lighting.ColorShift_Bottom = Lighting:GetAttribute("OrigCSB") Lighting.ColorShift_Top = Lighting:GetAttribute("OrigCST") Lighting.OutdoorAmbient = Lighting:GetAttribute("OrigOA") Lighting.ClockTime = Lighting:GetAttribute("OrigTime") Lighting.FogColor = Lighting:GetAttribute("OrigFogC") Lighting.FogEnd = Lighting:GetAttribute("OrigFogE") Lighting.ExposureCompensation = Lighting:GetAttribute("OrigExp") Lighting.ShadowSoftness = Lighting:GetAttribute("OrigShadow") Lighting.Ambient = Lighting:GetAttribute("OrigAmbient") Lighting.GlobalShadows = Lighting:GetAttribute("OrigGlobalS")
                if Lighting:GetAttribute("OrigGeo") then Lighting.GeographicLatitude = Lighting:GetAttribute("OrigGeo") end
                if Lighting:GetAttribute("OrigSpec") then Lighting.EnvironmentSpecularScale = Lighting:GetAttribute("OrigSpec") Lighting.EnvironmentDiffuseScale = Lighting:GetAttribute("OrigDiff") end
            end
            ToggleNubesYAtmo(false, "Night")
            if Terrain and Terrain:GetAttribute("OrigWaterSavedNight") then
                Terrain.WaterWaveSize = Terrain:GetAttribute("OrigWaveSize") Terrain.WaterWaveSpeed = Terrain:GetAttribute("OrigWaveSpeed") Terrain.WaterReflectance = Terrain:GetAttribute("OrigReflectance") Terrain.WaterTransparency = Terrain:GetAttribute("OrigTransparency") Terrain.WaterColor = Terrain:GetAttribute("OrigWaterColor")
            end
            showBottomMessage("Noche: OFF")
        end
    end
})

-- ==========================================
-- 3. SHADER PINK HOUR 🌸 (MORADO AESTHETIC VIBE)
-- ==========================================
UIElements.TogPink = Tabs.Graficos:Toggle({
    Title = "Pink Hour",
    Desc = "Estilo Synthwave. Cielo y ambiente ajustable con los sliders.",
    Callback = function(Value)
        local Lighting = game:GetService("Lighting")
        pinkActivo = Value

        if Value then
            if not Lighting:GetAttribute("OrigSavedPink") then
                Lighting:SetAttribute("OrigBrightP", Lighting.Brightness) Lighting:SetAttribute("OrigCSBP", Lighting.ColorShift_Bottom) Lighting:SetAttribute("OrigCSTP", Lighting.ColorShift_Top) Lighting:SetAttribute("OrigOAP", Lighting.OutdoorAmbient) Lighting:SetAttribute("OrigTimeP", Lighting.ClockTime) Lighting:SetAttribute("OrigFogCP", Lighting.FogColor) Lighting:SetAttribute("OrigFogEP", Lighting.FogEnd) Lighting:SetAttribute("OrigAmbientP", Lighting.Ambient) Lighting:SetAttribute("OrigExpP", Lighting.ExposureCompensation) Lighting:SetAttribute("OrigShadowP", Lighting.ShadowSoftness) Lighting:SetAttribute("OrigSavedPink", true)
            end
            
            ToggleNubesYAtmo(true, "Pink")

            for _, v in ipairs(pinkEffects) do pcall(function() v:Destroy() end) end table.clear(pinkEffects)

            -- Creamos los efectos base (se colorean en UpdatePinkHourVibe)
            local cc = Instance.new("ColorCorrectionEffect")
            cc.Parent = Lighting
            table.insert(pinkEffects, cc)

            local bloom = Instance.new("BloomEffect") bloom.Size = 25 bloom.Threshold = 0.85 bloom.Parent = Lighting table.insert(pinkEffects, bloom)
            local blur = Instance.new("BlurEffect") blur.Size = 2 blur.Parent = Lighting table.insert(pinkEffects, blur)
            local sunRays = Instance.new("SunRaysEffect") sunRays.Intensity = 0.08 sunRays.Spread = 0.8 sunRays.Parent = Lighting table.insert(pinkEffects, sunRays)

            local sky = Instance.new("Sky") sky.Name = "AstraPinkSky" sky.SkyboxUp = "rbxassetid://323493360" sky.SkyboxLf = "rbxassetid://323494252" sky.SkyboxBk = "rbxassetid://323494035" sky.SkyboxFt = "rbxassetid://323494130" sky.SkyboxDn = "rbxassetid://323494368" sky.SkyboxRt = "rbxassetid://323494067" sky.SunAngularSize = 14 sky.StarCount = 3000 sky.Parent = Lighting table.insert(pinkEffects, sky)
            
            Lighting.Brightness = 2.0 
            Lighting.ClockTime = 6.7 
            Lighting.FogColor = Color3.fromRGB(120, 20, 150) 
            Lighting.FogEnd = 1200 
            Lighting.ShadowSoftness = 0.2 
            
            -- Llama a la función que colorea de inmediato
            UpdatePinkHourVibe()

            showBottomMessage("Pink Hour: ON")
        else
            for _, v in ipairs(pinkEffects) do pcall(function() v:Destroy() end) end table.clear(pinkEffects)
            if Lighting:GetAttribute("OrigSavedPink") then
                Lighting.Brightness = Lighting:GetAttribute("OrigBrightP") Lighting.ColorShift_Bottom = Lighting:GetAttribute("OrigCSBP") Lighting.ColorShift_Top = Lighting:GetAttribute("OrigCSTP") Lighting.OutdoorAmbient = Lighting:GetAttribute("OrigOAP") Lighting.ClockTime = Lighting:GetAttribute("OrigTimeP") Lighting.FogColor = Lighting:GetAttribute("OrigFogCP") Lighting.FogEnd = Lighting:GetAttribute("OrigFogEP") Lighting.Ambient = Lighting:GetAttribute("OrigAmbientP") Lighting.ExposureCompensation = Lighting:GetAttribute("OrigExpP") Lighting.ShadowSoftness = Lighting:GetAttribute("OrigShadowP")
            end
            ToggleNubesYAtmo(false, "Pink")
            showBottomMessage("Pink Hour: OFF")
        end
    end
})

-- ==========================================
-- 🎚️ SECCIÓN: AJUSTES MODO NOCHE PBR
-- ==========================================
Tabs.Graficos:Section({Title = "Ajustes: Modo Noche"})

Tabs.Graficos:Slider({
    Title = "Claridad del Mapa",
    Desc = "Afecta solo al Modo Noche. Úsalo si está muy oscuro.",
    Step = 0.05,
    Value = {Min = 0.0, Max = 1.0, Default = 0.28},
    Callback = function(v)
        shaderAjustes.Exposicion = v
        if nightActivo then game:GetService("Lighting").ExposureCompensation = v end
    end
})

Tabs.Graficos:Slider({
    Title = "Profundidad de Sombras",
    Desc = "0 = Oscuridad total. 50 = Sombra suave y clara.",
    Step = 5,
    Value = {Min = 0, Max = 50, Default = 5},
    Callback = function(v)
        shaderAjustes.Sombras = v
        if nightActivo then game:GetService("Lighting").Ambient = Color3.fromRGB(v, v + 3, v + 10) end
    end
})

Tabs.Graficos:Slider({
    Title = "Resplandor",
    Desc = "Ajusta qué tanto brillan las armas y las luces del mapa.",
    Step = 0.05,
    Value = {Min = 0.1, Max = 1.0, Default = 0.45},
    Callback = function(v)
        shaderAjustes.Neon = v
        if nightActivo then
            for _, effect in ipairs(nightEffects) do
                if effect:IsA("BloomEffect") then effect.Intensity = v end
            end
        end
    end
})

Tabs.Graficos:Slider({
    Title = "Fondo Borroso",
    Desc = "0 = Sin borrosidad. Añade un efecto de cámara cinematográfica.",
    Step = 0.5,
    Value = {Min = 0, Max = 10, Default = 2},
    Callback = function(v)
        shaderAjustes.Desenfoque = v
        if nightActivo then
            for _, effect in ipairs(nightEffects) do
                if effect:IsA("BlurEffect") then effect.Size = v end
            end
        end
    end
})

Tabs.Graficos:Slider({
    Title = "Posición de la Luna",
    Desc = "Mueve la luna en el cielo.",
    Step = 5,
    Value = {Min = 0, Max = 360, Default = 85},
    Callback = function(v)
        shaderAjustes.LunaPos = v
        if nightActivo then game:GetService("Lighting").GeographicLatitude = v end
    end
})

-- ==========================================
-- 🎚️ SECCIÓN: AJUSTES PINK HOUR (VAPORWAVE)
-- ==========================================
Tabs.Graficos:Section({Title = "Ajustes: Pink Hour"})

Tabs.Graficos:Slider({
    Title = "Intensidad del Morado",
    Desc = "Añade oscuridad y tonos violetas al cielo y al mapa.",
    Step = 0.05,
    Value = {Min = 0.0, Max = 1.0, Default = 0.7},
    Callback = function(v)
        shaderAjustes.PinkMorado = v
        UpdatePinkHourVibe()
    end
})

Tabs.Graficos:Slider({
    Title = "Intensidad del Rosa",
    Desc = "Agrega tonos magentas y rosas a las luces.",
    Step = 0.05,
    Value = {Min = 0.0, Max = 1.0, Default = 0.8},
    Callback = function(v)
        shaderAjustes.PinkRosa = v
        UpdatePinkHourVibe()
    end
})

Tabs.Graficos:Slider({
    Title = "Saturación de Color",
    Desc = "0 = Grisáceo y apagado. 1 = Colores fluorescentes.",
    Step = 0.05,
    Value = {Min = 0.0, Max = 1.0, Default = 0.4},
    Callback = function(v)
        shaderAjustes.PinkSaturacion = v
        UpdatePinkHourVibe()
    end
})

Tabs.Graficos:Slider({
    Title = "Resplandor",
    Desc = "Haz que el cielo y los neones brillen mas.",
    Step = 0.05,
    Value = {Min = 0.0, Max = 1.0, Default = 0.3},
    Callback = function(v)
        shaderAjustes.PinkNeon = v
        if pinkActivo then
            for _, effect in ipairs(pinkEffects) do
                if effect:IsA("BloomEffect") then effect.Intensity = v end
            end
        end
    end
})


Tabs.Farm:Section({Title = "Farmeo de Evento"})
getgenv().AutoEventFarm = false
local Networking = game:GetService("ReplicatedStorage"):WaitForChild("Packages"):WaitForChild("Networking")
local RemoteFarm = Networking:FindFirstChild("RE/Events/CollectEventSpawnable")

Tabs.Farm:Toggle({Title = "Auto Farmear Evento", Callback = function(s)
    getgenv().AutoEventFarm = s
    if s then 
        showBottomMessage("Auto Farm activado...")
        task.spawn(function()
            -- El contenedor y sus objetos se indexan por eventos. El bucle sólo
            -- compara posiciones; ya no crea GetChildren() diez veces por segundo.
            local cachedCoinContainer = nil
            local cachedCoinParts = {}
            local coinAddedConnection = nil
            local coinRemovedConnection = nil

            local function disconnectCoinCache()
                if coinAddedConnection then coinAddedConnection:Disconnect(); coinAddedConnection = nil end
                if coinRemovedConnection then coinRemovedConnection:Disconnect(); coinRemovedConnection = nil end
                table.clear(cachedCoinParts)
            end

            local function resolveCoinPart(item)
                if item:IsA("BasePart") then return item end
                if item:IsA("Model") and item.PrimaryPart then return item.PrimaryPart end
                return item:FindFirstChildWhichIsA("BasePart")
            end

            local function bindCoinContainer(container)
                disconnectCoinCache()
                cachedCoinContainer = container
                if not container then return end

                for _, item in ipairs(container:GetChildren()) do
                    cachedCoinParts[item] = resolveCoinPart(item) or false
                end

                coinAddedConnection = container.ChildAdded:Connect(function(item)
                    cachedCoinParts[item] = resolveCoinPart(item) or false
                end)
                coinRemovedConnection = container.ChildRemoved:Connect(function(item)
                    cachedCoinParts[item] = nil
                end)
            end

            while runtime.Alive and getgenv().AutoEventFarm do
                local char = player.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                
                if hrp then
                    -- Solo busca el contenedor si no lo tenemos, o si se destruyó (cambio de ronda/mapa)
                    if not cachedCoinContainer or not cachedCoinContainer.Parent then
                        local mapaNormal = workspace:FindFirstChild("Normal")
                        local newContainer = mapaNormal and mapaNormal:FindFirstChild("CoinContainer")
                        
                        if not newContainer then
                            -- Búsqueda profunda ultra pesada (pero ahora solo se hace 1 vez, no en cada frame)
                            newContainer = workspace:FindFirstChild("CoinContainer", true)
                        end

                        bindCoinContainer(newContainer)
                    end
                    
                    local masCercano = nil
                    local menorDistanciaSq = math.huge
                    
                    if cachedCoinContainer then
                        for item, cachedPart in pairs(cachedCoinParts) do
                            local part = cachedPart
                            if part == false or not part.Parent then
                                part = resolveCoinPart(item)
                                cachedCoinParts[item] = part or false
                            end

                            if part then
                                local delta = hrp.Position - part.Position
                                local distanciaSq = delta:Dot(delta)
                                if distanciaSq < menorDistanciaSq then
                                    menorDistanciaSq = distanciaSq
                                    masCercano = part
                                end
                            end
                        end
                    end
                    
                    if masCercano and menorDistanciaSq > 225 then
                        hrp.CFrame = masCercano.CFrame
                        task.wait(0.2) 
                    end
                
                    pcall(function() 
                        if not RemoteFarm then 
                            RemoteFarm = Networking:FindFirstChild("RE/Events/CollectEventSpawnable") 
                        end
                        if RemoteFarm then 
                            RemoteFarm:FireServer() 
                        end 
                    end)
                end
                
                task.wait(0.1) 
            end

            disconnectCoinCache()
        end)
    else 
        showBottomMessage("Auto Farm detenido.") 
    end
end})

-- ==========================================
-- COMPRADOR DE CAJAS (TIENDA) - CON DETECCIÓN DE ARMA
-- ==========================================
Tabs.Farm:Section({Title = "Comprador de Cajas (Con monedas)"})

local HttpService = game:GetService("HttpService")
local selectedBox = "Mythic Box #1"
local availableBoxes = {
    "Mythic Box #1", "Mythic Box #2", "Mythic Box #3", "Mythic Box #4",
    "Gun Box #1", "Gun Box #2",
    "Knife Box #1", "Knife Box #2"
}

Tabs.Farm:Dropdown({
    Title = "Selecciona la Caja",
    Values = availableBoxes,
    Value = "Mythic Box #1",
    Callback = function(Value)
        selectedBox = Value
    end
})

-- Función para leer la respuesta del servidor
function procesarCompra()
    local success, result = pcall(function()
        local args = { [1] = selectedBox }
        return game:GetService("ReplicatedStorage").Packages.Networking:FindFirstChild("RF/Shop/BuyCase"):InvokeServer(unpack(args))
    end)

    if success then
        -- Dependiendo de cómo esté programado el juego, el resultado puede ser una tabla o un texto.
        local premio = "Desconocido (Revisa tu inventario)"
        
        if type(result) == "table" then
            -- Convertimos la tabla a texto para poder leerla en consola
            premio = HttpService:JSONEncode(result)
            print("Caja abierta. Resultado:", premio)
            
            -- Intentamos adivinar si el arma viene en algún índice común
            if result.Item then premio = tostring(result.Item)
            elseif result.Weapon then premio = tostring(result.Weapon)
            elseif result.Name then premio = tostring(result.Name) 
            elseif result[1] then premio = tostring(result[1]) end
        elseif result ~= nil then
            premio = tostring(result)
            print("Caja abierta. Resultado:", premio)
        end
        
        showBottomMessage("" .. string.sub(premio, 1, 35))
    else
        showBottomMessage("Error al comprar o sin dinero.")
    end
end

Tabs.Farm:Button({
    Title = "Comprar 1 Caja",
    Callback = function()
        task.spawn(function()
            procesarCompra()
        end)
    end
})

local autoBuyBoxEnabled = false
Tabs.Farm:Toggle({
    Title = "Auto Comprar Caja (Loop)",
    Callback = function(Value)
        autoBuyBoxEnabled = Value
        if Value then
            showBottomMessage("Auto-compra iniciada...")
            task.spawn(function()
                while runtime.Alive and autoBuyBoxEnabled do
                    procesarCompra()
                    task.wait(1.5) -- Pausa obligatoria para evitar kick
                end
            end)
        else
            showBottomMessage("Auto-compra detenida.")
        end
    end
})

-- ==========================================
-- PESTAÑA ANIMACIONES (PAQUETES COMPLETOS Y MEZCLADOR)
-- ==========================================

-- 1. BASE DE DATOS LOCAL (Súper optimizada con tus nuevos packs)
local animationData = {
    ["Old School"] = { Walk = 10921244891, Run = 10921240218, Jump = 10921242013, Fall = 10921241244, SwimIdle = 10921244018, Swim = 10921243048, Idle = 10921230744, Idle2 = 10921232093, Climb = 10921229866 },
    ["Adidas Sports"] = { Walk = 18537392113, Run = 18537384940, Jump = 18537380791, Fall = 18537367238, SwimIdle = 18537387180, Swim = 18537389531, Idle = 18537376492, Idle2 = 18537371272, Climb = 18537363391 },
    ["Adidas Community"] = { Walk = 122150855457006, Run = 82598234841035, Jump = 75290611992385, Fall = 98600215928904, SwimIdle = 109346520324160, Swim = 133308483266208, Idle = 122257458498464, Idle2 = 102357151005774, Climb = 88763136693023 },
    ["Adidas Aura"] = { Walk = 83842218823011, Run = 118320322718866, Jump = 109996626521204, Fall = 95603166884636, SwimIdle = 94922130551805, Swim = 134530128383903, Idle = 110211186840347, Idle2 = 114191137265065, Climb = 97824616490448 },
    ["Wicked Popular"] = { Walk = 92072849924640, Run = 72301599441680, Jump = 104325245285198, Fall = 121152442762481, Idle = 118832222982049, Idle2 = 76049494037641, SwimIdle = 113199415118199, Swim = 99384245425157, Climb = 131326830509784 },
    ["Elder"] = { Walk = 10921111375, Run = 10921104374, Jump = 10921107367, Fall = 10921105765, SwimIdle = 10921110146, Swim = 10921108971, Idle = 10921101664, Idle2 = 10921102574, Climb = 10921100400 },
    ["Zombie"] = { Walk = 10921355261, Run = 616163682, Jump = 10921351278, Fall = 10921350320, SwimIdle = 10921353442, Swim = 10921352344, Idle = 10921344533, Idle2 = 10921345304, Climb = 10921343576 },
    ["Mage"] = { Walk = 10921152678, Run = 10921148209, Jump = 10921149743, Fall = 10921148939, SwimIdle = 10921151661, Swim = 10921150788, Idle = 10921144709, Idle2 = 10921145797, Climb = 10921143404 },
    ["Catwalk Glam"] = { Walk = 109168724482748, Run = 81024476153754, Jump = 116936326516985, Fall = 92294537340807, SwimIdle = 98854111361360, Swim = 134591743181628, Idle = 133806214992291, Idle2 = 94970088341563, Climb = 119377220967554 },
    ["Astronaut"] = { Walk = 10921046031, Run = 10921039308, Jump = 10921042494, Fall = 10921040576, SwimIdle = 10921045006, Swim = 10921044000, Idle = 10921034824, Idle2 = 10921036806, Climb = 10921032124 },
    ['Wicked "Dancing Through Life"'] = { Walk = 73718308412641, Run = 135515454877967, Jump = 78508480717326, Fall = 78147885297412, SwimIdle = 129183123083281, Swim = 110657013921774, Idle = 92849173543269, Idle2 = 132238900951109, Climb = 129447497744818 },
    ["Werewolf"] = { Walk = 10921342074, Run = 10921336997, Fall = 10921337907, SwimIdle = 10921341319, Swim = 10921340419, Idle = 10921330408, Idle2 = 10921333667, Climb = 10921329322 },
    ["Superhero"] = { Walk = 10921298616, Run = 10921291831, Jump = 10921294559, Fall = 10921293373, SwimIdle = 10921297391, Swim = 10921295495, Idle = 10921288909, Idle2 = 10921290167, Climb = 10921286911 },
    ["Toy"] = { Walk = 10921312010, Run = 10921306285, Jump = 10921308158, Fall = 10921307241, SwimIdle = 10921310341, Swim = 10921309319, Idle = 10921301576, Climb = 10921300839 },
    ["No Boundaries"] = { Walk = 18747074203, Run = 18747070484, Jump = 18747069148, Fall = 18747062535, SwimIdle = 18747071682, Swim = 18747073181, Idle = 18747067405, Idle2 = 18747063918, Climb = 18747060903 },
    ["NFL"] = { Walk = 110358958299415, Run = 117333533048078, Jump = 119846112151352, Fall = 129773241321032, SwimIdle = 79090109939093, Swim = 132697394189921, Idle = 92080889861410, Idle2 = 74451233229259, Climb = 134630013742019 },
    ["Amazon Unboxed"] = { Walk = 90478085024465, Run = 134824450619865, Jump = 121454505477205, Fall = 94788218468396, SwimIdle = 129126268464847, Swim = 105962919001086, Idle = 98281136301627, Climb = 121145883950231 },
    ["Vampire"] = { Walk = 10921326949, Run = 10921320299, Jump = 10921322186, Fall = 10921321317, SwimIdle = 10921325443, Swim = 10921324408, Idle = 10921315373, Climb = 10921314188 },
    ["Ninja"] = { Walk = 656121766, Run = 656118852, Jump = 656117878, Fall = 656115606, SwimIdle = 656121397, Swim = 656119721, Idle = 656117400, Idle2 = 656118341, Climb = 656114359 },
    ["Robot"] = { Walk = 616095330, Run = 616091570, Jump = 616090535, Fall = 616087089, SwimIdle = 616094091, Swim = 616092998, Idle = 616088211, Idle2 = 616089559, Climb = 616086039 },
    ["Levitation"] = { Walk = 616013216, Run = 616010382, Jump = 616008936, Fall = 616005863, SwimIdle = 616012453, Swim = 616011509, Idle = 616006778, Idle2 = 616008087, Climb = 616003713 },
    ["Stylish"] = { Walk = 616146177, Run = 616140816, Jump = 616139451, Fall = 616134815, SwimIdle = 616144772, Swim = 616143378, Idle = 616136790, Idle2 = 616138447, Climb = 616133594 },
    ["Bubbly"] = { Walk = 910034870, Run = 910025107, Jump = 910016857, Fall = 910001910, SwimIdle = 910030921, Swim = 910028158, Idle = 910004836, Idle2 = 910009958, Climb = 909997997 },
    ["Cartoon"] = { Walk = 742640026, Run = 742638842, Jump = 742637942, Fall = 742637151, SwimIdle = 742639812, Swim = 742639220, Idle = 742637544, Idle2 = 742638445, Climb = 742636889 }
}

-- 2. LIMPIEZA DE ANIMACIONES PREVIAS
function clearAllAnimations()
    local char = player.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end

    local animator = hum:FindFirstChildOfClass("Animator")
    local tracks = animator and animator:GetPlayingAnimationTracks() or hum:GetPlayingAnimationTracks()
    for _, track in pairs(tracks) do track:Stop(0) track:Destroy() end
    task.wait(0.1)
end

local animacionActualActiva = nil 
local misAnimacionesOriginales = nil 
local animationGuardConnection = nil
local applyingCustomAnimations = false

-- 3. MOTOR UNIVERSAL DE INYECCIÓN
function applyCustomAnims(customData)
    if not customData then return end
    local char = player.Character
    if not char then return end

    local animate = char:FindFirstChild("Animate")
    if not animate then return end

    applyingCustomAnimations = true
    clearAllAnimations()
    
    if not misAnimacionesOriginales then
        local function getAnim(folderName, animName)
            local folder = animate:FindFirstChild(folderName)
            if folder then
                local anim = folder:FindFirstChild(animName)
                if anim and anim:IsA("Animation") then
                    local idStr = anim.AnimationId:match("%d+")
                    if idStr then return tonumber(idStr) end
                end
            end
            return nil
        end

        misAnimacionesOriginales = {
            Idle = getAnim("idle", "Animation1") or 507766666,
            Idle2 = getAnim("idle", "Animation2") or 507766951,
            Walk = getAnim("walk", "WalkAnim") or 507777826,
            Run = getAnim("run", "RunAnim") or 507767714,
            Jump = getAnim("jump", "JumpAnim") or 507765000,
            Climb = getAnim("climb", "ClimbAnim") or 507765644,
            Fall = getAnim("fall", "FallAnim") or 507767968,
            Swim = getAnim("swim", "Swim") or 507784897,
            SwimIdle = getAnim("swimidle", "SwimIdle") or 507785072
        }
    end

    animate.Disabled = true
    task.wait(0.1)

    local function updateAnimation(folderName, animName, animId)
        if not animId then return end
        local folder = animate:FindFirstChild(folderName)
        if folder then
            local anim = folder:FindFirstChild(animName)
            if anim and anim:IsA("Animation") then
                anim.AnimationId = "rbxassetid://" .. tostring(animId)
            end
        end
    end

    updateAnimation("idle", "Animation1", customData.Idle)
    updateAnimation("idle", "Animation2", customData.Idle2 or customData.Idle)
    updateAnimation("walk", "WalkAnim", customData.Walk)
    updateAnimation("run", "RunAnim", customData.Run)
    updateAnimation("jump", "JumpAnim", customData.Jump)
    updateAnimation("climb", "ClimbAnim", customData.Climb)
    updateAnimation("fall", "FallAnim", customData.Fall)
    updateAnimation("swim", "Swim", customData.Swim)
    updateAnimation("swimidle", "SwimIdle", customData.SwimIdle or customData.Swim)

    task.wait(0.1)
    animate.Disabled = false

    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then
        hum:ChangeState(Enum.HumanoidStateType.Landed)
        task.wait(0.05)
        hum:ChangeState(Enum.HumanoidStateType.Running)
    end

    applyingCustomAnimations = false
    if bindAnimationGuard then bindAnimationGuard() end
end

-- ==========================================
-- GUARDIA DE ANIMACIONES POR EVENTOS (SIN POLLING)
-- ==========================================
function bindAnimationGuard()
    if animationGuardConnection then
        animationGuardConnection:Disconnect()
        animationGuardConnection = nil
    end

    if not animacionActualActiva then return end
    local char = player.Character
    local animate = char and char:FindFirstChild("Animate")
    local idleFolder = animate and animate:FindFirstChild("idle")
    local anim1 = idleFolder and idleFolder:FindFirstChild("Animation1")
    if not anim1 then return end

    animationGuardConnection = runtime.Track(anim1:GetPropertyChangedSignal("AnimationId"):Connect(function()
        if applyingCustomAnimations or not animacionActualActiva then return end
        local currentId = anim1.AnimationId:match("%d+")
        if currentId ~= tostring(animacionActualActiva.Idle) then
            task.defer(function()
                if runtime.Alive and animacionActualActiva then
                    applyCustomAnims(animacionActualActiva)
                end
            end)
        end
    end))
end

runtime.Track(player.CharacterAdded:Connect(function(char)
    if not animacionActualActiva then return end
    task.defer(function()
        local animate = char:WaitForChild("Animate", 5)
        if runtime.Alive and animate and animacionActualActiva then
            applyCustomAnims(animacionActualActiva)
        end
    end)
end))


-- 4. RECONSTRUCCIÓN DE LA UI EN WINDUI
local animList = {"Ninguno"}
for name, _ in pairs(animationData) do table.insert(animList, name) end
table.sort(animList)

Tabs.Emotes:Section({Title = "Paquetes Completos"})

local selectedBundleCompleto = "Ninguno"
Tabs.Emotes:Dropdown({
    Title = "Elegir Paquete", 
    Values = animList, 
    Value = "Ninguno", 
    Callback = function(Value) selectedBundleCompleto = Value end
})

Tabs.Emotes:Button({Title = "Aplicar Paquete Completo", Callback = function()
    if selectedBundleCompleto == "Ninguno" then return end
    task.spawn(function()
        showBottomMessage("Aplicando paquete: " .. selectedBundleCompleto)
        animacionActualActiva = animationData[selectedBundleCompleto]
        applyCustomAnims(animacionActualActiva)
    end)
end})

Tabs.Emotes:Button({Title = "Restaurar Default", Callback = function()
    task.spawn(function()
        local defaultAnims = misAnimacionesOriginales or {
            Idle = 507766666, Idle2 = 507766951, Walk = 507777826, Run = 507767714,
            Jump = 507765000, Climb = 507765644, Fall = 507767968, Swim = 507784897, SwimIdle = 507785072
        }
        animacionActualActiva = nil 
        applyCustomAnims(defaultAnims)
        showBottomMessage("Animaciones de tu avatar restauradas.")
    end)
end})

-- 5. MEZCLADOR DE ANIMACIONES
Tabs.Emotes:Section({Title = "Mezclador de Animaciones"})

local mixParts = {
    Idle = "Ninguno", Walk = "Ninguno", Run = "Ninguno", 
    Jump = "Ninguno", Fall = "Ninguno", Climb = "Ninguno"
}

Tabs.Emotes:Dropdown({Title = "Reposo", Values = animList, Value = "Ninguno", Callback = function(Value) mixParts.Idle = Value end})
Tabs.Emotes:Dropdown({Title = "Caminar", Values = animList, Value = "Ninguno", Callback = function(Value) mixParts.Walk = Value end})
Tabs.Emotes:Dropdown({Title = "Correr", Values = animList, Value = "Ninguno", Callback = function(Value) mixParts.Run = Value end})
Tabs.Emotes:Dropdown({Title = "Saltar", Values = animList, Value = "Ninguno", Callback = function(Value) mixParts.Jump = Value end})
Tabs.Emotes:Dropdown({Title = "Caer", Values = animList, Value = "Ninguno", Callback = function(Value) mixParts.Fall = Value end})
Tabs.Emotes:Dropdown({Title = "Escalar", Values = animList, Value = "Ninguno", Callback = function(Value) mixParts.Climb = Value end})

Tabs.Emotes:Button({Title = "Combinar y Aplicar", Callback = function()
    task.spawn(function()
        local customMix = {}
        
        if mixParts.Idle ~= "Ninguno" then
            customMix.Idle = animationData[mixParts.Idle].Idle
            customMix.Idle2 = animationData[mixParts.Idle].Idle2
        end
        if mixParts.Walk ~= "Ninguno" then customMix.Walk = animationData[mixParts.Walk].Walk end
        if mixParts.Run ~= "Ninguno" then customMix.Run = animationData[mixParts.Run].Run end
        if mixParts.Jump ~= "Ninguno" then customMix.Jump = animationData[mixParts.Jump].Jump end
        if mixParts.Fall ~= "Ninguno" then customMix.Fall = animationData[mixParts.Fall].Fall end
        if mixParts.Climb ~= "Ninguno" then customMix.Climb = animationData[mixParts.Climb].Climb end

        local hasValues = false
        for _, v in pairs(customMix) do if v then hasValues = true break end end
        
        if hasValues then
            showBottomMessage("Aplicando combinación de animaciones...")
            animacionActualActiva = customMix 
            applyCustomAnims(animacionActualActiva)
        else
            showBottomMessage("Selecciona al menos una animación para combinar.")
        end
    end)
end})

-- ==========================================
-- NUEVA SECCIÓN: INVENTARIO & ARMAS (0 LAG)
-- ==========================================
local SpoofSection = Window:Section({ Title = "INVENTARIO", Opened = true })
local TabSpoof = SpoofSection:Tab({Title = "Generar Armas", Icon = "solar:box-bold"})

TabSpoof:Paragraph({
    Title = "Aviso",
    Desc = "De momento solo genera armas en el inventario (visuales)."
})

local DB_Weapons = {}
local DB_Rarities = {}
local knownRarities = {"Common", "Uncommon", "Rare", "Legendary", "Mythic", "Ancient"}

local RarityBorders = {
    ["Common"]    = "rbxassetid://132453594022404",
    ["Uncommon"]  = "rbxassetid://131106754160848",
    ["Rare"]      = "rbxassetid://131023770160505",
    ["Legendary"] = "rbxassetid://74335220949230",
    ["Mythic"]    = "rbxassetid://91151835037566",
    ["Ancient"]   = "rbxassetid://72705038235103"
}

-- Reemplaza tu tabla RarityWeights actual por esta:
local RarityWeights = {
    ["Ancient"]   = -600,
    ["Mythic"]    = -500,
    ["Legendary"] = -400,
    ["Rare"]      = -300,
    ["Uncommon"]  = -200,
    ["Common"]    = -100
}

local currentSpoofFilter = "Todos"
local currentSpoofSearch = ""
local currentQuantity = 1
local SelectedSpoofWeapon = nil
local DropWeaponsSpoof = nil

local function normalizeString(str)
    if not str then return "" end
    return string.lower(string.gsub(tostring(str), "[%s%p]", ""))
end

-- Escáner optimizado (Se ejecuta solo 1 vez en segundo plano)
local function BuildSpoofDatabase()
    table.clear(DB_Weapons)
    table.clear(DB_Rarities)
    
    task.spawn(function()
        local scannedModules = 0
        for _, module in ipairs(ReplicatedStorage:GetDescendants()) do
            if module:IsA("ModuleScript") then
                local success, data = pcall(require, module)
                local function scanTable(t, depth)
                    if depth > 4 then return end
                    for k, v in pairs(t) do
                        if type(v) == "table" then
                            if (v.ItemName or v.Rarity or v.Image) and type(k) == "string" then
                                if not DB_Weapons[k] then DB_Weapons[k] = v end
                            end
                            if type(k) == "string" and table.find(knownRarities, k) then
                                if not DB_Rarities[k] then DB_Rarities[k] = {} end
                                if typeof(v.Color) == "Color3" then DB_Rarities[k].Color = v.Color end
                            end
                            scanTable(v, depth + 1)
                        end
                    end
                end
                if success and type(data) == "table" then scanTable(data, 1) end

                scannedModules = scannedModules + 1
                if scannedModules % 25 == 0 then task.wait() end
            end
        end
        showBottomMessage("Base de datos de armas cargada con éxito.")
    end)
end

-- Motor de ordenamiento BLINDADO
local function OrdenarInventario(sList)
    task.spawn(function()
        task.wait(0.05) -- Le damos un microsegundo de ventaja al juego para sobreescribir su orden
        
        local layout = sList:FindFirstChildWhichIsA("UIGridLayout") or sList:FindFirstChildWhichIsA("UIListLayout")
        if layout then 
            layout.SortOrder = Enum.SortOrder.LayoutOrder 
        end
        
        for _, slot in pairs(sList:GetChildren()) do
            if slot:IsA("ImageButton") and slot.Name ~= "BuyCrates" then
                -- 🔥 FIX: Usamos nuestro atributo blindado para buscar su rareza real
                local wName = slot:GetAttribute("SpoofedName") or slot.Name
                local wData = DB_Weapons[wName]
                local rarity = "Common"
                
                if type(wData) == "table" then
                    rarity = tostring(wData.Rarity or wData.Tier or "Common")
                end
                
                slot.LayoutOrder = RarityWeights[rarity] or 7
            end
        end
    end)
end

local currentPageSpoof = 1
local itemsPerPage = 30 -- 30 es un número perfecto para que cargue al instante
local function GetFilteredSpoofItems()
    local list = {}
    local searchNeedle = currentSpoofSearch ~= "" and string_lower(currentSpoofSearch) or nil
    for name, data in pairs(DB_Weapons) do
        local typeMatch = false
        local iType = (type(data) == "table" and data.ItemType) or "Knife"
        
        if currentSpoofFilter == "Todos" then typeMatch = true
        elseif currentSpoofFilter == "Cuchillos" and iType == "Knife" then typeMatch = true
        elseif currentSpoofFilter == "Pistolas" and iType == "Gun" then typeMatch = true
        elseif currentSpoofFilter == "Efectos" and iType == "Effect" then typeMatch = true end

        local sMatch = not searchNeedle
            or string_find(string_lower(name), searchNeedle) ~= nil
            or string_find(string_lower((type(data) == "table" and data.ItemName) or ""), searchNeedle) ~= nil
        
        if typeMatch and sMatch then table.insert(list, name) end
    end
    
    table.sort(list)
    
    -- 🔥 LÓGICA DE PAGINACIÓN 🔥
    local totalItems = #list
    local totalPages = math.ceil(totalItems / itemsPerPage)
    if totalPages == 0 then totalPages = 1 end
    if currentPageSpoof > totalPages then currentPageSpoof = totalPages end
    
    local startIndex = ((currentPageSpoof - 1) * itemsPerPage) + 1
    local endIndex = math.min(startIndex + itemsPerPage - 1, totalItems)
    
    local pagedList = {}
    
    -- Si no estamos en la primera página, agregamos el botón de regresar
    if currentPageSpoof > 1 then
        table.insert(pagedList, "Página Anterior")
    end
    
    -- Agregamos las armas de la página actual
    for i = startIndex, endIndex do
        table.insert(pagedList, list[i])
    end
    
    -- Si hay más páginas adelante, agregamos el botón de avanzar
    if currentPageSpoof < totalPages then
        table.insert(pagedList, "Página Siguiente")
    end
    
    if #pagedList == 0 then 
        table.insert(pagedList, "No se encontraron items") 
    end
    
    return pagedList
end

task.delay(1.25, BuildSpoofDatabase)

TabSpoof:Dropdown({ 
    Title = "Filtrar por Tipo", 
    Values = {"Todos", "Cuchillos", "Pistolas", "Efectos"}, 
    Value = "Todos", 
    Callback = function(V) 
        currentSpoofFilter = V
        currentPageSpoof = 1 -- Resetea la página al filtrar
        if DropWeaponsSpoof then DropWeaponsSpoof:Refresh(GetFilteredSpoofItems()) end 
    end
})

TabSpoof:Input({ 
    Title = "Buscar Item...", 
    Callback = function(T) 
        currentSpoofSearch = T
        currentPageSpoof = 1 -- Resetea la página al buscar
        if DropWeaponsSpoof then DropWeaponsSpoof:Refresh(GetFilteredSpoofItems()) end 
    end
})

DropWeaponsSpoof = TabSpoof:Dropdown({ 
    Title = "Selecciona un Item", 
    Values = GetFilteredSpoofItems(), 
    Value = "Cargando...", 
    Callback = function(V) 
        -- 🔥 INTERCEPTAMOS LOS CLICS DE PAGINACIÓN 🔥
        if V == "Página Anterior" then
            currentPageSpoof = currentPageSpoof - 1
            DropWeaponsSpoof:Refresh(GetFilteredSpoofItems())
            
        elseif V == "Página Siguiente" then
            currentPageSpoof = currentPageSpoof + 1
            DropWeaponsSpoof:Refresh(GetFilteredSpoofItems())
            
        elseif V ~= "No se encontraron items" then 
            -- Si no es un botón de página, entonces sí guardamos el arma seleccionada
            SelectedSpoofWeapon = V 
        end 
    end
})

TabSpoof:Section({ Title = "Control del Inventario" })

TabSpoof:Input({ 
    Title = "Cantidad a Generar", 
    Placeholder = "Ej: 1, 10, 99+", 
    Callback = function(T) 
        local n = tonumber(T)
        currentQuantity = (n and n > 0) and n or 1 
    end
})

TabSpoof:Button({ 
    Title = "Agregar al Inventario", 
    Callback = function()
        if not SelectedSpoofWeapon or SelectedSpoofWeapon == "No se encontraron items" then return end
        local pGui = player:FindFirstChild("PlayerGui")
        if not pGui then return end
        
        local inventoryFrame = pGui:FindFirstChild("NewGui") and pGui.NewGui:FindFirstChild("Inventory")
        local sList = inventoryFrame and inventoryFrame:FindFirstChild("ScrollList")
        if not sList then return end

        local wNode = DB_Weapons[SelectedSpoofWeapon]
        if type(wNode) ~= "table" then return end

        -- 🔥 FIX ANTIDUPLICADOS: Buscamos por atributo secreto, no por nombre
        local existingSlot = nil
        for _, child in ipairs(sList:GetChildren()) do
            if child:GetAttribute("IsSpoofed") and child:GetAttribute("SpoofedName") == SelectedSpoofWeapon then
                existingSlot = child
                break
            end
        end

        if existingSlot then
            local cAmt = existingSlot:GetAttribute("SpoofedAmount") or 1
            local nAmt = cAmt + currentQuantity
            existingSlot:SetAttribute("SpoofedAmount", nAmt)
            
            -- Actualizamos el texto del multiplicador dinámicamente
            for _, c in pairs(existingSlot:GetChildren()) do
                if c:IsA("TextLabel") and c.Name ~= "Favorite" then
                    local t = string.lower(c.Text)
                    if string.find(t, "x") or tonumber(string.match(t, "%d+")) then 
                        c.Text = (nAmt > 99) and "99x" or tostring(nAmt) .. "x"
                    end
                end
            end
            
            OrdenarInventario(sList)
            showBottomMessage("Cantidad sumada: " .. SelectedSpoofWeapon .. " (" .. nAmt .. "x)")
            return 
        end

        local baseSlot = nil
        for _, c in pairs(sList:GetChildren()) do 
            if c:IsA("ImageButton") and c.Name ~= "BuyCrates" then 
                baseSlot = c
                break 
            end 
        end

        if baseSlot then
            local fSlot = baseSlot:Clone()
            fSlot.Name = SelectedSpoofWeapon
            
            -- 🔥 ATRIBUTOS BLINDADOS 🔥
            fSlot:SetAttribute("SpoofedName", SelectedSpoofWeapon) 
            fSlot:SetAttribute("IsSpoofed", true)
            fSlot:SetAttribute("SpoofedAmount", currentQuantity)
            
            local sType = wNode.ItemType or "Knife"
            fSlot:SetAttribute("WeaponType", sType)
            fSlot.Parent = sList
            
            local tRarity = tostring(wNode.Rarity or wNode.Tier or "Common")
            if RarityBorders[tRarity] then fSlot.Image = RarityBorders[tRarity] end
            
            local wIcon = fSlot:FindFirstChildWhichIsA("ImageLabel")
            if wIcon then wIcon.Image = wNode.Image or wNode.Icon or "rbxassetid://107969586413592" end
            
            local weaponNameStr = SelectedSpoofWeapon
            local weaponColor = Color3.fromRGB(255, 255, 255)
            
            for _, c in pairs(fSlot:GetChildren()) do
                if c:IsA("TextLabel") then
                    local t = string.lower(c.Text)
                    if c.Text == "❤️" then 
                        c.Visible = false
                    elseif string.find(t, "x") or tonumber(string.match(t, "%d+")) then 
                        c.Text = (currentQuantity > 99) and "99x" or tostring(currentQuantity) .. "x"
                    else
                        c.Text = wNode.ItemName or SelectedSpoofWeapon
                        weaponNameStr = c.Text
                        if DB_Rarities[tRarity] and DB_Rarities[tRarity].Color then 
                            c.TextColor3 = DB_Rarities[tRarity].Color 
                            weaponColor = c.TextColor3
                        end
                    end
                end
            end
            
            fSlot.MouseButton1Click:Connect(function()
                local equipFrame = inventoryFrame.SelectedSkins.Frame
                local equipSlots = {}
                
                for _, v in ipairs(equipFrame:GetChildren()) do
                    if v:IsA("ImageButton") then table.insert(equipSlots, v) end
                end
                
                local targetSlotIndex = 1
                if sType == "Gun" then targetSlotIndex = 2
                elseif sType == "Effect" then targetSlotIndex = 3 end
                
                local targetSlot = equipSlots[targetSlotIndex]
                if targetSlot then
                    targetSlot.Image = fSlot.Image 
                    local img = targetSlot:FindFirstChildWhichIsA("ImageLabel")
                    if img and wIcon then img.Image = wIcon.Image end 
                    
                    local txt = targetSlot:FindFirstChildWhichIsA("TextLabel")
                    if txt then
                        txt.Text = weaponNameStr
                        txt.TextColor3 = weaponColor
                    end
                end
            end)

            if _G.CurrentSpoofTab == sType then
                fSlot.Visible = true
            else
                fSlot.Visible = false
            end
            
            OrdenarInventario(sList) 
            showBottomMessage("Generado: " .. SelectedSpoofWeapon)
        else
            showBottomMessage("Error: Necesitas tener al menos 1 arma real en tu inventario.")
        end
    end
})

TabSpoof:Button({ 
    Title = "Eliminar Arma Seleccionada", 
    Callback = function()
        if not SelectedSpoofWeapon or SelectedSpoofWeapon == "No se encontraron items" then return end
        local pGui = player:FindFirstChild("PlayerGui")
        if not pGui then return end
        
        local sList = pGui:FindFirstChild("NewGui") and pGui.NewGui:FindFirstChild("Inventory") and pGui.NewGui.Inventory:FindFirstChild("ScrollList")
        if not sList then return end
        
        local slotToDel = sList:FindFirstChild(SelectedSpoofWeapon)
        if slotToDel and slotToDel:GetAttribute("IsSpoofed") then
            slotToDel:Destroy()
            showBottomMessage("Eliminado: " .. SelectedSpoofWeapon)
        else
            showBottomMessage("El arma no es Spoof o no está en el inventario.")
        end
    end
})

TabSpoof:Button({ 
    Title = "Limpiar Todo lo Generado", 
    Callback = function()
        local pGui = player:FindFirstChild("PlayerGui")
        if not pGui then return end
        
        local sList = pGui:FindFirstChild("NewGui") and pGui.NewGui:FindFirstChild("Inventory") and pGui.NewGui.Inventory:FindFirstChild("ScrollList")
        if not sList then return end
        
        local count = 0
        for _, obj in pairs(sList:GetChildren()) do
            if obj:GetAttribute("IsSpoofed") then
                obj:Destroy()
                count = count + 1
            end
        end
        showBottomMessage("Limpieza completa: " .. count .. " armas eliminadas.")
    end
})

-- 👇 AQUÍ MERITO PEGAS EL BLOQUE SUELTO 👇
_G.CurrentSpoofTab = "Knife" -- Pestaña por defecto cuando abres el inventario

task.spawn(function()
    local pGui = player:WaitForChild("PlayerGui", 10)
    if not pGui then return end
    
    local inventory = pGui:WaitForChild("NewGui", 10) and pGui.NewGui:WaitForChild("Inventory", 10)
    local tabsFrame = inventory and inventory:WaitForChild("Tabs", 10)
    
    if tabsFrame then
        for _, tabBtn in ipairs(tabsFrame:GetChildren()) do
            if tabBtn:IsA("ImageButton") then
                tabBtn.MouseButton1Click:Connect(function()
                    _G.CurrentSpoofTab = tabBtn.Name -- Actualizamos la memoria
                    
                    task.wait() 
                    local sList = inventory:FindFirstChild("ScrollList")
                    if sList then
                        for _, slot in pairs(sList:GetChildren()) do
                            if slot:GetAttribute("IsSpoofed") then
                                if tabBtn.Name == slot:GetAttribute("WeaponType") then
                                    slot.Visible = true
                                else
                                    slot.Visible = false
                                end
                            end
                        end
                    end
                end)
            end
        end
    end
end)

Tabs.Config:Section({ Title = "Personalización de Interfaz" })

Tabs.Config:Paragraph({
    Title = "Xero / Obsidian",
    Desc = "Negro, blanco y una interfaz hecha para XeroHub. Creado por Kev.",
})

Tabs.Config:Toggle({
    Title = "Ocultar Botón Flotante",
    Desc = "Lo deja invisible pero sigue en su sitio y sigue siendo tocable para reabrir el hub.",
    Callback = function(value)
        Window:SetOpenButtonGhosted(value)
    end,
})

Tabs.Config:Toggle({
    Title = "Botones Flotantes Invisibles",
    Desc = "Oculta la posicion de los botones.",
    Value = false,
    Callback = function(Value)
        _G.AstraBotonesOcultos = Value 
        for _, btn in ipairs(floatingButtonsList) do
            if btn then btn:SetAttribute("Ghosted", Value) end
        end
    end
})

-- ==========================================
-- PESTAÑA FINAL: CONFIGURACIÓN (SISTEMA ILIMITADO)
-- ==========================================
Tabs.Config:Section({ Title = "Gestor de Configs" })
local configFolder = "iLunXHub_Configs_Duels_WindUI"
local legacyConfigFolder = "OnyxHub_Configs_Duels_WindUI"
if isfolder and not isfolder(configFolder) then pcall(function() makefolder(configFolder) end) end

local availableConfigs = {"Ninguna"}
local selectedConfig = "Ninguna"
local customConfigName = ""
local configPaths = {}

local configDropdown = Tabs.Config:Dropdown({
    Title = "Seleccionar Configuración",
    Values = availableConfigs,
    Value = "Ninguna",
    Callback = function(Value)
        selectedConfig = Value
    end
})

function refreshConfigs()
    local list = {}
    local seen = {}
    configPaths = {}
    if listfiles then
        pcall(function()
            -- El folder anterior también se lee para no perder configuraciones guardadas.
            for _, folder in ipairs({configFolder, legacyConfigFolder}) do
                if not isfolder or isfolder(folder) then
                    for _, file in ipairs(listfiles(folder)) do
                        if file:match("%.json$") then
                            local name = file:match("([^/\\]+)%.json$")
                            if name and not seen[name] then
                                seen[name] = true
                                configPaths[name] = file
                                table.insert(list, name)
                            end
                        end
                    end
                end
            end
        end)
    end
    if #list == 0 then table.insert(list, "Ninguna") end
    
    pcall(function()
        configDropdown:Refresh(list)
        if selectedConfig == "Ninguna" or not table.find(list, selectedConfig) then
            configDropdown:Select(list[1])
            selectedConfig = list[1]
        end
    end)
end

Tabs.Config:Button({
    Title = "Actualizar Lista",
    Callback = function()
        refreshConfigs()
        showBottomMessage("Lista de configuraciones actualizada.")
    end
})

Tabs.Config:Input({ 
    Title = "Nombre para Guardar ", 
    Placeholder = "Ej: Config 1, Config 2...", 
    Callback = function(Text) 
        customConfigName = Text 
    end 
})
Tabs.Config:Button({ Title = "Guardar Configuración", Callback = function()
    task.wait(0.1) 
    
    -- Si el usuario escribió un nombre, usamos ese. Si no, sobreescribimos el seleccionado en el dropdown.
    local finalName = customConfigName:gsub("[^%w%s%-]", "") 
    if finalName == "" then finalName = selectedConfig end
    
    if finalName == "" or finalName == "Ninguna" then
        showBottomMessage(" Escribe un nombre válido o selecciona una config para sobreescribir.")
        return
    end
    
    local path = configFolder .. "/" .. finalName .. ".json"
    
    local configData = {
        ConfigName = finalName, 
        Toggles = {
            ["Auto Shoot"] = autoShootEnabled,
            ["AutoShoot Cuchillo"] = autoShootCuchilloEnabled,
            ["Transparencia Hitbox"] = hitboxTransparency,
            ["Silent Aim (Pistola)"] = silentAimPistolaEnabled,
            ["Silent Aim (Cuchillo)"] = silentAimCuchilloEnabled,
            ["Silent Aim (FOV)"] = silentAimFovEnabled,
            ["Mostrar Círculo FOV"] = fovVisiblePreference,
            ["ESP Lineas"] = espLinesEnabled,
            ["ESP Box 2D"] = espSettings.Box,
            ["ESP Barra Vida"] = espSettings.HealthBar,
            ["Btn Flotante AutoShoot"] = asBtn.Visible,
            ["Btn Flotante SilentAim"] = saBtn.Visible,
            ["Btn Flotante Fantasma"] = ghostBtn.Visible,
            ["Aumentar Hitbox"] = hitboxEnabled, 
            ["Hitbox Invisible"] = hitboxInvisible, 
            ["ESP Jugadores"] = espEnabled, 
            ["Mostrar Resplandor (Glow)"] = espSettings.Glow, 
            ["Mostrar Nombre"] = espSettings.Name, 
            ["Mostrar Distancia"] = espSettings.Distance, 
            ["Ocultar mi Nombre (Local)"] = hideNameEnabled, 
            ["FPS Boost"] = fpsBoostEnabled
        },
        Sliders = { 
            ["Tamaño del FOV"] = fovRadius, 
            ["Tamaño de Hitbox"] = hitboxSize, 
            ["Delay Equipar Macro"] = macroEquipDelay,
            ["Delay Disparo Macro"] = macroShootDelay
        },
        Colors = {
            ["Color de Hitbox"] = {R = hitboxColor.R, G = hitboxColor.G, B = hitboxColor.B}, 
            ["Color del ESP"] = {R = espColor.R, G = espColor.G, B = espColor.B} 
        },
        Extras = {
            -- Los campos antiguos se conservan para compatibilidad con configs viejas.
            ["Parte Aimbot"] = silentAimTargetPart,
            ["Parte AutoShoot"] = autoShootTargetPart,
            ["Partes Aimbot"] = runtime.GetTargetSelectionArray("SilentAim"),
            ["Partes AutoShoot"] = runtime.GetTargetSelectionArray("AutoShoot")
        },
        Apariencia = runtime.SerializeAppearanceConfig(),
        -- BORRA LA LINEA VIEJA DE getgenv().AstraGetSavedAnimations Y PON ESTA:
        Animaciones = {
            Paquete = selectedBundleCompleto,
            Mix = mixParts
        }
    }
    
    if writefile then 
        local sEncode, encodedData = pcall(function() return HttpService:JSONEncode(configData) end)
        if sEncode then
            pcall(function() writefile(path, encodedData) end) 
            showBottomMessage(" Guardado como: " .. finalName) 
            refreshConfigs()
            pcall(function() configDropdown:Select(finalName) end)
        else
            showBottomMessage(" Error interno al procesar los datos.")
        end
    else 
        showBottomMessage(" Error: Tu ejecutor no soporta guardar") 
    end
end})

function secureLoadToggle(element, val) 
    if not element or val == nil then return end 
    -- Cargar una config puede cambiar muchos controles de golpe. Silenciamos
    -- esos callbacks y mostramos solamente el resultado final de la carga.
    local wasSuppressed = runtime.SuppressNotifications
    runtime.SuppressNotifications = true
    pcall(function() element:Set(val) end)
    runtime.SuppressNotifications = wasSuppressed
end

Tabs.Config:Button({ Title = " Cargar Configuración", Callback = function()
    if selectedConfig == "Ninguna" or selectedConfig == "" then
        showBottomMessage("No hay ninguna configuración seleccionada.")
        return
    end
    
    local path = configPaths[selectedConfig] or (configFolder .. "/" .. selectedConfig .. ".json")
    if isfile and isfile(path) then
        local success, decoded = pcall(function() return HttpService:JSONDecode(readfile(path)) end)
        if success and type(decoded) == "table" then
            
            -- Toggles
             if decoded.Toggles then
                -- 🔥 NUEVOS AGREGADOS CARGA:
                if decoded.Toggles["Auto Shoot"] ~= nil then autoShootEnabled = decoded.Toggles["Auto Shoot"] secureLoadToggle(UIElements.TogAutoShoot, autoShootEnabled) end
                -- 🔥 AQUÍ CARGAS EL CUCHILLO (Y actualizas el toggle visual)
                if decoded.Toggles["AutoShoot Cuchillo"] ~= nil then 
                    autoShootCuchilloEnabled = decoded.Toggles["AutoShoot Cuchillo"] 
                    secureLoadToggle(UIElements.TogAutoShootCuchillo, autoShootCuchilloEnabled) 
                end
                
                -- Cargar Silent Aim Pistola (con compatibilidad vieja)
                if decoded.Toggles["Silent Aim (Pistola)"] ~= nil then 
                    silentAimPistolaEnabled = decoded.Toggles["Silent Aim (Pistola)"] 
                    secureLoadToggle(UIElements.TogSilentAimPistola, silentAimPistolaEnabled) 
                elseif decoded.Toggles["Silent Aim (Manual)"] ~= nil then 
                    silentAimPistolaEnabled = decoded.Toggles["Silent Aim (Manual)"] 
                    secureLoadToggle(UIElements.TogSilentAimPistola, silentAimPistolaEnabled) 
                end
                
                -- Cargar Silent Aim Cuchillo
                if decoded.Toggles["Silent Aim (Cuchillo)"] ~= nil then 
                    silentAimCuchilloEnabled = decoded.Toggles["Silent Aim (Cuchillo)"] 
                    secureLoadToggle(UIElements.TogSilentAimCuchillo, silentAimCuchilloEnabled) 
                end

                if decoded.Toggles["Silent Aim (FOV)"] ~= nil then silentAimFovEnabled = decoded.Toggles["Silent Aim (FOV)"] secureLoadToggle(UIElements.TogSilentAimFOV, silentAimFovEnabled) end

                if decoded.Toggles["Mostrar Círculo FOV"] ~= nil then fovVisiblePreference = decoded.Toggles["Mostrar Círculo FOV"] secureLoadToggle(UIElements.TogShowFOV, fovVisiblePreference) end
                if decoded.Toggles["ESP Lineas"] ~= nil then espLinesEnabled = decoded.Toggles["ESP Lineas"] secureLoadToggle(UIElements.TogEspLines, espLinesEnabled) end
                if decoded.Toggles["ESP Box 2D"] ~= nil then espSettings.Box = decoded.Toggles["ESP Box 2D"] secureLoadToggle(UIElements.TogEspBox, espSettings.Box) end
                if decoded.Toggles["ESP Barra Vida"] ~= nil then espSettings.HealthBar = decoded.Toggles["ESP Barra Vida"] secureLoadToggle(UIElements.TogEspHealth, espSettings.HealthBar) end
                
                -- Botones Flotantes (Usando Set() para que se actulice el toggle visual)
                if decoded.Toggles["Btn Flotante AutoShoot"] ~= nil then secureLoadToggle(UIElements.ToggleAsBtn, decoded.Toggles["Btn Flotante AutoShoot"]) end
                if decoded.Toggles["Btn Flotante SilentAim"] ~= nil then secureLoadToggle(UIElements.ToggleSaBtn, decoded.Toggles["Btn Flotante SilentAim"]) end
                if decoded.Toggles["Btn Flotante Fantasma"] ~= nil then secureLoadToggle(UIElements.ToggleGhost, decoded.Toggles["Btn Flotante Fantasma"]) end

                -- EXISTENTES CARGA:
                if decoded.Toggles["Aumentar Hitbox"] ~= nil then hitboxEnabled = decoded.Toggles["Aumentar Hitbox"] secureLoadToggle(UIElements.TogHitbox, hitboxEnabled) end
                if decoded.Toggles["Hitbox Invisible"] ~= nil then hitboxInvisible = decoded.Toggles["Hitbox Invisible"] secureLoadToggle(UIElements.TogHbInv, hitboxInvisible) end
                if decoded.Toggles["ESP Jugadores"] ~= nil then espEnabled = decoded.Toggles["ESP Jugadores"] secureLoadToggle(UIElements.TogEsp, espEnabled) end
                if decoded.Toggles["Mostrar Resplandor (Glow)"] ~= nil then espSettings.Glow = decoded.Toggles["Mostrar Resplandor (Glow)"] secureLoadToggle(UIElements.TogEspGl, espSettings.Glow) end
                if decoded.Toggles["Mostrar Nombre"] ~= nil then espSettings.Name = decoded.Toggles["Mostrar Nombre"] secureLoadToggle(UIElements.TogEspNm, espSettings.Name) end
                if decoded.Toggles["Mostrar Distancia"] ~= nil then espSettings.Distance = decoded.Toggles["Mostrar Distancia"] secureLoadToggle(UIElements.TogEspDs, espSettings.Distance) end
                if decoded.Toggles["Ocultar mi Nombre (Local)"] ~= nil then hideNameEnabled = decoded.Toggles["Ocultar mi Nombre (Local)"] secureLoadToggle(UIElements.TogHideName, hideNameEnabled) end
                if decoded.Toggles["FPS Boost"] ~= nil then fpsBoostEnabled = decoded.Toggles["FPS Boost"] secureLoadToggle(UIElements.ToggleFPS, fpsBoostEnabled) end
            end
            
            -- Sliders
            if decoded.Sliders then 
                if decoded.Sliders["Transparencia Hitbox"] ~= nil then hitboxTransparency = decoded.Sliders["Transparencia Hitbox"] secureLoadToggle(UIElements.SliHitboxTrans, hitboxTransparency) end
                if decoded.Sliders["Tamaño del FOV"] ~= nil then fovRadius = decoded.Sliders["Tamaño del FOV"] secureLoadToggle(UIElements.SliFOVSize, fovRadius) end
                if decoded.Sliders["Tamaño de Hitbox"] ~= nil then hitboxSize = decoded.Sliders["Tamaño de Hitbox"] secureLoadToggle(UIElements.SliHitbox, hitboxSize) end
                if decoded.Sliders["Delay Equipar Macro"] ~= nil then macroEquipDelay = decoded.Sliders["Delay Equipar Macro"] secureLoadToggle(UIElements.SliMacroEquip, macroEquipDelay) end
                if decoded.Sliders["Delay Disparo Macro"] ~= nil then macroShootDelay = decoded.Sliders["Delay Disparo Macro"] secureLoadToggle(UIElements.SliMacroShoot, macroShootDelay) end
            end
        
            
            -- Colores
            if decoded.Colors then
                if decoded.Colors["Color de Hitbox"] then
                    local cHitbox = Color3.new(decoded.Colors["Color de Hitbox"].R, decoded.Colors["Color de Hitbox"].G, decoded.Colors["Color de Hitbox"].B)
                    hitboxColor = cHitbox secureLoadToggle(UIElements.ColHitbox, cHitbox) 
                end
                if decoded.Colors["Color del ESP"] then
                    local cEsp = Color3.new(decoded.Colors["Color del ESP"].R, decoded.Colors["Color del ESP"].G, decoded.Colors["Color del ESP"].B)
                    espColor = cEsp secureLoadToggle(UIElements.ColEsp, cEsp) 
                end
            end
            
            -- Extras: multiselección corporal + compatibilidad con configs anteriores.
            if decoded.Extras then
                if decoded.Extras["Partes Aimbot"] then
                    runtime.SetTargetSelection("SilentAim", decoded.Extras["Partes Aimbot"])
                elseif decoded.Extras["Parte Aimbot"] then
                    runtime.SetTargetSelection("SilentAim", decoded.Extras["Parte Aimbot"])
                end

                if decoded.Extras["Partes AutoShoot"] then
                    runtime.SetTargetSelection("AutoShoot", decoded.Extras["Partes AutoShoot"])
                elseif decoded.Extras["Parte AutoShoot"] then
                    runtime.SetTargetSelection("AutoShoot", decoded.Extras["Parte AutoShoot"])
                end
            end

            if decoded.Apariencia then
                runtime.LoadAppearanceConfig(decoded.Apariencia)
            end

            -- CARGAR ANIMACIONES NUEVAS
            if decoded.Animaciones then
                task.spawn(function()
                    -- Esperar un segundo para asegurar que el personaje exista
                    task.wait(1) 
                    
                    if decoded.Animaciones.Paquete and decoded.Animaciones.Paquete ~= "Ninguno" then
                        selectedBundleCompleto = decoded.Animaciones.Paquete
                        -- 🔥 FIX: Guardar en la memoria global para que sobreviva al respawn
                        animacionActualActiva = animationData[selectedBundleCompleto]
                        applyCustomAnims(animacionActualActiva)
                        
                    elseif decoded.Animaciones.Mix then
                        mixParts = decoded.Animaciones.Mix
                        local customMix = {}
                        
                        if mixParts.Idle ~= "Ninguno" then
                            customMix.Idle = animationData[mixParts.Idle].Idle
                            customMix.Idle2 = animationData[mixParts.Idle].Idle2
                        end
                        if mixParts.Walk ~= "Ninguno" then customMix.Walk = animationData[mixParts.Walk].Walk end
                        if mixParts.Run ~= "Ninguno" then customMix.Run = animationData[mixParts.Run].Run end
                        if mixParts.Jump ~= "Ninguno" then customMix.Jump = animationData[mixParts.Jump].Jump end
                        if mixParts.Fall ~= "Ninguno" then customMix.Fall = animationData[mixParts.Fall].Fall end
                        if mixParts.Climb ~= "Ninguno" then customMix.Climb = animationData[mixParts.Climb].Climb end

                        local hasValues = false
                        for _, v in pairs(customMix) do if v then hasValues = true break end end
                        
                        if hasValues then 
                            -- 🔥 FIX: Guardar el mix en la memoria global
                            animacionActualActiva = customMix
                            applyCustomAnims(animacionActualActiva) 
                        end
                    end
                end)
            end
            
            
            showBottomMessage("'" .. selectedConfig .. "' cargada con éxito.")
        else 
            showBottomMessage("Error al leer el archivo.") 
        end
    else 
        showBottomMessage("La configuración no existe.") 
    end
end})
-- Cargar la lista al iniciar el script
task.spawn(function()
    task.wait(1)
    refreshConfigs()
end)

-- El splash sólo existe durante esta ejecución inicial. Abrir y cerrar el hub
-- después de este punto permanece completamente instantáneo.
startupSplashState.Finish()
runtime.NotificationsReady = true
