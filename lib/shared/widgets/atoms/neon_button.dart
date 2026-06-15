import 'package:flutter/material.dart';

class NeonButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final double width;
  final double height;
  final bool loading;

  const NeonButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.width = double.infinity,
    this.height = 50,
    this.loading = false,
  });

  @override
  State<NeonButton> createState() => _NeonButtonState();
}

class _NeonButtonState extends State<NeonButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.loading ? null : widget.onPressed,
          onHover: (v) => setState(() => _hovered = v),
          borderRadius: BorderRadius.circular(25),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(25),
              gradient: const LinearGradient(
                colors: [Color(0xFF00E676), Color(0xFF00C853)],
              ),
              boxShadow: _hovered
                  ? [BoxShadow(
                      color: Colors.green.withValues(alpha: 0.6),
                      blurRadius: 15,
                      spreadRadius: 2,
                    )]
                  : [BoxShadow(
                      color: Colors.green.withValues(alpha: 0.3),
                      blurRadius: 8,
                    )],
            ),
            child: Center(
              child: widget.loading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.icon != null) ...[
                          Icon(widget.icon, color: Colors.white, size: 20),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          widget.label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
