import 'package:dart_nostr/dart_nostr.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'nostr_tools.dart';
import 'playground_controller.dart';

const TextStyle _mono = TextStyle(
  fontFamily: 'monospace',
  fontFamilyFallback: ['Menlo', 'Consolas', 'Liberation Mono'],
  fontSize: 12,
  height: 1.45,
);

Future<bool> showPublishConfirmation(
  BuildContext context, {
  required NostrEvent event,
  required List<String> relays,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
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
  );
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

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? PlaygroundController();
    _controller.addListener(_onControllerChanged);
  }

  void _onControllerChanged() {
    if (mounted) {
      setState(() {});
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
            if (_controller.error != null)
              _ErrorBanner(
                message: _controller.error!,
                onDismiss: _controller.clearError,
              ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth >= 1000) {
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
                              const TabBar(
                                tabs: [
                                  Tab(text: 'Setup'),
                                  Tab(text: 'Events'),
                                  Tab(text: 'Logs'),
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
                                    Column(
                                      children: [
                                        Expanded(
                                          flex: 3,
                                          child: _EventListPanel(
                                            controller: _controller,
                                          ),
                                        ),
                                        const Divider(height: 1),
                                        Expanded(
                                          flex: 4,
                                          child: _EventInspector(
                                            controller: _controller,
                                          ),
                                        ),
                                      ],
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
              'No relays configured.',
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
                      ? Colors.green
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
  const _EventListPanel({required this.controller});

  final PlaygroundController controller;

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
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: scheme.error),
                  ),
                ),
              Text(
                '${controller.events.length}/$maxEventFeed',
                style: Theme.of(context).textTheme.bodySmall,
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
                      ? 'Connect to a relay, then start a read subscription.'
                      : controller.subscriptionActive
                      ? 'Subscription is live. Waiting for matching events.'
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
                    return InkWell(
                      onTap: () => controller.selectEvent(event),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                        decoration: BoxDecoration(
                          color: selected
                              ? scheme.primaryContainer.withValues(alpha: 0.45)
                              : null,
                          border: Border(
                            bottom: BorderSide(
                              color: scheme.outlineVariant.withValues(
                                alpha: 0.5,
                              ),
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
                                  authentic
                                      ? Icons.verified_outlined
                                      : Icons.gpp_bad_outlined,
                                  size: 14,
                                  color: authentic
                                      ? Colors.green
                                      : scheme.error,
                                ),
                                const Spacer(),
                                Text(
                                  _timeLabel(event.createdAt),
                                  style: Theme.of(context).textTheme.bodySmall,
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
                              style: _mono.copyWith(
                                fontSize: 10,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
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

class _EventInspector extends StatelessWidget {
  const _EventInspector({required this.controller});

  final PlaygroundController controller;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final event = controller.selectedEvent;
    final json = controller.selectedEventJson;

    if (event == null || json == null) {
      return const _EmptyState(
        icon: Icons.data_object,
        title: 'No event selected',
        message: 'Sign an event or pick one from the list to inspect its JSON.',
      );
    }

    final authentic = controller.isAuthentic(event);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
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
                      color: authentic ? Colors.green : scheme.error,
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
                    color: scheme.surfaceContainerHighest.withValues(
                      alpha: 0.5,
                    ),
                    borderRadius: BorderRadius.circular(8),
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
              Text(
                'Operation log',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const Spacer(),
              Text(
                '${controller.logs.length}/$maxLogEntries',
                style: Theme.of(context).textTheme.bodySmall,
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
        borderRadius: BorderRadius.circular(12),
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
    final (color, label) = switch (controller.status) {
      PlaygroundSessionStatus.disconnected => (scheme.outline, 'Not connected'),
      PlaygroundSessionStatus.connecting => (scheme.tertiary, 'Connecting…'),
      PlaygroundSessionStatus.connected => (
        Colors.green,
        'Connected · ${controller.liveRelays.length}/${controller.relays.length}',
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
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
        borderRadius: BorderRadius.circular(999),
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          ok ? Icons.check_circle_outline : Icons.error_outline,
          size: 16,
          color: ok ? Colors.green : scheme.error,
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
