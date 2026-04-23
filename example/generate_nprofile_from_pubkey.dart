import '_example_shared.dart';

void main() {
  final nostr = exampleNostr();
  final keyPair = nostr.keys.generateKeyPair();
  final nprofile = nostr.bech32.encodeNProfile(
    pubkey: keyPair.public,
    userRelays: exampleRelays,
  );

  print(divider('nprofile'));
  print('encoded: $nprofile');
  print('decoded: ${nostr.bech32.decodeNprofileToMap(nprofile)}');
}
