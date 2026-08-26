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
