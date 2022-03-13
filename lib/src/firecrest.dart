import 'package:firecrest/firecrest.dart';
import 'package:firecrest/src/firecrest_internal.dart';

abstract class Firecrest {
  factory Firecrest(List<Object> controllers, ErrorHandler errorHandler,
      {bool collectStatistics = true}) {
    return FirecrestInternal(controllers, errorHandler,
        collectStatistics: collectStatistics);
  }

  void setCollectStatistics(bool collect);

  Statistics get statistics;

  /// Starts an http server and binds it to the specified host and port.
  Future<void> start(String host, int port);

  /// Closes the http server.
  ///
  /// See [HttpServer.close] for details.
  Future<void> close({bool force = false});
}
