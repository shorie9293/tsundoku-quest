import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/core/infrastructure/deep_link_service.dart';

void main() {
  group('DeepLinkService.build', () {
    // ── 正常系 ──

    test('builds cross-reward URI with scheme/host/source/reward', () {
      final uri = DeepLinkService.build(
        source: 'tsundoku-quest',
        reward: 'daily_mission',
      );
      expect(uri.scheme, 'app');
      expect(uri.host, 'cross-reward');
      expect(uri.queryParameters['source'], 'tsundoku-quest');
      expect(uri.queryParameters['reward'], 'daily_mission');
    });

    test('builds URI for different source/reward values', () {
      final uri = DeepLinkService.build(
        source: 'kozuchi',
        reward: 'expenditure_recorded',
      );
      expect(uri.scheme, 'app');
      expect(uri.host, 'cross-reward');
      expect(uri.queryParameters['source'], 'kozuchi');
      expect(uri.queryParameters['reward'], 'expenditure_recorded');
    });

    test('build output round-trips through parse', () {
      final uri = DeepLinkService.build(
        source: 'tsundoku-quest',
        reward: 'daily_mission',
      );
      final parsed = DeepLinkService.parse(uri);
      expect(parsed, isNotNull);
      expect(parsed!.source, 'tsundoku-quest');
      expect(parsed.reward, 'daily_mission');
    });
  });

  group('DeepLinkService.parse', () {
    // ── 正常系 ──

    test('parses source and reward from URL', () {
      final uri = Uri.parse(
        'app://cross-reward?source=tsundoku-quest&reward=daily_mission',
      );
      final parsed = DeepLinkService.parse(uri);
      expect(parsed, isNotNull);
      expect(parsed!.source, 'tsundoku-quest');
      expect(parsed.reward, 'daily_mission');
    });

    test('parses different source and reward values', () {
      final parsed = DeepLinkService.parse(
        Uri.parse('app://cross-reward?source=rpg-task&reward=quest_complete'),
      );
      expect(parsed, isNotNull);
      expect(parsed!.source, 'rpg-task');
      expect(parsed.reward, 'quest_complete');
    });

    test('ignores extra query parameters', () {
      final parsed = DeepLinkService.parse(
        Uri.parse(
          'app://cross-reward?source=tsundoku-quest&reward=daily_mission&ref=notification',
        ),
      );
      expect(parsed, isNotNull);
      expect(parsed!.source, 'tsundoku-quest');
      expect(parsed.reward, 'daily_mission');
    });

    test('handles URL with fragment', () {
      final parsed = DeepLinkService.parse(
        Uri.parse(
          'app://cross-reward?source=tsundoku-quest&reward=daily_mission#grant',
        ),
      );
      expect(parsed, isNotNull);
      expect(parsed!.source, 'tsundoku-quest');
      expect(parsed.reward, 'daily_mission');
    });

    // ── 異常系：異なる scheme ──

    test('returns null for https scheme', () {
      final parsed = DeepLinkService.parse(
        Uri.parse(
          'https://cross-reward?source=tsundoku-quest&reward=daily_mission',
        ),
      );
      expect(parsed, isNull);
    });

    test('returns null for other custom scheme', () {
      final parsed = DeepLinkService.parse(
        Uri.parse(
          'myapp://cross-reward?source=tsundoku-quest&reward=daily_mission',
        ),
      );
      expect(parsed, isNull);
    });

    test('returns null for empty scheme', () {
      final parsed = DeepLinkService.parse(
        Uri.parse('cross-reward?source=tsundoku-quest&reward=daily_mission'),
      );
      expect(parsed, isNull);
    });

    // ── 異常系：異なる host ──

    test('returns null for different host', () {
      final parsed = DeepLinkService.parse(
        Uri.parse('app://weekly-report?source=tsundoku-quest&reward=daily_mission'),
      );
      expect(parsed, isNull);
    });

    test('returns null for empty host', () {
      final parsed = DeepLinkService.parse(
        Uri.parse('app://?source=tsundoku-quest&reward=daily_mission'),
      );
      expect(parsed, isNull);
    });

    // ── 異常系：必須パラメータ欠落 ──

    test('returns null when source parameter is missing', () {
      final parsed = DeepLinkService.parse(
        Uri.parse('app://cross-reward?reward=daily_mission'),
      );
      expect(parsed, isNull);
    });

    test('returns null when reward parameter is missing', () {
      final parsed = DeepLinkService.parse(
        Uri.parse('app://cross-reward?source=tsundoku-quest'),
      );
      expect(parsed, isNull);
    });

    test('returns null when both parameters are missing', () {
      final parsed = DeepLinkService.parse(Uri.parse('app://cross-reward'));
      expect(parsed, isNull);
    });

    test('returns null for completely different URL', () {
      final parsed = DeepLinkService.parse(
        Uri.parse('https://example.com/page'),
      );
      expect(parsed, isNull);
    });
  });

  group('DeepLinkService.isCrossRewardLink', () {
    test('returns true for valid cross-reward link', () {
      expect(
        DeepLinkService.isCrossRewardLink(
          Uri.parse(
            'app://cross-reward?source=tsundoku-quest&reward=daily_mission',
          ),
        ),
        isTrue,
      );
    });

    test('returns false for invalid scheme', () {
      expect(
        DeepLinkService.isCrossRewardLink(
          Uri.parse(
            'https://cross-reward?source=tsundoku-quest&reward=daily_mission',
          ),
        ),
        isFalse,
      );
    });

    test('returns false when parameters are missing', () {
      expect(
        DeepLinkService.isCrossRewardLink(Uri.parse('app://cross-reward')),
        isFalse,
      );
    });

    test('returns false for completely different URL', () {
      expect(
        DeepLinkService.isCrossRewardLink(Uri.parse('https://example.com')),
        isFalse,
      );
    });
  });

  group('DeepLinkService.isAppOpenLink', () {
    test('returns true for app://open', () {
      expect(
        DeepLinkService.isAppOpenLink(Uri.parse('app://open')),
        isTrue,
      );
    });

    test('returns false for cross-reward host', () {
      expect(
        DeepLinkService.isAppOpenLink(
          Uri.parse('app://cross-reward?source=tsundoku-quest&reward=daily_mission'),
        ),
        isFalse,
      );
    });

    test('returns false for non-app scheme', () {
      expect(DeepLinkService.isAppOpenLink(Uri.parse('https://open')), isFalse);
    });

    test('returns false for app scheme with different host', () {
      expect(
        DeepLinkService.isAppOpenLink(Uri.parse('app://weekly-report')),
        isFalse,
      );
    });
  });
}
