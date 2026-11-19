import 'dart:async';
import 'dart:ui' show Tristate;

import 'package:dart_nostr/dart_nostr.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_playground/main.dart';
import 'package:nostr_playground/src/nostr_tools.dart';
import 'package:nostr_playground/src/playground_controller.dart';
import 'package:nostr_playground/src/playground_page.dart';
import 'package:nostr_playground/src/playground_theme.dart';

class _TestSession implements PlaygroundNostrSession {
  final connectCompleter = Completer<NostrResult<void>>();
  final publishCompleter = Completer<NostrResult<NostrEventOkCommand>>();
  final events = StreamController<NostrEvent>.broadcast();
  List<String> requestedRelays = const [];
  List<String> live = const [];
  int publishCalls = 0;

  @override
  Future<NostrResult<void>> connect(List<String> relays) {
    requestedRelays = relays;
    return connectCompleter.future;
  }

  @override
  Future<NostrResult<NostrEventOkCommand>> publish(NostrEvent event) {
    publishCalls++;
    return publishCompleter.future;
  }

  @override
  NostrResult<NostrEventsStream> subscribe(NostrFilter filter) => NostrSuccess(
    NostrEventsStream(
      stream: events.stream,
      subscriptionId: 'sub-test',
      request: NostrRequest(filters: [filter]),
    ),
  );

  @override
  List<String> get liveRelayUrls => live;

  @override
  Future<void> teardown() async {
    if (!events.isClosed) {
      await events.close();
    }
  }
}

