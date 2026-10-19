-- AOT:R HUB  (Attack on Titan Revolution)
-- Start: loadstring(readfile("aot_hub.lua"))()     UI an/aus: RightShift   Kill-Aura: K
-- Main-VM: GUI, Kill-Aura, Blades/Refill, ESP, Visuals, Misc
-- Actor-VM (Character.Actor): Gas/ODM-Stats/Familien-Buffs, Anti-Ragdoll, Auto-Grab-Escape, Auto-Chest/Retry

local HUB_VERSION = "2026-10-16a"
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

-- Phasen-Log (Messung Rundenzyklus): ms-Zeitstempel, gepuffert, alle 0.5s angehaengt (nie writefile pro Event)
S.ph = {}
local function PH(ev, info)
	S.ph[#S.ph + 1] = string.format("%.3f,main,%s,%d,%s\n", DateTime.now().UnixTimestampMillis / 1000, ev, game.PlaceId, (tostring(info or ""):gsub("[,%c]", ";")))
end
S.PH = PH
local function phFlush()
	if #S.ph == 0 then return end
	local b = table.concat(S.ph)
	S.ph = {}
	pcall(function()
		if isfile("aot_phase.csv") then appendfile("aot_phase.csv", b) else writefile("aot_phase.csv", "t,vm,ev,place,info\n" .. b) end
	end)
end
task.spawn(function()
	while S.alive do task.wait(0.5) phFlush() end
end)

----------------------------------------------------------------- Config
local C = {
	KillAura = false, AuraRange = 5000, PerCycle = 3, Interval = 0.6, NapeOnly = true, HitCD = 1.1, SmartAura = true, AutoCannon = true, SpawnBait = false, AutoCast = true, WaveReady = true, WaveSkip = true, WaveUpgrades = true, WaveSwords = true, WaveBless = true, WaveMarket = true, WaveEquip = true, WaveSafe = true, ProfileName = "", FarmMode = "",  WaveSafeHeight = 350, WaveSwordGold = 1500, BossSkills = true, BossSkillFar = true, BaitHeight = 90, EvadeRange = 400, BossEvadeRange = 900, BossSafeDist = 1300, SafeSpot = false, SafeSpotDist = 250, SelfDefRange = 120, ErenGuard = true, ErenGuardRange = 300, CoopRole = "Solo", CannonMulti = 100,
	AutoReload = true, AutoRefill = true,
	InfGas = false, InfRange = false, InfBlades = false, SpeedPct = 0, ControlPct = 0, RangePct = 0, GasPct = 0, Dashes = 0, GearUncap = false,
	Family = "Keine",
	NoRagdoll = false, AutoEscape = false,
	ESP = false, Fullbright = false, NoFog = false,
	AntiAFK = true, AutoChest = false, AutoRetry = false, UpgTarget = 2, AutoUpgrade = false,
	UIX = -1, UIY = -1, UIVisible = true, Tab = "Combat", Collapsed = false, AutoClaim = false,
	AutoFarm = false, AuraToggleFix = false, AutoStart = true, AutoPrestige = false, PrestigeBoost = "Luck", FarmMission = "Shiganshina · Skirmish", FarmPick = "Fest", FarmMods = true, FarmMaxGrade = 12, ModOddball = false, ModTimeTrial = true, ModGlass = true, ModGlassRaid = false, ModTimeTrialRaid = true, SmartGap = 1.2, ReloadAt = 4, MaxHits = 16, FillHits = true, BladeSaver = false, GoldSink = true, GoldReserve = 0, AutoBoost = false, AutoKeys = false, KeyTarget = 15, AutoScrolls = false, ScrollTarget = 999, BonusAlways = false, BoostType = "XP", BoostXP = true, BoostGold = false, BoostLuck = false, BoostGemReserve = 0, BoostSafety = false, SellPerks = false, EnhancePerks = true, SellPerksUpTo = "Rare", SellPerksFrom = 1500, LowPower = false, LowPowerFPS = 30, StuckLeave = true, AutoBuild = true, SpeedMode = false, SpeedFromAberrant = false, Webhook = true, WebhookMin = "Legendary", WebhookRareOnly = false, BossFocus = true, BossEvade = true, AutoSkip = true, AutoQTE = true, PremiumChest = false, AutoSpears = true, CrateSel = "Alle", CrateGap = 0.15, AutoCodes = true,
	RollDeposit = true, RollGap = 0.55, RollStartTier = "Epic", RollStop_Common = false, RollStop_Rare = false, RollStop_Epic = false, RollStop_Legendary = true, RollStop_Mythic = true, RollStop_Secret = true,
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
	KillAura = true, MaxHits = 16, ModGlass = true, ModOddball = true, ModTimeTrial = true, NapeOnly = true, NoFog = false,
	NoRagdoll = false, PerCycle = 10, PrestigeBoost = "Luck", RangePct = 0, ReloadAt = 4,
	RollDeposit = true, RollStartTier = "Epic", RollStop_Common = false, RollStop_Epic = false,
	RollStop_Legendary = true, RollStop_Mythic = true, RollStop_Rare = false, RollStop_Secret = true,
	SmartAura = true, SmartGap = 1.2, SpeedMode = false, SpeedPct = 0, StuckLeave = true, UpgTarget = 12,
	Webhook = true, WebhookMin = "Legendary", AutoCodes = true,
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
-- einmalig: wer Auto-Farm schon an hatte, lief bisher mit Aura (auch bei KillAura=false) -> nicht ploetzlich stillstehen
if not C.AuraToggleFix then
	if C.AutoFarm then C.KillAura = true end
	C.AuraToggleFix = true
end
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
-- Farm-Modus (Aufraeumen 19.10.): nur noch 3 Modi, intern weiter FarmPick/FarmMission
local MODE_MISSION = { ["Colossal-Raid"] = "Shiganshina · Colossal Titan", ["Waves"] = "Trost · Waves" }
local function modeFrom(pick, mission)
	mission = tostring(mission or "")
	if pick == "Fest" and mission:find("Colossal") then return "Colossal-Raid" end
	if pick == "Fest" and mission:find("Waves") then return "Waves" end
	return "Beste Mission"
end
S.modeFrom = modeFrom
local function syncCfg()
	if (C.FarmMode or "") == "" then C.FarmMode = modeFrom(C.FarmPick, C.FarmMission) end
	C.BonusAlways = false
	if MODE_MISSION[C.FarmMode] then
		C.FarmPick = "Fest"
		C.FarmMission = MODE_MISSION[C.FarmMode]
	else
		C.FarmPick = "Beste Mission"
	end
	-- ohne Schalter (Aufraeumen 19.10.): fest auf die gemessenen Bestwerte, Raids immer solo
	C.SmartAura, C.AuraRange, C.SmartGap, C.MaxHits, C.FillHits, C.BladeSaver = true, 20000, 1.2, 16, true, false
	C.CoopRole, C.BossFocus, C.AutoQTE, C.AutoCannon, C.AutoCast, C.AutoSkip = "Solo", true, true, true, true, true
	C.SpawnBait, C.SafeSpot = false, false
	C.InfGas, C.InfRange, C.GearUncap = true, true, true
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
	Cfg:SetAttribute("AutoKeys", C.AutoKeys)
	Cfg:SetAttribute("KeyTarget", C.KeyTarget)
	Cfg:SetAttribute("AutoScrolls", C.AutoScrolls)
	Cfg:SetAttribute("ScrollTarget", C.ScrollTarget)
	Cfg:SetAttribute("BoostXP", C.BoostXP)
	Cfg:SetAttribute("BoostGold", C.BoostGold)
	Cfg:SetAttribute("BoostLuck", C.BoostLuck)
	Cfg:SetAttribute("BoostGemReserve", C.BoostGemReserve)
	Cfg:SetAttribute("SellPerks", C.SellPerks)
	Cfg:SetAttribute("SellPerksUpTo", C.SellPerksUpTo)
	Cfg:SetAttribute("EnhancePerks", C.EnhancePerks)
	Cfg:SetAttribute("SellPerksFrom", C.SellPerksFrom)
	Cfg:SetAttribute("FarmMods", C.FarmMods)
	Cfg:SetAttribute("AutoBuild", C.AutoBuild)
	Cfg:SetAttribute("SpeedMode", C.SpeedMode)
	Cfg:SetAttribute("SpeedFromAberrant", C.SpeedFromAberrant)
	Cfg:SetAttribute("AutoQTE", C.AutoQTE)
	Cfg:SetAttribute("AutoSkip", C.AutoSkip)
	Cfg:SetAttribute("AutoCannon", C.AutoCannon)
	Cfg:SetAttribute("AutoCast", C.AutoCast)
	Cfg:SetAttribute("BossSkills", C.BossSkills)
	Cfg:SetAttribute("WaveReady", C.WaveReady)
	Cfg:SetAttribute("WaveSkip", C.WaveSkip)
	Cfg:SetAttribute("WaveUpgrades", C.WaveUpgrades)
	Cfg:SetAttribute("WaveSwords", C.WaveSwords)
	Cfg:SetAttribute("WaveBless", C.WaveBless)
	Cfg:SetAttribute("WaveMarket", C.WaveMarket)
	Cfg:SetAttribute("WaveEquip", C.WaveEquip)
	Cfg:SetAttribute("WaveSwordGold", C.WaveSwordGold)
	Cfg:SetAttribute("BossSkillFar", C.BossSkillFar)
	Cfg:SetAttribute("AutoSpears", C.AutoSpears)
	Cfg:SetAttribute("WebhookMin", C.WebhookMin)
	Cfg:SetAttribute("PremiumChest", C.PremiumChest)
	local skip = {}
	if not C.ModOddball then skip[#skip + 1] = "Oddball" end
	if not C.ModTimeTrial then skip[#skip + 1] = "Time Trial" end
	if not C.ModGlass then skip[#skip + 1] = "Glass Cannon" end
	Cfg:SetAttribute("SkipMods", table.concat(skip, ","))
	Cfg:SetAttribute("ModGlassRaid", C.ModGlassRaid)
	Cfg:SetAttribute("ModTimeTrialRaid", C.ModTimeTrialRaid)
	Cfg:SetAttribute("FarmMaxGrade", C.FarmMaxGrade)
end
S.syncCfg = syncCfg
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
	if a == "Effects" and b == "Sound" and c == "Hit_Kill" then S.kills = S.kills + 1 PH("KILL", S.kills)
	elseif a ~= "Effects" then PH("EVT", tostring(a) .. "/" .. tostring(b) .. "/" .. tostring(c)) end
end))
PH("HUB_START", HUB_VERSION)
do
	local f = "aot_exp_" .. LP.Name .. ".json"
	local ok, plan = pcall(function() return isfile(f) and HS:JSONDecode(readfile(f)) end)
	if ok and type(plan) == "table" and plan.active and type(plan.variants) == "table" and #plan.variants > 0
		and game.PlaceId ~= 14916516914 then
		plan.idx = (plan.idx or 0) + 1
		if plan.idx > (plan.rounds or 12) then
			plan.active = false
			for k, v in pairs(plan.restore or {}) do C[k] = v end
			PH("EXP_END", plan.idx - 1)
		else
			local vn = (plan.idx - 1) % #plan.variants + 1
			local v = plan.variants[vn]
			for k, x in pairs(v) do if k ~= "name" then C[k] = x end end
			PH("VARIANT", tostring(v.name or vn))
		end
		pcall(writefile, f, HS:JSONEncode(plan))
	end
end
for _, k in ipairs({ "Rewarded", "Force_End", "Starting", "Type", "Boosted" }) do
	conn(workspace:GetAttributeChangedSignal(k):Connect(function() PH("WS_" .. k, workspace:GetAttribute(k)) end))
end
do -- Rundenuhr: nur Start (erster Tick nach Reset) und Reset loggen, nicht jede Sekunde
	local lastSec
	conn(workspace:GetAttributeChangedSignal("Seconds"):Connect(function()
		local v = tonumber(workspace:GetAttribute("Seconds"))
		if v and lastSec and v < lastSec then PH("SEC_RESET", lastSec .. ">" .. v) end
		if v and (not lastSec or v < lastSec) then PH("SEC_RUN", v) end
		lastSec = v
	end))
end
for _, k in ipairs({ "Teleporting", "Refills" }) do
	conn(LP:GetAttributeChangedSignal(k):Connect(function() PH("LP_" .. k, LP:GetAttribute(k)) end))
end
do -- Shifter-Leiste: nur ganze Prozent-Schritte loggen
	local lastBar
	conn(LP:GetAttributeChangedSignal("Bar"):Connect(function()
		local v = tonumber(LP:GetAttribute("Bar"))
		local f = v and math.floor(v)
		if f ~= lastBar then lastBar = f PH("BAR", tostring(f) .. "/" .. tostring(LP:GetAttribute("Max_Bar"))) end
	end))
end
do
	local tconn = {}
	local function watchTitans(tf)
		for _, c in ipairs(tconn) do pcall(function() c:Disconnect() end) end
		tconn = {}
		if not tf then return end
		PH("TITANS_FOLDER", #tf:GetChildren())
		tconn[1] = conn(tf.ChildAdded:Connect(function() if #tf:GetChildren() == 1 then PH("TITAN_FIRST", 1) end end))
		tconn[2] = conn(tf.ChildRemoved:Connect(function() if #tf:GetChildren() == 0 then PH("TITANS_ZERO", 0) end end))
	end
	watchTitans(workspace:FindFirstChild("Titans"))
	conn(workspace.ChildAdded:Connect(function(c) if c.Name == "Titans" then watchTitans(c) end end))
end

----------------------------------------------------------------- Actor-Payload
local ACTOR_CODE = [==[
local CG = game:GetService("CoreGui")
local cfg = CG:WaitForChild("AOTHubCfg", 10)
if not cfg then return end
if _G.AOTA and _G.AOTA.Kill then pcall(_G.AOTA.Kill) end
local A = { on = true, ph = {} }
_G.AOTA = A
-- Phasen-Log (Actor): gleiches Format wie Main-VM, eigener Puffer
local function PH(ev, info)
	A.ph[#A.ph + 1] = string.format("%.3f,actor,%s,%d,%s", DateTime.now().UnixTimestampMillis / 1000, ev, game.PlaceId, (tostring(info or ""):gsub("[,%c]", ";"))) .. string.char(10)
end
local function phFlush()
	if #A.ph == 0 then return end
	local b = table.concat(A.ph)
	A.ph = {}
	pcall(function() if isfile("aot_phase.csv") then appendfile("aot_phase.csv", b) else writefile("aot_phase.csv", "t,vm,ev,place,info" .. string.char(10) .. b) end end)
end
task.spawn(function() while A.on do task.wait(0.5) phFlush() end end)
function A.Kill()
	phFlush()
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
-- Speed-Modus aktiv: von Hand oder automatisch, sobald Aberrant erreicht ist (Grade 12 / Aberrant-Runde)
local function speedOn()
	if cfg:GetAttribute("SpeedMode") then return true end
	return cfg:GetAttribute("SpeedFromAberrant") == true
		and ((cfg:GetAttribute("FarmGrade") or 0) >= 12 or workspace:GetAttribute("Difficulty") == "Aberrant")
end
-- Heavenly Restriction ausgeruestet? (Lobby: Slot-Daten, Mission: Loadout)
local function hasHR()
	local ok, r = pcall(function()
		if H.Loadout then return (tonumber(M.Shared.Item_Quantity(H, H.Loadout, "Perks", "Heavenly Restriction")) or 0) > 0 end
		local d = H.Cache.Data
		local sl = d and d.Slots and d.Slots[d.Current_Slot]
		for _, id in pairs(sl and sl.Perks and sl.Perks.Equipped or {}) do
			local p = id ~= "" and sl.Perks.Storage[id]
			if p and p.Name == "Heavenly Restriction" then return true end
		end
		return false
	end)
	return ok and r == true
end
local function wantedMods0()
	local w = {}
	-- Raids: Modifier geben LUCK (halber Wert); Simple/Boring = -20% Luck, Oddball bremst den Boss
	local fm = cfg:GetAttribute("FarmMission") or ""
	-- Colossal-Raid: vorerst ohne Modifier
	if workspace:GetAttribute("Objective") == "Colossal Titan" or fm:find("Colossal") then
		-- Colossal sonst ohne Modifier; Glass Cannon (1 HP) aendert am Ablauf nichts (Ausweichen + Fern-Aura)
		if cfg:GetAttribute("ModGlassRaid") then w["Glass Cannon"] = true end
		-- Time Trial: Limit Colossal (Shiganshina Raid_2, Aberrant) 195s, wir brauchen ~100-160s (Log 18.10.) -> Bonus sicher
		if cfg:GetAttribute("ModTimeTrialRaid") ~= false then w["Time Trial"] = true end
		return w
	end
	if workspace:GetAttribute("Type") == "Raids" or fm:find("Titan$") then
		for _, m in ipairs({ "No Perks", "No Skills", "No Memories", "Nightmare", "Injury Prone", "Chronic Injuries", "Fog", "Glass Cannon" }) do w[m] = true end
		return w
	end
	if speedOn() then
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
-- ohne Einfluss auf unsere Farm (User 17.10.) -> immer an, auch im Speed-Modus und im Colossal-Raid
local FREE_MODS = { "Chronic Injuries", "Injury Prone", "Fog", "Nightmare" }
local function wantedMods()
	local w = wantedMods0()
	if cfg:GetAttribute("FreeMods") ~= false then for _, m in ipairs(FREE_MODS) do w[m] = true end end
	-- Nightmare (nur Abnormals/Crawler) widerspricht Boring (keine) -> wo Boring gewollt ist (Speed), Nightmare raus.
	-- In Missionen aendern Modifier nur XP/Gold, im Raid geben sie Luck -> dort bleiben die freien Modifier
	if w["Boring"] then w["Nightmare"] = nil end
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
-- naechstes Upgrade-Ziel: naechste Schwierigkeit; ab Aberrant (keine weitere) Grade+1 bis zum eingestellten Max
-- (ohne das ging der Farm ab Grade 12 nie mehr upgraden, wenn das Max hoeher stand)
local function nextGoal(g, maxG)
	local nt, nd = nextThreshold(g)
	if nt and nt <= maxG then return nt, nd end
	if not nt and g < maxG then return g + 1, "Grade " .. (g + 1) end
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
				local nt, nd = nextGoal(g, cfg:GetAttribute("FarmMaxGrade") or 12)
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
	local gems = sl and sl.Currency and sl.Currency.Gems or 0
	local reserve = cfg:GetAttribute("BoostGemReserve") or 0
	-- immer die 2h-Version: eigenes 2h-Item, sonst 2h kaufen (nur 2h, kleinere Pakete sind pro Minute teurer);
	-- vorhandene kleinere Items werden aufgebraucht, wenn fuer 2h die Gems fehlen
	local top = BOOST_SHOP[1]
	local tag2h = "2x " .. kind .. " Boost " .. top[1]
	if (items[tag2h] or 0) > 0 then return "use", tag2h end
	if gems - top[2] >= reserve then return "buy", tag2h, top[2] end
	for i = 2, #BOOST_SHOP do
		local tag = "2x " .. kind .. " Boost " .. BOOST_SHOP[i][1]
		if (items[tag] or 0) > 0 then return "use", tag end
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
-- Auto-Keys (Lobby): Emperor's Keys auf Ziel auffuellen (Market "1_Progression", 2999 Gems). Laeuft NACH Auto-Boost,
-- haelt die Gem-Reserve + einen 2h-Boost (13999) frei, solange Auto-Boost an ist
-- Market-Kauf (Lobby, "1_Progression", 2999 Gems): Item bis Ziel auffuellen; laesst Gem-Reserve + 2h-Boost frei
local function buyMarket(item, target, label)
	task.synchronize()
	local rt, items = GET:InvokeServer("S_Market", "Get")
	local list = type(items) == "table" and items["1_Progression"]
	local idx
	for i, n in pairs(list or {}) do if n == item then idx = i end end
	if not idx then farmStatus(label .. ": nicht im Market") return 0 end
	local bought = 0
	for _ = 1, target do
		local d = H.Cache.Data
		local sl = d and d.Slots and d.Slots[d.Current_Slot]
		local have = sl and sl.Inventory and sl.Inventory.Items and sl.Inventory.Items[item] or 0
		local gems = sl and sl.Currency and sl.Currency.Gems or 0
		local keep = (cfg:GetAttribute("BoostGemReserve") or 0) + (cfg:GetAttribute("AutoBoost") and 13999 or 0)
		if have >= target or gems - 2999 < keep then break end
		local nd = GET:InvokeServer("S_Market", "Buy", "1_Progression", idx, 1)
		if type(nd) ~= "table" then farmStatus(label .. ": Kauf abgelehnt") break end
		if nd.Slots then H.Cache.Data = nd elseif nd.Inventory and d and d.Slots then d.Slots[d.Current_Slot] = nd end
		bought = bought + 1
		task.wait(0.3)
	end
	if bought > 0 then
		task.spawn(pcall, M.Topbar.Refresh, H, H.Cache.Data)
		farmStatus(label .. ": " .. bought .. " gekauft")
	end
	return bought
end
-- Reihenfolge: Boost (vorher) -> Keys bis Ziel -> Scrolls mit dem Rest
local function autoKeys()
	if cfg:GetAttribute("AutoKeys") then buyMarket("Emperor's Key", cfg:GetAttribute("KeyTarget") or 15, "Auto-Keys") end
	if cfg:GetAttribute("AutoScrolls") then buyMarket("Memory Scroll", cfg:GetAttribute("ScrollTarget") or 999, "Auto-Scrolls") end
end
-- XP zuerst, dann Gold, dann Luck (Gems gehen in dieser Reihenfolge weg)
local function autoBoost()
	for _, kind in ipairs(boostKinds()) do pcall(autoBoostOne, kind) task.wait(0.3) end
end

-- Perks verkaufen (Lobby): unter No Perks zaehlt nur die ANZAHL ausgeruesteter Perks, Qualitaet egal.
-- Verkauf gibt Gems (Values.Perk_Sell_Amount: Common 1, Rare 15, Epic 50) -> Gems fuer XP-Boosts.
-- Behalten: alles Ausgeruestete + die 2 besten je Typ (fuer kuenftige Slots), Epic+ nie.
local SELL_RANK = { Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5, Mythic = 6, Secret = 7 }
-- Perks enhancen (Lobby): statt verkaufen die Futter-Perks (gleiche Auswahl wie beim Verkauf) in die besten Perks stecken.
-- Ziele: erst ausgeruestete, dann nach Raritaet (Mythic > Legendary > Epic), jeweils bis Stufe 10.
-- Spielregeln (Values/Shared.Get_Perk_Total): Futter-XP Common 100 / Rare 250 / Epic 625, Kosten 20 Gold pro XP.
local function enhancePerks()
	task.synchronize()
	local V = M.Values
	if type(V) ~= "table" then local okv, rv = pcall(require, V) V = okv and rv or nil end
	if not V or not V.Perk_XP or not V.Perk_Level_XP then return end
	local P = M.Perks
	if type(P) ~= "table" then local okp, rp = pcall(require, P) P = okp and rp or {} end
	local info = {}
	for rar, lst in pairs(P) do
		if type(lst) == "table" and SELL_RANK[rar] then
			for name, v in pairs(lst) do if type(v) == "table" then info[name] = { r = SELL_RANK[rar], rar = rar, t = v.Type or "?" } end end
		end
	end
	local maxR = SELL_RANK[cfg:GetAttribute("SellPerksUpTo") or "Rare"] or 3
	local done, used = 0, 0
	for _ = 1, 40 do
		local d = H.Cache.Data
		local sl = d and d.Slots and d.Slots[d.Current_Slot]
		if not sl or not sl.Perks or not sl.Perks.Storage then return end
		local eq = {}
		for _, v in pairs(sl.Perks.Equipped or {}) do if v ~= "" then eq[v] = true end end
		-- Futter = Verkaufs-Auswahl (Stufe 0, bis maxR, nicht ausgeruestet, nicht die 2 besten je Typ)
		local byType, keep = {}, {}
		for id in pairs(eq) do keep[id] = true end
		for id, pp in pairs(sl.Perks.Storage) do
			local i = info[pp.Name]
			if i then byType[i.t] = byType[i.t] or {} table.insert(byType[i.t], { id = id, sc = i.r * 1000 + (pp.Level or 0) }) end
		end
		for _, lst in pairs(byType) do
			table.sort(lst, function(a, b) return a.sc > b.sc end)
			for k = 1, math.min(2, #lst) do keep[lst[k].id] = true end
		end
		local fodder = {}
		for id, pp in pairs(sl.Perks.Storage) do
			local i = info[pp.Name]
			if i and i.r <= maxR and not keep[id] and (pp.Level or 0) == 0 then fodder[#fodder + 1] = { id = id, xp = V.Perk_XP[i.rar] or 0 } end
		end
		if #fodder == 0 then break end
		table.sort(fodder, function(a, b) return a.xp < b.xp end) -- kleinstes Futter zuerst (Rest bleibt fuer naechste Ziele)
		-- Ziel: nur Legendaries (User 19.10.: Mythic-XP verteilt er selbst), ausgeruestete zuerst, nicht maximiert
		local target, tsc
		for id, pp in pairs(sl.Perks.Storage) do
			local i = info[pp.Name]
			local lvls = i and V.Perk_Level_XP[i.rar]
			if i and i.rar == "Legendary" and lvls and #lvls > 0 and (pp.Level or 0) < #lvls then
				local sc = (eq[id] and 100 or 0) + i.r * 10 + (pp.Level or 0) / 100
				if not tsc or sc > tsc then target, tsc = id, sc end
			end
		end
		if not target then break end
		local tp = sl.Perks.Storage[target]
		local lvls = V.Perk_Level_XP[info[tp.Name].rar]
		local need = -(tp.XP or 0)
		for lv = (tp.Level or 0) + 1, #lvls do need = need + lvls[lv] end
		local pick, sum = {}, 0
		for _, f in ipairs(fodder) do
			if sum >= need then break end
			if f.id ~= target then
				pick[f.id] = 1
				sum = sum + f.xp
			end
		end
		local gold = sl.Currency and sl.Currency.Gold or 0
		if gold < sum * 20 + (cfg:GetAttribute("GoldReserve") or 0) then farmStatus("Perks enhancen: Gold reicht nicht") break end
		task.synchronize()
		local nd = GET:InvokeServer("S_Equipment", "Enhance", target, pick)
		if type(nd) ~= "table" then farmStatus("Perks enhancen: abgelehnt (" .. tostring(tp.Name) .. ")") break end
		if nd.Slots then H.Cache.Data = nd elseif d and d.Slots then d.Slots[d.Current_Slot] = nd end
		local cnt = 0
		for _ in pairs(pick) do cnt = cnt + 1 end
		used = used + cnt
		done = done + 1
		local d2 = H.Cache.Data
		local s2 = d2 and d2.Slots and d2.Slots[d2.Current_Slot]
		local np = s2 and s2.Perks.Storage[target]
		farmStatus(string.format("Perks enhancen: %s -> Stufe %s (%d Futter)", tostring(tp.Name), tostring(np and np.Level), cnt))
		task.wait(0.4)
	end
	if done > 0 then task.spawn(pcall, M.Topbar.Refresh, H, H.Cache.Data) end
	return done, used
end

local function sellPerks()
	task.synchronize()
	local maxR = SELL_RANK[cfg:GetAttribute("SellPerksUpTo") or "Rare"] or 3
	local d = H.Cache.Data
	local sl = d and d.Slots and d.Slots[d.Current_Slot]
	if not sl or not sl.Perks or not sl.Perks.Storage then return end
	-- erst verkaufen, wenn das Lager voll genug ist (Limit 2000)
	local stored = 0
	for _ in pairs(sl.Perks.Storage) do stored = stored + 1 end
	local minStore = cfg:GetAttribute("SellPerksFrom") or 1500
	if stored < minStore then farmStatus(string.format("Perks: %d/%d im Lager, verkaufe erst ab %d", stored, 2000, minStore)) return end
	local P = M.Perks
	if type(P) ~= "table" then local okp, rp = pcall(require, P) P = okp and rp or {} end
	local info = {}
	for rar, lst in pairs(P) do
		if type(lst) == "table" and SELL_RANK[rar] then
			for name, v in pairs(lst) do if type(v) == "table" then info[name] = { r = SELL_RANK[rar], t = v.Type or "?" } end end
		end
	end
	local keep = {}
	for _, v in pairs(sl.Perks.Equipped or {}) do if v ~= "" then keep[v] = true end end
	local byType = {}
	for id, pp in pairs(sl.Perks.Storage) do
		local i = info[pp.Name]
		if i then
			byType[i.t] = byType[i.t] or {}
			table.insert(byType[i.t], { id = id, sc = i.r * 1000 + (pp.Level or 0) })
		end
	end
	for _, lst in pairs(byType) do
		table.sort(lst, function(a, b) return a.sc > b.sc end)
		for k = 1, math.min(2, #lst) do keep[lst[k].id] = true end
	end
	local sell = {}
	for id, pp in pairs(sl.Perks.Storage) do
		local i = info[pp.Name]
		if i and i.r <= maxR and not keep[id] and (pp.Level or 0) == 0 then sell[#sell + 1] = id end
	end
	if #sell == 0 then return end
	local gems0 = sl.Currency and sl.Currency.Gems or 0
	local done = 0
	for k = 1, #sell, 50 do
		local batch = {}
		for j = k, math.min(k + 49, #sell) do batch[#batch + 1] = sell[j] end
		task.synchronize()
		local nd = GET:InvokeServer("S_Equipment", "Delete", "Perk", batch)
		if type(nd) ~= "table" then break end
		if nd.Slots then H.Cache.Data = nd end
		done = done + #batch
		task.wait(0.3)
	end
	local d2 = H.Cache.Data
	local s2 = d2 and d2.Slots and d2.Slots[d2.Current_Slot]
	farmStatus(string.format("Perks verkauft: %d (+%d Gems)", done, (s2 and s2.Currency and s2.Currency.Gems or gems0) - gems0))
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
-- Boss-Skills + Haltedauer (s) der Server-Hitbox laut Skill-Modul
-- Hand Grinder (3) nur wenn ein Titan dich gepackt hat, Lethal Tempo (35) findet den Boss-Nacken nie (noQuery) -> nicht dabei
-- Haltedauer ab Ausloesen = letzte Hitbox laut Skill-Modul + Puffer (Blade Dance: Schlag erst nach 1,17s, Hitbox 1s)
local BOSS_SKILLS = { ["7"] = 2.4, ["26"] = 2.4, ["23"] = 2.1, ["14"] = 1.4 } -- Blade Dance, Rising Slash, Torrential Steel, Drill Thrust
local HOTBAR_COMBAT = { "7", "26", "97", "95" } -- + Order: Rage, Black Flare (Auto-Cast)
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
	-- Weggabelungen: Path-Knoten mit freigeschaltetem Lock_Skill(_2) = anderer Zweig genommen -> Server "Path is locked!"
	-- (ohne Filter kamen die gesperrten Offense-Skills zuerst, 5 Ablehnungen -> Abbruch, SP blieben liegen)
	local function pathLocked(id, unl)
		local i = Sk[tostring(id)]
		local p = i and i.Path and Sk[tostring(i.Path)]
		if not p then return false end
		return (p.Lock_Skill ~= nil and unl[tostring(p.Lock_Skill)] == true) or (p.Lock_Skill_2 ~= nil and unl[tostring(p.Lock_Skill_2)] == true)
	end
	-- 1) Skills freischalten
	xpcall(function()
		local unl = {}
		for _, v in ipairs(sl.Skills.Unlocked or {}) do unl[tostring(v)] = true end
		local cands = {}
		for id, i in pairs(Sk) do
			local n = tonumber(id)
			if n and n < 99 and type(i) == "table" and i.Skill_Cost and not unl[id] and not pathLocked(id, unl) then cands[#cands + 1] = id end
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
					if not unl[cur] then
						if pathLocked(cur, unl) then return {}, 0 end
						list[#list + 1] = cur cost = cost + (Sk[cur].Skill_Cost or 0)
					end
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
					if not unl[cur] then
						if pathLocked(cur, unl) then list = {} break end
						list[#list + 1] = cur cost = cost + (Sk[cur].Skill_Cost or 0)
					end
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
		-- Boss-Skills: Slot 1 (Titan-Shift 999) bleibt, Slots 2-5 mit den Combat-Skills belegen (ersetzt Nicht-Combat-Skills)
		-- Hotbar waehlt der User selbst -> nur noch auf Wunsch (ForceHotbar) umbelegen
		if cfg:GetAttribute("BossSkills") and cfg:GetAttribute("ForceHotbar") then
			local want, keep = {}, {}
			for _, id in ipairs(HOTBAR_COMBAT) do keep[id] = true if unl[id] and not onBar[id] then want[#want + 1] = id end end
			for slot = 2, 5 do
				local cur = tostring(hb[slot] or "")
				if #want > 0 and cur ~= "999" and not keep[cur] then
					local id = table.remove(want, 1)
					task.synchronize()
					local nd = GET:InvokeServer("S_Equipment", "Skill_State", slot, id)
					buildStatus("Hotbar " .. slot .. ": " .. skillTag(id) .. (type(nd) == "table" and "" or " (abgelehnt)"))
					if type(nd) == "table" then H.Cache.Data = nd got.hb = got.hb + 1 onBar[id] = true end
					task.wait(0.2)
					sl = slotData()
					hb = sl.Skills.Hotbar
				end
			end
		end
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
local lastSell = cfg:GetAttribute("SellReq")
task.spawn(function()
	while A.on do
		task.wait(0.4)
		task.synchronize()
		local q = cfg:GetAttribute("SellReq")
		if q ~= lastSell and not workspace:FindFirstChild("Titans") then lastSell = q pcall(sellPerks) end
	end
end)

-- Eigene Loadouts (User 19.10.: Server-Loadouts unbrauchbar): Waffe, Perks je Slot (per ID = genau diese Kopie),
-- Artefakte je Slot, Skill-Hotbar 1-5. Datei je Loadout in aot_loadouts/. Laden nur in der Lobby
local LO_HS = game:GetService("HttpService")
local function loStatus(t) task.synchronize() cfg:SetAttribute("LoadoutStatus", t) end
local function loSlot() local d = H.Cache.Data return d and d.Slots and d.Slots[d.Current_Slot] end
local function loHb(sl, i) local hb = sl.Skills and sl.Skills.Hotbar or {} local v = hb[i] if v == nil then v = hb[tostring(i)] end return v end
local function loSave(name)
	task.synchronize()
	local sl = loSlot()
	if not sl then loStatus("Keine Daten (nur in der Lobby)") return end
	local t = { Weapon = sl.Weapon, Perks = {}, Artifacts = {}, Vanity = {}, Hotbar = {}, Names = {} }
	for slot, id in pairs(sl.Perks and sl.Perks.Equipped or {}) do
		t.Perks[slot] = id
		local pp = id ~= "" and sl.Perks.Storage[id]
		t.Names["P_" .. slot] = pp and (tostring(pp.Name) .. " +" .. tostring(pp.Level or 0)) or ""
	end
	for slot, v in pairs(sl.Artifacts and sl.Artifacts.Equipped or {}) do
		local id = type(v) == "table" and v.ID or v
		t.Artifacts[slot] = id or ""
		t.Vanity[slot] = type(v) == "table" and v.Vanity == true or false
		local a = id and sl.Artifacts.Storage[id]
		t.Names["A_" .. slot] = a and tostring(a.Name) or ""
	end
	for i = 1, 5 do t.Hotbar[tostring(i)] = loHb(sl, i) or "" end
	if not isfolder("aot_loadouts") then makefolder("aot_loadouts") end
	writefile("aot_loadouts/" .. name .. ".json", LO_HS:JSONEncode(t))
	loStatus("Gespeichert: " .. name)
end
local function loLoad(name)
	task.synchronize()
	if workspace:FindFirstChild("Titans") then loStatus("Laden nur in der Lobby") return end
	local t = LO_HS:JSONDecode(readfile("aot_loadouts/" .. name .. ".json"))
	local n, errs = 0, {}
	local function call(...)
		task.synchronize()
		local r = H:Invoke(...)
		if type(r) == "table" and r.Slots then H.Cache.Data = r end
		task.wait(0.25)
		return r ~= nil
	end
	local sl = loSlot()
	if not sl then loStatus("Keine Daten") return end
	if t.Weapon and sl.Weapon ~= t.Weapon then
		if call("S_Equipment", "Weapon", t.Weapon) then n = n + 1 else errs[#errs + 1] = "Waffe" end
	end
	-- Perks: erst abweichende ablegen (sonst steckt eine gewuenschte Kopie noch im falschen Slot), dann ausruesten
	sl = loSlot()
	for slot, id in pairs(t.Perks or {}) do
		local cur = sl.Perks.Equipped[slot] or ""
		if cur ~= "" and cur ~= id then call("S_Equipment", "Perk_State", cur, "Unequip", slot) sl = loSlot() end
	end
	for slot, id in pairs(t.Perks or {}) do
		if id ~= "" and (sl.Perks.Equipped[slot] or "") ~= id then
			if not sl.Perks.Storage[id] then errs[#errs + 1] = "Perk fehlt: " .. tostring(t.Names["P_" .. slot])
			elseif call("S_Equipment", "Perk_State", id, "Equip", slot) then n = n + 1
			else errs[#errs + 1] = "Perk " .. slot .. " abgelehnt" end
			sl = loSlot()
		end
	end
	-- Artefakte genauso
	local function artCur(slot) local v = sl.Artifacts.Equipped and sl.Artifacts.Equipped[slot] return type(v) == "table" and v.ID or v or "" end
	for slot, id in pairs(t.Artifacts or {}) do
		local cur = artCur(slot)
		if cur ~= "" and cur ~= id then call("S_Equipment", "Artifact_State", cur, "Unequip", slot) sl = loSlot() end
	end
	for slot, id in pairs(t.Artifacts or {}) do
		if id ~= "" and artCur(slot) ~= id then
			if not sl.Artifacts.Storage[id] then errs[#errs + 1] = "Artefakt fehlt: " .. tostring(t.Names["A_" .. slot])
			elseif call("S_Equipment", "Artifact_State", id, "Equip", slot) then n = n + 1
			else errs[#errs + 1] = "Artefakt " .. slot .. " abgelehnt" end
			sl = loSlot()
		end
	end
	-- Hotbar 1-5
	for i = 1, 5 do
		local want = t.Hotbar and t.Hotbar[tostring(i)]
		if want ~= nil and tostring(want) ~= "" and tostring(loHb(sl, i) or "") ~= tostring(want) then
			if call("S_Equipment", "Skill_State", i, want) then n = n + 1 else errs[#errs + 1] = "Skill " .. i .. " abgelehnt" end
			sl = loSlot()
		end
	end
	task.spawn(pcall, M.Topbar.Refresh, H, H.Cache.Data)
	pcall(function() M.Char.Gear(H, M.Lobby.Character, loSlot(), nil, true, true) end)
	loStatus("Geladen: " .. name .. " (" .. n .. " Aenderungen)" .. (#errs > 0 and (" | " .. table.concat(errs, ", ")) or ""))
end
local lastLo = cfg:GetAttribute("LoadoutReq")
task.spawn(function()
	while A.on do
		task.wait(0.3)
		task.synchronize()
		local q = cfg:GetAttribute("LoadoutReq")
		if q ~= lastLo and type(q) == "string" then
			lastLo = q
			local op, name = q:match("^(%a+)|(.-)|")
			local ok, e = pcall(op == "save" and loSave or loLoad, name)
			if not ok then loStatus("Fehler: " .. tostring(e)) end
		end
	end
end)
-- Kisten oeffnen: S_Inventory("Crate", name) -> (SlotDaten, Item, Raritaet, Pity). Kein Cooldown,
-- aber Opens fuer nicht vorhandene Kisten loesen eine kurze Server-Sperre aus -> nur besessene + Retry.
local function crateStatus(t) task.synchronize() cfg:SetAttribute("CrateStatus", t) end
local function refreshInventory()
	task.synchronize()
	local Inv = M.Inventory
	local ui = H.Cache.Interface and H.Cache.Interface.Inventory
	if type(Inv) == "table" and ui and Inv.Opening ~= true then pcall(Inv.Update, H, ui) end
	task.spawn(pcall, M.Topbar.Refresh, H, H.Cache.Data)
end
local function openCrates()
	task.synchronize()
	local d, sl = M.Update.Get_Data(H, true)
	if not sl then crateStatus("Keine Daten") return end
	local Cr = M.Crates
	if type(Cr) ~= "table" then Cr = require(Cr) end
	local sel = cfg:GetAttribute("CrateSel") or "Alle"
	local list = {}
	for name in pairs(Cr) do
		if (tonumber(sl.Inventory.Items[name]) or 0) > 0 and (sel == "Alle" or sel == name) then list[#list + 1] = name end
	end
	table.sort(list)
	local ORDER = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret" }
	local RK = {} for i, r in ipairs(ORDER) do RK[r] = i end
	local n, cnt, best, log, line = 0, {}, {}, {}, ""
	local function summary()
		local parts = {}
		for _, r in ipairs(ORDER) do if cnt[r] then parts[#parts + 1] = r .. " " .. cnt[r] end end
		return table.concat(parts, " · ") .. (#best > 0 and ("\nEpic+: " .. table.concat(best, ", ")) or "")
	end
	for _, name in ipairs(list) do
		while A.on and not cfg:GetAttribute("CrateStop") do
			local ok, sd, item, rar, pity
			for try = 1, 4 do
				ok, sd, item, rar, pity = pcall(function() return GET:InvokeServer("S_Inventory", "Crate", name) end)
				if ok and type(sd) == "table" and item ~= nil then break end
				task.wait(0.5 * try)
			end
			if not ok or type(sd) ~= "table" or item == nil then break end
			task.synchronize()
			local dd = H.Cache.Data
			if dd and dd.Slots then dd.Slots[dd.Current_Slot] = sd end
			n = n + 1
			rar = tostring(rar or "?")
			cnt[rar] = (cnt[rar] or 0) + 1
			if (RK[rar] or 0) >= 4 then best[#best + 1] = tostring(item) .. " (" .. rar .. ")" end
			log[#log + 1] = os.date("%H:%M:%S") .. " " .. name .. " -> " .. tostring(item) .. " (" .. rar .. ") pity=" .. tostring(pity)
			local left = sd.Inventory and sd.Inventory.Items and sd.Inventory.Items[name] or 0
			line = string.format("#%d %s: %s (%s) · noch %d", n, name, tostring(item), rar, left)
			crateStatus(line .. "\n" .. summary())
			if left <= 0 then break end
			task.wait(0.15)
		end
		if cfg:GetAttribute("CrateStop") or not A.on then break end
	end
	if #log > 0 then pcall(function() writefile("aot_crates_log.txt", (isfile("aot_crates_log.txt") and readfile("aot_crates_log.txt") or "") .. table.concat(log, string.char(10)) .. string.char(10)) end) end
	-- Redraw im Hintergrund: Inventory.Update kann bei offenem Inventar auf UI-Tweens haengen und hielt sonst "Crating" fest
	if n > 0 then task.spawn(pcall, refreshInventory) end
	crateStatus((#list == 0 and "Keine Kisten im Inventar" or n == 0 and "Server lehnt ab (Kisten schon geoeffnet? Anzeige veraltet bis Lobby-Neuladen)" or ("Fertig: " .. n .. " geoeffnet · " .. summary())) .. (cfg:GetAttribute("CrateStop") and " · gestoppt" or ""))
end
-- Flags eines alten/abgebrochenen Laufs zuruecksetzen (Cfg ueberlebt Hub-Reloads)
cfg:SetAttribute("Crating", false)
cfg:SetAttribute("CrateStop", false)
local lastCrate = cfg:GetAttribute("CrateReq")
task.spawn(function()
	while A.on do
		task.wait(0.3)
		task.synchronize()
		local q = cfg:GetAttribute("CrateReq")
		if q ~= lastCrate then
			lastCrate = q
			cfg:SetAttribute("CrateStop", false)
			cfg:SetAttribute("Crating", true)
			local ok, e = pcall(openCrates)
			task.synchronize()
			cfg:SetAttribute("CrateStop", false)
			if not ok then cfg:SetAttribute("CrateStatus", "Fehler: " .. tostring(e)) end
			cfg:SetAttribute("Crating", false)
		end
	end
end)
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
			-- Colossal-Phasenwechsel (gemessen 18.10.): griff der Skip nach 0,3s, spawnte der Colossal nach ~2s mit 100% statt
			-- nach ~16s mit 50% -> doppelte Phase 2. Test (User): dort erst spaeter skippen (1,5s reichte nicht -> 2,5s). Erkennung: keine Kanonen, Raid laeuft
			local col = workspace:GetAttribute("Objective") == "Colossal Titan"
			-- Erkennung ueber den Boss-Balken (1-55%): beim Wechsel sind die Kanonen noch getaggt, Balken 0% = Raid-Ende
			local pct
			if col then
				for _, g in ipairs(game.Players.LocalPlayer.PlayerGui:GetDescendants()) do
					if g:IsA("TextLabel") and g.Name == "Percentage" and g.Visible then pct = tonumber((g.Text:gsub("%%", ""))) break end
				end
			end
			local trans = col and pct ~= nil and pct > 1 and pct <= 55 and not workspace:FindFirstChild("Chest_End")
				and workspace:GetAttribute("Force_End") ~= true
			-- Auswertung 25 Raids (18.10.): kurze Pause nach Skip (1-4s) -> 6 von 10 mal Phase 2 mit 100%; ohne Skip (7-18s) 15/15
			-- mit 49%. 2,5s Verzoegerung half nicht (2/2 mit 100%) -> Phasenwechsel nicht skippen (kostet ~10s, Bug ~60s+)
			if trans and cfg:GetAttribute("ColSkipTrans") ~= true then PH("SKIP", "Colossal-Phasenwechsel Balken " .. tostring(pct) .. " -> nicht skippen") return end
			local delay = 0.3
			PH("SKIP", tostring(workspace:GetAttribute("Objective")) .. (trans and " Phasenwechsel" or "") .. " Balken " .. tostring(pct) .. " in " .. delay .. "s")
			task.delay(delay, function()
				if RD.Can_Skip.Value ~= true then return end
				task.synchronize()
				pcall(RD.Skip, H)
			end)
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

-- Auto-Kanone: Kanone besetzen, feuern; Einschlag (client-gemeldet) direkt auf den Colossal legen
pcall(function()
	local Sk = M.Skills
	if not Sk or not Sk.Impact or Sk.__aotImpact then return end
	local POSTr = game:GetService("ReplicatedStorage").Assets.Remotes.POST
	local function colossalTarget()
		local tf = workspace:FindFirstChild("Titans")
		if not tf then return end
		local best
		for _, t in ipairs(tf:GetChildren()) do if not t:IsA("Model") then continue end
			local ty = tostring(t:GetAttribute("Type") or "")
			if t.Name:find("Colossal") or ty:find("Colossal") then best = t break end
			if t:GetAttribute("Shifter") then best = best or t end
		end
		if not best then return end
		local hit = best:FindFirstChild("Hitboxes") and best.Hitboxes:FindFirstChild("Hit")
		local part = (hit and (hit:FindFirstChild("Nape") or hit:GetChildren()[1])) or best:FindFirstChild("HumanoidRootPart") or best.PrimaryPart
		return part and part.Position, best
	end
	local orig = Sk.Impact
	Sk.__aotImpact = orig
	Sk.Impact = function(h, ball, part, t, flag, ...)
		if cfg:GetAttribute("AutoCannon") and typeof(ball) == "Instance" and (ball.Name == "Cannon" or ball:GetAttribute("Skill") == "Cannon") then
			do return end
			local pos = colossalTarget()
			if pos then
				task.spawn(function()
					task.wait(0.05)
					task.synchronize()
					POSTr:FireServer("S_Skills", "Impact", ball, pos)
					cfg:SetAttribute("CannonHits", (cfg:GetAttribute("CannonHits") or 0) + 1)
				end)
				return
			end
		end
		return orig(h, ball, part, t, flag, ...)
	end
	-- Besetzen + Feuern
	task.spawn(function()
		local CS = game:GetService("CollectionService")
		local seated, angles
		while A.on do
			task.wait(0.25)
			if cfg:GetAttribute("AutoCannonActor") and workspace:GetAttribute("Type") == "Raids" and colossalTarget() then
				task.synchronize()
				local lp = game.Players.LocalPlayer
				if not (seated and seated.Parent and seated:GetAttribute("Player") == lp.Name) then
					seated = nil
					for _, c in ipairs(CS:GetTagged("Cannon")) do
						if c:GetAttribute("Player") == nil or c:GetAttribute("Player") == lp.Name then
							local ok, a = pcall(function() return GET:InvokeServer("Cannon", "State", c, true, nil) end)
							if ok and type(a) == "table" then
								seated, angles = c, a
								M.Cannon.Info = M.Cannon.Info or nil
								break
							end
						end
					end
				end
				-- Server sperrt nur ~1.4s (Shots); das Cooldown-Attribut prueft nur der Client -> ignorieren
				if seated then
					local ok, r2 = pcall(function() return GET:InvokeServer("Cannon", "Shoot", angles or { Base = 0, BarrelWood = 0 }) end)
					if ok and r2 == true then cfg:SetAttribute("CannonShots", (cfg:GetAttribute("CannonShots") or 0) + 1) end
				end
			end
		end
	end)
end)

-- Perk "Heavenly Restriction" deaktiviert ALLE Skills (Skills.Use bricht ab) -> Skill-Automatik pausieren
function skillsBlocked()
	local ok, n = pcall(function() return M.Shared.Item_Quantity(H, H.Loadout, "Perks", "Heavenly Restriction") end)
	return ok and (tonumber(n) or 0) > 0
end
-- Skill-Module vorladen: Skills.Use macht require(Modules[id]) - aus dem Hub-Thread scheitert das
-- ("Cannot require a non-RobloxScript module from a RobloxScript") -> Cooldown weg, Client-Teil (z.B. Blade-Dance-Schlaege) laeuft nie
local function preloadSkill(id)
	if type(M[id]) == "table" then return true end
	local inst = typeof(M[id]) == "Instance" and M[id] or nil
	if not inst then
		local f = game:GetService("ReplicatedStorage"):FindFirstChild("Modules")
		f = f and f:FindFirstChild("Skills")
		inst = f and f:FindFirstChild(id, true)
	end
	if not (inst and inst:IsA("ModuleScript")) then return false end
	local ok, r = pcall(require, inst)
	if ok and type(r) == "table" then M[id] = r return true end
	return false
end
-- Boss-Skills (Phase 2 / Shifter-Boss): Skill-Hitboxen entstehen serverseitig um den Charakter (S_Skills.Hitbox)
-- -> kurz an den Boss-Nacken setzen, ausloesen, so lange halten wie die Hitbox steht (aus den Skill-Modulen), zurueck
task.spawn(function()
	local CS = game:GetService("CollectionService")
	local RunS = game:GetService("RunService")
	while A.on do
		task.wait(0.1) -- Blade Dance soll sofort off Cooldown feuern
		local me = game.Players.LocalPlayer
		local shifted = (me.Character and me.Character:GetAttribute("Shifter") ~= nil) or H.Shifting ~= nil
			or skillsBlocked() -- Heavenly Restriction: alle Skills aus -> nicht sinnlos an den Boss porten
		-- Raids + Waves (Waves: nur Blade Dance fern, ohne Teleport), nie im Titan-Modus (sonst galt der eigene Titan als "Boss")
		if (cfg:GetAttribute("BossSkills") or cfg:GetAttribute("BossSkillFar")) and not shifted and (workspace:GetAttribute("Type") == "Raids" or workspace:GetAttribute("Type") == "Waves")
			and workspace:FindFirstChild("Titans") and #CS:GetTagged("Cannon") == 0 then
			pcall(function()
				task.synchronize()
				local lp = game.Players.LocalPlayer
				local hb = H.Loadout and H.Loadout.Skills and H.Loadout.Skills.Hotbar
				local hrp = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
				if not hb or not hrp or H.Skill ~= nil then return end
				local boss
				for _, t in ipairs(workspace.Titans:GetChildren()) do if not t:IsA("Model") then continue end
					if t:GetAttribute("Shifter") and t:GetAttribute("Player") ~= lp.Name and t.Name ~= lp.Name then boss = t break end
				end
				local nape = boss and boss:FindFirstChild("Hitboxes") and boss.Hitboxes:FindFirstChild("Hit") and boss.Hitboxes.Hit:FindFirstChild("Nape")
				if not nape then return end
				-- Blade Dance (Fern-Schlag) zuerst pruefen; Teleport-Skills nicht starten, wenn er in <2,5s wieder bereit ist
				local order, bdSlot = {}, nil
				for sl = 1, 5 do if tostring(hb[sl] or "") == "7" then bdSlot = sl end end
				if bdSlot then order[1] = bdSlot end
				for sl = 1, 5 do if sl ~= bdSlot then order[#order + 1] = sl end end
				local bdLeft = bdSlot and tonumber(lp:GetAttribute("Skill_" .. bdSlot)) or nil
				local bdSoon = bdSlot and cfg:GetAttribute("BossSkillFar") and (bdLeft == nil or bdLeft <= 2.5)
				for _, slot in ipairs(order) do
					local id = tostring(hb[slot] or "")
					local hold = BOSS_SKILLS[id]
					if id ~= "7" and bdSoon then hold = nil end
					A.skillBlock = A.skillBlock or {}
					A.skillFree = A.skillFree or {}
					A.skillFails = A.skillFails or {}
					-- Client-Cooldown laeuft ~0,5s vor dem Server ab -> erst 0,4s nach "frei" ansetzen (sonst jeder 3. Versuch abgelehnt)
					local free = lp:GetAttribute("Skill_" .. slot) == nil
					if free and not A.skillFree[id] then A.skillFree[id] = os.clock() end
					if not free then A.skillFree[id] = nil end
					-- laeuft noch ein anderer Skill (Attribut "Skill"), warten statt Fehlversuch
					if id == "7" and cfg:GetAttribute("BossSkillFar") and free and H.Skill == nil and lp:GetAttribute("Skill") == nil and os.clock() >= (A.skillBlock[id] or 0) then
						-- Blade Dance ohne Teleport: Server baut die Schlag-Hitbox an der vom Client geschickten CFrame und prueft
						-- nur Skill=="7" -> waehrend der Skill laeuft alle 0,25s einen Schlag direkt auf den Boss-Nacken
						-- (gemessen 17.10.: 4 statt 1 Treffer, ~340k statt ~85k pro Einsatz)
						preloadSkill(id)
						M.Skills.Use(H, lp, false, slot)
						local tu = os.clock()
						while lp:GetAttribute("Skill") ~= "7" and os.clock() - tu < 0.8 do RunS.Heartbeat:Wait() end
						local n = 0
						local ts = os.clock()
						while lp:GetAttribute("Skill") == "7" and os.clock() - ts < 2 and nape.Parent do
							H:Send("7", "Slash", nape.CFrame * CFrame.new(0, 0, 6.5))
							n = n + 1
							task.wait(0.25)
						end
						local cast = n > 0
						if cast then A.skillFails[id] = 0 else
							A.skillFails[id] = (A.skillFails[id] or 0) + 1
							-- NICHT spammen: schnelle Wiederholungen verlaengern die Server-Sperre (gemessen 18.10.: 0,2s -> lange
							-- Ablehnungsserien; 1x/s -> sofort angenommen, sobald der Client-Cooldown abgelaufen ist)
							A.skillBlock[id] = os.clock() + 1
						end
						local why = ""
						if not cast then
							local V = H.Cache.Variables
							local ch = lp.Character
							why = string.format(" | cd=%s skill=%s ragdoll=%s reload=%s full=%s slashing=%s trans=%s block=%s invoked=%s cannon=%s",
								tostring(lp:GetAttribute("Skill_" .. slot)), tostring(lp:GetAttribute("Skill")), tostring(ch and ch:GetAttribute("Ragdoll")),
								tostring(V.Reload), tostring(V.Full_Reload), tostring(V.Slash and V.Slash.Slashing), tostring(V.Slash and V.Slash.Transition),
								tostring(V.Block), tostring(H.Invoked), tostring(M.Cannon and M.Cannon.Info ~= nil))
						end
						PH("BOSS_SKILL", "7 slot " .. slot .. (cast and (" Fern-Schlaege " .. n) or (" nicht angenommen" .. why)))
						task.wait(0.4)
					elseif hold and id ~= "7" and cfg:GetAttribute("BossSkills") and workspace:GetAttribute("Type") == "Raids" and free and os.clock() - (A.skillFree[id] or os.clock()) >= 0.4 and H.Skill == nil and os.clock() >= (A.skillBlock[id] or 0) then
						local back = hrp.CFrame
						cfg:SetAttribute("SkillTP", true)
						local function put()
							hrp.CFrame = nape.CFrame * CFrame.new(0, 0, 4)
							hrp.AssemblyLinearVelocity = Vector3.zero
						end
						preloadSkill(id)
						put()
						RunS.Heartbeat:Wait()
						put()
						local tUse = os.clock()
						M.Skills.Use(H, lp, false, slot)
						-- Cooldown setzt der Server -> kommt ein paar Frames spaeter an; bis dahin am Nacken bleiben
						local tc = os.clock()
						while lp:GetAttribute("Skill_" .. slot) == nil and os.clock() - tc < 0.6 do put() RunS.Heartbeat:Wait() end
						local cast = lp:GetAttribute("Skill_" .. slot) ~= nil
						while cast and os.clock() - tUse < hold and nape.Parent do put() RunS.Heartbeat:Wait() end
						hrp.CFrame = back
						hrp.AssemblyLinearVelocity = Vector3.zero
						cfg:SetAttribute("SkillTP", false)
						-- abgelehnt: nach 1s nochmal, erst nach 3 Fehlversuchen in Folge 20s Pause (nicht dauernd hin- und herporten)
						if cast then A.skillFails[id] = 0 else
							A.skillFails[id] = (A.skillFails[id] or 0) + 1
							A.skillBlock[id] = os.clock() + (A.skillFails[id] >= 3 and 20 or 1)
						end
						PH("BOSS_SKILL", id .. " slot " .. slot .. (cast and " gezuendet" or " nicht angenommen"))
						task.wait(0.4)
					end
				end
			end)
			cfg:SetAttribute("SkillTP", false)
		end
	end
end)

-- Knopf "Jetzt kaufen" (Auto-Keys)
cfg:GetAttributeChangedSignal("KeyReq"):Connect(function()
	if game.PlaceId == 14916516914 then task.spawn(function() pcall(autoKeys) end) end
end)

-- Waves-Modus: Vote-Fenster (Raids.Objectives.Waves, Attribut Show) -> Phase "Ready" oder "Skip";
-- abstimmen = Send("Waves","Update") (wie der Vote-Knopf des Spiels), einmal pro Fenster
task.spawn(function()
	local voted
	while A.on do
		task.wait(0.3)
		if workspace:GetAttribute("Type") == "Waves" then
			pcall(function()
				local W = M.Raids and M.Raids.Objectives and M.Raids.Objectives.Waves
				if not W then return end
				local show = W:GetAttribute("Show") == true and game.Players.LocalPlayer:GetAttribute("Dead") == nil
				if not show then voted = nil return end
				local phase = W:GetAttribute("Phase")
				local want = ((phase == "Ready" or phase == "Start") and cfg:GetAttribute("WaveReady")) or (phase == "Skip" and cfg:GetAttribute("WaveSkip"))
				if want and voted ~= phase then
					voted = phase
					task.synchronize()
					H:Send("Waves", "Update")
					PH("WAVE_VOTE", tostring(phase) .. " " .. tostring(W:GetAttribute("Ready")) .. "/" .. tostring(W:GetAttribute("Total")))
				end
			end)
		end
	end
end)

-- Waves-Modus: alle Kaeufe mit Wave-Gold (Loadout.Gold). Jeder Kauf geht nur beim passenden NPC (Workspace.Waves.NPCs):
-- Lulu = Schwerter Invoke("Equipment","Upgrade",{Stats}), Cole = HQ Invoke("Waves","Upgrade",{Name}). Kurz hin, kaufen, zurueck.
-- Prioritaet: HQ < 60% -> Replenish; Refill-Pool < 10 -> Refills; ab 1500 Gold Schwerter; Schwerter fertig -> Max/Regen
local WAVE_STATS = { "ODM_Damage", "Crit_Damage", "Crit_Chance", "Blade_Durability", "ODM_Speed", "ODM_Gas", "ODM_Range", "ODM_Control" }
task.spawn(function()
	local nextTry, nextSword = 0, 0
	local function visit(npcName, fn)
		local lp = game.Players.LocalPlayer
		local hrp = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
		local npc = workspace.Waves.NPCs:FindFirstChild(npcName)
		if not (hrp and npc) then return end
		local back = hrp.CFrame
		cfg:SetAttribute("SkillTP", true) -- Ausweichen pausieren
		hrp.CFrame = npc:GetPivot() * CFrame.new(0, 0, -6)
		hrp.AssemblyLinearVelocity = Vector3.zero
		task.wait(0.3)
		pcall(fn)
		task.wait(0.6) -- Server bucht verzoegert ab
		-- nicht zurueck an die alte Stelle: das Spiel setzt einen zum Wellenstart ans HQ, die alte Stelle lag oft weit
		-- draussen -> man wurde staendig vom HQ weggezogen. Haendler stehen am HQ, Aura braucht keine Naehe -> dort bleiben
		hrp.AssemblyLinearVelocity = Vector3.zero
		cfg:SetAttribute("SkillTP", false)
	end
	while A.on do
		task.wait(0.5)
		if workspace:GetAttribute("Type") == "Waves" and os.clock() >= nextTry and workspace:FindFirstChild("Waves") then
			pcall(function()
				task.synchronize()
				local lp = game.Players.LocalPlayer
				local ch = lp.Character
				if not ch or ch:GetAttribute("Shifter") ~= nil or H.Skill ~= nil or lp:GetAttribute("Dead") ~= nil then return end
				local U = workspace.Waves:FindFirstChild("Upgrades")
				local gold = H.Loadout and tonumber(H.Loadout.Gold) or 0
				local function cost(n) local u = U and U:FindFirstChild(n) return u and tonumber(u:GetAttribute("Cost")) or math.huge end
				local Wv = M.Raids and M.Raids.Objectives and M.Raids.Objectives.Waves
				local hp = Wv and Wv:FindFirstChild("Health")
				local hpPct = (hp and hp:GetAttribute("Max_Health") and hp:GetAttribute("Max_Health") > 0) and hp.Value / hp:GetAttribute("Max_Health") * 100 or 100
				local pool = U and U:FindFirstChild("Refills") and U.Refills.Value or 15
				-- Gekaufte Perks/Artefakte ausruesten: das Slot-Limit (Perks 2, Artefakte 1) prueft nur der Client -
				-- gemessen 18.10.: Server nahm 6 Perks + 5 Artefakte gleichzeitig an. Geht ohne NPC-Besuch
				if cfg:GetAttribute("WaveEquip") ~= false and os.clock() >= (A.nextEquip or 0) and H.Loadout then
					A.nextEquip = os.clock() + 10
					for _, cat in ipairs({ "Perks", "Artifacts" }) do
						local inv = H.Loadout[cat]
						local ids = {}
						-- ausgeruestete bleiben in Storage stehen -> eigene Liste (UUIDs, je Runde neu), jede ID nur 1x versuchen
						A.equipTried = A.equipTried or {}
						for id in pairs(inv and inv.Storage or {}) do if not A.equipTried[id] then ids[#ids + 1] = id end end
						for _, id in ipairs(ids) do
							A.equipTried[id] = true
							local r = H:Invoke("Equipment", "State", cat, "Equip", id, nil, nil)
							if type(r) == "table" then H.Loadout[cat] = r PH("WAVE_EQUIP", cat .. " " .. tostring(id):sub(1, 8)) end
						end
					end
				end
				-- Market (Orange): seltenstes bezahlbares Item mit Vorrat (ab Rare); 50k Reserve fuer Schwerter
				local marketBest
				if cfg:GetAttribute("WaveMarket") and os.clock() >= (A.nextMarket or 0) then
					local RANK = { Rare = 3, Epic = 4, Legendary = 5, Mythic = 6, Secret = 7 }
					-- nur was wirkt: Perks + Artefakte lassen sich ausruesten (WaveEquip); Memories gehen per "State" nicht (abgelehnt),
					-- Shifting-Shards landen nicht im Lager (436k fuer Colossal Shard ohne sichtbaren Effekt) -> vorerst nicht kaufen
					local CAT = { Perks = 2, Artifacts = 1 }
					local bs
					local items = workspace.Waves:FindFirstChild("Items")
					for _, cat in ipairs(items and items:GetChildren() or {}) do
						for _, it in ipairs(cat:GetChildren()) do
							local r = RANK[it:GetAttribute("Rarity") or ""]
							local price = tonumber(it:GetAttribute("Price")) or math.huge
							if r and CAT[cat.Name] and (it:GetAttribute("Stock") or 0) > 0 and gold - price >= 50000 then
								local sc = r * 10 + CAT[cat.Name]
								if not bs or sc > bs then marketBest, bs = { cat.Name, it:GetAttribute("ID"), it.Value, it:GetAttribute("Rarity"), price }, sc end
							end
						end
					end
					A.nextMarket = os.clock() + 4
				end
				-- Boss am HQ (Haendler stehen dort): keine Besuche. Gemessen 18.10.: Runde nach ~25 min gescheitert bei HQ 100%,
				-- Boss 266 Studs vom HQ - jeder Besuch portete einen neben den Boss und pausierte das Ausweichen
				local cole = workspace.Waves:FindFirstChild("NPCs") and workspace.Waves.NPCs:FindFirstChild("Cole")
				local tf = workspace:FindFirstChild("Titans")
				if cole and tf then
					local hq = cole:GetPivot().Position
					for _, t in ipairs(tf:GetChildren()) do
						local r = t:IsA("Model") and t:GetAttribute("Shifter") and (t:FindFirstChild("HumanoidRootPart") or t.PrimaryPart)
						if r and (r.Position - hq).Magnitude < (tonumber(cfg:GetAttribute("BossEvadeRange")) or 900) + 400 then
							if os.clock() >= (A.bossNote or 0) then A.bossNote = os.clock() + 10 PH("WAVE_HOLD", "Boss " .. math.floor((r.Position - hq).Magnitude) .. " st vom HQ -> keine Haendler") end
							return
						end
					end
				end
				local action
				if cfg:GetAttribute("WaveUpgrades") and hpPct < 60 and gold >= cost("Replenish") and os.clock() >= (A.noReplenish or 0) then action = { "Cole", "Replenish" }
				elseif cfg:GetAttribute("WaveUpgrades") and pool < 5 and gold >= cost("Refills") and os.clock() >= (A.nextRefillBuy or 0) then
					action = { "Cole", "Refills" } A.nextRefillBuy = os.clock() + 10
				elseif cfg:GetAttribute("WaveSwords") and os.clock() >= nextSword and gold >= (cfg:GetAttribute("WaveSwordGold") or 1500) then
					action = { "Lulu" } nextSword = os.clock() + 8
				elseif marketBest then action = { "Orange", marketBest }
				elseif cfg:GetAttribute("WaveBless") and gold >= math.ceil(2000 * 1.43 ^ ((H.Loadout.Blessings and H.Loadout.Blessings.Rolled) or 0)) + 3000
					and (tonumber(H.Loadout.Capacity) or 0) < 1000 then
					-- Blessing-Glücksrad (NPC Roll): 2000 * 1.43^Spins, Rest bleibt fuer Schwerter; Rad dreht ~5s -> danach 6s Pause
					if os.clock() >= (A.nextSpin or 0) then action = { "Roll" } A.nextSpin = os.clock() + 6 end
				elseif cfg:GetAttribute("WaveUpgrades") and gold >= 20000 + math.min(os.clock() < ((A.hqCap or {}).Max or 0) and math.huge or cost("Max"), os.clock() < ((A.hqCap or {}).Regen or 0) and math.huge or cost("Regen")) then
					-- Ueberschuss ueber 20k Reserve (Schwerter) ins HQ: mehrere Kaeufe pro Besuch (gemessen 18.10.: 5x Max am Stueck
					-- gehen alle durch). Max = +5 HQ-Leben je Stufe und billig (x1.077) -> bester HQ-Schutz pro Gold
					action = { "Cole", "Bulk" }
				end
				if not action then return end
				nextTry = os.clock() + 3
				local g0 = gold
				if action[1] == "Orange" then
					local b = action[2]
					visit("Orange", function() H:Invoke("Waves", "Item", "Buy", b[1], b[2], 1) end)
					action[2] = string.format("%s %s (%s, %d)", b[1], tostring(b[3]), tostring(b[4]), b[5])
				elseif action[1] == "Lulu" then
					visit("Lulu", function() H:Invoke("Equipment", "Upgrade", WAVE_STATS) end)
				elseif action[1] == "Roll" then
					visit("Roll", function()
						-- Segen sperren: jede Kategorie zeigt 3 Angebote (Selection[Kat][2..4]), die jede Welle wechseln;
						-- Sperre (20% des Drehpreises) haelt sie 5 Wellen. Kategorien mit Angebot ab Epic sperren, Offense zuerst
						local RK = { Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5, Mythic = 6 }
						local Bl, Sel = M.Blessings, H.Loadout.Blessings and H.Loadout.Blessings.Selection
						local locked = {}
						for _, cat in ipairs({ "Offense", "Body", "Defense", "Support" }) do
							local s = Sel and Sel[cat]
							if s and (s[1] or 0) == 0 and Bl and Bl[cat] then
								local best = 0
								for i = 2, 4 do local b = Bl[cat][s[i]] best = math.max(best, b and RK[b.Rarity] or 0) end
								local lc = math.ceil(2000 * 1.43 ^ (H.Loadout.Blessings.Rolled or 0) * 0.2)
								if best >= 4 and (tonumber(H.Loadout.Gold) or 0) >= lc + 3000 and H:Invoke("Waves", "Blessing", "Lock", cat) ~= nil then
									s[1] = 5
									locked[#locked + 1] = cat
								end
							end
						end
						local list, rew, rolled = H:Invoke("Waves", "Blessing", "Spin")
						if type(list) == "table" and rolled then
							H.Loadout.Blessings.Rolled = rolled
							local names = {}
							for _, b in pairs(type(rew) == "table" and rew or list) do names[#names + 1] = type(b) == "table" and tostring(b.Name or b.Tag or b[1]) or tostring(b) end
							action[2] = (#locked > 0 and ("Sperre " .. table.concat(locked, "+") .. ", ") or "") .. "Spin -> " .. table.concat(names, ", ")
						else
							action[2] = "Spin abgelehnt"
							A.nextSpin = os.clock() + 15 -- Server-Kosten/Rad noch aktiv -> nicht dauernd hinporten
						end
					end)
				elseif action[2] == "Bulk" then
					visit("Cole", function()
						local budget, bought = gold - 20000, {}
						A.hqCap = A.hqCap or {}
						local function c2(n) return os.clock() < (A.hqCap[n] or 0) and math.huge or cost(n) end
						for _ = 1, 20 do
							local n = c2("Max") <= c2("Regen") and "Max" or "Regen"
							local c = c2(n)
							if c > budget then break end
							local l0 = U[n]:GetAttribute("Upgrade")
							H:Invoke("Waves", "Upgrade", { n })
							-- Cost-Attribut kommt verzoegert -> kurz auf die neue Stufe warten, sonst zum alten Preis weitergerechnet
							local t = os.clock() + 0.5
							while U[n]:GetAttribute("Upgrade") == l0 and os.clock() < t do task.wait(0.05) end
							-- Stufe unveraendert = abgelehnt (gemessen 18.10.: Regen 5x "gekauft" ohne Goldabzug) -> 60s sperren
							if U[n]:GetAttribute("Upgrade") == l0 then A.hqCap[n] = os.clock() + 60 else
								budget = budget - c
								bought[n] = (bought[n] or 0) + 1
							end
						end
						action[2] = "Bulk Max x" .. (bought.Max or 0) .. " Regen x" .. (bought.Regen or 0)
					end)
				else
					local l0 = U and U:FindFirstChild(action[2]) and U[action[2]]:GetAttribute("Upgrade")
					visit("Cole", function() H:Invoke("Waves", "Upgrade", { action[2] }) end)
					-- Replenish nimmt der Server oft nicht (Stufe bleibt, kein Gold weg) -> 60s Pause, blockierte sonst alle Kaeufe
					if action[2] == "Replenish" and U.Replenish:GetAttribute("Upgrade") == l0 then
						A.noReplenish = os.clock() + 60 action[2] = "Replenish abgelehnt"
					end
				end
				task.wait(0.6)
				local g2 = H.Loadout and tonumber(H.Loadout.Gold) or 0
				-- Lulu hatte nichts mehr zu verkaufen (Gold gleich oder durch Kills gestiegen) -> 30s Ruhe statt alle 8s hinporten
				if action[1] == "Lulu" and g2 >= g0 then nextSword = os.clock() + 30 end
				PH("WAVE_BUY", string.format("%s %s | Gold %d -> %d | HQ %.0f%% Pool %d", action[1], tostring(action[2] or "Upgrade all"), g0, g2, hpPct, pool))
			end)
			cfg:SetAttribute("SkillTP", false)
		end
	end
end)

-- Auto-Cast: Schadens-Skills (Black/Red Flare, Order: Rage) zuenden sobald bereit
task.spawn(function()
	local CAST = { ["95"] = true, ["97"] = true, ["76"] = true }
	while A.on do
		task.wait(1)
		local me2 = game.Players.LocalPlayer
		local shifted2 = (me2.Character and me2.Character:GetAttribute("Shifter") ~= nil) or H.Shifting ~= nil or skillsBlocked()
		if cfg:GetAttribute("AutoCast") and not shifted2 and workspace:FindFirstChild("Titans") and #workspace.Titans:GetChildren() > 0 then
			pcall(function()
				task.synchronize()
				local lp = game.Players.LocalPlayer
				local L = H.Loadout
				local hb = L and L.Skills and L.Skills.Hotbar
				if not hb then return end
				for slot = 1, 5 do
					local id = tostring(hb[slot] or "")
					if CAST[id] and lp:GetAttribute("Skill_" .. slot) == nil and H.Skill == nil then
						preloadSkill(id)
						M.Skills.Use(H, lp, false, slot)
						cfg:SetAttribute("CastCount", (cfg:GetAttribute("CastCount") or 0) + 1)
						task.wait(1.5)
					end
				end
			end)
		end
	end
end)

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
	if cfg:GetAttribute("AutoKeys") or cfg:GetAttribute("AutoScrolls") then pcall(autoKeys) end
	farmStatus("Upgrade...")
	pcall(upgradeLoop, cfg:GetAttribute("FarmMaxGrade") or 12)
	-- Build NACH den Upgrades: Skills kosten Gold (1850 * 1.063^n), die Schwierigkeit bringt aber viel mehr XP
	-- (Aberrant-Abschluss 7025 XP vs. Easy 337) -> erst Grade, dann XP-Bonus-Build, dann Gold-Sink
	if cfg:GetAttribute("AutoBuild") then
		farmStatus("Skills/Perks...")
		pcall(autoBuild)
	end
	if cfg:GetAttribute("EnhancePerks") then pcall(enhancePerks) end
	if cfg:GetAttribute("SellPerks") then pcall(sellPerks) end
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
			-- Bonus-Map wandert weiter, wenn Boosted_Timer ablaeuft -> Ablaufzeit fuers Rundenende merken
			local bt = tonumber(workspace:GetAttribute("Boosted_Timer"))
			if bt and bt > 0 then pcall(writefile, "aot_bonus_until.txt", tostring(os.time() + bt)) end
		else
			farmStatus(pickMode .. ": nichts gefunden (" .. tostring(pm) .. ") -> feste Mission")
			task.wait(1)
		end
	end
	local mission = cfg:GetAttribute("FarmMission") or "Shiganshina · Skirmish"
	local map, obj = mission:match("^(.-) · (.+)$")
	map, obj = map or "Shiganshina", obj or "Skirmish"
	local raid = RAID_OBJ[obj] == true
	local waves = obj == "Waves"
	local diff = waves and "Easy" or bestDiff(g, raid) -- Waves: keine Schwierigkeitswahl
	local minimum = nil
	if raid and obj == "Colossal Titan" then minimum = 3 diff = (g >= 13) and "Aberrant" or nil end
	if not diff then farmStatus("Grade " .. g .. " zu niedrig fuer diesen Raid") farmRunning = false return end
	farmStatus("Erstelle " .. map .. " " .. obj .. " auf " .. diff .. " (Grade " .. g .. ")")
	pcall(function() GET:InvokeServer("S_Missions", "Leave") end)
	task.wait(0.5)
	local o = GET:InvokeServer("S_Missions", "Create", { Name = map, Difficulty = diff, Type = waves and "Waves" or (raid and "Raids" or "Missions"), Objective = obj, Minimum = minimum })
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
local endAt, endResends = nil, 0
local lobbyAt -- Lobby angefordert: Nachsende-Logik schickt dann Teleport statt Retry (19:51 hatte Retry den Lobby-Trip ueberholt)
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
				PH("END_DETECT", tostring(R and R.State) .. " rw=" .. tostring(workspace:GetAttribute("Rewarded")))
				task.wait((speedOn() or workspace:GetAttribute("Type") ~= "Raids") and 0.4 or 2.5)
				local farm = cfg:GetAttribute("AutoFarm")
				local slot, rinfo
				if cfg:GetAttribute("AutoChest") or farm then
					for _ = 1, 20 do
						local ok, a, b = pcall(function() return GET:InvokeServer("S_Rewards", "Get") end)
						if ok and a ~= nil and b ~= nil then slot = b rinfo = a break end
						task.wait(0.25)
					end
					PH("REWARDS", slot ~= nil)
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
					task.wait((speedOn() or workspace:GetAttribute("Type") ~= "Raids") and 0.2 or 1)
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
						-- Ping nur nach Seltenheit (User 18.10.: Legendary-Key/Serum hatte trotz "ab Mythic" gepingt)
						local rare = (RANKS[rar] or 0) >= minR
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
						writefile("aot_dropdbg.txt", (isfile("aot_dropdbg.txt") and readfile("aot_dropdbg.txt") or "") .. os.date("%H:%M:%S") .. " type=" .. tostring(workspace:GetAttribute("Type")) .. " rinfo=" .. type(rinfo) .. " {" .. table.concat(keys, ",") .. "} Obtained{" .. table.concat(obk, ",") .. "} chest#=" .. tostring(S_lastChest and #S_lastChest) .. " found#=" .. #found .. " [" .. (function() local q = {} for _, f in ipairs(found) do q[#q + 1] = f.name .. "/" .. f.rarity .. (f.rare and "*" or "") end return table.concat(q, ", ") end)() .. "]" .. string.char(10))
					end)
					S_lastChest = nil
					local gold, xp = 0, 0
					local cur = {}
					if type(ob) == "table" then
						gold = tonumber(ob.Gold) or 0 xp = tonumber(ob.XP) or 0
						-- Waves: Loot sind Waehrungen (keine Items) -> alle Zahlen-Eintraege mitschicken
						for kk, vv in pairs(ob) do if type(vv) == "number" and vv > 0 and kk ~= "Gold" and kk ~= "XP" then cur[kk] = vv end end
					end
					task.synchronize()
					cfg:SetAttribute("DropEvent", game:GetService("HttpService"):JSONEncode({
						items = found, map = workspace:GetAttribute("Objective"), diff = workspace:GetAttribute("Difficulty"),
						type = workspace:GetAttribute("Type"), t = os.time(), sec = (tonumber(workspace:GetAttribute("Seconds")) or 0) > 0 and workspace:GetAttribute("Seconds") or (type(rinfo) == "table" and rinfo.Seconds), gold = gold, xp = xp, cur = cur,
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
					-- "Fest" = Wahl des Users, nie automatisch umstellen (nur Auto-Modi fallen auf Beste Mission zurueck)
					if failed and farm and nf >= 2 and (cfg:GetAttribute("FarmPick") or "Fest") ~= "Fest" then
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
					if not upNow and (pm == "Bonus-Map" or pm == "Beste Mission") and workspace:GetAttribute("Type") == "Missions" then
						local okb, bu = pcall(function() return tonumber(readfile("aot_bonus_until.txt")) end)
						if okb and bu and os.time() >= bu + 5 then upNow = "Bonus-Map-Timer abgelaufen" pcall(delfile, "aot_bonus_until.txt") end
					end
					-- Gold-Sink: erst zur Lobby, wenn jeder Schadens-Stat +1 bezahlbar ist (Lobby-Trip kostet ~1 Min)
					if not upNow and cfg:GetAttribute("GoldSink") and gradeOf(slot) >= (cfg:GetAttribute("FarmMaxGrade") or 12) then
						local need = sinkRoundCost(slot)
						if need and (slot.Currency and slot.Currency.Gold or 0) - need >= (cfg:GetAttribute("GoldReserve") or 0) then upNow = "Schadens-Upgrades" end
					end
					-- Boost abgelaufen und Item/Gems da -> Lobby (nur wenn der Timer lesbar ist, max. alle 5 Min)
					if not upNow and cfg:GetAttribute("AutoBoost") and game.Players.LocalPlayer:FindFirstChild("Boosts") then
						for _, bk in ipairs(boostKinds()) do
							if not upNow and boostLeft(bk) <= 60 and boostPlan(slot, bk) then
								local okb, lb = pcall(function() return tonumber(readfile("aot_lastboost.txt")) end)
								if not (okb and lb) or os.time() - lb > 300 then upNow = "2x " .. bk .. "-Boost" end
							end
						end
					end
				end
				if not upNow and farm and speedOn() and type(slot) == "table" and slot.Upgrades then
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
					if not upNow and not isRaid and not nextThreshold(g) and g < maxG
						and (slot.Currency and slot.Currency.Gold or 0) >= costToGrade(slot, g + 1) then upNow = "Grade " .. (g + 1) end
				end
				if upNow then
					PH("LOBBY_SENT", upNow)
					lobbyAt = os.clock()
					farmStatus("-> Lobby: Gold reicht fuer " .. tostring(upNow))
					task.synchronize()
					game:GetService("ReplicatedStorage").Assets.Remotes.POST:FireServer("Functions", "Teleport")
				elseif farm and speedOn() then
					local nm = syncMods(function() return workspace:GetAttribute("Modifiers") end, "Functions", "Modify")
					farmStatus("Speed: Retry (" .. nm .. " leichte Modifier)")
					PH("RETRY_SENT", "speed")
					local okr, rr = pcall(function() return GET:InvokeServer("Functions", "Retry", "Add") end)
					PH("RETRY_RET", tostring(okr) .. " " .. tostring(rr))
				elseif farm then
					local goLobby, why = false, ""
					if type(slot) == "table" and slot.Upgrades then
						local g = gradeOf(slot)
						local gold = slot.Currency and slot.Currency.Gold or 0
						local maxG = cfg:GetAttribute("FarmMaxGrade") or 12
						local nt, nd = nextGoal(g, maxG)
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
						PH("LOBBY_SENT", why)
						lobbyAt = os.clock()
						game:GetService("ReplicatedStorage").Assets.Remotes.POST:FireServer("Functions", "Teleport")
					else
						syncMods(function() return workspace:GetAttribute("Modifiers") end, "Functions", "Modify")
						PH("RETRY_SENT", "normal")
						local okr, rr = pcall(function() return GET:InvokeServer("Functions", "Retry", "Add") end)
						PH("RETRY_RET", tostring(okr) .. " " .. tostring(rr))
					end
				elseif cfg:GetAttribute("AutoRetry") then
					pcall(function() GET:InvokeServer("Functions", "Retry", "Add") end)
				end
				endAt, endResends = os.clock(), 0
			elseif (cfg:GetAttribute("AutoFarm") or cfg:GetAttribute("AutoRetry")) and endAt and os.clock() - endAt > (workspace:GetAttribute("Starting") == nil and 2.5 or 10) and endResends < 12
				and not (game.Players.LocalPlayer:GetAttribute("Teleporting") == true and (workspace:GetAttribute("Starting") or 0) > 0) then
				-- Retry kam nicht an (Runde steht weiter auf Ende) -> erneut senden
				endResends = endResends + 1
				endAt = os.clock()
				farmStatus("Retry erneut (" .. endResends .. ")")
				if lobbyAt and os.clock() - lobbyAt < 60 then
					-- Lobby war angefordert: Teleport erneut statt Retry (sonst startet die naechste Runde, kein Lobby-Kauf)
					PH("LOBBY_RESEND", endResends)
					pcall(function() game:GetService("ReplicatedStorage").Assets.Remotes.POST:FireServer("Functions", "Teleport") end)
				else
					PH("RETRY_RESEND", endResends)
					pcall(function() GET:InvokeServer("Functions", "Retry", "Add") end)
				end
			end
		else
			endDone = false
			endAt = nil
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
local refillParts, refillIdx = nil, 0
-- verfuegbare Refills: eigene + (Waves) gemeinsamer Pool Workspace.Waves.Upgrades.Refills (das Spiel rechnet genauso:
-- ODMG.Reload -> Player.Refills + Zones.Reference.Value); im Wave-Modus steht der eigene Zaehler immer auf 0
local function wavePool()
	local w = workspace:GetAttribute("Type") == "Waves" and workspace:FindFirstChild("Waves")
	local r = w and w:FindFirstChild("Upgrades") and w.Upgrades:FindFirstChild("Refills")
	return r and r:IsA("ValueBase") and r or nil
end
local function refillsLeft()
	local pool = wavePool()
	return (LP:GetAttribute("Refills") or 0) + (pool and pool.Value or 0)
end
local function doRefill()
	-- Remote-Refill; fertig sobald der Server das Refills-Attribut runterzaehlt. Nicht angenommen -> nach 1,5s
	-- naechste Tankstelle (Raid-Map hat 12; vorher immer dieselbe + 5s Warten = Klingen lange leer)
	if refilling or not C.AutoRefill or refillsLeft() <= 0 then return false end
	if not (refillParts and refillParts[1] and refillParts[1].Parent) then
		refillParts = {}
		for _, d in ipairs(workspace:GetDescendants()) do
			if d.Name == "Refill" and d:IsA("BasePart") then refillParts[#refillParts + 1] = d end
		end
		refillIdx = 0
	end
	if #refillParts == 0 then return false end
	refillIdx = refillIdx % #refillParts + 1
	refillPart = refillParts[refillIdx]
	refilling = true
	local before = refillsLeft()
	POST:FireServer("Attacks", "Reload", refillPart)
	local t0 = os.clock()
	while os.clock() - t0 < 1.5 and refillsLeft() == before do task.wait(0.05) end
	refilling = false
	local ok = refillsLeft() ~= before
	PH("REFILL", (ok and "OK " or "nein ") .. refillIdx .. "/" .. #refillParts .. " " .. refillPart.Parent.Parent.Name)
	if ok then
		refillIdx = refillIdx - 1 -- funktionierende Station beim naechsten Mal zuerst
		sets = 3
		return true
	end
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
	local avail = (sets or 0) + 3 * refillsLeft() + bladesLeft() / 7
	local need = left * hpk / HITS_PER_SET
	return avail, need, hpk
end
S.bladeBudget = bladeBudget
local function reloadAt()
	if C.ReloadAt <= 1 then return 1 end
	if not C.BladeSaver then return C.ReloadAt end -- Klingen egal: immer frueh nachladen -> jeder Slash mit voller Trefferzahl
	local ok, avail, need = pcall(bladeBudget)
	-- frueher Reload kostet bis ~1.7x Klingen -> nur mit 2x Puffer + 1 Satz Reserve
	if ok and avail >= need * 2 + 1 then return C.ReloadAt end
	return 1
end
local nextReloadTry = 0
local function ensureBlades(force)
	local b = bladesLeft()
	if b > reloadAt() then return true end
	-- Noch Klingen da (frueher Reload): nie blockieren. Ein Reload-Versuch hoechstens alle 0.5s, Refill im Hintergrund,
	-- solange mit den Restklingen weiterschlagen (nach einem Refill nimmt der Server ~2.6s keinen Reload an).
	if b > 1 then
		if (C.AutoReload or force) and not reloading and os.clock() >= nextReloadTry then
			nextReloadTry = os.clock() + 0.5
			reloading = true
			pcall(function()
				if syncSets() ~= 0 then
					if inv(2, "Blades", "Reload") == true and sets then sets = math.max(sets - 1, 0) end
				elseif not refilling then
					task.spawn(doRefill)
				end
			end)
			reloading = false
		end
		return true
	end
	DBG("ENSURE start sets=" .. tostring(sets) .. " refilling=" .. tostring(refilling))
	if (not C.AutoReload and not force) or reloading then return false end
	reloading = true
	local ok = false
	pcall(function()
		-- bekannt leer -> keinen zum Scheitern verurteilten Reload abwarten, direkt Refill
		if syncSets() ~= 0 then
			-- Saetze laut HUD vorhanden: ein abgelehnter Reload ist der Server-Cooldown (~2.6s nach dem letzten
			-- Reload/Refill) -> wiederholen statt faelschlich "leer" anzunehmen und einen Refill zu verschwenden
			local t0 = os.clock()
			repeat
				if inv(2, "Blades", "Reload") == true then ok = true if sets then sets = math.max(sets - 1, 0) end return end
				task.wait(0.15)
			until os.clock() - t0 > 3.5 or syncSets() == 0
			if syncSets() ~= 0 then return end
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
-- Refill bei <= Reload-Schwelle (Server ignoriert Refills bei mehr Restklingen: 2x 5s Warten gemessen)
local function refillAt() return reloadAt() end
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
-- Treffer pro Kill (Waves-Fokusfeuer): gesendete Treffer je Titan bis er verschwindet, Median der letzten 15.
-- Stirbt ein Titan im Slash mit k Treffern, lag der Bedarf zwischen prev+1 und prev+k -> Mitte speichern
-- (sonst schaukelt sich die Schaetzung hoch, weil jeder Titan genau so viele bekommt wie geschaetzt)
S.hitCount = setmetatable({}, { __mode = "k" })
S.hitPrev = setmetatable({}, { __mode = "k" })
S.hpkS = {}
local function hpkWatch(tf)
	if not tf then return end
	conn(tf.ChildRemoved:Connect(function(t)
		local h = S.hitCount[t]
		if h and h > 0 and not t:GetAttribute("Shifter") then
			local p = S.hitPrev[t] or 0
			table.insert(S.hpkS, p + (h - p + 1) / 2)
			if #S.hpkS > 15 then table.remove(S.hpkS, 1) end
			local c = table.clone(S.hpkS) table.sort(c)
			S.hpk = c[math.ceil(#c / 2)]
		end
	end))
end
-- Fokusfeuer: jedem Titan so viele Treffer wie fuer einen Kill noetig (statt 1 je Titan, gemessen 18.10. spaete Wellen:
-- 15 Treffer/Slash -> ~2 Kills, 30 Titanen stauten sich am HQ). Gibt die Zahl verbrauchter Treffer zurueck
-- cap = Treffer, die der Server pro Slash annimmt (~Klingen+1, gemessen); nur die zaehlen und werden verteilt -
-- mitgezaehlte verworfene Treffer trieben die Schaetzung hoch (18.10.: 5,5 statt 1 in fruehen Wellen)
local function focusHits(entries, n, fire, cap)
	cap = math.min(n, cap or n)
	-- 1 Treffer je Titan und Slash (Mehrfachtreffer kosteten gemessen Kills, Schaetzung lief hoch); Fokus entsteht
	-- ueber die Reihenfolge (angeschlagene + zuschlagende zuerst). hpk ist so exakt messbar -> nur Diagnose
	local need = 1
	local used = 0
	for _, e in ipairs(entries) do
		if used >= cap then break end
		local have = S.hitCount[e.t] or 0
		S.hitPrev[e.t] = have
		local k = math.min(math.max(1, need - have), cap - used)
		for _ = 1, k do fire(e) end
		S.hitCount[e.t] = have + k
		lastHit[e.t] = os.clock()
		used = used + k
	end
	return used
end
hpkWatch(workspace:FindFirstChild("Titans"))
conn(workspace.ChildAdded:Connect(function(c) if c.Name == "Titans" then hpkWatch(c) end end))
-- Erens Leben ins Phasen-Log (Colossal-Raid)
task.spawn(function()
	local last
	while S.alive do
		task.wait(0.5)
		local ob = workspace:FindFirstChild("Unclimbable") and workspace.Unclimbable:FindFirstChild("Objective")
		local hv = ob and ob:FindFirstChild("Defend_Eren_2") and ob.Defend_Eren_2:FindFirstChild("Health")
		if hv and hv.Value ~= last then last = hv.Value PH("EREN_HP", math.floor(hv.Value)) end
	end
end)
local function targets()
	local tf = workspace:FindFirstChild("Titans")
	local hrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
	if not tf or not hrp then return {} end
	local list, now = {}, os.clock()
	local raidMode = workspace:GetAttribute("Type") == "Raids"
	local waveMode = workspace:GetAttribute("Type") == "Waves"
	for _, t in ipairs(tf:GetChildren()) do if not t:IsA("Model") then continue end
		local hb = t:FindFirstChild("Hitboxes")
		local hit = hb and hb:FindFirstChild("Hit")
		local nape = hit and hit:FindFirstChild("Nape")
		local root = t:FindFirstChild("HumanoidRootPart") or t.PrimaryPart
		-- Waves (gemessen 18.10. per Tod-Orakel): Titanen OHNE Humanoid (nur HumanoidRootPart/Hitboxes/Fake) sind noch
		-- nicht aktiviert und unverwundbar - ueberlebten Slash fuer Slash und frassen als "naechste" die Treffer
		-- (Server nimmt eh nur ~8/Slash an: von 15 gesendeten kamen so im Schnitt nur 4,4 an). Bosse ausgenommen
		-- auch Raids (18.10.: im Colossal Phase 2 hatten 5 von 6 kleinen Titanen keinen Humanoid, Eren-Slashes 4,5 statt 7,5 angenommen)
		local young = (waveMode or raidMode) and not t:GetAttribute("Shifter") and t:FindFirstChildOfClass("Humanoid") == nil
		if nape and root and not young and (not lastHit[t] or now - lastHit[t] > C.HitCD) then
			local d = (root.Position - hrp.Position).Magnitude
			-- Raids: Titanen nach Naehe zum Verteidigungsziel (Attribut Distance) priorisieren
			if raidMode then
				local od = t:GetAttribute("Distance")
				if od then d = od end -- naechster am Verteidigungsziel zuerst
			end
			local immune = false
			if t:GetAttribute("Type") == "Colossal" then
				local ob = workspace:FindFirstChild("Unclimbable") and workspace.Unclimbable:FindFirstChild("Objective")
				local de = ob and ob:FindFirstChild("Defend_Eren_2")
				-- Phase 1 endet bei 50% Leben (Phase-Attribut wechselt nicht zuverlaessig)
				local pc
				for _, g in ipairs(LP.PlayerGui:GetDescendants()) do
					if g:IsA("TextLabel") and g.Name == "Percentage" and g.Visible then pc = tonumber((g.Text:gsub("%%", ""))) break end
				end
				immune = #game:GetService("CollectionService"):GetTagged("Cannon") > 0 -- Phase 1 = Kanonen aktiv
			end
			if immune then d = math.huge end -- Phase 1: Colossal nur per Kanone verwundbar
			if t:GetAttribute("Shifter") and not immune then d = -1 lastHit[t] = nil end -- Raid-Boss immer zuerst, ohne Cooldown
			if d ~= math.huge and (C.AuraRange >= 20000 or d <= C.AuraRange) then list[#list + 1] = { t = t, nape = nape, d = d } end
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
		-- nur der Kill-Aura-Toggle zaehlt (frueher "or AutoFarm": Toggle aus -> trotzdem getoetet)
		if C.KillAura and LP.Character and LP:GetAttribute("Weapon") == "Blades" then
			local hum = LP.Character:FindFirstChildOfClass("Humanoid")
			if hum and hum.Health > 0 then
				local list = targets()
				if #list > 0 then
					if ensureBlades() then
						-- Colossal Phase 1 (Kanone): ruhige Aura 8/1.8s, sonst normal
						local canPhase = false
						if workspace:GetAttribute("Objective") == "Colossal Titan" then
							for _, g in ipairs(LP.PlayerGui:GetDescendants()) do
								if g:IsA("TextLabel") and g.Name == "Percentage" and g.Visible then
									local pc = tonumber((g.Text:gsub("%%", "")))
									local ob2 = workspace:FindFirstChild("Unclimbable") and workspace.Unclimbable:FindFirstChild("Objective")
									canPhase = #game:GetService("CollectionService"):GetTagged("Cannon") > 0
									break
								end
							end
						end
						-- Phase 1 mit Auto-Kanone: gar nicht slashen. Gemessen (221 Kanonenschuesse, 17.10.): Slash < 1s vor dem
						-- Einschlag -> Server verwirft den ganzen Kanonenschuss (0 statt 7-10 Treffer a ~522k); in Phase 1 gibt es nichts zu treffen
						if canPhase and C.AutoCannon then task.wait(0.2) return end
						local cd = C.SmartAura and (canPhase and 1.8 or (C.SpeedMode and math.min(C.SmartGap, 1.5) or C.SmartGap)) or C.Interval
						-- Raids: wenige Refills -> seltener aber voll slashen (gleiche Treffer/s, ~3x weniger Klingenverbrauch)
						-- (frueher fest 4s in Raids: Klingen verschleissen pro Treffer, nicht pro Slash -> bremste nur Phase 1)
						local dt = os.clock() - lastSlash
						if dt < cd then task.wait(cd - dt) end
						list = targets()
						local n = S.forceHits or (C.SmartAura and (canPhase and math.min(8, bladesLeft() + 1) or math.min(C.MaxHits, bladesLeft() + 1 + (C.MaxHits - 8))) or C.PerCycle)
						if #list > 0 then
							lastSlash = os.clock()
							RB.hits = RB.hits + math.min(n, #list)
							DBG("SLASH n=" .. math.min(n, #list) .. " blades=" .. bladesLeft() .. " targets=" .. #list)
							PH("SLASH", "n=" .. n .. " t=" .. #list .. " b=" .. bladesLeft() .. " k=" .. S.kills .. " hpk=" .. string.format("%.1f", S.hpk or 1))
							-- Diagnose: Zustaende der Ziele (toter Titan im Ordner = verschwendeter Treffer?)
							do
								local cnt = {}
								for i = 1, math.min(#list, 16) do local st = tostring(list[i].t:GetAttribute("State")) cnt[st] = (cnt[st] or 0) + 1 end
								local o = {}
								for k, v in pairs(cnt) do o[#o + 1] = k .. "=" .. v end
								-- Entfernung Ziel <-> eigener Charakter (Test: begrenzt der Server angenommene Treffer nach Abstand?)
								local hrp0 = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
								if hrp0 then
									local b = { 0, 0, 0, 0 }
									for i = 1, #list do
										local r = list[i].t:FindFirstChild("HumanoidRootPart") or list[i].t.PrimaryPart
										local dd = r and (r.Position - hrp0.Position).Magnitude or 1e9
										local ix = dd < 300 and 1 or dd < 600 and 2 or dd < 1000 and 3 or 4
										b[ix] = b[ix] + 1
									end
									o[#o + 1] = string.format("d<300:%d <600:%d <1000:%d >1000:%d", b[1], b[2], b[3], b[4])
								end
								PH("TARGET_STATES", table.concat(o, " "))
							end
							POST:FireServer("Attacks", "Slash", true)
							task.wait(0.03)
							local bossE = C.BossFocus and list[1] and list[1].t:GetAttribute("Shifter") and list[1]
							local role = C.CoopRole or "Solo"
							if bossE and role == "Player 2" then
								-- Coop P2: nur Boss
								for _ = 1, n do
									POST:FireServer("Hitboxes", "Register", bossE.nape, 200 + math.random() * 40, 0.25 + math.random() * 0.4)
								end
							elseif bossE and role == "Player 1" then
								-- Coop P1 (Verteidiger): kleine Titanen naechst an Eren zuerst, Rest auf den Boss
								local smalls = {}
								for i = 2, #list do smalls[#smalls + 1] = list[i] end
								table.sort(smalls, function(x, y) return (x.t:GetAttribute("Distance") or x.d) < (y.t:GetAttribute("Distance") or y.d) end)
								local used = 0
								for _, e in ipairs(smalls) do
									if used >= n then break end
									lastHit[e.t] = os.clock()
									POST:FireServer("Hitboxes", "Register", e.nape, 200 + math.random() * 40, 0.25 + math.random() * 0.4)
									used = used + 1
								end
								for _ = used + 1, n do
									POST:FireServer("Hitboxes", "Register", bossE.nape, 200 + math.random() * 40, 0.25 + math.random() * 0.4)
								end
							elseif bossE then
								-- Eren-Schutz: nie mit Boss-Treffern mischen (gemessen 17.10.: Slash mit Eren-Titanen -> Server verwirft
								-- oft den ganzen Slash, Ø 3,2 statt 9,5 angenommen). Abwechselnd reiner Eren-Slash / reiner Boss-Slash.
								-- Schutzziel: Raid = Eren (Attribut Distance), Waves = HQ (echter Abstand zum HQ, Haendler stehen dort)
								local waves = workspace:GetAttribute("Type") == "Waves"
								local hqPos
								if waves then
									local npc = workspace:FindFirstChild("Waves") and workspace.Waves:FindFirstChild("NPCs") and workspace.Waves.NPCs:FindFirstChild("Cole")
									hqPos = npc and npc:GetPivot().Position
								end
								local near = {}
								for i = 2, #list do
									local e = list[i]
									local toGoal = e.t:GetAttribute("Distance")
									if waves and hqPos then
										local r = e.t:FindFirstChild("HumanoidRootPart") or e.t.PrimaryPart
										toGoal = r and (r.Position - hqPos).Magnitude
									end
									if waves then
										-- Waves (gemessen 18.10.): HQ fiel in der Boss-Welle 100->31%, obwohl nur 1-2 Titanen <300 Studs
										-- an Cole standen - das HQ ist gross, die zuschlagenden Titanen (Smack) stehen weiter weg.
										-- Darum alle kleinen Titanen, zuschlagende zuerst, dann nach Abstand zum HQ
										local st = tostring(e.t:GetAttribute("State"))
										local atk = st:find("Smack") or st:find("Attack") or st:find("Grab")
										-- angeschlagene zuerst fertigmachen (Fokusfeuer)
										near[#near + 1] = { e = e, d = (toGoal or 1e6) - (atk and 1e7 or 0) - ((S.hitCount[e.t] or 0) > 0 and 5e6 or 0) }
									elseif C.ErenGuard ~= false and toGoal and toGoal < (C.ErenGuardRange or 300) then near[#near + 1] = { e = e, d = toGoal } end
								end
								table.sort(near, function(x, y) return x.d < y.d end)
								-- Prioritaet nach Erens Leben: >=90% -> 10% der Slashes fuer Eren, <=30% -> alle, dazwischen linear
								-- (gleichmaessig per Akkumulator statt Zufall; Rest geht auf den Boss)
								local ob = workspace:FindFirstChild("Unclimbable") and workspace.Unclimbable:FindFirstChild("Objective")
								local hv = ob and ob:FindFirstChild("Defend_Eren_2") and ob.Defend_Eren_2:FindFirstChild("Health")
								-- Health ist absolut (z.B. 61.2), Maximum im Attribut Max_Health -> in Prozent umrechnen
								local hmax = hv and tonumber(hv:GetAttribute("Max_Health")) or 0
								local hp = (hv and hmax > 0) and math.clamp(hv.Value / hmax * 100, 0, 100) or 50
								-- gieriger (User: ~25% HP-Puffer uebrig): >=55% -> 10%, ~32% -> 55%, <=10% -> alles
								local share = 0.1 + 0.9 * math.clamp((55 - hp) / 45, 0, 1)
								if waves then
									-- HQ-Leben (Workspace.Unclimbable.Objective.Waves.Health): >=95% -> halbe Slashes auf Titanen,
									-- <=60% -> alle. Kleine Titanen sterben pro Slash zu ~8, danach geht ohnehin alles auf den Boss
									local Wv = ob and ob:FindFirstChild("Waves")
									local h = Wv and Wv:FindFirstChild("Health")
									local mx = h and tonumber(h:GetAttribute("Max_Health")) or 0
									hp = (h and mx > 0) and math.clamp(h.Value / mx * 100, 0, 100) or 100
									share = 0.5 + 0.5 * math.clamp((95 - hp) / 35, 0, 1)
								end
								S.erenAcc = (S.erenAcc or 0) + share
								S.erenTurn = S.erenAcc >= 1
								if S.erenTurn then S.erenAcc = S.erenAcc - 1 end
								local used = 0
								if #near > 0 and S.erenTurn then
									-- erst Titanen an Eren (1 Treffer je Titan), Rest des Slashes auf den Boss
									if waves then
										local es = {}
										for i, x in ipairs(near) do es[i] = x.e end
										used = focusHits(es, n, function(e) POST:FireServer("Hitboxes", "Register", e.nape, 200 + math.random() * 40, 0.25 + math.random() * 0.4) end, bladesLeft() + 1)
									else
										for _, x in ipairs(near) do
											if used >= n then break end
											lastHit[x.e.t] = os.clock()
											POST:FireServer("Hitboxes", "Register", x.e.nape, 200 + math.random() * 40, 0.25 + math.random() * 0.4)
											used = used + 1
										end
									end
									PH("EREN_SLASH", #near .. " an Eren, " .. used .. " Treffer, Rest " .. (n - used) .. " auf Boss, Eren " .. math.floor(hp) .. "% -> Anteil " .. math.floor(share * 100) .. "%")
								else
									PH("BOSS_SLASH", #near .. " nah an Eren")
								end
								for _ = used + 1, n do
									POST:FireServer("Hitboxes", "Register", bossE.nape, (S.hitVel or 200) + math.random() * 40, 0.25 + math.random() * 0.4)
								end
							elseif workspace:GetAttribute("Type") == "Waves" then
								-- Waves ohne Boss: Fokusfeuer, zuschlagende + angeschlagene Titanen zuerst, dann naechste am HQ
								local cole = workspace:FindFirstChild("Waves") and workspace.Waves:FindFirstChild("NPCs") and workspace.Waves.NPCs:FindFirstChild("Cole")
								local hqPos = cole and cole:GetPivot().Position
								local es = {}
								for _, e in ipairs(list) do
									local st = tostring(e.t:GetAttribute("State"))
									local atk = st:find("Smack") or st:find("Attack") or st:find("Grab")
									local r = e.t:FindFirstChild("HumanoidRootPart") or e.t.PrimaryPart
									local dh = (hqPos and r) and (r.Position - hqPos).Magnitude or e.d
									es[#es + 1] = { t = e.t, nape = e.nape, k = dh - (atk and 1e7 or 0) - ((S.hitCount[e.t] or 0) > 0 and 5e6 or 0) }
								end
								table.sort(es, function(a, b) return a.k < b.k end)
								local fire = function(e) POST:FireServer("Hitboxes", "Register", e.nape, (S.hitVel or 200) + math.random() * 40, 0.25 + math.random() * 0.4) end
								local used = focusHits(es, n, fire, bladesLeft() + 1)
								-- Rest (weniger Titanen als Treffer): reihum auf dieselben Nacken
								if C.FillHits and used < n and #es > 0 then
									for j = 1, n - used do fire(es[(j - 1) % #es + 1]) end -- ueber dem Annahme-Limit: nicht mitzaehlen
								end
							else
								for i = 1, math.min(n, #list) do
									local e = list[i]
									lastHit[e.t] = os.clock()
									POST:FireServer("Hitboxes", "Register", e.nape, (S.hitVel or 200) + math.random() * 40, 0.25 + math.random() * 0.4)
								end
								-- weniger Titanen als Treffer: Rest reihum auf dieselben Nacken (Rundenende geht sonst mit halben Slashes raus)
								if C.FillHits and n > #list then
									for j = 1, n - #list do
										local e = list[(j - 1) % #list + 1]
										POST:FireServer("Hitboxes", "Register", e.nape, (S.hitVel or 200) + math.random() * 40, 0.25 + math.random() * 0.4)
									end
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
					if nf >= 2 and C.FarmPick ~= "Fest" then C.FarmPick = "Beste Mission" syncCfg() nf = 0 end
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
		local stuck = C.AutoFarm and C.StuckLeave and workspace:GetAttribute("Type") ~= "Waves" and workspace:FindFirstChild("Titans") and bladesLeft() <= 1
			and (LP:GetAttribute("Refills") or 0) <= 0 and sets == 0
		if stuck then
			since = since or os.clock()
			if os.clock() - since > 8 then
				Cfg:SetAttribute("FarmStatus", "Keine Klingen/Refills mehr -> Lobby")
				-- im Raid zaehlt das als Fehlschlag (2x -> zurueck auf die beste Mission)
				if workspace:GetAttribute("Type") == "Raids" then
					local okf, nf = pcall(function() return tonumber(readfile("aot_raidfail.txt")) end)
					nf = (okf and nf or 0) + 1
					if nf >= 2 and C.FarmPick ~= "Fest" then C.FarmPick = "Beste Mission" syncCfg() nf = 0 end
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
	-- der Charakter-Actor ist nicht immer aktiv -> alle probieren, bis einer laeuft
	local list = {}
	for _, a in ipairs(getactors()) do if LP.Character and a:IsDescendantOf(LP.Character) then table.insert(list, 1, a) else list[#list + 1] = a end end
	local code = [[
		local H
		for _, v in ipairs(getgc(true)) do
			if type(v) == "table" and rawget(v, "Prefix") == "rbxassetid://" and type(rawget(v, "Cache")) == "table" then H = v break end
		end
		local _, sl = H.Modules.Update.Get_Data(H, true)
		local gp = game.Players.LocalPlayer:FindFirstChild("Gamepasses")
		local bag = gp and gp:FindFirstChild("Family_Bag") and gp.Family_Bag.Value == true
		local cap = 1 + (bag and 10 or 0) + ((sl.Extra_Slots and sl.Extra_Slots.Family) or 0)
		writefile("aot_fam.json", game:GetService("HttpService"):JSONEncode({ stored = sl.Inventory.Families or {}, cap = cap }))
	]]
	for _, a in ipairs(list) do if pcall(run_on_actor, a, code) then break end end
	for _ = 1, 30 do if isfile("aot_fam.json") then break end task.wait(0.1) end
	local ok, d = pcall(function() return game:GetService("HttpService"):JSONDecode(readfile("aot_fam.json")) end)
	if ok and type(d) == "table" then return d.stored or {}, d.cap or 1 end
	return nil, nil -- nicht lesbar
end
local function autoRoll()
	if S.rolling then S.rolling = false return end
	S.rolling = true
	local n = 0
	local stored, cap = {}, 1
	local tier = RANK[C.RollStartTier] or 3
	if C.RollDeposit then
		stored, cap = famStorage()
		if not stored then S.rollStatus = "Lager nicht lesbar -> Roll nicht gestartet (nochmal druecken)" S.rolling = false return end
		-- alle Plaetze ab der Start-Stufe fuellen; voll -> schlechteste eingelagerte durch bessere ersetzen
		-- (frueher: ab 2 Stueck einer Stufe nur noch hoehere -> Lager blieb bei 2/6)
	end
	while S.rolling and S.alive do
		local ok, spins, extra, fam, pity
		-- Server-Cooldown ~3.4s zwischen Rolls: bis zu 6s alle 0.25s erneut versuchen
		local t0 = os.clock()
		local back = 0.6
		repeat
			ok, spins, extra, fam, pity = pcall(function() return GET:InvokeServer("Family", "Roll") end)
			if ok and fam ~= nil then break end
			-- abgelehnt: ruhig zurueckhalten statt spammen (Spam verlaengert die Sperre)
			task.wait(back)
			back = math.min(back + 0.4, 2)
		until os.clock() - t0 > 8 or not S.rolling
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
					if oks and ok2 == true then stored[#stored + 1] = sf or fam end
				end
			end
			local names = {}
			for _, f in ipairs(stored) do names[#names + 1] = f end
			S.rollStatus = string.format("#%d: %s (%s) · Spins %d · Pity %s\nLager %d/%d: %s · lagert ab %s", n, tostring(fam), rar, left, tostring(pity), #stored, cap, table.concat(names, ", "), RNAME[tier] or "MAX")
		elseif C["RollStop_" .. rar] then
			S.rollStatus = "TREFFER: " .. tostring(fam) .. " (" .. rar .. ") nach " .. n .. " Rolls · Spins " .. left
			break
		end
		if left <= 0 then S.rollStatus = S.rollStatus .. " · keine Spins mehr" break end
		-- kein fester Cooldown: die Retry-Schleife oben pollt alle 0.25s, bis der Server den naechsten Roll annimmt
		S.rollTimes = S.rollTimes or {}
		S.rollTimes[#S.rollTimes + 1] = os.clock()
		if #S.rollTimes >= 2 then
			S.rollGap = S.rollTimes[#S.rollTimes] - S.rollTimes[#S.rollTimes - 1]
			S.rollStatus = S.rollStatus .. string.format(" · %.1fs/Roll", S.rollGap)
		end
		task.wait(C.RollGap or 0.55)
	end
	S.rolling = false
end
S.autoRoll = autoRoll

-- Auto-Kisten: S_Inventory("Crate", name) -> (SlotDaten, Item, Raritaet, Pity). Kein Server-Cooldown (~50ms/Kiste).
local function crateNames()
	local ok, Cr = pcall(function() return require(game:GetService("ReplicatedStorage").Modules.Storage.Crates) end)
	local t = {}
	if ok and type(Cr) == "table" then for k in pairs(Cr) do t[#t + 1] = k end end
	table.sort(t)
	return t
end
-- Oeffnen laeuft im Actor (dort liegt der Client-Daten-Cache): Server-Antwort ersetzt den Cache, danach Inventar neu zeichnen
local function autoCrates()
	if Cfg:GetAttribute("Crating") then Cfg:SetAttribute("CrateStop", true) return end
	Cfg:SetAttribute("CrateSel", C.CrateSel or "Alle")
	Cfg:SetAttribute("CrateReq", os.clock())
end
S.autoCrates = autoCrates

-- Lobby-Teleport, der auch einen haengenden Teleport ("previous teleport is in processing") aufloest
function lobbyTP()
	local TS = game:GetService("TeleportService")
	pcall(function() RS:Set3dRenderingEnabled(true) end)
	pcall(function() TS:TeleportCancel() end)
	task.wait(1)
	pcall(function() TS:Teleport(14916516914, LP) end)
end

-- Teleport-Watchdog: haengt ein Retry/Teleport > 60s -> Client-Teleport in die Lobby (Auto-Farm laeuft dort weiter)
task.spawn(function()
	local since
	while S.alive do
		if C.AutoFarm and LP:GetAttribute("Teleporting") == true and workspace:FindFirstChild("Titans") then
			since = since or os.clock()
			if os.clock() - since > 60 then
				Cfg:SetAttribute("FarmStatus", "Teleport haengt -> Lobby")
				lobbyTP()
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
	for _, t in ipairs(tf:GetChildren()) do if not t:IsA("Model") then continue end
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
	if not C.BossEvade or S.baiting then return end -- Koeder schwebt ausser Reichweite, nicht wegversetzen
	if Cfg:GetAttribute("SkillTP") then return end -- Boss-Skill laeuft: Charakter steht absichtlich am Nacken
	if C.SafeSpot and LP.Character and LP.Character:FindFirstChild("HumanoidRootPart") and LP.Character.HumanoidRootPart.Anchored then return end -- steht am sicheren Platz
	if S.waveHeld and Cfg:GetAttribute("SkillTP") ~= true then return end -- Waves: oben verankert, nicht auf den Boden versetzen
	if LP.Character and LP.Character:GetAttribute("Shifter") ~= nil then return end -- im Titan-Modus nie wegversetzen
	-- auf der Kanone nicht wegversetzen (sonst ist die Kanone weg und es wird nicht mehr gefeuert)
	for _, c in ipairs(game:GetService("CollectionService"):GetTagged("Cannon")) do
		if c:GetAttribute("Player") == LP.Name then return end
	end
	if os.clock() - lastEvade < 0.4 then return end
	local hrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
	local tf = workspace:FindFirstChild("Titans")
	if not hrp or not tf then return end
	-- naechste Gefahr: Boss < 300 Studs oder normaler Titan < 120 Studs
	local broot
	for _, t in ipairs(tf:GetChildren()) do if not t:IsA("Model") then continue end
		local root = t:FindFirstChild("HumanoidRootPart") or t.PrimaryPart
		if root then
			local d = Vector3.new(hrp.Position.X - root.Position.X, 0, hrp.Position.Z - root.Position.Z).Magnitude
			-- Waves: nur vor Bossen ausweichen (normale Titanen sind dort dauernd nah -> staendiges Wegversetzen)
			-- ausser sie stehen direkt bei einem (gemessen 18.10.: spaete Wellen, 30 Titanen am HQ, Leben 65% -> Runde verloren)
			local skip = workspace:GetAttribute("Type") == "Waves" and not t:GetAttribute("Shifter") and d >= (C.WaveCloseEvade or 100)
			if not skip and d < (t:GetAttribute("Shifter") and (C.BossEvadeRange or 600) or (C.EvadeRange or 400)) then broot = root break end
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
		local target = broot.Position + dir * ((broot.Parent and broot.Parent:GetAttribute("Shifter")) and (C.BossSafeDist or 1300) or 900)
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
	-- nur seltene melden: ohne Drop ab "Ping ab" (bzw. Serum/Key) gar nichts schicken
	-- Waves + Raids: jede beendete Runde melden (User 18.10.), egal ob selten; Ping bleibt nur bei selten
	if C.WebhookRareOnly and not anyRare and ev.type ~= "Waves" and ev.type ~= "Raids" then return end
	if #lines == 0 then lines[1] = "_keine Items_" end
	local function k(n) n = tonumber(n) or 0 if n >= 1e3 then return string.format("%.1fk", n / 1e3) end return tostring(n) end
	-- Loot-Waehrungen (Gems/Shards/Silver/...) + Laufzeit als eigene Felder
	local fields = {}
	local sec = tonumber(ev.sec)
	fields[1] = { name = "Zeit", value = sec and string.format("%d:%02d min", sec // 60, sec % 60) or "?", inline = true }
	fields[2] = { name = "Gold / XP", value = "+" .. k(ev.gold) .. " / +" .. k(ev.xp), inline = true }
	local cl = {}
	for kk, vv in pairs(ev.cur or {}) do cl[#cl + 1] = string.format("**%s** +%s", (tostring(kk):gsub("_", " ")), k(vv)) end
	table.sort(cl)
	if #cl > 0 then fields[3] = { name = "Loot", value = table.concat(cl, string.char(10)), inline = false } end
	local okR, res = pcall(req, {
		Url = url, Method = "POST", Headers = { ["Content-Type"] = "application/json" },
		Body = HS:JSONEncode({
			username = "Thropus Hub",
			content = anyRare and (pingText() .. " seltener Drop!") or nil,
			allowed_mentions = { parse = { "everyone", "users" } },
			embeds = { {
				title = (anyRare and "⭐ " or "") .. tostring(ev.type) .. " · " .. tostring(ev.map) .. " · " .. tostring(ev.diff),
				description = table.concat(lines, string.char(10)),
				color = anyRare and (RCOL[best] or 0xBE4696) or 0x2B2D31,
				fields = fields,
				footer = { text = string.format("%s · %ss · +%s Gold · +%s XP · %s", LP.Name, tostring(ev.sec or "?"), k(ev.gold), k(ev.xp), os.date("%H:%M:%S")) },
			} },
		}),
	})
	pcall(PH, "WEBHOOK", tostring(ev.type) .. " " .. tostring(okR) .. " " .. tostring(type(res) == "table" and res.StatusCode or res))
end))

-- Thunder-Spear Supplies (Forest): Kisten per Beruehrung aufnehmen und am Kreis abgeben
task.spawn(function()
	while S.alive do
		task.wait(2)
		if C.AutoSpears then
			pcall(function()
				local U = workspace:FindFirstChild("Unclimbable")
				local circle = U and U:FindFirstChild("Supplies_Circle")
				local hrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
				if not circle or not hrp then return end
				for i = 1, 3 do
					local box = U:FindFirstChild("ThunderSpear_Supplies" .. i)
					if box and box:FindFirstChild("Hitbox") then
						firetouchinterest(hrp, box.Hitbox, 0) task.wait(0.4) firetouchinterest(hrp, box.Hitbox, 1)
						task.wait(1)
						firetouchinterest(hrp, circle.Hitbox, 0) task.wait(0.4) firetouchinterest(hrp, circle.Hitbox, 1)
						task.wait(1.5)
					end
				end
			end)
		end
	end
end)

-- Kanonen-Umlenkung (Colossal-Raid): Einschlag jeder eigenen Kanonenkugel direkt auf den Boss-Nacken melden
conn(POST.OnClientEvent:Connect(function(a, b, ball)
	if not C.AutoCannon or a ~= "Skills" or b ~= "Impact" or typeof(ball) ~= "Instance" or ball.Name ~= "Cannon" then return end
	local tf = workspace:FindFirstChild("Titans")
	if not tf then return end
	for _, t in ipairs(tf:GetChildren()) do if not t:IsA("Model") then continue end
		if t:GetAttribute("Shifter") then
			local hit = t:FindFirstChild("Hitboxes") and t.Hitboxes:FindFirstChild("Hit")
			local np = hit and (hit:FindFirstChild("Nape") or hit:GetChildren()[1])
			if np then
				for _ = 1, (C.CannonMulti or 1) do POST:FireServer("S_Skills", "Impact", ball, np.Position) end
				Cfg:SetAttribute("CannonHits", (Cfg:GetAttribute("CannonHits") or 0) + 1)
			end
			return
		end
	end
end))

-- Kanonier (Main-VM): eigene Kanone besetzen, dauernd feuern (Server nimmt alle ~1,4s an)
task.spawn(function()
	local CS = game:GetService("CollectionService")
	local ang
	while S.alive do
		task.wait(0.25)
		if C.AutoCannon and workspace:GetAttribute("Type") == "Raids" and workspace:FindFirstChild("Titans") then
			local boss
			for _, t in ipairs(workspace.Titans:GetChildren()) do if not t:IsA("Model") then continue end if t:GetAttribute("Shifter") then boss = t break end end
			if boss then
				-- Kanonen: getaggte + (Phase 2) Kanonen ohne Tag, die das Spiel nur "abgeschaltet" hat
				local all = {}
				for _, c in ipairs(CS:GetTagged("Cannon")) do all[#all + 1] = c end
				for _, d in ipairs(workspace:GetDescendants()) do
					if d.Name == "Cannons" then
						for _, c in ipairs(d:GetChildren()) do
							if c:IsA("Model") and c:FindFirstChild("Barrel") and not table.find(all, c) then all[#all + 1] = c end
						end
					end
				end
				local mine
				for _, c in ipairs(all) do if c:GetAttribute("Player") == LP.Name then mine = c break end end
				if not mine then
					local cands = {}
					for _, c in ipairs(all) do if c:GetAttribute("Player") == nil then cands[#cands + 1] = c end end
					table.sort(cands, function(x, y)
						local xs, ys = x:GetAttribute("Spawn") == LP.Name, y:GetAttribute("Spawn") == LP.Name
						if xs ~= ys then return xs end
						if C.CoopRole == "Player 2" then return x:GetFullName() > y:GetFullName() end
						return x:GetFullName() < y:GetFullName()
					end)
					for _, c in ipairs(cands) do
						if c:GetAttribute("Player") == nil then
							local ok, a = pcall(function() return GET:InvokeServer("Cannon", "State", c, true, nil) end)
							if ok and type(a) == "table" then mine, ang = c, a break end
						end
					end
				end
				-- (Cooldown wird bewusst ignoriert: so lief Phase 1 in 18s)
				if mine then
					local ok, r = pcall(function() return GET:InvokeServer("Cannon", "Shoot", ang or { Base = 0, BarrelWood = 0 }) end)
					if ok and r == true then Cfg:SetAttribute("CannonShots", (Cfg:GetAttribute("CannonShots") or 0) + 1) end
				end
			end
		end
	end
end)

-- Raid-Zwischensequenz haengt ("Waiting for players to load") -> Lade-Meldung selbst schicken
task.spawn(function()
	local since
	while S.alive do
		task.wait(1)
		local waiting = false
		if workspace:GetAttribute("Type") == "Raids" then
			for _, d in ipairs(LP.PlayerGui:GetDescendants()) do
				if d:IsA("TextLabel") and d.Visible and d.Text:find("Waiting for players to load") then waiting = true break end
			end
		end
		if waiting then
			since = since or os.clock()
			if os.clock() - since > 3 then
				pcall(function() POST:FireServer("Functions", "Loaded", "Add") end)
				pcall(function() GET:InvokeServer("Functions", "Loaded", "Add") end)
				Cfg:SetAttribute("FarmStatus", "Raid: Lade-Meldung gesendet")
				since = os.clock() + 5
			end
		else
			since = nil
		end
	end
end)

-- Koeder (Colossal-Raid Phase 2): ueber der Titan-Spawn-Zone schweben, damit Titanen dich statt Eren angreifen
S.spawnPts = {}
conn(RS.Heartbeat:Connect(function() end))
task.spawn(function()
	local tf
	while S.alive do
		task.wait(1)
		local t = workspace:FindFirstChild("Titans")
		if t ~= tf then
			tf = t
			S.spawnPts = {}
			if tf then
				conn(tf.ChildAdded:Connect(function(m)
					task.wait(0.3)
					if m:GetAttribute("Shifter") then return end
					local r0 = m:FindFirstChild("HumanoidRootPart") or m.PrimaryPart
					if r0 then table.insert(S.spawnPts, r0.Position) if #S.spawnPts > 40 then table.remove(S.spawnPts, 1) end end
				end))
			end
		end
	end
end)
local function colossalPct()
	for _, d in ipairs(LP.PlayerGui:GetDescendants()) do
		if d:IsA("TextLabel") and d.Name == "Percentage" and d.Visible then return tonumber((d.Text:gsub("%%", ""))) end
	end
end
conn(RS.Heartbeat:Connect(function()
	local shiftedB = LP.Character and LP.Character:GetAttribute("Shifter") ~= nil
	if shiftedB or not C.SpawnBait or workspace:GetAttribute("Type") ~= "Raids" or workspace:GetAttribute("Objective") ~= "Colossal Titan" then
		if S.baiting then S.baiting = false local h = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart") if h then h.Anchored = false end end
		return
	end
	local pc = colossalPct()
	local hrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
	if not hrp or not pc or pc > 50.05 or workspace:FindFirstChild("Chest_End") then
		if S.baiting and hrp then hrp.Anchored = false end
		S.baiting = false
		return
	end
	-- Mitte der zuletzt gesehenen Spawns (Fallback: bekannte Zone Shiganshina)
	local sx, sz, n = 0, 0, 0
	for _, v in ipairs(S.spawnPts) do sx, sz, n = sx + v.X, sz + v.Z, n + 1 end
	local cx, cz = -1800, 450
	if n >= 3 then cx, cz = sx / n, sz / n end
	local cannonWeld = hrp:FindFirstChild("Cannon")
	if cannonWeld then pcall(function() cannonWeld:Destroy() end) end
	S.baiting = true
	hrp.Anchored = true
	hrp.CFrame = CFrame.new(cx, 18 + (C.BaitHeight or 90), cz)
end))

-- Diagnose Colossal-Raid (0,1s): eigene HP, Positionsspruenge (Spiel-Teleport), Tod mit Abstaenden, Balken
task.spawn(function()
	local lastHP, lastPos, lastPct, lastCan
	while S.alive do
		task.wait(0.1)
		if workspace:GetAttribute("Objective") == "Colossal Titan" then
			local ch = LP.Character
			local hum = ch and ch:FindFirstChildOfClass("Humanoid")
			local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
			if hum and hrp then
				local hp = math.floor(hum.Health * 10) / 10
				if hp ~= lastHP then
					local info = ""
					if hp <= 0 then
						local bd, td = -1, math.huge
						for _, t in ipairs(workspace:FindFirstChild("Titans") and workspace.Titans:GetChildren() or {}) do
							if t:IsA("Model") then
								local r = t:FindFirstChild("HumanoidRootPart") or t.PrimaryPart
								if r then
									local d = (r.Position - hrp.Position).Magnitude
									if t:GetAttribute("Shifter") then bd = d elseif d < td then td = d end
								end
							end
						end
						info = string.format(" TOT bei (%.0f,%.0f,%.0f) Boss %.0f naechster Titan %.0f anchored=%s", hrp.Position.X, hrp.Position.Y, hrp.Position.Z, bd, td, tostring(hrp.Anchored))
					end
					PH("ME_HP", tostring(hp) .. info)
					lastHP = hp
				end
				if lastPos and (hrp.Position - lastPos).Magnitude > 100 then
					PH("ME_JUMP", string.format("%.0f studs -> (%.0f,%.0f,%.0f)", (hrp.Position - lastPos).Magnitude, hrp.Position.X, hrp.Position.Y, hrp.Position.Z))
				end
				lastPos = hrp.Position
			end
			local pc = colossalPct()
			local can = #game:GetService("CollectionService"):GetTagged("Cannon")
			if pc ~= lastPct or can ~= lastCan then PH("COL_BAR", tostring(pc) .. " kanonen=" .. can) lastPct, lastCan = pc, can end
		end
	end
end)

-- Diagnose Waves: HQ-Leben, Boss da?, naechster Titan am HQ (nur bei Aenderung)
task.spawn(function()
	local last
	while S.alive do
		task.wait(0.5)
		if workspace:GetAttribute("Type") == "Waves" then
			pcall(function()
				local h = workspace.Unclimbable.Objective.Waves:FindFirstChild("Health")
				local mx = h and tonumber(h:GetAttribute("Max_Health")) or 0
				local pct = (h and mx > 0) and math.floor(h.Value / mx * 100) or -1
				local npc = workspace.Waves.NPCs:FindFirstChild("Cole")
				local hq = npc and npc:GetPivot().Position
				local boss, nd, n = false, math.huge, 0
				for _, t in ipairs(workspace.Titans:GetChildren()) do
					if t:IsA("Model") then
						n = n + 1
						if t:GetAttribute("Shifter") then boss = true end
						local r = t:FindFirstChild("HumanoidRootPart") or t.PrimaryPart
						if r and hq then nd = math.min(nd, (r.Position - hq).Magnitude) end
					end
				end
				-- eigenes Leben mitloggen (Runde scheiterte bei HQ 100% -> vermutlich Tod)
				local hum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
				local me = hum and math.floor(hum.Health / math.max(hum.MaxHealth, 1) * 100) or -1
				local key = pct .. "|" .. tostring(boss) .. "|" .. n .. "|" .. me
				if key ~= last then
					last = key
					PH("HQ", string.format("%d%% Boss=%s Titanen=%d naechster am HQ %s Ich %d%%", pct, tostring(boss), n, nd < math.huge and math.floor(nd) or "-", me))
				end
			end)
		end
	end
end)

-- Waves: immer verankert hoch ueber dem HQ parken (User 18.10.: "nie sterben") - Aura/Refill brauchen keine Naehe.
-- Nur fuer Haendlerbesuche (SkillTP) loslassen; versetzt das Spiel einen (Wellenstart), sofort zurueck
S.waveHeld = nil
task.spawn(function()
	while S.alive do
		task.wait(0.1)
		local hrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
		local on = C.WaveSafe ~= false and hrp and workspace:GetAttribute("Type") == "Waves"
			and LP.Character:GetAttribute("Shifter") == nil and workspace:GetAttribute("Force_End") ~= true
			and workspace:FindFirstChild("Waves") and workspace.Waves:FindFirstChild("NPCs")
		local visiting = Cfg:GetAttribute("SkillTP") == true
		if on and not visiting then
			if not S.waveHeld then
				local cole = workspace.Waves.NPCs:FindFirstChild("Cole")
				local base = cole and cole:GetPivot().Position or hrp.Position
				local rp = RaycastParams.new()
				rp.FilterType = Enum.RaycastFilterType.Exclude
				rp.FilterDescendantsInstances = { LP.Character, workspace:FindFirstChild("Titans") }
				local hit = workspace:Raycast(base + Vector3.new(0, 50, 0), Vector3.new(0, -2000, 0), rp)
				local gy = hit and hit.Position.Y or base.Y
				S.waveHeld = CFrame.new(base.X, gy + (C.WaveSafeHeight or 350), base.Z)
				PH("WAVE_SAFE", string.format("an (%.0f,%.0f,%.0f)", S.waveHeld.X, S.waveHeld.Y, S.waveHeld.Z))
			end
			if (hrp.Position - S.waveHeld.Position).Magnitude > 3 then hrp.CFrame = S.waveHeld end
			hrp.AssemblyLinearVelocity = Vector3.zero
			hrp.Anchored = true
		elseif hrp and S.waveHeld then
			-- Besuch/Ende: loslassen (verankert repliziert die Position nicht -> Haendler wuerde ablehnen)
			hrp.Anchored = false
			if not on then S.waveHeld = nil PH("WAVE_SAFE", "aus") end
		end
	end
end)
conn(RS.Heartbeat:Connect(function()
	if not S.waveHeld or Cfg:GetAttribute("SkillTP") == true then return end
	local h = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
	if h and h.Anchored and (h.Position - S.waveHeld.Position).Magnitude > 3 then
		h.CFrame = S.waveHeld
		h.AssemblyLinearVelocity = Vector3.zero
	end
end))

-- Colossal-Raid Phase 2: senkrecht in die Luft (Hoehe ueber Boden einstellbar) und dort verankert halten
-- -> ausser Reichweite der Titanen; Aura/Refill brauchen keine Naehe
task.spawn(function()
	local CS = game:GetService("CollectionService")
	local held
	while S.alive do
		task.wait(0.1) -- schnell genug fuer den 50%-Moment
		local hrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
		local active = C.SafeSpot and hrp and workspace:GetAttribute("Type") == "Raids"
			and workspace:GetAttribute("Objective") == "Colossal Titan"
			-- frueh: schon ab Boss-Balken <= 50% (Ende Kanonen-Phase), nicht erst wenn die Kanonen weg sind
			and (#CS:GetTagged("Cannon") == 0 or (colossalPct() or 100) <= 50.5)
			and not (LP.Character:GetAttribute("Shifter") ~= nil) and workspace:FindFirstChild("Titans")
			and not workspace:FindFirstChild("Chest_End") and workspace:GetAttribute("Force_End") ~= true
		local boss = false
		if active then for _, t in ipairs(workspace.Titans:GetChildren()) do if t:IsA("Model") and t:GetAttribute("Shifter") then boss = true break end end end
		-- einmal oben: gelockt bis Raid-Ende (beim Phasenwechsel ist der Boss kurz weg -> sonst losgelassen, Sturz)
		local raidOver = not (hrp and workspace:GetAttribute("Type") == "Raids" and workspace:GetAttribute("Objective") == "Colossal Titan")
			or workspace:FindFirstChild("Chest_End") ~= nil or workspace:GetAttribute("Force_End") == true or not C.SafeSpot
		-- nicht auf den Boss warten: beim Phasenwechsel ist der Colossal ~13s weg (gemessen), das Spiel versetzt dich 3x
		if active or (held and not raidOver) then
			if not held then
				-- senkrecht nach oben ueber der aktuellen Stelle (Boden per Raycast), dort verankern
				local rp = RaycastParams.new()
				rp.FilterType = Enum.RaycastFilterType.Exclude
				rp.FilterDescendantsInstances = { LP.Character, workspace:FindFirstChild("Titans") }
				local hit = workspace:Raycast(hrp.Position + Vector3.new(0, 50, 0), Vector3.new(0, -2000, 0), rp)
				local gy = hit and hit.Position.Y or hrp.Position.Y
				held = CFrame.new(hrp.Position.X, gy + (C.SafeSpotDist or 250), hrp.Position.Z)
				PH("SAFE_SPOT", string.format("an (%.0f,%.0f,%.0f) Boden %.0f HP %.0f", held.X, held.Y, held.Z, gy, LP.Character.Humanoid.Health))
			end
			hrp.CFrame = held
			hrp.AssemblyLinearVelocity = Vector3.zero
			hrp.Anchored = true
			-- versetzt das Spiel den Charakter (Phasenwechsel), sofort zurueck statt erst nach 0,5s
			if not S.safeConn then
				S.safeConn = conn(RS.Heartbeat:Connect(function()
					local h = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
					if S.safeHeld and h and (h.Position - S.safeHeld.Position).Magnitude > 5 then
						h.CFrame = S.safeHeld
						h.AssemblyLinearVelocity = Vector3.zero
						h.Anchored = true
					end
				end))
			end
			S.safeHeld = held
		elseif held then
			hrp = hrp or (LP.Character and LP.Character:FindFirstChild("HumanoidRootPart"))
			S.safeHeld = nil
			if hrp then hrp.Anchored = false end
			PH("SAFE_SPOT", "aus")
			held = nil
		end
	end
end)

-- Lobby-Watchdog: Auto-Farm an, aber nach 40s in der Lobby noch keine Mission gestartet -> anstossen
task.spawn(function()
	local t0, kicks = os.clock(), 0
	while S.alive do
		task.wait(5)
		if C.AutoStart and game.PlaceId == 14916516914 and not workspace:FindFirstChild("Titans") then
			local st = tostring(Cfg:GetAttribute("FarmStatus") or "")
			if os.clock() - t0 > 40 + kicks * 40 and not st:find("Starte") then
				kicks = kicks + 1
				Cfg:SetAttribute("FarmStatus", "Lobby-Watchdog: starte Farm (" .. kicks .. ")")
				Cfg:SetAttribute("FarmReq", os.clock())
			end
		end
	end
end)

-- Rundenende-Watchdog: haengt die Runde fertig rum (Seconds steht still, keine Titanen), Retry erneut
-- senden; nach 3 Fehlversuchen per TeleportService in die Lobby (Auto-Farm laeuft dort weiter)
task.spawn(function()
	local lastSec, since, tries = nil, nil, 0
	while S.alive do
		task.wait(5)
		Cfg:SetAttribute("WDBeat", os.time())
		if C.AutoFarm and workspace:FindFirstChild("Titans") then
			local sec = workspace:GetAttribute("Seconds")
			local idle = workspace:GetAttribute("Rewarded") == true or #workspace.Titans:GetChildren() == 0
			if sec ~= nil and sec == lastSec and idle then
				since = since or os.clock()
				if os.clock() - since > 45 then
					tries = tries + 1
					since = os.clock()
					if tries <= 3 then
						Cfg:SetAttribute("FarmStatus", "Watchdog: Retry erneut (" .. tries .. "/3)")
						pcall(function() GET:InvokeServer("Functions", "Retry", "Add") end)
					else
						Cfg:SetAttribute("FarmStatus", "Watchdog: Retry klemmt -> Lobby")
						lobbyTP()
						tries = 0
					end
				end
			else
				since, tries = nil, 0
			end
			lastSec = sec
		else
			lastSec, since, tries = nil, nil, 0
		end
	end
end)

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
	for _, t in ipairs(tf:GetChildren()) do if not t:IsA("Model") then continue end
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

-- Nachtmodus: 3D-Rendering aus (GPU fast idle), FPS-Cap, stumm, niedrigste Grafik. Aura/Remotes laufen
-- unabhaengig vom Rendering; wird nach jedem Teleport neu gesetzt, weil der Hub per Autoexec neu laedt.
local lowPowerOn = false
local savedVolume
local function applyLowPower()
	if C.LowPower then
		pcall(function() RS:Set3dRenderingEnabled(false) end)
		pcall(function() if setfpscap then setfpscap(C.LowPowerFPS) end end)
		pcall(function()
			local gs = UserSettings():GetService("UserGameSettings")
			if not lowPowerOn then savedVolume = gs.MasterVolume end
			gs.MasterVolume = 0
		end)
		pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Level01 end)
		lowPowerOn = true
	elseif lowPowerOn then
		pcall(function() RS:Set3dRenderingEnabled(true) end)
		pcall(function() if setfpscap then setfpscap(0) end end)
		pcall(function() if savedVolume then UserSettings():GetService("UserGameSettings").MasterVolume = savedVolume end end)
		pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Automatic end)
		lowPowerOn = false
	end
end
S.applyLowPower = applyLowPower
task.defer(applyLowPower)
-- Teleport mit 3D aus hing/crashte (Starscape 08.10.) -> beim Teleport-Start Rendering an;
-- nach dem Laden setzt der neu geladene Hub den Nachtmodus wieder
conn(LP.OnTeleport:Connect(function(st)
	if C.LowPower and (st == Enum.TeleportState.Started or st == Enum.TeleportState.InProgress) then
		pcall(function() RS:Set3dRenderingEnabled(true) end)
	end
end))

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
	-- Thropus-Strand: Grund dunkles Lagunen-Teal, Akzent Korall (Abendhimmel), Text Sand-Creme
	bg = Color3.fromRGB(10, 34, 42), panel = Color3.fromRGB(14, 46, 56), panel2 = Color3.fromRGB(20, 62, 74),
	stroke = Color3.fromRGB(38, 92, 104), edge = Color3.fromRGB(64, 132, 142), track = Color3.fromRGB(30, 74, 86),
	off = Color3.fromRGB(26, 66, 78), accent = Color3.fromRGB(255, 152, 112), text = Color3.fromRGB(250, 243, 226),
	dim = Color3.fromRGB(176, 206, 204), font = Enum.Font.GothamMedium, bold = Enum.Font.GothamBold, ts = 13,
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
-- Thropus-Hintergrund: Bild liegt im Repo (games/aot/thropus_bg.jpg), wird einmal nach workspace geladen.
-- Fehlt es (kein Netz), bleibt der dunkle Standard. Lesbarkeit: dunkle Schicht ueber dem Bild + halbtransparente Sektionen
S.hasBg = false
pcall(function()
	if not (isfile and getcustomasset) then return end
	if not isfile("thropus_bg.jpg") then
		local base = (getgenv and getgenv().RAFFIR_BASE) or "https://raw.githubusercontent.com/Raffir2/scripthub/main/"
		local ok, data = pcall(game.HttpGet, game, base .. "games/aot/thropus_bg.jpg")
		if ok and type(data) == "string" and #data > 1000 then writefile("thropus_bg.jpg", data) end
	end
	if not isfile("thropus_bg.jpg") then return end
	local bg = Instance.new("ImageLabel")
	bg.Name = "ThropusBG"; bg.Size = UDim2.fromScale(1, 1); bg.BackgroundTransparency = 1; bg.BorderSizePixel = 0
	bg.Image = getcustomasset("thropus_bg.jpg"); bg.ScaleType = Enum.ScaleType.Crop; bg.ZIndex = -2; bg.Parent = main
	corner(bg, 8)
	local shade = Instance.new("Frame")
	shade.Name = "ThropusShade"; shade.Size = UDim2.fromScale(1, 1); shade.BackgroundColor3 = Color3.fromRGB(8, 30, 38)
	shade.BackgroundTransparency = 0.68; shade.BorderSizePixel = 0; shade.ZIndex = -1; shade.Parent = main
	corner(shade, 8)
	S.hasBg = true
end)

local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 30); titleBar.BackgroundTransparency = 1; titleBar.Active = true; titleBar.Parent = main
local statusL, farmHdr
do
	local tl2 = Instance.new("UIListLayout", titleBar); tl2.FillDirection = Enum.FillDirection.Horizontal
	tl2.VerticalAlignment = Enum.VerticalAlignment.Center; tl2.Padding = UDim.new(0, 8); tl2.SortOrder = Enum.SortOrder.LayoutOrder
	Instance.new("UIPadding", titleBar).PaddingLeft = UDim.new(0, 12)
	local a = txt(titleBar, "Thropus Hub", UDim2.fromOffset(0, 30), T.accent); a.Font = T.bold; a.AutomaticSize = Enum.AutomaticSize.X; a.LayoutOrder = 1
	local b = txt(titleBar, "Interface", UDim2.fromOffset(0, 30), T.text); b.AutomaticSize = Enum.AutomaticSize.X; b.LayoutOrder = 2
	local c = txt(titleBar, LP.Name, UDim2.fromOffset(0, 18), T.accent); c.AutomaticSize = Enum.AutomaticSize.X; c.LayoutOrder = 3
	c.TextSize = 12; c.BackgroundColor3 = Color3.fromRGB(58, 34, 30); c.BackgroundTransparency = 0.15; corner(c, 6); stroke(c, Color3.fromRGB(150, 86, 66))
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
	if S.hasBg then f.BackgroundTransparency = 0.45 end
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

local cL, cR = tab("Combat")
local fL, fR = tab("Farm")
local lL, lR = tab("Lobby")
local vL, vR = tab("Visuals")
local xL, xR = tab("Misc")
local pL, pR = tab("Profile")

-- ===== Combat =====
local A1 = section(cL, "Kill Aura")
toggle(A1, "Kill Aura (Nape)  [K]", "KillAura")
toggle(A1, "Blade Dance aus der Ferne auf den Boss", "BossSkillFar")
toggle(A1, "Andere Boss-Skills (kurz an den Boss-Nacken)", "BossSkills")
info(A1, "Slash-Takt, Treffer und Reichweite laufen fest auf den gemessenen Bestwerten.")

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
toggle(A3, "Ausweichen vor Boss/Titanen", "BossEvade")
slider(A3, "Boss: ausweichen ab", "BossEvadeRange", 300, 2000, 50, function(v) return v .. " st" end)
slider(A3, "Boss: Abstand danach", "BossSafeDist", 600, 3000, 50, function(v) return v .. " st" end)
toggle(A3, "Auto Grab-Escape (QTE)", "AutoEscape")
toggle(A3, "Kein Fall-Ragdoll", "NoRagdoll")

-- ===== Farm (Mission/Raid) =====
local F1 = section(fL, "Auto-Farm")
toggle(F1, "Auto-Farm (Aura + Retry/Lobby-Entscheidung)", "AutoFarm", function(v)
	if v and not C.KillAura then C.KillAura = true syncCfg() for _, f in ipairs(refreshers) do pcall(f) end end
end)
dropdown(F1, "Farm-Modus", "FarmMode", { "Beste Mission", "Colossal-Raid", "Waves" })
toggle(F1, "Speed-Modus (max. Runden/h, nur Missionen)", "SpeedMode")
toggle(F1, "  · automatisch ab Aberrant", "SpeedFromAberrant")
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
button(F1, "Jetzt starten (ueber die Lobby)", function() goPick(C.FarmPick) end)
local boostL = info(F1, "")
slider(F1, "Bis Grade", "FarmMaxGrade", 2, 15, 1, function(v) return TAGS[v] or tostring(v) end)
toggle(F1, "Ohne Klingen+Refills -> Lobby", "StuckLeave")
local farmL = info(F1, "Status: -")
info(F1, "Am Ende: Retry, oder Lobby sobald das Gold fuer die naechste Schwierigkeit reicht.")

local F5 = section(fL, "Waves")
toggle(F5, "Auto-Ready + Auto-Skip", "WaveReady", function(v) C.WaveSkip = v syncCfg() end)
toggle(F5, "Schwerter upgraden (Lulu)", "WaveSwords")
toggle(F5, "HQ-Upgrades (Cole)", "WaveUpgrades")
toggle(F5, "Segen drehen + gute sperren (Roll)", "WaveBless")
toggle(F5, "Market: Perks/Artefakte kaufen (Orange)", "WaveMarket")
toggle(F5, "Gekauftes ausruesten (ohne Slot-Limit)", "WaveEquip")
toggle(F5, "Sicher ueber dem HQ parken", "WaveSafe")

local F2 = section(fL, "Modifier")
toggle(F2, "Harte Modifier (+Gold/XP)", "FarmMods")
toggle(F2, "  · Oddball (+50% Titan-Stats)", "ModOddball")
toggle(F2, "  · Time Trial (+/-15%)", "ModTimeTrial")
toggle(F2, "  · Glass Cannon (1 HP)", "ModGlass")
toggle(F2, "  · Glass Cannon auch im Colossal-Raid", "ModGlassRaid")
toggle(F2, "  · Time Trial im Colossal-Raid (Limit 3:15)", "ModTimeTrialRaid")
info(F2, "Speed: Simple, Boring, Time Trial, Fog, Injury Prone, Chronic Injuries, Glass Cannon.\nRaids: Luck-Satz ohne Oddball (Phase 1 haelt sonst nicht).")

local F3 = section(fR, "Raid")
toggle(F3, "Premium-Truhe (Emperor's Key)", "PremiumChest")
toggle(F3, "Phase 2: Eren beschuetzen", "ErenGuard")
info(F3, "Solo. Kanone, QTE, Boss-Fokus, Flares und Cutscene-Skip laufen automatisch.")

local F4 = section(fR, "Missionsende")
toggle(F4, "Auto-Truhen (nur Raids)", "AutoChest")
toggle(F4, "Auto Retry (ohne Auto-Farm)", "AutoRetry")
button(F4, "Retry jetzt", function() GET:InvokeServer("Functions", "Retry", "Add") end)
button(F4, "Zur Lobby", function() POST:FireServer("Functions", "Teleport") end)

-- ===== Movement =====
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
info(LB, "Reihenfolge XP > Gold > Luck. Immer 2h: 2h-Item, sonst 2h kaufen (13999 Gems). Kauft nie kleinere Pakete, vorhandene kleinere Items werden genutzt. Erneuert ab 60s Rest.")

local LK = section(lL, "Market: Keys + Scrolls (je 2999 Gems)")
toggle(LK, "Keys bei jedem Lobby-Besuch auffuellen", "AutoKeys")
slider(LK, "Ziel", "KeyTarget", 1, 30, 1, function(v) return v .. " Keys" end)
info(LK, "Laeuft nach Auto-Boost. Laesst Gem-Reserve + 13999 fuer einen 2h-Boost uebrig, solange Auto-Boost an ist.")
toggle(LK, "Memory Scrolls mit den restlichen Gems kaufen", "AutoScrolls")
slider(LK, "  · Scroll-Ziel", "ScrollTarget", 1, 999, 1, function(v) return v >= 999 and "unbegrenzt" or (v .. " Scrolls") end)
button(LK, "Jetzt kaufen (nur Lobby)", function() Cfg:SetAttribute("KeyReq", os.clock()) end)

local LS = section(lL, "Perks verkaufen (-> Gems)")
toggle(LS, "Erst enhancen: Futter nur in Legendaries (ausgeruestete zuerst)", "EnhancePerks")
toggle(LS, "Bei jedem Lobby-Besuch verkaufen", "SellPerks")
dropdown(LS, "Bis Seltenheit", "SellPerksUpTo", { "Common", "Rare", "Epic" })
slider(LS, "Erst ab Perks im Lager (von 2000)", "SellPerksFrom", 0, 2000, 100)
info(LS, "Common 1 · Rare 15 · Epic 50 Gems. Behaelt Ausgeruestetes + die 2 besten je Typ. Unter No Perks zaehlt nur die Anzahl ausgeruesteter Perks.")
button(LS, "Jetzt verkaufen (nur Lobby)", function() Cfg:SetAttribute("SellReq", os.clock()) end)

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

-- Codes: nur im Startplatz (Titelbildschirm) einloesbar. Liste = eingebaut + game.guide (aktive Tabelle),
-- Ergebnisse in aot_codes.json. Server: [SUCCESSFUL]/[USED]/[EXPIRED]/[INVALID]/[ERROR] (Level/Prestige zu niedrig)
local START_ID = 13379208636
local CODES_BUILTIN = {
	"LIKES1M400K", "UPDATE5SOON", "WEBSITE", "LIKES1M350K", "FREECODE7", "LIKES1M300K", "VISITS1B", "WZINS",
	"LIKES1M250K", "VISITS900M", "VISITS800M", "FREECODE6", "TERRA70K", "LAYERS100K", "FAVORITES1M", "MEMBERS1M",
	"MEMBERS900K", "UPDATE4", "VISITS600M", "VISITS700M", "LIKES1M150K", "FREECODE3", "THANKSFORSTAYINGWITHUS",
}
local CODES_FINAL = { ["[SUCCESSFUL]"] = true, ["[USED]"] = true, ["[EXPIRED]"] = true }
S.codeStatus = "-"
local function autoCodes()
	if S.coding then return end
	if game.PlaceId ~= START_ID then S.codeStatus = "Nur im Titelbildschirm (Startplatz) einloesbar" return end
	S.coding = true
	local db = {}
	pcall(function() if isfile("aot_codes.json") then db = HS:JSONDecode(readfile("aot_codes.json")) end end)
	local list, seen = {}, {}
	local function add(c)
		c = tostring(c):upper()
		if #c >= 3 and #c <= 40 and not seen[c] then seen[c] = true list[#list + 1] = c end
	end
	S.codeStatus = "Lade Code-Liste ..."
	local ok, html = pcall(game.HttpGet, game, "https://www.game.guide/roblox-codes/attack-on-titan-revolution")
	local web = 0
	if ok and type(html) == "string" then
		-- aktive: class="codes-code-text ", abgelaufene haben zusaetzlich codes-code-expired
		for cls, c in html:gmatch('<code class="([^"]*)">%s*([%w_]+)%s*</code>') do
			if cls:find("codes-code-text", 1, true) and not cls:find("expired", 1, true) then add(c) web = web + 1 end
		end
	end
	for _, c in ipairs(CODES_BUILTIN) do add(c) end
	local got, tried = {}, 0
	for i, c in ipairs(list) do
		if not S.alive then break end
		local e = db[c]
		-- [INVALID] einmal am Tag neu probieren (Code evtl. noch nicht live)
		local skip = e and (CODES_FINAL[e.r] or (e.r == "[INVALID]" and os.time() - (e.t or 0) < 86400))
		if not skip then
			S.codeStatus = string.format("%d/%d: %s", i, #list, c)
			local r, extra = inv(8, "Functions", "Redeem", c)
			tried = tried + 1
			if r ~= nil then db[c] = { r = tostring(r), t = os.time(), x = extra } end
			if r == "[SUCCESSFUL]" then got[#got + 1] = c end
			PH("CODE", c .. " " .. tostring(r))
			task.wait(0.4)
		end
	end
	pcall(writefile, "aot_codes.json", HS:JSONEncode(db))
	S.codeStatus = string.format("Fertig: %d neu eingeloest%s · %d probiert · %d bekannt (Web %d)",
		#got, #got > 0 and (" (" .. table.concat(got, ", ") .. ")") or "", tried, #list, web)
	S.coding = false
end
S.autoCodes = autoCodes

local LC = section(lR, "Codes")
toggle(LC, "Auto-Codes im Titelbildschirm", "AutoCodes")
button(LC, "Jetzt einloesen (nur Titelbildschirm)", function() task.spawn(autoCodes) end)
local codeL = info(LC, "Status: -")
info(LC, "Neue Codes von game.guide + eingebaute Liste. Bereits genutzte/abgelaufene werden gemerkt (aot_codes.json).")
if C.AutoCodes and game.PlaceId == START_ID then task.delay(2, autoCodes) end

local RC = section(lR, "Kisten oeffnen")
local crOpts = { "Alle" }
for _, k in ipairs(crateNames()) do crOpts[#crOpts + 1] = k end
dropdown(RC, "Kiste", "CrateSel", crOpts)
button(RC, "Oeffnen Start / Stop", function() task.spawn(autoCrates) end)
local crateL = info(RC, "Status: -")
info(RC, "Oeffnet alle Kisten des Typs (oder alle Typen). Log: aot_crates_log.txt. Inventar im Spiel wird danach direkt aktualisiert.")

-- ===== Visuals =====
local V1 = section(vL, "ESP")
toggle(V1, "Titan ESP (Nape + Distanz)", "ESP")
local V2 = section(vR, "Lighting")
toggle(V2, "Fullbright", "Fullbright")
toggle(V2, "Kein Nebel", "NoFog")

-- ===== Misc =====
-- Diagnose-Recorder: schreibt 60s lang alle Client->Server-Aufrufe (Send/Invoke) + Server-Schaden + Shifter-Leiste
-- nach aot_shift_rec.txt (laeuft im Charakter-Actor, aendert nichts)
local REC_CODE = [=[
local H
for _, v in ipairs(getgc(true)) do
	if type(v) == "table" and rawget(v, "Prefix") == "rbxassetid://" and type(rawget(v, "Cache")) == "table" then H = v break end
end
if not H then writefile("aot_shift_rec.txt", "kein Host gefunden") return end
local HS = game:GetService("HttpService")
local log, t0 = {}, os.clock()
local function S(v)
	local t = typeof(v)
	if t == "Instance" then return (v:GetFullName():gsub("^Workspace%.", ""))
	elseif t == "Vector3" then return string.format("V(%.0f,%.0f,%.0f)", v.X, v.Y, v.Z)
	elseif t == "CFrame" then return string.format("CF(%.0f,%.0f,%.0f)", v.X, v.Y, v.Z)
	elseif t == "table" then local ok, j = pcall(HS.JSONEncode, HS, v) return ok and j:sub(1, 120) or "{tbl}" end
	return tostring(v)
end
local function L(kind, args)
	local o = {}
	for i = 1, args.n do o[#o + 1] = S(args[i]) end
	log[#log + 1] = string.format("%.2f %s %s", os.clock() - t0, kind, table.concat(o, " | "))
end
local bS, bI = H.Send, H.Invoke
rawset(H, "Send", function(self, ...) local a = table.pack(...) pcall(L, "SEND", a) return bS(self, ...) end)
rawset(H, "Invoke", function(self, ...) local a = table.pack(...) pcall(L, "INV", a) return bI(self, ...) end)
local POST = game:GetService("ReplicatedStorage").Assets.Remotes.POST
local c = POST.OnClientEvent:Connect(function(a, b, v)
	if a == "Zones" and b == "Damage_Check" then pcall(L, "DMG", table.pack(v))
	elseif a == "Effects" and v == "Hit_Kill" then pcall(L, "KILL", table.pack()) end
end)
local lp = game.Players.LocalPlayer
local lastB
local c2 = lp:GetAttributeChangedSignal("Bar"):Connect(function()
	local b = tonumber(lp:GetAttribute("Bar"))
	if b and math.floor(b) ~= lastB then lastB = math.floor(b) pcall(L, "BAR", table.pack(lastB)) end
end)
writefile("aot_shift_rec.txt", "START")
while os.clock() - t0 < 60 do
	task.wait(1)
	pcall(writefile, "aot_shift_rec.txt", table.concat(log, string.char(10)))
end
rawset(H, "Send", bS)
rawset(H, "Invoke", bI)
c:Disconnect()
c2:Disconnect()
pcall(writefile, "aot_shift_rec.txt", table.concat(log, string.char(10)) .. string.char(10) .. "ENDE")
]=]
local W1 = section(xL, "Discord-Webhook")
toggle(W1, "Jede Runde melden (Ping nur bei selten)", "Webhook")
dropdown(W1, "Ping ab", "WebhookMin", { "Epic", "Legendary", "Mythic", "Secret" })
toggle(W1, "Nur seltene melden (ab \"Ping ab\", sonst nichts)", "WebhookRareOnly")
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
info(W1, "Ping nur nach Seltenheit (ab \"Ping ab\"). Waves- und Raid-Runden werden immer gemeldet.")
local X3 = section(xL, "Nachtmodus (PC kuehl & leise)")
toggle(X3, "3D aus, FPS-Cap, stumm, Minimalgrafik", "LowPower", function() applyLowPower() end)
slider(X3, "FPS-Cap", "LowPowerFPS", 10, 60, 5, function(v) return v .. " FPS" end)
info(X3, "Farm laeuft normal weiter (Treffer gehen ueber den Server, nicht ueber die Grafik). Bleibt nach Teleports aktiv.")
local X2 = section(xL, "Sonstiges")
toggle(X2, "Anti-AFK", "AntiAFK")
button(X2, "Actor neu injizieren", function() injectActor() end)
button(X2, "Hub beenden", function() S.Kill() end)
local infoL = info(X2, "")
info(X2, "RightShift = Menue · K = Kill Aura")
local X0 = section(xR, "Truhen-Log")
local chestL = info(X0, "-")

-- Profile: aktuelle Einstellungen unter Namen speichern/laden (je Profil eine Datei in aot_profiles/).
-- Fenster-/Laufzeit-Zustand bleibt draussen, Laden wirkt sofort (Toggles werden neu gezeichnet)
;(function()
local PROF_DIR = "aot_profiles"
-- feste Profile (im Hub eingebaut, nicht loeschbar). "Mondlicht" = Config von Mondlicht_X, Stand 19.10.
local PROF_BUILTIN = {
	["Mondlicht (fest)"] = [==[{"AntiAFK":true,"AuraRange":20000,"AutoBoost":true,"AutoBuild":true,"AutoCannon":true,"AutoCast":true,"AutoChest":true,"AutoClaim":true,"AutoCodes":true,"AutoEscape":true,"AutoFarm":true,"AutoKeys":false,"AutoPrestige":false,"AutoQTE":true,"AutoRefill":true,"AutoReload":true,"AutoRetry":false,"AutoScrolls":false,"AutoSkip":true,"AutoSpears":true,"AutoStart":false,"AutoUpgrade":true,"BaitHeight":90,"BladeSaver":false,"BonusAlways":false,"BoostGemReserve":0,"BoostGold":false,"BoostLuck":true,"BoostType":"XP","BoostXP":false,"BossEvade":true,"BossEvadeRange":900,"BossFocus":true,"BossSafeDist":1300,"BossSkillFar":true,"BossSkills":true,"CannonMulti":100,"ControlPct":0,"CoopRole":"Solo","CrateGap":0.15,"CrateSel":"Alle","Dashes":0,"ESP":false,"EnhancePerks":true,"ErenGuard":true,"ErenGuardRange":300,"EvadeRange":400,"Family":"Keine","FarmMaxGrade":15,"FarmMission":"Shiganshina \u00b7 Colossal Titan","FarmMods":false,"FarmPick":"Fest","FillHits":true,"Fullbright":true,"GasPct":0,"GearUncap":true,"GoldReserve":0,"GoldSink":true,"HitCD":0.15,"InfBlades":true,"InfGas":true,"InfRange":true,"Interval":0.1,"KeyTarget":15,"KillAura":true,"LowPower":false,"LowPowerFPS":30,"MaxHits":16,"ModGlass":false,"ModGlassRaid":false,"ModOddball":false,"ModTimeTrial":false,"ModTimeTrialRaid":true,"NapeOnly":true,"NoFog":true,"NoRagdoll":false,"PerCycle":10,"PremiumChest":true,"PrestigeBoost":"Luck","RangePct":0,"ReloadAt":5,"RollDeposit":true,"RollGap":0.55,"RollStartTier":"Epic","RollStop_Common":false,"RollStop_Epic":true,"RollStop_Legendary":true,"RollStop_Mythic":true,"RollStop_Rare":true,"RollStop_Secret":true,"SafeSpot":false,"SafeSpotDist":725,"ScrollTarget":999,"SelfDefRange":120,"SellPerks":true,"SellPerksFrom":1500,"SellPerksUpTo":"Rare","SmartAura":true,"SmartGap":1.2,"SpawnBait":false,"SpeedFromAberrant":true,"SpeedMode":true,"SpeedPct":0,"StuckLeave":true,"UpgTarget":15,"WaveBless":true,"WaveEquip":true,"WaveMarket":true,"WaveReady":true,"WaveSafe":true,"WaveSafeHeight":350,"WaveSkip":true,"WaveSwordGold":1500,"WaveSwords":true,"WaveUpgrades":true,"Webhook":true,"WebhookMin":"Mythic","WebhookRareOnly":true}]==],
}
local PROF_SKIP = { UIX = true, UIY = true, Tab = true, Collapsed = true, UIVisible = true, PresetVersion = true,
	AuraToggleFix = true, BoostSafety = true, ProfileName = true }
local function profName(s)
	s = tostring(s or ""):gsub("[^%w%s%-_]", ""):gsub("^%s+", ""):gsub("%s+$", "")
	return s:sub(1, 24)
end
local function profList()
	local out = {}
	pcall(function()
		if not isfolder(PROF_DIR) then return end
		for _, p in ipairs(listfiles(PROF_DIR)) do
			local n = tostring(p):gsub("\\", "/"):match("([^/]+)%.json$")
			if n then out[#out + 1] = n end
		end
	end)
	table.sort(out, function(a, b) return a:lower() < b:lower() end)
	local fixed = {}
	for n in pairs(PROF_BUILTIN) do fixed[#fixed + 1] = n end
	fixed[#fixed + 1] = "Raffir (fest)"
	table.sort(fixed)
	for i = #fixed, 1, -1 do table.insert(out, 1, fixed[i]) end
	return out
end
local function profSave(name)
	name = profName(name)
	if name == "" then error("Name fehlt", 0) end
	if PROF_BUILTIN[name] or name == "Raffir (fest)" then error("festes Profil, anderen Namen nehmen", 0) end
	if not isfolder(PROF_DIR) then makefolder(PROF_DIR) end
	local t = {}
	for k, v in pairs(C) do if not PROF_SKIP[k] then t[k] = v end end
	writefile(PROF_DIR .. "/" .. name .. ".json", HS:JSONEncode(t))
	C.ProfileName = name
	saveCfg()
	return name
end
local function profLoad(name)
	local n = 0
	if name == "Raffir (fest)" then
		applyPreset()
		C.FarmMode = modeFrom(C.FarmPick, C.FarmMission)
		C.ProfileName = name
		syncCfg()
		for _, f in ipairs(refreshers) do pcall(f) end
		return 1
	end
	local t = HS:JSONDecode(PROF_BUILTIN[name] or readfile(PROF_DIR .. "/" .. name .. ".json"))
	for k, v in pairs(t) do
		if not PROF_SKIP[k] and C[k] ~= nil and type(C[k]) == type(v) then C[k] = v n = n + 1 end
	end
	-- alte Profile ohne FarmMode: aus Missionswahl ableiten
	if t.FarmMode == nil then C.FarmMode = modeFrom(C.FarmPick, C.FarmMission) end
	C.ProfileName = name
	syncCfg()
	for _, f in ipairs(refreshers) do pcall(f) end
	pcall(applyLowPower)
	Cfg:SetAttribute("FarmStatus", "Profil geladen: " .. name)
	return n
end
S.profSave, S.profLoad, S.profList = profSave, profLoad, profList

local P1 = section(pL, "Profil speichern")
local profPending = ""
local profStatus
textbox(P1, "Name", "z. B. Raid, Waves, Missionen", function() return profPending end, function(v) profPending = profName(v) return profPending ~= "" and "bereit zum Speichern" or "Name fehlt" end)
local profRebuild
button(P1, "Aktuelle Einstellungen speichern", function()
	local ok, r = pcall(profSave, profPending ~= "" and profPending or C.ProfileName)
	profStatus.Text = ok and ("Gespeichert: " .. r) or ("Fehler: " .. tostring(r))
	profRebuild()
end)
profStatus = info(P1, "")
info(P1, "Gleicher Name = ueberschreiben. Fenster-Position und Tab werden nicht gespeichert.")

local P2 = section(pR, "Gespeicherte Profile")
local profActive = info(P2, "")
local profBox = Instance.new("Frame")
profBox.BackgroundTransparency = 1; profBox.Size = UDim2.new(1, 0, 0, 0); profBox.AutomaticSize = Enum.AutomaticSize.Y
profBox.LayoutOrder = nextOrder(P2); profBox.Parent = P2.f
local pbl = Instance.new("UIListLayout", profBox); pbl.Padding = UDim.new(0, 6); pbl.SortOrder = Enum.SortOrder.LayoutOrder
local function profBtn(parent, label, w, x, fn)
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(w, -4, 1, 0); b.Position = UDim2.new(x, x > 0 and 4 or 0, 0, 0)
	b.BackgroundColor3 = T.panel2; b.BorderSizePixel = 0; b.AutoButtonColor = false
	b.Font = T.font; b.TextSize = 12; b.TextColor3 = T.text; b.Text = label; b.TextTruncate = Enum.TextTruncate.AtEnd
	b.Parent = parent
	stroke(b); corner(b, 6)
	b.MouseButton1Click:Connect(function() task.spawn(fn) end)
	b.MouseEnter:Connect(function() b.TextColor3 = T.accent end)
	b.MouseLeave:Connect(function() b.TextColor3 = T.text end)
	return b
end
profRebuild = function()
	for _, c in ipairs(profBox:GetChildren()) do if c:IsA("Frame") then c:Destroy() end end
	local list = profList()
	profActive.Text = "Aktiv: " .. ((C.ProfileName or "") ~= "" and C.ProfileName or "-") .. " · " .. #list .. " gespeichert"
	for i, name in ipairs(list) do
		local row = Instance.new("Frame")
		row.BackgroundTransparency = 1; row.Size = UDim2.new(1, 0, 0, 26); row.LayoutOrder = i; row.Parent = profBox
		local lb = profBtn(row, (name == C.ProfileName and "● " or "") .. "Laden: " .. name, 0.62, 0, function()
			local ok, r = pcall(profLoad, name)
			profActive.Text = ok and ("Geladen: " .. name .. " (" .. r .. " Werte)") or ("Fehler: " .. tostring(r))
			task.wait(1.5) profRebuild()
		end)
		if name == C.ProfileName then lb.TextColor3 = T.accent end
		if PROF_BUILTIN[name] or name == "Raffir (fest)" then lb.Size = UDim2.new(1, 0, 1, 0) continue end
		local armed = false
		local db
		db = profBtn(row, "Loeschen", 0.38, 0.62, function()
			-- zweiter Klick bestaetigt (kein versehentliches Loeschen)
			if not armed then armed = true db.Text = "Sicher?" task.delay(3, function() armed = false if db.Parent then db.Text = "Loeschen" end end) return end
			pcall(delfile, PROF_DIR .. "/" .. name .. ".json")
			if C.ProfileName == name then C.ProfileName = "" saveCfg() end
			profRebuild()
		end)
	end
end
profRebuild()

	-- Loadouts (Skills/Perks/Artefakte/Waffe), Ausfuehrung im Actor
	local LO_DIR = "aot_loadouts"
	local function loList()
		local out = {}
		pcall(function()
			if not isfolder(LO_DIR) then return end
			for _, pth in ipairs(listfiles(LO_DIR)) do
				local n = tostring(pth):gsub("\\", "/"):match("([^/]+)%.json$")
				if n then out[#out + 1] = n end
			end
		end)
		table.sort(out, function(a, b) return a:lower() < b:lower() end)
		return out
	end
	local function loReq(op, name) Cfg:SetAttribute("LoadoutReq", op .. "|" .. name .. "|" .. tostring(os.clock())) end
	S.loReq, S.loList = loReq, loList
	local P3 = section(pL, "Loadout speichern")
	local loPending = ""
	textbox(P3, "Name", "z. B. Raid, Waves", function() return loPending end, function(v) loPending = profName(v) return loPending ~= "" and "bereit zum Speichern" or "Name fehlt" end)
	local loRebuild
	button(P3, "Ausgeruestetes speichern (nur Lobby)", function()
		if loPending == "" then Cfg:SetAttribute("LoadoutStatus", "Name fehlt") return end
		loReq("save", loPending)
		task.wait(1) loRebuild()
	end)
	info(P3, "Speichert Waffe, Perks je Slot (genau diese Kopie), Artefakte und Skill-Hotbar 1-5.")
	local P4 = section(pR, "Gespeicherte Loadouts")
	local loState = info(P4, "")
	conn(Cfg:GetAttributeChangedSignal("LoadoutStatus"):Connect(function() loState.Text = tostring(Cfg:GetAttribute("LoadoutStatus")) end))
	local loBox = Instance.new("Frame")
	loBox.BackgroundTransparency = 1; loBox.Size = UDim2.new(1, 0, 0, 0); loBox.AutomaticSize = Enum.AutomaticSize.Y
	loBox.LayoutOrder = nextOrder(P4); loBox.Parent = P4.f
	local lbl = Instance.new("UIListLayout", loBox); lbl.Padding = UDim.new(0, 6); lbl.SortOrder = Enum.SortOrder.LayoutOrder
	loRebuild = function()
		for _, c in ipairs(loBox:GetChildren()) do if c:IsA("Frame") then c:Destroy() end end
		for i, name in ipairs(loList()) do
			local row = Instance.new("Frame")
			row.BackgroundTransparency = 1; row.Size = UDim2.new(1, 0, 0, 26); row.LayoutOrder = i; row.Parent = loBox
			profBtn(row, "Ausruesten: " .. name, 0.62, 0, function() loReq("load", name) end)
			local armed, db = false, nil
			db = profBtn(row, "Loeschen", 0.38, 0.62, function()
				if not armed then armed = true db.Text = "Sicher?" task.delay(3, function() armed = false if db.Parent then db.Text = "Loeschen" end end) return end
				pcall(delfile, LO_DIR .. "/" .. name .. ".json")
				loRebuild()
			end)
		end
		if #loList() == 0 then loState.Text = "Noch keine Loadouts gespeichert." end
	end
	loRebuild()
end)()

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
			boostL.Text = "Diese Mission: " .. (workspace:GetAttribute("Boosted") and "<b>Bonus aktiv</b>" or "kein Bonus") .. ""
		else
			boostL.Text = "Bonus-Map wird in der Lobby angezeigt."
		end
		chestL.Text = "Truhen: " .. tostring(Cfg:GetAttribute("ChestCount") or 0) .. " · " .. tostring(Cfg:GetAttribute("ChestLog") or "-"):gsub(" || ", "\n")
		rollL.Text = (S.rolling and "<font color=\"#ff9870\">ROLLT</font> · " or "") .. tostring(S.rollStatus)
		codeL.Text = (S.coding and "<font color=\"#ff9870\">LOEST EIN</font> · " or "") .. tostring(S.codeStatus)
		crateL.Text = (Cfg:GetAttribute("Crating") and "<font color=\"#ff9870\">OEFFNET</font> · " or "") .. tostring(Cfg:GetAttribute("CrateStatus") or "-")
		local etaShort, etaLong = prestigeETA()
		presL.Text = etaLong or "Prestige-ETA: -"
		local fg, fn = Cfg:GetAttribute("FarmGold"), Cfg:GetAttribute("FarmNeed")
		farmHdr.Visible = C.AutoFarm and fg ~= nil
		if farmHdr.Visible then
			local function k(n) n = tonumber(n) or 0 if n >= 1e6 then return string.format("%.2fM", n / 1e6) elseif n >= 1e3 then return string.format("%.1fk", n / 1e3) end return tostring(math.floor(n)) end
			local nx = Cfg:GetAttribute("FarmNext") or "?"
			if nx == "MAX" then
				farmHdr.Text = '<font color="#ffd97a">Gold ' .. k(fg) .. '</font> · MAX · Lv ' .. tostring(LP:GetAttribute("Level") or "?") .. (etaShort and (' · <font color="#ff9870">' .. etaShort .. '</font>') or '')
			else
				local col = fg >= fn and "#7fff50" or "#ffd97a"
				farmHdr.Text = '<font color="' .. col .. '">Gold ' .. k(fg) .. ' / ' .. k(fn) .. '</font> → ' .. nx .. ' · Lv ' .. tostring(LP:GetAttribute("Level") or "?") .. (etaShort and (' · <font color="#ff9870">' .. etaShort .. '</font>') or '')
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

return "Thropus Hub geladen"
