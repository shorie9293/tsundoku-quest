import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../testing/widget_keys.dart';
import 'app_lock_repository.dart';
import 'app_lock_service.dart';

/// アプリロック有効時に全UIを隠すゲートWidget。
/// repository は注入可能（テスト用）。デフォルトは実 SharedPreferences。
/// 読込例外・生成失敗は握りつぶして素通り（fail-open）。
class AppLockGate extends StatefulWidget {
  final WidgetBuilder unlockedBuilder;
  final AppLockRepository? repository;

  const AppLockGate({
    super.key,
    required this.unlockedBuilder,
    this.repository,
  });

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate> {
  AppLockService? _service;
  bool _initialized = false;
  bool _locked = false;
  bool _obscure = true;
  final _codeController = TextEditingController();
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final repo = widget.repository ??
          SharedPreferencesAppLockRepository(
            await SharedPreferences.getInstance(),
          );
      final service = AppLockService(repo);
      final locked = service.isLocked;
      if (!mounted) return;
      setState(() {
        _service = service;
        _locked = locked;
        _initialized = true;
      });
    } catch (e) {
      // fail-open: 読込例外時はロックせず素通り
      if (!mounted) return;
      setState(() {
        _service = null;
        _locked = false;
        _initialized = true;
      });
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final service = _service;
    if (service == null) return;
    final ok = await service.unlock(passcode: _codeController.text);
    if (!mounted) return;
    if (ok) {
      setState(() => _locked = false);
    } else {
      setState(() => _error = 'パスコードが正しくありません');
    }
    _codeController.clear();
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
    return Overlay(
      initialEntries: [
        OverlayEntry(builder: (_) => _buildLockedScaffold()),
      ],
    );
  }

  Widget _buildLockedScaffold() {
    return Scaffold(
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
              const SizedBox(height: 16),
              FilledButton(
                key: AppKeys.appLockUnlockButton,
                onPressed: _submit,
                child: const Text('ロック解除'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
