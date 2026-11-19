import 'dart:typed_data';

import 'package:dart_nostr/nostr/builders/social_builder.dart';
import 'package:dart_nostr/nostr/instance/bech32/bech32.dart';
import 'package:dart_nostr/nostr/instance/tlv/base/base.dart';
import 'package:dart_nostr/nostr/instance/tlv/tlv_utils.dart';
import 'package:dart_nostr/nostr/model/relay_informations.dart';
import 'package:dart_nostr/nostr/nips/blossom/blossom.dart';
import 'package:dart_nostr/nostr/nips/nip13/pow.dart';
import 'package:dart_nostr/nostr/nips/nip57/zaps.dart';
import 'package:test/test.dart';

void main() {
  test('legacy import paths still resolve to the same implementations', () {
    expect(NostrProofOfWork.getDifficulty('0' * 64), 256);
    final bech32 = NostrBech32();
    final pubkey = 'a' * 64;
    expect(
      bech32.decodeNpubKeyToPublicKey(bech32.encodePublicKeyToNpub(pubkey)),
      pubkey,
    );

    final tlv = NostrTLV();
    final bytes = tlv.encode([TLV(type: 0, length: 1, value: Uint8List(1))]);
    expect(tlv.decode(bytes).single.type, 0);

    expect(
      RelayInformations.fromNip11Response(const {'name': 'relay'}).name,
      'relay',
    );

    expect(NostrBlossomClient, isNotNull);
    expect(NostrNip94FileMetadata, isNotNull);
    expect(NostrNip96Uploader, isNotNull);
    expect(NostrSocialBuilder, isNotNull);
    expect(NostrZaps, isNotNull);
  });
}
