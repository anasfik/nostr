import 'package:dart_nostr/nostr/core/utils.dart';
import 'package:dart_nostr/nostr/instance/bech32/bech32.dart';
import 'package:dart_nostr/nostr/instance/connection_pool.dart';
import 'package:dart_nostr/nostr/instance/error_recovery.dart';
import 'package:dart_nostr/nostr/instance/keys/keys.dart';
import 'package:dart_nostr/nostr/instance/relay_pool.dart';
import 'package:dart_nostr/nostr/instance/relays/relays.dart';
import 'package:dart_nostr/nostr/instance/subscription_manager.dart';
import 'package:dart_nostr/nostr/instance/utils/utils.dart';

class NostrServices {
  NostrServices({
    required this.logger,
  });
  final NostrLogger logger;

  /// {@macro nostr_keys}
  late final keys = NostrKeys(
    logger: logger,
  );

  /// {@macro nostr_relays}
  late final relays = NostrRelays(
    logger: logger,
  );

  late final utils = NostrUtils(
    logger: logger,
  );

  late final bech32 = NostrBech32(
    logger: logger,
  );

  /// {@macro relay_pool_manager}
  late final relayPool = RelayPoolManager(
    logger: logger,
  );

  /// {@macro subscription_manager}
  late final subscriptionManager = SubscriptionManager(
    logger: logger,
  );

  /// {@macro connection_pool_manager}
  late final connectionPool = ConnectionPoolManager(
    logger: logger,
  );

  /// {@macro error_recovery_manager}
  late final errorRecovery = ErrorRecoveryManager(
    logger: logger,
  );
}
