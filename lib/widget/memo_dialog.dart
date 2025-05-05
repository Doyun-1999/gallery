import 'package:flutter/material.dart';
import 'package:gallery/model/photo_model.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';
import 'package:gallery/model/gallery_model.dart';
import 'dart:async';

class MemoDialog extends StatefulWidget {
  final Photo photo;

  const MemoDialog({super.key, required this.photo});

  @override
  State<MemoDialog> createState() => _MemoDialogState();
}

class _MemoDialogState extends State<MemoDialog> {
  late final TextEditingController _textController;
  late final AudioPlayer _audioPlayer;
  late final StreamController<bool> _isPlayingController;
  late final StreamController<String> _memoLengthController;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.photo.memo);
    _audioPlayer = AudioPlayer();
    _isPlayingController = StreamController<bool>();
    _memoLengthController = StreamController<String>();

    _audioPlayer.playerStateStream.listen((state) {
      if (!_isPlayingController.isClosed) {
        _isPlayingController.add(state.playing);
      }
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _audioPlayer.dispose();
    _isPlayingController.close();
    _memoLengthController.close();
    super.dispose();
  }

  Future<void> _playVoiceMemo() async {
    try {
      if (_audioPlayer.playing) {
        await _audioPlayer.pause();
      } else {
        await _audioPlayer.setFilePath(widget.photo.voiceMemoPath!);
        await _audioPlayer.play();
      }
    } catch (e) {
      print('음성 메모 재생 중 오류 발생: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('음성 메모 재생 중 오류가 발생했습니다.')));
      }
    }
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
          if (widget.photo.voiceMemoPath != null) _buildVoiceMemoSection(),
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
        onChanged: (value) {
          if (!_memoLengthController.isClosed) {
            _memoLengthController.add(value);
          }
        },
      ),
    );
  }

  Widget _buildMemoLengthIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: StreamBuilder<String>(
        stream: _memoLengthController.stream,
        builder: (context, snapshot) {
          final length = snapshot.data?.length ?? 0;
          return Text(
            '$length/100',
            style: TextStyle(color: length > 100 ? Colors.red : Colors.grey),
          );
        },
      ),
    );
  }

  Widget _buildVoiceMemoSection() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          StreamBuilder<bool>(
            stream: _isPlayingController.stream,
            initialData: false,
            builder: (context, snapshot) {
              final isPlaying = snapshot.data ?? false;
              return IconButton(
                icon: Icon(
                  isPlaying ? Icons.pause : Icons.play_arrow,
                  color: isPlaying ? Colors.red : Colors.blue,
                ),
                onPressed: _playVoiceMemo,
              );
            },
          ),
          const Text('음성 메모', style: TextStyle(color: Colors.white)),
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
