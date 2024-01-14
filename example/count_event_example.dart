import 'package:dart_nostr/dart_nostr.dart';

void main() async {
  // init relays
  final relays = [
    'wss://relay.nostr.band',
    'wss://eden.nostr.land',
    'wss://nostr.fmt.wiz.biz',
    'wss://relay.damus.io',
    'wss://nostr-pub.wellorder.net',
    'wss://relay.nostr.info',
    'wss://offchain.pub',
    'wss://nos.lol',
    'wss://brb.io',
    'wss://relay.snort.social',
    'wss://relay.current.fyi',
    'wss://nostr.relayer.se',
  ];

  final relayThatSupportsNip45 = <String>[];

  for (final relay in relays) {
    final relayInfo =
        await Nostr.instance.relaysService.relayInformationsDocumentNip11(
      relayUrl: relay,
      throwExceptionIfExists: false,
    );
    if (relayInfo?.supportedNips?.contains(45) ?? false) {
      relayThatSupportsNip45.add(relay);
      break;
    }
  }

  if (relayThatSupportsNip45.isEmpty) {
    throw Exception('no relay supports NIP-45');
  }

  await Nostr.instance.relaysService.init(
    relaysUrl: relayThatSupportsNip45,
  );

// create filter for events to count with.
  const filter = NostrFilter(
    kinds: [1],
    t: ['nostr'],
  );

// create the count event.
  final countEvent = NostrCountEvent.fromPartialData(
    eventsFilter: filter,
  );

  Nostr.instance.relaysService.sendCountEventToRelays(
    countEvent,
    onCountResponse: (countRes) {
      print('your filter matches ${countRes.count} events');
    },
  );
}
