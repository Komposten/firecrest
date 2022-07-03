import 'package:firecrest/src/query_parameter.dart';
import 'package:firecrest/src/server_exception.dart';
import 'package:firecrest/src/util/conversion.dart';
import 'package:firecrest/src/util/query_parameters.dart';
import 'package:test/test.dart';

import '../test_util/matchers.dart';

void main() {
  var defined = {
    'param1': QueryParameter(String, 'param1', false),
    'param2': QueryParameter(int, 'param2', true),
    'param3': QueryParameter(double, 'param3', false),
    'param4': QueryParameter(String, 'param4', true),
  };

  group('assertRequiredQueryParameters', () {
    test('missingRequiredParameter_throwsServerException', () {
      var provided = {
        'param1': '1',
        'param3': '3',
      };
      expect(
          () => assertRequiredQueryParameters(provided, defined),
          throwsWithMessage<ServerException>(
              'Missing required query parameters: [param2, param4]'));

      provided['param2'] = '2';
      expect(
          () => assertRequiredQueryParameters(provided, defined),
          throwsWithMessage<ServerException>(
              'Missing required query parameters: [param4]'));
    });

    test('allRequiredParametersPresent_returnsNormally', () {
      var provided = {
        'param1': '1',
        'param2': '2',
        'param3': '3',
        'param4': '4',
      };

      expect(() => assertRequiredQueryParameters(provided, defined),
          returnsNormally);
    });
  });

  group('removeUnknownParameters', () {
    test('unknownParameters_onlyUnknownRemoved', () {
      var provided = {
        'param0': '1',
        'param2': '2',
        'param3': '3',
        'param5': '4',
        'param6': '5',
      };

      removeUnknownParameters(provided, defined);
      expect(provided, equals({'param2': '2', 'param3': '3'}));
    });
  });

  group('convertQueryParameters', () {
    test('differentParameterTypes_convertedToCorrectType', () {
      var conversion = Conversion();
      var provided = {
        'param1': '1',
        'param2': '2',
        'param3': '3',
        'param4': '4',
      };

      var actual = convertQueryParameters(provided, defined, conversion);
      expect(actual,
          equals({'param1': '1', 'param2': 2, 'param3': 3.0, 'param4': '4'}));
    });
  });
}
