import 'dart:convert';

import 'package:dart_nostr/dart_nostr.dart';

import '_example_shared.dart';

/// Complete Nostr Client Workflow Example
///
/// Demonstrates:
/// 1. Key generation and validation
/// 2. Connecting to relays
/// 3. Publishing events with error handling
/// 4. Subscribing to events
/// 5. Counting events (NIP-45)
/// 6. Deleting events
/// 7. Signing & verifying messages
/// 8. NIP-05 verification
/// 9. Error handling
/// 10. Cleanup & disconnect
Future<void> main() async {
  // STEP 1: Initialize Nostr instance
  print(divider('🚀 Nostr Client Initialization'));
  final nostr = exampleNostr(enableLogs: true);
  print('✅ Nostr instance created');

  // STEP 2: Key Generation & Validation
  print(divider('🔑 Key Generation & Validation'));

  final keyPair = nostr.keys.generateKeyPair();
  print('Generated Key Pair:');
  print('  Public Key: ${keyPair.public}');
  print('  Private Key: ${keyPair.private}');

  final isValidPrivateKey =
      NostrKeyPairs.isValidPrivateKey(keyPair.private);
  print('  Valid Private Key: $isValidPrivateKey');

  final npub = nostr.bech32.encodePublicKeyToNpub(keyPair.public);
  final nsec = nostr.bech32.encodePrivateKeyToNsec(keyPair.private);
  print('  Npub: $npub');
  print('  Nsec: $nsec');

  // STEP 3: Connect to Relays
  print(divider('🔗 Connecting to Relays'));

  final connectResult = await nostr.connect(exampleRelays);
  printResult('Connection', connectResult);

  // Get relay info (NIP-11)
  print(divider('ℹ️ Relay Information'));
  for (final relay in exampleRelays) {
    try {
      final relayInfo =
          await nostr.relays.relayInformationsDocumentNip11(relayUrl: relay);
      if (relayInfo != null) {
        print('Relay: $relay');
        print('  Name: ${relayInfo.name ?? 'N/A'}');
        print('  Software: ${relayInfo.software ?? 'N/A'}');
        print(
            '  Supported NIPs: ${relayInfo.supportedNips?.join(', ') ?? 'N/A'}');
      }
    } catch (e) {
      print('  Could not fetch relay info: $e');
    }
  }

  // STEP 4: Publish Events (with typed error handling)
  print(divider('📤 Publishing Events'));

  // Create metadata event
  final metadataEvent = NostrEvent.fromPartialData(
    kind: 0,
    content: jsonEncode({
      'name': 'dart_nostr example',
      'about': 'Complete workflow demo',
    }),
    keyPairs: keyPair,
  );

  final publishMetadataResult = await nostr.publish(metadataEvent);
  publishMetadataResult.fold(
    (ok) {
      print('✅ Metadata published:');
      print('   Event ID: ${ok.eventId}');
      print('   Accepted: ${ok.isEventAccepted}');
      print('   Message: ${ok.message}');
    },
    (failure) {
      print('❌ Metadata publish failed: ${failure.message}');
      print('   Code: ${failure.code}');
      print('   Retryable: ${failure.isRetryable}');
    },
  );

  // Create text note
  final noteEvent = NostrEvent.fromPartialData(
    kind: 1,
    content: 'Hello from dart_nostr! ${DateTime.now().toIso8601String()}',
    keyPairs: keyPair,
    tags: [
      ['t', 'dart'],
      ['t', 'nostr'],
    ],
  );

  final publishNoteResult = await nostr.publish(noteEvent);
  publishNoteResult.fold(
    (ok) {
      print('✅ Note published:');
      print('   Event ID: ${ok.eventId}');
      print('   Accepted: ${ok.isEventAccepted}');
    },
    (failure) {
      print('❌ Note publish failed: ${failure.message}');
    },
  );

  // STEP 5: Subscribe to Events
  print(divider('📥 Subscribing to Events'));

  final subscriptionResult = nostr.subscribeRequest(
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

  subscriptionResult.fold(
    (stream) {
      print('✅ Subscription established');
      print('   Subscription ID: ${stream.subscriptionId}');

      var eventCount = 0;

      stream.stream.listen(
        (event) {
          eventCount++;
          final content = event.content ?? '';
          final contentPreview = content.length > 60
              ? '${content.substring(0, 60)}...'
              : content;
          print('\n📨 Event $eventCount:');
          print('   ID: ${event.id}');
          print('   Kind: ${event.kind}');
          print('   Author: ${event.pubkey.substring(0, 16)}...');
          print('   Content: $contentPreview');
          print('   Tags: ${event.tags?.length ?? 0} tags');
        },
        onError: (Object error) {
          print('❌ Stream error: $error');
        },
        onDone: () {
          print('\n✅ Stream closed. Received $eventCount events.');
        },
      );

      // Show subscription statistics after 3 seconds
      Future.delayed(const Duration(seconds: 3), () {
        final activeSubscriptions = nostr.activeSubscriptions;
        final stats = nostr.subscriptionStatistics;

        print(divider('📊 Subscription Statistics'));
        print('Active Subscriptions: ${activeSubscriptions.length}');
        print('Total Tracked Events: ${stats.totalEventCount}');
        print(
            'Average Events/Sub: ${stats.averageEventsPerSubscription.toStringAsFixed(2)}');

        stream.close();
      });
    },
    (failure) {
      print('❌ Subscription failed: ${failure.message}');
      print('   Code: ${failure.code}');
    },
  );

  // STEP 6: Count Events (NIP-45)
  print(divider('🔢 Counting Events'));

  final countEvent = NostrCountEvent.fromPartialData(
    eventsFilter: NostrFilter(kinds: [1], limit: 100),
  );

  final countResult = await nostr.count(countEvent);
  countResult.fold(
    (countResponse) {
      print('✅ Event count retrieved:');
      print('   Count: ${countResponse.count}');
      print('   Subscription ID: ${countResponse.subscriptionId}');
    },
    (failure) {
      print('❌ Count failed: ${failure.message}');
    },
  );

  // STEP 7: Delete Event
  print(divider('🗑️ Deleting Events'));

  final deleteEvent = NostrEvent.deleteEvent(
    keyPairs: keyPair,
    reasonOfDeletion: 'Example deletion',
    eventIdsToBeDeleted: [
      noteEvent.id ?? '',
    ],
  );

  final deleteResult = await nostr.publish(deleteEvent);
  deleteResult.fold(
    (ok) {
      print('✅ Delete event published:');
      print('   Event ID: ${ok.eventId}');
      print('   Accepted: ${ok.isEventAccepted}');
    },
    (failure) {
      print('❌ Delete failed: ${failure.message}');
    },
  );

  // STEP 8: Sign & Verify Messages
  print(divider('🔐 Sign & Verify Messages'));

  const messageToSign = 'Hello Nostr!';
  final signature = nostr.keys.sign(
    privateKey: keyPair.private,
    message: messageToSign,
  );

  final isVerified = nostr.keys.verify(
    publicKey: keyPair.public,
    message: messageToSign,
    signature: signature,
  );

  print('Message: "$messageToSign"');
  print('Signature: ${signature.substring(0, 32)}...');
  print('Verification: ${isVerified ? '✅ Valid' : '❌ Invalid'}');

  // STEP 9: NIP-05 Verification
  print(divider('✉️ NIP-05 Verification'));

  const testIdentifier = 'jb55@jb55.com';
  const testPublicKey =
      '32e1827635450ebb3c5a7d12c1f8e7b2b514439ac10a67eef3d9fd9c5c68e245';

  try {
    final verified = await nostr.utils.verifyNip05(
      internetIdentifier: testIdentifier,
      pubKey: testPublicKey,
    );
    print('✅ NIP-05 verification: $verified');
  } catch (e) {
    print('⚠️ NIP-05 verification error: $e');
  }

  // STEP 10: Error Handling Examples
  print(divider('⚠️ Error Handling Examples'));

  final invalidConnectResult =
      await nostr.client.connect(['https://invalid.com']);
  printResult('Invalid relay URL', invalidConnectResult);

  final invalidSubscriptionResult = nostr.subscribeRequest(
    NostrRequest(filters: []),
  );
  printResult('Empty subscription', invalidSubscriptionResult);

  // STEP 11: Cleanup & Disconnect
  print(divider('🛑 Cleanup & Disconnect'));

  nostr.closeAllSubscriptions();
  print('✅ All subscriptions closed');

  final disconnectResult = await nostr.disconnect();
  disconnectResult.fold(
    (_) {
      print('✅ Disconnected from all relays');
    },
    (failure) {
      print('⚠️ Disconnect warning: ${failure.message}');
    },
  );

  // Final summary
  print(divider('📋 Workflow Summary'));
  print('✅ Key generation: Complete');
  print('✅ Relay connection: Complete');
  print('✅ Event publishing: Complete');
  print('✅ Event subscription: Complete');
  print('✅ Event counting: Complete');
  print('✅ Event deletion: Complete');
  print('✅ Message signing: Complete');
  print('✅ NIP-05 verification: Complete');
  print('✅ Error handling: Complete');
  print('✅ Cleanup: Complete');
  print('\n🎉 Full Nostr workflow demo completed!');
}
