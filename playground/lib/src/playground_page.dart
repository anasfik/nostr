import 'package:dart_nostr/dart_nostr.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'nostr_tools.dart';
import 'playground_controller.dart';
import 'playground_theme.dart';

const TextStyle _mono = TextStyle(
  fontFamily: 'monospace',
  fontFamilyFallback: ['Menlo', 'Consolas', 'Liberation Mono'],
  fontSize: 12,
  height: 1.45,
);

const List<String> _navTabLabels = ['Setup', 'Events', 'Logs'];

TextStyle? _tabular(TextStyle? style) =>
    style?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]);

Future<bool> showPublishConfirmation(
  BuildContext context, {
  required NostrEvent event,
  required List<String> relays,
}) async {
  final previousFocus = FocusManager.instance.primaryFocus;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.pop(dialogContext, false),
      },
      child: AlertDialog(
        title: const Text('Publish publicly?'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'This signed event is sent to public relays. Anyone can read '
                'and copy it. Published events cannot be deleted everywhere.',
              ),
              const SizedBox(height: 8),
              const Text(
                'Only the first relay response is shown. Other relays may '
                'accept, reject or not answer, so a rejection does not prove '
                'that no relay accepted the event.',
              ),
              const SizedBox(height: 12),
              Text(
                'Kind ${event.kind ?? "?"} · ${shortId(event.id)}',
                style: _mono,
              ),
              const SizedBox(height: 4),
              Text(
                relays.isEmpty ? 'No relays configured.' : relays.join('\n'),
                style: _mono,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            autofocus: true,
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.public),
            label: const Text('Publish publicly'),
          ),
        ],
      ),
    ),
  );
  if (previousFocus != null && previousFocus.context != null) {
    previousFocus.requestFocus();
  }
  return confirmed ?? false;
}

class PlaygroundPage extends StatefulWidget {
  const PlaygroundPage({super.key, this.controller, this.onToggleTheme});

  final PlaygroundController? controller;
  final VoidCallback? onToggleTheme;

  @override
  State<PlaygroundPage> createState() => _PlaygroundPageState();
}

class _PlaygroundPageState extends State<PlaygroundPage> {
  late final PlaygroundController _controller;
  late final bool _ownsController;

  final _relayText = TextEditingController();
  final _kindText = TextEditingController(text: '1');
  final _contentText = TextEditingController();
  final _tagsText = TextEditingController(text: '[]');
  final _filterKindsText = TextEditingController(text: '1');
  final _filterAuthorsText = TextEditingController();
  final _filterLimitText = TextEditingController(text: '20');

