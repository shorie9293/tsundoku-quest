/// アプリについて画面に表示する情報の不変（Immutable）値オブジェクト。
///
/// 不変条件：全フィールドが非空であること。
/// Dart の const コンストラクタは本体を持てないため、
/// 検証つきの非constコンストラクタ（[AboutInfo.new]）と、
/// 既定値用の const 内部コンストラクタ（[AboutInfo.constValid]）を分離する。
/// バージョン ドリフトは test/features/about/about_version_sync_test.dart が担保する。
class AboutInfo {
  /// アプリ表示名。
  final String appName;

  /// セマンティックバージョン（例: 1.1.16）。ビルド番号は含まない。
  final String version;

  /// 問い合わせ先メールアドレス。
  final String contactEmail;

  /// プライバシーポリシーの URL。
  final String privacyPolicyUrl;

  /// アプリの一言紹介文。
  final String tagline;

  /// 非constコンストラクタ本体で不変条件を検証する（空文字禁止 → ArgumentError）。
  AboutInfo({
    required this.appName,
    required this.version,
    required this.contactEmail,
    required this.privacyPolicyUrl,
    required this.tagline,
  }) {
    if (appName.isEmpty) {
      throw ArgumentError.value(appName, 'appName', '空文字は禁止');
    }
    if (version.isEmpty) {
      throw ArgumentError.value(version, 'version', '空文字は禁止');
    }
    if (contactEmail.isEmpty) {
      throw ArgumentError.value(contactEmail, 'contactEmail', '空文字は禁止');
    }
    if (privacyPolicyUrl.isEmpty) {
      throw ArgumentError.value(privacyPolicyUrl, 'privacyPolicyUrl', '空文字は禁止');
    }
    if (tagline.isEmpty) {
      throw ArgumentError.value(tagline, 'tagline', '空文字は禁止');
    }
  }

  /// const 既定値専用の内部コンストラクタ。
  /// const 式の中でも検証相当の担保として assert を併設する。
  const AboutInfo.constValid({
    required this.appName,
    required this.version,
    required this.contactEmail,
    required this.privacyPolicyUrl,
    required this.tagline,
  })  : assert(appName != ''),
        assert(version != ''),
        assert(contactEmail != ''),
        assert(privacyPolicyUrl != ''),
        assert(tagline != '');
}

/// 既定のアプリ情報。
///
/// version は pubspec.yaml と同期して維持すること（試練で担保）。
const kAboutInfo = AboutInfo.constValid(
  appName: '積ん読クエスト',
  version: '1.1.19',
  contactEmail: 'horie.shunta@gmail.com',
  privacyPolicyUrl: 'https://yoppala.in/privacy',
  tagline: '積ん読を冒険に変える読書アプリ',
);
