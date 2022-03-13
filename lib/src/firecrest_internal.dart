import 'dart:io';
import 'dart:mirrors';

import 'package:firecrest/src/annotations/controller.dart';
import 'package:firecrest/src/annotations/with_middleware.dart';
import 'package:firecrest/src/controller_reference.dart';
import 'package:firecrest/src/error_handler.dart';
import 'package:firecrest/src/firecrest.dart';
import 'package:firecrest/src/middleware.dart';
import 'package:firecrest/src/route/route.dart';
import 'package:firecrest/src/server_exception.dart';
import 'package:firecrest/src/statistics/statistics.dart';
import 'package:firecrest/src/statistics/statistics_collector.dart';
import 'package:firecrest/src/util/controller_map.dart';
import 'package:firecrest/src/util/meta.dart';
import 'package:firecrest/src/util/route_comparators.dart';
import 'package:meta/meta.dart';

class FirecrestInternal implements Firecrest {
  final Statistics _statistics = Statistics();
  final RouteMap<ControllerReference> _controllers = RouteMap();
  final RouteMap<List<Middleware>> _middlewares = RouteMap();
  final ErrorHandler _errorHandler;

  HttpServer? _server;
  bool _collectStatistics;

  @override
  Statistics get statistics => _statistics;

  FirecrestInternal(List<Object> controllers, ErrorHandler errorHandler,
      {bool collectStatistics = true})
      : _errorHandler = errorHandler,
        _collectStatistics = collectStatistics {
    _initControllers(controllers);
  }

  void _initControllers(List<Object> controllers) {
    for (var controller in controllers) {
      var controllerMeta = firstMetaOfType<Controller>(object: controller);

      if (controllerMeta == null) {
        throw ArgumentError(
            '${controller.runtimeType} is not an @${Controller}');
      }

      _registerController(controllerMeta.route, controller);
    }

    _registerMiddleware();
    _printRoutes();
  }

  void _registerController(Route route, Object controller) {
    var reference = ControllerReference.forController(controller);
    _validateHandlers(reference.requestHandlers, controller.runtimeType);

    if (_controllers.containsKey(route)) {
      throw StateError(
          'Two controllers registered for path "${route.path}": ${_controllers[route]!.name} and ${reference.name}');
    }
    _controllers[route] = reference;
  }

  void _validateHandlers(
      Map<Symbol, MethodMirror> handlers, Type controllerType) {
    for (var mirror in handlers.values) {
      var isValid = true;
      if (mirror.parameters.isEmpty) {
        isValid = false;
      } else {
        var firstParam = mirror.parameters.first;

        if (firstParam.isNamed ||
            firstParam.isOptional ||
            !firstParam.type.hasReflectedType ||
            firstParam.type.reflectedType != HttpResponse) {
          isValid = false;
        }
      }

      if (!isValid) {
        throw ArgumentError(
            'Request handler "${MirrorSystem.getName(mirror.simpleName)}" in $controllerType must have an HttpResponse as first positional parameter');
      }
    }
  }

  void _printRoutes() {
    print('Registered routes:');
    var routes = _controllers.keys.toList()..sort();

    for (var route in routes) {
      var path = route.path;
      var middlewares = _middlewares[route]!;
      var controller = _controllers[route]!;
      var controllerString =
          '${controller.name}[${controller.supportedMethods.map(MirrorSystem.getName).join(', ')}]';

      if (controller.supportedMethods.isNotEmpty) {
        if (middlewares.length > 0) {
          var middlewareString =
              middlewares.map((e) => e.runtimeType.toString()).join(' > ');
          print('  /$path | $middlewareString > $controllerString');
        } else {
          print('  /$path | $controllerString');
        }
      }
    }
  }

  void _registerMiddleware() {
    for (var route in _controllers.keys) {
      _middlewares[route] = _findMiddlewareRecursively(route);
    }
  }

