/**
 * write — HTTP POST endpoint
 *
 * Appends a signed statement to an issuer's statement stream in Firestore.
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * REQUEST
 * ─────────────────────────────────────────────────────────────────────────────
 * POST {baseUrl}/write
 * Content-Type: application/json
 *
 * Body (Firebase callable envelope):
 * {
 *   "data": {
 *     "statement": <Statement>,   // required — the signed statement object
 *     "collection": <string>      // required — stream name, e.g. "statements" or "dis"
 *   }
 * }
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * FIRESTORE PATH
 * ─────────────────────────────────────────────────────────────────────────────
 * {token(I)} / {collection} / statements / {token(statement)}
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * RESPONSE
 * ─────────────────────────────────────────────────────────────────────────────
 * 200 OK: { "result": { "token": <statementToken> } }
 * Error: HTTP 500, body contains error message (previous mismatch, bad signature, etc.)
 */

const admin = require('firebase-admin');
const { verifyStatementSignature, statementToken, keyToken } = require('./verify_util');

async function handleWrite(data, context) {
  const { statement, collection } = data ?? {};

  if (!statement || typeof statement !== 'object') {
    throw new Error('missing statement');
  }
  if (!verifyStatementSignature(statement)) {
    throw new Error('invalid statement signature');
  }

  const iToken = await keyToken(statement['I']);
  const token = await statementToken(statement);
  const db = admin.firestore();

  const statementsRef = db
    .collection(iToken)
    .doc(collection)
    .collection('statements');

  const latestSnap = await statementsRef.orderBy('time', 'desc').limit(1).get();
  const latestToken = latestSnap.empty ? null : latestSnap.docs[0].id;
  const latestTime = latestSnap.empty ? null : latestSnap.docs[0].data()['time'];
  const clientPrevious = statement['previous'] ?? null;
  const clientTime = statement['time'] ?? null;

  if (latestToken === null && clientPrevious !== null) {
    throw new Error('genesis check failed: statement.previous must not be set for first write');
  }
  if (latestToken !== null && clientPrevious !== latestToken) {
    throw new Error(`previous mismatch: expected ${latestToken}, got ${clientPrevious}`);
  }
  if (latestTime !== null && clientTime !== null && clientTime <= latestTime) {
    throw new Error(`time ordering violation: ${clientTime} must be > ${latestTime}`);
  }

  await statementsRef.doc(token).set(statement);

  return { token };
}

module.exports = { handleWrite };
