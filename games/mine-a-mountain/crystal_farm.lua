-- === Crystal Farm: Häppchen-Anflug + Yank-Schutz + Anziehung (Executor / Potassium) ===
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local RS = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local guiParent = (gethui and gethui()) or game:GetService("CoreGui")

-- === Grafik auf Minimum: weniger GPU/Textur/Streaming-Druck -> gegen Roblox-Crashes beim Server-Hoppen ===
pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Level01 end)
pcall(function() sethiddenproperty(settings().Rendering, "QualityLevel", 1) end)
pcall(function() UserSettings():GetService("UserGameSettings").SavedQualityLevel = Enum.SavedQualitySetting.QualityLevel1 end)
pcall(function() game:GetService("Lighting").GlobalShadows=false end)
pcall(function() game:GetService("Lighting").Brightness=1 end)
pcall(function() local t=settings().Rendering; t.EnableFRM=false end)

-- === Schaden / Fall-Schaden / Ragdoll aus ===
local NO_DAMAGE = true
local getcons = getconnections or get_signal_cons or (getgenv and getgenv().getconnections)
local function killCons(sig)
	if not getcons then return end
	pcall(function() for _,c in ipairs(getcons(sig)) do pcall(function() if c.Disable then c:Disable() elseif c.Disconnect then c:Disconnect() end end) end end)
