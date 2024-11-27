---
sidebar_position: 3
---

# Listening & subscribe to events

After ensuring that your client Dart/Flutter application is connected to a set of your relays, you will need to retrieve events, this is done by sending requests to relays and listen to them.

In Order to subscribe & listen to a set of target events, you will need to create the request that defines it, and then send it to the relays, and then listen to the stream of events that will be returned.

Don't worry about sending events, this will be covered in the next documentation section, this is a special implmentation to subscribe to events.

This is an example of how we can achieve it:

```dart

// Creating a request to retrieve all kind 1 (notes) events that have the "nostr" tag.
final req = NostrRequest(
 filters: [
   NostrFilter(
     kind: 1,
     tags: ["t", "nostr"],
     authors: [],
   ),
 ],
);


// Creating a request to retrieve all kind 1 (notes) events that have the "nostr" tag.
final nostrEventsSubscription = Nostr.instance.services.relays.startEventsSubscription(
       request: req,
       onEose: (ease) {
         print("ease received for subscription id: ${ease.subscriptionId}");
     
        // Closing the request as example, see next section.
  
  });

// listening to the stream of the subscription, and print all events in the debug console.
nostrEventsSubscription.stream.listen((event) {
  print(event);
});

```

in order to trigger an action when the eose command is sent from a relay to our client app, you can pass a callback to the `onEose` parameter.

## Closing A subscription
s
in order to close & end aspecific subscription that is created, you can call the `closeEventsSubscription` method

```dart

Nostr.instance.services.relays.closeEventsSubscription(
  eose.subscriptionId,
);
```

This will end & stop events for been received by the relays.