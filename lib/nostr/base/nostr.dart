import 'package:web_socket_channel/web_socket_channel.dart';

import '../model/event.dart';
import '../model/request/request.dart';

abstract class NostrServiceBase {
  String generateKeys();

  void sendEventToRelays(NostrEvent event);

  Stream<NostrEvent> subscribeToEvents({
    required NostrRequest request,
  });
}
