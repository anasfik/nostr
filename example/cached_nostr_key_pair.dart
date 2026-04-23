import '_example_shared.dart';

void main() {
  final nostr = exampleNostr();
  final generated = nostr.keys.generateKeyPair();
  final cached = nostr.keys.generateKeyPairFromExistingPrivateKey(
    generated.private,
  );

  print(divider('cached key pair'));
  print('generated public: ${generated.public}');
  print('cached public:    ${cached.public}');
  print('same private:     ${generated.private == cached.private}');
}
