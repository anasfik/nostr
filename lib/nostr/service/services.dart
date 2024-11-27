import 'package:dart_nostr/nostr/core/utils.dart';
import 'package:dart_nostr/nostr/instance/bech32/bech32.dart';
import 'package:dart_nostr/nostr/instance/keys/keys.dart';
import 'package:dart_nostr/nostr/instance/relays/relays.dart';
import 'package:dart_nostr/nostr/instance/utils/utils.dart';

class NostrServices {
  final NostrLogger logger;

  NostrServices({
    required this.logger,
  });

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
}
