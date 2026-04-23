import 'package:dart_nostr/nostr/instance/relays/relays.dart';
import 'package:dart_nostr/nostr/model/count.dart';
import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:dart_nostr/nostr/model/nostr_events_stream.dart';
import 'package:dart_nostr/nostr/model/ok.dart';
import 'package:dart_nostr/nostr/model/request/request.dart';

abstract interface class NostrRelayTransport {
  Future<void> connect({
    required List<String> relays,
    required Duration connectionTimeout,
  });

  Future<NostrEventOkCommand> publish(
    NostrEvent event, {
    required Duration timeout,
    List<String>? relays,
  });

  Future<NostrCountResponse> count(
    NostrCountEvent countEvent, {
    required Duration timeout,
    List<String>? relays,
  });

  NostrEventsStream subscribe({
    required NostrRequest request,
    List<String>? relays,
  });

  void closeSubscription(String subscriptionId, [String? relay]);

  Future<bool> disconnect();
}

class LegacyNostrRelayTransport implements NostrRelayTransport {
  LegacyNostrRelayTransport(this.relaysService);

  final NostrRelays relaysService;

  @override
  Future<void> connect({
    required List<String> relays,
    required Duration connectionTimeout,
  }) {
    return relaysService.init(
      relaysUrl: relays,
      connectionTimeout: connectionTimeout,
      retryOnClose: true,
      retryOnError: true,
    );
  }

  @override
  Future<NostrEventOkCommand> publish(
    NostrEvent event, {
    required Duration timeout,
    List<String>? relays,
  }) {
    return relaysService.sendEventToRelaysAsync(
      event,
      timeout: timeout,
      relays: relays,
    );
  }

  @override
  Future<NostrCountResponse> count(
    NostrCountEvent countEvent, {
    required Duration timeout,
    List<String>? relays,
  }) {
    return relaysService.sendCountEventToRelaysAsync(
      countEvent,
      timeout: timeout,
      relays: relays,
    );
  }

  @override
  NostrEventsStream subscribe({
    required NostrRequest request,
    List<String>? relays,
  }) {
    return relaysService.startEventsSubscription(
      request: request,
      relays: relays,
      useConsistentSubscriptionIdBasedOnRequestData: true,
    );
  }

  @override
  void closeSubscription(String subscriptionId, [String? relay]) {
    relaysService.closeEventsSubscription(subscriptionId, relay);
  }

  @override
  Future<bool> disconnect() {
    return relaysService.disconnectFromRelays();
  }
}
