import 'package:dart_nostr/dart_nostr.dart';
import 'package:test/test.dart';

const _pubkey1 =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _pubkey2 =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const _relay = 'wss://relay.example';
const _eventId =
    'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
const _blobHash =
    'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';
const _server = 'https://you-may-find-the-blob-here.com/path-to-url.ext';

NostrEvent _event(
  int kind,
  List<List<String>> tags, {
  String content = '',
}) {
  return NostrEvent(
    id: null,
    kind: kind,
    content: content,
    sig: null,
    pubkey: _pubkey1,
    createdAt: DateTime.fromMillisecondsSinceEpoch(0),
    tags: tags,
  );
}

/// 32.md:60-70 — `#t` namespace, label marks the target topic.
NostrEvent get _topicVector => _event(1985, [
      ['L', '#t'],
      ['l', 'permies', '#t'],
      ['p', _pubkey1, _relay],
      ['p', _pubkey2, _relay],
    ]);

/// 32.md:75-85 — ontology namespace.
NostrEvent get _ontologyVector => _event(1985, [
      ['L', 'com.example.ontology'],
      ['l', 'VI-hum', 'com.example.ontology'],
      ['p', _pubkey1, _relay],
      ['p', _pubkey2, _relay],
    ]);

/// 32.md:90-99 — nip28 moderation of a chat event.
NostrEvent get _moderationVector => _event(1985, [
      ['L', 'nip28.moderation'],
      ['l', 'approve', 'nip28.moderation'],
      ['e', _eventId, _relay],
    ]);

/// 32.md:104-113 — license assignment.
NostrEvent get _licenseVector => _event(1985, [
      ['L', 'license'],
      ['l', 'MIT', 'license'],
      ['e', _eventId, _relay],
    ]);

