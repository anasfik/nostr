import 'dart:async';
import 'dart:convert';

import 'package:dart_nostr/nostr/core/key_pairs.dart';
import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:dart_nostr/nostr/nips/nip04/nip04.dart';
import 'package:dart_nostr/nostr/signers/signer.dart';

/// NIP-47 request methods.
abstract final class Nip47Method {
  /// Pays a BOLT-11 invoice.
  static const String payInvoice = 'pay_invoice';

  /// Pays to a node pubkey (keysend).
  static const String payKeysend = 'pay_keysend';

  /// Creates an invoice on the wallet.
  static const String makeInvoice = 'make_invoice';

  /// Looks up an invoice by payment hash or invoice string.
  static const String lookupInvoice = 'lookup_invoice';

  /// Lists transactions.
  static const String listTransactions = 'list_transactions';

  /// Returns the wallet balance (millisats) and budget info.
  static const String getBalance = 'get_balance';

  /// Returns wallet capabilities and metadata.
  static const String getInfo = 'get_info';
}

/// NIP-47 `encryption` tag values.
abstract final class Nip47Encryption {
  /// NIP-44 v2 payload encryption (required by the current spec).
  static const String nip44V2 = 'nip44_v2';

  /// Legacy NIP-04 payload encryption (deprecated).
  static const String nip04 = 'nip04';
}

/// Standard NIP-47 error codes.
abstract final class Nip47ErrorCode {
  /// Too many requests.
  static const String rateLimited = 'RATE_LIMITED';

  /// Method not supported by the wallet.
  static const String notImplemented = 'NOT_IMPLEMENTED';

  /// Not enough funds.
  static const String insufficientBalance = 'INSUFFICIENT_BALANCE';

  /// The spending budget or quota was exceeded.
  static const String quotaExceeded = 'QUOTA_EXCEEDED';

  /// The connection permissions do not allow this call.
  static const String restricted = 'RESTRICTED';

  /// The client is not authorized.
  static const String unauthorized = 'UNAUTHORIZED';

  /// The request encryption scheme is not supported by the wallet.
  static const String unsupportedEncryption = 'UNSUPPORTED_ENCRYPTION';

  /// Wallet-side failure.
  static const String internal = 'INTERNAL';

  /// The payment failed.
  static const String paymentFailed = 'PAYMENT_FAILED';

  /// Invoice or transaction not found.
  static const String notFound = 'NOT_FOUND';

  /// Any other error.
  static const String other = 'OTHER';
}

/// {@template nwc_connection}
/// Parsed `nostr+walletconnect://` connection string.
/// {@endtemplate}
class NwcConnection {
  /// {@macro nwc_connection}
  const NwcConnection({
    required this.pubkey,
    required this.relays,
    required this.secret,
  });

  /// Parses a NWC connection string.
  ///
  /// Throws [FormatException] when the pubkey, a relay or the secret is
  /// missing.
  factory NwcConnection.parse(String connectionString) {
    final uri = Uri.parse(connectionString);
    final path = uri.path.replaceFirst('/', '');
    final pubkey = path.isNotEmpty ? path : uri.host;
    final relays = uri.queryParametersAll['relay'] ?? const <String>[];
    final secret = uri.queryParameters['secret'];

    if (pubkey.isEmpty || relays.isEmpty || secret == null || secret.isEmpty) {
      throw const FormatException('invalid connection string');
    }

    return NwcConnection(pubkey: pubkey, relays: relays, secret: secret);
  }

  /// Wallet service pubkey (64-char hex).
  final String pubkey;

  /// Relays the wallet listens on.
  final List<String> relays;

  /// Connection secret used to authorize the client.
  final String secret;

  /// First relay, kept for callers that only handle one.
  String get relay => relays.first;

  /// Formats the connection string again.
  String toConnectionString() {
    return Uri(
      scheme: 'nostr+walletconnect',
      host: pubkey,
      queryParameters: {
        'relay': relays,
        'secret': secret,
      },
    ).toString();
  }
}

