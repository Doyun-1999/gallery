import 'dart:io';

import 'package:flutter/material.dart';
import 'package:gallery/model/gallery_model.dart';
import 'package:gallery/screen/album_screen.dart';
import 'package:provider/provider.dart';

class AlbumsScreen extends StatelessWidget {
  const AlbumsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<GalleryModel>(
      builder: (context, galleryModel, child) {
        final albums = galleryModel.albums;

        return Scaffold(
          body:
              albums.isEmpty
                  ? const Center(child: Text('No albums yet. Create some!'))
                  : ListView.builder(
                    itemCount: albums.length,
                    itemBuilder: (context, index) {
                      final album = albums[index];
                      final albumPhotos = galleryModel.getAlbumPhotos(album.id);

                      return ListTile(
                        leading:
                            albumPhotos.isNotEmpty
                                ? SizedBox(
                                  width: 50,
                                  height: 50,
                                  child: Image.file(
                                    File(albumPhotos.first.path),
                                    fit: BoxFit.cover,
                                  ),
                                )
                                : Container(
                                  width: 50,
                                  height: 50,
                                  color: Colors.grey,
                                  child: const Icon(Icons.photo_album),
                                ),
                        title: Text(album.name),
                        subtitle: Text('${albumPhotos.length} photos'),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) => AlbumScreen(albumId: album.id),
                            ),
                          );
                        },
                        trailing: IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed:
                              () => _showDeleteAlbumDialog(
                                context,
                                galleryModel,
                                album.id,
                                album.name,
                              ),
                        ),
                      );
                    },
                  ),
          floatingActionButton: FloatingActionButton(
            child: const Icon(Icons.add),
            onPressed: () => _showCreateAlbumDialog(context, galleryModel),
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
          title: const Text('Delete Album'),
          content: Text('Are you sure you want to delete "$albumName"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                galleryModel.deleteAlbum(albumId);
                Navigator.pop(context);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  void _showCreateAlbumDialog(BuildContext context, GalleryModel galleryModel) {
    final textController = TextEditingController();

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
              onPressed: () {
                final name = textController.text.trim();
                if (name.isNotEmpty) {
                  galleryModel.createAlbum(name);
                  Navigator.pop(context);
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
