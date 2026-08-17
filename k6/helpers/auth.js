/**
 * k6 Auth Helper
 * Handles login and token management for test scripts
 */

import http from "k6/http";
import { check } from "k6";

const BASE_URL = __ENV.BASE_URL || "http://localhost:8000";

/**
 * Login with email/password and return access token.
 * Fails the check if login doesn't return 200.
 */
export function login(email, password) {
  const payload = JSON.stringify({ email, password });
  const params = {
    headers: { "Content-Type": "application/json" },
    tags: { name: "auth_login" },
  };

  const res = http.post(`${BASE_URL}/api/v1/auth/login`, payload, params);

  check(res, {
    "login status is 200": (r) => r.status === 200,
    "login returns access_token": (r) => {
      try {
        return JSON.parse(r.body).access_token !== undefined;
      } catch {
        return false;
      }
    },
  });

  if (res.status !== 200) {
    console.error(`Login failed: ${res.status} ${res.body}`);
    return null;
  }

  return JSON.parse(res.body).access_token;
}

/**
 * Return default auth headers with Bearer token
 */
export function authHeaders(token) {
  return {
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json",
    },
  };
}

/**
 * Get test credentials from environment variables.
 * Set TEST_EMAIL and TEST_PASSWORD when running k6.
 */
export function getTestCredentials() {
  return {
    email: __ENV.TEST_EMAIL || "test@pulsofit.app",
    password: __ENV.TEST_PASSWORD || "testpass123",
  };
}
