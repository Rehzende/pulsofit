/**
 * k6 Smoke Test — Pulso API
 *
 * Purpose: Validate that the stack is up and responding.
 * Profile: 1 VU for 30 seconds.
 * Run:   k6 run k6/tests/smoke.js
 */

import http from "k6/http";
import { check, sleep } from "k6";

const BASE_URL = __ENV.BASE_URL || "http://localhost:8000";

// Scope thresholds to the health tag only — avoids counting 404/401
// (from routes that require auth or don't exist) as failures.
export const options = {
  vus: 1,
  duration: "30s",
  thresholds: {
    "http_req_failed{name:health}":   ["rate<0.01"],
    "http_req_duration{name:health}": ["p(95)<500"],
  },
};

export default function () {
  // ── Health check ──────────────────────────────────────────
  const health = http.get(`${BASE_URL}/health`, {
    tags: { name: "health" },
  });
  check(health, {
    "health: status 200": (r) => r.status === 200,
    "health: body ok":    (r) => {
      try { return JSON.parse(r.body).status === "ok"; }
      catch { return false; }
    },
  });

  sleep(1);

  // ── Root endpoint ─────────────────────────────────────────
  const root = http.get(`${BASE_URL}/`, {
    tags: { name: "root" },
    responseCallback: http.expectedStatuses(200, 404),
  });
  check(root, {
    "root: status 200 or 404": (r) => [200, 404].includes(r.status),
  });

  sleep(1);

  // ── Exercises (public-ish endpoint) ───────────────────────
  const exercises = http.get(`${BASE_URL}/api/v1/exercises?limit=1`, {
    tags: { name: "exercises" },
    responseCallback: http.expectedStatuses(200, 401, 403, 404),
  });
  check(exercises, {
    "exercises: reachable": (r) => [200, 401, 403, 404].includes(r.status),
  });

  sleep(2);
}
