-- Elemental Magic Arena helper (PlaceId 7243409883)
-- Everything here was checked live against the server (2026-09-24):
--  * diamond pickups can be collected remotely via firetouchinterest (debounced, +1 each)
--  * element pads only CHECK the diamond amount (no cost) -> can be touched remotely from anywhere
--  * gifts / streak / spin / shop are server-validated (timer, "Too fast", price check)
-- Note: the game's Anti script kicks when a CoreGui descendant name contains "hub".

local G = getgenv()
if G.__EMA and G.__EMA.cleanup then pcall(G.__EMA.cleanup) end

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")
local VU = game:GetService("VirtualUser")
local lp = Players.LocalPlayer
local ls = lp:WaitForChild("leaderstats")

local ENV = { conns = {}, alive = true }
G.__EMA = ENV
local CFG = {
    collect = true,   -- auto diamond collector
    gifts = true,     -- claim playtime gifts + daily streak
    spin = true,      -- spend souls on the Magic Forge automatically
    antiafk = true,
    autoBest = false, -- always equip the best element you've unlocked
}
ENV.cfg = CFG
local CODES = { "140KLIKES" }

local function conn(c) table.insert(ENV.conns, c) return c end
local function hrp() local c = lp.Character return c and c:FindFirstChild("HumanoidRootPart") end
local function D() return ls.Diamonds.Value end

local function touch(part)
    local r = hrp()
    if not (r and part and part.Parent) then return false end
    firetouchinterest(r, part, 0)
    task.wait()
    firetouchinterest(r, part, 1)
    return true
end

---------------------------------------------------------------- diamonds
local stats = { picked = 0, gifts = 0, spins = 0 }
local function isPickup(d)
    return d:IsA("BasePart") and d.Parent == workspace and d.Name:find("Diamond") and d.Name ~= "FakeDiamond"
        and d:FindFirstChildOfClass("TouchTransmitter") ~= nil
end
local function grab(d)
    if not (CFG.collect and ENV.alive and isPickup(d)) then return end
    if touch(d) then stats.picked += 1 end
end
conn(workspace.ChildAdded:Connect(function(d)
    task.wait(0.1)
    grab(d)
end))
task.spawn(function()
    while ENV.alive do
        if CFG.collect then
            for _, d in ipairs(workspace:GetChildren()) do
                if isPickup(d) then grab(d) end
            end
        end
        task.wait(2)
    end
end)

---------------------------------------------------------------- gifts / streak / codes
local GF = RS:WaitForChild("GiftFolder")
task.spawn(function()
    for _, code in ipairs(CODES) do
        pcall(function() RS.ClaimCode:FireServer("CLAIM", code) end)
        task.wait(1)
    end
    while ENV.alive do
        if CFG.gifts then
            for i = 1, 9 do
                if not lp.ClaimedGifts:FindFirstChild(tostring(i)) then
                    local ok, r = pcall(GF.ClaimGift.InvokeServer, GF.ClaimGift, i)
                    if ok and r == true then stats.gifts += 1 end
                end
            end
            pcall(function()
                local s = GF.GetDayStreakData:InvokeServer()
                if s and (s.SecondsUntilNext or 1) <= 0 then GF.ClaimDayStreak:InvokeServer() end
            end)
        end
        task.wait(15)
    end
end)

---------------------------------------------------------------- auto spin
local SR = RS:WaitForChild("SpinRemotes")
task.spawn(function()
    while ENV.alive do
        if CFG.spin and ls.Souls.Value > 0 then
            local ok, r = pcall(SR.RequestSpin.InvokeServer, SR.RequestSpin)
            if ok and r and r.success then
                task.wait(2.2) -- the server rejects "Too fast" confirms
                pcall(SR.ConfirmSpin.InvokeServer, SR.ConfirmSpin)
                stats.spins += 1
                ENV.lastPrize = r.prizeName
            end
            task.wait(1)
        else
            task.wait(3)
        end
    end
end)

