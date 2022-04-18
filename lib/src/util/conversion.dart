Object convertToType(String string, Type type) {
  Object? result;

  if (type == int) {
    result = int.tryParse(string);
    if (result == null) {
      throw ArgumentError('$string is not a valid integer value');
    }
  } else if (type == double) {
    result = double.tryParse(string);
    if (result == null) {
      throw ArgumentError('$string is not a valid double value');
    }
  } else if (type == num) {
    result = num.tryParse(string);
    if (result == null) {
      throw ArgumentError('$string is not a valid numerical value');
    }
  } else if (type == bool) {
    result = string != 'false';
  } else {
    result = string;
  }

  return result;
}
