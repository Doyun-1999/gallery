// lib/screen/home_screen.dart
import 'package:flutter/material.dart';
import 'package:gallery_memo/model/gallery_model.dart';
import 'package:gallery_memo/screen/albums_screen.dart';
import 'package:gallery_memo/screen/favorite_screen.dart';
import 'package:gallery_memo/screen/gallery_screen.dart';
import 'package:gallery_memo/screen/videos_screen.dart';
import 'package:gallery_memo/screen/photo_view_screen.dart';
import 'package:gallery_memo/utils/permission_manager.dart';
import 'package:gallery_memo/widget/album_dialogs.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  HomeScreenState createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  bool _hasPhotoPermission = false;
  bool _isLoading = true;

  bool _isSelectMode = false;
  final Set<String> _selectedPhotoIds = {};

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  void _onItemTap(String photoId) {
    if (_isSelectMode) {
      _togglePhotoSelection(photoId);
    } else {
      // Gallery, Videos 탭에서 상세보기로 이동
      final source =
          _selectedIndex == 0
              ? PhotoViewSource.gallery
              : PhotoViewSource.video; // Videos 탭을 위한 소스 구분
      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (context) => PhotoViewScreen(photoId: photoId, source: source),
        ),
      );
    }
  }

  void _onItemLongPress(String photoId) {
    if (!_isSelectMode) {
      _enterSelectMode();
      _togglePhotoSelection(photoId);
    }
  }

  Future<void> _checkPermissions() async {
    try {
      final PermissionState photoPermission =
          await PhotoManager.requestPermissionExtend();
      final bool hasPhotoPermissionAccess = photoPermission.hasAccess;

      if (!hasPhotoPermissionAccess) {
        if (mounted) {
          setState(() {
            _hasPhotoPermission = false;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _hasPhotoPermission = true;
            _isLoading = true;
          });
        }
        final galleryModel = Provider.of<GalleryModel>(context, listen: false);
        await galleryModel.loadDevicePhotos([]);
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print("권한 확인 중 오류 발생: $e");
      if (mounted) {
        setState(() {
          _hasPhotoPermission = false;
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildPermissionScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.no_photography, size: 80, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            '사진 접근 권한이 필요합니다',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            '갤러리 기능을 사용하려면 사진 접근 권한을 허용해주세요.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () async {
              final hasPermission =
                  await PermissionManager.requestPhotoPermission(context);
              if (hasPermission) {
                _checkPermissions();
              }
            },
            child: const Text('권한 허용하기'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(context),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _hasPhotoPermission
              ? IndexedStack(
                index: _selectedIndex,
                children: <Widget>[
                  GalleryScreen(
                    key: const ValueKey('gallery_screen'),
                    isSelectMode: _isSelectMode,
                    selectedPhotoIds: _selectedPhotoIds,
                    onPhotoTap: _onItemTap,
                    onPhotoLongPress: _onItemLongPress,
                  ),
                  VideosScreen(
                    key: const ValueKey('videos_screen'),
                    isSelectMode: _isSelectMode,
                    selectedPhotoIds: _selectedPhotoIds,
                    onPhotoTap: _onItemTap,
                    onPhotoLongPress: _onItemLongPress,
                  ),
                  const FavoritesScreen(key: ValueKey('favorites_screen')),
                  const AlbumsScreen(key: ValueKey('albums_screen')),
                ],
              )
              : _buildPermissionScreen(),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color:
              Theme.of(context).bottomNavigationBarTheme.backgroundColor ??
              Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(0, Icons.photo_library, '갤러리'),
                _buildNavItem(1, Icons.video_library, '동영상'),
                _buildNavItem(2, Icons.favorite, '즐겨찾기'),
                _buildNavItem(3, Icons.album, '앨범'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  AppBar _buildAppBar(BuildContext context) {
    if (_isSelectMode && (_selectedIndex == 0 || _selectedIndex == 1)) {
      return AppBar(
        title: Text('${_selectedPhotoIds.length}개 선택됨'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _exitSelectMode,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            tooltip: '삭제',
            onPressed:
                _selectedPhotoIds.isEmpty
                    ? null
                    : () => _deleteSelectedPhotos(context),
          ),
          IconButton(
            icon: const Icon(Icons.favorite_border),
            tooltip: '즐겨찾기',
            onPressed:
                _selectedPhotoIds.isEmpty
                    ? null
                    : () => _toggleSelectedPhotosFavorite(context),
          ),
          IconButton(
            icon: const Icon(Icons.playlist_add),
            tooltip: '앨범에 추가',
            onPressed:
                _selectedPhotoIds.isEmpty
                    ? null
                    : () => _addSelectedPhotosToAlbum(context),
          ),
        ],
      );
    } else {
      return AppBar(
        title: const Text('사진 갤러리'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed:
                _hasPhotoPermission ? () => _refreshGallery(context) : null,
          ),
        ],
      );
    }
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _selectedIndex == index;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (_selectedIndex != index) {
          setState(() {
            _selectedIndex = index;
            if (_isSelectMode) {
              _exitSelectMode();
            }
          });
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? Theme.of(context).primaryColor.withOpacity(0.1)
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? Theme.of(context).primaryColor : Colors.grey,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color:
                    isSelected ? Theme.of(context).primaryColor : Colors.grey,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _refreshGallery(BuildContext context) async {
    setState(() {
      _isLoading = true;
    });

    final galleryModel = Provider.of<GalleryModel>(context, listen: false);
    await galleryModel.loadDevicePhotos(
      galleryModel.favorites.map((p) => p.id).toList(),
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _enterSelectMode() {
    setState(() {
      _isSelectMode = true;
    });
  }

  void _exitSelectMode() {
    setState(() {
      _isSelectMode = false;
      _selectedPhotoIds.clear();
    });
  }

  void _togglePhotoSelection(String photoId) {
    setState(() {
      if (_selectedPhotoIds.contains(photoId)) {
        _selectedPhotoIds.remove(photoId);
        if (_selectedPhotoIds.isEmpty) {
          _isSelectMode = false;
        }
      } else {
        _selectedPhotoIds.add(photoId);
      }
    });
  }

  Future<void> _deleteSelectedPhotos(BuildContext context) async {
    final galleryModel = Provider.of<GalleryModel>(context, listen: false);
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('삭제 확인'),
            content: Text('${_selectedPhotoIds.length}개의 항목을 삭제하시겠습니까?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('취소'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('삭제', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
    );

    if (confirm == true) {
      final Set<String> idsToDelete = Set.from(_selectedPhotoIds);
      for (final photoId in idsToDelete) {
        await galleryModel.deletePhoto(photoId);
      }
      _exitSelectMode();
    }
  }

  void _addSelectedPhotosToAlbum(BuildContext context) async {
    if (_selectedPhotoIds.isEmpty) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => AddToAlbumDialog(photoId: _selectedPhotoIds.first),
    );
  }

  void _toggleSelectedPhotosFavorite(BuildContext context) async {
    final galleryModel = Provider.of<GalleryModel>(context, listen: false);
    final allPhotos = galleryModel.photos;
    final selectedPhotos = allPhotos.where(
      (photo) => _selectedPhotoIds.contains(photo.id),
    );

    if (selectedPhotos.isEmpty) return;

    final allFavorites = selectedPhotos.every((photo) => photo.isFavorite);
    final selectedCount = _selectedPhotoIds.length;

    for (final photo in selectedPhotos) {
      await galleryModel.toggleFavorite(photo.id);
    }

    _exitSelectMode();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            allFavorites
                ? '$selectedCount개의 사진을 즐겨찾기에서 제거했습니다.'
                : '$selectedCount개의 사진을 즐겨찾기에 추가했습니다.',
          ),
        ),
      );
    }
  }
}
