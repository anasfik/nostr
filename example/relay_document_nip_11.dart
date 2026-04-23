import '_example_shared.dart';

Future<void> main() async {
  final nostr = exampleNostr();
  final relayDocument = await nostr.relays.relayInformationsDocumentNip11(
    relayUrl: exampleRelays.first,
  );

  print('name: ${relayDocument?.name}');
  print('software: ${relayDocument?.software}');
  print('supported NIPs: ${relayDocument?.supportedNips}');
}