---------------------------------------------------------------- anti afk
conn(lp.Idled:Connect(function()
    if CFG.antiafk then
        VU:CaptureController()
        VU:ClickButton2(Vector2.new())
    end
end))

---------------------------------------------------------------- element pads
local function parseReq(t)
    t = tostring(t or ""):upper():gsub(",", "")
    local n, k = t:match("^([%d%.]+)(K?)$")
    if not n then return nil end
    return tonumber(n) * (k == "K" and 1000 or 1)
end

local BADGE = {}
pcall(function()
    for _, e in ipairs(require(RS.ElementConfig)) do
        if e.badge then BADGE[e.name:upper()] = true end
    end
end)

local PADS = {}
local function scanPads()
    table.clear(PADS)
    local titles = {}
    for _, b in ipairs(workspace:GetDescendants()) do
        if b:IsA("TextLabel") and b.Parent:IsA("BillboardGui") and b.Parent.Name == "Title" then
            local a = b.Parent.Parent
            local pos = a:IsA("Attachment") and a.WorldPosition or (a:IsA("BasePart") and a.Position)
            if pos then table.insert(titles, { pos = pos, text = b.Text }) end
        end
    end
    local function nameNear(p)
        local best, bd = "?", 30
        for _, t in ipairs(titles) do
            local d = (t.pos - p.Position).Magnitude
            if d < bd then bd, best = d, t.text end
        end
        return best
    end
    local function add(p)
        if not (p:IsA("BasePart") and p:FindFirstChildOfClass("TouchTransmitter")) then return end
        local req = 0
        local ra = p:FindFirstChild("REQUERAttachment")
        if p.Parent == workspace.TPS and not ra then return end
        local lbl = ra and ra:FindFirstChild("Requirements") and ra.Requirements:FindFirstChildOfClass("TextLabel")
        if lbl then
            req = parseReq(lbl.Text)
            if not req then return end -- badge-locked pad
        end
        local name = nameNear(p)
        if name == "?" or name:find("🏆") or name == "SHOP" or name == "Magic Forge" then return end
        if req == 0 and BADGE[name:upper()] then return end
        table.insert(PADS, { part = p, req = req, name = name })
    end
    for _, p in ipairs(workspace.TPS:GetChildren()) do add(p) end
    for _, p in ipairs(workspace:GetChildren()) do
        if p.Name == "teleporter" then add(p) end
    end
    table.sort(PADS, function(a, b) return a.req < b.req end)
end
scanPads()
ENV.pads = PADS

local function equip(pad) touch(pad.part) end
local function bestPad()
    local best
    for _, p in ipairs(PADS) do if p.req <= D() then best = p end end
    return best
end
ENV.equipBest = function() local b = bestPad() if b then equip(b) end return b end

task.spawn(function()
    local last
    while ENV.alive do
        if CFG.autoBest then
            local b = bestPad()
            if b and b ~= last then last = b equip(b) end
        end
        task.wait(5)
    end
end)

---------------------------------------------------------------- combat
-- Verified live: cooldowns + damage are server-side (spamming does nothing), but skills aim at the
-- client's Mouse.Hit and teleporting inside the arena is not punished. So: silent aim + sticky lock.
-- Poison (80 diamonds) Q aura = 5 dmg / 0.1 s around you -> 150 HP player dies in ~2 s while locked on.
local RunService = game:GetService("RunService")
CFG.silent = false   -- skills that read Mouse.Hit hit the target instead
CFG.lock = false     -- F: stick behind the target + auto attack
CFG.escape = true    -- flee to the lobby at low HP, come back when healed
CFG.dist = 4
CFG.escapeHP, CFG.backHP, CFG.arenaY = 45, 130, -80

local Mouse = lp:GetMouse()
local cam = workspace.CurrentCamera
local combat = { target = nil, aimPart = nil, escaping = false }
ENV.combat = combat

