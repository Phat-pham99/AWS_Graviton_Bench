#!/usr/bin/env bash
# Runs a single benchmark scenario against one SUT, then exports Prometheus
# energy data and the k6 summary to the results/ tree.
#
# Usage:
#   BASE_URL=<sut-ip>:8080 ENDPOINT=cpu ./scripts/run_benchmark.sh [log]
set -euo pipefail

END_ARCH="${END_ARCH:?END_ARCH required (x86_64|arm64)}"
END_GROUP="${END_GROUP:?END_GROUP required (control|test)}"
BASE_URL="${BASE_URL:?BASE_URL required (SUT base URL)}"
ENDPOINT="${ENDPOINT:-cpu}"
DURATION="${DURATION:-120s}"
VUS="${VUS:-16}"
REPEAT="${REPEAT:-3}"          # repetitions for statistical power (H0 testing)
PROM_URL="${PROM_URL:-http://localhost:9090}"
RUN_ID="${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="${ROOT}/results/${RUN_ID}/${END_GROUP}-${END_ARCH}/${ENDPOINT}"
mkdir -p "${OUT}"

echo "==> run ${RUN_ID} group=${END_GROUP} arch=${END_ARCH} endpoint=${ENDPOINT}"

for i in $(seq 1 "${REPEAT}"); do
  echo "    repetition ${i}/${REPEAT} (${DURATION}, ${VUS} VU)"
  docker run --rm --network host \
    -e BASE_URL="http://${BASE_URL}" \
    -e ENDPOINT="${ENDPOINT}" \
    -e DURATION="${DURATION}" \
    -e VUS="${VUS}" \
    -e RUN_ID="${RUN_ID}" \
    -e RESULT_FILE="/scripts/results/${END_GROUP}-${END_ARCH}-${ENDPOINT}-r${i}.json" \
    -v "${ROOT}/loadgen:/scripts" \
    grafana/k6 run /scripts/benchmark.js
done

echo "==> exporting energy time-series from Prometheus"
"${ROOT}/analysis/export_energy.py" \
  --prom "${PROM_URL}" \
  --group "${END_GROUP}" --arch "${END_ARCH}" \
  --start "${RUN_ID%%T*}" \
  --out "${OUT}/energy.csv"

echo "==> done: ${OUT}"
