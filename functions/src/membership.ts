import {createHash} from "node:crypto";
import {Firestore, Timestamp, Transaction} from "firebase-admin/firestore";
import {AccessError, MAX_BETA_MEMBERS, validUid} from "./security";

export const idHash = (value: string): string => createHash("sha256").update(value).digest("hex");
const rosterPath = "authorization/betaRoster";
export const memberPath = (uid: string): string => `authorizationMembers/${idHash(uid)}`;

function roster(data: FirebaseFirestore.DocumentData | undefined): string[] {
  if (!data) return [];
  if (data.version !== 1 || !Array.isArray(data.members) || data.members.length > MAX_BETA_MEMBERS ||
      data.members.some((uid: unknown) => !validUid(uid)) || new Set(data.members).size !== data.members.length) {
    throw new AccessError("unavailable");
  }
  return data.members;
}

export interface BetaStore {
  assertActive(uid: string): Promise<void>;
  commitGrant(uid: string, installationId: string, jti: string, exp: number): Promise<void>;
}

export class FirestoreBetaStore implements BetaStore {
  constructor(private readonly db: Firestore) {}
  private async active(tx: Transaction, uid: string): Promise<void> {
    const [r, m] = await tx.getAll(this.db.doc(rosterPath), this.db.doc(memberPath(uid)));
    if (!r || !m || !roster(r.data()).includes(uid) || m.data()?.uid !== uid || m.data()?.state !== "active") {
      throw new AccessError("permission-denied");
    }
  }
  async assertActive(uid: string): Promise<void> {
    await this.db.runTransaction(tx => this.active(tx, uid));
  }
  async commitGrant(uid: string, installationId: string, jti: string, exp: number): Promise<void> {
    await this.db.runTransaction(async tx => {
      await this.active(tx, uid);
      tx.set(this.db.doc(`authorizationGrants/${idHash(uid + ":" + installationId)}`), {
        uid, installationId, jti, expiresAt: Timestamp.fromMillis(exp * 1000),
      });
    });
  }
  async approve(uid: string): Promise<void> {
    if (!validUid(uid)) throw new AccessError("invalid-argument");
    await this.db.runTransaction(async tx => {
      const r = this.db.doc(rosterPath), m = this.db.doc(memberPath(uid));
      const [rs, ms] = await tx.getAll(r, m);
      const members = roster(rs?.data());
      if (members.includes(uid)) {
        if (ms?.data()?.uid !== uid || ms.data()?.state !== "active") throw new AccessError("unavailable");
        return;
      }
      if (ms?.data()?.state === "active") throw new AccessError("unavailable");
      if (members.length >= MAX_BETA_MEMBERS) throw new AccessError("resource-exhausted");
      tx.set(r, {version: 1, members: [...members, uid]});
      tx.set(m, {uid, state: "active", approvedAt: Timestamp.now()});
    });
  }
  async revoke(uid: string): Promise<void> {
    if (!validUid(uid)) throw new AccessError("invalid-argument");
    await this.db.runTransaction(async tx => {
      const r = this.db.doc(rosterPath);
      const rs = await tx.get(r);
      tx.set(r, {version: 1, members: roster(rs.data()).filter(u => u !== uid)});
      tx.set(this.db.doc(memberPath(uid)), {uid, state: "revoked", revokedAt: Timestamp.now()});
    });
  }
  async status(): Promise<string[]> {
    return this.db.runTransaction(async tx => {
      const r = await tx.get(this.db.doc(rosterPath));
      const members = roster(r.data());
      for (const uid of members) await this.active(tx, uid);
      return members;
    });
  }
}
