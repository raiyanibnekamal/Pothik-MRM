import 'package:flutter/material.dart';

abstract final class AppRadius {
  static const sm = 8.0;
  static const md = 12.0;
  static const sheet = 20.0;

  static const smAll = BorderRadius.all(Radius.circular(sm));
  static const mdAll = BorderRadius.all(Radius.circular(md));
  static final sheetTop = const BorderRadius.vertical(
    top: Radius.circular(sheet),
  );
}
