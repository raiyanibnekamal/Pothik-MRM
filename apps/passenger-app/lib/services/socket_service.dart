import 'dart:async';

import 'package:mobile_core/realtime/pusher_client.dart';

import '../constants/socket_events.dart' as ev;

/// Passenger realtime transport backed by Laravel Reverb
/// (Phase 0d). Subscribes to `private-passenger.{passengerId}` and
/// dispatches incoming payloads to [handlers] keyed by event name.
///
/// The wire shape is broker-agnostic: any server that speaks the
/// Pusher Channels protocol (Reverb, Soketi, pusher.com) will work
/// unchanged. The underlying transport lives in
/// [PusherRealtimeClient] so we can swap brokers without touching
/// the cubit layer.
class PassengerSocketService {
  PassengerSocketService({
    required this.apiBaseUrl,
    required this.wsUrl,
    required this.appKey,
    required this.getAuthToken,
    String? passengerId,
  // ignore: prefer_initializing_formals
  }) : _passengerId = passengerId;

  /// REST base, e.g. `https://api.bdride.test/api/v1`. Used for the
  /// broadcasting auth handshake (`POST /broadcasting/auth`).
  final String apiBaseUrl;

  /// WebSocket origin, e.g. `wss://ws.bdride.test`.
  final String wsUrl;

  /// App key the Reverb/Pusher server expects in the WS path.
  /// Defaults to the Laravel Reverb `REVERB_APP_KEY`.
  final String appKey;

  /// Returns the current JWT (or empty string when signed out). The
  /// service calls this on every reconnect -- never cache the token
  /// inside the service, the auth cubit owns it.
  final Future<String> Function() getAuthToken;

  String? _passengerId;

  PusherRealtimeClient? _client;
  final Map<String, List<void Function(Map<String, dynamic>)>> _handlers = {};
  final Set<String> _subscribed = {};

  bool _disposed = false;

  /// True while the WebSocket is open and the welcome frame has
  /// landed. Cubits can read this to drive a "reconnecting..." banner.
  bool get isConnected => _client?.isConnected ?? false;

  /// Set or rotate the active passenger id. Idempotent: when the id
  /// changes we tear down any existing subscription and re-bind on
  /// the next [connect].
  void setPassengerId(String id) {
    if (_passengerId == id) return;
    _passengerId = id;
  }

  void on(String event, void Function(Map<String, dynamic>) handler) {
    _handlers.putIfAbsent(event, () => []).add(handler);
  }

  void off(String event, [void Function(Map<String, dynamic>)? handler]) {
    final list = _handlers[event];
    if (list == null) return;
    if (handler == null) {
      _handlers.remove(event);
    } else {
      list.remove(handler);
    }
  }

  Future<void> connect() async {
    if (_disposed) return;
    final id = _passengerId;
    if (id == null || id.isEmpty) {
      // No identity yet -- auth cubit will call us again once OTP
      // verification completes.
      return;
    }
    _client ??= PusherRealtimeClient(
      apiBaseUrl: apiBaseUrl,
      wsUrl: wsUrl,
      appKey: appKey,
      getAuthToken: getAuthToken,
    );
    await _client!.connect();
    _bindSubscriptions();
  }

  Future<void> dispose() async {
    _disposed = true;
    await _client?.dispose();
    _client = null;
    _handlers.clear();
    _subscribed.clear();
  }

  // -------------------------------------------------------------------
  // Internals
  // -------------------------------------------------------------------

  String _channel() => 'private-passenger.${_passengerId ?? ""}';

  void _bindSubscriptions() {
    final client = _client;
    if (client == null) return;
    final ch = _channel();
    for (final event in const [
      ev.SocketEvents.serverRideAccepted,
      ev.SocketEvents.serverDriverLocation,
      ev.SocketEvents.serverDriverArrived,
      ev.SocketEvents.serverRideStarted,
      ev.SocketEvents.serverRideCompleted,
      ev.SocketEvents.serverDriverCancelled,
      ev.SocketEvents.serverRideCancelled,
      ev.SocketEvents.serverRideTimeout,
    ]) {
      if (_subscribed.add('$ch::$event')) {
        client.subscribe(ch, event).listen((payload) {
          final list = _handlers[event];
          if (list == null) return;
          for (final handler in List.of(list)) {
            handler(payload);
          }
        });
      }
    }
  }

  // Convenience getters so cubits can subscribe without re-typing
  // the event-name strings (which live in shared-constants).
  void onRideAccepted(void Function(Map<String, dynamic>) handler) =>
      on(ev.SocketEvents.serverRideAccepted, handler);

  void onDriverLocation(void Function(Map<String, dynamic>) handler) =>
      on(ev.SocketEvents.serverDriverLocation, handler);

  void onDriverArrived(void Function(Map<String, dynamic>) handler) =>
      on(ev.SocketEvents.serverDriverArrived, handler);

  void onRideStarted(void Function(Map<String, dynamic>) handler) =>
      on(ev.SocketEvents.serverRideStarted, handler);

  void onRideCompleted(void Function(Map<String, dynamic>) handler) =>
      on(ev.SocketEvents.serverRideCompleted, handler);

  void onDriverCancelled(void Function(Map<String, dynamic>) handler) =>
      on(ev.SocketEvents.serverDriverCancelled, handler);

  void onRideCancelled(void Function(Map<String, dynamic>) handler) =>
      on(ev.SocketEvents.serverRideCancelled, handler);

  void onRideTimeout(void Function(Map<String, dynamic>) handler) =>
      on(ev.SocketEvents.serverRideTimeout, handler);
}

/// Default config pulled from `--dart-define`. Both apps compile
/// these in via the same env vars so dev/prod/parity is automatic.
class SocketDefaults {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000/api/v1',
  );

  static const String wsUrl = String.fromEnvironment(
    'REVERB_WS_URL',
    defaultValue: 'ws://10.0.2.2:8080',
  );

  static const String appKey = String.fromEnvironment(
    'REVERB_APP_KEY',
    defaultValue: 'pothik-local-key',
  );
}
