import '../../../model/event.dart';
import '../../../model/nostr_events_stream.dart';
import '../../../model/relay_informations.dart';
import '../../../model/request/request.dart';

abstract class NostrRelaysBase {
  Stream<NostrEvent> get stream;
  init({
    required List<String> relaysUrl,
    void Function(String relayUrl, dynamic receivedData)? onRelayListening,
    void Function(String relayUrl, Object? error)? onRelayError,
    void Function(String relayUrl)? onRelayDone,
    bool lazyListeningToRelays = false,
    bool retryOnError = false,
    bool retryOnClose = false,
  });

  void sendEventToRelays(NostrEvent event);

  NostrEventsStream startEventsSubscription({required NostrRequest request});

  void closeEventsSubscription(String subscriptionId);

  void startListeningToRelays({
    required String relay,
    required void Function(String relayUrl, dynamic receivedData)?
        onRelayListening,
    required void Function(String relayUrl, Object? error)? onRelayError,
    required void Function(String relayUrl)? onRelayDone,
    required bool retryOnError,
    required bool retryOnClose,
    required bool shouldReconnectToRelayOnNotice,
    required Duration connectionTimeout,
    required bool ignoreConnectionException,
    required bool lazyListeningToRelays,
  });

  Future<bool> verifyNip05({
    required String internetIdentifier,
    required String pubKey,
  });

  Future<String> pubKeyFromIdentifierNip05({
    required String internetIdentifier,
  });

  Future<RelayInformations> relayInformationsDocumentNip11({
    required String relayUrl,
  });
}
