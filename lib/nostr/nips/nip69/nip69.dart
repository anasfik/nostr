import 'dart:convert';

import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:dart_nostr/nostr/nips/common/tags.dart';
import 'package:dart_nostr/nostr/signers/signer.dart';

/// {@template nostr_p2p_order}
/// Parsed NIP-69 peer-to-peer order (kind 38383).
///
/// [orderType] is the `k` tag (`sell` or `buy`), [fiatCurrency] the ISO 4217
/// `f` code and [status] the `s` tag. [fiatAmounts] keeps one value for a
/// fixed-price order and two values (minimum, maximum) for a range order.
/// [ratingJson] is the raw `rating` tag and [rating] its decoded object when
/// the platform wrote valid JSON.
///
/// Parsing never verifies `id`/`sig`: callers must verify signatures with
/// `NostrEvent.isVerified()` when they need authenticity.
/// {@endtemplate}
class NostrP2pOrder {
  /// {@macro nostr_p2p_order}
  const NostrP2pOrder({
    this.id,
    required this.pubkey,
    required this.orderId,
    required this.orderType,
    required this.fiatCurrency,
    required this.status,
    required this.amount,
    required this.fiatAmounts,
    required this.paymentMethods,
    this.premium,
    this.ratingJson,
    this.rating,
    this.source,
    this.network,
    this.layer,
    this.makerName,
    this.geohash,
    this.bond,
    this.expiresAt,
    this.expiration,
    this.platform,
    this.document = NostrNip69.document,
    this.content = '',
    this.tags = const [],
  });

  /// Event id, or `null` for an unsigned template.
  final String? id;

  /// Order author public key.
  final String pubkey;

  /// `d` tag: unique order identifier.
  final String orderId;

  /// `k` tag: `sell` or `buy`.
  final String orderType;

  /// `f` tag: ISO 4217 fiat currency code.
  final String fiatCurrency;

  /// `s` tag: order status.
  final String status;

  /// `amt` tag: bitcoin amount in satoshis; `0` defers to a public API.
  final int amount;

  /// `fa` tag values: one for a fixed amount, two for a range.
  final List<String> fiatAmounts;

  /// `pm` tag values: accepted payment methods.
  final List<String> paymentMethods;

  /// `premium` tag, verbatim.
  final String? premium;

  /// Raw `rating` tag JSON.
  final String? ratingJson;

  /// Decoded `rating` object, or `null` when absent or not a JSON object.
  final Map<String, dynamic>? rating;

  /// `source` tag: URL pointing at the order on its platform.
  final String? source;

  /// `network` tag: `mainnet`, `testnet`, `signet`, ...
  final String? network;

  /// `layer` tag: `onchain`, `lightning`, `liquid`, ...
  final String? layer;

  /// `name` tag: maker display name.
  final String? makerName;

  /// `g` tag: geohash of the trade location.
  final String? geohash;

  /// `bond` tag, verbatim.
  final String? bond;

  /// `expires_at` tag: pending-order expiry in unix seconds.
  final int? expiresAt;

  /// `expiration` tag (NIP-40): relay deletion time in unix seconds.
  final int? expiration;

  /// `y` tag: platform that created the order.
  final String? platform;

  /// `z` tag; NIP-69 fixes it to `order`.
  final String document;

  /// Optional free-form content.
  final String content;

  /// Raw tag list.
  final List<List<String>> tags;

  /// Whether `fa` carries a minimum and a maximum.
  bool get isRange => fiatAmounts.length > 1;

  /// Lower bound of the fiat amount (the only value for a fixed order).
  String? get fiatMin => fiatAmounts.isEmpty ? null : fiatAmounts.first;

  /// Upper bound of the fiat amount, `null` for a fixed order.
  String? get fiatMax => isRange ? fiatAmounts.last : null;

  /// Parses a kind-38383 event, throwing [ArgumentError] when invalid.
  static NostrP2pOrder parse(NostrEvent event) {
    final parsed = tryParse(event);

    if (parsed == null) {
      throw ArgumentError('Invalid NIP-69 peer-to-peer order event');
    }

    return parsed;
  }

