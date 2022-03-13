import 'package:firecrest/src/route/route.dart';
import 'package:test/expect.dart';
import 'package:test/scaffolding.dart';

void main() {
  group('path', () {
    test('withParameters_correctPath', () {
      var route = Route('some/short/:path');
      expect(route.path, equals('some/short/:path'));

      route = Route('some/:short/path/:again');
      expect(route.path, equals('some/:short/path/:again'));
    });

    test('withEmptySections_pathWithoutEmptySections', () {
      var route = Route('some/short//path');
      expect(route.path, equals('some/short/path'));
    });
  });

  group('matches', () {
    test('matchingPathWithNoWilds_returnsTrue', () {
      var route = Route('some/short/path');
      expect(route.matches(['some', 'short', 'path']), isTrue);
    });

    test('matchingPathWithBasicWilds_returnsTrue', () {
      var route = Route('some/short/:path');
      expect(route.matches(['some', 'short', 'stick']), isTrue);

      route = Route(':some/short/:path');
      expect(route.matches(['a', 'short', 'route']), isTrue);
    });

    test('matchingPathWithSuperWilds_returnsTrue', () {
      var route = Route('some/short/::path');
      expect(route.matches(['some', 'short', 'stick']), isTrue);
      expect(route.matches(['some', 'short', 'thin', 'blue', 'stick']), isTrue);

      route = Route('::some/short/path');
      expect(route.matches(['a', 'short', 'path']), isTrue);
      expect(route.matches(['a', 'not', 'so', 'short', 'path']), isTrue);

      route = Route('some/::short/path');
      expect(route.matches(['some', 'short', 'path']), isTrue);
      expect(route.matches(['some', 'not', 'so', 'short', 'little', 'path']),
          isTrue);
    });

    test('matchingPathWithMixedWilds_returnsTrue', () {
      var route = Route(':some/short/::path');
      expect(route.matches(['some', 'short', 'stick']), isTrue);
      expect(route.matches(['some', 'short', 'thin', 'blue', 'stick']), isTrue);

      route = Route('::some/:short/path');
      expect(route.matches(['a', 'short', 'path']), isTrue);
      expect(
          route.matches(['a', 'not', 'so', 'short', 'narrow', 'path']), isTrue);

      route = Route('some/::short/:path');
      expect(route.matches(['some', 'short', 'path']), isTrue);
      expect(route.matches(['some', 'not', 'so', 'short', 'little', 'path']),
          isTrue);
    });

    test('emptyPath_returnsTrueForEmptyRoute', () {
      var route = Route('');
      expect(route.matches([]), isTrue);
    });

    test('differentPath_returnsFalse', () {
      var route = Route('some/short/path');
      expect(route.matches(['some', 'long', 'path']), isFalse);

      route = Route('some/short');
      expect(route.matches(['some', 'short', 'path']), isFalse);

      route = Route('short/path');
      expect(route.matches(['some', 'short', 'path']), isFalse);

      route = Route('some/short/path');
      expect(route.matches(['short', 'path']), isFalse);

      route = Route('some/short/path');
      expect(route.matches(['some', 'short']), isFalse);
    });
  });

  group('firstNormalMatch', () {
    test('routeWithOnlyNormalSegments_returnsZero', () {
      var route = Route('some/short/path');
      expect(route.firstNormalMatch(['some', 'short', 'path']), equals(0));
    });

    test('routeWithBasicWildSegments_returnsIndexOfFirstMatch', () {
      var route = Route('some/:short/path');
      expect(route.firstNormalMatch(['some', 'short', 'path']), equals(0));

      route = Route(':some/short/path');
      expect(route.firstNormalMatch(['some', 'short', 'path']), equals(1));

      route = Route(':some/:short/path');
      expect(route.firstNormalMatch(['some', 'short', 'path']), equals(2));
    });

    test('routeWithSuperWildSegments_returnsIndexOfFirstMatch', () {
      var route = Route('some/::short/path');
      expect(route.firstNormalMatch(['some', 'short', 'path']), equals(0));

      route = Route(':some/::short/path');
      expect(route.firstNormalMatch(['some', 'short', 'path']), equals(2));
      expect(route.firstNormalMatch(['some', 'short', 'little', 'path']),
          equals(3));
    });

    test('routeWithOnlyWildSegments_returnsNull', () {
      var route = Route(':some/:short/:path');
      expect(route.firstNormalMatch(['some', 'short', 'path']), isNull);

      route = Route(':some/::short/:path');
      expect(route.firstNormalMatch(['some', 'short', 'path']), isNull);
    });

    test('withAfterSpecified_returnsIndexOfFirstMatchAfterSpecifiedIndex', () {
      var route = Route('some/::short/path');
      expect(route.firstNormalMatch(['some', 'short', 'path'], 0), equals(2));
    });
  });

  group('getParameters', () {
    test('wrongNumberOfSegments_throws', () {
      var route = Route('some/short/path');

      expect(() => route.getParameters(['some', 'short']), throwsArgumentError);
      expect(() => route.getParameters(['some', 'short', 'path', 'again']),
          throwsArgumentError);
    });

    test('noWilds_returnsEmptyList', () {
      var route = Route('some/short/path');
      expect(route.getParameters(['some', 'short', 'path']), isEmpty);
    });

    test('withBasicWilds_returnsParameterValues', () {
      var route = Route('some/short/:path');
      expect(
          route.getParameters(['some', 'short', 'c']), equals({'path': 'c'}));

      route = Route('some/:short/:path');
      expect(route.getParameters(['some', 'b', 'c']),
          equals({'short': 'b', 'path': 'c'}));

      route = Route(':some/short/:path');
      expect(route.getParameters(['a', 'short', 'c']),
          equals({'some': 'a', 'path': 'c'}));
    });

    test('withSuperWilds_returnsParameterValues', () {
      var route = Route('some/short/::path');
      expect(
          route.getParameters(['some', 'short', 'stick']),
          equals({
            'path': ['stick']
          }));
      expect(
          route.getParameters(['some', 'short', 'thin', 'blue', 'stick']),
          equals({
            'path': ['thin', 'blue', 'stick']
          }));

      route = Route('::some/short/path');
      expect(
          route.getParameters(['a', 'short', 'path']),
          equals({
            'some': ['a']
          }));
      expect(
          route.getParameters(['a', 'not', 'so', 'short', 'path']),
          equals({
            'some': ['a', 'not', 'so']
          }));

      route = Route('some/::short/path');
      expect(
          route.getParameters(['some', 'short', 'path']),
          equals({
            'short': ['short']
          }));
      expect(
          route.getParameters(['some', 'not', 'so', 'short', 'little', 'path']),
          equals({
            'short': ['not', 'so', 'short', 'little']
          }));
    });

    test('withMixedWilds_returnsParameterValues', () {
      var route = Route(':some/short/::path');
      expect(
          route.getParameters(['some', 'short', 'stick']),
          equals({
            'some': 'some',
            'path': ['stick']
          }));
      expect(
          route.getParameters(['some', 'short', 'thin', 'blue', 'stick']),
          equals({
            'some': 'some',
            'path': ['thin', 'blue', 'stick']
          }));

      route = Route('::some/:short/path');
      expect(
          route.getParameters(['a', 'short', 'path']),
          equals({
            'some': ['a'],
            'short': 'short'
          }));
      expect(
          route.getParameters(['a', 'not', 'so', 'short', 'path']),
          equals({
            'some': ['a', 'not', 'so'],
            'short': 'short'
          }));

      route = Route('some/::short/:path');
      expect(
          route.getParameters(['some', 'short', 'path']),
          equals({
            'short': ['short'],
            'path': 'path'
          }));
      expect(
          route.getParameters(['some', 'not', 'so', 'short', 'little', 'path']),
          equals({
            'short': ['not', 'so', 'short', 'little'],
            'path': 'path'
          }));
    });
  });

  group('overlapsWith', () {
    test('differentNumberOfSegments_noOverlap', () {
      var route1 = Route('some/short/path');
      var route2 = Route('some/short');

      expect(route1.overlapsWith(route2), isFalse);
    });

    test('identicalRoutes_doOverlap', () {
      var route1 = Route('some/short/path');
      var route2 = Route('some/short/path');
      expect(route1.overlapsWith(route2), isTrue);

      route1 = Route('some/short/:path');
      route2 = Route('some/short/:stick');
      expect(route1.overlapsWith(route2), isTrue);

      route1 = Route('some/::short/path');
      route2 = Route('some/::long/path');
      expect(route1.overlapsWith(route2), isTrue);

      route1 = Route('some/::short/:path');
      route2 = Route('some/::long/:stick');
      expect(route1.overlapsWith(route2), isTrue);
    });

    test('normalAndBasicWild_noOverlap', () {
      var route1 = Route('some/short/path');
      var route2 = Route('some/short/:path');
      expect(route1.overlapsWith(route2), isFalse);

      route1 = Route('some/short/path');
      route2 = Route('some/short/:stick');
      expect(route1.overlapsWith(route2), isFalse);

      route1 = Route('some/short/path');
      route2 = Route(':some/:short/:stick');
      expect(route1.overlapsWith(route2), isFalse);
    });

    test('normalAndSuperWild_noOverlap', () {
      var route1 = Route('some/short/path');
      var route2 = Route('some/::short/path');
      expect(route1.overlapsWith(route2), isFalse);

      route1 = Route('some/short/path');
      route2 = Route('some/::short/:stick');
      expect(route1.overlapsWith(route2), isFalse);

      route1 = Route('some/short/path');
      route2 = Route('some/::short');
      expect(route1.overlapsWith(route2), isFalse);
    });

    test('wildsMixedWithNormalSegments_noOverlap', () {
      var route1 = Route('some/slightly/:longer/short/:path');
      var route2 = Route(':some/::slightly/:short/path');
      expect(route1.overlapsWith(route2), isFalse);
    });

    test('wildsMixedWithoutNormalSegments_doOverlap', () {
      var route1 = Route('some/:short/::path');
      var route2 = Route('some/::short/:path');
      expect(route1.overlapsWith(route2), isTrue);

      route1 = Route('some/short/:path');
      route2 = Route('some/short/::path');
      expect(route1.overlapsWith(route2), isTrue);
    });

    test('differentLengthsThatCanBeCoveredBySuperWilds_doOverlap', () {
      // The difference in the paths can be covered by the super wilds
      // since the super wild simply can be expanded.
      var route1 = Route(':some/::path');
      var route2 = Route(':some/::short/:path');
      expect(route1.overlapsWith(route2), isTrue);

      route1 = Route(':some/::short/:path/:with/stuff');
      route2 = Route(':some/::short/:path/stuff');
      expect(route1.overlapsWith(route2), isTrue);
    });

    test('differentLengthsThatCannotBeCoveredBySuperWilds_noOverlap', () {
      // The difference in the paths cannot be covered by the super wilds
      // since there is a normal segment in between.
      var route1 = Route('::some/:short/path/:with/:extra/stuff');
      var route2 = Route('::some/:short/path/:with/stuff');
      expect(route1.overlapsWith(route2), isFalse);
    });
  });

  group('equals', () {
    test('samePathsWithNoParameters_areEqual', () {
      var route1 = Route('some/short/path');
      var route2 = Route('some/short/path');

      expect(route1, equals(route2));
    });

    test('samePathsWithParameters_areEqual', () {
      var route1 = Route('some/short/:cat');
      var route2 = Route('some/short/:cat');
      var route3 = Route('some/short/:dog');
      var route4 = Route('some/:short/:dog');

      expect(route1, equals(route2));
      expect(route1, equals(route3),
          reason: 'Parameter name should not affect equality');
      expect(route1, equals(route4),
          reason: 'Parameter name should not affect equality');
    });

    test('differentPaths_areNotEqual', () {
      var route1 = Route('some/short');
      var route2 = Route('some/short/path');
      var route3 = Route('some/short2/');
      var route4 = Route('some/');

      expect(route1, isNot(equals(route2)));
      expect(route1, isNot(equals(route3)));
      expect(route1, isNot(equals(route4)));
    });
  });

  group('compareTo', () {
    test('samePathsWithNoParameters_areEqual', () {
      var route1 = Route('some/short/path');
      var route2 = Route('some/short/path');

      expect(route1.compareTo(route2), equals(0));
    });

    test('samePathsWithParameters_areEqual', () {
      var route1 = Route('some/short/:cat');
      var route2 = Route('some/short/:cat');
      var route3 = Route('some/short/:dog');
      var route4 = Route('some/short/dog');

      expect(route1.compareTo(route2), equals(0));
      expect(route1.compareTo(route3), equals(0),
          reason: 'Parameter name should not affect sorting');
      expect(route1.compareTo(route4), equals(0),
          reason: 'Parameter name should not affect sorting');
    });

    test('differentPaths_sortedCorrectly', () {
      var route1 = Route('some/short');
      var route2 = Route('some/short/path');
      var route3 = Route('some/short2/');
      var route4 = Route('some/');
      var route5 = Route('some/long/route');
      var route6 = Route('some/long/path');

      var expected = [route4, route6, route5, route1, route2, route3];
      var actual = [route1, route2, route3, route4, route5, route6]..sort();

      expect(actual, orderedEquals(expected));
    });
  });

  group('parent', () {
    test('root_returnsNull', () {
      var route = Route('');
      expect(route.parent, isNull);
    });

    test('withPath_returnsParent', () {
      var route = Route('some/short/path');
      var expected = Route('some/short');

      expect(route.parent, equals(expected));
    });
  });
}
