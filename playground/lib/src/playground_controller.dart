import 'dart:async';

import 'package:dart_nostr/dart_nostr.dart';
import 'package:flutter/foundation.dart';

import 'nostr_tools.dart';

enum PlaygroundSessionStatus { disconnected, connecting, connected }

enum LogLevel { info, event, warn, error }

/// Minimal session surface used by the controller. Production uses
/// [_DartNostrSession]; tests inject a controlled implementation.
abstract interface class PlaygroundNostrSession {
  Future<NostrResult<void>> connect(List<String> relays);
  Future<NostrResult<NostrEventOkCommand>> publish(NostrEvent event);
  NostrResult<NostrEventsStream> subscribe(NostrFilter filter);
  List<String> get liveRelayUrls;
  Future<void> teardown();
}

typedef PlaygroundSessionFactory = PlaygroundNostrSession Function();

class _DartNostrSession implements PlaygroundNostrSession {
  _DartNostrSession()
    : _nostr = Nostr(
        clientOptions: const NostrClientOptions(
          connectionTimeout: Duration(seconds: 8),
          requestTimeout: Duration(seconds: 10),
          failFast: true,
        ),
      ) {
    _nostr.disableLogs();
  }

  final Nostr _nostr;
  bool _released = false;

  @override
  Future<NostrResult<void>> connect(List<String> relays) =>
      _nostr.connect(relays);

  @override
  Future<NostrResult<NostrEventOkCommand>> publish(NostrEvent event) =>
      _nostr.publish(event);

  @override
  NostrResult<NostrEventsStream> subscribe(NostrFilter filter) =>
      _nostr.subscribe(filter);

