import 'dart:io';

import 'package:firecrest/firecrest.dart';
import 'package:firecrest/src/controller_reference.dart';
import 'package:firecrest/src/query_parameter.dart';
import 'package:test/test.dart';

import 'test_util/matchers.dart';
import 'test_util/mock_response.dart';
import 'test_util/pair.dart';

void main() {
  group('name', () {
    test('setToClassName', () {
      var controller = ControllerWithBasicMethods();
      var reference =
          ControllerReference.forController(controller, controller.route);
      expect(reference.name, equals('ControllerWithBasicMethods'));
    });
  });

  group('Request handler detection', () {
    test('multipleHandlers_allRegistered', () {
      var controller = ControllerWithBasicMethods();
      var reference =
          ControllerReference.forController(controller, controller.route);
      var handlers = reference.requestHandlers;

      expect(
          handlers.entries
              .map((entry) => Pair(entry.key, entry.value.simpleName)),
          unorderedEquals([
            Pair(Symbol('get'), Symbol('get')),
            Pair(Symbol('post'), Symbol('post'))
          ]));
    });

    test('handlersWithCustomMethods_customMethodNamesAreUsed', () {
      var controller = ControllerWithCustomMethods();
      var reference =
          ControllerReference.forController(controller, controller.route);
      var handlers = reference.requestHandlers;

      expect(
          handlers.entries
              .map((entry) => Pair(entry.key, entry.value.simpleName)),
          unorderedEquals([
            Pair(Symbol('get'), Symbol('retrieve')),
            Pair(Symbol('post'), Symbol('save')),
            Pair(Symbol('mail'), Symbol('post')),
            Pair(Symbol('delete'), Symbol('delete'))
          ]));
    });

    test('handlersWithDuplicateMethods_throwsError', () {
      var controller = ControllerWithDuplicateMethods();
      expect(
          () => ControllerReference.forController(controller, controller.route),
          throwsWithMessage<StateError>(
              'Multiple handlers detected for method "get"'));
    });
  });

  group('Request handler validation', () {
    test('noResponseParameter_throwsArgumentError', () {
      Controller controller = ControllerNoParameters();
      expect(
          () => ControllerReference.forController(controller, controller.route),
          throwsWithMessage<ArgumentError>(
              'ControllerNoParameters has invalid handlers:\n"get" must have a(n) HttpResponse as positional parameter at index 0'));

      controller = ControllerNoResponseParameter();
      expect(
          () => ControllerReference.forController(controller, controller.route),
          throwsWithMessage<ArgumentError>(
              'ControllerNoResponseParameter has invalid handlers:\n"get" must have a(n) HttpResponse as positional parameter at index 0'));
    });

    test('complexValidController_passesValidation', () {
      var controller = ControllerWithEverything();
      expect(
          () => ControllerReference.forController(controller, controller.route),
          returnsNormally);
    });

    test('missingPathParameter_throwsArgumentError', () {
      var controller = ControllerMissingPathParameter();
      var expectedMessage =
          'ControllerMissingPathParameter has invalid handlers:\n' +
              '"post" is missing one or more named parameters: {params}\n' +
              '"patch" is missing one or more named parameters: {has}';

      expect(
          () => ControllerReference.forController(controller, controller.route),
          throwsWithMessage<ArgumentError>(expectedMessage));
    });

    test('incorrectPathParameterTypes_throwsArgumentError', () {
      Controller controller = ControllerIncorrectBasicPathParameter();
      var expectedMessage =
          'ControllerIncorrectBasicPathParameter has invalid handlers:\n' +
              '"post" has named parameters with incorrect types. They should be: {has: String}\n' +
              '"patch" has named parameters with incorrect types. They should be: {params: List<String>}';
      expect(
          () => ControllerReference.forController(controller, controller.route),
          throwsWithMessage<ArgumentError>(expectedMessage));
    });

    test('unnamedParameters_throwsArgumentError', () {
      var controller = ControllerUnnamedParameters();
      var expectedMessage =
          'ControllerUnnamedParameters has invalid handlers:\n' +
              '"get" may only have 1 unnamed parameters\n' +
              '"post" may only have 1 unnamed parameters';
      expect(
          () => ControllerReference.forController(controller, controller.route),
          throwsWithMessage<ArgumentError>(expectedMessage));
    });
  });

  group('Query parameter extraction', () {
    test('withQueryParameters_extractedCorrectly', () {
      var controller = ControllerWithEverything();
      var reference =
          ControllerReference.forController(controller, controller.route);

      var actual = reference.queryParameters;

      expect(actual.keys, containsAll([Symbol('get'), Symbol('post')]));
      expect(actual[Symbol('get')]!,
          equals({'other': QueryParameter(dynamic, 'other', false)}));
      expect(
          actual[Symbol('post')]!,
          equals({
            'id': QueryParameter(String, 'id', true),
            'overwrite': QueryParameter(dynamic, 'overwrite', false),
            'timestamp': QueryParameter(int, 'timestamp', false)
          }));
    });
  });

  group('Query parameter validation', () {
    test('unknownParameters_handlerInvokedCorrectly', () async {
      var controller = ControllerWithQueryParameters();
      var reference =
          ControllerReference.forController(controller, controller.route);
      var query = {'name': 'bob', 'count': '5', 'id': '123', 'date': 'now'};

      await expectLater(
          reference.invoke(Symbol('get'), MockResponse(), {}, query),
          completes);
    });

    test('missingRequiredParameter_throwsServerException', () async {
      var controller = ControllerWithQueryParameters();
      var reference =
          ControllerReference.forController(controller, controller.route);
      var query = {'count': '5'};

      await expectLater(
          reference.invoke(Symbol('get'), MockResponse(), {}, query),
          throwsWithMessage<ServerException>(
              'Missing required query parameters: [name]'));
    });

    test('correctParameters_handlerInvokedCorrectly', () async {
      var controller = ControllerWithQueryParameters();
      var reference =
          ControllerReference.forController(controller, controller.route);
      var query = {'name': 'bob', 'count': '5'};

      await expectLater(
          reference.invoke(Symbol('get'), MockResponse(), {}, query),
          completes);
      expect(controller.name, equals('bob'));
      expect(controller.count, equals(5));
    });
  });

  group('invoke', () {
    test('handlerWithEverything_invokedCorrectly', () async {
      var controller = ControllerWithEverything();
      var reference =
          ControllerReference.forController(controller, controller.route);
      var path = {
        'wild': 'path1',
        'here': ['path2', 'path3']
      };
      var query = {'id': 'bob', 'timestamp': '5'};

      await expectLater(
          reference.invoke(Symbol('post'), MockResponse(), path, query),
          completes);
      expect(controller.wild, 'path1');
      expect(controller.here, ['path2', 'path3']);
      expect(controller.id, equals('bob'));
      expect(controller.overwrite, equals(false));
      expect(controller.timestamp, equals(5));
    });
  });
}

