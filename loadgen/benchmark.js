// k6 load generation script for the ARM64 vs x86_64 empirical study.
//
// Targets the benchmark microservice and records request throughput (RPS),
// latency percentiles (p50/p95/p99), and per-request error rate. Output is
// emitted as JSON so the analysis pipeline can aggregate across runs.
//
// Runtime configuration (via k6 env vars):
//   BASE_URL     -- workload base URL, e.g. http://<sut-addr>:8080   (required)
//   ENDPOINT     -- one of cpu|json|mixed|memory                      (default: cpu)
//   DURATION     -- test duration, e.g. 120s                         (default: 120s)
//   VUS          -- concurrent virtual users                         (default: 16)
//   RAMP_TIME    -- ramp-up duration                                 (default: 30s)
//   RUN_ID       -- opaque run identifier for correlation            (default: auto)

import http from 'k6/http';
import { check } from 'k6';
import { randomIntBetween } from 'https://jslib.k6.io/k6-utils/1.4.0/index.js';

const BASE_URL = __ENV.BASE_URL || 'http://localhost:8080';
const ENDPOINT = __ENV.ENDPOINT || 'cpu';
const RAMP_TIME = __ENV.RAMP_TIME || '30s';
const DURATION = __ENV.DURATION || '120s';
const VUS = __ENV.VUS || 16;
const RUN_ID = __ENV.RUN_ID || `${new Date().toISOString()}`;

export const options = {
  scenarios: {
    ramp_and_hold: {
      executor: 'ramping-vus',
      exec: 'bench',
      startVUs: 1,
      stages: [
        { duration: RAMP_TIME, target: VUS },
        { duration: DURATION, target: VUS },
        { duration: '10s', target: 0 },
      ],
      gracefulRampDown: '15s',
    },
  },
};

const ENDPOINTS = {
  cpu: `${BASE_URL}/cpu`,
  json: `${BASE_URL}/json`,
  mixed: `${BASE_URL}/mixed`,
  memory: `${BASE_URL}/memory`,
  healthz: `${BASE_URL}/healthz`,
};

function selectPayload() {
  // Bounded random payload to emulate realistic variable-size requests while
  // keeping both architectures on identical distributions.
  return JSON.stringify({ tenant: randomIntBetween(1, 64), n: randomIntBetween(16, 512) });
}

export function bench() {
  const url = ENDPOINTS[ENDPOINT] || ENDPOINTS.cpu;
  const res = http.post(url, selectPayload(), {
    headers: { 'Content-Type': 'application/json' },
    tags: { endpoint: ENDPOINT, run_id: RUN_ID },
  });

  check(res, {
    'status is 2xx': (r) => r.status >= 200 && r.status < 300,
    'body is valid JSON': (r) => r.body !== '' && (() => {
      try { JSON.parse(r.body); return true; } catch { return false; }
    })(),
  });
}

export function handleSummary(data) {
  const m = data.metrics;
  const lat = (n) => (m['http_req_duration']?.values[n] ?? 0);
  const snapshot = {
    run_id: RUN_ID,
    endpoint: ENDPOINT,
    vus: VUS,
    duration: DURATION,
    iterations: m['iterations']?.values?.count ?? 0,
    http_reqs: m['http_reqs']?.values?.count ?? 0,
    http_req_duration: {
      avg_ms: lat('avg'),
      p50_ms: lat('p(50)'),
      p90_ms: lat('p(90)'),
      p95_ms: lat('p(95)'),
      p99_ms: lat('p(99)'),
      max_ms: lat('max'),
    },
    rps: m['http_reqs']?.values?.rate ?? 0,
    errors: m['errors']?.values?.count ?? 0,
    error_rate: m['http_req_failed']?.values?.rate ?? 0,
    throughput: {
      data_received_bps: m['data_received']?.values?.rate ?? 0,
      data_sent_bps: m['data_sent']?.values?.rate ?? 0,
    },
  };
  return {
    stdout: JSON.stringify(snapshot, null, 2),
    [__ENV.RESULT_FILE || `results/${RUN_ID}_${ENDPOINT}.json`]: JSON.stringify(snapshot),
  };
}
