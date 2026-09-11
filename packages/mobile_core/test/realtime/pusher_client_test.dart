import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_core/realtime/pusher_client.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class FakeWebSocketChannel extends StreamChannelMixin<dynamic>
    implements WebSocketChannel {
  final StreamController<dynamic> _ctrl = StreamController<dynamic>.broadcast();
  final List<String> sent = [];
  late final WebSocketSink _sink;
  bool closed = false;
  String? _protocol;
  int? _closeCode;
  String? _closeReason;
  final Completer<void> _ready = Completer<void>();

  FakeWebSocketChannel({String? protocol}) {
    _protocol = protocol;
    _sink = _CapturingSink(this);
    _ready.complete();
  }

  void pushJson(Map<String, dynamic> frame) => _ctrl.add(jsonEncode(frame));

  void errorOut(Object err) => _ctrl.addError(err);

  void closeDown({int? code, String? reason}) {
    if (closed) return;
    closed = true;
    _closeCode = code;
    _closeReason = reason;
    if (!_ctrl.isClosed) _ctrl.close();
  }

  @override
  Stream<dynamic> get stream => _ctrl.stream;

  @override
  WebSocketSink get sink => _sink;

  @override
  String? get protocol => _protocol;

  @override
  int? get closeCode => _closeCode;

  @override
  String? get closeReason => _closeReason;

  @override
  Future<void> get ready => _ready.future;
}

class _CapturingSink implements WebSocketSink {
  _CapturingSink(this._owner);
  final FakeWebSocketChannel _owner;

  @override
  void add(dynamic data) {
    if (data is String) _owner.sent.add(data);
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  Future addStream(Stream<dynamic> stream) async {}

  @override
  Future close([int? closeCode, String? closeReason]) async {
    _owner.closeDown(code: closeCode, reason: closeReason);
  }

  @override
  Future get done => Future.value();
}

class _StubHttp extends http.BaseClient {
  _StubHttp(this.responder);
  final Future<http.Response> Function(http.BaseRequest req) responder;
  final List<http.BaseRequest> seen = [];
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    seen.add(request);
    final resp = await responder(request);
    return http.StreamedResponse(
      Stream.value(utf8.encode(resp.body)),
      resp.statusCode,
      headers: resp.headers,
    );
  }
}

Map<String, dynamic> _decode(String s) =>
    jsonDecode(s) as Map<String, dynamic>;

