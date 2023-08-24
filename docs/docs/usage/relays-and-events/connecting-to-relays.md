---
sidebar_position: 2
---


# Managing Relays Connection

## Connecting To Relays

Now you have your relays up and running, and you have your events ready to be sent to them, but how can you send them to your relays?

Before sending any event to your relays, you will need to initialize/connect to your them at least one time in your Dart/Flutter app before sending any event.

```dart
// TODO: add the code here.
```

if you have a Flutter app, I personally recommend you to call this method in the `main()` before the `runApp` is called, so you ensure that the relays are connected before the app starts.

```dart
void main() async {
  await Nostr.instance.relaysService.init(
    relaysUrl: <String>["wss://eden.nostr.land"],
    connectionTimeout: Duration(seconds: 5),
    ensureToClearRegistriesBeforeStarting: true,
    ignoreConnectionException: true,
    lazyListeningToRelays: false,
    onRelayConnectionDone: (relayUrl, relayWebSocket) {
      print("Connected to relay: $relayUrl");
    },
    onRelayListening: (relayUrl, receivedEvent, relayWebSocket) {
      print("Listening to relay: $relayUrl");
    },
    onRelayConnectionError: (relayUrl, error, relayWebSocket) {},
    retryOnClose: true,
    retryOnError: true,
    shouldReconnectToRelayOnNotice: true,
);

// ...

// if it is a flutter app:
// runApp(MyApp());
 }
```

## Reconneting to relays

if you already connected to your relays, and you want to reconnect to them again, you can call the `reconnectToRelays()` method:

```dart
await Nostr.instance.relaysService.reconnectToRelays(
  connectionTimeout: Duration(seconds: 5),
  ignoreConnectionException: true,
  lazyListeningToRelays: false,
  onRelayConnectionDone: (relayUrl, relayWebSocket) {
    print("Connected to relay: $relayUrl");
  },
  onRelayListening: (relayUrl, receivedEvent, relayWebSocket) {
    print("Listening to relay: $relayUrl");
  },
  onRelayConnectionError: (relayUrl, error, relayWebSocket) {},
  retryOnClose: true,
  retryOnError: true,
  shouldReconnectToRelayOnNotice: true,
);
```

## Disconnecting from relays

if you want to disconnect from your relays, you can call the `disconnectFromRelays()` method:

```dart
await Nostr.instance.relaysService.disconnectFromRelays(
  closeCode: (relayUrl) {
    return WebSocketStatus.normalClosure;
  },
  closeReason: (relayUrl) {
    return "Bye";
  },
  onRelayDisconnect: (relayUrl, relayWebSocket, returnedMessage) {
    print("Disconnected from relay: $relayUrl, $returnedMessage");
  },
);

```
