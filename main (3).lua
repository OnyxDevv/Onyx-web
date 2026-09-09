--[[
    NoxHub UI / Obsidian 2.0 — responsive + resizable
    Creator: Kev
    Native Roblox interface. No WindUI runtime, icon downloads or render loops.
    Compatible with the control API used by the supplied DUELS hub.
    Usage: local UI = require(module); local Window = UI:CreateWindow({...})
    GuiButton input: https://create.roblox.com/docs/reference/engine/classes/GuiButton
]]

local Players = game:GetService("Players")
local Input = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local TextService = game:GetService("TextService")
local Nox = { Version = "2.0.0", Brand = "NoxHub", Creator = "Kev", UIScale = 1 }
local C = {
    Window = Color3.fromRGB(9,9,9), Panel = Color3.fromRGB(14,14,14),
    Row = Color3.fromRGB(20,20,20), Field = Color3.fromRGB(11,11,11),
    Hover = Color3.fromRGB(29,29,29), Border = Color3.fromRGB(42,42,42),
    Text = Color3.fromRGB(242,242,242), Muted = Color3.fromRGB(157,157,157),
    Faint = Color3.fromRGB(103,103,103), White = Color3.fromRGB(255,255,255),
}
local FONT = Enum.Font.Gotham
local MEDIUM = Enum.Font.GothamMedium
local BOLD = Enum.Font.GothamBold
local function new(class, props, parent)
    local object = Instance.new(class)
    if object:IsA("GuiObject") then object.BorderSizePixel = 0 end
    if object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox") then
        object.Font = FONT
        object.TextSize = 13
        object.TextColor3 = C.Text
        object.Text = ""
    end
    if object:IsA("GuiButton") then object.AutoButtonColor = false end
    for key, value in pairs(props or {}) do object[key] = value end
    object.Parent = parent
    return object
end
local function round(object, radius)
    return new("UICorner", {CornerRadius = UDim.new(0, radius or 10)}, object)