end
local _actRag    = RS:FindFirstChild("ActivateRagdollRemote", true)
local _collapse  = RS:FindFirstChild("CollapseRagdollRemote", true)
local _deactRag  = RS:FindFirstChild("DeactivateRagdollRemote", true)
local _fallDmg   = RS:FindFirstChild("FallDamage", true)
local _freezeDmg = RS:FindFirstChild("FreezeDamage", true)
-- Client-Reaktionen auf Ragdoll/Fall/Freeze-Schaden abklemmen (dann passiert's gar nicht erst)
local function killGameReactions()
	if not NO_DAMAGE then return end
	if _actRag then killCons(_actRag.OnClientEvent) end
	if _collapse then killCons(_collapse.OnClientEvent) end
	if _fallDmg then killCons(_fallDmg.OnClientEvent) end
	if _freezeDmg then killCons(_freezeDmg.OnClientEvent) end
end
-- KERN-FIX: Ragdoll-Klasse patchen -> physische Aktivierung = no-op -> Char ragdollt NIE (egal welcher Trigger)
pcall(function()
	if not NO_DAMAGE then return end
	local rm=RS:FindFirstChild("RagdollSystemPackage")
	rm=rm and rm:FindFirstChild("RagdollSystem"); rm=rm and rm:FindFirstChild("RagdollFactory"); rm=rm and rm:FindFirstChild("Ragdoll")
	if rm then
		local cls=require(rm)
		if type(cls)=="table" then
			local noop=function() end
			cls.activateRagdollPhysics=noop
			cls.activateRagdollPhysicsLowDetail=noop
			cls._activateRagdollPhysics=noop
		end
	end
end)
-- Gamepass-Besitz imitieren (LocalPlayer.GamepassesOwned.<Name> = true)
pcall(function()
	if not NO_DAMAGE then return end
	local go=player:FindFirstChild("GamepassesOwned")
	if go then for _,v in ipairs(go:GetChildren()) do if v:IsA("BoolValue") then pcall(function() v.Value=true end) end end end
end)
-- Brute-Force: jeden Frame prüfen ob Ragdolled und SOFORT aufrichten (wirkt egal wie's getriggert wird)
task.spawn(function()
	while NO_DAMAGE do
		local char=player.Character
		if char and char:GetAttribute("Ragdolled") then
			pcall(function() char:SetAttribute("Ragdolled", false) end)
			pcall(function() if _deactRag then _deactRag:FireServer() end end)
			local hum=char:FindFirstChildWhichIsA("Humanoid")
			if hum then pcall(function() hum.PlatformStand=false end); pcall(function() hum:ChangeState(Enum.HumanoidStateType.GettingUp) end) end
			for _,d in ipairs(char:GetDescendants()) do
				if d:IsA("BallSocketConstraint") then pcall(function() d.Enabled=false end)
				elseif d:IsA("Motor6D") then pcall(function() d.Enabled=true end) end
			end
		end
		task.wait()
	end
end)
-- Fall-Velocity clampen: kein harter Aufprall -> Server registriert keinen Sturz -> kein Fall-Schaden/Kristall-Drop
local FALL_CLAMP = -65   -- max. Fallgeschwindigkeit (Studs/s)
task.spawn(function()
	while NO_DAMAGE do
		local c=player.Character
		local hrp=c and c:FindFirstChild("HumanoidRootPart")
		if hrp then
			local v=hrp.AssemblyLinearVelocity
			if v.Y < FALL_CLAMP then pcall(function() hrp.AssemblyLinearVelocity=Vector3.new(v.X, FALL_CLAMP, v.Z) end) end
		end
		task.wait()
	end
end)
local function protectChar(char)
	if not NO_DAMAGE then return end
	task.spawn(function()
		local hum=char:FindFirstChildWhichIsA("Humanoid") or char:WaitForChild("Humanoid",5)
		if not hum then return end
		pcall(function() hum.BreakJointsOnDeath=false end)
		-- Health voll halten (Signal + Backup-Loop)
		hum:GetPropertyChangedSignal("Health"):Connect(function() if hum.Health<hum.MaxHealth then pcall(function() hum.Health=hum.MaxHealth end) end end)
		task.spawn(function() while hum.Parent and NO_DAMAGE do if hum.Health<hum.MaxHealth then pcall(function() hum.Health=hum.MaxHealth end) end task.wait(0.3) end end)
		-- reaktiv: sobald Ragdolled=true -> sofort deaktivieren
		pcall(function() char:GetAttributeChangedSignal("Ragdolled"):Connect(function()
			if char:GetAttribute("Ragdolled") then
				pcall(function() if _deactRag then _deactRag:FireServer() end end)
				pcall(function() char:SetAttribute("Ragdolled", false) end)
				pcall(function() hum.PlatformStand=false end)
			end
		end) end)
		task.wait(1); killGameReactions()   -- Listener sind evtl. per-Char neu -> nochmal abklemmen
	end)
end
task.spawn(function() task.wait(1.5); killGameReactions() end)
pcall(function() if player.Character then protectChar(player.Character) end end)
player.CharacterAdded:Connect(protectChar)

-- === Persistente Settings (überleben Re-Execute) — key=value pro Zeile in cf_settings.txt ===
local SETTINGS_FILE="cf_settings.txt"
local function settingGet(key, default)
	local val=default
	pcall(function()
		if isfile and readfile and isfile(SETTINGS_FILE) then
			for line in readfile(SETTINGS_FILE):gmatch("[^\r\n]+") do
				local k,v=line:match("^(%w+)=(.*)$"); if k==key then val=v end
			end
		end
	end)
	return val
end
local function settingSet(key, value)
	pcall(function()
		if not (writefile and readfile) then return end
		local out={}; local found=false
		if isfile and isfile(SETTINGS_FILE) then
			for line in readfile(SETTINGS_FILE):gmatch("[^\r\n]+") do
				local k=line:match("^(%w+)=")
				if k==key then out[#out+1]=key.."="..tostring(value); found=true else out[#out+1]=line end
			end
		end
		if not found then out[#out+1]=key.."="..tostring(value) end
		writefile(SETTINGS_FILE, table.concat(out,"\n"))
	end)
end
local function tiersFromStr(s) local t={}; local i=1; for v in tostring(s):gmatch("[^,]+") do if v=="1" then t[i]=true end; i+=1 end; return t end
local function tiersToStr(t) local o={}; for n=1,6 do o[n]=t[n] and "1" or "0" end; return table.concat(o,",") end

-- === Konfig ===
local cfg = { tiers = tiersFromStr(settingGet("tiers","1,1,1,1,1,1")) }
local STEP = tonumber(settingGet("step","14")) or 14
local STEP_WAIT = 0.02
local WALL_JUMP = 12
local MAX_BIGJUMPS = 6
local GLIDE_YANK = 15
local MAX_YANKS = 6
local YANK_CHILL = 1.6
local PACE_STEPS = 28
local PACE_CHILL = 0.8
local CHUNK = 95
local APPROACH_HEIGHT = 45
local FIRE_INTERVAL = 0.25
local MAX_FIRES = 80
local GROUND_WAIT = 1.8
local CLOSE = 9
local APPROACH_RUBBER = 35
local FIRE_RUBBER = 45
local PULL_THRESH = 3
local PULL_SPEED = 110
local COOLDOWN = 2.0
local MAX_ATTEMPTS = 120         -- viele Anflug-Versuche (große Kristalle nicht zu früh aufgeben)
local MAX_CRYSTAL_TIME = 250     -- aber max. so viele Sekunden GESAMT pro Kristall -> sonst Blacklist (kein Hängenbleiben)
local MAX_RECENTER = 3
local PEAK_FRAC = 0.07
local CENTER_LOAD = 0.8
local RECENTER_Z = -355   -- Versatz beim Zentrieren in Z (negativ = weg vom Spawn, weiter in die Bergmitte/Peak)
local REST_INTERVAL = 12
local REST_TIME = 2.5
local AUTO_REJOIN = true   -- nach dem Sweep automatisch den Private Server (re)joinen
local MAX_SERVER_TIME = tonumber(settingGet("srvtime","300")) or 300 -- Watchdog: nach so vielen Sekunden HART hoppen; per Slider einstellbar, persistent
local SCOUT_RADIUS = tonumber(settingGet("radius","650")) or 650 -- halber Scan-Bereich um den Gipfel = Abstand der äußeren Etappen-Punkte; per Slider, persistent
local SHARE_LINKS = {      -- Rejoin ALTERNIERT zwischen diesen Servern (der andere resettet derweil)
	"202201b0f75e484f8c2c405cc43b6c49",
	"a40807dc6d5cb846a33c0e0c5ed4322f",
}
local SERVER_IDX_FILE = "farm_server_idx.txt"  -- merkt sich über Rejoins, welcher Server als nächstes dran ist
local RAY_CEIL = 6000      -- Strahl-Starthöhe ÜBER dem Gipfel (Anti-Untergrund)
local RAY_LEN  = 12000     -- max. Strahllänge nach unten
local XZ_NOPROG = 6        -- so viele Iterationen ohne Fortschritt -> Zelle abbrechen

-- === Ordner + Remote ===
local crystalsFolder
for i = 1, 20 do
	crystalsFolder = Workspace:FindFirstChild("Crystals", true)
	if crystalsFolder then break end
	task.wait(0.5)
end
local pickupRemote = crystalsFolder and RS:FindFirstChild("CrystalHoldComplete", true)

-- === Luck-Filter (nutzt das Spiel-Modul CrystalLuck.crystalLuck(Tier,WeightKg)) ===
local CrystalLuck
-- non-blocking laden: falls require() im Modul hängt, blockiert es NICHT das ganze Skript
task.spawn(function() pcall(function() local m=RS:FindFirstChild("CrystalLuck", true); if m then CrystalLuck=require(m) end end) end)
local function crystalLuckOf(o)
	if not CrystalLuck then return 0 end
	local cf = CrystalLuck.crystalLuck or CrystalLuck.CrystalLuck
	if not cf then return 0 end
	local ok,v = pcall(cf, o:GetAttribute("Tier"), o:GetAttribute("WeightKg") or 0)
	return (ok and type(v)=="number") and v or 0
end
-- Spiel-Luck-% eines Kristalls (genau die Zahl die du im Spiel überm Kristall siehst)
local function crystalLuckPct(o)
	local raw = crystalLuckOf(o)
	if CrystalLuck and CrystalLuck.formatLuckPercent then
		local ok,s = pcall(CrystalLuck.formatLuckPercent, raw)
		if ok and type(s)=="string" then local n=tonumber((s:gsub("[^%d%.]",""))); if n then return n end end
	end
	return raw*100   -- Fallback
end
local LUCK_X10 = tonumber(settingGet("luck","50")) or 50   -- Mindest-Luck in Zehntel-% (50 = 5.0%); persistent

-- === Auto-Place: gefilterte Kristalle direkt in den eigenen Plot legen (KEIN Hook) ===
local AUTO_PLACE = (settingGet("place","1")=="1")
local PLACE_INSET = 0.10    -- Rand-Anteil, den wir von der Fence-Innenkante einrücken (klein = nutzt fast den ganzen Plot)
local PLACE_STEP = 5        -- Rasterabstand der Platzier-Kandidaten (dicht = findet auch kleine Lücken)
local PLACE_TRIES = 70      -- max. Kandidaten-Positionen pro Tool (deckt vollen Plot ab)
local placeRemote = RS:FindFirstChild("PlotPlaceRequest", true)

-- === Auto-Sell: wertvolle (aber nicht Luck-würdige) Kristalle mitsammeln + verkaufen ===
local SELL_ENABLED = (settingGet("sell","1")=="1")                      -- persistent
local SELL_MIN_VALUE = tonumber(settingGet("sellmin","5000000")) or 5000000   -- Sell-Schwelle (Value), persistent
local sellRemote = RS:FindFirstChild("SellRequest", true)

-- === Charakter ===
local function getRoot() local c=player.Character; return c and c:FindFirstChild("HumanoidRootPart") end
local function getHum() local c=player.Character; return c and c:FindFirstChildWhichIsA("Humanoid") end
local function isTarget(o)
	if not o:IsA("BasePart") then return false end
	local t=o:GetAttribute("Tier")
	if t==nil or cfg.tiers[t]~=true then return false end
	-- Luck-Filter nur wenn Modul geladen (sonst NICHT alles wegfiltern)
	if LUCK_X10>0 and CrystalLuck and crystalLuckPct(o) < LUCK_X10/10 then return false end
	return true
end
-- Sell-Ziel: wertvoll (>SELL_MIN_VALUE) aber NICHT Luck-würdig (sonst käme es in den Plot)
local function isSellTarget(o)
	if not (SELL_ENABLED and o:IsA("BasePart")) then return false end
	local t=o:GetAttribute("Tier")
	if t==nil or cfg.tiers[t]~=true then return false end
	if isTarget(o) then return false end                 -- ≥5% Luck -> Plot, nicht verkaufen
	return (o:GetAttribute("Value") or 0) > SELL_MIN_VALUE
end
-- Killer-Spots: wo der Char beim Minen WIEDERHOLT resettet wurde -> erst nach 3x überspringen (überlebt Respawn, reset bei Rejoin)
local killerSpots={}
local respawnCount={}  -- "x,z" (gerundet) -> Anzahl Resets an dem Spot
local mineNowPos=nil   -- Position des aktuell geminten Kristalls (für Reset-Erkennung)
local function spotKey(p) return math.floor(p.X/10)..","..math.floor(p.Z/10) end
local function nearKiller(p) for _,k in ipairs(killerSpots) do if (k-p).Magnitude<15 then return true end end return false end
-- alles was wir einsammeln: Luck-Ziele ODER Sell-Ziele (aber keine tödlichen Spots)
local function isCollectable(o) return (isTarget(o) or isSellTarget(o)) and not nearKiller(o.Position) end
local function fixCollision()
	local c=player.Character; if not c then return end
	for _,p in ipairs(c:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide=true end end
end
fixCollision()

local function holdStill(secs)
	local r=getRoot(); if not r then return end
	local pos=r.Position
	local t=os.clock()
	while os.clock()-t<secs do
		r=getRoot(); if r then r.CFrame=CFrame.new(pos); r.AssemblyLinearVelocity=Vector3.zero end
		task.wait(0.1)
	end
end

local function pullToward(cpos)
	local root=getRoot(); if not root then return end
	local off=cpos-root.Position
	local horiz=Vector3.new(off.X,0,off.Z)
	if horiz.Magnitude>0.1 then
		local v=root.AssemblyLinearVelocity
		local pull=horiz.Unit*math.min(horiz.Magnitude*6, PULL_SPEED)
		root.AssemblyLinearVelocity=Vector3.new(pull.X, v.Y, pull.Z)
	end
end

-- === Box (Fallback) ===
local boxFolder
local function destroyBox() if boxFolder then boxFolder:Destroy(); boxFolder=nil end end
local function buildBox(pos)
	destroyBox()
	boxFolder=Instance.new("Folder"); boxFolder.Name="FarmBox"; boxFolder.Parent=Workspace
	local function wall(s,p) local w=Instance.new("Part"); w.Anchored=true;w.CanCollide=true;w.Transparency=1;w.Size=s;w.CFrame=CFrame.new(p);w.Parent=boxFolder end
	wall(Vector3.new(10,1,10),pos-Vector3.new(0,2.5,0)); wall(Vector3.new(10,1,10),pos+Vector3.new(0,5,0))
	wall(Vector3.new(1,9,10),pos+Vector3.new(-5,1,0)); wall(Vector3.new(1,9,10),pos+Vector3.new(5,1,0))
	wall(Vector3.new(10,9,1),pos+Vector3.new(0,1,-5)); wall(Vector3.new(10,9,1),pos+Vector3.new(0,1,5))
end

-- Boden berühren: runter auf echtes Terrain, Position beim Server validieren -> kein Yank
local function touchGround()
	local root,hum=getRoot(),getHum()
	if not root or not hum then return false end
	local params=RaycastParams.new()
	params.FilterType=Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances={player.Character, boxFolder}
	local origin=root.Position
	local res=Workspace:Raycast(origin+Vector3.new(0,5,0), Vector3.new(0,-200,0), params)
	-- nur runtersnappen wenn Boden NAH ist (sonst landet man unter der Map -> Spawn-Teleport)
	if res and (origin.Y - res.Position.Y) < 90 then
		root.CFrame=CFrame.new(res.Position+Vector3.new(0,3,0)); root.AssemblyLinearVelocity=Vector3.zero
	end
	local t=os.clock()
	while os.clock()-t<1.2 do
		if hum.FloorMaterial~=Enum.Material.Air then return true end
		task.wait(0.05)
	end
	return hum.FloorMaterial~=Enum.Material.Air
end

-- === GUI + Log ===
local PINK=Color3.fromRGB(255,80,180)
local GOLD=Color3.fromRGB(255,200,60)
local gui=Instance.new("ScreenGui"); gui.Name="T5Farm"; gui.ResetOnSpawn=false; gui.Parent=guiParent
local panel=Instance.new("Frame"); panel.Size=UDim2.new(0,340,0,580)
panel.Position=UDim2.new(0,tonumber(settingGet("posx","30")) or 30, 0, tonumber(settingGet("posy","70")) or 70)
panel.BackgroundColor3=Color3.fromRGB(18,18,22); panel.BorderSizePixel=0; panel.Active=true; panel.Parent=gui
Instance.new("UICorner",panel).CornerRadius=UDim.new(0,8)
local header=Instance.new("TextLabel"); header.Size=UDim2.new(1,0,0,34); header.BackgroundColor3=Color3.fromRGB(30,30,38)
header.BorderSizePixel=0; header.Font=Enum.Font.GothamBold; header.TextSize=15; header.TextColor3=PINK
header.Text="💎 Crystal Farm"; header.Parent=panel
Instance.new("UICorner",header).CornerRadius=UDim.new(0,8)
do local dr,ds,sp
	header.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then dr=true;ds=i.Position;sp=panel.Position end end)
	UserInputService.InputChanged:Connect(function(i) if dr and i.UserInputType==Enum.UserInputType.MouseMovement then local d=i.Position-ds; panel.Position=UDim2.new(sp.X.Scale,sp.X.Offset+d.X,sp.Y.Scale,sp.Y.Offset+d.Y) end end)
	UserInputService.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then if dr then settingSet("posx", math.floor(panel.Position.X.Offset)); settingSet("posy", math.floor(panel.Position.Y.Offset)) end; dr=false end end)
end
local running=false
local btn=Instance.new("TextButton"); btn.Size=UDim2.new(1,-24,0,38); btn.Position=UDim2.new(0,12,0,42)
btn.Font=Enum.Font.GothamBold; btn.TextSize=16; btn.TextColor3=Color3.fromRGB(255,255,255); btn.BorderSizePixel=0; btn.Parent=panel
Instance.new("UICorner",btn).CornerRadius=UDim.new(0,6)
local function refreshBtn() btn.BackgroundColor3=running and PINK or Color3.fromRGB(55,55,62); btn.Text=running and "LÄUFT (klick=stop)" or "FARM STARTEN" end

local tierLbl=Instance.new("TextLabel"); tierLbl.BackgroundTransparency=1; tierLbl.Size=UDim2.new(1,-24,0,16); tierLbl.Position=UDim2.new(0,12,0,86)
tierLbl.Font=Enum.Font.GothamBold; tierLbl.TextSize=12; tierLbl.TextColor3=Color3.fromRGB(235,235,240); tierLbl.TextXAlignment=Enum.TextXAlignment.Left
tierLbl.Text="Sammeln (anklicken):"; tierLbl.Parent=panel
do
	-- Plot-Toggle
	local apBtn=Instance.new("TextButton",panel); apBtn.Size=UDim2.new(0,74,0,18); apBtn.Position=UDim2.new(1,-160,0,85)
	apBtn.Font=Enum.Font.GothamBold; apBtn.TextSize=11; apBtn.TextColor3=Color3.fromRGB(255,255,255); apBtn.BorderSizePixel=0
	Instance.new("UICorner",apBtn).CornerRadius=UDim.new(0,5)
	local function apRf() apBtn.BackgroundColor3=AUTO_PLACE and PINK or Color3.fromRGB(50,50,57); apBtn.Text=AUTO_PLACE and "Plot: AN" or "Plot: AUS" end
	apBtn.MouseButton1Click:Connect(function() AUTO_PLACE=not AUTO_PLACE; settingSet("place", AUTO_PLACE and "1" or "0"); apRf() end)
	apRf()
	-- Sell-Toggle (persistent über Re-Executes)
	local slBtn=Instance.new("TextButton",panel); slBtn.Size=UDim2.new(0,74,0,18); slBtn.Position=UDim2.new(1,-80,0,85)
	slBtn.Font=Enum.Font.GothamBold; slBtn.TextSize=11; slBtn.TextColor3=Color3.fromRGB(255,255,255); slBtn.BorderSizePixel=0
	Instance.new("UICorner",slBtn).CornerRadius=UDim.new(0,5)
	local function slRf() slBtn.BackgroundColor3=SELL_ENABLED and GOLD or Color3.fromRGB(50,50,57); slBtn.TextColor3=SELL_ENABLED and Color3.fromRGB(20,20,20) or Color3.fromRGB(255,255,255); slBtn.Text=SELL_ENABLED and "💰 Sell: AN" or "💰 Sell: AUS" end
	slBtn.MouseButton1Click:Connect(function() SELL_ENABLED=not SELL_ENABLED; settingSet("sell", SELL_ENABLED and "1" or "0"); slRf() end)
	slRf()
end
for n=1,6 do
	local b=Instance.new("TextButton")
	b.Size=UDim2.new(0,48,0,28); b.Position=UDim2.new(0,12+(n-1)*50,0,106)
	b.Font=Enum.Font.GothamBold; b.TextSize=14; b.TextColor3=Color3.fromRGB(255,255,255); b.BorderSizePixel=0; b.Parent=panel
	Instance.new("UICorner",b).CornerRadius=UDim.new(0,5)
	local function rf() b.BackgroundColor3=cfg.tiers[n] and PINK or Color3.fromRGB(50,50,57); b.Text="T"..n end
	b.MouseButton1Click:Connect(function() cfg.tiers[n]=not cfg.tiers[n] or nil; settingSet("tiers", tiersToStr(cfg.tiers)); rf() end)
	rf()
end

local function makeSlider(y,t,mn,mx,fmt,get,set,disp,color)
	local h=Instance.new("Frame",panel); h.BackgroundTransparency=1; h.Size=UDim2.new(1,-24,0,40); h.Position=UDim2.new(0,12,0,y)
	local lbl=Instance.new("TextLabel",h); lbl.BackgroundTransparency=1; lbl.Size=UDim2.new(1,0,0,16); lbl.Font=Enum.Font.GothamBold; lbl.TextSize=12; lbl.TextColor3=Color3.fromRGB(235,235,240); lbl.TextXAlignment=Enum.TextXAlignment.Left
	local tr=Instance.new("Frame",h); tr.Position=UDim2.new(0,0,0,22); tr.Size=UDim2.new(1,0,0,10); tr.BackgroundColor3=Color3.fromRGB(45,45,52); tr.BorderSizePixel=0
	Instance.new("UICorner",tr).CornerRadius=UDim.new(1,0)
	local fl=Instance.new("Frame",tr); fl.BackgroundColor3=color or PINK; fl.BorderSizePixel=0; Instance.new("UICorner",fl).CornerRadius=UDim.new(1,0)
	local function rf() fl.Size=UDim2.new(math.clamp((get()-mn)/(mx-mn),0,1),0,1,0); lbl.Text=string.format("%s: "..fmt,t,(disp and disp(get()) or get())) end
	local dg=false; local function sx(px) local r=math.clamp((px-tr.AbsolutePosition.X)/tr.AbsoluteSize.X,0,1); set(math.floor(mn+(mx-mn)*r+0.5)); rf() end
	tr.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then dg=true;sx(i.Position.X) end end)
	UserInputService.InputChanged:Connect(function(i) if dg and i.UserInputType==Enum.UserInputType.MouseMovement then sx(i.Position.X) end end)
	UserInputService.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then dg=false end end)
	rf()
end
makeSlider(146,"Schrittweite",4,80,"%d",function() return STEP end,function(v) STEP=v; settingSet("step",v) end)
makeSlider(190,"Min-Luck",0,100,"%.1f%%",function() return LUCK_X10 end,function(v) LUCK_X10=v; settingSet("luck",v) end,function(v) return v/10 end)
makeSlider(234,"💰 Geld (Sell ab)",0,50,"%d Mio",function() return math.floor(SELL_MIN_VALUE/1000000) end,function(v) SELL_MIN_VALUE=v*1000000; settingSet("sellmin",SELL_MIN_VALUE) end,nil,GOLD)
makeSlider(278,"⏱️ Server-Hop nach",60,900,"%ds",function() return MAX_SERVER_TIME end,function(v) MAX_SERVER_TIME=v; settingSet("srvtime",v) end,nil,Color3.fromRGB(90,180,255))
makeSlider(322,"📡 Scan-Radius",200,1500,"%d",function() return SCOUT_RADIUS end,function(v) SCOUT_RADIUS=v; settingSet("radius",v) end,nil,Color3.fromRGB(150,120,255))

local stat=Instance.new("TextLabel"); stat.Size=UDim2.new(1,-24,0,34); stat.Position=UDim2.new(0,12,0,368)
stat.BackgroundColor3=Color3.fromRGB(10,10,12); stat.BorderSizePixel=0; stat.Font=Enum.Font.GothamBold; stat.TextSize=13; stat.TextColor3=PINK
stat.TextXAlignment=Enum.TextXAlignment.Left; stat.Text="Bereit."; stat.Parent=panel; Instance.new("UICorner",stat).CornerRadius=UDim.new(0,6)
local logBox=Instance.new("TextBox"); logBox.Size=UDim2.new(1,-24,1,-418); logBox.Position=UDim2.new(0,12,0,410)
logBox.BackgroundColor3=Color3.fromRGB(8,8,10); logBox.BorderSizePixel=0; logBox.TextColor3=Color3.fromRGB(0,255,120)
logBox.Font=Enum.Font.Code; logBox.TextSize=11; logBox.TextXAlignment=Enum.TextXAlignment.Left; logBox.TextYAlignment=Enum.TextYAlignment.Top
logBox.TextWrapped=true; logBox.MultiLine=true; logBox.ClearTextOnFocus=false; logBox.TextEditable=false; logBox.Text=""; logBox.Parent=panel
Instance.new("UICorner",logBox).CornerRadius=UDim.new(0,6)
if rconsolename then pcall(rconsolename,"Crystal Farm") end
if rconsoleclear then pcall(rconsoleclear) end
local lines={}
local function log(s) if rconsoleprint then pcall(rconsoleprint,s.."\n") end table.insert(lines,s); while #lines>28 do table.remove(lines,1) end logBox.Text=table.concat(lines,"\n"); print("[T]"..s) end

-- Disk-Log (überlebt Teleport/Reload, wird NICHT gelöscht) — für Rejoin-Diagnose
local REJOIN_LOG="farm_rejoin_log.txt"
local function dlog(s)
	pcall(function()
		if not (writefile and readfile) then return end
		local prev=""
		pcall(function() if (not isfile) or isfile(REJOIN_LOG) then prev=readfile(REJOIN_LOG) end end)
		local stamp=(os.date and os.date("%H:%M:%S")) or tostring(os.clock())
		writefile(REJOIN_LOG, prev..stamp.." | "..s.."\n")
	end)
end
dlog("START JobId="..tostring(game.JobId).." PlaceId="..tostring(game.PlaceId))

-- === Crash-Log: Breadcrumbs + Fehler-Traceback (für Post-Mortem nach Crash) ===
local CRASH_LOG="crash_log.txt"
local function clog(s)
	pcall(function()
		if not (writefile and readfile) then return end
		local prev=""
		pcall(function() if (not isfile) or isfile(CRASH_LOG) then prev=readfile(CRASH_LOG) end end)
		local stamp=(os.date and os.date("%H:%M:%S")) or tostring(math.floor(os.clock()))
		local all=prev..stamp.." | "..tostring(s).."\n"
		-- auf letzte ~160 Zeilen kürzen, damit die Datei nicht unbegrenzt wächst
		local lines={}; for line in all:gmatch("[^\n]+") do lines[#lines+1]=line end
		if #lines>160 then local t={}; for i=#lines-159,#lines do t[#t+1]=lines[i] end; all=table.concat(t,"\n").."\n" end
		writefile(CRASH_LOG, all)
	end)
end
clog("=== EXECUTE/JOIN JobId="..tostring(game.JobId).." ===")

-- Scout-Disk-Log (persistent, überlebt Hops) — damit ich die Diagnose auch bei autoexec auslesen kann
local SCOUT_LOG="scout_log.txt"
local function scoutLog(s)
	pcall(function()
		if not (writefile and readfile) then return end
		local prev=""
		pcall(function() if (not isfile) or isfile(SCOUT_LOG) then prev=readfile(SCOUT_LOG) end end)
		local stamp=(os.date and os.date("%H:%M:%S")) or tostring(os.clock())
		writefile(SCOUT_LOG, prev..stamp.." | "..s.."\n")
	end)
end

-- Ziel-Disk-Log: hält fest WIE jeder ≥Min-Luck-Kristall ausging (zum Debuggen von Fehlschlägen)
local TARGET_LOG="target_log.txt"
local function tlog(s)
	pcall(function()
		if not (writefile and readfile) then return end
		local prev=""
		pcall(function() if (not isfile) or isfile(TARGET_LOG) then prev=readfile(TARGET_LOG) end end)
		local stamp=(os.date and os.date("%H:%M:%S")) or tostring(os.clock())
		writefile(TARGET_LOG, prev..stamp.." | "..s.."\n")
	end)
end

if not crystalsFolder or not pickupRemote then stat.Text="FEHLER: Ordner/Remote fehlt!"; stat.TextColor3=Color3.fromRGB(255,80,80); refreshBtn(); return end

-- === Glide mit Wand-Sprung + YANK-Schutz + Pacing ===
local function glideTo(dest)
	local root=getRoot(); if not root then return false end
	local lastDist=math.huge; local stuck,bigJumps=0,0
	local prevSet=root.Position; local steps,yanks=0,0
	for _=1,4000 do
		if not running then return false end
		local cur=root.Position
		if (cur-prevSet).Magnitude>GLIDE_YANK then
			yanks+=1
			log(string.format("  ! Yank set=%.0f,%.0f,%.0f now=%.0f,%.0f,%.0f d=%.0f",
				prevSet.X,prevSet.Y,prevSet.Z, cur.X,cur.Y,cur.Z, (cur-prevSet).Magnitude))
			holdStill(YANK_CHILL)
			touchGround()
			if yanks>=MAX_YANKS then return false end
			local r=getRoot(); cur=r and r.Position or cur; prevSet=cur; lastDist=math.huge
		end
		local d=dest-cur; local dist=d.Magnitude
		if dist<=STEP then root.CFrame=CFrame.new(dest); root.AssemblyLinearVelocity=Vector3.zero; return true end
		if dist<lastDist-0.4 then stuck=0; bigJumps=0 else stuck+=1 end
		lastDist=dist
		local stepSize=STEP
		if stuck>=3 then stepSize=WALL_JUMP; stuck=0; bigJumps+=1; if bigJumps>=MAX_BIGJUMPS then return false end end
		local newPos=cur+d.Unit*stepSize
		root.CFrame=CFrame.new(newPos); root.AssemblyLinearVelocity=Vector3.zero
		prevSet=newPos; steps+=1
		if steps%PACE_STEPS==0 then holdStill(PACE_CHILL); local r=getRoot(); prevSet=r and r.Position or newPos end
		task.wait(STEP_WAIT)
	end
	return false
end

local function approach(cpos)
	local root=getRoot(); if not root then return false end
	local arrived=glideTo(cpos+Vector3.new(0,4,0))
	if not arrived or (root.Position-cpos).Magnitude>15 then
		glideTo(Vector3.new(cpos.X, cpos.Y+APPROACH_HEIGHT, cpos.Z))
		glideTo(cpos+Vector3.new(0,4,0))
	end
	return (root.Position-cpos).Magnitude <= 30
end

-- === Auto-Positionierung (Häppchen-Anflug mit Streaming) ===
local function peakCenter()
	local sx,sz,n=0,0,0; local mnY,mxY=math.huge,-math.huge
	for _,o in ipairs(crystalsFolder:GetDescendants()) do
		if o:IsA("BasePart") and o:GetAttribute("Tier")~=nil then
			sx+=o.Position.X; sz+=o.Position.Z; n+=1
			if o.Position.Y<mnY then mnY=o.Position.Y end
			if o.Position.Y>mxY then mxY=o.Position.Y end
		end
	end
	if n==0 then return nil end
	return Vector3.new(sx/n, mxY-PEAK_FRAC*(mxY-mnY), sz/n)
end

local function countLoaded()
	local n=0
	for _,o in ipairs(crystalsFolder:GetDescendants()) do
		if o:IsA("BasePart") and o:GetAttribute("Tier")~=nil then n+=1 end
	end
	return n
end

-- höchster geladener Kristall (zur Strahl-Starthöhe)
local function peakYEstimate()
	local mxY=-math.huge
	for _,o in ipairs(crystalsFolder:GetDescendants()) do
		if o:IsA("BasePart") and o:GetAttribute("Tier")~=nil and o.Position.Y>mxY then mxY=o.Position.Y end
	end
	return mxY
end

-- Oberkante an X,Z von WEIT OBEN finden (findet die echte Oberfläche, auch wenn man drunter steckt)
local function surfaceYat(x, z)
	local params=RaycastParams.new()
	params.FilterType=Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances={player.Character, boxFolder}
	local root=getRoot()
	local peak=peakYEstimate()
	local startY=math.max(peak+RAY_CEIL, (root and root.Position.Y or 0)+RAY_CEIL, RAY_CEIL)
	local res=Workspace:Raycast(Vector3.new(x, startY, z), Vector3.new(0,-RAY_LEN,0), params)
	return res and res.Position.Y or nil
end

-- setzt den Char zuverlässig AUF die Oberkante (auch nach OBEN, falls man drunter steckt)
local function snapToSurface()
	local root=getRoot(); if not root then return nil end
	local p=root.Position
	local sy=surfaceYat(p.X, p.Z)
	if sy then
		root.CFrame=CFrame.new(p.X, sy+3, p.Z); root.AssemblyLinearVelocity=Vector3.zero
	end
	return sy
end

-- chunked Oberflächen-Bewegung zu beliebigem X,Z (folgt dem Terrain, Anti-Untergrund)
local function glideToXZ(tx, tz)
	local lastHd=math.huge; local noProg=0
	for _=1,120 do
		if not running then return false end
		local root=getRoot(); if not root then return false end
		local cur=root.Position
		local horiz=Vector3.new(tx-cur.X, 0, tz-cur.Z)
		local hd=horiz.Magnitude
		-- Fortschritts-Wächter: kein horizontaler Fortschritt -> Zelle abbrechen statt loopen
		if hd < lastHd-2 then noProg=0 else noProg+=1 end
		lastHd=hd
		if noProg>=XZ_NOPROG then
			log(string.format("  ! glideToXZ kein Fortschritt (hd=%.0f) -> Zelle abgebrochen", hd))
			snapToSurface(); return false
		end
		local lastStep = hd<CHUNK
		local goalH = lastStep and Vector3.new(tx, cur.Y, tz) or (cur+horiz.Unit*CHUNK)
		pcall(function() player:RequestStreamingAround(Vector3.new(goalH.X, cur.Y, goalH.Z)) end)
		task.wait(0.2)
		local sy = surfaceYat(goalH.X, goalH.Z)
		if sy then
			glideTo(Vector3.new(goalH.X, sy+3, goalH.Z))   -- immer ÜBER die Oberkante
		else
			-- keine Oberfläche -> NICHT in den Berg gleiten; hochziehen
			log(string.format("  ! keine Oberfläche bei %.0f,%.0f -> hochziehen", goalH.X, goalH.Z))
			if not snapToSurface() then
				root.CFrame=CFrame.new(cur.X, cur.Y+60, cur.Z); root.AssemblyLinearVelocity=Vector3.zero
			end
		end
		-- Sicherung: falls trotzdem unter der Oberkante -> hoch auf die Oberkante
		local r=getRoot()
		if r then
			local sNow=surfaceYat(r.Position.X, r.Position.Z)
			if sNow and r.Position.Y < sNow-2 then
				r.CFrame=CFrame.new(r.Position.X, sNow+3, r.Position.Z); r.AssemblyLinearVelocity=Vector3.zero
			end
		end
		touchGround()
		if lastStep then break end
	end
	return true
end

local function recenter()
	local c=peakCenter()
	if not c then log("  -> kein Center (0 Kristalle geladen)"); return false end
	local root=getRoot()
	local tz=c.Z+RECENTER_Z   -- weiter in die Bergmitte (weg vom Spawn)
	log(string.format("ZENTRIEREN: pos=%s -> Center=%.0f,%.0f,%.0f (Z%+d)", root and string.format("%.0f,%.0f,%.0f",root.Position.X,root.Position.Y,root.Position.Z) or "?", c.X,c.Y,tz, RECENTER_Z))
	glideToXZ(c.X, tz)
	pcall(function() player:RequestStreamingAround(Vector3.new(c.X, c.Y, tz)) end); task.wait(CENTER_LOAD)
	return true
end

-- Berg-Grenzen (X,Z) aus den geladenen Kristallen
local function bounds()
	local mnx,mxx,mnz,mxz=math.huge,-math.huge,math.huge,-math.huge; local n=0
	for _,o in ipairs(crystalsFolder:GetDescendants()) do
		if o:IsA("BasePart") and o:GetAttribute("Tier")~=nil then
			n+=1; local p=o.Position
			mnx=math.min(mnx,p.X); mxx=math.max(mxx,p.X)
			mnz=math.min(mnz,p.Z); mxz=math.max(mxz,p.Z)
		end
	end
	if n==0 then return nil end
	return mnx,mxx,mnz,mxz
end

-- === Collect ===
local attempts={}
local crystalTime=setmetatable({},{__mode="k"})    -- kumulierte Zeit (s) pro Kristall (Failsafe gegen Hängenbleiben)
local deadCrystals=setmetatable({},{__mode="k"})   -- endgültig aufgegeben (unsammelbar) — überlebt attempts-Reset
local function collect(crystal)
	local root,hum=getRoot(),getHum(); if not root or not hum then return false,"kein char" end
	local cpos=crystal.Position

	if not approach(cpos) then
		if not crystal.Parent then return true,"weg während Anflug" end
		task.wait(0.4); return false, "festgehängt – übersprungen"
	end
	if not crystal.Parent then return true,"weg während Anflug" end

	-- 1) kurzes Fenster: natürlich auf echtem Boden nah am Kristall landen (Flachland)
	local closeGrounded,maxDrift=false,0
	local t0=os.clock()
	while os.clock()-t0<0.5 do
		if not crystal.Parent then break end
		local dd=(root.Position-cpos).Magnitude
		if dd>maxDrift then maxDrift=dd end
		if hum.FloorMaterial~=Enum.Material.Air and dd<CLOSE then closeGrounded=true; break end
		if dd>PULL_THRESH then pullToward(cpos) end
		task.wait(0.05)
	end

	-- 2) nicht geerdet (steile/senkrechte Klippe) -> Box drunter + EXAKT auf den Kristall snappen.
	--    Kein Drift-Abbruch mehr: die Box holt uns sowieso zurück auf cpos.
	local usedBox=false
	if not closeGrounded and crystal.Parent then
		usedBox=true
		buildBox(cpos)
		root.CFrame=CFrame.new(cpos+Vector3.new(0,1,0)); root.AssemblyLinearVelocity=Vector3.zero
		local b0=os.clock()
		while os.clock()-b0<GROUND_WAIT do
			root.AssemblyLinearVelocity=Vector3.zero      -- nicht von der Box rutschen
			if hum.FloorMaterial~=Enum.Material.Air then closeGrounded=true; break end
			task.wait(0.05)
		end
	end

	local distNow=(crystal.Parent and (cpos-root.Position).Magnitude) or 0
	local floorMat=tostring(hum.FloorMaterial):gsub("Enum.Material.","")
	-- nur abbrechen, wenn wir TROTZ Box nicht am Kristall sind
	if crystal.Parent and distNow>20 then
		if usedBox then destroyBox() end; task.wait(COOLDOWN)
		return false, string.format("zu weit weg (%.0f)", distNow)
	end

	local fireBase=usedBox and (cpos+Vector3.new(0,1,0)) or root.Position
	-- Schlag-Limit mit Gewicht skalieren: schwere Kristalle in EINEM Anflug durchziehen (kein mittendrin-Neustart)
	local fkg = crystal:GetAttribute("WeightKg") or 0
	local fireCap = math.clamp(math.ceil(fkg/2)+60, MAX_FIRES, 950)   -- Decke ~237s (1 Anflug, unter MAX_CRYSTAL_TIME)
	-- KOLLISION AUS + ANKER: große Kristall-Meshes (Giant/XL) können den Char so nicht mehr wegschleudern
	local char=player.Character
	pcall(function() for _,p in ipairs(char:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide=false end end end)
	local wasAnchored=root.Anchored
	pcall(function() root.CFrame=CFrame.new(fireBase); root.AssemblyLinearVelocity=Vector3.zero; root.Anchored=true end)
	local fired,fireDrift,fireRubber=0,0,false
	while crystal.Parent and running do
		pcall(function() pickupRemote:FireServer(crystal) end); fired+=1
		task.wait(FIRE_INTERVAL)
		local fd=(fireBase-root.Position).Magnitude
		if fd>fireDrift then fireDrift=fd end
		if fd>FIRE_RUBBER then fireRubber=true end   -- nur merken, NICHT aufgeben
		-- JEDEN Tick hart zurückpinnen (gegen Fling/Server-Teleport bei Riesen-Kristallen) -> kein Reset, Pickup klappt
		pcall(function() root.CFrame=CFrame.new(fireBase); root.AssemblyLinearVelocity=Vector3.zero; root.Anchored=true end)
		if fired>=fireCap then break end
	end
	pcall(function() root.Anchored=wasAnchored end)
	fixCollision()      -- Kollision wieder an
	if usedBox then destroyBox() end

	log(string.format("  T%s | Dist %.1f | Floor:%s | Box:%s | Schläge:%d | maxDrift %.0f%s",
		tostring(crystal:GetAttribute("Tier")), distNow, floorMat, tostring(usedBox), fired, fireDrift,
		fireRubber and "  <<RUBBERBAND>>" or ""))

	if crystal.Parent==nil then return true, "ok ("..fired.." Schläge"..(usedBox and ",Box" or "")..")"
	elseif fireRubber then return false, string.format("RUBBERBAND Feuern (%.0f)", fireDrift)
	elseif not closeGrounded then return false, "nicht nah geerdet"
	else return false, "Cap erreicht ("..fired..")" end
end

local function nearestTarget()
	local root=getRoot(); if not root then return nil end
	local best,bd=nil,math.huge
	for _,o in ipairs(crystalsFolder:GetDescendants()) do
		if isCollectable(o) and not deadCrystals[o] and (attempts[o] or 0)<MAX_ATTEMPTS then
			local d=(o.Position-root.Position).Magnitude
			if d<bd then bd,best=d,o end
		end
	end
	return best
end

local function anyTierSelected() for n=1,6 do if cfg.tiers[n] then return true end end return false end

local function chill()
	stat.Text="Chillen gegen Rubberband..."
	log("  ~ Chill "..REST_TIME.."s ~")
	holdStill(REST_TIME)
end

-- === Auto-Rejoin Private Server ===
local function httpReq(opts)
	local f = request or http_request or (http and http.request) or (syn and syn.request)
	if not f then return nil end
	local ok,res = pcall(f, opts)
	return ok and res or nil
end

local function rbxPost(url, body)
	local headers={["Content-Type"]="application/json"}
	for _=1,2 do
		local res=httpReq({Url=url, Method="POST", Headers=headers, Body=body})
		if not res then return nil end
		local code = res.StatusCode or res.Status or 0
		local tok = res.Headers and (res.Headers["x-csrf-token"] or res.Headers["X-CSRF-Token"])
		if code==403 and tok then headers["X-CSRF-TOKEN"]=tok else return res end
	end
end

-- === Server-Hop: in einen ANDEREN öffentlichen Server (garantiert nicht derselbe) ===
local function serverHop()
	stat.Text="Fertig -> Server-Hop (public)..."
	local placeId = game.PlaceId
	local current = game.JobId
	log("Hop: verlasse JobId="..tostring(current):sub(1,8))
	-- öffentliche Serverliste holen (kein Login nötig), paginiert
	local cands={}
	local cursor=""
	for page=1,6 do
		local url="https://games.roblox.com/v1/games/"..placeId.."/servers/Public?limit=100&sortOrder=Asc"
		if cursor~="" then url=url.."&cursor="..cursor end
		local res=httpReq({Url=url, Method="GET"})
		if not (res and res.Body) then log("Hop: keine HTTP-Antwort (Seite "..page..")"); break end
		local ok,data=pcall(function() return HttpService:JSONDecode(res.Body) end)
		if not (ok and type(data)=="table" and data.data) then log("Hop: JSON-Fehler: "..tostring(res.Body):sub(1,150)); break end
		for _,s in ipairs(data.data) do
			if s.id~=current and (s.playing or 0) < (s.maxPlayers or 99) then table.insert(cands, s) end
		end
		cursor = data.nextPageCursor or ""
		if cursor=="" or #cands>=60 then break end
	end
	log("Hop: "..#cands.." andere Server gefunden")
	if #cands==0 then
		log("Hop: keine Alternative -> normaler Teleport")
		pcall(function() TeleportService:Teleport(placeId, player) end)
		return
	end
	-- wenig Spieler bevorzugen (weniger Konkurrenz), dann aus den untersten zufällig mischen
	table.sort(cands, function(a,b) return (a.playing or 0) < (b.playing or 0) end)
	local order={}; local pickN=math.min(8,#cands)
	for i=1,pickN do order[i]=cands[i] end
	for i=#order,2,-1 do local j=math.random(1,i); order[i],order[j]=order[j],order[i] end
	-- Retry über mehrere Kandidaten falls ein Teleport fehlschlägt
	local attempt=0
	local function tryNext()
		attempt+=1
		if attempt>#order then
			log("Hop: alle Kandidaten fehlgeschlagen -> normaler Teleport")
			pcall(function() TeleportService:Teleport(placeId, player) end)
			return
		end
		local c=order[attempt]
		log(string.format("Hop #%d -> %s (%d/%d Spieler)", attempt, tostring(c.id):sub(1,8), c.playing or 0, c.maxPlayers or 0))
		pcall(function() TeleportService:TeleportToPlaceInstance(placeId, c.id, player) end)
	end
	TeleportService.TeleportInitFailed:Connect(function(plr, result, msg)
		if plr==player then log("Hop: Teleport-Fail ("..tostring(result).."): "..tostring(msg).." -> nächster"); task.wait(0.4); tryNext() end
	end)
	tryNext()
end

-- === Sweep ===
local SWEEP_CELL = 200     -- Rasterabstand (grob = wenige Zellen)
local SWEEP_RADIUS = 220   -- Sammel-Reichweite pro Zelle
local SWEEP_MARGIN = 100   -- über die geladenen Grenzen hinaus
local SWEEP_EXTRA_NEGZ = 1*SWEEP_CELL   -- zusätzlich Richtung kleinere Z (weg vom Spawn) absuchen

local farmDone, farmFails, farmReasons, lastRest = 0, 0, {}, 0

-- === Auto-Place Hilfsfunktionen ===
local function myPlot()
	local t=Workspace:FindFirstChild("Things"); t=t and t:FindFirstChild("Plots"); t=t and t:FindFirstChild("Slots")
	return t and t:FindFirstChild(player.Name)
end
local function plotCapacity()
	local rs=player:FindFirstChild("PlayerData"); rs=rs and rs:FindFirstChild("RealStats")
	local c=rs and rs:FindFirstChild("PlotCapacity")
	return (c and c.Value) or 50
end
local function placedFolder(plot) return plot:FindFirstChild("PlacedCrystals") end
local function placedCount(plot) local pc=placedFolder(plot); return pc and #pc:GetChildren() or 0 end
local function plotFull() local p=myPlot(); return p and (placedCount(p) >= plotCapacity()) or false end
local function placedPositions(plot)
	local out={}; local pc=placedFolder(plot)
	if pc then for _,d in ipairs(pc:GetDescendants()) do
		if d:IsA("BasePart") and d.Name=="PromptAnchor" then table.insert(out,d.Position) end
	end end
	return out
end
-- Fence-XZ-Box + unterste Y des eigenen Plots
local function plotBox(plot)
	local fence=plot:FindFirstChild("Fence") or plot
	local mnx,mxx,mnz,mxz,my=math.huge,-math.huge,math.huge,-math.huge,math.huge
	for _,d in ipairs(fence:GetDescendants()) do
		if d:IsA("BasePart") then local p=d.Position
			if p.X<mnx then mnx=p.X end; if p.X>mxx then mxx=p.X end
			if p.Z<mnz then mnz=p.Z end; if p.Z>mxz then mxz=p.Z end
			if p.Y<my then my=p.Y end
		end
	end
	if mnx==math.huge then return nil end
	return mnx,mxx,mnz,mxz,my
end
local function plotGroundY(x,z,fallback)
	local params=RaycastParams.new()
	params.FilterType=Enum.RaycastFilterType.Exclude
	-- platzierte Kristalle (ganzer Slots-Ordner) ausschließen, sonst landet der Strahl auf einem Kristall-Dach
	local slots=Workspace:FindFirstChild("Things") and Workspace.Things:FindFirstChild("Plots")
	slots=slots and slots:FindFirstChild("Slots")
	params.FilterDescendantsInstances={player.Character, boxFolder, slots}
	local res=Workspace:Raycast(Vector3.new(x,(fallback or 30)+90,z), Vector3.new(0,-400,0), params)
	local y=res and res.Position.Y or fallback
	-- durchgefallen (kein Boden / Terrain weit unten)? -> Fence-Höhe als Untergrenze
	if fallback and (not y or y<fallback-20) then y=fallback end
	return y
end
-- EIN Kristall-Tool in den Plot legen. Rückgabe: "ok",x,z | "voll" | "kein-spot" | "skip"
local function placeOneTool(plot, tool)
	if placedCount(plot) >= plotCapacity() then return "voll" end
	local tname=tool.Name
	local mnx,mxx,mnz,mxz,fy=plotBox(plot); if not mnx then return "skip" end
	local ix=(mxx-mnx)*PLACE_INSET; local iz=(mxz-mnz)*PLACE_INSET
	mnx,mxx,mnz,mxz=mnx+ix,mxx-ix,mnz+iz,mxz-iz
	-- dichtes Raster über den GANZEN Plot, gemischt -> probiert jede Lücke durch (Server lehnt belegte ab)
	local cands={}
	local x=mnx; while x<=mxx do local z=mnz; while z<=mxz do cands[#cands+1]=Vector2.new(x,z); z+=PLACE_STEP end; x+=PLACE_STEP end
	for i=#cands,2,-1 do local j=math.random(i); cands[i],cands[j]=cands[j],cands[i] end
	local before=placedCount(plot)
	for i=1,math.min(#cands,PLACE_TRIES) do
		local c=cands[i]
		local y=plotGroundY(c.X,c.Y,fy)+1
		pcall(function() placeRemote:FireServer(tname, Vector3.new(c.X,y,c.Y), 0) end)
		local t0=os.clock()
		while os.clock()-t0<0.4 do if placedCount(plot)>before then return "ok",c.X,c.Y end task.wait(0.08) end
	end
	return "kein-spot"
end
-- Hintergrund-Schleife: legt alle gefilterten Kristall-Tools nacheinander in den Plot
-- Kristall-Tool erkennen: per Tier-Attribut ODER Namensmuster "[S] Name [1.5kg]"
local function isCrystalTool(t)
	if not t:IsA("Tool") then return false end
	if t:GetAttribute("Tier")~=nil then return true end
	return t.Name:match("^%[.-%].-%[.-[kK][gG]%]%s*$")~=nil
end
local function backpackHasCrystals()
	local bp=player:FindFirstChild("Backpack"); if not bp then return false end
	for _,t in ipairs(bp:GetChildren()) do if isCrystalTool(t) then return true end end
	return false
end
-- Tool ist Luck-würdig (kommt in den Plot)?
local function isPlaceableTool(t)
	return isCrystalTool(t) and (t:GetAttribute("Tier")==nil or crystalLuckPct(t)>=LUCK_X10/10)
end
-- Tool ist Sell-Ziel (Kristall, NICHT Luck-würdig)?  (im Backpack sind eh nur Luck/Sell-Ziele)
local function isSellTool(t)
	if not isCrystalTool(t) then return false end
	if not AUTO_PLACE then return true end   -- Plot AUS -> ALLES verkaufen (Luck-Kristalle kommen ja nicht in den Plot)
	if plotFull() then return true end       -- Plot VOLL -> ALLES verkaufen (kommt eh nicht rein)
	-- Plot AN + Platz: nur NICHT-Luck-Kristalle (Luck -> Plot) und nur über der Geld-Schwelle
	if t:GetAttribute("Tier")~=nil and crystalLuckPct(t)>=LUCK_X10/10 then return false end
	local v=t:GetAttribute("Value")
	if v~=nil and v<SELL_MIN_VALUE then return false end
	return true
end
local function backpackHasPlaceable()
	local bp=player:FindFirstChild("Backpack"); if not bp then return false end
	for _,t in ipairs(bp:GetChildren()) do if isPlaceableTool(t) then return true end end
	return false
end
local function backpackHasSellable()
	local bp=player:FindFirstChild("Backpack"); if not bp then return false end
	for _,t in ipairs(bp:GetChildren()) do if isSellTool(t) then return true end end
	return false
end
-- aktuelles/max Trage-Gewicht aus der GUI ("0.6 / 2312.0 kg") -> berücksichtigt Pickaxe-x4-Perk automatisch
local function backpackWeight()
	local cur,mx
	pcall(function()
		local pg=player:FindFirstChild("PlayerGui"); if not pg then return end
		for _,d in ipairs(pg:GetDescendants()) do
			if d:IsA("TextLabel") then
				local a,b=tostring(d.Text):match("([%d%.]+)%s*/%s*([%d%.]+)%s*[kK][gG]")
				if a and b then cur=tonumber(a); mx=tonumber(b); break end
			end
		end
	end)
	return cur, mx
end
local function placerLoop()
	if not placeRemote then placeRemote=RS:FindFirstChild("PlotPlaceRequest", true) end
	if not (AUTO_PLACE and placeRemote) then if AUTO_PLACE then log("[Plot] Remote PlotPlaceRequest FEHLT") end return end
	local p0=myPlot()
	log("[Plot] Auto-Place an | Plot="..(p0 and p0.Name or "NIL").." | Cap="..(p0 and plotCapacity() or 0).." | belegt="..(p0 and placedCount(p0) or 0))
	local fails=setmetatable({},{__mode="k"})   -- tool -> Fehlversuche (schwache Keys)
	local diagged=false
	while running do
		local plot=myPlot(); local bp=player:FindFirstChild("Backpack")
		if not plot then
			if not diagged then diagged=true; log("[Plot] kein 'Slots."..player.Name.."' in diesem Server — hast du hier einen Plot?") end
		elseif bp and placedCount(plot)<plotCapacity() then
			local tool,nT,nTier,nLow=nil,0,0,0
			for _,t in ipairs(bp:GetChildren()) do
				if isCrystalTool(t) then nT+=1
					if t:GetAttribute("Tier")~=nil then nTier+=1 end
					local luckOk = (LUCK_X10<=0) or (not CrystalLuck) or (t:GetAttribute("Tier")==nil) or (crystalLuckPct(t)>=LUCK_X10/10)
					if (fails[t] or 0)<3 and luckOk then tool=t; break
					elseif not luckOk then nLow+=1 end
				end
			end
			if tool then
				diagged=false
				local r,x,z=placeOneTool(plot,tool)
				if r=="ok" then log(string.format("  💠 Plot: %s @(%.0f,%.0f) [%d/%d]", tool.Name, x, z, placedCount(plot), plotCapacity()))
				elseif r=="voll" then log("  [Plot] voll ("..placedCount(plot).."/"..plotCapacity()..")"); task.wait(2)
				else fails[tool]=(fails[tool] or 0)+1; log("  [Plot] kein Platz für "..tool.Name.." (Versuch "..(fails[tool])..")") end
			elseif not diagged and nT>0 then
				diagged=true; log(string.format("[Plot] idle: %d Kristall-Tools (%d mit Tier, %d unter Min-Luck) — keiner platzierbar", nT, nTier, nLow))
			end
		end
		task.wait(0.5)
	end
end

-- gestufter Teleport zu einem Zielpunkt (umgeht Anti-Cheat-Rubberband bei Riesen-Sprüngen)
local function stepTeleport(targetPos, stepLen, perWait)
	stepLen=stepLen or 80; perWait=perWait or 0.05
	local root=getRoot(); if not root then return false end
	for _=1,500 do
		local cur=root.Position
		local d=targetPos-cur; local dist=d.Magnitude
		if dist<=stepLen then root.CFrame=CFrame.new(targetPos); root.AssemblyLinearVelocity=Vector3.zero; return true end
		local np=cur+d.Unit*stepLen
		root.CFrame=CFrame.new(np); root.AssemblyLinearVelocity=Vector3.zero
		pcall(function() player:RequestStreamingAround(np) end)
		task.wait(perWait)
		root=getRoot(); if not root then return false end
	end
	return false
end

-- Surface-following Anflug (wie der Sweep) zu einem Punkt am Base -> KEIN Rubberband (braucht running=true)
local function gotoBase(targetPos)
	pcall(function() glideToXZ(targetPos.X, targetPos.Z) end)
	local root=getRoot()
	if root then pcall(function() root.CFrame=CFrame.new(targetPos); root.AssemblyLinearVelocity=Vector3.zero end) end
	task.wait(0.4)
end

-- Restliche Kristall-Tools synchron in den Plot legen (vor Rejoin)
local function drainPlacer(timeout)
	if not (AUTO_PLACE and placeRemote) then return end
	local plot=myPlot(); if not plot then log("[Plot] Drain: kein Plot in diesem Server"); return end
	-- zum eigenen Plot teleportieren (Server verlangt Nähe zum Platzieren)
	do
		local mnx,mxx,mnz,mxz,fy=plotBox(plot)
		if mnx then
			local cx,cz=(mnx+mxx)/2,(mnz+mxz)/2
			local gy=plotGroundY(cx,cz,fy)+5
			local root=getRoot()
			if root then
				log(string.format("[Plot] TP zum Plot (%.0f,%.0f,%.0f)", cx,gy,cz))
				gotoBase(Vector3.new(cx,gy,cz))             -- surface-following -> kein Rubberband
				pcall(function() player:RequestStreamingAround(Vector3.new(cx,gy,cz)) end)
				task.wait(0.3)
				local sy=plotGroundY(cx,cz,fy)              -- nachsnappen, falls drunter gelandet
				if sy then local r=getRoot(); if r then r.CFrame=CFrame.new(cx,sy+4,cz); r.AssemblyLinearVelocity=Vector3.zero end end
				task.wait(0.3)
			end
		end
	end
	tlog(string.format("DRAIN start | Plot=%s belegt=%d/%d", plot.Name, placedCount(plot), plotCapacity()))
	-- Kollision mit den schon platzierten (Base-)Kristallen aus, damit der Char nicht weggeschoben/blockiert wird
	local char=player.Character
	pcall(function() for _,p in ipairs(char:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide=false end end end)
	local fails=setmetatable({},{__mode="k"})
	local t0=os.clock()
	local placed=0
	while os.clock()-t0<(timeout or 25) do
		if placedCount(plot)>=plotCapacity() then log("  [Plot] voll ("..placedCount(plot).."/"..plotCapacity()..")"); tlog("DRAIN voll "..placedCount(plot).."/"..plotCapacity()); break end
		local bp=player:FindFirstChild("Backpack"); if not bp then tlog("DRAIN: kein Backpack"); break end
		local tool
		local nCT,nLow=0,0
		for _,t in ipairs(bp:GetChildren()) do
			if isCrystalTool(t) then nCT+=1
				local lk=(LUCK_X10<=0) or (not CrystalLuck) or (t:GetAttribute("Tier")==nil) or (crystalLuckPct(t)>=LUCK_X10/10)
				if (fails[t] or 0)<3 and lk then tool=t; break
				elseif not lk then nLow+=1 end
			end
		end
		if not tool then tlog(string.format("DRAIN ende: %d platziert | Backpack: %d Kristall-Tools (%d unter Min-Luck)", placed, nCT, nLow)); break end
		local r,x,z=placeOneTool(plot,tool)
		if r=="ok" then placed+=1; log(string.format("  💠 Drain: %s [%d/%d]", tool.Name, placedCount(plot), plotCapacity())); tlog(string.format("DRAIN ok %s [%d/%d] @(%.0f,%.0f)", tool.Name, placedCount(plot), plotCapacity(), x or 0, z or 0))
		elseif r=="voll" then tlog("DRAIN voll"); break
		else fails[tool]=(fails[tool] or 0)+1; tlog(string.format("DRAIN KEIN-SPOT %s (Versuch %d) — Platzierung abgelehnt/keine freie Stelle", tool.Name, fails[tool])) end
	end
	fixCollision()      -- Kollision wieder an
end

-- Sell-Ziele aus dem Backpack am SellProx verkaufen (equip -> SellRequest:FireServer("held"))
local function sellBackpack()
	if not (SELL_ENABLED and sellRemote) then return 0 end
	if not backpackHasSellable() then return 0 end
	local prox=Workspace:FindFirstChild("Things") and Workspace.Things:FindFirstChild("SellProx")
	local spot = (prox and prox:IsA("BasePart")) and (prox.Position+Vector3.new(0,3,0)) or nil
	local root=getRoot(); if not (spot and root) then return 0 end
	log("[Sell] zum SellProx")
	gotoBase(spot)                                        -- surface-following -> kein Rubberband
	-- am Prox verankern + settlen, sonst registriert der Server die Nähe nicht ("get closer")
	local wasAnch=root.Anchored
	pcall(function() root.CFrame=CFrame.new(spot); root.AssemblyLinearVelocity=Vector3.zero; root.Anchored=true end)
	task.wait(0.8)
	-- SHOP ÖFFNEN (sonst kein Verkauf / "get closer") — Prompt feuern + SellOpen-Remote
	local prompt = prox:FindFirstChildWhichIsA("ProximityPrompt")
	pcall(function() if fireproximityprompt and prompt then fireproximityprompt(prompt) end end)
	local sellOpen = RS:FindFirstChild("SellOpen", true)
	pcall(function() if sellOpen then sellOpen:FireServer() end end)
	task.wait(0.6)
	local hum=getHum()
	local toSell={}
	local bp=player:FindFirstChild("Backpack")
	if bp then for _,t in ipairs(bp:GetChildren()) do if isSellTool(t) then table.insert(toSell,t) end end end
	local sold=0
	for _,t in ipairs(toSell) do
		if t and t.Parent then
			pcall(function() root.CFrame=CFrame.new(spot); root.AssemblyLinearVelocity=Vector3.zero end)  -- nah am Prox bleiben
			pcall(function() if hum then hum:EquipTool(t) end end)
			task.wait(0.2)
			pcall(function() sellRemote:FireServer("held") end)
			task.wait(0.4)
			if not t.Parent then sold+=1
			else pcall(function() if hum then hum:UnequipTools() end end); task.wait(0.1) end  -- nicht verkauft -> zurück ins Backpack (kein Drop)
		end
	end
	pcall(function() if hum then hum:UnequipTools() end end)   -- nichts in der Hand zurücklassen
	pcall(function() root.Anchored=wasAnch end)
	if sold>0 then log("  💰 verkauft: "..sold.." Kristall(e)"); tlog("SELL "..sold.." verkauft") end
	return sold
end

-- Backpack zu voll -> zum Base (verkaufen + platzieren = Platz schaffen), dann zurück zum Kristall
local function freeBackpackFor(returnPos)
	clog("FREE: Backpack zu voll -> Base aufräumen (sell+place)")
	stat.Text="Backpack voll — räume am Base auf…"
	if SELL_ENABLED and backpackHasSellable() then pcall(sellBackpack) end
	if AUTO_PLACE and backpackHasPlaceable() then pcall(function() drainPlacer(60) end) end
	if returnPos then gotoBase(returnPos+Vector3.new(0,4,0)); pcall(function() player:RequestStreamingAround(returnPos) end); task.wait(0.3) end
end

local function doCollect(crystal)
	local cname=crystal:GetAttribute("CrystalName") or crystal.Name
	-- Ziel-Infos VOR dem Sammeln festhalten (Kristall wird ggf. zerstört)
	local cluck=crystalLuckPct(crystal)
	local ctier=crystal:GetAttribute("Tier"); local ckg=crystal:GetAttribute("WeightKg") or 0
	local cpos=crystal.Position
	local isHigh = (LUCK_X10>0 and CrystalLuck and cluck>=LUCK_X10/10)
	-- Backpack-Gewicht: passt der Kristall überhaupt rein?
	do
		local cur,mx = backpackWeight()
		if mx and ckg>0 then
			if ckg >= mx then
				deadCrystals[crystal]=true
				clog(string.format("zu schwer (%.0fkg >= Backpack-Max %.0f) -> blacklist %s", ckg, mx, tostring(cname)))
				log(string.format("  ⛔ %s %.0fkg passt nie ins Backpack (max %.0f) — übersprungen", tostring(cname), ckg, mx))
				return
			elseif ckg > (mx-(cur or 0)) then
				log(string.format("  ⚖️ Backpack zu voll (%.0f/%.0f) für %s %.0fkg — räume auf", cur or 0, mx, tostring(cname), ckg))
				freeBackpackFor(cpos)
				if not crystal.Parent then return end   -- evtl. weg während des Aufräum-TPs
			end
		end
	end
	stat.Text=string.format("OK:%d Fail:%d -> %s", farmDone, farmFails, tostring(cname))
	log("-> "..tostring(cname).." (T"..tostring(crystal:GetAttribute("Tier"))..")")
	clog(string.format("MINE %s %dkg %.1f%% @(%.0f,%.0f,%.0f)", tostring(cname), math.floor(ckg), cluck, cpos.X,cpos.Y,cpos.Z))
	mineNowPos=cpos      -- für Tod-Erkennung (CharacterAdded prüft das)
	local _t0=os.clock()
	local pok, ok, reason = pcall(collect, crystal)
	crystalTime[crystal]=(crystalTime[crystal] or 0)+(os.clock()-_t0)
	mineNowPos=nil       -- überlebt -> kein Killer-Spot
	if not pok then
		farmFails+=1; attempts[crystal]=(attempts[crystal] or 0)+1
		clog("collect-FEHLER "..tostring(cname)..": "..tostring(ok))
		log("  ! Fehler: "..tostring(ok)); task.wait(0.3)
	elseif ok then farmDone+=1; log("  ✓ "..reason)
	else farmFails+=1; attempts[crystal]=(attempts[crystal] or 0)+1; farmReasons[reason]=(farmReasons[reason] or 0)+1; log("  ✗ "..reason) end
	-- Failsafe: nach MAX_ATTEMPTS ODER MAX_CRYSTAL_TIME endgültig aufgeben (Blacklist überlebt attempts-Reset)
	if crystal.Parent and ((attempts[crystal] or 0)>=MAX_ATTEMPTS or (crystalTime[crystal] or 0)>=MAX_CRYSTAL_TIME) then
		deadCrystals[crystal]=true
		log(string.format("  ⛔ aufgegeben (%d Versuche / %.0fs): %s (%.0fkg) — übersprungen", attempts[crystal] or 0, crystalTime[crystal] or 0, tostring(cname), ckg))
		if isHigh then tlog(string.format("AUFGEGEBEN %s %.0fkg %.1f%% nach %d Versuchen/%.0fs @(%.0f,%.0f,%.0f)", tostring(cname), ckg, cluck, attempts[crystal] or 0, crystalTime[crystal] or 0, cpos.X,cpos.Y,cpos.Z)) end
	end
	-- High-Luck-Ziele IMMER auf Platte protokollieren (Erfolg ODER Fehlgrund), für Debugging
	if isHigh then
		local res = (not pok) and ("ERR:"..tostring(ok)) or (ok and ("OK ("..tostring(reason)..")") or ("FAIL ("..tostring(reason)..")"))
		tlog(string.format("%s T%s %.0fkg %.1f%% @(%.0f,%.0f,%.0f) -> %s", tostring(cname), tostring(ctier), ckg, cluck, cpos.X,cpos.Y,cpos.Z, res))
	end
	if os.clock()-lastRest > REST_INTERVAL then chill(); lastRest=os.clock() end
end

-- alle geladenen Ziele in Reichweite eines Wegpunkts einsammeln
local function farmAround(wx, wz)
	while running do
		local root=getRoot(); if not root then break end
		local best,bd=nil,math.huge
		for _,o in ipairs(crystalsFolder:GetDescendants()) do
			if isCollectable(o) and not deadCrystals[o] and (attempts[o] or 0)<MAX_ATTEMPTS then
				local dWp=(Vector3.new(o.Position.X,0,o.Position.Z)-Vector3.new(wx,0,wz)).Magnitude
				if dWp<=SWEEP_RADIUS then
					local d=(o.Position-root.Position).Magnitude
					if d<bd then bd,best=d,o end
				end
			end
		end
		if not best then break end
		doCollect(best)
	end
end

-- === SCOUT-PASS: per Streaming schnell prüfen ob ein ≥Min-Luck-Ziel im Server ist ===
local SCOUT = true
local SCOUT_CELL = 300      -- Rasterabstand der Streaming-Abfragen (Lade-Radius ist groß: max 300-750/Punkt); auch der X/Z-Abstand der 3-Etappen-Punkte
local SCOUT_WAIT = 0.22     -- Wartezeit pro Punkt fürs Nachladen (sanfter = kleinerer Speicher-Burst)
-- SCOUT_RADIUS ist weiter oben deklariert (persistent, per Slider einstellbar)
local MIN_COVER = 120       -- lädt der Scout weniger als das, ist die Coverage kaputt -> NICHT hoppen, Grid-Sweep als Fallback

local function scanLoadedForTarget()
	for _,o in ipairs(crystalsFolder:GetDescendants()) do
		if isTarget(o) then return o end
	end
	return nil
end
-- streamt rasterartig über den GANZEN Berg (ohne hinzufliegen) und sammelt ALLE Ziel-Positionen.
-- Scannt EIN Drittel des Berges (um zc herum), 5 Scans über die X-Breite verteilt.
-- Rückgabe: Liste von Vector3 (Ziele in diesem Drittel) + maxSeen (Diagnose).
local function scoutThird(cx, zc, streamY, ei)
	local found={}
	local function addLoaded()
		for _,o in ipairs(crystalsFolder:GetDescendants()) do
			if isCollectable(o) then
				local p=o.Position; local dup=false
				for _,q in ipairs(found) do if (q-p).Magnitude<12 then dup=true; break end end
				if not dup then table.insert(found, p) end
			end
		end
	end
	local xOffs = { -2*SCOUT_CELL, -SCOUT_CELL, 0, SCOUT_CELL, 2*SCOUT_CELL }
	local maxSeen=0
	for i,xo in ipairs(xOffs) do
		if not running then break end
		pcall(function() player:RequestStreamingAround(Vector3.new(cx+xo, streamY, zc)) end)
		stat.Text=string.format("Etappe %d/3: Scan %d/5 | %d Ziele", ei or 0, i, #found)
		task.wait(SCOUT_WAIT)
		local seen=0
		for _,o in ipairs(crystalsFolder:GetDescendants()) do if o:IsA("BasePart") and o:GetAttribute("Tier")~=nil then seen+=1 end end
		if seen>maxSeen then maxSeen=seen end
		addLoaded()
	end
	local mem=0; pcall(function() mem=collectgarbage("count") end)
	scoutLog(string.format("etappe %s @Z=%.0f | %d Ziele | max %d | mem %.0fMB", tostring(ei), zc, #found, maxSeen, mem/1024))
	return found, maxSeen
end

-- Mittelpunkt aller geladenen Kristalle (Sweep-Mitte) auf der Oberfläche — für Rescan-TP
local function sweepCenter()
	local mnx,mxx,mnz,mxz=bounds()
	if not mnx then return nil end
	local cx,cz=(mnx+mxx)/2,(mnz+mxz)/2
	local sy=surfaceYat(cx,cz)
	local pc=peakCenter()
	local cy=sy or (pc and pc.Y) or (getRoot() and getRoot().Position.Y) or 100
	return Vector3.new(cx, cy+5, cz)
end

local function runFarm()
	if not anyTierSelected() then stat.Text="Kein Tier angekreuzt!"; return end
	running=true; refreshBtn(); attempts={}; crystalTime=setmetatable({},{__mode="k"}); deadCrystals=setmetatable({},{__mode="k"}); farmDone=0; farmFails=0; farmReasons={}; lastRest=os.clock()
	local targets=nil
	local startPos = getRoot() and getRoot().Position   -- Spawn-Position merken (liegt nah am Berg)
	log("=== SWEEP START ===")
	-- 1) ZUERST platzieren: Backpack-Kristalle vom letzten Server reinlegen, solange wir noch nah am Plot/Spawn sind
	--    (verhindert den Mega-TP-Rubberband vom Gipfel und nutzt die Nähe direkt nach dem Join)
	local didBase=false
	-- ZUERST verkaufen (macht Backpack frei: 'TOO HEAVY' verhindern), DANN platzieren
	if SELL_ENABLED and backpackHasSellable() then
		clog("phase: SELL")
		log("=== SELL (wertvolle Kristalle verkaufen) ===")
		stat.Text="Verkaufe Kristalle…"
		sellBackpack(); didBase=true
	end
	if AUTO_PLACE and backpackHasPlaceable() then
		clog("phase: PLACE")
		log("=== PLOT-PLACE (Luck-Kristalle vom letzten Server) ===")
		stat.Text="Platziere im Plot…"
		drainPlacer(60); didBase=true
	end
	-- WICHTIG: zurück zur Spawn-Position — sonst stehen wir am Plot/SellProx und recenter findet den Berg nicht
	if didBase and startPos then log("[Base] zurück zur Startposition für den Scan"); gotoBase(startPos); task.wait(0.4) end
	-- 3) SCOUT+SAMMELN in 3 Etappen: je ein Drittel des Berges an der Z-Achse.
	--    Pro Etappe: DIREKT zum Drittel tpen -> 5 Scans über die X-Breite -> gefundene Ziele sammeln -> nächstes Drittel.
	if SCOUT and LUCK_X10>0 then
		-- WICHTIG: aufs Luck-Modul warten — sonst filtert isTarget nichts und der Scout "findet" alles
		if not CrystalLuck then
			stat.Text="warte auf Luck-Modul…"
			local t=os.clock(); while not CrystalLuck and os.clock()-t<12 do task.wait(0.2) end
			log(CrystalLuck and "CrystalLuck geladen" or "WARN: CrystalLuck NICHT geladen — Filter inaktiv!")
		end
		-- Berg-Mitte bestimmen OHNE erst hinzufahren: erst vom Spawn aus anstreamen, dann peakCenter.
		-- Nur wenn gar nichts lädt -> einmal physisch recenter (an den Berg), damit peakCenter greift.
		stat.Text="Berg lokalisieren…"
		pcall(function() local r=getRoot(); if r then player:RequestStreamingAround(r.Position) end end); task.wait(0.5)
		local c = peakCenter()
		if not c then recenter(); c = peakCenter() end
		if not c then
			log("Kein Berg-Center gefunden -> hoppe"); running=false; refreshBtn()
			if AUTO_REJOIN then task.wait(1); serverHop() end; return
		end
		local cpos = Vector3.new(c.X, c.Y, c.Z + RECENTER_Z)   -- Bezugsmitte (wie beim alten Zentrieren, weiter in den Berg)
		local streamY = c.Y
		local dz = SCOUT_RADIUS                            -- äußere Punkte bis ans Bergende (nicht nur bis zur Hälfte)
		local thirds = { cpos.Z + dz, cpos.Z, cpos.Z - dz }
		local anyFound=false
		for ei,zc in ipairs(thirds) do
			if not running then break end
			clog(string.format("phase: ETAPPE %d/3 @Z=%.0f", ei, zc))
			stat.Text=string.format("Etappe %d/3: fahre zum Drittel…", ei)
			-- Sweep-TP (oberflächenfolgend) zum Drittel — KEIN stepTeleport (sonst Rubberband vom Gipfel)
			pcall(function() player:RequestStreamingAround(Vector3.new(cpos.X, streamY, zc)) end); task.wait(0.3)
			glideToXZ(cpos.X, zc); task.wait(0.3)
			local tgt, maxSeen = scoutThird(cpos.X, zc, streamY, ei)
			if not running then return end
			clog(string.format("etappe %d scan: %d Ziele (max %d geladen)", ei, #tgt, maxSeen))
			if #tgt>0 then
				anyFound=true
				log(string.format("=== Etappe %d/3: %d Ziel(e) -> sammeln ===", ei, #tgt))
				for i,pos in ipairs(tgt) do
					if not running then break end
					stat.Text=string.format("Etappe %d/3 Ziel %d/%d | OK:%d Fail:%d", ei, i, #tgt, farmDone, farmFails)
					glideToXZ(pos.X, pos.Z)
					pcall(function() local r=getRoot(); if r then player:RequestStreamingAround(r.Position) end end); task.wait(0.25)
					while running do
						local b=nearestTarget(); if not b then break end
						if (b.Position-Vector3.new(pos.X,b.Position.Y,pos.Z)).Magnitude>SWEEP_RADIUS then break end
						doCollect(b)
					end
				end
			else
				log(string.format("=== Etappe %d/3 @Z=%.0f: keine Ziele ===", ei, zc))
			end
		end
		if not running then return end
		if not anyFound then
			log(string.format("=== kein %.1f%%-Ziel in allen 3 Etappen -> HOP ===", LUCK_X10/10))
			running=false; refreshBtn()
			if AUTO_REJOIN then task.wait(1); serverHop() end
			return
		end
		targets=nil                                   -- schon per Etappe gesammelt; kein Beeline/Sweep mehr
	else
		-- SCOUT aus: klassischer Grid-Sweep über die geladenen Bounds
		local mnx,mxx,mnz,mxz=bounds()
		if not mnx then
			log("Keine Kristalle geladen — bitte am Berg starten!")
			stat.Text="Keine Kristalle — geh zum Berg"; running=false; refreshBtn()
			if AUTO_REJOIN and getgenv and getgenv().CRYSTAL_AUTOSTART then task.wait(3); serverHop() end
			return
		end
		mnx=mnx-SWEEP_MARGIN; mxx=mxx+SWEEP_MARGIN; mnz=mnz-SWEEP_MARGIN-SWEEP_EXTRA_NEGZ; mxz=mxz+SWEEP_MARGIN
		log(string.format("Sweep-Bereich X[%.0f..%.0f] Z[%.0f..%.0f]", mnx,mxx,mnz,mxz))
		local col=0
		local x=mnx
		while x<=mxx and running do
			local zs={}
			if col%2==0 then local z=mnz; while z<=mxz do table.insert(zs,z); z+=SWEEP_CELL end
			else local z=mxz; while z>=mnz do table.insert(zs,z); z-=SWEEP_CELL end end
			for _,z in ipairs(zs) do
				if not running then break end
				stat.Text=string.format("Sweep x=%.0f z=%.0f | OK:%d Fail:%d", x, z, farmDone, farmFails)
				log(string.format("== Zelle x=%.0f z=%.0f ==", x, z))
				glideToXZ(x, z)
				pcall(function() local r=getRoot(); if r then player:RequestStreamingAround(r.Position) end end); task.wait(0.3)
				farmAround(x, z)
			end
			x+=SWEEP_CELL; col+=1
		end
	end

	-- === CLEANUP-PASS: alles noch Geladene einsammeln (frisches Budget), bis nichts mehr übrig ===
	if running then
		log("=== CLEANUP-PASS ===")
		for pass=1,6 do
			if not running then break end
			attempts={}                              -- frische Versuche für früh-gecapte Kristalle
			local remaining=0
			for _,o in ipairs(crystalsFolder:GetDescendants()) do if isCollectable(o) and not deadCrystals[o] then remaining+=1 end end
			log(string.format("Cleanup #%d: %d Ziele geladen", pass, remaining))
			if remaining==0 then break end
			local got=farmDone
			while running do
				local best=nearestTarget()
				if not best then break end
				stat.Text=string.format("Cleanup #%d | OK:%d Fail:%d", pass, farmDone, farmFails)
				glideToXZ(best.Position.X, best.Position.Z)
				pcall(function() local r=getRoot(); if r then player:RequestStreamingAround(r.Position) end end); task.wait(0.2)
				local b2=nearestTarget(); if not b2 then break end
				doCollect(b2)
			end
			if farmDone==got then break end          -- kein Fortschritt mehr -> fertig
		end
	end

	-- Bilanz (KEIN zweiter Scan): nur zählen wie viele Ziele jetzt noch geladen aber NICHT geholt sind (sollte 0)
	local loadedLeft=0
	for _,o in ipairs(crystalsFolder:GetDescendants()) do if isCollectable(o) and not deadCrystals[o] then loadedLeft+=1 end end
	log(string.format("BILANZ: gesammelt %d | offen geladen %d (sollte 0 sein)", farmDone, loadedLeft))
	tlog(string.format("BILANZ gesammelt=%d offen=%d JobId=%s", farmDone, loadedLeft, tostring(game.JobId)))

	local completed = running   -- true=natürlich fertig, false=manuell gestoppt
	destroyBox()
	log("=== SWEEP FERTIG ==="); log(string.format("Gesammelt: %d  |  Fails: %d", farmDone, farmFails))
	log("-- Fehlergründe --")
	for r,c in pairs(farmReasons) do log(string.format("  %dx  %s", c, r)) end
	stat.Text=string.format("Fertig: %d gesammelt, %d fails", farmDone, farmFails)
	running=false; refreshBtn()
	-- Platzieren passiert BEIM NÄCHSTEN JOIN (am Anfang, nah am Plot) — der gesammelte Kristall bleibt solange im Backpack
	if completed and AUTO_REJOIN then task.wait(1); serverHop() end
end

-- runFarm geschützt ausführen: Fehler + Traceback ins crash_log.txt schreiben (Post-Mortem)
local function safeRunFarm()
	clog("runFarm() START")
	local ok,err = xpcall(runFarm, function(e)
		local tb=""; pcall(function() tb=debug.traceback("",2) end)
		return tostring(e).."\n"..tb
	end)
	if not ok then
		clog("!!! CRASH in runFarm:\n"..tostring(err))
		pcall(function() log("!! CRASH (crash_log.txt): "..tostring(err):sub(1,90)) end)
		running=false; pcall(refreshBtn); pcall(destroyBox)
		-- nach Crash nicht hängen: bei Autostart weiter zum nächsten Server hoppen
		if AUTO_REJOIN and getgenv and getgenv().CRYSTAL_AUTOSTART then task.wait(3); pcall(serverHop) end
	else
		clog("runFarm() ENDE (sauber)")
	end
end

btn.MouseButton1Click:Connect(function()
	if running then running=false; refreshBtn(); destroyBox() else task.spawn(safeRunFarm) end
end)
player.CharacterAdded:Connect(function()
	local wasRunning=running
	-- Reset beim Minen? -> Spot zählen; erst nach 3x überspringen (sonst wertvollen Kristall einfach nochmal versuchen)
	if mineNowPos then
		local k=spotKey(mineNowPos)
		respawnCount[k]=(respawnCount[k] or 0)+1
		clog(string.format("RESET beim Minen @(%.0f,%.0f,%.0f) — %dx an dem Spot", mineNowPos.X,mineNowPos.Y,mineNowPos.Z, respawnCount[k]))
		if respawnCount[k]>=3 then table.insert(killerSpots, mineNowPos); clog("-> Spot nach 3x blacklistet"); pcall(function() log("☠️ Spot 3x resettet — übersprungen") end) end
		mineNowPos=nil
	end
	running=false; pcall(refreshBtn); pcall(destroyBox)
	-- bei Reset/Respawn WÄHREND des Farmens: nicht komplett stoppen, sondern neu starten
	if wasRunning then
		clog("char RESET während Farm -> Neustart in 4s")
		task.wait(4)
		if not running then task.spawn(safeRunFarm) end
	end
end)
refreshBtn()

-- === Auto-Start (via autoexec nach jedem (Re)Join) ===
if getgenv and getgenv().CRYSTAL_AUTOSTART then
	log("AUTO-START aktiv (autoexec) — Farm startet gleich...")
	task.delay(3, function() if not running then task.spawn(safeRunFarm) end end)
end

-- === Watchdog: nach MAX_SERVER_TIME hart hoppen (egal was läuft) — Reset pro Join (Script lädt neu) ===
if AUTO_REJOIN then
	task.spawn(function()
		local t0=os.clock()
		while true do
			task.wait(1)
			if MAX_SERVER_TIME and MAX_SERVER_TIME>0 and (os.clock()-t0)>=MAX_SERVER_TIME then
				clog("WATCHDOG: "..MAX_SERVER_TIME.."s im Server -> HARD HOP")
				pcall(function() log("⏱️ Max-Server-Zeit erreicht -> hoppe") end)
				running=false; pcall(refreshBtn); pcall(destroyBox)
				pcall(serverHop)
				break
			end
		end
	end)
end
