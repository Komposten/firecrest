final _converters = {
  int: int.tryParse,
  double: double.tryParse,
  num: num.tryParse,
  bool: (v) => v != 'false',
  String: (v) => v,
  dynamic: (v) => v
};

final _typeToName = {
  int: 'integer',
  num: 'numerical',
  bool: 'boolean',
};

Set<Type> get convertibleTypes => _converters.keys.toSet();

Object convertToType(String string, Type type) {
  Object? result;

  var converter = _converters[type];
  if (converter == null) {
    throw UnsupportedTypeError(type,
        'No converter exists for converting String to $type. Supported types: ${_converters.keys.join(', ')}');
  }

  result = converter.call(string);
  if (result == null) {
    final typeName = _typeToName[type] ?? type.toString();
    throw ArgumentError('$string is not a valid $typeName value');
  }

  return result;
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
