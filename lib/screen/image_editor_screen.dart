import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:image_editor/image_editor.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:gallery_saver/gallery_saver.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:gallery_memo/model/gallery_model.dart';

class ImageEditorScreen extends StatefulWidget {
  final String imagePath;

  const ImageEditorScreen({super.key, required this.imagePath});

  @override
  State<ImageEditorScreen> createState() => _ImageEditorScreenState();
}

class _ImageEditorScreenState extends State<ImageEditorScreen> {
  late File _imageFile;
  double _rotation = 0.0;
  bool _isDrawing = false;
  List<Offset?> _drawingPoints = [];

  // --- 크롭 관련 상태 변수 ---
  bool _isCropping = false;
  Rect? _cropRect;

  // --- 핸들 및 영역 이동 관련 상태 변수 ---
  int? _activeHandleIndex;
  bool _isMovingCropArea = false;
  Offset? _panStartOffset;
  Rect? _initialCropRect;

  // --- GlobalKeys ---
  final GlobalKey _imageKey = GlobalKey();
  final GlobalKey _captureKey = GlobalKey();

  // --- 원본 이미지 정보 ---
  Size? _originalImageSize;
  Uint8List? _editedImageData;

  // --- Getters for convenience ---
  RenderBox? get _imageRenderBox =>
      _imageKey.currentContext?.findRenderObject() as RenderBox?;

  @override
  void initState() {
    super.initState();
    _imageFile = File(widget.imagePath);
    _editedImageData = _imageFile.readAsBytesSync();
    _loadImage();
  }

  Future<void> _loadImage() async {
    if (_editedImageData == null) return;
    final codec = await ui.instantiateImageCodec(_editedImageData!);
    final frame = await codec.getNextFrame();
    if (!mounted) return;
    setState(() {
      _originalImageSize = Size(
        frame.image.width.toDouble(),
        frame.image.height.toDouble(),
      );
    });
  }

