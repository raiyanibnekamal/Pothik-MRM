import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:latlong2/latlong.dart';
import 'package:mobile_core/core/models/models.dart';
import 'package:mobile_core/core/network/api_backend.dart';
import 'package:mobile_core/core/network/error_codes.dart';
import 'package:mobile_core/core/network/mock_backend.dart';
import 'package:mobile_core/native/gps_channel.dart';

enum DriverTripPhase {
  idle,
  request,
  toPickup,
  arrived,
  pin,
  toDrop,
  cash,
  rate,
}

class DriverSessionState extends Equatable {
  const DriverSessionState({
    this.online = false,
    this.onBreak = false,
    this.batterySaver = false,
    this.phase = DriverTripPhase.idle,
    this.request,
    this.requestLeft = 15,
    this.pin = '',
    this.pinError = false,
    this.earnings,
    this.busy = false,
    this.error,
    this.rideId,
    this.fareBdt = 0,
    this.cashDone = false,
    this.driverPoint,
    this.tripPickup,
    this.tripDrop,
  });

  final bool online;
  final bool onBreak;
  final bool batterySaver;
  final DriverTripPhase phase;
  final DriverRequest? request;
  final int requestLeft;
  final String pin;
  final bool pinError;
  final EarningsToday? earnings;
  final bool busy;
  final String? error;
  final String? rideId;
  final int fareBdt;
  final bool cashDone;

  /// Latest GPS fix, mirrored from the location cubit for trip logic.
  final LatLng? driverPoint;
  final LatLng? tripPickup;
  final LatLng? tripDrop;

  /// Where the driver should head next, or null when idle.
  LatLng? get navTarget => switch (phase) {
        DriverTripPhase.toPickup ||
        DriverTripPhase.arrived ||
        DriverTripPhase.pin =>
          tripPickup,
        DriverTripPhase.toDrop || DriverTripPhase.cash => tripDrop,
        _ => null,
      };

  DriverSessionState copyWith({
    bool? online,
    bool? onBreak,
    bool? batterySaver,
    DriverTripPhase? phase,
    DriverRequest? request,
    int? requestLeft,
    String? pin,
    bool? pinError,
    EarningsToday? earnings,
    bool? busy,
    String? error,
    String? rideId,
    int? fareBdt,
    bool? cashDone,
    LatLng? driverPoint,
    LatLng? tripPickup,
    LatLng? tripDrop,
    bool clearRequest = false,
    bool clearError = false,
    bool clearTrip = false,
  }) {
    return DriverSessionState(
      online: online ?? this.online,
      onBreak: onBreak ?? this.onBreak,
      batterySaver: batterySaver ?? this.batterySaver,
      phase: phase ?? this.phase,
      request: clearRequest ? null : (request ?? this.request),
      requestLeft: requestLeft ?? this.requestLeft,
      pin: pin ?? this.pin,
      pinError: pinError ?? this.pinError,
      earnings: earnings ?? this.earnings,
      busy: busy ?? this.busy,
      error: clearError ? null : (error ?? this.error),
      rideId: rideId ?? this.rideId,
      fareBdt: fareBdt ?? this.fareBdt,
      cashDone: cashDone ?? this.cashDone,
      driverPoint: driverPoint ?? this.driverPoint,
      tripPickup: clearTrip ? null : (tripPickup ?? this.tripPickup),
      tripDrop: clearTrip ? null : (tripDrop ?? this.tripDrop),
    );
  }

  @override
  List<Object?> get props => [
        online,
        onBreak,
        batterySaver,
        phase,
        request,
        requestLeft,
        pin,
        pinError,
        earnings,
        busy,
        error,
        cashDone,
        driverPoint,
        tripPickup,
        tripDrop,
      ];
}

class DriverSessionCubit extends Cubit<DriverSessionState> {
  DriverSessionCubit(this.backend) : super(const DriverSessionState()) {
    _loadEarnings();
  }

  final MockBackend backend;
  Timer? _ring;
  Timer? _offerTimer;
  Timer? _locationTimer;

  ApiBackend? get _api => backend is ApiBackend ? backend as ApiBackend : null;

