--[[ shape_gui.lua — Shape Factory Tool
     Feature 1: Auto-Seller (togglebar)
       Nimmt jede lose Shape (Tag "carryable", type="part") und legt sie automatisch
       auf den Seller.Sell-Part -> Server verkauft sie per Touch. Hilft in der Frühphase
       bevor man einen Conveyor gebaut hat.
     Hook-frei: feuert nur Remotes.Network ("pickup"/"general") + bewegt PrimaryPart,
       genau wie das Spiel es beim Tragen tut.
]]

local Players        = game:GetService("Players")
local RS             = game:GetService("ReplicatedStorage")
local RunService     = game:GetService("RunService")
local UserInput      = game:GetService("UserInputService")
local WS             = workspace
local lp             = Players.LocalPlayer

-- ===== altes Tool sauber killen (kein Zombie) =====
if _G.__ShapeTool and _G.__ShapeTool.destroy then pcall(_G.__ShapeTool.destroy) end
local _pg = lp:WaitForChild("PlayerGui")
local oldGui = _pg:FindFirstChild("ShapeToolGui")
if oldGui then oldGui:Destroy() end
local oldTags = _pg:FindFirstChild("ShapeZoneTags")
if oldTags then oldTags:Destroy() end
for _, m in ipairs(WS:GetChildren()) do
  if m.Name == "ShapeZoneMarker" then pcall(function() m:Destroy() end) end
end

local net = RS:WaitForChild("Remotes"):WaitForChild("Network")

local T = {}
_G.__ShapeTool = T
T.autoSell  = false
T.active    = {}     -- shape(Model) -> lastPickupTick
T.soldCount = 0
T.conns     = {}
-- ===== Auto-Conveyor State =====
T.autoConveyor = false
T.zones      = {}    -- array: { num=n, pos=Vector3, r=radius, marker=Part }
T.zoneByNum  = {}    -- num -> zone
T.zoneRadius = 2.5
T.convToken  = 0
T.movedCount = 0

local function log(msg)
  if rconsoleprint then pcall(rconsoleprint, "[ShapeTool] "..msg.."\n") end
end

-- ===== Helpers =====
local function getSell()
  local map = WS:FindFirstChild("Map")
  local bp  = map and map:FindFirstChild("BuildingParts")
  local seller = bp and bp:FindFirstChild("Seller")
  return seller and seller:FindFirstChild("Sell")
end

local function isLooseShape(d)
  return d:IsA("Model")
     and d:GetAttribute("type") == "part"
     and d.PrimaryPart
     and not d:GetAttribute("sold")
     and not d:GetAttribute("destroyed")
     and table.find(d:GetTags(), "carryable") ~= nil
end

-- ===== Auto-Seller Loop =====
-- Shapes werden NICHT eingefroren: aufheben (pickup=Ownership), ueber den Pool
-- teleportieren und REINFALLEN lassen. Beruehrt die Shape das Sell-Part, verkauft
-- der Server sie (sold=true). Kein velocity/pivot-Spam -> sonst schwebt sie & faellt nie rein.
local function dropPosFor(sell, i)
  -- kleiner Streuoffset damit viele Shapes nicht exakt aufeinander landen
  local a = (i % 8) * 0.7853981633974483   -- i * 45deg
  local r = 1.4 * (((i % 3) + 1) / 3)
  return sell.Position + Vector3.new(math.cos(a) * r, 4.2, math.sin(a) * r)
end

local dropCounter = 0
T.conns[#T.conns+1] = RunService.Heartbeat:Connect(function()
  if not T.autoSell then return end
  local sell = getSell()
  if not sell then return end
  local now = tick()

  -- neue lose Shapes aufheben + ueber den Pool werfen
  local parts = WS:FindFirstChild("Parts")
  local scan = parts and parts:GetChildren() or WS:GetChildren()
  local newThisFrame = 0
  for _, d in ipairs(scan) do
    if isLooseShape(d) and not T.active[d] and newThisFrame < 8 then
      newThisFrame = newThisFrame + 1
      dropCounter = dropCounter + 1
      T.active[d] = now
      pcall(function()
        net:FireServer("pickup", d)
        d:PivotTo(CFrame.new(dropPosFor(sell, dropCounter)))
      end)
    end
  end

  -- aktive Shapes: fallen lassen, general feuern, erst nach Timeout neu werfen
  for shape, picked in pairs(T.active) do
    if not shape.Parent or not shape.PrimaryPart
       or shape:GetAttribute("sold") or shape:GetAttribute("destroyed") then
      if shape:GetAttribute("sold") or not shape.Parent then T.soldCount = T.soldCount + 1 end
      T.active[shape] = nil
    else
      pcall(function() net:FireServer("general", shape) end)   -- Ownership/Carry halten
      if now - picked > 1.3 then
        -- ist wohl aus dem Pool gefallen -> nochmal aufheben & reinwerfen
        dropCounter = dropCounter + 1
        T.active[shape] = now
        pcall(function()
          net:FireServer("pickup", shape)
          shape:PivotTo(CFrame.new(dropPosFor(sell, dropCounter)))
        end)
      end
    end
  end
end)

-- ===== Auto-Conveyor =====
-- Reihe nummerierter Teleport-Zonen. Alle 0.1s werden abwechselnd die UNGERADEN und
-- die GERADEN Zonen getriggert: jede Shape in Zone n wandert nach Zone n+1. Durch das
-- Wechseln (odd-tick / even-tick) rutscht jede Shape genau 1 Zone pro 0.1s weiter,
-- statt in einem Frame durch alle Zonen durchgereicht zu werden = echter Conveyor.
local function getRootPos()
  local char = lp.Character
  local hrp = char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso"))
  return hrp and hrp.Position
end

-- eigenes ScreenGui nur fuer die Zonen-Zahlen (2D, auf den Bildschirm projiziert)
local zoneGui = Instance.new("ScreenGui")
zoneGui.Name = "ShapeZoneTags"
zoneGui.ResetOnSpawn = false
zoneGui.IgnoreGuiInset = true
zoneGui.DisplayOrder = 50
zoneGui.Parent = lp:WaitForChild("PlayerGui")
T.zoneGui = zoneGui

