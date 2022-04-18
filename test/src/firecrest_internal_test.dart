import 'dart:convert';
import 'dart:io';

import 'package:firecrest/firecrest.dart';
import 'package:firecrest/src/firecrest_internal.dart';
import 'package:test/test.dart';

import 'test_util/matchers.dart';

void main() {
  group('Controller validation', () {
    test('validControllers_acceptedAsController', () {
      var controllers = [ControllerExtending(), ControllerWithMeta()];
      expect(
          () => FirecrestInternal(controllers, TestHandler()), returnsNormally);
    });

    test('noControllerMetaOrSubClass_throwsArgumentError', () {
      var controllers = [ControllerNoMeta()];
      expect(
          () => FirecrestInternal(controllers, TestHandler()),
          throwsWithMessage<ArgumentError>(
              'ControllerNoMeta is neither a Controller nor annotated with @Controller'));
    });

    test('twoControllersForSameRoute_throwsStateError', () {
      List<Object> controllers = [ControllerUser(), ControllerUser()];
      expect(
          () => FirecrestInternal(controllers, TestHandler()),
          throwsWithMessage<StateError>(
              'Two controllers registered for path /user: ControllerUser and ControllerUser'));

      controllers = [ControllerWild(), ControllerWild2()];
      expect(
          () => FirecrestInternal(controllers, TestHandler()),
          throwsWithMessage<StateError>(
              'Two controllers registered for path /:wild: ControllerWild and ControllerWild2'));
    });
  });

  group('Statistics collection', () {
    test('controllerThrowsAnError_collectorIsClosedCorrectly', () async {
      var controllers = <Object>[ControllerThatThrows()];
      var firecrest = FirecrestInternal(controllers, TestHandler());
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
      var firecrest = FirecrestInternal(controllers, TestHandler(),
          collectStatistics: false);
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

  group('Request validation', () {
    test('Unhandled method', () async {
      var controllers = [ControllerWithValidGet()];
      var firecrest = FirecrestInternal(controllers, TestHandler());
      firecrest.start('localhost', 31233);

      var responseFuture = _sendRequest(31233, 'POST', 'valid');
      await expectLater(responseFuture, completes);
      var response = await responseFuture;
      var message = await response.transform(utf8.decoder).join();

      expect(response.statusCode, HttpStatus.methodNotAllowed);
      expect(message, equals('Method post is not allowed for route /valid'));
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

class ControllerExtending extends Controller {
  ControllerExtending() : super('i-extend');
}

@Controller('i-meta')
class ControllerWithMeta {}

@Controller('user')
class ControllerUser {}

@Controller('user/posts/recent')
class ControllerUserPostsRecent {}

@Controller('user/:what/:why')
class ControllerUserWild {}

@Controller('user/:what/recent')
class ControllerUserWildRecent {}

@Controller(':wild')
class ControllerWild {}

@Controller(':wild')
class ControllerWild2 {}

@Controller('valid')
class ControllerWithValidGet {
  @RequestHandler()
  Future<void> get(HttpResponse response) async {
    response.statusCode = 200;
    response.write('Got!');
    await response.flush();
    await response.close();
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
