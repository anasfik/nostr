---
sidebar_position: 1
description: Resolve and verify NIP-05 internet identifiers (user@domain.com).
---

# NIP-05 Identity

NIP-05 maps human-readable identifiers (`user@domain.com`) to Nostr public keys via a `/.well-known/nostr.json` endpoint.

## Resolve an identifier to a public key

```dart
final publicKey = await nostr.utils.pubKeyFromIdentifierNip05(
  internetIdentifier: 'jb55@jb55.com',
);

if (publicKey != null) {
  print(publicKey);
} else {
  print('identifier not found or unreachable');
}
```

## Verify that a public key matches an identifier

```dart
final isVerified = await nostr.utils.verifyNip05(
  internetIdentifier: 'jb55@jb55.com',
  pubKey: '32e1827635450ebb3c5a7d12c1f8e7b2b514439ac10a67eef3d9fd9c5c68e245',
);

print(isVerified);  // true or false
```

## Notes

- These methods make HTTP requests to the identifier's domain. They will fail if the domain is unreachable or the identifier is not registered.
- `verifyNip05` resolves the identifier and compares the returned pubkey to the one you provide. It does not make any Nostr relay requests.
