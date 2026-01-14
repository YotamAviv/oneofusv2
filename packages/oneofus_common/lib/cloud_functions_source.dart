import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:oneofus_common/io.dart';
import 'package:oneofus_common/statement.dart';
import 'package:oneofus_common/source_error.dart';
import 'package:oneofus_common/jsonish.dart';

/// Fetches statements using the Cloud Function HTTP endpoint.
class CloudFunctionsSource<T extends Statement> implements StatementSource<T> {
  final String baseUrl;
  final String statementType;
  final http.Client client;
  final StatementVerifier verifier;
  final bool skipVerify; // Injected dependency

  final Map<String, SourceError> _errors = {};

  static const Map<String, dynamic> _paramsProto = {
    "distinct": "true",
    "orderStatements": "false",
    "includeId": "true",
    "checkPrevious": "true",
    "omit": ['statement', 'I'],
  };

  CloudFunctionsSource({
    required this.baseUrl,
    http.Client? client,
    required this.verifier,
    this.skipVerify = false,
  })  : statementType = Statement.type<T>(),
        client = client ?? http.Client();

  @override
  List<SourceError> get errors => List.unmodifiable(_errors.values);

  @override
  Future<Map<String, List<T>>> fetch(Map<String, String?> keys) async {
    print('baseUrl=$baseUrl');
    _errors.clear();
    if (keys.isEmpty) return {};

    final List<dynamic> spec = keys.entries.map((e) {
      if (e.value == null) return e.key;
      return {e.key: e.value};
    }).toList();

    final Map<String, dynamic> params = Map.of(_paramsProto);
    params['spec'] = jsonEncode(spec);

    final Uri uri = Uri.parse(baseUrl).replace(queryParameters: params);

    final http.Request request = http.Request('GET', uri);
    final http.StreamedResponse response = await client.send(request);

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch statements from $baseUrl: ${response.statusCode}');
    }

    final Map<String, List<T>> results = {};

    await for (final String line
        in response.stream.transform(utf8.decoder).transform(const LineSplitter())) {
      if (line.trim().isEmpty) continue;

      final Map<String, dynamic> jsonToken2Statements = jsonDecode(line);

      for (final MapEntry<String, dynamic> entry in jsonToken2Statements.entries) {
        final String token = entry.key;
        final dynamic value = entry.value;

        if (value is Map && value.containsKey('error')) {
          _errors[token] = SourceError(value['error'], token: token);
          results.remove(token);
          continue;
        }

        final List<dynamic> statementsJson = value as List<dynamic>;
        final List<T> list = results.putIfAbsent(token, () => []);
        final Map<String, String> iJson = {'I': token};

        try {
          for (final dynamic json in statementsJson) {
            final Jsonish? cached = Jsonish.find(token);
            json['I'] = cached != null ? cached.json : iJson;
            json['statement'] = statementType;

            final String? serverToken = json.remove('id');

            Jsonish jsonish;
            if (!skipVerify) {
              try {
                jsonish = await Jsonish.makeVerify(json, verifier);
              } catch (e) {
                throw SourceError('Invalid Signature: $e', token: token, originalError: e);
              }
            } else {
              jsonish = Jsonish(json, serverToken);
            }

            final Statement statement = Statement.make(jsonish);
            list.add(statement as T);
          }
        } catch (e) {
          _errors[token] = e is SourceError ? e : SourceError('Error processing statements: $e', token: token, originalError: e);
          results.remove(token);
        }
      }
    }
    return results;
  }
}
