import '../model/event.dart';
import '../model/request/request.dart';
import '../core/key_pairs.dart';

abstract class NostrServiceBase {
  void disableLogs();
  void enableLogs();
  String generatePrivateKey();
  NostrKeyPairs generateKeyPair();

  void sendEventToRelays(NostrEvent event);

  Stream<NostrEvent> startEventsSubscription({required NostrRequest request});

  void closeEventsSubscription(String subscriptionId);
}
