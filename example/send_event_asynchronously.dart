import 'package:dart_nostr/dart_nostr.dart';

import '_example_shared.dart';

Future<void> main() async {
  final nostr = await connectedExampleNostr();
  final keyPair = nostr.keys.generateKeyPair();

  final event = NostrEvent.fromPartialData(
    kind: 1,
    content: 'Hello World! from dart_nostr package',
    keyPairs: keyPair,
  );

  final result = await nostr.publish(event);
  result.fold(
    (ok) => print('accepted: ${ok.isEventAccepted}, message: ${ok.message}'),
    (failure) => print('publish failed: $failure'),
  );
}
