// lib/screens/galeria/galeria_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:io';
import '../../models/models.dart';
import '../../providers/app_provider.dart';
import '../../constants/app_theme.dart';
import '../../constants/app_constants.dart';

class GaleriaScreen extends StatelessWidget {
  final String obraId;
  const GaleriaScreen({super.key, required this.obraId});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<AppProvider>();

    return StreamBuilder<List<GaleriaModel>>(
      stream: provider.firebaseService.streamGaleria(obraId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final fotos = snapshot.data ?? [];

        return Scaffold(
          body: fotos.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.photo_library_outlined,
                          size: 64, color: AppTheme.border),
                      const SizedBox(height: 16),
                      const Text('Nenhuma foto ainda'),
                    ],
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: fotos.length,
                  itemBuilder: (context, i) => _FotoCard(foto: fotos[i]),
                ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _tirarFoto(context),
            child: const Icon(Icons.camera_alt),
          ),
        );
      },
    );
  }

  Future<void> _tirarFoto(BuildContext context) async {
    final picker = ImagePicker();
    final xFile = await picker.pickImage(source: ImageSource.camera, imageQuality: 80);
    if (xFile == null) return;

    final provider = context.read<AppProvider>();
    final usuario = provider.usuario!;
    final id = const Uuid().v4();

    try {
      final url = await provider.firebaseService.uploadFoto(
        File(xFile.path),
        obraId,
        'foto_$id.jpg',
      );
      final galeria = GaleriaModel(
        id: id,
        obraId: obraId,
        fotoUrl: url,
        fase: AppConstants.fasesObra.first,
        registradoPorNome: usuario.nome,
        data: DateTime.now(),
      );
      await provider.firebaseService.salvarFotoGaleria(galeria);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Foto salva!'), backgroundColor: AppTheme.success),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }
}

class _FotoCard extends StatelessWidget {
  final GaleriaModel foto;
  const _FotoCard({required this.foto});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _verFoto(context),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: CachedNetworkImage(
          imageUrl: foto.fotoUrl,
          fit: BoxFit.cover,
          placeholder: (_, __) => Container(
            color: AppTheme.border,
            child: const Center(child: CircularProgressIndicator()),
          ),
          errorWidget: (_, __, ___) =>
              Container(color: AppTheme.border, child: const Icon(Icons.broken_image)),
        ),
      ),
    );
  }

  void _verFoto(BuildContext context) {
    final fmt = DateFormat('dd/MM/yyyy');
    showDialog(
      context: context,
      builder: (_) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CachedNetworkImage(imageUrl: foto.fotoUrl),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Text(foto.fase, style: Theme.of(context).textTheme.titleMedium),
                  Text('${fmt.format(foto.data)} • ${foto.registradoPorNome}',
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
