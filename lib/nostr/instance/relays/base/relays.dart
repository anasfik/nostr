import '../../../model/event.dart';
import '../../../model/request/request.dart';

abstract class NostrRelaysBase {
  void sendEventToRelays(NostrEvent event);

  Stream<NostrEvent> startEventsSubscription({required NostrRequest request});

  void closeEventsSubscription(String subscriptionId);
  void startListeningToRelays({
    required String relay,
    void Function(String relayUrl, dynamic receivedData)? onRelayListening,
    void Function(String relayUrl, Object? error)? onRelayError,
    void Function(String relayUrl)? onRelayDone,
  });
}
