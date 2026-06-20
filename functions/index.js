"use strict";

const admin = require("firebase-admin");
const logger = require("firebase-functions/logger");
const {setGlobalOptions} = require("firebase-functions/v2");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {
  Environment,
  SignedDataVerifier,
} = require("@apple/app-store-server-library");

const REGION = "europe-west1";
const PREMIUM_PRODUCT_ID = process.env.PREMIUM_PRODUCT_ID || "premium_monthly";
const APPLE_BUNDLE_ID = process.env.APPLE_BUNDLE_ID || "be.missionzebra.app";
const APPLE_APP_APPLE_ID = parseAppleAppId(process.env.APPLE_APP_APPLE_ID);
const APPLE_ENABLE_ONLINE_CHECKS = process.env.APPLE_ENABLE_ONLINE_CHECKS !== "false";

setGlobalOptions({region: REGION, maxInstances: 10});
admin.initializeApp();

const firestore = admin.firestore();
let signedDataVerifier;

exports.verifyApplePremiumPurchase = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Log in before buying Premium.");
  }

  const uid = request.auth.uid;
  const transactionId = cleanString(request.data?.transactionId);
  const originalTransactionId = cleanString(request.data?.originalTransactionId);
  const productId = cleanString(request.data?.productId);
  const signedTransactionInfo = cleanString(request.data?.signedTransactionInfo);
  const source = cleanString(request.data?.source) || "iosStoreKit";

  if (!transactionId) {
    throw new HttpsError("invalid-argument", "Missing transactionId.");
  }
  if (!originalTransactionId) {
    throw new HttpsError("invalid-argument", "Missing originalTransactionId.");
  }
  if (productId !== PREMIUM_PRODUCT_ID) {
    throw new HttpsError("invalid-argument", "Unknown Premium product.");
  }
  if (!signedTransactionInfo) {
    throw new HttpsError("invalid-argument", "Missing signedTransactionInfo.");
  }

  const decodedTransaction = await verifySignedTransaction(signedTransactionInfo);
  const entitlement = buildApplePremiumEntitlement(decodedTransaction, {
    transactionId,
    originalTransactionId,
    source,
  });

  await assertAppleTransactionNotOwnedByAnotherUser(
    entitlement.appleOriginalTransactionId,
    uid
  );

  if (!entitlement.productMatches) {
    throw new HttpsError("failed-precondition", "Purchase is not for MissionZebra Premium.");
  }
  if (!entitlement.bundleMatches) {
    throw new HttpsError("failed-precondition", "Purchase belongs to another app.");
  }
  if (!entitlement.transactionMatches) {
    throw new HttpsError("failed-precondition", "Transaction id does not match the signed purchase.");
  }
  if (!entitlement.originalTransactionMatches) {
    throw new HttpsError("failed-precondition", "Original transaction id does not match the signed purchase.");
  }
  if (!entitlement.isPremium) {
    throw new HttpsError("failed-precondition", "Premium purchase is not active.");
  }

  await writeApplePremiumEntitlement(uid, entitlement);
  logger.info("Verified Apple Premium entitlement.", {
    uid,
    productId: entitlement.subscriptionId,
    premiumUntil: entitlement.premiumUntil,
    environment: entitlement.appleEnvironment,
  });

  return {
    isPremium: entitlement.isPremium,
    premiumUntil: entitlement.premiumUntil,
    billingStatus: entitlement.billingStatus,
  };
});

async function verifySignedTransaction(signedTransactionInfo) {
  try {
    const verifier = getSignedDataVerifier();
    return await verifier.verifyAndDecodeTransaction(signedTransactionInfo);
  } catch (error) {
    logger.error("Apple transaction verification failed.", {error});
    throw new HttpsError("failed-precondition", "App Store purchase verification failed.");
  }
}

function getSignedDataVerifier() {
  if (signedDataVerifier) {
    return signedDataVerifier;
  }

  const rootCertificates = appleRootCertificates();
  if (rootCertificates.length === 0) {
    throw new HttpsError(
      "failed-precondition",
      "Apple root certificates are not configured."
    );
  }

  signedDataVerifier = new SignedDataVerifier(
    rootCertificates,
    APPLE_ENABLE_ONLINE_CHECKS,
    appleEnvironment(),
    APPLE_BUNDLE_ID,
    APPLE_APP_APPLE_ID
  );
  return signedDataVerifier;
}

function appleRootCertificates() {
  const raw = cleanString(process.env.APPLE_ROOT_CERTS_BASE64);
  if (!raw) {
    return [];
  }
  return raw
    .split(",")
    .map((value) => value.trim())
    .filter(Boolean)
    .map((base64Certificate) => Buffer.from(base64Certificate, "base64"));
}

