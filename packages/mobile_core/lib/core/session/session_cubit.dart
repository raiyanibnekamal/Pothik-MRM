import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile_core/core/app_role.dart';
import 'package:mobile_core/core/config/bd_phone.dart';
import 'package:mobile_core/core/config/static_test_user.dart';
import 'package:mobile_core/core/models/models.dart';
import 'package:mobile_core/core/network/error_codes.dart';
import 'package:mobile_core/core/network/mock_backend.dart';
import 'package:mobile_core/core/storage/secure_store.dart';

class SessionState extends Equatable {
  const SessionState({
    this.booting = true,
    this.user,
    this.busy = false,
    this.error,
    this.otpPhone,
    this.resendAt,
  });

  final bool booting;
  final UserProfile? user;
  final bool busy;
  final String? error;
  final String? otpPhone;
  final DateTime? resendAt;

  bool get loggedIn => user != null;

  SessionState copyWith({
    bool? booting,
    UserProfile? user,
    bool? busy,
    String? error,
    String? otpPhone,
    DateTime? resendAt,
    bool clearUser = false,
    bool clearError = false,
  }) {
    return SessionState(
      booting: booting ?? this.booting,
      user: clearUser ? null : (user ?? this.user),
      busy: busy ?? this.busy,
      error: clearError ? null : (error ?? this.error),
      otpPhone: otpPhone ?? this.otpPhone,
      resendAt: resendAt ?? this.resendAt,
    );
  }

  @override
  List<Object?> get props => [booting, user, busy, error, otpPhone, resendAt];
}

class SessionCubit extends Cubit<SessionState> {
  SessionCubit({
    required this.role,
    required this.backend,
    required this.store,
  }) : super(const SessionState());

  final AppRole role;
  final MockBackend backend;
  final SecureStore store;

  Future<void> restore() async {
    final access = await store.access;
    if (access == null) {
      emit(const SessionState(booting: false));
      return;
    }
    var user = await store.readUser();
    if (user != null) {
      user = user.copyWith();
      if (BdPhone.isQa(user.phone)) {
        StaticTestUser.hydrate(backend, role);
        user = backend.sessionUser ?? StaticTestUser.profile(role);
      } else {
        backend.sessionUser = user;
      }
      backend.access = access;
      emit(SessionState(booting: false, user: user));
      return;
    }
    emit(const SessionState(booting: false));
  }

  Future<void> requestOtp(String national10, {required bool online}) async {
    emit(state.copyWith(busy: true, clearError: true, otpPhone: national10));
    try {
      await backend.requestOtp(national10, online: online);
      emit(state.copyWith(
        busy: false,
        otpPhone: national10,
        resendAt: DateTime.now().add(const Duration(seconds: 60)),
      ));
    } on ApiException catch (e) {
      emit(state.copyWith(busy: false, error: e.message));
      rethrow;
    }
  }

  Future<void> verifyOtp(String otp) async {
    final phone = state.otpPhone;
    if (phone == null) return;
    emit(state.copyWith(busy: true, clearError: true));
    try {
      final user = await backend.verifyOtp(
        national10: phone,
        otp: otp,
        role: role,
      );
      await store.saveTokens(
        access: backend.access ?? '',
        refresh: backend.refresh ?? '',
      );
      await store.saveUser(user);
      emit(SessionState(booting: false, user: user));
    } on ApiException catch (e) {
      emit(state.copyWith(busy: false, error: e.message));
      rethrow;
    }
  }

  Future<void> saveName(String name) async {
    emit(state.copyWith(busy: true, clearError: true));
    final user = await backend.patchProfile(name: name.trim());
    await store.saveUser(user);
    emit(state.copyWith(busy: false, user: user));
  }

  Future<void> markLocationPrimed() async {
    final user = await backend.patchProfile(locationPrimed: true);
    await store.saveUser(user);
    emit(state.copyWith(user: user));
  }

  Future<void> setOnboarding(DriverOnboardingStatus s) async {
    final user = await backend.patchProfile(onboarding: s);
    await store.saveUser(user);
    emit(state.copyWith(user: user));
  }

  Future<void> logout() async {
    await store.clearTokens();
    backend.sessionUser = null;
    backend.activeRide = null;
    emit(const SessionState(booting: false));
  }
}
