--!nocheck
--=====================================================================
--  AUTO CRAFT & SELL  --  shape carrier bot
--  PlaceId 73648930852061
--
--  Loop:  loose shape   -> flown into your Crafter's Input
--         crafted shape -> flown onto the Sell pad
--
--  Your character is never moved. Only the shapes fly.
--=====================================================================

if _G.__AutoCraftSell then pcall(_G.__AutoCraftSell.destroy) end

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService  = game:GetService("UserInputService")

local plr        = Players.LocalPlayer
local Remotes    = ReplicatedStorage:WaitForChild("Remotes")
local Net        = Remotes:WaitForChild("Network")
local CrafterRem = Remotes:WaitForChild("Crafter")

--=====================================================================
-- CONFIG
--=====================================================================
-- carry "speed" = AlignPosition responsiveness (vanilla uses 150)
local SPEEDS = {
    { name = "fast",   v = 200 },
    { name = "normal", v = 150 },
    { name = "gentle", v = 60  },
}
local CARRY_FORCE = 2500000   -- same as the vanilla grab force

local CFG = {
    running     = false,
    crafter     = nil,     -- Model      | nil = nearest of yours
    sellPart    = nil,     -- BasePart   | nil = nearest
    outputShape = nil,     -- string     | nil = auto-detect from the crafter recipe
    inputShapes = {},      -- set[name]  | empty = feed every shape
    speedIndex  = 2,       -- index into SPEEDS
    maxAtOnce   = 3,       -- shapes in flight simultaneously
    reach       = 14,      -- server only accepts a pickup this close to you
    scanRadius  = 150,     -- how far out to look for shapes worth fetching
    sellFirst   = true,    -- clear the crafter output before feeding more in
    rawSell     = false,   -- true = ignore crafters, fly everything straight to the pad
}

local SCANS = { 40, 80, 150, 300, 600 }

