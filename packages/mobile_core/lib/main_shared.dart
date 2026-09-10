import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:latlong2/latlong.dart';
import 'package:mobile_core/core/app_role.dart';
import 'package:mobile_core/core/connectivity/connectivity_cubit.dart';
import 'package:mobile_core/core/driver/driver_session_cubit.dart';
import 'package:mobile_core/core/l10n/app_strings.dart';
import 'package:mobile_core/core/location/geo_service.dart';
import 'package:mobile_core/core/location/location_cubit.dart';
import 'package:mobile_core/core/location/route_service.dart';
import 'package:mobile_core/core/network/backend_factory.dart';
import 'package:mobile_core/core/network/mock_backend.dart';
import 'package:mobile_core/core/ride/ride_cubit.dart';
import 'package:mobile_core/core/router/app_router.dart';
import 'package:mobile_core/core/session/session_cubit.dart';
import 'package:mobile_core/core/sos/sos_cubit.dart';
import 'package:mobile_core/core/storage/secure_store.dart';
import 'package:mobile_core/core/theme/app_theme.dart';
import 'package:mobile_core/core/widgets/app_chrome.dart';
import 'package:mobile_core/native/gps_channel.dart';

Future<void> runBdRideShareApp(AppRole role) async {
  WidgetsFlutterBinding.ensureInitialized();
  final backend = createBackend();
  final store = SecureStore();
  final session = SessionCubit(role: role, backend: backend, store: store);
  await session.restore();
  if (role == AppRole.driver) {
    await GpsChannel.ensureReady();
  }
  runApp(BdRideShareApp(role: role, backend: backend, session: session));
}

class BdRideShareApp extends StatelessWidget {
  const BdRideShareApp({
    super.key,
    required this.role,
    required this.backend,
    required this.session,
  });

  final AppRole role;
  final MockBackend backend;
  final SessionCubit session;

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: backend),
        RepositoryProvider.value(value: role),
        RepositoryProvider(create: (_) => GeoService()),
        RepositoryProvider(create: (_) => RouteService()),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider.value(value: session),
          BlocProvider(create: (_) => LocaleCubit()),
          BlocProvider(create: (_) => ConnectivityCubit()),
          BlocProvider(create: (_) => LocationCubit()),
          BlocProvider(
            create: (ctx) => RideCubit(backend, routes: ctx.read<RouteService>()),
          ),
          BlocProvider(create: (_) => DriverSessionCubit(backend)),
          BlocProvider(create: (_) => SosCubit(backend)),
        ],
        child: const _AppView(),
      ),
    );
  }
}

class _AppView extends StatefulWidget {
  const _AppView();

  @override
  State<_AppView> createState() => _AppViewState();
}

class _AppViewState extends State<_AppView> {
  late final router = createRouter(
    role: context.read<AppRole>(),
    session: context.read<SessionCubit>(),
    ride: context.read<RideCubit>(),
  );

  LatLng? _labelledFor;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _primeLocation());
  }

  /// Picks up an already-granted permission on launch. The primer screen owns
  /// the first prompt, so this must not raise a dialog of its own.
  Future<void> _primeLocation() async {
    final location = context.read<LocationCubit>();
    if (context.read<AppRole>() == AppRole.driver) {
      location.bindNativeUpdates();
    }
    if (await location.ensure(request: false)) {
      await location.startStream();
    }
  }

  Future<void> _syncPickup(BuildContext context, LocationState state) async {
    if (context.read<AppRole>() != AppRole.passenger) return;
    final point = state.point;
    if (point == null || !state.isPrecise) return;

    final ride = context.read<RideCubit>();
    ride.setDevicePickup(point);

    const distance = Distance();
    final last = _labelledFor;
    if (last != null && distance.as(LengthUnit.Meter, last, point) < 60) return;
    _labelledFor = point;

    final label = await context.read<GeoService>().reverse(point);
    if (label != null) ride.setDevicePickup(point, label: label);
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleCubit>().state;
    final online = context.watch<ConnectivityCubit>().state;
    return MaterialApp.router(
      title: 'BD Ride Share',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      locale: locale,
      supportedLocales: const [Locale('bn'), Locale('en')],
      localizationsDelegates: const [
        SDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
      builder: (context, child) {
        return Column(
          children: [
            if (!online) OfflineBanner(message: S(locale).offline),
            Expanded(
              child: BlocListener<LocationCubit, LocationState>(
                listenWhen: (a, b) => b.point != null && a.point != b.point,
                listener: _syncPickup,
                child: child ?? const SizedBox.shrink(),
              ),
            ),
          ],
        );
      },
    );
  }
}
