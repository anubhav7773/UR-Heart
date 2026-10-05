# State

## Current phase

Phase 1 — Reliable Android/Web FCM delivery

## Status

Implementation in progress on the FCM remediation branch.

## Decisions

- Android and Web are the supported notification platforms.
- iOS and Tauri are explicitly out of scope until native integrations exist.
- Private notification content must not be marked public on Android.

## Next

Finish backend durability/retry coverage, run targeted tests, and perform production
device/browser acceptance checks.
