#!/usr/bin/env node
/**
 * Record where a key's statement stream ends, so a take can be undone.
 *
 *   node snapshot_statements.js --token <T> --project oneofus --prod > before.json
 *   node truncate_statements.js --token <T> --project oneofus --prod \
 *     --keep $(jq -r '.streams["statements"].head' before.json)
 *
 * THE POINT. `close_account` publishes a `clear` statement and that is the whole
 * of its side effect -- these streams are append-only hash chains, so a take
 * cannot modify or remove anything, it can only add. Undoing it is therefore
 * exact: rewind the stream to the statement that was its head beforehand and
 * the clear never happened.
 *
 * WHY NOT JUST RESHOOT SIGN-IN to get a delegate key back. Because it is not the
 * SAME delegate key. The likes in the `nerdster` and `crypto_teaser` sections
 * were signed by the delegate that existed when those takes were shot; mint a
 * new one and those likes are orphaned -- signed by a key no statement links to
 * the identity any more -- and they vanish from the feed. Rewinding restores the
 * original delegate statement, so the original key, so the likes.
 *
 * An empty stream snapshots as head:null, which truncate reads as --all.
 *
 * Only demo-owned keys, enforced the same way truncate_statements.js enforces
 * it and for the same reason: everything else in these stores belongs to real
 * people.
 */
const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

const KEYS_FILE = process.env.DEMO_IDENTITY ||
  path.join(__dirname, 'demo_identity.json');

function demoTokens() {
  if (!fs.existsSync(KEYS_FILE)) {
    throw new Error(`demo identity file not found: ${KEYS_FILE}\n` +
      'Refusing to touch anything without it — it is the only allowlist of demo-owned keys.');
  }
  const { demoTokens = {} } = JSON.parse(fs.readFileSync(KEYS_FILE, 'utf8'));
  return new Map(Object.entries(demoTokens).map(([name, t]) => [t, name]));
}

function assertDemoOwned(token) {
  const name = demoTokens().get(token);
  if (!name) {
    throw new Error(`REFUSED: ${token} is not a demo-owned key.\n` +
      `Only keys listed in ${KEYS_FILE} may be snapshotted for rewinding.`);
  }
  return name;
}

/**
 * The token of a public key: SHA1 of its pretty-printed canonical JSON.
 * Same as truncate_statements.js -- a bare JWK holds none of the keys that
 * jsonish.dart positions, so plain alphabetical is canonical for these.
 */
function keyToken(key) {
  const ordered = {};
  for (const k of Object.keys(key).sort()) ordered[k] = key[k];
  return require('crypto').createHash('sha1')
    .update(JSON.stringify(ordered, null, 2)).digest('hex');
}

/**
 * The delegate keys an identity has published for a domain, newest first.
 *
 * Named this way because a delegate's token changes every time sign-in is
 * reshot, so nothing can hardcode it -- and a snapshot has to name the stream
 * it is snapshotting. The allowlist still holds: the IDENTITY must be
 * demo-owned, and the delegates come from that identity's own signed
 * statements, so this can only reach keys the demo identity delegated itself.
 */
async function delegatesOf(identityToken, domain) {
  const url = `https://export.one-of-us.net/?spec=${identityToken}&includeId=true`;
  const res = await fetch(url);
  if (!res.ok) throw new Error(`export.one-of-us.net returned ${res.status}`);
  const body = await res.json();
  const statements = body[identityToken] || [];
  const found = [];
  for (const s of statements.sort((a, b) => String(b.time).localeCompare(String(a.time)))) {
    if (!s.delegate) continue;
    if (domain && s.with?.domain !== domain) continue;
    const t = keyToken(s.delegate);
    if (!found.includes(t)) found.push(t);
  }
  return found;
}

const PROJECTS = {
  nerdster: { prod: 'nerdster', emulatorPort: 8080 },
  oneofus: { prod: 'one-of-us-net', emulatorPort: 8081 },
  karennet: { prod: 'karennet', emulatorPort: 8083 },
};

function arg(name, fallback) {
  const i = process.argv.indexOf('--' + name);
  return i >= 0 ? (process.argv[i + 1] ?? true) : fallback;
}
const has = name => process.argv.includes('--' + name);

async function main() {
  const which = arg('project', 'oneofus');
  const stream = arg('stream', 'statements');
  const prod = has('prod');
  const delegateOf = arg('delegate-of');
  const domain = arg('domain');
  const proj = PROJECTS[which];
  if (!proj) throw new Error(`--project must be one of ${Object.keys(PROJECTS).join(', ')}`);

  // --delegate-of, because the interesting stream is often not the identity's.
  // The ratings a section makes -- likes, dismisses, snoozes -- are published by
  // the DELEGATE, into the service's project, under a token that is minted fresh
  // on every sign-in. Snapshotting only the identity's own stream misses all of
  // it, which is how a take that meant to preserve the history preserved none
  // of it.
  let token, owner;
  if (delegateOf) {
    owner = assertDemoOwned(delegateOf);       // before any connection is opened
    const found = await delegatesOf(delegateOf, domain);
    if (!found.length) {
      throw new Error(`demo identity '${owner}' has no delegate` +
        `${domain ? ` for ${domain}` : ''} to snapshot`);
    }
    token = found[0];
  } else {
    token = arg('token');
    if (!token) throw new Error('--token <issuer key token> or --delegate-of <identity token>');
    owner = assertDemoOwned(token);
  }

  if (prod) {
    delete process.env.FIRESTORE_EMULATOR_HOST;
  } else {
    process.env.FIRESTORE_EMULATOR_HOST = `localhost:${proj.emulatorPort}`;
  }
  admin.initializeApp({ projectId: proj.prod });
  const db = admin.firestore();

  // The head is read from the STATEMENTS, not from the stream document. They
  // should agree, but the stream doc is what a bad write corrupts, and a
  // snapshot taken from a corrupt head would rewind to a statement that is not
  // there. Chain order and time order agree -- write2 rejects a statement whose
  // time is not strictly greater than the head's -- so the newest by time is
  // the head.
  const snap = await db.collection(token).doc(stream).collection('statements').get();
  const stmts = snap.docs
    .map(d => ({ token: d.id, time: d.data().time ?? null }))
    .sort((a, b) => String(a.time).localeCompare(String(b.time)));
  const head = stmts.length ? stmts[stmts.length - 1] : null;

  console.log(JSON.stringify({
    taken: new Date().toISOString(),
    identity: owner,
    token, project: which, prod: !!prod,
    delegateOf: delegateOf || null, domain: domain || null,
    streams: {
      [stream]: {
        head: head ? head.token : null,
        headTime: head ? head.time : null,
        count: stmts.length,
      },
    },
  }, null, 2));
}

main().catch(e => { console.error(e.message); process.exit(1); });
