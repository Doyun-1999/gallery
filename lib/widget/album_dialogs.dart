import 'package:flutter/material.dart';
import 'package:gallery_memo/model/gallery_model.dart';
import 'package:provider/provider.dart';

class AddToAlbumDialog extends StatelessWidget {
  final String photoId;

  const AddToAlbumDialog({super.key, required this.photoId});

  @override
  Widget build(BuildContext context) {
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
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
              final albums = galleryModel.albums;
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
                          builder:
                              (context) => CreateAlbumDialog(photoId: photoId),
                        );
                      },
                    );
                  }
                  final album = albums[index];
                  final isInAlbum = galleryModel.isPhotoInAlbum(
                    photoId,
                    album.id,
                  );
                  return ListTile(
                    leading: const Icon(Icons.photo_album),
                    title: Text(album.name),
                    trailing:
                        isInAlbum
                            ? const Icon(Icons.check, color: Colors.green)
                            : null,
                    onTap: () {
                      if (isInAlbum) {
                        galleryModel.removePhotoFromAlbum(photoId, album.id);
                      } else {
                        galleryModel.addPhotoToAlbum(photoId, album.id);
                      }
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            isInAlbum
                                ? '${album.name}에서 사진을 제거했습니다.'
                                : '${album.name}에 사진을 추가했습니다.',
                          ),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class CreateAlbumDialog extends StatefulWidget {
  final String photoId;

  const CreateAlbumDialog({super.key, required this.photoId});

  @override
  State<CreateAlbumDialog> createState() => _CreateAlbumDialogState();
}

class _CreateAlbumDialogState extends State<CreateAlbumDialog> {
  final textController = TextEditingController();

  @override
  void dispose() {
    textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                  onPressed: () async {
                    final name = textController.text.trim();
                    if (name.isNotEmpty) {
                      final galleryModel = Provider.of<GalleryModel>(
                        context,
                        listen: false,
                      );
                      await galleryModel.createAlbum(name);
                      final albumId = galleryModel.albums.last.id;
                      await galleryModel.addPhotoToAlbum(
                        widget.photoId,
                        albumId,
                      );
                      if (mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('새 앨범이 생성되고 사진이 추가되었습니다.'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
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
  }
}
