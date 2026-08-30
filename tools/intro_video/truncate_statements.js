#!/usr/bin/env node
/**
 * Truncate a key's statement stream back to a fixed point.
 *
 *   node bin/truncate_statements.js --token <T> --after <ISO8601>
 *   node bin/truncate_statements.js --token <T> --keep <statementToken>
 *   node bin/truncate_statements.js --token <T> --all
 *
 * Defaults to the emulator. Add --prod to hit production, --dry-run to see what
 * would go without deleting.
 *
 * WHY THIS ISN'T JUST A DELETE. Statements are a hash chain: each one carries
 * `previous`, and the stream document holds `head` and `headTime`. Deleting
 * documents without rewinding the head leaves the stream pointing at a statement
 * that no longer exists, and the next write fails its chain check with
 * "chain race: expected <gone>". So this deletes the tail *and* resets the head
 * to the newest survivor.
 *
 * Layout (functions/schema.js):
 *   <issuerToken>/<streamName>                    { head, headTime }
 *   <issuerToken>/<streamName>/statements/<token> the statement
 */
const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

/**
 * HARD RULE: only demo-user statements may ever be deleted.
 *
 * Everything else in these stores belongs to real people. A wrong --token here
 * would silently destroy someone's identity history, and there is no undo. So
 * the token must appear in the generated demo key file; anything else is
 * refused before a connection is opened.
 */
const KEYS_FILE = process.env.DEMO_IDENTITY ||
  path.join(__dirname, 'demo_identity.json');

function demoTokens() {
  if (!fs.existsSync(KEYS_FILE)) {
    throw new Error(`demo identity file not found: ${KEYS_FILE}\n` +
      'Refusing to delete anything without it — it is the only allowlist of demo-owned keys.');
  }
  const { demoTokens = {} } = JSON.parse(fs.readFileSync(KEYS_FILE, 'utf8'));
  return new Map(Object.entries(demoTokens).map(([name, t]) => [t, name]));
}

function assertDemoOwned(token) {
  const tokens = demoTokens();
  const name = tokens.get(token);
  if (!name) {
    throw new Error(
      `REFUSED: ${token} is not a demo-owned key.\n` +
      `Only keys listed in ${KEYS_FILE} may be truncated. Every other key in this\n` +
      `store belongs to a real person, and deletion cannot be undone.\n` +
      `Known demo keys: ${[...tokens.entries()].map(([t, n]) => `${n}=${t.slice(0, 12)}`).join(', ') || '(none)'}`);
  }
  return name;
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
  const token = arg('token');
  const which = arg('project', 'oneofus');
  const stream = arg('stream', 'statements');
  const after = arg('after');
  const keep = arg('keep');
  const all = has('all');
  const prod = has('prod');
  const dry = has('dry-run');

  if (!token) throw new Error('--token <issuer key token> is required');
  if (!all && !after && !keep) throw new Error('one of --after <ISO>, --keep <token>, --all');
  const proj = PROJECTS[which];
  if (!proj) throw new Error(`--project must be one of ${Object.keys(PROJECTS).join(', ')}`);

  const owner = assertDemoOwned(token);   // before any connection is opened
  console.log(`token belongs to demo identity '${owner}'`);

  if (prod) {
    delete process.env.FIRESTORE_EMULATOR_HOST;
    admin.initializeApp({ projectId: proj.prod });
  } else {
    process.env.FIRESTORE_EMULATOR_HOST = `localhost:${proj.emulatorPort}`;
    admin.initializeApp({ projectId: proj.prod });
  }
  const db = admin.firestore();

  const streamRef = db.collection(token).doc(stream);
  const stmtsRef = streamRef.collection('statements');

  const snap = await stmtsRef.get();
  if (snap.empty) {
    console.log(`no statements under ${token}/${stream} — nothing to do`);
    return;
  }

  // Chain order and time order agree: write2 rejects a statement whose time is
  // not strictly greater than the current head's.
  const stmts = snap.docs
    .map(d => ({ token: d.id, time: d.data().time ?? null, data: d.data() }))
    .sort((a, b) => String(a.time).localeCompare(String(b.time)));

  let survivors;
  if (all) {
    survivors = [];
  } else if (keep) {
    const idx = stmts.findIndex(s => s.token === keep);
    if (idx < 0) throw new Error(`--keep ${keep} is not in this stream`);
    survivors = stmts.slice(0, idx + 1);
  } else {
    survivors = stmts.filter(s => s.time !== null && String(s.time) <= String(after));
  }
  const doomed = stmts.slice(survivors.length);

  console.log(`${prod ? 'PRODUCTION' : 'emulator'}  ${which}  ${token}/${stream}`);
  console.log(`  ${stmts.length} statements, keeping ${survivors.length}, deleting ${doomed.length}`);
  for (const s of doomed) {
    const v = s.data.verb ?? s.data.statement ?? Object.keys(s.data).slice(0, 3).join(',');
    console.log(`    - ${s.time}  ${s.token.slice(0, 12)}  ${v}`);
  }
  if (dry) { console.log('  (dry run — nothing deleted)'); return; }
  if (!doomed.length) { console.log('  nothing to delete'); return; }

  if (prod) {
    // Deliberately awkward: production statements are public and permanent to
    // anyone who already fetched them. Deleting only stops them being served.
    const ok = process.env.I_MEAN_IT === 'yes';
    if (!ok) throw new Error('refusing to delete from production without I_MEAN_IT=yes');
  }

  const batch = db.batch();
  for (const s of doomed) batch.delete(stmtsRef.doc(s.token));

  const head = survivors.length ? survivors[survivors.length - 1] : null;
  if (head) {
    batch.set(streamRef, { head: head.token, headTime: head.time }, { merge: true });
  } else {
    // No survivors: clear the pointer so the next write starts a fresh chain.
    batch.set(streamRef, { head: null, headTime: null }, { merge: true });
  }
  await batch.commit();

  console.log(`  deleted ${doomed.length}; head is now ${head ? head.token.slice(0, 12) + ' @ ' + head.time : 'null (empty chain)'}`);
}

main().then(() => process.exit(0)).catch(e => { console.error(String(e.message || e)); process.exit(1); });
