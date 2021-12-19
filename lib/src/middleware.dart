import 'dart:io';

abstract class Middleware {
  Future<bool> handle(HttpRequest request);
}
