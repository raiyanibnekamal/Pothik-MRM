import 'package:go_router/go_router.dart';
import 'package:mobile_core/core/app_role.dart';
import 'package:mobile_core/core/network/error_codes.dart';
import 'package:mobile_core/core/ride/ride_cubit.dart';
import 'package:mobile_core/core/router/cubit_listenable.dart';
import 'package:mobile_core/core/session/session_cubit.dart';
import 'package:mobile_core/features/auth/force_update_screen.dart';
import 'package:mobile_core/features/auth/otp_screen.dart';
import 'package:mobile_core/features/auth/permission_primer_screen.dart';
import 'package:mobile_core/features/auth/phone_screen.dart';
import 'package:mobile_core/features/auth/profile_setup_screen.dart';
import 'package:mobile_core/features/auth/splash_screen.dart';
import 'package:mobile_core/features/driver/home_screen.dart';
import 'package:mobile_core/features/driver/onboarding_screens.dart';
import 'package:mobile_core/features/passenger/finding_history.dart';
import 'package:mobile_core/features/passenger/home_screen.dart';
import 'package:mobile_core/features/passenger/tracking_screen.dart';
import 'package:mobile_core/features/profile/profile_screens.dart';
import 'package:mobile_core/features/sos/sos_flow.dart';

GoRouter createRouter({
  required AppRole role,
  required SessionCubit session,
  required RideCubit ride,
}) {
  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: CubitListenable([session, ride]),
    redirect: (context, state) {
      final loc = state.matchedLocation;
      final s = session.state;
      if (s.booting) return loc == '/splash' ? null : '/splash';
      if (loc == '/force-update') return null;

      const authOpen = {'/phone', '/otp', '/splash'};
      if (!s.loggedIn) {
        if (authOpen.contains(loc)) return loc == '/splash' ? '/phone' : null;
        return '/phone';
      }

      final user = s.user!;
      if (role == AppRole.passenger) {
        if (user.needsName) {
          return loc == '/profile-setup' ? null : '/profile-setup';
        }
        if (!user.locationPrimed) {
          return loc == '/permission' ? null : '/permission';
        }
        final r = ride.state;
        if (r.phase == RidePhase.finding && loc != '/passenger/finding') {
          return '/passenger/finding';
        }
        if ((r.phase == RidePhase.tracking ||
                r.phase == RidePhase.matched ||
                r.phase == RidePhase.complete) &&
            r.ride != null &&
            !loc.startsWith('/passenger/sos') &&
            loc != '/passenger/tracking') {
          if (loc.startsWith('/passenger/')) return null;
          return '/passenger/tracking';
        }
        if (loc == '/phone' ||
            loc == '/otp' ||
            loc == '/splash' ||
            loc == '/profile-setup' ||
            loc == '/permission') {
          return '/passenger/home';
        }
        return null;
      }

      // Driver
      switch (user.onboarding) {
        case DriverOnboardingStatus.phoneVerified:
          return loc == '/driver/personal' ? null : '/driver/personal';
        case DriverOnboardingStatus.personalDone:
          return loc == '/driver/vehicle' ? null : '/driver/vehicle';
        case DriverOnboardingStatus.docsPending:
          return loc == '/driver/documents' ? null : '/driver/documents';
        case DriverOnboardingStatus.pendingReview:
          return loc == '/driver/pending' ? null : '/driver/pending';
        case DriverOnboardingStatus.rejected:
          return loc == '/driver/rejected' ? null : '/driver/rejected';
        case DriverOnboardingStatus.vehicleDone:
        case DriverOnboardingStatus.grace:
        case DriverOnboardingStatus.approved:
          if (loc == '/phone' || loc == '/otp' || loc == '/splash') {
            return '/driver/home';
          }
          return null;
      }
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),
      GoRoute(path: '/phone', builder: (_, _) => const PhoneScreen()),
      GoRoute(path: '/otp', builder: (_, _) => const OtpScreen()),
      GoRoute(path: '/profile-setup', builder: (_, _) => const ProfileSetupScreen()),
      GoRoute(path: '/permission', builder: (_, _) => const PermissionPrimerScreen()),
      GoRoute(path: '/force-update', builder: (_, _) => const ForceUpdateScreen()),
      GoRoute(path: '/passenger/home', builder: (_, _) => const PassengerHomeScreen()),
      GoRoute(path: '/passenger/search', builder: (_, _) => const SearchScreen()),
      GoRoute(path: '/passenger/finding', builder: (_, _) => const FindingDriverScreen()),
      GoRoute(path: '/passenger/tracking', builder: (_, _) => const TrackingScreen()),
      GoRoute(path: '/passenger/sos-countdown', builder: (_, _) => const SosCountdownScreen()),
      GoRoute(path: '/passenger/sos-active', builder: (_, _) => const SosActiveScreen()),
      GoRoute(path: '/passenger/history', builder: (_, _) => const HistoryScreen()),
      GoRoute(path: '/passenger/profile', builder: (_, _) => const ProfileScreen()),
      GoRoute(path: '/passenger/guardians', builder: (_, _) => const GuardiansScreen()),
      GoRoute(path: '/driver/personal', builder: (_, _) => const DriverPersonalScreen()),
      GoRoute(path: '/driver/vehicle', builder: (_, _) => const DriverVehicleScreen()),
      GoRoute(path: '/driver/documents', builder: (_, _) => const DriverDocumentsScreen()),
      GoRoute(path: '/driver/pending', builder: (_, _) => const DriverPendingScreen()),
      GoRoute(path: '/driver/rejected', builder: (_, _) => const DriverRejectedScreen()),
      GoRoute(path: '/driver/home', builder: (_, _) => const DriverHomeScreen()),
      GoRoute(path: '/driver/earnings', builder: (_, _) => const DriverEarningsScreen()),
      GoRoute(path: '/driver/profile', builder: (_, _) => const DriverProfileScreen()),
    ],
  );
}
