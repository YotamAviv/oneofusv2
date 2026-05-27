function streamRef(db, issuerToken, streamName) {
  return db.collection(issuerToken).doc(streamName);
}
function statementsRef(db, issuerToken, streamName) {
  return streamRef(db, issuerToken, streamName).collection('statements');
}
const statementPrefix = 'net.one-of-us';
module.exports = { streamRef, statementsRef, statementPrefix };
