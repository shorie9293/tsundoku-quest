/// バックアップに載せる設定の許可リスト／純粋変換
///
/// 主題: 自動バックアップの控え（JSON）に「設定」を載せ、復元で戻せるようにする。
///
/// 設計の掟:
/// - **許可リスト方式**。プレフィックス一括取得（`tsundoku_*` を丸ごと）は禁止。
///   新しい設定を控えに載せたい時は [kBackupSettingSpecs] に1行足す。
/// - `isSecret` のキー（app_lock・トークン・Supabase セッション）は
///   [selectForBackup] が**必ず**落とす。復元経路でも同じ関門を通す。
/// - 破損 JSON は絶対に throw しない（null / 空に落とす）。
///   Flutter にも Hive にも SharedPreferences にも依存しない純粋層。
library;

/// 設定の分類（UI で「設定」と「チュートリアル既読」を分けられるようにする）
enum BackupSettingCategory {
  /// アプリ設定（テーマ・文字サイズ・静穏時間・リマインダー等）
  settings,

  /// チュートリアル／物語の既読状態
  tutorial,
}

/// 控えに載せる1設定の定義
class BackupSettingSpec {
  /// 保存キー（SharedPreferences のキー、または Hive の論理キー）
  final String key;

  /// 分類
  final BackupSettingCategory category;

  /// 利用者向けの短い名前（UI 説明用）
  final String label;

  /// 秘密か。true のキーは控えにも復元にも通さない。
  final bool isSecret;

  const BackupSettingSpec({
    required this.key,
    required this.category,
    required this.label,
    this.isSecret = false,
  });
}

/// 値1件の上限（控えの肥大・異常入力を防ぐ）。超えた値は載せない。
const int kMaxBackupSettingValueLength = 4096;

/// 控えに載せてよい設定の許可リスト（順序は表示順を兼ねる）
///
/// 追加時は「復元側の書き込み先」（[BackupSettingsStore] 実装）も
/// 併せて対応させること。未対応キーは復元時に個別スキップされる。
const List<BackupSettingSpec> kBackupSettingSpecs = <BackupSettingSpec>[
  BackupSettingSpec(
    key: 'tsundoku_theme_mode',
    category: BackupSettingCategory.settings,
    label: 'テーマ',
  ),
  BackupSettingSpec(
    key: 'tsundoku_text_scale',
    category: BackupSettingCategory.settings,
    label: '文字サイズ',
  ),
  BackupSettingSpec(
    key: 'tsundoku_reduce_motion',
    category: BackupSettingCategory.settings,
    label: '動きを減らす',
  ),
  BackupSettingSpec(
    key: 'quiet_hours_settings',
    category: BackupSettingCategory.settings,
    label: '静穏時間（おやすみモード）',
  ),
  BackupSettingSpec(
    key: 'reminder_settings',
    category: BackupSettingCategory.settings,
    label: '読書リマインダー',
  ),
  BackupSettingSpec(
    key: 'tutorial_lore_seen',
    category: BackupSettingCategory.tutorial,
    label: '物語の導入既読',
  ),
  BackupSettingSpec(
    key: 'tutorial_operation_seen',
    category: BackupSettingCategory.tutorial,
    label: '操作チュートリアル既読',
  ),
  // ── 秘密（控えにも復元にも通さない）──────────────────────────
  // 端末固有のロック状態・ハッシュは機種変更で持ち越すべきではない
  // （持ち越すと新しい端末でロックアウトし得る）。
  BackupSettingSpec(
    key: 'app_lock.enabled',
    category: BackupSettingCategory.settings,
    label: 'アプリロック有効',
    isSecret: true,
  ),
  BackupSettingSpec(
    key: 'app_lock.passcode_hash',
    category: BackupSettingCategory.settings,
    label: 'アプリロックのパスコード',
    isSecret: true,
  ),
  BackupSettingSpec(
    key: 'app_lock.method',
    category: BackupSettingCategory.settings,
    label: 'アプリロック方式',
    isSecret: true,
  ),
  BackupSettingSpec(
    key: 'app_lock.relock_grace_seconds',
    category: BackupSettingCategory.settings,
    label: '再ロック猶予',
    isSecret: true,
  ),
  BackupSettingSpec(
    key: 'app_lock.failed_attempts',
    category: BackupSettingCategory.settings,
    label: 'アプリロック失敗回数',
    isSecret: true,
  ),
  BackupSettingSpec(
    key: 'app_lock.locked_until',
    category: BackupSettingCategory.settings,
    label: 'アプリロック解除時刻',
    isSecret: true,
  ),
  // 認証系（トークン・Supabase セッション）は絶対に控えへ載せない。
  BackupSettingSpec(
    key: 'supabase.auth.token',
    category: BackupSettingCategory.settings,
    label: 'Supabase セッション',
    isSecret: true,
  ),
  BackupSettingSpec(
    key: 'auth.access_token',
    category: BackupSettingCategory.settings,
    label: 'アクセストークン',
    isSecret: true,
  ),
  BackupSettingSpec(
    key: 'auth.refresh_token',
    category: BackupSettingCategory.settings,
    label: 'リフレッシュトークン',
    isSecret: true,
  ),
];

