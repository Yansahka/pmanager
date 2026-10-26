import 'package:flutter/material.dart';

import '../app.dart';

class Brand extends StatelessWidget {
  const Brand({super.key});
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: ink,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.key_rounded, color: accent, size: 26),
      ),
      const SizedBox(width: 12),
      const Text(
        'sésame',
        style: TextStyle(
          color: ink,
          fontSize: 28,
          fontWeight: FontWeight.w800,
          letterSpacing: -1.3,
        ),
      ),
    ],
  );
}

class SecretField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final bool autofocus;
  final ValueChanged<String>? onSubmitted;
  const SecretField({
    super.key,
    required this.controller,
    required this.label,
    this.autofocus = false,
    this.onSubmitted,
  });
  @override
  State<SecretField> createState() => _SecretFieldState();
}

class _SecretFieldState extends State<SecretField> {
  bool hidden = true;
  @override
  Widget build(BuildContext context) => TextField(
    controller: widget.controller,
    autofocus: widget.autofocus,
    obscureText: hidden,
    autocorrect: false,
    enableSuggestions: false,
    enableIMEPersonalizedLearning: false,
    enableInteractiveSelection: false,
    maxLength: 256,
    onSubmitted: widget.onSubmitted,
    decoration: InputDecoration(
      labelText: widget.label,
      counterText: '',
      suffixIcon: IconButton(
        tooltip: hidden ? 'Afficher' : 'Masquer',
        onPressed: () => setState(() => hidden = !hidden),
        icon: Icon(
          hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        ),
      ),
    ),
  );
}

class Notice extends StatelessWidget {
  final String text;
  final bool error;
  const Notice(this.text, {super.key, this.error = false});
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    margin: const EdgeInsets.symmetric(vertical: 12),
    decoration: BoxDecoration(
      color: error ? const Color(0xFFFFEAE4) : const Color(0xFFE8EFDF),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Text(
      text,
      style: TextStyle(
        color: error ? const Color(0xFF9D3529) : ink,
        height: 1.5,
      ),
    ),
  );
}

void message(BuildContext context, String text) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}
