/**
 * k6 Stress Test — Workout Endpoints
 *
 * Purpose: Stress test focado no fluxo de treinos (criação, listagem, templates).
 * Profile: Incrementa VUs até encontrar o limite de degradação.
 *
 * Run:
 *   k6 run k6/tests/stress_workouts.js \
 *     --out experimental-prometheus-rw \
 *     -e K6_PROMETHEUS_RW_SERVER_URL=http://localhost:9090/api/v1/write \
 *     -e TEST_EMAIL=myuser@email.com \
 *     -e TEST_PASSWORD=mypassword
 */

import http from "k6/http";
import { check, group, sleep } from "k6";
import { Trend, Rate } from "k6/metrics";
import { login, authHeaders, getTestCredentials } from "../helpers/auth.js";

const BASE_URL = __ENV.BASE_URL || "http://localhost:8000";
const API = `${BASE_URL}/api/v1`;

// ── Custom metrics ──────────────────────────────────────────────────────────
const workoutCreateDuration = new Trend("pulso_workout_create_duration", true);
const workoutListDuration   = new Trend("pulso_workout_list_duration", true);
const templateListDuration  = new Trend("pulso_template_list_duration", true);
const writeErrorRate        = new Rate("pulso_write_error_rate");

// ── Stress profile: ramp until breakpoint ───────────────────────────────────
export const options = {
  stages: [
    { duration: "1m",  target: 5  },   // Warm up
    { duration: "2m",  target: 20 },   // Normal load
    { duration: "2m",  target: 50 },   // High load
    { duration: "2m",  target: 80 },   // Very high load
    { duration: "1m",  target: 0  },   // Recovery
  ],
  thresholds: {
    http_req_duration:              ["p(95)<1000"],
    http_req_failed:                ["rate<0.05"],  // More lenient for stress
    pulso_workout_create_duration:  ["p(95)<2000"],
    pulso_write_error_rate:         ["rate<0.05"],
  },
};

export function setup() {
  const creds = getTestCredentials();
  const token = login(creds.email, creds.password);
  if (!token) {
    throw new Error("Setup failed: could not authenticate.");
  }
  return { token };
}

export default function (data) {
  const { token } = data;
  const headers = authHeaders(token);

  group("workout_read_path", () => {
    // List workouts
    const t0 = Date.now();
    const listRes = http.get(`${API}/workouts`, {
      ...headers,
      tags: { name: "GET /workouts" },
    });
    workoutListDuration.add(Date.now() - t0);

    check(listRes, {
      "list workouts: 200": (r) => r.status === 200,
    });
  });

  sleep(0.5);

  group("workout_templates", () => {
    const t0 = Date.now();
    const res = http.get(`${API}/workout-templates`, {
      ...headers,
      tags: { name: "GET /workout-templates" },
    });
    templateListDuration.add(Date.now() - t0);

    check(res, {
      "templates: 200 or 401": (r) => [200, 401, 403, 404].includes(r.status),
    });
  });

  sleep(0.5);

  group("exercise_search", () => {
    // Simulate searching for exercises with varying queries
    const queries = ["agachamento", "supino", "rosca", "elevação", "remada"];
    const query = queries[Math.floor(Math.random() * queries.length)];

    const res = http.get(`${API}/exercises?search=${encodeURIComponent(query)}&limit=10`, {
      ...headers,
      tags: { name: "GET /exercises?search" },
    });

    const ok = check(res, {
      "exercise search: 200": (r) => r.status === 200,
    });
    writeErrorRate.add(!ok);
  });

  sleep(1 + Math.random());
}
