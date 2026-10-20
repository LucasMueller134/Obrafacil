// A foto da nota para as capturas do "Lançar gasto": um cupom desenhado
// num arquivo temporário, o image_picker devolvendo esse arquivo e o ML
// Kit devolvendo o texto dele, como o Android mandaria.
//
// Só os canais mudam; o app roda o OcrNotaService de verdade (o parser,
// os itens, o aviso de confiança).

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _canalFoto = MethodChannel('plugins.flutter.io/image_picker');
const _canalTexto = MethodChannel('google_mlkit_text_recognizer');

/// As linhas do cupom: o que está desenhado e o que o "OCR" lê.
const _linhas = [
  'CASA DO CONSTRUTOR LTDA',
  'CNPJ 11.222.333/0001-81',
  'CUPOM FISCAL ELETRONICO',
  '',
  'BLOCO CERAMICO 9 FUROS',
  '2000 UN X 1,19      2.380,00',
  '',
  'VALOR TOTAL R\$     2.380,00',
  'EMISSAO 19/10/2026 10:12:30',
];

const double _larguraFoto = 900;
const double _alturaFoto = 1200;
const double _margemPapel = 110;
const double _topoTexto = 180;
const double _entreLinhas = 56;
const double _tamanhoLetra = 34;

/// Desenha o cupom e grava num PNG temporário; devolve o caminho.
Future<String> _desenharNota() async {
  final gravador = ui.PictureRecorder();
  final tela = Canvas(gravador);
  tela.drawRect(
    const Rect.fromLTWH(0, 0, _larguraFoto, _alturaFoto),
    Paint()..color = const Color(0xFFCFC6B4),
  );
  tela.drawRect(
    const Rect.fromLTWH(
        _margemPapel, 60, _larguraFoto - 2 * _margemPapel, _alturaFoto - 120),
    Paint()..color = const Color(0xFFFBFAF6),
  );
  for (var i = 0; i < _linhas.length; i++) {
    final construtor = ui.ParagraphBuilder(ui.ParagraphStyle(
      fontFamily: 'PlexMono',
      fontSize: _tamanhoLetra,
    ))
      ..pushStyle(ui.TextStyle(color: const Color(0xFF2B2B2B)))
      ..addText(_linhas[i]);
    final paragrafo = construtor.build()
      ..layout(const ui.ParagraphConstraints(width: _larguraFoto));
    tela.drawParagraph(
        paragrafo, Offset(_margemPapel + 40, _topoTexto + i * _entreLinhas));
  }
  final imagem = await gravador
      .endRecording()
      .toImage(_larguraFoto.toInt(), _alturaFoto.toInt());
  final png = await imagem.toByteData(format: ui.ImageByteFormat.png);
  imagem.dispose();
  final pasta = await Directory.systemTemp.createTemp('nota_falsa');
  final arquivo = File('${pasta.path}/nota.png');
  await arquivo.writeAsBytes(png!.buffer.asUint8List());
  return arquivo.path;
}

Map<String, Object?> _linhaOcr(String texto, double y) {
  const x = _margemPapel + 40;
  final direita = x + texto.length * _tamanhoLetra * 0.6;
  final baixo = y + _tamanhoLetra * 1.3;
  return {
    'text': texto,
    'rect': {'left': x, 'top': y, 'right': direita, 'bottom': baixo},
    'points': [
      {'x': x, 'y': y},
      {'x': direita, 'y': y},
      {'x': direita, 'y': baixo},
      {'x': x, 'y': baixo},
    ],
    'recognizedLanguages': <String>[],
    'elements': <Object>[],
    'confidence': 0.94,
    'angle': 0.0,
  };
}

/// O RecognizedText do ML Kit, um bloco por grupo de linhas.
Map<String, Object?> _textoReconhecido() {
  final blocos = <List<Map<String, Object?>>>[[]];
  for (var i = 0; i < _linhas.length; i++) {
    if (_linhas[i].isEmpty) {
      blocos.add([]);
      continue;
    }
    blocos.last.add(_linhaOcr(_linhas[i], _topoTexto + i * _entreLinhas));
  }
  return {
    'text': _linhas.where((l) => l.isNotEmpty).join('\n'),
    'blocks': [
      for (final linhas in blocos.where((b) => b.isNotEmpty))
        {
          'text': linhas.map((l) => l['text']).join('\n'),
          'rect': linhas.first['rect'],
          'points': linhas.first['points'],
          'recognizedLanguages': <String>[],
          'lines': linhas,
        },
    ],
  };
}

/// Prepara a foto: o arquivo, o image_picker devolvendo ele, o ML Kit
/// respondendo depois de [demora] (tempo falso do teste) e as duas
/// imagens que a tela pede já decodificadas no cache, nos tamanhos em
/// que ela pede (a foto na largura da tela e a miniatura de 64 dp).
///
/// Com uma [demora] maior que o tempo até a captura, a foto sai no meio
/// da leitura; o harness ainda deixa o tempo correr 10 s depois de
/// desmontar, então a resposta chega e nada fica pendente.
Future<void> prepararNotaFalsa(
  WidgetTester tester, {
  Duration demora = const Duration(milliseconds: 300),
}) async {
  final caminho = (await tester.runAsync(_desenharNota))!;
  final mensageiro = tester.binding.defaultBinaryMessenger;
  mensageiro.setMockMethodCallHandler(
    _canalFoto,
    (chamada) async => chamada.method == 'pickImage' ? caminho : null,
  );
  mensageiro.setMockMethodCallHandler(_canalTexto, (chamada) async {
    if (chamada.method != 'vision#startTextRecognizer') return null;
    await Future<void>.delayed(demora);
    return _textoReconhecido();
  });

  final contexto = tester.element(find.byType(Scaffold).last);
  final proporcao = tester.view.devicePixelRatio;
  final larguraTela = tester.view.physicalSize.width / proporcao;
  await tester.runAsync(() async {
    for (final largura in [larguraTela * proporcao, 64 * proporcao]) {
      await precacheImage(
        ResizeImage.resizeIfNeeded(
            largura.round(), null, FileImage(File(caminho))),
        contexto,
      );
    }
  });
}
