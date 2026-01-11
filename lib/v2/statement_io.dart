import 'package:oneofus_common/jsonish.dart';
import 'package:oneofus_common/statement.dart';

/// Contract for fetching statements from a source.
abstract class StatementSource {
  /// Fetches a list of statements for a given set of keys.
  /// The [keys] map contains the public key tokens as keys, and optionally 
  /// a 'since' token to fetch only new statements.
  Future<Map<String, List<Jsonish>>> fetch(Map<String, String?> keys);
}

/// Contract for pushing a new statement to a destination.
abstract class StatementPusher {
  /// Pushes a single statement to the destination.
  Future<void> push(Jsonish statement);
}
