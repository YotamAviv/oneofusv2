import 'package:oneofus_common/jsonish.dart';

/// Validates the integrity of a chain of statements.
class NotaryChainVerifier {
  /// Verifies that a list of statements forms a valid, unbroken chain.
  /// Expects statements to be ordered from newest to oldest.
  /// 
  /// Throws an [Exception] if the chain is invalid.
  void verify(List<Jsonish> chain) {
    if (chain.isEmpty) return;

    for (int i = 0; i < chain.length - 1; i++) {
      final current = chain[i];
      final next = chain[i + 1];

      // 1. Check Linkage: current.previous must equal next.token
      final previousToken = current['previous'];
      if (previousToken == null) {
        // Only the very first statement ever made by a key can have no 'previous'.
        // In a chain, if we aren't at the end, 'previous' MUST exist.
        throw Exception('Broken chain: Statement ${current.token} is missing "previous" link.');
      }

      if (previousToken != next.token) {
        throw Exception('Broken chain: Statement ${current.token} points to $previousToken, but next is ${next.token}.');
      }

      // 2. Check Timestamps: current.time must be >= next.time
      final currentTime = DateTime.parse(current['time']);
      final nextTime = DateTime.parse(next['time']);
      
      if (currentTime.isBefore(nextTime)) {
        throw Exception('Timestamp violation: Statement ${current.token} (${current['time']}) is older than its predecessor ${next.token} (${next['time']}).');
      }
    }
  }
}
