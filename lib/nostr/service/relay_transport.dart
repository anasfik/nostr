import 'package:dart_nostr/nostr/core/exceptions.dart';
import 'package:dart_nostr/nostr/instance/relays/relays.dart';
import 'package:dart_nostr/nostr/signers/signer.dart';
import 'package:dart_nostr/nostr/model/count.dart';
import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:dart_nostr/nostr/model/nostr_events_stream.dart';
import 'package:dart_nostr/nostr/model/ok.dart';
import 'package:dart_nostr/nostr/model/request/request.dart';

abstract interface class NostrRelayTransport {
  Future<void> connect({
    required List<String> relays,
    required Duration connectionTimeout,
    NostrEventSigner? signer,
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

  /// Connects additional relays at runtime without disturbing existing
  /// connections. Throws when none of the new relays could be reached.
  Future<void> addRelays({
    required List<String> relays,
    required Duration connectionTimeout,
    NostrEventSigner? signer,
  });

  /// Disconnects a single relay at runtime. Returns true when it was
  /// connected.
  Future<bool> removeRelay(String relayUrl);

  Future<bool> disconnect();
}

class LegacyNostrRelayTransport implements NostrRelayTransport {
  LegacyNostrRelayTransport(this.relaysService);

  final NostrRelays relaysService;

  @override
  Future<void> connect({
    required List<String> relays,
    required Duration connectionTimeout,
    NostrEventSigner? signer,
  }) async {
    await relaysService.init(
      relaysUrl: relays,
      connectionTimeout: connectionTimeout,
      retryOnClose: true,
      retryOnError: true,
      signer: signer,
    );

    // Surface real connectivity: if every relay failed (down, DNS, 503…),
    // the caller must see a failure instead of a silently dead session.
    final anyConnected = relaysService.relaysWebSocketsRegistry.keys.any(
      (relay) => relaysService.nostrRegistry
          .isRelayRegisteredAndConnectedSuccesfully(relay),
    );

    if (!anyConnected) {
      throw NostrCoreException(
        'None of the provided relays could be reached. '
        'Check the relay URLs and your network connection.',
      );
    }
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

  @override
  Future<void> addRelays({
    required List<String> relays,
    required Duration connectionTimeout,
    NostrEventSigner? signer,
  }) async {
    await relaysService.connectAdditionalRelays(
      relays,
      connectionTimeout: connectionTimeout,
      signer: signer,
    );

    final anyNewConnected = relays.any(
      (relay) => relaysService.nostrRegistry
          .isRelayRegisteredAndConnectedSuccesfully(relay),
    );

    if (!anyNewConnected) {
      throw NostrCoreException(
        'None of the new relays could be reached: ${relays.join(', ')}',
      );
    }
  }

  @override
  Future<bool> removeRelay(String relayUrl) {
    return relaysService.disconnectFromRelay(relayUrl);
  }
}
