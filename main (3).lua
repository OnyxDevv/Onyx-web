--[[
    XeroHub UI / Obsidian 2.9 — polish + compact sliders + open-button ghost
    Creator: Kev
    Native Roblox interface. No WindUI runtime, icon downloads or render loops.
    Compatible with the control API used by the supplied DUELS hub.
    Usage: local UI = require(module); local Window = UI:CreateWindow({...})
    GuiButton input: https://create.roblox.com/docs/reference/engine/classes/GuiButton
]]

local Players = game:GetService("Players")
local Input = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")
local Nox = { Version = "2.9.0", Brand = "XeroHub", Creator = "Kev", UIScale = 1 }
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
    if not ok then warn("[XeroHub] " .. tostring(err)) end
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
    -- Marca Xero: una X geométrica limpia. Sin marco, caja ni "reloj de arena".
    local holder = new("Frame", {Name="XeroMark", BackgroundTransparency=1, Size=UDim2.fromOffset(size,size)}, parent)
    local tone = color or C.Text
    local length = math.max(14, math.floor(size * 0.72))
    local thickness = math.max(2, math.floor(size * 0.105))

    local function xBar(rotation)
        local bar = new("Frame", {
            AnchorPoint=Vector2.new(.5,.5),
            Position=UDim2.fromScale(.5,.5),
            Size=UDim2.fromOffset(length,thickness),
            Rotation=rotation,
            BackgroundColor3=tone,
        }, holder)
        round(bar, thickness)
        return bar
    end

    xBar(45)
    xBar(-45)

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
            AutoFarm="06",["Gráficos"]="07",Animaciones="08",Apariencia="09",["Generar Armas"]="10",["Configuración"]="11",["Créditos"]="12"}
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
    local px=section and 2 or 10
    local py=section and 7 or 8
    local headWidth=math.max(40,width-px*2)
    local reserve=self.Reserve or 0
    local copyWidth=math.max(30,headWidth-reserve)
    local titleHeight=textHeight(self.Title,self.TitleLabel.TextSize,self.TitleLabel.Font,copyWidth)
    local descHeight=textHeight(self.Desc,self.DescLabel.TextSize,self.DescLabel.Font,copyWidth)
    local copyHeight=titleHeight+(descHeight>0 and 4+descHeight or 0)
    local headHeight=math.max(copyHeight,self.HeadMinimum or 0)
    self.Head.Position=UDim2.fromOffset(px,py)
    self.Head.Size=UDim2.new(1,-px*2,0,headHeight)
    local copyOffsetX=self.CopyOffsetX or 0
    self.Copy.Position=UDim2.fromOffset(copyOffsetX,0)
    self.Copy.Size=UDim2.new(1,-reserve-copyOffsetX,0,copyHeight)
    self.TitleLabel.Size=UDim2.new(1,0,0,titleHeight)
    self.DescLabel.Position=UDim2.fromOffset(0,titleHeight+4)
    self.DescLabel.Size=UDim2.new(1,0,0,descHeight)
    if self.Thumbnail then
        local size=self.ThumbnailSize or 36
        local thumbY=math.max(0,math.floor((headHeight-size)/2))
        local thumbX=(self.ImageAlign=="left") and 0 or math.max(0,headWidth-size)
        self.Thumbnail.Position=UDim2.fromOffset(thumbX,thumbY)
        self.Thumbnail.Size=UDim2.fromOffset(size,size)
    end
    local y=py+headHeight
    if self.BodyField then
        local fieldHeight=28
        if self.ValueLabel then fieldHeight=math.max(28,textHeight(self.ValueLabel.Text,11,FONT,headWidth-36)+12) end
        self.BodyField.Position=UDim2.fromOffset(px,y+6)
        self.BodyField.Size=UDim2.new(1,-px*2,0,fieldHeight)
        y+=6+fieldHeight
    end
    if self.SliderArea then
        local sliderAreaHeight=self.SliderAreaHeight or 14
        local sliderLimitsGap=self.SliderLimitsGap or 2
        self.SliderArea.Position=UDim2.fromOffset(px,y+3)
        self.SliderArea.Size=UDim2.new(1,-px*2,0,sliderAreaHeight)
        self.Limits.Position=UDim2.fromOffset(px,y+3+sliderAreaHeight+sliderLimitsGap)
        self.Limits.Size=UDim2.new(1,-px*2,0,10)
        y+=sliderAreaHeight+sliderLimitsGap+14
    end
    if self.Rule then self.Rule.Position=UDim2.fromOffset(px,y+5); self.Rule.Size=UDim2.new(1,-px*2,0,1); y+=7 end
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
            if c.Slot.Visible then height+=c.Slot.Size.Y.Offset+5 end
        end
    end
    local bottomPad=22
    local canvasHeight=math.max(0,height-5+bottomPad)
    self.Content.CanvasSize=UDim2.fromOffset(0,canvasHeight)
    local viewportHeight=self.Content.AbsoluteSize.Y
    self.Content.CanvasPosition=Vector2.new(0,math.clamp(self.Content.CanvasPosition.Y,0,math.max(0,canvasHeight-viewportHeight)))
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
    local row = new("Frame", {Name=kind,BackgroundColor3=o.Color or C.Row,
        Size=UDim2.new(1,0,0,0),LayoutOrder=self._order,ClipsDescendants=true},slot)
    round(row,11); local rowStroke=stroke(row,o.StrokeColor or Color3.fromRGB(31,31,31))
    local head = new("Frame", {Name="Heading",BackgroundTransparency=1,
        Size=UDim2.new(1,0,0,0),LayoutOrder=1},row)
    local copy = new("Frame", {Name="Copy",BackgroundTransparency=1,
        Size=UDim2.new(1,0,0,0)},head)
    local title = label(copy,plain(o.Title or kind),12,C.Text,{Font=MEDIUM,TextWrapped=true,
        TextYAlignment=Enum.TextYAlignment.Top,Size=UDim2.new(1,0,0,18),LayoutOrder=1})
    local desc = label(copy,plain(o.Desc),11,C.Muted,{TextWrapped=true,AutomaticSize=Enum.AutomaticSize.Y,
        Size=UDim2.new(1,0,0,0),LayoutOrder=2,Visible=o.Desc ~= nil and o.Desc ~= ""})
    local control = setmetatable({Title=plain(o.Title or kind),Desc=plain(o.Desc),__type=kind,
        Window=self.Window,Tab=self,ElementFrame=row,Slot=slot,Head=head,Copy=copy,RowStroke=rowStroke,
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
    c.TitleLabel.TextColor3=C.Muted; c.TitleLabel.TextSize=10; c.TitleLabel.Font=BOLD
    local rule = new("Frame",{Size=UDim2.new(1,0,0,1),BackgroundColor3=C.Border,LayoutOrder=3},c.ElementFrame)
    c.Rule = rule
    return c
end
function Tab:Paragraph(options)
    local c = self:_control("Paragraph",options)
    local o = options or {}
    if o.TitleColor then c.TitleLabel.TextColor3=o.TitleColor end
    if o.DescColor then c.DescLabel.TextColor3=o.DescColor end
    if type(o.Image)=="string" and (o.Image:match("^rbxassetid://") or o.Image:match("^rbxthumb://")) then
        local pictureSize=math.max(32, tonumber(o.ImageSize) or 32)
        local align=(o.ImageAlign=="left") and "left" or "right"
        c.ImageAlign=align
        c.ThumbnailSize=pictureSize
        c.CopyOffsetX=align=="left" and (pictureSize+12) or 0
        c.Reserve=(align=="left") and 0 or (pictureSize+14)
        c.HeadMinimum=math.max(34,pictureSize)
        local picture=new("ImageLabel",{Name="Thumbnail",Image=o.Image,BackgroundColor3=C.Field,
            Position=UDim2.new(1,-pictureSize,0,0),Size=UDim2.fromOffset(pictureSize,pictureSize),ScaleType=Enum.ScaleType.Crop},c.Head)
        round(picture,o.CircleImage and math.floor(pictureSize/2) or 10)
        stroke(picture,o.ImageStrokeColor or Color3.fromRGB(238,238,238),o.ImageStrokeThickness or 1)
        c.Thumbnail=picture
    end
    if o.Gothic then
        local decor=new("Frame",{Name="Decor",BackgroundTransparency=1,Size=UDim2.fromScale(1,1),ZIndex=0},c.ElementFrame)
        local shell=new("Frame",{Name="Shell",BackgroundColor3=Color3.fromRGB(255,255,255),BackgroundTransparency=.985,
            Position=UDim2.fromOffset(1,1),Size=UDim2.new(1,-2,1,-2),ZIndex=0},decor)
        round(shell,10); stroke(shell,Color3.fromRGB(72,72,78),1)
        local glow=new("Frame",{AnchorPoint=Vector2.new(1,.5),Position=UDim2.fromScale(.985,.5),Size=UDim2.fromScale(.38,.92),
            BackgroundColor3=Color3.fromRGB(26,26,32),BackgroundTransparency=.54,Rotation=-8,ZIndex=0},decor)
        round(glow,22)
        new("UIGradient",{Rotation=28,Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.16),NumberSequenceKeypoint.new(1,1)})},glow)
        local bar=line(decor,18,14,1,200,0,Color3.fromRGB(64,64,72)); bar.BackgroundTransparency=.58; bar.ZIndex=0
        local corner=line(decor,18,14,42,1,0,Color3.fromRGB(86,86,92)); corner.BackgroundTransparency=.48; corner.ZIndex=0
        local wm=label(decor,o.DecorText or "XERO",28,Color3.fromRGB(255,255,255),{AnchorPoint=Vector2.new(1,1),Position=UDim2.fromScale(.968,.9),
            Size=UDim2.fromScale(.46,.30),Font=BOLD,TextTransparency=.952,TextXAlignment=Enum.TextXAlignment.Right,TextYAlignment=Enum.TextYAlignment.Bottom,ZIndex=0})
        c.ElementFrame.BackgroundColor3=o.Color or Color3.fromRGB(11,11,14)
        c.RowStroke.Color=o.StrokeColor or Color3.fromRGB(42,42,48)
        c.TitleLabel.Font=BOLD
        c.TitleLabel.TextSize=math.max(c.TitleLabel.TextSize,14)
        c.DescLabel.TextSize=math.max(c.DescLabel.TextSize,11)
        c.DescLabel.TextColor3=o.DescColor or Color3.fromRGB(178,178,178)
        if c.Thumbnail then
            -- La foto ya lleva su propio stroke. No añadimos un halo separado:
            -- al relayout quedaba como un círculo vacío a la derecha del perfil.
            c.HeadMinimum=math.max(c.HeadMinimum or 0,(c.ThumbnailSize or 36)+8)
            c.Thumbnail.ZIndex=2
        end
        if o.BadgeText then
            local badge=label(c.Head,string.upper(plain(o.BadgeText)),9,Color3.fromRGB(252,252,252),{
                AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-4,0,0),Size=UDim2.fromOffset(82,22),
                TextXAlignment=Enum.TextXAlignment.Center,Font=Enum.Font.Code,BackgroundColor3=Color3.fromRGB(18,18,18),BackgroundTransparency=.05,ZIndex=3})
            round(badge,9); stroke(badge,Color3.fromRGB(54,54,58),1)
        end
    end
    function c:Set(value) return self:SetDesc(value) end
    return c