local SHAPE_NAMES = {}
do
    local folder = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Parts"):WaitForChild("Shapes")
    for _, m in ipairs(folder:GetChildren()) do
        if m:IsA("Model") then SHAPE_NAMES[#SHAPE_NAMES + 1] = m.Name end
    end
    table.sort(SHAPE_NAMES)
end

--=====================================================================
-- WORLD HELPERS
--=====================================================================
local function getHRP()
    local c = plr.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function shapeFolders()
    local t = {}
    if workspace:FindFirstChild("Parts")       then t[#t+1] = workspace.Parts end
    if workspace:FindFirstChild("Shapesother") then t[#t+1] = workspace.Shapesother end
    return t
end

local function isAlive(o)
    return o
       and o.Parent
       and o.PrimaryPart
       and o:GetAttribute("type") == "part"
       and not o:GetAttribute("destroyed")
       and not o:GetAttribute("sold")
end

local function gone(o)
    return (not o.Parent) or o:GetAttribute("destroyed") or o:GetAttribute("sold")
end

local function shapeNameOf(o)
    return o:GetAttribute("shape") or o:GetAttribute("name") or o.Name
end

-- placed buildings are shared between players, so filter by owner
local function findCrafters()
    local t = {}
    for _, m in ipairs(workspace.BuildingParts:GetChildren()) do
        if m:IsA("Model") and string.find(m.Name, "Crafter")
           and m:FindFirstChild("Input") then
            local by = m:GetAttribute("placedBy")
            if by == nil or by == plr.Name then t[#t+1] = m end
        end
    end
    return t
end

local function findSellParts()
    local t = {}
    local function scan(folder)
        if not folder then return end
        for _, m in ipairs(folder:GetChildren()) do
            if m:IsA("Model") then
                local s = m:FindFirstChild("Sell")
                if s and s:IsA("BasePart") then t[#t+1] = s end
            end
        end
    end
    scan(workspace.BuildingParts)
    scan(workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("BuildingParts"))
    return t
end

local function nearestTo(list, pos, posOf)
    local best, bd
    for _, v in ipairs(list) do
        local d = (posOf(v) - pos).Magnitude
        if not bd or d < bd then best, bd = v, d end
    end
    return best
end

local function activeCrafter()
    if CFG.crafter and CFG.crafter.Parent and CFG.crafter:FindFirstChild("Input") then
        return CFG.crafter
    end
    CFG.crafter = nil
    local hrp = getHRP(); if not hrp then return nil end
    return nearestTo(findCrafters(), hrp.Position, function(m) return m:GetPivot().Position end)
end

local function activeSell()
    if CFG.sellPart and CFG.sellPart.Parent then return CFG.sellPart end
    CFG.sellPart = nil
    local hrp = getHRP(); if not hrp then return nil end
    return nearestTo(findSellParts(), hrp.Position, function(p) return p.Position end)
end

--=====================================================================
-- TRANSPORT
--   Two things have to be true for a shape to be accepted by the crafter
--   Input or the Sell pad:
--
--   1. The server must consider the shape held by us.  That needs
--      Network:FireServer("pickup", shape) while the shape is inside its
--      range check (~14 studs from your character), replayed for the
--      first few frames plus a "general" ping every ~0.2s -- exactly what
--      the vanilla client does.
--   2. The shape has to *arrive* under physics.  Writing CFrame teleports
--      it without generating a Touched event, so the pad never fires.  We
--      drag it with an AlignPosition, same as the vanilla grab.
--=====================================================================
local inFlight = {}          -- [Model] = true
local flightCount = 0
local STATUS = "idle"
local stats = { fed = 0, sold = 0, failed = 0 }

-- fly up, across, then down, so shapes don't grind along walls
local function waypoint(cur, dest)
    local flat = Vector3.new(dest.X - cur.X, 0, dest.Z - cur.Z)
    if flat.Magnitude > 7 then
        return Vector3.new(dest.X, math.max(cur.Y, dest.Y) + 7, dest.Z)
    end
    return dest
end

local function transport(o, getDest, timeout)
    local pp = o.PrimaryPart
    if not pp then return false end

    inFlight[o] = true
    flightCount += 1

    -- Shapes are ours to move, so this is just two teleports:
    -- snap it next to you (so the server's pickup range check passes),
    -- claim it, then snap it onto the target and hold it there.
    local hrp = getHRP()
    if hrp then
        pp.CFrame = CFrame.new(hrp.Position + Vector3.new(0, 3, 0))
        RunService.Heartbeat:Wait()
    end
    Net:FireServer("pickup", o)

    local frame, lastGeneral = 0, 0
    local conn = RunService.Heartbeat:Connect(function()
        if not o.Parent or not o.PrimaryPart then return end
        local dest = getDest()
        if dest then
            local p = o.PrimaryPart
            p.AssemblyLinearVelocity  = Vector3.zero
            p.AssemblyAngularVelocity = Vector3.zero
            -- tiny bob: a part held perfectly still can stop re-firing Touched
            p.CFrame = CFrame.new(dest + Vector3.new(0, (frame % 2) * 0.2, 0))
        end

        frame += 1
        if frame <= 4 then Net:FireServer("pickup", o) end
        if os.clock() - lastGeneral >= 0.15 then
            lastGeneral = os.clock()
            Net:FireServer("general", o)
        end
    end)

    local t0 = os.clock()
    while os.clock() - t0 < timeout do
        if gone(o) then break end
        if not CFG.running then break end
        task.wait(0.03)
    end
    conn:Disconnect()

    local ok = gone(o)
    if not ok and o.Parent then pcall(function() Net:FireServer("drop", o) end) end
    inFlight[o] = nil
    flightCount -= 1
    return ok
end

--=====================================================================
-- RECIPE DETECTION
--   Opening a crafter server-side replies with (inventory, grid, item);
--   `item` is the currently selected recipe, e.g. "BIG TRIANGLE" or
--   "SQUARE_2".  We open and immediately close it again.
--=====================================================================
local function detectOutputShape(crafter)
    if not crafter then return nil end
    local result, done
    local conn = CrafterRem.OnClientEvent:Connect(function(_, _, item)
        result, done = item, true
    end)
    pcall(function() CrafterRem:FireServer(crafter, true) end)
    local t0 = os.clock()
    while not done and os.clock() - t0 < 2 do task.wait(0.05) end
    conn:Disconnect()
    pcall(function() CrafterRem:FireServer(crafter, false) end)
    if type(result) == "string" then return (string.split(result, "_"))[1] end
    return nil
end

--=====================================================================
-- MAIN LOOP
--=====================================================================
local UI  -- forward decl

local function wantsInput(name, outName)
    if outName and name == outName then return false end
    if next(CFG.inputShapes) == nil then return true end
    return CFG.inputShapes[name] == true
end

local function collect(hrp, predicate, limit)
    local found = {}
    for _, folder in ipairs(shapeFolders()) do
        for _, o in ipairs(folder:GetChildren()) do
            -- note: "carried" is sticky (it stays true after a drop), so the
            -- held-by-someone flag to test is "owner"
            if o:IsA("Model") and not inFlight[o] and isAlive(o)
               and not o:GetAttribute("owner") and predicate(o) then
                if (o:GetPivot().Position - hrp.Position).Magnitude <= CFG.scanRadius then
                    found[#found+1] = o
                    if #found >= limit then return found end
                end
            end
        end
    end
    return found
end

local function mainLoop()
    while CFG.running do
        local ok, err = pcall(function()
            local hrp = getHRP()
            if not hrp then STATUS = "waiting for character" task.wait(0.5) return end

            local map   = workspace:FindFirstChild("Map")
            local state = map and map:GetAttribute("state")
            if state ~= "playing" then
                STATUS = "waiting for round (" .. tostring(state) .. ")"
                task.wait(0.75) return
            end

            local sell = activeSell()
            if not sell then STATUS = "no sell pad found" task.wait(1) return end

            local sellDest = function()
                local s = activeSell()
                if not s then return nil end
                return s.Position + Vector3.new(0, s.Size.Y / 2 + 1.2, 0)
            end

            local slots = CFG.maxAtOnce - flightCount
            if slots <= 0 then task.wait(0.05) return end

            -- No crafter yet (or crafting disabled): just sell everything.
            local crafter = CFG.rawSell and nil or activeCrafter()
            if not crafter then
                local raw = collect(hrp, function() return true end, slots)
                for _, o in ipairs(raw) do
                    task.spawn(function()
                        if transport(o, sellDest, 5) then stats.sold += 1 else stats.failed += 1 end
                    end)
                end
                STATUS = #raw > 0 and "selling raw shapes"
                       or (flightCount > 0 and ("carrying " .. flightCount) or "no shapes in range")
                task.wait(0.1)
                return
            end

            local outName = CFG.outputShape
            if not outName then
                STATUS = "reading crafter recipe..."
                outName = detectOutputShape(crafter)
                if outName then CFG.outputShape = outName if UI then UI.refresh() end end
                if not outName then task.wait(1) return end
            end

            local feedDest = function()
                local c = activeCrafter()
                local i = c and c:FindFirstChild("Input")
                return i and i.Position or nil
            end

            -- 1) crafted shapes first so the output never backs up
            local outs = collect(hrp, function(o) return shapeNameOf(o) == outName end, slots)
            for _, o in ipairs(outs) do
                task.spawn(function()
                    if transport(o, sellDest, 5) then stats.sold += 1 else stats.failed += 1 end
                end)
            end
            slots -= #outs
            if CFG.sellFirst and #outs > 0 then
                STATUS = "selling " .. outName
                task.wait(0.05)
                return
            end

            -- 2) then feed the crafter
            if slots > 0 then
                local ins = collect(hrp, function(o) return wantsInput(shapeNameOf(o), outName) end, slots)
                for _, o in ipairs(ins) do
                    task.spawn(function()
                        if transport(o, feedDest, 5) then stats.fed += 1 else stats.failed += 1 end
                    end)
                end
                if #ins > 0 then STATUS = "feeding crafter" task.wait(0.05) return end
            end

            if flightCount > 0 then
                STATUS = "carrying " .. flightCount .. " shape(s)"
            else
                local total = 0
                for _, folder in ipairs(shapeFolders()) do
                    for _, o in ipairs(folder:GetChildren()) do
                        if o:IsA("Model") and isAlive(o) then total += 1 end
                    end
                end
                STATUS = total > 0
                    and ("no shape in range (" .. total .. " on the map)")
                    or  "no shapes on the map"
            end
            task.wait(0.15)
        end)
        if not ok then STATUS = "error: " .. tostring(err) task.wait(0.5) end
        task.wait()
    end
    STATUS = "stopped"
end

--=====================================================================
-- GUI
--=====================================================================
local C = {
    bg     = Color3.fromRGB(22, 24, 30),
    bg2    = Color3.fromRGB(31, 34, 42),
    bg3    = Color3.fromRGB(44, 48, 58),
    accent = Color3.fromRGB(88, 166, 255),
    good   = Color3.fromRGB(70, 200, 110),
    bad    = Color3.fromRGB(230, 80, 80),
    text   = Color3.fromRGB(232, 236, 244),
    dim    = Color3.fromRGB(150, 158, 172),
}

local function new(class, props, parent)
    local i = Instance.new(class)
    for k, v in pairs(props or {}) do i[k] = v end
    if parent then i.Parent = parent end
    return i
end
local function corner(p, r) new("UICorner", { CornerRadius = UDim.new(0, r or 6) }, p) end

local gui = new("ScreenGui", {
    Name = "AutoCraftSell",
    ResetOnSpawn = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, (gethui and gethui()) or plr:WaitForChild("PlayerGui"))

local root = new("Frame", {
    Size = UDim2.fromOffset(330, 476),
    Position = UDim2.new(0, 24, 0.5, -224),
    BackgroundColor3 = C.bg, BorderSizePixel = 0,
    Active = true, Draggable = true,
}, gui)
corner(root, 10)
new("UIStroke", { Color = Color3.fromRGB(60, 66, 80), Thickness = 1 }, root)

local header = new("Frame", {
    Size = UDim2.new(1, 0, 0, 36), BackgroundColor3 = C.bg2, BorderSizePixel = 0,
}, root)
corner(header, 10)
new("Frame", { Size = UDim2.new(1, 0, 0, 10), Position = UDim2.new(0, 0, 1, -10),
               BackgroundColor3 = C.bg2, BorderSizePixel = 0 }, header)

new("TextLabel", {
    Size = UDim2.new(1, -70, 1, 0), Position = UDim2.fromOffset(12, 0),
    BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 14,
    TextColor3 = C.text, TextXAlignment = Enum.TextXAlignment.Left,
    Text = "Auto Craft & Sell",
}, header)

local minBtn = new("TextButton", {
    Size = UDim2.fromOffset(26, 22), Position = UDim2.new(1, -60, 0, 7),
    BackgroundColor3 = C.bg3, BorderSizePixel = 0, Text = "–",
    Font = Enum.Font.GothamBold, TextSize = 15, TextColor3 = C.text,
}, header)
corner(minBtn, 5)

local closeBtn = new("TextButton", {
    Size = UDim2.fromOffset(26, 22), Position = UDim2.new(1, -31, 0, 7),
    BackgroundColor3 = C.bg3, BorderSizePixel = 0, Text = "X",
    Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = C.bad,
}, header)
corner(closeBtn, 5)

local body = new("Frame", {
    Size = UDim2.new(1, -20, 1, -46), Position = UDim2.fromOffset(10, 40),
    BackgroundTransparency = 1,
}, root)
new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, body)

local order = 0
local function nextOrder() order += 1 return order end

local statusLbl = new("TextLabel", {
    Size = UDim2.new(1, 0, 0, 34), BackgroundColor3 = C.bg2, BorderSizePixel = 0,
    Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = C.dim,
    Text = "idle", TextWrapped = true, LayoutOrder = nextOrder(),
}, body)
corner(statusLbl, 6)

local startBtn = new("TextButton", {
    Size = UDim2.new(1, 0, 0, 34), BackgroundColor3 = C.good, BorderSizePixel = 0,
    Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = Color3.new(1, 1, 1),
    Text = "START", LayoutOrder = nextOrder(),
}, body)
corner(startBtn, 6)

local function rowButton(label, layout)
    local f = new("Frame", {
        Size = UDim2.new(1, 0, 0, 26), BackgroundColor3 = C.bg2,
        BorderSizePixel = 0, LayoutOrder = layout,
    }, body)
    corner(f, 6)
    new("TextLabel", {
        Size = UDim2.new(0.40, -8, 1, 0), Position = UDim2.fromOffset(8, 0),
        BackgroundTransparency = 1, Font = Enum.Font.Gotham, TextSize = 12,
        TextColor3 = C.dim, TextXAlignment = Enum.TextXAlignment.Left, Text = label,
    }, f)
    local b = new("TextButton", {
        Size = UDim2.new(0.60, -8, 1, -8), Position = UDim2.new(0.40, 0, 0, 4),
        BackgroundColor3 = C.bg3, BorderSizePixel = 0, Font = Enum.Font.GothamMedium,
        TextSize = 12, TextColor3 = C.text, Text = "-",
        TextTruncate = Enum.TextTruncate.AtEnd,
    }, f)
    corner(b, 5)
    return b
end

local crafterBtn = rowButton("Crafter",     nextOrder())
local sellBtn    = rowButton("Sell pad",    nextOrder())
local outBtn     = rowButton("Sell shape",  nextOrder())
local speedBtn   = rowButton("Fly speed",   nextOrder())
local batchBtn   = rowButton("At once",     nextOrder())
local reachBtn   = rowButton("Scan radius", nextOrder())

local filterHdr = new("Frame", {
    Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1, LayoutOrder = nextOrder(),
}, body)
new("TextLabel", {
    Size = UDim2.new(0.55, 0, 1, 0), BackgroundTransparency = 1, Font = Enum.Font.GothamBold,
    TextSize = 12, TextColor3 = C.dim, TextXAlignment = Enum.TextXAlignment.Left,
    Text = "Feed into crafter",
}, filterHdr)
local allBtn = new("TextButton", {
    Size = UDim2.new(0.45, 0, 1, -3), Position = UDim2.new(0.55, 0, 0, 1),
    BackgroundColor3 = C.bg3, BorderSizePixel = 0, Font = Enum.Font.GothamMedium,
    TextSize = 11, TextColor3 = C.text, Text = "all / none",
}, filterHdr)
corner(allBtn, 5)

new("TextLabel", {
    Size = UDim2.new(1, 0, 0, 14), BackgroundTransparency = 1, Font = Enum.Font.Gotham,
    TextSize = 10, TextColor3 = Color3.fromRGB(110, 118, 132),
    TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = nextOrder(),
    Text = "click = feed this shape   •   shift+click = sell this shape",
}, body)

local list = new("ScrollingFrame", {
    Size = UDim2.new(1, 0, 0, 148), BackgroundColor3 = C.bg2, BorderSizePixel = 0,
    ScrollBarThickness = 4, CanvasSize = UDim2.new(),
    AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarImageColor3 = C.bg3,
    LayoutOrder = nextOrder(),
}, body)
corner(list, 6)
new("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }, list)
new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingLeft = UDim.new(0, 4),
                   PaddingRight = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4) }, list)

local rows = {}
for i, name in ipairs(SHAPE_NAMES) do
    local b = new("TextButton", {
        Size = UDim2.new(1, 0, 0, 22), BackgroundColor3 = C.bg3, BackgroundTransparency = 0.4,
        BorderSizePixel = 0, Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = C.dim,
        Text = "  " .. name, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = i,
    }, list)
    corner(b, 4)
    rows[name] = b
    b.Activated:Connect(function()
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
        or UserInputService:IsKeyDown(Enum.KeyCode.RightShift) then
            CFG.outputShape = (CFG.outputShape ~= name) and name or nil
        else
            CFG.inputShapes[name] = (not CFG.inputShapes[name]) or nil
        end
        UI.refresh()
    end)
end

--=====================================================================
-- UI LOGIC
--=====================================================================
local crafterIndex, sellIndex = 0, 0
local BATCHES = { 1, 2, 3, 5, 8 }

UI = {}
function UI.refresh()
    crafterBtn.Text = CFG.crafter and CFG.crafter.Name or "nearest (auto)"
    sellBtn.Text    = CFG.sellPart and CFG.sellPart.Parent.Name or "nearest (auto)"
    outBtn.Text     = CFG.outputShape or "auto-detect"
    speedBtn.Text   = SPEEDS[CFG.speedIndex].name
    batchBtn.Text   = tostring(CFG.maxAtOnce)
    reachBtn.Text   = CFG.scanRadius .. " studs"
    startBtn.Text   = CFG.running and "STOP" or "START"
    startBtn.BackgroundColor3 = CFG.running and C.bad or C.good

    for name, b in pairs(rows) do
        if CFG.outputShape == name then
            b.BackgroundColor3, b.BackgroundTransparency = C.accent, 0.15
            b.TextColor3 = Color3.new(1, 1, 1)
            b.Text = "  " .. name .. "   [SELL]"
        elseif CFG.inputShapes[name] then
            b.BackgroundColor3, b.BackgroundTransparency = C.good, 0.3
            b.TextColor3 = C.text
            b.Text = "  " .. name .. "   [feed]"
        else
            b.BackgroundColor3, b.BackgroundTransparency = C.bg3, 0.4
            b.TextColor3 = C.dim
            b.Text = "  " .. name
        end
    end
end

crafterBtn.Activated:Connect(function()
    local all = findCrafters()
    if #all == 0 then CFG.crafter = nil UI.refresh() return end
    crafterIndex = (crafterIndex + 1) % (#all + 1)
    CFG.crafter = crafterIndex == 0 and nil or all[crafterIndex]
    CFG.outputShape = nil
    UI.refresh()
end)

sellBtn.Activated:Connect(function()
    local all = findSellParts()
    if #all == 0 then CFG.sellPart = nil UI.refresh() return end
    sellIndex = (sellIndex + 1) % (#all + 1)
    CFG.sellPart = sellIndex == 0 and nil or all[sellIndex]
    UI.refresh()
end)

outBtn.Activated:Connect(function() CFG.outputShape = nil UI.refresh() end)

speedBtn.Activated:Connect(function()
    CFG.speedIndex = CFG.speedIndex % #SPEEDS + 1
    UI.refresh()
end)

batchBtn.Activated:Connect(function()
    local i = table.find(BATCHES, CFG.maxAtOnce) or 1
    CFG.maxAtOnce = BATCHES[i % #BATCHES + 1]
    UI.refresh()
end)

reachBtn.Activated:Connect(function()
    local i = table.find(SCANS, CFG.scanRadius) or 1
    CFG.scanRadius = SCANS[i % #SCANS + 1]
    UI.refresh()
end)

allBtn.Activated:Connect(function()
    if next(CFG.inputShapes) == nil then
        for _, n in ipairs(SHAPE_NAMES) do CFG.inputShapes[n] = true end
    else
        CFG.inputShapes = {}
    end
    UI.refresh()
end)

local function setRunning(on)
    if on == CFG.running then return end
    CFG.running = on
    UI.refresh()
    if on then task.spawn(mainLoop) end
end
startBtn.Activated:Connect(function() setRunning(not CFG.running) end)

local minimized = false
minBtn.Activated:Connect(function()
    minimized = not minimized
    body.Visible = not minimized
    root.Size = minimized and UDim2.fromOffset(330, 36) or UDim2.fromOffset(330, 476)
end)

local statusConn = RunService.Heartbeat:Connect(function()
    statusLbl.Text = string.format("%s\nfed %d   sold %d   missed %d",
        STATUS, stats.fed, stats.sold, stats.failed)
end)

local keyConn = UserInputService.InputBegan:Connect(function(i, gp)
    if gp then return end
    if i.KeyCode == Enum.KeyCode.RightControl then gui.Enabled = not gui.Enabled end
end)

--=====================================================================
local API = {}
function API.destroy()
    CFG.running = false
    statusConn:Disconnect()
    keyConn:Disconnect()
    gui:Destroy()
    _G.__AutoCraftSell = nil
end
API.CFG    = CFG
API.stats  = stats
API.start  = function() setRunning(true)  end
API.stop   = function() setRunning(false) end
API.status = function() return STATUS end
_G.__AutoCraftSell = API

closeBtn.Activated:Connect(API.destroy)

UI.refresh()
print("[AutoCraftSell] loaded — RightCtrl hides the window")
return API
