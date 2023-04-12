# Nostr Dart Client for Nostr protocol.

**help this gets discovered and noticed by other developers with a star ⭐**

This package is a client for the [Nostr protocol](https://github.com/nostr-protocol/). It is a wrapper that lets you interact with the Nostr protocol in an easier, faster and more organized way.

## TODO:

(talking to me) please, when you have time, here is a thing to do in addition to maintaining the package.

- [ ] Add tests for every single member.
- [ ] Add more documentation.
- [ ] add more examples.
- [ ] ...

# Usage:

the main and only the instance that you need to use to access all other memebers in this package is:

```dart
Nostr.instance;
```

`Nostr.instance` offers access to the services of this package which they-self offer many other functionalities to get your things done.

```dart
Nostr.instance.keysService; // access to the keys service, which will provide methods to handle user key pairs, private keys, public keys, etc.

Nostr.instance.relaysService; // access to the relays service, which will provide methods to interact with your own relays such as sending events, listening to events, etc.
```
