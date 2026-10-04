--[[ Clean all the Leaves — Leaf Farm
     Runs in the lobby AND in the run place (same universe 10539411000).

     RUN PLACE
       Vent Eat      buys every vent (1-3 cash) and eats all leaves within ~56 studs of each
                     vent from right next to it. VentEat has no server rate limit and pays
                     instantly - this clears most of a map in seconds.
       Auto Farm     the rest: teleports to the densest patch of visible leaves and grabs them,
                     paced to the server budget (~400 burst, ~200/s; extra grabs are dropped),
                     sells at the best unlocked dumpster. Locked zones are skipped
                     (their leaves stay Transparency 1 until the zone unlocks).
       Hand Grasp    buys Hand Grasp (6 leaves per grab call instead of 1).
       Auto Bag      buys bag upgrades as soon as cash allows (25 -> 75 -> 500 -> 1000).
       Auto Perk     picks run perks by priority (Safety Valve auto-sell, Roomy Bag, Hidden Gems...).
       Duck Part     picks up the hidden duck bot part of this map once.
       Auto Finish   when every zone is done, takes the exit (House: vent hole, Mansion: hatch)
                     -> round cleared, back to lobby.
     LOBBY
       Auto Claim    daily reward, free gift, group reward (if in group).
       Auto Upgrade  spends diamonds on lobby upgrades (Gems > Cash > Bag > rest).
       Auto Start    walks onto a free pad and starts a SOLO run. Mode Progress: new maps first,
                     then raises difficulty; once all are Impossible, repeats the best measured
                     diamonds/min. Mode Fixed: the chosen map/difficulty.
     AFK LOOP: autoexec/leaf_farm.lua reloads this after every teleport.

     Settings persist in RaffirScripts/leaf_farm.json, so after the teleport into a run the
     farm continues on its own (re-execute or let the launcher load it).
     Toggle GUI: RightShift.   Kill: getgenv().__LEAF_FARM.kill()
]]

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local lp = Players.LocalPlayer

local g = getgenv and getgenv() or _G
if g.__LEAF_FARM and g.__LEAF_FARM.kill then pcall(g.__LEAF_FARM.kill) end
local ctl = { alive = true }
g.__LEAF_FARM = ctl
local function alive() return ctl.alive and g.__LEAF_FARM == ctl end

local Remotes = RS:WaitForChild("Remotes", 30)
local IS_RUN = Remotes:FindFirstChild("CollectLeaf") ~= nil or workspace:FindFirstChild("Leaves") ~= nil

-- ===== settings =====
local CFG_FILE = "RaffirScripts/leaf_farm.json"
local S = {
	farm = true, vents = true, bag = true, hand = true, duck = true, perk = true, finish = true, collect = true, bot = true,
	classroll = true, clan = true, antiafk = true,
	claim = true, upgrade = true, autostart = false,
	mode = "progress", map = "House", diff = 1,
	tpWait = 0.3, grabRange = 26,
}
pcall(function()
	if isfile and isfile(CFG_FILE) then
		local t = HttpService:JSONDecode(readfile(CFG_FILE))
		for k, v in pairs(t) do if S[k] ~= nil and type(v) == type(S[k]) then S[k] = v end end
	end
end)
local function save()
	pcall(function()
		if makefolder and not isfolder("RaffirScripts") then makefolder("RaffirScripts") end
		writefile(CFG_FILE, HttpService:JSONEncode(S))
	end)
end

local stat = { state = "idle", grabbed = 0, sold = 0, cash = 0, trips = 0, note = "" }

local function hrp()
	local c = lp.Character
	return c and c:FindFirstChild("HumanoidRootPart")
end
local function tp(pos)
	local h = hrp()
	if not h then return false end
	h.AssemblyLinearVelocity = Vector3.zero
	h.CFrame = CFrame.new(pos)
	return true
end
local function A(k) return lp:GetAttribute(k) end

-- ===== session stats (survive teleports; a new session starts after 30 min without a run) =====
local SESSION_FILE = "RaffirScripts/leaf_farm_session.json"
local function loadSession()
	local ok, t = pcall(function() return HttpService:JSONDecode(readfile(SESSION_FILE)) end)
	t = ok and type(t) == "table" and t or {}
	if not t.start or os.time() - (t.last or 0) > 1800 then t = { start = os.time(), last = os.time(), runs = 0, gained = 0 } end
	return t
end
local function saveSession(t) pcall(function() writefile(SESSION_FILE, HttpService:JSONEncode(t)) end) end
local function sessionText()
	local t = loadSession()
	local hrs = math.max((os.time() - t.start) / 3600, 1 / 60)
	return ("session: %d runs  +%d 💎  (%.0f/h)"):format(t.runs or 0, t.gained or 0, (t.gained or 0) / hrs)
end

-- ===== anti-AFK + auto-rejoin (long AFK sessions) =====
if S.antiafk then
	ctl.cons = ctl.cons or {}
	table.insert(ctl.cons, lp.Idled:Connect(function()
		pcall(function()
			local vu = game:GetService("VirtualUser")
			vu:CaptureController()
			vu:ClickButton2(Vector2.new())
		end)
	end))
	pcall(function()
		local GuiService = game:GetService("GuiService")
		table.insert(ctl.cons, GuiService.ErrorMessageChanged:Connect(function(msg)
			if not alive() or type(msg) ~= "string" or msg == "" then return end
			stat.note = "disconnected - rejoining"
			task.wait(3)
			pcall(function() game:GetService("TeleportService"):Teleport(92637789841354, lp) end)
		end))
	end)
