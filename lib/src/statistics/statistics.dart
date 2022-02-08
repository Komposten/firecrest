import 'dart:math';

import 'package:firecrest/src/statistics/statistics_collector.dart';
import 'package:firecrest/src/util/controller_map.dart';

// TODO jhj: Documentation
class Statistics {
  static const TOTAL_KEY = '[TOTAL]';

  RouteMap<RouteStatistics> _stats = RouteMap();
  RouteStatistics _noRouteStats = RouteStatistics();

  void update(StatisticsCollector collector) {
    var route = collector.route;
    var statsToUpdate = route != null
        ? _stats.computeIfAbsent(route, () => RouteStatistics())
        : _noRouteStats;

    statsToUpdate.updateLatencies(
        collector.timePerHandler, collector.totalTime);
  }

  Map<String, RouteStatistics> get statsPerRoute =>
      _stats.map((route, value) => MapEntry(route.path, value));

  RouteStatistics get errorStats => _noRouteStats;
}

class RouteStatistics {
  final int startTime = DateTime.now().millisecondsSinceEpoch;
  int _requestCount = 0;

  /* TODO jhj: Use linked hash maps instead to keep the order of the middlewares
      and controller?
      Also applies to StatisticsCollector.
  */
  Map<Object, int> _minLatencyPerHandler = {};
  Map<Object, int> _maxLatencyPerHandler = {};
  Map<Object, num> _avgLatencyPerHandler = {};

  int get msSinceStart => DateTime.now().millisecondsSinceEpoch - startTime;

  int get requestCount => _requestCount;

  Map<Object, int> get minLatencyPerHandler =>
      Map.unmodifiable(_minLatencyPerHandler);

  Map<Object, int> get maxLatencyPerHandler =>
      Map.unmodifiable(_maxLatencyPerHandler);

  Map<Object, num> get avgLatencyPerHandler =>
      Map.unmodifiable(_avgLatencyPerHandler);

  void updateLatencies(Map<Object, int> handlerToLatency, int total) {
    _requestCount++;
    _updateLatency(Statistics.TOTAL_KEY, total);
    handlerToLatency.forEach(_updateLatency);
  }

  void _updateLatency(Object handler, int newValue) {
    var minLatency = _minLatencyPerHandler[handler] ?? newValue;
    var maxLatency = _maxLatencyPerHandler[handler] ?? newValue;
    var avgLatency = _avgLatencyPerHandler[handler] ?? 0;

    _minLatencyPerHandler[handler] = min(minLatency, newValue);
    _maxLatencyPerHandler[handler] = max(maxLatency, newValue);
    _avgLatencyPerHandler[handler] =
        avgLatency + (newValue - avgLatency) / (requestCount);
  }
}
