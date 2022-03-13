import 'package:firecrest/src/route/route.dart';

class RouteMap<T> {
  final Map<Route, T> _map = <Route, T>{};

  Iterable<Route> get keys => _map.keys;

  Iterable<T> get values => _map.values;

  Iterable<MapEntry<Route, T>> get entries => _map.entries;

  Map<K, V> map<K, V>(MapEntry<K, V> Function(Route route, T value) mapper) =>
      _map.map(mapper);

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
          'A key already exists which overlaps with the route /${key.path}');
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

  T computeIfAbsent(Route key, T Function() supplier) {
    T? value = this[key];

    if (value == null) {
      value = supplier();
      this[key] = value!;
    }

    return value;
  }
}
