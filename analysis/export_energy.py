#!/usr/bin/env python3
"""Export and derive the energy/throughput metrics for one SUT from Prometheus.

Produces the raw (csv) energy time-series and a per-run ``summary.csv`` with the
study's primary metrics:

    * throughput            RPS (requests/s)
    * energy_joules         total CPU energy (J) consumed during the run
    * joules_per_request    energy / requests          [H0/H1 core metric]
    * rps_per_watt          throughput / mean power    [H1 core metric]
    * gco2e_per_1m_requests operational carbon per 1M requests (gCO2e)

Author & Principal Researcher: Pham Hong Phat.
"""
from __future__ import annotations

import argparse
import json
import math
import sys
from pathlib import Path

import requests

DEFAULT_PROM = "http://localhost:9090"

# Operational carbon intensity in gCO2e / kWh.
# Load data from the grid region being measured; this is a placeholder default
# (average US 2023 mix) and should be replaced with the experiment's regional
# carbon intensity before drawing conclusions.
DEFAULT_CARBON_INTENSITY_GCO2_PER_KWH = 380.0


def query_range(prom: str, query: str, start: str, end: str, step: str = "10s"):
    params = {"query": query, "start": start, "end": end, "step": step}
    r = requests.get(f"{prom}/api/v1/query_range", params=params, timeout=60)
    r.raise_for_status()
    data = r.json()["data"]["result"]
    return data


def extract_series(result, label: str) -> list[float]:
    """Return the first series' values as floats (ordered by time)."""
    if not result:
        return []
    values = result[0].get("values", [])
    return [float(v[1]) for _, v in values]


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--prom", default=DEFAULT_PROM, help="Prometheus base URL")
    ap.add_argument("--group", required=True, help="control|test")
    ap.add_argument("--arch", required=True, help="x86_64|arm64")
    ap.add_argument("--start", required=True, help="ISO/epoch start of window")
    ap.add_argument("--end", required=True, help="ISO/epoch end of window")
    ap.add_argument("--step", default="10s", help="step for query_range")
    ap.add_argument("--rps", type=float, default=0.0, help="measured RPS override")
    ap.add_argument("--requests", type=int, default=0, help="total request count")
    ap.add_argument("--out", required=True, help="output directory")
    ap.add_argument("--carbon-gco2-per-kwh", type=float,
                    default=DEFAULT_CARBON_INTENSITY_GCO2_PER_KWH)
    args = ap.parse_args()

    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)

    energy_q = (
        'sum(kepler_process_joules_total{group="%s",arch="%s"})'
        % (args.group, args.arch)
    )
    power_q = (
        'rate(kepler_process_joules_total{group="%s",arch="%s"}[2m])'
        % (args.group, args.arch)
    )

    energy_series = extract_series(
        query_range(args.prom, energy_q, args.start, args.end, args.step), "energy")
    power_series = extract_series(
        query_range(args.prom, power_q, args.start, args.end, args.step), "power")

    # Persist raw series for re-analysis.
    with (out / "energy.csv").open("w") as f:
        f.write("t,energy_joules\n")
        for i, v in enumerate(energy_series):
            f.write(f"{i},{v}\n")

    # --- Metric derivation -------------------------------------------------
    energy_total = max(energy_series[-1] - energy_series[0], 0.0) if len(energy_series) > 1 \
        else 0.0
    mean_power = sum(power_series) / len(power_series) if power_series else 0.0
    seconds = step_seconds(args.step) * max(len(energy_series) - 1, 1)

    requests = args.requests
    rps = args.rps
    if requests > 0 and seconds > 0 and rps == 0.0:
        rps = requests / seconds

    joules_per_request = energy_total / requests if requests > 0 else math.nan
    rps_per_watt = rps / mean_power if mean_power > 0 else math.nan

    kwh = energy_total / 3_600_000.0
    gco2e_total = kwh * args.carbon_gco2_per_kwh
    gco2e_per_1m = (gco2e_total / requests * 1_000_000.0) if requests > 0 else math.nan

    summary = {
        "group": args.group,
        "arch": args.arch,
        "start": args.start,
        "end": args.end,
        "duration_s": round(seconds, 3),
        "requests": requests,
        "rps": round(rps, 3),
        "energy_joules": round(energy_total, 3),
        "mean_power_w": round(mean_power, 3),
        "joules_per_request": round(joules_per_request, 6),
        "rps_per_watt": round(rps_per_watt, 4),
        "gco2e_per_1m_requests": round(gco2e_per_1m, 4),
        "carbon_intensity_gco2_per_kwh": args.carbon_gco2_per_kwh,
    }

    with (out / "summary.json").open("w") as f:
        json.dump(summary, f, indent=2)

    print(json.dumps(summary, indent=2))
    return 0


def step_seconds(step: str) -> float:
    """Convert a Prometheus step string ('10s','5m') to seconds (float)."""
    import re
    m = re.fullmatch(r"(\d+)([smh])", step)
    if not m:
        return 10.0
    val, unit = m.groups()
    mult = {"s": 1, "m": 60, "h": 3600}[unit]
    return int(val) * mult


if __name__ == "__main__":
    sys.exit(main())
