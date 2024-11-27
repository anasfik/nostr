---
sidebar_position: 4
description: Learn how to sign & verify data.
---

# Sign and verify a pice of data

Generating a key pair is not about just generating the private and public keys, it's also about using them to sign and verify data, this is what we will talk about in this section.

To sign a message as example or any price of data, you will need to use the `sign()` method on the `NostrKeyPair` object, which will return a `String` that represents the signature of the message. Then, if you want to verify that or any other signature, you can use the `verify()` method, which will return a `bool` that indicates if the signature belongs to the user keys or not, Example:

## Sign Messages

You can sign any message you want, using the `sign` method of the `Nostr.instance.services.keys`, like this:

```dart

// The message to sign.
String message = "something, IDK";

// The signature of the message.
String signature = Nostr.instance.services.keys.sign(
  privateKey: "THE_PRIVATE_KEY_HEX_STRING",
  message: message,
);

// Use the signature as you want.
print(signature); // ...

//...
```

This will provide you withe a signature of that data that you can use to verify its ownership later.

## Verify Signatures

You can verify any signature you want, using the `verify` method of the `Nostr.instance.services.keys`, like this:

```dart

// Later, when we get a signature from any source, we can verify it.
bool isSignatureVerified = Nostr.instance.services.keys.verify(
  publicKey: "THE_PUBLIC_KEY_HEX_STRING",
  message: message,
  signature: signature,
);

// Use the verification result as you want.
print(isSignatureVerified ); // ...
```

This will provide you with a `bool` that indicates if the signature belongs to the user keys or not.
