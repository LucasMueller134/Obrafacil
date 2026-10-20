// Componentes: alvos de toque mínimos (seção 1), estados (pressionado,
// carregando, desabilitado), leitor de tela, status nunca só por cor e a
// vibração opcional.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obra_facil/design/catalogo_design.dart';
import 'package:obra_facil/design/design.dart';

import 'suporte/montar.dart';

void main() {
  setUp(() => Tato.ativo = true);

  group('alvos de toque', () {
    testWidgets('BotaoPrincipal 64 dp; grande 72 dp', (tester) async {
      await tester.pumpWidget(montar(Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          BotaoPrincipal(key: const Key('n'), rotulo: 'Salvar', aoTocar: () {}),
          BotaoPrincipal(
              key: const Key('g'),
              rotulo: 'Salvar',
              grande: true,
              aoTocar: () {}),
        ],
      )));
      expect(tester.getSize(find.byKey(const Key('n'))).height, Alvo.mestre);
      expect(tester.getSize(find.byKey(const Key('g'))).height, Alvo.principal);
      expect(tester.getSize(find.byKey(const Key('n'))).width,
          greaterThanOrEqualTo(Alvo.mestre));
    });

    testWidgets('BotaoMarca e BotaoContorno ≥ 64 dp, também desabilitados',
        (tester) async {
      await tester.pumpWidget(montar(Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          BotaoMarca(key: const Key('m'), rotulo: 'Lançar', aoTocar: () {}),
          BotaoContorno(key: const Key('c'), rotulo: 'Ler', aoTocar: () {}),
          const BotaoMarca(key: Key('md'), rotulo: 'Lançar', aoTocar: null),
          const BotaoContorno(key: Key('cd'), rotulo: 'Ler', aoTocar: null),
        ],
      )));
      for (final k in ['m', 'c', 'md', 'cd']) {
        expect(tester.getSize(find.byKey(Key(k))).height,
            greaterThanOrEqualTo(Alvo.mestre),
            reason: k);
      }
    });

    testWidgets('BotaoIcone 64 x 64', (tester) async {
      await tester.pumpWidget(montar(BotaoIcone(
        icone: Icons.add,
        rotulo: 'Lançar gasto',
        aoTocar: () {},
      )));
      expect(tester.getSize(find.byType(BotaoIcone)), const Size(64, 64));
    });

    testWidgets('LinhaLista ≥ 72 dp, com e sem apoio', (tester) async {
      await tester.pumpWidget(montar(Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const LinhaLista(key: Key('s'), titulo: 'Areia'),
          LinhaLista(
            key: const Key('a'),
            titulo: 'Areia média',
            apoio: '6 m³ · Areial',
            valor: 'R\$ 840,00',
            fim: const SeloStatus(StatusSelo.pendente),
            aoTocar: () {},
          ),
        ],
      )));
      for (final k in ['s', 'a']) {
        expect(tester.getSize(find.byKey(Key(k))).height,
            greaterThanOrEqualTo(Alvo.principal),
            reason: k);
      }
    });

    testWidgets('BarraDeAcao: 12 dp entre a ação e o botão de ícone',
        (tester) async {
      await tester.pumpWidget(montar(Builder(
        builder: (context) => BarraDeAcao(
          principal: BotaoPrincipal(rotulo: 'Revisar', aoTocar: () {}),
          secundaria: BotaoIcone(
            icone: Icons.add,
            rotulo: 'Lançar',
            estilo: EstiloBotaoIcone.marca,
            aoTocar: () {},
          ),
        ),
      )));
      final a = tester.getRect(find.byType(BotaoPrincipal));
      final b = tester.getRect(find.byType(BotaoIcone));
      expect(b.left - a.right, greaterThanOrEqualTo(Espaco.entreAlvos));
    });

    testWidgets('BarraDeAcao sobe com o teclado e respeita a barra de gestos',
        (tester) async {
      definirTela(tester, 390, 800);
      tester.view.padding = const FakeViewPadding(bottom: 24);
      await tester.pumpWidget(montar(const SizedBox()));
      Widget tela() => MaterialApp(
            home: TemaPrancheta(
              child: Scaffold(
                body: const SizedBox.expand(),
                bottomNavigationBar: BarraDeAcao(
                  principal: BotaoPrincipal(rotulo: 'Salvar', aoTocar: () {}),
                ),
              ),
            ),
          );
      await tester.pumpWidget(tela());
      final semTeclado = tester.getRect(find.byType(BotaoPrincipal));
      expect(800 - semTeclado.bottom, greaterThanOrEqualTo(24 + Espaco.e12));

      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpWidget(tela());
      final comTeclado = tester.getRect(find.byType(BotaoPrincipal));
      expect(comTeclado.bottom, lessThanOrEqualTo(800 - 300));
    });

    testWidgets('componentes do Material: 48 dp; chip 48; campo 64',
        (tester) async {
      await tester.pumpWidget(montar(
        rolavel: true,
        Column(
          children: [
            FilledButton(
                key: const Key('FilledButton'),
                onPressed: () {},
                child: const Text('Filled')),
            OutlinedButton(
                key: const Key('OutlinedButton'),
                onPressed: () {},
                child: const Text('Outlined')),
            TextButton(
                key: const Key('TextButton'),
                onPressed: () {},
                child: const Text('Text')),
            IconButton(
                key: const Key('IconButton'),
                onPressed: () {},
                icon: const Icon(Icons.add)),
            ChoiceChip(
                label: const Text('Semana'),
                selected: true,
                onSelected: (_) {}),
            FilterChip(
                label: const Text('Alvenaria'),
                selected: false,
                onSelected: (_) {}),
            const Chip(label: Text('Só leitura')),
            const TextField(decoration: InputDecoration(labelText: 'Valor')),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 1, label: Text('Hoje')),
                ButtonSegment(value: 2, label: Text('Semana')),
              ],
              selected: const {1},
              onSelectionChanged: (_) {},
            ),
          ],
        ),
      ));
      for (final tipo in [
        'FilledButton',
        'OutlinedButton',
        'TextButton',
        'IconButton',
      ]) {
        final s = tester.getSize(find.byKey(Key(tipo)));
        expect(s.height, greaterThanOrEqualTo(Alvo.minimo), reason: tipo);
        expect(s.width, greaterThanOrEqualTo(Alvo.minimo), reason: tipo);
      }
      // A forma desenhada do chip (não só a área de toque) tem 48 dp.
      for (final rotulo in ['Semana', 'Alvenaria', 'Só leitura']) {
        final forma = find.ancestor(
          of: find.text(rotulo),
          matching: find.byWidgetPredicate(
              (w) => w is Material && w.shape is RoundedRectangleBorder),
        );
        expect(tester.getSize(forma.first).height, Alvo.minimo, reason: rotulo);
      }
      expect(tester.getSize(find.byType(InputDecorator)).height,
          greaterThanOrEqualTo(Alvo.mestre));
      expect(tester.getSize(find.byType(SegmentedButton<int>)).height,
          greaterThanOrEqualTo(Alvo.minimo));
    });

    testWidgets('catálogo inteiro passa nas diretrizes de alvo de toque',
        (tester) async {
      definirTela(tester, 390, 844);
      final semantica = tester.ensureSemantics();
      await tester.pumpWidget(const MaterialApp(
        home: CatalogoDesign(brilho: Brightness.light),
      ));
      await tester.pump(const Duration(seconds: 1));
      // Estica a tela até caber a página toda: um alvo cortado pela borda
      // da rolagem pareceria pequeno sem ser.
      final rolagem =
          tester.state<ScrollableState>(find.byType(Scrollable).first);
      definirTela(tester, 390, 844 + rolagem.position.maxScrollExtent);
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      semantica.dispose();
    });
  });

  group('estados dos botões', () {
    testWidgets('pressionado: encolhe e troca o fundo por cor sólida',
        (tester) async {
      await tester.pumpWidget(montar(
        BotaoPrincipal(rotulo: 'Salvar', aoTocar: () {}, vibrar: false),
      ));
      Color fundo() {
        final caixa = tester.widget<AnimatedContainer>(find.descendant(
          of: find.byType(BotaoPrincipal),
          matching: find.byType(AnimatedContainer),
        ));
        return (caixa.decoration! as BoxDecoration).color!;
      }

      double escala() => tester
          .widget<AnimatedScale>(find.descendant(
            of: find.byType(BotaoPrincipal),
            matching: find.byType(AnimatedScale),
          ))
          .scale;

      expect(fundo(), CoresObra.claro.grafite);
      expect(escala(), 1);
      final gesto = await tester
          .startGesture(tester.getCenter(find.byType(BotaoPrincipal)));
      await tester.pump(const Duration(milliseconds: 200));
      expect(escala(), lessThan(1));
      expect(fundo(), CoresObra.claro.grafite2);
      expect(fundo().a, 1, reason: 'estado em cor sólida, sem véu');
      await gesto.up();
      await tester.pump(const Duration(milliseconds: 200));
      expect(escala(), 1);
    });

    testWidgets('carregando: indicador, não aceita toque, leitor avisa',
        (tester) async {
      var toques = 0;
      final semantica = tester.ensureSemantics();
      await tester.pumpWidget(montar(BotaoPrincipal(
        rotulo: 'Salvar',
        carregando: true,
        aoTocar: () => toques++,
      )));
      expect(find.byType(IndicadorCarregando), findsOneWidget);
      await tester.tap(find.byType(BotaoPrincipal));
      await tester.pump(const Duration(milliseconds: 200));
      expect(toques, 0);
      expect(find.bySemanticsLabel('Salvar, carregando'), findsOneWidget);
      semantica.dispose();
    });

    testWidgets('carregando com "reduzir animações": ampulheta parada',
        (tester) async {
      await tester.pumpWidget(montar(
        semAnimacao: true,
        BotaoIcone(
          icone: Icons.send,
          rotulo: 'Enviar',
          carregando: true,
          aoTocar: () {},
        ),
      ));
      expect(
        find.descendant(
          of: find.byType(BotaoIcone),
          matching: find.byType(RotationTransition),
        ),
        findsNothing,
      );
      expect(find.byIcon(Icons.hourglass_top), findsOneWidget);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('desabilitado: tracejado, texto legível, sem toque',
        (tester) async {
      final semantica = tester.ensureSemantics();
      await tester.pumpWidget(montar(
        const BotaoPrincipal(rotulo: 'Salvar gasto', aoTocar: null),
      ));
      final texto = tester.widget<Text>(find.text('Salvar gasto'));
      expect(texto.style?.color, CoresObra.claro.grafite2);
      expect(
        find.descendant(
          of: find.byType(BotaoPrincipal),
          matching: find.byWidgetPredicate((w) =>
              w is CustomPaint && w.foregroundPainter is ContornoTracejado),
        ),
        findsOneWidget,
      );
      expect(
        tester.getSemantics(find.byType(BotaoPrincipal)),
        isSemantics(
          label: 'Salvar gasto',
          isButton: true,
          hasEnabledState: true,
          isEnabled: false,
        ),
      );
      semantica.dispose();
    });

    testWidgets('leitor de tela: botão de ícone lê o rótulo e é tocável',
        (tester) async {
      final semantica = tester.ensureSemantics();
      await tester.pumpWidget(montar(BotaoIcone(
        icone: Icons.add,
        rotulo: 'Lançar gasto',
        aoTocar: () {},
      )));
      expect(
        tester.getSemantics(find.byType(AreaPressionavel)),
        isSemantics(
          label: 'Lançar gasto',
          isButton: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );
      semantica.dispose();
    });

    testWidgets('foco de teclado: contorno laranja de 3 dp', (tester) async {
      await tester.pumpWidget(montar(
        BotaoContorno(rotulo: 'Ler', aoTocar: () {}),
      ));
      // Tab do teclado leva o foco ao botão.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump(const Duration(milliseconds: 200));
      final caixa = tester.widget<AnimatedContainer>(find.descendant(
        of: find.byType(BotaoContorno),
        matching: find.byType(AnimatedContainer),
      ));
      final anel = caixa.foregroundDecoration as BoxDecoration?;
      expect(anel, isNotNull);
      final borda = anel!.border! as Border;
      expect(borda.top.width, 3);
      expect(borda.top.color, CoresObra.claro.marcaTexto);
    });
  });

  group('status nunca só por cor', () {
    testWidgets('SeloStatus: forma e texto para cada status', (tester) async {
      await tester.pumpWidget(montar(const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SeloStatus(StatusSelo.pendente, key: Key('p')),
          SeloStatus(StatusSelo.aprovado, key: Key('a')),
          SeloStatus(StatusSelo.recusado, key: Key('r')),
          SeloStatus(StatusSelo.aviso, key: Key('v')),
        ],
      )));
      Finder em(String k, Finder f) =>
          find.descendant(of: find.byKey(Key(k)), matching: f);
      expect(em('p', find.byType(CaixaHachurada)), findsOneWidget);
      expect(em('a', find.byIcon(Icons.check)), findsOneWidget);
      expect(em('r', find.byIcon(Icons.close)), findsOneWidget);
      expect(em('v', find.byIcon(Icons.warning_amber)), findsOneWidget);
      for (final t in ['Pendente', 'Aprovado', 'Recusado', 'Atenção']) {
        expect(find.textContaining(t, findRichText: true), findsOneWidget);
      }
    });

    testWidgets('LinhaLista tocável: um nó só, com o status junto',
        (tester) async {
      // Antes o selo ficava como um nó solto dentro do botão: o leitor de
      // tela lia a linha sem o status.
      final semantica = tester.ensureSemantics();
      await tester.pumpWidget(montar(LinhaLista(
        titulo: 'Areia média',
        apoio: '6 m³',
        valor: 'R\$ 840,00',
        fim: const SeloStatus(StatusSelo.pendente),
        aoTocar: () {},
      )));
      expect(
        tester.getSemantics(find.text('Areia média')),
        isSemantics(
          label: 'Areia média\nR\$ 840,00\n6 m³\nStatus: Pendente',
          isButton: true,
          hasTapAction: true,
        ),
      );
      semantica.dispose();
    });

    testWidgets('SeletorGrande: a escolhida ganha check, não só cor',
        (tester) async {
      String? escolhido = 'a';
      await tester.pumpWidget(montar(StatefulBuilder(
        builder: (context, setState) => SizedBox(
          width: 360,
          child: SeletorGrande<String>(
            opcoes: const [
              OpcaoSeletor(valor: 'a', rotulo: 'Pix'),
              OpcaoSeletor(valor: 'b', rotulo: 'Dinheiro'),
            ],
            selecionado: escolhido,
            aoMudar: (v) => setState(() => escolhido = v),
          ),
        ),
      )));
      expect(find.byIcon(Icons.check), findsOneWidget);
      await tester.tap(find.textContaining('Dinheiro', findRichText: true));
      await tester.pump(const Duration(milliseconds: 300));
      expect(escolhido, 'b');
      expect(find.byIcon(Icons.check), findsOneWidget);
    });
  });

  group('vibração (Tato)', () {
    testWidgets('botão vibra leve ao tocar; com vibrar: false, não',
        (tester) async {
      final vibracoes = gravarVibracoes(tester);
      await tester.pumpWidget(montar(Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          BotaoPrincipal(key: const Key('sim'), rotulo: 'A', aoTocar: () {}),
          BotaoPrincipal(
            key: const Key('nao'),
            rotulo: 'B',
            aoTocar: () {},
            vibrar: false,
          ),
        ],
      )));
      await tester.tap(find.byKey(const Key('sim')));
      await tester.pump();
      expect(vibracoes, ['HapticFeedbackType.selectionClick']);
      await tester.tap(find.byKey(const Key('nao')));
      await tester.pump();
      expect(vibracoes, hasLength(1));
    });

    testWidgets('confirmar e erro vibram diferente; Tato.ativo desliga',
        (tester) async {
      final vibracoes = gravarVibracoes(tester);
      await Tato.leve();
      await Tato.confirmar();
      await Tato.erro();
      expect(vibracoes, [
        'HapticFeedbackType.selectionClick',
        'HapticFeedbackType.mediumImpact',
        // O erro usa a vibração longa (LONG_PRESS no Android): o
        // heavyImpact vira CONTEXT_CLICK, tão fraco quanto a confirmação.
        'padrao',
      ]);
      Tato.ativo = false;
      await Tato.confirmar();
      expect(vibracoes, hasLength(3));
    });
  });

  group('dentro de diálogo e de IntrinsicHeight', () {
    // O AlertDialog (e o menu, e o SimpleDialog) mede o conteúdo com
    // IntrinsicWidth antes de montar. Com LayoutBuilder, isso derrubava a
    // tela ("LayoutBuilder does not support returning intrinsic
    // dimensions").
    testWidgets('lista, seletor, régua e linha de cota num AlertDialog',
        (tester) async {
      await tester.pumpWidget(montar(Builder(
        builder: (context) => TextButton(
          onPressed: () => showDialog<void>(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('Qual obra?'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LinhaLista(
                    titulo: 'Sobrado Vila Izabel',
                    apoio: 'Alvenaria · semana 14',
                    valor: 'R\$ 112.380,00',
                    fim: const SeloStatus(StatusSelo.aviso),
                    aoTocar: () {},
                  ),
                  const ParComValor(
                    esquerda: Text('Total'),
                    direita: Text('R\$ 4.912,40'),
                  ),
                  const LinhaCota(legenda: 'Semana 14'),
                  const ReguaCota(
                    valor: 0.43,
                    marcador: 0.38,
                    legenda: 'avanço 38%',
                  ),
                  SeletorGrande<int>(
                    rotulo: 'Pagamento',
                    opcoes: const [
                      OpcaoSeletor(valor: 1, rotulo: 'Pix'),
                      OpcaoSeletor(valor: 2, rotulo: 'Dinheiro'),
                      OpcaoSeletor(valor: 3, rotulo: 'Cartão'),
                    ],
                    selecionado: 1,
                    aoMudar: (_) {},
                  ),
                ],
              ),
            ),
          ),
          child: const Text('abrir'),
        ),
      )));
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Sobrado Vila Izabel'), findsOneWidget);
      expect(
          find.textContaining('Dinheiro', findRichText: true), findsOneWidget);
    });

    testWidgets('ParComValor: altura intrínseca igual à montada',
        (tester) async {
      await tester.pumpWidget(montar(SizedBox(
        width: 300,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const ColoredBox(
                  color: Color(0xFF000000), child: SizedBox(width: 4)),
              Expanded(
                child: ParComValor(
                  key: const Key('par'),
                  esquerda: const Text('Bloco cerâmico de vedação 9 furos'),
                  direita: Text('R\$ 2.380,00',
                      style: Tipografia.valorHeroi.copyWith(fontSize: 30)),
                ),
              ),
            ],
          ),
        ),
      )));
      final par = tester.renderObject<RenderBox>(find.byKey(const Key('par')));
      expect(par.getMaxIntrinsicHeight(par.size.width), par.size.height);
      expect(tester.takeException(), isNull);
    });

    testWidgets('ParComValor: direita até a fração, esquerda com o resto',
        (tester) async {
      await tester.pumpWidget(montar(const SizedBox(
        width: 300,
        child: ParComValor(
          esquerda: SizedBox(key: Key('e'), height: 20),
          direita: SizedBox(key: Key('d'), width: 500, height: 20),
        ),
      )));
      expect(tester.getSize(find.byKey(const Key('d'))).width, 300 * 0.45);
      expect(tester.getSize(find.byKey(const Key('e'))).width,
          300 - 300 * 0.45 - Espaco.e12);
    });
  });

  group('aviso com desfazer (mostrarAviso)', () {
    Future<BuildContext> tela(WidgetTester tester,
        {bool acessivel = false}) async {
      late BuildContext contexto;
      await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
          data:
              MediaQuery.of(context).copyWith(accessibleNavigation: acessivel),
          child: child!,
        ),
        home: TemaPrancheta(
          brilho: Brightness.light,
          child: Scaffold(
            body: Builder(builder: (context) {
              contexto = context;
              return const SizedBox.expand();
            }),
          ),
        ),
      ));
      return contexto;
    }

    testWidgets('some sozinho em 4 s; o SnackBar com ação ficaria para sempre',
        (tester) async {
      final contexto = await tela(tester);
      mostrarAviso(contexto, 'Gasto aprovado.', aoDesfazer: () {});
      await tester.pumpAndSettle();
      expect(find.text('Gasto aprovado.'), findsOneWidget);
      await tester.pump(Movimento.janelaDesfazer);
      await tester.pumpAndSettle();
      expect(find.text('Gasto aprovado.'), findsNothing);

      // A contraprova: montado à mão, com SnackBarAction, não sai.
      ScaffoldMessenger.of(contexto).showSnackBar(SnackBar(
        content: const Text('À mão'),
        duration: Movimento.janelaDesfazer,
        action: SnackBarAction(label: 'Desfazer', onPressed: () {}),
      ));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();
      expect(find.text('À mão'), findsOneWidget);
    });

    testWidgets('com leitor de tela, espera o toque no Desfazer',
        (tester) async {
      final contexto = await tela(tester, acessivel: true);
      mostrarAviso(contexto, 'Gasto aprovado.', aoDesfazer: () {});
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();
      expect(find.text('Gasto aprovado.'), findsOneWidget);
    });

    testWidgets('Desfazer: laranja, texto preto, 48 dp, cantos de 2 dp',
        (tester) async {
      var desfez = 0;
      final contexto = await tela(tester);
      mostrarAviso(contexto, 'Gasto aprovado.', aoDesfazer: () => desfez++);
      await tester.pumpAndSettle();
      final caixa = find.ancestor(
        of: find.text('Desfazer'),
        matching: find.byType(AnimatedContainer),
      );
      final decoracao =
          tester.widget<AnimatedContainer>(caixa).decoration! as BoxDecoration;
      expect(decoracao.color, CoresObra.claro.marca);
      expect(decoracao.borderRadius, Raio.cantoPequeno);
      expect(tester.getSize(caixa).height, greaterThanOrEqualTo(Alvo.minimo));
      expect(tester.widget<Text>(find.text('Desfazer')).style?.color,
          CoresObra.claro.sobreMarca);
      // Nada da pílula do TextButton do Material.
      expect(
        find.descendant(
            of: find.byType(SnackBar), matching: find.byType(TextButton)),
        findsNothing,
      );
      await tester.tap(find.text('Desfazer'));
      await tester.pumpAndSettle();
      expect(desfez, 1);
      expect(find.text('Gasto aprovado.'), findsNothing);
    });

    testWidgets('um aviso novo substitui o anterior, sem fila', (tester) async {
      final contexto = await tela(tester);
      mostrarAviso(contexto, 'Primeiro aprovado.', aoDesfazer: () {});
      await tester.pumpAndSettle();
      mostrarAviso(contexto, 'Segundo aprovado.', aoDesfazer: () {});
      await tester.pumpAndSettle();
      expect(find.text('Primeiro aprovado.'), findsNothing);
      expect(find.text('Segundo aprovado.'), findsOneWidget);
    });
  });
}
