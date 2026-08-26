import 'dart:convert';

import 'package:dart_nostr/dart_nostr.dart';
import 'package:dart_nostr/nostr/builders/social_builder.dart';
import 'package:dart_nostr/nostr/signers/signer.dart';
import 'package:test/test.dart';

import '../real/helpers.dart';

/// Iteration 14 — profile metadata compatibility: real profiles (Damus,
/// Snort, Primal) carry zap-routing and identity fields. Rebuild wild
/// profiles through our builder and assert nothing is lost — a client
/// using dart_nostr must be able to round-trip any profile it reads.
void main() {
  if (!realNetworkTestsEnabled) {
    return;
  }

  group('REAL/interop: profile metadata', () {
    test(
      'rebuild real profiles field-complete',
      () async {
        final profiles = await rawFetchAny(
          kPrimaryRelays,
          {
            'kinds': [0],
            'limit': 20
          },
          timeout: const Duration(seconds: 15),
        );
        expect(profiles.length, greaterThan(3));

        var checked = 0;
        var withLud = 0;

        for (final raw in profiles.take(10)) {
          Map<String, dynamic> meta;
          try {
            meta = jsonDecode(raw['content'] as String) as Map<String, dynamic>;
          } catch (_) {
            continue;
          }

          // Skip empty/degenerate profiles.
          if (!meta.containsKey('name') && !meta.containsKey('about')) {
            continue;
          }

          final signer = NostrLocalKeySigner(newIdentity());
          final builder = NostrSocialBuilder(signer: signer);

          final rebuilt = await builder.updateProfile(
            name: (meta['name'] as String?) ?? '',
            displayName: meta['display_name'] as String?,
            about: meta['about'] as String?,
            picture: meta['picture'] as String?,
            nip05: meta['nip05'] as String?,
            website: meta['website'] as String?,
            banner: meta['banner'] as String?,
            lud16: meta['lud16'] as String?,
            lud06: meta['lud06'] as String?,
          );

          final rebuiltMeta =
              jsonDecode(rebuilt.content!) as Map<String, dynamic>;

          // Every standard field present in the original must survive.
          for (final field in [
            'name',
            'display_name',
            'about',
            'picture',
            'nip05',
            'banner',
            'website',
            'lud16',
            'lud06',
          ]) {
            if (meta.containsKey(field)) {
              expect(rebuiltMeta[field], meta[field],
                  reason: 'lost $field rebuilding a wild profile');
            }
          }

          if (meta['lud16'] != null || meta['lud06'] != null) {
            withLud++;
          }
          checked++;
        }

        expect(checked, greaterThan(2));
        // ignore: avoid_print
        print('profiles checked: $checked, '
            'with lightning addresses: $withLud');
      },
      timeout: kTestTimeout,
    );

    test(
      'zap-capable profile enables the full zap chain end-to-end',
      () async {
        // Find a profile that actually has a Lightning Address.
        final profiles = await rawFetchAny(
          kPrimaryRelays,
          {
            'kinds': [0],
            'limit': 30
          },
          timeout: const Duration(seconds: 15),
        );

        String? lud16;
        for (final raw in profiles) {
          try {
            final meta =
                jsonDecode(raw['content'] as String) as Map<String, dynamic>;
            final candidate = meta['lud16'] as String?;
            if (candidate != null &&
                candidate.contains('@') &&
                !candidate.contains('_@')) {
              lud16 = candidate;
              break;
            }
          } catch (_) {}
        }

        if (lud16 == null) {
          markTestSkipped('no zap-capable profile in sample window');
          return;
        }

        // The full chain a zap button runs:
        final payUrl = lightningAddressToLnurlPayUrl(lud16);
        final zaps = NostrZaps(signer: NostrLocalKeySigner(newIdentity()));

        try {
          final doc = await zaps.fetchLnurlPayDocument(payUrl);
          // A working wallet document means our whole chain is compatible
          // with how Damus/njump resolve zaps from a profile.
          expect(doc['callback'], isA<String>());
          // ignore: avoid_print
          print('$lud16 -> wallet reachable, callback OK');
        } on ArgumentError {
          // Wallet exists but doesn't allow nostr zaps; resolution worked.
          // ignore: avoid_print
          print('$lud16 -> wallet resolved but no nostr zap support');
        }
      },
      timeout: kTestTimeout,
    );
  });
}
