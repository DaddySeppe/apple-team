# iOS/Android parity notes

MissionZebra iOS now mirrors the Android behavior where iOS allows it, with these platform conditions:

- Screen Time: real usage on iOS uses FamilyControls + DeviceActivityMonitor threshold events. App and extension share data through App Group `group.be.missionzebra.app`. Without FamilyControls entitlement approval, user authorization, and an app/category selection, iOS shows fallback state and does not claim `DEVICE_ACTIVITY`.
- Blocking: iOS shielding uses ManagedSettings for locally selected apps/categories/web domains. This applies on the device where the FamilyActivitySelection exists. Apple does not expose Android-style remote arbitrary package blocking.
- Online safety: iOS writes `safetyDaily` from real DeviceActivity threshold data. Apple does not expose Android UsageStats-style per-app open counts or full category history to normal apps; unknown category time is recorded as `OTHER`, and `openCount` remains `0`.
- Notifications: remote push requires APNS capability/provisioning in the Apple Developer portal and a valid FCM/APNS setup. `aps-environment` is build-config driven: Debug = development, Release = production.
- Premium: iOS purchases use StoreKit product `premium_monthly`. The app sends `transactionId`, `originalTransactionId`, `productId`, and StoreKit JWS `signedTransactionInfo` to Firebase callable `verifyApplePremiumPurchase`; the backend must validate with Apple and write `parents/{uid}.isPremium`.
- Calendar sync: EventKit sync requires calendar permission and premium status. Recurring weekly tasks are expanded into concrete calendar events for the next six months, and iOS now auto-syncs after task/premium/calendar connection changes.

External release checklist:

- Apple Developer: enable Family Controls entitlement for the app and DeviceActivity extension bundle IDs.
- Apple Developer: enable App Groups for `be.missionzebra.app` and `be.missionzebra.app.deviceactivity`, both with `group.be.missionzebra.app`.
- Apple Developer: enable Push Notifications and regenerate provisioning profiles for Debug and Release.
- Firebase: upload APNS auth key/cert for the iOS app in Firebase Cloud Messaging.
- Firebase Functions/backend: implement and deploy `verifyApplePremiumPurchase` in `europe-west1`; validate the StoreKit JWS with Apple App Store Server APIs, verify bundle ID/product ID, reject transactions owned by another user, and write `parents/{uid}` plus any billing entitlement audit document.
- App Store Connect: create StoreKit product `premium_monthly` matching the backend configuration.
- App Store Connect: create StoreKit sandbox testers and test purchase/restore on a real device.
- AdMob: iOS currently has no ads integration. Do not use copy promising “ads removed” unless GoogleMobileAds and iOS ad unit IDs are added later.
