import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalPointsStore {
  static const String _pointsKey = 'gamification_points_v1';

  // Conversion: Every 1000 points = $0.50
  static const int pointsPerUnit = 1000;
  static const double cashPerUnit = 0.5; // in USD

  // Live notifier for current points
  static final ValueNotifier<int> pointsNotifier = ValueNotifier<int>(0);

  // Call on app start
  static Future<void> bootstrap() async {
    final p = await getPoints();
    pointsNotifier.value = p;
  }

  static Future<int> getPoints() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_pointsKey) ?? 0;
    }

  static Future<void> setPoints(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_pointsKey, value.clamp(0, 1000000000));
    if (pointsNotifier.value != value) {
      pointsNotifier.value = value;
    }
  }

  static Future<int> addPoints(int delta, {String reason = ''}) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_pointsKey) ?? 0;
    final updated = (current + delta).clamp(0, 1000000000);
    await prefs.setInt(_pointsKey, updated);
    if (pointsNotifier.value != updated) {
      pointsNotifier.value = updated;
    }
    debugPrint('Points updated: old=$current, delta=$delta, new=$updated, reason=$reason');
    return updated;
  }

  // Utility: convert points to cash value
  static double pointsToCash(int points) {
    return (points / pointsPerUnit) * cashPerUnit;
  }

  static String formatCash(double value) {
    // Keep two decimals and a $ prefix
    return '\$${value.toStringAsFixed(2)}';
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pointsKey);
    pointsNotifier.value = 0;
  }
}
