import 'package:flutter/material.dart';

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

  CustomLabeledTextField({
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
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. External Label
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),

        // 2. The Styled Text Field
        TextFormField(
          controller: controller,
          validator: validator,
          keyboardType: keyboardType,
          maxLength: maxLength,
          decoration: InputDecoration(
            // Fill background
            filled: true,
            fillColor: Theme.of(context).colorScheme.surface,

            // Hint text styling
            hintText: hintText,
            hintStyle: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),

            // Prefix Icon styling
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 16.0, right: 8.0),
              child: Icon(
                prefixIcon,
                color: Theme.of(context).colorScheme.onSurface,
                size: 22,
              ),
            ),

            // Internal padding to make it spacious and perfectly centered
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 16,
            ),

            // 3. Unselected Border State
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(
                30.0,
              ), // Fully rounded pill shape
              borderSide: BorderSide(color: Colors.grey.shade300, width: 1.0),
            ),

            // 4. Active/Focused Border State
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30.0),
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.primary,
                width: 1.5,
              ),
            ),

            // Error border state
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30.0),
              borderSide: BorderSide(color: Colors.red, width: 1.5),
            ),

            // Focused error border state
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30.0),
              borderSide: BorderSide(color: Colors.red, width: 1.5),
            ),

            suffixIcon: isPassword
                ? IconButton(
                    icon: Icon(
                      isObscure ? Icons.visibility : Icons.visibility_off,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    onPressed: onObscureTap,
                  )
                : null,
          ),

          obscureText: isPassword ? isObscure : false,
        ),
      ],
    );
  }
}
