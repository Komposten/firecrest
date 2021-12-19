import 'package:test/test.dart';

Matcher throwsWithMessage<T>(String message) {
  if (T == ArgumentError) {
    return throwsA(
        predicate((e) => e is ArgumentError && e.message == message));
  } else if (T == StateError) {
    return throwsA(predicate((e) => e is StateError && e.message == message));
  } else {
    throw ArgumentError('Unknown error type: $T');
  }
}
