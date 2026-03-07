from flask import Flask, request, jsonify
import json
import os
from datetime import datetime, timezone

app = Flask(__name__)

SCORES_FILE = "scores.json"


def load_scores() -> dict:
    if os.path.exists(SCORES_FILE):
        with open(SCORES_FILE, "r") as f:
            return json.load(f)
    return {}


def save_scores(scores: dict) -> None:
    with open(SCORES_FILE, "w") as f:
        json.dump(scores, f, indent=2)


@app.route("/score", methods=["POST"])
def submit_score():
    """Accept a score submission from the Roblox game server."""
    data = request.get_json(silent=True)

    if not data or "player" not in data or "score" not in data:
        return jsonify({"error": "Missing required fields: player, score"}), 400

    player_name = str(data["player"])
    new_score = int(data["score"])

    if new_score < 0:
        return jsonify({"error": "Score must be non-negative"}), 400

    scores = load_scores()

    existing = scores.get(player_name, {})
    if new_score >= existing.get("score", -1):
        scores[player_name] = {
            "score": new_score,
            "userId": data.get("userId"),
            "lastUpdated": datetime.now(timezone.utc).isoformat(),
        }
        save_scores(scores)

    return jsonify({"status": "ok", "player": player_name, "score": scores[player_name]["score"]})


@app.route("/leaderboard", methods=["GET"])
def get_leaderboard():
    """Return the top N players sorted by score descending."""
    limit = request.args.get("limit", 10, type=int)
    limit = max(1, min(limit, 100))  # clamp between 1 and 100

    scores = load_scores()

    ranked = sorted(scores.items(), key=lambda x: x[1]["score"], reverse=True)[:limit]

    leaderboard = [
        {
            "rank": i + 1,
            "player": name,
            "score": entry["score"],
            "lastUpdated": entry.get("lastUpdated"),
        }
        for i, (name, entry) in enumerate(ranked)
    ]

    return jsonify({"leaderboard": leaderboard, "total_players": len(scores)})


@app.route("/score/<player_name>", methods=["GET"])
def get_player_score(player_name: str):
    """Return the score record for a specific player."""
    scores = load_scores()
    entry = scores.get(player_name)

    if entry is None:
        return jsonify({"error": "Player not found"}), 404

    return jsonify({"player": player_name, **entry})


@app.route("/reset", methods=["DELETE"])
def reset_scores():
    """Clear all scores (dev/admin use only)."""
    save_scores({})
    return jsonify({"status": "ok", "message": "All scores cleared"})


if __name__ == "__main__":
    app.run(debug=True, host="0.0.0.0", port=5000)