  bool _inspectingMobileEvent = false;
  int? _focusedTabIndex;
  late PlaygroundSessionStatus _lastStatus;
  String? _lastError;
  String? _lastReceipt;
  String _liveMessage = '';

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? PlaygroundController();
    _lastStatus = _controller.status;
    _lastError = _controller.error;
    _lastReceipt = _controller.publishReceipt;
    _controller.addListener(_onControllerChanged);
  }

  void _onControllerChanged() {
    if (mounted) {
      _syncLiveMessage();
      setState(() {});
    }
  }

  /// Announce outcomes only. Incoming relay events stay silent on purpose.
  void _syncLiveMessage() {
    final status = _controller.status;
    final error = _controller.error;
    final receipt = _controller.publishReceipt;
    String? next;
    if (error != null && error != _lastError) {
      next = 'Error: $error';
    } else if (receipt != null && receipt != _lastReceipt) {
      next = 'Publish receipt: $receipt';
    } else if (status != _lastStatus) {
      next = switch (status) {
        PlaygroundSessionStatus.disconnected => 'Disconnected.',
        PlaygroundSessionStatus.connecting =>
          'Connecting to ${_controller.relays.length} relay(s).',
        PlaygroundSessionStatus.connected =>
          'Connected to ${_controller.liveRelays.length} of '
              '${_controller.relays.length} relay(s).',
      };
    }
    _lastStatus = status;
    _lastError = error;
    _lastReceipt = receipt;
    if (next != null) {
      _liveMessage = next;
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    if (_ownsController) {
      _controller.dispose();
    }
    _relayText.dispose();
    _kindText.dispose();
    _contentText.dispose();
    _tagsText.dispose();
    _filterKindsText.dispose();
    _filterAuthorsText.dispose();
    _filterLimitText.dispose();
    super.dispose();
  }

  Future<void> _publish() async {
    final event = _controller.signedEvent;
    if (event == null) {
      return;
    }
    final confirmed = await showPublishConfirmation(
      context,
      event: event,
      relays: _controller.liveRelays,
    );
    if (!mounted || !confirmed) {
      return;
    }
    await _controller.publishSignedEvent(confirmed: true);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: [
            Icon(Icons.hub_outlined, color: scheme.primary),
            const SizedBox(width: 8),
            const Flexible(
              child: Text(
                'Nostr debug playground',
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            const _Badge(text: 'ephemeral'),
          ],
        ),
        actions: [
          if (widget.onToggleTheme != null)
            IconButton(
              tooltip: 'Toggle light or dark theme',
              onPressed: widget.onToggleTheme,
              icon: const Icon(Icons.brightness_6_outlined),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Semantics(
              key: const Key('live-announcements'),
              container: true,
              liveRegion: true,
              label: _liveMessage,
              child: const SizedBox(width: 1, height: 1),
            ),
            if (_controller.error != null)
              _ErrorBanner(
                message: _controller.error!,
                onDismiss: _controller.clearError,
              ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth >= 1180) {
                    return Row(
                      key: const Key('desktop-console'),
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          width: 400,
                          child: _ControlsPanel(
                            controller: _controller,
                            relayText: _relayText,
                            kindText: _kindText,
                            contentText: _contentText,
                            tagsText: _tagsText,
                            filterKindsText: _filterKindsText,
                            filterAuthorsText: _filterAuthorsText,
                            filterLimitText: _filterLimitText,
                            onConnect: () =>
                                _controller.connect(_relayText.text),
                            onPublish: _publish,
                          ),
                        ),
                        const VerticalDivider(width: 1),
                        Expanded(child: _DebugConsole(controller: _controller)),
                      ],
                    );
                  }

                  return Column(
                    key: const Key('mobile-console'),
                    children: [
                      _RelayStatusBar(controller: _controller, dense: true),
                      const Divider(height: 1),
                      Expanded(
                        child: DefaultTabController(
                          length: 3,
                          child: Column(
                            children: [
                              TabBar(
                                onFocusChange: (focused, index) {
                                  if (mounted) {
                                    setState(
                                      () => _focusedTabIndex = focused
                                          ? index
                                          : null,
                                    );
                                  }
                                },
                                tabs: [
                                  for (var index = 0; index < 3; index++)
                                    _NavTab(
                                      index: index,
                                      label: _navTabLabels[index],
                                      focused: _focusedTabIndex == index,
                                    ),
                                ],
                              ),
                              Expanded(
                                child: TabBarView(
                                  children: [
                                    _ControlsPanel(
                                      controller: _controller,
                                      relayText: _relayText,
                                      kindText: _kindText,
                                      contentText: _contentText,
                                      tagsText: _tagsText,
                                      filterKindsText: _filterKindsText,
                                      filterAuthorsText: _filterAuthorsText,
                                      filterLimitText: _filterLimitText,
                                      onConnect: () =>
                                          _controller.connect(_relayText.text),
                                      onPublish: _publish,
                                    ),
                                    _MobileEventsPanel(
                                      controller: _controller,
                                      inspecting: _inspectingMobileEvent,
                                      onOpen: () => setState(
                                        () => _inspectingMobileEvent = true,
                                      ),
                                      onBack: () => setState(
                                        () => _inspectingMobileEvent = false,
                                      ),
                                    ),
                                    _LogPanel(controller: _controller),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavTab extends StatelessWidget {
  const _NavTab({
    required this.index,
    required this.label,
    required this.focused,
  });

  final int index;
  final String label;
  final bool focused;

  @override
  Widget build(BuildContext context) {
    final colors = playgroundColorsOf(context);
    return Container(
      key: Key('nav-tab-$index'),
      decoration: focused
          ? BoxDecoration(
              border: Border.all(
                color: colors.accent,
                width: playgroundFocusWidth,
              ),
              borderRadius: BorderRadius.circular(4),
            )
          : null,
      child: Tab(text: label),
    );
  }
}

class _ControlsPanel extends StatelessWidget {
  const _ControlsPanel({
    required this.controller,
    required this.relayText,
    required this.kindText,
    required this.contentText,
    required this.tagsText,
    required this.filterKindsText,
    required this.filterAuthorsText,
    required this.filterLimitText,
    required this.onConnect,
    required this.onPublish,
  });

  final PlaygroundController controller;
  final TextEditingController relayText;
  final TextEditingController kindText;
  final TextEditingController contentText;
  final TextEditingController tagsText;
  final TextEditingController filterKindsText;
  final TextEditingController filterAuthorsText;
  final TextEditingController filterLimitText;
  final VoidCallback onConnect;
  final VoidCallback onPublish;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _IntroCard(),
          const SizedBox(height: 12),
          _Section(
            title: 'Relay session',
            subtitle: 'WSS only · max 3 relays · nothing connects on load',
            children: [
              TextField(
                key: const Key('relay-input'),
                controller: relayText,
                minLines: 2,
                maxLines: 3,
                autocorrect: false,
                enableSuggestions: false,
                decoration: const InputDecoration(
                  labelText: 'Relay URLs',
                  hintText: 'wss://relay.damus.io\nwss://nos.lol',
                  helperText: 'One per line, or separated by commas.',
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Relay presets',
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final preset in relayPresets)
                    OutlinedButton(
                      key: Key(
                        'relay-preset-'
                        '${preset.name.toLowerCase().replaceAll('.', '-')}',
                      ),
                      onPressed: () {
                        relayText.value = TextEditingValue(
                          text: preset.url,
                          selection: TextSelection.collapsed(
                            offset: preset.url.length,
                          ),
                        );
                      },
                      child: Text(preset.name),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Presets replace the relay field. Nothing connects until '
                'you press Connect. Relay availability varies, so if one '
                'times out or returns nothing, try another preset.',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: playgroundColorsOf(context).muted),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    key: const Key('connect-button'),
                    onPressed:
                        controller.status == PlaygroundSessionStatus.connecting
                        ? null
                        : onConnect,
                    icon: const Icon(Icons.link),
                    label: Text(
                      controller.status == PlaygroundSessionStatus.connecting
                          ? 'Connecting…'
                          : 'Connect',
                    ),
                  ),
                  OutlinedButton.icon(
                    key: const Key('disconnect-button'),
                    onPressed:
                        controller.status ==
                            PlaygroundSessionStatus.disconnected
                        ? null
                        : controller.disconnect,
                    icon: const Icon(Icons.link_off),
                    label: Text(
                      controller.status == PlaygroundSessionStatus.connecting
                          ? 'Cancel'
                          : 'Disconnect',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _StatusChip(controller: controller),
            ],
          ),
          _Section(
            title: 'Ephemeral identity',
            subtitle: 'Generated in memory. Never stored, imported or logged.',
            children: [
              FilledButton.tonalIcon(
                key: const Key('generate-key-button'),
                style: playgroundFocusSideStyle(
                  Theme.of(context).colorScheme.onSecondaryContainer,
                ),
                onPressed: controller.generateKeyPair,
                icon: const Icon(Icons.key),
                label: Text(
                  controller.hasKey ? 'Generate another key' : 'Generate key',
                ),
              ),
              if (controller.publicKey != null) ...[
                const SizedBox(height: 12),
                const Text('Public key (hex)'),
                const SizedBox(height: 4),
                SelectableText(
                  controller.publicKey!,
                  key: const Key('pubkey-text'),
                  style: _mono,
                ),
                const SizedBox(height: 8),
                const Text('npub'),
                const SizedBox(height: 4),
                SelectableText(controller.npub!, style: _mono),
                const SizedBox(height: 8),
                Text(
                  'The private key stays in this browser tab. Reloading or '
                  'disconnecting a live session clears it; cancelling a '
                  'pending connection keeps it.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
          _Section(
            title: 'Sign locally',
            subtitle: 'Build, hash and sign an event in this tab.',
            children: [
              TextField(
                key: const Key('kind-input'),
                controller: kindText,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Kind'),
              ),
              const SizedBox(height: 10),
              TextField(
                key: const Key('content-input'),
                controller: contentText,
                minLines: 3,
                maxLines: 6,
                maxLength: maxContentLength,
                decoration: const InputDecoration(
                  labelText: 'Content',
                  hintText: 'Hello from the Nostr debug playground.',
                ),
              ),
              const SizedBox(height: 4),
              TextField(
                key: const Key('tags-input'),
                controller: tagsText,
                minLines: 1,
                maxLines: 3,
                autocorrect: false,
                enableSuggestions: false,
                decoration: const InputDecoration(
                  labelText: 'Tags (JSON)',
                  hintText: '[["t","nostr"]]',
                ),
              ),
              const SizedBox(height: 10),
              FilledButton.tonalIcon(
                key: const Key('sign-button'),
                style: playgroundFocusSideStyle(
                  Theme.of(context).colorScheme.onSecondaryContainer,
                ),
                onPressed: () => controller.signEvent(
                  kind: kindText.text,
                  content: contentText.text,
                  tags: tagsText.text,
                ),
                icon: const Icon(Icons.draw_outlined),
                label: const Text('Sign event'),
              ),
              if (controller.signedEvent != null) ...[
                const SizedBox(height: 10),
                _CheckLine(
                  ok: controller.isAuthentic(controller.signedEvent!),
                  text: controller.isAuthentic(controller.signedEvent!)
                      ? 'Locally verified · ${shortId(controller.signedEvent!.id)}'
                      : 'Local verification failed · ${shortId(controller.signedEvent!.id)}',
                ),
              ],
            ],
          ),
          _Section(
            title: 'Publish publicly',
            subtitle:
                'Requires a live connection, a signed event and explicit '
                'confirmation. Only the first relay response is shown.',
            children: [
              FilledButton.icon(
                key: const Key('publish-button'),
                onPressed: controller.canPublish ? onPublish : null,
                icon: const Icon(Icons.public),
                label: Text(
                  controller.publishing ? 'Publishing…' : 'Publish event…',
                ),
              ),
              if (!controller.canPublish) ...[
                const SizedBox(height: 8),
                Text(
                  _publishRequirement(controller),
                  key: const Key('publish-prerequisites'),
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: playgroundColorsOf(context).muted),
                ),
              ],
              if (controller.publishing) ...[
                const SizedBox(height: 10),
                const LinearProgressIndicator(),
              ],
              if (controller.publishReceipt != null) ...[
                const SizedBox(height: 10),
                _CheckLine(ok: true, text: controller.publishReceipt!),
              ],
            ],
          ),
          _Section(
            title: 'Read subscription',
            subtitle:
                'Live events from the connected relays. Capped at '
                '$maxEventFeed in memory.',
            children: [
              TextField(
                key: const Key('filter-kinds-input'),
                controller: filterKindsText,
                decoration: const InputDecoration(
                  labelText: 'Kinds',
                  hintText: '1, 7',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                key: const Key('filter-authors-input'),
                controller: filterAuthorsText,
                autocorrect: false,
                enableSuggestions: false,
                decoration: const InputDecoration(
                  labelText: 'Authors (optional hex pubkeys)',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                key: const Key('filter-limit-input'),
                controller: filterLimitText,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Limit'),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonalIcon(
                    key: const Key('subscribe-button'),
                    style: playgroundFocusSideStyle(
                      Theme.of(context).colorScheme.onSecondaryContainer,
                    ),
                    onPressed: () => controller.subscribe(
                      kinds: filterKindsText.text,
                      authors: filterAuthorsText.text,
                      limit: filterLimitText.text,
                    ),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Start reading'),
                  ),
                  OutlinedButton.icon(
                    key: const Key('stop-subscription-button'),
                    onPressed: controller.subscriptionActive
                        ? controller.stopSubscription
                        : null,
                    icon: const Icon(Icons.stop),
                    label: const Text('Stop'),
                  ),
                ],
              ),
              if (controller.subscriptionId != null) ...[
                const SizedBox(height: 10),
                Text(
                  'Subscription ${shortId(controller.subscriptionId)}'
                  '${controller.waitingForFirstEvent ? " · waiting for first event…" : ""}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
          const _LimitsCard(),
        ],
      ),
    );

    return SingleChildScrollView(child: content);
  }
}

class _DebugConsole extends StatelessWidget {
  const _DebugConsole({required this.controller});

  final PlaygroundController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _RelayStatusBar(controller: controller),
        const Divider(height: 1),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 310,
                child: _EventListPanel(controller: controller),
              ),
              const VerticalDivider(width: 1),
              Expanded(child: _EventInspector(controller: controller)),
            ],
          ),
        ),
        const Divider(height: 1),
        SizedBox(height: 190, child: _LogPanel(controller: controller)),
      ],
    );
  }
}

class _RelayStatusBar extends StatelessWidget {
  const _RelayStatusBar({required this.controller, this.dense = false});

  final PlaygroundController controller;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = playgroundColorsOf(context);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: dense ? 8 : 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text('Relays', style: Theme.of(context).textTheme.labelLarge),
          _StatusChip(controller: controller),
          if (controller.relays.isEmpty)
            Text(
              'No relays yet. Choose a preset and press Connect.',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          for (final relay in controller.relays)
            Tooltip(
              message: relay,
              child: Chip(
                visualDensity: VisualDensity.compact,
                avatar: Icon(
                  controller.liveRelays.contains(relay)
                      ? Icons.circle
                      : Icons.circle_outlined,
                  size: 10,
                  color: controller.liveRelays.contains(relay)
                      ? colors.success
                      : scheme.outline,
                ),
                label: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 190),
                  child: Text(
                    relay,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _EventListPanel extends StatelessWidget {
  const _EventListPanel({required this.controller, this.onOpen});

  final PlaygroundController controller;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final connected = controller.status == PlaygroundSessionStatus.connected;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Text('Events', style: Theme.of(context).textTheme.titleSmall),
              const Spacer(),
              if (controller.droppedEventCount > 0)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    '${controller.droppedEventCount} dropped',
                    style: _tabular(
                      Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: scheme.error),
                    ),
                  ),
                ),
              Text(
                '${controller.events.length}/$maxEventFeed',
                style: _tabular(Theme.of(context).textTheme.bodySmall),
              ),
            ],
          ),
        ),
        Expanded(
          child: controller.events.isEmpty
              ? _EmptyState(
                  icon: Icons.inbox_outlined,
                  title: 'No events yet',
                  message: !connected
                      ? 'Connect to a relay, then start a read subscription. '
                            'Choose a preset above, then press Connect.'
                      : controller.subscriptionActive
                      ? 'Subscription is live. Waiting for matching events. '
                            'Relay availability varies; try another preset '
                            'and reconnect if nothing arrives.'
                      : 'Start a read subscription to see events here.',
                )
              : ListView.builder(
                  itemCount: controller.events.length,
                  itemBuilder: (context, index) {
                    final event = controller.events[index];
                    final selected =
                        controller.selectedEvent?.id == event.id &&
                        event.id != null;
                    final authentic = controller.isAuthentic(event);

                    return _EventRow(
                      key: event.id == null
                          ? ObjectKey(event)
                          : ValueKey('event-row-state-${event.id}'),
                      event: event,
                      selected: selected,
                      authentic: authentic,
                      onOpen: () {
                        controller.selectEvent(event);
                        onOpen?.call();
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _EventRow extends StatefulWidget {
  const _EventRow({
    super.key,
    required this.event,
    required this.selected,
    required this.authentic,
    required this.onOpen,
  });

  final NostrEvent event;
  final bool selected;
  final bool authentic;
  final VoidCallback onOpen;

  @override
  State<_EventRow> createState() => _EventRowState();
}

class _EventRowState extends State<_EventRow> {
  final FocusNode _focusNode = FocusNode(debugLabel: 'event-row');
  bool _focused = false;

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = playgroundColorsOf(context);
    final event = widget.event;

    return Semantics(
      key: Key('event-row-${event.id}'),
      container: true,
      excludeSemantics: true,
      button: true,
      selected: widget.selected,
      label: _eventRowLabel(event, widget.authentic),
      onTap: widget.onOpen,
      child: InkWell(
        focusNode: _focusNode,
        onFocusChange: (focused) {
          if (mounted) {
            setState(() => _focused = focused);
          }
        },
        onTap: widget.onOpen,
        child: Container(
          key: Key('event-row-surface-${event.id}'),
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          decoration: BoxDecoration(
            color: widget.selected
                ? scheme.primaryContainer.withValues(alpha: 0.45)
                : null,
            border: _focused
                ? Border.all(color: colors.accent, width: playgroundFocusWidth)
                : Border(
                    bottom: BorderSide(
                      color: colors.border.withValues(alpha: 0.6),
                    ),
                  ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'kind ${event.kind ?? "?"}',
                    style: Theme.of(context).textTheme.labelMedium
                        ?.copyWith(color: scheme.primary),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    widget.authentic
                        ? Icons.verified_outlined
                        : Icons.gpp_bad_outlined,
                    size: 14,
                    color: widget.authentic ? colors.success : scheme.error,
                  ),
                  const Spacer(),
                  Text(
                    _timeLabel(event.createdAt),
                    style: _tabular(Theme.of(context).textTheme.bodySmall),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                (event.content ?? '').isEmpty
                    ? '(no content)'
                    : event.content!.replaceAll('\n', ' '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 4),
              Text(
                shortId(event.id),
                style: _mono.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EventInspector extends StatelessWidget {
  const _EventInspector({required this.controller, this.onBack});

  final PlaygroundController controller;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = playgroundColorsOf(context);
    final event = controller.selectedEvent;
    final json = controller.selectedEventJson;

    if (event == null || json == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (onBack != null) _BackToEvents(onBack: onBack!),
          const Expanded(
            child: _EmptyState(
              icon: Icons.data_object,
              title: 'No event selected',
              message: 'Sign an event or pick one from the list to inspect its JSON.',
            ),
          ),
        ],
      );
    }

    final authentic = controller.isAuthentic(event);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (onBack != null) _BackToEvents(onBack: onBack!),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
          child: Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(
                      authentic
                          ? Icons.verified_outlined
                          : Icons.gpp_bad_outlined,
                      size: 18,
                      color: authentic ? colors.success : scheme.error,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        authentic ? 'Signature valid' : 'Signature invalid',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Copy event JSON',
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: json));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Event JSON copied.')),
                    );
                  }
                },
                icon: const Icon(Icons.copy_all_outlined),
              ),
            ],
          ),
        ),
        if ((event.content ?? '').isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Content (untrusted plain text)',
                  style: Theme.of(context).textTheme.labelSmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxHeight: 96),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colors.background,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: colors.border),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(event.content!),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SelectableText(
              json,
              key: const Key('event-json'),
              style: _mono,
            ),
          ),
        ),
      ],
    );
  }
}

class _BackToEvents extends StatelessWidget {
  const _BackToEvents({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          key: const Key('back-to-events-button'),
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back, size: 18),
          label: const Text('Back to events'),
        ),
      ),
    );
  }
}

class _MobileEventsPanel extends StatelessWidget {
  const _MobileEventsPanel({
    required this.controller,
    required this.inspecting,
    required this.onOpen,
    required this.onBack,
  });

  final PlaygroundController controller;
  final bool inspecting;
  final VoidCallback onOpen;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final signedEvent = controller.signedEvent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!inspecting && signedEvent != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                key: const Key('inspect-signed-event-button'),
                onPressed: () {
                  controller.selectEvent(signedEvent);
                  onOpen();
                },
                icon: const Icon(Icons.data_object, size: 18),
                label: const Text('Inspect signed event'),
              ),
            ),
          ),
        Expanded(
          child: inspecting
              ? _EventInspector(controller: controller, onBack: onBack)
              : _EventListPanel(controller: controller, onOpen: onOpen),
        ),
      ],
    );
  }
}

