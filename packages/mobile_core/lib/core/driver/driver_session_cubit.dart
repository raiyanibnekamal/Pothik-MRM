import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:latlong2/latlong.dart';
import 'package:mobile_core/core/models/models.dart';
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
    emit(state.copyWith(earnings: backend.earnings()));
  }

  final MockBackend backend;
  Timer? _ring;
  Timer? _demoOffer;

  Future<String?> goOnline({
    required bool debtBlocked,
    required bool graceBlocked,
  }) async {
    if (debtBlocked) return ErrorCodes.debtCap;
    if (graceBlocked) return ErrorCodes.graceOver;
    backend.driverOnline = true;
    emit(state.copyWith(online: true, onBreak: false));
    await GpsChannel.start(batterySaver: state.batterySaver);
    _demoOffer?.cancel();
    _demoOffer = Timer(const Duration(seconds: 2), _offer);
    return null;
  }

  void goOffline() {
    _ring?.cancel();
    _demoOffer?.cancel();
    GpsChannel.stop();
    backend.driverOnline = false;
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
  }

  void _offer() {
    if (!state.online || state.onBreak) return;
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
    _ring?.cancel();
    emit(state.copyWith(phase: DriverTripPhase.idle, clearRequest: true));
  }

  void accept() {
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
  }

  void arrived() => emit(state.copyWith(phase: DriverTripPhase.arrived));

  void openPin() => emit(state.copyWith(phase: DriverTripPhase.pin, pin: ''));

  void setPin(String v) => emit(state.copyWith(pin: v, pinError: false));

  bool submitPin() {
    if (state.pin != '4821') {
      emit(state.copyWith(pinError: true, pin: ''));
      return false;
    }
    emit(state.copyWith(phase: DriverTripPhase.toDrop, pinError: false));
    return true;
  }

  void openCash() => emit(state.copyWith(phase: DriverTripPhase.cash));

  Future<void> confirmCash() async {
    emit(state.copyWith(busy: true, clearError: true));
    try {
      await backend.confirmCash(state.fareBdt == 0 ? 250 : state.fareBdt);
      emit(state.copyWith(
        busy: false,
        cashDone: true,
        phase: DriverTripPhase.rate,
        earnings: backend.earnings(),
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
      _demoOffer?.cancel();
      _demoOffer = Timer(const Duration(seconds: 8), _offer);
    }
  }

  @override
  Future<void> close() {
    _ring?.cancel();
    _demoOffer?.cancel();
    return super.close();
  }
}
