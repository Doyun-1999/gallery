import 'package:flutter/material.dart';
import 'package:gallery_memo/model/gallery_model.dart';
import 'package:gallery_memo/screen/albums_screen.dart';
import 'package:gallery_memo/screen/favorite_screen.dart';
import 'package:gallery_memo/screen/gallery_screen.dart';
import 'package:gallery_memo/screen/videos_screen.dart';
import 'package:gallery_memo/screen/photo_view_screen.dart';
import 'package:gallery_memo/utils/permission_manager.dart';
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

  // 선택 모드 및 선택 상태 관리
  bool _isSelectMode = false;
  final Set<String> _selectedPhotoIds = {};

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    try {
      // 1. 먼저 PhotoManager로 권한 상태 확인
      final PermissionState photoPermission =
          await PhotoManager.requestPermissionExtend();

      print(
        "PhotoManager 권한 상태: ${photoPermission.isAuth}, ${photoPermission.hasAccess}",
      );

      // 2. Permission Handler로도 확인 (비교용)
      final photosStatus = await Permission.photos.status;
      print("Permission Handler 권한 상태: ${photosStatus.isGranted}");

      // 3. 둘 중 하나라도 권한이 있으면 진행
      final bool hasPhotoPermissionAccess =
          photoPermission.hasAccess || photosStatus.isGranted;

      if (!hasPhotoPermissionAccess) {
        // 권한이 없는 경우
        setState(() {
          _hasPhotoPermission = false;
          _isLoading = false;
        });
        print("권한 없음: PhotoManager와 Permission Handler 모두 권한 없음");
      } else {
        // 권한이 있는 경우 (둘 중 하나라도 있으면)
        setState(() {
          _hasPhotoPermission = true;
          _isLoading = true;
        });

        // 권한을 처음 허용할 때는 즐겨찾기가 없음
        final galleryModel = Provider.of<GalleryModel>(context, listen: false);
        await galleryModel.loadDevicePhotos([]);

        setState(() {
          _isLoading = false;
        });
        print("권한 있음: 이미지 로드 완료");
      }
    } catch (e) {
      print("권한 확인 중 오류 발생: $e");
      setState(() {
        _hasPhotoPermission = false;
        _isLoading = false;
      });
    }
  }

  // 현재 선택된 화면을 반환하는 메서드
  Widget _getCurrentScreen() {
    switch (_selectedIndex) {
      case 0:
        return GalleryScreen(
          isSelectMode: _isSelectMode,
          selectedPhotoIds: _selectedPhotoIds,
          onPhotoTap: (photoId) {
            if (_isSelectMode) {
              _togglePhotoSelection(photoId);
            } else {
              // 상세보기로 이동 (PhotoViewScreen)
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (context) => PhotoViewScreen(
                        photoId: photoId,
                        source: PhotoViewSource.gallery,
                      ),
                ),
              );
            }
          },
          onPhotoLongPress: (photoId) {
            if (!_isSelectMode) {
              _enterSelectMode();
              _togglePhotoSelection(photoId);
            }
          },
        );
      case 1:
        return const VideosScreen();
      case 2:
        return const FavoritesScreen();
      case 3:
        return const AlbumsScreen();
      default:
        return GalleryScreen(
          isSelectMode: _isSelectMode,
          selectedPhotoIds: _selectedPhotoIds,
          onPhotoTap: (photoId) {},
          onPhotoLongPress: (photoId) {},
        );
    }
  }

  // 권한 요청 화면을 별도의 메서드로 분리
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
                setState(() {
                  _hasPhotoPermission = true;
                  _isLoading = true;
                });
                // 권한을 처음 허용할 때는 즐겨찾기가 없음
                final galleryModel = Provider.of<GalleryModel>(
                  context,
                  listen: false,
                );
                await galleryModel.loadDevicePhotos([]);
                setState(() {
                  _isLoading = false;
                });
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
      appBar: AppBar(
        title:
            _isSelectMode
                ? Text('${_selectedPhotoIds.length}개 선택됨')
                : const Text('사진 갤러리'),
        actions: [
          if (_selectedIndex == 0 && _isSelectMode) ...[
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
            TextButton(onPressed: _exitSelectMode, child: const Text('취소')),
          ] else ...[
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed:
                  _hasPhotoPermission ? () => _refreshGallery(context) : null,
            ),
            if (_selectedIndex == 0)
              IconButton(
                icon: const Icon(Icons.select_all),
                onPressed: _enterSelectMode,
              ),
          ],
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _hasPhotoPermission
              ? _getCurrentScreen()
              : _buildPermissionScreen(),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).bottomNavigationBarTheme.backgroundColor,
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
                _buildNavItem(4, Icons.album, '앨범'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _selectedIndex == index;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (_selectedIndex != index) {
          setState(() {
            _selectedIndex = index;
            // 다른 화면으로 이동할 때 선택 모드와 선택된 이미지 초기화
            if (_isSelectMode) {
              _isSelectMode = false;
              _selectedPhotoIds.clear();
            }
          });
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.black12 : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
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
    // 리프레시 시에는 현재 즐겨찾기 목록 전달
    await galleryModel.loadDevicePhotos(
      galleryModel.favorites.map((p) => p.id).toList(),
    );

    setState(() {
      _isLoading = false;
    });
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

  // 선택된 사진 삭제 (GalleryModel 연동)
  Future<void> _deleteSelectedPhotos(BuildContext context) async {
    final galleryModel = Provider.of<GalleryModel>(context, listen: false);
    for (final photoId in _selectedPhotoIds) {
      await galleryModel.deletePhoto(photoId);
    }
    _exitSelectMode();
  }

  // 선택된 사진 앨범 추가 기능 구현
  void _addSelectedPhotosToAlbum(BuildContext context) async {
    final galleryModel = Provider.of<GalleryModel>(context, listen: false);
    final albums = galleryModel.albums;
    if (albums.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('먼저 앨범을 생성해주세요.')));
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '앨범에 추가',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Consumer<GalleryModel>(
                builder: (context, galleryModel, child) {
                  return ListView.builder(
                    shrinkWrap: true,
                    itemCount: albums.length + 1,
                    itemBuilder: (context, index) {
                      if (index == albums.length) {
                        return ListTile(
                          leading: const Icon(Icons.add),
                          title: const Text('새 앨범 만들기'),
                          onTap: () {
                            Navigator.pop(context);
                            showModalBottomSheet(
                              context: context,
                              backgroundColor: Colors.transparent,
                              isScrollControlled: true,
                              builder: (context) {
                                final textController = TextEditingController();
                                return Container(
                                  decoration: BoxDecoration(
                                    color:
                                        Theme.of(
                                          context,
                                        ).scaffoldBackgroundColor,
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(20),
                                    ),
                                  ),
                                  padding: EdgeInsets.only(
                                    bottom:
                                        MediaQuery.of(
                                          context,
                                        ).viewInsets.bottom,
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        margin: const EdgeInsets.only(top: 8),
                                        width: 40,
                                        height: 4,
                                        decoration: BoxDecoration(
                                          color: Colors.grey.withOpacity(0.3),
                                          borderRadius: BorderRadius.circular(
                                            2,
                                          ),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                          16,
                                          16,
                                          16,
                                          8,
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            const Text(
                                              '새 앨범 만들기',
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.close),
                                              onPressed:
                                                  () => Navigator.pop(context),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: TextField(
                                          controller: textController,
                                          autofocus: true,
                                          decoration: InputDecoration(
                                            hintText: '앨범 이름을 입력하세요',
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            filled: true,
                                            fillColor: Colors.grey.withOpacity(
                                              0.1,
                                            ),
                                          ),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.end,
                                          children: [
                                            TextButton(
                                              onPressed:
                                                  () => Navigator.pop(context),
                                              child: const Text('취소'),
                                            ),
                                            const SizedBox(width: 8),
                                            ElevatedButton(
                                              onPressed: () async {
                                                final name =
                                                    textController.text.trim();
                                                if (name.isNotEmpty) {
                                                  await galleryModel
                                                      .createAlbum(name);
                                                  final newAlbum =
                                                      galleryModel.albums.last;
                                                  for (final photoId
                                                      in _selectedPhotoIds) {
                                                    await galleryModel
                                                        .addPhotoToAlbum(
                                                          photoId,
                                                          newAlbum.id,
                                                        );
                                                  }
                                                  if (mounted) {
                                                    Navigator.pop(context);
                                                    _exitSelectMode();
                                                    ScaffoldMessenger.of(
                                                      context,
                                                    ).showSnackBar(
                                                      SnackBar(
                                                        content: Text(
                                                          '새 앨범 "$name"이(가) 생성되고 사진이 추가되었습니다.',
                                                        ),
                                                      ),
                                                    );
                                                  }
                                                }
                                              },
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    Theme.of(
                                                      context,
                                                    ).primaryColor,
                                                foregroundColor: Colors.white,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                              ),
                                              child: const Text('만들기'),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            );
                          },
                        );
                      }
                      final album = albums[index];
                      final isInAlbum = _selectedPhotoIds.every(
                        (photoId) =>
                            galleryModel.isPhotoInAlbum(photoId, album.id),
                      );
                      return ListTile(
                        leading: const Icon(Icons.photo_album),
                        title: Text(album.name),
                        trailing:
                            isInAlbum
                                ? const Icon(Icons.check, color: Colors.green)
                                : null,
                        onTap: () async {
                          for (final photoId in _selectedPhotoIds) {
                            if (isInAlbum) {
                              await galleryModel.removePhotoFromAlbum(
                                photoId,
                                album.id,
                              );
                            } else {
                              await galleryModel.addPhotoToAlbum(
                                photoId,
                                album.id,
                              );
                            }
                          }
                          if (mounted) {
                            Navigator.pop(context);
                            _exitSelectMode();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  isInAlbum
                                      ? '${album.name}에서 사진을 제거했습니다.'
                                      : '${album.name}에 사진을 추가했습니다.',
                                ),
                              ),
                            );
                          }
                        },
                      );
                    },
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // 선택된 사진들의 즐겨찾기 상태 토글
  void _toggleSelectedPhotosFavorite(BuildContext context) async {
    final galleryModel = Provider.of<GalleryModel>(context, listen: false);
    final photos = galleryModel.photos;

    // 선택된 사진들의 현재 즐겨찾기 상태 확인
    final selectedPhotos = photos.where(
      (photo) => _selectedPhotoIds.contains(photo.id),
    );
    final allFavorites = selectedPhotos.every((photo) => photo.isFavorite);

    // 선택된 사진 개수 저장
    final selectedCount = _selectedPhotoIds.length;

    // 모든 선택된 사진의 즐겨찾기 상태 토글
    for (final photo in selectedPhotos) {
      await galleryModel.toggleFavorite(photo.id);
    }

    // 작업 완료 후 선택 모드 종료
    _exitSelectMode();

    // 결과 메시지 표시
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
