import 'dart:async';

import 'package:dart_nostr/dart_nostr.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_playground/src/nostr_tools.dart';
import 'package:nostr_playground/src/playground_controller.dart';

class _FakeSession implements PlaygroundNostrSession {
  final connectCompleter = Completer<NostrResult<void>>();
  final publishCompleters = <Completer<NostrResult<NostrEventOkCommand>>>[];
  final eventController = StreamController<NostrEvent>.broadcast();
  List<String> requestedRelays = const [];
  List<String> connectedRelays = const [];
  NostrFilter? lastFilter;
  int teardownCalls = 0;
  bool tornDown = false;

  @override
  Future<NostrResult<void>> connect(List<String> relays) {
    requestedRelays = relays;
    return connectCompleter.future;
  }

  @override
  Future<NostrResult<NostrEventOkCommand>> publish(NostrEvent event) {
    final completer = Completer<NostrResult<NostrEventOkCommand>>();
    publishCompleters.add(completer);
    return completer.future;
  }

  @override
  NostrResult<NostrEventsStream> subscribe(NostrFilter filter) {
    lastFilter = filter;
    return NostrSuccess(
      NostrEventsStream(
        stream: eventController.stream,
        subscriptionId: 'sub-1',
        request: NostrRequest(filters: [filter]),
      ),
    );
  }

  @override
  List<String> get liveRelayUrls => connectedRelays;

  void succeedConnect() {
    connectedRelays = requestedRelays;
    connectCompleter.complete(const NostrSuccess<void>(null));
  }

  @override
  Future<void> teardown() async {
    teardownCalls++;
    tornDown = true;
    if (!eventController.isClosed) {
      await eventController.close();
    }
  }
}

PlaygroundController _controllerWithFake(
  List<_FakeSession> sessions, {
  Duration connectTimeout = const Duration(seconds: 1),
  Duration publishTimeout = const Duration(seconds: 1),
}) {
  return PlaygroundController(
    sessionFactory: () {
      final session = _FakeSession();
      sessions.add(session);
      return session;
    },
    connectTimeout: connectTimeout,
    publishTimeout: publishTimeout,
  );
}

Future<void> _awaitMicrotasks() => Future<void>.delayed(Duration.zero);

