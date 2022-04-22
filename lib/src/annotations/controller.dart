import 'package:firecrest/firecrest.dart';
import 'package:firecrest/src/route/route.dart';

/// Annotation/parent class to mark a class as a controller for a route.
///
/// Annotate a class with `@Controller('some/path/')` or extend from this class
/// to create a controller. The path specified in the constructor is the route
/// the controller should be registered for. The path may contain
/// "basic wildcards" (example: `user/:id` will match `user/a`, `user/b`, etc.)
/// and "super wildcards" (example: `doc/::path` will match `doc/a`, `doc/b`,
/// `doc/a/b`, `doc/a/b/c`, etc.).
///
/// Controllers will not be auto-discovered, and must therefore be manually
/// passed to [Firecrest] when creating the [Firecrest] instance.
class Controller {
  final String path;

  const Controller(this.path);

  Route get route => Route(path);
}
