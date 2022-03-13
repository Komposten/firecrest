import 'dart:convert';
import 'dart:io';

import 'package:firecrest/src/annotations/controller.dart';
import 'package:firecrest/src/annotations/request_handler.dart';
import 'package:firecrest/src/error_handler.dart';
import 'package:firecrest/src/firecrest.dart';
import 'package:firecrest/src/server_exception.dart';
import 'package:test/test.dart';

import 'test_util/matchers.dart';

void main() {
  group('Controller validation', () {
    test('noControllerMeta_throwsArgumentError', () {
      var controllers = [ControllerNoMeta()];
      expect(
          () => Firecrest(controllers, TestHandler()),
          throwsWithMessage<ArgumentError>(
              'ControllerNoMeta is not an @Controller'));
    });

    test('twoControllersForSameRoute_throwsStateError', () {
      List<Object> controllers = [ControllerUser(), ControllerUser()];
      expect(
          () => Firecrest(controllers, TestHandler()),
          throwsWithMessage<StateError>(
              'Two controllers registered for path "user": ControllerUser and ControllerUser'));

      controllers = [ControllerWild(), ControllerWild2()];
      expect(
          () => Firecrest(controllers, TestHandler()),
          throwsWithMessage<StateError>(
              'Two controllers registered for path ":wild": ControllerWild and ControllerWild2'));
    });

    test('controllerWithNoResponseParameter_throwsArgumentError', () {
      var controllers = <Object>[ControllerNoParameters()];
      expect(
          () => Firecrest(controllers, TestHandler()),
          throwsWithMessage<ArgumentError>(
              'Request handler "get" in ControllerNoParameters must have an HttpResponse as first positional parameter'));

      controllers = [ControllerNoResponseParameter()];
      expect(
          () => Firecrest(controllers, TestHandler()),
          throwsWithMessage<ArgumentError>(
              'Request handler "get" in ControllerNoResponseParameter must have an HttpResponse as first positional parameter'));
    });
  });

  group('Statistics collection', () {
    test('controllerThrowsAnError_collectorIsClosedCorrectly', () async {
      var controllers = <Object>[ControllerThatThrows()];
      var firecrest = Firecrest(controllers, TestHandler());
      await firecrest.start('localhost', 31231);

      var responseFuture = _sendRequest(31231, 'GET', 'i-throw');
      await expectLater(responseFuture, completes);
      var response = await responseFuture;
      var message = await response.transform(utf8.decoder).join();

      expect(response.statusCode, equals(HttpStatus.serviceUnavailable));
      expect(message, equals('i throw! >:o'));

      await firecrest.close();
    });

    test('statisticsDisabled_doesNotCollect', () async {
      var controllers = <Object>[];
      var firecrest =
          Firecrest(controllers, TestHandler(), collectStatistics: false);
      await firecrest.start('localhost', 31232);

      await expectLater(_sendRequest(31232, 'GET', 'some-path'), completes);
      expect(firecrest.statistics.errorStats.requestCount, equals(0));

      firecrest.setCollectStatistics(true);
      await expectLater(_sendRequest(31232, 'GET', 'some-path'), completes);
      expect(firecrest.statistics.errorStats.requestCount, equals(1));

      firecrest.setCollectStatistics(false);
      await expectLater(_sendRequest(31232, 'GET', 'some-path'), completes);
      expect(firecrest.statistics.errorStats.requestCount, equals(1));

      await firecrest.close();
    });
  });

  /* TEST jhj:
      - Middleware added in correct order
      - Middleware run in order before controller
      - ErrorHandler receives 404 if controller cannot handle request method
      - ErrorHandler receives 404 if no controller exists for request route
      - ErrorHandler receives 500 if controller throws random object
      - ErrorHandler called if controller throws.
   */
}

Future<HttpClientResponse> _sendRequest(
    int port, String method, String path) async {
  var client = HttpClient();
  var request = await client.open(method, 'localhost', port, path);
  return request.close();
}

class ControllerNoMeta {}

@Controller('user')
class ControllerUser {}

@Controller(':wild')
class ControllerWild {}

@Controller(':wild')
class ControllerWild2 {}

@Controller('no-parameters')
class ControllerNoParameters {
  @RequestHandler()
  int get() {
    return 1;
  }
}

@Controller('no-response-parameter')
class ControllerNoResponseParameter {
  @RequestHandler()
  String get(String name, {count = 2}) {
    return '$name: $count';
  }
}

@Controller('i-throw')
class ControllerThatThrows {
  @RequestHandler()
  int get(HttpResponse response) {
    throw ServerException(HttpStatus.serviceUnavailable, 'i throw! >:o');
  }
}

class TestHandler implements ErrorHandler {
  final handled = <HttpRequest>[];

  @override
  Future<void> handle(ServerException exception, HttpRequest request) async {
    handled.add(request);
    request.response.statusCode = exception.status;
    request.response.write(exception.message);
    await request.response.flush();
    await request.response.close();
  }
}
