#!/usr/bin/env python3
"""Re-apply the new rubric importance policy to completed harbor trials.

Walks each trial dir under the given job paths, loads rubrics_results.json,
overrides each rubric's `importance` based on the rubric's hli_category
(looked up from data/rf/<task>/tests/rubrics.json), recomputes
must_have_pass / agg_score, and rewrites rubrics_results.json and reward.json
in place. Backs up originals with .old suffix on first run.

Policy:
  documentation maintainability  -> nice to have
  everything else                -> must have

Usage:
    python relabel_rubrics.py
"""

import json
import os
import sys
import glob
import collections

JOBS = [
    "/mnt/efs/mohitraghavendra/src/cae-eval/harbor_results/cae/rf_task/gpt-5p4-xhigh_codex",
    "/mnt/efs/mohitraghavendra/src/cae-eval/harbor_results/cae/rf_task/gpt-5p3-codex-xhigh_codex",
]
RAW = "/mnt/efs/mohitraghavendra/src/cae-eval/data/rf"


def cat_map_for(task_dir):
    """Build {rubric_id: hli_category} from the task's rubrics.json."""
    src = f"{task_dir}/tests/rubrics.json"
    if not os.path.exists(src):
        return {}
    out = {}
    for r in json.load(open(src)):
        ann = r.get("annotations") or {}
        out[r["id"]] = (ann.get("hli_category") or "").strip().lower()
    return out


def importance_for(category):
    return "nice to have" if category == "documentation maintainability" else "must have"


def relabel_trial(trial_dir, raw_lookup, dry_run=False):
    """Returns (changed, was_pass_old, was_pass_new, summary_dict)."""
    rr_path = f"{trial_dir}/verifier/rubrics_results.json"
    rj_path = f"{trial_dir}/verifier/reward.json"
    rt_path = f"{trial_dir}/verifier/reward.txt"
    cfg_path = f"{trial_dir}/config.json"

    if not (os.path.exists(rr_path) and os.path.exists(cfg_path)):
        return None

    cfg = json.load(open(cfg_path))
    full_id = os.path.basename((cfg.get("task") or {}).get("path", "")).replace("instance_refactor__", "")
    cat_map = raw_lookup.get(full_id)
    if cat_map is None:
        cat_map = cat_map_for(f"{RAW}/instance_refactor__{full_id}")
        raw_lookup[full_id] = cat_map

    if not cat_map:
        # Task no longer exists in data/rf (filtered out) — skip.
        return None

    rr = json.load(open(rr_path))
    rubric_scores = rr.get("rubric_scores", [])

    # Override importance per rubric. Track aggregate stats.
    must_have_count = 0
    evaluable_count = 0
    pass_count = 0
    must_have_fail = False

    for r in rubric_scores:
        rid = r.get("id")
        cat = cat_map.get(rid, "")
        new_imp = importance_for(cat)
        r["importance"] = new_imp
        if not r.get("evaluable", True):
            continue
        evaluable_count += 1
        if r.get("passes"):
            pass_count += 1
        if new_imp == "must have":
            must_have_count += 1
            if not r.get("passes"):
                must_have_fail = True

    must_have_pass = (must_have_count > 0) and (not must_have_fail)
    agg_score = (pass_count / evaluable_count) if evaluable_count else 0.0

    # Build new rubric_results
    new_rr = dict(rr)
    new_rr["must_have_pass"] = must_have_pass
    new_rr["agg_score"] = agg_score
    new_rr["evaluable_count"] = evaluable_count
    new_rr["must_have_count"] = must_have_count
    new_rr["rubric_scores"] = rubric_scores
    new_rr["_relabeled"] = True

    # Update reward
    tests_reward = 0.0
    if os.path.exists(rj_path):
        rd = json.load(open(rj_path))
        tests_reward = float(rd.get("tests_reward", 0) or 0)
    new_reward = 1.0 if (tests_reward >= 1.0 and must_have_pass) else 0.0

    new_rj = {
        "reward": new_reward,
        "tests_reward": tests_reward,
        "must_have_pass": must_have_pass,
        "rubrics_agg_score": agg_score,
        "overall_pass": (tests_reward >= 1.0 and must_have_pass),
        "_relabeled": True,
    }

    if dry_run:
        return {
            "must_have_pass_old": rr.get("must_have_pass"),
            "must_have_pass_new": must_have_pass,
            "reward_old": json.load(open(rj_path)).get("reward") if os.path.exists(rj_path) else None,
            "reward_new": new_reward,
            "agg_old": rr.get("agg_score"),
            "agg_new": agg_score,
        }

    # Backup originals once.
    if not os.path.exists(rr_path + ".old"):
        os.rename(rr_path, rr_path + ".old")
    if os.path.exists(rj_path) and not os.path.exists(rj_path + ".old"):
        os.rename(rj_path, rj_path + ".old")
    if os.path.exists(rt_path) and not os.path.exists(rt_path + ".old"):
        os.rename(rt_path, rt_path + ".old")

    with open(rr_path, "w") as f:
        json.dump(new_rr, f, indent=2)
    with open(rj_path, "w") as f:
        json.dump(new_rj, f, indent=2)
    with open(rt_path, "w") as f:
        f.write(str(new_reward))

    return {
        "must_have_pass_old": rr.get("must_have_pass"),
        "must_have_pass_new": must_have_pass,
        "reward_new": new_reward,
        "agg_old": rr.get("agg_score"),
        "agg_new": agg_score,
    }


def main():
    dry_run = "--dry-run" in sys.argv

    raw_lookup = {}
    for job in JOBS:
        if not os.path.isdir(job):
            print(f"SKIP missing job dir: {job}")
            continue
        print(f"\n=== {os.path.basename(job)} ===")
        n_total = n_changed = n_skip = 0
        rwd_old = rwd_new = collections.Counter()
        for trial in sorted(glob.glob(f"{job}/instance_refactor__*")):
            res = relabel_trial(trial, raw_lookup, dry_run=dry_run)
            n_total += 1
            if res is None:
                n_skip += 1
                continue
            if res["must_have_pass_old"] != res["must_have_pass_new"]:
                n_changed += 1
            rwd_old[res.get("reward_old", "n/a") if dry_run else "n/a"] += 1
            rwd_new[res["reward_new"]] += 1
        print(f"  trials seen: {n_total}, skipped: {n_skip}, must_have_pass changed: {n_changed}")
        print(f"  new reward distribution: {dict(rwd_new)}")
        if dry_run:
            print(f"  (DRY RUN — no files written)")


if __name__ == "__main__":
    main()
