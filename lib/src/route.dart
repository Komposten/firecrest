import 'dart:math';

import 'package:collection/collection.dart';
import 'package:firecrest/src/util/pair.dart';

// TODO jhj: Allow simple patterns in wild paths? E.g. :id[L+] or :id[D+]
/* TODO jhj: Add super-wilds (e.g. ::path) which match all sub-paths.
    Example 1:
      Route: documents/::path
      Matches:
       - documents/doc1
       - documents/folder/doc1
       - documents/folder/subfolder/doc1
    .
    Example 2:
      Route: documents/::path/stats
      Matches:
       - documents/doc1/stats
       - documents/folder/doc1/stats
       - documents/folder/subfolder/doc1/stats
      But not:
       - documents/doc1
       - documents/folder/doc1
       - documents/folder/subfolder/doc1
 */
class Route implements Comparable<Route> {
  final List<_Segment> _segments;
  late final int _indexAfterSuperWild;
  late final int _elementsAfterSuperWild;

  Route(String path) : _segments = _splitPath(path) {
    _indexAfterSuperWild =
        _segments.indexWhere((element) => element.isSuperWild) + 1;
    _elementsAfterSuperWild = _segments.length - _indexAfterSuperWild;
  }

  Route._(this._segments);

  bool get _hasSuperWild => _indexAfterSuperWild != 0;

  static List<_Segment> _splitPath(String path) {
    var split = path.split('/').where((e) => e.isNotEmpty);
    var segments = <_Segment>[];

    bool hasSuperWild = false;

    for (var part in split) {
      if (part.startsWith('::')) {
        if (hasSuperWild) {
          throw ArgumentError(
              'A route may only have a single super wild (::) section.');
        }

        segments.add(_Segment(part.substring(2), _SegmentType.superWild));
        hasSuperWild = true;
      } else if (part.startsWith(':')) {
        segments.add(_Segment(part.substring(1), _SegmentType.basicWild));
      } else {
        segments.add(_Segment(part, _SegmentType.normal));
      }
    }

    return segments;
  }

  /// Checks if the path consisting of the provided path segments matches this
  /// route.
  bool matches(List<String> pathSegments) {
    return _match(pathSegments) != null;
  }

  /// Extracts the values of this route's path parameters from the provided path
  /// segments.
  ///
  /// An [ArgumentError] is thrown if the segments in `pathSegments` does not
  /// this route. Always check the segments with [matches] first.
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

  List<Pair<_Segment, Object>>? _match(List<String> pathSegments) {
    if (!_hasSuperWild && pathSegments.length != _segments.length) {
      return null;
    }

    var result = <Pair<_Segment, Object>>[];

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
    if (!_hasSuperWild && _segments.length != other._segments.length) {
      return false;
    }

    /* TODO jhj: Handle super wilds.
        - Handle cases where both routes have super wilds!
        - Can this also use _match?

        There should be an overlap if:
        - Same length (or one has a wild)
        - No differing normal segments (normal segment has higher priority than
           wild segment, wild and super wild have same priority).
     */
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
  final _SegmentType type;

  _Segment(this.name, this.type);

  @override
  String toString() {
    var prefix = '';

    if (type == _SegmentType.superWild) {
      prefix = '::';
    } else if (type == _SegmentType.basicWild) {
      prefix = ':';
    }

    return '$prefix$name';
  }

  bool overlapsWith(_Segment other) =>
      identical(this, other) ||
      runtimeType == other.runtimeType &&
          (name == other.name || (isAnyWild || other.isAnyWild));

  bool get isAnyWild => isBasicWild || isSuperWild;

  bool get isBasicWild => type == _SegmentType.basicWild;

  bool get isSuperWild => type == _SegmentType.superWild;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _Segment &&
          runtimeType == other.runtimeType &&
          (name == other.name || (isAnyWild && other.isAnyWild));

  @override
  int get hashCode {
    if (isAnyWild) {
      return '*'.hashCode;
    } else {
      return name.hashCode;
    }
  }

  @override
  int compareTo(_Segment other) {
    if (isAnyWild || other.isAnyWild) {
      return 0;
    } else {
      return name.compareTo(other.name);
    }
  }
}

enum _SegmentType { normal, basicWild, superWild }
