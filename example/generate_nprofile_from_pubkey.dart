import 'package:dart_nostr/nostr/dart_nostr.dart';

void main() {
  final newKeyPair = Nostr.instance.services.keys.generateKeyPair();

  final relays = ['wss://relay.damus.io'];

  final nProfile = Nostr.instance.services.bech32.encodeNProfile(
    pubkey: newKeyPair.public,
    userRelays: relays,
  );

  print('nProfile: $nProfile');

  final decodedNprofile =
      Nostr.instance.services.bech32.decodeNprofileToMap(nProfile);

  print('decodedNprofile: $decodedNprofile');
}