void main() {
  test('generates an ephemeral identity without exposing the private key', () {
    final controller = PlaygroundController();
    addTearDown(controller.dispose);

    controller.generateKeyPair();

    expect(controller.hasKey, isTrue);
    expect(controller.publicKey, hasLength(64));
    expect(controller.npub, startsWith('npub1'));
    expect(controller.signedEvent, isNull);
    expect(controller.logs.first.message, contains('ephemeral key'));
  });

  test('signs and locally verifies an event', () {
    final controller = PlaygroundController();
    addTearDown(controller.dispose);
    controller.generateKeyPair();

    controller.signEvent(kind: '1', content: 'local only', tags: '[]');

    expect(controller.error, isNull);
    expect(controller.signedEvent, isNotNull);
    expect(controller.selectedEvent, same(controller.signedEvent));
    expect(controller.isAuthentic(controller.signedEvent!), isTrue);
  });

  test(
    'authenticity cache does not trust changed content with the same id',
    () {
      final controller = PlaygroundController();
      addTearDown(controller.dispose);
      controller.generateKeyPair();
      controller.signEvent(kind: '1', content: 'original', tags: '[]');
      final original = controller.signedEvent!;
      final tampered = NostrEvent(
        id: original.id,
        kind: original.kind,
        content: 'tampered',
        sig: original.sig,
        pubkey: original.pubkey,
        createdAt: original.createdAt,
        tags: original.tags,
      );

      expect(controller.isAuthentic(original), isTrue);
      expect(controller.isAuthentic(original), isTrue);
      expect(controller.isAuthentic(tampered), isFalse);
    },
  );

  test('signing without a key reports a visible error', () {
    final controller = PlaygroundController();
    addTearDown(controller.dispose);

    controller.signEvent(kind: '1', content: 'no key', tags: '[]');

    expect(controller.signedEvent, isNull);
    expect(controller.error, contains('ephemeral key'));
  });

  test('rejects bad relay URLs before opening a socket', () async {
    final controller = PlaygroundController();
    addTearDown(controller.dispose);

    await controller.connect('https://relay.example');

    expect(controller.status, PlaygroundSessionStatus.disconnected);
    expect(controller.error, contains('wss://'));
    expect(controller.logs.first.level, LogLevel.error);
  });

  test(
    'publishing requires a signed event, a connection and confirmation',
    () async {
      final controller = PlaygroundController();
      addTearDown(controller.dispose);

      await controller.publishSignedEvent(confirmed: true);
      expect(controller.error, contains('Sign'));

      controller.generateKeyPair();
      controller.signEvent(kind: '1', content: 'not connected', tags: '[]');

      await controller.publishSignedEvent(confirmed: false);
      expect(controller.publishReceipt, isNull);
      expect(controller.error, contains('confirmation'));

      await controller.publishSignedEvent(confirmed: true);
      expect(controller.publishReceipt, isNull);
      expect(controller.error, contains('Connect'));
    },
  );

  test('subscribing without a connection is refused', () {
    final controller = PlaygroundController();
    addTearDown(controller.dispose);

    controller.subscribe(kinds: '1', authors: '', limit: '20');

    expect(controller.subscriptionActive, isFalse);
    expect(controller.error, contains('Connect'));
  });

  test('generating a new key clears the previously signed event', () {
    final controller = PlaygroundController();
    addTearDown(controller.dispose);
    controller.generateKeyPair();
    controller.signEvent(kind: '1', content: 'first', tags: '[]');
    final firstKey = controller.publicKey;

    controller.generateKeyPair();

    expect(controller.publicKey, isNot(firstKey));
    expect(controller.signedEvent, isNull);
    expect(controller.selectedEvent, isNull);
  });

  test('disconnect clears keys, signed event and the session', () async {
    final sessions = <_FakeSession>[];
    final controller = _controllerWithFake(sessions);
    addTearDown(controller.dispose);

    final connecting = controller.connect('wss://relay.example');
    await _awaitMicrotasks();
    sessions.single.succeedConnect();
    await connecting;
    controller.generateKeyPair();
    controller.signEvent(
      kind: '1',
      content: 'sign then disconnect',
      tags: '[]',
    );
    expect(controller.hasKey, isTrue);

    await controller.disconnect();

    expect(controller.status, PlaygroundSessionStatus.disconnected);
    expect(controller.hasKey, isFalse);
    expect(controller.npub, isNull);
    expect(controller.signedEvent, isNull);
    expect(controller.liveRelays, isEmpty);
    expect(sessions.single.tornDown, isTrue);
  });

  test('concurrent connects create only one session', () async {
    final sessions = <_FakeSession>[];
    final controller = _controllerWithFake(sessions);
    addTearDown(controller.dispose);

    final first = controller.connect('wss://a.example');
    final second = controller.connect('wss://b.example');
    await second;
    await _awaitMicrotasks();

    expect(sessions, hasLength(1));
    expect(sessions.single.requestedRelays, ['wss://a.example']);

    sessions.single.succeedConnect();
    await first;

    expect(controller.status, PlaygroundSessionStatus.connected);
    expect(controller.liveRelays, ['wss://a.example']);
    expect(sessions, hasLength(1));
  });

  test(
    'disconnect during connect tears down and never revives the session',
    () async {
      final sessions = <_FakeSession>[];
      final controller = _controllerWithFake(sessions);
      addTearDown(controller.dispose);

      final connecting = controller.connect('wss://relay.example');
      await _awaitMicrotasks();
      final disconnecting = controller.disconnect();
      sessions.single.succeedConnect();
      await disconnecting;
      await connecting;

      expect(controller.status, PlaygroundSessionStatus.disconnected);
      expect(controller.liveRelays, isEmpty);
      expect(sessions.single.tornDown, isTrue);
      expect(sessions.single.teardownCalls, greaterThanOrEqualTo(1));
    },
  );

  test(
    'cancelling a pending connect keeps offline key and signed event',
    () async {
      final sessions = <_FakeSession>[];
      final controller = _controllerWithFake(sessions);
      addTearDown(controller.dispose);

      final connecting = controller.connect('wss://relay.example');
      await _awaitMicrotasks();
      controller.generateKeyPair();
      controller.signEvent(kind: '1', content: 'offline signed', tags: '[]');
      final event = controller.signedEvent;

      final disconnecting = controller.disconnect();
      sessions.single.succeedConnect();
      await disconnecting;
      await connecting;

      expect(controller.status, PlaygroundSessionStatus.disconnected);
      expect(controller.hasKey, isTrue);
      expect(controller.signedEvent, same(event));
      expect(sessions.single.tornDown, isTrue);
    },
  );

  test('oversized drops batch notifications instead of rebuilding per event',
      () async {
    final sessions = <_FakeSession>[];
    final controller = _controllerWithFake(sessions);
    addTearDown(controller.dispose);

    final connecting = controller.connect('wss://relay.example');
    await _awaitMicrotasks();
    sessions.single.succeedConnect();
    await connecting;
    controller.subscribe(kinds: '1', authors: '', limit: '100');

    var notifications = 0;
    controller.addListener(() => notifications++);
    final keys = NostrKeyPairs.generate();
    for (var i = 0; i < 30; i++) {
      sessions.single.eventController.add(
        NostrEvent(
          id: 'oversized-$i',
          kind: 1,
          content: 'a' * (maxRelayEventContentChars + 1),
          sig: 'sig',
          pubkey: keys.public,
          createdAt: DateTime.now(),
          tags: const [],
        ),
      );
    }
    await _awaitMicrotasks();
    await _awaitMicrotasks();

    expect(controller.events, isEmpty);
    expect(controller.droppedEventCount, 30);
    expect(notifications, greaterThan(0));
    expect(notifications, lessThanOrEqualTo(4));
    expect(controller.logs.length, lessThanOrEqualTo(maxLogEntries));
  });

  test('connect timeout tears down the abandoned session', () async {
    final sessions = <_FakeSession>[];
    final controller = _controllerWithFake(
      sessions,
      connectTimeout: const Duration(milliseconds: 30),
    );
    addTearDown(controller.dispose);

    await controller.connect('wss://relay.example');

    expect(controller.status, PlaygroundSessionStatus.disconnected);
    expect(controller.error, contains('timed out'));
    expect(sessions.single.tornDown, isTrue);
  });

  test('dispose during connect tears down the pending session', () async {
    final sessions = <_FakeSession>[];
    final controller = _controllerWithFake(sessions);

    final connecting = controller.connect('wss://relay.example');
    await _awaitMicrotasks();
    controller.dispose();
    sessions.single.succeedConnect();
    await connecting;
    await _awaitMicrotasks();

    expect(sessions.single.tornDown, isTrue);
    expect(controller.hasKey, isFalse);
    expect(controller.status, PlaygroundSessionStatus.disconnected);
  });

  test(
    'oversized relay events are dropped and the feed stays bounded',
    () async {
      final sessions = <_FakeSession>[];
      final controller = _controllerWithFake(sessions);
      addTearDown(controller.dispose);

      final connecting = controller.connect('wss://relay.example');
      await _awaitMicrotasks();
      sessions.single.succeedConnect();
      await connecting;
      controller.subscribe(kinds: '1', authors: '', limit: '100');

      final keys = NostrKeyPairs.generate();
      sessions.single.eventController.add(
        NostrEvent(
          id: 'oversized',
          kind: 1,
          content: 'a' * (maxRelayEventContentChars + 1),
          sig: 'sig',
          pubkey: keys.public,
          createdAt: DateTime.now(),
          tags: const [],
        ),
      );
      await _awaitMicrotasks();

      expect(controller.events, isEmpty);
      expect(controller.droppedEventCount, 1);
      expect(
        controller.logs.any((entry) => entry.level == LogLevel.warn),
        isTrue,
      );

      for (var i = 0; i < maxEventFeed + 10; i++) {
        sessions.single.eventController.add(
          signLocalEvent(
            keys: keys,
            kind: 1,
            content: 'event $i',
            tags: const [],
            createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000 + i),
          ),
        );
      }
      await _awaitMicrotasks();

      expect(controller.events, hasLength(maxEventFeed));
      expect(controller.feedOverflowCount, greaterThan(0));
      expect(controller.logs.length, lessThanOrEqualTo(maxLogEntries));
    },
  );

  test(
    'publish surfaces the first relay response and unknown outcomes',
    () async {
      final sessions = <_FakeSession>[];
      final controller = _controllerWithFake(sessions);
      addTearDown(controller.dispose);

      final connecting = controller.connect('wss://relay.example');
      await _awaitMicrotasks();
      sessions.single.succeedConnect();
      await connecting;
      controller.generateKeyPair();
      controller.signEvent(kind: '1', content: 'publish me', tags: '[]');

      final rejected = controller.publishSignedEvent(confirmed: true);
      await _awaitMicrotasks();
      sessions.single.publishCompleters.last.complete(
        const NostrSuccess<NostrEventOkCommand>(
          NostrEventOkCommand(
            eventId: 'event',
            isEventAccepted: false,
            message: 'blocked',
          ),
        ),
      );
      await rejected;

      expect(controller.error, contains('First relay response'));
      expect(controller.error, contains('unknown'));

      controller.signEvent(kind: '1', content: 'publish me again', tags: '[]');
      final accepted = controller.publishSignedEvent(confirmed: true);
      await _awaitMicrotasks();
      sessions.single.publishCompleters.last.complete(
        const NostrSuccess<NostrEventOkCommand>(
          NostrEventOkCommand(
            eventId: 'event',
            isEventAccepted: true,
            message: '',
          ),
        ),
      );
      await accepted;

      expect(controller.publishReceipt, contains('First relay response'));
      expect(controller.publishReceipt, contains('Other relays may differ'));
    },
  );

  test('dispose clears in-memory keys and is idempotent', () {
    final controller = PlaygroundController();
    controller.generateKeyPair();
    controller.dispose();
    controller.dispose();

    expect(controller.hasKey, isFalse);
    expect(controller.publicKey, isNull);
    expect(controller.status, PlaygroundSessionStatus.disconnected);
  });

  test('logs stay bounded', () {
    final controller = PlaygroundController();
    addTearDown(controller.dispose);

    for (var i = 0; i < maxLogEntries + 25; i++) {
      controller.generateKeyPair();
    }

    expect(controller.logs.length, maxLogEntries);
  });
}
