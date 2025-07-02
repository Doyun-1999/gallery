import 'package:photo_manager/photo_manager.dart';

/// 상위 폴더 기준으로 그룹화된 앨범을 표현하는 클래스
class GroupedAlbum {
  /// 상위 폴더 이름 (예: "Download", "DCIM")
  final String name;

  /// 이 그룹에 속한 모든 AssetEntity 리스트
  final List<AssetEntity> assets;

  /// 그룹에 속한 미디어 개수
  int get assetCount => assets.length;

  /// 앨범의 썸네일로 사용할 첫 번째 에셋
  AssetEntity? get thumbnail => assets.isNotEmpty ? assets.first : null;

  GroupedAlbum({required this.name, required this.assets});
}
