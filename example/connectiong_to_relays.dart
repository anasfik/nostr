import '_example_shared.dart';

/// Connect to Nostr relays.
/// Demonstrates establishing connections with multiple relay servers.
Future<void> main() async {
  print(divider('🔗 Relay Connection Example'));

  final nostr = exampleNostr(enableLogs: true);

  // Connect to relays using the high-level client API
  print('✅ Connecting to ${exampleRelays.length} relays...');

  final connectResult = await nostr.connect(exampleRelays);

  connectResult.fold(
    (_) {
      print('✅ Successfully connected to all relays');
      print('   Connected relays: ${nostr.connectedRelays}');
    },
    (failure) {
      print('❌ Connection failed: ${failure.message}');
      return;
    },
  );

  // Verify connection status
  print('\n✅ Connection Status:');
  print('   Is Connected: ${nostr.isConnected}');
  print('   Connected Relays: ${nostr.connectedRelays.length}');

  // Keep connection open briefly
  await Future<void>.delayed(const Duration(seconds: 2));

  // Disconnect
  print('\n✅ Disconnecting...');
  final disconnectResult = await nostr.disconnect();
  disconnectResult.fold(
    (_) {
      print('✅ Successfully disconnected from all relays');
    },
    (failure) {
      print('⚠️ Disconnect warning: ${failure.message}');
    },
  );

  print('\n${divider()}');
  print('✅ Connection example completed!');
}
