---
sidebar_position: 99
sidebar_label: Contributing
title: Contribute to the dart_nostr SDK
description: Contribute Dart Nostr protocol fixes, relay lifecycle tests, transports or documentation. Learn what to include in an issue or pull request.
---

# Contributing

Contributions are welcome. Fork the [GitHub repository](https://github.com/anasfik/nostr), make your changes, and open a pull request.

Useful contributions include protocol correctness fixes, relay handling improvements, additional tests, new transport implementations, and documentation improvements.

Make sure changes include tests where appropriate and keep the public API consistent.

## Report a reproducible issue

Include the package version or Git revision, Dart/Flutter version, platform, expected result and a minimal example. For relay failures, include a sanitized failure code and explain whether one relay or several are affected. Remove private keys, event content and personal identifiers before sharing logs.

## Check a change locally

Run the offline Dart suite from the repository root:

```bash
dart pub get
dart test --concurrency=1
```

Real-network tests are opt-in and can publish events. Do not enable `RUN_REAL_NETWORK_TESTS` as a routine check. Documentation changes should also pass the [site build and route checks](https://github.com/anasfik/nostr/blob/main/docs/README.md).