void main() {
  Future<void> pumpPage(
    WidgetTester tester,
    PlaygroundController controller, {
    Size size = const Size(1280, 900),
    double textScale = 1,
    Brightness brightness = Brightness.light,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildPlaygroundTheme(brightness),
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: PlaygroundPage(controller: controller),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> pumpApp(
    WidgetTester tester, {
    Size size = const Size(1280, 900),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const NostrPlaygroundApp());
    await tester.pump();
  }

  Future<(_TestSession, PlaygroundController)> connectedController({
    List<String> live = const ['wss://relay.example'],
  }) async {
    final session = _TestSession();
    final controller = PlaygroundController(sessionFactory: () => session);
    addTearDown(controller.dispose);
    final connecting = controller.connect('wss://relay.example');
    session.live = live;
    session.connectCompleter.complete(const NostrSuccess<void>(null));
    await connecting;
    return (session, controller);
  }

  Future<void> openTab(WidgetTester tester, String label) async {
    await tester.tap(
      find.descendant(of: find.byType(TabBar), matching: find.text(label)),
    );
    await tester.pumpAndSettle();
  }

  String liveLabel(WidgetTester tester) =>
      tester.getSemantics(find.byKey(const Key('live-announcements'))).label;

  bool focusedWithin(WidgetTester tester, Finder finder) {
    final focusContext = FocusManager.instance.primaryFocus?.context;
    if (focusContext == null || finder.evaluate().isEmpty) {
      return false;
    }
    final target = tester.element(finder);
    var found = false;
    (focusContext as Element).visitAncestorElements((ancestor) {
      if (identical(ancestor, target)) {
        found = true;
        return false;
      }
      return true;
    });
    return found;
  }

  Border rowBorder(WidgetTester tester, String id) {
    final container = tester.widget<Container>(
      find.byKey(Key('event-row-surface-$id')),
    );
    return (container.decoration! as BoxDecoration).border! as Border;
  }

  testWidgets('relay presets fill the input without creating a session', (
    tester,
  ) async {
    var factories = 0;
    final controller = PlaygroundController(
      sessionFactory: () {
        factories++;
        return _TestSession();
      },
    );
    addTearDown(controller.dispose);
    await pumpPage(tester, controller);

    final input = find.byKey(const Key('relay-input'));
    expect(tester.widget<TextField>(input).controller!.text, isEmpty);

    for (final preset in relayPresets) {
      await tester.ensureVisible(find.text(preset.name));
      await tester.tap(find.text(preset.name));
      await tester.pump();
      expect(tester.widget<TextField>(input).controller!.text, preset.url);
      expect(controller.status, PlaygroundSessionStatus.disconnected);
    }

    expect(factories, 0);
    expect(
      find.textContaining('Nothing connects until you press Connect'),
      findsOneWidget,
    );
    expect(find.textContaining('try another preset'), findsWidgets);
    expect(find.textContaining('replace the relay field'), findsOneWidget);
  });

  testWidgets('publish explains the missing live relay and rejects it', (
    tester,
  ) async {
    final (session, controller) = await connectedController(live: const []);
    controller.generateKeyPair();
    controller.signEvent(kind: '1', content: 'ready but relayless', tags: '[]');
    await pumpPage(tester, controller);

    final button = tester.widget<FilledButton>(
      find.byKey(const Key('publish-button')),
    );
    expect(button.onPressed, isNull);
    expect(find.textContaining('No relay is live'), findsOneWidget);
    expect(find.textContaining('try another preset'), findsWidgets);

    await controller.publishSignedEvent(confirmed: true);
    await tester.pump();

    expect(session.publishCalls, 0);
    expect(controller.error, contains('live relay'));
  });

  testWidgets('mobile events open a full inspector and return to the list', (
    tester,
  ) async {
    final (session, controller) = await connectedController();
    controller.subscribe(kinds: '1', authors: '', limit: '20');
    final event = signLocalEvent(
      keys: NostrKeyPairs.generate(),
      kind: 1,
      content: 'mobile row note',
      tags: const [],
    );
    session.events.add(event);
    await tester.pump();
    await pumpPage(tester, controller, size: const Size(1024, 900));

    await openTab(tester, 'Events');
    final row = find.byKey(Key('event-row-${event.id}'));
    expect(row, findsOneWidget);
    expect(find.byKey(const Key('event-json')), findsNothing);

    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('event-json')), findsOneWidget);
    expect(find.text('Back to events'), findsOneWidget);
    expect(find.textContaining('mobile row note'), findsWidgets);

    await tester.tap(find.byKey(const Key('back-to-events-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('event-json')), findsNothing);
    expect(row, findsOneWidget);
  });

  testWidgets('mobile offers inspection for a locally signed event', (
    tester,
  ) async {
    final controller = PlaygroundController(sessionFactory: _TestSession.new);
    addTearDown(controller.dispose);
    controller.generateKeyPair();
    controller.signEvent(kind: '1', content: 'local inspect only', tags: '[]');
    await pumpPage(tester, controller, size: const Size(1024, 900));

    await openTab(tester, 'Events');
    expect(
      find.byKey(const Key('inspect-signed-event-button')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('inspect-signed-event-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('event-json')), findsOneWidget);
    expect(find.textContaining('local inspect only'), findsWidgets);
    expect(find.byKey(const Key('back-to-events-button')), findsOneWidget);
    await tester.tap(find.byKey(const Key('back-to-events-button')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('inspect-signed-event-button')),
      findsOneWidget,
    );
  });

  testWidgets('event rows expose button, selected and authenticity semantics', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final (session, controller) = await connectedController();
    controller.subscribe(kinds: '1', authors: '', limit: '20');
    final event = signLocalEvent(
      keys: NostrKeyPairs.generate(),
      kind: 1,
      content: 'a' * 400,
      tags: const [],
    );
    session.events.add(event);
    await tester.pump();
    await pumpPage(tester, controller, size: const Size(1024, 900));
    await openTab(tester, 'Events');

    final node = tester.getSemantics(find.byKey(Key('event-row-${event.id}')));
    final flags = node.getSemanticsData().flagsCollection;
    expect(flags.isButton, isTrue);
    expect(flags.isSelected, Tristate.isTrue);
    expect(flags.isLiveRegion, isFalse);
    expect(node.label, contains('Signature valid'));
    expect(node.label, contains('kind 1'));
    expect(node.label.length, lessThanOrEqualTo(220));
    handle.dispose();
  });

  testWidgets('event rows show a focused ring and activate with Enter', (
    tester,
  ) async {
    final (session, controller) = await connectedController();
    controller.subscribe(kinds: '1', authors: '', limit: '20');
    final keys = NostrKeyPairs.generate();
    final first = signLocalEvent(
      keys: keys,
      kind: 1,
      content: 'first focus row',
      tags: const [],
      createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
    );
    final second = signLocalEvent(
      keys: keys,
      kind: 1,
      content: 'second focus row',
      tags: const [],
      createdAt: DateTime.fromMillisecondsSinceEpoch(1700000001000),
    );
    session.events.add(first);
    await tester.pump();
    session.events.add(second);
    await tester.pump();
    await pumpPage(tester, controller, size: const Size(1280, 900));

    expect(controller.selectedEvent?.id, first.id);
    final row = find.byKey(Key('event-row-${second.id}'));
    final ink = tester.widget<InkWell>(
      find.descendant(of: row, matching: find.byType(InkWell)),
    );
    ink.focusNode!.requestFocus();
    await tester.pumpAndSettle();

    final surface = tester.widget<Container>(
      find.byKey(Key('event-row-surface-${second.id}')),
    );
    final border = (surface.decoration! as BoxDecoration).border! as Border;
    for (final side in [border.top, border.left, border.right, border.bottom]) {
      expect(side.width, 3);
      expect(side.color, playgroundLightColors.accent);
    }

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(controller.selectedEvent?.id, second.id);
  });

  testWidgets('focused row keeps its identity when a newer event prepends', (
    tester,
  ) async {
    final (session, controller) = await connectedController();
    controller.subscribe(kinds: '1', authors: '', limit: '20');
    final keys = NostrKeyPairs.generate();
    final existing = signLocalEvent(
      keys: keys,
      kind: 1,
      content: 'existing focused row',
      tags: const [],
      createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
    );
    session.events.add(existing);
    await tester.pump();
    await pumpPage(tester, controller, size: const Size(1280, 900));

    final row = find.byKey(Key('event-row-${existing.id}'));
    final ink = tester.widget<InkWell>(
      find.descendant(of: row, matching: find.byType(InkWell)),
    );
    ink.focusNode!.requestFocus();
    await tester.pumpAndSettle();
    expect(rowBorder(tester, existing.id!).top.width, 3);

    final incoming = signLocalEvent(
      keys: keys,
      kind: 1,
      content: 'newly arrived row',
      tags: const [],
      createdAt: DateTime.fromMillisecondsSinceEpoch(1700000001000),
    );
    session.events.add(incoming);
    await tester.pumpAndSettle();

    expect(rowBorder(tester, incoming.id!).top.width, 0);
    expect(controller.selectedEvent?.id, existing.id);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(controller.selectedEvent?.id, existing.id);
  });

  for (final brightness in Brightness.values) {
    testWidgets('compact tabs show a focus ring separate from selection in '
        '${brightness.name}', (tester) async {
      final controller = PlaygroundController(sessionFactory: _TestSession.new);
      addTearDown(controller.dispose);
      await pumpPage(
        tester,
        controller,
        size: const Size(1024, 900),
        brightness: brightness,
      );

      final tabBar = find.byType(TabBar);
      final tabController = DefaultTabController.of(tester.element(tabBar));
      expect(tabController.index, 0);
      for (var index = 0; index < 3; index++) {
        expect(
          find.descendant(
            of: find.byKey(Key('nav-tab-$index')),
            matching: find.byType(Focus),
          ),
          findsNothing,
        );
      }

      var focusedIndex = -1;
      for (var step = 0; step < 10 && focusedIndex != 1; step++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        for (var index = 0; index < 3; index++) {
          final container = tester.widget<Container>(
            find.byKey(Key('nav-tab-$index')),
          );
          final border =
              (container.decoration as BoxDecoration?)?.border as Border?;
          if (border != null) {
            focusedIndex = index;
          }
        }
      }

      expect(focusedIndex, 1);
      expect(tabController.index, 0);
      final focusedRing =
          (tester
                          .widget<Container>(
                            find.byKey(Key('nav-tab-$focusedIndex')),
                          )
                          .decoration!
                      as BoxDecoration)
                  .border!
              as Border;
      final accent = brightness == Brightness.dark
          ? playgroundDarkColors.accent
          : playgroundLightColors.accent;
      for (final side in [
        focusedRing.top,
        focusedRing.left,
        focusedRing.right,
        focusedRing.bottom,
      ]) {
        expect(side.width, 3);
        expect(side.color, accent);
      }
      for (final index in [0, 2]) {
        expect(
          (tester
                      .widget<Container>(find.byKey(Key('nav-tab-$index')))
                      .decoration
                  as BoxDecoration?)
              ?.border,
          isNull,
        );
      }
    });
  }

  testWidgets('Tab focus reaches presets and Connect once', (tester) async {
    final controller = PlaygroundController(sessionFactory: _TestSession.new);
    addTearDown(controller.dispose);
    await pumpPage(tester, controller);

    final connect = find.byKey(const Key('connect-button'));
    final primal = find.byKey(const Key('relay-preset-primal'));
    var sawPreset = false;
    for (var i = 0; i < 12 && !focusedWithin(tester, connect); i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      sawPreset = sawPreset || focusedWithin(tester, primal);
    }

    expect(sawPreset, isTrue);
    expect(focusedWithin(tester, connect), isTrue);
  });

  testWidgets('mobile tabs keep native keyboard focus', (tester) async {
    final controller = PlaygroundController(sessionFactory: _TestSession.new);
    addTearDown(controller.dispose);
    await pumpPage(tester, controller, size: const Size(1024, 900));

    final tabBar = find.byType(TabBar);
    var sawTabFocus = false;
    for (var i = 0; i < 12 && !sawTabFocus; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      sawTabFocus = focusedWithin(tester, tabBar);
    }
    expect(sawTabFocus, isTrue);
  });

  testWidgets('live region announces session outcomes, not incoming events', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final session = _TestSession();
    final controller = PlaygroundController(sessionFactory: () => session);
    addTearDown(controller.dispose);
    await pumpPage(tester, controller);

    final connecting = controller.connect('wss://relay.example');
    await tester.pump();
    expect(liveLabel(tester), contains('Connecting'));

    session.live = const ['wss://relay.example'];
    session.connectCompleter.complete(const NostrSuccess<void>(null));
    await connecting;
    await tester.pump();
    expect(liveLabel(tester), contains('Connected to 1 of 1'));

    controller.subscribe(kinds: '1', authors: '', limit: '20');
    final before = liveLabel(tester);
    session.events.add(
      signLocalEvent(
        keys: NostrKeyPairs.generate(),
        kind: 1,
        content: 'do-not-announce-incoming-event',
        tags: const [],
      ),
    );
    await tester.pump();

    expect(liveLabel(tester), before);
    expect(liveLabel(tester), isNot(contains('do-not-announce')));
    handle.dispose();
  });

  testWidgets('live region announces errors and publish outcomes', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final session = _TestSession();
    final controller = PlaygroundController(sessionFactory: () => session);
    addTearDown(controller.dispose);
    await pumpPage(tester, controller);

    await controller.connect('https://relay.example');
    await tester.pump();
    expect(liveLabel(tester), contains('Error'));
    expect(liveLabel(tester), contains('wss://'));

    final connecting = controller.connect('wss://relay.example');
    session.live = const ['wss://relay.example'];
    session.connectCompleter.complete(const NostrSuccess<void>(null));
    await connecting;
    controller.generateKeyPair();
    controller.signEvent(kind: '1', content: 'announce receipt', tags: '[]');

    final publish = controller.publishSignedEvent(confirmed: true);
    session.publishCompleter.complete(
      NostrSuccess<NostrEventOkCommand>(
        NostrEventOkCommand(
          eventId: controller.signedEvent!.id!,
          isEventAccepted: true,
          message: '',
        ),
      ),
    );
    await publish;
    await tester.pump();

    expect(liveLabel(tester), contains('Publish receipt'));
    expect(liveLabel(tester), contains('accepted'));
    handle.dispose();
  });

  testWidgets('publish dialog focuses Cancel, Esc cancels and focus returns', (
    tester,
  ) async {
    final event = signLocalEvent(
      keys: NostrKeyPairs.generate(),
      kind: 1,
      content: 'dialog focus',
      tags: const [],
    );
    final result = ValueNotifier<bool?>(null);
    addTearDown(result.dispose);
    final triggerFocus = FocusNode(debugLabel: 'open-publish-dialog');
    addTearDown(triggerFocus.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                key: const Key('open-publish-dialog'),
                focusNode: triggerFocus,
                onPressed: () async {
                  triggerFocus.requestFocus();
                  result.value = await showPublishConfirmation(
                    context,
                    event: event,
                    relays: const ['wss://relay.example'],
                  );
                },
                child: const Text('Open publish dialog'),
              ),
            ),
          ),
        ),
      ),
    );

    Future<void> open() async {
      await tester.tap(find.byKey(const Key('open-publish-dialog')));
      await tester.pumpAndSettle();
      expect(find.text('Publish publicly?'), findsOneWidget);
    }

    await open();
    final cancel = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Cancel'),
    );
    expect(cancel.autofocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(result.value, isFalse);
    expect(triggerFocus.hasFocus, isTrue);

    await open();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(result.value, isFalse);
    expect(triggerFocus.hasFocus, isTrue);

    await open();
    await tester.tap(find.text('Publish publicly'));
    await tester.pumpAndSettle();
    expect(result.value, isTrue);
    expect(triggerFocus.hasFocus, isTrue);
  });

  for (final width in [390.0, 1024.0, 1280.0]) {
    testWidgets('layout at ${width.toInt()}px has no overflow', (tester) async {
      await pumpApp(tester, size: Size(width, 900));

      if (width >= 1180) {
        expect(find.byKey(const Key('desktop-console')), findsOneWidget);
        expect(find.byKey(const Key('mobile-console')), findsNothing);
      } else {
        expect(find.byKey(const Key('mobile-console')), findsOneWidget);
        expect(find.byKey(const Key('desktop-console')), findsNothing);
        await openTab(tester, 'Events');
        expect(find.textContaining('No events yet'), findsOneWidget);
        await openTab(tester, 'Logs');
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('390px with 1.6 text scale has no overflow', (tester) async {
    final controller = PlaygroundController(sessionFactory: _TestSession.new);
    addTearDown(controller.dispose);
    await pumpPage(
      tester,
      controller,
      size: const Size(390, 844),
      textScale: 1.6,
    );

    expect(find.byKey(const Key('mobile-console')), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'setup tab');
    await openTab(tester, 'Events');
    expect(tester.takeException(), isNull, reason: 'events tab');
    await openTab(tester, 'Logs');
    expect(tester.takeException(), isNull, reason: 'logs tab');
  });
}