end
function Tab:Button(options)
    local c = self:_control("Button",options)
    c.Reserve=34; c.HeadMinimum=28
    local hit = button(c.Head,"→",{Name="Action",BackgroundColor3=Color3.fromRGB(14,14,14),TextSize=14,
        Position=UDim2.new(1,-26,0,0),Size=UDim2.fromOffset(26,26)})
    round(hit,8); stroke(hit,Color3.fromRGB(30,30,30)); hover(c.Window,hit,C.Field)
    -- The title and description are clickable too; nested field controls are separate.
    local titleHit=button(c.Copy,"",{Name="Activate",BackgroundTransparency=1,Size=UDim2.fromScale(1,1),ZIndex=3})
    local function activate() if not c.Locked and not c.Destroyed then invoke(c.Callback) end end
    connect(c.Window,hit.Activated,activate); connect(c.Window,titleHit.Activated,activate)
    c.Interactive=hit
    return c
end
function Tab:Toggle(options)
    local o = options or {}; local c = self:_control("Toggle",o)
    c.Reserve=46; c.HeadMinimum=28
    local target=button(c.Head,"",{Name="ToggleHit",BackgroundTransparency=1,
        Position=UDim2.new(1,-38,0,0),Size=UDim2.fromOffset(38,26)})
    local hit=new("Frame",{Name="Switch",BackgroundColor3=C.Border,
        Position=UDim2.fromOffset(4,4),Size=UDim2.fromOffset(30,18)},target)
    round(hit,7)
    local knob=new("Frame",{Name="Thumb",BackgroundColor3=C.Muted,Position=UDim2.fromOffset(4,4),
        Size=UDim2.fromOffset(10,10)},hit); round(knob,4)
    local tick=label(knob,"",11,C.Window,{TextXAlignment=Enum.TextXAlignment.Center,Size=UDim2.fromScale(1,1)})
    c.Interactive=target
    function c:Set(value,silent)
        if self.Destroyed then return self end
        value=value == true
        local changed=self.Value ~= value; self.Value=value
        hit.BackgroundColor3=value and C.White or C.Border
        knob.BackgroundColor3=value and C.Window or C.Muted
        knob.Position=UDim2.fromOffset(value and 16 or 4,4)
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
        TextXAlignment=Enum.TextXAlignment.Left,TextSize=11,Size=UDim2.new(1,0,0,28),LayoutOrder=2},parent)
    round(box,8); stroke(box,Color3.fromRGB(30,30,30)); padding(box,9,0)
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
    c.Reserve=70; c.HeadMinimum=28
    c.SliderAreaHeight=30; c.SliderLimitsGap=1

    local box=field(c.Head,"")
    box.Name="Value"
    box.Size=UDim2.fromOffset(58,26)
    box.Position=UDim2.new(1,-58,0,0)
    box.TextXAlignment=Enum.TextXAlignment.Center
    box.BackgroundColor3=Color3.fromRGB(11,11,11)
    box.TextColor3=Color3.fromRGB(242,242,242)
    box.Font=MEDIUM
    box.TextSize=10
    if box:FindFirstChildOfClass("UICorner") then box:FindFirstChildOfClass("UICorner").CornerRadius=UDim.new(0,9) end
    local boxStroke=box:FindFirstChildOfClass("UIStroke")
    if boxStroke then boxStroke.Color=Color3.fromRGB(42,42,42); boxStroke.Transparency=.12 end

    local area=button(c.ElementFrame,"",{Name="SliderArea",BackgroundTransparency=1,
        Size=UDim2.new(1,0,0,30),LayoutOrder=2})

    -- Rail oscuro + carril interior. El área táctil sigue siendo toda la fila.
    local rail=new("Frame",{Name="Rail",Position=UDim2.new(0,8,.5,-5),Size=UDim2.new(1,-16,0,10),
        BackgroundColor3=Color3.fromRGB(18,18,18)},area)
    round(rail,7); stroke(rail,Color3.fromRGB(37,37,40),1)

    local track=new("Frame",{Name="Track",Position=UDim2.new(0,6,.5,-3),Size=UDim2.new(1,-12,0,6),
        BackgroundColor3=Color3.fromRGB(43,43,46)},rail)
    round(track,4)
    local trackGradient=new("UIGradient",{Color=ColorSequence.new({
        ColorSequenceKeypoint.new(0,Color3.fromRGB(36,36,39)),
        ColorSequenceKeypoint.new(.5,Color3.fromRGB(48,48,51)),
        ColorSequenceKeypoint.new(1,Color3.fromRGB(36,36,39))
    })},track)

    local fill=new("Frame",{Name="Fill",Size=UDim2.fromScale(0,1),BackgroundColor3=Color3.fromRGB(232,232,232)},track)
    round(fill,4)
    new("UIGradient",{Color=ColorSequence.new({
        ColorSequenceKeypoint.new(0,Color3.fromRGB(255,255,255)),
        ColorSequenceKeypoint.new(1,Color3.fromRGB(200,200,204))
    })},fill)

    local halo=new("Frame",{Name="ThumbHalo",AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(0,.5),
        Size=UDim2.fromOffset(20,20),BackgroundColor3=Color3.fromRGB(255,255,255),BackgroundTransparency=.88,ZIndex=3},track)
    round(halo,10)
    local thumb=new("Frame",{Name="Thumb",AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(0,.5),
        Size=UDim2.fromOffset(13,13),BackgroundColor3=Color3.fromRGB(248,248,248),ZIndex=4},track)
    round(thumb,7); local thumbStroke=stroke(thumb,Color3.fromRGB(72,72,76),1); thumbStroke.Transparency=.05

    local limits=new("Frame",{Name="Limits",BackgroundTransparency=1,Size=UDim2.new(1,0,0,10),LayoutOrder=3},c.ElementFrame)
    c.SliderArea=area; c.Limits=limits
    label(limits,tostring(low),8,C.Faint,{Size=UDim2.fromScale(.5,1),Font=Enum.Font.Code})
    label(limits,tostring(high),8,C.Faint,{Size=UDim2.fromScale(.5,1),Position=UDim2.fromScale(.5,0),
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
        fill.Size=UDim2.fromScale(ratio,1)
        thumb.Position=UDim2.fromScale(ratio,.5)
        halo.Position=UDim2.fromScale(ratio,.5)
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
        Size=UDim2.new(1,0,0,28),LayoutOrder=2}); round(hit,8); stroke(hit,Color3.fromRGB(28,28,28))
    local valueLabel=label(hit,"",11,C.Text,{Position=UDim2.fromOffset(8,0),Size=UDim2.new(1,-30,1,0),TextWrapped=true})
    label(hit,"⌄",14,C.Muted,{Position=UDim2.new(1,-24,0,0),Size=UDim2.new(0,16,1,0),TextXAlignment=Enum.TextXAlignment.Center})
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
        search.Position=UDim2.fromOffset(16,48); search.Size=UDim2.new(1,-32,0,30)
        local list=scroll(panel,{Position=UDim2.fromOffset(16,90),Size=UDim2.new(1,-32,1,-120)})
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
                        local choiceHeight=math.max(32,textHeight(tostring(value),12,FONT,math.max(60,panel.AbsoluteSize.X-78))+12)
                        local choice=button(list,"",{Name="Option",Size=UDim2.new(1,-4,0,choiceHeight),LayoutOrder=count,
                            BackgroundColor3=selected and C.Text or C.Row})
                        round(choice,8)
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
    round(hit,9); local hitStroke=stroke(hit,Color3.fromRGB(54,54,58),1); hitStroke.Transparency=.08
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
        local panel=window:_popup(self.Title,370,410,self)
        local body=new("Frame",{Name="ColorPaletteBody",Position=UDim2.fromOffset(16,54),
            Size=UDim2.new(1,-32,1,-70),BackgroundTransparency=1},panel)

        local h,s,v=self.Value:ToHSV()
        local state={H=h,S=s,V=v,Internal=false}
        if state.S < .001 then state.H=0 end

        local current=new("Frame",{Name="Current",Position=UDim2.fromOffset(0,0),Size=UDim2.fromOffset(44,34),
            BackgroundColor3=self.Value},body)
        round(current,9); stroke(current,Color3.fromRGB(70,70,74),1)

        local hex=field(body,"#FFFFFF")
        hex.Position=UDim2.fromOffset(54,0); hex.Size=UDim2.new(1,-54,0,34)
        hex.TextSize=11; hex.Font=MEDIUM

        local hint=label(body,"Paleta RGB · arrastra para elegir tono e intensidad",9,C.Muted,{
            Position=UDim2.fromOffset(0,39),Size=UDim2.new(1,0,0,16)})

        local palette=button(body,"",{Name="RGBPalette",Position=UDim2.fromOffset(0,58),
            Size=UDim2.new(1,0,0,220),BackgroundColor3=Color3.fromHSV(state.H,1,1),ClipsDescendants=true})
        round(palette,11); local paletteStroke=stroke(palette,Color3.fromRGB(58,58,62),1); paletteStroke.Transparency=.08

        -- Izquierda = blanco, derecha = color puro.
        local whiteLayer=new("Frame",{Name="WhiteBlend",Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.new(1,1,1),
            BorderSizePixel=0,ZIndex=2},palette)
        new("UIGradient",{Transparency=NumberSequence.new({
            NumberSequenceKeypoint.new(0,0),NumberSequenceKeypoint.new(1,1)
        })},whiteLayer)

        -- Arriba = luminoso, abajo = negro.
        local blackLayer=new("Frame",{Name="BlackBlend",Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.new(0,0,0),
            BorderSizePixel=0,ZIndex=3},palette)
        new("UIGradient",{Rotation=90,Transparency=NumberSequence.new({
            NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(1,0)
        })},blackLayer)

        local cursor=new("Frame",{Name="PaletteCursor",AnchorPoint=Vector2.new(.5,.5),Size=UDim2.fromOffset(18,18),
            BackgroundTransparency=1,ZIndex=6},palette)
        round(cursor,9); local cursorStroke=stroke(cursor,Color3.new(1,1,1),2); cursorStroke.Transparency=0
        local cursorShadow=new("UIStroke",{Color=Color3.new(0,0,0),Thickness=1,Transparency=.18,
            ApplyStrokeMode=Enum.ApplyStrokeMode.Border},cursor)

        local hueBar=button(body,"",{Name="Hue",Position=UDim2.fromOffset(0,290),Size=UDim2.new(1,0,0,18),
            BackgroundColor3=Color3.new(1,1,1),ClipsDescendants=false})
        round(hueBar,9); local hueStroke=stroke(hueBar,Color3.fromRGB(58,58,62),1); hueStroke.Transparency=.1
        new("UIGradient",{Color=ColorSequence.new({
            ColorSequenceKeypoint.new(0.00,Color3.fromRGB(255,0,0)),
            ColorSequenceKeypoint.new(0.17,Color3.fromRGB(255,255,0)),
            ColorSequenceKeypoint.new(0.33,Color3.fromRGB(0,255,0)),
            ColorSequenceKeypoint.new(0.50,Color3.fromRGB(0,255,255)),
            ColorSequenceKeypoint.new(0.67,Color3.fromRGB(0,0,255)),
            ColorSequenceKeypoint.new(0.83,Color3.fromRGB(255,0,255)),
            ColorSequenceKeypoint.new(1.00,Color3.fromRGB(255,0,0))
        })},hueBar)

        local hueCursor=new("Frame",{Name="HueCursor",AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(state.H,.5),
            Size=UDim2.fromOffset(5,26),BackgroundColor3=Color3.fromRGB(250,250,250),ZIndex=6},hueBar)
        round(hueCursor,3); local hueCursorStroke=stroke(hueCursor,Color3.fromRGB(20,20,20),1); hueCursorStroke.Transparency=.1

        local presets=Instance.new("Frame")
        presets.Name="Presets"; presets.BackgroundTransparency=1
        presets.Position=UDim2.fromOffset(0,320); presets.Size=UDim2.new(1,0,0,30); presets.Parent=body
        local presetLayout=Instance.new("UIListLayout")
        presetLayout.FillDirection=Enum.FillDirection.Horizontal; presetLayout.HorizontalAlignment=Enum.HorizontalAlignment.Center
        presetLayout.Padding=UDim.new(0,7); presetLayout.Parent=presets
        local presetColors={
            Color3.fromRGB(255,255,255),Color3.fromRGB(180,180,180),Color3.fromRGB(30,30,30),
            Color3.fromRGB(255,72,72),Color3.fromRGB(255,170,45),Color3.fromRGB(255,225,55),
            Color3.fromRGB(70,220,110),Color3.fromRGB(65,195,255),Color3.fromRGB(120,100,255),Color3.fromRGB(235,85,220)
        }

        local function applyHSV()
            state.Internal=true
            self:Set(Color3.fromHSV(state.H,state.S,state.V))
            state.Internal=false
        end

        local function syncFromValue()
            if not state.Internal then
                local nh,ns,nv=self.Value:ToHSV()
                if ns>.001 then state.H=nh end
                state.S=ns; state.V=nv
            end
            current.BackgroundColor3=self.Value
            hex.Text="#"..self.Value:ToHex():upper()
            palette.BackgroundColor3=Color3.fromHSV(state.H,1,1)
            cursor.Position=UDim2.new(state.S,0,1-state.V,0)
            hueCursor.Position=UDim2.new(state.H,0,.5,0)
        end
        self._updateColor=syncFromValue

        local function updatePalette(position)
            local size=palette.AbsoluteSize
            if size.X<=1 or size.Y<=1 then return end
            state.S=math.clamp((position.X-palette.AbsolutePosition.X)/size.X,0,1)
            state.V=1-math.clamp((position.Y-palette.AbsolutePosition.Y)/size.Y,0,1)
            applyHSV()
        end
        local function updateHue(position)
            local width=hueBar.AbsoluteSize.X
            if width<=1 then return end
            state.H=math.clamp((position.X-hueBar.AbsolutePosition.X)/width,0,1)
            applyHSV()
        end

        connect(window,palette.InputBegan,function(input)
            if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
                window:_beginDrag(input,updatePalette,nil,self); updatePalette(input.Position)
            end
        end,window._popupConnections)
        connect(window,hueBar.InputBegan,function(input)
            if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
                window:_beginDrag(input,updateHue,nil,self); updateHue(input.Position)
            end
        end,window._popupConnections)

        for index,color in ipairs(presetColors) do
            local swatch=button(presets,"",{Name="Preset"..index,Size=UDim2.fromOffset(24,24),BackgroundColor3=color,LayoutOrder=index})
            round(swatch,7); local ss=stroke(swatch,Color3.fromRGB(78,78,82),1); ss.Transparency=.1
            connect(window,swatch.Activated,function() self:Set(color) end,window._popupConnections)
        end

        connect(window,hex.FocusLost,function()
            local value=hex.Text:gsub("#","")
            if #value==6 and value:match("^%x+$") then self:Set(Color3.fromHex(value)) else syncFromValue() end
        end,window._popupConnections)

        window._popupCleanup=function() self._updateColor=nil end
        syncFromValue()
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
    ["Configuración"]="Tu interfaz y tus configuraciones guardadas.", ["Generar Armas"]="Organiza tus opciones de inventario.", ["Créditos"]="Conoce al creador y los datos del proyecto.",
}
function Nox:CreateWindow(options)
    local o=options or {}
    if self.Window and not self.Window.Destroyed then self.Window:Destroy() end
    local player=Players.LocalPlayer
    assert(player,"XeroHub UI must run on the client")
    local parent=player:WaitForChild("PlayerGui")
    pcall(function()
        if gethui then
            local hui=gethui()
            if hui then parent=hui else parent=game:GetService("CoreGui") end
        else
            parent=game:GetService("CoreGui")
        end
    end)
    local env=(getgenv and getgenv()) or _G
    if env.__NOX_UI and env.__NOX_UI.Destroy then pcall(function() env.__NOX_UI:Destroy() end) end
    local w={_connections={},_popupConnections={},_onDestroy={},_onOpen={},_onClose={},Tabs={},
        Groups={},Opened=true,Destroyed=false,Compact=false,ToggleKey=o.ToggleKey or Enum.KeyCode.RightShift,
        Title=plain(o.Title or "XeroHub"),Author=o.Author or "by Kev",UIScale=1,_navOrder=0}
    self.Window=w; env.__NOX_UI=w
    local gui=new("ScreenGui",{Name="XeroHubUI",ResetOnSpawn=false,IgnoreGuiInset=true,
        DisplayOrder=2147483000,ZIndexBehavior=Enum.ZIndexBehavior.Sibling},parent)
    -- El panel usa todo el viewport real. Así puede tocar Y=0 y no queda atrapado
    -- debajo del inset de la barra superior de Roblox.
    pcall(function()
        gui.ScreenInsets=Enum.ScreenInsets.None
        gui.ClipToDeviceSafeArea=false
        gui.SafeAreaCompatibility=Enum.SafeAreaCompatibility.None
    end)
    pcall(function() gui.OnTopOfCoreBlur=true end)
    local launcherGui=new("ScreenGui",{Name="XeroHubLauncher",ResetOnSpawn=false,IgnoreGuiInset=true,
        DisplayOrder=2147483001,ZIndexBehavior=Enum.ZIndexBehavior.Sibling},parent)
    pcall(function()
        launcherGui.ScreenInsets=Enum.ScreenInsets.None
        launcherGui.ClipToDeviceSafeArea=false
        launcherGui.SafeAreaCompatibility=Enum.SafeAreaCompatibility.None
    end)
    pcall(function() launcherGui.OnTopOfCoreBlur=true end)
    local launcherSurface=new("Frame",{Name="FullScreen",BackgroundTransparency=1,Size=UDim2.fromScale(1,1)},launcherGui)
    w.LauncherGui=launcherGui
    self.ScreenGui=gui; w.ScreenGui=gui
    -- Full-viewport bounds are shared by popups, dragging and responsive layout.
    local surface=new("Frame",{Name="Surface",BackgroundTransparency=1,Size=UDim2.fromScale(1,1)},gui)
    local root=new("Frame",{Name="XeroPanel",BackgroundColor3=Color3.fromRGB(7,7,7),AnchorPoint=Vector2.new(.5,.5),
        Position=UDim2.fromScale(.5,.5),Size=UDim2.fromOffset(680,430),ClipsDescendants=true},surface)
    round(root,20); stroke(root,Color3.fromRGB(48,48,48))
    local rootGradient=new("UIGradient",{Rotation=22,Color=ColorSequence.new({
        ColorSequenceKeypoint.new(0,Color3.fromRGB(5,5,5)),
        ColorSequenceKeypoint.new(.52,Color3.fromRGB(10,10,10)),
        ColorSequenceKeypoint.new(1,Color3.fromRGB(4,4,4))
    })},root)
    local scale=new("UIScale",{Scale=1},root); self.UIScaleObj=scale

    -- Fondo Xero: geométrico, monocromo y más contenido para no invadir el panel.
    local backdrop=new("Frame",{Name="NoxBackdrop",BackgroundTransparency=1,Size=UDim2.fromScale(1,1),ZIndex=1},root)
    local glowA=new("Frame",{Name="SoftGlowA",AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.68,.34),
        Size=UDim2.fromScale(.54,.62),BackgroundColor3=Color3.fromRGB(26,26,28),BackgroundTransparency=.58,Rotation=-16,ZIndex=1},backdrop)
    round(glowA,72)
    new("UIGradient",{Rotation=35,Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.12),NumberSequenceKeypoint.new(1,1)})},glowA)
    local glowB=new("Frame",{Name="SoftGlowB",AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.22,.84),
        Size=UDim2.fromScale(.46,.38),BackgroundColor3=Color3.fromRGB(20,20,24),BackgroundTransparency=.64,Rotation=18,ZIndex=1},backdrop)
    round(glowB,64)
    new("UIGradient",{Rotation=205,Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.2),NumberSequenceKeypoint.new(1,1)})},glowB)
    local watermark=label(backdrop,"XERO",80,Color3.fromRGB(255,255,255),{
        AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.61,.58),Size=UDim2.fromScale(.30,.12),
        Font=BOLD,TextTransparency=.974,TextXAlignment=Enum.TextXAlignment.Center,TextYAlignment=Enum.TextYAlignment.Center,Rotation=-10,ZIndex=1})
    for i=1,6 do
        local v=new("Frame",{Name="GridV",Position=UDim2.new(i/7,0,0,0),Size=UDim2.new(0,1,1,0),
            BackgroundColor3=Color3.fromRGB(255,255,255),BackgroundTransparency=.952,ZIndex=1},backdrop)
    end
    for i=1,4 do
        local h=new("Frame",{Name="GridH",Position=UDim2.new(0,0,i/5,0),Size=UDim2.new(1,0,0,1),
            BackgroundColor3=Color3.fromRGB(255,255,255),BackgroundTransparency=.962,ZIndex=1},backdrop)
    end
    local top=new("Frame",{Name="Topbar",BackgroundTransparency=1,Size=UDim2.new(1,0,0,58),ZIndex=5},root)
    local logo=mark(top,28); logo.Position=UDim2.fromOffset(16,12)

    local titleCluster=new("Frame",{Name="TitleCluster",BackgroundTransparency=1,
        Position=UDim2.fromOffset(50,9),Size=UDim2.fromOffset(290,24)},top)
    -- El título y el contador se posicionan manualmente para mantenerlos juntos
    -- en cualquier ancho; un UIListLayout con AutomaticSize dejaba huecos raros.
    local brand=label(titleCluster,"XERO | DUELS",16,C.Text,{Position=UDim2.fromOffset(0,0),
        Size=UDim2.fromOffset(120,22),Font=BOLD})
    local statusLabel=label(titleCluster,"-- activos",12,C.Muted,{Position=UDim2.fromOffset(126,0),
        Size=UDim2.fromOffset(96,22),Font=BOLD})
    local subtitle=label(top,"X E R O  /  "..tostring(o.Subtitle or "DUELS"),8,C.Faint,{Position=UDim2.fromOffset(52,37),Size=UDim2.fromOffset(180,14)})
    local author=label(top,w.Author,11,C.Muted,{Position=UDim2.new(1,-248,0,27),Size=UDim2.fromOffset(104,20),TextXAlignment=Enum.TextXAlignment.Right})
    local controls=new("Frame",{BackgroundTransparency=1,Position=UDim2.new(1,-76,0,8),Size=UDim2.fromOffset(64,28)},top)
    -- Navegación siempre visible: ya no existe el botón hamburguesa/drawer.
    local menu=button(controls,"",{Name="Menu",Size=UDim2.fromOffset(1,1),Visible=false,Active=false})
    local minimize=button(controls,"",{Name="Minimize",Position=UDim2.fromOffset(0,0),Size=UDim2.fromOffset(28,28)}); round(minimize,8)
    icon(minimize,"minus").Position=UDim2.fromOffset(4,4)
    local close=button(controls,"",{Name="Close",Position=UDim2.fromOffset(32,0),Size=UDim2.fromOffset(28,28)}); round(close,8)
    icon(close,"close").Position=UDim2.fromOffset(4,4)
    hover(w,minimize); hover(w,close)
    local topRule=line(root,14,57,784,1,0,C.Border); topRule.Size=UDim2.new(1,-28,0,1)
    local sidebar=new("Frame",{Name="Navigation",BackgroundColor3=Color3.fromRGB(10,10,10),Position=UDim2.fromOffset(12,70),
        Size=UDim2.new(0,154,1,-82),ZIndex=12},root); round(sidebar,12); stroke(sidebar,Color3.fromRGB(28,28,28))
    local nav=scroll(sidebar,{Name="Tabs",Position=UDim2.fromOffset(8,10),Size=UDim2.new(1,-16,1,-58),ScrollBarThickness=0})
    vertical(nav,6)
    local navFooter=label(sidebar,"XERO  /  OBSIDIAN",8,C.Faint,{Position=UDim2.new(0,12,1,-28),Size=UDim2.new(1,-24,0,16),Font=Enum.Font.Code})
    local drawerShade=button(root,"",{Name="DrawerBackdrop",BackgroundTransparency=1,
        Position=UDim2.fromOffset(0,70),Size=UDim2.new(1,0,1,-70),Visible=false,Active=false,ZIndex=11})
    local content=new("Frame",{Name="Content",BackgroundTransparency=1,Position=UDim2.fromOffset(182,70),Size=UDim2.new(1,-194,1,-82),ZIndex=4},root)
    local pageTitle=label(content,"Inicio",20,C.Text,{Size=UDim2.new(1,-90,0,26),Font=BOLD})
    local pageDesc=label(content,DESCRIPTIONS.Inicio,10,C.Muted,{Position=UDim2.fromOffset(0,24),Size=UDim2.new(1,0,0,20),TextWrapped=true,TextYAlignment=Enum.TextYAlignment.Top})
    local count=label(content,"0 opciones",9,C.Faint,{Position=UDim2.new(1,-96,0,5),Size=UDim2.fromOffset(96,16),TextXAlignment=Enum.TextXAlignment.Right,Font=Enum.Font.Code})
    w.CountLabel=count
    local searchBox=new("Frame",{Name="SearchBox",BackgroundColor3=C.Field,ClipsDescendants=true,
        Position=UDim2.new(1,-312,0,8),Size=UDim2.fromOffset(198,30),ZIndex=6},top)
    round(searchBox,9); stroke(searchBox,Color3.fromRGB(32,32,32))
    local search=new("TextBox",{Name="Search",BackgroundTransparency=1,ClearTextOnFocus=false,TextSize=12,TextTruncate=Enum.TextTruncate.AtEnd,
        PlaceholderText="Buscar ajuste...",PlaceholderColor3=C.Faint,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Center,
        Position=UDim2.fromOffset(28,0),Size=UDim2.new(1,-54,1,0)},searchBox)
    icon(searchBox,"search").Position=UDim2.new(0,8,.5,-10)
    local clear=button(searchBox,"×",{Name="Clear",BackgroundTransparency=1,Position=UDim2.new(1,-28,0,0),Size=UDim2.new(0,26,1,0),Visible=false})
    local pages=new("Frame",{Name="Pages",BackgroundTransparency=1,Position=UDim2.fromOffset(0,34),Size=UDim2.new(1,0,1,-34)},content)
    local footer=label(root,"XEROHUB",8,C.Faint,{Position=UDim2.new(0,18,1,-24),Size=UDim2.new(.6,0,0,14),Font=Enum.Font.Code})
    local shortcut=label(root,"RSHIFT  /  MOSTRAR U OCULTAR",8,C.Faint,{Position=UDim2.new(.4,0,1,-24),Size=UDim2.new(.6,-18,0,14),TextXAlignment=Enum.TextXAlignment.Right,Font=Enum.Font.Code})
    local openButton=button(launcherSurface,"",{Name="OpenXeroHub",Position=UDim2.new(.5,-77,0,16),Size=UDim2.fromOffset(154,40),BackgroundColor3=C.Window,ZIndex=20})
    round(openButton,12); local openStroke=stroke(openButton,Color3.fromRGB(66,66,66))
    local openIcon=mark(openButton,24); openIcon.Position=UDim2.fromOffset(8,8)
    local openLabel=label(openButton,"Abrir XeroHub",12,C.Text,{Position=UDim2.fromOffset(40,0),Size=UDim2.new(1,-47,1,0),Font=MEDIUM})
    w.OpenButton=openButton; w._launcherMoved=false; w.UIElements={Main=root,Title=brand,ActiveStatus=statusLabel,SideBar=sidebar,MainBar=content,Pages=pages,Search=searchBox,Topbar=top}
    local desired=o.Size or UDim2.fromOffset(680,430)
    w._desiredWidth=desired.X.Offset>0 and desired.X.Offset or 680
    w._desiredHeight=desired.Y.Offset>0 and desired.Y.Offset or 430
    w._initialFitDone=false
    w.Resizable=o.Resizable~=false
    local minSize=o.MinSize or Vector2.new(390,320)
    w._minWidth=math.max(300,tonumber(minSize.X) or 390)
    w._minHeight=math.max(260,tonumber(minSize.Y) or 320)

    local resizeHandles={}
    local resizeVisuals={}

    -- Affordance visual de resize: sólo en las dos esquinas inferiores.
    -- Los hitboxes de los cuatro bordes/esquinas siguen existiendo, pero ya no
    -- llenamos el marco con líneas. Cada marca es una cápsula diagonal suave.
    local function addResizeVisual(name, position, anchor, size, rotation)
        local grip = new("Frame", {
            Name = name,
            AnchorPoint = anchor,
            Position = position,
            Size = size,
            Rotation = rotation or 0,
            BackgroundColor3 = C.Text,
            BackgroundTransparency = 0.32,
            BorderSizePixel = 0,
            ZIndex = 39,
            Visible = w.Resizable,
        }, root)
        round(grip, 99)
        table.insert(resizeVisuals, grip)
        return grip
    end

    -- Dos pequeñas líneas redondeadas por esquina, separadas del borde para
    -- que ClipsDescendants/UICorner nunca les corte las puntas.
    addResizeVisual("ResizeGuideBL_Outer", UDim2.new(0, 13, 1, -10), Vector2.new(.5, .5), UDim2.fromOffset(16, 3), -45)
    addResizeVisual("ResizeGuideBL_Inner", UDim2.new(0, 20, 1, -10), Vector2.new(.5, .5), UDim2.fromOffset(10, 3), -45)
    addResizeVisual("ResizeGuideBR_Outer", UDim2.new(1, -13, 1, -10), Vector2.new(.5, .5), UDim2.fromOffset(16, 3), 45)
    addResizeVisual("ResizeGuideBR_Inner", UDim2.new(1, -20, 1, -10), Vector2.new(.5, .5), UDim2.fromOffset(10, 3), 45)

    -- Guías laterales: cápsulas verticales discretas, un poco metidas hacia
    -- dentro del marco para conservar el redondeo exterior del hub.
    addResizeVisual("ResizeGuideLeft", UDim2.new(0, 6, .5, 0), Vector2.new(.5, .5), UDim2.fromOffset(3, 36), 0)
    addResizeVisual("ResizeGuideRight", UDim2.new(1, -6, .5, 0), Vector2.new(.5, .5), UDim2.fromOffset(3, 36), 0)

    local function addResizeHandle(name,position,anchor,size,xFactor,yFactor,showGrip)
        local hit=button(root,"",{Name=name,AnchorPoint=anchor,Position=position,
            Size=size,BackgroundTransparency=1,ZIndex=40,Visible=w.Resizable})
        table.insert(resizeHandles,{Hit=hit,X=xFactor,Y=yFactor})
        return hit
    end
    -- Esquinas: cambian ancho y alto a la vez.
    addResizeHandle("ResizeTL",UDim2.fromScale(0,0),Vector2.new(0,0),UDim2.fromOffset(28,28),-1,-1,false)
    addResizeHandle("ResizeTR",UDim2.fromScale(1,0),Vector2.new(1,0),UDim2.fromOffset(28,28), 1,-1,false)
    addResizeHandle("ResizeBL",UDim2.fromScale(0,1),Vector2.new(0,1),UDim2.fromOffset(28,28),-1, 1,false)
    addResizeHandle("ResizeBR",UDim2.fromScale(1,1),Vector2.new(1,1),UDim2.fromOffset(28,28), 1, 1,false)
    -- Bordes invisibles más grandes: facilitan especialmente estirar verticalmente en celular.
    addResizeHandle("ResizeTop",UDim2.fromScale(.5,0),Vector2.new(.5,0),UDim2.new(.34,0,0,12),0,-1,false)
    addResizeHandle("ResizeBottom",UDim2.fromScale(.5,1),Vector2.new(.5,1),UDim2.new(.34,0,0,14),0,1,false)
    addResizeHandle("ResizeLeft",UDim2.fromScale(0,.5),Vector2.new(0,.5),UDim2.new(0,12,.34,0),-1,0,false)
    addResizeHandle("ResizeRight",UDim2.fromScale(1,.5),Vector2.new(1,.5),UDim2.new(0,12,.34,0),1,0,false)
    function w:_endDrag()
        local d=self._drag; self._drag=nil
        if d and d.Scroll and d.Scroll.Parent then d.Scroll.ScrollingEnabled=d.WasScrolling end
        if d and type(d.Owner)=="table" and d.Owner.X~=nil and d.Owner.Y~=nil then
            if self._fit then self._fit(false) end
        end
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
        -- Conservado por compatibilidad con llamadas antiguas. La navegación
        -- ahora siempre está visible, incluso en layouts compactos.
        self._drawerOpen=false
        sidebar.Visible=true
        drawerShade.Visible=false
    end
    local function clampRoot()
        local bounds=surface.AbsoluteSize; local size=root.AbsoluteSize
        if bounds.X<=0 or bounds.Y<=0 then return end
        local x=root.Position.X.Scale*bounds.X+root.Position.X.Offset
        local y=root.Position.Y.Scale*bounds.Y+root.Position.Y.Offset
        -- Sin margen artificial: el borde superior puede llegar exactamente a Y=0.
        local minX=math.min(size.X/2,bounds.X/2); local minY=math.min(size.Y/2,bounds.Y/2)
        root.Position=UDim2.fromOffset(math.clamp(x,minX,math.max(minX,bounds.X-minX)),math.clamp(y,minY,math.max(minY,bounds.Y-minY)))
    end
    local function clampLauncher()
        local bounds=launcherSurface.AbsoluteSize; local size=openButton.AbsoluteSize
        local position=openButton.Position
        openButton.Position=UDim2.fromOffset(math.clamp(position.X.Scale*bounds.X+position.X.Offset,0,math.max(0,bounds.X-size.X)),
            math.clamp(position.Y.Scale*bounds.Y+position.Y.Offset,0,math.max(0,bounds.Y-size.Y)))
    end
    function w:_applyOpenButtonState()
        local ghosted=self._openButtonGhosted==true
        local visibleWhenClosed=(self._openButtonEnabled~=false) or ghosted
        local shouldShow=(not self.Opened) and visibleWhenClosed
        openButton.Visible=shouldShow
        openButton.Active=shouldShow
        openButton.AutoButtonColor=shouldShow and (not ghosted)
        openButton.BackgroundTransparency=ghosted and 1 or 0
        openLabel.TextTransparency=ghosted and 1 or 0
        if openStroke then openStroke.Transparency=ghosted and 1 or 0 end
        if openIcon then
            for _,d in ipairs(openIcon:GetDescendants()) do
                if d:IsA("Frame") then d.BackgroundTransparency=ghosted and 1 or 0 end
                if d:IsA("UIStroke") then d.Transparency=ghosted and 1 or 0 end
            end
        end
    end
    local function fit(skipContentLayout)
        if w.Destroyed then return end
        local bounds=surface.AbsoluteSize
        if bounds.X<1 or bounds.Y<1 then return end

        -- La ventana conserva tamaño lógico, pero nunca puede salir del viewport.
        -- En móvil se redistribuye en vez de escalarse completa, para mantener
        -- texto, botones, dropdowns y sliders legibles/táctiles.
        local maxWidth=math.max(280,bounds.X/w.UIScale)
        local maxHeight=math.max(240,bounds.Y/w.UIScale)
        local minWidth=math.min(w._minWidth,maxWidth)
        local minHeight=math.min(w._minHeight,maxHeight)

        -- Primer arranque en móvil/landscape: deja aire alrededor del panel.
        -- Después de esto no vuelve a forzar tamaño y el resize manual manda.
        if not w._initialFitDone then
            if maxHeight < 500 then
                w._desiredHeight=math.min(w._desiredHeight,math.max(minHeight,maxHeight*0.78))
                w._desiredWidth=math.min(w._desiredWidth,math.max(minWidth,maxWidth*0.76))
            elseif maxWidth < 650 then
                w._desiredWidth=math.min(w._desiredWidth,math.max(minWidth,maxWidth*0.86))
                w._desiredHeight=math.min(w._desiredHeight,math.max(minHeight,maxHeight*0.84))
            elseif maxWidth < 900 then
                w._desiredWidth=math.min(w._desiredWidth,math.max(minWidth,maxWidth*0.78))
                w._desiredHeight=math.min(w._desiredHeight,math.max(minHeight,maxHeight*0.80))
            end
            w._initialFitDone=true
        end

        local width=math.clamp(w._desiredWidth,minWidth,maxWidth)
        local height=math.clamp(w._desiredHeight,minHeight,maxHeight)
        root.Size=UDim2.fromOffset(width,height)

        local phone=width<520
        local tiny=width<380
        local short=height<390
        local veryShort=height<330
        w.Short=height<435
        w.Narrow=width<500
        w.Compact=width<650 or w.Short

        local topHeight=(phone or short) and 48 or 52
        local contentTop=topHeight+8
        local sidebarWidth
        if width<340 then sidebarWidth=76
        elseif width<430 then sidebarWidth=86
        elseif width<560 then sidebarWidth=100
        elseif width<700 then sidebarWidth=116
        else sidebarWidth=136 end

        local left=8+sidebarWidth+10
        local right=phone and 7 or 10
        local bottom=veryShort and 4 or (w.Short and 6 or 9)
        w.ContentWidth=math.max(150,width-left-right)

        top.Size=UDim2.new(1,0,0,topHeight)
        logo.Size=UDim2.fromOffset(phone and 24 or 28,phone and 24 or 28)
        logo.Position=UDim2.fromOffset(phone and 10 or 14,phone and 11 or 11)
        logo.Visible=true

        controls.Position=UDim2.new(1,-68,0,8)
        controls.Size=UDim2.fromOffset(60,28)
        minimize.Position=UDim2.fromOffset(0,0); minimize.Size=UDim2.fromOffset(26,26)
        close.Position=UDim2.fromOffset(30,0); close.Size=UDim2.fromOffset(26,26)

        -- Marca + activos: siempre juntos y usando sólo el espacio realmente libre.
        local clusterX=phone and 40 or 48
        local clusterRight=width-76
        local clusterWidth=math.max(82,clusterRight-clusterX-4)
        titleCluster.Position=UDim2.fromOffset(clusterX,phone and 10 or 10)
        titleCluster.Size=UDim2.fromOffset(clusterWidth,24)
        brand.Text=(tiny and "XERO") or "XERO | DUELS"
        brand.TextSize=phone and 13 or 15
        statusLabel.TextSize=phone and 10 or 11

        local measuredBrand=math.ceil(TextService:GetTextSize(
            brand.Text,brand.TextSize,brand.Font,Vector2.new(300,24)
        ).X)
        local measuredStatus=math.ceil(TextService:GetTextSize(
            statusLabel.Text,statusLabel.TextSize,statusLabel.Font,Vector2.new(180,24)
        ).X)
        local gap=phone and 6 or 8
        local canShowStatus=(measuredBrand+gap+measuredStatus)<=clusterWidth
        if not canShowStatus and brand.Text~="XERO" then
            brand.Text="XERO"
            measuredBrand=math.ceil(TextService:GetTextSize(
                brand.Text,brand.TextSize,brand.Font,Vector2.new(180,24)
            ).X)
            canShowStatus=(measuredBrand+gap+measuredStatus)<=clusterWidth
        end
        brand.Position=UDim2.fromOffset(0,0)
        brand.Size=UDim2.fromOffset(math.min(measuredBrand,clusterWidth),22)
        statusLabel.Position=UDim2.fromOffset(measuredBrand+gap,0)
        statusLabel.Size=UDim2.fromOffset(math.max(0,clusterWidth-measuredBrand-gap),22)
        statusLabel.Visible=canShowStatus

        subtitle.Visible=false
        author.Visible=false
        menu.Visible=false

        topRule.Position=UDim2.fromOffset(12,topHeight-1)
        topRule.Size=UDim2.new(1,-24,0,1)

        sidebar.Visible=true
        sidebar.Position=UDim2.fromOffset(8,contentTop)
        sidebar.Size=UDim2.new(0,sidebarWidth,1,-contentTop-bottom)
        nav.Position=UDim2.fromOffset(4,6)
        nav.Size=UDim2.new(1,-8,1,(w.Short or sidebarWidth<110) and -10 or -32)
        nav.ScrollBarThickness=2
        navFooter.Visible=not w.Short and sidebarWidth>=116
        navFooter.Position=UDim2.new(0,8,1,-27)
        navFooter.Size=UDim2.new(1,-16,0,15)
        drawerShade.Visible=false

        -- En móvil el buscador baja al encabezado del contenido para no chocar
        -- con el título, el contador ni los botones de ventana.
        if phone then
            if searchBox.Parent~=content then searchBox.Parent=content end
            searchBox.Position=UDim2.fromOffset(0,28)
            searchBox.Size=UDim2.new(1,0,0,28)
            searchBox.Visible=w.ContentWidth>=150
        else
            if searchBox.Parent~=top then searchBox.Parent=top end
            local searchWidth=math.clamp(math.floor(width*0.28),170,236)
            searchBox.Size=UDim2.fromOffset(searchWidth,28)
            searchBox.Position=UDim2.new(1,-(searchWidth+76),0,8)
            searchBox.Visible=true
        end

        content.Position=UDim2.fromOffset(left,contentTop)
        content.Size=UDim2.new(1,-left-right,1,-contentTop-bottom)
        pageTitle.Position=UDim2.fromOffset(0,0)
        pageTitle.Size=UDim2.new(1,phone and 0 or -76,0,22)
        pageTitle.TextSize=phone and 16 or 18
        pageTitle.TextTruncate=Enum.TextTruncate.AtEnd

        count.Position=UDim2.new(1,-84,0,2)
        count.Visible=(not phone) and (not short) and width>=720

        pageDesc.Position=UDim2.fromOffset(0,21)
        pageDesc.Size=UDim2.new(1,-6,0,18)
        pageDesc.Visible=(not phone) and height>=430 and w.ContentWidth>=280

        local pagesY
        if phone then
            pagesY=62
        else
            pagesY=pageDesc.Visible and 40 or 25
        end
        pages.Position=UDim2.fromOffset(0,pagesY)
        pages.Size=UDim2.new(1,0,1,-pagesY)

        footer.Visible=(not phone) and (not short)
        shortcut.Visible=(not phone) and (not short) and width>=660

        -- Compacta sólo la navegación; el contenido conserva tamaños táctiles.
        for _,tab in ipairs(w.Tabs) do
            if tab.NavButton then
                tab.NavButton.Size=UDim2.new(1,0,0,phone and 30 or 28)
            end
            if tab.SelectionBar then
                tab.SelectionBar.Position=UDim2.fromOffset(1,phone and 6 or 5)
                tab.SelectionBar.Size=UDim2.fromOffset(2,18)
                tab.SelectionBar.Visible=(w.CurrentTab==tab)
                tab.SelectionBar.BackgroundTransparency=(w.CurrentTab==tab) and 0 or 1
            end
            local glyph=tab.NavButton and tab.NavButton:FindFirstChildOfClass("Frame")
            if glyph then
                glyph.Position=UDim2.fromOffset(phone and 4 or 6,phone and 5 or 4)
                glyph.Visible=sidebarWidth>=76
            end
            if tab.NavTitle then
                tab.NavTitle.Position=UDim2.fromOffset(phone and 23 or 26,0)
                tab.NavTitle.Size=UDim2.new(1,phone and -25 or -30,1,0)
                tab.NavTitle.TextSize=phone and 9 or 10
            end
        end
        for _,section in ipairs(w.Groups) do
            local group=section.ElementFrame
            if group then
                local heading=group:FindFirstChildOfClass("TextLabel")
                if heading then
                    heading.TextSize=phone and 8 or 9
                    heading.Size=UDim2.new(1,-6,0,phone and 18 or 20)
                end
            end
        end

        -- Botón flotante también se adapta a pantallas angostas.
        if bounds.X<380 then
            openButton.Size=UDim2.fromOffset(math.min(138,math.max(112,bounds.X-20)),38)
            openLabel.Text="Abrir Xero"
            openLabel.TextSize=11
        else
            openButton.Size=UDim2.fromOffset(154,40)
            openLabel.Text="Abrir XeroHub"
            openLabel.TextSize=12
        end
        if not w._launcherMoved then
            local launcherWidth=openButton.Size.X.Offset
            openButton.Position=UDim2.fromOffset(math.max(0,math.floor((bounds.X-launcherWidth)/2)),16)
        end

        w:_drawer(false)
        clampRoot()
        clampLauncher()
        if not skipContentLayout then
            for _,tab in ipairs(w.Tabs) do tab:_queueFilter() end
        end
    end
    w._fit=fit
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
            tab.NavButton.BackgroundColor3=selected and C.Row or Color3.fromRGB(11,11,11)
            tab.NavTitle.TextColor3=selected and C.Text or C.Muted
            if tab.Number then tab.Number.TextColor3=selected and C.Text or C.Faint end
            if tab.SelectionBar then
                tab.SelectionBar.Visible=selected
                tab.SelectionBar.BackgroundTransparency=selected and 0 or 1
            end
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
        local list=scroll(page,{Name="Options",AutomaticCanvasSize=Enum.AutomaticSize.None}); vertical(list,5); padding(list,2,4)
        local empty=label(page,"Sin coincidencias. Prueba otra búsqueda.",12,C.Muted,{Position=UDim2.fromOffset(12,18),Size=UDim2.new(1,-24,0,50),TextWrapped=true,Visible=false})
        local navButton=button(holder or nav,"",{Name=title,Size=UDim2.new(1,0,0,28),BackgroundColor3=Color3.fromRGB(10,10,10),LayoutOrder=index})
        round(navButton,8)
        local selectionBar=new("Frame",{Name="Selected",Position=UDim2.fromOffset(1,5),Size=UDim2.fromOffset(2,18),
            BackgroundColor3=C.Text,BackgroundTransparency=0,Visible=false,ZIndex=3},navButton); round(selectionBar,2)
        local glyph=icon(navButton,title); glyph.Position=UDim2.fromOffset(6,4)
        local titleLabel=label(navButton,title,10,C.Muted,{Position=UDim2.fromOffset(26,0),Size=UDim2.new(1,-30,1,0),Font=MEDIUM,TextTruncate=Enum.TextTruncate.AtEnd})
        tab.Page,tab.Content,tab.Empty=page,list,empty; tab.NavButton,tab.NavTitle=navButton,titleLabel
        tab.Number=glyph:FindFirstChildOfClass("TextLabel"); tab.SelectionBar=selectionBar
        table.insert(self.Tabs,tab)
        connect(self,navButton.Activated,function() self:SelectTab(tab) end)
        connect(self,navButton.MouseEnter,function() if self.CurrentTab~=tab then navButton.BackgroundColor3=Color3.fromRGB(18,18,18) end end)
        connect(self,navButton.MouseLeave,function() if self.CurrentTab~=tab then navButton.BackgroundColor3=Color3.fromRGB(11,11,11) end end)
        connect(self,list:GetPropertyChangedSignal("AbsoluteSize"),function() tab:_queueFilter() end)
        if not self.CurrentTab then self:SelectTab(tab) end
        return tab
    end
    function w:Tab(options) return self:_tab(options) end
    function w:Section(options)
        local opt=options or {}; self._navOrder+=1
        local group=new("Frame",{Name=plain(opt.Title),BackgroundTransparency=1,Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,LayoutOrder=self._navOrder},nav)
        vertical(group,6)
        local heading=label(group,string.upper(plain(opt.Title or "GENERAL")),9,C.Faint,{Size=UDim2.new(1,-8,0,20),Font=BOLD,LayoutOrder=0,TextWrapped=true})
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
    function w:SetTitle(title)
        self.Title=plain(title)
        footer.Text=self.Title
        local active=self.Title:match("(%d+)%s+activos")
        if active then
            statusLabel.Text=active.." activos"
            if self._fit then self._fit(true) end
        end
        return self
    end
    function w:SetAuthor(text) self.Author=plain(text); author.Text=self.Author end
    function w:SetSize(size)
        self._desiredWidth=math.max(1,size.X.Offset); self._desiredHeight=math.max(1,size.Y.Offset); fit(); return self
    end
    function w:GetSize() return Vector2.new(self._desiredWidth,self._desiredHeight) end
    function w:SetResizable(value)
        self.Resizable=value~=false
        for _,info in ipairs(resizeHandles) do info.Hit.Visible=self.Resizable end
        for _,grip in ipairs(resizeVisuals) do grip.Visible=self.Resizable end
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
        if value==nil then
            self._openButtonEnabled=true
        else
            self._openButtonEnabled=value~=false
        end
        self:_applyOpenButtonState()
        return self
    end
    function w:SetOpenButtonGhosted(value)
        self._openButtonGhosted=value==true
        self:_applyOpenButtonState()
        return self
    end
    function w:EditOpenButton(config)
        if config.Enabled~=nil then self:SetOpenButtonVisible(config.Enabled) end
        if config.Ghosted~=nil then self:SetOpenButtonGhosted(config.Ghosted) end
        if config.Title then openLabel.Text=plain(config.Title) end
        return self
    end
    function w:OnDestroy(callback) table.insert(self._onDestroy,callback); return self end
    function w:OnOpen(callback) table.insert(self._onOpen,callback); return self end
    function w:OnClose(callback) table.insert(self._onClose,callback); return self end
    function w:Open()
        if self.Destroyed then return self end
        local changed=not self.Opened; self.Opened=true; root.Visible=true
        self:_applyOpenButtonState()
        if changed then for _,callback in ipairs(self._onOpen) do invoke(callback) end end
        return self
    end
    function w:Close()
        if self.Destroyed then return self end
        local changed=self.Opened; self.Opened=false; root.Visible=false; self:_closePopup()
        self:_applyOpenButtonState()
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
        local cfg=config or {}; local panel=self:_popup(plain(cfg.Title or "XeroHub"),350,230,nil)
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
        w:Dialog({Title="Cerrar XeroHub",Content="Se cerrará el panel y se limpiará esta sesión. Puedes volver a ejecutar el hub cuando quieras.",
            Buttons={{Title="Volver"},{Title="Cerrar",Callback=function() w:Destroy() end}}})
    end)
    -- Sin drawer: las categorías permanecen visibles todo el tiempo.
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
                    w._launcherMoved=true
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
            local maxScreenW=math.max(260,bounds.X)
            local maxScreenH=math.max(220,bounds.Y)
            local minScreenW=math.min(w._minWidth*w.UIScale,maxScreenW)
            local minScreenH=math.min(w._minHeight*w.UIScale,maxScreenH)
            local screenW=math.clamp(startWidth+info.X*delta.X,minScreenW,maxScreenW)
            local screenH=math.clamp(startHeight+info.Y*delta.Y,minScreenH,maxScreenH)
            w._desiredWidth=screenW/w.UIScale
            w._desiredHeight=screenH/w.UIScale
            root.Size=UDim2.fromOffset(w._desiredWidth,w._desiredHeight)
            if not w._resizeFitQueued then
                w._resizeFitQueued=true
                task.defer(function()
                    RunService.RenderStepped:Wait()
                    w._resizeFitQueued=false
                    if not w.Destroyed then fit(true) end
                end)
            end
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
    footer.Text="XEROHUB  /  KEV"
    task.defer(fit)
    return w
