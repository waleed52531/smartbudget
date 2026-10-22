import {AccessError, validUid} from "./security";

export interface IdentityAdmin {
  verifyIdToken(token: string, checkRevoked: boolean): Promise<{
    uid: string; aud: string; firebase?: {sign_in_provider: string};
  }>;
  getUser(uid: string): Promise<{uid: string; disabled: boolean}>;
}

export async function verifyIdentity(
  admin: IdentityAdmin, contextUid: unknown, authorization: unknown, projectId: string,
): Promise<string> {
  if (!validUid(contextUid) || typeof authorization !== "string" ||
      !/^Bearer [A-Za-z0-9_.-]{1,8192}$/.test(authorization)) {
    throw new AccessError("unauthenticated");
  }
  try {
    const token = await admin.verifyIdToken(authorization.slice(7), true);
    if (token.uid !== contextUid || token.aud !== projectId ||
        token.firebase?.sign_in_provider !== "password") throw new AccessError("unauthenticated");
    const user = await admin.getUser(token.uid);
    if (user.disabled || user.uid !== token.uid) throw new AccessError("unauthenticated");
    return token.uid;
  } catch (error) {
    // Do not expose account existence, revocation details, or SDK exceptions.
    if (error instanceof AccessError) throw error;
    const code = (error as {code?: string})?.code;
    if (["auth/id-token-expired", "auth/id-token-revoked", "auth/user-disabled", "auth/user-not-found",
      "auth/argument-error", "auth/invalid-id-token"].includes(code ?? "")) throw new AccessError("unauthenticated");
    throw new AccessError("unavailable");
  }
}
