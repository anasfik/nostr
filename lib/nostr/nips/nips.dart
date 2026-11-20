/// Single entry point for every NIP implementation in this package.
///
/// NIPs with dedicated code live in one folder each. NIPs implemented by the
/// shared model, transport or social builder layer have an index module here:
///
/// - NIP-01  `nip01/` → model/event + model/request + relay messages
/// - NIP-02  kind 3 follow lists (`social/`)
/// - NIP-03  `NostrEvent.ots` OpenTimestamps attestation field
/// - NIP-09  kind 5 deletions (`social/`)
/// - NIP-10  reply threading tags (`social/`)
/// - NIP-18  kind 6 reposts (`social/`)
/// - NIP-22  kind 1111 comments (`social/`)
/// - NIP-23  kind 30023 long-form articles (`social/`)
/// - NIP-24  `nip24/` extra metadata fields and tags
/// - NIP-25  kind 7 reactions (`social/`)
/// - NIP-28  kind 40–44 channels (`nip28/`)
/// - NIP-30  custom emoji (`nip30/`)
/// - NIP-32  kind 1985 labels (`nip32/`)
/// - NIP-34  `nip34/` git repos, patches, pull requests, issues and statuses
/// - NIP-35  `nip35/` kind 2003 torrent indexes and kind 2004 comments
/// - NIP-36  `nip36/` content warnings
/// - NIP-37  `nip37/` draft wraps, checkpoints and private relay lists
/// - NIP-38  kind 30315 user statuses (`nip38/`)
/// - NIP-42  `nip42/` auth events; `NostrRelays` answers challenges
/// - NIP-43  `nip43/` relay access metadata and join/leave requests
/// - NIP-45  `model/count.dart` shim → `nip45/` COUNT payloads
/// - NIP-48  `nip48/` bridged-event `proxy` tags
/// - NIP-50  `NostrFilter.search` (+ filter builder)
/// - NIP-51  kind 10000–10003/30000–30003 lists (`social/`)
/// - NIP-52  `nip52/` kinds 31922–31925 calendar events, calendars and RSVPs
/// - NIP-53  `nip53/` live streams, chat, rooms, meetings and presence
/// - NIP-56  kind 1984 reports (`nip56/`)
/// - NIP-65  kind 10002 relay lists (`social/`)
/// - NIP-66  `nip66/` relay liveness monitoring (kinds 30166/10166)
/// - NIP-5A  `nip5a/` static website manifests and snapshots
/// - NIP-60  `nip60/` cashu wallet, token, history and quote events
/// - NIP-61  `nip61/` mint recommendations and nutzaps
/// - NIP-62  `nip62/` requests to vanish
/// - NIP-64  `nip64/` kind 64 chess games as PGN
/// - NIP-68  `nip68/` kind 20 picture-first feeds
/// - NIP-69  `nip69/` kind 38383 peer-to-peer orders
/// - NIP-70  protected events (`nip70/`)
/// - NIP-71  `nip71/` kinds 21/22/34235/34236 video events
/// - NIP-73  `nip73/` external content `i`/`k` ids
/// - NIP-7D  `nip7d/` kind 11 forum threads
/// - NIP-78  kinds 78/30078 custom app data (`nip78/`)
/// - NIP-84  kind 9802 highlights (`nip54/`)
/// - NIP-85  `nip85/` trusted assertions and provider recommendations
/// - NIP-86  `nip86/` HTTP relay management JSON-RPC client
/// - NIP-87  `nip87/` cashu and fedimint discoverability
/// - NIP-88  kinds 1068/1018 polls (`nip88/`)
/// - NIP-89  `nip89/` kinds 31989/31990 recommended app handlers
/// - NIP-92  `imeta` media attachments (`nip92/`)
/// - NIP-A0  `nipa0/` voice messages and voice replies (kinds 1222/1244)
/// - NIP-A3  `nipa3/` kind 10133 `payto` payment targets
/// - NIP-A4  `nipa4/` kind 24 public messages
/// - NIP-B0  `nipb0/` kind 39701 web bookmarks
/// - NIP-C0  `nipc0/` kind 1337 code snippets
/// - NIP-C7  `nipc7/` kind 9 chat messages
/// - NIP-CC  `nipcc/` geocache listings, logs, verification and curation
/// - NIP-CD  `nipcd/` slash command definitions, lists and invocations
/// - NIP-F4  `nipf4/` podcast metadata, authored lists and episodes
///
/// Shared tag/address/validator helpers live in `common/tags.dart`.
library;

export 'blossom/blossom.dart';
export 'common/tags.dart';
export 'nip01/nip01.dart';
export 'nip04/nip04.dart';
export 'nip05/nip05.dart';
export 'nip06/nip06.dart';
export 'nip07/nip07.dart';
export 'nip11/nip11.dart';
export 'nip13/nip13.dart';
export 'nip17/nip17.dart';
export 'nip19/nip19.dart';
export 'nip21/nip21.dart';
export 'nip24/nip24.dart';
export 'nip27/nip27.dart';
export 'nip28/nip28.dart';
export 'nip29/nip29.dart';
export 'nip30/nip30.dart';
export 'nip32/nip32.dart';
export 'nip34/nip34.dart';
export 'nip35/nip35.dart';
export 'nip36/nip36.dart';
export 'nip37/nip37.dart';
export 'nip38/nip38.dart';
export 'nip39/nip39.dart';
export 'nip42/nip42.dart';
export 'nip43/nip43.dart';
export 'nip44/nip44.dart';
export 'nip45/nip45.dart';
export 'nip46/nip46.dart';
export 'nip47/nip47.dart';
export 'nip48/nip48.dart';
export 'nip49/nip49.dart';
export 'nip52/nip52.dart';
export 'nip53/nip53.dart';
export 'nip54/nip54.dart';
export 'nip55/nip55.dart';
export 'nip56/nip56.dart';
export 'nip57/nip57.dart';
export 'nip58/nip58.dart';
export 'nip59/nip59.dart';
export 'nip5a/nip5a.dart';
export 'nip60/nip60.dart';
export 'nip61/nip61.dart';
export 'nip62/nip62.dart';
export 'nip64/nip64.dart';
export 'nip66/nip66.dart';
export 'nip68/nip68.dart';
export 'nip69/nip69.dart';
export 'nip70/nip70.dart';
export 'nip71/nip71.dart';
export 'nip73/nip73.dart';
export 'nip75/nip75.dart';
export 'nip77/nip77.dart';
export 'nip78/nip78.dart';
export 'nip7d/nip7d.dart';
export 'nip85/nip85.dart';
export 'nip86/nip86.dart';
export 'nip87/nip87.dart';
export 'nip88/nip88.dart';
export 'nip89/nip89.dart';
export 'nip92/nip92.dart';
export 'nip94/nip94.dart';
export 'nip96/nip96.dart';
export 'nip98/nip98.dart';
export 'nip99/nip99.dart';
export 'nipa0/nipa0.dart';
export 'nipa3/nipa3.dart';
export 'nipa4/nipa4.dart';
export 'nipad/nipad.dart';
export 'nipb0/nipb0.dart';
export 'nipb7/nipb7.dart';
export 'nipc0/nipc0.dart';
export 'nipc7/nipc7.dart';
export 'nipcc/nipcc.dart';
export 'nipcd/nipcd.dart';
export 'nipf4/nipf4.dart';
export 'nostr_nips.dart';
export 'social/social_builder.dart';