/// {@template nwc_request}
/// NIP-47 request payload: `{"method","params"}`.
/// {@endtemplate}
class NwcRequest {
  /// {@macro nwc_request}
  const NwcRequest({required this.method, this.params = const {}});

  /// Parses a decrypted request payload.
  factory NwcRequest.fromJson(Map<String, dynamic> json) {
    return NwcRequest(
      method: json['method'] as String,
      params: Map<String, dynamic>.from(
        (json['params'] as Map?) ?? const <String, dynamic>{},
      ),
    );
  }

  /// Parses a JSON request string.
  factory NwcRequest.parse(String raw) {
    return NwcRequest.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  /// Requested method, see [Nip47Method].
  final String method;

  /// Method parameters.
  final Map<String, dynamic> params;

  /// Serializes to the NIP-47 JSON payload.
  String toJson() => jsonEncode({'method': method, 'params': params});
}

/// {@template nwc_error}
/// NIP-47 error object.
/// {@endtemplate}
class NwcError {
  /// {@macro nwc_error}
  const NwcError({required this.code, required this.message});

  /// Parses an error object.
  factory NwcError.fromJson(Map<String, dynamic> json) {
    return NwcError(
      code: json['code'] as String? ?? Nip47ErrorCode.other,
      message: json['message'] as String? ?? '',
    );
  }

  /// Machine-readable code, see [Nip47ErrorCode].
  final String code;

  /// Human-readable message.
  final String message;

  /// Whether the wallet refused the call because of a spending budget.
  bool get isQuotaExceeded => code == Nip47ErrorCode.quotaExceeded;

  @override
  String toString() => 'NwcError($code): $message';
}

/// {@template nwc_response}
/// NIP-47 response payload:
/// `{"result_type","result"}` or `{"result_type","error"}`.
/// {@endtemplate}
class NwcResponse {
  /// {@macro nwc_response}
  const NwcResponse({this.resultType, this.result, this.error});

  /// Parses a decrypted response payload.
  factory NwcResponse.fromJson(Map<String, dynamic> json) {
    final rawResult = json['result'];
    final rawError = json['error'];

    return NwcResponse(
      resultType: json['result_type'] as String?,
      result: rawResult is Map<String, dynamic> ? rawResult : null,
      error:
          rawError is Map<String, dynamic> ? NwcError.fromJson(rawError) : null,
    );
  }

  /// Parses a JSON response string.
  factory NwcResponse.parse(String raw) {
    return NwcResponse.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  /// Method this response answers, e.g. `get_balance`.
  ///
  /// NIP-47 requires this field; it is nullable only so legacy payloads parse.
  final String? resultType;

  /// Success payload, if any.
  final Map<String, dynamic>? result;

  /// Error payload, if any.
  final NwcError? error;

  /// Whether the response carries an error.
  bool get isError => error != null;

  /// Serializes to the NIP-47 JSON payload.
  String toJson() => jsonEncode({
        if (resultType != null) 'result_type': resultType,
        if (result != null) 'result': result,
        if (error != null)
          'error': {
            'code': error!.code,
            'message': error!.message,
          },
      });
}

/// {@template nwc_notification}
/// NIP-47 notification payload: `{"notification":{"type","notification"}}`.
/// {@endtemplate}
class NwcNotification {
  /// {@macro nwc_notification}
  const NwcNotification({required this.type, this.data = const {}});

  /// Parses a decrypted notification payload.
  factory NwcNotification.fromJson(Map<String, dynamic> json) {
    final body = json['notification'];
    final map = body is Map<String, dynamic> ? body : const <String, dynamic>{};
    return NwcNotification(
      type: map['type'] as String? ?? '',
      data: Map<String, dynamic>.from(
        (map['notification'] as Map?) ?? const <String, dynamic>{},
      ),
    );
  }

  /// Parses a JSON notification string.
  factory NwcNotification.parse(String raw) {
    return NwcNotification.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  /// Notification type, e.g. `payment_received`.
  final String type;

  /// Notification body.
  final Map<String, dynamic> data;

  /// Serializes to the NIP-47 JSON payload.
  String toJson() => jsonEncode({
        'notification': {
          'type': type,
          'notification': data,
        },
      });
}

/// Thrown when a NIP-47 call returns an error payload.
class NwcException implements Exception {
  /// Creates an exception carrying the wallet [error].
  const NwcException(this.error);

