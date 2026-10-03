--[[
    Anime Expeditions [Summer Siege] - Auto Fishing  v3
    ====================================================
    Flow (decompiled from ClientFishingHandler / FishingPrompt):

      FISH_CAST_REEL:FireServer(waterPos, holdSeconds)  -> Stage: Idle -> Waiting
      Server triggers the bite after ~7-11s             -> Stage: Waiting -> Reeling
        FishingState.Parameters arrives with it         -> that IS the fish (Speed/MF/Length/Tracking)
      The minigame runs CLIENT SIDE ONLY                -> server only gets FISHING_RESULT:FireServer(bool)
                                                        -> Stage: Success/Fail -> Idle
      FISHING_PROMPT_OBTAINED delivers the real catch (Asset, Quality, Length as 0..1 rolls)

    We hijack FISHING_START_MINIGAME:InvokeSelf: no prompt, no clicking,
    just a "true" returned after ReelDelay.

    IMPORTANT: a result that arrives too early is discarded by the server
    (the state then hangs in Reeling). Measured: 0.15s and 0.4s discarded,
    1.5s and 3.0s accepted immediately. Hence ReelDelay 1.2-2.0 plus retry.

    Controls:  GUI top left, or F6, or _G.AutoFish:Start() / :Stop() / :Report()
    Full unload:  _G.AutoFish:Destroy()
]]

local Players           = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService  = game:GetService("UserInputService")

local Nodes     = require(ReplicatedStorage:WaitForChild("Nodes"))
local ItemUtils = require(ReplicatedStorage.Shared:WaitForChild("ItemUtils"))
local Info      = require(ReplicatedStorage.Shared:WaitForChild("Information"))
local RodInfo   = require(ReplicatedStorage.Shared.Information.FishingRodInfo)

local LocalPlayer = Players.LocalPlayer

----------------------------------------------------------------------
-- CONFIG
----------------------------------------------------------------------
local CONFIG = {
    HoldTime         = { 0.10, 0.25 }, -- charge-up time on the cast (no measurable effect)
    ReelDelay        = { 1.2,  2.0 },  -- delay before sending the result. Below ~1s the server discards it.
    RecastDelay      = { 0.15, 0.40 }, -- pause after Idle before the next cast
    ResultRetry      = 2.5,            -- no reaction? re-send the result
    MaxRetries       = 4,
    WaitingTimeout   = 45,             -- no bite -> resolve the state and recast
    CastSearchRadius = 60,
    CastDistance     = 8,
    LogCatches       = true,           -- log every catch to console + catches.txt
    AutoStart        = true,           -- start fishing immediately on load
    ToggleKey        = Enum.KeyCode.F6,
}

----------------------------------------------------------------------
-- FISH DATABASE (Parameters -> fish, known BEFORE reeling it in)
----------------------------------------------------------------------
local FISH = {}
for name, item in pairs(Info.Items) do
    if item.SubType == "Fish" and typeof(item.Length) == "table" then
        FISH[#FISH + 1] = {
            Id = name, Name = item.DisplayName or name, Rarity = item.Rarity or "Rare",
            Speed = item.Speed, Length = item.Length, Maps = item.Maps,
        }
    end
end

local function identifyFish(params)
    if not (params and typeof(params.Length) == "table") then return nil end
    for _, f in ipairs(FISH) do
        if math.abs((f.Speed or -99) - (params.Speed or -1)) < 0.001
           and f.Length[1] == params.Length[1] and f.Length[2] == params.Length[2] then
            return f
        end
    end
end

-- Sand Dollar value per FishingRodInfo.GetSellRewards (Quality/Length are 0..1 rolls)
local function fishValue(rarity, quality, length)
    local rv = RodInfo.SellRarityValue[rarity or "Rare"] or 1
    return math.floor(5 * (rv * ((quality or 0) + 1) * ((length or 0) * 1.1 + 1)))
end

