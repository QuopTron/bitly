import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../backend/rpc/backend_service.dart';
import '../../../../backend/services/verification_service.dart';
import '../../../../injection.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/utils/responsive.dart';
import '../../../shared/widgets/glass_button.dart';
import '../../../shared/widgets/glass_container.dart';
import '../bloc/setup_bloc.dart';
import '../bloc/setup_event.dart';
import '../bloc/setup_state.dart';
import 'package:logger/logger.dart';

final _log = Logger();

enum _ProviderStatus { pending, verifying, verified, failed }

class VerificationSlide extends StatefulWidget {
  final SetupState state;
  final AppLocalizations loc;
  final Responsive r;
  final bool isDark;

  const VerificationSlide({
    super.key,
    required this.state,
    required this.loc,
    required this.r,
    required this.isDark,
  });

  @override
  State<VerificationSlide> createState() => _VerificationSlideState();
}

class _VerificationSlideState extends State<VerificationSlide> {
  static const _providers = [
    ('deezer', 'Deezer'),
    ('qobuz-web', 'Qobuz'),
    ('tidal-web', 'TIDAL'),
    ('amazon', 'Amazon'),
    ('apple-music', 'Apple'),
    ('soundcloud', 'SoundCloud'),
    ('pandora', 'Pandora'),
  ];

  final Map<String, _ProviderStatus> _statuses = {
    for (final p in _providers) p.$1: _ProviderStatus.pending,
  };

  bool _verificationStarted = false;

  bool get _allVerified =>
      _statuses.values.every((s) => s == _ProviderStatus.verified);

  bool get _allAttempted =>
      _statuses.values.every((s) => s == _ProviderStatus.verified || s == _ProviderStatus.failed);

  Future<void> _startVerification() async {
    if (_verificationStarted) return;
    setState(() => _verificationStarted = true);

    final backend = sl<BackendService>();

    for (final (extId, displayName) in _providers) {
      if (!mounted) return;
      setState(() => _statuses[extId] = _ProviderStatus.verifying);

      try {
        _log.i('Verifying $extId...');
        var url = await backend.getPendingVerificationUrl(extId);
        _log.i('$extId: getPendingVerificationUrl returned "$url"');
        if (url.isEmpty) {
          url = await backend.triggerExtensionVerification(extId);
          _log.i('$extId: triggerExtensionVerification returned "$url"');
        }
        if (url.isEmpty) {
          _log.i('$extId: no auth URL needed, marking verified');
          setState(() => _statuses[extId] = _ProviderStatus.verified);
          continue;
        }

        if (!mounted) return;

        // NOTE: a grant is bound to the challenge (install_id) that issued
        // it, so it cannot be reused for another provider — each provider
        // must complete its own Cloudflare challenge.
        _log.i('$extId: opening WebView for $url');
        final grant = await VerificationService().showVerification(
          extId: extId,
          displayName: displayName,
          authUrl: url,
        );
        _log.i('$extId: WebView returned grant=$grant');
        if (grant == null) {
          _log.w('$extId: grant is null, marking failed');
          setState(() => _statuses[extId] = _ProviderStatus.failed);
          continue;
        }

        final ok = await backend.completeSignedSessionGrant(extId, grant);
        _log.i('$extId: completeSignedSessionGrant result=$ok');
        setState(() {
          _statuses[extId] = ok ? _ProviderStatus.verified : _ProviderStatus.failed;
        });
      } catch (e) {
        _log.e('Verification failed for $extId: $e');
        if (mounted) {
          setState(() => _statuses[extId] = _ProviderStatus.failed);
        }
      }
    }

    // Don't auto-advance — let the user see debug output and manually
    // tap Continue.  The VerificationCompleted event is dispatched from
    // the button's onPressed handler instead.
  }

  // WebView logic is handled by VerificationService (shared with download flow).
  // No duplicate WebView implementation needed here.

