import 'package:latlong2/latlong.dart';
import 'package:mobile_core/core/app_role.dart';
import 'package:mobile_core/core/config/bd_phone.dart';
import 'package:mobile_core/core/models/models.dart';
import 'package:mobile_core/core/network/error_codes.dart';
import 'package:mobile_core/core/network/mock_backend.dart';

/// Full-access static tester. Same person in passenger, driver, and admin data.
abstract final class StaticTestUser {
  static const localPhone = BdPhone.qaLocal;
  static const otp = BdPhone.qaOtp;
  static const name = 'মনিরুজ্জামান';
  static const email = 'qa@bdrideshare.com';
  static const id = 'u_qa_0152170004';

  static UserProfile profile(AppRole role) {
    return UserProfile(
      id: id,
      phone: localPhone,
      role: role,
      name: name,
      email: email,
      language: 'bn',
      onboarding: DriverOnboardingStatus.approved,
      isVerified: true,
      locationPrimed: true,
      commissionDebtBdt: 0,
      debtCapBdt: 5000,
    );
  }

  static void hydrate(MockBackend backend, AppRole role) {
    backend.sessionUser = profile(role);
    backend.guardians
      ..clear()
      ..addAll(const [
        Guardian(id: 'g_qa_1', name: 'আয়েশা', phone: '01711000001'),
        Guardian(id: 'g_qa_2', name: 'করিম', phone: '01822000002'),
      ]);
    backend.history
      ..clear()
      ..addAll([
        Ride(
          id: 'R90001',
          status: RideStatus.completed,
          pickup: const LatLng(23.7925, 90.4078),
          drop: const LatLng(23.7937, 90.4066),
          pickupLabel: 'Gulshan 2',
          dropLabel: 'Banani',
          vehicleType: MockBackend.car,
          paymentMethod: 'CASH',
          pin: '4821',
          fare: const FareBreakdown(
            base: 50,
            distance: 80,
            time: 40,
            minFare: 80,
            total: 250,
          ),
          createdAt: DateTime.now().subtract(const Duration(hours: 5)),
          driver: const DriverCard(
            name: 'রহিম উদ্দিন',
            rating: 4.9,
            tripCount: 1240,
            vehicleModel: 'Toyota Axio',
            color: 'White',
            plate: 'DHAKA METRO-GA 12-3456',
            etaMin: 4,
            distanceKm: 0.8,
            isVerified: true,
          ),
        ),
        Ride(
          id: 'R90000',
          status: RideStatus.completed,
          pickup: const LatLng(23.7465, 90.3760),
          drop: const LatLng(23.7580, 90.3900),
          pickupLabel: 'Dhanmondi 27',
          dropLabel: 'Farmgate',
          vehicleType: MockBackend.bike,
          paymentMethod: 'CASH',
          pin: '4821',
          fare: const FareBreakdown(
            base: 25,
            distance: 36,
            time: 16,
            minFare: 40,
            total: 85,
          ),
          createdAt: DateTime.now().subtract(const Duration(days: 1)),
        ),
      ]);
    backend.cashConfirmed = false;
    backend.activeRide = null;
    backend.activeSos = null;
    backend.driverOnline = false;
  }
}
