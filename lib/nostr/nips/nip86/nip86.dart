import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:dart_nostr/nostr/nips/nip11/nip11.dart';
import 'package:dart_nostr/nostr/signers/signer.dart';
import 'package:http/http.dart' as http;

/// {@template nostr_relay_rpc_response}
/// Raw NIP-86 JSON-RPC response.
///
/// The relay returns `{result, error}`; exactly one is normally populated but
/// the spec does not constrain [result]'s type, so it stays `Object?`
/// (86.md:20-24).
/// {@endtemplate}
class NostrRelayRpcResponse {
  /// {@macro nostr_relay_rpc_response}
  const NostrRelayRpcResponse({this.result, this.error});

  /// Raw `result` value.
  final Object? result;

  /// Optional error message.
  final String? error;

  /// Whether the relay reported an error.
  bool get hasError => error != null && error!.isNotEmpty;
}

/// {@template nostr_relay_management_exception}
/// Error returned by a relay management call.
/// {@endtemplate}
class NostrRelayManagementException implements Exception {
  /// {@macro nostr_relay_management_exception}
  const NostrRelayManagementException(this.message, {this.response});

  /// Error message from the relay, or a transport description.
  final String message;

  /// Raw response, when the relay answered.
  final NostrRelayRpcResponse? response;

  @override
  String toString() => 'NostrRelayManagementException: $message';
}

/// {@template nostr_relay_management_entry}
/// One entry of a `listbanned*`/`listallowed*` result.
///
/// The spec uses `pubkey` for key lists, `id` for event lists and `ip` for IP
/// lists, with an optional `reason` (86.md:38-45, 121-135, 250-258).
/// [key] holds whichever identifier the method returned.
/// {@endtemplate}
class NostrRelayManagementEntry {
  /// {@macro nostr_relay_management_entry}
  const NostrRelayManagementEntry({required this.key, this.reason});

  /// Pubkey, event id or IP address.
  final String key;

  /// Optional reason supplied when the entry was added.
  final String? reason;
}

/// {@template nostr_relay_role}
/// Role payload used by `createrole`/`editrole`.
///
/// Params are positional: `[id, label, description, color, order]`.
/// {@endtemplate}
class NostrRelayManagementRole {
  /// {@macro nostr_relay_role}
  const NostrRelayManagementRole({
    required this.id,
    required this.label,
    this.description = '',
    this.color = '',
    this.order = 0,
  });

  /// Role id.
  final String id;

  /// Human-readable label.
  final String label;

  /// Description.
  final String description;

  /// Color, as understood by the relay.
  final String color;

  /// Display order.
  final int order;

  /// Positional params for the RPC call.
  List<Object?> toParams() => [id, label, description, color, order];
}

/// {@template nip86}
/// NIP-86 relay management JSON-RPC client surface.
///
/// The accessor is signer-bound; call [client] with the management relay URL
/// to get a [NostrRelayManagementClient] shim. Request headers, NIP-98
/// authorization and result typing live on that client.
/// {@endtemplate}
class NostrNip86 {
  /// {@macro nip86}
  NostrNip86({required this.signer});

  /// Signer used by the management clients this object creates.
  final NostrEventSigner signer;

  /// Creates a client for [relayUrl].
  ///
  /// The returned client closes only HTTP clients it created itself; an
  /// injected [httpClient] stays caller-owned.
  NostrRelayManagementClient client({
    required String relayUrl,
    http.Client? httpClient,
  }) =>
      NostrRelayManagementClient(
        relayUrl: relayUrl,
        signer: signer,
        httpClient: httpClient,
      );
}

/// {@template nip86_client}
/// NIP-86 relay management JSON-RPC client.
///
/// Requests are HTTP `POST`s with `Content-Type: application/nostr+json+rpc`
/// to the HTTP(S) form of the relay URL. Every request is authorized with a
/// NIP-98 kind-27235 event whose `u` tag is the relay URL and whose `payload`
/// tag hashes the exact request body (86.md:265-270).
///
/// Result types follow the spec literally. Where the spec is inconsistent
/// (for example `listclaims` returns untyped NIP-43 invite codes, and role
/// result shapes are only described as `true`), the wrapper returns the
/// closest documented type and leaves unmodelled values as `Object?`.
///
/// Usage:
/// ```dart
/// final client = NostrRelayManagementClient(
///   relayUrl: 'wss://relay.example',
///   signer: signer,
/// );
/// final ok = await client.banPubkey(pubkey, reason: 'spam');
/// ```
/// {@endtemplate}
class NostrRelayManagementClient {
  /// {@macro nip86}
  /// Creates a client for NIP-86 calls.
  ///
  /// When [httpClient] is omitted the client creates and owns one; call
  /// [close] to release it. An injected client is caller-owned and is never
  /// closed by this class.
  NostrRelayManagementClient({
    required this.relayUrl,
    required this.signer,
    http.Client? httpClient,
  })  : _ownsHttpClient = httpClient == null,
        _httpClient = httpClient ?? http.Client();

  /// Relay URL used in the NIP-98 `u` tag.
  final String relayUrl;