end
function Nox:SetTheme(name)
    -- "Onyx" sigue aceptado como alias para no romper llamadas antiguas.
    self.Theme={Name="Xero",Accent=C.White,Background=C.Window,Text=C.Text}
    return self.Theme
end
function Nox:GetCurrentTheme() return "Xero" end
function Nox:GetThemes() return {Xero={Name="Xero"},Nox={Name="Xero"},Onyx={Name="Xero"}} end
function Nox:Notify(options)
    if not self.Window then return end
    local w=self.Window; local o=options or {}
    if w.Destroyed then return end
    if w._notice then w._notice:Destroy() end
    local holder=new("Frame",{Name="XeroNotice",BackgroundColor3=C.Row,AnchorPoint=Vector2.new(.5,0),
        Position=UDim2.new(.5,0,0,12),Size=UDim2.new(1,-24,0,0),AutomaticSize=Enum.AutomaticSize.Y,ZIndex=100},w.ScreenGui)
    new("UISizeConstraint",{MaxSize=Vector2.new(360,math.huge)},holder)
    round(holder,12); stroke(holder); padding(holder,14,12); vertical(holder,6)
    label(holder,plain(o.Title or "XeroHub"),13,C.Text,{Font=BOLD,LayoutOrder=1})
    label(holder,plain(o.Content or o.Desc),12,C.Muted,{Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,TextWrapped=true,LayoutOrder=2})
    w._notice=holder
    task.delay(math.clamp(tonumber(o.Duration) or 2,1,8),function()
        if holder.Parent then holder:Destroy() end
        if w._notice==holder then w._notice=nil end
    end)
    return {Close=function() if holder.Parent then holder:Destroy() end end}
end
Nox:SetTheme("Xero")
return Nox
