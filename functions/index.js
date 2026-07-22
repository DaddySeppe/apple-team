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
const PREMIUM_PRODUCT_IDS = premiumProductIds();
const PREMIUM_PRODUCT_ID = PREMIUM_PRODUCT_IDS[0];
const APPLE_BUNDLE_ID = process.env.APPLE_BUNDLE_ID || "be.missionzebra.app";
const APPLE_APP_APPLE_ID = parseAppleAppId(process.env.APPLE_APP_APPLE_ID);
const APPLE_ENABLE_ONLINE_CHECKS = process.env.APPLE_ENABLE_ONLINE_CHECKS !== "false";
const DEFAULT_APPLE_ROOT_CERTS_BASE64 = [
  "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",
];

setGlobalOptions({region: REGION, maxInstances: 10});
admin.initializeApp();

const firestore = admin.firestore();
const signedDataVerifiers = new Map();

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
  if (!isPremiumProductId(productId)) {
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

exports.deleteParentAccount = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Log in before deleting your account.");
  }

  const uid = request.auth.uid;

  await deleteParentAccountData(uid);
  try {
    await admin.auth().deleteUser(uid);
  } catch (error) {
    if (error?.code !== "auth/user-not-found") {
      logger.error("Firebase Auth account deletion failed.", {uid, error});
      throw new HttpsError("internal", "Account deletion failed.");
    }
  }

  logger.info("Deleted parent account.", {uid});
  return {deleted: true};
});

async function verifySignedTransaction(signedTransactionInfo) {
  const failures = [];

  for (const environment of appleVerificationEnvironments()) {
    try {
      const verifier = getSignedDataVerifier(environment);
      return await verifier.verifyAndDecodeTransaction(signedTransactionInfo);
    } catch (error) {
      failures.push({
        environment,
        message: error instanceof Error ? error.message : String(error),
      });
    }
  }

  logger.error("Apple transaction verification failed.", {failures});
  throw new HttpsError("failed-precondition", "App Store purchase verification failed.");
}

function getSignedDataVerifier(environment) {
  if (signedDataVerifiers.has(environment)) {
    return signedDataVerifiers.get(environment);
  }

  const rootCertificates = appleRootCertificates();
  if (rootCertificates.length === 0) {
    throw new HttpsError(
      "failed-precondition",
      "Apple root certificates are not configured."
    );
  }

  const verifier = new SignedDataVerifier(
    rootCertificates,
    APPLE_ENABLE_ONLINE_CHECKS,
    environment,
    APPLE_BUNDLE_ID,
    APPLE_APP_APPLE_ID
  );
  signedDataVerifiers.set(environment, verifier);
  return verifier;
}

function appleRootCertificates() {
  const raw = cleanString(process.env.APPLE_ROOT_CERTS_BASE64);
  const certificates = raw ? raw.split(",") : DEFAULT_APPLE_ROOT_CERTS_BASE64;
  return certificates
    .map((value) => value.trim())
    .filter(Boolean)
    .map((base64Certificate) => Buffer.from(base64Certificate, "base64"));
}

function appleVerificationEnvironments() {
  const environments = [];
  const addEnvironment = (environment) => {
    if (environment === Environment.PRODUCTION && !APPLE_APP_APPLE_ID) {
      return;
    }
    if (environment && !environments.includes(environment)) {
      environments.push(environment);
    }
  };

  addEnvironment(appleEnvironment(process.env.APPLE_ENVIRONMENT));
  addEnvironment(Environment.SANDBOX);
  if (Environment.XCODE) {
    addEnvironment(Environment.XCODE);
  }
  if (APPLE_APP_APPLE_ID) {
    addEnvironment(Environment.PRODUCTION);
  }

  return environments;
}

function appleEnvironment(value) {
  const raw = cleanString(value).toUpperCase();
  if (raw === "PRODUCTION") {
    return Environment.PRODUCTION;
  }
  if (raw === "XCODE" && Environment.XCODE) {
    return Environment.XCODE;
  }
  if (raw === "SANDBOX") {
    return Environment.SANDBOX;
  }
  if (raw === "LOCAL_TESTING" && Environment.LOCAL_TESTING) {
    return Environment.LOCAL_TESTING;
  }
  if (!raw) {
    return null;
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
    productMatches: isPremiumProductId(productId),
    bundleMatches: bundleId === APPLE_BUNDLE_ID,
    transactionMatches: decodedTransactionId === requestData.transactionId,
    originalTransactionMatches: decodedOriginalTransactionId === requestData.originalTransactionId,
  };
}

async function writeApplePremiumEntitlement(uid, entitlement) {
  await firestore.runTransaction(async (transaction) => {
    const existingOwners = await transaction.get(
      firestore
        .collection("billingEntitlements")
        .where("appleOriginalTransactionId", "==", entitlement.appleOriginalTransactionId)
    );

    for (const ownerDoc of existingOwners.docs) {
      if (ownerDoc.id === uid) {
        continue;
      }
      const ownerUid = ownerDoc.id;
      const transferFields = transferredAppleEntitlementFields(uid, entitlement);

      transaction.set(firestore.collection("parents").doc(ownerUid), transferFields.parent, {merge: true});
      transaction.set(ownerDoc.ref, transferFields.billing, {merge: true});
    }

    transaction.set(firestore.collection("parents").doc(uid), {
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

    transaction.set(firestore.collection("billingEntitlements").doc(uid), {
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
  });
}

function transferredAppleEntitlementFields(newOwnerUid, entitlement) {
  const transferredAt = admin.firestore.FieldValue.serverTimestamp();
  return {
    parent: {
      isPremium: false,
      premium: false,
      premiumUntil: null,
      premiumExpiresAt: null,
      billingStatus: "APPLE_TRANSFERRED",
      billingUpdatedAt: transferredAt,
      transferredPremiumToUid: newOwnerUid,
      transferredAppleOriginalTransactionId: entitlement.appleOriginalTransactionId,
      appleTransactionId: admin.firestore.FieldValue.delete(),
      appleOriginalTransactionId: admin.firestore.FieldValue.delete(),
    },
    billing: {
      billingStatus: "APPLE_TRANSFERRED",
      premiumUntil: null,
      isPremium: false,
      transferredToUid: newOwnerUid,
      transferredAt,
      transferredAppleOriginalTransactionId: entitlement.appleOriginalTransactionId,
      appleTransactionId: admin.firestore.FieldValue.delete(),
      appleOriginalTransactionId: admin.firestore.FieldValue.delete(),
      updatedAt: transferredAt,
    },
  };
}

async function deleteParentAccountData(uid) {
  const parentRef = firestore.collection("parents").doc(uid);
  const billingRef = firestore.collection("billingEntitlements").doc(uid);

  await firestore.recursiveDelete(parentRef);
  await firestore.recursiveDelete(billingRef);
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

function premiumProductIds() {
  const raw = cleanString(process.env.PREMIUM_PRODUCT_IDS || process.env.PREMIUM_PRODUCT_ID);
  const ids = raw
    .split(",")
    .map((value) => cleanString(value))
    .filter(Boolean);
  return ids.length === 0 ? ["premium_monthly"] : ids;
}

function isPremiumProductId(productId) {
  return PREMIUM_PRODUCT_IDS.includes(cleanString(productId));
}
