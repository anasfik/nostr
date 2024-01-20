import 'package:dart_nostr/nostr/dart_nostr.dart';

void main() {
  final nostrKeyPairs = Nostr.instance.keysService.generateKeyPair();

  print(nostrKeyPairs.private);

  final firstKey = nostrKeyPairs.private;
  const secondKey = '';

  print(
    'is firstKey a valid key? ${Nostr.instance.keysService.isValidPrivateKey(firstKey)}',
  );
  print(
    'is secondKey a valid key? ${Nostr.instance.keysService.isValidPrivateKey(secondKey)}',
  );
}
