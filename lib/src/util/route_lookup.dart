import 'package:firecrest/src/route/route.dart';
import 'package:firecrest/src/route/segment.dart';
import 'package:firecrest/src/util/route_comparators.dart';
import 'package:meta/meta.dart';

class RouteLookup {
  final _Node _root;

  @visibleForTesting
  _Node get root => _root;

  factory RouteLookup(Iterable<Route> routes) {
    var root = _createRouteTree(routes);
    return RouteLookup._(root);
  }

  RouteLookup._(this._root);

  static _Node _createRouteTree(Iterable<Route> routes) {
    var root = _Node(Segment('[root]', SegmentType.normal));

    for (var route in routes) {
      var node = root;
      for (var segment in route.segments) {
        node = node.addChild(segment);
      }

      if (node.route != null) {
        throw StateError(
            'Duplicate routes: ${route.path} and ${node.route!.path}');
      }

      node.route = route;
    }

    return root;
  }

  /// Tries to find a route matching the provided path.
  ///
  /// If there is a single match, that match is returned.
  ///
  /// If there are multiple matches, the one with highest priority is returned.
  /// A route has higher priority if it has a normal (i.e. non-wild) segment
  /// earlier in the path.
  Route? findRoute(List<String> pathSegments) {
    if (pathSegments.isEmpty) {
      return _root.route;
    }

    pathSegments = pathSegments.where((s) => s.isNotEmpty).toList();

    var matches = _findRoutes2(_root, -1, pathSegments).toList();
    matches.sort((a, b) => compareRouteMatches(a, b, pathSegments));

    return matches.isNotEmpty ? matches.first : null;
  }

  /// Recursively tries to find matches to the provided [pathSegments].
  ///
  /// [pathIndex] is the index of the [pathSegments] which the [node] matched to.
  Iterable<Route> _findRoutes2(
      _Node node, int pathIndex, List<String> pathSegments) {
    var matches = <Route>[];

    if (pathIndex == pathSegments.length - 1) {
      if (node.route != null) {
        matches.add(node.route!);
      }
      return matches;
    }

    if (node.segment.isSuperWild) {
      // Add node itself if it has a route since the super-wild can expand to
      // cover the remaining segments.
      if (node.route != null) {
        matches.add(node.route!);
      }

      // Expand the super-wild to cover the next segment, the next 2, etc.
      for (var i = pathIndex + 1; i < pathSegments.length; i++) {
        var children = node.childrenMatching(pathSegments[i]);
        for (var child in children) {
          matches.addAll(_findRoutes2(child, i, pathSegments));
        }
      }
    } else {
      var children = node.childrenMatching(pathSegments[pathIndex + 1]);
      for (var child in children) {
        matches.addAll(_findRoutes2(child, pathIndex + 1, pathSegments));
      }
    }

    return matches;
  }
}

class _Node {
  final Segment segment;
  final Map<String, _Node> normalChildren;
  _Node? wildChild;
  Route? route;

  _Node(this.segment, [this.route]) : normalChildren = {};

  _Node addChild(Segment segment) {
    if (segment.isAnyWild) {
      if (wildChild == null) {
        wildChild = _Node(segment);
      }
      return wildChild!;
    }

    return normalChildren.putIfAbsent(segment.name, () => _Node(segment));
  }

  Iterable<_Node> childrenMatching(String segment) {
    var list = <_Node>[];
    if (wildChild != null) {
      list.add(wildChild!);
    }

    var child = normalChildren[segment];

    if (child != null) {
      list.add(child);
    }

    return list;
  }
}
