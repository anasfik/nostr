import 'package:dart_nostr/dart_nostr.dart';

void main(List<String> args) async {
  await Nostr.instance.relaysService.init(relaysUrl: [
    "wss://relay.damus.io",
  ]);

  try {
    final request = NostrRequest(
      filters: [
        NostrFilter(
          limit: 30,
          kinds: [1],
        ),
      ],
    );

    final events =
        await Nostr.instance.relaysService.startEventsSubscriptionAsync(
      request: request,
      timeout: Duration(seconds: 10),
      shouldThrowErrorOnTimeoutWithoutEose: true,
    );

    events.forEach((element) {
      print('${element.content}\n\n');
    });
  } catch (e) {
    print(e);
  }
}
