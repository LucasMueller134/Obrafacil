import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:flutter/services.dart';

/// Falhas da câmera, das IAs e do salvamento em frases de canteiro.
///
/// A exceção crua na tela ("PlatformException(camera_access_denied, ...)")
/// não diz nada a quem está na obra com o celular na mão: a pessoa precisa
/// saber o que aconteceu e o que fazer a seguir. O detalhe técnico continua
/// indo para o log (`debugPrint` em quem chama), não para o usuário.
abstract class MensagensErro {
  /// Falha ao abrir a câmera ou a galeria.
  ///
  /// [temGaleria] diz se a tela oferece a galeria como saída. O estoque só
  /// identifica o material pela câmera: mandar "escolher da galeria" ali
  /// deixava a pessoa sem caminho nenhum.
  static String daCamera(Object erro, {bool temGaleria = true}) {
    final codigo = _codigo(erro);
    if (_negouPermissao(codigo)) {
      return 'O app não tem permissão para usar a câmera ou as fotos. '
          'Libere nas configurações do celular e tente de novo.';
    }
    if (codigo.contains('no_available_camera')) {
      final saida = temGaleria
          ? 'Escolha uma foto da galeria.'
          : 'Digite o nome do material no campo.';
      return 'Não encontrei uma câmera disponível neste aparelho. $saida';
    }
    if (erro is MissingPluginException) return _soNoCelular;
    return 'Não consegui abrir a câmera agora. Tente de novo.';
  }

  /// Falha de uma IA ao ler a foto. [oQue] completa a frase: "a foto",
  /// "o material".
  static String daAnalise(Object erro, {required String oQue}) {
    if (erro is MissingPluginException) return _soNoCelular;
    if (erro is FileSystemException) {
      return 'Não consegui abrir a foto no aparelho para ler $oQue. '
          'Tire outra e tente de novo.';
    }
    if (erro is FormatException) {
      return 'A foto veio num formato que não consegui ler. Tire outra pela '
          'câmera do app.';
    }
    if (erro is TimeoutException) {
      return 'A leitura de $oQue demorou demais. Tente de novo com uma foto '
          'mais simples, de perto e com boa luz.';
    }
    return 'Não consegui ler $oQue desta vez. Você pode preencher à mão ou '
        'tentar de novo com outra foto.';
  }

  /// Falha ao gravar o registro no servidor.
  static String aoSalvar(Object erro) {
    if (erro is FirebaseException) {
      final codigo = erro.code;
      if (codigo == 'permission-denied' || codigo == 'unauthenticated') {
        return 'Você não tem permissão para salvar nesta obra. Fale com o '
            'dono da obra.';
      }
      if (codigo == 'unavailable' || codigo == 'deadline-exceeded') {
        return 'Sem conexão com o servidor agora. Confira a internet e '
            'tente de novo.';
      }
      if (codigo == 'resource-exhausted') {
        return 'O servidor está no limite de uso. Tente de novo em alguns '
            'minutos.';
      }
      // O Firestore recusa documento acima de 1 MB com "invalid-argument":
      // no diário, são as fotos embutidas que passam do limite.
      if (codigo == 'invalid-argument' &&
          (erro.message ?? '').toLowerCase().contains('size')) {
        return 'O registro ficou grande demais por causa das fotos. Remova '
            'uma delas e salve de novo.';
      }
    }
    if (erro is FileSystemException) {
      return 'Não consegui abrir uma das fotos anexadas. Remova a foto e '
          'salve de novo.';
    }
    return 'Não foi possível salvar o registro. Tente de novo.';
  }

  static const String _soNoCelular =
      'A leitura por IA só funciona no app instalado no celular.';

  static String _codigo(Object erro) =>
      erro is PlatformException ? erro.code.toLowerCase() : '';

  static bool _negouPermissao(String codigo) =>
      codigo.contains('denied') || codigo.contains('permission');
}