----------------------------------------------------------------------
-- STATE
----------------------------------------------------------------------
if _G.AutoFish then pcall(function() _G.AutoFish:Destroy() end) end

local AutoFish = {}
_G.__AUTOFISH_EPOCH = (_G.__AUTOFISH_EPOCH or 0) + 1
local EPOCH = _G.__AUTOFISH_EPOCH

local function loaded()  return _G.__AUTOFISH_EPOCH == EPOCH and not AutoFish.Destroyed end
local function farming() return loaded() and AutoFish.Active end

AutoFish.Active      = false
AutoFish.Destroyed   = false
AutoFish.Stage       = Nodes.CLIENT_FISHING_STATE:Get() or "Idle"
AutoFish.Casts       = 0
AutoFish.Caught      = 0
AutoFish.Failed      = 0
AutoFish.Retries     = 0
AutoFish.Currency    = 0
AutoFish.ActiveTime  = 0
AutoFish.LastFish    = "-"
AutoFish.ByFish      = {}
AutoFish._conns      = {}
AutoFish._patched    = {}
AutoFish._lastGood   = nil

local function rand(r) return r[1] + (r[2] - r[1]) * math.random() end
local function say(...) print("[AutoFish]", ...) end

local function patch(node, method, fn)
    local orig = rawget(node, method) or getrawmetatable(node).__index[method]
    rawset(node, method, function(self, ...) return fn(orig, self, ...) end)
    table.insert(AutoFish._patched, { node, method })
end

----------------------------------------------------------------------
-- FINDING WATER (water parts carry the "Water" tag)
----------------------------------------------------------------------
local function surfacePointOn(part, fromPos)
    local o    = part.CFrame:PointToObjectSpace(fromPos)
    local half = part.Size / 2
    return part.CFrame:PointToWorldSpace(Vector3.new(
        math.clamp(o.X, -half.X, half.X), half.Y, math.clamp(o.Z, -half.Z, half.Z)))
end

local function findWaterTarget()
    local char = LocalPlayer.Character
    local root = char and char.PrimaryPart
    local head = char and char:FindFirstChild("Head")
    if not (root and head) then return nil, "No character" end

    -- Measure the distance to the NEAREST POINT of the surface, not to the center:
    -- water planes are often hundreds of studs wide, so their center can be far away
    -- while you are standing right in the middle of them.
    local best, bestDist, bestEdge
    for _, part in ipairs(CollectionService:GetTagged("Water")) do
        if part:IsA("BasePart") then
            local surf = surfacePointOn(part, root.Position)
            local d    = (surf - root.Position).Magnitude
            if d <= CONFIG.CastSearchRadius and (not bestDist or d < bestDist) then
                best, bestDist, bestEdge = part, d, surf
            end
        end
    end
    if not best then return nil, "No water in range" end

    local edge     = bestEdge
    local toCenter = Vector3.new(best.Position.X, edge.Y, best.Position.Z) - edge
    local target   = edge
    if toCenter.Magnitude > 0.1 then
        target = edge + toCenter.Unit * math.min(CONFIG.CastDistance, toCenter.Magnitude)
    end

    local hit = ItemUtils:RaycastToWater(head.Position, target)
    if hit then AutoFish._lastGood = hit.Position return hit.Position end
    if ItemUtils:IsPositionNearWater(target) then AutoFish._lastGood = target return target end
    if AutoFish._lastGood then return AutoFish._lastGood end
    return nil, "Water point not confirmed"
end

----------------------------------------------------------------------
-- ROD
----------------------------------------------------------------------
local function equippedRodId()
    local data = Nodes.GET_DATA_VALUE:InvokeSelf({ "FishingRodData" })
    if not data then return nil end
    for id, rod in pairs(data) do
        if rod.Equipped then return id end
    end
end

local function ensureRodEquipped()
    if Nodes.FISHING_ACTIVE:Get() then return true end
    if not equippedRodId() then return false, "No rod equipped" end
    local req = Nodes.FISH_EQUIP:Request()
    req:Timeout(2)
    if req:Wait() then return true end
    return false, "Equip failed"
