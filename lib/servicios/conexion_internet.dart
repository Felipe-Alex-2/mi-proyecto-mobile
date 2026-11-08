import 'package:http/http.dart' as http;

/// Checks the internet independently of the business API. An HTTP response,
/// including a server error, proves connectivity and must not enable offline mode.
Future<bool> internetDisponible() async {
  final client = http.Client();
  try {
    for (final address in [
      'https://www.gstatic.com/generate_204',
      'https://www.cloudflare.com/cdn-cgi/trace',
    ]) {
      try {
        await client
            .get(Uri.parse(address))
            .timeout(const Duration(seconds: 4));
        return true;
      } catch (_) {
        // A second independent host avoids depending on one provider.
      }
    }
    return false;
  } finally {
    client.close();
  }
}