local rayp = RaycastParams.new()
rayp.FilterType = Enum.RaycastFilterType.Exclude
local function ground(pos)
    rayp.FilterDescendantsInstances = { lp.Character }
    return workspace:Raycast(pos + Vector3.new(0, 4, 0), Vector3.new(0, -60, 0), rayp)
end
local function alive(c)
    local h = c and c:FindFirstChildOfClass("Humanoid")
    return h and h.Health > 0 and c:FindFirstChild("HumanoidRootPart") and h
end
local function validTarget(p)
    if not p or p == lp or not p.Parent then return false end
    local c = p.Character
    if not alive(c) or c:FindFirstChildOfClass("ForceField") then return false end
    return c.HumanoidRootPart.Position.Y < CFG.arenaY
end
local function pickTarget()
    local r = hrp()
    if not r then return end
    local best, score
    for _, p in ipairs(Players:GetPlayers()) do
        if validTarget(p) then
            local c = p.Character
            local s = (c.HumanoidRootPart.Position - r.Position).Magnitude + c.Humanoid.Health * 0.5
            if not score or s < score then best, score = p, s end
        end
    end
    return best
end
local function cursorTarget()
    local m = UIS:GetMouseLocation()
    local best, bd = nil, 300
    for _, p in ipairs(Players:GetPlayers()) do
        if validTarget(p) then
            local sp, on = cam:WorldToViewportPoint(p.Character.HumanoidRootPart.Position)
            if on then
                local d = (Vector2.new(sp.X, sp.Y) - m).Magnitude
                if d < bd then best, bd = p, d end
            end
        end
    end
    return best
end

-- silent aim: only answers game scripts (checkcaller), falls through once this instance is cleaned up
local oldIndex
oldIndex = hookmetamethod(game, "__index", newcclosure(function(self, key)
    if ENV.alive and CFG.silent and rawequal(self, Mouse) and not checkcaller() then
        local part = combat.aimPart
        if part and part.Parent then
            if key == "Hit" or key == "hit" then
                return CFrame.new(part.Position + part.AssemblyLinearVelocity * 0.12)
            elseif key == "Target" or key == "target" then
                return part
            end
        end
    end
    return oldIndex(self, key)
end))

local function safeSpot()
    for _, s in ipairs(workspace:GetDescendants()) do
        if s:IsA("SpawnLocation") and s.Position.Y > CFG.arenaY then return s.Position + Vector3.new(0, 4, 0) end
    end
end

conn(RunService.Heartbeat:Connect(function()
    local r = hrp()
    local h = r and alive(lp.Character)
    if not h then return end

    if CFG.lock and not validTarget(combat.target) then combat.target = pickTarget() end
    local aim = (CFG.lock and validTarget(combat.target) and combat.target) or cursorTarget()
    combat.aimPart = aim and aim.Character.HumanoidRootPart or nil

    -- low-HP escape
    if CFG.escape and CFG.lock then
        if not combat.escaping and h.Health < CFG.escapeHP then
            local s = safeSpot()
            if s then combat.escaping = true r.CFrame = CFrame.new(s) end
        elseif combat.escaping and h.Health >= CFG.backHP then
            combat.escaping = false
        end
    end
    if combat.escaping or not CFG.lock then return end

    local t = combat.target
    if not validTarget(t) then return end
    local tr = t.Character.HumanoidRootPart
    local want = tr.Position - tr.CFrame.LookVector * CFG.dist
    if ground(want) then
        r.CFrame = CFrame.lookAt(want, Vector3.new(tr.Position.X, want.Y, tr.Position.Z))
        r.AssemblyLinearVelocity = Vector3.zero
    end
end))

