class Segment implements Comparable<Segment> {
  final String name;
  final SegmentType type;

  Segment(this.name, this.type);

  @override
  String toString() {
    var prefix = '';

    if (type == SegmentType.superWild) {
      prefix = '::';
    } else if (type == SegmentType.basicWild) {
      prefix = ':';
    }

    return '$prefix$name';
  }

  /// Checks if this segment overlaps with another one.
  ///
  /// Two segments overlap if:
  ///   1. Both are [SegmentType.normal] segments and have the same [name].
  ///   2. Both are segments are any type of wild.
  bool overlapsWith(Segment other) =>
      identical(this, other) ||
      runtimeType == other.runtimeType &&
          ((name == other.name && !isAnyWild && !other.isAnyWild) ||
              (isAnyWild && other.isAnyWild));

  bool get isAnyWild => isBasicWild || isSuperWild;

  bool get isBasicWild => type == SegmentType.basicWild;

  bool get isSuperWild => type == SegmentType.superWild;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Segment &&
          runtimeType == other.runtimeType &&
          (name == other.name || (isAnyWild && other.isAnyWild));

  @override
  int get hashCode {
    if (isAnyWild) {
      return '*'.hashCode;
    } else {
      return name.hashCode;
    }
  }

  @override
  int compareTo(Segment other) {
    if (isAnyWild || other.isAnyWild) {
      return 0;
    } else {
      return name.compareTo(other.name);
    }
  }
}

Type toParameterType(SegmentType segmentType) {
  switch (segmentType) {
    case SegmentType.basicWild:
      return String;
    case SegmentType.superWild:
      return <String>[].runtimeType;
    default:
      throw ArgumentError('$segmentType does not have a parameter mapping');
  }
}

enum SegmentType { normal, basicWild, superWild }