  Future<void> _loadEarnings() async {
    final api = _api;
    if (api != null) {
      try {
        final e = await api.fetchEarnings();
        emit(state.copyWith(earnings: e));
        return;
      } catch (_) {
        // fall through to mock
      }
    }
    emit(state.copyWith(earnings: backend.earnings()));
  }

  Future<String?> goOnline({
    required bool debtBlocked,
    required bool graceBlocked,
  }) async {
    if (debtBlocked) return ErrorCodes.debtCap;
    if (graceBlocked) return ErrorCodes.graceOver;
    backend.driverOnline = true;
    emit(state.copyWith(online: true, onBreak: false));
    await GpsChannel.start(batterySaver: state.batterySaver);
    final api = _api;
    if (api != null) {
      try {
        await api.setDriverAvailability(online: true);
      } on ApiException catch (e) {
        emit(state.copyWith(error: e.message));
        return e.code;
      }
      _startLocationStream();
    }
    _offerTimer?.cancel();
    _offerTimer = Timer(const Duration(seconds: 2), _offer);
    return null;
  }

  void goOffline() {
    _ring?.cancel();
    _offerTimer?.cancel();
    _locationTimer?.cancel();
    GpsChannel.stop();
    backend.driverOnline = false;
    final api = _api;
    if (api != null) {
      api.setDriverAvailability(online: false).catchError((_) {});
    }
    emit(state.copyWith(
      online: false,
      onBreak: false,
      phase: DriverTripPhase.idle,
      clearRequest: true,
    ));
  }

  void toggleBreak() {
    if (!state.online) return;
    emit(state.copyWith(onBreak: !state.onBreak));
  }

  void setBatterySaver(bool v) => emit(state.copyWith(batterySaver: v));

  /// Mirrors the live GPS fix so offers and navigation use the real position.
  void updateLocation(LatLng point) {
    if (state.driverPoint == point) return;
    emit(state.copyWith(driverPoint: point));
    _pushLocation(point);
  }

  /// Forwards the latest GPS fix to the API so dispatch can find this driver.
  void _pushLocation(LatLng p) {
    final api = _api;
    if (api == null || !state.online) return;
    api.postDriverLocation(lat: p.latitude, lng: p.longitude).catchError((_) {});
  }

  void _startLocationStream() {
    _locationTimer?.cancel();
    final p = state.driverPoint;
    if (p != null) _pushLocation(p);
    _locationTimer =
        Timer.periodic(const Duration(seconds: 15), (_) {
      final point = state.driverPoint;
      if (point != null) _pushLocation(point);
    });
  }

  Future<void> _offer() async {
    if (!state.online || state.onBreak || isClosed) return;
    final api = _api;
    if (api != null) {
      try {
        final ride = await api.pollForIncomingRequest(
          timeout: const Duration(seconds: 5),
        );
        if (ride != null) {
          final req = DriverRequest(
            rideId: ride.id,
            pickupDistanceKm: 0,
            fareBdt: ride.fare.total,
            dropArea: ride.dropLabel,
            paymentMethod: ride.paymentMethod,
            seconds: 15,
            pickup: ride.pickup,
            drop: ride.drop,
          );
          emit(state.copyWith(
            phase: DriverTripPhase.request,
            request: req,
            requestLeft: 15,
            rideId: ride.id,
            fareBdt: ride.fare.total,
          ));
          _ring?.cancel();
          _ring = Timer.periodic(const Duration(seconds: 1), (t) {
            final left = state.requestLeft - 1;
            if (left <= 0) {
              t.cancel();
              emit(state.copyWith(
                phase: DriverTripPhase.idle,
                clearRequest: true,
                requestLeft: 15,
              ));
            } else {
              emit(state.copyWith(requestLeft: left));
            }
          });
          return;
        }
      } on ApiException catch (_) {
        // ignore — try again on next tick
      }
      // Schedule the next poll.
      _offerTimer = Timer(const Duration(seconds: 3), _offer);
      return;
    }
    // Mock fallback.
    final req = backend.spawnRequest(driverAt: state.driverPoint);
    emit(state.copyWith(
      phase: DriverTripPhase.request,
      request: req,
      requestLeft: 15,
    ));
    _ring?.cancel();
    _ring = Timer.periodic(const Duration(seconds: 1), (t) {
      final left = state.requestLeft - 1;
      if (left <= 0) {
        t.cancel();
        emit(state.copyWith(
          phase: DriverTripPhase.idle,
          clearRequest: true,
          requestLeft: 15,
        ));
      } else {
        emit(state.copyWith(requestLeft: left));
      }
    });
  }

