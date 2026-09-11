import 'dart:async';

import 'package:mobile_core/realtime/pusher_client.dart';

import '../constants/socket_events.dart' as ev;

/// Driver realtime transport backed by Laravel Reverb.
///
/// Drivers subscribe to `private-driver.{driverId}` for dispatch
/// offers, ride cancellations, and dispatch timeouts. They publish
/// `driver:location:update` frames to the same channel so the
/// passenger app can stream the driver's GPS in real time.
class DriverSocketService {
  DriverSocketService({
    required this.apiBaseUrl,
    required this.wsUrl,
    required this.appKey,
    required this.getAuthToken,
    String? driverId,
  // ignore: prefer_initializing_formals
  }) : _driverId = driverId;

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

  String? _driverId;

  PusherRealtimeClient? _client;
  final Map<String, List<void Function(Map<String, dynamic>)>> _handlers = {};
  final Set<String> _subscribed = {};

  bool _disposed = false;

  /// True while the WebSocket is open and the welcome frame has
  /// landed. Cubits can read this to drive a "reconnecting..." banner.
  bool get isConnected => _client?.isConnected ?? false;

  void setDriverId(String id) {
    if (_driverId == id) return;
    _driverId = id;
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
    final id = _driverId;
    if (id == null || id.isEmpty) return;
    _client ??= PusherRealtimeClient(
      apiBaseUrl: apiBaseUrl,
      wsUrl: wsUrl,
      appKey: appKey,
      getAuthToken: getAuthToken,
    );
    await _client!.connect();
    _bindSubscriptions();
  }

  /// Publish a GPS update on the driver's private channel. Skipped
  /// silently when the socket isn't connected yet -- the next
  /// reconnect will pick up the new position from the cubit.
  Future<void> publishLocation({
    required double lat,
    required double lng,
    double? heading,
    double? speed,
  }) async {
    final id = _driverId;
    if (id == null || id.isEmpty) return;
    if (!(_client?.isConnected ?? false)) return;
    await _client!.publishEvent(
      'private-driver.$id',
      ev.SocketEvents.driverLocationUpdate,
      {
        'lat': lat,
        'lng': lng,
        ?heading == null ? null : 'heading': heading,
        ?speed == null ? null : 'speed': speed,
        'ts': DateTime.now().toUtc().toIso8601String(),
      },
    );
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

  String _channel() => 'private-driver.${_driverId ?? ""}';

  void _bindSubscriptions() {
    final client = _client;
    if (client == null) return;
    final ch = _channel();
    for (final event in const [
      ev.SocketEvents.serverRideDispatched,
      ev.SocketEvents.serverRideCancelled,
      ev.SocketEvents.serverRideTimeout,
      // serverDriverCancelled is fired on the driver's private
      // channel when a passenger cancels *after* acceptance. Without
      // this subscription the driver only finds out via the next
      // pull-poll, leaving the cab circling a phantom pickup.
      ev.SocketEvents.serverDriverCancelled,
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
  void onRideDispatched(void Function(Map<String, dynamic>) handler) =>
      on(ev.SocketEvents.serverRideDispatched, handler);

  void onRideCancelled(void Function(Map<String, dynamic>) handler) =>
      on(ev.SocketEvents.serverRideCancelled, handler);

  void onRideTimeout(void Function(Map<String, dynamic>) handler) =>
      on(ev.SocketEvents.serverRideTimeout, handler);

  void onDriverCancelled(void Function(Map<String, dynamic>) handler) =>
      on(ev.SocketEvents.serverDriverCancelled, handler);
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
