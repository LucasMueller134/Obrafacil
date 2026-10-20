// Nada estoura com a fonte do sistema em 130% numa tela de 360 dp (o
// celular mais estreito comum). Um estouro de layout vira exceção no
// teste ("A RenderFlex overflowed...").
//
// Com as fontes de verdade (as do pubspec, carregadas pelo harness das
// capturas): a fonte de teste do Flutter dá 1 em a cada letra, quase o
// dobro da Archivo SemiCondensed, e o teste mediria outra coisa.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obra_facil/design/catalogo_design.dart';
import 'package:obra_facil/design/design.dart';

import '../visual/suporte/fontes.dart';
import 'suporte/montar.dart';

void main() {
  setUpAll(() async {
    Tato.ativo = false;
    await carregarFontes();
  });

  for (final brilho in Brightness.values) {
    for (final escala in [1.0, 1.3]) {
      testWidgets(
          'catálogo em 360 dp, fonte ${(escala * 100).round()}%, '
          '${brilho.name}', (tester) async {
        definirTela(tester, 360, 780);
        await tester.pumpWidget(MaterialApp(
          debugShowCheckedModeBanner: false,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(escala)),
            child: child!,
          ),
          home: CatalogoDesign(brilho: brilho),
        ));
        await tester.pump(const Duration(seconds: 1));
        expect(tester.takeException(), isNull);
        expect(familiasNaoCarregadas(), isEmpty);
        // A página inteira é montada de uma vez (SingleChildScrollView):
        // rolar até o fim confere que nada quebrou no caminho.
        await tester.drag(
            find.byType(Scrollable).first, const Offset(0, -20000));
        await tester.pump(const Duration(seconds: 1));
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('componentes com conteúdo difícil em 360 dp e fonte 130%',
      (tester) async {
    definirTela(tester, 360, 2000);
    await tester.pumpWidget(montar(
      escalaTexto: 1.3,
      rolavel: true,
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Carimbo(linhas: [
            [
              CelulaCarimbo(
                rotulo: 'Obra',
                valor:
                    'Residência Unifamiliar do Loteamento Jardim das Acácias',
                destaque: true,
              ),
            ],
            [
              CelulaCarimbo(rotulo: 'Fase', valor: 'Revestimento'),
              CelulaCarimbo(rotulo: 'Semana', valor: '114 de 132'),
              CelulaCarimbo(rotulo: 'Equipe', valor: '12 pessoas'),
            ],
          ]),
          const ValorHeroi(valor: 12345678.9, rotulo: 'Gasto até agora'),
          const ReguaCota(
            valor: 0.98,
            marcador: 0.97,
            legenda: 'avanço previsto da semana 97%',
          ),
          const ReguaCota(valor: 0.02, marcador: 0.01, legenda: 'avanço 1%'),
          const Wrap(children: [
            NotaRevisao('R\$ 12.300 acima do previsto para a fase de estrutura',
                icone: Icons.trending_up),
            SeloStatus(StatusSelo.pendente, texto: 'Aguardando o dono'),
          ]),
          const LinhaCota(legenda: 'Lançamentos aguardando aprovação do dono'),
          BotaoPrincipal(
            rotulo: 'Revisar os 13 gastos que chegaram hoje',
            icone: Icons.fact_check_outlined,
            grande: true,
            aoTocar: () {},
          ),
          Row(children: [
            Expanded(
              child: BotaoPrincipal(
                rotulo: 'Aprovar',
                icone: Icons.check,
                aoTocar: () {},
              ),
            ),
            const SizedBox(width: Espaco.entreAlvos),
            Expanded(
              child: BotaoContorno(
                rotulo: 'Recusar',
                icone: Icons.close,
                aoTocar: () {},
              ),
            ),
          ]),
          LinhaLista(
            icone: Icons.receipt_long_outlined,
            titulo: 'Bloco cerâmico de vedação 9 furos 14 x 19 x 29 cm',
            apoio: '2.000 un · Casa do Construtor Materiais Ltda',
            valor: 'R\$ 123.380,00',
            fim: const SeloStatus(StatusSelo.recusado),
            aoTocar: () {},
          ),
          SeletorGrande<int>(
            rotulo: 'Categoria do gasto',
            opcoes: const [
              OpcaoSeletor(valor: 1, rotulo: 'Material'),
              OpcaoSeletor(valor: 2, rotulo: 'Mão de obra'),
              OpcaoSeletor(valor: 3, rotulo: 'Equipamento'),
              OpcaoSeletor(valor: 4, rotulo: 'Serviço terceirizado'),
            ],
            selecionado: 3,
            aoMudar: (_) {},
          ),
          SeletorGrande<int>(
            opcoes: const [
              OpcaoSeletor(valor: 1, rotulo: 'Pix'),
              OpcaoSeletor(valor: 2, rotulo: 'Dinheiro'),
              OpcaoSeletor(valor: 3, rotulo: 'Cartão de crédito'),
            ],
            selecionado: 1,
            aoMudar: (_) {},
          ),
          const SizedBox(
            height: 200,
            child: Varredura(
              legenda: 'Lendo a nota fiscal eletrônica do fornecedor',
              child: ColoredBox(color: Colors.white),
            ),
          ),
          const EsqueletoFolha(linhas: 5),
          BarraDeAcao(
            acima: const Text('3 gastos selecionados · R\$ 4.912,40'),
            principal: BotaoPrincipal(
              rotulo: 'Aprovar os 3 gastos selecionados',
              aoTocar: () {},
            ),
            secundaria: BotaoIcone(
              icone: Icons.add,
              rotulo: 'Lançar gasto',
              estilo: EstiloBotaoIcone.marca,
              aoTocar: () {},
            ),
          ),
        ],
      ),
    ));
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
    expect(familiasNaoCarregadas(), isEmpty);
  });

  testWidgets(
      'LinhaLista em 360 dp: valor na linha de base do título, apoio numa '
      'linha só, selo inteiro', (tester) async {
    definirTela(tester, 360, 800);
    const titulo = 'Bloco cerâmico 9 furos';
    const apoio = '2.000 un · Casa do Construtor';
    await tester.pumpWidget(montar(
      rolavel: true,
      Folha(
        preenchimento: EdgeInsets.zero,
        child: Column(
          children: [
            LinhaLista(
              icone: Icons.receipt_long_outlined,
              titulo: titulo,
              apoio: apoio,
              valor: 'R\$ 2.380,00',
              margemHorizontal: Espaco.e12,
              aoTocar: () {},
            ),
            const LinhaLista(
              icone: Icons.check,
              titulo: 'Fundação',
              apoio: 'Concluída em 02/09',
              fim: SeloStatus(StatusSelo.aprovado),
              margemHorizontal: Espaco.e12,
            ),
          ],
        ),
      ),
    ));
    await tester.pump();
    expect(tester.takeException(), isNull);

    double linhaDeBase(Finder texto) {
      final p = tester.renderObject<RenderParagraph>(texto);
      return p.localToGlobal(Offset.zero).dy +
          p.getDryBaseline(p.constraints, TextBaseline.alphabetic)!;
    }

    // O valor fica na altura da primeira linha do título (como na fila
    // da prancha), não no meio da linha de lista.
    expect(linhaDeBase(find.text('R\$ 2.380,00')),
        closeTo(linhaDeBase(find.text(titulo)), 0.5));
    // O apoio vai até a borda (não só até a coluna do valor): numa linha.
    final paragrafoApoio =
        tester.renderObject<RenderParagraph>(find.text(apoio));
    expect(paragrafoApoio.didExceedMaxLines, isFalse);
    expect(tester.getSize(find.text(apoio)).height,
        lessThan(Tipografia.apoio.fontSize! * Tipografia.apoio.height! * 1.5));
    // O texto do selo de status nunca é cortado.
    final selo = tester.renderObject<RenderParagraph>(
        find.textContaining('Aprovado', findRichText: true));
    expect(selo.didExceedMaxLines, isFalse);
  });

  // Medido com as fontes reais: com a fonte de teste "Equipamento" já não
  // cabe em meia tela e o seletor vai, com razão, para uma coluna.
  group('SeletorGrande', () {
      testWidgets('SeletorGrande: opções de 56 dp, 12 dp entre elas',
          (tester) async {
        await tester.pumpWidget(montar(SizedBox(
          width: 360,
          child: SeletorGrande<int>(
            rotulo: 'Categoria',
            opcoes: const [
              OpcaoSeletor(valor: 1, rotulo: 'Material'),
              OpcaoSeletor(valor: 2, rotulo: 'Mão de obra'),
              OpcaoSeletor(valor: 3, rotulo: 'Equipamento'),
              OpcaoSeletor(valor: 4, rotulo: 'Outros'),
            ],
            selecionado: 1,
            aoMudar: (_) {},
          ),
        )));
        final caixas = [
          for (final r in ['Material', 'Mão de obra', 'Equipamento', 'Outros'])
            tester.getRect(find.ancestor(
              of: find.textContaining(r, findRichText: true),
              matching: find.byType(AreaPressionavel),
            )),
        ];
        for (final c in caixas) {
          expect(c.height, greaterThanOrEqualTo(Alvo.opcao));
        }
        // 2 x 2: lado a lado e uma linha embaixo da outra.
        expect(caixas[1].left - caixas[0].right,
            greaterThanOrEqualTo(Espaco.entreAlvos));
        expect(caixas[2].top - caixas[0].bottom,
            greaterThanOrEqualTo(Espaco.entreAlvos));
      });


    testWidgets('em 360 dp com fonte 130%, nenhum rótulo quebra no meio',
        (tester) async {
      definirTela(tester, 360);
      // Na tela, o seletor fica dentro da margem de 16 dp (328 dp úteis).
      await tester.pumpWidget(montar(
        SeletorGrande<int>(
          opcoes: const [
            OpcaoSeletor(valor: 1, rotulo: 'Material'),
            OpcaoSeletor(valor: 2, rotulo: 'Mão de obra'),
            OpcaoSeletor(valor: 3, rotulo: 'Equipamento'),
            OpcaoSeletor(valor: 4, rotulo: 'Outros'),
          ],
          selecionado: 3,
          aoMudar: (_) {},
        ),
        escalaTexto: 1.3,
        rolavel: true,
      ));
      final texto = tester.renderObject<RenderParagraph>(
          find.textContaining('Equipamento', findRichText: true));
      final umaLinha = texto.getFullHeightForCaret(
              const TextPosition(offset: 0)) *
          1.5;
      expect(texto.size.height, lessThan(umaLinha),
          reason: '"Equipamento" quebrou em mais de uma linha');
    });
  });
}
