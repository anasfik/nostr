import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// A minimal in-process Nostr relay for integration tests.
///
/// Serves a WebSocket endpoint on `ws://localhost:<port>` and exposes hooks
/// to script relay behavior: echoing events, sending EOSE, OK, NOTICE,
/// CLOSED and AUTH messages on demand.
class FakeRelayServer {
  FakeRelayServer({this.autoOk = true, this.requireAuth = false});

  /// Whether the relay automatically answers every EVENT with an OK message.
  final bool autoOk;

  /// Whether the relay requires NIP-42 authentication before accepting
  /// publishes (sends an AUTH challenge on connect).
  final bool requireAuth;

  HttpServer? _server;
  final List<WebSocket> _sockets = [];
  final _receivedMessages = <dynamic>[];
  final _receivedController = StreamController<dynamic>.broadcast();
  final _clientsConnected = StreamController<WebSocket>.broadcast();
  bool _stopped = false;

  int get port => _server!.port;
  String get url => 'ws://localhost:$port';

  /// Every message received from any client, in order.
  List<dynamic> get receivedMessages => _receivedMessages;
  Stream<dynamic> get receivedStream => _receivedController.stream;

  Future<void> start() async {
    _server = await HttpServer.bind('localhost', 0);
    _server!.transform(WebSocketTransformer()).listen((socket) {
      _sockets.add(socket);
      _clientsConnected.add(socket);

      if (requireAuth) {
        // NIP-42 challenge: ["AUTH", <challenge-string>]
        socket.add(jsonEncode([
          'AUTH',
          'test-challenge-${DateTime.now().millisecondsSinceEpoch}'
        ]));
      }

      socket.listen(
        (data) {
          if (_stopped) {
            return;
          }
          _receivedMessages.add(data);
          _receivedController.add(data);

          // Sends can fail if the test already tore the server down while
          // the client is still flushing messages; ignore those.
          void safeSend(String message) {
            if (socket.readyState != WebSocket.open) {
              return;
            }
            try {
              socket.add(message);
            } catch (_) {}
          }

          try {
            final decoded = jsonDecode(data as String) as List;
            if (decoded.isNotEmpty && decoded.first == 'EVENT') {
              // Client->relay EVENT messages carry the event at index 1
              // (no subscription id), per NIP-01.
              final eventMap = decoded.length > 2 ? decoded[2] : decoded[1];
              if (requireAuth) {
                safeSend(jsonEncode([
                  'OK',
                  eventMap['id'],
                  false,
                  'auth-required: please authenticate first',
                ]));
                return;
              }
              if (autoOk) {
                safeSend(jsonEncode([
                  'OK',
                  eventMap['id'],
                  true,
                  '',
                ]));
              }
            }
            if (decoded.isNotEmpty && decoded.first == 'REQ') {
              safeSend(
                jsonEncode(['EOSE', decoded[1]]),
              );
            }
            if (decoded.isNotEmpty && decoded.first == 'AUTH') {
              // Client->relay AUTH carries the event at index 1; reply with
              // its id per NIP-42.
              safeSend(
                jsonEncode(['OK', (decoded[1] as Map)['id'], true, '']),
              );
            }
          } catch (_) {
            // Non-JSON or malformed; tests can assert on raw data.
          }
        },
        onError: (_) {},
        onDone: () {
          _sockets.remove(socket);
        },
      );
    });
  }

  /// Sends a raw string to all connected clients.
  void broadcast(String data) {
    for (final socket in List.of(_sockets)) {
      socket.add(data);
    }
  }

  /// Sends `["EVENT", subId, eventJson]` to all connected clients.
  void sendEventToClients(String subscriptionId, Map<String, dynamic> event) {
    broadcast(jsonEncode(['EVENT', subscriptionId, event]));
  }

  /// Sends `["CLOSED", subId, reason]` to all connected clients.
  void sendClosed(String subscriptionId, String reason) {
    broadcast(jsonEncode(['CLOSED', subscriptionId, reason]));
  }

  /// Sends `["NOTICE", message]` to all connected clients.
  void sendNotice(String message) {
    broadcast(jsonEncode(['NOTICE', message]));
  }

  /// Waits until the next client connects, returning its socket.
  Future<WebSocket> nextClient() async {
    if (_sockets.isNotEmpty) {
      return _sockets.last;
    }
    return _clientsConnected.stream.first;
  }

  /// Waits until a message matching [test] arrives from a client.
  Future<dynamic> waitForMessage(bool Function(dynamic message) test,
      {Duration timeout = const Duration(seconds: 5)}) async {
    final existing = _receivedMessages.where(test);
    if (existing.isNotEmpty) {
      return existing.first;
    }

    await for (final message in receivedStream) {
      if (test(message)) {
        return message;
      }
    }

    throw TimeoutException('message not received in time', timeout);
  }

  Future<void> stop() async {
    _stopped = true;
    for (final socket in _sockets) {
      await socket.close();
    }
    _sockets.clear();
    await _receivedController.close();
    await _clientsConnected.close();
    await _server?.close(force: true);
  }
}
