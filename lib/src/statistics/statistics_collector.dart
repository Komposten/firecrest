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

class MockCollector implements StatisticsCollector {
  @override
  void begin(Object handler) {}

  @override
  void close() {}

  @override
  void end(Object handler) {}

  @override
  void forRoute(Route? route) {}

  @override
  Route? get route => null;

  @override
  Map<Object, int> get timePerHandler => {};

  @override
  int get totalTime => 0;
}

class DefaultCollector implements StatisticsCollector {
  final int _startTime;
  final Map<Object, int> _startTimeByHandler = {};
  final Map<Object, int> _timePerHandler = {};

  bool _isClosed = false;
  Route? _route;
  int? _totalTime;

  DefaultCollector() : _startTime = DateTime.now().millisecondsSinceEpoch;

  Route? get route {
    if (!_isClosed) {
      throw StateError('must call close() first');
    }
    return _route;
  }

  int get totalTime {
    if (!_isClosed) {
      throw StateError('must call close() first');
    }
    return _totalTime!;
  }

  Map<Object, int> get timePerHandler => _timePerHandler;

  void forRoute(Route? route) => _route = route;

  void begin(Object handler) => _startTimeByHandler[handler] = _now();

  void end(Object handler) =>
      _timePerHandler[handler] = _timePassed(_startTimeByHandler[handler]);

  void close() {
    _totalTime = _timePassed();
    _isClosed = true;
  }

  int _timePassed([int? since]) => _now() - (since ?? _startTime);

  int _now() => DateTime.now().millisecondsSinceEpoch;
}
