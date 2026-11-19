import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:dart_nostr/nostr/signers/signer.dart';

/// {@template nip07_capable}
/// Minimal surface a NIP-07 provider must expose.
///
/// In a browser this is `window.nostr`; this package does not use `dart:js`
/// or `dart:html`, so applications supply their own bridge implementing this
/// interface (for example over `package:web` or a WebView channel).
/// {@endtemplate}
abstract interface class NostrNip07Capable {
  /// Returns the user's public key as 64-char hex.
  Future<String> getPublicKey();

  /// Asks the provider to sign an unsigned event template.
  ///
  /// [event] must contain `kind`, `created_at`, `tags` and `content`. The
  /// returned map is the complete signed event (`id`, `pubkey`, `sig` set).
  Future<Map<String, dynamic>> signEvent(Map<String, dynamic> event);
}

/// {@template nip07_nip04_capable}
/// Optional NIP-04 methods a NIP-07 provider may expose (`window.nostr.nip04`).
/// {@endtemplate}
abstract interface class NostrNip07Nip04Capable {
  /// NIP-04 encrypts [plaintext] for [publicKey].
  Future<String> nip04Encrypt(String publicKey, String plaintext);

  /// NIP-04 decrypts [ciphertext] sent by [publicKey].
  Future<String> nip04Decrypt(String publicKey, String ciphertext);
}

/// {@template nip07_nip44_capable}
/// Optional NIP-44 methods a NIP-07 provider may expose (`window.nostr.nip44`).
/// {@endtemplate}
abstract interface class NostrNip07Nip44Capable {
  /// NIP-44 encrypts [plaintext] for [publicKey].
  Future<String> nip44Encrypt(String publicKey, String plaintext);

  /// NIP-44 decrypts [ciphertext] sent by [publicKey].
  Future<String> nip44Decrypt(String publicKey, String ciphertext);
}

/// {@template nip07}
/// NIP-07 browser-extension signer bridge.
///
/// Wraps a [NostrNip07Capable] and adapts it to this package's
/// [NostrEventSigner] contract. Nothing here touches a browser `window`; the
/// caller provides the provider object.
///
/// ```dart
/// final signer = await NostrNip07Signer.connect(windowNostr);
/// nostr.nips.bindSigner(signer);
/// ```
///
/// NIP-04 and NIP-44 calls require the provider to additionally implement
/// [NostrNip07Nip04Capable] / [NostrNip07Nip44Capable]; otherwise they throw
/// [UnsupportedError].
/// {@endtemplate}
class NostrNip07 {
  /// {@macro nip07}
  const NostrNip07();

  /// Converts [event] into the template map a NIP-07 provider expects.
  static Map<String, dynamic> eventTemplate(NostrEvent event) {
    final milliseconds = event.createdAt?.millisecondsSinceEpoch ??
        DateTime.now().millisecondsSinceEpoch;

    return {
      'kind': event.kind,
      'created_at': milliseconds ~/ 1000,
      'tags': event.tags ?? const <List<String>>[],
      'content': event.content ?? '',
    };
  }

  /// Reads the public key of [capable].
  static Future<String> getPublicKey(NostrNip07Capable capable) {
    return capable.getPublicKey();
  }

  /// Signs [event] through [capable].
  static Future<NostrEvent> sign(
    NostrNip07Capable capable,
    NostrEvent event,
  ) async {
    final signed = await capable.signEvent(eventTemplate(event));
    return fromSignedMap(signed);
  }

