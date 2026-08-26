import 'dart:async';

import 'dart:convert';
import 'dart:io';

import 'package:dart_nostr/dart_nostr.dart';
import 'package:test/test.dart' as test;

/// Gate: real-network tests only run when explicitly enabled.
///
/// ```sh
/// RUN_REAL_NETWORK_TESTS=1 dart test test/real
/// ```
bool get realNetworkTestsEnabled =>
    Platform.environment['RUN_REAL_NETWORK_TESTS'] == '1';

/// Public relays verified reachable from CI/dev environments.
/// nostr.wine requires NIP-42 auth for writes — used by auth tests.
const kPrimaryRelays = [
  'wss://relay.damus.io',
  'wss://nos.lol',
  'wss://relay.primal.net',
  'wss://offchain.pub',
];

const kAuthRelay = 'wss://nostr.wine';

final kTestTimeout = const test.Timeout(Duration(minutes: 4));

/// Returns up to [count] currently-reachable relays, probing each with a
/// quick REQ. Public relays go down regularly (503s, rate limits), so real
/// tests must select healthy ones at runtime.
Future<List<String>> pickLiveRelays({int count = 2}) async {
  final live = <String>[];

  for (final relay in kPrimaryRelays) {
    try {
      await rawFetch(
        relay,
        {
          'kinds': [1],
          'limit': 1,
        },
        timeout: const Duration(seconds: 8),
      );
      live.add(relay);
    } catch (_) {
      continue;
    }

    if (live.length >= count) {
      break;
    }
  }

  if (live.length < count) {
    throw StateError(
      'only ${live.length} of $kPrimaryRelays reachable; need $count',
    );
  }

  return live;
}

/// Fresh identity for this test run.
NostrKeyPairs newIdentity() => NostrKeyPairs.generate();

/// Fetches events directly over a throwaway websocket connection.
/// Independent from the library's pool so tests can assert on raw wire data
/// as ground truth. Tries [relays] in order, tolerating transient failures.
Future<List<dynamic>> rawFetchAny(
  List<String> relays,
  Map<String, dynamic> filter, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  Object? lastError;

  for (final relay in relays) {
    try {
      return await rawFetch(relay, filter, timeout: timeout);
    } catch (e) {
      lastError = e;
    }
  }

  throw StateError('all relays failed; last error: $lastError');
}

/// Fetches events directly over a throwaway websocket connection.
/// Independent from the library's pool so tests can assert on raw wire data
/// as ground truth.
Future<List<dynamic>> rawFetch(String relay, Map<String, dynamic> filter,
    {Duration timeout = const Duration(seconds: 10)}) async {
  final socket = await WebSocket.connect(relay).timeout(timeout);
  final subId = 'probe${DateTime.now().millisecondsSinceEpoch}';
  socket.add(jsonEncode(['REQ', subId, filter]));

  final events = <dynamic>[];
  final done = Completer<void>();

  late StreamSubscription<dynamic> sub;
  sub = socket.listen((data) {
    try {
      final decoded = jsonDecode(data as String) as List;
      if (decoded.first == 'EVENT' && decoded[1] == subId) {
        events.add(decoded[2]);
      } else if (decoded.first == 'EOSE' && decoded[1] == subId) {
        done.complete();
        sub.cancel();
      }
    } catch (_) {}
  }, onError: (Object e) {
    if (!done.isCompleted) done.complete();
  }, onDone: () {
    if (!done.isCompleted) done.complete();
  });

  await done.future.timeout(timeout, onTimeout: () {});
  await socket.close().catchError((_) {});

  return events;
}

/// Sends a single EVENT message over a raw socket and returns the first OK.
Future<List<dynamic>> rawPublish(String relay, NostrEvent event,
    {Duration timeout = const Duration(seconds: 10)}) async {
  final socket = await WebSocket.connect(relay).timeout(timeout);
  socket.add(event.serialized());

  List<dynamic>? ok;
  try {
    final reply = await socket.first.timeout(timeout, onTimeout: () => null);
    if (reply != null) {
      ok = jsonDecode(reply as String) as List;
    }
  } finally {
    await socket.close().catchError((_) {});
  }

  return ok ?? ['TIMEOUT'];
}

/// Publishes [event], trying each live relay in turn until one accepts it.
/// Mirrors what real clients do when relays rate-limit or refuse writes.
Future<NostrEventOkCommand?> publishWithFallback(
  Nostr nostr,
  NostrEvent event,
  List<String> relays,
) async {
  for (final relay in relays) {
    final connected = await nostr.connect([relay]);
    if (connected.isFailure) {
      continue;
    }

    final result = await nostr.publish(event);
    if (result.isSuccess && (result.valueOrNull?.isEventAccepted ?? false)) {
      return result.valueOrNull;
    }
  }
  return null;
}

/// Waits until [test] returns true when polling [probe]. Probe errors
/// (relay 503s, timeouts) are treated as "not ready yet" and retried.
Future<T> eventually<T>(
  Future<T> Function() probe,
  bool Function(T) test, {
  Duration every = const Duration(milliseconds: 500),
  Duration timeout = const Duration(seconds: 15),
}) async {
  final deadline = DateTime.now().add(timeout);

  while (true) {
    T? result;
    Object? probeError;

    try {
      result = await probe();
    } catch (e) {
      probeError = e;
    }

    if (probeError == null && test(result as T)) {
      return result;
    }

    if (DateTime.now().isAfter(deadline)) {
      if (probeError != null) {
        throw StateError('condition not met; last probe error: $probeError');
      }
      throw TimeoutException('condition not met within $timeout');
    }
    await Future<void>.delayed(every);
  }
}
