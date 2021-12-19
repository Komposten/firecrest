class ServerException implements Exception {
  final int status;
  final Object? message;

  ServerException(this.status, [this.message]);

  String toString() {
    if (message == null) return '$status';
    return "$status: $message";
  }
}
