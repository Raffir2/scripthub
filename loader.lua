--[[ Raffir Scripts — one loadstring launcher
     loadstring(game:HttpGet("https://raw.githubusercontent.com/Raffir2/scripthub/main/loader.lua"))()

     * detects the game (GameId, then PlaceId) from registry.lua
     * known game  -> loads its script right away, no menu (RightControl opens the menu
                      to switch to another script of that game; the choice is remembered)
     * unknown game -> shows the menu with every game's scripts
     * offline fallback: each fetched file is cached under RaffirScripts/cache/
     * optional: re-run the launcher after a teleport (queue_on_teleport)
     * RightControl shows / hides the window

     Dev: getgenv().RAFFIR_DEV = "<workspace folder>" reads registry + mirrored files
     from that folder instead of GitHub. getgenv().RAFFIR_BASE overrides the raw base.

     Instance names never contain "hub" (Elemental Magic Arena kicks on that), and in
     games flagged quiet (TSC / Adonis log scanner) the launcher never writes to the console.
]]

local VERSION = "1.0.0"
local G = (getgenv and getgenv()) or _G
if G.__RAFFIR_LAUNCHER and G.__RAFFIR_LAUNCHER.kill then pcall(G.__RAFFIR_LAUNCHER.kill) end

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local lp = Players.LocalPlayer

local BASE = G.RAFFIR_BASE or "https://raw.githubusercontent.com/Raffir2/scripthub/main/"
local DEV = G.RAFFIR_DEV
local DIR = "RaffirScripts"

local L = { alive = true, conns = {}, quiet = false }
G.__RAFFIR_LAUNCHER = L

local function log(...)
	if L.quiet then return end
	print("[Raffir]", ...)
end

