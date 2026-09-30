import 'package:flutter/material.dart';

/// Champ de saisie du design system (label flottant, emoji préfixe).
class EcoTextField extends StatelessWidget {
  const EcoTextField({
    super.key,
    required this.label,
    this.controller,
    this.hint,
    this.emoji,
    this.validator,
    this.keyboardType,
    this.obscure = false,
    this.autofillHints,
    this.textInputAction,
    this.onSubmitted,
    this.onChanged,
    this.maxLength,
    this.enabled = true,
    this.helper,
    this.suffix,
  });

  final String label;
  final TextEditingController? controller;
  final String? hint;
  final String? emoji;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final bool obscure;
  final Iterable<String>? autofillHints;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final int? maxLength;
  final bool enabled;
  final String? helper;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      onChanged: onChanged,
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      obscureText: obscure,
      autofillHints: autofillHints,
      textInputAction: textInputAction ?? TextInputAction.next,
      onFieldSubmitted: onSubmitted,
      maxLength: maxLength,
      enabled: enabled,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: helper,
        helperMaxLines: 2,
        suffixIcon: suffix,
        prefixIcon: emoji == null
            ? null
            : Padding(
                padding: const EdgeInsetsDirectional.only(start: 14, end: 8),
                child: ExcludeSemantics(child: Text(emoji!, style: const TextStyle(fontSize: 18))),
              ),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
      ),
    );
  }
}

/// Champ mot de passe avec bouton afficher / masquer.
class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.label,
    this.controller,
    this.validator,
    this.helper,
    this.newPassword = false,
    this.textInputAction,
    this.onSubmitted,
  });

  final String label;
  final TextEditingController? controller;
  final String? Function(String?)? validator;
  final String? helper;
  final bool newPassword;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _hidden = true;

  @override
  Widget build(BuildContext context) => EcoTextField(
    label: widget.label,
    controller: widget.controller,
    validator: widget.validator,
    helper: widget.helper,
    emoji: '🔒',
    obscure: _hidden,
    textInputAction: widget.textInputAction,
    onSubmitted: widget.onSubmitted,
    autofillHints: [widget.newPassword ? AutofillHints.newPassword : AutofillHints.password],
    suffix: IconButton(
      tooltip: _hidden ? 'Afficher' : 'Masquer',
      icon: Icon(_hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined),
      onPressed: () => setState(() => _hidden = !_hidden),
    ),
  );
}