void main() {
  group('PusherRealtimeClient', () {
    late _StubHttp httpClient;
    late FakeWebSocketChannel fakeSocket;
    late List<FakeWebSocketChannel> socketPool;
    late PusherRealtimeClient client;

    setUp(() {
      httpClient = _StubHttp((req) async {
        return http.Response(
          jsonEncode({'auth': 'app-key:fake-signature'}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      socketPool = [];
      fakeSocket = FakeWebSocketChannel();
      socketPool.add(fakeSocket);
      client = PusherRealtimeClient(
        apiBaseUrl: 'https://api.example.test/api/v1',
        wsUrl: 'wss://ws.example.test',
        appKey: 'app-key',
        getAuthToken: () async => 'jwt-token',
        httpClient: httpClient,
        channelFactory: (uri) async {
          if (socketPool.isEmpty) {
            socketPool.add(FakeWebSocketChannel());
          }
          return socketPool.removeAt(0);
        },
        heartbeatInterval: const Duration(milliseconds: 60),
        reconnectMin: const Duration(milliseconds: 10),
        reconnectMax: const Duration(milliseconds: 30),
      );
    });

    tearDown(() async {
      await client.dispose();
    });

    Future<void> connectAndEstablish() async {
      await client.connect();
      fakeSocket.pushJson({
        'event': 'pusher:connection_established',
        'data': jsonEncode({'socket_id': 's.s', 'activity_timeout': 30}),
      });
      while (!client.isConnected) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
    }

    test('connect + welcome sets isConnected and socketId', () async {
      await connectAndEstablish();
      expect(client.isConnected, isTrue);
      expect(client.socketId, 's.s');
    });

    test('private subscribe POSTs auth then sends subscribe frame', () async {
      await connectAndEstablish();
      final stream =
          client.subscribe('private-driver.42', 'server:ride:dispatched');
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(httpClient.seen, hasLength(1));
      final req = httpClient.seen.first;
      expect(req.url.toString(),
          'https://api.example.test/api/v1/broadcasting/auth');
      expect(req.headers['Authorization'], 'Bearer jwt-token');

      final subs = fakeSocket.sent
          .where((s) => _decode(s)['event'] == 'pusher:subscribe');
      expect(subs, hasLength(1));
      final sub = _decode(subs.first);
      expect(sub['event'], 'pusher:subscribe');
      final subData = jsonDecode(sub['data'] as String) as Map<String, dynamic>;
      expect(subData['channel'], 'private-driver.42');
      expect(subData['auth'], 'app-key:fake-signature');
      expect(stream.isBroadcast, isTrue);
    });

    test('public subscribe skips auth POST', () async {
      await connectAndEstablish();
      client.subscribe('public-news', 'news:headline');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(httpClient.seen, isEmpty);
      final subs = fakeSocket.sent
          .where((s) => _decode(s)['event'] == 'pusher:subscribe');
      expect(subs, hasLength(1));
      final sub = _decode(subs.first);
      final subData = jsonDecode(sub['data'] as String) as Map<String, dynamic>;
      expect(subData['channel'], 'public-news');
      expect(subData.containsKey('auth'), isFalse);
    });

    test('dispatches server events on the matching channel stream', () async {
      await connectAndEstablish();
      final received = <Map<String, dynamic>>[];
      final sub = client
          .subscribe('private-driver.42', 'server:ride:dispatched')
          .listen(received.add);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      fakeSocket.pushJson({
        'event': 'server:ride:dispatched',
        'channel': 'private-driver.42',
        'data': jsonEncode({'ride_id': 'r1', 'pickup': 'Gulshan'}),
      });
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(received, hasLength(1));
      expect(received.first['ride_id'], 'r1');
      expect(received.first['pickup'], 'Gulshan');
      await sub.cancel();
    });

    test('publishEvent encodes and sends a client event', () async {
      await connectAndEstablish();
      await client.publishEvent(
        'private-driver.42',
        'driver:location:update',
        {'lat': 23.79, 'lng': 90.40},
      );
      final locationFrames = fakeSocket.sent
          .where((s) => _decode(s)['event'] == 'driver:location:update');
      expect(locationFrames, hasLength(1));
      final frame = _decode(locationFrames.first);
      expect(frame['event'], 'driver:location:update');
      final inner = jsonDecode(frame['data'] as String) as Map<String, dynamic>;
      expect(inner['channel'], 'private-driver.42');
      final payload =
          jsonDecode(inner['data'] as String) as Map<String, dynamic>;
      expect(payload['lat'], 23.79);
    });

    test('pings every heartbeatInterval', () async {
      await connectAndEstablish();
      await Future<void>.delayed(const Duration(milliseconds: 200));
      final pings = fakeSocket.sent
          .where((s) => _decode(s)['event'] == 'pusher:ping')
          .toList();
      expect(pings.length, greaterThanOrEqualTo(1));
    });

    test('reconnects when WS closes unexpectedly', () async {
      await connectAndEstablish();
      final nextSocket = FakeWebSocketChannel();
      socketPool.add(nextSocket);

      fakeSocket.closeDown();
      await Future<void>.delayed(const Duration(milliseconds: 80));

      nextSocket.pushJson({
        'event': 'pusher:connection_established',
        'data': jsonEncode({'socket_id': 's2.s2', 'activity_timeout': 30}),
      });
      while (!client.isConnected) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      expect(client.socketId, 's2.s2');
    });

    test('skips subscribe when channel auth returns non-200', () async {
      final failing = _StubHttp((req) async => http.Response('forbidden', 403));
      await client.dispose();
      socketPool.clear();
      fakeSocket = FakeWebSocketChannel();
      socketPool.add(fakeSocket);
      client = PusherRealtimeClient(
        apiBaseUrl: 'https://api.example.test/api/v1',
        wsUrl: 'wss://ws.example.test',
        appKey: 'app-key',
        getAuthToken: () async => 'jwt-token',
        httpClient: failing,
        channelFactory: (_) async => fakeSocket,
        heartbeatInterval: const Duration(seconds: 60),
        reconnectMin: const Duration(seconds: 30),
        reconnectMax: const Duration(seconds: 30),
      );
      await connectAndEstablish();
      client.subscribe('private-driver.42', 'server:ride:dispatched');
      await Future<void>.delayed(const Duration(milliseconds: 30));
      final subs = fakeSocket.sent
          .where((s) => _decode(s)['event'] == 'pusher:subscribe');
      expect(subs, isEmpty);
    });
  });
}