  List<Middleware> _findMiddlewareRecursively(Route route,
      {bool onlyTransient = false}) {
    var list = <Middleware>[];

    if (route.parent != null) {
      list.addAll(
          _findMiddlewareRecursively(route.parent!, onlyTransient: true));
    }

    var controller = _controllers[route];

    if (controller != null) {
      var middlewareMetas =
          allMetaOfType<WithMiddleware>(mirror: controller.mirror.type);

      for (var middlewareMeta in middlewareMetas) {
        var middleware = reflectClass(middlewareMeta.type)
            .newInstance(Symbol(''), []).reflectee as Middleware;
        list.add(middleware);
      }
    }

    return list;
  }

  @override
  void setCollectStatistics(bool collect) => _collectStatistics = collect;

  @override
  Future<void> start(String host, int port) async {
    _server = await HttpServer.bind(host, port);
    _server!.listen(_handleRequest);
    print('HTTP server started on $host:$port');
  }

  @override
  Future<void> close({bool force = false}) async {
    await _server?.close(force: force);
  }

  Future<void> _handleRequest(HttpRequest request) async {
    var statsCollector = _collectStatistics ? BasicCollector() : null;

    try {
      var uri = request.uri.toString();
      print('Request received: ${request.method.toUpperCase()} $uri');

      Route? route = findRoute(request.uri.pathSegments);
      statsCollector?.forRoute(route);

      try {
        var handled = false;

        if (route != null) {
          handled =
              await _handleRequestForRoute(route, request, statsCollector);
        }

        if (!handled) {
          throw ServerException(HttpStatus.notFound);
        }
      } catch (e) {
        statsCollector?.endAll();
        _handleRequestError(e, request, statsCollector);
      }
    } finally {
      statsCollector?.close();
      if (_collectStatistics) {
        _statistics.update(statsCollector!);
      }
    }
  }

  /// Tries to find a route matching the path in the provided [request].
  ///
  /// If there is a single match, that match is returned.
  ///
  /// If there are multiple matches, the one with highest priority is returned.
  /// A route has higher priority if it has a normal (i.e. non-wild) segment
  /// earlier in the path.
  @visibleForTesting
  Route? findRoute(List<String> pathSegments) {
    var matches = <Route>[];
    for (var route in _controllers.keys) {
      if (route.matches(pathSegments)) {
        matches.add(route);
      }
    }

    matches.sort((a, b) => compareRouteMatches(a, b, pathSegments));

    return matches.isNotEmpty ? matches.first : null;
  }

  Future<bool> _handleRequestForRoute(Route route, HttpRequest request,
      [StatisticsCollector? statsCollector]) async {
    var routeController = _controllers[route]!;
    var middlewares = _middlewares[route]!;
    var pathParameters = route.getParameters(request.uri.pathSegments);

    var handled = false;

    /* TODO jhj: Validate that all required query parameters are included,
        and ensure that unknown query parameters are removed from the map!
     */
    for (var middleware in middlewares) {
      statsCollector?.begin(middleware);
      if (await middleware.handle(request)) {
        handled = true;
      }
      statsCollector?.end(middleware);
    }

    statsCollector?.begin(routeController.controller);
    var method = request.method.toLowerCase();
    var methodSymbol = Symbol(method);
    if (routeController.canHandle(methodSymbol) && !handled) {
      handled = await routeController.invoke(methodSymbol, request.response,
          pathParameters, request.uri.queryParameters);
    }
    statsCollector?.end(routeController.controller);

    return handled;
  }

  void _handleRequestError(Object error, HttpRequest request,
      [StatisticsCollector? statsCollector]) {
    if (error is Error) {
      throw error;
    }

    ServerException exception = error is ServerException
        ? error
        : ServerException(HttpStatus.internalServerError, error);

    statsCollector?.begin(_errorHandler);
    _errorHandler.handle(exception, request);
    statsCollector?.end(_errorHandler);
  }
}