  void decline() {
    final id = state.rideId ?? state.request?.rideId;
    _ring?.cancel();
    emit(state.copyWith(phase: DriverTripPhase.idle, clearRequest: true));
    final api = _api;
    if (api != null && id != null) {
      api.declineRide(id).catchError((_) {});
    }
  }

  Future<void> accept() async {
    _ring?.cancel();
    final req = state.request;
    emit(state.copyWith(
      phase: DriverTripPhase.toPickup,
      rideId: req?.rideId,
      fareBdt: req?.fareBdt ?? 250,
      tripPickup: req?.pickup,
      tripDrop: req?.drop,
      clearRequest: true,
    ));
    final api = _api;
    if (api != null && req != null) {
      try {
        final ride = await api.acceptRide(req.rideId);
        emit(state.copyWith(
          pin: ride?.pin ?? state.pin,
          fareBdt: ride?.fare.total ?? req.fareBdt,
        ));
      } on ApiException catch (e) {
        emit(state.copyWith(error: e.message, phase: DriverTripPhase.idle));
      }
    }
  }

  Future<void> arrived() async {
    emit(state.copyWith(phase: DriverTripPhase.arrived));
    final api = _api;
    final id = state.rideId;
    if (api != null && id != null) {
      try {
        await api.markArrived(id);
      } on ApiException catch (e) {
        emit(state.copyWith(error: e.message));
      }
    }
  }

  void openPin() => emit(state.copyWith(phase: DriverTripPhase.pin, pin: ''));

  void setPin(String v) => emit(state.copyWith(pin: v, pinError: false));

  Future<bool> submitPin() async {
    final pin = state.pin;
    final api = _api;
    final id = state.rideId;
    if (api != null && id != null) {
      try {
        await api.verifyRidePin(rideId: id, pin: pin);
        emit(state.copyWith(phase: DriverTripPhase.toDrop, pinError: false));
        return true;
      } on ApiException catch (e) {
        emit(state.copyWith(pinError: true, pin: '', error: e.message));
        return false;
      }
    }
    // Mock fallback — accept any 4-digit PIN locally.
    if (pin.length < 4) {
      emit(state.copyWith(pinError: true, pin: ''));
      return false;
    }
    emit(state.copyWith(phase: DriverTripPhase.toDrop, pinError: false));
    return true;
  }

  void openCash() => emit(state.copyWith(phase: DriverTripPhase.cash));

  Future<void> confirmCash() async {
    emit(state.copyWith(busy: true, clearError: true));
    final amount = state.fareBdt == 0 ? 250 : state.fareBdt;
    try {
      await backend.confirmCash(amount);
      await _loadEarnings();
      emit(state.copyWith(
        busy: false,
        cashDone: true,
        phase: DriverTripPhase.rate,
      ));
    } on ApiException catch (e) {
      emit(state.copyWith(busy: false, error: e.message));
    }
  }

  void finishTrip() {
    if (state.cashDone && state.rideId != null && state.fareBdt > 0) {
      backend.recordDriverTrip(
        rideId: state.rideId!,
        fareBdt: state.fareBdt,
        pickup: state.tripPickup,
        drop: state.tripDrop,
      );
    }
    emit(state.copyWith(
      phase: DriverTripPhase.idle,
      cashDone: false,
      pin: '',
      rideId: null,
      clearTrip: true,
    ));
    if (state.online) {
      _offerTimer?.cancel();
      _offerTimer = Timer(const Duration(seconds: 8), _offer);
    }
  }

  @override
  Future<void> close() {
    _ring?.cancel();
    _offerTimer?.cancel();
    _locationTimer?.cancel();
    return super.close();
  }
}
