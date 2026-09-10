import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ConnectivityCubit extends Cubit<bool> {
  ConnectivityCubit() : super(true) {
    _sub = Connectivity().onConnectivityChanged.listen((results) {
      final online = results.any((r) => r != ConnectivityResult.none);
      emit(online);
    });
    Connectivity().checkConnectivity().then((results) {
      emit(results.any((r) => r != ConnectivityResult.none));
    });
  }

  late final StreamSubscription<List<ConnectivityResult>> _sub;

  @override
  Future<void> close() {
    _sub.cancel();
    return super.close();
  }
}
