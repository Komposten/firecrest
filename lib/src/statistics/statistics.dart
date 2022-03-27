import 'dart:collection';
import 'dart:math';

import 'package:firecrest/src/statistics/statistics_collector.dart';
import 'package:firecrest/src/util/route_map.dart';

/// Collection and aggregation of statistics on a per-route basis.
///
/// Use [StatisticsCollector]s to collect statistics for individual routes and
/// pass them to [update] to aggregate them together. Aggregated statistics can
/// be fetched using [statsPerRoute] and [errorStats].
class Statistics {
  static const TOTAL_KEY = '[TOTAL]';

  late RouteMap<RouteStatistics> _stats;
  late RouteStatistics _noRouteStats;

  Statistics() {
    reset();
  }

  /// Clears all statistics.
  void reset() {
    _stats = RouteMap();
    _noRouteStats = RouteStatistics();
  }

  /// Updates the statistics with data from a [StatisticsCollector].
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

  /// Statistics from collectors with no route specified.
  RouteStatistics get errorStats => _noRouteStats;
}

/// Statistics for a specific route.
class RouteStatistics {
  /// The unix time since statistics were first collected.
  final int startTime = DateTime.now().millisecondsSinceEpoch;
  int _requestCount = 0;

  Map<Object, int> _minLatencyPerHandler = LinkedHashMap();
  Map<Object, int> _maxLatencyPerHandler = LinkedHashMap();
  Map<Object, num> _avgLatencyPerHandler = LinkedHashMap();

  /// The time that has passed since [startTime].
  int get msSinceStart => DateTime.now().millisecondsSinceEpoch - startTime;

  /// The number of requests made to this route.
  int get requestCount => _requestCount;

  /// The minimum latency per handler.
  ///
  /// Use [TOTAL_KEY] as key to get the minimum latency for the entire route.
  Map<Object, int> get minLatencyPerHandler =>
      Map.unmodifiable(_minLatencyPerHandler);

  /// The maximum latency per handler.
  ///
  /// Use [TOTAL_KEY] as key to get the maximum latency for the entire route.
  Map<Object, int> get maxLatencyPerHandler =>
      Map.unmodifiable(_maxLatencyPerHandler);

  /// The average latency per handler.
  ///
  /// Use [TOTAL_KEY] as key to get the average latency for the entire route.
  Map<Object, num> get avgLatencyPerHandler =>
      Map.unmodifiable(_avgLatencyPerHandler);

  /// Updates the latency and request count statistics.
  ///
  /// [total] specifies the total latency for the route (sum of all handlers and
  /// additional time spent between them).
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
