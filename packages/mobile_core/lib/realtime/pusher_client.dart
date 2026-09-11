import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Lightweight Pusher-protocol WebSocket client for Laravel Reverb.
///
/// Laravel Reverb speaks the Pusher Channels wire protocol (`pusher-js`
/// over WebSocket). This class is a minimal Dart implementation:
///   - opens a WebSocket to `wss://{host}:{port}/{appKey}?protocol=7&...`
///   - handles `pusher:connection_established`
///   - subscribes to channels (private channels are authorised via
///     `POST {apiBase}/broadcasting/auth` returning `{auth: "..."}`)
///   - heartbeats every 30s with `pusher:ping` / `pusher:pong`
///   - dispatches incoming server events to typed handlers
///
/// The class is transport-agnostic about the actual WS handle so tests
/// can swap in an in-memory channel and assert on the protocol frames
/// without touching a real socket.
class PusherRealtimeClient {
  PusherRealtimeClient({
    required this.apiBaseUrl,
    required this.wsUrl,
    required this.appKey,
    required this.getAuthToken,
    http.Client? httpClient,
    Future<WebSocketChannel> Function(Uri uri)? channelFactory,
    this._heartbeatInterval = const Duration(seconds: 30),
    this._reconnectMin = const Duration(seconds: 1),
    this._reconnectMax = const Duration(seconds: 30),
  })  : _httpClient = httpClient ?? http.Client(),
        _channelFactory = channelFactory ?? _defaultChannelFactory;

  /// REST base, e.g. `https://api.bdride.test`. Used for the
  /// broadcasting auth handshake (`POST /broadcasting/auth`).
  final String apiBaseUrl;

  /// WebSocket origin, e.g. `wss://ws.bdride.test`.
  final String wsUrl;

  /// App key the Reverb/Pusher server expects in the WS path.
  final String appKey;

  /// Returns the current JWT (or empty string when signed out). The
  /// client calls this on every reconnect â€” never cache the token
  /// inside the service, the auth cubit owns it.
  final Future<String> Function() getAuthToken;

  final http.Client _httpClient;
  final Future<WebSocketChannel> Function(Uri uri) _channelFactory;
  final Duration _heartbeatInterval;
  final Duration _reconnectMin;
  final Duration _reconnectMax;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _wsSub;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;
  bool _disposed = false;
  bool _connected = false;
  int _attempt = 0;
  String? _socketId;

  final Map<String, StreamController<Map<String, dynamic>>> _eventControllers =
      {};
  final Set<String> _subscribed = {};

  bool get isConnected => _connected;
  String? get socketId => _socketId;

  /// Subscribe to a server-named event on a channel. Returns a Stream
  /// that emits the decoded payload for each incoming event.
  Stream<Map<String, dynamic>> subscribe(
    String channel,
    String eventName,
  ) {
    final key = '$channel::$eventName';
    final ctrl = _eventControllers.putIfAbsent(
      key,
      () => StreamController<Map<String, dynamic>>.broadcast(),
    );
    if (_connected && !_subscribed.contains(channel)) {
      unawaited(_sendSubscribe(channel));
    }
    return ctrl.stream;
  }

  /// Send a client-originated event (e.g. `driver:location:update`).
  /// Most apps only need this for driver GPS streaming.
  Future<void> publishEvent(
    String channel,
    String eventName,
    Map<String, dynamic> payload,
  ) async {
    if (!_connected) return;
    _send(eventName, {
      'event': eventName,
      'channel': channel,
      'data': jsonEncode(payload),
    });
  }