  /// Wallet error payload.
  final NwcError error;

  /// Whether the wallet refused the call because of a spending budget.
  bool get isQuotaExceeded => error.isQuotaExceeded;

  @override
  String toString() => 'NwcException: $error';
}

/// {@template nip47}
/// NIP-47 Nostr Wallet Connect helpers.
///
/// Builds, signs, encrypts and parses kinds 23194 (request), 23195
/// (response) and 23196 (notification). Payloads are NIP-44 v2 encrypted and
/// requests carry an `encryption` tag with the scheme they use; the wallet
/// pubkey is carried in a `p` tag and responses add an `e` tag with the
/// request event id.
///
/// Relay transport is caller-provided: there is no automatic relay pool or
/// `get_info` discovery here. Use [NostrNip47Client] with any `publish`
/// callback, or publish events through `Nostr.instance.client`.
///
/// NWC clients MUST sign and encrypt with the connection secret from the
/// `nostr+walletconnect://` URI, not the user's identity key. Use
/// [NostrNip47.forConnection] (or [NostrNip47Client.forConnection]) so the
/// wallet can authorize the per-connection pubkey.
///
/// Usage:
/// ```dart
/// final nwc = NwcConnection.parse(connectionString);
/// final nip47 = NostrNip47.forConnection(nwc);
/// final request = await nip47.createRequestEvent(
///   walletPubkey: nwc.pubkey,
///   method: Nip47Method.getBalance,
/// );
/// ```
/// {@endtemplate}
class NostrNip47 {
  /// {@macro nip47}
  NostrNip47({required this.signer});

  /// Creates a signer-bound helper from a parsed NWC connection.
  ///
  /// Derives a [NostrLocalKeySigner] from [NwcConnection.secret], which is the
  /// dedicated per-connection key the wallet authorizes. Never bind the
  /// user's identity signer here: the wallet would reject it with
  /// `UNAUTHORIZED` and payment activity would be linked to the user's key.
  factory NostrNip47.forConnection(NwcConnection connection) {
    return NostrNip47(
      signer: NostrLocalKeySigner(NostrKeyPairs(private: connection.secret)),
    );
  }

  /// Signer used to sign NWC events.
  ///
  /// For clients this must be the connection-secret signer
  /// ([NostrNip47.forConnection]), not the identity key.
  final NostrEventSigner signer;

  /// Reads the `encryption` tag from [event], if present.
  ///
  /// Per NIP-47 an absent tag on a request implies legacy NIP-04.
  static String? encryptionOf(NostrEvent event) {
    for (final tag in event.tags ?? const <List<String>>[]) {
      if (tag.length >= 2 && tag[0] == 'encryption') {
        return tag[1];
      }
    }
    return null;
  }

  /// Kind 23194: wallet request.
  static const int requestKind = 23194;

  /// Kind 23195: wallet response.
  static const int responseKind = 23195;

  /// Kind 23196: wallet notification.
  static const int notificationKind = 23196;

  /// Kind 13194: wallet info (published by the wallet).
  static const int infoKind = 13194;

  /// Every NIP-47 kind.
  static const List<int> kinds = [
    requestKind,
    responseKind,
    notificationKind,
    infoKind,
  ];

  /// Builds and signs a kind-23194 request event for [walletPubkey].
  ///
  /// [encryption] selects the payload scheme and the `encryption` tag value;
  /// NIP-44 v2 is the spec default. Legacy NIP-04 requires a
  /// [NostrLocalKeySigner].
  Future<NostrEvent> createRequestEvent({
    required String walletPubkey,
    required String method,
    Map<String, dynamic> params = const {},
    String encryption = Nip47Encryption.nip44V2,
    DateTime? createdAt,
  }) {
    if (encryption != Nip47Encryption.nip44V2 &&
        encryption != Nip47Encryption.nip04) {
      throw ArgumentError.value(
        encryption,
        'encryption',
        'must be ${Nip47Encryption.nip44V2} or ${Nip47Encryption.nip04}',
      );
    }
    return _sign(
      kind: requestKind,
      remotePubkey: walletPubkey,
      plaintext: NwcRequest(method: method, params: params).toJson(),
      tagEncryption: true,
      encryption: encryption,
      createdAt: createdAt,
    );
  }

