--[[
    CoinGame.server.lua
    Place in: ServerScriptService

    Responsibilities:
      - Sets up leaderstats (Score, Coins) for every player
      - Spawns spinning coin parts around the map
      - Awards points when a player touches a coin
      - Respawns coins after collection
      - Periodically POSTs each player's score to the Flask backend

    SETUP:
      1. Enable HttpService in Roblox Studio:
         Game Settings > Security > Allow HTTP Requests = ON
      2. Set BACKEND_URL to your Flask server address.
         For local testing with Roblox Studio use a tool like
         ngrok to expose localhost, e.g. "https://xxxx.ngrok.io"
--]]

-- ── Services ──────────────────────────────────────────────────────────────────
local Players    = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local RunService  = game:GetService("RunService")

-- ── Configuration ─────────────────────────────────────────────────────────────
local CONFIG = {
    BACKEND_URL        = "http://localhost:5000",  -- Change to your server URL
    COIN_COUNT         = 20,    -- Active coins in the world at once
    COIN_VALUE         = 10,    -- Points per coin
    COIN_RESPAWN_DELAY = 3,     -- Seconds before a collected coin respawns
    SCORE_SYNC_INTERVAL = 30,   -- Seconds between automatic score syncs
    MAP_HALF_SIZE      = 60,    -- Coins spawn within a square of this half-width
    COIN_HEIGHT        = 2,     -- Stud height above ground
}

-- ── Coin Factory ──────────────────────────────────────────────────────────────
local function buildCoinLabel(parent: BasePart)
    local gui = Instance.new("BillboardGui")
    gui.Size = UDim2.new(0, 60, 0, 30)
    gui.StudsOffset = Vector3.new(0, 2.5, 0)
    gui.AlwaysOnTop = false
    gui.Parent = parent

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = "+" .. CONFIG.COIN_VALUE
    label.TextColor3 = Color3.fromRGB(255, 215, 0)
    label.TextScaled = true
    label.Font = Enum.Font.GothamBold
    label.Parent = gui
end

local function createCoin(): BasePart
    local coin = Instance.new("Part")
    coin.Name = "Coin"
    coin.Size = Vector3.new(2, 0.4, 2)
    coin.Shape = Enum.PartType.Cylinder
    coin.Material = Enum.Material.Neon
    coin.BrickColor = BrickColor.new("Bright yellow")
    coin.CastShadow = false
    coin.CanCollide = false
    coin.Anchored = true
    -- Rotate flat so the cylinder face points up
    coin.CFrame = CFrame.Angles(0, 0, math.rad(90))
    buildCoinLabel(coin)
    return coin
end

-- ── Coin Spawning ─────────────────────────────────────────────────────────────
local activeCoins: { [BasePart]: boolean } = {}

local function spawnCoin()
    local coin = createCoin()

    local x = math.random(-CONFIG.MAP_HALF_SIZE, CONFIG.MAP_HALF_SIZE)
    local z = math.random(-CONFIG.MAP_HALF_SIZE, CONFIG.MAP_HALF_SIZE)
    coin.CFrame = CFrame.new(x, CONFIG.COIN_HEIGHT, z) * CFrame.Angles(0, 0, math.rad(90))
    coin.Parent = workspace

    activeCoins[coin] = true

    -- Spin animation
    local spinConnection: RBXScriptConnection
    spinConnection = RunService.Heartbeat:Connect(function(dt: number)
        if coin.Parent then
            coin.CFrame = coin.CFrame * CFrame.Angles(math.rad(120) * dt, 0, 0)
        else
            spinConnection:Disconnect()
        end
    end)

    -- Collection handler
    coin.Touched:Connect(function(hit: BasePart)
        if not activeCoins[coin] then return end  -- already collected

        local character = hit.Parent
        local player = Players:GetPlayerFromCharacter(character)
        if not player then return end

        -- Mark as collected immediately to prevent double-award
        activeCoins[coin] = nil
        coin:Destroy()
        spinConnection:Disconnect()

        -- Award points
        local leaderstats = player:FindFirstChild("leaderstats")
        if leaderstats then
            local scoreValue = leaderstats:FindFirstChild("Score")
            local coinsValue = leaderstats:FindFirstChild("Coins")
            if scoreValue then scoreValue.Value += CONFIG.COIN_VALUE end
            if coinsValue then coinsValue.Value += 1 end
        end

        -- Respawn after delay
        task.delay(CONFIG.COIN_RESPAWN_DELAY, spawnCoin)
    end)
end

-- ── Leaderstats Setup ─────────────────────────────────────────────────────────
local function setupLeaderstats(player: Player)
    local leaderstats = Instance.new("Folder")
    leaderstats.Name = "leaderstats"
    leaderstats.Parent = player

    local score = Instance.new("IntValue")
    score.Name = "Score"
    score.Value = 0
    score.Parent = leaderstats

    local coins = Instance.new("IntValue")
    coins.Name = "Coins"
    coins.Value = 0
    coins.Parent = leaderstats
end

-- ── Backend Communication ─────────────────────────────────────────────────────
local function postScore(player: Player)
    local leaderstats = player:FindFirstChild("leaderstats")
    if not leaderstats then return end

    local scoreValue = leaderstats:FindFirstChild("Score")
    if not scoreValue then return end

    local payload = HttpService:JSONEncode({
        player = player.Name,
        userId = player.UserId,
        score  = scoreValue.Value,
    })

    local ok, err = pcall(function()
        HttpService:PostAsync(
            CONFIG.BACKEND_URL .. "/score",
            payload,
            Enum.HttpContentType.ApplicationJson
        )
    end)

    if not ok then
        warn(("[CoinGame] Score sync failed for %s: %s"):format(player.Name, tostring(err)))
    end
end

local function syncAllScores()
    for _, player in Players:GetPlayers() do
        task.spawn(postScore, player)
    end
end

-- ── Player Events ─────────────────────────────────────────────────────────────
Players.PlayerAdded:Connect(function(player: Player)
    setupLeaderstats(player)
end)

Players.PlayerRemoving:Connect(function(player: Player)
    -- Send final score before the player fully disconnects
    postScore(player)
end)

-- Handle players who joined before this script loaded (Studio play-test)
for _, player in Players:GetPlayers() do
    setupLeaderstats(player)
end

-- ── Initialise World ──────────────────────────────────────────────────────────
for _ = 1, CONFIG.COIN_COUNT do
    spawnCoin()
end

-- Periodic score sync loop (runs on the server thread)
while true do
    task.wait(CONFIG.SCORE_SYNC_INTERVAL)
    syncAllScores()
end
