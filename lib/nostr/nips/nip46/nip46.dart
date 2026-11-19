import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:dart_nostr/nostr/signers/signer.dart';

/// NIP-46 method names used by the remote-signer RPC.
abstract final class Nip46Method {
  /// Liveness check; answers `pong`.
  static const String ping = 'ping';

  /// Approves the client with the remote signer.
  static const String connect = 'connect';

  /// Returns the pubkey the remote signer signs for.
  static const String getPublicKey = 'get_public_key';

  /// Signs an event template passed as JSON.
  static const String signEvent = 'sign_event';

  /// Encrypts with legacy NIP-04.
  static const String nip04Encrypt = 'nip04_encrypt';

  /// Decrypts with legacy NIP-04.
  static const String nip04Decrypt = 'nip04_decrypt';

  /// Encrypts with NIP-44.
  static const String nip44Encrypt = 'nip44_encrypt';

  /// Decrypts with NIP-44.
  static const String nip44Decrypt = 'nip44_decrypt';

  /// Ends the remote session.
  static const String logout = 'logout';

  /// Asks the signer to switch relays.
  static const String switchRelays = 'switch_relays';
}

/// {@template nip46_request}
/// NIP-46 RPC request envelope: `{"id","method","params"}`.
/// {@endtemplate}
class Nip46Request {
  /// {@macro nip46_request}
  const Nip46Request({
    required this.id,
    required this.method,
    this.params = const [],
  });

  /// Parses a decrypted request payload.
  factory Nip46Request.fromJson(Map<String, dynamic> json) {
    return Nip46Request(
      id: json['id'] as String,
      method: json['method'] as String,
      params: List<String>.from(
        (json['params'] as List?) ?? const <String>[],
      ),
    );
  }

  /// Parses a JSON request string.
  factory Nip46Request.parse(String raw) {
    return Nip46Request.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  /// Correlation id chosen by the client.
  final String id;

  /// RPC method, see [Nip46Method].
  final String method;

  /// Positional string parameters.
  final List<String> params;

  /// Serializes to the NIP-46 JSON envelope.
  String toJson() => jsonEncode({
        'id': id,
        'method': method,
        'params': params,
      });

  /// Decoded envelope.
  Map<String, dynamic> toMap() => {
        'id': id,
        'method': method,
        'params': params,
      };
}

/// {@template nip46_response}
/// NIP-46 RPC response envelope: `{"id","result"}` or `{"id","error"}`.
/// {@endtemplate}
class Nip46Response {
  /// {@macro nip46_response}
  const Nip46Response({
    required this.id,
    this.result,
    this.error,
  });

  /// Parses a decrypted response payload.
  factory Nip46Response.fromJson(Map<String, dynamic> json) {
    return Nip46Response(
      id: json['id'] as String,
      result: json['result'] as String?,
      error: json['error'] as String?,
    );
  }

  /// Parses a JSON response string.
  factory Nip46Response.parse(String raw) {
    return Nip46Response.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  /// Correlation id copied from the request.
  final String id;

  /// Result string, if the call succeeded.
  final String? result;

  /// Error message, if the call failed.
  final String? error;

  /// Serializes to the NIP-46 JSON envelope.
  String toJson() => jsonEncode({
        'id': id,
        if (result != null) 'result': result,
        if (error != null) 'error': error,
      });
}

/// Thrown when a NIP-46 call returns an error payload.
class Nip46Exception implements Exception {
  /// Creates an exception carrying the remote [message].
  const Nip46Exception(this.message);

  /// Remote error message.
  final String message;

  @override
  String toString() => 'Nip46Exception: $message';
}

/// {@template nip46_bunker_pointer}
/// Parsed `bunker://` connection target.
/// {@endtemplate}
class Nip46BunkerPointer {
  /// {@macro nip46_bunker_pointer}
  const Nip46BunkerPointer({
    required this.pubkey,
    required this.relays,
    this.secret,
  });

  /// Remote signer pubkey (64-char hex).
  final String pubkey;

  /// Relays the signer listens on.
  final List<String> relays;

  /// Optional connection secret.
  final String? secret;
}

/// {@template nip46}
/// NIP-46 Nostr Connect (remote signer / bunker) helpers.
///
/// Request and response events use kind 24133, tagged `p` with the remote
/// party and encrypted with NIP-44. This class only builds, signs, encrypts
/// and parses those events: relay transport is the caller's job. Use
/// [NostrNip46Client] for request/response correlation over any `publish`
/// callback, or hand the events to `Nostr.instance.client.publish`.
///
/// There is no automatic relay rendezvous pool or NIP-05 bunker discovery
/// here; connect a relay yourself and subscribe to
/// `{kinds: [24133], '#p': [clientPubkey]}`.
///
/// Usage:
/// ```dart
/// final nip46 = Nostr.instance.nips.nip46;
/// final event = await nip46.createRequestEvent(
///   remotePubkey: bunkerPubkey,
///   method: Nip46Method.ping,
/// );
/// // publish `event`, feed the reply to nip46.decryptResponse().
/// ```
/// {@endtemplate}
class NostrNip46 {
  /// {@macro nip46}
  NostrNip46({required this.signer});

