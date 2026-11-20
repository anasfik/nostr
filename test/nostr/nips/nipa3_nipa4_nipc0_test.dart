import 'package:dart_nostr/dart_nostr.dart';
import 'package:test/test.dart';

/// Spec vectors, verbatim from NIP-A3, NIP-A4 and NIP-C0.
const List<List<String>> _a3Tags = [
  ['payto', 'bitcoin', 'bc1qxq66e0t8d7ugdecwnmv58e90tpry23nc84pg9k'],
  [
    'payto',
    'nano',
    'nano_1dctqbmqxfppo9pswbm6kg9d4s4mbraqn8i4m7ob9gnzz91aurmuho48jx3c',
  ],
  ['payto', 'unknowntype', 'l7tbta5b9xze6ckkfc99uohzxd009b0r'],
];

const String _receiver =
    '3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d';
const String _sender =
    'afc93622eb4d79c0fb75e56e0c14553f7214b0a466abeba14cb38968c6755e6a';

const Map<String, dynamic> _a4Vector = {
  'kind': 24,
  'content': '<message-in-plain-text>',
  'tags': [
    ['p', _receiver, 'wss://relay.example'],
  ],
};

const String _c0Content = 'function helloWorld() {\n'
    "  console.log('Hello, Nostr!');\n"
    '}\n'
    '\n'
    'helloWorld();';

const Map<String, dynamic> _c0Vector = {
  'kind': 1337,
  'content': _c0Content,
  'tags': [
    ['l', 'javascript'],
    ['extension', 'js'],
    ['name', 'hello-world.js'],
    [
      'description',
      "A basic JavaScript function that prints 'Hello, Nostr!' to the console",
    ],
    ['runtime', 'node v18.15.0'],
    ['license', 'MIT'],
    ['repo', 'https://github.com/nostr-protocol/nostr'],
  ],
};

NostrEvent _event(
  Map<String, dynamic> json, {
  String pubkey = '',
  DateTime? createdAt,
}) {
  return NostrEvent(
    id: json['id'] as String?,
    kind: json['kind'] as int?,
    content: json['content'] as String?,
    pubkey: pubkey,
    sig: json['sig'] as String?,
    createdAt: createdAt ?? DateTime.fromMillisecondsSinceEpoch(0),
    tags: [
      for (final tag in json['tags'] as List) List<String>.from(tag as List),
    ],
  );
}

