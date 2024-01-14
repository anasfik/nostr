import 'package:dart_nostr/nostr/dart_nostr.dart';

void main() {
  final newKeyPair = Nostr.instance.keysService.generateKeyPair();

  final relays = ['wss://relay.damus.io'];

  final nProfile = Nostr.instance.utilsService.encodeNProfile(
    pubkey: newKeyPair.public,
    userRelays: relays,
  );

  print('nProfile: $nProfile');

  final decodedNprofile =
      Nostr.instance.utilsService.decodeNprofileToMap(nProfile);

  print('decodedNprofile: $decodedNprofile');
}
