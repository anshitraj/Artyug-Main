import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NfcLinkService {
  static final _db = Supabase.instance.client;

  static String _fallbackKey(String artworkId) => 'nfc_link_$artworkId';

  static Future<String?> getArtworkNfcLink(String artworkId) async {
    try {
      final row = await _db
          .from('artwork_nfc_links')
          .select('link_url')
          .eq('artwork_id', artworkId)
          .maybeSingle();
      final url = row?['link_url']?.toString().trim();
      if (url != null && url.isNotEmpty) return url;
    } catch (_) {}

    try {
      final row = await _db
          .from('paintings')
          .select('nfc_link')
          .eq('id', artworkId)
          .maybeSingle();
      final url = row?['nfc_link']?.toString().trim();
      if (url != null && url.isNotEmpty) return url;
    } catch (_) {}

    try {
      final prefs = await SharedPreferences.getInstance();
      final url = prefs.getString(_fallbackKey(artworkId))?.trim();
      if (url != null && url.isNotEmpty) return url;
    } catch (_) {}
    return null;
  }

  static Future<void> setArtworkNfcLink({
    required String artworkId,
    required String linkUrl,
  }) async {
    final userId = _db.auth.currentUser?.id;

    try {
      await _db.from('artwork_nfc_links').upsert({
        'artwork_id': artworkId,
        'link_url': linkUrl,
        if (userId != null) 'updated_by': userId,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (_) {
      try {
        await _db.from('paintings').update({
          'nfc_link': linkUrl,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', artworkId);
      } catch (_) {}
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_fallbackKey(artworkId), linkUrl);
    } catch (_) {}
  }
}