  /// Like [parse], returning `null` for invalid events.
  static NostrP2pOrder? tryParse(NostrEvent event) {
    if (event.kind != NostrNip69.kind) {
      return null;
    }

    final tags = event.tags ?? const <List<String>>[];
    final orderId = NostrTags.first(tags, 'd');
    final orderType = NostrTags.first(tags, 'k');
    final fiatCurrency = NostrTags.first(tags, 'f');
    final status = NostrTags.first(tags, 's');
    final document = NostrTags.first(tags, 'z');

    if (orderId == null || orderId.isEmpty) {
      return null;
    }

    if (!NostrNip69.orderTypes.contains(orderType)) {
      return null;
    }

    if (!NostrNip69.isFiatCurrency(fiatCurrency)) {
      return null;
    }

    if (!NostrNip69.statuses.contains(status)) {
      return null;
    }

    if (document != NostrNip69.document) {
      return null;
    }

    final amount = NostrValidators.tryInt(
      NostrTags.first(tags, 'amt'),
      min: 0,
    );
    if (amount == null) {
      return null;
    }

    final fiatTag = NostrTags.tag(tags, 'fa');
    final fiatAmounts = [
      for (final value in NostrTags.tail(fiatTag ?? const <String>[]))
        if (value.trim().isNotEmpty) value,
    ];
    if (fiatAmounts.isEmpty ||
        fiatAmounts.length > 2 ||
        !fiatAmounts.every(NostrNip69.isFiatAmount)) {
      return null;
    }

    final paymentMethods = <String>[];
    for (final tag in tags) {
      if (tag.length < 2 || tag.first != 'pm') {
        continue;
      }

      for (final slot in tag.skip(1)) {
        paymentMethods.addAll(
          slot
              .split(',')
              .map((method) => method.trim())
              .where((method) => method.isNotEmpty),
        );
      }
    }
    if (paymentMethods.isEmpty) {
      return null;
    }

    final ratingJson = NostrTags.first(tags, 'rating');

    return NostrP2pOrder(
      id: event.id,
      pubkey: event.pubkey,
      orderId: orderId,
      orderType: orderType!,
      fiatCurrency: fiatCurrency!,
      status: status!,
      amount: amount,
      fiatAmounts: List<String>.unmodifiable(fiatAmounts),
      paymentMethods: List<String>.unmodifiable(paymentMethods),
      premium: NostrTags.first(tags, 'premium'),
      ratingJson: ratingJson,
      rating: NostrNip69.decodeRating(ratingJson),
      source: NostrTags.first(tags, 'source'),
      network: NostrTags.first(tags, 'network'),
      layer: NostrTags.first(tags, 'layer'),
      makerName: NostrTags.first(tags, 'name'),
      geohash: NostrTags.first(tags, 'g'),
      bond: NostrTags.first(tags, 'bond'),
      expiresAt: NostrValidators.tryUnixSeconds(
        NostrTags.first(tags, 'expires_at'),
      ),
      expiration: NostrValidators.tryUnixSeconds(
        NostrTags.first(tags, 'expiration'),
      ),
      platform: NostrTags.first(tags, 'y'),
      document: document!,
      content: event.content ?? '',
      tags: tags,
    );
  }
}

/// {@template nip69}
/// NIP-69 peer-to-peer order events (kind 38383).
///
/// One liquidity pool for every P2P platform: the `d` tag is the platform
/// order id, `k`/`f`/`s`/`amt`/`fa`/`pm` are mandatory and `z` is always
/// `order`. Optional tags describe the maker, premium, rating, network, layer,
/// geohash, bond and expiration.
///
/// Templates are unsigned; [publish] signs through the bound signer. Parsing
/// is static and never verifies signatures.
/// {@endtemplate}
class NostrNip69 {
  /// {@macro nip69}
  NostrNip69({required this.signer});

  /// Signer used by [publish].
  final NostrEventSigner signer;

  /// Peer-to-peer order kind.
  static const int kind = 38383;

  /// `z` document marker fixed by NIP-69.
  static const String document = 'order';

  /// Accepted `k` order types.
  static const Set<String> orderTypes = {'sell', 'buy'};

  /// Accepted `s` statuses, as enumerated by 69.md at the pinned revision.
  static const Set<String> statuses = {
    'pending',
    'canceled',
    'in-progress',
    'success',
    'expired',
  };

  static final RegExp _fiatCurrency = RegExp(r'^[A-Z]{3}$');

  /// Whether [value] is an uppercase ISO 4217 currency code.
  static bool isFiatCurrency(String? value) =>
      value != null && _fiatCurrency.hasMatch(value);

  /// Whether [value] is a finite numeric fiat amount.
  static bool isFiatAmount(String value) {
    final parsed = double.tryParse(value.trim());

    return parsed != null && parsed.isFinite && parsed >= 0;
  }

  /// Decodes a `rating` tag into an object, or `null` when it is not JSON.
  static Map<String, dynamic>? decodeRating(String? ratingJson) {
    if (ratingJson == null || ratingJson.trim().isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(ratingJson);

      return decoded is Map<String, dynamic> ? decoded : null;
    } on FormatException {
      return null;
    }
  }

