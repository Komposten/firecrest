import 'dart:math';

import 'package:collection/collection.dart';

// TODO jhj: Allow regex in wild paths. E.g. :id[\w+] or :id[[A-Za-z]+]
class Route implements Comparable<Route> {
  final List<_Segment> _segments;

  Route(String path) : _segments = _splitPath(path);

  Route._(this._segments);

  static List<_Segment> _splitPath(String path) {
    var split = path.split('/').where((e) => e.isNotEmpty);
    var segments = <_Segment>[];

    for (var part in split) {
      if (part.startsWith(':')) {
        segments.add(_Segment(part.substring(1), true));
      } else {
        segments.add(_Segment(part, false));
      }
    }

    return segments;
  }

  bool matches(List<String> pathSegments) {
    if (pathSegments.length != _segments.length) {
      return false;
    }

    for (var i = 0; i < _segments.length; i++) {
      var segment = _segments[i];

      if ((!segment.isWild && pathSegments[i] != segment.name) ||
          (segment.isWild && pathSegments[i].isEmpty)) {
        return false;
      }
    }

    return true;
  }

  Map<String, String> getParameters(List<String> pathSegments) {
    if (pathSegments.length != _segments.length) {
      throw ArgumentError(
          'pathSegments must contain exactly ${_segments.length} elements: ${pathSegments.length} != ${_segments.length}');
    }

    var parameters = <String, String>{};
    for (var i = 0; i < _segments.length; i++) {
      var segment = _segments[i];

      if (segment.isWild) {
        parameters[segment.name] = pathSegments[i];
      }
    }

    return parameters;
  }

  String get path => _segments.join('/');

  Route? get parent {
    if (_segments.length > 0) {
      return Route._(_segments.sublist(0, _segments.length - 1));
    } else {
      return null;
    }
  }

  bool overlapsWith(Route other) =>
      identical(this, other) || _hasSegmentOverlap(other);

  bool _hasSegmentOverlap(Route other) {
    if (_segments.length != other._segments.length) {
      return false;
    }

    for (var i = 0; i < _segments.length; i++) {
      if (!_segments[i].overlapsWith(other._segments[i])) {
        return false;
      }
    }

    return true;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Route &&
          runtimeType == other.runtimeType &&
          IterableEquality().equals(_segments, other._segments);

  @override
  int get hashCode => IterableEquality().hash(_segments);

  @override
  int compareTo(Route other) {
    var maxLength = max(_segments.length, other._segments.length);

    for (var i = 0; i < maxLength; i++) {
      if (i >= _segments.length) {
        return -1;
      } else if (i >= other._segments.length) {
        return 1;
      }

      var cmp = _segments[i].compareTo(other._segments[i]);

      if (cmp != 0) {
        return cmp;
      }
    }

    return 0;
  }

  @override
  String toString() {
    return '$Route{${_segments.join('/')}}';
  }
}

class _Segment implements Comparable<_Segment> {
  final String name;
  final bool isWild;

  _Segment(this.name, this.isWild);

  @override
  String toString() {
    return isWild ? ':$name' : name;
  }

  bool overlapsWith(_Segment other) =>
      identical(this, other) ||
      runtimeType == other.runtimeType &&
          (name == other.name || (isWild || other.isWild));

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _Segment &&
          runtimeType == other.runtimeType &&
          (name == other.name || (isWild && other.isWild));

  @override
  int get hashCode {
    if (isWild) {
      return '*'.hashCode;
    } else {
      return name.hashCode;
    }
  }

  @override
  int compareTo(_Segment other) {
    if (isWild || other.isWild) {
      return 0;
    } else {
      return name.compareTo(other.name);
    }
  }
}
