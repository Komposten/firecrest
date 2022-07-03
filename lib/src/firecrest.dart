import 'package:firecrest/firecrest.dart';
import 'package:firecrest/src/firecrest_internal.dart';

abstract class Firecrest {
  /// Sets up a Firecrest instance with the provided controllers and error handler.
  ///
  /// [controllers] is a list of [Controller] instances. A controller class is
  /// any class which either extends [Controller] or is annotated with
  /// @[Controller].
  /// If an exception occurs while processing a request it will be passed to the
  /// [errorHandler], so that an appropriate response can be constructed.
  /// By default the request handler methods in the controllers are limited to a
  /// small set of types for query parameters. Use [typeConverters] to add
  /// conversion logic for any additional types you want to use.
  factory Firecrest(List<Object> controllers, ErrorHandler errorHandler,
      {List<TypeConverter> typeConverters = const [],
      bool collectStatistics = true}) {
    return FirecrestInternal(controllers, errorHandler,
        typeConverters: typeConverters, collectStatistics: collectStatistics);
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