end
local function stroke(object, color, thickness)
    return new("UIStroke", {Color = color or C.Border, Thickness = thickness or 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, object)
end
local function padding(object, x, y)
    return new("UIPadding", {PaddingLeft = UDim.new(0,x), PaddingRight = UDim.new(0,x),
        PaddingTop = UDim.new(0,y or x), PaddingBottom = UDim.new(0,y or x)}, object)
end
local function vertical(object, gap)
    return new("UIListLayout", {Padding = UDim.new(0,gap or 0),
        SortOrder = Enum.SortOrder.LayoutOrder}, object)
end
local function label(parent, text, size, color, props)
    local p = {Text = text or "", TextSize = size or 13, TextColor3 = color or C.Text,
        BackgroundTransparency = 1, TextXAlignment = Enum.TextXAlignment.Left,
        Size = UDim2.new(1,0,0,20)}
    for k,v in pairs(props or {}) do p[k] = v end
    return new("TextLabel", p, parent)
end
local function button(parent, text, props)
    local p = {Text = text or "", BackgroundColor3 = C.Row, Size = UDim2.fromOffset(36,36)}
    for k,v in pairs(props or {}) do p[k] = v end
    return new("TextButton", p, parent)
end
local function plain(text)
    return tostring(text or ""):gsub("<[^>]+>", "")
end
local function normalized(text)
    local s = string.lower(plain(text))
    for a,b in pairs({["á"]="a",["é"]="e",["í"]="i",["ó"]="o",["ú"]="u",["ñ"]="n",
        ["Á"]="a",["É"]="e",["Í"]="i",["Ó"]="o",["Ú"]="u",["Ñ"]="n"}) do s = s:gsub(a,b) end
    return s
end
local function invoke(callback, ...)
    if type(callback) ~= "function" then return end
    local ok, err = pcall(callback, ...)
    if not ok then warn("[NoxHub] " .. tostring(err)) end
end
local function disconnect(bucket)
    for _,connection in ipairs(bucket) do connection:Disconnect() end
    table.clear(bucket)
end
local function connect(window, signal, callback, bucket)
    local connection = signal:Connect(callback)
    table.insert(bucket or window._connections, connection)
    return connection
end
local function hover(window, target, base)
    connect(window, target.MouseEnter, function() target.BackgroundColor3 = C.Hover end)
    connect(window, target.MouseLeave, function() target.BackgroundColor3 = base or C.Row end)
end
local function line(parent, x, y, w, h, rotation, color)
    return new("Frame", {Position=UDim2.fromOffset(x,y), Size=UDim2.fromOffset(w,h),
        Rotation=rotation or 0, BackgroundColor3=color or C.Muted}, parent)
end
local function mark(parent, size, color)
    local holder = new("Frame", {BackgroundTransparency=1, Size=UDim2.fromOffset(size,size)}, parent)
    local diamond = new("Frame", {BackgroundTransparency=1, AnchorPoint=Vector2.new(.5,.5),
        Position=UDim2.fromScale(.5,.5), Size=UDim2.fromScale(.62,.62), Rotation=45}, holder)
    round(diamond, 3); stroke(diamond, color or C.Text, 2)
    local inset = new("Frame", {BackgroundTransparency=1, AnchorPoint=Vector2.new(.5,.5),
        Position=UDim2.fromScale(.5,.5), Size=UDim2.fromScale(.30,.30), Rotation=45}, holder)
    round(inset, 1); stroke(inset, color or C.Text, 1)
    return holder
end
local function icon(parent, kind)
    local h = new("Frame", {BackgroundTransparency=1, Size=UDim2.fromOffset(20,20)}, parent)
    if kind == "close" then line(h,3,9,14,1,45); line(h,3,9,14,1,-45)
    elseif kind == "menu" then for _,y in ipairs({5,10,15}) do line(h,3,y,14,1) end
    elseif kind == "search" then
        local circle = new("Frame", {Position=UDim2.fromOffset(3,2),Size=UDim2.fromOffset(10,10),BackgroundTransparency=1},h)
        round(circle,10); stroke(circle,C.Muted,1.4); line(h,12,13,6,1,45)
    elseif kind == "minus" then line(h,4,10,12,1)
    else
        local symbols = {Inicio="01",Aimbot="02",["Kill All"]="03",Visuales="04",Movimiento="05",
            AutoFarm="06",["Gráficos"]="07",Animaciones="08",Apariencia="09",["Generar Armas"]="10",["Configuración"]="11"}
        label(h, symbols[kind] or "·", 10, C.Muted, {Font=Enum.Font.Code,TextXAlignment=Enum.TextXAlignment.Center})
    end
    return h
end
local function scroll(parent, props)
    local p = {BackgroundTransparency=1, Size=UDim2.fromScale(1,1), CanvasSize=UDim2.new(),
        AutomaticCanvasSize=Enum.AutomaticSize.Y, ScrollingDirection=Enum.ScrollingDirection.Y,
        ScrollBarThickness=3, ScrollBarImageColor3=C.Faint, ElasticBehavior=Enum.ElasticBehavior.Never}
    for k,v in pairs(props or {}) do p[k]=v end
    return new("ScrollingFrame",p,parent)
end

local Tab = {}; Tab.__index = Tab
local Control = {}; Control.__index = Control

-- Measure wrapped copy once per width/content change. Rows never derive their
-- height from a child whose height is a fraction of that same row.
local function textHeight(text,size,font,width)
    if text=="" then return 0 end
    return math.max(size+3,math.ceil(TextService:GetTextSize(text,size,font,Vector2.new(math.max(30,width),100000)).Y)+3)
end
function Control:_resize(width)
    if self.Destroyed then return end
    local section=self.__type=="Section"
    local px=section and 2 or 12
    local py=section and 10 or 10
    local headWidth=math.max(40,width-px*2)
    local reserve=self.Reserve or 0
    local copyWidth=math.max(30,headWidth-reserve)
    local titleHeight=textHeight(self.Title,self.TitleLabel.TextSize,self.TitleLabel.Font,copyWidth)
    local descHeight=textHeight(self.Desc,self.DescLabel.TextSize,self.DescLabel.Font,copyWidth)
    local copyHeight=titleHeight+(descHeight>0 and 5+descHeight or 0)
    local headHeight=math.max(copyHeight,self.HeadMinimum or 0)
    self.Head.Position=UDim2.fromOffset(px,py)
    self.Head.Size=UDim2.new(1,-px*2,0,headHeight)
    self.Copy.Size=UDim2.new(1,-reserve,0,copyHeight)
    self.TitleLabel.Size=UDim2.new(1,0,0,titleHeight)
    self.DescLabel.Position=UDim2.fromOffset(0,titleHeight+5)
    self.DescLabel.Size=UDim2.new(1,0,0,descHeight)
    local y=py+headHeight
    if self.BodyField then
        local fieldHeight=44
        if self.ValueLabel then fieldHeight=math.max(44,textHeight(self.ValueLabel.Text,13,FONT,headWidth-46)+18) end
        self.BodyField.Position=UDim2.fromOffset(px,y+8)
        self.BodyField.Size=UDim2.new(1,-px*2,0,fieldHeight)
        y+=8+fieldHeight
    end
    if self.SliderArea then
        self.SliderArea.Position=UDim2.fromOffset(px,y+3)
        self.SliderArea.Size=UDim2.new(1,-px*2,0,40)
        self.Limits.Position=UDim2.fromOffset(px,y+43)
        self.Limits.Size=UDim2.new(1,-px*2,0,12)
        y+=55
    end
    if self.Rule then self.Rule.Position=UDim2.fromOffset(px,y+6); self.Rule.Size=UDim2.new(1,-px*2,0,1); y+=8 end
    local height=y+(section and 3 or py)
    self.ElementFrame.Size=UDim2.new(1,0,0,height)
    self.Slot.Size=UDim2.new(1,-6,0,height)
end
function Tab:_layout()
    if self.Window.Destroyed then return end
    local width=math.max(80,(self.Window.ContentWidth or 500)-8)
    local height=4
    for _,c in ipairs(self.Elements) do
        if not c.Destroyed then
            c:_resize(width)
            if c.Slot.Visible then height+=c.Slot.Size.Y.Offset+7 end
        end
    end
    self.Content.CanvasSize=UDim2.fromOffset(0,math.max(0,height-7))
    local viewportHeight=self.Content.AbsoluteSize.Y/self.Window.UIScale
    self.Content.CanvasPosition=Vector2.new(0,math.clamp(self.Content.CanvasPosition.Y,0,math.max(0,height-7-viewportHeight)))
end

function Control:SetTitle(value)
    self.Title = plain(value); self.TitleLabel.Text = self.Title
    self.Tab:_queueFilter(); return self
end
function Control:SetDesc(value)
    self.Desc = plain(value); self.DescLabel.Text = self.Desc
    self.DescLabel.Visible = self.Desc ~= ""; self.Tab:_queueFilter(); return self
end
function Control:SetVisible(value) self.ElementFrame.Visible = value == true; return self end
function Control:Show() return self:SetVisible(true) end
function Control:Hide() return self:SetVisible(false) end
function Control:Lock()
    self.Locked = true; self.TitleLabel.TextColor3 = C.Faint
    if self.Interactive then self.Interactive.Active = false end
    return self
end
function Control:Unlock()
    self.Locked = false; self.TitleLabel.TextColor3 = C.Text
    if self.Interactive then self.Interactive.Active = true end
    return self
end
function Control:Destroy()
    if self.Destroyed then return end
    self.Destroyed = true
    if self.Window._popupOwner == self then self.Window:_closePopup() end
    if self.Window._drag and self.Window._drag.Owner == self then self.Window:_endDrag() end
    self.Slot:Destroy(); self.Tab:_queueFilter()
end
function Control:SetValue(value, silent) return self:Set(value,silent) end
function Control:Get() return self.Value end

function Tab:_queueFilter()
    if self._filterQueued or self.Window.Destroyed then return end
    self._filterQueued = true
    task.defer(function()
        self._filterQueued = false
        if not self.Window.Destroyed then self:_filter() end
    end)
end
function Tab:_filter()
    local query = normalized(self.Query or "")
    local shown, total = 0,0
    local matchingGroups = {}
    local ordered=table.clone(self.Elements)
    table.sort(ordered,function(a,b) return a.Slot.LayoutOrder<b.Slot.LayoutOrder end)
    local groupTitle=""
    for _,c in ipairs(ordered) do
        if not c.Destroyed then
            if c.__type=="Section" then groupTitle=c.Title else c.GroupTitle=groupTitle end
        end
    end
    for _,c in ipairs(self.Elements) do
        if not c.Destroyed and c.__type ~= "Section" then
            local allowed = c.ElementFrame.Visible
            local matched = query == "" or string.find(normalized(c.Title .. " " .. c.Desc .. " " .. (c.GroupTitle or "")),query,1,true) ~= nil
            c.Slot.Visible = allowed and matched
            if allowed then total += 1 end
            if allowed and matched then shown += 1; matchingGroups[c.GroupTitle or ""] = true end
        end
    end
    for _,c in ipairs(self.Elements) do
        if not c.Destroyed and c.__type == "Section" then
            c.Slot.Visible = c.ElementFrame.Visible and (query == "" or matchingGroups[c.Title] == true)
        end
    end
    self.Empty.Visible = shown == 0
    if self.Window.CurrentTab == self then
        self.Window.CountLabel.Text = tostring(shown) .. (query ~= "" and " / " .. total or "") .. " opciones"
    end
    if self._lastQuery~=query then self.Content.CanvasPosition=Vector2.zero; self._lastQuery=query end
    self:_layout()
end
function Tab:_control(kind, options)
    local o = options or {}
    self._order += 1
    local slot = new("Frame", {Name="Slot",BackgroundTransparency=1,
        Size=UDim2.new(1,-4,0,0),LayoutOrder=self._order},self.Content)
    local row = new("Frame", {Name=kind,BackgroundColor3=C.Row,
        Size=UDim2.new(1,0,0,0),LayoutOrder=self._order},slot)
    round(row,10); stroke(row)
    local head = new("Frame", {Name="Heading",BackgroundTransparency=1,
        Size=UDim2.new(1,0,0,0),LayoutOrder=1},row)
    local copy = new("Frame", {Name="Copy",BackgroundTransparency=1,
        Size=UDim2.new(1,0,0,0)},head)
    local title = label(copy,plain(o.Title or kind),13,C.Text,{Font=MEDIUM,TextWrapped=true,
        TextYAlignment=Enum.TextYAlignment.Top,Size=UDim2.new(1,0,0,18),LayoutOrder=1})
    local desc = label(copy,plain(o.Desc),12,C.Muted,{TextWrapped=true,AutomaticSize=Enum.AutomaticSize.Y,
        Size=UDim2.new(1,0,0,0),LayoutOrder=2,Visible=o.Desc ~= nil and o.Desc ~= ""})
    local control = setmetatable({Title=plain(o.Title or kind),Desc=plain(o.Desc),__type=kind,
        Window=self.Window,Tab=self,ElementFrame=row,Slot=slot,Head=head,Copy=copy,
        TitleLabel=title,DescLabel=desc,Callback=o.Callback,GroupTitle=self._groupTitle,Locked=false},Control)
    desc.AutomaticSize=Enum.AutomaticSize.None; desc.TextYAlignment=Enum.TextYAlignment.Top
    table.insert(self.Elements,control)
    connect(self.Window,row:GetPropertyChangedSignal("Visible"),function() self:_queueFilter() end)
    connect(self.Window,row:GetPropertyChangedSignal("LayoutOrder"),function() slot.LayoutOrder=row.LayoutOrder; self:_queueFilter() end)
    if o.Locked then control:Lock() end
    self:_queueFilter()
    return control
end
function Tab:Section(options)
    local o = type(options)=="string" and {Title=options} or (options or {})
    self._groupTitle = plain(o.Title)
    local c = self:_control("Section",o)
    c.ElementFrame.BackgroundTransparency = 1
    c.ElementFrame.UIStroke:Destroy()
    c.TitleLabel.TextColor3=C.Muted; c.TitleLabel.TextSize=11; c.TitleLabel.Font=BOLD
    local rule = new("Frame",{Size=UDim2.new(1,0,0,1),BackgroundColor3=C.Border,LayoutOrder=3},c.ElementFrame)
    c.Rule = rule
    return c
end
function Tab:Paragraph(options)
    local c = self:_control("Paragraph",options)
    local o = options or {}
    if type(o.Image)=="string" and (o.Image:match("^rbxassetid://") or o.Image:match("^rbxthumb://")) then
        c.Reserve=62; c.HeadMinimum=48
        local picture=new("ImageLabel",{Name="Thumbnail",Image=o.Image,BackgroundColor3=C.Field,
            Position=UDim2.new(1,-48,0,0),Size=UDim2.fromOffset(48,48)},c.Head)
        round(picture,10)
    end
    function c:Set(value) return self:SetDesc(value) end
    return c
end
function Tab:Button(options)
    local c = self:_control("Button",options)
    c.Reserve=52; c.HeadMinimum=40
    local hit = button(c.Head,"→",{Name="Action",BackgroundColor3=C.Field,TextSize=18,
        Position=UDim2.new(1,-40,0,0),Size=UDim2.fromOffset(40,40)})
    round(hit,8); stroke(hit); hover(c.Window,hit,C.Field)
    -- The title and description are clickable too; nested field controls are separate.
    local titleHit=button(c.Copy,"",{Name="Activate",BackgroundTransparency=1,Size=UDim2.fromScale(1,1),ZIndex=3})
    local function activate() if not c.Locked and not c.Destroyed then invoke(c.Callback) end end
    connect(c.Window,hit.Activated,activate); connect(c.Window,titleHit.Activated,activate)
    c.Interactive=hit
    return c
end
function Tab:Toggle(options)
    local o = options or {}; local c = self:_control("Toggle",o)
    c.Reserve=66; c.HeadMinimum=44
    local target=button(c.Head,"",{Name="ToggleHit",BackgroundTransparency=1,
        Position=UDim2.new(1,-54,0,0),Size=UDim2.fromOffset(54,44)})
    local hit=new("Frame",{Name="Switch",BackgroundColor3=C.Border,
        Position=UDim2.fromOffset(5,9),Size=UDim2.fromOffset(44,26)},target)
    round(hit,8)
    local knob=new("Frame",{Name="Thumb",BackgroundColor3=C.Muted,Position=UDim2.fromOffset(4,4),
        Size=UDim2.fromOffset(18,18)},hit); round(knob,5)
    local tick=label(knob,"",11,C.Window,{TextXAlignment=Enum.TextXAlignment.Center,Size=UDim2.fromScale(1,1)})
    c.Interactive=target
    function c:Set(value,silent)
        if self.Destroyed then return self end
        value=value == true
        local changed=self.Value ~= value; self.Value=value
        hit.BackgroundColor3=value and C.White or C.Border
        knob.BackgroundColor3=value and C.Window or C.Muted
        knob.Position=UDim2.fromOffset(value and 22 or 4,4)
        tick.Text=value and "·" or ""; tick.TextColor3=C.White
        if changed and not silent then invoke(self.Callback,value) end
        return self
    end
    c:Set(o.Value == true,true)
    connect(c.Window,target.Activated,function() if not c.Locked then c:Set(not c.Value) end end)
    return c
end
local function field(parent, placeholder)
    local box=new("TextBox",{Name="Field",Text="",PlaceholderText=placeholder or "",
        PlaceholderColor3=C.Faint,BackgroundColor3=C.Field,ClearTextOnFocus=false,
        TextXAlignment=Enum.TextXAlignment.Left,Size=UDim2.new(1,0,0,38),LayoutOrder=2},parent)
    round(box,8); stroke(box); padding(box,11,0)
    return box
end
function Tab:Input(options)
    local o=options or {}; local c=self:_control("Input",o)
    local box=field(c.ElementFrame,o.Placeholder or "Escribe aquí…")
    c.Interactive=box; c.BodyField=box
    function c:Set(value,silent)
        value=tostring(value or ""); local changed=self.Value ~= value
        self.Value=value; box.Text=value
        if changed and not silent then invoke(self.Callback,value) end
        return self
    end
    c:Set(o.Value or o.Default or "",true)
    connect(c.Window,box.FocusLost,function()
        if c.Locked then box.Text=c.Value else c:Set(box.Text) end
    end)
    if o.Live then connect(c.Window,box:GetPropertyChangedSignal("Text"),function()
        if not c.Locked then c:Set(box.Text) end
    end) end
    return c
end
function Tab:Slider(options)
    local o=options or {}; local c=self:_control("Slider",o)
    local range=type(o.Value)=="table" and o.Value or {}
    local low=tonumber(range.Min or o.Min) or 0; local high=tonumber(range.Max or o.Max) or 100
    if high<low then low,high=high,low end
    local step=math.max(tonumber(o.Step) or 1,0.000001)
    local decimals=0
    while decimals<6 and math.abs(step*10^decimals-math.floor(step*10^decimals+.5))>.000001 do decimals+=1 end
    c.Min,c.Max,c.Step=low,high,step
    c.Reserve=88; c.HeadMinimum=40
    local box=field(c.Head,""); box.Name="Value"; box.Size=UDim2.fromOffset(76,40)
    box.Position=UDim2.new(1,-76,0,0); box.TextXAlignment=Enum.TextXAlignment.Center
    local area=button(c.ElementFrame,"",{Name="SliderArea",BackgroundTransparency=1,
        Size=UDim2.new(1,0,0,28),LayoutOrder=2})
    local track=new("Frame",{Name="Track",Position=UDim2.new(0,8,.5,-2),Size=UDim2.new(1,-16,0,4),BackgroundColor3=C.Border},area)
    round(track,2)
    local fill=new("Frame",{Name="Fill",Size=UDim2.fromScale(0,1),BackgroundColor3=C.Text},track); round(fill,2)
    local thumb=new("Frame",{Name="Thumb",AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(0,.5),
        Size=UDim2.fromOffset(14,14),BackgroundColor3=C.White},track); round(thumb,5)
    local limits=new("Frame",{Name="Limits",BackgroundTransparency=1,Size=UDim2.new(1,0,0,12),LayoutOrder=3},c.ElementFrame)
    c.SliderArea=area; c.Limits=limits
    label(limits,tostring(low),10,C.Faint,{Size=UDim2.fromScale(.5,1),Font=Enum.Font.Code})
    label(limits,tostring(high),10,C.Faint,{Size=UDim2.fromScale(.5,1),Position=UDim2.fromScale(.5,0),
        TextXAlignment=Enum.TextXAlignment.Right,Font=Enum.Font.Code})
    local function format(value) return string.format("%." .. decimals .. "f",value) end
    function c:Set(value,silent)
        if self.Destroyed then return self end
        value=tonumber(value)
        if not value or value~=value or value==math.huge or value==-math.huge then return self end
        value=math.clamp(low+math.floor((value-low)/step+.5)*step,low,high)
        value=tonumber(format(value)) or low
        local changed=self.Value~=value; self.Value=value; box.Text=format(value)
        local ratio=high>low and (value-low)/(high-low) or 0
        fill.Size=UDim2.fromScale(ratio,1); thumb.Position=UDim2.fromScale(ratio,.5)
        if changed and not silent then invoke(self.Callback,value) end
        return self
    end
    local function update(position)
        local width=track.AbsoluteSize.X
        if width>0 then c:Set(low+math.clamp((position.X-track.AbsolutePosition.X)/width,0,1)*(high-low)) end
    end
    connect(c.Window,area.InputBegan,function(input)
        if c.Locked then return end
        if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
            c.Window:_beginDrag(input,update,self.Content,c); update(input.Position)
        end
    end)
    connect(c.Window,box.FocusLost,function()
        if not c.Locked then c:Set(tonumber(box.Text)) end
        box.Text=format(c.Value)
    end)
    c.Interactive=area
    c:Set(range.Default or (type(o.Value)=="number" and o.Value) or o.Default or low,true)
    return c
end

function Tab:Dropdown(options)
    local o=options or {}; local c=self:_control("Dropdown",o)
    c.Values=table.clone(o.Values or {}); c.Multi=o.Multi==true or o.MultiSelect==true
    local hit=button(c.ElementFrame,"",{Name="Dropdown",BackgroundColor3=C.Field,
        Size=UDim2.new(1,0,0,38),LayoutOrder=2}); round(hit,8); stroke(hit)
    local valueLabel=label(hit,"",13,C.Text,{Position=UDim2.fromOffset(11,0),Size=UDim2.new(1,-42,1,0),TextWrapped=true})
    label(hit,"⌄",16,C.Muted,{Position=UDim2.new(1,-28,0,0),Size=UDim2.new(0,20,1,0),TextXAlignment=Enum.TextXAlignment.Center})
    c.Interactive=hit; c.BodyField=hit; c.ValueLabel=valueLabel
    function c:Set(value,silent,force)
        if self.Destroyed then return self end
        local changed
        if self.Multi then
            local arr=type(value)=="table" and table.clone(value) or (value and {value} or {})
            changed=table.concat(arr,"\0") ~= table.concat(type(self.Value)=="table" and self.Value or {},"\0")
            self.Value=arr; valueLabel.Text=#arr>0 and table.concat(arr,", ") or "Seleccionar…"
        else
            changed=self.Value~=value; self.Value=value
            valueLabel.Text=value~=nil and tostring(value) or "Seleccionar…"
        end
        if (changed or force) and not silent then invoke(self.Callback,self.Multi and table.clone(self.Value) or self.Value) end
        self.Tab:_queueFilter()
        return self
    end
    function c:Refresh(values)
        self.Values=table.clone(values or {})
        self._revision=(self._revision or 0)+1
        if self.Window._popupOwner==self and self._renderOptions then self._renderOptions() end
        return self
    end
    function c:Open()
        if self.Locked or self.Destroyed then return end
        local window=self.Window
        local panel=window:_popup(self.Title,360,410,self)
        local search=field(panel,"Buscar una opción…")
        search.Position=UDim2.fromOffset(16,54); search.Size=UDim2.new(1,-32,0,44)
        local list=scroll(panel,{Position=UDim2.fromOffset(16,108),Size=UDim2.new(1,-32,1,-140)})
        vertical(list,5)
        local hint=label(panel,"",10,C.Faint,{Position=UDim2.new(0,16,1,-29),Size=UDim2.new(1,-32,0,16)})
        local optionConnections={}
        window._popupCleanup=function() disconnect(optionConnections); self._renderOptions=nil end
        local function render()
            disconnect(optionConnections)
            for _,child in ipairs(list:GetChildren()) do if child:IsA("GuiObject") then child:Destroy() end end
            local query=normalized(search.Text); local count, matches=0,0
            for _,value in ipairs(self.Values) do
                if query=="" or string.find(normalized(value),query,1,true) then
                    matches+=1
                    if count<120 then
                        count+=1
                        local selected=self.Multi and table.find(self.Value,value)~=nil or (not self.Multi and self.Value==value)
                        local choiceHeight=math.max(44,textHeight(tostring(value),13,FONT,math.max(60,panel.AbsoluteSize.X-78))+18)
                        local choice=button(list,"",{Name="Option",Size=UDim2.new(1,-4,0,choiceHeight),LayoutOrder=count,
                            BackgroundColor3=selected and C.Text or C.Row})
                        round(choice,7)
                        label(choice,tostring(value),13,selected and C.Window or C.Text,{Position=UDim2.fromOffset(12,0),
                            Size=UDim2.new(1,-38,1,0),TextWrapped=true})
                        label(choice,selected and "✓" or "",12,C.Window,{Position=UDim2.new(1,-28,0,0),Size=UDim2.new(0,20,1,0)})
                        connect(window,choice.Activated,function()
                            if self.Multi then
                                local arr=table.clone(self.Value); local i=table.find(arr,value)
                                if i then table.remove(arr,i) else table.insert(arr,value) end
                                self:Set(arr)
                                if window._popupOwner==self then render() end
                            else
                                local revision=self._revision or 0
                                self:Set(value,false,true)
                                if window._popupOwner==self and revision==(self._revision or 0) then window:_closePopup() end
                            end
                        end,optionConnections)
                    end
                end
            end
            hint.Text=matches==0 and "Sin resultados" or (matches>120 and "120 de "..matches.." · Escribe para filtrar" or matches.." opciones")
        end
        self._renderOptions=render
        connect(window,search:GetPropertyChangedSignal("Text"),render,window._popupConnections)
        connect(window,panel:GetPropertyChangedSignal("AbsoluteSize"),render,window._popupConnections)
        render()
    end
    connect(c.Window,hit.Activated,function() c:Open() end)
    c:Set(o.Value or o.Default or (c.Multi and {} or nil),true)
    return c
end
function Tab:Colorpicker(options)
    local o=options or {}; local c=self:_control("Colorpicker",o)
    c.Reserve=62; c.HeadMinimum=44
    local hit=button(c.Head,"",{Name="Color",Position=UDim2.new(1,-46,0,0),Size=UDim2.fromOffset(46,44)})
    round(hit,8); stroke(hit)
    c.Interactive=hit
    function c:Set(value,silent)
        if typeof(value)~="Color3" then return self end
        local changed=self.Value~=value; self.Value=value; hit.BackgroundColor3=value
        if self._updateColor then self._updateColor() end
        if changed and not silent then invoke(self.Callback,value) end
        return self
    end
    function c:Open()
        if self.Locked then return end
        local window=self.Window
        local panel=window:_popup(self.Title,330,340,self)
        local body=scroll(panel,{Name="ColorBody",Position=UDim2.fromOffset(16,54),Size=UDim2.new(1,-32,1,-68),
            AutomaticCanvasSize=Enum.AutomaticSize.None,CanvasSize=UDim2.fromOffset(0,270)})
        local preview=new("Frame",{Position=UDim2.fromOffset(0,0),Size=UDim2.new(1,-6,0,44),BackgroundColor3=self.Value},body)
        round(preview,9)
        local hex=field(body,"#FFFFFF"); hex.Position=UDim2.fromOffset(0,56); hex.Size=UDim2.new(1,-6,0,44)
        local bars={}
        for i,name in ipairs({"R","G","B"}) do
            local y=112+(i-1)*50
            label(body,name,11,C.Muted,{Position=UDim2.fromOffset(0,y),Size=UDim2.fromOffset(22,44),Font=Enum.Font.Code})
            local area=button(body,"",{Name=name,BackgroundTransparency=1,Position=UDim2.fromOffset(28,y),Size=UDim2.new(1,-76,0,44)})
            local track=new("Frame",{Position=UDim2.new(0,0,.5,-2),Size=UDim2.new(1,0,0,4),BackgroundColor3=C.Border},area); round(track,2)
            local fill=new("Frame",{Size=UDim2.fromScale(0,1),BackgroundColor3=C.Text},track); round(fill,2)
            local value=label(body,"",11,C.Muted,{Position=UDim2.new(1,-40,0,y),Size=UDim2.fromOffset(34,44),TextXAlignment=Enum.TextXAlignment.Right})
            bars[i]={Fill=fill,Label=value}
            local function update(position)
                if area.AbsoluteSize.X<=0 then return end
                local rgb={self.Value.R,self.Value.G,self.Value.B}
                rgb[i]=math.clamp((position.X-area.AbsolutePosition.X)/area.AbsoluteSize.X,0,1)
                self:Set(Color3.new(rgb[1],rgb[2],rgb[3]))
            end
            connect(window,area.InputBegan,function(input)
                if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
                    window:_beginDrag(input,update,body,self); update(input.Position)
                end
            end,window._popupConnections)
        end
        self._updateColor=function()
            preview.BackgroundColor3=self.Value
            hex.Text="#"..self.Value:ToHex():upper()
            for i,v in ipairs({self.Value.R,self.Value.G,self.Value.B}) do
                bars[i].Fill.Size=UDim2.fromScale(v,1); bars[i].Label.Text=tostring(math.floor(v*255+.5))
            end
        end
        window._popupCleanup=function() self._updateColor=nil end
        connect(window,hex.FocusLost,function()
            local value=hex.Text:gsub("#","")
            if #value==6 and value:match("^%x+$") then self:Set(Color3.fromHex(value)) else self._updateColor() end
        end,window._popupConnections)
        self._updateColor()
    end
    connect(c.Window,hit.Activated,function() c:Open() end)
    c:Set(o.Default or o.Value or C.White,true)
    return c
end
function Tab:Select() self.Window:SelectTab(self); return self end
function Tab:LockAll() for _,c in ipairs(self.Elements) do c:Lock() end end
function Tab:UnlockAll() for _,c in ipairs(self.Elements) do c:Unlock() end end

local DESCRIPTIONS = {
    Inicio="Tu espacio. Todo bajo control.", Aimbot="Organiza tus ajustes de precisión y selección.",
    ["Kill All"]="Controles y ajustes de esta función.", Visuales="Elige qué información quieres ver.",
    Movimiento="Personaliza el movimiento y sus controles.", AutoFarm="Configura tus acciones automáticas.",
    ["Gráficos"]="Ajusta el ambiente, la iluminación y los efectos.",
    Animaciones="Combina paquetes y movimientos a tu gusto.", Apariencia="Tu avatar, a tu manera.",
    ["Configuración"]="Tu interfaz y tus configuraciones guardadas.", ["Generar Armas"]="Organiza tus opciones de inventario.",
}
function Nox:CreateWindow(options)
    local o=options or {}
    if self.Window and not self.Window.Destroyed then self.Window:Destroy() end
    local player=Players.LocalPlayer
    assert(player,"NoxHub UI must run on the client")
    local parent=player:WaitForChild("PlayerGui")
    local env=(getgenv and getgenv()) or _G
    if env.__NOX_UI and env.__NOX_UI.Destroy then pcall(function() env.__NOX_UI:Destroy() end) end
    local w={_connections={},_popupConnections={},_onDestroy={},_onOpen={},_onClose={},Tabs={},
        Groups={},Opened=true,Destroyed=false,Compact=false,ToggleKey=o.ToggleKey or Enum.KeyCode.RightShift,
        Title=plain(o.Title or "NoxHub"),Author=o.Author or "by Kev",UIScale=1,_navOrder=0}
    self.Window=w; env.__NOX_UI=w
    local gui=new("ScreenGui",{Name="NoxHubUI",ResetOnSpawn=false,IgnoreGuiInset=false,
        DisplayOrder=100,ZIndexBehavior=Enum.ZIndexBehavior.Sibling},parent)
    -- Only the launcher ignores system insets: its top-left corner can reach Y=0.
    local launcherGui=new("ScreenGui",{Name="NoxHubLauncher",ResetOnSpawn=false,IgnoreGuiInset=true,
        DisplayOrder=101,ZIndexBehavior=Enum.ZIndexBehavior.Sibling},parent)
    pcall(function()
        launcherGui.ScreenInsets=Enum.ScreenInsets.None
        launcherGui.ClipToDeviceSafeArea=false
        launcherGui.SafeAreaCompatibility=Enum.SafeAreaCompatibility.None
    end)
    local launcherSurface=new("Frame",{Name="FullScreen",BackgroundTransparency=1,Size=UDim2.fromScale(1,1)},launcherGui)
    w.LauncherGui=launcherGui
    self.ScreenGui=gui; w.ScreenGui=gui
    -- Inset-aware bounds are shared by popups, dragging and responsive layout.
    local surface=new("Frame",{Name="Surface",BackgroundTransparency=1,Size=UDim2.fromScale(1,1)},gui)
    local root=new("Frame",{Name="NoxPanel",BackgroundColor3=Color3.fromRGB(7,7,7),AnchorPoint=Vector2.new(.5,.5),
        Position=UDim2.fromScale(.5,.5),Size=UDim2.fromOffset(820,590),ClipsDescendants=true},surface)
    round(root,22); stroke(root,Color3.fromRGB(58,58,58))
    local rootGradient=new("UIGradient",{Rotation=22,Color=ColorSequence.new({
        ColorSequenceKeypoint.new(0,Color3.fromRGB(5,5,5)),
        ColorSequenceKeypoint.new(.52,Color3.fromRGB(10,10,10)),
        ColorSequenceKeypoint.new(1,Color3.fromRGB(4,4,4))
    })},root)
    local scale=new("UIScale",{Scale=1},root); self.UIScaleObj=scale

    -- Fondo Nox: geométrico, monocromo y muy tenue para no competir con los controles.
    local backdrop=new("Frame",{Name="NoxBackdrop",BackgroundTransparency=1,Size=UDim2.fromScale(1,1),ZIndex=1},root)
    local glowA=new("Frame",{Name="SoftGlowA",AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.76,.30),
        Size=UDim2.fromScale(.66,.74),BackgroundColor3=Color3.fromRGB(24,24,24),BackgroundTransparency=.58,Rotation=-16,ZIndex=1},backdrop)
    round(glowA,80)
    new("UIGradient",{Rotation=35,Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.12),NumberSequenceKeypoint.new(1,1)})},glowA)
    local glowB=new("Frame",{Name="SoftGlowB",AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.20,.88),
        Size=UDim2.fromScale(.52,.46),BackgroundColor3=Color3.fromRGB(20,20,20),BackgroundTransparency=.68,Rotation=18,ZIndex=1},backdrop)
    round(glowB,80)
    new("UIGradient",{Rotation=205,Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.2),NumberSequenceKeypoint.new(1,1)})},glowB)
    local watermark=label(backdrop,"N  /  X",118,Color3.fromRGB(255,255,255),{
        AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.70,.63),Size=UDim2.fromScale(.55,.42),
        Font=BOLD,TextTransparency=.965,TextXAlignment=Enum.TextXAlignment.Center,TextYAlignment=Enum.TextYAlignment.Center,Rotation=-12,ZIndex=1})
    for i=1,6 do
        local v=new("Frame",{Name="GridV",Position=UDim2.new(i/7,0,0,0),Size=UDim2.new(0,1,1,0),
            BackgroundColor3=Color3.fromRGB(255,255,255),BackgroundTransparency=.972,ZIndex=1},backdrop)
    end
    for i=1,4 do
        local h=new("Frame",{Name="GridH",Position=UDim2.new(0,0,i/5,0),Size=UDim2.new(1,0,0,1),
            BackgroundColor3=Color3.fromRGB(255,255,255),BackgroundTransparency=.978,ZIndex=1},backdrop)
    end
    local top=new("Frame",{Name="Topbar",BackgroundTransparency=1,Size=UDim2.new(1,0,0,70),ZIndex=5},root)
    local logo=mark(top,32); logo.Position=UDim2.fromOffset(20,18)
    local brand=label(top,"NOX",19,C.Text,{Position=UDim2.fromOffset(62,14),Size=UDim2.fromOffset(112,26),Font=BOLD})
    local subtitle=label(top,"N O X  /  "..tostring(o.Subtitle or "DUELS"),9,C.Faint,{Position=UDim2.fromOffset(63,41),Size=UDim2.fromOffset(180,14)})
    local author=label(top,w.Author,11,C.Muted,{Position=UDim2.new(1,-248,0,27),Size=UDim2.fromOffset(104,20),TextXAlignment=Enum.TextXAlignment.Right})
    local controls=new("Frame",{BackgroundTransparency=1,Position=UDim2.new(1,-128,0,18),Size=UDim2.fromOffset(110,34)},top)
    local menu=button(controls,"",{Name="Menu",Size=UDim2.fromOffset(32,32),Visible=false}); round(menu,8)
    icon(menu,"menu").Position=UDim2.fromOffset(6,6)
    local minimize=button(controls,"",{Name="Minimize",Position=UDim2.fromOffset(38,0),Size=UDim2.fromOffset(32,32)}); round(minimize,8)
    icon(minimize,"minus").Position=UDim2.fromOffset(6,6)
    local close=button(controls,"",{Name="Close",Position=UDim2.fromOffset(76,0),Size=UDim2.fromOffset(32,32)}); round(close,8)
    icon(close,"close").Position=UDim2.fromOffset(6,6)
    hover(w,menu); hover(w,minimize); hover(w,close)
    local topRule=line(root,18,69,784,1,0,C.Border); topRule.Size=UDim2.new(1,-36,0,1)
    local sidebar=new("Frame",{Name="Navigation",BackgroundColor3=C.Panel,Position=UDim2.fromOffset(14,82),
        Size=UDim2.new(0,176,1,-118),ZIndex=12},root); round(sidebar,12)
    local nav=scroll(sidebar,{Name="Tabs",Position=UDim2.fromOffset(8,10),Size=UDim2.new(1,-16,1,-58),ScrollBarThickness=0})
    vertical(nav,5)
    local navFooter=label(sidebar,"NOX  /  OBSIDIAN",9,C.Faint,{Position=UDim2.new(0,14,1,-32),Size=UDim2.new(1,-28,0,18),Font=Enum.Font.Code})
    local drawerShade=button(root,"",{Name="DrawerBackdrop",BackgroundColor3=Color3.new(),BackgroundTransparency=.3,
        Position=UDim2.fromOffset(0,70),Size=UDim2.new(1,0,1,-70),Visible=false,ZIndex=11})
    local content=new("Frame",{Name="Content",BackgroundTransparency=1,Position=UDim2.fromOffset(210,84),Size=UDim2.new(1,-232,1,-120),ZIndex=4},root)
    local pageTitle=label(content,"Inicio",26,C.Text,{Size=UDim2.new(1,-130,0,34),Font=BOLD})
    local pageDesc=label(content,DESCRIPTIONS.Inicio,12,C.Muted,{Position=UDim2.fromOffset(0,42),Size=UDim2.new(1,0,0,32),TextWrapped=true,TextYAlignment=Enum.TextYAlignment.Top})
    local count=label(content,"0 opciones",10,C.Faint,{Position=UDim2.new(1,-124,0,9),Size=UDim2.fromOffset(124,18),TextXAlignment=Enum.TextXAlignment.Right,Font=Enum.Font.Code})
    w.CountLabel=count
    local searchBox=new("Frame",{Name="SearchBox",BackgroundColor3=C.Field,
        Position=UDim2.fromOffset(0,84),Size=UDim2.new(1,0,0,44)},content)
    round(searchBox,8); stroke(searchBox)
    local search=new("TextBox",{Name="Search",BackgroundTransparency=1,ClearTextOnFocus=false,
        PlaceholderText="Buscar en esta pestaña…",PlaceholderColor3=C.Faint,TextXAlignment=Enum.TextXAlignment.Left,
        Position=UDim2.fromOffset(36,0),Size=UDim2.new(1,-76,1,0)},searchBox)
    icon(searchBox,"search").Position=UDim2.new(0,10,.5,-10)
    local clear=button(searchBox,"×",{Name="Clear",BackgroundTransparency=1,Position=UDim2.new(1,-40,0,0),Size=UDim2.new(0,40,1,0),Visible=false})
    local pages=new("Frame",{Name="Pages",BackgroundTransparency=1,Position=UDim2.fromOffset(0,136),Size=UDim2.new(1,0,1,-136)},content)
    local footer=label(root,"NOXHUB",9,C.Faint,{Position=UDim2.new(0,22,1,-28),Size=UDim2.new(.6,0,0,16),Font=Enum.Font.Code})
    local shortcut=label(root,"RSHIFT  /  MOSTRAR U OCULTAR",9,C.Faint,{Position=UDim2.new(.4,0,1,-28),Size=UDim2.new(.6,-22,0,16),TextXAlignment=Enum.TextXAlignment.Right,Font=Enum.Font.Code})
    local openButton=button(launcherSurface,"",{Name="OpenNoxHub",Position=UDim2.new(0,18,.5,-20),Size=UDim2.fromOffset(154,40),BackgroundColor3=C.Window,ZIndex=20})
    round(openButton,12); stroke(openButton,Color3.fromRGB(66,66,66))
    mark(openButton,24).Position=UDim2.fromOffset(8,8)
    local openLabel=label(openButton,"Abrir NoxHub",12,C.Text,{Position=UDim2.fromOffset(40,0),Size=UDim2.new(1,-47,1,0),Font=MEDIUM})
    w.OpenButton=openButton; w.UIElements={Main=root,Title=brand,SideBar=sidebar,MainBar=content,Pages=pages,Search=searchBox,Topbar=top}
    local desired=o.Size or UDim2.fromOffset(820,590)
    w._desiredWidth=desired.X.Offset>0 and desired.X.Offset or 820
    w._desiredHeight=desired.Y.Offset>0 and desired.Y.Offset or 590
    w.Resizable=o.Resizable~=false
    local minSize=o.MinSize or Vector2.new(390,320)
    w._minWidth=math.max(300,tonumber(minSize.X) or 390)
    w._minHeight=math.max(260,tonumber(minSize.Y) or 320)

    local resizeHandles={}
    local function resizeHandle(name,xScale,yScale,xAnchor,yAnchor)
        local hit=button(root,"",{Name=name,AnchorPoint=Vector2.new(xAnchor,yAnchor),Position=UDim2.fromScale(xScale,yScale),
            Size=UDim2.fromOffset(30,30),BackgroundTransparency=1,ZIndex=40,Visible=w.Resizable})
        local xDir=xScale==0 and 1 or -1
        local yDir=yScale==0 and 1 or -1
        local ox=xScale==0 and 5 or 15
        local oy=yScale==0 and 5 or 15
        local h=line(hit,ox,oy,10,1,0,Color3.fromRGB(118,118,118)); h.ZIndex=41
        local v=line(hit,ox,oy,10,1,90,Color3.fromRGB(118,118,118)); v.ZIndex=41
        if xDir<0 then h.Position=UDim2.fromOffset(5,oy) end
        if yDir<0 then v.Position=UDim2.fromOffset(ox,5) end
        table.insert(resizeHandles,{Hit=hit,X=xScale==0 and -1 or 1,Y=yScale==0 and -1 or 1})
        return hit
    end
    resizeHandle("ResizeTL",0,0,0,0)
    resizeHandle("ResizeTR",1,0,1,0)
    resizeHandle("ResizeBL",0,1,0,1)
    resizeHandle("ResizeBR",1,1,1,1)
    function w:_endDrag()
        local d=self._drag; self._drag=nil
        if d and d.Scroll and d.Scroll.Parent then d.Scroll.ScrollingEnabled=d.WasScrolling end
    end
    function w:_beginDrag(input,update,scroller,owner)
        self:_endDrag()
        self._drag={Input=input,Update=update,Scroll=scroller,Owner=owner,WasScrolling=scroller and scroller.ScrollingEnabled}
        if scroller then scroller.ScrollingEnabled=false end
    end
    function w:_closePopup()
        self:_endDrag(); disconnect(self._popupConnections)
        if self._popupCleanup then self._popupCleanup(); self._popupCleanup=nil end
        if self._popupLayer then self._popupLayer:Destroy(); self._popupLayer=nil end
        self._popupOwner=nil
        launcherGui.Enabled=true
    end
    function w:_popup(title,width,height,owner)
        self:_closePopup()
        local layer=button(surface,"",{Name="ModalBackdrop",BackgroundColor3=Color3.new(),BackgroundTransparency=.3,Size=UDim2.fromScale(1,1),ZIndex=50})
        launcherGui.Enabled=false
        local panel=button(layer,"",{Name="Modal",BackgroundColor3=C.Panel,AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromOffset(width,height),ZIndex=2,ClipsDescendants=true})
        round(panel,16); stroke(panel,Color3.fromRGB(66,66,66))
        label(panel,title,14,C.Text,{Position=UDim2.fromOffset(16,17),Size=UDim2.new(1,-62,0,22),Font=BOLD,TextTruncate=Enum.TextTruncate.AtEnd})
        local dismiss=button(panel,"×",{Position=UDim2.new(1,-50,0,7),Size=UDim2.fromOffset(40,40),TextSize=18}); round(dismiss,8)
        local function fit()
            panel.Size=UDim2.fromOffset(math.max(100,math.min(width,surface.AbsoluteSize.X-24)),math.max(100,math.min(height,surface.AbsoluteSize.Y-24)))
        end
        connect(self,layer.Activated,function() self:_closePopup() end,self._popupConnections)
        connect(self,dismiss.Activated,function() self:_closePopup() end,self._popupConnections)
        connect(self,surface:GetPropertyChangedSignal("AbsoluteSize"),fit,self._popupConnections)
        self._popupLayer=layer; self._popupOwner=owner; fit()
        return panel
    end
    function w:_drawer(value)
        self._drawerOpen=value==true
        sidebar.Visible=not self.Compact or self._drawerOpen
        drawerShade.Visible=self.Compact and self._drawerOpen
    end
    local function clampRoot()
        local bounds=surface.AbsoluteSize; local size=root.AbsoluteSize
        if bounds.X<=0 or bounds.Y<=0 then return end
        local x=root.Position.X.Scale*bounds.X+root.Position.X.Offset
        local y=root.Position.Y.Scale*bounds.Y+root.Position.Y.Offset
        local minX=math.min(size.X/2+6,bounds.X/2); local minY=math.min(size.Y/2+6,bounds.Y/2)
        root.Position=UDim2.fromOffset(math.clamp(x,minX,math.max(minX,bounds.X-minX)),math.clamp(y,minY,math.max(minY,bounds.Y-minY)))
    end
    local function clampLauncher()
        local bounds=launcherSurface.AbsoluteSize; local size=openButton.AbsoluteSize
        local position=openButton.Position
        openButton.Position=UDim2.fromOffset(math.clamp(position.X.Scale*bounds.X+position.X.Offset,0,math.max(0,bounds.X-size.X)),
            math.clamp(position.Y.Scale*bounds.Y+position.Y.Offset,0,math.max(0,bounds.Y-size.Y)))
    end
    local function fit()
        if w.Destroyed then return end
        local bounds=surface.AbsoluteSize
        if bounds.X<1 or bounds.Y<1 then return end
        local maxWidth=math.max(280,(bounds.X-12)/w.UIScale)
        local maxHeight=math.max(240,(bounds.Y-12)/w.UIScale)
        local minWidth=math.min(w._minWidth,maxWidth)
        local minHeight=math.min(w._minHeight,maxHeight)
        local width=math.clamp(w._desiredWidth,minWidth,maxWidth)
        local height=math.clamp(w._desiredHeight,minHeight,maxHeight)
        root.Size=UDim2.fromOffset(width,height)
        w.Short=height<470
        w.Narrow=width<520
        w.Compact=width<670 or w.Short
        local tight=w.Compact or Input.TouchEnabled
        local topHeight=tight and 54 or 70
        local contentTop=topHeight+(tight and 9 or 14)
        local left=w.Compact and 12 or 204
        local right=w.Compact and 12 or 20
        local bottom=w.Short and 10 or 30
        w.ContentWidth=math.max(120,width-left-right)
        top.Size=UDim2.new(1,0,0,topHeight)
        logo.Position=UDim2.fromOffset(tight and 14 or 20,tight and 11 or 18)
        brand.Position=UDim2.fromOffset(tight and 54 or 62,tight and 14 or 14)
        brand.TextSize=tight and 17 or 19
        brand.Visible=not w.Narrow or width>=430
        logo.Visible=true
        subtitle.Visible=not tight
        controls.Position=UDim2.new(1,-146,0,tight and 7 or 15)
        controls.Size=UDim2.fromOffset(132,40)
        for index,control in ipairs({menu,minimize,close}) do
            control.Position=UDim2.fromOffset((index-1)*44,0); control.Size=UDim2.fromOffset(40,40)
            control:FindFirstChildOfClass("Frame").Position=UDim2.fromOffset(10,10)
        end
        topRule.Position=UDim2.fromOffset(14,topHeight-1); topRule.Size=UDim2.new(1,-28,0,1)
        menu.Visible=w.Compact; author.Visible=not tight and width>=700
        author.Position=UDim2.new(1,-266,0,27)
        sidebar.Position=UDim2.fromOffset(14,contentTop)
        sidebar.Size=UDim2.new(0,w.Compact and math.min(242,width-24) or 176,1,-contentTop-bottom)
        nav.Size=UDim2.new(1,-16,1,w.Short and -20 or -58)
        nav.ScrollBarThickness=3; navFooter.Visible=not w.Short
        drawerShade.Position=UDim2.fromOffset(0,topHeight); drawerShade.Size=UDim2.new(1,0,1,-topHeight)
        content.Position=UDim2.fromOffset(left,contentTop)
        content.Size=UDim2.new(1,-left-right,1,-contentTop-bottom)
        pageDesc.Visible=not tight and height>=500; count.Visible=not tight and width>=720
        pageTitle.TextSize=tight and 21 or 26
        pageTitle.TextTruncate=Enum.TextTruncate.AtEnd
        local pagesY
        if w.Short and w.ContentWidth>=520 then
            pageTitle.Size=UDim2.new(.42,-12,0,44)
            searchBox.Position=UDim2.new(.42,0,0,0); searchBox.Size=UDim2.new(.58,0,0,44)
            pagesY=54
        elseif tight then
            pageTitle.Size=UDim2.new(1,0,0,28)
            searchBox.Position=UDim2.fromOffset(0,34); searchBox.Size=UDim2.new(1,0,0,44)
            pagesY=88
        else
            pageTitle.Size=UDim2.new(1,-130,0,34)
            searchBox.Position=UDim2.fromOffset(0,84); searchBox.Size=UDim2.new(1,0,0,44)
            pagesY=140
        end
        pages.Position=UDim2.fromOffset(0,pagesY); pages.Size=UDim2.new(1,0,1,-pagesY)
        footer.Visible=not w.Short
        shortcut.Visible=not tight and width>=700
        w:_drawer(false); clampRoot(); clampLauncher()
        for _,tab in ipairs(w.Tabs) do tab:_queueFilter() end
    end
    function w:SelectTab(which)
        if self.Destroyed then return end
        local target=type(which)=="number" and self.Tabs[which] or which
        if type(which)=="string" then for _,tab in ipairs(self.Tabs) do if tab.Title==which then target=tab; break end end end
        if type(target)~="table" or target.Window~=self then return end
        if self.CurrentTab then self.CurrentTab.Query=search.Text end
        self:_closePopup()
        self.CurrentTab=target
        for _,tab in ipairs(self.Tabs) do
            local selected=tab==target
            tab.Page.Visible=selected
            tab.NavButton.BackgroundColor3=selected and C.Text or C.Panel
            tab.NavTitle.TextColor3=selected and C.Window or C.Muted
            tab.Number.TextColor3=selected and C.Window or C.Faint
        end
        pageTitle.Text=target.Title; pageDesc.Text=target.Desc
        search.Text=target.Query or ""; clear.Visible=search.Text~=""
        self:_drawer(false); target:_filter()
        return target
    end
    function w:_tab(options,holder)
        local opt=options or {}; local title=plain(opt.Title or "Pestaña")
        local index=#self.Tabs+1
        local tab=setmetatable({Window=self,Title=title,Desc=opt.Desc or DESCRIPTIONS[title] or "Personaliza tus opciones.",
            Elements={},_order=0,Query="",Index=index},Tab)
        local page=new("Frame",{Name=title,BackgroundTransparency=1,Size=UDim2.fromScale(1,1),Visible=false},pages)
        local list=scroll(page,{Name="Options",AutomaticCanvasSize=Enum.AutomaticSize.None}); vertical(list,7); padding(list,1,2)
        local empty=label(page,"Sin coincidencias. Prueba otra búsqueda.",12,C.Muted,{Position=UDim2.fromOffset(12,18),Size=UDim2.new(1,-24,0,50),TextWrapped=true,Visible=false})
        local navButton=button(holder or nav,"",{Name=title,Size=UDim2.new(1,0,0,44),BackgroundColor3=C.Panel,LayoutOrder=index})
        round(navButton,8)
        local glyph=icon(navButton,title); glyph.Position=UDim2.fromOffset(8,12)
        local titleLabel=label(navButton,title,12,C.Muted,{Position=UDim2.fromOffset(35,0),Size=UDim2.new(1,-43,1,0),Font=MEDIUM,TextTruncate=Enum.TextTruncate.AtEnd})
        tab.Page,tab.Content,tab.Empty=page,list,empty; tab.NavButton,tab.NavTitle=navButton,titleLabel
        tab.Number=glyph:FindFirstChildOfClass("TextLabel")
        table.insert(self.Tabs,tab)
        connect(self,navButton.Activated,function() self:SelectTab(tab) end)
        connect(self,navButton.MouseEnter,function() if self.CurrentTab~=tab then navButton.BackgroundColor3=C.Row end end)
        connect(self,navButton.MouseLeave,function() if self.CurrentTab~=tab then navButton.BackgroundColor3=C.Panel end end)
        connect(self,list:GetPropertyChangedSignal("AbsoluteSize"),function() tab:_queueFilter() end)
        if not self.CurrentTab then self:SelectTab(tab) end
        return tab
    end
    function w:Tab(options) return self:_tab(options) end
    function w:Section(options)
        local opt=options or {}; self._navOrder+=1
        local group=new("Frame",{Name=plain(opt.Title),BackgroundTransparency=1,Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,LayoutOrder=self._navOrder},nav)
        vertical(group,5)
        local heading=label(group,string.upper(plain(opt.Title or "GENERAL")),9,C.Faint,{Size=UDim2.new(1,-8,0,25),Font=BOLD,LayoutOrder=0,TextWrapped=true})
        padding(heading,8,0)
        local items=new("Frame",{Name="Items",BackgroundTransparency=1,Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,LayoutOrder=1},group)
        vertical(items,3)
        local section={Window=self,ElementFrame=group}
        function section:Tab(config) return self.Window:_tab(config,items) end
        function section:Open() items.Visible=true; return self end
        function section:Close() items.Visible=false; return self end
        table.insert(self.Groups,section)
        return section
    end
    function w:SetTitle(title) self.Title=plain(title); footer.Text=self.Title end
    function w:SetAuthor(text) self.Author=plain(text); author.Text=self.Author end
    function w:SetSize(size)
        self._desiredWidth=math.max(1,size.X.Offset); self._desiredHeight=math.max(1,size.Y.Offset); fit(); return self
    end
    function w:GetSize() return Vector2.new(self._desiredWidth,self._desiredHeight) end
    function w:SetResizable(value)
        self.Resizable=value~=false
        for _,info in ipairs(resizeHandles) do info.Hit.Visible=self.Resizable end
        return self
    end
    function w:SetUIScale(value)
        self.UIScale=math.clamp(tonumber(value) or 1,.7,1.4); scale.Scale=self.UIScale
        Nox.UIScale=self.UIScale; fit(); return self
    end
    function w:GetUIScale() return self.UIScale end
    function w:SetToTheCenter() root.Position=UDim2.fromScale(.5,.5); clampRoot(); return self end
    function w:SetToggleKey(key) self.ToggleKey=key; return self end
    function w:SetOpenButtonVisible(value)
        self._openButtonEnabled=value==true
        openButton.Visible=self._openButtonEnabled or (Input.TouchEnabled and not self.Opened)
        return self
    end
    function w:EditOpenButton(config)
        if config.Enabled~=nil then self:SetOpenButtonVisible(config.Enabled) end
        if config.Title then openLabel.Text=plain(config.Title) end
        return self
    end
    function w:OnDestroy(callback) table.insert(self._onDestroy,callback); return self end
    function w:OnOpen(callback) table.insert(self._onOpen,callback); return self end
    function w:OnClose(callback) table.insert(self._onClose,callback); return self end
    function w:Open()
        if self.Destroyed then return self end
        local changed=not self.Opened; self.Opened=true; root.Visible=true
        openButton.Visible=self._openButtonEnabled~=false
        if changed then for _,callback in ipairs(self._onOpen) do invoke(callback) end end
        return self
    end
    function w:Close()
        if self.Destroyed then return self end
        local changed=self.Opened; self.Opened=false; root.Visible=false; self:_closePopup()
        if Input.TouchEnabled then openButton.Visible=true end
        if changed then for _,callback in ipairs(self._onClose) do invoke(callback) end end
        return self
    end
    function w:Toggle() if self.Opened then return self:Close() else return self:Open() end end
    function w:Destroy()
        if self.Destroyed then return end
        self.Destroyed=true; self:_closePopup(); disconnect(self._connections)
        for _,callback in ipairs(self._onDestroy) do invoke(callback) end
        gui:Destroy(); launcherGui:Destroy()
        if env.__NOX_UI==self then env.__NOX_UI=nil end
        if Nox.Window==self then Nox.Window=nil end
    end
    function w:Dialog(config)
        local cfg=config or {}; local panel=self:_popup(plain(cfg.Title or "NoxHub"),350,230,nil)
        local body=scroll(panel,{Position=UDim2.fromOffset(18,58),Size=UDim2.new(1,-36,1,-122)})
        label(body,plain(cfg.Content or cfg.Desc),13,C.Muted,{Size=UDim2.new(1,-6,0,0),AutomaticSize=Enum.AutomaticSize.Y,TextWrapped=true,TextYAlignment=Enum.TextYAlignment.Top})
        local buttons=cfg.Buttons or {{Title="Aceptar"}}
        for i,entry in ipairs(buttons) do
            local b=button(panel,entry.Title or "Aceptar",{Position=UDim2.new((i-1)/#buttons,16,1,-54),Size=UDim2.new(1/#buttons,-22,0,36)})
            round(b,8)
            connect(self,b.Activated,function() self:_closePopup(); invoke(entry.Callback) end,self._popupConnections)
        end
        return {Close=function() self:_closePopup() end}
    end
    connect(w,minimize.Activated,function() w:Close() end)
    connect(w,close.Activated,function()
        w:Dialog({Title="Cerrar NoxHub",Content="Se cerrará el panel y se limpiará esta sesión. Puedes volver a ejecutar el hub cuando quieras.",
            Buttons={{Title="Volver"},{Title="Cerrar",Callback=function() w:Destroy() end}}})
    end)
    connect(w,menu.Activated,function() w:_drawer(not w._drawerOpen) end)
    connect(w,drawerShade.Activated,function() w:_drawer(false) end)
    connect(w,clear.Activated,function() search.Text="" end)
    connect(w,search:GetPropertyChangedSignal("Text"),function()
        clear.Visible=search.Text~=""
        if w.CurrentTab then w.CurrentTab.Query=search.Text; w.CurrentTab:_queueFilter() end
    end)
    local function drag(input,target,centered)
        if input.UserInputType~=Enum.UserInputType.MouseButton1 and input.UserInputType~=Enum.UserInputType.Touch then return end
        local start=input.Position; local pos=target.Position; local moved=false
        local parentSize=target.Parent.AbsoluteSize
        local startX=pos.X.Scale*parentSize.X+pos.X.Offset
        local startY=pos.Y.Scale*parentSize.Y+pos.Y.Offset
        w:_beginDrag(input,function(position)
            local delta=position-start
            if delta.Magnitude>5 then moved=true end
            if moved then
                target.Position=UDim2.fromOffset(startX+delta.X,startY+delta.Y)
                if centered then clampRoot() else
                    w._skipOpen=true
                    clampLauncher()
                end
            end
        end)
    end

    local function beginResize(info,input)
        if not w.Resizable then return end
        if input.UserInputType~=Enum.UserInputType.MouseButton1 and input.UserInputType~=Enum.UserInputType.Touch then return end
        local start=input.Position
        local startWidth=root.AbsoluteSize.X
        local startHeight=root.AbsoluteSize.Y
        local bounds=surface.AbsoluteSize
        local rootCenter=Vector2.new(root.AbsolutePosition.X+root.AbsoluteSize.X/2,root.AbsolutePosition.Y+root.AbsoluteSize.Y/2)
        w:_beginDrag(input,function(position)
            local delta=position-start
            local maxScreenW=math.max(260,bounds.X-12)
            local maxScreenH=math.max(220,bounds.Y-12)
            local minScreenW=math.min(w._minWidth*w.UIScale,maxScreenW)
            local minScreenH=math.min(w._minHeight*w.UIScale,maxScreenH)
            local screenW=math.clamp(startWidth+info.X*delta.X,minScreenW,maxScreenW)
            local screenH=math.clamp(startHeight+info.Y*delta.Y,minScreenH,maxScreenH)
            local changedW=screenW-startWidth
            local changedH=screenH-startHeight
            w._desiredWidth=screenW/w.UIScale
            w._desiredHeight=screenH/w.UIScale
            root.Position=UDim2.fromOffset(rootCenter.X+(info.X*changedW)/2,rootCenter.Y+(info.Y*changedH)/2)
            fit()
        end,nil,info)
    end
    for _,info in ipairs(resizeHandles) do
        connect(w,info.Hit.InputBegan,function(input) beginResize(info,input) end)
    end
    top.Active=true
    connect(w,top.InputBegan,function(input)
        if input.Position.X < controls.AbsolutePosition.X then drag(input,root,true) end
    end)
    connect(w,openButton.InputBegan,function(input) w._skipOpen=false; drag(input,openButton,false) end)
    connect(w,openButton.Activated,function() if not w._skipOpen then w:Toggle() end end)
    connect(w,Input.InputChanged,function(input)
        local d=w._drag
        if d and ((d.Input.UserInputType==Enum.UserInputType.Touch and input==d.Input)
            or (d.Input.UserInputType==Enum.UserInputType.MouseButton1 and input.UserInputType==Enum.UserInputType.MouseMovement)) then d.Update(input.Position) end
    end)
    connect(w,Input.InputEnded,function(input)
        local d=w._drag
        if d and (input==d.Input or (d.Input.UserInputType==Enum.UserInputType.MouseButton1 and input.UserInputType==Enum.UserInputType.MouseButton1)) then w:_endDrag() end
    end)
    connect(w,Input.WindowFocusReleased,function() w:_endDrag() end)
    connect(w,Input.InputBegan,function(input,processed)
        if input.KeyCode==Enum.KeyCode.Escape and w._popupLayer then w:_closePopup(); return end
        if processed or Input:GetFocusedTextBox() then return end
        if input.KeyCode==w.ToggleKey then w:Toggle() end
    end)
    connect(w,surface:GetPropertyChangedSignal("AbsoluteSize"),fit)
    connect(w,launcherSurface:GetPropertyChangedSignal("AbsoluteSize"),clampLauncher)
    connect(w,gui.Destroying,function() if not w.Destroyed then w:Destroy() end end)
    if o.OpenButton then w:EditOpenButton(o.OpenButton) end
    if o.Author then w:SetAuthor(o.Author) end
    footer.Text="NOXHUB  /  KEV"
    task.defer(fit)
    return w
end
function Nox:SetTheme(name)
    -- "Onyx" sigue aceptado como alias para no romper llamadas antiguas.
    self.Theme={Name="Nox",Accent=C.White,Background=C.Window,Text=C.Text}
    return self.Theme
end
function Nox:GetCurrentTheme() return "Nox" end
function Nox:GetThemes() return {Nox={Name="Nox"},Onyx={Name="Nox"}} end
function Nox:Notify(options)
    if not self.Window then return end
    local w=self.Window; local o=options or {}
    if w.Destroyed then return end
    if w._notice then w._notice:Destroy() end
    local holder=new("Frame",{Name="NoxNotice",BackgroundColor3=C.Row,AnchorPoint=Vector2.new(.5,0),
        Position=UDim2.new(.5,0,0,12),Size=UDim2.new(1,-24,0,0),AutomaticSize=Enum.AutomaticSize.Y,ZIndex=100},w.ScreenGui)
    new("UISizeConstraint",{MaxSize=Vector2.new(360,math.huge)},holder)
    round(holder,12); stroke(holder); padding(holder,14,12); vertical(holder,6)
    label(holder,plain(o.Title or "NoxHub"),13,C.Text,{Font=BOLD,LayoutOrder=1})
    label(holder,plain(o.Content or o.Desc),12,C.Muted,{Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,TextWrapped=true,LayoutOrder=2})
    w._notice=holder
    task.delay(math.clamp(tonumber(o.Duration) or 2,1,8),function()
        if holder.Parent then holder:Destroy() end
        if w._notice==holder then w._notice=nil end
    end)
    return {Close=function() if holder.Parent then holder:Destroy() end end}
end
Nox:SetTheme("Nox")
return Nox