end

----------------------------------------------------------------------
-- HIJACK THE MINIGAME (plus retry, because early results get discarded)
----------------------------------------------------------------------
patch(Nodes.FISHING_START_MINIGAME, "InvokeSelf", function(orig, self, params, callback)
    -- paused? -> open the real minigame so manual play still works
    if not farming() then return orig(self, params, callback) end

    local fish = identifyFish(params)
    AutoFish.LastFish = fish and (fish.Name .. " (" .. fish.Rarity .. ")") or "?"
    if CONFIG.LogCatches and fish then
        say(("Bite: %s (%s)"):format(fish.Name, fish.Rarity))
    end

    task.delay(rand(CONFIG.ReelDelay), function()
        if not farming() then return end
        callback(true)
        task.spawn(function()
            for _ = 1, CONFIG.MaxRetries do
                task.wait(CONFIG.ResultRetry)
                if not farming() or AutoFish.Stage ~= "Reeling" then break end
                AutoFish.Retries += 1
                Nodes.FISHING_RESULT:FireServer(true)
            end
        end)
    end)
    return true -- the prompt is never opened
end)

----------------------------------------------------------------------
-- STAGE + CATCH TRACKING
----------------------------------------------------------------------
table.insert(AutoFish._conns, Nodes.FISHING_STATE_CHANGED:Connect(function(_, path, value)
    if path[2] ~= "Stage" then return end
    AutoFish.Stage = value
    if value == "Success" then AutoFish.Caught += 1
    elseif value == "Fail" then AutoFish.Failed += 1 end
end))

table.insert(AutoFish._conns, Nodes.FISHING_PROMPT_OBTAINED:Connect(function(data)
    if not (farming() and data) then return end
    local id      = data.Asset or data.Item or data.Id
    local item    = id and Info.Items[id]
    local rarity  = item and item.Rarity
    local length  = data.Length or (data.Data and data.Data.Length)
    local quality = data.Quality or (data.Data and data.Data.Quality)
    local value   = fishValue(rarity, quality, length)
    AutoFish.Currency += value
    AutoFish.ByFish[id or "?"] = (AutoFish.ByFish[id or "?"] or 0) + 1
    if CONFIG.LogCatches then
        local line = ("%s | %s | Length %.2f | Quality %.2f | ~%d Sand Dollar"):format(
            (item and item.DisplayName) or tostring(id), tostring(rarity),
            tonumber(length) or -1, tonumber(quality) or -1, value)
        say("Catch: " .. line)
        pcall(function() appendfile("catches.txt", os.date("%H:%M:%S ") .. line .. "\n") end)
    end
end))

----------------------------------------------------------------------
-- MAIN LOOP
----------------------------------------------------------------------
local function waitStage(target, timeout)
    local t0 = os.clock()
    while farming() and os.clock() - t0 < timeout do
        if AutoFish.Stage == target then return true end
        task.wait(0.05)
    end
    return AutoFish.Stage == target
end

local function waitDone(timeout)
    local t0 = os.clock()
    while farming() and os.clock() - t0 < timeout do
        local s = AutoFish.Stage
        if s == "Success" or s == "Fail" or s == "Idle" then return s end
        task.wait(0.05)
    end
end

-- resolve a stuck state (e.g. after restarting in the middle of a reel)
local function resolveStuck()
    if AutoFish.Stage == "Reeling" then
        Nodes.FISHING_RESULT:FireServer(true)
        waitDone(6)
    end
    if AutoFish.Stage == "Waiting" then
        Nodes.FISHING_RESULT:FireServer(false)
        waitDone(4)
    end
    waitStage("Idle", 8)
end