class ControllerWithBasicMethods extends Controller {
  ControllerWithBasicMethods() : super('');

  @RequestHandler()
  void get(HttpResponse response) {}

  @RequestHandler()
  void post(HttpResponse response) {}
}

class ControllerWithCustomMethods extends Controller {
  ControllerWithCustomMethods() : super('');

  @RequestHandler(method: 'get')
  void retrieve(HttpResponse response) {}

  @RequestHandler(method: 'post')
  void save(HttpResponse response) {}

  @RequestHandler(method: 'mail')
  void post(HttpResponse response) {}

  @RequestHandler()
  void delete(HttpResponse response) {}
}

class ControllerWithDuplicateMethods extends Controller {
  ControllerWithDuplicateMethods() : super('');

  @RequestHandler(method: 'get')
  void retrieve(HttpResponse response) {}

  @RequestHandler()
  void get(HttpResponse response) {}
}

class ControllerNoParameters extends Controller {
  ControllerNoParameters() : super('no-parameters');

  @RequestHandler()
  int get() {
    return 1;
  }
}

class ControllerNoResponseParameter extends Controller {
  ControllerNoResponseParameter() : super('no-response-parameter');

  @RequestHandler()
  String get(String name, {count = 2}) {
    return '$name: $count';
  }
}

class ControllerMissingPathParameter extends Controller {
  ControllerMissingPathParameter() : super(':has/:params');

  @RequestHandler()
  void get(HttpResponse response,
      {required String has, required String params, required String id}) {}

  @RequestHandler()
  void post(HttpResponse response, {required String has, required String id}) {}

  @RequestHandler()
  void patch(HttpResponse response,
      {required String params, required String id}) {}
}

class ControllerIncorrectBasicPathParameter extends Controller {
  ControllerIncorrectBasicPathParameter() : super(':has/::params');

  @RequestHandler()
  void get(HttpResponse response,
      {required String has,
      required List<String> params,
      required String id}) {}

  @RequestHandler()
  void post(HttpResponse response,
      {required int has, required List<String> params, required String id}) {}

  @RequestHandler()
  void patch(HttpResponse response,
      {required String has, required String params, required String id}) {}
}

class ControllerUnnamedParameters extends Controller {
  ControllerUnnamedParameters() : super('unnamed-parameters');

  @RequestHandler()
  void get(HttpResponse response, [String? param1, String? param2]) {}

  @RequestHandler()
  void post(HttpResponse response, String param1, String param2) {}
}

class ControllerWithEverything extends Controller {
  String? wild;
  List<String>? here;
  String? id;
  dynamic overwrite;
  int? timestamp;

  ControllerWithEverything() : super(':wild/path/::here');

  @RequestHandler()
  void get(HttpResponse response,
      {required String wild, required List<String> here, other = 'hi'}) {}

  @RequestHandler(method: 'post')
  void save(HttpResponse response,
      {required String wild,
      required List<String> here,
      required String id,
      overwrite = false,
      int timestamp = -1}) {
    this.wild = wild;
    this.here = here;
    this.id = id;
    this.overwrite = overwrite;
    this.timestamp = timestamp;
  }
}

class ControllerWithQueryParameters extends Controller {
  String? name;
  int? count;

  ControllerWithQueryParameters() : super('with-query-parameters');

  @RequestHandler()
  void get(HttpResponse response, {required String name, int count = 2}) {
    this.name = name;
    this.count = count;
  }
}
