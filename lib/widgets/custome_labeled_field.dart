import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CustomLabeledTextField extends StatelessWidget {
  final String label;
  final String hintText;
  final IconData prefixIcon;
  final TextEditingController controller;
  final String? Function(String?)? validator;
  final void Function()? onObscureTap;
  final bool isPassword;
  final bool isObscure;
  final TextInputType? keyboardType;
  final int? maxLength;

  // NEW
  final ValueChanged<bool>? onFocusChange;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;
  final List<TextInputFormatter>? inputFormatters;
  final bool enabled;
  final TextInputAction? textInputAction;

  const CustomLabeledTextField({
    super.key,
    required this.label,
    required this.hintText,
    required this.prefixIcon,
    required this.controller,
    this.validator,
    this.isPassword = false,
    this.isObscure = false,
    this.onObscureTap,
    this.keyboardType,
    this.maxLength,
    this.onFocusChange,
    this.onChanged,
    this.onFieldSubmitted,
    this.inputFormatters,
    this.enabled = true,
    this.textInputAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),

        // Field with focus listener
        Focus(
          onFocusChange: onFocusChange,
          child: TextFormField(
            controller: controller,
            validator: validator,
            keyboardType: keyboardType,
            maxLength: maxLength,
            onChanged: onChanged,
            onFieldSubmitted: onFieldSubmitted,
            inputFormatters: inputFormatters,
            enabled: enabled,
            textInputAction: textInputAction,
            obscureText: isPassword ? isObscure : false,
            obscuringCharacter: '•',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurface,
            ),
            decoration: InputDecoration(
              counterText: "",

              filled: true,
              fillColor: theme.colorScheme.surface,

              hintText: hintText,
              hintStyle: TextStyle(
                color: theme.colorScheme.onSurface.withOpacity(0.55),
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),

              prefixIcon: Padding(
                padding: const EdgeInsets.only(left: 16.0, right: 8.0),
                child: Icon(
                  prefixIcon,
                  color: theme.colorScheme.onSurface.withOpacity(0.8),
                  size: 22,
                ),
              ),
              prefixIconConstraints: const BoxConstraints(
                minWidth: 48,
                minHeight: 48,
              ),

              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 16,
              ),

              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
              ),

              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: BorderSide(
                  color: theme.colorScheme.primary,
                  width: 1.5,
                ),
              ),

              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: const BorderSide(color: Colors.red, width: 1.5),
              ),

              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: const BorderSide(color: Colors.red, width: 1.5),
              ),

              suffixIcon: isPassword
                  ? IconButton(
                      onPressed: onObscureTap,
                      icon: Icon(
                        isObscure
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                        color: theme.colorScheme.onSurface.withOpacity(0.8),
                      ),
                    )
                  : null,
            ),
          ),
        ),
      ],
    );
  }
}
