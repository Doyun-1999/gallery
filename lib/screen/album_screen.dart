import 'dart:io';

import 'package:flutter/material.dart';
import 'package:gallery/model/gallery_model.dart';
import 'package:gallery/screen/photo_view_screen.dart';
import 'package:provider/provider.dart';

class AlbumScreen extends StatelessWidget {
  final String albumId;

  const AlbumScreen({super.key, required this.albumId});

  @override
  Widget build(BuildContext context) {
    return Consumer<GalleryModel>(
      builder: (context, galleryModel, child) {
        final album = galleryModel.albums.firstWhere((a) => a.id == albumId);
        final photos = galleryModel.getAlbumPhotos(albumId);

        return Scaffold(
          appBar: AppBar(title: Text(album.name)),
          body:
              photos.isEmpty
                  ? const Center(child: Text('No photos in this album'))
                  : GridView.builder(
                    padding: const EdgeInsets.all(8.0),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 8.0,
                          mainAxisSpacing: 8.0,
                        ),
                    itemCount: photos.length,
                    itemBuilder: (context, index) {
                      final photo = photos[index];
                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) => PhotoViewScreen(
                                    photoId: photo.id,
                                    source: PhotoViewSource.album,
                                    albumId: albumId,
                                  ),
                            ),
                          );
                        },
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.file(File(photo.path), fit: BoxFit.cover),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: Icon(
                                Icons.favorite,
                                color:
                                    photo.isFavorite
                                        ? Colors.red
                                        : Colors.transparent,
                                size: 20,
                              ),
                            ),
                            Positioned(
                              bottom: 4,
                              right: 4,
                              child: IconButton(
                                icon: const Icon(
                                  Icons.remove_circle,
                                  color: Colors.white,
                                ),
                                onPressed: () {
                                  galleryModel.removePhotoFromAlbum(
                                    photo.id,
                                    albumId,
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
        );
      },
    );
  }
}