  /// Builds and signs a successful kind-23195 response to [request].
  ///
  /// [resultType] is the request method the result answers; NIP-47 requires
  /// it. Pass `request.method` from the decrypted request.
  Future<NostrEvent> createResponseEvent({
    required NostrEvent request,
    required Map<String, dynamic> result,
    String? resultType,
    String encryption = Nip47Encryption.nip44V2,
    DateTime? createdAt,
  }) {
    return _sign(
      kind: responseKind,
      remotePubkey: request.pubkey,
      plaintext: NwcResponse(resultType: resultType, result: result).toJson(),
      encryption: encryption,
      extraTags: [
        ['e', request.id ?? ''],
      ],
      createdAt: createdAt,
    );
  }

  /// Builds and signs an error kind-23195 response to [request].
  Future<NostrEvent> createErrorResponseEvent({
    required NostrEvent request,
    required String code,
    required String message,
    String? resultType,
    String encryption = Nip47Encryption.nip44V2,
    DateTime? createdAt,
  }) {
    return _sign(
      kind: responseKind,
      remotePubkey: request.pubkey,
      plaintext: NwcResponse(
        resultType: resultType,
        error: NwcError(code: code, message: message),
      ).toJson(),
      encryption: encryption,
      extraTags: [
        ['e', request.id ?? ''],
      ],
      createdAt: createdAt,
    );
  }

  /// Builds and signs a kind-23196 notification for [clientPubkey].
  Future<NostrEvent> createNotificationEvent({
    required String clientPubkey,
    required String type,
    Map<String, dynamic> data = const {},
    String encryption = Nip47Encryption.nip44V2,
    DateTime? createdAt,
  }) {
    return _sign(
      kind: notificationKind,
      remotePubkey: clientPubkey,
      plaintext: NwcNotification(type: type, data: data).toJson(),
      encryption: encryption,
      createdAt: createdAt,
    );
  }

  /// Decrypts an incoming request event.
  ///
  /// Uses the event's `encryption` tag when present; absent tags follow the
  /// spec's legacy NIP-04 default, with a NIP-44 attempt first so untagged
  /// NIP-44 clients still interoperate.
  Future<NwcRequest> decryptRequest(NostrEvent event) async {
    return NwcRequest.parse(await _decrypt(event));
  }

  /// Decrypts an incoming response event.
  ///
  /// Responses normally carry no `encryption` tag: NIP-44 is attempted first,
  /// then NIP-04 as a fallback when local key material is available.
  Future<NwcResponse> decryptResponse(NostrEvent event) async {
    return NwcResponse.parse(await _decrypt(event));
  }

  /// Decrypts an incoming notification event.
  Future<NwcNotification> decryptNotification(NostrEvent event) async {
    return NwcNotification.parse(await _decrypt(event));
  }

  Future<String> _decrypt(NostrEvent event) async {
    final payload = event.content ?? '';
    final encryption = encryptionOf(event);
    if (encryption == Nip47Encryption.nip04) {
      return _nip04().decrypt(payload, event.pubkey);
    }
    if (encryption == Nip47Encryption.nip44V2) {
      return signer.nip44Decrypt(payload, event.pubkey);
    }
    // No tag: the spec default is NIP-04, but untagged NIP-44 events exist in
    // the wild, so try NIP-44 first and fall back when local keys are present.
    try {
      return await signer.nip44Decrypt(payload, event.pubkey);
    } on Object {
      final current = signer;
      if (current is NostrLocalKeySigner) {
        return NostrNip04.fromSigner(current).decrypt(payload, event.pubkey);
      }
      rethrow;
    }
  }

