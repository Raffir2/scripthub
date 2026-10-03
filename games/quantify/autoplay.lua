--!nocheck
--=====================================================================
--  AUTOPLAY  --  plans and executes the best craft chain for a round
--  PlaceId 73648930852061
--
--  1. predict how many base shapes the round will drop
--  2. search the recipe tree for the target that maximises banked value
--     subject to how many carries the bot can physically do in the time
--  3. drive the single crafter stage by stage, switching its recipe
--  4. liquidate everything before the clock runs out
--=====================================================================

if _G.__AutoPlay then pcall(_G.__AutoPlay.destroy) end

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService       = game:GetService("HttpService")

local plr        = Players.LocalPlayer
local Remotes    = ReplicatedStorage:WaitForChild("Remotes")
local Net        = Remotes:WaitForChild("Network")
local CrafterRem = Remotes:WaitForChild("Crafter")
local RecipeRem  = Remotes:WaitForChild("Recipes")
local InvRem     = Remotes:WaitForChild("Inventory")
local BuyRem     = Remotes:WaitForChild("BoughtItem")

--=====================================================================
-- STATIC GAME DATA  (extracted from the server's own recipe grids)
--=====================================================================
local RECIPES = {
    ["SQUARE"]           = { TRIANGLE = 2 },
    ["PENTAGON"]         = { TRIANGLE = 3 },
    ["HEXAGON"]          = { TRIANGLE = 4 },
    ["TETRAHEDRON"]      = { TRIANGLE = 4 },
    ["OCTAHEDRON"]       = { TRIANGLE = 8 },
    ["BIG TRIANGLE"]     = { TRIANGLE = 9 },
    ["PYRAMID"]          = { SQUARE = 1, TRIANGLE = 4 },
    ["STAR"]             = { PENTAGON = 1, TRIANGLE = 5 },
    ["DIAMOND"]          = { HEXAGON = 1, TRIANGLE = 6 },
    ["CUBE"]             = { SQUARE = 6 },
    ["EGYPTIAN PYRAMID"] = { SQUARE = 6 },
    ["BIG SQUARE"]       = { SQUARE = 9 },
    ["HONEYCOMB"]        = { HEXAGON = 4 },
    ["BIG HEXAGON"]      = { HEXAGON = 9 },
    ["BIG PENTAGON"]     = { PENTAGON = 9 },
    ["DODECAHEDRON"]     = { PENTAGON = 6 },
    ["ICOSAHEDRON"]      = { TETRAHEDRON = 5 },
    ["TESSERACT"]        = { CUBE = 1, SQUARE = 6 },
    ["ULTIMATE DICE"]    = { CUBE = 1, DODECAHEDRON = 1, ICOSAHEDRON = 1,
                             OCTAHEDRON = 1, TETRAHEDRON = 1 },
    -- need CIRCLE, which only a Circle Dropper / Circular card provides
    ["BIG CIRCLE"]       = { CIRCLE = 9 },
    ["SPHERE"]           = { CIRCLE = 5 },
    ["CYLINDER"]         = { CIRCLE = 3 },
    ["CONE"]             = { CIRCLE = 1, TRIANGLE = 3 },
    ["HEART"]            = { TRIANGLE = 1, CIRCLE = 2 },
    ["GEAR"]             = { CIRCLE = 1, SQUARE = 4 },
    ["TORUS KNOT"]       = { CYLINDER = 6 },
    ["ICOSPHERE"]        = { SPHERE = 1, TRIANGLE = 8 },
    ["TROPHY"]           = { STAR = 1, CIRCLE = 2, CYLINDER = 2 },
    ["HEAD"]             = { GEAR = 1, CIRCLE = 2 },
    ["TORSO"]            = { HEART = 1, SQUARE = 4 },
    ["LIMB"]             = { CIRCLE = 1, CUBE = 1, CYLINDER = 1 },
    ["HUMAN"]            = { HEAD = 1, TORSO = 1, LIMB = 4 },
}

-- measured spawn cadence: every dropper emits one shape per this many seconds
local DROP_PERIOD = 1.60

--=====================================================================
-- LEARNED SHAPE VALUES  (persisted across sessions)
--=====================================================================
local VALUES = { TRIANGLE = 6 }
pcall(function()
    if isfile and isfile("shapevalues.json") then
        local t = HttpService:JSONDecode(readfile("shapevalues.json"))
        if type(t) == "table" then for k, v in pairs(t) do VALUES[k] = v end end
    end
end)

local function saveValues()
    pcall(function()
        writefile("shapevalues.json", HttpService:JSONEncode(VALUES))
        local ks = {}
        for k in pairs(VALUES) do ks[#ks+1] = k end
        table.sort(ks)
        local lines = { "shape,baseValue" }
        for _, k in ipairs(ks) do lines[#lines+1] = k .. "," .. tostring(VALUES[k]) end
        writefile("shapevalues.csv", table.concat(lines, "\n"))
    end)
end

-- Until a shape has been seen for real we have to guess its worth.  Both
-- candidate models are supported; whichever the measurements support wins.
--   "step"  : crafting multiplies the input value by CRAFT_GAIN each craft
--   "flat"  : a shape is worth exactly the sum of its ingredients
local MODEL      = "unknown"
local CRAFT_GAIN = 3.5      -- from BIG TRIANGLE: 189 / (9 x 6)

local baseCostCache = {}
local function baseCost(shape, seen)          -- cost in TRIANGLEs
    if baseCostCache[shape] then return baseCostCache[shape] end
    local r = RECIPES[shape]
    if not r then return (shape == "TRIANGLE") and 1 or nil end
    seen = seen or {}
    if seen[shape] then return nil end
    seen[shape] = true
    local total = 0
    for ing, n in pairs(r) do
        local c = baseCost(ing, seen)
        if not c then return nil end
        total += c * n
    end
    seen[shape] = nil
    baseCostCache[shape] = total
    return total
end

local depthCache = {}
local function craftDepth(shape)               -- craft steps from raw
    if depthCache[shape] then return depthCache[shape] end
    local r = RECIPES[shape]
    if not r then return 0 end
    local deepest = 0
    for ing in pairs(r) do
        local d = craftDepth(ing)
        if d > deepest then deepest = d end
    end
    depthCache[shape] = deepest + 1
    return deepest + 1
end

local function rawValue() return VALUES.TRIANGLE or 5 end

-- Measured so far: SQUARE is worth exactly its ingredients (1.0x) while
-- BIG TRIANGLE is worth 3.5x them.  There is no single rule, so an
-- unmeasured shape is assumed to be worth only its ingredients -- the
-- planner will never gamble on a shape it has not actually seen.
local function valueOf(shape)
    if VALUES[shape] then return VALUES[shape] end
    local c = baseCost(shape)
    if not c then return 0 end
    return c * rawValue()
end

local function gainOf(shape)
    local v, c = VALUES[shape], baseCost(shape)
    if not v or not c or c == 0 then return nil end
    return v / (c * rawValue())
end

-- how many individual shapes have to be carried into the crafter to make
-- one of `shape` from raw materials (this is the real bottleneck)
local carryCache = {}
local function carriesFor(shape)
    if carryCache[shape] then return carryCache[shape] end
    local r = RECIPES[shape]
    if not r then return 0 end
    local total = 0
    for ing, n in pairs(r) do
        total += n                       -- each ingredient is carried in
        total += carriesFor(ing) * n     -- plus whatever it took to make it
    end
    carryCache[shape] = total
    return total
end

--=====================================================================
-- WORLD HELPERS
--=====================================================================
local function getHRP()
    local c = plr.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function isAlive(o)
    return o and o.Parent and o.PrimaryPart
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

local function myCrafters()
    local t = {}
    for _, m in ipairs(workspace.BuildingParts:GetChildren()) do
        if m:IsA("Model") and string.find(m.Name, "Crafter") and m:FindFirstChild("Input") then
            local by = m:GetAttribute("placedBy")
            if by == nil or by == plr.Name then t[#t+1] = m end
        end
    end
    return t
end

local function sellPart()
    local best, bd
    local hrp = getHRP()
    local origin = hrp and hrp.Position or Vector3.new()
    local function scan(folder)
        if not folder then return end
        for _, m in ipairs(folder:GetChildren()) do
            if m:IsA("Model") then
                local s = m:FindFirstChild("Sell")
                if s and s:IsA("BasePart") then
                    local d = (s.Position - origin).Magnitude
                    if not bd or d < bd then best, bd = s, d end
                end
            end
        end
    end
    scan(workspace.BuildingParts)
    scan(workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("BuildingParts"))
    return best
end

local function census()
    local c = {}
    for _, folder in ipairs({ workspace:FindFirstChild("Parts"), workspace:FindFirstChild("Shapesother") }) do
        if folder then
            for _, o in ipairs(folder:GetChildren()) do
                if o:IsA("Model") and isAlive(o) and not o:GetAttribute("owner") then
                    local n = shapeNameOf(o)
                    c[n] = (c[n] or 0) + 1
                end
            end
        end
    end
    return c
end

--=====================================================================
-- CARRY  (two teleports plus the vanilla pickup handshake)
--=====================================================================
local inFlight, flightCount = {}, 0
local stats = { fed = 0, sold = 0, failed = 0 }
local RUNNING = false

local function transport(o, getDest, timeout)
    local pp = o.PrimaryPart
    if not pp then return false end
    inFlight[o] = true
    flightCount += 1

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
    while os.clock() - t0 < (timeout or 4) do
        if gone(o) or not RUNNING then break end
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
-- CRAFTER CONTROL
--=====================================================================
local recipeIndex = {}     -- shapeName -> the recipe table the server expects
local function loadRecipeIndex()
    local ok, crafting = pcall(require, plr.PlayerScripts.Client.Classes.gui.crafting)
    if ok and crafting and crafting.Recipes then
        for _, r in ipairs(crafting.Recipes) do recipeIndex[r[1]] = r end
    end
    return next(recipeIndex) ~= nil
end

local currentRecipe = nil
local function setRecipe(crafter, shape)
    if currentRecipe == shape then return true end
    local r = recipeIndex[shape]
    if not r then return false end
    RecipeRem:FireServer(crafter, r)
    currentRecipe = shape
    task.wait(0.35)
    return true
end

local function readCrafter(crafter)
    local inv, grid, item, done
    local conn = CrafterRem.OnClientEvent:Connect(function(i, g, it)
        inv, grid, item, done = i, g, it, true
    end)
    pcall(function() CrafterRem:FireServer(crafter, true) end)
    local t0 = os.clock()
    while not done and os.clock() - t0 < 1.5 do task.wait(0.04) end
    conn:Disconnect()
    pcall(function() CrafterRem:FireServer(crafter, false) end)
    return inv or {}, grid or {}, item
end

--=====================================================================
-- SURVEY  -- a shape's worth cannot be derived, only observed, so the
-- first thing a run does is craft exactly one of every unknown shape.
-- One unit is cheap and it permanently unlocks that shape for planning.
--=====================================================================
local function surveyList(maxCost)
    local todo = {}
    for shape in pairs(RECIPES) do
        local c = baseCost(shape)
        if c and not VALUES[shape] and c <= (maxCost or math.huge) then
            todo[#todo+1] = { shape = shape, cost = c }
        end
    end
    table.sort(todo, function(a, b) return a.cost < b.cost end)
    return todo
end

--=====================================================================
-- PLANNER
--=====================================================================
-- expected number of raw shapes still to drop this round
local function shapeBudget()
    local map = workspace:FindFirstChild("Map")
    if not map then return 0, 0 end

    local counts = map:GetAttribute("DropperCounts")
    local n = 0
    if type(counts) == "string" then
        local ok, t = pcall(function() return HttpService:JSONDecode(counts) end)
        if ok and type(t) == "table" then for _, v in pairs(t) do n += v end end
    end
    if n == 0 then
        -- attribute only exists mid-round; fall back to counting the world
        for _, m in ipairs(workspace.BuildingParts:GetChildren()) do
            if string.find(m.Name, "Dropper") then n += 1 end
        end
        local mb = map:FindFirstChild("BuildingParts")
        if mb then
            for _, m in ipairs(mb:GetChildren()) do
                if string.find(m.Name, "Dropper") or m.Name == "Conveyor" then n += 1 end
            end
        end
        if n == 0 then n = 1 end
    end

    local gh = plr.PlayerGui:FindFirstChild("GameHUD")
    local secs = 0
    if gh then secs = tonumber((gh.Time.Text:gsub("%D", ""))) or 0 end

    return math.floor(n * secs / DROP_PERIOD), secs
end

-- Given a pool of raw triangles, pick the target shape that banks the most.
-- carryBudget caps how many crafter feeds we can physically perform.
local function plan(triangles, carryBudget)
    local best = { target = nil, count = 0, value = 0 }

    for shape in pairs(RECIPES) do
        local cost = baseCost(shape)
        local per  = carriesFor(shape)
        if cost and per and per > 0 and cost <= triangles then
            local byMaterial = math.floor(triangles / cost)
            local byCarries  = math.floor(carryBudget / (per + 1))   -- +1 = the sell trip
            local count      = math.min(byMaterial, byCarries)
            if count > 0 then
                local leftover = triangles - count * cost
                local total    = count * valueOf(shape) + leftover * rawValue()
                if total > best.value then
                    best = { target = shape, count = count, value = total,
                             cost = cost, carries = per }
                end
            end
        end
    end

    -- selling raw is always the fallback
    local rawTotal = math.min(triangles, carryBudget) * rawValue()
    if rawTotal > best.value then
        best = { target = nil, count = 0, value = rawTotal, cost = 1, carries = 0 }
    end
    return best
end

-- Break a target into the ordered list of crafter stages needed to build it.
local function stagesFor(target, count)
    local need, order, seen = { [target] = count }, {}, {}
    local function walk(shape, qty)
        local r = RECIPES[shape]
        if not r then return end
        for ing, n in pairs(r) do
            need[ing] = (need[ing] or 0) + qty * n
            walk(ing, qty * n)
        end
    end
    walk(target, count)

    local function emit(shape)
        if seen[shape] or not RECIPES[shape] then return end
        seen[shape] = true
        for ing in pairs(RECIPES[shape]) do emit(ing) end
        order[#order+1] = { shape = shape, count = need[shape] }
    end
    emit(target)
    return order, need
end

--=====================================================================
-- EXECUTION
--=====================================================================
local STATUS  = "idle"
local LOGLINES = {}
local function LOG(s)
    LOGLINES[#LOGLINES+1] = os.date("%X") .. "  " .. s
    pcall(writefile, "autoplay.log", table.concat(LOGLINES, "\n"))
    print("[autoplay] " .. s)
end

local MAX_AT_ONCE  = 12
local LIQUIDATE_AT = 12      -- seconds left when we stop crafting and cash out

local function learnFrom(o)
    local s, b = shapeNameOf(o), o:GetAttribute("BaseValue")
    if s and b and VALUES[s] == nil then
        VALUES[s] = b
        saveValues()
        LOG(("learned %s = %s"):format(s, tostring(b)))
        -- first crafted shape settles which value model the game uses
        if MODEL == "unknown" and RECIPES[s] then
            local raw = (baseCost(s) or 0) * 6
            if raw > 0 then
                MODEL = (b > raw * 1.5) and "step" or "flat"
                LOG(("value model = %s  (%s raw=%d actual=%s)"):format(MODEL, s, raw, tostring(b)))
            end
        end
    end
end

local function pickShapes(name, limit)
    local out = {}
    for _, folder in ipairs({ workspace:FindFirstChild("Parts"), workspace:FindFirstChild("Shapesother") }) do
        if folder then
            for _, o in ipairs(folder:GetChildren()) do
                if o:IsA("Model") and not inFlight[o] and isAlive(o)
                   and not o:GetAttribute("owner") and shapeNameOf(o) == name then
                    out[#out+1] = o
                    if #out >= limit then return out end
                end
            end
        end
    end
    return out
end

local function timeLeft()
    local gh = plr.PlayerGui:FindFirstChild("GameHUD")
    if not gh then return 0 end
    return tonumber((gh.Time.Text:gsub("%D", ""))) or 0
end

local function runRound()
    local crafter = myCrafters()[1]
    local sell    = sellPart()
    if not sell then LOG("no sell pad — aborting") return end

    local sellDest = function()
        local s = sellPart()
        return s and (s.Position + Vector3.new(0, s.Size.Y / 2 + 1.2, 0)) or nil
    end
    local feedDest = function()
        local i = crafter and crafter:FindFirstChild("Input")
        return i and i.Position or nil
    end

    -- ---- plan -------------------------------------------------------
    local incoming, secs = shapeBudget()
    local have = census()
    local triangles = (have.TRIANGLE or 0) + incoming
    -- throughput measured at roughly 1.6 carries/sec with 8 in flight
    local carryBudget = math.floor(math.max(secs - LIQUIDATE_AT, 0) * 1.6)

    LOG(("round: %ds left, %d triangles on field, %d incoming -> %d total; carry budget %d")
        :format(secs, have.TRIANGLE or 0, incoming, triangles, carryBudget))

    -- ---- survey unknown shapes first -------------------------------
    if crafter then
        local todo = surveyList(math.floor(triangles / 2))
        if #todo > 0 then
            local names = {}
            for _, e in ipairs(todo) do names[#names+1] = e.shape .. "(" .. e.cost .. "T)" end
            LOG("survey: " .. #todo .. " unknown shapes -> " .. table.concat(names, ", "))
            local surveyUntil = os.clock() + math.max(10, (secs - LIQUIDATE_AT) * 0.5)
            for _, entry in ipairs(todo) do
                if not RUNNING or timeLeft() <= LIQUIDATE_AT + 8 then break end
                if os.clock() > surveyUntil then
                    LOG("survey budget spent; " .. entry.shape .. " and beyond deferred")
                    break
                end
                if VALUES[entry.shape] then continue end
                STATUS = "surveying " .. entry.shape
                local sub = stagesFor(entry.shape, 1)
                for _, stage in ipairs(sub) do
                    if not RUNNING or VALUES[entry.shape] then break end
                    setRecipe(crafter, stage.shape)
                    local deadline = math.min(os.clock() + 15, surveyUntil + 15)
                    while RUNNING and os.clock() < deadline do
                        if timeLeft() <= LIQUIDATE_AT then break end
                        if (census()[stage.shape] or 0) >= stage.count then break end
                        local slots = MAX_AT_ONCE - flightCount
                        local fedAny = false
                        for ing in pairs(RECIPES[stage.shape]) do
                            if slots <= 0 then break end
                            for _, o in ipairs(pickShapes(ing, slots)) do
                                fedAny = true
                                slots -= 1
                                task.spawn(function()
                                    if transport(o, feedDest, 4) then stats.fed += 1 else stats.failed += 1 end
                                end)
                            end
                        end
                        task.wait(fedAny and 0.1 or 0.3)
                    end
                end
            end
            local known = {}
            for shape in pairs(RECIPES) do
                local g = gainOf(shape)
                if g then known[#known+1] = ("%s=%.2fx"):format(shape, g) end
            end
            table.sort(known)
            LOG("gains: " .. table.concat(known, "  "))
        end
    end

    local p = plan(triangles, carryBudget)
    if not crafter or not p.target then
        LOG("plan: sell raw" .. (crafter and "" or " (no crafter placed)"))
        while RUNNING and workspace.Map:GetAttribute("state") == "playing" do
            STATUS = "selling raw"
            local slots = MAX_AT_ONCE - flightCount
            if slots > 0 then
                for _, o in ipairs(pickShapes("TRIANGLE", slots)) do
                    task.spawn(function()
                        if transport(o, sellDest, 4) then stats.sold += 1 else stats.failed += 1 end
                    end)
                end
            end
            task.wait(0.1)
        end
        return
    end

    local stages, need = stagesFor(p.target, p.count)
    local desc = {}
    for _, s in ipairs(stages) do desc[#desc+1] = s.count .. "x " .. s.shape end
    LOG(("plan: %d x %s  (=%d triangles each, %d carries each, est $%d)")
        :format(p.count, p.target, p.cost, p.carries, math.floor(p.value)))
    LOG("stages: " .. table.concat(desc, "  ->  "))

    -- ---- execute stages --------------------------------------------
    for _, stage in ipairs(stages) do
        if not RUNNING then break end
        setRecipe(crafter, stage.shape)
        LOG(("stage: make %d x %s"):format(stage.count, stage.shape))

        local ingredients = RECIPES[stage.shape]
        while RUNNING and workspace.Map:GetAttribute("state") == "playing" do
            if timeLeft() <= LIQUIDATE_AT then LOG("liquidation time") break end

            local made = census()[stage.shape] or 0
            if made >= stage.count then
                LOG(("stage done: %d x %s"):format(made, stage.shape))
                break
            end

            STATUS = ("crafting %s (%d/%d)"):format(stage.shape, made, stage.count)

            local slots = MAX_AT_ONCE - flightCount
            local fedAny = false
            for ing in pairs(ingredients) do
                if slots <= 0 then break end
                local batch = pickShapes(ing, slots)
                for _, o in ipairs(batch) do
                    fedAny = true
                    slots -= 1
                    task.spawn(function()
                        if transport(o, feedDest, 4) then stats.fed += 1 else stats.failed += 1 end
                    end)
                end
            end
            task.wait(fedAny and 0.1 or 0.35)
        end
    end

    -- ---- liquidate --------------------------------------------------
    LOG("liquidating")
    while RUNNING and workspace.Map:GetAttribute("state") == "playing" do
        STATUS = "selling everything"
        local slots = MAX_AT_ONCE - flightCount
        if slots > 0 then
            -- most valuable first
            local pool = {}
            for _, folder in ipairs({ workspace:FindFirstChild("Parts") }) do
                if folder then
                    for _, o in ipairs(folder:GetChildren()) do
                        if o:IsA("Model") and not inFlight[o] and isAlive(o)
                           and not o:GetAttribute("owner") then pool[#pool+1] = o end
                    end
                end
            end
            table.sort(pool, function(a, b)
                return (a:GetAttribute("value") or 0) > (b:GetAttribute("value") or 0)
            end)
            for i = 1, math.min(slots, #pool) do
                local o = pool[i]
                task.spawn(function()
                    if transport(o, sellDest, 4) then stats.sold += 1 else stats.failed += 1 end
                end)
            end
        end
        task.wait(0.1)
    end
end

--=====================================================================
local learnConn = workspace.Parts.ChildAdded:Connect(function(o)
    task.wait(0.1)
    if o.Parent and isAlive(o) then learnFrom(o) end
end)
for _, o in ipairs(workspace.Parts:GetChildren()) do if isAlive(o) then learnFrom(o) end end

local API = {}
API.stats  = stats
API.values = VALUES
API.status = function() return STATUS end
API.plan   = plan
API.budget = shapeBudget

function API.start()
    if RUNNING then return end
    if not loadRecipeIndex() then LOG("could not read recipe list") return end
    RUNNING = true
    task.spawn(function()
        while RUNNING do
            if workspace.Map:GetAttribute("state") == "playing" then
                stats.fed, stats.sold, stats.failed = 0, 0, 0
                currentRecipe = nil
                runRound()
                STATUS = "round over"
                while RUNNING and workspace.Map:GetAttribute("state") == "playing" do task.wait(0.5) end
            else
                STATUS = "waiting for round"
                task.wait(0.5)
            end
        end
    end)
    LOG("started")
end

function API.stop() RUNNING = false STATUS = "stopped" LOG("stopped") end

function API.destroy()
    RUNNING = false
    learnConn:Disconnect()
    _G.__AutoPlay = nil
end

_G.__AutoPlay = API
LOG("loaded. known values: " .. HttpService:JSONEncode(VALUES))
return API