  Future<void> connect() async {
    if (_disposed) return;
    final token = await getAuthToken();
    if (token.isEmpty) {
      _scheduleReconnect();
      return;
    }

    final uri = _buildWsUri();
    try {
      final ch = await _channelFactory(uri);
      _channel = ch;
      _wsSub = ch.stream.listen(
        _handleFrame,
        onError: (Object err, StackTrace _) => _onWsError(err),
        onDone: _onWsClosed,
        cancelOnError: true,
      );
    } catch (_) {
      _connected = false;
      _scheduleReconnect();
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    _heartbeatTimer?.cancel();
    _reconnectTimer?.cancel();
    await _wsSub?.cancel();
    await _channel?.sink.close();
    for (final ctrl in _eventControllers.values) {
      await ctrl.close();
    }
    _eventControllers.clear();
    _connected = false;
  }

  // ---------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------

  Uri _buildWsUri() {
    // Pusher protocol 7 query params. Reverb ignores client/version
    // and only cares about protocol=7 + the path's appKey prefix.
    final ws = Uri.parse(wsUrl);
    final scheme = ws.scheme == 'wss' ? 'wss' : 'ws';
    return Uri(
      scheme: scheme,
      host: ws.host,
      port: ws.hasPort ? ws.port : null,
      path: '/$appKey',
      queryParameters: {
        'protocol': '7',
        'client': 'mobile_core',
        'version': '1.0.0',
      },
    );
  }

  static Future<WebSocketChannel> _defaultChannelFactory(Uri uri) async {
    return IOWebSocketChannel.connect(
      uri,
      pingInterval: const Duration(seconds: 25),
    );
  }

  void _handleFrame(dynamic raw) {
    if (raw is! String) return;
    Map<String, dynamic> frame;
    try {
      frame = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    final event = frame['event'] as String?;
    final data = frame['data'];
    switch (event) {
      case 'pusher:connection_established':
        _onConnected(data);
        break;
      case 'pusher:pong':
        // Heartbeat reply â€” nothing to do.
        break;
      case 'pusher:error':
        _onWsError(data);
        break;
      default:
        // Server-originated event on a channel: dispatch to handler.
        final channel = frame['channel'] as String?;
        if (channel != null) {
          final key = '$channel::$event';
          final ctrl = _eventControllers[key];
          Map<String, dynamic>? payload;
          if (data is String) {
            try {
              payload = jsonDecode(data) as Map<String, dynamic>;
            } catch (_) {
              payload = {'_raw': data};
            }
          } else if (data is Map<String, dynamic>) {
            payload = data;
          }
          if (ctrl != null && payload != null) ctrl.add(payload);
        }
        break;
    }
  }

  void _onConnected(dynamic data) {
    Map<String, dynamic>? parsed;
    if (data is String) {
      try {
        parsed = jsonDecode(data) as Map<String, dynamic>;
      } catch (_) {
        parsed = null;
      }
    }
    _socketId = parsed?['socket_id'] as String?;
    _connected = true;
    _attempt = 0;
    _startHeartbeat();
    // Re-subscribe every channel that callers asked for while we were
    // disconnected (and any new ones we never got around to binding).
    for (final ch in _eventControllers.keys.map((k) => k.split('::').first)) {
      unawaited(_sendSubscribe(ch));
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) {
      if (_connected) {
        _send('pusher:ping', null);
      }
    });
  }

  Future<void> _sendSubscribe(String channel) async {
    if (_subscribed.contains(channel)) return;
    _subscribed.add(channel);
    if (channel.startsWith('private-') || channel.startsWith('presence-')) {
      final auth = await _authoriseChannel(channel);
      if (auth == null) {
        _subscribed.remove(channel);
        return;
      }
      _send('pusher:subscribe', {
        'channel': channel,
        'auth': auth,
      });
    } else {
      _send('pusher:subscribe', {'channel': channel});
    }
  }

  Future<String?> _authoriseChannel(String channel) async {
    final token = await getAuthToken();
    if (token.isEmpty) return null;
    final authUri = Uri.parse('$apiBaseUrl/broadcasting/auth');
    final body = {
      'socket_id': _socketId ?? '',
      'channel_name': channel,
    };
    try {
      final resp = await _httpClient.post(
        authUri,
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: body,
      );
      if (resp.statusCode != 200) return null;
      final json = jsonDecode(resp.body) as Map<String, dynamic>;
      return json['auth'] as String?;
    } catch (_) {
      return null;
    }
  }

  void _send(String event, Map<String, dynamic>? data) {
    final frame = <String, dynamic>{'event': event};
    if (data != null) frame['data'] = jsonEncode(data);
    try {
      _channel?.sink.add(jsonEncode(frame));
    } catch (_) {
      // Socket likely torn down â€” let the onDone path reconnect.
    }
  }

  void _onWsError(Object _) {
    _connected = false;
    _heartbeatTimer?.cancel();
    _scheduleReconnect();
  }

  void _onWsClosed() {
    _connected = false;
    _heartbeatTimer?.cancel();
    if (!_disposed) _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_disposed) return;
    _attempt += 1;
    final seconds = (_attempt.clamp(1, 6));
    final delay = Duration(seconds: 1 << seconds);
    final clamped = delay < _reconnectMin
        ? _reconnectMin
        : (delay > _reconnectMax ? _reconnectMax : delay);
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(clamped, connect);
  }
}




