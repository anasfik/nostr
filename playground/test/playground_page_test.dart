import 'dart:async';

import 'package:dart_nostr/dart_nostr.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_playground/main.dart';
import 'package:nostr_playground/src/nostr_tools.dart';
import 'package:nostr_playground/src/playground_controller.dart';
import 'package:nostr_playground/src/playground_page.dart';

class _HangingSession implements PlaygroundNostrSession {
  final connectCompleter = Completer<NostrResult<void>>();
  bool tornDown = false;

  @override
  Future<NostrResult<void>> connect(List<String> relays) =>
      connectCompleter.future;

  @override
  Future<NostrResult<NostrEventOkCommand>> publish(NostrEvent event) {
    throw UnimplementedError();
  }

  @override
  NostrResult<NostrEventsStream> subscribe(NostrFilter filter) {
    throw UnimplementedError();
  }

  @override
  List<String> get liveRelayUrls => const [];

  @override
  Future<void> teardown() async {
    tornDown = true;
  }
}

void main() {
  Future<void> pumpApp(
    WidgetTester tester, {
    Size size = const Size(1400, 900),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const NostrPlaygroundApp());
    await tester.pump();
  }

  testWidgets('opens disconnected and does not auto-connect', (tester) async {
    await pumpApp(tester);
    expect(find.textContaining('Not connected'), findsWidgets);
    expect(find.byKey(const Key('desktop-console')), findsOneWidget);
  });

  testWidgets('shows a visible error for a non-wss relay', (tester) async {
    await pumpApp(tester);
    await tester.enterText(
      find.byKey(const Key('relay-input')),
      'https://relay.example',
    );
    await tester.tap(find.byKey(const Key('connect-button')));
    await tester.pump();

    expect(find.textContaining('wss://'), findsWidgets);
    expect(find.textContaining('Not connected'), findsWidgets);
  });

  testWidgets('generates keys and inspects a locally signed event', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.ensureVisible(find.byKey(const Key('generate-key-button')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('generate-key-button')));
    await tester.pump();
    expect(find.textContaining('npub1'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('content-input')),
      'widget signed note',
    );
    await tester.ensureVisible(find.byKey(const Key('sign-button')));
    await tester.tap(find.byKey(const Key('sign-button')));
    await tester.pump();

    expect(find.text('Signature valid'), findsOneWidget);
    expect(find.textContaining('widget signed note'), findsWidgets);
    expect(find.byKey(const Key('event-json')), findsOneWidget);
    final publishButton = tester.widget<FilledButton>(
      find.byKey(const Key('publish-button')),
    );
    expect(publishButton.onPressed, isNull);
  });

  testWidgets('mobile layout is usable and has no overflow', (tester) async {
    await pumpApp(tester, size: const Size(420, 900));

    expect(find.byKey(const Key('mobile-console')), findsOneWidget);
    expect(find.byKey(const Key('desktop-console')), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Events'));
    await tester.pumpAndSettle();
    expect(find.textContaining('No events yet'), findsOneWidget);
  });

  testWidgets('connect can be cancelled from the UI', (tester) async {
    final session = _HangingSession();
    final controller = PlaygroundController(
      sessionFactory: () => session,
      connectTimeout: const Duration(minutes: 1),
    );
    addTearDown(controller.dispose);

    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(home: PlaygroundPage(controller: controller)),
    );

    await tester.ensureVisible(find.byKey(const Key('generate-key-button')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('generate-key-button')));
    await tester.pump();
    expect(controller.hasKey, isTrue);

    await tester.enterText(
      find.byKey(const Key('relay-input')),
      'wss://relay.example',
    );
    await tester.ensureVisible(find.byKey(const Key('connect-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('connect-button')));
    await tester.pump();
    expect(find.text('Cancel'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('disconnect-button')));
    await tester.tap(find.byKey(const Key('disconnect-button')));
    await tester.pump();
    session.connectCompleter.complete(const NostrSuccess<void>(null));
    await tester.pumpAndSettle();

    expect(controller.status, PlaygroundSessionStatus.disconnected);
    expect(session.tornDown, isTrue);
    expect(controller.hasKey, isTrue);
  });

  testWidgets('publish dialog requires an explicit confirmation', (
    tester,
  ) async {
    final event = signLocalEvent(
      keys: NostrKeyPairs.generate(),
      kind: 1,
      content: 'confirm me',
      tags: const [],
    );
    final result = ValueNotifier<String>('none');
    addTearDown(result.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Column(
              children: [
                ValueListenableBuilder<String>(
                  valueListenable: result,
                  builder: (context, value, _) => Text(value),
                ),
                TextButton(
                  onPressed: () async {
                    result.value =
                        'result:${await showPublishConfirmation(context, event: event, relays: const ['wss://relay.example'])}';
                  },
                  child: const Text('open'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.textContaining('publicly'), findsWidgets);
    expect(find.textContaining('cannot be deleted everywhere'), findsOneWidget);
    expect(
      find.textContaining('Only the first relay response'),
      findsOneWidget,
    );

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('result:false'), findsOneWidget);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Publish publicly'));
    await tester.pumpAndSettle();
    expect(find.text('result:true'), findsOneWidget);
  });
}
