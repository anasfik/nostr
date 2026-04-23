import 'dart:core';

import 'package:dart_nostr/nostr/builder/defaults.dart';
import 'package:dart_nostr/nostr/builder/filter_builder.dart';
import 'package:dart_nostr/nostr/core/result.dart';
import 'package:dart_nostr/nostr/core/utils.dart';
import 'package:dart_nostr/nostr/instance/bech32/bech32.dart';
import 'package:dart_nostr/nostr/instance/keys/keys.dart';
import 'package:dart_nostr/nostr/instance/relays/relays.dart';
import 'package:dart_nostr/nostr/instance/subscription_manager.dart';
import 'package:dart_nostr/nostr/instance/utils/utils.dart';
import 'package:dart_nostr/nostr/model/count.dart';
import 'package:dart_nostr/nostr/model/debug_options.dart';
import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:dart_nostr/nostr/model/nostr_events_stream.dart';
import 'package:dart_nostr/nostr/model/ok.dart';
import 'package:dart_nostr/nostr/model/request/filter.dart';
import 'package:dart_nostr/nostr/model/request/request.dart';
import 'package:dart_nostr/nostr/service/client.dart';
import 'package:dart_nostr/nostr/service/client_options.dart';
import 'package:dart_nostr/nostr/service/services.dart';

/// {@template nostr_service}
/// This class is responsible for handling the connection to all relays.
/// {@endtemplate}
class Nostr {
  /// {@macro nostr_service}
  factory Nostr({
    NostrDebugOptions? debugOptions,
    NostrServices? services,
    NostrClientOptions clientOptions = const NostrClientOptions(),
  }) {
    //  utils.log("A Nostr instance created successfully.");
    return Nostr._(
      debugOptions: debugOptions,
      services: services,
      clientOptions: clientOptions,
    );
  }

  /// Enterprise-oriented default preset.
  factory Nostr.enterprise({
    NostrDebugOptions? debugOptions,
    NostrServices? services,
    NostrClientOptions clientOptions = const NostrClientOptions(
      connectionTimeout: Duration(seconds: 10),
      requestTimeout: Duration(seconds: 15),
    ),
  }) {
    return Nostr(
      debugOptions: debugOptions,
      services: services,
      clientOptions: clientOptions,
    );
  }

  /// {@macro nostr_service}
  Nostr._({
    NostrDebugOptions? debugOptions,
    NostrServices? services,
    NostrClientOptions clientOptions = const NostrClientOptions(),
  }) {
    debugOptions ??= NostrDebugOptions.generate();

    _logger = NostrLogger(passedDebugOptions: debugOptions);
    this.services = services ??
        NostrServices(logger: _logger, clientOptions: clientOptions);
  }

  /// Wether this instance resources are disposed or not.
  bool _isDisposed = false;

  //
  /// {@macro nostr_service}
  static final Nostr _instance = Nostr._(
    debugOptions: NostrDebugOptions.general(),
  );

  /// {@macro nostr_service}
  static Nostr get instance => _instance;

  /// Default relay URLs.
  static List<String> get defaultRelays => NostrDefaults.defaultRelays;

  /// Whether the high-level client currently has active relay connections.
  bool get isConnected => client.isConnected;

  /// High-level relay list known by the active client.
  List<String> get connectedRelays => client.connectedRelays;

  /// Key management surface.
  NostrKeys get keys => services.keys;

  /// Utility helpers surface.
  NostrUtils get utils => services.utils;

  /// Bech32 encoding surface.
  NostrBech32 get bech32 => services.bech32;

  /// Advanced low-level relay surface.
  NostrRelays get relays => services.relays;

  /// Subscription tracking surface.
  SubscriptionManager get subscriptions => services.subscriptionManager;

  /// Connect with the enterprise client facade.
  Future<NostrResult<void>> connect(List<String> relays) {
    return client.connect(relays);
  }

  /// Connect using package defaults.
  Future<NostrResult<void>> connectDefaults() {
    return connect(defaultRelays);
  }

  /// Disconnect and cleanup tracked subscriptions.
  Future<NostrResult<void>> disconnect() {
    return client.disconnect();
  }

  /// Publish an event through the enterprise client facade.
  Future<NostrResult<NostrEventOkCommand>> publish(
    NostrEvent event, {
    List<String>? relays,
  }) {
    return client.publish(event, relays: relays);
  }

  /// Execute a count request through the enterprise client facade.
  Future<NostrResult<NostrCountResponse>> count(
    NostrCountEvent countEvent, {
    List<String>? relays,
  }) {
    return client.count(countEvent, relays: relays);
  }

  /// Start a typed request subscription through the enterprise client facade.
  NostrResult<NostrEventsStream> subscribeRequest(
    NostrRequest request, {
    List<String>? relays,
  }) {
    return client.subscribe(request, relays: relays);
  }

  /// Active managed subscriptions.
  Map<String, SubscriptionMetadata> get activeSubscriptions {
    return client.getActiveSubscriptions();
  }

  /// Aggregate managed subscription metrics.
  SubscriptionStatistics get subscriptionStatistics {
    return client.getSubscriptionStatistics();
  }

  /// Close all client-tracked subscriptions.
  void closeAllSubscriptions() {
    client.closeAllSubscriptions();
  }

  /// Convenience method to start an event subscription.
  /// Shortcut for a typed request subscription with one filter.
  ///
  /// Returns a [NostrEventsStream] that can be listened to for events.
  NostrResult<NostrEventsStream> subscribe(
    NostrFilter filter, {
    List<String>? relays,
  }) {
    return subscribeRequest(
      NostrRequest(filters: [filter]),
      relays: relays,
    );
  }

  /// Convenience method to start multiple event subscriptions.
  /// Shortcut for starting a subscription with multiple filters.
  ///
  /// Returns a [NostrEventsStream] that receives events matching any of the filters.
  NostrResult<NostrEventsStream> subscribeFilters(
    List<NostrFilter> filters, {
    List<String>? relays,
  }) {
    return subscribeRequest(
      NostrRequest(filters: filters),
      relays: relays,
    );
  }

  /// Create a filter builder for fluent API.
  NostrFilterBuilder filterBuilder() => NostrFilterBuilder();

  /// This method will disable the logs of the library.

  void disableLogs() {
    _logger.disableLogs();
  }

  /// This method will enable the logs of the library.

  void enableLogs() {
    _logger.enableLogs();
  }

  /// {@macro nostr_client_utils}
  late final NostrLogger _logger;

  late final NostrServices services;

  /// Enterprise facade with typed result and resilience APIs.
  NostrClient get client => services.client;
}

mixin LifeCycleManager on Nostr {
  /// Clears and frees all the resources used by this instance.

  Future<bool> dispose() async {
    if (_isDisposed) {
      _logger.log('This Nostr instance is already disposed.');
      return true;
    }

    _isDisposed = true;

    _logger.log('A Nostr instance disposed successfully.');

    await Future.wait<dynamic>([
      services.keys.freeAllResources(),
      services.relays.freeAllResources(),
    ]);

    return true;
  }
}
