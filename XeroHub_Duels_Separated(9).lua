-- iLunXHub | Weapon Lab v0.1 | AlexDev
-- Standalone LOCAL cosmetic experiment. Does not grant inventory ownership.
-- Run separately from the main hub for the first test. No remote loader/network calls.
-- Scan -> optionally load catalog -> select -> equip a real Tool -> Apply.
-- Restore / Close undo this lab's changes. Respawn clears the applied visual.
-- Script-driven animation, bursts and server-only assets cannot be reconstructed here.
-- The chunk also exposes its pure resolver via chunk('core') for reuse/testing.

local Core = {}
function Core.normalize(value)
    return tostring(value or ''):lower():gsub('[%s%p]', '')
end
function Core.newIndex()
    return {items={}, aliases={}, visuals={}}
end
function Core.addItem(index, key, data)
    if type(key) ~= 'string' or type(data) ~= 'table' then return end
    index.items[key] = data
    for _, alias in ipairs({key, data.ItemName or key}) do
        alias = Core.normalize(alias)
        if alias ~= '' then
            index.aliases[alias] = index.aliases[alias] or {}
            index.aliases[alias][key] = true
        end
    end
end
function Core.resolve(index, identities)
    local selected
    for _, identity in ipairs(identities) do
        local match
        if index.items[identity] then
            match = identity
        else
            local aliases = index.aliases[Core.normalize(identity)] or {}
            for key in pairs(aliases) do
                if match and match ~= key then return nil end
                match = key
            end
        end
        if match then
            if selected and selected ~= match then return nil end
            selected = match
        end
    end
    return selected
end
function Core.register(index, key, template, score, source)
    local old = index.visuals[key]
    if old and old.score > score then return false end
    index.visuals[key] = {template=template, score=score, source=source}
    return true, old
end
function Core.ingest(index, data)
    local seen, budget = {}, 12000
    local function walk(node, depth)
        if type(node) ~= 'table' or seen[node] or depth > 5 or budget <= 0 then return end
        seen[node] = true
        for key, value in pairs(node) do
            budget = budget - 1
            if budget <= 0 then break end
            if type(value) == 'table' then
                if type(key) == 'string' and (value.ItemName or value.Image)
                    and (value.ItemType == 'Knife' or value.ItemType == 'Gun' or value.ItemType == 'Effect') then
                    Core.addItem(index, key, value)
                end
                walk(value, depth + 1)
            end
        end
    end
    walk(data, 0)
