import 'dart:mirrors';

bool hasMetaOfType<T>(DeclarationMirror mirror) {
  for (var metadata in mirror.metadata) {
    if (metadata.type.reflectedType == T) {
      return true;
    }
  }

  return false;
}

T? firstMetaOfType<T>({DeclarationMirror? mirror, Object? object}) {
  for (var metadata in _metadata(mirror: mirror, object: object)) {
    var reflectee = metadata.reflectee;

    if (reflectee is T) {
      return reflectee;
    }
  }

  return null;
}

List<T> allMetaOfType<T>({DeclarationMirror? mirror, Object? object}) {
  var list = <T>[];

  for (var metadata in _metadata(mirror: mirror, object: object)) {
    var reflectee = metadata.reflectee;

    if (reflectee is T) {
      list.add(reflectee);
    }
  }

  return list;
}

List<InstanceMirror> _metadata({DeclarationMirror? mirror, Object? object}) {
  if (mirror == null) {
    if (object == null) {
      throw ArgumentError("Either mirror or object must be specified");
    }

    mirror = reflectClass(object.runtimeType);
  }

  return mirror.metadata;
}
