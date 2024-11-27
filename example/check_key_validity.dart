import 'package:dart_nostr/nostr/dart_nostr.dart';

void main() {
  final nostrKeyPairs = Nostr.instance.services.keys.generateKeyPair();

  print(nostrKeyPairs.private);

  final firstKey = nostrKeyPairs.private;
  const secondKey = '';

  print(
    'is firstKey a valid key? ${Nostr.instance.services.keys.isValidPrivateKey(firstKey)}',
  );
  print(
    'is secondKey a valid key? ${Nostr.instance.services.keys.isValidPrivateKey(secondKey)}',
  );
}
