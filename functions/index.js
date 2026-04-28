/**
 * ONE-OF-US.NET Cloud Functions — entry point
 *
 * Each function is implemented in its own file. This file only registers them.
 *
 * Deploy:
 *   firebase --project=one-of-us-net deploy --only functions
 *
 * Shared files (keep identical across nerdster14, oneofusv22, hablotengo):
 *   write.js, verify_util.js, jsonish_util.js, statement_fetcher.js, export.js
 */

const { onCall, onRequest, HttpsError } = require("firebase-functions/v2/https");
const admin = require('firebase-admin');

if (admin.apps.length === 0) {
  admin.initializeApp();
}

const { handleWrite } = require('./write');
const { handleExport } = require('./export');

exports.write = onCall(async (request) => {
  try {
    return await handleWrite(request.data);
  } catch (e) {
    throw new HttpsError('internal', e.message);
  }
});

exports.export = onRequest({ cors: true, minInstances: 1 }, async (req, res) => {
  return await handleExport(req, res);
});
