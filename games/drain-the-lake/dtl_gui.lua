--[[ Drain the Lake — Auto Farm GUI
     [Auto-Drain]   toggle: VDT_Bucket.Used-Loop (dyn. Tempo). Draint + Tokens automatisch.
     [Auto-Sell]    toggle: gibt am aktuellen Drain das Wasser ab (Pour) + sammelt Tokens. Kein TP.
     [Auto-Upgrade] toggle: kauft automatisch ALLE bezahlbaren Skill-Upgrades.
     [Alle Chests]  einmalig: oeffnet alle Chests (Diamanten), teleportiert dazu.
     Einfach im Executor ausfuehren. Gruen = an, Rot = aus.
]]--

local Players = game:GetService("Players")
local RS      = game:GetService("ReplicatedStorage")
local UIS     = game:GetService("UserInputService")
local vr      = RS:WaitForChild("VerdantRemotes")
local Used    = vr:FindFirstChild("VDT_Bucket.Used")
local ReqProf = vr:FindFirstChild("VDT_RequestProfile")
local Purchase= vr:FindFirstChild("VDT_SkillTree.Purchase")
local SL      = require(RS.Shared.Registry.SkillTreeLayouts)
local SE      = require(RS.Shared.Registry.SkillEffects)
local DC      = require(RS.Shared.Registry.DrainConfig)
local lp      = Players.LocalPlayer

-- ===== ZOMBIE-SICHER: globaler Generations-Zaehler =====
-- Jeder Loop prueft getgenv().DTL_GEN == MYGEN. Ein neuer Start erhoeht DTL_GEN,
-- wodurch ALLE aelteren Loops (dieser Bauart) sich sofort beenden.
local g = getgenv()
g.DTL_STOP = true
g.DTL_GEN  = (g.DTL_GEN or 0) + 1
local MYGEN = g.DTL_GEN
local S = { drain=false, sell=false, upgrade=false }
g.DTL = S
local function alive() return getgenv().DTL_GEN == MYGEN end

local BASE_CD = DC.VACUUM_USE_DELAY or 0.3

local function hrp() local c=lp.Character return c and c:FindFirstChild("HumanoidRootPart") end
local function prof() for _=1,3 do local ok,r=pcall(function() return ReqProf:InvokeServer() end) if ok and type(r)=="table" then return r end task.wait(0.06) end end
local function partOf(x) while x and not x:IsA("BasePart") do x=x.Parent end return x end
local function playing() return workspace:GetAttribute("RoundPhase")=="Playing" end
local function effCooldown(p)
  if not (p and p.SkillTree) then return BASE_CD end
  local ok,v=pcall(function() return SE.resolveNumber(p.SkillTree, SE.KEYS.SCOOP_COOLDOWN, BASE_CD) end)
  return (ok and type(v)=="number" and v>0) and v or BASE_CD
end

-- LERN-SELL: merkt sich die Prompts die DU manuell benutzt (Verkaufen=ProximityPosition,
-- Collecten=TakeTokens). Auto-Sell wiederholt genau diese. Verkaufst du woanders,
-- werden die neuen gelernt -> Auto-Sell springt darauf um.
local learnedPour, learnedTake
if g.DTL_SELLCONN then pcall(function() g.DTL_SELLCONN:Disconnect() end) end
g.DTL_SELLCONN = game:GetService("ProximityPromptService").PromptTriggered:Connect(function(prompt, plr)
  if plr~=lp then return end
  local pn = prompt.Parent and prompt.Parent.Name
  if pn=="ProximityPosition" then learnedPour=prompt
  elseif pn=="TakeTokens" then learnedTake=prompt end
end)

