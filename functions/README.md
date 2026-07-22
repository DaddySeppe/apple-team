# MissionZebra Firebase Functions

This folder contains the iOS App Store Premium verification callable and the
account deletion callable.

Deploy the callables without touching other existing backend functions:

```sh
firebase deploy --only functions:verifyApplePremiumPurchase,functions:deleteParentAccount
```

Required runtime environment:

- `APPLE_BUNDLE_ID=be.missionzebra.app`
- `APPLE_ENVIRONMENT=SANDBOX` for Sandbox/TestFlight testing, `PRODUCTION` for release
- `APPLE_APP_APPLE_ID=<app Apple ID>` for production validation
- `PREMIUM_PRODUCT_ID=premium_monthly` or `PREMIUM_PRODUCT_IDS=premium_monthly,<alias>` if App Store Connect has to support more than one product identifier

The project-specific defaults for `missionzebra-683d5` live in
`functions/.env.missionzebra-683d5`. Keep `APPLE_ENVIRONMENT=SANDBOX` while
testing with StoreKit/Sandbox/TestFlight. Before App Store release, confirm
App Store Connect has an auto-renewable subscription with product ID
`premium_monthly`, add the real `APPLE_APP_APPLE_ID`, and switch
`APPLE_ENVIRONMENT` to `PRODUCTION`.

`APPLE_ROOT_CERTS_BASE64` is optional. When omitted, the function uses the
Apple Inc. Root, Apple Root CA - G2, and Apple Root CA - G3 certificates.

The callable requires Firebase Auth and writes the verified entitlement to:

- `parents/{uid}`
- `billingEntitlements/{uid}`

The iOS app reads `parents/{uid}.isPremium` and `parents/{uid}.premiumUntil`.

One Apple subscription can be active for one MissionZebra account at a time.
When Apple returns an already-active subscription while another Firebase user is
logged in, the callable transfers the entitlement to that current user and
marks the previous MissionZebra account as non-premium.

`deleteParentAccount` requires Firebase Auth, recursively deletes
`parents/{uid}` plus `billingEntitlements/{uid}`, and then deletes the Firebase
Authentication user with the Admin SDK. This avoids client-side deletion being
blocked by Apple/Google/e-mail provider reauthentication settings.
