--[[ ============================================================
     UTG INFINITE SLIDE  —  Untitled Tag Game (PlaceId 14044547200)

     Ein Schalter: sliden ohne Zeitlimit, und dabei schneller werden.
     Laeuft komplett ueber die spieleigenen Regler, keine Positions-
     spruenge (die kickt der Server sofort mit "Suspicious activity").

     Was im Spielcode steht (Parkour/Slide.lua, gelesen 2026-09-20):
       * Der Slide endet nach 3 * SlideLengthMultiplier Sekunden —
         ausser shared.multipliers.InfiniteSlides ist wahr. Der Regler
         existiert im Spiel und steht normal auf false.
       * Er endet trotzdem, wenn du laenger als 0.1 s in der Luft bist,
         wenn die Seitwaertsgeschwindigkeit unter 2 faellt oder eine
         Emote laeuft. Dagegen hilft der Auto-Neustart.
       * Tempo kommt aus shared.boosts.SlideSlopeSpeed. Bergab waechst
         es bis 2.125 * SlideSpeedMultiplier, in der Ebene zieht es auf
         SlopesMultiplier * SlideSpeedMultiplier. Beide Regler stehen
         normal auf 1.
       * Neu starten geht 0.5 s nach dem Loslassen; einen eigenen
         Slide-Cooldown hat das Spiel nicht (SlideCooldown = nil).

     Bedienung:  RightShift an/aus   |   Insert blendet das Panel aus
     ============================================================ ]]

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local RS               = game:GetService("ReplicatedStorage")

local LP = Players.LocalPlayer

local genv = getgenv()
if genv.UTG_SLIDE and genv.UTG_SLIDE.unload then
	pcall(genv.UTG_SLIDE.unload)
end
local SLIDE = { version = "1.0.0" }
genv.UTG_SLIDE = SLIDE

------------------------------------------------------------------
-- Einstellungen
------------------------------------------------------------------
local CFG = {
	-- Startwert beim Antritt und wie schnell er waehrend des Slides steigt
	baseSpeed   = 1.0,
	rampPerSec  = 0.20,
	-- Deckel. Das Spiel rechnet bergab bis 2.125 * diesem Wert, das sind
	-- bei 2.0 schon ueber 130 studs/s. Hoeher zu gehen faellt auf.
	maxSpeed    = 2.0,
	slopes      = 1.25,
	-- laengerer Slide auch ohne die Endlos-Regel (greift beim Ausschalten)
	length      = 1.0,
	autoRestart = true,
}

