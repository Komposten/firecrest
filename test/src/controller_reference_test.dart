import 'package:firecrest/src/annotations/request_handler.dart';
import 'package:firecrest/src/controller_reference.dart';
import 'package:test/test.dart';

import 'test_util/matchers.dart';
import 'test_util/pair.dart';

void main() {
  group('name', () {
    test('setToClassName', () {
      var reference =
          ControllerReference.forController(ControllerWithBasicMethods());
      expect(reference.name, equals('ControllerWithBasicMethods'));
    });
  });

  group('requestHandlers', () {
    test('multipleHandlers_allRegistered', () {
      var reference =
          ControllerReference.forController(ControllerWithBasicMethods());
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
      var reference =
          ControllerReference.forController(ControllerWithCustomMethods());
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
      expect(
          () => ControllerReference.forController(
              ControllerWithDuplicateMethods()),
          throwsWithMessage<StateError>(
              'Multiple handlers detected for method "get"'));
    });
  });

  // TEST jhj: invoke()
}

class ControllerWithBasicMethods {
  @RequestHandler()
  void get() {}

  @RequestHandler()
  void post() {}
}

class ControllerWithCustomMethods {
  @RequestHandler(method: 'get')
  void retrieve() {}

  @RequestHandler(method: 'post')
  void save() {}

  @RequestHandler(method: 'mail')
  void post() {}

  @RequestHandler()
  void delete() {}
}

class ControllerWithDuplicateMethods {
  @RequestHandler(method: 'get')
  void retrieve() {}

  @RequestHandler()
  void get() {}
}
