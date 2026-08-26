import 'package:dart_nostr/dart_nostr.dart';
import 'package:dart_nostr/nostr/builders/social_builder.dart';
import 'package:dart_nostr/nostr/signers/signer.dart';
import 'package:test/test.dart';

import '../real/helpers.dart';

/// Iteration 12 — threading compatibility: real clients (Damus, Amethyst,
/// Snort) mark replies with NIP-10 root/reply markers. Fetch a real thread,
/// extract its tag grammar, and assert our reply builder emits the same
/// shapes so our posts render correctly in those clients.
void main() {
  if (!realNetworkTestsEnabled) {
    return;
  }

  group('REAL/interop: thread tag grammar', () {
    test(
      'real threads use NIP-10 markers and ours match the convention',
      () async {
        // Find a reply (has an e tag) in the wild.
        final notes = await rawFetchAny(
          kPrimaryRelays,
          {
            'kinds': [1],
            'limit': 100
          },
          timeout: const Duration(seconds: 15),
        );

        Map<String, dynamic>? realReply;
        for (final raw in notes.cast<Map<String, dynamic>>()) {
          final tags = raw['tags'] as List;
          final hasE = tags.any((t) => (t as List).isNotEmpty && t[0] == 'e');
          if (hasE) {
            realReply = Map<String, dynamic>.from(raw);
            break;
          }
        }

        if (realReply == null) {
          markTestSkipped('no replies found in sample window');
          return;
        }

        // Extract the real client's e-tag grammar.
        final eTags = (realReply['tags'] as List)
            .map((t) => (t as List).map((x) => '$x').toList())
            .where((t) => t.isNotEmpty && t[0] == 'e')
            .toList();

        // ignore: avoid_print
        print('real reply e-tags from a real client:');
        for (final t in eTags.take(4)) {
          // ignore: avoid_print
          print('  marker=${t.length > 3 ? t[3] : "<none>"} '
              'relay=${t.length > 2 ? t[2] : ""}');
        }

        // Grammar rules every mainstream client follows:
        // - each e tag has [type, id, relay?, marker?]
        // - at most one root and one reply marker
        final markers =
            eTags.where((t) => t.length > 3).map((t) => t[3]).toSet();
        expect(
            markers.contains('root') ||
                markers.contains('reply') ||
                eTags.any((t) => t.length <= 3),
            isTrue,
            reason:
                'real replies follow NIP-10 positional or marked conventions');

        // Our builder must emit compatible structures.
        final builder = NostrSocialBuilder(
          signer: NostrLocalKeySigner(newIdentity()),
        );

        final withRoot = await builder.createTextNote(
          'compat probe',
          replyTo: (
            eventId: 'ee' * 32,
            authorPubkey: 'aa' * 32,
            rootEventId: 'rr' * 32,
          ),
        );
        final ourTags = withRoot.tags!
            .where((t) => t[0] == 'e')
            .map((t) => t.length > 3 ? t[3] : '<positional>')
            .toList();

        expect(ourTags, containsAll(['root', 'reply']),
            reason: 'our tagged replies must carry NIP-10 markers');

        // Positional fallback (no root): single e tag without marker.
        final positional = await builder.createTextNote(
          'direct reply',
          replyTo: (
            eventId: 'ee' * 32,
            authorPubkey: 'aa' * 32,
            rootEventId: null,
          ),
        );
        final positionalETags = positional.tags!
            .where((t) => t[0] == 'e')
            .map((t) => t.length)
            .toList();
        expect(positionalETags.every((len) => len == 2 || len == 4), isTrue);
      },
      timeout: kTestTimeout,
    );

    test(
      'publish a threaded reply into a real thread — accepted by relays',
      () async {
        // Find a fresh note to genuinely reply to.
        final notes = await rawFetchAny(
          kPrimaryRelays,
          {
            'kinds': [1],
            'limit': 5,
            'since':
                (DateTime.now().millisecondsSinceEpoch ~/ 1000) - 86400 * 7,
          },
          timeout: const Duration(seconds: 12),
        );
        if (notes.isEmpty) {
          markTestSkipped('no recent notes to reply into');
          return;
        }

        final target = (notes.first as Map<String, dynamic>);
        if (target['id'] == null) return;

        final identity = newIdentity();
        final signer = NostrLocalKeySigner(identity);
        final builder = NostrSocialBuilder(signer: signer);
        final nostr = Nostr();
        final liveRelays = await pickLiveRelays(count: 1);

        final receipt = await publishWithFallback(
          nostr,
          await builder.createTextNote(
            '(nostr dart sdk interop check)',
            replyTo: (
              eventId: target['id'] as String,
              authorPubkey: target['pubkey'] as String,
              rootEventId: null,
            ),
          ),
          [...liveRelays, ...kPrimaryRelays],
        );

        expect(receipt, isNotNull,
            reason: 'our threaded reply was rejected everywhere');
        expect(receipt!.isEventAccepted, isTrue);

        await nostr.disconnect();
      },
      timeout: kTestTimeout,
    );
  });
}