function appleEnvironment() {
  const raw = cleanString(process.env.APPLE_ENVIRONMENT).toUpperCase();
  if (raw === "PRODUCTION") {
    return Environment.PRODUCTION;
  }
  if (raw === "XCODE" && Environment.XCODE) {
    return Environment.XCODE;
  }
  return Environment.SANDBOX;
}

function parseAppleAppId(value) {
  const raw = cleanString(value);
  if (!raw) {
    return undefined;
  }
  const parsed = Number(raw);
  return Number.isFinite(parsed) ? parsed : undefined;
}

function buildApplePremiumEntitlement(decodedTransaction, requestData) {
  const decodedTransactionId = cleanString(decodedTransaction.transactionId);
  const decodedOriginalTransactionId = cleanString(decodedTransaction.originalTransactionId);
  const premiumUntil = millis(decodedTransaction.expiresDate);
  const revocationDate = millis(decodedTransaction.revocationDate);
  const productId = cleanString(decodedTransaction.productId);
  const bundleId = cleanString(decodedTransaction.bundleId);
  const environment = cleanString(decodedTransaction.environment);

  const active = Boolean(
    premiumUntil &&
    premiumUntil > Date.now() &&
    !revocationDate
  );

  return {
    isPremium: active,
    premiumUntil,
    billingStatus: active ? "APPLE_ACTIVE" : "APPLE_INACTIVE",
    billingUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
    subscriptionId: productId || PREMIUM_PRODUCT_ID,
    basePlanId: null,
    entitlementSource: "apple_app_store",
    appleTransactionId: decodedTransactionId,
    appleOriginalTransactionId: decodedOriginalTransactionId,
    appleEnvironment: environment || cleanString(process.env.APPLE_ENVIRONMENT) || "SANDBOX",
    applePurchaseSource: requestData.source,
    appleRevocationDate: revocationDate,
    productMatches: productId === PREMIUM_PRODUCT_ID,
    bundleMatches: bundleId === APPLE_BUNDLE_ID,
    transactionMatches: decodedTransactionId === requestData.transactionId,
    originalTransactionMatches: decodedOriginalTransactionId === requestData.originalTransactionId,
  };
}

async function assertAppleTransactionNotOwnedByAnotherUser(originalTransactionId, uid) {
  const existing = await firestore
    .collection("billingEntitlements")
    .where("appleOriginalTransactionId", "==", originalTransactionId)
    .limit(1)
    .get();

  if (!existing.empty && existing.docs[0].id !== uid) {
    throw new HttpsError("permission-denied", "Purchase is already linked to another account.");
  }
}

async function writeApplePremiumEntitlement(uid, entitlement) {
  const batch = firestore.batch();

  batch.set(firestore.collection("parents").doc(uid), {
    isPremium: entitlement.isPremium,
    premium: entitlement.isPremium,
    premiumSource: "apple",
    premiumUntil: entitlement.premiumUntil,
    premiumExpiresAt: entitlement.premiumUntil,
    billingStatus: entitlement.billingStatus,
    billingUpdatedAt: entitlement.billingUpdatedAt,
    subscriptionId: entitlement.subscriptionId,
    basePlanId: entitlement.basePlanId,
    entitlementSource: entitlement.entitlementSource,
    appleTransactionId: entitlement.appleTransactionId,
    appleOriginalTransactionId: entitlement.appleOriginalTransactionId,
    appleEnvironment: entitlement.appleEnvironment,
  }, {merge: true});

  batch.set(firestore.collection("billingEntitlements").doc(uid), {
    uid,
    purchaseToken: null,
    subscriptionId: entitlement.subscriptionId,
    basePlanId: entitlement.basePlanId,
    billingStatus: entitlement.billingStatus,
    premiumUntil: entitlement.premiumUntil,
    isPremium: entitlement.isPremium,
    entitlementSource: entitlement.entitlementSource,
    appleTransactionId: entitlement.appleTransactionId,
    appleOriginalTransactionId: entitlement.appleOriginalTransactionId,
    appleEnvironment: entitlement.appleEnvironment,
    applePurchaseSource: entitlement.applePurchaseSource,
    appleRevocationDate: entitlement.appleRevocationDate,
    updatedAt: entitlement.billingUpdatedAt,
  }, {merge: true});

  await batch.commit();
}

function millis(value) {
  if (value == null) {
    return null;
  }
  if (typeof value === "number" && Number.isFinite(value)) {
    return Math.trunc(value);
  }
  if (typeof value === "bigint") {
    return Number(value);
  }
  if (value instanceof Date) {
    return value.getTime();
  }
  const parsed = Date.parse(String(value));
  return Number.isNaN(parsed) ? null : parsed;
}

function cleanString(value) {
  return value == null ? "" : String(value).trim();
}