local enabled = false
local ramp = CFG.baseSpeed
local lastFire = 0
local conns = {}
local function keep(c)
	conns[#conns + 1] = c
	return c
end

------------------------------------------------------------------
-- Die spieleigenen Regler setzen (und sauber zuruecknehmen)
------------------------------------------------------------------
local KEYS = { "InfiniteSlides", "SlideSpeedMultiplier", "SlopesMultiplier", "SlideLengthMultiplier" }
local originals, originalTable = nil, nil

local function sharedTable()
	local ok, s = pcall(function()
		return getrenv().shared
	end)
	return ok and s or nil
end

-- Das Spiel baut shared.multipliers bei jedem Rollenwechsel neu auf
-- (Utils.UpdateModifiers), deshalb wird jede Frame geschrieben statt einmal.
local function capture(m)
	if originalTable == m and originals then
		return
	end
	originalTable, originals = m, {}
	for _, k in ipairs(KEYS) do
		originals[k] = m[k]
	end
end

local function restore()
	local s = sharedTable()
	local m = s and s.multipliers
	if m and originals and originalTable == m then
		for k, v in pairs(originals) do
			m[k] = v
		end
	end
	ramp = CFG.baseSpeed
end

local function hrp()
	local c = LP.Character
	return c and c:FindFirstChild("HumanoidRootPart")
end

local function hum()
	local c = LP.Character
	return c and c:FindFirstChildOfClass("Humanoid")
end

local function lateralSpeed()
	local root = hrp()
	if not root then
		return 0
	end
	local v = root.AssemblyLinearVelocity
	return Vector3.new(v.X, 0, v.Z).Magnitude
end

local slideInput = nil
local function fireSlide()
	if not slideInput then
		local ok, ev = pcall(function()
			return RS.Events.game.player:FindFirstChild("SlideInput")
		end)
		slideInput = ok and ev or nil
	end
	if slideInput then
		pcall(function()
			slideInput:Fire()
		end)
		return true
	end
	return false
end

local status = { text = "aus", speed = 0, mult = 1 }

local function step(dt)
	local s = sharedTable()
	local m = s and s.multipliers
	if not m then
		return
	end
	capture(m)
	if not enabled then
		return
	end

	local sliding = s.sliding == true
	if sliding then
		-- waehrend des Slides wird er schneller, bis zum Deckel
		ramp = math.min(ramp + dt * CFG.rampPerSec, CFG.maxSpeed)
	else
		ramp = CFG.baseSpeed
	end

	m.InfiniteSlides = true
	m.SlideSpeedMultiplier = ramp
	m.SlopesMultiplier = CFG.slopes
	m.SlideLengthMultiplier = math.max(CFG.length, originals.SlideLengthMultiplier or 1)
	m.DisableSliding = false

	status.mult = ramp
	status.speed = lateralSpeed()

	-- Auto-Neustart: der Slide bricht in der Luft ab und beim Stehenbleiben.
	-- Das Spiel laesst 0.5 s nach dem Loslassen wieder zu.
	if CFG.autoRestart and not sliding then
		local h = hum()
		local grounded = h and h.FloorMaterial ~= Enum.Material.Air
		local char = LP.Character
		local values = char and char:FindFirstChild("values")
		local mv = values and values:FindFirstChild("MoveVector")
		local lock = values and values:FindFirstChild("LockMoveVector")
		local forward = mv and mv.Value.Z < 0
		local free = not (lock and lock.Value)
		if grounded and forward and free and s.sprinting and os.clock() - lastFire > 0.65 then
			lastFire = os.clock()
			fireSlide()
		end
		status.text = grounded and "wartet auf Anlauf" or "in der Luft"
	else
		status.text = sliding and "slidet" or "bereit"
	end
end

------------------------------------------------------------------
-- Panel
------------------------------------------------------------------
local COL = {
	bg   = Color3.fromRGB(20, 22, 28),
	head = Color3.fromRGB(28, 31, 40),
	text = Color3.fromRGB(236, 239, 246),
	dim  = Color3.fromRGB(140, 147, 163),
	on   = Color3.fromRGB(46, 170, 96),
	off  = Color3.fromRGB(58, 63, 77),
	knob = Color3.fromRGB(245, 247, 252),
	accent = Color3.fromRGB(96, 165, 250),
}

local sg = Instance.new("ScreenGui")
sg.Name = "UTG_InfiniteSlide"
sg.ResetOnSpawn = false
sg.DisplayOrder = 998
sg.Parent = (gethui and gethui()) or game:GetService("CoreGui")

local function corner(i, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = i
end

local main = Instance.new("Frame")
main.Size = UDim2.fromOffset(220, 0)
main.AutomaticSize = Enum.AutomaticSize.Y
main.Position = UDim2.new(0, 24, 0.62, 0)
main.BackgroundColor3 = COL.bg
main.BorderSizePixel = 0
main.Parent = sg
corner(main, 10)
local list = Instance.new("UIListLayout")
list.SortOrder = Enum.SortOrder.LayoutOrder
list.Parent = main

local header = Instance.new("TextLabel")
header.Size = UDim2.new(1, 0, 0, 34)
header.BackgroundColor3 = COL.head
header.BorderSizePixel = 0
header.Font = Enum.Font.GothamBold
header.TextSize = 14
header.TextColor3 = COL.accent
header.Text = "  Infinite Slide"
header.TextXAlignment = Enum.TextXAlignment.Left
header.LayoutOrder = 1
header.Parent = main
corner(header, 10)

local body = Instance.new("Frame")
body.Size = UDim2.new(1, 0, 0, 0)
body.AutomaticSize = Enum.AutomaticSize.Y
body.BackgroundTransparency = 1
body.LayoutOrder = 2
body.Parent = main
local pad = Instance.new("UIPadding")
pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 10), UDim.new(0, 10)
pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 10), UDim.new(0, 10)
pad.Parent = body
local bl = Instance.new("UIListLayout")
bl.Padding = UDim.new(0, 8)
bl.SortOrder = Enum.SortOrder.LayoutOrder
bl.Parent = body

local function makeToggle(text, order, getter, setter)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1, 0, 0, 32)
	btn.BackgroundColor3 = COL.head
	btn.BorderSizePixel = 0
	btn.AutoButtonColor = false
	btn.Font = Enum.Font.Gotham
	btn.TextSize = 12
	btn.TextColor3 = COL.text
	btn.Text = "   " .. text
	btn.TextXAlignment = Enum.TextXAlignment.Left
	btn.LayoutOrder = order
	btn.Parent = body
	corner(btn, 8)
	local track = Instance.new("Frame")
	track.Size = UDim2.fromOffset(32, 17)
	track.Position = UDim2.new(1, -42, 0.5, -8)
	track.BackgroundColor3 = COL.off
	track.BorderSizePixel = 0
	track.Parent = btn
	corner(track, 9)
	local knob = Instance.new("Frame")
	knob.Size = UDim2.fromOffset(13, 13)
	knob.Position = UDim2.fromOffset(2, 2)
	knob.BackgroundColor3 = COL.knob
	knob.BorderSizePixel = 0
	knob.Parent = track
	corner(knob, 7)
	local function paint()
		local on = getter()
		TweenService:Create(track, TweenInfo.new(0.12), { BackgroundColor3 = on and COL.on or COL.off }):Play()
		TweenService:Create(knob, TweenInfo.new(0.12), {
			Position = on and UDim2.fromOffset(17, 2) or UDim2.fromOffset(2, 2),
		}):Play()
	end
	keep(btn.MouseButton1Click:Connect(function()
		setter(not getter())
		paint()
	end))
	paint()
	return paint
