import 'package:flutter/material.dart';
import 'package:takamagahara_ui/takamagahara_ui.dart';

/// 認証画面で使う共通フォームフィールド
///
/// ErrorBoundary不要（単一Widget、画面ルートで囲む）。
/// 200行以内厳守。
class AuthFormField extends StatelessWidget {
  final String testId;
  final String label;
  final String? hintText;
  final bool obscureText;
  final TextEditingController? controller;
  final String? Function(String?)? validator;
  final Widget? suffixIcon;

  const AuthFormField({
    super.key,
    required this.testId,
    required this.label,
    this.hintText,
    this.obscureText = false,
    this.controller,
    this.validator,
    this.suffixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return SemanticHelper.textField(
      testId: testId,
      child: TextFormField(
        key: Key(testId),
        controller: controller,
        obscureText: obscureText,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          hintText: hintText,
          suffixIcon: suffixIcon,
        ),
      ),
    );
  }
}
