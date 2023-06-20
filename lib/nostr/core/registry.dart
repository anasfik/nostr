import 'dart:io';
import 'package:dart_nostr/nostr/model/event.dart';
import 'package:meta/meta.dart';

import 'exceptions.dart';
import 'utils.dart';

@protected

/// This is responsible for registering and retrieving relays [WebSocket]s that are connected to the app.
abstract class NostrRegistry {
  /// This is the registry which will have all relays [WebSocket]s.
  static final _relaysWebSocketsRegistry = <String, WebSocket>{};

  ///  This is the registry which will have all events.
  static final _eventsRegistry = <String, NostrEvent>{};

  /// Registers a [WebSocket] to the registry with the given [relayUrl].
  /// If a [WebSocket] is already registered with the given [relayUrl], it will be replaced.
  static WebSocket registerRelayWebSocket({
    required String relayUrl,
    required WebSocket webSocket,
  }) {
    _relaysWebSocketsRegistry[relayUrl] = webSocket;
    return _relaysWebSocketsRegistry[relayUrl]!;
  }

  /// Returns the [WebSocket] registered with the given [relayUrl].
  static WebSocket? getRelayWebSocket({
    required String relayUrl,
  }) {
    final targetWebSocket = _relaysWebSocketsRegistry[relayUrl];

    if (targetWebSocket != null) {
      final relay = targetWebSocket;

      return relay;
    } else {
      NostrClientUtils.log(
        "No relay is registered with the given url: $relayUrl, did you forget to register it?",
      );

      throw RelayNotFoundException(relayUrl);
    }
  }

  /// Returns all [WebSocket]s registered in the registry.
  static List<MapEntry<String, WebSocket>> allRelaysEntries() {
    return _relaysWebSocketsRegistry.entries.toList();
  }

  /// Clears all registries.
  static void clearAllRegistries() {
    return _relaysWebSocketsRegistry.clear();
  }

  /// Wether a [WebSocket] is registered with the given [relayUrl].
  static bool isRelayRegistered(String relayUrl) {
    return _relaysWebSocketsRegistry.containsKey(relayUrl);
  }

  static bool isEventRegistered(NostrEvent event) {
    return _eventsRegistry.containsKey(eventUniqueId(event));
  }

  static NostrEvent registerEvent(NostrEvent event) {
    _eventsRegistry[eventUniqueId(event)] = event;

    return _eventsRegistry[eventUniqueId(event)]!;
  }

  static String eventUniqueId(NostrEvent event) {
    final eventUniqueId = event.id + event.subscriptionId.toString();

    return eventUniqueId;
  }

  static bool unregisterRelay(String relay) {
    final isUnregistered = _relaysWebSocketsRegistry.remove(relay) != null;

    return isUnregistered;
  }
}
