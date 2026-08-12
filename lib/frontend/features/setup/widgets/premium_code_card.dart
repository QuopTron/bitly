import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/utils/responsive.dart';
import '../../../shared/widgets/glass_container.dart';
import '../../../shared/widgets/glass_button.dart';
import '../bloc/setup_bloc.dart';
import '../bloc/setup_event.dart';
import '../bloc/setup_state.dart';

class PremiumCodeCard extends StatelessWidget {
  final SetupState state;
  final AppLocalizations loc;
  final Responsive r;
  final Color onBg;
  final Color glowColor;

  const PremiumCodeCard({
    super.key,
    required this.state,
    required this.loc,
    required this.r,
    required this.onBg,
    required this.glowColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: r.spacingM),
      child: GlassContainer(
        borderRadius: 14,
        borderColor: onBg.withValues(alpha: 0.08),
        bgColor: onBg.withValues(alpha: 0.02),
        margin: EdgeInsets.symmetric(horizontal: r.languageCardMargin),
        padding: EdgeInsets.all(r.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(loc.setup.activateCode,
                style: TextStyle(fontSize: r.subtitleSize, fontWeight: FontWeight.w600, color: onBg)),
            SizedBox(height: r.spacingXS),
            Text(loc.setup.enterCode,
                style: TextStyle(fontSize: r.footerSize, color: onBg.withValues(alpha: 0.5))),
            SizedBox(height: r.spacingM),
            _buildField(context),
            SizedBox(height: r.spacingM),
            _buildBtn(context),
            if (state.codeError != null) ...[
              SizedBox(height: r.spacingS),
              _buildError(context),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildField(BuildContext context) {
    return GlassContainer(
      borderRadius: 10,
      borderColor: state.codeError != null
          ? Colors.redAccent.withValues(alpha: 0.4)
          : onBg.withValues(alpha: 0.08),
      bgColor: onBg.withValues(alpha: 0.03),
      child: TextField(
        decoration: InputDecoration(
          hintText: loc.setup.codePlaceholder,
          hintStyle: TextStyle(color: onBg.withValues(alpha: 0.35), fontSize: r.footerSize),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: r.spacingM, vertical: r.spacingS + 2),
          suffixIcon: state.codeValid
              ? Icon(Icons.check_circle, color: glowColor, size: 18)
              : state.codeError != null
                  ? Icon(Icons.cancel, color: Colors.redAccent, size: 18)
                  : null,
        ),
        style: TextStyle(color: onBg, fontSize: r.subtitleSize),
        onChanged: (val) => context.read<SetupBloc>().add(PremiumCodeChanged(val)),
      ),
    );
  }

  Widget _buildError(BuildContext context) {
    return GlassContainer(
      borderRadius: 10,
      borderColor: Colors.redAccent.withValues(alpha: 0.3),
      bgColor: Colors.redAccent.withValues(alpha: 0.06),
      padding: EdgeInsets.symmetric(horizontal: r.spacingM, vertical: r.spacingS),
      child: Row(
        children: [
          Icon(Icons.cancel, color: Colors.redAccent, size: 16),
          SizedBox(width: r.spacingS),
          Expanded(
            child: Text(
              state.codeError!,
              style: TextStyle(color: Colors.redAccent, fontSize: r.footerSize),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBtn(BuildContext context) {
    final hasError = state.codeError != null;
    final enabled = !state.codeValidating && !state.codeValid && state.premiumCode.trim().isNotEmpty;
    return GlassButton(
      label: state.codeValid
          ? loc.setup.codeActivated
          : hasError
              ? loc.setup.retry
              : loc.setup.activate,
      icon: state.codeValid
          ? Icon(Icons.check_circle, size: 16, color: glowColor)
          : hasError
              ? Icon(Icons.refresh, size: 16, color: Colors.redAccent)
              : null,
      onPressed: enabled ? () => context.read<SetupBloc>().add(const ValidatePremiumCode()) : null,
      isLoading: state.codeValidating,
      height: r.continueButtonHeight * 0.85,
      accent: hasError ? Colors.redAccent : glowColor,
    );
  }
}


