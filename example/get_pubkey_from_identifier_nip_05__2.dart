import 'package:dart_nostr/dart_nostr.dart';

void main() async {
  try {
    final publicKeyFromNip05 =
        await Nostr.instance.utilsService.pubKeyFromIdentifierNip05(
      internetIdentifier: 'jb55@jb55.com',
    );

    print('publicKeyFromNip05: $publicKeyFromNip05'); // ...
  } catch (e) {
    print(e);
  }
}
