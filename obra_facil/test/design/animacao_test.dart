// Movimento: com "reduzir animações" tudo aparece pronto (duração zero);
// sem, a régua se traça e o valor conta até o número novo.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obra_facil/design/design.dart';
import 'package:obra_facil/utils/formatters.dart';

import 'suporte/montar.dart';

/// O texto que o ValorHeroi mostra agora (reais + centavos).
String _valorNaTela(WidgetTester tester) {
  final texto = tester.widget<Text>(find
      .descendant(
        of: find.byType(ValorHeroi),
        matching: find.byType(Text),
      )
      .last);
  return texto.data ?? texto.textSpan!.toPlainText();
}

/// Conta quantas vezes a subárvore em volta é repintada.
class _ContaPinturas extends SingleChildRenderObjectWidget {
  const _ContaPinturas({required this.contagem, super.child});

  final List<int> contagem;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderContaPinturas(contagem);
}

class _RenderContaPinturas extends RenderProxyBox {
  _RenderContaPinturas(this.contagem);

  final List<int> contagem;

  @override
  void paint(PaintingContext context, Offset offset) {
    contagem[0]++;
    super.paint(context, offset);
  }
}

/// O quanto a régua já traçou.
PintorReguaCota _pintor(WidgetTester tester) => tester
    .widget<CustomPaint>(find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is PintorReguaCota))
    .painter! as PintorReguaCota;

