import 'dart:io';
import 'dart:mirrors';

import 'package:firecrest/firecrest.dart';
import 'package:firecrest/src/query_parameter.dart';
import 'package:firecrest/src/route/route.dart';
import 'package:firecrest/src/route/segment.dart';
import 'package:firecrest/src/util/meta.dart';
import 'package:firecrest/src/util/query_parameters.dart';
import 'package:firecrest/src/validation/method_validator.dart';
import 'package:meta/meta.dart';

class ControllerReference {
  final String name;
  final Object controller;
  final Route route;
  final InstanceMirror _instanceMirror;
  late final Map<Symbol, MethodMirror> _handlers;
  late final Map<Symbol, Map<String, QueryParameter>> _queryParameters;

  ControllerReference.forController(this.controller, this.route)
      : name = controller.runtimeType.toString(),
        _instanceMirror = reflect(controller) {
    _extractMethodHandlers();
  }

  void _extractMethodHandlers() {
    var mirror = _instanceMirror.type;
    var handlers = <Symbol, MethodMirror>{};
    var queryParameters = <Symbol, Map<String, QueryParameter>>{};

    var handlerMethods = {...mirror.instanceMembers}
      ..removeWhere((symbol, mirror) => !hasMetaOfType<RequestHandler>(mirror));

    handlerMethods.forEach((symbol, method) {
      symbol = _getRequestMethod(method);

      if (!handlers.containsKey(symbol)) {
        handlers[symbol] = method;
        queryParameters[symbol] = _extractQueryParameters(method);
      } else {
        throw StateError(
            'Multiple handlers detected for method "${MirrorSystem.getName(symbol)}"');
      }
    });

    _validateMethodHandlers(handlers);

    _handlers = Map.unmodifiable(handlers);
    _queryParameters = Map.unmodifiable(queryParameters);
  }

  Symbol _getRequestMethod(MethodMirror method) {
    var methodHandlerMeta = firstMetaOfType<RequestHandler>(mirror: method)!;
    if (methodHandlerMeta.hasCustomMethod) {
      return Symbol(methodHandlerMeta.method!.toLowerCase());
    } else {
      return Symbol(MirrorSystem.getName(method.simpleName).toLowerCase());
    }
  }

  Map<String, QueryParameter> _extractQueryParameters(MethodMirror method) {
    var parameters = method.parameters.skip(1).toList();
    var pathParameters = route.parameters.keys;

    var result = <String, QueryParameter>{};
    for (var parameter in parameters) {
      var name = MirrorSystem.getName(parameter.simpleName);

      if (!pathParameters.contains(name)) {
        result[name] = QueryParameter(
            parameter.type.reflectedType, name, !parameter.hasDefaultValue);
      }
    }

    return result;
  }

  void _validateMethodHandlers(Map<Symbol, MethodMirror> handlers) {
    var errors = <String>[];

    for (var entry in handlers.entries) {
      var handler = entry.value;

      var pathParameters = route.parameters
          .map((name, type) => MapEntry(name, toParameterType(type)));

      try {
        MethodValidator.requirePositionalParameterOfType(handler, HttpResponse,
            index: 0);
        MethodValidator.requireNamedParameters(handler, pathParameters);
        MethodValidator.requireOnlyNamedParameters(handler, skip: 1);
      } on ArgumentError catch (e) {
        errors.add(e.message);
      }
    }

    if (errors.isNotEmpty) {
      throw ArgumentError(
          '${controller.runtimeType} has invalid handlers:\n${errors.join('\n')}');
    }
  }

  /// Invokes the handler for the specified [method] with the provided parameters.
  ///
  /// Returns `true` if there was a handler for the specified [method], `false`
  /// otherwise.
  Future<bool> invoke(
      Symbol method,
      HttpResponse response,
      Map<String, dynamic> pathParameters,
      Map<String, String> queryParameters) async {
    var named = <Symbol, dynamic>{};
    var handler = _handlers[method];

    if (handler != null) {
      var cleanedQueryParameters =
          _validateAndCleanQueryParameters(queryParameters, method);

      pathParameters.forEach((name, value) => named[Symbol(name)] = value);
      cleanedQueryParameters
          .forEach((name, value) => named[Symbol(name)] = value);

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

  Map<String, Object> _validateAndCleanQueryParameters(
      Map<String, String> queryParameters, Symbol method) {
    queryParameters = Map.of(queryParameters);
    assertRequiredQueryParameters(queryParameters, _queryParameters[method]!);
    removeUnknownParameters(queryParameters, _queryParameters[method]!);
    return convertQueryParameters(queryParameters, _queryParameters[method]!);
  }

  bool canHandle(Symbol method) => _handlers.containsKey(method);

  InstanceMirror get mirror => _instanceMirror;

  Set<Symbol> get supportedMethods => _handlers.keys.toSet();

  Map<Symbol, MethodMirror> get requestHandlers => _handlers;

  @visibleForTesting
  Map<Symbol, Map<String, QueryParameter>> get queryParameters =>
      _queryParameters;
}
