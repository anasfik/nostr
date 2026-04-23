import '_example_shared.dart';

void main() {
  final nostr = exampleNostr();

  print(divider('bech32'));

  final keyPair = nostr.keys.generateKeyPair();

  final npub = nostr.bech32.encodePublicKeyToNpub(keyPair.public);
  final nsec = nostr.bech32.encodePrivateKeyToNsec(keyPair.private);

  print('npub: $npub');
  print('nsec: $nsec');

  final decodedPublicKey = nostr.bech32.decodeNpubKeyToPublicKey(npub);
  final decodedPrivateKey = nostr.bech32.decodeNsecKeyToPrivateKey(nsec);

  print('public key round-trip : ${decodedPublicKey == keyPair.public}');
  print('private key round-trip: ${decodedPrivateKey == keyPair.private}');
}
