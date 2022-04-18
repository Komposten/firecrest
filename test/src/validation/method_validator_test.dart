import 'dart:collection';
import 'dart:mirrors';

import 'package:firecrest/src/validation/method_validator.dart';
import 'package:test/test.dart';

import '../test_util/matchers.dart';

void main() {
  group('requirePositionalParameterOfType', () {
    void a(int a, num b) {}

    test('correctParameterTypeAtIndex_doesNotThrow', () {
      expect(
          () => MethodValidator.requirePositionalParameterOfType(mirror(a), int,
              index: 0),
          returnsNormally);
      expect(
          () => MethodValidator.requirePositionalParameterOfType(mirror(a), num,
              index: 1),
          returnsNormally);
    });

    test('correctParameterTypeAtOtherIndex_throwsArgumentError', () {
      expect(
          () => MethodValidator.requirePositionalParameterOfType(mirror(a), int,
              index: 1),
          throwsWithMessage<ArgumentError>(
              '"a" must have a(n) int as positional parameter at index 1'));
      expect(
          () => MethodValidator.requirePositionalParameterOfType(mirror(a), num,
              index: 0),
          throwsWithMessage<ArgumentError>(
              '"a" must have a(n) num as positional parameter at index 0'));
    });

    test('noParameterOfType_throwsArgumentError', () {
      expect(
          () => MethodValidator.requirePositionalParameterOfType(
              mirror(a), bool, index: 1),
          throwsWithMessage<ArgumentError>(
              '"a" must have a(n) bool as positional parameter at index 1'));
    });
  });

  group('requireNamedParameters', () {
    void a({int? a, num? b, String? c}) {}
    test('allSpecifiedParametersExist_doesNotThrow', () {
      expect(
          () => MethodValidator.requireNamedParameters(
              mirror(a), {'a': int, 'b': num}),
          returnsNormally);
      expect(
          () => MethodValidator.requireNamedParameters(
              mirror(a), {'a': int, 'b': num, 'c': String}),
          returnsNormally);
    });

    test('someParametersMissing_throwsArgumentError', () {
      expect(
          () => MethodValidator.requireNamedParameters(mirror(a), {'d': int}),
          throwsWithMessage<ArgumentError>(
              '"a" is missing one or more named parameters: {d}'));
      expect(
          () => MethodValidator.requireNamedParameters(mirror(a),
              LinkedHashMap.fromIterable(['d', 'e', 'f'], value: (_) => int)),
          throwsWithMessage<ArgumentError>(
              '"a" is missing one or more named parameters: {d, e, f}'));
    });

    test('someParametersWrongType_throwsArgumentError', () {
      expect(
          () => MethodValidator.requireNamedParameters(mirror(a), {'a': num}),
          throwsWithMessage<ArgumentError>(
              '"a" has named parameters with incorrect types. They should be: {a: num}'));
      expect(
          () => MethodValidator.requireNamedParameters(
              mirror(a),
              LinkedHashMap.fromEntries([
                MapEntry('a', String),
                MapEntry('b', <String>[].runtimeType)
              ])),
          throwsWithMessage<ArgumentError>(
              '"a" has named parameters with incorrect types. They should be: {a: String, b: List<String>}'));
    });
  });

  group('requireOnlyNamedParameters', () {
    void a(a, b, {c, d, e}) {}

    test('allParametersAfterSkipAreNamed_doesNotThrow', () {
      expect(
          () => MethodValidator.requireOnlyNamedParameters(mirror(a), skip: 2),
          returnsNormally);
      expect(
          () => MethodValidator.requireOnlyNamedParameters(mirror(a), skip: 4),
          returnsNormally);
    });

    test('someUnnamedParametersAfterSkip_throwsArgumentError', () {
      expect(
          () => MethodValidator.requireOnlyNamedParameters(mirror(a), skip: 0),
          throwsWithMessage<ArgumentError>(
              '"a" may not have any unnamed parameters'));
      expect(
          () => MethodValidator.requireOnlyNamedParameters(mirror(a), skip: 1),
          throwsWithMessage<ArgumentError>(
              '"a" may only have 1 unnamed parameters'));
    });
  });
}

MethodMirror mirror(dynamic a) {
  return (reflect(a) as ClosureMirror).function;
}
