# Requirements

## FCM background delivery

- **FCM-01:** Register Android and Web tokens with a valid authenticated bearer token.
- **FCM-02:** Retain and deliver to multiple active user installations independently.
- **FCM-03:** Retry pending token registration after authentication, token refresh, app resume, and connectivity recovery.
- **FCM-04:** Deliver Android notifications in background and terminated states with working tap routing.
- **FCM-05:** Deliver Web notifications without duplicate display and with validated click routing.
- **FCM-06:** Do not expose private message bodies through public Android lock-screen visibility.
- **FCM-07:** Purge invalid tokens individually without disabling other devices.
- **FCM-08:** Validate notification routes and entity identifiers before navigation.
- **FCM-09:** Surface background handler and delivery failures through structured, non-sensitive diagnostics.
- **FCM-10:** Document Android/Web support and explicitly mark iOS/Tauri unsupported until implemented.

## Validation

- Backend tests cover authenticated registration, multi-device registration/logout,
  invalid-token cleanup, payload privacy, and route validation.
- Flutter/Web tests or acceptance procedures cover permission, background,
  terminated, tap, refresh, and denial flows.