-- auto attack while locked: M1 + no-arg ability remotes (server enforces cooldowns, extra fires are ignored)
local ABILITY = { Qevent = true, Q = true, QAbility = true, Ability2 = true, EAbility = true, Eability = true, EE = true }
task.spawn(function()
    local lastAbility = 0
    while ENV.alive do
        local ch = lp.Character
        if CFG.lock and not combat.escaping and ch and alive(ch) and validTarget(combat.target) then
            local tool = ch:FindFirstChildOfClass("Tool")
            if not tool or tool.Name == "CameraShake" then
                for _, t in ipairs(lp.Backpack:GetChildren()) do
                    if t:IsA("Tool") and t.Name ~= "CameraShake" then ch.Humanoid:EquipTool(t) tool = t break end
                end
            end
            local d = (combat.target.Character.HumanoidRootPart.Position - hrp().Position).Magnitude
            if tool and d < 20 then
                pcall(function() tool:Activate() end)
                if os.clock() - lastAbility > 1 then
                    lastAbility = os.clock()
                    for _, t in ipairs({ tool, unpack(lp.Backpack:GetChildren()) }) do
                        for _, rmt in ipairs(t:GetChildren()) do
                            if rmt:IsA("RemoteEvent") and ABILITY[rmt.Name] then pcall(rmt.FireServer, rmt) end
                        end
                    end
                end
            end
        end
        task.wait(0.2)
    end
end)

-- void guard (a lot of the map has no floor)
task.spawn(function()
    while ENV.alive do
        local r = hrp()
        if r and r.Position.Y < -400 then
            local s = safeSpot()
            if s then r.CFrame = CFrame.new(s) r.AssemblyLinearVelocity = Vector3.zero end
        end
        task.wait(0.25)
    end
end)

---------------------------------------------------------------- GUI
local gui = Instance.new("ScreenGui")
gui.Name = "EMAPanel"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
local ok = pcall(function() gui.Parent = (gethui and gethui()) or game:GetService("CoreGui") end)
if not ok then gui.Parent = lp:WaitForChild("PlayerGui") end
ENV.gui = gui

local C = {
    bg = Color3.fromRGB(22, 22, 30), panel = Color3.fromRGB(32, 32, 44),
    on = Color3.fromRGB(60, 190, 110), off = Color3.fromRGB(70, 70, 88),
    text = Color3.fromRGB(235, 235, 245), dim = Color3.fromRGB(150, 150, 170),
    accent = Color3.fromRGB(110, 170, 255),
}
local function mk(cls, props, parent)
    local o = Instance.new(cls)
    for k, v in pairs(props) do o[k] = v end
    o.Parent = parent
    return o
end
local function round(o, r) mk("UICorner", { CornerRadius = UDim.new(0, r or 6) }, o) end

local main = mk("Frame", {
    Size = UDim2.fromOffset(300, 560), Position = UDim2.new(0, 20, 0.5, -280),
    BackgroundColor3 = C.bg, BorderSizePixel = 0, Active = true,
}, gui)
round(main, 10)
local top = mk("TextLabel", {
    Size = UDim2.new(1, 0, 0, 34), BackgroundColor3 = C.panel, BorderSizePixel = 0,
    Text = "  Elemental Arena  ·  RightShift", TextXAlignment = Enum.TextXAlignment.Left,
    Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = C.text,
}, main)
round(top, 10)

-- drag
do
    local dragging, start, startPos
    conn(top.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging, start, startPos = true, i.Position, main.Position
        end
    end))
    conn(UIS.InputChanged:Connect(function(i)
        if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then
            local d = i.Position - start
            main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end))
    conn(UIS.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end))
end
conn(UIS.InputBegan:Connect(function(i, gp)
    if not gp and i.KeyCode == Enum.KeyCode.RightShift then main.Visible = not main.Visible end
end))

local status = mk("TextLabel", {
    Size = UDim2.new(1, -20, 0, 36), Position = UDim2.fromOffset(10, 40), BackgroundTransparency = 1,
    Font = Enum.Font.Gotham, TextSize = 13, TextColor3 = C.dim, TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Top, Text = "",
}, main)

