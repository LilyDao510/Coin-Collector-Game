--[[
    GlobalLeaderboard.server.lua
    Place in: ServerScriptService

    Fetches the top 10 players from the Flask backend and displays them
    on a SurfaceGui billboard placed in the world.

    SETUP:
      1. Create a Part in the workspace named "LeaderboardBoard".
         This script will attach a SurfaceGui to its front face.
      2. Ensure BACKEND_URL matches the value in CoinGame.server.lua.
--]]

-- ── Services ──────────────────────────────────────────────────────────────────
local HttpService = game:GetService("HttpService")

-- ── Configuration ─────────────────────────────────────────────────────────────
local BACKEND_URL      = "http://localhost:5000"  -- Must match CoinGame.server.lua
local REFRESH_INTERVAL = 30   -- Seconds between leaderboard refreshes
local TOP_COUNT        = 10   -- How many players to display
local BOARD_PART_NAME  = "LeaderboardBoard"

-- ── Build the SurfaceGui ──────────────────────────────────────────────────────
local function buildGui(boardPart: BasePart): Frame
    -- Remove any existing gui
    local existing = boardPart:FindFirstChild("LeaderboardGui")
    if existing then existing:Destroy() end

    local surfaceGui = Instance.new("SurfaceGui")
    surfaceGui.Name = "LeaderboardGui"
    surfaceGui.Face = Enum.NormalId.Front
    surfaceGui.CanvasSize = Vector2.new(400, 600)
    surfaceGui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
    surfaceGui.Parent = boardPart

    -- Background
    local bg = Instance.new("Frame")
    bg.Size = UDim2.new(1, 0, 1, 0)
    bg.BackgroundColor3 = Color3.fromRGB(15, 15, 30)
    bg.BorderSizePixel = 0
    bg.Parent = surfaceGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = bg

    -- Title
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 70)
    title.Position = UDim2.new(0, 0, 0, 10)
    title.BackgroundTransparency = 1
    title.Text = "GLOBAL LEADERBOARD"
    title.TextColor3 = Color3.fromRGB(255, 215, 0)
    title.TextScaled = true
    title.Font = Enum.Font.GothamBold
    title.Parent = bg

    -- List container
    local list = Instance.new("Frame")
    list.Name = "List"
    list.Size = UDim2.new(1, -20, 1, -100)
    list.Position = UDim2.new(0, 10, 0, 90)
    list.BackgroundTransparency = 1
    list.Parent = bg

    local layout = Instance.new("UIListLayout")
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 6)
    layout.Parent = list

    return list
end

local function makeRowColor(rank: number): Color3
    if rank == 1 then return Color3.fromRGB(255, 215, 0)   end  -- Gold
    if rank == 2 then return Color3.fromRGB(192, 192, 192) end  -- Silver
    if rank == 3 then return Color3.fromRGB(205, 127, 50)  end  -- Bronze
    return Color3.fromRGB(200, 200, 200)
end

local function populateList(list: Frame, entries: { { rank: number, player: string, score: number } })
    -- Clear old rows
    for _, child in list:GetChildren() do
        if child:IsA("Frame") then child:Destroy() end
    end

    if #entries == 0 then
        local empty = Instance.new("TextLabel")
        empty.Size = UDim2.new(1, 0, 0, 40)
        empty.BackgroundTransparency = 1
        empty.Text = "No scores yet!"
        empty.TextColor3 = Color3.fromRGB(150, 150, 150)
        empty.TextScaled = true
        empty.Font = Enum.Font.Gotham
        empty.Parent = list
        return
    end

    for _, entry in entries do
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, 0, 0, 44)
        row.BackgroundColor3 = Color3.fromRGB(30, 30, 55)
        row.BorderSizePixel = 0
        row.LayoutOrder = entry.rank
        row.Parent = list

        local rowCorner = Instance.new("UICorner")
        rowCorner.CornerRadius = UDim.new(0, 8)
        rowCorner.Parent = row

        -- Rank
        local rankLabel = Instance.new("TextLabel")
        rankLabel.Size = UDim2.new(0, 50, 1, 0)
        rankLabel.Position = UDim2.new(0, 8, 0, 0)
        rankLabel.BackgroundTransparency = 1
        rankLabel.Text = "#" .. entry.rank
        rankLabel.TextColor3 = makeRowColor(entry.rank)
        rankLabel.TextScaled = true
        rankLabel.Font = Enum.Font.GothamBold
        rankLabel.Parent = row

        -- Player name
        local nameLabel = Instance.new("TextLabel")
        nameLabel.Size = UDim2.new(0.55, 0, 1, 0)
        nameLabel.Position = UDim2.new(0, 65, 0, 0)
        nameLabel.BackgroundTransparency = 1
        nameLabel.Text = entry.player
        nameLabel.TextColor3 = Color3.fromRGB(240, 240, 240)
        nameLabel.TextScaled = true
        nameLabel.Font = Enum.Font.Gotham
        nameLabel.TextXAlignment = Enum.TextXAlignment.Left
        nameLabel.Parent = row

        -- Score
        local scoreLabel = Instance.new("TextLabel")
        scoreLabel.Size = UDim2.new(0, 90, 1, 0)
        scoreLabel.Position = UDim2.new(1, -98, 0, 0)
        scoreLabel.BackgroundTransparency = 1
        scoreLabel.Text = tostring(entry.score) .. " pts"
        scoreLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
        scoreLabel.TextScaled = true
        scoreLabel.Font = Enum.Font.GothamBold
        scoreLabel.TextXAlignment = Enum.TextXAlignment.Right
        scoreLabel.Parent = row
    end
end

-- ── Fetch & Refresh ───────────────────────────────────────────────────────────
local function fetchLeaderboard(): { { rank: number, player: string, score: number } }
    local ok, result = pcall(function()
        local response = HttpService:GetAsync(
            ("%s/leaderboard?limit=%d"):format(BACKEND_URL, TOP_COUNT)
        )
        return HttpService:JSONDecode(response)
    end)

    if not ok then
        warn(("[GlobalLeaderboard] Fetch failed: %s"):format(tostring(result)))
        return {}
    end

    return result.leaderboard or {}
end

local function refresh(list: Frame)
    local entries = fetchLeaderboard()
    populateList(list, entries)
end

-- ── Initialise ────────────────────────────────────────────────────────────────
local boardPart = workspace:FindFirstChild(BOARD_PART_NAME)
if not boardPart then
    warn(("[GlobalLeaderboard] Could not find a Part named '%s' in Workspace. ")
        :format(BOARD_PART_NAME)
        .. "Create one and re-run, or the leaderboard board will not appear.")
else
    local list = buildGui(boardPart :: BasePart)

    -- Initial populate
    refresh(list)

    -- Periodic refresh
    while true do
        task.wait(REFRESH_INTERVAL)
        refresh(list)
    end
end
