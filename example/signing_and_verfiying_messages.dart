import 'package:dart_nostr/dart_nostr.dart';

void main() {
  final keyPair = Nostr.instance.keysService.generateKeyPair();
  final signature = Nostr.instance.keysService.sign(
    privateKey: keyPair.private,
    message: 'message',
  );

  print('signature: $signature'); // ...
  final isVerified = Nostr.instance.keysService.verify(
    publicKey: keyPair.public,
    message: 'message',
    signature: signature,
  );

  print('isVerified: $isVerified'); // true
}
