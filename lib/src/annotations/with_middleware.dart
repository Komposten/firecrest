/// Annotation to add middleware to a controller.
///
/// Annotate a controller with `@WithMiddleware(MyMiddleware)` to attach an
/// instance of `MyMiddleware` to that controller. If `transient: true` is
/// specified, the middleware will be inherited by controllers on sub-routes.
/// For example, if /a has a transient middleware, that middleware will also be
/// active for /a/b.
class WithMiddleware {
  final Type type;
  final bool transient;

  const WithMiddleware(this.type, {this.transient = false});
}
