import http from "k6/http";
import { check, group, sleep } from "k6";
import { Trend, Rate, Counter } from "k6/metrics";
import { login, authHeaders, getTestCredentials } from "../helpers/auth.js";

const BASE_URL = __ENV.BASE_URL || "http://localhost:8000";
const API = `${BASE_URL}/api/v1`;

const apiDuration = new Trend("api_duration");
const errorRate = new Rate("error_rate");
const requestCount = new Counter("request_count");

export const options = {
  stages: [
    { duration: "30s", target: 50 },    // Ramp-up rápido: 0 → 50 VUs
    { duration: "1m", target: 100 },    // Intensificar: 50 → 100 VUs
    { duration: "2m", target: 100 },    // Manter pico
    { duration: "30s", target: 150 },   // PICO MÁXIMO: 150 VUs
    { duration: "2m", target: 150 },    // Manter pico máximo
    { duration: "30s", target: 0 },     // Ramp-down
  ],
  thresholds: {
    http_req_duration: ["p(95)<1000"],
    http_req_failed: ["rate<0.1"],
  },
};

export function setup() {
  console.log("🚀 Setup: Autenticando via magic link...");
  const { email } = getTestCredentials();
  const token = login(email);
  if (!token) {
    throw new Error(`Falha ao autenticar: ${email}`);
  }
  return { token, email };
}

export default function (data) {
  const headers = authHeaders(data.token);
  
  // Teste de stress: requisições rápidas e repetidas
  group("stress_test", () => {
    const tests = [
      () => http.get(`${API}/users/me`, { ...headers, tags: { name: "GET /users/me" } }),
      () => http.get(`${API}/workouts?limit=10`, { ...headers, tags: { name: "GET /workouts" } }),
      () => http.get(`${API}/exercises?limit=20&search=test`, { ...headers, tags: { name: "GET /exercises" } }),
      () => http.get(`${API}/workout-templates/by-program?limit=5`, { ...headers, tags: { name: "GET /templates" } }),
    ];

    // Executar todas as requisições rapidamente
    for (let i = 0; i < 5; i++) {
      for (let test of tests) {
        const res = test();
        requestCount.add(1);
        apiDuration.add(res.timings.duration);
        
        const ok = check(res, { "Status 2xx-3xx": (r) => r.status >= 200 && r.status < 400 });
        if (!ok) {
          errorRate.add(1);
        }
      }
      sleep(0.1); // Mínima pausa entre rounds
    }
  });
}
