import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:gallery_memo/model/gallery_model.dart';
import 'package:gallery_memo/model/photo_model.dart';
import 'package:gallery_memo/screen/album_screen.dart';
import 'package:gallery_memo/screen/device_album_screen.dart';
import 'package:provider/provider.dart';
import 'package:photo_manager/photo_manager.dart';

class AlbumsScreen extends StatefulWidget {
  const AlbumsScreen({super.key});

  @override
  State<AlbumsScreen> createState() => _AlbumsScreenState();
}

class _AlbumsScreenState extends State<AlbumsScreen>
    with AutomaticKeepAliveClientMixin {
  final Map<String, ImageProvider> _imageCache = {};
  final Map<String, Uint8List?> _thumbnailCache = {};
  static const int _maxCacheSize = 50;
  List<AssetPathEntity> _deviceAlbums = [];
  final Map<String, Photo?> _albumThumbnails = {};
  bool _isLoading = false;
  bool _isInitialized = false;
  GalleryModel? _galleryModel;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadDeviceAlbums();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // GalleryModel 참조를 안전하게 저장
    final galleryModel = Provider.of<GalleryModel>(context, listen: false);
    if (_galleryModel != galleryModel) {
      // 이전 리스너 제거
      _galleryModel?.removeListener(_onGalleryModelChanged);

      // 새로운 리스너 추가
      _galleryModel = galleryModel;
      _galleryModel?.addListener(_onGalleryModelChanged);
    }
  }

  @override
  void dispose() {
    // 저장된 참조를 사용하여 리스너 제거
    _galleryModel?.removeListener(_onGalleryModelChanged);
    super.dispose();
  }

  void _onGalleryModelChanged() {
    // 갤러리 모델이 변경되면 앨범 목록도 완전히 새로고침
    if (mounted && _galleryModel != null) {
      // 이미 로딩 중이면 무시
      if (_isLoading) {
        debugPrint('AlbumsScreen: 이미 로딩 중이므로 갤러리 모델 변경 무시');
        return;
      }

      debugPrint('AlbumsScreen: 갤러리 모델 변경 감지, 앨범 목록 새로고침 시작');
      debugPrint('AlbumsScreen: 현재 앨범 개수: ${_deviceAlbums.length}');

      // 앨범 목록을 완전히 새로고침
      setState(() {
        _isInitialized = false;
        _imageCache.clear();
        _thumbnailCache.clear();
        _albumThumbnails.clear();
        _deviceAlbums.clear();
      });

      debugPrint('AlbumsScreen: 앨범 목록 초기화 완료, 앨범 개수: ${_deviceAlbums.length}');

      // 즉시 로드 (지연 제거)
      if (mounted) {
        debugPrint('AlbumsScreen: _loadDeviceAlbums 즉시 호출');
        _loadDeviceAlbums();
      }
    }
  }

  Future<void> _loadDeviceAlbums() async {
    if (_isInitialized || _isLoading) {
      debugPrint('AlbumsScreen: _loadDeviceAlbums 중단 - 이미 초기화됨 또는 로딩 중');
      return;
    }

    debugPrint('AlbumsScreen: 기기 앨범 로딩 시작...');

    setState(() {
      _isLoading = true;
    });

    try {
      final galleryModel = Provider.of<GalleryModel>(context, listen: false);
      debugPrint('AlbumsScreen: GalleryModel.getDeviceAlbums() 호출 시작');
      _deviceAlbums = await galleryModel.getDeviceAlbums();
      debugPrint('AlbumsScreen: 로드된 기기 앨범 수: ${_deviceAlbums.length}');

      if (_deviceAlbums.isEmpty) {
        debugPrint('AlbumsScreen: 기기 앨범이 없습니다.');
        if (mounted) {
          setState(() {
            _isInitialized = true;
            _isLoading = false;
          });
        }
        return;
      }

      debugPrint('AlbumsScreen: 앨범 썸네일 로딩 시작...');
      // 각 앨범의 썸네일 로드
      for (var album in _deviceAlbums) {
        if (!mounted) break; // 위젯이 dispose된 경우 중단

        try {
          debugPrint('AlbumsScreen: 앨범 썸네일 로딩 중: ${album.name}');
          final thumbnail = await galleryModel.getDeviceAlbumThumbnail(album);
          if (mounted) {
            setState(() {
              _albumThumbnails[album.id] = thumbnail;
            });
            debugPrint('AlbumsScreen: 앨범 썸네일 로딩 완료: ${album.name}');
          }
        } catch (e) {
          debugPrint('AlbumsScreen: 앨범 썸네일 로드 실패: ${album.name} - $e');
        }
      }

      if (mounted) {
        setState(() {
          _isInitialized = true;
          _isLoading = false;
        });
        debugPrint('AlbumsScreen: 기기 앨범 로딩 완료 - 총 ${_deviceAlbums.length}개 앨범');
      }
    } catch (e) {
      debugPrint('AlbumsScreen: 기기 앨범 로딩 중 오류 발생: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        // 오류가 발생해도 초기화는 완료로 표시
        _isInitialized = true;
      }
    }
  }

  Future<ImageProvider> _getImageProvider(Photo photo) async {
    final cacheKey = photo.id;

    if (_imageCache.containsKey(cacheKey)) {
      return _imageCache[cacheKey]!;
    }

    // 캐시 크기 제한 확인
    if (_imageCache.length >= _maxCacheSize) {
      _imageCache.remove(_imageCache.keys.first);
    }

    ImageProvider imageProvider;

    if (photo.isVideo) {
      // 영상인 경우 썸네일 생성
      try {
        if (photo.asset != null) {
          final thumbnail = await photo.asset!.thumbnailDataWithSize(
            const ThumbnailSize(200, 200),
            quality: 80,
          );
          if (thumbnail != null) {
            imageProvider = MemoryImage(thumbnail);
          } else {
            // 썸네일 생성 실패 시 기본 아이콘
            imageProvider = const AssetImage('assets/logo/logo.png');
          }
        } else {
          imageProvider = const AssetImage('assets/logo/logo.png');
        }
      } catch (e) {
        debugPrint('영상 썸네일 생성 중 오류 발생: $e');
        imageProvider = const AssetImage('assets/logo/logo.png');
      }
    } else {
      // 이미지인 경우 FileImage 사용
      imageProvider = FileImage(File(photo.path));
    }

    _imageCache[cacheKey] = imageProvider;
    return imageProvider;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<GalleryModel>(
      builder: (context, galleryModel, child) {
        // 갤러리 모델이 변경되면 앨범 목록도 업데이트
        if (_galleryModel != galleryModel) {
          debugPrint('AlbumsScreen: GalleryModel 인스턴스 변경 감지');
          _galleryModel = galleryModel;
          _onGalleryModelChanged();
        }

        return Scaffold(
          body:
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _deviceAlbums.isEmpty
                  ? const Center(child: Text('기기 앨범이 없습니다.'))
                  : ListView.builder(
                    itemCount: _deviceAlbums.length,
                    itemBuilder: (context, index) {
                      final deviceAlbum = _deviceAlbums[index];
                      final thumbnail = _albumThumbnails[deviceAlbum.id];
                      final assetCount = deviceAlbum.assetCountAsync;

                      return ListTile(
                        leading:
                            thumbnail != null
                                ? SizedBox(
                                  width: 50,
                                  height: 50,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: FutureBuilder<ImageProvider>(
                                      future: _getImageProvider(thumbnail),
                                      builder: (context, snapshot) {
                                        if (snapshot.connectionState ==
                                            ConnectionState.waiting) {
                                          return Container(
                                            width: 50,
                                            height: 50,
                                            color: Colors.grey[300],
                                            child: const Center(
                                              child: SizedBox(
                                                width: 20,
                                                height: 20,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                    ),
                                              ),
                                            ),
                                          );
                                        }

                                        if (snapshot.hasError ||
                                            !snapshot.hasData) {
                                          return Container(
                                            width: 50,
                                            height: 50,
                                            color: Colors.grey,
                                            child: const Icon(
                                              Icons.photo_album,
                                            ),
                                          );
                                        }

                                        return Image(
                                          image: snapshot.data!,
                                          fit: BoxFit.cover,
                                          width: 50,
                                          height: 50,
                                          errorBuilder: (
                                            context,
                                            error,
                                            stackTrace,
                                          ) {
                                            return Container(
                                              width: 50,
                                              height: 50,
                                              color: Colors.grey,
                                              child: const Icon(
                                                Icons.photo_album,
                                              ),
                                            );
                                          },
                                        );
                                      },
                                    ),
                                  ),
                                )
                                : Container(
                                  width: 50,
                                  height: 50,
                                  color: Colors.grey,
                                  child: const Icon(Icons.photo_album),
                                ),
                        title: Text(deviceAlbum.name),
                        subtitle: FutureBuilder<int>(
                          future: assetCount,
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Text('로딩 중...');
                            }
                            return Text('${snapshot.data ?? 0}개의 사진');
                          },
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) =>
                                      DeviceAlbumScreen(album: deviceAlbum),
                            ),
                          );
                        },
                      );
                    },
                  ),
        );
      },
    );
  }

  void _showDeleteAlbumDialog(
    BuildContext context,
    GalleryModel galleryModel,
    String albumId,
    String albumName,
  ) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('앨범 삭제'),
          content: Text('"$albumName" 앨범을 삭제하시겠습니까?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () {
                galleryModel.deleteAlbum(albumId);
                Navigator.pop(context);
              },
              child: const Text('삭제'),
            ),
          ],
        );
      },
    );
  }

  void _showCreateAlbumDialog(BuildContext context, GalleryModel galleryModel) {
    final textController = TextEditingController();

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
                      '새 앨범 만들기',
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
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: textController,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: '앨범 이름을 입력하세요',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey.withOpacity(0.1),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('취소'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        final name = textController.text.trim();
                        if (name.isNotEmpty) {
                          galleryModel.createAlbum(name);
                          Navigator.pop(context);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
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
  }
}
