import 'dart:mirrors';

import 'package:firecrest/src/query_parameter.dart';
import 'package:firecrest/src/util/conversion.dart';

abstract class MethodValidator {
  MethodValidator._();

  static void requirePositionalParameterOfType(MethodMirror handler, Type type,
      {required index}) {
    index = (index < 0 ? 0 : index);

    var isValid = true;
    if (index >= handler.parameters.length) {
      isValid = false;
    } else {
      var parameter = handler.parameters[index];

      if (parameter.isNamed ||
          parameter.isOptional ||
          !parameter.type.hasReflectedType ||
          parameter.type.reflectedType != type) {
        isValid = false;
      }
    }

    if (!isValid) {
      throw ArgumentError(
          '"${MirrorSystem.getName(handler.simpleName)}" must have a(n) $type as positional parameter at index $index');
    }
  }

  static void requireNamedParameters(
      MethodMirror handler, Map<String, Type> parameters) {
    var handlerParameters = handler.parameters
        .map((e) => MirrorSystem.getName(e.simpleName))
        .toSet();

    var missing = parameters.keys.toSet().difference(handlerParameters);
    if (missing.isNotEmpty) {
      throw ArgumentError(
          '"${MirrorSystem.getName(handler.simpleName)}" is missing one or more named parameters: $missing');
    }

    var wrongType = <String, Type>{};
    for (var parameter in parameters.entries) {
      var name = parameter.key;
      var expectedType = parameter.value;

      var typeMirror = handler.parameters
          .firstWhere((p) => MirrorSystem.getName(p.simpleName) == name)
          .type;
      var type = typeMirror.hasReflectedType ? typeMirror.reflectedType : null;

      if (type != expectedType) {
        wrongType[name] = expectedType;
      }
    }
    if (wrongType.isNotEmpty) {
      throw ArgumentError(
          '"${MirrorSystem.getName(handler.simpleName)}" has named parameters with incorrect types. They should be: $wrongType');
    }
  }

  static void requireOnlyNamedParameters(MethodMirror handler,
      {required int skip}) {
    if (!handler.parameters.skip(skip).every((p) => p.isNamed)) {
      if (skip == 0) {
        throw ArgumentError(
            '"${MirrorSystem.getName(handler.simpleName)}" may not have any unnamed parameters');
      } else {
        throw ArgumentError(
            '"${MirrorSystem.getName(handler.simpleName)}" may only have $skip unnamed parameters');
      }
    }
  }

  static void requireSupportedQueryParameterTypes(MethodMirror handler,
      Conversion typeConversion, Iterable<QueryParameter> parameters) {
    var withUnsupportedTypes = parameters
        .where((parameter) =>
            !typeConversion.convertibleTypes.contains(parameter.type))
        .map((parameter) => '${parameter.name} (${parameter.type})')
        .toList();

    if (withUnsupportedTypes.isNotEmpty) {
      var methodName = MirrorSystem.getName(handler.simpleName);
      throw ArgumentError(
          '"$methodName" has query parameters of unsupported types: ${withUnsupportedTypes.join(', ')}. '
          'Supported types: ${typeConversion.convertibleTypes.join(', ')}');
    }
  }
}
