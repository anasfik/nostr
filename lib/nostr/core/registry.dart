import 'dart:io';
import 'package:meta/meta.dart';

import 'exceptions.dart';

/// This is responsible for registering and retrieving relays [WebSocket]s that are connected to the app.
@protected
abstract class NostrRegistry {
  /// This is the registry which will have all relays [WebSocket]s.
  static final Map<String, WebSocket> _relaysWebSocketsRegistry = {};

  /// Registers a [WebSocket] to the registry with the given [relayUrl].
  /// If a [WebSocket] is already registered with the given [relayUrl], it will be replaced.
  static void registerRelayWebSocket({
    required String relayUrl,
    required WebSocket webSocket,
  }) {
    _relaysWebSocketsRegistry[relayUrl] = webSocket;
  }

  /// Returns the [WebSocket] registered with the given [relayUrl].
  static WebSocket? getRelayWebSocket({
    required String relayUrl,
  }) {
    final targetWebSocket = _relaysWebSocketsRegistry[relayUrl];

    if (targetWebSocket != null) {
      return _relaysWebSocketsRegistry[relayUrl]!;
    } else {
      throw RelayNotFoundException(relayUrl);
    }
  }

  /// Returns all [WebSocket]s registered in the registry.
  static List<MapEntry<String, WebSocket>> allRelaysEntries() {
    return _relaysWebSocketsRegistry.entries.toList();
  }

  /// Clears all registries.
  static void clearAllRegistries() {
    _relaysWebSocketsRegistry.clear();
  }

  /// Wether a [WebSocket] is registered with the given [relayUrl].
  static bool isRelayRegistered(String relayUrl) {
    return _relaysWebSocketsRegistry.containsKey(relayUrl);
  }
}
