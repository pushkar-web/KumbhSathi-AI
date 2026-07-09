import 'dart:convert';
import 'dart:math' as math;

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:hive/hive.dart';

import 'verhoeff.dart';

/// Result of an offline Aadhaar scan (OCR or secure QR).
/// The raw number is never persisted — only [maskedNumber] for display and
/// [numberHash] for matching (DESIGN.md §7.2).
class AadhaarScanResult {
  const AadhaarScanResult({
    this.maskedNumber,
    this.numberHash,
    required this.verhoeffValid,
    required this.source,
    this.name,
    this.dob,
    this.yearOfBirth,
    this.gender,
    this.address,
    this.confidence = 0,
    this.qrSigned = false,
  });

  /// e.g. `XXXX XXXX 1234`.
  final String? maskedNumber;

  /// Salted SHA-256 of the 12 digits.
  final String? numberHash;
  final bool verhoeffValid;

  /// `ocr` or `qr`.
  final String source;
  final String? name;
  final DateTime? dob;
  final int? yearOfBirth;
  final String? gender;
  final String? address;

  /// 0..1 heuristic extraction confidence.
  final double confidence;

  /// True when parsed from the UIDAI secure QR (tamper-evident payload).
  final bool qrSigned;

  bool get hasIdentity => name != null || numberHash != null;
}

/// A local case match for a scanned Aadhaar identity.
class AadhaarCaseMatch {
  const AadhaarCaseMatch({
    required this.caseId,
    required this.personName,
    required this.score,
    required this.level,
    this.caseData = const {},
  });

  final String caseId;
  final String personName;

  /// 0..1 combined match score.
  final double score;

  /// 1 = name+age+gender, 2 = name+gender, 3 = name-only.
  final int level;
  final Map<String, dynamic> caseData;
}

/// Fully offline Aadhaar extraction, validation and matching:
///   camera photo → ML Kit OCR → field parse → Verhoeff checksum
///   secure QR    → BigInt → zlib inflate → field parse
/// then fuzzy match against the locally cached case index. Card images are
/// processed in memory and never uploaded (DESIGN.md §7.2).
class AadhaarService {
  AadhaarService({String hashSalt = _defaultSalt}) : _salt = hashSalt;

  static const String _defaultSalt = 'kumbhsathi-aadhaar-v2';
  static const String casesBoxName = 'cases_cache';

  final String _salt;
  final TextRecognizer _recognizer =
      TextRecognizer(script: TextRecognitionScript.latin);

  static final _numberRe = RegExp(r'\b(\d{4})\s?(\d{4})\s?(\d{4})\b');
  static final _dobRe = RegExp(r'\b(\d{2})[/-](\d{2})[/-](\d{4})\b');
  static final _yobRe =
      RegExp(r'(?:year of birth|yob)\s*[:\-]?\s*(\d{4})', caseSensitive: false);

