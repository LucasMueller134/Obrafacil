// Confere o harness de fontes das capturas (roda sempre, sem CAPTURAR):
// se o carregarFontes() quebrar, as capturas sairiam com texto em blocos
// e ícones em quadrado, e é aqui que isso aparece primeiro.

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obra_facil/constants/app_theme.dart';

import 'suporte/fontes.dart';

/// Na fonte de teste do Flutter todo glifo tem 1 em de largura. Numa
/// fonte de verdade, oito "i" ficam bem mais estreitos que isso — até na
/// monoespaçada (0,6 em).
const _tamanho = 20.0;
const _amostra = 'iiiiiiii';

Future<Uint8List> _pixels(WidgetTester tester, GlobalKey chave) async {
  late Uint8List rgba;
  await tester.runAsync(() async {
    final limite =
        chave.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final imagem = await limite.toImage();
    final dados = await imagem.toByteData(format: ui.ImageByteFormat.rawRgba);
    imagem.dispose();
    rgba = dados!.buffer.asUint8List();
  });
  return rgba;
}

/// Quadro de 48x48 com fundo preto. O Center de fora impede que a raiz
/// da tela estique o quadro até o tamanho da janela.
Widget _quadro(GlobalKey chave, Widget filho) => Center(
      child: RepaintBoundary(
        key: chave,
        child: SizedBox(
          width: 48,
          height: 48,
          child: ColoredBox(color: Colors.black, child: Center(child: filho)),
        ),
      ),
    );

void main() {
  setUpAll(carregarFontes);

  testWidgets('texto do tema atual e das fontes novas sai na fonte de verdade',
      (tester) async {
    const familiasNovas = ['Archivo', 'Atkinson', 'PlexMono'];
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark,
      home: Scaffold(
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(_amostra,
                key: ValueKey('Poppins'), style: TextStyle(fontSize: _tamanho)),
            for (final familia in familiasNovas)
              Text(_amostra,
                  key: ValueKey(familia),
                  style: TextStyle(fontFamily: familia, fontSize: _tamanho)),
            const Text('Olá → R\$ 1.234,56 · Toque no ✕'),
          ],
        ),
      ),
    ));

    expect(familiasNaoCarregadas(), isEmpty);
    for (final familia in ['Poppins', ...familiasNovas]) {
      final largura = tester.getSize(find.byKey(ValueKey(familia))).width;
      expect(largura, lessThan(_amostra.length * _tamanho * 0.8),
          reason: '$familia saiu na fonte de teste (largura $largura)');
    }
  });

  testWidgets('ícone Material sai desenhado, não como quadrado',
      (tester) async {
    final chave = GlobalKey();
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child:
          _quadro(chave, const Icon(Icons.add, size: 48, color: Colors.white)),
    ));
    final rgba = await _pixels(tester, chave);
    expect(rgba.length, 48 * 48 * 4);
    int brilho(int x, int y) => rgba[(y * 48 + x) * 4];

    // O "+" acende o centro e deixa os cantos do quadro apagados; um
    // quadrado cheio (fonte de teste) acenderia tudo, e o contorno de
    // glifo ausente deixaria o centro apagado.
    expect(brilho(24, 24), greaterThan(200), reason: 'centro do +');
    expect(brilho(24, 14), greaterThan(200), reason: 'braço de cima do +');
    expect(brilho(12, 12), lessThan(50), reason: 'canto do quadro');
  });

  testWidgets('símbolo que a Poppins não tem cai na fonte de símbolos',
      (tester) async {
    Future<Uint8List> desenhar(String simbolo) async {
      final chave = GlobalKey();
      // O Material põe o texto do tema (Poppins) como estilo padrão.
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.dark,
        home: Material(
          type: MaterialType.transparency,
          child: _quadro(
            chave,
            Text(simbolo,
                style: const TextStyle(fontSize: 32, color: Colors.white)),
          ),
        ),
      ));
      expect(familiasNaoCarregadas(), isEmpty);
      return _pixels(tester, chave);
    }

    // Sem o fallback, as duas setas viram o mesmo quadradinho.
    final direita = await desenhar('→');
    final esquerda = await desenhar('←');
    expect(direita.any((b) => b > 200), isTrue, reason: 'a seta não apareceu');
    expect(direita, isNot(equals(esquerda)));
  });
}