  /// Builds a [NostrEvent] from a provider's signed JSON map.
  ///
  /// Throws [FormatException] when `id`, `pubkey` or `sig` is missing, since
  /// an unsigned response cannot be trusted or published.
  static NostrEvent fromSignedMap(Map<String, dynamic> json) {
    final id = json['id'];
    final pubkey = json['pubkey'];
    final sig = json['sig'];
    final kind = json['kind'];

    if (id is! String || pubkey is! String || sig is! String || kind is! int) {
      throw const FormatException('NIP-07 signer returned an unsigned event');
    }

    final createdAt = json['created_at'];

    return NostrEvent(
      id: id,
      kind: kind,
      content: (json['content'] as String?) ?? '',
      sig: sig,
      pubkey: pubkey,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        ((createdAt as int?) ?? 0) * 1000,
      ),
      tags: [
        for (final tag in (json['tags'] as List?) ?? const [])
          [for (final value in tag as List) value.toString()],
      ],
    );
  }

  /// NIP-04 encrypts [plaintext] for [publicKey] via [capable].
  static Future<String> nip04Encrypt(
    NostrNip07Capable capable,
    String publicKey,
    String plaintext,
  ) {
    final nip04 = _asNip04(capable);
    return nip04.nip04Encrypt(publicKey, plaintext);
  }

  /// NIP-04 decrypts [ciphertext] from [publicKey] via [capable].
  static Future<String> nip04Decrypt(
    NostrNip07Capable capable,
    String publicKey,
    String ciphertext,
  ) {
    final nip04 = _asNip04(capable);
    return nip04.nip04Decrypt(publicKey, ciphertext);
  }

  /// NIP-44 encrypts [plaintext] for [publicKey] via [capable].
  static Future<String> nip44Encrypt(
    NostrNip07Capable capable,
    String publicKey,
    String plaintext,
  ) {
    final nip44 = _asNip44(capable);
    return nip44.nip44Encrypt(publicKey, plaintext);
  }

  /// NIP-44 decrypts [ciphertext] from [publicKey] via [capable].
  static Future<String> nip44Decrypt(
    NostrNip07Capable capable,
    String publicKey,
    String ciphertext,
  ) {
    final nip44 = _asNip44(capable);
    return nip44.nip44Decrypt(publicKey, ciphertext);
  }

  /// Creates a [NostrEventSigner] backed by [capable].
  static Future<NostrEventSigner> signer(NostrNip07Capable capable) {
    return NostrNip07Signer.connect(capable);
  }

  static NostrNip07Nip04Capable _asNip04(NostrNip07Capable capable) {
    if (capable is NostrNip07Nip04Capable) {
      return capable as NostrNip07Nip04Capable;
    }
    throw UnsupportedError('NIP-07 provider does not expose nip04 methods');
  }

  static NostrNip07Nip44Capable _asNip44(NostrNip07Capable capable) {
    if (capable is NostrNip07Nip44Capable) {
      return capable as NostrNip07Nip44Capable;
    }
    throw UnsupportedError('NIP-07 provider does not expose nip44 methods');
  }
}

/// {@template nip07_signer}
/// [NostrEventSigner] adapter over a NIP-07 provider.
///
/// [publicKey] is fetched once by [connect] because [NostrEventSigner]
/// exposes it synchronously. Call [connect] again after the user switches
/// accounts in the extension.
/// {@endtemplate}
class NostrNip07Signer implements NostrEventSigner {
  NostrNip07Signer._(this.capable, this.publicKey);

  /// Wraps [capable], reading the public key once.
  static Future<NostrNip07Signer> connect(NostrNip07Capable capable) async {
    return NostrNip07Signer._(capable, await capable.getPublicKey());
  }

  /// Underlying browser-extension provider.
  final NostrNip07Capable capable;

  @override
  final String publicKey;

  @override
  Future<NostrEvent> sign(NostrEvent event) {
    return NostrNip07.sign(capable, event);
  }

  @override
  Future<String> nip44Encrypt(String plaintext, String recipientPublicKey) {
    return NostrNip07.nip44Encrypt(capable, recipientPublicKey, plaintext);
  }

  @override
  Future<String> nip44Decrypt(String payload, String senderPublicKey) {
    return NostrNip07.nip44Decrypt(capable, senderPublicKey, payload);
  }

  /// NIP-04 encrypts [plaintext] for [recipientPublicKey].
  Future<String> nip04Encrypt(String plaintext, String recipientPublicKey) {
    return NostrNip07.nip04Encrypt(capable, recipientPublicKey, plaintext);
  }

  /// NIP-04 decrypts [payload] sent by [senderPublicKey].
  Future<String> nip04Decrypt(String payload, String senderPublicKey) {
    return NostrNip07.nip04Decrypt(capable, senderPublicKey, payload);
  }
}
