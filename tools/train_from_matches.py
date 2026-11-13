#!/usr/bin/env python3
"""Train a small action-value Decision Tree from Godot battle_records.jsonl.

Each record is one enemy decision and contains features, chosen action, reward,
done and episode_id. The target is the discounted return from that decision.
This is an offline approximation from observed actions, not a guarantee of an
optimal policy. The game needs varied action coverage and many completed battles.
"""

from __future__ import annotations

import argparse
import json
import math
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any

import numpy as np
from sklearn.metrics import mean_absolute_error, r2_score
from sklearn.model_selection import GroupShuffleSplit
from sklearn.tree import DecisionTreeRegressor

FEATURES = [
    "enemy_hp_ratio",
    "player_hp_ratio",
    "enemy_damage",
    "player_expected_damage",
    "enhance_ready",
    "player_damage_to_enemy_ratio",
    "enemy_damage_to_player_ratio",
    "last_action_defense",
]
ACTIONS = ["ATTACK", "DEFENSE", "ENHANCE"]
INPUT_FEATURES = FEATURES + [f"action_{action}" for action in ACTIONS]


def load_records(path: Path) -> list[dict[str, Any]]:
    if not path.exists():
        raise FileNotFoundError(
            f"Record tidak ditemukan: {path}\nSalin battle_records.jsonl dari folder user:// Godot terlebih dahulu."
        )
    records: list[dict[str, Any]] = []
    with path.open("r", encoding="utf-8") as file:
        for line_number, line in enumerate(file, start=1):
            line = line.strip()
            if not line:
                continue
            try:
                record = json.loads(line)
            except json.JSONDecodeError as exc:
                print(f"Lewati baris {line_number} yang bukan JSON valid: {exc}")
                continue
            if not isinstance(record, dict):
                continue
            action = record.get("action")
            features = record.get("features")
            if action not in ACTIONS or not isinstance(features, dict):
                continue
            if not all(name in features for name in FEATURES):
                continue
            if not math.isfinite(float(record.get("reward", 0.0))):
                continue
            records.append(record)
    if not records:
        raise ValueError("Tidak ada record valid. Pastikan game sudah memainkan dan menyelesaikan battle.")
    return records


def make_training_data(records: list[dict[str, Any]], gamma: float) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    episodes: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for record in records:
        episodes[str(record.get("episode_id", "unknown"))].append(record)

    x_rows: list[list[float]] = []
    targets: list[float] = []
    groups: list[str] = []

    for episode_id, rows in episodes.items():
        rows.sort(key=lambda item: int(item.get("step", 0)))
        discounted_return = 0.0
        episode_samples: list[tuple[dict[str, Any], float]] = []
        for record in reversed(rows):
            reward = float(record.get("reward", 0.0))
            if bool(record.get("done", False)):
                discounted_return = reward
            else:
                discounted_return = reward + gamma * discounted_return
            episode_samples.append((record, discounted_return))
        for record, target in reversed(episode_samples):
            features = record["features"]
            action = str(record["action"])
            row = [float(features[name]) for name in FEATURES]
            row.extend(1.0 if action == candidate else 0.0 for candidate in ACTIONS)
            x_rows.append(row)
            targets.append(float(target))
            groups.append(episode_id)

    return np.asarray(x_rows, dtype=float), np.asarray(targets, dtype=float), np.asarray(groups, dtype=object)


def export_tree(model: DecisionTreeRegressor, output_path: Path) -> None:
    tree = model.tree_
    payload = {
        "model_name": "Biblioteka Match-Record Action Value Tree",
        "model_version": 1,
        "model_type": "action_value_regression",
        "training_source": "Godot battle_records.jsonl; discounted return from recorded matches",
        "features": FEATURES,
        "actions": ACTIONS,
        "input_features": INPUT_FEATURES,
        "children_left": tree.children_left.tolist(),
        "children_right": tree.children_right.tolist(),
        "feature": tree.feature.tolist(),
        "threshold": [float(value) for value in tree.threshold.tolist()],
        "value": [float(node[0][0]) for node in tree.value],
        "max_depth": int(model.get_depth()),
        "node_count": int(tree.node_count),
    }
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(payload, indent=2), encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--records", type=Path, default=Path("battle_records.jsonl"))
    parser.add_argument("--output", type=Path, default=Path("data/decision_tree_rewards.json"))
    parser.add_argument("--gamma", type=float, default=0.90, help="Discount factor for future battle rewards")
    parser.add_argument("--max-depth", type=int, default=5)
    parser.add_argument("--seed", type=int, default=42)
    args = parser.parse_args()

    records = load_records(args.records)
    x, y, groups = make_training_data(records, args.gamma)
    episode_count = len(set(groups.tolist()))
    action_counts = Counter(str(record["action"]) for record in records)

    print(f"Record keputusan: {len(records)}")
    print(f"Battle/episode: {episode_count}")
    print(f"Aksi tercatat: {dict(action_counts)}")

    if episode_count < 5:
        print("PERINGATAN: jumlah battle masih sedikit. Kumpulkan setidaknya 10-20 battle yang bervariasi sebelum mengandalkan model.")
    missing_actions = [action for action in ACTIONS if action_counts[action] == 0]
    if missing_actions:
        print(f"PERINGATAN: aksi ini belum pernah tercatat: {missing_actions}. Model tidak bisa memperkirakan nilainya dengan baik.")

    if episode_count >= 5 and len(records) >= 10:
        splitter = GroupShuffleSplit(n_splits=1, test_size=0.20, random_state=args.seed)
        train_indices, test_indices = next(splitter.split(x, y, groups))
        evaluation_model = DecisionTreeRegressor(
            max_depth=args.max_depth,
            min_samples_leaf=2,
            random_state=args.seed,
        )
        evaluation_model.fit(x[train_indices], y[train_indices])
        predictions = evaluation_model.predict(x[test_indices])
        print(f"Evaluasi holdout MAE: {mean_absolute_error(y[test_indices], predictions):.3f}")
        if len(test_indices) > 1 and float(np.var(y[test_indices])) > 1e-12:
            print(f"Evaluasi holdout R2: {r2_score(y[test_indices], predictions):.3f}")
        print("Evaluasi ini mengukur prediksi return dari data yang tercatat, bukan jaminan win rate lebih tinggi.")

    final_model = DecisionTreeRegressor(
        max_depth=args.max_depth,
        min_samples_leaf=2,
        random_state=args.seed,
    )
    final_model.fit(x, y)
    export_tree(final_model, args.output)
    print(f"Model disimpan ke: {args.output}")
    print("Salin/letakkan file tersebut pada data/decision_tree_rewards.json di root project Godot.")


if __name__ == "__main__":
    main()
