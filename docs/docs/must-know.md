---
sidebar_position: 3
description: Master the Nostr protocol with dart_nostr. Effortlessly handle events and operations, except for specific exceptions. Navigate the code structure and access robust functionalities, all guided by a single maintainer.
---

# Must Know ?

With `dart_nostr`, you can achieve almost anything that relate to the Nostr protocol, there is some exceptions that are out of my hand currently such as adapting web-based extensions such [ably](https://chrome.google.com/webstore/detail/alby-bitcoin-lightning-wa/iokeahhehimjnekafflcihljlcjccdbe). In the other side, all other operations of sending events & listening to them.. will be like a piece of cake with this package.

This maintained by one individual, so if you opened any issue or a pull request, please be patient, I will try to respond as soon as possible.

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

so basically, this approach allows for the term of using the package in the whole application with the same singleton, this mean that as example, you can connect to your relays in the `main.dart` file, and you can create a new event from `myCubit.dart` file, you don't have to worry about this, just use & enjoy.

## Whats next ?

You're know ready to start learning how to use it in action, see the next section for more.

- [Usage](/usage/key-pairs/generate-key-pair)
