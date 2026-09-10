import 'dart:async';
import 'dart:math';

import 'package:latlong2/latlong.dart';
import 'package:mobile_core/core/app_role.dart';
import 'package:mobile_core/core/config/bd_phone.dart';
import 'package:mobile_core/core/config/static_test_user.dart';
import 'package:mobile_core/core/models/models.dart';
import 'package:mobile_core/core/network/error_codes.dart';

/// In-memory backend for local UI until NestJS is live (max 48h mock).
class MockBackend {
  MockBackend();

  static const demoOtp = '123456';
  static const minAppVersion = '1.0.0';

  final _otpSends = <String, List<DateTime>>{};
  final _otpVerifyTries = <String, int>{};
  UserProfile? sessionUser;
  String? access;
  String? refresh;
  Ride? activeRide;
  SosAlert? activeSos;
  final guardians = <Guardian>[];
  final history = <Ride>[];
  DriverRequest? openRequest;
  bool driverOnline = false;
  bool driverBreak = false;
  bool cashConfirmed = false;
  int otpLeft = 5;

  bool get forceUpdate => false;

  static final bike = VehicleType(
    id: 'bike',
    code: 'BIKE',
    nameBn: 'বাইক',
    nameEn: 'Bike',
    etaMin: 4,
    estimateBdt: 85,
    base: 25,
    perKm: 12,
    perMin: 2,
    minFare: 40,
    isActive: true,
  );

  static final car = VehicleType(
    id: 'car',
    code: 'CAR',
    nameBn: 'কার',
    nameEn: 'Car',
    etaMin: 7,
    estimateBdt: 250,
    base: 50,
    perKm: 22,
    perMin: 4,
    minFare: 80,
    isActive: true,
  );

  List<VehicleType> get types => [bike, car];

  bool validPhone(String input) => BdPhone.isValid(input);

  String accountPhone(String input) => BdPhone.normalize(input);

