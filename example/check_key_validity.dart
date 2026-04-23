import '_example_shared.dart';

void main() {
  final nostr = exampleNostr();
  final generated = nostr.keys.generateKeyPair();
  const invalidKey = '';

  print(divider('key validity'));
  print('generated private key: ${generated.private}');
  print(
      'generated is valid: ${nostr.keys.isValidPrivateKey(generated.private)}');
  print('empty string is valid: ${nostr.keys.isValidPrivateKey(invalidKey)}');
}
