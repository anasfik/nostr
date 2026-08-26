import 'dart:async';

import 'package:dart_nostr/nostr/core/utils.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// {@template nostr_web_sockets_service}
/// A service that manages the relays web sockets connections
/// {@endtemplate}
class NostrWebSocketsService {
  /// {@macro nostr_web_sockets_service}
  NostrWebSocketsService({
    required this.logger,
  });
  final NostrLogger logger;

  /// The connection timeout for the web sockets.
  Duration _connectionTimeout = const Duration(seconds: 5);

  void set(Duration newDur) {
    _connectionTimeout = newDur;
  }

  /// Connects to a [relay] web socket, and trigger the [onConnectionSuccess] callback if the connection is successful, or the [onConnectionError] callback if the connection fails.
  ///
  /// If [connectTimeout] is provided, the connection attempt will be aborted
  /// after the specified duration. If not provided, falls back to the default
  /// [_connectionTimeout] (5 seconds). This prevents a single unreachable relay
  /// from blocking the entire connection process indefinitely.
  ///
  /// Uses the platform-independent [WebSocketChannel.connect] factory so this
  /// works on VM, Flutter Web and WASM targets alike.
  Future<void> connectRelay({
    required String relay,
    Duration? connectTimeout,
    bool? shouldIgnoreConnectionException,
    Duration? connectionTimeout,
    void Function(WebSocketChannel webSocket)? onConnectionSuccess,
  }) async {
    WebSocketChannel? webSocket;

    try {
      webSocket = WebSocketChannel.connect(
        Uri.parse(relay),
      );

      final effectiveTimeout =
          connectionTimeout ?? connectTimeout ?? _connectionTimeout;

      try {
        await webSocket.ready.timeout(effectiveTimeout);
      } on TimeoutException {
        // The handshake timed out; make sure we do not leak a half-open
        // socket underneath us.
        await _closeQuietly(webSocket);
        rethrow;
      }

      onConnectionSuccess?.call(webSocket);
    } catch (e) {
      logger.log(
        'error while connecting to the relay with url: $relay',
        e,
      );

      if (shouldIgnoreConnectionException ?? true) {
        logger.log(
          'The error related to relay: $relay is ignored, because to the ignoreConnectionException parameter is set to true.',
        );
      } else {
        rethrow;
      }
    }
  }

  Future<void> _closeQuietly(WebSocketChannel? webSocket) async {
    if (webSocket == null) {
      return;
    }

    try {
      await webSocket.sink.close().timeout(
            const Duration(seconds: 2),
            onTimeout: () {},
          );
    } catch (_) {
      // Best-effort close; the original error matters more than this one.
    }
  }

  /// Changes the protocol of a websocket url to http.
  Uri getHttpUrlFromWebSocketUrl(String relayUrl) {
    final normalized = relayUrl.trim();

    if (!normalized.startsWith('ws://') && !normalized.startsWith('wss://')) {
      throw ArgumentError.value(
        relayUrl,
        'relayUrl',
        'invalid relay url, expected ws:// or wss:// scheme',
      );
    }

    try {
      var removeWebsocketSign = normalized.replaceFirst('ws://', 'http://');
      removeWebsocketSign =
          removeWebsocketSign.replaceFirst('wss://', 'https://');
      return Uri.parse(removeWebsocketSign);
    } catch (e) {
      logger.log(
        'error while getting http url from websocket url: $relayUrl',
        e,
      );

      rethrow;
    }
  }

  /// Creates a custom http client.
  // HttpClient _createCustomHttpClient() {
  //   final client = HttpClient();
  //   client.badCertificateCallback =
  //       (X509Certificate cert, String host, int port) => true;
  //   client.connectionTimeout = _connectionTimeout;

  //   return client;
  // }
}
