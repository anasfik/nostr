# Changelog

## 8.1.0

- Making use of the `web_socket_channel` for cross platform compatibility.

## 8.0.3

- Support to sending close commands to specific relays, instead of closing all relays at once.

## 8.0.2

- Fixed issue of async method to get events from relays.

## 8.0.1

- Support for #a tag filter.

## 8.0.0

- Support for identification of relays commands by their name/url, in order to be able to customize behavior based on the relay and the action instead of the action only.
- Minor edits and fixes.

## 7.0.1

- Support for NIP 50 search filter with example.

## 7.0.0

- Breaking changes in most package services.
- Implementations for more asyncronous methods.
- New Mniimal Documentation for the package in readme.md file.
- Minor dev edits, fixes and improvements.

## 6.1.0

- Implmenttaion of free resources method for the relays service of an instance that clears and closes all events registeries and streams.
- Implementation of a new asynchronous methods for sending and receiving events, to ensure actions before and after the event is sent or received.
- More Doc comments for members.
- Minor bug fixes.

## 6.0.1

- Fixed the Stack overflow issue in the event model .

## 6.0.0

- Added ability to create standalone instances of the package services, useful if you want to target Flutter web so you can use only one service for routes and not all of them...
- Break changes in events types, in favor of possible collisions when working with replacable events.

## 5.0.1

- Added documentation config to pubspec.yaml

## 5.0.0

- Fully Breaking changes.
- Adidtion of callbacks triggeres for events, notices...
- Adidtion of more features.

## 4.0.0

- Breaking changes
- Exposed more APIs to the package interface.
- Offered more control over the events sending/receiving.

## 3.3.1

- Bug fixes.
- Added more docs
- More optimizations for the use of the keypair class for quickeer constructions after the first time (caching).

## 3.0.0

- Added new utils methods to the utils service.
- Exposed and modifed some implmentation source service class.
- Minor modifications for better maintainence of code.
- Commented out more APIs of the package.

## 2.1.1

- Changes the dart_bip32_bip44 with bip32_bip44 so it works with dart packages and projects and not Flutter ones sonce it breaks pana scoring system.

## 2.1.0

- Added nprofile & tlv services

## 2.0.1

- Minor changes in the docs.
- Added more docs to memebers that miss it.

## 2.0.0

- Exposed new APIs with new documentation for more developer experience use of this package.
- Addition of utils service.
- Addition of more nostr NIPs in the package.
- Added more examples.

## 1.5.1

- Exported the `NostrEventsStream` model class

## 1.5.0

- Added implementation of bech32 encoder in general.
- Added implementation of npub & nsec encoder.
- Added example for generating npub & nsec keys.
- Added more documentation and documenttaion-example for some memebers that miss it in the keys service.

## 1.4.0

- Added the reconnecting option when a relay sent's a notice message.

## 1.3.3

- refactored the optional memebers to requests in the internal library packages.
- ( experiental ) Implementation of a work around over the relays subscrition limits.

## 1.3.2

- Added a main example.

## 1.3.0

- Add more helper methods.
- Minor fixes.

## 1.2.0

- Added example of litening to events.
- Fixing the subscription id that turns null when not se

## 1.1.0

- Fixed signing and verifying hexadiciaml encoding issue.
- added more example in example/ folder.

## 1.0.6

- Added more helper methods with docs and examples.

## 1.0.5

- Added more docs with examples to more methods.

## 1.0.4

- Highlighted support for more nips in the docs.

## 1.0.3

- Added support for more nips.
- Exposed them in the docs.

## 1.0.2

- Added implementation of nip 11 and its docs

## 1.0.1

- Added docs for nip-05 verification.

## 1.0.0

- Implementation of nip 05 for internet identity verification.
- Adding more docs and examples.

## 1.0.2-dev

- Added more functionalities and parameters to the `relays` service.

## 1.0.1-dev

- organized the main package to services (keys, relays).
- exposed more helper methods.
- added and edited docs

## 1.0.0-dev

- Initial under-development version.
