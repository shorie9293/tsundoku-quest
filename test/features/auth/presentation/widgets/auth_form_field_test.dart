import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/features/auth/presentation/widgets/auth_form_field.dart';

void main() {
  group('AuthFormField', () {
    testWidgets('ラベルとヒントが表示される', (tester) async {
      const testId = 'test_field';
      const label = 'メールアドレス';
      const hint = 'example@email.com';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AuthFormField(
              testId: testId,
              label: label,
              hintText: hint,
            ),
          ),
        ),
      );

      expect(find.text(label), findsOneWidget);
      expect(find.text(hint), findsOneWidget);
    });

    testWidgets('obscureText=trueでパスワード表示', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AuthFormField(
              testId: 'password',
              label: 'パスワード',
              obscureText: true,
            ),
          ),
        ),
      );

      final editableText = tester.widget<EditableText>(find.byType(EditableText));
      expect(editableText.obscureText, isTrue);
    });

    testWidgets('obscureText=false（デフォルト）で平文表示', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AuthFormField(
              testId: 'email',
              label: 'メール',
            ),
          ),
        ),
      );

      final editableText = tester.widget<EditableText>(find.byType(EditableText));
      expect(editableText.obscureText, false);
    });

    testWidgets('コントローラが接続される', (tester) async {
      final controller = TextEditingController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AuthFormField(
              testId: 'email',
              label: 'メール',
              controller: controller,
            ),
          ),
        ),
      );

      // コントローラ経由で入力
      controller.text = 'test@example.com';
      await tester.pump();

      final textField = tester.widget<TextFormField>(find.byType(TextFormField));
      expect(textField.controller?.text, 'test@example.com');
    });

    testWidgets('バリデーターが適用される', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Form(
              child: AuthFormField(
                testId: 'email',
                label: 'メール',
                validator: (value) {
                  if (value == null || value.isEmpty) return '必須項目です';
                  return null;
                },
              ),
            ),
          ),
        ),
      );

      final formState = tester.state<FormState>(find.byType(Form));
      expect(formState.validate(), isFalse);
    });

    testWidgets('suffixIconが表示される', (tester) async {
      const icon = Icon(Icons.visibility, key: Key('suffix_icon'));

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AuthFormField(
              testId: 'password',
              label: 'パスワード',
              suffixIcon: icon,
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('suffix_icon')), findsOneWidget);
    });

    testWidgets('Semanticsが適用されている（testId経由でKey付与）', (tester) async {
      const testId = 'test_field';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AuthFormField(
              testId: testId,
              label: 'メール',
            ),
          ),
        ),
      );

      // testId がKeyとして使われている
      expect(find.byKey(const Key('test_field')), findsOneWidget);
      // TextFormFieldが存在する
      expect(find.byType(TextFormField), findsOneWidget);
    });
  });
}