end

local paintMain
local function setEnabled(on)
	enabled = on and true or false
	if not enabled then
		restore()
		status.text = "aus"
	else
		ramp = CFG.baseSpeed
		status.text = "bereit"
	end
	if paintMain then
		paintMain()
	end
end

paintMain = makeToggle("Unendlich sliden   [RShift]", 1, function()
	return enabled
end, setEnabled)

makeToggle("Auto-Neustart", 2, function()
	return CFG.autoRestart
end, function(v)
	CFG.autoRestart = v
end)

-- Tempo-Deckel in Stufen, damit man ihn ohne Konsole aendern kann
local speedBtn = Instance.new("TextButton")
speedBtn.Size = UDim2.new(1, 0, 0, 30)
speedBtn.BackgroundColor3 = COL.head
speedBtn.BorderSizePixel = 0
speedBtn.AutoButtonColor = false
speedBtn.Font = Enum.Font.Gotham
speedBtn.TextSize = 12
speedBtn.TextColor3 = COL.text
speedBtn.Text = ""
speedBtn.LayoutOrder = 3
speedBtn.Parent = body
corner(speedBtn, 8)
local STEPS = { 1.25, 1.5, 2.0, 2.5, 3.0 }
local function speedText()
	speedBtn.Text = string.format("   Deckel %.2fx  (klicken zum Wechseln)", CFG.maxSpeed)
end
keep(speedBtn.MouseButton1Click:Connect(function()
	local i = 1
	for k, v in ipairs(STEPS) do
		if math.abs(v - CFG.maxSpeed) < 0.01 then
			i = k
		end
	end
	CFG.maxSpeed = STEPS[(i % #STEPS) + 1]
	speedText()
end))
speedText()

local rows = {}
local function addRow(name)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, 15)
	row.BackgroundTransparency = 1
	row.LayoutOrder = 10 + #rows
	row.Parent = body
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.Gotham
	l.TextSize = 11
	l.TextColor3 = COL.dim
	l.Text = name
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Size = UDim2.new(0.55, 0, 1, 0)
	l.Parent = row
	local v = Instance.new("TextLabel")
	v.BackgroundTransparency = 1
	v.Font = Enum.Font.GothamMedium
	v.TextSize = 11
	v.TextColor3 = COL.text
	v.Text = "-"
	v.TextXAlignment = Enum.TextXAlignment.Right
	v.Size = UDim2.new(0.45, 0, 1, 0)
	v.Position = UDim2.new(0.55, 0, 0, 0)
	v.Parent = row
	rows[name] = v
end

addRow("Zustand")
addRow("Tempo")
addRow("Faktor")

keep(UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.RightShift then
		setEnabled(not enabled)
	elseif input.KeyCode == Enum.KeyCode.Insert then
		main.Visible = not main.Visible
	end
end))

------------------------------------------------------------------
-- Laufen lassen
------------------------------------------------------------------
local STEP = "UTG_InfiniteSlide_Step"
-- vor den Bewegungsskripten des Spiels, die bei Input laufen
RunService:BindToRenderStep(STEP, Enum.RenderPriority.Input.Value - 1, function(dt)
	local ok, err = pcall(step, dt)
	if not ok then
		warn("[InfiniteSlide] " .. tostring(err))
	end
end)

task.spawn(function()
	while SLIDE.alive ~= false do
		task.wait(0.2)
		if not sg.Parent then
			break
		end
		rows["Zustand"].Text = status.text
		rows["Tempo"].Text = string.format("%.0f studs/s", status.speed)
		rows["Faktor"].Text = string.format("%.2fx", status.mult)
	end
end)

keep(LP.CharacterAdded:Connect(function()
	ramp = CFG.baseSpeed
	originalTable, originals = nil, nil
end))

SLIDE.alive = true
SLIDE.cfg = CFG
function SLIDE.unload()
	SLIDE.alive = false
	enabled = false
	pcall(function()
		RunService:UnbindFromRenderStep(STEP)
	end)
	for _, c in ipairs(conns) do
		pcall(function()
			c:Disconnect()
		end)
	end
	restore()
	pcall(function()
		sg:Destroy()
	end)
	if genv.UTG_SLIDE == SLIDE then
		genv.UTG_SLIDE = nil
	end
end

setEnabled(false)
print("[UTG Infinite Slide] geladen. RightShift schaltet, Insert blendet das Panel aus.")
return SLIDE