local function conn(sig, fn)
	local c = sig:Connect(fn)
	L.conns[#L.conns + 1] = c
	return c
end

---------------------------------------------------------------- files
local hasFS = type(writefile) == "function" and type(readfile) == "function" and type(isfile) == "function"

local function fsRead(p)
	if not hasFS then return nil end
	local ok, r = pcall(function() return isfile(p) and readfile(p) or nil end)
	return ok and r or nil
end

local function fsWrite(p, s)
	if not hasFS then return end
	pcall(function()
		if makefolder and isfolder then
			if not isfolder(DIR) then makefolder(DIR) end
			if not isfolder(DIR .. "/cache") then makefolder(DIR .. "/cache") end
		end
		writefile(p, s)
	end)
end

local settings = { reexec = false, last = {} }
do
	local raw = fsRead(DIR .. "/settings.json")
	if raw then
		local ok, t = pcall(HttpService.JSONDecode, HttpService, raw)
		if ok and type(t) == "table" then
			for k, v in pairs(t) do settings[k] = v end
		end
	end
	if type(settings.last) ~= "table" then settings.last = {} end
end

local function saveSettings()
	local ok, s = pcall(HttpService.JSONEncode, HttpService, settings)
	if ok then fsWrite(DIR .. "/settings.json", s) end
end

---------------------------------------------------------------- fetch
local function cacheKey(s) return (s:gsub("^https?://", ""):gsub("[^%w%.%-]", "_")) end

local function looksValid(src)
	return type(src) == "string" and #src > 0 and not src:match("^%s*404: Not Found") and not src:match("^%s*<!DOCTYPE")
end

-- returns src, origin ("dev" | "net" | "cache") or nil, err
local function fetch(entry, nocache)
	local url = entry.url or (BASE .. entry.path)
	if DEV and entry.path then
		local s = fsRead(DEV .. "/" .. entry.path)
		if s then return s, "dev" end
	end
	local key = DIR .. "/cache/" .. cacheKey(url) .. ".lua"
	local lastErr
	for attempt = 1, 3 do
		local sep = url:find("?", 1, true) and "&" or "?"
		local ok, res = pcall(function() return game:HttpGet(url .. sep .. "t=" .. tostring(os.time())) end)
		if ok and looksValid(res) then
			fsWrite(key, res)
			return res, "net"
		end
		lastErr = ok and "empty / 404 response" or tostring(res)
		task.wait(0.4 * attempt)
	end
	if not nocache then
		local s = fsRead(key)
		if looksValid(s) then return s, "cache" end
	end
	return nil, lastErr
end

local function compile(src, name)
	local ok, fn, err = pcall(loadstring, src, "=" .. name)
	if not ok or not fn then
		fn, err = loadstring(src)
	end
	return fn, err
end

---------------------------------------------------------------- registry + detection
local REG
do
	local src, origin = fetch({ path = "registry.lua" })
	if src then
		local fn = compile(src, "registry")
		local ok, t = pcall(fn or error)
		if ok and type(t) == "table" and type(t.games) == "table" then REG = t; REG._origin = origin end
	end
end
if not REG then
	log("could not load the registry (no network and no cache)")
	G.__RAFFIR_LAUNCHER = nil
	return
end

local function listHas(list, v)
	for _, x in ipairs(list or {}) do if x == v then return true end end
	return false
end

-- Detection, most to least reliable. GameId/PlaceId read 0 for a moment after a
-- teleport or an early inject, so wait for real ids first.
do
	local t0 = os.clock()
	while (not game:IsLoaded() or game.PlaceId == 0 or game.GameId == 0) and os.clock() - t0 < 15 do task.wait(0.1) end
end

local function findBy(field, v)
	if not v or v == 0 then return nil end
	for _, g in ipairs(REG.games) do
		if listHas(g[field], v) then return g end
	end
end

local current, how = findBy("universe", game.GameId), "GameId"
if not current then current, how = findBy("places", game.PlaceId), "PlaceId" end
if not current and game.PlaceId ~= 0 then
	-- unknown sub-place / new server type: ask Roblox which universe it belongs to (cached)
	settings.universeOf = type(settings.universeOf) == "table" and settings.universeOf or {}
	local key = tostring(game.PlaceId)
	local uni = tonumber(settings.universeOf[key])
	if not uni then
		local ok, res = pcall(function() return game:HttpGet("https://apis.roblox.com/universes/v1/places/" .. key .. "/universe") end)
		uni = ok and tonumber(tostring(res):match('"universeId"%s*:%s*(%d+)')) or nil
		if uni then settings.universeOf[key] = uni; saveSettings() end
	end
	current, how = findBy("universe", uni), "universe lookup"
	L._uni = uni
end
if not current then
	-- last resort: the game's (universe) name against each entry's match patterns;
	-- sub-places carry their own names, so ask for the universe name first
	local name = ""
	local uni = (game.GameId ~= 0 and game.GameId) or L._uni
	if uni then
		local ok, res = pcall(function() return game:HttpGet("https://games.roblox.com/v1/games?universeIds=" .. uni) end)
		name = ok and tostring(res):match('"name"%s*:%s*"(.-)"') or ""
	end
	if name == "" then
		local ok, info = pcall(function() return game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId) end)
		name = ok and info and tostring(info.Name) or ""
	end
	name = name:lower()
	for _, g in ipairs(REG.games) do
		for _, pat in ipairs(g.match or {}) do
			if name:find(pat) then current, how = g, "name" break end
		end
		if current then break end
	end
end
L.quiet = current and current.quiet or false

local function defaultScript(g)
	local want = settings.last[g.id]
	for _, s in ipairs(g.scripts) do if s.id == want then return s end end
	for _, s in ipairs(g.scripts) do if s.default then return s end end
	return g.scripts[1]
end

---------------------------------------------------------------- theme
local C = {
	bg = Color3.fromRGB(17, 19, 24),
	side = Color3.fromRGB(12, 14, 18),
	card = Color3.fromRGB(24, 27, 34),
	cardHi = Color3.fromRGB(31, 35, 44),
	stroke = Color3.fromRGB(40, 44, 55),
	text = Color3.fromRGB(230, 232, 238),
	muted = Color3.fromRGB(138, 144, 160),
	accent = Color3.fromRGB(124, 92, 255),
	ok = Color3.fromRGB(70, 200, 120),
	warn = Color3.fromRGB(240, 180, 60),
	err = Color3.fromRGB(235, 80, 80),
}

