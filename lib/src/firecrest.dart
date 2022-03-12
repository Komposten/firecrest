import 'dart:io';
import 'dart:mirrors';

import 'package:firecrest/src/annotations/controller.dart';
import 'package:firecrest/src/annotations/with_middleware.dart';
import 'package:firecrest/src/controller_reference.dart';
import 'package:firecrest/src/error_handler.dart';
import 'package:firecrest/src/middleware.dart';
import 'package:firecrest/src/route.dart';
import 'package:firecrest/src/server_exception.dart';
import 'package:firecrest/src/util/controller_map.dart';
import 'package:firecrest/src/util/meta.dart';

class Firecrest {
  final RouteMap<ControllerReference> _controllers = RouteMap();
  final RouteMap<List<Middleware>> _middlewares = RouteMap();
  final ErrorHandler _errorHandler;

  HttpServer? _server;

  Firecrest(List<Object> controllers, ErrorHandler errorHandler)
      : _errorHandler = errorHandler {
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

  /// Starts an http server and binds it to the specified host and port.
  Future<void> start(String host, int port) async {
    _server = await HttpServer.bind(host, port);
    _server!.listen(_handleRequest);
    print('HTTP server started on $host:$port');
  }

  /// Closes the http server.
  ///
  /// See [HttpServer.close] for details.
  Future<void> close({bool force = false}) async {
    await _server?.close(force: force);
  }

  void _handleRequest(HttpRequest request) async {
    var uri = request.uri.toString();
    print('Request received: ${request.method.toUpperCase()} $uri');

    var method = request.method.toLowerCase();
    Route? route;
    for (var _route in _controllers.keys) {
      if (_route.matches(request.uri.pathSegments)) {
        route = _route;
        break;
      }
    }

    try {
      var handled = false;

      if (route != null) {
        var routeController = _controllers[route]!;
        var middlewares = _middlewares[route]!;
        var pathParameters = route.getParameters(request.uri.pathSegments);

        /* TODO jhj: Validate that all required query parameters are included,
          and that no unknown query parameters exist!
       */
        for (var middleware in middlewares) {
          if (await middleware.handle(request)) {
            handled = true;
          }
        }

        var methodSymbol = Symbol(method);
        if (routeController.canHandle(methodSymbol) && !handled) {
          handled = await routeController.invoke(methodSymbol, request.response,
              pathParameters, request.uri.queryParameters);
        }
      }

      if (!handled) {
        throw ServerException(HttpStatus.notFound);
      }
    } catch (e) {
      if (e is Error) {
        throw e;
      }

      ServerException exception;

      if (e is ServerException) {
        exception = e;
      } else {
        exception = ServerException(HttpStatus.internalServerError, e);
      }

      _errorHandler.handle(exception, request);
    }
  }
}
