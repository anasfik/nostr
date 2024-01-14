import 'dart:io';

import 'package:dart_nostr/nostr/core/utils.dart';

/// {@template nostr_web_sockets_service}
/// A service that manages the relays web sockets connections
/// {@endtemplate}
class NostrWebSocketsService {

  /// {@macro nostr_web_sockets_service}
  NostrWebSocketsService({
    required this.utils,
  });
  final NostrClientUtils utils;

  /// The connection timeout for the web sockets.
  Duration _connectionTimeout = const Duration(seconds: 5);

  void set(Duration newDur) {
    _connectionTimeout = newDur;
  }

  /// THe custom http client that will be used to connect to the relay.
  HttpClient? _client;

  /// Connects to a [relay] web socket, and trigger the [onConnectionSuccess] callback if the connection is successful, or the [onConnectionError] callback if the connection fails.
  Future<void> connectRelay({
    required String relay,
    HttpClient? customHttpClient,
    bool? shouldIgnoreConnectionException,
    void Function(WebSocket webSocket)? onConnectionSuccess,
  }) async {
    _client ??= _createCustomHttpClient();
    WebSocket? webSocket;

    try {
      webSocket = await WebSocket.connect(
        relay,
        compression: CompressionOptions.compressionOff,
        customClient: customHttpClient ?? _client!,
      );

      onConnectionSuccess?.call(webSocket);
    } catch (e) {
      utils.log(
        'error while connecting to the relay with url: $relay',
        e,
      );

      if (shouldIgnoreConnectionException ?? true) {
        utils.log(
          'The error related to relay: $relay is ignored, because to the ignoreConnectionException parameter is set to true.',
        );
      } else {
        rethrow;
      }
    }
  }

  /// Changes the protocol of a websocket url to http.
  Uri getHttpUrlFromWebSocketUrl(String relayUrl) {
    assert(
      relayUrl.startsWith('ws://') || relayUrl.startsWith('wss://'),
      'invalid relay url',
    );

    try {
      var removeWebsocketSign = relayUrl.replaceFirst('ws://', 'http://');
      removeWebsocketSign =
          removeWebsocketSign.replaceFirst('wss://', 'https://');
      return Uri.parse(removeWebsocketSign);
    } catch (e) {
      utils.log(
        'error while getting http url from websocket url: $relayUrl',
        e,
      );

      rethrow;
    }
  }

  /// Creates a custom http client.
  HttpClient _createCustomHttpClient() {
    final client = HttpClient();
    client.badCertificateCallback =
        (X509Certificate cert, String host, int port) => true;
    client.connectionTimeout = _connectionTimeout;

    return client;
  }
}
