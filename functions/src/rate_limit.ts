import {Firestore, Timestamp} from "firebase-admin/firestore";
import {AccessError} from "./security";
import {idHash} from "./membership";

export class FirestoreRateLimiter {
  constructor(private readonly db: Firestore) {}
  async consume(uid: string, now: number): Promise<void> {
    const window = Math.floor(now / 60);
    const refs = [this.db.doc(`authorizationRateLimits/u_${idHash(uid)}`), this.db.doc("authorizationRateLimits/global")];
    await this.db.runTransaction(async tx => {
      const documents = await tx.getAll(...refs);
      const counts = documents.map(d => {
        const data = d.data();
        if (!data || data.window !== window) return 0;
        if (!Number.isSafeInteger(data.count) || data.count < 0) throw new AccessError("unavailable");
        return data.count as number;
      });
      if (counts[0]! >= 10 || counts[1]! >= 100) throw new AccessError("resource-exhausted");
      refs.forEach((ref, i) => tx.set(ref, {window, count: counts[i]! + 1, expiresAt: Timestamp.fromMillis((now + 86400) * 1000)}));
    });
  }
}
