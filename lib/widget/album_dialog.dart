import 'package:flutter/material.dart';
import 'package:gallery_memo/model/gallery_model.dart';
import 'package:provider/provider.dart';

class AlbumDialog extends StatelessWidget {
  final String photoId;

  const AlbumDialog({super.key, required this.photoId});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add to Album'),
      content: SizedBox(
        width: double.maxFinite,
        child: Consumer<GalleryModel>(
          builder: (context, galleryModel, child) {
            return ListView.builder(
              shrinkWrap: true,
              itemCount: galleryModel.albums.length,
              itemBuilder: (context, index) {
                final album = galleryModel.albums[index];
                final bool isInAlbum = album.photoIds.contains(photoId);

                return ListTile(
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
                    Navigator.pop(context);
                  },
                );
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
        TextButton(
          onPressed: () => _showCreateAlbumDialog(context),
          child: const Text('Create New Album'),
        ),
      ],
    );
  }

  void _showCreateAlbumDialog(BuildContext context) {
    final textController = TextEditingController();
    final galleryModel = Provider.of<GalleryModel>(context, listen: false);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Create New Album'),
          content: TextField(
            controller: textController,
            decoration: const InputDecoration(labelText: 'Album Name'),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                final name = textController.text.trim();
                if (name.isNotEmpty) {
                  await galleryModel.createAlbum(name);
                  final albumId = galleryModel.albums.last.id;
                  await galleryModel.addPhotoToAlbum(photoId, albumId);
                  Navigator.pop(context);
                  Navigator.pop(context); // Close both dialogs
                }
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  }
}
