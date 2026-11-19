import 'package:dart_nostr/dart_nostr.dart';
import 'package:test/test.dart';

void main() {
  test('barrel exposes every NIP implementation and Blossom', () {
    expect(NostrNip05, isNotNull);
    expect(NostrNip06, isNotNull);
    expect(NostrNip11, isNotNull);
    expect(NostrNip19, isNotNull);
    expect(NostrNip21, isNotNull);
    expect(NostrNip27, isNotNull);
    expect(NostrNip42, isNotNull);
    expect(NostrNip45, isNotNull);
    expect(NostrNip46, isNotNull);
    expect(NostrNip47, isNotNull);
    expect(NostrProofOfWork, isNotNull);
    expect(NostrZaps, isNotNull);
    expect(NostrSocialBuilder, isNotNull);
    expect(NostrBlossomClient, isNotNull);
    expect(NostrNip94FileMetadata, isNotNull);
    expect(NostrNip96Uploader, isNotNull);
  });
}
