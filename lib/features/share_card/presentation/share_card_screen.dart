/// 読了シェアカード画面（Riverpod非依存）
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/testing/widget_keys.dart';
import 'package:tsundoku_quest/features/share_card/data/share_card_exporter.dart';
import 'package:tsundoku_quest/features/share_card/domain/share_card_data.dart';
import 'package:tsundoku_quest/features/share_card/domain/share_card_service.dart';
import 'share_card_capture.dart';
import 'share_card_widget.dart';

/// 読了シェアカード生成・共有画面
class ShareCardScreen extends StatefulWidget {
  final List<ShareCardData> candidates;
  final ShareCardExporter? exporter;
  final ShareCardCapture? capture;

  const ShareCardScreen({
    super.key,
    required this.candidates,
    this.exporter,
    this.capture,
  });

  @override
  State<ShareCardScreen> createState() => _ShareCardScreenState();
}

class _ShareCardScreenState extends State<ShareCardScreen> {
  final GlobalKey _previewKey = LabeledGlobalKey('view_share_card_preview');
  ShareCardData? _selected;
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.candidates.isEmpty ? -1 : 0;
    _selected =
        widget.candidates.isEmpty ? null : widget.candidates.first;
  }

  ShareCardCapture? get _capture =>
      widget.capture ?? RepaintBoundaryCapture(_previewKey);

  void _onShare() async {
    final selected = _selected;
    if (selected == null) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final png = await _capture?.capture();
      if (png == null) {
        messenger.showSnackBar(
          const SnackBar(content: Text('カード画像を生成できませんでした')),
        );
        return;
      }
      await (widget.exporter ?? const SharePlusExporter())
          .shareImage(png: png, text: ShareCardService.shareText(selected));
      messenger.showSnackBar(
        const SnackBar(content: Text('カードを共有しました')),
      );
    } on Exception {
      messenger.showSnackBar(
        const SnackBar(content: Text('カードの共有に失敗しました')),
      );
    }
  }

  void _onCopy() async {
    final selected = _selected;
    if (selected == null) return;
    await Clipboard.setData(
      ClipboardData(text: ShareCardService.shareText(selected)),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('テキストをコピーしました')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: AppKeys.shareCardScreen,
      appBar: AppBar(title: const Text('読了カードを共有')),
      body: widget.candidates.isEmpty
          ? const Center(
              key: AppKeys.shareCardEmpty,
              child: Text('読了した本がまだない'),
            )
          : SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: Center(
                      child: RepaintBoundary(
                        key: _previewKey,
                        child: KeyedSubtree(
                          key: AppKeys.shareCardPreview,
                          child: ShareCard(data: _selected!),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.candidates.length > 1)
                          DropdownButton<int>(
                            key: AppKeys.shareCardCandidate,
                            value: _selectedIndex,
                            isExpanded: true,
                            items: [
                              for (var i = 0;
                                  i < widget.candidates.length;
                                  i++)
                                DropdownMenuItem(
                                  value: i,
                                  child: Text(widget.candidates[i].title),
                                ),
                            ],
                            onChanged: (index) {
                              if (index == null) return;
                              setState(() {
                                _selectedIndex = index;
                                _selected = widget.candidates[index];
                              });
                            },
                          ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton.icon(
                                key: AppKeys.shareCardShareButton,
                                onPressed: _onShare,
                                icon: const Icon(Icons.ios_share),
                                label: const Text('共有'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                key: AppKeys.shareCardCopyButton,
                                onPressed: _onCopy,
                                icon: const Icon(Icons.copy),
                                label: const Text('テキストコピー'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
