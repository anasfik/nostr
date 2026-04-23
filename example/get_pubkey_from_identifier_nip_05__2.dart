import '_example_shared.dart';

Future<void> main() async {
  final nostr = exampleNostr();

  try {
    final publicKey = await nostr.utils.pubKeyFromIdentifierNip05(
      internetIdentifier: 'jb55@jb55.com',
    );
    print('resolved public key: $publicKey');
  } catch (error) {
    print('nip05 lookup failed: $error');
  }
}