local function new(class, props, children)
	local o = Instance.new(class)
	for k, v in pairs(props or {}) do o[k] = v end
	for _, c in ipairs(children or {}) do c.Parent = o end
	return o
end
local function corner(r) return new("UICorner", { CornerRadius = UDim.new(0, r or 6) }) end
local function stroke(c, t) return new("UIStroke", { Color = c or C.stroke, Thickness = t or 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }) end
local function pad(l, t, r, b)
	return new("UIPadding", { PaddingLeft = UDim.new(0, l), PaddingTop = UDim.new(0, t or l), PaddingRight = UDim.new(0, r or l), PaddingBottom = UDim.new(0, b or t or l) })
end
local function tween(o, t, props) TweenService:Create(o, TweenInfo.new(t, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), props):Play() end

local function label(text, size, color, font, props)
	local o = new("TextLabel", {
		BackgroundTransparency = 1, Text = text, TextSize = size or 13, TextColor3 = color or C.text,
		Font = font or Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center,
	})
	for k, v in pairs(props or {}) do o[k] = v end
	return o
end

---------------------------------------------------------------- window
local function guiParent()
	local ok, h = pcall(function() return gethui and gethui() end)
	if ok and h then return h end
	local cg = game:GetService("CoreGui")
	if pcall(function() local _ = cg.Name end) then return cg end
	return lp:WaitForChild("PlayerGui")
end

local screen = new("ScreenGui", {
	Name = "RL" .. tostring(math.random(100000, 999999)),
	ResetOnSpawn = false, IgnoreGuiInset = true, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 999,
})
pcall(function() if syn and syn.protect_gui then syn.protect_gui(screen) end end)
screen.Parent = guiParent()

local W, H = 600, 400
local win = new("Frame", {
	Size = UDim2.fromOffset(W, H), Position = UDim2.new(0.5, -W / 2, 0.5, -H / 2 + 12),
	BackgroundColor3 = C.bg, BorderSizePixel = 0, ClipsDescendants = true, BackgroundTransparency = 1,
}, { corner(10), stroke(C.stroke) })
win.Parent = screen

-- top bar
local top = new("Frame", { Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = C.side, BorderSizePixel = 0 })
top.Parent = win
label("RAFFIR", 15, C.text, Enum.Font.GothamBold, { Position = UDim2.fromOffset(16, 0), Size = UDim2.fromOffset(70, 40) }).Parent = top
label("scripts  v" .. VERSION, 12, C.muted, Enum.Font.Gotham, { Position = UDim2.fromOffset(80, 0), Size = UDim2.fromOffset(120, 40) }).Parent = top

local chip = new("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -84, 0.5, 0), Size = UDim2.fromOffset(10, 22), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = C.card }, {
	corner(11), pad(10, 0), new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 6) }),
})
chip.Parent = top
local chipDot = new("Frame", { Size = UDim2.fromOffset(7, 7), BackgroundColor3 = current and C.ok or C.warn }, { corner(4) })
chipDot.Parent = chip
local chipText = label(current and current.name or ("Unknown game · " .. game.PlaceId), 12, C.text, Enum.Font.GothamMedium, { Size = UDim2.fromOffset(0, 22), AutomaticSize = Enum.AutomaticSize.X })
chipText.Parent = chip

local function topButton(text, x, color)
	local b = new("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, x, 0.5, 0), Size = UDim2.fromOffset(28, 28),
		BackgroundColor3 = C.card, BackgroundTransparency = 1, Text = text, TextColor3 = C.muted, TextSize = 16, Font = Enum.Font.GothamBold, AutoButtonColor = false,
	}, { corner(6) })
	b.Parent = top
	conn(b.MouseEnter, function() tween(b, 0.15, { BackgroundTransparency = 0, TextColor3 = color or C.text }) end)
	conn(b.MouseLeave, function() tween(b, 0.15, { BackgroundTransparency = 1, TextColor3 = C.muted }) end)
	return b
end
local closeBtn = topButton("×", -10, C.err)
local hideBtn = topButton("–", -42)

