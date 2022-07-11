import 'dart:io';

import 'package:firecrest/src/server_exception.dart';

abstract class ErrorHandler {
  Future<void> handle(
      ServerException exception, StackTrace stacktrace, HttpRequest request);
}
