import 'dart:convert';

import 'package:dart_nostr/dart_nostr.dart';
import 'package:test/test.dart';

void main() {
  NostrEvent eventWith({
    List<List<String>>? tags,
    String? id,
    String? sig,
    String? subscriptionId,
    String? ots,
  }) {
    return NostrEvent(
      id: id,
      kind: 1,
      content: 'sensitive content',
      sig: sig,
      pubkey: 'a' * 64,
      createdAt: DateTime.fromMillisecondsSinceEpoch(0),
      tags: tags,
      subscriptionId: subscriptionId,
      ots: ots,
    );
  }

  group('NIP-24', () {
    test('birthday round-trips and omits missing fields', () {
      const birthday = NostrMetadataBirthday(year: 1990, month: 5, day: 20);

      expect(birthday.toJson(), {'year': 1990, 'month': 5, 'day': 20});

      final parsed = NostrMetadataBirthday.tryParse(birthday.toJson())!;
      expect(parsed.year, 1990);
      expect(parsed.month, 5);
      expect(parsed.day, 20);
      expect(parsed.isEmpty, isFalse);

      const partial = NostrMetadataBirthday(month: 6);
      expect(partial.toJson(), {'month': 6});
      expect(
        NostrMetadataBirthday.tryParse(jsonEncode(partial.toJson()))!.toJson(),
        {'month': 6},
      );

      const empty = NostrMetadataBirthday();
      expect(empty.toJson(), isEmpty);
      expect(empty.isEmpty, isTrue);
    });

    test('birthday parsing never throws and rejects malformed values', () {
      expect(NostrMetadataBirthday.tryParse('{'), isNull);
      expect(NostrMetadataBirthday.tryParse('[]'), isNull);
      expect(NostrMetadataBirthday.tryParse(5), isNull);
      expect(NostrMetadataBirthday.tryParse(null), isNull);
      expect(NostrMetadataBirthday.tryParse(const {}), isNull);
      expect(NostrMetadataBirthday.tryParse(const {'month': 13}), isNull);
      expect(NostrMetadataBirthday.tryParse(const {'year': 'x'}), isNull);
    });

    test('metadata extras expose bot, birthday and deprecated fields', () {
      final extras = NostrMetadataExtras.tryParse(
        jsonEncode({
          'name': 'alice',
          'bot': true,
          'birthday': {'month': 6, 'day': 1},
          'displayName': 'Alice',
          'username': 'alice',
        }),
      )!;

      expect(extras.bot, isTrue);
      expect(extras.birthday!.month, 6);
      expect(extras.birthday!.day, 1);
      expect(extras.birthday!.year, isNull);
      expect(extras.deprecatedFields, ['displayName', 'username']);

      final plain = NostrMetadataExtras.tryParse('{"name":"alice"}')!;
      expect(plain.bot, isNull);
      expect(plain.birthday, isNull);
      expect(plain.deprecatedFields, isEmpty);

      expect(NostrMetadataExtras.tryParse('nope'), isNull);
      expect(NostrMetadataExtras.tryParse('[]'), isNull);
      expect(NostrMetadataExtras.tryParse(null), isNull);
      expect(NostrMetadataExtras.parse(const {'name': 'alice'}).fields, {
        'name': 'alice',
      });
    });

    test('normalizeMetadataJson drops deprecated fields only', () {
      final normalized = NostrNip24.normalizeMetadataJson(
        '{"name":"alice","displayName":"Alice","username":"a","bot":true}',
      );

      expect(jsonDecode(normalized!), {'name': 'alice', 'bot': true});
      expect(
        NostrNip24.normalizeMetadataJson(
          const {'displayName': 'Alice', 'username': 'a'},
        ),
        '{}',
      );
      expect(
        NostrNip24.normalizeMetadataJson({
          'name': 'alice',
          'created_at': DateTime.fromMillisecondsSinceEpoch(0),
        }),
        isNull,
      );
      expect(NostrNip24.normalizeMetadataJson('[]'), isNull);
      expect(NostrNip24.normalizeMetadataJson('nope'), isNull);
      expect(NostrNip24.normalizeMetadataJson(5), isNull);
    });

    test('hashtags must be lowercase and normalize on build', () {
      expect(NostrNip24.isValidHashtag('nostr'), isTrue);
      expect(NostrNip24.isValidHashtag('Nostr'), isFalse);
      expect(NostrNip24.isValidHashtag(''), isFalse);

      expect(NostrNip24.hashtagTag('nostr'), ['t', 'nostr']);
      expect(NostrNip24.hashtagTag('Nostr'), ['t', 'nostr']);
      expect(() => NostrNip24.hashtagTag(''), throwsArgumentError);
      expect(() => NostrNip24.hashtagTag('  '), throwsArgumentError);
    });

    test('updateProfile omits an empty birthday but keeps a partial one',
        () async {
      final builder = NostrSocialBuilder(
        signer: NostrLocalKeySigner(NostrKeyPairs.generate()),
      );

      final partial = await builder.updateProfile(
        name: 'alice',
        birthday: const NostrMetadataBirthday(year: 1990),
      );
      expect(jsonDecode(partial.content!)['birthday'], {'year': 1990});

      final empty = await builder.updateProfile(
        name: 'alice',
        birthday: const NostrMetadataBirthday(),
      );
      final emptyJson = jsonDecode(empty.content!) as Map<String, dynamic>;
      expect(emptyJson.containsKey('birthday'), isFalse);
    });

    test('publishes the NIP-24 tag names', () {
      expect(
        [
          NostrNip24.r,
          NostrNip24.i,
          NostrNip24.title,
          NostrNip24.t,
        ],
        ['r', 'i', 'title', 't'],
      );
    });
  });

  group('NIP-36', () {
    test('detects bare and reasoned content warnings', () {
      final bare = eventWith(
        tags: [
          ['content-warning'],
        ],
      );
      expect(NostrNip36.hasContentWarning(bare), isTrue);
      expect(NostrNip36.contentWarningReason(bare), isNull);

      final reasoned = eventWith(
        tags: [
          ['content-warning', 'nudity'],
        ],
      );
      expect(NostrNip36.hasContentWarning(reasoned), isTrue);
      expect(NostrNip36.contentWarningReason(reasoned), 'nudity');

      final explicitEmpty = eventWith(
        tags: [
          ['content-warning', ''],
        ],
      );
      expect(NostrNip36.hasContentWarning(explicitEmpty), isTrue);
      expect(NostrNip36.contentWarningReason(explicitEmpty), '');

      final plain = eventWith(
        tags: [
          ['t', 'nostr'],
        ],
      );
      expect(NostrNip36.hasContentWarning(plain), isFalse);
      expect(NostrNip36.contentWarningReason(plain), isNull);
    });

    test('builds the tag with an optional reason', () {
      expect(NostrNip36.tag(), ['content-warning']);
      expect(
        NostrNip36.tag(reason: 'nsfw'),
        ['content-warning', 'nsfw'],
      );
      expect(NostrNip36.tag(reason: ''), ['content-warning', '']);
    });

    test('withContentWarning dedupes and clears id/sig', () {
      final event = eventWith(
        id: 'b' * 64,
        sig: 'c' * 64,
        subscriptionId: 'sub-1',
        ots: 'ots-proof',
        tags: [
          ['t', 'nostr'],
          ['content-warning', 'old'],
          ['content-warning', 'duplicate'],
        ],
      );

      final tagged = NostrNip36.withContentWarning(event, reason: 'nsfw');

      expect(tagged.id, isNull);
      expect(tagged.sig, isNull);
      expect(tagged.subscriptionId, 'sub-1');
      expect(tagged.ots, 'ots-proof');
      expect(tagged.tags!.where((tag) => tag.first == 'content-warning'), [
        ['content-warning', 'nsfw'],
      ]);
      expect(tagged.tags!.first, ['t', 'nostr']);
      expect(NostrNip36.contentWarningReason(tagged), 'nsfw');

      final again = NostrNip36.withContentWarning(tagged, reason: 'nsfw');
      expect(again.tags, tagged.tags);
      expect(again.id, isNull);
    });

    test('withoutContentWarning removes every match and clears id/sig', () {
      final event = eventWith(
        id: 'b' * 64,
        sig: 'c' * 64,
        subscriptionId: 'sub-2',
        ots: 'ots-proof',
        tags: [
          ['content-warning', 'a'],
          ['t', 'nostr'],
          ['content-warning'],
        ],
      );

      final cleared = NostrNip36.withoutContentWarning(event);

      expect(cleared.id, isNull);
      expect(cleared.sig, isNull);
      expect(cleared.subscriptionId, 'sub-2');
      expect(cleared.ots, 'ots-proof');
      expect(cleared.tags, [
        ['t', 'nostr'],
      ]);
      expect(NostrNip36.hasContentWarning(cleared), isFalse);
    });
  });

  group('shared tag helpers', () {
    const tags = [
      ['e', 'id1', 'wss://relay.example', 'root'],
      ['e', 'id2'],
      ['t', 'nostr'],
      ['content-warning'],
    ];

    test('reads full tags, slots and values', () {
      expect(NostrTags.tag(tags, 'e'), [
        'e',
        'id1',
        'wss://relay.example',
        'root',
      ]);
      expect(NostrTags.tag(tags, 'content-warning'), ['content-warning']);
      expect(NostrTags.tag(tags, 'x'), isNull);
      expect(NostrTags.at(tags.first, 2), 'wss://relay.example');
      expect(NostrTags.at(tags.last, 1), isNull);
      expect(NostrTags.at(null, 0), isNull);
      expect(NostrTags.containsValue(tags, 't', 'nostr'), isTrue);
      expect(NostrTags.containsValue(tags, 't', 'Nostr'), isFalse);
      expect(NostrTags.hasExactly(tags, 'e', 2), isTrue);
      expect(NostrTags.hasExactly(tags, 't', 2), isFalse);
    });

    test('withTag replaces same-named tags and withoutTag removes them', () {
      final event = eventWith(id: 'b' * 64, sig: 'c' * 64, tags: tags);

      final replaced = NostrTags.withTag(event, ['t', 'dart']);
      expect(replaced.id, isNull);
      expect(replaced.sig, isNull);
      expect(replaced.tags!.where((tag) => tag.first == 't'), [
        ['t', 'dart'],
      ]);
      expect(replaced.tags![2], ['t', 'dart']);

      final removed = NostrTags.withoutTag(event, ['e']);
      expect(removed.tags, [
        ['t', 'nostr'],
        ['content-warning'],
      ]);

      expect(() => NostrTags.withTag(event, const []), throwsArgumentError);
      expect(() => NostrTags.withoutTag(event, const []), throwsArgumentError);
    });

    test('validates integers and lowercase strings', () {
      expect(NostrValidators.tryInt(5), 5);
      expect(NostrValidators.tryInt(' 5 '), 5);
      expect(NostrValidators.tryInt('x'), isNull);
      expect(NostrValidators.tryInt(5.5), isNull);
      expect(NostrValidators.tryInt(0, min: 1), isNull);
      expect(NostrValidators.tryInt(13, max: 12), isNull);
      expect(NostrValidators.tryInt(12, max: 12), 12);

      expect(NostrValidators.isLowercase('nostr'), isTrue);
      expect(NostrValidators.isLowercase('Nostr'), isFalse);
      expect(NostrValidators.isLowercase(''), isTrue);
    });
  });
}
