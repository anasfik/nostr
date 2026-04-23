import '_example_shared.dart';

Future<void> main() async {
  final nostr = exampleNostr(enableLogs: true);

  print(divider('connect'));

  final connectResult = await nostr.connect(exampleRelays);

  connectResult.fold(
    (_) {
      print('connected to all relays');
      print('connected relays: ${nostr.connectedRelays}');
    },
    (failure) {
      print('connection failed: ${failure.message}');
      return;
    },
  );

  print('is connected: ${nostr.isConnected}');
  print('relay count: ${nostr.connectedRelays.length}');

  await Future<void>.delayed(const Duration(seconds: 2));

  final disconnectResult = await nostr.disconnect();
  disconnectResult.fold(
    (_) => print('disconnected'),
    (failure) => print('disconnect warning: ${failure.message}'),
  );
}