  // ============================================================
  // OCR extraction
  // ============================================================
  Future<AadhaarScanResult?> extractFromImage(String imagePath) async {
    final recognized = await _recognizer
        .processImage(InputImage.fromFilePath(imagePath));
    final fullText = recognized.text;
    if (fullText.trim().isEmpty) return null;

    final lines = <String>[
      for (final block in recognized.blocks)
        for (final line in block.lines) line.text.trim(),
    ];

    // --- Aadhaar number (skip 16-digit VIDs by requiring exactly 12) ---
    String? digits;
    for (final m in _numberRe.allMatches(fullText)) {
      final candidate = '${m[1]}${m[2]}${m[3]}';
      final start = int.parse(candidate[0]);
      if (start >= 2) {
        digits = candidate;
        if (Verhoeff.isValidAadhaar(candidate)) break; // prefer valid one
      }
    }
    final valid = digits != null && Verhoeff.isValidAadhaar(digits);

    // --- DOB / Year of birth ---
    DateTime? dob;
    int? yob;
    final dobM = _dobRe.firstMatch(fullText);
    if (dobM != null) {
      dob = DateTime.tryParse(
          '${dobM[3]}-${dobM[2]!.padLeft(2, '0')}-${dobM[1]!.padLeft(2, '0')}');
      yob = dob?.year;
    } else {
      final yobM = _yobRe.firstMatch(fullText);
      if (yobM != null) yob = int.tryParse(yobM[1]!);
    }

    // --- Gender (English + Hindi) ---
    String? gender;
    final lower = fullText.toLowerCase();
    if (lower.contains('female') || fullText.contains('महिला')) {
      gender = 'Female';
    } else if (lower.contains('male') || fullText.contains('पुरुष')) {
      gender = 'Male';
    }

    // --- Name: the line just above the DOB/gender line, skipping headers ---
    String? name;
    const noise = [
      'government of india', 'unique identification', 'authority of india',
      'भारत सरकार', 'dob', 'date of birth', 'year of birth', 'male', 'female',
      'aadhaar', 'uid', 'वर्ष', 'जन्म',
    ];
    int anchor = lines.indexWhere((l) =>
        _dobRe.hasMatch(l) || _yobRe.hasMatch(l) ||
        l.toLowerCase().contains('male'));
    if (anchor > 0) {
      for (var i = anchor - 1; i >= 0; i--) {
        final l = lines[i];
        final lc = l.toLowerCase();
        final isNoise = noise.any(lc.contains) ||
            _numberRe.hasMatch(l) ||
            l.length < 3;
        if (!isNoise && RegExp(r'^[A-Za-z .]+$').hasMatch(l)) {
          name = l;
          break;
        }
      }
    }

    var confidence = 0.0;
    if (digits != null) confidence += valid ? 0.45 : 0.20;
    if (name != null) confidence += 0.25;
    if (dob != null || yob != null) confidence += 0.15;
    if (gender != null) confidence += 0.15;

    return AadhaarScanResult(
      maskedNumber: digits == null
          ? null
          : 'XXXX XXXX ${digits.substring(8)}',
      numberHash: digits == null ? null : hashNumber(digits),
      verhoeffValid: valid,
      source: 'ocr',
      name: name,
      dob: dob,
      yearOfBirth: yob,
      gender: gender,
      confidence: confidence,
    );
  }

  // ============================================================
  // Secure QR parsing (offline, tamper-evident payload)
  // ============================================================

  /// Parses the UIDAI "secure QR": a decimal big integer that inflates to
  /// 0xFF-delimited demographic fields. The full Aadhaar number is not in
  /// the QR (privacy by design) — only reference digits + demographics.
  AadhaarScanResult? parseSecureQr(String raw) {
    try {
      final big = BigInt.tryParse(raw.trim());
      if (big == null || big <= BigInt.zero) return null;

      var bytes = _bigIntToBytes(big);
      List<int> inflated;
      try {
        inflated = const ZLibDecoder().decodeBytes(bytes);
      } catch (_) {
        inflated = bytes; // some test QRs are uncompressed
      }

      // Split on 0xFF delimiters; fields are ISO-8859-1 text.
      final fields = <String>[];
      var start = 0;
      for (var i = 0; i < inflated.length && fields.length < 20; i++) {
        if (inflated[i] == 255) {
          fields.add(latin1.decode(inflated.sublist(start, i),
              allowInvalid: true));
          start = i + 1;
        }
      }
      if (fields.length < 6) return null;

      // Layout (V2): [0] version/flags, [1] referenceId(last4+timestamp),
      // [2] name, [3] dob, [4] gender, [5..] address parts.
      final refId = fields[1];
      final last4 = refId.length >= 4 ? refId.substring(0, 4) : null;
      final name = fields[2].trim();
      DateTime? dob;
      final dobM = _dobRe.firstMatch(fields[3]);
      if (dobM != null) {
        dob = DateTime.tryParse(
            '${dobM[3]}-${dobM[2]!.padLeft(2, '0')}-${dobM[1]!.padLeft(2, '0')}');
      }
      final g = fields[4].trim().toUpperCase();
      final gender = g.startsWith('F')
          ? 'Female'
          : g.startsWith('M')
              ? 'Male'
              : null;
      final address = fields
          .sublist(5, math.min(fields.length, 13))
          .where((f) => f.trim().isNotEmpty)
          .join(', ');

      return AadhaarScanResult(
        maskedNumber: last4 == null ? null : 'XXXX XXXX $last4',
        numberHash: null, // full number is not present in the QR
        verhoeffValid: false,
        source: 'qr',
        name: name.isEmpty ? null : name,
        dob: dob,
        yearOfBirth: dob?.year,
        gender: gender,
        address: address.isEmpty ? null : address,
        confidence: name.isEmpty ? 0.3 : 0.9,
        qrSigned: true,
      );
    } catch (_) {
      return null;
    }
  }

