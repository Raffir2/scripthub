-- UTG bundle (main), generated 2026-09-20 15:28:20
local __M, __L = {}, {}
local function import(name) local v = __L[name]; if v == nil then v = __M[name](); __L[name] = v end; return v end
__M["util"] = function()
-- Shared helpers: services, cleanup, logging, vector math
local U = {}

U.Players = game:GetService("Players")
U.RunService = game:GetService("RunService")
U.UIS = game:GetService("UserInputService")
U.RS = game:GetService("ReplicatedStorage")
U.CS = game:GetService("CollectionService")
U.HttpService = game:GetService("HttpService")
U.lp = U.Players.LocalPlayer

-- the game's `shared` table (the executor has its own)
function U.shared()
	return getrenv().shared
end

local Maid = {}
Maid.__index = Maid

function Maid.new()
	return setmetatable({ items = {} }, Maid)
end

function Maid:give(item)
	table.insert(self.items, item)
	return item
end

function Maid:clean()
	for i = #self.items, 1, -1 do
		local item = self.items[i]
		if typeof(item) == "RBXScriptConnection" then
			item:Disconnect()
		elseif type(item) == "function" then
			pcall(item)
		elseif typeof(item) == "Instance" then
			item:Destroy()
		end
	end
	table.clear(self.items)
end

U.Maid = Maid

U.logLines = {}

function U.log(...)
	local parts = {}
	for i = 1, select("#", ...) do
		parts[i] = tostring((select(i, ...)))
	end
	local line = table.concat(parts, " ")
	table.insert(U.logLines, string.format("[%.2f] %s", os.clock(), line))
	if #U.logLines > 300 then
		table.remove(U.logLines, 1)
	end
	print("[UTGAP] " .. line)
end

function U.flat(v)
	return Vector3.new(v.X, 0, v.Z)
end

-- yaw (radians) so that CFrame.Angles(0, yaw, 0).LookVector points along dir
function U.yawOf(dir)
	return math.atan2(-dir.X, -dir.Z)
end

function U.wrapAngle(a)
	return (a + math.pi) % (2 * math.pi) - math.pi
end

function U.char()
	return U.lp.Character
end

function U.hrp(char)
	char = char or U.lp.Character
	return char and char:FindFirstChild("HumanoidRootPart")
end

function U.hum(char)
	char = char or U.lp.Character
	return char and char:FindFirstChildOfClass("Humanoid")
end

return U

end
__M["gameapi"] = function()
-- Read-only view of game state + access to the game's own action functions
local U = import("util")

local G = {}

local fnCache = {}

local function upvaluesContain(fn, targets)
	local ok, ups = pcall(debug.getupvalues, fn)
	if not ok or type(ups) ~= "table" then
		return false
	end
	for _, v in pairs(ups) do
		if targets[v] then
			return true
		end
	end
	return false
end

-- Character scripts re-run on respawn, so closures belonging to an old
-- character stay in the GC. Only accept ones bound to the current character.
local function findGameFn(name, sourcePart)
	local char = U.char()
	if not char then
		return nil
	end
	local cached = fnCache[name]
	if cached and cached.char == char then
		return cached.fn
	end
	local targets = {}
	targets[char] = true
	local hrp, hum = U.hrp(char), U.hum(char)
	if hrp then
		targets[hrp] = true
	end
	if hum then
		targets[hum] = true
	end
	for _, fn in ipairs(getgc(false)) do
		if type(fn) == "function" and islclosure(fn) then
			local ok, info = pcall(debug.getinfo, fn)
			if ok and info and info.name == name and string.find(tostring(info.source), sourcePart, 1, true) and upvaluesContain(fn, targets) then
				fnCache[name] = { fn = fn, char = char }
				return fn
			end
		end
	end
	return nil
end

G.findGameFn = findGameFn

-- Direct tag: the game own button aims through the CAMERA, which means the
-- camera has to snap onto the target. Sending the remote with the target
-- serial and a synthesised look direction removes that entirely - no camera
-- yanking, and it also lands while we are running away.
local SerialisedData = nil
local Utils = nil
local tagState = { pending = false, pendingAt = 0, nextAt = 0, cooldown = 0.9, ok = 0, rejected = 0, missRun = 0 }
G.tagState = tagState

local function serialOf(player)
	if not SerialisedData then
		local ok, mod = pcall(require, U.RS:WaitForChild("Modules"):WaitForChild("SerialisedData"))
		SerialisedData = ok and mod or false
	end
	if SerialisedData then
		local ok, serial = pcall(SerialisedData.getPlayer, player)
		if ok and serial then
			return serial
		end
	end
	local attr = player:GetAttribute("serialID")
	return typeof(attr) == "number" and attr or nil
end

local function gameUtils()
	if Utils == nil then
		local ok, mod = pcall(require, game:GetService("ReplicatedFirst").Utils)
		Utils = ok and mod or false
	end
	return Utils or nil
end

function G.tagReady()
	return not tagState.pending and os.clock() >= tagState.nextAt
end

function G.tagPlayer(player)
	if not G.tagReady() then
		-- watchdog: a stuck lock would block every future tag
		if tagState.pending and os.clock() - tagState.pendingAt > 2 then
			tagState.pending = false
		else
			return false
		end
	end
	local me, target = U.hrp(), U.hrp(player.Character)
	local serial = me and target and serialOf(player)
	if not serial then
		return false
	end
	tagState.pending, tagState.pendingAt = true, os.clock()
	tagState.nextAt = os.clock() + tagState.cooldown

	local look = CFrame.lookAt(me.Position + Vector3.new(0, 1.5, 0), target.Position)
	local buf = buffer.create(7)
	buffer.writeu8(buf, 0, serial)
	local x, y, z = look:ToEulerAnglesYXZ()
	buffer.writeu16(buf, 1, math.floor((x + math.pi) / (2 * math.pi) * 65535 + 0.5))
	buffer.writeu16(buf, 3, math.floor((y + math.pi) / (2 * math.pi) * 65535 + 0.5))
	buffer.writeu16(buf, 5, math.floor((z + math.pi) / (2 * math.pi) * 65535 + 0.5))

	-- local feel: sound, swing animation and the game own cooldown
	local events = U.RS.Events
	pcall(function()
		events.replication.SoundEvent:Fire("Tag", me, 0.25, true)
	end)
	pcall(function()
		events.game.player.AnimateEvent:Fire("Tag", 0.1, 1)
	end)
	pcall(function()
		events.game.tags.TagSwing:Fire()
	end)
	local utils = gameUtils()
	if utils and utils.ApplyCooldown then
		pcall(utils.ApplyCooldown, "Tag")
	end

	local ok, res = pcall(function()
		return events.game.tags.TagPlayer:InvokeServer(buf)
	end)
	local landed = ok and res and true or false
	if landed then
		tagState.ok += 1
		-- the server has its own cooldown; measure it instead of guessing
		if tagState.missRun == 0 then
			tagState.cooldown = math.max(tagState.cooldown * 0.97, 0.45)
		end
		tagState.missRun = 0
		tagState.nextAt = os.clock() + tagState.cooldown
	else
		tagState.rejected += 1
		tagState.missRun += 1
		tagState.cooldown = math.min(tagState.cooldown + 0.2, 3)
		tagState.nextAt = os.clock() + math.min(0.3 * tagState.missRun, 1.2)
	end
	tagState.pending = false
	return landed
end

function G.tagStatusText()
	return string.format("%d ok / %d abgelehnt (%.2fs)", tagState.ok, tagState.rejected, tagState.cooldown)
end

-- Swing exactly like a left click (same range, cooldown and server checks)
function G.tag()
	local fn = findGameFn("Tag", "scripts.action.Tag")
	if not fn then
		return false
	end
	local ok, err = pcall(fn)
	if not ok then
		U.log("tag error", err)
	end
	return ok
end

function G.slide()
	local ev = U.RS.Events.game.player:FindFirstChild("SlideInput")
	if ev then
		ev:Fire()
		return true
	end
	return false
end

function G.role(player)
	local v = player and player:FindFirstChild("PlayerRole")
	return v and v.Value
end

-- dead/spectator roles have no business moving around
function G.isDeadRole()
	local rd = U.shared().roleData
	if rd and rd.DeadRole then
		return true
	end
	local role = G.role(U.lp)
	return role == "Dead" or role == "Spectator" or role == "Ashen"
end

-- the game keeps its own options; UpdateOption is what its own keybinds fire
function G.setOption(name, value)
	local ev = U.RS.Events.game.player:FindFirstChild("UpdateOption")
	if not ev then
		return false
	end
	ev:Fire(name, value)
	return true
end

function G.getOption(group, name)
	local opts = U.shared().options
	local g = opts and opts[group]
	return g and g[name]
end

function G.setThirdPerson(on, distance)
	G.setOption("ThirdPerson", on and true or false)
	if distance then
		G.setOption("ThirdPersonDistance", distance)
	end
	return true
end

-- Frozen, caged or anchored: the game pins the character, so steering is
-- pointless. Attributes are not always set, so the role name and the actually
-- measured movement count as well.
local stuckSince, lastPos = 0, nil
function G.isImmobile(commanded)
	local char = U.char()
	if not char then
		return true
	end
	if char:GetAttribute("Anchor") or char:GetAttribute("Frozen") or char:GetAttribute("Caged") or char:GetAttribute("Teleport") then
		return true
	end
	local m = U.shared().multipliers
	if m and (m.Anchored or m.DisableAllUtgMovement) then
		return true
	end
	local role = G.role(U.lp)
	if role == "Frozen" or role == "FrozenRed" or role == "FrozenBlue" or role == "FrozenInfected" then
		return true
	end
	local hrp = U.hrp(char)
	if commanded and hrp then
		local now = os.clock()
		if lastPos and (hrp.Position - lastPos).Magnitude < 0.5 then
			if stuckSince == 0 then
				stuckSince = now
			elseif now - stuckSince > 1.5 then
				return true
			end
		else
			stuckSince, lastPos = 0, hrp.Position
		end
		if not lastPos then
			lastPos = hrp.Position
		end
	else
		stuckSince, lastPos = 0, nil
	end
	return false
end

-- the vote screens cover the view; hiding them keeps the map readable
local VOTE_GUIS = { "MapVoting", "ModeVoting", "Voting" }
function G.hideVoting(hide)
	local gui = U.lp:FindFirstChild("PlayerGui")
	if not gui then
		return false
	end
	local touched = 0
	for _, name in ipairs(VOTE_GUIS) do
		local screen = gui:FindFirstChild(name)
		if screen and screen:IsA("ScreenGui") then
			if screen.Enabled == hide then
				screen.Enabled = not hide
			end
			touched += 1
		end
	end
	return touched > 0
end

function G.gamemode()
	local v = U.RS.Values:FindFirstChild("Gamemode")
	return v and v.Value
end

function G.mapName()
	local info = U.shared().currentMapInfo
	return info and info.Name
end

-- Port of ReplicatedFirst.Utils.GetTagTable
local function getTagTable(tagTables, victimRole)
	local gd = U.shared().gamemodeData
	if not (tagTables and gd) then
		return nil
	end
	if tagTables[victimRole] then
		return tagTables[victimRole]
	end
	local roles = gd.Roles
	for key, entry in pairs(tagTables) do
		if string.sub(key, 1, 4) == "Not-" and string.sub(key, 5) ~= victimRole and roles and roles[victimRole] then
			return entry
		end
	end
	local roleTags = roles and roles[victimRole] and roles[victimRole].RoleTags
	if roleTags then
		for key, entry in pairs(tagTables) do
			if table.find(roleTags, key) then
				return entry
			end
		end
		for key, entry in pairs(tagTables) do
			if string.sub(key, 1, 4) == "Not-" and string.sub(key, 5) ~= victimRole and not table.find(roleTags, key) then
				return entry
			end
		end
	end
	return nil
end

function G.tagEntry(attackerRole, victimRole)
	local gd = U.shared().gamemodeData
	local roleData = gd and gd.Roles and attackerRole and gd.Roles[attackerRole]
	return roleData and getTagTable(roleData.TagTables, victimRole)
end

-- true when the attacker's tag actually does something to the victim
function G.canTag(attackerRole, victimRole)
	local entry = G.tagEntry(attackerRole, victimRole)
	return entry ~= nil and next(entry) ~= nil
end

function G.hasNoTagBack(player)
	local char = player.Character
	return (char and char:GetAttribute("NoTagBack")) or player:GetAttribute("NoTagBack") or false
end

-- the game blocks a swing while the tag cooldown runs; swinging anyway only
-- wastes the aim window
function G.tagOnCooldown()
	local cds = U.shared().cooldowns
	local until_ = cds and cds.Tag
	return until_ ~= nil and until_ > time()
end

function G.tagRange()
	local m = U.shared().multipliers
	return 7 * ((m and m.RangeMultiplier) or 1)
end

function G.tagOrigin()
	local hrp = U.hrp()
	if not hrp then
		return nil
	end
	return hrp.Position + Vector3.new(0, U.shared().crouching and 0.25 or 1.5, 0)
end

function G.cameraValues(char)
	char = char or U.char()
	local values = char and char:FindFirstChild("values")
	if not values then
		return nil, nil
	end
	return values:FindFirstChild("CameraX"), values:FindFirstChild("CameraY")
end

function G.lookVector()
	local camX, camY = G.cameraValues()
	if not (camX and camY) then
		return nil
	end
	return (camY.Value * CFrame.Angles(math.rad(camX.Value), 0, 0)).LookVector
end

return G

end
__M["control"] = function()
-- Drives the character through the game's own input path:
-- CameraY/CameraX (facing + aim) and the ControlModule (move vector + jump)
local U = import("util")
local G = import("gameapi")

local C = {
	enabled = false,
	freeMovement = false, -- set by the boost module: move without turning
	moveDir = nil, -- world direction or nil
	aimPoint = nil, -- world point to face/aim at, overrides move facing
	idlePitch = -8,
	-- the movement direction itself is rate limited, the camera then follows
	-- it; that is what makes turns look like a fast mouse flick instead of a
	-- teleport, and it keeps momentum through corners
	dirRate = math.rad(540), -- rad/s for the desired move direction
	dirRateFast = math.rad(1100), -- while juking
	turnRate = math.rad(420), -- rad/s base camera turn
	turnRateMax = math.rad(1200), -- camera catches up on wide angles
	aimLerp = 14, -- exponential factor when aiming at a tag target
	pitchRate = 360, -- deg/s
	jumpHold = false,
	jumpUntil = 0,
	nudgeDir = nil,
	nudgeUntil = 0,
	throttle = 1, -- 0..1, the game scales walk speed with the vector length
	pitchGoal = nil, -- degrees, overrides the idle pitch while set
	pitchUntil = 0,
}

local maid = U.Maid.new()
local hookedModule = nil
local localMove = nil
local smoothDir = nil
local proxies = setmetatable({}, { __mode = "k" })

local function wantsJump()
	return C.jumpHold or os.clock() < C.jumpUntil
end

local function proxyFor(controller)
	local proxy = proxies[controller]
	if proxy then
		return proxy
	end
	proxy = setmetatable({}, {
		__index = function(_, key)
			if key == "GetIsJumping" then
				return function()
					return wantsJump() or controller:GetIsJumping()
				end
			end
			local value = controller[key]
			if type(value) == "function" then
				return function(_, ...)
					return value(controller, ...)
				end
			end
			return value
		end,
	})
	proxies[controller] = proxy
	return proxy
end

local function installHooks()
	local cm = U.shared().controlModule
	if not cm or hookedModule == cm then
		return
	end
	local ownMove, ownActive = rawget(cm, "GetMoveVector"), rawget(cm, "GetActiveController")
	local origMove, origActive = cm.GetMoveVector, cm.GetActiveController

	rawset(cm, "GetMoveVector", function(self, ...)
		if C.enabled and localMove then
			return localMove
		end
		return origMove(self, ...)
	end)
	rawset(cm, "GetActiveController", function(self, ...)
		local controller = origActive(self, ...)
		if C.enabled and controller then
			return proxyFor(controller)
		end
		return controller
	end)

	hookedModule = cm
	maid:give(function()
		rawset(cm, "GetMoveVector", ownMove)
		rawset(cm, "GetActiveController", ownActive)
		hookedModule = nil
	end)
	U.log("control hooks installed")
end

local function approach(current, target, maxStep)
	local diff = U.wrapAngle(target - current)
	if math.abs(diff) <= maxStep then
		return target
	end
	return current + math.sign(diff) * maxStep
end

-- rotate `cur` towards `goal` by at most maxRad (both flat unit vectors)
local function turnToward(cur, goal, maxRad)
	if not cur or cur.Magnitude < 0.05 then
		return goal
	end
	local dot = math.clamp(cur:Dot(goal), -1, 1)
	local angle = math.acos(dot)
	if angle <= maxRad then
		return goal
	end
	local sign = (cur:Cross(goal).Y >= 0) and 1 or -1
	local rotated = (CFrame.Angles(0, maxRad * sign, 0) * cur) * Vector3.new(1, 0, 1)
	if rotated.Magnitude < 0.05 then
		return goal
	end
	return rotated.Unit
end

local function step(dt)
	if not C.enabled then
		localMove, smoothDir = nil, nil
		return
	end
	installHooks()

	local hrp = U.hrp()
	local camX, camY = G.cameraValues()
	if not (hrp and camX and camY) then
		localMove = nil
		return
	end
	dt = math.min(dt, 0.1)

	local juking = C.nudgeDir and os.clock() < C.nudgeUntil
	local wanted = juking and C.nudgeDir or C.moveDir
	local flatWanted = wanted and U.flat(wanted) or nil
	if flatWanted and flatWanted.Magnitude > 0.05 then
		local goal = flatWanted.Unit
		local rate = juking and C.dirRateFast or C.dirRate
		smoothDir = turnToward(smoothDir, goal, rate * dt)
	elseif not wanted then
		smoothDir = nil
	end

	local yaw = U.yawOf(camY.Value.LookVector)
	local wantPitch = nil

	if C.aimPoint then
		-- aiming: ease onto the target so the swing still lines up
		local delta = C.aimPoint - (hrp.Position + Vector3.new(0, 1.5, 0))
		local flat = U.flat(delta)
		if flat.Magnitude > 0.05 then
			local goalYaw = U.yawOf(flat)
			local alpha = 1 - math.exp(-C.aimLerp * dt)
			yaw = yaw + U.wrapAngle(goalYaw - yaw) * alpha
			camY.Value = CFrame.Angles(0, yaw, 0)
		end
		wantPitch = math.deg(math.atan2(delta.Y, math.max(flat.Magnitude, 0.01)))
	elseif smoothDir and not C.freeMovement then
		-- camera follows the movement; wider angles are corrected faster so we
		-- do not lose the sprint (the game only sprints while moving forward)
		local goalYaw = U.yawOf(smoothDir)
		local diff = math.abs(U.wrapAngle(goalYaw - yaw))
		local rate = C.turnRate + (C.turnRateMax - C.turnRate) * math.min(diff / math.pi, 1)
		local stepRad = rate * dt
		local delta = U.wrapAngle(goalYaw - yaw)
		yaw = yaw + math.clamp(delta, -stepRad, stepRad)
		camY.Value = CFrame.Angles(0, yaw, 0)
		wantPitch = C.idlePitch
	end

	if C.pitchGoal and os.clock() < C.pitchUntil then
		wantPitch = C.pitchGoal
	end
	if wantPitch then
		local p = camX.Value
		local stepDeg = C.pitchRate * dt
		camX.Value = p + math.clamp(wantPitch - p, -stepDeg, stepDeg)
	end

	if smoothDir then
		local rel = CFrame.Angles(0, yaw, 0):VectorToObjectSpace(smoothDir)
		local t = (C.nudgeDir and os.clock() < C.nudgeUntil) and 1 or C.throttle
		localMove = Vector3.new(rel.X, 0, rel.Z) * t
	else
		localMove = wanted and Vector3.zero or nil
	end
end

function C.init()
	U.RunService:BindToRenderStep("utgap_control", Enum.RenderPriority.Input.Value - 1, step)
	maid:give(function()
		U.RunService:UnbindFromRenderStep("utgap_control")
	end)
end

function C.setEnabled(on)
	C.enabled = on and true or false
	if not C.enabled then
		C.stop()
	end
end

-- throttle < 1 is real braking: Humanoid:Move keeps the vector length
function C.move(dir, throttle)
	C.moveDir = dir
	C.throttle = math.clamp(throttle or 1, 0, 1)
end

function C.aim(point)
	C.aimPoint = point
end

-- A jump while climbing means letting go of the ladder, which is exactly how
-- you fall off it. Ladders are our main vertical shortcut, so guard them.
function C.climbing()
	local hum = U.hum()
	if hum and hum:GetState() == Enum.HumanoidStateType.Climbing then
		return true
	end
	return U.shared().touchingTruss == true
end

function C.jump(duration, force)
	if not force and C.climbing() then
		return false
	end
	C.jumpUntil = os.clock() + (duration or 0.12)
	return true
end

-- short sidestep that overrides steering: makes a chaser overshoot
-- the wallrun release reads the camera pitch, so we need to set it on purpose
function C.setPitch(deg, duration)
	C.pitchGoal = deg
	C.pitchUntil = os.clock() + (duration or 0.4)
end

function C.nudge(dir, duration)
	C.nudgeDir = dir
	C.nudgeUntil = os.clock() + (duration or 0.22)
end

function C.holdJump(on)
	C.jumpHold = on and true or false
end

function C.stop()
	C.moveDir = nil
	C.throttle = 1
	smoothDir = nil
	C.aimPoint = nil
	C.nudgeDir = nil
	C.nudgeUntil = 0
	C.jumpHold = false
	C.jumpUntil = 0
	localMove = nil
end

-- what the control layer is actually feeding the game right now
function C.debugInfo()
	local hum = U.hum()
	return {
		enabled = C.enabled,
		localMove = localMove,
		smoothDir = smoothDir,
		moveDir = C.moveDir,
		aim = C.aimPoint ~= nil,
		jump = wantsJump(),
		hooked = hookedModule ~= nil,
		walkSpeed = hum and hum.WalkSpeed,
		state = hum and tostring(hum:GetState()),
		moveDirection = hum and hum.MoveDirection,
	}
end

function C.shutdown()
	C.enabled = false
	C.stop()
	maid:clean()
end

return C

end
__M["gui"] = function()
-- Panel with toggle pills and a status block. The game locks the mouse to the
-- centre, so every toggle also has a hotkey; RightControl hides the panel.
local U = import("util")

local GUI = { toggles = {}, order = {} }
local maid = U.Maid.new()
local root, frame, body, togglesBox, statusBox, statusRows

local COL = {
	bg = Color3.fromRGB(20, 22, 28),
	stroke = Color3.fromRGB(44, 48, 60),
	header = Color3.fromRGB(28, 31, 40),
	text = Color3.fromRGB(236, 239, 246),
	dim = Color3.fromRGB(140, 147, 163),
	on = Color3.fromRGB(46, 170, 96),
	off = Color3.fromRGB(58, 63, 77),
	knob = Color3.fromRGB(245, 247, 252),
	accent = Color3.fromRGB(96, 165, 250),
}

