-- TSC HUB (Thunder Scientific) — hook-frei: nur Lighting-Props + eigene GUI/Adornments in CoreGui
-- Start: loadstring(readfile("tsc_hub.lua"))()   Toggle GUI: RightShift (umbelegbar unter Settings)

-- altes Hub komplett killen
if _G.__TSC_HUB and _G.__TSC_HUB.kill then pcall(_G.__TSC_HUB.kill) end
local H = { conns = {}, alive = true }
_G.__TSC_HUB = H

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local CoreGui = game:GetService("CoreGui")
local lp = Players.LocalPlayer
local cam = workspace.CurrentCamera

local function con(sig, fn) local c = sig:Connect(fn) table.insert(H.conns, c) return c end

-- Persistenz: Einstellungen in tsc_hub_settings.json (überlebt Re-Execute/Rejoin)
local HttpService = game:GetService("HttpService")
local SAVE_FILE = "tsc_hub_settings.json"
local saved = {}
pcall(function() if isfile(SAVE_FILE) then saved = HttpService:JSONDecode(readfile(SAVE_FILE)) end end)
if type(saved) ~= "table" then saved = {} end
local function sv(k, def) if saved[k] ~= nil then return saved[k] end return def end
local function kc(n, def)
	if type(n) ~= "string" then return def end
	local ok, k = pcall(function() return Enum.KeyCode[n] end); if ok and k then return k end
	ok, k = pcall(function() return Enum.UserInputType[n] end); if ok and k then return k end
	return def
end
-- Keybind = KeyCode oder Maustaste (UserInputType)
local function keyMatch(i, k) if k.EnumType == Enum.KeyCode then return i.KeyCode == k end return i.UserInputType == k end
local function keyHeld(k) if k.EnumType == Enum.KeyCode then return UIS:IsKeyDown(k) end return UIS:IsMouseButtonPressed(k) end
local SAVE_KEYS = { "fullbright", "esp", "espDist", "espFade", "espFadePow", "bright", "items", "perf", "updInt", "nofall", "staff", "markId", "markName",
	"vent", "ventPred", "ventLog", "ventBias", "ms", "msReader", "msHints", "msFlags", "msPace", "turrets", "pkgSel", "collapsed", "desyncDepth", "nofog",
	"aim", "aimTeam", "aimVis", "aimHealth", "aimSticky", "aimDist", "aimSens", "aimPart", "aimType", "aimRage", "aimRageType",
	"aimPred", "aimPredX", "aimPredY", "aimSmooth", "aimSmX", "aimSmY", "fov", "fovGlow", "fovFill", "fovSize", "fovStyle", "fovColor", "fovGunOnly", "aimGunOnly" , "alarms", "alarmDist" , "alarmOff" , "alarmDel",
	"espBox", "espBoxStyle", "espBoxFill", "espHealth", "espName", "espDistTxt", "espTextSize2", "espTracer", "espTracerFov",
	"espTracerFrom", "espTeamCol", "espTargetCol", "espHideTeam", "msClickDelay", "nostam", "doorphase", "radioSpy", "radioOverlay", "chatLog", "chatOverlay", "norecoil", "ventFake", "ventFakeIdx", "autoreload", "disgDetect", "radioPos", "chatPos", "nospread", "fakeTranslator", "maxcharge", "aura", "auraRange", "auraTeam", "auraDelay2", "auraSmooth2", "auraRing", "adonisMon", "adonisOverlay", "infAbil", "ventLock", "staffPos", "bingoNotify", "bingoAuto", "clickTp", "tpDetail", "tpBubbleSpeed", "tpZH", "antiAfk", "dmgOff", "dmgShow" , "auraForceMax" , "infEsp" , "view" , "viewPos" , "espTeamTag" , "ventJam" , "silentStep" , "silentStepCloak" , "cmdFx" , "senseWarn" , "senseRange" , "senseRings" , "senseOverlay" , "senseOnlyInf" , "sensePos"  , "itType" , "itWait" , "ventEsp" , "ventEspHL" , "autoRevive" , "wallbang" , "wbRadius" , "trkEsp" , "trkRings" , "trkOnlyInf" , "auraIndPos" }

local state = { fullbright = sv("fullbright", false), esp = sv("esp", false), espDist = sv("espDist", 1500),
	espFade = sv("espFade", 0.4), espFadePow = sv("espFadePow", 2), bright = sv("bright", 2), markId = sv("markId", nil), markName = sv("markName", nil),
	keys = { menu = kc(sv("keyMenu", "RightShift"), Enum.KeyCode.RightShift), vent = kc(sv("keyVent", "End"), Enum.KeyCode.End),
		aim = kc(sv("keyAim", "MouseButton2"), Enum.UserInputType.MouseButton2),
		aura = kc(sv("keyAura", "F14"), Enum.KeyCode.F14), cloak = kc(sv("keyCloak", "F"), Enum.KeyCode.F) } }
H.state = state

-- ================= THEME / GUI-BAUKASTEN (Matcha-Stil) =================
local T = {
	bg = Color3.fromRGB(15, 15, 18), panel = Color3.fromRGB(20, 20, 24), panel2 = Color3.fromRGB(25, 25, 30),
	stroke = Color3.fromRGB(36, 36, 43), edge = Color3.fromRGB(46, 46, 54), track = Color3.fromRGB(32, 32, 38),
	off = Color3.fromRGB(34, 34, 41), accent = Color3.fromRGB(190, 70, 150), text = Color3.fromRGB(226, 226, 232),
	dim = Color3.fromRGB(122, 122, 134), font = Enum.Font.GothamMedium, bold = Enum.Font.GothamBold, ts = 13,
}

local gui = Instance.new("ScreenGui")
gui.Name = "TSC_HUB"; gui.ResetOnSpawn = false; gui.IgnoreGuiInset = true; gui.DisplayOrder = 999
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = CoreGui

local espFolder = Instance.new("Folder"); espFolder.Name = "TSC_ESP"; espFolder.Parent = gui

local function stroke(o, c) local s = Instance.new("UIStroke"); s.Color = c or T.stroke; s.Thickness = 1
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border; s.Parent = o; return s end
local function corner(o, r) Instance.new("UICorner", o).CornerRadius = UDim.new(0, r or 3) end
local function txt(parent, text, size, color)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1; l.Font = T.font; l.TextSize = T.ts; l.TextColor3 = color or T.text
	l.Text = text; l.TextXAlignment = Enum.TextXAlignment.Left; l.Size = size; l.Parent = parent
	return l
end

local main = Instance.new("Frame")
main.Size = UDim2.fromOffset(560, 500); main.Position = UDim2.fromOffset(sv("guiX", 40), sv("guiY", 160))
main.Visible = sv("guiVisible", true)
main.BackgroundColor3 = T.bg; main.BorderSizePixel = 0; main.Active = true
main.Parent = gui
corner(main, 8); stroke(main, T.edge)

local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 30); titleBar.BackgroundTransparency = 1; titleBar.Active = true; titleBar.Parent = main
do
	local tl2 = Instance.new("UIListLayout", titleBar); tl2.FillDirection = Enum.FillDirection.Horizontal
	tl2.VerticalAlignment = Enum.VerticalAlignment.Center; tl2.Padding = UDim.new(0, 8); tl2.SortOrder = Enum.SortOrder.LayoutOrder
	Instance.new("UIPadding", titleBar).PaddingLeft = UDim.new(0, 12)
	local a = txt(titleBar, "RSC Hub", UDim2.fromOffset(0, 30), T.accent); a.Font = T.bold; a.AutomaticSize = Enum.AutomaticSize.X; a.LayoutOrder = 1
	local b = txt(titleBar, "Interface", UDim2.fromOffset(0, 30), T.text); b.AutomaticSize = Enum.AutomaticSize.X; b.LayoutOrder = 2
	local c = txt(titleBar, lp.Name, UDim2.fromOffset(0, 18), T.accent); c.AutomaticSize = Enum.AutomaticSize.X; c.LayoutOrder = 3
	c.TextSize = 12; c.BackgroundColor3 = Color3.fromRGB(40, 18, 34); c.BackgroundTransparency = 0; corner(c, 6); stroke(c, Color3.fromRGB(90, 34, 72))
	local cp = Instance.new("UIPadding", c); cp.PaddingLeft = UDim.new(0, 7); cp.PaddingRight = UDim.new(0, 7)
end

-- Drag
do
	local dragging, startPos, startMouse
	con(titleBar.InputBegan, function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true; startPos = main.Position; startMouse = i.Position end
	end)
	con(UIS.InputChanged, function(i)
		if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then
			local d = i.Position - startMouse
			main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
		end
	end)
	con(UIS.InputEnded, function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end end)
end

-- Tabs
local tabBar = Instance.new("Frame")
tabBar.Size = UDim2.new(1, -20, 0, 26); tabBar.Position = UDim2.fromOffset(8, 32); tabBar.BackgroundTransparency = 1; tabBar.Parent = main
local tl = Instance.new("UIListLayout", tabBar); tl.FillDirection = Enum.FillDirection.Horizontal; tl.Padding = UDim.new(0, 4)
tl.SortOrder = Enum.SortOrder.LayoutOrder

local content = Instance.new("Frame")
content.Size = UDim2.new(1, -16, 1, -74); content.Position = UDim2.fromOffset(8, 66); content.BackgroundTransparency = 1
content.Parent = main

local pages, tabBtns, tabStrokes = {}, {}, {}
local function selectTab(name)
	for n, pg in pairs(pages) do pg.Visible = (n == name) end
	for n, b in pairs(tabBtns) do
		local on = n == name
		b.TextColor3 = on and T.text or T.dim; b.BackgroundTransparency = on and 0 or 1; tabStrokes[n].Transparency = on and 0 or 1
	end
end
local function mkCol(page, right)
	local c = Instance.new("ScrollingFrame")
	c.BackgroundTransparency = 1; c.BorderSizePixel = 0; c.ScrollBarThickness = 2; c.ScrollBarImageColor3 = T.accent
	c.Size = UDim2.new(0.5, -4, 1, 0); c.Position = right and UDim2.new(0.5, 4, 0, 0) or UDim2.new()
	c.AutomaticCanvasSize = Enum.AutomaticSize.Y; c.CanvasSize = UDim2.new(); c.Parent = page
	local l = Instance.new("UIListLayout", c); l.Padding = UDim.new(0, 8); l.SortOrder = Enum.SortOrder.LayoutOrder
	local p = Instance.new("UIPadding", c)
	p.PaddingTop = UDim.new(0, 1); p.PaddingLeft = UDim.new(0, 1); p.PaddingRight = UDim.new(0, 5); p.PaddingBottom = UDim.new(0, 1)
	return c
end
local function tab(name, raw)
	local b = Instance.new("TextButton")
	b.AutomaticSize = Enum.AutomaticSize.X; b.Size = UDim2.new(0, 0, 1, 0); b.BackgroundTransparency = 1
	b.BackgroundColor3 = T.panel2; b.AutoButtonColor = false
	b.Font = T.font; b.TextSize = T.ts; b.Text = name; b.TextColor3 = T.dim; b.LayoutOrder = #tabBar:GetChildren()
	b.Parent = tabBar
	corner(b, 6); tabStrokes[name] = stroke(b, T.edge)
	local bp = Instance.new("UIPadding", b); bp.PaddingLeft = UDim.new(0, 12); bp.PaddingRight = UDim.new(0, 12)
	local page = Instance.new("Frame"); page.Size = UDim2.fromScale(1, 1); page.BackgroundTransparency = 1; page.Visible = false
	page.Parent = content
	pages[name] = page; tabBtns[name] = b
	con(b.MouseButton1Click, function() selectTab(name) end)
	if raw then return page end
	return mkCol(page, false), mkCol(page, true)
end

-- Unter-Tabs (Pill-Leiste oben in einer Seite), liefert je Unter-Tab {links, rechts}
local function subtabs(page, names)
	local bar = Instance.new("Frame")
	bar.Size = UDim2.new(0, 0, 0, 28); bar.AutomaticSize = Enum.AutomaticSize.X; bar.BackgroundColor3 = T.panel
	bar.Parent = page
	corner(bar, 7); stroke(bar)
	local bl = Instance.new("UIListLayout", bar); bl.FillDirection = Enum.FillDirection.Horizontal; bl.Padding = UDim.new(0, 2)
	bl.VerticalAlignment = Enum.VerticalAlignment.Center; bl.SortOrder = Enum.SortOrder.LayoutOrder
	local bpad = Instance.new("UIPadding", bar); bpad.PaddingLeft = UDim.new(0, 3); bpad.PaddingRight = UDim.new(0, 3)
	local subs, btns, out = {}, {}, {}
	local function pick(n)
		for k, f in pairs(subs) do f.Visible = (k == n) end
		for k, b in pairs(btns) do
			local on = k == n
			b.TextColor3 = on and T.accent or T.dim; b.BackgroundTransparency = on and 0 or 1
		end
	end
	for i, n in ipairs(names) do
		local b = Instance.new("TextButton")
		b.AutomaticSize = Enum.AutomaticSize.X; b.Size = UDim2.new(0, 0, 0, 22); b.BackgroundColor3 = T.panel2
		b.BackgroundTransparency = 1; b.AutoButtonColor = false; b.Font = T.font; b.TextSize = 12; b.Text = n
		b.TextColor3 = T.dim; b.LayoutOrder = i; b.Parent = bar
		corner(b, 5)
		local pp = Instance.new("UIPadding", b); pp.PaddingLeft = UDim.new(0, 10); pp.PaddingRight = UDim.new(0, 10)
		local f = Instance.new("Frame")
		f.Size = UDim2.new(1, 0, 1, -36); f.Position = UDim2.fromOffset(0, 36); f.BackgroundTransparency = 1; f.Visible = false
		f.Parent = page
		subs[n] = f; btns[n] = b
		out[n] = { mkCol(f, false), mkCol(f, true) }
		con(b.MouseButton1Click, function() pick(n) end)
	end
	pick(names[1])
	return out
end

local secN = 0
local function section(col, name)
	secN = secN + 1
	local f = Instance.new("Frame")
	f.BackgroundColor3 = T.panel; f.BorderSizePixel = 0; f.Size = UDim2.new(1, 0, 0, 0); f.AutomaticSize = Enum.AutomaticSize.Y
	f.LayoutOrder = secN; f.Parent = col
	stroke(f); corner(f, 7)
	local pd = Instance.new("UIPadding", f)
	pd.PaddingTop = UDim.new(0, 8); pd.PaddingBottom = UDim.new(0, 10); pd.PaddingLeft = UDim.new(0, 10); pd.PaddingRight = UDim.new(0, 10)
	local l = Instance.new("UIListLayout", f); l.Padding = UDim.new(0, 7); l.SortOrder = Enum.SortOrder.LayoutOrder
	local h = txt(f, name, UDim2.new(1, 0, 0, 16)); h.Font = T.bold; h.LayoutOrder = 0
	return { f = f, n = 0 }
end
local function nextOrder(S) S.n = S.n + 1 return S.n end

-- Keybinds: Klick auf Box -> nächste Taste belegen (Escape = abbrechen)
local listening, keyBoxes = nil, {}
local KEY_ALIAS = { F13 = "mouse4", F14 = "mouse5" } -- tools/MouseBridge: Maus 4/5 -> F13/F14 (Roblox kennt keine Seitentasten)
local function keyName(k)
	if not k then return "none" end
	return KEY_ALIAS[k.Name] or (k.Name:lower():gsub("mousebutton", "mouse"))
end
local function keybox(parent, id)
	local b = Instance.new("TextButton")
	b.Size = UDim2.fromOffset(78, 18); b.AnchorPoint = Vector2.new(1, 0); b.Position = UDim2.new(1, 0, 0, 0)
	b.BackgroundColor3 = T.panel2; b.BorderSizePixel = 0; b.AutoButtonColor = false
	b.Font = T.font; b.TextSize = 12; b.TextColor3 = T.text; b.Text = keyName(state.keys[id]); b.Parent = parent
	stroke(b, T.edge); corner(b, 9)
	keyBoxes[id] = b
	con(b.MouseButton1Click, function() listening = id; b.Text = "..."; b.TextColor3 = T.accent end)
	return b
end

local refresh = {}
local ctl = {} -- Config: [id] = {get=, set=}
H.ctl = ctl -- Panik-Modus schaltet damit alles ueber die echten Aus-Handler ab
local function toggle(S, label, key, onChange, bindId)
	local row = Instance.new("TextButton")
	row.AutoButtonColor = false; row.BackgroundTransparency = 1; row.Text = ""; row.Size = UDim2.new(1, 0, 0, 18)
	row.LayoutOrder = nextOrder(S); row.Parent = S.f
	local dot = Instance.new("Frame")
	dot.Size = UDim2.fromOffset(17, 17); dot.Position = UDim2.fromOffset(0, 0); dot.BorderSizePixel = 0; dot.Parent = row
	corner(dot, 4)
	stroke(dot)
	local l = txt(row, label, UDim2.new(1, bindId and -112 or -28, 1, 0)); l.Position = UDim2.fromOffset(27, 0)
	if bindId then keybox(row, bindId) end
	local function paint()
		local on = state[key]
		dot.BackgroundColor3 = on and T.accent or T.off
		l.TextColor3 = on and T.text or T.dim
	end
	paint()
	if state[key] then task.spawn(onChange, true) end -- gespeicherten Zustand anwenden
	con(row.MouseButton1Click, function() state[key] = not state[key]; paint(); task.spawn(onChange, state[key]) end)
	refresh[key] = paint
	ctl[key] = { get = function() return state[key] end,
		set = function(v) if state[key] ~= v then state[key] = v; paint(); task.spawn(onChange, v) end end }
	return paint, row
end

local function keyRow(S, label, id)
	local row = Instance.new("Frame"); row.BackgroundTransparency = 1; row.Size = UDim2.new(1, 0, 0, 16)
	row.LayoutOrder = nextOrder(S); row.Parent = S.f
	txt(row, label, UDim2.new(1, -84, 1, 0))
	keybox(row, id)
end

-- Slider: Label oben, Pill mit pinker Füllung + Wert mittig; onSet(v) liefert Werttext
local function slider(S, label, minV, maxV, init, onSet, id)
	local head = Instance.new("Frame"); head.BackgroundTransparency = 1; head.Size = UDim2.new(1, 0, 0, 15)
	head.LayoutOrder = nextOrder(S); head.Parent = S.f
	txt(head, label, UDim2.new(1, -70, 1, 0))
	local val = txt(head, "", UDim2.new(0, 70, 1, 0), T.text)
	val.AnchorPoint = Vector2.new(1, 0); val.Position = UDim2.new(1, 0, 0, 0); val.TextXAlignment = Enum.TextXAlignment.Right
	local hit = Instance.new("Frame"); hit.BackgroundTransparency = 1; hit.Size = UDim2.new(1, 0, 0, 12); hit.Active = true
	hit.LayoutOrder = nextOrder(S); hit.Parent = S.f
	local bar = Instance.new("Frame")
	bar.Size = UDim2.new(1, 0, 0, 6); bar.Position = UDim2.fromOffset(0, 3); bar.BackgroundColor3 = T.track; bar.BorderSizePixel = 0
	bar.Parent = hit
	corner(bar, 3)
	local fill = Instance.new("Frame")
	fill.BackgroundColor3 = T.accent; fill.BorderSizePixel = 0; fill.Parent = bar
	corner(fill, 3)
	local raw = init
	local function set(v)
		v = math.clamp(v, minV, maxV); raw = v
		fill.Size = UDim2.new((v - minV) / (maxV - minV), 0, 1, 0)
		val.Text = onSet(v)
	end
	set(init)
	if id then ctl[id] = { get = function() return raw end, set = set } end
	local sliding = false
	local function fromX(x) set(minV + (x - bar.AbsolutePosition.X) / bar.AbsoluteSize.X * (maxV - minV)) end
	con(hit.InputBegan, function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 then sliding = true; fromX(i.Position.X) end
	end)
	con(UIS.InputChanged, function(i)
		if sliding and i.UserInputType == Enum.UserInputType.MouseMovement then fromX(i.Position.X) end
	end)
	con(UIS.InputEnded, function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then sliding = false end end)
	return set
end

local function dropdown(S, label, opts, idx, onSel, id)
	txt(S.f, label, UDim2.new(1, 0, 0, 14)).LayoutOrder = nextOrder(S)
	local box = Instance.new("TextButton")
	box.Size = UDim2.new(1, 0, 0, 28); box.BackgroundColor3 = T.panel2; box.BorderSizePixel = 0; box.AutoButtonColor = false
	box.Text = ""; box.LayoutOrder = nextOrder(S); box.Parent = S.f
	stroke(box); corner(box, 6)
	local cur = txt(box, opts[idx], UDim2.new(1, -34, 1, 0)); cur.Position = UDim2.fromOffset(10, 0)
	local arr = txt(box, "▼", UDim2.new(0, 14, 1, 0), T.dim); arr.Position = UDim2.new(1, -22, 0, 0); arr.TextSize = 10
	local list = Instance.new("Frame")
	list.Size = UDim2.new(1, 0, 0, 0); list.AutomaticSize = Enum.AutomaticSize.Y; list.BackgroundColor3 = T.bg
	list.BorderSizePixel = 0; list.Visible = false; list.LayoutOrder = nextOrder(S); list.Parent = S.f
	stroke(list); corner(list, 6)
	Instance.new("UIListLayout", list).SortOrder = Enum.SortOrder.LayoutOrder
	local items = {}
	local function paint() for i, b in ipairs(items) do b.TextColor3 = (i == idx) and T.accent or T.dim end end
	for i, o in ipairs(opts) do
		local b = Instance.new("TextButton")
		b.Size = UDim2.new(1, 0, 0, 22); b.BackgroundTransparency = 1; b.Font = T.font; b.TextSize = 12
		b.Text = "   " .. o; b.TextXAlignment = Enum.TextXAlignment.Left; b.LayoutOrder = i; b.Parent = list
		items[i] = b
		con(b.MouseButton1Click, function()
			idx = i; cur.Text = o; list.Visible = false; arr.Text = "▼"; paint(); task.spawn(onSel, i)
		end)
	end
	paint()
	if id then ctl[id] = { get = function() return idx end,
		set = function(i) if opts[i] then idx = i; cur.Text = opts[i]; paint(); task.spawn(onSel, i) end end } end
	con(box.MouseButton1Click, function() list.Visible = not list.Visible; arr.Text = list.Visible and "▲" or "▼" end)
end

local function button(S, label, fn)
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(1, 0, 0, 26); b.BackgroundColor3 = T.panel2; b.BorderSizePixel = 0; b.AutoButtonColor = false
	b.Font = T.font; b.TextSize = 12; b.TextColor3 = T.text; b.Text = label; b.LayoutOrder = nextOrder(S); b.Parent = S.f
	stroke(b); corner(b, 6)
	con(b.MouseButton1Click, fn)
	con(b.MouseEnter, function() b.TextColor3 = T.accent end)
	con(b.MouseLeave, function() b.TextColor3 = T.text end)
	return b
end

local function info(S, text, color)
	local l = txt(S.f, text, UDim2.new(1, 0, 0, 0), color or T.dim)
	l.AutomaticSize = Enum.AutomaticSize.Y; l.TextWrapped = true; l.RichText = true; l.TextSize = 12
	l.LayoutOrder = nextOrder(S)
	return l
end

-- Seiten + Sektionen
local comPage = tab("Combat", true)
local visL, visR = tab("Visuals")
local miscL, miscR = tab("Misc")
local optL, optR = tab("Options")
local cfgL = tab("Config")
local plL, plR = tab("Players")

local S_light = section(visL, "Lighting")
local S_items = section(visL, "Items")
local S_esp = section(visR, "ESP")
local S_staff = section(visR, "Staff Radar")
local S_vent = section(miscL, "Auto Vent")
local S_ms = section(miscL, "Auto Hack (Minesweeper)")
local S_move = section(miscR, "Movement")
local S_world = section(miscR, "World")
local S_pkg = section(miscR, "Packages (Dead Drops)")
local S_menu = section(optL, "Menu")
local S_perf = section(optR, "Performance")
local S_cfg = section(cfgL, "Config")
local S_mark = section(plL, "Target")
local S_plInfo = section(plR, "Info")

-- ================= AUTO VENT =================
-- Spiel (VentSystemL, jedes RenderStepped): u8 = (MausX - Frame.AbsX)/Frame.AbsW; drin wenn Green.X < u8 < Green.X+Green.W
-- (Green vom letzten Frame), danach bewegt sich Green (prallt an 0/u7 ab). Marker.X = gelesenes u8.
-- Hook-frei (namecall-Hook = Kick!), keine Remotes: nur GUI lesen + echten Cursor (mousemoveabs) setzen.
-- Heartbeat läuft nach dem Green-Update; Lag wird über Marker.X vs. eigene Befehle gemessen, Vorhersage prallt ab.
-- M1 hält man selbst.
-- "Lock Bar To Mouse": statt den Cursor zu bewegen (2-6 Frames Eingabe-Lag -> Vorhersage wackelt) wird der lokale Frame so
-- verschoben, dass die Maus genau in der Mitte von Green liegt. u8 hängt nur von MausX und Frame.AbsX ab -> kein Lag.
state.vent = sv("vent", true); state.ventPred = sv("ventPred", true); state.ventLog = sv("ventLog", true); state.ventBias = sv("ventBias", 0)
state.ventLock = sv("ventLock", true)
local V = { hist = {}, lagF = 1, prevP = nil, prevW = 0, dir = 1, mult = 1, open = false, st = nil, wasRed = false, last = "-" }
local VENT_LOG, MAX_LAG = "_autovent_log.txt", 6
local focused = (typeof(isrbxactive) == "function") and isrbxactive or function() return true end
local hasMove = typeof(mousemoveabs) == "function"

local function ventParts()
	local pg = lp:FindFirstChild("PlayerGui"); local mg = pg and pg:FindFirstChild("VentMinigame"); if not mg then return end
	local fr = mg:FindFirstChild("Frame"); if not fr or not fr.Visible then return end
	local gr = fr:FindFirstChild("Green"); if not gr then return end
	return fr, gr, fr:FindFirstChild("Marker")
end
-- Green um dist (Scale) in [0, u7] weiterschieben, an den Rändern abprallen wie im Spiel
local function advance(p, d, dist, u7)
	if u7 <= 0 then return 0 end
	local q = p + d * dist
	for _ = 1, 4 do
		if q > u7 then q = 2 * u7 - q elseif q < 0 then q = -q else break end
	end
	return math.clamp(q, 0, u7)
end
local function ventFlush()
	local st = V.st; V.st = nil
	if not st or st.frames == 0 then return end
	V.last = ("%d fails · min %.0fpx · %.1fs"):format(st.fails, st.minPx < 1e8 and st.minPx or 0, os.clock() - st.t0)
	if not state.ventLog then return end
	local line = ("[%s] %.1fs frames=%d drillFrames=%d outWhileDrill=%d fails=%d minMarginPx=%.1f edgeOut=%d lagF=%.2f mult=%.2f %s\n"):format(
		os.date("%H:%M:%S"), os.clock() - st.t0, st.frames, st.drill, st.out, st.fails, st.minPx, st.edgeOut, V.lagF, V.mult, table.concat(st.notes, " "))
	pcall(function()
		if typeof(appendfile) == "function" and isfile(VENT_LOG) then appendfile(VENT_LOG, line)
		else writefile(VENT_LOG, (isfile(VENT_LOG) and readfile(VENT_LOG) or "") .. line) end
	end)
end

con(RunService.Heartbeat, function(dt)
	local fr, gr, mk = ventParts()
	if not state.vent or not fr then
		if V.open then ventFlush(); V.hist = {}; V.prevP = nil; V.open = false end
		if V.origPos then pcall(function() V.frame.Position = V.origPos end); V.origPos = nil end
		return
	end
	if not V.open then
		V.open = true
		V.st = { t0 = os.clock(), frames = 0, drill = 0, out = 0, fails = 0, minPx = 1e9, edgeOut = 0, notes = {} }
	end
	local st = V.st
	local p, w = gr.Position.X.Scale, gr.Size.X.Scale
	local u7 = 1 - w

	if V.prevP then
		-- Telemetrie: Marker = u8, das das Spiel diesen Frame gegen Green des Vorframes geprüft hat
		if mk then
			local m, pp, pw = mk.Position.X.Scale, V.prevP, V.prevW
			local mar = math.min(m - pp, pp + pw - m) * fr.AbsoluteSize.X
			local bc = fr.BackgroundColor3
			st.frames = st.frames + 1
			if bc.R > 0.35 and bc.G < 0.15 then -- Frame rot = am Bohren
				st.drill = st.drill + 1
				st.minPx = math.min(st.minPx, mar)
				if mar <= 0 then
					st.out = st.out + 1
					if pp < 0.01 or pp > (1 - pw) - 0.01 then st.edgeOut = st.edgeOut + 1 end
				end
			end
			local c = gr.BackgroundColor3
			local red = c.R > 0.95 and c.G < 0.05 and c.B < 0.05
			if red and not V.wasRed then
				st.fails = st.fails + 1
				st.notes[#st.notes + 1] = ("FAIL(m=%.3f g=%.3f..%.3f focus=%s)"):format(m, pp, pp + pw, tostring(focused()))
			end
			V.wasRed = red
		end
		-- Richtung + Tempo-Multiplikator (Tools) aus der Bewegung
		if p ~= V.prevP then
			if p <= 1e-6 then V.dir = 1
			elseif p >= u7 - 1e-6 then V.dir = -1
			else
				V.dir = (p > V.prevP) and 1 or -1
				if u7 > 0.01 and dt > 0 then
					local m = math.abs(p - V.prevP) / (u7 * dt)
					if m > 0.2 and m < 5 then V.mult = V.mult + (m - V.mult) * 0.2 end
				end
			end
		end
	end
	V.prevP, V.prevW = p, w

	if state.ventLock then
		-- Heartbeat = nach dem Green-Update; der Check im nächsten Frame nutzt genau dieses Green
		V.frame = fr
		V.origPos = V.origPos or fr.Position
		local want = UIS:GetMouseLocation().X - (p + w * 0.5) * fr.AbsoluteSize.X
		local o = V.origPos
		local cur = fr.Position
		fr.Position = UDim2.new(o.X.Scale, cur.X.Offset + (want - fr.AbsolutePosition.X), o.Y.Scale, o.Y.Offset)
		return
	end

	-- Lag messen: welchen unserer letzten Befehle hat das Spiel gerade gelesen?
	if mk and #V.hist >= 2 then
		local m = mk.Position.X.Scale
		local bestK, bestE = nil, 1.5 / fr.AbsoluteSize.X
		for k = 1, math.min(#V.hist, MAX_LAG) do
			local e = math.abs(V.hist[#V.hist - k + 1] - m)
			if e < bestE then bestE, bestK = e, k end
		end
		if bestK then V.lagF = V.lagF + (bestK - V.lagF) * 0.15 end
	end

	local fdt = math.clamp(dt, 1 / 240, 1 / 20)
	local ahead = state.ventPred and math.max(V.lagF - 1 + state.ventBias, 0) * fdt or 0
	local target = advance(p, V.dir, u7 * V.mult * ahead, u7) + w * 0.5
	V.hist[#V.hist + 1] = target
	if #V.hist > MAX_LAG + 2 then table.remove(V.hist, 1) end

	if hasMove and focused() then
		local x = fr.AbsolutePosition.X + target * fr.AbsoluteSize.X
		local y = fr.AbsolutePosition.Y + fr.AbsoluteSize.Y * 0.5
		mousemoveabs(math.floor(x + 0.5), math.floor(y + 0.5))
	end
end)

toggle(S_vent, "Enabled", "vent", function() end, "vent")
toggle(S_vent, "Lock Bar To Mouse (no lag)", "ventLock", function() end)
toggle(S_vent, "Prediction", "ventPred", function() end)
slider(S_vent, "Lead Adjust (frames)", -2, 2, state.ventBias, function(v)
	state.ventBias = math.floor(v * 4 + 0.5) / 4
	return ("%+.2f"):format(state.ventBias)
end, "ventBias")
toggle(S_vent, "Log To File", "ventLog", function() end)
-- ================= FAKE VENT TOOL =================
-- VentSystemL.getModifiers sucht VentTools per Name in Hand/Backpack (höchste Priority gewinnt) und nutzt dessen
-- SpeedMultiplier fürs rein clientseitige Minigame. Lokales leeres Tool mit passendem Namen = Tool-Bonus.
-- Nur während das Minigame offen ist im Backpack (kein Phantom-Slot). Server sieht das Tool nicht.
state.ventFake = sv("ventFake", false)
state.ventFakeIdx = sv("ventFakeIdx", 1)
;(function()
	local OPTS = { "Drill", "Sledge Hammer", "Crowbar" }
	local fake = nil
	local function removeFake() if fake then pcall(function() fake:Destroy() end) fake = nil end end
	toggle(S_vent, "Fake Tool", "ventFake", function(on) if not on then removeFake() end end)
	dropdown(S_vent, "Fake Tool Type", { "Drill (x20)", "Sledge Hammer (x5.5)", "Crowbar (x4)" }, state.ventFakeIdx, function(i)
		state.ventFakeIdx = i; removeFake()
	end, "ventFakeIdx")
	task.spawn(function()
		while H.alive do
			local open = false
			local pg = lp:FindFirstChild("PlayerGui")
			local mg = pg and pg:FindFirstChild("VentMinigame")
			local fr = mg and mg:FindFirstChild("Frame")
			open = fr and fr.Visible or false
			if state.ventFake and open then
				local bp = lp:FindFirstChild("Backpack")
				local name = OPTS[state.ventFakeIdx] or "Drill"
				if bp and (not fake or fake.Parent ~= bp or fake.Name ~= name) then
					removeFake()
					if not bp:FindFirstChild(name) then
						fake = Instance.new("Tool")
						fake.Name = name; fake.RequiresHandle = false; fake.CanBeDropped = false
						fake:SetAttribute("TSC_Fake", true)
						fake.Parent = bp
					end
				end
			elseif fake then
				removeFake()
			end
			task.wait(0.1)
		end
	end)
	table.insert(H.conns, { Disconnect = function() removeFake() end })
end)()

-- ================= JAMMED VENTS =================
-- Nach einem Fehlversuch setzt der Server den Prompt-Text auf "Jammed". Am Vent-Modell: Attribut Cooldown
-- (= time() beim Jammen) + CooldownTime (Sperrdauer, meist 40 s). Rein lesend, markiert nur im Umkreis.
state.ventJam = sv("ventJam", true)
;(function()
	local RANGE = 40
	local prompts = {}   -- [ProximityPrompt] = true (nur Vent/Manhole)
	local marks = {}     -- [prompt] = {hl=, bb=, lbl=}
	local function isVentPrompt(d)
		return d:IsA("ProximityPrompt") and (d.ObjectText:find("Vent") or d.ObjectText:find("Manhole")) ~= nil
	end
	local function clear(pp)
		local m = marks[pp]
		if m then pcall(function() m.hl:Destroy() end) pcall(function() m.bb:Destroy() end) marks[pp] = nil end
	end
	toggle(S_vent, "Mark Jammed Vents (40 studs)", "ventJam", function(on)
		if not on then for pp in pairs(marks) do clear(pp) end end
	end)
	con(workspace.DescendantAdded, function(d) if d:IsA("ProximityPrompt") then task.defer(function() if isVentPrompt(d) then prompts[d] = true end end) end end)
	task.spawn(function()
		-- Startsuche einmal, in Chunks (kein Ruckler)
		local all = workspace:GetDescendants()
		for i = 1, #all do
			if isVentPrompt(all[i]) then prompts[all[i]] = true end
			if i % 4000 == 0 then task.wait() end
		end
		while H.alive do
			local r = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
			for pp in pairs(prompts) do
				local part = pp.Parent
				if part and not part:IsA("BasePart") then part = part:FindFirstChildWhichIsA("BasePart", true) end
				if not pp:IsDescendantOf(workspace) then clear(pp); prompts[pp] = nil; part = nil end
				local jammed = state.ventJam and r and part and pp.ActionText == "Jammed"
					and (part.Position - r.Position).Magnitude <= RANGE
				if jammed then
					local model = pp.Parent
					while model and model ~= workspace and model:GetAttribute("CooldownTime") == nil do model = model.Parent end
					if model == workspace or not model then model = pp.Parent end
					local m = marks[pp]
					if not m then
						local hl = Instance.new("Highlight")
						hl.FillColor = Color3.fromRGB(255, 60, 60); hl.OutlineColor = Color3.fromRGB(255, 60, 60)
						hl.FillTransparency = 0.6; hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
						hl.Adornee = model; hl.Parent = espFolder
						local bb = Instance.new("BillboardGui")
						bb.AlwaysOnTop = true; bb.Size = UDim2.fromOffset(120, 20); bb.StudsOffset = Vector3.new(0, 2, 0)
						bb.LightInfluence = 0; bb.Adornee = part; bb.Parent = espFolder
						local l = Instance.new("TextLabel")
						l.Size = UDim2.fromScale(1, 1); l.BackgroundTransparency = 1; l.Font = Enum.Font.GothamBold
						l.TextSize = 12; l.TextColor3 = Color3.fromRGB(255, 80, 80); l.TextStrokeTransparency = 0.3; l.Parent = bb
						m = { hl = hl, bb = bb, lbl = l }
						marks[pp] = m
					end
					local cd, ct = tonumber(model:GetAttribute("Cooldown")), tonumber(model:GetAttribute("CooldownTime"))
					local left = (cd and ct) and math.max(0, cd + ct - time()) or nil
					m.lbl.Text = left and ("JAMMED %ds"):format(math.ceil(left)) or "JAMMED"
				elseif marks[pp] then
					clear(pp)
				end
			end
			task.wait(0.3)
		end
	end)
	table.insert(H.conns, { Disconnect = function() for pp in pairs(marks) do clear(pp) end end })
end)()

local ventStatus = info(S_vent, "Status: -")
local ventLast = info(S_vent, "Last: -")
if not hasMove then ventStatus.Text = '<font color="#ff6060">mousemoveabs fehlt</font>' end
task.spawn(function()
	while H.alive do
		if hasMove then
			local s
			if not state.vent then s = "off"
			elseif V.open then s = ('<font color="#d266b4">aiming</font> · lag %.1ff · x%.2f'):format(V.lagF, V.mult)
			else s = "idle · waiting for vent" end
			ventStatus.Text = "Status: " .. s
		end
		ventLast.Text = "Last: " .. V.last
		task.wait(0.25)
	end
end)

-- ================= FULLBRIGHT =================
local origLight = {}
local LPROPS = { Brightness = 2, ClockTime = 14, FogEnd = 1e6, FogStart = 1e6, GlobalShadows = false,
	Ambient = Color3.new(1, 1, 1), OutdoorAmbient = Color3.new(1, 1, 1), ExposureCompensation = 0 }
local disabledFx = {}
local function applyFB()
	for k, v in pairs(LPROPS) do
		if origLight[k] == nil then origLight[k] = Lighting[k] end
		if Lighting[k] ~= v then pcall(function() Lighting[k] = v end) end
	end
	local fx = Lighting:GetChildren()
	for _, o in ipairs(workspace.CurrentCamera:GetChildren()) do fx[#fx + 1] = o end
	for _, o in ipairs(fx) do
		if o:IsA("Atmosphere") then
			if not disabledFx[o] then disabledFx[o] = { Density = o.Density, Haze = o.Haze } end
			if o.Density ~= 0 then o.Density = 0 end
			if o.Haze ~= 0 then o.Haze = 0 end
		elseif (o:IsA("ColorCorrectionEffect") or o:IsA("BloomEffect") or o:IsA("BlurEffect")) and o.Enabled then
			if not disabledFx[o] then disabledFx[o] = { Enabled = true } end
			o.Enabled = false
		end
	end
end
local function restoreFB()
	for k, v in pairs(origLight) do pcall(function() Lighting[k] = v end) end
	origLight = {}
	for o, t in pairs(disabledFx) do if o.Parent then for k, v in pairs(t) do pcall(function() o[k] = v end) end end end
	disabledFx = {}
end
toggle(S_light, "Fullbright", "fullbright", function(on) if on then applyFB() else restoreFB() end end)
-- Spiel setzt Lighting per Zone neu -> periodisch nachziehen
task.spawn(function()
	while H.alive do
		if state.fullbright then pcall(applyFB) end
		task.wait(0.5)
	end
end)

-- Helligkeit (Fullbright): 0..10 -> Brightness + ExposureCompensation
slider(S_light, "Brightness", 0, 10, state.bright, function(v)
	state.bright = v
	LPROPS.Brightness = v
	-- unter 2: Ambient + Belichtung mit absenken -> bis fast schwarz runterregelbar
	if v < 2 then
		local g = v / 2
		LPROPS.Ambient = Color3.new(g, g, g); LPROPS.OutdoorAmbient = Color3.new(g, g, g)
		LPROPS.ExposureCompensation = -3 * (1 - g)
	else
		LPROPS.Ambient = Color3.new(1, 1, 1); LPROPS.OutdoorAmbient = Color3.new(1, 1, 1)
		LPROPS.ExposureCompensation = math.clamp((v - 2) / 3, 0, 2.5)
	end
	if state.fullbright then pcall(applyFB) end
	return ("%.1f/10.0"):format(v)
end, "brightness")

-- ================= REMOVE FOG =================
-- Nur Nebel/Dunst weg (Atmosphere Density/Haze, Fog), Licht bleibt wie es ist. Zonen setzen Lighting neu -> nachziehen.
state.nofog = sv("nofog", false)
local fogOrig, atmoOrig = {}, {}
local function applyNoFog()
	if fogOrig.FogEnd == nil then fogOrig.FogEnd = Lighting.FogEnd; fogOrig.FogStart = Lighting.FogStart end
	if Lighting.FogEnd ~= 1e6 then Lighting.FogEnd = 1e6 end
	if Lighting.FogStart ~= 1e6 then Lighting.FogStart = 1e6 end
	for _, o in ipairs(Lighting:GetChildren()) do
		if o:IsA("Atmosphere") then
			if not atmoOrig[o] then atmoOrig[o] = { Density = o.Density, Haze = o.Haze } end
			if o.Density ~= 0 then o.Density = 0 end
			if o.Haze ~= 0 then o.Haze = 0 end
		end
	end
end
local function restoreNoFog()
	if state.fullbright then return end -- Fullbright hält den Nebel selbst weg
	if fogOrig.FogEnd then pcall(function() Lighting.FogEnd = fogOrig.FogEnd; Lighting.FogStart = fogOrig.FogStart end) end
	for o, t in pairs(atmoOrig) do if o.Parent then o.Density = t.Density; o.Haze = t.Haze end end
	fogOrig, atmoOrig = {}, {}
end
toggle(S_light, "Remove Fog", "nofog", function(on) if on then pcall(applyNoFog) else restoreNoFog() end end)
task.spawn(function()
	while H.alive do
		if state.nofog then pcall(applyNoFog) end
		task.wait(0.5)
	end
end)

-- Anti-Flackern: Das Spiel setzt ClockTime ~2x/s auf 0 (Nacht) und Zonen-Lighting neu. Statt alle 0,5 s nachzuziehen
-- (dazwischen sichtbar) wird jede Änderung im selben Frame per Changed zurückgesetzt -> nie gerendert.
do
local lightBusy = false
local function enforce(o, prop, want)
	if lightBusy then return end
	local ok, cur = pcall(function() return o[prop] end)
	if ok and cur ~= want then
		lightBusy = true
		pcall(function() o[prop] = want end)
		lightBusy = false
	end
end
con(Lighting.Changed, function(prop)
	if state.fullbright and LPROPS[prop] ~= nil then enforce(Lighting, prop, LPROPS[prop])
	elseif state.nofog and (prop == "FogEnd" or prop == "FogStart") then enforce(Lighting, prop, 1e6) end
end)
local FX_KILL = { ColorCorrectionEffect = true, BloomEffect = true, BlurEffect = true }
local fxWatched = setmetatable({}, { __mode = "k" })
local function watchFx(o)
	if fxWatched[o] or not (o:IsA("Atmosphere") or FX_KILL[o.ClassName]) then return end
	fxWatched[o] = true
	con(o.Changed, function(prop)
		if o:IsA("Atmosphere") then
			if (prop == "Density" or prop == "Haze") and (state.fullbright or state.nofog) then enforce(o, prop, 0) end
		elseif prop == "Enabled" and state.fullbright and o.Enabled then
			if not disabledFx[o] then disabledFx[o] = { Enabled = true } end
			enforce(o, "Enabled", false)
		end
	end)
end
local function fxAdded(o)
	watchFx(o)
	if state.fullbright then task.defer(function() pcall(applyFB) end) end
	if state.nofog then task.defer(function() pcall(applyNoFog) end) end
end
for _, o in ipairs(Lighting:GetChildren()) do watchFx(o) end
for _, o in ipairs(workspace.CurrentCamera:GetChildren()) do watchFx(o) end
con(Lighting.ChildAdded, fxAdded)
con(workspace.CurrentCamera.ChildAdded, fxAdded)
end

-- ================= COMBAT / AIMBOT =================
do
-- Hook-frei, keine Remotes: Maus-Modus = mousemoverel (echter Input), Kamera-Modus = Camera.CFrame nach dem
-- Kamera-Update (BindToRenderStep Camera+1). Zielwahl: nächster Spieler zum FOV-Mittelpunkt (Bildschirm).
state.aim = sv("aim", false); state.aimTeam = sv("aimTeam", true); state.aimVis = sv("aimVis", true)
state.aimHealth = sv("aimHealth", true); state.aimSticky = sv("aimSticky", true); state.aimDist = sv("aimDist", 600)
state.aimSens = sv("aimSens", 2); state.aimPart = sv("aimPart", 1); state.aimType = sv("aimType", 1)
state.aimRage = sv("aimRage", false); state.aimRageType = sv("aimRageType", 1)
state.aimPred = sv("aimPred", false); state.aimPredX = sv("aimPredX", 5); state.aimPredY = sv("aimPredY", 5)
state.aimSmooth = sv("aimSmooth", true); state.aimSmX = sv("aimSmX", 7.5); state.aimSmY = sv("aimSmY", 7.5)
state.fov = sv("fov", true); state.fovGlow = sv("fovGlow", false); state.fovFill = sv("fovFill", false)
state.fovSize = sv("fovSize", 126); state.fovStyle = sv("fovStyle", 1); state.fovColor = sv("fovColor", 1)
state.fovGunOnly = sv("fovGunOnly", false)
state.aimGunOnly = sv("aimGunOnly", true)

-- Schusswaffe ausgerüstet? GunData.MagSize > 0 (AK-47: 30, Fäuste: 0). Ergebnis pro Tool gecacht.
local gunCache = setmetatable({}, { __mode = "k" })
local function gunEquipped()
	local c = lp.Character
	local t = c and c:FindFirstChildOfClass("Tool")
	if not t then return false end
	local v = gunCache[t]
	if v == nil then
		v = false
		local gd = t:FindFirstChild("GunData")
		if gd and gd:IsA("ModuleScript") then
			local ok, d = pcall(require, gd)
			v = ok and type(d) == "table" and (tonumber(d.MagSize) or 0) > 0
		end
		gunCache[t] = v
	end
	return v
end

local FOV_COLORS = { Color3.fromRGB(0, 255, 255), Color3.fromRGB(210, 80, 170), Color3.fromRGB(255, 255, 255),
	Color3.fromRGB(255, 70, 70), Color3.fromRGB(90, 255, 120), Color3.fromRGB(255, 210, 60) }
local HIT_PARTS = { "Head", "Torso", "Closest" }

local sub = subtabs(comPage, { "Aimbot", "Prediction", "Smoothness", "FOV" })
local S_aim = section(sub.Aimbot[1], "Aimbot")
local S_aimT = section(sub.Aimbot[2], "Targeting")
local S_pred = section(sub.Prediction[1], "Prediction")
local S_smooth = section(sub.Smoothness[1], "Smoothness")
local S_fov = section(sub.FOV[1], "FOV Circle")

toggle(S_aim, "Enabled", "aim", function() end, "aim")
toggle(S_aim, "Team Check", "aimTeam", function() end)
toggle(S_aim, "Visible Check", "aimVis", function() end)
toggle(S_aim, "Health Check", "aimHealth", function() end)
toggle(S_aim, "Sticky Aim", "aimSticky", function() end)
toggle(S_aim, "Only With Gun", "aimGunOnly", function() end)
slider(S_aim, "Distance", 25, 3000, state.aimDist, function(v) state.aimDist = math.floor(v); return tostring(state.aimDist) end, "aimDist")
slider(S_aim, "Sensitivity", 0.1, 5, state.aimSens, function(v)
	state.aimSens = math.floor(v * 20 + 0.5) / 20; return ("%.2f"):format(state.aimSens) end, "aimSens")
dropdown(S_aimT, "Hit Part", HIT_PARTS, state.aimPart, function(i) state.aimPart = i end, "aimPart")
dropdown(S_aimT, "Aim Type", { "Mouse", "Camera" }, state.aimType, function(i) state.aimType = i end, "aimType")
toggle(S_aimT, "Rage Method", "aimRage", function() end)
dropdown(S_aimT, "Type", { "Camera Teleport", "Mouse Flick" }, state.aimRageType, function(i) state.aimRageType = i end, "aimRageType")
local aimStatus = info(S_aimT, "Target: -")

-- No Visual Recoil: LocalGunScript feuert beim Schuss das lokale BindableEvent Remotes.ShootRecoil; einziger Listener
-- ist PlayerScripts.VisualGun (Feder, die Camera.CFrame hochkickt). Diese Verbindung deaktivieren -> kein Kamera-Kick.
-- Treffer/Spread unberührt, nichts geht an den Server; beim Ausschalten wieder Enable().
state.norecoil = sv("norecoil", false)
local S_gun = section(sub.Aimbot[2], "Gun Mods")
local recoilDisabled = false
local function applyRecoil()
	local rem = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
	local ev = rem and rem:FindFirstChild("ShootRecoil")
	if not ev or typeof(getconnections) ~= "function" then return nil end
	local ok, cs = pcall(getconnections, ev.Event)
	if not ok then return nil end
	for _, c in ipairs(cs) do
		if state.norecoil then pcall(function() c:Disable() end)
		elseif recoilDisabled then pcall(function() c:Enable() end) end
	end
	recoilDisabled = state.norecoil
	return #cs
end
local recoilInfo
toggle(S_gun, "No Visual Recoil", "norecoil", function() applyRecoil() end)
recoilInfo = info(S_gun, "")
-- ================= AUTO RELOAD =================
-- LocalGunScript lädt auf InputBegan(KeyCode == ClientSettings.Controls.Reload) nach (Animation + Server-Aufruf).
-- Magazin (Tool.GunData.Mag) zählt der Server. Mag leer + Reserve da + kein "Reloading" -> echte Reload-Taste
-- per nativem keypress drücken (VIM kommt in Potassium nicht an) -> normaler Spielweg. Nur wenn Roblox fokussiert.
state.autoreload = sv("autoreload", false)
;(function()
	toggle(S_gun, "Auto Reload", "autoreload", function() end)
	local lastPress = 0
	local function reloadKey()
		local cs = lp:FindFirstChild("ClientSettings")
		local ctrl = cs and cs:FindFirstChild("Controls")
		local v = ctrl and ctrl:FindFirstChild("Reload")
		local ok, kc = pcall(function() return Enum.KeyCode[v and v.Value or "R"] end)
		return ok and kc or Enum.KeyCode.R
	end
	local function vkOf(kc)
		local n = kc.Name
		if #n == 1 and n:match("%u") then return string.byte(n) end -- A-Z
		local map = { One = 0x31, Two = 0x32, Three = 0x33, Four = 0x34, Five = 0x35, Six = 0x36, Seven = 0x37, Eight = 0x38,
			Nine = 0x39, Zero = 0x30, LeftShift = 0xA0, LeftControl = 0xA2, LeftAlt = 0xA4, Tab = 0x09, CapsLock = 0x14,
			Backquote = 0xC0, F1 = 0x70, F2 = 0x71, F3 = 0x72, F4 = 0x73 }
		return map[n]
	end
	local isFocused = (typeof(isrbxactive) == "function") and isrbxactive or function() return true end
	task.spawn(function()
		while H.alive do
			if state.autoreload and typeof(keypress) == "function" then
				local c = lp.Character
				local tool = c and c:FindFirstChildOfClass("Tool")
				local gd = tool and tool:FindFirstChild("GunData")
				local mag = gd and gd:FindFirstChild("Mag")
				local res = gd and gd:FindFirstChild("ReserveAmmo")
				if mag and mag.Value <= 0 and (not res or res.Value > 0) and not gd:FindFirstChild("Reloading")
					and os.clock() - lastPress > 1.5 and isFocused() and not UIS:GetFocusedTextBox() then
					local vk = vkOf(reloadKey())
					if vk then
						lastPress = os.clock()
						pcall(keypress, vk); task.wait(0.05); pcall(keyrelease, vk)
					end
				end
			end
			task.wait(0.15)
		end
	end)
end)()

-- Gebuendelter getgc-Durchlauf: getgc(true) liefert in diesem Spiel ~460.000 Objekte. No Spread, Max Charge und
-- Kill Aura riefen den bei JEDEM Waffen-Equip je einmal auf (Max Charge beim Ausschalten zweimal) -> ~400 ms
-- Freeze pro Ausruesten (User 28.09.: "sobald ich ein tool rausohle lagt es tod", gemessen worst frame 401 ms).
-- Jetzt: Anfragen werden 0.3 s gesammelt und in EINEM Durchlauf abgearbeitet, Nicht-Tabellen vorher aussortiert.
-- Ausserdem fragen die Features den Durchlauf nur noch, wenn tatsaechlich eine neue Waffen-Tabelle dazukam;
-- normales Ein-/Ausruesten kommt ohne getgc aus, weil die Modul-Tabelle gepatcht ist und der deepCopy beim
-- Equip die gepatchten Werte erbt.
H.gcPending, H.gcRunning = {}, false
function H.gcRequest(name, visitor)
	if typeof(getgc) ~= "function" then return end
	H.gcPending[name] = visitor
	if H.gcRunning then return end
	H.gcRunning = true
	task.delay(0.3, function()
		H.gcRunning = false
		local vis = H.gcPending
		H.gcPending = {}
		local list = {}
		for _, fn in pairs(vis) do list[#list + 1] = fn end
		if #list == 0 then return end
		for _, v in ipairs(getgc(true)) do
			if type(v) == "table" then
				for i = 1, #list do pcall(list[i], v) end
			end
		end
	end)
end

-- No Spread: LocalGunScript berechnet die Streuung CLIENTSEITIG (spread() -> Pos) und schickt nur den fertigen Zielpunkt
-- (gunFireNet:Fire({Pos = spread(mouse)})). Streuung = u14.Spread * ...; u14 = deepCopy(require(Tool.GunData)) beim
-- Ausrüsten (GunManager, Haupt-VM). Daher Spread im Modul-Table (künftige Equips) UND in schon kopierten Tabellen
-- (getgc) auf 0; Originalwerte werden gemerkt und beim Ausschalten zurückgesetzt. Keine Hooks, keine Remotes.
state.nospread = sv("nospread", false)
;(function()
	local orig = setmetatable({}, { __mode = "k" }) -- [table] = Original-Spread
	local function isGunTable(t)
		return type(t) == "table" and rawget(t, "Spread") ~= nil and rawget(t, "MagSize") ~= nil
			and rawget(t, "RateOfFire") ~= nil and rawget(t, "Recoil") ~= nil
	end
	local function patch(t, on)
		if on then
			if orig[t] == nil and rawget(t, "Spread") ~= 0 then orig[t] = rawget(t, "Spread") end
			if orig[t] ~= nil then rawset(t, "Spread", 0) end
		elseif orig[t] ~= nil then
			rawset(t, "Spread", orig[t]); orig[t] = nil
		end
	end
	local seenMod = setmetatable({}, { __mode = "k" })
	local function patchModules(container, on)
		local newly = false
		if not container then return newly end
		for _, tool in ipairs(container:GetChildren()) do
			local gd = tool:IsA("Tool") and tool:FindFirstChild("GunData")
			if gd and gd:IsA("ModuleScript") then
				local ok, m = pcall(require, gd)
				if ok and isGunTable(m) then
					if on and not seenMod[m] then seenMod[m] = true; newly = true end
					patch(m, on)
				end
			end
		end
		return newly
	end
	local function apply()
		local on = state.nospread
		patchModules(lp:FindFirstChild("Backpack"), on)
		patchModules(lp.Character, on)
		if on then
			if typeof(getgc) == "function" then
				for _, v in ipairs(getgc(true)) do if isGunTable(v) then patch(v, true) end end
			end
		else
			for t in pairs(orig) do patch(t, false) end
		end
	end
	toggle(S_gun, "No Spread", "nospread", function() pcall(apply) end)
	-- neue Waffen (Kauf/Respawn/Ausrüsten): kurz nach dem Equip neu patchen (deepCopy passiert beim Equip)
	local function hookChar(c)
		con(c.ChildAdded, function(ch)
			if not state.nospread or not ch:IsA("Tool") then return end
			local a, b = false, false
			pcall(function() a = patchModules(lp.Character, true) end)
			pcall(function() b = patchModules(lp:FindFirstChild("Backpack"), true) end)
			if a or b then H.gcRequest("nospread", function(v) if isGunTable(v) then patch(v, true) end end) end
		end)
	end
	if lp.Character then hookChar(lp.Character) end
	con(lp.CharacterAdded, hookChar)
	table.insert(H.conns, { Disconnect = function() state.nospread = false; pcall(apply) end })
end)()

-- Always Max Charge (Nahkampf mit Charge-Tabelle: Fäuste, Klauen, ...): LocalGunScript zählt die Haltedauer LOKAL hoch und
-- bestimmt daraus die Stufe (LowCharge/MidCharge/MaxCharge); VisualGun.submitGunHit packt diese Stufe in das GunHit-Paket,
-- der Server nimmt Schaden/Knockback aus seiner Tabelle für die gemeldete Stufe (Fäuste: 12 -> 37 Schaden). Einen
-- "Charge-Start" meldet der Client nicht. Schwellen im GunData-Charge-Table (Modul + kopierte Tabellen via getgc) auf ~0
-- -> jeder Schlag ist sofort Stufe 3. Originale werden gemerkt und beim Ausschalten zurückgesetzt. Keine Hooks/Remotes.
state.maxcharge = sv("maxcharge", false)
;(function()
	local KEYS = { "LowCharge", "MidCharge", "MaxCharge" }
	local FAST = { LowCharge = 0.001, MidCharge = 0.002, MaxCharge = 0.003 }
	local orig = setmetatable({}, { __mode = "k" }) -- [Charge-Table] = {LowCharge=, MidCharge=, MaxCharge=}
	-- Kopien, die das Spiel WÄHREND "an" erstellt (deepCopy beim Equip), haben kein Original -> per Waffen-Signatur
	-- (Damage-Stufen) die Originalwerte merken, damit Ausschalten auch diese Kopien zurücksetzt.
	local bySig = {}
	local function sig(t)
		local d = rawget(t, "Damage")
		return type(d) == "table" and (tostring(d[1]) .. "," .. tostring(d[2]) .. "," .. tostring(d[3])) or "?"
	end
	local function isChargeTable(t)
		return type(t) == "table" and type(rawget(t, "MaxCharge")) == "number" and type(rawget(t, "LowCharge")) == "number"
			and type(rawget(t, "MidCharge")) == "number" and type(rawget(t, "Damage")) == "table"
	end
	local function patch(t, on)
		if on then
			if not orig[t] and rawget(t, "MaxCharge") > FAST.MaxCharge then
				orig[t] = { LowCharge = rawget(t, "LowCharge"), MidCharge = rawget(t, "MidCharge"), MaxCharge = rawget(t, "MaxCharge") }
				bySig[sig(t)] = bySig[sig(t)] or orig[t]
			end
			if orig[t] then for _, k in ipairs(KEYS) do rawset(t, k, FAST[k]) end end
		elseif orig[t] then
			for _, k in ipairs(KEYS) do rawset(t, k, orig[t][k]) end
			orig[t] = nil
		end
	end
	local seenMod = setmetatable({}, { __mode = "k" })
	local function patchModules(container, on)
		local newly = false
		if not container then return newly end
		for _, tool in ipairs(container:GetChildren()) do
			local gd = tool:IsA("Tool") and tool:FindFirstChild("GunData")
			if gd and gd:IsA("ModuleScript") then
				local ok, m = pcall(require, gd)
				if ok and type(m) == "table" and isChargeTable(rawget(m, "Charge")) then
					if on and not seenMod[m] then seenMod[m] = true; newly = true end
					patch(m.Charge, on)
				end
			end
		end
		return newly
	end
	local function apply()
		local on = state.maxcharge
		patchModules(lp:FindFirstChild("Backpack"), on)
		patchModules(lp.Character, on)
		if on then
			if typeof(getgc) == "function" then
				for _, v in ipairs(getgc(true)) do if isChargeTable(v) then patch(v, true) end end
			end
		else
			for t in pairs(orig) do patch(t, false) end
			-- während "an" entstandene Kopien (Schwellen noch auf FAST) über die Signatur zurücksetzen
			if typeof(getgc) == "function" then
				for _, v in ipairs(getgc(true)) do
					if isChargeTable(v) and rawget(v, "MaxCharge") == FAST.MaxCharge then
						local o = bySig[sig(v)]
						if o then for _, k in ipairs(KEYS) do rawset(v, k, o[k]) end end
					end
				end
			end
		end
	end
	toggle(S_gun, "Always Max Charge (melee)", "maxcharge", function() pcall(apply) end)
	local function hookChar(c)
		con(c.ChildAdded, function(ch)
			if not state.maxcharge or not ch:IsA("Tool") then return end
			local a, b = false, false
			pcall(function() a = patchModules(lp.Character, true) end)
			pcall(function() b = patchModules(lp:FindFirstChild("Backpack"), true) end)
			if a or b then H.gcRequest("maxcharge", function(v) if isChargeTable(v) then patch(v, true) end end) end
		end)
	end
	if lp.Character then hookChar(lp.Character) end
	con(lp.CharacterAdded, hookChar)
	table.insert(H.conns, { Disconnect = function() state.maxcharge = false; pcall(apply) end })
end)()
-- Wallbang: Treffer entscheidet der CLIENT. LocalGunScript.doVGRaycast castet Muendung -> Ziel und laeuft nur durch
-- Teile, die checkPartCanHit ablehnt (CanCollide false / unsichtbar); das getroffene Teil meldet VisualGun dann per
-- GunHit an den Server. Hier wird doVGRaycast in den Waffen-Closures (fire + Input-Handler, Upvalue "copy") per
-- setupvalue gegen eine Variante getauscht, die durch ALLES laeuft bis zum ersten lebenden Charakter (Humanoid bis
-- 3 Ebenen hoch, wie im Spiel). Gesucht wird auf der Muendungs-Linie UND auf der Kamera-Linie (dort zielt man; im
-- 3rd Person verfehlt die Muendungs-Linie sonst knapp), dazu ein Toleranz-Radius. Kein Ziel -> Originalverhalten.
-- GunManager ruft LocalGunScript(tool) einmal pro Waffe beim Eintreffen im Backpack -> neue Closures -> nachpatchen.
-- Keine Hooks, keine Remotes. UNGETESTET, ob der Server die Sichtlinie prueft.
state.wallbang = sv("wallbang", false); state.wbRadius = sv("wbRadius", 3)
state.keys.wallbang = kc(sv("keyWallbang", nil), nil)
;(function()
	local wrapOf = setmetatable({}, { __mode = "k" }) -- [original] = wrapper
	local origOf = setmetatable({}, { __mode = "k" }) -- [wrapper] = original
	local patched = setmetatable({}, { __mode = "k" }) -- [holder] = {i, ...}
	local wbInfo, nPatched, nHits, nMiss = nil, 0, 0, 0
	local function living(p)
		local a = p.Parent
		for _ = 1, 3 do
			if not a then return nil end
			local h = a:FindFirstChildOfClass("Humanoid")
			if h then return h, a end
			a = a.Parent
		end
	end
	-- Ziel rein geometrisch (Waende zaehlen ohnehin nicht): lebender fremder Spieler, dessen Kopf/Torso am naechsten an der
	-- Linie liegt (Abstand <= Toleranz + halbe Teilgroesse), vor der Muendung und in Reichweite. Frueher: Strahl Teil fuer Teil
	-- durch die Map -> nach 48 Teilen (Lampen, Leisten, Boden-Kacheln im Toleranz-Ball) abgebrochen -> nie ein Treffer.
	local AIM_PARTS = { "Head", "Torso", "UpperTorso", "LowerTorso", "HumanoidRootPart" }
	local function pick(o, dir, range, tol)
		local best, bestPerp
		for _, p in ipairs(Players:GetPlayers()) do
			local ch = p ~= lp and p.Character
			local h = ch and ch:FindFirstChildOfClass("Humanoid")
			if h and h.Health > 0 then
				for _, n in ipairs(AIM_PARTS) do
					local part = ch:FindFirstChild(n)
					if part and part:IsA("BasePart") then
						local v = part.Position - o
						local along = v:Dot(dir)
						if along > 0 and along <= range then
							local perp = (v - dir * along).Magnitude - part.Size.Magnitude / 3
							if perp <= tol and (not bestPerp or perp < bestPerp) then best, bestPerp = part, perp end
						end
					end
				end
			end
		end
		return best
	end
	local function makeWrap(orig)
		return function(tool, gd, aim, plr, n, from, flag)
			if not state.wallbang or not aim or not from or typeof(gd) ~= "table" then return orig(tool, gd, aim, plr, n, from, flag) end
			local range = tonumber(gd.Range) or 1000
			local dir = (aim - from).Unit
			local part = pick(from, dir, range, 0.5) -- Muendungs-Linie, knapp
			if not part then -- Kamera-Linie (dort zielt man), mit Toleranz
				local cam = workspace.CurrentCamera.CFrame.Position
				part = pick(cam, (aim - cam).Unit, range + (cam - from).Magnitude, state.wbRadius)
			end
			if part then nHits = nHits + 1; return part.Position, part, -(part.Position - from).Unit end
			-- kein Spieler auf der Linie: Kugel fliegt trotzdem durch alle Waende bis zur vollen Reichweite (kein Wandtreffer)
			nMiss = nMiss + 1
			return from + (aim - from).Unit * range, nil, nil
		end
	end
	-- ein getgc-Durchlauf: doVGRaycast-Originale finden, dann alle Closures umhaengen, die sie als Upvalue halten
	local function scan(on)
		if typeof(getgc) ~= "function" or typeof(debug.setupvalue) ~= "function" then return 0 end
		local fns = {}
		for _, f in ipairs(getgc(false)) do
			if type(f) == "function" and islclosure(f) then
				fns[#fns + 1] = f
				if not origOf[f] and not wrapOf[f] then
					local ok, nm = pcall(debug.info, f, "n")
					if ok and nm == "doVGRaycast" then local w = makeWrap(f); wrapOf[f] = w; origOf[w] = f end
				end
			end
		end
		local n = 0
		for _, f in ipairs(fns) do
			if not origOf[f] then
				local ok, ups = pcall(debug.getupvalues, f)
				if ok and ups then
					for i, u in pairs(ups) do
						if type(u) == "function" then
							if on and wrapOf[u] then
								if pcall(debug.setupvalue, f, i, wrapOf[u]) then
									patched[f] = patched[f] or {}; table.insert(patched[f], i); n = n + 1
								end
							elseif not on and origOf[u] then
								pcall(debug.setupvalue, f, i, origOf[u])
							end
						end
					end
				end
			end
		end
		if not on then table.clear(patched) end
		return n
	end
	-- haengt an einer der bekannten Closures wieder das Original? -> nachpatchen (billig, ohne getgc)
	local function intact()
		for f, idx in pairs(patched) do
			for _, i in ipairs(idx) do
				local ok, u = pcall(debug.getupvalue, f, i)
				if ok and type(u) == "function" and wrapOf[u] then return false end
			end
		end
		return true
	end
	local function paint()
		if not wbInfo then return end
		wbInfo.Text = not state.wallbang and "off" or (nPatched == 0 and "ON - no gun loaded yet"
			or ("ON - %d closures  |  wall hits %d  |  no target %d"):format(nPatched, nHits, nMiss))
	end
	local function apply()
		scan(state.wallbang)
		nPatched = 0
		for _, idx in pairs(patched) do nPatched = nPatched + #idx end
		paint()
	end
	toggle(S_gun, "Wallbang", "wallbang", function() pcall(apply) end, "wallbang")
	wbInfo = info(S_gun, "off", T.accent)
	slider(S_gun, "Wallbang aim tolerance", 0, 6, state.wbRadius, function(v) state.wbRadius = math.floor(v * 2 + 0.5) / 2; return ("%.1f studs"):format(state.wbRadius) end, "wbRadius")
	info(S_gun, "While a gun is in your hand, the walls on your aim line lose their collision (only between physics steps, so you don't fall or noclip). Every bullet goes through every wall. It hits the first player on your aim line (muzzle line, then camera through the crosshair with the tolerance in studs); otherwise it flies to full range. 'wall hits' = shots that reached a player, 'no target' = shots that hit nothing.")
	-- neue Waffe im Backpack/Charakter -> neue doVGRaycast-Closures -> nachpatchen (zweimal, LocalGunScript braucht kurz)
	local pend = false
	local function onTool(ch)
		if not state.wallbang or pend or not ch:IsA("Tool") or not ch:FindFirstChild("GunData") then return end
		pend = true
		task.delay(0.3, function() pcall(apply) end)
		task.delay(1.5, function() pend = false; pcall(apply) end)
	end
	local function hookBp(b) if b and b:IsA("Backpack") then con(b.ChildAdded, onTool) end end
	hookBp(lp:FindFirstChildOfClass("Backpack")); con(lp.ChildAdded, hookBp)
	if lp.Character then con(lp.Character.ChildAdded, onTool) end
	con(lp.CharacterAdded, function(c) con(c.ChildAdded, onTool) end)
	task.spawn(function()
		while H.alive do
			task.wait(1)
			if state.wallbang then
				if not intact() then pcall(apply) end
				paint()
			end
		end
	end)
	-- Waende auf der Schusslinie verlieren ihre Kollision NUR im Fenster nach der Physik (PostSimulation) bis vor die naechste
	-- Physik (PreSimulation). Gemessen: task.wait-Threads (Schuss-Schleife) laufen NACH PostSimulation, aber VOR Heartbeat,
	-- Input davor -> beide sehen CanCollide=false (30/30)
	-- -> checkPartCanHit laesst die Kugel durch. Die Physik sieht die Waende nie offen -> kein Durchfallen/Noclip. Lokal.
	local off = {}
	local function restore()
		for i, p in ipairs(off) do pcall(function() p.CanCollide = true end); off[i] = nil end
	end
	local function collect(o, dir, len, ex, out, keep)
		local params = RaycastParams.new(); params.FilterType = Enum.RaycastFilterType.Exclude
		local list, start = table.clone(ex), o
		for _ = 1, 24 do
			params.FilterDescendantsInstances = list
			local rest = len - (o - start).Magnitude
			if rest <= 0.1 then return end
			local r = workspace:Raycast(o, dir * rest, params)
			if not r then return end
			local inst = r.Instance
			-- nur Waende: Boden unter den Fuessen (keep) und alles, was von oben getroffen wird (Boden/Treppe/Tisch), bleibt fest
			if inst:IsA("BasePart") and not inst:IsA("Terrain") and inst.CanCollide and not keep[inst] and r.Normal.Y < 0.5
				and not living(inst) then out[#out + 1] = inst end
			list[#list + 1] = inst
			o = o + dir * math.max((r.Position - o):Dot(dir), 0.05)
		end
	end
	con(RunService.PreSimulation, restore)
	con(RunService.PostSimulation, function()
		if not state.wallbang then return end
		local c = lp.Character; local t = c and c:FindFirstChildOfClass("Tool")
		if not t or not t:FindFirstChild("GunData") then return end
		local cam = workspace.CurrentCamera
		local m = UIS:GetMouseLocation()
		local ray = cam:ViewportPointToRay(m.X, m.Y)
		local ex = { c, cam }
		for _, n in ipairs({ "GunEffects", "EffectParts" }) do local x = workspace:FindFirstChild(n); if x then ex[#ex + 1] = x end end
		local out, keep = {}, {}
		local hrp = c:FindFirstChild("HumanoidRootPart")
		if hrp then -- Boden, auf dem man steht (User: sonst rutscht man herum)
			local op = OverlapParams.new(); op.FilterType = Enum.RaycastFilterType.Exclude; op.FilterDescendantsInstances = ex
			for _, p in ipairs(workspace:GetPartBoundsInBox(hrp.CFrame * CFrame.new(0, -3.5, 0), Vector3.new(5, 4, 5), op)) do keep[p] = true end
		end
		collect(ray.Origin, ray.Direction, 1500, ex, out, keep)
		local fp = t:FindFirstChild("GunFirePoint", true)
		local mz = fp and fp:IsA("Attachment") and fp.WorldPosition or (t:FindFirstChild("Handle") and t.Handle.Position)
		if mz then collect(mz, ((ray.Origin + ray.Direction * 1500) - mz).Unit, 1500, ex, out, keep) end
		for _, p in ipairs(out) do
			if p.CanCollide then p.CanCollide = false; off[#off + 1] = p end
		end
	end)
	con(UIS.InputBegan, function(i, gp)
		local k = state.keys.wallbang
		if gp or listening or not k or not keyMatch(i, k) or UIS:GetFocusedTextBox() then return end
		ctl.wallbang.set(not state.wallbang)
	end)
	table.insert(H.conns, { Disconnect = function() state.wallbang = false; pcall(scan, false); restore() end })
end)()

-- Kill Aura (Nahkampf, z. B. Fäuste): Taste GEHALTEN -> nächster Gegner in Reichweite wird anvisiert (echte Maus: abs im
-- 3rd Person, rel im 1st Person, geglättet) und mit dem gewählten Abstand per echtem Linksklick geschlagen, solange die
-- Taste gehalten wird. Sticky: bleibt auf dem Ziel, bis es tot/down/außer Reichweite ist. Den Schlag sendet der Spieleigene
-- Ablauf (Richtung = Kamera-Strahl durch die Maus, Stufe = Charge). Range lokal auf Aura-Reichweite (UNGETESTET, ob der
-- Server die Distanz prüft). Keine Hooks, keine Remotes.
-- Charge "legit": pro Schlag wird nur die Stufe beansprucht, die ein echter Spieler seit dem letzten Schlag hätte aufladen
-- können (echte Schwellen Fäuste ~1/2/2.2-3.2 s). Dafür werden direkt vor dem Klick nur die erreichten Schwellen auf ~0
-- gesetzt, die übrigen bleiben echt -> 1-Frame-Klick ergibt genau diese Stufe. Der Server stuft zu schnelle Stufe-3-Schläge
-- ohnehin herunter; so sehen die Pakete auch im Log wie echte aus.
state.aura = sv("aura", false); state.auraRange = sv("auraRange", 10); state.auraTeam = sv("auraTeam", true)
state.auraDelay = sv("auraDelay2", 0.3); state.auraSmooth = sv("auraSmooth2", 2); state.auraRing = sv("auraRing", true)
state.auraForceMax = sv("auraForceMax", false)
;(function()
	local S_aura = section(sub.Aimbot[2], "Kill Aura (Melee)")
	local saved = setmetatable({}, { __mode = "k" }) -- [table] = {key = original}
	local real = setmetatable({}, { __mode = "k" }) -- [Charge-Tabelle] = {Low, Mid, Max} echt
	local lastSwing = 0 -- letzter Schlag (Aura oder von Hand), für die legit Charge-Stufe
	local function set(t, k, v)
		if table.isfrozen(t) then return end
		saved[t] = saved[t] or {}
		if saved[t][k] == nil then saved[t][k] = rawget(t, k) end
		rawset(t, k, v)
	end
	local function isMeleeTable(t)
		return type(t) == "table" and type(rawget(t, "Charge")) == "table" and type(rawget(t, "Range")) == "number"
			and rawget(t, "MagSize") == 0
	end
	local function patchTable(t)
		set(t, "Range", state.auraRange + 1)
		-- Windup = rein lokale Pause zwischen Loslassen und Schlag (task.wait(u14.Windup or 0.07)); Server sieht sie nicht
		if type(rawget(t, "Windup")) == "number" then set(t, "Windup", 0.01) end
		local c = rawget(t, "Charge")
		if type(rawget(c, "MaxCharge")) == "number" and not real[c] then
			-- echte Schwellen merken (falls schon gepatcht, z. B. durch "Always Max Charge": sichere Obergrenzen)
			local function rv(k, def)
				local o = saved[c] and saved[c][k]
				local v = (type(o) == "number" and o > 0.05) and o or rawget(c, k)
				return (type(v) == "number" and v > 0.05) and v or def
			end
			real[c] = { rv("LowCharge", 1), rv("MidCharge", 2), rv("MaxCharge", 3.2) }
		end
	end
	-- Stufe L (0-3) für den nächsten Klick einstellen
	local function setLevel(L)
		for c, rl in pairs(real) do
			if not table.isfrozen(c) then
				set(c, "LowCharge", L >= 1 and 0.001 or rl[1])
				set(c, "MidCharge", L >= 2 and 0.002 or rl[2])
				set(c, "MaxCharge", L >= 3 and 0.003 or rl[3])
			end
		end
	end
	-- welche Stufe ein echter Spieler nach `el` Sekunden seit dem letzten Schlag erreicht haben kann (strengste Schwellen)
	local function legitLevel(el)
		local lo, mi, ma = 0, 0, 0
		for _, rl in pairs(real) do lo, mi, ma = math.max(lo, rl[1]), math.max(mi, rl[2]), math.max(ma, rl[3]) end
		if ma == 0 then lo, mi, ma = 1, 2, 3.2 end
		el = el - 0.15 -- Windup + Reaktionszeit des vorigen Schlags
		return el >= ma and 3 or el >= mi and 2 or el >= lo and 1 or 0
	end
	local seenMod = setmetatable({}, { __mode = "k" })
	local function patchModulesOnly()
		local newly = false
		for _, cont in ipairs({ lp:FindFirstChild("Backpack"), lp.Character }) do
			if cont then
				for _, tool in ipairs(cont:GetChildren()) do
					local gd = tool:IsA("Tool") and tool:FindFirstChild("GunData")
					if gd and gd:IsA("ModuleScript") then
						local ok, m = pcall(require, gd)
						if ok and isMeleeTable(m) then
							if not seenMod[m] then seenMod[m] = true; newly = true end
							patchTable(m)
						end
					end
				end
			end
		end
		return newly
	end
	local function patchAll()
		patchModulesOnly()
		if typeof(getgc) == "function" then
			for _, v in ipairs(getgc(true)) do if isMeleeTable(v) then patchTable(v) end end
		end
	end
	local function restoreAll()
		for t, kv in pairs(saved) do for k, v in pairs(kv) do pcall(rawset, t, k, v) end end
		-- Schwellen immer auf die echten Werte (falls die Tabelle schon vorher gepatcht war)
		for c, rl in pairs(real) do
			if not table.isfrozen(c) then pcall(rawset, c, "LowCharge", rl[1]); pcall(rawset, c, "MidCharge", rl[2]); pcall(rawset, c, "MaxCharge", rl[3]) end
		end
		table.clear(saved)
		table.clear(real)
	end
	toggle(S_aura, "Enabled", "aura", function(on) if on then pcall(patchAll); setLevel(0) else restoreAll() end end, "aura")
	slider(S_aura, "Range", 6, 14, state.auraRange, function(v)
		state.auraRange = math.floor(v + 0.5)
		if state.aura then pcall(patchAll) end
		return state.auraRange .. " studs"
	end, "auraRange")
	slider(S_aura, "Hit Delay", 0.2, 3.5, state.auraDelay, function(v)
		state.auraDelay = math.floor(v * 20 + 0.5) / 20; state.auraDelay2 = state.auraDelay; return ("%.2f s"):format(state.auraDelay) end, "auraDelay")
	slider(S_aura, "Smoothing", 1, 10, state.auraSmooth, function(v)
		state.auraSmooth = math.floor(v + 0.5); state.auraSmooth2 = state.auraSmooth; return tostring(state.auraSmooth) end, "auraSmooth")
	toggle(S_aura, "Ignore Teammates", "auraTeam", function() end)
	toggle(S_aura, "Force Max Charge", "auraForceMax", function() end)
	toggle(S_aura, "Show Range Circle", "auraRing", function() end)
	local auraInfo = info(S_aura, "Press the key to toggle on/off (melee weapon, e.g. fists): hits the nearest enemy in range until you press it again. Each hit only claims the charge a real player could have built up since the last punch (first hit = full charge). Range above 6 is untested server-side.")

	local function meleeTool()
		local c = lp.Character
		local t = c and c:FindFirstChildOfClass("Tool")
		local gd = t and t:FindFirstChild("GunData")
		if not gd then return end
		local ok, m = pcall(require, gd)
		if ok and type(m) == "table" and type(m.Charge) == "table" then return t end
	end
	-- Niedergeschlagen: das Spiel markiert das uneinheitlich (Char.Down, Humanoid.Ragdoll, plrRGD, Incap-Objekt)
	local function isKnocked(c, hum)
		return c:GetAttribute("Down") == true or hum:GetAttribute("Ragdoll") == true or c:GetAttribute("plrRGD") == true
			or hum:GetAttribute("plrRGD") == true or c:FindFirstChild("Incap") ~= nil
	end
	-- Körperteil + knocked-Flag; nil für tot/nicht geladen
	local function bodyOf(p)
		local c = p and p.Character
		local hum = c and c:FindFirstChildOfClass("Humanoid")
		local part = c and (c:FindFirstChild("Torso") or c:FindFirstChild("UpperTorso") or c:FindFirstChild("HumanoidRootPart"))
		if not (part and hum and hum.Health > 0 and c:IsDescendantOf(workspace)) then return end
		return part, isKnocked(c, hum)
	end
	local function distTo(part)
		local my = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
		return my and (part.Position - my.Position).Magnitude or math.huge
	end
	local function validTarget(p, slack)
		if not p or p.Parent ~= Players then return end
		if state.auraTeam and p.Team ~= nil and p.Team == lp.Team then return end
		local part, knocked = bodyOf(p)
		if part and distTo(part) <= state.auraRange + (slack or 0) then return part, knocked end
	end
	-- Stehende Gegner zuerst (nächster), niedergeschlagene nur, wenn keiner steht
	local function findTarget(standingOnly)
		local best, bestPart, bd = nil, nil, math.huge
		local kBest, kPart, kd = nil, nil, math.huge
		for _, p in ipairs(Players:GetPlayers()) do
			if p ~= lp then
				local part, knocked = validTarget(p, 0)
				if part then
					local d = distTo(part)
					if not knocked then
						if d < bd then best, bestPart, bd = p, part, d end
					elseif d < kd then
						kBest, kPart, kd = p, part, d
					end
				end
			end
		end
		if best or standingOnly then return best, bestPart end
		return kBest, kPart
	end
	-- ein geglätteter Zielschritt: 3rd Person -> Cursor Richtung Ziel, 1st Person (Maus zentriert) -> Kamera per mousemoverel
	local function aimStep(part)
		local sp = cam:WorldToViewportPoint(part.Position)
		local k = 1 / math.max(state.auraSmooth, 1)
		-- Toleranz = ~60 % des Torso-Radius auf dem Bildschirm (nah dran reicht "irgendwo auf dem Körper")
		local edge = cam:WorldToViewportPoint(part.Position + cam.CFrame.RightVector * 1)
		local tol = math.max(12, (Vector2.new(edge.X, edge.Y) - Vector2.new(sp.X, sp.Y)).Magnitude * 0.6)
		if UIS.MouseBehavior == Enum.MouseBehavior.LockCenter then
			local c = cam.ViewportSize / 2
			local dx, dy = sp.X - c.X, sp.Y - c.Y
			if sp.Z < 0 then dx, dy = -dx, -dy end
			local mx, my = dx * k, dy * k
			if math.abs(mx) < 1 then mx = dx end
			if math.abs(my) < 1 then my = dy end
			if typeof(mousemoverel) == "function" then mousemoverel(mx, my) end
			return sp.Z > 0 and math.abs(dx) < tol and math.abs(dy) < tol
		end
		if sp.Z <= 0 then return false end
		local m = UIS:GetMouseLocation()
		local d = Vector2.new(sp.X, sp.Y) - m
		local step = d.Magnitude * k < 1 and d or d * k
		mousemoveabs(math.floor(m.X + step.X + 0.5), math.floor(m.Y + step.Y + 0.5))
		return d.Magnitude < tol
	end

	local aimSince = 0
	-- hart aufs Ziel setzen (ohne Glaettung); gibt true zurueck wenn das Ziel auf dem Bildschirm liegt
	local function aimSnap(part)
		local sp = cam:WorldToViewportPoint(part.Position)
		if sp.Z <= 0 then return false end
		if UIS.MouseBehavior == Enum.MouseBehavior.LockCenter then
			local c = cam.ViewportSize / 2
			if typeof(mousemoverel) == "function" then mousemoverel(sp.X - c.X, sp.Y - c.Y) end
		else
			mousemoveabs(math.floor(sp.X + 0.5), math.floor(sp.Y + 0.5))
		end
		return true
	end
	local target = nil
	local busy = false
	local auraOn = false -- Taste schaltet an/aus (statt halten)
	local function run()
		if busy then return end
		busy = true
		pcall(patchAll) -- frisch kopierte Tabellen (Equip) mit erfassen
		local hits, lastHit = 0, 0
		while H.alive and state.aura and auraOn do
			if not (focused() and meleeTool()) then
				-- Pause statt Abbruch: ohne Nahkampfwaffe / Fenster im Hintergrund nur warten, Toggle bleibt an
				auraInfo.Text = "Status: ON · equip a melee weapon"
				RunService.RenderStepped:Wait()
				continue
			end
			-- Sticky: einmal gelockt bleibt das Ziel, solange die Aura an ist; Wechsel nur bei tot/down/weg oder
			-- weiter als 2x Reichweite. Außerhalb der Reichweite wird weiter mitgezielt, aber nicht geschlagen.
			-- Reihenfolge: 1) Sticky-Ziel, solange es steht und in Reichweite ist  2) nächster stehender Gegner in Reichweite
			-- (wird neues Sticky-Ziel)  3) Sticky-Ziel knapp außerhalb (<= 2x Reichweite): weiter mitzielen, nicht schlagen
			-- 4) nächster niedergeschlagener in Reichweite
			local part, knocked = validTarget(target, state.auraRange)
			local stickyHittable = part and not knocked and distTo(part) <= state.auraRange
			if not stickyHittable then
				local sp, spart = findTarget(true)
				if sp then
					target, part = sp, spart
				elseif not (part and not knocked) then
					target, part = findTarget() -- nur noch niedergeschlagene übrig (oder niemand)
				end
			end
			if not target then
				auraInfo.Text = "Status: nobody within " .. state.auraRange .. " studs"
				RunService.RenderStepped:Wait()
			else
				local onTarget = aimStep(part)
				-- Snap-Fallback: wenn das geglaettete Zielen laenger als snapAfter nicht triftt (bewegtes Ziel,
				-- hohe Glaettung), einmal hart aufs Ziel setzen. Ohne das bleibt onTarget dauerhaft false -> keine Schlaege.
				if onTarget then
					aimSince = 0
				else
					if aimSince == 0 then aimSince = os.clock() end
					if os.clock() - aimSince > 0.4 then
						onTarget = aimSnap(part)
						aimSince = 0
					end
				end
				local inRange = distTo(part) <= state.auraRange
				if not inRange then
					auraInfo.Text = ('Status: locked <font color="#d266b4">%s</font> · out of range (%.0f)'):format(target.Name, distTo(part))
				end
				if inRange and onTarget and os.clock() - lastHit >= state.auraDelay then
					local L = state.auraForceMax and 3 or legitLevel(os.clock() - lastSwing)
					setLevel(L)
					lastSwing = os.clock()
					mouse1press()
					RunService.RenderStepped:Wait()
					mouse1release()
					lastHit = os.clock()
					hits = hits + 1
					auraInfo.Text = ('Status: <font color="#d266b4">%s</font> · %d hits · charge %d'):format(target.Name, hits, L)
					RunService.RenderStepped:Wait()
				else
					RunService.RenderStepped:Wait()
				end
			end
		end
		target = nil
		busy = false
		if not (H.alive and state.aura) then auraOn = false end
		if auraOn then task.spawn(run); return end -- schnell aus+an gedrückt, während der Loop noch auslief
		if next(real) then setLevel(0) end
	end
	-- Schläge von Hand zählen auch (setzen den Auflade-Timer zurück); die Aura setzt lastSwing selbst vor dem Klick
	con(UIS.InputBegan, function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 and not busy and meleeTool() then lastSwing = os.clock() end
	end)
	con(UIS.InputBegan, function(i)
		if state.aura and state.keys.aura and keyMatch(i, state.keys.aura) and not UIS:GetFocusedTextBox() then
			if typeof(mouse1press) ~= "function" then auraInfo.Text = "Status: mouse1press missing"; return end
			auraOn = not auraOn
			if auraOn then task.spawn(run) else auraInfo.Text = "Status: OFF" end
		end
	end)

	-- Indikator auf dem Bildschirm: ON (gruen) / OFF (grau), nur solange Kill Aura aktiviert ist; verschiebbar
	local ind = Instance.new("TextLabel")
	ind.Name = "TSC_AURA_IND"; ind.AnchorPoint = Vector2.new(0.5, 1); ind.Position = UDim2.new(0.5, 0, 1, -110)
	ind.Size = UDim2.fromOffset(0, 24); ind.AutomaticSize = Enum.AutomaticSize.X
	ind.BackgroundColor3 = Color3.fromRGB(10, 10, 12); ind.BackgroundTransparency = 0.35
	ind.Font = Enum.Font.GothamBold; ind.TextSize = 14; ind.Visible = false; ind.Parent = gui
	Instance.new("UICorner", ind).CornerRadius = UDim.new(0, 4)
	local ip = Instance.new("UIPadding", ind); ip.PaddingLeft = UDim.new(0, 10); ip.PaddingRight = UDim.new(0, 10)
	task.delay(1, function() if H.movable and ind.Parent then H.movable(ind, "auraIndPos") end end)
	con(RunService.Heartbeat, function()
		local show = state.aura
		if ind.Visible ~= show then ind.Visible = show end
		if not show then return end
		local txt = auraOn and "KILL AURA: ON" or "KILL AURA: OFF"
		if ind.Text ~= txt then
			ind.Text = txt
			ind.TextColor3 = auraOn and Color3.fromRGB(90, 255, 120) or Color3.fromRGB(150, 150, 150)
		end
	end)

	-- Reichweiten-Kreis am Boden (wie der FOV-Kreis), pink sobald ein Gegner drin ist
	local ringGui = Instance.new("ScreenGui")
	ringGui.Name = "TSC_AURA"; ringGui.ResetOnSpawn = false; ringGui.IgnoreGuiInset = true; ringGui.DisplayOrder = 997
	ringGui.Parent = CoreGui
	table.insert(H.conns, { Disconnect = function() ringGui:Destroy() end })
	local SEG = 48
	local segs = {}
	for i = 1, SEG do
		local f = Instance.new("Frame"); f.BorderSizePixel = 0; f.AnchorPoint = Vector2.new(0.5, 0.5); f.Visible = false
		f.Parent = ringGui
		segs[i] = f
	end
	RunService:BindToRenderStep("TSC_AURA_RING", Enum.RenderPriority.Camera.Value + 3, function()
		local my = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
		local show = state.aura and state.auraRing and my and meleeTool() ~= nil
		if not show then
			for i = 1, SEG do segs[i].Visible = false end
			return
		end
		local inside = target ~= nil or (findTarget()) ~= nil
		local col = inside and Color3.fromRGB(255, 60, 110) or Color3.fromRGB(0, 255, 255)
		local base = my.Position - Vector3.new(0, 2.9, 0)
		local r = state.auraRange
		local prev, prevOk
		for i = 0, SEG do
			local a = (i % SEG) / SEG * math.pi * 2
			local sp = cam:WorldToViewportPoint(base + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r))
			local p2, ok = Vector2.new(sp.X, sp.Y), sp.Z > 0
			if i > 0 then
				local f = segs[i]
				if ok and prevOk then
					local d = p2 - prev
					f.Position = UDim2.fromOffset((p2.X + prev.X) / 2, (p2.Y + prev.Y) / 2)
					f.Size = UDim2.fromOffset(d.Magnitude + 1, 2)
					f.Rotation = math.deg(math.atan2(d.Y, d.X))
					f.BackgroundColor3 = col; f.BackgroundTransparency = 0.25
					f.Visible = true
				else
					f.Visible = false
				end
			end
			prev, prevOk = p2, ok
		end
	end)
	table.insert(H.conns, { Disconnect = function() RunService:UnbindFromRenderStep("TSC_AURA_RING") end })

	local function hookChar(c)
		con(c.ChildAdded, function(ch)
			if not state.aura or not ch:IsA("Tool") then return end
			local newly = false
			pcall(function() newly = patchModulesOnly() end)
			if newly then H.gcRequest("aura", function(v) if isMeleeTable(v) then patchTable(v) end end) end
		end)
	end
	if lp.Character then hookChar(lp.Character) end
	con(lp.CharacterAdded, hookChar)
	table.insert(H.conns, { Disconnect = function() restoreAll() end })
end)()

task.spawn(function()
	while H.alive do
		-- VisualGun kann neu verbinden (Respawn/Neustart) -> regelmäßig nachziehen
		local n = applyRecoil()
		recoilInfo.Text = state.norecoil and (n and ('<font color="#78ff8c">camera kick off</font> (%d listener)'):format(n) or "ShootRecoil not found") or ""
		task.wait(2)
	end
end)
table.insert(H.conns, { Disconnect = function() if recoilDisabled then state.norecoil = false; pcall(applyRecoil) end end })
info(S_aimT, "Hold the aim key. Rage = instant snap, ignores FOV + visible check.")
info(S_aimT, "Mouse 3 works natively. Mouse 4/5: run tools/MouseBridge.exe (maps them to F13/F14 while Roblox is focused), then click the key box and press the side button.")

toggle(S_pred, "Enabled", "aimPred", function() end)
slider(S_pred, "Prediction X", 0, 20, state.aimPredX, function(v)
	state.aimPredX = math.floor(v * 4 + 0.5) / 4; return ("%.2f"):format(state.aimPredX) end, "aimPredX")
slider(S_pred, "Prediction Y", 0, 20, state.aimPredY, function(v)
	state.aimPredY = math.floor(v * 4 + 0.5) / 4; return ("%.2f"):format(state.aimPredY) end, "aimPredY")
info(S_pred, "Lead = target velocity × value/100 s (X = horizontal, Y = vertical).")

toggle(S_smooth, "Enabled", "aimSmooth", function() end)
slider(S_smooth, "Smoothness X", 1, 20, state.aimSmX, function(v)
	state.aimSmX = math.floor(v * 2 + 0.5) / 2; return ("%.1f"):format(state.aimSmX) end, "aimSmX")
slider(S_smooth, "Smoothness Y", 1, 20, state.aimSmY, function(v)
	state.aimSmY = math.floor(v * 2 + 0.5) / 2; return ("%.1f"):format(state.aimSmY) end, "aimSmY")

-- FOV-Kreis (reine GUI, liegt im Hub-ScreenGui mit IgnoreGuiInset -> Koordinaten = Viewport/Maus)
local fovRing = Instance.new("Frame")
fovRing.AnchorPoint = Vector2.new(0.5, 0.5); fovRing.BackgroundTransparency = 1; fovRing.Visible = false; fovRing.Parent = gui
Instance.new("UICorner", fovRing).CornerRadius = UDim.new(1, 0)
local fovStroke = Instance.new("UIStroke", fovRing); fovStroke.Thickness = 1.5
local fovGlowF = Instance.new("Frame")
fovGlowF.AnchorPoint = Vector2.new(0.5, 0.5); fovGlowF.Position = UDim2.fromScale(0.5, 0.5); fovGlowF.Size = UDim2.new(1, 6, 1, 6)
fovGlowF.BackgroundTransparency = 1; fovGlowF.Parent = fovRing
Instance.new("UICorner", fovGlowF).CornerRadius = UDim.new(1, 0)
local fovGlowS = Instance.new("UIStroke", fovGlowF); fovGlowS.Thickness = 5; fovGlowS.Transparency = 0.75

local _, fovRow = toggle(S_fov, "Enabled", "fov", function() end)
do -- Farbfeld rechts in der Zeile: Klick = nächste Farbe
	local sw = Instance.new("TextButton")
	sw.Size = UDim2.fromOffset(17, 17); sw.AnchorPoint = Vector2.new(1, 0); sw.Position = UDim2.new(1, 0, 0, 0)
	sw.Text = ""; sw.AutoButtonColor = false; sw.BackgroundColor3 = FOV_COLORS[state.fovColor] or FOV_COLORS[1]; sw.Parent = fovRow
	corner(sw, 4); stroke(sw, T.edge)
	con(sw.MouseButton1Click, function()
		state.fovColor = state.fovColor % #FOV_COLORS + 1; sw.BackgroundColor3 = FOV_COLORS[state.fovColor]
	end)
end
toggle(S_fov, "Glow", "fovGlow", function() end)
toggle(S_fov, "Filled", "fovFill", function() end)
toggle(S_fov, "Only With Gun", "fovGunOnly", function() end)
slider(S_fov, "Size", 10, 600, state.fovSize, function(v) state.fovSize = math.floor(v); return tostring(state.fovSize) end, "fovSize")
dropdown(S_fov, "Style", { "Smooth", "Static", "Center" }, state.fovStyle, function(i) state.fovStyle = i end, "fovStyle")
info(S_fov, "Smooth = follows the mouse softly, Static = sits on the mouse, Center = screen center.")

local aimParams = RaycastParams.new(); aimParams.FilterType = Enum.RaycastFilterType.Exclude
local aimTarget, fovPos = nil, nil
H.aimInfo = function() return aimTarget, fovPos end
local hasRel = typeof(mousemoverel) == "function"

local function aimPartOf(c, origin)
	local head = c:FindFirstChild("Head")
	local torso = c:FindFirstChild("UpperTorso") or c:FindFirstChild("Torso") or c:FindFirstChild("HumanoidRootPart")
	if state.aimPart == 1 then return head or torso end
	if state.aimPart == 2 then return torso or head end
	local best, bd = nil, math.huge -- Closest: der Teil, der dem FOV-Mittelpunkt am nächsten ist
	for _, part in ipairs({ head, torso }) do
		if part then
			local sp, on = cam:WorldToViewportPoint(part.Position)
			if on then
				local d = (Vector2.new(sp.X, sp.Y) - origin).Magnitude
				if d < bd then best, bd = part, d end
			end
		end
	end
	return best or head or torso
end

-- nil wenn Spieler kein gültiges Ziel ist, sonst Teil + Bildschirmabstand
local function aimCheck(p, origin, ignoreFov)
	if p == lp then return end
	local c = p.Character; if not c or not c.Parent then return end
	local hum = c:FindFirstChildOfClass("Humanoid"); if not hum then return end
	if state.aimTeam and p.Team ~= nil and p.Team == lp.Team then return end
	if state.aimHealth and (hum.Health <= 0 or c:GetAttribute("Down")) then return end
	local part = aimPartOf(c, origin); if not part then return end
	local camPos = cam.CFrame.Position
	if (part.Position - camPos).Magnitude > state.aimDist then return end
	local sp, on = cam:WorldToViewportPoint(part.Position)
	if not on or sp.Z <= 0 then return end
	local sd = (Vector2.new(sp.X, sp.Y) - origin).Magnitude
	local rage = state.aimRage
	if state.fov and not rage and not ignoreFov and sd > state.fovSize then return end
	if state.aimVis and not rage then
		aimParams.FilterDescendantsInstances = { lp.Character, cam }
		local hit = workspace:Raycast(camPos, part.Position - camPos, aimParams)
		if hit and not hit.Instance:IsDescendantOf(c) then return end
	end
	return part, sd
end

RunService:BindToRenderStep("TSC_AIM", Enum.RenderPriority.Camera.Value + 1, function(dt)
	local mouse = UIS:GetMouseLocation()
	-- FOV-Mittelpunkt
	local want = (state.fovStyle == 3) and (cam.ViewportSize / 2) or mouse
	if state.fovStyle == 1 and fovPos then fovPos = fovPos:Lerp(want, math.clamp(dt * 18, 0, 1)) else fovPos = want end
	local r = state.fovSize
	if state.fov and (not state.fovGunOnly or gunEquipped()) then
		local col = FOV_COLORS[state.fovColor] or FOV_COLORS[1]
		fovRing.Position = UDim2.fromOffset(fovPos.X, fovPos.Y); fovRing.Size = UDim2.fromOffset(r * 2, r * 2)
		fovStroke.Color = col; fovGlowS.Color = col; fovGlowS.Enabled = state.fovGlow
		fovRing.BackgroundColor3 = col; fovRing.BackgroundTransparency = state.fovFill and 0.88 or 1
		fovRing.Visible = true
	else
		fovRing.Visible = false
	end

	if not state.aim or not keyHeld(state.keys.aim) or (state.aimGunOnly and not gunEquipped()) then aimTarget = nil; return end
	-- Ziel wählen (Sticky: altes Ziel behalten, solange es gültig bleibt – FOV egal)
	local part
	if state.aimSticky and aimTarget then part = aimCheck(aimTarget, fovPos, true) end
	if not part then
		aimTarget = nil
		local bd = math.huge
		for _, p in ipairs(Players:GetPlayers()) do
			local pt, sd = aimCheck(p, fovPos, false)
			if pt and sd < bd then bd, aimTarget, part = sd, p, pt end
		end
	end
	if not part then return end

	local pos = part.Position
	if state.aimPred then
		local v = part.AssemblyLinearVelocity
		pos = pos + Vector3.new(v.X * state.aimPredX, v.Y * state.aimPredY, v.Z * state.aimPredX) / 100
	end
	local camCF = cam.CFrame
	local sp = cam:WorldToViewportPoint(pos)
	local delta = Vector2.new(sp.X, sp.Y) - mouse

	if state.aimRage then
		if state.aimRageType == 1 then cam.CFrame = CFrame.lookAt(camCF.Position, pos)
		elseif hasRel and focused() then mousemoverel(delta.X, delta.Y) end
		return
	end
	local sx = state.aimSmooth and state.aimSmX or 1
	local sy = state.aimSmooth and state.aimSmY or 1
	local k = state.aimSens / 2
	if state.aimType == 1 then
		if hasRel and focused() then
			local mx, my = delta.X * k / sx, delta.Y * k / sy
			-- nie über das Ziel hinausschießen
			if math.abs(mx) > math.abs(delta.X) then mx = delta.X end
			if math.abs(my) > math.abs(delta.Y) then my = delta.Y end
			mousemoverel(mx, my)
		end
	else
		local goal = CFrame.lookAt(camCF.Position, pos)
		local a = math.clamp(k / ((sx + sy) / 2), 0, 1)
		cam.CFrame = camCF:Lerp(goal, a)
	end
end)
table.insert(H.conns, { Disconnect = function() RunService:UnbindFromRenderStep("TSC_AIM") end })

task.spawn(function()
	while H.alive do
		if not state.aim then aimStatus.Text = "Target: - (off)"
		elseif state.aimGunOnly and not gunEquipped() then aimStatus.Text = "Target: - (no gun equipped)"
		elseif aimTarget then
			local c = aimTarget.Character; local rt = c and c:FindFirstChild("HumanoidRootPart")
			local d = rt and math.floor((rt.Position - cam.CFrame.Position).Magnitude) or 0
			aimStatus.Text = ('Target: <font color="#d266b4">%s</font> · %dm'):format(aimTarget.Name, d)
		else aimStatus.Text = "Target: - (hold " .. keyName(state.keys.aim) .. ")" end
		task.wait(0.2)
	end
end)
end

-- ================= ESP =================
local espObjs = {} -- [player] = {bb=, lbl=}
local function teamColor(p) return (p.Team and p.TeamColor.Color) or Color3.new(1, 1, 1) end

local function removeEsp(p)
	local e = espObjs[p]
	if e then pcall(function() e.bb:Destroy() end) espObjs[p] = nil end
end

local function ensureEsp(p)
	local e = espObjs[p]
	if not e then
		local bb = Instance.new("BillboardGui")
		bb.Name = "E_" .. p.UserId; bb.AlwaysOnTop = true; bb.Size = UDim2.fromOffset(200, 34)
		bb.StudsOffset = Vector3.new(0, 3.2, 0); bb.LightInfluence = 0; bb.ResetOnSpawn = false
		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.fromScale(1, 1); lbl.BackgroundTransparency = 1; lbl.Font = Enum.Font.GothamBold
		lbl.TextSize = 12; lbl.TextStrokeTransparency = 0.3; lbl.Parent = bb
		bb.Parent = espFolder
		e = { bb = bb, lbl = lbl }
		espObjs[p] = e
	end
	return e
end

toggle(S_esp, "Enabled", "esp", function(on)
	if not on then for p in pairs(espObjs) do removeEsp(p) end end
end)
-- ESP-Reichweite + Fade-Zone (letzte X % der Reichweite blenden aus)
slider(S_esp, "Distance", 25, 3000, state.espDist, function(v)
	state.espDist = math.floor(v)
	return state.espDist .. "/3000"
end, "espDist")
slider(S_esp, "Fade (last % of range)", 0, 100, state.espFade * 100, function(v)
	state.espFade = v / 100
	return math.floor(v) .. "/100"
end, "espFade")
-- Fade-Stärke: Transparenz = 1-(1-t)^k (k=1 linear, höher = blendet früher/stärker aus) + Schrift schrumpft
slider(S_esp, "Fade Strength", 1, 5, state.espFadePow, function(v)
	state.espFadePow = math.floor(v * 10 + 0.5) / 10
	return ("%.1fx"):format(state.espFadePow)
end, "espFadePow")
local function fadeAlpha(d)
	local fs = state.espDist * (1 - state.espFade)
	if d <= fs or state.espDist <= fs then return 0 end
	local t = math.clamp((d - fs) / (state.espDist - fs), 0, 1)
	return 1 - (1 - t) ^ state.espFadePow
end
local function applyFade(lbl, a, baseSize)
	lbl.TextTransparency = a
	lbl.TextStrokeTransparency = 0.3 + 0.7 * a
	lbl.TextSize = math.max(7, math.floor(baseSize * (1 - 0.45 * a) + 0.5))
end

-- ================= ESP (Boxen / Health / Tracer) =================
-- Eigene ScreenGui (IgnoreGuiInset -> Koordinaten = Viewport), gezeichnet nach dem Kamera-Update (Camera+2),
-- damit Boxen nicht hinterherwackeln. Nur Chars im Workspace (rausgestreamte haben keine aktuelle Position).
do
state.espBox = sv("espBox", true); state.espBoxStyle = sv("espBoxStyle", 1); state.espBoxFill = sv("espBoxFill", false)
state.espHealth = sv("espHealth", true); state.espName = sv("espName", true); state.espTeamTag = sv("espTeamTag", true); state.espDistTxt = sv("espDistTxt", true)
state.espTextSize = sv("espTextSize2", 15); state.espTracer = sv("espTracer", false); state.espTracerFov = sv("espTracerFov", true)
state.espTracerFrom = sv("espTracerFrom", 1); state.espTeamCol = sv("espTeamCol", true); state.espTargetCol = sv("espTargetCol", true)
state.espHideTeam = sv("espHideTeam", false)

local ESP_FONT, ESP_FONT_BOLD = Enum.Font.GothamBold, Enum.Font.GothamBlack
pcall(function() ESP_FONT = Enum.Font.BuilderSansBold end)
pcall(function() ESP_FONT_BOLD = Enum.Font.BuilderSansExtraBold end)
local TARGET_COL = Color3.fromRGB(255, 60, 110)
local BASE_COL = Color3.fromRGB(235, 235, 240)
local BLACK = Color3.new(0, 0, 0)

local S_espStyle = section(visL, "ESP Style")
toggle(S_espStyle, "Boxes", "espBox", function() end)
dropdown(S_espStyle, "Box Style", { "Full", "Corners" }, state.espBoxStyle, function(i) state.espBoxStyle = i end, "espBoxStyle")
toggle(S_espStyle, "Box Fill", "espBoxFill", function() end)
toggle(S_espStyle, "Health Bar", "espHealth", function() end)
toggle(S_espStyle, "Names", "espName", function() end)
toggle(S_espStyle, "Team Tag after Name (JU, HU …)", "espTeamTag", function() end)
-- Team-Kuerzel: Spiel-Attribut "Abbreviation" am Team (JU, HU, SD …); fehlt es, kurzer Name bzw. Anfangsbuchstaben
H.teamTagCache = {}
function H.teamTag(team)
	if not team then return nil end
	local c = H.teamTagCache[team]
	if c ~= nil then return c or nil end
	local ab = team:GetAttribute("Abbreviation")
	if type(ab) ~= "string" or ab == "" then
		local n = team.Name:gsub("[^%w%s]", "")
		if n == "Menu" or n == "" then ab = false
		elseif not n:find("%s") and #n <= 6 then ab = n:upper()
		else ab = n:gsub("(%w)%w*%s*", "%1"):upper() end
	end
	H.teamTagCache[team] = ab
	return ab or nil
end
toggle(S_espStyle, "Distance", "espDistTxt", function() end)
slider(S_espStyle, "Text Size", 9, 18, state.espTextSize, function(v)
	state.espTextSize = math.floor(v + 0.5); state.espTextSize2 = state.espTextSize; return tostring(state.espTextSize) end, "espTextSize")
toggle(S_espStyle, "Tracers", "espTracer", function() end)
toggle(S_espStyle, "Tracers Only In FOV", "espTracerFov", function() end)
dropdown(S_espStyle, "Tracer Origin", { "Bottom", "Mouse", "FOV Center", "Top" }, state.espTracerFrom, function(i) state.espTracerFrom = i end, "espTracerFrom")
toggle(S_espStyle, "Team Colors", "espTeamCol", function() end)
toggle(S_espStyle, "Highlight Aim Target", "espTargetCol", function() end)
toggle(S_espStyle, "Hide Teammates", "espHideTeam", function() end)

local espGui = Instance.new("ScreenGui")
espGui.Name = "TSC_ESP2"; espGui.ResetOnSpawn = false; espGui.IgnoreGuiInset = true; espGui.DisplayOrder = 998
espGui.Parent = CoreGui
table.insert(H.conns, { Disconnect = function() espGui:Destroy() end })

local function line(parent, th)
	local f = Instance.new("Frame"); f.BorderSizePixel = 0; f.AnchorPoint = Vector2.new(0.5, 0.5); f.Parent = parent
	local s = Instance.new("UIStroke", f); s.Color = BLACK; s.Thickness = th or 1; s.Transparency = 0.35
	return f, s
end
local function label(parent)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1; l.Font = ESP_FONT; l.TextStrokeTransparency = 0.15; l.TextStrokeColor3 = BLACK
	l.Size = UDim2.fromOffset(200, 16); l.AnchorPoint = Vector2.new(0.5, 0); l.Parent = parent
	return l
end

local function build(p)
	local root = Instance.new("Frame")
	root.Name = "P_" .. p.UserId; root.BackgroundTransparency = 1; root.Size = UDim2.fromScale(1, 1); root.Parent = espGui
	local o = { root = root }
	-- volle Box: Füllung + farbige Kontur + schwarze Außenkontur
	local box = Instance.new("Frame"); box.BorderSizePixel = 0; box.Parent = root
	local bIn = Instance.new("UIStroke", box); bIn.Thickness = 1; bIn.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	local outl = Instance.new("Frame"); outl.BackgroundTransparency = 1; outl.Parent = root
	local bOut = Instance.new("UIStroke", outl); bOut.Thickness = 3; bOut.Color = BLACK; bOut.Transparency = 0.4
	o.box, o.bIn, o.outl, o.bOut = box, bIn, outl, bOut
	-- Ecken: 8 kurze Linien
	o.corners = {}
	for i = 1, 8 do o.corners[i] = { line(root, 1) } end
	-- Health Bar
	local hbg = Instance.new("Frame"); hbg.BorderSizePixel = 0; hbg.BackgroundColor3 = BLACK; hbg.BackgroundTransparency = 0.35; hbg.Parent = root
	local hfill = Instance.new("Frame"); hfill.BorderSizePixel = 0; hfill.AnchorPoint = Vector2.new(0, 1); hfill.Parent = hbg
	o.hbg, o.hfill = hbg, hfill
	o.name = label(root); o.info = label(root); o.name.RichText = true
	o.name.Font = ESP_FONT_BOLD
	o.tracer = { line(root, 1) }
	return o
end

local objs = {}
local function kill(p) local o = objs[p]; if o then pcall(function() o.root:Destroy() end); objs[p] = nil end end
removeEsp = function(p) kill(p) end -- PlayerRemoving/Aus-Schalten nutzen weiterhin removeEsp
con(Players.PlayerRemoving, kill)

local function setLine(f, a, b, col, tr)
	local d = b - a
	f.Position = UDim2.fromOffset((a.X + b.X) / 2, (a.Y + b.Y) / 2)
	f.Size = UDim2.fromOffset(math.max(d.Magnitude, 1), 1.5)
	f.Rotation = math.deg(math.atan2(d.Y, d.X))
	f.BackgroundColor3 = col; f.BackgroundTransparency = tr
	f.Visible = true
end

local function hpColor(fr)
	if fr > 0.5 then return Color3.fromRGB(255, 220, 60):Lerp(Color3.fromRGB(80, 235, 110), (fr - 0.5) * 2) end
	return Color3.fromRGB(235, 60, 60):Lerp(Color3.fromRGB(255, 220, 60), fr * 2)
end

RunService:BindToRenderStep("TSC_ESP", Enum.RenderPriority.Camera.Value + 2, function()
	if not state.esp then
		for p in pairs(objs) do kill(p) end
		return
	end
	local camPos = cam.CFrame.Position
	local vp = cam.ViewportSize
	local myRoot = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
	local myPos = myRoot and myRoot.Position or camPos
	local aimT, fovC = nil, nil
	if H.aimInfo then aimT, fovC = H.aimInfo() end
	local mouse = UIS:GetMouseLocation()
	local seen = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p == lp then continue end
		local c = p.Character
		local r = c and c:FindFirstChild("HumanoidRootPart")
		local hum = c and c:FindFirstChildOfClass("Humanoid")
		if not (r and hum and c:IsDescendantOf(workspace)) then continue end
		if state.espHideTeam and p.Team ~= nil and p.Team == lp.Team then continue end
		local dist = (r.Position - myPos).Magnitude
		if dist > state.espDist then continue end
		-- Box aus Kopf-oben / Füße-unten projizieren (stabil bei Rotation)
		local up = Vector3.new(0, 1, 0)
		local top, onT = cam:WorldToViewportPoint(r.Position + up * 2.9)
		local bot, onB = cam:WorldToViewportPoint(r.Position - up * 3.2)
		if top.Z <= 0 or bot.Z <= 0 then continue end
		local h = math.abs(bot.Y - top.Y)
		local w = h * 0.58
		local cx = (top.X + bot.X) / 2
		local x0, y0 = cx - w / 2, math.min(top.Y, bot.Y)
		if x0 > vp.X or x0 + w < 0 or y0 > vp.Y or y0 + h < 0 then continue end

		seen[p] = true
		local o = objs[p] or build(p); objs[p] = o
		o.root.Visible = true
		local a = fadeAlpha(dist)
		local isT = state.espTargetCol and aimT == p
		local col = isT and TARGET_COL or (state.espTeamCol and p.Team and p.TeamColor.Color or BASE_COL)

		-- Box
		local full = state.espBox and state.espBoxStyle == 1
		o.box.Visible = full; o.outl.Visible = full
		if full then
			o.box.Position = UDim2.fromOffset(x0, y0); o.box.Size = UDim2.fromOffset(w, h)
			o.box.BackgroundColor3 = col; o.box.BackgroundTransparency = state.espBoxFill and (0.82 + 0.18 * a) or 1
			o.bIn.Color = col; o.bIn.Transparency = a
			o.outl.Position = UDim2.fromOffset(x0, y0); o.outl.Size = UDim2.fromOffset(w, h); o.bOut.Transparency = 0.4 + 0.6 * a
		end
		local cor = state.espBox and state.espBoxStyle == 2
		if cor then
			local lx, ly = math.max(w * 0.28, 3), math.max(h * 0.2, 3)
			local x1, y1 = x0 + w, y0 + h
			local P = Vector2.new
			local segs = {
				{ P(x0, y0), P(x0 + lx, y0) }, { P(x0, y0), P(x0, y0 + ly) },
				{ P(x1, y0), P(x1 - lx, y0) }, { P(x1, y0), P(x1, y0 + ly) },
				{ P(x0, y1), P(x0 + lx, y1) }, { P(x0, y1), P(x0, y1 - ly) },
				{ P(x1, y1), P(x1 - lx, y1) }, { P(x1, y1), P(x1, y1 - ly) },
			}
			for i, sgm in ipairs(segs) do
				local f, s = o.corners[i][1], o.corners[i][2]
				setLine(f, sgm[1], sgm[2], col, a); s.Transparency = 0.35 + 0.65 * a
			end
		else
			for i = 1, 8 do o.corners[i][1].Visible = false end
		end

		-- Health Bar (links neben der Box)
		o.hbg.Visible = state.espHealth
		if state.espHealth then
			local fr = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
			o.hbg.Position = UDim2.fromOffset(x0 - 6, y0 - 1); o.hbg.Size = UDim2.fromOffset(4, h + 2)
			o.hbg.BackgroundTransparency = 0.35 + 0.65 * a
			o.hfill.Position = UDim2.new(0, 1, 1, -1); o.hfill.Size = UDim2.new(1, -2, fr, -2 * fr)
			o.hfill.BackgroundColor3 = hpColor(fr); o.hfill.BackgroundTransparency = a
		end

		-- Texte
		local ts = math.max(12, math.floor(state.espTextSize * (1 - 0.2 * a) + 0.5))
		o.name.Visible = state.espName
		if state.espName then
			local nm = p.DisplayName:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")
			local tag = state.espTeamTag and H.teamTag(p.Team)
			if tag then nm = nm .. ('<font size="%d"> (%s)</font>'):format(math.max(8, ts - 4), tag) end
			o.name.Text = nm; o.name.TextSize = ts; o.name.TextColor3 = col
			o.name.TextTransparency = a; o.name.TextStrokeTransparency = 0.15 + 0.85 * a
			o.name.Position = UDim2.fromOffset(cx, y0 - ts - 4); o.name.Size = UDim2.fromOffset(240, ts + 2)
		end
		o.info.Visible = state.espDistTxt
		if state.espDistTxt then
			o.info.Text = ("%dm · %d hp"):format(math.floor(dist), math.floor(hum.Health))
			o.info.TextSize = math.max(11, ts - 2); o.info.TextColor3 = col
			o.info.TextTransparency = a; o.info.TextStrokeTransparency = 0.15 + 0.85 * a
			o.info.Position = UDim2.fromOffset(cx, y0 + h + 3); o.info.Size = UDim2.fromOffset(240, ts)
		end

		-- Tracer (optional nur, wenn der Spieler im FOV-Kreis ist)
		local tr = o.tracer[1]
		local showT = state.espTracer
		local feet = Vector2.new(cx, y0 + h)
		if showT and state.espTracerFov then
			local fc = fovC or mouse
			showT = (Vector2.new(cx, y0 + h / 2) - fc).Magnitude <= state.fovSize
		end
		if showT then
			local tf = state.espTracerFrom
			local from = (tf == 2 and mouse) or (tf == 3 and (fovC or mouse)) or (tf == 4 and Vector2.new(vp.X / 2, 2)) or Vector2.new(vp.X / 2, vp.Y - 2)
			local to = (tf == 4) and Vector2.new(cx, y0) or feet -- von oben: zum Kopf, sonst zu den Füßen
			setLine(tr, from, to, col, a); o.tracer[2].Transparency = 0.35 + 0.65 * a
		else
			tr.Visible = false
		end
	end
	for p, o in pairs(objs) do if not seen[p] then o.root.Visible = false end end
end)
table.insert(H.conns, { Disconnect = function() RunService:UnbindFromRenderStep("TSC_ESP") end })
end

-- ================= ITEM-ESP (gedroppte Tools) =================
-- Spiel-Logik (PromptToolPickup): Tool direkt in workspace + Handle + CanBeDropped = aufhebbar
state.items = sv("items", false)
local itemObjs = {} -- [tool] = {bb=, lbl=}
-- nur echte Drops (gleiche Regel wie das Spiel-Script PromptToolPickup): Tag "DroppedTool" + CanBeDropped.
-- Liegengebliebene Tools toter Spieler (nur Tag "Tool", CanBeDropped=false) sind nicht aufhebbar -> kein ESP
local function isDropped(t) return t:IsA("Tool") and t.Parent == workspace and t.CanBeDropped and t:HasTag("DroppedTool") and t:FindFirstChild("Handle") ~= nil end
local function clearItem(t) local o = itemObjs[t] if o then pcall(function() o.bb:Destroy() end) itemObjs[t] = nil end end
toggle(S_items, "Dropped Items", "items", function(on) if not on then for t in pairs(itemObjs) do clearItem(t) end end end)
con(workspace.ChildRemoved, function(t) clearItem(t) end)

-- ================= PERFORMANCE =================
-- Stufe 0 aus | 1 Schatten/Post-FX/Terrain-Deko aus | 2 + Partikel/Trails/Beams/Decals/Texturen weg | 3 + alles SmoothPlastic, Qualität min
state.perf = sv("perf", 0); state.updInt = sv("updInt", 0.2)
local perfCur, perfOrig = 0, setmetatable({}, { __mode = "k" })
local function setp(o, k, v)
	local t = perfOrig[o]
	if not t then t = {} perfOrig[o] = t end
	if t[k] == nil then t[k] = o[k] end
	if o[k] ~= v then o[k] = v end
end
local FX2 = { ParticleEmitter = true, Trail = true, Beam = true, Smoke = true, Fire = true, Sparkles = true }
local function perfOne(d, lvl)
	if lvl >= 2 then
		if FX2[d.ClassName] then setp(d, "Enabled", false)
		elseif d:IsA("Decal") then setp(d, "Transparency", 1) end -- Texture erbt von Decal
	end
	if lvl >= 3 and d:IsA("BasePart") then
		setp(d, "Material", Enum.Material.SmoothPlastic); setp(d, "Reflectance", 0); setp(d, "CastShadow", false)
	end
end
local function perfLighting(lvl)
	if lvl < 1 then return end
	setp(Lighting, "GlobalShadows", false)
	for _, o in ipairs(Lighting:GetChildren()) do
		if (o:IsA("SunRaysEffect") or o:IsA("DepthOfFieldEffect") or o:IsA("BloomEffect") or o:IsA("BlurEffect")) and o.Enabled then setp(o, "Enabled", false) end
	end
	local ter = workspace:FindFirstChildOfClass("Terrain")
	if ter then pcall(function() setp(ter, "Decoration", false); setp(ter, "WaterWaveSize", 0); setp(ter, "WaterReflectance", 0) end) end
	if lvl >= 3 then pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Level01 end) end
end
local function perfRestore(chunked)
	local old = perfOrig
	perfOrig = setmetatable({}, { __mode = "k" })
	local i = 0
	for o, t in pairs(old) do
		if o.Parent then for k, v in pairs(t) do pcall(function() o[k] = v end) end end
		i = i + 1
		if chunked and i % 1500 == 0 then task.wait() end
	end
	pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Automatic end)
end
dropdown(S_perf, "Level", { "Off", "Shadows / FX", "+ Particles / Decals", "+ Materials" }, state.perf + 1, function(i)
	state.perf = i - 1
end, "perf")
slider(S_perf, "Hub Update Rate", 0.05, 1, state.updInt, function(v)
	state.updInt = v
	return ("%.1f/s"):format(1 / v)
end, "updInt")
info(S_perf, "Lower update rate = more FPS.")
-- Worker: Stufe wechseln (in Chunks, kein Freeze) + neue Instanzen (Regionen laden nach) mitnehmen
con(workspace.DescendantAdded, function(d)
	if perfCur >= 2 then task.defer(function() pcall(perfOne, d, perfCur) end) end
end)
task.spawn(function()
	while H.alive do
		if state.perf ~= perfCur then
			local want = state.perf
			perfRestore(true)
			perfCur = want
			if want >= 2 then
				local all = workspace:GetDescendants()
				for i = 1, #all do
					if not H.alive or state.perf ~= want then break end
					pcall(perfOne, all[i], want)
					if i % 3000 == 0 then task.wait() end
				end
			end
		end
		pcall(perfLighting, perfCur)
		task.wait(1)
	end
end)

-- ================= NO FALL DAMAGE =================
-- ClientFallDamage meldet FallImpact:FireServer(-vel.Y) beim Landen, aber nur wenn > 80.
-- Hook-frei: in Bodennähe jeden Frame auf 60 kappen (Landung max ~65) -> nichts wird gemeldet.
state.nofall = sv("nofall", false)
local FALL_CAP = 60
local fallParams = RaycastParams.new(); fallParams.FilterType = Enum.RaycastFilterType.Exclude
toggle(S_move, "No Fall Damage", "nofall", function() end)
con(RunService.Heartbeat, function(dt)
	if not state.nofall then return end
	local c = lp.Character
	local r = c and c:FindFirstChild("HumanoidRootPart")
	local hum = c and c:FindFirstChildOfClass("Humanoid")
	if not (r and hum) then return end
	local v = r.AssemblyLinearVelocity
	if v.Y >= -FALL_CAP then return end
	fallParams.FilterDescendantsInstances = { c }
	-- Vorausschau: Strecke der nächsten ~3 Frames + Hüfthöhe + Puffer
	local look = -v.Y * math.max(dt, 1 / 60) * 3 + hum.HipHeight + r.Size.Y / 2 + 6
	local hit = workspace:Raycast(r.Position, Vector3.new(0, -look, 0), fallParams)
	if hit then
		r.AssemblyLinearVelocity = Vector3.new(v.X, -FALL_CAP, v.Z)
	end
end)

-- ================= WALK THROUGH DOORS =================
-- InteractEvent(door) prüft Clearance serverseitig -> Tür öffnen ohne Karte geht nicht. Aber: eigener Char ist
-- client-owned (Physik lokal) -> Türflügel lokal CanCollide=false = durchlaufen; für andere bleibt die Tür zu.
-- Türen = CollectionService-Tag "DoorInteractable"; Frame/Button behalten Kollision. Flügel lokal halb transparent.
state.doorphase = sv("doorphase", false)
do
	local CS = game:GetService("CollectionService")
	local KEEP = { Frame = true, Button = true, ExternalSoundPlayer = true }
	local touched = {} -- [part] = origCanCollide
	local doorInfo
	local function phaseDoor(door)
		if not state.doorphase then return end
		for _, d in ipairs(door:GetDescendants()) do
			if d:IsA("BasePart") and not KEEP[d.Name] and not (d.Parent and KEEP[d.Parent.Name]) and touched[d] == nil then
				touched[d] = d.CanCollide
				d.CanCollide = false
				d.LocalTransparencyModifier = 0.5
			end
		end
	end
	local function restoreAll()
		for d, orig in pairs(touched) do
			if d.Parent then d.CanCollide = orig; d.LocalTransparencyModifier = 0 end
		end
		touched = {}
	end
	local function applyAll()
		for _, door in ipairs(CS:GetTagged("DoorInteractable")) do pcall(phaseDoor, door) end
	end
	toggle(S_move, "Walk Through Doors", "doorphase", function(on) if on then applyAll() else restoreAll() end end)
	doorInfo = info(S_move, "")
	con(CS:GetInstanceAddedSignal("DoorInteractable"), function(door) task.defer(function() pcall(phaseDoor, door) end) end)
	task.spawn(function()
		while H.alive do
			if state.doorphase then
				applyAll() -- neu gestreamte Türteile nachziehen
				local n = 0 for d in pairs(touched) do if d.Parent then n = n + 1 else touched[d] = nil end end
				doorInfo.Text = '<font color="#78ff8c">' .. n .. " door parts passable (local)</font>"
			else
				doorInfo.Text = ""
			end
			task.wait(2)
		end
	end)
	table.insert(H.conns, { Disconnect = function() pcall(restoreAll) end })
end

-- ================= INFINITE STAMINA =================
-- Stamina lebt rein clientseitig im Actor PlayerScripts.FrameworkActor (FrameworkClient.Stamina-Tabelle mit
-- step/publish/Value/Max). Per run_on_actor läuft dort ein Loop, der Value jeden Frame auf Max setzt -> kein
-- Verbrauch, Anzeige bleibt voll. Steuerung über Attribute am Actor (TSC_NoStam an/aus, TSC_NSGen = Instanz-ID:
-- alter Loop beendet sich bei Re-Execute selbst). Keine Hooks, nur Tabellenwert.
state.nostam = sv("nostam", false)
do
	local actor = lp:WaitForChild("PlayerScripts"):FindFirstChild("FrameworkActor")
	local gen = tostring(os.clock()) .. "_" .. tostring(math.random(1, 1e9))
	local stamInfo
	local function setFlag()
		if actor then pcall(function() actor:SetAttribute("TSC_NoStam", state.nostam and true or false) end) end
	end
	toggle(S_move, "Infinite Stamina", "nostam", function() setFlag() end)
	stamInfo = info(S_move, "")
	if actor and run_on_actor then
		pcall(function() actor:SetAttribute("TSC_NSGen", gen) end)
		setFlag()
		pcall(run_on_actor, actor, [==[
			-- (script ist in Potassiums Actor-Env eine Tabelle, keine Instance -> Actor über Pfad holen)
			local actor = game:GetService("Players").LocalPlayer.PlayerScripts:FindFirstChild("FrameworkActor")
			local myGen = actor:GetAttribute("TSC_NSGen")
			local RS = game:GetService("RunService")
			local tbl, alt, lastScan = nil, false, 0
			local function scan()
				for _, t in ipairs(getgc(true)) do
					if type(t) == "table" and rawget(t, "LockDebuff") ~= nil and rawget(t, "Max") ~= nil
						and type(rawget(t, "step")) == "function" then
						return t
					end
					-- Fake-/aeltere TSC-Versionen: StatsPanel-Tabelle mit Stamina/MaxStamina/StaminaBool/UpdateStamina
					if type(t) == "table" and rawget(t, "MaxStamina") ~= nil and rawget(t, "StaminaLockDebuff") ~= nil
						and type(rawget(t, "UpdateStamina")) == "function" then
						return t, true
					end
				end
			end
			while actor:GetAttribute("TSC_NSGen") == myGen do
				if actor:GetAttribute("TSC_NoStam") then
					if not tbl and os.clock() - lastScan > 3 then lastScan = os.clock(); tbl, alt = scan() end
					if tbl then
						local ok = pcall(function()
							if alt then
								if tbl.Stamina < tbl.MaxStamina then tbl.Stamina = tbl.MaxStamina end
								if (tbl.StaminaBool or 0) > 0 then tbl.StaminaBool = 0 end
							else
								if tbl.Value < tbl.Max then tbl.Value = tbl.Max end
								if (tbl.Bool or 0) > 0 then tbl.Bool = 0 end
							end
						end)
						if not ok then tbl = nil end
					end
					actor:SetAttribute("TSC_NSFound", tbl ~= nil)
				end
				RS.Heartbeat:Wait()
			end
		]==])
		task.spawn(function()
			while H.alive do
				local found = actor:GetAttribute("TSC_NSFound")
				stamInfo.Text = state.nostam and (found and '<font color="#78ff8c">stamina locked at max</font>' or "searching stamina table...") or ""
				task.wait(1)
			end
		end)
		table.insert(H.conns, { Disconnect = function()
			pcall(function() actor:SetAttribute("TSC_NSGen", nil); actor:SetAttribute("TSC_NoStam", false) end)
		end })
	else
		stamInfo.Text = "FrameworkActor / run_on_actor not available"
	end
end

-- ================= DESYNC INVIS =================
-- Eigener Char ist client-owned -> der Server übernimmt die CFrame, die nach Heartbeat gesendet wird.
-- Heartbeat: HRP auf Versteck (senkrecht unter mir, Y=-depth; Map geht bis ~-611, FallenPartsDestroyHeight=-5000)
-- -> das repliziert. Vor dem Rendern (RenderPriority.First) zurück auf echte Pos -> Physik/Kamera/Bewegung lokal normal.
-- Folgen: andere sehen/streamen dich nicht; serverseitige Distanzchecks (Prompts, Türen, Pickups, evtl. Guns) laufen ins Leere.
state.desync = false -- bewusst NICHT persistent: nie automatisch beim Laden an
state.desyncDepth = sv("desyncDepth", 2000)
local desyncReal = nil
toggle(S_move, "Desync Invis (risky)", "desync", function(on)
	if not on and desyncReal then
		local r = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
		if r then r.CFrame = desyncReal end
		desyncReal = nil
	end
end)
slider(S_move, "Hide Depth (Y)", 800, 4500, state.desyncDepth, function(v)
	state.desyncDepth = math.floor(v / 50 + 0.5) * 50
	return "-" .. state.desyncDepth
end, "desyncDepth")
info(S_move, "Others see nothing; prompts/doors/pickups won't work while on (server thinks you're underground).")
con(RunService.Heartbeat, function()
	if not state.desync then return end
	local c = lp.Character
	local r = c and c:FindFirstChild("HumanoidRootPart")
	local hum = c and c:FindFirstChildOfClass("Humanoid")
	if not (r and hum) or hum.Health <= 0 then desyncReal = nil return end
	desyncReal = r.CFrame
	r.CFrame = CFrame.new(r.Position.X, -state.desyncDepth, r.Position.Z) * (r.CFrame - r.CFrame.Position)
end)
RunService:BindToRenderStep("TSC_DesyncRestore", Enum.RenderPriority.First.Value, function()
	if desyncReal then
		local r = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
		if r then r.CFrame = desyncReal end
		desyncReal = nil
	end
end)
table.insert(H.conns, { Disconnect = function() pcall(function() RunService:UnbindFromRenderStep("TSC_DesyncRestore") end) end })

-- ================= TURRET WIPE =================
-- workspace.EOP.TurretsFolder: vorhandene Turrets lokal löschen + neu gestreamte/gespawnte beim Erscheinen.
-- Rein clientseitig (Destroy), keine Remotes. Beim Ausschalten kommen gelöschte erst per Re-Stream/Rejoin zurück.
state.turrets = sv("turrets", false)
local turretConn, turretFolder, turretKilled = nil, nil, 0
local function killTurret(t)
	if t:IsA("Model") or t:IsA("BasePart") then
		if pcall(function() t:Destroy() end) then turretKilled = turretKilled + 1 end
	end
end
local function turretStop()
	if turretConn then turretConn:Disconnect(); turretConn = nil end
	turretFolder = nil
end
local function turretStart(folder)
	turretStop()
	turretFolder = folder
	for _, t in ipairs(folder:GetChildren()) do killTurret(t) end
	turretConn = folder.ChildAdded:Connect(killTurret)
	table.insert(H.conns, turretConn)
end
toggle(S_world, "Delete Turrets", "turrets", function(on) if not on then turretStop() end end)
local turretInfo = info(S_world, "Turrets: -")
-- Ordner kann später geladen/ersetzt werden -> jede Sekunde prüfen
task.spawn(function()
	while H.alive do
		local eop = workspace:FindFirstChild("EOP")
		local f = eop and eop:FindFirstChild("TurretsFolder")
		if state.turrets then
			if f and f ~= turretFolder then turretStart(f) elseif not f then turretStop() end
		end
		if not state.turrets then
			turretInfo.Text = "Turrets: " .. (f and (#f:GetChildren() .. " in folder") or "folder not loaded")
		else
			turretInfo.Text = ('Turrets: <font color="#d266b4">%d deleted</font>%s'):format(turretKilled, f and "" or " · folder not loaded")
		end
		task.wait(1)
	end
end)

-- ================= MARKER =================
local markHL = Instance.new("Highlight")
markHL.Name = "TSC_MARK_HL"; markHL.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
markHL.FillColor = Color3.fromRGB(255, 40, 40); markHL.FillTransparency = 0.55
markHL.OutlineColor = Color3.fromRGB(255, 220, 60); markHL.OutlineTransparency = 0
markHL.Enabled = false; markHL.Parent = gui

-- Label + Punkt als 2D-Projektion (hängt nicht am Character -> funktioniert auch, wenn er rausgestreamt ist)
local markLbl = Instance.new("TextLabel")
markLbl.AnchorPoint = Vector2.new(0.5, 1); markLbl.Size = UDim2.fromOffset(240, 40); markLbl.BackgroundTransparency = 1
markLbl.Font = Enum.Font.GothamBlack; markLbl.TextSize = 15; markLbl.TextColor3 = Color3.fromRGB(255, 90, 90)
markLbl.TextStrokeTransparency = 0.2; markLbl.Visible = false; markLbl.Parent = gui
local markDot = Instance.new("Frame")
markDot.AnchorPoint = Vector2.new(0.5, 0.5); markDot.Size = UDim2.fromOffset(10, 10); markDot.BorderSizePixel = 0
markDot.Rotation = 45; markDot.Visible = false; markDot.Parent = gui


-- Randpfeil, wenn Ziel off-screen / hinter mir
local arrow = Instance.new("TextLabel")
arrow.Size = UDim2.fromOffset(160, 40); arrow.AnchorPoint = Vector2.new(0.5, 0.5); arrow.BackgroundTransparency = 1
arrow.Font = Enum.Font.GothamBlack; arrow.TextSize = 16; arrow.TextColor3 = Color3.fromRGB(255, 60, 60)
arrow.TextStrokeTransparency = 0; arrow.Visible = false; arrow.Parent = gui

local markInfo = info(S_mark, "Target: -", T.accent)

local search = Instance.new("TextBox")
search.Size = UDim2.new(1, 0, 0, 18); search.BackgroundColor3 = T.track; search.BorderSizePixel = 0; search.Font = T.font
search.TextSize = 12; search.TextColor3 = T.text; search.PlaceholderText = "search player..."
search.PlaceholderColor3 = T.dim; search.TextXAlignment = Enum.TextXAlignment.Left
search.Text = ""; search.ClearTextOnFocus = false; search.LayoutOrder = nextOrder(S_mark); search.Parent = S_mark.f
stroke(search); corner(search, 2)
Instance.new("UIPadding", search).PaddingLeft = UDim.new(0, 6)

local list = Instance.new("ScrollingFrame")
list.Size = UDim2.new(1, 0, 0, 300); list.BackgroundColor3 = T.bg; list.BorderSizePixel = 0; list.ScrollBarThickness = 2
list.ScrollBarImageColor3 = T.accent; list.LayoutOrder = nextOrder(S_mark)
list.AutomaticCanvasSize = Enum.AutomaticSize.Y; list.CanvasSize = UDim2.new(); list.Parent = S_mark.f
stroke(list)
local lay = Instance.new("UIListLayout", list); lay.Padding = UDim.new(0, 1); lay.SortOrder = Enum.SortOrder.Name

local function markedPlayer()
	if not state.markId then return nil end
	return Players:GetPlayerByUserId(state.markId)
end

local rebuildList
local function setMark(p)
	if p then state.markId = p.UserId; state.markName = p.Name else state.markId = nil; state.markName = nil end
	rebuildList()
end
button(S_mark, "Clear Target", function() setMark(nil) end)
local plCount = info(S_plInfo, "Players: -")
info(S_plInfo, "Click a player to mark them: highlight, label and an edge arrow when off-screen. Click again to unmark.")
task.spawn(function()
	while H.alive do
		plCount.Text = ("Players: %d / %d"):format(#Players:GetPlayers(), Players.MaxPlayers)
		task.wait(1)
	end
end)

function rebuildList()
	for _, c in ipairs(list:GetChildren()) do if c:IsA("TextButton") then c:Destroy() end end
	local q = search.Text:lower()
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= lp and (q == "" or p.Name:lower():find(q, 1, true) or p.DisplayName:lower():find(q, 1, true)) then
			local marked = state.markId == p.UserId
			local b = Instance.new("TextButton")
			b.Name = p.Name:lower(); b.Size = UDim2.new(1, -4, 0, 18); b.BorderSizePixel = 0; b.AutoButtonColor = false
			b.BackgroundColor3 = marked and Color3.fromRGB(70, 38, 60) or T.bg
			b.BackgroundTransparency = marked and 0 or 1
			b.Font = T.font; b.TextSize = 12; b.TextXAlignment = Enum.TextXAlignment.Left
			b.TextTruncate = Enum.TextTruncate.AtEnd
			b.TextColor3 = marked and T.accent or teamColor(p)
			b.Text = (marked and " ◆ " or "   ") .. p.DisplayName .. " (@" .. p.Name .. ")  " .. (p.Team and p.Team.Name or "")
			b.Parent = list
			b.MouseButton1Click:Connect(function()
				if state.markId == p.UserId then setMark(nil) else setMark(p) end
			end)
		end
	end
end
con(search:GetPropertyChangedSignal("Text"), function() rebuildList() end)
con(Players.PlayerAdded, function() rebuildList() end)
con(Players.PlayerRemoving, function(p) removeEsp(p); task.defer(rebuildList) end)
rebuildList()

-- ================= UPDATE-LOOPS =================
local function rootOf(p)
	local c = p.Character
	return c and (c:FindFirstChild("HumanoidRootPart") or c:FindFirstChild("Head") or c.PrimaryPart), c
end

-- Dropped-Items-ESP (Spieler-ESP läuft per RenderStep, siehe ESP-Block)
task.spawn(function()
	while H.alive do
		-- Dropped Items
		if state.items then
			local myRoot = rootOf(lp)
			local myPos = myRoot and myRoot.Position or cam.CFrame.Position
			for _, t in ipairs(workspace:GetChildren()) do
				if isDropped(t) then
					local h = t.Handle
					local d = (h.Position - myPos).Magnitude
					if d <= state.espDist then
						local o = itemObjs[t]
						if not o then
							local bb = Instance.new("BillboardGui")
							bb.AlwaysOnTop = true; bb.Size = UDim2.fromOffset(160, 26); bb.StudsOffset = Vector3.new(0, 1.5, 0)
							bb.LightInfluence = 0; bb.Parent = espFolder
							local l = Instance.new("TextLabel")
							l.Size = UDim2.fromScale(1, 1); l.BackgroundTransparency = 1; l.Font = Enum.Font.GothamBold
							l.TextSize = 12; l.TextColor3 = Color3.fromRGB(120, 255, 140); l.TextStrokeTransparency = 0.3; l.Parent = bb
							o = { bb = bb, lbl = l }
							itemObjs[t] = o
						end
						if o.bb.Adornee ~= h then o.bb.Adornee = h end
						-- Waffen (Tool mit GunData: Schuss- und Nahkampfwaffen) rot, Rest grün
						o.lbl.TextColor3 = t:FindFirstChild("GunData") and Color3.fromRGB(255, 70, 70) or Color3.fromRGB(120, 255, 140)
						o.lbl.Text = "▣ " .. t.Name .. "  " .. math.floor(d) .. "m"
						applyFade(o.lbl, fadeAlpha(d), 12)
					else
						clearItem(t)
					end
				elseif itemObjs[t] then
					clearItem(t)
				end
			end
		end
		task.wait(state.updInt)
	end
end)

-- Marker jeden Frame
-- StreamingEnabled: außerhalb der Streaming-Reichweite ist der Character lokal Parent=nil und seine Position
-- eingefroren (Server schickt nichts). Dann: letzte bekannte Position (grau) + Alter; live wieder, sobald er reinstreamt.
local markLast = { id = nil, pos = nil, t = nil }
-- letzte gesehene Position ALLER Spieler (2 Hz), damit auch rausgestreamte Ziele einen Anker haben
local lastSeen = {} -- [userId] = {pos=, t=}
task.spawn(function()
	while H.alive do
		for _, pl in ipairs(Players:GetPlayers()) do
			local c = pl.Character
			local rr = c and c:FindFirstChild("HumanoidRootPart")
			if rr and c:IsDescendantOf(workspace) then lastSeen[pl.UserId] = { pos = rr.Position, t = os.clock() } end
		end
		task.wait(0.5)
	end
end)
con(Players.PlayerRemoving, function(pl) lastSeen[pl.UserId] = nil end)
local function markHide() markHL.Enabled = false; markLbl.Visible = false; markDot.Visible = false; arrow.Visible = false end
con(RunService.RenderStepped, function()
	local p = markedPlayer()
	if not p then
		markHide()
		markInfo.Text = state.markName and ("Target: " .. state.markName .. " (offline)") or "Target: -"
		return
	end
	if markLast.id ~= p.UserId then markLast = { id = p.UserId } end
	local r, c = rootOf(p)
	local live = r and c and c:IsDescendantOf(workspace)
	local pos
	if live then
		pos = r.Position; markLast.pos = pos; markLast.t = os.clock()
		if markHL.Adornee ~= c then markHL.Adornee = c end
		markHL.Enabled = true
	else
		markHL.Enabled = false
		local ls = lastSeen[p.UserId]
		if ls and (not markLast.t or ls.t > markLast.t) then markLast.pos = ls.pos; markLast.t = ls.t end
		pos = markLast.pos
	end
	if not pos then
		markHide()
		markInfo.Text = "Target: " .. p.Name .. (c and " (out of stream range, not seen yet)" or " (no char)")
		return
	end
	local myRoot = rootOf(lp)
	local d = myRoot and math.floor((pos - myRoot.Position).Magnitude) or 0
	local age = markLast.t and math.floor(os.clock() - markLast.t) or nil
	local stale = not live
	local col = stale and Color3.fromRGB(200, 160, 120) or Color3.fromRGB(255, 90, 90)
	local ageTxt = stale and (age and ("last seen " .. age .. "s ago") or "last known pos") or nil
	markInfo.Text = "Target: " .. p.Name .. "  " .. d .. "m" .. (ageTxt and ("  (" .. ageTxt .. ")") or "")

	local vp = cam.ViewportSize
	local sp, onScreen = cam:WorldToViewportPoint(pos + Vector3.new(0, stale and 0 or 3.5, 0))
	if onScreen and sp.Z > 0 then
		arrow.Visible = false
		markLbl.Position = UDim2.fromOffset(sp.X, sp.Y - 6); markLbl.TextColor3 = col
		markLbl.Text = "◆ " .. p.DisplayName .. " ◆\n" .. d .. "m" .. (ageTxt and ("  · " .. ageTxt) or "")
		markLbl.Visible = true
		markDot.Position = UDim2.fromOffset(sp.X, sp.Y); markDot.BackgroundColor3 = col; markDot.Visible = stale
	else
		markLbl.Visible = false; markDot.Visible = false
		arrow.TextColor3 = col
		local center = vp / 2
		local dir = Vector2.new(sp.X, sp.Y) - center
		if sp.Z < 0 then dir = -dir end
		if dir.Magnitude < 1 then dir = Vector2.new(0, -1) end
		dir = dir.Unit
		local m = 60
		local sx = (center.X - m) / math.max(math.abs(dir.X), 1e-3)
		local sy = (center.Y - m) / math.max(math.abs(dir.Y), 1e-3)
		local pos = center + dir * math.min(sx, sy)
		arrow.Position = UDim2.fromOffset(pos.X, pos.Y)
		arrow.Text = "➤ " .. p.DisplayName .. " " .. d .. "m"
		arrow.Rotation = 0
		arrow.Visible = true
	end
end)

-- ================= STAFF-RADAR =================
-- Gruppe 11577231: Rang >= 90 = Staff (External Command, Intern, Dept-Admin, Contractor, Devs);
-- plrUniqueTag_txt-Attribut = Staff-Tag (QA etc.). Panel oben mittig, immer sichtbar (auch wenn Hub zu).
-- Moderatoren/Admins stehen NICHT in der Hauptgruppe (dort oft nur L-3 o. ä.), sondern in "TSC Moderation Team" 33326090:
-- Rang >= 190 = Junior Moderators bis Holder (Staff); 170 Intelligence Access / 175 Forced LOA / 180 Suspended nur als Info.
-- Fake-TSC (andere PlaceId, eigene Gruppe mit identischer Rangstruktur): Gruppe des Spiel-Erstellers nehmen
local GROUP_ID, STAFF_MIN = (game.PlaceId ~= 7131355525 and game.CreatorType == Enum.CreatorType.Group) and game.CreatorId or 11577231, 90
H.MOD = { group = 33326090, min = 190, info = 170 } -- als H-Feld: Hauptchunk am 200-Locals-Limit
-- Fake "Sierra Research Corporation" (81826874): Modteam "SRC | Moderation Team" 825389872, Raenge 6 Intelligence Access
-- (Staff-Alts, z. B. AdmiralAckbarr), 10 Suspended, 20 Trial Admin ... 255 Holder -> ab 6 als Staff zaehlen
if GROUP_ID == 81826874 then H.MOD = { group = 825389872, min = 6, info = 6 } end
local rankCache = {} -- [userId] = {rank=, role=}
local function fetchRank(p)
	if rankCache[p.UserId] then return end
	rankCache[p.UserId] = { rank = -1, role = "?", mrank = -1 }
	task.spawn(function()
		local ok, r = pcall(function() return p:GetRankInGroup(GROUP_ID) end)
		local ok2, role = pcall(function() return p:GetRoleInGroup(GROUP_ID) end)
		local ok3, mr = pcall(function() return p:GetRankInGroup(H.MOD.group) end)
		local mrole
		if ok3 and mr >= H.MOD.info then
			local ok4, x = pcall(function() return p:GetRoleInGroup(H.MOD.group) end)
			mrole = ok4 and x or "?"
		end
		rankCache[p.UserId] = { rank = ok and r or -1, role = ok2 and role or "?", mrank = ok3 and mr or -1, mrole = mrole }
	end)
end
local function staffInfo(p)
	local rc = rankCache[p.UserId]
	local tag = p:GetAttribute("plrUniqueTag_txt")
	if rc and rc.mrank >= H.MOD.min then return "Mod Team: " .. rc.mrole .. (tag and (" | " .. tag) or ""), true end
	if rc and rc.rank >= STAFF_MIN then return rc.role .. (tag and (" | " .. tag) or ""), true end
	if rc and rc.mrank >= H.MOD.info then return "Mod Team: " .. rc.mrole .. (tag and (" | " .. tag) or ""), false end
	if tag and tag ~= "" then return tostring(tag), false end
	return nil
end
for _, p in ipairs(Players:GetPlayers()) do fetchRank(p) end

local staffPanel = Instance.new("TextLabel")
staffPanel.AnchorPoint = Vector2.new(0.5, 0); staffPanel.Position = UDim2.new(0.5, 0, 0, 44)
staffPanel.Size = UDim2.fromOffset(0, 0); staffPanel.AutomaticSize = Enum.AutomaticSize.XY
staffPanel.BackgroundColor3 = T.bg; staffPanel.BackgroundTransparency = 0.1
staffPanel.Font = T.font; staffPanel.TextSize = 13; staffPanel.RichText = true
staffPanel.TextColor3 = T.text; staffPanel.TextXAlignment = Enum.TextXAlignment.Left
staffPanel.TextYAlignment = Enum.TextYAlignment.Top; staffPanel.Visible = false; staffPanel.Parent = gui
corner(staffPanel, 4); stroke(staffPanel, T.edge)
H.staffPanel = staffPanel -- verschiebbar gemacht weiter unten (H.movable ist später definiert)
local pad = Instance.new("UIPadding", staffPanel)
pad.PaddingLeft = UDim.new(0, 8); pad.PaddingRight = UDim.new(0, 8); pad.PaddingTop = UDim.new(0, 4); pad.PaddingBottom = UDim.new(0, 4)

state.staff = sv("staff", true)
toggle(S_staff, "Enabled", "staff", function() end)
local staffSummary = info(S_staff, "No staff detected.")
info(S_staff, "TSC group rank ≥ 90, Moderation Team rank ≥ 190, or staff tag. Panel stays visible at the top even with the menu closed.")

local staffObjs = {} -- [player] = {bb=, lbl=, box=}
local function clearStaffObj(p)
	local o = staffObjs[p]
	if o then pcall(function() o.bb:Destroy() end) pcall(function() o.box:Destroy() end) staffObjs[p] = nil end
end
con(Players.PlayerAdded, function(p) fetchRank(p) end)
con(Players.PlayerRemoving, function(p) clearStaffObj(p) end)

local function isInvisible(c)
	local any, vis = false, false
	for _, d in ipairs(c:GetDescendants()) do
		if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then
			any = true
			if d.Transparency < 0.9 then vis = true break end
		end
	end
	return any and not vis
end

local function esc(s) return (tostring(s):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")) end

task.spawn(function()
	while H.alive do
		local lines, n = {}, 0
		local myRoot = rootOf(lp)
		for _, p in ipairs(Players:GetPlayers()) do
			if p ~= lp then
				local sinfo, isStaff = staffInfo(p)
				if sinfo and state.staff then
					n = n + 1
					local c = p.Character
					local r = c and c:FindFirstChild("HumanoidRootPart")
					local status, col
					if not c then
						status, col = "KEIN CHAR (Spectate/Menü?)", "#ff4040"
					elseif not c.Parent then
						status, col = "nicht geladen (anderer Bereich)", "#aaaaaa"
					elseif isInvisible(c) then
						status, col = "UNSICHTBAR", "#ff4040"
					else
						status, col = "sichtbar", "#80ff80"
					end
					local dist = (r and myRoot) and math.floor((r.Position - myRoot.Position).Magnitude) or nil
					if dist and c and c.Parent and dist < 60 and status ~= "sichtbar" then col = "#ff00ff" end
					if p:GetAttribute("InMenu") then status = status .. " [InMenu]" end
					lines[#lines + 1] = ('<font color="%s">%s %s</font>  <font color="#9ab">%s</font>  %s%s'):format(
						isStaff and "#ffcc40" or "#8fd0ff", isStaff and "★" or "•", esc(p.Name .. (p.DisplayName ~= p.Name and (" (" .. p.DisplayName .. ")") or "")), esc(sinfo),
						('<font color="%s">%s</font>'):format(col, status), dist and ("  " .. dist .. "m") or "")
					-- Welt-Marker (auch für unsichtbare): Box am Root + Label, ignoriert ESP-Reichweite
					if r and c.Parent then
						local o = staffObjs[p]
						if not o then
							local bb = Instance.new("BillboardGui")
							bb.AlwaysOnTop = true; bb.Size = UDim2.fromOffset(220, 30); bb.StudsOffset = Vector3.new(0, 3.6, 0)
							bb.LightInfluence = 0; bb.Parent = gui
							local l = Instance.new("TextLabel")
							l.Size = UDim2.fromScale(1, 1); l.BackgroundTransparency = 1; l.Font = Enum.Font.GothamBold
							l.TextSize = 13; l.TextStrokeTransparency = 0.2; l.Parent = bb
							local box = Instance.new("BoxHandleAdornment")
							box.AlwaysOnTop = true; box.ZIndex = 5; box.Size = Vector3.new(2.2, 5, 1.4)
							box.Transparency = 0.6; box.Parent = gui
							o = { bb = bb, lbl = l, box = box }
							staffObjs[p] = o
						end
						o.bb.Adornee = r; o.box.Adornee = r
						o.box.Color3 = isStaff and Color3.fromRGB(255, 200, 40) or Color3.fromRGB(120, 200, 255)
						o.lbl.TextColor3 = o.box.Color3
						o.lbl.Text = (isStaff and "★ STAFF " or "• ") .. p.Name .. (p.DisplayName ~= p.Name and (" (" .. p.DisplayName .. ")") or "") .. (status ~= "sichtbar" and (" [" .. status .. "]") or "")
					else
						clearStaffObj(p)
					end
				else
					clearStaffObj(p)
				end
			end
		end
		if state.staff and n > 0 then
			staffPanel.Text = ('<font color="#d266b4">STAFF IM SERVER: %d</font>\n'):format(n) .. table.concat(lines, "\n")
			staffPanel.Visible = true
			staffSummary.Text = ('<font color="#d266b4">%d staff in server</font>'):format(n)
		else
			-- bei offenem Menü als Platzhalter sichtbar, damit man es verschieben kann
			staffPanel.Visible = state.staff and main.Visible
			if staffPanel.Visible then staffPanel.Text = '<font color="#d266b4">STAFF RADAR</font>\nno staff · drag to move' end
			staffSummary.Text = state.staff and "No staff detected." or "off"
		end
		task.wait(math.max(0.5, state.updInt))
	end
end)

-- ================= AUTO HACK (Minesweeper / HackingMinigame) =================
-- Übernommen aus minesweeper_bot.lua. Keine eigenen Remotes: liest den Mine-Layout-State clientseitig
-- (debug.getupvalues der Cell-Handler) bzw. löst per Solver, und feuert die EIGENEN Button-Handler
-- des Spiels (getconnections) -> das Spiel sendet seine normale Anfrage wie bei einem echten Klick.
state.ms = sv("ms", true); state.msReader = sv("msReader", true); state.msHints = sv("msHints", true)
state.msFlags = sv("msFlags", true); state.msPace = sv("msPace", 0); state.msClickDelay = sv("msClickDelay", 90)
toggle(S_ms, "Enabled", "ms", function() end)
toggle(S_ms, "Mine Reader (instant)", "msReader", function() end)
toggle(S_ms, "Use Hints", "msHints", function() end)
toggle(S_ms, "Place Flags", "msFlags", function() end)
slider(S_ms, "Solve Time (reader pacing)", 0, 30, state.msPace, function(v)
	state.msPace = math.floor(v + 0.5)
	return state.msPace == 0 and "instant" or (state.msPace .. "s")
end, "msPace")
slider(S_ms, "Click Delay (server boards)", 0, 300, state.msClickDelay, function(v)
	state.msClickDelay = math.floor(v / 5 + 0.5) * 5
	return state.msClickDelay .. " ms"
end, "msClickDelay")
local msStatus = info(S_ms, "Status: idle · waiting for hack")
local function msLog(s)
	-- bewusst KEIN print: Adonis scannt LogService/Konsole nach Executor-Funktionsnamen
	-- (getconnections, firesignal, ...) -> Crash-Kick. Status nur im Menue.
	msStatus.Text = "Status: " .. s
end
local function msBot()
	local PlayerGui   = lp:WaitForChild("PlayerGui")

	-- ---- config ----------------------------------------------------------------
	local MINE_COUNT    = nil        -- manual override; nil = auto-detect from the level
	local LEVEL_MINES   = {          -- mines per level (fill in any you know)
	    [5] = 200,
	    [6] = 400,
	}
	local CYCLE_WAIT    = 0.05       -- pause between full read/solve cycles (after a batch)
	local MAX_ENUM      = 26         -- max frontier-component size to enumerate exactly
	local ENUM_ALL      = 26         -- endgame: full-board enumeration when <= this many covered cells
	local ENUM_BUDGET   = 2000000    -- safety cap on search nodes per component (prevents hangs)
	local FIRST_MOVE    = "center"   -- "center" or "corner": opening click on a blank board
	-- read stability / anti-stale-guess timing. The #1 cause of needless 50/50s is
	-- guessing on a board that hadn't finished updating. Levels 5-6 are dense AND
	-- laggy, so we settle HARD there; levels 1-4 are small/snappy and stay crazy fast.
	local SLOW_LEVELS   = { [5] = true, [6] = true }   -- levels that get the cautious timing
	local SLOW_MIN_MINES = 150        -- fallback: treat as "slow" if mines >= this (level label unread)
	local STABLE_MAX    = 20          -- max reads before giving up waiting for it to settle
	--                       slow (lv5-6) , fast (lv1-4)
	local STABLE_NEED_S, STABLE_NEED_F = 3   , 2     -- consecutive identical reads required
	local STABLE_WAIT_S, STABLE_WAIT_F = 0.03, 0     -- delay between reads
	local STUCK_CONFIRM_S, STUCK_CONFIRM_F = 0.25, 0 -- settle before any probability move
	local USE_WMC       = true        -- slow levels only: weight marginals by the global mine budget (exact WMC)
	local HINT_CANDIDATES = 16        -- slow levels: cap on cells scored for the "best hint" 1-ply search
	-- ---- direct mine-layout reader (the board is fully client-side) ------------
	local SOLVE_TIME    = {}          -- per-level reveal spread in seconds; empty = no pacing (fastest)
	local CHEAT_SHUFFLE = false       -- no pacing -> order is irrelevant; reveal in natural cell order

	-- current board's level / mine count (forward-declared so the timing helper below
	-- can read them; detection lives further down).
	local CURRENT_MINES = nil
	local CURRENT_LEVEL = nil
	-- are we on a slow (dense) level? drives the settle timing.
	local function isSlowLevel()
	    if CURRENT_LEVEL and SLOW_LEVELS[CURRENT_LEVEL] then return true end
	    if CURRENT_MINES and CURRENT_MINES >= SLOW_MIN_MINES then return true end   -- label unreadable
	    return false
	end

	-- ---- click WITHOUT moving the mouse ----------------------------------------
	-- The game listens on Button.MouseButton1Down (reveal) and MouseButton2Down (flag).
	-- We fire those handlers directly: no cursor movement, no jitter, no focus loss.
	-- The game's own handler runs and sends its normal request to the server.
	local hasGC = typeof(getconnections) == "function"
	local hasFS = typeof(firesignal) == "function"
	if not hasGC and not hasFS then msLog("no getconnections/firesignal -> disabled"); return end

	local function fire(signal, ...)
	    local args = table.pack(...)
	    if hasGC then
	        local ok, conns = pcall(getconnections, signal)
	        if ok and conns and #conns > 0 then
	            for _, c in ipairs(conns) do
	                -- Handler in EIGENEM Thread starten: c:Fire ist nicht yieldbar -> das task.wait(1) in
	                -- selectDoor(nil) (Sieg/Niederlage) brach ab, Canvas blieb offen + clearBoard lief nie,
	                -- und der Bot hing nach dem ersten Hack. task.spawn laeuft bis zum ersten Yield sofort.
	                local f
	                pcall(function() f = c.Function end)
	                if typeof(f) == "function" then
	                    task.spawn(f, table.unpack(args, 1, args.n))
	                else
	                    pcall(function() c:Fire(table.unpack(args, 1, args.n)) end)
	                end
	            end
	            return true
	        end
	    end
	    if hasFS then return (pcall(firesignal, signal, table.unpack(args, 1, args.n))) end
	    return false
	end

	local function centreOf(cell)
	    return cell.AbsolutePosition.X + cell.AbsoluteSize.X/2,
	           cell.AbsolutePosition.Y + cell.AbsoluteSize.Y/2
	end

	-- fire synchronously, no per-click wait; we wait once per batch instead
	local function revealCell(cell)
	    local b = cell:FindFirstChild("Button"); if not b then return end
	    local hid = cell:FindFirstChild("Hidden")
	    if hid and not hid.Visible then return end -- schon (per Kaskade) aufgedeckt -> kein Doppelklick/Chord
	    local x, y = centreOf(cell)
	    fire(b.MouseButton1Down, x, y)
	    fire(b.MouseButton1Up, x, y)
	    -- Server-Boards: jeder Klick = HackReveal-Anfrage -> nicht übermenschlich schnell
	    if state.msClickDelay > 0 then task.wait(state.msClickDelay / 1000 * (0.7 + 0.6 * math.random())) end
	end

	local function flagCell(cell)
	    local b = cell:FindFirstChild("Button"); if not b then return end
	    local x, y = centreOf(cell)
	    fire(b.MouseButton2Down, x, y)
	    fire(b.MouseButton2Up, x, y)
	end

	-- ---- hints -----------------------------------------------------------------
	-- Mechanic: click the magnifying glass to EQUIP a hint (HintEquipped becomes
	-- visible), then click a cell -> it's a guaranteed-safe probe (mine -> flag,
	-- else -> reveal). We equip, then probe the most informative cell.
	-- Set HINT_EQUIP_NAME after the buttons-probe if auto-detect picks wrong.
	local HINT_EQUIP_NAME = nil
	local EQUIP_KEYWORDS  = { "hint", "magn", "glass", "search", "zoom", "help", "scan" }

	local function root4(board) return board.Parent or board end

	local function hintsLeft(board)
	    local lbl = root4(board):FindFirstChild("HintsLeft", true)
	    if lbl and lbl:IsA("TextLabel") then return tonumber(lbl.Text:match("%d+")) or 0 end
	    return 0
	end

	local function findEquipButton(board)
	    local root = root4(board)
	    if HINT_EQUIP_NAME then
	        local b = root:FindFirstChild(HINT_EQUIP_NAME, true)
	        if b then return b end
	    end
	    -- The magnifier is named "Button" but lives under a "Hints" frame, so match
	    -- on the ANCESTOR chain (this also excludes the identically-named Exit button).
	    for _, d in ipairs(root:GetDescendants()) do
	        if d:IsA("GuiButton") and d.Visible and not (d.Parent and d.Parent.Name == "Cell") then
	            local node = d
	            while node and node ~= root.Parent do
	                local n = node.Name:lower()
	                for _, kw in ipairs(EQUIP_KEYWORDS) do
	                    if n:find(kw) then return d end
	                end
	                node = node.Parent
	            end
	        end
	    end
	end

	local function isEquipped(board)
	    local he = root4(board):FindFirstChild("HintEquipped", true)
	    return he and he.Visible == true
	end

	-- probe one cell safely using a hint. returns true only if the cell was probed
	-- WITH a hint confirmed equipped (otherwise the click would be a real, deadly
	-- reveal of the most-likely-mine cell -- so we refuse to click).
	local function useHintOn(board, cell)
	    if not isEquipped(board) then
	        local eq = findEquipButton(board)
	        if not eq then
	            msLog("no magnifier button found (run minesweeper_buttonsprobe).")
	            return false
	        end
	        local ex, ey = centreOf(eq)
	        fire(eq.MouseButton1Down, ex, ey)
	        fire(eq.MouseButton1Up, ex, ey)
	        -- WAIT until the hint is actually equipped before probing
	        local t0 = os.clock()
	        while not isEquipped(board) and os.clock() - t0 < 0.8 do task.wait() end
	    end
	    if not isEquipped(board) then
	        msLog("hint failed to equip -> not probing (avoids a real click on a mine).")
	        return false
	    end
	    revealCell(cell)   -- equip confirmed: this click is the safe probe
	    msLog("hint probe fired (equip confirmed).")
	    return true
	end

	-- ---- board location --------------------------------------------------------
	local function dominantSizeCount(c)
	    local sizes = {}
	    for _, ch in ipairs(c:GetChildren()) do
	        if ch:IsA("GuiObject") then
	            local s = ch.AbsoluteSize
	            if s.X > 4 and s.Y > 4 then
	                local k = math.floor(s.X/2)*2 .. "_" .. math.floor(s.Y/2)*2
	                sizes[k] = (sizes[k] or 0) + 1
	            end
	        end
	    end
	    local bk, bc = nil, 0
	    for k, n in pairs(sizes) do if n > bc then bk, bc = k, n end end
	    return bc, bk
	end

	local function findBoard(root)
	    root = root or PlayerGui
	    local best, bc = nil, 0
	    for _, d in ipairs(root:GetDescendants()) do
	        if d:IsA("GuiObject") and d.Visible and #d:GetChildren() >= 9 then
	            local c = dominantSizeCount(d)
	            if c > bc then best, bc = d, c end
	        end
	    end
	    return best
	end

	-- ---- read board into a grid ------------------------------------------------
	local function vis(o, n) local c = o:FindFirstChild(n); return c and c.Visible == true end

	-- returns: grid[r][c] = {cell, state, num}, rows, cols, gridGeom
	local function readBoard(board)
	    local cells = {}
	    local _, domKey = dominantSizeCount(board)
	    for _, ch in ipairs(board:GetChildren()) do
	        if ch:IsA("GuiObject") then
	            local s = ch.AbsoluteSize
	            if (math.floor(s.X/2)*2 .. "_" .. math.floor(s.Y/2)*2) == domKey then
	                cells[#cells+1] = ch
	            end
	        end
	    end
	    if #cells == 0 then return nil end

	    -- cluster centres into columns / rows
	    local function cluster(vals, tol)
	        table.sort(vals)
	        local g = {}
	        for _, v in ipairs(vals) do
	            local last = g[#g]
	            if last and math.abs(v-last.mean) <= tol then
	                last.sum=last.sum+v; last.n=last.n+1; last.mean=last.sum/last.n
	            else g[#g+1] = {sum=v,n=1,mean=v} end
	        end
	        return g
	    end
	    local xs, ys = {}, {}
	    for _, c in ipairs(cells) do
	        xs[#xs+1] = c.AbsolutePosition.X + c.AbsoluteSize.X/2
	        ys[#ys+1] = c.AbsolutePosition.Y + c.AbsoluteSize.Y/2
	    end
	    local cs = cells[1].AbsoluteSize
	    local cols = cluster(xs, cs.X*0.4)
	    local rows = cluster(ys, cs.Y*0.4)
	    local function nearest(groups, v)
	        local bi, bd = 1, math.huge
	        for i, g in ipairs(groups) do local d=math.abs(v-g.mean); if d<bd then bi,bd=i,d end end
	        return bi
	    end

	    local grid = {}
	    for r = 1, #rows do grid[r] = {} end
	    for _, c in ipairs(cells) do
	        local cx = c.AbsolutePosition.X + c.AbsoluteSize.X/2
	        local cy = c.AbsolutePosition.Y + c.AbsoluteSize.Y/2
	        local ci, ri = nearest(cols, cx), nearest(rows, cy)
	        local state, num = "BLANK", 0
	        if vis(c, "Flag") then state = "FLAG"
	        elseif vis(c, "Hidden") then state = "COVERED"
	        elseif vis(c, "Mine") then state = "MINE"
	        else
	            local nb = c:FindFirstChild("Number")
	            if nb and nb.Visible then
	                local t = tonumber(nb.Text)
	                if t and t > 0 then state, num = "NUM", t end
	            end
	        end
	        grid[ri][ci] = { cell = c, state = state, num = num }
	    end
	    return grid, #rows, #cols
	end

	-- a compact fingerprint of the board, to detect when it has settled
	local function signature(grid, R, C)
	    local t = {}
	    for r=1,R do for c=1,C do local g = grid[r][c]; t[#t+1] = (g and (g.state .. g.num)) or "x" end end
	    return table.concat(t, ",")
	end

	-- read repeatedly until two consecutive reads agree (board not mid-cascade).
	-- This stops us from acting on a half-revealed cell (e.g. Hidden off but Number
	-- not yet on, which would look like a false "0" and get us killed).
	local function readStable(board)
	    local slow = isSlowLevel()
	    local need = slow and STABLE_NEED_S or STABLE_NEED_F
	    local wait = slow and STABLE_WAIT_S or STABLE_WAIT_F
	    local grid, R, C = readBoard(board)
	    if not grid then return nil end
	    local sig = signature(grid, R, C)
	    local streak = 1                       -- how many consecutive reads have matched
	    for _ = 1, STABLE_MAX do
	        task.wait(wait)
	        local g2, R2, C2 = readBoard(board)
	        if not g2 then return grid, R, C end
	        local s2 = signature(g2, R2, C2)
	        if s2 == sig then
	            streak = streak + 1
	            grid, R, C = g2, R2, C2
	            if streak >= need then return grid, R, C end   -- held still long enough
	        else
	            streak = 1                     -- still changing -> restart the count
	            grid, R, C, sig = g2, R2, C2, s2
	        end
	    end
	    return grid, R, C
	end

	-- current board's level number and total mines (declared up top; detection here).
	local function detectLevel(board)
	    local db = root4(board):FindFirstChild("DifficultyButton", true)
	    if db and (db:IsA("TextButton") or db:IsA("TextLabel")) then
	        return tonumber(tostring(db.Text):match("%d+"))
	    end
	    return nil
	end
	-- read an on-screen "N unflagged mines" counter, if present
	local function readMineCounter()
	    for _, d in ipairs(PlayerGui:GetDescendants()) do
	        if d:IsA("TextLabel") and d.Visible then
	            local t = tostring(d.Text):lower()
	            if t:find("mine") then
	                local n = tonumber(t:match("%d+"))
	                if n then return n end
	            end
	        end
	    end
	end

	-- total mines = (unflagged-mines counter) + (flags already placed). Falls back
	-- to the level table, then to manual override.
	local function detectMines(board, grid, R, C)
	    if MINE_COUNT then return MINE_COUNT end
	    local counter = readMineCounter()
	    if counter and grid then
	        local flags = 0
	        for r=1,R do for c=1,C do if grid[r][c].state == "FLAG" then flags = flags + 1 end end end
	        return counter + flags
	    end
	    if CURRENT_LEVEL and LEVEL_MINES[CURRENT_LEVEL] then return LEVEL_MINES[CURRENT_LEVEL] end
	    return nil
	end

	-- ---- solver ----------------------------------------------------------------
	local NB = {{-1,-1},{-1,0},{-1,1},{0,-1},{0,1},{1,-1},{1,0},{1,1}}

	local function solve(grid, R, C)
	    local function key(r,c) return r*100+c end
	    local mine, safe = {}, {}           -- key -> true
	    local covered = {}                  -- list of {r,c} still unknown (covered, unflagged)

	    for r=1,R do for c=1,C do
	        local g = grid[r][c]
	        if g.state == "FLAG" then mine[key(r,c)] = true
	        elseif g.state == "COVERED" then covered[#covered+1] = {r,c} end
	    end end

	    -- build constraints from revealed numbers
	    local constraints = {}            -- each: { cells = {key,...}, n = mines among them }
	    for r=1,R do for c=1,C do
	        local g = grid[r][c]
	        if g.state == "NUM" or g.state == "BLANK" then
	            local unk, mc = {}, 0
	            for _, d in ipairs(NB) do
	                local nr, nc = r+d[1], c+d[2]
	                if grid[nr] and grid[nr][nc] then
	                    local ng = grid[nr][nc]
	                    if ng.state == "FLAG" then mc = mc + 1
	                    elseif ng.state == "COVERED" then unk[#unk+1] = key(nr,nc) end
	                end
	            end
	            if #unk > 0 then constraints[#constraints+1] = { cells = unk, n = g.num - mc } end
	        end
	    end end

	    local function markSafe(k) if not safe[k] then safe[k]=true; return true end end
	    local function markMine(k) if not mine[k] then mine[k]=true; return true end end

	    -- iterate basic rules + subset elimination to a fixpoint
	    local function setOf(list) local s={} for _,k in ipairs(list) do s[k]=true end return s end
	    local changed = true
	    local guard = 0
	    while changed and guard < 200 do
	        changed = false; guard = guard + 1
	        -- prune decided cells out of every constraint
	        for _, con in ipairs(constraints) do
	            local nc, nn = {}, con.n
	            for _, k in ipairs(con.cells) do
	                if mine[k] then nn = nn - 1
	                elseif safe[k] then -- drop
	                else nc[#nc+1] = k end
	            end
	            con.cells, con.n = nc, nn
	            if #con.cells > 0 then
	                if con.n <= 0 then
	                    for _, k in ipairs(con.cells) do if markSafe(k) then changed = true end end
	                elseif con.n >= #con.cells then
	                    for _, k in ipairs(con.cells) do if markMine(k) then changed = true end end
	                end
	            end
	        end
	        -- subset elimination
	        for i=1,#constraints do for j=1,#constraints do
	            if i ~= j then
	                local A, B = constraints[i], constraints[j]
	                if #A.cells > 0 and #B.cells > 0 and #A.cells < #B.cells then
	                    local bset = setOf(B.cells)
	                    local subset = true
	                    for _, k in ipairs(A.cells) do if not bset[k] then subset=false break end end
	                    if subset then
	                        local aset = setOf(A.cells)
	                        local diff = {}
	                        for _, k in ipairs(B.cells) do if not aset[k] then diff[#diff+1]=k end end
	                        local dn = B.n - A.n
	                        if #diff > 0 then
	                            if dn <= 0 then
	                                for _, k in ipairs(diff) do if markSafe(k) then changed=true end end
	                            elseif dn >= #diff then
	                                for _, k in ipairs(diff) do if markMine(k) then changed=true end end
	                            end
	                        end
	                    end
	                end
	            end
	        end end
	    end

	    -- if the cheap rules already produced an actionable move, skip the costly
	    -- enumeration this cycle -- act now, enumerate only when truly stuck.
	    local hasMove = false
	    for _, rc in ipairs(covered) do
	        local k = key(rc[1], rc[2])
	        if safe[k] or mine[k] then hasMove = true break end
	    end

	    -- reusable exact CSP enumerator over a set of cell keys + constraints.
	    -- returns forcedSafe(set), forcedMine(set), prob(map key->mine probability).
	    local function csp(cellKeys, cons, maxSize)
	        local fSafe, fMine, fProb = {}, {}, {}
	        local inSet = {}
	        for _, k in ipairs(cellKeys) do inSet[k] = true end
	        local live = {}
	        for _, con in ipairs(cons) do
	            local cs = {}
	            for _, k in ipairs(con.cells) do if inSet[k] then cs[#cs+1] = k end end
	            if #cs > 0 then live[#live+1] = { cells = cs, n = con.n } end
	        end
	        local cellCons = {}
	        for ci, con in ipairs(live) do
	            for _, k in ipairs(con.cells) do cellCons[k] = cellCons[k] or {}; table.insert(cellCons[k], ci) end
	        end
	        local seenCon = {}
	        for start=1,#live do
	            if not seenCon[start] then
	                local stack, compCons, compCellsSet = {start}, {}, {}
	                seenCon[start] = true
	                while #stack > 0 do
	                    local ci = table.remove(stack)
	                    compCons[#compCons+1] = ci
	                    for _, k in ipairs(live[ci].cells) do
	                        compCellsSet[k] = true
	                        for _, cj in ipairs(cellCons[k]) do
	                            if not seenCon[cj] then seenCon[cj]=true; stack[#stack+1]=cj end
	                        end
	                    end
	                end
	                local compCells = {}
	                for k in pairs(compCellsSet) do compCells[#compCells+1] = k end
	                if #compCells <= maxSize then
	                    -- order cells by constraint-graph connectivity so constraints
	                    -- finish early -> far stronger forward-checking (lets us enumerate
	                    -- much larger frontiers without blowing up).
	                    local adj = {}
	                    for _, ci in ipairs(compCons) do
	                        local cl = live[ci].cells
	                        for a=1,#cl do
	                            adj[cl[a]] = adj[cl[a]] or {}
	                            for b=1,#cl do if a ~= b then adj[cl[a]][cl[b]] = true end end
	                        end
	                    end
	                    local ordered, vis = {}, {}
	                    local function dfs(k)
	                        vis[k] = true; ordered[#ordered+1] = k
	                        for nb in pairs(adj[k] or {}) do if not vis[nb] then dfs(nb) end end
	                    end
	                    for _, k in ipairs(compCells) do if not vis[k] then dfs(k) end end
	                    compCells = ordered

	                    local idx = {}; for i,k in ipairs(compCells) do idx[k]=i end
	                    local cons2 = {}
	                    for _, ci in ipairs(compCons) do
	                        local cl = {}
	                        for _, k in ipairs(live[ci].cells) do cl[#cl+1] = idx[k] end
	                        cons2[#cons2+1] = { cells = cl, n = live[ci].n }
	                    end
	                    local cellInCons = {}
	                    for i=1,#compCells do cellInCons[i] = {} end
	                    for ciI, con in ipairs(cons2) do
	                        for _, i in ipairs(con.cells) do table.insert(cellInCons[i], ciI) end
	                    end
	                    local ones  = {}; for i=1,#cons2 do ones[i]=0 end
	                    local remn  = {}; for i=1,#cons2 do remn[i]=#cons2[i].cells end
	                    local assign = {}
	                    local solCount = 0
	                    local mineCnt = {}; for i=1,#compCells do mineCnt[i]=0 end
	                    local n = #compCells
	                    local nodes, aborted = 0, false
	                    local function rec(i)
	                        if aborted then return end
	                        nodes = nodes + 1
	                        if nodes > ENUM_BUDGET then aborted = true; return end
	                        if i > n then
	                            solCount = solCount + 1
	                            for j=1,n do if assign[j]==1 then mineCnt[j]=mineCnt[j]+1 end end
	                            return
	                        end
	                        for _, v in ipairs({0,1}) do
	                            local ok = true
	                            for _, ciI in ipairs(cellInCons[i]) do
	                                ones[ciI] = ones[ciI] + v
	                                remn[ciI] = remn[ciI] - 1
	                                if ones[ciI] > cons2[ciI].n or ones[ciI] + remn[ciI] < cons2[ciI].n then ok = false end
	                            end
	                            if ok then assign[i] = v; rec(i+1) end
	                            for _, ciI in ipairs(cellInCons[i]) do
	                                ones[ciI] = ones[ciI] - v
	                                remn[ciI] = remn[ciI] + 1
	                            end
	                            if aborted then return end
	                        end
	                    end
	                    rec(1)
	                    -- only trust the result if enumeration finished (a partial run
	                    -- would give WRONG forced cells -> never act on it).
	                    if not aborted and solCount > 0 then
	                        for i, k in ipairs(compCells) do
	                            if mineCnt[i] == 0 then fSafe[k] = true
	                            elseif mineCnt[i] == solCount then fMine[k] = true
	                            else fProb[k] = mineCnt[i] / solCount end
	                        end
	                    end
	                end
	            end
	        end
	        return fSafe, fMine, fProb
	    end

	    -- ---- WMC: exact marginals weighted by the global mine budget --------------
	    -- The cheap per-component CSP above counts every satisfying assignment EQUALLY,
	    -- which is only correct for a component in isolation. On a board with a known
	    -- mine total, a frontier config that uses k mines must be weighted by
	    -- C(sea, minesLeft-k) -- the number of ways the remaining mines fill the
	    -- unconstrained "sea". That weighting skews with mine density, so it matters
	    -- most on levels 5-6. We enumerate each frontier component into a mine-count
	    -- histogram, convolve the components, fold in the sea via binomial weights, and
	    -- read off exact marginals for frontier AND sea cells on one common scale.
	    -- Returns nil (caller falls back to the cheap path) if a component is too big
	    -- to enumerate, so there is never a regression versus before.
	    local function wmc(maxSize)
	        -- frontier = undecided cells appearing in some (pruned) constraint
	        local frontierSet = {}
	        for _, con in ipairs(constraints) do
	            for _, k in ipairs(con.cells) do
	                if not safe[k] and not mine[k] then frontierSet[k] = true end
	            end
	        end
	        -- sea = covered, still-undecided, NOT on the frontier
	        local U = 0
	        for _, rc in ipairs(covered) do
	            local k = key(rc[1], rc[2])
	            if not mine[k] and not safe[k] and not frontierSet[k] then U = U + 1 end
	        end
	        -- mines already pinned (flags + deductions all live in `mine`)
	        local knownMines = 0
	        for _ in pairs(mine) do knownMines = knownMines + 1 end
	        local Mrem = CURRENT_MINES - knownMines

	        -- connected-component decomposition; each component enumerated exactly into
	        -- a mine-count histogram H[m] and per-cell mine counts cellMine[localIdx][m].
	        local live = {}
	        for _, con in ipairs(constraints) do
	            local cs = {}
	            for _, k in ipairs(con.cells) do if frontierSet[k] then cs[#cs+1] = k end end
	            if #cs > 0 then live[#live+1] = { cells = cs, n = con.n } end
	        end
	        local cellCons = {}
	        for ci, con in ipairs(live) do
	            for _, k in ipairs(con.cells) do cellCons[k] = cellCons[k] or {}; table.insert(cellCons[k], ci) end
	        end
	        local comps = {}
	        local seenCon = {}
	        for start = 1, #live do
	            if not seenCon[start] then
	                local stack, compCons, cellSet = {start}, {}, {}
	                seenCon[start] = true
	                while #stack > 0 do
	                    local ci = table.remove(stack)
	                    compCons[#compCons+1] = ci
	                    for _, k in ipairs(live[ci].cells) do
	                        cellSet[k] = true
	                        for _, cj in ipairs(cellCons[k]) do
	                            if not seenCon[cj] then seenCon[cj] = true; stack[#stack+1] = cj end
	                        end
	                    end
	                end
	                local compCells = {}
	                for k in pairs(cellSet) do compCells[#compCells+1] = k end
	                if #compCells > maxSize then return nil end       -- too big -> fall back
	                local adj = {}
	                for _, ci in ipairs(compCons) do
	                    local cl = live[ci].cells
	                    for a = 1, #cl do
	                        adj[cl[a]] = adj[cl[a]] or {}
	                        for b = 1, #cl do if a ~= b then adj[cl[a]][cl[b]] = true end end
	                    end
	                end
	                local ordered, vseen = {}, {}
	                local function dfs(k)
	                    vseen[k] = true; ordered[#ordered+1] = k
	                    for nb in pairs(adj[k] or {}) do if not vseen[nb] then dfs(nb) end end
	                end
	                for _, k in ipairs(compCells) do if not vseen[k] then dfs(k) end end
	                compCells = ordered
	                local idx = {}; for i, k in ipairs(compCells) do idx[k] = i end
	                local cons2 = {}
	                for _, ci in ipairs(compCons) do
	                    local cl = {}
	                    for _, k in ipairs(live[ci].cells) do cl[#cl+1] = idx[k] end
	                    cons2[#cons2+1] = { cells = cl, n = live[ci].n }
	                end
	                local cellInCons = {}
	                for i = 1, #compCells do cellInCons[i] = {} end
	                for ciI, con in ipairs(cons2) do
	                    for _, i in ipairs(con.cells) do table.insert(cellInCons[i], ciI) end
	                end
	                local ones = {}; for i = 1, #cons2 do ones[i] = 0 end
	                local remn = {}; for i = 1, #cons2 do remn[i] = #cons2[i].cells end
	                local n = #compCells
	                local assign = {}
	                local H = {}
	                local cellMine = {}; for i = 1, n do cellMine[i] = {} end
	                local nodes, aborted = 0, false
	                local function rec(i, used)
	                    if aborted then return end
	                    nodes = nodes + 1
	                    if nodes > ENUM_BUDGET then aborted = true; return end
	                    if i > n then
	                        H[used] = (H[used] or 0) + 1
	                        for j = 1, n do if assign[j] == 1 then cellMine[j][used] = (cellMine[j][used] or 0) + 1 end end
	                        return
	                    end
	                    for _, v in ipairs({0, 1}) do
	                        local ok = true
	                        for _, ciI in ipairs(cellInCons[i]) do
	                            ones[ciI] = ones[ciI] + v
	                            remn[ciI] = remn[ciI] - 1
	                            if ones[ciI] > cons2[ciI].n or ones[ciI] + remn[ciI] < cons2[ciI].n then ok = false end
	                        end
	                        if ok then assign[i] = v; rec(i + 1, used + v) end
	                        for _, ciI in ipairs(cellInCons[i]) do
	                            ones[ciI] = ones[ciI] - v
	                            remn[ciI] = remn[ciI] + 1
	                        end
	                        if aborted then return end
	                    end
	                end
	                rec(1, 0)
	                if aborted then return nil end                    -- budget blown -> fall back
	                local total = 0
	                for _, cnt in pairs(H) do total = total + cnt end
	                if total == 0 then return nil end                 -- inconsistent -> fall back
	                comps[#comps+1] = { cells = compCells, H = H, cellMine = cellMine, total = total, n = n }
	            end
	        end

	        local totalUndecided = U
	        for _, comp in ipairs(comps) do totalUndecided = totalUndecided + comp.n end
	        if Mrem < 0 or Mrem > totalUndecided then return nil end   -- count inconsistent -> fall back

	        -- log-factorial table for the sea binomials C(U, .)
	        local lf = {}; lf[0] = 0
	        for i = 1, U do lf[i] = lf[i-1] + math.log(i) end
	        local function Cbin(nn, kk)
	            if kk < 0 or kk > nn then return 0 end
	            return math.exp(lf[nn] - lf[kk] - lf[nn-kk])
	        end

	        -- no frontier -> every covered cell is sea, uniform marginal
	        if #comps == 0 then
	            return {}, {}, {}, (U > 0) and (Mrem / U) or nil
	        end

	        -- normalized component histograms (poly in x^mines) + per-cell mine dists.
	        -- Dividing by total keeps magnitudes ~1; constant factors cancel in ratios.
	        local hpoly, cmdist = {}, {}
	        for ci, comp in ipairs(comps) do
	            local p = { deg = comp.n }
	            for m = 0, comp.n do p[m] = (comp.H[m] or 0) / comp.total end
	            hpoly[ci] = p
	            local cm = {}
	            for j = 1, comp.n do
	                local arr = {}
	                for m = 0, comp.n do arr[m] = (comp.cellMine[j][m] or 0) / comp.total end
	                cm[j] = arr
	            end
	            cmdist[ci] = cm
	        end

	        local function conv(a, b)
	            local r = { deg = a.deg + b.deg }
	            for i = 0, r.deg do r[i] = 0 end
	            for i = 0, a.deg do
	                local ai = a[i]
	                if ai ~= 0 then for j = 0, b.deg do r[i+j] = r[i+j] + ai * b[j] end end
	            end
	            return r
	        end

	        -- prefix/suffix products so "all components except i" is one lookup
	        local K = #comps
	        local ONE = { deg = 0, [0] = 1 }
	        local pref, suf = {}, {}
	        pref[0] = ONE
	        for i = 1, K do pref[i] = conv(pref[i-1], hpoly[i]) end
	        suf[K+1] = ONE
	        for i = K, 1, -1 do suf[i] = conv(suf[i+1], hpoly[i]) end
	        local Gall = pref[K]                                       -- all frontier comps combined

	        -- total weight W = sum_T Gall[T] * C(U, Mrem - T)
	        local W = 0
	        for T = 0, Gall.deg do
	            local g = Gall[T]
	            if g ~= 0 then W = W + g * Cbin(U, Mrem - T) end
	        end
	        if W <= 0 then return nil end

	        local fSafe, fMine, probOut = {}, {}, {}
	        for ci, comp in ipairs(comps) do
	            local Hrest = conv(pref[ci-1], suf[ci+1])              -- product of the OTHER comps
	            -- A[s] = sum_t Hrest[t] * C(U, s - t)   (others + sea filling the rest)
	            local A = {}
	            for s = 0, Mrem do
	                local acc = 0
	                for t = 0, Hrest.deg do
	                    local ht = Hrest[t]
	                    if ht ~= 0 then acc = acc + ht * Cbin(U, s - t) end
	                end
	                A[s] = acc
	            end
	            local cm = cmdist[ci]
	            for j = 1, comp.n do
	                local numer, arr = 0, cm[j]
	                for m = 0, comp.n do
	                    local q = arr[m]
	                    if q ~= 0 then
	                        local s = Mrem - m
	                        if s >= 0 then numer = numer + q * A[s] end
	                    end
	                end
	                local pmine = numer / W
	                local k = comp.cells[j]
	                if pmine <= 1e-9 then fSafe[k] = true
	                elseif pmine >= 1 - 1e-9 then fMine[k] = true
	                else probOut[k] = pmine end
	            end
	        end

	        -- sea-cell marginal = expected leftover mines per sea cell
	        local seaP = nil
	        if U > 0 then
	            local ET = 0
	            for T = 0, Gall.deg do
	                local g = Gall[T]
	                if g ~= 0 then ET = ET + T * g * Cbin(U, Mrem - T) end
	            end
	            ET = ET / W
	            seaP = (Mrem - ET) / U
	            if seaP < 0 then seaP = 0 elseif seaP > 1 then seaP = 1 end
	        end

	        return fSafe, fMine, probOut, seaP
	    end

	    local prob = {}   -- key -> mine probability  (prob[0] = sea-cell probability)
	    if not hasMove then
	        local usedWMC = false
	        if USE_WMC and isSlowLevel() and CURRENT_MINES then
	            local fs, fm, pr, seaP = wmc(MAX_ENUM)
	            if fs then                                  -- WMC succeeded (all comps enumerable)
	                for k in pairs(fs) do markSafe(k) end
	                for k in pairs(fm) do markMine(k) end
	                prob = pr
	                if seaP then prob[0] = seaP end         -- sentinel key 0 = sea probability
	                usedWMC = true
	            end
	        end

	        if not usedWMC then
	            -- (1) frontier cells touched by number constraints (unweighted CSP)
	            local fkeys, seenk = {}, {}
	            for _, con in ipairs(constraints) do
	                for _, k in ipairs(con.cells) do
	                    if not safe[k] and not mine[k] and not seenk[k] then seenk[k]=true; fkeys[#fkeys+1]=k end
	                end
	            end
	            local fs, fm, pr = csp(fkeys, constraints, MAX_ENUM)
	            for k in pairs(fs) do markSafe(k) end
	            for k in pairs(fm) do markMine(k) end
	            prob = pr

	            -- (2) global mine-count endgame: "rem mines among the covered cells".
	            -- Resolves the last cells that local number-logic alone cannot.
	            if CURRENT_MINES then
	                local km = 0
	                for r=1,R do for c=1,C do if grid[r][c].state == "FLAG" then km = km + 1 end end end
	                local unknown = {}
	                for _, rc in ipairs(covered) do
	                    local k = key(rc[1], rc[2])
	                    if mine[k] then km = km + 1
	                    elseif not safe[k] then unknown[#unknown+1] = k end
	                end
	                local rem = CURRENT_MINES - km
	                if rem <= 0 then
	                    for _, k in ipairs(unknown) do markSafe(k) end
	                elseif rem == #unknown then
	                    for _, k in ipairs(unknown) do markMine(k) end
	                elseif #unknown > 0 and #unknown <= ENUM_ALL then
	                    local cons = {}
	                    for _, con in ipairs(constraints) do
	                        if #con.cells > 0 then cons[#cons+1] = { cells = con.cells, n = con.n } end
	                    end
	                    cons[#cons+1] = { cells = unknown, n = rem }   -- total mines remaining
	                    local fs2, fm2, pr2 = csp(unknown, cons, ENUM_ALL)
	                    for k in pairs(fs2) do markSafe(k) end
	                    for k in pairs(fm2) do markMine(k) end
	                    for k, v in pairs(pr2) do prob[k] = v end
	                end
	            end
	        end
	    end

	    -- collect results
	    local toReveal, toFlag = {}, {}
	    for _, rc in ipairs(covered) do
	        local k = key(rc[1], rc[2])
	        if safe[k] and not mine[k] then toReveal[#toReveal+1] = rc
	        elseif mine[k] then toFlag[#toFlag+1] = rc end
	    end

	    -- ---- best hint target: maximize expected cells unlocked (1-ply) ----------
	    -- A hint is a guaranteed-SAFE probe, so survival is NOT a factor -- we spend it
	    -- purely for information. Score each undetermined frontier cell by the EXPECTED
	    -- number of OTHER frontier cells that become forced once its true state is
	    -- known: with prob p it's a mine (-> flagged), otherwise it reveals a number
	    -- whose value distribution comes from the neighbours' marginals. Under each
	    -- hypothesis we re-run only the cheap single-point + subset deduction (NO
	    -- enumeration), so this stays light. Slow levels only (needs WMC marginals);
	    -- computed only when there's nothing certain to reveal (i.e. we're stuck).
	    local hintTarget = nil
	    if #toReveal == 0 and USE_WMC and isSlowLevel() then
	        local cand = {}
	        for k, p in pairs(prob) do
	            if k ~= 0 and p > 0 and p < 1 then cand[#cand+1] = k end
	        end
	        if #cand > 0 then
	            -- fresh number-constraints from the grid, for the simulation
	            local baseCons = {}
	            for r=1,R do for c=1,C do
	                local g = grid[r][c]
	                if g.state == "NUM" or g.state == "BLANK" then
	                    local unk, mc = {}, 0
	                    for _, d in ipairs(NB) do
	                        local nr, nc = r+d[1], c+d[2]
	                        if grid[nr] and grid[nr][nc] then
	                            local ng = grid[nr][nc]
	                            if ng.state == "FLAG" then mc = mc + 1
	                            elseif ng.state == "COVERED" then unk[#unk+1] = key(nr, nc) end
	                        end
	                    end
	                    if #unk > 0 then baseCons[#baseCons+1] = { cells = unk, n = g.num - mc } end
	                end
	            end end

	            -- rank candidates by constraint degree and keep the top HINT_CANDIDATES
	            -- so the 1-ply search stays bounded on dense boards.
	            local degree = {}
	            for _, con in ipairs(baseCons) do
	                for _, k in ipairs(con.cells) do degree[k] = (degree[k] or 0) + 1 end
	            end
	            table.sort(cand, function(a, b) return (degree[a] or 0) > (degree[b] or 0) end)
	            if #cand > HINT_CANDIDATES then
	                for i = #cand, HINT_CANDIDATES + 1, -1 do cand[i] = nil end
	            end

	            local undet = {}
	            for _, k in ipairs(cand) do undet[k] = true end

	            -- run single-point + subset deduction from current knowledge + `extra`
	            -- hypothesis constraints; return how many `undet` cells (except `exclude`)
	            -- become forced.
	            local function countForced(extra, exclude)
	                local mineC, safeC = {}, {}
	                for k in pairs(mine) do mineC[k] = true end
	                for k in pairs(safe) do safeC[k] = true end
	                local cons = {}
	                for _, con in ipairs(baseCons) do
	                    local cc = {}; for _, k in ipairs(con.cells) do cc[#cc+1] = k end
	                    cons[#cons+1] = { cells = cc, n = con.n }
	                end
	                for _, con in ipairs(extra) do
	                    local cc = {}; for _, k in ipairs(con.cells) do cc[#cc+1] = k end
	                    cons[#cons+1] = { cells = cc, n = con.n }
	                end
	                local function setOf(list) local s={} for _,k in ipairs(list) do s[k]=true end return s end
	                local changed, guard = true, 0
	                while changed and guard < 200 do
	                    changed = false; guard = guard + 1
	                    for _, con in ipairs(cons) do
	                        local nc, nn = {}, con.n
	                        for _, k in ipairs(con.cells) do
	                            if mineC[k] then nn = nn - 1
	                            elseif safeC[k] then -- drop
	                            else nc[#nc+1] = k end
	                        end
	                        con.cells, con.n = nc, nn
	                        if #con.cells > 0 then
	                            if con.n <= 0 then
	                                for _, k in ipairs(con.cells) do if not safeC[k] then safeC[k]=true; changed=true end end
	                            elseif con.n >= #con.cells then
	                                for _, k in ipairs(con.cells) do if not mineC[k] then mineC[k]=true; changed=true end end
	                            end
	                        end
	                    end
	                    for i=1,#cons do for j=1,#cons do
	                        if i ~= j then
	                            local A, B = cons[i], cons[j]
	                            if #A.cells > 0 and #B.cells > 0 and #A.cells < #B.cells then
	                                local bset = setOf(B.cells)
	                                local subset = true
	                                for _, k in ipairs(A.cells) do if not bset[k] then subset=false break end end
	                                if subset then
	                                    local aset = setOf(A.cells)
	                                    local diff = {}
	                                    for _, k in ipairs(B.cells) do if not aset[k] then diff[#diff+1]=k end end
	                                    local dn = B.n - A.n
	                                    if #diff > 0 then
	                                        if dn <= 0 then
	                                            for _, k in ipairs(diff) do if not safeC[k] then safeC[k]=true; changed=true end end
	                                        elseif dn >= #diff then
	                                            for _, k in ipairs(diff) do if not mineC[k] then mineC[k]=true; changed=true end end
	                                        end
	                                    end
	                                end
	                            end
	                        end
	                    end end
	                end
	                local cnt = 0
	                for k in pairs(undet) do
	                    if k ~= exclude and (mineC[k] or safeC[k]) then cnt = cnt + 1 end
	                end
	                return cnt
	            end

	            -- covered (still-unknown) neighbours of a cell -- those its number constrains
	            local function coveredNbrs(k)
	                local r = math.floor(k / 100); local c = k - r * 100
	                local nb = {}
	                for _, d in ipairs(NB) do
	                    local nr, nc = r + d[1], c + d[2]
	                    if grid[nr] and grid[nr][nc] and grid[nr][nc].state == "COVERED" then
	                        nb[#nb+1] = key(nr, nc)
	                    end
	                end
	                return nb
	            end

	            local best, bestScore, bestEnt = nil, -1, -1
	            for _, k in ipairs(cand) do
	                local p = prob[k]
	                -- mine outcome: c gets flagged
	                local uMine = countForced({ { cells = {k}, n = 1 } }, k)
	                -- safe outcome: c reveals a number -> covered-neighbour mines = m,
	                -- m ~ Poisson-binomial of the neighbours' marginals.
	                local nbrs = coveredNbrs(k)
	                local dist, deg = { [0] = 1 }, 0
	                for _, nk in ipairs(nbrs) do
	                    local q
	                    if mine[nk] then q = 1
	                    elseif safe[nk] then q = 0
	                    else q = prob[nk] or prob[0] or 0.5 end
	                    local nd = {}
	                    for m = 0, deg do
	                        local dm = dist[m] or 0
	                        nd[m]   = (nd[m]   or 0) + dm * (1 - q)
	                        nd[m+1] = (nd[m+1] or 0) + dm * q
	                    end
	                    dist, deg = nd, deg + 1
	                end
	                local uSafe = 0
	                for m = 0, #nbrs do
	                    local pm = dist[m] or 0
	                    if pm > 1e-9 then
	                        local extra = { { cells = {k}, n = 0 } }
	                        if #nbrs > 0 then extra[#extra+1] = { cells = nbrs, n = m } end
	                        uSafe = uSafe + pm * countForced(extra, k)
	                    end
	                end
	                local score = p * uMine + (1 - p) * uSafe
	                local ent = -(p * math.log(p) + (1 - p) * math.log(1 - p))   -- tiebreak: more uncertain wins
	                if score > bestScore + 1e-9 or (math.abs(score - bestScore) <= 1e-9 and ent > bestEnt) then
	                    best, bestScore, bestEnt = k, score, ent
	                end
	            end
	            if best then
	                local r = math.floor(best / 100)
	                hintTarget = { r, best - r * 100 }
	            end
	        end
	    end

	    return toReveal, toFlag, prob, covered, mine, key, hintTarget
	end

	-- ---- minigame open/closed detection (cheap -- vent-style idle) -------------
	-- While the minigame is closed we do ZERO board scanning/solving: just a single
	-- FindFirstChild on the known name. Only once it's open do we engage.
	local function minigameOpen()
	    local mg = PlayerGui:FindFirstChild("HackingMinigame")
	    if not mg then return nil end
	    if mg:IsA("ScreenGui") or mg:IsA("LayerCollector") then
	        if not mg.Enabled then return nil end
	    elseif mg:IsA("GuiObject") then
	        if not mg.Visible then return nil end
	    end
	    return mg
	end

	-- Wait until the board changes (our last action took effect / a cascade settled)
	-- or we time out / the minigame closes. This is what makes play event-driven
	-- instead of re-solving 20x/second.
	local function waitForChange(board, oldSig, timeout)
	    local t0 = os.clock()
	    while os.clock() - t0 < timeout do
	        task.wait()
	        if not minigameOpen() then return false end
	        local g, R, C = readBoard(board)
	        if g and signature(g, R, C) ~= oldSig then return true end
	    end
	    return false
	end

	-- deduce + act on CERTAIN moves only. returns a status plus the solve results so
	-- the caller can decide whether to gamble:
	--   "over"    a mine is showing, or every safe cell is already revealed
	--   "acted"   placed flags and/or revealed at least one PROVEN-safe cell
	--   "stuck"   no certain move -> caller may guess/hint (results returned)
	--   "idle"    board not readable right now
	local function deduceAndAct(board)
	    local grid, R, C = readStable(board)
	    if not grid then return "idle" end
	    CURRENT_MINES = detectMines(board, grid, R, C)

	    for r=1,R do for c=1,C do if grid[r][c].state == "MINE" then
	        msLog("a mine is revealed -> stopping (lost or finished).")
	        return "over"
	    end end end

	    local toReveal, toFlag, prob, covered, mine, key, hintTarget = solve(grid, R, C)

	    if state.msFlags then
	        for _, rc in ipairs(toFlag) do
	            local g = grid[rc[1]][rc[2]]
	            if g.state == "COVERED" then flagCell(g.cell) end
	        end
	    end

	    if #toReveal > 0 then
	        for _, rc in ipairs(toReveal) do
	            revealCell(grid[rc[1]][rc[2]].cell)
	        end
	        return "acted"
	    end

	    local unknownLeft = 0
	    for _, rc in ipairs(covered) do if not mine[key(rc[1],rc[2])] then unknownLeft = unknownLeft+1 end end
	    if unknownLeft == 0 then
	        msLog("solved -- all safe cells revealed.")
	        return "over"
	    end

	    return "stuck", grid, R, C, prob, covered, mine, key, hintTarget
	end

	-- ---- one play cycle: read -> solve -> act. returns "acted"/"idle"/"over". --
	local function playCycle(board)
	    CURRENT_LEVEL = detectLevel(board)

	    local status, grid, R, C, prob, covered, mine, key, hintTarget = deduceAndAct(board)
	    if status ~= "stuck" then return status end

	    -- STUCK. Needless 50/50s come from gambling on a board that hadn't finished
	    -- updating, so NEVER guess on the first stuck read. Give it extra settle time
	    -- and deduce again -- a cascade from the previous move often exposes proven-
	    -- safe cells we'd otherwise have gambled on. Only guess if STILL stuck.
	    -- Slow levels (5-6) settle; levels 1-4 confirm instantly and stay fast.
	    task.wait(isSlowLevel() and STUCK_CONFIRM_S or STUCK_CONFIRM_F)
	    local status2, grid2, R2, C2, prob2, covered2, mine2, key2, hintTarget2 = deduceAndAct(board)
	    if status2 ~= "stuck" then return status2 end        -- found a sure move / over
	    grid, R, C, prob, covered, mine, key = grid2, R2, C2, prob2, covered2, mine2, key2
	    hintTarget = hintTarget2

	    local anyRevealed = false
	    for r=1,R do for c=1,C do local s=grid[r][c].state; if s=="NUM" or s=="BLANK" then anyRevealed=true end end end

	    -- returns the safest covered cell AND its mine probability.
	    local function lowestProbCell()
	        local minesLeft = CURRENT_MINES
	        local flagged = 0
	        for r=1,R do for c=1,C do if grid[r][c].state=="FLAG" then flagged=flagged+1 end end end
	        -- prefer the exact WMC sea probability (prob[0]) over the flat base-rate guess
	        local defP = prob[0] or (minesLeft and math.max(0,(minesLeft-flagged))/math.max(1,#covered) or 0.5)
	        local best, bp = nil, 2
	        for _, rc in ipairs(covered) do
	            if not mine[key(rc[1],rc[2])] then
	                local p = prob[key(rc[1],rc[2])] or defP
	                if p < bp then bp, best = p, rc end
	            end
	        end
	        return best, bp
	    end
	    -- fallback hint target (fast levels / no WMC target): the frontier cell most
	    -- likely to be a mine. The slow-level path prefers solve()'s expected-unlock
	    -- `hintTarget` instead, which is far better at breaking the deadlock.
	    local function bestHintCell()
	        local best, bp = nil, -1
	        for _, rc in ipairs(covered) do
	            local p = prob[key(rc[1],rc[2])]
	            if p and not mine[key(rc[1],rc[2])] and p > bp then bp, best = p, rc end
	        end
	        return best or (lowestProbCell())
	    end
	    -- the opening: centre opens the most area on a fresh board.
	    local function openingCell()
	        local r = (FIRST_MOVE=="corner") and 1 or math.ceil(R/2)
	        local c = (FIRST_MOVE=="corner") and 1 or math.ceil(C/2)
	        return {r, c}
	    end

	    local canHint = state.msHints and hintsLeft(board) > 0
	    -- Always prefer a hint when one is available (incl. the opening), so we never
	    -- take an avoidable gamble. Only guess once hints are gone.
	    if canHint then
	        -- slow levels: spend the hint on the expected-unlock target from solve();
	        -- otherwise fall back to the highest-mine-prob cell (or the opening).
	        local t
	        if anyRevealed then t = hintTarget or bestHintCell() else t = openingCell() end
	        if t then
	            msLog(("stuck -> hint probe (%d,%d), %d left [mines=%s]"):format(
	                t[1], t[2], hintsLeft(board), tostring(CURRENT_MINES)))
	            useHintOn(board, grid[t[1]][t[2]].cell)
	        end
	    else
	        local pick, pickP
	        if anyRevealed then pick, pickP = lowestProbCell() else pick = openingCell() end
	        if pick then
	            msLog(("no hints -> guess (%d,%d) p=%.2f [mines=%s]"):format(
	                pick[1], pick[2], pickP or -1, tostring(CURRENT_MINES)))
	            revealCell(grid[pick[1]][pick[2]].cell)
	        end
	    end
	    return "acted"
	end

	-- ---- direct mine-layout reader (pure read, no network) --------------------
	-- The board is generated CLIENT-SIDE: each cell's reveal handler closes over a
	-- state table { HasMine, X, Y, UI=<frame>, ... }. We read it straight out of the
	-- handler's upvalues -- so we know every mine before touching anything. Sends
	-- nothing to the server; this is all reads. Falls back to the solver if the
	-- closure shape ever changes (returns nil).
	local hasGetUpvalues = typeof(debug) == "table" and typeof(debug.getupvalues) == "function"

	local function getCellState(btn)
	    local ok, conns = pcall(getconnections, btn.MouseButton1Up)
	    if not ok or not conns then return nil end
	    for _, c in ipairs(conns) do
	        local f
	        pcall(function() f = c.Function end)
	        if typeof(f) == "function" and hasGetUpvalues then
	            local ok2, ups = pcall(debug.getupvalues, f)
	            if ok2 and ups then
	                for _, u in ipairs(ups) do
	                    if typeof(u) == "table" and u.HasMine ~= nil and u.X ~= nil and u.Y ~= nil then
	                        return u
	                    end
	                end
	            end
	        end
	    end
	    return nil
	end

	-- read the live layout. returns { cells = {state,...}, mines = n } or nil.
	local function readMineLayout()
	    if not state.msReader or not hasGetUpvalues then return nil end
	    local mg = minigameOpen(); if not mg then return nil end
	    local canvas = mg:FindFirstChild("Canvas") or mg
	    local cells, mines = {}, 0
	    for _, d in ipairs(canvas:GetDescendants()) do
	        if d:FindFirstChild("Mine") and d:FindFirstChild("Hidden") and d:FindFirstChild("Button") then
	            local st = getCellState(d.Button)
	            if st then
	                if st.UI == nil then st.UI = d end   -- ensure a frame back-reference
	                cells[#cells+1] = st
	                if st.HasMine then mines = mines + 1 end
	            end
	        end
	    end
	    if #cells == 0 then return nil end
	    -- Seit dem Patch erzeugt der SERVER die Minen bei echten Türen (Client: placeMine nur im Übungsmodus,
	    -- Aufdecken per HackReveal:InvokeServer). Dann steht überall HasMine=false -> kein Vorwissen -> Solver.
	    if mines == 0 then return nil end
	    return { cells = cells, mines = mines }
	end

	local function cellCovered(st)
	    local h = st.UI and st.UI:FindFirstChild("Hidden")
	    return h and h.Visible == true
	end

	local function revealState(st)
	    local cell = st.UI; if not cell then return end
	    local btn = cell:FindFirstChild("Button")
	    if not btn and cell:IsA("GuiButton") then btn = cell end
	    if not btn then return end
	    local x, y = centreOf(cell)
	    fire(btn.MouseButton1Down, x, y)
	    fire(btn.MouseButton1Up, x, y)
	end

	-- play the board out from the known layout, pacing reveals so it spans SOLVE_TIME
	-- for the current level (so a 200/400-mine board never resolves instantly).
	-- returns "over" (done), or "fail" (couldn't read -> caller falls back to solver).
	local function cheatSolve(board)
	    local layout = readMineLayout()
	    if not layout then return "fail" end

	    local lvl = detectLevel(board)
	    local T = (lvl and SOLVE_TIME[lvl]) or state.msPace

	    local safe = {}
	    for _, st in ipairs(layout.cells) do
	        if not st.HasMine then safe[#safe+1] = st end
	    end
	    if #safe == 0 then return "fail" end

	    if CHEAT_SHUFFLE then
	        for i = #safe, 2, -1 do local j = math.random(i); safe[i], safe[j] = safe[j], safe[i] end
	    end

	    local interval = (#safe > 0) and (T / #safe) or 0
	    msLog(("reader: lvl %s, %d mines, revealing %d safe cells over %.0fs")
	        :format(tostring(lvl), layout.mines, #safe, T))

	    for _, st in ipairs(safe) do
	        if not minigameOpen() or not state.ms then return "over" end   -- closed/ended/disabled mid-solve
	        if cellCovered(st) then revealState(st) end     -- skip ones a cascade already opened
	        if interval > 0 then task.wait(interval) end
	    end
	    msLog("reader: board cleared.")
	    return "over"
	end

	-- ---- main loop -------------------------------------------------------------

	-- guards, both cleared when the minigame closes so the NEXT one restarts fresh:
	--   doneSig          (solver fallback) signature of a board we already finished
	--   cheatedThisOpen  (reader path) we already played this open instance to completion
	local doneSig = nil
	local cheatedThisOpen = false   -- false oder eine Zelle des geloesten Boards
	local doneMarker = nil          -- Zelle des Boards, zu dem doneSig gehoert
	-- irgendeine Zelle des Boards: clearBoard() zerstoert alle Zellen, ein neues Board hat neue Instanzen
	local function boardMarker(board)
	    for _, ch in ipairs(board:GetChildren()) do
	        if ch:FindFirstChild("Hidden") and ch:FindFirstChild("Button") then return ch end
	    end
	end

	-- the solver fallback for one engagement (used only if the reader can't read).
	local function solverCycle(board)
	    local g0, R0, C0 = readBoard(board)
	    local before = g0 and signature(g0, R0, C0) or ""
	    if doneSig and (not doneMarker or doneMarker.Parent ~= board) then doneSig = nil end -- Zellen ersetzt -> neues Board
	    if before == doneSig then task.wait(0.4); return end
	    local marker = boardMarker(board)
	    local result = playCycle(board)
	    if result == "over" then
	        doneSig, doneMarker = before, marker
	        task.wait(0.4)
	    elseif result == "acted" then
	        waitForChange(board, before, 1.0)   -- event-driven: wait for it to land
	    else
	        task.wait(CYCLE_WAIT)               -- "idle": board mid-read, retry shortly
	    end
	end

	-- eine Runde der Hauptschleife; läuft in pcall, damit ein einzelner Fehler (z. B. nach einem Hinweis) den Bot
	-- nicht dauerhaft tötet (vorher: Thread tot, Status hing auf "hint probe fired", erst Hub-Neuladen half)
	local function tick()
	        local mg = state.ms and minigameOpen()
	        if not mg then
	            -- IDLE: minigame closed. No board scan -- just back off and reset guards.
	            doneSig, cheatedThisOpen = nil, false
	            task.wait(0.4)
	        else
	            local board = findBoard(mg)
	            if not board then
	                doneSig, cheatedThisOpen = nil, false   -- between games -> reset
	                task.wait(0.2)
	            elseif state.msReader then
	                if cheatedThisOpen and cheatedThisOpen.Parent ~= board then
	                    cheatedThisOpen = false              -- Zellen ersetzt -> neues Board, auch ohne Schliessen
	                end
	                if cheatedThisOpen then
	                    task.wait(0.4)                       -- solved; wait for it to close
	                else
	                    local marker = boardMarker(board)
	                    local res = cheatSolve(board)
	                    if res == "over" then
	                        cheatedThisOpen = marker or false -- done until this board closes / is replaced
	                        task.wait(0.4)
	                    else                                 -- "fail": read unavailable -> solve it
	                        solverCycle(board)
	                    end
	                end
	            else
	                solverCycle(board)
	            end
	        end
	end
	task.spawn(function()
	    while H.alive do
	        local ok, err = pcall(tick)
	        if not ok then
	            msLog("error, retrying: " .. tostring(err):sub(1, 120))
	            doneSig = nil
	            task.wait(0.5)
	        end
	    end
	end)
end
task.spawn(msBot)

-- ================= PAKETE / DEAD DROPS (Wegpunkt) =================
-- Quests: RS.Values.Quests.DeadDrops.<NPC>.<Ort> (Payout/Risk/Distance/CurrentPlayer); angenommen = lp.CurrentQuest.
-- Ziel-Part workspace.DeadDropLocations[<Ort>] streamt erst in der Nähe -> bis dahin Näherung (Region/Kamera),
-- danach exakte Position, dauerhaft gelernt in tsc_deaddrops.json. Anzeige rein 2D (keine Welt-Instanzen).
local DD_FILE = "tsc_deaddrops.json"
local ddLearned = {}
pcall(function() if isfile(DD_FILE) then ddLearned = HttpService:JSONDecode(readfile(DD_FILE)) end end)
if type(ddLearned) ~= "table" then ddLearned = {} end
-- Näherungen: Region-Boxen/Security-Kameras, gegen Quest-"Distance" plausibilisiert
local DD_HINTS = {
	["Centrifuge Control Room"] = { 1072, -158, 624 },
	["SteeleTown"] = { -259, 54, 93 },
	["AD Offices"] = { -600, 71, 410 },
	["CISCZ Kitchen"] = { 559, -141, 1247 },
	["U&M Spawn"] = { -340, 50, 105 },
	["S2 Commons Vent"] = { 1059, 26, -122 },
	["MD Spawn"] = { -86, 36, 273 },
	["Security Storage Entrance"] = { 989, 12, -62 },
	["Tram Platform A"] = { 284, 20, 57 },
	["S2 Staff Break Room"] = { 983, 10, -25 },
	["Classroom Wing"] = { 889, 62, -341 },
	["TSCZ Cargo Elevator"] = { 1494, 40, -513 },
	["TSCZ Cargo Dropoff"] = { 913, 80, -563 },
	["S1 Bridge"] = { -715, 87, 47 },
	["Solitary Confinement"] = { 1557.8, 70.5, -394 },
	["TSCZ Viewing Area"] = { 1556.4, 87.3, -246.6 },
	["Parkour Chute"] = { 1693.9, 204.1, -144 },
	["Liam's Hideout"] = { 1033.3, 23.6, -32.8 },
}
local function ddSave() pcall(writefile, DD_FILE, HttpService:JSONEncode(ddLearned)) end
local function ddLearn(part)
	if not part:IsA("BasePart") then return end
	local p = part.Position
	local old = ddLearned[part.Name]
	if not old or math.abs(old[1] - p.X) + math.abs(old[2] - p.Y) + math.abs(old[3] - p.Z) > 1 then
		ddLearned[part.Name] = { p.X, p.Y, p.Z }; ddSave()
	end
end
local ddFolder = workspace:FindFirstChild("DeadDropLocations")
if ddFolder then
	for _, c in ipairs(ddFolder:GetChildren()) do ddLearn(c) end
	con(ddFolder.ChildAdded, function(c) task.defer(ddLearn, c) end)
end
local function ddTarget(name)
	local live = ddFolder and ddFolder:FindFirstChild(name)
	if live and live:IsA("BasePart") then return live.Position, "exakt" end
	local l = ddLearned[name]; if l then return Vector3.new(l[1], l[2], l[3]), "gelernt" end
	local h = DD_HINTS[name]; if h then return Vector3.new(h[1], h[2], h[3]), "ca." end
	return nil, "unbekannt"
end
local function ddQuests()
	local out = {}
	local RSq = game:GetService("ReplicatedStorage")
	local root = RSq:FindFirstChild("Values")
	-- Fake-TSC: Quests direkt unter ReplicatedStorage statt unter Values
	root = (root and root:FindFirstChild("Quests")) or RSq:FindFirstChild("Quests"); root = root and root:FindFirstChild("DeadDrops")
	if not root then return out end
	for _, npc in ipairs(root:GetChildren()) do
		for _, q in ipairs(npc:GetChildren()) do
			local function v(n) local o = q:FindFirstChild(n) return o and o.Value end
			out[#out + 1] = { obj = q, name = q.Name, npc = npc.Name, pay = v("Payout") or 0, risk = v("Risk") or 0, who = v("CurrentPlayer") }
		end
	end
	table.sort(out, function(a, b) return a.pay > b.pay end)
	return out
end

state.pkgSel = sv("pkgSel", nil)
local pkgInfo = info(S_pkg, "No package selected", T.accent)
-- Ziel-Auswahl als Dropdown (Liste wird beim Aufklappen frisch gebaut)
local lastPkgSig = ""
local pkgCur
do
	txt(S_pkg.f, "Target", UDim2.new(1, 0, 0, 14)).LayoutOrder = nextOrder(S_pkg)
	local box = Instance.new("TextButton")
	box.Size = UDim2.new(1, 0, 0, 18); box.BackgroundColor3 = T.track; box.BorderSizePixel = 0; box.AutoButtonColor = false
	box.Text = ""; box.LayoutOrder = nextOrder(S_pkg); box.Parent = S_pkg.f
	stroke(box); corner(box, 2)
	pkgCur = txt(box, state.pkgSel or "none", UDim2.new(1, -24, 1, 0)); pkgCur.Position = UDim2.fromOffset(6, 0)
	pkgCur.TextTruncate = Enum.TextTruncate.AtEnd
	local arr = txt(box, "▼", UDim2.new(0, 14, 1, 0), T.text); arr.Position = UDim2.new(1, -16, 0, 0); arr.TextSize = 10
	local list = Instance.new("Frame")
	list.Size = UDim2.new(1, 0, 0, 0); list.AutomaticSize = Enum.AutomaticSize.Y; list.BackgroundColor3 = T.bg
	list.BorderSizePixel = 0; list.Visible = false; list.LayoutOrder = nextOrder(S_pkg); list.Parent = S_pkg.f
	stroke(list)
	Instance.new("UIListLayout", list).SortOrder = Enum.SortOrder.LayoutOrder
	local function close() list.Visible = false; arr.Text = "▼" end
	local function fill()
		for _, c in ipairs(list:GetChildren()) do if c:IsA("TextButton") then c:Destroy() end end
		local cq = lp:FindFirstChild("CurrentQuest")
		local mineObj = cq and cq.Value
		local opts = { { label = "none" } }
		for _, q in ipairs(ddQuests()) do
			local _, kind = ddTarget(q.name)
			local npcShort = q.npc:gsub("'s Dead Drops", "")
			opts[#opts + 1] = { name = q.name, own = mineObj == q.obj, label = ("%s$%d %s [%s] r%d%s%s"):format(mineObj == q.obj and "> " or "",
				q.pay, q.name, npcShort, q.risk, q.who and (" - " .. (q.who == lp and "you" or q.who.Name)) or "", kind == "ca." and " ~" or "") }
		end
		for i, o in ipairs(opts) do
			local b = Instance.new("TextButton")
			b.Size = UDim2.new(1, 0, 0, 17); b.BackgroundTransparency = 1; b.Font = T.font; b.TextSize = 12
			b.Text = "  " .. o.label; b.TextXAlignment = Enum.TextXAlignment.Left; b.TextTruncate = Enum.TextTruncate.AtEnd
			b.TextColor3 = o.own and Color3.fromRGB(120, 255, 140) or ((o.name == state.pkgSel) and T.accent or T.dim)
			b.LayoutOrder = i; b.Parent = list
			b.MouseButton1Click:Connect(function() state.pkgSel = o.name; close() end)
		end
	end
	con(box.MouseButton1Click, function()
		if list.Visible then close() else fill(); list.Visible = true; arr.Text = "▲" end
	end)
end
button(S_pkg, "Clear Waypoint", function() state.pkgSel = nil end)

-- Bubble-TPs (Paket-Ziel, Liam's Hideout, Shops): erst TP-Blase dorthin (Kamera auf der Blase, umsehen ob die Luft
-- rein ist), Enter = TP, Backspace = abbrechen. Return = zurück zur Stelle vor dem ersten TP (gemeinsam für alle).
;(function()
	local returnCF
	local function tp(cf)
		local h = rootOf(lp)
		if not h then return false end
		pcall(function() lp:RequestStreamAroundAsync(cf.Position, 2) end)
		h.AssemblyLinearVelocity = Vector3.zero
		h.CFrame = cf
		return true
	end
	local function bubbleTo(pos)
		if not (pos and H.tpPlaceBubble) then return end
		H.tpPlaceBubble(pos, function()
			local h = rootOf(lp)
			if h and not returnCF then returnCF = h.CFrame end -- erster Sprung merkt die Ausgangsstelle
		end)
	end
	local function returnBtn(S)
		button(S, "Return (back to where you were)", function()
			if not returnCF then return end
			local cf = returnCF
			task.spawn(function() if tp(cf) then returnCF = nil end end)
		end)
	end

	-- Paket: gewähltes / angenommenes Dead-Drop-Ziel
	button(S_pkg, "Bubble to Package (Enter = TP)", function()
		local pos = state.pkgSel and ddTarget(state.pkgSel)
		if pos then bubbleTo(pos + Vector3.new(0, 3, 0)) end
	end)
	button(S_pkg, "Bubble to Liam's Hideout (Enter = TP)", function()
		local pos = ddTarget("Liam's Hideout")
		if pos then bubbleTo(pos + Vector3.new(0, 3, 0)) end
	end)
	returnBtn(S_pkg)

	-- Shops: workspace.Markets. Manche Shops (z. B. Liam's Hideout) existieren nur, solange die Gegend reingestreamt ist
	-- -> jeder gesehene Shop wird mit Pivot in tsc_shops.json gemerkt; Liste wird beim Aufklappen frisch gebaut.
	local S_shop = section(miscR, "Shop TP")
	local SHOP_FILE = "tsc_shops.json"
	local SHOP_HINTS = { ["Liam's Hideout"] = { 1045, 25, -26, 0, 0, -1 } } -- x,y,z + Blickrichtung
	local learned = {}
	pcall(function() if isfile(SHOP_FILE) then learned = HttpService:JSONDecode(readfile(SHOP_FILE)) end end)
	if type(learned) ~= "table" then learned = {} end
	local markets = workspace:FindFirstChild("Markets")
	local function liveShops()
		local out, seen = {}, {}
		for _, m in ipairs(markets and markets:GetChildren() or {}) do
			if m:IsA("Model") and m.Name ~= "VendingMachines" then
				seen[m.Name] = (seen[m.Name] or 0) + 1
				out[m.Name .. (seen[m.Name] > 1 and (" #" .. seen[m.Name]) or "")] = m
			end
		end
		return out
	end
	local function learn()
		local changed = false
		for name, m in pairs(liveShops()) do
			local pv = m:GetPivot()
			local p, l = pv.Position, pv.LookVector
			local old = learned[name]
			if not old or (Vector3.new(old[1], old[2], old[3]) - p).Magnitude > 1 then
				learned[name] = { p.X, p.Y, p.Z, l.X, l.Y, l.Z }; changed = true
			end
		end
		if changed then pcall(writefile, SHOP_FILE, HttpService:JSONEncode(learned)) end
	end
	pcall(learn)
	if markets then con(markets.ChildAdded, function() task.delay(1, function() pcall(learn) end) end) end

	local VEND = "Vending Machine (nearest)"
	state.shopSel = state.shopSel or VEND
	local function shopNames()
		local set = {}
		for n in pairs(SHOP_HINTS) do set[n] = true end
		for n in pairs(learned) do set[n] = true end
		for n in pairs(liveShops()) do set[n] = true end
		local list = {}
		for n in pairs(set) do list[#list + 1] = n end
		table.sort(list)
		table.insert(list, 1, VEND)
		return list
	end
	-- Dropdown (wie beim Paket-Ziel: Liste beim Aufklappen neu)
	do
		txt(S_shop.f, "Shop", UDim2.new(1, 0, 0, 14)).LayoutOrder = nextOrder(S_shop)
		local box = Instance.new("TextButton")
		box.Size = UDim2.new(1, 0, 0, 28); box.BackgroundColor3 = T.panel2; box.BorderSizePixel = 0; box.AutoButtonColor = false
		box.Text = ""; box.LayoutOrder = nextOrder(S_shop); box.Parent = S_shop.f
		stroke(box); corner(box, 6)
		local cur = txt(box, state.shopSel, UDim2.new(1, -34, 1, 0)); cur.Position = UDim2.fromOffset(10, 0)
		cur.TextTruncate = Enum.TextTruncate.AtEnd
		local arr = txt(box, "▼", UDim2.new(0, 14, 1, 0), T.dim); arr.Position = UDim2.new(1, -22, 0, 0); arr.TextSize = 10
		local list = Instance.new("Frame")
		list.Size = UDim2.new(1, 0, 0, 0); list.AutomaticSize = Enum.AutomaticSize.Y; list.BackgroundColor3 = T.bg
		list.BorderSizePixel = 0; list.Visible = false; list.LayoutOrder = nextOrder(S_shop); list.Parent = S_shop.f
		stroke(list); corner(list, 6)
		Instance.new("UIListLayout", list).SortOrder = Enum.SortOrder.LayoutOrder
		local function close() list.Visible = false; arr.Text = "▼" end
		local function fill()
			for _, c in ipairs(list:GetChildren()) do if c:IsA("TextButton") then c:Destroy() end end
			for i, n in ipairs(shopNames()) do
				local b = Instance.new("TextButton")
				b.Size = UDim2.new(1, 0, 0, 22); b.BackgroundTransparency = 1; b.Font = T.font; b.TextSize = 12
				b.Text = "   " .. n; b.TextXAlignment = Enum.TextXAlignment.Left; b.TextTruncate = Enum.TextTruncate.AtEnd
				b.TextColor3 = (n == state.shopSel) and T.accent or T.dim
				b.LayoutOrder = i; b.Parent = list
				b.MouseButton1Click:Connect(function() state.shopSel = n; cur.Text = n; close() end)
			end
		end
		con(box.MouseButton1Click, function()
			if list.Visible then close() else fill(); list.Visible = true; arr.Text = "▲" end
		end)
	end

	local function shopPos(name)
		local pv
		if name == VEND then
			local vf = markets and markets:FindFirstChild("VendingMachines")
			local my = rootOf(lp)
			local bd
			for _, v in ipairs(vf and vf:GetChildren() or {}) do
				if v:IsA("Model") then
					local p = v:GetPivot()
					local d = my and (p.Position - my.Position).Magnitude or 0
					if not bd or d < bd then pv, bd = p, d end
				end
			end
		else
			local m = liveShops()[name]
			if m then pv = m:GetPivot() else
				local e = learned[name] or SHOP_HINTS[name]
				if e then pv = CFrame.lookAt(Vector3.new(e[1], e[2], e[3]), Vector3.new(e[1] + e[4], e[2] + e[5], e[3] + e[6])) end
			end
		end
		if not pv then return end
		-- 4 Studs vor das Modell (Pivot-Blickrichtung), Blase lässt sich noch mit Pfeiltasten nachjustieren
		local fwd = Vector3.new(pv.LookVector.X, 0, pv.LookVector.Z)
		fwd = fwd.Magnitude > 0.1 and fwd.Unit or Vector3.zero
		return pv.Position + fwd * 4 + Vector3.new(0, 1, 0)
	end
	button(S_shop, "Bubble to Shop (Enter = TP)", function() bubbleTo(shopPos(state.shopSel)) end)
	returnBtn(S_shop)
	info(S_shop, "Bubble first: the camera shows the spot, arrows adjust, Enter teleports, Backspace cancels. Return is shared with the package TPs.")

	-- Spieler: Blase 3 Studs hinter das Target (Players-Tab); die Blase läuft mit dem Spieler mit (Verschiebung pro
	-- Frame übernommen, eigene Pfeiltasten-Korrektur bleibt erhalten), Enter = TP dorthin wo er gerade ist.
	local S_ptp = section(plL, "Player TP")
	local ptpInfo = info(S_ptp, "Pick a player under Target first.", T.dim)
	local follow -- { bubble, player, last }
	button(S_ptp, "Bubble to Target (Enter = TP)", function()
		local p = markedPlayer()
		local r = p and rootOf(p)
		if not r then ptpInfo.Text = p and (p.Name .. " is not loaded (too far / dead)") or "Pick a player under Target first."; return end
		local back = Vector3.new(r.CFrame.LookVector.X, 0, r.CFrame.LookVector.Z)
		back = back.Magnitude > 0.1 and -back.Unit * 3 or Vector3.zero
		bubbleTo(r.Position + back)
		follow = { bubble = H.tpBubble, player = p, last = r.Position }
		ptpInfo.Text = "Bubble follows " .. p.Name
	end)
	returnBtn(S_ptp)
	con(RunService.RenderStepped, function()
		if not follow then return end
		if not follow.bubble or H.tpBubble ~= follow.bubble then follow = nil; ptpInfo.Text = "Pick a player under Target, then bubble."; return end
		local r = rootOf(follow.player)
		if not r then return end
		follow.bubble.Position = follow.bubble.Position + (r.Position - follow.last)
		follow.last = r.Position
	end)
end)()
info(S_pkg, "~ = approx. (region/camera); exact once the drop point streams in (saved to workspace/" .. DD_FILE .. ")")

local function rebuildPkg()
	local sel = state.pkgSel or "none"
	if pkgCur.Text ~= sel then pkgCur.Text = sel end
end

-- Wegpunkt-Overlay (2D-Projektion)
local wpLbl = Instance.new("TextLabel")
wpLbl.AnchorPoint = Vector2.new(0.5, 1); wpLbl.Size = UDim2.fromOffset(220, 36); wpLbl.BackgroundTransparency = 1
wpLbl.Font = Enum.Font.GothamBold; wpLbl.TextSize = 14; wpLbl.TextStrokeTransparency = 0.2; wpLbl.Visible = false; wpLbl.Parent = gui
local wpDot = Instance.new("Frame")
wpDot.AnchorPoint = Vector2.new(0.5, 0.5); wpDot.Size = UDim2.fromOffset(12, 12); wpDot.BorderSizePixel = 0
wpDot.Rotation = 45; wpDot.Visible = false; wpDot.Parent = gui
local wpArrow = Instance.new("TextLabel")
wpArrow.AnchorPoint = Vector2.new(0.5, 0.5); wpArrow.Size = UDim2.fromOffset(200, 36); wpArrow.BackgroundTransparency = 1
wpArrow.Font = Enum.Font.GothamBold; wpArrow.TextSize = 14; wpArrow.TextStrokeTransparency = 0.2; wpArrow.Visible = false; wpArrow.Parent = gui

local autoSel = nil
con(RunService.RenderStepped, function()
	-- angenommene Quest automatisch wählen
	local cq = lp:FindFirstChild("CurrentQuest")
	local mine = cq and cq.Value and cq.Value.Name
	if mine and autoSel ~= mine then autoSel = mine; state.pkgSel = mine; lastPkgSig = "" end
	if not mine and autoSel then if state.pkgSel == autoSel then state.pkgSel = nil end autoSel = nil; lastPkgSig = "" end

	local name = state.pkgSel
	local pos, kind
	if name then pos, kind = ddTarget(name) end
	if not pos then
		wpLbl.Visible = false; wpDot.Visible = false; wpArrow.Visible = false
		pkgInfo.Text = name and ("Target: " .. name .. " (position unknown)") or "No package selected"
		return
	end
	local myRoot = rootOf(lp)
	local d = myRoot and math.floor((pos - myRoot.Position).Magnitude) or 0
	local dy = myRoot and math.floor(pos.Y - myRoot.Position.Y) or 0
	local col = (kind == "ca.") and Color3.fromRGB(255, 170, 60) or Color3.fromRGB(90, 255, 120)
	local txt = ("📦 %s\n%s%dm  (%s%d Höhe)"):format(name, kind == "ca." and "ca. " or "", d, dy >= 0 and "+" or "", dy)
	pkgInfo.Text = ("Target: %s  %dm  [%s]"):format(name, d, kind)
	local vp = cam.ViewportSize
	local sp, on = cam:WorldToViewportPoint(pos)
	if on and sp.Z > 0 then
		wpArrow.Visible = false
		wpDot.Position = UDim2.fromOffset(sp.X, sp.Y); wpDot.BackgroundColor3 = col; wpDot.Visible = true
		wpLbl.Position = UDim2.fromOffset(sp.X, sp.Y - 8); wpLbl.TextColor3 = col; wpLbl.Text = txt; wpLbl.Visible = true
	else
		wpLbl.Visible = false; wpDot.Visible = false
		local center = vp / 2
		local dir = Vector2.new(sp.X, sp.Y) - center
		if sp.Z < 0 then dir = -dir end
		if dir.Magnitude < 1 then dir = Vector2.new(0, -1) end
		dir = dir.Unit
		local m = 70
		local sx = (center.X - m) / math.max(math.abs(dir.X), 1e-3)
		local sy = (center.Y - m) / math.max(math.abs(dir.Y), 1e-3)
		local p2 = center + dir * math.min(sx, sy)
		wpArrow.Position = UDim2.fromOffset(p2.X, p2.Y); wpArrow.TextColor3 = col
		wpArrow.Text = "📦 " .. name .. "\n" .. d .. "m"; wpArrow.Visible = true
	end
end)
task.spawn(function() while H.alive do pcall(rebuildPkg) task.wait(1) end end)

-- ================= EINKLAPPEN =================
state.collapsed = sv("collapsed", false)
local FULL_H = main.Size.Y.Offset
local colBtn = Instance.new("TextButton")
colBtn.Size = UDim2.fromOffset(22, 22); colBtn.AnchorPoint = Vector2.new(1, 0); colBtn.Position = UDim2.new(1, -8, 0, 4)
colBtn.BackgroundTransparency = 1; colBtn.Font = T.font; colBtn.TextSize = 16; colBtn.TextColor3 = T.dim; colBtn.ZIndex = 3; colBtn.Parent = main
local function applyCollapse()
	tabBar.Visible = not state.collapsed; content.Visible = not state.collapsed
	main.Size = UDim2.fromOffset(main.Size.X.Offset, state.collapsed and 30 or FULL_H)
	colBtn.Text = state.collapsed and "+" or "–"
end
applyCollapse()
con(colBtn.MouseButton1Click, function() state.collapsed = not state.collapsed; applyCollapse() end)
con(colBtn.MouseEnter, function() colBtn.TextColor3 = T.accent end)
con(colBtn.MouseLeave, function() colBtn.TextColor3 = T.dim end)

-- ================= ALARM-ZONEN =================
-- Alarme = unsichtbare Touch-Boxen "TeamDetect" (Server-Script TeamDetector + Alarm-Sound) in LaserGates,
-- TeslaGates, TeamSensors (Motion Sensor), MaxiBurgerSystems, *Detect. Box statt Radius -> exakte Box zeichnen.
-- StreamingEnabled: Zonen existieren nur in der Nähe -> jede gesehene Zone wird gelernt (tsc_alarms.json)
-- und an Weltkoordinaten gezeichnet (Adornee = Terrain), also auch wenn sie gerade rausgestreamt ist.
local S_alarm = section(visL, "Alarm Zones")
state.alarms = sv("alarms", false)
state.alarmDist = sv("alarmDist", 600)
local ALARM_FILE = "tsc_alarms.json"
local ALARM_COL = {
	LaserGates = Color3.fromRGB(255, 150, 40), TeslaGates = Color3.fromRGB(170, 90, 255),
	TeamSensors = Color3.fromRGB(255, 60, 60), MaxiBurgerSystems = Color3.fromRGB(255, 220, 60),
}
local alarmDB = {} -- [key] = {cf={12 Zahlen}, size={x,y,z}, name=, kind=}
pcall(function() if isfile(ALARM_FILE) then alarmDB = HttpService:JSONDecode(readfile(ALARM_FILE)) end end)
if type(alarmDB) ~= "table" then alarmDB = {} end
local alarmDirty = false
local function alarmKind(part) return part:GetFullName():match("^Workspace%.([^%.]+)") or "?" end
local function alarmName(part, kind)
	local m = part.Parent
	local mn = m and m:FindFirstChild("MotionName")
	if mn and mn.Value ~= "" then return mn.Value end
	if kind == "TeamSensors" then return "Motion Sensor" end
	if kind == "LaserGates" then return "Laser Gate" end
	if kind == "TeslaGates" then return "Tesla Gate" end
	if kind == "MaxiBurgerSystems" then return "MaxiBurger" end
	return (m and m.Name ~= "Model" and m.Name) or kind
end
local function alarmLearn(part)
	local p = part.Position
	local key = ("%d_%d_%d"):format(math.floor(p.X + 0.5), math.floor(p.Y + 0.5), math.floor(p.Z + 0.5))
	if alarmDB[key] then return end
	local kind = alarmKind(part)
	alarmDB[key] = { cf = { part.CFrame:GetComponents() }, size = { part.Size.X, part.Size.Y, part.Size.Z },
		name = alarmName(part, kind), kind = kind }
	alarmDirty = true
end
local alarmFolders = {}
local function isAlarmFolder(n)
	return n:find("Detect") or n:find("Sensor") or n == "LaserGates" or n == "TeslaGates" or n == "MaxiBurgerSystems"
end
-- Trigger lokal entschärfen: Touches des eigenen (client-owned) Chars meldet der Client -> CanTouch=false lokal
-- = kein Touch-Event = Server-TeamDetector feuert nicht. Reversibel; Alarm-Sound bleibt zum Gegenprüfen.
state.alarmOff = sv("alarmOff", false)
local alarmLive = {} -- [TeamDetect-Part] = true (stark: weak keys würden Instance-Wrapper verlieren)
local function alarmDisarm(d)
	if state.alarmOff then
		if d:GetAttribute("TSC_OrigCanTouch") == nil then d:SetAttribute("TSC_OrigCanTouch", d.CanTouch) end
		d.CanTouch = false
	elseif d:GetAttribute("TSC_OrigCanTouch") ~= nil then
		d.CanTouch = d:GetAttribute("TSC_OrigCanTouch"); d:SetAttribute("TSC_OrigCanTouch", nil)
	end
end
-- Wie Turrets: Trigger-Box lokal löschen (auch neu reingestreamte). Box-Anzeige bleibt (gelernte Position).
-- Nicht reversibel bis Re-Stream/Rejoin.
state.alarmDel = sv("alarmDel", false)
local alarmDeleted = 0
local function alarmSeen(d)
	alarmLearn(d)
	if state.alarmDel then
		pcall(function() d:Destroy() end)
		alarmDeleted = alarmDeleted + 1
		return
	end
	alarmLive[d] = true
	pcall(alarmDisarm, d)
end
local function hookAlarmFolder(f)
	if alarmFolders[f] then return end
	alarmFolders[f] = true
	for _, d in ipairs(f:GetDescendants()) do if d:IsA("BasePart") and d.Name == "TeamDetect" then alarmSeen(d) end end
	con(f.DescendantAdded, function(d)
		if d:IsA("BasePart") and d.Name == "TeamDetect" then task.defer(alarmSeen, d) end
	end)
end
for _, f in ipairs(workspace:GetChildren()) do if isAlarmFolder(f.Name) then hookAlarmFolder(f) end end
con(workspace.ChildAdded, function(c) if isAlarmFolder(c.Name) then hookAlarmFolder(c) end end)

local alarmObjs = {} -- [key] = {box=, wire=, bb=, lbl=}
local function clearAlarm(key)
	local o = alarmObjs[key]
	if o then for _, x in pairs(o) do pcall(function() x:Destroy() end) end alarmObjs[key] = nil end
end
local function ensureAlarm(key, z)
	if alarmObjs[key] then return alarmObjs[key] end
	local col = ALARM_COL[z.kind] or Color3.fromRGB(255, 90, 90)
	local cf, size = CFrame.new(table.unpack(z.cf)), Vector3.new(z.size[1], z.size[2], z.size[3])
	local ter = workspace.Terrain
	local box = Instance.new("BoxHandleAdornment")
	box.Adornee = ter; box.CFrame = cf; box.Size = size; box.AlwaysOnTop = true; box.ZIndex = 1
	box.Color3 = col; box.Transparency = 0.82; box.Parent = gui
	local wire = Instance.new("WireframeHandleAdornment")
	wire.Adornee = ter; wire.CFrame = cf; wire.AlwaysOnTop = true; wire.ZIndex = 2; wire.Color3 = col; wire.Thickness = 2
	local h = size / 2
	local c = {}
	for _, sx in ipairs({ -1, 1 }) do for _, sy in ipairs({ -1, 1 }) do for _, sz in ipairs({ -1, 1 }) do
		c[#c + 1] = Vector3.new(sx * h.X, sy * h.Y, sz * h.Z)
	end end end
	for i = 1, 8 do for j = i + 1, 8 do
		local d = c[i] - c[j]
		local nz = (d.X ~= 0 and 1 or 0) + (d.Y ~= 0 and 1 or 0) + (d.Z ~= 0 and 1 or 0)
		if nz == 1 then wire:AddLine(c[i], c[j]) end
	end end
	wire.Parent = gui
	local bb = Instance.new("BillboardGui")
	bb.Adornee = ter; bb.StudsOffsetWorldSpace = cf.Position + Vector3.new(0, size.Y / 2 + 1, 0)
	bb.AlwaysOnTop = true; bb.Size = UDim2.fromOffset(220, 30); bb.LightInfluence = 0; bb.Parent = gui
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.fromScale(1, 1); lbl.BackgroundTransparency = 1; lbl.Font = Enum.Font.GothamBold; lbl.TextSize = 12
	lbl.TextColor3 = col; lbl.TextStrokeTransparency = 0.3; lbl.Parent = bb
	local o = { box = box, wire = wire, bb = bb, lbl = lbl, cf = cf, size = size }
	alarmObjs[key] = o
	return o
end

toggle(S_alarm, "Show Alarm Zones", "alarms", function(on) if not on then for k in pairs(alarmObjs) do clearAlarm(k) end end end)
slider(S_alarm, "Max Distance", 50, 3000, state.alarmDist, function(v)
	state.alarmDist = math.floor(v)
	return state.alarmDist .. "m"
end, "alarmDist")
toggle(S_alarm, "Delete Alarms (local)", "alarmDel", function(on)
	if not on then return end
	for d in pairs(alarmLive) do
		if d.Parent then pcall(function() d:Destroy() end) alarmDeleted = alarmDeleted + 1 end
		alarmLive[d] = nil
	end
	for f in pairs(alarmFolders) do
		if f.Parent then
			for _, d in ipairs(f:GetDescendants()) do
				if d:IsA("BasePart") and d.Name == "TeamDetect" then pcall(function() d:Destroy() end) alarmDeleted = alarmDeleted + 1 end
			end
		end
	end
end)
toggle(S_alarm, "Disable Triggers (local)", "alarmOff", function()
	for d in pairs(alarmLive) do if d.Parent then pcall(alarmDisarm, d) else alarmLive[d] = nil end end
end)
local alarmInfo = info(S_alarm, "")
info(S_alarm, '<font color="#ff3c3c">Motion</font> · <font color="#ff9628">Laser</font> · <font color="#aa5aff">Tesla</font> · <font color="#ffdc3c">MaxiBurger</font> – box = exact trigger volume. Zones are learned when loaded once (workspace/' .. ALARM_FILE .. ').')
task.spawn(function()
	while H.alive do
		if alarmDirty then alarmDirty = false; pcall(writefile, ALARM_FILE, HttpService:JSONEncode(alarmDB)) end
		if state.alarms then
			local myRoot = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
			local myPos = myRoot and myRoot.Position or cam.CFrame.Position
			local total, shown, near, nearD, insideAny = 0, 0, nil, math.huge, nil
			for key, z in pairs(alarmDB) do
				total = total + 1
				local pos = Vector3.new(z.cf[1], z.cf[2], z.cf[3])
				local dist = (pos - myPos).Magnitude
				if dist <= state.alarmDist then
					local o = ensureAlarm(key, z)
					local lpnt = o.cf:PointToObjectSpace(myPos)
					local inside = math.abs(lpnt.X) <= o.size.X / 2 and math.abs(lpnt.Y) <= o.size.Y / 2 and math.abs(lpnt.Z) <= o.size.Z / 2
					o.box.Transparency = inside and 0.55 or 0.82
					o.lbl.Text = z.name .. "  " .. math.floor(dist) .. "m" .. (inside and "  [INSIDE]" or "")
					shown = shown + 1
					if inside then insideAny = z.name end
					if dist < nearD then nearD = dist; near = z.name end
				else
					clearAlarm(key)
				end
			end
			-- welche geladenen Alarme laufen gerade (Sound-State kommt vom Server)
			local playing = {}
			for d in pairs(alarmLive) do
				if not d.Parent then alarmLive[d] = nil end
				local snd = d.Parent and d:FindFirstChild("Alarm")
				if snd and snd:IsA("Sound") and snd.Playing then playing[#playing + 1] = alarmName(d, alarmKind(d)) end
			end
			alarmInfo.Text = ("%d/%d known zones shown%s%s%s%s"):format(shown, total,
				near and (" · nearest: " .. near .. " " .. math.floor(nearD) .. "m") or "",
				insideAny and ('\n<font color="#ff3c3c">INSIDE: ' .. insideAny .. "</font>") or "",
				(state.alarmOff and '\n<font color="#78ff8c">triggers disarmed (local)</font>' or "")
					.. (state.alarmDel and ('\n<font color="#78ff8c">alarms deleted: ' .. alarmDeleted .. "</font>") or ""),
				#playing > 0 and ('\n<font color="#ff3c3c">ALARM SOUNDING: ' .. table.concat(playing, ", ") .. "</font>") or "")
		end
		task.wait(math.max(0.5, state.updInt or 0.5))
	end
end)

-- ================= TEAM SWITCH =================
-- Gleicher Aufruf wie das Deploy-Menü: TeamChanger:InvokeServer("SwitchTeam", team). Server prüft Rechte selbst
-- (Gruppe/Spielzeit) -> nur Teams, die man eh hat. Civilian (2h Spielzeit) + Test Subject (frei).
local S_team = section(miscL, "Team Switch")
local teamInfo = info(S_team, "")
local teamBusy = false
local function switchTeam(name)
	if teamBusy then return end
	if lp.Team and lp.Team.Name == name then teamInfo.Text = "Already " .. name; return end
	teamBusy = true
	teamInfo.Text = "Switching to " .. name .. "..."
	task.spawn(function()
		local ok, res = pcall(function()
			return game:GetService("ReplicatedStorage").Remotes.Teams.TeamChanger:InvokeServer("SwitchTeam", name)
		end)
		task.wait(0.5)
		if ok and res then
			teamInfo.Text = '<font color="#78ff8c">Now: ' .. tostring(lp.Team) .. "</font>"
		else
			teamInfo.Text = '<font color="#ff3c3c">Denied: ' .. name .. (ok and "" or (" (" .. tostring(res) .. ")")) .. "</font>"
		end
		teamBusy = false
	end)
end
button(S_team, "Switch to Civilian", function() switchTeam("Civilian") end)
button(S_team, "Switch to Test Subject", function() switchTeam("Test Subject") end)
task.spawn(function()
	local last
	while H.alive do
		local t = tostring(lp.Team)
		if t ~= last and not teamBusy then last = t; teamInfo.Text = "Current team: " .. t end
		task.wait(1)
	end
end)

-- ================= VERSCHIEBBARE OVERLAYS =================
-- Nur bei offenem Menü greifbar (pinker Rahmen); sonst Active=false -> Klicks gehen normal ins Spiel.
-- Position (Ankerpunkt in Pixeln) wird unter state[key] gespeichert. Als H-Feld statt local (Hauptchunk am 200-Locals-Limit).
H.movable = function(f, key)
	state[key] = state[key] or sv(key, nil)
	-- UDim2.fromOffset setzt den Scale-Anteil auf 0. Overlays, die unten/mittig verankert definiert sind (Y-Scale 1
	-- bzw. X-Scale 0.5), landen dadurch ausserhalb des Bildschirms. Deshalb wird jede Position auf den sichtbaren
	-- Bereich begrenzt: (x,y) ist die Lage des AnchorPoints in Pixeln, daraus die linke obere Ecke berechnen,
	-- in den Viewport klemmen und zurueckrechnen. Mindestens 24 px bleiben immer sichtbar (zum Zurueckziehen).
	local function setClamped(x, y)
		local vp = cam and cam.ViewportSize or Vector2.new(1920, 1080)
		local sz, ap = f.AbsoluteSize, f.AnchorPoint
		local w = math.min(sz.X > 0 and sz.X or 200, vp.X)
		local h = math.min(sz.Y > 0 and sz.Y or 24, vp.Y)
		local left = math.clamp(x - w * ap.X, 0, math.max(vp.X - w, 0))
		local top = math.clamp(y - h * ap.Y, 0, math.max(vp.Y - h, 24))
		f.Position = UDim2.fromOffset(math.floor(left + w * ap.X + 0.5), math.floor(top + h * ap.Y + 0.5))
	end
	local p = state[key]
	if type(p) == "table" and tonumber(p[1]) and tonumber(p[2]) then
		-- erst im naechsten Frame, damit AbsoluteSize durch AutomaticSize schon stimmt
		task.defer(function() if f.Parent then setClamped(p[1], p[2]) end end)
	end
	local st = Instance.new("UIStroke"); st.Color = T.accent; st.Thickness = 1.5
	st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border; st.Enabled = false; st.Parent = f
	local drag, sp, sm = false, nil, nil
	con(f.InputBegan, function(i)
		if main.Visible and i.UserInputType == Enum.UserInputType.MouseButton1 then
			drag = true; sm = i.Position
			sp = f.AbsolutePosition + f.AbsoluteSize * f.AnchorPoint
		end
	end)
	con(UIS.InputChanged, function(i)
		if drag and i.UserInputType == Enum.UserInputType.MouseMovement then
			local d = i.Position - sm
			setClamped(sp.X + d.X, sp.Y + d.Y)
		end
	end)
	con(UIS.InputEnded, function(i)
		if drag and i.UserInputType == Enum.UserInputType.MouseButton1 then
			drag = false; state[key] = { f.Position.X.Offset, f.Position.Y.Offset }
		end
	end)
	con(RunService.RenderStepped, function()
		local open = main.Visible
		if st.Enabled ~= open then st.Enabled = open; f.Active = open end
		if not open then drag = false end
		-- Laufende Korrektur anhand der ECHTEN Bildschirmposition: reicht nicht, die Position einmal beim Laden zu
		-- klemmen, weil AutomaticSize das Overlay nachtraeglich wachsen laesst und unten verankerte Overlays dadurch
		-- oben aus dem Bild wandern. Hier wird nur nachgeschoben, wenn es wirklich rausragt.
		local ap, sz = f.AbsolutePosition, f.AbsoluteSize
		local vp = cam and cam.ViewportSize or Vector2.new(1920, 1080)
		local dx, dy = 0, 0
		if sz.X > 0 and sz.X <= vp.X then
			if ap.X < 0 then dx = -ap.X elseif ap.X + sz.X > vp.X then dx = vp.X - (ap.X + sz.X) end
		end
		if sz.Y > 0 and sz.Y <= vp.Y then
			if ap.Y < 0 then dy = -ap.Y elseif ap.Y + sz.Y > vp.Y then dy = vp.Y - (ap.Y + sz.Y) end
		end
		if math.abs(dx) >= 1 or math.abs(dy) >= 1 then
			f.Position = f.Position + UDim2.fromOffset(math.floor(dx + 0.5), math.floor(dy + 0.5))
		end
	end)
end

H.movable(H.staffPanel, "staffPos")

-- ================= RADIO SPY =================
-- Remotes.RadioHistory:InvokeServer() (ohne Args) liefert die letzten 20 Funknachrichten der "gehörten" Kanäle
-- (Main) – auch ohne Funkgerät / als Test Subject. Pollen alle 4s (wie das Spiel selbst), Dedupe, Anzeige im
-- Players-Tab + optionales Overlay unten links.
state.radioSpy = sv("radioSpy", false)
state.radioOverlay = sv("radioOverlay", false)
;(function()
	local CHANNELS = { "Main", "Surface", "QA Dev Gaming" }
	local S_radio = section(plR, "Radio Spy")
	local log, seenKey = {}, {}
	local MAXLOG = 40
	local function esc(s) return (tostring(s):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")) end
	toggle(S_radio, "Read Radio (Main)", "radioSpy", function() end)
	toggle(S_radio, "Overlay", "radioOverlay", function() end)
	local radioInfo = info(S_radio, "")
	local ov = Instance.new("TextLabel")
	ov.AnchorPoint = Vector2.new(0, 1); ov.Position = UDim2.new(0, 12, 1, -120); ov.Size = UDim2.fromOffset(460, 0)
	ov.AutomaticSize = Enum.AutomaticSize.Y; ov.BackgroundColor3 = Color3.fromRGB(10, 10, 12); ov.BackgroundTransparency = 0.35
	ov.Font = Enum.Font.Code; ov.TextSize = 13; ov.RichText = true; ov.TextWrapped = true; ov.TextColor3 = Color3.fromRGB(230, 230, 230)
	ov.TextXAlignment = Enum.TextXAlignment.Left; ov.TextYAlignment = Enum.TextYAlignment.Top; ov.Visible = false; ov.Parent = gui
	Instance.new("UICorner", ov).CornerRadius = UDim.new(0, 4)
	local pad = Instance.new("UIPadding", ov); pad.PaddingLeft = UDim.new(0, 6); pad.PaddingRight = UDim.new(0, 6)
	pad.PaddingTop = UDim.new(0, 4); pad.PaddingBottom = UDim.new(0, 4)
	H.movable(ov, "radioPos")
	local function render()
		local function lines(n)
			local t = {}
			for i = math.max(1, #log - n + 1), #log do
				local m = log[i]
				t[#t + 1] = ('<font color="#767676">[%s] %s</font> <font color="#f5a8de">%s</font>: %s'):format(
					esc(m.Date), esc(CHANNELS[m.Channel] or m.Channel), esc(m.Sender), esc(m.Message))
			end
			return table.concat(t, "\n")
		end
		radioInfo.Text = #log > 0 and lines(14) or "no messages yet"
		ov.Text = '<font color="#f5a8de">RADIO</font>\n' .. (#log > 0 and lines(7) or "...")
	end
	-- Fake-TSC hat kein RadioHistory: dort passiv auf WalkieTalkieMessage mithoeren (Server schickt Sender-Char,
	-- Text, Funkgeraet mit Attribut Channel; nur OnClientEvent, kein Hook)
	local RSr = game:GetService("ReplicatedStorage")
	local hasHistory = RSr:FindFirstChild("Remotes") and RSr.Remotes:FindFirstChild("RadioHistory")
	local wtm = not hasHistory and RSr:FindFirstChild("Remotes") and RSr.Remotes:FindFirstChild("WalkieTalkieMessage")
	-- Fake-TSC: Server legt jede Funknachricht kurz als StringValue in <Radio-Tool>.CapturedTexts ab (Value = Text,
	-- Kinder Sender/Chat/Date) – auch in den Tools ANDERER Spieler (Backpack repliziert). Per ChildAdded live mitlesen.
	if not hasHistory then
		local hookedCT = {}
		local function addMsg(m)
			if not state.radioSpy or not m:IsA("StringValue") then return end
			local snd, cht, dat = m:WaitForChild("Sender", 2), m:WaitForChild("Chat", 2), m:WaitForChild("Date", 2)
			local k = tostring(cht and cht.Value) .. "|" .. tostring(dat and dat.Value) .. "|" .. tostring(snd and snd.Value) .. "|" .. m.Value
			if m.Value == "" or seenKey[k] then return end
			seenKey[k] = true
			log[#log + 1] = { Date = dat and dat.Value or os.date("%H:%M"), Sender = snd and snd.Value or "?", Message = m.Value, Channel = cht and cht.Value or "?" }
			while #log > MAXLOG do table.remove(log, 1) end
		end
		local function watchTool(t)
			local ct = t:IsA("Tool") and t:FindFirstChild("CapturedTexts")
			if not ct or hookedCT[ct] then return end
			hookedCT[ct] = true
			for _, m in ipairs(ct:GetChildren()) do task.spawn(pcall, addMsg, m) end
			con(ct.ChildAdded, function(m) task.spawn(pcall, addMsg, m) end)
		end
		local function watchCont(c)
			if not c then return end
			for _, t in ipairs(c:GetChildren()) do pcall(watchTool, t) end
			con(c.ChildAdded, function(t) task.defer(pcall, watchTool, t) end)
		end
		local function watchPlayer(pl)
			task.spawn(function() watchCont(pl:WaitForChild("Backpack", 10)) end)
			if pl.Character then watchCont(pl.Character) end
			con(pl.CharacterAdded, watchCont)
		end
		for _, pl in ipairs(Players:GetPlayers()) do watchPlayer(pl) end
		con(Players.PlayerAdded, watchPlayer)
	end
	if wtm then
		con(wtm.OnClientEvent, function(kind, who, msg, dev)
			if not state.radioSpy or kind == "SENDMESSAGE" or type(msg) ~= "string" then return end
			local sender = typeof(who) == "Instance" and who.Name or tostring(who)
			local ch = typeof(dev) == "Instance" and dev:GetAttribute("Channel") or "?"
			log[#log + 1] = { Date = os.date("%H:%M:%S"), Sender = sender, Message = msg, Channel = ch }
			while #log > MAXLOG do table.remove(log, 1) end
		end)
	end
	task.spawn(function()
		while H.alive do
			if state.radioSpy and not hasHistory then
				render()
				ov.Visible = state.radioOverlay
			elseif state.radioSpy then
				local ok, h = pcall(function() return game:GetService("ReplicatedStorage").Remotes.RadioHistory:InvokeServer() end)
				if ok and type(h) == "table" and type(h.history) == "table" then
					local fresh = {}
					for ch, list in pairs(h.history) do
						for _, m in ipairs(list) do
							local k = tostring(ch) .. "|" .. tostring(m.Date) .. "|" .. tostring(m.Sender) .. "|" .. tostring(m.Message)
							if not seenKey[k] then
								seenKey[k] = true
								fresh[#fresh + 1] = { Date = m.Date, Sender = m.Sender, Message = m.Message, Channel = m.Channel or ch }
							end
						end
					end
					table.sort(fresh, function(a, b) return tostring(a.Date) < tostring(b.Date) end)
					for _, m in ipairs(fresh) do log[#log + 1] = m end
					while #log > MAXLOG do table.remove(log, 1) end
				elseif not ok then
					radioInfo.Text = "RadioHistory failed: " .. esc(h)
				end
				render()
				ov.Visible = state.radioOverlay
			else
				ov.Visible = false
				radioInfo.Text = ""
			end
			task.wait(4)
		end
	end)

end)()

-- ================= CHAT LOG =================
-- TextChatService liefert alle RBXGeneral-Nachrichten an den Client (auch von weit weg/nicht geladenen Spielern),
-- das Spiel blendet nur das Chatfenster aus (Bubbles max 100 Studs). MessageReceived mitlesen (Listener, kein Hook).
state.chatLog = sv("chatLog", false)
state.chatOverlay = sv("chatOverlay", false)
;(function()
	local TCS = game:GetService("TextChatService")
	local S_chat = section(plR, "Chat Log")
	local log = {}
	local MAXLOG = 40
	local function esc(s) return (tostring(s):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")) end
	toggle(S_chat, "Read Chat", "chatLog", function() end)
	toggle(S_chat, "Chat Overlay", "chatOverlay", function() end)
	local chatInfo = info(S_chat, "")
	local ov = Instance.new("TextLabel")
	ov.AnchorPoint = Vector2.new(0, 1); ov.Position = UDim2.new(0, 480, 1, -120); ov.Size = UDim2.fromOffset(460, 0)
	ov.AutomaticSize = Enum.AutomaticSize.Y; ov.BackgroundColor3 = Color3.fromRGB(10, 10, 12); ov.BackgroundTransparency = 0.35
	ov.Font = Enum.Font.Code; ov.TextSize = 13; ov.RichText = true; ov.TextWrapped = true; ov.TextColor3 = Color3.fromRGB(230, 230, 230)
	ov.TextXAlignment = Enum.TextXAlignment.Left; ov.TextYAlignment = Enum.TextYAlignment.Top; ov.Visible = false; ov.Parent = gui
	Instance.new("UICorner", ov).CornerRadius = UDim.new(0, 4)
	local pad = Instance.new("UIPadding", ov); pad.PaddingLeft = UDim.new(0, 6); pad.PaddingRight = UDim.new(0, 6)
	pad.PaddingTop = UDim.new(0, 4); pad.PaddingBottom = UDim.new(0, 4)
	H.movable(ov, "chatPos")
	local dirty = false
	local function lines(n)
		local t = {}
		for i = math.max(1, #log - n + 1), #log do
			local m = log[i]
			t[#t + 1] = ('<font color="#767676">[%s]%s</font> <font color="#%s">[%s]</font> <font color="#8fd0ff">%s</font>: %s'):format(
				m.t, m.far and " far" or "", m.roleCol, esc(m.role), esc(m.name), esc(m.text))
		end
		return table.concat(t, "\n")
	end
	con(TCS.MessageReceived, function(msg)
		if not state.chatLog then return end
		local ch = msg.TextChannel and msg.TextChannel.Name or ""
		if ch == "RBXSystem" then return end
		local src = msg.TextSource
		local pl = src and Players:GetPlayerByUserId(src.UserId)
		local c = pl and pl.Character
		local far = not (c and c:IsDescendantOf(workspace))
		local team = pl and pl.Team
		log[#log + 1] = { t = os.date("%H:%M:%S"), name = pl and pl.DisplayName or (src and src.Name) or "?",
			text = msg.Text or "", far = far and pl ~= lp,
			role = team and team.Name or "", roleCol = team and team.TeamColor.Color:ToHex() or "767676" }
		while #log > MAXLOG do table.remove(log, 1) end
		dirty = true
	end)
	task.spawn(function()
		while H.alive do
			if state.chatLog then
				if dirty then
					dirty = false
					chatInfo.Text = lines(14)
					ov.Text = '<font color="#8fd0ff">CHAT</font>\n' .. lines(7)
				elseif #log == 0 then
					chatInfo.Text = "waiting for messages..."
					ov.Text = '<font color="#8fd0ff">CHAT</font>\n...'
				end
				ov.Visible = state.chatOverlay
			else
				ov.Visible = false
				chatInfo.Text = ""
			end
			task.wait(0.5)
		end
	end)
end)()

-- ================= DISGUISE DETECTOR =================
-- DISGUISE-CARD -> Server legt Character.DisguisedAsTeam (ObjectValue -> Team, +FakeNameIndex) an; plrTag zeigt dann
-- falsches Team/Rang. Leaderboard/Player.Team bleibt echt -> Vergleich entlarvt. Rein lesend.
state.disgDetect = sv("disgDetect", true)
;(function()
	local S_disg = section(visL, "Disguise Detector")
	toggle(S_disg, "Reveal Disguises", "disgDetect", function() end)
	local disgInfo = info(S_disg, "")
	local tags = {} -- [player] = billboard
	local function clearTag(p) if tags[p] then pcall(function() tags[p]:Destroy() end) tags[p] = nil end end
	con(Players.PlayerRemoving, clearTag)
	task.spawn(function()
		while H.alive do
			local lines = {}
			for _, p in ipairs(Players:GetPlayers()) do
				local c = p.Character
				local d = state.disgDetect and p ~= lp and c and c:FindFirstChild("DisguisedAsTeam")
				local head = c and (c:FindFirstChild("Head") or c:FindFirstChild("HumanoidRootPart"))
				if d and head and c:IsDescendantOf(workspace) then
					local real = p.Team and p.Team.Name or "?"
					local fake = d.Value and d.Value.Name or "?"
					local bb = tags[p]
					if not bb or bb.Adornee ~= head then
						clearTag(p)
						bb = Instance.new("BillboardGui")
						bb.AlwaysOnTop = true; bb.Size = UDim2.fromOffset(170, 22); bb.StudsOffset = Vector3.new(0, 4.6, 0)
						bb.LightInfluence = 0; bb.Adornee = head; bb.Parent = gui
						local l = Instance.new("TextLabel")
						l.Size = UDim2.fromScale(1, 1); l.BackgroundTransparency = 1; l.Font = Enum.Font.GothamBold; l.TextSize = 9
						l.TextColor3 = Color3.fromRGB(255, 110, 110); l.TextTransparency = 0.2; l.TextStrokeTransparency = 0.5; l.Parent = bb
						tags[p] = bb
					end
					bb.TextLabel.Text = ("disguised · real: %s"):format(real)
					lines[#lines + 1] = ('<font color="#ff4646">%s</font>: real <b>%s</b> → shown %s'):format(p.Name, real, fake)
				else
					clearTag(p)
					if state.disgDetect and p ~= lp and c and not c:IsDescendantOf(workspace) then
						-- nicht geladen: Child ggf. noch lesbar
						local d2 = c:FindFirstChild("DisguisedAsTeam")
						if d2 then lines[#lines + 1] = ('<font color="#ff9696">%s</font>: real %s → shown %s (far)'):format(
							p.Name, p.Team and p.Team.Name or "?", d2.Value and d2.Value.Name or "?") end
					end
				end
			end
			disgInfo.Text = state.disgDetect and (#lines > 0 and table.concat(lines, "\n") or "No disguised players.") or ""
			task.wait(1)
		end
	end)
end)()

-- ================= FAKE TRANSLATOR =================
-- HayperScript.ChatHandler übersetzt Infected-Sprache nur clientseitig: HasTranslator/CanHearInfected prüfen
-- LocalPlayer.Backpack:FindFirstChild("Translator") OHNE Typprüfung. Ein lokaler Folder "Translator" im Backpack genügt:
-- erscheint nicht in der Hotbar, repliziert nicht zum Server; Skripte, die das Backpack durchgehen, prüfen IsA("Tool").
state.fakeTranslator = sv("fakeTranslator", false)
;(function()
	local S_tr = section(plR, "Fake Translator")
	local function ensure()
		local bp = lp:FindFirstChild("Backpack")
		if not bp then return end
		local f = bp:FindFirstChild("Translator")
		if state.fakeTranslator then
			if not f then
				f = Instance.new("Folder"); f.Name = "Translator"; f:SetAttribute("TSCFake", true); f.Parent = bp
			end
		elseif f and f:GetAttribute("TSCFake") then
			f:Destroy()
		end
	end
	toggle(S_tr, "Understand Infected", "fakeTranslator", function() pcall(ensure) end)
	info(S_tr, "Infected speech in chat bubbles gets translated like with a real Translator. Local only.")
	-- Backpack wird bei Respawn neu erzeugt -> regelmäßig nachziehen
	task.spawn(function() while H.alive do pcall(ensure) task.wait(1) end end)
	table.insert(H.conns, { Disconnect = function() state.fakeTranslator = false; pcall(ensure) end })
end)()

-- ================= ADONIS MONITOR =================
-- Adonis (Admin-System) schickt Server->Client-Aufrufe im Klartext über sein GUID-Remote in ReplicatedStorage
-- (RemoteEvent mit Kind "__FUNCTION"): Args = {Sent, Mode}, Key, Befehlsname, Argumente (z. B. "NewCape", Durchsagen,
-- Hinweise, Notifications). Dazu Chat-Befehle mit ":" / ";" aus TextChatService. Nur Zuhören (Listener, kein Hook).
-- Log im Tab + Overlay + dauerhaft in workspace/tsc_adonis_log.txt (gepuffert, alle 3 s).
state.adonisMon = sv("adonisMon", true)
state.adonisOverlay = sv("adonisOverlay", false)
;(function()
	local S_ad = section(plR, "Adonis Monitor")
	local LOG_FILE = "tsc_adonis_log.txt"
	local log, fileBuf = {}, {}
	local MAXLOG = 60
	local function esc(s) return (tostring(s):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")) end
	local function ser(v, d)
		d = d or 0
		local tv = typeof(v)
		if tv == "Instance" then return "<" .. v.Name .. ">" end
		if tv == "string" then return '"' .. v:sub(1, 120) .. '"' end
		if tv ~= "table" then return tostring(v) end
		if d > 2 then return "{..}" end
		local t, n = {}, 0
		for k, x in pairs(v) do n = n + 1 if n > 8 then t[#t + 1] = "…" break end t[#t + 1] = tostring(k) .. "=" .. ser(x, d + 1) end
		return "{" .. table.concat(t, ", ") .. "}"
	end
	local function add(kind, text, hot)
		local e = { t = os.date("%H:%M:%S"), kind = kind, text = text, hot = hot }
		log[#log + 1] = e
		while #log > MAXLOG do table.remove(log, 1) end
		fileBuf[#fileBuf + 1] = ("[%s] %s %s"):format(e.t, kind, text)
	end
	H.adLog = add -- Command Effects schreibt in dasselbe Log
	toggle(S_ad, "Monitor Adonis + Chat Commands", "adonisMon", function() end)
	toggle(S_ad, "Adonis Overlay", "adonisOverlay", function() end)
	local adInfo = info(S_ad, "")
	info(S_ad, "Logged permanently to workspace/" .. LOG_FILE)

	-- Adonis-Remote finden: GUID-Name + Kind "__FUNCTION"
	local function findAdonisRemote()
		for _, c in ipairs(game:GetService("ReplicatedStorage"):GetChildren()) do
			if c:IsA("RemoteEvent") and c:FindFirstChild("__FUNCTION") and c.Name:match("^%x+%-%x+%-%x+%-%x+%-%x+$") then return c end
		end
	end
	local adRemote = findAdonisRemote()
	if adRemote then
		con(adRemote.OnClientEvent, function(...)
			if not state.adonisMon then return end
			local a = { ... }
			local cmd = a[3]
			local rest = {}
			for i = 4, select("#", ...) do rest[#rest + 1] = ser(a[i]) end
			local name = type(cmd) == "string" and cmd or ser(cmd)
			-- Durchsagen / Nachrichten / Kicks / Teleports hervorheben
			local l = name:lower()
			local hot = l:find("message") or l:find("hint") or l:find("notif") or l:find("kick") or l:find("ban")
				or l:find("tele") or l:find("warn") or l:find("announce") or l:find("countdown") or l:find("function")
			add("ADONIS", name .. (#rest > 0 and ("  " .. table.concat(rest, " | ")) or ""), hot)
		end)
	else
		add("INFO", "Adonis remote not found", false)
	end

	-- Chat-Befehle (alle üblichen Präfixe)
	con(game:GetService("TextChatService").MessageReceived, function(msg)
		if not state.adonisMon then return end
		local text = msg.Text or ""
		-- Befehlspräfix + direkt ein Buchstabe (":kill", ";tp", "!cd", "/e", ".cmds", "?help", "-x", "$x", "#x", "~x", ">x")
		if not text:match("^[:;!/%.%?%-%$#~>]%a") then return end
		local src = msg.TextSource
		local pl = src and Players:GetPlayerByUserId(src.UserId)
		local staff = pl and select(2, pcall(staffInfo, pl))
		local who = pl and pl.Name or (src and src.Name) or "?"
		local team = pl and pl.Team and pl.Team.Name or ""
		add("CMD", ("%s%s [%s]: %s"):format(staff and "★ " or "", who, team, text), true)
	end)

	local ov = Instance.new("TextLabel")
	ov.AnchorPoint = Vector2.new(0, 1); ov.Position = UDim2.new(0, 12, 1, -300); ov.Size = UDim2.fromOffset(520, 0)
	ov.AutomaticSize = Enum.AutomaticSize.Y; ov.BackgroundColor3 = Color3.fromRGB(10, 10, 12); ov.BackgroundTransparency = 0.35
	ov.Font = Enum.Font.Code; ov.TextSize = 13; ov.RichText = true; ov.TextWrapped = true; ov.TextColor3 = Color3.fromRGB(230, 230, 230)
	ov.TextXAlignment = Enum.TextXAlignment.Left; ov.TextYAlignment = Enum.TextYAlignment.Top; ov.Visible = false; ov.Parent = gui
	Instance.new("UICorner", ov).CornerRadius = UDim.new(0, 4)
	local pad = Instance.new("UIPadding", ov); pad.PaddingLeft = UDim.new(0, 6); pad.PaddingRight = UDim.new(0, 6)
	pad.PaddingTop = UDim.new(0, 4); pad.PaddingBottom = UDim.new(0, 4)
	local function lines(n)
		local t = {}
		for i = math.max(1, #log - n + 1), #log do
			local m = log[i]
			local col = m.kind == "CMD" and "#8fd0ff" or (m.hot and "#ff6b6b" or "#f5a8de")
			t[#t + 1] = ('<font color="#767676">[%s]</font> <font color="%s">%s</font> %s'):format(m.t, col, m.kind, esc(m.text))
		end
		return table.concat(t, "\n")
	end
	local lastFlush = os.clock()
	task.spawn(function()
		while H.alive do
			if state.adonisMon then
				adInfo.Text = #log > 0 and lines(16) or "waiting for Adonis events / commands..."
				ov.Text = '<font color="#f5a8de">ADONIS</font>\n' .. (#log > 0 and lines(8) or "...")
				ov.Visible = state.adonisOverlay
			else
				adInfo.Text = ""; ov.Visible = false
			end
			if #fileBuf > 0 and os.clock() - lastFlush > 3 then
				lastFlush = os.clock()
				local chunk = table.concat(fileBuf, "\n") .. "\n"
				fileBuf = {}
				if isfile(LOG_FILE) then pcall(appendfile, LOG_FILE, chunk) else pcall(writefile, LOG_FILE, chunk) end
			end
			task.wait(0.5)
		end
	end)
end)()

-- ================= INFECTED: INFINITE ABILITIES =================
-- Cloak (J) / Hypnotize (K) hängen an der globalen Tabelle `abilitySlots` im Script Character.AbilityHandlerClient
-- (Zugriff per getsenv — NICHT per Garbage-Collector-Scan, der baut ~460k Objekte und lässt das Spiel ruckeln).
-- Ablauf im Spiel: Cloak.LocalScript hört auf das lokale BindableEvent slot.Event — "StartAbility" -> FireServer("Cloak"),
-- alles andere ("EndAbility"/"PressedWhileActive") -> FireServer("Uncloak"). Das Ende kommt NUR vom Client (Duration läuft
-- ab); der Server hat KEINEN eigenen Timer (gemessen 27.09.: 17 s getarnt, kein "UncloakPlayer" vom Server).
-- Toggle-Taste feuert daher nur das lokale BindableEvent — den Remote schickt der Spieleigene Code. Duration/Cooldown
-- werden gehalten, damit das Spiel nicht selbst nach 10 s enttarnt. NIE doppelt tarnen: jedes "CloakPlayer" merkt sich die
-- aktuelle Transparenz (dann 1) als Ausgangswert -> nach dem Enttarnen bleibt man auf allen Clients unsichtbar.
state.infAbil = sv("infAbil", false)
;(function()
	local S_ab = section(miscL, "Infected Abilities")
	local cachedScript, cachedSlots = nil, nil
	local function getSlots()
		local c = lp.Character
		local ah = c and c:FindFirstChild("AbilityHandlerClient")
		if not ah then cachedScript, cachedSlots = nil, nil return end
		if ah == cachedScript and type(cachedSlots) == "table" then return cachedSlots end
		cachedScript, cachedSlots = ah, nil
		if typeof(getsenv) ~= "function" then return end
		local ok, env = pcall(getsenv, ah)
		if ok and type(env) == "table" and type(env.abilitySlots) == "table" then cachedSlots = env.abilitySlots end
		return cachedSlots
	end
	local function cloakSlot()
		local slots = getSlots()
		if not slots then return end
		for _, s in pairs(slots) do
			local o = type(s) == "table" and rawget(s, "OriginScript")
			if typeof(o) == "Instance" and o.Name == "Cloak" then return s end
		end
	end
	-- wantCloak: Spieler will getarnt sein. Endet die Tarnung ohne Tastendruck (vereinzelt beobachtet), wird neu getarnt —
	-- erst nach >= 1.2 s, damit das Enttarnen fertig ist (sonst merkt sich CloakPlayer eine halbe Transparenz).
	local busy, wantCloak, lastTry, hookedEv = false, false, 0, nil
	-- Fake-TSC: Cloak ist ein Server-Script (ClassName "Script") mit RemoteEvent; der Spiel-Automat haengt sich dort gern
	-- in "warte bis Torso.Transparency >= 1" auf. Deshalb direkt "Cloak"/"Uncloak" feuern (gleicher Aufruf wie das Spiel),
	-- Zustand ueber die Torso-Transparenz; nie doppelt tarnen (nur bei sichtbar), Server hat keinen eigenen Timer (30 s+ gemessen).
	H.cloakDirect = function(s)
		local o = s and rawget(s, "OriginScript")
		if typeof(o) ~= "Instance" or o.ClassName ~= "Script" then return nil end
		local tor = lp.Character and lp.Character:FindFirstChild("Torso")
		return o:FindFirstChild("RemoteEvent"), tor
	end
	H.isCloaked = function(s)
		local re, tor = H.cloakDirect(s)
		if re then return tor ~= nil and tor.Transparency > 0.95 end
		return rawget(s, "Active") == true
	end
	local function setCloak(on)
		local s = cloakSlot()
		local re, tor = H.cloakDirect(s)
		if re then
			if not tor then return end
			wantCloak = on; lastTry = os.clock()
			-- Slot.Active mitfuehren: sonst loest die Spieltaste (U) waehrend Hub-Tarnung "StartAbility" = ZWEITES Cloak aus ->
			-- Server speichert PreviousTransparency=1 an allen Teilen und Uncloak macht nie wieder sichtbar (nur Respawn hilft)
			if on and tor.Transparency < 0.05 then pcall(function() s.Active = true end); re:FireServer("Cloak")
			elseif not on and tor.Transparency > 0.95 then pcall(function() s.Active = false end); re:FireServer("Uncloak") end
			return
		end
		local ev = s and rawget(s, "Event")
		if not ev or busy then return end
		wantCloak = on
		lastTry = os.clock()
		if (rawget(s, "Active") == true) == on then return end
		busy = true
		task.spawn(function()
			-- das Cloak-Script sperrt sich 1 s nach jedem Start/Ende -> bis zu 1.5 s nachfassen, bis der Zustand stimmt
			local t0 = os.clock()
			repeat
				pcall(function() ev:Fire(on and "StartAbility" or "EndAbility") end)
				local t1 = os.clock()
				repeat task.wait(0.05) until (rawget(s, "Active") == true) == on or os.clock() - t1 > 0.3
			until (rawget(s, "Active") == true) == on or os.clock() - t0 > 1.5 or not on
			busy = false
		end)
	end
	toggle(S_ab, "Infinite Cloak / Abilities", "infAbil", function(on)
		if not on then setCloak(false); wantCloak = false end
	end, "cloak")
	local abInfo = info(S_ab, "")
	info(S_ab, "Press the key to cloak, press it again to uncloak — no time limit, no cooldown. J still works too. Hypnotize (K) also has no cooldown while this is on.")

	con(UIS.InputBegan, function(i, gp)
		if gp or not state.infAbil or not state.keys.cloak or not keyMatch(i, state.keys.cloak) then return end
		if UIS:GetFocusedTextBox() then return end
		-- Ist die Toggle-Taste zugleich die Spieltaste (J), macht das Spiel es selbst
		local s = cloakSlot()
		if not s or rawget(s, "Keybind") == i.KeyCode then return end
		setCloak(not H.isCloaked(s))
	end)
	task.spawn(function()
		while H.alive do
			if state.infAbil then
				local slots = getSlots()
				if slots then
					local names, cloaked = {}, false
					for _, s in pairs(slots) do
						if type(s) == "table" then
							pcall(function()
								if rawget(s, "MaxDuration") then s.Duration = s.MaxDuration end
								if (rawget(s, "Cooldown") or 0) > 0 then s.Cooldown = 0 end
								local o = rawget(s, "OriginScript")
								if typeof(o) == "Instance" then
									names[#names + 1] = o.Name
									if o.Name == "Cloak" and H.isCloaked(s) then cloaked = true end
								end
							end)
						end
					end
					-- J während der Tarnung = bewusst enttarnen (nicht wieder tarnen)
					local cs = cloakSlot()
					local ev = cs and rawget(cs, "Event")
					if ev and ev ~= hookedEv then
						hookedEv = ev; wantCloak = false
						con(ev.Event, function(n) if n == "PressedWhileActive" then wantCloak = false end end)
					end
					H.cloakActive = cloaked
					if wantCloak and cs and not cloaked and not busy and os.clock() - lastTry > 1.2 then setCloak(true) end
					abInfo.Text = ('<font color="#78ff8c">holding: %s</font>%s'):format(
						#names > 0 and table.concat(names, ", ") or "?",
						cloaked and '  ·  <font color="#d266b4">CLOAKED</font>' or "")
				else
					abInfo.Text = typeof(getsenv) == "function" and "no abilities found (are you Infected?)" or "getsenv not available"
				end
			elseif abInfo.Text ~= "" then
				abInfo.Text = ""
			end
			task.wait(0.25)
		end
	end)
end)()

-- ================= SELF REVIVE =================
-- Downed: der Server haengt einen ProximityPrompt "RevivePrompt" an den eigenen Torso. Nur DownLocal (Client) schaltet ihn
-- per DescendantAdded lokal ab (Enabled=false), damit man sich nicht selbst aufheben kann -> lokal wieder an + selbst
-- ausloesen. Ob der Server den Ausloeser prueft (Reviver ~= Downed), ist UNGETESTET. Revive-Cooldown 60 s (LastDownTime).
;(function()
	local S_rv = section(miscL, "Self Revive")
	state.autoRevive = sv("autoRevive", false)
	toggle(S_rv, "Auto Revive (instant)", "autoRevive", function() end)
	local rvInfo = info(S_rv, "")
	H.selfRevive = function()
		local c = lp.Character
		local tor = c and c:FindFirstChild("Torso")
		local pr = tor and tor:FindFirstChild("RevivePrompt")
		if not (pr and pr:IsA("ProximityPrompt")) then
			rvInfo.Text = "no RevivePrompt on you (only exists while downed)"
			return
		end
		if typeof(fireproximityprompt) ~= "function" then rvInfo.Text = "fireproximityprompt not available" return end
		pr.Enabled = true
		pr.HoldDuration = 0 -- Haltedauer prueft nur der Client
		local ok, err = pcall(fireproximityprompt, pr)
		if not ok then rvInfo.Text = "failed: " .. tostring(err) return end
		rvInfo.Text = "revive prompt fired, waiting..."
		task.wait(1.5)
		local hum = c:FindFirstChildOfClass("Humanoid")
		local down = c:GetAttribute("Down")
		rvInfo.Text = (not down) and '<font color="#78ff8c">up again</font>'
			or ("still down (hp " .. (hum and math.floor(hum.Health) or "?") .. ") - server probably rejects self-revive")
	end
	button(S_rv, "Revive myself", function() task.spawn(pcall, H.selfRevive) end)
	-- Auto: sobald der RevivePrompt am eigenen Torso existiert sofort ausloesen, Wiederholung hoechstens alle 1.5 s
	local busy, last = false, 0
	task.spawn(function()
		while H.alive do
			if state.autoRevive and not busy and os.clock() - last > 1.5 then
				local c = lp.Character
				local tor = c and c:FindFirstChild("Torso")
				local pr = tor and tor:FindFirstChild("RevivePrompt")
				local hum = c and c:FindFirstChildOfClass("Humanoid")
				if pr and hum and hum.Health > 0 then
					busy, last = true, os.clock()
					task.spawn(function() pcall(H.selfRevive); busy = false end)
				end
			end
			task.wait(0.1)
		end
	end)
	info(S_rv, "Use while downed. Re-enables your own revive prompt (the game only hides it on your screen) and triggers it.")
end)()

-- ================= CLICK TP =================
-- Strg + Linksklick = zum Mauspunkt teleportieren (eigene HRP-CFrame setzen, repliziert wie normale Bewegung).
-- Detail-Modus: Strg + Klick setzt stattdessen eine Blase; Pfeiltasten schieben sie (kamerarelativ), Numpad 4/1 = hoch/runter,
-- Enter = hinteleportieren, Backspace = abbrechen. Während die Blase existiert, schluckt ContextActionService diese Tasten,
-- damit der Charakter nicht mitläuft. Keine Remotes.
state.clickTp = sv("clickTp", false); state.tpDetail = sv("tpDetail", false); state.tpBubbleSpeed = sv("tpBubbleSpeed", 20); state.tpZH = sv("tpZH", false)
;(function()
	local CAS = game:GetService("ContextActionService")
	toggle(S_move, "Ctrl + Click TP", "clickTp", function(on) if not on then H.tpCancel() end end)
	toggle(S_move, "TP Detail Mode (bubble)", "tpDetail", function(on) if not on then H.tpCancel() end end)
	slider(S_move, "Bubble Speed", 5, 80, state.tpBubbleSpeed, function(v)
		state.tpBubbleSpeed = math.floor(v + 0.5); return state.tpBubbleSpeed .. " studs/s" end, "tpBubbleSpeed")
	-- Hoch/Runter zusätzlich auf Z/H. Deutsches Layout: die Taste mit "Z" drauf kommt in Roblox als KeyCode.Y an (gemessen).
	local UP_ZH, DOWN_ZH = Enum.KeyCode.Y, Enum.KeyCode.H
	toggle(S_move, "Bubble Up/Down on Z / H", "tpZH", function() if H.tpRebind then H.tpRebind() end end)
	local tpInfo = info(S_move, "Ctrl+Click = teleport. Detail mode: Ctrl+Click places a bubble · arrows move · Numpad 4/1 (or Z/H) up/down · Enter = TP · Backspace = cancel.")

	local params = RaycastParams.new(); params.FilterType = Enum.RaycastFilterType.Exclude
	local function mouseHit()
		local m = UIS:GetMouseLocation()
		local ray = cam:ViewportPointToRay(m.X, m.Y)
		params.FilterDescendantsInstances = { lp.Character, H.tpBubble }
		local r = workspace:Raycast(ray.Origin, ray.Direction * 3000, params)
		return r and r.Position
	end
	local function tpTo(pos)
		local c = lp.Character
		local hrp = c and c:FindFirstChild("HumanoidRootPart")
		if not hrp then return end
		local look = hrp.CFrame.LookVector
		hrp.AssemblyLinearVelocity = Vector3.zero
		hrp.CFrame = CFrame.lookAt(pos, pos + Vector3.new(look.X, 0, look.Z))
	end

	-- Blase: lokales Teil (nur für uns sichtbar), Position = künftige HRP-Position; Linie + Abstand zum Boden
	local bubble, line, bb
	local onConfirm -- optional: wird bei Enter vor dem TP aufgerufen (z. B. Return-Stelle merken)
	local held = {}
	local KEYS = { Enum.KeyCode.Up, Enum.KeyCode.Down, Enum.KeyCode.Left, Enum.KeyCode.Right,
		Enum.KeyCode.KeypadFour, Enum.KeyCode.KeypadOne, Enum.KeyCode.Return, Enum.KeyCode.KeypadEnter, Enum.KeyCode.Backspace }
	H.tpCancel = function()
		-- Kamera zurück auf den eigenen Charakter
		local c = workspace.CurrentCamera
		if c and bubble and c.CameraSubject == bubble then
			local hum = lp.Character and lp.Character:FindFirstChildOfClass("Humanoid")
			if hum then c.CameraSubject = hum end
		end
		if bubble then bubble:Destroy(); bubble = nil end
		if line then line:Destroy(); line = nil end
		H.tpBubble = nil
		onConfirm = nil
		table.clear(held)
		pcall(function() CAS:UnbindAction("TSC_TP_BUBBLE") end)
	end
	local function onKey(_, st, input)
		local k = input.KeyCode
		if st == Enum.UserInputState.Begin then
			if k == Enum.KeyCode.Return or k == Enum.KeyCode.KeypadEnter then
				local p = bubble and bubble.Position
				local cb = onConfirm
				H.tpCancel()
				if p then
					if cb then pcall(cb) end
					tpTo(p)
				end
			elseif k == Enum.KeyCode.Backspace then
				H.tpCancel()
			else
				held[k] = true
			end
		elseif st == Enum.UserInputState.End or st == Enum.UserInputState.Cancel then
			held[k] = nil
		end
		return Enum.ContextActionResult.Sink
	end
	local function placeBubble(pos)
		if not bubble then
			bubble = Instance.new("Part")
			bubble.Name = "TSC_TP_Bubble"; bubble.Shape = Enum.PartType.Ball; bubble.Size = Vector3.new(2.2, 2.2, 2.2)
			bubble.Anchored = true; bubble.CanCollide = false; bubble.CanQuery = false; bubble.CanTouch = false
			bubble.Material = Enum.Material.ForceField; bubble.Color = T.accent; bubble.CastShadow = false
			bubble.Parent = workspace
			line = Instance.new("Part")
			line.Name = "TSC_TP_Line"; line.Anchored = true; line.CanCollide = false; line.CanQuery = false; line.CanTouch = false
			line.Material = Enum.Material.Neon; line.Color = T.accent; line.Transparency = 0.5; line.CastShadow = false
			line.Parent = workspace
			bb = Instance.new("BillboardGui")
			bb.AlwaysOnTop = true; bb.Size = UDim2.fromOffset(140, 18); bb.StudsOffset = Vector3.new(0, 2.2, 0); bb.Parent = bubble
			local l = Instance.new("TextLabel")
			l.Size = UDim2.fromScale(1, 1); l.BackgroundTransparency = 1; l.Font = Enum.Font.GothamBold; l.TextSize = 11
			l.TextColor3 = Color3.new(1, 1, 1); l.TextStrokeTransparency = 0.3; l.Parent = bb
			H.tpBubble = bubble
			H.tpRebind()
		end
		bubble.Position = pos
		-- Kamera auf die Blase (rotiert/zoomt normal um sie herum)
		local c = workspace.CurrentCamera
		if c then c.CameraSubject = bubble end
	end
	-- Z/H nur schlucken, wenn die Option an ist (sonst gehen sie normal ans Spiel)
	H.tpRebind = function()
		if not bubble then return end
		local keys = table.clone(KEYS)
		if state.tpZH then table.insert(keys, UP_ZH); table.insert(keys, DOWN_ZH) end
		pcall(function() CAS:UnbindAction("TSC_TP_BUBBLE") end)
		table.clear(held)
		CAS:BindActionAtPriority("TSC_TP_BUBBLE", onKey, false, 3000, table.unpack(keys))
	end
	-- Blase von außen setzen (z. B. Liam's Hideout): Gegend am Ziel nachladen lassen, damit man sich umsehen kann
	H.tpPlaceBubble = function(pos, cb)
		placeBubble(pos)
		onConfirm = cb
		task.spawn(function() pcall(function() lp:RequestStreamAroundAsync(pos, 5) end) end)
	end
	table.insert(H.conns, { Disconnect = function() H.tpCancel() end })

	con(UIS.InputBegan, function(i, gp)
		if gp or i.UserInputType ~= Enum.UserInputType.MouseButton1 or not state.clickTp then return end
		if not (UIS:IsKeyDown(Enum.KeyCode.LeftControl) or UIS:IsKeyDown(Enum.KeyCode.RightControl)) then return end
		local hit = mouseHit()
		if not hit then return end
		local pos = hit + Vector3.new(0, 3, 0) -- HRP steht ~3 Studs über dem Boden
		if state.tpDetail then placeBubble(pos) else tpTo(pos) end
	end)

	con(RunService.RenderStepped, function(dt)
		if not bubble then return end
		local f = cam.CFrame.LookVector; f = Vector3.new(f.X, 0, f.Z)
		f = f.Magnitude > 0 and f.Unit or Vector3.new(0, 0, -1)
		local r = Vector3.new(-f.Z, 0, f.X)
		local d = Vector3.zero
		if held[Enum.KeyCode.Up] then d = d + f end
		if held[Enum.KeyCode.Down] then d = d - f end
		if held[Enum.KeyCode.Right] then d = d + r end
		if held[Enum.KeyCode.Left] then d = d - r end
		if held[Enum.KeyCode.KeypadFour] or (state.tpZH and held[UP_ZH]) then d = d + Vector3.yAxis end
		if held[Enum.KeyCode.KeypadOne] or (state.tpZH and held[DOWN_ZH]) then d = d - Vector3.yAxis end
		if d.Magnitude > 0 then bubble.Position = bubble.Position + d.Unit * state.tpBubbleSpeed * dt end
		-- Lot zum Boden anzeigen
		params.FilterDescendantsInstances = { lp.Character, bubble, line }
		local g = workspace:Raycast(bubble.Position, Vector3.new(0, -500, 0), params)
		local h = g and (bubble.Position.Y - g.Position.Y) or 500
		line.Size = Vector3.new(0.12, math.max(h, 0.1), 0.12)
		line.CFrame = CFrame.new(bubble.Position - Vector3.new(0, h / 2, 0))
		local my = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
		bb.TextLabel.Text = ("%.0f studs away · %.0f above ground"):format(my and (bubble.Position - my.Position).Magnitude or 0, h)
	end)
end)()

-- ================= ANTI AFK =================
-- Ganz simpel: hat man 9 min lang KEINE Eingabe gemacht (Taste, Klick, Mausbewegung), kommt ein echter Mausklick.
-- Mit Tool in der Hand Rechtsklick statt Linksklick (sonst würde man schießen/schlagen). Nur wenn Roblox im Vordergrund ist.
-- Keine Remotes, kein VirtualUser, keine Roblox-Events angefasst — nur Eingaben mitzählen + echter Klick.
state.antiAfk = sv("antiAfk", true)
;(function()
	toggle(S_world, "Anti AFK (click after 9 min idle)", "antiAfk", function() end)
	local afkInfo = info(S_world, "")
	local IDLE = 9 * 60
	local lastInput, count = os.clock(), 0
	con(UIS.InputBegan, function() lastInput = os.clock() end)
	con(UIS.InputChanged, function(i) if i.UserInputType == Enum.UserInputType.MouseMovement then lastInput = os.clock() end end)
	task.spawn(function()
		while H.alive do
			task.wait(5)
			if state.antiAfk and os.clock() - lastInput >= IDLE and focused() then
				local tool = lp.Character and lp.Character:FindFirstChildOfClass("Tool")
				if tool and typeof(mouse2click) == "function" then mouse2click()
				elseif not tool and typeof(mouse1click) == "function" then mouse1click() end
				lastInput = os.clock()
				count = count + 1
				afkInfo.Text = ("clicked %d× (last %s)"):format(count, os.date("%H:%M"))
			end
		end
	end)
end)()

-- ================= BINGO =================
-- Bingo Card (Tool): das Server-Script BingoCardScript markiert gezogene Zahlen selbst -> Zelle TextColor3 = rot
-- (Mitte = rotes "X", Freifeld). Einlösen = mit der Karte in der Hand klicken (Tool.Activated -> Server prüft,
-- Payout 750 bzw. NoBingo-Sound). Hier: Linie (Reihe/Spalte/Diagonale) lokal aus den Zellfarben erkennen, melden und
-- optional per echtem Klick einlösen (Karte kurz ausrüsten, mouse1click, vorheriges Tool zurück). Keine Remotes.
state.bingoNotify = sv("bingoNotify", true); state.bingoAuto = sv("bingoAuto", false)
;(function()
	local S_bingo = section(miscR, "Bingo")
	toggle(S_bingo, "Notify On Bingo", "bingoNotify", function() end)
	toggle(S_bingo, "Auto Claim", "bingoAuto", function() end)
	local bInfo = info(S_bingo, "")
	info(S_bingo, "Needs a Bingo Card (150 credits, Bingo Guy). Auto Claim equips the card for a moment and clicks with it.")

	local function getCard()
		local c = lp.Character
		return (c and c:FindFirstChild("Bingo Card")) or lp.Backpack:FindFirstChild("Bingo Card")
	end
	local function isRed(l) local c = l.TextColor3 return c.R > 0.8 and c.G < 0.2 and c.B < 0.2 end
	-- 5x5-Raster aus den Bildschirm-/Surface-Positionen (LayoutOrder ist überall 0)
	local function readGrid(card)
		local fr = card:FindFirstChild("Handle") and card.Handle:FindFirstChild("SurfaceGui") and card.Handle.SurfaceGui:FindFirstChild("Frame")
		if not fr then return end
		local cells = {}
		for _, l in ipairs(fr:GetChildren()) do if l:IsA("TextLabel") then cells[#cells + 1] = l end end
		if #cells ~= 25 then return end
		table.sort(cells, function(a, b)
			local ay, by = math.floor(a.AbsolutePosition.Y + 0.5), math.floor(b.AbsolutePosition.Y + 0.5)
			if ay ~= by then return ay < by end
			return a.AbsolutePosition.X < b.AbsolutePosition.X
		end)
		local g, marked = {}, 0
		for i, l in ipairs(cells) do
			local r, c = math.floor((i - 1) / 5) + 1, (i - 1) % 5 + 1
			g[r] = g[r] or {}
			g[r][c] = isRed(l)
			if g[r][c] then marked = marked + 1 end
		end
		return g, marked
	end
	local function findLine(g)
		for r = 1, 5 do local ok = true for c = 1, 5 do ok = ok and g[r][c] end if ok then return "row " .. r end end
		for c = 1, 5 do local ok = true for r = 1, 5 do ok = ok and g[r][c] end if ok then return "column " .. c end end
		local d1, d2 = true, true
		for i = 1, 5 do d1 = d1 and g[i][i]; d2 = d2 and g[i][6 - i] end
		if d1 then return "diagonal" end
		if d2 then return "diagonal" end
	end

	local claiming, lastClaim, notified = false, 0, nil
	local function claim(card)
		if claiming or os.clock() - lastClaim < 8 then return end
		local c = lp.Character
		local hum = c and c:FindFirstChildOfClass("Humanoid")
		if not (hum and hum.Health > 0) or not focused() or UIS:GetFocusedTextBox() or c:GetAttribute("Down") then return end
		if typeof(mouse1click) ~= "function" then bInfo.Text = "Status: mouse1click missing" return end
		claiming = true
		task.spawn(function()
			local prev = c:FindFirstChildOfClass("Tool")
			if prev ~= card then hum:EquipTool(card); task.wait(0.35) end
			-- Klick nur, wenn die Maus nicht über dem Hub-Menü liegt (sonst schluckt die GUI den Klick)
			local t0 = os.clock()
			while main.Visible and os.clock() - t0 < 3 do task.wait(0.1) end
			if card.Parent == c then
				mouse1click()
				lastClaim = os.clock()
				bInfo.Text = '<font color="#d266b4">Status: claimed (clicked)</font>'
				task.wait(0.6)
			end
			if prev and prev ~= card and prev.Parent == lp.Backpack then hum:EquipTool(prev)
			elseif not prev and card.Parent == c then hum:UnequipTools() end
			claiming = false
		end)
	end

	task.spawn(function()
		while H.alive do
			local card = getCard()
			if not card then
				bInfo.Text = (state.bingoNotify or state.bingoAuto) and "Status: no Bingo Card" or ""
				notified = nil
			else
				local g, marked = readGrid(card)
				local line = g and findLine(g)
				if line then
					bInfo.Text = ('<font color="#78ff8c">BINGO!</font> %s · %d marked'):format(line, marked)
					if state.bingoNotify and notified ~= card then
						notified = card
						pcall(function()
							game:GetService("StarterGui"):SetCore("SendNotification", { Title = "RSC Hub", Text = "BINGO! Claim now (" .. line .. ")", Duration = 8 })
						end)
					end
					if state.bingoAuto then claim(card) end
				else
					notified = nil
					if g then bInfo.Text = ("Status: no bingo yet · %d/25 marked"):format(marked) end
				end
			end
			task.wait(0.5)
		end
	end)
end)()

-- ================= DAMAGE ZONES =================
-- 63 unsichtbare Parts in der Map (Transparency=1) mit Attribut `Damage` (10–20 harmlos, 120, bis 9999/50000 =
-- Instant-Kill) und `Debounce` (Sekunden zwischen Treffern), z. B. Map.S2_OpenArea.zapper. Schaden laeuft ueber
-- Touch, und Touches des eigenen (client-owned) Characters meldet der CLIENT -> CanTouch=false lokal = kein Touch
-- = kein Schaden. CanCollide bleibt unberuehrt, damit man nicht durch den Boden faellt. Alles reversibel.
-- Sichtbarmachen ist rein lokal (Transparency/Color an server-eigenen Parts repliziert nicht).
state.dmgOff = sv("dmgOff", false)
state.dmgShow = sv("dmgShow", false)
;(function()
	local S_dz = section(visR, "Damage Zones")
	local touched = {}   -- [part] = originales CanTouch
	local shown = {}     -- [part] = {Transparency, Color, Material}
	local seen = {}      -- [part] = true

	local function isDmg(d) return d:IsA("BasePart") and d:GetAttribute("Damage") ~= nil end
	local function colFor(dmg)
		if dmg >= 1000 then return Color3.fromRGB(255, 0, 60) end      -- Instant-Kill
		if dmg >= 100 then return Color3.fromRGB(255, 110, 0) end      -- schwer
		if dmg >= 40 then return Color3.fromRGB(255, 200, 0) end       -- mittel
		return Color3.fromRGB(120, 200, 255)                            -- leicht
	end
	local function applyOne(d)
		local dmg = tonumber(d:GetAttribute("Damage")) or 0
		if state.dmgOff then
			if touched[d] == nil then touched[d] = d.CanTouch end
			if d.CanTouch then d.CanTouch = false end
		elseif touched[d] ~= nil then
			d.CanTouch = touched[d]; touched[d] = nil
		end
		if state.dmgShow then
			if shown[d] == nil then shown[d] = { d.Transparency, d.Color, d.Material } end
			d.Transparency = 0.55
			d.Color = colFor(dmg)
			d.Material = Enum.Material.Neon
		elseif shown[d] ~= nil then
			local o = shown[d]
			d.Transparency, d.Color, d.Material = o[1], o[2], o[3]
			shown[d] = nil
		end
	end
	-- Voller Workspace-Scan (~110k Instanzen, ~65 ms) nur EINMAL und in Chunks; danach haelt DescendantAdded
	-- `seen` aktuell. Vorher lief der Scan alle 2 s am Stueck = periodischer ~80-ms-Ruckler.
	local scanned = false
	local function fullScan()
		if scanned then return end
		scanned = true
		local all = workspace:GetDescendants()
		for i = 1, #all do
			local d = all[i]
			if isDmg(d) then seen[d] = true end
			if i % 4000 == 0 then task.wait() end
		end
	end
	local function sweep()
		fullScan()
		for d in pairs(seen) do if d.Parent then pcall(applyOne, d) end end
	end
	local function restoreAll()
		for d in pairs(touched) do if d.Parent then pcall(function() d.CanTouch = touched[d] end) end end
		touched = {}
		for d, o in pairs(shown) do
			if d.Parent then pcall(function() d.Transparency, d.Color, d.Material = o[1], o[2], o[3] end) end
		end
		shown = {}
	end

	toggle(S_dz, "No Damage (local)", "dmgOff", function() task.spawn(pcall, sweep) end)
	toggle(S_dz, "Show Damage Zones", "dmgShow", function() task.spawn(pcall, sweep) end)
	local dzInfo = info(S_dz, "")
	info(S_dz, '<font color="#ff003c">red = instant kill</font> · <font color="#ff6e00">orange</font> · <font color="#ffc800">yellow</font> · <font color="#78c8ff">light</font>  — these parts are invisible in the game; collision is left alone.')

	-- neu gestreamte Zonen mitnehmen
	con(workspace.DescendantAdded, function(d)
		if not isDmg(d) then return end
		seen[d] = true
		if state.dmgOff or state.dmgShow then task.defer(function() pcall(applyOne, d) end) end
	end)

	task.spawn(function()
		while H.alive do
			if state.dmgOff or state.dmgShow then
				pcall(sweep)
				local n, lethal, near, nd = 0, 0, nil, math.huge
				local my = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
				for d in pairs(seen) do
					if d.Parent then
						n = n + 1
						local dmg = tonumber(d:GetAttribute("Damage")) or 0
						if dmg >= 1000 then lethal = lethal + 1 end
						if my then
							local dist = (d.Position - my.Position).Magnitude
							if dist < nd then nd = dist; near = dmg end
						end
					else
						seen[d] = nil; touched[d] = nil; shown[d] = nil
					end
				end
				dzInfo.Text = ('%d zones loaded (%d lethal)%s%s'):format(n, lethal,
					near and ('  ·  nearest: ' .. math.floor(nd) .. 'm dmg ' .. near) or "",
					state.dmgOff and '  ·  <font color="#78ff8c">disarmed</font>' or "")
			elseif dzInfo.Text ~= "" then
				dzInfo.Text = ""
				restoreAll()
			end
			task.wait(2)
		end
	end)
	table.insert(H.conns, { Disconnect = function() pcall(restoreAll) end })
end)()
-- ================= INFECTION SOURCES =================
-- Infektion laeuft serverseitig: Character.InfectedValues.InfectionLevel steigt bis MaxInfectionValue (100), dann
-- wird man ins Infected-Team gesetzt. Zwei Quellen: Pfuetzen (Instanz mit Attribut InfectAmount + InfectedType;
-- Vorlagen in workspace.InfectedPuddles, echte entstehen an MessNodes mit AllowsInfected=true) und Treffer von
-- Infizierten (Feld LastHit). Der InfectedType der Quelle bestimmt, WAS man wird und damit welche Faehigkeiten.
-- Rein lesend: Attribute + replizierte Werte, keine Remotes, keine Hooks. Suche ist ereignisgesteuert
-- (DescendantAdded) statt per Dauerscan ueber ~120k Instanzen.
state.infEsp = sv("infEsp", false)
;(function()
	local S_inf = section(visL, "Infection Sources")
	local puddles = {}   -- [instance] = true
	local marks = {}     -- [instance] = {bb=, lbl=, hl=}
	toggle(S_inf, "Show Infection Sources", "infEsp", function(on)
		if not on then for _, o in pairs(marks) do pcall(function() o.bb:Destroy() end) end end
	end)
	local meInfo = info(S_inf, "")
	local pudInfo = info(S_inf, "")
	local srcInfo = info(S_inf, "")

	local function isPuddle(d)
		return d:GetAttribute("InfectAmount") ~= nil and not (workspace:FindFirstChild("InfectedPuddles") and d:IsDescendantOf(workspace.InfectedPuddles))
	end
	local function partOf(d)
		if d:IsA("BasePart") then return d end
		return d:FindFirstChildWhichIsA("BasePart")
	end
	-- Startsuche einmalig, danach nur noch per Ereignis
	for _, d in ipairs(workspace:GetDescendants()) do if isPuddle(d) then puddles[d] = true end end
	con(workspace.DescendantAdded, function(d)
		task.defer(function() if d.Parent and isPuddle(d) then puddles[d] = true end end)
	end)

	local function clearMark(d)
		local o = marks[d]
		if o then pcall(function() o.bb:Destroy() end) pcall(function() o.hl:Destroy() end) marks[d] = nil end
	end

	task.spawn(function()
		while H.alive do
			if state.infEsp then
				local c = lp.Character
				local iv = c and (c:FindFirstChild("InfectedValues") or c:FindFirstChild("LatexValues"))
				local my = c and c:FindFirstChild("HumanoidRootPart")
				-- eigener Zustand
				local lvl, max, spore, full = 0, 100, 1, false
				if iv then
					local function gv(n, d) local o = iv:FindFirstChild(n) return o and o.Value or d end
					lvl, max, spore, full = gv("InfectionLevel", 0), gv("MaxInfectionValue", 100), gv("SporeImmunity", 1), gv("FullImmunity", false)
					meInfo.Text = ('you: <font color="%s">%d / %d</font>  ·  spore immunity %s%s'):format(
						lvl > 0 and "#ffc800" or "#78ff8c", lvl, max, tostring(spore), full and '  ·  <font color="#78ff8c">FULL IMMUNITY</font>' or "")
				else
					meInfo.Text = "no InfectedValues on your character"
				end
				-- Pfuetzen
				local lines, n = {}, 0
				for d in pairs(puddles) do
					if d.Parent then
						local part = partOf(d)
						local amt = tonumber(d:GetAttribute("InfectAmount")) or 0
						local typ = tostring(d:GetAttribute("InfectedType") or "?")
						local eff = amt * (tonumber(spore) or 1)
						local need = eff > 0 and math.max(1, math.ceil((max - lvl) / eff)) or 0
						local dist = (part and my) and math.floor((part.Position - my.Position).Magnitude) or -1
						n = n + 1
						if #lines < 8 then
							lines[#lines + 1] = ('<font color="#c8a0ff">%s</font> %s  amount %d  ·  %d contact%s'):format(
								typ, dist >= 0 and (dist .. "m") or "?", amt, need, need == 1 and "" or "s")
						end
						if part then
							local o = marks[d]
							if not o then
								local bb = Instance.new("BillboardGui")
								bb.AlwaysOnTop = true; bb.Size = UDim2.fromOffset(220, 30); bb.StudsOffset = Vector3.new(0, 2.5, 0)
								bb.LightInfluence = 0; bb.Adornee = part; bb.Parent = gui
								local l = Instance.new("TextLabel")
								l.Size = UDim2.fromScale(1, 1); l.BackgroundTransparency = 1; l.Font = Enum.Font.GothamBold
								l.TextSize = 13; l.TextColor3 = Color3.fromRGB(200, 160, 255); l.TextStrokeTransparency = 0.25; l.Parent = bb
								local hl = Instance.new("Highlight")
								hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop; hl.FillColor = Color3.fromRGB(180, 120, 255)
								hl.FillTransparency = 0.5; hl.OutlineColor = Color3.fromRGB(230, 200, 255); hl.Parent = gui
								hl.Adornee = d:IsA("Model") and d or part
								o = { bb = bb, lbl = l, hl = hl }
								marks[d] = o
							end
							o.lbl.Text = ("%s  %d contact%s"):format(typ, need, need == 1 and "" or "s")
						end
					else
						puddles[d] = nil; clearMark(d)
					end
				end
				pudInfo.Text = n > 0 and table.concat(lines, "\n") or "no infection puddles in the world right now"
				-- Infizierte in der Naehe (zweite Quelle: sich schlagen lassen)
				local Check = nil
				local okm, mod = pcall(require, game:GetService("ReplicatedStorage").Modules.InfectedCheckModule)
				if okm then Check = mod end
				local near = {}
				if Check and my then
					for _, p in ipairs(Players:GetPlayers()) do
						if p ~= lp then
							local pc = p.Character
							local pr = pc and pc:FindFirstChild("HumanoidRootPart")
							if pr and pc:IsDescendantOf(workspace) then
								local ok2, isInf = pcall(Check, p)
								if ok2 and isInf then
									local pv = pc:FindFirstChild("InfectedValues") or pc:FindFirstChild("LatexValues")
									local t = pv and (pv:FindFirstChild("InfectedType") or pv:FindFirstChild("LatexType"))
									near[#near + 1] = { (pr.Position - my.Position).Magnitude, p.Name, t and tostring(t.Value) or "?" }
								end
							end
						end
					end
				end
				table.sort(near, function(a, b) return a[1] < b[1] end)
				local nl = {}
				for i = 1, math.min(#near, 5) do
					nl[#nl + 1] = ('<font color="#ff8fb0">%s</font> %dm  %s'):format(near[i][2], math.floor(near[i][1]), near[i][3])
				end
				srcInfo.Text = #nl > 0 and ("infected nearby:\n" .. table.concat(nl, "\n")) or "no infected loaded nearby"
			elseif meInfo.Text ~= "" then
				meInfo.Text = ""; pudInfo.Text = ""; srcInfo.Text = ""
				for d in pairs(marks) do clearMark(d) end
			end
			task.wait(1)
		end
	end)
	table.insert(H.conns, { Disconnect = function() for d in pairs(marks) do clearMark(d) end end })
end)()
-- ================= VIEW (SPECTATE) =================
-- Modifier-Taste (Standard B) halten + Linksklick: der Spieler, dessen Bildschirmposition dem Mauszeiger am naechsten
-- ist, wird angesehen. Es zaehlt NUR der Pixelabstand zur Maus — keine Wandpruefung, keine Entfernungsgrenze.
-- Gleicher Spieler nochmal oder Taste + Rechtsklick = zurueck zu mir. Der Klick wird geschluckt (ContextActionService),
-- damit man beim Zielen nicht schiesst/zuschlaegt.
-- Umsetzung: lokales Anker-Teil als Camera.CameraSubject. Damit macht die Roblox-Kamera Drehen/Zoomen selbst und es
-- klappt auch, wenn der Ziel-Character rausgestreamt ist (Anker haengt dann an der letzten bekannten Position aus
-- lastSeen). Sobald der echte Character da ist, wird direkt auf dessen Humanoid umgeschaltet.
-- Keine Remotes ausser dem spieleigenen ContentStreaming.RequestStreamAround (das feuert das Spiel selbst im Menue).
state.view = sv("view", false)
;(function()
	local CAS = game:GetService("ContextActionService")
	local RSto = game:GetService("ReplicatedStorage")
	state.keys.view = kc(sv("keyView", "B"), Enum.KeyCode.B)
	local S_view = section(plL, "View (Spectate)")
	toggle(S_view, "Key + Click View", "view", function(on) if not on then H.viewStop() end end, "view")
	local viewInfo = info(S_view, "Viewing: -", T.accent)
	info(S_view, "Hold the key and left-click: the player nearest to your mouse on screen gets viewed — walls and distance are ignored. Same player again or key + right-click goes back to you.")
	button(S_view, "Back to me", function() H.viewStop() end)

	local ov = Instance.new("TextLabel")
	ov.AnchorPoint = Vector2.new(0.5, 0); ov.Position = UDim2.new(0.5, 0, 0, 84); ov.Size = UDim2.fromOffset(430, 0)
	ov.AutomaticSize = Enum.AutomaticSize.Y; ov.BackgroundColor3 = Color3.fromRGB(10, 10, 12); ov.BackgroundTransparency = 0.35
	ov.Font = Enum.Font.GothamBold; ov.TextSize = 14; ov.TextColor3 = T.accent
	ov.TextWrapped = true; ov.Visible = false; ov.Parent = gui
	Instance.new("UICorner", ov).CornerRadius = UDim.new(0, 4)
	local vpad = Instance.new("UIPadding", ov); vpad.PaddingLeft = UDim.new(0, 8); vpad.PaddingRight = UDim.new(0, 8)
	vpad.PaddingTop = UDim.new(0, 4); vpad.PaddingBottom = UDim.new(0, 4)
	H.movable(ov, "viewPos")

	local selfHL = Instance.new("Highlight")
	selfHL.Name = "TSC_VIEW_SELF"; selfHL.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	selfHL.FillColor = Color3.fromRGB(80, 170, 255); selfHL.FillTransparency = 0.5
	selfHL.OutlineColor = Color3.fromRGB(150, 220, 255); selfHL.OutlineTransparency = 0
	selfHL.Enabled = false; selfHL.Parent = gui
	local selfBB = Instance.new("BillboardGui")
	selfBB.AlwaysOnTop = true; selfBB.Size = UDim2.fromOffset(170, 20); selfBB.StudsOffset = Vector3.new(0, 3.2, 0)
	selfBB.LightInfluence = 0; selfBB.Enabled = false; selfBB.Parent = espFolder
	local selfLbl = Instance.new("TextLabel")
	selfLbl.Size = UDim2.fromScale(1, 1); selfLbl.BackgroundTransparency = 1; selfLbl.Font = Enum.Font.GothamBlack
	selfLbl.TextSize = 13; selfLbl.TextColor3 = Color3.fromRGB(150, 220, 255); selfLbl.TextStrokeTransparency = 0.25
	selfLbl.Parent = selfBB
	local function selfMark(on)
		local c = lp.Character
		local r = c and c:FindFirstChild("HumanoidRootPart")
		selfHL.Adornee = on and c or nil
		selfHL.Enabled = on and c ~= nil
		selfBB.Adornee = on and r or nil
		selfBB.Enabled = on and r ~= nil
	end

	local target, anchor, lastReq = nil, nil, 0

	-- Position: live aus dem Character, sonst letzte bekannte (lastSeen wird oben mit 2 Hz gefuellt)
	local function posOf(p)
		local c = p.Character
		local r = c and (c:FindFirstChild("HumanoidRootPart") or c:FindFirstChild("Head") or c.PrimaryPart)
		if r and c:IsDescendantOf(workspace) then return r.Position, true, c end
		local ls = lastSeen[p.UserId]
		return ls and ls.pos or nil, false, nil
	end

	function H.viewStop()
		target = nil
		local c = lp.Character
		local hum = c and c:FindFirstChildOfClass("Humanoid")
		if hum then cam.CameraSubject = hum end
		if anchor then pcall(function() anchor:Destroy() end); anchor = nil end
		selfMark(false)
		ov.Visible = false
		viewInfo.Text = "Viewing: -"
	end

	local function viewStart(p)
		local pos = posOf(p)
		if not anchor then
			anchor = Instance.new("Part")
			anchor.Name = "TSC_VIEW_ANCHOR"; anchor.Anchored = true; anchor.CanCollide = false
			anchor.CanQuery = false; anchor.CanTouch = false; anchor.Transparency = 1
			anchor.Size = Vector3.new(1, 1, 1); anchor.CastShadow = false; anchor.Parent = workspace
		end
		if pos then anchor.CFrame = CFrame.new(pos) end
		target = p
		cam.CameraSubject = anchor
		selfMark(true)
		ov.Visible = true
	end

	-- kleinster Pixelabstand zur Maus; sp.Z > 0 = vor der Kamera (dahinter ist die Projektion sinnlos)
	local function nearestToMouse()
		local m = UIS:GetMouseLocation()
		local best, bestD
		for _, p in ipairs(Players:GetPlayers()) do
			if p ~= lp then
				local pos = posOf(p)
				if pos then
					local sp = cam:WorldToViewportPoint(pos + Vector3.new(0, 2, 0))
					if sp.Z > 0 then
						local d = (Vector2.new(sp.X, sp.Y) - Vector2.new(m.X, m.Y)).Magnitude
						if not bestD or d < bestD then best, bestD = p, d end
					end
				end
			end
		end
		return best, bestD
	end

	local function onClick(_, st, input)
		if st ~= Enum.UserInputState.Begin or not state.view then return Enum.ContextActionResult.Pass end
		if not keyHeld(state.keys.view) then return Enum.ContextActionResult.Pass end
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			H.viewStop()
			return Enum.ContextActionResult.Sink
		end
		local p = nearestToMouse()
		if not p then
			viewInfo.Text = "Viewing: - (no player on screen)"
		elseif p == target then
			H.viewStop()
		else
			viewStart(p)
		end
		return Enum.ContextActionResult.Sink
	end
	CAS:BindActionAtPriority("TSC_VIEW_PICK", onClick, false, 2900,
		Enum.UserInputType.MouseButton1, Enum.UserInputType.MouseButton2)
	table.insert(H.conns, { Disconnect = function()
		pcall(function() CAS:UnbindAction("TSC_VIEW_PICK") end)
		pcall(function() H.viewStop() end)
	end })

	con(Players.PlayerRemoving, function(p) if p == target then H.viewStop() end end)
	con(lp.CharacterAdded, function() if target then H.viewStop() end end) -- eigener Respawn: zurueck zu mir

	con(RunService.RenderStepped, function()
		if not target then return end
		if not target.Parent or not state.view then H.viewStop() return end
		local pos, live, c = posOf(target)
		if pos and anchor then anchor.CFrame = CFrame.new(pos + Vector3.new(0, live and 1.5 or 0, 0)) end
		if live and c then
			local hum = c:FindFirstChildOfClass("Humanoid")
			if hum and cam.CameraSubject ~= hum then cam.CameraSubject = hum end
		elseif anchor and cam.CameraSubject ~= anchor then
			cam.CameraSubject = anchor
		end
		local myRoot = rootOf(lp)
		local d = (myRoot and pos) and math.floor((pos - myRoot.Position).Magnitude) or nil
		if myRoot and selfBB.Adornee ~= myRoot then selfMark(true) end
		selfLbl.Text = d and ("YOU  %dm from target"):format(d) or "YOU"
		ov.Text = ("VIEW  %s%s%s   ·   %s + right-click = back"):format(target.DisplayName,
			d and ("  ·  " .. d .. "m") or "",
			live and "" or "  ·  out of stream range (last known position)", keyName(state.keys.view))
		viewInfo.Text = "Viewing: " .. target.Name .. (live and "" or " (stale)")
		-- weit weg: Streaming anfordern, damit der Character wirklich sichtbar wird (max 1x/s)
		if not live and pos and os.clock() - lastReq > 1 then
			lastReq = os.clock()
			task.spawn(function() pcall(function() lp:RequestStreamAroundAsync(pos, 1) end) end)
			local cs = RSto:FindFirstChild("Remotes") and RSto.Remotes:FindFirstChild("ContentStreaming")
			local ra = cs and cs:FindFirstChild("RequestStreamAround")
			if ra then pcall(function() ra:FireServer(pos) end) end
		end
	end)
end)()

-- ================= SILENT STEPS =================
-- Schrittgeraeusche entstehen NICHT auf dem Server: PlayerScripts.FrameworkActor.FrameworkClient.Playerstates
-- registriert pro Character einen Listener auf Humanoid.AnimationPlayed und haengt sich an
-- track:GetMarkerReachedSignal("footstep"). Jeder Zuhoerer klont dann selbst einen Sound aus
-- ReplicatedStorage.Sounds.Footsteps[<Material>] in den Torso (nur <= 120 Studs von seiner Kamera).
-- Heisst: laeuft bei MIR keine Lauf-Animation, kann kein fremder Client einen Schritt-Marker erreichen
-- -> niemand hoert mich, und niemand sieht die Laufanimation. Rein lokal, kein Remote, kein Hook.
-- Cloak deckt den Ton NICHT ab (im Cloak-Script gibt es keine Sound-Behandlung), darum dieses Feature.
-- Betroffene Animationen (aus Modules.Animations.Backtrack): walk, run, panicrun, crouch, crawl, gunwalk, climb.
-- Schritt-Tracks werden per Stop(0) beendet (fuer andere: gleitet ohne Laufanimation) und jeden Frame vor dem
-- Animations-Schritt nachkontrolliert.
state.silentStep = sv("silentStep", false); state.silentStepCloak = sv("silentStepCloak", false)
;(function()
	local RSss = game:GetService("ReplicatedStorage")
	local STEP, nStep = {}, 0
	do
		local ok, A = pcall(require, RSss.Modules.Animations)
		if ok and type(A) == "table" and type(A.Backtrack) == "table" then
			local want = { walk = true, run = true, panicrun = true, crouch = true, crawl = true, gunwalk = true, climb = true }
			for id, nm in pairs(A.Backtrack) do if want[nm] then STEP[id] = nm; nStep = nStep + 1 end end
		end
	end

	local S_ss = section(miscL, "Silent Steps")
	toggle(S_ss, "Silent Steps", "silentStep", function() end)
	toggle(S_ss, "Only while cloaked", "silentStepCloak", function() end)
	local ssInfo = info(S_ss, "")
	info(S_ss, "Footsteps are produced by every listener's own client from your walk animation. No walk animation = nobody can hear you. Cloak alone does not silence steps.")

	local killed = 0
	-- cloaked: NameHidden ist der serverseitige Tarn-Marker (siehe Cloak-Recon 27.09.)
	local function cloaked()
		local c = lp.Character
		if not c then return false end
		if H.cloakActive or c:GetAttribute("NameHidden") == true then return true end
		local t = c:FindFirstChild("Torso")
		return (t and t.Transparency >= 0.99) or false
	end
	local function active()
		if not state.silentStep then return false end
		if state.silentStepCloak and not cloaked() then return false end
		return true
	end

	-- Immer Stop(0), nie einfrieren: das Framework setzt jeden Frame (RenderStepped) per SetAnimationSpeed ->
	-- CoreAnimationTrack:AdjustSpeed(x) das Tempo neu, ein Speed-0-Freeze wurde dadurch sofort aufgehoben und die
	-- Schritt-Marker liefen wieder. Ein gestoppter Track bleibt gestoppt (Framework spielt ihn erst beim naechsten
	-- Animationswechsel neu -> AnimationPlayed -> sofort wieder Stop, gleicher Frame, repliziert nie als "laeuft").
	local function suppress(tr, counted)
		local a = tr.Animation
		if not a or not STEP[a.AnimationId] then return end
		if counted then killed = killed + 1 end
		pcall(function() tr:Stop(0) end)
	end

	local animConn
	local function hook(c)
		if animConn then pcall(function() animConn:Disconnect() end); animConn = nil end
		local hum = c and c:FindFirstChildOfClass("Humanoid")
		if not hum then return end
		animConn = hum.AnimationPlayed:Connect(function(tr) if active() then suppress(tr, true) end end)
		table.insert(H.conns, animConn)
	end
	hook(lp.Character)
	con(lp.CharacterAdded, function(c) task.wait(0.2); hook(c) end)

	-- jeden Frame vor dem Animations-Schritt: laufende Schritt-Tracks stoppen (faengt auch alles ab, was
	-- AnimationPlayed verpasst, z. B. schon laufende Tracks beim Einschalten oder beim Cloak-Start)
	local RunSvc = game:GetService("RunService")
	local ok, preAnim = pcall(function() return RunSvc.PreAnimation end)
	con((ok and preAnim) or RunSvc.Stepped, function()
		if not active() then return end
		local c = lp.Character
		local hum = c and c:FindFirstChildOfClass("Humanoid")
		local an = hum and hum:FindFirstChildOfClass("Animator")
		if not an then return end
		for _, tr in ipairs(an:GetPlayingAnimationTracks()) do
			if tr.Animation and STEP[tr.Animation.AnimationId] then suppress(tr, false) end
		end
	end)
	-- Zustandsanzeige
	task.spawn(function()
		while H.alive do
			ssInfo.Text = ("%s · %d step anims known · %d suppressed · cloaked: %s"):format(
				active() and "ACTIVE" or (state.silentStep and "waiting for cloak" or "off"),
				nStep, killed, cloaked() and "yes" or "no")
			task.wait(0.25)
		end
	end)
end)()

-- ================= COMMAND EFFECTS =================
-- Warum der Adonis-Monitor NICHT alle Befehle sieht: Admins tippen sie meist nicht in den Chat, sondern in Adonis'
-- eigene Befehlsleiste. Die geht direkt von IHREM Client an den Server — fremde Client->Server-Pakete sind fuer uns
-- prinzipiell unsichtbar, und Chat-Befehle filtert Adonis vor dem Verteilen raus. Wir sehen also nur, was der Server
-- an UNS zurueckschickt (Hints/Messages/Notifications) — der Rest kommt nie bei uns an.
-- Was aber immer ankommt, sind die WIRKUNGEN, weil das normale Replikation ist: Team,
-- hohe WalkSpeed, ForceField/Sparkles/Fire/Smoke am Character, grosse Positionssprünge, Verlassen des Servers.
-- Alles ereignisgesteuert (nur der Teleport-Check pollt mit 4 Hz ueber lebende Characters), Ausgabe in denselben
-- Adonis-Log (Tab + Overlay + tsc_adonis_log.txt).
state.cmdFx = sv("cmdFx", true)
;(function()
	local S_fx = section(plR, "Command Effects")
	toggle(S_fx, "Detect Command Effects", "cmdFx", function() end)
	local fxInfo = info(S_fx, "")
	info(S_fx, "Admins use Adonis' command bar, not chat — their packets never reach us. This watches the visible effects instead: team change, sparkles/fire/smoke, health/speed changes, teleports over 150 studs.")

	local n = 0
	local function say(who, what, hot)
		n = n + 1
		if H.adLog then H.adLog("EFFECT", ("%s  ->  %s"):format(who, what), hot ~= false) end
	end
	local function nameOf(pl) return pl.Name .. (pl.Team and (" [" .. pl.Team.Name .. "]") or "") end

	local FX = { Sparkles = true, Fire = true, Smoke = true, SelectionBox = true, ParticleEmitter = true }
	local lastDeath, lastTeam = {}, {}
	local spawnAt = {} -- Zeitpunkt des letzten Character-Spawns (Spawnschutz-Filter)
	-- Spieler im Spawn-Menue spawnen dauernd neu -> komplett ignorieren
	local function ignored(pl) return (pl.Team and pl.Team.Name == "Menu") or false end
	local function fresh(pl, sec) local t = spawnAt[pl.UserId] return t ~= nil and os.clock() - t < sec end

	local function hookHumanoid(pl, c, hum)
		if not hum then return end
		con(hum.Died, function() lastDeath[pl.UserId] = os.clock() end)
		-- WalkSpeed: das Spiel selbst geht bis ~32 (PanicRun). Erst darueber ist es ein Befehl.
		con(hum:GetPropertyChangedSignal("WalkSpeed"), function()
				if state.cmdFx and not ignored(pl) and hum.WalkSpeed > 40 then say(nameOf(pl), ("WalkSpeed %.0f (:speed?)"):format(hum.WalkSpeed)) end
		end)
		con(hum:GetPropertyChangedSignal("JumpPower"), function()
			if state.cmdFx and not ignored(pl) and hum.JumpPower > 60 then say(nameOf(pl), ("JumpPower %.0f (:jumppower?)"):format(hum.JumpPower)) end
		end)
	end

	local function hookChar(pl, c)
		-- Respawn ohne vorherigen Tod = :respawn / :reset durch einen Admin
		-- Respawn-Erkennung bewusst entfernt (User 28.09.): das Spiel spawnt Characters zu unregelmaessig neu,
		-- daraus laesst sich kein :respawn ableiten. lastDeath bleibt nur fuer den Teleport-Filter.
		lastDeath[pl.UserId] = nil
		spawnAt[pl.UserId] = os.clock()
		hookHumanoid(pl, c, c:FindFirstChildOfClass("Humanoid"))
		con(c.ChildAdded, function(ch)
			-- ForceField & Co. in den ersten Sekunden nach dem Spawn = Spawnschutz des Spiels
			if state.cmdFx and FX[ch.ClassName] and not ignored(pl) and not fresh(pl, 8) then
				say(nameOf(pl), ch.ClassName .. " added (:" .. ch.ClassName:lower() .. "?)")
			end
		end)
	end

	local function hookPlayer(pl)
		lastTeam[pl.UserId] = pl.Team and pl.Team.Name or "-"
		con(pl:GetPropertyChangedSignal("Team"), function()
			local new = pl.Team and pl.Team.Name or "-"
			local old = lastTeam[pl.UserId] or "-"
			lastTeam[pl.UserId] = new
			if state.cmdFx and new ~= old and old ~= "Menu" and new ~= "Menu" then
				say(pl.Name, ("team %s -> %s"):format(old, new), false)
			end
		end)
		if pl.Character then hookChar(pl, pl.Character) end
		con(pl.CharacterAdded, function(c) task.wait(0.3) hookChar(pl, c) end)
	end
	for _, pl in ipairs(Players:GetPlayers()) do if pl ~= lp then hookPlayer(pl) end end
	con(Players.PlayerAdded, hookPlayer)
	con(Players.PlayerRemoving, function(pl)
		-- "left the server" bewusst entfernt (User 28.09.): normales Verlassen ist nicht von Kick/Ban zu trennen
		lastDeath[pl.UserId] = nil; lastTeam[pl.UserId] = nil; spawnAt[pl.UserId] = nil
	end)
	if lp.Character then hookChar(lp, lp.Character) end
	con(lp.CharacterAdded, function(c) task.wait(0.3) hookChar(lp, c) end)

	-- reine Anzeige; Positions-Poll entfaellt, seit die Teleport-Erkennung raus ist -> alles ereignisgesteuert
	task.spawn(function()
		while H.alive do
			fxInfo.Text = ("%s · %d effects logged"):format(state.cmdFx and "watching" or "off", n)
			task.wait(0.5)
		end
	end)
end)()

-- ================= SENSE RANGE (RAH / RECON) =================
-- Warnkreis um jeden Spieler im Team RAH oder Recontainment Unit. Hintergrund: der Light Specimen hat in
-- PlayerGui.InfectedUI.ClientSide einen "Hivemind"-Loop, der jeden Spieler im Umkreis von GENAU 300 Studs mit einem
-- Highlight versieht (DepthMode AlwaysOnTop, also durch Waende) und nach InfectedCheckModule einfaerbt: rot =
-- infiziert, gruen = ebenfalls LightInfected, weiss = nicht infiziert. Das laeuft im Client des Specimen, ist von
-- aussen nicht abschaltbar -- man kann nur wissen, wann man drin ist. Genau das macht dieses Feature.
-- 300 ist der gemessene Hivemind-Radius; fuer RAH/RECON allgemein ist keine Reichweite bestaetigt, der Ring zeigt
-- also diese Referenzdistanz (per Slider aenderbar).
-- Die Kugel ist ein lokales ForceField-Teil (fuer andere unsichtbar, kein Remote, keine Kollision). Nur die 3
-- naechsten Traeger bekommen eine, Update 5 Hz, damit nichts ruckelt. Ziel-Position notfalls aus lastSeen.
state.senseWarn = sv("senseWarn", false); state.senseRange = sv("senseRange", 300); state.senseRings = sv("senseRings", true)
state.senseOverlay = sv("senseOverlay", false); state.senseOnlyInf = sv("senseOnlyInf", false)
;(function()
	local TEAMS = { RAH = true, ["Recontainment Unit"] = true }
	local MAXRINGS = 3

	local S_sr = section(visR, "RAH / RECON Range")
	local ov = Instance.new("TextLabel")
	ov.AnchorPoint = Vector2.new(0.5, 0); ov.Position = UDim2.new(0.5, 0, 0, 120); ov.Size = UDim2.fromOffset(420, 0)
	ov.AutomaticSize = Enum.AutomaticSize.Y; ov.BackgroundColor3 = Color3.fromRGB(10, 10, 12); ov.BackgroundTransparency = 0.35
	ov.Font = Enum.Font.GothamBold; ov.TextSize = 14; ov.TextColor3 = Color3.fromRGB(255, 90, 90)
	ov.TextWrapped = true; ov.RichText = true; ov.Visible = false; ov.Parent = gui
	Instance.new("UICorner", ov).CornerRadius = UDim.new(0, 4)
	local sp = Instance.new("UIPadding", ov); sp.PaddingLeft = UDim.new(0, 8); sp.PaddingRight = UDim.new(0, 8)
	sp.PaddingTop = UDim.new(0, 4); sp.PaddingBottom = UDim.new(0, 4)
	H.movable(ov, "sensePos")

	local folder = Instance.new("Folder")
	folder.Name = "TSC_SENSE"; folder.Parent = workspace
	local rings = {} -- [userId] = Kugel-Part
	local bubbles = {}    -- [userId] = { pos =, col =, inside = }  Datenquelle fuer die 2D-Umrisslinie
	local insideBorder = Instance.new("Frame")
	insideBorder.Name = "TSC_SENSE_BORDER"; insideBorder.BackgroundTransparency = 1
	insideBorder.Size = UDim2.fromScale(1, 1); insideBorder.Visible = false; insideBorder.Parent = espFolder
	local ibStroke = Instance.new("UIStroke")
	ibStroke.Thickness = 4; ibStroke.Color = Color3.fromRGB(255, 50, 50)
	ibStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border; ibStroke.Parent = insideBorder

	local function killRing(id)
		local sph = rings[id]
		if sph then pcall(function() sph:Destroy() end); rings[id] = nil end
	end
	local function killAllRings()
		for id in pairs(rings) do killRing(id) end
		table.clear(bubbles)
		insideBorder.Visible = false
	end
	-- ForceField-Kugel: rendert als durchscheinende Huelle, 1 Teil pro Traeger (statt 40 Ringsegmenten)
	local function newSphere(col)
		local p = Instance.new("Part")
		p.Name = "TSC_SENSE_SPHERE"; p.Shape = Enum.PartType.Ball
		p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false
		p.Material = Enum.Material.ForceField; p.Color = col; p.Transparency = 0.7
		p.CastShadow = false; p.Locked = true
		p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = folder
		return p
	end

	local function iAmInfected()
		local c = lp.Character
		if not c then return false end
		if c:GetAttribute("Uninfected") then return false end
		local iv = c:FindFirstChild("InfectedValues") or c:FindFirstChild("LatexValues")
		local f = iv and iv:FindFirstChild("Infected")
		if f and f.Value then return true end
		local t = lp.Team and lp.Team.Name
		return t == "Infected" or t == "CIS Solitary" or t == "Contained Infected Subject"
	end

	-- Position: live aus dem Character, sonst letzte bekannte (lastSeen, oben mit 2 Hz gefuellt)
	local function posOf(pl)
		local c = pl.Character
		local r = c and c:FindFirstChild("HumanoidRootPart")
		if r and c:IsDescendantOf(workspace) then return r.Position, true, c end
		local ls = lastSeen[pl.UserId]
		return ls and ls.pos or nil, false, nil
	end

	toggle(S_sr, "Warn: RAH / RECON range", "senseWarn", function(on)
		if not on then killAllRings(); ov.Visible = false end
	end)
	toggle(S_sr, "Show sphere", "senseRings", function(on) if not on then killAllRings() end end)
	toggle(S_sr, "Overlay (top of screen)", "senseOverlay", function(on) if not on then ov.Visible = false end end)
	toggle(S_sr, "Only when infected", "senseOnlyInf", function(on)
		if on and not iAmInfected() then killAllRings(); ov.Visible = false end
	end)
	slider(S_sr, "Range", 50, 600, state.senseRange, function(v)
		state.senseRange = math.floor(v + 0.5); return state.senseRange .. " studs"
	end, "senseRange")
	local srInfo = info(S_sr, "")
	info(S_sr, "300 studs is the measured Hivemind radius of the Light Specimen (InfectedUI.ClientSide, 'Magnitude <= 300', through walls). For RAH/RECON in general no radius is confirmed - the sphere shows that reference distance. Works whether or not you are infected.")
	table.insert(H.conns, { Disconnect = function()
		pcall(function() folder:Destroy() end)
		pcall(function() insideBorder:Destroy() end)
	end })

	-- Umrisslinie entfernt (User 28.09.). Es bleibt der rote Bildrand, solange man in einer Blase steht.
	con(RunService.RenderStepped, function()
		local anyInside = false
		for _, b in pairs(bubbles) do
			if b.inside then anyInside = true break end
		end
		if insideBorder.Visible ~= anyInside then insideBorder.Visible = anyInside end
	end)

	task.spawn(function()
		while H.alive do
			local gate = state.senseWarn and (not state.senseOnlyInf or iAmInfected())
			if not gate and next(rings) then killAllRings(); ov.Visible = false end
			if gate then
				local myRoot = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
				local me = myRoot and myRoot.Position
				local found = {}
				for _, pl in ipairs(Players:GetPlayers()) do
					if pl ~= lp and pl.Team and TEAMS[pl.Team.Name] then
						local pos, live = posOf(pl)
						if pos and me then
							found[#found + 1] = { pl = pl, pos = pos, live = live, team = pl.Team.Name,
								d = (pos - me).Magnitude }
						end
					end
				end
				table.sort(found, function(a, b) return a.d < b.d end)

				-- Kugeln nur fuer die naechsten Traeger, und nur wenn sie ueberhaupt relevant nah sind
				local keep = {}
				if state.senseRings then
					for i = 1, math.min(#found, MAXRINGS) do
						local f = found[i]
						if f.d <= state.senseRange * 2 then
							keep[f.pl.UserId] = true
							local inside = f.d <= state.senseRange
							local col = inside and Color3.fromRGB(255, 60, 60) or Color3.fromRGB(255, 190, 60)
							local sph = rings[f.pl.UserId]
							if not sph then sph = newSphere(col); rings[f.pl.UserId] = sph end
							if sph.Color ~= col then sph.Color = col end
							local dia = state.senseRange * 2
							if sph.Size.X ~= dia then sph.Size = Vector3.new(dia, dia, dia) end
							sph.CFrame = CFrame.new(f.pos)
							bubbles[f.pl.UserId] = { pos = f.pos, col = col, inside = inside }
						end
					end
				end
				for id in pairs(rings) do if not keep[id] then killRing(id) end end
				for id in pairs(bubbles) do if not keep[id] then bubbles[id] = nil end end

				-- Overlay: wer kann mich sehen
				local insideList, nearList = {}, {}
				for _, f in ipairs(found) do
					local tag = f.team == "RAH" and "RAH" or "RECON"
					local txt2 = ("%s %s %.0fm%s"):format(tag, f.pl.Name, f.d, f.live and "" or " (stale)")
					if f.d <= state.senseRange then insideList[#insideList + 1] = txt2
					elseif #nearList < 4 then nearList[#nearList + 1] = txt2 end
				end
				if not state.senseOverlay then
					ov.Visible = false
				elseif #insideList > 0 then
					ov.Text = ('<font color="#ff4040">IN SENSE RANGE (%d studs)</font>  '):format(state.senseRange)
						.. table.concat(insideList, "  ·  ")
					ov.Visible = true
				elseif #nearList > 0 then
					ov.Text = '<font color="#ffbe3c">clear</font>  ' .. table.concat(nearList, "  ·  ")
					ov.Visible = true
				else
					ov.Visible = false
				end
				srInfo.Text = ("%d RAH/RECON online · %d in range"):format(#found, #insideList)
			else
				srInfo.Text = state.senseWarn and "waiting: not infected" or "off"
			end
			task.wait(0.2)
		end
	end)
end)()

-- ================= SPECIMEN TRACKER ESP =================
-- Specimen Tracker (RAH-Tool): Abstand/Highlight laufen nur beim Besitzer clientseitig (gruen < 50, gelb < 150,
-- sonst rot, gemessen HRP zu HRP zum gepairten Specimen). Backpacks replizieren -> Traeger sind fuer alle sichtbar.
-- Hier: Umriss um jeden Traeger + Boden-Ringe 50/150 um ihn = die Zonen, in denen sein Tracker gruen/gelb zeigt.
-- Fernbedienung getestet (2026-10-07): clientfunction "pair"/"setting" vom Nicht-Besitzer -> nil (Server ignoriert).
state.trkEsp = sv("trkEsp", false); state.trkRings = sv("trkRings", true); state.trkOnlyInf = sv("trkOnlyInf", false)
;(function()
	local S_trk = section(visR, "Specimen Tracker")
	local hls = {}   -- [player] = Highlight
	local function clearAll()
		for p, h in pairs(hls) do pcall(function() h:Destroy() end) hls[p] = nil end
	end
	toggle(S_trk, "Outline tracker holders", "trkEsp", function(on) if not on then clearAll() end end)
	toggle(S_trk, "Range rings (50 / 150)", "trkRings", function() end)
	local function iAmInfected()
		local c = lp.Character
		if not c then return false end
		if c:GetAttribute("Uninfected") then return false end
		local iv = c:FindFirstChild("InfectedValues") or c:FindFirstChild("LatexValues")
		local f = iv and iv:FindFirstChild("Infected")
		if f and f.Value then return true end
		local t = lp.Team and lp.Team.Name
		return t == "Infected" or t == "CIS Solitary" or t == "Contained Infected Subject"
	end
	toggle(S_trk, "Only when infected", "trkOnlyInf", function(on) if on and not iAmInfected() then clearAll() end end)
	local tInfo = info(S_trk, "")

	local function hasTracker(pl)
		for _, cont in ipairs({ pl.Character, pl:FindFirstChild("Backpack") }) do
			if cont then
				for _, t in ipairs(cont:GetChildren()) do
					if t:IsA("Tool") and t.Name == "Specimen Tracker" then return true, cont == pl.Character end
				end
			end
		end
		return false
	end

	local ringGui = Instance.new("ScreenGui")
	ringGui.Name = "TSC_TRK"; ringGui.ResetOnSpawn = false; ringGui.IgnoreGuiInset = true; ringGui.DisplayOrder = 996
	ringGui.Parent = CoreGui
	table.insert(H.conns, { Disconnect = function() ringGui:Destroy(); clearAll() end })
	local SEG, MAXH = 48, 3
	local RADII = { { 50, Color3.fromRGB(66, 255, 14) }, { 150, Color3.fromRGB(255, 247, 19) } }
	local segs = {} -- [holderIdx][ringIdx][seg]
	for h = 1, MAXH do
		segs[h] = {}
		for r = 1, #RADII do
			segs[h][r] = {}
			for i = 1, SEG do
				local f = Instance.new("Frame"); f.BorderSizePixel = 0; f.AnchorPoint = Vector2.new(0.5, 0.5); f.Visible = false
				f.BackgroundColor3 = RADII[r][2]; f.BackgroundTransparency = 0.2; f.Parent = ringGui
				segs[h][r][i] = f
			end
		end
	end
	local roots = {} -- aktuelle Traeger-HRPs fuer die Ringe

	RunService:BindToRenderStep("TSC_TRK_RING", Enum.RenderPriority.Camera.Value + 3, function()
		local cm = workspace.CurrentCamera
		for h = 1, MAXH do
			local root = state.trkEsp and state.trkRings and roots[h]
			for r = 1, #RADII do
				local ring = segs[h][r]
				if not (root and root.Parent) then
					if ring[1].Visible or ring[SEG].Visible then for i = 1, SEG do ring[i].Visible = false end end
				else
					local base = root.Position - Vector3.new(0, 2.9, 0)
					local rad = RADII[r][1]
					local prev, prevOk
					for i = 0, SEG do
						local a = (i % SEG) / SEG * math.pi * 2
						local sp = cm:WorldToViewportPoint(base + Vector3.new(math.cos(a) * rad, 0, math.sin(a) * rad))
						local p2, ok = Vector2.new(sp.X, sp.Y), sp.Z > 0
						if i > 0 then
							local f = ring[i]
							if ok and prevOk then
								local d = p2 - prev
								f.Position = UDim2.fromOffset((p2.X + prev.X) / 2, (p2.Y + prev.Y) / 2)
								f.Size = UDim2.fromOffset(d.Magnitude + 1, 2)
								f.Rotation = math.deg(math.atan2(d.Y, d.X))
								f.Visible = true
							else
								f.Visible = false
							end
						end
						prev, prevOk = p2, ok
					end
				end
			end
		end
	end)
	table.insert(H.conns, { Disconnect = function() RunService:UnbindFromRenderStep("TSC_TRK_RING") end })

	task.spawn(function()
		while H.alive do
			table.clear(roots)
			local gate = state.trkEsp and (not state.trkOnlyInf or iAmInfected())
			if not gate and next(hls) then clearAll() end
			if gate then
				local myRoot = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
				local list, seen = {}, {}
				for _, pl in ipairs(Players:GetPlayers()) do
					local has, equipped = hasTracker(pl)
					local c = pl.Character
					local root = c and c:FindFirstChild("HumanoidRootPart")
					if has and c then
						seen[pl] = true
						local h = hls[pl]
						if not h or not h.Parent then
							h = Instance.new("Highlight"); h.Name = "TSC_TRK_HL"
							h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop; h.FillTransparency = 0.8
							h.Parent = espFolder; hls[pl] = h
						end
						if h.Adornee ~= c then h.Adornee = c end
						local col = equipped and Color3.fromRGB(255, 50, 50) or Color3.fromRGB(255, 140, 0)
						h.OutlineColor = col; h.FillColor = col
						local d = (root and myRoot) and (root.Position - myRoot.Position).Magnitude
						list[#list + 1] = { pl = pl, root = root, d = d or math.huge, eq = equipped }
					end
				end
				for p in pairs(hls) do if not seen[p] then pcall(function() hls[p]:Destroy() end) hls[p] = nil end end
				table.sort(list, function(a, b) return a.d < b.d end)
				local parts = {}
				for i, e in ipairs(list) do
					if i <= MAXH then roots[i] = e.root end
					local zone = e.d < 50 and '<font color="#42ff0e">GREEN</font>' or e.d < 150 and '<font color="#fff713">YELLOW</font>' or "far"
					parts[#parts + 1] = ("%s%s %s %s"):format(e.pl.Name, e.eq and " (EQUIPPED)" or "",
						e.d < math.huge and ("%.0fm"):format(e.d) or "?", zone)
				end
				tInfo.Text = #list > 0 and table.concat(parts, "\n") or "no tracker holders"
			else
				tInfo.Text = state.trkEsp and "waiting: not infected" or "off"
			end
			task.wait(0.25)
		end
	end)
	info(S_trk, "Red outline = tracker equipped, orange = in backpack. Rings = the holder's tracker zones (green < 50, yellow < 150 from the paired specimen). Remote use of someone else's tracker: server ignores non-owners.")
end)()

-- ================= VENT / MANHOLE ESP =================
-- Markiert ALLE Vents und Manholes (nicht nur gejammte wie "Mark Jammed Vents"). Erkennung wie dort ueber den
-- ProximityPrompt: ObjectText enthaelt "Vent" oder "Manhole". Reichweite und Ausblenden kommen aus denselben
-- Reglern wie das Spieler-ESP (ESP Distance / Fade / Fade Power) ueber fadeAlpha+applyFade.
-- Startsuche einmal in Chunks, danach ereignisgesteuert; Labels entstehen erst in Reichweite und werden
-- ausserhalb sofort wieder abgeraeumt. Gejammte Vents werden rot mit Restzeit gezeigt (Attribute Cooldown +
-- CooldownTime am Vent-Modell), sind also auch ausserhalb der 40 Studs des anderen Features sichtbar.
state.ventEsp = sv("ventEsp", false); state.ventEspHL = sv("ventEspHL", false)
;(function()
	local S_ve = section(visR, "Vents / Manholes")
	local prompts, marks = {}, {}
	local function isVentPrompt(d)
		return d:IsA("ProximityPrompt") and (d.ObjectText:find("Vent") or d.ObjectText:find("Manhole")) ~= nil
	end
	local function clear(pp)
		local m = marks[pp]
		if m then
			pcall(function() m.bb:Destroy() end)
			if m.hl then pcall(function() m.hl:Destroy() end) end
			marks[pp] = nil
		end
	end
	local function clearAll() for pp in pairs(marks) do clear(pp) end end
	local function clearHL() for _, m in pairs(marks) do if m.hl then pcall(function() m.hl:Destroy() end) m.hl = nil end end end

	toggle(S_ve, "Vent / Manhole ESP", "ventEsp", function(on) if not on then clearAll() end end)
	toggle(S_ve, "Highlight model", "ventEspHL", function(on) if not on then clearHL() end end)
	local veInfo = info(S_ve, "")
	info(S_ve, "Uses the same Distance / Fade / Fade Power sliders as the player ESP. Jammed vents show red with the remaining cooldown, at any distance.")

	con(workspace.DescendantAdded, function(d)
		if d:IsA("ProximityPrompt") then task.defer(function() if isVentPrompt(d) then prompts[d] = true end end) end
	end)

	task.spawn(function()
		-- Startsuche in Chunks, damit es keinen Ruckler gibt (Workspace hat ~94k Descendants)
		local all = workspace:GetDescendants()
		for i = 1, #all do
			if isVentPrompt(all[i]) then prompts[all[i]] = true end
			if i % 4000 == 0 then task.wait() end
		end
		while H.alive do
			if state.ventEsp then
				local r = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
				local me = r and r.Position
				local shown, total = 0, 0
				for pp in pairs(prompts) do
					if not pp:IsDescendantOf(workspace) then
						clear(pp); prompts[pp] = nil
					else
						total = total + 1
						local part = pp.Parent
						if part and not part:IsA("BasePart") then part = part:FindFirstChildWhichIsA("BasePart", true) end
						local d = (part and me) and (part.Position - me).Magnitude or nil
						if d and d <= state.espDist then
							shown = shown + 1
							local jammed = pp.ActionText == "Jammed"
							local isMan = pp.ObjectText:find("Manhole") ~= nil
							local col = jammed and Color3.fromRGB(255, 70, 70)
								or (isMan and Color3.fromRGB(255, 175, 60) or Color3.fromRGB(95, 210, 255))
							local m = marks[pp]
							if not m then
								local bb = Instance.new("BillboardGui")
								bb.AlwaysOnTop = true; bb.Size = UDim2.fromOffset(150, 20); bb.StudsOffset = Vector3.new(0, 2, 0)
								bb.LightInfluence = 0; bb.Adornee = part; bb.Parent = espFolder
								local l = Instance.new("TextLabel")
								l.Size = UDim2.fromScale(1, 1); l.BackgroundTransparency = 1; l.Font = Enum.Font.GothamBold
								l.TextSize = 12; l.TextStrokeTransparency = 0.3; l.Parent = bb
								m = { bb = bb, lbl = l }
								marks[pp] = m
							end
							if m.bb.Adornee ~= part then m.bb.Adornee = part end
							if state.ventEspHL then
								if not m.hl then
									local model = pp.Parent
									while model and model ~= workspace and model:GetAttribute("CooldownTime") == nil do model = model.Parent end
									if model == workspace or not model then model = pp.Parent end
									local hl = Instance.new("Highlight")
									hl.FillTransparency = 0.75; hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
									hl.Adornee = model; hl.Parent = espFolder
									m.hl = hl
								end
								m.hl.FillColor = col; m.hl.OutlineColor = col
							elseif m.hl then
								pcall(function() m.hl:Destroy() end); m.hl = nil
							end
							local txt2
							if jammed then
								local model = pp.Parent
								while model and model ~= workspace and model:GetAttribute("CooldownTime") == nil do model = model.Parent end
								local cd = model and tonumber(model:GetAttribute("Cooldown"))
								local ct = model and tonumber(model:GetAttribute("CooldownTime"))
								local left = (cd and ct) and math.max(0, cd + ct - time()) or nil
								txt2 = left and ("JAMMED %ds"):format(math.ceil(left)) or "JAMMED"
							else
								txt2 = isMan and "MANHOLE" or "VENT"
							end
							m.lbl.TextColor3 = col
							m.lbl.Text = ("%s  %dm"):format(txt2, math.floor(d))
							applyFade(m.lbl, fadeAlpha(d), 12)
						elseif marks[pp] then
							clear(pp)
						end
					end
				end
				veInfo.Text = ("%d vents/manholes known · %d in range"):format(total, shown)
			else
				veInfo.Text = "off"
			end
			task.wait(0.3)
		end
	end)
	table.insert(H.conns, { Disconnect = function() clearAll() end })
end)()

-- ================= INFECT TRIP =================
-- Hinfahren, infizieren lassen, zurueck zur Ausgangsstelle -- alles auf Knopfdruck, nie automatisch.
-- Wie die Infektion funktioniert: die Ordner unter Workspace.InfectedPuddles tragen die Attribute InfectAmount
-- und InfectedType, die Pfuetzenteile darin haben TouchInterest. Beruehrungen des eigenen (client-owned)
-- Characters meldet der Client -> auf der Pfuetze stehen und wackeln laesst InfectionLevel steigen, bei
-- MaxInfectionValue (100) ist man infiziert. SquidDog gibt 70 pro Kontakt, also zwei Beruehrungen.
-- Problem: die Pfuetzen sind dynamisch UND rausgestreamt, wenn man weit weg ist -- dann findet man sie nicht.
-- Loesung: jede je gesehene Pfuetze wird mit Typ und Position in tsc_puddles.json gemerkt, der Trip springt
-- auf die gemerkte Position, fordert Streaming an und wartet bis die Pfuetze wirklich da ist.
state.itType = sv("itType", 1); state.itWait = sv("itWait", 14)
;(function()
	local PFILE = "tsc_puddles.json"
	local TYPES = { "SquidDog", "TabbyCat", "Tiger", "WhiteInfected", "LightInfected", "DarkDragon", "BlueDragon",
		"DarkWolf", "HypnoCat", "TigerShark", "ConeLizard", "SpiderWolf", "BerylWolf", "SnowLeopard", "FireFox", "ArcticFox" }

	local db = {}
	pcall(function()
		if isfile(PFILE) then db = HttpService:JSONDecode(readfile(PFILE)) or {} end
	end)
	local dirty = false
	local function remember(typ, pos)
		local old = db[typ]
		if old and (Vector3.new(old[1], old[2], old[3]) - pos).Magnitude < 10 then return end
		db[typ] = { pos.X, pos.Y, pos.Z }
		dirty = true
	end

	local S_it = section(miscR, "Infect Trip")
	local itInfo = info(S_it, "", T.accent)
	dropdown(S_it, "Specimen", TYPES, state.itType, function(i) state.itType = i end, "itType")
	slider(S_it, "Max wait", 5, 40, state.itWait, function(v)
		state.itWait = math.floor(v + 0.5); return state.itWait .. " s" end, "itWait")
	info(S_it, "Jumps to a remembered puddle of that type, wiggles until InfectionLevel is full, then back to where you started. Puddles are dynamic - a type only works once the hub has seen one. Positions are saved to " .. PFILE .. ".")

	-- Lerner: alle 2 s die Ordner abklappern (16 Ordner, kostet nichts)
	task.spawn(function()
		while H.alive do
			local ip = workspace:FindFirstChild("InfectedPuddles")
			if ip then
				for _, f in ipairs(ip:GetChildren()) do
					for _, c in ipairs(f:GetDescendants()) do
						if c:IsA("BasePart") then remember(f.Name, c.Position) break end
					end
				end
			end
			if dirty then dirty = false; pcall(function() writefile(PFILE, HttpService:JSONEncode(db)) end) end
			task.wait(2)
		end
	end)

	local function iv()
		local c = lp.Character
		return c and (c:FindFirstChild("InfectedValues") or c:FindFirstChild("LatexValues"))
	end
	local function level()
		local v = iv()
		local l = v and v:FindFirstChild("InfectionLevel")
		local m = v and v:FindFirstChild("MaxInfectionValue")
		return l and l.Value or 0, m and m.Value or 100
	end
	local function infected()
		local v = iv()
		local f = v and v:FindFirstChild("Infected")
		return (f and f.Value) == true
	end
	local running = false
	H.itAbort = false
	local function trip()
		if running then H.itAbort = true; itInfo.Text = "aborting..."; return end
		local typ = TYPES[state.itType] or TYPES[1]
		local c = lp.Character
		local hrp = c and c:FindFirstChild("HumanoidRootPart")
		if not hrp then itInfo.Text = "no character"; return end
		if infected() then itInfo.Text = "already infected (" .. typ .. " trip pointless)"; return end

		local ip = workspace:FindFirstChild("InfectedPuddles")
		local live
		if ip and ip:FindFirstChild(typ) then
			for _, d in ipairs(ip[typ]:GetDescendants()) do if d:IsA("BasePart") then live = d break end end
		end
		local target = live and live.Position or (db[typ] and Vector3.new(db[typ][1], db[typ][2], db[typ][3]))
		if not target then
			itInfo.Text = ("no %s puddle known - none seen yet"):format(typ)
			return
		end

		running = true; H.itAbort = false
		local home = hrp.CFrame
		local l0 = select(1, level())
		task.spawn(function()
			local t0 = os.clock()
			local phase = 0
			while running and not H.itAbort and os.clock() - t0 < state.itWait do
				local ch = lp.Character
				local h = ch and ch:FindFirstChild("HumanoidRootPart")
				if not h then break end
				-- auf der Pfuetze wackeln, damit Touched mehrfach feuert
				phase = phase + 1
				local off = Vector3.new(((phase % 2 == 0) and 1.5 or -1.5), 3.5, ((phase % 4 < 2) and 1.5 or -1.5))
				h.CFrame = CFrame.new(target + off)
				h.AssemblyLinearVelocity = Vector3.zero
				if phase == 1 then pcall(function() lp:RequestStreamAroundAsync(target, 2) end) end
				local lv, mx = level()
				itInfo.Text = ("%s: level %d / %d  (%.0fs)"):format(typ, lv, mx, os.clock() - t0)
				if infected() or lv >= mx then break end
				task.wait(0.15)
			end
			local lv, mx = level()
			local ch = lp.Character
			local h = ch and ch:FindFirstChild("HumanoidRootPart")
			if h then
				h.CFrame = home -- zurueck zur Ausgangsstelle (inkl. Blickrichtung)
				h.AssemblyLinearVelocity = Vector3.zero
			end
			local okTxt = infected() and "INFECTED" or ((lv > l0) and ("partial: %d / %d"):format(lv, mx) or "no contact registered")
			itInfo.Text = ("%s -> %s, back at start"):format(typ, okTxt)
			running = false
		end)
	end

	button(S_it, "Infect me (and return)", function() task.spawn(function() pcall(trip) end) end)
	button(S_it, "Abort", function() H.itAbort = true end)

	task.spawn(function()
		while H.alive do
			if not running then
				local known = 0
				for _ in pairs(db) do known = known + 1 end
				local typ = TYPES[state.itType] or "?"
				local lv, mx = level()
				itInfo.Text = ("%s: %s | infection %d/%d | %d puddle positions known"):format(
					typ, db[typ] and "position known" or "not seen yet", lv, mx, known)
			end
			task.wait(1)
		end
	end)
end)()

-- ================= CONFIG =================
-- Laufende Einstellungen speichern sich automatisch (SAVE_FILE); hier zusätzlich ein Profil zum Sichern/Zurückholen
local CFG_FILE = "tsc_hub_config.json"
local DEFAULTS = { fullbright = false, esp = false, espDist = 1500, espFade = 40, espFadePow = 2, brightness = 2, items = false, perf = 1,
	updInt = 0.2, nofall = false, staff = true, vent = true, ventPred = true, ventLog = true, ventBias = 0,
	ms = true, msReader = true, msHints = true, msFlags = true, msPace = 0, turrets = false, nofog = false,
	aim = false, aimTeam = true, aimVis = true, aimHealth = true, aimSticky = true, aimDist = 600, aimSens = 2, aimPart = 1, aimType = 1,
	aimRage = false, aimRageType = 1, aimPred = false, aimPredX = 5, aimPredY = 5, aimSmooth = true, aimSmX = 7.5, aimSmY = 7.5,
	fov = true, fovGlow = false, fovFill = false, fovSize = 126, fovStyle = 1, fovGunOnly = false, aimGunOnly = true }
local cfgStatus
local function saveCfg()
	local data = { keys = {} }
	for id, c in pairs(ctl) do data[id] = c.get() end
	for id, k in pairs(state.keys) do data.keys[id] = k.Name end
	local ok, err = pcall(function() writefile(CFG_FILE, HttpService:JSONEncode(data)) end)
	cfgStatus.Text = ok and ('<font color="#d266b4">profile saved</font> ' .. os.date("%H:%M:%S")) or ("save failed: " .. tostring(err))
end
local function applyCfg(data)
	for id, v in pairs(data) do
		if id ~= "keys" and ctl[id] then pcall(ctl[id].set, v) end
	end
	for id, n in pairs(data.keys or {}) do
		local k = kc(n, nil)
		if k and keyBoxes[id] then state.keys[id] = k; keyBoxes[id].Text = keyName(k) end
	end
end
local function loadCfg()
	local ok, data = pcall(function() return HttpService:JSONDecode(readfile(CFG_FILE)) end)
	if not ok or type(data) ~= "table" then cfgStatus.Text = "no profile found"; return end
	applyCfg(data)
	cfgStatus.Text = '<font color="#d266b4">profile loaded</font> ' .. os.date("%H:%M:%S")
end
button(S_cfg, "Save Profile", saveCfg)
button(S_cfg, "Load Profile", loadCfg)
button(S_cfg, "Reset To Defaults", function()
	applyCfg({ keys = { menu = "RightShift", vent = "End", aim = "MouseButton2" } })
	for id, v in pairs(DEFAULTS) do if ctl[id] then pcall(ctl[id].set, v) end end
	cfgStatus.Text = '<font color="#d266b4">defaults restored</font>'
end)
cfgStatus = info(S_cfg, "Settings save automatically.\nProfile: workspace/" .. CFG_FILE)

-- ================= MENU / KEYBINDS =================
keyRow(S_menu, "Toggle Menu", "menu")
button(S_menu, "Unload", function() task.defer(H.kill) end)
info(S_menu, "Click a key box, then press a key (Esc = cancel).")

con(UIS.InputBegan, function(i, gp)
	if listening then
		local isKey = i.UserInputType == Enum.UserInputType.Keyboard
		local isMouse = i.UserInputType == Enum.UserInputType.MouseButton2 or i.UserInputType == Enum.UserInputType.MouseButton3
		if isKey or isMouse then
			local id = listening; listening = nil
			if isMouse then state.keys[id] = i.UserInputType
			elseif i.KeyCode ~= Enum.KeyCode.Escape then state.keys[id] = i.KeyCode end
			local b = keyBoxes[id]; b.Text = keyName(state.keys[id]); b.TextColor3 = T.text
		end
		return
	end
	if gp or i.UserInputType ~= Enum.UserInputType.Keyboard then return end
	if keyMatch(i, state.keys.menu) then main.Visible = not main.Visible
	elseif keyMatch(i, state.keys.vent) then state.vent = not state.vent; refresh.vent() end
end)

selectTab("Misc")
H.selectTab = selectTab

-- Speichern (nur bei Änderung, max 1x/s)
task.spawn(function()
	local last = ""
	while H.alive do
		local t = {}
		for _, k in ipairs(SAVE_KEYS) do t[k] = state[k] end
		t.keyMenu = state.keys.menu.Name; t.keyVent = state.keys.vent.Name; t.keyAim = state.keys.aim.Name; t.keyAura = state.keys.aura.Name; t.keyCloak = state.keys.cloak.Name; t.keyView = state.keys.view and state.keys.view.Name or nil; t.keyPanic = state.keys.panic and state.keys.panic.Name or nil; t.keyWallbang = state.keys.wallbang and state.keys.wallbang.Name or nil
		t.guiX = main.Position.X.Offset; t.guiY = main.Position.Y.Offset; t.guiVisible = main.Visible
		local ok, js = pcall(function() return HttpService:JSONEncode(t) end)
		if ok and js ~= last then
			if pcall(writefile, SAVE_FILE, js) then last = js end
		end
		task.wait(1)
	end
end)

function H.kill()
	H.alive = false
	for _, c in ipairs(H.conns) do pcall(function() c:Disconnect() end) end
	H.conns = {}
	pcall(ventFlush)
	pcall(restoreFB)
	pcall(perfRestore)
	pcall(function() if desyncReal then lp.Character.HumanoidRootPart.CFrame = desyncReal end end)
	pcall(function() gui:Destroy() end)
end

-- ================= PANIC =================
-- Zwei getrennte Aktionen:
--  * Shift + G (Taste umbelegbar) = Panik: schaltet JEDES Feature ueber dessen eigenen Aus-Handler ab, damit
--    gepatchte Werte (No Spread/Max Charge/Kill Aura/Damage Zones/Fullbright/Performance/Fake Tools/Kamera)
--    korrekt zurueckgesetzt werden, und versteckt das Hub-Fenster. AUSNAHME: der Staff Radar (Admin-ESP) bleibt
--    an -- man will ja sehen, wann die Admins wieder weg sind (User 28.09.).
--  * Knopf "Remove hub completely" = H.kill: zusaetzlich alle Verbindungen trennen und die GUIs zerstoeren.
--    H.kill ist hier erweitert, weil das Original den Nebel nicht zurueckgesetzt und _G.__TSC_HUB stehen gelassen hat.
;(function()
	local KEEP = { staff = true } -- was der Panik-Modus NICHT anfasst
	state.keys.panic = kc(sv("keyPanic", "G"), Enum.KeyCode.G)
	local S_panic = section(optL, "Panic")
	keyRow(S_panic, "Panic key (hold Shift)", "panic")
	local pInfo = info(S_panic, "ready", T.accent)
	info(S_panic, "Shift + key: every feature off via its own restore path, hub window hidden - but the Staff Radar keeps running so you can see when the admins are gone. The button below additionally closes all connections and destroys the GUIs.")

	local origKill = H.kill
	H.kill = function()
		pcall(restoreNoFog)
		pcall(function() if H.viewStop then H.viewStop() end end)
		pcall(origKill)
		pcall(function() RunService:UnbindFromRenderStep("TSC_VIEW") end)
		_G.__TSC_HUB = nil
	end

	function H.panic()
		local off, kept = 0, {}
		for key, c in pairs(H.ctl) do
			if KEEP[key] then
				kept[#kept + 1] = key
			elseif c.get() then
				pcall(c.set, false)
				off = off + 1
			end
		end
		pcall(function() if H.viewStop then H.viewStop() end end)
		pcall(restoreNoFog)
		main.Visible = false
		H.panicked = true
		pInfo.Text = ("PANIC: %d features off, kept: %s"):format(off, #kept > 0 and table.concat(kept, ", ") or "-")
		return off
	end

	button(S_panic, "Remove hub completely", function() task.spawn(function() pcall(H.kill) end) end)
	con(UIS.InputBegan, function(i, gp)
		if gp or i.UserInputType ~= Enum.UserInputType.Keyboard then return end
		if not keyMatch(i, state.keys.panic) then return end
		if not (UIS:IsKeyDown(Enum.KeyCode.LeftShift) or UIS:IsKeyDown(Enum.KeyCode.RightShift)) then return end
		task.spawn(function() pcall(H.panic) end)
	end)
end)()

return "RSC HUB geladen"
