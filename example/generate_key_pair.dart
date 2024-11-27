import 'package:dart_nostr/nostr/dart_nostr.dart';

void main() async {
  // This method will enable the logs of the library.
  Nostr.instance.enableLogs();

  // generates a key pair.
  final keyPair = Nostr.instance.services.keys.generateKeyPair();

  print(keyPair.public); // ...
  print(keyPair.private); // ...

  final sameKeyPairGeneratedFromPrivate = Nostr.instance.services.keys
      .generateKeyPairFromExistingPrivateKey(keyPair.private);

  print(sameKeyPairGeneratedFromPrivate.public); // ...
  print(sameKeyPairGeneratedFromPrivate.private); // ...

  assert(sameKeyPairGeneratedFromPrivate == keyPair);
  if (sameKeyPairGeneratedFromPrivate != keyPair) {
    throw Exception('Key pair generation has something wrong.');
  }

  final publicKey = Nostr.instance.services.keys
      .derivePublicKey(privateKey: sameKeyPairGeneratedFromPrivate.private);
  print(publicKey);

  assert(publicKey == sameKeyPairGeneratedFromPrivate.public);
  if (publicKey != sameKeyPairGeneratedFromPrivate.public) {
    throw Exception('Key pair generation has something wrong.');
  }
}
