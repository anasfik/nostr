enum NostrFailureCode {
  invalidArgument,
  invalidState,
  connection,
  timeout,
  protocol,
  serialization,
  permissionDenied,
  unavailable,
  unknown,
}

class NostrFailure {
  const NostrFailure({
    required this.code,
    required this.message,
    this.cause,
    this.stackTrace,
    this.context = const <String, Object?>{},
    this.isRetryable = false,
  });

  final NostrFailureCode code;
  final String message;
  final Object? cause;
  final StackTrace? stackTrace;
  final Map<String, Object?> context;
  final bool isRetryable;

  factory NostrFailure.invalidArgument(
    String message, {
    Map<String, Object?> context = const <String, Object?>{},
    Object? cause,
    StackTrace? stackTrace,
  }) {
    return NostrFailure(
      code: NostrFailureCode.invalidArgument,
      message: message,
      context: context,
      cause: cause,
      stackTrace: stackTrace,
      isRetryable: false,
    );
  }

  factory NostrFailure.connection(
    String message, {
    Map<String, Object?> context = const <String, Object?>{},
    Object? cause,
    StackTrace? stackTrace,
    bool isRetryable = true,
  }) {
    return NostrFailure(
      code: NostrFailureCode.connection,
      message: message,
      context: context,
      cause: cause,
      stackTrace: stackTrace,
      isRetryable: isRetryable,
    );
  }

  factory NostrFailure.invalidState(
    String message, {
    Map<String, Object?> context = const <String, Object?>{},
    Object? cause,
    StackTrace? stackTrace,
  }) {
    return NostrFailure(
      code: NostrFailureCode.invalidState,
      message: message,
      context: context,
      cause: cause,
      stackTrace: stackTrace,
      isRetryable: false,
    );
  }

  factory NostrFailure.timeout(
    String message, {
    Map<String, Object?> context = const <String, Object?>{},
    Object? cause,
    StackTrace? stackTrace,
  }) {
    return NostrFailure(
      code: NostrFailureCode.timeout,
      message: message,
      context: context,
      cause: cause,
      stackTrace: stackTrace,
      isRetryable: true,
    );
  }

  factory NostrFailure.protocol(
    String message, {
    Map<String, Object?> context = const <String, Object?>{},
    Object? cause,
    StackTrace? stackTrace,
  }) {
    return NostrFailure(
      code: NostrFailureCode.protocol,
      message: message,
      context: context,
      cause: cause,
      stackTrace: stackTrace,
      isRetryable: false,
    );
  }

  factory NostrFailure.serialization(
    String message, {
    Map<String, Object?> context = const <String, Object?>{},
    Object? cause,
    StackTrace? stackTrace,
  }) {
    return NostrFailure(
      code: NostrFailureCode.serialization,
      message: message,
      context: context,
      cause: cause,
      stackTrace: stackTrace,
      isRetryable: false,
    );
  }

  factory NostrFailure.unknown(
    String message, {
    Map<String, Object?> context = const <String, Object?>{},
    Object? cause,
    StackTrace? stackTrace,
    bool isRetryable = false,
  }) {
    return NostrFailure(
      code: NostrFailureCode.unknown,
      message: message,
      context: context,
      cause: cause,
      stackTrace: stackTrace,
      isRetryable: isRetryable,
    );
  }

  NostrFailure copyWith({
    NostrFailureCode? code,
    String? message,
    Object? cause,
    StackTrace? stackTrace,
    Map<String, Object?>? context,
    bool? isRetryable,
  }) {
    return NostrFailure(
      code: code ?? this.code,
      message: message ?? this.message,
      cause: cause ?? this.cause,
      stackTrace: stackTrace ?? this.stackTrace,
      context: context ?? this.context,
      isRetryable: isRetryable ?? this.isRetryable,
    );
  }

  @override
  String toString() {
    return 'NostrFailure(code: $code, message: $message, isRetryable: $isRetryable, context: $context, cause: $cause)';
  }
}

class NostrException implements Exception {
  const NostrException(this.failure);

  final NostrFailure failure;

  @override
  String toString() => 'NostrException($failure)';
}
