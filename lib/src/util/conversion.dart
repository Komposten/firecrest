import 'package:firecrest/src/util/type_converter.dart';

class Conversion {
  final _converters = {
    int: TypeConverter<int>(int.tryParse, humanReadableName: 'integer'),
    double: TypeConverter<double>(double.tryParse, humanReadableName: 'double'),
    num: TypeConverter<num>(num.tryParse, humanReadableName: 'numerical'),
    bool: TypeConverter<bool>((v) => v != 'false'),
    String: TypeConverter<String>((v) => v),
    dynamic: TypeConverter<dynamic>((v) => v)
  };

  void addConverter(TypeConverter converter) {
    _converters[converter.type] = converter;
  }

  Set<Type> get convertibleTypes => _converters.keys.toSet();

  Object convertToType(String string, Type type) {
    Object? result;

    var converter = _converters[type];
    if (converter == null) {
      throw UnsupportedTypeError(type,
          'No converter exists for converting String to $type. Supported types: ${_converters.keys.join(', ')}');
    }

    result = converter.convert(string);
    if (result == null) {
      final typeName = converter.humanReadableName ?? type.toString();
      throw ArgumentError('$string is not a valid $typeName value');
    }

    return result;
  }
}

class UnsupportedTypeError extends Error {
  final type;
  final message;

  UnsupportedTypeError(this.type, this.message);

  @override
  String toString() {
    return 'Unsupported type ($type): $message';
  }
}
