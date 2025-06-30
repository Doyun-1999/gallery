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

      // 편집된 이미지 데이터가 있으면 사용, 없으면 현재 화면 캡처
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
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        final capturedData = byteData?.buffer.asUint8List();
        if (capturedData == null) throw Exception('이미지 변환에 실패했습니다.');
        imageDataToSave = capturedData;
      }

      if (overwrite) {
        // 덮어쓰기
        await _imageFile.writeAsBytes(imageDataToSave);
        setState(() {
          _imageFile = File(_imageFile.path);
          _editedImageData = imageDataToSave;
        });
        await _loadImage();
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('이미지가 저장되었습니다.')));
        }
      } else {
        // 새 파일로 저장
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

          // 저장 성공 시 GalleryModel 새로고침
          if (success == true) {
            final galleryModel = Provider.of<GalleryModel>(
              context,
              listen: false,
            );
            await galleryModel.loadDevicePhotos([]);
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

      // 크롭 완료 후 저장 및 네비게이션 처리
      await _handleCropComplete();
    }
  }

  Future<void> _handleCropComplete() async {
    // 크롭된 이미지를 새 파일로 저장
    await _saveImage(false);

    // 저장 완료 후 홈 화면으로 가기 (두 번 pop)
    if (mounted) {
      Navigator.of(context).pop(); // 사진 보기 화면으로
      Navigator.of(context).pop(); // 홈 화면으로
    }
  }

  void _onPanStart(DragStartDetails details) {
    final box = _imageRenderBox;
    if (box == null) return;
    final localPosition = details.localPosition;

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
        }
      }
      setState(() => _cropRect = Rect.fromPoints(localPosition, localPosition));
    }
  }

  void _onPanUpdate(DragUpdateDetails details) {
    final box = _imageRenderBox;
    if (box == null) return;
    final localPosition = details.localPosition;

    final clampedPosition = Offset(
      localPosition.dx.clamp(0, box.size.width).toDouble(),
      localPosition.dy.clamp(0, box.size.height).toDouble(),
    );

    if (_isDrawing) {
      setState(() => _drawingPoints = [..._drawingPoints, clampedPosition]);
    } else if (_isCropping) {
      if (_activeHandleIndex != null) {
        _updateCropWithHandle(clampedPosition);
      } else if (_isMovingCropArea) {
        if (_panStartOffset == null) return;
        final delta = clampedPosition - _panStartOffset!;
        _moveCropArea(delta);
        _panStartOffset = clampedPosition;
      } else if (_cropRect != null) {
        setState(
          () =>
              _cropRect = Rect.fromPoints(_cropRect!.topLeft, clampedPosition),
        );
      }
    }
  }

  void _onPanEnd(DragEndDetails details) {
    if (_isDrawing) {
      setState(() => _drawingPoints = [..._drawingPoints, null]);
    } else if (_isCropping) {
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
    if (_initialCropRect == null || _activeHandleIndex == null) return;
    double left = _initialCropRect!.left;
    double top = _initialCropRect!.top;
    double right = _initialCropRect!.right;
    double bottom = _initialCropRect!.bottom;
    if ([0, 6, 7].contains(_activeHandleIndex)) left = localPosition.dx;
    if ([2, 3, 4].contains(_activeHandleIndex)) right = localPosition.dx;
    if ([0, 1, 2].contains(_activeHandleIndex)) top = localPosition.dy;
    if ([4, 5, 6].contains(_activeHandleIndex)) bottom = localPosition.dy;
    setState(() => _cropRect = Rect.fromLTRB(left, top, right, bottom));
  }

  void _moveCropArea(Offset delta) {
    if (_initialCropRect == null) return;
    final box = _imageRenderBox;
    if (box == null) return;

    final newRect = _initialCropRect!.shift(delta);
    double clampedLeft =
        newRect.left.clamp(0, box.size.width - newRect.width).toDouble();
    double clampedTop =
        newRect.top.clamp(0, box.size.height - newRect.height).toDouble();

    setState(() {
      _cropRect = Rect.fromLTWH(
        clampedLeft,
        clampedTop,
        newRect.width,
        newRect.height,
      );
      _initialCropRect = _cropRect;
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
    for (int i = 0; i < handles.length; i++) {
      if ((position - handles[i]).distance < 20.0) return i;
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
    // 그리기 모드일 경우, 그린 내용을 초기화할지 물어볼 수 있습니다. (선택적)
    if (_drawingPoints.isNotEmpty) {
      // 예: _drawingPoints.clear();
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
        // 🐛 [수정] 크롭 모드 시작 시 이미지 전체를 선택 영역으로 지정합니다.
        // 위젯이 그려진 후 RenderBox에 접근하기 위해 post-frame 콜백을 사용합니다.
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

  void _rotateImage() {
    setState(() {
      if (_isCropping) {
        _isCropping = false;
        _resetCropState();
      }
      _rotation = (_rotation + 90) % 360;
    });
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
          child: RepaintBoundary(
            key: _captureKey,
            child: RotatedBox(
              quarterTurns: (_rotation / 90).round(),
              child:
                  _editedImageData != null
                      ? GestureDetector(
                        onPanStart:
                            _isDrawing || _isCropping ? _onPanStart : null,
                        onPanUpdate:
                            _isDrawing || _isCropping ? _onPanUpdate : null,
                        onPanEnd: _isDrawing || _isCropping ? _onPanEnd : null,
                        behavior: HitTestBehavior.translucent,
                        child: Stack(
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
                                child: CustomPaint(
                                  painter: CropPainter(cropRect: _cropRect!),
                                ),
                              ),
                          ],
                        ),
                      )
                      : const CircularProgressIndicator(),
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
