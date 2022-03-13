import 'dart:io';
import 'dart:mirrors';

import 'package:firecrest/src/annotations/request_handler.dart';
import 'package:firecrest/src/util/meta.dart';

class ControllerReference {
  final String name;
  final Object controller;
  final InstanceMirror _instanceMirror;
  late final Map<Symbol, MethodMirror> _handlers;

  ControllerReference.forController(Object controller)
      : name = controller.runtimeType.toString(),
        controller = controller,
        _instanceMirror = reflect(controller) {
    _extractMethodHandlers();
  }

  void _extractMethodHandlers() {
    var mirror = _instanceMirror.type;
    var handlers = <Symbol, MethodMirror>{};

    var handlerMethods = {...mirror.instanceMembers}
      ..removeWhere((symbol, mirror) => !hasMetaOfType<RequestHandler>(mirror));

    handlerMethods.forEach((symbol, method) {
      symbol = _getRequestMethod(method);

      if (!handlers.containsKey(symbol)) {
        handlers[symbol] = method;
      } else {
        throw StateError(
            'Multiple handlers detected for method "${MirrorSystem.getName(symbol)}"');
      }
    });

    _handlers = Map.unmodifiable(handlers);
  }

  Symbol _getRequestMethod(MethodMirror method) {
    var methodHandlerMeta = firstMetaOfType<RequestHandler>(mirror: method)!;
    if (methodHandlerMeta.hasCustomMethod) {
      return Symbol(methodHandlerMeta.method!.toLowerCase());
    } else {
      return Symbol(MirrorSystem.getName(method.simpleName).toLowerCase());
    }
  }

  Future<bool> invoke(
      Symbol method,
      HttpResponse response,
      Map<String, dynamic> pathParameters,
      Map<String, dynamic> queryParameters) async {
    var named = <Symbol, dynamic>{};
    var handler = _handlers[method];

    if (handler != null) {
      pathParameters.forEach((name, value) => named[Symbol(name)] = value);
      queryParameters.forEach((name, value) => named[Symbol(name)] = value);

      var invocation =
          _instanceMirror.invoke(handler.simpleName, [response], named);
      if (invocation.hasReflectee) {
        await invocation.reflectee;
      }

      return true;
    } else {
      return false;
    }
  }

  bool canHandle(Symbol method) => _handlers.containsKey(method);

  InstanceMirror get mirror => _instanceMirror;

  Set<Symbol> get supportedMethods => _handlers.keys.toSet();

  Map<Symbol, MethodMirror> get requestHandlers => _handlers;
}