  /// Signer used to sign kind-24133 events.
  final NostrEventSigner signer;

  /// NIP-46 event kind.
  static const int kind = 24133;

  /// Kind 24133 (request and response share it).
  static const List<int> kinds = [kind];

  static final RegExp _bunkerRegex =
      RegExp(r'^bunker://([0-9a-f]{64})\??([?/\w:.=&%-]*)$');

  static final Random _random = Random.secure();

  /// Builds and signs a kind-24133 request event for [remotePubkey].
  Future<NostrEvent> createRequestEvent({
    required String remotePubkey,
    required String method,
    List<String> params = const [],
    String? id,
    DateTime? createdAt,
  }) {
    final request = Nip46Request(
      id: id ?? newId(),
      method: method,
      params: params,
    );
    return _sign(
      remotePubkey: remotePubkey,
      plaintext: request.toJson(),
      createdAt: createdAt,
    );
  }

  /// Decrypts an incoming request event authored by the remote signer.
  Future<Nip46Request> decryptRequest(NostrEvent event) async {
    final plaintext = await signer.nip44Decrypt(
      event.content ?? '',
      event.pubkey,
    );
    return Nip46Request.parse(plaintext);
  }

  /// Builds and signs the response to [request].
  ///
  /// [remotePubkey] is the requester's pubkey (the `pubkey` of the request
  /// event). Set exactly one of [result] or [error].
  Future<NostrEvent> createResponseEvent({
    required Nip46Request request,
    required String remotePubkey,
    String? result,
    String? error,
    DateTime? createdAt,
  }) {
    if ((result == null) == (error == null)) {
      throw ArgumentError('provide exactly one of result or error');
    }

    final response = Nip46Response(
      id: request.id,
      result: result,
      error: error,
    );
    return _sign(
      remotePubkey: remotePubkey,
      plaintext: response.toJson(),
      createdAt: createdAt,
    );
  }

  /// Decrypts an incoming response event authored by the remote signer.
  Future<Nip46Response> decryptResponse(NostrEvent event) async {
    final plaintext = await signer.nip44Decrypt(
      event.content ?? '',
      event.pubkey,
    );
    return Nip46Response.parse(plaintext);
  }

  /// Generates a fresh correlation id.
  String newId() {
    final prefix =
        List.generate(6, (_) => _random.nextInt(16).toRadixString(16)).join();
    return '$prefix-${DateTime.now().microsecondsSinceEpoch}';
  }

  /// Parses a `bunker://` URL.
  ///
  /// NIP-05 bunker discovery needs HTTP and is not implemented here; pass a
  /// `bunker://` URL instead. Throws [FormatException] for invalid input.
  static Nip46BunkerPointer parseBunkerUrl(String input) {
    final match = _bunkerRegex.firstMatch(input);
    if (match == null) {
      // Never echo [input]: it carries the connect secret.
      throw const FormatException('invalid bunker url');
    }

    final query = Uri.parse('bunker://x?${match.group(2) ?? ''}');
    return Nip46BunkerPointer(
      pubkey: match.group(1)!,
      relays: query.queryParametersAll['relay'] ?? const [],
      secret: query.queryParameters['secret'],
    );
  }

  /// Formats [pointer] as a `bunker://` URL.
  static String toBunkerUrl(Nip46BunkerPointer pointer) {
    return Uri(
      scheme: 'bunker',
      host: pointer.pubkey,
      queryParameters: {
        if (pointer.relays.isNotEmpty) 'relay': pointer.relays,
        if (pointer.secret != null) 'secret': pointer.secret,
      },
    ).toString();
  }

  /// Builds a `nostrconnect://` URI for the client to display as a QR code.
  static String createNostrConnectUri({
    required String clientPubkey,
    required List<String> relays,
    required String secret,
    List<String>? perms,
    String? name,
    String? url,
    String? image,
  }) {
    return Uri(
      scheme: 'nostrconnect',
      host: clientPubkey,
      queryParameters: {
        if (relays.isNotEmpty) 'relay': relays,
        'secret': secret,
        if (perms != null && perms.isNotEmpty) 'perms': perms.join(','),
        if (name != null) 'name': name,
        if (url != null) 'url': url,
        if (image != null) 'image': image,
      },
    ).toString();
  }