  Future<void> requestOtp(String input, {required bool online}) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (!online) {
      throw ApiException(code: ErrorCodes.smsDown, message: 'SMS পাঠানো যাচ্ছে না।');
    }
    if (!validPhone(input)) {
      throw ApiException(
        code: ErrorCodes.badPhone,
        message: 'সঠিক বাংলাদেশি মোবাইল নম্বর দিন',
      );
    }
    final key = accountPhone(input);
    final now = DateTime.now();
    final list = (_otpSends[key] ?? [])
        .where((t) => now.difference(t) < const Duration(minutes: 10))
        .toList();
    if (!BdPhone.isQa(key) && list.length >= 3) {
      throw ApiException(
        code: ErrorCodes.rateLimit,
        message: 'কিছুক্ষণ পর আবার চেষ্টা করুন।',
      );
    }
    list.add(now);
    _otpSends[key] = list;
    _otpVerifyTries[key] = 0;
  }

  Future<UserProfile> verifyOtp({
    required String national10,
    required String otp,
    required AppRole role,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    final key = accountPhone(national10);
    final tries = _otpVerifyTries[key] ?? 0;
    if (tries >= 5) {
      throw ApiException(
        code: ErrorCodes.otpExpired,
        message: 'OTP মেয়াদ শেষ হয়েছে। আবার পাঠান।',
      );
    }
    if (otp != demoOtp) {
      _otpVerifyTries[key] = tries + 1;
      final left = 5 - (tries + 1);
      throw ApiException(
        code: ErrorCodes.otpInvalid,
        message: 'ভুল OTP। আর $left বার সুযোগ আছে।',
      );
    }
    access = 'access_${Random().nextInt(999999)}';
    refresh = 'refresh_${Random().nextInt(999999)}';
    if (BdPhone.isQa(key)) {
      StaticTestUser.hydrate(this, role);
      return sessionUser!;
    }
    sessionUser = UserProfile(
      id: 'u_$key',
      phone: key.startsWith('0') ? key : '+880$key',
      role: role,
      onboarding: role == AppRole.driver
          ? DriverOnboardingStatus.phoneVerified
          : DriverOnboardingStatus.approved,
      graceExpiresAt: role == AppRole.driver
          ? DateTime.now().add(const Duration(hours: 24))
          : null,
    );
    return sessionUser!;
  }

  Future<UserProfile> patchProfile({
    String? name,
    String? email,
    bool? locationPrimed,
    DriverOnboardingStatus? onboarding,
  }) async {
    final u = sessionUser;
    if (u == null) {
      throw ApiException(code: 'UNAUTH', message: 'Unauthorized', status: 401);
    }
    if (name != null && (name.trim().length < 2 || name.trim().length > 100)) {
      throw ApiException(code: 'NAME', message: 'Name 2–100 required');
    }
    sessionUser = u.copyWith(
      name: name ?? u.name,
      email: email ?? u.email,
      locationPrimed: locationPrimed ?? u.locationPrimed,
      onboarding: onboarding ?? u.onboarding,
    );
    return sessionUser!;
  }

  FareBreakdown estimate(VehicleType t, double km) {
    final minutes = (km * 3).round().clamp(4, 90);
    var total = t.base + (km * t.perKm).round() + minutes * t.perMin;
    if (total < t.minFare) total = t.minFare;
    total = ((total / 5).round()) * 5;
    return FareBreakdown(
      base: t.base,
      distance: (km * t.perKm).round(),
      time: minutes * t.perMin,
      minFare: t.minFare,
      total: total,
    );
  }

  Future<Ride> createRide({
    required LatLng pickup,
    required LatLng drop,
    required String pickupLabel,
    required String dropLabel,
    required VehicleType type,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    const d = Distance();
    final km = d.as(LengthUnit.Kilometer, pickup, drop);
    if (km > 80) {
      throw ApiException(
        code: ErrorCodes.outOfZone,
        message: 'এই এলাকায় এখন সার্ভিস নেই।',
      );
    }
    final ride = Ride(
      id: 'R${DateTime.now().millisecondsSinceEpoch % 100000}',
      status: RideStatus.requested,
      pickup: pickup,
      drop: drop,
      pickupLabel: pickupLabel,
      dropLabel: dropLabel,
      vehicleType: type,
      paymentMethod: 'CASH',
      pin: '4821',
      fare: estimate(type, km < 1 ? 3.2 : km),
      createdAt: DateTime.now(),
      shareUrl: 'https://track.bdrideshare.local/t/demo',
    );
    activeRide = ride;
    cashConfirmed = false;
    return ride;
  }

  Future<Ride> matchDemo() async {
    await Future<void>.delayed(const Duration(seconds: 3));
    var ride = activeRide;
    if (ride == null) {
      throw ApiException(code: ErrorCodes.noDrivers, message: 'কাছাকাছি কোনো ড্রাইভার নেই। আবার চেষ্টা করুন।');
    }
    ride = ride.copyWith(
      status: RideStatus.accepted,
      driver: const DriverCard(
        name: 'রহিম উদ্দিন',
        rating: 4.9,
        tripCount: 1240,
        vehicleModel: 'Honda Shine',
        color: 'Black',
        plate: 'DHAKA METRO-GA 12-3456',
        etaMin: 4,
        distanceKm: 0.8,
        isVerified: true,
        phone: '+8801711000000',
      ),
      driverPoint: LatLng(
        ride.pickup.latitude + 0.004,
        ride.pickup.longitude - 0.003,
      ),
    );
    activeRide = ride;
    return ride;
  }

  Future<Ride> advance(RideStatus status) async {
    final ride = activeRide;
    if (ride == null) {
      throw ApiException(code: 'NO_RIDE', message: 'No ride');
    }
    activeRide = ride.copyWith(status: status);
    return activeRide!;
  }

  Future<void> confirmCash(int amount) async {
    final ride = activeRide;
    if (ride == null) return;
    if (cashConfirmed) {
      throw ApiException(
        code: ErrorCodes.alreadyPaid,
        message: 'পেমেন্ট ইতিমধ্যে নিশ্চিত।',
        status: 409,
      );
    }
    if (amount != ride.fare.total) {
      throw ApiException(code: 'FARE', message: 'Amount mismatch');
    }
    cashConfirmed = true;
  }

  Future<void> completeAndRate() async {
    final ride = activeRide;
    if (ride == null) return;
    history.insert(0, ride.copyWith(status: RideStatus.completed));
    activeRide = null;
    cashConfirmed = false;
  }

  Future<SosAlert> triggerSos({required bool allowed}) async {
    if (!allowed) {
      throw ApiException(
        code: ErrorCodes.sosNotAllowed,
        message: 'রাইড চলাকালীনই SOS ব্যবহার করা যাবে।',
        status: 403,
      );
    }
    if (activeSos != null && activeSos!.status == 'active') {
      return activeSos!;
    }
    activeSos = SosAlert(
      id: 'sos_${DateTime.now().millisecondsSinceEpoch}',
      status: 'active',
      trackUrl: activeRide?.shareUrl ?? 'https://track.bdrideshare.local/t/sos',
      smsStatus: 'sent',
    );
    return activeSos!;
  }

  Future<void> cancelSos() async {
    if (activeSos == null) return;
    activeSos = SosAlert(
      id: activeSos!.id,
      status: 'cancelled',
      trackUrl: activeSos!.trackUrl,
      smsStatus: activeSos!.smsStatus,
    );
    activeSos = null;
  }

  Future<Guardian> addGuardian(String name, String phone) async {
    if (guardians.length >= 3) {
      throw ApiException(
        code: ErrorCodes.guardianCap,
        message: 'সর্বোচ্চ ৩ জন ইমার্জেন্সি কন্টাক্ট।',
      );
    }
    if (guardians.any((g) => g.phone == phone)) {
      throw ApiException(code: 'DUP', message: 'Duplicate phone', status: 409);
    }
    final g = Guardian(id: 'g${guardians.length}', name: name, phone: phone);
    guardians.add(g);
    return g;
  }

  DriverRequest spawnRequest() {
    openRequest = DriverRequest(
      rideId: 'R${DateTime.now().millisecondsSinceEpoch % 100000}',
      pickupDistanceKm: 0.7,
      fareBdt: 250,
      dropArea: 'Banani',
      paymentMethod: 'CASH',
      seconds: 15,
    );
    return openRequest!;
  }

  void recordDriverTrip({required String rideId, required int fareBdt, String dropArea = 'Banani'}) {
    history.insert(
      0,
      Ride(
        id: rideId,
        status: RideStatus.completed,
        pickup: const LatLng(23.7925, 90.4078),
        drop: const LatLng(23.7937, 90.4066),
        pickupLabel: 'Gulshan 2',
        dropLabel: dropArea,
        vehicleType: bike,
        paymentMethod: 'CASH',
        pin: '4821',
        fare: FareBreakdown(
          base: 30,
          distance: fareBdt ~/ 3,
          time: fareBdt ~/ 5,
          minFare: 50,
          total: fareBdt,
        ),
        createdAt: DateTime.now(),
      ),
    );
  }

  EarningsToday earnings() {
    final qa = sessionUser != null && BdPhone.isQa(sessionUser!.phone);
    return EarningsToday(
      gross: qa ? 4320 : 1850,
      commission: qa ? 864 : 370,
      net: qa ? 3456 : 1480,
      trips: qa ? 14 : 7,
      debt: sessionUser?.commissionDebtBdt ?? (qa ? 0 : 370),
    );
  }
}
