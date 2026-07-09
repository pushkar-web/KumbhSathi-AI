import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../providers/ai_providers.dart';
import '../../../providers/core_providers.dart';
import '../../../providers/dashboard_providers.dart';
import '../../../services/aadhaar/aadhaar_service.dart';
import '../../../services/aadhaar/verhoeff.dart';
import '../../../shared/widgets/animated_count.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/gradient_button.dart';
import '../../../shared/widgets/loading_shimmer.dart';
import '../../../shared/widgets/offline_banner.dart';
import '../../../shared/widgets/person_avatar.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/status_badge.dart';

/// Offline Aadhaar scanner & verifier (DESIGN.md §6.1 + §7.2).
///
/// Three modes — card OCR, UIDAI secure QR, manual entry — all processed
/// fully on-device: Verhoeff checksum offline, salted SHA-256 hash only,
/// raw image discarded, matches run against the locally cached case index
/// and the record is queued for sync.
class AadhaarScannerScreen extends ConsumerStatefulWidget {
  const AadhaarScannerScreen({super.key});

  @override
  ConsumerState<AadhaarScannerScreen> createState() =>
      _AadhaarScannerScreenState();
}

class _AadhaarScannerScreenState extends ConsumerState<AadhaarScannerScreen> {
  // ---- consent ----
  bool _consented = false;

  // ---- mode: 0 = Scan Card, 1 = Scan QR, 2 = Manual ----
  int _mode = 0;

  // ---- extraction / result state ----
  bool _extracting = false;
  AadhaarScanResult? _scan;
  bool _matching = false;
  List<AadhaarCaseMatch>? _matches;
  bool _saved = false;

  // ---- scan-card ----
  final ImagePicker _picker = ImagePicker();

  // ---- QR ----
  MobileScannerController? _qrController;
  bool _qrHandled = false;
  bool _torchOn = false;
  int _qrSession = 0;
  DateTime? _lastQrWarning;

  // ---- editable result form ----
  final _nameCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();
  final _maskedCtrl = TextEditingController();
  String? _gender;

  // ---- manual entry ----
  final _manNumberCtrl = TextEditingController();
  final _manNameCtrl = TextEditingController();
  final _manAgeCtrl = TextEditingController();
  String? _manGender;

  static final _nonDigits = RegExp(r'\D');

  @override
  void initState() {
    super.initState();
    _manNumberCtrl.addListener(_onManualNumberChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _showConsentDialog());
  }

  @override
  void dispose() {
    _manNumberCtrl.removeListener(_onManualNumberChanged);
    try {
      _qrController?.dispose();
    } catch (_) {}
    _nameCtrl.dispose();
    _dobCtrl.dispose();
    _maskedCtrl.dispose();
    _manNumberCtrl.dispose();
    _manNameCtrl.dispose();
    _manAgeCtrl.dispose();
    super.dispose();
  }

  void _onManualNumberChanged() {
    if (mounted) setState(() {});
  }

