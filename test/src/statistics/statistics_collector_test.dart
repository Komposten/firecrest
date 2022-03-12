import 'package:firecrest/src/route.dart';
import 'package:firecrest/src/statistics/statistics_collector.dart';
import 'package:test/test.dart';

import '../test_util/matchers.dart';

void main() {
  late int time;
  late BasicCollector collector;
  final timeNow = () => DateTime.fromMillisecondsSinceEpoch(++time);

  setUp(() {
    time = 0;
    collector = BasicCollector.withTimeSource(timeNow);
  });

  group('BasicCollector', () {
    group('forRoute', () {
      test('closed_throwsStateError', () {
        collector.close();
        expect(() => collector.forRoute(Route('/a/b/c')),
            throwsWithMessage<StateError>('the collector has been closed'));
      });
    });

    group('begin', () {
      test('closed_throwsStateError', () {
        collector.close();
        expect(() => collector.begin('handler'),
            throwsWithMessage<StateError>('the collector has been closed'));
      });
    });

    group('end', () {
      test('closed_throwsStateError', () {
        collector.close();
        expect(() => collector.end('handler'),
            throwsWithMessage<StateError>('the collector has been closed'));
      });

      test('unknownHandler_throwsArgumentError', () {
        expect(
            () => collector.end('handler'),
            throwsWithMessage<ArgumentError>(
                'unknown handler: handler (String)'));
      });
    });

    group('endAll', () {
      test('multipleOpenHandlers_closesAll', () {
        collector.begin('1');
        collector.begin('2');
        collector.begin('3');
        collector.endAll();

        expect(() => collector.close(), returnsNormally);
      });
    });

    group('close', () {
      test('alreadyClosed_doesNotChangeState', () {
        collector.close();
        final totalTime = collector.totalTime;
        collector.close();

        expect(collector.totalTime, equals(totalTime));
      });

      test('withOpenHandler_throwsStateError', () {
        collector.begin('handler');
        collector.begin('handler2');
        expect(
            () => collector.close(),
            throwsWithMessage<StateError>(
                'the following handlers have not been closed with end(): handler (String), handler2 (String)'));
      });
    });

    group('route', () {
      test('notClosed_throwsStateError', () {
        expect(() => collector.route,
            throwsWithMessage<StateError>('must call close() first'));

        collector.forRoute(Route('/a/b/c'));
        expect(() => collector.route,
            throwsWithMessage<StateError>('must call close() first'));
      });

      test('closed_returnsSpecifiedRoute', () {
        collector.close();
        expect(collector.route, isNull);

        collector = BasicCollector.withTimeSource(timeNow);
        collector.forRoute(null);
        collector.close();
        expect(collector.route, isNull);

        final route = Route('/a/b/c');
        collector = BasicCollector.withTimeSource(timeNow);
        collector.forRoute(route);
        collector.close();
        expect(collector.route, equals(route));
      });
    });

    group('totalTime', () {
      test('notClosed_throwsStateError', () {
        expect(() => collector.totalTime,
            throwsWithMessage<StateError>('must call close() first'));
      });

      test('closed_returnsCorrectTime', () {
        collector
          ..begin('1')
          ..end('1')
          ..begin('2')
          ..end('2');
        collector.close();

        expect(collector.totalTime, equals(5));
      });
    });

    group('timePerHandler', () {
      test('notClosed_throwsStateError', () {
        expect(() => collector.timePerHandler,
            throwsWithMessage<StateError>('must call close() first'));
      });

      test('closed_returnsCorrectTimes', () {
        collector
          ..begin('1')
          ..begin('2')
          ..end('2')
          ..begin('3')
          ..end('3')
          ..end('1')
          ..close();

        expect(collector.timePerHandler, equals({'1': 5, '2': 1, '3': 1}));
      });
    });
  });
}