local TweenService = game:GetService("TweenService")
local TWEEN = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function corner(inst, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = inst
	return c
end

local function listLayout(inst, padding)
	local l = Instance.new("UIListLayout")
	l.Padding = UDim.new(0, padding)
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.Parent = inst
	return l
end

local function label(parent, text, size, color, bold)
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham
	t.TextSize = size
	t.TextColor3 = color
	t.Text = text
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.Size = UDim2.new(1, 0, 0, size + 6)
	t.Parent = parent
	return t
end

function GUI.create(title, version, guiName)
	local sg = Instance.new("ScreenGui")
	sg.Name = guiName or "UTGAP"
	sg.ResetOnSpawn = false
	sg.DisplayOrder = 999
	sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	sg.Parent = (gethui and gethui()) or game:GetService("CoreGui")
	maid:give(sg)
	root = sg

	frame = Instance.new("Frame")
	frame.Size = UDim2.fromOffset(250, 0)
	frame.AutomaticSize = Enum.AutomaticSize.Y
	frame.Position = UDim2.new(0, 24, 0.3, 0)
	frame.BackgroundColor3 = COL.bg
	frame.BorderSizePixel = 0
	frame.Parent = sg
	corner(frame, 10)
	local stroke = Instance.new("UIStroke")
	stroke.Color = COL.stroke
	stroke.Thickness = 1
	stroke.Parent = frame
	listLayout(frame, 0)

	-- header doubles as the drag handle
	local header = Instance.new("TextButton")
	header.Size = UDim2.new(1, 0, 0, 34)
	header.BackgroundColor3 = COL.header
	header.BorderSizePixel = 0
	header.AutoButtonColor = false
	header.Text = ""
	header.Modal = true -- frees the cursor while the panel is open
	header.LayoutOrder = 0
	header.Parent = frame
	corner(header, 10)

	local dot = Instance.new("Frame")
	dot.Size = UDim2.fromOffset(8, 8)
	dot.Position = UDim2.new(0, 12, 0.5, -4)
	dot.BackgroundColor3 = COL.accent
	dot.BorderSizePixel = 0
	dot.Parent = header
	corner(dot, 4)

	local titleLabel = Instance.new("TextLabel")
	titleLabel.BackgroundTransparency = 1
	titleLabel.Position = UDim2.new(0, 28, 0, 0)
	titleLabel.Size = UDim2.new(1, -70, 1, 0)
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextSize = 13
	titleLabel.TextColor3 = COL.text
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Text = title
	titleLabel.Parent = header

	local ver = Instance.new("TextLabel")
	ver.BackgroundTransparency = 1
	ver.Position = UDim2.new(1, -46, 0, 0)
	ver.Size = UDim2.fromOffset(36, 34)
	ver.Font = Enum.Font.Gotham
	ver.TextSize = 11
	ver.TextColor3 = COL.dim
	ver.TextXAlignment = Enum.TextXAlignment.Right
	ver.Text = version or ""
	ver.Parent = header

	body = Instance.new("Frame")
	body.BackgroundTransparency = 1
	body.Size = UDim2.new(1, 0, 0, 0)
	body.AutomaticSize = Enum.AutomaticSize.Y
	body.LayoutOrder = 1
	body.Parent = frame
	listLayout(body, 6)
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 10)
	padding.PaddingRight = UDim.new(0, 10)
	padding.PaddingTop = UDim.new(0, 8)
	padding.PaddingBottom = UDim.new(0, 10)
	padding.Parent = body

	local featTitle = label(body, "FUNKTIONEN", 10, COL.dim, true)
	featTitle.LayoutOrder = 0

	togglesBox = Instance.new("Frame")
	togglesBox.BackgroundTransparency = 1
	togglesBox.Size = UDim2.new(1, 0, 0, 0)
	togglesBox.AutomaticSize = Enum.AutomaticSize.Y
	togglesBox.LayoutOrder = 1
	togglesBox.Parent = body
	listLayout(togglesBox, 3)

	local statTitle = label(body, "STATUS", 10, COL.dim, true)
	statTitle.LayoutOrder = 2

	statusBox = Instance.new("Frame")
	statusBox.BackgroundTransparency = 1
	statusBox.Size = UDim2.new(1, 0, 0, 0)
	statusBox.AutomaticSize = Enum.AutomaticSize.Y
	statusBox.LayoutOrder = 3
	statusBox.Parent = body
	listLayout(statusBox, 2)
	statusRows = {}

	local hint = label(body, "RCtrl blendet aus, Kopfzeile zum Ziehen", 10, COL.dim)
	hint.LayoutOrder = 4

	local dragging, dragStart, startPos = false, nil, nil
	maid:give(header.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging, dragStart, startPos = true, input.Position, frame.Position
		end
	end))
	maid:give(U.UIS.InputChanged:Connect(function(input)
		if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
			local d = input.Position - dragStart
			frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
		end
	end))
	maid:give(U.UIS.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = false
		end
	end))

	-- `processed` is ignored on purpose: the game marks some keys as processed;
	-- only typing into a TextBox (chat) blocks hotkeys
	maid:give(U.UIS.InputBegan:Connect(function(input, processed)
		if input.UserInputType ~= Enum.UserInputType.Keyboard or U.UIS:GetFocusedTextBox() then
			return
		end
		if input.KeyCode == Enum.KeyCode.RightControl then
			frame.Visible = not frame.Visible
			U.log("hotkey RightControl visible=", frame.Visible, "processed=", processed)
			return
		end
		for _, id in ipairs(GUI.order) do
			local t = GUI.toggles[id]
			if t.key and input.KeyCode == t.key then
				U.log("hotkey", t.key.Name, "->", id, not t.value, "processed=", processed)
				GUI.set(id, not t.value)
			end
		end
	end))
end

local function refresh(t)
	TweenService:Create(t.track, TWEEN, { BackgroundColor3 = t.value and COL.on or COL.off }):Play()
	TweenService:Create(t.knob, TWEEN, {
		Position = t.value and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7),
	}):Play()
	t.name.TextColor3 = t.value and COL.text or COL.dim
end

function GUI.addToggle(id, name, key, default, onChange)
	local row = Instance.new("TextButton")
	row.Size = UDim2.new(1, 0, 0, 26)
	row.BackgroundTransparency = 1
	row.AutoButtonColor = false
	row.Text = ""
	row.LayoutOrder = #GUI.order + 1
	row.Parent = togglesBox

	local nameLabel = Instance.new("TextLabel")
	nameLabel.BackgroundTransparency = 1
	nameLabel.Size = UDim2.new(1, -90, 1, 0)
	nameLabel.Font = Enum.Font.Gotham
	nameLabel.TextSize = 12
	nameLabel.TextColor3 = COL.dim
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Text = name
	nameLabel.Parent = row

	local keyLabel = Instance.new("TextLabel")
	keyLabel.BackgroundTransparency = 1
	keyLabel.Position = UDim2.new(1, -78, 0, 0)
	keyLabel.Size = UDim2.fromOffset(38, 26)
	keyLabel.Font = Enum.Font.Code
	keyLabel.TextSize = 10
	keyLabel.TextColor3 = COL.dim
	keyLabel.TextXAlignment = Enum.TextXAlignment.Right
	keyLabel.Text = key and key.Name or ""
	keyLabel.Parent = row

	local track = Instance.new("Frame")
	track.Size = UDim2.fromOffset(32, 18)
	track.Position = UDim2.new(1, -32, 0.5, -9)
	track.BackgroundColor3 = COL.off
	track.BorderSizePixel = 0
	track.Parent = row
	corner(track, 9)

	local knob = Instance.new("Frame")
	knob.Size = UDim2.fromOffset(14, 14)
	knob.Position = UDim2.new(0, 2, 0.5, -7)
	knob.BackgroundColor3 = COL.knob
	knob.BorderSizePixel = 0
	knob.Parent = track
	corner(knob, 7)

	local t = {
		id = id,
		key = key,
		value = default and true or false,
		onChange = onChange,
		row = row,
		name = nameLabel,
		track = track,
		knob = knob,
	}
	GUI.toggles[id] = t
	table.insert(GUI.order, id)
	refresh(t)

	maid:give(row.MouseButton1Click:Connect(function()
		GUI.set(id, not t.value)
	end))
	return t
end

function GUI.set(id, value)
	local t = GUI.toggles[id]
	if not t then
		return
	end
	t.value = value and true or false
	refresh(t)
	if t.onChange then
		local ok, err = pcall(t.onChange, t.value)
		if not ok then
			U.log("toggle error", id, err)
		end
	end
end

function GUI.get(id)
	local t = GUI.toggles[id]
	return t and t.value or false
end

-- rows: { {"Modus", "Crown"}, {"Map", "Bloxburg"} }
function GUI.setStatusRows(rows)
	if not statusBox then
		return
	end
	for i, pair in ipairs(rows) do
		local row = statusRows[i]
		if not row then
			local holder = Instance.new("Frame")
			holder.BackgroundTransparency = 1
			holder.Size = UDim2.new(1, 0, 0, 15)
			holder.LayoutOrder = i
			holder.Parent = statusBox
			local key = label(holder, "", 11, COL.dim)
			key.Size = UDim2.new(0.42, 0, 1, 0)
			local value = label(holder, "", 11, COL.text)
			value.Position = UDim2.new(0.42, 0, 0, 0)
			value.Size = UDim2.new(0.58, 0, 1, 0)
			value.TextTruncate = Enum.TextTruncate.AtEnd
			row = { holder = holder, key = key, value = value }
			statusRows[i] = row
		end
		row.holder.Visible = true
		row.key.Text = pair[1]
		row.value.Text = tostring(pair[2])
	end
	for i = #rows + 1, #statusRows do
		statusRows[i].holder.Visible = false
	end
end

function GUI.destroy()
	maid:clean()
	GUI.toggles, GUI.order = {}, {}
	root, frame, body, togglesBox, statusBox, statusRows = nil, nil, nil, nil, nil, nil
end

return GUI

end
__M["heap"] = function()
-- Binary min-heap of items ordered by keys[item]
local Heap = {}

function Heap.push(heap, keys, item)
	local i = #heap + 1
	heap[i] = item
	local key = keys[item]
	while i > 1 do
		local parent = i // 2
		if keys[heap[parent]] <= key then
			break
		end
		heap[i], heap[parent] = heap[parent], heap[i]
		i = parent
	end
end

function Heap.pop(heap, keys)
	local top = heap[1]
	local n = #heap
	local last = heap[n]
	heap[n] = nil
	n -= 1
	if n > 0 then
		heap[1] = last
		local i = 1
		while true do
			local l = i * 2
			local r = l + 1
			local smallest = i
			if l <= n and keys[heap[l]] < keys[heap[smallest]] then
				smallest = l
			end
			if r <= n and keys[heap[r]] < keys[heap[smallest]] then
				smallest = r
			end
			if smallest == i then
				break
			end
			heap[i], heap[smallest] = heap[smallest], heap[i]
			i = smallest
		end
	end
	return top
end

return Heap

end
__M["navgraph"] = function()
-- 2.5D navigation grid: columns of standable floor nodes (ascending y) with
-- per-node 8-neighbour bitmasks for walk / climb / drop edges plus a variable
-- length list of jump edges (gap jumps, later also specials).
local N = {}
N.__index = N

N.WALK, N.CLIMB, N.DROP, N.JUMP = 1, 2, 3, 4
N.OFFSETS = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 }, { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } }

local BITS = { 1, 2, 4, 8, 16, 32, 64, 128 }
N.BITS = BITS