-- sidebar
local side = new("ScrollingFrame", {
	Position = UDim2.fromOffset(0, 40), Size = UDim2.new(0, 180, 1, -76), BackgroundColor3 = C.side, BorderSizePixel = 0,
	ScrollBarThickness = 2, ScrollBarImageColor3 = C.stroke, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
}, { pad(8, 8), new("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }) })
side.Parent = win

-- main area
local main = new("Frame", { Position = UDim2.fromOffset(180, 40), Size = UDim2.new(1, -180, 1, -76), BackgroundTransparency = 1 })
main.Parent = win
local title = label("", 18, C.text, Enum.Font.GothamBold, { Position = UDim2.fromOffset(18, 12), Size = UDim2.new(1, -36, 0, 24) })
title.Parent = main
local subtitle = label("", 12, C.muted, Enum.Font.Gotham, { Position = UDim2.fromOffset(18, 36), Size = UDim2.new(1, -36, 0, 16) })
subtitle.Parent = main

local list = new("ScrollingFrame", {
	Position = UDim2.fromOffset(18, 64), Size = UDim2.new(1, -36, 1, -72), BackgroundTransparency = 1, BorderSizePixel = 0,
	ScrollBarThickness = 3, ScrollBarImageColor3 = C.stroke, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
}, { new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }), pad(0, 2, 6, 6) })
list.Parent = main

-- footer
local foot = new("Frame", { Position = UDim2.new(0, 0, 1, -36), Size = UDim2.new(1, 0, 0, 36), BackgroundColor3 = C.side, BorderSizePixel = 0 }, {
	pad(14, 0),
})
foot.Parent = win
local status = label("", 12, C.muted, Enum.Font.Gotham, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.new(0.5, 0, 1, 0), TextXAlignment = Enum.TextXAlignment.Right, TextTruncate = Enum.TextTruncate.AtEnd })
status.Parent = foot

local function setStatus(text, color)
	status.Text = text
	status.TextColor3 = color or C.muted
end

local function toggle(text, x, get, set)
	local holder = new("TextButton", { Position = UDim2.fromOffset(x, 0), Size = UDim2.fromOffset(150, 36), BackgroundTransparency = 1, Text = "", AutoButtonColor = false })
	holder.Parent = foot
	local track = new("Frame", { Position = UDim2.new(0, 0, 0.5, -8), Size = UDim2.fromOffset(28, 16), BackgroundColor3 = C.card }, { corner(8), stroke(C.stroke) })
	track.Parent = holder
	local knob = new("Frame", { Position = UDim2.fromOffset(2, 2), Size = UDim2.fromOffset(12, 12), BackgroundColor3 = C.muted }, { corner(6) })
	knob.Parent = track
	label(text, 12, C.text, Enum.Font.Gotham, { Position = UDim2.fromOffset(36, 0), Size = UDim2.new(1, -36, 1, 0) }).Parent = holder
	local function paint()
		local on = get()
		tween(knob, 0.15, { Position = UDim2.fromOffset(on and 14 or 2, 2), BackgroundColor3 = on and C.text or C.muted })
		tween(track, 0.15, { BackgroundColor3 = on and C.accent or C.card })
	end
	conn(holder.MouseButton1Click, function() set(not get()); paint() end)
	paint()
end