-- Upgrades: guenstigste bezahlbare erreichbare Node ueber ALLE Layer
local NB={{1,0},{-1,0},{0,1},{0,-1},{1,-1},{-1,1}}
local LAYERS={"buckets","root","character","diamonds"}
local function cheapestBuyable(p)
  local best
  for _,layer in ipairs(LAYERS) do
    local layout=SL.LAYOUTS[layer]
    if layout then
      local owned={} if p.SkillTree and p.SkillTree[layer] then for k in pairs(p.SkillTree[layer]) do owned[k]=true end end
      local tok=p.Tokens or 0
      for _,n in pairs(layout) do if type(n)=="table" and n.q and n.cost then
        local key=SL.coordKey(n.q,n.r)
        if not owned[key] and n.cost<=tok then
          for _,o in ipairs(NB) do if owned[SL.coordKey(n.q+o[1],n.r+o[2])] then
            if not best or n.cost<best.cost then best={layer=layer,q=n.q,r=n.r,cost=n.cost} end
            break
          end end
        end
      end end
    end
  end
  return best
end
local stat={scoops=0,sells=0,chests=0,upg=0,interval=BASE_CD,tokens="?"}
local function buyAll()
  local p=prof(); if not p then return end
  for _=1,25 do                       -- pro Durchlauf bis 25 Kaeufe
    local c=cheapestBuyable(p)
    if not c then break end
    local ok,r=pcall(function() return Purchase:InvokeServer(c.layer,c.q,c.r) end)
    if ok and type(r)=="table" and r.ok then stat.upg=stat.upg+1; p=prof() or p else break end
  end
end

-- ===== LOOPS =====
task.spawn(function()  -- AUTO-DRAIN
  local wait=BASE_CD local n=0
  while alive() do
    if S.drain and playing() then
      pcall(function() Used:FireServer() end)
      stat.scoops=stat.scoops+1 n=n+1
      if n%12==0 then local p=prof() if p then wait=math.max(0.05,effCooldown(p)+0.01) stat.interval=wait stat.tokens=p.Tokens end end
      task.wait(wait)
    else task.wait(0.15) end
  end
end)

task.spawn(function()  -- AUTO-SELL: wiederholt die von DIR zuletzt benutzten Prompts
  while alive() do
    if S.sell and playing() then
      if learnedPour and learnedPour.Parent then pcall(function() fireproximityprompt(learnedPour) end) end
      task.wait(0.06)
      if learnedTake and learnedTake.Parent then pcall(function() fireproximityprompt(learnedTake) end) end
      if learnedPour or learnedTake then stat.sells=stat.sells+1 end
    end
    task.wait(0.12)
  end
end)

task.spawn(function()  -- AUTO-UPGRADE (kauft alles, unabhaengig)
  while alive() do
    if S.upgrade and playing() then buyAll() end
    task.wait(1.0)
  end
end)

-- COLLECT ALL CHESTS (einmalig, per TP)
local seenChest={}
local chestBusy=false
local function collectAllChests()
  if chestBusy then return end chestBusy=true
  task.spawn(function()
    local h=hrp()
    local scripted=workspace:FindFirstChild("Scripted")
    local cf=scripted and scripted:FindFirstChild("Chests")
    if h and cf then
      local origin=h.CFrame
      for _,chest in ipairs(cf:GetChildren()) do
        if not alive() then break end
        if not seenChest[chest] then
          local pr for _,x in ipairs(chest:GetDescendants()) do if x:IsA("ProximityPrompt") and x.ActionText=="Open" then pr=x break end end
          local pt=pr and partOf(pr)
          if pr and pt then
            h.CFrame=CFrame.new(pt.Position+Vector3.new(0,3,3)); task.wait(0.16)
            pcall(function() fireproximityprompt(pr) end); task.wait(0.16)
            seenChest[chest]=true stat.chests=stat.chests+1
          end
        end
      end
      h.CFrame=origin
    end
    chestBusy=false
  end)
end

-- ===== GUI =====
local parent=(gethui and gethui()) or game:FindFirstChild("CoreGui") or lp:WaitForChild("PlayerGui")
local old=parent:FindFirstChild("DTL_GUI") if old then old:Destroy() end
local gui=Instance.new("ScreenGui") gui.Name="DTL_GUI" gui.ResetOnSpawn=false gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling gui.Parent=parent

