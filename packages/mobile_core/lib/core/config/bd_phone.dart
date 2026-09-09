/// Bangladesh phone helpers + the locked QA login.
abstract final class BdPhone {
  /// Exact login the team asked for (local 01-style, 10 digits).
  static const qaLocal = '0152170004';
  static const qaOtp = '123456';

  static String digits(String raw) => raw.replaceAll(RegExp(r'\D'), '');

  static bool isQa(String raw) {
    var d = digits(raw);
    if (d.startsWith('880')) d = d.substring(3);
    return d == qaLocal || d == '152170004';
  }

  /// Canonical account id: `0152170004` for QA, else `01XXXXXXXXX` / `1XXXXXXXXX`.
  static String normalize(String raw) {
    var d = digits(raw);
    if (d.startsWith('880')) d = d.substring(3);
    if (isQa(d)) return qaLocal;
    return d;
  }

  static bool isValid(String raw) {
    if (isQa(raw)) return true;
    var d = digits(raw);
    if (d.startsWith('880')) d = d.substring(3);
    if (d.startsWith('0')) d = d.substring(1);
    return RegExp(r'^1[3-9]\d{8}$').hasMatch(d);
  }

  static String display(String raw) {
    if (isQa(raw)) return qaLocal;
    final n = normalize(raw);
    if (n.startsWith('0')) return n;
    if (n.length == 10 && n.startsWith('1')) return '0$n';
    return n;
  }
}
