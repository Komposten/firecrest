import 'package:firecrest/src/util/conversion.dart';
import 'package:firecrest/src/util/type_converter.dart';
import 'package:test/test.dart';

import '../test_util/matchers.dart';

void main() {
  late Conversion conversion;
  setUp(() => conversion = new Conversion());

  group('convertToType', () {
    group('int', () {
      test('validInteger_convertedToInt', () {
        var inputs = {'10': 10, '-10': -10};
        for (var input in inputs.entries) {
          var actual = conversion.convertToType(input.key, int);
          expect(actual.runtimeType, equals(int));
          expect(actual, equals(input.value));
        }
      });

      test('invalidInteger_throwsArgumentError', () {
        var inputs = ['hi', '10.0'];
        for (var input in inputs) {
          expect(
              () => conversion.convertToType(input, int),
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
          var actual = conversion.convertToType(input.key, double);
          expect(actual.runtimeType, equals(double));
          expect(actual, equals(input.value));
        }
      });

      test('invalidDouble_throwsArgumentError', () {
        var inputs = ['hi', '10_0'];
        for (var input in inputs) {
          expect(
              () => conversion.convertToType(input, double),
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
          var actual = conversion.convertToType(input.key, num);
          expect(actual.runtimeType, equals(input.value.runtimeType));
          expect(actual, equals(input.value));
        }
      });

      test('invalidNum_throwsArgumentError', () {
        var inputs = ['hi', '10_0'];
        for (var input in inputs) {
          expect(
              () => conversion.convertToType(input, num),
              throwsWithMessage<ArgumentError>(
                  '$input is not a valid numerical value'));
        }
      });
    });

    group('bool', () {
      test('false_convertedToFalse', () {
        expect(conversion.convertToType('false', bool), isFalse);
      });

      test('valueThatIsNotFalse_convertedToTrue', () {
        var inputs = ['', 'true', 'hi', '0'];
        for (var input in inputs) {
          expect(conversion.convertToType(input, bool), isTrue);
        }
      });
    });

    group('custom', () {
      test('noTypeConverter_throwsException', () {
        var inputs = {'a': List, 'b': Map, 'c': Set, 'd': DateTime};
        for (var input in inputs.entries) {
          expect(
              () => conversion.convertToType(input.key, input.value),
              throwsWithMessage<UnsupportedTypeError>(
                  'No converter exists for converting String to ${input.value}. Supported types: ${conversion.convertibleTypes.join(', ')}'));
        }
      });

      test('customTypeConverter_convertedCorrectly', () {
        conversion.addConverter(TypeConverter<List>((v) => v.split(',')));
        conversion
            .addConverter(TypeConverter<Set>((v) => v.split(',').toSet()));
        conversion.addConverter(TypeConverter<DateTime>(DateTime.tryParse));
        conversion.addConverter(TypeConverter<Map>(
          (v) => <String, String>{}..addEntries(v
              .split(',')
              .map((e) => e.split(':'))
              .map((e) => MapEntry(e[0], e[1]))),
        ));

        var inputs = {
          'a,b': List,
          'a:b,c:d': Map,
          'c,d': Set,
          '2022-01-01': DateTime
        };
        var expected = {
          'a,b': ['a', 'b'],
          'a:b,c:d': {'a': 'b', 'c': 'd'},
          'c,d': {'c', 'd'},
          '2022-01-01': DateTime(2022, 01, 01)
        };
        for (var input in inputs.entries) {
          expect(conversion.convertToType(input.key, input.value),
              equals(expected[input.key]));
        }
      });
    });
  });
}
