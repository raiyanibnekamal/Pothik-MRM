import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mobile_core/core/app_role.dart';
import 'package:mobile_core/core/connectivity/connectivity_cubit.dart';
import 'package:mobile_core/core/driver/driver_session_cubit.dart';
import 'package:mobile_core/core/l10n/app_strings.dart';
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
  final backend = MockBackend();
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
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider.value(value: session),
          BlocProvider(create: (_) => LocaleCubit()),
          BlocProvider(create: (_) => ConnectivityCubit()),
          BlocProvider(create: (_) => RideCubit(backend)),
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
            Expanded(child: child ?? const SizedBox.shrink()),
          ],
        );
      },
    );
  }
}