  /// Signer used to authorize every request.
  final NostrEventSigner signer;

  final http.Client _httpClient;

  /// Whether this client created [_httpClient] and therefore owns it.
  final bool _ownsHttpClient;

  /// Closes the underlying HTTP client when this object created it.
  ///
  /// An injected [http.Client] is caller-owned and is left open.
  void close() {
    if (_ownsHttpClient) {
      _httpClient.close();
    }
  }

  /// Content type required by the spec.
  static const String contentType = 'application/nostr+json+rpc';

  /// HTTP URL that receives the RPC request.
  Uri get httpUri => NostrNip11.httpUri(relayUrl);

  /// Calls any method and returns the raw response.
  ///
  /// [params] is encoded as the JSON `params` array. Throws
  /// [NostrRelayManagementException] on a relay `error` and
  /// [http.ClientException] on non-2xx responses.
  Future<NostrRelayRpcResponse> call(
    String method, {
    List<Object?> params = const <Object?>[],
  }) async {
    if (method.isEmpty) {
      throw ArgumentError.value(method, 'method', 'Method must not be empty');
    }

    final body = jsonEncode({'method': method, 'params': params});
    final authentication = await _authorizationHeader(body);
    final response = await _httpClient.post(
      httpUri,
      headers: {
        'Content-Type': contentType,
        'Accept': contentType,
        'Authorization': authentication,
      },
      body: body,
    );

    if (response.statusCode == 401) {
      throw const NostrRelayManagementException(
        'Relay management endpoint requires valid NIP-98 authorization',
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw http.ClientException(
        'Relay management call failed with status ${response.statusCode}',
        httpUri,
      );
    }

    final decoded = jsonDecode(response.body);

    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Expected a JSON-RPC response object');
    }

    final error = decoded['error'];
    final result = NostrRelayRpcResponse(
      result: decoded['result'],
      error: error is String && error.isNotEmpty ? error : null,
    );

    if (result.hasError) {
      throw NostrRelayManagementException(
        result.error!,
        response: result,
      );
    }

    return result;
  }

  /// Builds the NIP-98 `Authorization` header for [body].
  Future<String> _authorizationHeader(String body) async {
    final event = await signer.sign(
      NostrEvent(
        id: null,
        kind: 27235,
        content: '',
        sig: null,
        pubkey: signer.publicKey,
        createdAt: DateTime.now(),
        tags: [
          ['u', relayUrl],
          const ['method', 'POST'],
          ['payload', sha256.convert(utf8.encode(body)).toString()],
        ],
      ),
    );
    final encoded = base64.encode(utf8.encode(jsonEncode(event.toMap())));

    return 'Nostr $encoded';
  }

  /// `supportedmethods`.
  Future<List<String>> supportedMethods() async {
    final result = await call('supportedmethods');

    return _stringList(result.result, 'supportedmethods');
  }

  /// `banpubkey`: bans [pubkey] and removes it from the allow list.
  Future<bool> banPubkey(String pubkey, {String? reason}) =>
      _boolCall('banpubkey', _pubkeyParams(pubkey, reason));

  /// `unbanpubkey`: removes [pubkey] from the ban list.
  Future<bool> unbanPubkey(String pubkey, {String? reason}) =>
      _boolCall('unbanpubkey', _pubkeyParams(pubkey, reason));

  /// `listbannedpubkeys`.
  Future<List<NostrRelayManagementEntry>> listBannedPubkeys() =>
      _entryCall('listbannedpubkeys', 'pubkey');

  /// `allowpubkey`: allows [pubkey] and removes it from the ban list.
  Future<bool> allowPubkey(String pubkey, {String? reason}) =>
      _boolCall('allowpubkey', _pubkeyParams(pubkey, reason));

  /// `unallowpubkey`: removes [pubkey] from the allow list.
  Future<bool> unallowPubkey(String pubkey, {String? reason}) =>
      _boolCall('unallowpubkey', _pubkeyParams(pubkey, reason));

  /// `listallowedpubkeys`.
  Future<List<NostrRelayManagementEntry>> listAllowedPubkeys() =>
      _entryCall('listallowedpubkeys', 'pubkey');

  /// `createrole`.
  Future<bool> createRole(NostrRelayManagementRole role) =>
      _boolCall('createrole', role.toParams());

  /// `editrole`.
  Future<bool> editRole(NostrRelayManagementRole role) =>
      _boolCall('editrole', role.toParams());

  /// `deleterole`.
  Future<bool> deleteRole(String id) => _boolCall('deleterole', [id]);

  /// `assignrole`.
  Future<bool> assignRole(String pubkey, String roleId) =>
      _boolCall('assignrole', _withPubkey(pubkey, [roleId]));

  /// `unassignrole`.
  Future<bool> unassignRole(String pubkey, String roleId) =>
      _boolCall('unassignrole', _withPubkey(pubkey, [roleId]));

  /// `listclaims`.
  ///
  /// The spec only says "an array of NIP-43 invite codes", so entries stay
  /// unmodelled.
  Future<List<Object?>> listClaims() async {
    final result = await call('listclaims');

    return _objectList(result.result, 'listclaims');
  }

