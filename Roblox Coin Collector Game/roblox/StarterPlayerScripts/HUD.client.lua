--[[
    HUD.client.lua
    Place in: StarterPlayerScripts

    Displays a lightweight heads-up display showing the local player's
    current Score and Coins collected. Updates reactively whenever the
    server changes the leaderstats values.
--]]

-- ── Services ──────────────────────────────────────────────────────────────────
local Players     = game:GetService("Players")
local TweenService = game:GetService("TweenService")

-- ── Player & Character ────────────────────────────────────────────────────────
local localPlayer = Players.LocalPlayer

-- ── Build ScreenGui ───────────────────────────────────────────────────────────
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "CoinHUD"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = false
screenGui.Parent = localPlayer.PlayerGui

-- Outer container (top-left corner)
local container = Instance.new("Frame")
container.Name = "Container"
container.AnchorPoint = Vector2.new(0, 0)
container.Position = UDim2.new(0, 16, 0, 16)
container.Size = UDim2.new(0, 200, 0, 90)
container.BackgroundColor3 = Color3.fromRGB(15, 15, 30)
container.BackgroundTransparency = 0.25
container.BorderSizePixel = 0
container.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 12)
corner.Parent = container

local padding = Instance.new("UIPadding")
padding.PaddingLeft   = UDim.new(0, 12)
padding.PaddingRight  = UDim.new(0, 12)
padding.PaddingTop    = UDim.new(0, 8)
padding.PaddingBottom = UDim.new(0, 8)
padding.Parent = container

local layout = Instance.new("UIListLayout")
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Padding = UDim.new(0, 4)
layout.Parent = container

-- Helper: create a stat row
local function makeRow(icon: string, labelText: string, order: number): TextLabel
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 32)
    row.BackgroundTransparency = 1
    row.LayoutOrder = order
    row.Parent = container

    local iconLabel = Instance.new("TextLabel")
    iconLabel.Size = UDim2.new(0, 28, 1, 0)
    iconLabel.BackgroundTransparency = 1
    iconLabel.Text = icon
    iconLabel.TextScaled = true
    iconLabel.Font = Enum.Font.GothamBold
    iconLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
    iconLabel.Parent = row

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(0.5, -28, 1, 0)
    nameLabel.Position = UDim2.new(0, 32, 0, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = labelText
    nameLabel.TextScaled = true
    nameLabel.Font = Enum.Font.Gotham
    nameLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.Parent = row

    local valueLabel = Instance.new("TextLabel")
    valueLabel.Name = "Value"
    valueLabel.Size = UDim2.new(0.5, 0, 1, 0)
    valueLabel.Position = UDim2.new(0.5, 0, 0, 0)
    valueLabel.BackgroundTransparency = 1
    valueLabel.Text = "0"
    valueLabel.TextScaled = true
    valueLabel.Font = Enum.Font.GothamBold
    valueLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    valueLabel.TextXAlignment = Enum.TextXAlignment.Right
    valueLabel.Parent = row

    return valueLabel
end

local scoreValueLabel = makeRow("★", "Score", 1)
local coinsValueLabel = makeRow("◉", "Coins", 2)

-- ── Bump animation when a value changes ───────────────────────────────────────
local function bump(label: TextLabel)
    TweenService:Create(label, TweenInfo.new(0.1), { TextColor3 = Color3.fromRGB(255, 215, 0) }):Play()
    task.delay(0.1, function()
        TweenService:Create(label, TweenInfo.new(0.2), { TextColor3 = Color3.fromRGB(255, 255, 255) }):Play()
    end)
end

-- ── Connect to leaderstats ────────────────────────────────────────────────────
local function connectLeaderstats(leaderstats: Folder)
    local scoreValue = leaderstats:WaitForChild("Score",  10) :: IntValue
    local coinsValue = leaderstats:WaitForChild("Coins",  10) :: IntValue

    if scoreValue then
        scoreValueLabel.Text = tostring(scoreValue.Value)
        scoreValue.Changed:Connect(function(val: number)
            scoreValueLabel.Text = tostring(val)
            bump(scoreValueLabel)
        end)
    end

    if coinsValue then
        coinsValueLabel.Text = tostring(coinsValue.Value)
        coinsValue.Changed:Connect(function(val: number)
            coinsValueLabel.Text = tostring(val)
            bump(coinsValueLabel)
        end)
    end
end

-- Leaderstats may not exist yet if the server script hasn't run
local function waitForLeaderstats()
    local ls = localPlayer:FindFirstChild("leaderstats")
    if ls then
        connectLeaderstats(ls)
    else
        localPlayer.ChildAdded:Connect(function(child)
            if child.Name == "leaderstats" then
                connectLeaderstats(child)
            end
        end)
    end
end

waitForLeaderstats()
