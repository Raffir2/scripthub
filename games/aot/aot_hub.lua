-- AOT:R HUB  (Attack on Titan Revolution)
-- Start: loadstring(readfile("aot_hub.lua"))()     UI an/aus: RightShift   Kill-Aura: K
-- Main-VM: GUI, Kill-Aura, Blades/Refill, ESP, Visuals, Misc
-- Actor-VM (Character.Actor): Gas/ODM-Stats/Familien-Buffs, Anti-Ragdoll, Auto-Grab-Escape, Auto-Chest/Retry

local g = getgenv()
if g.AOTHUB and g.AOTHUB.Kill then pcall(g.AOTHUB.Kill, true) end

-- Autoexec laeuft vor LocalPlayer -> sonst ist LP nil und alle Loops sterben beim ersten Durchlauf
if not game:IsLoaded() then game.Loaded:Wait() end
local Players = game:GetService("Players")
local RS = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local CG = game:GetService("CoreGui")
local Lighting = game:GetService("Lighting")
local LP = Players.LocalPlayer
while not LP do Players:GetPropertyChangedSignal("LocalPlayer"):Wait() LP = Players.LocalPlayer end

local S = { alive = true, conns = {}, esp = {}, kills = 0, status = "", dbg = {} }
local function DBG(t) if S.dbgOn then S.dbg[#S.dbg + 1] = string.format("%.2f %s", os.clock(), t) end end
g.AOTHUB = S
local function conn(c) table.insert(S.conns, c) return c end

----------------------------------------------------------------- Config
local C = {
	KillAura = false, AuraRange = 5000, PerCycle = 3, Interval = 0.6, NapeOnly = true, HitCD = 1.1, SmartAura = true,
	AutoReload = true, AutoRefill = true,
	InfGas = false, InfRange = false, InfBlades = false, SpeedPct = 0, ControlPct = 0, RangePct = 0, GasPct = 0, Dashes = 0, GearUncap = false,
	Family = "Keine",
	NoRagdoll = false, AutoEscape = false,
	ESP = false, Fullbright = false, NoFog = false,
	AntiAFK = true, AutoChest = false, AutoRetry = false, UpgTarget = 2, AutoUpgrade = false,
	UIX = -1, UIY = -1, UIVisible = true, Tab = "Combat", Collapsed = false, AutoClaim = false,
	AutoFarm = false, AutoStart = true, AutoPrestige = false, PrestigeBoost = "Luck", FarmMission = "Shiganshina · Skirmish", FarmPick = "Fest", FarmMods = true, FarmMaxGrade = 12, ModOddball = false, ModTimeTrial = true, ModGlass = true, SmartGap = 1.2, ReloadAt = 4, GoldSink = true, GoldReserve = 0, AutoBoost = false, BoostType = "XP", BoostXP = true, BoostGold = false, BoostLuck = false, BoostGemReserve = 0, BoostSafety = false, StuckLeave = true, AutoBuild = true, SpeedMode = false, Webhook = true, WebhookMin = "Legendary", BossFocus = true, BossEvade = true, AutoSkip = true, AutoQTE = true, PremiumChest = false,
	RollDeposit = true, RollStartTier = "Epic", RollStop_Common = false, RollStop_Rare = false, RollStop_Epic = false, RollStop_Legendary = true, RollStop_Mythic = true, RollStop_Secret = true,
}
S.C = C
-- Raffir-Preset: komplette Farm-Einstellungen (Stand 04.10.2026).
-- Nur per Button "Raffir-Einstellungen laden" (kein Auto-Apply). Ohne Kauf-Einstellungen (Auto-Boost/Gems, Premium-Truhe/Keys).
local PRESET_VERSION = 2
local PRESET = {
	AntiAFK = true, AuraRange = 20000, AutoBuild = true, AutoChest = true, AutoClaim = true,
	AutoEscape = true, AutoFarm = true, AutoPrestige = true, AutoQTE = true, AutoRefill = true, AutoReload = true,
	AutoRetry = false, AutoSkip = true, AutoStart = true, AutoUpgrade = true,
	BossEvade = true, BossFocus = true, ControlPct = 0, Dashes = 0, ESP = true,
	Family = "Keine", FarmMaxGrade = 12, FarmMission = "Shiganshina · Skirmish", FarmMods = true,
	FarmPick = "Beste Mission", Fullbright = false, GasPct = 0, GearUncap = true, GoldReserve = 0,
	GoldSink = true, HitCD = 0.15, InfBlades = true, InfGas = true, InfRange = true, Interval = 0.1,
	KillAura = true, ModGlass = true, ModOddball = true, ModTimeTrial = true, NapeOnly = true, NoFog = false,
	NoRagdoll = false, PerCycle = 10, PrestigeBoost = "Luck", RangePct = 0, ReloadAt = 4,
	RollDeposit = true, RollStartTier = "Epic", RollStop_Common = false, RollStop_Epic = false,
	RollStop_Legendary = true, RollStop_Mythic = true, RollStop_Rare = false, RollStop_Secret = true,
	SmartAura = true, SmartGap = 1.2, SpeedMode = false, SpeedPct = 0, StuckLeave = true, UpgTarget = 12,
	Webhook = true, WebhookMin = "Legendary",
}
C.PresetVersion = 0
local function applyPreset()
	for k, v in pairs(PRESET) do
		if C[k] ~= nil and type(C[k]) == type(v) then C[k] = v end
	end
	C.PresetVersion = PRESET_VERSION
end
S.applyPreset = applyPreset
local HS = game:GetService("HttpService")
pcall(function()
	if isfile("aot_hub_cfg.json") then
		for k, v in pairs(HS:JSONDecode(readfile("aot_hub_cfg.json"))) do
			if C[k] ~= nil and type(C[k]) == type(v) then C[k] = v end
		end
	end
end)
-- Preset wird NICHT mehr automatisch uebernommen (nur per Button). Wer v1/v2 schon automatisch bekommen hat und
-- nicht SireSenpai ist: Auto-Boost einmalig aus, damit keine Gems ungewollt fuer Boosts draufgehen.
if not C.BoostSafety then
	if LP.Name ~= "SireSenpai" and (C.PresetVersion or 0) >= 1 then C.AutoBoost = false C.PremiumChest = false end
	C.BoostSafety = true
end

-- Familien-Passives (nur die client-seitigen Bewegungs-Stats sind emulierbar)
local FAM = {
	Keine     = { s = 0,  c = 0,  r = 0,  g = 0,  d = 0 },
	Ackerman  = { s = 0,  c = 10, r = 10, g = 10, d = 1 },
	Helos     = { s = 15, c = 15, r = 15, g = 15, d = 1 },
	Shiki     = { s = 0,  c = 10, r = 10, g = 10, d = 2 },
	Zoe       = { s = 10, c = 10, r = 0,  g = 0,  d = 0 },
	Azumabito = { s = 0,  c = 5,  r = 0,  g = 0,  d = 0 },
	Ksaver    = { s = 0,  c = 0,  r = 10, g = 0,  d = 0 },
	Finger    = { s = 0,  c = 0,  r = 0,  g = 10, d = 0 },
}
local FAM_ORDER = { "Keine", "Ackerman", "Helos", "Shiki", "Zoe", "Azumabito", "Ksaver", "Finger" }

-- Config-Bruecke zum Actor (Attribute auf einem Folder in CoreGui)
local Cfg = CG:FindFirstChild("AOTHubCfg") or Instance.new("Folder")
Cfg.Name = "AOTHubCfg"
Cfg.Parent = CG
local function saveCfg()
	pcall(function() writefile("aot_hub_cfg.json", HS:JSONEncode(C)) end)
end
local function syncCfg()
	saveCfg()
	local f = FAM[C.Family] or FAM.Keine
	Cfg:SetAttribute("Shutdown", false)
	Cfg:SetAttribute("InfGas", C.InfGas)
	Cfg:SetAttribute("Speed", (C.SpeedPct + f.s) / 100)
	Cfg:SetAttribute("Control", (C.ControlPct + f.c) / 100)
	Cfg:SetAttribute("Range", (C.RangePct + f.r) / 100 + (C.InfRange and 60 or 0))
	Cfg:SetAttribute("Gas", (C.GasPct + f.g) / 100)
	Cfg:SetAttribute("Dashes", C.Dashes + f.d)
	Cfg:SetAttribute("GearUncap", C.GearUncap)
	Cfg:SetAttribute("NoRagdoll", C.NoRagdoll)
	Cfg:SetAttribute("AutoEscape", C.AutoEscape)
	Cfg:SetAttribute("AutoChest", C.AutoChest)
	Cfg:SetAttribute("AutoRetry", C.AutoRetry)
	Cfg:SetAttribute("UpgTarget", C.UpgTarget)
	Cfg:SetAttribute("AutoUpgrade", C.AutoUpgrade)
	Cfg:SetAttribute("AutoClaim", C.AutoClaim)
	Cfg:SetAttribute("AutoFarm", C.AutoFarm)
	Cfg:SetAttribute("AutoStart", C.AutoStart)
	Cfg:SetAttribute("AutoPrestige", C.AutoPrestige)
	Cfg:SetAttribute("PrestigeBoost", C.PrestigeBoost)
	Cfg:SetAttribute("FarmMission", C.FarmMission)
	Cfg:SetAttribute("FarmPick", C.FarmPick)
	Cfg:SetAttribute("GoldSink", C.GoldSink)
	Cfg:SetAttribute("GoldReserve", C.GoldReserve)
	Cfg:SetAttribute("AutoBoost", C.AutoBoost)
	Cfg:SetAttribute("BoostXP", C.BoostXP)
	Cfg:SetAttribute("BoostGold", C.BoostGold)
	Cfg:SetAttribute("BoostLuck", C.BoostLuck)
	Cfg:SetAttribute("BoostGemReserve", C.BoostGemReserve)
	Cfg:SetAttribute("FarmMods", C.FarmMods)
	Cfg:SetAttribute("AutoBuild", C.AutoBuild)
	Cfg:SetAttribute("SpeedMode", C.SpeedMode)
	Cfg:SetAttribute("AutoQTE", C.AutoQTE)
	Cfg:SetAttribute("AutoSkip", C.AutoSkip)
	Cfg:SetAttribute("WebhookMin", C.WebhookMin)
	Cfg:SetAttribute("PremiumChest", C.PremiumChest)
	local skip = {}
	if not C.ModOddball then skip[#skip + 1] = "Oddball" end
	if not C.ModTimeTrial then skip[#skip + 1] = "Time Trial" end
	if not C.ModGlass then skip[#skip + 1] = "Glass Cannon" end
	Cfg:SetAttribute("SkipMods", table.concat(skip, ","))
	Cfg:SetAttribute("FarmMaxGrade", C.FarmMaxGrade)
end
pcall(function()
	if not isfile("aot_bench.json") then return end
	local plan = HS:JSONDecode(readfile("aot_bench.json"))
	if plan.active and plan.queue[plan.idx or 0] then
		local cur = plan.queue[plan.idx]
		C.SpeedMode = cur == "speed"
		C.FarmMods = cur ~= "speed"
		C.ModOddball = cur == "odd"
		C.ModGlass = true
	end
end)
syncCfg()

----------------------------------------------------------------- Remotes
local Remotes = game:GetService("ReplicatedStorage"):WaitForChild("Assets"):WaitForChild("Remotes")
local POST, GET = Remotes:WaitForChild("POST"), Remotes:WaitForChild("GET")
-- InvokeServer mit Timeout: haengt der Server, blockiert das nicht die Aura fuer immer
local function inv(timeout, ...)
	local args, done, res = table.pack(...), false, nil
	task.spawn(function()
		res = table.pack(pcall(GET.InvokeServer, GET, table.unpack(args, 1, args.n)))
		done = true
	end)
	local t0 = os.clock()
	while not done and os.clock() - t0 < timeout do task.wait() end
	if not done or not res[1] then return nil end
	return table.unpack(res, 2, res.n)
end

conn(POST.OnClientEvent:Connect(function(a, b, c)
	if a == "Effects" and b == "Sound" and c == "Hit_Kill" then S.kills = S.kills + 1 end
end))

----------------------------------------------------------------- Actor-Payload
local ACTOR_CODE = [==[
local CG = game:GetService("CoreGui")
local cfg = CG:WaitForChild("AOTHubCfg", 10)
if not cfg then return end
if _G.AOTA and _G.AOTA.Kill then pcall(_G.AOTA.Kill) end
local A = { on = true }
_G.AOTA = A
function A.Kill()
	A.on = false
	if A.restore then pcall(A.restore) end
end

local H
for _ = 1, 60 do
	for _, v in ipairs(getgc(true)) do
		if type(v) == "table" and rawget(v, "Prefix") == "rbxassetid://" and type(rawget(v, "Cache")) == "table" and type(rawget(v, "Modules")) == "table" then H = v break end
	end
	if H then break end
	task.wait(0.5)
end
if not H then return end
local M = H.Modules
local GET = game:GetService("ReplicatedStorage").Assets.Remotes.GET

-- Auto-Upgrade (Lobby): immer den niedrigsten Waffen-Stat hochziehen bis Ziel-Grade / Gold alle
local upgRunning = false
local function upgStatus(t)
	task.synchronize()
	cfg:SetAttribute("UpgStatus", t)
end
-- Farm-Helfer (Lobby + Mission)
local THR = { { "Easy", 0 }, { "Normal", 2 }, { "Hard", 5 }, { "Severe", 9 }, { "Aberrant", 12 } }
local COSTS = { 500, 1250, 2000, 3000, 5000, 7500, 11000, 17500, 25000, 37500, 50000, 70000, 100000, 135000, 169420 }
local HARD_MODS = { "No Perks", "No Skills", "No Memories", "Nightmare", "Oddball", "Injury Prone", "Chronic Injuries", "Fog", "Glass Cannon", "Time Trial" }
local ALL_MODS = { "No Perks", "No Skills", "No Memories", "Nightmare", "Oddball", "Injury Prone", "Chronic Injuries", "Fog", "Glass Cannon", "Time Trial", "Boring", "Simple" }
local function wantedMods()
	local w = {}
	-- Raids: Modifier geben LUCK (halber Wert); Simple/Boring = -20% Luck, Oddball bremst den Boss
	local fm = cfg:GetAttribute("FarmMission") or ""
	if workspace:GetAttribute("Type") == "Raids" or fm:find("Titan$") then
		for _, m in ipairs({ "No Perks", "No Skills", "No Memories", "Nightmare", "Injury Prone", "Chronic Injuries", "Fog", "Glass Cannon" }) do w[m] = true end
		return w
	end
	if cfg:GetAttribute("SpeedMode") then
		-- leichter machen + alles, was die Clear-Time nicht beeinflusst (Bonus ohne Nachteil)
		for _, m in ipairs({ "Simple", "Boring", "Time Trial", "Fog", "Injury Prone", "Chronic Injuries", "Glass Cannon" }) do w[m] = true end
		return w
	end
	if cfg:GetAttribute("FarmMods") then
		local skip = "," .. (cfg:GetAttribute("SkipMods") or "") .. ","
		for _, m in ipairs(HARD_MODS) do
			if not skip:find("," .. m .. ",", 1, true) then w[m] = true end
		end
	end
	return w
end
-- Modifier-Liste auf das Wunsch-Set bringen (toggle per Remote)
local function syncMods(getCur, remoteMod, fn)
	local w = wantedMods()
	local n = 0
	for _, m in ipairs(ALL_MODS) do
		task.synchronize()
		local cur = "," .. (getCur() or "") .. ","
		local has = cur:find("," .. m .. ",", 1, true) ~= nil
		if has ~= (w[m] == true) then
			pcall(function() GET:InvokeServer(remoteMod, fn, m) end)
			task.wait(0.15)
		end
		if w[m] then n = n + 1 end
	end
	return n
end

local function gradeOf(sl)
	local U = sl and sl.Upgrades and sl.Upgrades[sl.Weapon]
	if not U then return 0 end
	local sum, cnt = 0, 0
	for _, v in pairs(U) do sum = sum + v cnt = cnt + 1 end
	return math.floor(sum / math.max(cnt, 1))
end
local function costToGrade(sl, g)
	local U = sl.Upgrades[sl.Weapon]
	local lv, cnt, sum = {}, 0, 0
	for k, v in pairs(U) do lv[k] = v cnt = cnt + 1 sum = sum + v end
	local mult = sl.Weapon == "Spears" and 1.25 or 1
	local total = 0
	while math.floor(sum / math.max(cnt, 1)) < g do
		local low, l
		for k, v in pairs(lv) do if not l or v < l then low, l = k, v end end
		if not low or l >= #COSTS then return math.huge end
		total = total + math.ceil(math.floor(COSTS[l + 1]) * mult)
		lv[low] = l + 1
		sum = sum + 1
	end
	return total
end
local function nextThreshold(g)
	for _, t in ipairs(THR) do if t[2] > g then return t[2], t[1] end end
end
local RAID_THR = { { "Hard", 6 }, { "Severe", 10 }, { "Aberrant", 13 } }
local RAID_OBJ = { ["Female Titan"] = true, ["Attack Titan"] = true, ["Armored Titan"] = true, ["Colossal Titan"] = true }
local function bestDiff(g, raid)
	local d = raid and nil or "Easy"
	for _, t in ipairs(raid and RAID_THR or THR) do if t[2] <= g then d = t[1] end end
	return d
end
local function farmStatus(t)
	task.synchronize()
	cfg:SetAttribute("FarmStatus", t)
end

task.spawn(function()
	while A.on do
		pcall(function()
			task.synchronize()
			local d = H.Cache.Data
			local sl = d and d.Slots and d.Slots[d.Current_Slot]
			if sl and sl.Upgrades then
				local g = gradeOf(sl)
				local nt, nd = nextThreshold(g)
				cfg:SetAttribute("FarmGold", sl.Currency and sl.Currency.Gold or 0)
				-- Prestige-ETA: fehlende XP bis Level-Cap (100 + 25*P) mit vollem Balken (Balken je Level = Max_XP-Formel)
				local pr = sl.Progression
				if pr and pr.Level then
					local P = pr.Prestige or 0
					local m = 1 - P * 0.0023
					local cap = 100 + 25 * P
					local v, need = 0, 0
					for i = 1, cap do
						v = math.floor((v + math.floor((i + 9) / 10) * 100) * m)
						if i == pr.Level then need = need + math.max(v - (pr.XP or 0), 0) elseif i > pr.Level then need = need + v end
					end
					cfg:SetAttribute("PrestigeNeed", need)
					cfg:SetAttribute("PrestigeLevel", pr.Level)
					cfg:SetAttribute("PrestigeCap", cap)
					cfg:SetAttribute("PrestigeNext", P + 1)
				end
				cfg:SetAttribute("FarmGrade", g)
				if nt then
					cfg:SetAttribute("FarmNeed", costToGrade(sl, nt))
					cfg:SetAttribute("FarmNext", nd)
				else
					cfg:SetAttribute("FarmNeed", 0)
					cfg:SetAttribute("FarmNext", "MAX")
				end
			end
		end)
		task.wait(2)
	end
end)

local function upgradeLoop(targetOverride)
	if upgRunning then return end
	upgRunning = true
	task.synchronize()
	local target = targetOverride or cfg:GetAttribute("UpgTarget") or 2
	local n = 0
	while A.on do
		local d = H.Cache.Data
		local sl = d and d.Slots and d.Slots[d.Current_Slot]
		local U = sl and sl.Upgrades and sl.Upgrades[sl.Weapon]
		if not U then upgStatus("Keine Daten (nur in der Lobby)") break end
		local sum, cnt, low, lv = 0, 0, nil, nil
		for k, v in pairs(U) do
			sum = sum + v
			cnt = cnt + 1
			if not lv or v < lv then low, lv = k, v end
		end
		local grade = math.floor(sum / math.max(cnt, 1))
		if grade >= target then upgStatus("Ziel erreicht: Grade " .. grade .. " (" .. n .. " Upgrades)") break end
		local nd = GET:InvokeServer("S_Equipment", "Upgrade", { low })
		if type(nd) ~= "table" then upgStatus("Gold alle bei Grade " .. grade .. " (" .. sum .. "/" .. (target * cnt) .. " Level)") break end
		n = n + 1
		H.Cache.Data = nd
		task.spawn(pcall, M.Topbar.Refresh, H, nd)
		upgStatus("Upgrade " .. n .. ": " .. low .. " -> " .. (lv + 1))
		task.wait(0.35)
	end
	upgRunning = false
end
-- Gold-Sink: nach dem Ziel-Grade Restgold in die Schadens-Stats (bis 15) -> weniger Treffer pro Titan
-- (Gas/Speed/Range/Control bringen der Aura nichts; Grade-Schnitt steigt trotzdem -> ab 13 Aberrant-Raids)
local SINK_STATS = { "ODM_Damage", "Crit_Damage", "Crit_Chance", "Blade_Durability" }
local function sinkNext(sl)
	local U = sl and sl.Upgrades and sl.Upgrades[sl.Weapon]
	if not U then return nil end
	local mult = sl.Weapon == "Spears" and 1.25 or 1
	local best, bl
	for _, k in ipairs(SINK_STATS) do
		local l = U[k]
		if l and l < #COSTS and (not bl or l < bl) then best, bl = k, l end
	end
	if not best then return nil end
	return best, math.ceil(math.floor(COSTS[bl + 1]) * mult), bl
end
-- Gold fuer eine komplette Runde (jeder Schadens-Stat +1) -> lohnt den Lobby-Trip
local function sinkRoundCost(sl)
	local U = sl and sl.Upgrades and sl.Upgrades[sl.Weapon]
	if not U then return nil end
	local mult = sl.Weapon == "Spears" and 1.25 or 1
	local sum = 0
	for _, k in ipairs(SINK_STATS) do
		local l = U[k]
		if l and l < #COSTS then sum = sum + math.ceil(math.floor(COSTS[l + 1]) * mult) end
	end
	return sum > 0 and sum or nil
end
local function sinkUpgrades()
	task.synchronize()
	local reserve = cfg:GetAttribute("GoldReserve") or 0
	local n = 0
	while A.on do
		local d = H.Cache.Data
		local sl = d and d.Slots and d.Slots[d.Current_Slot]
		local stat, cost, lv = sinkNext(sl)
		if not stat then upgStatus("Gold-Sink: alle Schadens-Stats max") break end
		local gold = sl.Currency and sl.Currency.Gold or 0
		if gold - cost < reserve then upgStatus(string.format("Gold-Sink: %d Upgrades, naechstes %s %d (%d Gold)", n, stat, lv + 1, cost)) break end
		local nd = GET:InvokeServer("S_Equipment", "Upgrade", { stat })
		if type(nd) ~= "table" then upgStatus("Gold-Sink: Upgrade abgelehnt (" .. stat .. ")") break end
		n = n + 1
		H.Cache.Data = nd
		task.spawn(pcall, M.Topbar.Refresh, H, nd)
		upgStatus("Gold-Sink " .. n .. ": " .. stat .. " -> " .. (lv + 1))
		task.wait(0.35)
	end
	return n
end

-- Auto-Boost (Lobby): 2x XP/Gold/Luck aktiv halten. Restzeit = Players.<LP>.Boosts.<Typ> (Sekunden).
-- Erst eigene Boost-Items benutzen, sonst mit Gems kaufen (Shop "1_Boosts": 30m 4499 · 1h 7999 · 2h 13999 -> 2h am guenstigsten)
local BOOST_SHOP = { { "[2h]", 13999 }, { "[1h]", 7999 }, { "[30m]", 4499 } }
local function boostLeft(kind)
	local f = game.Players.LocalPlayer:FindFirstChild("Boosts")
	local v = f and f:FindFirstChild(kind)
	return v and tonumber(v.Value) or 0
end
-- naechster machbarer Schritt: "use" (Item vorhanden), "buy" (Gems reichen) oder nil
local function boostPlan(sl, kind)
	local items = sl and sl.Inventory and sl.Inventory.Items or {}
	for _, s in ipairs(BOOST_SHOP) do
		local tag = "2x " .. kind .. " Boost " .. s[1]
		if (items[tag] or 0) > 0 then return "use", tag end
	end
	local gems = sl and sl.Currency and sl.Currency.Gems or 0
	local reserve = cfg:GetAttribute("BoostGemReserve") or 0
	for _, s in ipairs(BOOST_SHOP) do
		if gems - s[2] >= reserve then return "buy", "2x " .. kind .. " Boost " .. s[1], s[2] end
	end
end
local function boostKinds()
	local k = {}
	for _, t in ipairs({ "XP", "Gold", "Luck" }) do if cfg:GetAttribute("Boost" .. t) then k[#k + 1] = t end end
	return k
end
local function autoBoostOne(kind)
	task.synchronize()
	if boostLeft(kind) > 120 then return end
	local d = H.Cache.Data
	local sl = d and d.Slots and d.Slots[d.Current_Slot]
	local act, tag = boostPlan(sl, kind)
	if not act then farmStatus("Auto-Boost: keine Items, Gems unter Reserve") return end
	if act == "buy" then
		local idx
		local Shop = M.Shop
		if type(Shop) ~= "table" then local okr, r = pcall(require, Shop) Shop = okr and r or nil end
		for i, e in ipairs(Shop and Shop["1_Boosts"] or {}) do if e.Tag == tag then idx = i end end
		if not idx then farmStatus("Auto-Boost: " .. tag .. " nicht im Shop") return end
		local nd = GET:InvokeServer("S_Market", "Buy", "1_Boosts", idx, 1)
		if type(nd) ~= "table" then farmStatus("Auto-Boost: Kauf abgelehnt") return end
		-- Antwort ist Slot-Daten (Inventory/Currency) oder komplette Daten (Slots)
		if nd.Slots then H.Cache.Data = nd elseif nd.Inventory and d and d.Slots then d.Slots[d.Current_Slot] = nd end
		task.wait(0.4)
	end
	local nd2 = GET:InvokeServer("S_Inventory", "Item", tag)
	task.synchronize()
	if type(nd2) == "table" then
		local dd = H.Cache.Data
		if dd and dd.Slots then dd.Slots[dd.Current_Slot] = nd2 end
		task.spawn(pcall, M.Topbar.Refresh, H, H.Cache.Data)
		farmStatus("Auto-Boost: " .. tag .. (act == "buy" and " gekauft + aktiviert" or " aktiviert"))
		pcall(writefile, "aot_lastboost.txt", tostring(os.time()))
	else
		farmStatus("Auto-Boost: Aktivieren abgelehnt (" .. tag .. ")")
	end
end
-- XP zuerst, dann Gold, dann Luck (Gems gehen in dieser Reihenfolge weg)
local function autoBoost()
	for _, kind in ipairs(boostKinds()) do pcall(autoBoostOne, kind) task.wait(0.3) end
end

-- Claim All (Lobby): Battlepass-Free, Quests, Achievements
local claimRunning = false
local function clmStatus(t)
	task.synchronize()
	cfg:SetAttribute("ClaimStatus", t)
end
local function claimAll()
	if claimRunning then return end
	claimRunning = true
	task.synchronize()
	local got = { bp = 0, q = 0, a = 0 }
	local function data() local d = H.Cache.Data return d, d and d.Slots and d.Slots[d.Current_Slot] end
	local _, sl = data()
	if not sl then clmStatus("Keine Daten (nur in der Lobby)") claimRunning = false return end
	clmStatus("Battlepass...")
	pcall(function()
		local bp, Pass = sl.Battlepass, M.Pass
		if bp and Pass and Pass.Items then
			local list = {}
			for i = 0, bp.Tier or 0 do
				if not (Pass.Items[i] == nil and (i <= 100 or (i - 100) % 3 ~= 0)) then
					for _, ty in ipairs({ "Free", "Paid" }) do
						if bp.Claimed[i .. "_" .. ty] == nil and (ty == "Free" or bp.Premium == true) then
							list[#list + 1] = { Tier = i, Type = ty }
						end
					end
				end
			end
			if #list > 0 then
				local nd = GET:InvokeServer("Functions", "Tier", list)
				if type(nd) == "table" then H.Cache.Data = nd got.bp = #list end
			end
		end
	end)
	clmStatus("Quests...")
	pcall(function()
		local _, sl2 = data()
		local amt = {}
		for _, grp in pairs(M.Quest or {}) do
			if type(grp) == "table" and grp.Quests then for _, q in pairs(grp.Quests) do amt[q.Tag] = q.Amount end end
		end
		for cat, qs in pairs(sl2.Quests or {}) do
			for _, q in pairs(qs) do
				local need = type(q) == "table" and (q.Amount or amt[q.Tag])
				if need and q.Tag and q.Rewarded ~= true and (q.Current or 0) >= need then
					task.synchronize()
					local nd = GET:InvokeServer("Functions", "Quest", q.Tag, cat)
					if type(nd) == "table" then H.Cache.Data = nd got.q = got.q + 1 end
					task.wait(0.15)
				end
			end
		end
	end)
	clmStatus("Achievements...")
	pcall(function()
		local _, sl3 = data()
		for id, t in pairs(sl3.Titles or {}) do
			if type(id) == "number" and id < 68 and type(t) == "table" and t.Owned ~= true then
				task.synchronize()
				local nd = GET:InvokeServer("S_Achievements", "Claim", id)
				if type(nd) == "table" then H.Cache.Data = nd got.a = got.a + 1 end
				task.wait(0.12)
			end
		end
	end)
	task.spawn(pcall, M.Topbar.Refresh, H, H.Cache.Data)
	clmStatus(string.format("Fertig: %d Battlepass, %d Quests, %d Achievements", got.bp, got.q, got.a))
	claimRunning = false
end
local lastClaim = cfg:GetAttribute("ClaimReq")
task.spawn(function()
	task.wait(4)
	task.synchronize()
	for _ = 1, 120 do if H.Cache.Data then break end task.wait(0.5) end
	task.synchronize()
	if cfg:GetAttribute("AutoClaim") and not workspace:FindFirstChild("Titans") then pcall(claimAll) end
	while A.on do
		task.wait(0.3)
		task.synchronize()
		local q = cfg:GetAttribute("ClaimReq")
		if q ~= lastClaim then
			lastClaim = q
			local ok, e = pcall(claimAll)
			if not ok then claimRunning = false pcall(clmStatus, "Fehler: " .. tostring(e)) end
		end
	end
end)

local lastReq = cfg:GetAttribute("UpgReq")
local function safeUpgrade()
	local ok, e = pcall(upgradeLoop)
	if not ok then upgRunning = false pcall(upgStatus, "Fehler: " .. tostring(e)) end
end
task.spawn(function()
	task.wait(3)
	task.synchronize()
	for _ = 1, 120 do if H.Cache.Data then break end task.wait(0.5) end
	task.synchronize()
	if cfg:GetAttribute("AutoUpgrade") and not workspace:FindFirstChild("Titans") then safeUpgrade() end
	while A.on do
		task.wait(0.3)
		task.synchronize()
		local q = cfg:GetAttribute("UpgReq")
		if q ~= lastReq then lastReq = q safeUpgrade() end
	end
end)

-- Auto-Build (Lobby): Skillpunkte ausgeben, Hotbar fuellen, Perk-Slots fuellen
local RAR = { Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5, Mythic = 6, Secret = 7 }
local HOTBAR_PREF = { "35", "95", "97", "76", "84", "26", "23", "14", "7", "93", "3", "40", "59", "68", "72", "91", "47" }
local function buildStatus(t)
	task.synchronize()
	cfg:SetAttribute("BuildStatus", t)
end
local function slotData()
	local d = H.Cache.Data
	return d and d.Slots and d.Slots[d.Current_Slot]
end
local function skillTag(id)
	local Sk = M.Skills
	local i = Sk and Sk[id]
	local t = i and i.Tag
	if not t and M.Skill and M.Skill.Info and M.Skill.Info[id] then t = M.Skill.Info[id].Tag end
	return t or ""
end
local function skillScore(id)
	local Sk = M.Skills
	local i = Sk and Sk[id]
	if not i then return -1 end
	local tag = skillTag(id)
	if i.Cooldown ~= nil then
		local pi = table.find(HOTBAR_PREF, id)
		return pi and (50 - pi) or 5
	end
	if tag:find("^Damage") then return 100 end
	if tag:find("Crit Chance") then return 95 end
	if tag:find("Crit Damage") then return 90 end
	if tag:find("Durability") then return 85 end
	if tag:find("Eye Gouge") then return 80 end
	if tag:find("Duration") then return 10 end
	return 20
end
local function autoBuild()
	task.synchronize()
	local Sk = M.Skills
	local sl = slotData()
	if not sl or not Sk then buildStatus("Keine Daten (nur in der Lobby)") return end
	local got = { sk = 0, hb = 0, pk = 0 }
	local errs = {}
	-- Diagnose ins Log
	pcall(function()
		local L = {}
		local nSk, sample = 0, nil
		for id, i in pairs(Sk) do nSk = nSk + 1 if not sample and type(i) == "table" then sample = id .. "{" .. (function() local t = {} for k, v in pairs(i) do t[#t + 1] = tostring(k) .. "=" .. tostring(v) end return table.concat(t, ",") end)() .. "}" end end
		L[#L + 1] = "Skills-Modul: " .. nSk .. " Eintraege, Beispiel " .. tostring(sample)
		L[#L + 1] = "SP: " .. tostring(select(2, pcall(M.Shared.Get_Skill_Points, H, H.Cache.Player)))
		L[#L + 1] = "Unlocked: " .. table.concat(sl.Skills.Unlocked or {}, ",") .. " | Hotbar: " .. table.concat(sl.Skills.Hotbar or {}, ",")
		local eq = {}
		for k, v in pairs(sl.Perks.Equipped or {}) do eq[#eq + 1] = tostring(k) .. "=" .. tostring(v) end
		L[#L + 1] = "Perks.Equipped: " .. table.concat(eq, ", ")
		local np, pex = 0, nil
		for id, pp in pairs(sl.Perks.Storage or {}) do np = np + 1 if not pex then pex = tostring(pp.Name) end end
		local npi = 0
		for rar, list in pairs(M.Perks or {}) do if type(list) == "table" then for _ in pairs(list) do npi = npi + 1 end end end
		L[#L + 1] = "Perks besessen: " .. np .. " (z.B. " .. tostring(pex) .. "), Perk-Infos: " .. npi .. ", Modul-Keys: " .. (function() local t = {} for k in pairs(M.Perks or {}) do t[#t + 1] = tostring(k) end return table.concat(t, ",") end)()
		writefile("aot_build_log.txt", os.date("%H:%M:%S") .. string.char(10) .. table.concat(L, string.char(10)) .. string.char(10))
	end)
	local function EH(e) errs[#errs + 1] = tostring(e) end
	-- 1) Skills freischalten
	xpcall(function()
		local unl = {}
		for _, v in ipairs(sl.Skills.Unlocked or {}) do unl[tostring(v)] = true end
		local cands = {}
		for id, i in pairs(Sk) do
			local n = tonumber(id)
			if n and n < 99 and type(i) == "table" and i.Skill_Cost and not unl[id] then cands[#cands + 1] = id end
		end
		table.sort(cands, function(a, b)
			local sa, sb = skillScore(a), skillScore(b)
			if sa ~= sb then return sa > sb end
			return (Sk[a].Skill_Cost or 0) < (Sk[b].Skill_Cost or 0)
		end)
		local sp = M.Shared.Get_Skill_Points(H, H.Cache.Player) or 0
		-- XP-Bonus-Build: mit No Perks/No Skills wirken Skills/Perks nicht, zaehlen aber als Bonus
		-- (+5% je ausgeruesteter Perk, +3% je Hotbar-Skill) -> SP dahin, wo es am meisten Bonus pro SP gibt
		local wm = wantedMods()
		if wm["No Perks"] or wm["No Skills"] then
			local V = M.Values
			if type(V) ~= "table" then local okv, rv = pcall(require, V) V = okv and rv or nil end
			local function chain(id)
				local list, cost, cur, g = {}, 0, tostring(id), 0
				while cur and Sk[cur] and g < 30 do
					g = g + 1
					if not unl[cur] then list[#list + 1] = cur cost = cost + (Sk[cur].Skill_Cost or 0) end
					cur = Sk[cur].Previous and tostring(Sk[cur].Previous)
				end
				return list, cost
			end
			local perkTypes = {}
			for _, pp in pairs(sl.Perks.Storage or {}) do
				for rar, lst in pairs(M.Perks or {}) do
					if type(lst) == "table" and lst[pp.Name] and lst[pp.Name].Type then perkTypes[lst[pp.Name].Type] = true end
				end
			end
			for _ = 1, 20 do
				local actives = 0
				for id in pairs(unl) do if Sk[id] and Sk[id].Cooldown ~= nil then actives = actives + 1 end end
				local bestL, bestC, bestR, bestTag
				local function consider(id, value, tag)
					local list, cost = chain(id)
					if #list > 0 and cost > 0 and cost <= sp and (not bestR or value / cost > bestR) then bestL, bestC, bestR, bestTag = list, cost, value / cost, tag end
				end
				if wm["No Perks"] and V and V.Slot_Indexes then
					for cat, id in pairs(V.Slot_Indexes) do
						if not unl[tostring(id)] and perkTypes[cat] then consider(id, 5, cat .. "-Perk-Slot") end
					end
				end
				if wm["No Skills"] and actives < 5 then
					for id, i in pairs(Sk) do
						if type(i) == "table" and i.Cooldown ~= nil and tonumber(id) and tonumber(id) < 99 and not unl[id] then consider(id, 3, skillTag(id)) end
					end
				end
				if not bestL then break end
				task.synchronize()
				local nd, nsp = GET:InvokeServer("S_Equipment", "Unlock", bestL)
				if type(nd) ~= "table" then errs[#errs + 1] = "XP-Build-Unlock abgelehnt (" .. tostring(bestTag) .. ")" break end
				H.Cache.Data = nd
				for _, x in ipairs(bestL) do unl[x] = true end
				got.sk = got.sk + #bestL
				sp = tonumber(nsp) or (sp - bestC)
				buildStatus("XP-Build: " .. tostring(bestTag) .. " (" .. sp .. " SP uebrig)")
				task.wait(0.2)
			end
		end
		-- Server lehnt ab -> nach 2 Fehlern abbrechen statt ~160x Invoke + 0.2s (kostete ~40s pro Lobby-Besuch)
		local fails = 0
		for _, id in ipairs(cands) do
			if fails >= 5 then errs[#errs + 1] = "Skill-Unlock abgelehnt" break end
			if not unl[id] then
				local list, cost, cur, guard = {}, 0, id, 0
				while cur and Sk[cur] and guard < 30 do
					guard = guard + 1
					if not unl[cur] then list[#list + 1] = cur cost = cost + (Sk[cur].Skill_Cost or 0) end
					cur = Sk[cur].Previous
				end
				if #list > 0 and cost <= sp then
					task.synchronize()
					local nd, nsp = GET:InvokeServer("S_Equipment", "Unlock", list)
					if type(nd) == "table" then
						H.Cache.Data = nd
						for _, x in ipairs(list) do unl[x] = true end
						got.sk = got.sk + #list
						sp = tonumber(nsp) or (sp - cost)
						buildStatus("Skill: " .. skillTag(id) .. " (" .. sp .. " SP uebrig)")
						fails = 0
					else
						fails = fails + 1
					end
					task.wait(0.2)
				end
			end
		end
	end, EH)
	-- 2) Hotbar fuellen
	xpcall(function()
		sl = slotData()
		local hb = sl.Skills.Hotbar
		local unl = {}
		for _, v in ipairs(sl.Skills.Unlocked or {}) do unl[tostring(v)] = true end
		local onBar = {}
		for _, v in pairs(hb) do if v ~= "" then onBar[tostring(v)] = true end end
		local pick = {}
		for _, id in ipairs(HOTBAR_PREF) do if unl[id] and not onBar[id] then pick[#pick + 1] = id end end
		for id in pairs(unl) do
			if Sk[id] and Sk[id].Cooldown ~= nil and not onBar[id] and not table.find(pick, id) and tonumber(id) and tonumber(id) < 99 then pick[#pick + 1] = id end
		end
		for slot = 1, 5 do
			if (hb[slot] == nil or hb[slot] == "") and #pick > 0 then
				local id = table.remove(pick, 1)
				task.synchronize()
				local nd = GET:InvokeServer("S_Equipment", "Skill_State", slot, id)
				if type(nd) == "table" then H.Cache.Data = nd got.hb = got.hb + 1 end
				task.wait(0.2)
				sl = slotData()
				hb = sl.Skills.Hotbar
			end
		end
	end, EH)
	-- 3) Perks ausruesten
	xpcall(function()
		sl = slotData()
		local info = {}
		for rar, list in pairs(M.Perks or {}) do
			if type(list) == "table" and RAR[rar] then
				for name, v in pairs(list) do if type(v) == "table" then info[name] = { type = v.Type, r = RAR[rar] } end end
			end
		end
		local eq = sl.Perks.Equipped
		local used = {}
		for _, v in pairs(eq) do if v ~= "" then used[v] = true end end
		local function best(cat, anyType)
			local bid, bs
			for id, p in pairs(sl.Perks.Storage) do
				local i = info[p.Name]
				if i and not used[id] and (anyType or i.type == cat) then
					local sc = i.r * 1000 + (p.Level or 0)
					if not bs or sc > bs then bid, bs = id, sc end
				end
			end
			return bid
		end
		local pfails = 0
		for _, cat in ipairs({ "Offense", "Defense", "Support", "Body", "Extra", "Family" }) do
			if pfails >= 2 then errs[#errs + 1] = "Perk-Equip abgelehnt" break end
			if eq[cat] == "" then
				local id = best(cat, false) or ((cat == "Extra" or cat == "Family") and best(cat, true))
				pcall(function() writefile("aot_build_log.txt", (isfile("aot_build_log.txt") and readfile("aot_build_log.txt") or "") .. "Perk " .. cat .. ": waehle " .. tostring(id) .. " (" .. tostring(id and sl.Perks.Storage[id] and sl.Perks.Storage[id].Name) .. ")" .. string.char(10)) end)
				if id then
					task.synchronize()
					local nd, n2, n3 = GET:InvokeServer("S_Equipment", "Perk_State", id, "Equip", cat)
					pcall(function() writefile("aot_build_log.txt", readfile("aot_build_log.txt") .. "  -> " .. type(nd) .. " / " .. tostring(n2) .. " / " .. tostring(n3) .. string.char(10)) end)
					if type(nd) == "table" then
						H.Cache.Data = nd
						used[id] = true
						got.pk = got.pk + 1
						sl = slotData()
						eq = sl.Perks.Equipped
					else
						pfails = pfails + 1
					end
					task.wait(0.2)
				end
			end
		end
	end, EH)
	-- 4) Artifacts: pro Slot das seltenste besessene
	xpcall(function()
		sl = slotData()
		local A = sl.Artifacts
		if not A or not A.Storage then return end
		local info = {}
		for rar, list in pairs(M.Artifacts or {}) do
			if type(list) == "table" and RAR[rar] then
				for name, v in pairs(list) do if type(v) == "table" and v.Slot then info[name] = { slot = v.Slot, r = RAR[rar] } end end
			end
		end
		local used = {}
		for _, v in pairs(A.Equipped or {}) do if type(v) == "table" and v.ID and v.ID ~= "" then used[v.ID] = true end end
		local bestBySlot = {}
		for id, a in pairs(A.Storage) do
			local i = info[a.Name]
			if i and not used[id] then
				local cur = bestBySlot[i.slot]
				if not cur or i.r > cur.r then bestBySlot[i.slot] = { id = id, r = i.r } end
			end
		end
		for slot, b in pairs(bestBySlot) do
			local e = A.Equipped[slot]
			if e == nil or e.ID == nil or e.ID == "" then
				task.synchronize()
				local nd = GET:InvokeServer("S_Equipment", "Artifact_State", b.id, "Equip", slot)
				if type(nd) == "table" then H.Cache.Data = nd got.pk = got.pk + 1 end
				task.wait(0.2)
			end
		end
	end, EH)
	task.spawn(pcall, M.Topbar.Refresh, H, H.Cache.Data)
	buildStatus(string.format("Fertig: %d Skills, %d Hotbar, %d Perks/Artifacts", got.sk, got.hb, got.pk) .. (#errs > 0 and (" | Fehler: " .. table.concat(errs, " / ")) or ""))
end
local lastBuild = cfg:GetAttribute("BuildReq")
task.spawn(function()
	while A.on do
		task.wait(0.3)
		task.synchronize()
		local q = cfg:GetAttribute("BuildReq")
		if q ~= lastBuild and not workspace:FindFirstChild("Titans") then
			lastBuild = q
			local ok, e = pcall(autoBuild)
			if not ok then pcall(buildStatus, "Fehler: " .. tostring(e)) end
		end
	end
end)

-- Auto-QTE (Raid-Cutscenes): Fehlschlag-Callback neutralisieren, Erfolg nach kurzer Zeit melden
pcall(function()
	local RD = M.Raids
	if not RD or not RD.QTE or RD.__aotQTE then return end
	local orig = RD.QTE
	RD.__aotQTE = orig
	RD.QTE = function(h, ui, timing, pos, key, ckey, failCb, okCb, ...)
		if not cfg:GetAttribute("AutoQTE") then return orig(h, ui, timing, pos, key, ckey, failCb, okCb, ...) end
		local done = false
		local function ok() if not done then done = true if okCb then okCb() end end end
		local function noFail() end
		local r = orig(h, ui, timing, pos, key, ckey, noFail, ok, ...)
		task.delay(0.25 + math.random() * 0.15, function() task.synchronize() ok() end)
		return r
	end
end)

-- Auto-Skip Cutscenes (Raids): sobald Skip erlaubt ist
pcall(function()
	local RD = M.Raids
	if not RD or not RD.Can_Skip then return end
	local function trySkip()
		if A.on and cfg:GetAttribute("AutoSkip") and RD.Can_Skip.Value == true then
			task.delay(0.3, function() task.synchronize() pcall(RD.Skip, H) end)
		end
	end
	RD.Can_Skip:GetPropertyChangedSignal("Value"):Connect(trySkip)
	trySkip()
end)

-- Auto-Prestige (Lobby): Boost waehlen (Luck/XP/Gold), ersten Talent nehmen, prestigen
local function plog(t)
	pcall(function() writefile("aot_prestige_log.txt", (isfile("aot_prestige_log.txt") and readfile("aot_prestige_log.txt") or "") .. os.date("%H:%M:%S ") .. t .. string.char(10)) end)
end
local function xpFor(l, pres)
	local m = 1 - pres * 0.0023
	local v = 0
	for i = 1, l do v = math.floor((v + math.floor((i + 9) / 10) * 100) * m) end
	return v
end
local function prestigeReady(sl)
	local pr = sl and sl.Progression
	if not pr then return false end
	local P = pr.Prestige or 0
	local cap = 100 + 25 * P
	-- Level-Cap erreicht UND XP-Balken voll (Server-Bedingung)
	return (pr.Level or 0) >= cap and (pr.XP or 0) >= xpFor(cap, P), pr
end
local function doPrestige()
	task.synchronize()
	local d = H.Cache.Data
	local sl = d and d.Slots and d.Slots[d.Current_Slot]
	local ready, pr = prestigeReady(sl)
	if not ready then return false end
	farmStatus("Prestige " .. tostring((pr.Prestige or 0) + 1) .. "...")
	local want = cfg:GetAttribute("PrestigeBoost") or "Luck"
	local bname, dump = nil, {}
	local Mem = M.Memories
	for k, v in pairs((Mem and Mem.Boosts) or {}) do
		local txt = tostring(k)
		if type(v) == "table" then
			for a, b in pairs(v) do txt = txt .. " " .. tostring(a) .. "=" .. tostring(b) end
		end
		dump[#dump + 1] = txt
		if txt:find(want) then bname = type(v) == "table" and v.Tag or tostring(k) end
	end
	plog("Boosts: " .. table.concat(dump, " | ") .. " -> gewaehlt " .. tostring(bname))
	bname = bname or "Luck Boost"
	-- schon generierte Talente liegen in den Daten (Next_Talents); sonst neu anfordern
	local nd, talents, scrolls
	local _, fresh = pcall(function() return select(2, M.Update.Get_Data(H, true)) end)
	local src = (type(fresh) == "table" and fresh) or sl
	if type(src.Next_Talents) == "table" then
		talents = src.Next_Talents
	else
		nd, talents, scrolls = GET:InvokeServer("S_Equipment", "Talents")
		if type(talents) ~= "table" then
			local _, f2 = pcall(function() return select(2, M.Update.Get_Data(H, true)) end)
			if type(f2) == "table" and type(f2.Next_Talents) == "table" then talents = f2.Next_Talents end
		end
	end
	local tname
	if type(talents) == "table" then
		local tl = {}
		-- Auswahl = Tag des Talents; ID ueber Memories.Talents[Raritaet][id] aufloesen, meiste Sterne nehmen
		local bestStars = -1
		for k, v in pairs(talents) do
			local info
			for _, rt in pairs((Mem and Mem.Talents) or {}) do
				if type(rt) == "table" and (rt[v] or rt[tostring(v)] or rt[tonumber(v) or -1]) then info = rt[v] or rt[tostring(v)] or rt[tonumber(v)] break end
			end
			tl[#tl + 1] = tostring(k) .. "=" .. tostring(v) .. "(" .. tostring(info and info.Tag) .. "," .. tostring(info and info.Stars) .. ")"
			if info and info.Tag and (info.Stars or 0) > bestStars then bestStars = info.Stars or 0 tname = info.Tag end
		end
		plog("Talents: " .. table.concat(tl, ", "))
	else
		plog("Talents-Antwort: " .. tostring(nd) .. " / " .. tostring(talents))
	end
	task.wait(0.5)
	local a, b, c = GET:InvokeServer("S_Equipment", "Prestige", { Boosts = bname, Talents = tname })
	plog("Prestige(" .. tostring(bname) .. ", " .. tostring(tname) .. ") -> " .. tostring(a) .. " / " .. tostring(b) .. " / " .. tostring(c))
	if type(a) == "table" then
		H.Cache.Data = a
		farmStatus("Prestige geschafft!")
		return true
	end
	farmStatus("Prestige abgelehnt (siehe aot_prestige_log.txt)")
	return false
end

-- Missionswahl (Lobby): Live-Multiplikatoren aus dem Rewards-Modul (Map + Reward-Boost der Bonus-Map)
local function modReq(m)
	if type(m) == "table" then return m end
	local ok, r = pcall(require, m)
	return ok and type(r) == "table" and r or nil
end
local function pickMission(mode, g)
	local R, O = modReq(M.Rewards), modReq(M.Objectives)
	local boosted = workspace:GetAttribute("Boosted_Map")
	if mode == "Bonus-Map" then
		return boosted and (boosted .. " · Skirmish") or nil
	end
	if not O then return nil end
	local mm = (R and R.Map_Multipliers) or {}
	local bm = (R and R.Boost_Multipliers and R.Boost_Multipliers.Gold) or 25
	local gu = modReq(M.Gear_Up)
	-- aktiver Gold-Gear-Up verdoppelt den Bonus-Map-Boost (wie in der Rewards-Vorschau)
	if gu and gu.Multipliers and gu.Multipliers.Gold and (gu.Multipliers.Gold.Time or 0) > 0 then bm = bm * 2 end
	local best, bs
	if mode == "Beste Mission" then
		for map, objs in pairs(O.Missions or {}) do
			if type(objs) == "table" and table.find(objs, "Skirmish") then
				local s = (mm[map] or 0) + (map == boosted and bm or 0)
				if not bs or s > bs then best, bs = map .. " · Skirmish", s end
			end
		end
	elseif mode == "Bester Raid" then
		if not bestDiff(g, true) then return nil end
		for map, objs in pairs(O.Raids or {}) do
			for _, ob in ipairs(type(objs) == "table" and objs or {}) do
				-- Colossal braucht min. 3 Spieler (+ Prestige 2) -> solo nicht startbar
				-- Armored: Schild blockt Klingen-Treffer, Boss blieb 100/100 bis alle Refills weg waren (gemessen 2x)
				if ob ~= "Colossal Titan" and ob ~= "Armored Titan" then
					local s = mm[map] or 0
					if not bs or s > bs then best, bs = map .. " · " .. ob, s end
				end
			end
		end
	end
	return best
end

-- Auto-Farm (Lobby): upgraden -> hoechste Schwierigkeit + harte Modifier -> starten
local farmRunning = false
local function startFarm()
	if farmRunning then return end
	farmRunning = true
	task.synchronize()
	for _ = 1, 120 do if H.Cache.Data then break end task.wait(0.5) end
	task.synchronize()
	while upgRunning do task.wait(0.5) end
	if cfg:GetAttribute("AutoPrestige") then
		local d0 = H.Cache.Data
		local sl0 = d0 and d0.Slots and d0.Slots[d0.Current_Slot]
		if prestigeReady(sl0) then
			local okp, done = pcall(doPrestige)
			if not (okp and done) then
				farmStatus("Prestige fehlgeschlagen -> bleibe in Lobby (aot_prestige_log.txt)")
				farmRunning = false
				return
			end
			task.wait(2)
		end
	end
	if cfg:GetAttribute("AutoBoost") then pcall(autoBoost) end
	farmStatus("Upgrade...")
	pcall(upgradeLoop, cfg:GetAttribute("FarmMaxGrade") or 12)
	-- Build NACH den Upgrades: Skills kosten Gold (1850 * 1.063^n), die Schwierigkeit bringt aber viel mehr XP
	-- (Aberrant-Abschluss 7025 XP vs. Easy 337) -> erst Grade, dann XP-Bonus-Build, dann Gold-Sink
	if cfg:GetAttribute("AutoBuild") then
		farmStatus("Skills/Perks...")
		pcall(autoBuild)
	end
	if cfg:GetAttribute("GoldSink") then
		farmStatus("Gold-Sink (Schaden)...")
		pcall(sinkUpgrades)
	end
	task.synchronize()
	local d = H.Cache.Data
	local sl = d and d.Slots and d.Slots[d.Current_Slot]
	local g = gradeOf(sl)
	local pickMode = cfg:GetAttribute("FarmPick") or "Fest"
	if pickMode ~= "Fest" then
		local okp, pm = pcall(pickMission, pickMode, g)
		task.synchronize()
		if okp and pm then
			cfg:SetAttribute("FarmMission", pm)
			pcall(writefile, "aot_lastpick.txt", tostring(os.time()))
		else
			farmStatus(pickMode .. ": nichts gefunden (" .. tostring(pm) .. ") -> feste Mission")
			task.wait(1)
		end
	end
	local mission = cfg:GetAttribute("FarmMission") or "Shiganshina · Skirmish"
	local map, obj = mission:match("^(.-) · (.+)$")
	map, obj = map or "Shiganshina", obj or "Skirmish"
	local raid = RAID_OBJ[obj] == true
	local diff = bestDiff(g, raid)
	local minimum = nil
	if raid and obj == "Colossal Titan" then minimum = 3 diff = (g >= 13) and "Aberrant" or nil end
	if not diff then farmStatus("Grade " .. g .. " zu niedrig fuer diesen Raid") farmRunning = false return end
	farmStatus("Erstelle " .. map .. " " .. obj .. " auf " .. diff .. " (Grade " .. g .. ")")
	pcall(function() GET:InvokeServer("S_Missions", "Leave") end)
	task.wait(0.5)
	local o = GET:InvokeServer("S_Missions", "Create", { Name = map, Difficulty = diff, Type = raid and "Raids" or "Missions", Objective = obj, Minimum = minimum })
	if typeof(o) ~= "Instance" then farmStatus("Create abgelehnt (" .. diff .. ")") farmRunning = false return end
	local nm = syncMods(function() return o:GetAttribute("Modifiers") end, "S_Missions", "Modify")
	farmStatus("Starte " .. diff .. " mit " .. nm .. " Modifiern...")
	task.wait(0.5)
	pcall(function() GET:InvokeServer("S_Missions", "Start") end)
	farmRunning = false
end
local lastFarm = cfg:GetAttribute("FarmReq")
task.spawn(function()
	task.wait(5)
	task.synchronize()
	if cfg:GetAttribute("AutoStart") and not workspace:FindFirstChild("Titans") then pcall(startFarm) end
	while A.on do
		task.wait(0.3)
		task.synchronize()
		local q = cfg:GetAttribute("FarmReq")
		if q ~= lastFarm and not workspace:FindFirstChild("Titans") then
			lastFarm = q
			local ok, e = pcall(startFarm)
			if not ok then farmRunning = false pcall(farmStatus, "Fehler: " .. tostring(e)) end
		end
	end
end)

local RT, T = M.Runtime, M.Titans
if not RT or not T then return end
local ap = { s = 0, c = 0, r = 0, g = 0, d = 0 }
local gearOrig = RT.Gear_Shift

-- Anti-Ragdoll: Fall-Ragdoll-Meldung des Clients wird verworfen
local baseSend = getmetatable(H).Send
rawset(H, "Send", function(self, a, b, ...)
	if a == "Functions" and b == "Ragdoll" and cfg:GetAttribute("NoRagdoll") then return end
	return baseSend(self, a, b, ...)
end)

-- Auto-Grab-Escape: spielt den QTE mit menschlichem Tempo ueber die spieleigene Funktion
local origGrab = T.Grab_Event
T.Grab_Event = function(h, mode, ...)
	local r = origGrab(h, mode, ...)
	if mode == "Start" and cfg:GetAttribute("AutoEscape") then
		task.spawn(function()
			task.wait(0.15)
			if T.Initiated == false then
				pcall(function() GET:InvokeServer("Blades", "Reload") end)
				task.wait(0.1)
				local B = h.Cache.Interface:FindFirstChild("Buttons")
				if B and T.Initiated == false and T.Finished == false then
					T.Initiated = true
					T.Create(h, B, T.Grabbing.Key)
				end
			end
			for _ = 1, 40 do
				if not A.on or T.Initiated ~= true then break end
				task.wait(0.09 + math.random() * 0.07)
				if T.Initiated ~= true then break end
				pcall(origGrab, h, "Update", true)
			end
		end)
	end
	return r
end

local function apply()
	local L = H.Loadout
	if not L or not L.Stats then return end
	local X, St = RT.Extra_Stats, L.Stats
	local s = cfg:GetAttribute("Speed") or 0
	local c = (cfg:GetAttribute("Control") or 0) * (St.ODM_Control or 100)
	local r = cfg:GetAttribute("Range") or 0
	local gs = cfg:GetAttribute("Gas") or 0
	local d = cfg:GetAttribute("Dashes") or 0
	if s ~= ap.s then X.ODM_Speed = X.ODM_Speed + s - ap.s ap.s = s end
	if c ~= ap.c then X.ODM_Control = X.ODM_Control + c - ap.c ap.c = c end
	if r ~= ap.r then X.ODM_Range = X.ODM_Range + r - ap.r ap.r = r end
	if gs ~= ap.g then
		X.ODM_Gas = X.ODM_Gas + gs - ap.g ap.g = gs
		if St.Base_ODM_Gas then St.Maximum_ODM_Gas = math.ceil(St.Base_ODM_Gas * X.ODM_Gas + 0.5) end
	end
	if d ~= ap.d then St.Boost_Dashes = (St.Boost_Dashes or 0) + d - ap.d ap.d = d end
	-- Server nimmt pro Slash nur Stats.Strike Treffer an (No Perks/No Skills -> 1); Main-VM schickt nicht mehr
	if St.Strike and St.Strike ~= ap.strike then
		ap.strike = St.Strike
		task.synchronize()
		cfg:SetAttribute("Strike", St.Strike)
	end
	if cfg:GetAttribute("InfGas") and St.Maximum_ODM_Gas then St.ODM_Gas = St.Maximum_ODM_Gas end
	if cfg:GetAttribute("GearUncap") then
		if RT.Gear_Shift < 100000 then gearOrig = RT.Gear_Shift RT.Gear_Shift = 100000 end
	elseif RT.Gear_Shift >= 100000 then
		RT.Gear_Shift = gearOrig
	end
end

local function restore()
	local L = H.Loadout
	local X = RT.Extra_Stats
	X.ODM_Speed = X.ODM_Speed - ap.s
	X.ODM_Control = X.ODM_Control - ap.c
	X.ODM_Range = X.ODM_Range - ap.r
	X.ODM_Gas = X.ODM_Gas - ap.g
	if L and L.Stats then
		L.Stats.Boost_Dashes = (L.Stats.Boost_Dashes or 0) - ap.d
		if L.Stats.Base_ODM_Gas then L.Stats.Maximum_ODM_Gas = math.ceil(L.Stats.Base_ODM_Gas * X.ODM_Gas + 0.5) end
	end
	ap = { s = 0, c = 0, r = 0, g = 0, d = 0 }
	if RT.Gear_Shift >= 100000 then RT.Gear_Shift = gearOrig end
	rawset(H, "Send", nil)
	T.Grab_Event = origGrab
end

local hb = game:GetService("RunService").Heartbeat:Connect(function()
	if not A.on then return end
	if cfg:GetAttribute("Shutdown") then A.Kill() return end
	pcall(apply)
end)

-- Missionsende: Free-Chest + Retry
local endDone = false
S_lastChest = nil
task.spawn(function()
	while A.on do
		task.wait(0.25)
		local R = M.Rewards
		local CH = M.Chests
		local ended
		if workspace:GetAttribute("Type") == "Raids" then
			-- Raids: nur die echte Truhen-Szene zaehlt (Rewards.State wechselt im Raid auch zwischendurch)
			ended = (workspace:FindFirstChild("Chest_End") ~= nil and workspace:GetAttribute("Rewarded") == true)
				-- fehlgeschlagen (Ziel verloren): Server setzt Force_End -> sonst haengt der Farm hier fuer immer
				or workspace:GetAttribute("Force_End") == true
		else
			ended = R and R.State ~= nil and R.State ~= "Out"
		end
		if ended then
			if not endDone then
				endDone = true
				task.wait((cfg:GetAttribute("SpeedMode") or workspace:GetAttribute("Type") ~= "Raids") and 0.4 or 2.5)
				local farm = cfg:GetAttribute("AutoFarm")
				local slot, rinfo
				if cfg:GetAttribute("AutoChest") or farm then
					for _ = 1, 20 do
						local ok, a, b = pcall(function() return GET:InvokeServer("S_Rewards", "Get") end)
						if ok and a ~= nil and b ~= nil then slot = b rinfo = a break end
						task.wait(0.25)
					end
					if workspace:GetAttribute("Type") == "Raids" then task.wait(0.5) end
					-- Truhen gibt es nur in Raids (Missionen geben Drops direkt in den Rewards)
					if workspace:GetAttribute("Type") == "Raids" then pcall(function()
						local items, extra, tries = nil, nil, 0
						repeat
							tries = tries + 1
							items, extra = GET:InvokeServer("S_Rewards", "Chest", "Free")
							if items == nil then task.wait(1) end
						until items ~= nil or tries >= 3
						S_lastChest = {}
						if type(items) == "table" then for _, it in ipairs(items) do if type(it) == "table" then S_lastChest[#S_lastChest + 1] = it end end end
						if cfg:GetAttribute("PremiumChest") then -- war "or true": oeffnete immer die Premium-Truhe und verbrauchte Emperor's Keys
							task.wait(0.5)
							local pi = GET:InvokeServer("S_Rewards", "Chest", "Premium")
							if type(pi) == "table" then for _, it in ipairs(pi) do if type(it) == "table" then S_lastChest[#S_lastChest + 1] = it end end end
							if pi ~= nil then items = { Free = items, Premium = pi } end
						end
						local function dump(v, d)
							d = d or 0
							if type(v) ~= "table" or d > 2 then return tostring(v) end
							local t = {}
							for k, x in pairs(v) do if #t < 12 then t[#t + 1] = tostring(k) .. "=" .. dump(x, d + 1) end end
							return "{" .. table.concat(t, ",") .. "}"
						end
						pcall(function(x) writefile("aot_chest_log.txt", (isfile("aot_chest_log.txt") and readfile("aot_chest_log.txt") or "") .. x) end, os.date("%H:%M:%S") .. " Chest (Versuch " .. tostring(tries) .. ") -> " .. dump(items) .. " | 2nd=" .. type(extra) .. " | Stat=" .. tostring(game.Players.LocalPlayer:GetAttribute("Stat")) .. string.char(10))
						local txt = "leer/abgelehnt"
						if type(items) == "table" and #items > 0 then
							local t = {}
							for _, it in ipairs(items) do
								if type(it) == "table" then
									t[#t + 1] = tostring(it.Name or it.Item or it[1] or "?") .. (it.Amount and (" x" .. tostring(it.Amount)) or "")
								else
									t[#t + 1] = tostring(it)
								end
							end
							txt = table.concat(t, ", ")
						end
						task.synchronize()
						local log = cfg:GetAttribute("ChestLog") or ""
						log = (os.date("%H:%M") .. " " .. txt .. " || " .. log):sub(1, 600)
						cfg:SetAttribute("ChestLog", log)
						cfg:SetAttribute("ChestCount", (cfg:GetAttribute("ChestCount") or 0) + 1)
					end) end
					-- Drops dieser Runde (Items aus den Rewards) ins Log
					pcall(function()
						local ob = rinfo and rinfo.Obtained
						if type(ob) ~= "table" then return end
						local t = {}
						for cat, v in pairs(ob) do
							if type(v) == "table" then
								for k, x in pairs(v) do t[#t + 1] = tostring(cat) .. ":" .. (type(k) == "number" and tostring(x) or (tostring(k) .. "=" .. tostring(x))) end
							elseif cat ~= "Gold" and cat ~= "XP" and cat ~= "BP_XP" and type(v) == "number" and v > 0 then
								t[#t + 1] = tostring(cat) .. "=" .. tostring(v)
							end
						end
						if #t > 0 then
							local line = os.date("%H:%M:%S") .. " Drops: " .. table.concat(t, ", ") .. string.char(10)
							writefile("aot_drops_log.txt", (isfile("aot_drops_log.txt") and readfile("aot_drops_log.txt") or "") .. line)
						end
					end)
					task.wait((cfg:GetAttribute("SpeedMode") or workspace:GetAttribute("Type") ~= "Raids") and 0.2 or 1)
				end
				-- Benchmark: Runde loggen, naechste Konfiguration setzen
				pcall(function()
					if not isfile("aot_bench.json") then return end
					local HS = game:GetService("HttpService")
					local plan = HS:JSONDecode(readfile("aot_bench.json"))
					if not plan.active then return end
					local function flat(t, pre, out)
						for k, v in pairs(t or {}) do
							if type(v) == "number" then out[pre .. tostring(k)] = v
							elseif type(v) == "table" then flat(v, pre .. tostring(k) .. ".", out) end
						end
						return out
					end
					if plan.applied then
						plan.log = plan.log or {}
						table.insert(plan.log, {
							cfg = plan.applied, t = os.time(), sec = workspace:GetAttribute("Seconds"),
							mods = workspace:GetAttribute("Modifiers"), done = rinfo and rinfo.Completed,
							got = flat(rinfo and rinfo.Obtained, "", {}), stats = flat(rinfo and rinfo.Stats, "", {}),
							gold = slot and slot.Currency and slot.Currency.Gold,
							lvl = slot and slot.Progression and slot.Progression.Level,
							xp = slot and slot.Progression and slot.Progression.XP,
						})
					else
						plan.tStart = os.time()
					end
					plan.idx = (plan.idx or 0) + 1
					local nxt = plan.queue[plan.idx]
					if nxt then
						plan.applied = nxt
						cfg:SetAttribute("SpeedMode", nxt == "speed")
						cfg:SetAttribute("FarmMods", nxt ~= "speed")
						cfg:SetAttribute("SkipMods", nxt == "odd" and "" or "Oddball")
					else
						plan.active = false
						plan.applied = nil
					end
					writefile("aot_bench.json", HS:JSONEncode(plan))
					farmStatus("Bench: Runde " .. tostring(#(plan.log or {})) .. "/" .. #plan.queue .. " · naechste: " .. tostring(nxt or "fertig"))
				end)
				-- Drop-Meldung an Main-VM (Webhook)
				pcall(function()
					local RANKS = { Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5, Mythic = 6, Secret = 7, Exclusive = 8 }
					local minR = RANKS[cfg:GetAttribute("WebhookMin") or "Legendary"] or 5
					local found = {}
					local function add(name, rar, src)
						name = tostring(name)
						if not rar and M.Items and type(M.Items[name]) == "table" then rar = M.Items[name].Rarity end
						if not rar and M.Perks then
							for rr, list in pairs(M.Perks) do if type(list) == "table" and list[name] then rar = rr break end end
						end
						if not rar and M.Artifacts then
							for rr, list in pairs(M.Artifacts) do if type(list) == "table" and list[name] then rar = rr break end end
						end
						rar = rar or (M.Shared and M.Shared.Get_Rarity and select(2, pcall(M.Shared.Get_Rarity, H, name))) or "?"
						if type(rar) ~= "string" then rar = "?" end
						local rare = (RANKS[rar] or 0) >= minR or name:find("Serum") ~= nil or name:find("Key") ~= nil
						found[#found + 1] = { name = name, rarity = rar, src = src, rare = rare }
					end
					local ob = rinfo and rinfo.Obtained
					if type(ob) == "table" then
						for cat, v in pairs(ob) do
							if type(v) == "table" then
								for k, x in pairs(v) do
									if type(k) == "number" then add(type(x) == "table" and (x.Name or x.Tag) or x, type(x) == "table" and x.Rarity or nil, "Drop:" .. tostring(cat))
									else add(k, nil, "Drop:" .. tostring(cat)) end
								end
							end
						end
					end
					for _, it in ipairs(S_lastChest or {}) do add(it.Tag or it.Name, it.Rarity, "Truhe") end
					pcall(function()
						local keys = {}
						if type(rinfo) == "table" then for k, v in pairs(rinfo) do keys[#keys + 1] = tostring(k) .. ":" .. type(v) end end
						local obk = {}
						if type(ob) == "table" then for k, v in pairs(ob) do obk[#obk + 1] = tostring(k) .. ":" .. type(v) .. (type(v) == "table" and ("#" .. tostring(#v)) or "") end end
						writefile("aot_dropdbg.txt", (isfile("aot_dropdbg.txt") and readfile("aot_dropdbg.txt") or "") .. os.date("%H:%M:%S") .. " type=" .. tostring(workspace:GetAttribute("Type")) .. " rinfo=" .. type(rinfo) .. " {" .. table.concat(keys, ",") .. "} Obtained{" .. table.concat(obk, ",") .. "} chest#=" .. tostring(S_lastChest and #S_lastChest) .. " found#=" .. #found .. string.char(10))
					end)
					S_lastChest = nil
					local gold, xp = 0, 0
					if type(ob) == "table" then gold = tonumber(ob.Gold) or 0 xp = tonumber(ob.XP) or 0 end
					task.synchronize()
					cfg:SetAttribute("DropEvent", game:GetService("HttpService"):JSONEncode({
						items = found, map = workspace:GetAttribute("Objective"), diff = workspace:GetAttribute("Difficulty"),
						type = workspace:GetAttribute("Type"), t = os.time(), sec = workspace:GetAttribute("Seconds"), gold = gold, xp = xp,
					}))
				end)
				-- Speed: trotzdem in die Lobby, wenn das Gold fuer die naechste Schwierigkeit reicht
				local upNow = false
				-- Raid verloren: 1x Retry, nach 2 Fehlschlaegen in Folge zurueck auf die beste Mission
				if workspace:GetAttribute("Type") == "Raids" then
					local failed = workspace:FindFirstChild("Chest_End") == nil and workspace:GetAttribute("Force_End") == true
					local okf, nf = pcall(function() return tonumber(readfile("aot_raidfail.txt")) end)
					nf = failed and ((okf and nf or 0) + 1) or 0
					pcall(writefile, "aot_raidfail.txt", tostring(nf))
					if failed and farm and nf >= 2 then
						task.synchronize()
						cfg:SetAttribute("FarmPick", "Beste Mission")
						pcall(writefile, "aot_raidfail.txt", "0")
						upNow = "Raid 2x verloren -> Beste Mission"
					elseif failed then
						farmStatus("Raid verloren (" .. nf .. "/2) -> Retry")
					end
				end
				if farm and type(slot) == "table" then
					if cfg:GetAttribute("AutoPrestige") and prestigeReady(slot) then upNow = "Prestige" end
					local fm = cfg:GetAttribute("FarmMission") or ""
					local fobj = fm:match(" · (.+)$")
					if fobj and workspace:GetAttribute("Objective") and fobj ~= workspace:GetAttribute("Objective") then upNow = "Missionswechsel" end
					-- Bonus-Map ist weitergewandert -> in der Lobby neu waehlen (max. alle 5 Min, falls "Boosted" mal anders gemeint ist)
					local pm = cfg:GetAttribute("FarmPick") or "Fest"
					-- Modus passt nicht zum aktuellen Typ (z.B. Raid laeuft, gewaehlt ist Mission) -> zur Lobby neu waehlen
					local wantRaid = pm == "Bester Raid"
					if pm ~= "Fest" and wantRaid ~= (workspace:GetAttribute("Type") == "Raids") then upNow = "Missionswahl: " .. pm end
					if (pm == "Bonus-Map" or pm == "Beste Mission") and workspace:GetAttribute("Type") == "Missions" and workspace:GetAttribute("Boosted") == false then
						local okl, lp = pcall(function() return tonumber(readfile("aot_lastpick.txt")) end)
						if not (okl and lp) or os.time() - lp > 300 then upNow = "Bonus-Map gewechselt" end
					end
					-- Gold-Sink: erst zur Lobby, wenn jeder Schadens-Stat +1 bezahlbar ist (Lobby-Trip kostet ~1 Min)
					if not upNow and cfg:GetAttribute("GoldSink") and gradeOf(slot) >= (cfg:GetAttribute("FarmMaxGrade") or 12) then
						local need = sinkRoundCost(slot)
						if need and (slot.Currency and slot.Currency.Gold or 0) - need >= (cfg:GetAttribute("GoldReserve") or 0) then upNow = "Schadens-Upgrades" end
					end
					-- Boost abgelaufen und Item/Gems da -> Lobby (nur wenn der Timer lesbar ist, max. alle 5 Min)
					if not upNow and cfg:GetAttribute("AutoBoost") and game.Players.LocalPlayer:FindFirstChild("Boosts") then
						for _, bk in ipairs(boostKinds()) do
							if not upNow and boostLeft(bk) <= 0 and boostPlan(slot, bk) then
								local okb, lb = pcall(function() return tonumber(readfile("aot_lastboost.txt")) end)
								if not (okb and lb) or os.time() - lb > 300 then upNow = "2x " .. bk .. "-Boost" end
							end
						end
					end
				end
				if not upNow and farm and cfg:GetAttribute("SpeedMode") and type(slot) == "table" and slot.Upgrades then
					local isRaid = workspace:GetAttribute("Type") == "Raids"
					local g = gradeOf(slot)
					local maxG = cfg:GetAttribute("FarmMaxGrade") or 12
					for _, t in ipairs(isRaid and RAID_THR or THR) do
						if t[2] > g and t[2] <= maxG then
							local cost = costToGrade(slot, t[2])
							if (slot.Currency and slot.Currency.Gold or 0) >= cost then upNow = t[1] end
							break
						end
					end
				end
				if upNow then
					farmStatus("-> Lobby: Gold reicht fuer " .. tostring(upNow))
					task.synchronize()
					game:GetService("ReplicatedStorage").Assets.Remotes.POST:FireServer("Functions", "Teleport")
				elseif farm and cfg:GetAttribute("SpeedMode") then
					local nm = syncMods(function() return workspace:GetAttribute("Modifiers") end, "Functions", "Modify")
					farmStatus("Speed: Retry (" .. nm .. " leichte Modifier)")
					pcall(function() GET:InvokeServer("Functions", "Retry", "Add") end)
				elseif farm then
					local goLobby, why = false, ""
					if type(slot) == "table" and slot.Upgrades then
						local g = gradeOf(slot)
						local gold = slot.Currency and slot.Currency.Gold or 0
						local maxG = cfg:GetAttribute("FarmMaxGrade") or 12
						local nt, nd = nextThreshold(g)
						local curD = workspace:GetAttribute("Difficulty")
						local isRaid = workspace:GetAttribute("Type") == "Raids"
						if bestDiff(g, isRaid) ~= curD and bestDiff(g, isRaid) ~= nil then
							goLobby, why = true, "Grade " .. g .. " erlaubt schon " .. tostring(bestDiff(g, isRaid))
						elseif nt and nt <= maxG then
							local cost = costToGrade(slot, nt)
							why = string.format("Gold %d / %d fuer %s", gold, cost, nd)
							goLobby = gold >= cost
						else
							why = "Max-Grade erreicht"
						end
					else
						why = "keine Daten -> Retry"
					end
					farmStatus((goLobby and "-> Lobby: " or "-> Retry: ") .. why)
					task.synchronize()
					if goLobby then
						game:GetService("ReplicatedStorage").Assets.Remotes.POST:FireServer("Functions", "Teleport")
					else
						syncMods(function() return workspace:GetAttribute("Modifiers") end, "Functions", "Modify")
						pcall(function() GET:InvokeServer("Functions", "Retry", "Add") end)
					end
				elseif cfg:GetAttribute("AutoRetry") then
					pcall(function() GET:InvokeServer("Functions", "Retry", "Add") end)
				end
			end
		else
			endDone = false
		end
	end
end)

A.restore = function()
	hb:Disconnect()
	restore()
end
]==]

local function injectActor()
	local ch = LP.Character
	if not ch then return false end
	local actor = ch:FindFirstChild("Actor")
	if not actor then
		for _, a in ipairs(getactors()) do if a:IsDescendantOf(ch) then actor = a break end end
	end
	if not actor then return false end
	local ok = pcall(run_on_actor, actor, ACTOR_CODE)
	return ok
end

----------------------------------------------------------------- Kill-Aura
local function rig()
	local ch = LP.Character
	return ch and ch:FindFirstChild("Rig_" .. LP.Name)
end

local function bladesLeft()
	local r = rig()
	if not r or not r:FindFirstChild("LeftHand") then return 0 end
	local n = 0
	for i = 1, 7 do
		local b = r.LeftHand:FindFirstChild("Blade_" .. i)
		if b and not b:GetAttribute("Broken") then n = n + 1 end
	end
	return n
end

local function nearestRefill()
	local hrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
	local best, bd
	for _, d in ipairs(workspace:GetDescendants()) do
		if d.Name == "Refill" and d:IsA("BasePart") then
			local dist = hrp and (d.Position - hrp.Position).Magnitude or 0
			if not bd or dist < bd then best, bd = d, dist end
		end
	end
	return best
end

local reloading, refilling = false, false
local sets = nil -- verbleibende Klingen-Saetze (nil = unbekannt)
local refillPart
-- Saetze aus dem HUD ("2 / 3") lesen: Loadout.Supply im Actor bleibt bei Remote-Reloads stehen, das HUD nicht
local setsLabel
local function syncSets()
	if not (setsLabel and setsLabel.Parent) then
		setsLabel = nil
		local hud = LP:FindFirstChild("PlayerGui") and LP.PlayerGui:FindFirstChild("Interface")
		hud = hud and hud:FindFirstChild("HUD")
		local bl = hud and hud:FindFirstChild("Blades", true)
		setsLabel = bl and bl:FindFirstChild("Sets")
	end
	local n = setsLabel and tonumber(tostring(setsLabel.Text):match("^%s*(%d+)"))
	if n then sets = n end
	return sets
end
local function doRefill()
	-- Remote-Refill; fertig sobald der Server das Refills-Attribut runterzaehlt
	if refilling or not C.AutoRefill or (LP:GetAttribute("Refills") or 0) <= 0 then return false end
	refillPart = (refillPart and refillPart.Parent) and refillPart or nearestRefill()
	if not refillPart then return false end
	refilling = true
	local before = LP:GetAttribute("Refills")
	POST:FireServer("Attacks", "Reload", refillPart)
	local t0 = os.clock()
	while os.clock() - t0 < 5 and LP:GetAttribute("Refills") == before do task.wait(0.05) end
	refilling = false
	if LP:GetAttribute("Refills") ~= before then sets = 3 return true end
	return false
end
-- Treffer pro Slash = Segmente + 1, ein Slash bricht aber hoechstens 1 Segment und Reload dauert ~50ms
-- -> frueh nachladen haelt jeden Slash bei ~8 Treffern. Bei knappem Vorrat (Saetze + 3*Refills) wieder erst bei 1.
-- Budget: frueh nachladen verschwendet die Rest-Segmente (Aberrant hat nur 3 Refills!) -> nur wenn der Vorrat
-- fuer den Rest der Runde mit Puffer reicht. Treffer/Kill wird pro Runde live gemessen.
local RB = { folder = nil, hits = 0, k0 = 0 }
local HITS_PER_SET = 35 -- gemessen ~35-40 Treffer pro 7er-Satz, wenn bis 1 Klinge genutzt
local function roundTrack()
	local tf = workspace:FindFirstChild("Titans")
	if tf ~= RB.folder then RB.folder, RB.hits, RB.k0 = tf, 0, S.kills end
	return tf
end
local function bladeBudget()
	local tf = roundTrack()
	local left = tf and #tf:GetChildren() or 0
	local kills = S.kills - RB.k0
	local hpk = kills >= 4 and math.max(RB.hits / kills, 3) or 6
	local avail = (sets or 0) + 3 * (LP:GetAttribute("Refills") or 0) + bladesLeft() / 7
	local need = left * hpk / HITS_PER_SET
	return avail, need, hpk
end
S.bladeBudget = bladeBudget
local function reloadAt()
	if C.ReloadAt <= 1 then return 1 end
	local ok, avail, need = pcall(bladeBudget)
	-- frueher Reload kostet bis ~1.7x Klingen -> nur mit 2x Puffer + 1 Satz Reserve
	if ok and avail >= need * 2 + 1 then return C.ReloadAt end
	return 1
end
local function ensureBlades(force)
	if bladesLeft() > reloadAt() then return true end
	DBG("ENSURE start sets=" .. tostring(sets) .. " refilling=" .. tostring(refilling))
	if (not C.AutoReload and not force) or reloading then return false end
	reloading = true
	local ok = false
	pcall(function()
		-- bekannt leer -> keinen zum Scheitern verurteilten Reload abwarten, direkt Refill
		if syncSets() ~= 0 and inv(4, "Blades", "Reload") == true then
			ok = true
			if sets then sets = math.max(sets - 1, 0) end
			return
		end
		sets = 0
		while refilling do task.wait(0.05) end
		if sets == 0 then doRefill() end
		-- direkt nachladen, sobald der Server es zulaesst
		local t0 = os.clock()
		repeat
			if inv(4, "Blades", "Reload") == true then ok = true if sets then sets = math.max(sets - 1, 0) end break end
			task.wait(0.1)
		until os.clock() - t0 > 4
	end)
	reloading = false
	DBG("ENSURE end ok=" .. tostring(ok))
	return ok or bladesLeft() > 0
end
-- Nach einem Refill nimmt der Server ~2.6s lang keinen Reload an (gemessen) -> Refill ein paar Klingen frueher,
-- dann laeuft die Sperre waehrend die letzten Klingen noch schlagen. Bei knappem Vorrat nur 1 Klinge Puffer.
local function refillAt()
	local ok, avail, need = pcall(bladeBudget)
	if ok and avail >= need * 1.5 + 1 then return math.min(reloadAt() + 3, 5) end
	return reloadAt() + 1
end
-- Vorausschauend auffuellen: letzter Satz drin und Klingen werden knapp -> Refill schon vorher
task.spawn(function()
	while S.alive do
		pcall(syncSets)
		if (C.KillAura or C.AutoFarm or C.InfBlades) and C.AutoRefill and sets == 0 and not refilling
			and workspace:FindFirstChild("Titans") and bladesLeft() <= refillAt() then
			pcall(doRefill)
		end
		task.wait(0.15)
	end
end)

local lastHit = setmetatable({}, { __mode = "k" })
local function targets()
	local tf = workspace:FindFirstChild("Titans")
	local hrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
	if not tf or not hrp then return {} end
	local list, now = {}, os.clock()
	local raidMode = workspace:GetAttribute("Type") == "Raids"
	for _, t in ipairs(tf:GetChildren()) do
		local hb = t:FindFirstChild("Hitboxes")
		local hit = hb and hb:FindFirstChild("Hit")
		local nape = hit and hit:FindFirstChild("Nape")
		local root = t:FindFirstChild("HumanoidRootPart") or t.PrimaryPart
		if nape and root and (not lastHit[t] or now - lastHit[t] > C.HitCD) then
			local d = (root.Position - hrp.Position).Magnitude
			-- Raids: Titanen nach Naehe zum Verteidigungsziel (Attribut Distance) priorisieren
			if raidMode then
				local od = t:GetAttribute("Distance")
				if od then d = od end -- naechster am Verteidigungsziel zuerst
			end
			if t:GetAttribute("Shifter") then d = -1 lastHit[t] = nil end -- Raid-Boss immer zuerst, ohne Cooldown
			if C.AuraRange >= 20000 or d <= C.AuraRange then list[#list + 1] = { t = t, nape = nape, d = d } end
		end
	end
	table.sort(list, function(a, b) return a.d < b.d end)
	return list
end

-- Server-Limits (gemessen): ~1 Slash / 0.85s, pro Slash max. (Klingen-Segmente + 1) Treffer,
-- meist bricht nur 1 Segment pro Slash -> Smart: 1 Slash/0.9s, so viele Treffer wie angenommen, frueh nachladen
local lastSlash = 0
local function topUp()
	if reloading or (sets ~= nil and sets <= 0) then return end
	reloading = true
	local ok, r = pcall(function() return inv(4, "Blades", "Reload") end)
	if ok and r == true then
		if sets then sets = math.max(sets - 1, 0) end
	else
		sets = 0
	end
	reloading = false
end
task.spawn(function()
	while S.alive do
		-- pcall: ein einzelner Fehler (Charakter weg, Titan despawnt) darf die Aura nicht dauerhaft toeten
		local okA, errA = pcall(function()
		if (C.KillAura or C.AutoFarm) and LP.Character and LP:GetAttribute("Weapon") == "Blades" then
			local hum = LP.Character:FindFirstChildOfClass("Humanoid")
			if hum and hum.Health > 0 then
				local list = targets()
				if #list > 0 then
					if ensureBlades() then
						local cd = C.SmartAura and (C.SpeedMode and math.min(C.SmartGap, 1.5) or C.SmartGap) or C.Interval
						-- Raids: wenige Refills -> seltener aber voll slashen (gleiche Treffer/s, ~3x weniger Klingenverbrauch)
						-- (frueher fest 4s in Raids: Klingen verschleissen pro Treffer, nicht pro Slash -> bremste nur Phase 1)
						local dt = os.clock() - lastSlash
						if dt < cd then task.wait(cd - dt) end
						list = targets()
						local n = C.SmartAura and math.min(8, bladesLeft() + 1) or C.PerCycle
						if #list > 0 then
							lastSlash = os.clock()
							RB.hits = RB.hits + math.min(n, #list)
							DBG("SLASH n=" .. math.min(n, #list) .. " blades=" .. bladesLeft() .. " targets=" .. #list)
							POST:FireServer("Attacks", "Slash", true)
							task.wait(0.03)
							local bossE = C.BossFocus and list[1] and list[1].t:GetAttribute("Shifter") and list[1]
							if bossE then
								-- erst ALLE normalen Titanen (sortiert nach Naehe zum Verteidigungsziel), nur Rest-Treffer auf den Boss:
								-- in Phase 1 ist der Boss unverwundbar -> vorher gingen fast alle Treffer ins Leere und das Ziel fiel
								local used = 0
								for i = 2, #list do
									if used >= n then break end
									local e = list[i]
									lastHit[e.t] = os.clock()
									POST:FireServer("Hitboxes", "Register", e.nape, (S.hitVel or 200) + math.random() * 40, 0.25 + math.random() * 0.4)
									used = used + 1
								end
								for _ = used + 1, n do
									POST:FireServer("Hitboxes", "Register", bossE.nape, (S.hitVel or 200) + math.random() * 40, 0.25 + math.random() * 0.4)
								end
							else
								for i = 1, math.min(n, #list) do
									local e = list[i]
									lastHit[e.t] = os.clock()
									POST:FireServer("Hitboxes", "Register", e.nape, (S.hitVel or 200) + math.random() * 40, 0.25 + math.random() * 0.4)
								end
							end
							task.wait(0.12)
							POST:FireServer("Attacks", "Slash", false)
						end
					end
				end
			end
		end
		end)
		if not okA then DBG("AURA ERR " .. tostring(errA)) task.wait(0.5) end
		task.wait(0.03)
	end
end)

-- Charakter kaputt (HumanoidRootPart unter die Map gefallen) -> Mission haengt sonst ewig: nach 10s zur Lobby
task.spawn(function()
	local since
	while S.alive do
		local ch = LP.Character
		local broken = (C.AutoFarm or C.KillAura) and game.PlaceId ~= 14916516914 and workspace:GetAttribute("Type") ~= nil
			and ch and ch:FindFirstChildOfClass("Humanoid") and not ch:FindFirstChild("HumanoidRootPart")
		if broken then
			since = since or os.clock()
			if os.clock() - since > 10 then
				Cfg:SetAttribute("FarmStatus", "Charakter unter die Map gefallen -> Lobby")
				if workspace:GetAttribute("Type") == "Raids" then
					local okf, nf = pcall(function() return tonumber(readfile("aot_raidfail.txt")) end)
					nf = (okf and nf or 0) + 1
					if nf >= 2 then C.FarmPick = "Beste Mission" syncCfg() nf = 0 end
					pcall(writefile, "aot_raidfail.txt", tostring(nf))
				end
				POST:FireServer("Functions", "Teleport")
				task.wait(15)
				since = nil
			end
		else
			since = nil
		end
		task.wait(1)
	end
end)

-- Festgefahren: 0 Klingen, 0 Refills, kein Satz mehr -> nach 8s zur Lobby (Auto-Farm laeuft dort weiter)
task.spawn(function()
	local since
	while S.alive do
		local stuck = C.AutoFarm and C.StuckLeave and workspace:FindFirstChild("Titans") and bladesLeft() <= 1
			and (LP:GetAttribute("Refills") or 0) <= 0 and sets == 0
		if stuck then
			since = since or os.clock()
			if os.clock() - since > 8 then
				Cfg:SetAttribute("FarmStatus", "Keine Klingen/Refills mehr -> Lobby")
				-- im Raid zaehlt das als Fehlschlag (2x -> zurueck auf die beste Mission)
				if workspace:GetAttribute("Type") == "Raids" then
					local okf, nf = pcall(function() return tonumber(readfile("aot_raidfail.txt")) end)
					nf = (okf and nf or 0) + 1
					if nf >= 2 then C.FarmPick = "Beste Mission" syncCfg() nf = 0 end
					pcall(writefile, "aot_raidfail.txt", tostring(nf))
				end
				POST:FireServer("Functions", "Teleport")
				task.wait(10)
				since = nil
			end
		else
			since = nil
		end
		task.wait(1)
	end
end)

-- Family Auto-Roll: rollt bis eine der gewaehlten Raritaeten kommt oder keine Spins mehr da sind
S.rolling = false
S.rollStatus = "-"
local function famRarity(name)
	local ok, F = pcall(function() return require(game:GetService("ReplicatedStorage").Modules.Storage.Families) end)
	if not ok or type(F) ~= "table" then return nil end
	for rar, list in pairs(F) do if type(list) == "table" and list[name] then return rar end end
end
local RANK = { Common = 1, Rare = 2, Epic = 3, Legendary = 4, Mythic = 5, Secret = 6 }
local RNAME = { "Common", "Rare", "Epic", "Legendary", "Mythic", "Secret" }
-- Lager-Stand aus dem Actor lesen (Liste + Kapazitaet)
local function famStorage()
	if isfile("aot_fam.json") then delfile("aot_fam.json") end
	local actor
	for _, a in ipairs(getactors()) do if LP.Character and a:IsDescendantOf(LP.Character) then actor = a break end end
	actor = actor or getactors()[1]
	pcall(run_on_actor, actor, [[
		local H
		for _, v in ipairs(getgc(true)) do
			if type(v) == "table" and rawget(v, "Prefix") == "rbxassetid://" and type(rawget(v, "Cache")) == "table" then H = v break end
		end
		local _, sl = H.Modules.Update.Get_Data(H, true)
		local gp = game.Players.LocalPlayer:FindFirstChild("Gamepasses")
		local bag = gp and gp:FindFirstChild("Family_Bag") and gp.Family_Bag.Value == true
		local cap = 1 + (bag and 10 or 0) + ((sl.Extra_Slots and sl.Extra_Slots.Family) or 0)
		writefile("aot_fam.json", game:GetService("HttpService"):JSONEncode({ stored = sl.Inventory.Families or {}, cap = cap }))
	]])
	for _ = 1, 30 do if isfile("aot_fam.json") then break end task.wait(0.1) end
	local ok, d = pcall(function() return game:GetService("HttpService"):JSONDecode(readfile("aot_fam.json")) end)
	if ok and type(d) == "table" then return d.stored or {}, d.cap or 1 end
	return {}, 1
end
local function autoRoll()
	if S.rolling then S.rolling = false return end
	S.rolling = true
	local n = 0
	local stored, cap = {}, 1
	local tier = RANK[C.RollStartTier] or 3
	if C.RollDeposit then
		stored, cap = famStorage()
		-- Stufe hochziehen, falls schon genug im Lager
		local function cnt(t) local k = 0 for _, f in ipairs(stored) do if RANK[famRarity(f) or ""] == t then k = k + 1 end end return k end
		while tier <= 6 and cnt(tier) >= 2 do tier = tier + 1 end
	end
	while S.rolling and S.alive do
		local ok, spins, extra, fam, pity
		-- Server-Cooldown ~3.4s zwischen Rolls: bis zu 6s alle 0.25s erneut versuchen
		local t0 = os.clock()
		repeat
			ok, spins, extra, fam, pity = pcall(function() return GET:InvokeServer("Family", "Roll") end)
			if ok and fam ~= nil then break end
			task.wait(0.25)
		until os.clock() - t0 > 6 or not S.rolling
		if not ok or fam == nil then
			S.rollStatus = n == 0 and "Roll abgelehnt (keine Spins / falscher Screen?)" or ("Gestoppt nach " .. n .. " Rolls (Server lehnt ab)")
			break
		end
		n = n + 1
		local rar = famRarity(fam) or "?"
		local left = (tonumber(spins) or 0) + (tonumber(extra) or 0)
		S.rollStatus = string.format("#%d: %s (%s) · Spins %d · Pity %s", n, tostring(fam), rar, left, tostring(pity))
		if C.RollDeposit then
			local rk = RANK[rar] or 0
			if rk >= tier then
				-- Platz schaffen: schlechteste eingelagerte Familie (unter dieser Raritaet) loeschen
				if #stored >= cap then
					local wi, wr
					for i, f in ipairs(stored) do
						local fr = RANK[famRarity(f) or ""] or 0
						if fr < rk and (not wr or fr < wr) then wi, wr = i, fr end
					end
					if wi then
						local okd, del = pcall(function() return GET:InvokeServer("Family", "Delete", stored[wi]) end)
						if okd and del == true then table.remove(stored, wi) end
						task.wait(0.3)
					end
				end
				if #stored < cap then
					local oks, ok2, sf = pcall(function() return GET:InvokeServer("Family", "Store") end)
					if oks and ok2 == true then
						stored[#stored + 1] = sf or fam
						local k = 0
						for _, f in ipairs(stored) do if RANK[famRarity(f) or ""] == tier then k = k + 1 end end
						if k >= 2 then tier = tier + 1 end
					end
				end
			end
			local names = {}
			for _, f in ipairs(stored) do names[#names + 1] = f end
			S.rollStatus = string.format("#%d: %s (%s) · Spins %d · Pity %s\nLager %d/%d: %s · sammle ab %s", n, tostring(fam), rar, left, tostring(pity), #stored, cap, table.concat(names, ", "), RNAME[tier] or "MAX")
			if tier > 6 then S.rollStatus = S.rollStatus .. " · fertig (2x Secret)" break end
		elseif C["RollStop_" .. rar] then
			S.rollStatus = "TREFFER: " .. tostring(fam) .. " (" .. rar .. ") nach " .. n .. " Rolls · Spins " .. left
			break
		end
		if left <= 0 then S.rollStatus = S.rollStatus .. " · keine Spins mehr" break end
		task.wait(3.3)
	end
	S.rolling = false
end

-- Teleport-Watchdog: haengt ein Retry/Teleport > 60s -> Client-Teleport in die Lobby (Auto-Farm laeuft dort weiter)
task.spawn(function()
	local since
	while S.alive do
		if C.AutoFarm and LP:GetAttribute("Teleporting") == true and workspace:FindFirstChild("Titans") then
			since = since or os.clock()
			if os.clock() - since > 60 then
				Cfg:SetAttribute("FarmStatus", "Teleport haengt -> Lobby")
				pcall(function() game:GetService("TeleportService"):Teleport(14916516914, LP) end)
				since = os.clock()
			end
		elseif C.AutoStart and LP:GetAttribute("Teleporting") == true and game.PlaceId == 14916516914 then
			-- Lobby: Party-Teleport haengt -> Party verlassen und neu starten
			since = since or os.clock()
			if os.clock() - since > 40 then
				Cfg:SetAttribute("FarmStatus", "Lobby-Teleport haengt -> neu erstellen")
				pcall(function() GET:InvokeServer("S_Missions", "Leave") end)
				task.wait(2)
				Cfg:SetAttribute("FarmReq", os.clock())
				since = os.clock()
			end
		else
			since = nil
		end
		task.wait(2)
	end
end)

-- Boss-Ausweichen (Raids): Abstand + Hoehe zum Shifter-Boss halten
S.safeCF = nil
local function findBoss()
	local tf = workspace:FindFirstChild("Titans")
	if not tf then return end
	for _, t in ipairs(tf:GetChildren()) do
		if t:GetAttribute("Shifter") then return t end
	end
end
-- kein Schweben: nur einmal auf den Boden versetzen, wenn der Boss zu nah kommt
local lastEvade = 0
local evParams = RaycastParams.new()
evParams.FilterType = Enum.RaycastFilterType.Exclude
-- nur echter Boden: ohne das landete der Teleport auf nicht-kollidierenden Teilen -> Sturz unter die Map (HRP weg, Raid haengt)
evParams.RespectCanCollide = true
conn(RS.Heartbeat:Connect(function()
	if not C.BossEvade then return end
	if os.clock() - lastEvade < 0.4 then return end
	local hrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
	local tf = workspace:FindFirstChild("Titans")
	if not hrp or not tf then return end
	-- naechste Gefahr: Boss < 300 Studs oder normaler Titan < 120 Studs
	local broot
	for _, t in ipairs(tf:GetChildren()) do
		local root = t:FindFirstChild("HumanoidRootPart") or t.PrimaryPart
		if root then
			local d = Vector3.new(hrp.Position.X - root.Position.X, 0, hrp.Position.Z - root.Position.Z).Magnitude
			if d < (t:GetAttribute("Shifter") and 450 or 120) then broot = root break end
		end
	end
	if not broot then return end
	local flat = Vector3.new(hrp.Position.X - broot.Position.X, 0, hrp.Position.Z - broot.Position.Z)
	lastEvade = os.clock()
	evParams.FilterDescendantsInstances = { LP.Character, workspace:FindFirstChild("Titans"), workspace:FindFirstChild("Characters") }
	-- 8 Richtungen probieren, die vom Boss weg zuerst; Boden per Raycast
	local base = flat.Magnitude > 1 and flat.Unit or Vector3.new(1, 0, 0)
	for i = 0, 7 do
		local ang = (i % 2 == 0 and 1 or -1) * math.ceil(i / 2) * math.pi / 4
		local dir = CFrame.Angles(0, ang, 0):VectorToWorldSpace(base)
		local target = broot.Position + dir * 900
		local hit = workspace:Raycast(Vector3.new(target.X, broot.Position.Y + 400, target.Z), Vector3.new(0, -1200, 0), evParams)
		if hit and hit.Normal.Y > 0.7 and hit.Position.Y > workspace.FallenPartsDestroyHeight + 50 then
			hrp.CFrame = CFrame.new(hit.Position + Vector3.new(0, 4, 0))
			hrp.AssemblyLinearVelocity = Vector3.zero
			break
		end
	end
end))

-- Discord-Webhook bei seltenen Drops (URL aus blox_wh_url.txt bzw. aot_wh_url.txt)
local function whURL()
	for _, f in ipairs({ "aot_wh_url.txt", "blox_wh_url.txt" }) do
		local ok, v = pcall(function() return isfile(f) and readfile(f) end)
		if ok and type(v) == "string" then
			v = v:gsub("%s+", "")
			if v:match("^https://") and v:find("/webhooks/") then return v end
		end
	end
end
local RCOL = { Epic = 0x6E16FF, Legendary = 0xFFB726, Mythic = 0xFF0000, Secret = 0x000000, Exclusive = 0x000000 }
local function pingText()
	local ok, v = pcall(function() return isfile("aot_wh_ping.txt") and readfile("aot_wh_ping.txt") end)
	if ok and type(v) == "string" then
		local id = v:match("%d%d%d%d%d+")
		if id then return "<@" .. id .. ">" end
	end
	return "@everyone"
end
local RICON = { Common = "⚪", Uncommon = "🟢", Rare = "🔵", Epic = "🟣", Legendary = "🟡", Mythic = "🔴", Secret = "⚫", Exclusive = "⚫" }
conn(Cfg:GetAttributeChangedSignal("DropEvent"):Connect(function()
	local ok, ev = pcall(function() return HS:JSONDecode(Cfg:GetAttribute("DropEvent")) end)
	-- Runden-Log fuer Gold/XP-pro-Minute-Vergleich (Wandzeit zwischen zwei Zeilen = kompletter Zyklus inkl. Teleport)
	if ok and type(ev) == "table" and ev.type ~= "Test" then
		pcall(function()
			local line = table.concat({ os.time(), tostring(ev.type), tostring(ev.map), tostring(ev.diff), tostring(game.PlaceId),
				tostring(workspace:GetAttribute("Boosted")), tostring(ev.sec), tostring(ev.gold), tostring(ev.xp), #(ev.items or {}) }, ",") .. "\n"
			if not isfile("aot_rounds.csv") then writefile("aot_rounds.csv", "time,type,objective,diff,place,boosted,sec,gold,xp,items\n") end
			appendfile("aot_rounds.csv", line)
		end)
	end
	if not C.Webhook then return end
	local url = whURL()
	local req = http_request or request or (syn and syn.request)
	if not ok or not url or not req then return end
	local order = { Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5, Mythic = 6, Secret = 7, Exclusive = 8 }
	local lines, best, anyRare = {}, "Common", false
	table.sort(ev.items or {}, function(x, y) return (order[x.rarity] or 0) > (order[y.rarity] or 0) end)
	for _, it in ipairs(ev.items or {}) do
		lines[#lines + 1] = string.format("%s %s**%s** · %s · _%s_", RICON[it.rarity] or "▫️", it.rare and "⭐ " or "", it.name, it.rarity, it.src)
		if it.rare then anyRare = true end
		if (order[it.rarity] or 0) > (order[best] or 0) then best = it.rarity end
	end
	if #lines == 0 then lines[1] = "_keine Items_" end
	local function k(n) n = tonumber(n) or 0 if n >= 1e3 then return string.format("%.1fk", n / 1e3) end return tostring(n) end
	pcall(req, {
		Url = url, Method = "POST", Headers = { ["Content-Type"] = "application/json" },
		Body = HS:JSONEncode({
			username = "AOT:R Drops",
			content = anyRare and (pingText() .. " seltener Drop!") or nil,
			allowed_mentions = { parse = { "everyone", "users" } },
			embeds = { {
				title = (anyRare and "⭐ " or "") .. tostring(ev.type) .. " · " .. tostring(ev.map) .. " · " .. tostring(ev.diff),
				description = table.concat(lines, string.char(10)),
				color = anyRare and (RCOL[best] or 0xBE4696) or 0x2B2D31,
				footer = { text = string.format("%s · %ss · +%s Gold · +%s XP · %s", LP.Name, tostring(ev.sec or "?"), k(ev.gold), k(ev.xp), os.date("%H:%M:%S")) },
			} },
		}),
	})
end))

-- Ressourcen nie leer: Klingen dauerhaft nachladen/auffuellen (auch ohne Kill Aura)
task.spawn(function()
	while S.alive do
		if C.InfBlades and LP:GetAttribute("Weapon") == "Blades" and bladesLeft() <= 1 then
			ensureBlades(true)
		end
		task.wait(0.1)
	end
end)

----------------------------------------------------------------- ESP
local function clearESP()
	for t, o in pairs(S.esp) do
		pcall(function() o.h:Destroy() o.b:Destroy() end)
		S.esp[t] = nil
	end
end

local function updateESP()
	if not C.ESP then if next(S.esp) then clearESP() end return end
	local tf = workspace:FindFirstChild("Titans")
	local hrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
	for t, o in pairs(S.esp) do
		if not t.Parent or not tf or t.Parent ~= tf then
			pcall(function() o.h:Destroy() o.b:Destroy() end)
			S.esp[t] = nil
		end
	end
	if not tf then return end
	for _, t in ipairs(tf:GetChildren()) do
		local nape = t:FindFirstChild("Hitboxes") and t.Hitboxes:FindFirstChild("Hit") and t.Hitboxes.Hit:FindFirstChild("Nape")
		if nape then
			local o = S.esp[t]
			if not o then
				local h = Instance.new("Highlight")
				h.FillColor = Color3.fromRGB(255, 60, 60)
				h.OutlineColor = Color3.fromRGB(255, 220, 220)
				h.FillTransparency = 0.8
				h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
				h.Adornee = t
				h.Parent = CG
				local b = Instance.new("BillboardGui")
				b.Size = UDim2.fromOffset(120, 22)
				b.AlwaysOnTop = true
				b.StudsOffset = Vector3.new(0, 4, 0)
				b.Adornee = nape
				local l = Instance.new("TextLabel")
				l.BackgroundTransparency = 1
				l.Size = UDim2.fromScale(1, 1)
				l.Font = Enum.Font.GothamBold
				l.TextSize = 13
				l.TextColor3 = Color3.fromRGB(255, 230, 120)
				l.TextStrokeTransparency = 0.3
				l.Parent = b
				b.Parent = CG
				o = { h = h, b = b, l = l }
				S.esp[t] = o
			end
			if hrp then o.l.Text = "NAPE  " .. math.floor((nape.Position - hrp.Position).Magnitude) .. "m" end
		end
	end
end

----------------------------------------------------------------- Visuals / Misc
local LIGHT0 = {
	Brightness = Lighting.Brightness, ClockTime = Lighting.ClockTime, FogEnd = Lighting.FogEnd,
	GlobalShadows = Lighting.GlobalShadows, Ambient = Lighting.Ambient,
}
local atm = Lighting:FindFirstChildOfClass("Atmosphere")
local ATM0 = atm and atm.Density
local lightTouched = false
local function visuals()
	if C.Fullbright then
		lightTouched = true
		Lighting.Brightness = 2
		Lighting.ClockTime = 14
		Lighting.GlobalShadows = false
		Lighting.Ambient = Color3.fromRGB(170, 170, 170)
	end
	if C.NoFog then
		lightTouched = true
		Lighting.FogEnd = 1e6
		if atm then atm.Density = 0 end
	end
	if not C.Fullbright and not C.NoFog and lightTouched then
		lightTouched = false
		for k, v in pairs(LIGHT0) do pcall(function() Lighting[k] = v end) end
		if atm and ATM0 then atm.Density = ATM0 end
	end
end

conn(LP.Idled:Connect(function()
	if C.AntiAFK then
		local VU = game:GetService("VirtualUser")
		VU:CaptureController()
		VU:ClickButton2(Vector2.new())
	end
end))

conn(LP.CharacterAdded:Connect(function(ch)
	task.spawn(function()
		ch:WaitForChild("Actor", 20)
		task.wait(3)
		if S.alive then injectActor() end
	end)
end))
task.spawn(injectActor)

local tick0 = 0
conn(RS.Heartbeat:Connect(function()
	local n = os.clock()
	if n - tick0 < 0.3 then return end
	tick0 = n
	pcall(updateESP)
	pcall(visuals)
end))

----------------------------------------------------------------- Prestige-ETA
-- XP/Minute aus aot_rounds.csv: letzter zusammenhaengender Block (Luecke > 10 Min = Pause) der letzten 15 Min (reagiert schnell auf Boosts)
local xpRateCache, xpRateAt = nil, 0
local function xpRate()
	if os.clock() - xpRateAt < 20 then return xpRateCache end
	xpRateAt = os.clock()
	local ok, txt = pcall(function() return isfile("aot_rounds.csv") and readfile("aot_rounds.csv") end)
	if not ok or type(txt) ~= "string" then xpRateCache = nil return nil end
	local rows = {}
	for line in txt:gmatch("[^\n]+") do
		local t, xp = line:match("^(%d+),[^,]*,[^,]*,[^,]*,[^,]*,[^,]*,[^,]*,[^,]*,(%d+),")
		if t then rows[#rows + 1] = { tonumber(t), tonumber(xp) } end
	end
	local now = os.time()
	local first = #rows
	while first > 1 and rows[first - 1][1] >= now - 900 and rows[first][1] - rows[first - 1][1] <= 600 do first = first - 1 end
	if #rows - first < 2 or now - rows[#rows][1] > 900 then xpRateCache = nil return nil end
	local sum = 0
	for i = first + 1, #rows do sum = sum + rows[i][2] end
	local span = rows[#rows][1] - rows[first][1]
	xpRateCache = span > 0 and sum / span * 60 or nil
	return xpRateCache
end
local function fmtDur(sec)
	sec = math.max(math.floor(sec), 0)
	if sec >= 3600 then return string.format("%dh %02dm", sec // 3600, (sec % 3600) // 60) end
	return string.format("%dm", math.max(sec // 60, 1))
end
local function kfmt(n)
	n = tonumber(n) or 0
	if n >= 1e6 then return string.format("%.2fM", n / 1e6) elseif n >= 1e3 then return string.format("%.0fk", n / 1e3) end
	return tostring(math.floor(n))
end
-- kurz fuer die Titelleiste, lang fuer die Lobby-Sektion
local function prestigeETA()
	local need = Cfg:GetAttribute("PrestigeNeed")
	if not need then return nil end
	local nx = Cfg:GetAttribute("PrestigeNext") or 1
	local lv, cap = Cfg:GetAttribute("PrestigeLevel") or 0, Cfg:GetAttribute("PrestigeCap") or 100
	if need <= 0 then return "P" .. nx .. " bereit", "Prestige " .. nx .. ": bereit (Level " .. lv .. "/" .. cap .. ")" end
	local r = xpRate()
	if not r or r <= 0 then
		return "P" .. nx .. ": " .. kfmt(need) .. " XP", string.format("Prestige %d: Lv %d/%d · %s XP fehlen · Rate wird gemessen (2+ Runden)", nx, lv, cap, kfmt(need))
	end
	local sec = need / r * 60
	return "P" .. nx .. " in ~" .. fmtDur(sec),
		string.format("Prestige %d: Lv %d/%d · %s XP fehlen · %s XP/min · ETA ~%s (%s)", nx, lv, cap, kfmt(need), kfmt(r), fmtDur(sec), os.date("%H:%M", os.time() + math.floor(sec)))
end

----------------------------------------------------------------- GUI (Matcha-Stil wie TSC Hub)
local old = CG:FindFirstChild("AOTHub")
if old then old:Destroy() end

local T = {
	bg = Color3.fromRGB(15, 15, 18), panel = Color3.fromRGB(20, 20, 24), panel2 = Color3.fromRGB(25, 25, 30),
	stroke = Color3.fromRGB(36, 36, 43), edge = Color3.fromRGB(46, 46, 54), track = Color3.fromRGB(32, 32, 38),
	off = Color3.fromRGB(34, 34, 41), accent = Color3.fromRGB(190, 70, 150), text = Color3.fromRGB(226, 226, 232),
	dim = Color3.fromRGB(122, 122, 134), font = Enum.Font.GothamMedium, bold = Enum.Font.GothamBold, ts = 13,
}

local gui = Instance.new("ScreenGui")
gui.Name = "AOTHub"; gui.ResetOnSpawn = false; gui.IgnoreGuiInset = true; gui.DisplayOrder = 999
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = CG
S.gui = gui

local function stroke(o, c) local s = Instance.new("UIStroke"); s.Color = c or T.stroke; s.Thickness = 1
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border; s.Parent = o; return s end
local function corner(o, r) Instance.new("UICorner", o).CornerRadius = UDim.new(0, r or 3) end
local function txt(parent, text, size, color)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1; l.Font = T.font; l.TextSize = T.ts; l.TextColor3 = color or T.text
	l.Text = text; l.TextXAlignment = Enum.TextXAlignment.Left; l.Size = size; l.Parent = parent
	return l
end

local FULL_H = 470
local main = Instance.new("Frame")
main.Size = UDim2.fromOffset(560, FULL_H)
local vp = workspace.CurrentCamera.ViewportSize
if C.UIX < 0 or C.UIY < 0 or C.UIX > vp.X - 100 or C.UIY > vp.Y - 40 then C.UIX, C.UIY = 40, 160 end
main.Position = UDim2.fromOffset(C.UIX, C.UIY)
main.Visible = C.UIVisible
main.BackgroundColor3 = T.bg; main.BorderSizePixel = 0; main.Active = true; main.ClipsDescendants = true
main.Parent = gui
corner(main, 8); stroke(main, T.edge)

local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 30); titleBar.BackgroundTransparency = 1; titleBar.Active = true; titleBar.Parent = main
local statusL, farmHdr
do
	local tl2 = Instance.new("UIListLayout", titleBar); tl2.FillDirection = Enum.FillDirection.Horizontal
	tl2.VerticalAlignment = Enum.VerticalAlignment.Center; tl2.Padding = UDim.new(0, 8); tl2.SortOrder = Enum.SortOrder.LayoutOrder
	Instance.new("UIPadding", titleBar).PaddingLeft = UDim.new(0, 12)
	local a = txt(titleBar, "AOT:R Hub", UDim2.fromOffset(0, 30), T.accent); a.Font = T.bold; a.AutomaticSize = Enum.AutomaticSize.X; a.LayoutOrder = 1
	local b = txt(titleBar, "Interface", UDim2.fromOffset(0, 30), T.text); b.AutomaticSize = Enum.AutomaticSize.X; b.LayoutOrder = 2
	local c = txt(titleBar, LP.Name, UDim2.fromOffset(0, 18), T.accent); c.AutomaticSize = Enum.AutomaticSize.X; c.LayoutOrder = 3
	c.TextSize = 12; c.BackgroundColor3 = Color3.fromRGB(40, 18, 34); c.BackgroundTransparency = 0; corner(c, 6); stroke(c, Color3.fromRGB(90, 34, 72))
	local cp = Instance.new("UIPadding", c); cp.PaddingLeft = UDim.new(0, 7); cp.PaddingRight = UDim.new(0, 7)
	statusL = txt(titleBar, "", UDim2.fromOffset(0, 30), T.dim); statusL.AutomaticSize = Enum.AutomaticSize.X; statusL.TextSize = 11; statusL.LayoutOrder = 5
	farmHdr = txt(titleBar, "", UDim2.fromOffset(0, 18), T.text); farmHdr.AutomaticSize = Enum.AutomaticSize.X; farmHdr.TextSize = 12; farmHdr.LayoutOrder = 4
	farmHdr.RichText = true; farmHdr.BackgroundColor3 = T.panel2; farmHdr.BackgroundTransparency = 0; corner(farmHdr, 6); stroke(farmHdr, T.edge)
	local fp = Instance.new("UIPadding", farmHdr); fp.PaddingLeft = UDim.new(0, 7); fp.PaddingRight = UDim.new(0, 7)
end

-- Drag (Position wird gespeichert)
do
	local dragging, startPos, startMouse
	titleBar.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true; startPos = main.Position; startMouse = i.Position end
	end)
	conn(UIS.InputChanged:Connect(function(i)
		if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then
			local d = i.Position - startMouse
			main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
		end
	end))
	conn(UIS.InputEnded:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 and dragging then
			dragging = false
			C.UIX, C.UIY = main.Position.X.Offset, main.Position.Y.Offset
			saveCfg()
		end
	end))
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
	if not pages[name] then name = "Combat" end
	C.Tab = name
	saveCfg()
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
	b.MouseButton1Click:Connect(function() selectTab(name) end)
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
local function nextOrder(X) X.n = X.n + 1 return X.n end

local refreshers = {}
local function toggle(X, label, key, cb)
	local row = Instance.new("TextButton")
	row.AutoButtonColor = false; row.BackgroundTransparency = 1; row.Text = ""; row.Size = UDim2.new(1, 0, 0, 18)
	row.LayoutOrder = nextOrder(X); row.Parent = X.f
	local dot = Instance.new("Frame")
	dot.Size = UDim2.fromOffset(17, 17); dot.BorderSizePixel = 0; dot.Parent = row
	corner(dot, 4); stroke(dot)
	local l = txt(row, label, UDim2.new(1, -28, 1, 0)); l.Position = UDim2.fromOffset(27, 0)
	local function paint()
		dot.BackgroundColor3 = C[key] and T.accent or T.off
		l.TextColor3 = C[key] and T.text or T.dim
	end
	paint()
	row.MouseButton1Click:Connect(function()
		C[key] = not C[key]; paint(); syncCfg()
		if cb then task.spawn(cb, C[key]) end
	end)
	refreshers[#refreshers + 1] = paint
end

local function slider(X, label, key, minV, maxV, step, fmt)
	local head = Instance.new("Frame"); head.BackgroundTransparency = 1; head.Size = UDim2.new(1, 0, 0, 15)
	head.LayoutOrder = nextOrder(X); head.Parent = X.f
	txt(head, label, UDim2.new(1, -70, 1, 0))
	local val = txt(head, "", UDim2.new(0, 70, 1, 0), T.text)
	val.AnchorPoint = Vector2.new(1, 0); val.Position = UDim2.new(1, 0, 0, 0); val.TextXAlignment = Enum.TextXAlignment.Right
	local hit = Instance.new("Frame"); hit.BackgroundTransparency = 1; hit.Size = UDim2.new(1, 0, 0, 12); hit.Active = true
	hit.LayoutOrder = nextOrder(X); hit.Parent = X.f
	local bar = Instance.new("Frame")
	bar.Size = UDim2.new(1, 0, 0, 6); bar.Position = UDim2.fromOffset(0, 3); bar.BackgroundColor3 = T.track; bar.BorderSizePixel = 0
	bar.Parent = hit
	corner(bar, 3)
	local fill = Instance.new("Frame")
	fill.BackgroundColor3 = T.accent; fill.BorderSizePixel = 0; fill.Parent = bar
	corner(fill, 3)
	local function draw()
		fill.Size = UDim2.new(math.clamp((C[key] - minV) / (maxV - minV), 0, 1), 0, 1, 0)
		val.Text = fmt and fmt(C[key]) or tostring(C[key])
	end
	local function set(v)
		v = math.clamp(v, minV, maxV)
		v = math.floor(v / step + 0.5) * step
		if step < 1 then v = math.floor(v * 100 + 0.5) / 100 end
		if v ~= C[key] then C[key] = v; draw(); syncCfg() end
	end
	draw()
	local sliding = false
	local function fromX(x) set(minV + (x - bar.AbsolutePosition.X) / bar.AbsoluteSize.X * (maxV - minV)) end
	hit.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 then sliding = true; fromX(i.Position.X) end
	end)
	conn(UIS.InputChanged:Connect(function(i)
		if sliding and i.UserInputType == Enum.UserInputType.MouseMovement then fromX(i.Position.X) end
	end))
	conn(UIS.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then sliding = false end end))
	refreshers[#refreshers + 1] = draw
end

local function dropdown(X, label, key, opts)
	txt(X.f, label, UDim2.new(1, 0, 0, 14)).LayoutOrder = nextOrder(X)
	local box = Instance.new("TextButton")
	box.Size = UDim2.new(1, 0, 0, 28); box.BackgroundColor3 = T.panel2; box.BorderSizePixel = 0; box.AutoButtonColor = false
	box.Text = ""; box.LayoutOrder = nextOrder(X); box.Parent = X.f
	stroke(box); corner(box, 6)
	local cur = txt(box, tostring(C[key]), UDim2.new(1, -34, 1, 0)); cur.Position = UDim2.fromOffset(10, 0)
	local arr = txt(box, "▼", UDim2.new(0, 14, 1, 0), T.dim); arr.Position = UDim2.new(1, -22, 0, 0); arr.TextSize = 10
	local list = Instance.new("Frame")
	list.Size = UDim2.new(1, 0, 0, 0); list.AutomaticSize = Enum.AutomaticSize.Y; list.BackgroundColor3 = T.bg
	list.BorderSizePixel = 0; list.Visible = false; list.LayoutOrder = nextOrder(X); list.Parent = X.f
	stroke(list); corner(list, 6)
	Instance.new("UIListLayout", list).SortOrder = Enum.SortOrder.LayoutOrder
	local items = {}
	local function paint() for i, b in ipairs(items) do b.TextColor3 = (opts[i] == C[key]) and T.accent or T.dim end end
	for i, o in ipairs(opts) do
		local b = Instance.new("TextButton")
		b.Size = UDim2.new(1, 0, 0, 22); b.BackgroundTransparency = 1; b.Font = T.font; b.TextSize = 12
		b.Text = "   " .. o; b.TextXAlignment = Enum.TextXAlignment.Left; b.LayoutOrder = i; b.Parent = list
		items[i] = b
		b.MouseButton1Click:Connect(function()
			C[key] = o; cur.Text = o; list.Visible = false; arr.Text = "▼"; paint(); syncCfg()
		end)
	end
	paint()
	refreshers[#refreshers + 1] = function() cur.Text = tostring(C[key]); paint() end
	box.MouseButton1Click:Connect(function() list.Visible = not list.Visible; arr.Text = list.Visible and "▲" or "▼" end)
end

local function button(X, label, fn)
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(1, 0, 0, 26); b.BackgroundColor3 = T.panel2; b.BorderSizePixel = 0; b.AutoButtonColor = false
	b.Font = T.font; b.TextSize = 12; b.TextColor3 = T.text; b.Text = label; b.LayoutOrder = nextOrder(X); b.Parent = X.f
	stroke(b); corner(b, 6)
	b.MouseButton1Click:Connect(function() task.spawn(fn) end)
	b.MouseEnter:Connect(function() b.TextColor3 = T.accent end)
	b.MouseLeave:Connect(function() b.TextColor3 = T.text end)
	return b
end

-- Textfeld: speichert beim Verlassen (Enter/Klick daneben) ueber setter; setter gibt Statustext zurueck
local function textbox(X, label, placeholder, getter, setter)
	txt(X.f, label, UDim2.new(1, 0, 0, 14)).LayoutOrder = nextOrder(X)
	local tb = Instance.new("TextBox")
	tb.Size = UDim2.new(1, 0, 0, 28); tb.BackgroundColor3 = T.panel2; tb.BorderSizePixel = 0
	tb.Font = T.font; tb.TextSize = 12; tb.TextColor3 = T.text; tb.PlaceholderText = placeholder
	tb.PlaceholderColor3 = T.dim; tb.ClearTextOnFocus = false; tb.TextXAlignment = Enum.TextXAlignment.Left
	tb.TextTruncate = Enum.TextTruncate.AtEnd; tb.Text = getter() or ""; tb.LayoutOrder = nextOrder(X); tb.Parent = X.f
	stroke(tb); corner(tb, 6)
	local pd = Instance.new("UIPadding", tb); pd.PaddingLeft = UDim.new(0, 10); pd.PaddingRight = UDim.new(0, 10)
	local st = txt(X.f, "", UDim2.new(1, 0, 0, 12), T.dim); st.TextSize = 11; st.LayoutOrder = nextOrder(X)
	tb.FocusLost:Connect(function()
		local ok, msg = pcall(setter, tb.Text)
		st.Text = ok and tostring(msg or "gespeichert") or ("Fehler: " .. tostring(msg))
		tb.Text = getter() or ""
	end)
	return tb
end

local function info(X, text, color)
	local l = txt(X.f, text, UDim2.new(1, 0, 0, 0), color or T.dim)
	l.AutomaticSize = Enum.AutomaticSize.Y; l.TextWrapped = true; l.RichText = true; l.TextSize = 12
	l.LayoutOrder = nextOrder(X)
	return l
end

----------------------------------------------------------------- Seiten
local TAGS = { [0] = "E-", "E", "E+", "D-", "D", "D+", "C-", "C", "C+", "B-", "B", "B+", "A-", "A", "A+", "S-" }
local function pct(v) return v .. "%" end
local FARM_MISSIONS = {
	"Shiganshina · Skirmish", "Outskirts · Skirmish", "Chapel · Skirmish", "Trost · Skirmish",
	"Docks · Skirmish", "Stohess · Skirmish", "Utgard · Skirmish", "Forest · Skirmish",
	"Shiganshina · Breach", "Outskirts · Escort", "Trost · Protect", "Docks · Stall", "Utgard · Defend", "Forest · Guard",
	"Stohess · Female Titan", "Trost · Attack Titan", "Shiganshina · Armored Titan", "Shiganshina · Colossal Titan",
}

local cL, cR = tab("Combat")
local fL, fR = tab("Farm")
local mL, mR = tab("Movement")
local lL, lR = tab("Lobby")
local vL, vR = tab("Visuals")
local xL, xR = tab("Misc")

-- ===== Combat =====
local A1 = section(cL, "Kill Aura")
toggle(A1, "Kill Aura (Nape)  [K]", "KillAura")
toggle(A1, "Smart (Server-Limit, empfohlen)", "SmartAura")
slider(A1, "Smart: Slash alle", "SmartGap", 0.9, 8, 0.1, function(v) return v .. " s" end)
slider(A1, "Nachladen ab Klingen", "ReloadAt", 1, 6, 1, function(v) return v .. " / 7" end)
slider(A1, "Reichweite", "AuraRange", 50, 20000, 50, function(v) return v >= 20000 and "Unendlich" or (v .. " st") end)
info(A1, "Ohne Smart:")
slider(A1, "Titanen pro Slash", "PerCycle", 1, 30, 1)
slider(A1, "Intervall", "Interval", 0.05, 3, 0.05, function(v) return v .. " s" end)
slider(A1, "Gleicher Titan erst wieder nach", "HitCD", 0.05, 2, 0.05, function(v) return v .. " s" end)

local A2 = section(cR, "Klingen")
toggle(A2, "Auto-Reload", "AutoReload")
toggle(A2, "Auto-Refill (remote)", "AutoRefill")
toggle(A2, "Klingen nie leer", "InfBlades")
button(A2, "Jetzt nachladen", function() GET:InvokeServer("Blades", "Reload") end)
button(A2, "Jetzt auffuellen (Refill)", function()
	local rf = nearestRefill()
	if rf then POST:FireServer("Attacks", "Reload", rf) end
end)
local A3 = section(cR, "Schutz")
toggle(A3, "Ausweichen: Boss <450 / Titan <120 Studs", "BossEvade")
toggle(A3, "Auto Grab-Escape (QTE)", "AutoEscape")
toggle(A3, "Kein Fall-Ragdoll", "NoRagdoll")

-- ===== Farm (Mission/Raid) =====
local F1 = section(fL, "Auto-Farm")
toggle(F1, "Auto-Farm (Aura + Retry/Lobby-Entscheidung)", "AutoFarm")
toggle(F1, "SPEED MODE (max. Runden/h)", "SpeedMode")
dropdown(F1, "Mission / Raid", "FarmMission", FARM_MISSIONS)
dropdown(F1, "Missionswahl in der Lobby", "FarmPick", { "Fest", "Beste Mission", "Bester Raid", "Bonus-Map" })
local LOBBY_ID = 14916516914
local function goPick(mode)
	C.FarmPick = mode
	C.AutoStart = true
	syncCfg()
	for _, f in ipairs(refreshers) do pcall(f) end
	if game.PlaceId == LOBBY_ID then
		Cfg:SetAttribute("FarmReq", os.clock())
	else
		-- in der Mission: zur Lobby, dort waehlt + startet Auto-Start mit dem Modus
		Cfg:SetAttribute("FarmStatus", mode .. " -> Lobby")
		POST:FireServer("Functions", "Teleport")
	end
end
S.goPick = goPick
button(F1, "Beste Mission joinen", function() goPick("Beste Mission") end)
button(F1, "Besten Raid joinen", function() goPick("Bester Raid") end)
button(F1, "Bonus-Map joinen", function() goPick("Bonus-Map") end)
local boostL = info(F1, "")
slider(F1, "Bis Grade", "FarmMaxGrade", 2, 15, 1, function(v) return TAGS[v] or tostring(v) end)
toggle(F1, "Ohne Klingen+Refills -> Lobby", "StuckLeave")
local farmL = info(F1, "Status: -")
info(F1, "Am Ende: Retry, oder Lobby sobald das Gold fuer die naechste Schwierigkeit reicht.")

local F2 = section(fL, "Modifier")
toggle(F2, "Harte Modifier (+Gold/XP)", "FarmMods")
toggle(F2, "  · Oddball (+50% Titan-Stats)", "ModOddball")
toggle(F2, "  · Time Trial (+/-15%)", "ModTimeTrial")
toggle(F2, "  · Glass Cannon (1 HP)", "ModGlass")
info(F2, "Speed: Simple, Boring, Time Trial, Fog, Injury Prone, Chronic Injuries, Glass Cannon.\nRaids: Luck-Satz ohne Oddball (Phase 1 haelt sonst nicht).")

local F3 = section(fR, "Raid")
toggle(F3, "Boss-Fokus (Rest-Treffer auf Boss)", "BossFocus")
toggle(F3, "Auto-QTE", "AutoQTE")
toggle(F3, "Cutscenes automatisch skippen", "AutoSkip")
toggle(F3, "Premium-Truhe (Emperor's Key)", "PremiumChest")
info(F3, "Phase 1: Titanen am naechsten am Verteidigungsziel zuerst.")

local F4 = section(fR, "Missionsende")
toggle(F4, "Auto-Truhen (nur Raids)", "AutoChest")
toggle(F4, "Auto Retry (ohne Auto-Farm)", "AutoRetry")
button(F4, "Retry jetzt", function() GET:InvokeServer("Functions", "Retry", "Add") end)
button(F4, "Zur Lobby", function() POST:FireServer("Functions", "Teleport") end)

-- ===== Movement =====
local M1 = section(mL, "ODM Gear")
toggle(M1, "Unendlich Gas", "InfGas")
toggle(M1, "Unendliche Grapple-Range", "InfRange")
toggle(M1, "Gear-Shift Speedcap aus", "GearUncap")
slider(M1, "ODM Speed", "SpeedPct", 0, 200, 5, pct)
slider(M1, "ODM Control", "ControlPct", 0, 100, 5, pct)
slider(M1, "ODM Range", "RangePct", 0, 200, 5, pct)
slider(M1, "ODM Gas (Max)", "GasPct", 0, 200, 5, pct)
slider(M1, "Extra Boost-Dashes", "Dashes", 0, 5, 1)
local M2 = section(mR, "Familien-Buff")
dropdown(M2, "Familie emulieren", "Family", FAM_ORDER)
info(M2, "Bewegungs-Passives lokal, stapelt mit den Slidern.\nAckerman: +10% Control/Gas/Range, +1 Dash\nHelos: +15% alles, +1 Dash\nShiki: +10% Control/Gas/Range, +2 Dash\nZoe: +10% Speed/Control")

-- ===== Lobby =====
local L0 = section(lL, "Auto-Start")
toggle(L0, "Auto-Start aus der Lobby", "AutoStart")
button(L0, "Jetzt Mission starten", function() Cfg:SetAttribute("FarmReq", os.clock()) end)
info(L0, "Build -> Upgrade bis 'Bis Grade' -> hoechste Schwierigkeit + Modifier -> Start (Mission im Farm-Tab).")

local LP0 = section(lL, "Auto-Prestige")
toggle(LP0, "Automatisch prestigen (Level-Cap erreicht)", "AutoPrestige")
dropdown(LP0, "Boost", "PrestigeBoost", { "Luck", "XP", "Gold" })
local presL = info(LP0, "Prestige-ETA: -")
info(LP0, "Reset: Level, Skilltree, Grade. Gold -> Gems. Log: aot_prestige_log.txt")

local L1 = section(lL, "Auto-Upgrade (Grade)")
slider(L1, "Ziel-Grade", "UpgTarget", 1, 15, 1, function(v) return TAGS[v] or tostring(v) end)
button(L1, "Auto-Upgrade starten", function() Cfg:SetAttribute("UpgReq", os.clock()) end)
toggle(L1, "Bei jedem Lobby-Join", "AutoUpgrade")
local upgL = info(L1, "Status: -")
info(L1, "Missionen: E+ Normal · D+ Hard · B- Severe · A- Aberrant\nRaids: C- Hard · B Severe · A Aberrant")
toggle(L1, "Gold-Sink: Restgold in Schaden/Crit/Haltbarkeit (bis 15)", "GoldSink")
slider(L1, "Gold-Reserve behalten", "GoldReserve", 0, 1000000, 50000, function(v) return v >= 1000 and (math.floor(v / 1000) .. "k") or tostring(v) end)
info(L1, "Nach dem Ziel-Grade. Lobby-Trip erst, wenn alle 4 Stats +1 bezahlbar sind.")

local LB = section(lL, "Auto-Boost (2x)")
toggle(LB, "Boost aktiv halten (Item nutzen, sonst mit Gems kaufen)", "AutoBoost")
toggle(LB, "  · 2x XP", "BoostXP")
toggle(LB, "  · 2x Gold (schnellere Upgrades)", "BoostGold")
toggle(LB, "  · 2x Luck", "BoostLuck")
slider(LB, "Gems behalten", "BoostGemReserve", 0, 50000, 500, function(v) return v >= 1000 and (string.format("%.1fk", v / 1000)) or tostring(v) end)
local boostLT = info(LB, "")
info(LB, "Reihenfolge XP > Gold > Luck. Kauft das groesste bezahlbare Paket (2h = 13999 Gems, guenstigster Preis pro Minute).")

local L3 = section(lL, "Auto-Build")
button(L3, "Skills + Perks jetzt optimieren", function() Cfg:SetAttribute("BuildReq", os.clock()) end)
toggle(L3, "Vor jedem Auto-Start", "AutoBuild")
local bldL = info(L3, "Status: -")

local L2 = section(lR, "Claim All")
button(L2, "Alles claimen", function() Cfg:SetAttribute("ClaimReq", os.clock()) end)
toggle(L2, "Bei jedem Lobby-Join", "AutoClaim")
local clmL = info(L2, "Status: -")

local R1 = section(lR, "Family Auto-Roll")
toggle(R1, "Deposit-Modus (einlagern statt stoppen)", "RollDeposit")
dropdown(R1, "Einlagern ab", "RollStartTier", { "Rare", "Epic", "Legendary", "Mythic" })
info(R1, "Ohne Deposit: stoppt bei:")
for _, rar in ipairs({ "Common", "Rare", "Epic", "Legendary", "Mythic", "Secret" }) do toggle(R1, rar, "RollStop_" .. rar) end
button(R1, "Auto-Roll Start / Stop", function() autoRoll() end)
local rollL = info(R1, "Status: -")
info(R1, "1 Roll / ~3.4s. Jeder Roll ERSETZT die aktuelle Familie.")

-- ===== Visuals =====
local V1 = section(vL, "ESP")
toggle(V1, "Titan ESP (Nape + Distanz)", "ESP")
local V2 = section(vR, "Lighting")
toggle(V2, "Fullbright", "Fullbright")
toggle(V2, "Kein Nebel", "NoFog")

-- ===== Misc =====
local W1 = section(xL, "Discord-Webhook")
toggle(W1, "Jede Runde melden (Ping nur bei selten)", "Webhook")
dropdown(W1, "Ping ab", "WebhookMin", { "Epic", "Legendary", "Mythic", "Secret" })
button(W1, "Test-Nachricht", function()
	Cfg:SetAttribute("DropEvent", HS:JSONEncode({ items = { { name = "Test-Item", rarity = "Mythic", src = "Test", rare = true } }, map = "Test", diff = "-", type = "Test", t = os.time() }))
end)
textbox(W1, "Webhook-URL", "https://discord.com/api/webhooks/...", function()
	local u = whURL()
	return u and (#u > 48 and (u:sub(1, 48) .. "…") or u) or ""
end, function(v)
	v = v:gsub("%s+", "")
	if v == "" then
		pcall(delfile, "aot_wh_url.txt")
		return "geloescht" .. (whURL() and " (blox_wh_url.txt bleibt aktiv)" or "")
	end
	if v:sub(-3) == "…" or v == whURL() then return "unveraendert" end
	if not (v:match("^https://") and v:find("/webhooks/")) then error("keine Discord-Webhook-URL", 0) end
	writefile("aot_wh_url.txt", v)
	return "gespeichert"
end)
textbox(W1, "Ping (Discord-User-ID, leer = @everyone)", "123456789012345678", function()
	local ok, v = pcall(function() return isfile("aot_wh_ping.txt") and readfile("aot_wh_ping.txt") end)
	return ok and type(v) == "string" and v:match("%d+") or ""
end, function(v)
	v = v:gsub("%s+", "")
	if v == "" then pcall(delfile, "aot_wh_ping.txt") return "Ping: @everyone" end
	if not v:match("^%d%d%d%d%d+$") then error("nur die Ziffern-ID", 0) end
	writefile("aot_wh_ping.txt", v)
	return "Ping: <@" .. v .. ">"
end)
info(W1, "Serums/Keys pingen immer.")
local X2 = section(xL, "Sonstiges")
toggle(X2, "Anti-AFK", "AntiAFK")
button(X2, "Raffir-Einstellungen laden", function()
	applyPreset()
	syncCfg()
	for _, f in ipairs(refreshers) do pcall(f) end
	Cfg:SetAttribute("FarmStatus", "Raffir-Einstellungen geladen")
end)
button(X2, "Actor neu injizieren", function() injectActor() end)
button(X2, "Hub beenden", function() S.Kill() end)
local infoL = info(X2, "")
info(X2, "RightShift = Menue · K = Kill Aura")
local X0 = section(xR, "Truhen-Log")
local chestL = info(X0, "-")

-- Einklappen
local colBtn = Instance.new("TextButton")
colBtn.Size = UDim2.fromOffset(22, 22); colBtn.AnchorPoint = Vector2.new(1, 0); colBtn.Position = UDim2.new(1, -8, 0, 4)
colBtn.BackgroundTransparency = 1; colBtn.Font = T.font; colBtn.TextSize = 16; colBtn.TextColor3 = T.dim; colBtn.ZIndex = 3; colBtn.Parent = main
local function applyCollapse()
	tabBar.Visible = not C.Collapsed; content.Visible = not C.Collapsed
	main.Size = UDim2.fromOffset(main.Size.X.Offset, C.Collapsed and 30 or FULL_H)
	colBtn.Text = C.Collapsed and "+" or "–"
end
applyCollapse()
colBtn.MouseButton1Click:Connect(function() C.Collapsed = not C.Collapsed; applyCollapse(); saveCfg() end)
colBtn.MouseEnter:Connect(function() colBtn.TextColor3 = T.accent end)
colBtn.MouseLeave:Connect(function() colBtn.TextColor3 = T.dim end)

selectTab(C.Tab)

----------------------------------------------------------------- Status / Keys
task.spawn(function()
	while S.alive do
		local ref = LP:GetAttribute("Refills")
		local tf = workspace:FindFirstChild("Titans")
		statusL.Text = tf and string.format("K %d · Kl %d/7 · R %s · T %d", S.kills, bladesLeft(), tostring(ref or "-"), #tf:GetChildren()) or "Lobby"
		infoL.Text = "Map: " .. tostring(workspace:GetAttribute("Objective") or "-") .. " / " .. tostring(workspace:GetAttribute("Difficulty") or "-") .. "\nCredit: " .. tostring(LP:GetAttribute("Stat") or 0) .. "% · Level " .. tostring(LP:GetAttribute("Level"))
		upgL.Text = "Status: " .. tostring(Cfg:GetAttribute("UpgStatus") or "-")
		clmL.Text = "Status: " .. tostring(Cfg:GetAttribute("ClaimStatus") or "-")
		farmL.Text = "Status: " .. tostring(Cfg:GetAttribute("FarmStatus") or "-")
		bldL.Text = "Status: " .. tostring(Cfg:GetAttribute("BuildStatus") or "-")
		do
			local bf = LP:FindFirstChild("Boosts")
			local parts = {}
			for _, k in ipairs({ "XP", "Gold", "Luck" }) do
				local v = bf and bf:FindFirstChild(k)
				local t = v and tonumber(v.Value) or 0
				if t > 0 then parts[#parts + 1] = string.format("%s %d:%02d", k, t // 60, t % 60) end
			end
			boostLT.Text = "Aktiv: " .. (#parts > 0 and table.concat(parts, " · ") or "keiner")
		end
		local bm, bt = workspace:GetAttribute("Boosted_Map"), workspace:GetAttribute("Boosted_Timer")
		if bm then
			bt = math.max(tonumber(bt) or 0, 0)
			boostL.Text = string.format("Bonus-Map: <b>%s</b> (noch %d:%02d) · Beste Mission = Bonus-Map (Skirmish, hoechste Schwierigkeit)", bm, bt // 60, bt % 60)
		elseif workspace:GetAttribute("Boosted") ~= nil then
			boostL.Text = "Diese Mission: " .. (workspace:GetAttribute("Boosted") and "<b>Bonus aktiv</b>" or "kein Bonus") .. " · Buttons gehen ueber die Lobby"
		else
			boostL.Text = "Bonus-Map wird in der Lobby angezeigt."
		end
		chestL.Text = "Truhen: " .. tostring(Cfg:GetAttribute("ChestCount") or 0) .. " · " .. tostring(Cfg:GetAttribute("ChestLog") or "-"):gsub(" || ", "\n")
		rollL.Text = (S.rolling and "<font color=\"#be4696\">ROLLT</font> · " or "") .. tostring(S.rollStatus)
		local etaShort, etaLong = prestigeETA()
		presL.Text = etaLong or "Prestige-ETA: -"
		local fg, fn = Cfg:GetAttribute("FarmGold"), Cfg:GetAttribute("FarmNeed")
		farmHdr.Visible = C.AutoFarm and fg ~= nil
		if farmHdr.Visible then
			local function k(n) n = tonumber(n) or 0 if n >= 1e6 then return string.format("%.2fM", n / 1e6) elseif n >= 1e3 then return string.format("%.1fk", n / 1e3) end return tostring(math.floor(n)) end
			local nx = Cfg:GetAttribute("FarmNext") or "?"
			if nx == "MAX" then
				farmHdr.Text = '<font color="#dab061">Gold ' .. k(fg) .. '</font> · MAX · Lv ' .. tostring(LP:GetAttribute("Level") or "?") .. (etaShort and (' · <font color="#be4696">' .. etaShort .. '</font>') or '')
			else
				local col = fg >= fn and "#7fff50" or "#dab061"
				farmHdr.Text = '<font color="' .. col .. '">Gold ' .. k(fg) .. ' / ' .. k(fn) .. '</font> → ' .. nx .. ' · Lv ' .. tostring(LP:GetAttribute("Level") or "?") .. (etaShort and (' · <font color="#be4696">' .. etaShort .. '</font>') or '')
			end
		end
		task.wait(0.4)
	end
end)

-- Missionswahl im Actor setzt FarmMission -> Dropdown + gespeicherte Config nachziehen
conn(Cfg:GetAttributeChangedSignal("FarmPick"):Connect(function()
	local v = Cfg:GetAttribute("FarmPick")
	if type(v) == "string" and v ~= C.FarmPick then
		C.FarmPick = v
		saveCfg()
		for _, f in ipairs(refreshers) do pcall(f) end
	end
end))
conn(Cfg:GetAttributeChangedSignal("FarmMission"):Connect(function()
	local v = Cfg:GetAttribute("FarmMission")
	if type(v) == "string" and v ~= C.FarmMission then
		C.FarmMission = v
		saveCfg()
		for _, f in ipairs(refreshers) do pcall(f) end
	end
end))

conn(UIS.InputBegan:Connect(function(i, gp)
	if gp then return end
	if i.KeyCode == Enum.KeyCode.RightShift then
		main.Visible = not main.Visible
		C.UIVisible = main.Visible
		saveCfg()
	elseif i.KeyCode == Enum.KeyCode.K then
		C.KillAura = not C.KillAura
		saveCfg()
		for _, f in ipairs(refreshers) do f() end
	end
end))

----------------------------------------------------------------- Kill
function S.Kill()
	S.alive = false
	for _, c in ipairs(S.conns) do pcall(function() c:Disconnect() end) end
	S.conns = {}
	clearESP()
	C.Fullbright, C.NoFog = false, false
	pcall(visuals)
	Cfg:SetAttribute("Shutdown", true)
	if S.gui then S.gui:Destroy() end
end

return "AOT:R HUB geladen"
