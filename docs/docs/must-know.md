---
sidebar_position: 3
---

# Must Know?

With `dart_nostr`, you can achieve almost anything that relate to the Nostr protocol, there is some exception that are out of my hand currently such as adapting web-based Chrome extensions to work with Flutter, but I am working on it.but all the operations of sending events & listening to them.. will be so easy for easy.

## Code structure

`dart_nostr` exposes all it's functionality via its main and only singleton instance that you need to use to access all other services of this package:

```dart
Nostr singleton = Nostr.instance;
```

The `Nostr.instance` offers access to all other internal services & modules of this package which they-self offer deeper functionality to get things done:

```dart
final keysService = Nostr.instance.keysService; // access to the keys service, which will provide methods to handle user key pairs, private keys, public keys, etc.

final relaysService = Nostr.instance.relaysService; // access to the relays service, which will provide methods to interact with your own relays such as sending events, listening to events, etc.

final utilsService = Nostr.instance.utilsService; // access the utils service, which provides many handy utils that you will need to use in your app, such as encoding, getting random hex strings to use with requests, etc.
```

And so on, in the usage section, you will get to learn every single one and it's functionality & utils.
