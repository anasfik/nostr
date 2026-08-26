import 'package:dart_nostr/dart_nostr.dart';
import 'package:dart_nostr/nostr/nips/nip57/zaps.dart';
import 'package:dart_nostr/nostr/signers/signer.dart';

/// Send a Lightning zap: build the signed zap request, resolve the
/// recipient's wallet, and fetch a BOLT-11 invoice.
Future<void> main() async {
  final keyPair = NostrKeyPairs.generate();
  final signer = NostrLocalKeySigner(keyPair);
  final zaps = NostrZaps(signer: signer);

  // The creator you're zapping — usually read from their profile's
  // `lud16` (Lightning Address) or `lud06` (LNURL) field.
  final recipientPubkey = NostrKeyPairs.generate().public;
  const lightningAddress = 'someone@wallet.example.com';

  // Convert "user@domain" into the wallet's LNURL-pay endpoint.
  final payUrl = lightningAddressToLnurlPayUrl(lightningAddress);

  // Build and sign the zap request (kind 9734).
  final zapRequest = await zaps.createZapRequest(
    recipientPubkey: recipientPubkey,
    amountMillisats: 21000, // 21 sats
    lnurl: payUrl,
    content: 'great post!',
    relaysForReceipt: ['wss://relay.damus.io'],
  );

  // Ask the wallet for an invoice embedding our zap request.
  try {
    final invoice = await zaps.requestInvoice(
      lnurlPayUrl: payUrl,
      amountMillisats: 21000,
      zapRequest: zapRequest,
    );
    print('pay this invoice to complete the zap: $invoice');
  } catch (e) {
    print('wallet unreachable or zap not allowed: $e');
  }

  // Later, when kind-9735 receipts arrive, parse them:
  // final parsed = NostrZaps.parseZapReceipt(receiptEvent);
  // final sender = NostrZaps.zapSenderPubkey(parsed.zapRequest); // null = anon
}
