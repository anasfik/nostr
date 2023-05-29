import 'package:dart_nostr/dart_nostr.dart';

void main() async {
  final publicKeyToCheckWith =
      "32e1827635450ebb3c5a7d12c1f8e7b2b514439ac10a67eef3d9fd9c5c68e245";

  final isIdentifierVerifiedWithPublixKey =
      await Nostr.instance.utilsService.verifyNip05(
    internetIdentifier: "jb55@jb55.com",
    pubKey: publicKeyToCheckWith,
  );

  print(
    "isIdentifierVerifiedWithPublixKey: $isIdentifierVerifiedWithPublixKey",
  );
}
