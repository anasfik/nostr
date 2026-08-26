import 'package:dart_nostr/nostr/core/utils.dart';
import 'package:dart_nostr/nostr/instance/bech32/bech32.dart';
import 'package:dart_nostr/nostr/model/debug_options.dart';
import 'package:dart_nostr/nostr/nips/nip21/nip21.dart';
import 'package:test/test.dart';

void main() {
  late NostrBech32 bech32;
  late NostrNip21 nip21;

  setUp(() {
    final logger = NostrLogger(passedDebugOptions: NostrDebugOptions.general());
    logger.disableLogs();
    bech32 = NostrBech32(logger: logger);
    nip21 = NostrNip21(bech32: bech32);
  });

  group('NIP-19 naddr', () {
    const kind = 30023;
    const author =
        '3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d';
    const identifier = 'my-article-slug';
    const relays = ['wss://relay.damus.io'];

    test('encode/decode roundtrip with all fields', () {
      final naddr = bech32.encodeNAddr(
        kind: kind,
        authorPubkey: author,
        identifier: identifier,
        userRelays: relays,
      );

      expect(naddr, startsWith('naddr1'));

      final decoded = bech32.decodeNaddrToMap(naddr);

      expect(decoded['kind'], kind);
      expect(decoded['pubkey'], author);
      expect(decoded['identifier'], identifier);
      expect(decoded['relays'], relays);
    });

    test('roundtrip without identifier and relays', () {
      final naddr = bech32.encodeNAddr(
        kind: 0,
        authorPubkey: author,
      );

      final decoded = bech32.decodeNaddrToMap(naddr);

      expect(decoded['kind'], 0);
      expect(decoded['identifier'], isEmpty);
      expect(decoded['relays'], isEmpty);
    });

    test('rejects invalid kinds', () {
      expect(
        () => bech32.encodeNAddr(kind: -1, authorPubkey: author),
        throwsArgumentError,
      );
      expect(
        () => bech32.encodeNAddr(kind: 0x100000000, authorPubkey: author),
        throwsArgumentError,
      );
    });
  });

  group('NIP-21', () {
    test('parses nostr:npub URIs', () {
      final npub = bech32.encodePublicKeyToNpub('a' * 64);
      final parsed = nip21.parse('nostr:$npub');

      expect(parsed['hrp'], 'npub');
      expect(parsed['entity'], npub);
    });

    test('tolerates bare entities without scheme', () {
      final npub = bech32.encodePublicKeyToNpub('b' * 64);
      final parsed = nip21.parse(npub);

      expect(parsed['hrp'], 'npub');
    });

    test('isNostrUri validates', () {
      final npub = bech32.encodePublicKeyToNpub('c' * 64);
      expect(nip21.isNostrUri('nostr:$npub'), isTrue);
      expect(nip21.isNostrUri(npub), isTrue);
      expect(nip21.isNostrUri('nostr:not-a-thing'), isFalse);
      expect(nip21.isNostrUri(''), isFalse);
    });

    test('builds URI from entity', () {
      final npub = bech32.encodePublicKeyToNpub('d' * 64);
      expect(nip21.build(npub), 'nostr:$npub');
      expect(() => nip21.build('garbage'), throwsArgumentError);
    });

    test('parseFully decodes nprofile entities', () {
      const pubkey =
          '3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d';
      final nprofile =
          bech32.encodeNProfile(pubkey: pubkey, userRelays: ['wss://r.io']);

      final full = nip21.parseFully('nostr:$nprofile');

      expect((full['decoded'] as Map)['pubkey'], pubkey);
    });

    test('parseFully decodes naddr entities', () {
      const author =
          '3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d';
      final naddr = bech32.encodeNAddr(
        kind: 30023,
        authorPubkey: author,
        identifier: 'slug',
      );

      final full = nip21.parseFully('nostr:$naddr');
      final decoded = full['decoded'] as Map;

      expect(decoded['kind'], 30023);
      expect(decoded['identifier'], 'slug');
    });

    test('rejects malformed uris', () {
      expect(() => nip21.parse('nostr:'), throwsArgumentError);
      expect(() => nip21.parse('https://example.com'), throwsArgumentError);
      expect(() => nip21.parse(''), throwsArgumentError);
    });
  });
}
