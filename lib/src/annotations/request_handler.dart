class RequestHandler {
  final String? method;

  const RequestHandler({this.method});

  bool get hasCustomMethod => method != null;
}
