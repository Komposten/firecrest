import 'dart:convert';
import 'dart:io';

class MockResponse extends HttpResponse {
  @override
  Encoding encoding = utf8;

  @override
  void add(List<int> data) => throw UnsupportedError('unsupported operation');

  @override
  void addError(Object error, [StackTrace? stackTrace]) =>
      throw UnsupportedError('unsupported operation');

  @override
  Future addStream(Stream<List<int>> stream) =>
      throw UnsupportedError('unsupported operation');

  @override
  Future close() => throw UnsupportedError('unsupported operation');

  @override
  HttpConnectionInfo? get connectionInfo =>
      throw UnsupportedError('unsupported operation');

  @override
  List<Cookie> get cookies => throw UnsupportedError('unsupported operation');

  @override
  Future<Socket> detachSocket({bool writeHeaders = true}) =>
      throw UnsupportedError('unsupported operation');

  @override
  Future get done => throw UnsupportedError('unsupported operation');

  @override
  Future flush() => throw UnsupportedError('unsupported operation');

  @override
  HttpHeaders get headers => throw UnsupportedError('unsupported operation');

  @override
  Future redirect(Uri location, {int status = HttpStatus.movedTemporarily}) =>
      throw UnsupportedError('unsupported operation');

  @override
  void write(Object? object) => throw UnsupportedError('unsupported operation');

  @override
  void writeAll(Iterable objects, [String separator = ""]) =>
      throw UnsupportedError('unsupported operation');

  @override
  void writeCharCode(int charCode) =>
      throw UnsupportedError('unsupported operation');

  @override
  void writeln([Object? object = ""]) =>
      throw UnsupportedError('unsupported operation');
}
