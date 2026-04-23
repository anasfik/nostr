import '_example_shared.dart';

void main() {
  final nostr = exampleNostr();
  final keyPair = nostr.keys.generateKeyPair();
  final signature = nostr.keys.sign(
    privateKey: keyPair.private,
    message: 'message',
  );

  final isVerified = nostr.keys.verify(
    publicKey: keyPair.public,
    message: 'message',
    signature: signature,
  );

  print('signature: $signature');
  print('isVerified: $isVerified');
}
