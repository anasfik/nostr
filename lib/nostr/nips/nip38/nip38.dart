import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:dart_nostr/nostr/nips/common/tags.dart';
import 'package:dart_nostr/nostr/signers/signer.dart';

/// {@template nostr_user_status}
/// Parsed NIP-38 user status (kind 30315).
///
/// [statusType] is the `d` tag, the status kind such as `general` or `music`.
/// Any other value is allowed; the two common ones are only constants.
///
/// [urls], [pubkeys], [eventIds] and [addresses] keep the `r`, `p`, `e` and
/// `a` tag values in event order. [expiresAt] comes from the `expiration` tag
/// and is `null` when absent or unparseable.
///
/// An empty [content] means the client clears the status (38.md:51).
/// {@endtemplate}
class NostrUserStatus {
  /// {@macro nostr_user_status}
  const NostrUserStatus({
    required this.statusType,
    this.content = '',
    this.urls = const [],
    this.pubkeys = const [],
    this.eventIds = const [],
    this.addresses = const [],
    this.expiresAt,
  });

  /// `d` tag: status type, for example `general` or `music`.
  final String statusType;

  /// Free-form status text; empty clears the status.
  final String content;

  /// `r` tag values (URLs or arbitrary links).
  final List<String> urls;

  /// `p` tag values (profiles).
  final List<String> pubkeys;

  /// `e` tag values (notes).
  final List<String> eventIds;

  /// `a` tag values (addressable events).
  final List<String> addresses;

  /// `expiration` tag as a date-time, or `null`.
  final DateTime? expiresAt;

  /// Whether the status is expired at [now].
  ///
  /// A status without [expiresAt] never expires.
  bool isExpired({DateTime? now}) {
    final expiration = expiresAt;

    if (expiration == null) {
      return false;
    }

    return !expiration.isAfter(now ?? DateTime.now());
  }
}

/// {@template nip38}
/// NIP-38 user statuses (kind 30315).
///
/// Kind 30315 is addressable and uses the `d` tag as the status type. The
/// status is optionally expiring; an `expiration` tag holds UNIX seconds.
///
/// [publish] signs through the signer bound to this instance.
/// {@endtemplate}
class NostrNip38 {
  /// {@macro nip38}
  NostrNip38({required this.signer});

  /// Signer used by [publish].
  final NostrEventSigner signer;

  /// Kind of a user status event.
  static const int statusKind = 30315;

  /// Common status type for general activity.
  static const String generalStatus = 'general';

  /// Common status type for what the user is listening to.
  static const String musicStatus = 'music';

  /// Builds an unsigned kind-30315 status event.
  ///
  /// [statusType] is the `d` tag value (38.md:16) and must not be empty.
  /// [expiresAt] is UNIX seconds
  /// and must not be negative. [pubkeys] must be 64-character lowercase hex
  /// and [addresses] must be valid `kind:pubkey:d` addresses.
  ///
  /// [content] may be empty to clear the status (38.md:51).
  static NostrEvent generateStatusTemplate({
    required String statusType,
    String content = '',
    List<String> urls = const [],
    List<String> pubkeys = const [],
    List<String> eventIds = const [],
    List<String> addresses = const [],
    int? expiresAt,
    DateTime? createdAt,
  }) {
    if (statusType.isEmpty) {
      throw ArgumentError.value(
        statusType,
        'statusType',
        'Status type must not be empty',
      );
    }

    if (expiresAt != null && expiresAt < 0) {
      throw ArgumentError.value(
        expiresAt,
        'expiresAt',
        'Expiration must be a non-negative UNIX timestamp',
      );
    }

    for (final pubkey in pubkeys) {
      if (!NostrValidators.isHex64(pubkey)) {
        throw ArgumentError.value(
          pubkey,
          'pubkeys',
          'Expected 64 lowercase hex characters',
        );
      }
    }

    for (final address in addresses) {
      if (NostrEventAddress.tryParse(address) == null) {
        throw ArgumentError.value(
          address,
          'addresses',
          'Expected a kind:pubkey:d event address',
        );
      }
    }

    return NostrEvent(
      id: null,
      kind: statusKind,
      content: content,
      sig: null,
      pubkey: '',
      createdAt: createdAt ?? DateTime.now(),
      tags: [
        ['d', statusType],
        for (final url in urls) ['r', url],
        for (final pubkey in pubkeys) ['p', pubkey],
        for (final eventId in eventIds) ['e', eventId],
        for (final address in addresses) ['a', address],
        if (expiresAt != null) ['expiration', '$expiresAt'],
      ],
    );
  }

  /// Builds and signs a kind-30315 status event.
  Future<NostrEvent> publish({
    required String statusType,
    String content = '',
    List<String> urls = const [],
    List<String> pubkeys = const [],
    List<String> eventIds = const [],
    List<String> addresses = const [],
    int? expiresAt,
    DateTime? createdAt,
  }) {
    return signer.sign(
      generateStatusTemplate(
        statusType: statusType,
        content: content,
        urls: urls,
        pubkeys: pubkeys,
        eventIds: eventIds,
        addresses: addresses,
        expiresAt: expiresAt,
        createdAt: createdAt,
      ),
    );
  }

  /// Parses [event] into [NostrUserStatus].
  ///
  /// Throws [ArgumentError] for other kinds or a status event without a
  /// non-empty `d` tag.
  static NostrUserStatus parse(NostrEvent event) {
    final parsed = tryParse(event);

    if (parsed == null) {
      throw ArgumentError('Invalid NIP-38 user status event');
    }

    return parsed;
  }

  /// Like [parse], but returns `null` for invalid events.
  static NostrUserStatus? tryParse(NostrEvent event) {
    if (event.kind != statusKind) {
      return null;
    }

    final statusType = NostrTags.first(event.tags, 'd');
    if (statusType == null || statusType.isEmpty) {
      return null;
    }

    final expiration = NostrValidators.tryUnixSeconds(
      NostrTags.first(event.tags, 'expiration'),
    );

    return NostrUserStatus(
      statusType: statusType,
      content: event.content ?? '',
      urls: NostrTags.all(event.tags, 'r'),
      pubkeys: NostrTags.all(event.tags, 'p'),
      eventIds: NostrTags.all(event.tags, 'e'),
      addresses: NostrTags.all(event.tags, 'a'),
      expiresAt: expiration == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(expiration * 1000),
    );
  }

  /// Whether [event] is expired at [timestamp] (UNIX seconds).
  ///
  /// An event without a parseable `expiration` tag never expires. The check
  /// is inclusive: an event expires at its own expiration second.
  static bool isExpired(NostrEvent event, {int? timestamp}) {
    final expiration = NostrValidators.tryUnixSeconds(
      NostrTags.first(event.tags, 'expiration'),
    );

    if (expiration == null) {
      return false;
    }

    final now = timestamp ?? DateTime.now().millisecondsSinceEpoch ~/ 1000;

    return expiration <= now;
  }
}
