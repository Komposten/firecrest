import 'dart:io';

/// Annotation to mark a method in a controller as a request handler.
///
/// Add `@RequestHandler()` to a method in a controller to turn that method into
/// a request handler. This means that it will be registered by firecrest as a
/// handler for the route the controller is bound to. By default the name of the
/// method will be used to determine the HTTP method the handler will handle,
/// but this can be overridden using the `method` parameter.
///
/// A method marked as a request handler must have a signature following these
/// rules:
/// 1. The first parameter must be a positional parameter of type [HttpResponse].
/// 2. If the route has basic wildcards (e.g. `/:id`), those must be provided as
/// required named String parameters. Example `{required String id}`.
/// 3. If the route has super wildcards (e.g. `/::path`), those must be provided
/// as required named String list parameters. Example `{required List<String> path}`.
/// 4. Query parameters can be added as named parameters. They will be considered
/// as required query parameters if they have no default value or a default value
/// of `null`.
///
/// Firecrest will validate all method handlers during start-up and throw if
/// anything is incorrect.
///
/// Examples:
/// ```
/// @Controller('user/:userId/posts')
/// class UserPostsController {
///     @RequestHandler()
///     void get(HttpResponse response, {required String userId, int page = 0}) {
///         // Will handle GET requests.
///     }
///
///     @RequestHandler(method: 'post')
///     void save(HttpResponse response, {required String userId}) {
///         // Will handle POST requests.
///     }
/// }
/// ```
class RequestHandler {
  final String? method;

  const RequestHandler({this.method});

  bool get hasCustomMethod => method != null;
}
