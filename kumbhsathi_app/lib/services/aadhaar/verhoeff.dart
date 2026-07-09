/// Verhoeff checksum — the algorithm UIDAI uses for the 12th digit of every
/// Aadhaar number. Lets the app validate a scanned number fully offline
/// (DESIGN.md §7.2).
abstract final class Verhoeff {
  // Dihedral group D5 multiplication table.
  static const _d = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9],
    [1, 2, 3, 4, 0, 6, 7, 8, 9, 5],
    [2, 3, 4, 0, 1, 7, 8, 9, 5, 6],
    [3, 4, 0, 1, 2, 8, 9, 5, 6, 7],
    [4, 0, 1, 2, 3, 9, 5, 6, 7, 8],
    [5, 9, 8, 7, 6, 0, 4, 3, 2, 1],
    [6, 5, 9, 8, 7, 1, 0, 4, 3, 2],
    [7, 6, 5, 9, 8, 2, 1, 0, 4, 3],
    [8, 7, 6, 5, 9, 3, 2, 1, 0, 4],
    [9, 8, 7, 6, 5, 4, 3, 2, 1, 0],
  ];

  // Permutation table.
  static const _p = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9],
    [1, 5, 7, 6, 2, 8, 3, 0, 9, 4],
    [5, 8, 0, 3, 7, 9, 6, 1, 4, 2],
    [8, 9, 1, 6, 0, 4, 3, 5, 2, 7],
    [9, 4, 5, 3, 1, 2, 6, 8, 7, 0],
    [4, 2, 8, 6, 5, 7, 3, 9, 0, 1],
    [2, 7, 9, 3, 8, 0, 6, 4, 1, 5],
    [7, 0, 4, 6, 9, 1, 3, 2, 5, 8],
  ];

  /// True when [number] (digits only) carries a valid Verhoeff checksum.
  /// A 12-digit Aadhaar must also start with 2–9 (0/1 are reserved).
  static bool validate(String number) {
    final digits = number.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return false;
    var c = 0;
    final reversed = digits.split('').reversed.toList();
    for (var i = 0; i < reversed.length; i++) {
      c = _d[c][_p[i % 8][int.parse(reversed[i])]];
    }
    return c == 0;
  }

  /// Full Aadhaar-number check: 12 digits, first digit 2–9, checksum valid.
  static bool isValidAadhaar(String number) {
    final digits = number.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 12) return false;
    final first = int.parse(digits[0]);
    if (first < 2) return false;
    return validate(digits);
  }
}
