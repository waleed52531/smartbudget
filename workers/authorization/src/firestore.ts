import {createHash} from 'node:crypto';
import type {BetaStore} from '../../../functions/src/membership';
import {AccessError, MAX_BETA_MEMBERS, validUid} from '../../../functions/src/security';
import {GoogleFailure, GoogleRest, PROJECT} from './firebase_rest';

const hash = (value: string) => createHash('sha256').update(value).digest('hex');
const database = `https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/(default)`;
const documentName = `projects/${PROJECT}/databases/(default)/documents`;
const rosterPath = 'authorization/betaRoster';
const memberPath = (uid: string) => `authorizationMembers/${hash(uid)}`;
type Document = Record<string, any>;

function allowed(path: string): void {
  if (path !== rosterPath && path !== 'authorizationRateLimits/global' &&
      !/^authorizationMembers\/[a-f0-9]{64}$/.test(path) &&
      !/^authorizationGrants\/[a-f0-9]{64}$/.test(path) &&
      !/^authorizationRateLimits\/u_[a-f0-9]{64}$/.test(path)) throw new AccessError('unavailable');
}
function decode(value: any): any {
  if (!value || typeof value !== 'object') throw new AccessError('unavailable');
  if (typeof value.stringValue === 'string') return value.stringValue;
  if (typeof value.integerValue === 'string' && /^-?\d+$/.test(value.integerValue) &&
      Number.isSafeInteger(Number(value.integerValue))) return Number(value.integerValue);
  if (typeof value.timestampValue === 'string') return value.timestampValue;
  if (value.arrayValue && typeof value.arrayValue === 'object') {
    const values = value.arrayValue.values ?? [];
    if (!Array.isArray(values)) throw new AccessError('unavailable');
    return values.map(decode);
  }
  throw new AccessError('unavailable');
}
function fields(data: Document): Document {
  return Object.fromEntries(Object.entries(data).map(([name, value]) => {
    if (typeof value === 'string') return [name, {stringValue: value}];
    if (Number.isSafeInteger(value)) return [name, {integerValue: String(value)}];
    if (Array.isArray(value) && value.every(v => typeof v === 'string')) {
      return [name, {arrayValue: {values: value.map(v => ({stringValue: v}))}}];
    }
    if (value instanceof Date) return [name, {timestampValue: value.toISOString()}];
    throw new AccessError('unavailable');
  }));
}

export class RestTransaction {
  readonly writes: Document[] = [];
  constructor(private readonly api: GoogleRest, readonly id: string) {}
  async get(path: string): Promise<Document | undefined> {
    allowed(path);
    if (this.writes.length) throw new AccessError('unavailable');
    {
      // batchGet keeps the transaction bytes in the JSON body. It is supported
      // by both production Firestore and the official emulator's REST gateway.
      const response = await this.api.request(`${database}/documents:batchGet`, {
        documents: [`${documentName}/${path}`], transaction: this.id,
      }, 'POST', true);
      if (!Array.isArray(response) || response.length !== 1) throw new AccessError('unavailable');
      if (response[0]?.missing === `${documentName}/${path}`) return undefined;
      const doc = response[0]?.found;
      if (!doc) throw new AccessError('unavailable');
      if (doc.name !== `${documentName}/${path}` || !doc.fields || typeof doc.fields !== 'object') throw new AccessError('unavailable');
      return Object.fromEntries(Object.entries(doc.fields).map(([key, value]) => [key, decode(value)]));
    }
  }
  set(path: string, data: Document): void {
    allowed(path);
    this.writes.push({update: {name: `${documentName}/${path}`, fields: fields(data)}});
  }
}

export class RestFirestore {
  constructor(private readonly api: GoogleRest) {}
  async transaction<T>(action: (tx: RestTransaction) => Promise<T>): Promise<T> {
    for (let attempt = 0; attempt < 3; attempt++) {
      const begun = await this.api.request(`${database}/documents:beginTransaction`, {options: {readWrite: {}}});
      if (typeof begun.transaction !== 'string' || !begun.transaction) throw new AccessError('unavailable');
      const tx = new RestTransaction(this.api, begun.transaction);
      try {
        const result = await action(tx);
        await this.api.request(`${database}/documents:commit`, {transaction: tx.id, writes: tx.writes});
        return result;
      } catch (error) {
        try { await this.api.request(`${database}/documents:rollback`, {transaction: tx.id}); } catch { /* Expired transactions are not recovery permission. */ }
        if (!(error instanceof GoogleFailure) || error.apiStatus !== 'ABORTED' || attempt === 2) throw error;
      }
    }
    throw new AccessError('unavailable');
  }
}

export function roster(data: Document | undefined): string[] {
  if (!data) return [];
  if (data.version !== 1 || !Array.isArray(data.members) || data.members.length > MAX_BETA_MEMBERS ||
      data.members.some((uid: unknown) => !validUid(uid)) || new Set(data.members).size !== data.members.length) throw new AccessError('unavailable');
  return data.members;
}

export class RestBetaStore implements BetaStore {
  constructor(private readonly db: RestFirestore) {}
  private async active(tx: RestTransaction, uid: string): Promise<void> {
    const members = roster(await tx.get(rosterPath));
    const member = await tx.get(memberPath(uid));
    if (!members.includes(uid) || member?.uid !== uid || member.state !== 'active') throw new AccessError('permission-denied');
  }
  async assertActive(uid: string): Promise<void> { await this.db.transaction(tx => this.active(tx, uid)); }
  async commitGrant(uid: string, installationId: string, jti: string, exp: number): Promise<void> {
    await this.db.transaction(async tx => {
      await this.active(tx, uid);
      tx.set(`authorizationGrants/${hash(uid + ':' + installationId)}`, {
        uid, installationId, jti, expiresAt: new Date(exp * 1000),
      });
    });
  }
}

export class RestRateLimiter {
  constructor(private readonly db: RestFirestore) {}
  async consume(uid: string, now: number): Promise<void> {
    const window = Math.floor(now / 60);
    const paths = [`authorizationRateLimits/u_${hash(uid)}`, 'authorizationRateLimits/global'];
    await this.db.transaction(async tx => {
      const documents = [];
      for (const path of paths) documents.push(await tx.get(path));
      const counts = documents.map(d => {
        if (!d || d.window !== window) return 0;
        if (!Number.isSafeInteger(d.count) || d.count < 0) throw new AccessError('unavailable');
        return d.count as number;
      });
      if (counts[0]! >= 10 || counts[1]! >= 100) throw new AccessError('resource-exhausted');
      paths.forEach((path, i) => tx.set(path, {window, count: counts[i]! + 1, expiresAt: new Date((now + 86400) * 1000)}));
    });
  }
}
