import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import '../providers/photos_provider.dart';
import '../../../rust/db/models.dart';

class SessionGalleryWidget extends ConsumerWidget {
  final int sessionId;
  final int pacienteId;

  const SessionGalleryWidget({
    super.key,
    required this.sessionId,
    required this.pacienteId,
  });

  Future<void> _pickPhoto(BuildContext context, WidgetRef ref) async {
    final result = await FilePicker.pickFiles(
      type: FileType.image,
    );

    if (result.isNotEmpty && result.first.path != null) {
      final path = result.first.path!;
      
      String? selectedTipo;
      String? description;
      
      if (!context.mounted) return;
      
      final saved = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Detalles de la foto'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Tipo'),
                  items: const [
                    DropdownMenuItem(value: 'antes', child: Text('Antes')),
                    DropdownMenuItem(value: 'despues', child: Text('Después')),
                    DropdownMenuItem(value: 'durante', child: Text('Durante')),
                    DropdownMenuItem(value: 'otra', child: Text('Otra')),
                  ],
                  onChanged: (val) => selectedTipo = val,
                ),
                TextField(
                  decoration: const InputDecoration(labelText: 'Descripción (Opcional)'),
                  onChanged: (val) => description = val,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Guardar'),
              ),
            ],
          );
        }
      );

      if (saved == true && context.mounted) {
        try {
          await ref.read(sessionPhotosProvider(sessionId).notifier).addPhoto(
            pacienteId, path, selectedTipo, description,
          );
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Foto agregada correctamente')),
            );
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error al guardar: $e')),
            );
          }
        }
      }
    }
  }

  void _openGallery(BuildContext context, List<FotoSesion> photos, int initialIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('Visor de fotos')),
          body: PhotoViewGallery.builder(
            itemCount: photos.length,
            builder: (context, index) {
              return PhotoViewGalleryPageOptions(
                imageProvider: FileImage(File(photos[index].rutaFoto)),
                initialScale: PhotoViewComputedScale.contained,
                heroAttributes: PhotoViewHeroAttributes(tag: photos[index].id),
              );
            },
            pageController: PageController(initialPage: initialIndex),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(sessionPhotosProvider(sessionId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Fotos Comparativas', style: Theme.of(context).textTheme.titleLarge),
            ElevatedButton.icon(
              onPressed: () => _pickPhoto(context, ref),
              icon: const Icon(Icons.add_a_photo),
              label: const Text('Agregar Foto'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        state.when(
          data: (photos) {
            if (photos.isEmpty) {
              return const Center(child: Text('No hay fotos para esta sesión.'));
            }
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: photos.length,
              itemBuilder: (context, index) {
                final photo = photos[index];
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    GestureDetector(
                      onTap: () => _openGallery(context, photos, index),
                      child: Hero(
                        tag: photo.id,
                        child: Image.file(
                          File(photo.rutaThumb ?? photo.rutaFoto),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Eliminar foto'),
                              content: const Text('¿Estás seguro?'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
                                ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sí')),
                              ],
                            ),
                          );
                          if (confirm == true && context.mounted) {
                            try {
                              await ref.read(sessionPhotosProvider(sessionId).notifier).removePhoto(photo.id);
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                              }
                            }
                          }
                        },
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white70,
                        ),
                      ),
                    ),
                    if (photo.tipo != null)
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          color: Colors.black54,
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Text(
                            photo.tipo!.toUpperCase(),
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ),
                      ),
                  ],
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, st) => Center(child: Text('Error: $e')),
        ),
      ],
    );
  }
}
