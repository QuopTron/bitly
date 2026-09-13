part of 'settings_sheet_new.dart';

class _PremiumCodeForm extends StatelessWidget {
  final TextEditingController controller;
  final bool sending;
  final bool activated;
  final String? errorMsg;
  final Color glowColor;
  final Color onBg;
  final Responsive r;
  final VoidCallback onActivate;

  const _PremiumCodeForm({
    required this.controller,
    required this.sending,
    required this.activated,
    required this.errorMsg,
    required this.glowColor,
    required this.onBg,
    required this.r,
    required this.onActivate,
  });

  @override
  Widget build(BuildContext context) {
    final glow = glowColor;

    return Column(
      children: [
        // Code input
        Padding(
          padding: EdgeInsets.symmetric(horizontal: r.spacingXL),
          child: TextField(
            controller: controller,
            autofocus: true,
            style: TextStyle(color: onBg, fontSize: 16, letterSpacing: 2),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              hintText: 'XXXX-XXXX-XXXX',
              hintStyle: TextStyle(
                color: onBg.withValues(alpha: 0.25),
                letterSpacing: 3,
              ),
              filled: true,
              fillColor: onBg.withValues(alpha: 0.04),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: onBg.withValues(alpha: 0.15)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: onBg.withValues(alpha: 0.15)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: glow, width: 1.6),
              ),
            ),
          ),
        ),
        if (errorMsg != null) ...[
          SizedBox(height: r.spacingS),
          Text(
            errorMsg!,
            style: TextStyle(color: Colors.redAccent, fontSize: r.footerSize),
          ),
        ],
        SizedBox(height: r.spacingL),
        // Activate button
        Padding(
          padding: EdgeInsets.symmetric(horizontal: r.spacingXL),
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: sending || activated ? null : onActivate,
              style: ElevatedButton.styleFrom(
                backgroundColor: activated ? Colors.green : glow,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child:
                  activated
                      ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_rounded, size: 22),
                          SizedBox(width: 8),
                          Text(
                            'Premium activado',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      )
                      : sending
                      ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                      : Text(
                        'Activar',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
            ),
          ),
        ),
      ],
    );
  }
}
