import 'dart:io';

import '../core/utils.dart';

class NostrWebSocketsService {
  final NostrClientUtils utils;

  NostrWebSocketsService({
    required this.utils,
  });

  Duration _connectionTimeout = Duration(seconds: 5);

  void set(Duration newDur) {
    _connectionTimeout = newDur;
  }

  HttpClient? _client;

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
        "error while connecting to the relay with url: $relay",
        e,
      );

      if (shouldIgnoreConnectionException ?? true) {
        utils.log(
          "The error related to relay: $relay is ignored, because to the ignoreConnectionException parameter is set to true.",
        );
      } else {
        rethrow;
      }
    }
  }

  Uri getHttpUrlFromWebSocketUrl(String relayUrl) {
    assert(
      relayUrl.startsWith("ws://") || relayUrl.startsWith("wss://"),
      "invalid relay url",
    );

    try {
      String removeWebsocketSign = relayUrl.replaceFirst("ws://", "http://");
      removeWebsocketSign =
          removeWebsocketSign.replaceFirst("wss://", "https://");
      return Uri.parse(removeWebsocketSign);
    } catch (e) {
      utils.log(
        "error while getting http url from websocket url: $relayUrl",
        e,
      );

      rethrow;
    }
  }

  HttpClient _createCustomHttpClient() {
    HttpClient client = HttpClient();
    client.badCertificateCallback =
        ((X509Certificate cert, String host, int port) => true);
    client.connectionTimeout = _connectionTimeout;

    return client;
  }
}
