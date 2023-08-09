import 'dart:io';

import '../core/utils.dart';

final class NostrWebSocketsService {
  static final _instance = NostrWebSocketsService._();
  static NostrWebSocketsService get instance => _instance;

  Duration _connectionTimeout = Duration(seconds: 5);

  NostrWebSocketsService._();

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
      NostrClientUtils.log(
        "error while connecting to the relay with url: $relay",
        e,
      );

      if (shouldIgnoreConnectionException ?? true) {
        NostrClientUtils.log(
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
      NostrClientUtils.log(
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
