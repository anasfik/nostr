import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dart_nostr/dart_nostr.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

const String _pubkey =
    '3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d';
const String _otherKey =
    'afc93622eb4d79c0fb75e56e0c14553f7214b0a466abeba14cb38968c6755e6a';
const String _commit = '0123456789abcdef0123456789abcdef01234567';
const String _npub =
    'npub15qydau2hjma6ngxkl2cyar74wzyjshvl65za5k5rl69264ar2exs5cyejr';
const String _voiceUrl = 'https://blossom.primal.net/'
    '5fe7df0e46ee6b14b5a8b8b92939e84e3ca5e3950eb630299742325d5ed9891b.mp4';

NostrEvent _event({
  required int kind,
  String content = '',
  List<List<String>> tags = const <List<String>>[],
  String pubkey = _pubkey,
  DateTime? createdAt,
  String? id,
  String? sig,
}) =>
    NostrEvent(
      id: id,
      kind: kind,
      content: content,
      sig: sig,
      pubkey: pubkey,
      createdAt: createdAt ?? DateTime.utc(2024),
      tags: tags,
    );

class _TrackingClient extends http.BaseClient {
  bool closed = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async =>
      http.StreamedResponse(Stream<List<int>>.value(utf8.encode('{}')), 200);

  @override
  void close() {
    closed = true;
  }
}

