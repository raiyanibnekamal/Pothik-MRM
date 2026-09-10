import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
    bool clearRequest = false,
    bool clearError = false,
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
    );
  }

  @override
  List<Object?> get props => [
        online,
        onBreak,
        phase,
        request,
        requestLeft,
        pin,
        pinError,
        earnings,
        busy,
        error,
        cashDone,
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

  void _offer() {
    if (!state.online || state.onBreak) return;
    final req = backend.spawnRequest();
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
      );
    }
    emit(state.copyWith(
      phase: DriverTripPhase.idle,
      cashDone: false,
      pin: '',
      rideId: null,
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
