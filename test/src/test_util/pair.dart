class Pair<A, B> {
  final A a;
  final B b;

  const Pair(this.a, this.b);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Pair &&
          runtimeType == other.runtimeType &&
          a == other.a &&
          b == other.b;

  @override
  int get hashCode => a.hashCode ^ b.hashCode;

  @override
  String toString() {
    return 'Pair{a: $a, b: $b}';
  }
}
