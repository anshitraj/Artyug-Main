import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FeedViewModeProvider extends ChangeNotifier {
  static const _prefKey = 'artyug_feed_pro_mode';
  bool _proMode = true;

  FeedViewModeProvider() {
    _load();
  }

  bool get isProMode => _proMode;
  bool get isLiteMode => !_proMode;

  void setProMode(bool value) {
    if (_proMode == value) return;
    _proMode = value;
    _persist();
    notifyListeners();
  }

  void toggle() => setProMode(!_proMode);

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _proMode = prefs.getBool(_prefKey) ?? true;
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, _proMode);
  }
}
