import 'dart:convert';

import 'package:dart_nostr/dart_nostr.dart';
import 'package:dart_nostr/nostr/nips/nip21/nip21.dart';
import 'package:test/test.dart';

import '../real/helpers.dart';

/// Iteration 11 — cross-client consumption: notes written by Damus, Primal,
/// Amethyst, njump users must parse cleanly, and nostr: mentions inside
/// their content must resolve through our NIP-21 tooling (what njump does
/// when rendering a note).
void main() {
  if (!realNetworkTestsEnabled) {
    return;
  }

  group('REAL/interop: consuming real clients\' content', () {
    test(
      'real Damus/Primal notes deserialize and verify',
      () async {
        final notes = await rawFetchAny(
          kPrimaryRelays,
          {
            'kinds': [1],
            'limit': 40
          },
        );
        expect(notes.length, greaterThan(20));

        var parsed = 0;
        var verified = 0;
        final clientTagsSeen = <String>{};

        for (final raw in notes) {
          final event = NostrEvent.deserialized(
            jsonEncode(['EVENT', 'interop', raw]),
          );

          // Id recomputation must match for every single real event.
          final recomputed = NostrEvent.getEventId(
            kind: event.kind!,
            content: event.content!,
            createdAt: event.createdAt!,
            tags: event.tags!,
            pubkey: event.pubkey,
          );
          expect(recomputed, event.id,
              reason: 'id mismatch on a real event — serialization is wrong');

          if (event.isVerified()) verified++;

          for (final tag in event.tags ?? const <List<String>>[]) {
            if (tag.isNotEmpty && tag[0] == 'client' && tag.length > 1) {
              clientTagsSeen.add(tag[1]);
            }
          }
          parsed++;
        }

        expect(parsed, greaterThan(20));
        // Relays reject bad signatures; nearly all should verify.
        expect(verified / parsed, greaterThan(0.95),
            reason: 'only $verified/$parsed verified');

        // ignore: avoid_print
        print('clients seen in the wild sample: '
            '${clientTagsSeen.take(10).toList()}');
      },
      timeout: kTestTimeout,
    );

    test(
      'nostr: mentions in real notes resolve like njump renders them',
      () async {
        final notes = await rawFetchAny(
          kPrimaryRelays,
          {
            'kinds': [1],
            'limit': 100
          },
          timeout: const Duration(seconds: 15),
        );

        Map<String, dynamic>? withMention;
        String? mentionedEntity;

        final mentionRegex =
            RegExp(r'nostr:(npub1|nprofile1|nevent1|note1)[a-z0-9]+');

        for (final raw in notes.cast<Map<String, dynamic>>()) {
          final content = raw['content'] as String? ?? '';
          final match = mentionRegex.firstMatch(content);
          if (match != null) {
            withMention = Map<String, dynamic>.from(raw);
            mentionedEntity = match.group(0)?.substring('nostr:'.length);
            break;
          }
        }

        if (withMention == null) {
          markTestSkipped('no note with nostr: mention in sample window');
          return;
        }

        // Parse the entity exactly as njump would.
        final nip21 = NostrNip21();
        final parsed = nip21.parseFully('nostr:$mentionedEntity');

        expect(parsed['hrp'], isIn(['npub', 'nprofile', 'nevent', 'note']));

        if (parsed['hrp'] == 'nprofile') {
          final decoded = parsed['decoded'] as Map;
          expect(decoded['pubkey'], hasLength(64));
        }

        // The author of a mention usually p-tags the mentioned user.
        final pTags = (withMention['tags'] as List)
            .map((t) => (t as List).map((x) => '$x').toList())
            .where((t) => t.isNotEmpty && t[0] == 'p')
            .toList();
        expect(pTags, isNotEmpty,
            reason: 'real clients always pair mentions with p tags');
      },
      timeout: kTestTimeout,
    );

    test(
      'real Yakihonne-style articles parse completely through our models',
      () async {
        final articles = await rawFetchAny(
          kPrimaryRelays,
          {
            'kinds': [30023],
            'limit': 3
          },
          timeout: const Duration(seconds: 12),
        );

        if (articles.isEmpty) {
          markTestSkipped('no articles found');
          return;
        }

        for (final raw in articles) {
          final article = NostrEvent.deserialized(
            jsonEncode(['EVENT', 'interop', raw]),
          );

          // Extract what a reader app needs — all from our model:
          final dTag = article.tags!
              .firstWhere((t) => t.isNotEmpty && t[0] == 'd',
                  orElse: () => const <String>[])
              .sublist(1)
              .first;
          final title = article.tags!
              .firstWhere((t) => t.isNotEmpty && t[0] == 'title',
                  orElse: () => const <String>[])
              .sublist(1)
              .firstOrNull;

          expect(article.kind, 30023);
          expect(dTag, isNotNull, reason: 'article without d tag is invalid');

          // Content should be non-trivial markdown for real articles.
          expect(article.content, isNotEmpty);
          // ignore: avoid_print
          print('parsed article: "${title ?? dTag}" '
              '(${article.content!.length} chars)');
        }
      },
      timeout: kTestTimeout,
    );

    test(
      'our builders produce shapes indistinguishable from real clients',
      () async {
        final identity = newIdentity();
        final signer = NostrLocalKeySigner(identity);
        final builder = NostrSocialBuilder(signer: signer);

        // Compare our profile against the fields real clients write
        // (observed in the wild: name, display_name, about, picture,
        // nip05, banner, website, lud16, lud06).
        final profile = await builder.updateProfile(
          name: 'interop-check',
          displayName: 'Interop Check',
          about: 'compatibility probe',
          picture: 'https://example.com/p.png',
          nip05: 'probe@example.com',
          website: 'https://example.com',
          lud16: 'probe@wallet.co',
        );

        final meta = jsonDecode(profile.content!) as Map<String, dynamic>;
        for (final field in [
          'name',
          'display_name',
          'about',
          'picture',
          'nip05',
          'website',
          'lud16',
        ]) {
          expect(meta.containsKey(field), isTrue,
              reason: 'profile missing $field that real clients write');
        }

        // Our reaction vs the wild reaction shape ([e], [p], optional [k]).
        final reaction = await builder.createReaction(
          targetEventId: 'aa' * 32,
          targetAuthorPubkey: 'bb' * 32,
          targetKind: '1',
        );
        final tagNames = reaction.tags!.map((t) => t.first).toSet();
        expect(tagNames.containsAll(['e', 'p', 'k']), isTrue);
      },
    );
  });
}
