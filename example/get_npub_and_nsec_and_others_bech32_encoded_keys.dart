import '_example_shared.dart';

void maiBAn() {
  final nostr = exampleNostr();
  final keyPair = nostr.keys.generateKeyPair();

  final npub = nostr.bech32.encodePublicKeyToNpub(keyPair.public);
  final nsec = nostr.bech32.encodePrivateKeyToNsec(keyPair.private);
  final decodedPublicKey = nostr.bech32.decodeNpubKeyToPublicKey(npub);
  final decodedPrivateKey = nostr.bech32.decodeNsecKeyToPrivateKey(nsec);

  print(divider('npub / nsec'));
  print('npub: $npub');
  print('nsec: $nsec');
  print('public roundtrip: ${decodedPublicKey == keyPair.public}');
  print('private roundtrip: ${decodedPrivateKey == keyPair.private}');
}
