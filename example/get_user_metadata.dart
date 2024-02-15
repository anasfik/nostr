import 'package:dart_nostr/dart_nostr.dart';

void main() async {
  await Nostr.instance.relaysService.init(
    relaysUrl: ['wss://nos.lol'],
  );

  final request = NostrRequest(
    filters: const <NostrFilter>[
      NostrFilter(
        kinds: [0],
        authors: [
          'aeadd4b4a213c8bf86c63a3b52b5896193815f82122aa2a87ae91d2acaea087d'
        ],
      ),
    ],
  );

  final requestStream = Nostr.instance.relaysService.startEventsSubscription(
    request: request,
    onEose: (relay, ease) {
      print('ease received for subscription id: ${ease.subscriptionId}');

      Nostr.instance.relaysService.closeEventsSubscription(
        ease.subscriptionId,
      );
    },
  );

  requestStream.stream.listen((event) {
    print(event);
  });
}
