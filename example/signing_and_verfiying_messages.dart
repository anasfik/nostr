import '_example_shared.dart';

void main() {
  final nostr = exampleNostr();

  print(divider('sign / verify'));

  final keyPair = nostr.keys.generateKeyPair();

  const message = 'hello nostr';
  print('message: "$message"');

  final signature = nostr.keys.sign(
    privateKey: keyPair.private,
    message: message,
  );
  print('signature: ${signature.substring(0, 32)}...');

  final isVerified = nostr.keys.verify(
    publicKey: keyPair.public,
    message: message,
    signature: signature,
  );
  print('verified: $isVerified');

  final wrongVerify = nostr.keys.verify(
    publicKey: keyPair.public,
    message: 'different message',
    signature: signature,
  );
  print('wrong message verified: $wrongVerify');
}
