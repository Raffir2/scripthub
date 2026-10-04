-- VESTERIA HUB  (Vesteria, The Vesteria Team; Mushtown PlaceId 2064647391, patch 25.23.0)
-- Start: loadstring(readfile("vesteria_hub.lua"))()   Toggle GUI: RightShift (rebind under Settings)
-- Handle: _G.__VES_HUB (kill() = unload)
--
-- Measured live 2026-10-04 (source reference: github.com/berezaa/vesteria, live fork is newer):
--  * melee hit = fireEvent("playerWillUseBasicAttack", lp) + replicatePlayerAnimationSequence("<type>Animations","strike1|2")
--    then playerRequest_damageEntity_batch({{hitbox, pos, "equipment", "none", nil, GUID}}). Damage is computed on the
--    server from your stats. Without the animation event the server ignores the batch. 0.1s swings all land.
--    Several batches after one swing count several times; duplicate entries inside one batch count once.
--  * server range check: target within ~(weapon size+6)*1.75 of your hitbox, and within ~29 studs of where the
--    server saw you up to 1/3s ago -> travel there first, then hit (glue keeps us at 3 studs).
--  * anti-TP (config tpExploitPunishment = "redirect" = KICK, no ban): flags moves > 3*walkspeed per 1/3s unless the
--    replicated velocity points the same way (ratio <= 1.35x). Gliding with matching AssemblyLinearVelocity = clean.
--  * pickup: RF.playerRequest_pickUpItem(part) within ~11 studs. Chest: RF.openTreasureChest(model) within 40 studs
--    (farther = TP suspicion). Resources: RE.attackInteractionAttackableAttacked(part, pos) after a swing.
--  * selling via remote needs an open shop on the server (returns nil otherwise) -> not automated.

if _G.__VES_HUB and _G.__VES_HUB.kill then pcall(_G.__VES_HUB.kill) end
local H = { conns = {}, threads = {}, alive = true, log = {}, tok = 0,
	stats = { kills = 0, chests = 0, picks = 0, res = 0, start = os.clock() } }
_G.__VES_HUB = H

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local CoreGui = game:GetService("CoreGui")
local RepS = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local CollectionService = game:GetService("CollectionService")
local lp = Players.LocalPlayer
local cam = workspace.CurrentCamera

local NET = RepS:WaitForChild("network")
local RE, RF, BF = NET:WaitForChild("RemoteEvent"), NET:WaitForChild("RemoteFunction"), NET:WaitForChild("BindableFunction_Client")
local PF = workspace:WaitForChild("placeFolders")
local ENT = PF:WaitForChild("entityManifestCollection")
local ITEMS = PF:WaitForChild("items")
local RES = PF:FindFirstChild("resources")
local itemData = select(2, pcall(require, RepS.itemData))
local monsterLookup = select(2, pcall(require, RepS.monsterLookup))
if type(itemData) ~= "table" then itemData = {} end
if type(monsterLookup) ~= "table" then monsterLookup = {} end

local function con(sig, fn) local c = sig:Connect(fn) table.insert(H.conns, c) return c end
local function log(s)
	table.insert(H.log, os.date("%H:%M:%S ") .. s)
	if #H.log > 40 then table.remove(H.log, 1) end
end
local function status(s) H.status = s end

-- ================= SETTINGS (vesteria_hub_settings.json) =================
local SAVE_FILE = "vesteria_hub_settings.json"
local D = {
	-- farm
	farm = false, farmMode = 1, farmFilter = "", farmLvlOver = 5, farmDist = 3, farmHeight = 0, farmRadius = 600,
	aura = false, auraRange = 14, auraMax = 6, swingDelay = 0.12, hitsPerSwing = 1,
	autoHeal = true, healAt = 40, autoRespawn = true,
	-- quests
	autoQuest = false, questAccept = true, questRepeat = true, questTravel = true, questGrind = true, resumeAt = 0, liveAt = 0, lastPlace = 0, visited = "",
	-- loot
	loot = true, lootRange = 120, autoSell = false, sellFree = 2, sellGear = false, sellCommonOnly = true, chests = false, resources = false, resRange = 250,
	autoEquip = false, equipMode = 1, equipMelee = true,
	resCrate = true, resPot = true, resMushroom = false, resCabbage = false, resTree = false,
	-- player
	speed = 60, underground = false, ugDepth = 10, noFall = true, instantTp = false, clickTp = false, autoStats = false, statPick = 1, antiAfk = true,
	-- visuals
	espMobs = false, espBoss = true, espChests = false, espItems = false, espPlayers = false, espDist = 500,
	fullbright = false,
	-- gui
	guiX = 40, guiY = 160, guiVisible = true, guiCollapsed = false, keyMenu = "RightShift", keyFarm = "F6", keyStop = "F7",
}
local saved = {}
pcall(function() if isfile(SAVE_FILE) then saved = HttpService:JSONDecode(readfile(SAVE_FILE)) end end)
if type(saved) ~= "table" then saved = {} end
local state = {}
for k, v in pairs(D) do
	if saved[k] ~= nil and type(saved[k]) == type(v) then state[k] = saved[k] else state[k] = v end
end
state.farm = false state.autoQuest = false -- never auto-start farming on load
-- ...except right after auto quest took a zone exit: the autoexec reloads the hub in the new place and it carries on
if os.time() - (state.resumeAt or 0) < 600 then state.autoQuest = true state.resumeAt = 0 H.resumed = true end
-- ...and after a death/respawn teleport, rejoin or re-execute: the last session was alive < 10 min ago -> keep
-- farm / auto quest exactly as they were (turning them off yourself is saved and stays off)
if os.time() - (state.liveAt or 0) < 600 then
	if saved.farm == true then state.farm = true end
	if saved.autoQuest == true then state.autoQuest = true end
end
-- places we've been to (zone travel prefers new ones)
if not (("," .. state.visited .. ","):find("," .. game.PlaceId .. ",", 1, true)) then
	state.visited = state.visited == "" and tostring(game.PlaceId) or (state.visited .. "," .. game.PlaceId)
end
H.state = state
local saveQueued = false
local function save()
	if saveQueued then return end
	saveQueued = true
	task.delay(1, function()
		saveQueued = false
		pcall(writefile, SAVE_FILE, HttpService:JSONEncode(state))
	end)
end
task.spawn(function() -- alive stamp for the resume-after-death/rejoin check above
	while H.alive do state.liveAt = os.time() save() task.wait(30) end
end)
local function kc(n, def)
	if type(n) ~= "string" then return def end
	local ok, k = pcall(function() return Enum.KeyCode[n] end); if ok and k then return k end
	ok, k = pcall(function() return Enum.UserInputType[n] end); if ok and k then return k end
	return def
end
local keys = { menu = kc(state.keyMenu, Enum.KeyCode.RightShift), farm = kc(state.keyFarm, Enum.KeyCode.F6),
	stop = kc(state.keyStop, Enum.KeyCode.F7) }
local KEY_SAVE = { menu = "keyMenu", farm = "keyFarm", stop = "keyStop" }
local function keyMatch(i, k) if k.EnumType == Enum.KeyCode then return i.KeyCode == k end return i.UserInputType == k end

-- ================= GAME HELPERS =================
local function hb() local c = lp.Character return c and c.PrimaryPart end
local function alive()
	local h = hb()
	return h ~= nil and h:FindFirstChild("state") ~= nil and h.state.Value ~= "dead"
		and h:FindFirstChild("health") ~= nil and h.health.Value > 0
end
local cacheT, cacheV = 0, nil
local function pdata()
	if os.clock() - cacheT > 0.5 or not cacheV then
		local ok, v = pcall(function() return BF.getLocalPlayerDataCache:Invoke() end)
		if ok and type(v) == "table" then cacheV, cacheT = v, os.clock() end
	end
	return cacheV
end
local function myLevel() local d = pdata() return d and d.level or 1 end
local itemCache = {}
local function itemBase(id)
	if id == nil then return nil end
	local c = itemCache[id]
	if c == nil then
		local ok, d = pcall(function() return itemData[id] end)
		c = (ok and type(d) == "table") and d or false
		itemCache[id] = c
	end
	return c or nil
end
local function itemName(id) local d = itemBase(id) return d and d.name or ("item " .. tostring(id)) end

local function weaponType()
	local d = pdata()
	if d and d.equipment then
		for _, e in pairs(d.equipment) do
			if e.position == 1 then local b = itemBase(e.id) return b and b.equipmentType or "sword" end
		end
	end
	return "sword"
end

-- monsterLookup lazily requires per-monster modules; some fail from executor threads -> pcall + cache
local mobCache = {}
local function mobData(name)
	if name == nil then return nil end
	local c = mobCache[name]
	if c == nil then
		local ok, d = pcall(function() return monsterLookup[name] end)
		c = (ok and type(d) == "table") and d or false
		mobCache[name] = c
	end
	return c or nil
end
local function mobInfo(m) return mobData(m:FindFirstChild("entityId") and m.entityId.Value or m.Name) end
local function isBoss(m) local d = mobInfo(m) return d ~= nil and d.boss == true end
local function isMob(m)
	if not m:IsA("BasePart") then return false end
	local et, hp = m:FindFirstChild("entityType"), m:FindFirstChild("health")
	if not et or et.Value ~= "monster" or not hp or hp.Value <= 0 then return false end
	local imm = m:FindFirstChild("isDamageImmune")
	return not (imm and imm.Value)
