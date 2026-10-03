--[[
    Auto Vent v3  (run ONCE, leave it)  -- NO hooks, NO remotes
    ----------------------------------------------------------------------
    v2 hooked __namecall -> game has a "namecall instance detector" -> kick.
    v3 only reads GUI properties and moves the real cursor (mousemoveabs),
    exactly like v1 (which never got kicked), but precisely:

    How the game checks (decompiled VentSystemL, every RenderStepped):
        u8 = clamp((mouseX - Frame.AbsX) / Frame.AbsW, 0, 1)
        inZone = Green.X < u8 < Green.X + Green.W       (Green of LAST frame)
        then: Green.X += u7*dt*dir*mult, clamped to [0, u7], bounce at edges
              Green.W  = 1 - u7
        Marker.Position.X = u8   <- what the game actually read

    v1 failed at the corners: it ran BEFORE the game's update (stale Green)
    and used a linear lead that overshot when Green bounced.

    v3:
      * runs on Heartbeat (after the game's RenderStepped update this frame)
      * measures the real input lag by matching Marker.X (game's u8) against
        our own recent commands, and predicts exactly that far ahead
      * prediction reflects off the edges like the game does
    You hold M1 yourself. END = toggle on/off.
--]]

local MAX_LAG_FRAMES = 6

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS        = game:GetService("UserInputService")
local LP         = Players.LocalPlayer
local G          = getgenv()

-- unload a previous v3 instance
if G.__AUTOVENT3 then pcall(G.__AUTOVENT3) end

if typeof(mousemoveabs) ~= "function" then
    warn("[AUTO-VENT] mousemoveabs missing, aborting"); return
end

local enabled  = true
local hist     = {}      -- recent commands: {scale = targetScale}
local lagF     = 1.0     -- measured lag in frames (EMA), game reads our move this many frames later
local lastP    = nil
local dir      = 1
local mult     = 1.0     -- AreaMoveSpeedMultiplier estimate (tools change it)
local wasOpen  = false
local focused  = (typeof(isrbxactive) == "function") and isrbxactive or function() return true end

-- per-vent telemetry -> workspace/_autovent_log.txt
local LOG = "_autovent_log.txt"
local st
local function newStats() return {t0 = os.clock(), frames = 0, drill = 0, out = 0, fails = 0, minPx = 1e9, edgeOut = 0, notes = {}} end
local function flush()
    if not st or st.frames == 0 then return end
    local line = string.format("[%s] %.1fs frames=%d drillFrames=%d outWhileDrill=%d fails=%d minMarginPx=%.1f edgeOut=%d lagF=%.2f mult=%.2f %s\n",
        os.date("%H:%M:%S"), os.clock() - st.t0, st.frames, st.drill, st.out, st.fails, st.minPx, st.edgeOut, lagF, mult, table.concat(st.notes, " "))
    pcall(function()
        if typeof(appendfile) == "function" and isfile and isfile(LOG) then appendfile(LOG, line)
        else writefile(LOG, ((isfile and isfile(LOG)) and readfile(LOG) or "") .. line) end
    end)
end
local prevG, prevW, wasRed = nil, nil, false

local function parts()
    local mg = LP.PlayerGui:FindFirstChild("VentMinigame"); if not mg then return end
    local fr = mg:FindFirstChild("Frame");                  if not fr or not fr.Visible then return end
    local gr = fr:FindFirstChild("Green");                  if not gr then return end
    return fr, gr, fr:FindFirstChild("Marker")
end

-- move Green forward by `dist` (scale units) inside [0, u7], bouncing like the game
local function advance(p, d, dist, u7)
    if u7 <= 0 then return 0 end
    local q = p + d * dist
    for _ = 1, 4 do
        if q > u7 then q = 2 * u7 - q
        elseif q < 0 then q = -q
        else break end
    end
    return math.clamp(q, 0, u7)
end

local conn = RunService.Heartbeat:Connect(function(dt)
    local fr, gr, mk = parts()
    if not enabled or not fr then
        if wasOpen then flush(); st = nil; hist = {}; lastP = nil; prevG = nil; wasOpen = false end
        return
    end
    if not wasOpen then st = newStats() end
    wasOpen = true

    -- telemetry: Marker = the u8 the game read this frame, checked vs Green of the previous frame
    if mk and prevG then
        local m   = mk.Position.X.Scale
        local mar = math.min(m - prevG, prevG + prevW - m) * fr.AbsoluteSize.X
        local drilling = fr.BackgroundColor3.R > 0.35 and fr.BackgroundColor3.G < 0.15
        st.frames += 1
        if drilling then
            st.drill += 1
            st.minPx = math.min(st.minPx, mar)
            if mar <= 0 then
                st.out += 1
                if prevG < 0.01 or prevG > (1 - prevW) - 0.01 then st.edgeOut += 1 end
            end
        end
        local c = gr.BackgroundColor3
        local red = c.R > 0.95 and c.G < 0.05 and c.B < 0.05
        if red and not wasRed then
            st.fails += 1
            table.insert(st.notes, string.format("FAIL(m=%.3f g=%.3f..%.3f focus=%s)", m, prevG, prevG + prevW, tostring(focused())))
        end
        wasRed = red
    end
    prevG, prevW = gr.Position.X.Scale, gr.Size.X.Scale

    local p  = gr.Position.X.Scale
    local w  = gr.Size.X.Scale
    local u7 = 1 - w

    -- direction + speed multiplier from observed motion
    if lastP and p ~= lastP then
        local dp = p - lastP
        local bounced = (p <= 1e-6) or (p >= u7 - 1e-6)
        if not bounced then
            dir = dp > 0 and 1 or -1
            if u7 > 0.01 and dt > 0 then
                local m = math.abs(dp) / (u7 * dt)
                if m > 0.2 and m < 5 then mult = mult + (m - mult) * 0.2 end
            end
        else
            dir = (p <= 1e-6) and 1 or -1
        end
    end
    lastP = p

    -- lag measurement: which of our past commands did the game just read?
    if mk and #hist >= 2 then
        local m = mk.Position.X.Scale
        local bestK, bestE = nil, 1.5 / fr.AbsoluteSize.X   -- within 1.5 px
        for k = 1, math.min(#hist, MAX_LAG_FRAMES) do
            local e = math.abs(hist[#hist - k + 1] - m)
            if e < bestE then bestE, bestK = e, k end
        end
        if bestK then lagF = lagF + (bestK - lagF) * 0.15 end
    end

    -- predict where Green will be when the game reads this move
    local frameDt = math.clamp(dt, 1/240, 1/20)
    local ahead   = math.max(lagF - 1, 0) * frameDt          -- lag 1 = next frame = current Green
    local q       = advance(p, dir, u7 * mult * ahead, u7)
    local target  = q + w * 0.5

    hist[#hist + 1] = target
    if #hist > MAX_LAG_FRAMES + 2 then table.remove(hist, 1) end

    local x = fr.AbsolutePosition.X + target * fr.AbsoluteSize.X
    local y = fr.AbsolutePosition.Y + fr.AbsoluteSize.Y * 0.5
    if focused() then
        mousemoveabs(math.floor(x + 0.5), math.floor(y + 0.5))
    end
end)

local keyConn = UIS.InputBegan:Connect(function(i)
    if i.KeyCode == Enum.KeyCode.End then
        enabled = not enabled
        print("[AUTO-VENT] " .. (enabled and "ON" or "OFF"))
    end
end)

G.__AUTOVENT3 = function() flush(); conn:Disconnect(); keyConn:Disconnect() end
G.__AUTOVENT3_LAG = function() return lagF, mult end
print("[AUTO-VENT v3] loaded (no hooks). Hold M1 in the vent. END = toggle.")