end

-- ===================================================================
-- RUN PLACE
-- ===================================================================
local function runPlace()
	local LeafSim = require(lp.PlayerScripts:WaitForChild("LeafSim", 30))
	local Leaves = workspace:WaitForChild("Leaves", 30)
	local Map = workspace:WaitForChild("Map", 30)
	local EmptyBackpack = Remotes:WaitForChild("EmptyBackpack")
	local BuyBagUpgrade = Remotes:WaitForChild("BuyBagUpgrade")
	local BagConfig = require(RS:WaitForChild("BagConfig"))

	local function zoneDone(name)
		if name == nil or name == "None" then return true end
		local z = Map.Leave_Locations:FindFirstChild(name)
		-- a zone that doesn't exist on this map (Barn's dumpster says "Backyard") doesn't lock anything
		return z == nil or z:GetAttribute("Completed") == true
	end

	local function bestDumpster()
		local best, bp = nil, -1
		for _, d in ipairs(Map.Dumpsters:GetChildren()) do
			if d:IsA("Model") and zoneDone(d:GetAttribute("ZoneRequired")) then
				local p = d:GetAttribute("PricePerLeaf") or 0
				if p > bp then best, bp = d, p end
			end
		end
		if not best then
			for _, d in ipairs(Map.Dumpsters:GetChildren()) do
				if d:IsA("Model") then
					local p = d:GetAttribute("PricePerLeaf") or 0
					if not best or p < bp then best, bp = d, p end
				end
			end
		end
		return best
	end

	-- leaf -> zone name via LeafSim internals (canUseLeaf upvalues: part->id map, ..., id->zone map)
	-- (resolved lazily: the tables are empty until the leaves have loaded)
	local partId, idZone
	local function resolveIds()
		if partId then return partId end
		pcall(function()
			for _, v in pairs(debug.getupvalues(LeafSim.canUseLeaf)) do
				if type(v) == "table" then
					local k, val = next(v)
					if typeof(k) == "Instance" and type(val) == "number" then partId = v
					elseif type(k) == "number" and type(val) == "string" then idZone = v end
				end
			end
		end)
		return partId
	end
	local function zoneOf(l)
		local id = partId and partId[l]
		return id and idZone and idZone[id] or "?"
	end

	local function usable(l)
		return l:IsA("BasePart") and l.Transparency < 1 and LeafSim.canUseLeaf(l)
	end

	-- regions that rejected a grab (locked zone the client still shows) -> skip for a while
	local banned = {}
	local function isBanned(p)
		local now = os.clock()
		for i = #banned, 1, -1 do
			local b = banned[i]
			if now > b.t then table.remove(banned, i)
			elseif (b.p - p).Magnitude < 30 then return true end
		end
		return false
	end

	-- densest 24-stud cell of usable leaves
	local CELL = 24
	local function pickPatch(need)
		local cells, best, bn = {}, nil, 0
		for _, l in ipairs(Leaves:GetChildren()) do
			if usable(l) then
				local p = l.Position
				local k = math.floor(p.X / CELL) .. "," .. math.floor(p.Z / CELL)
				local c = cells[k]
				if not c then c = { n = 0, sum = Vector3.zero, y = p.Y }; cells[k] = c end
				c.n = c.n + 1
				c.sum = c.sum + p
			end
		end
		for _, c in pairs(cells) do
			local center = c.sum / c.n
			if not isBanned(center) then
				-- full bag is enough; beyond that prefer the denser cell
				local score = math.min(c.n, need * 2)
				if score > bn then best, bn = c, score end
			end
		end
		if not best then return nil end
		local center = best.sum / best.n
		-- stand on the leaf closest to the cell center
		local stand, sd = nil, math.huge
		for _, l in ipairs(Leaves:GetChildren()) do
			if usable(l) then
				local d = (l.Position - center).Magnitude
				if d < sd then stand, sd = l.Position, d end
			end
		end
		return stand or center
	end

	local function nearLeaves(pos, n)
		local list = {}
		for _, l in ipairs(Leaves:GetChildren()) do
			if usable(l) then
				local d = (l.Position - pos).Magnitude
				if d <= S.grabRange then list[#list + 1] = { l, d } end
			end
		end
		table.sort(list, function(a, b) return a[2] < b[2] end)
		local out = {}
		for i = 1, math.min(n, #list) do out[i] = list[i][1] end
		return out
	end

	local function capLeft()
		if A("InfiniteBag") then return 300 end
		return math.max(0, (A("LeafCapacity") or 25) - (A("Leaves") or 0))
	end

	local function sell()
		local d = bestDumpster()
		if not d then return end
		local cf, size = d:GetBoundingBox()
		stat.state = "selling"
		local before = A("Cash") or 0
		for attempt = 1, 3 do
			tp(cf.Position + Vector3.new(0, 0, size.Z / 2 + 3.5))
			task.wait(S.tpWait + 0.15 * (attempt - 1))
			EmptyBackpack:FireServer()
			local t = os.clock()
			while os.clock() - t < 1 and (A("Leaves") or 0) > 0 do task.wait(0.05) end
			if (A("Leaves") or 0) == 0 then break end
		end
		stat.trips = stat.trips + 1
		stat.cash = (A("Cash") or 0) - before + stat.cash
	end

	local function buyBag()
		if A("InfiniteBag") then return end
		local lvl = A("BagLevel") or 0
		local price = BagConfig.prices[lvl + 1]
		if price and (A("Cash") or 0) >= price then
			local item = Map.ToolsToBuy:FindFirstChild("BagUpgrade")
			if item then BuyBagUpgrade:FireServer(item) end
		end
	end

	-- duck bot parts: BaseParts named DuckBotPart* anywhere in the map; the part is
	-- destroyed locally once the server accepts it. Retry a few times (server checks range).
	-- Hand Grasp = leaves per grab call (cheap, cuts remote spam 6x)
	local BuyUpgrade = Remotes:FindFirstChild("BuyUpgrade")
	local handNext = 0
	local function buyHand()
		if not BuyUpgrade or os.clock() < handNext then return end
		handNext = os.clock() + 3
		local ok, UC = pcall(require, RS:WaitForChild("UpgradeConfig"))
		local g = ok and UC.tools and UC.tools.Hand and UC.tools.Hand.upgrades.Grasp
		if not g then return end
		local lvl = A("Upg_Hand_Grasp") or 0
		local price = g.prices and g.prices[lvl + 1]
		if price and (A("Cash") or 0) >= price then BuyUpgrade:FireServer("Hand", "Grasp") end
	end

	local duckTries, duckNext = 0, 0
	local duckOk = false
	local NotifyEv = Remotes:FindFirstChild("Notify")
	if NotifyEv then
		ctl.cons = ctl.cons or {}
		table.insert(ctl.cons, NotifyEv.OnClientEvent:Connect(function(msg)
			if type(msg) == "string" and msg:find("Duck part") then duckOk = true end
		end))
	end
	local function grabDuck()
		if duckTries >= 6 or os.clock() < duckNext then return end
		local part
		for _, x in ipairs(Map:GetDescendants()) do
			if x:IsA("BasePart") and x.Name:sub(1, 11) == "DuckBotPart" and x.Transparency < 1 then part = x break end
		end
		if not part then duckTries = 6 return end
		duckTries = duckTries + 1
		duckNext = os.clock() + 15
		local remote = Remotes:FindFirstChild("CollectDuckBotPart")
		local h = hrp(); if not (h and remote) then return end
		local back = h.CFrame
		tp(part.Position + Vector3.new(0, 3, 0)); task.wait(S.tpWait + 0.3)
		remote:FireServer(part)
		local t = os.clock()
		while os.clock() - t < 1.5 and part.Parent and not duckOk do task.wait(0.1) end
		if duckOk or not part.Parent then stat.note = "duck part collected" duckTries = 6 end
		h.CFrame = back
	end

	-- perk offers block all leaf input until one is chosen -> pick by priority
	local PERK_PRIO = { "safety_valve", "roomy_bag", "gem_finder", "deep_pockets", "third_time", "auto_sell",
		"lightning_hands", "chain_reaction", "market_savvy", "extra_grasp", "second_wind", "leaf_aura",
		"fleet_feet", "rainbow_steps", "gale_force", "wide_sweep" }
	local PerkRemotes = RS:FindFirstChild("PerkRemotes")
	local lastOffer
	local function pickPerk()
		if not (PerkRemotes and A("PerkOfferPending")) then return end
		local ok, st = pcall(function() return PerkRemotes.GetState:InvokeServer() end)
		local offer = ok and type(st) == "table" and st.offer
		if type(offer) ~= "table" or offer.id == nil or type(offer.choices) ~= "table" then return end
		if lastOffer == offer.id then return end
		local pick
		for _, want in ipairs(PERK_PRIO) do
			for _, c in ipairs(offer.choices) do if c == want then pick = c break end end
			if pick then break end
		end
		pick = pick or offer.choices[1]
		if pick then
			lastOffer = offer.id
			PerkRemotes.Choose:FireServer(offer.id, pick)
			stat.note = "perk: " .. tostring(pick)
		end
	end

	-- end of run: every zone done -> take the exit (vent hole on House, hatch on hatch maps)
	local runOver, lastFinish = false, 0
	local RunOverEv = Remotes:FindFirstChild("RunOver")
	if RunOverEv then
		ctl.cons = ctl.cons or {}
		table.insert(ctl.cons, RunOverEv.OnClientEvent:Connect(function() runOver = true end))
	end
	local function allZonesDone()
		if RS:GetAttribute("RunCompleted") == true then return true end
		local any = false
		for _, z in ipairs(Map.Leave_Locations:GetChildren()) do
			if z:IsA("Model") then
				any = true
				if z:GetAttribute("Completed") ~= true then return false end
			end
		end
		return any
	end
	-- any ending event (FallStart/FallProceed, HatchProceed, GasStation/SpaceMap/BarnEndProceed)
	-- means the exit worked and the end cutscene runs; don't trigger it again
	local ending = false
	for _, r in ipairs(Remotes:GetChildren()) do
		if r:IsA("RemoteEvent") and (r.Name == "FallStart" or r.Name:match("Proceed$")) then
			ctl.cons = ctl.cons or {}
			table.insert(ctl.cons, r.OnClientEvent:Connect(function() ending = true end))
		end
	end
	local function finishRun()
		if ending then stat.state = "end cutscene" return end
		if runOver or os.clock() - lastFinish < 15 then return end
		lastFinish = os.clock()
		stat.state = "finishing run"
		if (A("Leaves") or 0) > 0 then sell() end
		local h = hrp(); if not h then return end
		local fall = Map:FindFirstChild("PlayerFalling")
		if fall and fall:IsA("BasePart") then
			h.CFrame = CFrame.new(fall.Position + Vector3.new(0, 2, 0))
			task.wait(0.3)
			if firetouchinterest then
				firetouchinterest(h, fall, 0); task.wait(); firetouchinterest(h, fall, 1)
			end
		end
		if workspace:GetAttribute("MapHasHatch") then
			local hatch = Map:FindFirstChild("HatchDoor")
			if not hatch then
				for _, d in ipairs(Map:GetDescendants()) do
					if (d:IsA("Model") or d:IsA("BasePart")) and d.Name:lower():find("hatch") then hatch = d break end
				end
			end
			if hatch then
				local cf, size
				if hatch:IsA("Model") then cf, size = hatch:GetBoundingBox() else cf, size = hatch.CFrame, hatch.Size end
				h.CFrame = CFrame.new(cf.Position + Vector3.new(0, size.Y / 2 + 3, 0))
				task.wait(0.6)
			end
			local hc = Remotes:FindFirstChild("HatchClicked")
			if hc then hc:FireServer() end
		end
	end

	-- ===== vents =====
	-- VentEat has no rate limit: every leaf within ~60 studs of an unlocked vent can be eaten
	-- in one go while standing at the vent; pays CashPerLeaf instantly, no bag, no dumpster.
	local LeafNet = require(RS:WaitForChild("LeafNet"))
	local VentEat, BuyVent = Remotes:FindFirstChild("VentEat"), Remotes:FindFirstChild("BuyVent")
	local life
	pcall(function()
		for _, v in pairs(debug.getupvalues(LeafSim.collectMany)) do
			if type(v) == "table" and type(rawget(v, "epochs")) == "function" then life = v end
		end
	end)
	local VENT_R = 56
	local ventBuyNext, ventSent = {}, {}
	local function ventsFolder() return Map:FindFirstChild("Vents") end
	local function buyVents()
		local vf = ventsFolder(); if not (vf and BuyVent) then return end
		for _, v in ipairs(vf:GetChildren()) do
			if v:IsA("BasePart") and not v:GetAttribute("Unlocked") and (v:GetAttribute("Cost") or math.huge) <= (A("Cash") or 0)
				and os.clock() > (ventBuyNext[v] or 0) then
				ventBuyNext[v] = os.clock() + 25
				stat.state = "buying vent"
				tp(v.Position + Vector3.new(0, 4, 0)); task.wait(S.tpWait + 0.1)
				BuyVent:FireServer(v); task.wait(0.4)
			end
		end
	end
	local function ventPass()
		if not (VentEat and life and resolveIds()) then return false end
		local vf = ventsFolder(); if not vf then return false end
		local vents = {}
		for _, v in ipairs(vf:GetChildren()) do
			if v:IsA("BasePart") and v:GetAttribute("Unlocked") then vents[#vents + 1] = v end
		end
		if #vents == 0 then return false end
		local now = os.clock()
		local groups = {}
		for _, l in ipairs(Leaves:GetChildren()) do
			if usable(l) then
				local id = partId[l]
				if id and now > (ventSent[id] or 0) then
					local p = l.Position
					for _, v in ipairs(vents) do
						if (v.Position - p).Magnitude <= VENT_R then
							local g = groups[v]
							if not g then g = {}; groups[v] = g end
							g[#g + 1] = id
							break
						end
					end
				end
			end
		end
		local best, bn = nil, 0
		for v, g in pairs(groups) do if #g > bn then best, bn = v, #g end end
		if not best then return false end
		stat.state = ("venting %d"):format(bn)
		tp(best.Position + Vector3.new(0, 4, 0)); task.wait(S.tpWait)
		local ids = groups[best]
		for i = 1, #ids, 60 do
			local m = math.min(60, #ids - i + 1)
			local chunk = table.move(ids, i, i + m - 1, 1, table.create(m))
			VentEat:FireServer(LeafNet.packIds(chunk, m), life.epochs(chunk))
		end
		for _, id in ipairs(ids) do ventSent[id] = now + 10 end
		stat.vented = (stat.vented or 0) + #ids
		task.wait(0.35)
		return true
	end

	-- journal "collection" leaves pay gems the first time (Basement 100, Farm 60, Pool 40...).
	-- Vent-eaten ones do not count, so pick them up by hand before venting.
	local collTried = {}
	local function collectionPass()
		if not LeafSim.isCollectionLeafPart then return false end
		for _, l in ipairs(Leaves:GetChildren()) do
			if usable(l) and not collTried[l] then
				local okc, isColl = pcall(LeafSim.isCollectionLeafPart, l)
				if okc and isColl then
					collTried[l] = true
					stat.state = "collection leaf"
					tp(l.Position + Vector3.new(0, 3, 0)); task.wait(S.tpWait + 0.1)
					if l.Parent == Leaves then LeafSim.collectMany({ l }) end
					task.wait(0.4)
					stat.coll = (stat.coll or 0) + 1
					return true
				end
			end
		end
		return false
	end

	-- free helper bot (Duck/Elephant/...): deploy whenever it is not running or recharging
	local DeployBot = Remotes:FindFirstChild("DeployL33FBOT")
	local botNext = 0
	local function deployBot()
		if not DeployBot or os.clock() < botNext then return end
		botNext = os.clock() + 10
		if A("L33FBOTActive") or A("L33FBOTCooldown") then return end
		DeployBot:FireServer()
	end

	-- grab budget: server accepts ~400 leaves per burst and refills ~200/s; anything above is dropped
	local tokens, tokT = 380, os.clock()
	local function refill()
		local now = os.clock()
		tokens = math.min(380, tokens + (now - tokT) * 190)
		tokT = now
	end

	-- main farm loop
	task.spawn(function()
		while alive() do
			if S.duck then pcall(grabDuck) end
			if S.bag then pcall(buyBag) end
			if S.hand then pcall(buyHand) end
			if S.bot then pcall(deployBot) end
			if S.perk and LeafSim.perkInputBlocked() then
				pcall(pickPerk)
				if LeafSim.perkInputBlocked() then task.wait(0.5) end
			end
			-- the opening cutscene does not block grabs server-side, only leaf loading matters
			local loading = A("LeafLoadingStage") ~= nil and A("LeafLoadingStage") ~= "Ready"
			if not S.farm or loading or A("RankedInputLocked") or LeafSim.perkInputBlocked() then
				stat.state = not S.farm and "off" or loading and "waiting (leaves loading)" or "waiting (perk)"
				task.wait(0.4)
			else
				local ok, err = pcall(function()
					local cap = capLeft()
					-- near-full bag: a trip to the dumpster beats many tiny grabs
					if cap <= math.max(2, math.floor((A("LeafCapacity") or 25) * 0.04)) and (A("Leaves") or 0) > 0 then sell() return end
					if S.collect and collectionPass() then return end
					if S.vents then
						buyVents()
						if ventPass() then return end
					end
					refill()
					if tokens < 40 then stat.state = "waiting for grab budget" task.wait((40 - tokens) / 190) refill() end
					local spot = pickPatch(math.min(cap, math.floor(tokens)))
					if not spot then
						if runOver then stat.state = "round cleared, back to lobby soon" task.wait(1) return end
						if S.finish and allZonesDone() then finishRun() task.wait(1) return end
						stat.state = "no leaves (next wave / zone locked)"
						if (A("Leaves") or 0) > 0 then sell() end
						task.wait(1)
						return
					end
					stat.state = "grabbing"
					tp(spot + Vector3.new(0, 3, 0))
					task.wait(S.tpWait)
					local h = hrp(); if not h then return end
					refill()
					local list = nearLeaves(h.Position, math.min(cap, math.floor(tokens)))
					if #list == 0 then return end
					local before = A("Leaves") or 0
					local sent = 0
					local per = math.max(1, math.floor(tonumber(LeafSim.upgEffect("Hand", "Grasp")) or 1))
					local grp = {}
					for _, l in ipairs(list) do
						if l.Parent == Leaves then
							grp[#grp + 1] = l
							if #grp >= per then sent = sent + LeafSim.collectMany(grp); grp = {} end
						end
					end
					if #grp > 0 then sent = sent + LeafSim.collectMany(grp) end
					tokens = tokens - sent
					-- the server answers in batches (often 1 leaf, then the rest ~0.5s later):
					-- stay in range until the count is stable, otherwise late grabs are rejected
					local t, last, lastChange = os.clock(), before, os.clock()
					while os.clock() - t < 2.5 do
						task.wait(0.05)
						local now = A("Leaves") or 0
						if now ~= last then last, lastChange = now, os.clock() end
						if capLeft() <= 0 then break end
						if now - before >= sent * 0.95 then break end
						if os.clock() - lastChange > 0.6 then break end
					end
					local got = (A("Leaves") or 0) - before
					if got <= 0 and capLeft() > 0 and sent >= 5 then
						-- nothing accepted with free bag space: locked area -> skip it for a while
						banned[#banned + 1] = { p = spot, t = os.clock() + 20 }
						stat.note = "skipped locked spot"
					end
					stat.grabbed = stat.grabbed + math.max(got, 0)
					stat.log = stat.log or {}
					table.insert(stat.log, ("sent %d got %d cap %d [%s]"):format(#list, got, cap, zoneOf(list[1])))
					if #stat.log > 30 then table.remove(stat.log, 1) end
				end)
				if not ok then stat.note = tostring(err):sub(1, 80); task.wait(0.5) end
				task.wait()
			end
		end
	end)
end

-- ===================================================================
-- LOBBY
-- ===================================================================
local function lobby()
	local function tryCall(name, ...)
		local r = Remotes:FindFirstChild(name)
		if not r then return end
		local args = table.pack(...)
		return pcall(function()
			if r:IsA("RemoteFunction") then return r:InvokeServer(table.unpack(args, 1, args.n)) end
			r:FireServer(table.unpack(args, 1, args.n))
		end)
	end
	local function getData()
		for _ = 1, 3 do
			local ok, d = tryCall("GetMyData")
			if ok and type(d) == "table" then return d end
			task.wait(1)
		end
	end

	local PUC = require(RS:WaitForChild("PlayerUpgradeConfig"))
	local MapList = require(RS:WaitForChild("MapList"))
	local TeamMenu, TeamAction = Remotes:WaitForChild("TeamMenu"), Remotes:WaitForChild("TeamAction")

	-- diamonds per minute per map/difficulty, measured across runs (lobby -> run -> lobby)
	local RATE_FILE = "RaffirScripts/leaf_farm_rates.json"
	local R = { rates = {} }
	pcall(function() if isfile(RATE_FILE) then R = HttpService:JSONDecode(readfile(RATE_FILE)) end end)
	R.rates = R.rates or {}
	local function saveRates() pcall(function() writefile(RATE_FILE, HttpService:JSONEncode(R)) end) end

	local menu = { opened = nil, unlocked = nil, maxDiff = nil }
	ctl.cons = ctl.cons or {}
	table.insert(ctl.cons, TeamMenu.OnClientEvent:Connect(function(kind, a, b, c, d, e, f, g2)
		if kind == "open" then
			menu.opened = a
			menu.maxDiff = tonumber(e)
			if type(g2) == "table" then menu.unlocked = g2 end
		elseif kind == "mapctx" then
			menu.maxDiff = tonumber(a)
		elseif kind == "close" then
			menu.opened = nil
		end
	end))

	local function claims(d)
		tryCall("DailyClaim")
		if not d.FreeGiftClaimed then tryCall("FreeGiftClaim") end
		if not d.GroupRewardClaimed then
			local ok, r = tryCall("GroupClaim", false)
			if ok and r == "notmember" then
				local okm, member = pcall(function() return lp:IsInGroupAsync(require(RS.GroupRewardConfig).groupId) end)
				if okm and member then tryCall("GroupClaim", true) end
			end
		end
	end

	-- crew (clan) rewards: thresholds of weekly contribution, claimable once each
	local function clanClaims()
		local CR = Remotes:FindFirstChild("ClanRequest")
		if not CR then return end
		local data
		for _ = 1, 3 do
			local ok, r = pcall(function() return CR:InvokeServer("Open", {}) end)
			if ok and type(r) == "table" and r.ok ~= false then data = r.data or r break end
			task.wait(2)
		end
		if type(data) ~= "table" or type(data.rewards) ~= "table" then return end
		for _, rw in ipairs(data.rewards) do
			if not rw.claimed and rw.threshold and rw.threshold <= (data.contribution or 0) then
				pcall(function() CR:InvokeServer("Claim", { threshold = rw.threshold }) end)
				task.wait(0.5)
			end
		end
	end

	-- best owned helper bot (Speed + Vacuum)
	local function equipBot(d)
		local BC = require(RS:WaitForChild("BotConfig"))
		local best, bs
		for _, b in ipairs(BC.BOTS) do
			local okO, owns = pcall(BC.owns, d, b.key)
			if okO and owns then
				local sc = (b.stats and (b.stats.Speed or 0) + (b.stats.Vacuum or 0)) or 0
				if not bs or sc > bs then best, bs = b.key, sc end
			end
		end
		if best and d.EquippedBot ~= best then
			pcall(function() Remotes.BotEquip:InvokeServer(best) end)
			stat.note = stat.note .. " | bot " .. best
		end
	end

	-- class roll: Diamond Treasurer (2.5x gems) or Handy Man (everything); 40 per roll
	local GOOD_CLASS = { DiamondTreasurer = true, HandyMan = true }
	local function classRoll(d)
		local CA, CS = Remotes:FindFirstChild("ClassAction"), Remotes:FindFirstChild("ClassSpin")
		if not (CA and CS) then return end
		local CC = require(RS:WaitForChild("ClassConfig"))
		local ok, r = pcall(function() return CA:InvokeServer("state") end)
		local st = ok and type(r) == "table" and r.state
		if type(st) ~= "table" then return end
		local slot = st.selectedSlot or 1
		local cur = st.slots and st.slots[slot] or "Starter"
		if GOOD_CLASS[cur] then return nil end
		local pad = workspace:FindFirstChild("ClassPad")
		if pad then tp(pad:GetPivot().Position + Vector3.new(0, 3, 0)); task.wait(0.6) end
		local rolls = 0
		while alive() and (st.diamonds or d.Diamonds or 0) >= (CC.SPIN_COST or 40) do
			stat.state = ("rolling class (%s)"):format(cur)
			local okS, res = pcall(function() return CS:InvokeServer(slot, nil) end)
			if not (okS and type(res) == "table") then break end
			if res.state then st = res.state end
			if res.status == "ok" and res.key then
				rolls = rolls + 1
				cur = res.key
				if GOOD_CLASS[cur] then break end
				task.wait((tonumber(res.duration) or CC.NORMAL_ROLL_SECONDS or 4.5) + 0.2)
			elseif tonumber(res.retryAfter) then
				task.wait(tonumber(res.retryAfter) + 0.1)
			else
				stat.note = stat.note .. " | class roll: " .. tostring(res.status)
				break
			end
		end
		if rolls > 0 then return ("%d class rolls -> %s"):format(rolls, cur) end
	end

	local function upgrades(d)
		-- Gems first (more diamonds per run), then cash/bag; walk/grab/robot don't matter for the farm
		local PRIO = { Gems = 1, Cash = 2, BagCapacity = 3, WalkSpeed = 4, GrabCapacity = 5, RobotSpeed = 6 }
		local bought = 0
		for _ = 1, 15 do
			local best, bp
			for _, u in ipairs(PUC.upgrades) do
				local lvl = (d.Upgrades and d.Upgrades[u.key]) or 0
				local c = u.costs[lvl + 1]
				local p = PRIO[u.key] or 9
				if c and c <= (d.Diamonds or 0) and (not bp or p < bp) then best, bp = u, p end
			end
			if not best then break end
			local ok, r = tryCall("UpgradeBuy", best.key)
			if not ok or r == false then break end
			bought = bought + 1
			task.wait(0.4)
			d = getData() or d
		end
		return d, bought
	end

	-- progress: unplayed unlocked maps first (unlocks the next map), then raise the lowest
	-- difficulty; when everything is cleared on Impossible, repeat the best measured rate
	local function chooseMap(d)
		if S.mode ~= "progress" then return S.map, S.diff end
		local clears = d.MapClears or {}
		local unlocked = menu.unlocked or {}
		local pick, low
		for _, m in ipairs(MapList) do
			if unlocked[m.key] and not m.comingSoon then
				local c = tonumber(clears[m.key]) or 0
				if c == 0 then return m.key, 1 end
				if c < 4 and (not low or c < low) then pick, low = m.key, c end
			end
		end
		if pick then return pick, low + 1 end
		local bestKey, bestRate
		for k, r in pairs(R.rates) do
			local map = k:match("^(.-)#4$")
			if map and unlocked[map] and (not bestRate or r > bestRate) then bestKey, bestRate = map, r end
		end
		return bestKey or MapList[#MapList].key, 4
	end

	local function startRun(d)
		local teams = workspace:FindFirstChild("Teams")
		local pad
		for _, sq in ipairs(teams and teams:GetChildren() or {}) do
			if sq:GetAttribute("State") == "Open" and (sq:GetAttribute("Count") or 0) == 0 then pad = sq break end
		end
		local h = hrp()
		if not (pad and h) then stat.state = "no free pad" return false end
		stat.state = "joining " .. pad.Name
		menu.opened = nil
		h.CFrame = CFrame.new(pad:GetPivot().Position + Vector3.new(14, 3, 0))
		task.wait(1)
		local hum = lp.Character and lp.Character:FindFirstChildOfClass("Humanoid")
		if hum then hum:MoveTo(pad:GetPivot().Position) end
		local t = os.clock()
		while not menu.opened and os.clock() - t < 6 do task.wait(0.1) end
		if not menu.opened then stat.state = "pad menu did not open, retrying" return false end
		local map, diff = chooseMap(d)
		menu.maxDiff = nil
		TeamAction:FireServer("setMap", map)
		t = os.clock()
		while not menu.maxDiff and os.clock() - t < 3 do task.wait(0.1) end
		diff = math.clamp(diff, 1, menu.maxDiff or 1)
		TeamAction:FireServer("setDifficulty", diff); task.wait(0.3)
		TeamAction:FireServer("setMax", 1); task.wait(0.3)
		R.pending = { key = map .. "#" .. diff, diamonds = d.Diamonds or 0, t = os.time() }
		saveRates()
		TeamAction:FireServer("confirm")
		stat.state = ("starting %s (%s)"):format(map, ({ "Easy", "Medium", "Hard", "Impossible" })[diff] or diff)
		return true
	end

	task.spawn(function()
		local d = getData()
		while alive() and not d do task.wait(2); d = getData() end
		if not alive() then return end
		-- rate of the run we just came back from (before claims/upgrades change the balance)
		if R.pending and d.Diamonds then
			local p = R.pending
			local mins = (os.time() - p.t) / 60
			if mins > 1 and mins < 60 and d.Diamonds >= p.diamonds then
				local rate = (d.Diamonds - p.diamonds) / mins
				local old = R.rates[p.key]
				R.rates[p.key] = old and (old * 0.5 + rate * 0.5) or rate
				stat.note = ("last run %s: %.1f 💎/min"):format(p.key, rate)
				local ses = loadSession()
				ses.runs = (ses.runs or 0) + 1
				ses.gained = (ses.gained or 0) + (d.Diamonds - p.diamonds)
				ses.last = os.time()
				saveSession(ses)
			end
			R.pending = nil
			saveRates()
		end
		if S.claim then claims(d); task.wait(1); d = getData() or d end
		if S.clan then pcall(clanClaims) end
		if S.bot then pcall(equipBot, d) end
		if S.classroll then
			local okr, res = pcall(classRoll, d)
			if okr and res then stat.note = stat.note .. " | " .. res end
			d = getData() or d
		end
		local bought = 0
		if S.upgrade then d, bought = upgrades(d) end
		stat.cash = d.Diamonds or 0
		if bought > 0 then stat.note = stat.note .. (" | %d upgrades"):format(bought) end
		task.wait(2)
		while alive() do
			if S.autostart then
				if startRun(d) then
					for _ = 1, 30 do if not alive() then return end task.wait(0.5) end
					stat.state = "teleport did not happen, retrying"
				end
				task.wait(3)
				d = getData() or d
			else
				stat.state = "idle (Auto Start off)"
				task.wait(1)
			end
		end
	end)
end

-- ===================================================================
-- GUI
-- ===================================================================
local gui = Instance.new("ScreenGui")
gui.Name = "LF_" .. tostring(math.random(1e5, 1e6))
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
pcall(function() gui.Parent = (gethui and gethui()) or game:GetService("CoreGui") end)
if not gui.Parent then gui.Parent = lp:WaitForChild("PlayerGui") end

local frame = Instance.new("Frame")
frame.Size = UDim2.fromOffset(240, 0)
frame.AutomaticSize = Enum.AutomaticSize.Y
frame.Position = UDim2.new(0, 20, 0.35, 0)
frame.BackgroundColor3 = Color3.fromRGB(28, 24, 20)
frame.BorderSizePixel = 0
frame.Active = true
frame.Draggable = true
frame.Parent = gui
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)
local pad = Instance.new("UIPadding", frame)
pad.PaddingTop, pad.PaddingBottom, pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 8), UDim.new(0, 8), UDim.new(0, 8), UDim.new(0, 8)
local layout = Instance.new("UIListLayout", frame)
layout.Padding = UDim.new(0, 5)
layout.SortOrder = Enum.SortOrder.LayoutOrder

local order = 0
local function label(text, size, color)
	order = order + 1
	local l = Instance.new("TextLabel")
	l.LayoutOrder = order
	l.Size = UDim2.new(1, 0, 0, size or 18)
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.GothamBold
	l.TextSize = 13
	l.TextColor3 = color or Color3.fromRGB(240, 200, 140)
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextWrapped = true
	l.Text = text
	l.Parent = frame
	return l
end
local function toggle(text, key)
	order = order + 1
	local b = Instance.new("TextButton")
	b.LayoutOrder = order
	b.Size = UDim2.new(1, 0, 0, 26)
	b.BorderSizePixel = 0
	b.Font = Enum.Font.GothamBold
	b.TextSize = 13
	b.TextColor3 = Color3.new(1, 1, 1)
	b.AutoButtonColor = true
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
	local function paint()
		b.Text = text .. (S[key] and "  ON" or "  OFF")
		b.BackgroundColor3 = S[key] and Color3.fromRGB(60, 140, 60) or Color3.fromRGB(140, 55, 50)
	end
	paint()
	b.MouseButton1Click:Connect(function() S[key] = not S[key]; paint(); save() end)
	b.Parent = frame
	return b
end
local function cycle(text, values, key, fmt)
	order = order + 1
	local b = Instance.new("TextButton")
	b.LayoutOrder = order
	b.Size = UDim2.new(1, 0, 0, 24)
	b.BorderSizePixel = 0
	b.Font = Enum.Font.Gotham
	b.TextSize = 13
	b.TextColor3 = Color3.new(1, 1, 1)
	b.BackgroundColor3 = Color3.fromRGB(60, 52, 44)
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
	local function paint() b.Text = text .. ": " .. (fmt and fmt(S[key]) or tostring(S[key])) end
	paint()
	b.MouseButton1Click:Connect(function()
		local idx = 1
		for i, v in ipairs(values) do if v == S[key] then idx = i end end
		S[key] = values[idx % #values + 1]
		paint(); save()
	end)
	b.Parent = frame
end

label(IS_RUN and "🍂 Leaf Farm — Run" or "🍂 Leaf Farm — Lobby", 20)
if IS_RUN then
	toggle("Auto Farm", "farm")
	toggle("Vent Eat (no limit)", "vents")
	toggle("Auto Bag Upgrade", "bag")
	toggle("Auto Hand Grasp", "hand")
	toggle("Auto Perk Pick", "perk")
	toggle("Duck Part", "duck")
	toggle("Auto Finish Run", "finish")
	toggle("Collection Leaves (gems)", "collect")
	toggle("Auto Deploy Bot", "bot")
else
	toggle("Auto Claim (daily/gift/group)", "claim")
	toggle("Auto Upgrade (diamonds)", "upgrade")
	toggle("Class Roll (Diamond Treasurer)", "classroll")
	toggle("Crew Rewards", "clan")
	toggle("Equip Best Bot", "bot")
	toggle("Auto Start Solo Run", "autostart")
	local maps, mapNames = {}, {}
	pcall(function()
		for _, m in ipairs(require(RS.MapList)) do
			if not m.comingSoon then maps[#maps + 1] = m.key; mapNames[m.key] = m.name end
		end
	end)
	if #maps == 0 then maps = { "House" } end
	cycle("Mode", { "progress", "fixed" }, "mode", function(v) return v == "progress" and "Progress (auto map/diff)" or "Fixed map/diff" end)
	cycle("Map", maps, "map", function(k) return mapNames[k] or k end)
	local diffNames = { "Easy", "Medium", "Hard", "Impossible" }
	cycle("Difficulty", { 1, 2, 3, 4 }, "diff", function(v) return diffNames[v] or tostring(v) end)
end
local info = label("", 100, Color3.fromRGB(220, 220, 220))
info.Font = Enum.Font.Gotham
info.TextYAlignment = Enum.TextYAlignment.Top
label("RightShift: hide", 14, Color3.fromRGB(150, 140, 130)).TextSize = 11

local sesText, sesAt = "", 0
task.spawn(function()
	while alive() do
		if os.clock() - sesAt > 5 then sesAt = os.clock(); sesText = sessionText() end
		if IS_RUN then
			info.Text = ("%s\nbag %d/%s  cash $%.2f\nvented %d  grabbed %d  trips %d\n%s"):format(
				stat.state, A("Leaves") or 0, A("InfiniteBag") and "∞" or tostring(A("LeafCapacity") or "?"),
				A("Cash") or 0, stat.vented or 0, stat.grabbed, stat.trips, stat.note .. "\n" .. sesText)
		else
			info.Text = ("%s\ndiamonds %s\n%s\n%s"):format(stat.state, tostring(stat.cash), stat.note, sesText)
		end
		task.wait(0.25)
	end
end)

local keyCon = UIS.InputBegan:Connect(function(i, gp)
	if not gp and i.KeyCode == Enum.KeyCode.RightShift then frame.Visible = not frame.Visible end
end)

ctl.kill = function()
	ctl.alive = false
	pcall(function() keyCon:Disconnect() end)
	for _, c in ipairs(ctl.cons or {}) do pcall(function() c:Disconnect() end) end
	pcall(function() gui:Destroy() end)
end
ctl.S, ctl.stat = S, stat

if IS_RUN then task.spawn(runPlace) else task.spawn(lobby) end
