import 'dart:io';

import 'package:nostr_client/nostr/core/utils.dart';

import '../nostr.dart';

/// This is responsible for registering and retrieving relays [WebSocket]s that are connected to the app.
abstract class NostrRegistry {
  /// This is the registry which will have all relays [WebSocket]s.
  static Map<String, WebSocket> _relaysWebSocketsRegistry = {};

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
      throw Exception("No relay with url $relayUrl found in the registry");
    }
  }

  /// Returns all [WebSocket]s registered in the registry.
  static List<WebSocket> allRelayWebSockets() {
    return _relaysWebSocketsRegistry.values.toList();
  }
}
