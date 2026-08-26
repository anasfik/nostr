import 'package:equatable/equatable.dart';

/// NIP-11 relay information document.
///
/// All fields are nullable and parsing never throws: many relays omit most
/// of the document in practice.
class RelayInformations extends Equatable {
  const RelayInformations({
    this.contact,
    this.description,
    this.name,
    this.pubkey,
    this.software,
    this.supportedNips,
    this.supportedNipExtensions = const [],
    this.version,
    this.icon,
    this.postingPolicy,
    this.countryCodes = const [],
    this.languageTags = const [],
    this.tags = const [],
    this.limitation,
    this.fees,
    this.retention = const [],
  });

  factory RelayInformations.fromNip11Response(Map<String, dynamic> json) {
    return RelayInformations(
      contact: _asString(json['contact']),
      description: _asString(json['description']),
      name: _asString(json['name']),
      pubkey: _asString(json['pubkey']),
      software: _asString(json['software']),
      supportedNips: _asIntList(json['supported_nips']),
      supportedNipExtensions: _asStringList(json['supported_nip_extensions']),
      version: _asString(json['version']),
      icon: _asString(json['icon']),
      postingPolicy: _asString(json['posting_policy']),
      countryCodes: _asStringList(json['country_codes']),
      languageTags: _asStringList(json['language_tags']),
      tags: _asStringList(json['tags']),
      limitation: json['limitation'] is Map<String, dynamic>
          ? RelayLimitation.fromNip11Response(
              json['limitation'] as Map<String, dynamic>,
            )
          : null,
      fees: json['fees'] is Map<String, dynamic>
          ? RelayFees.fromNip11Response(json['fees'] as Map<String, dynamic>)
          : null,
      retention: _asRetentionList(json['retention']),
    );
  }

  final String? contact;
  final String? description;
  final String? name;
  final String? pubkey;
  final String? software;
  final List<int>? supportedNips;

  /// NIP extension identifiers beyond the numbered NIPs (e.g. `B7` Blossom).
  final List<String>? supportedNipExtensions;
  final String? version;
  final String? icon;
  final String? postingPolicy;
  final List<String> countryCodes;
  final List<String> languageTags;
  final List<String> tags;
  final RelayLimitation? limitation;
  final RelayFees? fees;
  final List<RelayRetention> retention;

  /// Whether this relay supports the given NIP number.
  bool supportsNip(int nip) => supportedNips?.contains(nip) ?? false;

  static String? _asString(dynamic value) => value is String ? value : null;

  static List<int>? _asIntList(dynamic value) {
    if (value is! List) {
      return null;
    }
    return [
      for (final element in value)
        if (element is int) element else int.tryParse('$element') ?? -1,
    ];
  }

  static List<String> _asStringList(dynamic value) {
    if (value is! List) {
      return const [];
    }
    return [
      for (final element in value)
        if (element != null) '$element'
    ];
  }

  static List<RelayRetention> _asRetentionList(dynamic value) {
    if (value is! List) {
      return const [];
    }
    return [
      for (final element in value)
        if (element is Map<String, dynamic>)
          RelayRetention.fromNip11Response(element),
    ];
  }

  @override
  List<Object?> get props => [
        contact,
        description,
        name,
        pubkey,
        software,
        supportedNips,
        version,
        icon,
        postingPolicy,
        limitation,
        fees,
      ];
}

/// The `limitation` object of a NIP-11 relay information document.
class RelayLimitation extends Equatable {
  const RelayLimitation({
    this.maxMessageLength,
    this.maxSubscriptions,
    this.maxFilters,
    this.maxLimit,
    this.maxSubscriptionIdLength,
    this.maxEventTags,
    this.maxContentLength,
    this.minPow,
    this.authRequired,
    this.paymentRequired,
    this.restrictedWrites,
  });

  factory RelayLimitation.fromNip11Response(Map<String, dynamic> json) {
    return RelayLimitation(
      maxMessageLength: _asInt(json['max_message_length']),
      maxSubscriptions: _asInt(json['max_subscriptions']),
      maxFilters: _asInt(json['max_filters']),
      maxLimit: _asInt(json['max_limit']),
      maxSubscriptionIdLength: _asInt(json['max_subscription_id_length']),
      maxEventTags: _asInt(json['max_event_tags']),
      maxContentLength: _asInt(json['max_content_length']),
      minPow: _asInt(json['min_pow']),
      authRequired: _asBool(json['auth_required']),
      paymentRequired: _asBool(json['payment_required']),
      restrictedWrites: _asBool(json['restricted_writes']),
    );
  }

  final int? maxMessageLength;
  final int? maxSubscriptions;
  final int? maxFilters;
  final int? maxLimit;
  final int? maxSubscriptionIdLength;
  final int? maxEventTags;
  final int? maxContentLength;
  final int? minPow;
  final bool? authRequired;
  final bool? paymentRequired;
  final bool? restrictedWrites;

  static int? _asInt(dynamic value) => value is int ? value : null;

  static bool? _asBool(dynamic value) => value is bool ? value : null;

  @override
  List<Object?> get props => [
        maxMessageLength,
        maxSubscriptions,
        maxFilters,
        maxLimit,
        maxEventTags,
        maxContentLength,
        minPow,
        authRequired,
        paymentRequired,
        restrictedWrites,
      ];
}

/// A fee entry of the `fees` object of a NIP-11 document.
class RelayFee extends Equatable {
  const RelayFee({this.amount, this.unit});

  factory RelayFee.fromNip11Response(Map<String, dynamic> json) {
    return RelayFee(
      amount: json['amount'] is num
          ? (json['amount'] as num).toInt()
          : int.tryParse('${json['amount']}'),
      unit: json['unit'] is String ? json['unit'] as String : null,
    );
  }

  final int? amount;
  final String? unit;

  @override
  List<Object?> get props => [amount, unit];
}

/// The `fees` object of a NIP-11 relay information document.
class RelayFees extends Equatable {
  const RelayFees({
    this.admission = const [],
    this.publication = const [],
  });

  factory RelayFees.fromNip11Response(Map<String, dynamic> json) {
    Iterable<Map<String, dynamic>> feeList(dynamic raw) {
      if (raw is! List) {
        return const [];
      }
      return [
        for (final element in raw)
          if (element is Map<String, dynamic>) element,
      ];
    }

    return RelayFees(
      admission:
          feeList(json['admission']).map(RelayFee.fromNip11Response).toList(),
      publication:
          feeList(json['publication']).map(RelayFee.fromNip11Response).toList(),
    );
  }

  final List<RelayFee> admission;
  final List<RelayFee> publication;

  @override
  List<Object?> get props => [admission, publication];
}

/// A `retention` entry of a NIP-11 relay information document.
class RelayRetention extends Equatable {
  const RelayRetention({this.kinds, this.time});

  factory RelayRetention.fromNip11Response(Map<String, dynamic> json) {
    final rawKinds = json['kinds'];

    return RelayRetention(
      kinds: rawKinds is List
          ? [
              for (final kind in rawKinds)
                if (kind is int) kind,
            ]
          : null,
      time: json['time'] is int ? json['time'] as int : null,
    );
  }

  /// Event kinds covered by this retention policy. `null` means all kinds.
  final List<int>? kinds;

  /// Retention duration in seconds. `0` means "forever", per spec.
  final int? time;

  @override
  List<Object?> get props => [kinds, time];
}