class _LogPanel extends StatelessWidget {
  const _LogPanel({required this.controller});

  final PlaygroundController controller;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Operation log',
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${controller.logs.length}/$maxLogEntries',
                style: _tabular(Theme.of(context).textTheme.bodySmall),
              ),
            ],
          ),
        ),
        Expanded(
          child: controller.logs.isEmpty
              ? const _EmptyState(
                  icon: Icons.terminal,
                  title: 'No operations yet',
                  message:
                      'Connections, reads, signing and publishes show up '
                      'here. Keys and private data never do.',
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 8),
                  itemCount: controller.logs.length,
                  itemBuilder: (context, index) {
                    final entry = controller.logs[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 3,
                      ),
                      child: SelectableText(
                        '${entry.timestamp}  ${entry.level.name.toUpperCase()}  '
                        '${entry.message}',
                        style: _mono.copyWith(
                          color: switch (entry.level) {
                            LogLevel.error => scheme.error,
                            LogLevel.warn => scheme.tertiary,
                            LogLevel.event => scheme.primary,
                            LogLevel.info => scheme.onSurfaceVariant,
                          },
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _IntroCard extends StatelessWidget {
  const _IntroCard();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.science_outlined, color: scheme.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Local-first debug console',
                  style: Theme.of(context).textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Connect, read and sign with real dart_nostr APIs. Keys are '
            'ephemeral and content from relays is shown as plain text.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _LimitsCard extends StatelessWidget {
  const _LimitsCard();

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall
        ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Known limits', style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 6),
          Text(
            'Core workflow only: no wallet, DMs, NIP-42 auth, private key '
            'import or persistence. Feed and log are capped. The browser '
            'keeps no keys after reload or disconnecting a live session. '
            'Use a test key for anything public.',
            style: style,
          ),
          const SizedBox(height: 8),
          Text('Full SDK docs: nostr.gwhyyy.com/docs', style: style),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.controller});

  final PlaygroundController controller;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = playgroundColorsOf(context);
    final (color, label) = switch (controller.status) {
      PlaygroundSessionStatus.disconnected => (scheme.outline, 'Not connected'),
      PlaygroundSessionStatus.connecting => (scheme.tertiary, 'Connecting…'),
      PlaygroundSessionStatus.connected => (
        colors.success,
        'Connected · ${controller.liveRelays.length}/${controller.relays.length}',
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 8, color: color),
          const SizedBox(width: 6),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: scheme.onSecondaryContainer),
      ),
    );
  }
}

