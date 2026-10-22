export const MAX_LEASE_SECONDS = 86_400;
export const MAX_BETA_MEMBERS = 5;
export type ErrorCode = "unauthenticated" | "permission-denied" | "invalid-argument" |
  "resource-exhausted" | "unavailable";

export class AccessError extends Error {
  constructor(readonly code: ErrorCode) { super(code); }
}

export function validateEnvironment(projectId: string, actualProject: string | undefined,
  emulator: boolean, environment: Readonly<Record<string, string | undefined>>): void {
  if (actualProject !== projectId) throw new AccessError("unavailable");
  const authHost = environment.FIREBASE_AUTH_EMULATOR_HOST;
  const firestoreHost = environment.FIRESTORE_EMULATOR_HOST;
  if (emulator) {
    const loopback = /^(127\.0\.0\.1|localhost):\d+$/;
    if (projectId !== "demo-smartbudget-authz" || !loopback.test(authHost ?? "") ||
        !loopback.test(firestoreHost ?? "")) throw new AccessError("unavailable");
  } else if (projectId.startsWith("demo-") || authHost || firestoreHost ||
      environment.SMARTBUDGET_TEST_SIGNING_KEY || environment.SMARTBUDGET_TEST_JWKS) {
    throw new AccessError("unavailable");
  }
}

export function validUid(value: unknown): value is string {
  return typeof value === "string" && value.length >= 1 && value.length <= 128 &&
    !/[\u0000-\u001f\u007f]/.test(value);
}

export function installationFrom(data: unknown): string {
  if (!data || typeof data !== "object" || Array.isArray(data) ||
      Object.keys(data).length !== 1 || !("installationId" in data) ||
      typeof data.installationId !== "string" ||
      !/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/.test(data.installationId)) {
    throw new AccessError("invalid-argument");
  }
  return data.installationId;
}

export function validatePolicy(ttlSeconds: number, policyVersion: number): void {
  if (!Number.isSafeInteger(ttlSeconds) || ttlSeconds < 300 || ttlSeconds > MAX_LEASE_SECONDS ||
      !Number.isSafeInteger(policyVersion) || policyVersion < 1) {
    throw new AccessError("unavailable");
  }
}
