import 'package:dart_nostr/dart_nostr.dart';

void main() {
  // we generate a key pair and print the public and private keys
  final keyPair = Nostr.instance.services.keys.generateKeyPair();
  final publicKey = keyPair.public;
  final privateKey = keyPair.private;
  print('publicKey: $publicKey');
  print('privateKey: $privateKey');

  // we encode the public key to an npub key (bech32 encoding)
  final npub = Nostr.instance.services.bech32.encodePublicKeyToNpub(publicKey);
  print('npub: $npub');

  // we encode the private  key to an nsec key (bech32 encoding)
  final nsec =
      Nostr.instance.services.bech32.encodePrivateKeyToNsec(privateKey);
  print('nsec: $nsec');

  // we decode the npub key to a public key
  final decodedPublicKey =
      Nostr.instance.services.bech32.decodeNpubKeyToPublicKey(npub);
  print('decodedPublicKey: $decodedPublicKey');

  // we decode the nsec key to a private key
  final decodedPrivateKey =
      Nostr.instance.services.bech32.decodeNsecKeyToPrivateKey(nsec);
  print('decodedPrivateKey: $decodedPrivateKey');

  assert(publicKey == decodedPublicKey);
  assert(privateKey == decodedPrivateKey);
}
