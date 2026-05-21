// Project Setup Guide (Firebase, Google Sign-In)
//
// Follow these steps in Xcode to finish configuration.
//
// 1) Add SPM Dependencies
// - In Xcode: File > Add Packages…
// - Add the following package URLs:
//   - Firebase iOS SDK: https://github.com/firebase/firebase-ios-sdk
//     - Add products you need (at minimum FirebaseAnalytics, FirebaseAuth, FirebaseFirestore as your app requires). Also add FirebaseCore.
//   - Google Sign-In for iOS: https://github.com/google/GoogleSignIn-iOS
// - Resolve packages.
//
// 2) Add GoogleService-Info.plist
// - Download the GoogleService-Info.plist from your Firebase Console (Project Settings > Your apps > iOS).
// - Drag the file into Xcode, ensure "Copy items if needed" is checked, and add it to the app target.
//
// 3) Add logozebra Asset
// - Place your image (logozebra.png/pdf) into Assets.xcassets.
// - Name the asset exactly: logozebra
//
// 4) Configure URL Types for Google Sign-In
// - Target > Info > URL Types
// - Add a URL type with the REVERSED_CLIENT_ID from GoogleService-Info.plist as the URL Scheme.
//
// 5) Initialize Firebase in App Startup
// - The project contains a guarded initializer in App startup that calls FirebaseApp.configure() when FirebaseCore is available.
//
// 6) Build and Run
// - After adding packages and plist, clean build folder (Shift+Cmd+K) and build (Cmd+B).
//
// Troubleshooting
// - If build fails due to missing packages, ensure the SPM packages are added to the correct app target.
// - If FirebaseApp.configure() crashes, verify GoogleService-Info.plist is present in the app bundle.
// - If Google Sign-In doesn’t return to the app, verify URL Types and reversed client ID.
