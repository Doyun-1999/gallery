import 'dart:io';

import 'package:flutter/material.dart';
import 'package:gallery_memo/model/gallery_model.dart';
import 'package:gallery_memo/screen/albums_screen.dart';
import 'package:gallery_memo/screen/favorite_screen.dart';
import 'package:gallery_memo/screen/gallery_screen.dart';
import 'package:gallery_memo/utils/permission_manager.dart';
import 'package:image_picker/image_picker.dart';
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
  bool _isNavigating = false;

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
        return const GalleryScreen();
      case 1:
        return const FavoritesScreen();
      case 2:
        return const AlbumsScreen();
      default:
        return const GalleryScreen();
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

  void _handleNavigation(int index) {
    if (_isNavigating) return;
    if (_selectedIndex == index) return;

    setState(() {
      _isNavigating = true;
      _selectedIndex = index;
    });

    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        setState(() {
          _isNavigating = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('사진 갤러리'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed:
                _hasPhotoPermission ? () => _refreshGallery(context) : null,
          ),
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
                _buildNavItem(1, Icons.favorite, '즐겨찾기'),
                _buildNavItem(2, Icons.album, '앨범'),
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
}
