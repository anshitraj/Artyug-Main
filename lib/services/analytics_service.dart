import 'package:flutter/foundation.dart';

class AnalyticsService {
  static void track(String event, {Map<String, dynamic>? params}) {
    debugPrint('[Analytics] $event ${params ?? const {}}');
  }
}
