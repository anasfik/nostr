import '_example_shared.dart';

Future<void> main() async {
  final nostr = exampleNostr();
  const publicKey =
      '32e1827635450ebb3c5a7d12c1f8e7b2b514439ac10a67eef3d9fd9c5c68e245';

  try {
    final verified = await nostr.utils.verifyNip05(
      internetIdentifier: 'jb55@jb55.com',
      pubKey: publicKey,
    );

    print('verified: $verified');
  } catch (error) {
    print('verification failed: $error');
  }
}
