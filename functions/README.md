# MissionZebra Firebase Functions

This folder contains the iOS App Store Premium verification callable.

Deploy the callable without touching other existing backend functions:

```sh
firebase deploy --only functions:verifyApplePremiumPurchase
```

Required runtime environment:

- `APPLE_BUNDLE_ID=be.missionzebra.app`
- `APPLE_ENVIRONMENT=SANDBOX` for Sandbox/TestFlight testing, `PRODUCTION` for release
- `APPLE_ROOT_CERTS_BASE64=<comma-separated base64 DER Apple root certificates>`
- `APPLE_APP_APPLE_ID=<app Apple ID>` for production validation
- `PREMIUM_PRODUCT_ID=premium_monthly`

The callable requires Firebase Auth and writes the verified entitlement to:

- `parents/{uid}`
- `billingEntitlements/{uid}`

The iOS app reads `parents/{uid}.isPremium` and `parents/{uid}.premiumUntil`.
