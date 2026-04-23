import 'dart:convert';

import 'package:dart_nostr/dart_nostr.dart';

import '_example_shared.dart';

// End-to-end demo: keys, relay connection, publish, subscribe, count,
// delete, sign/verify, NIP-05 verification, and error handling.
Future<void> main() async {
  final nostr = exampleNostr(enableLogs: true);

  // keys
  print(divider('keys'));
  final keyPair = nostr.keys.generateKeyPair();
  print('public : ${keyPair.public}');
  print('private: ${keyPair.private}');
  print('valid  : ${NostrKeyPairs.isValidPrivateKey(keyPair.private)}');

  final npub = nostr.bech32.encodePublicKeyToNpub(keyPair.public);
  final nsec = nostr.bech32.encodePrivateKeyToNsec(keyPair.private);
  print('npub   : $npub');
  print('nsec   : $nsec');

  // connect
  print(divider('connect'));
  final connectResult = await nostr.connect(exampleRelays);
  printResult('connect', connectResult);

  for (final relay in exampleRelays) {
    try {
      final info = await nostr.relays
          .relayInformationsDocumentNip11(relayUrl: relay);
      if (info != null) {
        final nips = info.supportedNips?.join(', ') ?? 'none';
        print('$relay -> ${info.name}, NIPs: $nips');
      }
    } catch (e) {
      print('NIP-11 fetch failed for $relay: $e');
    }
  }

  // publish
  print(divider('publish'));

  final metadata = NostrEvent.fromPartialData(
    kind: 0,
    content: jsonEncode({
      'name': 'dart_nostr example',
      'about': 'example run',
    }),
    keyPairs: keyPair,
  );

  final metaResult = await nostr.publish(metadata);
  metaResult.fold(
    (ok) {
      print('metadata accepted: ${ok.isEventAccepted}, message: ${ok.message}');
    },
    (failure) {
      print('metadata failed: ${failure.message} (${failure.code})');
      print('retryable: ${failure.isRetryable}');
    },
  );

  final note = NostrEvent.fromPartialData(
    kind: 1,
    content: 'hello from dart_nostr ${DateTime.now().toIso8601String()}',
    keyPairs: keyPair,
    tags: [
      ['t', 'dart'],
      ['t', 'nostr'],
    ],
  );

  final noteResult = await nostr.publish(note);
  noteResult.fold(
    (ok) => print('note accepted: ${ok.isEventAccepted}'),
    (failure) => print('note failed: ${failure.message}'),
  );

  // subscribe
  print(divider('subscribe'));

  final subResult = nostr.subscribeRequest(
    NostrRequest(
      filters: [
        NostrFilter(
          kinds: [1],
          limit: 10,
          since: DateTime.now().subtract(const Duration(hours: 1)),
        ),
        NostrFilter(
          kinds: [0],
          limit: 5,
          since: DateTime.now().subtract(const Duration(hours: 1)),
        ),
      ],
    ),
  );

  subResult.fold(
    (stream) {
      print('subscription id: ${stream.subscriptionId}');

      var count = 0;

      stream.stream.listen(
        (event) {
          count++;
          final raw = event.content ?? '';
          final preview =
              raw.length > 60 ? '${raw.substring(0, 60)}...' : raw;
          final author = event.pubkey.substring(0, 8);
          print('[$count] kind=${event.kind} author=$author "$preview"');
        },
        onError: (Object e) => print('stream error: $e'),
        onDone: () => print('stream closed, $count events received'),
      );

      Future.delayed(const Duration(seconds: 3), () {
        final stats = nostr.subscriptionStatistics;
        print('active subs: ${nostr.activeSubscriptions.length}');
        print('total events tracked: ${stats.totalEventCount}');
        stream.close();
      });
    },
    (failure) => print('subscribe failed: ${failure.message}'),
  );

  // count (NIP-45)
  print(divider('count'));

  final countResult = await nostr.count(
    NostrCountEvent.fromPartialData(
      eventsFilter: NostrFilter(kinds: [1], limit: 100),
    ),
  );

  countResult.fold(
    (r) => print('count: ${r.count}'),
    (failure) => print('count failed: ${failure.message}'),
  );

  // delete
  print(divider('delete'));

  final deletion = NostrEvent.deleteEvent(
    keyPairs: keyPair,
    reasonOfDeletion: 'cleanup',
    eventIdsToBeDeleted: [note.id ?? ''],
  );

  final deleteResult = await nostr.publish(deletion);
  deleteResult.fold(
    (ok) => print('delete accepted: ${ok.isEventAccepted}'),
    (failure) => print('delete failed: ${failure.message}'),
  );

  // sign / verify
  print(divider('sign / verify'));

  const msg = 'hello nostr';
  final sig = nostr.keys.sign(privateKey: keyPair.private, message: msg);
  final valid = nostr.keys.verify(
    publicKey: keyPair.public,
    message: msg,
    signature: sig,
  );

  print('message  : $msg');
  print('signature: ${sig.substring(0, 32)}...');
  print('valid    : $valid');

  // NIP-05
  print(divider('nip-05'));

  const knownPubkey =
      '32e1827635450ebb3c5a7d12c1f8e7b2b514439ac10a67eef3d9fd9c5c68e245';

  try {
    final verified = await nostr.utils.verifyNip05(
      internetIdentifier: 'jb55@jb55.com',
      pubKey: knownPubkey,
    );
    print('jb55@jb55.com verified: $verified');
  } catch (e) {
    print('nip-05 error: $e');
  }

  // error handling
  print(divider('error handling'));

  final badConnect = await nostr.client.connect(['https://invalid.com']);
  printResult('bad relay url', badConnect);

  final badSub = nostr.subscribeRequest(NostrRequest(filters: []));
  printResult('empty filter', badSub);

  // cleanup
  print(divider('cleanup'));

  nostr.closeAllSubscriptions();

  final disconnectResult = await nostr.disconnect();
  printResult('disconnect', disconnectResult);
}
