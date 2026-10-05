# UR-Heart

## Context

UR-Heart is a Flutter/FastAPI mindful dating and messaging platform. Its background
push notification contract is Android and Web through Firebase Cloud Messaging.

## Current milestone

Harden FCM background notification delivery so authenticated users receive reliable,
private, actionable notifications while the app is backgrounded or terminated.

## Scope boundary

- Supported: Android and Web.
- Not supported in this milestone: native iOS and Tauri notification targets.
- Notification payloads are navigation hints, not authorization.
