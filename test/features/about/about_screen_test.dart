import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/features/about/domain/about_info.dart';
import 'package:tsundoku_quest/features/about/presentation/about_app_keys.dart';
import 'package:tsundoku_quest/features/about/presentation/about_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // Clipboard のプラットフォームチャネルをモック（未モックだと
    // invokeMethod が fake async 外で例外化し SnackBar が映らない）
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (message) async {
      return null;
    });
  });

  const info = const AboutInfo.constValid(
    appName: '積ん読クエスト',
    version: '9.9.9',
    contactEmail: 'test@example.com',
    privacyPolicyUrl: 'https://example.com/privacy',
    tagline: '試練用タグライン',
  );

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(home: AboutScreen(info: info)),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('注入した info のアプリ名とバージョンを表示する', (tester) async {
    await pumpScreen(tester);

    expect(find.byKey(AboutAppKeys.aboutScreen), findsOneWidget);
    expect(find.text('積ん読クエスト'), findsOneWidget);
    expect(find.byKey(AboutAppKeys.versionLabel), findsOneWidget);
    expect(find.text('v9.9.9'), findsOneWidget);
  });

  testWidgets('ライセンスタイルをタップすると LicensePage が push される', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.byKey(AboutAppKeys.licenseTile));
    await tester.pumpAndSettle();

    expect(find.byType(LicensePage), findsOneWidget);
  });

  testWidgets('プライバシータイルでダイアログに URL が表示される', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.byKey(AboutAppKeys.privacyTile));
    await tester.pumpAndSettle();

    expect(find.text('https://example.com/privacy'), findsOneWidget);
    expect(find.byKey(AboutAppKeys.copyButton), findsOneWidget);
  });

  testWidgets('プライバシーダイアログでコピーすると SnackBar が出る', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.byKey(AboutAppKeys.privacyTile));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(AboutAppKeys.copyButton));
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('コピーしました'), findsOneWidget);
  });

  testWidgets('問い合わせタイルでメールアドレスが表示されコピーできる', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.byKey(AboutAppKeys.contactTile));
    await tester.pumpAndSettle();

    expect(find.text('test@example.com'), findsOneWidget);
    expect(find.byKey(AboutAppKeys.copyButton), findsOneWidget);

    await tester.tap(find.byKey(AboutAppKeys.copyButton));
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsOneWidget);
  });
}
