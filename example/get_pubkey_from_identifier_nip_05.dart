import '_example_shared.dart';

Future<void> main() async {
  final nostr = exampleNostr();
  final publicKey = await nostr.utils.pubKeyFromIdentifierNip05(
    internetIdentifier: 'jb55@jb55.com',
  );

  print('public key: $publicKey');
}