  /// Builds an unsigned kind-38383 order.
  ///
  /// Tags are emitted in the order used by the 69.md example: `d`, `k`, `f`,
  /// `s`, `amt`, `fa`, `pm`, then the optional tags, then `z`. A range order
  /// is any call that passes [fiatAmountMax].
  ///
  /// Throws [ArgumentError] when a mandatory value is invalid, when
  /// [fiatAmountMax] is lower than [fiatAmount], or when a timestamp, geohash
  /// or `rating` JSON is malformed.
  static NostrEvent generateOrderTemplate({
    required String orderId,
    required String orderType,
    required String fiatCurrency,
    required String status,
    required int amount,
    required String fiatAmount,
    required List<String> paymentMethods,
    String? fiatAmountMax,
    String? premium,
    String? ratingJson,
    String? source,
    String? network,
    String? layer,
    String? makerName,
    String? geohash,
    String? bond,
    int? expiresAt,
    int? expiration,
    String? platform,
    String content = '',
    DateTime? createdAt,
  }) {
    if (orderId.trim().isEmpty) {
      throw ArgumentError.value(orderId, 'orderId', 'Order id is empty');
    }

    if (!orderTypes.contains(orderType)) {
      throw ArgumentError.value(
        orderType,
        'orderType',
        'Expected sell or buy',
      );
    }

    if (!isFiatCurrency(fiatCurrency)) {
      throw ArgumentError.value(
        fiatCurrency,
        'fiatCurrency',
        'Expected a three-letter uppercase ISO 4217 code',
      );
    }

    if (!statuses.contains(status)) {
      throw ArgumentError.value(status, 'status', 'Unknown order status');
    }

    if (amount < 0) {
      throw ArgumentError.value(
          amount, 'amount', 'Amount must not be negative');
    }

    if (!isFiatAmount(fiatAmount)) {
      throw ArgumentError.value(
        fiatAmount,
        'fiatAmount',
        'Expected a non-negative fiat amount',
      );
    }

    if (fiatAmountMax != null) {
      if (!isFiatAmount(fiatAmountMax)) {
        throw ArgumentError.value(
          fiatAmountMax,
          'fiatAmountMax',
          'Expected a non-negative fiat amount',
        );
      }

      if (double.parse(fiatAmountMax) < double.parse(fiatAmount)) {
        throw ArgumentError.value(
          fiatAmountMax,
          'fiatAmountMax',
          'Range maximum must not be lower than the minimum',
        );
      }
    }

    if (paymentMethods.isEmpty) {
      throw ArgumentError.value(
        paymentMethods,
        'paymentMethods',
        'At least one payment method is required',
      );
    }

    for (final method in paymentMethods) {
      if (method.trim().isEmpty) {
        throw ArgumentError.value(
          method,
          'paymentMethods',
          'Payment method is empty',
        );
      }
    }

    if (premium != null) {
      final parsed = double.tryParse(premium.trim());
      if (parsed == null || !parsed.isFinite) {
        throw ArgumentError.value(
          premium,
          'premium',
          'Expected a numeric premium percentage',
        );
      }
    }

    if (ratingJson != null && decodeRating(ratingJson) == null) {
      throw ArgumentError.value(
        ratingJson,
        'ratingJson',
        'Rating must be a JSON object',
      );
    }

    if (geohash != null && NostrValidators.tryGeohash(geohash) == null) {
      throw ArgumentError.value(geohash, 'geohash', 'Invalid geohash');
    }

    if (bond != null && !isFiatAmount(bond)) {
      throw ArgumentError.value(
        bond,
        'bond',
        'Expected a numeric bond amount',
      );
    }

    if (expiresAt != null && expiresAt < 0) {
      throw ArgumentError.value(
        expiresAt,
        'expiresAt',
        'Timestamp must not be negative',
      );
    }

    if (expiration != null && expiration < 0) {
      throw ArgumentError.value(
        expiration,
        'expiration',
        'Timestamp must not be negative',
      );
    }

    if (source != null && source.trim().isEmpty) {
      throw ArgumentError.value(source, 'source', 'Source is empty');
    }

    if (platform != null && platform.trim().isEmpty) {
      throw ArgumentError.value(platform, 'platform', 'Platform is empty');
    }

    return NostrEvent(
      id: null,
      kind: kind,
      content: content,
      sig: null,
      pubkey: '',
      createdAt: createdAt ?? DateTime.now(),
      tags: [
        ['d', orderId],
        ['k', orderType],
        ['f', fiatCurrency],
        ['s', status],
        ['amt', '$amount'],
        ['fa', fiatAmount, if (fiatAmountMax != null) fiatAmountMax],
        ['pm', ...paymentMethods],
        if (premium != null) ['premium', premium],
        if (ratingJson != null) ['rating', ratingJson],
        if (source != null) ['source', source],
        if (network != null) ['network', network],
        if (layer != null) ['layer', layer],
        if (makerName != null) ['name', makerName],
        if (geohash != null) ['g', geohash],
        if (bond != null) ['bond', bond],
        if (expiresAt != null) ['expires_at', '$expiresAt'],
        if (expiration != null) ['expiration', '$expiration'],
        if (platform != null) ['y', platform],
        ['z', document],
      ],
    );
  }

  /// Signs [event] with the bound signer.
  Future<NostrEvent> publish(NostrEvent event) => signer.sign(event);
}