local frame=Instance.new("Frame")
frame.Size=UDim2.fromOffset(232,255) frame.Position=UDim2.fromScale(0.04,0.26)
frame.BackgroundColor3=Color3.fromRGB(24,26,32) frame.BorderSizePixel=0 frame.Active=true frame.Parent=gui
Instance.new("UICorner",frame).CornerRadius=UDim.new(0,10)
local padd=Instance.new("UIPadding",frame) padd.PaddingTop=UDim.new(0,8) padd.PaddingLeft=UDim.new(0,8) padd.PaddingRight=UDim.new(0,8)
local layout=Instance.new("UIListLayout",frame) layout.Padding=UDim.new(0,7) layout.SortOrder=Enum.SortOrder.LayoutOrder

local title=Instance.new("TextLabel")
title.Size=UDim2.new(1,0,0,24) title.BackgroundTransparency=1 title.Text="Drain the Lake" title.TextColor3=Color3.fromRGB(120,200,255)
title.Font=Enum.Font.GothamBold title.TextSize=16 title.LayoutOrder=1 title.Parent=frame
local status=Instance.new("TextLabel")
status.Size=UDim2.new(1,0,0,34) status.BackgroundTransparency=1 status.TextColor3=Color3.fromRGB(175,175,185)
status.Font=Enum.Font.Gotham status.TextSize=11 status.TextWrapped=true status.LayoutOrder=2 status.Text="bereit" status.Parent=frame

local function mkBtn(order)
  local b=Instance.new("TextButton")
  b.Size=UDim2.new(1,0,0,36) b.AutoButtonColor=true b.TextColor3=Color3.fromRGB(240,240,240)
  b.Font=Enum.Font.GothamMedium b.TextSize=14 b.LayoutOrder=order b.BorderSizePixel=0 b.Parent=frame
  Instance.new("UICorner",b).CornerRadius=UDim.new(0,8)
  return b
end
local function setTog(b,on,label) b.BackgroundColor3=on and Color3.fromRGB(46,140,70) or Color3.fromRGB(150,55,55) b.Text=label..(on and ": AN" or ": AUS") end
local bDrain=mkBtn(3) local bSell=mkBtn(4) local bUpg=mkBtn(5) local bChest=mkBtn(6)
bChest.BackgroundColor3=Color3.fromRGB(45,48,58) bChest.Text="Alle Chests sammeln"
setTog(bDrain,S.drain,"Auto-Drain") setTog(bSell,S.sell,"Auto-Sell") setTog(bUpg,S.upgrade,"Auto-Upgrade")

bDrain.MouseButton1Click:Connect(function() S.drain=not S.drain setTog(bDrain,S.drain,"Auto-Drain") end)
bSell.MouseButton1Click:Connect(function() S.sell=not S.sell setTog(bSell,S.sell,"Auto-Sell") end)
bUpg.MouseButton1Click:Connect(function() S.upgrade=not S.upgrade setTog(bUpg,S.upgrade,"Auto-Upgrade") end)
bChest.MouseButton1Click:Connect(function() bChest.Text="sammle..." collectAllChests() task.delay(0.4,function() if bChest.Parent then bChest.Text="Alle Chests sammeln" end end) end)

do local dragging,dstart,pstart
frame.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then dragging=true dstart=i.Position pstart=frame.Position end end)
UIS.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then dragging=false end end)
UIS.InputChanged:Connect(function(i) if dragging and i.UserInputType==Enum.UserInputType.MouseMovement then local d=i.Position-dstart frame.Position=UDim2.new(pstart.X.Scale,pstart.X.Offset+d.X,pstart.Y.Scale,pstart.Y.Offset+d.Y) end end)
end

task.spawn(function()
  while gui.Parent and alive() do
    local sellState = (learnedPour or learnedTake) and "Sell-Ziel gelernt" or "Sell: 1x manuell verkaufen!"
    status.Text=("Scoops %d  Chests %d  Upg %d\nIntervall %.2fs  Tokens %s\n%s")
      :format(stat.scoops,stat.chests,stat.upg,stat.interval,tostring(stat.tokens),sellState)
    task.wait(0.7)
  end
  if gui and gui.Parent then gui:Destroy() end   -- alte GUI verschwindet wenn abgeloest
end)

return "dtl_gui geladen (zombiesicher, gen "..MYGEN..")"
