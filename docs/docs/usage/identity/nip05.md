---
sidebar_position: 1
description: Resolve and verify NIP-05 internet identifiers (name@domain).
---

# NIP-05 identity

NIP-05 maps a human-readable identifier such as `jb55@jb55.com` to a public key through `https://<domain>/.well-known/nostr.json?name=<local-part>`. `nostr.utils` exposes the two calls you need.

| Method | Returns | Behaviour |
|---|---|---|
| `isValidNip05Identifier(String)` | `bool` | Format check only, no network |
| `pubKeyFromIdentifierNip05({internetIdentifier})` | `Future<String?>` | `null` when the JSON has no entry for the name |
| `verifyNip05({internetIdentifier, pubKey})` | `Future<bool>` | Resolves the identifier and compares against `pubKey` |

Both network calls throw on transport, HTTP, or JSON failure. The thrown type is `Nip05VerificationException`, which wraps the underlying exception in `parent`. That class is declared in `package:dart_nostr/nostr/core/exceptions.dart` and is not re-exported from the package root, so a snippet that only imports the root catches `Exception`.

## Resolve an identifier to a public key

```dart
import 'package:dart_nostr/dart_nostr.dart';

Future<void> main() async {
  final nostr = Nostr();

  if (!nostr.utils.isValidNip05Identifier('jb55@jb55.com')) {
    print('malformed identifier');
    return;
  }

  try {
    final publicKey = await nostr.utils.pubKeyFromIdentifierNip05(
      internetIdentifier: 'jb55@jb55.com',
    );

    if (publicKey == null) {
      print('identifier is not in the domain document');
    } else {
      print(publicKey);
    }
  } on Exception catch (error) {
    print('lookup failed: $error');
  }
}
```

## Verify that a public key matches an identifier

`verifyNip05` performs the same lookup and returns whether the published key equals the key you passed. A `false` result means the domain answered but advertised a different key; a thrown exception means the lookup itself failed, and the exception is rethrown rather than converted to `false`.

```dart
import 'package:dart_nostr/dart_nostr.dart';

Future<void> main() async {
  final nostr = Nostr();
  final keys = nostr.keys.generateKeyPair();

  try {
    final matches = await nostr.utils.verifyNip05(
      internetIdentifier: 'jb55@jb55.com',
      pubKey: keys.public,
    );

    print(matches); // false unless that domain publishes this key
  } on Exception catch (error) {
    print('verification could not be completed: $error');
  }
}
```

Pass the key as 64-character hex. An `npub` is not accepted: the implementation asserts the hex shape in debug builds and compares strings, so an `npub` input can never match the hex value in the domain document. Decode it first with [NIP-19](./nip19).

## Limitations

- Verification covers one identifier and one key. Domain documents may list many names; only the requested `name` is read.
- No relay request is made. NIP-05 says nothing about relays, and this implementation does not check the `relays` section of the document.
- The lookup is a plain HTTPS GET with no timeout argument. Wrap the call in your own timeout if the caller cannot wait on a slow domain.
- The domain controls the answer. A match proves the domain vouches for that key at the time of the request, not that the key belongs to a particular person.

## Related

- [Keys](/usage/keys-management/) for generating and deriving keys
- [NIP-19 encoding](./nip19) for `npub` and `nprofile`
- [Client options](../advanced/client-options) for timeouts elsewhere in the client