  // ============================================================
  // Consent (DESIGN.md §7.2 — consent dialog precedes scan)
  // ============================================================
  Future<void> _showConsentDialog() async {
    if (!mounted || _consented) return;
    final agreed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.modal),
          ),
          title: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(AppRadius.input),
                ),
                child: Icon(Symbols.shield_lock,
                    color: theme.colorScheme.primary),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  'Aadhaar privacy consent',
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _AadhScanConsentRow(
                icon: Symbols.smartphone,
                title: 'Processed on-device',
                body:
                    'OCR, QR parsing and the Verhoeff checksum run entirely on this phone — nothing is uploaded.',
              ),
              SizedBox(height: AppSpacing.base),
              _AadhScanConsentRow(
                icon: Symbols.delete,
                title: 'Image discarded',
                body:
                    'The card photo is analysed in memory and discarded immediately after extraction.',
              ),
              SizedBox(height: AppSpacing.base),
              _AadhScanConsentRow(
                icon: Symbols.tag,
                title: 'Only a salted hash stored',
                body:
                    'The Aadhaar number is never saved — only a salted SHA-256 hash used to match missing-person cases.',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Not now'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
              child: const Text('I consent'),
            ),
          ],
        );
      },
    );
    if (!mounted) return;
    setState(() => _consented = agreed ?? false);
  }

  // ============================================================
  // Mode 1 — card photo → on-device OCR
  // ============================================================
  Future<void> _pickAndExtract(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(source: source, maxWidth: 1280);
      if (picked == null || !mounted) return;
      setState(() {
        _extracting = true;
        _scan = null;
        _matches = null;
        _saved = false;
      });
      final scan =
          await ref.read(aadhaarServiceProvider).extractFromImage(picked.path);
      if (!mounted) return;
      if (scan == null || !scan.hasIdentity) {
        setState(() => _extracting = false);
        _snack('Could not read the card — retake in better light, no glare.');
        return;
      }
      _applyScan(scan);
    } catch (_) {
      if (!mounted) return;
      setState(() => _extracting = false);
      _snack('Scan failed — the image was discarded. Please try again.');
    }
  }

  // ============================================================
  // Mode 2 — UIDAI secure QR
  // ============================================================
  void _onQrDetect(BarcodeCapture capture) {
    if (_qrHandled || _scan != null || !mounted) return;
    String? raw;
    for (final barcode in capture.barcodes) {
      final v = barcode.rawValue;
      if (v != null && v.isNotEmpty) {
        raw = v;
        break;
      }
    }
    if (raw == null) return;
    try {
      final scan = ref.read(aadhaarServiceProvider).parseSecureQr(raw);
      if (scan == null) {
        final now = DateTime.now();
        if (_lastQrWarning == null ||
            now.difference(_lastQrWarning!) > const Duration(seconds: 3)) {
          _lastQrWarning = now;
          _snack('Not a UIDAI secure QR — aim at the QR on the Aadhaar card.');
        }
        return;
      }
      _qrHandled = true;
      try {
        unawaited(_qrController?.stop());
      } catch (_) {}
      _applyScan(scan);
    } catch (_) {
      // Malformed payload — keep scanning.
    }
  }

  void _rescanQr() {
    try {
      _qrController?.dispose();
    } catch (_) {}
    _qrController = null;
    setState(() {
      _qrSession++;
      _qrHandled = false;
      _torchOn = false;
      _scan = null;
      _matches = null;
      _saved = false;
    });
  }

  Future<void> _toggleTorch() async {
    try {
      await _qrController?.toggleTorch();
      if (mounted) setState(() => _torchOn = !_torchOn);
    } catch (_) {
      _snack('Torch is not available on this camera.');
    }
  }

  // ============================================================
  // Mode 3 — manual entry
  // ============================================================
  void _applyManual() {
    try {
      final digits = _manNumberCtrl.text.replaceAll(_nonDigits, '');
      if (digits.length != 12 || _manNameCtrl.text.trim().isEmpty) return;
      final age = int.tryParse(_manAgeCtrl.text.trim());
      final scan = AadhaarScanResult(
        maskedNumber: 'XXXX XXXX ${digits.substring(8)}',
        numberHash: ref.read(aadhaarServiceProvider).hashNumber(digits),
        verhoeffValid: Verhoeff.isValidAadhaar(digits),
        source: 'manual',
        name: _manNameCtrl.text.trim(),
        gender: _manGender,
        yearOfBirth: age == null ? null : DateTime.now().year - age,
        confidence: 1,
      );
      _applyScan(scan);
    } catch (_) {
      _snack('Could not build the record — please check the fields.');
    }
  }

  // ============================================================
  // Shared result / matching / offline queue
  // ============================================================
  void _applyScan(AadhaarScanResult scan) {
    _nameCtrl.text = scan.name ?? '';
    _dobCtrl.text = scan.dob != null
        ? DateFormat('dd/MM/yyyy').format(scan.dob!)
        : (scan.yearOfBirth?.toString() ?? '');
    _maskedCtrl.text = scan.maskedNumber ?? 'Not captured';
    _gender = scan.gender;
    setState(() {
      _scan = scan;
      _extracting = false;
      _matches = null;
      _matching = false;
      _saved = false;
    });
  }

  /// Re-reads the editable form so user corrections flow into matching.
  AadhaarScanResult _editedScan(AadhaarScanResult base) {
    DateTime? dob = base.dob;
    int? yob = base.yearOfBirth;
    final dobText = _dobCtrl.text.trim();
    if (dobText.isEmpty) {
      dob = null;
      yob = null;
    } else {
      try {
        dob = DateFormat('dd/MM/yyyy').parseStrict(dobText);
        yob = dob.year;
      } catch (_) {
        final y = int.tryParse(dobText);
        if (y != null && y > 1900 && y <= DateTime.now().year) {
          dob = null;
          yob = y;
        }
      }
    }
    final name = _nameCtrl.text.trim();
    return AadhaarScanResult(
      maskedNumber: base.maskedNumber,
      numberHash: base.numberHash,
      verhoeffValid: base.verhoeffValid,
      source: base.source,
      name: name.isEmpty ? null : name,
      dob: dob,
      yearOfBirth: yob,
      gender: _gender,
      address: base.address,
      confidence: base.confidence,
      qrSigned: base.qrSigned,
    );
  }

  Future<void> _findMatches() async {
    final base = _scan;
    if (base == null || _matching) return;
    setState(() {
      _matching = true;
      _matches = null;
    });
    try {
      final edited = _editedScan(base);
      _scan = edited;
      final cases =
          ref.read(casesProvider).value ?? const <Map<String, dynamic>>[];
      final matches = await ref
          .read(aadhaarServiceProvider)
          .matchAgainstLocalCases(edited, cases: cases);
      if (!mounted) return;
      setState(() {
        _matching = false;
        _matches = matches;
      });
      await _queueRecord(edited, matches);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _matching = false;
        _matches = const [];
      });
      _snack('Matching failed — the record is kept on this device.');
    }
  }

  Future<void> _queueRecord(
    AadhaarScanResult scan,
    List<AadhaarCaseMatch> matches,
  ) async {
    try {
      await ref.read(hiveServiceProvider).queueRequest(
        path: '/api/v1/aadhaar/records',
        method: 'POST',
        body: {
          'hash': scan.numberHash,
          'fields': {
            'name': scan.name,
            'dob': scan.dob?.toIso8601String(),
            'year_of_birth': scan.yearOfBirth,
            'gender': scan.gender,
            'masked_number': scan.maskedNumber,
            'address': scan.address,
            'source': scan.source,
            'verhoeff_valid': scan.verhoeffValid,
            'qr_signed': scan.qrSigned,
            'confidence': scan.confidence,
          },
          'matches': [
            for (final m in matches)
              {
                'case_id': m.caseId,
                'person_name': m.personName,
                'score': m.score,
                'level': m.level,
              },
          ],
        },
      );
      if (!mounted) return;
      setState(() => _saved = true);
      _snack('Saved — will sync');
    } catch (_) {
      if (mounted) _snack('Could not queue the record — kept on this device.');
    }
  }

  void _reset() {
    _nameCtrl.clear();
    _dobCtrl.clear();
    _maskedCtrl.clear();
    if (_mode == 1) {
      _rescanQr();
      return;
    }
    setState(() {
      _scan = null;
      _matches = null;
      _matching = false;
      _saved = false;
      _gender = null;
    });
  }

  void _switchMode(int mode) {
    if (mode == _mode) return;
    try {
      unawaited(_qrController?.stop());
    } catch (_) {}
    setState(() {
      _mode = mode;
      _extracting = false;
      _scan = null;
      _matches = null;
      _matching = false;
      _saved = false;
      _qrHandled = false;
      _torchOn = false;
      _qrSession++;
    });
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ));
  }

  // ============================================================
  // Build
  // ============================================================
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final casesAsync = ref.watch(casesProvider);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Symbols.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          'Aadhaar Verify',
          style: theme.textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        actions: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.successContainer,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Row(
              children: [
                const Icon(Symbols.verified_user,
                    size: 14, color: AppColors.success),
                const SizedBox(width: 4),
                Text(
                  'On-device',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.success,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.gutterMobile),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const OfflineBanner(),
            Expanded(
              child: !_consented
                  ? EmptyState(
                      icon: Symbols.shield_lock,
                      title: 'Consent needed to scan',
                      subtitle:
                          'Aadhaar verification runs fully on this device — the image is discarded and only a salted hash is stored.',
                      actionLabel: 'Review consent',
                      onAction: _showConsentDialog,
                    )
                  : _buildContent(theme, casesAsync),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(
    ThemeData theme,
    AsyncValue<List<Map<String, dynamic>>> casesAsync,
  ) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.gutterMobile,
        AppSpacing.base,
        AppSpacing.gutterMobile,
        AppSpacing.xxl,
      ),
      children: [
        _AadhScanModeSelector(selected: _mode, onChanged: _switchMode)
            .animate()
            .fadeIn(duration: 240.ms)
            .slideY(begin: 0.06, curve: Curves.easeOutCubic),
        const SizedBox(height: AppSpacing.base),
        _buildModeSection(theme)
            .animate()
            .fadeIn(delay: 50.ms, duration: 240.ms)
            .slideY(begin: 0.06, curve: Curves.easeOutCubic),
        if (_extracting) ...[
          const SizedBox(height: AppSpacing.base),
          const _AadhScanResultShimmer()
              .animate()
              .fadeIn(duration: 240.ms),
        ],
        if (_scan != null) ...[
          SectionHeader(
            'Extracted details',
            icon: Symbols.badge,
            actionLabel: 'Start over',
            onAction: _reset,
          ),
          _buildResultCard(theme, casesAsync)
              .animate()
              .fadeIn(duration: 240.ms)
              .slideY(begin: 0.06, curve: Curves.easeOutCubic),
        ],
        if (_matching) ...[
          const SectionHeader('Local matches', icon: Symbols.person_search),
          const ShimmerList(items: 3, itemHeight: 92),
        ] else if (_matches != null)
          ..._buildMatchesSection(theme),
        const SizedBox(height: AppSpacing.base),
        _buildPrivacyFootnote(theme)
            .animate()
            .fadeIn(delay: 100.ms, duration: 240.ms),
      ],
    );
  }

  // ------------------------------------------------------------
  // Mode sections
  // ------------------------------------------------------------
  Widget _buildModeSection(ThemeData theme) {
    switch (_mode) {
      case 1:
        return _buildQrSection(theme);
      case 2:
        return _buildManualSection(theme);
      default:
        return _buildCardSection(theme);
    }
  }

  Widget _buildCardSection(ThemeData theme) {
    final scheme = theme.colorScheme;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 1.586, // ID-1 card ratio
            child: Container(
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(AppRadius.card),
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _AadhScanDashPainter(
                        color: scheme.primary.withValues(alpha: 0.45),
                      ),
                    ),
                  ),
                  Positioned(
                      top: 10,
                      left: 10,
                      child: _AadhScanCorner(
                          top: true, left: true, color: scheme.primary)),
                  Positioned(
                      top: 10,
                      right: 10,
                      child: _AadhScanCorner(
                          top: true, left: false, color: scheme.primary)),
                  Positioned(
                      bottom: 10,
                      left: 10,
                      child: _AadhScanCorner(
                          top: false, left: true, color: scheme.primary)),
                  Positioned(
                      bottom: 10,
                      right: 10,
                      child: _AadhScanCorner(
                          top: false, left: false, color: scheme.primary)),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: scheme.primaryContainer,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Symbols.id_card,
                              size: 28, color: scheme.primary),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          'Fit the Aadhaar card inside the frame',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Good light · flat card · no glare',
                          style: theme.textTheme.labelSmall
                              ?.copyWith(color: AppColors.inkFaint),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.base),
          Row(
            children: [
              Expanded(
                child: PrimaryCta.tonal(
                  label: 'Camera',
                  icon: Symbols.photo_camera,
                  onPressed: _extracting
                      ? null
                      : () => _pickAndExtract(ImageSource.camera),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: PrimaryCta.tonal(
                  label: 'Gallery',
                  icon: Symbols.photo_library,
                  onPressed: _extracting
                      ? null
                      : () => _pickAndExtract(ImageSource.gallery),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Photo is processed on-device and discarded after extraction.',
            textAlign: TextAlign.center,
            style: theme.textTheme.labelSmall
                ?.copyWith(color: AppColors.inkFaint),
          ),
        ],
      ),
    );
  }

  Widget _buildQrSection(ThemeData theme) {
    final scheme = theme.colorScheme;

    if (_scan != null) {
      return AppCard(
        accentColor: AppColors.success,
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: AppColors.successContainer,
                shape: BoxShape.circle,
              ),
              child: const Icon(Symbols.qr_code_2,
                  size: 22, color: AppColors.success),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Secure QR captured',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    'Details decoded offline — review them below.',
                    style: theme.textTheme.labelMedium
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            TextButton(onPressed: _rescanQr, child: const Text('Rescan')),
          ],
        ),
      );
    }

    _qrController ??= MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      formats: const [BarcodeFormat.qrCode],
    );

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.card),
            child: SizedBox(
              height: 320,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  KeyedSubtree(
                    key: ValueKey('aadh-qr-$_qrSession'),
                    child: MobileScanner(
                      controller: _qrController,
                      onDetect: _onQrDetect,
                      placeholderBuilder: (context) => ColoredBox(
                        color: scheme.surfaceContainerHigh,
                        child: const Center(
                          child: ShimmerBox(
                              width: 120, height: 120, radius: AppRadius.card),
                        ),
                      ),
                      errorBuilder: (context, error) => ColoredBox(
                        color: scheme.surfaceContainerHigh,
                        child: const EmptyState(
                          icon: Symbols.no_photography,
                          title: 'Camera unavailable',
                          subtitle:
                              'Grant camera permission, or use Manual entry instead.',
                        ),
                      ),
                    ),
                  ),
                  const Positioned(
                      top: 14,
                      left: 14,
                      child: _AadhScanCorner(
                          top: true, left: true, color: Colors.white)),
                  const Positioned(
                      top: 14,
                      right: 14,
                      child: _AadhScanCorner(
                          top: true, left: false, color: Colors.white)),
                  const Positioned(
                      bottom: 14,
                      left: 14,
                      child: _AadhScanCorner(
                          top: false, left: true, color: Colors.white)),
                  const Positioned(
                      bottom: 14,
                      right: 14,
                      child: _AadhScanCorner(
                          top: false, left: false, color: Colors.white)),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(
                          AppSpacing.base, AppSpacing.xxl,
                          AppSpacing.base, AppSpacing.md),
                      decoration: const BoxDecoration(
                          gradient: AppColors.scrimGradient),
                      child: Text(
                        'Point at the secure QR on the Aadhaar card',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: AppSpacing.sm,
                    right: AppSpacing.sm,
                    child: Material(
                      color: AppColors.primaryDeep.withValues(alpha: 0.45),
                      shape: const CircleBorder(),
                      clipBehavior: Clip.antiAlias,
                      child: IconButton(
                        onPressed: _toggleTorch,
                        icon: Icon(
                          _torchOn
                              ? Symbols.flashlight_on
                              : Symbols.flashlight_off,
                          color: Colors.white,
                          size: 22,
                        ),
                        tooltip: 'Toggle torch',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Symbols.encrypted,
                    size: 16, color: AppColors.inkFaint),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Decoded offline — the tamper-evident UIDAI payload never leaves the device.',
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: AppColors.inkFaint),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildManualSection(ThemeData theme) {
    final scheme = theme.colorScheme;
    final digits = _manNumberCtrl.text.replaceAll(_nonDigits, '');

    final Widget liveBadge;
    if (digits.isEmpty) {
      liveBadge = _AadhScanBadge(
        icon: Symbols.pin,
        label: 'Enter the 12-digit number',
        fg: scheme.onSurfaceVariant,
        bg: scheme.surfaceContainerHigh,
      );
    } else if (digits.length < 12) {
      liveBadge = _AadhScanBadge(
        icon: Symbols.pending,
        label: '${12 - digits.length} more digit${12 - digits.length == 1 ? '' : 's'}',
        fg: scheme.onSurfaceVariant,
        bg: scheme.surfaceContainerHigh,
      );
    } else if (Verhoeff.isValidAadhaar(digits)) {
      liveBadge = const _AadhScanBadge(
        icon: Symbols.check_circle,
        label: 'Checksum valid ✓',
        fg: AppColors.success,
        bg: AppColors.successContainer,
      );
    } else {
      liveBadge = const _AadhScanBadge(
        icon: Symbols.error,
        label: 'Checksum failed',
        fg: AppColors.danger,
        bg: AppColors.dangerContainer,
      );
    }

    final canContinue =
        digits.length == 12 && _manNameCtrl.text.trim().isNotEmpty;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Enter Aadhaar details',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'The Verhoeff checksum is verified live as you type — fully offline.',
            style: theme.textTheme.labelMedium
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.base),
          TextField(
            controller: _manNumberCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(12),
            ],
            style: theme.textTheme.bodyLarge?.copyWith(letterSpacing: 2),
            decoration: const InputDecoration(
              labelText: 'Aadhaar number',
              hintText: '12-digit number',
              prefixIcon: Icon(Symbols.pin),
              counterText: '',
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          AnimatedSwitcher(
            duration: AppMotion.exit,
            child: KeyedSubtree(
              key: ValueKey('aadh-manual-badge-${digits.length >= 12 ? Verhoeff.isValidAadhaar(digits) : digits.length}'),
              child: liveBadge,
            ),
          ),
          const SizedBox(height: AppSpacing.base),
          TextField(
            controller: _manNameCtrl,
            textCapitalization: TextCapitalization.words,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Full name (as on card)',
              prefixIcon: Icon(Symbols.person),
            ),
          ),
          const SizedBox(height: AppSpacing.base),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 110,
                child: TextField(
                  controller: _manAgeCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(3),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Age',
                    prefixIcon: Icon(Symbols.cake),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.base),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Gender',
                      style: theme.textTheme.labelMedium
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Wrap(
                      spacing: AppSpacing.sm,
                      children: [
                        for (final g in const ['Male', 'Female'])
                          ChoiceChip(
                            label: Text(g),
                            selected: _manGender == g,
                            onSelected: (sel) =>
                                setState(() => _manGender = sel ? g : null),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          PrimaryCta.tonal(
            label: 'Use these details',
            icon: Symbols.arrow_forward,
            onPressed: canContinue ? _applyManual : null,
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // Result form
  // ------------------------------------------------------------
  Widget _buildResultCard(
    ThemeData theme,
    AsyncValue<List<Map<String, dynamic>>> casesAsync,
  ) {
    final scan = _scan!;
    final scheme = theme.colorScheme;
    final sourceLabel = switch (scan.source) {
      'qr' => 'Secure QR',
      'manual' => 'Manual entry',
      _ => 'Card OCR',
    };
    final confidence = scan.confidence.clamp(0.0, 1.0);
    final confColor = confidence >= 0.7
        ? AppColors.success
        : confidence >= 0.4
            ? AppColors.warning
            : AppColors.danger;
    final cachedCount = casesAsync.value?.length ?? 0;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _AadhScanBadge(
                icon: Symbols.document_scanner,
                label: sourceLabel,
                fg: scheme.primary,
                bg: scheme.primaryContainer,
              ),
              if (scan.qrSigned)
                const _AadhScanBadge(
                  icon: Symbols.verified,
                  label: 'UIDAI Secure QR ✓',
                  fg: AppColors.success,
                  bg: AppColors.successContainer,
                )
              else if (scan.verhoeffValid)
                const _AadhScanBadge(
                  icon: Symbols.check_circle,
                  label: 'Checksum valid ✓',
                  fg: AppColors.success,
                  bg: AppColors.successContainer,
                )
              else
                const _AadhScanBadge(
                  icon: Symbols.error,
                  label: 'Checksum failed',
                  fg: AppColors.danger,
                  bg: AppColors.dangerContainer,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.base),
          TextField(
            controller: _maskedCtrl,
            readOnly: true,
            decoration: const InputDecoration(
              labelText: 'Aadhaar number (masked)',
              prefixIcon: Icon(Symbols.pin),
              suffixIcon: Icon(Symbols.lock, size: 18),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _nameCtrl,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Full name',
              prefixIcon: Icon(Symbols.person),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _dobCtrl,
            keyboardType: TextInputType.datetime,
            decoration: InputDecoration(
              labelText: 'Date of birth',
              hintText: 'DD/MM/YYYY or year',
              prefixIcon: const Icon(Symbols.calendar_month),
              suffixIcon: IconButton(
                icon: const Icon(Symbols.edit_calendar, size: 20),
                onPressed: _pickDob,
                tooltip: 'Pick date',
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Text(
                'Gender',
                style: theme.textTheme.labelMedium
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(width: AppSpacing.md),
              for (final g in const ['Male', 'Female']) ...[
                ChoiceChip(
                  label: Text(g),
                  selected: _gender == g,
                  onSelected: (sel) =>
                      setState(() => _gender = sel ? g : null),
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
            ],
          ),
          if (scan.address != null) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Symbols.home_pin,
                    size: 18, color: AppColors.inkFaint),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    scan.address!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.base),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Extraction confidence',
                  style: theme.textTheme.labelMedium
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
              AnimatedCount(
                confidence * 100,
                suffix: '%',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: confColor,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          TweenAnimationBuilder<double>(
            duration: AppMotion.counter,
            curve: AppMotion.easeOut,
            tween: Tween(begin: 0, end: confidence),
            builder: (context, v, _) => ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: SizedBox(
                height: 8,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ColoredBox(color: scheme.surfaceContainerHigh),
                    ),
                    FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: v,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: confColor,
                          borderRadius:
                              BorderRadius.circular(AppRadius.pill),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          PrimaryCta(
            label: 'Find matches',
            icon: Symbols.person_search,
            loading: _matching,
            onPressed: _matching ? null : _findMatches,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Runs against $cachedCount locally cached case${cachedCount == 1 ? '' : 's'} — works offline.',
            textAlign: TextAlign.center,
            style:
                theme.textTheme.labelSmall?.copyWith(color: AppColors.inkFaint),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _scan?.dob ?? DateTime(now.year - 30),
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked == null || !mounted) return;
    setState(() => _dobCtrl.text = DateFormat('dd/MM/yyyy').format(picked));
  }

  // ------------------------------------------------------------
  // Matches
  // ------------------------------------------------------------
  List<Widget> _buildMatchesSection(ThemeData theme) {
    final matches = _matches!;
    return [
      const SectionHeader('Local matches', icon: Symbols.person_search),
      if (matches.isEmpty)
        const AppCard(
          padding: EdgeInsets.zero,
          child: EmptyState(
            icon: Symbols.person_search,
            title: 'No local match',
            subtitle: 'No cached case matched this identity — the record is '
                'stored for future matching.',
          ),
        ).animate().fadeIn(duration: 240.ms)
      else
        for (var i = 0; i < matches.length && i < 5; i++)
          _AadhScanMatchCard(match: matches[i])
              .animate()
              .fadeIn(delay: (i * 50).ms, duration: 240.ms)
              .slideY(begin: 0.06, curve: Curves.easeOutCubic),
      if (_saved) ...[
        const SizedBox(height: AppSpacing.sm),
        const Align(
          alignment: Alignment.center,
          child: _AadhScanBadge(
            icon: Symbols.cloud_sync,
            label: 'Saved — will sync when online',
            fg: AppColors.warning,
            bg: AppColors.warningContainer,
          ),
        ),
      ],
    ];
  }

  Widget _buildPrivacyFootnote(ThemeData theme) {
    final scheme = theme.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Symbols.verified_user, size: 16, color: scheme.primary),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            'Privacy secure: processed on-device, the card image is discarded '
            'and only a salted SHA-256 hash of the number is stored.',
            style:
                theme.textTheme.labelSmall?.copyWith(color: AppColors.inkFaint),
          ),
        ),
      ],
    );
  }
}

// ============================================================
// Private helper widgets
// ============================================================

/// Segmented 3-mode selector (Scan Card / Scan QR / Manual).
class _AadhScanModeSelector extends StatelessWidget {
  const _AadhScanModeSelector({required this.selected, required this.onChanged});

  final int selected;
  final ValueChanged<int> onChanged;

  static const _items = [
    (icon: Symbols.id_card, label: 'Scan Card'),
    (icon: Symbols.qr_code_scanner, label: 'Scan QR'),
    (icon: Symbols.keyboard, label: 'Manual'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppRadius.input + 4),
      ),
      child: Row(
        children: [
          for (var i = 0; i < _items.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(i),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: AppMotion.exit,
                  curve: AppMotion.easeOut,
                  height: 44,
                  decoration: BoxDecoration(
                    color: selected == i ? scheme.surface : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppRadius.input),
                    boxShadow: selected == i ? AppShadows.card : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _items[i].icon,
                        size: 18,
                        color: selected == i
                            ? scheme.primary
                            : scheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          _items[i].label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: selected == i
                                ? scheme.primary
                                : scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Tonal pill badge (checksum / secure QR / sync states).
class _AadhScanBadge extends StatelessWidget {
  const _AadhScanBadge({
    required this.label,
    required this.fg,
    required this.bg,
    this.icon,
  });

  final String label;
  final Color fg;
  final Color bg;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(color: fg, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

/// Consent dialog bullet row.
class _AadhScanConsentRow extends StatelessWidget {
  const _AadhScanConsentRow({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.labelLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(
                body,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// One corner bracket of the capture frame / viewfinder.
class _AadhScanCorner extends StatelessWidget {
  const _AadhScanCorner({
    required this.top,
    required this.left,
    required this.color,
  });

  final bool top;
  final bool left;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final side = BorderSide(color: color, width: 3);
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        border: Border(
          top: top ? side : BorderSide.none,
          bottom: !top ? side : BorderSide.none,
          left: left ? side : BorderSide.none,
          right: !left ? side : BorderSide.none,
        ),
        borderRadius: BorderRadius.only(
          topLeft: top && left ? const Radius.circular(10) : Radius.zero,
          topRight: top && !left ? const Radius.circular(10) : Radius.zero,
          bottomLeft: !top && left ? const Radius.circular(10) : Radius.zero,
          bottomRight: !top && !left ? const Radius.circular(10) : Radius.zero,
        ),
      ),
    );
  }
}

/// Dashed rounded-rect border for the card capture zone.
class _AadhScanDashPainter extends CustomPainter {
  const _AadhScanDashPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Offset.zero & size,
        const Radius.circular(AppRadius.card),
      ));
    const dash = 7.0;
    const gap = 5.0;
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(
          metric.extractPath(d, math.min(d + dash, metric.length)),
          paint,
        );
        d += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _AadhScanDashPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Shimmer skeleton mirroring the extracted-details card.
class _AadhScanResultShimmer extends StatelessWidget {
  const _AadhScanResultShimmer();

  @override
  Widget build(BuildContext context) {
    return const AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ShimmerBox(width: 110, height: 26, radius: AppRadius.pill),
              SizedBox(width: AppSpacing.sm),
              ShimmerBox(width: 130, height: 26, radius: AppRadius.pill),
            ],
          ),
          SizedBox(height: AppSpacing.base),
          ShimmerBox(height: 52, radius: AppRadius.input),
          SizedBox(height: AppSpacing.md),
          ShimmerBox(height: 52, radius: AppRadius.input),
          SizedBox(height: AppSpacing.md),
          ShimmerBox(height: 52, radius: AppRadius.input),
          SizedBox(height: AppSpacing.base),
          ShimmerBox(height: 8, radius: AppRadius.pill),
          SizedBox(height: AppSpacing.lg),
          ShimmerBox(height: 52, radius: AppRadius.button),
        ],
      ),
    );
  }
}

/// A matched local case: avatar, name, case id, level label + score ring.
class _AadhScanMatchCard extends StatelessWidget {
  const _AadhScanMatchCard({required this.match});

  final AadhaarCaseMatch match;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final (fg, bg) = _bandColors(match.score);
    final levelLabel = switch (match.level) {
      1 => 'Strong match',
      2 => 'Probable match',
      _ => 'Possible match',
    };
    final status = (match.caseData['status'] ?? '').toString();

    return AppCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      accentColor: fg,
      child: Row(
        children: [
          PersonAvatar(match.personName, size: 48),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  match.personName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  'Case ${match.caseId}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  children: [
                    _AadhScanBadge(label: levelLabel, fg: fg, bg: bg),
                    if (status.isNotEmpty) StatusBadge.fromLabel(status),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          _AadhScanScoreRing(score: match.score),
        ],
      ),
    );
  }

  static (Color, Color) _bandColors(double score) {
    if (score >= 0.8) return (AppColors.success, AppColors.successContainer);
    if (score >= 0.6) return (AppColors.warning, AppColors.warningContainer);
    return (AppColors.danger, AppColors.dangerContainer);
  }
}

/// Animated circular score ring, colored by confidence band.
class _AadhScanScoreRing extends StatelessWidget {
  const _AadhScanScoreRing({required this.score});

  final double score;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = score >= 0.8
        ? AppColors.success
        : score >= 0.6
            ? AppColors.warning
            : AppColors.danger;
    final clamped = score.clamp(0.0, 1.0);

    return SizedBox(
      width: 56,
      height: 56,
      child: TweenAnimationBuilder<double>(
        duration: AppMotion.counter,
        curve: AppMotion.easeOut,
        tween: Tween(begin: 0, end: clamped),
        builder: (context, v, child) => CustomPaint(
          painter: _AadhScanRingPainter(
            progress: v,
            color: color,
            track: theme.colorScheme.surfaceContainerHigh,
          ),
          child: child,
        ),
        child: Center(
          child: AnimatedCount(
            clamped * 100,
            suffix: '%',
            style: theme.textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _AadhScanRingPainter extends CustomPainter {
  const _AadhScanRingPainter({
    required this.progress,
    required this.color,
    required this.track,
  });

  final double progress;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 5.0;
    final rect = (Offset.zero & size).deflate(stroke / 2);
    final trackPaint = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawArc(rect, 0, math.pi * 2, false, trackPaint);

    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
        rect, -math.pi / 2, math.pi * 2 * progress, false, progressPaint);
  }

  @override
  bool shouldRepaint(covariant _AadhScanRingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.color != color ||
      oldDelegate.track != track;
}
