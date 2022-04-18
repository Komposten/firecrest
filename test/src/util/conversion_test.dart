import 'package:firecrest/src/util/conversion.dart';
import 'package:test/test.dart';

import '../test_util/matchers.dart';

void main() {
  group('convertToType', () {
    group('int', () {
      test('validInteger_convertedToInt', () {
        var inputs = {'10': 10, '-10': -10};
        for (var input in inputs.entries) {
          var actual = convertToType(input.key, int);
          expect(actual.runtimeType, equals(int));
          expect(actual, equals(input.value));
        }
      });

      test('invalidInteger_throwsArgumentError', () {
        var inputs = ['hi', '10.0'];
        for (var input in inputs) {
          expect(
              () => convertToType(input, int),
              throwsWithMessage<ArgumentError>(
                  '$input is not a valid integer value'));
        }
      });
    });

    group('double', () {
      test('validDouble_convertedToDouble', () {
        var inputs = {
          '10': 10.0,
          '-10': -10.0,
          '10.0': 10.0,
          '2E5': 2E5,
          '2E-5': 2E-5
        };
        for (var input in inputs.entries) {
          var actual = convertToType(input.key, double);
          expect(actual.runtimeType, equals(double));
          expect(actual, equals(input.value));
        }
      });

      test('invalidDouble_throwsArgumentError', () {
        var inputs = ['hi', '10_0'];
        for (var input in inputs) {
          expect(
              () => convertToType(input, double),
              throwsWithMessage<ArgumentError>(
                  '$input is not a valid double value'));
        }
      });
    });

    group('num', () {
      test('validNum_convertedToIntOrDouble', () {
        var inputs = {
          '10': 10,
          '-10': -10,
          '10.0': 10.0,
          '2E5': 2E5,
          '2E-5': 2E-5
        };
        for (var input in inputs.entries) {
          var actual = convertToType(input.key, num);
          expect(actual.runtimeType, equals(input.value.runtimeType));
          expect(actual, equals(input.value));
        }
      });

      test('invalidNum_throwsArgumentError', () {
        var inputs = ['hi', '10_0'];
        for (var input in inputs) {
          expect(
              () => convertToType(input, num),
              throwsWithMessage<ArgumentError>(
                  '$input is not a valid numerical value'));
        }
      });
    });

    group('bool', () {
      test('false_convertedToFalse', () {
        expect(convertToType('false', bool), isFalse);
      });

      test('valueThatIsNotFalse_convertedToTrue', () {
        var inputs = ['', 'true', 'hi', '0'];
        for (var input in inputs) {
          expect(convertToType(input, bool), isTrue);
        }
      });
    });

    group('unsupported types', () {
      test('returnsOriginalString', () {
        var inputs = {'a': List, 'b': Map, 'c': Set, 'd': DateTime};
        for (var input in inputs.entries) {
          expect(convertToType(input.key, input.value), equals(input.key));
        }
      });
    });
  });
}
