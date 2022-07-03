class TypeConverter<T> {
  final Type type;
  late final T? Function(String) convert;
  final String? humanReadableName;

  /// Creates a converter for a specific type.
  ///
  /// [convert] should be a function that takes a String and converts it into an
  /// object of the type given by [type]. If the input is invalid, the converter
  /// should return `null` rather than throw.
  /// A [humanReadableName] can optionally be provided for use in error messages.
  /// For example, the default TypeConverter for int has the human-readable name
  /// 'integer'.
  TypeConverter(this.convert, {this.humanReadableName}) : type = T;

  /// Creates a converter for a set of constant values.
  ///
  /// The converter will convert a String to one of the provided values based on
  /// a "name" derived from the value. By default the converter will use
  /// `toString()` to derive the names. If a different representation/name is
  /// necessary, specify a [valueToName] function.
  TypeConverter.forConstants(Iterable<T> values,
      {String Function(T)? valueToName, this.humanReadableName})
      : type = T {
    valueToName = valueToName ?? (v) => v.toString();
    final nameToValue = Map<String, T>.fromIterable(values,
        key: (v) => valueToName!(v), value: (v) => v);
    convert = (v) => nameToValue[v];
  }

  /// Creates a converter for a set of enum constants.
  ///
  /// The converter will convert a String to one of the provided enum constants
  /// based on their names..
  TypeConverter.forEnums(Iterable<T> values, {String? humanReadableName})
      : this.forConstants(values,
            valueToName: (v) =>
                v.toString().substring(v.toString().lastIndexOf('.') + 1),
            humanReadableName: humanReadableName);
}
