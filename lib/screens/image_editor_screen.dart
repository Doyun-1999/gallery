import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:image_editor/image_editor.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';

class ImageEditorScreen extends StatefulWidget {
  final String imagePath;

  const ImageEditorScreen({Key? key, required this.imagePath})
    : super(key: key);

  @override
  State<ImageEditorScreen> createState() => _ImageEditorScreenState();
}

class _ImageEditorScreenState extends State<ImageEditorScreen> {
  late File _imageFile;
  double _rotation = 0.0;
  bool _isDrawing = false;
  List<Offset> _drawingPoints = [];
  bool _isCropping = false;
  Offset? _cropStart;
  Offset? _cropEnd;
  Uint8List? _editedImageData;
  Size? _imageSize;
  final GlobalKey _imageKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _imageFile = File(widget.imagePath);
    _editedImageData = _imageFile.readAsBytesSync();
    _loadImageSize();
  }

  Future<void> _loadImageSize() async {
    ui.decodeImageFromList(_editedImageData!, (ui.Image image) {
      setState(() {
        _imageSize = Size(image.width.toDouble(), image.height.toDouble());
      });
    });
  }

  Future<void> _saveImage(bool overwrite) async {
    try {
      if (_editedImageData == null) {
        throw Exception('편집된 이미지 데이터가 없습니다.');
      }

      if (overwrite) {
        // 덮어쓰기
        final directory = path.dirname(_imageFile.path);
        final tempPath = path.join(
          directory,
          'temp_${path.basename(_imageFile.path)}',
        );
        final tempFile = File(tempPath);

        // 임시 파일에 저장
        await tempFile.writeAsBytes(_editedImageData!);

        // 원본 파일 삭제
        if (await _imageFile.exists()) {
          await _imageFile.delete();
        }

        // 임시 파일을 원본 파일로 이동
        await tempFile.rename(_imageFile.path);

        setState(() {
          _imageFile = File(_imageFile.path);
        });

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('이미지가 저장되었습니다.')));
      } else {
        // 새 파일로 저장
        if (Platform.isIOS) {
          try {
            // iOS에서는 갤러리에 직접 저장
            final result = await ImageGallerySaver.saveImage(
              _editedImageData!,
              quality: 100,
              name:
                  'edited_${DateTime.now().millisecondsSinceEpoch}_${path.basename(widget.imagePath)}',
            );

            if (result['isSuccess'] == true) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('갤러리에 저장되었습니다.')));
            } else {
              throw Exception('갤러리 저장 실패: ${result['errorMessage']}');
            }
          } catch (e) {
            print('iOS 저장 실패 상세: $e');
            // iOS 저장 실패 시 앱 디렉토리에 저장 시도
            final directory = await getApplicationDocumentsDirectory();
            final timestamp = DateTime.now().millisecondsSinceEpoch;
            final fileName =
                'edited_${timestamp}_${path.basename(widget.imagePath)}';
            final newPath = path.join(directory.path, fileName);
            final newFile = File(newPath);
            await newFile.writeAsBytes(_editedImageData!);

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('앱 디렉토리에 저장되었습니다: $fileName')),
            );
          }
        } else {
          // Android에서는 앱 디렉토리에 저장
          final directory = await getApplicationDocumentsDirectory();
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final fileName =
              'edited_${timestamp}_${path.basename(widget.imagePath)}';
          final newPath = path.join(directory.path, fileName);
          final newFile = File(newPath);
          await newFile.writeAsBytes(_editedImageData!);

          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('새 파일로 저장되었습니다: $fileName')));
        }
      }
    } catch (e) {
      print('저장 실패 상세: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('저장 실패: $e')));
    }
  }

  Future<void> _cropImage() async {
    if (_cropStart == null || _cropEnd == null || _imageSize == null) return;

    try {
      final option = ImageEditorOption();

      // 화면 좌표를 이미지 좌표로 변환
      final imageBox =
          _imageKey.currentContext?.findRenderObject() as RenderBox?;
      if (imageBox == null) return;

      // 이미지가 화면에 표시된 영역 계산
      final screenSize = MediaQuery.of(context).size;
      final imageAspectRatio = _imageSize!.width / _imageSize!.height;
      final screenAspectRatio = screenSize.width / screenSize.height;

      double displayWidth, displayHeight;
      if (imageAspectRatio > screenAspectRatio) {
        displayWidth = screenSize.width;
        displayHeight = screenSize.width / imageAspectRatio;
      } else {
        displayHeight = screenSize.height;
        displayWidth = screenSize.height * imageAspectRatio;
      }

      // 이미지가 화면 중앙에 위치하도록 오프셋 계산
      final offsetX = (screenSize.width - displayWidth) / 2;
      final offsetY = (screenSize.height - displayHeight) / 2;

      // 크롭 영역을 이미지 좌표로 변환
      final cropRect = Rect.fromPoints(_cropStart!, _cropEnd!);
      final normalizedRect = Rect.fromLTWH(
        (cropRect.left - offsetX) * (_imageSize!.width / displayWidth),
        (cropRect.top - offsetY) * (_imageSize!.height / displayHeight),
        cropRect.width * (_imageSize!.width / displayWidth),
        cropRect.height * (_imageSize!.height / displayHeight),
      );

      // 이미지 경계를 벗어나지 않도록 조정
      final adjustedRect = Rect.fromLTWH(
        normalizedRect.left.clamp(0, _imageSize!.width),
        normalizedRect.top.clamp(0, _imageSize!.height),
        normalizedRect.width.clamp(0, _imageSize!.width - normalizedRect.left),
        normalizedRect.height.clamp(0, _imageSize!.height - normalizedRect.top),
      );

      option.addOption(
        ClipOption(
          x: adjustedRect.left.toInt(),
          y: adjustedRect.top.toInt(),
          width: adjustedRect.width.toInt(),
          height: adjustedRect.height.toInt(),
        ),
      );

      final result = await ImageEditor.editFileImage(
        file: _imageFile,
        imageEditorOption: option,
      );

      if (result != null) {
        setState(() {
          _editedImageData = result;
          _isCropping = false;
          _cropStart = null;
          _cropEnd = null;
        });
        _loadImageSize(); // 이미지 크기 다시 로드
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('이미지 자르기 실패: $e')));
      print('자르기 실패 상세: $e');
    }
  }

  Future<void> _rotateImage() async {
    try {
      final option = ImageEditorOption();
      option.addOption(const RotateOption(90));
      final result = await ImageEditor.editFileImage(
        file: _imageFile,
        imageEditorOption: option,
      );
      if (result != null) {
        setState(() {
          _editedImageData = result;
          _rotation = (_rotation + 90) % 360;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('이미지 회전 실패: $e')));
      print('회전 실패 상세: $e'); // 디버깅을 위한 로그
    }
  }

  void _toggleDrawing() {
    setState(() {
      _isDrawing = !_isDrawing;
      if (!_isDrawing) {
        _drawingPoints = [];
      }
    });
  }

  void _toggleCropping() {
    setState(() {
      _isCropping = !_isCropping;
      if (!_isCropping) {
        _cropStart = null;
        _cropEnd = null;
      }
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
                onPressed: () {
                  Navigator.pop(context);
                  _saveImage(true); // 덮어쓰기
                },
                child: const Text('덮어쓰기'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _saveImage(false); // 새 파일로 저장
                },
                child: const Text('새 파일로 저장'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('취소'),
              ),
            ],
          ),
    );
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
          IconButton(
            icon: const Icon(Icons.rotate_right),
            onPressed: _rotateImage,
          ),
          IconButton(
            icon: Icon(_isDrawing ? Icons.edit_off : Icons.edit),
            onPressed: _toggleDrawing,
          ),
          IconButton(icon: const Icon(Icons.save), onPressed: _showSaveDialog),
        ],
      ),
      body: GestureDetector(
        onPanStart:
            _isCropping
                ? (details) {
                  setState(() {
                    _cropStart = details.localPosition;
                    _cropEnd = details.localPosition;
                  });
                }
                : null,
        onPanUpdate:
            _isCropping
                ? (details) {
                  setState(() {
                    _cropEnd = details.localPosition;
                  });
                }
                : _isDrawing
                ? (details) {
                  setState(() {
                    _drawingPoints.add(details.localPosition);
                  });
                }
                : null,
        onPanEnd:
            _isCropping
                ? null
                : _isDrawing
                ? (details) {
                  setState(() {
                    _drawingPoints.add(Offset.infinite);
                  });
                }
                : null,
        child: Stack(
          children: [
            Center(
              child:
                  _editedImageData != null
                      ? Image.memory(
                        _editedImageData!,
                        fit: BoxFit.contain,
                        key: _imageKey,
                      )
                      : Image.file(
                        _imageFile,
                        fit: BoxFit.contain,
                        key: _imageKey,
                      ),
            ),
            if (_isDrawing)
              CustomPaint(
                painter: DrawingPainter(_drawingPoints),
                size: Size.infinite,
              ),
            if (_isCropping && _cropStart != null && _cropEnd != null)
              CustomPaint(
                painter: CropPainter(_cropStart!, _cropEnd!),
                size: Size.infinite,
              ),
          ],
        ),
      ),
    );
  }
}

class DrawingPainter extends CustomPainter {
  final List<Offset> points;

  DrawingPainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = Colors.red
          ..strokeWidth = 3.0
          ..strokeCap = StrokeCap.round;

    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != Offset.infinite && points[i + 1] != Offset.infinite) {
        canvas.drawLine(points[i], points[i + 1], paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class CropPainter extends CustomPainter {
  final Offset start;
  final Offset end;

  CropPainter(this.start, this.end);

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = Colors.white.withOpacity(0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0;

    final rect = Rect.fromPoints(start, end);
    canvas.drawRect(rect, paint);

    // 모서리 핸들 그리기
    final handlePaint =
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill;

    const handleRadius = 8.0;
    canvas.drawCircle(rect.topLeft, handleRadius, handlePaint);
    canvas.drawCircle(rect.topRight, handleRadius, handlePaint);
    canvas.drawCircle(rect.bottomLeft, handleRadius, handlePaint);
    canvas.drawCircle(rect.bottomRight, handleRadius, handlePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