local y = 80
local function toggle(label, key)
    local b = mk("TextButton", {
        Size = UDim2.new(1, -20, 0, 26), Position = UDim2.fromOffset(10, y), BorderSizePixel = 0,
        Font = Enum.Font.GothamSemibold, TextSize = 13, TextColor3 = C.text, AutoButtonColor = false,
    }, main)
    round(b)
    local function paint()
        b.Text = label .. (CFG[key] and "  ✔" or "  ✖")
        b.BackgroundColor3 = CFG[key] and C.on or C.off
    end
    paint()
    conn(b.MouseButton1Click:Connect(function() CFG[key] = not CFG[key] paint() end))
    y += 30
    return paint
end
toggle("Auto-collect diamonds", "collect")
toggle("Auto gifts + daily streak", "gifts")
toggle("Auto spin (souls)", "spin")
toggle("Auto best element", "autoBest")
toggle("Anti-AFK", "antiafk")
toggle("Silent aim (Mouse.Hit -> target)", "silent")
local paintLock = toggle("Target lock + auto attack  [F]", "lock")
toggle("Escape to lobby at low HP", "escape")
conn(UIS.InputBegan:Connect(function(i, gp)
    if not gp and i.KeyCode == Enum.KeyCode.F then
        CFG.lock = not CFG.lock
        if not CFG.lock then combat.target = nil combat.escaping = false end
        paintLock()
    end
end))

mk("TextLabel", {
    Size = UDim2.new(1, -20, 0, 18), Position = UDim2.fromOffset(10, y + 2), BackgroundTransparency = 1,
    Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = C.accent, TextXAlignment = Enum.TextXAlignment.Left,
    Text = "Elements (click = equip from anywhere)",
}, main)
y += 22
local list = mk("ScrollingFrame", {
    Size = UDim2.new(1, -20, 1, -(y + 10)), Position = UDim2.fromOffset(10, y), BackgroundColor3 = C.panel,
    BorderSizePixel = 0, ScrollBarThickness = 5, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
}, main)
round(list)
mk("UIListLayout", { Padding = UDim.new(0, 3) }, list)
mk("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 8) }, list)

local rows = {}
for _, p in ipairs(PADS) do
    local b = mk("TextButton", {
        Size = UDim2.new(1, 0, 0, 24), BorderSizePixel = 0, Font = Enum.Font.Gotham, TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.text, AutoButtonColor = true,
        Text = ("  %s  ·  %s💎"):format(p.name, p.req >= 1000 and (p.req / 1000 .. "K") or tostring(p.req)),
    }, list)
    round(b, 4)
    conn(b.MouseButton1Click:Connect(function() equip(p) end))
    table.insert(rows, { b = b, p = p })
end

task.spawn(function()
    while ENV.alive do
        local d = D()
        for _, r in ipairs(rows) do
            r.b.BackgroundColor3 = r.p.req <= d and Color3.fromRGB(40, 90, 60) or Color3.fromRGB(55, 40, 45)
        end
        local nxt
        for _, p in ipairs(PADS) do if p.req > d then nxt = p break end end
        local t = combat.target
        local th = t and t.Character and t.Character:FindFirstChildOfClass("Humanoid")
        local tinfo = (combat.escaping and "ESCAPING (healing)")
            or (CFG.lock and th and ("target " .. t.Name .. " " .. math.floor(th.Health) .. "hp"))
            or (nxt and ("next: " .. nxt.name .. " (" .. (nxt.req - d) .. ")")) or ""
        status.Text = ("💎 %d   Souls %d   🏆 %d\npicked %d · gifts %d · spins %d  ·  %s"):format(
            d, ls.Souls.Value, ls.Trophies.Value, stats.picked, stats.gifts, stats.spins, tinfo)
        task.wait(1)
    end
end)

ENV.stats = stats
ENV.cleanup = function()
    ENV.alive = false
    for _, c in ipairs(ENV.conns) do pcall(function() c:Disconnect() end) end
    pcall(function() gui:Destroy() end)
end

print(("[EMA] loaded · %d element pads · diamonds %d"):format(#PADS, D()))
