import 'package:flutter/material.dart';

/// チュートリアル1ページ分のデータ
class TutorialPageData {
  final String keyName;
  final IconData icon;
  final String title;
  final String body;

  Key get pageKey => Key(keyName);

  const TutorialPageData({
    required this.keyName,
    required this.icon,
    required this.title,
    required this.body,
  });
}

/// チュートリアル文言定義
class TutorialContent {
  TutorialContent._();

  // ━━━ 世界観（4ページ） ━━━
  static const List<TutorialPageData> lorePages = [
    TutorialPageData(
      keyName: 'page_tutorial_lore1',
      icon: Icons.auto_stories,
      title: '積読ダンジョンへようこそ',
      body:
          'この世界では「積読」は恥ずかしいものではありません。\n\n'
          '積むほどに力が湧き、読むほどに経験となる——\n'
          '「積読」を「力」に変える、逆転のダンジョンです。',
    ),
    TutorialPageData(
      keyName: 'page_tutorial_lore2',
      icon: Icons.menu_book,
      title: '読書は冒険',
      body:
          '一冊の本を開くことは、未知のダンジョンに足を踏み入れること。\n\n'
          'ページをめくるたびに経験値が溜まり、\n'
          '読み終えた本は「討伐した戦利品」となります。',
    ),
    TutorialPageData(
      keyName: 'page_tutorial_lore3',
      icon: Icons.library_books,
      title: 'ダンジョンは書庫',
      body:
          'あなたの本棚そのものがダンジョンです。\n\n'
          '未読の本は待機中の敵、読みかけは探索中の部屋、\n'
          '読了した本は討伐済みの証。\n'
          'すべてがあなたの成長の糧となります。',
    ),
    TutorialPageData(
      keyName: 'page_tutorial_lore4',
      icon: Icons.emoji_events,
      title: 'さあ、探索の始まりだ',
      body:
          '本を読み、経験を積み、冒険者として成長せよ。\n\n'
          '積読は力なり。\n'
          'あなただけのダンジョン攻略が、今始まります。',
    ),
  ];

  /// 世界観ページ数
  static int get lorePageCount => lorePages.length;

  /// 操作説明ページのデータ
  static const operationPage = TutorialPageData(
    keyName: 'page_tutorial_operation',
    icon: Icons.touch_app,
    title: '操作ガイド',
    body:
        '📚 書庫タブ: 本棚の管理、進捗確認、日替わりクエスト\n\n'
        '🔍 探索タブ: 新たな本の検索・追加（バーコード/手動）\n\n'
        '📊 足跡タブ: 読書履歴、統計、バッジの確認\n\n'
        '👆 画面を左右にスワイプしてタブを切り替え',
  );
}
