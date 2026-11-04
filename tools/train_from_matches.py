#!/usr/bin/env python3
"""Latih decision tree nilai-aksi dari battle_records.jsonl milik Godot.

Setiap record adalah satu keputusan musuh: fitur, aksi, reward, done, episode_id.
Target latihan adalah discounted return dari keputusan itu.

Versi 2: satu pohon PER AKSI (ATTACK, DEFENSE, ENHANCE). Model lama memakai satu pohon
dengan aksi sebagai input one-hot, dan pohon itu bisa saja tidak pernah membelah di fitur
aksi, sehingga semua aksi dinilai sama dan musuh selalu memilih ATTACK. Dengan satu pohon
per aksi, setiap aksi pasti punya nilainya sendiri.

Ini perkiraan offline dari aksi yang pernah tercatat, bukan jaminan kebijakan optimal.
Model ditandai "reliable" hanya jika datanya cukup. Kalau belum, game memakai starter policy.
"""

from __future__ import annotations

import argparse
import json
import math
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any

import numpy as np
from sklearn.metrics import mean_absolute_error
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

MIN_EPISODES = 10           # battle minimum agar model dianggap bisa diandalkan
MIN_SAMPLES_PER_ACTION = 5  # keputusan minimum per aksi untuk melatih pohon aksi itu


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


def make_training_data(
    records: list[dict[str, Any]], gamma: float
) -> tuple[np.ndarray, np.ndarray, np.ndarray, np.ndarray]:
    episodes: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for record in records:
        episodes[str(record.get("episode_id", "unknown"))].append(record)

    x_rows: list[list[float]] = []
    targets: list[float] = []
    groups: list[str] = []
    actions: list[str] = []

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
            x_rows.append([float(features[name]) for name in FEATURES])
            targets.append(float(target))
            groups.append(episode_id)
            actions.append(str(record["action"]))

    return (
        np.asarray(x_rows, dtype=float),
        np.asarray(targets, dtype=float),
        np.asarray(groups, dtype=object),
        np.asarray(actions, dtype=object),
    )


def fit_action_trees(
    x: np.ndarray, y: np.ndarray, acts: np.ndarray, max_depth: int, seed: int
) -> dict[str, DecisionTreeRegressor]:
    trees: dict[str, DecisionTreeRegressor] = {}
    for action in ACTIONS:
        mask = acts == action
        if int(mask.sum()) < MIN_SAMPLES_PER_ACTION:
            continue
        tree = DecisionTreeRegressor(max_depth=max_depth, min_samples_leaf=2, random_state=seed)
        tree.fit(x[mask], y[mask])
        trees[action] = tree
    return trees


def tree_to_dict(model: DecisionTreeRegressor) -> dict[str, Any]:
    tree = model.tree_
    return {
        "children_left": tree.children_left.tolist(),
        "children_right": tree.children_right.tolist(),
        "feature": tree.feature.tolist(),
        "threshold": [float(value) for value in tree.threshold.tolist()],
        "value": [float(node[0][0]) for node in tree.value],
        "max_depth": int(model.get_depth()),
        "node_count": int(tree.node_count),
    }


def export_model(
    trees: dict[str, DecisionTreeRegressor],
    output_path: Path,
    episode_count: int,
    record_count: int,
    action_counts: Counter,
    reliable: bool,
) -> None:
    payload = {
        "model_name": "Biblioteka Match-Record Action Value Trees",
        "model_version": 2,
        "model_type": "action_value_regression",
        "training_source": "Godot battle_records.jsonl; discounted return from recorded matches",
        "features": FEATURES,
        "actions": ACTIONS,
        "reliable": reliable,
        "episodes": episode_count,
        "records": record_count,
        "action_counts": {action: int(action_counts[action]) for action in ACTIONS},
        "trees": {action: tree_to_dict(model) for action, model in trees.items()},
    }
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(payload, indent=2), encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--records", type=Path, default=Path("battle_records.jsonl"))
    parser.add_argument("--output", type=Path, default=Path("data/decision_tree_rewards.json"))
    parser.add_argument("--gamma", type=float, default=0.90, help="Discount factor for future battle rewards")
    parser.add_argument("--max-depth", type=int, default=3)
    parser.add_argument("--seed", type=int, default=42)
    args = parser.parse_args()

    records = load_records(args.records)
    x, y, groups, acts = make_training_data(records, args.gamma)
    episode_count = len(set(groups.tolist()))
    action_counts = Counter(str(record["action"]) for record in records)

    print(f"Record keputusan: {len(records)}")
    print(f"Battle/episode: {episode_count}")
    print(f"Aksi tercatat: {dict(action_counts)}")

    if episode_count < MIN_EPISODES:
        print(f"PERINGATAN: baru {episode_count} battle. Kumpulkan setidaknya {MIN_EPISODES}-20 battle yang bervariasi.")
    missing_actions = [action for action in ACTIONS if action_counts[action] < MIN_SAMPLES_PER_ACTION]
    if missing_actions:
        print(f"PERINGATAN: aksi ini kurang dari {MIN_SAMPLES_PER_ACTION} sampel: {missing_actions}.")

    if episode_count >= 5 and len(records) >= 10:
        splitter = GroupShuffleSplit(n_splits=1, test_size=0.20, random_state=args.seed)
        train_idx, test_idx = next(splitter.split(x, y, groups))
        eval_trees = fit_action_trees(x[train_idx], y[train_idx], acts[train_idx], args.max_depth, args.seed)
        errors = []
        for i in test_idx:
            model = eval_trees.get(str(acts[i]))
            if model is not None:
                errors.append((y[i], float(model.predict(x[i : i + 1])[0])))
        if errors:
            truth, pred = zip(*errors)
            print(f"Evaluasi holdout MAE: {mean_absolute_error(truth, pred):.3f} ({len(errors)} sampel)")
            print("Evaluasi ini mengukur prediksi return dari data tercatat, bukan jaminan win rate lebih tinggi.")

    trees = fit_action_trees(x, y, acts, args.max_depth, args.seed)
    reliable = episode_count >= MIN_EPISODES and len(trees) == len(ACTIONS)
    export_model(trees, args.output, episode_count, len(records), action_counts, reliable)
    print(f"Pohon dilatih untuk aksi: {list(trees.keys())}")
    print(f"Model disimpan ke: {args.output}")
    if reliable:
        print("Model ditandai reliable: game akan memakainya.")
    else:
        print("Model BELUM reliable: game tetap memakai starter policy sambil terus mengumpulkan data.")
    print("Salin/letakkan file tersebut pada data/decision_tree_rewards.json di root project Godot.")


if __name__ == "__main__":
    main()