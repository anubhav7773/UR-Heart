# Roadmap

## Phase 1: Reliable Android/Web FCM delivery

Implement the requirements in `REQUIREMENTS.md`: authenticated token lifecycle,
per-device persistence, Android background/tap handling, Web service-worker
behavior, payload privacy, diagnostics, tests, and support documentation.

## Phase 2: Production verification

Run authenticated Android device and browser acceptance checks against the deployed
backend, including background, terminated, permission-denied, token-refresh,
multi-device, logout, and invalid-token scenarios.
