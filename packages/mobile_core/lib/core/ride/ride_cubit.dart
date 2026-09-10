import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:latlong2/latlong.dart';
import 'package:mobile_core/core/models/models.dart';
import 'package:mobile_core/core/network/error_codes.dart';
import 'package:mobile_core/core/network/mock_backend.dart';

enum RidePhase {
  idle,
  estimating,
  finding,
  noDriver,
  matched,
  tracking,
  complete,
}

class RideState extends Equatable {
  const RideState({
    this.phase = RidePhase.idle,
    this.pickup = dhakaPickup,
    this.drop,
    this.pickupLabel = 'Gulshan 2',
    this.dropLabel,
    this.types = const [],
    this.selectedType,
    this.ride,
    this.showDriverSheet = false,
    this.busy = false,
    this.error,
    this.matchedAt,
  });

  static const dhakaPickup = LatLng(23.7925, 90.4078);

  final RidePhase phase;
  final LatLng pickup;
  final LatLng? drop;
  final String pickupLabel;
  final String? dropLabel;
  final List<VehicleType> types;
  final VehicleType? selectedType;
  final Ride? ride;
  final bool showDriverSheet;
  final bool busy;
  final String? error;
  final DateTime? matchedAt;

  RideState copyWith({
    RidePhase? phase,
    LatLng? pickup,
    LatLng? drop,
    String? pickupLabel,
    String? dropLabel,
    List<VehicleType>? types,
    VehicleType? selectedType,
    Ride? ride,
    bool? showDriverSheet,
    bool? busy,
    String? error,
    DateTime? matchedAt,
    bool clearDrop = false,
    bool clearRide = false,
    bool clearError = false,
  }) {
    return RideState(
      phase: phase ?? this.phase,
      pickup: pickup ?? this.pickup,
      drop: clearDrop ? null : (drop ?? this.drop),
      pickupLabel: pickupLabel ?? this.pickupLabel,
      dropLabel: dropLabel ?? this.dropLabel,
      types: types ?? this.types,
      selectedType: selectedType ?? this.selectedType,
      ride: clearRide ? null : (ride ?? this.ride),
      showDriverSheet: showDriverSheet ?? this.showDriverSheet,
      busy: busy ?? this.busy,
      error: clearError ? null : (error ?? this.error),
      matchedAt: matchedAt ?? this.matchedAt,
    );
  }

  @override
  List<Object?> get props =>
      [phase, drop, selectedType, ride, showDriverSheet, busy, error];
}

class RideCubit extends Cubit<RideState> {
  RideCubit(this.backend) : super(const RideState()) {
    emit(state.copyWith(types: backend.types, selectedType: MockBackend.bike));
  }

  final MockBackend backend;

  void setDrop(LatLng p, String label) {
    emit(state.copyWith(drop: p, dropLabel: label));
  }

  void selectType(VehicleType t) => emit(state.copyWith(selectedType: t));

  FareBreakdown breakdownFor(VehicleType t) {
    const d = Distance();
    final drop = state.drop ?? const LatLng(23.7936, 90.4056);
    final km = d.as(LengthUnit.Kilometer, state.pickup, drop);
    return backend.estimate(t, km < 1 ? 3.2 : km);
  }

  Future<void> book() async {
    final drop = state.drop;
    final type = state.selectedType;
    if (drop == null || type == null) return;
    emit(state.copyWith(busy: true, phase: RidePhase.finding, clearError: true));
    try {
      final ride = await backend.createRide(
        pickup: state.pickup,
        drop: drop,
        pickupLabel: state.pickupLabel,
        dropLabel: state.dropLabel ?? '',
        type: type,
      );
      emit(state.copyWith(busy: false, ride: ride, phase: RidePhase.finding));
      try {
        final matched = await backend.matchDemo();
        emit(state.copyWith(
          ride: matched,
          phase: RidePhase.matched,
          showDriverSheet: true,
          matchedAt: DateTime.now(),
        ));
      } on ApiException catch (e) {
        emit(state.copyWith(phase: RidePhase.noDriver, error: e.message));
      }
    } on ApiException catch (e) {
      emit(state.copyWith(busy: false, phase: RidePhase.idle, error: e.message));
    }
  }

  void ackDriverSheet() {
    emit(state.copyWith(showDriverSheet: false, phase: RidePhase.tracking));
    backend.advance(RideStatus.driverArriving);
  }

  Future<void> markInProgress() async {
    final ride = await backend.advance(RideStatus.inProgress);
    emit(state.copyWith(ride: ride, phase: RidePhase.tracking));
  }

  Future<void> complete() async {
    final ride = await backend.advance(RideStatus.completed);
    emit(state.copyWith(ride: ride, phase: RidePhase.complete));
  }

  Future<void> cancel() async {
    await backend.advance(RideStatus.cancelled);
    backend.activeRide = null;
    emit(state.copyWith(
      phase: RidePhase.idle,
      clearRide: true,
      showDriverSheet: false,
    ));
  }

  Future<void> rateAndReset() async {
    await backend.completeAndRate();
    emit(RideState(
      types: backend.types,
      selectedType: MockBackend.bike,
      pickup: state.pickup,
      pickupLabel: state.pickupLabel,
    ));
  }

  void retryFind() => book();

  void goIdle() => emit(state.copyWith(phase: RidePhase.idle, clearRide: true));
}
