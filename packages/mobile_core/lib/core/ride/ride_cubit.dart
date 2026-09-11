import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:latlong2/latlong.dart';
import 'package:mobile_core/core/location/route_service.dart';
import 'package:mobile_core/core/models/models.dart';
import 'package:mobile_core/core/network/api_backend.dart';
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
    this.pickupLabel = '',
    this.dropLabel,
    this.types = const [],
    this.selectedType,
    this.ride,
    this.showDriverSheet = false,
    this.busy = false,
    this.error,
    this.matchedAt,
    this.pickupIsManual = false,
    this.routePoints = const [],
    this.routeKm,
    this.routeEtaMin,
    this.routeSnapped = false,
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

  /// True once the rider picks a pickup by hand, so GPS stops overriding it.
  final bool pickupIsManual;

  /// Road geometry for pickup to drop, used by the map and the fare estimate.
  final List<LatLng> routePoints;
  final double? routeKm;
  final int? routeEtaMin;
  final bool routeSnapped;

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
    bool? pickupIsManual,
    List<LatLng>? routePoints,
    double? routeKm,
    int? routeEtaMin,
    bool? routeSnapped,
    bool clearDrop = false,
    bool clearRide = false,
    bool clearError = false,
    bool clearRoute = false,
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
      pickupIsManual: pickupIsManual ?? this.pickupIsManual,
      routePoints: clearRoute ? const [] : (routePoints ?? this.routePoints),
      routeKm: clearRoute ? null : (routeKm ?? this.routeKm),
      routeEtaMin: clearRoute ? null : (routeEtaMin ?? this.routeEtaMin),
      routeSnapped: clearRoute ? false : (routeSnapped ?? this.routeSnapped),
    );
  }

  @override
  List<Object?> get props => [
        phase,
        pickup,
        pickupLabel,
        drop,
        dropLabel,
        selectedType,
        ride,
        showDriverSheet,
        busy,
        error,
        routePoints,
        routeKm,
      ];
}

class RideCubit extends Cubit<RideState> {
  RideCubit(this.backend, {RouteService? routes})
      : routes = routes ?? RouteService(),
        super(const RideState()) {
    _bootstrap();
  }

  final MockBackend backend;
  final RouteService routes;

  ApiBackend? get _api => backend is ApiBackend ? backend as ApiBackend : null;

  Future<void> _bootstrap() async {
    final api = _api;
    if (api != null) {
      try {
        final fetched = await api.fetchVehicleTypes();
        emit(state.copyWith(
          types: fetched,
          selectedType: fetched.isNotEmpty ? fetched.first : null,
        ));
        return;
      } catch (_) {
        // Fall back to mock types on failure.
      }
    }
    emit(state.copyWith(types: backend.types, selectedType: MockBackend.bike));
  }

  void setDrop(LatLng p, String label) {
    emit(state.copyWith(drop: p, dropLabel: label, clearRoute: true));
    refreshRoute();
  }

  /// Rider chose a pickup by hand, so later GPS fixes must not move it.
  void setPickup(LatLng p, String label) {
    emit(state.copyWith(pickup: p, pickupLabel: label, pickupIsManual: true));
    refreshRoute();
  }

  /// A fresh GPS fix. Ignored once the rider has set pickup themselves.
  void setDevicePickup(LatLng p, {String? label}) {
    if (state.pickupIsManual) return;
    if (state.phase != RidePhase.idle && state.phase != RidePhase.estimating) {
      return;
    }
    emit(state.copyWith(pickup: p, pickupLabel: label));
    refreshRoute();
  }

  void clearDrop() => emit(state.copyWith(clearDrop: true, clearRoute: true));

  Future<void> refreshRoute() async {
    final drop = state.drop;
    if (drop == null) return;
    final path = await routes.driving(state.pickup, drop);
    if (isClosed || state.drop != drop) return;
    emit(state.copyWith(
      routePoints: path.points,
      routeKm: path.distanceKm,
      routeEtaMin: path.durationMin,
      routeSnapped: path.snapped,
    ));
  }

  void selectType(VehicleType t) => emit(state.copyWith(selectedType: t));

  FareBreakdown breakdownFor(VehicleType t) {
    return backend.estimate(t, _billableKm());
  }

