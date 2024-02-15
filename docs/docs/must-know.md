---
sidebar_position: 3
description: Master the Nostr protocol with dart_nostr. Effortlessly handle events and operations, except for specific exceptions. Navigate the code structure and access robust functionalities, all guided by a single maintainer.
---

# Must Know ?

This page will help you to get started with `dart_nostr` package, and ensuring that you have the basic knowledge to start using the package.

## General knowledge

`dart_nostr` package and this documentation assumes that you have a basic knowledge about the Nostr protocol, and how it works, if you don't know anything about the Nostr protocol, please read the [Nostr protocol documentation](https://nostr.org/docs/protocol) first, check the [Nostr NIPs](https://github.com/nostr-protocol/nips/) and get as much knowledge as you can about the Nostr protocol, then come back here and continue reading.

The goal of `dart_nostr` is to achieve almost anything that relate to the Nostr protocol (or at least the hard part), it will provide you with minimal APIs to start building your Nostr application, and so you can focus on your application logic, and not on the Nostr protocol itself.

## The package structure

`dart_nostr` exposes all it's functionality via a `Nostr` class instance, which holds all the future connections, events cache, keys, relays, etc. and so creating a new instance each time will create a whole separated with its own resources.

However, the packages offers a singleton instance of the `Nostr` class, which you can access it by calling the `Nostr.instance` getter, this will return the singleton instance of the `Nostr` class, which you can use it in your whole application, this is the recommended way to use the package (At least for dart:io platforms, and for medium sized apps), as it will allow you to access the same instance of the `Nostr` class in the whole application, and so you can access the same resources in the whole application, such as the same keys, events, relays, etc:

```dart
/// Different instances
final newInstanceOne  = Nostr();
final newInstanceTwo  = Nostr();

print(newInstanceOne == newInstanceTwo); // false, as they are two different instances

// Singleton instance
final instance = Nostr.instance;
```

A `Nostr` instance allow developers to access package members via services, which are:

```dart
final keysService = instance.keysService; // access to the keys service, which will provide methods to handle user key pairs, private keys, public keys, etc.

final relaysService = instance.relaysService; // access to the relays service, which will provide methods to interact with your own relays such as sending events, listening to events, etc.

final utilsService = instance.utilsService; // access the utils service, which provides many handy utils that you will need to use in your app, such as encoding, getting random hex strings to use with requests, etc.
```

Each service has its own methods that you can call and use, for example, the `keysService` has the `generateKeyPair()` method, which will generate a new key pair for your users, and so on.

The singleton approach allows using the package in the whole application with the same singleton without worrying about relating things around (relays connection with Nostr requests and received events...), however, if you want to use the package in a large application, you may want to create a new instance of the `Nostr` class, and use it in a specific part of your application, this will allow you to separate things around, and so you can use the package in different parts of your application without worrying about relating things around.

```dart
// Connect to relays in a specific part of your application.
await instance.relaysService.init(
    relayUrls: [
        'wss://relay1.nostr.org',
        'wss://relay2.nostr.org',
    ],
);

// Send an event in another part of your application.
await instance.relaysService.sendEventToRelays(/* ... */);
```

:::note
You don't need to worry about the code above, it's just an example to show you how you can use the package in different parts of your application.
:::

## The supported NIPs

This package allows you to use the Nostr protocol with the following NIPs:
