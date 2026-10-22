import {importPKCS8, SignJWT} from 'jose';
import {AccessError} from '../../../functions/src/security';

export type Fetch = typeof fetch;
export const PROJECT = 'smartbudget-561d4';
export const PROJECT_NUMBER = '463515242262';
export const APP_ID = '1:463515242262:android:066c564503b6ba967e0a37';
export const SERVICE_ACCOUNT = `smartbudget-authz@${PROJECT}.iam.gserviceaccount.com`;

// Never retain HTTP responses in exceptions: Auth responses can contain private
// account information. Bodies, headers, tokens and upstream exceptions are not logged.
export class GoogleFailure extends AccessError {
  constructor(readonly status: number, readonly apiStatus?: string) {
    super('unavailable');
  }
}

export async function jsonRequest(
  url: string, init: RequestInit, send: Fetch = fetch, limit = 131072, allowArray = false,
): Promise<Record<string, any>> {
  try {
    // Workers supports manual redirects, but not Fetch's "error" mode. Reject
    // every redirect explicitly so an OAuth/Auth token never follows one.
    const response = await send(url, {...init, redirect: 'manual', signal: AbortSignal.timeout(10000)});
    if (response.status >= 300 && response.status < 400) throw new AccessError('unavailable');
    if (response.headers.get('content-length') && Number(response.headers.get('content-length')) > limit) {
      throw new AccessError('unavailable');
    }
    if (!response.body) throw new AccessError('unavailable');
    const reader = response.body.getReader();
    const chunks: Uint8Array[] = [];
    let length = 0;
    try {
      while (true) {
        const {value, done} = await reader.read();
        if (done) break;
        length += value.length;
        if (length > limit) throw new AccessError('unavailable');
        chunks.push(value);
      }
    } finally { await reader.cancel(); }
    const data = JSON.parse(Buffer.concat(chunks).toString('utf8'));
    if (!data || typeof data !== 'object' || (Array.isArray(data) && !allowArray)) throw new AccessError('unavailable');
    if (!response.ok) {
      const status = data.error?.status;
      throw new GoogleFailure(response.status,
        ['ABORTED', 'NOT_FOUND', 'PERMISSION_DENIED', 'UNAUTHENTICATED', 'RESOURCE_EXHAUSTED'].includes(status) ? status : undefined);
    }
    return data;
  } catch (error) {
    if (error instanceof AccessError) throw error;
    throw new AccessError('unavailable');
  }
}

export class GoogleOAuth {
  private cached?: {value: string; until: number};
  constructor(private readonly privatePem: string, private readonly send: Fetch = fetch,
    private readonly now = () => Math.floor(Date.now() / 1000)) {}
  async token(): Promise<string> {
    const now = this.now();
    if (this.cached && this.cached.until > now + 60) return this.cached.value;
    try {
      const key = await importPKCS8(this.privatePem, 'RS256');
      const assertion = await new SignJWT({scope: 'https://www.googleapis.com/auth/cloud-platform'})
        .setProtectedHeader({alg: 'RS256', typ: 'JWT'}).setIssuer(SERVICE_ACCOUNT)
        .setAudience('https://oauth2.googleapis.com/token').setIssuedAt(now).setExpirationTime(now + 3600).sign(key);
      const data = await jsonRequest('https://oauth2.googleapis.com/token', {
        method: 'POST', headers: {'content-type': 'application/x-www-form-urlencoded'},
        body: new URLSearchParams({grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer', assertion}).toString(),
      }, this.send);
      if (typeof data.access_token !== 'string' || !data.access_token ||
          !Number.isSafeInteger(data.expires_in) || data.expires_in < 60 || data.expires_in > 3600) {
        throw new AccessError('unavailable');
      }
      this.cached = {value: data.access_token, until: now + data.expires_in};
      return this.cached.value;
    } catch { throw new AccessError('unavailable'); }
  }
}

export class GoogleRest {
  constructor(private readonly oauth: {token(): Promise<string>}, readonly send: Fetch = fetch) {}
  async request(url: string, body?: unknown, method = body === undefined ? 'GET' : 'POST', allowArray = false): Promise<Record<string, any>> {
    return jsonRequest(url, {
      method, headers: {authorization: `Bearer ${await this.oauth.token()}`, 'content-type': 'application/json'},
      ...(body === undefined ? {} : {body: JSON.stringify(body)}),
    }, this.send, 131072, allowArray);
  }
}