void main() {
  final signer = NostrLocalKeySigner(NostrKeyPairs.generate());
  final nip32 = NostrNip32(signer: signer);
  final nip56 = NostrNip56(signer: signer);

  group('NIP-32 label event shape', () {
    test('kind 1985 is a regular kind, not addressable or replaceable', () {
      expect(NostrNip32.labelKind, 1985);
      expect(NostrNip32.labelKind, lessThan(10000));
      expect(NostrEventAddress.isAddressableKind(1985), isFalse);
      expect(NostrNip32.defaultNamespace, 'ugc');
    });

    test('parses the #t namespace vector and keeps # verbatim', () {
      final parsed = NostrNip32.parseEvent(_topicVector);

      expect(parsed.labels, hasLength(1));
      expect(parsed.labels.single.value, 'permies');
      expect(parsed.labels.single.namespace, '#t');
      expect(parsed.labels.single.toTag, ['l', 'permies', '#t']);
      expect(parsed.labels.single.toNamespaceTag, ['L', '#t']);

      expect(parsed.targets, hasLength(2));
      expect(parsed.targets.first.type, NostrLabelTargetType.pubkey);
      expect(parsed.targets.first.value, _pubkey1);
      expect(parsed.targets.first.relay, _relay);
      expect(parsed.targets.last.value, _pubkey2);
      expect(NostrNip32.labelsForNamespace(parsed, '#t'), parsed.labels);
      expect(NostrNip32.labelsForNamespace(parsed, 't'), isEmpty);
    });

    test('parses the ontology, moderation and license vectors', () {
      final ontology = NostrNip32.parseEvent(_ontologyVector);
      expect(ontology.labels.single.namespace, 'com.example.ontology');
      expect(ontology.labels.single.value, 'VI-hum');

      final moderation = NostrNip32.parseEvent(_moderationVector);
      expect(moderation.targets.single.type, NostrLabelTargetType.event);
      expect(moderation.targets.single.value, _eventId);
      expect(moderation.targets.single.relay, _relay);

      final license = NostrNip32.parseEvent(_licenseVector);
      expect(license.labels.single.value, 'MIT');
      expect(
        NostrNip32.labelsForNamespace(license, 'license').single.value,
        'MIT',
      );
    });

    test('absent mark implies the ugc namespace', () {
      final parsed = NostrNip32.parseEvent(
        _event(1985, [
          ['l', 'permies'],
          ['t', 'permies'],
        ]),
      );

      expect(parsed.labels.single.namespace, 'ugc');
      expect(parsed.labels.single.toNamespaceTag, ['L', 'ugc']);
    });

    test('accepts a markless label when no L tag is present', () {
      final event = _event(1985, [
        ['l', 'nsfw'],
        ['r', _relay],
      ]);

      expect(NostrNip32.validateEvent(event), isTrue);
      expect(
        NostrNip32.parseEvent(event).targets.single.type,
        NostrLabelTargetType.relay,
      );
    });

    test('rejects wrong kind, missing targets, labels and L mismatches', () {
      expect(NostrNip32.tryParseEvent(_event(1, _licenseVector.tags!)), isNull);
      expect(
        NostrNip32.tryParseEvent(
          _event(1985, [
            ['L', 'license'],
            ['l', 'MIT', 'license'],
          ]),
        ),
        isNull,
      );
      expect(
        NostrNip32.tryParseEvent(
          _event(1985, [
            ['e', _eventId],
            ['L', 'license'],
          ]),
        ),
        isNull,
      );
      expect(
        NostrNip32.tryParseEvent(
          _event(1985, [
            ['L', 'license'],
            ['l', 'MIT', 'other.namespace'],
            ['e', _eventId],
          ]),
        ),
        isNull,
      );
      expect(
        () => NostrNip32.parseEvent(
          _event(1985, [
            ['e', _eventId],
          ]),
        ),
        throwsArgumentError,
      );
    });

    test('builder derives L tags and matches the license vector', () {
      final event = NostrNip32.generateEventTemplate(
        labels: const [NostrLabel(value: 'MIT', namespace: 'license')],
        targets: const [
          NostrLabelTarget(
            type: NostrLabelTargetType.event,
            value: _eventId,
            relay: _relay,
          ),
        ],
      );

      expect(event.kind, 1985);
      expect(event.tags, [
        ['L', 'license'],
        ['l', 'MIT', 'license'],
        ['e', _eventId, _relay],
      ]);
      expect(NostrNip32.validateEvent(event), isTrue);
    });

    test('builder reproduces the l/L tag prefixes of kind-1 self-label vectors',
        () {
      // 32.md:119-129 and 134-143: on a kind 1 event l/L self-labels it. These
      // assertions cover only the label-tag prefix; kind-1 fields are not built
      // here. Tagging identity itself lives in the events module.
      final milan = NostrNip32.generateEventTemplate(
        labels: const [NostrLabel(value: 'IT-MI', namespace: 'ISO-3166-2')],
        targets: const [
          NostrLabelTarget(type: NostrLabelTargetType.event, value: _eventId),
        ],
      );
      expect(milan.tags!.take(2), [
        ['L', 'ISO-3166-2'],
        ['l', 'IT-MI', 'ISO-3166-2'],
      ]);

      final english = NostrNip32.generateEventTemplate(
        labels: const [NostrLabel(value: 'en', namespace: 'ISO-639-1')],
        targets: const [
          NostrLabelTarget(type: NostrLabelTargetType.event, value: _eventId),
        ],
      );
      expect(english.tags!.take(2), [
        ['L', 'ISO-639-1'],
        ['l', 'en', 'ISO-639-1'],
      ]);
    });

    test('builder rejects empty labels and targets', () {
      expect(
        () => NostrNip32.generateEventTemplate(
          labels: const [NostrLabel(value: 'MIT', namespace: 'license')],
          targets: const [],
        ),
        throwsArgumentError,
      );
      expect(
        () => NostrNip32.generateEventTemplate(
          labels: const [],
          targets: const [
            NostrLabelTarget(type: NostrLabelTargetType.event, value: _eventId),
          ],
        ),
        throwsArgumentError,
      );
      expect(
        () => NostrNip32.generateEventTemplate(
          labels: const [NostrLabel(value: '', namespace: 'license')],
          targets: const [
            NostrLabelTarget(type: NostrLabelTargetType.event, value: _eventId),
          ],
        ),
        throwsArgumentError,
      );
      expect(
        () => NostrNip32.generateEventTemplate(
          labels: const [NostrLabel(value: 'MIT', namespace: '')],
          targets: const [
            NostrLabelTarget(type: NostrLabelTargetType.event, value: _eventId),
          ],
        ),
        throwsArgumentError,
      );
    });

    test('builder limits events to one namespace by default', () {
      const targets = [
        NostrLabelTarget(type: NostrLabelTargetType.event, value: _eventId),
      ];

      expect(
        () => NostrNip32.generateEventTemplate(
          labels: const [
            NostrLabel(value: 'a', namespace: 'one'),
            NostrLabel(value: 'b', namespace: 'two'),
          ],
          targets: targets,
        ),
        throwsArgumentError,
      );

      final multi = NostrNip32.generateEventTemplate(
        labels: const [
          NostrLabel(value: 'a', namespace: 'one'),
          NostrLabel(value: 'b', namespace: 'two'),
        ],
        targets: targets,
        allowMultipleNamespaces: true,
      );
      expect(multi.tags!.take(4), [
        ['L', 'one'],
        ['L', 'two'],
        ['l', 'a', 'one'],
        ['l', 'b', 'two'],
      ]);
    });

    test('qualified labels keep their namespace prefix', () {
      final parsed = NostrNip32.parseEvent(
        _event(1985, [
          ['L', 'com.example.vocabulary'],
          ['l', 'com.example.vocabulary:my-label', 'com.example.vocabulary'],
          ['e', _eventId],
        ]),
      );

      expect(parsed.labels.single.value, 'com.example.vocabulary:my-label');
      expect(
        parsed.labels.single.toTag,
        ['l', 'com.example.vocabulary:my-label', 'com.example.vocabulary'],
      );
    });

    test('relay hints only apply to e and p targets', () {
      const target = NostrLabelTarget(
        type: NostrLabelTargetType.topic,
        value: 'permies',
        relay: _relay,
      );
      expect(target.toTag, ['t', 'permies']);

      const address = NostrLabelTarget(
        type: NostrLabelTargetType.address,
        value: '30023:$_pubkey1:post',
        relay: _relay,
      );
      expect(address.toTag, ['a', '30023:$_pubkey1:post']);
      expect(NostrLabelTargetType.fromTagName('x'), isNull);
    });

    test('publishes a signed label event', () async {
      final event = await nip32.publish(
        labels: const [
          NostrLabel(value: 'approve', namespace: 'nip28.moderation'),
        ],
        targets: const [
          NostrLabelTarget(
            type: NostrLabelTargetType.event,
            value: _eventId,
            relay: _relay,
          ),
        ],
      );

      expect(event.kind, 1985);
      expect(event.pubkey, signer.publicKey);
      expect(event.id, isNotNull);
      expect(event.sig, isNotNull);
      expect(NostrNip32.parseEvent(event).labels.single.value, 'approve');
    });
  });

  group('NIP-56 report event shape', () {
    test('kind 1984 and known report types', () {
      expect(NostrNip56.reportKind, 1984);
      expect(NostrNip56.reportTypes, hasLength(7));
      expect(NostrNip56.isValidReportType('nudity'), isTrue);
      expect(NostrNip56.isValidReportType('impersonation'), isTrue);
      expect(NostrNip56.isValidReportType('violence'), isFalse);
      expect(NostrReportType.fromValue('spam'), NostrReportType.spam);
      expect(NostrReportType.fromValue('violence'), isNull);
    });

    test('parses the nudity + ontology vector (56.md:46-57)', () {
      final report = NostrNip56.parse(
        _event(
          1984,
          [
            ['p', _pubkey1, 'nudity'],
            ['L', 'social.nos.ontology'],
            ['l', 'NS-nud', 'social.nos.ontology'],
          ],
        ),
      );

      expect(report.reportedPubkey, _pubkey1);
      expect(report.rawType, 'nudity');
      expect(report.knownType, NostrReportType.nudity);
      expect(report.eventId, isNull);
      expect(report.labels.single.value, 'NS-nud');
      expect(report.labels.single.namespace, 'social.nos.ontology');
    });

    test('parses the note report vector (56.md:59-69)', () {
      final report = NostrNip56.parse(
        _event(
          1984,
          [
            ['e', _eventId, 'illegal'],
            ['p', _pubkey1],
          ],
          content: "He's insulting the king!",
        ),
      );

      expect(report.reportedPubkey, _pubkey1);
      expect(report.eventId, _eventId);
      expect(report.rawType, 'illegal');
      expect(report.knownType, NostrReportType.illegal);
      expect(report.content, "He's insulting the king!");
    });

    test('parses the impersonation vector (56.md:71-80)', () {
      final report = NostrNip56.parse(
        _event(
          1984,
          [
            ['p', _pubkey2, 'impersonation'],
          ],
          content: 'Profile is impersonating nostr:npub1victim',
        ),
      );

      expect(report.reportedPubkey, _pubkey2);
      expect(report.rawType, 'impersonation');
      expect(report.knownType, NostrReportType.impersonation);
    });

    test('parses the blob malware vector (56.md:82-93)', () {
      // The spec example omits the mandatory p tag (56.md:20-21); a real blob
      // report carries it, and strict parsing requires it.
      final report = NostrNip56.parse(
        _event(
          1984,
          [
            ['p', _pubkey1, 'malware'],
            ['x', _blobHash, 'malware'],
            ['e', _eventId, 'malware'],
            ['server', _server],
          ],
          content: 'This file contains malware software in it.',
        ),
      );

      expect(report.blobHash, _blobHash);
      expect(report.eventId, _eventId);
      expect(report.server, _server);
      expect(report.rawType, 'malware');
      expect(report.knownType, NostrReportType.malware);

      // Without the required p tag the same tags are not a report.
      expect(
        NostrNip56.tryParse(
          _event(1984, [
            ['x', _blobHash, 'malware'],
            ['e', _eventId, 'malware'],
            ['server', _server],
          ]),
        ),
        isNull,
      );
    });

    test('requires e when a blob x tag is present', () {
      final withoutEvent = _event(1984, [
        ['p', _pubkey1, 'malware'],
        ['x', _blobHash, 'malware'],
      ]);
      expect(NostrNip56.validateEvent(withoutEvent), isFalse);
      expect(NostrNip56.tryParse(withoutEvent), isNull);

      final withEvent = _event(1984, [
        ['p', _pubkey1, 'malware'],
        ['x', _blobHash, 'malware'],
        ['e', _eventId, 'malware'],
      ]);
      expect(NostrNip56.validateEvent(withEvent), isTrue);
      expect(NostrNip56.tryParse(withEvent)!.blobHash, _blobHash);
    });

    test('preserves unknown report types instead of dropping events', () {
      final event = _event(1984, [
        ['p', _pubkey1],
        ['e', _eventId, 'violence'],
      ]);

      expect(NostrNip56.validateEvent(event), isTrue);

      final report = NostrNip56.parse(event);
      expect(report.rawType, 'violence');
      expect(report.knownType, isNull);
    });

    test('returns null for wrong kind, missing p or missing type', () {
      expect(
        NostrNip56.tryParse(
          _event(1, [
            ['p', _pubkey1, 'nudity'],
          ]),
        ),
        isNull,
      );
      expect(
        NostrNip56.tryParse(
          _event(1984, [
            ['e', _eventId, 'illegal'],
          ]),
        ),
        isNull,
      );
      expect(
        NostrNip56.tryParse(
          _event(1984, [
            ['p', _pubkey1],
          ]),
        ),
        isNull,
      );
      expect(() => NostrNip56.parse(_event(1984, [])), throwsArgumentError);
      expect(
        NostrNip56.tryParse(
          _event(1984, [
            ['p', ''],
            ['e', _eventId, 'spam'],
          ]),
        ),
        isNull,
      );
    });

    test('builds a profile report', () async {
      final event = await nip56.createReport(
        reportedPubkey: _pubkey2,
        type: 'impersonation',
        content: 'Profile is impersonating nostr:npub1victim',
      );

      expect(event.kind, 1984);
      expect(event.pubkey, signer.publicKey);
      expect(event.tags, [
        ['p', _pubkey2, 'impersonation'],
      ]);
      expect(NostrNip56.parse(event).knownType, NostrReportType.impersonation);
    });

    test('builds a note report and attaches NIP-32 labels', () async {
      final event = await nip56.createReport(
        reportedPubkey: _pubkey1,
        eventId: _eventId,
        type: 'illegal',
        labels: const [
          NostrLabel(value: 'NS-nud', namespace: 'social.nos.ontology'),
        ],
      );

      expect(event.tags, [
        ['p', _pubkey1, 'illegal'],
        ['e', _eventId, 'illegal'],
        ['L', 'social.nos.ontology'],
        ['l', 'NS-nud', 'social.nos.ontology'],
      ]);

      final report = NostrNip56.parse(event);
      expect(report.labels.single.namespace, 'social.nos.ontology');
      expect(report.rawType, 'illegal');
    });

    test('builds a blob report with x, e and server', () async {
      final event = await nip56.createReport(
        reportedPubkey: _pubkey1,
        eventId: _eventId,
        blobHash: _blobHash,
        server: _server,
        type: 'malware',
        content: 'This file contains malware software in it.',
      );

      expect(event.tags, [
        ['p', _pubkey1, 'malware'],
        ['e', _eventId, 'malware'],
        ['x', _blobHash, 'malware'],
        ['server', _server],
      ]);
      expect(NostrNip56.parse(event).server, _server);
    });

    test('builder rejects missing p, empty/unknown types and x without e', () {
      expect(
        () => nip56.createReport(reportedPubkey: '', type: 'nudity'),
        throwsArgumentError,
      );
      expect(
        () => nip56.createReport(reportedPubkey: _pubkey1, type: ''),
        throwsArgumentError,
      );
      expect(
        () => nip56.createReport(reportedPubkey: _pubkey1, type: 'violence'),
        throwsArgumentError,
      );
      expect(
        () => nip56.createReport(
          reportedPubkey: _pubkey1,
          blobHash: _blobHash,
          type: 'malware',
        ),
        throwsArgumentError,
      );
    });

    test('report type in slot 2 is not a NIP-32 relay hint', () {
      // Same slot, different meaning: a report type must never be parsed as
      // a relay hint, and a relay hint must never be parsed as a report type.
      final report = NostrNip56.parse(
        _event(1984, [
          ['e', _eventId, 'spam'],
          ['p', _pubkey1],
        ]),
      );
      expect(report.rawType, 'spam');

      final label = NostrNip32.parseEvent(
        _event(1985, [
          ['L', 'license'],
          ['l', 'MIT', 'license'],
          ['e', _eventId, _relay],
        ]),
      );
      expect(label.targets.single.relay, _relay);
    });
  });

  group('signer-bound wiring', () {
    test('nip32 and nip56 require and reuse the bound signer', () {
      final nips = NostrNips(logger: Nostr.instance.services.logger);

      expect(() => nips.nip32, throwsStateError);
      expect(() => nips.nip56, throwsStateError);

      nips.bindSigner(signer);
      expect(nips.nip32, same(nips.nip32));
      expect(nips.nip32.signer, same(signer));
      expect(nips.nip56, same(nips.nip56));
      expect(nips.nip56.signer, same(signer));

      final other = NostrLocalKeySigner(NostrKeyPairs.generate());
      nips.bindSigner(other);
      expect(nips.nip32.signer, same(other));
      expect(nips.nip56.signer, same(other));

      nips.bindSigner(null);
      expect(() => nips.nip32, throwsStateError);
      expect(() => nips.nip56, throwsStateError);
    });
  });
}
