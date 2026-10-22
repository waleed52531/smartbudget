import {generateKeyPairSync} from "node:crypto";
import {mkdirSync, realpathSync, writeFileSync} from "node:fs";
import {basename, isAbsolute, relative, resolve, sep} from "node:path";
import {parseArgs} from "node:util";
import {initializeApp, applicationDefault} from "firebase-admin/app";
import {getAuth} from "firebase-admin/auth";
import {getFirestore} from "firebase-admin/firestore";
import {FirestoreBetaStore} from "./membership";
import {validUid} from "./security";

export function checkAdminTarget(project: string, confirm: string | undefined, emulator: boolean): void {
  if (emulator) {
    if (project !== "demo-smartbudget-authz" || !process.env.FIRESTORE_EMULATOR_HOST?.match(/^(127\.0\.0\.1|localhost):\d+$/) ||
        !process.env.FIREBASE_AUTH_EMULATOR_HOST?.match(/^(127\.0\.0\.1|localhost):\d+$/)) throw new Error("Explicit local emulators required.");
  } else if (project !== "smartbudget-561d4" || confirm !== project ||
      process.env.FIRESTORE_EMULATOR_HOST || process.env.FIREBASE_AUTH_EMULATOR_HOST) {
    throw new Error("Explicit approved production project confirmation required.");
  }
}

export function generateSigningKey(kid: string, privateOutput: string, publicOutput: string): void {
  if (!/^[A-Za-z0-9_-]{1,64}$/.test(kid)) throw new Error("Invalid key identifier.");
  const repository = resolve(__dirname, "../../..");
  const destination = resolve(privateOutput);
  const relativePath = relative(repository, destination);
  const outsideRepository = relativePath === ".." || relativePath.startsWith(`..${sep}`) || isAbsolute(relativePath);
  if (!outsideRepository || destination === resolve(publicOutput)) {
    throw new Error("Private key must be written outside this repository.");
  }
  const pair = generateKeyPairSync("ed25519");
  mkdirSync(resolve(destination, ".."), {recursive: true, mode: 0o700});
  const actualRelative = relative(realpathSync(repository), resolve(realpathSync(resolve(destination, "..")), basename(destination)));
  if (!(actualRelative === ".." || actualRelative.startsWith(`..${sep}`) || isAbsolute(actualRelative))) {
    throw new Error("Private key destination resolves inside this repository.");
  }
  writeFileSync(destination, pair.privateKey.export({format: "pem", type: "pkcs8"}), {flag: "wx", mode: 0o600});
  const jwk = pair.publicKey.export({format: "jwk"});
  writeFileSync(resolve(publicOutput), JSON.stringify({keys: [{kty: "OKP", crv: "Ed25519", x: jwk.x,
    kid, alg: "EdDSA", use: "sig"}]}, null, 2) + "\n", {flag: "wx", mode: 0o600});
}

async function main(): Promise<void> {
  const parsed = parseArgs({allowPositionals: true, options: {
    project: {type: "string"}, "confirm-project": {type: "string"}, emulator: {type: "boolean"},
    uid: {type: "string"}, email: {type: "string"}, kid: {type: "string"},
    "private-output": {type: "string"}, "public-output": {type: "string"},
  }});
  const v = parsed.values;
  const command = parsed.positionals[0];
  if (command === "keygen") {
    if (!v.kid || !v["private-output"] || !v["public-output"]) throw new Error("Key output paths and kid required.");
    generateSigningKey(v.kid, v["private-output"], v["public-output"]);
    process.stdout.write("Key files created exclusively; no private key printed.\n");
    return;
  }
  if (!v.project || !["approve", "revoke", "status", "find-user"].includes(command ?? "")) throw new Error("Expected approve, revoke, status, find-user or keygen with explicit arguments.");
  checkAdminTarget(v.project, v["confirm-project"], v.emulator ?? false);
  initializeApp({projectId: v.project, ...(v.emulator ? {} : {credential: applicationDefault()})});
  const auth = getAuth(), members = new FirestoreBetaStore(getFirestore());
  if (command === "status") {
    process.stdout.write(JSON.stringify({activeUids: await members.status()}) + "\n");
  } else if (command === "find-user") {
    if (!v.email) throw new Error("Email required for administrator lookup.");
    const user = await auth.getUserByEmail(v.email);
    process.stdout.write(JSON.stringify({uid: user.uid, disabled: user.disabled}) + "\n");
  } else {
    if (!validUid(v.uid)) throw new Error("Existing Firebase UID required.");
    if (command === "approve") {
      const user = await auth.getUser(v.uid);
      if (user.disabled || !user.providerData.some(p => p.providerId === "password")) throw new Error("Enabled email/password account required.");
      await members.approve(user.uid);
    } else {
      await members.revoke(v.uid);
      // Membership is denied before this secondary operation; a failure never
      // rolls approval back to active or permits further lease issuance.
      await auth.revokeRefreshTokens(v.uid);
    }
    process.stdout.write("Administrative operation completed.\n");
  }
}

if (require.main === module) main().catch(() => {
  process.stderr.write("Administrative operation failed. Check target, IAM, roster integrity and account state; no approval is implied. For revoke, membership may already be denied; confirm status before retrying.\n");
  process.exitCode = 1;
});
