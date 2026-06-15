import 'package:flutter/material.dart';
import 'base_bottom_sheet.dart';

class InputSheet extends StatefulWidget {
  final String title;
  final String? hintText;
  final String? initialValue;
  final String confirmLabel;
  final void Function(String value)? onConfirm;
  final bool obscureText;

  const InputSheet({
    super.key,
    required this.title,
    this.hintText,
    this.initialValue,
    this.confirmLabel = 'Confirm',
    this.onConfirm,
    this.obscureText = false,
  });

  static Future<String?> show(
    BuildContext context, {
    required String title,
    String? hintText,
    String? initialValue,
    String confirmLabel = 'Confirm',
    bool obscureText = false,
  }) {
    return BaseBottomSheet.show<String>(
      context,
      child: InputSheet(
        title: title,
        hintText: hintText,
        initialValue: initialValue,
        confirmLabel: confirmLabel,
        obscureText: obscureText,
      ),
    );
  }

  @override
  State<InputSheet> createState() => _InputSheetState();
}

class _InputSheetState extends State<InputSheet> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(widget.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 16),
        TextField(
          controller: _controller,
          obscureText: widget.obscureText,
          decoration: InputDecoration(
            hintText: widget.hintText,
            filled: true,
            fillColor: Colors.grey.withValues(alpha: 0.1),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: () {
              widget.onConfirm?.call(_controller.text);
              Navigator.pop(context, _controller.text);
            },
            child: Text(widget.confirmLabel),
          ),
        ),
      ],
    );
  }
}
