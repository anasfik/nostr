---
sidebar_position: 4
---

# Sign and verify a pice of data

Genrating a keypair is not about just generating the private and public keys, it's also about using them to sign and verify data, this is what we will talk about in this section.

To sign a message as example or any price of data, you will need to use the `sign()` method on the `NostrKeyPair` object, which will return a `String` that represents the signature of the message. Then, if you want to verify that or any other signature, you can use the `verify()` method, which will return a `bool` that indicates if the signatire belongs to the user keys or not, Example:


```dart
// The message to sign.
String message = "somthing, IDK";

// The signatire of the message.
String signature = Nostr.instance.keysService.sign(
  privateKey: "THE_PRIVATE_KEY_HEX_STRING",
  message: message,
);

// Use the signature as you want.
print(signature); // ...

//...


// Later, when we get a signature from any source, we can verify it.
bool isSignatureVerified = Nostr.instance.keysService.verify(
  publicKey: "THE_PUBLIC_KEY_HEX_STRING",
  message: message,
  signature: signature,
);

// Use the verification result as you want.
print(isSignatureVerified ); // ...
```