end
local function mobsNear(pos, r, limit)
	local out = {}
	for _, m in ipairs(ENT:GetChildren()) do
		if isMob(m) then
			local d = (m.Position - pos).Magnitude
			if d <= r then out[#out + 1] = { m, d } end
		end
	end
	table.sort(out, function(a, b) return a[2] < b[2] end)
	local res = {}
	for i = 1, math.min(limit or #out, #out) do res[i] = out[i][1] end
	return res
end

-- ================= ATTACK =================
local swingK = 0
local function swing()
	swingK += 1
	pcall(function()
		RE.fireEvent:FireServer("playerWillUseBasicAttack", lp)
		RE.replicatePlayerAnimationSequence:FireServer(weaponType() .. "Animations", swingK % 2 == 1 and "strike1" or "strike2", { attackSpeed = 0 })
	end)
end
local function sendHits(targets)
	local b = {}
	for _, m in ipairs(targets) do
		if m.Parent then b[#b + 1] = { m, m.Position, "equipment", "none", nil, HttpService:GenerateGUID(false) } end
	end
	if #b > 0 then pcall(function() RE.playerRequest_damageEntity_batch:FireServer(b) end) end
end
local function attack(targets)
	swing()
	task.wait(0.03)
	for _ = 1, math.max(1, math.floor(state.hitsPerSwing)) do sendHits(targets) end
end

-- ================= MOVEMENT =================
-- glide with matching velocity (passes the server's velocity/direction check); instant = one-frame jump (risk: kick)
local function stopTravel() H.tok += 1 end
-- NaN-safe: a zero vector's .Unit is NaN (standing straight above/below the goal) -> poisons the CFrame
local function finite(v) return v == v and math.abs(v.X) < 1e7 and math.abs(v.Y) < 1e7 and math.abs(v.Z) < 1e7 end
local function flatDir(from, to)
	local v = (from - to) * Vector3.new(1, 0, 1)
	return v.Magnitude > 0.1 and v.Unit or Vector3.new(1, 0, 0)
end
H.finite = finite
H.traveling = 0
H.ugDown = function() -- ugCap: pickups need ~11 studs, so they surface to at most ugCap below
	-- only while auto farm / auto quest drive us; kill aura or pickups alone stay on the surface
	local on = state.underground and (state.farm or state.autoQuest)
	return on and Vector3.new(0, -math.min(state.ugDepth, H.ugCap or math.huge), 0) or Vector3.zero
end
local function travel(goal, stopDist, maxT)
	local h = hb()
	if not h then return false end
	H.tok += 1
	local my = H.tok
	stopDist = stopDist or 3
	local function g()
		local p = goal
		if typeof(goal) == "function" then p = goal() end
		return p and p + H.ugDown() -- underground: every travel goal sits ugDepth below
	end
	if state.instantTp then
		local p = g()
		if not p then return false end
		h.AssemblyLinearVelocity = (p - h.Position) / 0.25
		h.CFrame = CFrame.new(p)
		RunService.Heartbeat:Wait()
		if hb() then hb().AssemblyLinearVelocity = Vector3.zero end
		return true
	end
	local t0, last, lastT, clips = os.clock(), h.Position, os.clock(), 0
	while my == H.tok and H.alive and alive() and os.clock() - t0 < (maxT or 30) do
		local dt = RunService.Heartbeat:Wait()
		H.traveling = os.clock()
		h = hb()
		local p = g()
		if not h or not p or not finite(p) then return false end
		local d = p - h.Position
		if d.Magnitude <= stopDist then h.AssemblyLinearVelocity = Vector3.zero return true end
		local dir = d.Unit
		local np = h.Position + dir * math.min(d.Magnitude, state.speed * dt)
		local look = Vector3.new(dir.X, 0, dir.Z)
		h.CFrame = look.Magnitude > 0.01 and CFrame.lookAt(np, np + look) or CFrame.new(np)
		h.AssemblyLinearVelocity = dir * state.speed
		if os.clock() - lastT > 0.5 then -- stuck (wall, terrain, barrier pushing back): micro clip through it
			if (h.Position - last).Magnitude < state.speed * 0.15 then
				clips += 1
				if clips > 8 then h.AssemblyLinearVelocity = Vector3.zero return false end
				H.clipUntil = os.clock() + 1.2 -- noclip window (underground heartbeat handles the parts)
				local hop = math.min(d.Magnitude - stopDist, 3)
				if hop > 0 then h.CFrame = h.CFrame + dir * hop end
			end
			last, lastT = h.Position, os.clock()
		end
	end
	if hb() then hb().AssemblyLinearVelocity = Vector3.zero end
	return false
end
H.travel = travel

-- glue: while engaging, sit next to the target every frame (same velocity as the target)
con(RunService.Heartbeat, function()
	local m = H.glue
	local h = hb()
	if not m or not h or not m.Parent then return end
	-- no underground offset while fighting: measured 2026-10-04 (Redwood, Wooden Club vs Baby Yeti) the server rejects
	-- every melee hit from inside the terrain (0 dmg at 11/9/5/3 studs below), surfaced next to it = 5 kills in ~10s.
	-- Underground still applies to travel; we only pop up beside the target for the fight.
	local off = (h.Position - m.Position) * Vector3.new(1, 0, 1)
	off = off.Magnitude > 0.1 and off.Unit or Vector3.new(1, 0, 0)
	local p = m.Position + off * math.min(m.Size.X / 2 + state.farmDist, 9) + Vector3.new(0, state.farmHeight, 0)
	h.CFrame = CFrame.lookAt(p, Vector3.new(m.Position.X, p.Y, m.Position.Z))
	h.AssemblyLinearVelocity = m.AssemblyLinearVelocity
end)

-- underground: only while the hub moves us (glide/travel) or sticks to a farm target (glue) - travel goals and the
-- glue spot sit ugDepth lower (H.ugDown), here we noclip through the terrain and surface again once the hub idles.
;(function()
	local saved, lastNoclip, wasOn, ugWas, holdPos = {}, 0, false, false, nil
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Exclude
	local function noclip(on)
		local c = lp.Character
		if not c then return end
		for _, p in ipairs(c:GetDescendants()) do
			if p:IsA("BasePart") then
				if on then
					if saved[p] == nil then saved[p] = p.CanCollide end
					p.CanCollide = false
				elseif saved[p] ~= nil then
					p.CanCollide = saved[p]
				end
			end
		end
		if not on then table.clear(saved) end
	end
	local function surfaceY(pos) -- ground under pos, searched from just above the old ground level (skips roofs)
		rp.FilterDescendantsInstances = { lp.Character, ENT, workspace.CurrentCamera }
		local r = workspace:Raycast(Vector3.new(pos.X, pos.Y + state.ugDepth + 8, pos.Z), Vector3.new(0, -(state.ugDepth + 60), 0), rp)
		return r and r.Position.Y
	end
	H.ugSurface = function() -- back up onto the ground
		local h = hb()
		if not h then return end
		local y = surfaceY(h.Position)
		if y then h.CFrame = CFrame.new(h.Position.X, y + 3.5, h.Position.Z) * (h.CFrame - h.CFrame.Position) end
		h.AssemblyLinearVelocity = Vector3.zero
	end
	local lastGood, lastWarn = nil, 0
	local function warnNaN(what)
		if os.clock() - lastWarn > 5 then lastWarn = os.clock() log("fixed NaN " .. what) end
	end
	-- the game's controlScript aims hitboxGyro at the flattened mouse/look direction every frame; straight above/below
	-- a target that direction is zero -> NaN gyro -> NaN velocity -> you hang or fall into the void. Repair the movers
	-- right before physics (Stepped runs after the controlScript's RenderStepped).
	con(RunService.Stepped, function()
		local h = hb()
		if not h then return end
		local gyro = h:FindFirstChild("hitboxGyro")
		if gyro then
			local cf = gyro.CFrame
			if cf.LookVector ~= cf.LookVector or not finite(cf.Position) then
				local lv = h.CFrame.LookVector * Vector3.new(1, 0, 1)
				gyro.CFrame = (lv == lv and lv.Magnitude > 0.1) and CFrame.lookAt(Vector3.zero, lv) or CFrame.new()
				warnNaN("gyro")
			end
		end
		local bv = h:FindFirstChild("hitboxVelocity")
		if bv and not (finite(bv.Velocity) and bv.Velocity.Magnitude < 2000) then bv.Velocity = Vector3.zero warnNaN("body velocity") end
		-- NaN angular velocity re-poisons the linear velocity every physics step -> clear both
		if not finite(h.AssemblyAngularVelocity) then h.AssemblyAngularVelocity = Vector3.zero warnNaN("angular velocity") end
		if not finite(h.AssemblyLinearVelocity) then h.AssemblyLinearVelocity = Vector3.zero warnNaN("velocity") end
	end)
	con(RunService.Heartbeat, function() -- last resort: NaN/huge position -> back to the last good spot
		local h = hb()
		if not h then lastGood = nil return end
		if finite(h.Position) and finite(h.AssemblyLinearVelocity) then
			lastGood = h.Position
		elseif not finite(h.Position) then
			H.glue = nil stopTravel()
			h.AssemblyLinearVelocity = Vector3.zero
			if lastGood then h.CFrame = CFrame.new(lastGood + Vector3.new(0, 3, 0)) end
			warnNaN("position")
		end
	end)
	con(RunService.Heartbeat, function()
		local h = hb()
		if not h or not alive() then
			if wasOn then wasOn = false noclip(false) end
			ugWas = false
			return
		end
		-- 1 s grace bridges the short gaps between travel -> glue -> next target, so we don't bob up and down
		local ugNow = state.underground and (state.farm or state.autoQuest) and (H.glue ~= nil or os.clock() - H.traveling < 1)
		if ugNow or os.clock() < (H.clipUntil or 0) then
			if not wasOn or os.clock() - lastNoclip > 0.5 then lastNoclip = os.clock() noclip(true) end
			wasOn = true
			if ugNow then ugWas = true end
			-- noclip but nothing drives us this frame (between kills / after a glide): hold still, else we fall
			if not H.glue and os.clock() - H.traveling > 0.05 then
				holdPos = holdPos or h.Position
				h.AssemblyLinearVelocity = Vector3.zero
				h.CFrame = CFrame.new(holdPos) * (h.CFrame - h.CFrame.Position)
			else
				holdPos = nil
			end
			return
		end
		holdPos = nil
		if wasOn then wasOn = false noclip(false) end
		if ugWas then ugWas = false H.ugSurface() end
	end)
end)()

-- no fall damage: controlScript skips the landing "gettingUp" report (fall height -> server damage + stun) when the
-- hitbox has attribute NoFall, and clears it after every landing -> keep setting it every frame
;(function()
	local had = false
	con(RunService.Stepped, function()
		local h = hb()
		if not h then return end
		if state.noFall then
			if h:GetAttribute("NoFall") ~= true then h:SetAttribute("NoFall", true) end
			had = true
		elseif had then
			had = false
			h:SetAttribute("NoFall", nil)
		end
	end)
end)()

-- ================= SURVIVAL =================
local lastHeal = 0
local function healSlot()
	local d = pdata()
	if not d or not d.inventory then return nil end
	local best, bestScore
	for _, s in pairs(d.inventory) do
		local b = itemBase(s.id)
		if b and b.sharedCooldownTag == "healingConsumable" then
			local score = (b.itemType == "potion" and 0 or 1) * 1e6 + (b.sellValue or 0) -- potions first, cheap first
			if not bestScore or score < bestScore then best, bestScore = s, score end
		end
	end
	return best
end
local function tryHeal()
	local h = hb()
	if not state.autoHeal or not alive() or os.clock() - lastHeal < 1.5 then return end
	if h.health.Value / math.max(h.maxHealth.Value, 1) * 100 >= state.healAt then return end
	local s = healSlot()
	if not s then return end
	lastHeal = os.clock()
	local ok, r = pcall(function() return BF.activateItemRequestLocal:Invoke(s) end)
	log(("heal %s -> %s"):format(itemName(s.id), tostring(ok and r)))
end
local deadSince
local function handleDeath()
	if alive() then deadSince = nil return false end
	deadSince = deadSince or os.clock()
	H.glue = nil
	if state.autoRespawn and os.clock() - deadSince > 3 then
		deadSince = os.clock()
		pcall(function() RF.playerRequest_respawnMyCharacter:InvokeServer() end)
		log("respawn requested")
	end
	return true
end

-- ================= LOOT / CHESTS / RESOURCES =================
local itemFail = {}
local function pickable(it)
	if not it:IsA("BasePart") or (itemFail[it] and itemFail[it] > os.clock()) then return false end
	local cp = it:FindFirstChild("canPickup")
	return not cp or cp.Value == true
end
local function nextItem(range, ids) -- ids: only these item ids (quest items)
	local h = hb()
	if not h then return nil end
	local best, bd
	for _, it in ipairs(ITEMS:GetChildren()) do
		local want = true
		if ids then
			local md = it:FindFirstChild("metadata")
			local ok, t = pcall(function() return HttpService:JSONDecode(md.Value) end)
			want = ok and type(t) == "table" and ids[t.id] == true
		end
		if want and pickable(it) then
			local d = (it.Position - h.Position).Magnitude
			if d <= range and (not bd or d < bd) then best, bd = it, d end
		end
	end
	return best
end
local function itemLabel(it)
	local md = it:FindFirstChild("metadata")
	if md then
		local ok, t = pcall(HttpService.JSONDecode, HttpService, md.Value)
		if ok and type(t) == "table" then return itemName(t.id) .. ((t.stacks or 1) > 1 and (" x" .. t.stacks) or "") end
	end
	return it.Name
end
local function pickUp(it)
	status("loot: " .. itemLabel(it))
	H.ugCap = 6
	local reached = travel(function() return it.Parent and it.Position + Vector3.new(0, 1.5, 0) end, 4, 15)
	H.ugCap = nil
	if not reached then
		itemFail[it] = os.clock() + 20 return
	end
	local ok, r = pcall(function() return RF.playerRequest_pickUpItem:InvokeServer(it) end)
	if ok and r then H.stats.picks += 1 log("picked " .. itemLabel(it)) else itemFail[it] = os.clock() + 20 end
end

local chestCd = {}
local function chestList()
	local out, seen = {}, {}
	local f = workspace:FindFirstChild("Chests")
	if f then for _, c in ipairs(f:GetChildren()) do if c:IsA("Model") and c.PrimaryPart then out[#out + 1] = c seen[c] = true end end end
	for _, c in ipairs(CollectionService:GetTagged("treasureChest")) do
		if not seen[c] and c:IsA("Model") and c.PrimaryPart then out[#out + 1] = c end
	end
	return out
end
local function nextChest()
	local h = hb()
	if not h then return nil end
	local lvl, best, bd = myLevel(), nil, nil
	for _, c in ipairs(chestList()) do
		local cl = c:FindFirstChild("chestLevel")
		if not (chestCd[c] and chestCd[c] > os.clock()) and (not cl or lvl >= cl.Value - 10) then
			local d = (c.PrimaryPart.Position - h.Position).Magnitude
			if not bd or d < bd then best, bd = c, d end
		end
	end
	return best
end
local function openChest(c)
	status("chest: " .. c.Name)
	local root = c.PrimaryPart
	if not travel(root.Position + root.CFrame.LookVector * 4 + Vector3.new(0, 1.5, 0), 3, 40) then chestCd[c] = os.clock() + 120 return end
	task.wait(0.35) -- let the server sample our new position first
	local ok, r = pcall(function() return RF.openTreasureChest:InvokeServer(c) end)
	if ok and type(r) == "table" then
		H.stats.chests += 1 chestCd[c] = os.clock() + 1800 log("opened chest " .. c.Name)
	else
		chestCd[c] = os.clock() + 900
	end
end

local RES_KEY = { crate = "resCrate", pot = "resPot", mushroom = "resMushroom", cabbage = "resCabbage",
	["oak tree"] = "resTree", ["apple tree"] = "resTree" }
local resFail = {}
local function nextResource()
	local h = hb()
	if not h or not RES then return nil end
	local best, bd
	for _, r in ipairs(RES:GetChildren()) do
		local k = RES_KEY[r.Name]
		if k and state[k] and (r:GetAttribute("health") or 0) > 0 and not (resFail[r] and resFail[r] > os.clock()) then
			local d = (r:GetPivot().Position - h.Position).Magnitude
			if d <= state.resRange and (not bd or d < bd) then best, bd = r, d end
		end
	end
	return best
end
local function breakResource(r)
	status("resource: " .. r.Name)
	local part = r:FindFirstChildWhichIsA("MeshPart") or r:FindFirstChildWhichIsA("BasePart")
	if not part then resFail[r] = os.clock() + 60 return end
	local p = r:GetPivot().Position
	if not travel(function() local h = hb() return h and p + flatDir(h.Position, p) * 4 + Vector3.new(0, 1, 0) end, 2.5, 20) then
		resFail[r] = os.clock() + 60 return
	end
	task.wait(0.3)
	local t0 = os.clock()
	while r.Parent and (r:GetAttribute("health") or 0) > 0 and os.clock() - t0 < 6 and alive() do
		swing()
		task.wait(0.05)
		pcall(function() RE.attackInteractionAttackableAttacked:FireServer(part, part.Position) end)
		task.wait(state.swingDelay)
	end
	if r.Parent and (r:GetAttribute("health") or 0) > 0 then resFail[r] = os.clock() + 120
	else H.stats.res += 1 end
end

-- ================= FARM =================
local FARM_MODES = { "Nearest mob", "Name filter", "Bosses first", "Bosses only", "Highest max HP first" }
local black = {}
local function farmTarget(onlyName)
	local h = hb()
	if not h then return nil end
	local lvl = myLevel()
	local filt
	if onlyName then
		filt = { [onlyName:lower()] = true }
	elseif state.farmMode == 2 then
		filt = {}
		for w in state.farmFilter:gmatch("[^,]+") do filt[w:lower():gsub("^%s+", ""):gsub("%s+$", "")] = true end
	end
	local best, bs
	for _, m in ipairs(ENT:GetChildren()) do
		if isMob(m) and not (black[m] and black[m] > os.clock()) then
			local boss = isBoss(m)
			local lv = m:FindFirstChild("level") and m.level.Value or 1
			local ok = lv <= lvl + state.farmLvlOver
			if filt and not filt[m.Name:lower()] then ok = false end
			if not onlyName and state.farmMode == 4 and not boss then ok = false end
			local d = (m.Position - h.Position).Magnitude
			if ok and (onlyName or d <= state.farmRadius) then -- quest targets: anywhere in the zone
				local score = d - ((state.farmMode == 3 and boss) and 1e6 or 0)
				if not onlyName and state.farmMode == 5 then -- biggest max HP wins, distance breaks ties
					score = d - (m:FindFirstChild("maxHealth") and m.maxHealth.Value or 0) * 1e4
				end
				if not bs or score < bs then best, bs = m, score end
			end
		end
	end
	return best
end
local function engage(m, keepGoing)
	keepGoing = keepGoing or function() return state.farm end
	H.target = m
	status(("%s: %s Lv%d"):format(H.questLabel or "farm", m.Name, m:FindFirstChild("level") and m.level.Value or 0))
	-- aim beside the mob (its body collides with ours, so its center is unreachable)
	local function beside()
		local h = hb()
		if not m.Parent or not h then return nil end
		if state.underground then return m.Position + Vector3.new(0, state.farmHeight, 0) end -- travel adds the depth
		local off = (h.Position - m.Position) * Vector3.new(1, 0, 1)
		off = off.Magnitude > 0.1 and off.Unit or Vector3.new(1, 0, 0)
		return m.Position + off * math.min(m.Size.X / 2 + state.farmDist, 9) + Vector3.new(0, state.farmHeight, 0)
	end
	if not travel(beside, 3, 25) then
		black[m] = os.clock() + 30 H.target = nil return
	end
	H.glue = m
	task.wait(0.35) -- server position sample catches up before the first hit
	local lastHp, lastChange = m.health.Value, os.clock()
	while keepGoing() and H.alive and m.Parent and m.health.Value > 0 and alive() do
		local targets = { m }
		if state.aura then
			for _, o in ipairs(mobsNear(hb().Position, state.auraRange, state.auraMax)) do
				if o ~= m then targets[#targets + 1] = o end
			end
		end
		attack(targets)
		task.wait(state.swingDelay)
		if m.Parent and m.health.Value < lastHp then lastHp, lastChange = m.health.Value, os.clock() end
		-- bosses / big HP pools have phases (jumps, shields): give them 15 s and only skip them for 15 s
		local big = isBoss(m) or (m:FindFirstChild("maxHealth") and m.maxHealth.Value >= 20000)
		if os.clock() - lastChange > (big and 15 or 6) then
			black[m] = os.clock() + (big and 15 or 60) log("no damage on " .. m.Name .. ", skipped") break
		end
	end
	H.glue = nil
	if not m.Parent or m.health.Value <= 0 then H.stats.kills += 1 end
	H.target = nil
end

-- ================= AUTO QUEST =================
-- questLookup (live): quest.objectives[i] = { giverNpcName, handerNpcName, autoSubmitQuest, requireLevel/minLevel, steps }
-- step.triggerType: monster-killed (requirement.monsterName), item-collected (requirement.id, sourceType monster/resource
-- + source name), level-reached, quest-submitted (optional). Player progress: pdata().quests[moduleName] =
-- { id, currentObjective, completed, objectives[i] = { started, steps[j] = { completion = { amount } } } }.
-- Accept: RF.playerRequest_startQuest(id, giverNpcName); turn in: RF.playerRequest_submitQuest(id, handerNpcName).
-- Both only work standing next to that NPC (remote start from 895 studs = false). No requireQuests chains exist.
local QUESTS = {}
do
	local ok, ql = pcall(require, RepS.questLookup)
	if ok and type(ql) == "table" then
		for _, q in pairs(ql) do
			if type(q) == "table" and q.id and type(q.objectives) == "table" then QUESTS[q.id] = q end
		end
	end
end
-- talk/speak quest steps: the NPC's dialogue module calls a quest remote (e.g. redwoodQuest_talkToNPC("Sid")).
-- Known ones first; otherwise decompile that NPC's dialogue once and take its first *talk* remote call.
local TALK_CALLS = {
	["Gregor"] = { "redwoodQuest_talkToGregor" },
	["Sid"] = { "redwoodQuest_talkToNPC", "Sid" },
	["Sir Tristain"] = { "redwoodQuest_talkToNPC", "Tristain" },
	["Rizan"] = { "redwoodQuest_talkToNPC", "RamKeeper" },
	["Reese"] = { "redwoodQuest_talkToNPC", "BearKeeper" },
	["Captain Bronzeheart"] = { "redwoodQuest_talkToNPC", "BronzeHeart" },
	["Lift Guard"] = { "redwoodQuest_talkToNPC", "LiftGuard" },
}
-- Working as a Warrior, objective 5 (Redwood lift): pass = RF.redwoodQuest_buyPass() at the Lift Guard (50 silver,
-- dialogue "Can I buy a pass?"); entering = RF.playerRequest_toggleElevator(workspace.elevator) at its interact part
local LIFT_PASS = 3168
local talkCache = {}
H.talkCall = function(npcName)
	if not npcName then return nil end
	if TALK_CALLS[npcName] then return TALK_CALLS[npcName] end
	if talkCache[npcName] ~= nil then return talkCache[npcName] or nil end
	talkCache[npcName] = false
	local m = workspace:FindFirstChild(npcName)
	local dl = m and m:FindFirstChild("dialogue", true)
	if not (dl and decompile) then return nil end
	local ok, src = pcall(decompile, dl)
	if not ok or type(src) ~= "string" then return nil end
	local name, args = src:match('invokeServer%(%s*"([%w_]*[Tt]alk[%w_]*)"%s*,?%s*([^%)]*)%)')
	if not name or not RF:FindFirstChild(name) then return nil end
	local call = { name }
	for a in (args or ""):gmatch('"([^"]*)"') do call[#call + 1] = a end
	talkCache[npcName] = call
	return call
end
-- quest step order: instant steps (talk/torso) -> "kill X" -> drops/resources -> "reach level N"
H.workPri = function(w)
	if w.kind == "talk" or w.kind == "torso" then return 1 end
	if not w.name then return 5 end
	if w.kind == "kill" and not w.drop then return 2 end
	return 3
end
local seenMobs = {}
local function noteMob(m)
	if m:FindFirstChild("entityType") and m.entityType.Value == "monster" then
		-- lowest live level seen: spawned mobs can be far above monsterLookup's base level (Redwood Bandit = 21)
		local lv = m:FindFirstChild("level") and m.level.Value or 1
		seenMobs[m.Name] = math.min(seenMobs[m.Name] or lv, lv)
	end
end
for _, m in ipairs(ENT:GetChildren()) do noteMob(m) end
con(ENT.ChildAdded, function(m) task.wait(0.2) noteMob(m) end)

local function npcModel(name)
	local m = name and workspace:FindFirstChild(name)
	return m and m:IsA("Model") and m or nil
end
local function questProgress()
	local out, d = {}, pdata()
	for _, pq in pairs(d and d.quests or {}) do if type(pq) == "table" and pq.id then out[pq.id] = pq end end
	return out
end
local function invCount(id)
	local n, d = 0, pdata()
	for _, s in pairs(d and d.inventory or {}) do if s.id == id then n += (s.stacks or 1) end end
	return n
end
local function stepNeed(s) return s.requirement and (s.requirement.amount or s.requirement._amount) or 1 end
local function stepHave(s, ps)
	local have = ps and ps.completion and ps.completion.amount or 0
	if s.triggerType == "item-collected" and s.requirement and s.requirement.id then have = math.max(have, invCount(s.requirement.id)) end
	if s.triggerType == "level-reached" then have = myLevel() end
	return have
end
local function stepDone(s, ps)
	if s.optional or (ps and ps.completed) then return true end
	return stepHave(s, ps) >= stepNeed(s)
end
local function mobOk(name)
	if not name or not seenMobs[name] then return false end
	local d = mobData(name)
	local lv = seenMobs[name] or (d and d.level) -- live level wins over the lookup's base level
	return not (type(lv) == "number" and lv > myLevel() + state.farmLvlOver)
end
local function resOk(name)
	if not RES or not name then return false end
	for _, r in ipairs(RES:GetChildren()) do if r.Name == name then return true end end
	return false
end
-- what to do for a step: {kind="kill", name=?} / {kind="res", name=} ; nil = optional/nothing ; false = can't automate
local function stepWork(s)
	if s.optional then return nil end
	local tt, rq = s.triggerType, s.requirement or {}
	if tt == "monster-killed" then
		return rq.monsterName and mobOk(rq.monsterName) and { kind = "kill", name = rq.monsterName } or false
	elseif tt == "item-collected" and rq.id == LIFT_PASS then
		return npcModel("Lift Guard") and { kind = "talk", name = "Lift Guard", call = { "redwoodQuest_buyPass" } } or false
	elseif tt == "enter-lift" then
		local el = workspace:FindFirstChild("elevator")
		if not (el and el:FindFirstChild("interact") and RF:FindFirstChild("playerRequest_toggleElevator")) then return false end
		return invCount(LIFT_PASS) > 0 and { kind = "lift", name = "the lift", model = el } or nil -- needs the pass first
	elseif tt == "item-collected" then
		if s.sourceType == "monster" then return mobOk(s.source) and { kind = "kill", name = s.source, drop = true } or false end
		if s.sourceType == "resource" then return resOk(s.source) and { kind = "res", name = s.source } or false end
		return false
	elseif tt == "level-reached" then
		return { kind = "kill" }
	elseif type(tt) == "string" and (tt:find("^talk%-") or tt:find("^speak%-")) and s.sourceType == "npc" then
		local call = H.talkCall(s.source)
		return (call and npcModel(s.source)) and { kind = "talk", name = s.source, call = call } or false
	elseif tt == "found-torso" then -- "Lost Adventurer": RF.playerRequest_gettorso(part) has no distance check
		local part = s.source and workspace:FindFirstChild(s.source)
		return part and { kind = "torso", name = s.source, part = part } or false
	elseif tt == "applied-stats" then -- "Staying On Point": the server counts playerRequest_incrementPlayerStatPointsByStatName
		local d = pdata()
		local free = d and d.statistics and d.statistics.pointsUnassigned or 0
		return free > 0 and { kind = "stat", name = "stat point" } or false
	end
	return false
end
-- repeatable quests have a cooldown (repeatableData.timeInterval, e.g. Abigail's Apples 14400 s) counted from
-- lastTimeCompleted; turning in or re-accepting before that returns false
local function repeatWait(q, pq)
	local iv = q.repeatableData and q.repeatableData.value and q.repeatableData.timeInterval
	local last = pq and pq.lastTimeCompleted
	if not (iv and last) then return 0 end
	return math.max(0, last + iv - workspace:GetServerTimeNow())
end
local function objLevelOk(q, o)
	local lvl = myLevel()
	return lvl >= (q.requireLevel or 1) and lvl >= (o.requireLevel or 1) and lvl >= (o.minLevel or 1)
end
-- every unfinished non-optional step must be automatable, and at least one step must need work
local function objWorkable(o, po)
	local any = false
	for i, s in pairs(o.steps or {}) do
		local ps = po and po.steps and po.steps[i]
		if not stepDone(s, ps) then
			local w = stepWork(s)
			if w == false then return false end
			if w then any = true end
		end
	end
	return any
end
local questCd = {}
H.questInfo = {}
local function questAction()
	local prog = questProgress()
	local h = hb()
	if not h then return nil end
	local work
	H.questInfo = {}
	H.questItems = {}
	for id, pq in pairs(prog) do
		local q = QUESTS[id]
		if q and not pq.completed then
			local ci = pq.currentObjective or 1
			local o, po = q.objectives[ci], pq.objectives and pq.objectives[ci]
			if o then
				local parts, allDone, act, blocked = {}, true, nil, false
				for i, s in pairs(o.steps or {}) do
					local ps = po and po.steps and po.steps[i]
					if not s.optional then
						parts[#parts + 1] = ("%s %d/%d"):format(s.requirement and (s.requirement.monsterName or (s.requirement.id and itemName(s.requirement.id))) or s.triggerType, stepHave(s, ps), stepNeed(s))
					end
					if not stepDone(s, ps) then
						allDone = false
						if s.triggerType == "item-collected" and s.requirement and s.requirement.id then H.questItems[s.requirement.id] = true end
						local w = stepWork(s)
						if w == false then blocked = true elseif w and not act then act = w end
					end
				end
				local rw = repeatWait(q, pq)
				local cd = (questCd[id] and questCd[id] > os.clock()) or rw > 0
				local tag = blocked and " (manual)" or (rw > 0 and (" (repeat in %dh%02dm)"):format(rw // 3600, rw % 3600 // 60)) or ""
				H.questInfo[#H.questInfo + 1] = ("%s%s: %s"):format(q.name, tag, table.concat(parts, ", "))
				if not cd then
					if not (po and po.started) then
						if npcModel(o.giverNpcName) and objLevelOk(q, o) and objWorkable(o, po) then
							return { kind = "start", q = q, o = o, npc = o.giverNpcName }
						end
					elseif allDone then
						if not o.autoSubmitQuest and npcModel(o.handerNpcName) then
							return { kind = "submit", q = q, o = o, npc = o.handerNpcName }
						end
					elseif act and not blocked and (not work or H.workPri(act) < H.workPri(work)) then
						act.q = q
						work = act
					end
				end
			end
		end
	end
	-- a named target (kill X / collect Y) goes first; plain "reach level N" only when there's nothing new to accept,
	-- otherwise a long level quest blocked accepting forever
	if work and work.name then return work end
	if not state.questAccept then return work end
	local best, bd
	for id, q in pairs(QUESTS) do
		local pq = prog[id]
		local again = pq and pq.completed and state.questRepeat and q.repeatableData and q.repeatableData.value and repeatWait(q, pq) <= 0
		if (not pq or again) and not (questCd[id] and questCd[id] > os.clock()) then
			local o = q.objectives[1]
			local npc = o and npcModel(o.giverNpcName)
			if npc and objLevelOk(q, o) and objWorkable(o, nil) then
				local d = (npc:GetPivot().Position - h.Position).Magnitude
				if not bd or d < bd then best, bd = { kind = "start", q = q, o = o, npc = o.giverNpcName }, d end
			end
		end
	end
	return best or work
end
local function talkTo(npcName)
	local m = npcModel(npcName)
	if not m then return false end
	-- quest start/turn-in/talk only works right next to the NPC (measured: 2.9 studs = true, ~5 + 2 below = false)
	H.ugCap = 0
	local ok = travel(function() local p = m:GetPivot().Position local hh = hb()
		return hh and p + flatDir(hh.Position, p) * 3 + Vector3.new(0, 1, 0) end, 1.5, 60)
	H.ugCap = nil
	return ok
end
local function doQuest(a)
	local q = a.q
	H.questLabel = "quest " .. q.name
	if a.kind == "start" or a.kind == "submit" then
		status(("quest: %s %s at %s"):format(a.kind == "start" and "accept" or "turn in", q.name, a.npc))
		if talkTo(a.npc) then
			task.wait(0.4)
			local remote = a.kind == "start" and RF.playerRequest_startQuest or RF.playerRequest_submitQuest
			local ok, r = pcall(function() return remote:InvokeServer(q.id, a.npc) end)
			log(("quest %s %s -> %s"):format(a.kind, q.name, tostring(ok and r)))
			if ok and r then
				if a.kind == "submit" then H.stats.quests = (H.stats.quests or 0) + 1 end
				cacheT = 0
			else
				questCd[q.id] = os.clock() + 300
			end
		else
			questCd[q.id] = os.clock() + 120
		end
	elseif a.kind == "kill" then
		local m = farmTarget(a.name)
		if m then
			engage(m, function() return state.autoQuest end)
			cacheT = 0
		else
			-- none in reach/level right now: park this quest for a minute so grind/other quests run instead of idling
			status(("quest %s: no %s in level range - parked 60s"):format(q.name, a.name or "mobs"))
			questCd[q.id] = os.clock() + 60
			task.wait(0.5)
		end
	elseif a.kind == "stat" then
		local stat = ({ "str", "dex", "int", "vit" })[state.statPick] or "str"
		local ok, r = pcall(function() return RF.playerRequest_incrementPlayerStatPointsByStatName:InvokeServer(stat) end)
		log(("quest %s: +1 %s -> %s"):format(q.name, stat, tostring(ok and r)))
		if not (ok and r) then questCd[q.id] = os.clock() + 120 end
		cacheT = 0
		task.wait(0.5)
	elseif a.kind == "talk" then
		status(("quest %s: talk to %s"):format(q.name, a.name))
		if talkTo(a.name) then
			task.wait(0.4)
			local ok, r = pcall(function() return RF[a.call[1]]:InvokeServer(table.unpack(a.call, 2)) end)
			log(("quest %s: talk %s (%s) -> %s"):format(q.name, a.name, a.call[1], tostring(ok and (r == nil and "sent" or r))))
		end
		questCd[q.id] = os.clock() + 8 -- let the progress replicate
		cacheT = 0
	elseif a.kind == "lift" then
		status(("quest %s: riding %s"):format(q.name, a.name))
		local part = a.model.interact
		if travel(part.Position + Vector3.new(0, 2, 0), 4, 60) then
			task.wait(0.4)
			local ok, r = pcall(function() return RF.playerRequest_toggleElevator:InvokeServer(a.model) end)
			log(("quest %s: lift -> %s"):format(q.name, tostring(ok and (r == nil and "sent" or r))))
		end
		questCd[q.id] = os.clock() + 10
		cacheT = 0
	elseif a.kind == "torso" then
		local ok, r = pcall(function() return RF.playerRequest_gettorso:InvokeServer(a.part) end)
		log(("quest %s: found %s -> %s"):format(q.name, a.name, tostring(ok and (r == nil and "sent" or r))))
		questCd[q.id] = os.clock() + 10 -- let the progress replicate before trying again
		cacheT = 0
		task.wait(1)
	elseif a.kind == "res" then
		local h, best, bd = hb(), nil, nil
		for _, r in ipairs(RES:GetChildren()) do
			if r.Name == a.name and (r:GetAttribute("health") or 0) > 0 and not (resFail[r] and resFail[r] > os.clock()) then
				local d = (r:GetPivot().Position - h.Position).Magnitude
				if not bd or d < bd then best, bd = r, d end
			end
		end
		if best then breakResource(best) else status(("quest %s: waiting for %s"):format(q.name, a.name)) task.wait(1) end
	end
	H.questLabel = nil
end

-- ================= BRAIN (one task at a time: death > loot > quests > chests > resources > farm) =================
local function loop(name, fn)
	H.threads[name] = task.spawn(function()
		while H.alive do
			local ok, e = xpcall(fn, function(err) return tostring(err) .. " | " .. debug.traceback():gsub("%s+", " "):sub(1, 220) end)
			if not ok then log(name .. " error: " .. tostring(e)) task.wait(1) end
		end
	end)
end
-- ================= ZONE TRAVEL (auto quest moves on when the zone is done) =================
-- Zone exits = parts tagged "teleportPart" (teleportDestination = PlaceId, minLevel). Touching one makes the client call
-- RF.playerRequest_useTeleporter(part) within 50 studs (MaxActivationDistance). The quest line names the next zone in
-- its notes ("Venture out towards The Moat."), so the exit whose place name appears there wins; otherwise the highest
-- level exit we're allowed through that doesn't lead back where we came from. The teleport kills the script: the
-- resume flag + autoexec (vesteria.lua) bring the hub back with auto quest on.
do
local placeNames = {}
local function placeName(id)
	if placeNames[id] == nil then
		local ok, info = pcall(function() return game:GetService("MarketplaceService"):GetProductInfo(id) end)
		placeNames[id] = ok and info and info.Name or false
	end
	return placeNames[id] or nil
end
local function questHints()
	local txt = {}
	for id, pq in pairs(questProgress()) do
		local q = QUESTS[id]
		if q then
			for i, o in pairs(q.objectives or {}) do
				local po = pq.objectives and pq.objectives[i]
				-- only "where to go next" notes of finished objectives; incompletedHint names the current zone
				-- ("Complete quests around Mushtown") and once sent us back
				if pq.completed or (po and po.completed) then
					txt[#txt + 1] = tostring(o.completedNotes or "") .. " " .. tostring(o.completedText or "")
				end
			end
		end
	end
	return table.concat(txt, " "):lower()
end
-- Conservative on purpose: wandering by "unvisited" alone went Nilgarf -> Great Crossroads -> Sewers (Lv21-24 mobs at
-- Lv11, next exit The Pit Lv35-50). Allowed exits: (a) the quest line names the destination and we haven't been
-- there, or (b) this zone is a transit zone (no monsters, no quest givers - e.g. The Moat) -> any new exit, never back.
local loadedAt = os.clock()
local function isTransit()
	for _, m in ipairs(ENT:GetChildren()) do
		if m:FindFirstChild("entityType") and m.entityType.Value == "monster" then return false end
	end
	for _, q in pairs(QUESTS) do
		for _, o in pairs(q.objectives or {}) do
			if npcModel(o.giverNpcName) then return false end
		end
	end
	return true
end
local function zoneExit()
	if os.clock() - loadedAt < 20 then return nil, "settling" end -- NPCs/mobs of a fresh place still loading
	local lvl, hints = myLevel(), questHints()
	local transit = isTransit()
	local exits = {}
	for _, p in ipairs(CollectionService:GetTagged("teleportPart")) do
		local dest = p:IsA("BasePart") and p:FindFirstChild("teleportDestination")
		if dest and dest.Value ~= 0 and dest.Value ~= game.PlaceId then exits[#exits + 1] = p end
	end
	local best, bestScore
	for _, p in ipairs(exits) do
		local dest = p.teleportDestination
		local minL = p:FindFirstChild("minLevel") and p.minLevel.Value or 0
		if p:GetAttribute("Enabled") ~= false and lvl >= minL then
			local name = placeName(dest.Value)
			local visited = (("," .. state.visited .. ","):find("," .. dest.Value .. ",", 1, true)) ~= nil
			local hinted = name ~= nil and hints:find(name:lower(), 1, true) ~= nil and not visited
			local back = dest.Value == state.lastPlace and #exits > 1
			local ok = hinted or (transit and not visited and not back) or (transit and #exits == 1)
			if ok then
				local score = (hinted and 1e6 or 0) + minL
				if not bestScore or score > bestScore then best, bestScore = p, score end
			end
		end
	end
	return best, best and placeName(best.teleportDestination.Value)
end
H.zoneExit = zoneExit
local function takeExit(p, name)
	status("quest: zone done, travelling to " .. tostring(name))
	log("zone done here -> exit to " .. tostring(name))
	H.ugCap = 2 -- underground mode: surface, the exit is touched like a normal walk-in
	local arrived = travel(p.Position, 4, 120)
	H.ugCap = nil
	if not arrived then return false end
	state.resumeAt = os.time()
	state.lastPlace = game.PlaceId
	pcall(writefile, SAVE_FILE, HttpService:JSONEncode(state)) -- now, the teleport may come before the save debounce
	local ok, r = pcall(function() return RF.playerRequest_useTeleporter:InvokeServer(p) end)
	log(("useTeleporter %s -> %s"):format(tostring(name), tostring(ok and r)))
	-- the server can still teleport us after answering false (seen live), so keep the resume flag while we wait;
	-- the place teleport ends this script
	status("teleporting to " .. tostring(name))
	task.wait(20)
	state.resumeAt = 0
	save()
	return false
end
H.takeExit = takeExit
end

loop("brain", function()
	task.wait(0.1)
	if handleDeath() then status("dead, waiting for respawn") return end
	local busy = state.farm or state.chests or state.resources or state.autoQuest
	-- an NPC dialogue (opened next to a quest NPC) arrests the character -> close it, only while auto quest runs
	if state.autoQuest and lp:GetAttribute("isInDialogue") then
		pcall(function() BF.endDialogue:Invoke() end)
		pcall(function() BF.setCharacterArrested:Invoke(false) end)
		log("closed NPC dialogue")
		task.wait(0.3)
		return
	end
	if state.loot then
		local it = nextItem(busy and state.lootRange or 25)
		if it then pickUp(it) return end
	elseif state.autoQuest and H.questItems and next(H.questItems) then -- quest drops even with auto pickup off
		local it = nextItem(state.lootRange, H.questItems)
		if it then pickUp(it) return end
	end
	if state.autoQuest then
		local a = questAction()
		if a then doQuest(a) return end
		-- nothing left here: move on along the quest line, or level up until the next exit opens
		if state.questTravel and not (H.exitFail and H.exitFail > os.clock()) then
			local p, name = H.zoneExit()
			if p then
				if not H.takeExit(p, name) then H.exitFail = os.clock() + 60 end
				return
			end
		end
		if state.questGrind and not state.farm then
			-- XP grind: highest-level mob within the level cap, nothing more than 6 levels below us (Lv1 chickens at Lv11 = no XP)
			local lvl, h, m, best = myLevel(), hb(), nil, nil
			for _, e in ipairs(ENT:GetChildren()) do
				if h and isMob(e) and not (black[e] and black[e] > os.clock()) then
					local lv = e:FindFirstChild("level") and e.level.Value or 0
					if lv >= lvl - 6 and lv <= lvl + state.farmLvlOver then
						local sc = lv * 1e4 - (e.Position - h.Position).Magnitude
						if not best or sc > best then m, best = e, sc end
					end
				end
			end
			if m then H.questLabel = "quest grind" engage(m, function() return state.autoQuest end) H.questLabel = nil return end
		end
		status("quest: nothing automatable here (see Quests tab) - no quest-line exit")
		task.wait(2)
	end
	if state.chests then local c = nextChest() if c then openChest(c) return end end
	if state.resources then local r = nextResource() if r then breakResource(r) return end end
	if state.farm then
		local m = farmTarget()
		if m then engage(m) return end
		status("farm: no target (radius/filter/level)")
		task.wait(1)
		return
	end
	status("idle")
	task.wait(0.4)
end)
loop("aura", function() -- standalone kill aura when the farm isn't driving
	task.wait(state.swingDelay)
	if not state.aura or H.glue or not alive() then task.wait(0.2) return end
	local t = mobsNear(hb().Position, state.auraRange, state.auraMax)
	if #t > 0 then attack(t) end
end)
-- auto sell: playerRequest_sellItemsToShop({{serial, stacks}}, shopInfo) has NO distance check (sold from 794 studs);
-- shopInfo = any merchant's "inventory" ModuleScript in workspace as source/module. Limits per category from the
-- game's own inventory_util (miscellaneous/equipment/consumable = 20 each by default).
;(function()
	local okU, invUtil = pcall(require, RepS.modules.inventory_util)
	local okI, iUtil = pcall(require, RepS.modules.item_util)
	local function category(b)
		if okI then local ok, c = pcall(iUtil.getItemCategory, b, "inventory") if ok and c then return c end end
		return b.itemType == "misc" and "miscellaneous" or "other"
	end
	local function shops()
		local h, out = hb(), {}
		for _, d in ipairs(workspace:GetDescendants()) do
			if d:IsA("ModuleScript") and d.Name == "inventory" and d.Parent:IsA("BasePart") and d.Parent:HasTag("interact") then
				out[#out + 1] = d
			end
		end
		if h then table.sort(out, function(a, b) return (a.Parent.Position - h.Position).Magnitude < (b.Parent.Position - h.Position).Magnitude end) end
		return out
	end
	local function freeSlots(cat)
		if not okU then return math.huge end
		local d = pdata()
		local okM, mx = pcall(invUtil.getMaximumSize, lp, "inventory", cat)
		if not (okM and type(mx) == "number") then mx = 20 end
		-- count ourselves: inventory_util.getCurrentSize returned nil live (-> mx - nil errored, auto sell never ran)
		local cur = 0
		for _, it in pairs(d and d.inventory or {}) do
			local b = itemBase(it.id)
			if b and category(b) == cat then cur += 1 end
		end
		return mx - cur
	end
	H.sellNow = function(gearToo)
		local d = pdata()
		if not d or not d.inventory then return 0 end
		local list, value = {}, 0
		for _, it in pairs(d.inventory) do
			local b = itemBase(it.id)
			-- Common only: never sell Rare+ drops/gear; upgraded/enchanted gear is always kept
			local rarityOk = not state.sellCommonOnly or (b and (b.rarity or "Common") == "Common")
			local plain = not (it.upgrades or it.enchantments or it.blessed or it.attribute == "mythic")
			if b and it.serial and rarityOk and plain and not b.cantSell and not b.inventorybound and (b.sellValue or 0) > 0
				and b.itemType ~= "arrow" and not (H.questItems and H.questItems[it.id]) then
				local cat = category(b)
				if cat == "miscellaneous" or ((state.sellGear or gearToo) and cat == "equipment") then
					list[#list + 1] = { serial = it.serial, stacks = it.stacks or 1 }
					value += (b.sellValue or 0) * (it.stacks or 1)
				end
			end
		end
		if #list == 0 then return 0 end
		for _, mod in ipairs(shops()) do
			local ok, r, n = pcall(function()
				return RF.playerRequest_sellItemsToShop:InvokeServer(list, { source = mod, module = mod, isSpecific = true })
			end)
			if ok and r then
				log(("sold %s items (~%d gold) at %s"):format(tostring(n or #list), value, mod.Parent.Parent and mod.Parent.Parent.Name or "?"))
				cacheT = 0
				return #list
			end
		end
		log("auto sell: no merchant accepted")
		return 0
	end
	loop("sell", function()
		task.wait(3)
		if not state.autoSell then return end
		-- a full gear bag blocks quest rewards (Gregor: "it's too full for me to give you a set of gear" = talk step
		-- false forever), so Common unequipped gear goes when the gear bag is full even with "sell gear" off
		local gearFull = freeSlots("equipment") <= state.sellFree
		local full = freeSlots("miscellaneous") <= state.sellFree or gearFull
		if full then H.sellNow(gearFull) task.wait(2) end
	end)
end)()
-- auto equip best: item stats depend on level scaling, attributes (dull/tattered), upgrades and modifiers, so instead of
-- re-implementing that we try each candidate and read the real statistics_final back (updates ~0.8 s after the swap).
-- RF.playerRequest_transferInventoryToEquipment("equipment", inventoryPosition, equipmentSlot) swaps; the old piece goes
-- back to the inventory. Losers are remembered per level+mode so later passes only test new drops.
local EQUIP_MODES = { "Damage", "Health (vitality)", "Defense", "Balanced" }
do
local RANGED = { bow = true, staff = true, revolver = true }
local equipLosers = {}
local function finalStats()
	cacheT = 0
	local d = pdata()
	return d and d.nonSerializeData and d.nonSerializeData.statistics_final
end
local function equipScore(f, base)
	if not f then return -math.huge end
	local dmg, hp, def = f.damage or 0, f.maxHealth or 0, f.defense or 0
	if state.equipMode == 2 then return hp * 1e6 + def * 1e3 + dmg end
	if state.equipMode == 3 then return def * 1e6 + hp * 1e3 + dmg end
	if state.equipMode == 4 and base then
		return dmg / math.max(base.damage or 1, 1) + hp / math.max(base.maxHealth or 1, 1) + def / math.max(base.defense or 1, 1)
	end
	return dmg * 1e6 + hp * 1e3 + def
end
local function equipBySerial(serial, slot)
	local d = pdata()
	for _, s in pairs(d and d.inventory or {}) do
		if s.serial == serial then
			local ok, r = pcall(function() return RF.playerRequest_transferInventoryToEquipment:InvokeServer("equipment", s.position, slot) end)
			task.wait(0.8)
			cacheT = 0
			return ok and r
		end
	end
	return false
end
function H.equipBest()
	local d = pdata()
	if not d or not d.inventory then return 0 end
	local lvl, changed = d.level or 1, 0
	local key = lvl .. ":" .. state.equipMode .. ":" .. tostring(state.equipMelee)
	-- candidates per slot (one per id+attribute unless upgraded, so 15 identical boots = 1 test)
	local slots, seenKey = {}, {}
	for _, s in pairs(d.inventory) do
		local b = itemBase(s.id)
		if b and s.serial and b.isEquippable and b.equipmentSlot and not b.cosmetic and b.category == "equipment"
			and (b.minLevel or 1) <= lvl and equipLosers[s.serial] ~= key
			and not (b.equipmentSlot == 1 and state.equipMelee and RANGED[b.equipmentType or ""]) then
			local dk = s.id .. ":" .. tostring(s.attribute) .. ":" .. ((s.upgrades or s.enchantments) and s.serial or "")
			if not seenKey[dk] then
				seenKey[dk] = true
				slots[b.equipmentSlot] = slots[b.equipmentSlot] or {}
				table.insert(slots[b.equipmentSlot], s.serial)
			end
		end
	end
	for slot, cands in pairs(slots) do
		if not state.autoEquip and not H.equipForce then break end
		local cur
		for _, e in pairs(pdata().equipment or {}) do if e.position == slot then cur = e.serial end end
		local base = finalStats()
		local best, bestScore = cur, cur and equipScore(base, base) or -math.huge
		local last = cur
		for i = 1, math.min(#cands, 5) do
			local serial = cands[i]
			if equipBySerial(serial, slot) then
				last = serial
				local sc = equipScore(finalStats(), base)
				if sc > bestScore + 1e-6 then
					if best then equipLosers[best] = key end
					best, bestScore = serial, sc
				else
					equipLosers[serial] = key
				end
			else
				equipLosers[serial] = key
			end
		end
		if best and last ~= best then equipBySerial(best, slot) end
		if best ~= cur then
			changed += 1
			local b
			for _, e in pairs(pdata().equipment or {}) do if e.position == slot then b = itemBase(e.id) end end
			log(("equipped %s (slot %d, %s)"):format(b and b.name or "?", slot, EQUIP_MODES[state.equipMode]))
		end
	end
	return changed
end
loop("equip", function()
	task.wait(20)
	if state.autoEquip and alive() then H.equipBest() end
end)
end
-- ownership watchdog: the server sometimes takes network ownership of our hitbox (seen 2026-10-04 in Redwood after
-- long underground/glide sessions). From then on every move only happens locally, the server still has us elsewhere
-- and every hit is out of range ("no damage" skips forever). A respawn gives a fresh character we own again.
H.ownerLost = 0
loop("owner", function()
	task.wait(1)
	local h = hb()
	if not h or not alive() or not isnetworkowner then return end
	local ok, own = pcall(isnetworkowner, h)
	if not ok or own then H.ownerSince = nil return end
	H.ownerSince = H.ownerSince or os.clock()
	local busy = state.farm or state.autoQuest or state.chests or state.resources or state.aura
	if busy and os.clock() - H.ownerSince > 3 then
		H.ownerLost += 1
		log("lost control of the character (server owns it) -> respawning")
		H.glue = nil stopTravel()
		pcall(function() RF.playerRequest_respawnMyCharacter:InvokeServer() end)
		H.ownerSince = nil
		task.wait(8)
	end
end)
loop("survival", function()
	task.wait(0.25)
	tryHeal()
end)
loop("stats", function()
	task.wait(3)
	if not state.autoStats then return end
	local d = pdata()
	local st = d and d.statistics
	if not st then return end
	local stat = ({ "str", "dex", "int", "vit" })[state.statPick] or "str"
	local n = st.pointsUnassigned or 0
	for _ = 1, math.min(n, 20) do
		local ok, r = pcall(function() return RF.playerRequest_incrementPlayerStatPointsByStatName:InvokeServer(stat) end)
		if not (ok and r) then break end
		log("+1 " .. stat)
	end
	cacheT = 0
end)

-- daily / free rewards: each called once, results go to the log
local CLAIMS = { "playerRequest_GetDailyReward", "playerRequest_claimDailyEthyr", "playerRequest_claimGifts",
	"playerRequest_claimWelcome", "playerRequest_claimStoredGold", "playerRequest_RedeemCalendarDay" }
local function claimAll()
	for _, n in ipairs(CLAIMS) do
		local r = RF:FindFirstChild(n)
		if r then
			local ok, a, b = pcall(function() return r:InvokeServer() end)
			log(("%s -> %s %s"):format(n:gsub("playerRequest_", ""), tostring(ok and a), tostring(ok and b or (not ok and a) or "")))
		end
	end
end

-- anti AFK (Roblox idle kick after 20 min)
con(lp.Idled, function()
	if not state.antiAfk then return end
	pcall(function()
		local vu = game:GetService("VirtualUser")
		vu:CaptureController() vu:ClickButton2(Vector2.new())
	end)
end)

-- fullbright (zones reset Lighting -> reapply)
local fbOrig = { Brightness = Lighting.Brightness, ClockTime = Lighting.ClockTime, FogEnd = Lighting.FogEnd,
	GlobalShadows = Lighting.GlobalShadows, Ambient = Lighting.Ambient }
local function applyFB()
	if state.fullbright then
		Lighting.Brightness = 2 Lighting.ClockTime = 14 Lighting.FogEnd = 1e6 Lighting.GlobalShadows = false
		Lighting.Ambient = Color3.fromRGB(178, 178, 178)
	end
end
local function restoreFB() for k, v in pairs(fbOrig) do pcall(function() Lighting[k] = v end) end end
loop("fullbright", function() task.wait(1) applyFB() end)

-- ================= THEME / GUI KIT (TSC hub style) =================
local T = {
	bg = Color3.fromRGB(15, 15, 18), panel = Color3.fromRGB(20, 20, 24), panel2 = Color3.fromRGB(25, 25, 30),
	stroke = Color3.fromRGB(36, 36, 43), edge = Color3.fromRGB(46, 46, 54), track = Color3.fromRGB(32, 32, 38),
	off = Color3.fromRGB(34, 34, 41), accent = Color3.fromRGB(190, 70, 150), text = Color3.fromRGB(226, 226, 232),
	dim = Color3.fromRGB(122, 122, 134), font = Enum.Font.GothamMedium, bold = Enum.Font.GothamBold, ts = 13,
}
local gui = Instance.new("ScreenGui")
gui.Name = "VES_HUB"; gui.ResetOnSpawn = false; gui.IgnoreGuiInset = true; gui.DisplayOrder = 999
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = (gethui and gethui()) or CoreGui
H.gui = gui
local espFolder = Instance.new("Folder"); espFolder.Name = "VES_ESP"; espFolder.Parent = gui

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
main.Size = UDim2.fromOffset(560, 500); main.Position = UDim2.fromOffset(state.guiX, state.guiY)
main.Visible = state.guiVisible
main.BackgroundColor3 = T.bg; main.BorderSizePixel = 0; main.Active = true
main.Parent = gui
corner(main, 8); stroke(main, T.edge)

local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 30); titleBar.BackgroundTransparency = 1; titleBar.Active = true; titleBar.Parent = main
local statusTxt
do
	local tl2 = Instance.new("UIListLayout", titleBar); tl2.FillDirection = Enum.FillDirection.Horizontal
	tl2.VerticalAlignment = Enum.VerticalAlignment.Center; tl2.Padding = UDim.new(0, 8); tl2.SortOrder = Enum.SortOrder.LayoutOrder
	Instance.new("UIPadding", titleBar).PaddingLeft = UDim.new(0, 12)
	local a = txt(titleBar, "Vesteria Hub", UDim2.fromOffset(0, 30), T.accent); a.Font = T.bold; a.AutomaticSize = Enum.AutomaticSize.X; a.LayoutOrder = 1
	local b = txt(titleBar, "Interface", UDim2.fromOffset(0, 30), T.text); b.AutomaticSize = Enum.AutomaticSize.X; b.LayoutOrder = 2
	local c = txt(titleBar, lp.Name, UDim2.fromOffset(0, 18), T.accent); c.AutomaticSize = Enum.AutomaticSize.X; c.LayoutOrder = 3
	c.TextSize = 12; c.BackgroundColor3 = Color3.fromRGB(40, 18, 34); c.BackgroundTransparency = 0; corner(c, 6); stroke(c, Color3.fromRGB(90, 34, 72))
	local cp = Instance.new("UIPadding", c); cp.PaddingLeft = UDim.new(0, 7); cp.PaddingRight = UDim.new(0, 7)
	statusTxt = txt(titleBar, "", UDim2.fromOffset(0, 30), T.dim); statusTxt.AutomaticSize = Enum.AutomaticSize.X
	statusTxt.LayoutOrder = 4; statusTxt.TextSize = 12
end

do -- drag
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
	con(UIS.InputEnded, function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 and dragging then
			dragging = false; state.guiX = main.Position.X.Offset; state.guiY = main.Position.Y.Offset; save()
		end
	end)
end

local tabBar = Instance.new("Frame")
tabBar.Size = UDim2.new(1, -20, 0, 26); tabBar.Position = UDim2.fromOffset(8, 32); tabBar.BackgroundTransparency = 1; tabBar.Parent = main
local tl = Instance.new("UIListLayout", tabBar); tl.FillDirection = Enum.FillDirection.Horizontal; tl.Padding = UDim.new(0, 4)
tl.SortOrder = Enum.SortOrder.LayoutOrder
local content = Instance.new("Frame")
content.Size = UDim2.new(1, -16, 1, -74); content.Position = UDim2.fromOffset(8, 66); content.BackgroundTransparency = 1
content.Parent = main

do -- collapse: "-" in the title bar folds the window down to the title bar
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.fromOffset(24, 20); btn.Position = UDim2.new(1, -30, 0, 5); btn.AutoButtonColor = false
	btn.BackgroundColor3 = T.panel2; btn.Font = T.bold; btn.TextSize = 14; btn.TextColor3 = T.text; btn.ZIndex = 5
	btn.Parent = main
	corner(btn, 5); stroke(btn, T.edge)
	local function apply()
		local c = state.guiCollapsed
		tabBar.Visible = not c; content.Visible = not c
		main.Size = UDim2.fromOffset(560, c and 30 or 500)
		btn.Text = c and "+" or "-"
	end
	apply()
	con(btn.MouseButton1Click, function() state.guiCollapsed = not state.guiCollapsed apply() save() end)
end

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
local function tab(name)
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
	return mkCol(page, false), mkCol(page, true)
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

local listening, keyBoxes = nil, {}
local function keyName(k) if not k then return "none" end return (k.Name:lower():gsub("mousebutton", "mouse")) end
local function keybox(parent, id)
	local b = Instance.new("TextButton")
	b.Size = UDim2.fromOffset(78, 18); b.AnchorPoint = Vector2.new(1, 0); b.Position = UDim2.new(1, 0, 0, 0)
	b.BackgroundColor3 = T.panel2; b.BorderSizePixel = 0; b.AutoButtonColor = false
	b.Font = T.font; b.TextSize = 12; b.TextColor3 = T.text; b.Text = keyName(keys[id]); b.Parent = parent
	stroke(b, T.edge); corner(b, 9)
	keyBoxes[id] = b
	con(b.MouseButton1Click, function() listening = id; b.Text = "..."; b.TextColor3 = T.accent end)
	return b
end

local refresh = {}
-- auto farm OFF stops all automation that fights or moves: auto quest farms its kill steps through the same
-- engage, kill aura keeps killing nearby mobs and auto pickup walks to their drops
H.haltMovers = function()
	state.farm = false state.autoQuest = false state.chests = false state.resources = false state.aura = false state.loot = false
	for _, k in ipairs({ "farm", "autoQuest", "chests", "resources", "aura", "loot" }) do if refresh[k] then refresh[k]() end end
	H.glue = nil H.target = nil stopTravel() save()
	status("farm stopped")
end
local function toggle(S, label, key, onChange, bindId)
	onChange = onChange or function() end
	local row = Instance.new("TextButton")
	row.AutoButtonColor = false; row.BackgroundTransparency = 1; row.Text = ""; row.Size = UDim2.new(1, 0, 0, 18)
	row.LayoutOrder = nextOrder(S); row.Parent = S.f
	local dot = Instance.new("Frame")
	dot.Size = UDim2.fromOffset(17, 17); dot.BorderSizePixel = 0; dot.Parent = row
	corner(dot, 4); stroke(dot)
	local l = txt(row, label, UDim2.new(1, bindId and -112 or -28, 1, 0)); l.Position = UDim2.fromOffset(27, 0)
	l.TextTruncate = Enum.TextTruncate.AtEnd
	if bindId then keybox(row, bindId) end
	local function paint()
		local on = state[key]
		dot.BackgroundColor3 = on and T.accent or T.off
		l.TextColor3 = on and T.text or T.dim
	end
	paint()
	if state[key] then task.spawn(onChange, true) end
	con(row.MouseButton1Click, function() state[key] = not state[key]; paint(); save(); task.spawn(onChange, state[key]) end)
	refresh[key] = paint
	return paint
end
local function keyRow(S, label, id)
	local row = Instance.new("Frame"); row.BackgroundTransparency = 1; row.Size = UDim2.new(1, 0, 0, 16)
	row.LayoutOrder = nextOrder(S); row.Parent = S.f
	txt(row, label, UDim2.new(1, -84, 1, 0))
	keybox(row, id)
end
-- slider bound to state[key]; step rounds, fmt formats the value text
local function slider(S, label, key, minV, maxV, step, fmt)
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
	local fill = Instance.new("Frame"); fill.BackgroundColor3 = T.accent; fill.BorderSizePixel = 0; fill.Parent = bar
	corner(fill, 3)
	local function set(v)
		v = math.clamp(math.floor(v / step + 0.5) * step, minV, maxV)
		state[key] = v
		fill.Size = UDim2.new((v - minV) / (maxV - minV), 0, 1, 0)
		val.Text = fmt and fmt(v) or tostring(v)
	end
	set(state[key])
	local sliding = false
	local function fromX(x) set(minV + (x - bar.AbsolutePosition.X) / bar.AbsoluteSize.X * (maxV - minV)) save() end
	con(hit.InputBegan, function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then sliding = true; fromX(i.Position.X) end end)
	con(UIS.InputChanged, function(i) if sliding and i.UserInputType == Enum.UserInputType.MouseMovement then fromX(i.Position.X) end end)
	con(UIS.InputEnded, function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then sliding = false end end)
end
-- dropdown; key = state index key (optional), returns setOptions(newOpts)
local function dropdown(S, label, opts, key, onSel)
	txt(S.f, label, UDim2.new(1, 0, 0, 14)).LayoutOrder = nextOrder(S)
	local idx = key and state[key] or 1
	local box = Instance.new("TextButton")
	box.Size = UDim2.new(1, 0, 0, 28); box.BackgroundColor3 = T.panel2; box.BorderSizePixel = 0; box.AutoButtonColor = false
	box.Text = ""; box.LayoutOrder = nextOrder(S); box.Parent = S.f
	stroke(box); corner(box, 6)
	local cur = txt(box, opts[idx] or "-", UDim2.new(1, -34, 1, 0)); cur.Position = UDim2.fromOffset(10, 0)
	cur.TextTruncate = Enum.TextTruncate.AtEnd
	local arr = txt(box, "▼", UDim2.new(0, 14, 1, 0), T.dim); arr.Position = UDim2.new(1, -22, 0, 0); arr.TextSize = 10
	local list = Instance.new("ScrollingFrame")
	list.Size = UDim2.new(1, 0, 0, 0); list.BackgroundColor3 = T.bg; list.BorderSizePixel = 0; list.Visible = false
	list.ScrollBarThickness = 2; list.ScrollBarImageColor3 = T.accent; list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new(); list.LayoutOrder = nextOrder(S); list.Parent = S.f
	stroke(list); corner(list, 6)
	Instance.new("UIListLayout", list).SortOrder = Enum.SortOrder.LayoutOrder
	local items = {}
	local function paint() for i, b in ipairs(items) do b.TextColor3 = (i == idx) and T.accent or T.dim end end
	local function build(o)
		opts = o
		for _, b in ipairs(items) do b:Destroy() end
		items = {}
		for i, name in ipairs(opts) do
			local b = Instance.new("TextButton")
			b.Size = UDim2.new(1, 0, 0, 22); b.BackgroundTransparency = 1; b.Font = T.font; b.TextSize = 12
			b.Text = "   " .. name; b.TextXAlignment = Enum.TextXAlignment.Left; b.LayoutOrder = i; b.Parent = list
			items[i] = b
			con(b.MouseButton1Click, function()
				idx = i; cur.Text = name; list.Visible = false; arr.Text = "▼"; paint()
				if key then state[key] = i; save() end
				if onSel then task.spawn(onSel, i, name) end
			end)
		end
		list.Size = UDim2.new(1, 0, 0, math.min(#opts, 8) * 22)
		if not opts[idx] then idx = 1 end
		cur.Text = opts[idx] or "-"
		paint()
	end
	build(opts)
	con(box.MouseButton1Click, function() list.Visible = not list.Visible; arr.Text = list.Visible and "▲" or "▼" end)
	return build, function() return idx, opts[idx] end
end
local function button(S, label, fn)
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(1, 0, 0, 26); b.BackgroundColor3 = T.panel2; b.BorderSizePixel = 0; b.AutoButtonColor = false
	b.Font = T.font; b.TextSize = 12; b.TextColor3 = T.text; b.Text = label; b.LayoutOrder = nextOrder(S); b.Parent = S.f
	stroke(b); corner(b, 6)
	con(b.MouseButton1Click, function() task.spawn(function() local ok, e = pcall(fn) if not ok then log("error: " .. tostring(e)) end end) end)
	con(b.MouseEnter, function() b.TextColor3 = T.accent end)
	con(b.MouseLeave, function() b.TextColor3 = T.text end)
	return b
end
local function textbox(S, label, key)
	txt(S.f, label, UDim2.new(1, 0, 0, 14)).LayoutOrder = nextOrder(S)
	local b = Instance.new("TextBox")
	b.Size = UDim2.new(1, 0, 0, 26); b.BackgroundColor3 = T.panel2; b.BorderSizePixel = 0; b.ClearTextOnFocus = false
	b.Font = T.font; b.TextSize = 12; b.TextColor3 = T.text; b.PlaceholderColor3 = T.dim; b.PlaceholderText = "e.g. Shroom, Elder Shroom"
	b.Text = state[key]; b.TextXAlignment = Enum.TextXAlignment.Left; b.LayoutOrder = nextOrder(S); b.Parent = S.f
	stroke(b); corner(b, 6)
	Instance.new("UIPadding", b).PaddingLeft = UDim.new(0, 8)
	con(b.FocusLost, function() state[key] = b.Text save() end)
end
local function info(S, text, color)
	local l = txt(S.f, text, UDim2.new(1, 0, 0, 0), color or T.dim)
	l.AutomaticSize = Enum.AutomaticSize.Y; l.TextWrapped = true; l.RichText = true; l.TextSize = 12
	l.LayoutOrder = nextOrder(S)
	return l
end

-- ================= PAGES =================
local farmL, farmR = tab("Farm")
local qL, qR = tab("Quests")
local lootL, lootR = tab("Loot")
local plL, plR = tab("Player")
local visL, visR = tab("Visuals")
local infL, infR = tab("Info")
local setL, setR = tab("Settings")

-- Farm
local S_farm = section(farmL, "Auto Farm")
toggle(S_farm, "Auto farm", "farm", function(v) if not v then H.haltMovers() end end, "farm")
dropdown(S_farm, "Target", FARM_MODES, "farmMode")
textbox(S_farm, "Name filter (comma separated)", "farmFilter")
slider(S_farm, "Max level above mine", "farmLvlOver", 0, 60, 1, function(v) return "+" .. v end)
slider(S_farm, "Search radius", "farmRadius", 50, 3000, 50, function(v) return v .. " st" end)
slider(S_farm, "Distance to target", "farmDist", 0, 10, 0.5, function(v) return v .. " st" end)
slider(S_farm, "Height offset", "farmHeight", -4, 12, 0.5, function(v) return v .. " st" end)
info(S_farm, "Flies to the mob at glide speed, sticks to it and swings until it dies. Mobs that take no damage for 6 s are skipped for a minute.")

local S_aura = section(farmR, "Kill Aura")
toggle(S_aura, "Kill aura (melee weapons)", "aura")
slider(S_aura, "Range", "auraRange", 4, 20, 1, function(v) return v .. " st" end)
slider(S_aura, "Max targets / swing", "auraMax", 1, 12, 1)
slider(S_aura, "Swing delay", "swingDelay", 0.05, 1, 0.01, function(v) return ("%.2fs"):format(v) end)
slider(S_aura, "Hits per swing", "hitsPerSwing", 1, 4, 1, function(v) return v .. "x" end)
info(S_aura, "Server checks ~17 studs (weapon reach). 0.1 s swings and up to ~4 hits/swing were accepted in testing. Bows and staffs shoot projectiles, so the aura won't work with them.")

local S_surv = section(farmR, "Survival")
toggle(S_surv, "Auto heal (potions, then food)", "autoHeal")
slider(S_surv, "Heal below", "healAt", 5, 95, 5, function(v) return v .. "%" end)
toggle(S_surv, "Auto respawn", "autoRespawn")

-- Quests
local S_q = section(qL, "Auto Quest")
toggle(S_q, "Auto quest", "autoQuest", function(v) if not v then H.glue = nil stopTravel() end end)
toggle(S_q, "Accept new quests", "questAccept")
toggle(S_q, "Redo repeatable quests", "questRepeat")
toggle(S_q, "Move to the next zone when done", "questTravel")
toggle(S_q, "Grind mobs while nothing to do", "questGrind")
button(S_q, "Show next zone exit", function() local p, n = H.zoneExit() log(p and ("next exit: " .. tostring(n) .. " (" .. math.floor((p.Position - hb().Position).Magnitude) .. " studs)") or "no zone exit open for your level") end)
info(S_q, "Turns in finished quests, works kill and item quests (drops from mobs, resource nodes) and accepts new ones from NPCs in this zone. Story steps (find/talk/special spots) are left to you and show as (manual). Uses Farm's 'Max level above mine' for mob levels.")
button(S_q, "Turn in / accept once now", function()
	local a = questAction()
	if a and (a.kind == "start" or a.kind == "submit") then doQuest(a) else log("quest: nothing to accept or turn in here") end
end)
local S_ql = section(qR, "Active quests")
local questLbl = info(S_ql, "", T.text)
questLbl.TextSize = 11

-- Loot
local S_pick = section(lootL, "Pickup")
toggle(S_pick, "Auto pickup drops", "loot")
slider(S_pick, "Pickup radius while busy", "lootRange", 20, 600, 10, function(v) return v .. " st" end)
info(S_pick, "When nothing else runs it only grabs drops within 25 studs.")

local S_sell = section(lootR, "Auto Sell")
toggle(S_sell, "Auto sell when inventory is full", "autoSell")
slider(S_sell, "Sell at free slots left", "sellFree", 0, 10, 1, function(v) return v .. " free" end)
toggle(S_sell, "Also sell unequipped gear (always when the gear bag is full)", "sellGear")
toggle(S_sell, "Only Common rarity (keep Rare+)", "sellCommonOnly")
button(S_sell, "Sell now", function() H.sellNow() end)
info(S_sell, "Sells drops/materials (and gear if enabled) to the nearest merchant by remote, no walking. Arrows and items an open quest still needs are kept.")
local S_chest = section(lootL, "Chests")
toggle(S_chest, "Auto open chests (whole map)", "chests")
button(S_chest, "Open nearest chest now", function() local c = nextChest() if c then openChest(c) end end)
info(S_chest, "Skips chests 10+ levels above you. Opened chests are retried after 30 min, failed ones after 15.")

local S_res = section(lootR, "Resources")
toggle(S_res, "Break resources", "resources")
slider(S_res, "Radius", "resRange", 50, 1500, 25, function(v) return v .. " st" end)
toggle(S_res, "Crates", "resCrate")
toggle(S_res, "Pots", "resPot")
toggle(S_res, "Mushrooms", "resMushroom")
toggle(S_res, "Cabbages", "resCabbage")
toggle(S_res, "Trees (may need an axe)", "resTree")

-- Player
local S_move = section(plL, "Movement")
slider(S_move, "Glide speed", "speed", 20, 150, 5, function(v) return v .. " st/s" end)
toggle(S_move, "Underground", "underground", function(v) if not v then H.ugSurface() end end)
slider(S_move, "Underground depth", "ugDepth", 3, 30, 1, function(v) return v .. " st" end)
info(S_move, "Only while gliding and auto farming: travel and the farm spot run below the surface (noclip), back up on the ground when the hub idles. Pickups surface to 6 studs. Melee reach ~15, keep the depth around 8-10.")
toggle(S_move, "No fall damage", "noFall")
toggle(S_move, "Instant teleport (kick risk)", "instantTp")
toggle(S_move, "Ctrl+Click teleport", "clickTp")
button(S_move, "Stop movement / farm target", function() stopTravel() H.glue = nil end)

local S_tp = section(plL, "Teleports")
local npcList = {}
local function scanNpcs()
	npcList = {}
	for _, m in ipairs(workspace:GetChildren()) do
		if m:IsA("Model") and m ~= lp.Character and (m:FindFirstChildOfClass("Humanoid") or m:FindFirstChild("HumanoidRootPart")) then
			npcList[#npcList + 1] = m.Name
		end
	end
	table.sort(npcList)
	return #npcList > 0 and npcList or { "-" }
end
local setNpcs, getNpc = dropdown(S_tp, "NPC", scanNpcs())
button(S_tp, "Go to NPC", function()
	local _, name = getNpc()
	local m = name and workspace:FindFirstChild(name)
	if m then status("travel: " .. name) travel(m:GetPivot().Position + Vector3.new(0, 2, 0), 5, 60) end
end)
button(S_tp, "Rescan NPCs", function() setNpcs(scanNpcs()) end)
local chestNames = {}
local function scanChests()
	chestNames = {}
	for _, c in ipairs(chestList()) do chestNames[#chestNames + 1] = c.Name end
	table.sort(chestNames)
	return #chestNames > 0 and chestNames or { "-" }
end
local setChests, getChest = dropdown(S_tp, "Chest", scanChests())
button(S_tp, "Go to chest", function()
	local _, name = getChest()
	for _, c in ipairs(chestList()) do
		if c.Name == name then travel(c.PrimaryPart.Position + c.PrimaryPart.CFrame.LookVector * 4 + Vector3.new(0, 2, 0), 3, 60) break end
	end
end)

local S_eq = section(plR, "Auto Equip")
toggle(S_eq, "Auto equip best gear", "autoEquip")
dropdown(S_eq, "Best by", EQUIP_MODES, "equipMode")
toggle(S_eq, "Weapon: melee only (aura/farm need melee)", "equipMelee")
button(S_eq, "Equip best now", function() H.equipForce = true local ok, e = pcall(H.equipBest) H.equipForce = nil if not ok then log("equip error: " .. tostring(e)) end end)
info(S_eq, "Tries each item you can wear and keeps whatever gives the highest real stat (damage, max HP or defense, read from the game after equipping). Identical copies are tested once; losers are skipped until you level up.")
local S_stats = section(plR, "Stats")
toggle(S_stats, "Auto spend stat points", "autoStats")
dropdown(S_stats, "Stat", { "STR (melee)", "DEX (bow/dagger)", "INT (magic)", "VIT (health)" }, "statPick")
local S_rew = section(plR, "Rewards")
button(S_rew, "Claim daily / free rewards", claimAll)
info(S_rew, "Calls the daily reward, daily ethyr, gifts, welcome, stored gold and calendar remotes once. Results go to the log (Info tab).")
local S_misc = section(plR, "Misc")
toggle(S_misc, "Anti AFK", "antiAfk")
button(S_misc, "Respawn now", function() pcall(function() RF.playerRequest_respawnMyCharacter:InvokeServer() end) end)

-- Visuals
local S_esp = section(visL, "ESP")
toggle(S_esp, "Monsters", "espMobs")
toggle(S_esp, "Bosses (always, red)", "espBoss")
toggle(S_esp, "Chests", "espChests")
toggle(S_esp, "Drops", "espItems")
toggle(S_esp, "Players", "espPlayers")
slider(S_esp, "ESP distance", "espDist", 100, 3000, 50, function(v) return v .. " st" end)
local S_world = section(visR, "World")
toggle(S_world, "Fullbright", "fullbright", function(v) if v then applyFB() else restoreFB() end end)

-- Info
local S_info = section(infL, "Session")
local infoLbl = info(S_info, "", T.text)
infoLbl.Font = Enum.Font.Code
local S_log = section(infR, "Log")
local logLbl = info(S_log, "", T.dim)
logLbl.Font = Enum.Font.Code; logLbl.TextSize = 11
button(S_log, "Copy log", function() if setclipboard then setclipboard(table.concat(H.log, "\n")) end end)

-- Settings
local S_keys = section(setL, "Keybinds")
keyRow(S_keys, "Menu", "menu")
keyRow(S_keys, "Toggle auto farm", "farm")
keyRow(S_keys, "Stop everything", "stop")
local S_set = section(setR, "Hub")
button(S_set, "Unload hub", function() H.kill() end)
info(S_set, "Settings save automatically to vesteria_hub_settings.json in the executor workspace.")

selectTab("Farm")

-- ================= INPUT =================
local function stopAll()
	state.farm = false state.chests = false state.resources = false state.aura = false state.autoQuest = false state.loot = false
	for _, k in ipairs({ "farm", "chests", "resources", "aura", "autoQuest", "loot" }) do if refresh[k] then refresh[k]() end end
	H.glue = nil stopTravel() save()
	status("stopped")
end
con(UIS.InputBegan, function(i, gp)
	if listening then
		if i.UserInputType == Enum.UserInputType.Keyboard or i.UserInputType.Name:find("MouseButton") then
			local id = listening
			listening = nil
			if i.KeyCode ~= Enum.KeyCode.Escape then
				keys[id] = i.UserInputType == Enum.UserInputType.Keyboard and i.KeyCode or i.UserInputType
				state[KEY_SAVE[id]] = keys[id].Name save()
			end
			keyBoxes[id].Text = keyName(keys[id]); keyBoxes[id].TextColor3 = T.text
		end
		return
	end
	if keyMatch(i, keys.menu) then main.Visible = not main.Visible state.guiVisible = main.Visible save() return end
	if gp then return end
	if keyMatch(i, keys.farm) then
		state.farm = not state.farm refresh.farm() save()
		if not state.farm then H.haltMovers() end
	elseif keyMatch(i, keys.stop) then
		stopAll()
	elseif state.clickTp and i.UserInputType == Enum.UserInputType.MouseButton1 and UIS:IsKeyDown(Enum.KeyCode.LeftControl) then
		local m = lp:GetMouse()
		if m.Hit then task.spawn(travel, m.Hit.Position + Vector3.new(0, 3, 0), 2, 60) end
	end
end)

-- ================= ESP =================
local espCache = {}
local function espTag(obj, adornee, text, color)
	local e = espCache[obj]
	if not e then
		local bb = Instance.new("BillboardGui")
		bb.Size = UDim2.fromOffset(200, 30); bb.AlwaysOnTop = true; bb.StudsOffset = Vector3.new(0, 3, 0)
		bb.LightInfluence = 0; bb.Parent = espFolder
		local l = Instance.new("TextLabel", bb)
		l.Size = UDim2.fromScale(1, 1); l.BackgroundTransparency = 1; l.Font = T.bold; l.TextSize = 12
		l.TextStrokeTransparency = 0.4
		e = { bb = bb, l = l }
		espCache[obj] = e
	end
	e.bb.Adornee = adornee; e.l.Text = text; e.l.TextColor3 = color; e.seen = os.clock()
end
loop("esp", function()
	task.wait(0.4)
	local h = hb()
	if not h then return end
	local pos = h.Position
	local function inRange(p) return (p - pos).Magnitude <= state.espDist end
	if state.espMobs or state.espBoss then
		for _, m in ipairs(ENT:GetChildren()) do
			if isMob(m) and inRange(m.Position) then
				local boss = isBoss(m)
				if state.espMobs or boss then
					espTag(m, m, ("%s [%d] %d/%d"):format(m.Name, m.level.Value, math.floor(m.health.Value), math.floor(m.maxHealth.Value)),
						boss and Color3.fromRGB(255, 70, 70) or Color3.fromRGB(235, 235, 240))
				end
			end
		end
	end
	if state.espChests then
		local lvl = myLevel()
		for _, c in ipairs(chestList()) do
			if inRange(c.PrimaryPart.Position) then
				local cl = c:FindFirstChild("chestLevel")
				local cd = chestCd[c] and chestCd[c] > os.clock()
				espTag(c, c.PrimaryPart, ("%s%s"):format(c.Name, cl and (" [" .. cl.Value .. "]") or ""),
					cd and T.dim or ((cl and lvl < cl.Value - 10) and Color3.fromRGB(255, 120, 60) or Color3.fromRGB(255, 210, 60)))
			end
		end
	end
	if state.espItems then
		for _, it in ipairs(ITEMS:GetChildren()) do
			if it:IsA("BasePart") and inRange(it.Position) then
				espTag(it, it, itemLabel(it), pickable(it) and Color3.fromRGB(120, 230, 140) or T.dim)
			end
		end
	end
	if state.espPlayers then
		for _, p in ipairs(Players:GetPlayers()) do
			local c = p ~= lp and p.Character
			local r = c and c.PrimaryPart
			if r and inRange(r.Position) then
				local lv = p:FindFirstChild("level")
				espTag(p, r, ("%s%s"):format(p.Name, lv and (" [" .. tostring(lv.Value) .. "]") or ""), Color3.fromRGB(110, 170, 255))
			end
		end
	end
	local now = os.clock()
	for o, e in pairs(espCache) do
		if now - (e.seen or 0) > 1 or (typeof(o) == "Instance" and not o.Parent) then e.bb:Destroy() espCache[o] = nil end
	end
end)

-- ================= INFO =================
local startGold, startExp, startLvl
loop("info", function()
	task.wait(0.5)
	statusTxt.Text = H.status or ""
	if main.Visible and pages.Quests.Visible then
		if not state.autoQuest then pcall(questAction) end -- refresh the list even while off
		questLbl.Text = #H.questInfo > 0 and table.concat(H.questInfo, string.char(10)) or "no quests in progress"
	end
	if not (main.Visible and pages.Info.Visible) then return end
	local d = pdata()
	if not d then return end
	startGold = startGold or d.gold
	startExp, startLvl = startExp or d.exp, startLvl or d.level
	local hrs = math.max((os.clock() - H.stats.start) / 3600, 1 / 3600)
	local h = hb()
	local L = {}
	local function add(f, ...) L[#L + 1] = f:format(...) end
	add("Level %d (%s)  exp %d", d.level or 0, tostring(d.class), d.exp or 0)
	add("Gold %d  (+%d, %.0f/h)", d.gold or 0, (d.gold or 0) - startGold, ((d.gold or 0) - startGold) / hrs)
	if d.level == startLvl then add("Exp +%d (%.0f/h)", (d.exp or 0) - startExp, ((d.exp or 0) - startExp) / hrs)
	else add("Levels gained: %d", d.level - startLvl) end
	add("HP %s", h and h:FindFirstChild("health") and ("%d/%d"):format(h.health.Value, h.maxHealth.Value) or "-")
	add("Kills %d (%.0f/h)  chests %d", H.stats.kills, H.stats.kills / hrs, H.stats.chests)
	add("Picked %d  resources %d  quests %d", H.stats.picks, H.stats.res, H.stats.quests or 0)
	add("Weapon type: %s", weaponType())
	add("Target: %s", H.target and H.target.Parent and H.target.Name or "-")
	add("Session %.0f min", (os.clock() - H.stats.start) / 60)
	infoLbl.Text = table.concat(L, "\n")
	logLbl.Text = table.concat(H.log, "\n", math.max(1, #H.log - 18))
end)

-- ================= KILL =================
function H.kill()
	H.alive = false
	H.glue = nil
	H.tok += 1
	for _, c in ipairs(H.conns) do pcall(function() c:Disconnect() end) end
	for _, t in pairs(H.threads) do if t ~= coroutine.running() then pcall(task.cancel, t) end end
	if state.fullbright then restoreFB() end
	local h = hb()
	if h then h.AssemblyLinearVelocity = Vector3.zero end
	pcall(function() gui:Destroy() end)
	pcall(writefile, SAVE_FILE, HttpService:JSONEncode(state))
	if _G.__VES_HUB == H then _G.__VES_HUB = nil end
end

save() -- persist the consumed resume flag + visited places
log("loaded (" .. tostring(game.PlaceId) .. ")")
status("loaded")
return H
