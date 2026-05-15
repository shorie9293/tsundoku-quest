import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/testing/widget_keys.dart';
import '../../../core/widgets/dungeon_background.dart';
import '../../../domain/models/book.dart';
import '../../../domain/models/user_book.dart';
import '../../../shared/providers/book_data_provider.dart';
import '../../../shared/providers/book_search_service_provider.dart';
import 'widgets/search_results_widget.dart';

/// 探索画面（本の登録）
class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  int _selectedTab = 0; // 0=検索, 1=スキャン, 2=手入力
  final _searchController = TextEditingController();
  final _titleController = TextEditingController();
  final _authorController = TextEditingController();
  final _isbnController = TextEditingController();

  // 検索状態
  List<Book>? _searchResults;
  bool _isSearching = false;

  // スキャン状態
  bool _isScanning = false;
  String? _lastScannedIsbn;
  DateTime? _lastScanTime;
  static const _scanDebounceMs = 2500; // 同一ISBNの重複検出防止
  MobileScannerController? _scannerController;

  void _addBook(Book book) {
    final notifier = ref.read(bookDataProvider.notifier);
    notifier.addBook(book);
    notifier.addUserBook(UserBook(
      id: 'ub-${book.id}',
      userId: 'local-user',
      bookId: book.id,
      book: book,
      status: BookStatus.tsundoku,
      medium: BookMedium.physical,
      createdAt: DateTime.now().toUtc().toIso8601String(),
    ));
    context.go('/');
  }

  Future<void> _performSearch(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;

    setState(() {
      _isSearching = true;
      _searchResults = null;
    });

    try {
      final service = ref.read(bookSearchServiceProvider);
      final results = await service.search(trimmed);
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSearching = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('🔌 検索エラー: $e')),
        );
      }
    }
  }

  void _onManualSubmit() {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;
    final book = Book(
      id: 'manual-${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      authors: _authorController.text.trim().isEmpty
          ? []
          : _authorController.text.split(',').map((s) => s.trim()).toList(),
      isbn13: _isbnController.text.trim().isEmpty
          ? null
          : _isbnController.text.trim(),
      source: BookSource.manual,
      createdAt: DateTime.now().toUtc().toIso8601String(),
    );
    _addBook(book);
  }

  Future<void> _onBarcodeDetected(String? rawValue) async {
    if (_isScanning) return;
    if (rawValue == null || rawValue.isEmpty) return;

    // デバウンス: 同一ISBNを短時間に再検出したら無視
    final now = DateTime.now();
    if (rawValue == _lastScannedIsbn &&
        _lastScanTime != null &&
        now.difference(_lastScanTime!).inMilliseconds < _scanDebounceMs) {
      return;
    }
    _lastScannedIsbn = rawValue;
    _lastScanTime = now;

    setState(() => _isScanning = true);

    try {
      final service = ref.read(bookSearchServiceProvider);
      final book = await service.lookupByIsbn(rawValue);
      if (book != null && mounted) {
        _addBook(book);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('📚 本が見つかりませんでした')),
        );
        await Future.delayed(const Duration(milliseconds: 1500));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('🔌 検索エラー: $e')),
        );
        await Future.delayed(const Duration(milliseconds: 1500));
      }
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _titleController.dispose();
    _authorController.dispose();
    _isbnController.dispose();
    _scannerController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: AppKeys.exploreScreen,
      appBar: AppBar(title: const Text('🧭 探索')),
      body: DungeonBackground(
        child: Column(
        children: [
          // Tab selector
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _TabButton(
                  label: '🔍 検索',
                  isSelected: _selectedTab == 0,
                  onTap: () => setState(() => _selectedTab = 0),
                ),
                const SizedBox(width: 8),
                _TabButton(
                  label: '📷 スキャン',
                  isSelected: _selectedTab == 1,
                  onTap: () => setState(() => _selectedTab = 1),
                ),
                const SizedBox(width: 8),
                _TabButton(
                  label: '✏️ 手入力',
                  isSelected: _selectedTab == 2,
                  onTap: () => setState(() => _selectedTab = 2),
                ),
              ],
            ),
          ),
          // Tab content
          Expanded(
            child: _selectedTab == 1
                ? _buildScanTab()
                : IndexedStack(
                    index: _selectedTab,
                    children: [
                      _buildSearchTab(),
                      const SizedBox.shrink(),
                      _buildManualTab(),
                    ],
                  ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildSearchTab() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          TextField(
            key: AppKeys.searchField,
            controller: _searchController,
            decoration: const InputDecoration(
              hintText: 'タイトルまたはISBNで検索',
              prefixIcon: Icon(Icons.search),
            ),
            onSubmitted: _performSearch,
          ),
          const SizedBox(height: 16),
          Expanded(child: _buildSearchContent()),
        ],
      ),
    );
  }

  Widget _buildSearchContent() {
    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_searchResults != null) {
      if (_searchResults!.isEmpty) {
        return const Center(
          child: Text('検索結果が見つかりませんでした',
              style: TextStyle(color: AppTheme.textSecondary)),
        );
      }
      return SearchResultsWidget(
        books: _searchResults!,
        onAddBook: _addBook,
      );
    }
    return const Center(
      child: Text('本を検索してください',
          style: TextStyle(color: AppTheme.textSecondary)),
    );
  }

  Widget _buildScanTab() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scanWidth = constraints.maxWidth * 0.7;
        final scanHeight = constraints.maxHeight * 0.35;
        final scanWindow = Rect.fromCenter(
          center: Offset(constraints.maxWidth / 2, constraints.maxHeight / 3),
          width: scanWidth,
          height: scanHeight,
        );

        return Stack(
          children: [
            // Camera preview
            MobileScanner(
              key: AppKeys.scanPreview,
              controller: _scannerController,
              scanWindow: scanWindow,
              onDetect: (capture) {
                final barcodes = capture.barcodes;
                for (final barcode in barcodes) {
                  if (barcode.rawValue != null &&
                      barcode.rawValue!.isNotEmpty) {
                    _onBarcodeDetected(barcode.rawValue);
                    break;
                  }
                }
              },
            ),
            // Scan window frame guide
            Positioned.fromRect(
              rect: scanWindow,
              child: Container(
                key: AppKeys.scanFrame,
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.accent, width: 2),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            // Bottom guide text
            Positioned(
              left: 0,
              right: 0,
              bottom: 24,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _isScanning
                      ? const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(width: 8),
                            Text('検索中...',
                                style: TextStyle(color: Colors.white)),
                          ],
                        )
                      : const Text('枠内にバーコードをかざしてください',
                          style:
                              TextStyle(color: Colors.white, fontSize: 12)),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildManualTab() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          TextField(
            key: AppKeys.manualTitleField,
            controller: _titleController,
            decoration:
                const InputDecoration(hintText: 'タイトル *', labelText: 'タイトル'),
          ),
          const SizedBox(height: 12),
          TextField(
            key: AppKeys.manualAuthorField,
            controller: _authorController,
            decoration:
                const InputDecoration(hintText: '著者 (カンマ区切り)', labelText: '著者'),
          ),
          const SizedBox(height: 12),
          TextField(
            key: AppKeys.manualIsbnField,
            controller: _isbnController,
            decoration:
                const InputDecoration(hintText: 'ISBN', labelText: 'ISBN'),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              key: AppKeys.manualSubmit,
              onPressed: _onManualSubmit,
              child: const Text('登録する'),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _TabButton(
      {required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.accent.withAlpha(40)
                : AppTheme.cardBackground,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? AppTheme.accent : AppTheme.border,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isSelected ? AppTheme.active : AppTheme.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