-- 2D-Screen-Tag mit der Zonennummer (folgt der Zone auf dem Bildschirm)
local function makeScreenTag(zone)
  local tag = Instance.new("TextLabel")
  tag.Name = "Zone" .. zone.num
  tag.Size = UDim2.fromOffset(38, 38)
  tag.AnchorPoint = Vector2.new(0.5, 0.5)
  tag.BackgroundColor3 = (zone.num % 2 == 1) and Color3.fromRGB(60, 140, 255) or Color3.fromRGB(255, 150, 45)
  tag.BackgroundTransparency = 0.15
  tag.Font = Enum.Font.GothamBlack
  tag.TextSize = 20
  tag.TextColor3 = Color3.fromRGB(255, 255, 255)
  tag.TextStrokeTransparency = 0.2
  tag.Text = tostring(zone.num)
  tag.Visible = false
  Instance.new("UICorner", tag).CornerRadius = UDim.new(1, 0)
  local stroke = Instance.new("UIStroke", tag)
  stroke.Color = Color3.fromRGB(0, 0, 0)
  stroke.Thickness = 2
  tag.Parent = zoneGui
  return tag
end

-- Screen-Tags jeden Frame auf die Zonenposition projizieren
T.conns[#T.conns+1] = RunService.RenderStepped:Connect(function()
  local cam = WS.CurrentCamera
  if not cam then return end
  for _, zone in ipairs(T.zones) do
    local tag = zone.scr
    if tag then
      local sp, onScreen = cam:WorldToViewportPoint(zone.pos + Vector3.new(0, (zone.height or 5) + 1.5, 0))
      if onScreen and sp.Z > 0 then
        tag.Visible = true
        tag.Position = UDim2.fromOffset(sp.X, sp.Y)
      else
        tag.Visible = false
      end
    end
  end
end)

local function makeMarker(zone)
  local h = zone.height or 5
  local part = Instance.new("Part")
  part.Name = "ShapeZoneMarker"
  part.Anchored = true
  part.CanCollide = false
  part.CanQuery = false
  -- Box vom Boden (zone.pos) bis Spielerhoehe -> Mittelpunkt liegt h/2 ueber dem Boden
  part.Size = Vector3.new(zone.r * 2, h, zone.r * 2)
  part.Position = zone.pos + Vector3.new(0, h / 2, 0)
  part.Transparency = 0.35
  part.Material = Enum.Material.Neon
  part.Color = (zone.num % 2 == 1) and Color3.fromRGB(60, 140, 255) or Color3.fromRGB(255, 150, 45)
  part.Parent = WS
  local bb = Instance.new("BillboardGui")
  bb.Size = UDim2.fromOffset(46, 46)
  bb.StudsOffset = Vector3.new(0, h / 2 + 1, 0)   -- Zahl schwebt ueber der Box
  bb.AlwaysOnTop = true
  bb.Parent = part
  local lbl = Instance.new("TextLabel")
  lbl.Size = UDim2.fromScale(1, 1)
  lbl.BackgroundTransparency = 1
  lbl.Font = Enum.Font.GothamBold
  lbl.TextSize = 24
  lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
  lbl.TextStrokeTransparency = 0
  lbl.Text = tostring(zone.num)
  lbl.Parent = bb
  return part
end