class _CheckLine extends StatelessWidget {
  const _CheckLine({required this.ok, required this.text});

  final bool ok;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = playgroundColorsOf(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          ok ? Icons.check_circle_outline : Icons.error_outline,
          size: 16,
          color: ok ? colors.success : scheme.error,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: SelectableText(
            text,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onDismiss});

  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: scheme.onErrorContainer, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: scheme.onErrorContainer),
              ),
            ),
            IconButton(
              tooltip: 'Dismiss error',
              onPressed: onDismiss,
              icon: Icon(Icons.close, color: scheme.onErrorContainer),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 32, color: scheme.outline),
            const SizedBox(height: 8),
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

String _timeLabel(DateTime? time) {
  if (time == null) {
    return '';
  }
  final local = time.toLocal();
  return '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
}

String _eventRowLabel(NostrEvent event, bool authentic) {
  final content = (event.content ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();
  final preview = content.isEmpty
      ? 'no content'
      : content.length <= 120
      ? content
      : '${content.substring(0, 120)}…';
  return 'kind ${event.kind ?? "?"} · '
      '${authentic ? "Signature valid" : "Signature invalid"} · '
      '${_timeLabel(event.createdAt)} · id ${shortId(event.id)} · $preview';
}

String _publishRequirement(PlaygroundController controller) {
  if (controller.publishing) {
    return 'Waiting for the current publish to finish…';
  }
  if (controller.signedEvent == null) {
    return 'Sign an event locally, connect to a live relay, then publish.';
  }
  if (controller.status != PlaygroundSessionStatus.connected) {
    return 'Connect to at least one live relay before publishing. '
        'Try another preset if a relay times out.';
  }
  if (controller.liveRelays.isEmpty) {
    return 'No relay is live yet. Try another preset, reconnect, then publish.';
  }
  return 'Publishing is unavailable right now.';
}