void main() {
  group('NIP-A3', () {
    test('parses the spec vectors and renders payment URIs', () {
      final event = _event({
        'kind': 10133,
        'content': '',
        'tags': _a3Tags,
      });
      final targets = NostrNipA3.parse(event);

      expect(NostrNipA3.paymentTargetsKind, 10133);
      expect(targets, hasLength(3));
      expect(targets[0].type, 'bitcoin');
      expect(
        targets[0].toUri().toString(),
        'bitcoin:bc1qxq66e0t8d7ugdecwnmv58e90tpry23nc84pg9k',
      );
      expect(
        targets[1].toUri().toString(),
        'payto://nano/'
        'nano_1dctqbmqxfppo9pswbm6kg9d4s4mbraqn8i4m7ob9gnzz91aurmuho48jx3c',
      );
      expect(
        targets[2].toUri().toString(),
        'payto://unknowntype/l7tbta5b9xze6ckkfc99uohzxd009b0r',
      );
      expect(NostrNipA3.validate(event), isTrue);
      expect(NostrNipA3.tryParse(event), hasLength(3));
    });

    test('builds the spec vector tags back', () {
      final event = NostrNipA3.generatePaymentTargetsTemplate(
        targets: [
          for (final tag in _a3Tags) NostrNipA3.parseTag(tag),
        ],
        createdAt: DateTime.fromMillisecondsSinceEpoch(0),
      );

      expect(event.kind, 10133);
      expect(event.content, '');
      expect(event.tags, _a3Tags);
      expect(NostrNipA3.tryParse(event)!.map((t) => t.tag), _a3Tags);
    });

    test('hasUriScheme is case-insensitive for hand-built targets', () {
      const target = NostrPaytoTarget(type: 'Bitcoin', address: 'bc1q');

      expect(target.hasUriScheme, isTrue);
      expect(target.toUri().toString(), 'bitcoin:bc1q');
      // Builder validation still requires lowercase types.
      expect(
        () =>
            NostrNipA3.generatePaymentTargetsTemplate(targets: const [target]),
        throwsArgumentError,
      );
    });

    test('toUri percent-encodes the fallback address and type', () {
      const target = NostrPaytoTarget(
        type: 'unknowntype',
        address: 'a b/c?d',
      );

      expect(target.toUri().toString(), 'payto://unknowntype/a%20b%2Fc%3Fd');
      expect(target.hasUriScheme, isFalse);
      expect(
        const NostrPaytoTarget(type: 'bitcoin', address: 'bc1q').hasUriScheme,
        isTrue,
      );
    });

    test('parses tags with extra slots and ignores foreign tags', () {
      final target = NostrNipA3.parseTag([
        'payto',
        'bitcoin',
        'bc1q',
        'future-slot',
      ]);

      expect(target.extra, ['future-slot']);
      expect(target.tag, ['payto', 'bitcoin', 'bc1q', 'future-slot']);
      expect(target.toUri().toString(), 'bitcoin:bc1q');
      expect(NostrNipA3.tryParseTag(['p', 'x']), isNull);
      expect(NostrNipA3.tryParseTag(['payto', 'bitcoin']), isNull);
      expect(NostrNipA3.tryParseTag(['payto', '', 'bc1q']), isNull);
      expect(NostrNipA3.tryParseTag(['payto', 'bitcoin', '  ']), isNull);
      expect(() => NostrNipA3.parseTag(['nope']), throwsArgumentError);
    });

    test('rejects invalid builders and wrong kinds', () {
      expect(
        () => NostrNipA3.generatePaymentTargetsTemplate(targets: const []),
        throwsArgumentError,
      );
      for (final target in const [
        NostrPaytoTarget(type: 'Bitcoin', address: 'bc1q'),
        NostrPaytoTarget(type: '', address: 'bc1q'),
        NostrPaytoTarget(type: 'bitcoin', address: ' '),
        NostrPaytoTarget(type: 'bit coin', address: 'bc1q'),
      ]) {
        expect(
          () => NostrNipA3.generatePaymentTargetsTemplate(targets: [target]),
          throwsArgumentError,
        );
      }

      final note = _event({'kind': 1, 'content': 'GM', 'tags': _a3Tags});
      expect(NostrNipA3.tryParse(note), isNull);
      expect(() => NostrNipA3.parse(note), throwsArgumentError);
      expect(
        NostrNipA3.validate(
          _event({'kind': 10133, 'content': '', 'tags': <String>[]}),
        ),
        isFalse,
      );
    });
  });

  group('NIP-A4', () {
    test('parses the spec vector', () {
      final event = _event(_a4Vector, pubkey: _sender);
      final message = NostrNipA4.parseMessage(event);

      expect(NostrNipA4.messageKind, 24);
      expect(message.content, '<message-in-plain-text>');
      expect(message.receivers, [_receiver]);
      expect(
          message.receiverTags.first, ['p', _receiver, 'wss://relay.example']);
      expect(message.tags, isEmpty);
      expect(message.pubkey, _sender);
      expect(NostrNipA4.validateMessage(event), isTrue);
    });

    test('builds the spec vector and signs it through a signer', () async {
      final signer = NostrLocalKeySigner(NostrKeyPairs.generate());
      final nipa4 = NostrNipA4(signer: signer);

      final template = NostrNipA4.generateMessageTemplate(
        content: '<message-in-plain-text>',
        receivers: const [_receiver],
        relayHints: const {_receiver: 'wss://relay.example'},
        createdAt: DateTime.fromMillisecondsSinceEpoch(0),
      );

      expect(template.kind, 24);
      expect(template.tags, _a4Vector['tags']);
      expect(template.pubkey, '');

      final signed = await nipa4.publish(
        content: '<message-in-plain-text>',
        receivers: const [_receiver],
        relayHints: const {_receiver: 'wss://relay.example'},
        createdAt: DateTime.fromMillisecondsSinceEpoch(0),
      );

      expect(signed.pubkey, signer.publicKey);
      expect(signed.id, isNotNull);
      expect(signed.sig, isNotNull);
      expect(NostrNipA4.validateMessage(signed), isTrue);
    });

    test('rejects e tags but parses events that carry them', () {
      expect(
        () => NostrNipA4.generateMessageTemplate(
          content: 'hello',
          receivers: const [_receiver],
          extraTags: const [
            ['e', 'abc'],
          ],
        ),
        throwsArgumentError,
      );

      final withE = _event({
        'kind': 24,
        'content': 'hello',
        'tags': [
          ['p', _receiver],
          ['e', 'abc'],
        ],
      });
      final message = NostrNipA4.parseMessage(withE);

      expect(message.receivers, [_receiver]);
      expect(message.tags, [
        ['e', 'abc'],
      ]);
      expect(message.hasForbiddenThreadTags, isTrue);
      expect(NostrNipA4.validateMessage(withE), isTrue);
    });

    test('allows empty content when an imeta tag carries the media', () {
      final event = NostrNipA4.generateMessageTemplate(
        content: '',
        receivers: const [_receiver],
        extraTags: const [
          ['imeta', 'url https://example.com/a.png', 'm image/png'],
        ],
      );

      expect(event.content, '');
      final message = NostrNipA4.parseMessage(event);
      expect(message.content, isEmpty);
      expect(message.hasImeta, isTrue);
      expect(message.hasForbiddenThreadTags, isFalse);
      expect(NostrNipA4.validateMessage(event), isTrue);

      // Neither content nor imeta stays invalid.
      expect(
        () => NostrNipA4.generateMessageTemplate(
          content: '',
          receivers: const [_receiver],
          extraTags: const [
            ['expiration', '1700000000'],
          ],
        ),
        throwsArgumentError,
      );
      expect(
        NostrNipA4.tryParseMessage(_event({
          'kind': 24,
          'content': '',
          'tags': [
            ['p', _receiver],
            ['expiration', '1700000000'],
          ],
        })),
        isNull,
      );
    });

    test('allows expiration, q and imeta tags', () {
      final event = NostrNipA4.generateMessageTemplate(
        content: 'hello',
        receivers: const [_receiver],
        extraTags: const [
          ['expiration', '1700000000'],
          ['q', 'event-id', 'wss://relay.example', _sender],
          ['imeta', 'url https://example.com/a.png'],
        ],
      );

      final message = NostrNipA4.parseMessage(event);
      expect(message.tags, hasLength(3));
      expect(message.tags[0], ['expiration', '1700000000']);
    });

    test('helpers mark reaction and zap targets for kind 24', () {
      expect(NostrNipA4.kindTag, ['k', '24']);
      expect(
        NostrNipA4.targetsMessage(_event({
          'kind': 7,
          'content': '+',
          'tags': [
            ['k', '24'],
          ],
        })),
        isTrue,
      );
      expect(
        NostrNipA4.targetsMessage(_event({
          'kind': 7,
          'content': '+',
          'tags': [
            ['k', '1'],
          ],
        })),
        isFalse,
      );
    });

    test('resolves receiver inbox and sender outbox relays', () {
      final receiverList = _event({
        'kind': 10002,
        'content': '',
        'tags': [
          ['r', 'wss://inbox.example'],
          ['r', 'wss://both.example'],
          ['r', 'wss://out.example', 'write'],
        ],
      }, pubkey: _receiver);
      final senderList = _event({
        'kind': 10002,
        'content': '',
        'tags': [
          ['r', 'wss://sender-both.example'],
          ['r', 'wss://sender-out.example', 'write'],
          ['r', 'wss://sender-in.example', 'read'],
          ['r', 'not-a-relay'],
        ],
      }, pubkey: _sender);

      expect(
        NostrNipA4.resolveTargetRelays(
          relayLists: [receiverList, senderList],
          receiverPubkeys: const [_receiver],
          senderPubkey: _sender,
        ),
        [
          'wss://inbox.example',
          'wss://both.example',
          'wss://sender-both.example',
          'wss://sender-out.example',
        ],
      );
      expect(
        NostrNipA4.resolveTargetRelays(
          relayLists: const [],
          receiverPubkeys: const [],
        ),
        isEmpty,
      );
    });

    test('rejects invalid builders and parses invalid events', () {
      expect(
        () => NostrNipA4.generateMessageTemplate(
          content: ' ',
          receivers: const [_receiver],
        ),
        throwsArgumentError,
      );
      expect(
        () => NostrNipA4.generateMessageTemplate(
          content: 'hi',
          receivers: const [],
        ),
        throwsArgumentError,
      );
      expect(
        () => NostrNipA4.generateMessageTemplate(
          content: 'hi',
          receivers: const ['not-hex'],
        ),
        throwsArgumentError,
      );

      expect(
          NostrNipA4.tryParseMessage(_event({
            'kind': 24,
            'content': 'hi',
            'tags': [
              ['p', 'not-hex'],
            ],
          })),
          isNull);
      expect(
        () => NostrNipA4.parseMessage(_event({
          'kind': 1,
          'content': 'hi',
          'tags': [
            ['p', _receiver],
          ],
        })),
        throwsArgumentError,
      );
    });
  });

  group('NIP-C0', () {
    test('parses the spec vector', () {
      final event = _event(_c0Vector);
      final snippet = NostrNipC0.parse(event);

      expect(NostrNipC0.snippetKind, 1337);
      expect(snippet.content, _c0Content);
      expect(snippet.language, 'javascript');
      expect(snippet.extension, 'js');
      expect(snippet.name, 'hello-world.js');
      expect(
        snippet.description,
        "A basic JavaScript function that prints 'Hello, Nostr!' to the console",
      );
      expect(snippet.runtime, 'node v18.15.0');
      expect(snippet.licenses.map((license) => license.id), ['MIT']);
      expect(snippet.dependencies, isEmpty);
      expect(
        snippet.repo!.url,
        'https://github.com/nostr-protocol/nostr',
      );
      expect(snippet.tags, isEmpty);
      expect(NostrNipC0.validateSnippet(event), isTrue);
    });

    test('builds the spec vector tags back', () {
      final event = NostrNipC0.generateSnippetTemplate(
        content: _c0Content,
        language: 'javascript',
        extension: 'js',
        name: 'hello-world.js',
        description:
            "A basic JavaScript function that prints 'Hello, Nostr!' to the console",
        runtime: 'node v18.15.0',
        licenses: const [NostrSnippetLicense('MIT')],
        repo: const NostrCodeSnippetRepo.url(
          'https://github.com/nostr-protocol/nostr',
        ),
        createdAt: DateTime.fromMillisecondsSinceEpoch(0),
      );

      expect(event.kind, 1337);
      expect(event.tags, _c0Vector['tags']);
      expect(NostrNipC0.parse(event).tags, isEmpty);
    });

    test('supports repeated licenses, deps and NIP-34 repo addresses', () {
      final event = NostrNipC0.generateSnippetTemplate(
        content: 'void main() {}',
        language: 'dart',
        extension: 'dart',
        licenses: const [
          NostrSnippetLicense('MIT'),
          NostrSnippetLicense(
            'Apache-2.0',
            text: 'https://www.apache.org/licenses/LICENSE-2.0',
          ),
        ],
        dependencies: const ['http', 'meta'],
        repo: const NostrCodeSnippetRepo.event(
          NostrEventAddress(
            kind: 30617,
            pubkey: _sender,
            identifier: 'repo',
          ),
          relay: 'wss://relay.example',
        ),
        extraTags: const [
          ['t', 'code'],
          ['l', 'ignored'],
        ],
        createdAt: DateTime.fromMillisecondsSinceEpoch(0),
      );

      final snippet = NostrNipC0.parse(event);
      expect(snippet.licenses.map((license) => license.id), [
        'MIT',
        'Apache-2.0',
      ]);
      expect(snippet.licenses.last.text, contains('apache.org'));
      expect(snippet.dependencies, ['http', 'meta']);
      expect(snippet.repo!.address!.kind, 30617);
      expect(snippet.repo!.address!.pubkey, _sender);
      expect(snippet.repo!.address!.identifier, 'repo');
      expect(snippet.repo!.relay, 'wss://relay.example');
      expect(snippet.tags, [
        ['t', 'code'],
      ]);
    });

    test('all tags are optional', () {
      final event = _event({
        'kind': 1337,
        'content': 'print(1)',
        'tags': <List<String>>[],
      });
      final snippet = NostrNipC0.parse(event);

      expect(snippet.language, isNull);
      expect(snippet.name, isNull);
      expect(snippet.extension, isNull);
      expect(snippet.description, isNull);
      expect(snippet.runtime, isNull);
      expect(snippet.licenses, isEmpty);
      expect(snippet.dependencies, isEmpty);
      expect(snippet.repo, isNull);
    });

    test('rejects uppercase language, dotted extension, bad license and repo',
        () {
      expect(
        () => NostrNipC0.generateSnippetTemplate(
          content: 'x',
          language: 'JavaScript',
        ),
        throwsArgumentError,
      );
      expect(
        () => NostrNipC0.generateSnippetTemplate(
          content: 'x',
          extension: '.js',
        ),
        throwsArgumentError,
      );
      expect(
        () => NostrNipC0.generateSnippetTemplate(
          content: 'x',
          licenses: const [NostrSnippetLicense('MIT License')],
        ),
        throwsArgumentError,
      );
      expect(
        () => NostrNipC0.generateSnippetTemplate(
          content: 'x',
          dependencies: const [''],
        ),
        throwsArgumentError,
      );
      expect(
        () => NostrNipC0.generateSnippetTemplate(
          content: 'x',
          repo: const NostrCodeSnippetRepo.url('http://insecure.example'),
        ),
        throwsArgumentError,
      );
      expect(
        () => NostrNipC0.generateSnippetTemplate(content: '  '),
        throwsArgumentError,
      );
      expect(NostrCodeSnippetRepo.isValidLicenseId('GPL-3.0-or-later'), isTrue);
      expect(NostrCodeSnippetRepo.isValidLicenseId('not a license'), isFalse);
      // SPDX ids are case-sensitive: canonical ids start uppercase or digit.
      expect(NostrCodeSnippetRepo.isValidLicenseId('mit'), isFalse);
      expect(NostrCodeSnippetRepo.isValidLicenseId('0BSD'), isTrue);
      expect(
        () => NostrNipC0.generateSnippetTemplate(
          content: 'x',
          licenses: const [NostrSnippetLicense('mit')],
        ),
        throwsArgumentError,
      );

      NostrEvent withTags(List<List<String>> tags) => _event({
            'kind': 1337,
            'content': 'x',
            'tags': tags,
          });

      expect(
          NostrNipC0.tryParse(withTags([
            ['l', 'JavaScript']
          ])),
          isNull);
      expect(
          NostrNipC0.tryParse(withTags([
            ['extension', '.js']
          ])),
          isNull);
      expect(
          NostrNipC0.tryParse(withTags([
            ['license', 'MIT License']
          ])),
          isNull);
      expect(
          NostrNipC0.tryParse(withTags([
            ['license', 'mit']
          ])),
          isNull);
      // Every occurrence is validated, not just the first one.
      expect(
        NostrNipC0.tryParse(
          withTags([
            ['l', 'javascript'],
            ['l', 'JavaScript'],
          ]),
        ),
        isNull,
      );
      expect(
        NostrNipC0.tryParse(
          withTags([
            ['extension', 'js'],
            ['extension', '.js'],
          ]),
        ),
        isNull,
      );
      expect(
        NostrNipC0.tryParse(
          withTags([
            ['l', 'dart'],
            ['l', 'dart2'],
            ['extension', 'dart'],
            ['extension', 'dart2'],
          ]),
        )!
            .language,
        'dart',
      );
      expect(
        NostrNipC0.tryParse(
          withTags([
            ['repo', 'http://insecure.example'],
          ]),
        ),
        isNull,
      );
      expect(
        NostrNipC0.tryParse(
          withTags([
            ['repo', '30617:$_sender:repo'],
          ]),
        ),
        isNotNull,
      );
      expect(
        () => NostrNipC0.parse(
          _event({'kind': 1, 'content': 'x', 'tags': <List<String>>[]}),
        ),
        throwsArgumentError,
      );
    });
  });
}