local function farmLoop()
    resolveStuck()
    while farming() do
        if AutoFish.Stage ~= "Idle" then
            if not waitStage("Idle", 15) then resolveStuck() end
        end
        if not farming() then break end

        task.wait(rand(CONFIG.RecastDelay))

        local pos, err = findWaterTarget()
        if not pos then
            say("Cannot cast:", err, "- retrying in 3s")
            task.wait(3)
        else
            local ok, reason = ensureRodEquipped()
            if not ok then
                say("Rod:", reason, "- retrying in 3s")
                task.wait(3)
            else
                Nodes.FISH_CAST_REEL:FireServer(pos, rand(CONFIG.HoldTime))
                AutoFish.Casts += 1

                if not waitStage("Waiting", 4) then
                    resolveStuck()
                elseif not waitStage("Reeling", CONFIG.WaitingTimeout) then
                    say("no bite - resolving")
                    resolveStuck()
                elseif not waitDone(CONFIG.ReelDelay[2] + CONFIG.ResultRetry * (CONFIG.MaxRetries + 1)) then
                    say("reel stuck permanently - resolving")
                    resolveStuck()
                end
            end
        end
    end
end

----------------------------------------------------------------------
-- API
----------------------------------------------------------------------
function AutoFish:Start()
    if not loaded() or self.Active then return end
    self.Active = true
    self._activeSince = os.clock()
    say("started")
    task.spawn(farmLoop)
end

function AutoFish:Stop()
    if not self.Active then return end
    self.Active = false
    if self._activeSince then
        self.ActiveTime += os.clock() - self._activeSince
        self._activeSince = nil
    end
    -- do not leave a running reel hanging
    if self.Stage == "Reeling" then pcall(function() Nodes.FISHING_RESULT:FireServer(true) end) end
    say("stopped")
end

function AutoFish:Toggle()
    if self.Active then self:Stop() else self:Start() end
end

function AutoFish:Seconds()
    return self.ActiveTime + (self._activeSince and (os.clock() - self._activeSince) or 0)
end

function AutoFish:Report()
    local secs = self:Seconds()
    say(("%d casts | %d caught | %d lost | %d retries | ~%d Sand Dollar | %.1f min | ~%d/h | %.1fs per fish")
        :format(self.Casts, self.Caught, self.Failed, self.Retries, self.Currency, secs / 60,
                secs > 5 and math.floor(self.Currency / secs * 3600) or 0,
                self.Caught > 0 and secs / self.Caught or 0))
    for id, n in pairs(self.ByFish) do
        local item = Info.Items[id]
        say(("   %-20s x%d"):format((item and item.DisplayName) or id, n))
    end
end

function AutoFish:Destroy()
    self:Stop()
    self.Destroyed = true
    for _, c in ipairs(self._conns) do pcall(function() c:Disconnect() end) end
    for _, p in ipairs(self._patched) do rawset(p[1], p[2], nil) end
    if self.Gui then pcall(function() self.Gui:Destroy() end) end
    self:Report()
    if _G.AutoFish == self then _G.AutoFish = nil end
end

