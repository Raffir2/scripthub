-- Spellbound Book Auto-Collector (legit farm)
-- Roams to every BookDrop pickup, fires its ProximityPrompt, loops for respawns.
-- Stop with:  getgenv().StopBookFarm()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local lp = Players.LocalPlayer

getgenv().BookFarmRunning = true
getgenv().StopBookFarm = function()
    getgenv().BookFarmRunning = false
    warn("[BookFarm] stop requested")
end

local function getHRP()
    local char = lp.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

-- Find a world position for a prompt (attachment or nearest BasePart ancestor)
local function promptPosition(prompt)
    local p = prompt.Parent
    if p and p:IsA("Attachment") then return p.WorldPosition end
    if p and p:IsA("BasePart") then return p.Position end
    local anc = prompt:FindFirstAncestorWhichIsA("BasePart")
    return anc and anc.Position
end

-- Collect all live book prompts
local function gatherBookPrompts()
    local out = {}
    for _, d in ipairs(workspace:GetDescendants()) do
        if d:IsA("ProximityPrompt") and d.Enabled then
            local drop = d:FindFirstAncestor("BookDrop")
            if drop then out[#out+1] = d end
        end
    end
    return out
end

local collected = 0
task.spawn(function()
    while getgenv().BookFarmRunning do
        local prompts = gatherBookPrompts()
        if #prompts == 0 then
            task.wait(3) -- nothing spawned; wait for respawns
        else
            for _, prompt in ipairs(prompts) do
                if not getgenv().BookFarmRunning then break end
                local hrp = getHRP()
                local pos = promptPosition(prompt)
                if hrp and pos then
                    -- hop next to the book so the server sees us in range
                    hrp.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0))
                    task.wait(0.15)
                    pcall(function()
                        fireproximityprompt(prompt, prompt.HoldDuration or 0)
                    end)
                    collected += 1
                    task.wait(0.25)
                end
            end
        end
    end
    warn(string.format("[BookFarm] stopped. prompt-fires this run: %d", collected))
end)

print("[BookFarm] started. Books on map right now:", #gatherBookPrompts(), "| stop with getgenv().StopBookFarm()")