  NostrNip04 _nip04() {
    final current = signer;
    if (current is! NostrLocalKeySigner) {
      throw UnsupportedError(
        'NIP-04 encryption requires a NostrLocalKeySigner',
      );
    }
    return NostrNip04.fromSigner(current);
  }

  Future<NostrEvent> _sign({
    required int kind,
    required String remotePubkey,
    required String plaintext,
    List<List<String>> extraTags = const [],
    DateTime? createdAt,
    String encryption = Nip47Encryption.nip44V2,
    bool tagEncryption = false,
  }) async {
    final content = encryption == Nip47Encryption.nip04
        ? _nip04().encrypt(plaintext, remotePubkey)
        : await signer.nip44Encrypt(plaintext, remotePubkey);
    return signer.sign(
      NostrEvent(
        id: null,
        kind: kind,
        content: content,
        sig: null,
        pubkey: signer.publicKey,
        createdAt: createdAt ?? DateTime.now(),
        tags: [
          if (tagEncryption) ['encryption', encryption],
          ['p', remotePubkey],
          ...extraTags,
        ],
      ),
    );
  }
}

/// {@template nip47_client}
/// Minimal NIP-47 client: publishes request events through [publish] and
/// settles pending calls when response events reach [handleEvent].
///
/// Subscribing is the caller's job: listen for kinds 23195/23196 addressed to
/// your pubkey on the wallet's relays and forward every event.
///
/// Usage:
/// ```dart
/// final nwcConnection = NwcConnection.parse(connectionString);
/// final client = NostrNip47Client.forConnection(
///   connection: nwcConnection,
///   publish: (event) => relaySend(event),
/// );
/// final balance = await client.getBalance();
/// ```
/// {@endtemplate}
class NostrNip47Client {
  /// {@macro nip47_client}
  NostrNip47Client({
    required this.nip47,
    required this.walletPubkey,
    required this.publish,
    this.onNotification,
    this.timeout = const Duration(seconds: 60),
  });

  /// Creates a client bound to the connection-secret signer.
  ///
  /// This is the safe default: the wallet authorizes the pubkey derived from
  /// [NwcConnection.secret]. Do not pass an identity-key [NostrNip47] here.
  factory NostrNip47Client.forConnection({
    required NwcConnection connection,
    required Future<void> Function(NostrEvent event) publish,
    void Function(NwcNotification notification)? onNotification,
    Duration timeout = const Duration(seconds: 60),
  }) {
    return NostrNip47Client(
      nip47: NostrNip47.forConnection(connection),
      walletPubkey: connection.pubkey,
      publish: publish,
      onNotification: onNotification,
      timeout: timeout,
    );
  }

  /// Signer-bound NIP-47 helper.
  final NostrNip47 nip47;

  /// Wallet service pubkey.
  final String walletPubkey;

  /// Transport used to publish request events.
  final Future<void> Function(NostrEvent event) publish;

  /// Called for `payment_received` / `payment_sent` notifications.
  final void Function(NwcNotification notification)? onNotification;

  /// How long a call waits for its response.
  final Duration timeout;

  final Map<String, Completer<NwcResponse>> _pending = {};

  /// Sends [method] with [params] and returns the result payload.
  ///
  /// Throws [NwcException] when the wallet answers with an error.
  Future<Map<String, dynamic>> sendRequest(
    String method, [
    Map<String, dynamic> params = const {},
  ]) async {
    final event = await nip47.createRequestEvent(
      walletPubkey: walletPubkey,
      method: method,
      params: params,
    );
    final id = event.id;
    if (id == null) {
      throw StateError('request event was not signed');
    }

    final completer = Completer<NwcResponse>();
    _pending[id] = completer;
    try {
      await publish(event);
      final response = await completer.future.timeout(timeout);
      if (response.error != null) {
        throw NwcException(response.error!);
      }
      return response.result ?? const {};
    } finally {
      _pending.remove(id);
    }
  }

