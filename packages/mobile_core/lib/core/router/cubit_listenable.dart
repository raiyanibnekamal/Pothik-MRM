import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class CubitListenable extends ChangeNotifier {
  CubitListenable(List<Cubit<dynamic>> cubits) {
    for (final c in cubits) {
      _subs.add(c.stream.listen((_) => notifyListeners()));
    }
  }

  final _subs = <StreamSubscription<dynamic>>[];

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }
}
