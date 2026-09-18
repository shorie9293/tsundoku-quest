import 'package:flutter/material.dart';
import 'package:tsundoku_quest/core/testing/widget_keys.dart';
import 'package:tsundoku_quest/core/theme/app_theme.dart';
import 'package:tsundoku_quest/features/history/data/reading_forecast_service.dart';

/// 読了予測カード — 進行中の本の読了予定日とペースを表示する。
///
/// 予測不能（ペース不明・総ページ不明）でも、判明している情報だけを
/// 折りたたまずに表示する（ペースのみ / 総ページのみ 等）。
class ReadingForecastCard extends StatelessWidget {
  final ReadingForecast forecast;

  const ReadingForecastCard({super.key, required this.forecast});

  @override
  Widget build(BuildContext context) {
    final label = forecast.forecastLabel;
    final pace = forecast.paceLabel;

    return Container(
      key: AppKeys.readingForecastCard,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.progress.withAlpha(15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppTheme.progress.withAlpha(40),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          const Text('🎯', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label ?? _unknownLabel(),
                  key: AppKeys.readingForecastLabel,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                if (pace != null)
                  Text(
                    pace,
                    key: AppKeys.readingForecastPace,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _unknownLabel() {
    if (forecast.isDone) return '読了済み';
    if (forecast.totalPages == null) {
      return '総ページ数が不明のため読了日は未予測';
    }
    return '読書ペースがつかめないため読了日は未予測';
  }
}
