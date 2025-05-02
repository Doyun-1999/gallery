import 'dart:io';

import 'package:flutter/material.dart';
import 'package:gallery/model/gallery_model.dart';
import 'package:gallery/screen/albums_screen.dart';
import 'package:gallery/screen/favorite_screen.dart';
import 'package:gallery/screen/gallery_screen.dart';
import 'package:gallery/utils/permission_manager.dart';
import 'package:image_picker/image_picker.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  bool _hasPhotoPermission = false;
  bool _isLoading = true;

  final List<Widget> _screens = [
    const GalleryScreen(),
    const FavoritesScreen(),
    const AlbumsScreen(),
  ];

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
        });

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Photo Gallery'),
        actions: [
          IconButton(
            icon: const Icon(Icons.camera_alt),
            onPressed: () => _takePhoto(context),
          ),
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
              ? _screens[_selectedIndex]
              : Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.no_photography,
                      size: 80,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      '사진 접근 권한이 필요합니다',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
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
                            await PermissionManager.requestPhotoPermission(
                              context,
                            );
                        if (hasPermission) {
                          setState(() {
                            _hasPhotoPermission = true;
                            _isLoading = true;
                          });
                          // 권한을 처음 허용할 때는 즐겨찾기가 없음
                          await Provider.of<GalleryModel>(
                            context,
                            listen: false,
                          ).loadDevicePhotos([]);
                          setState(() {
                            _isLoading = false;
                          });
                        }
                      },
                      child: const Text('권한 허용하기'),
                    ),
                  ],
                ),
              ),
      bottomNavigationBar:
          _hasPhotoPermission
              ? BottomNavigationBar(
                currentIndex: _selectedIndex,
                onTap: (index) {
                  setState(() {
                    _selectedIndex = index;
                  });
                },
                items: [
                  BottomNavigationBarItem(
                    icon: Icon(Icons.photo_library),
                    label: 'Gallery',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.favorite),
                    label: 'Favorites',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.album),
                    label: 'Albums',
                  ),
                ],
              )
              : null,
    );
  }

  Future<void> _takePhoto(BuildContext context) async {
    final hasPermission = await PermissionManager.requestCameraPermission(
      context,
    );

    if (hasPermission) {
      final picker = ImagePicker();
      final imageFile = await picker.pickImage(source: ImageSource.camera);

      if (imageFile != null) {
        await Provider.of<GalleryModel>(
          context,
          listen: false,
        ).addPhoto(File(imageFile.path));
      }
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('카메라 접근 권한이 필요합니다.')));
    }
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
