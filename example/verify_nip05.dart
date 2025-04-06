import 'package:dart_nostr/dart_nostr.dart';

void main() async {
  const publicKeyToCheckWith =
      '32e1827635450ebb3c5a7d12c1f8e7b2b514439ac10a67eef3d9fd9c5c68e245';

  final isIdentifierVerifiedWithPublixKey =
      await Nostr.instance.services.utils.verifyNip05(
    internetIdentifier: 'jb55@randomshit.com',
    pubKey: publicKeyToCheckWith,
  );

  print(
    'isIdentifierVerifiedWithPublixKey: $isIdentifierVerifiedWithPublixKey',
  );
}