---------------------------------------------------------------- loading
local busy = false
local function runScript(g, s, manual)
	if busy then return end
	busy = true
	setStatus("Fetching " .. s.name .. " …", C.text)
	task.spawn(function()
		local src, origin = fetch(s, s.nocache)
		if not src then
			setStatus("Download failed: " .. s.name, C.err)
			log("download failed", s.name, origin)
			busy = false
			if L.show then L.show() end
			return
		end
		local fn, err = compile(src, s.name)
		if not fn then
			setStatus("Compile error in " .. s.name, C.err)
			log("compile error", s.name, err)
			busy = false
			if L.show then L.show() end
			return
		end
		if manual then
			settings.last[g.id] = s.id
			saveSettings()
		end
		setStatus(("Running %s%s"):format(s.name, origin == "cache" and " (cached copy, offline)" or origin == "dev" and " (dev)" or ""), C.ok)
		L.loaded = L.loaded or {}
		L.loaded[#L.loaded + 1] = g.id .. "/" .. s.id
		busy = false
		-- the launcher steps aside so the script's own UI is in front
		if manual then task.delay(0.4, function() if L.alive and L.hide then L.hide() end end) end
		local ok, res = pcall(fn)
		if not ok then
			setStatus("Runtime error in " .. s.name, C.err)
			log("runtime error", s.name, res)
			if L.show then L.show() end
		end
	end)
end

---------------------------------------------------------------- views
local sideButtons = {}
local selected

local function scriptCard(g, s, order)
	local isDefault = defaultScript(g) == s
	local card = new("Frame", { Size = UDim2.new(1, 0, 0, 66), BackgroundColor3 = C.card, LayoutOrder = order }, { corner(8), stroke(isDefault and C.accent or C.stroke) })
	card.Parent = list
	label(s.name, 14, C.text, Enum.Font.GothamBold, { Position = UDim2.fromOffset(14, 10), Size = UDim2.new(1, -130, 0, 18) }).Parent = card
	label(s.desc or "", 12, C.muted, Enum.Font.Gotham, {
		Position = UDim2.fromOffset(14, 29), Size = UDim2.new(1, -130, 0, 30), TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, TextTruncate = Enum.TextTruncate.AtEnd,
	}).Parent = card
	local tag = label(s.url and "repo" or "mirror", 10, s.url and C.ok or C.muted, Enum.Font.GothamMedium, {
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 8), Size = UDim2.fromOffset(100, 14), TextXAlignment = Enum.TextXAlignment.Right,
	})
	tag.Text = (isDefault and "default · " or "") .. tag.Text
	tag.Parent = card
	local btn = new("TextButton", {
		AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -12, 1, -10), Size = UDim2.fromOffset(84, 28),
		BackgroundColor3 = isDefault and C.accent or C.cardHi, Text = "Load", TextColor3 = C.text, TextSize = 13, Font = Enum.Font.GothamBold, AutoButtonColor = true,
	}, { corner(6) })
	btn.Parent = card
	conn(btn.MouseButton1Click, function() runScript(g, s, true) end)
	conn(card.MouseEnter, function() tween(card, 0.12, { BackgroundColor3 = C.cardHi }) end)
	conn(card.MouseLeave, function() tween(card, 0.12, { BackgroundColor3 = C.card }) end)
end

