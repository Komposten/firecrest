import 'dart:io';

import 'package:firecrest/firecrest.dart';
import 'package:firecrest/src/query_parameter.dart';
import 'package:firecrest/src/util/conversion.dart';

void assertRequiredQueryParameters(Map<String, String> providedParameters,
    Map<String, QueryParameter> definedParameters) {
  var required = definedParameters.values.where((v) => v.required);

  var missing = <String>[];
  for (var parameter in required) {
    if (!providedParameters.containsKey(parameter.name)) {
      missing.add(parameter.name);
    }
  }

  if (missing.isNotEmpty) {
    throw ServerException(
        HttpStatus.badRequest, 'Missing required query parameters: $missing');
  }
}

void removeUnknownParameters(Map<String, String> providedParameters,
    Map<String, QueryParameter> definedParameters) {
  var known = definedParameters.keys;
  providedParameters.removeWhere((name, _) => !known.contains(name));
}

Map<String, Object> convertQueryParameters(
    Map<String, String> providedParameters,
    Map<String, QueryParameter> definedParameters,
    Conversion typeConversion) {
  var converted = <String, Object>{};

  try {
    for (var entry in providedParameters.entries) {
      var name = entry.key;
      var value = entry.value;
      var type = definedParameters[name]!.type;
      converted[name] = typeConversion.convertToType(value, type);
    }
  } on ArgumentError catch (e) {
    throw new ServerException(HttpStatus.badRequest, e.message);
  }

  return converted;
}
