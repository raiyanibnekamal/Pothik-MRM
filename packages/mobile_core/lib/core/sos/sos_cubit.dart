import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile_core/core/models/models.dart';
import 'package:mobile_core/core/network/error_codes.dart';
import 'package:mobile_core/core/network/mock_backend.dart';

class SosState extends Equatable {
  const SosState({
    this.alert,
    this.countdown = false,
    this.secondsLeft = 5,
    this.error,
  });

  final SosAlert? alert;
  final bool countdown;
  final int secondsLeft;
  final String? error;

  bool get active => alert?.status == 'active';

  SosState copyWith({
    SosAlert? alert,
    bool? countdown,
    int? secondsLeft,
    String? error,
    bool clearAlert = false,
    bool clearError = false,
  }) {
    return SosState(
      alert: clearAlert ? null : (alert ?? this.alert),
      countdown: countdown ?? this.countdown,
      secondsLeft: secondsLeft ?? this.secondsLeft,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [alert, countdown, secondsLeft, error];
}

class SosCubit extends Cubit<SosState> {
  SosCubit(this.backend) : super(const SosState());

  final MockBackend backend;

  void beginCountdown() {
    emit(const SosState(countdown: true, secondsLeft: 5));
  }

  void tick() {
    if (!state.countdown) return;
    final next = state.secondsLeft - 1;
    emit(state.copyWith(secondsLeft: next));
  }

  void abortCountdown() {
    emit(const SosState());
  }

  Future<void> send({required RideStatus? rideStatus, required bool driverOnline}) async {
    final passengerOk = rideStatus == RideStatus.inProgress;
    final allowed = passengerOk || driverOnline;
    try {
      final alert = await backend.triggerSos(allowed: allowed);
      emit(SosState(alert: alert));
    } on ApiException catch (e) {
      emit(state.copyWith(countdown: false, error: e.message));
    }
  }

  Future<void> cancelAlert() async {
    await backend.cancelSos();
    emit(const SosState());
  }
}
