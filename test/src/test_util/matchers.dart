import 'package:test/test.dart';

Matcher throwsWithMessage<T>(String message,
    [String Function(dynamic) getMessage = _getMessage]) {
  return throwsA(predicate((e) => e is T && getMessage(e) == message,
      '$T with the message: $message'));
}

String _getMessage(e) => e.message;