void main() {
  setUpAll(() => Tato.ativo = false);

  testWidgets('Movimento.ajustar zera a duração com "reduzir animações"',
      (tester) async {
    late Duration comReducao;
    late Duration semReducao;
    await tester.pumpWidget(montar(semAnimacao: true, Builder(
      builder: (context) {
        comReducao = context.duracao(Movimento.lento);
        return const SizedBox();
      },
    )));
    await tester.pumpWidget(montar(Builder(builder: (context) {
      semReducao = context.duracao(Movimento.lento);
      return const SizedBox();
    })));
    expect(comReducao, Duration.zero);
    expect(semReducao, Movimento.lento);
  });

  group('ValorHeroi', () {
    Widget heroi(double valor, {bool semAnimacao = false}) => montar(
          semAnimacao: semAnimacao,
          ValorHeroi(valor: valor, rotulo: 'Gasto até agora'),
        );

    testWidgets('com "reduzir animações", o valor novo aparece na hora',
        (tester) async {
      await tester.pumpWidget(heroi(112380, semAnimacao: true));
      expect(_valorNaTela(tester), Formatters.moeda(112380));
      await tester.pumpWidget(heroi(114760, semAnimacao: true));
      expect(_valorNaTela(tester), Formatters.moeda(114760));
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('sem redução, conta até o valor novo em 360 ms',
        (tester) async {
      await tester.pumpWidget(heroi(100));
      // Aparecer não é mudança: não conta do zero.
      expect(_valorNaTela(tester), Formatters.moeda(100));
      await tester.pumpWidget(heroi(200));
      await tester.pump(const Duration(milliseconds: 120));
      final meio = Formatters.parseValor(_valorNaTela(tester))!;
      expect(meio, greaterThan(100));
      expect(meio, lessThan(200));
      await tester.pump(Movimento.lento);
      expect(_valorNaTela(tester), Formatters.moeda(200));
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('o leitor de tela ouve só o valor final', (tester) async {
      final semantica = tester.ensureSemantics();
      await tester.pumpWidget(heroi(100));
      await tester.pumpWidget(heroi(200));
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        find.bySemanticsLabel('Gasto até agora: ${Formatters.moeda(200)}'),
        findsOneWidget,
      );
      semantica.dispose();
    });

    testWidgets('a largura não tremula durante a contagem', (tester) async {
      // Algarismos tabulares: com o mesmo número de dígitos, a largura
      // natural do texto é a mesma em todo quadro; e a caixa do número tem
      // tamanho fixo durante a contagem (a tela em volta não remonta).
      await tester.pumpWidget(heroi(111111.11));
      await tester.pumpWidget(heroi(888888.88));
      final numero = find
          .descendant(
              of: find.byType(ValorHeroi), matching: find.byType(RichText))
          .last;
      final naturais = <double>{};
      final caixas = <Size>{};
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 60));
        naturais.add(tester
            .renderObject<RenderParagraph>(numero)
            .getMaxIntrinsicWidth(double.infinity));
        caixas.add(tester.getSize(numero));
      }
      expect(naturais, hasLength(1));
      expect(caixas, hasLength(1));
      final estilo = tester.widget<RichText>(numero).text.style!;
      expect(estilo.fontFeatures, contains(const FontFeature.tabularFigures()));
    });
  });

  group('ReguaCota', () {
    Widget regua(double valor, {bool semAnimacao = false}) => montar(
          semAnimacao: semAnimacao,
          SizedBox(
            width: 320,
            child: ReguaCota(valor: valor, marcador: 0.38, legenda: 'avanço'),
          ),
        );

    testWidgets('com "reduzir animações", aparece já traçada', (tester) async {
      await tester.pumpWidget(regua(0.43, semAnimacao: true));
      expect(_pintor(tester).preenchimento, 0.43);
      expect(_pintor(tester).marcador, 0.38);
      await tester.pumpWidget(regua(0.6, semAnimacao: true));
      await tester.pump();
      expect(_pintor(tester).preenchimento, 0.6);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('sem redução, traça da esquerda até o valor', (tester) async {
      await tester.pumpWidget(regua(0.43));
      expect(_pintor(tester).preenchimento, 0);
      await tester.pump(const Duration(milliseconds: 120));
      final meio = _pintor(tester).preenchimento;
      expect(meio, greaterThan(0));
      expect(meio, lessThan(0.43));
      await tester.pump(Movimento.lento);
      expect(_pintor(tester).preenchimento, closeTo(0.43, 1e-9));
      // Ao mudar, vai do valor antigo ao novo (não recomeça do zero).
      await tester.pumpWidget(regua(0.6));
      await tester.pump(const Duration(milliseconds: 16));
      expect(_pintor(tester).preenchimento, greaterThanOrEqualTo(0.43));
    });

    testWidgets('orçamento zero (valor infinito ou NaN) não derruba a tela',
        (tester) async {
      for (final v in [double.infinity, double.nan]) {
        await tester.pumpWidget(montar(
          semAnimacao: true,
          SizedBox(
            width: 320,
            child: ReguaCota(valor: v, marcador: v, legenda: 'avanço'),
          ),
        ));
        expect(tester.takeException(), isNull);
        expect(_pintor(tester).preenchimento, 0);
      }
    });

    testWidgets('acima de 100% a régua fica cheia; o leitor ouve o valor',
        (tester) async {
      final semantica = tester.ensureSemantics();
      await tester.pumpWidget(montar(
        semAnimacao: true,
        const SizedBox(
          width: 320,
          child: ReguaCota(valor: 1.12, rotuloSemantico: 'Orçamento usado'),
        ),
      ));
      expect(_pintor(tester).preenchimento, 1);
      expect(
        tester.getSemantics(find.byType(ReguaCota)),
        isSemantics(label: 'Orçamento usado', value: '112%'),
      );
      semantica.dispose();
    });
  });

  testWidgets('varredura e esqueleto ficam parados com "reduzir animações"',
      (tester) async {
    await tester.pumpWidget(montar(
      semAnimacao: true,
      const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 300,
            height: 200,
            child: Varredura(child: ColoredBox(color: Colors.white)),
          ),
          SizedBox(width: 300, child: EsqueletoFolha()),
        ],
      ),
    ));
    await tester.pump();
    expect(tester.hasRunningAnimations, isFalse);
    // A legenda continua dizendo o que acontece.
    expect(find.textContaining('LENDO A NOTA', findRichText: true),
        findsOneWidget);
  });

  testWidgets('sem redução, a varredura se move', (tester) async {
    await tester.pumpWidget(montar(const SizedBox(
      width: 300,
      height: 200,
      child: Varredura(child: ColoredBox(color: Colors.white)),
    )));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.hasRunningAnimations, isTrue);
    // Ao terminar a leitura (ativa: false), para.
    await tester.pumpWidget(montar(const SizedBox(
      width: 300,
      height: 200,
      child: Varredura(ativa: false, child: ColoredBox(color: Colors.white)),
    )));
    await tester.pump();
    expect(tester.hasRunningAnimations, isFalse);
  });

  group('o que anima não repinta a tela em volta', () {
    // Sem camada própria (RepaintBoundary) e sem `repaint:` no pintor, a
    // varredura, o esqueleto e o indicador repintavam a tela a cada quadro,
    // enquanto durassem (30 de 30 quadros, com a foto embaixo junto).
    for (final (nome, animado) in <(String, Widget)>[
      (
        'varredura',
        const SizedBox(
          width: 300,
          height: 200,
          child: Varredura(child: ColoredBox(color: Color(0xFFFFFFFF))),
        ),
      ),
      ('esqueleto', const SizedBox(width: 300, child: EsqueletoFolha())),
      ('indicador de carregamento', const IndicadorCarregando()),
    ]) {
      testWidgets(nome, (tester) async {
        final contagem = [0];
        await tester.pumpWidget(montar(_ContaPinturas(
          contagem: contagem,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [const Text('vizinho'), animado],
          ),
        )));
        await tester.pump(const Duration(milliseconds: 16));
        final antes = contagem[0];
        for (var i = 0; i < 30; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        expect(tester.hasRunningAnimations, isTrue, reason: 'está animando');
        expect(contagem[0] - antes, 0);
      });
    }

    testWidgets('régua que se traça e valor que conta', (tester) async {
      final contagem = [0];
      Widget tela(double v) => montar(_ContaPinturas(
            contagem: contagem,
            child: SizedBox(
              width: 320,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ValorHeroi(valor: v * 1000, rotulo: 'Gasto'),
                  ReguaCota(valor: v, marcador: v / 2, legenda: 'avanço'),
                ],
              ),
            ),
          ));
      await tester.pumpWidget(tela(0.2));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpWidget(tela(0.8));
      final antes = contagem[0];
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(tester.hasRunningAnimations, isTrue, reason: 'está animando');
      // O quadro em que o valor muda remonta a tela (é a mudança); os
      // quadros da animação, não.
      expect(contagem[0] - antes, lessThanOrEqualTo(1));
    });
  });
}
