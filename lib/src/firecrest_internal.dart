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
import 'package:firecrest/src/util/conversion.dart';
import 'package:firecrest/src/util/meta.dart';
import 'package:firecrest/src/util/route_lookup.dart';
import 'package:firecrest/src/util/route_map.dart';
import 'package:firecrest/src/util/type_converter.dart';

class FirecrestInternal implements Firecrest {
  final Statistics _statistics = Statistics();
  final RouteMap<ControllerReference> _controllers = RouteMap();
  final RouteMap<List<Middleware>> _middlewares = RouteMap();
  late final RouteLookup _routeLookup;
  final ErrorHandler _errorHandler;

  HttpServer? _server;
  bool _collectStatistics;

  @override
  Statistics get statistics => _statistics;

  FirecrestInternal(List<Object> controllers, ErrorHandler errorHandler,
      {List<TypeConverter> typeConverters = const [],
      bool collectStatistics = true})
      : _errorHandler = errorHandler,
        _collectStatistics = collectStatistics {
    final typeConversion = Conversion();
    typeConverters.forEach(typeConversion.addConverter);

    _initControllers(controllers, typeConversion);
    _routeLookup = RouteLookup(_controllers.keys);
  }

  void _initControllers(List<Object> controllers, Conversion typeConversion) {
    for (var controller in controllers) {
      Route route;

      if (controller is Controller) {
        route = controller.route;
      } else {
        var controllerMeta = firstMetaOfType<Controller>(object: controller);

        if (controllerMeta == null) {
          throw ArgumentError(
              '${controller.runtimeType} is neither a $Controller nor annotated with @${Controller}');
        } else {
          route = controllerMeta.route;
        }
      }

      _registerController(route, controller, typeConversion);
    }

    _registerMiddleware();
    _printRoutes();
  }

  void _registerController(
      Route route, Object controller, Conversion typeConversion) {
    var reference =
        ControllerReference.forController(controller, route, typeConversion);

    if (_controllers.containsKey(route)) {
      throw StateError(
          'Two controllers registered for path /${route.path}: ${_controllers[route]!.name} and ${reference.name}');
    }
    _controllers[route] = reference;
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

    var parent = route.parent;
    if (parent != null) {
      list.addAll(_findMiddlewareRecursively(parent, onlyTransient: true));
    }

    var controller = _controllers[route];

    if (controller != null) {
      var middlewareMetas =
          allMetaOfType<WithMiddleware>(mirror: controller.mirror.type);

      for (var middlewareMeta in middlewareMetas) {
        if (!onlyTransient || middlewareMeta.transient) {
          var middleware = reflectClass(middlewareMeta.type)
              .newInstance(Symbol(''), []).reflectee as Middleware;
          list.add(middleware);
        }
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

      Route? route = _routeLookup.findRoute(request.uri.pathSegments);
      statsCollector?.forRoute(route);

      try {
        if (route != null) {
          await _handleRequestForRoute(route, request, statsCollector);
        } else {
          throw ServerException(HttpStatus.notFound,
              'No controller has been registered for path ${request.uri.path}');
        }
      } catch (e, stacktrace) {
        statsCollector?.endAll();
        if (e is Error) {
          rethrow;
        }
        await _handleRequestError(e, stacktrace, request, statsCollector);
      }
    } finally {
      statsCollector?.close();
      if (_collectStatistics) {
        _statistics.update(statsCollector!);
      }
    }
  }

  Future<void> _handleRequestForRoute(Route route, HttpRequest request,
      [StatisticsCollector? statsCollector]) async {
    var routeController = _controllers[route]!;
    var middlewares = _middlewares[route]!;
    var pathParameters = route.getParameters(request.uri.pathSegments);

    var handled = false;

    for (var middleware in middlewares) {
      statsCollector?.begin(middleware);
      if (await middleware.handle(request)) {
        handled = true;
        statsCollector?.end(middleware);
        break;
      }
      statsCollector?.end(middleware);
    }

    if (!handled) {
      statsCollector?.begin(routeController.controller);
      var method = request.method.toLowerCase();
      var methodSymbol = Symbol(method);
      handled = await routeController.invoke(methodSymbol, request.response,
          pathParameters, request.uri.queryParameters);

      if (!handled) {
        throw ServerException(HttpStatus.methodNotAllowed,
            'Method $method is not allowed for route /${route.path}');
      }
      statsCollector?.end(routeController.controller);
    }
  }

  Future<void> _handleRequestError(
      Object error, StackTrace stacktrace, HttpRequest request,
      [StatisticsCollector? statsCollector]) async {
    ServerException exception = error is ServerException
        ? error
        : ServerException(HttpStatus.internalServerError, error);

    statsCollector?.begin(_errorHandler);
    try {
      await _errorHandler.handle(exception, stacktrace, request);
    } catch (e) {
      rethrow;
    } finally {
      statsCollector?.end(_errorHandler);
    }
  }
}
