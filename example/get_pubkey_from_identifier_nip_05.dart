import 'package:dart_nostr/dart_nostr.dart';

Future<void> main() async {
  final puKey = await Nostr.instance.services.utils.pubKeyFromIdentifierNip05(
    internetIdentifier:
        'aljaz@raw.githubusercontent.com/aljazceru/awesome-nostr/main',
  );

  print(puKey);
}
