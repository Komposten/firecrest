class QueryParameter {
  final Type type;
  final String name;
  final bool required;

  QueryParameter(this.type, this.name, this.required);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QueryParameter &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          name == other.name &&
          required == other.required;

  @override
  int get hashCode => type.hashCode ^ name.hashCode ^ required.hashCode;

  @override
  String toString() => '$name{$type, ${required ? 'required' : 'optional'}}';
}
