import 'dart:convert';

import 'package:dart_nostr/dart_nostr.dart';

import '_example_shared.dart';

/// Send events to Nostr relays.
/// Demonstrates publishing metadata and note events with error handling.
Future<void> main() async {
  print(divider('📤 Sending Events Example'));

  final nostr = exampleNostr(enableLogs: true);

  // Connect to relays
  print('✅ Connecting to relays...');
  final connectResult = await nostr.connect(exampleRelays);

  if (connectResult.isFailure) {
    print('❌ Connection failed');
    return;
  }

  // Generate a key pair
  final keyPair = nostr.keys.generateKeyPair();
  print('✅ Generated key pair');

  // Create and send metadata event (kind 0)
  print('\n📝 Sending metadata event...');
  final metadataEvent = NostrEvent.fromPartialData(
    kind: 0,
    content: jsonEncode({
      'name': 'dart_nostr user',
      'about': 'Nostr SDK example',
      'picture': 'https://example.com/pic.jpg',
    }),
    keyPairs: keyPair,
  );

  final metadataResult = await nostr.publish(metadataEvent);
  metadataResult.fold(
    (ok) {
      print('✅ Metadata published:');
      print('   Event ID: ${ok.eventId}');
      print('   Accepted: ${ok.isEventAccepted}');
    },
    (failure) {
      print('❌ Metadata failed: ${failure.message}');
    },
  );

  // Create and send text note (kind 1)
  print('\n📝 Sending text note...');
  final noteEvent = NostrEvent.fromPartialData(
    kind: 1,
    content: 'Hello from dart_nostr! ${DateTime.now()}',
    keyPairs: keyPair,
    tags: [
      ['t', 'nostr'],
      ['t', 'dart'],
    ],
  );

  final noteResult = await nostr.publish(noteEvent);
  noteResult.fold(
    (ok) {
      print('✅ Note published:');
      print('   Event ID: ${ok.eventId}');
      print('   Accepted: ${ok.isEventAccepted}');
    },
    (failure) {
      print('❌ Note failed: ${failure.message}');
    },
  );

  // Disconnect
  print('\n✅ Disconnecting...');
  await nostr.disconnect();

  print('\n${divider()}');
  print('✅ Event sending example completed!');
}
