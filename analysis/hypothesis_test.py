#!/usr/bin/env python3
"""Hypothesis testing for the empirical study (H0 / H1 from PLAN.md).

For each metric and endpoint, compares ARM64 (test) vs x86_64 (control):

    * joules_per_request    -- H0 metric (energy efficiency)
    * rps_per_watt          -- H1 metric (throughput per watt)
    * gco2e_per_1m_requests -- H1 metric (operational carbon)
    * p95_ms / p99_ms       -- latency-penalty requirement of H1

Uses a Welch two-sample t-test (no equal-variance assumption) plus Cohen's d
effect size. Rejects H0 when p <= 0.05. Assumes >= 2 repetitions per group.

Author & Principal Researcher: Pham Hong Phat.
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import numpy as np
import pandas as pd
from scipy import stats

METRICS = ["joules_per_request", "rps_per_watt", "gco2e_per_1m_requests",
           "p95_ms", "p99_ms"]
ALPHA = 0.05


def welch_compare(control: np.ndarray, test: np.ndarray, metric: str) -> dict:
    if len(control) < 2 or len(test) < 2:
        return {"metric": metric, "supported": False,
                "note": "need >=2 reps per group"}
    t, p = stats.ttest_ind(control, test, equal_var=False)
    pooled = np.sqrt((np.std(control, ddof=1) ** 2 + np.std(test, ddof=1) ** 2) / 2)
    cohen_d = (np.mean(test) - np.mean(control)) / pooled if pooled > 0 else np.nan
    delta_pct = (np.mean(test) / np.mean(control) - 1) * 100 if np.mean(control) else np.nan
    return {
        "metric": metric,
        "supported": True,
        "mean_control": round(float(np.mean(control)), 6),
        "mean_test": round(float(np.mean(test)), 6),
        "delta_test_vs_control_pct": round(float(delta_pct), 2),
        "t": round(float(t), 4),
        "p_value": round(float(p), 6),
        "cohen_d": round(float(cohen_d), 4),
        "reject_h0": bool(p <= ALPHA),
    }


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--csv", default="results/aggregated.csv")
    ap.add_argument("--alpha", type=float, default=ALPHA)
    ap.add_argument("--out-json", default="results/hypothesis.json")
    args = ap.parse_args()

    df = pd.read_csv(args.csv)
    df = df.dropna(subset=["group", "arch"])
    endpoints = df["endpoint"].unique() if "endpoint" in df.columns else [None]

    results = []
    for ep in endpoints:
        control = df[(df["arch"] == "x86_64") & (df["endpoint"].eq(ep))] \
            if "endpoint" in df.columns else df[df["arch"] == "x86_64"]
        test = df[(df["arch"] == "arm64") & (df["endpoint"].eq(ep))] \
            if "endpoint" in df.columns else df[df["arch"] == "arm64"]
        for metric in METRICS:
            if metric not in df.columns:
                continue
            c = control[metric].dropna().to_numpy(dtype=float)
            t = test[metric].dropna().to_numpy(dtype=float)
            if len(c) == 0 or len(t) == 0:
                continue
            r = welch_compare(c, t, metric)
            r["endpoint"] = ep
            results.append(r)

    out = {
        "alpha": args.alpha,
        "summary": f"Welch two-sample t-test; reject H0 iff p<{args.alpha}",
        "results": results,
    }
    with Path(args.out_json).open("w") as f:
        json.dump(out, f, indent=2)
    print(json.dumps(out, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