  Future<void> _saveImage(bool overwrite) async {
    try {
      Uint8List imageDataToSave;

      // 회전이나 그림 그리기가 적용된 경우 화면 캡처를 사용
      if (_rotation != 0.0 || _drawingPoints.isNotEmpty) {
        final boundary =
            _captureKey.currentContext?.findRenderObject()
                as RenderRepaintBoundary?;
        if (boundary == null) throw Exception('화면을 캡처할 수 없습니다.');
        final image = await boundary.toImage(
          pixelRatio: ui.window.devicePixelRatio,
        );
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        final capturedData = byteData?.buffer.asUint8List();
        if (capturedData == null) throw Exception('이미지 변환에 실패했습니다.');
        imageDataToSave = capturedData;
      } else {
        // 회전이나 그림 그리기가 없는 경우 기존 데이터 사용
        if (_editedImageData != null) {
          imageDataToSave = _editedImageData!;
        } else {
          final boundary =
              _captureKey.currentContext?.findRenderObject()
                  as RenderRepaintBoundary?;
          if (boundary == null) throw Exception('화면을 캡처할 수 없습니다.');
          final image = await boundary.toImage(
            pixelRatio: ui.window.devicePixelRatio,
          );
          final byteData = await image.toByteData(
            format: ui.ImageByteFormat.png,
          );
          final capturedData = byteData?.buffer.asUint8List();
          if (capturedData == null) throw Exception('이미지 변환에 실패했습니다.');
          imageDataToSave = capturedData;
        }
      }

      if (overwrite) {
        try {
          // 파일이 존재하는지 확인
          if (!await _imageFile.exists()) {
            throw Exception('원본 파일을 찾을 수 없습니다.');
          }

          // 파일을 직접 덮어쓰기
          await _imageFile.writeAsBytes(imageDataToSave);

          // 파일 메타데이터 업데이트 (갤러리 시스템에 변경사항 알림)
          try {
            await _imageFile.setLastModified(DateTime.now());
          } catch (e) {
            debugPrint('파일 메타데이터 업데이트 실패 (무시): $e');
          }

          setState(() {
            _imageFile = File(_imageFile.path);
            _editedImageData = imageDataToSave;
          });
          await _loadImage();

          // 갤러리 모델 새로고침 - 변경된 파일이 갤러리에 반영되도록
          final galleryModel = Provider.of<GalleryModel>(
            context,
            listen: false,
          );
          await galleryModel.refreshGallery();

          // 변경된 파일의 ImageCache 제거 (더 확실한 반영을 위해)
          try {
            // 기본 FileImage 캐시 제거
            final imageProvider = FileImage(_imageFile);
            PaintingBinding.instance.imageCache.evict(imageProvider);

            // ResizeImage 캐시도 제거 (gallery_screen에서 사용하는 형태)
            final resizeImageProvider = ResizeImage(
              imageProvider,
              width: 200,
              allowUpscaling: false,
              policy: ResizeImagePolicy.fit,
            );
            PaintingBinding.instance.imageCache.evict(resizeImageProvider);
          } catch (e) {
            debugPrint('이미지 캐시 제거 실패 (무시): $e');
          }

          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('이미지가 저장되었습니다.')));
            // 저장 후 이전 화면으로 돌아가기 (두 번 pop)
            Navigator.of(context).pop();
            Navigator.of(context).pop();
          }
        } catch (e) {
          debugPrint('덮어쓰기 실패: $e');
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('덮어쓰기 실패: $e')));
          }
        }
      } else {
        final tempDir = await getTemporaryDirectory();
        final fileName = 'edited_${DateTime.now().millisecondsSinceEpoch}.png';
        final tempFile = await File(
          path.join(tempDir.path, fileName),
        ).writeAsBytes(imageDataToSave);
        final success = await GallerySaver.saveImage(tempFile.path);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                success == true ? '갤러리에 저장되었습니다.' : '갤러리 저장에 실패했습니다.',
              ),
            ),
          );

          if (success == true) {
            final galleryModel = Provider.of<GalleryModel>(
              context,
              listen: false,
            );
            // refreshGallery를 사용하여 앨범 캐시도 함께 초기화
            await galleryModel.refreshGallery();
            // 저장 후 이전 화면으로 돌아가기 (두 번 pop)
            Navigator.of(context).pop();
            Navigator.of(context).pop();
          }
        }
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('저장 실패: $e')));
    }
  }

  Future<void> _cropImage() async {
    if (_cropRect == null || _originalImageSize == null) return;
    final displayedSize = _imageRenderBox?.size;
    if (displayedSize == null || displayedSize.isEmpty) return;

    final scaleX = _originalImageSize!.width / displayedSize.width;
    final scaleY = _originalImageSize!.height / displayedSize.height;

    final finalCropRect = Rect.fromLTWH(
      _cropRect!.left * scaleX,
      _cropRect!.top * scaleY,
      _cropRect!.width * scaleX,
      _cropRect!.height * scaleY,
    );

    final option =
        ImageEditorOption()..addOption(ClipOption.fromRect(finalCropRect));
    final result = await ImageEditor.editFileImage(
      file: _imageFile,
      imageEditorOption: option,
    );

    if (result != null) {
      setState(() {
        _editedImageData = result;
        _isCropping = false;
        _resetCropState();
      });
      await _loadImage();
      await _handleCropComplete();
    }
  }

  Future<void> _handleCropComplete() async {
    await _saveImage(false);
  }

  void _onPanStart(DragStartDetails details) {
    final box = _imageRenderBox;
    if (box == null || !box.hasSize) return;

    final localPosition = box.globalToLocal(details.globalPosition);

    if (_isDrawing) {
      setState(() => _drawingPoints = [..._drawingPoints, localPosition]);
    } else if (_isCropping) {
      if (_cropRect != null) {
        final handleIndex = _getHandleIndex(localPosition, _cropRect!);
        if (handleIndex != null) {
          setState(() {
            _activeHandleIndex = handleIndex;
            _panStartOffset = localPosition;
            _initialCropRect = _cropRect;
          });
          return;
        } else if (_cropRect!.contains(localPosition)) {
          setState(() {
            _isMovingCropArea = true;
            _panStartOffset = localPosition;
            _initialCropRect = _cropRect;
          });
          return;
        } else {
          // 크롭 영역 바깥 클릭 시 아무 동작도 하지 않음
          return;
        }
      }
      // 크롭 영역이 없을 때만 새로 생성
      final clampedPosition = Offset(
        localPosition.dx.clamp(0, box.size.width),
        localPosition.dy.clamp(0, box.size.height),
      );
      setState(
        () => _cropRect = Rect.fromPoints(clampedPosition, clampedPosition),
      );
    }
  }

  void _onPanUpdate(DragUpdateDetails details) {
    final box = _imageRenderBox;
    if (box == null || !box.hasSize) return;

    final localPosition = box.globalToLocal(details.globalPosition);

    if (_isDrawing) {
      final clampedPosition = Offset(
        localPosition.dx.clamp(0, box.size.width),
        localPosition.dy.clamp(0, box.size.height),
      );
      setState(() => _drawingPoints = [..._drawingPoints, clampedPosition]);
    } else if (_isCropping) {
      // 크롭 영역 조정/이동 상태가 아닐 때는 무시
      if (_activeHandleIndex != null) {
        _updateCropWithHandle(localPosition);
      } else if (_isMovingCropArea) {
        if (_panStartOffset == null || _initialCropRect == null) return;
        final delta = localPosition - _panStartOffset!;
        _moveCropArea(delta);
      } else {
        // 크롭 영역 조정/이동 상태가 아니면 아무 동작도 하지 않음
        return;
      }
    }
  }

  void _onPanEnd(DragEndDetails details) {
    if (_isDrawing) {
      setState(() => _drawingPoints = [..._drawingPoints, null]);
    } else if (_isCropping) {
      // 크롭 영역 조정/이동 상태가 아닐 때는 무시
      if (_activeHandleIndex == null && !_isMovingCropArea) return;
      if (_cropRect != null) {
        setState(() => _cropRect = _normalizeRect(_cropRect!));
      }
      setState(() {
        _activeHandleIndex = null;
        _isMovingCropArea = false;
        _panStartOffset = null;
        _initialCropRect = null;
      });
    }
  }

  void _updateCropWithHandle(Offset localPosition) {
    final box = _imageRenderBox;
    if (_initialCropRect == null ||
        _activeHandleIndex == null ||
        box == null ||
        !box.hasSize)
      return;

    // ✨ [수정] 핸들의 위치를 이미지 영역 안으로 강제로 제한합니다.
    final clampedPosition = Offset(
      localPosition.dx.clamp(0.0, box.size.width),
      localPosition.dy.clamp(0.0, box.size.height),
    );

    double left = _initialCropRect!.left;
    double top = _initialCropRect!.top;
    double right = _initialCropRect!.right;
    double bottom = _initialCropRect!.bottom;

    // 제한된 좌표(clampedPosition)를 사용하여 핸들 위치를 업데이트합니다.
    if ([0, 6, 7].contains(_activeHandleIndex)) left = clampedPosition.dx;
    if ([2, 3, 4].contains(_activeHandleIndex)) right = clampedPosition.dx;
    if ([0, 1, 2].contains(_activeHandleIndex)) top = clampedPosition.dy;
    if ([4, 5, 6].contains(_activeHandleIndex)) bottom = clampedPosition.dy;

    setState(() => _cropRect = Rect.fromLTRB(left, top, right, bottom));
  }

  void _moveCropArea(Offset delta) {
    if (_initialCropRect == null) return;
    final box = _imageRenderBox;
    if (box == null || !box.hasSize) return;

    final newRect = _initialCropRect!.shift(delta);

    // 크롭 영역이 이미지보다 크지 않도록 제한
    final double cropWidth = newRect.width.clamp(0.0, box.size.width);
    final double cropHeight = newRect.height.clamp(0.0, box.size.height);

    // clamp의 최대값이 0보다 작으면 0으로 고정
    final double maxLeft = (box.size.width - cropWidth).clamp(
      0.0,
      double.infinity,
    );
    final double maxTop = (box.size.height - cropHeight).clamp(
      0.0,
      double.infinity,
    );

    final double clampedLeft = newRect.left.clamp(0.0, maxLeft);
    final double clampedTop = newRect.top.clamp(0.0, maxTop);

    setState(() {
      _cropRect = Rect.fromLTWH(clampedLeft, clampedTop, cropWidth, cropHeight);
    });
  }

  List<Offset> _getHandlePositions(Rect rect) {
    return [
      rect.topLeft,
      rect.topCenter,
      rect.topRight,
      rect.centerRight,
      rect.bottomRight,
      rect.bottomCenter,
      rect.bottomLeft,
      rect.centerLeft,
    ];
  }

  int? _getHandleIndex(Offset position, Rect rect) {
    final handles = _getHandlePositions(rect);
    const handleHitboxSize = 20.0;
    for (int i = 0; i < handles.length; i++) {
      if ((position - handles[i]).distance < handleHitboxSize) return i;
    }
    return null;
  }

  Rect _normalizeRect(Rect rect) {
    return Rect.fromLTRB(
      min(rect.left, rect.right),
      min(rect.top, rect.bottom),
      max(rect.left, rect.right),
      max(rect.top, rect.bottom),
    );
  }

  void _resetCropState() {
    setState(() {
      _cropRect = null;
      _activeHandleIndex = null;
      _isMovingCropArea = false;
      _panStartOffset = null;
      _initialCropRect = null;
    });
  }

  void _toggleCropping() {
    if (_drawingPoints.isNotEmpty) {
      // _drawingPoints.clear();
    }
    if (_rotation != 0.0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('회전을 초기화한 후 잘라주세요.')));
      return;
    }
    setState(() {
      _isCropping = !_isCropping;
      _isDrawing = false;
      if (!_isCropping) {
        _resetCropState();
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final box = _imageRenderBox;
          if (box != null && box.hasSize) {
            setState(() {
              _cropRect = Offset.zero & box.size;
            });
          }
        });
      }
    });
  }

  void _toggleDrawing() {
    setState(() {
      _isDrawing = !_isDrawing;
      _isCropping = false;
      _resetCropState();
    });
  }

  void _clearDrawing() {
    setState(() {
      _drawingPoints.clear();
    });
  }

  void _rotateImage() async {
    setState(() {
      if (_isCropping) {
        _isCropping = false;
        _resetCropState();
      }
      _rotation = (_rotation + 90) % 360;
    });

    // 그림이 그려진 상태에서 회전하는 경우, 그림을 이미지에 적용 후 회전
    if (_drawingPoints.isNotEmpty) {
      await _applyDrawingToImage();
    }

    // 실제 이미지 데이터에 회전 적용
    if (_editedImageData != null) {
      try {
        final option = ImageEditorOption()..addOption(RotateOption(90));

        final tempDir = await getTemporaryDirectory();
        final tempFile = File(path.join(tempDir.path, 'temp_rotate.png'));
        await tempFile.writeAsBytes(_editedImageData!);

        final result = await ImageEditor.editFileImage(
          file: tempFile,
          imageEditorOption: option,
        );

        if (result != null) {
          setState(() {
            _editedImageData = result;
            _rotation = 0.0; // UI 회전은 초기화
            _drawingPoints.clear(); // 그림 그리기 초기화
          });
          await _loadImage();
        }

        // 임시 파일 삭제
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      } catch (e) {
        debugPrint('회전 처리 중 오류 발생: $e');
        // 오류 발생 시 UI 회전만 유지
      }
    }
  }

  Future<void> _applyDrawingToImage() async {
    if (_drawingPoints.isEmpty || _editedImageData == null) return;

    try {
      // 현재 화면을 캡처하여 그림이 포함된 이미지 생성
      final boundary =
          _captureKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) throw Exception('화면을 캡처할 수 없습니다.');

      final image = await boundary.toImage(
        pixelRatio: ui.window.devicePixelRatio,
      );
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final capturedData = byteData?.buffer.asUint8List();

      if (capturedData != null) {
        setState(() {
          _editedImageData = capturedData;
        });
      }
    } catch (e) {
      debugPrint('그림 적용 중 오류 발생: $e');
    }
  }

  void _showSaveDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('저장 옵션'),
            content: const Text('이미지를 어떻게 저장하시겠습니까?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('덮어쓰기'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('새 파일로 저장'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('취소'),
              ),
            ],
          ),
    ).then((value) {
      if (value == true) _saveImage(true);
      if (value == false) _saveImage(false);
    });
  }

  @override
  Widget build(BuildContext context) {
    const double cropModeScale = 0.8;
    return Scaffold(
      appBar: AppBar(
        title: const Text('이미지 편집'),
        actions: [
          IconButton(
            icon: Icon(_isCropping ? Icons.check : Icons.crop),
            onPressed: _isCropping ? _cropImage : _toggleCropping,
          ),
          if (!_isCropping) ...[
            IconButton(
              icon: const Icon(Icons.rotate_right),
              onPressed: _rotateImage,
            ),
            IconButton(
              icon: Icon(_isDrawing ? Icons.edit_off : Icons.edit),
              onPressed: _toggleDrawing,
            ),
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _showSaveDialog,
            ),
          ],
        ],
      ),
      body: Container(
        color: Colors.black,
        child: Center(
          child: GestureDetector(
            onPanStart: _isDrawing || _isCropping ? _onPanStart : null,
            onPanUpdate: _isDrawing || _isCropping ? _onPanUpdate : null,
            onPanEnd: _isDrawing || _isCropping ? _onPanEnd : null,
            behavior: HitTestBehavior.translucent,
            child: RepaintBoundary(
              key: _captureKey,
              child: AnimatedScale(
                scale: _isCropping ? cropModeScale : 1.0,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                child: RotatedBox(
                  quarterTurns: (_rotation / 90).round(),
                  child:
                      _editedImageData != null
                          ? Stack(
                            fit: StackFit.passthrough,
                            alignment: Alignment.center,
                            children: [
                              Image.memory(
                                _editedImageData!,
                                key: _imageKey,
                                fit: BoxFit.contain,
                              ),
                              if (_isDrawing)
                                Positioned.fill(
                                  child: CustomPaint(
                                    painter: DrawingPainter(
                                      points: _drawingPoints,
                                    ),
                                  ),
                                ),
                              if (_isCropping && _cropRect != null)
                                Positioned.fill(
                                  child: IgnorePointer(
                                    child: CustomPaint(
                                      painter: CropPainter(
                                        cropRect: _cropRect!,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          )
                          : const CircularProgressIndicator(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class DrawingPainter extends CustomPainter {
  final List<Offset?> points;
  DrawingPainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = Colors.red
          ..strokeWidth = 3.0
          ..strokeCap = StrokeCap.round;
    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != null && points[i + 1] != null) {
        canvas.drawLine(points[i]!, points[i + 1]!, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant DrawingPainter oldDelegate) {
    return oldDelegate.points != points;
  }
}

class CropPainter extends CustomPainter {
  final Rect cropRect;

  CropPainter({required this.cropRect});

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPaint = Paint()..color = Colors.black.withOpacity(0.5);

    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height)),
        Path()..addRect(cropRect),
      ),
      backgroundPaint,
    );

    final borderPaint =
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0;
    canvas.drawRect(cropRect, borderPaint);

    final handlePaint =
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill;
    const handleRadius = 8.0;

    final handles = [
      cropRect.topLeft,
      cropRect.topCenter,
      cropRect.topRight,
      cropRect.centerRight,
      cropRect.bottomRight,
      cropRect.bottomCenter,
      cropRect.bottomLeft,
      cropRect.centerLeft,
    ];

    for (final handle in handles) {
      canvas.drawCircle(handle, handleRadius, handlePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CropPainter oldDelegate) {
    return oldDelegate.cropRect != cropRect;
  }
}
