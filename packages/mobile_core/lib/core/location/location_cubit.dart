import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:mobile_core/native/gps_channel.dart';

enum LocationStatus {
  idle,
  checking,
  ready,
  denied,
  deniedForever,
  serviceOff,
  failed,
}

class LocationState extends Equatable {
  const LocationState({
    this.status = LocationStatus.idle,
    this.point,
    this.accuracyM,
    this.headingDeg,
    this.speedMps,
    this.updatedAt,
    this.streaming = false,
  });

  final LocationStatus status;
  final LatLng? point;
  final double? accuracyM;
  final double? headingDeg;
  final double? speedMps;
  final DateTime? updatedAt;
  final bool streaming;

  bool get hasFix => point != null;
  bool get blocked =>
      status == LocationStatus.denied ||
      status == LocationStatus.deniedForever ||
      status == LocationStatus.serviceOff;

  /// GPS fixes better than 50 m are good enough to trust as a pickup point.
  bool get isPrecise => (accuracyM ?? double.infinity) <= 50;

  LocationState copyWith({
    LocationStatus? status,
    LatLng? point,
    double? accuracyM,
    double? headingDeg,
    double? speedMps,
    DateTime? updatedAt,
    bool? streaming,
  }) {
    return LocationState(
      status: status ?? this.status,
      point: point ?? this.point,
      accuracyM: accuracyM ?? this.accuracyM,
      headingDeg: headingDeg ?? this.headingDeg,
      speedMps: speedMps ?? this.speedMps,
      updatedAt: updatedAt ?? this.updatedAt,
      streaming: streaming ?? this.streaming,
    );
  }

  @override
  List<Object?> get props =>
      [status, point, accuracyM, headingDeg, streaming, updatedAt];
}

/// Single source of truth for "where am I" across passenger and driver maps.
class LocationCubit extends Cubit<LocationState> {
  LocationCubit() : super(const LocationState());

  StreamSubscription<Position>? _sub;
  StreamSubscription<dynamic>? _nativeSub;

  /// Merges fixes from the driver app's foreground service, which keeps
  /// reporting when Flutter is backgrounded.
  void bindNativeUpdates() {
    _nativeSub ??= GpsChannel.events.receiveBroadcastStream().listen(
      (event) {
        if (event is! Map) return;
        final lat = (event['lat'] as num?)?.toDouble();
        final lng = (event['lng'] as num?)?.toDouble();
        if (lat == null || lng == null || isClosed) return;
        emit(state.copyWith(
          status: LocationStatus.ready,
          point: LatLng(lat, lng),
          accuracyM: (event['accuracy'] as num?)?.toDouble(),
          speedMps: (event['speed'] as num?)?.toDouble(),
          updatedAt: DateTime.now(),
        ));
      },
      onError: (_) {},
    );
  }

  /// Asks for permission and publishes a first fix. Returns true when usable.
  Future<bool> ensure({bool request = true}) async {
    emit(state.copyWith(status: LocationStatus.checking));

    if (!await Geolocator.isLocationServiceEnabled()) {
      emit(state.copyWith(status: LocationStatus.serviceOff));
      return false;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied && request) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      emit(state.copyWith(status: LocationStatus.deniedForever));
      return false;
    }
    if (permission == LocationPermission.denied) {
      emit(state.copyWith(status: LocationStatus.denied));
      return false;
    }

    await _seedLastKnown();
    return refresh();
  }

  /// One-shot high accuracy fix.
  Future<bool> refresh() async {
    try {
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
      _publish(p);
      return true;
    } on TimeoutException {
      if (!state.hasFix) emit(state.copyWith(status: LocationStatus.failed));
      return state.hasFix;
    } catch (_) {
      if (!state.hasFix) emit(state.copyWith(status: LocationStatus.failed));
      return state.hasFix;
    }
  }

  /// Continuous updates. `highAccuracy: false` is the battery saver profile.
  Future<void> startStream({bool highAccuracy = true}) async {
    if (state.streaming) return;
    if (!state.hasFix && !await ensure()) return;

    await _sub?.cancel();
    _sub = Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy:
            highAccuracy ? LocationAccuracy.high : LocationAccuracy.medium,
        distanceFilter: highAccuracy ? 5 : 25,
      ),
    ).listen(_publish, onError: (_) {});
    emit(state.copyWith(streaming: true));
  }

  Future<void> stopStream() async {
    await _sub?.cancel();
    _sub = null;
    if (!isClosed) emit(state.copyWith(streaming: false));
  }

  Future<void> restartStream({required bool highAccuracy}) async {
    await stopStream();
    await startStream(highAccuracy: highAccuracy);
  }

  Future<void> openSettings() async {
    if (state.status == LocationStatus.serviceOff) {
      await Geolocator.openLocationSettings();
    } else {
      await Geolocator.openAppSettings();
    }
  }

  /// Web has no cached fix, so failures here are expected and ignored.
  Future<void> _seedLastKnown() async {
    if (state.hasFix) return;
    try {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) _publish(last);
    } catch (_) {
      return;
    }
  }

  void _publish(Position p) {
    if (isClosed) return;
    emit(state.copyWith(
      status: LocationStatus.ready,
      point: LatLng(p.latitude, p.longitude),
      accuracyM: p.accuracy,
      headingDeg: p.heading,
      speedMps: p.speed,
      updatedAt: DateTime.now(),
    ));
  }

  @override
  Future<void> close() {
    _sub?.cancel();
    _nativeSub?.cancel();
    return super.close();
  }
}
