import 'package:firecrest/src/route.dart';

class RouteMap<T> {
  final Map<Route, T> _map = <Route, T>{};

  Iterable<Route> get keys => _map.keys;

  Iterable<T> get values => _map.values;

  T? operator [](Route key) {
    var value = _map[key];

    if (value == null) {
      value = _map[_overlappingKey(key)];
    }

    return value;
  }

  void operator []=(Route key, T value) {
    if (containsKey(key)) {
      throw StateError(
          'A key already exists which overlaps with the route "${key.path}"');
    }

    _map[key] = value;
  }

  bool containsKey(Route key) {
    if (_map.containsKey(key)) {
      return true;
    }

    return _overlappingKey(key) != null;
  }

  Route? _overlappingKey(Route key) {
    // TODO jhj: Optimise
    var overlaps = _map.keys.where((route) => route.overlapsWith(key));
    return overlaps.isNotEmpty ? overlaps.first : null;
  }
}