local function showGame(g)
	selected = g
	for gg, b in pairs(sideButtons) do
		local on = gg == g
		tween(b, 0.12, { BackgroundTransparency = on and 0 or 1 })
		b:FindFirstChild("Label").TextColor3 = on and C.text or C.muted
	end
	for _, c in ipairs(list:GetChildren()) do if c:IsA("Frame") then c:Destroy() end end
	title.Text = g.name
	if g == current then
		subtitle.Text = ("Detected by %s · %d script%s · registry %s"):format(how, #g.scripts, #g.scripts == 1 and "" or "s", REG._origin or "?")
		subtitle.TextColor3 = C.ok
	else
		subtitle.Text = "Not the current game — scripts will most likely not work here"
		subtitle.TextColor3 = C.warn
	end
	for i, s in ipairs(g.scripts) do scriptCard(g, s, i) end
end

local function sideButton(g, order)
	local b = new("TextButton", { Size = UDim2.new(1, -16, 0, 30), BackgroundColor3 = C.card, BackgroundTransparency = 1, Text = "", AutoButtonColor = false, LayoutOrder = order }, { corner(6) })
	b.Parent = side
	if g == current then
		new("Frame", { Position = UDim2.new(0, 10, 0.5, -3), Size = UDim2.fromOffset(6, 6), BackgroundColor3 = C.ok }, { corner(3) }).Parent = b
	end
	label(g.name, 12, C.muted, Enum.Font.GothamMedium, { Name = "Label", Position = UDim2.fromOffset(24, 0), Size = UDim2.new(1, -28, 1, 0), TextTruncate = Enum.TextTruncate.AtEnd }).Parent = b
	conn(b.MouseButton1Click, function()
		showGame(g)
	end)
	sideButtons[g] = b
end

if current then
	label("THIS GAME", 10, C.muted, Enum.Font.GothamBold, { Size = UDim2.new(1, -16, 0, 20), LayoutOrder = 0 }).Parent = side
	sideButton(current, 1)
end
label("ALL GAMES", 10, C.muted, Enum.Font.GothamBold, { Size = UDim2.new(1, -16, 0, 24), LayoutOrder = 2, TextYAlignment = Enum.TextYAlignment.Bottom }).Parent = side
for i, g in ipairs(REG.games) do
	if g ~= current then sideButton(g, 2 + i) end
end

toggle("Re-run after teleport", 0, function() return settings.reexec end, function(v)
	settings.reexec = v
	saveSettings()
end)

---------------------------------------------------------------- show / hide / drag / keybind
local visible = false
function L.show()
	if not L.alive then return end
	visible = true
	win.Visible = true
	tween(win, 0.25, { BackgroundTransparency = 0, Position = UDim2.new(0.5, -W / 2, 0.5, -H / 2) })
end
function L.hide()
	visible = false
	tween(win, 0.2, { BackgroundTransparency = 1, Position = UDim2.new(0.5, -W / 2, 0.5, -H / 2 + 12) })
	task.delay(0.2, function() if not visible then win.Visible = false end end)
end
function L.kill()
	L.alive = false
	for _, c in ipairs(L.conns) do pcall(function() c:Disconnect() end) end
	pcall(function() screen:Destroy() end)
	if G.__RAFFIR_LAUNCHER == L then G.__RAFFIR_LAUNCHER = nil end
end
-- for scripted use (bridge tests): L.load("utg", "slide")
function L.load(gameId, scriptId)
	for _, g in ipairs(REG.games) do
		if g.id == gameId then
			for _, s in ipairs(g.scripts) do
				if s.id == scriptId then return runScript(g, s, true) end
			end
		end
	end
end
function L.select(gameId)
	for _, g in ipairs(REG.games) do
		if g.id == gameId then showGame(g) return true end
	end
end
L.registry, L.current, L.how, L.version = REG, current, how, VERSION

conn(closeBtn.MouseButton1Click, L.kill)
conn(hideBtn.MouseButton1Click, L.hide)
conn(UIS.InputBegan, function(input, gp)
	if gp then return end
	if input.KeyCode == Enum.KeyCode.RightControl then
		if visible then L.hide() else L.show() end
	end
end)

do
	local dragging, startPos, startInput
	conn(top.InputBegan, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging, startPos, startInput = true, win.Position, input.Position
		end
	end)
	conn(UIS.InputChanged, function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local d = input.Position - startInput
			win.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
		end
	end)
	conn(UIS.InputEnded, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = false end
	end)
end

---------------------------------------------------------------- re-run after teleport
do
	local q = queue_on_teleport or (syn and syn.queue_on_teleport) or (fluxus and fluxus.queue_on_teleport)
	if type(q) == "function" then
		local queued = false
		conn(lp.OnTeleport, function(state)
			if queued or not settings.reexec or state ~= Enum.TeleportState.Started then return end
			queued = true
			local code
			if DEV then
				code = ("getgenv().RAFFIR_DEV=%q loadstring(readfile(%q))()"):format(DEV, DEV .. "/loader.lua")
			else
				code = ("loadstring(game:HttpGet(%q))()"):format(BASE .. "loader.lua")
			end
			pcall(q, code)
		end)
	end
end

---------------------------------------------------------------- start
win.Visible = false
showGame(current or REG.games[1])
if current then
	-- known game: load straight away, the menu stays hidden (RightControl opens it)
	runScript(current, defaultScript(current), false)
else
	setStatus(("No script for this game (PlaceId %d) · %d games available"):format(game.PlaceId, #REG.games), C.warn)
	L.show()
end
log(("launcher v%s · %s"):format(VERSION, current and current.name or "unknown game"))