----------------------------------------------------------------------
-- GUI
----------------------------------------------------------------------
local function buildGui()
    local parent = (gethui and gethui()) or game:GetService("CoreGui")
    local old = parent:FindFirstChild("AutoFishGui")
    if old then old:Destroy() end

    local gui = Instance.new("ScreenGui")
    gui.Name = "AutoFishGui"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.Parent = parent

    local main = Instance.new("Frame")
    main.Size = UDim2.fromOffset(232, 150)
    main.Position = UDim2.new(0, 24, 0, 120)
    main.BackgroundColor3 = Color3.fromRGB(22, 26, 33)
    main.BorderSizePixel = 0
    main.Active = true
    main.Parent = gui
    Instance.new("UICorner", main).CornerRadius = UDim.new(0, 8)

    local stroke = Instance.new("UIStroke", main)
    stroke.Color = Color3.fromRGB(58, 120, 180)
    stroke.Thickness = 1
    stroke.Transparency = 0.4

    -- title bar (draggable)
    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(1, 0, 0, 30)
    bar.BackgroundColor3 = Color3.fromRGB(30, 38, 50)
    bar.BorderSizePixel = 0
    bar.Parent = main
    Instance.new("UICorner", bar).CornerRadius = UDim.new(0, 8)

    local title = Instance.new("TextLabel")
    title.BackgroundTransparency = 1
    title.Position = UDim2.fromOffset(12, 0)
    title.Size = UDim2.new(1, -46, 1, 0)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 13
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.TextColor3 = Color3.fromRGB(225, 235, 245)
    title.Text = "AutoFish"
    title.Parent = bar

    local close = Instance.new("TextButton")
    close.Size = UDim2.fromOffset(28, 30)
    close.Position = UDim2.new(1, -28, 0, 0)
    close.BackgroundTransparency = 1
    close.Font = Enum.Font.GothamBold
    close.TextSize = 14
    close.TextColor3 = Color3.fromRGB(150, 160, 175)
    close.Text = "X"
    close.Parent = bar

    local toggle = Instance.new("TextButton")
    toggle.Size = UDim2.new(1, -24, 0, 34)
    toggle.Position = UDim2.fromOffset(12, 40)
    toggle.BackgroundColor3 = Color3.fromRGB(45, 150, 90)
    toggle.BorderSizePixel = 0
    toggle.Font = Enum.Font.GothamBold
    toggle.TextSize = 14
    toggle.TextColor3 = Color3.fromRGB(255, 255, 255)
    toggle.Text = "START"
    toggle.AutoButtonColor = true
    toggle.Parent = main
    Instance.new("UICorner", toggle).CornerRadius = UDim.new(0, 6)

    local stats = Instance.new("TextLabel")
    stats.BackgroundTransparency = 1
    stats.Position = UDim2.fromOffset(12, 80)
    stats.Size = UDim2.new(1, -24, 0, 62)
    stats.Font = Enum.Font.Code
    stats.TextSize = 11
    stats.TextXAlignment = Enum.TextXAlignment.Left
    stats.TextYAlignment = Enum.TextYAlignment.Top
    stats.TextColor3 = Color3.fromRGB(165, 180, 200)
    stats.Text = ""
    stats.Parent = main

    -- dragging
    local dragging, dragStart, startPos
    bar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging, dragStart, startPos = true, input.Position, main.Position
        end
    end)
    bar.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if not dragging then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch then
            local d = input.Position - dragStart
            main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X,
                                      startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)

    toggle.MouseButton1Click:Connect(function() AutoFish:Toggle() end)
    close.MouseButton1Click:Connect(function() AutoFish:Destroy() end)

    -- stats refresh
    task.spawn(function()
        while loaded() and gui.Parent do
            local on   = AutoFish.Active
            toggle.Text = on and "STOP" or "START"
            toggle.BackgroundColor3 = on and Color3.fromRGB(190, 65, 65) or Color3.fromRGB(45, 150, 90)
            local secs = AutoFish:Seconds()
            stats.Text = ("Status  %s\nCaught  %d   Fails %d   Retry %d\nCurrency ~%d  (~%d/h)\nLast    %s")
                :format(on and (AutoFish.Stage or "?") or "paused",
                        AutoFish.Caught, AutoFish.Failed, AutoFish.Retries, AutoFish.Currency,
                        secs > 5 and math.floor(AutoFish.Currency / secs * 3600) or 0,
                        AutoFish.LastFish)
            task.wait(0.4)
        end
    end)

    AutoFish.Gui = gui
    return gui
end

pcall(buildGui)

table.insert(AutoFish._conns, UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == CONFIG.ToggleKey then AutoFish:Toggle() end
end))

_G.AutoFish = AutoFish
say("loaded (epoch " .. EPOCH .. ") - GUI top left, key " .. CONFIG.ToggleKey.Name)
if CONFIG.AutoStart then AutoFish:Start() end
return AutoFish
