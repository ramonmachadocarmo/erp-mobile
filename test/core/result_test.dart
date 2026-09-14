import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/error/failure.dart';
import 'package:mobile/core/error/result.dart';

void main() {
  test('Ok getOrThrow', () {
    expect(const Ok(2).getOrThrow(), 2);
  });

  test('Err getOrThrow', () {
    expect(() => const Err<int>(NetworkFailure('x')).getOrThrow(), throwsException);
  });

  test('when', () {
    expect(const Ok('a').when(ok: (v) => v, err: (_) => 'e'), 'a');
    expect(const Err<String>(ServerFailure('no')).when(ok: (v) => v, err: (f) => f.message), 'no');
  });
}
