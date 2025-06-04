import 'package:flutter/material.dart';

class PhotoMemoDisplay extends StatelessWidget {
  final String? memo;
  final String? voiceMemoPath;

  const PhotoMemoDisplay({super.key, this.memo, this.voiceMemoPath});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (memo?.isNotEmpty ?? false)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Color.alphaBlend(
                Colors.white.withAlpha(26),
                Colors.transparent,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.note, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    memo ?? '',
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
        if (voiceMemoPath != null && voiceMemoPath!.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Color.alphaBlend(
                Colors.white.withAlpha(26),
                Colors.transparent,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Icon(Icons.audiotrack, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text(
                  '음성 메모',
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
