#!/usr/bin/env python3
"""Aggregate per-run summary.json files into a tidy dataset and optionally merge
k6 latency percentiles for the latency-penalty part of H1 (p95/p99).

Outputs ``results/aggregated.csv`` with one row per (run, group, arch, endpoint).
"""
from __future__ import annotations

import argparse
import csv
import json
import sys
from pathlib import Path


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--results", default="results", help="root results directory")
    ap.add_argument("--out", default="results/aggregated.csv", help="output csv")
    args = ap.parse_args()

    root = Path(args.results)
    rows = []
    for summary_file in sorted(root.rglob("summary.json")):
        with summary_file.open() as f:
            s = json.load(f)

        # Attempt to attach k6 latency percentiles from a sibling <run>_<ep>.json
        # produced by the loadgen (RESULT_FILE) if present.
        lat = {}
        for k6 in sorted(summary_file.parent.glob("*-r*.json")):
            try:
                with k6.open() as f:
                    k6d = json.load(f)
                lat = k6d.get("http_req_duration", {})
            except Exception:
                continue
            break

        row = {
            "group": s.get("group"),
            "arch": s.get("arch"),
            "start": s.get("start"),
            "duration_s": s.get("duration_s"),
            "requests": s.get("requests"),
            "rps": s.get("rps"),
            "energy_joules": s.get("energy_joules"),
            "mean_power_w": s.get("mean_power_w"),
            "joules_per_request": s.get("joules_per_request"),
            "rps_per_watt": s.get("rps_per_watt"),
            "gco2e_per_1m_requests": s.get("gco2e_per_1m_requests"),
            "p50_ms": lat.get("p50_ms"),
            "p95_ms": lat.get("p95_ms"),
            "p99_ms": lat.get("p99_ms"),
        }
        rows.append(row)

    if not rows:
        print("no summary.json found under", root, file=sys.stderr)
        return 1

    with Path(args.out).open("w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
        writer.writeheader()
        writer.writerows(rows)

    print(f"wrote {len(rows)} rows to {args.out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
