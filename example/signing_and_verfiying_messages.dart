import 'package:dart_nostr/dart_nostr.dart';

void main() {
  final keyPair = Nostr.instance.services.keys.generateKeyPair();
  final signature = Nostr.instance.services.keys.sign(
    privateKey: keyPair.private,
    message: 'message',
  );

  print('signature: $signature'); // ...
  final isVerified = Nostr.instance.services.keys.verify(
    publicKey: keyPair.public,
    message: 'message',
    signature: signature,
  );

  print('isVerified: $isVerified'); // true
}