  double _billableKm() {
    final km = state.routeKm;
    if (km != null && km > 0) return km;
    final drop = state.drop;
    if (drop == null) return 3.2;
    const d = Distance();
    // Straight line under-reads Dhaka roads by roughly a third.
    final direct = d.as(LengthUnit.Kilometer, state.pickup, drop) * 1.35;
    return direct < 1 ? 3.2 : direct;
  }

  Future<void> book() async {
    final drop = state.drop;
    final type = state.selectedType;
    if (drop == null || type == null) return;
    emit(state.copyWith(
      busy: true,
      phase: RidePhase.finding,
      clearError: true,
    ));
    try {
      final api = _api;
      final Ride ride;
      if (api != null) {
        ride = await api.createRideApi(
          vehicleCode: type.code,
          pickup: state.pickup,
          pickupAddress:
              state.pickupLabel.isEmpty ? 'Pickup point' : state.pickupLabel,
          drop: drop,
          dropAddress: state.dropLabel ?? '',
          paymentMethod: 'CASH',
        );
      } else {
        ride = await backend.createRide(
          pickup: state.pickup,
          drop: drop,
          pickupLabel:
              state.pickupLabel.isEmpty ? 'Pickup point' : state.pickupLabel,
          dropLabel: state.dropLabel ?? '',
          type: type,
        );
      }
      emit(state.copyWith(busy: false, ride: ride, phase: RidePhase.finding));
      try {
        final matched = api != null
            ? await api.matchDemoApi(
                rideId: ride.id,
                timeout: const Duration(seconds: 30),
              )
            : await backend.matchDemo();
        final finalRide = matched ?? ride;
        emit(state.copyWith(
          ride: finalRide,
          phase: finalRide.driver != null
              ? RidePhase.matched
              : RidePhase.noDriver,
          showDriverSheet: finalRide.driver != null,
          matchedAt: DateTime.now(),
          error: finalRide.driver == null ? 'No driver accepted yet' : null,
        ));
      } on ApiException catch (e) {
        emit(state.copyWith(phase: RidePhase.noDriver, error: e.message));
      }
    } on ApiException catch (e) {
      emit(state.copyWith(
        busy: false,
        phase: RidePhase.idle,
        error: e.message,
      ));
    }
  }

  void ackDriverSheet() {
    emit(state.copyWith(showDriverSheet: false, phase: RidePhase.tracking));
    final api = _api;
    if (api != null) {
      api.advanceApi();
    } else {
      backend.advance(RideStatus.driverArriving);
    }
  }

  Future<void> markInProgress() async {
    final api = _api;
    final Ride? ride;
    if (api != null) {
      ride = await api.advanceApi();
    } else {
      ride = await backend.advance(RideStatus.inProgress);
    }
    if (ride != null) {
      emit(state.copyWith(ride: ride, phase: RidePhase.tracking));
    }
  }

  Future<void> complete() async {
    final api = _api;
    final Ride? ride;
    if (api != null) {
      ride = await api.advanceApi();
    } else {
      ride = await backend.advance(RideStatus.completed);
    }
    if (ride != null) {
      emit(state.copyWith(ride: ride, phase: RidePhase.complete));
    }
  }

  Future<void> cancel() async {
    final ride = state.ride;
    final api = _api;
    try {
      if (api != null && ride != null) {
        await api.cancelRide(ride.id);
      } else {
        await backend.advance(RideStatus.cancelled);
      }
    } on ApiException catch (_) {
      // Best-effort cancel — always reset local state.
    }
    backend.activeRide = null;
    emit(state.copyWith(
      phase: RidePhase.idle,
      clearRide: true,
      showDriverSheet: false,
    ));
  }

  Future<void> rateAndReset() async {
    final ride = state.ride;
    final api = _api;
    try {
      if (api != null && ride != null) {
        await api.rateRideApi(rideId: ride.id, stars: 5);
      } else {
        await backend.completeAndRate();
      }
    } on ApiException catch (_) {
      // ignore rating failures; reset anyway.
    }
    await _bootstrap();
  }

  void retryFind() => book();

  void goIdle() => emit(state.copyWith(phase: RidePhase.idle, clearRide: true));
}
