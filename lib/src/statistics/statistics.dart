import 'dart:math';

import 'package:firecrest/src/statistics/statistics_collector.dart';
import 'package:firecrest/src/util/controller_map.dart';

class Statistics {
  RouteMap<RouteStatistics> _stats = RouteMap();
  RouteStatistics _noRouteStats = RouteStatistics();

  void update(StatisticsCollector collector) {
    var route = collector.route;
    var statsToUpdate = route != null
        ? _stats.computeIfAbsent(route, () => RouteStatistics())
        : _noRouteStats;

    statsToUpdate.requestCount++;
    collector.timePerHandler.forEach(statsToUpdate.updateLatency);
  }

  Map<String, RouteStatistics> get statsPerRoute =>
      _stats.map((route, value) => MapEntry(route.path, value));

  RouteStatistics get errorStats => _noRouteStats;
}

class RouteStatistics {
  static const LARGE_INT = 1000000000;

  final int startTime = DateTime.now().millisecondsSinceEpoch;
  int requestCount = 0;

  int get msSinceStart => DateTime.now().millisecondsSinceEpoch - startTime;

  /* TODO jhj: Use lists instead to keep the order of the middlewares and controller?
      Also applies to StatisticsCollector. */
  Map<Object, int> minLatencyPerHandler = {};
  Map<Object, int> maxLatencyPerHandler = {};
  Map<Object, num> avgLatencyPerHandler = {};

  void updateLatency(Object handler, int newValue) {
    var minLatency = minLatencyPerHandler[handler] ?? LARGE_INT;
    var maxLatency = maxLatencyPerHandler[handler] ?? 0;
    var avgLatency = avgLatencyPerHandler[handler] ?? 0;

    minLatencyPerHandler[handler] = min(minLatency, newValue);
    maxLatencyPerHandler[handler] = max(maxLatency, newValue);
    avgLatencyPerHandler[handler] =
        avgLatency + (newValue - avgLatency) / (requestCount + 1);
  }
}
