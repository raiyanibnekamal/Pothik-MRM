import 'package:equatable/equatable.dart';
import 'package:latlong2/latlong.dart';
import 'package:mobile_core/core/app_role.dart';
import 'package:mobile_core/core/network/error_codes.dart';

class UserProfile extends Equatable {
  const UserProfile({
    required this.id,
    required this.phone,
    required this.role,
    this.name,
    this.email,
    this.photoUrl,
    this.language = 'bn',
    this.onboarding = DriverOnboardingStatus.phoneVerified,
    this.isVerified = false,
    this.locationPrimed = false,
    this.graceExpiresAt,
    this.commissionDebtBdt = 0,
    this.debtCapBdt = 5000,
  });

  final String id;
  final String phone;
  final AppRole role;
  final String? name;
  final String? email;
  final String? photoUrl;
  final String language;
  final DriverOnboardingStatus onboarding;
  final bool isVerified;
  final bool locationPrimed;
  final DateTime? graceExpiresAt;
  final int commissionDebtBdt;
  final int debtCapBdt;

  bool get needsName => name == null || name!.trim().length < 2;
  bool get debtBlocked => commissionDebtBdt >= debtCapBdt;
  bool get graceExpired =>
      graceExpiresAt != null && DateTime.now().isAfter(graceExpiresAt!);

  UserProfile copyWith({
    String? name,
    String? email,
    String? photoUrl,
    String? language,
    DriverOnboardingStatus? onboarding,
    bool? isVerified,
    bool? locationPrimed,
    DateTime? graceExpiresAt,
    int? commissionDebtBdt,
  }) {
    return UserProfile(
      id: id,
      phone: phone,
      role: role,
      name: name ?? this.name,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
      language: language ?? this.language,
      onboarding: onboarding ?? this.onboarding,
      isVerified: isVerified ?? this.isVerified,
      locationPrimed: locationPrimed ?? this.locationPrimed,
      graceExpiresAt: graceExpiresAt ?? this.graceExpiresAt,
      commissionDebtBdt: commissionDebtBdt ?? this.commissionDebtBdt,
      debtCapBdt: debtCapBdt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'phone': phone,
        'role': role.name,
        'name': name,
        'email': email,
        'language': language,
        'onboarding': onboarding.name,
        'isVerified': isVerified,
        'locationPrimed': locationPrimed,
        'commissionDebtBdt': commissionDebtBdt,
        'debtCapBdt': debtCapBdt,
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      phone: json['phone'] as String,
      role: AppRole.values.byName(json['role'] as String? ?? 'passenger'),
      name: json['name'] as String?,
      email: json['email'] as String?,
      language: json['language'] as String? ?? 'bn',
      onboarding: DriverOnboardingStatus.values.byName(
        json['onboarding'] as String? ?? 'approved',
      ),
      isVerified: json['isVerified'] as bool? ?? false,
      locationPrimed: json['locationPrimed'] as bool? ?? false,
      commissionDebtBdt: json['commissionDebtBdt'] as int? ?? 0,
      debtCapBdt: json['debtCapBdt'] as int? ?? 5000,
    );
  }

  @override
  List<Object?> get props =>
      [id, phone, name, onboarding, language, locationPrimed];
}

class VehicleType extends Equatable {
  const VehicleType({
    required this.id,
    required this.code,
    required this.nameBn,
    required this.nameEn,
    required this.etaMin,
    required this.estimateBdt,
    required this.base,
    required this.perKm,
    required this.perMin,
    required this.minFare,
    required this.isActive,
  });

  final String id;
  final String code;
  final String nameBn;
  final String nameEn;
  final int etaMin;
  final int estimateBdt;
  final int base;
  final int perKm;
  final int perMin;
  final int minFare;
  final bool isActive;

  String label(bool bn) => bn ? nameBn : nameEn;

  @override
  List<Object?> get props => [id, code, estimateBdt];
}

class FareBreakdown extends Equatable {
  const FareBreakdown({
    required this.base,
    required this.distance,
    required this.time,
    required this.minFare,
    required this.total,
  });

  final int base;
  final int distance;
  final int time;
  final int minFare;
  final int total;

  String get formatted => '৳$total';

