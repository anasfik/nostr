import 'package:dart_nostr/nostr/core/failures.dart';

sealed class NostrResult<T> {
  const NostrResult();

  bool get isSuccess => this is NostrSuccess<T>;
  bool get isFailure => this is NostrFailureResult<T>;

  T? get valueOrNull => switch (this) {
        NostrSuccess<T>(:final value) => value,
        NostrFailureResult<T>() => null,
      };

  NostrFailure? get failureOrNull => switch (this) {
        NostrSuccess<T>() => null,
        NostrFailureResult<T>(:final failure) => failure,
      };

  R fold<R>(R Function(T value) onSuccess,
      R Function(NostrFailure failure) onFailure) {
    return switch (this) {
      NostrSuccess<T>(:final value) => onSuccess(value),
      NostrFailureResult<T>(:final failure) => onFailure(failure),
    };
  }

  NostrResult<R> map<R>(R Function(T value) mapper) {
    return switch (this) {
      NostrSuccess<T>(:final value) => NostrSuccess<R>(mapper(value)),
      NostrFailureResult<T>(:final failure) => NostrFailureResult<R>(failure),
    };
  }

  NostrResult<R> flatMap<R>(NostrResult<R> Function(T value) mapper) {
    return switch (this) {
      NostrSuccess<T>(:final value) => mapper(value),
      NostrFailureResult<T>(:final failure) => NostrFailureResult<R>(failure),
    };
  }
}

final class NostrSuccess<T> extends NostrResult<T> {
  const NostrSuccess(this.value);

  final T value;
}

final class NostrFailureResult<T> extends NostrResult<T> {
  const NostrFailureResult(this.failure);

  final NostrFailure failure;
}
