import 'dart:io';

import 'package:dart_nostr/dart_nostr.dart';
import 'package:dart_nostr/nostr/instance/relays/relays.dart';
import 'package:test/test.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../fake_relay_server.dart';

class _ThrowingDisconnectRelays extends NostrRelays {
  _ThrowingDisconnectRelays({required super.logger});

  @override
  Future<bool> disconnectFromRelays({
    int Function(String relayUrl)? closeCode,
    String Function(String relayUrl)? closeReason,
    void Function(
      String relayUrl,
      WebSocketChannel relayWebSocket,
      dynamic webSocketDisconnectionMessage,
    )? onRelayDisconnect,
  }) async {
    throw StateError('close failed');
  }
}

void main() {
  group('relay lifecycle cancellation', () {
    test('disconnect during reconnect backoff leaves no live socket', () async {
      final server = FakeRelayServer();
      await server.start();
      final relays = Nostr().services.relays;

      try {
        await relays.init(
          relaysUrl: [server.url],
          retryOnClose: true,
          retryOnError: true,
          connectionTimeout: const Duration(seconds: 2),
        );
        expect(relays.connectedRelayUrls, contains(server.url));

        // Trigger the onDone reconnect path, then disconnect while it is in
        // its exponential-backoff delay.
        final client = await server.nextClient();
        await client.close();
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await relays.disconnectFromRelays();
        await Future<void>.delayed(const Duration(milliseconds: 1800));

        expect(relays.connectedRelayUrls, isEmpty);
        expect(relays.relaysWebSocketsRegistry, isEmpty);
      } finally {
        await relays.freeAllResources();
        await server.stop();
      }
    });

    test('freeAllResources during backoff leaves no live socket', () async {
      final server = FakeRelayServer();
      await server.start();
      final relays = Nostr().services.relays;

      try {
        await relays.init(
          relaysUrl: [server.url],
          retryOnClose: true,
          retryOnError: true,
          connectionTimeout: const Duration(seconds: 2),
        );
        final client = await server.nextClient();
        await client.close();
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await relays.freeAllResources();
        await Future<void>.delayed(const Duration(milliseconds: 1800));

        expect(relays.connectedRelayUrls, isEmpty);
        expect(relays.relaysWebSocketsRegistry, isEmpty);
      } finally {
        await relays.freeAllResources();
        await server.stop();
      }
    });

    test('single-relay disconnect cancels its scheduled reconnect', () async {
      final server = FakeRelayServer();
      await server.start();
      final relays = Nostr().services.relays;

      try {
        await relays.init(
          relaysUrl: [server.url],
          retryOnClose: true,
          retryOnError: true,
          connectionTimeout: const Duration(seconds: 2),
        );
        final client = await server.nextClient();
        await client.close();
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await relays.disconnectFromRelay(server.url);
        await Future<void>.delayed(const Duration(milliseconds: 1800));

        expect(relays.connectedRelayUrls, isEmpty);
        expect(relays.relaysWebSocketsRegistry, isEmpty);
      } finally {
        await relays.freeAllResources();
        await server.stop();
      }
    });

    test(
      'disconnect during an in-flight handshake never registers the socket',
      () async {
        final sockets = <WebSocket>[];
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        server.listen((request) async {
          // Hold the upgrade so a disconnect can happen mid-handshake.
          await Future<void>.delayed(const Duration(milliseconds: 300));
          try {
            final socket = await WebSocketTransformer.upgrade(request);
            sockets.add(socket);
            socket.listen(
              (_) {},
              onError: (_) {},
              onDone: () => sockets.remove(socket),
            );
          } catch (_) {
            // The client may already be gone; that is the expected outcome.
          }
        });
        final relays = Nostr().services.relays;
        final relayUrl = 'ws://127.0.0.1:${server.port}';

        try {
          final initFuture = relays.init(
            relaysUrl: [relayUrl],
            retryOnClose: true,
            retryOnError: true,
            connectionTimeout: const Duration(seconds: 2),
          );
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await relays.disconnectFromRelays();
          await initFuture;
          await Future<void>.delayed(const Duration(milliseconds: 500));

          expect(relays.relaysWebSocketsRegistry, isEmpty);
          expect(relays.connectedRelayUrls, isEmpty);
        } finally {
          await relays.freeAllResources();
          for (final socket in List.of(sockets)) {
            await socket.close();
          }
          await server.close(force: true);
        }
      },
    );

    test(
      'legitimate reconnect still happens after an unexpected close',
      () async {
        final server = FakeRelayServer();
        await server.start();
        final relays = Nostr().services.relays;

        try {
          await relays.init(
            relaysUrl: [server.url],
            retryOnClose: true,
            retryOnError: true,
            connectionTimeout: const Duration(seconds: 2),
          );
          expect(server.connectionCount, 1);

          final nextConnection = server.waitForNewConnection(
            timeout: const Duration(seconds: 4),
          );
          final first = await server.nextClient();
          await first.close();
          await nextConnection;
          await Future<void>.delayed(const Duration(milliseconds: 100));

          expect(server.connectionCount, 2);
          expect(relays.connectedRelayUrls, contains(server.url));
        } finally {
          await relays.freeAllResources();
          await server.stop();
        }
      },
    );

    test(
      'explicit disconnect closes the server-side socket and does not revive',
      () async {
        final server = FakeRelayServer();
        await server.start();
        final relays = Nostr().services.relays;

        try {
          await relays.init(
            relaysUrl: [server.url],
            retryOnClose: true,
            retryOnError: true,
            connectionTimeout: const Duration(seconds: 2),
          );
          final socket = await server.nextClient();

          final socketClosed = server.waitForClosed(
            socket,
            timeout: const Duration(seconds: 2),
          );
          await relays.disconnectFromRelays();
          await socketClosed;
          await Future<void>.delayed(const Duration(milliseconds: 1200));

          expect(relays.relaysWebSocketsRegistry, isEmpty);
          expect(relays.connectedRelayUrls, isEmpty);
          expect(server.connectionCount, 1);
          expect(server.closedConnectionCount, greaterThanOrEqualTo(1));
        } finally {
          await relays.freeAllResources();
          await server.stop();
        }
      },
    );

    test(
      'NOTICE reconnect happens once even with retryOnClose enabled',
      () async {
        final server = FakeRelayServer(
          upgradeDelay: const Duration(milliseconds: 1500),
        );
        await server.start();
        final relays = Nostr().services.relays;

        try {
          await relays.init(
            relaysUrl: [server.url],
            retryOnClose: true,
            retryOnError: true,
            shouldReconnectToRelayOnNotice: true,
            connectionTimeout: const Duration(seconds: 5),
          );
          expect(server.connectionCount, 1);

          final nextConnection = server.waitForNewConnection(
            timeout: const Duration(seconds: 8),
          );
          server.sendNotice('reconnect once');
          await nextConnection;

          // Give a would-be second reconnect time to complete as well.
          await Future<void>.delayed(const Duration(seconds: 3));

          expect(server.connectionCount, 2);
          expect(relays.connectedRelayUrls, contains(server.url));
        } finally {
          await relays.freeAllResources();
          await server.stop();
        }
      },
    );

    test(
      'bulk disconnect closes every socket then rethrows the first error',
      () async {
        final firstServer = FakeRelayServer();
        final secondServer = FakeRelayServer();
        await firstServer.start();
        await secondServer.start();
        final relays = Nostr().services.relays;

        try {
          await relays.init(
            relaysUrl: [firstServer.url, secondServer.url],
            retryOnClose: true,
            retryOnError: true,
            connectionTimeout: const Duration(seconds: 2),
          );
          final firstSocket = await firstServer.nextClient();
          final secondSocket = await secondServer.nextClient();
          final firstClosed = firstServer.waitForClosed(
            firstSocket,
            timeout: const Duration(seconds: 2),
          );
          final secondClosed = secondServer.waitForClosed(
            secondSocket,
            timeout: const Duration(seconds: 2),
          );

          await expectLater(
            relays.disconnectFromRelays(
              onRelayDisconnect: (relay, socket, message) {
                throw StateError('disconnect callback failed');
              },
            ),
            throwsA(isA<StateError>()),
          );

          await Future.wait([firstClosed, secondClosed]);
          expect(relays.relaysWebSocketsRegistry, isEmpty);
          expect(relays.connectedRelayUrls, isEmpty);
          expect(firstServer.closedConnectionCount, greaterThanOrEqualTo(1));
          expect(secondServer.closedConnectionCount, greaterThanOrEqualTo(1));
        } finally {
          await relays.freeAllResources();
          await firstServer.stop();
          await secondServer.stop();
        }
      },
    );

    test('freeAllResources preserves false/throw failure semantics', () async {
      final logger = Nostr().services.logger;
      final relays = _ThrowingDisconnectRelays(logger: logger);
      addTearDown(relays.freeAllResources);

      expect(await relays.freeAllResources(), isFalse);
      await expectLater(
        relays.freeAllResources(true),
        throwsA(isA<StateError>()),
      );
    });
  });
}
