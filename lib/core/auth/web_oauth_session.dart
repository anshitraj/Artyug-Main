import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'oauth_url.dart';

/// Runs after [Supabase.initialize]. Exchanges `?code=` for a session when the deep-link
/// observer path fails, and clears OAuth query params from the address bar.
Future<void> finalizeWebOAuthSessionIfNeeded() async {
  if (!kIsWeb) return;
  debugLogOAuthUri();
  final location = oauthBrowserUri();
  final hasCode = location.queryParameters.containsKey('code');
  final hasTokenFragment = location.fragment.contains('access_token=');
  final hasError = location.queryParameters.containsKey('error') ||
      location.queryParameters.containsKey('error_description');
  if (!hasCode && !hasTokenFragment && !hasError) return;

  final auth = Supabase.instance.client.auth;
  if (auth.currentSession != null) {
    oauthStripQueryParamsIfOAuthPresent();
    return;
  }

  try {
    await auth.getSessionFromUrl(location);
  } catch (e, st) {
    debugPrint('[Auth] Web OAuth getSessionFromUrl failed: $e');
    debugPrint('$st');
  }
  oauthStripQueryParamsIfOAuthPresent();
}
