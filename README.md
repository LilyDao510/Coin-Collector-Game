# Roblox Coin Collector

A Roblox game where players run around the map collecting glowing coins to earn points. Scores are synced to a Python backend that maintains a persistent global leaderboard across all sessions.

## Gameplay

- 20 spinning coins are scattered across the map at all times
- Touch a coin to collect it and earn **+10 points**
- Collected coins respawn after 3 seconds
- Your Score and Coins collected are shown in the top-left HUD
- The global leaderboard board in the world displays the top 10 players

## Architecture

```
Roblox Game (Lua/Luau)
│
├── CoinGame.server.lua          Spawns coins, handles collection, syncs scores
├── GlobalLeaderboard.server.lua Fetches top players and renders in-world board
└── HUD.client.lua               Local score display with live updates
         │
         │  HTTP (JSON)
         ▼
Python Flask Backend
│
├── POST /score                  Submit or update a player's score
├── GET  /leaderboard?limit=N    Retrieve top N players
└── GET  /score/<player>         Look up a single player's score
         │
         ▼
scores.json                      Persistent score storage
```

## Tech Stack

| Layer | Technology |
|---|---|
| Game engine | Roblox Studio |
| Game scripting | Lua / Luau |
| Backend | Python + Flask |
| Data format | JSON |
| Storage | Flat-file (`scores.json`) |

## Setup

### Backend

```bash
cd backend
pip install -r requirements.txt
python app.py
# Runs on http://localhost:5000
```

### Roblox Studio

1. Enable HTTP requests: **Game Settings > Security > Allow HTTP Requests = ON**
2. Copy scripts to their destinations:

| File | Destination |
|---|---|
| `CoinGame.server.lua` | `ServerScriptService` |
| `GlobalLeaderboard.server.lua` | `ServerScriptService` |
| `HUD.client.lua` | `StarterPlayerScripts` |

3. Add a `Part` to `Workspace` named `LeaderboardBoard` — the leaderboard GUI renders on its front face
4. Set `BACKEND_URL` in both server scripts to your Flask server address

> **Local testing:** Roblox Studio cannot reach `localhost` directly. Use [ngrok](https://ngrok.com) to create a public tunnel:
> ```bash
> ngrok http 5000
> # Copy the https URL into BACKEND_URL
> ```

## API Reference

| Method | Endpoint | Body / Params | Description |
|---|---|---|---|
| `POST` | `/score` | `{ player, userId, score }` | Submit a score (keeps highest) |
| `GET` | `/leaderboard` | `?limit=10` | Top N players ranked by score |
| `GET` | `/score/<name>` | — | Single player lookup |
| `DELETE` | `/reset` | — | Clear all scores (dev only) |