  @override
  List<Object?> get props => [total];
}

class DriverCard extends Equatable {
  const DriverCard({
    required this.name,
    required this.rating,
    required this.tripCount,
    required this.vehicleModel,
    required this.color,
    required this.plate,
    required this.etaMin,
    required this.distanceKm,
    required this.isVerified,
    this.photoUrl,
    this.vehiclePhotoUrl,
    this.phone,
  });

  final String name;
  final double rating;
  final int tripCount;
  final String vehicleModel;
  final String color;
  final String plate;
  final int etaMin;
  final double distanceKm;
  final bool isVerified;
  final String? photoUrl;
  final String? vehiclePhotoUrl;
  final String? phone;

  @override
  List<Object?> get props => [plate, name];
}

class Ride extends Equatable {
  const Ride({
    required this.id,
    required this.status,
    required this.pickup,
    required this.drop,
    required this.pickupLabel,
    required this.dropLabel,
    required this.vehicleType,
    required this.paymentMethod,
    required this.pin,
    required this.fare,
    required this.createdAt,
    this.driver,
    this.shareUrl,
    this.driverPoint,
  });

  final String id;
  final RideStatus status;
  final LatLng pickup;
  final LatLng drop;
  final String pickupLabel;
  final String dropLabel;
  final VehicleType vehicleType;
  final String paymentMethod;
  final String pin;
  final FareBreakdown fare;
  final DateTime createdAt;
  final DriverCard? driver;
  final String? shareUrl;
  final LatLng? driverPoint;

  bool get isActive =>
      status != RideStatus.completed &&
      status != RideStatus.cancelled &&
      status != RideStatus.noShow;

  Ride copyWith({
    RideStatus? status,
    DriverCard? driver,
    LatLng? driverPoint,
    String? shareUrl,
  }) {
    return Ride(
      id: id,
      status: status ?? this.status,
      pickup: pickup,
      drop: drop,
      pickupLabel: pickupLabel,
      dropLabel: dropLabel,
      vehicleType: vehicleType,
      paymentMethod: paymentMethod,
      pin: pin,
      fare: fare,
      createdAt: createdAt,
      driver: driver ?? this.driver,
      shareUrl: shareUrl ?? this.shareUrl,
      driverPoint: driverPoint ?? this.driverPoint,
    );
  }

  @override
  List<Object?> get props => [id, status, pin];
}

class SosAlert extends Equatable {
  const SosAlert({
    required this.id,
    required this.status,
    required this.trackUrl,
    this.smsStatus = 'pending',
  });

  final String id;
  final String status;
  final String trackUrl;
  final String smsStatus;

  @override
  List<Object?> get props => [id, status];
}

class Guardian extends Equatable {
  const Guardian({required this.id, required this.name, required this.phone});
  final String id;
  final String name;
  final String phone;
  @override
  List<Object?> get props => [id, phone];
}

class DriverRequest extends Equatable {
  const DriverRequest({
    required this.rideId,
    required this.pickupDistanceKm,
    required this.fareBdt,
    required this.dropArea,
    required this.paymentMethod,
    required this.seconds,
    required this.pickup,
    required this.drop,
    this.pickupArea = '',
  });

  final String rideId;
  final double pickupDistanceKm;
  final int fareBdt;
  final String dropArea;
  final String paymentMethod;
  final int seconds;
  final LatLng pickup;
  final LatLng drop;
  final String pickupArea;

  @override
  List<Object?> get props => [rideId];
}

class EarningsToday extends Equatable {
  const EarningsToday({
    required this.gross,
    required this.commission,
    required this.net,
    required this.trips,
    required this.debt,
  });

  final int gross;
  final int commission;
  final int net;
  final int trips;
  final int debt;

  @override
  List<Object?> get props => [gross, trips, debt];
}

String formatTaka(int amount) {
  final n = amount.toString();
  final rev = n.split('').reversed.join();
  final chunks = <String>[];
  for (var i = 0; i < rev.length; i += 3) {
    final end = i + 3 > rev.length ? rev.length : i + 3;
    chunks.add(rev.substring(i, end));
  }
  return '৳${chunks.join(',').split('').reversed.join()}';
}