  @override
  List<String> get liveRelayUrls {
    try {
      return _nostr.liveRelayUrls;
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<void> teardown() async {
    if (_released) {
      return;
    }
    _released = true;

    try {
      await _nostr.disconnect().timeout(const Duration(seconds: 10));
    } catch (_) {
      // Best-effort teardown; the SDK generation guard stops late sockets.
    }
    try {
      await _nostr.services.keys.freeAllResources().timeout(
        const Duration(seconds: 5),
      );
    } catch (_) {
      // Best effort.
    }
    try {
      await _nostr.services.relays.freeAllResources().timeout(
        const Duration(seconds: 5),
      );
    } catch (_) {
      // Best effort.
    }
  }
}

class LogEntry {
  const LogEntry({
    required this.at,
    required this.level,
    required this.message,
  });

  final DateTime at;
  final LogLevel level;
  final String message;

  String get timestamp {
    final h = at.hour.toString().padLeft(2, '0');
    final m = at.minute.toString().padLeft(2, '0');
    final s = at.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}

class PlaygroundController extends ChangeNotifier {
  PlaygroundController({
    PlaygroundSessionFactory? sessionFactory,
    Duration connectTimeout = const Duration(seconds: 25),
    Duration publishTimeout = const Duration(seconds: 20),
  }) : _sessionFactory = sessionFactory ?? _DartNostrSession.new,
       _connectGuard = connectTimeout,
       _publishGuard = publishTimeout;

  static final Nostr _bech32Helper = Nostr();

  final PlaygroundSessionFactory _sessionFactory;
  final Duration _connectGuard;
  final Duration _publishGuard;
  static const Duration _emptyNotice = Duration(seconds: 15);

  PlaygroundNostrSession? _session;
  PlaygroundNostrSession? _pendingSession;
  int _sessionGeneration = 0;

  NostrKeyPairs? _keyPair;
  NostrEventsStream? _subscription;
  StreamSubscription<NostrEvent>? _subscriptionListener;
  Timer? _emptyTimer;
  bool _disposed = false;
  final Map<int, ({NostrEvent event, bool authentic})> _authenticityCache = {};

  PlaygroundSessionStatus status = PlaygroundSessionStatus.disconnected;
  List<String> relays = const [];
  List<String> liveRelays = const [];
  final List<NostrEvent> events = [];
  final List<LogEntry> logs = [];
  int droppedEventCount = 0;
  int feedOverflowCount = 0;

  String? error;
  String? publishReceipt;
  String? subscriptionId;
  bool subscriptionActive = false;
  bool waitingForFirstEvent = false;
  bool publishing = false;
  NostrEvent? signedEvent;
  NostrEvent? selectedEvent;

  bool get hasKey => _keyPair != null;
  String? get publicKey => _keyPair?.public;
  String? get npub => _keyPair == null
      ? null
      : _bech32Helper.bech32.encodePublicKeyToNpub(_keyPair!.public);

  String? get selectedEventJson =>
      selectedEvent == null ? null : prettyEventJson(selectedEvent!);

  bool get canPublish =>
      signedEvent != null &&
      !publishing &&
      status == PlaygroundSessionStatus.connected &&
      _session != null;

  bool isAuthentic(NostrEvent event) {
    final key = identityHashCode(event);
    final cached = _authenticityCache[key];
    if (cached != null && identical(cached.event, event)) {
      return cached.authentic;
    }

    final authentic = isEventAuthentic(event);
    if (_authenticityCache.length >= maxAuthenticityCacheEntries) {
      _authenticityCache.remove(_authenticityCache.keys.first);
    }
    _authenticityCache[key] = (event: event, authentic: authentic);
    return authentic;
  }

  void generateKeyPair() {
    final pair = NostrKeyPairs.generate();
    _keyPair = pair;
    signedEvent = null;
    selectedEvent = null;
    publishReceipt = null;
    error = null;
    _appendLog(
      LogLevel.info,
      'Generated ephemeral key ${shortId(pair.public)}.',
    );
    _notify();
  }

  void signEvent({
    required String kind,
    required String content,
    required String tags,
  }) {
    final keys = _keyPair;
    if (keys == null) {
      _setError('Generate an ephemeral key first.');
      return;
    }

    try {
      final event = signLocalEvent(
        keys: keys,
        kind: parseKind(kind),
        content: content,
        tags: parseTags(tags),
      );
      signedEvent = event;
      selectedEvent = event;
      publishReceipt = null;
      error = null;
      _appendLog(
        LogLevel.info,
        'Signed kind ${event.kind} event ${shortId(event.id)} locally.',
      );
      _notify();
    } on FormatException catch (e) {
      _setError(e.message);
    } catch (e) {
      _setError('Signing failed: $e');
    }
  }

  void selectEvent(NostrEvent? event) {
    selectedEvent = event;
    _notify();
  }

  Future<void> connect(String rawRelays) async {
    if (status == PlaygroundSessionStatus.connecting) {
      return;
    }

    final parsed = parseRelayInput(rawRelays);
    if (!parsed.isValid) {
      _setError(parsed.error!);
      return;
    }

    // Mark busy before the first await so concurrent connects cannot both run.
    final generation = ++_sessionGeneration;
    status = PlaygroundSessionStatus.connecting;
    error = null;
    publishReceipt = null;
    publishing = false;
    liveRelays = const [];
    relays = parsed.urls;

    final previous = _session;
    final previousPending = _pendingSession;
    _session = null;
    _pendingSession = null;

    _appendLog(LogLevel.info, 'Connecting to ${relays.length} relay(s)…');
    _notify();

    await _releaseSession(previous);
    await _releaseSession(previousPending);
    if (generation != _sessionGeneration) {
      return;
    }

    final session = _sessionFactory();
    _pendingSession = session;
    _notify();

    NostrResult<void> result;
    try {
      result = await session.connect(relays).timeout(_connectGuard);
    } on TimeoutException {
      _pendingSession = null;
      await _releaseSession(session);
      if (generation != _sessionGeneration) {
        return;
      }
      status = PlaygroundSessionStatus.disconnected;
      _setError('Connection timed out after ${_connectGuard.inSeconds}s.');
      return;
    } catch (e) {
      _pendingSession = null;
      await _releaseSession(session);
      if (generation != _sessionGeneration) {
        return;
      }
      status = PlaygroundSessionStatus.disconnected;
      _setError('Could not connect: $e');
      return;
    }

    if (generation != _sessionGeneration) {
      // Disconnect or a newer connect superseded this attempt.
      _pendingSession = null;
      await _releaseSession(session);
      return;
    }

    _pendingSession = null;
    if (result.isFailure) {
      await _releaseSession(session);
      status = PlaygroundSessionStatus.disconnected;
      _setError('Could not connect: ${result.failureOrNull!.message}');
      return;
    }

    _session = session;
    status = PlaygroundSessionStatus.connected;
    _refreshLiveRelays();
    _appendLog(
      LogLevel.info,
      'Connected to ${liveRelays.length} of ${relays.length} relay(s).',
    );
    _notify();
  }

  Future<void> disconnect() async {
    // Invalidate in-flight connect/publish results before awaiting teardown.
    _sessionGeneration++;
    final wasEstablished =
        status == PlaygroundSessionStatus.connected;
    final pending = _pendingSession;
    final active = _session;
    _pendingSession = null;
    _session = null;

    stopSubscription(notify: false);
    if (wasEstablished) {
      _clearEphemeralState();
    }
    events.clear();
    droppedEventCount = 0;
    feedOverflowCount = 0;
    liveRelays = const [];
    status = PlaygroundSessionStatus.disconnected;
    error = null;
    publishReceipt = null;
    publishing = false;
    _authenticityCache.clear();

    _notify();

    await _releaseSession(pending);
    await _releaseSession(active);
    if (_disposed) {
      return;
    }

    _appendLog(
      LogLevel.info,
      wasEstablished
          ? 'Disconnected. Ephemeral keys cleared.'
          : 'Connection cancelled. Offline key and signed event preserved.',
    );
    _notify();
  }

  void subscribe({
    required String kinds,
    required String authors,
    required String limit,
  }) {
    final session = _session;
    if (session == null || status != PlaygroundSessionStatus.connected) {
      _setError('Connect to at least one relay before subscribing.');
      return;
    }

    final filterInput = parseFilterInput(
      kinds: kinds,
      authors: authors,
      limit: limit,
    );
    if (!filterInput.isValid) {
      _setError(filterInput.error!);
      return;
    }

    stopSubscription(notify: false);
    final result = session.subscribe(
      NostrFilter(
        kinds: filterInput.kinds.isEmpty ? null : filterInput.kinds,
        authors: filterInput.authors.isEmpty ? null : filterInput.authors,
        limit: filterInput.limit,
      ),
    );

    if (result.isFailure) {
      _setError('Subscribe failed: ${result.failureOrNull!.message}');
      return;
    }

    final stream = result.valueOrNull!;
    _subscription = stream;
    subscriptionId = stream.subscriptionId;
    subscriptionActive = true;
    waitingForFirstEvent = true;
    events.clear();
    droppedEventCount = 0;
    feedOverflowCount = 0;
    selectedEvent = signedEvent;
    error = null;
    _subscriptionListener = stream.stream.listen(
      _onEvent,
      onError: _onSubscriptionError,
      onDone: _onSubscriptionDone,
    );
    _emptyTimer = Timer(_emptyNotice, () {
      if (!subscriptionActive) {
        return;
      }
      waitingForFirstEvent = false;
      _appendLog(
        LogLevel.warn,
        'No events after ${_emptyNotice.inSeconds}s. The relay may not '
        'return results for this filter.',
      );
      _notify();
    });
    _appendLog(
      LogLevel.info,
      'Subscribed ${shortId(stream.subscriptionId)} '
      '(kinds: ${filterInput.kinds.isEmpty ? "any" : filterInput.kinds.join(",")}; '
      'limit: ${filterInput.limit}).',
    );
    _notify();
  }

  void stopSubscription({bool notify = true}) {
    _emptyTimer?.cancel();
    _emptyTimer = null;

    final listener = _subscriptionListener;
    _subscriptionListener = null;
    if (listener != null) {
      unawaited(listener.cancel());
    }

    final stream = _subscription;
    _subscription = null;
    if (stream != null) {
      try {
        stream.close();
      } catch (_) {
        // The transport may already be closed.
      }
    }

    final wasActive = subscriptionActive || subscriptionId != null;
    subscriptionActive = false;
    waitingForFirstEvent = false;
    subscriptionId = null;

    if (wasActive) {
      _appendLog(LogLevel.info, 'Read subscription closed.');
    }
    if (notify) {
      _notify();
    }
  }

  Future<void> publishSignedEvent({required bool confirmed}) async {
    final event = signedEvent;
    if (event == null) {
      _setError('Sign an event locally before publishing.');
      return;
    }
    if (!confirmed) {
      _setError('Publishing requires explicit confirmation.');
      return;
    }

    final session = _session;
    if (session == null || status != PlaygroundSessionStatus.connected) {
      _setError('Connect to at least one relay before publishing.');
      return;
    }
    if (publishing) {
      return;
    }

    final generation = _sessionGeneration;
    publishing = true;
    error = null;
    publishReceipt = null;
    _appendLog(
      LogLevel.info,
      'Publishing kind ${event.kind} event ${shortId(event.id)}…',
    );
    _notify();

    try {
      final result = await session.publish(event).timeout(_publishGuard);
      if (generation != _sessionGeneration) {
        return;
      }
      publishing = false;
      if (result.isFailure) {
        _setError(
          'Publish outcome unknown: ${result.failureOrNull!.message}. '
          'No relay confirmation was received.',
        );
        return;
      }

      final ok = result.valueOrNull!;
      if (ok.isEventAccepted == true) {
        publishReceipt =
            'First relay response: accepted ${shortId(event.id)}.'
            '${ok.message == null || ok.message!.isEmpty ? "" : " ${ok.message}"}'
            ' Other relays may differ.';
        _appendLog(LogLevel.info, publishReceipt!);
      } else {
        _setError(
          'First relay response was a rejection'
          '${ok.message == null || ok.message!.isEmpty ? "" : ": ${ok.message}"}. '
          'Another relay may have accepted the event; the final outcome is '
          'unknown.',
        );
      }
    } on TimeoutException {
      if (generation != _sessionGeneration) {
        return;
      }
      publishing = false;
      _setError(
        'Publishing timed out after ${_publishGuard.inSeconds}s. '
        'No relay confirmation was received; the outcome is unknown.',
      );
      return;
    } catch (e) {
      if (generation != _sessionGeneration) {
        return;
      }
      publishing = false;
      _setError(
        'Publish outcome unknown: $e. No relay confirmation was received.',
      );
      return;
    }

    _refreshLiveRelays();
    _notify();
  }

  void clearError() {
    if (error == null) {
      return;
    }
    error = null;
    _notify();
  }

  void _onEvent(NostrEvent event) {
    if (_disposed) {
      return;
    }

    final rejection = relayEventRejection(event);
    if (rejection != null) {
      droppedEventCount++;
      if (droppedEventCount == 1 || droppedEventCount % 10 == 0) {
        _appendLog(
          LogLevel.warn,
          'Dropped relay event ($rejection). '
          'Dropped $droppedEventCount event(s) so far.',
        );
        // Batch UI updates for hostile event floods: notify on warning
        // boundaries instead of once per dropped event.
        _notify();
      }
      return;
    }

    final id = event.id;
    if (id != null && events.any((existing) => existing.id == id)) {
      return;
    }
    events.insert(0, event);
    if (events.length > maxEventFeed) {
      final removed = events.length - maxEventFeed;
      events.removeRange(maxEventFeed, events.length);
      feedOverflowCount += removed;
      if (feedOverflowCount == removed || feedOverflowCount % 25 < removed) {
        _appendLog(
          LogLevel.warn,
          'Feed capped at $maxEventFeed events; '
          '$feedOverflowCount event(s) evicted.',
        );
      }
    }
    selectedEvent ??= event;
    if (waitingForFirstEvent) {
      waitingForFirstEvent = false;
      _emptyTimer?.cancel();
    }
    _appendLog(
      LogLevel.event,
      'Received kind ${event.kind} event ${shortId(event.id)}.',
    );
    _refreshLiveRelays();
    _notify();
  }

  void _onSubscriptionError(Object error) {
    subscriptionActive = false;
    waitingForFirstEvent = false;
    _emptyTimer?.cancel();
    _setError('Subscription error: $error');
  }

  void _onSubscriptionDone() {
    subscriptionActive = false;
    waitingForFirstEvent = false;
    _emptyTimer?.cancel();
    _appendLog(LogLevel.info, 'Subscription ended by the relay.');
    _notify();
  }

  Future<void> _releaseSession(PlaygroundNostrSession? session) async {
    if (session == null) {
      return;
    }
    try {
      await session.teardown();
    } catch (_) {
      // Best-effort teardown; the generation guard keeps stale state out.
    }
  }

  void _refreshLiveRelays() {
    try {
      liveRelays = List.unmodifiable(_session?.liveRelayUrls ?? const []);
    } catch (_) {
      liveRelays = const [];
    }
  }

  void _clearEphemeralState() {
    _keyPair = null;
    signedEvent = null;
    selectedEvent = null;
  }

  void _setError(String message) {
    error = message;
    _appendLog(LogLevel.error, message);
    _notify();
  }

  void _appendLog(LogLevel level, String message) {
    logs.insert(
      0,
      LogEntry(at: DateTime.now(), level: level, message: message),
    );
    if (logs.length > maxLogEntries) {
      logs.removeRange(maxLogEntries, logs.length);
    }
  }

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _sessionGeneration++;
    _emptyTimer?.cancel();
    _emptyTimer = null;

    final listener = _subscriptionListener;
    _subscriptionListener = null;
    if (listener != null) {
      unawaited(listener.cancel());
    }
    final stream = _subscription;
    _subscription = null;
    if (stream != null) {
      try {
        stream.close();
      } catch (_) {
        // Best effort.
      }
    }

    final pending = _pendingSession;
    final active = _session;
    _pendingSession = null;
    _session = null;
    _clearEphemeralState();
    _authenticityCache.clear();
    unawaited(_releaseSession(pending));
    unawaited(_releaseSession(active));

    status = PlaygroundSessionStatus.disconnected;
    super.dispose();
  }
}