local function addZone()
  local char = lp.Character
  local hrp = char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso"))
  if not hrp then log("keine Character-Position (spawn erst)"); return end
  -- Bodenpunkt + volle Spielerhoehe aus der Bounding-Box
  local cf, size = char:GetBoundingBox()
  local height = size.Y
  local groundY = cf.Position.Y - size.Y / 2
  local pos = Vector3.new(hrp.Position.X, groundY, hrp.Position.Z)  -- Bodenmitte der Box
  local zone = { num = #T.zones + 1, pos = pos, r = T.zoneRadius, height = height }
  T.zones[#T.zones + 1] = zone
  T.zoneByNum[zone.num] = zone
  zone.marker = makeMarker(zone)
  zone.scr = makeScreenTag(zone)
  log("Zone " .. zone.num .. " gesetzt @ " .. string.format("%.0f,%.0f,%.0f (h=%.1f)", pos.X, pos.Y, pos.Z, height))
end

local function clearZones()
  for _, z in ipairs(T.zones) do
    if z.marker then pcall(function() z.marker:Destroy() end) end
    if z.scr then pcall(function() z.scr:Destroy() end) end
  end
  T.zones = {}
  T.zoneByNum = {}
  log("Zonen geloescht")
end

local function shapesInZone(zone, scan)
  local out = {}
  local r2 = zone.r * zone.r
  for _, d in ipairs(scan) do
    if isLooseShape(d) and not d:GetAttribute("sold") then
      local p = d.PrimaryPart.Position
      local dx, dz = p.X - zone.pos.X, p.Z - zone.pos.Z
      local h = zone.height or 5
      if (dx * dx + dz * dz) <= r2 and p.Y >= zone.pos.Y - 1 and p.Y <= zone.pos.Y + h + 2 then
        out[#out + 1] = d
      end
    end
  end
  return out
end

-- parity: 1 = ungerade Zonen, 0 = gerade Zonen
local function stepParity(parity)
  local parts = WS:FindFirstChild("Parts")
  local scan = parts and parts:GetChildren() or {}
  for _, zone in ipairs(T.zones) do
    if (zone.num % 2) == parity then
      local nz = T.zoneByNum[zone.num + 1]
      if nz then
        for _, shape in ipairs(shapesInZone(zone, scan)) do
          T.movedCount = T.movedCount + 1
          pcall(function()
            net:FireServer("pickup", shape)
            shape:PivotTo(CFrame.new(nz.pos + Vector3.new(0, 2, 0)))
            -- Momentum killen, sonst tragen sie sich aus der naechsten Zone heraus
            local pp = shape.PrimaryPart
            if pp then
              pp.AssemblyLinearVelocity = Vector3.zero
              pp.AssemblyAngularVelocity = Vector3.zero
            end
          end)
        end
      end
    end
  end
end

local function startConveyor()
  T.convToken = T.convToken + 1
  local myToken = T.convToken
  task.spawn(function()
    local phase = 1   -- mit ungeraden Zonen starten
    while T.autoConveyor and T.convToken == myToken and _G.__ShapeTool == T do
      pcall(stepParity, phase)
      phase = 1 - phase
      task.wait(0.1)
    end
  end)
end

-- ===== Auto-Craft =====
-- Prinzip (vom Spieler bestaetigt): Crafter craftet automatisch, sobald Rezept gewaehlt
-- ist UND genug Input drin liegt; er verbraucht dabei ALLE passenden Inputs im Inventar.
-- Output landet lose am Boden vor dem Crafter. EjectCrafter wirft Rest-Inventar raus.
-- => Mengensteuerung durch EXAKTES Fuettern. Ablauf pro Batch: leeren -> Rezept waehlen
--    -> exakt (qty*zutat) Inputs auf Input-Part -> auto-craft -> Output am Boden.
-- Planung: top-down exakte Mengen jeder Shape ausrechnen, dann bottom-up abarbeiten.
local Remotes   = RS:WaitForChild("Remotes")
local CrafterR  = Remotes:WaitForChild("Crafter")
local RecipesR  = Remotes:WaitForChild("Recipes")
local EjectR    = Remotes:WaitForChild("EjectCrafter")

local RECIPE = {
  SQUARE={TRIANGLE=2}, PENTAGON={TRIANGLE=3}, HEXAGON={TRIANGLE=4},
  STAR={TRIANGLE=5,PENTAGON=1}, HEART={TRIANGLE=1,CIRCLE=2}, DIAMOND={TRIANGLE=6,HEXAGON=1},
  GEAR={CIRCLE=1,SQUARE=4}, ["BIG TRIANGLE"]={TRIANGLE=9}, ["BIG SQUARE"]={SQUARE=9},
  ["BIG CIRCLE"]={CIRCLE=9}, ["BIG PENTAGON"]={PENTAGON=9}, ["BIG HEXAGON"]={HEXAGON=9},
  CUBE={SQUARE=6}, SPHERE={CIRCLE=5}, CYLINDER={CIRCLE=3}, CONE={TRIANGLE=3,CIRCLE=1},
  PYRAMID={TRIANGLE=4,SQUARE=1}, TETRAHEDRON={TRIANGLE=4}, OCTAHEDRON={TRIANGLE=8},
  ICOSAHEDRON={TETRAHEDRON=5}, DODECAHEDRON={PENTAGON=6}, ICOSPHERE={TRIANGLE=8,SPHERE=1},
  ["TORUS KNOT"]={CYLINDER=6}, HONEYCOMB={HEXAGON=4}, ["EGYPTIAN PYRAMID"]={SQUARE=6},
  TESSERACT={CUBE=1,SQUARE=6},
  ["ULTIMATE DICE"]={DODECAHEDRON=1,CUBE=1,TETRAHEDRON=1,ICOSAHEDRON=1,OCTAHEDRON=1},
  TROPHY={STAR=1,CYLINDER=2,CIRCLE=2}, LIMB={CIRCLE=1,CUBE=1,CYLINDER=1},
  TORSO={HEART=1,SQUARE=4}, HEAD={GEAR=1,CIRCLE=2}, HUMAN={TORSO=1,HEAD=1,LIMB=4},
}
local BASE = { TRIANGLE=true, CIRCLE=true }

T.autoCraft     = false
T.craftBusy     = false
T.craftedRound  = false
T.craftLeadSec  = 10     -- letzte Ernte; Umwandeln+Verkaufen dauert nur Sekunden
T.harvestEvery  = 15     -- alle 15s zwischenernten statt bis zum Ende zu horten
T.craftMsg      = "bereit"
T.storeRecipe   = "HUMAN"-- Rezept das aus Basis NICHT craftbar ist -> reiner Speicher
T.storeInit     = false  -- Rezept dieser Runde schon gesetzt?
T.storedCount   = 0

local _cm = {}
local function baseCost(sh)
  if _cm[sh] then return _cm[sh] end
  local r = RECIPE[sh]; if not r then return { [sh]=1 } end
  local acc = {}
  for ing,c in pairs(r) do for b,n in pairs(baseCost(ing)) do acc[b]=(acc[b] or 0)+n*c end end
  _cm[sh]=acc; return acc
end
local function costTotal(sh) local t=0 for _,n in pairs(baseCost(sh)) do t=t+n end return t end

-- ===== gemessene Shape-Werte =====
-- Der Output-Wert einer Shape ist eine FESTE Konstante pro Shape und haengt NICHT
-- davon ab, wie teuer sie herzustellen war (gemessen: jede 3D-Shape der 2. Stufe
-- liegt bei 160-206, egal ob sie 4 oder 12 Dreiecke kostet). "Teuer zu bauen" ist
-- also ein INVERTIERTES Signal - sortiert wird nach Wert pro Basis-Dreieck.
local VALUES = {}
pcall(function()
  if isfile and isfile("shapevalues.json") then
    local t = game:GetService("HttpService"):JSONDecode(readfile("shapevalues.json"))
    if type(t) == "table" then VALUES = t end
  end
end)
local RAW = VALUES.TRIANGLE or 5
T.values = VALUES

local function shapeValue(sh)
  if VALUES[sh] then return VALUES[sh] end
  -- ungemessen -> hoechstens so viel wert wie seine Zutaten. Nie auf Unbekanntes wetten.
  return costTotal(sh) * RAW
end

-- Wert pro eingesetztem Basis-Dreieck: das ist die Groesse, die maximiert werden muss
local function density(sh)
  local c = costTotal(sh)
  if c <= 0 then return 0 end
  return shapeValue(sh) / c
end
T.density = density

local _prods
local function prodList()
  if _prods then return _prods end
  _prods = {}
  for name in pairs(RECIPE) do _prods[#_prods+1]=name end
  table.sort(_prods, function(a,b) return density(a)>density(b) end)
  return _prods
end

-- lose Shapes am Boden nach Typ
local function scanGround()
  local inv = {}
  local parts = WS:FindFirstChild("Parts")
  for _, d in ipairs(parts and parts:GetChildren() or {}) do
    if isLooseShape(d) then
      local nm = d:GetAttribute("name") or d.Name
      inv[nm] = inv[nm] or {}
      inv[nm][#inv[nm]+1] = d
    end
  end
  return inv
end

-- Optimierer: teuerste Produkte zuerst, begrenzt durch Basis-Budget
local function optimize(budget)
  local b = {} for k,v in pairs(budget) do b[k]=v end
  local chosen = {}
  for _, P in ipairs(prodList()) do
    local c = baseCost(P)
    -- lohnt sich nur wenn die Shape mehr bringt als ihre Zutaten roh zu verkaufen
    if density(P) <= RAW then break end
    local maxN = math.huge
    for base,need in pairs(c) do maxN = math.min(maxN, math.floor((b[base] or 0)/need)) end
    if maxN > 0 and maxN < math.huge then
      chosen[P] = (chosen[P] or 0) + maxN
      for base,need in pairs(c) do b[base] = b[base] - need*maxN end
    end
  end
  return chosen
end

-- top-down: exakte Gesamtmenge jeder Shape (craftbar = zu produzieren, base = zu verbrauchen)
local function requirements(chosen)
  local need = {}
  local function add(sh, qty)
    need[sh] = (need[sh] or 0) + qty
    local r = RECIPE[sh]
    if r then for ing,per in pairs(r) do add(ing, per*qty) end end
  end
  for P,qty in pairs(chosen) do add(P, qty) end
  return need
end

-- bottom-up Reihenfolge: Shape erst craften wenn alle Zutaten fertig/base
local function schedule(need)
  local batches, done, remaining = {}, {}, {}
  for sh,q in pairs(need) do if not BASE[sh] then remaining[sh]=q end end
  local guard = 0
  while next(remaining) and guard < 200 do
    guard = guard + 1
    for sh,q in pairs(remaining) do
      local ready = true
      for ing in pairs(RECIPE[sh]) do
        if not BASE[ing] and not done[ing] then ready=false break end
      end
      if ready then
        batches[#batches+1] = { shape=sh, qty=q }
        done[sh]=true; remaining[sh]=nil
      end
    end
  end
  return batches
end

-- exakt N Shapes vom Typ auf den Input teleportieren
local function feedShapes(input, shapeName, count)
  local fed = 0
  local pool = scanGround()[shapeName] or {}
  for i = 1, math.min(count, #pool) do
    local sh = pool[i]
    pcall(function()
      net:FireServer("pickup", sh)
      sh:PivotTo(CFrame.new(input.Position + Vector3.new((i%3)*0.7-0.7, 1.4, (math.floor(i/3)%3)*0.7-0.7)))
      if sh.PrimaryPart then sh.PrimaryPart.AssemblyLinearVelocity = Vector3.zero end
    end)
    fed = fed + 1
    if fed % 25 == 0 then task.wait() end
  end
  return fed
end

local function countGround(name)
  local n = 0
  for _, d in ipairs((WS:FindFirstChild("Parts") and WS.Parts:GetChildren()) or {}) do
    if isLooseShape(d) and (d:GetAttribute("shape") or d:GetAttribute("name") or d.Name) == name then n = n + 1 end
  end
  return n
end

-- alle eigenen Crafter. Mehrere lohnen sich, weil Umwandlung und Ausgabe
-- pro Crafter laufen koennten (gemessen: ~90 Shapes/s Ausgabe bei einem).
-- Bei 24 Droppern sind das ~900 Shapes pro Runde - auf 3 Crafter verteilt
-- entsprechend schneller. Kosten pro Crafter: 50.
local function findCrafters()
  local out = {}
  local bp = WS:FindFirstChild("BuildingParts")
  if not bp then return out end
  for _, c in ipairs(bp:GetChildren()) do
    if string.find(c.Name, "Crafter") and c.PrimaryPart and c:FindFirstChild("Input")
       and (c:GetAttribute("placedBy") == nil or c:GetAttribute("placedBy") == lp.Name) then
      out[#out+1] = c
    end
  end
  return out
end
T.findCrafters = findCrafters

local function findCrafter()
  return findCrafters()[1]
end

-- Crafter-Inventar lesen (Server pusht {shape=count} beim Oeffnen)
local function readCrafterInv(crafter)
  local got = nil
  local cc = CrafterR.OnClientEvent:Connect(function(inv) got = inv end)
  CrafterR:FireServer(crafter, true)
  local t = 0
  while not got and t < 1.5 do task.wait(0.1); t = t + 0.1 end
  cc:Disconnect()
  CrafterR:FireServer(crafter, false)          -- sonst bleibt er serverseitig offen
  return type(got) == "table" and got or {}
end

-- ===== Crafter-Mechanik, in-game gemessen =====
-- 1. Ein Rezept zu SETZEN wandelt sofort das GESAMTE passende Inventar um, nicht
--    nur das gerade Gefuetterte: 264 Dreiecke wurden in unter 1s zu 70 Hexagons,
--    obwohl nur 16 gefuettert wurden.
-- 2. Eject dribbelt ueber mehrere Sekunden raus (264 Stueck ~ 3-4s), nicht sofort.
--    Genau daran ist die alte Batch-Logik gescheitert: sie hat nach 0.12s ein
--    Rezept gesetzt waehrend noch hunderte Dreiecke drin lagen.
-- 3. Boden-Shapes despawnen am Rundenende, das Crafter-Inventar ueberlebt sie.
-- Folge: einstufige Ketten brauchen weder Eject noch exakte Fuetterung.

local function invTotal(inv)
  local n = 0
  for _, v in pairs(inv) do n = n + v end
  return n
end

-- leeren und WARTEN bis wirklich leer (blindes task.wait war der Fehler)
local function drainCrafter(crafter, maxWait)
  EjectR:FireServer(crafter)
  local t0, last, stable = tick(), -1, 0
  while tick() - t0 < (maxWait or 15) do
    local n = invTotal(readCrafterInv(crafter))
    if n == 0 then return true end
    if n == last then
      stable = stable + 1
      if stable >= 2 then EjectR:FireServer(crafter); stable = 0 end
    else
      stable = 0
    end
    last = n
    task.wait(0.35)
  end
  return false
end

-- Rezept setzen -> gesamtes passendes Inventar wird sofort umgewandelt.
-- Bei mehreren Craftern allen dasselbe Rezept geben: sie wandeln parallel.
local function bulkConvertAll(shape, maxWait)
  local list = findCrafters()
  if #list == 0 then return 0 end
  local before = countGround(shape)
  for _, c in ipairs(list) do RecipesR:FireServer(c, { shape, 1 }) end
  local t0, last, stable = tick(), -1, 0
  while tick() - t0 < (maxWait or 6) do
    task.wait(0.25)
    local now = countGround(shape)
    if now > before then
      -- warten bis der Nachschub versiegt, nicht beim ersten Stueck aufhoeren
      if now == last then
        stable = stable + 1
        if stable >= 3 then break end
      else
        stable = 0
      end
    end
    last = now
  end
  return countGround(shape) - before
end

local function drainAll(maxWait)
  local ok = true
  for _, c in ipairs(findCrafters()) do
    if not drainCrafter(c, maxWait) then ok = false end
  end
  return ok
end

-- Kette von unten nach oben. nil, wenn ein Schritt mehr als EINE Zutat braucht:
-- solche Rezepte lassen sich per Massenumwandlung nicht dosieren.
local function chainOf(shape)
  local chain, cur, guard = {}, shape, 0
  while RECIPE[cur] and guard < 12 do
    guard = guard + 1
    local ings = {}
    for ing in pairs(RECIPE[cur]) do ings[#ings+1] = ing end
    if #ings ~= 1 then return nil end
    table.insert(chain, 1, cur)
    cur = ings[1]
  end
  if not BASE[cur] then return nil end
  return chain, cur
end

-- bestes massenwandelbares Ziel, nach Wert pro Basis-Dreieck
local function bestChainTarget()
  local best, bestD
  for name in pairs(RECIPE) do
    if chainOf(name) then
      local d = density(name)
      if d > RAW and (not bestD or d > bestD) then best, bestD = name, d end
    end
  end
  return best, bestD
end
T.bestChainTarget = bestChainTarget
T.chainOf = chainOf



-- einmaliger Verkaufs-Sweep (unabhaengig vom Auto-Seller-Toggle) -> alles Lose zum Seller
local function sellSweep(seconds)
  local sell = getSell()
  if not sell then return end
  local deadline = tick() + (seconds or 12)
  local i = 0
  while tick() < deadline do
    local any = false
    for _, list in pairs(scanGround()) do
      for _, sh in ipairs(list) do
        any = true
        i = i + 1
        pcall(function()
          net:FireServer("pickup", sh)
          sh:PivotTo(CFrame.new(dropPosFor(sell, i)))
        end)
        if i % 25 == 0 then task.wait() end
      end
    end
    if not any then break end
    task.wait(0.2)
  end
end

-- Storage: alle losen Boden-Shapes in den Crafter saugen (Rezept = nicht craftbar -> nur Speicher)
-- Reihum auf alle Crafter verteilen, damit kein einzelnes Lager zum Nadeloehr
-- wird und die spaetere Umwandlung parallel laufen kann.
local function vacuumToStorage(crafter)
  local list = findCrafters()
  if #list == 0 then
    if not crafter then return end
    list = { crafter }
  end
  local inputs = {}
  for _, c in ipairs(list) do
    local inp = c:FindFirstChild("Input")
    if inp then inputs[#inputs+1] = inp end
  end
  if #inputs == 0 then return end

  local i = 0
  for _, group in pairs(scanGround()) do
    for _, sh in ipairs(group) do
      i = i + 1
      local input = inputs[(i % #inputs) + 1]
      pcall(function()
        net:FireServer("pickup", sh)
        sh:PivotTo(CFrame.new(input.Position + Vector3.new((i%3)*0.7-0.7, 1.4, (math.floor(i/3)%3)*0.7-0.7)))
        if sh.PrimaryPart then sh.PrimaryPart.AssemblyLinearVelocity = Vector3.zero end
      end)
      if i % 25 == 0 then task.wait() end
    end
  end
end

function T.runCraftPlan()
  if T.craftBusy then return end
  T.craftBusy = true
  local crafters = findCrafters()
  if #crafters == 0 then T.craftMsg = "kein Crafter"; T.craftBusy = false; return end
  local crafter = crafters[1]

  -- was noch am Boden liegt zuerst einsammeln, sonst wird es nicht mitgewandelt
  T.craftMsg = "sammle Rest ein"
  pcall(vacuumToStorage, crafter)
  task.wait(0.6)

  -- Lagerbestand ueber ALLE Crafter zusammenzaehlen
  local tri, cir = 0, 0
  for _, c in ipairs(crafters) do
    local iv = readCrafterInv(c)
    tri = tri + (iv.TRIANGLE or 0)
    cir = cir + (iv.CIRCLE or 0)
  end
  T.lastBudget = "T=" .. tri .. " C=" .. cir .. " (" .. #crafters .. " Crafter)"
  local target, dens = bestChainTarget()

  if not target then
    T.craftMsg = "kein lohnendes Ziel -> roh verkaufen"
    log("kein Ziel besser als Rohverkauf; Lager " .. T.lastBudget)
    drainAll(5)
    pcall(sellSweep, 10)
    T.craftBusy = false
    return
  end

  local chain = chainOf(target)
  T.lastPlan  = table.concat(chain, " -> ") .. string.format("  (%.1f pro Dreieck)", dens)
  log("Ziel: " .. T.lastPlan .. "   Lager: " .. T.lastBudget)

  for i, step in ipairs(chain) do
    if not T.autoCraft and not T.craftManual then break end
    T.craftMsg = string.format("wandle %d/%d: %s", i, #chain, step)
    local ok, made = pcall(bulkConvertAll, step, 8)
    if not ok then
      log("FEHLER beim Umwandeln von " .. step .. ": " .. tostring(made))
      T.craftMsg = "Fehler: " .. tostring(made)
      break                      -- lieber roh verkaufen als gar nichts
    end
    log("  " .. step .. " -> " .. tostring(made) .. " Stueck")
    -- Zwischenstufe zurueck ins Lager, damit die naechste Stufe sie erfasst
    if i < #chain then
      pcall(vacuumToStorage, crafter)
      task.wait(0.6)
    end
  end

  -- unteilbare Reste rauswerfen und alles verkaufen
  T.craftMsg = "leere Lager"
  drainAll(5)
  T.craftMsg = "verkaufe"
  pcall(sellSweep, 10)

  -- Speicher wieder scharf: sonst steht der Crafter nach der Ernte auf dem
  -- Zielrezept und die naechste Sammelphase wandelt sofort einzeln um.
  for _, c in ipairs(findCrafters()) do
    RecipesR:FireServer(c, { T.storeRecipe, 1 })
  end

  T.craftMsg = "fertig"
  log("Ernte fertig + verkauft")
  T.craftBusy = false
end

-- Timer: letzte Sekunden der Runde erkennen (GameHUD.Time "12s")
local function roundTimeLeft()
  local gh = lp.PlayerGui:FindFirstChild("GameHUD")
  local tl = gh and gh:FindFirstChild("Time")
  if not tl then return nil end
  return tonumber(string.match(tl.Text, "%d+"))
end
local lastVacuum, lastHarvest = 0, 0

local function safeHarvest(tag)
  task.spawn(function()
    local ok, err = pcall(T.runCraftPlan)
    if not ok then
      log("runCraftPlan abgestuerzt (" .. tag .. "): " .. tostring(err))
      T.craftMsg = "Absturz -> Notverkauf"
      T.craftBusy = false
      pcall(sellSweep, 10)      -- auf keinen Fall ohne Verkauf enden
    end
  end)
end

T.conns[#T.conns+1] = RunService.Heartbeat:Connect(function()
  if not T.autoCraft or T.craftBusy then return end
  local state = WS:FindFirstChild("Map") and WS.Map:GetAttribute("state")
  if state ~= "playing" then
    T.craftedRound = false
    T.storeInit = false
    lastHarvest = 0
    return
  end
  local left = roundTimeLeft()
  if not left then return end

  local crafter = findCrafter()
  if not crafter then T.craftMsg = "kein Crafter" return end

  if not T.storeInit then
    -- HUMAN ist aus Dreiecken nicht craftbar -> der Crafter wird reiner Speicher.
    -- Muss auf JEDEM Crafter gesetzt werden, sonst lagern die anderen nichts ein.
    for _, c in ipairs(findCrafters()) do
      RecipesR:FireServer(c, { T.storeRecipe, 1 })
    end
    T.storeInit = true
    lastVacuum, lastHarvest = tick(), tick()
  end

  -- letzte Ernte der Runde
  if left <= T.craftLeadSec then
    if not T.craftedRound then
      T.craftedRound = true
      safeHarvest("final")
    end
    return
  end

  -- Zwischenernte: Batchgroesse aendert den Wert pro Dreieck nicht, also
  -- lieber mehrfach ernten als am Ende Shapes roh verkaufen zu muessen.
  if tick() - lastHarvest >= T.harvestEvery then
    lastHarvest = tick()
    safeHarvest("zwischen")
    return
  end

  T.craftMsg = "storage: sammle... " .. left .. "s"
  if not T.vacBusy and tick() - lastVacuum > 0.25 then
    lastVacuum = tick()
    T.vacBusy = true
    task.spawn(function() pcall(vacuumToStorage, crafter); T.vacBusy = false end)
  end
end)

-- ===== Auto-Build (kaufen + platzieren) =====
-- Automatic Dropper ist der einzige echte Einkommens-Multiplikator: jeder liefert
-- ~37.5 Shapes/Runde. Preis = 500 * 1.1^(bereits besessene Dropper), d.h. die ersten
-- ~12 amortisieren sich noch innerhalb EINER Runde. Crafter (50) wird zuerst
-- sichergestellt, sonst kann gar nicht gecraftet werden.
local BuyR = Remotes:WaitForChild("BoughtItem")
local InvR = Remotes:WaitForChild("Inventory")

T.autoBuild   = false
T.buyBuffer   = 0      -- keine Reserve: Cash ist zwischen den Runden nutzlos,
                       -- die Quota zaehlt Umsatz waehrend der Runde, nicht Kontostand
T.maxDroppers = math.huge  -- kein Deckel: der Kauf stoppt von selbst, sobald
                       -- das Geld nicht mehr reicht (Preis = 500 * 1.1^Anzahl)
T.wantCrafters= 3      -- Umwandlung/Ausgabe parallelisieren
T.wantCircleDroppers = 2  -- CIRCLE ist als Rohteil 34 wert (Dreieck: 5) und der
                       -- Circle Dropper kostet pauschal 3000. Ausserdem der
                       -- einzige Weg an CIRCLE zu kommen -> HUMAN-Zweig.
T.buildMsg    = "aus"
T.buildBusy   = false

local function cash() return lp:GetAttribute("Cash") or 0 end

local function myBuildings(match)
  local n, bp = 0, WS:FindFirstChild("BuildingParts")
  for _, m in ipairs(bp and bp:GetChildren() or {}) do
    if m:GetAttribute("placedBy") == lp.Name and string.find(m.Name, match) then n = n + 1 end
  end
  return n
end

local function inventoryCount(name)
  local ok, inv = pcall(function() return Remotes.GetOtherData:InvokeServer("Inventory") end)
  if ok and type(inv) == "table" then return inv[name] or 0 end
  return 0
end

local function groundAt(x, z)
  local p = RaycastParams.new()
  p.FilterType = Enum.RaycastFilterType.Exclude
  p.FilterDescendantsInstances = { WS.Live, WS:FindFirstChild("Parts"), WS:FindFirstChild("BuildingParts") }
  local r = WS:Raycast(Vector3.new(x, 150, z), Vector3.new(0, -400, 0), p)
  return r and r.Position.Y or nil
end

local function occupied(pos, radius)
  local bp = WS:FindFirstChild("BuildingParts")
  for _, m in ipairs(bp and bp:GetChildren() or {}) do
    if m:IsA("Model") and (m:GetPivot().Position - pos).Magnitude < radius then return true end
  end
  return false
end

-- freies Bodenfeld in einem Raster um den Spieler herum suchen
local function findSpot()
  local base = getRootPos()
  if not base then return nil end
  for ring = 1, 14 do          -- ohne Dropper-Deckel wird viel mehr Flaeche gebraucht
    for dx = -ring, ring do
      for dz = -ring, ring do
        if math.abs(dx) == ring or math.abs(dz) == ring then
          local x, z = base.X + dx * 8, base.Z + dz * 8
          local y = groundAt(x, z)
          if y then
            local pos = Vector3.new(x, y + 3, z)
            if not occupied(pos, 7) then return pos end
          end
        end
      end
    end
  end
end

local function placeItem(name, pos)
  local cf = CFrame.new(pos)
  local ok, model = InvR:InvokeServer("spawn", name, cf)
  if not ok or typeof(model) ~= "Instance" then return false end
  local t = os.clock()
  repeat task.wait() until model.PrimaryPart or os.clock() - t > 2
  if not model.PrimaryPart then return false end
  model.PrimaryPart.CFrame = cf
  model.PrimaryPart.Anchored = true
  model.PrimaryPart.AssemblyLinearVelocity = Vector3.zero
  net:FireServer("place", model, cf)
  task.wait(0.3)
  return true
end

-- alles was im Inventar liegt auch wirklich aufstellen
local function placeAllOf(name)
  local placed = 0
  for _ = 1, inventoryCount(name) do
    local spot = findSpot()
    if not spot then log("kein freier Bauplatz mehr"); break end
    if not placeItem(name, spot) then break end
    placed = placed + 1
  end
  return placed
end

function T.runBuild()
  if T.buildBusy then return end
  T.buildBusy = true

  -- 1. Crafter auffuellen. Mehrere, weil Umwandlung/Ausgabe pro Crafter laeuft
  --    und einer bei ~900 Shapes/Runde zum Nadeloehr wird. 50 pro Stueck.
  while myBuildings("Crafter") + inventoryCount("Crafter") < T.wantCrafters and cash() >= 50 do
    local ok, msg = BuyR:InvokeServer("Crafter", nil)
    log("kaufe Crafter -> " .. tostring(ok) .. " " .. tostring(msg))
    if not ok then break end
    task.wait(0.2)
  end
  if inventoryCount("Crafter") > 0 then
    T.buildMsg = "platziere Crafter"
    placeAllOf("Crafter")
  end

  -- 2. Circle Dropper: einziger CIRCLE-Lieferant und mit 3000 pauschal billiger
  --    als der n-te Automatic Dropper (500 * 1.1^n).
  while myBuildings("Circle Dropper") + inventoryCount("Circle Dropper") < T.wantCircleDroppers
        and cash() >= 3000 do
    local ok, msg = BuyR:InvokeServer("Circle Dropper", nil)
    log("kaufe Circle Dropper -> " .. tostring(ok) .. " " .. tostring(msg))
    if not ok then break end
    task.wait(0.2)
  end
  if inventoryCount("Circle Dropper") > 0 then
    T.buildMsg = "platziere Circle Dropper"
    placeAllOf("Circle Dropper")
  end

  -- 3. Dropper nachkaufen solange Cash reicht
  local bought = 0
  while cash() > T.buyBuffer and myBuildings("Dropper") + inventoryCount("Automatic Dropper") < T.maxDroppers do
    local before = cash()
    local ok, msg = BuyR:InvokeServer("Automatic Dropper", nil)
    if not ok then log("Dropper-Kauf gestoppt: " .. tostring(msg)) break end
    bought = bought + 1
    T.buildMsg = "gekauft: " .. bought .. " Dropper"
    log("Dropper #" .. bought .. " gekauft (" .. math.floor(before - cash()) .. "$)")
    task.wait(0.25)
  end

  -- 4. alles Gekaufte aufstellen
  local placed = placeAllOf("Automatic Dropper")
  T.buildMsg = string.format("%d Dropper gesamt", myBuildings("Dropper"))
  log("Auto-Build fertig: " .. bought .. " gekauft, " .. placed .. " platziert, "
      .. myBuildings("Dropper") .. " Dropper stehen jetzt")
  T.buildBusy = false
end

-- Bauen laeuft in BEIDEN Phasen. In Runde 1 liegt bereits ein Crafter im
-- Inventar: wer den erst in der Intermission aufstellt, verschenkt die
-- komplette erste Runde (roh verkaufen = 5 statt 40 pro Dreieck).
-- Auch Dropper lohnen sich mitten in der Runde, sie droppen sofort weiter.
local lastBuild = 0
T.conns[#T.conns+1] = RunService.Heartbeat:Connect(function()
  if not T.autoBuild or T.buildBusy then return end
  if tick() - lastBuild < 5 then return end
  lastBuild = tick()
  task.spawn(T.runBuild)
end)

-- ===== GUI =====
local gui = Instance.new("ScreenGui")
gui.Name = "ShapeToolGui"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = lp.PlayerGui

local frame = Instance.new("Frame")
frame.Size = UDim2.fromOffset(214, 300)
frame.Position = UDim2.fromScale(0.012, 0.45)
frame.BackgroundColor3 = Color3.fromRGB(20, 22, 28)
frame.BorderSizePixel = 0
frame.Active = true
frame.Draggable = true
frame.Parent = gui
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -12, 0, 20)
title.Position = UDim2.fromOffset(6, 4)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.TextSize = 13
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.Text = "Shape Tool"
title.Parent = frame

local function mkBtn(y, w, x)
  local b = Instance.new("TextButton")
  b.Size = UDim2.new(w or 1, (w and 0 or -12), 0, 30)
  b.Position = UDim2.fromOffset(x or 6, y)
  b.Font = Enum.Font.GothamBold
  b.TextSize = 13
  b.TextColor3 = Color3.fromRGB(255, 255, 255)
  b.BorderSizePixel = 0
  b.Parent = frame
  Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
  return b
end

local btn     = mkBtn(26)                                   -- Auto-Seller
local btnConv = mkBtn(60)                                   -- Auto-Conveyor
local btnAdd  = mkBtn(94, 0.62, 6)                          -- Zone setzen (links)
local btnClr  = mkBtn(94, 0, math.floor(214 * 0.62) + 2)    -- Zonen loeschen (rechts)
btnAdd.Size  = UDim2.fromOffset(126, 30)
btnAdd.Text  = "+ Zone setzen"
btnAdd.BackgroundColor3 = Color3.fromRGB(45, 70, 130)
btnClr.Size  = UDim2.fromOffset(70, 30)
btnClr.Position = UDim2.fromOffset(138, 94)
btnClr.Text  = "Clear"
btnClr.BackgroundColor3 = Color3.fromRGB(90, 55, 60)

local btnCraft = mkBtn(128)                                 -- Auto-Craft
local btnBuild = mkBtn(162)                                 -- Auto-Build

local status = Instance.new("TextLabel")
status.Size = UDim2.new(1, -12, 0, 20)
status.Position = UDim2.fromOffset(6, 198)
status.BackgroundTransparency = 1
status.Font = Enum.Font.Gotham
status.TextSize = 11
status.TextXAlignment = Enum.TextXAlignment.Left
status.TextColor3 = Color3.fromRGB(180, 185, 195)
status.Text = "verkauft: 0"
status.Parent = frame

local zoneStatus = Instance.new("TextLabel")
zoneStatus.Size = UDim2.new(1, -12, 0, 20)
zoneStatus.Position = UDim2.fromOffset(6, 220)
zoneStatus.BackgroundTransparency = 1
zoneStatus.Font = Enum.Font.Gotham
zoneStatus.TextSize = 11
zoneStatus.TextXAlignment = Enum.TextXAlignment.Left
zoneStatus.TextColor3 = Color3.fromRGB(150, 180, 220)
zoneStatus.Text = "Zonen: 0 | Conveyor aus"
zoneStatus.Parent = frame

local craftStatus = Instance.new("TextLabel")
craftStatus.Size = UDim2.new(1, -12, 0, 20)
craftStatus.Position = UDim2.fromOffset(6, 242)
craftStatus.BackgroundTransparency = 1
craftStatus.Font = Enum.Font.Gotham
craftStatus.TextSize = 11
craftStatus.TextXAlignment = Enum.TextXAlignment.Left
craftStatus.TextColor3 = Color3.fromRGB(220, 200, 140)
craftStatus.Text = "Craft: aus"
craftStatus.Parent = frame

local buildStatus = Instance.new("TextLabel")
buildStatus.Size = UDim2.new(1, -12, 0, 20)
buildStatus.Position = UDim2.fromOffset(6, 264)
buildStatus.BackgroundTransparency = 1
buildStatus.Font = Enum.Font.Gotham
buildStatus.TextSize = 11
buildStatus.TextXAlignment = Enum.TextXAlignment.Left
buildStatus.TextColor3 = Color3.fromRGB(150, 220, 170)
buildStatus.Text = "Build: aus"
buildStatus.Parent = frame

local function refresh()
  if T.autoSell then
    btn.Text = "Auto-Seller: AN  [F6]"
    btn.BackgroundColor3 = Color3.fromRGB(40, 160, 70)
  else
    btn.Text = "Auto-Seller: AUS  [F6]"
    btn.BackgroundColor3 = Color3.fromRGB(150, 45, 50)
  end
  if T.autoConveyor then
    btnConv.Text = "Auto-Conveyor: AN  [F7]"
    btnConv.BackgroundColor3 = Color3.fromRGB(40, 160, 70)
  else
    btnConv.Text = "Auto-Conveyor: AUS  [F7]"
    btnConv.BackgroundColor3 = Color3.fromRGB(150, 45, 50)
  end
  if T.autoCraft then
    btnCraft.Text = "Auto-Craft: SCHARF  [F9]"
    btnCraft.BackgroundColor3 = Color3.fromRGB(40, 160, 70)
  else
    btnCraft.Text = "Auto-Craft: AUS  [F9]"
    btnCraft.BackgroundColor3 = Color3.fromRGB(150, 45, 50)
  end
  if T.autoBuild then
    btnBuild.Text = "Auto-Build: AN  [F11]"
    btnBuild.BackgroundColor3 = Color3.fromRGB(40, 160, 70)
  else
    btnBuild.Text = "Auto-Build: AUS  [F11]"
    btnBuild.BackgroundColor3 = Color3.fromRGB(150, 45, 50)
  end
end

local function toggle()
  T.autoSell = not T.autoSell
  if not T.autoSell then T.active = {} end
  refresh()
  log("Auto-Seller " .. (T.autoSell and "AN" or "AUS"))
end

local function toggleConveyor()
  T.autoConveyor = not T.autoConveyor
  if T.autoConveyor then startConveyor() end
  refresh()
  log("Auto-Conveyor " .. (T.autoConveyor and "AN" or "AUS") .. " (" .. #T.zones .. " Zonen)")
end

local function toggleBuild()
  T.autoBuild = not T.autoBuild
  refresh()
  log("Auto-Build " .. (T.autoBuild and "AN (kauft/platziert in der Intermission)" or "AUS"))
end

local function toggleCraft()
  T.autoCraft = not T.autoCraft
  refresh()
  log("Auto-Craft " .. (T.autoCraft and "SCHARF (startet "..T.craftLeadSec.."s vor Rundenende)" or "AUS"))
end

-- Sofort-Run (fuer Test/manuell), unabhaengig vom Timer
function T.runManual()
  T.craftManual = true
  task.spawn(function() pcall(T.runCraftPlan); T.craftManual = false end)
end

btn.MouseButton1Click:Connect(toggle)
btnConv.MouseButton1Click:Connect(toggleConveyor)
btnAdd.MouseButton1Click:Connect(addZone)
btnClr.MouseButton1Click:Connect(clearZones)
btnCraft.MouseButton1Click:Connect(toggleCraft)
btnBuild.MouseButton1Click:Connect(toggleBuild)
T.conns[#T.conns+1] = UserInput.InputBegan:Connect(function(input, gpe)
  if gpe then return end
  if input.KeyCode == Enum.KeyCode.F6 then toggle()
  elseif input.KeyCode == Enum.KeyCode.F7 then toggleConveyor()
  elseif input.KeyCode == Enum.KeyCode.F8 then addZone()
  elseif input.KeyCode == Enum.KeyCode.F9 then toggleCraft()
  elseif input.KeyCode == Enum.KeyCode.F10 then T.runManual()       -- JETZT craften
  elseif input.KeyCode == Enum.KeyCode.F11 then toggleBuild()
  elseif input.KeyCode == Enum.KeyCode.F12 then task.spawn(T.runBuild) end  -- JETZT bauen
end)

-- Status-Update
local function fmt(v)
  v = math.floor((v or 0) + 0.5)
  if v >= 1e6 then return string.format("%.2fM", v/1e6)
  elseif v >= 1e3 then return string.format("%.1fk", v/1e3)
  else return tostring(v) end
end
T.conns[#T.conns+1] = RunService.Heartbeat:Connect(function()
  local cash = lp:GetAttribute("Cash")
  local n = 0 for _ in pairs(T.active) do n = n + 1 end
  status.Text = string.format("verkauft: %d | aktiv: %d | $%s", T.soldCount, n, fmt(cash))
  zoneStatus.Text = string.format("Zonen: %d | Conveyor %s | bewegt: %d",
    #T.zones, T.autoConveyor and "AN" or "aus", T.movedCount)
  craftStatus.Text = "Craft: " .. tostring(T.craftMsg)
  buildStatus.Text = "Build: " .. tostring(T.buildMsg)
end)

-- ===== destroy =====
function T.destroy()
  T.autoSell = false
  T.autoConveyor = false
  T.autoCraft = false
  T.autoBuild = false
  T.buildBusy = false
  T.craftManual = false
  T.storeInit = false
  T.vacBusy = false
  T.convToken = T.convToken + 1   -- laufenden Conveyor-Loop stoppen
  for _, c in ipairs(T.conns) do pcall(function() c:Disconnect() end) end
  T.conns = {}
  T.active = {}
  for _, z in ipairs(T.zones) do
    if z.marker then pcall(function() z.marker:Destroy() end) end
    if z.scr then pcall(function() z.scr:Destroy() end) end
  end
  T.zones = {}
  T.zoneByNum = {}
  if T.zoneGui then pcall(function() T.zoneGui:Destroy() end) end
  if gui then gui:Destroy() end
  _G.__ShapeTool = nil
end

refresh()
log("geladen. F6=Auto-Seller | F7=Auto-Conveyor | F8=Zone setzen | F9=Auto-Craft scharf | F10=Craft JETZT | F11=Auto-Build | F12=Bauen JETZT.")
log("Auto-Craft (F9 scharf): saugt die ganze Runde alle Shapes in den Crafter (Speicher, kein Despawn); in den letzten "..T.craftLeadSec.."s -> eject + wertoptimal craften + verkaufen. F10 = sofort testen.")
print("[ShapeTool] bereit — Auto-Seller Toggle (F6). Map.state aktuell: "
  .. tostring(WS:FindFirstChild("Map") and WS.Map:GetAttribute("state")))
