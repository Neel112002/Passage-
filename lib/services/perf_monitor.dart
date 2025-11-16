import 'dart:math' as math;
import 'package:flutter/scheduler.dart';

/// Lightweight frame timing monitor that logs build/raster stats per route.
///
/// Usage: call PerformanceMonitor.init() once at app start.
/// It will print lines prefixed with "PERF" to the console, e.g.:
/// PERF route=/home frames=60 avg_build=3.1ms p95_build=7.8ms avg_raster=4.5ms p95_raster=10.2ms jank(>16ms)=2
class PerformanceMonitor {
  PerformanceMonitor._();

  static final PerformanceMonitor _instance = PerformanceMonitor._();
  static PerformanceMonitor get instance => _instance;

  static bool _initialized = false;
  final List<FrameTiming> _window = <FrameTiming>[];
  String _route = 'unknown';
  int _lastLogEpochMs = 0;

  /// Updates the current route label used in logs.
  void setRoute(String routeName) {
    _route = routeName.isEmpty ? 'unknown' : routeName;
  }

  static void init() {
    if (_initialized) return;
    _initialized = true;
    SchedulerBinding.instance.addTimingsCallback(_instance._onTimings);
  }

  void _onTimings(List<FrameTiming> timings) {
    _window.addAll(timings);
    // Log every ~1s or when buffer >= 60 frames
    final now = DateTime.now().millisecondsSinceEpoch;
    if (_window.length >= 60 || now - _lastLogEpochMs > 1200) {
      _emitStats();
      _lastLogEpochMs = now;
    }
  }

  void _emitStats() {
    if (_window.isEmpty) return;
    final builds = _window.map((t) => t.buildDuration.inMicroseconds / 1000.0).toList();
    final rasters = _window.map((t) => t.rasterDuration.inMicroseconds / 1000.0).toList();

    double avg(List<double> a) => a.isEmpty ? 0 : a.reduce((p, n) => p + n) / a.length;
    double p(List<double> a, double q) {
      if (a.isEmpty) return 0;
      final sorted = [...a]..sort();
      final idx = (q * (sorted.length - 1)).clamp(0, sorted.length - 1).toDouble();
      final lo = idx.floor();
      final hi = idx.ceil();
      if (hi == lo) return sorted[lo];
      final t = idx - lo;
      return sorted[lo] * (1 - t) + sorted[hi] * t;
    }

    final dropped = _window.where((t) => math.max(
      t.buildDuration.inMicroseconds, t.rasterDuration.inMicroseconds,
    ) > 16000).length;

    // ignore: avoid_print
    print(
      'PERF route=${_route} frames=${_window.length} '
      'avg_build=${avg(builds).toStringAsFixed(1)}ms p95_build=${p(builds, 0.95).toStringAsFixed(1)}ms '
      'avg_raster=${avg(rasters).toStringAsFixed(1)}ms p95_raster=${p(rasters, 0.95).toStringAsFixed(1)}ms '
      'jank(>16ms)=$dropped',
    );

    _window.clear();
  }
}
