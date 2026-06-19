# iOS/Android parity notes

MissionZebra iOS now mirrors the Android behavior where iOS allows it, with these platform conditions:

- Screen Time: real device usage on iOS requires Apple FamilyControls/DeviceActivity entitlement approval and explicit user authorization. Without that, iOS must show the fallback state and may only track MissionZebra foreground/app session time.
- Notifications: remote push requires APNS capability/provisioning in the Apple Developer portal and a valid FCM/APNS setup. Notification permission is requested contextually from settings toggles.
- Premium: iOS purchases use StoreKit product `premium_monthly` and update Firebase after StoreKit verification. Production server-side App Store receipt validation would be stronger than client-only verification.
- Calendar sync: EventKit sync requires calendar permission and premium status. Recurring weekly tasks are expanded into concrete calendar events for the next six months, matching the Android behavior.
