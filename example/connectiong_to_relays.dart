import 'package:dart_nostr/dart_nostr.dart';

Future<void> main() async {
  await Nostr.instance.relaysService.init(
    relaysUrl: <String>["wss://eden.nostr.land"],
  );
}