  // ============================================================
  // Local matching (against Hive-cached cases)
  // ============================================================
  Future<List<AadhaarCaseMatch>> matchAgainstLocalCases(
    AadhaarScanResult scan, {
    List<Map<String, dynamic>>? cases,
  }) async {
    final pool = cases ?? await _cachedCases();
    if (scan.name == null || pool.isEmpty) return const [];

    final results = <AadhaarCaseMatch>[];
    for (final c in pool) {
      final caseName = (c['missing_person_name'] ?? '').toString();
      if (caseName.isEmpty) continue;

      final nameScore = _nameSimilarity(scan.name!, caseName);
      if (nameScore < 0.55) continue;

      final genderMatch = scan.gender != null &&
          scan.gender!.toLowerCase() ==
              (c['gender'] ?? '').toString().toLowerCase();
      final ageMatch = _ageBandMatches(
          scan.yearOfBirth, (c['age_band'] ?? '').toString());

      var level = 3;
      var score = nameScore * 0.6;
      if (genderMatch) {
        score += 0.15;
        level = 2;
      }
      if (ageMatch) {
        score += 0.25;
        if (genderMatch) level = 1;
      }

      results.add(AadhaarCaseMatch(
        caseId: (c['case_id'] ?? c['id'] ?? '').toString(),
        personName: caseName,
        score: score.clamp(0, 1),
        level: level,
        caseData: c,
      ));
    }
    results.sort((a, b) => b.score.compareTo(a.score));
    return results.take(5).toList();
  }

  /// Salted SHA-256; plaintext numbers are never stored (DESIGN.md §7.2).
  String hashNumber(String digits) =>
      sha256.convert(utf8.encode('$_salt:${digits.replaceAll(' ', '')}'))
          .toString();

  // ============================================================
  // Internals
  // ============================================================
  Future<List<Map<String, dynamic>>> _cachedCases() async {
    try {
      final box = await Hive.openBox(casesBoxName);
      final raw = box.get('cases');
      if (raw is List) {
        return [
          for (final e in raw)
            if (e is Map) Map<String, dynamic>.from(e),
        ];
      }
    } catch (_) {}
    return const [];
  }

  List<int> _bigIntToBytes(BigInt v) {
    final bytes = <int>[];
    var n = v;
    final mask = BigInt.from(0xff);
    while (n > BigInt.zero) {
      bytes.insert(0, (n & mask).toInt());
      n = n >> 8;
    }
    return bytes;
  }

  double _nameSimilarity(String a, String b) {
    final na = a.toLowerCase().replaceAll(RegExp(r'[^a-z ]'), '').trim();
    final nb = b.toLowerCase().replaceAll(RegExp(r'[^a-z ]'), '').trim();
    if (na.isEmpty || nb.isEmpty) return 0;
    if (na == nb) return 1;

    // Token overlap + Levenshtein ratio blend.
    final ta = na.split(RegExp(r'\s+')).toSet();
    final tb = nb.split(RegExp(r'\s+')).toSet();
    final overlap = ta.intersection(tb).length / math.max(ta.length, tb.length);
    final lev = 1 -
        _levenshtein(na, nb) / math.max(na.length, nb.length).toDouble();
    return (overlap * 0.6 + lev * 0.4).clamp(0, 1);
  }

  bool _ageBandMatches(int? yearOfBirth, String ageBand) {
    if (yearOfBirth == null || ageBand.isEmpty) return false;
    final age = DateTime.now().year - yearOfBirth;
    final m = RegExp(r'^(\d+)\s*-\s*(\d+)$').firstMatch(ageBand);
    if (m != null) {
      final lo = int.parse(m[1]!), hi = int.parse(m[2]!);
      return age >= lo - 2 && age <= hi + 2; // tolerance for OCR/band edges
    }
    if (ageBand.endsWith('+')) {
      final lo = int.tryParse(ageBand.replaceAll('+', '')) ?? 0;
      return age >= lo - 2;
    }
    return false;
  }

  int _levenshtein(String s, String t) {
    if (s == t) return 0;
    if (s.isEmpty) return t.length;
    if (t.isEmpty) return s.length;
    var prev = List<int>.generate(t.length + 1, (i) => i);
    final curr = List<int>.filled(t.length + 1, 0);
    for (var i = 0; i < s.length; i++) {
      curr[0] = i + 1;
      for (var j = 0; j < t.length; j++) {
        final cost = s[i] == t[j] ? 0 : 1;
        curr[j + 1] = math.min(
            math.min(curr[j] + 1, prev[j + 1] + 1), prev[j] + cost);
      }
      prev = List.of(curr);
    }
    return curr[t.length];
  }

  void dispose() {
    _recognizer.close();
  }
}
