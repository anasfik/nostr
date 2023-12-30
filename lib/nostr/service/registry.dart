import 'dart:io';
import 'package:dart_nostr/nostr/model/count.dart';
import 'package:dart_nostr/nostr/model/ok.dart';
import 'package:meta/meta.dart';

import '../core/exceptions.dart';
import '../core/utils.dart';
import '../model/ease.dart';
import '../model/event/event.dart';

/// {@template nostr_registry}
/// This is responsible for registering and retrieving relays [WebSocket]s that are connected to the app.
/// {@endtemplate}
@protected
class NostrRegistry {
  final NostrClientUtils utils;

  /// {@macro nostr_registry}
  NostrRegistry({required this.utils});

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
    relaysWebSocketsRegistry.clear();
    eventsRegistry.clear();
    okCommandCallBacks.clear();
    eoseCommandCallBacks.clear();
    countResponseCallBacks.clear();
  }

  /// Wether a [WebSocket] is registered with the given [relayUrl].
  bool isRelayRegistered(String relayUrl) {
    return relaysWebSocketsRegistry.containsKey(relayUrl);
  }

  /// Wether an event is registered with the given [event].
  bool isEventRegistered(NostrEvent event) {
    return eventsRegistry.containsKey(eventUniqueId(event));
  }

  /// Registers an event to the registry with the given [event].
  NostrEvent registerEvent(NostrEvent event) {
    eventsRegistry[eventUniqueId(event)] = event;

    return eventsRegistry[eventUniqueId(event)]!;
  }

  /// REturns an [event] unique id, See also [NostrEvent.uniqueKey].
  String eventUniqueId(NostrEvent event) {
    return event.uniqueKey().toString();
  }

  /// Removes an event from the registry with the given [event].
  bool unregisterRelay(String relay) {
    final isUnregistered = relaysWebSocketsRegistry.remove(relay) != null;

    return isUnregistered;
  }

  /// Registers an ok command callback to the registry with the given [associatedEventId].
  void registerOkCommandCallBack(
    String associatedEventId,
    void Function(NostrEventOkCommand ok)? onOk,
  ) {
    okCommandCallBacks[associatedEventId] = onOk;
  }

  /// Returns an ok command callback from the registry with the given [associatedEventId].
  void Function(
    NostrEventOkCommand ok,
  )? getOkCommandCallBack(String associatedEventIdWithOkCommand) {
    return okCommandCallBacks[associatedEventIdWithOkCommand];
  }

  /// Registers an eose command callback to the registry with the given [subscriptionId].
  void registerEoseCommandCallBack(
    String subscriptionId,
    void Function(NostrRequestEoseCommand eose)? onEose,
  ) {
    eoseCommandCallBacks[subscriptionId] = onEose;
  }

  /// Returns an eose command callback from the registry with the given [subscriptionId].
  void Function(
    NostrRequestEoseCommand eose,
  )? getEoseCommandCallBack(String subscriptionId) {
    return eoseCommandCallBacks[subscriptionId];
  }

  /// Registers a count response callback to the registry with the given [subscriptionId].
  void registerCountResponseCallBack(
    String subscriptionId,
    void Function(NostrCountResponse countResponse) onCountResponse,
  ) {
    countResponseCallBacks[subscriptionId] = onCountResponse;
  }

  /// Returns a count response callback from the registry with the given [subscriptionId].
  void Function(
    NostrCountResponse countResponse,
  )? getCountResponseCallBack(String subscriptionId) {
    return countResponseCallBacks[subscriptionId];
  }

  /// Clears the events registry.
  void clearWebSocketsRegistry() {
    relaysWebSocketsRegistry.clear();
  }
}
