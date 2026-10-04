--[[ Clean all the Leaves — Leaf Farm
     Runs in the lobby AND in the run place (same universe 10539411000).

     RUN PLACE
       Auto Farm     teleports to the densest patch of visible leaves, grabs a full bag in one
                     burst (server only checks range ~30 studs, no cooldown), sells at the best
                     unlocked dumpster, repeats. Locked zones are skipped automatically
                     (their leaves stay Transparency 1 until the zone unlocks).
       Auto Bag      buys bag upgrades as soon as cash allows (25 -> 75 -> 500 -> 1000).
       Auto Perk     picks run perks by priority (Safety Valve auto-sell, Roomy Bag, Hidden Gems...).
       Duck Part     picks up the hidden duck bot part of this map once.
       Auto Finish   when every zone is done, takes the exit (House: vent hole, Mansion: hatch)
                     -> round cleared, back to lobby.
     LOBBY
       Auto Claim    daily reward, free gift, group reward (if in group).
       Auto Upgrade  spends diamonds on lobby upgrades (Gems > Cash > Bag > rest).
       Auto Start    walks onto a free pad and starts a SOLO run with the chosen map/difficulty.

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
	farm = true, bag = true, duck = true, perk = true, finish = true,
	claim = true, upgrade = true, autostart = false,
	map = "House", diff = 1,
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
		return z ~= nil and z:GetAttribute("Completed") == true
	end

	local function bestDumpster()
		local best, bp = nil, -1
		for _, d in ipairs(Map.Dumpsters:GetChildren()) do
			if d:IsA("Model") and zoneDone(d:GetAttribute("ZoneRequired")) then
				local p = d:GetAttribute("PricePerLeaf") or 0
				if p > bp then best, bp = d, p end
			end
		end
		return best
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

	local duckDone = false
	local function grabDuck()
		if duckDone then return end
		duckDone = true
		local part
		for _, x in ipairs(Map:GetChildren()) do
			if x.Name:match("^DuckBotPart") then part = x break end
		end
		if not part then return end
		local p = part:IsA("Model") and part:GetPivot().Position or part.Position
		local h = hrp(); if not h then return end
		local back = h.CFrame
		tp(p + Vector3.new(0, 3, 0)); task.wait(S.tpWait + 0.2)
		local remote = Remotes:FindFirstChild("CollectDuckBotPart")
		if remote then
			remote:FireServer(part)
			local bp = part:IsA("Model") and part:FindFirstChildWhichIsA("BasePart", true)
			if bp then task.wait(0.2); remote:FireServer(bp) end
		end
		task.wait(0.3)
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
	local function finishRun()
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

	-- main farm loop
	task.spawn(function()
		while alive() do
			if S.duck then pcall(grabDuck) end
			if S.bag then pcall(buyBag) end
			if S.perk and LeafSim.perkInputBlocked() then
				pcall(pickPerk)
				if LeafSim.perkInputBlocked() then task.wait(0.5) end
			end
			if not S.farm or A("CutsceneActive") or A("RankedInputLocked") or LeafSim.perkInputBlocked() then
				stat.state = S.farm and "waiting (cutscene/perk)" or "off"
				task.wait(0.4)
			else
				local ok, err = pcall(function()
					local cap = capLeft()
					-- near-full bag: a trip to the dumpster beats many tiny grabs
					if cap <= math.max(2, math.floor((A("LeafCapacity") or 25) * 0.04)) and (A("Leaves") or 0) > 0 then sell() return end
					local spot = pickPatch(cap)
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
					local list = nearLeaves(h.Position, cap)
					if #list == 0 then return end
					local before = A("Leaves") or 0
					for _, l in ipairs(list) do
						if l.Parent == Leaves then LeafSim.collectMany({ l }) end
					end
					-- accepted leaves trickle in: wait until the bag count settles
					local t, last, lastChange = os.clock(), before, os.clock()
					while os.clock() - t < 2 do
						task.wait(0.05)
						local now = A("Leaves") or 0
						if now ~= last then last, lastChange = now, os.clock() end
						if capLeft() <= 0 then break end
						if now > before and os.clock() - lastChange > 0.2 then break end
						if now == before and os.clock() - t > 1 then break end
					end
					local got = (A("Leaves") or 0) - before
					if got <= 0 and capLeft() > 0 then
						-- nothing accepted with free bag space: locked area -> skip it for a while
						banned[#banned + 1] = { p = spot, t = os.clock() + 20 }
						stat.note = "skipped locked spot"
					end
					stat.grabbed = stat.grabbed + math.max(got, 0)
					stat.log = stat.log or {}
					table.insert(stat.log, ("sent %d got %d cap %d"):format(#list, got, cap))
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
		local ok, d = tryCall("GetMyData")
		return ok and type(d) == "table" and d or nil
	end

	local PUC = require(RS:WaitForChild("PlayerUpgradeConfig"))

	task.spawn(function()
		local claimedOnce = false
		while alive() do
			local d = getData()
			if d then
				stat.cash = d.Diamonds or 0
				if S.claim and not claimedOnce then
					claimedOnce = true
					tryCall("DailyClaim")
					if not d.FreeGiftClaimed then tryCall("FreeGiftClaim") end
					if not d.GroupRewardClaimed then
						local ok, r = tryCall("GroupClaim", false)
						if ok and r == "notmember" then
							local okm, member = pcall(function() return lp:IsInGroupAsync(require(RS.GroupRewardConfig).groupId) end)
							if okm and member then tryCall("GroupClaim", true) end
						end
					end
					stat.note = "claims sent"
				end
				if S.upgrade then
					-- Gems first (more diamonds per run), then cash/bag; walk/grab/robot don't matter for the farm
					local PRIO = { Gems = 1, Cash = 2, BagCapacity = 3, WalkSpeed = 4, GrabCapacity = 5, RobotSpeed = 6 }
					for _ = 1, 10 do
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
						task.wait(0.4)
						d = getData() or d
					end
				end
			end
			for _ = 1, 20 do if not alive() then return end task.wait(0.5) end
		end
	end)

	-- auto start solo run
	task.spawn(function()
		local TeamMenu, TeamAction = Remotes:WaitForChild("TeamMenu"), Remotes:WaitForChild("TeamAction")
		local opened
		local con = TeamMenu.OnClientEvent:Connect(function(kind, pad)
			if kind == "open" then opened = pad end
		end)
		ctl.cons = ctl.cons or {}
		table.insert(ctl.cons, con)
		task.wait(4)
		while alive() do
			if S.autostart then
				local teams = workspace:FindFirstChild("Teams")
				local pad
				for _, sq in ipairs(teams and teams:GetChildren() or {}) do
					if sq:GetAttribute("State") == "Open" and (sq:GetAttribute("Count") or 0) == 0 then pad = sq break end
				end
				local h = hrp()
				if pad and h then
					stat.state = "joining " .. pad.Name
					opened = nil
					h.CFrame = CFrame.new(pad:GetPivot().Position + Vector3.new(14, 3, 0))
					task.wait(1)
					local hum = lp.Character:FindFirstChildOfClass("Humanoid")
					if hum then hum:MoveTo(pad:GetPivot().Position) end
					local t = os.clock()
					while not opened and os.clock() - t < 6 do task.wait(0.1) end
					if opened then
						TeamAction:FireServer("setMap", S.map); task.wait(0.3)
						TeamAction:FireServer("setDifficulty", S.diff); task.wait(0.3)
						TeamAction:FireServer("setMax", 1); task.wait(0.3)
						TeamAction:FireServer("confirm")
						stat.state = "starting run (teleport)"
						task.wait(12)
					else
						stat.state = "pad menu did not open, retrying"
					end
				else
					stat.state = "no free pad"
				end
				task.wait(3)
			else
				stat.state = "idle"
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
	toggle("Auto Bag Upgrade", "bag")
	toggle("Auto Perk Pick", "perk")
	toggle("Duck Part", "duck")
	toggle("Auto Finish Run", "finish")
else
	toggle("Auto Claim (daily/gift/group)", "claim")
	toggle("Auto Upgrade (diamonds)", "upgrade")
	toggle("Auto Start Solo Run", "autostart")
	local maps, mapNames = {}, {}
	pcall(function()
		for _, m in ipairs(require(RS.MapList)) do
			if not m.comingSoon then maps[#maps + 1] = m.key; mapNames[m.key] = m.name end
		end
	end)
	if #maps == 0 then maps = { "House" } end
	cycle("Map", maps, "map", function(k) return mapNames[k] or k end)
	local diffNames = { "Easy", "Medium", "Hard", "Impossible" }
	cycle("Difficulty", { 1, 2, 3, 4 }, "diff", function(v) return diffNames[v] or tostring(v) end)
end
local info = label("", 70, Color3.fromRGB(220, 220, 220))
info.Font = Enum.Font.Gotham
info.TextYAlignment = Enum.TextYAlignment.Top
label("RightShift: hide", 14, Color3.fromRGB(150, 140, 130)).TextSize = 11

task.spawn(function()
	while alive() do
		if IS_RUN then
			info.Text = ("%s\nbag %d/%s  cash $%.2f\ngrabbed %d  trips %d\n%s"):format(
				stat.state, A("Leaves") or 0, A("InfiniteBag") and "∞" or tostring(A("LeafCapacity") or "?"),
				A("Cash") or 0, stat.grabbed, stat.trips, stat.note)
		else
			info.Text = ("%s\ndiamonds %s\n%s"):format(stat.state, tostring(stat.cash), stat.note)
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
