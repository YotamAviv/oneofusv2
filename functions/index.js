/**
 * ONE-OF-US.NET Cloud Functions
 *
 * Deploy:
 *   firebase --project=one-of-us-net deploy --only functions:export
 *
 * Only the export function is needed here. Nerdster-specific functions
 * (fetchImages, magicPaste, signin) live in nerdster14/functions/.
 *
 * Code duplication: statement_fetcher.js and jsonish_util.js are copied across
 * nerdster14/, oneofusv22/, and hablotengo/functions/. Changes must be applied
 * to all three manually until a shared library is introduced.
 */

const { onRequest } = require("firebase-functions/v2/https");
const { logger } = require("firebase-functions");
const admin = require('firebase-admin');

const { fetchStatements } = require('./statement_fetcher');
const { parseIrevoke } = require('./jsonish_util');

if (admin.apps.length === 0) {
  admin.initializeApp();
}

/**
 * Exports statements as a JSON stream.
 * Mapped to https://export.one-of-us.net
 */
exports.export = onRequest({ cors: true, minInstances: 1 }, async (req, res) => {
  if (req.path === '/openapi.yaml') {
    const fs = require('fs');
    const path = require('path');
    const yaml = fs.readFileSync(path.join(__dirname, 'openapi.yaml'), 'utf8');
    res.setHeader('Content-Type', 'application/yaml');
    res.send(yaml);
    return;
  }

  res.setHeader('Content-Type', 'application/json');
  res.setHeader('Cache-Control', 'no-cache');
  res.setHeader('Connection', 'keep-alive');

  try {
    const specParam = req.query.spec;
    if (!specParam) {
      res.status(400).type('text').send(
        'ONE-OF-US.NET Export API\n\n' +
        'Required parameter: spec — key token or JSON array/object of tokens.\n\n' +
        'Optional parameters:\n' +
        '  distinct                    — deduplicate by verb+subject (keep most recent)\n' +
        '  orderStatements             — default true; set false to skip key ordering\n' +
        '  includeId                   — include the statement token as "id" field on each statement\n' +
        '  checkPrevious               — verify notarization chain (requires includeId)\n' +
        '  after=<ISO time>            — only return statements newer than this time\n' +
        '  omit=<field>                — strip field from each statement (repeatable)\n' +
        '  subcollection=<doc/col>     — default "statements/statements"; use "dis/statements" for dismiss stream\n\n' +
        'Example:\n' +
        '  https://export.one-of-us.net/?spec=<token>&distinct=true&omit=I&omit=signature\n\n' +
        'See /openapi.yaml for full API documentation.\n'
      );
      return;
    }

    const specString = decodeURIComponent(specParam);
    let specs = /^\s*[\[{"]/.test(specString) ? JSON.parse(specString) : specString;
    if (!Array.isArray(specs)) specs = [specs];

    const params = req.query;
    const omit = params.omit;

    for (const spec of specs) {
      let token = "unknown";
      try {
        const token2revoked = parseIrevoke(spec);
        token = Object.keys(token2revoked)[0];
        const statements = await fetchStatements(token2revoked, params, omit);
        res.write(JSON.stringify({ [token]: statements }) + '\n');
      } catch (e) {
        logger.error(`[export] Error processing ${typeof spec === 'string' ? spec : JSON.stringify(spec)}: ${e.message}`);
        res.write(JSON.stringify({ [token]: { error: e.message } }) + '\n');
      }
    }
    res.end();
  } catch (e) {
    logger.error(`[export] Error: ${e.message}`);
    if (!res.headersSent) {
      res.status(500).send(`Error: ${e.message}`);
    } else {
      res.end();
    }
  }
});
