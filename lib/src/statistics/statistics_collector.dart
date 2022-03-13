import 'dart:collection';

import 'package:firecrest/src/route/route.dart';

/// Interface for an object that collects statistics for requests.
abstract class StatisticsCollector {
  /// Set the [Route] to collect statistics for.
  void forRoute(Route? route);

  /// Begin collection for the specified handler.
  void begin(Object handler);

  /// End collection for the specified handler.
  void end(Object handler);

  /// Close the collector.
  ///
  /// No more modifications are permitted after closing the collector.
  void close();

  /// The route set by [forRoute].
  Route? get route;

  /// The total time passed between creating the collector and closing it.
  int get totalTime;

  /// The time spent between [begin] and [end] per handler.
  Map<Object, int> get timePerHandler;
}

typedef TimeNow = DateTime Function();

/// A basic collector which collects request counts and min/max/avg latencies.
class BasicCollector implements StatisticsCollector {
  static final _DEFAULT_TIMER = () => DateTime.now();

  late final int _startTime;
  final TimeNow _getTime;
  final Map<Object, int> _startTimeByHandler = LinkedHashMap();
  final Map<Object, int> _timePerHandler = LinkedHashMap();

  List<Object> _openHandlers = [];

  bool _isClosed = false;
  Route? _route;
  int? _totalTime;

  BasicCollector() : this.withTimeSource(_DEFAULT_TIMER);

  BasicCollector.withTimeSource(DateTime Function() getTime)
      : _getTime = getTime {
    _startTime = _now();
  }

  Route? get route {
    _requireClosed();
    return _route;
  }

  int get totalTime {
    _requireClosed();
    return _totalTime!;
  }

  Map<Object, int> get timePerHandler {
    _requireClosed();
    return _timePerHandler;
  }

  void forRoute(Route? route) {
    _requireOpen();
    _route = route;
  }

  void begin(Object handler) {
    _requireOpen();
    _startTimeByHandler[handler] = _now();
    _openHandlers.add(handler);
  }

  void end(Object handler) {
    _requireOpen();

    var startTime = _startTimeByHandler[handler];
    if (startTime == null) {
      throw ArgumentError('unknown handler: ' + _handlerToString(handler));
    }

    _timePerHandler[handler] = _timePassed(startTime);
    _openHandlers.remove(handler);
  }

  void endAll() {
    for (var handler in _openHandlers.toList()) {
      end(handler);
    }
  }

  void close() {
    if (_openHandlers.isNotEmpty) {
      throw StateError(
          'the following handlers have not been closed with end(): ' +
              _openHandlers.map(_handlerToString).join(", "));
    }
    if (!_isClosed) {
      _totalTime = _timePassed();
      _isClosed = true;
    }
  }

  int _timePassed([int? since]) => _now() - (since ?? _startTime);

  int _now() => _getTime().millisecondsSinceEpoch;

  void _requireClosed() {
    if (!_isClosed) {
      throw StateError('must call close() first');
    }
  }

  void _requireOpen() {
    if (_isClosed) {
      throw StateError('the collector has been closed');
    }
  }

  String _handlerToString(Object handler) {
    String handlerString = handler.toString();
    Type handlerType = handler.runtimeType;

    return '$handlerString ($handlerType)';
  }
}