end
function Core.filter(index, query, kind, onlyAvailable)
    local result, needle = {}, tostring(query or ''):lower()
    for key, data in pairs(index.items) do
        local text = (key .. ' ' .. tostring(data.ItemName or '')):lower()
        if (kind == 'Todos' or data.ItemType == kind)
            and (not onlyAvailable or index.visuals[key]) and text:find(needle, 1, true) then
            result[#result+1] = key
        end
    end
    table.sort(result)
    return result
end
function Core.toolKind(name, children)
    name = Core.normalize(name)
    if name == 'gun' or name == 'pistol' or name == 'revolver' or children.GunClient then return 'Gun' end
    if name == 'knife' or children.KnifeClient or children.Throw then return 'Knife' end
    return nil
end
function Core.identities(name, metadata, isTool)
    local result = {}
    for _, value in ipairs(metadata) do result[#result+1] = value end
    local generic = {knife=true, gun=true, pistol=true, revolver=true, weapon=true, tool=true}
    if not isTool or not generic[Core.normalize(name)] then result[#result+1] = name end
    return result
end
if ... == 'core' then return Core end

local Players = game:GetService('Players')
local RS = game:GetService('ReplicatedStorage')
local UIS = game:GetService('UserInputService')
local player = Players.LocalPlayer
assert(player, 'Weapon Lab debe ejecutarse en el cliente, no en un Script de servidor.')
local playerGui = player:WaitForChild('PlayerGui')
local env = (getgenv and getgenv()) or _G
local singleton = '__ILUNX_WEAPON_LAB_V1'
if env[singleton] and env[singleton].close then pcall(env[singleton].close) end
local state = {
    alive=true, index=Core.newIndex(), connections={}, playerConnections={}, jobs={},
    snapshots={}, selected=nil, page=1, query='', kind='Todos', available=false,
    learning=false, scanning=false, loading=false, logs={}, active=nil,
}
env[singleton] = state
local refresh, detail, statusLabel, logBox
local function log(message)
    message = tostring(message)
    state.logs[#state.logs+1] = os.date('%H:%M:%S') .. ' | ' .. message
    if #state.logs > 80 then table.remove(state.logs, 1) end
    print('[iLunX Weapon Lab] ' .. message)
    if statusLabel then statusLabel.Text = message end
    if logBox then logBox.Text = table.concat(state.logs, '\n') end
end
local function connect(signal, callback, bucket)
    local connection = signal:Connect(callback)
    local list = bucket or state.connections
    list[#list+1] = connection
    return connection
end
local function disconnectAll(list)
    for _, connection in ipairs(list) do connection:Disconnect() end
    table.clear(list)
end
local function schedule(seconds, callback)
    local thread
    thread = task.delay(seconds, function()
        state.jobs[thread] = nil
        if state.alive then callback() end
    end)
    state.jobs[thread] = true
    return thread
end
local function path(object)
    local ok, value = pcall(function() return object:GetFullName() end)
    return ok and value or object.Name
end
local function isVisual(object)
    return typeof(object) == 'Instance' and
        (object:IsA('Tool') or object:IsA('Model') or object:IsA('BasePart'))
end
local function all(root)
    local list = root:GetDescendants()
    table.insert(list, 1, root)
    return list
end
local function rootPart(root)
    if root:IsA('BasePart') then return root end
    local handle = root:FindFirstChild('Handle', true)
    if handle and handle:IsA('BasePart') then return handle end
    if root:IsA('Model') and root.PrimaryPart then return root.PrimaryPart end
    return root:FindFirstChildWhichIsA('BasePart', true)
end
local function identities(object)
    local result = {}
    for _, key in ipairs({'Skin','SkinName','WeaponName','ItemName','ItemId','WeaponId'}) do
        local value = object:GetAttribute(key)
        if type(value) == 'string' then result[#result+1] = value end
        local child = object:FindFirstChild(key)
        if child and child:IsA('StringValue') then result[#result+1] = child.Value end
    end
    return Core.identities(object.Name, result, object:IsA('Tool'))
end
local function kindOf(tool)
    local kind = tool:GetAttribute('ItemType') or tool:GetAttribute('WeaponType')
    if kind == 'Knife' or kind == 'Gun' then return kind end
    local key = Core.resolve(state.index, identities(tool))
    if key then
        kind = state.index.items[key].ItemType
        if kind == 'Knife' or kind == 'Gun' then return kind end
    end
    return Core.toolKind(tool.Name, {
        GunClient=tool:FindFirstChild('GunClient') ~= nil,
        KnifeClient=tool:FindFirstChild('KnifeClient') ~= nil,
        Throw=tool:FindFirstChild('Throw') ~= nil,
    })
end
local function sanitize(template)
    -- Clone off-world; never enable scripts in the copy.
    local changed = {}
    for _, object in ipairs(all(template)) do
        if not object.Archivable then
            changed[#changed+1] = object
            object.Archivable = true
        end
    end
    local ok, copy = pcall(function() return template:Clone() end)
    for _, object in ipairs(changed) do pcall(function() object.Archivable = false end) end
    if not ok or not copy then return nil, 'El modelo no se pudo clonar.' end
    local partCount = 0
    for _, object in ipairs(all(copy)) do
        if object:IsA('LuaSourceContainer') or object:IsA('JointInstance')
            or object:IsA('Constraint') or object:IsA('WeldConstraint') or object:IsA('BodyMover')
            or object:IsA('Sound') or object:IsA('Humanoid')
            or object:IsA('AnimationController') or object:IsA('ClickDetector')
            or object:IsA('ProximityPrompt') or object:IsA('RemoteEvent')
            or object:IsA('RemoteFunction') or object:IsA('BindableEvent')
            or object:IsA('BindableFunction') then
            object:Destroy()
        elseif object:IsA('BasePart') then
            partCount = partCount + 1
            object.Anchored = true
            object.CanCollide, object.CanTouch, object.CanQuery = false, false, false
            object.Massless = true
            object.LocalTransparencyModifier = 0
        end
    end
    if partCount == 0 or partCount > 350 then
        copy:Destroy()
        return nil, 'Modelo vacío o demasiado grande (>350 piezas).'
    end
    -- Remove external endpoint references. Internal cloned endpoints remain intact.
    for _, object in ipairs(copy:GetDescendants()) do
        if object:IsA('Beam') or object:IsA('Trail') then
            for _, property in ipairs({'Attachment0','Attachment1'}) do
                local endpoint = object[property]
                if endpoint and not endpoint:IsDescendantOf(copy) then object[property] = nil end
            end
        end
    end
    return copy
end
local function register(key, object, score, source, snapshot)
    if not rootPart(object) then return end
    local old = state.index.visuals[key]
    if old and old.score > score then return end
    if snapshot then
        local count = 0
        for _ in pairs(state.snapshots) do count = count + 1 end
        if count >= 80 and not (old and state.snapshots[old.template]) then return end
        local copy = sanitize(object)
        if not copy then return end
        object = copy
        state.snapshots[copy] = true
    end
    Core.register(state.index, key, object, score, source)
    if old and old.template ~= object and state.snapshots[old.template] then
        state.snapshots[old.template] = nil
        old.template:Destroy()
    end
end
local function restore(silent)
    local active = state.active
    state.active = nil
    if not active then return end
    disconnectAll(active.connections)
    if active.model then active.model:Destroy() end
    for object, properties in pairs(active.originals) do
        for property, value in pairs(properties) do
            pcall(function() object[property] = value end)
        end
    end
    if not silent then log('Visual restaurado. El Tool original sigue intacto.') end
end
state.restore = restore
local function hideOriginal(active, object)
    if object:IsDescendantOf(active.model) then return end
    local property, replacement
    if object:IsA('BasePart') then property, replacement = 'LocalTransparencyModifier', 1
    elseif object:IsA('Decal') or object:IsA('Texture') then property, replacement = 'Transparency', 1
    elseif object:IsA('ParticleEmitter') or object:IsA('Trail') or object:IsA('Beam') or object:IsA('Light') then
        property, replacement = 'Enabled', false
    end
    if property and not active.originals[object] then
        active.originals[object] = {[property]=object[property]}
        object[property] = replacement
        connect(object:GetPropertyChangedSignal(property), function()
            if state.active == active and object[property] ~= replacement then
                object[property] = replacement
            end
        end, active.connections)
    end
end
local function apply()
    local key = state.selected
    local record = key and state.index.visuals[key]
    if not record then log('Sin modelo 3D: carga el catálogo, escanea o activa Aprender.') return end
    local character = player.Character
    local tool = character and character:FindFirstChildWhichIsA('Tool')
    if not tool then log('Primero equipa en la mano tu cuchillo o pistola real.') return end
    local handle = tool:FindFirstChild('Handle')
    if not handle or not handle:IsA('BasePart') then log('Tool sin Handle compatible.') return end
    local expected, actual = state.index.items[key].ItemType, kindOf(tool)
    if expected == 'Effect' then log('Esta prueba aplica modelos completos; efectos sueltos aún no.') return end
    if actual and (expected == 'Knife' or expected == 'Gun') and expected ~= actual then
        log('Tipo distinto: equipa un arma de tipo ' .. expected .. '.') return
    end
    local copy, problem = sanitize(record.template)
    if not copy then log(problem) return end
    local sourceRoot = rootPart(copy)
    local origin = sourceRoot.CFrame
    local model = Instance.new('Model')
    model.Name = 'iLunX_WeaponLab_Visual'
    model:SetAttribute('WeaponLabVisual', true)
    -- Tool -> Model: do not create a second functional Tool or lose child effects.
    if copy:IsA('Tool') then
        for _, child in ipairs(copy:GetChildren()) do child.Parent = model end
        copy:Destroy()
    else copy.Parent = model end
    local ok, err = pcall(function()
        for _, object in ipairs(model:GetDescendants()) do
            if object:IsA('BasePart') then
                object.CFrame = handle.CFrame * origin:ToObjectSpace(object.CFrame)
                local weld = Instance.new('WeldConstraint')
                weld.Part0, weld.Part1 = handle, object
                weld.Parent = object
                object.Anchored = false
            end
        end
    end)
    if not ok then model:Destroy() log('No se pudo preparar el visual: ' .. tostring(err)) return end
    restore(true)
    local active = {tool=tool, model=model, originals={}, connections={}}
    state.active = active
    local committed, commitError = pcall(function()
        model.Parent = tool
        for _, object in ipairs(tool:GetDescendants()) do hideOriginal(active, object) end
        connect(tool.DescendantAdded, function(object)
            if state.active == active then hideOriginal(active, object) end
        end, active.connections)
        connect(tool.AncestryChanged, function()
            if state.active == active and not tool:IsDescendantOf(character) then restore(true) log('Arma guardada: visual restaurado.') end
        end, active.connections)
    end)
    if not committed then restore(true) log('Aplicación cancelada: ' .. tostring(commitError)) return end
    log('Aplicado: ' .. tostring(state.index.items[key].ItemName or key) .. '. Solo visible para ti.')
end

local function candidate(object)
    if not isVisual(object) or not rootPart(object) then return end
    local key = Core.resolve(state.index, identities(object))
    if key then
        local score = object:IsA('Tool') and 90 or (object:IsA('Model') and 80 or 70)
        register(key, object, score, path(object), false)
        return
    end
    -- Unidentified models remain explicitly raw candidates; never pretend a skin match.
    local parent = object.Parent
    if not parent or parent:IsA('Tool') or parent:IsA('Model') or parent:IsA('BasePart') then return end
    local context = path(parent):lower()
    local weaponContext = context:find('weapon',1,true) or context:find('skin',1,true)
        or context:find('knife',1,true) or context:find('gun',1,true)
    if not weaponContext and not object:IsA('Tool') then return end
    local rawKey = '@modelo:' .. path(object)
    Core.addItem(state.index, rawKey, {ItemName=object.Name .. ' [modelo sin identificar]', ItemType='Modelo'})
    register(rawKey, object, 10, path(object), false)
end
local function scan()
    if state.scanning then log('Ya hay un escaneo en curso.') return end
    state.scanning = true
    log('Escaneando modelos replicados...')
    schedule(0, function()
        local ok, err = pcall(function()
            for i, object in ipairs(RS:GetDescendants()) do
                if not state.alive then return end
                candidate(object)
                if i % 160 == 0 then task.wait() end
            end
            -- Direct Instance metadata links; do not interpret icon IDs as mesh IDs.
            for key, data in pairs(state.index.items) do
                for _, value in pairs(data) do
                    if isVisual(value) then register(key, value, 100, 'Metadata: ' .. path(value), false) end
                end
            end
        end)
        state.scanning = false
        if not state.alive then return end
        if not ok then log('Escaneo incompleto: ' .. tostring(err)) else log('Escaneo terminado. Revisa el contador y los modelos disponibles.') end
        refresh()
    end)
end
local function loadCatalog()
    if state.loading then return end
    state.loading = true
    log('Leyendo ModuleScripts replicados (pueden ejecutar lógica propia)...')
    schedule(0, function()
        local loaded, failed, timeout = 0, 0, 0
        for _, module in ipairs(RS:GetDescendants()) do
            if not state.alive then break end
            if module:IsA('ModuleScript') then
                local done, ok, data = false, false, nil
                local worker = task.spawn(function()
                    ok, data = pcall(require, module)
                    done = true
                end)
                state.jobs[worker] = true
                local deadline = os.clock() + 0.6
                repeat task.wait() until done or not state.alive or os.clock() >= deadline
                state.jobs[worker] = nil
                if not done then
                    pcall(task.cancel, worker)
                    timeout = timeout + 1
                elseif ok and type(data) == 'table' then
                    Core.ingest(state.index, data)
                    loaded = loaded + 1
                else failed = failed + 1 end
                if (loaded+failed+timeout) % 20 == 0 then
                    log(string.format('Catálogo: %d tablas / %d errores / %d tiempos agotados', loaded, failed, timeout))
                    refresh()
                end
            end
        end
        state.loading = false
        if state.alive then
            log(string.format('Catálogo listo: %d tablas, %d errores, %d tiempos agotados.', loaded, failed, timeout))
            scan()
        end
    end)
end
local observed = setmetatable({}, {__mode='k'})
local function learnTool(tool, owner)
    if not state.learning or not tool:IsA('Tool') or not tool.Parent then return end
    if tool:FindFirstChild('iLunX_WeaponLab_Visual') then return end
    local key = Core.resolve(state.index, identities(tool))
    if not key then
        key = '@visto:' .. owner.UserId .. ':' .. tool.Name
        Core.addItem(state.index, key, {
            ItemName=tool.Name .. ' [visto en ' .. owner.DisplayName .. '; skin no identificada]',
            ItemType=kindOf(tool) or 'Modelo',
        })
    end
    register(key, tool, 60, 'Equipado por ' .. owner.Name .. ' | ' .. path(tool), true)
    refresh()
end
local function queueLearn(tool, owner)
    if not state.learning or not tool:IsA('Tool') or observed[tool] then return end
    observed[tool] = true
    schedule(0.6, function() learnTool(tool, owner) end)
    schedule(1.8, function() learnTool(tool, owner) observed[tool] = nil end)
end
local function watchPlayer(owner)
    local bucket = {}
    state.playerConnections[owner] = bucket
    local characterBucket = {}
    local function bind(character)
        disconnectAll(characterBucket)
        connect(character.ChildAdded, function(child) queueLearn(child, owner) end, characterBucket)
        connect(character.DescendantAdded, function(child)
            local tool = child:FindFirstAncestorWhichIsA('Tool')
            if tool then queueLearn(tool, owner) end
        end, characterBucket)
        for _, child in ipairs(character:GetChildren()) do queueLearn(child, owner) end
    end
    connect(owner.CharacterAdded, bind, bucket)
    connect(owner.CharacterRemoving, function() disconnectAll(characterBucket) end, bucket)
    bucket.characterBucket = characterBucket
    if owner.Character then bind(owner.Character) end
end

-- Native self-contained UI. All IDs and runtime state are separate from the main hub.
local gui = Instance.new('ScreenGui')
gui.Name = 'iLunX_WeaponLab'
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.DisplayOrder = 500
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui
local function create(class, properties, parent)
    local object = Instance.new(class)
    for key, value in pairs(properties) do object[key] = value end
    object.Parent = parent
    return object
end
local white, gray = Color3.fromRGB(238,238,238), Color3.fromRGB(175,175,175)
local function round(object, radius)
    create('UICorner', {CornerRadius=UDim.new(0,radius or 9)}, object)
end
local panel = create('Frame', {
    AnchorPoint=Vector2.new(0.5,0.5), Position=UDim2.fromScale(0.5,0.5),
    Size=UDim2.new(1,-20,1,-28), BackgroundColor3=Color3.fromRGB(12,12,14), BorderSizePixel=0,
}, gui)
create('UISizeConstraint', {MaxSize=Vector2.new(590,740)}, panel)
round(panel, 16)
create('UIStroke', {Color=Color3.fromRGB(72,72,76), Thickness=1}, panel)
local header = create('TextLabel', {Text='iLunXHub / WEAPON LAB  ·  AlexDev',
    Size=UDim2.new(1,-96,0,46), Position=UDim2.fromOffset(14,0), BackgroundTransparency=1,
    Font=Enum.Font.GothamMedium, TextSize=13, TextColor3=white, TextXAlignment=Enum.TextXAlignment.Left,
    TextTruncate=Enum.TextTruncate.AtEnd, Active=true}, panel)
local scroll = create('ScrollingFrame', {Size=UDim2.new(1,-20,1,-58), Position=UDim2.fromOffset(10,48),
    BackgroundTransparency=1, BorderSizePixel=0, ScrollBarThickness=3,
    AutomaticCanvasSize=Enum.AutomaticSize.Y, CanvasSize=UDim2.new(), ScrollingDirection=Enum.ScrollingDirection.Y}, panel)
create('UIListLayout', {Padding=UDim.new(0,7), SortOrder=Enum.SortOrder.LayoutOrder}, scroll)
create('UIPadding', {PaddingBottom=UDim.new(0,16), PaddingRight=UDim.new(0,5)}, scroll)
local order = 0
local function nextOrder() order=order+1 return order end
local function label(text, height)
    return create('TextLabel', {Text=text, Size=UDim2.new(1,0,0,height or 34), BackgroundTransparency=1,
        TextColor3=gray, TextSize=12, Font=Enum.Font.Gotham, TextWrapped=true,
        TextXAlignment=Enum.TextXAlignment.Left, LayoutOrder=nextOrder()}, scroll)
end
local function button(text, callback, parent)
    local object = create('TextButton', {Text=text, Size=UDim2.new(1,0,0,34),
        BackgroundColor3=Color3.fromRGB(29,29,33), BorderSizePixel=0, TextColor3=white,
        TextSize=12, Font=Enum.Font.GothamMedium, TextWrapped=true, LayoutOrder=nextOrder()}, parent or scroll)
    round(object)
    connect(object.Activated, function()
        local ok, err = pcall(callback)
        if not ok then log('Error controlado: ' .. tostring(err)) end
    end)
    return object
end
local function row()
    local frame = create('Frame', {Size=UDim2.new(1,0,0,36), BackgroundTransparency=1, LayoutOrder=nextOrder()}, scroll)
    create('UIListLayout', {FillDirection=Enum.FillDirection.Horizontal, Padding=UDim.new(0,6), SortOrder=Enum.SortOrder.LayoutOrder}, frame)
    return frame
end
label('Prueba local · no modifica tu inventario ni concede armas. Equipa un Tool real antes de aplicar.', 38)
local counts = label('Modelos: 0', 28)
local actions = row()
local scanButton = button('Escanear modelos', scan, actions)
local catalogButton = button('Cargar catálogo', loadCatalog, actions)
scanButton.Size, catalogButton.Size = UDim2.new(0.5,-3,1,0), UDim2.new(0.5,-3,1,0)
label('Catálogo es opcional: usa require en módulos del juego. No puede deshacer efectos internos de esos módulos.', 35)
local learnButton
learnButton = button('Aprender equipados: OFF', function()
    state.learning = not state.learning
    learnButton.Text = 'Aprender equipados: ' .. (state.learning and 'ON' or 'OFF')
    if state.learning then
        for _, owner in ipairs(Players:GetPlayers()) do
            if owner.Character then for _, child in ipairs(owner.Character:GetChildren()) do queueLearn(child, owner) end end
        end
    end
    log(state.learning and 'Aprendizaje activo. Captura local: máximo 80 modelos.' or 'Aprendizaje detenido; caché conservada hasta cerrar.')
end)
local search = create('TextBox', {Size=UDim2.new(1,0,0,36), BackgroundColor3=Color3.fromRGB(23,23,26),
    Text='', PlaceholderText='Buscar arma / modelo...', PlaceholderColor3=gray, TextColor3=white,
    TextSize=13, Font=Enum.Font.Gotham, ClearTextOnFocus=false, LayoutOrder=nextOrder()}, scroll)
round(search)
local filters = row()
local types = {'Todos','Knife','Gun','Effect','Modelo'}
local typeIndex, typeButton, availableButton = 1
typeButton = button('Tipo: Todos', function()
    typeIndex = typeIndex % #types + 1
    state.kind = types[typeIndex]
    typeButton.Text = 'Tipo: ' .. state.kind
    state.page=1 refresh()
end, filters)
availableButton = button('Solo disponibles: OFF', function()
    state.available = not state.available
    availableButton.Text = 'Solo disponibles: ' .. (state.available and 'ON' or 'OFF')
    state.page=1 refresh()
end, filters)
typeButton.Size, availableButton.Size = UDim2.new(0.45,-3,1,0), UDim2.new(0.55,-3,1,0)
local list = create('Frame', {Size=UDim2.new(1,0,0,0), AutomaticSize=Enum.AutomaticSize.Y,
    BackgroundTransparency=1, LayoutOrder=nextOrder()}, scroll)
create('UIListLayout', {Padding=UDim.new(0,4), SortOrder=Enum.SortOrder.LayoutOrder}, list)
local rowButtons, rowKeys = {}, {}
for i=1,8 do
    local b = button('', function()
        state.selected = rowKeys[i]
        refresh()
    end, list)
    b.TextXAlignment = Enum.TextXAlignment.Left
    create('UIPadding', {PaddingLeft=UDim.new(0,9), PaddingRight=UDim.new(0,7)}, b)
    b.Size = UDim2.new(1,0,0,40)
    rowButtons[i]=b
end
local paging = row()
local prev = button('< Anterior', function() state.page=math.max(1,state.page-1) refresh() end, paging)
local pageLabel = create('TextLabel', {Size=UDim2.new(0.34,-4,1,0), Text='', BackgroundTransparency=1,
    TextColor3=gray, TextSize=12, Font=Enum.Font.Gotham, LayoutOrder=nextOrder()}, paging)
local nextPage = button('Siguiente >', function() state.page=state.page+1 refresh() end, paging)
prev.Size, nextPage.Size = UDim2.new(0.33,-4,1,0), UDim2.new(0.33,-4,1,0)
detail = label('Selecciona un modelo. [3D] = encontrado; [--] = solo metadata.', 84)
local applyRow = row()
local applyButton = button('Aplicar a mi arma', apply, applyRow)
local restoreButton = button('Restaurar', function() restore(false) end, applyRow)
applyButton.Size, restoreButton.Size = UDim2.new(0.6,-3,1,0), UDim2.new(0.4,-3,1,0)
statusLabel = label('Listo para escanear.', 48)
label('Diagnóstico (selecciona y copia el texto si hay un fallo):', 22)
logBox = create('TextBox', {Size=UDim2.new(1,0,0,150), BackgroundColor3=Color3.fromRGB(20,20,23),
    Text='', TextColor3=gray, TextSize=11, Font=Enum.Font.Code, TextWrapped=true, MultiLine=true,
    ClearTextOnFocus=false, TextEditable=false, TextXAlignment=Enum.TextXAlignment.Left,
    TextYAlignment=Enum.TextYAlignment.Top, LayoutOrder=nextOrder()}, scroll)
round(logBox)
label('Efectos que dependan de scripts, disparos o animaciones no se reproducen automáticamente. Al guardar el arma o reaparecer, se restaura.', 44)
refresh = function()
    if not state.alive then return end
    local n, v = 0, 0
    for _ in pairs(state.index.items) do n=n+1 end
    for _ in pairs(state.index.visuals) do v=v+1 end
    counts.Text = string.format('Entradas: %d  ·  Con modelo 3D: %d',n,v)
    local found = Core.filter(state.index,state.query,state.kind,state.available)
    local pages = math.max(1,math.ceil(#found/8))
    state.page = math.min(state.page,pages)
    for i,b in ipairs(rowButtons) do
        local key = found[(state.page-1)*8+i]
        rowKeys[i] = key
        b.Visible = key ~= nil
        if key then
            local data = state.index.items[key]
            b.Text = (state.index.visuals[key] and '[3D] ' or '[--] ') .. tostring(data.ItemName or key)
            b.BackgroundColor3 = key == state.selected and Color3.fromRGB(62,62,68) or Color3.fromRGB(29,29,33)
        end
    end
    pageLabel.Text = state.page .. ' / ' .. pages .. ' · ' .. #found
    local key = state.selected
    if key then
        local record = state.index.visuals[key]
        local data = state.index.items[key]
        detail.Text = tostring(data.ItemName or key) .. '\nTipo: ' .. tostring(data.ItemType) .. '\n' ..
            (record and ('Fuente: ' .. record.source) or 'Sin modelo replicado localizado. El icono no contiene la geometría 3D.')
    end
end
connect(search:GetPropertyChangedSignal('Text'), function() state.query=search.Text state.page=1 refresh() end)
local openButton = button('Abrir Weapon Lab', function() panel.Visible=true end, gui)
openButton.Size, openButton.Position = UDim2.fromOffset(150,34), UDim2.new(0.5,-75,0,8)
openButton.Visible = false
connect(panel:GetPropertyChangedSignal('Visible'), function() openButton.Visible=not panel.Visible end)
local minimize = button('–', function() panel.Visible=false end, panel)
minimize.Size, minimize.Position = UDim2.fromOffset(32,30), UDim2.new(1,-80,0,8)
function state.close()
    if not state.alive then return end
    state.alive=false
    restore(true)
    disconnectAll(state.connections)
    for _, bucket in pairs(state.playerConnections) do
        disconnectAll(bucket.characterBucket)
        disconnectAll(bucket)
    end
    for thread in pairs(state.jobs) do pcall(task.cancel,thread) end
    for copy in pairs(state.snapshots) do copy:Destroy() end
    table.clear(state.snapshots)
    gui:Destroy()
    if env[singleton] == state then env[singleton]=nil end
end
local closeButton = button('×', state.close, panel)
closeButton.Size, closeButton.Position = UDim2.fromOffset(32,30), UDim2.new(1,-42,0,8)
local drag
connect(header.InputBegan, function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        drag={input=input, origin=input.Position, position=panel.Position}
    end
end)
connect(UIS.InputChanged, function(input)
    if not drag then return end
    if input == drag.input or input.UserInputType == Enum.UserInputType.MouseMovement then
        local delta=input.Position-drag.origin
        panel.Position=UDim2.new(drag.position.X.Scale,drag.position.X.Offset+delta.X,
            drag.position.Y.Scale,drag.position.Y.Offset+delta.Y)
    end
end)
connect(UIS.InputEnded, function(input) if drag and input == drag.input then drag=nil end end)
connect(player.CharacterRemoving, function() restore(true) end)
connect(Players.PlayerAdded, watchPlayer)
connect(Players.PlayerRemoving, function(owner)
    local bucket=state.playerConnections[owner]
    if bucket then disconnectAll(bucket.characterBucket) disconnectAll(bucket) state.playerConnections[owner]=nil end
end)
for _, owner in ipairs(Players:GetPlayers()) do watchPlayer(owner) end
refresh()
log('Weapon Lab v0.1 listo. Escanea primero; carga catálogo para asociar nombres.')
scan()
return state
