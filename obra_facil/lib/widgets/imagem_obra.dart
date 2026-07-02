import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../services/imagem_service.dart';

/// Exibe uma foto vinda do Firestore: aceita data URI (base64) ou URL http.
class ImagemObra extends StatelessWidget {
  final String fonte;
  final BoxFit fit;
  final double? width;
  final double? height;

  const ImagemObra(
    this.fonte, {
    super.key,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    if (ImagemService.ehDataUri(fonte)) {
      return Image.memory(
        ImagemService.bytesDe(fonte),
        fit: fit,
        width: width,
        height: height,
        gaplessPlayback: true,
      );
    }
    if (fonte.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: fonte,
        fit: fit,
        width: width,
        height: height,
        placeholder: (_, __) => const _Placeholder(),
        errorWidget: (_, __, ___) => const _Placeholder(erro: true),
      );
    }
    return const _Placeholder(erro: true);
  }
}

class _Placeholder extends StatelessWidget {
  final bool erro;
  const _Placeholder({this.erro = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.superficieAlta,
      alignment: Alignment.center,
      child: Icon(
        erro ? Icons.broken_image : Icons.image,
        color: AppColors.textoDesabilitado,
      ),
    );
  }
}
