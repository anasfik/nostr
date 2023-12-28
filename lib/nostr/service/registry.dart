import 'dart:io';
import 'package:dart_nostr/nostr/model/count.dart';
import 'package:dart_nostr/nostr/model/ok.dart';
import 'package:meta/meta.dart';

import '../core/exceptions.dart';
import '../core/utils.dart';
import '../model/ease.dart';
import '../model/event/event.dart';
import '../model/nostr_event_key.dart';

@protected

/// This is responsible for registering and retrieving relays [WebSocket]s that are connected to the app.
class NostrRegistry {
  NostrRegistry({
    required this.utils,
  });

  final NostrClientUtils utils;

  /// This is the registry which will have all relays [WebSocket]s.
  final relaysWebSocketsRegistry = <String, WebSocket>{};

  ///  This is the registry which will have all events.
  final eventsRegistry = <String, NostrEvent>{};

  /// This is the registry which will have all ok commands callbacks.
  final okCommandCallBacks = <String,
      void Function(
    NostrEventOkCommand ok,
  )?>{};

  /// This is the registry which will have all eose responses callbacks.
  final eoseCommandCallBacks = <String,
      void Function(
    NostrRequestEoseCommand eose,
  )?>{};

  /// This is the registry which will have all count responses callbacks.
  final countResponseCallBacks = <String,
      void Function(
    NostrCountResponse countResponse,
  )>{};

  /// Registers a [WebSocket] to the registry with the given [relayUrl].
  /// If a [WebSocket] is already registered with the given [relayUrl], it will be replaced.
  WebSocket registerRelayWebSocket({
    required String relayUrl,
    required WebSocket webSocket,
  }) {
    relaysWebSocketsRegistry[relayUrl] = webSocket;
    return relaysWebSocketsRegistry[relayUrl]!;
  }

  /// Returns the [WebSocket] registered with the given [relayUrl].
  WebSocket? getRelayWebSocket({
    required String relayUrl,
  }) {
    final targetWebSocket = relaysWebSocketsRegistry[relayUrl];

    if (targetWebSocket != null) {
      final relay = targetWebSocket;

      return relay;
    } else {
      utils.log(
        "No relay is registered with the given url: $relayUrl, did you forget to register it?",
      );

      throw RelayNotFoundException(relayUrl);
    }
  }

  /// Returns all [WebSocket]s registered in the registry.
  List<MapEntry<String, WebSocket>> allRelaysEntries() {
    return relaysWebSocketsRegistry.entries.toList();
  }

  /// Clears all registries.
  void clearAllRegistries() {
    return relaysWebSocketsRegistry.clear();
  }

  /// Wether a [WebSocket] is registered with the given [relayUrl].
  bool isRelayRegistered(String relayUrl) {
    return relaysWebSocketsRegistry.containsKey(relayUrl);
  }

  bool isEventRegistered(NostrEvent event) {
    return eventsRegistry.containsKey(eventUniqueId(event));
  }

  NostrEvent registerEvent(NostrEvent event) {
    eventsRegistry[eventUniqueId(event)] = event;

    return eventsRegistry[eventUniqueId(event)]!;
  }

  String eventUniqueId(NostrEvent event) {
    return event.uniqueKey().toString();
  }

  bool unregisterRelay(String relay) {
    final isUnregistered = relaysWebSocketsRegistry.remove(relay) != null;

    return isUnregistered;
  }

  void registerOkCommandCallBack(
    String associatedEventId,
    void Function(NostrEventOkCommand ok)? onOk,
  ) {
    okCommandCallBacks[associatedEventId] = onOk;
  }

  void Function(
    NostrEventOkCommand ok,
  )? getOkCommandCallBack(String associatedEventIdWithOkCommand) {
    return okCommandCallBacks[associatedEventIdWithOkCommand];
  }

  void registerEoseCommandCallBack(
    String subscriptionId,
    void Function(NostrRequestEoseCommand eose)? onEose,
  ) {
    eoseCommandCallBacks[subscriptionId] = onEose;
  }

  void Function(
    NostrRequestEoseCommand eose,
  )? getEoseCommandCallBack(String subscriptionId) {
    return eoseCommandCallBacks[subscriptionId];
  }

  void registerCountResponseCallBack(
    String subscriptionId,
    void Function(NostrCountResponse countResponse) onCountResponse,
  ) {
    countResponseCallBacks[subscriptionId] = onCountResponse;
  }

  void Function(
    NostrCountResponse countResponse,
  )? getCountResponseCallBack(String subscriptionId) {
    return countResponseCallBacks[subscriptionId];
  }

  void clearWebSocketsRegistry() {
    relaysWebSocketsRegistry.clear();
  }
}
