import 'package:firecrest/src/route/route.dart';

int compareRouteMatches(Route a, Route b, List<String> pathSegments) {
  var after = -1;

  while (true) {
    var aIndex = a.firstNormalMatch(pathSegments, after);
    var bIndex = b.firstNormalMatch(pathSegments, after);

    var compare = compareIndices(aIndex, bIndex);

    if (compare == null) {
      return a.compareTo(b);
    } else if (compare == 0) {
      after = aIndex!;
    } else {
      return compare;
    }
  }
}

int? compareIndices(int? a, int? b) {
  if (a == null) {
    if (b == null) {
      return null;
    }

    return 1;
  } else if (b == null) {
    return -1;
  } else {
    return a - b;
  }
}
