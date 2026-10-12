#!/usr/bin/env node
/**
 * dump_vouches.js — read-only: who is vouching for whom at production one-of-us.net.
 *
 * Prints every current vouch (the latest statement from an issuer about a subject is a
 * `trust`), then again with me, the Simpsons/demo cast, role placeholders ("Mom", "boss")
 * and keyboard-mash test names removed.
 *
 * Usage:
 *   node bin/dump_vouches.js              # prod (application default credentials)
 *   node bin/dump_vouches.js --emulator   # local emulator at 127.0.0.1:8080
 */

const fs = require('fs');
const path = require('path');
const admin = require('../functions/node_modules/firebase-admin');
const { getToken } = require('../functions/jsonish_util');

if (process.argv.includes('--emulator')) {
  process.env.FIRESTORE_EMULATOR_HOST = process.env.FIRESTORE_EMULATOR_HOST || '127.0.0.1:8080';
}

// Demo keys live next to the repos, not in them.
const DEMO_KEY_FILES = [
  'simpsonsPublicKeys.json',
  'simpsonsHabloKeys.json',
  'videoDemoPublicKeys.json',
].map(f => path.resolve(__dirname, '../..', f));

const ME = new Set(['tom', 'tommy', 'tomasito', 'tonmy', 'tom m', 'yotam', 'yotam aviv', 'myself']);

// Includes Bart's prank-call names and the renamings used in demos ("4-Eyes", "Boy").
const SIMPSONS = new Set([
  'lisa', 'lusa', 'bart', 'bart 2', 'batt', 'homer', 'homer2', 'homes', 'holmes', 'marge',
  'maggie', 'milhouse', 'mel', 'krusty', 'ralph', 'carl', 'lenny', 'nelson', 'smithers',
  'sideshow', 'sideshow t. c.', 'sideshow t. clown', 'burns', 'luann', 'seymore butts',
  'amanda hugginkiss', 'amanda huggenkiss', 'hugh g. reckshin', 'ben dover', 'dick hurtz',
  '4-eyes',
]);

const ROLES = new Set([
  'mom', 'moms', 'dad', 'boy', 'my boy', 'son', 'daughter', 'sis', 'sister', 'hubby',
  'hubby2', 'wife', 'partner', 'boss', 'staff', 'colleague', 'friend', 'baby', 'babe',
  'mi amor', 'jock', 'hipster', 'poser', 'poser asd asd', 'clown', 'burner',
]);

const JUNK = new Set([
  'asdf', 'asdfasdf', 'asdasdf', 'asd', 'sdf', 'sdfsdf', 'sdsdfsdf', 'dfdf', 'dffddf',
  'tttxx', '3aaaa', 'gggcf', 'nnm', 'hggf', 'b2', 'and', 'to', 'she', 'never', 'neverw',
  'not sure', 'another', 'town', 'emulator', 'iphone', 'moto', 'moto2', 'stege', 'amo',
  'alis', 'titans delegate', 'trusting my own delegate!?',
]);

function classify(name) {
  const n = (name ?? '').trim().toLowerCase();
  if (!n) return 'unnamed';
  if (ME.has(n) || /^to+m+$/.test(n)) return 'me';
  if (SIMPSONS.has(n)) return 'simpsons';
  if (ROLES.has(n)) return 'role';
  if (JUNK.has(n) || /^(.)\1+$/.test(n) || /^steve2\w+$/.test(n)) return 'junk';
  return null;
}

function loadDemoTokens() {
  const tokens = new Map();
  for (const file of DEMO_KEY_FILES) {
    if (!fs.existsSync(file)) throw new Error(`missing demo key file: ${file}`);
    for (const [label, key] of Object.entries(JSON.parse(fs.readFileSync(file, 'utf8')))) {
      tokens.set(getToken(key), label);
    }
  }
  return tokens;
}

const VERBS = ['trust', 'block', 'clear', 'replace', 'delegate'];

async function main() {
  const demo = loadDemoTokens();

  admin.initializeApp({ projectId: 'one-of-us-net' });
  const snap = await admin.firestore().collectionGroup('statements').get();

  // Latest statement per (issuer, subject) decides the current disposition.
  const latest = new Map();
  for (const doc of snap.docs) {
    const s = doc.data();
    const verb = VERBS.find(v => s[v]);
    if (!verb || !s.I || !s.time) continue;
    const issuer = getToken(s.I);
    const subject = getToken(s[verb]);
    const k = `${issuer}:${subject}`;
    const prev = latest.get(k);
    if (!prev || s.time > prev.time) {
      latest.set(k, {
        issuer, subject, verb, time: s.time, name: s.with?.moniker ?? '',
        payload: { key: s[verb], ...(s.with?.endpoint ?? {}) },
      });
    }
  }
  const vouches = [...latest.values()].filter(v => v.verb === 'trust')
    .sort((a, b) => a.time.localeCompare(b.time));

  const issuers = new Set([...latest.values()].map(v => v.issuer));

  // A token anyone calls by my name or a Simpsons name is that, whatever else it's called.
  const meTokens = new Set();
  const castTokens = new Set(demo.keys());
  for (const v of vouches) {
    const c = classify(v.name);
    if (c === 'me') meTokens.add(v.subject);
    if (c === 'me' || c === 'simpsons') castTokens.add(v.subject);
  }

  const namesOf = new Map();
  for (const v of vouches) {
    if (!namesOf.has(v.subject)) namesOf.set(v.subject, new Set());
    if (v.name && !classify(v.name)) namesOf.get(v.subject).add(v.name.trim());
  }
  const label = t => {
    if (demo.has(t)) return `demo:${demo.get(t)}`;
    if (meTokens.has(t)) return 'me';
    return [...(namesOf.get(t) ?? [])].slice(0, 3).join('/');
  };

  const line = v => [
    v.time.slice(0, 10),
    v.subject,
    JSON.stringify(v.name).padEnd(22),
    issuers.has(v.subject) ? 'active' : '      ',
    `by ${v.issuer.slice(0, 8)} (${label(v.issuer) || '?'})`,
  ].join('  ');

  console.log(`=== All current vouches (${vouches.length}) ===`);
  vouches.forEach(v => console.log(line(v)));

  const interesting = vouches.filter(v =>
    !classify(v.name) && !castTokens.has(v.subject) && !demo.has(v.issuer));
  console.log(`\n=== Not me, not Simpsons/demo, not roles or junk (${interesting.length}) ===`);
  interesting.forEach(v => console.log(line(v)));

  // ?pov= takes the FedKey payload JSON; a bare token is silently ignored.
  const povs = new Map(interesting.map(v => [v.subject, v]));
  console.log(`\n=== PoV links (${povs.size}) ===`);
  for (const v of povs.values()) {
    const pov = encodeURIComponent(JSON.stringify(v.payload));
    console.log(`${label(v.subject).padEnd(30)}  https://nerdster.org/app?pov=${pov}`);
  }

  console.log('\n"active": the vouched-for key has published statements of its own.');
}

main().catch(e => { console.error(e); process.exit(1); });