  /// `createclaim`.
  Future<bool> createClaim(Object claim) => _boolCall('createclaim', [claim]);

  /// `deleteclaim`.
  Future<bool> deleteClaim(Object claim) => _boolCall('deleteclaim', [claim]);

  /// `listeventsneedingmoderation`.
  Future<List<NostrRelayManagementEntry>> listEventsNeedingModeration() =>
      _entryCall('listeventsneedingmoderation', 'id');

  /// `allowevent`.
  Future<bool> allowEvent(String eventId, {String? reason}) =>
      _boolCall('allowevent', _eventParams(eventId, reason));

  /// `unallowevent`.
  Future<bool> unallowEvent(String eventId, {String? reason}) =>
      _boolCall('unallowevent', _eventParams(eventId, reason));

  /// `banevent`.
  Future<bool> banEvent(String eventId, {String? reason}) =>
      _boolCall('banevent', _eventParams(eventId, reason));

  /// `unbanevent`.
  Future<bool> unbanEvent(String eventId, {String? reason}) =>
      _boolCall('unbanevent', _eventParams(eventId, reason));

  /// `listbannedevents`.
  Future<List<NostrRelayManagementEntry>> listBannedEvents() =>
      _entryCall('listbannedevents', 'id');

  /// `listallowedevents`.
  Future<List<NostrRelayManagementEntry>> listAllowedEvents() =>
      _entryCall('listallowedevents', 'id');

  /// `changerelayname`.
  Future<bool> changeRelayName(String name) =>
      _boolCall('changerelayname', [name]);

  /// `changerelaydescription`.
  Future<bool> changeRelayDescription(String description) =>
      _boolCall('changerelaydescription', [description]);

  /// `changerelayicon`.
  Future<bool> changeRelayIcon(String iconUrl) =>
      _boolCall('changerelayicon', [iconUrl]);

  /// `allowkind`.
  Future<bool> allowKind(int kind) => _boolCall('allowkind', [kind]);

  /// `disallowkind`.
  Future<bool> disallowKind(int kind) => _boolCall('disallowkind', [kind]);

  /// `listallowedkinds`.
  Future<List<int>> listAllowedKinds() async {
    final result = await call('listallowedkinds');

    return _intList(result.result, 'listallowedkinds');
  }

  /// `listdisallowedkinds`.
  Future<List<int>> listDisallowedKinds() async {
    final result = await call('listdisallowedkinds');

    return _intList(result.result, 'listdisallowedkinds');
  }

  /// `blockip`.
  Future<bool> blockIp(String ip, {String? reason}) =>
      _boolCall('blockip', [ip, if (reason != null) reason]);

  /// `unblockip`.
  Future<bool> unblockIp(String ip) => _boolCall('unblockip', [ip]);

  /// `listblockedips`.
  Future<List<NostrRelayManagementEntry>> listBlockedIps() =>
      _entryCall('listblockedips', 'ip');

  Future<bool> _boolCall(String method, List<Object?> params) async {
    final result = await call(method, params: params);
    final value = result.result;

    if (value is bool) {
      return value;
    }

    throw FormatException('$method expected a boolean result');
  }

  Future<List<NostrRelayManagementEntry>> _entryCall(
    String method,
    String keyField,
  ) async {
    final result = await call(method);

    return _entries(result.result, method, keyField);
  }

  static List<Object?> _pubkeyParams(String pubkey, String? reason) => [
        pubkey,
        if (reason != null) reason,
      ];

  static List<Object?> _eventParams(String eventId, String? reason) => [
        eventId,
        if (reason != null) reason,
      ];

  static List<Object?> _withPubkey(String pubkey, List<Object?> rest) => [
        pubkey,
        ...rest,
      ];

  static bool _isStringList(Object? value) =>
      value is List && value.every((entry) => entry is String);

  static List<String> _stringList(Object? value, String method) {
    if (!_isStringList(value)) {
      throw FormatException('$method expected an array of strings');
    }

    return List<String>.from(value! as List);
  }

  static List<Object?> _objectList(Object? value, String method) {
    if (value is! List) {
      throw FormatException('$method expected an array');
    }

    return List<Object?>.of(value);
  }

  static List<int> _intList(Object? value, String method) {
    if (value is! List || !value.every((entry) => entry is int)) {
      throw FormatException('$method expected an array of numbers');
    }

    return value.cast<int>();
  }

  static List<NostrRelayManagementEntry> _entries(
    Object? value,
    String method,
    String keyField,
  ) {
    if (value is! List) {
      throw FormatException('$method expected an array of objects');
    }

    return [
      for (final entry in value)
        if (entry is Map)
          NostrRelayManagementEntry(
            key:
                '${entry[keyField] ?? entry['pubkey'] ?? entry['id'] ?? entry['ip'] ?? ''}',
            reason:
                entry['reason'] is String ? entry['reason'] as String : null,
          )
        else
          throw FormatException('$method expected an array of objects'),
    ];
  }
}