  /// Decrypts a wallet event and settles a pending call or notification.
  Future<bool> handleEvent(NostrEvent event) async {
    if (event.kind == NostrNip47.notificationKind) {
      final NwcNotification notification;
      try {
        notification = await nip47.decryptNotification(event);
      } on Object catch (_) {
        return false;
      }
      onNotification?.call(notification);
      return true;
    }

    if (event.kind != NostrNip47.responseKind) {
      return false;
    }

    final requestId = _eTag(event);
    final completer = requestId == null ? null : _pending[requestId];
    if (completer == null || completer.isCompleted) {
      return false;
    }

    final NwcResponse response;
    try {
      response = await nip47.decryptResponse(event);
    } on Object catch (_) {
      return false;
    }
    completer.complete(response);
    return true;
  }

  /// Pays a BOLT-11 [invoice].
  ///
  /// [amount] is only needed for zero-amount invoices (millisats).
  Future<Map<String, dynamic>> payInvoice(
    String invoice, {
    int? amount,
  }) {
    return sendRequest(Nip47Method.payInvoice, {
      'invoice': invoice,
      if (amount != null) 'amount': amount,
    });
  }

  /// Returns `{"balance": millisats}` for the wallet.
  Future<Map<String, dynamic>> getBalance() {
    return sendRequest(Nip47Method.getBalance);
  }

  /// Returns the wallet's `get_info` capabilities.
  Future<Map<String, dynamic>> getInfo() {
    return sendRequest(Nip47Method.getInfo);
  }

  /// Creates an invoice for [amount] millisats.
  Future<Map<String, dynamic>> makeInvoice({
    required int amount,
    String? description,
    String? descriptionHash,
    int? expiry,
  }) {
    return sendRequest(Nip47Method.makeInvoice, {
      'amount': amount,
      if (description != null) 'description': description,
      if (descriptionHash != null) 'description_hash': descriptionHash,
      if (expiry != null) 'expiry': expiry,
    });
  }

  /// Looks up an invoice by [invoice] or [paymentHash].
  Future<Map<String, dynamic>> lookupInvoice({
    String? invoice,
    String? paymentHash,
  }) {
    if ((invoice == null) == (paymentHash == null)) {
      throw ArgumentError('provide exactly one of invoice or paymentHash');
    }
    return sendRequest(Nip47Method.lookupInvoice, {
      if (invoice != null) 'invoice': invoice,
      if (paymentHash != null) 'payment_hash': paymentHash,
    });
  }

  /// Lists wallet transactions.
  Future<Map<String, dynamic>> listTransactions({
    int? from,
    int? until,
    int? limit,
    int? offset,
    bool? unpaid,
    String? type,
  }) {
    return sendRequest(Nip47Method.listTransactions, {
      if (from != null) 'from': from,
      if (until != null) 'until': until,
      if (limit != null) 'limit': limit,
      if (offset != null) 'offset': offset,
      if (unpaid != null) 'unpaid': unpaid,
      if (type != null) 'type': type,
    });
  }

  /// Pays [amount] millisats to [pubkey] via keysend.
  ///
  /// [tlvRecords] entries are `[type, value]` with an integer TLV type and a
  /// hex string value, for example `[5482373484, '0123...']`.
  Future<Map<String, dynamic>> payKeysend({
    required String pubkey,
    required int amount,
    String? preimage,
    List<List<Object>>? tlvRecords,
  }) {
    return sendRequest(Nip47Method.payKeysend, {
      'pubkey': pubkey,
      'amount': amount,
      if (preimage != null) 'preimage': preimage,
      if (tlvRecords != null)
        'tlv_records': [
          for (final record in tlvRecords)
            {
              'type': record[0] is int
                  ? record[0]
                  : int.parse(record[0].toString()),
              'value': record[1],
            },
        ],
    });
  }

  /// Rejects every pending call.
  void close([String reason = 'client closed']) {
    for (final completer in _pending.values) {
      if (!completer.isCompleted) {
        completer.complete(
          NwcResponse(
            error: NwcError(code: Nip47ErrorCode.internal, message: reason),
          ),
        );
      }
    }
    _pending.clear();
  }

  String? _eTag(NostrEvent event) {
    for (final tag in event.tags ?? const <List<String>>[]) {
      if (tag.length >= 2 && tag[0] == 'e') {
        return tag[1];
      }
    }
    return null;
  }
}
