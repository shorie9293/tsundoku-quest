import 'package:flutter/material.dart';

/// 全画面の試練用Keyを一括管理
///
/// 使い方:
///   試練側: find.byKey(AppKeys.bookshelfScreen)
///   コード側: Scaffold(key: AppKeys.bookshelfScreen, ...)
class AppKeys {
  AppKeys._();

  // ━━━ 書庫（ホーム） ━━━
  static const Key bookshelfScreen = Key('screen_bookshelf');
  static const Key adventurerHeader = Key('header_adventurer');
  static const Key dungeonSummary = Key('section_dungeon_summary');
  static const Key xpBar = Key('bar_xp');
  static const Key streakDisplay = Key('txt_streak');
  static const Key dailyQuest = Key('section_daily_quest');
  static const Key bookShelfSection = Key('section_book_shelf');
  static const Key bookCard = Key('card_book');
  static const Key bookCardCover = Key('img_book_cover');
  static const Key bookCardTitle = Key('txt_book_title');
  static const Key bookCardProgress = Key('bar_book_progress');
  static const Key bookEditModal = Key('dlg_edit_book');

  // ━━━ 探索（本の登録） ━━━
  static const Key exploreScreen = Key('screen_explore');
  static const Key searchTab = Key('tab_search');
  static const Key scanTab = Key('tab_scan');
  static const Key manualTab = Key('tab_manual');
  static const Key searchField = Key('txt_search_query');
  static const Key searchButton = Key('btn_search');
  static const Key searchResultsList = Key('list_search_results');
  static const Key searchResultItem = Key('item_search_result');
  static const Key scanPreview = Key('view_scan_preview');
  static const Key scanFrame = Key('view_scan_frame');
  static const Key manualTitleField = Key('txt_manual_title');
  static const Key manualAuthorField = Key('txt_manual_author');
  static const Key manualIsbnField = Key('txt_manual_isbn');
  static const Key manualSubmit = Key('btn_manual_submit');

  // ━━━ 読書中 ━━━
  static const Key readingScreen = Key('screen_reading');
  static const Key readingCover = Key('img_reading_cover');
  static const Key readingTitle = Key('txt_reading_title');
  static const Key readingTimer = Key('widget_reading_timer');
  static const Key readingProgress = Key('bar_reading_progress');
  static const Key readingPageInput = Key('txt_current_page');
  static const Key readingMemo = Key('txt_reading_memo');
  static const Key readingComplete = Key('btn_complete_reading');
  static const Key completeModal = Key('dlg_complete_reading');
  static const Key trophyLearning1 = Key('txt_trophy_learning_1');
  static const Key trophyLearning2 = Key('txt_trophy_learning_2');
  static const Key trophyLearning3 = Key('txt_trophy_learning_3');
  static const Key trophyAction = Key('txt_trophy_action');
  static const Key trophyQuote = Key('txt_trophy_quote');
  static const Key trophySubmit = Key('btn_trophy_submit');

  // ━━━ 足跡（統計） ━━━
  static const Key historyScreen = Key('screen_history');
  static const Key monthlyStatsGrid = Key('grid_monthly_stats');
  static const Key readingCalendar = Key('widget_reading_calendar');
  static const Key genreDistribution = Key('section_genre_distribution');
  static const Key badgeCollection = Key('section_badge_collection');

  // ━━━ メインタブバー ━━━
  static const Key mainTabBar = Key('tab_main');
  static const Key tabBookshelf = Key('tab_bookshelf');
  static const Key tabExplore = Key('tab_explore');
  static const Key tabReading = Key('tab_reading');
  static const Key tabHistory = Key('tab_history');

  // ━━━ 認証（Auth Feature） ━━━
  static const Key authScreen = Key('screen_auth');
  static const Key authGuestButton = Key('btn_auth_guest');
  static const Key authLoginButton = Key('btn_auth_login');
  static const Key authSignupButton = Key('btn_auth_signup');
  static const Key authEmailField = Key('txt_auth_email');
  static const Key authPasswordField = Key('txt_auth_password');
  static const Key authConfirmPasswordField = Key('txt_auth_confirm_password');
  static const Key authSubmitButton = Key('btn_auth_submit');
  static const Key authErrorText = Key('txt_auth_error');
  static const Key authBackButton = Key('btn_auth_back');

  // ━━━ 今日のおすすめ ━━━
  static const Key recommendationSection = Key('section_recommendation');
  static const Key recommendationCard = Key('card_recommendation');
  static const Key recommendationTitle = Key('txt_recommendation_title');
  static const Key recommendationAuthor = Key('txt_recommendation_author');
  static const Key recommendationReason = Key('txt_recommendation_reason');
  static const Key recommendationButton = Key('btn_recommendation_start');

  // ━━━ おすすめ画面（Phase 4） ━━━
  static const Key recommendationScreen = Key('screen_recommendation');
  static const Key recommendationList = Key('list_recommendation');
  static const Key socialReadingSection = Key('section_social_reading');

  // ━━━ 汎用 ━━━
  static const Key backButton = Key('btn_back');
  static const Key closeButton = Key('btn_close');
  static const Key confirmDialog = Key('dlg_confirm');
  static const Key errorBoundary = Key('widget_error_boundary');
}
