import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/domain/repositories/shelf_repository.dart';
import 'package:tsundoku_quest/features/shelves/data/shelf_repository_provider.dart';
import 'package:tsundoku_quest/features/shelves/presentation/shelf_management_screen.dart';

Widget _wrap(ShelfRepository repo) {
  return ProviderScope(
    overrides: [
      shelfRepositoryProvider.overrideWithValue(repo),
    ],
    child: const MaterialApp(home: ShelfManagementScreen()),
  );
}

void main() {
  testWidgets('棚が無いとき空状態を表示する', (tester) async {
    await tester.pumpWidget(_wrap(InMemoryShelfRepository()));
    await tester.pumpAndSettle();
    expect(find.text('自作棚はまだありません'), findsOneWidget);
  });

  testWidgets('＋から棚を作成できる', (tester) async {
    final repo = InMemoryShelfRepository();
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('棚を作る'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '積ん読の山');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(find.text('積ん読の山'), findsOneWidget);
    expect(find.text('0冊'), findsOneWidget);
    expect(await repo.listShelves(), hasLength(1));
  });

  testWidgets('棚のメニューから棚名を変更できる', (tester) async {
    final repo = InMemoryShelfRepository();
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    // 棚を作る
    await tester.tap(find.byTooltip('棚を作る'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '旧名');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(find.text('旧名'), findsOneWidget);

    // メニュー → 棚名を変更
    await tester.tap(find.byTooltip('棚の操作'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('棚名を変更'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '新名');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(find.text('新名'), findsOneWidget);
    expect(find.text('旧名'), findsNothing);
  });
}
