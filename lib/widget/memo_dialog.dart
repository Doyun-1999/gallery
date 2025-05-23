import 'package:flutter/material.dart';
import 'package:gallery_memo/model/photo_model.dart';
import 'package:record/record.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:provider/provider.dart';
import 'package:gallery_memo/model/gallery_model.dart';
import 'dart:async';

class MemoDialog extends StatefulWidget {
  final Photo photo;

  const MemoDialog({super.key, required this.photo});

  @override
  State<MemoDialog> createState() => _MemoDialogState();
}

class _MemoDialogState extends State<MemoDialog> {
  late final TextEditingController _textController;
  final _audioRecorder = AudioRecorder();
  late final AudioPlayer _audioPlayer;
  bool _isRecording = false;
  bool _isPlaying = false;
  String? _currentVoiceMemoPath;
  Duration _recordingDuration = Duration.zero;
  Timer? _recordingTimer;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.photo.memo);
    _audioPlayer = AudioPlayer();
    _currentVoiceMemoPath = widget.photo.voiceMemoPath;

    _audioPlayer.playerStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state.playing;
        });
      }
    });

    // 초기 음성 메모 duration 설정
    if (_currentVoiceMemoPath != null) {
      _initializeAudioDuration();
    }
  }

  Future<void> _initializeAudioDuration() async {
    if (_currentVoiceMemoPath != null) {
      try {
        await _audioPlayer.setFilePath(_currentVoiceMemoPath!);
        if (mounted) {
          setState(() {});
        }
      } catch (e) {
        // duration 초기화 실패 시 무시
      }
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    _recordingTimer?.cancel();
    super.dispose();
  }

  void _startRecordingTimer() {
    _recordingDuration = Duration.zero;
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _recordingDuration += const Duration(seconds: 1);
        });
      }
    });
  }

  void _stopRecordingTimer() {
    _recordingTimer?.cancel();
    _recordingTimer = null;
    _recordingDuration = Duration.zero;
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final appDir = await getApplicationDocumentsDirectory();
        final fileName =
            'voice_memo_${DateTime.now().millisecondsSinceEpoch}.m4a';
        final path = '${appDir.path}/$fileName';

        // 기존 파일이 있다면 삭제
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
        }

        // 디렉토리가 존재하는지 확인하고 생성
        final directory = Directory(appDir.path);
        if (!await directory.exists()) {
          await directory.create(recursive: true);
        }

        await _audioRecorder.start(
          const RecordConfig(
            encoder: AudioEncoder.aacLc,
            bitRate: 128000,
            sampleRate: 44100,
            numChannels: 1,
          ),
          path: path,
        );

        setState(() {
          _isRecording = true;
          _currentVoiceMemoPath = path;
        });
        _startRecordingTimer();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('녹음 시작 중 오류가 발생했습니다.')));
      }
    }
  }

  Future<void> _stopRecording() async {
    try {
      if (!_isRecording) {
        return;
      }

      final isRecording = await _audioRecorder.isRecording();
      if (!isRecording) {
        return;
      }

      _stopRecordingTimer();

      final path = await _audioRecorder.stop();

      if (path != null) {
        final file = File(path);
        int retryCount = 0;
        bool fileExists = false;
        while (retryCount < 5) {
          fileExists = await file.exists();
          if (fileExists) {
            break;
          }
          await Future.delayed(const Duration(milliseconds: 200));
          retryCount++;
        }

        if (fileExists) {
          final fileSize = await file.length();
          if (fileSize > 0) {
            try {
              await file.readAsBytes();
            } catch (e) {
              throw Exception('녹음 파일을 읽을 수 없습니다.');
            }

            if (mounted) {
              setState(() {
                _currentVoiceMemoPath = path;
                _isRecording = false;
              });
            }

            try {
              final galleryModel = Provider.of<GalleryModel>(
                context,
                listen: false,
              );
              await galleryModel.addVoiceMemo(widget.photo.id, path);
            } catch (e) {
              throw Exception('파일 경로 저장 중 오류가 발생했습니다.');
            }

            // 녹음 중지 후 duration 초기화
            await _initializeAudioDuration();

            await Future.delayed(const Duration(milliseconds: 1000));
            final finalFileExists = await file.exists();
            if (!finalFileExists) {
              throw Exception('녹음 파일이 저장되지 않았습니다.');
            }
          } else {
            throw Exception('녹음 파일이 비어 있습니다.');
          }
        } else {
          throw Exception('녹음 파일이 생성되지 않았습니다.');
        }
      } else {
        throw Exception('녹음 파일 경로를 가져올 수 없습니다.');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('녹음 중지 중 오류가 발생했습니다: ${e.toString()}')),
        );
        setState(() {
          _isRecording = false;
          _currentVoiceMemoPath = null;
        });
      }
    }
  }

  Future<void> _playVoiceMemo() async {
    if (_currentVoiceMemoPath == null) return;

    try {
      final file = File(_currentVoiceMemoPath!);
      if (!await file.exists()) {
        throw Exception('음성 메모 파일을 찾을 수 없습니다.');
      }

      final fileSize = await file.length();
      if (fileSize == 0) {
        throw Exception('음성 메모 파일이 비어 있습니다.');
      }

      try {
        await file.readAsBytes();
      } catch (e) {
        throw Exception('음성 메모 파일을 읽을 수 없습니다.');
      }

      if (_isPlaying) {
        await _audioPlayer.pause();
        setState(() {
          _isPlaying = false;
        });
      } else {
        if (!await file.exists()) {
          throw Exception('음성 메모 파일이 삭제되었습니다.');
        }

        await _audioPlayer.stop();
        await _audioPlayer.setFilePath(_currentVoiceMemoPath!);
        // `play()` 호출 후 완료될 때까지 기다린 다음 상태 업데이트
        await _audioPlayer.play().then((_) {
          if (mounted) {
            setState(() {
              _isPlaying = false;
            });
            // 재생 완료 후 명시적으로 stop 호출하여 리소스 정리 및 상태 초기화
            _audioPlayer.stop();
          }
        });
        // play()가 호출되면 즉시 _isPlaying을 true로 설정
        if (mounted) {
          setState(() {
            _isPlaying = true;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('음성 메모 재생 중 오류가 발생했습니다: ${e.toString()}')),
        );
        setState(() {
          _currentVoiceMemoPath = null;
          _isPlaying = false;
        });
      }
    }
  }

  Future<void> _deleteVoiceMemo() async {
    if (_currentVoiceMemoPath != null) {
      final file = File(_currentVoiceMemoPath!);
      if (await file.exists()) {
        await file.delete();
      }
      if (mounted) {
        setState(() {
          _currentVoiceMemoPath = null;
          _isPlaying = false;
        });
      }
      final galleryModel = Provider.of<GalleryModel>(context, listen: false);
      galleryModel.addVoiceMemo(widget.photo.id, '');
    }
  }

  Future<void> _showDeleteConfirmationDialog() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // 사용자가 다이얼로그 바깥을 터치해도 닫히지 않음
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('음성 메모 삭제'),
          content: const SingleChildScrollView(
            child: ListBody(children: <Widget>[Text('정말로 이 음성 메모를 삭제하시겠습니까?')]),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('취소'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('삭제'),
              onPressed: () {
                Navigator.of(context).pop(); // 다이얼로그 닫기
                _deleteVoiceMemo(); // 음성 메모 삭제 함수 호출
              },
            ),
          ],
        );
      },
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.9),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildDragHandle(),
          _buildHeader(),
          _buildMemoInput(),
          _buildMemoLengthIndicator(),
          _buildVoiceMemoControls(),
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildDragHandle() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.3),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            '메모',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildMemoInput() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        controller: _textController,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: '메모를 입력하세요',
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.white),
          ),
          filled: true,
          fillColor: Colors.white.withOpacity(0.1),
        ),
        maxLines: 3,
      ),
    );
  }

  Widget _buildMemoLengthIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(
        '${_textController.text.length}/100',
        style: TextStyle(
          color: _textController.text.length > 100 ? Colors.red : Colors.grey,
        ),
      ),
    );
  }

  Widget _buildVoiceMemoControls() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // 1. 음성 녹음 중일 때 : 음성 녹음 중지 버튼.
              if (_isRecording)
                IconButton(
                  icon: const Icon(Icons.stop),
                  onPressed: _stopRecording,
                  color: Colors.red,
                )
              // 2. 음성 녹음이 없을 때 (그리고 녹음 중이 아닐 때): 음성 녹음 버튼.
              else if (_currentVoiceMemoPath == null ||
                  _currentVoiceMemoPath!.isEmpty)
                IconButton(
                  icon: const Icon(Icons.mic),
                  onPressed: _startRecording,
                  color: Colors.white,
                )
              // 3. 음성 녹음이 있을 때 (그리고 녹음 중이 아닐 때): 재생, 삭제 버튼.
              else if (_currentVoiceMemoPath != null &&
                  _currentVoiceMemoPath!.isNotEmpty) ...[
                IconButton(
                  icon: Icon(
                    _isPlaying ? Icons.pause : Icons.play_arrow,
                    color: _isPlaying ? Colors.red : Colors.blue,
                  ),
                  onPressed: _playVoiceMemo,
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: _showDeleteConfirmationDialog,
                  color: Colors.red,
                ),
              ],
            ],
          ),
          // 음성 메모 정보 표시는 녹음 중이거나, 음성 메모가 있을 때만
          if (_isRecording ||
              (_currentVoiceMemoPath != null &&
                  _currentVoiceMemoPath!.isNotEmpty))
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.audiotrack,
                      color: Colors.white.withOpacity(0.7),
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _isRecording ? '녹음 중' : '음성 메모',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 1,
                      height: 12,
                      color: Colors.white.withOpacity(0.3),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatDuration(
                        _isRecording
                            ? _recordingDuration
                            : (_audioPlayer.duration ?? Duration.zero),
                      ),
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소', style: TextStyle(color: Colors.white70)),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () async {
              final memo = _textController.text;
              if (memo.length <= 100) {
                final galleryModel = Provider.of<GalleryModel>(
                  context,
                  listen: false,
                );
                await galleryModel.addMemo(widget.photo.id, memo);
                if (mounted) {
                  Navigator.pop(context);
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }
}