function N.fromArrays(h, colCount, y, clear, walk, climb, drop, exStart, exTo, exKind)
	local cells = h.W * h.H
	local colStart = table.create(cells + 1, 0)
	local cx, cz = table.create(#y, 0), table.create(#y, 0)
	local acc = 1
	for c = 1, cells do
		colStart[c] = acc
		local ix, iz = (c - 1) % h.W, (c - 1) // h.W
		for i = acc, acc + colCount[c] - 1 do
			cx[i], cz[i] = ix, iz
		end
		acc += colCount[c]
	end
	colStart[cells + 1] = acc

	local n = #y
	if not exStart then
		exStart = table.create(n + 1, 1)
		for i = 1, n + 1 do
			exStart[i] = 1
		end
	end
	return setmetatable({
		h = h,
		W = h.W,
		H = h.H,
		sp = h.spacing,
		x0 = h.x0,
		z0 = h.z0,
		walkDy = h.walkDy,
		climbDy = h.climbDy,
		N = n,
		colStart = colStart,
		y = y,
		clear = clear,
		cx = cx,
		cz = cz,
		walk = walk or table.create(n, 0),
		climb = climb or table.create(n, 0),
		drop = drop or table.create(n, 0),
		exStart = exStart,
		exTo = exTo or {},
		exKind = exKind or {},
	}, N)
end

-- layout: u8 colCount per cell; per node i32 y*10, u8 clear*10, walk, climb,
-- drop, exCount; then per extra edge u32 target, u8 kind
function N.fromBuffer(h, buf)
	local cells = h.W * h.H
	local colCount = table.create(cells, 0)
	for c = 1, cells do
		colCount[c] = buffer.readu8(buf, c - 1)
	end
	local n = h.N
	local y, clear = table.create(n, 0), table.create(n, 0)
	local walk, climb, drop = table.create(n, 0), table.create(n, 0), table.create(n, 0)
	local exStart = table.create(n + 1, 1)
	local off = cells
	local acc = 1
	for i = 1, n do
		y[i] = buffer.readi32(buf, off) / 10
		clear[i] = buffer.readu8(buf, off + 4) / 10
		walk[i] = buffer.readu8(buf, off + 5)
		climb[i] = buffer.readu8(buf, off + 6)
		drop[i] = buffer.readu8(buf, off + 7)
		exStart[i] = acc
		acc += buffer.readu8(buf, off + 8)
		off += 9
	end
	exStart[n + 1] = acc
	local e = acc - 1
	local exTo, exKind = table.create(e, 0), table.create(e, 0)
	for k = 1, e do
		exTo[k] = buffer.readu32(buf, off)
		exKind[k] = buffer.readu8(buf, off + 4)
		off += 5
	end
	return N.fromArrays(h, colCount, y, clear, walk, climb, drop, exStart, exTo, exKind)
end

function N:toBuffer()
	local cells = self.W * self.H
	local e = #self.exTo
	local buf = buffer.create(cells + self.N * 9 + e * 5)
	for c = 1, cells do
		buffer.writeu8(buf, c - 1, math.min(self.colStart[c + 1] - self.colStart[c], 255))
	end
	local off = cells
	for i = 1, self.N do
		buffer.writei32(buf, off, math.floor(self.y[i] * 10 + 0.5))
		buffer.writeu8(buf, off + 4, math.clamp(math.floor(self.clear[i] * 10 + 0.5), 0, 255))
		buffer.writeu8(buf, off + 5, self.walk[i])
		buffer.writeu8(buf, off + 6, self.climb[i])
		buffer.writeu8(buf, off + 7, self.drop[i])
		buffer.writeu8(buf, off + 8, math.min(self.exStart[i + 1] - self.exStart[i], 255))
		off += 9
	end
	for k = 1, e do
		buffer.writeu32(buf, off, self.exTo[k])
		buffer.writeu8(buf, off + 4, self.exKind[k])
		off += 5
	end
	return buf
end

function N:byteSize()
	return self.W * self.H + self.N * 9 + #self.exTo * 5
end

-- 1-based column index or nil when outside the grid
function N:col(ix, iz)
	if ix < 0 or iz < 0 or ix >= self.W or iz >= self.H then
		return nil
	end
	return ix + iz * self.W + 1
end

function N:pos(i)
	return Vector3.new(self.x0 + self.cx[i] * self.sp, self.y[i], self.z0 + self.cz[i] * self.sp)
end

function N:walkTarget(c, ya)
	local best, bestD = nil, math.huge
	for j = self.colStart[c], self.colStart[c + 1] - 1 do
		local d = math.abs(self.y[j] - ya)
		if d <= self.walkDy and d < bestD then
			best, bestD = j, d
		end
	end
	return best
end

-- lowest node above walking range but within climb height
function N:climbTarget(c, ya)
	for j = self.colStart[c], self.colStart[c + 1] - 1 do
		local d = self.y[j] - ya
		if d > self.walkDy and d <= self.climbDy then
			return j
		end
	end
	return nil
end

-- highest node below walking range (the floor you land on)
function N:dropTarget(c, ya)
	local best = nil
	for j = self.colStart[c], self.colStart[c + 1] - 1 do
		if self.y[j] < ya - self.walkDy then
			best = j
		else
			break
		end
	end
	return best
end

-- fn(targetNode, edgeType, offsetIndex)
function N:forEachEdge(i, fn)
	local ix, iz, ya = self.cx[i], self.cz[i], self.y[i]
	local walk, climb, drop = self.walk[i], self.climb[i], self.drop[i]
	for k = 1, 8 do
		local bit = BITS[k]
		if bit32.btest(walk, bit) or bit32.btest(climb, bit) or bit32.btest(drop, bit) then
			local o = N.OFFSETS[k]
			local c = self:col(ix + o[1], iz + o[2])
			if c then
				if bit32.btest(walk, bit) then
					local j = self:walkTarget(c, ya)
					if j then
						fn(j, N.WALK, k)
					end
				end
				if bit32.btest(climb, bit) then
					local j = self:climbTarget(c, ya)
					if j then
						fn(j, N.CLIMB, k)
					end
				end
				if bit32.btest(drop, bit) then
					local j = self:dropTarget(c, ya)
					if j then
						fn(j, N.DROP, k)
					end
				end
			end
		end
	end
	for k = self.exStart[i], self.exStart[i + 1] - 1 do
		fn(self.exTo[k], self.exKind[k], 0)
	end
end

-- nearest standable node to a world position (prefers floors at/below feet).
-- Only stops widening the search once a candidate is vertically plausible,
-- otherwise a platform far above/below in the same column would win.
function N:nearest(pos, maxRing)
	local fx, fz = (pos.X - self.x0) / self.sp, (pos.Z - self.z0) / self.sp
	local bx, bz = math.floor(fx + 0.5), math.floor(fz + 0.5)
	local best, bestScore, bestVert = nil, math.huge, math.huge
	for ring = 0, maxRing or 6 do
		for dz = -ring, ring do
			for dx = -ring, ring do
				if math.max(math.abs(dx), math.abs(dz)) == ring then
					local c = self:col(bx + dx, bz + dz)
					if c then
						for j = self.colStart[c], self.colStart[c + 1] - 1 do
							local dy = pos.Y - self.y[j]
							-- above the node is normal (standing/jumping); below it is penalised
							local vert = dy >= -1.5 and dy or (-dy * 4)
							local hx, hz = bx + dx - fx, bz + dz - fz
							local score = (hx * hx + hz * hz) * self.sp * self.sp + vert * vert
							if score < bestScore then
								best, bestScore, bestVert = j, score, vert
							end
						end
					end
				end
			end
		end
		if best and ring >= 1 and bestVert < 8 then
			break
		end
	end
	return best
end

return N

end
__M["regions"] = function()
-- Coarse region graph on top of the node grid: walk-connected node groups per
-- BLOCK x BLOCK cells. Small enough for per-player distance fields every tick.
local N = import("navgraph")
local Heap = import("heap")

local R = { BLOCK = 6, CLIMB_COST = 4, DROP_COST = 0.5, JUMP_COST = 6 }

function R.build(g, yield)
	local B = R.BLOCK
	local regionOf = table.create(g.N, 0)
	local count, cxs, cys, czs = {}, {}, {}, {}
	local n = 0
	local queue = {}

	for i = 1, g.N do
		if regionOf[i] == 0 then
			n += 1
			local rid = n
			local bx, bz = g.cx[i] // B, g.cz[i] // B
			regionOf[i] = rid
			queue[1] = i
			local head, tail = 1, 1
			local c, sx, sy, sz = 0, 0, 0, 0
			while head <= tail do
				local cur = queue[head]
				head += 1
				c += 1
				sx += g.cx[cur]
				sy += g.y[cur]
				sz += g.cz[cur]
				g:forEachEdge(cur, function(j, kind)
					if kind == N.WALK and regionOf[j] == 0 and g.cx[j] // B == bx and g.cz[j] // B == bz then
						regionOf[j] = rid
						tail += 1
						queue[tail] = j
					end
				end)
			end
			count[rid] = c
			cxs[rid] = g.x0 + (sx / c) * g.sp
			cys[rid] = sy / c
			czs[rid] = g.z0 + (sz / c) * g.sp
			if yield then
				yield()
			end
		end
	end

	-- representative node: closest to the region centre
	local rep, repD = table.create(n, 0), table.create(n, math.huge)
	for i = 1, g.N do
		local r = regionOf[i]
		local dx = g.x0 + g.cx[i] * g.sp - cxs[r]
		local dz = g.z0 + g.cz[i] * g.sp - czs[r]
		local dy = g.y[i] - cys[r]
		local d = dx * dx + dz * dz + dy * dy
		if d < repD[r] then
			rep[r], repD[r] = i, d
		end
		if yield and i % 4000 == 0 then
			yield()
		end
	end

	-- directed region adjacency with min cost
	local adjMap = table.create(n)
	for r = 1, n do
		adjMap[r] = {}
	end
	for i = 1, g.N do
		local a = regionOf[i]
		local ax, ay, az = cxs[a], cys[a], czs[a]
		local m = adjMap[a]
		g:forEachEdge(i, function(j, kind)
			local b = regionOf[j]
			if b ~= a then
				local dx, dz = cxs[b] - ax, czs[b] - az
				local cost = math.sqrt(dx * dx + dz * dz) + math.abs(cys[b] - ay) * 0.25
				if kind == N.CLIMB then
					cost += R.CLIMB_COST
				elseif kind == N.DROP then
					cost += R.DROP_COST
				elseif kind == N.JUMP then
					cost += R.JUMP_COST
				end
				if not m[b] or cost < m[b] then
					m[b] = cost
				end
			end
		end)
		if yield and i % 2000 == 0 then
			yield()
		end
	end

	-- how many jump/special edges start in a region: a rough "fun to move" score
	local extras = table.create(n, 0)
	for i = 1, g.N do
		local c = g.exStart[i + 1] - g.exStart[i]
		if c > 0 then
			local r = regionOf[i]
			extras[r] += c
		end
	end

	local adjTo, adjCost, degree = table.create(n), table.create(n), table.create(n, 0)
	for r = 1, n do
		local to, cost = {}, {}
		for b, c in pairs(adjMap[r]) do
			table.insert(to, b)
			table.insert(cost, c)
		end
		adjTo[r], adjCost[r], degree[r] = to, cost, #to
	end

	return {
		n = n,
		g = g,
		regionOf = regionOf,
		count = count,
		cx = cxs,
		cy = cys,
		cz = czs,
		rep = rep,
		adjTo = adjTo,
		adjCost = adjCost,
		degree = degree,
		extras = extras,
	}
end

function R.center(reg, r)
	return Vector3.new(reg.cx[r], reg.cy[r], reg.cz[r])
end

-- sources: { [regionId] = startCost }; returns dist array (math.huge = unreachable)
function R.dijkstra(reg, sources, maxCost)
	local dist = table.create(reg.n, math.huge)
	local heap = {}
	for r, c in pairs(sources) do
		if c < dist[r] then
			dist[r] = c
			Heap.push(heap, dist, r)
		end
	end
	local done = {}
	maxCost = maxCost or math.huge
	while #heap > 0 do
		local r = Heap.pop(heap, dist)
		if not done[r] then
			done[r] = true
			local base = dist[r]
			if base > maxCost then
				break
			end
			local to, cost = reg.adjTo[r], reg.adjCost[r]
			for k = 1, #to do
				local b = to[k]
				local nc = base + cost[k]
				if nc < dist[b] then
					dist[b] = nc
					Heap.push(heap, dist, b)
				end
			end
		end
	end
	return dist
end

-- A* on regions; returns list of region ids or nil
function R.path(reg, a, b)
	if a == b then
		return { a }
	end
	local gs, fs, came = { [a] = 0 }, {}, {}
	local bx, by, bz = reg.cx[b], reg.cy[b], reg.cz[b]
	local function h(r)
		local dx, dz = reg.cx[r] - bx, reg.cz[r] - bz
		return math.sqrt(dx * dx + dz * dz) + math.abs(reg.cy[r] - by) * 0.25
	end
	fs[a] = h(a)
	local heap, closed = { a }, {}
	while #heap > 0 do
		local r = Heap.pop(heap, fs)
		if r == b then
			local list = {}
			while r do
				table.insert(list, 1, r)
				r = came[r]
			end
			return list
		end
		if not closed[r] then
			closed[r] = true
			local to, cost = reg.adjTo[r], reg.adjCost[r]
			for k = 1, #to do
				local nb = to[k]
				if not closed[nb] then
					local nc = gs[r] + cost[k]
					if gs[nb] == nil or nc < gs[nb] then
						gs[nb] = nc
						fs[nb] = nc + h(nb)
						came[nb] = r
						Heap.push(heap, fs, nb)
					end
				end
			end
		end
	end
	return nil
end

return R

end
__M["mapcache"] = function()
-- Map cache: map assets are private, so each map is scanned the first time it
-- is played and the navigation grid is stored in the workspace for later.
local U = import("util")
local N = import("navgraph")
local R = import("regions")

local M = {
	FORMAT = 10,
	SPACING = 2,
	STAND_H = 4.8,
	CROUCH_H = 2.6,
	WALK_DY = 1.6,
	CLIMB_DY = 5.8,
	VAULT_ASSIST = 3.2,
	VAULT_REACH = 9,
	MAX_LAYERS = 16,
	-- these match the boosted movement (speed ~1.3x, jump 1.1x, gravity 0.95x)
	-- with a safety margin, because an edge we cannot make is worse than a
	-- missing one
	RUN_SPEED = 34,
	JUMP_VY = 30,
	GRAVITY = 72,
	JUMP_RANGE = 30,
	JUMP_DROP = 45,
	MAX_JUMPS = 10,
	BUDGET = 0.005, -- seconds of scan work per frame
	DIR = "utgap/maps",
	status = "idle",
	progress = 0,
	graph = nil,
	header = nil,
	mapKey = nil,
	lastBuild = nil,
}

local maid = U.Maid.new()
local job = 0

local function fileKey(name)
	return (name:gsub("[^%w_-]", "_"))
end

local function makeParams(folder)
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Include
	rp.FilterDescendantsInstances = { folder, workspace.Terrain }
	rp.RespectCanCollide = true
	rp.CollisionGroup = "Player"
	local op = OverlapParams.new()
	op.FilterType = Enum.RaycastFilterType.Include
	op.FilterDescendantsInstances = { folder, workspace.Terrain }
	op.RespectCanCollide = true
	op.CollisionGroup = "Player"
	op.MaxParts = 1
	return rp, op
end

local function cfList(cf)
	local t = { cf:GetComponents() }
	for i, v in ipairs(t) do
		t[i] = math.floor(v * 1000 + 0.5) / 1000
	end
	return t
end

local function survey(folder)
	local minX, minY, minZ = math.huge, math.huge, math.huge
	local maxX, maxY, maxZ = -math.huge, -math.huge, -math.huge
	local parts, specials = 0, {}

	local function add(kind, part, extra)
		local s = part.Size
		table.insert(specials, { k = kind, cf = cfList(part.CFrame), s = { s.X, s.Y, s.Z }, x = extra })
	end

	for _, d in ipairs(folder:GetDescendants()) do
		if d:IsA("BasePart") then
			parts += 1
			if d.CanCollide and d.Size.Magnitude < 1500 then
				local cf, s = d.CFrame, d.Size * 0.5
				local r, u, l = cf.RightVector, cf.UpVector, cf.LookVector
				local ex = math.abs(r.X) * s.X + math.abs(u.X) * s.Y + math.abs(l.X) * s.Z
				local ey = math.abs(r.Y) * s.X + math.abs(u.Y) * s.Y + math.abs(l.Y) * s.Z
				local ez = math.abs(r.Z) * s.X + math.abs(u.Z) * s.Y + math.abs(l.Z) * s.Z
				local p = cf.Position
				minX, maxX = math.min(minX, p.X - ex), math.max(maxX, p.X + ex)
				minY, maxY = math.min(minY, p.Y - ey), math.max(maxY, p.Y + ey)
				minZ, maxZ = math.min(minZ, p.Z - ez), math.max(maxZ, p.Z + ez)
			end
			if d:GetAttribute("SwingBar") then
				add("swingbar", d)
			end
			if d:GetAttribute("RailCollision") or d:GetAttribute("RailGrind") then
				add("rail", d)
			end
			if d:GetAttribute("Lava") or (d:GetAttribute("ContactDamage") or 0) > 0 then
				add("hazard", d, d:GetAttribute("ContactDamage"))
			end
			if d:GetAttribute("Wallrun") then
				add("wallrun", d, d:GetAttribute("Speed"))
			end
			if d:GetAttribute("BounceAmount") then
				add("bounce", d, d:GetAttribute("BounceAmount"))
			end
			if d:GetAttribute("CanBeBroken") or d:GetAttribute("Smashable") then
				add("breakable", d)
			end
			if d:GetAttribute("WindForce") then
				add("wind", d, d:GetAttribute("WindForce"))
			end
			if d:GetAttribute("RopeGrab") then
				add("rope", d)
			end
			if d:IsA("TrussPart") then
				add("truss", d)
			end
			if d:IsA("SpawnLocation") or (d.Parent and d.Parent.Name == "Spawns") then
				add("spawn", d)
			end
			if d:FindFirstChildOfClass("TouchTransmitter") then
				add("touch", d, d.Name)
			end
		elseif d:IsA("Model") and d:GetAttribute("Zipline") then
			local zip = d:FindFirstChild("ZipPart")
			local top = zip and zip:FindFirstChild("TopAttachment")
			if zip and top then
				add("zipline", zip, { top = cfList(top.WorldCFrame), length = zip.Size.Z })
			end
		end
	end

	return {
		parts = parts,
		min = Vector3.new(minX, minY, minZ),
		max = Vector3.new(maxX, maxY, maxZ),
		specials = specials,
	}
end

local function fingerprint(sv)
	return {
		parts = sv.parts,
		bounds = {
			math.floor(sv.min.X),
			math.floor(sv.min.Z),
			math.floor(sv.max.X),
			math.floor(sv.max.Z),
		},
	}
end

-- destruction during a round removes parts, so allow small differences
local function fingerprintMatches(a, b)
	if not (a and b and a.bounds and b.bounds) then
		return false
	end
	if math.abs(a.parts - b.parts) > math.max(25, a.parts * 0.03) then
		return false
	end
	for i = 1, 4 do
		if math.abs(a.bounds[i] - b.bounds[i]) > 4 then
			return false
		end
	end
	return true
end

local function checkJob(st)
	if os.clock() - st.t > M.BUDGET then
		U.RunService.Heartbeat:Wait()
		st.t = os.clock()
		if st.job ~= job then
			error("cancelled", 0)
		end
	end
end

-- the game marks damaging surfaces with attributes; standing there is a loss
local function isHarmful(inst)
	if not inst then
		return false
	end
	if inst:GetAttribute("Lava") or (inst:GetAttribute("ContactDamage") or 0) > 0 then
		return true
	end
	local parent = inst.Parent
	if parent and (parent:GetAttribute("Lava") or (parent:GetAttribute("ContactDamage") or 0) > 0) then
		return true
	end
	return false
end

-- The character is about 2 studs wide, so a single centre line happily walks
-- through door frames, pillars and wall corners. Check the body width.
local function clearBetween(ax, az, bx, bz, baseY, rp, crouchOnly)
	local dir = Vector3.new(bx - ax, 0, bz - az)
	local len = dir.Magnitude
	if len < 0.01 then
		return true
	end
	local side = Vector3.new(-dir.Z / len, 0, dir.X / len) * 0.8
	if workspace:Raycast(Vector3.new(ax, baseY + 1.1, az), dir, rp) then
		return false
	end
	if crouchOnly then
		-- sliding fits through gaps that would block a standing character
		return true
	end
	for _, offset in ipairs({ Vector3.new(0, 0, 0), side, -side }) do
		local from = Vector3.new(ax, baseY + 3.6, az) + offset
		if workspace:Raycast(from, dir, rp) then
			return false
		end
	end
	return true
end

local function build(folder, sv, st)
	local rp, op = makeParams(folder)
	local sp = M.SPACING
	local x0, z0 = math.floor(sv.min.X), math.floor(sv.min.Z)
	local W = math.floor((sv.max.X - x0) / sp) + 1
	local H = math.floor((sv.max.Z - z0) / sp) + 1
	local void = workspace:GetAttribute("VoidHeight")
	local topY = sv.max.Y + 8
	-- maps are wrapped in enormous barrier slabs; nodes on those are useless
	local barrierY = sv.min.Y + (sv.max.Y - sv.min.Y) * 0.55
	local botY = math.max(sv.min.Y - 4, (void or -10000) - 1)
	local cells = W * H

	-- pass 1: floors per column
	local colCount = table.create(cells, 0)
	local ys, clears = {}, {}
	local upDir = Vector3.new(0, 20, 0)
	local found = {}
	for iz = 0, H - 1 do
		for ix = 0, W - 1 do
			local x, z = x0 + ix * sp, z0 + iz * sp
			local y = topY
			table.clear(found)
			for _ = 1, M.MAX_LAYERS do
				local res = workspace:Raycast(Vector3.new(x, y, z), Vector3.new(0, botY - y, 0), rp)
				if not res then
					break
				end
				local hy = res.Position.Y
				local inst = res.Instance
				local huge = inst.Size.X > 300 or inst.Size.Z > 300
				if res.Normal.Y >= 0.6 and (not void or hy > void) and not (huge and hy > barrierY) and not isHarmful(inst) then
					local up = workspace:Raycast(Vector3.new(x, hy + 0.05, z), upDir, rp)
					local clear = up and (up.Position.Y - hy) or 20
					if clear >= M.CROUCH_H then
						local h = math.min(clear, M.STAND_H) - 0.6
						local center = Vector3.new(x, hy + 0.3 + h * 0.5, z)
						if #workspace:GetPartBoundsInBox(CFrame.new(center), Vector3.new(1.2, h, 1.2), op) == 0 then
							table.insert(found, hy)
							table.insert(found, clear)
						end
					end
				end
				y = hy - 0.05
			end
			local count = #found // 2
			-- found is top-down; store ascending
			for k = count, 1, -1 do
				table.insert(ys, found[k * 2 - 1])
				table.insert(clears, found[k * 2])
			end
			colCount[ix + iz * W + 1] = math.min(count, 255)
			checkJob(st)
		end
		M.progress = 0.5 * (iz + 1) / H
	end

	local h = {
		format = M.FORMAT,
		spacing = sp,
		x0 = x0,
		z0 = z0,
		W = W,
		H = H,
		walkDy = M.WALK_DY,
		climbDy = M.CLIMB_DY,
		standH = M.STAND_H,
		topY = topY,
		void = void,
	}
	local g = N.fromArrays(h, colCount, ys, clears)

	-- pass 2: edges
	local BITS = N.BITS
	-- index of the two orthogonal neighbours that belong to each diagonal
	local DIAG_PARTS = { [5] = { 1, 3 }, [6] = { 1, 4 }, [7] = { 2, 3 }, [8] = { 2, 4 } }
	for i = 1, g.N do
		local ax, az, ya = g.cx[i], g.cz[i], g.y[i]
		local wx, wz = x0 + ax * sp, z0 + az * sp
		local walk, climb, drop = 0, 0, 0
		for k, o in ipairs(N.OFFSETS) do
			local c = g:col(ax + o[1], az + o[2])
			if c then
				local bx, bz = wx + o[1] * sp, wz + o[2] * sp
				local wj = g:walkTarget(c, ya)
				if wj then
					local crouch = g.clear[wj] < M.STAND_H or g.clear[i] < M.STAND_H
					if clearBetween(wx, wz, bx, bz, math.max(ya, g.y[wj]), rp, crouch) then
						walk += BITS[k]
					end
				else
					local dj = g:dropTarget(c, ya)
					if dj and clearBetween(wx, wz, bx, bz, ya, rp) then
						drop += BITS[k]
					end
				end
				local cj = g:climbTarget(c, ya)
				if cj and g.clear[i] >= (g.y[cj] - ya) + 3 and clearBetween(wx, wz, bx, bz, g.y[cj], rp) then
					climb += BITS[k]
				end
			end
		end
		-- a diagonal is only walkable when both of its orthogonal halves are:
		-- otherwise the line slips straight through the corner of a wall
		for k, parts in pairs(DIAG_PARTS) do
			local bit = BITS[k]
			if bit32.btest(walk, bit) then
				if not (bit32.btest(walk, BITS[parts[1]]) and bit32.btest(walk, BITS[parts[2]])) then
					walk -= bit
				end
			end
		end
		g.walk[i], g.climb[i], g.drop[i] = walk, climb, drop
		checkJob(st)
		if i % 2000 == 0 then
			M.progress = 0.5 + 0.3 * i / g.N
		end
	end

	-- pass 3: gap jumps. Running speed plus jump power reaches surprisingly far
	-- (~24 studs), which is what makes most of a map connected. Every jump is
	-- also checked in reverse, otherwise the graph ends up full of one-way edges.
	local exList = table.create(g.N)
	local function addExtra(a, b, kind)
		if not (a and b) or a == b then
			return
		end
		local t = exList[a]
		if not t then
			t = {}
			exList[a] = t
		end
		if #t >= M.MAX_JUMPS then
			return
		end
		for _, v in ipairs(t) do
			if v[1] == b then
				return
			end
		end
		t[#t + 1] = { b, kind }
	end
	local function addJump(a, b)
		addExtra(a, b, N.JUMP)
	end

	local function apexAt(y0, t)
		return y0 + M.JUMP_VY * t - 0.5 * M.GRAVITY * t * t
	end

	-- the body is about 2 studs wide, so the arc is checked on three lines and
	-- all the way to the target instead of stopping short of it
	local function arcClear(a, b, tTotal)
		local flat = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
		local side = Vector3.new(0, 0, 0)
		if flat.Magnitude > 0.1 then
			local unit = flat.Unit
			side = Vector3.new(-unit.Z, 0, unit.X) * 0.9
		end
		for _, offset in ipairs({ Vector3.new(0, 0, 0), side, -side }) do
			local prev = a + offset
			for step = 1, 6 do
				local f = step / 6
				local ts = tTotal * f
				local p = Vector3.new(
					a.X + (b.X - a.X) * f,
					apexAt(a.Y, ts),
					a.Z + (b.Z - a.Z) * f
				) + offset
				if workspace:Raycast(prev, p - prev, rp) then
					return false
				end
				prev = p
			end
		end
		return true
	end

	for i = 1, g.N do
		if g.clear[i] >= M.STAND_H then
			local ya = g.y[i]
			local ix, iz = g.cx[i], g.cz[i]
			local aPos = Vector3.new(x0 + ix * sp, ya + 2.5, z0 + iz * sp)
			for k, o in ipairs(N.OFFSETS) do
				-- only jump where walking does not already work (a gap or a wall)
				if not bit32.btest(g.walk[i], N.BITS[k]) then
					local stepLen = math.sqrt(o[1] * o[1] + o[2] * o[2]) * sp
					local steps = math.floor(M.JUMP_RANGE / stepLen)
					local added = 0
					for m = 2, steps do
						local c = g:col(ix + o[1] * m, iz + o[2] * m)
						if c then
							local t = (stepLen * m) / M.RUN_SPEED
							local ymax = apexAt(ya, t)
							-- within vault reach the ledge itself throws us up, so the
							-- arc may end higher than a plain jump would
							local assist = (stepLen * m <= M.VAULT_REACH) and M.VAULT_ASSIST or 0
							for j = g.colStart[c], g.colStart[c + 1] - 1 do
								local yj = g.y[j]
								if yj <= ymax + 0.3 + assist and yj > ya - M.JUMP_DROP and g.clear[j] >= M.CROUCH_H then
									local bPos = Vector3.new(x0 + g.cx[j] * sp, yj + 2.5, z0 + g.cz[j] * sp)
									if arcClear(aPos, bPos, t) then
										addJump(i, j)
										-- same distance backwards: only the height has to work out
										if g.clear[j] >= M.STAND_H and ya <= apexAt(yj, t) + 0.3 + assist then
											addJump(j, i)
										end
										added += 1
									end
									break
								end
							end
						end
						if added >= 2 then
							break
						end
					end
				end
			end
		end
		checkJob(st)
		if i % 2000 == 0 then
			M.progress = 0.8 + 0.2 * i / g.N
		end
	end

	-- pass 4: climbable trusses and ziplines, which are often the only way back
	-- up after a long drop
	local function nodeNear(pos, maxDrop)
		local n = g:nearest(pos, 4)
		if not n then
			return nil
		end
		local q = g:pos(n)
		local dy = q.Y - pos.Y
		if dy > 4 or dy < -(maxDrop or 6) then
			return nil
		end
		if math.abs(q.X - pos.X) > 8 or math.abs(q.Z - pos.Z) > 8 then
			return nil
		end
		return n
	end

	local trusses, ziplines = 0, 0
	for _, d in ipairs(folder:GetDescendants()) do
		if d:IsA("TrussPart") then
			-- a ladder is only useful if every landing it passes is connected,
			-- not just its two ends
			local cf, size = d.CFrame, d.Size
			local up = cf.UpVector
			local bottom = cf.Position - up * (size.Y * 0.5)
			local levels = {}
			local step = 4
			for h = 0, size.Y, step do
				local n = nodeNear(bottom + up * h + Vector3.new(0, 1, 0), 5)
				if n and n ~= levels[#levels] then
					levels[#levels + 1] = n
				end
			end
			local topNode = nodeNear(cf.Position + up * (size.Y * 0.5) + Vector3.new(0, 1.5, 0), 6)
			if topNode and topNode ~= levels[#levels] then
				levels[#levels + 1] = topNode
			end
			if #levels > 1 then
				for k = 1, #levels - 1 do
					addExtra(levels[k], levels[k + 1], N.CLIMB)
					addExtra(levels[k + 1], levels[k], N.DROP)
				end
				trusses += 1
			end
		elseif d:IsA("Model") and d:GetAttribute("Zipline") then
			local zip = d:FindFirstChild("ZipPart")
			local top = zip and zip:FindFirstChild("TopAttachment")
			if zip and top then
				local a = top.WorldPosition
				local b = a + top.WorldCFrame.LookVector * zip.Size.Z
				local na, nb = nodeNear(a, 12), nodeNear(b, 12)
				if na and nb then
					-- ziplines are ridden downhill
					if g.y[na] >= g.y[nb] then
						addExtra(na, nb, N.JUMP)
					else
						addExtra(nb, na, N.JUMP)
					end
					ziplines += 1
				end
			end
		end
		checkJob(st)
	end
	M.lastSpecialEdges = { trusses = trusses, ziplines = ziplines }

	local exStart, exTo, exKind = table.create(g.N + 1, 1), {}, {}
	for i = 1, g.N do
		exStart[i] = #exTo + 1
		local t = exList[i]
		if t then
			for _, e in ipairs(t) do
				table.insert(exTo, e[1])
				table.insert(exKind, e[2])
			end
		end
	end
	exStart[g.N + 1] = #exTo + 1
	g.exStart, g.exTo, g.exKind = exStart, exTo, exKind

	return g, h
end

local function save(key, header, g)
	if not isfolder(M.DIR) then
		makefolder(M.DIR)
	end
	writefile(M.DIR .. "/" .. key .. ".json", U.HttpService:JSONEncode(header))
	writefile(M.DIR .. "/" .. key .. ".bin", buffer.tostring(g:toBuffer()))
end

local function tryLoad(key, fp)
	local jsonPath, binPath = M.DIR .. "/" .. key .. ".json", M.DIR .. "/" .. key .. ".bin"
	if not (isfile(jsonPath) and isfile(binPath)) then
		return nil
	end
	local ok, header = pcall(function()
		return U.HttpService:JSONDecode(readfile(jsonPath))
	end)
	if not ok or type(header) ~= "table" then
		return nil
	end
	if header.format ~= M.FORMAT or header.spacing ~= M.SPACING or header.walkDy ~= M.WALK_DY or header.climbDy ~= M.CLIMB_DY or header.standH ~= M.STAND_H then
		return nil
	end
	if not fingerprintMatches(header.fingerprint, fp) then
		return nil
	end
	local bin = readfile(binPath)
	local expected = header.W * header.H + header.N * 9 + (header.E or 0) * 5
	if #bin ~= expected then
		U.log("map cache size mismatch", key, #bin, expected)
		return nil
	end
	return N.fromBuffer(header, buffer.fromstring(bin)), header
end

local function waitForStableMap(folder, st)
	local last, stable = -1, 0
	local deadline = os.clock() + 30
	while stable < 2 and os.clock() < deadline do
		local count = #folder:GetDescendants()
		if count == last and count > 0 then
			stable += 1
		else
			stable = 0
		end
		last = count
		task.wait(0.5)
		if st.job ~= job then
			error("cancelled", 0)
		end
	end
end

local function finalize(g, header, st, label)
	M.status = "Regionen"
	st.t = os.clock()
	local t0 = os.clock()
	local regions = R.build(g, function()
		checkJob(st)
	end)
	M.graph, M.header, M.regions = g, header, regions
	M.status, M.progress = label, 1
	U.log("regions built", regions.n, string.format("%.2fs", os.clock() - t0))
end

local function process(folder, force)
	job += 1
	local st = { job = job, t = os.clock() }
	M.graph, M.header, M.regions, M.mapKey = nil, nil, nil, folder.Name
	M.status, M.progress = "warte auf Map", 0

	task.spawn(function()
		local ok, err = pcall(function()
			waitForStableMap(folder, st)
			local key = fileKey(folder.Name)
			local sv = survey(folder)
			local fp = fingerprint(sv)

			if not force then
				local t0 = os.clock()
				local g, header = tryLoad(key, fp)
				if g then
					U.log("map cache loaded", key, "nodes", g.N, string.format("%.2fs", os.clock() - t0))
					finalize(g, header, st, "geladen")
					return
				end
			end

			M.status = "scanne"
			local t0 = os.clock()
			st.t = os.clock()
			local g, header = build(folder, sv, st)
			header.key = folder.Name
			header.fingerprint = fp
			header.N = g.N
			header.E = #g.exTo
			header.specials = sv.specials
			header.built = os.time()
			header.buildSeconds = os.clock() - t0
			save(key, header, g)
			finalize(g, header, st, "gescannt")
			M.lastBuild = { key = key, seconds = header.buildSeconds, nodes = g.N, extraEdges = #g.exTo, special = M.lastSpecialEdges, cells = header.W * header.H, specials = #sv.specials }
			U.log("map cache built", key, "nodes", g.N, "jumps", #g.exTo, "cells", header.W * header.H, string.format("%.1fs", header.buildSeconds))
		end)
		if not ok and err ~= "cancelled" then
			M.status = "Fehler"
			U.log("map cache error", err)
		end
	end)
end

function M.start()
	local cm = workspace:WaitForChild("CurrentMap")
	maid:give(cm.ChildAdded:Connect(function(child)
		process(child)
	end))
	maid:give(cm.ChildRemoved:Connect(function()
		if not cm:GetChildren()[1] then
			job += 1
			M.graph, M.header, M.regions, M.mapKey = nil, nil, nil, nil
			M.status, M.progress = "keine Map", 0
		end
	end))
	local current = cm:GetChildren()[1]
	if current then
		process(current)
	else
		M.status = "keine Map"
	end
end

function M.rebuild()
	local current = workspace.CurrentMap:GetChildren()[1]
	if current then
		process(current, true)
	end
end

function M.statusText()
	if M.status == "scanne" then
		return string.format("scanne %d%%", math.floor(M.progress * 100))
	end
	if M.status == "Regionen" then
		return "berechne Regionen"
	end
	if M.graph then
		return string.format("%s (%d Knoten, %d Regionen)", M.status, M.graph.N, M.regions and M.regions.n or 0)
	end
	return M.status
end

function M.stop()
	job += 1
	maid:clean()
end

return M

end
__M["learn"] = function()
-- Experience per map: which nodes of the graph keep failing us (a jump that
-- falls short, a ladder that throws us off, a corner we get stuck on). The
-- path search pays extra for them, so after a few rounds on a map the routes
-- avoid the moves that do not work for this character. Saved per map.
local U = import("util")

local L = {
	DIR = "utgap/learn",
	failCost = { walk = 6, special = 14 },
	maxPenalty = 60,
	halfLife = 1800, -- seconds of real time until a penalty is halved
	key = nil,
	penalty = {}, -- node -> cost
	stamp = {}, -- node -> os.time() of the last change
	dirty = false,
	-- as a ghost nothing collides, so every "failure" would be made up
	enabled = true,
	lastSave = 0,
	fails = 0,
	successes = 0,
}

local function ensureDir()
	if not isfolder("utgap") then
		makefolder("utgap")
	end
	if not isfolder(L.DIR) then
		makefolder(L.DIR)
	end
end

local function decayed(node, now)
	local p = L.penalty[node]
	if not p then
		return 0
	end
	local age = now - (L.stamp[node] or now)
	return p * 0.5 ^ (age / L.halfLife)
end

function L.save()
	if not (L.key and L.dirty) then
		return
	end
	L.dirty = false
	L.lastSave = os.clock()
	local now = os.time()
	local out = {}
	for node in pairs(L.penalty) do
		local p = decayed(node, now)
		if p > 0.5 then
			out[#out + 1] = { node, math.floor(p * 10 + 0.5) / 10 }
		end
	end
	pcall(function()
		ensureDir()
		writefile(L.DIR .. "/" .. L.key .. ".json", U.HttpService:JSONEncode({ t = now, nodes = out }))
	end)
end

-- key includes the node count, so a rebuilt graph never inherits wrong ids
function L.bind(mapKey, g)
	local key = mapKey and g and (mapKey .. "_" .. g.N) or nil
	-- the graph is briefly nil while a map is scanned; that is not a new map
	-- and must not throw away what we know
	if key == nil or key == L.key then
		return
	end
	L.save()
	L.key, L.penalty, L.stamp, L.dirty = key, {}, {}, false
	local ok, data = pcall(function()
		return U.HttpService:JSONDecode(readfile(L.DIR .. "/" .. key .. ".json"))
	end)
	if ok and type(data) == "table" and type(data.nodes) == "table" then
		local t = data.t or os.time()
		for _, entry in ipairs(data.nodes) do
			L.penalty[entry[1]] = entry[2]
			L.stamp[entry[1]] = t
		end
		U.log("learn: loaded", #data.nodes, "penalties for", key)
	end
end

-- neighbours share a bit of the blame: the grid is 2 studs, the real cause is
-- rarely exactly one node
function L.fail(g, node, special, why)
	if not (L.enabled and L.key and g and node) then
		return
	end
	local now = os.time()
	local add = special and L.failCost.special or L.failCost.walk
	local function bump(n, amount)
		L.penalty[n] = math.min(decayed(n, now) + amount, L.maxPenalty)
		L.stamp[n] = now
	end
	bump(node, add)
	local p = g:pos(node)
	for _, ring in ipairs({ 1, 2 }) do
		local near = g:nearest(p + Vector3.new(ring * g.sp, 0, 0), 1)
		if near and near ~= node then
			bump(near, add * 0.35)
		end
		near = g:nearest(p + Vector3.new(0, 0, ring * g.sp), 1)
		if near and near ~= node then
			bump(near, add * 0.35)
		end
	end
	L.fails += 1
	L.dirty = true
	U.log("learn: fail", node, why or "")
end

function L.success(node)
	local p = node and L.penalty[node]
	if not p then
		return
	end
	L.penalty[node] = decayed(node, os.time()) * 0.6
	L.stamp[node] = os.time()
	L.successes += 1
	L.dirty = true
end

-- the path search reads this table directly, so keep it a plain lookup
function L.costOf(node)
	return L.penalty[node]
end

function L.tick()
	if L.dirty and os.clock() - L.lastSave > 20 then
		L.save()
	end
end

function L.statusText()
	local n = 0
	for _ in pairs(L.penalty) do
		n += 1
	end
	return string.format("%d Stellen, %d Fehler / %d ok", n, L.fails, L.successes)
end

return L

end
__M["pathfind"] = function()
-- Node-level A*, optionally restricted to a corridor of regions
local N = import("navgraph")
local Heap = import("heap")
local R = import("regions")

local P = {
	maxExpansions = 60000,
	climbCost = 4,
	dropCost = 0.5,
	jumpCost = 6,
	crouchCost = 3,
}

-- "fast" avoids risky moves, "style" actively looks for gaps, climbs and
-- jumps because that is what makes a route look like parkour
P.PROFILES = {
	fast = { climb = 4, drop = 0.5, jump = 6, crouch = 3 },
	style = { climb = 0.5, drop = 0.2, jump = -1.5, crouch = 1 },
	-- hunting someone above us: ladders and climbs are the short way up, a long
	-- ramp around the building is not
	chaseUp = { climb = 1.5, drop = 0.3, jump = 3, crouch = 2 },
	-- running away: take the lines a chaser struggles to copy. Gaps, crawl
	-- holes and climbs are cheap, plain open ground is not.
	evade = { climb = 0.5, drop = 0.1, jump = -2.5, crouch = -1.5, openPenalty = 0.35 },
}
P.profile = P.PROFILES.fast

function P.setProfile(name)
	P.profile = P.PROFILES[name] or P.PROFILES.fast
end

local function edgeCost(g, from, to, kind)
	local dx = (g.cx[to] - g.cx[from]) * g.sp
	local dz = (g.cz[to] - g.cz[from]) * g.sp
	local dy = g.y[to] - g.y[from]
	local cost = math.sqrt(dx * dx + dz * dz) + math.abs(dy) * 0.15
	local prof = P.profile
	if kind == N.CLIMB then
		cost += prof.climb
	elseif kind == N.DROP then
		cost += prof.drop
	elseif kind == N.JUMP then
		cost += prof.jump
	end
	if g.clear[to] < g.h.standH then
		cost += prof.crouch
	end
	if prof.openPenalty and kind == N.WALK then
		-- plain running is what a pursuer is best at, so make it slightly dear
		cost += prof.openPenalty
	end
	-- learned: spots where this character failed before on this map
	local learned = P.penalty and P.penalty[to]
	if learned then
		cost += learned
	end
	-- never let a discount make an edge free, A* needs positive costs
	return math.max(cost, 0.5)
end

-- allowed: optional set of region ids, regionOf: node -> region
-- returns { nodes, kinds, cost, expanded } or nil
function P.find(g, start, goal, allowed, regionOf)
	if not (start and goal) then
		return nil
	end
	local gs, fs, came, kinds, closed = {}, {}, {}, {}, {}
	local heap = {}
	local gx, gz, gy = g.cx[goal], g.cz[goal], g.y[goal]

	local function h(i)
		local dx = (g.cx[i] - gx) * g.sp
		local dz = (g.cz[i] - gz) * g.sp
		return math.sqrt(dx * dx + dz * dz) + math.abs(g.y[i] - gy) * 0.25
	end

	gs[start] = 0
	fs[start] = h(start)
	Heap.push(heap, fs, start)
	local expanded = 0

	while #heap > 0 do
		local cur = Heap.pop(heap, fs)
		if cur == goal then
			local nodes, kindList = {}, {}
			local n = cur
			while n do
				table.insert(nodes, 1, n)
				table.insert(kindList, 1, kinds[n] or 0)
				n = came[n]
			end
			return { nodes = nodes, kinds = kindList, cost = gs[goal], expanded = expanded }
		end
		if not closed[cur] then
			closed[cur] = true
			expanded += 1
			if expanded > P.maxExpansions then
				return nil
			end
			local base = gs[cur]
			g:forEachEdge(cur, function(nxt, kind)
				if closed[nxt] or (allowed and not allowed[regionOf[nxt]]) then
					return
				end
				local cost = base + edgeCost(g, cur, nxt, kind)
				local old = gs[nxt]
				if old == nil or cost < old then
					gs[nxt] = cost
					fs[nxt] = cost + h(nxt)
					came[nxt] = cur
					kinds[nxt] = kind
					Heap.push(heap, fs, nxt)
				end
			end)
		end
	end
	return nil
end

-- region path first, then node A* inside that corridor (+1 region margin);
-- falls back to an unrestricted search when the corridor is too tight
function P.route(g, reg, start, goal)
	if not (start and goal) then
		return nil
	end
	local ra, rb = reg.regionOf[start], reg.regionOf[goal]
	local rpath = R.path(reg, ra, rb)
	if not rpath then
		return nil
	end
	local allowed = {}
	for _, r in ipairs(rpath) do
		allowed[r] = true
		for _, nb in ipairs(reg.adjTo[r]) do
			allowed[nb] = true
		end
	end
	local res = P.find(g, start, goal, allowed, reg.regionOf)
	if res then
		res.corridor = true
		return res
	end
	return P.find(g, start, goal)
end

-- best effort: if the goal cannot be reached, walk to the reachable place that
-- gets us closest to it (happens when a target sits on an isolated ledge)
function P.routeToward(g, reg, start, goal, goalPos)
	local res = goal and P.route(g, reg, start, goal)
	if res then
		return res
	end
	local startRegion = reg.regionOf[start]
	if not startRegion then
		return nil
	end
	local dist = R.dijkstra(reg, { [startRegion] = 0 }, 400)
	local bestR, bestD
	for r = 1, reg.n do
		if dist[r] < math.huge then
			local dx, dy, dz = reg.cx[r] - goalPos.X, reg.cy[r] - goalPos.Y, reg.cz[r] - goalPos.Z
			local d = dx * dx + dy * dy * 4 + dz * dz
			if not bestD or d < bestD then
				bestR, bestD = r, d
			end
		end
	end
	if not bestR then
		return nil
	end
	local target = reg.rep[bestR]
	if not target or target == start then
		return nil
	end
	local approx = P.route(g, reg, start, target)
	if approx then
		approx.approximate = true
	end
	return approx
end

return P

end
__M["evade"] = function()
-- Short horizon planner for the moment a chaser is close. The route says
-- where to go in the long run; this tries a fan of directions, rolls each one
-- forward for well under a second against a chaser that runs straight at
-- where we will be, and keeps the direction that leaves the most room while
-- still roughly serving the route. Walls and holes cut a candidate short.
local U = import("util")

local E = {
	horizon = 0.8,
	steps = 6,
	samples = 16,
	-- Measured: with 26 studs and a weak route weight the fan overrode the
	-- route on 91% of its runs, which throws away everything the path knows
	-- about ladders and gaps. It is a last resort for a chaser on our heels.
	danger = 18, -- only threats inside this radius are simulated
	routeWeight = 10,
	-- Second measurement: even at radius 18 the fan still overruled the route on
	-- 77% of its runs. It should fire when someone is actually about to catch us,
	-- so a threat now has to be closing in or right behind us.
	minGain = 10, -- studs of extra room needed before the route is overruled
	closingSpeed = 6, -- studs/s he has to be gaining on us
	closeRange = 12, -- ... unless he is already this close
	lastDir = nil,
	lastAt = 0,
	active = false,
	margin = 0,
	-- how expensive the fan is: it costs raycasts on every frame it runs
	calls = 0,
	msSum = 0,
	overrides = 0,
}

local rp = RaycastParams.new()
rp.RespectCanCollide = true
rp.CollisionGroup = "Player"

local function refresh()
	local ignore = { U.char(), workspace.CurrentCamera }
	for _, pl in ipairs(U.Players:GetPlayers()) do
		if pl.Character then
			table.insert(ignore, pl.Character)
		end
	end
	rp.FilterDescendantsInstances = ignore
end

-- how far we can run this way before a wall or a real hole stops us
local function freeRun(pos, dir, len)
	local chest = workspace:Raycast(pos + Vector3.new(0, 1.2, 0), dir * len, rp)
	local free = chest and math.max((chest.Position - pos).Magnitude - 2, 0) or len
	local knee = workspace:Raycast(pos + Vector3.new(0, -2.2, 0), dir * math.min(free, len), rp)
	if knee then
		-- a step we would have to vault: slower, not a stop
		free = math.min(free, (knee.Position - pos).Magnitude + 3)
	end
	-- ground at a few points along the way; a long fall is a trap
	local step = math.max(free / 3, 3)
	local d = step
	while d <= free do
		local hit = workspace:Raycast(pos + dir * d + Vector3.new(0, 2, 0), Vector3.new(0, -22, 0), rp)
		if not hit or pos.Y - 3 - hit.Position.Y > 16 then
			return math.max(d - step, 0), true
		end
		d += step
	end
	return free, false
end

-- threats: snapshot infos; desired: flat unit direction from the route.
-- Returns a direction to use instead (or nil when no close threat).
function E.choose(hrp, desired, threats, speed)
	E.active = false
	if not (hrp and desired and desired.Magnitude > 0.05) then
		return nil
	end
	local pos = hrp.Position
	local close = {}
	for _, info in ipairs(threats) do
		if info.dist < E.danger then
			-- is he coming for us, or just standing around nearby?
			local toUs = U.flat(pos - info.pos)
			local closing = toUs.Magnitude > 0.1 and info.vel:Dot(toUs.Unit) or 0
			if info.dist < E.closeRange or closing > E.closingSpeed then
				close[#close + 1] = info
			end
		end
	end
	if #close == 0 then
		return nil
	end
	local t0 = os.clock()
	E.calls += 1
	refresh()
	-- A chaser on the other side of a wall cannot reach us on this horizon, and
	-- letting him bend our route is how we end up running away from nothing.
	-- Very close ones count anyway: a thin pillar is no protection.
	local visible = {}
	for _, info in ipairs(close) do
		if info.dist < 8 or not workspace:Raycast(pos, info.pos - pos, rp) then
			visible[#visible + 1] = info
		end
	end
	if #visible == 0 then
		E.msSum += (os.clock() - t0) * 1000
		return nil
	end
	close = visible
	local mySpeed = math.max(speed, 30)
	local maxLen = mySpeed * E.horizon
	local now = os.clock()

	local bestDir, bestScore, routeMargin
	for k = 0, E.samples - 1 do
		-- sample 0 is the route direction itself
		local dir = k == 0 and desired.Unit or (CFrame.Angles(0, k * (2 * math.pi / E.samples), 0) * desired.Unit)
		local free, hole = freeRun(pos, dir, maxLen + 8)
		local minGap = math.huge
		for s = 1, E.steps do
			local t = E.horizon * s / E.steps
			local me = pos + dir * math.min(mySpeed * t, free)
			for _, th in ipairs(close) do
				-- a chaser a floor away first has to get to our height
				local dy = math.abs(th.pos.Y - me.Y)
				local climb = dy > 5 and dy * 1.5 or 0
				local theirSpeed = math.max(th.speed, 32) * 1.05
				local gap = (U.flat(me - th.pos)).Magnitude + climb - theirSpeed * t
				if gap < minGap then
					minGap = gap
				end
			end
		end
		local score = minGap + dir:Dot(desired.Unit) * E.routeWeight
		if free < maxLen * 0.5 then
			score -= 6 -- running into a corner buys a moment and then nothing
		end
		if hole then
			score -= 4
		end
		if E.lastDir and now - E.lastAt < 0.4 and dir:Dot(E.lastDir) > 0.9 then
			score += 2.5 -- no dithering between two nearly equal options
		end
		if k == 0 then
			routeMargin = score
		end
		if not bestScore or score > bestScore then
			bestDir, bestScore = dir, score
		end
	end
	-- the route already is the best escape (within a little): keep it, the
	-- path knows about gaps and ladders that this fan cannot see
	E.msSum += (os.clock() - t0) * 1000
	if not bestDir or bestScore - routeMargin < E.minGain then
		E.margin = routeMargin or 0
		return nil
	end
	E.active = true
	E.overrides += 1
	E.margin = bestScore
	E.lastDir, E.lastAt = bestDir, now
	return bestDir
end

function E.statusText()
	return string.format("%d Laeufe, %d Umleitungen, %.2fms", E.calls, E.overrides, E.calls > 0 and E.msSum / E.calls or 0)
end

return E

end
__M["follower"] = function()
-- Path following built around one idea: at 32+ studs per second you cannot
-- steer by "am I close to the waypoint" - you project yourself onto the path,
-- look ahead by a distance that grows with speed, and brake before corners.
local U = import("util")
local G = import("gameapi")
local C = import("control")
local N = import("navgraph")
local P = import("pathfind")
local Steer = import("steer")
local Ladder = import("ladder")
local Style = import("style")
local Learn = import("learn")
local Evade = import("evade")

local F = {
	Map = nil,
	path = nil,
	points = nil,
	kinds = nil,
	idx = 1,
	goalPos = nil,
	plannedGoal = nil,
	state = "idle",
	lastPlan = 0,
	lastFail = 0,
	lastCheck = 0,
	bestProgress = -1,
	progressAt = 0,
	stuckJumps = 0,
	lastSlide = 0,
	lastJump = 0,
	replans = 0,
	fails = 0,
	planMs = 0,
	throttle = 1,
	approximate = false,
	carrot = nil,
	-- path telemetry: how far do we drift, and what were we doing at the time
	stats = {
		samples = 0, offSum = 0, offMax = 0, off5 = 0, off12 = 0,
		plans = 0, stuck = 0, blocked = 0, arrivals = 0,
		airborne = 0, braking = 0, advance = 0, planMsSum = 0,
		reasons = {}, pathStuds = 0, patches = 0,
	},
	log = {},
	logAt = 0,
	-- hard floor between two plans; the chase raises this on purpose so the
	-- bot commits to a line instead of recomputing every time the prey moves
	minInterval = 0.45,
	-- chasing: no arrival braking (the goal is a person we want to run into)
	aggressive = false,
	-- fleeing: close chasers the short horizon planner should dodge
	threats = nil,
	-- the jump edge we just took, to learn whether it worked
	pendingEdge = nil,
}

local MIN_PLAN_INTERVAL = 0.45
local GOAL_MOVE_LIMIT = 12
-- A path does not rot. It is replaced when the goal moves, when we drift off
-- it or when we are stuck; the age limit is only a safety net for stale world
-- state (destroyed walls, opened doors).
local MAX_PLAN_AGE = 8
local FAIL_COOLDOWN = 0.5
local WINDOW = 14 -- how many segments ahead we look when projecting

local rp = RaycastParams.new()
rp.RespectCanCollide = true
rp.CollisionGroup = "Player"

local KIND_NAME = { [1] = "walk", [2] = "climb", [3] = "drop", [4] = "jump" }
local NEWLINE = string.char(10)

local function note(event, text)
	local entry = string.format("%7.2f %-10s %s", os.clock() % 10000, event, text or "")
	table.insert(F.log, entry)
	if #F.log > 250 then
		table.remove(F.log, 1)
	end
end
F.note = note

function F.resetStats()
	F.stats = {
		samples = 0, offSum = 0, offMax = 0, off5 = 0, off12 = 0,
		plans = 0, stuck = 0, blocked = 0, arrivals = 0,
		airborne = 0, braking = 0, advance = 0, planMsSum = 0,
		reasons = {}, pathStuds = 0, patches = 0,
	}
	F.log = {}
	F.statsAt = os.clock()
end

function F.dumpLog(path)
	local st = F.stats
	local seconds = math.max(os.clock() - (F.statsAt or os.clock()), 0.01)
	local reasons = {}
	for reason, count in pairs(st.reasons) do
		table.insert(reasons, string.format("%s x%d", reason, count))
	end
	table.sort(reasons)
	local head = string.format(
		"%.0fs | Abweichung am Boden avg %.1f (in der Luft avg %.1f) max %.1f (>5: %.0f%%, >12: %.0f%%) | Pfad-Fortschritt %.1f studs/s | in der Luft %.0f%% | bremst %.0f%% | Plaene %d (%.1fms, %.0f studs/Plan) | Ende nachgezogen %d | steckengeblieben %d | am Pfad vorbei %d | blockiert %d | Gruende: %s",
		seconds,
		(st.groundSamples or 0) > 0 and st.offSum / st.groundSamples or 0,
		(st.airSamples or 0) > 0 and (st.airOffSum or 0) / st.airSamples or 0,
		st.offMax,
		st.samples > 0 and st.off5 / st.samples * 100 or 0,
		st.samples > 0 and st.off12 / st.samples * 100 or 0,
		st.advance / seconds,
		st.samples > 0 and st.airborne / st.samples * 100 or 0,
		st.samples > 0 and st.braking / st.samples * 100 or 0,
		st.plans,
		st.plans > 0 and st.planMsSum / st.plans or 0,
		st.plans > 0 and st.pathStuds / st.plans or 0,
		st.patches or 0,
		st.stuck,
		st.pastPath or 0,
		st.blocked,
		table.concat(reasons, ", ")
	)
	local body = head .. NEWLINE .. table.concat(F.log, NEWLINE)
	if path then
		pcall(writefile, path, body)
	end
	return head
end

function F.init(Map)
	F.Map = Map
end

function F.setGoal(pos)
	F.goalPos = pos
	if not pos then
		F.path, F.points, F.idx, F.state, F.carrot = nil, nil, 1, "idle", nil
	end
end

function F.stop()
	F.setGoal(nil)
	C.move(nil)
	Ladder.reset()
end

-- a target in mid air (jumping player) has no node under it, so drop it down
local function groundedGoal(g, pos)
	local node = g:nearest(pos)
	if node then
		return node
	end
	rp.FilterDescendantsInstances = { U.char(), workspace.CurrentCamera }
	local hit = workspace:Raycast(pos, Vector3.new(0, -80, 0), rp)
	if hit then
		return g:nearest(hit.Position + Vector3.new(0, 1, 0))
	end
	return nil
end

local function plan(g, reg, hrp, reason)
	local t0 = os.clock()
	reason = reason or "?"
	F.stats.reasons[reason] = (F.stats.reasons[reason] or 0) + 1
	-- keep the current line unless we have nothing at all to follow
	if F.points and t0 - F.lastPlan < F.minInterval then
		return false
	end
	F.lastPlan = t0
	F.replans += 1
	local start = g:nearest(hrp.Position)
	local goal = groundedGoal(g, F.goalPos)
	if not start then
		F.path, F.points, F.state = nil, nil, "kein Knoten"
		F.lastFail, F.fails = os.clock(), F.fails + 1
		return
	end
	local res = P.routeToward(g, reg, start, goal, F.goalPos)
	F.planMs = (os.clock() - t0) * 1000
	if not res then
		F.path, F.points, F.state = nil, nil, "kein Pfad"
		F.lastFail, F.fails = os.clock(), F.fails + 1
		note("KEIN-PFAD", string.format("Ziel %.0f studs entfernt", (F.goalPos - hrp.Position).Magnitude))
		return
	end
	-- cache world positions once instead of recomputing them every frame
	local raw = table.create(#res.nodes)
	for i, node in ipairs(res.nodes) do
		raw[i] = g:pos(node)
	end
	raw[#raw] = F.goalPos -- finish exactly at the requested spot

	-- string pulling: the grid hands us a waypoint every 2 studs, which makes
	-- the line zigzag. Merge stretches we can see through, but never merge
	-- across a jump, climb or drop: those edges are the interesting part.
	rp.FilterDescendantsInstances = { U.char(), workspace.CurrentCamera }
	local points, kinds, ids = { raw[1] }, { res.kinds[1] }, { res.nodes[1] }
	local anchor = 1
	local i = 2
	while i <= #raw do
		local special = res.kinds[i] ~= N.WALK
		local canSkip = false
		if not special and i < #raw and res.kinds[i + 1] == N.WALK then
			local a = raw[anchor] + Vector3.new(0, 2.5, 0)
			local b = raw[i + 1] + Vector3.new(0, 2.5, 0)
			local delta = b - a
			if delta.Magnitude < 40 and math.abs(delta.Y) < 4 then
				-- body width again: a thin line would smooth us through a pillar
				local flatDelta = U.flat(delta)
				local side = Vector3.new(0, 0, 0)
				if flatDelta.Magnitude > 0.1 then
					local unit = flatDelta.Unit
					side = Vector3.new(-unit.Z, 0, unit.X) * 0.8
				end
				canSkip = true
				for _, offset in ipairs({ Vector3.new(0, 0, 0), side, -side }) do
					if workspace:Raycast(a + offset, delta, rp) then
						canSkip = false
						break
					end
				end
				if canSkip and workspace:Raycast(a - Vector3.new(0, 1.6, 0), delta, rp) then
					canSkip = false
				end
			end
		end
		if not canSkip then
			table.insert(points, raw[i])
			table.insert(kinds, res.kinds[i])
			table.insert(ids, res.nodes[i])
			anchor = i
		end
		i += 1
	end
	res.kinds = kinds
	F.stats.plans += 1
	F.stats.planMsSum += F.planMs
	local studs = 0
	for k = 1, #points - 1 do
		studs += (points[k + 1] - points[k]).Magnitude
	end
	F.stats.pathStuds += studs
	note("PLAN", string.format("%s: %d Knoten -> %d Punkte, %.0f studs, %.1fms%s", reason, #res.nodes, #points, studs, F.planMs, res.approximate and " (nur genaehert)" or ""))
	F.path, F.points, F.kinds, F.ids = res, points, kinds, ids
	F.pendingEdge = nil
	-- routeToward falls back to "closest reachable spot"; the caller has to
	-- know, otherwise it keeps sending us to a goal we can never reach
	F.approximate = res.approximate == true
		or ((F.goalPos - points[#points]).Magnitude > 25)
	F.idx, F.plannedGoal = 1, F.goalPos
	F.bestProgress, F.progressAt = -1, os.clock()
	F.state = "laufen"
end

-- closest point on a segment, returned as the fraction along it
local function projectOnSegment(a, b, p)
	local ab = b - a
	local len2 = ab:Dot(ab)
	if len2 < 0.0001 then
		return 0, (p - a).Magnitude
	end
	local t = math.clamp((p - a):Dot(ab) / len2, 0, 1)
	local closest = a + ab * t
	return t, (p - closest).Magnitude
end

-- Where are we on the path? This never moves backwards, so overshooting a
-- corner pushes us forward instead of turning us around.
local function project(pos, wide)
	local points = F.points
	-- the last node has no following segment, so never let the index sit on it
	F.idx = math.clamp(F.idx, 1, math.max(#points - 1, 1))
	local bestI, bestT, bestD = F.idx, 0, math.huge
	-- normally we only look forward (never walk backwards), but after a launch
	-- we may have landed anywhere, so then the whole path is searched
	local first = wide and 1 or F.idx
	local last = wide and (#points - 1) or math.min(#points - 1, F.idx + WINDOW)
	for i = first, last do
		local t, d = projectOnSegment(points[i], points[i + 1], pos)
		-- ties should move us on, so later segments get a small bonus
		if d - i * 0.001 < bestD then
			bestI, bestT, bestD = i, t, d - i * 0.001
		end
	end
	F.idx = bestI
	return bestI, bestT, bestD
end

-- walk `dist` studs further along the polyline from (i, t)
local function pointAhead(i, t, dist)
	local points = F.points
	if not (points[i] and points[i + 1]) then
		return points[#points], math.max(#points - 1, 1)
	end
	local pos = points[i]:Lerp(points[i + 1], t)
	local remaining = dist
	local k = i
	while k < #points - 1 do
		local segEnd = points[k + 1]
		local step = (segEnd - pos).Magnitude
		if step >= remaining then
			return pos + (segEnd - pos).Unit * remaining, k
		end
		remaining -= step
		pos = segEnd
		k += 1
	end
	return points[#points], #points - 1
end

-- how sharp is the path within the next `dist` studs?
local function upcomingTurn(i, dist)
	local points = F.points
	local total, travelled = 0, 0
	local k = i
	while k < #points - 2 and travelled < dist do
		local a = points[k + 1] - points[k]
		local b = points[k + 2] - points[k + 1]
		local fa, fb = U.flat(a), U.flat(b)
		if fa.Magnitude > 0.1 and fb.Magnitude > 0.1 then
			total += math.acos(math.clamp(fa.Unit:Dot(fb.Unit), -1, 1))
		end
		travelled += fa.Magnitude
		k += 1
	end
	return total
end

function F.update()
	local Map = F.Map
	local g, reg = Map and Map.graph, Map and Map.regions
	local hrp, hum = U.hrp(), U.hum()
	if not (g and reg and hrp and hum and F.goalPos) then
		C.move(nil)
		return
	end
	local now = os.clock()
	local pos = hrp.Position
	local vel = hrp.AssemblyLinearVelocity
	local speed = U.flat(vel).Magnitude
	local airborne = hum.FloorMaterial == Enum.Material.Air
	F.evading = false

	local goalMoved = F.plannedGoal and (F.plannedGoal - F.goalPos).Magnitude or math.huge

	-- Chasing a runner used to throw the whole path away every time he moved
	-- 12 studs. Usually only the tail changed, so patch that instead: if the
	-- old end is still near the new goal and we can see from there to it, just
	-- move the last point.
	if F.points and goalMoved > 6 and #F.points >= 2 then
		local tail = F.points[#F.points]
		if (tail - F.goalPos).Magnitude < 22 and F.idx < #F.points - 1 then
			rp.FilterDescendantsInstances = { U.char(), workspace.CurrentCamera }
			local from = F.points[#F.points - 1] + Vector3.new(0, 2.5, 0)
			local to = F.goalPos + Vector3.new(0, 2.5, 0)
			if not workspace:Raycast(from, to - from, rp) then
				F.points[#F.points] = F.goalPos
				F.plannedGoal = F.goalPos
				goalMoved = 0
				F.stats.patches = (F.stats.patches or 0) + 1
			end
		end
	end
	local interval = math.max(MIN_PLAN_INTERVAL, F.minInterval)
	local onTrack = (F.lastOff or 0) < 6
	local needPlan = not F.points
		or (goalMoved > GOAL_MOVE_LIMIT and now - F.lastPlan > interval)
		-- only age out a path when we are not happily following it anyway
		or (now - F.lastPlan > math.max(MAX_PLAN_AGE, F.minInterval) and not onTrack)
	-- never replan mid jump: the new path would fight the arc we are already in
	if needPlan and not airborne and now - F.lastFail > FAIL_COOLDOWN then
		local reason = "start"
		if F.points then
			reason = goalMoved > GOAL_MOVE_LIMIT and "Ziel bewegt" or "Plan zu alt"
		end
		plan(g, reg, hrp, reason)
	end
	if not F.points then
		local direct = U.flat(F.goalPos - pos)
		if direct.Magnitude > 3 then
			-- no path (yet): still dodge, otherwise he runs straight into the
			-- chaser while the search is still catching up
			if F.threats and not airborne then
				local alt = Evade.choose(hrp, direct.Unit, F.threats, speed)
				if alt then
					direct = alt
					F.evading = true
				end
			end
			C.move(direct, 1)
			F.state = "direkt"
		else
			C.move(nil)
		end
		return
	end

	if #F.points < 2 then
		-- a one point path is just the goal itself
		C.move(U.flat(F.goalPos - pos), 0.6)
		F.state = "ziel"
		return
	end
	local i, t, offPath = project(pos, F.lastOff and F.lastOff > 10)
	local kind = F.kinds[math.min(i + 1, #F.kinds)]
	local nodePos = F.points[i + 1] or F.points[#F.points]

	-- ladders get their own routine (line up, push in, step off on top)
	if kind == N.CLIMB or C.climbing() then
		if Ladder.update(F.Map, hrp, nodePos) then
			F.state = "leiter:" .. Ladder.state
			return
		end
	end

	-- Pure pursuit: follow the DIRECTION of the path and fold the sideways
	-- error into it, instead of aiming straight at a point. Aiming at a point
	-- makes him turn back on himself when he is a little off the line, which
	-- is what the micro stalls were.
	-- The lookahead also grows when we are off the line, never shrinking to
	-- the point where the correction dominates.
	local lookahead = math.clamp(math.max(speed * 0.4, 6) + offPath * 0.8, 6, 16)
	local carrot = pointAhead(i, t, lookahead)
	F.carrot = carrot

	local segment = U.flat(F.points[i + 1] - F.points[i])
	local tangent = segment.Magnitude > 0.1 and segment.Unit or nil
	local closest = F.points[i]:Lerp(F.points[i + 1], t)
	local cross = U.flat(closest - pos)

	local desired = U.flat(carrot - pos)
	if desired.Magnitude < 0.05 then
		desired = U.flat(nodePos - pos)
	end
	if desired.Magnitude > 0.05 then
		desired = desired.Unit
		if tangent then
			-- blend: mostly where the path goes, partly back onto it
			local w = math.clamp(offPath / 10, 0, 0.55)
			local back = cross.Magnitude > 0.1 and cross.Unit or tangent
			desired = (desired * (1 - w) + back * w)
			if desired.Magnitude > 0.05 then
				desired = desired.Unit
			else
				desired = tangent
			end
		end
	end

	-- braking, the part that was missing: corners, bad alignment, arrival
	local throttle = 1
	local turn = upcomingTurn(i, math.max(speed * 0.5, 8))
	if turn > 0.6 then
		throttle = math.clamp(1 - (turn - 0.6) * 0.55, 0.4, 1)
		-- chasing: only slow for a corner when we are really fast, and never by
		-- much; losing the sprint costs more than a slightly wide line
		if F.aggressive then
			throttle = speed > 26 and math.max(throttle, 0.6) or 1
		end
	end
	-- Braking for misalignment only makes sense at speed. Slowing down while
	-- already slow just feeds the turn-around loop.
	if speed > 18 and desired.Magnitude > 0.1 then
		local heading = U.flat(vel)
		if heading.Magnitude > 1 then
			local align = heading.Unit:Dot(desired.Unit)
			if align < 0.1 then
				throttle = math.min(throttle, 0.5)
			elseif align < 0.55 then
				throttle = math.min(throttle, 0.75)
			end
		end
	end
	local toGoal = U.flat(F.goalPos - pos).Magnitude
	if toGoal < 7 and not F.aggressive then
		throttle = math.min(throttle, math.max(toGoal / 7, 0.25))
	end
	-- jumping sideways into a gap ends at the edge: line up first
	if kind == N.JUMP and not airborne then
		local toNode = U.flat(nodePos - pos)
		if toNode.Magnitude > 0.1 and desired.Magnitude > 0.1 then
			local off = toNode.Unit:Dot(desired.Unit)
			if off < 0.93 then
				desired = toNode
				throttle = math.min(throttle, 0.55)
			end
		end
	end

	if airborne then
		-- keep the take off line instead of steering mid flight
		if F.airDir and now - F.lastJump < 0.9 then
			desired = F.airDir
		end
		throttle = 1
	else
		F.airDir = nil
	end
	F.throttle = throttle

	F.lastOff = offPath
	-- telemetry: how far are we off the line, and what were we doing
	if now - F.logAt > 0.2 then
		F.logAt = now
		local st = F.stats
		st.samples += 1
		if airborne then
			-- flying is not a steering error: a rail fling reaches speed 166 and
			-- lands 60 studs off the line on purpose. Counting that as drift made
			-- the average useless, so it gets its own bucket.
			st.airborne += 1
			st.airOffSum = (st.airOffSum or 0) + offPath
			st.airSamples = (st.airSamples or 0) + 1
		else
			st.groundSamples = (st.groundSamples or 0) + 1
			st.offSum += offPath
		end
		if throttle < 0.7 then
			st.braking += 1
		end
		-- how many studs of path did we actually eat since the last sample?
		local arc = 0
		for k = 1, math.min(i, #F.points - 1) do
			arc += (F.points[k + 1] - F.points[k]).Magnitude
		end
		arc = arc - (1 - t) * (F.points[math.min(i + 1, #F.points)] - F.points[i]).Magnitude
		if F.lastArc and F.lastArcPath == F.path then
			local delta = arc - F.lastArc
			if delta > 0 and delta < 60 then
				st.advance += delta
			end
		end
		F.lastArc, F.lastArcPath = arc, F.path
		st.offMax = math.max(st.offMax, offPath)
		if offPath > 5 then
			st.off5 += 1
		end
		if offPath > 12 then
			st.off12 += 1
			note("ABWEICHUNG", string.format("%.1f studs, Segment %d/%d, Kante %s, Tempo %.0f, %s",
				offPath, i, #F.points, KIND_NAME[kind] or "?", speed, airborne and "in der Luft" or "am Boden"))
		end
	end

	-- let the trick layer know what we are trying to do right now
	Style.context.dir = desired
	Style.context.targetY = nodePos.Y
	Style.context.needHeight = (nodePos.Y - pos.Y) > 4 or kind == N.CLIMB
	Style.context.straight = upcomingTurn(i, 24) < 0.5
	local remaining = 0
	for k = i, math.min(#F.points - 1, i + 12) do
		remaining += (F.points[k + 1] - F.points[k]).Magnitude
	end
	Style.context.remaining = remaining

	-- a chaser on our heels: the short horizon planner may bend the route
	F.evading = false
	if F.threats and not airborne and kind ~= N.CLIMB then
		local alt = Evade.choose(hrp, desired, F.threats, speed)
		if alt then
			desired, throttle = alt, 1
			F.evading = true
		end
	end

	-- local steering has the last word: never press into a wall
	local adjusted, wantJump, blocked = Steer.resolve(hrp, desired, speed)
	C.move(adjusted, throttle)
	if wantJump and now - F.lastJump > 0.35 then
		F.lastJump = now
		C.jump(0.18)
	end

	-- jump by time to arrival, not by distance: at speed 36 a fixed 4 studs is
	-- barely one tenth of a second of warning
	local distToNode = U.flat(nodePos - pos).Magnitude
	local eta = distToNode / math.max(speed, 10)
	if kind == N.JUMP and eta < 0.18 and now - F.lastJump > 0.3 then
		F.lastJump = now
		F.airDir = U.flat(nodePos - pos)
		C.jump(0.25)
		if F.ids and F.ids[i + 1] then
			F.pendingEdge = { node = F.ids[i + 1], idx = i + 1, at = now }
		end
	elseif kind == N.CLIMB and eta < 0.2 and now - F.lastJump > 0.3 and not C.climbing() then
		F.lastJump = now
		C.jump(0.2)
	end
	local slideNode = g:nearest(nodePos)
	if slideNode and g.clear[slideNode] < g.h.standH and distToNode < 6 and now - F.lastSlide > 1.5 then
		F.lastSlide = now
		G.slide()
	end

	-- As a ghost there is no collision and FloorMaterial never leaves Air, so
	-- "stuck" and "off the line" mean nothing. Measuring it anyway poisons both
	-- the telemetry and the learned map experience.
	if G.isDeadRole() then
		F.state = string.format("%d/%d (Geist)", i, #F.points)
		return
	end

	-- progress is measured along the path, so running in circles counts as zero
	if now - F.lastCheck > 0.3 then
		F.lastCheck = now
		local progress = i + t
		local pending = F.pendingEdge
		-- reaching the far side IS the success; a clean jump still lands a good
		-- way off the smoothed line, so do not ask for 6 studs here
		if pending and not airborne and i >= pending.idx and offPath < 20 then
			Learn.success(pending.node)
			F.pendingEdge = nil
		end
		if progress > F.bestProgress + 0.05 then
			F.bestProgress, F.progressAt, F.stuckJumps = progress, now, 0
			Style.progressing = true
		elseif now - F.progressAt > 0.6 then
			Style.progressing = false
		end
		if now - F.progressAt > 0.9 and not airborne then
			-- moving fast but not advancing on the line is a planning problem
			-- (wrong line, goal moved), and a jump only makes it worse
			if speed > 12 then
				F.stuckJumps, F.bestProgress = 0, -1
				-- own counter: this is not "stuck against something", it is
				-- "running fast along the wrong line", and mixing the two made
				-- the run comparisons meaningless
				F.stats.pastPath = (F.stats.pastPath or 0) + 1
				note("STECKT", string.format("Tempo %.0f ohne Fortschritt, Segment %d/%d -> neuer Plan", speed, i, #F.points))
				F.lastPlan = 0
				plan(g, reg, hrp, "laeuft am Pfad vorbei")
			elseif F.stuckJumps < 2 then
				F.stuckJumps += 1
				F.stats.stuck += 1
				note("STECKT", string.format("Segment %d/%d, Kante %s, Tempo %.0f", i, #F.points, KIND_NAME[kind] or "?", speed))
				C.jump(0.25)
				F.progressAt = now - 0.4
			else
				F.stuckJumps, F.bestProgress = 0, -1
				if F.ids and F.ids[i + 1] then
					Learn.fail(g, F.ids[i + 1], kind ~= N.WALK, "steckt")
				end
				F.lastPlan = 0
				plan(g, reg, hrp, "steckengeblieben")
			end
		end
	end

	-- landed far away from the line (trick launch, knockback, fall): a fresh
	-- path beats trying to run back to the old one
	-- Landed well off the line right after a jump edge: that jump did not work.
	-- Measured: a clean jump still lands 12-16 studs off the pulled line, so
	-- only count it when we also never reached the far side.
	local pendingJump = F.pendingEdge
	if pendingJump and not airborne and offPath > 18 and i < pendingJump.idx and now - pendingJump.at < 3 then
		Learn.fail(g, pendingJump.node, true, string.format("Sprung verfehlt (%.0f studs)", offPath))
		note("LERNT", string.format("Sprung auf Knoten %d verfehlt, %.0f studs daneben", pendingJump.node, offPath))
		F.pendingEdge = nil
	end
	if offPath > 25 and not airborne and now - F.lastPlan > 0.4 then
		note("NEUPLAN", string.format("%.1f studs neben der Linie (nach Landung)", offPath))
		local pending = F.pendingEdge
		if pending and now - pending.at < 3 then
			Learn.fail(g, pending.node, true, "Sprung verfehlt")
			F.pendingEdge = nil
		end
		F.lastPlan = 0 -- bypass the chase lock, we are simply somewhere else
		plan(g, reg, hrp, "nach Landung")
	elseif offPath > 12 and not airborne and now - F.lastPlan > interval then
		note("NEUPLAN", string.format("%.1f studs neben der Linie", offPath))
		plan(g, reg, hrp, "neben der Linie")
	end

	F.state = string.format("%d/%d %.0f%%", i, #F.points, throttle * 100)
end

function F.statusText()
	if not F.goalPos then
		return "-"
	end
	return F.state
end

return F

end
__M["steer"] = function()
-- Local steering. The path says where to go, this decides how to get there
-- without scraping walls or running into holes. Everything here is body sized
-- (the character is about 2 studs wide) and scales with speed, because at 32
-- studs per second a 4 stud probe is a tenth of a second of warning.
local U = import("util")

local S = {
	kneeY = 0.6,
	chestY = 2.6,
	headY = 4.2,
	halfWidth = 1.1,
	minProbe = 5,
	maxProbe = 14,
	dropLimit = 14, -- a step down further than this counts as a hole
}

local rp = RaycastParams.new()
rp.RespectCanCollide = true
rp.CollisionGroup = "Player"

local ANGLES = { 0, 20, -20, 40, -40, 62, -62, 85, -85, 110, -110, 140, -140 }

-- committing to a side for a moment stops the left/right dithering in doorways
local lastAngle, lastAngleAt = nil, 0

local function refresh()
	local ignore = { U.char(), workspace.CurrentCamera }
	for _, pl in ipairs(U.Players:GetPlayers()) do
		if pl.Character then
			table.insert(ignore, pl.Character)
		end
	end
	rp.FilterDescendantsInstances = ignore
end

local function ray(from, dir, len)
	local hit = workspace:Raycast(from, dir * len, rp)
	return hit, hit and (hit.Position - from).Magnitude or len
end

-- how far can the body travel this way before something is in the way?
-- three parallel rays, because a single one slips past corners
local function clearance(pos, dir, len, height)
	local side = Vector3.new(-dir.Z, 0, dir.X) * S.halfWidth
	local base = pos + Vector3.new(0, height, 0)
	local _, mid = ray(base, dir, len)
	local _, left = ray(base + side, dir, len)
	local _, right = ray(base - side, dir, len)
	return math.min(mid, left, right)
end

-- is there floor over there, and how far down is it?
local function groundAhead(pos, dir, dist)
	local from = pos + dir * dist + Vector3.new(0, 3, 0)
	local hit = workspace:Raycast(from, Vector3.new(0, -70, 0), rp)
	if not hit then
		return false, 0
	end
	return true, pos.Y - hit.Position.Y
end

-- returns direction, wantJump, blocked
function S.resolve(hrp, desired, speed)
	if not (hrp and desired) then
		return desired, false, false
	end
	local flat = U.flat(desired)
	if flat.Magnitude < 0.05 then
		return desired, false, false
	end
	local dir = flat.Unit
	refresh()
	local pos = hrp.Position
	speed = speed or U.flat(hrp.AssemblyLinearVelocity).Magnitude
	-- look further ahead the faster we run
	local probe = math.clamp(speed * 0.4, S.minProbe, S.maxProbe)

	local straightChest = clearance(pos, dir, probe, S.chestY)
	local straightKnee = clearance(pos, dir, probe, S.kneeY)

	-- knee blocked but chest free: a low obstacle, jumping turns it into a vault.
	-- Only worth it for a real step up, otherwise he hops over every pebble and
	-- spends half the round in the air (measured: 52%).
	if straightKnee < 3 and straightChest > 4.5 then
		local hum = U.hum()
		local grounded = hum and hum.FloorMaterial ~= Enum.Material.Air
		local top = workspace:Raycast(pos + dir * 2.4 + Vector3.new(0, 4, 0), Vector3.new(0, -5.5, 0), rp)
		local rise = top and (top.Position.Y - (pos.Y - 3)) or 0
		if grounded and rise > 1.2 and speed > 8 then
			return dir, true, false
		end
		return dir, false, false
	end

	local nearGround, nearDrop = groundAhead(pos, dir, 5)
	local farGround, farDrop = groundAhead(pos, dir, 11)
	local straightOk = straightChest > math.min(probe * 0.75, 7)
		and nearGround
		and nearDrop < S.dropLimit
	if straightOk then
		return dir, false, false
	end

	-- pick the best way around instead of just refusing to move: score every
	-- candidate by how far it is clear and how much it still points our way
	local best, bestScore, bestJump, bestAngle = nil, -math.huge, false, 0
	for _, angle in ipairs(ANGLES) do
		local cand = U.flat(CFrame.Angles(0, math.rad(angle), 0) * dir)
		if cand.Magnitude > 0.05 then
			cand = cand.Unit
			local chest = clearance(pos, cand, probe, S.chestY)
			local knee = clearance(pos, cand, probe, S.kneeY)
			local ground, drop = groundAhead(pos, cand, 5)
			local groundFar, dropFar = groundAhead(pos, cand, 11)
			local vaultable = knee < 3 and chest > 4.5
			local score = math.min(chest, probe) * 1.6 + cand:Dot(dir) * 12
			if not ground then
				-- a gap we can jump is fine, a bottomless hole is not
				score = groundFar and (score - 6) or (score - 60)
			elseif drop > S.dropLimit then
				score -= 25
			end
			if groundFar and dropFar > S.dropLimit * 2 then
				score -= 8
			end
			if vaultable then
				score += 6
			end
			if lastAngle and math.abs(angle - lastAngle) < 25 and os.clock() - lastAngleAt < 0.5 then
				score += 9 -- keep going the way we already committed to
			end
			if score > bestScore then
				best, bestScore, bestJump, bestAngle = cand, score, vaultable or (not ground and groundFar), angle
			end
		end
	end

	if not best then
		return dir, true, true
	end
	lastAngle, lastAngleAt = bestAngle, os.clock()
	return best, bestJump, best:Dot(dir) < 0.95
end

-- is there a wall to the side we could wallrun along?
function S.wallSide(hrp, len)
	refresh()
	local right = hrp.CFrame.RightVector
	for _, dir in ipairs({ right, -right }) do
		local hit = workspace:Raycast(hrp.Position + Vector3.new(0, S.chestY, 0), dir * (len or 5), rp)
		if hit and math.abs(hit.Normal.Y) < 0.3 then
			return dir, hit
		end
	end
	return nil
end

return S

end
__M["ladder"] = function()
-- Ladders (TrussPart). The humanoid only climbs while it is pushed into the
-- truss from a side that is actually open, so we line up on that face first
-- instead of running into a corner or jumping past it.
local U = import("util")
local C = import("control")
local Learn = import("learn")

local L = {
	state = "idle", -- idle | approach | mount | exit
	truss = nil,
	face = nil,
	since = 0,
	bestY = -math.huge,
	progressAt = 0,
	failed = {}, -- truss -> time until we ignore it
	climbs = 0,
	aborts = 0,
}

local rp = RaycastParams.new()
rp.RespectCanCollide = true
rp.CollisionGroup = "Player"

local function refresh()
	rp.FilterDescendantsInstances = { U.char(), workspace.CurrentCamera }
end

-- the four horizontal faces; a face is usable when there is room in front of it
local function faceDirs(cf)
	return { cf.LookVector, -cf.LookVector, cf.RightVector, -cf.RightVector }
end

-- a face is identified by its flat direction, so we can remember which ones
-- we already tried on this ladder
local function faceKey(dir)
	return string.format("%.1f,%.1f", dir.X, dir.Z)
end

local function openFace(truss, fromPos, tried)
	refresh()
	local cf = truss.CFrame
	local center = cf.Position
	local best, bestScore
	for _, dir in ipairs(faceDirs(cf)) do
		local flat = U.flat(dir)
		if flat.Magnitude > 0.1 and not (tried and tried[faceKey(flat.Unit)]) then
			flat = flat.Unit
			local probe = Vector3.new(center.X, fromPos.Y + 1, center.Z)
			local blocked = workspace:Raycast(probe, flat * 4, rp)
			if not blocked then
				-- prefer the face we are already standing in front of
				local toUs = U.flat(fromPos - center)
				local score = toUs.Magnitude > 0.1 and flat:Dot(toUs.Unit) or 0
				if not bestScore or score > bestScore then
					best, bestScore = flat, score
				end
			end
		end
	end
	return best
end

-- a ladder we could not climb is worth remembering: the route search should
-- prefer another way up next time on this map
local function learnFail(Map, truss, why)
	local g = Map and Map.graph
	if not (g and truss and truss.Parent) then
		return
	end
	local node = g:nearest(truss.Position, 3)
	if node then
		Learn.fail(g, node, true, why)
	end
end

function L.reset()
	L.state, L.truss, L.face, L.center = "idle", nil, nil, nil
end

-- A ladder is often several TrussParts side by side. Pressing into the centre
-- of one part can still be a stud off the climbable middle, which is exactly
-- how you end up scraping the wall next to it.
local function clusterCenter(truss)
	local sumX, sumZ, n = 0, 0, 0
	for _, part in ipairs(workspace:GetPartBoundsInRadius(truss.Position, 8)) do
		if part:IsA("TrussPart") then
			local d = Vector3.new(part.Position.X - truss.Position.X, 0, part.Position.Z - truss.Position.Z)
			if d.Magnitude < 4 then
				sumX += part.Position.X
				sumZ += part.Position.Z
				n += 1
			end
		end
	end
	if n == 0 then
		return Vector3.new(truss.Position.X, truss.Position.Y, truss.Position.Z)
	end
	return Vector3.new(sumX / n, truss.Position.Y, sumZ / n)
end

-- find a climbable truss near a point (from the cached map specials)
function L.find(Map, near, maxDist)
	local header = Map and Map.header
	if not header then
		return nil
	end
	local best, bestD
	for _, sp in ipairs(header.specials or {}) do
		if sp.k == "truss" then
			local pos = Vector3.new(sp.cf[1], sp.cf[2], sp.cf[3])
			local half = (sp.s[2] or 8) * 0.5
			-- compare against the ladder body, not just its centre
			local dy = math.clamp(near.Y - pos.Y, -half, half)
			local ref = Vector3.new(pos.X, pos.Y + dy, pos.Z)
			local d = (ref - near).Magnitude
			if d < (maxDist or 14) and (not bestD or d < bestD) then
				best, bestD = { pos = pos, size = Vector3.new(sp.s[1], sp.s[2], sp.s[3]), cf = sp.cf }, d
			end
		end
	end
	return best, bestD
end

-- drive the climb; returns true while the ladder routine is in control
function L.update(Map, hrp, targetPos)
	local now = os.clock()
	local wantUp = targetPos.Y - hrp.Position.Y

	if L.state == "idle" then
		if wantUp < 3 then
			return false
		end
		refresh()
		-- is there a truss between us and the target?
		local trussPart = nil
		for _, dir in ipairs({ U.flat(targetPos - hrp.Position), hrp.CFrame.LookVector }) do
			if dir.Magnitude > 0.05 then
				local hit = workspace:Raycast(hrp.Position, dir.Unit * 10, rp)
				if hit and hit.Instance:IsA("TrussPart") then
					trussPart = hit.Instance
					break
				end
			end
		end
		if not trussPart then
			local nearby = workspace:GetPartBoundsInRadius(hrp.Position, 12)
			for _, part in ipairs(nearby) do
				if part:IsA("TrussPart") then
					trussPart = part
					break
				end
			end
		end
		if not trussPart or (L.failed[trussPart] or 0) > now then
			return false
		end
		local face = openFace(trussPart, hrp.Position)
		if not face then
			L.failed[trussPart] = now + 8
			return false
		end
		L.truss, L.face, L.state, L.since = trussPart, face, "approach", now
		L.tried = { [faceKey(face)] = true }
		L.center = clusterCenter(trussPart)
		L.bestY, L.progressAt = hrp.Position.Y, now
	end

	local truss = L.truss
	if not (truss and truss.Parent) then
		L.reset()
		return false
	end

	local center = L.center or truss.Position
	local base = Vector3.new(center.X, hrp.Position.Y, center.Z)
	local side = Vector3.new(-L.face.Z, 0, L.face.X) -- along the ladder face
	local toCentre = U.flat(base - hrp.Position)
	local lateral = toCentre:Dot(side) -- sideways offset, this is what was off
	local forward = toCentre:Dot(L.face) -- negative means we are in front of it
	local standPoint = base + L.face * 2.2

	if L.state == "approach" then
		local toStand = U.flat(standPoint - hrp.Position)
		-- both have to be right: close enough AND lined up with the middle
		local aligned = math.abs(lateral) < 0.7 and toStand.Magnitude < 2.6
		if not aligned then
			-- when we are already at the right distance, correct sideways only
			local dir = toStand
			if toStand.Magnitude < 4 then
				dir = side * lateral + L.face * math.clamp(-forward - 2.2, -1, 1)
			end
			local throttle = math.clamp(math.max(toStand.Magnitude, math.abs(lateral)) / 8, 0.3, 1)
			C.move(dir, throttle) -- no jumping: that is how he flies past
			if now - L.since > 4 then
				-- the way to this face is blocked (fence, crate, another player):
				-- try the next open face before writing off the whole ladder
				local other = openFace(truss, hrp.Position, L.tried)
				if other then
					L.face, L.since = other, now
					L.tried[faceKey(other)] = true
				else
					L.failed[truss] = now + 8
					L.aborts += 1
					learnFail(Map, truss, "Leiter nicht erreicht")
					L.reset()
				end
			end
			return true
		end
		L.state, L.since, L.bestY, L.progressAt = "mount", now, hrp.Position.Y, now
	end

	if L.state == "mount" then
		-- push into the face, with a small correction so we stay in the middle
		local correction = side * math.clamp(lateral, -1, 1) * 0.6
		C.move(-L.face + correction, 0.85)
		if math.abs(lateral) > 1.6 then
			-- drifted off the ladder: line up again instead of scraping the wall
			L.state, L.since = "approach", now
			return true
		end
		local y = hrp.Position.Y
		if y > L.bestY + 0.4 then
			L.bestY, L.progressAt = y, now
		elseif now - L.progressAt > 1.4 then
			-- not moving up: wrong ladder or blocked, try another route
			L.failed[truss] = now + 10
			L.aborts += 1
			learnFail(Map, truss, "Leiter blockiert")
			L.reset()
			return false
		end
		if y >= targetPos.Y - 1.5 then
			L.state, L.since = "exit", now
			L.climbs += 1
			-- this ladder worked: take back part of an earlier penalty
			local g = Map and Map.graph
			if g then
				Learn.success(g:nearest(truss.Position, 3))
			end
		end
		return true
	end

	if L.state == "exit" then
		-- step off the top, away from the ladder
		local away = U.flat(targetPos - hrp.Position)
		if away.Magnitude < 0.2 then
			away = -L.face
		end
		C.move(away, 0.8)
		if now - L.since > 0.6 or hrp.Position.Y >= targetPos.Y - 0.5 then
			L.reset()
			return false
		end
		return true
	end

	return false
end

function L.statusText()
	return string.format("%s (%d/%d)", L.state, L.climbs, L.aborts)
end

return L

end
__M["style"] = function()
-- Movement flair that is also plain useful: perfect rolls on landing, vaults,
-- wallruns and swing bars. All of it goes through the game mechanics, which
-- is where the speed comes from: a vault adds momentum, a wallrun release
-- adds momentum, a perfect roll multiplies walkspeed.
local U = import("util")
local G = import("gameapi")
local C = import("control")
local Steer = import("steer")

local S = {
	enabled = true,
	flow = true,
	-- set by the follower: tricks are only allowed while we actually advance
	progressing = true,
	rollFallSpeed = -38,
	rollWindow = 0.085,
	lastRoll = 0,
	lastSlide = 0,
	lastVault = 0,
	lastWallrun = 0,
	lastSwing = 0,
	lastFling = 0,
	rolls = 0,
	vaults = 0,
	wallruns = 0,
	swings = 0,
	flings = 0,
	jukes = 0,
	lastJuke = 0,
	-- what the follower wants right now; wallrides are only worth it when they
	-- serve that goal instead of happening by accident
	context = { dir = nil, targetY = nil, needHeight = false, straight = false, remaining = 0 },
	wall = { since = 0, startY = 0, exitAt = 0 },
}

local rp = RaycastParams.new()
rp.RespectCanCollide = true
rp.CollisionGroup = "Player"

local GRAVITY = 75

local function refreshFilter()
	rp.FilterDescendantsInstances = { U.char(), workspace.CurrentCamera }
end

-- seconds until the feet reach the floor, or nil when nothing is below
local function timeToLand(hrp)
	local pos = hrp.Position
	local vy = hrp.AssemblyLinearVelocity.Y
	local hit = workspace:Raycast(pos, Vector3.new(0, -60, 0), rp)
	if not hit then
		return nil
	end
	-- HumanoidRootPart sits about 3 studs above the floor
	local d = pos.Y - 3 - hit.Position.Y
	if d <= 0 then
		return 0
	end
	local a = 0.5 * GRAVITY
	local b = -vy
	local disc = b * b + 4 * a * d
	if disc < 0 then
		return nil
	end
	return (-b + math.sqrt(disc)) / (2 * a)
end

-- a ledge we could vault onto: wall in front, free space on top of it
local function ledgeAhead(hrp)
	local cf = hrp.CFrame
	local fwd = cf.LookVector * Vector3.new(1, 0, 1)
	if fwd.Magnitude < 0.1 then
		return false
	end
	fwd = fwd.Unit
	local base = hrp.Position
	if not workspace:Raycast(base + Vector3.new(0, -1.5, 0), fwd * 3.2, rp) then
		return false
	end
	-- something blocks the legs; is there a top edge within vault height?
	for h = 0.5, 3.5, 0.75 do
		local top = workspace:Raycast(base + fwd * 2.2 + Vector3.new(0, h + 2.5, 0), Vector3.new(0, -3.2, 0), rp)
		if top then
			local rise = top.Position.Y - (base.Y - 3)
			if rise > 0.4 and rise < 6 then
				return true
			end
		end
	end
	return false
end

-- checker walls carry the Wallrun attribute; running along one and jumping off
-- again is both fast and good looking
-- A wall only helps when we run ALONG it. Jumping into a wall we are heading
-- straight at just bounces us around, which is what made him circle.
local function wallrunWallNear(hrp)
	local cf = hrp.CFrame
	local moveDir = U.flat(hrp.AssemblyLinearVelocity)
	if moveDir.Magnitude < 6 then
		return false
	end
	moveDir = moveDir.Unit
	local anywhere = U.shared().multipliers and U.shared().multipliers.EnableWallrunning
	local right = cf.RightVector
	for _, dir in ipairs({ right, -right }) do
		local hit = workspace:Raycast(hrp.Position, dir * 5, rp)
		if hit then
			local inst = hit.Instance
			local allowed = inst:GetAttribute("Wallrun") or anywhere
			local normal = U.flat(hit.Normal)
			-- only a head on wall is useless; anything we can run along is fair
			local limit = anywhere and 0.8 or 0.45
			if allowed and normal.Magnitude > 0.1 and math.abs(normal.Unit:Dot(moveDir)) < limit then
				return true
			end
		end
	end
	return false
end

-- rolling into a rail turns the grind into a fling (velocity 170 forward),
-- which is the fastest thing in the game
local function railAhead(hrp)
	local cf = hrp.CFrame
	local fwd = cf.LookVector * Vector3.new(1, 0, 1)
	if fwd.Magnitude < 0.1 then
		return false
	end
	fwd = fwd.Unit
	for _, d in ipairs({ 4, 7, 10 }) do
		local hit = workspace:Raycast(hrp.Position + fwd * d + Vector3.new(0, 1, 0), Vector3.new(0, -7, 0), rp)
		if hit and hit.Instance:GetAttribute("RailCollision") then
			return true
		end
	end
	return false
end

-- A vault sets VaultDebounce, and the game disables the climbing state while
-- that runs. Tricking into a ladder is therefore how you slide back down.
local function trussNear(hrp)
	local cf = hrp.CFrame
	for _, dir in ipairs({ cf.LookVector, cf.RightVector, -cf.RightVector, -cf.LookVector }) do
		local flat = U.flat(dir)
		if flat.Magnitude > 0.05 then
			local hit = workspace:Raycast(hrp.Position, flat.Unit * 4.5, rp)
			if hit and hit.Instance:IsA("TrussPart") then
				return true
			end
		end
	end
	return false
end

local function swingBarAhead(hrp)
	local cf = hrp.CFrame
	local fwd = cf.LookVector * Vector3.new(1, 0, 1)
	if fwd.Magnitude < 0.1 then
		return false
	end
	local origin = hrp.Position + Vector3.new(0, 2.5, 0)
	local hit = workspace:Raycast(origin, fwd.Unit * 7, rp)
	return hit ~= nil and hit.Instance:GetAttribute("SwingBar") ~= nil
end

function S.update()
	if not S.enabled then
		return
	end
	local hrp, hum = U.hrp(), U.hum()
	if not (hrp and hum) then
		return
	end
	refreshFilter()
	local now = os.clock()
	local vel = hrp.AssemblyLinearVelocity
	local speed = U.flat(vel).Magnitude
	local airborne = hum.FloorMaterial == Enum.Material.Air
	local shared = U.shared()

	-- perfect roll: press slide just before touchdown on a fast fall
	if airborne and vel.Y < S.rollFallSpeed and now - S.lastRoll > 0.6 then
		local t = timeToLand(hrp)
		if t and t <= S.rollWindow then
			S.lastRoll = now
			S.rolls += 1
			G.slide()
		end
	end

	-- downhill slides keep speed up on long descents
	if not airborne and now - S.lastSlide > 4 then
		local slope = shared.slopeTilt
		if speed > 26 and slope and slope < -0.18 then
			S.lastSlide = now
			G.slide()
		end
	end

	if not S.flow then
		return
	end

	-- on or next to a ladder: climbing beats every trick
	if C.climbing() or trussNear(hrp) then
		return
	end

	-- a trick that does not move us forward is just a loop against a wall
	if not S.progressing then
		return
	end

	-- WALLRIDE, on purpose instead of by accident.
	-- Rules from the game: it only starts in the air, the wall has to be to the
	-- side, and starting it sets the vertical speed to +10. Releasing it with a
	-- jump fires PitchRedirect, which reads the camera pitch - so we aim the
	-- exit before we let go.
	if shared.wallrunSide then
		local onWallFor = now - S.wall.since
		local gained = hrp.Position.Y - S.wall.startY
		local ctx = S.context
		-- keep riding while it still buys us height, then leave deliberately
		local wallGone = not Steer.wallSide(hrp, 6)
		local enough = ctx.needHeight and (gained > 9 or onWallFor > 1.1) or onWallFor > 0.55
		if wallGone or enough then
			-- look where we want to go: up for height, flat for distance
			C.setPitch(ctx.needHeight and 55 or 12, 0.35)
			S.lastWallrun = now
			C.jump(0.16, true)
		end
		return
	end

	if airborne and speed > 12 and now - S.lastWallrun > 0.9 then
		local ctx = S.context
		local wantsHeight = ctx.needHeight
		-- a wallride throws us off the line unless the route keeps going that
		-- way anyway: only ride for height, or along a long straight stretch
		local longRun = speed > 24 and ctx.straight and (ctx.remaining or 0) > 45
		if (wantsHeight or longRun) and (wallrunWallNear(hrp) or (shared.multipliers and shared.multipliers.EnableWallrunning and Steer.wallSide(hrp))) then
			S.lastWallrun = now
			S.wallruns += 1
			S.wall.since, S.wall.startY = now, hrp.Position.Y
			C.jump(0.16)
			return
		end
	end

	-- swing bars: jumping into one hooks it and slings us forward
	if speed > 12 and now - S.lastSwing > 1.2 and swingBarAhead(hrp) then
		S.lastSwing = now
		S.swings += 1
		C.jump(0.2)
		return
	end

	-- rail fling: a 170 stud launch is only useful when the path really
	-- continues that way, otherwise we land somewhere off the route
	if speed > 18 and now - S.lastFling > 2.5 and S.context.straight
		and (S.context.remaining or 0) > 60 and railAhead(hrp) then
		S.lastFling = now
		S.flings += 1
		G.slide()
		return
	end

	-- vault: jumping at a ledge climbs it and adds momentum on the way
	if not airborne and speed > 10 and now - S.lastVault > 0.7 and ledgeAhead(hrp) then
		S.lastVault = now
		S.vaults += 1
		C.jump(0.18)
	end
end

-- Ankle breaker. The game has no dodge, so this is: hard sidestep to the open
-- side, a slide to cut the heading (the game keeps the slide direction, which
-- is what makes a chaser overshoot), and a hop when he is right behind us.
function S.juke(hrp, threatPos, threatDist)
	refreshFilter()
	local away = U.flat(hrp.Position - threatPos)
	if away.Magnitude < 0.5 then
		return false
	end
	away = away.Unit
	local side = Vector3.new(-away.Z, 0, away.X)
	local speed = U.flat(hrp.AssemblyLinearVelocity).Magnitude
	local bestDir, bestRoom = nil, 0
	for _, d in ipairs({ side, -side }) do
		-- close chasers get a sharper cut, distant ones a softer curve
		local blend = threatDist and threatDist < 10 and 0.95 or 0.8
		local mixed = (d * blend + away * (1 - blend + 0.25)).Unit
		local hit = workspace:Raycast(hrp.Position + Vector3.new(0, 2.4, 0), mixed * 16, rp)
		local room = hit and (hit.Position - hrp.Position).Magnitude or 16
		if room > bestRoom then
			bestDir, bestRoom = mixed, room
		end
	end
	if not bestDir or bestRoom < 6 then
		return false
	end

	C.nudge(bestDir, 0.3)
	S.jukes += 1

	local hum = U.hum()
	local grounded = hum and hum.FloorMaterial ~= Enum.Material.Air
	if grounded and speed > 22 and os.clock() - S.lastSlide > 2 then
		-- slide cut: heading locks to the slide, so the turn is much sharper
		S.lastSlide = os.clock()
		G.slide()
	elseif grounded and threatDist and threatDist < 9 then
		-- he is in swing range: leaving the ground makes the tag ray miss
		C.jump(0.16)
	end
	return true
end

-- called by the idle routine: hop along while cruising so momentum builds
function S.cruiseHop(hum)
	if hum and hum.FloorMaterial ~= Enum.Material.Air then
		C.jump(0.12)
	end
end

function S.statusText()
	return string.format("%d/%d/%d/%d/%d/%d", S.rolls, S.vaults, S.wallruns, S.swings, S.flings, S.jukes)
end

return S

end
__M["boosts"] = function()
-- Optional advantages that go through the game own multiplier system:
-- reach, hit cone, cooldown, speed boosts and the free movement switches.
-- Everything ramps smoothly and every touched value is restored on unload.
local U = import("util")

local B = {
	enabled = false,
	-- reach grows only when a target is actually close, so it is not obvious
	reachMax = 15 * 0.8,
	reachFrom = 21 * 0.8,
	spreadMax = 3,
	cooldownMul = 0.8,

	-- Speed through the game boost table. Small numbers over a wide radius
	-- feel far better than a big kick up close: the bot is quicker the whole
	-- time a chase is on, instead of snapping when someone gets near.
	fleeBoost = 0.16,
	fleeRadius = 110,
	chaseBoost = 0.3,
	chaseRadius = 200,
	accel = 1.35,
	jump = 1.1,
	-- lighter gravity means longer jumps, which the nav graph is built for
	gravityMul = 0.95,

	-- movement quality: sprint in every direction and face the move direction
	freeMovement = true,
	-- Wallrunning on every wall made him ride things that were not meant for
	-- it, so this is off: the game attribute decides again.
	wallrunAnywhere = false,

	reach = 7,
	spread = 1,
	speed = 1,
}

local originals = nil
local originalTable = nil

local function lerp(a, b, f)
	return a + (b - a) * math.min(f, 1)
end

-- 1 at zero distance, 0 at the radius
local function ramp(d, radius)
	if not d then
		return 0
	end
	return math.clamp(1 - d / radius, 0, 1)
end

local function capture(m)
	if originalTable == m and originals then
		return
	end
	originalTable = m
	originals = {
		RangeMultiplier = m.RangeMultiplier,
		TagRaySpread = m.TagRaySpread,
		TagCooldown = m.TagCooldown,
		GravityMultiplier = m.GravityMultiplier,
		RunInAllDirections = m.RunInAllDirections,
		RotateInMoveDirection = m.RotateInMoveDirection,
		EnableWallrunning = m.EnableWallrunning,
	}
end

function B.apply(dt, snap)
	local shared = U.shared()
	local m = shared.multipliers
	if not (m and shared.boosts) then
		return
	end
	capture(m)

	local preyD, threatD
	for _, info in ipairs(snap and snap.prey or {}) do
		if not preyD or info.dist < preyD then
			preyD = info.dist
		end
	end
	for _, info in ipairs(snap and snap.activeThreats or {}) do
		if not threatD or info.dist < threatD then
			threatD = info.dist
		end
	end

	-- reach and hit cone: only near the target, eased in
	local wantReach, wantSpread = 7, 1
	if preyD and preyD <= B.reachFrom then
		wantReach = math.clamp(preyD + 1.5, 7, B.reachMax)
		wantSpread = lerp(1, B.spreadMax, ramp(preyD, B.reachFrom))
	end
	B.reach = lerp(B.reach, wantReach, dt * 10)
	B.spread = lerp(B.spread, wantSpread, dt * 10)
	-- Roles carry their own values (Permafrost has RangeMultiplier 4 and
	-- TagRaySpread 8). Writing ours straight in would NERF those roles, so we
	-- only ever raise, never lower.
	m.RangeMultiplier = math.max(B.reach / 7, originals.RangeMultiplier or 1)
	m.TagRaySpread = math.max(B.spread, originals.TagRaySpread or 1)
	if B.cooldownMul < 1 then
		m.TagCooldown = (originals.TagCooldown or m.TagCooldown or 0.7) * B.cooldownMul
	end

	-- speed: strongest when a chaser is close, and a base amount while hunting
	local wantSpeed, wantAccel = 1, 1
	if threatD then
		local r = ramp(threatD, B.fleeRadius)
		wantSpeed = 1 + B.fleeBoost * r
		wantAccel = lerp(1, B.accel, r)
	end
	if preyD then
		local f = math.min(0.6 + 0.4 * ramp(preyD, B.chaseRadius), 1)
		local sp = 1 + B.chaseBoost * f
		if sp > wantSpeed then
			wantSpeed, wantAccel = sp, lerp(1, B.accel, f)
		end
	end
	B.speed = lerp(B.speed, wantSpeed, dt * 6)
	if math.abs(B.speed - 1) < 0.004 then
		B.speed = 1
		shared.boosts.__utgap = nil
	else
		shared.boosts.__utgap = { Speed = B.speed, Accel = wantAccel, Jump = B.jump }
	end

	m.GravityMultiplier = B.gravityMul or originals.GravityMultiplier

	-- movement quality
	m.RunInAllDirections = B.freeMovement and true or originals.RunInAllDirections
	m.RotateInMoveDirection = B.freeMovement and true or originals.RotateInMoveDirection
	m.EnableWallrunning = B.wallrunAnywhere and true or originals.EnableWallrunning
end

function B.restore()
	local shared = U.shared()
	if shared.boosts then
		shared.boosts.__utgap = nil
	end
	local m = shared.multipliers
	if m and originals and originalTable == m then
		for key, value in pairs(originals) do
			m[key] = value
		end
	end
	B.reach, B.spread, B.speed = 7, 1, 1
end

function B.statusText()
	if not B.enabled then
		return "aus"
	end
	return string.format("Reichweite %.1f  Kegel %.1f  Tempo %.2f", B.reach, B.spread, B.speed)
end

return B

end
__M["voting"] = function()
-- Voting: wait a moment so the other votes are in, then back the leader.
-- The cards carry their count in Frame.Front.Votes1, and pressing a card is
-- done by firing its own Activated connections, so the game handles the rest.
local U = import("util")

local V = {
	delay = 2, -- seconds to let the others vote first
	screens = { "ModeVoting", "MapVoting" },
	votes = 0,
	last = "-",
}

local maid = U.Maid.new()
local pending = {}

local function cards(screen)
	local options = screen:FindFirstChild("Options", true)
	if not options then
		return {}
	end
	local list = {}
	for _, child in ipairs(options:GetChildren()) do
		if child:IsA("GuiButton") then
			local label = child:FindFirstChild("Votes1", true)
			local count = label and tonumber(label.Text) or 0
			table.insert(list, { button = child, count = count })
		end
	end
	return list
end

local function press(button)
	local ok, conns = pcall(getconnections, button.Activated)
	if ok and conns and #conns > 0 then
		for _, c in ipairs(conns) do
			pcall(function()
				c:Fire()
			end)
		end
		return true
	end
	-- some cards listen on MouseButton1Click instead
	local ok2, conns2 = pcall(getconnections, button.MouseButton1Click)
	if ok2 and conns2 then
		for _, c in ipairs(conns2) do
			pcall(function()
				c:Fire()
			end)
		end
		return #conns2 > 0
	end
	return false
end

local function voteOn(screen)
	local list = cards(screen)
	if #list == 0 then
		return false
	end
	local best
	for _, entry in ipairs(list) do
		if not best or entry.count > best.count then
			best = entry
		end
	end
	if not best then
		return false
	end
	if press(best.button) then
		V.votes += 1
		V.last = string.format("%s (%d Stimmen)", screen.Name, best.count)
		U.log("voted", V.last)
		return true
	end
	return false
end

local function watch(screen)
	if not screen:IsA("ScreenGui") then
		return
	end
	local function onShown()
		if not screen.Enabled or pending[screen] then
			return
		end
		pending[screen] = true
		task.delay(V.delay, function()
			if screen.Parent then
				pcall(voteOn, screen)
			end
			pending[screen] = nil
		end)
	end
	maid:give(screen:GetPropertyChangedSignal("Enabled"):Connect(onShown))
	onShown()
end

function V.start()
	local gui = U.lp:FindFirstChild("PlayerGui")
	if not gui then
		return
	end
	for _, name in ipairs(V.screens) do
		local screen = gui:FindFirstChild(name)
		if screen then
			watch(screen)
		end
	end
	maid:give(gui.ChildAdded:Connect(function(child)
		for _, name in ipairs(V.screens) do
			if child.Name == name then
				watch(child)
			end
		end
	end))
end

function V.stop()
	maid:clean()
	pending = {}
end

function V.statusText()
	return string.format("%d abgegeben, zuletzt %s", V.votes, V.last)
end

return V

end
__M["tactics"] = function()
-- Decides what to do: who to hunt, where to run. Works for any gamemode
-- because prey/threat come from the game's own TagTables.
local U = import("util")
local G = import("gameapi")
local R = import("regions")

local T = {
	blacklist = {},
	-- stick to a target instead of flip flopping between two runners
	commit = { player = nil, since = 0, minTime = 1.5, switchGain = 0.8 },
	fieldInterval = 0.4,
	fieldMaxCost = 400,
	fields = {},
	lastSnapshot = 0,
	snapshot = nil,
	decision = "-",
}

-- Other characters almost always report velocity 0 on the client, so measure
-- their real speed from position deltas instead.
local velTrack = {}
local function trackVelocity(player, hrp)
	local now = os.clock()
	local e = velTrack[player]
	if not e then
		velTrack[player] = { pos = hrp.Position, t = now, vel = Vector3.zero, speed = 0 }
		return Vector3.zero, 0
	end
	local dt = now - e.t
	if dt >= 0.2 then
		local delta = hrp.Position - e.pos
		local v = delta / dt
		-- smoothed, so a single replication jump does not dominate
		e.vel = e.vel * 0.4 + v * 0.6
		e.speed = U.flat(e.vel).Magnitude
		e.pos, e.t = hrp.Position, now
	end
	return e.vel, e.speed
end

local function alive(player)
	local hum = U.hum(player.Character)
	return hum and hum.Health > 0
end

-- prey: roles I may tag; threats: roles that may tag me
function T.observe()
	local myRole = G.role(U.lp)
	local myHrp = U.hrp()
	local snap = { myRole = myRole, prey = {}, threats = {}, activeThreats = {}, all = {} }
	if not myHrp then
		T.snapshot = snap
		return snap
	end
	snap.pos = myHrp.Position
	for _, player in ipairs(U.Players:GetPlayers()) do
		if player ~= U.lp and alive(player) then
			local hrp = U.hrp(player.Character)
			if hrp then
				local vel, speed = trackVelocity(player, hrp)
				local info = {
					player = player,
					hrp = hrp,
					pos = hrp.Position,
					vel = vel,
					speed = speed,
					mobile = speed > 4,
					role = G.role(player),
					dist = (hrp.Position - myHrp.Position).Magnitude,
					ntb = G.hasNoTagBack(player),
				}
				table.insert(snap.all, info)
				if G.canTag(myRole, info.role) then
					table.insert(snap.prey, info)
				end
				if G.canTag(info.role, myRole) then
					table.insert(snap.threats, info)
					-- a chaser standing still right next to us is still a chaser
					if info.mobile or info.dist < 18 then
						table.insert(snap.activeThreats, info)
					end
				end
			end
		end
	end
	T.snapshot = snap
	return snap
end

-- cached region distance field (costs from that region outwards)
function T.field(reg, regionId)
	local now = os.clock()
	local entry = T.fields[regionId]
	if entry and now - entry.t < T.fieldInterval then
		return entry.dist
	end
	local dist = R.dijkstra(reg, { [regionId] = 0 }, T.fieldMaxCost)
	T.fields[regionId] = { t = now, dist = dist }
	return dist
end

function T.clearFields()
	T.fields = {}
end

local function regionOf(g, reg, pos)
	local node = g:nearest(pos)
	return node and reg.regionOf[node], node
end

-- targets we cannot make progress on get parked for a while
function T.parkTarget(player, seconds)
	T.blacklist[player.UserId] = os.clock() + (seconds or 8)
end

function T.isParked(player)
	local until_ = T.blacklist[player.UserId]
	return until_ ~= nil and os.clock() < until_
end

-- chase: nearest prey by path cost, ignoring ones we cannot reach
function T.pickPrey(g, reg, snap)
	local myRegion = regionOf(g, reg, snap.pos)
	if not myRegion then
		return nil
	end
	local field = T.field(reg, myRegion)
	local now = os.clock()
	local commit = T.commit
	local best, bestScore
	local committed, committedScore
	for _, info in ipairs(snap.prey) do
		if not T.isParked(info.player) then
		local r = regionOf(g, reg, info.pos)
		local cost = r and field[r] or math.huge
		if cost == math.huge then
			cost = info.dist * 2 + 500 -- unreachable: only as a last resort
		end
		-- prefer targets that are not running away from us and not shielded
		local away = 0
		local toThem = info.pos - snap.pos
		if toThem.Magnitude > 1 then
			away = info.vel:Dot(toThem.Unit)
		end
		local score = cost + math.max(away, 0) * 0.6 + (info.ntb and 80 or 0)
		if not bestScore or score < bestScore then
			best, bestScore = info, score
		end
		if commit.player == info.player then
			committed, committedScore = info, score
		end
		end
	end

	-- keep the current target for a while; only a clearly better one wins
	if committed then
		local heldFor = now - commit.since
		if heldFor < commit.minTime or not best or bestScore > committedScore * commit.switchGain then
			return committed, committedScore
		end
	end
	if best and best.player ~= commit.player then
		commit.player, commit.since = best.player, now
	end
	return best, bestScore
end

function T.dropCommit()
	T.commit.player, T.commit.since = nil, 0
end

-- Where do we meet a runner if both keep going straight? Solves
-- |rel + v t| = mySpeed * t on the ground plane; the height is left to the
-- path search because players jump all the time.
function T.intercept(myPos, pos, vel, mySpeed)
	local v = U.flat(vel)
	local rel = U.flat(pos - myPos)
	local a = v:Dot(v) - mySpeed * mySpeed
	local b = 2 * rel:Dot(v)
	local c = rel:Dot(rel)
	local t
	if math.abs(a) < 0.001 then
		t = b < 0 and -c / b or nil
	else
		local disc = b * b - 4 * a * c
		if disc >= 0 then
			local s = math.sqrt(disc)
			local t1, t2 = (-b - s) / (2 * a), (-b + s) / (2 * a)
			if t1 > 0 and (t2 <= 0 or t1 < t2) then
				t = t1
			elseif t2 > 0 then
				t = t2
			end
		end
	end
	-- faster than us and running away: aim at where he is heading anyway
	t = t or rel.Magnitude / mySpeed
	return pos + v * math.clamp(t, 0, 1.2)
end

-- Can we simply run there? Same height, nothing in the way at body width and
-- floor under the whole line. Then the path follower is only in the way.
local lineRp = RaycastParams.new()
lineRp.RespectCanCollide = true
lineRp.CollisionGroup = "Player"

function T.directLine(from, to)
	if math.abs(to.Y - from.Y) > 4 then
		return false
	end
	local delta = U.flat(to - from)
	local len = delta.Magnitude
	if len < 1 then
		return true
	end
	if len > 45 then
		return false
	end
	local ignore = { workspace.CurrentCamera }
	for _, pl in ipairs(U.Players:GetPlayers()) do
		if pl.Character then
			table.insert(ignore, pl.Character)
		end
	end
	lineRp.FilterDescendantsInstances = ignore
	local unit = delta.Unit
	local side = Vector3.new(-unit.Z, 0, unit.X) * 0.9
	for _, offset in ipairs({ Vector3.new(0, 1, 0), Vector3.new(0, 1, 0) + side, Vector3.new(0, 1, 0) - side, Vector3.new(0, -2, 0) }) do
		if workspace:Raycast(from + offset, delta, lineRp) then
			return false
		end
	end
	local d = 4
	while d < len do
		local hit = workspace:Raycast(from + unit * d + Vector3.new(0, 2, 0), Vector3.new(0, -12, 0), lineRp)
		if not hit or hit.Position.Y < from.Y - 7 then
			return false
		end
		local inst = hit.Instance
		if inst:GetAttribute("Lava") or inst:GetAttribute("ContactDamage") then
			return false
		end
		d += 4
	end
	return true
end

-- flee: pick a region that is far from every threat, cheap for us to reach,
-- high up and with several exits
function T.pickRefuge(g, reg, snap, banned)
	local myRegion = regionOf(g, reg, snap.pos)
	if not myRegion then
		return nil
	end
	local mine = T.field(reg, myRegion)
	local threatFields = {}
	for _, info in ipairs(snap.activeThreats) do
		local r = regionOf(g, reg, info.pos)
		if r then
			table.insert(threatFields, T.field(reg, r))
		end
	end
	if #threatFields == 0 then
		return nil
	end

	local myPos = snap.pos
	-- running "past" a chaser is how you get tagged; reject refuges whose
	-- straight line from here passes close to one
	local function lineIsSafe(target)
		for _, info in ipairs(snap.activeThreats) do
			local seg = target - myPos
			local len = seg.Magnitude
			if len > 1 then
				local t = math.clamp((info.pos - myPos):Dot(seg) / (len * len), 0, 1)
				local closest = myPos + seg * t
				if (info.pos - closest).Magnitude < 16 and t > 0.05 then
					return false
				end
			end
		end
		return true
	end

	local candidates = {}
	local fallback = {} -- when nothing passes the strict test, take the best of these
	local best, bestScore
	for r = 1, reg.n do
		local myCost = mine[r]
		if myCost < 150 and not (banned and banned[r] and os.clock() - banned[r] < 4) then
			local minThreat = math.huge
			for _, f in ipairs(threatFields) do
				if f[r] < minThreat then
					minThreat = f[r]
				end
			end
			if minThreat > 12 and lineIsSafe(R.center(reg, r)) then
				local score = math.min(minThreat, 250)
					- myCost * 0.45
					+ reg.cy[r] * 0.12
					+ math.min(reg.degree[r], 8) * 1.5
				-- we also have to get there clearly before he does, otherwise the
				-- "refuge" is just a place where he meets us
				if minThreat > myCost * 0.9 + 8 then
					candidates[#candidates + 1] = { r = r, score = score }
				else
					fallback[#fallback + 1] = { r = r, score = score }
				end
			end
		end
	end
	if #candidates == 0 then
		candidates = fallback
	end
	-- breaking line of sight is worth more than a few studs of distance, so
	-- the best handful get a visibility check
	table.sort(candidates, function(a, b)
		return a.score > b.score
	end)
	local rp = RaycastParams.new()
	rp.RespectCanCollide = true
	rp.CollisionGroup = "Player"
	rp.FilterDescendantsInstances = { U.char(), workspace.CurrentCamera }
	for i = 1, math.min(#candidates, 12) do
		local cand = candidates[i]
		local centre = R.center(reg, cand.r) + Vector3.new(0, 3, 0)
		local hidden = 0
		for _, info in ipairs(snap.activeThreats) do
			local from = info.pos + Vector3.new(0, 2, 0)
			local delta = centre - from
			if delta.Magnitude > 6 and workspace:Raycast(from, delta, rp) then
				hidden += 1
			end
		end
		cand.score += hidden * 18
		if not bestScore or cand.score > bestScore then
			best, bestScore = cand.r, cand.score
		end
	end

	if not best then
		return nil
	end
	return R.center(reg, best), bestScore, best
end

-- how good the region we are already heading to still is (nil when unsafe)
function T.refugeScore(g, reg, snap, region)
	local myRegion = regionOf(g, reg, snap.pos)
	if not (myRegion and region) then
		return nil
	end
	local mine = T.field(reg, myRegion)
	local myCost = mine[region]
	if myCost == math.huge then
		return nil
	end
	local minThreat = math.huge
	for _, info in ipairs(snap.threats) do
		local r = regionOf(g, reg, info.pos)
		if r then
			local f = T.field(reg, r)
			if f[region] < minThreat then
				minThreat = f[region]
			end
		end
	end
	if minThreat < 12 or minThreat < myCost * 0.9 + 8 then
		return nil
	end
	return math.min(minThreat, 250) - myCost * 0.45 + reg.cy[region] * 0.12 + math.min(reg.degree[region], 8) * 1.5
end

-- regions that contain something fun (swing bars, rails, ziplines, trusses)
local specialCache = { key = nil, set = nil }
function T.specialRegions(g, reg, header, mapKey)
	if specialCache.key == mapKey and specialCache.set then
		return specialCache.set
	end
	local set = {}
	for _, sp in ipairs((header and header.specials) or {}) do
		if sp.k == "swingbar" or sp.k == "rail" or sp.k == "zipline" or sp.k == "truss" or sp.k == "bounce" then
			local node = g:nearest(Vector3.new(sp.cf[1], sp.cf[2], sp.cf[3]), 5)
			if node then
				local r = reg.regionOf[node]
				set[r] = (set[r] or 0) + 1
			end
		end
	end
	specialCache.key, specialCache.set = mapKey, set
	return set
end

-- idle showtime: head for a high, jumpy corner of the map that is not boring
-- to get to, and pick a new one every time we arrive
function T.pickPlayground(g, reg, snap, visited, header, mapKey)
	local myRegion = regionOf(g, reg, snap.pos)
	if not myRegion then
		return nil
	end
	local mine = T.field(reg, myRegion)
	local fun = T.specialRegions(g, reg, header, mapKey)
	local now = os.clock()
	local best, bestScore, bestRegion
	for r = 1, reg.n do
		local cost = mine[r]
		local seenAt = visited and visited[r]
		-- a far away target keeps him travelling instead of circling, and
		-- recently visited corners are off the list for a while
		if cost > 70 and cost < 320 and not (seenAt and now - seenAt < 90) then
			local score = reg.cy[r] * 0.5
				+ (fun[r] or 0) * 6
				+ math.min(reg.extras[r] or 0, 40) * 1.2
				+ math.min(reg.degree[r], 10) * 1.0
				+ math.min(cost, 200) * 0.05 -- reward going somewhere new
				+ math.random() * 10
			if not bestScore or score > bestScore then
				best, bestScore, bestRegion = R.center(reg, r), score, r
			end
		end
	end
	return best, bestRegion
end

return T

end
__M["debugviz"] = function()
-- Debug overlay: navigation nodes around the player plus the current path
-- (pooled adornments, no parts, nothing replicated to the server)
local U = import("util")
local N = import("navgraph")

local V = { enabled = false, radius = 14, maxBoxes = 900, maxLines = 400, drawn = 0, lastError = nil }

local maid = U.Maid.new()
local folder = nil
local boxes, lines = {}, {}
local lastUpdate = 0

local COLORS = {
	walk = Color3.fromRGB(70, 200, 110),
	climb = Color3.fromRGB(70, 150, 255),
	drop = Color3.fromRGB(255, 165, 50),
	jump = Color3.fromRGB(250, 220, 60),
	crouch = Color3.fromRGB(200, 90, 255),
	isolated = Color3.fromRGB(230, 60, 60),
	path = Color3.fromRGB(255, 255, 255),
}

local function getBox(i)
	local b = boxes[i]
	if not b then
		b = Instance.new("BoxHandleAdornment")
		b.Adornee = workspace.Terrain
		b.Size = Vector3.new(0.7, 0.15, 0.7)
		b.Transparency = 0.3
		b.AlwaysOnTop = false
		b.ZIndex = 1
		b.Parent = folder
		boxes[i] = b
	end
	return b
end

local function getLine(i)
	local l = lines[i]
	if not l then
		l = Instance.new("CylinderHandleAdornment")
		l.Adornee = workspace.Terrain
		l.Radius = 0.12
		l.Transparency = 0.15
		l.AlwaysOnTop = true
		l.ZIndex = 5
		l.Parent = folder
		lines[i] = l
	end
	return l
end

local function nodeColor(g, j)
	if g.clear[j] < g.h.standH then
		return COLORS.crouch
	elseif g.exStart[j + 1] > g.exStart[j] then
		return COLORS.jump
	elseif g.climb[j] ~= 0 then
		return COLORS.climb
	elseif g.drop[j] ~= 0 then
		return COLORS.drop
	elseif g.walk[j] ~= 0 then
		return COLORS.walk
	end
	return COLORS.isolated
end

local KIND_COLOR = { [N.WALK] = COLORS.path, [N.CLIMB] = COLORS.climb, [N.DROP] = COLORS.drop, [N.JUMP] = COLORS.jump }

local function update(getGraph, getPath)
	local g = getGraph()
	local hrp = U.hrp()
	local usedBoxes, usedLines = 0, 0

	if g and hrp then
		local p = hrp.Position
		local bx, bz = math.floor((p.X - g.x0) / g.sp + 0.5), math.floor((p.Z - g.z0) / g.sp + 0.5)
		local r = V.radius
		for dz = -r, r do
			for dx = -r, r do
				if dx * dx + dz * dz <= r * r then
					local c = g:col(bx + dx, bz + dz)
					if c then
						for j = g.colStart[c], g.colStart[c + 1] - 1 do
							if math.abs(g.y[j] - p.Y) < 14 and usedBoxes < V.maxBoxes then
								usedBoxes += 1
								local b = getBox(usedBoxes)
								b.Color3 = nodeColor(g, j)
								b.CFrame = CFrame.new(g:pos(j) + Vector3.new(0, 0.1, 0))
								b.Visible = true
							end
						end
					end
				end
			end
		end

		-- current path as a chain of segments, coloured by movement kind
		local path = getPath and getPath()
		if g and path and path.nodes then
			for i = 2, #path.nodes do
				if usedLines >= V.maxLines then
					break
				end
				local a = g:pos(path.nodes[i - 1]) + Vector3.new(0, 1, 0)
				local b = g:pos(path.nodes[i]) + Vector3.new(0, 1, 0)
				local delta = b - a
				if delta.Magnitude > 0.05 then
					usedLines += 1
					local l = getLine(usedLines)
					l.Height = delta.Magnitude
					l.CFrame = CFrame.lookAt(a + delta * 0.5, b) * CFrame.new(0, 0, -delta.Magnitude * 0)
					l.Color3 = KIND_COLOR[path.kinds[i]] or COLORS.path
					l.Visible = true
				end
			end
		end
	end

	V.drawn = usedBoxes
	for i = usedBoxes + 1, #boxes do
		boxes[i].Visible = false
	end
	for i = usedLines + 1, #lines do
		lines[i].Visible = false
	end
end

function V.setEnabled(on, getGraph, getPath)
	V.enabled = on and true or false
	maid:clean()
	boxes, lines = {}, {}
	folder = nil
	if not V.enabled then
		return
	end
	folder = Instance.new("Folder")
	folder.Name = "UTGAP_Debug"
	folder.Parent = (gethui and gethui()) or game:GetService("CoreGui")
	maid:give(folder)
	maid:give(U.RunService.Heartbeat:Connect(function()
		if os.clock() - lastUpdate < 0.2 then
			return
		end
		lastUpdate = os.clock()
		local ok, err = pcall(update, getGraph, getPath)
		if not ok then
			V.lastError = tostring(err)
			U.log("debugviz error", err)
		end
	end))
end

function V.info()
	return string.format("aktiv %s, gezeichnet %d, Pool %d, Ordner %s, Fehler %s",
		tostring(V.enabled), V.drawn, #boxes, folder and folder:GetFullName() or "-", tostring(V.lastError))
end

function V.destroy()
	V.setEnabled(false)
end

return V

end
__M["main"] = function()
-- Entry point: wires modules together, exposes getgenv().UTGAP for testing
local U = import("util")
local G = import("gameapi")
local C = import("control")
local GUI = import("gui")
local Map = import("mapcache")
local Viz = import("debugviz")
local P = import("pathfind")
local R = import("regions")
local Fol = import("follower")
local T = import("tactics")
local Style = import("style")
local Ladder = import("ladder")
local Boost = import("boosts")
local Vote = import("voting")
local Learn = import("learn")
local Steer = import("steer")

local genv = getgenv()
if genv.UTGAP and genv.UTGAP.unload then
	pcall(genv.UTGAP.unload)
end

local AP = {
	version = "0.6.4",
	U = U,
	G = G,
	C = C,
	GUI = GUI,
	Map = Map,
	Viz = Viz,
	P = P,
	R = R,
	Fol = Fol,
	T = T,
	Style = Style,
	Boost = Boost,
	Ladder = Ladder,
	Vote = Vote,
	Learn = Learn,
	Evade = import("evade"),
	Steer = Steer,
}
genv.UTGAP = AP

local maid = U.Maid.new()
local lastTag = 0
local status = { behaviour = "-", goal = "-", tag = "-" }
local idle = { region = nil, since = 0, goal = nil, trick = 0, visited = {}, fails = 0 }
local flee = { region = nil, goal = nil, since = 0, banned = {}, lastBan = 0 }
local chase = { player = nil, bestDist = math.huge, since = 0, lastHop = 0, direct = false }

local FEATURES = { "auto", "follow", "autotag" }
-- while chasing, commit to a path this long: enough to stop the flip flopping,
-- short enough to react when the target cuts away
local CHASE_PLAN_INTERVAL = 1

-- control is only hooked while a feature wants it
local function syncControl()
	local any = false
	for _, id in ipairs(FEATURES) do
		any = any or GUI.get(id)
	end
	if C.enabled ~= any then
		C.setEnabled(any)
	end
	if not any then
		Fol.stop()
	end
end

GUI.create("UTG Autopilot", "v" .. AP.version)
GUI.addToggle("auto", "Autopilot", Enum.KeyCode.F6, false, function(on)
	if not on then
		Fol.stop()
		status.behaviour, status.goal = "-", "-"
	end
	syncControl()
end)
GUI.addToggle("follow", "Test: Pfad zum Naechsten", Enum.KeyCode.F7, false, function(on)
	if not on then
		Fol.stop()
		status.goal = "-"
	end
	syncControl()
end)
GUI.addToggle("autotag", "Nur Auto-Tag", Enum.KeyCode.F8, false, function(on)
	if not on then
		C.aim(nil)
	end
	syncControl()
end)
GUI.addToggle("boosts", "Boosts (Reichweite/Tempo)", Enum.KeyCode.F4, true, function(on)
	Boost.enabled = on
	C.freeMovement = on and Boost.freeMovement
	if not on then
		Boost.restore()
	end
end)
GUI.addToggle("hidevote", "Voting ausblenden", Enum.KeyCode.F3, true)
GUI.addToggle("autovote", "Auto-Vote (Mehrheit)", Enum.KeyCode.F2, true, function(on)
	if on then
		Vote.start()
	else
		Vote.stop()
	end
end)
GUI.addToggle("freestyle", "Freestyle im Leerlauf", Enum.KeyCode.F9, true)
GUI.addToggle("thirdperson", "Third Person", Enum.KeyCode.F11, false, function(on)
	G.setThirdPerson(on)
end)
GUI.addToggle("navdebug", "Debug: Wegenetz", Enum.KeyCode.F10, true, function(on)
	Viz.setEnabled(on, function()
		return Map.graph
	end, function()
		return Fol.path
	end)
end)

-- another tag script steering at the same time fights our own input and
-- rewrites the same multipliers, so say it out loud
local function foreignScript()
    local hui = (gethui and gethui()) or game:GetService("CoreGui")
    for _, g in ipairs(hui:GetChildren()) do
        if g.Name:find("UTG") and g.Name ~= "UTGAP" and g.Name ~= "UTGAP_Debug" then
            return g.Name
        end
    end
    return nil
end

-- another tag script fights us for the same multipliers every frame, so offer
-- a clean shutdown of it (it exposes __UTG_TAG.cleanup itself)
function AP.stopForeign()
	local other = genv.__UTG_TAG
	local stopped = false
	if type(other) == "table" and type(other.cleanup) == "function" then
		stopped = pcall(other.cleanup)
	end
	local hui = (gethui and gethui()) or game:GetService("CoreGui")
	for _, g in ipairs(hui:GetChildren()) do
		if g.Name:find("UTG") and g.Name ~= "UTGAP" and g.Name ~= "UTGAP_Debug" then
			pcall(function()
				g:Destroy()
			end)
			stopped = true
		end
	end
	U.log("foreign script stop:", stopped)
	return stopped
end

C.init()
Map.start()
Fol.init(Map)

-- boosts are on by default (proximity speed, reach, cooldown); wallrunning
-- stays limited to real Wallrun walls
Boost.enabled = GUI.get("boosts")
C.freeMovement = Boost.enabled and Boost.freeMovement

-- apply the defaults through the very same path the hotkeys use
for _, id in ipairs({ "navdebug", "freestyle", "boosts", "hidevote", "autovote" }) do
	GUI.set(id, GUI.get(id))
end

-- Tagging goes straight through the remote with the target serial, the way
-- the game does it internally. No camera aiming means no camera yanking, and
-- it still lands while we are running past or away.
local TAG_REACH = 24 * 0.8 -- shortened by 20% on request

local function tagInRange(snap)
	if not G.tagReady() then
		return false
	end
	local origin = G.tagOrigin()
	if not origin then
		return false
	end
	local prey
	for _, info in ipairs(snap.prey) do
		if info.dist <= TAG_REACH and (not prey or info.dist < prey.dist) then
			prey = info
		end
	end
	if not prey then
		return false
	end
	if G.tagPlayer(prey.player) then
		status.tag = prey.player.Name
	end
	return true
end

local function nearestPlayer(snap)
	local best
	for _, info in ipairs(snap.all) do
		if not best or info.dist < best.dist then
			best = info
		end
	end
	return best
end

-- cruise to high, jumpy, trick rich corners of the map
local function freestyle(snap, g, reg, hum)
	local hrp = U.hrp()
	if not hrp then
		return false
	end
	local now = os.clock()
	local arrived = idle.goal and (hrp.Position - idle.goal).Magnitude < 14
	-- a goal we cannot route to would keep him spinning on the spot
	if idle.goal and (Fol.state == "kein Pfad" or Fol.approximate) then
		idle.fails += 1
		if idle.fails > 1 then
			if idle.region then
				idle.visited[idle.region] = now
			end
			idle.goal, idle.fails = nil, 0
		end
	end
	if not idle.goal or arrived or now - idle.since > 25 then
		if idle.region then
			idle.visited[idle.region] = now
		end
		local goal, region = T.pickPlayground(g, reg, snap, idle.visited, Map.header, Map.mapKey)
		-- a new corner has to be a real trip, otherwise he just circles
		if goal and (goal - hrp.Position).Magnitude < 70 then
			idle.visited[region] = now
			goal = nil
		end
		if goal then
			idle.goal, idle.region, idle.since, idle.fails = goal, region, now, 0
		end
	end
	if not idle.goal then
		return false
	end
	P.setProfile("style")
	Fol.minInterval = 0.45
	Fol.setGoal(idle.goal)
	Fol.update()
	P.setProfile("fast")
	-- a hop now and then keeps momentum up and looks alive
	if hum and math.random() < 0.012 and now - idle.trick > 1.5 then
		idle.trick = now
		Style.cruiseHop(hum)
	end
	status.goal = string.format("%.0f, %.0f, %.0f", idle.goal.X, idle.goal.Y, idle.goal.Z)
	return true
end

-- Target in plain sight on the same floor: run straight at the meeting point
-- at full speed. No plan latency, no corner braking, no path detours.
local function chaseDirect(hrp, aimAt, prey)
	local dir = U.flat((prey.dist < 8 and prey.pos or aimAt) - hrp.Position)
	if dir.Magnitude < 0.5 then
		dir = U.flat(prey.pos - hrp.Position)
	end
	if dir.Magnitude < 0.3 then
		C.move(nil)
		return
	end
	dir = dir.Unit
	local speed = U.flat(hrp.AssemblyLinearVelocity).Magnitude
	local adjusted, wantJump = Steer.resolve(hrp, dir, speed)
	C.move(adjusted, 1)
	local now = os.clock()
	local dy = prey.pos.Y - hrp.Position.Y
	-- a step up to him (crate, mid jump): hop so the swing still connects
	if (wantJump or (dy > 2 and dy < 6 and prey.dist < 12)) and now - chase.lastHop > 0.45 then
		chase.lastHop = now
		C.jump(0.18)
	end
	Style.context.dir = dir
	Style.context.targetY = prey.pos.Y
	Style.context.needHeight = false
	Style.context.straight = true
	Style.context.remaining = prey.dist
	Style.progressing = true
	Fol.state = "Sicht"
end

-- Does the route ahead run into a chaser? A refuge can be safe while the way
-- there passes right by him.
local function routeThreatened(snap)
	local pts = Fol.points
	if not pts or #pts < 2 then
		return false
	end
	local travelled = 0
	for k = math.max(Fol.idx, 1), #pts - 1 do
		local p = pts[k + 1]
		travelled += (p - pts[k]).Magnitude
		for _, th in ipairs(snap.activeThreats) do
			local theirs = (th.pos - p).Magnitude
			if theirs < 14 and theirs < travelled + 4 then
				return true
			end
		end
		if travelled > 45 then
			break
		end
	end
	return false
end

local function autopilot(snap)
	local g, reg = Map.graph, Map.regions
	if not (g and reg) then
		status.behaviour = "warte auf Wegenetz"
		C.move(nil)
		return
	end
	local hum = U.hum()

	-- dead or spectating: nothing to hunt or run from, so put on a show
	if G.isDeadRole() then
		if GUI.get("freestyle") and freestyle(snap, g, reg, hum) then
			status.behaviour = "freestyle (tot)"
		else
			Fol.stop()
			status.behaviour = "tot"
			status.goal = "-"
		end
		return
	end

	local health = hum and hum.Health or 100
	local nearestThreat
	for _, info in ipairs(snap.activeThreats) do
		if not nearestThreat or info.dist < nearestThreat.dist then
			nearestThreat = info
		end
	end

	-- Tagging beats not being tagged: hunt across the whole map, even with
	-- hunters about (in many modes both sides can tag). Only break off when
	-- someone is really on our neck AND closer than our own target.
	local defensive = health < 40 and nearestThreat and nearestThreat.dist < 30

	if #snap.prey > 0 and not defensive then
		local prey = T.pickPrey(g, reg, snap)
		if prey and nearestThreat and nearestThreat.dist < 22 and nearestThreat.dist < prey.dist then
			prey = nil -- the chaser is the more urgent problem
		end
		if prey then
			-- no progress for a while means the target sits somewhere we cannot
			-- follow; park it and hunt someone else
			local now = os.clock()
			if chase.player ~= prey.player then
				chase.player, chase.bestDist, chase.since = prey.player, prey.dist, now
			elseif prey.dist < chase.bestDist - 3 then
				chase.bestDist, chase.since = prey.dist, now
			elseif now - chase.since > 3.5 or (Fol.approximate and now - chase.since > 1.5) then
				T.parkTarget(prey.player, 8)
				chase.player, chase.bestDist = nil, math.huge
			end
			-- aim where we meet, not where he is
			local hrp = U.hrp()
			local mySpeed = math.max(hrp and U.flat(hrp.AssemblyLinearVelocity).Magnitude or 0, 32)
			local aimAt = T.intercept(snap.pos, prey.pos, prey.vel, mySpeed)
			Fol.aggressive = true
			local sight = hrp and not C.climbing()
				and (T.directLine(hrp.Position, aimAt) or T.directLine(hrp.Position, prey.pos))
			-- a single blocked ray (a lamp post, a jump) should not throw away
			-- the sight run and trigger a fresh plan
			local now2 = os.clock()
			if sight then
				chase.sightAt = now2
			end
			local direct = sight or (chase.direct and chase.sightAt and now2 - chase.sightAt < 0.3)
			if direct then
				if not chase.direct then
					Fol.note("SICHT", string.format("%s %.0f studs", prey.player.Name, prey.dist))
				end
				chaseDirect(hrp, aimAt, prey)
				-- keep the goal fresh so falling back to the path is instant
				Fol.goalPos = aimAt
				status.behaviour = "jagt (Sicht)"
			else
				if chase.direct then
					Fol.lastPlan = 0 -- lost sight: plan right away
				end
				Fol.minInterval = CHASE_PLAN_INTERVAL
				-- he is above us: make the climbs cheap so we take the ladder
				local up = hrp and (prey.pos.Y - hrp.Position.Y) > 6
				if up then
					P.setProfile("chaseUp")
				end
				Fol.setGoal(aimAt)
				Fol.update()
				if up then
					P.setProfile("fast")
				end
				status.behaviour = up and "jagt (hoch)" or "jagt"
			end
			chase.direct = direct and true or false
			status.goal = string.format("%s (%.0f)", prey.player.Name, prey.dist)
			return
		end
	end

	if #snap.activeThreats > 0 then
		local now = os.clock()
		local hrp = U.hrp()
		Fol.threats = snap.activeThreats
		-- the way to the refuge leads past a chaser: pick another one now
		if flee.goal and now - flee.lastBan > 0.6 and routeThreatened(snap) then
			flee.lastBan = now
			if flee.region then
				flee.banned[flee.region] = now
			end
			Fol.note("UMWEG", "Route fuehrt am Faenger vorbei")
			flee.goal, flee.region = nil, nil
			Fol.lastPlan = 0
		end
		-- keep the current refuge unless we arrived, it became unsafe, or a
		-- clearly better one shows up; re-picking every tick shreds the path
		local keep = flee.goal and T.refugeScore(g, reg, snap, flee.region)
		local arrived = flee.goal and hrp and (hrp.Position - flee.goal).Magnitude < 12
		if keep and not arrived and now - flee.since < 1.5 then
			Fol.setGoal(flee.goal)
			Fol.update()
			status.behaviour = defensive and "weicht aus" or "flieht"
			status.goal = string.format("%.0f, %.0f, %.0f", flee.goal.X, flee.goal.Y, flee.goal.Z)
			return
		end
		local refuge, score, region = T.pickRefuge(g, reg, snap, flee.banned)
		if refuge and (not keep or arrived or score > keep * 1.15) then
			flee.goal, flee.region, flee.since = refuge, region, now
		end
		if flee.goal then
			Fol.minInterval = 0.45
			-- escape routes may be awkward on purpose: gaps, crawl holes, climbs
			P.setProfile("evade")
			Fol.setGoal(flee.goal)
			Fol.update()
			P.setProfile("fast")
			-- chaser on our heels: juke when he is really closing in on us, not
			-- at random intervals (a juke costs speed, so it has to buy something)
			if nearestThreat and nearestThreat.dist < 16 then
				local toUs = U.flat(snap.pos - nearestThreat.pos)
				local closing = toUs.Magnitude > 0.1 and nearestThreat.vel:Dot(toUs.Unit) or 0
				local urgency = math.clamp(1 - nearestThreat.dist / 16, 0, 1)
				if (closing > 6 or nearestThreat.dist < 9) and now - Style.lastJuke > 1.2 - urgency * 0.6 then
					Style.lastJuke = now
					Style.juke(U.hrp(), nearestThreat.pos, nearestThreat.dist)
				end
			end
			status.behaviour = defensive and "weicht aus" or "flieht"
			status.goal = string.format("%.0f, %.0f, %.0f", flee.goal.X, flee.goal.Y, flee.goal.Z)
			return
		end
	end

	if GUI.get("freestyle") and freestyle(snap, g, reg, hum) then
		status.behaviour = "freestyle"
		return
	end

	Fol.stop()
	status.behaviour = "wartet"
	status.goal = "-"
end

local lastObserve = 0
local function brain()
	if not C.enabled then
		return
	end
	local snap = T.snapshot
	if not snap or os.clock() - lastObserve > 0.12 then
		lastObserve = os.clock()
		snap = T.observe()
	end

	-- as a ghost the character has no collision, so FloorMaterial never leaves
	-- Air and the trick detection would only fire into the void
	-- pinned in place (frozen, caged, anchored): every input is wasted
	if G.isImmobile(C.enabled and Fol.goalPos ~= nil) then
		C.move(nil)
		status.behaviour = "bewegungsunfaehig"
		return
	end

	Style.flow = not G.isDeadRole()
	Style.update()

	-- experience for this map feeds straight into the path costs
	Learn.bind(Map.mapKey, Map.graph)
	-- a ghost walks through walls, so nothing that happens then is a real failure
	Learn.enabled = not G.isDeadRole()
	P.penalty = Learn.penalty
	Learn.tick()
	Fol.aggressive, Fol.threats = false, nil

	if (GUI.get("auto") or GUI.get("autotag")) and not G.isDeadRole() then
		tagInRange(snap)
	end

	if GUI.get("auto") then
		autopilot(snap)
	elseif GUI.get("follow") then
		local target = nearestPlayer(snap)
		if target and target.dist > 4 then
			Fol.minInterval = 0.45
			Fol.setGoal(target.pos)
			Fol.update()
			status.goal = string.format("%s (%.0f)", target.player.Name, target.dist)
		else
			Fol.stop()
			status.goal = target and "angekommen" or "niemand"
		end
	end
end

U.RunService:BindToRenderStep("utgap_brain", Enum.RenderPriority.Input.Value - 2, function()
	local ok, err = pcall(brain)
	if not ok then
		U.log("brain error", err)
	end
end)
maid:give(function()
	U.RunService:UnbindFromRenderStep("utgap_brain")
end)

-- The game rebuilds shared.multipliers whenever a role or modifier changes,
-- so the boosts are written every frame, right before its movement scripts
-- read them (they run at Input and Input+1).
U.RunService:BindToRenderStep("utgap_boosts", Enum.RenderPriority.Input.Value - 3, function(dt)
	if not Boost.enabled then
		return
	end
	local ok, err = pcall(Boost.apply, dt, T.snapshot)
	if not ok then
		U.log("boost error", err)
	end
	C.freeMovement = Boost.freeMovement
end)
maid:give(function()
	U.RunService:UnbindFromRenderStep("utgap_boosts")
end)

local lastStatus = 0
maid:give(U.RunService.Heartbeat:Connect(function()
	local now = os.clock()
	if now - lastStatus < 0.2 then
		return
	end
	lastStatus = now
	if GUI.get("hidevote") then
		G.hideVoting(true)
	end
	local snap = T.snapshot
	GUI.setStatusRows({
		{ "Modus", tostring(G.gamemode()) },
		{ "Map", tostring(G.mapName()) },
		{ "Wegenetz", Map.statusText() },
		{ "Rolle", tostring(G.role(U.lp)) },
		{ "Jagd / Gefahr", snap and string.format("%d / %d aktiv %d", #snap.prey, #snap.threats, #snap.activeThreats) or "-" },
		{ "Verhalten", status.behaviour },
		{ "Ziel", status.goal },
		{ "Pfad", Fol.statusText() },
		{ "Tricks R/V/W/S/F/J", Style.statusText() },
		{ "Planungen", string.format("%d (%.0fms, alle %.1fs)", Fol.replans, Fol.planMs, Fol.minInterval) },
		{ "Leiter", Ladder.statusText() },
		{ "Erfahrung", Learn.statusText() },
		{ "Boosts", Boost.statusText() },
		{ "Voting", Vote.statusText() },
		{ "Fremdscript", foreignScript() or "keins" },
		{ "Tags", G.tagStatusText() },
		{ "Letzter Tag", status.tag },
	})
end))

local function resetDecisions(reason)
	T.clearFields()
	T.dropCommit()
	idle.goal, idle.region = nil, nil
	flee.goal, flee.region = nil, nil
	chase.player, chase.bestDist = nil, math.huge
	Fol.minInterval = 0.45
	Fol.lastPlan = 0 -- next update plans immediately
	Fol.setGoal(nil)
	T.observe()
	U.log("decisions reset:", reason)
end

-- a new round means new roles, so drop the cached distance fields
maid:give(U.RS.Values.Gamemode.Changed:Connect(function()
	resetDecisions("Modus gewechselt")
end))

-- Losing the crown, getting infected, being frozen: the whole prey/threat
-- picture flips in that instant, so nothing from before may survive.
local roleValue = U.lp:FindFirstChild("PlayerRole")
if roleValue then
	maid:give(roleValue.Changed:Connect(function(value)
		resetDecisions("Rolle jetzt " .. tostring(value))
	end))
end
maid:give(U.lp.CharacterAdded:Connect(function()
	resetDecisions("neuer Charakter")
end))

function AP.unload()
	pcall(Learn.save)
	maid:clean()
	Boost.restore()
	Map.stop()
	Viz.destroy()
	C.shutdown()
	GUI.destroy()
	if genv.UTGAP == AP then
		genv.UTGAP = nil
	end
end

U.log("loaded", AP.version)
return AP

end
return import("main")
