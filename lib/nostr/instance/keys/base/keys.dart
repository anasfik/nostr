import 'package:dart_nostr/dart_nostr.dart';

abstract class NostrKeysBase {
  NostrKeyPairs generateKeyPair();
  NostrKeyPairs generateKeyPairFromExistingPrivateKey(String privateKey);
  String generatePrivateKey();
  String derivePublicKey({required String privateKey});
  String sign({required String privateKey, required String message});
  String encodePublicKeyToNpub(String publicKey);
  String encodePrivateKeyToNsec(String privateKey);
  String decodeNpubKeyToPublicKey(String npubKey);
  String decodeNsecKeyToPrivateKey(String nsecKey);
  bool isValidPrivateKey(String privateKey);
}
