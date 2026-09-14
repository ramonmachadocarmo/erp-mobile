import 'failure.dart';

sealed class Result<T> {
  const Result();

  R when<R>({
    required R Function(T value) ok,
    required R Function(Failure failure) err,
  });

  T getOrThrow() => when(ok: (v) => v, err: (f) => throw Exception(f.message));
}

final class Ok<T> extends Result<T> {
  const Ok(this.value);
  final T value;

  @override
  R when<R>({
    required R Function(T value) ok,
    required R Function(Failure failure) err,
  }) => ok(value);
}

final class Err<T> extends Result<T> {
  const Err(this.failure);
  final Failure failure;

  @override
  R when<R>({
    required R Function(T value) ok,
    required R Function(Failure failure) err,
  }) => err(failure);
}
