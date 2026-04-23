---
sidebar_position: 1
description: Connect to Nostr relay WebSockets, manage connection lifecycle, and inspect connection state.
---

# Connecting to Relays

## Basic connection

```dart
final nostr = Nostr.instance;

final result = await nostr.connect([
  'wss://relay.damus.io',
  'wss://nos.lol',
]);

result.fold(
  (_) => print('connected'),
  (failure) => print('failed: ${failure.message}'),
);
```

## Connect with defaults

`connectDefaults` uses a built-in list of well-known public relays:

```dart
await nostr.connectDefaults();
```

## Check connection state

```dart
print(nostr.isConnected);               // bool
print(nostr.connectedRelays);           // List<String>
print(nostr.connectedRelays.length);    // int
```

## Disconnect

```dart
final result = await nostr.disconnect();
result.fold(
  (_) => print('disconnected'),
  (failure) => print('disconnect warning: ${failure.message}'),
);
```

## Configure timeouts and retry

Pass `NostrClientOptions` when constructing an isolated instance (or use the options on `Nostr.instance` before connecting):

```dart
final nostr = Nostr(
  clientOptions: NostrClientOptions(
    connectionTimeout: const Duration(seconds: 10),
    requestTimeout: const Duration(seconds: 15),
    retryPolicy: NostrRetryPolicy.exponential(
      maxAttempts: 4,
      initialDelayMs: 150,
      maxDelayMs: 3000,
    ),
  ),
);

await nostr.connect(['wss://relay.damus.io']);
```

## Relay information (NIP-11)

Fetch a relay's self-description document:

```dart
final info = await nostr.relays.relayInformationsDocumentNip11(
  relayUrl: 'wss://relay.damus.io',
);

if (info != null) {
  print(info.name);
  print(info.description);
  print(info.supportedNips);
  print(info.software);
  print(info.version);
}
```
