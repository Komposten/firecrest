import 'package:firecrest/firecrest.dart';
import 'package:firecrest/src/route.dart';
import 'package:firecrest/src/statistics/statistics_collector.dart';
import 'package:test/test.dart';

void main() {
  group('Statistics', () {
    group('update', () {
      test('multipleRoutes_latenciesCalculatedPerRoute', () {
        int time = 0;
        final timeNow = () => DateTime.fromMillisecondsSinceEpoch(++time);
        final collector1 = BasicCollector.withTimeSource(timeNow);
        final collector2 = BasicCollector.withTimeSource(timeNow);
        final route1 = Route('/a');
        final route2 = Route('/b');
        final statistics = Statistics();

        collector1
          ..forRoute(route1)
          ..begin('1')
          ..begin('2')
          ..end('2')
          ..begin('3')
          ..end('3')
          ..end('1')
          ..close();

        collector2
          ..forRoute(route2)
          ..begin('4')
          ..begin('5')
          ..end('5')
          ..end('4')
          ..begin('6')
          ..end('6')
          ..close();

        statistics.update(collector1);
        statistics.update(collector2);

        expect(
            statistics.statsPerRoute.keys, equals({route1.path, route2.path}));
        expect(statistics.statsPerRoute[route1.path]!.avgLatencyPerHandler,
            equals({Statistics.TOTAL_KEY: 8, '1': 5, '2': 1, '3': 1}));
        expect(statistics.statsPerRoute[route2.path]!.avgLatencyPerHandler,
            equals({Statistics.TOTAL_KEY: 14, '4': 3, '5': 1, '6': 1}));
      });

      test('noRoute_latenciesAddedAsErrorStats', () {
        int time = 0;
        final timeNow = () => DateTime.fromMillisecondsSinceEpoch(++time);
        final collector1 = BasicCollector.withTimeSource(timeNow);
        final statistics = Statistics();

        collector1
          ..begin('1')
          ..begin('2')
          ..end('2')
          ..begin('3')
          ..end('3')
          ..end('1')
          ..close();

        statistics.update(collector1);

        expect(statistics.statsPerRoute, isEmpty);
        expect(statistics.errorStats.avgLatencyPerHandler,
            equals({Statistics.TOTAL_KEY: 7, '1': 5, '2': 1, '3': 1}));
      });
    });
  });

  group('RouteStatistics', () {
    group('updateLatency', () {
      test('latenciesCalculatedCorrectly', () {
        final stats = RouteStatistics();

        stats.updateLatencies({'handler1': 13, 'handler2': 9}, 30);
        stats.updateLatencies({'handler1': 10, 'handler2': 6}, 25);
        stats.updateLatencies({'handler1': 22, 'handler2': 3}, 32);

        expect(stats.minLatencyPerHandler,
            equals({'handler1': 10, 'handler2': 3, Statistics.TOTAL_KEY: 25}));
        expect(stats.maxLatencyPerHandler,
            equals({'handler1': 22, 'handler2': 9, Statistics.TOTAL_KEY: 32}));
        expect(stats.avgLatencyPerHandler,
            equals({'handler1': 15, 'handler2': 6, Statistics.TOTAL_KEY: 29}));
      });
    });
  });
}
