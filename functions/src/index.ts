import {initializeApp} from "firebase-admin/app";
import {getAuth} from "firebase-admin/auth";
import {getFirestore} from "firebase-admin/firestore";
import {defineInt, defineSecret, defineString} from "firebase-functions/params";
import {HttpsError, onCall, onRequest} from "firebase-functions/v2/https";
import {authorize} from "./authorization";
import {publicKeys, signer} from "./leases";
import {FirestoreBetaStore} from "./membership";
import {FirestoreRateLimiter} from "./rate_limit";
import {AccessError, validateEnvironment} from "./security";

initializeApp();
const emulator = process.env.FUNCTIONS_EMULATOR === "true";
const expectedProject = defineString("AUTH_EXPECTED_PROJECT", {default: "smartbudget-561d4"});
const region = defineString("AUTH_REGION", {default: "asia-south1"});
const serviceAccount = defineString("AUTH_SERVICE_ACCOUNT", emulator ? {default: "emulator-only@demo-smartbudget-authz.iam.gserviceaccount.com"} : {});
const ttl = defineInt("AUTH_LEASE_TTL_SECONDS", {default: 86400});
const policy = defineInt("AUTH_POLICY_VERSION", {default: 1});
const kid = defineString("AUTH_SIGNING_KEY_ID", emulator ? {default: "emulator-only"} : {});
const jwks = defineString("AUTH_PUBLIC_KEY_SET_JSON", emulator ? {default: "{\"keys\":[]}"} : {});
const privateKey = defineSecret("AUTH_LEASE_PRIVATE_KEY");
const androidAppId = "1:463515242262:android:066c564503b6ba967e0a37";

function configuration() {
  const actual = process.env.GCLOUD_PROJECT;
  const projectId = emulator ? "demo-smartbudget-authz" : expectedProject.value();
  validateEnvironment(projectId, actual, emulator, process.env);
  const keys = publicKeys(JSON.parse(emulator ? process.env.SMARTBUDGET_TEST_JWKS ?? "{}" : jwks.value()));
  return {projectId, keys, kid: emulator ? "emulator-only" : kid.value()};
}

const safeMessages = {
  unauthenticated: "Authentication required.", "permission-denied": "Access is not authorized.",
  "invalid-argument": "Invalid authorization request.", "resource-exhausted": "Please retry later.",
  unavailable: "Authorization is temporarily unavailable.",
};

export const authorizeSession = onCall({
  region, ...(emulator ? {} : {serviceAccount}),
  enforceAppCheck: !emulator, consumeAppCheckToken: !emulator,
  secrets: emulator ? [] : [privateKey], maxInstances: 2, minInstances: 0,
  concurrency: 20, timeoutSeconds: 15, memory: "256MiB", invoker: "public",
}, async request => {
  try {
    if (!emulator && (!request.app || request.app.appId !== androidAppId || request.app.alreadyConsumed)) {
      throw new AccessError("permission-denied");
    }
    const config = configuration();
    return await authorize({identity: getAuth(), store: new FirestoreBetaStore(getFirestore()),
      rateLimit: new FirestoreRateLimiter(getFirestore()), projectId: config.projectId,
      ttlSeconds: ttl.value(), policyVersion: policy.value(), kid: config.kid,
      signingKey: () => signer(emulator ? process.env.SMARTBUDGET_TEST_SIGNING_KEY ?? "" : privateKey.value(), config.kid, config.keys),
      now: () => Math.floor(Date.now() / 1000),
    }, {contextUid: request.auth?.uid, authorization: request.rawRequest.headers.authorization, data: request.data});
  } catch (error) {
    const code = error instanceof AccessError ? error.code : "unavailable";
    // Never log the request, ID token, lease, private key or raw exception.
    throw new HttpsError(code, safeMessages[code]);
  }
});

// Public verification material only; no allowlist, grants or private secrets.
export const leaseVerificationKeys = onRequest({region, ...(emulator ? {} : {serviceAccount}), maxInstances: 1, minInstances: 0,
  concurrency: 20, timeoutSeconds: 5, invoker: "public"}, (request, response) => {
  if (request.method !== "GET") { response.status(405).end(); return; }
  try {
    response.set("Cache-Control", "public, max-age=300").json(configuration().keys);
  } catch { response.status(503).json({error: "Verification keys unavailable."}); }
});
