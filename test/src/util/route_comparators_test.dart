import 'package:firecrest/src/route/route.dart';
import 'package:firecrest/src/util/route_comparators.dart';
import 'package:test/test.dart';

void main() {
  group('compareRouteMatches', () {
    test('differentFirstIndex_earlierIndexFirst', () {
      var route1 = Route('some/short/path');
      var route2 = Route(':some/short/path');
      var segments = ['some', 'short', 'path'];

      expect(compareRouteMatches(route1, route2, segments), isNegative);
      expect(compareRouteMatches(route2, route1, segments), isPositive);
    });

    test('differentSecondIndex_earlierIndexFirst', () {
      var route1 = Route('some/short/path');
      var route2 = Route('some/:short/path');
      var segments = ['some', 'short', 'path'];

      expect(compareRouteMatches(route1, route2, segments), isNegative);
      expect(compareRouteMatches(route2, route1, segments), isPositive);
    });

    test('normalSegmentsInSamePositions_compareRoutes', () {
      var route1 = Route(':some/:short/:path');
      var route2 = Route(':some/:short/:route');
      var segments = ['some', 'short', 'path'];

      expect(compareRouteMatches(route1, route2, segments), isZero);
      expect(compareRouteMatches(route2, route1, segments), isZero);

      route1 = Route('some/short/:path');
      route2 = Route('some/short/:route');

      expect(compareRouteMatches(route1, route2, segments), isZero);
      expect(compareRouteMatches(route2, route1, segments), isZero);
    });
  });
}
