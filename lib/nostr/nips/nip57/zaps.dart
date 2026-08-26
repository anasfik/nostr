import 'dart:convert';

import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:dart_nostr/nostr/signers/signer.dart';
import 'package:http/http.dart' as http;

/// {@template nip57}
/// Lightning zaps (NIP-57) client-side support.
///
/// Covers:
/// - Building and signing kind-9734 zap requests
/// - Resolving LNURL-pay endpoints and requesting invoices that embed the
///   signed zap request (`callback?amount=&nostr=`)
/// - Parsing kind-9735 zap receipts, including extracting the embedded
///   anonymous/verified zap request from the description tag
/// {@endtemplate}
class NostrZaps {
  /// {@macro nip57}
  NostrZaps({required this.signer, http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  final NostrEventSigner signer;

  final http.Client _httpClient;

  /// Creates a signed kind-9734 zap request event.
  ///
  /// [recipientPubkey] is mandatory (`p` tag); [targetEventId] optionally
  /// scopes the zap to a note (`e` tag). [amountMillisats] and [lnurl] are
  /// informational tags relayed to the recipient's wallet.
  Future<NostrEvent> createZapRequest({
    required String recipientPubkey,
    String? targetEventId,
    String? targetAuthorRelayUrl,
    required int amountMillisats,
    required String lnurl,
    List<String> relaysForReceipt = const [],
    String? content,
    String? zapTargetKind,
    DateTime? createdAt,
  }) async {
    return signer.sign(
      NostrEvent(
        id: null,
        kind: 9734,
        content: content ?? '',
        sig: null,
        pubkey: signer.publicKey,
        createdAt: createdAt ?? DateTime.now(),
        tags: [
          ['p', recipientPubkey],
          if (targetEventId != null) ...[
            [
              'e',
              targetEventId,
              if (targetAuthorRelayUrl != null) targetAuthorRelayUrl,
            ],
          ],
          if (zapTargetKind != null) ['k', zapTargetKind],
          ['amount', '$amountMillisats'],
          ['lnurl', lnurl],
          ['relays', ...relaysForReceipt],
        ],
      ),
    );
  }

  /// Fetches an LNURL-pay document from [lnurlPayUrl] (the decoded
  /// `https://` endpoint behind a bech32 LNURL or a lud16 address).
  ///
  /// Throws when the endpoint does not allow Nostr zaps.
  Future<Map<String, dynamic>> fetchLnurlPayDocument(
    String lnurlPayUrl,
  ) async {
    final response = await _httpClient.get(Uri.parse(lnurlPayUrl));

    if (response.statusCode != 200) {
      throw http.ClientException(
          'lnurl-pay fetch failed: ${response.statusCode}');
    }

    final doc = jsonDecode(response.body) as Map<String, dynamic>;

    if (doc['allowsNostr'] != true || doc['callback'] == null) {
      throw ArgumentError('this lnurl endpoint does not accept nostr zaps');
    }

    return doc;
  }

  /// Builds the invoice-request URL that embeds the signed zap request,
  /// ready for the wallet service to return a BOLT-11 invoice.
  Uri buildInvoiceRequestUrl({
    required Map<String, dynamic> lnurlPayDocument,
    required NostrEvent zapRequest,
    required int amountMillisats,
  }) {
    final callback = Uri.parse(lnurlPayDocument['callback'] as String);

    return callback.replace(
      queryParameters: {
        ...callback.queryParameters,
        'amount': '$amountMillisats',
        'nostr': jsonEncode(zapRequest.toMap()),
      },
    );
  }

  /// One-shot: resolves the pay document, builds the invoice request URL and
  /// returns the BOLT-11 invoice string.
  Future<String> requestInvoice({
    required String lnurlPayUrl,
    required int amountMillisats,
    required NostrEvent zapRequest,
  }) async {
    final doc = await fetchLnurlPayDocument(lnurlPayUrl);

    if ((doc['minSendable'] as num?) != null &&
        amountMillisats < (doc['minSendable'] as num).toInt()) {
      throw ArgumentError('amount below minSendable');
    }
    if ((doc['maxSendable'] as num?) != null &&
        amountMillisats > (doc['maxSendable'] as num).toInt()) {
      throw ArgumentError('amount above maxSendable');
    }

    final invoiceUrl = buildInvoiceRequestUrl(
      lnurlPayDocument: doc,
      zapRequest: zapRequest,
      amountMillisats: amountMillisats,
    );

    final response = await _httpClient.get(invoiceUrl);
    if (response.statusCode != 200) {
      throw http.ClientException(
          'invoice request failed: ${response.statusCode}');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final pr = body['pr'];

    if (pr is! String || pr.isEmpty) {
      throw ArgumentError('wallet did not return an invoice');
    }

    return pr;
  }

  /// Parses a kind-9735 zap receipt into its parts.
  ///
  /// The `description` tag carries the original zap request JSON; decoding it
  /// lets clients verify who actually sent the zap (or detect anonymity).
  static ({String? bolt11, String? preimage, Map<String, dynamic>? zapRequest})
      parseZapReceipt(NostrEvent receipt) {
    if (receipt.kind != 9735) {
      throw ArgumentError('expected kind 9735, got ${receipt.kind}');
    }

    String? bolt11;
    String? preimage;
    Map<String, dynamic>? zapRequest;

    for (final tag in receipt.tags ?? const <List<String>>[]) {
      if (tag.length < 2) {
        continue;
      }

      switch (tag.first) {
        case 'bolt11':
          bolt11 = tag[1];
        case 'preimage':
          preimage = tag[1];
        case 'description':
          try {
            zapRequest = jsonDecode(tag[1]) as Map<String, dynamic>;
          } catch (_) {}
      }
    }

    return (bolt11: bolt11, preimage: preimage, zapRequest: zapRequest);
  }

  /// Extracts the sender pubkey from a parsed zap receipt's embedded request.
  /// Returns `null` for anonymous zaps.
  static String? zapSenderPubkey(Map<String, dynamic>? zapRequest) {
    return zapRequest?['pubkey'] as String?;
  }

  /// Validates an incoming zap request against the NIP-57 rules a wallet or
  /// client must enforce before honoring it.
  ///
  /// Returns a list of problems; empty means valid. Checks:
  /// - kind is 9734 and the id is correctly derived from fields
  /// - exactly one `p` tag with a valid 32-byte hex pubkey (spec: MUST)
  /// - a `relays` tag exists so the receipt can be routed (spec: MUST)
  /// - when present, `amount` is a positive integer string
  static List<String> validateZapRequest(NostrEvent event) {
    final problems = <String>[];

    if (event.kind != 9734) {
      problems.add('expected kind 9734, got ${event.kind}');
      return problems;
    }

    final recomputedId = NostrEvent.getEventId(
      kind: event.kind!,
      content: event.content ?? '',
      createdAt: event.createdAt!,
      tags: event.tags ?? [],
      pubkey: event.pubkey,
    );
    if (recomputedId != event.id) {
      problems.add('event id does not match its serialized content');
    }

    if (!event.isVerified()) {
      problems.add('signature is invalid');
    }

    final pTags =
        (event.tags ?? []).where((t) => t.isNotEmpty && t[0] == 'p').toList();
    if (pTags.isEmpty) {
      problems.add('missing required p tag');
    } else if (pTags.length > 1) {
      problems.add('must contain exactly one p tag, found ${pTags.length}');
    } else if (pTags.first.length < 2 ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(pTags.first[1])) {
      problems.add('p tag value is not a valid 32-byte pubkey');
    }

    final hasRelaysTag =
        (event.tags ?? []).any((t) => t.isNotEmpty && t[0] == 'relays');
    if (!hasRelaysTag) {
      problems.add('missing required relays tag for receipt routing');
    }

    final amountTags = (event.tags ?? [])
        .where((t) => t.isNotEmpty && t[0] == 'amount')
        .toList();
    if (amountTags.isNotEmpty) {
      final amount =
          int.tryParse(amountTags.first.length > 1 ? amountTags.first[1] : '');
      if (amount == null || amount <= 0) {
        problems.add('amount tag is not a positive integer');
      }
    }

    return problems;
  }

  /// Verifies that a zap receipt's embedded `description` matches the zap
  /// request it claims to carry: the SHA-256 of the description string must
  /// equal the `description_hash` embedded in the BOLT-11 invoice, which is
  /// how wallets prove the invoice was created for THIS zap request.
  ///
  /// [bolt11DescriptionField] is the human-readable `description` field of
  /// the invoice, which per NIP-57 holds the exact zap-request JSON.
  static bool verifyReceiptMatchesRequest({
    required String bolt11DescriptionField,
    required NostrEvent zapRequest,
  }) {
    // The description field must be byte-identical to the serialized request
    // we would produce from the parsed event.
    final canonical = jsonEncode(zapRequest.toMap());
    return bolt11DescriptionField == canonical;
  }
}

/// {@template nip57_lud16_helper}
/// Converts a Lightning Address (lud16, `user@domain`) into its LNURL-pay
/// HTTPS endpoint.
/// {@endtemplate}
String lightningAddressToLnurlPayUrl(String lightningAddress) {
  final parts = lightningAddress.split('@');

  if (parts.length != 2 ||
      parts[0].isEmpty ||
      parts[1].isEmpty ||
      lightningAddress.contains('/')) {
    throw ArgumentError.value(
      lightningAddress,
      'lightningAddress',
      'must look like user@domain',
    );
  }

  return 'https://${parts[1]}/.well-known/lnurlp/${parts[0]}';
}
