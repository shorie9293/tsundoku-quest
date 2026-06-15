import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/infrastructure/supabase/supabase_client_provider.dart';
import '../../core/infrastructure/supabase/supabase_storage_service.dart';
import '../../domain/models/game_avatar.dart';

/// 表示中のアバター角度
final avatarAngleProvider = StateProvider<AvatarAngle>((ref) => AvatarAngle.defaultAngle);

/// アバターデータ
final avatarProvider = FutureProvider<GameAvatar>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final storage = SupabaseStorageService(client);
  final sprites = await storage.fetchAvatarSprites('default');
  if (sprites.isNotEmpty) {
    return GameAvatar(
      id: 'default',
      name: '冒険者',
      spriteUrls: sprites,
    );
  }
  return GameAvatar.placeholder();
});