  Future<NostrEvent> _sign({
    required String remotePubkey,
    required String plaintext,
    DateTime? createdAt,
  }) async {
    final content = await signer.nip44Encrypt(plaintext, remotePubkey);
    return signer.sign(
      NostrEvent(
        id: null,
        kind: kind,
        content: content,
        sig: null,
        pubkey: signer.publicKey,
        createdAt: createdAt ?? DateTime.now(),
        tags: [
          ['p', remotePubkey],
        ],
      ),
    );
  }
}

/// {@template nip46_client}
/// Minimal NIP-46 client: publishes request events through [publish] and
/// completes pending calls when response events are handed to [handleEvent].
///
/// Callers subscribe to kind 24133 events addressed to their pubkey and pass
/// every event to [handleEvent]; unmatched events are ignored.
///
/// Usage:
/// ```dart
/// final client = NostrNip46Client(
///   nip46: Nostr.instance.nips.nip46,
///   remotePubkey: bunkerPubkey,
///   publish: (event) => relaySend(event),
/// );
/// await client.ping();
/// ```
/// {@endtemplate}
class NostrNip46Client {
  /// {@macro nip46_client}
  NostrNip46Client({
    required this.nip46,
    required this.remotePubkey,
    required this.publish,
    this.secret,
    this.timeout = const Duration(seconds: 30),
  });

  /// Signer-bound NIP-46 helper.
  final NostrNip46 nip46;

  /// Remote signer pubkey.
  final String remotePubkey;

  /// Transport used to publish request events.
  final Future<void> Function(NostrEvent event) publish;

  /// Optional connect secret from the bunker pointer.
  final String? secret;

  /// How long [send] waits for a response.
  final Duration timeout;

  final Map<String, Completer<String>> _pending = {};
  String? _publicKey;

  /// Sends [method] and returns its result string.
  Future<String> send(String method, [List<String> params = const []]) async {
    final id = nip46.newId();
    final completer = Completer<String>();
    _pending[id] = completer;

    try {
      final event = await nip46.createRequestEvent(
        remotePubkey: remotePubkey,
        method: method,
        params: params,
        id: id,
      );
      await publish(event);
      return await completer.future.timeout(timeout);
    } finally {
      _pending.remove(id);
    }
  }

  /// Parses [event] and settles a pending call. Returns whether it matched.
  ///
  /// Events that are not kind 24133 or not authored by the bunker are ignored.
  Future<bool> handleEvent(NostrEvent event) async {
    if (event.kind != NostrNip46.kind || event.pubkey != remotePubkey) {
      return false;
    }

    final Nip46Response response;
    try {
      response = await nip46.decryptResponse(event);
    } on Object catch (_) {
      return false;
    }

    final completer = _pending[response.id];
    if (completer == null || completer.isCompleted) {
      return false;
    }

    if (response.error != null) {
      completer.completeError(Nip46Exception(response.error!));
    } else {
      completer.complete(response.result ?? '');
    }
    return true;
  }

  /// Calls `ping` and requires a `pong`.
  Future<void> ping() async {
    final result = await send(Nip46Method.ping);
    if (result != 'pong') {
      throw Nip46Exception('expected pong, got: $result');
    }
  }

  /// Calls `connect`, optionally announcing client metadata.
  Future<void> connect({Map<String, dynamic>? metadata}) async {
    await send(Nip46Method.connect, [
      remotePubkey,
      secret ?? '',
      if (metadata != null) '',
      if (metadata != null) jsonEncode(metadata),
    ]);
  }

  /// Calls `get_public_key`, caching the answer.
  Future<String> getPublicKey() async {
    return _publicKey ??= await send(Nip46Method.getPublicKey);
  }

  /// Asks the remote signer to sign [event].
  Future<NostrEvent> signEvent(NostrEvent event) async {
    final template = jsonEncode({
      'kind': event.kind,
      'content': event.content ?? '',
      'tags': event.tags ?? const <List<String>>[],
      'created_at':
          (event.createdAt ?? DateTime.now()).millisecondsSinceEpoch ~/ 1000,
    });

    final result = await send(Nip46Method.signEvent, [template]);
    final signed = NostrEvent.fromDecodedMessage([
      'EVENT',
      '',
      jsonDecode(result) as Map<String, dynamic>,
    ]);
    if (!signed.isVerified()) {
      throw const Nip46Exception('remote signer returned an invalid signature');
    }
    return signed;
  }

  /// Rejects every pending call and drops cached state.
  void close([String reason = 'client closed']) {
    for (final completer in _pending.values) {
      if (!completer.isCompleted) {
        completer.completeError(Nip46Exception(reason));
      }
    }
    _pending.clear();
    _publicKey = null;
  }
}
