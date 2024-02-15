import 'package:dart_nostr/nostr/core/exceptions.dart';
import 'package:dart_nostr/nostr/core/utils.dart';
import 'package:dart_nostr/nostr/model/count.dart';
import 'package:dart_nostr/nostr/model/ease.dart';
import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:dart_nostr/nostr/model/ok.dart';
import 'package:meta/meta.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

typedef SubscriptionCallback<T>
    = Map<String, void Function(String relay, T callback)>;

typedef RelayCallbackRegister<T> = Map<String, SubscriptionCallback<T>>;

/// {@template nostr_registry}
/// This is responsible for registering and retrieving relays [WebSocket]s that are connected to the app.
/// {@endtemplate}
@protected
class NostrRegistry {
  /// {@macro nostr_registry}
  NostrRegistry({required this.utils});
  final NostrClientUtils utils;

  /// This is the registry which will have all relays [WebSocket]s.
  final relaysWebSocketsRegistry = <String, WebSocketChannel>{};

  ///  This is the registry which will have all events.
  final eventsRegistry = <String, NostrEvent>{};

  /// This is the registry which will have all ok commands callbacks.
  final okCommandCallBacks = RelayCallbackRegister<NostrEventOkCommand>();

  /// This is the registry which will have all eose responses callbacks.
  final eoseCommandCallBacks = RelayCallbackRegister<NostrRequestEoseCommand>();

  /// This is the registry which will have all count responses callbacks.
  final countResponseCallBacks = RelayCallbackRegister<NostrCountResponse>();

  /// Registers a [WebSocket] to the registry with the given [relayUrl].
  /// If a [WebSocket] is already registered with the given [relayUrl], it will be replaced.
  WebSocketChannel registerRelayWebSocket({
    required String relayUrl,
    required WebSocketChannel webSocket,
  }) {
    relaysWebSocketsRegistry[relayUrl] = webSocket;
    return relaysWebSocketsRegistry[relayUrl]!;
  }

  /// Returns the [WebSocket] registered with the given [relayUrl].
  WebSocketChannel? getRelayWebSocket({
    required String relayUrl,
  }) {
    final targetWebSocket = relaysWebSocketsRegistry[relayUrl];

    if (targetWebSocket != null) {
      final relay = targetWebSocket;

      return relay;
    } else {
      utils.log(
        'No relay is registered with the given url: $relayUrl, did you forget to register it?',
      );

      throw RelayNotFoundException(relayUrl);
    }
  }

  /// Returns all [WebSocket]s registered in the registry.
  List<MapEntry<String, WebSocketChannel>> allRelaysEntries() {
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
  void registerOkCommandCallBack({
    required String associatedEventId,
    required void Function(String relay, NostrEventOkCommand ok) onOk,
    required String relay,
  }) {
    final relayOkRegister = getOrCreateRegister(okCommandCallBacks, relay);

    relayOkRegister[associatedEventId] = onOk;
  }

  /// Returns an ok command callback from the registry with the given [associatedEventId].
  void Function(
    String relay,
    NostrEventOkCommand ok,
  )? getOkCommandCallBack({
    required String associatedEventIdWithOkCommand,
    required String relay,
  }) {
    final relayOkRegister = getOrCreateRegister(okCommandCallBacks, relay);

    return relayOkRegister[associatedEventIdWithOkCommand];
  }

  /// Registers an eose command callback to the registry with the given [subscriptionId].
  void registerEoseCommandCallBack({
    required String subscriptionId,
    required void Function(String relay, NostrRequestEoseCommand eose) onEose,
    required String relay,
  }) {
    final relayEoseRegister = getOrCreateRegister(eoseCommandCallBacks, relay);

    relayEoseRegister[subscriptionId] = onEose;
  }

  /// Returns an eose command callback from the registry with the given [subscriptionId].
  void Function(
    String relay,
    NostrRequestEoseCommand eose,
  )? getEoseCommandCallBack({
    required String subscriptionId,
    required String relay,
  }) {
    final relayEoseRegister = getOrCreateRegister(eoseCommandCallBacks, relay);

    return relayEoseRegister[subscriptionId];
  }

  /// Registers a count response callback to the registry with the given [subscriptionId].
  void registerCountResponseCallBack({
    required String subscriptionId,
    required void Function(String relay, NostrCountResponse countResponse)
        onCountResponse,
    required String relay,
  }) {
    final relayCountRegister = countResponseCallBacks[subscriptionId];

    relayCountRegister?[subscriptionId] = onCountResponse;
  }

  /// Returns a count response callback from the registry with the given [subscriptionId].
  void Function(
    String relay,
    NostrCountResponse countResponse,
  )? getCountResponseCallBack({
    required String subscriptionId,
    required String relay,
  }) {
    final relayCountRegister =
        getOrCreateRegister(countResponseCallBacks, relay);

    return relayCountRegister[subscriptionId];
  }

  /// Clears the events registry.
  void clearWebSocketsRegistry() {
    relaysWebSocketsRegistry.clear();
  }

  SubscriptionCallback<T> getOrCreateRegister<T>(
    RelayCallbackRegister<T> register,
    String relay,
  ) {
    final relayRegister = register[relay];

    if (relayRegister == null) {
      register[relay] = <String, void Function(String relay, T callback)>{};
    }

    return register[relay]!;
  }
}
