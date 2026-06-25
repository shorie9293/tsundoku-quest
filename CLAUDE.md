# CLAUDE.md — tsundoku-quest-flutter

## Project Overview

**ツンドクエスト (Tsundoku Quest)** — Flutter 製の積読管理 RPG アプリ。本の ISBN バーコードをスキャンして積読をクエスト化し、読書進捗で経験値を獲得する。

## Tech Stack

- **Framework**: Flutter (Dart SDK ^3.6.2)
- **State Management**: Riverpod (`flutter_riverpod: ^2.6.0`)
- **Navigation**: go_router (`go_router: ^14.6.0`)
- **Backend**: Supabase (`supabase_flutter: ^2.8.0`)
- **Local Storage**: Hive (`hive_flutter: ^1.1.0`) + SharedPreferences
- **Barcode**: mobile_scanner (`mobile_scanner: ^6.0.0`)
- **Monorepo Packages**: takamagahara_core, takamagahara_ui (`../../packages/`)
- **Current Version**: 1.0.2+36

## Project Structure

```
lib/
  main.dart              # App entry point
  core/                  # Core infrastructure (Supabase, widgets)
  features/              # Feature modules
  shared/                # Shared providers, models
test/
  core/                  # Core tests
  shared/                # Shared tests
```

## Common Commands

```bash
# Get dependencies
flutter pub get

# Run app
flutter run

# Analyze (warnings = CI failure!)
flutter analyze --no-fatal-infos

# Run tests
flutter test

# Build Android App Bundle
flutter build appbundle --release
```

## ⛩️ Push Gate

**Pre-push hook** at `.git/hooks/pre-push` runs `flutter analyze --no-fatal-infos` before every push.
- Warnings (not just errors) cause exit code 1 = push REJECTED.
- This mirrors the CI check exactly — prevents CI failures from missed warnings.
- Info-level issues are suppressed by `--no-fatal-infos` and won't block.

## 🚀 Pre-Deploy Check

Before deploying, run the full CI simulation:
```bash
bash scripts/pre-deploy-check.sh
```
This runs: `flutter pub get` → `flutter analyze --no-fatal-infos` → `flutter test`
All must pass before deployment.

## CI/CD

- **CI**: `.github/workflows/flutter-ci.yml` — runs on push/PR to main
  - Setup monorepo packages → flutter pub get → analyze → test
- **Deploy**: `.github/workflows/deploy.yml` — triggers on `pubspec.yaml` change on main
  - Builds AAB → deploys to Google Play via fastlane

## Pitfalls

- **analyze warning = CI failure**: `--no-fatal-infos` only suppresses `info`, not `warning`. Always run `flutter analyze --no-fatal-infos` before pushing.
- **Monorepo packages**: CI clones packages from `shorie9293/takamagahara` repo. Locally they're at `../../packages/`.
- **Hive in tests**: Widget tests using Hive may need `TestWidgetsFlutterBinding.ensureInitialized()` in `main()`.
