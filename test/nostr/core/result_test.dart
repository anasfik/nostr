import 'package:dart_nostr/dart_nostr.dart';
import 'package:test/test.dart';

void main() {
  group('NostrResult', () {
    test('success map transforms value', () {
      const result = NostrSuccess<int>(2);

      final mapped = result.map((value) => value * 5);

      expect(mapped.isSuccess, isTrue);
      expect(mapped.valueOrNull, 10);
    });

    test('failure keeps failure when mapped', () {
      final result = NostrFailureResult<int>(
        NostrFailure.invalidArgument('bad input'),
      );

      final mapped = result.map((value) => value * 5);

      expect(mapped.isFailure, isTrue);
      expect(mapped.failureOrNull?.code, NostrFailureCode.invalidArgument);
    });
  });
}