void main() {
  group('NIP-34 git stuff', () {
    test('nostr:// clone URIs round-trip the four spec examples', () {
      const vectors = [
        'nostr://$_npub/relay.ngit.dev/ngit',
        'nostr://$_npub/my%20%F0%9F%9A%80%20repo',
        'nostr://danconwaydev.com/ws%3A%2F%2Flocalhost%3A7334/'
            'my-local-only-repo',
        'nostr://danconwaydev.com/relay.ngit.dev/ngit',
      ];

      for (final vector in vectors) {
        final uri = NostrGitCloneUri.parse(vector);

        expect(uri.toString(), vector);
        expect(uri.isNaddr, isFalse);
        expect(uri.identifier, isNotEmpty);
      }

      final local = NostrGitCloneUri.parse(vectors[2]);

      expect(local.relayHint, 'ws://localhost:7334');
      expect(local.identifier, 'my-local-only-repo');
      expect(local.pubkeyOrNip05, 'danconwaydev.com');

      final spaced = NostrGitCloneUri.parse(vectors[1]);
      expect(spaced.identifier, 'my 🚀 repo');

      final entity = NostrGitCloneUri.parse('nostr://naddr1qqqq');
      expect(entity.isNaddr, isTrue);
      expect(entity.toString(), 'nostr://naddr1qqqq');
    });

    test('percent-encodes only RFC 3986 unreserved characters', () {
      final uri = NostrGitCloneUri.repository(
        pubkeyOrNip05: 'danconwaydev.com',
        relayHint: "wss://relay.example/a!b*c'd(e)",
        identifier: "my!*'() repo",
      );

      expect(
        uri.toString(),
        'nostr://danconwaydev.com/'
        'wss%3A%2F%2Frelay.example%2Fa%21b%2Ac%27d%28e%29/'
        'my%21%2A%27%28%29%20repo',
      );
      expect(NostrGitCloneUri.parse(uri.toString()).identifier, "my!*'() repo");
    });

    test('rejects malformed clone URIs', () {
      expect(NostrGitCloneUri.tryParse('https://example.com/repo'), isNull);
      expect(NostrGitCloneUri.tryParse('nostr://'), isNull);
      expect(NostrGitCloneUri.tryParse('nostr://danconwaydev.com/'), isNull);
      expect(
        NostrGitCloneUri.tryParse('nostr://danconwaydev.com/a/b/c'),
        isNull,
      );
      expect(
        NostrGitCloneUri.tryParse('nostr://danconwaydev.com/%ZZ/repo'),
        isNull,
      );
      expect(
        NostrGitCloneUri.tryParse('nostr://danconwaydev.com/%FF/repo'),
        isNull,
      );
      expect(NostrGitCloneUri.tryParse('nostr://naddr1'), isNull);
      expect(
        () => NostrGitCloneUri.naddr('naddr1'),
        throwsArgumentError,
      );
    });

    test('parses the repository announcement vector', () {
      final event = _event(
        kind: NostrNip34.repoAnnouncementKind,
        tags: [
          ['d', 'repo-id'],
          ['name', 'My Repo'],
          ['description', 'A repository'],
          ['web', 'https://example.com/repo'],
          ['clone', 'https://example.com/repo.git'],
          ['relays', 'wss://relay.example'],
          ['r', _commit, 'euc'],
          ['maintainers', _otherKey],
          [
            'u',
            '30617:$_otherKey:forked',
            'wss://relay.example',
            _otherKey,
          ],
          ['t', 'git'],
        ],
      );

      final repo = NostrNip34.parseRepoAnnouncement(event);

      expect(repo.identifier, 'repo-id');
      expect(repo.name, 'My Repo');
      expect(repo.clone, ['https://example.com/repo.git']);
      expect(repo.relays, ['wss://relay.example']);
      expect(repo.maintainers, [_otherKey]);
      expect(repo.earliestUniqueCommit, _commit);
      expect(repo.forkAddress, '30617:$_otherKey:forked');
      expect(repo.forkRelayUrl, 'wss://relay.example');
      expect(repo.forkAuthorPubkey, _otherKey);
      expect(repo.hashtags, ['git']);
      expect(repo.isValid, isTrue);
    });

    test('decomposes the fork u tag into address and git URL', () {
      final event = _event(
        kind: NostrNip34.repoAnnouncementKind,
        tags: [
          ['d', 'repo-id'],
          [
            'u',
            '30617:$_otherKey:forked|https://example.com/fork.git',
            'wss://relay.example',
            _otherKey,
          ],
        ],
      );

      final repo = NostrNip34.parseRepoAnnouncement(event);

      expect(repo.forkAddress, '30617:$_otherKey:forked');
      expect(repo.forkUrl, 'https://example.com/fork.git');
      expect(repo.forkTag, [
        'u',
        '30617:$_otherKey:forked|https://example.com/fork.git',
        'wss://relay.example',
        _otherKey,
      ]);

      final rebuilt = NostrNip34.createRepoAnnouncement(
        identifier: 'repo-id',
        forkAddress: repo.forkAddress,
        forkUrl: repo.forkUrl,
        forkRelayUrl: repo.forkRelayUrl,
        forkAuthorPubkey: repo.forkAuthorPubkey,
      );

      expect(
        rebuilt.tags,
        contains(
          equals([
            'u',
            '30617:$_otherKey:forked|https://example.com/fork.git',
            'wss://relay.example',
            _otherKey,
          ]),
        ),
      );
    });

    test('round-trips an empty fork relay slot before the author', () {
      final event = _event(
        kind: NostrNip34.repoAnnouncementKind,
        tags: [
          ['d', 'repo-id'],
          ['u', '30617:$_otherKey:forked', '', _otherKey],
        ],
      );

      final repo = NostrNip34.parseRepoAnnouncement(event);

      expect(repo.forkRelayUrl, isNull);
      expect(repo.forkAuthorPubkey, _otherKey);

      final rebuilt = NostrNip34.createRepoAnnouncement(
        identifier: 'repo-id',
        forkAddress: repo.forkAddress,
        forkRelayUrl: repo.forkRelayUrl,
        forkAuthorPubkey: repo.forkAuthorPubkey,
      );

      final forkTag = rebuilt.tags!.firstWhere((tag) => tag.first == 'u');

      expect(forkTag, ['u', '30617:$_otherKey:forked', '', _otherKey]);

      final reparsed = NostrNip34.parseRepoAnnouncement(rebuilt);

      expect(reparsed.forkRelayUrl, isNull);
      expect(reparsed.forkAuthorPubkey, _otherKey);
      expect(reparsed.forkTag, forkTag);
    });

    test('builds repository announcements and state refs', () {
      final announcement = NostrNip34.createRepoAnnouncement(
        identifier: 'repo-id',
        name: 'My Repo',
        relays: const ['wss://relay.example'],
        maintainers: const [_otherKey],
        earliestUniqueCommit: _commit,
      );

      expect(
        announcement.tags,
        containsAllInOrder([
          ['d', 'repo-id'],
          ['r', _commit, 'euc'],
          ['maintainers', _otherKey],
        ]),
      );

      final state = NostrNip34.createRepoState(
        identifier: 'repo-id',
        heads: const {'main': _commit},
        tags: const {'v1': _commit},
        headBranch: 'main',
      );

      expect(
        state.tags,
        [
          ['d', 'repo-id'],
          ['refs/heads/main', _commit],
          ['refs/tags/v1', _commit],
          ['HEAD', 'ref: refs/heads/main'],
        ],
      );

      final parsed = NostrNip34.parseRepoState(state);

      expect(parsed.heads, {'main': _commit});
      expect(parsed.tagRefs, {'v1': _commit});
      expect(parsed.headBranch, 'main');
      expect(
        NostrNip34.tryParseRepoState(
          _event(
            kind: NostrNip34.repoStateKind,
            tags: [
              ['d', 'repo-id'],
              ['HEAD', 'ref: refs/tags/v1'],
            ],
          ),
        ),
        isNull,
      );
    });

    test('parses patches, pull requests, updates and issues', () {
      final patch = NostrNip34.createPatch(
        content: 'From abc Mon Sep 17 00:00:00 2001',
        repositoryAddress: '30617:$_pubkey:repo-id',
        earliestUniqueCommit: _commit,
        recipients: const [_otherKey],
        isRoot: true,
        commit: _commit,
        parentCommit: _commit,
        committer: const NostrGitCommitter(
          name: 'Dev',
          email: 'dev@example.com',
          timestamp: 1700000000,
          timezoneOffsetMinutes: 60,
        ),
        rootEventId: _pubkey,
      );

      final parsedPatch = NostrNip34.parsePatch(patch);

      expect(parsedPatch.isRoot, isTrue);
      expect(parsedPatch.isRootRevision, isFalse);
      expect(parsedPatch.commit, _commit);
      expect(parsedPatch.committer?.name, 'Dev');
      expect(parsedPatch.committer?.timezoneOffsetMinutes, 60);
      expect(parsedPatch.rootEventId, _pubkey);
      expect(patch.tags, contains(equals(['e', _pubkey, '', 'reply'])));

      final pr = NostrNip34.createPullRequest(
        content: 'Please merge',
        commit: _commit,
        clone: const ['https://example.com/repo.git'],
        repositoryAddress: '30617:$_pubkey:repo-id',
        recipients: const [_otherKey],
        subject: 'Fix',
        labels: const ['bug'],
        branchName: 'fix',
        mergeBase: _commit,
      );

      final parsedPr = NostrNip34.parsePullRequest(pr);

      expect(parsedPr.subject, 'Fix');
      expect(parsedPr.labels, ['bug']);
      expect(parsedPr.branchName, 'fix');
      expect(parsedPr.clone, ['https://example.com/repo.git']);
      expect(parsedPr.isValid, isTrue);

      final update = NostrNip34.createPullRequestUpdate(
        pullRequestEventId: _pubkey,
        pullRequestAuthorPubkey: _otherKey,
        commit: _commit,
        clone: const ['https://example.com/repo.git'],
      );

      final parsedUpdate = NostrNip34.parsePullRequestUpdate(update);

      expect(parsedUpdate.pullRequestEventId, _pubkey);
      expect(parsedUpdate.pullRequestAuthorPubkey, _otherKey);
      expect(parsedUpdate.commit, _commit);

      final issue = NostrNip34.createIssue(
        content: 'Something is broken',
        repositoryAddress: '30617:$_pubkey:repo-id',
        recipients: const [_otherKey],
        subject: 'Bug',
        labels: const ['bug'],
      );

      final parsedIssue = NostrNip34.parseIssue(issue);

      expect(parsedIssue.content, 'Something is broken');
      expect(parsedIssue.subject, 'Bug');
      expect(parsedIssue.labels, ['bug']);
    });

    test('status events use literal root/reply e tag markers', () {
      final event = NostrNip34.createStatus(
        kind: NostrGitStatusKind.applied,
        rootEventId: _pubkey,
        acceptedRevisionId: _otherKey,
        recipients: const [_otherKey],
        repositoryAddress: '30617:$_pubkey:repo-id',
        earliestUniqueCommit: _commit,
        appliedAsCommits: const [_commit],
      );

      expect(event.kind, 1631);
      expect(event.tags, contains(equals(['e', _pubkey, '', 'root'])));
      expect(event.tags, contains(equals(['e', _otherKey, '', 'reply'])));

      final status = NostrNip34.parseStatus(event);

      expect(status.status, NostrGitStatusKind.applied);
      expect(status.rootEventId, _pubkey);
      expect(status.acceptedRevisionId, _otherKey);
      expect(status.appliedAsCommits, [_commit]);
    });

    test('q tags keep the optional relay and author slots', () {
      final event = _event(
        kind: NostrGitStatusKind.applied.kind,
        tags: [
          ['e', _pubkey, '', 'root'],
          ['q', _otherKey],
          ['q', _commit, 'wss://relay.example', _otherKey],
          ['q', 'd' * 64, '', _pubkey],
        ],
      );

      final status = NostrNip34.parseStatus(event);

      expect(status.appliedPatchIds, [_otherKey, _commit, 'd' * 64]);
      expect(status.appliedPatches.first.relayUrl, isNull);
      expect(status.appliedPatches[1].relayUrl, 'wss://relay.example');
      expect(status.appliedPatches[1].pubkey, _otherKey);
      expect(
        status.appliedPatches[1].toTag(),
        ['q', _commit, 'wss://relay.example', _otherKey],
      );
      expect(
        status.appliedPatches.last.toTag(),
        ['q', 'd' * 64, '', _pubkey],
      );

      final rebuilt = NostrNip34.createStatus(
        kind: NostrGitStatusKind.applied,
        rootEventId: _pubkey,
        appliedPatchIds: const [_otherKey],
        appliedPatches: status.appliedPatches.sublist(1),
      );

      expect(rebuilt.tags, contains(equals(['q', _otherKey])));
      expect(
        rebuilt.tags,
        contains(equals(['q', _commit, 'wss://relay.example', _otherKey])),
      );
    });

    test('resolveStatus picks the newest author or maintainer status', () {
      NostrEvent status(
        String author,
        DateTime at,
        NostrGitStatusKind kind,
      ) =>
          NostrNip34.createStatus(
            kind: kind,
            rootEventId: _pubkey,
            createdAt: at,
          ).copyWithAuthor(author);

      final winner = NostrNip34.resolveStatus(
        statuses: [
          status(_pubkey, DateTime.utc(2024, 1, 1), NostrGitStatusKind.open),
          status(
            _otherKey,
            DateTime.utc(2024, 1, 2),
            NostrGitStatusKind.applied,
          ),
          status(
            'c' * 64,
            DateTime.utc(2024, 1, 3),
            NostrGitStatusKind.closed,
          ),
        ],
        rootAuthorPubkey: _pubkey,
        maintainers: const [_otherKey],
      );

      expect(winner?.status, NostrGitStatusKind.applied);
    });

    test('resolveStatus derives a revision status from its root', () {
      final root = NostrNip34.createStatus(
        kind: NostrGitStatusKind.applied,
        rootEventId: _pubkey,
        appliedPatchIds: const [_otherKey],
      );
      final rootStatus = NostrNip34.parseStatus(root);

      final inherited = NostrNip34.resolveStatus(
        statuses: const [],
        rootAuthorPubkey: _pubkey,
        rootStatus: rootStatus,
        revisionId: _otherKey,
      );
      final untagged = NostrNip34.resolveStatus(
        statuses: const [],
        rootAuthorPubkey: _pubkey,
        rootStatus: rootStatus,
        revisionId: _commit,
      );
      final openRoot = NostrNip34.resolveStatus(
        statuses: const [],
        rootAuthorPubkey: _pubkey,
        rootStatus: NostrNip34.parseStatus(
          NostrNip34.createStatus(
            kind: NostrGitStatusKind.open,
            rootEventId: _pubkey,
          ),
        ),
        revisionId: _commit,
      );

      expect(inherited?.status, NostrGitStatusKind.applied);
      expect(untagged?.status, NostrGitStatusKind.closed);
      expect(openRoot?.status, NostrGitStatusKind.open);

      final fromRootStatuses = NostrNip34.resolveStatus(
        statuses: [root.copyWithAuthor(_pubkey)],
        rootAuthorPubkey: _pubkey,
        revisionId: _commit,
      );

      expect(fromRootStatuses?.status, NostrGitStatusKind.closed);

      final explicit = NostrNip34.resolveStatus(
        statuses: [
          NostrNip34.createStatus(
            kind: NostrGitStatusKind.draft,
            rootEventId: _otherKey,
            createdAt: DateTime.utc(2024, 1, 2),
          ).copyWithAuthor(_pubkey),
        ],
        rootAuthorPubkey: _pubkey,
        rootStatus: rootStatus,
        revisionId: _commit,
      );

      expect(explicit?.status, NostrGitStatusKind.draft);
    });

    test('builds and parses grasp lists', () {
      final event = NostrNip34.createRepoList(
        graspServers: const ['wss://grasp.example'],
      );
      final list = NostrNip34.parseRepoList(event);

      expect(list.graspServers, ['wss://grasp.example']);
    });

    test('validation failures throw or return null', () {
      expect(
        () => NostrNip34.createPatch(content: ' '),
        throwsArgumentError,
      );
      expect(
        () => NostrNip34.createRepoAnnouncement(
            identifier: 'x', relays: ['http://bad']),
        throwsArgumentError,
      );
      expect(
        () => NostrNip34.createStatus(
          kind: NostrGitStatusKind.open,
          rootEventId: 'not-hex',
        ),
        throwsArgumentError,
      );
      expect(
        () => NostrNip34.createPullRequest(
          content: '',
          commit: _commit,
          clone: const [],
        ),
        throwsArgumentError,
      );
      expect(
        NostrNip34.tryParsePatch(
          _event(kind: NostrNip34.patchKind, content: ''),
        ),
        isNull,
      );
      expect(
        () => NostrNip34.parseIssue(_event(kind: 1)),
        throwsArgumentError,
      );
    });
  });

  group('NIP-66 relay liveness', () {
    test('parses the relay discovery vector', () {
      final event = _event(
        kind: NostrNip66.discoveryKind,
        content: '<optional nip 11 document>',
        tags: [
          ['d', 'wss://some.relay/'],
          ['n', 'clearnet'],
          ['N', '40'],
          ['N', '33'],
          ['R', '!payment'],
          ['R', 'auth'],
          ['g', 'ww8p1r4t8'],
          ['l', 'en', 'ISO-639-1'],
          ['t', 'nsfw'],
          ['rtt-open', '234'],
        ],
      );

      final relay = NostrNip66.parseAnnouncement(event);

      expect(relay.relay, 'wss://some.relay/');
      expect(relay.network, 'clearnet');
      expect(relay.nips, ['40', '33']);
      expect(relay.requirements, ['!payment', 'auth']);
      expect(relay.geohashes, ['ww8p1r4t8']);
      expect(relay.languages, ['en']);
      expect(relay.topics, ['nsfw']);
      expect(relay.rttOpen, 234);
      expect(relay.nip11, isNull);
      expect(relay.isValid, isTrue);
    });

    test('normalizes relay identifiers and parses NIP-11 content', () {
      expect(
        NostrNip66.normalizeRelayIdentifier('WSS://Some.Relay:443'),
        'wss://some.relay',
      );
      expect(
        NostrNip66.normalizeRelayIdentifier('wss://some.relay/path?x=1'),
        'wss://some.relay/path?x=1',
      );
      expect(NostrNip66.normalizeRelayIdentifier('a' * 64), 'a' * 64);
      expect(
          NostrNip66.normalizeRelayIdentifier('https://relay.example'), isNull);
      expect(
        NostrNip66.describesRelay('wss://some.relay/', 'WSS://some.relay'),
        isTrue,
      );

      final announcement = NostrNip66.createMonitorAnnouncement(
        relay: 'wss://some.relay',
        network: 'clearnet',
        relayTypes: const ['PrivateInbox'],
        nips: const ['1', '11'],
        requirements: const ['!payment'],
        topics: const ['cats'],
        kinds: const ['1', '!4'],
        geohashes: const ['ww8p1r4t8'],
        languages: const ['en'],
        rttOpen: 100,
        nip11: const {'name': 'some relay'},
      );

      final parsed = NostrNip66.parseAnnouncement(announcement);

      expect(parsed.relay, 'wss://some.relay');
      expect(parsed.relayTypes, ['PrivateInbox']);
      expect(parsed.kinds, ['1', '!4']);
      expect(parsed.nip11, {'name': 'some relay'});
      expect(parsed.tags, isEmpty);
    });

    test('unknown network and non-numeric kinds follow the SHOULD wording', () {
      final unknown = NostrNip66.tryParseAnnouncement(
        _event(
          kind: NostrNip66.discoveryKind,
          tags: [
            ['d', 'wss://some.relay'],
            ['n', 'yggdrasil'],
          ],
        ),
      );

      expect(unknown, isNotNull);
      expect(unknown!.network, 'yggdrasil');
      expect(unknown.hasKnownNetwork, isFalse);
      expect(unknown.isValid, isTrue);

      expect(
        () => NostrNip66.createMonitorAnnouncement(
          relay: 'wss://some.relay',
          kinds: const ['not-a-kind'],
        ),
        throwsArgumentError,
      );

      final event = NostrNip66.createMonitorAnnouncement(
        relay: 'wss://some.relay',
        kinds: const ['1', '!4'],
      );

      expect(
        event.tags,
        containsAllInOrder([
          ['k', '1'],
          ['k', '!4'],
        ]),
      );
    });

    test('malformed NIP-11 JSON and RTT values are handled tolerantly', () {
      final malformed = _event(
        kind: NostrNip66.discoveryKind,
        content: '{not json',
        tags: [
          ['d', 'wss://some.relay'],
        ],
      );

      expect(NostrNip66.tryParseAnnouncement(malformed)?.nip11, isNull);
      expect(
        NostrNip66.tryParseAnnouncement(
          _event(
            kind: NostrNip66.discoveryKind,
            tags: [
              ['d', 'wss://some.relay'],
              ['rtt-open', 'nope'],
            ],
          ),
        ),
        isNull,
      );
      expect(
        NostrNip66.tryParseAnnouncement(
          _event(
            kind: NostrNip66.discoveryKind,
            tags: [
              ['d', 'not-a-relay'],
            ],
          ),
        ),
        isNull,
      );
    });

    test('accepts both timeout parameter orders', () {
      final exampleOrder = NostrRelayTimeout.tryParse(
        ['timeout', 'open', '5000'],
      );
      final proseOrder = NostrRelayTimeout.tryParse(
        ['timeout', '5000', 'open'],
      );
      final allChecks = NostrRelayTimeout.tryParse(['timeout', '3000']);

      expect(exampleOrder?.check, 'open');
      expect(exampleOrder?.milliseconds, 5000);
      expect(proseOrder?.check, 'open');
      expect(proseOrder?.milliseconds, 5000);
      expect(allChecks?.check, isNull);
      expect(allChecks?.milliseconds, 3000);
      expect(NostrRelayTimeout.tryParse(['timeout', 'open', 'x']), isNull);
    });

    test('parses and builds the monitor announcement vector', () {
      final event = _event(
        kind: NostrNip66.monitorListKind,
        tags: [
          ['timeout', 'open', '5000'],
          ['timeout', 'read', '3000'],
          ['timeout', 'write', '3000'],
          ['timeout', 'nip11', '3000'],
          ['frequency', '3600'],
          ['c', 'ws'],
          ['c', 'nip11'],
          ['c', 'ssl'],
          ['c', 'dns'],
          ['c', 'geo'],
          ['g', 'ww8p1r4t8'],
        ],
      );

      final monitor = NostrNip66.parseMonitorList(event);

      expect(monitor.frequency, 3600);
      expect(monitor.timeouts, hasLength(4));
      expect(monitor.checks, ['ws', 'nip11', 'ssl', 'dns', 'geo']);
      expect(monitor.geohashes, ['ww8p1r4t8']);

      final built = NostrNip66.createMonitorList(
        frequency: 3600,
        timeouts: const [
          NostrRelayTimeout(milliseconds: 5000, check: 'open'),
          NostrRelayTimeout(milliseconds: 3000, check: 'read'),
        ],
        checks: const ['ws'],
        geohashes: const ['ww8p1r4t8'],
      );

      expect(
        built.tags,
        containsAllInOrder([
          ['timeout', 'open', '5000'],
          ['timeout', 'read', '3000'],
          ['frequency', '3600'],
        ]),
      );

      expect(
        () => NostrNip66.createMonitorList(frequency: 0),
        throwsArgumentError,
      );
      expect(
        () => NostrNip66.createMonitorAnnouncement(
          relay: 'wss://some.relay',
          network: 'carrier-pigeon',
        ),
        throwsArgumentError,
      );
    });

    test('verifies signed monitor events', () async {
      final signer = NostrLocalKeySigner(NostrKeyPairs.generate());
      final event = await signer.sign(
        NostrNip66.createMonitorAnnouncement(relay: 'wss://some.relay'),
      );

      expect(NostrNip66.verifyAnnouncement(event), isTrue);
      expect(
        NostrNip66.verifyAnnouncement(
          NostrNip66.createMonitorAnnouncement(relay: 'wss://some.relay'),
        ),
        isFalse,
      );
      expect(
        NostrNip66.verifyAnnouncement(
          NostrNip66.createMonitorAnnouncement(relay: 'wss://some.relay'),
          requireSignature: false,
        ),
        isTrue,
      );
    });
  });

  group('NIP-86 relay management', () {
    test('posts JSON-RPC with NIP-98 authorization and payload hash', () async {
      final signer = NostrLocalKeySigner(NostrKeyPairs.generate());
      late http.Request captured;

      final mock = MockClient((request) async {
        captured = request;
        return http.Response(jsonEncode({'result': true}), 200);
      });
      final client = NostrRelayManagementClient(
        relayUrl: 'wss://relay.example',
        signer: signer,
        httpClient: mock,
      );

      expect(await client.banPubkey(_pubkey, reason: 'spam'), isTrue);

      expect(captured.method, 'POST');
      expect(captured.url.toString(), 'https://relay.example');
      expect(
        captured.headers['content-type'],
        NostrRelayManagementClient.contentType,
      );
      expect(
        jsonDecode(captured.body),
        {
          'method': 'banpubkey',
          'params': [_pubkey, 'spam'],
        },
      );

      final authorization = captured.headers['authorization']!;
      expect(authorization, startsWith('Nostr '));

      final authEvent = NostrNip98.unpackEventFromToken(authorization);
      expect(authEvent.kind, 27235);
      expect(authEvent.isVerified(), isTrue);
      expect(authEvent.tags, contains(equals(['u', 'wss://relay.example'])));
      expect(authEvent.tags, contains(equals(['method', 'POST'])));
      expect(
        authEvent.tags,
        contains(
          equals(
            [
              'payload',
              sha256.convert(utf8.encode(captured.body)).toString(),
            ],
          ),
        ),
      );
    });

    test('covers every documented admin method', () async {
      final signer = NostrLocalKeySigner(NostrKeyPairs.generate());
      final methods = <String>[];

      final mock = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final method = body['method']! as String;
        methods.add(method);

        final result = switch (method) {
          'supportedmethods' => ['banpubkey'],
          'listbannedpubkeys' ||
          'listallowedpubkeys' ||
          'listbannedevents' ||
          'listallowedevents' ||
          'listeventsneedingmoderation' ||
          'listblockedips' ||
          'listclaims' =>
            <Object?>[],
          'listallowedkinds' || 'listdisallowedkinds' => [1, 2],
          _ => true,
        };

        return http.Response(jsonEncode({'result': result}), 200);
      });
      final client = NostrRelayManagementClient(
        relayUrl: 'wss://relay.example',
        signer: signer,
        httpClient: mock,
      );

      expect(await client.supportedMethods(), ['banpubkey']);
      await client.banPubkey(_pubkey);
      await client.unbanPubkey(_pubkey);
      await client.listBannedPubkeys();
      await client.allowPubkey(_pubkey);
      await client.unallowPubkey(_pubkey);
      await client.listAllowedPubkeys();
      await client.createRole(
        const NostrRelayManagementRole(id: 'mod', label: 'Moderator'),
      );
      await client.editRole(
        const NostrRelayManagementRole(id: 'mod', label: 'Moderator'),
      );
      await client.deleteRole('mod');
      await client.assignRole(_pubkey, 'mod');
      await client.unassignRole(_pubkey, 'mod');
      await client.listClaims();
      await client.createClaim('claim');
      await client.deleteClaim('claim');
      await client.listEventsNeedingModeration();
      await client.allowEvent(_pubkey);
      await client.unallowEvent(_pubkey);
      await client.banEvent(_pubkey);
      await client.unbanEvent(_pubkey);
      await client.listBannedEvents();
      await client.listAllowedEvents();
      await client.changeRelayName('Relay');
      await client.changeRelayDescription('Description');
      await client.changeRelayIcon('https://example.com/icon.png');
      await client.allowKind(1);
      await client.disallowKind(4);
      expect(await client.listAllowedKinds(), [1, 2]);
      expect(await client.listDisallowedKinds(), [1, 2]);
      await client.blockIp('127.0.0.1');
      await client.unblockIp('127.0.0.1');
      await client.listBlockedIps();

      expect(methods, [
        'supportedmethods',
        'banpubkey',
        'unbanpubkey',
        'listbannedpubkeys',
        'allowpubkey',
        'unallowpubkey',
        'listallowedpubkeys',
        'createrole',
        'editrole',
        'deleterole',
        'assignrole',
        'unassignrole',
        'listclaims',
        'createclaim',
        'deleteclaim',
        'listeventsneedingmoderation',
        'allowevent',
        'unallowevent',
        'banevent',
        'unbanevent',
        'listbannedevents',
        'listallowedevents',
        'changerelayname',
        'changerelaydescription',
        'changerelayicon',
        'allowkind',
        'disallowkind',
        'listallowedkinds',
        'listdisallowedkinds',
        'blockip',
        'unblockip',
        'listblockedips',
      ]);
    });

    test('sends positional role params and entry results', () async {
      final signer = NostrLocalKeySigner(NostrKeyPairs.generate());
      late Map<String, dynamic> body;

      final mock = MockClient((request) async {
        body = jsonDecode(request.body) as Map<String, dynamic>;

        return http.Response(
          jsonEncode({
            'result': body['method'] == 'createrole'
                ? true
                : [
                    {'pubkey': _pubkey, 'reason': 'spam'},
                  ],
          }),
          200,
        );
      });
      final client = NostrRelayManagementClient(
        relayUrl: 'wss://relay.example',
        signer: signer,
        httpClient: mock,
      );

      await client.createRole(
        const NostrRelayManagementRole(
          id: 'mod',
          label: 'Moderator',
          description: 'Moderates',
          color: '#fff',
          order: 2,
        ),
      );

      expect(body['method'], 'createrole');
      expect(body['params'], ['mod', 'Moderator', 'Moderates', '#fff', 2]);

      final entries = await client.listBannedPubkeys();

      expect(entries.single.key, _pubkey);
      expect(entries.single.reason, 'spam');
    });

    test('surfaces relay errors and 401 responses', () async {
      final signer = NostrLocalKeySigner(NostrKeyPairs.generate());

      final errorClient = NostrRelayManagementClient(
        relayUrl: 'wss://relay.example',
        signer: signer,
        httpClient: MockClient(
          (_) async => http.Response(
            jsonEncode({'error': 'not allowed'}),
            200,
          ),
        ),
      );

      expect(
        errorClient.banPubkey(_pubkey),
        throwsA(isA<NostrRelayManagementException>()),
      );

      final unauthorized = NostrRelayManagementClient(
        relayUrl: 'wss://relay.example',
        signer: signer,
        httpClient: MockClient((_) async => http.Response('', 401)),
      );

      expect(
        unauthorized.supportedMethods(),
        throwsA(isA<NostrRelayManagementException>()),
      );
    });

    test('close releases only self-created http clients', () {
      final signer = NostrLocalKeySigner(NostrKeyPairs.generate());
      final injected = _TrackingClient();
      final injectedClient = NostrRelayManagementClient(
        relayUrl: 'wss://relay.example',
        signer: signer,
        httpClient: injected,
      );

      injectedClient.close();

      expect(injected.closed, isFalse);

      final owned = NostrRelayManagementClient(
        relayUrl: 'wss://relay.example',
        signer: signer,
      );

      owned.close();
      owned.close();
    });
  });

  group('NIP-A0 voice messages', () {
    const waveform = '0 7 35 8 100 100 49 8 4 16 8 10 7 2 20 10 100 100 '
        '100 100 100 100 15 100 100 100 25 60 5 4 3 1 0 100 100 15 100 29 88 '
        '0 33 11 39 100 100 19 4 100 42 35 5 0 1 5 0 0 11 38 100 94 17 11 44 '
        '58 5 100 100 100 55 14 72 100 100 57 6 1 14 2 16 100 100 40 16 100 '
        '100 6 32 14 13 41 36 16 14 6 3 0 1 2 1 6 0';

    test('parses the root voice message vector', () {
      final event = _event(
        kind: NostrNipA0.rootKind,
        content: _voiceUrl,
        tags: [
          [
            'imeta',
            'url $_voiceUrl',
            'waveform $waveform',
            'duration 8',
          ],
        ],
      );

      final message = NostrNipA0.parse(event);

      expect(message.isReply, isFalse);
      expect(message.audioUrl, event.content);
      expect(message.waveform, hasLength(101));
      expect(message.waveform.first, 0);
      expect(message.waveform.last, 0);
      expect(message.duration, 8);
      expect(message.hasRecommendedWaveformLength, isFalse);
      expect(message.isValid, isTrue);
    });

    test('builds root messages and reply NIP-22 tags', () {
      final root = NostrNipA0.createVoiceMessage(
        audioUrl: 'https://example.com/voice.m4a',
        waveform: const [0, 7, 35],
        duration: 8,
        extraTags: const [
          ['t', 'voice'],
        ],
      );

      expect(root.kind, 1222);
      expect(root.content, 'https://example.com/voice.m4a');
      expect(
        root.tags,
        [
          [
            'imeta',
            'url https://example.com/voice.m4a',
            'waveform 0 7 35',
            'duration 8',
          ],
          ['t', 'voice'],
        ],
      );

      final reply = NostrNipA0.createVoiceReply(
        audioUrl: 'https://example.com/reply.m4a',
        parentEventId: _pubkey,
        parentAuthorPubkey: _otherKey,
        parentKind: 1222,
        rootEventId: _pubkey,
        rootAuthorPubkey: _otherKey,
        rootKind: 1222,
        relayUrl: 'wss://relay.example',
      );

      expect(reply.kind, 1244);
      expect(
        reply.tags,
        containsAllInOrder([
          ['K', '1222'],
          ['E', _pubkey, 'wss://relay.example', _otherKey],
          ['P', _otherKey, 'wss://relay.example'],
          ['k', '1222'],
          ['e', _pubkey, 'wss://relay.example', _otherKey],
          ['p', _otherKey, 'wss://relay.example'],
        ]),
      );

      final parsed = NostrNipA0.parse(reply);

      expect(parsed.isReply, isTrue);
      expect(parsed.root?.eventId, _pubkey);
      expect(parsed.parent?.authorPubkey, _otherKey);
      expect(parsed.isValid, isTrue);
    });

    test('strict parsing rejects broken voice events', () {
      final replyWithoutRefs = _event(
        kind: NostrNipA0.replyKind,
        content: 'https://example.com/reply.m4a',
      );

      expect(NostrNipA0.tryParse(replyWithoutRefs)?.isValid, isFalse);
      expect(
        () => NostrNipA0.parse(replyWithoutRefs),
        throwsArgumentError,
      );
      expect(
        NostrNipA0.tryParse(
          _event(
            kind: NostrNipA0.rootKind,
            content: 'ftp://example.com/voice.m4a',
          ),
        ),
        isNull,
      );
      expect(NostrNipA0.tryParse(_event(kind: 1, content: 'hello')), isNull);
    });

    test('builder enforces waveform and URL limits', () {
      expect(
        () => NostrNipA0.createVoiceMessage(
          audioUrl: 'https://example.com/voice.m4a',
          waveform: List<int>.filled(101, 0),
        ),
        throwsArgumentError,
      );

      final maximum = NostrNipA0.createVoiceMessage(
        audioUrl: 'https://example.com/voice.m4a',
        waveform: List<int>.filled(100, 1),
      );
      expect(
        NostrNipA0.parse(maximum).waveform,
        List<int>.filled(100, 1),
      );

      expect(
        () => NostrNipA0.createVoiceMessage(
          audioUrl: 'https://example.com/voice.m4a',
          duration: 0,
        ),
        throwsArgumentError,
      );
      expect(
        () => NostrNipA0.createVoiceMessage(
          audioUrl: 'https://example.com/voice.m4a',
          waveform: const [-1],
        ),
        throwsArgumentError,
      );
      expect(
        () => NostrNipA0.createVoiceMessage(audioUrl: 'not-a-url'),
        throwsArgumentError,
      );
      expect(NostrNipA0.tryParseWaveform('1 x'), isNull);
      expect(NostrNipA0.tryParseWaveform('0 7 35'), [0, 7, 35]);
    });

    test('keeps unconsumed imeta fields for a lossless round-trip', () {
      final event = _event(
        kind: NostrNipA0.rootKind,
        content: _voiceUrl,
        tags: [
          [
            'imeta',
            'url $_voiceUrl',
            'm audio/mp4',
            'waveform 0 7 35',
            'duration 8',
          ],
        ],
      );

      final message = NostrNipA0.parse(event);

      expect(message.waveform, [0, 7, 35]);
      expect(message.duration, 8);
      expect(message.tags, [
        ['imeta', 'url $_voiceUrl', 'm audio/mp4'],
      ]);
    });
  });

  group('NIP-CD slash commands', () {
    const definitionTags = [
      ['d', '8f2c1a'],
      ['command', 'ban'],
      ['title', 'Ban a user'],
      [
        'description',
        'Removes a user. Reply to a message to ban its author.',
      ],
      ['arg', 'target', 'pubkey', 'required', 'Who to ban'],
      ['arg', 'reason', 'text', 'optional', 'Why'],
      ['s', 'kind:9'],
      ['s', 'kind:11'],
      ['s', 'tag:h:62af9b0'],
      ['s', 'relay:wss://relay.example'],
    ];

    test('parses and rebuilds the definition vector', () {
      final event = _event(
        kind: NostrNipCd.definitionKind,
        tags: definitionTags,
      );
      final definition = NostrSlashCommandDefinition.parse(event);

      expect(definition.identifier, '8f2c1a');
      expect(definition.command, 'ban');
      expect(definition.title, 'Ban a user');
      expect(definition.arguments, hasLength(2));
      expect(definition.arguments.first.type, NostrSlashArgumentType.pubkey);
      expect(definition.arguments.last.type, NostrSlashArgumentType.text);
      expect(definition.scopes, hasLength(4));
      expect(definition.address, '31992:$_pubkey:8f2c1a');

      final rebuilt = NostrSlashCommandDefinition.tryParse(
        _event(
          kind: NostrNipCd.definitionKind,
          tags: [
            ...definitionTags.take(4),
            ...definition.arguments.map((argument) => argument.toTag()),
            ...definition.scopes.map((scope) => scope.toTag()),
          ],
        ),
      );

      expect(rebuilt?.arguments.first.toTag(), definitionTags[4]);
      expect(rebuilt?.scopes.last.toTag(), definitionTags[9]);
    });

    test('builds definitions and matches composite scopes', () {
      final event = NostrNipCd.createDefinition(
        identifier: '8f2c1a',
        command: 'ban',
        title: 'Ban a user',
        description: 'Removes a user.',
        arguments: const [
          NostrSlashArgument(
            name: 'target',
            type: NostrSlashArgumentType.pubkey,
            required: true,
            label: 'Who to ban',
          ),
          NostrSlashArgument(
            name: 'reason',
            type: NostrSlashArgumentType.text,
            required: false,
            label: 'Why',
          ),
        ],
        scopes: [
          const NostrSlashScope(type: NostrSlashScopeType.kind, value: '9'),
          const NostrSlashScope(type: NostrSlashScopeType.kind, value: '11'),
          const NostrSlashScope(
            type: NostrSlashScopeType.tag,
            value: 'h',
            tagValue: '62af9b0',
          ),
          const NostrSlashScope(
            type: NostrSlashScopeType.relay,
            value: 'wss://relay.example',
          ),
        ],
      );
      final definition = NostrSlashCommandDefinition.parse(event);

      expect(
        definition.appliesTo(
          kind: 9,
          relayUrl: 'wss://relay.example',
          tags: const [
            ['h', '62af9b0'],
          ],
        ),
        isTrue,
      );
      expect(
        definition.appliesTo(
          kind: 10,
          relayUrl: 'wss://relay.example',
          tags: const [
            ['h', '62af9b0'],
          ],
        ),
        isFalse,
      );
      expect(
        definition.appliesTo(
          kind: 9,
          relayUrl: 'wss://relay.example',
          tags: const [
            ['h', 'other'],
          ],
        ),
        isFalse,
      );
      expect(
        definition.appliesTo(kind: 9, tags: const <List<String>>[]),
        isFalse,
      );
      expect(
        () => NostrNipCd.createDefinition(
          identifier: 'x',
          command: 'x',
          title: 'x',
          description: 'x',
          arguments: const [
            NostrSlashArgument(
              name: 'optional',
              type: NostrSlashArgumentType.word,
              required: false,
              label: 'Optional',
            ),
            NostrSlashArgument(
              name: 'required',
              type: NostrSlashArgumentType.word,
              required: true,
              label: 'Required',
            ),
          ],
        ),
        throwsArgumentError,
      );
      expect(
        () => NostrNipCd.createDefinition(
          identifier: 'x',
          command: 'x',
          title: 'x',
          description: 'x',
          arguments: const [
            NostrSlashArgument(
              name: 'color',
              type: NostrSlashArgumentType.enumeration,
              required: true,
              label: 'Color',
            ),
          ],
        ),
        throwsArgumentError,
      );
    });

    NostrSlashCommandDefinition demoDefinition(
      List<NostrSlashArgument> arguments,
    ) =>
        NostrSlashCommandDefinition.parse(
          NostrNipCd.createDefinition(
            identifier: 'demo',
            command: 'demo',
            title: 'Demo',
            description: 'Demo command',
            arguments: arguments,
          ),
        );

    test('parses every argument type', () {
      final definition = demoDefinition(const [
        NostrSlashArgument(
          name: 'pubkey',
          type: NostrSlashArgumentType.pubkey,
          required: true,
          label: 'Pubkey',
        ),
        NostrSlashArgument(
          name: 'event',
          type: NostrSlashArgumentType.event,
          required: true,
          label: 'Event',
        ),
        NostrSlashArgument(
          name: 'address',
          type: NostrSlashArgumentType.address,
          required: true,
          label: 'Address',
        ),
        NostrSlashArgument(
          name: 'relay',
          type: NostrSlashArgumentType.relay,
          required: true,
          label: 'Relay',
        ),
        NostrSlashArgument(
          name: 'number',
          type: NostrSlashArgumentType.number,
          required: true,
          label: 'Number',
        ),
        NostrSlashArgument(
          name: 'bool',
          type: NostrSlashArgumentType.boolean,
          required: true,
          label: 'Bool',
        ),
        NostrSlashArgument(
          name: 'enum',
          type: NostrSlashArgumentType.enumeration,
          required: true,
          label: 'Enum',
          choices: ['red', 'blue'],
        ),
        NostrSlashArgument(
          name: 'word',
          type: NostrSlashArgumentType.word,
          required: true,
          label: 'Word',
        ),
        NostrSlashArgument(
          name: 'text',
          type: NostrSlashArgumentType.text,
          required: true,
          label: 'Text',
        ),
      ]);

      final invocation = NostrSlashInvocation.parse(
        '/demo ${'a' * 64} ${'b' * 64} nostr:naddr1qqqq '
        'wss://relay.example 42 yes blue hello rest of it',
        definition: definition,
      );

      expect(invocation.argument('pubkey')?.value, 'a' * 64);
      expect(invocation.argument('event')?.value, 'b' * 64);
      expect(invocation.argument('address')?.value, 'naddr1qqqq');
      expect(invocation.argument('relay')?.value, 'wss://relay.example');
      expect(invocation.argument('number')?.value, 42);
      expect(invocation.argument('bool')?.value, isTrue);
      expect(invocation.argument('enum')?.value, 'blue');
      expect(invocation.argument('word')?.value, 'hello');
      expect(invocation.text, 'rest of it');
    });

    test('allows one optional non-text argument before text', () {
      final definition = demoDefinition(const [
        NostrSlashArgument(
          name: 'first',
          type: NostrSlashArgumentType.word,
          required: true,
          label: 'First',
        ),
        NostrSlashArgument(
          name: 'second',
          type: NostrSlashArgumentType.word,
          required: false,
          label: 'Second',
        ),
        NostrSlashArgument(
          name: 'reason',
          type: NostrSlashArgumentType.text,
          required: false,
          label: 'Reason',
        ),
      ]);

      expect(definition.arguments, hasLength(3));

      final invocation = NostrSlashInvocation.parse(
        '/demo one two remaining words here',
        definition: definition,
      );

      expect(invocation.argument('second')?.value, 'two');
      expect(invocation.text, 'remaining words here');

      expect(
        () => NostrNipCd.createDefinition(
          identifier: 'x',
          command: 'x',
          title: 'x',
          description: 'x',
          arguments: const [
            NostrSlashArgument(
              name: 'a',
              type: NostrSlashArgumentType.word,
              required: false,
              label: 'A',
            ),
            NostrSlashArgument(
              name: 'b',
              type: NostrSlashArgumentType.word,
              required: false,
              label: 'B',
            ),
            NostrSlashArgument(
              name: 'text',
              type: NostrSlashArgumentType.text,
              required: false,
              label: 'Text',
            ),
          ],
        ),
        throwsArgumentError,
      );
    });

    test('rejects required text after an optional argument', () {
      const arguments = [
        NostrSlashArgument(
          name: 'first',
          type: NostrSlashArgumentType.word,
          required: false,
          label: 'First',
        ),
        NostrSlashArgument(
          name: 'reason',
          type: NostrSlashArgumentType.text,
          required: true,
          label: 'Reason',
        ),
      ];

      expect(
        () => NostrNipCd.createDefinition(
          identifier: 'x',
          command: 'x',
          title: 'x',
          description: 'x',
          arguments: arguments,
        ),
        throwsArgumentError,
      );

      expect(
        NostrSlashCommandDefinition.tryParse(
          _event(
            kind: NostrNipCd.definitionKind,
            tags: [
              ['d', 'x'],
              ['command', 'x'],
              ['title', 'x'],
              ['description', 'x'],
              ...arguments.map((argument) => argument.toTag()),
            ],
          ),
        ),
        isNull,
      );
    });

    test('rejects a command name that cannot be invoked', () {
      for (final command in ['ban@', 'ba n', '/ban']) {
        expect(
          () => NostrNipCd.createDefinition(
            identifier: 'x',
            command: command,
            title: 'x',
            description: 'x',
          ),
          throwsArgumentError,
          reason: command,
        );
      }

      expect(
        NostrSlashCommandDefinition.tryParse(
          _event(
            kind: NostrNipCd.definitionKind,
            tags: [
              ['d', 'x'],
              ['command', 'ban@nostr'],
              ['title', 'x'],
              ['description', 'x'],
            ],
          ),
        ),
        isNull,
      );
    });

    test('bool table accepts every documented spelling', () {
      final definition = demoDefinition(const [
        NostrSlashArgument(
          name: 'flag',
          type: NostrSlashArgumentType.boolean,
          required: true,
          label: 'Flag',
        ),
      ]);

      for (final token in ['true', 'yes', '1', 't', 'y']) {
        expect(
          NostrSlashInvocation.parse(
            '/demo $token',
            definition: definition,
          ).argument('flag')?.value,
          isTrue,
        );
      }

      for (final token in ['false', 'no', '0', 'f', 'n']) {
        expect(
          NostrSlashInvocation.parse(
            '/demo $token',
            definition: definition,
          ).argument('flag')?.value,
          isFalse,
        );
      }
    });

    test('parses qualifiers and rejects malformed invocations', () {
      final bech32 = Nostr.instance.nips.nip19;
      final npub = bech32.encodePublicKeyToNpub(_pubkey);
      final definition = demoDefinition(const [
        NostrSlashArgument(
          name: 'target',
          type: NostrSlashArgumentType.pubkey,
          required: true,
          label: 'Target',
        ),
        NostrSlashArgument(
          name: 'reason',
          type: NostrSlashArgumentType.text,
          required: false,
          label: 'Reason',
        ),
      ]);

      final invocation = NostrSlashInvocation.parse(
        '/demo@nostr:$npub nostr:$npub repeatedly spamming links',
        definition: definition,
        bech32: bech32,
      );

      expect(invocation.targetNpub, npub);
      expect(invocation.targetPubkey, _pubkey);
      expect(invocation.argument('target')?.value, _pubkey);
      expect(invocation.text, 'repeatedly spamming links');

      final bare = NostrSlashInvocation.parse(
        '/demo@$npub nostr:$npub bare qualifier',
        definition: definition,
        bech32: bech32,
      );

      expect(bare.targetNpub, npub);
      expect(bare.targetPubkey, _pubkey);
      expect(bare.text, 'bare qualifier');

      final punctuation = NostrSlashInvocation.parse(
        '/demo@nostr:$npub,',
        definition: demoDefinition(const [
          NostrSlashArgument(
            name: 'rest',
            type: NostrSlashArgumentType.word,
            required: true,
            label: 'Rest',
          ),
        ]),
        bech32: bech32,
      );

      expect(punctuation.targetNpub, npub);
      expect(punctuation.argument('rest')?.value, ',');

      final note = bech32.encodeBech32('b' * 64, 'note');
      final eventInvocation = NostrSlashInvocation.parse(
        '/demo nostr:$note',
        definition: demoDefinition(const [
          NostrSlashArgument(
            name: 'event',
            type: NostrSlashArgumentType.event,
            required: true,
            label: 'Event',
          ),
        ]),
        bech32: bech32,
      );

      expect(eventInvocation.argument('event')?.value, 'b' * 64);

      expect(
        NostrSlashInvocation.tryParse(
          'hello /demo',
          definition: definition,
        ),
        isNull,
      );
      expect(
        NostrSlashInvocation.tryParse('/other', definition: definition),
        isNull,
      );
      expect(
        NostrSlashInvocation.tryParse('/demo', definition: definition),
        isNull,
      );
      expect(
        NostrSlashInvocation.tryParse(
          '/demo not-a-pubkey',
          definition: definition,
        ),
        isNull,
      );
      expect(
        NostrSlashInvocation.tryParse(
          '/demo $npub extra',
          definition: demoDefinition(const [
            NostrSlashArgument(
              name: 'target',
              type: NostrSlashArgumentType.pubkey,
              required: true,
              label: 'Target',
            ),
          ]),
        ),
        isNull,
      );
      expect(
        NostrSlashInvocation.tryParse(
          '/demo@nostr:npub1invalid $npub',
          definition: definition,
          bech32: bech32,
        ),
        isNull,
      );
    });

    test('text arguments keep the remainder verbatim', () {
      final definition = demoDefinition(const [
        NostrSlashArgument(
          name: 'text',
          type: NostrSlashArgumentType.text,
          required: true,
          label: 'Text',
        ),
      ]);
      final invocation = NostrSlashInvocation.parse(
        '/demo hello\nworld  with  spaces',
        definition: definition,
      );

      expect(invocation.text, 'hello\nworld  with  spaces');
    });

    test('builds and parses installed command lists', () {
      final event = NostrNipCd.createCommandList(
        commands: const [
          NostrSlashCommandAddress(
            pubkey: _pubkey,
            identifier: '8f2c1a',
            relayUrl: 'wss://relay.example',
          ),
        ],
      );
      final list = NostrNipCd.parseCommandList(event);

      expect(list.commands.single.address, '31992:$_pubkey:8f2c1a');
      expect(list.commands.single.relayUrl, 'wss://relay.example');
      expect(
        event.tags,
        [
          ['a', '31992:$_pubkey:8f2c1a', 'wss://relay.example'],
        ],
      );
    });
  });

  group('NIP-F4 podcasts', () {
    test('parses podcast metadata and credits roles', () {
      final event = _event(
        kind: NostrNipF4.metadataKind,
        tags: [
          ['title', 'My Podcast'],
          ['image', 'https://example.com/cover.jpg'],
          ['description', 'A show'],
          ['website', 'https://example.com'],
          ['p', _otherKey, 'host'],
          ['p', _pubkey, 'editor'],
        ],
      );
      final metadata = NostrNipF4.parseMetadata(event);

      expect(metadata.title, 'My Podcast');
      expect(metadata.image, 'https://example.com/cover.jpg');
      expect(metadata.websites, ['https://example.com']);
      expect(metadata.people, hasLength(2));
      expect(metadata.people.first.role, 'host');
      expect(metadata.people.first.hasKnownRole, isTrue);
      expect(metadata.hosts, [_otherKey]);
      expect(metadata.isValid, isTrue);
    });

    test('keeps unknown p roles without failing validity', () {
      final event = _event(
        kind: NostrNipF4.metadataKind,
        tags: [
          ['title', 'My Podcast'],
          ['p', _otherKey, 'guest'],
        ],
      );

      final metadata = NostrNipF4.parseMetadata(event);

      expect(metadata.people.single.role, 'guest');
      expect(metadata.people.single.hasKnownRole, isFalse);
      expect(metadata.isValid, isTrue);
    });

    test('builds metadata and episodes', () {
      final metadata = NostrNipF4.createPodcastMetadata(
        title: 'My Podcast',
        image: 'https://example.com/cover.jpg',
        description: 'A show',
        websites: const ['https://example.com'],
        people: const [
          NostrPodcastPerson(pubkey: _otherKey, role: 'host'),
        ],
      );

      expect(
        metadata.tags,
        containsAllInOrder([
          ['title', 'My Podcast'],
          ['image', 'https://example.com/cover.jpg'],
          ['p', _otherKey, 'host'],
        ]),
      );

      final episode = NostrNipF4.createEpisode(
        title: 'Episode 1',
        image: 'https://example.com/episode.jpg',
        description: 'First episode',
        audios: const [
          NostrPodcastAudio(
            url: 'https://example.com/ep1.mp3',
            mediaType: 'audio/mpeg',
          ),
          NostrPodcastAudio(url: 'https://example.com/ep1.m4a'),
        ],
        content: 'Show notes',
      );
      final parsed = NostrNipF4.parseEpisode(episode);

      expect(parsed.title, 'Episode 1');
      expect(parsed.audios, hasLength(2));
      expect(parsed.audios.first.mediaType, 'audio/mpeg');
      expect(parsed.content, 'Show notes');
      expect(parsed.isValid, isTrue);
    });

    test('accepts legacy 10164 authored lists but emits 10064', () {
      final legacy = NostrNipF4.parseAuthoredList(
        _event(
          kind: NostrNipF4.legacyAuthoredListKind,
          tags: [
            ['p', _otherKey],
          ],
        ),
      );

      expect(legacy.isLegacy, isTrue);
      expect(legacy.podcastPubkeys, [_otherKey]);

      final current = NostrNipF4.createAuthoredPodcastList(
        podcastPubkeys: const [_otherKey],
      );

      expect(current.kind, NostrNipF4.authoredListKind);
      expect(
        NostrNipF4.parseAuthoredList(current).isLegacy,
        isFalse,
      );
    });

    test('verifyAuthorship requires the two-way claim', () async {
      final podcast = NostrLocalKeySigner(NostrKeyPairs.generate());
      final host = NostrLocalKeySigner(NostrKeyPairs.generate());

      final metadata = await podcast.sign(
        NostrNipF4.createPodcastMetadata(
          title: 'Show',
          people: [
            NostrPodcastPerson(pubkey: host.publicKey, role: 'host'),
          ],
        ),
      );
      final authored = await host.sign(
        NostrNipF4.createAuthoredPodcastList(
          podcastPubkeys: [podcast.publicKey],
        ),
      );

      expect(NostrNipF4.verifyAuthorship(metadata, authored), isTrue);
      expect(
        NostrNipF4.verifyAuthorship(
          metadata,
          authored,
          requireValidSignatures: true,
        ),
        isTrue,
      );
      expect(
        NostrNipF4.verifyAuthorship(
          metadata,
          _event(
            kind: NostrNipF4.authoredListKind,
            pubkey: host.publicKey,
            tags: const <List<String>>[],
          ),
        ),
        isFalse,
      );
      expect(
        NostrNipF4.verifyAuthorship(
          metadata,
          _event(kind: 1, pubkey: host.publicKey),
        ),
        isFalse,
      );
    });

    test('rejects invalid metadata and episodes', () {
      expect(
        NostrNipF4.tryParseMetadata(
          _event(
            kind: NostrNipF4.metadataKind,
            tags: [
              ['p', _otherKey, 'actor'],
            ],
          ),
        ),
        isNull,
      );
      expect(
        NostrNipF4.tryParseEpisode(
          _event(
            kind: NostrNipF4.episodeKind,
            tags: [
              ['title', 'Episode'],
              ['audio', 'not-a-url'],
            ],
          ),
        ),
        isNull,
      );
      expect(
        () => NostrNipF4.createEpisode(
          title: 'Episode',
          audios: const [],
        ),
        throwsArgumentError,
      );
      expect(
        () => NostrNipF4.createPodcastMetadata(title: ' '),
        throwsArgumentError,
      );
    });
  });
}

extension on NostrEvent {
  NostrEvent copyWithAuthor(String author) => NostrEvent(
        id: id,
        kind: kind,
        content: content,
        sig: sig,
        pubkey: author,
        createdAt: createdAt,
        tags: tags,
      );
}
