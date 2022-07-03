import 'package:firecrest/src/util/type_converter.dart';
import 'package:test/test.dart';

void main() {
  group('TypeConverter.forConstants', () {
    test('defaultNameFunction_usesToStringForNames', () {
      final converter = TypeConverter.forConstants(TestConstants.values);

      for (var value in TestConstants.values) {
        expect(converter.convert(value.toString()), equals(value));
      }
    });

    test('customNameFunction_usesCustomFunctionForNames', () {
      final converter = TypeConverter<TestConstants>.forConstants(
          TestConstants.values,
          valueToName: (v) => v.name);

      for (var value in TestConstants.values) {
        expect(converter.convert(value.name), equals(value));
      }
    });

    test('invalidValues_nullReturned', () {
      final converter = TypeConverter.forConstants(TestConstants.values);
      expect(converter.convert('not a value'), isNull);
    });
  });

  group('TypeConverter.forEnums', () {
    test('validValues_returnsCorrectConstants', () {
      final converter = TypeConverter.forEnums(TestEnum.values);

      for (var value in TestEnum.values) {
        expect(converter.convert(value.name), equals(value));
      }
    });

    test('invalidValues_nullReturned', () {
      final converter = TypeConverter.forEnums(TestEnum.values);
      expect(converter.convert('not a value'), isNull);
    });
  });
}

class TestConstants {
  static const one = const TestConstants._('one');
  static const two = const TestConstants._('two');
  static const three = const TestConstants._('three');
  static const List<TestConstants> values = const [one, two, three];

  final String name;

  const TestConstants._(this.name);

  @override
  String toString() => 'TestConstants.$name';
}

enum TestEnum { one, two, three }
