import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tsundoku_quest/core/testing/widget_keys.dart';
import 'package:tsundoku_quest/features/settings/presentation/settings_hub_screen.dart';

/// 設定ハブへの退会導線 — ビルダー未注入なら項目を出さない（後方互換）。
void main() {
  testWidgets('accountDeletionBuilder 未注入なら退会項目は表示されない', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SettingsHubScreen()));
    await tester.pumpAndSettle();

    expect(find.text('アカウント削除（退会）'), findsNothing);
    expect(find.byKey(AppKeys.settingsHubItem('account_deletion')), findsNothing);
    expect(find.byType(ListTile), findsNWidgets(9));
  });

  testWidgets('accountDeletionBuilder 注入で退会項目が表示される', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SettingsHubScreen(
          accountDeletionBuilder: (_) => const Scaffold(
            body: Center(child: Text('FAKE:account_deletion')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('アカウント削除（退会）'), findsOneWidget);
    expect(find.byType(ListTile), findsNWidgets(10));

    await tester.tap(find.byKey(AppKeys.settingsHubItem('account_deletion')));
    await tester.pumpAndSettle();

    expect(find.text('FAKE:account_deletion'), findsOneWidget);
  });
}