  @override
  Widget build(BuildContext context) {
    final onBg = widget.isDark ? Colors.white : Colors.black;
    final glowColor = widget.isDark ? AppColors.greenBright : AppColors.greenMedium;

    return Padding(
      padding: EdgeInsets.only(bottom: widget.r.bottomPadding),
      child: Column(children: [
        const Spacer(),
        _icon(onBg),
        SizedBox(height: widget.r.spacingS),
        Text(widget.loc.setup.verificationTitle,
          style: TextStyle(
            fontSize: widget.r.titleSize,
            fontWeight: FontWeight.bold,
            color: onBg,
            letterSpacing: 1,
          )),
        SizedBox(height: widget.r.spacingM),
        Expanded(
          child: SingleChildScrollView(
            child: _providerList(onBg, glowColor),
          ),
        ),
        SizedBox(height: widget.r.spacingM),
        _actions(onBg, glowColor),
        SizedBox(height: widget.r.spacingM),
      ]),
    );
  }

  Widget _icon(Color onBg) => Container(
    padding: EdgeInsets.all(widget.r.spacingS),
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: onBg.withValues(alpha: 0.04),
      border: Border.all(color: onBg.withValues(alpha: 0.08), width: 0.8),
    ),
    child: Icon(Icons.verified_user_outlined,
      size: widget.r.titleSize * 1.1,
      color: onBg.withValues(alpha: 0.55)),
  );

  Widget _providerList(Color onBg, Color glowColor) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: widget.r.spacingXL),
      child: GlassContainer(
        borderRadius: 14,
        borderColor: glowColor.withValues(alpha: 0.15),
        bgColor: onBg.withValues(alpha: 0.02),
        padding: EdgeInsets.all(widget.r.spacingM),
        child: Column(
          children: [
            Text(widget.loc.setup.verificationDesc,
              style: TextStyle(
                fontSize: widget.r.footerSize,
                color: onBg.withValues(alpha: 0.65),
              )),
            SizedBox(height: widget.r.spacingM),
            ..._providers.map((p) => _providerRow(p.$1, p.$2, onBg, glowColor)),
          ],
        ),
      ),
    );
  }

  Widget _providerRow(String extId, String displayName, Color onBg, Color glowColor) {
    final status = _statuses[extId] ?? _ProviderStatus.pending;
    final icon = switch (status) {
      _ProviderStatus.pending => Icons.hourglass_empty,
      _ProviderStatus.verifying => Icons.sync,
      _ProviderStatus.verified => Icons.check_circle,
      _ProviderStatus.failed => Icons.error_outline,
    };
    final color = switch (status) {
      _ProviderStatus.pending => onBg.withValues(alpha: 0.35),
      _ProviderStatus.verifying => glowColor,
      _ProviderStatus.verified => glowColor,
      _ProviderStatus.failed => Colors.redAccent,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Icon(icon, size: widget.r.footerSize + 4, color: color),
        SizedBox(width: widget.r.spacingS),
        Expanded(
          child: Text(displayName,
            style: TextStyle(
              fontSize: widget.r.footerSize,
              color: status == _ProviderStatus.verified
                  ? onBg.withValues(alpha: 0.8)
                  : onBg.withValues(alpha: 0.5),
            )),
        ),
        if (status == _ProviderStatus.verifying)
          SizedBox(
            width: widget.r.footerSize,
            height: widget.r.footerSize,
            child: CircularProgressIndicator(strokeWidth: 2, color: glowColor),
          ),
      ]),
    );
  }

  Widget _actions(Color onBg, Color glowColor) {
    final showLoading = _verificationStarted && !_allAttempted;
    final canContinue = _verificationStarted && _allAttempted;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: widget.r.spacingXL),
      child: GlassButton(
        label: canContinue
            ? widget.loc.setup.continueText
            : _allVerified
                ? widget.loc.setup.continueText
                : widget.loc.setup.verificationStart,
        onPressed: () async {
          if (!_verificationStarted) {
            await _startVerification();
          } else if (canContinue || _allVerified) {
            context.read<SetupBloc>().add(const VerificationCompleted());
          }
        },
        isLoading: showLoading,
        height: widget.r.continueButtonHeight,
        accent: glowColor,
      ),
    );
  }
}