/// 秘密キーの一覧（試練・監査用）
List<String> get secretKeys => <String>[
      for (final spec in kBackupSettingSpecs)
        if (spec.isSecret) spec.key,
    ];

/// キーに対応する定義（無ければ null）
BackupSettingSpec? backupSettingSpecFor(String key) {
  for (final spec in kBackupSettingSpecs) {
    if (spec.key == key) return spec;
  }
  return null;
}

/// 生の設定マップから「控えに載せてよい分」だけを抜き出す。
///
/// - 許可リストのキーのみ通す（プレフィックス一括はしない）
/// - [secretKeys] は必ず落とす
/// - JSON スカラー以外（Map/List）と巨大文字列は落とす
/// - 入力がどれだけ巨大でも throw しない
Map<String, Object?> selectForBackup(Map<String, Object?> raw) {
  final out = <String, Object?>{};
  for (final spec in kBackupSettingSpecs) {
    if (spec.isSecret) continue; // 秘密は絶対に通さない
    if (!raw.containsKey(spec.key)) continue;
    final value = raw[spec.key];
    if (!_isJsonScalar(value)) continue;
    if (value is String && value.length > kMaxBackupSettingValueLength) {
      continue;
    }
    out[spec.key] = value;
  }
  return out;
}

/// [key] の値が期待する型か（純粋判定。意味的な妥当性は保存先が判定する）。
bool isAcceptableSettingValue(String key, Object? value) {
  final spec = backupSettingSpecFor(key);
  if (spec == null || spec.isSecret) return false;
  switch (key) {
    case 'tsundoku_theme_mode':
    case 'tsundoku_reduce_motion':
    case 'quiet_hours_settings':
    case 'reminder_settings':
      return value is String && value.isNotEmpty;
    case 'tsundoku_text_scale':
      return value is num;
    case 'tutorial_lore_seen':
    case 'tutorial_operation_seen':
      return value is bool;
    default:
      return false;
  }
}

/// null は「未設定」を意味するので控えには載せない（キー自体を出さない）。
bool _isJsonScalar(Object? value) =>
    value is String || value is num || value is bool;

/// 控えに載せる設定の束（JSON 安全）
class BackupSettingsBundle {
  /// 形式の版（将来の移行用）
  final int schemaVersion;

  /// 控えに載せる設定値（許可リスト通過済み）
  final Map<String, Object?> values;

  const BackupSettingsBundle({
    this.schemaVersion = 1,
    this.values = const <String, Object?>{},
  });

  /// 生の設定マップから束を作る（許可リスト通過・秘密除外）
  factory BackupSettingsBundle.fromRaw(Map<String, Object?> raw) =>
      BackupSettingsBundle(values: selectForBackup(raw));

  Map<String, Object?> toJson() => <String, Object?>{
        'schemaVersion': schemaVersion,
        'values': values,
      };

  /// 破損・非 Map・values 非 Map は null（**絶対に throw しない**）。
  ///
  /// 読み込み時にも許可リストと秘密除外を通す（改竄された控え対策）。
  static BackupSettingsBundle? tryFromJson(Object? json) {
    try {
      if (json is! Map) return null;
      final rawValues = json['values'];
      if (rawValues is! Map) return null;

      final raw = <String, Object?>{};
      for (final entry in rawValues.entries) {
        final key = entry.key;
        if (key is! String) continue;
        raw[key] = entry.value;
      }

      final schema = json['schemaVersion'];
      final version =
          schema is int && schema >= 1 && schema <= 1000 ? schema : 1;

      return BackupSettingsBundle(
        schemaVersion: version,
        values: selectForBackup(raw),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  String toString() =>
      'BackupSettingsBundle(schemaVersion: $schemaVersion, keys: ${values.length})';
}
