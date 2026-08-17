/**
 * k6 Load Test — Pulso API
 *
 * Purpose: Simulates realistic concurrent user traffic across key endpoints.
 * Profile: Ramp-up to 10 VUs → spike to 30 VUs → ramp-down.
 *
 * Run (basic):
 *   k6 run k6/tests/load_api.js \
 *     -e TEST_EMAIL=myuser@email.com \
 *     -e TEST_PASSWORD=mypassword
 *
 * Run (with Prometheus output — requires docker-compose running):
 *   k6 run --out experimental-prometheus-rw \
 *     -e K6_PROMETHEUS_RW_SERVER_URL=http://localhost:9090/api/v1/write \
 *     -e TEST_EMAIL=myuser@email.com \
 *     -e TEST_PASSWORD=mypassword \
 *     k6/tests/load_api.js
 */

import http from "k6/http";
import { check, group, sleep } from "k6";
import { Trend, Rate, Counter } from "k6/metrics";
import { login, authHeaders, getTestCredentials } from "../helpers/auth.js";

const BASE_URL = __ENV.BASE_URL || "http://localhost:8000";
const API = `${BASE_URL}/api/v1`;

// ── Custom metrics ──────────────────────────────────────────────────────────
const loginDuration = new Trend("pulso_login_duration", true);
const workoutListDuration = new Trend("pulso_workout_list_duration", true);
const exerciseListDuration = new Trend("pulso_exercise_list_duration", true);
const errorRate = new Rate("pulso_error_rate");
const requestCount = new Counter("pulso_requests_total");

// ── Load profile ────────────────────────────────────────────────────────────
export const options = {
  stages: [
    { duration: "30s", target: 10 },  // Ramp-up to 10 VUs
    { duration: "2m",  target: 10 },  // Hold — normal load
    { duration: "30s", target: 30 },  // Spike to 30 VUs
    { duration: "1m",  target: 30 },  // Hold — peak load
    { duration: "30s", target: 0  },  // Ramp-down
  ],
  thresholds: {
    http_req_duration:        ["p(50)<200", "p(95)<500", "p(99)<1500"],
    http_req_failed:          ["rate<0.01"],
    pulso_error_rate:         ["rate<0.02"],
    pulso_login_duration:     ["p(95)<800"],
    pulso_workout_list_duration: ["p(95)<600"],
  },
};

// ── VU setup: login once per VU lifecycle ───────────────────────────────────
export function setup() {
  const creds = getTestCredentials();
  const token = login(creds.email, creds.password);
  if (!token) {
    throw new Error("Setup failed: could not authenticate. Check TEST_EMAIL / TEST_PASSWORD.");
  }
  return { token };
}

// ── Main test function ──────────────────────────────────────────────────────
export default function (data) {
  const { token } = data;
  const headers = authHeaders(token);

  // Use random number to distribute between scenarios
  const scenario = Math.random();

  if (scenario < 0.3) {
    // 30% — Read workouts (most common trainer action)
    group("workouts", () => {
      const start = Date.now();
      const res = http.get(`${API}/workouts`, {
        ...headers,
        tags: { name: "GET /workouts" },
      });
      workoutListDuration.add(Date.now() - start);
      requestCount.add(1);

      const ok = check(res, {
        "GET /workouts: 200": (r) => r.status === 200,
        "GET /workouts: has data": (r) => {
          try { return Array.isArray(JSON.parse(r.body)); } catch { return false; }
        },
      });
      errorRate.add(!ok);
    });
  } else if (scenario < 0.55) {
    // 25% — Exercise library
    group("exercises", () => {
      const start = Date.now();
      const res = http.get(`${API}/exercises?limit=20`, {
        ...headers,
        tags: { name: "GET /exercises" },
      });
      exerciseListDuration.add(Date.now() - start);
      requestCount.add(1);

      const ok = check(res, {
        "GET /exercises: 200": (r) => r.status === 200,
      });
      errorRate.add(!ok);
    });
  } else if (scenario < 0.70) {
    // 15% — User profile
    group("user_profile", () => {
      const res = http.get(`${API}/users/me`, {
        ...headers,
        tags: { name: "GET /users/me" },
      });
      requestCount.add(1);

      const ok = check(res, {
        "GET /users/me: 200": (r) => r.status === 200,
      });
      errorRate.add(!ok);
    });
  } else if (scenario < 0.82) {
    // 12% — Marketplace
    group("marketplace", () => {
      const res = http.get(`${API}/marketplace`, {
        ...headers,
        tags: { name: "GET /marketplace" },
      });
      requestCount.add(1);

      const ok = check(res, {
        "GET /marketplace: 200 or 401": (r) => [200, 401, 403].includes(r.status),
      });
      errorRate.add(!ok);
    });
  } else if (scenario < 0.92) {
    // 10% — Notifications
    group("notifications", () => {
      const res = http.get(`${API}/notifications`, {
        ...headers,
        tags: { name: "GET /notifications" },
      });
      requestCount.add(1);

      const ok = check(res, {
        "GET /notifications: 200 or 401": (r) => [200, 401, 403].includes(r.status),
      });
      errorRate.add(!ok);
    });
  } else {
    // 8% — Health check (baseline noise)
    group("health", () => {
      const res = http.get(`${BASE_URL}/health`, {
        tags: { name: "GET /health" },
      });
      requestCount.add(1);

      const ok = check(res, {
        "GET /health: 200": (r) => r.status === 200,
      });
      errorRate.add(!ok);
    });
  }

  // Think time: 1-3 seconds between requests (realistic user pacing)
  sleep(1 + Math.random() * 2);
}
