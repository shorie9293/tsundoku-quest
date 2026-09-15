/// シェアカード画像の共有 exports
library;

import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';

/// 画像共有の抽象（テストでフェイク注入可能に）
abstract class ShareCardExporter {
  Future<void> shareImage({required Uint8List png, required String text});
}

/// share_plus 13系 API を使った実装
class SharePlusExporter implements ShareCardExporter {
  const SharePlusExporter();

  @override
  Future<void> shareImage({required Uint8List png, required String text}) {
    return SharePlus.instance.share(
      ShareParams(files: [XFile.fromData(png, mimeType: 'image/png')], text: text),
    );
  }
}
