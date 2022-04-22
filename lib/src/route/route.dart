import 'dart:math';

import 'package:collection/collection.dart';
import 'package:firecrest/src/route/segment.dart';
import 'package:firecrest/src/util/pair.dart';

class Route implements Comparable<Route> {
  final List<Segment> _segments;
  late final int _indexAfterSuperWild;
  late final int _elementsAfterSuperWild;

  Route(String path) : this._(_splitPath(path));

  Route._(List<Segment> segments) : _segments = List.unmodifiable(segments) {
    _indexAfterSuperWild =
        _segments.indexWhere((element) => element.isSuperWild) + 1;
    _elementsAfterSuperWild = _segments.length - _indexAfterSuperWild;
  }

  bool get _hasSuperWild => _indexAfterSuperWild != 0;

  static List<Segment> _splitPath(String path) {
    var split = path.split('/').where((e) => e.isNotEmpty);
    var segments = <Segment>[];

    bool hasSuperWild = false;

    for (var part in split) {
      if (part.startsWith('::')) {
        if (hasSuperWild) {
          throw ArgumentError(
              'A route may only have a single super wild (::) section.');
        }

        segments.add(Segment(part.substring(2), SegmentType.superWild));
        hasSuperWild = true;
      } else if (part.startsWith(':')) {
        segments.add(Segment(part.substring(1), SegmentType.basicWild));
      } else {
        segments.add(Segment(part, SegmentType.normal));
      }
    }

    return segments;
  }

  /// Checks if the path consisting of the provided path segments matches this
  /// route.
  bool matches(List<String> pathSegments) {
    return _match(pathSegments) != null;
  }

  /// Finds the index of the first path segments that matches against a
  /// [SegmentType.normal] segment.
  ///
  /// An [ArgumentError] is thrown if the segments in `pathSegments` does not
  /// match this route. Always check the segments with [matches] first.
  ///
  /// If the path has no normal segments, `null` is returned. Otherwise the
  /// index of the first item in [pathSegments] that matches a normal segment is
  /// returned.
  ///
  /// If [after] is specified, the first normal match after start will be
  /// returned.
  int? firstNormalMatch(List<String> pathSegments, [after = -1]) {
    var match = _match(pathSegments);
    if (match == null) {
      throw ArgumentError("The provided path segments don't match this route!");
    }

    var index = 0;

    for (var pair in match) {
      var isNormal = !pair.a.isAnyWild;

      if (isNormal && index > after) {
        return index;
      }

      var matches = pair.b;
      index += (matches is List ? matches.length : 1);
    }

    return null;
  }

  /// Extracts the values of this route's path parameters from the provided path
  /// segments.
  ///
  /// An [ArgumentError] is thrown if the segments in `pathSegments` does not
  /// match this route. Always check the segments with [matches] first.
  ///
  /// The returned map has the path parameters as keys with the parameter
  /// values as values. The value for a basic wild parameter will always
  /// be a string while the value for a super wild parameter will be a list of
  /// strings (one element per path segment it matched).
  Map<String, Object> getParameters(List<String> pathSegments) {
    var match = _match(pathSegments);
    if (match == null) {
      throw ArgumentError("The provided path segments don't match this route!");
    }

    var map = <String, Object>{};
    match
        .where((element) => element.a.isAnyWild)
        .forEach((element) => map[element.a.name] = element.b);
    return map;
  }

  List<Pair<Segment, Object>>? _match(List<String> pathSegments) {
    if (!_hasSuperWild && pathSegments.length != _segments.length) {
      return null;
    }

    var result = <Pair<Segment, Object>>[];

    var pathIndex = 0;
    var routeIndex = 0;

    while (pathIndex < pathSegments.length) {
      var pathSegment = pathSegments[pathIndex];
      var routeSegment = _segments[routeIndex];

      if (routeSegment.isSuperWild) {
        var end = pathSegments.length - _elementsAfterSuperWild;
        if (end <= pathIndex) {
          // There aren't enough segments to find the super wild and the following ones.
          return null;
        }

        result.add(Pair(routeSegment, pathSegments.sublist(pathIndex, end)));

        routeIndex = _indexAfterSuperWild;
        pathIndex = end;
      } else {
        if (!routeSegment.isBasicWild && pathSegment != routeSegment.name) {
          return null;
        } else if (routeSegment.isBasicWild && pathSegment.isEmpty) {
          return null;
        }

        result.add(Pair(routeSegment, pathSegment));

        pathIndex++;
        routeIndex++;
      }
    }

    return result;
  }

  List<Segment> get segments => List.unmodifiable(_segments);

  String get path => _segments.join('/');

  Map<String, SegmentType> get parameters => Map.fromEntries(
      _segments.where((s) => s.isAnyWild).map((s) => MapEntry(s.name, s.type)));

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
    var thisIsShorter = (_segments.length < other._segments.length);

    var shorter = thisIsShorter ? this : other;
    var longer = thisIsShorter ? other : this;

    if (shorter._segments.length < longer._segments.length) {
      if (!shorter._hasSuperWild) {
        return false;
      }

      shorter = shorter._expandToLength(longer._segments.length);
    }

    // Equal length, compare segment by segment.
    for (var i = 0; i < shorter._segments.length; i++) {
      if (!shorter._segments[i].overlapsWith(longer._segments[i])) {
        return false;
      }
    }

    return true;
  }

  /// Creates a new route with the provided length by expanding this route's
  /// super wild segment.
  ///
  /// If this route has a super wild, that super wild will be "extended" until
  /// the requested length is reached. The new segments that are added will be
  /// [SegmentType.basicWild] segments with the same name as the super wild but
  /// with a numerical suffix.
  Route _expandToLength(int length) {
    if (!_hasSuperWild) {
      throw ArgumentError('Route does not contain a super wild: /' + path);
    }

    var newSegments = <Segment>[];
    var lengthDiff = length - _segments.length;
    var usedNames = _segments.map((e) => e.name).toSet();
    var nameIndex = 0;

    for (var segment in _segments) {
      newSegments.add(segment);
      if (segment.isSuperWild) {
        for (var i = 0; i < lengthDiff; i++) {
          String name;

          do {
            name = '${segment.name}-${++nameIndex}';
          } while (usedNames.contains(name));

          newSegments.add(Segment(name, SegmentType.basicWild));
          usedNames.add(name);
        }
      }
    }

    return Route._(newSegments);
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
