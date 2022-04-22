import 'package:firecrest/src/route/route.dart';
import 'package:firecrest/src/route/segment.dart';
import 'package:firecrest/src/util/route_lookup.dart';
import 'package:test/test.dart';

import '../test_util/matchers.dart';

void main() {
  group('RouteLookup', () {
    test('multipleRoutes_correctTreeStructure', () {
      var routes = [
        Route('user'),
        Route('user/:name'),
        Route('user/:name/activity'),
        Route('user/:name/posts'),
        Route('users'),
        Route('file/::path'),
        Route('file/::path/stats'),
        Route(':wild'),
        Route(':wild/strawberry/cake')
      ];
      var lookup = RouteLookup(routes);

      expect(lookup.root.route, isNull);
      expect(lookup.root.segment.isAnyWild, isFalse);
      expect(lookup.root.normalChildren, hasLength(3));
      expect(lookup.root.wildChild, isNotNull);

      // user/
      expect(lookup.root.normalChildren.containsKey('user'), isTrue);
      var user = lookup.root.normalChildren['user']!;
      expect(user.segment, equals(Segment('user', SegmentType.normal)));
      expect(user.route, equals(routes[0]));
      expect(user.normalChildren, isEmpty);
      expect(user.wildChild, isNotNull);

      // user/:name/
      var userName = user.wildChild!;
      expect(userName.segment, equals(Segment(':name', SegmentType.basicWild)));
      expect(userName.route, equals(routes[1]));
      expect(userName.normalChildren, hasLength(2));
      expect(userName.wildChild, isNull);

      // user/:name/activity/
      expect(userName.normalChildren.containsKey('activity'), isTrue);
      var userActivity = userName.normalChildren['activity']!;
      expect(userActivity.segment,
          equals(Segment('activity', SegmentType.normal)));
      expect(userActivity.route, equals(routes[2]));
      expect(userActivity.normalChildren, isEmpty);
      expect(userActivity.wildChild, isNull);

      // user/:name/posts/
      expect(userName.normalChildren.containsKey('posts'), isTrue);
      var userPosts = userName.normalChildren['posts']!;
      expect(userPosts.segment, equals(Segment('posts', SegmentType.normal)));
      expect(userPosts.route, equals(routes[3]));
      expect(userPosts.normalChildren, isEmpty);
      expect(userPosts.wildChild, isNull);

      // users/
      expect(lookup.root.normalChildren.containsKey('users'), isTrue);
      var users = lookup.root.normalChildren['users']!;
      expect(users.segment, equals(Segment('users', SegmentType.normal)));
      expect(users.route, equals(routes[4]));
      expect(users.normalChildren, isEmpty);
      expect(users.wildChild, isNull);

      // file/
      expect(lookup.root.normalChildren.containsKey('file'), isTrue);
      var file = lookup.root.normalChildren['file']!;
      expect(file.segment, equals(Segment('file', SegmentType.normal)));
      expect(file.route, isNull);
      expect(file.normalChildren, isEmpty);
      expect(file.wildChild, isNotNull);

      // file/::path/
      var filePath = file.wildChild!;
      expect(
          filePath.segment, equals(Segment('::path', SegmentType.superWild)));
      expect(filePath.route, equals(routes[5]));
      expect(filePath.normalChildren, hasLength(1));
      expect(filePath.wildChild, isNull);

      // file/::path/stats
      expect(filePath.normalChildren.containsKey('stats'), isTrue);
      var fileStats = filePath.normalChildren['stats']!;
      expect(fileStats.segment, equals(Segment('stats', SegmentType.normal)));
      expect(fileStats.route, equals(routes[6]));
      expect(fileStats.normalChildren, isEmpty);
      expect(fileStats.wildChild, isNull);

      // :wild/
      var wild = lookup.root.wildChild!;
      expect(wild.segment, equals(Segment(':wild', SegmentType.basicWild)));
      expect(wild.route, equals(routes[7]));
      expect(wild.normalChildren, hasLength(1));
      expect(wild.wildChild, isNull);

      // :wild/strawberry
      expect(wild.normalChildren.containsKey('strawberry'), isTrue);
      var wildStrawberry = wild.normalChildren['strawberry']!;
      expect(wildStrawberry.segment,
          equals(Segment('strawberry', SegmentType.normal)));
      expect(wildStrawberry.route, isNull);
      expect(wildStrawberry.normalChildren, hasLength(1));
      expect(wildStrawberry.wildChild, isNull);

      // :wild/strawberry/cake
      expect(wildStrawberry.normalChildren.containsKey('cake'), isTrue);
      var wildStrawberryCake = wildStrawberry.normalChildren['cake']!;
      expect(wildStrawberryCake.segment,
          equals(Segment('cake', SegmentType.normal)));
      expect(wildStrawberryCake.route, equals(routes[8]));
      expect(wildStrawberryCake.normalChildren, isEmpty);
      expect(wildStrawberryCake.wildChild, isNull);
    });

    test('overlappingRoutes_throwsStateError', () {
      var routes1 = [Route('user'), Route('user')];
      var routes2 = [Route(':user'), Route(':user')];
      var routes3 = [Route(':user'), Route('::user')];
      expect(() => RouteLookup(routes1),
          throwsWithMessage<StateError>('Duplicate routes: user and user'));
      expect(() => RouteLookup(routes2),
          throwsWithMessage<StateError>('Duplicate routes: :user and :user'));
      expect(() => RouteLookup(routes3),
          throwsWithMessage<StateError>('Duplicate routes: ::user and :user'));
    });
  });

  group('findRoute', () {
    test('singleMatchingRoute_matchingRouteReturned', () {
      var routes = [Route('user'), Route('user/bob'), Route('users')];
      var lookup = RouteLookup(routes);

      var actual = lookup.findRoute(['user']);
      expect(actual, isNotNull);
      expect(actual?.path, equals('user'));
    });

    test('noMatchingRoute_nullReturned', () {
      var routes = [Route('user'), Route('user/bob'), Route('users')];
      var lookup = RouteLookup(routes);

      var actual = lookup.findRoute(['post']);
      expect(actual, isNull);
    });

    test('emptyPathSegments_ignored', () {
      var routes = [Route('user/posts/recent')];
      var lookup = RouteLookup(routes);

      var actual =
          lookup.findRoute(['', 'user', '', '', 'posts', 'recent', '']);
      expect(actual, isNotNull);
      expect(actual?.path, equals('user/posts/recent'));
    });

    test('emptyPath_matchesRootRoute', () {
      var routes = [Route(':wild')];
      var lookup = RouteLookup(routes);

      var actual = lookup.findRoute([]);
      expect(actual, isNull);

      routes.add(Route(''));
      lookup = RouteLookup(routes);

      actual = lookup.findRoute([]);
      expect(actual, isNotNull);
      expect(actual?.path, equals(''));
    });

    test('multipleMatchingRoutes_highestPriorityRouteReturned', () {
      var routes = [
        Route('user'),
        Route(':wild'),
        Route('user/posts/recent'),
        Route('user/:what/:why'),
        Route('user/:what/recent')
      ];
      var lookup = RouteLookup(routes);

      var actual = lookup.findRoute(['user']);
      expect(actual, isNotNull);
      expect(actual?.path, equals('user'));

      actual = lookup.findRoute(['post']);
      expect(actual, isNotNull);
      expect(actual?.path, equals(':wild'));

      actual = lookup.findRoute('user/posts/recent'.split('/'));
      expect(actual, isNotNull);
      expect(actual?.path, equals('user/posts/recent'));

      actual = lookup.findRoute('user/photos/recent'.split('/'));
      expect(actual, isNotNull);
      expect(actual?.path, equals('user/:what/recent'));

      actual = lookup.findRoute('user/photos/trending'.split('/'));
      expect(actual, isNotNull);
      expect(actual?.path, equals('user/:what/:why'));
    });

    test('superWildRoutes_matchesIfHighestPriority', () {
      var routes = [
        Route('file/::path'),
        Route(':wild/::path'),
        Route('file/::path/stats'),
        Route('file/::path/stats/all'),
        Route('file/posts/recent')
      ];
      var lookup = RouteLookup(routes);

      var actual = lookup.findRoute(['file']);
      expect(actual, isNull);

      actual = lookup.findRoute('file/a/b/c'.split('/'));
      expect(actual, isNotNull);
      expect(actual?.path, equals('file/::path'));

      actual = lookup.findRoute('file/a/b/c/stats'.split('/'));
      expect(actual, isNotNull);
      expect(actual?.path, equals('file/::path/stats'));

      actual = lookup.findRoute('file/a/b/c/stats/all'.split('/'));
      expect(actual, isNotNull);
      expect(actual?.path, equals('file/::path/stats/all'));

      actual = lookup.findRoute('file/a/b/c/stats/none'.split('/'));
      expect(actual, isNotNull);
      expect(actual?.path, equals('file/::path'));

      actual = lookup.findRoute('file/posts/recent'.split('/'));
      expect(actual, isNotNull);
      expect(actual?.path, equals('file/posts/recent'));

      actual = lookup.findRoute('user'.split('/'));
      expect(actual, isNull);

      actual = lookup.findRoute('user/a/b/c'.split('/'));
      expect(actual, isNotNull);
      expect(actual?.path, equals(':wild/::path'));
    });
  });
}
