import 'package:firecrest/src/route/route.dart';

class Controller {
  final String path;

  const Controller(this.path);

  Route get route => Route(path);
}
