import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/features/about/domain/about_info.dart';

void main() {
  group('AboutInfo 不変条件', () {
    test('全フィールドが空文字のとき ArgumentError', () {
      expect(
        () => AboutInfo(
          appName: '',
          version: '1.0.0',
          contactEmail: 'a@b.c',
          privacyPolicyUrl: 'https://example.com',
          tagline: 't',
        ),
        throwsArgumentError,
      );
      expect(
        () => AboutInfo(
          appName: 'x',
          version: '',
          contactEmail: 'a@b.c',
          privacyPolicyUrl: 'https://example.com',
          tagline: 't',
        ),
        throwsArgumentError,
      );
      expect(
        () => AboutInfo(
          appName: 'x',
          version: '1.0.0',
          contactEmail: '',
          privacyPolicyUrl: 'https://example.com',
          tagline: 't',
        ),
        throwsArgumentError,
      );
      expect(
        () => AboutInfo(
          appName: 'x',
          version: '1.0.0',
          contactEmail: 'a@b.c',
          privacyPolicyUrl: '',
          tagline: 't',
        ),
        throwsArgumentError,
      );
      expect(
        () => AboutInfo(
          appName: 'x',
          version: '1.0.0',
          contactEmail: 'a@b.c',
          privacyPolicyUrl: 'https://example.com',
          tagline: '',
        ),
        throwsArgumentError,
      );
    });

    test('全フィールドが非空なら生成できる', () {
      final info = AboutInfo(
        appName: 'x',
        version: '1.0.0',
        contactEmail: 'a@b.c',
        privacyPolicyUrl: 'https://example.com',
        tagline: 't',
      );
      expect(info.appName, 'x');
      expect(info.version, '1.0.0');
    });
  });

  group('kAboutInfo 既定値', () {
    test('appName / contactEmail / privacyPolicyUrl が正しい', () {
      expect(kAboutInfo.appName, '積ん読クエスト');
      expect(kAboutInfo.contactEmail, 'horie.shunta@gmail.com');
      expect(kAboutInfo.privacyPolicyUrl, 'https://www.yoppala.in/privacy');
    });

    test('version は 1.1.21（pubspec 同期試練が真値を担保）', () {
      expect(kAboutInfo.version, '1.1.21');
      expect(kAboutInfo.version, isNotEmpty);
    });
  });
}
