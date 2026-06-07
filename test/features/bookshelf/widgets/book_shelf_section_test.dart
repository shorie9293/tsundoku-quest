import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/features/bookshelf/presentation/widgets/book_shelf_section.dart';

Widget createTestWidget({
  required String title,
  required IconData icon,
  required Color iconColor,
  required bool isOpen,
  required VoidCallback onToggle,
  required List<Widget> children,
}) {
  return MaterialApp(
    theme: ThemeData.dark(),
    home: Scaffold(
      body: BookShelfSection(
        title: title,
        icon: icon,
        iconColor: iconColor,
        isOpen: isOpen,
        onToggle: onToggle,
        children: children,
      ),
    ),
  );
}

void main() {
  group('BookShelfSection', () {
    testWidgets('should display title and icon', (tester) async {
      await tester.pumpWidget(createTestWidget(
        title: 'テストセクション',
        icon: Icons.book,
        iconColor: Colors.blue,
        isOpen: false,
        onToggle: () {},
        children: const [Text('child')],
      ));

      expect(find.text('テストセクション'), findsOneWidget);
      expect(find.byIcon(Icons.book), findsOneWidget);
    });

    testWidgets('should show child count badge when children is not empty',
        (tester) async {
      await tester.pumpWidget(createTestWidget(
        title: 'セクション',
        icon: Icons.book,
        iconColor: Colors.blue,
        isOpen: false,
        onToggle: () {},
        children: const [
          Text('child1'),
          Text('child2'),
          Text('child3'),
        ],
      ));

      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('should hide badge when children is empty',
        (tester) async {
      await tester.pumpWidget(createTestWidget(
        title: 'セクション',
        icon: Icons.book,
        iconColor: Colors.blue,
        isOpen: false,
        onToggle: () {},
        children: const [],
      ));

      // Badge text should not appear
      expect(find.text('0'), findsNothing);
    });

    testWidgets('should show arrow rotated when isOpen is true',
        (tester) async {
      await tester.pumpWidget(createTestWidget(
        title: 'セクション',
        icon: Icons.book,
        iconColor: Colors.blue,
        isOpen: true,
        onToggle: () {},
        children: const [Text('child')],
      ));

      final rotation =
          tester.widget<AnimatedRotation>(find.byType(AnimatedRotation));
      expect(rotation.turns, 0.5);
    });

    testWidgets('should call onToggle when tapped', (tester) async {
      bool toggled = false;
      await tester.pumpWidget(createTestWidget(
        title: 'セクション',
        icon: Icons.book,
        iconColor: Colors.blue,
        isOpen: false,
        onToggle: () {
          toggled = true;
        },
        children: const [Text('child')],
      ));

      await tester.tap(find.text('セクション'));
      expect(toggled, isTrue);
    });
  });
}
