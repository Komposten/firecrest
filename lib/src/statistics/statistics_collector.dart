import 'dart:collection';

import 'package:firecrest/src/route.dart';

abstract class StatisticsCollector {
  void forRoute(Route? route);

  void begin(Object handler);

  void end(Object handler);

  void close();

  Route? get route;

  int get totalTime;

  Map<Object, int> get timePerHandler;
}

typedef TimeNow = DateTime Function();

class BasicCollector implements StatisticsCollector {
  static final _DEFAULT_TIMER = () => DateTime.now();

  late final int _startTime;
  final TimeNow _getTime;
  final Map<Object, int> _startTimeByHandler = LinkedHashMap();
  final Map<Object, int> _timePerHandler = LinkedHashMap();

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
  }

  void end(Object handler) {
    _requireOpen();

    var startTime = _startTimeByHandler[handler];
    if (startTime == null) {
      throw ArgumentError('unknown handler: $handler (${handler.runtimeType})');
    }

    _timePerHandler[handler] = _timePassed(startTime);
  }

  void close() {
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
}
