import 'package:dart_nostr/nostr/core/utils.dart';
import 'package:dart_nostr/nostr/instance/connection_pool.dart';
import 'package:dart_nostr/nostr/instance/error_recovery.dart';
import 'package:dart_nostr/nostr/instance/keys/keys.dart';
import 'package:dart_nostr/nostr/instance/relay_pool.dart';
import 'package:dart_nostr/nostr/instance/relays/relays.dart';
import 'package:dart_nostr/nostr/instance/subscription_manager.dart';
import 'package:dart_nostr/nostr/instance/utils/utils.dart';
import 'package:dart_nostr/nostr/nips/nip19/nip19.dart';
import 'package:dart_nostr/nostr/nips/nostr_nips.dart';
import 'package:dart_nostr/nostr/service/client.dart';
import 'package:dart_nostr/nostr/service/client_options.dart';
import 'package:dart_nostr/nostr/service/relay_transport.dart';

class NostrServices {
  NostrServices({
    required this.logger,
    NostrKeys? keys,
    NostrRelays? relays,
    NostrUtils? utils,
    NostrBech32? bech32,
    NostrNips? nips,
    RelayPoolManager? relayPool,
    SubscriptionManager? subscriptionManager,
    ConnectionPoolManager? connectionPool,
    ErrorRecoveryManager? errorRecovery,
    NostrRelayTransport? relayTransport,
    NostrClientOptions clientOptions = const NostrClientOptions(),
  })  : keys = keys ?? NostrKeys(logger: logger),
        relays = relays ?? NostrRelays(logger: logger),
        utils = utils ?? NostrUtils(logger: logger),
        bech32 = bech32 ?? NostrBech32(logger: logger),
        relayPool = relayPool ?? RelayPoolManager(logger: logger),
        subscriptionManager =
            subscriptionManager ?? SubscriptionManager(logger: logger),
        connectionPool =
            connectionPool ?? ConnectionPoolManager(logger: logger),
        errorRecovery = errorRecovery ?? ErrorRecoveryManager(logger: logger),
        relayTransport = relayTransport,
        clientOptions = clientOptions {
    this.nips = nips ?? NostrNips(logger: logger, bech32: this.bech32);
    // Let auto-closing subscriptions also send CLOSE to the relays.
    this.subscriptionManager.onAutoClose ??=
        this.relays.closeEventsSubscription;
  }

  final NostrLogger logger;
  final NostrClientOptions clientOptions;

  final NostrRelayTransport? relayTransport;

  /// {@macro nostr_keys}
  final NostrKeys keys;

  /// {@macro nostr_relays}
  final NostrRelays relays;

  final NostrUtils utils;

  final NostrBech32 bech32;

  /// Per-NIP accessor surface.
  late final NostrNips nips;

  /// {@macro relay_pool_manager}
  final RelayPoolManager relayPool;

  /// {@macro subscription_manager}
  final SubscriptionManager subscriptionManager;

  /// {@macro connection_pool_manager}
  final ConnectionPoolManager connectionPool;

  /// {@macro error_recovery_manager}
  final ErrorRecoveryManager errorRecovery;

  /// Enterprise-grade facade with typed errors and retry behavior.
  late final NostrClient client = NostrClient(
    transport: relayTransport ?? LegacyNostrRelayTransport(relays),
    logger: logger,
    options: clientOptions,
    subscriptionManager: subscriptionManager,
  );
}
