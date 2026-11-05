import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/account_deletion/data/hive_account_deletion_data_eraser.dart';
import '../../features/auto_backup/data/auto_backup_store.dart';
import '../../features/auto_backup/domain/auto_backup_policy.dart';
import '../../features/backup/data/backup_repository.dart';
import '../testing/widget_keys.dart';
import 'app_lock_recovery_policy.dart';
import 'app_lock_repository.dart';
import 'app_lock_service.dart';
import 'lock_attempt_policy.dart';
import 'lock_recovery_service.dart';
import 'lock_reload_policy.dart';

/// アプリロック有効時に全UIを隠すゲートWidget。
/// repository は注入可能（テスト用）。デフォルトは実 SharedPreferences。
/// 読込例外・生成失敗は握りつぶして素通り（fail-open）。
class AppLockGate extends StatefulWidget {
  final WidgetBuilder unlockedBuilder;
  final AppLockRepository? repository;

  /// 試練用の時刻注入（既定は `DateTime.now`）。
  final DateTime Function()? now;

  /// 試練用の猶予上書き（既定はリポジトリの保存値）。
  final Duration? graceOverride;

  /// パスコード忘却時の回復役（未注入なら本番実装を組み立てる）。
  final LockRecoveryService? recoveryService;

  const AppLockGate({
    super.key,
    required this.unlockedBuilder,
    this.repository,
    this.now,
    this.graceOverride,
    this.recoveryService,
  });

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate> with WidgetsBindingObserver {
  AppLockService? _service;
  bool _initialized = false;
  bool _locked = false;
  bool _obscure = true;
  final _codeController = TextEditingController();
  String? _error;

  /// 背景化を最初に観測した時刻（猶予判定の起点）。
  DateTime? _backgroundedAt;

  Duration _grace = Duration.zero;

  /// 回復ダイアログの表示状態。
  bool _showRecovery = false;
  bool _recovering = false;
  String? _recoveryError;
  final _confirmController = TextEditingController();

  /// 回復役（ロック読込成功時のみ生成）。
  LockRecoveryService? _recovery;

  DateTime _now() => (widget.now ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  Future<void> _init() async {
    AppLockService? service;
    var grace = Duration.zero;
    try {
      final repo = widget.repository ??
          SharedPreferencesAppLockRepository(
            await SharedPreferences.getInstance(),
          );
      service = AppLockService(repo, now: widget.now ?? DateTime.now);
      service.isLocked;
      grace = service.relockGrace;
    } catch (_) {
      service = null; // fail-open
    }
    if (!mounted) return;
    setState(() {
      _service = service;
      _recovery = widget.recoveryService ??
          (service == null
              ? null
              : LockRecoveryService(
                  service,
                  backupExporter: _exportBackup,
                  dataEraser: _eraseLocalData,
                ));
      _locked = service?.isLocked ?? false;
      _initialized = true;
      _grace = widget.graceOverride ?? grace;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _codeController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.inactive) {
      // 最初の背景化時刻を保持する（inactive→paused で上書きしない）。
      _backgroundedAt ??= _now();
      return;
    }
    if (state == AppLifecycleState.resumed) {
      _handleResumed();
    }
  }

  void _handleResumed() {
    final backgroundedAt = _backgroundedAt;
    _backgroundedAt = null;
    final service = _service;
    if (service == null) return;
    // ロック無効時は一切変わらない。
    if (!service.isLocked) return;
    if (!LockReloadPolicy.shouldRelock(backgroundedAt, _now(), _grace)) return;
    if (!mounted) return;
    setState(() {
      _locked = true;
      _error = null;
      _codeController.clear();
    });
  }

  Future<void> _submit() async {
    final service = _service;
    if (service == null) return;
    if (service.isLockedOut) {
      setState(() => _error = 'パスコードが正しくありません');
      return;
    }
    final ok = await service.unlock(passcode: _codeController.text);
    if (!mounted) return;
    if (ok) {
      setState(() => _locked = false);
    } else {
      setState(() => _error = 'パスコードが正しくありません');
    }
    _codeController.clear();
  }

  // ── パスコード忘却時の回復（#211）──

  void _openRecovery() {
    setState(() {
      _showRecovery = true;
      _recoveryError = null;
      _recovering = false;
      _confirmController.clear();
    });
  }

  void _closeRecovery() {
    setState(() {
      _showRecovery = false;
      _recoveryError = null;
      _recovering = false;
      _confirmController.clear();
    });
  }

  Future<void> _runRecovery() async {
    final recovery = _recovery;
    if (recovery == null) return;
    if (!LockRecoveryPolicy.isConfirmationValid(_confirmController.text)) {
      setState(() => _recoveryError =
          '「${LockRecoveryPolicy.confirmationPhrase}」と入力してください');
      return;
    }
    setState(() {
      _recovering = true;
      _recoveryError = null;
    });
    final messenger = ScaffoldMessenger.maybeOf(context);
    final result = await recovery.recover(
      confirmation: _confirmController.text,
    );
    if (!mounted) return;
    if (!result.succeeded) {
      setState(() {
        _recovering = false;
        _recoveryError = '回復できませんでした（ロックが無効か、解除に失敗しました）';
      });
      return;
    }
    setState(() {
      _recovering = false;
      _showRecovery = false;
      _locked = false;
      _confirmController.clear();
    });
    messenger?.showSnackBar(SnackBar(content: Text(_recoveryMessage(result))));
  }

  /// 結果をそのまま伝える（成功を誇張しない）。
  String _recoveryMessage(LockRecoveryResult result) {
    final parts = <String>['ロックを解除しました。'];
    if (result.backupPath != null) {
      parts.add('バックアップ: ${result.backupPath}');
    } else if (result.backupFailed) {
      parts.add('バックアップは取得できませんでした。');
    }
    parts.add(
      result.dataWiped ? 'データを初期化しました。' : 'データの初期化には失敗しました。',
    );
    return parts.join(' ');
  }

  /// 本番のバックアップ書き出し（features/backup + auto_backup を再利用）。
  Future<String?> _exportBackup() async {
    final container = ProviderScope.containerOf(context, listen: false);
    final repository = container.read(backupRepositoryProvider);
    final data = await repository.collect();
    final json = const JsonEncoder.withIndent('  ').convert(data.toJson());
    final fileName = AutoBackupPolicy.fileNameFor(DateTime.now());
    await FileAutoBackupStore().write(fileName, json);
    return fileName;
  }

  /// 本番のデータ初期化（退会処理の全データ消去を再利用）。
  Future<void> _eraseLocalData() async {
    await const HiveAccountDeletionDataEraser().call();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!_locked) {
      return widget.unlockedBuilder(context);
    }
    // builder 配線（MaterialApp.builder）では Navigator の外に置かれるため
    // TextField（autofocus）用に自前で Overlay を用意する。
    // エラー・ロックアウト表示の更新で entry を作り直すため key を状態に連動。
    final lockedOut = _service?.isLockedOut ?? false;
    return Overlay(
      key: ValueKey('locked:${_error ?? ''}:$_obscure:$lockedOut:'
          '$_showRecovery:$_recovering:${_recoveryError ?? ''}'),
      initialEntries: [
        OverlayEntry(builder: (_) => _buildLockedScaffold(lockedOut)),
        if (_showRecovery) OverlayEntry(builder: (_) => _buildRecoverySheet()),
      ],
    );
  }

  /// 回復の確認（Navigator の外なので自前のモーダルとして重ねる）。
  Widget _buildRecoverySheet() {
    final theme = Theme.of(context);
    return Positioned.fill(
      child: Material(
        color: Colors.black54,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Material(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'パスコードを忘れた場合',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      const Text(LockRecoveryPolicy.warningMessage),
                      const SizedBox(height: 16),
                      TextField(
                        key: AppKeys.appLockRecoveryConfirmField,
                        controller: _confirmController,
                        enabled: !_recovering,
                        decoration: InputDecoration(
                          labelText: '確認のため「'
                              '${LockRecoveryPolicy.confirmationPhrase}」と入力',
                          errorText: _recoveryError,
                        ),
                      ),
                      if (_recoveryError != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            _recoveryError!,
                            key: AppKeys.appLockRecoveryError,
                            style: TextStyle(color: theme.colorScheme.error),
                          ),
                        ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            key: AppKeys.appLockRecoveryCancelButton,
                            onPressed:
                                _recovering ? null : _closeRecovery,
                            child: const Text('キャンセル'),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            key: AppKeys.appLockRecoveryConfirmButton,
                            onPressed: _recovering ? null : _runRecovery,
                            child: Text(_recovering ? '実行中…' : '初期化して解除'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLockedScaffold(bool lockedOut) {
    return Scaffold(
      key: AppKeys.appLockGateScreen,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock, size: 48),
              const SizedBox(height: 16),
              const Text(
                'ツンドクエストはロックされています',
                key: AppKeys.appLockLockedMessage,
              ),
              const SizedBox(height: 24),
              TextField(
                key: AppKeys.appLockPasscodeField,
                controller: _codeController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                maxLength: 4,
                obscureText: _obscure,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'パスコード',
                  errorText: _error,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscure ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                onSubmitted: (_) => _submit(),
              ),
              if (lockedOut)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    LockAttemptPolicy.lockoutLabel(
                      _service?.lockoutRemainingSeconds ?? 0,
                    ),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              FilledButton(
                key: AppKeys.appLockUnlockButton,
                onPressed: lockedOut ? null : _submit,
                child: const Text('ロック解除'),
              ),
              const SizedBox(height: 8),
              TextButton(
                key: AppKeys.appLockForgotButton,
                onPressed: _openRecovery,
                child: const Text('パスコードをお忘れですか？'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
