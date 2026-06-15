import 'package:flutter/material.dart';

class SetupInputField extends StatefulWidget {
  final IconData icon;
  final String hint;
  final bool obscureText;
  final ValueChanged<String> onSubmitted;

  const SetupInputField({
    super.key,
    required this.icon,
    required this.hint,
    this.obscureText = false,
    required this.onSubmitted,
  });

  @override
  State<SetupInputField> createState() => _SetupInputFieldState();
}

class _SetupInputFieldState extends State<SetupInputField> {
  final _controller = TextEditingController();
  bool _obscured = false;

  @override
  void initState() {
    super.initState();
    _obscured = widget.obscureText;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      obscureText: _obscured,
      style: const TextStyle(color: Colors.white, fontSize: 16),
      decoration: InputDecoration(
        prefixIcon: Icon(widget.icon, color: const Color(0xFF1DB954)),
        hintText: widget.hint,
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
        filled: true,
        fillColor: const Color(0xFF1E1E1E),
        suffixIcon: widget.obscureText
            ? IconButton(
                icon: Icon(
                  _obscured ? Icons.visibility_off : Icons.visibility,
                  color: Colors.white54,
                ),
                onPressed: () => setState(() => _obscured = !_obscured),
              )
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF1DB954)),
        ),
      ),
      onSubmitted: widget.onSubmitted,
    );
  }
}
