---
sidebar_position: 1
---

# Creating Events

Events are the atomic unit of the Nostr protocol. This is a short overview of various types of events, you can learn more about events from [here.](https://nostr.com/the-protocol/events).

In the following sections, you will learn how you can create an event using `dart_nostr`, type of implmentation that are offered are the following:

- Creating a raw event, this means that all fields in the events need te be assigned manually.
- Creating a shortcut event, this means that you only need to set the direct necessary fields and the rest will be handled internally by the package.
- Creating customized events, thsose kind of events can be created using the two previous ways, but some Nostr NIPs, require much additional work to create there events, either some kind of hashing, encryption, setting non-sense fields... which might not be easy for all, so this packages offers some other additional ways to create those events.

## Creating a raw event

You can get the final events that you will send them to your relays by either creating a raw `NostrEvent` object, that allows you to set every field manually such as id, pubkey, sig, content..., you can learn more about a Nostr event from [here.](https://github.com/nostr-protocol/nips/blob/master/01.md), example of creating an event.

```dart
 // Create a new key pair.
final keyPair = Nostr.instance.keysService.generateKeyPair();

// Create a new event.
NostrEvent event = SendNostrEvent(
  pubkey: '<THE-PUBKEY-OF-THE-EVENT-OWNER>',
  kind: 0,
  content: 'This is a test event content',
  createdAt: DateTime.now(),
  id: '<THE-ID-OF-THE-EVENT>', // you will need to generate and set the id of the event manually by hashing other event fields, please refer to the official Nostr protocol documentation to learn how to do it yourself.
  tags: [],
  sig: '<THE-SIGNATURE-OF-THE-EVENT>', // you will need to generate and set the signature of the event manually by signing the event's id, please refer to the official Nostr protocol documentation to learn how to do it yourself.
);

// later, send the event to relays.
// ...
```

## Creating a shortcut event

As it is mentioned, this will require you to set every single value of the event properties manually. Well, we all love easy things right? `dart_nostr` offers the option to handle all this internally and covers you in this part with the  `NostrEvent.fromPartialData(...)` factory constructor, which requires you to only set the direct necessary fields and leave the the rest to be handled internally by the package, so you don't need to worry about anything else, this is the newest & fastest way to create an event:

```dart
// Create a new key pair.
final keyPair = Nostr.instance.keysService.generateKeyPair();

// Create a new event.
final event = NostrEvent.fromPartialData(
  kind: 0,
  keyPairs: keyPair,
  content: 'This is a test event content',
  tags: [],
  createdAt: DateTime.now(),
);

// later, send the event to relays.
// ...
```

The only required fields in the  `NostrEvent.fromPartialData` factory constructor here are the `kind`, `keyPairs` and `content` fields.

**Notes here:**

- if the `tags` field is `null`, an empty list `[]` will be used in the event.

- if `createdAt` is ignored, the date which will be used is the instant date when the event is created. In Dart, this means using `DateTime.now()`.

- The `id`, `sign` and `pubkey` fields is what you don't need to worry about when using this constructor, the package will calculate a encode them for you, and assign them to the event that will be sent to relays.

**Why `keyPairs` is required ?**

The `NostrEvent.fromPartialData` requires the `keyPairs` because it needs to get it's private key to sign the event with it, creating the `sig` field of the event. In the other side, the public key will be used directly for the event `pubKey` field.

## Customized events

### Delete Event

You can create & send a delete event like this:

```dart

// assuming you have other receivedEvents
NostrEvent originalEvent = ...

// create a delete event
  final deleteEvent = NostrEvent.deleteEvent(
    reasonOfDeletion: "As example, the user decided to delete his created note events.",
    keyPairs: newKeyPair,
    eventIdsToBeDeleted: [
      // this is just an example event id.
      originalEvent.id,
    ],
  );

  // send the delete event.
  Nostr.instance.relaysService.sendEventToRelays(deleteEvent);

```
