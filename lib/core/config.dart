import 'dart:convert';

enum FireChoice {
  fake,
  emulator,
  prod;
}

class Config {
  // --- Environment Switch ---
  static FireChoice fireChoice = FireChoice.fake;

  // --- Service Registry (formerly V2Config) ---
  static final Map<String, String> _urls = {};

  static void registerUrl(String domain, String url) {
    _urls[domain] = url;
  }

  static String? getUrl(String domain) => _urls[domain];

  static Uri makeSimpleUri(String domain, dynamic spec, {String? revokeAt}) {
    final String? baseUrl = getUrl(domain);
    if (baseUrl == null) {
      return Uri.parse('about:blank');
    }

    final uri = Uri.parse(baseUrl);
    final params = <String, String>{'spec': jsonEncode(spec)};
    if (revokeAt != null) {
      params['revokeAt'] = revokeAt;
    }

    final newParams = Map<String, String>.from(uri.queryParameters)..addAll(params);
    return uri.replace(queryParameters: newParams);
  }

  // --- Static Named Endpoints ---
  static String get exportUrl {
    switch (fireChoice) {
      case FireChoice.emulator:
        // Use 10.0.2.2 for Android Emulator to access host's localhost
        return 'http://10.0.2.2:5002/one-of-us-net/us-central1/export';
      case FireChoice.prod:
      default:
        return 'https://export.one-of-us.net';
    }
  }

  /// This is the endpoint we tell the server to use when it needs to fetch data.
  /// If the server is also running in an emulator on the same host, it should use 127.0.0.1.
  static String get exportUrlForServer {
    switch (fireChoice) {
      case FireChoice.emulator:
        return 'http://127.0.0.1:5002/one-of-us-net/us-central1/export';
      case FireChoice.prod:
      default:
        return 'https://export.one-of-us.net';
    }
  }

  static String get signInUrl {
     switch (fireChoice) {
      case FireChoice.emulator:
        return 'http://10.0.2.2:5001/nerdster/us-central1/signin';
      case FireChoice.prod:
      default:
        return 'https://signin.nerdster.org/signin';
    }
  }
}
