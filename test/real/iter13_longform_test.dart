import 'dart:convert';

import 'package:dart_nostr/dart_nostr.dart';
import 'package:dart_nostr/nostr/builders/social_builder.dart';
import 'package:dart_nostr/nostr/signers/signer.dart';
import 'package:test/test.dart';

import '../real/helpers.dart';

/// Iteration 13 — long-form compatibility: take a REAL article from the
/// wild (Yakihonne/reader clients), rebuild it with our builder from its
/// own fields, and assert the rebuilt tag set is a superset match — proving
/// our articles carry everything readers expect.
void main() {
  if (!realNetworkTestsEnabled) {
    return;
  }

  group('REAL/interop: long-form article compatibility', () {
    test(
      'rebuild a wild article through our builder — tag-complete',
      () async {
        final articles = await rawFetchAny(
          kPrimaryRelays,
          {
            'kinds': [30023],
            'limit': 5
          },
          timeout: const Duration(seconds: 12),
        );

        if (articles.isEmpty) {
          markTestSkipped('no articles in sample window');
          return;
        }

        var rebuilt = 0;

        for (final raw in articles) {
          final original = NostrEvent.deserialized(
            jsonEncode(['EVENT', 'iter13', raw]),
          );

          String dTag = '';
          String? title;
          String? image;
          String? summary;
          DateTime? publishedAt;
          final hashtags = <String>[];
          final references = <String>[];

          for (final tag in original.tags ?? const <List<String>>[]) {
            if (tag.isEmpty) continue;
            switch (tag[0]) {
              case 'd':
                if (tag.length > 1) dTag = tag[1];
              case 'title':
                if (tag.length > 1) title = tag[1];
              case 'image':
                if (tag.length > 1) image = tag[1];
              case 'summary':
                if (tag.length > 1) summary = tag[1];
              case 'published_at':
                if (tag.length > 1) {
                  publishedAt = DateTime.fromMillisecondsSinceEpoch(
                    (int.tryParse(tag[1]) ?? 0) * 1000,
                  );
                }
              case 't':
                if (tag.length > 1 && tag[1].isNotEmpty) hashtags.add(tag[1]);
              case 'r':
                if (tag.length > 1) references.add(tag[1]);
            }
          }

          if (dTag.isEmpty) continue;

          // Rebuild with our builder using ONLY what the wild article had.
          final signer = NostrLocalKeySigner(newIdentity());
          final builder = NostrSocialBuilder(signer: signer);

          final ours = await builder.createLongFormArticle(
            content: original.content ?? '',
            dTagIdentifier: dTag,
            title: title,
            image: image,
            summary: summary,
            publishedAt: publishedAt,
            hashtags: hashtags,
            references: references,
          );

          // Every tag the wild article carried (of the kinds we model)
          // must appear in ours.
          for (final kind in ['d', 'title', 'summary', 'published_at', 't']) {
            final theirs = original.tags!
                .where((t) => t.isNotEmpty && t[0] == kind)
                .map((t) => t.length > 1 ? t[1] : '')
                .toSet();
            final mine = ours.tags!
                .where((t) => t.isNotEmpty && t[0] == kind)
                .map((t) => t.length > 1 ? t[1] : '')
                .toSet();

            expect(mine.containsAll(theirs), isTrue,
                reason: 'rebuilt article lost $kind data: '
                    'theirs=$theirs mine=$mine');
          }

          // r tags too.
          final theirRefs = original.tags!
              .where((t) => t.isNotEmpty && t[0] == 'r')
              .map((t) => t.length > 1 ? t[1] : '')
              .toSet();
          final myRefs = ours.tags!
              .where((t) => t.isNotEmpty && t[0] == 'r')
              .map((t) => t.length > 1 ? t[1] : '')
              .toSet();
          expect(myRefs.containsAll(theirRefs), isTrue,
              reason: 'lost r-tag references');

          rebuilt++;
        }

        expect(rebuilt, greaterThan(0));
      },
      timeout: kTestTimeout,
    );
  });
}
