import 'dart:io';

import '../../../model/count.dart';
import '../../../model/ease.dart';
import '../../../model/event/event.dart';
import '../../../model/nostr_events_stream.dart';
import '../../../model/ok.dart';
import '../../../model/relay_informations.dart';
import '../../../model/request/request.dart';

abstract class NostrRelaysBase {
  // Stream<NostrEvent> get eventsStream;
  // Stream<NostrNotice> get noticesStream;
  Map<String, WebSocket> get relaysWebSocketsRegistry;
  Map<String, NostrEvent> get eventsRegistry;

  List<String>? relaysList;

  init({
    required List<String> relaysUrl,
    void Function(
      String relayUrl,
      dynamic receivedData,
      WebSocket? relayWebSocket,
    )? onRelayListening,
    void Function(
      String relayUrl,
      Object? error,
      WebSocket? relayWebSocket,
    )? onRelayConnectionError,
    void Function(
      String relayUrl,
      WebSocket? relayWebSocket,
    )? onRelayConnectionDone,
    bool lazyListeningToRelays = false,
    bool retryOnError = false,
    bool retryOnClose = false,
  });

  Future<NostrEventOkCommand> sendEventToRelaysAsync(
    NostrEvent event, {
    required Duration timeout,
    void Function(NostrEventOkCommand ok)? onOk,
  });

  void sendEventToRelays(
    NostrEvent event, {
    required void Function(NostrEventOkCommand ok) onOk,
  });

  void sendCountEventToRelays(
    NostrCountEvent countEvent, {
    required void Function(NostrCountResponse NostrCountResponse)
        onCountResponse,
  });

  NostrEventsStream startEventsSubscription({
    required NostrRequest request,
    void Function(NostrRequestEoseCommand ease)? onEose,
  });

  Future<List<NostrEvent>> startEventsSubscriptionAsync({
    required NostrRequest request,
    required Duration timeout,
    void Function(NostrRequestEoseCommand ease)? onEose,
    bool useConsistentSubscriptionIdBasedOnRequestData = false,
    bool shouldThrowErrorOnTimeoutWithoutEose = true,
  });

  void closeEventsSubscription(String subscriptionId);

  void startListeningToRelay({
    required String relay,
    required void Function(
            String relayUrl, dynamic receivedData, WebSocket? relayWebSocket)?
        onRelayListening,
    required void Function(
            String relayUrl, Object? error, WebSocket? relayWebSocket)?
        onRelayConnectionError,
    required void Function(String relayUrl, WebSocket? relayWebSocket)?
        onRelayConnectionDone,
    required bool retryOnError,
    required bool retryOnClose,
    required bool shouldReconnectToRelayOnNotice,
    required Duration connectionTimeout,
    required bool ignoreConnectionException,
    required bool lazyListeningToRelays,
  });

  Future<RelayInformations?> relayInformationsDocumentNip11({
    required String relayUrl,
    bool throwExceptionIfExists,
  });
  Future<void> reconnectToRelays({
    required void Function(
            String relayUrl, dynamic receivedData, WebSocket? relayWebSocket)?
        onRelayListening,
    required void Function(
            String relayUrl, Object? error, WebSocket? relayWebSocket)?
        onRelayConnectionError,
    required void Function(String relayUrl, WebSocket? relayWebSocket)?
        onRelayConnectionDone,
    required bool retryOnError,
    required bool retryOnClose,
    required bool shouldReconnectToRelayOnNotice,
    required Duration connectionTimeout,
    required bool ignoreConnectionException,
    required bool lazyListeningToRelays,
    bool relayUnregistered = true,
  });
}
