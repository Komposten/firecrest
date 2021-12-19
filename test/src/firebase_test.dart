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
              'Two controllers registered for path user: ControllerUser and ControllerUser'));

      controllers = [ControllerUser(), ControllerWild()];
      expect(
          () => Firecrest(controllers, TestHandler()),
          throwsWithMessage<StateError>(
              'Two controllers registered for path user: ControllerUser and ControllerWild'));
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

  /* TEST jhj:
      - Middleware added in correct order
      - Middleware run in order before controller
      - ErrorHandler receives 404 if controller cannot handle request method
      - ErrorHandler receives 404 if no controller exists for request route
      - ErrorHandler receives 500 if controller throws random object
      - ErrorHandler called if controller throws.
   */
}

class ControllerNoMeta {}

@Controller('user')
class ControllerUser {}

@Controller(':wild')
class ControllerWild {}

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

class TestHandler implements ErrorHandler {
  final handled = <HttpRequest>[];

  @override
  Future<void> handle(ServerException exception, HttpRequest request) async {
    handled.add(request);
  }
}
