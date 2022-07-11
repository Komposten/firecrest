import 'dart:convert';
import 'dart:io';

import 'package:firecrest/firecrest.dart';
import 'package:firecrest/src/firecrest_internal.dart';
import 'package:test/test.dart';

import 'test_util/matchers.dart';

void main() {
  var port = 31230;

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
      await firecrest.start('localhost', ++port);

      var responseFuture = _sendRequest(port, 'GET', 'i-throw');
      await expectLater(responseFuture, completes);

      expect(firecrest.statistics.statsPerRoute, hasLength(1));
      expect(firecrest.statistics.statsPerRoute['i-throw']?.requestCount,
          equals(1));

      await firecrest.close();
    });

    test('statisticsDisabled_doesNotCollect', () async {
      var controllers = <Object>[];
      var firecrest = FirecrestInternal(controllers, TestHandler(),
          collectStatistics: false);
      await firecrest.start('localhost', ++port);

      await expectLater(_sendRequest(port, 'GET', 'some-path'), completes);
      expect(firecrest.statistics.noRouteStats.requestCount, equals(0));

      firecrest.setCollectStatistics(true);
      await expectLater(_sendRequest(port, 'GET', 'some-path'), completes);
      expect(firecrest.statistics.noRouteStats.requestCount, equals(1));

      firecrest.setCollectStatistics(false);
      await expectLater(_sendRequest(port, 'GET', 'some-path'), completes);
      expect(firecrest.statistics.noRouteStats.requestCount, equals(1));

      await firecrest.close();
    });
  });

  group('Request validation', () {
    test('unknownRoute_respondsWithNotFound', () async {
      var controllers = [ControllerWithValidGet()];
      var firecrest = FirecrestInternal(controllers, TestHandler());
      firecrest.start('localhost', ++port);

      var responseFuture = _sendRequest(port, 'GET', 'invalid');
      await expectLater(responseFuture, completes);
      var response = await responseFuture;
      var message = await response.transform(utf8.decoder).join();

      expect(response.statusCode, HttpStatus.notFound);
      expect(message,
          equals('No controller has been registered for path /invalid'));

      await firecrest.close();
    });

    test('unhandledMethod_respondsWithMethodNotAllowed', () async {
      var controllers = [ControllerWithValidGet()];
      var firecrest = FirecrestInternal(controllers, TestHandler());
      firecrest.start('localhost', ++port);

      var responseFuture = _sendRequest(port, 'POST', 'valid');
      await expectLater(responseFuture, completes);
      var response = await responseFuture;
      var message = await response.transform(utf8.decoder).join();

      expect(response.statusCode, HttpStatus.methodNotAllowed);
      expect(message, equals('Method post is not allowed for route /valid'));

      await firecrest.close();
    });
  });

  group('Middleware', () {
    test('multipleMiddlewares_calledInCorrectOrder', () async {
      var controllers = <Object>[
        ControllerWithMiddleware(),
        ControllerWithMiddleware2()
      ];
      var firecrest = FirecrestInternal(controllers, TestHandler());
      await firecrest.start('localhost', ++port);

      var responseFuture = _sendRequest(port, 'GET', 'with/middleware/2');
      await expectLater(responseFuture, completes);
      var response = await responseFuture;

      expect(
          response.cookies.map((e) => '${e.name}=${e.value}'),
          containsAll([
            'Middleware1=0',
            'Middleware3=1',
            'Middleware4=2',
            'counter=2'
          ]));
      expect(response.cookies, hasLength(4));

      await firecrest.close();
    });
  });

  group('Error handling', () {
    test('controllerThrowsObject_respondsWithServerError', () async {
      var controllers = <Object>[ControllerThatThrowsString()];
      var firecrest = FirecrestInternal(controllers, TestHandler());
      await firecrest.start('localhost', ++port);

      var responseFuture = _sendRequest(port, 'GET', 'i-throw-string');
      await expectLater(responseFuture, completes);
      var response = await responseFuture;
      var message = await response.transform(utf8.decoder).join();

      expect(response.statusCode, equals(HttpStatus.internalServerError));
      expect(message, equals('i throw! >:o'));

      await firecrest.close();
    });

    test('controllerThrowsServerException_respondsWithStatusFromException',
        () async {
      var controllers = <Object>[ControllerThatThrows()];
      var firecrest = FirecrestInternal(controllers, TestHandler());
      await firecrest.start('localhost', ++port);

      var responseFuture = _sendRequest(port, 'GET', 'i-throw');
      await expectLater(responseFuture, completes);
      var response = await responseFuture;
      var message = await response.transform(utf8.decoder).join();

      expect(response.statusCode, equals(HttpStatus.serviceUnavailable));
      expect(message, equals('i throw! >:o'));

      await firecrest.close();
    });

    test('controllerThrows_errorHandlerInvoked', () async {
      var errorHandler = TestHandler();
      var controllers = <Object>[ControllerThatThrows()];
      var firecrest = FirecrestInternal(controllers, errorHandler);
      await firecrest.start('localhost', ++port);

      var responseFuture = _sendRequest(port, 'GET', 'i-throw');
      await expectLater(responseFuture, completes);

      expect(errorHandler.handled, hasLength(1));

      await firecrest.close();
    });
  });
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

@Controller('i-throw-string')
class ControllerThatThrowsString {
  @RequestHandler()
  int get(HttpResponse response) {
    throw 'i throw! >:o';
  }
}

class CountingMiddleware implements Middleware {
  @override
  Future<bool> handle(HttpRequest request) async {
    var counter = int.parse(request.response.cookies
            .firstWhere((c) => c.name == 'counter',
                orElse: () => Cookie('counter', '-1'))
            .value) +
        1;

    _setCookie(request.response, 'counter', counter.toString());
    _setCookie(request.response, runtimeType.toString(), counter.toString());
    // request.session[this.runtimeType] = counter;
    // request.session['__counter'] = counter++;
    return false;
  }

  void _setCookie(HttpResponse response, String name, String value) {
    var cookie = Cookie(name, value);
    response.cookies.removeWhere((c) => c.name == name);
    response.cookies.add(cookie);
  }
}

class Middleware1 extends CountingMiddleware {}

class Middleware2 extends CountingMiddleware {}

class Middleware3 extends CountingMiddleware {}

class Middleware4 extends CountingMiddleware {}

@WithMiddleware(Middleware1, transient: true)
@WithMiddleware(Middleware2)
@Controller('with/middleware')
class ControllerWithMiddleware {}

@WithMiddleware(Middleware3)
@WithMiddleware(Middleware4)
@Controller('with/middleware/2')
class ControllerWithMiddleware2 {
  @RequestHandler()
  Future<void> get(HttpResponse response) async {
    await response.close();
  }
}

class TestHandler implements ErrorHandler {
  final handled = <HttpRequest>[];

  @override
  Future<void> handle(ServerException exception, StackTrace stackTrace,
      HttpRequest request) async {
    handled.add(request);
    request.response.statusCode = exception.status;
    request.response.write(exception.message);
    await request.response.flush();
    await request.response.close();
  }
}
