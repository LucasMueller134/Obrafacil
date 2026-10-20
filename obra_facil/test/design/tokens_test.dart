// Tokens: valores da especificação, ThemeExtension (lerp, copyWith) e o
// `context.cores`, que nunca lança, mesmo sem a extensão no tema.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obra_facil/constants/app_theme.dart';
import 'package:obra_facil/design/design.dart';

import '../visual/suporte/fontes.dart';

void main() {
  setUpAll(() async {
    Tato.ativo = false;
    // O AppTheme antigo usa a Poppins do google_fonts, que no teste não
    // pode ir à rede: o harness das capturas serve os arquivos locais.
    await carregarFontes();
  });

  group('valores da especificação', () {
    test('cores da seção 2, claro e escuro', () {
      String hex(Color c) =>
          '#${c.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
      Map<String, String> tabela(CoresObra c) => {
            'papel': hex(c.papel),
            'folha': hex(c.folha),
            'folhaRebaixada': hex(c.folhaRebaixada),
            'grafite': hex(c.grafite),
            'grafite2': hex(c.grafite2),
            'traco': hex(c.traco),
            'grade': hex(c.grade),
            'marca': hex(c.marca),
            'sobreMarca': hex(c.sobreMarca),
            'marcaTexto': hex(c.marcaTexto),
            'revisao': hex(c.revisao),
            'ok': hex(c.ok),
            'aviso': hex(c.aviso),
            'sobreGrafite': hex(c.sobreGrafite),
          };
      expect(tabela(CoresObra.claro), {
        'papel': '#F4F5F3',
        'folha': '#FFFFFF',
        'folhaRebaixada': '#EBECE8',
        'grafite': '#1A1C1F',
        'grafite2': '#4B5058',
        'traco': '#6E737B',
        'grade': '#DCDFDB',
        'marca': '#F97316',
        'sobreMarca': '#15120F',
        'marcaTexto': '#C2410C',
        'revisao': '#B42318',
        'ok': '#0B6E4F',
        'aviso': '#FFC400',
        'sobreGrafite': '#F4F5F3',
      });
      expect(tabela(CoresObra.escuro), {
        'papel': '#121315',
        'folha': '#1A1C1F',
        'folhaRebaixada': '#23262A',
        'grafite': '#ECEDE9',
        'grafite2': '#A9ADB3',
        'traco': '#7A7F87',
        'grade': '#2C2F34',
        'marca': '#FF8A3D',
        'sobreMarca': '#15120F',
        'marcaTexto': '#FF8A3D',
        'revisao': '#FF6B5B',
        'ok': '#3FBF8A',
        'aviso': '#FFC400',
        'sobreGrafite': '#121315',
      });
    });

    test('espaço, raio, traço e alvos da seção 1 e 4', () {
      expect(
        [
          Espaco.e4,
          Espaco.e8,
          Espaco.e12,
          Espaco.e16,
          Espaco.e24,
          Espaco.e32,
          Espaco.e48,
        ],
        [4, 8, 12, 16, 24, 32, 48],
      );
      expect(Espaco.margem, 16);
      expect(Espaco.entreAlvos, 12);
      expect(
          [Raio.nenhum, Raio.pequeno, Raio.padrao, Raio.folha], [0, 2, 4, 8]);
      expect(Traco.fino, 1.5);
      expect(Traco.forte, 2);
      expect([Alvo.minimo, Alvo.mestre, Alvo.principal], [48, 64, 72]);
    });

    test('movimento da seção 5', () {
      expect(Movimento.rapido, const Duration(milliseconds: 120));
      expect(Movimento.medio, const Duration(milliseconds: 220));
      expect(Movimento.lento, const Duration(milliseconds: 360));
      expect(Movimento.entrar, Curves.easeOutCubic);
      expect(Movimento.sair, Curves.easeInCubic);
      expect(Movimento.mola.mass, 1);
      expect(Movimento.mola.stiffness, 520);
      expect(Movimento.mola.damping, 42);
      expect(Movimento.janelaDesfazer, const Duration(seconds: 4));
    });
  });

  group('CoresObra como ThemeExtension', () {
    test('lerp nas pontas devolve as paletas e no meio mistura', () {
      const a = CoresObra.claro;
      const b = CoresObra.escuro;
      expect(a.lerp(b, 0), a);
      expect(a.lerp(b, 1), b);
      final meio = a.lerp(b, 0.5);
      expect(meio.papel, Color.lerp(a.papel, b.papel, 0.5));
      expect(meio.marca, Color.lerp(a.marca, b.marca, 0.5));
      expect(a.lerp(null, 0.5), a);
    });

    test('copyWith troca só o que foi pedido', () {
      final c = CoresObra.claro.copyWith(marca: const Color(0xFF000000));
      expect(c.marca, const Color(0xFF000000));
      expect(c.copyWith(marca: CoresObra.claro.marca), CoresObra.claro);
      expect(CoresObra.claro.copyWith(), CoresObra.claro);
      expect(CoresObra.claro.copyWith().hashCode, CoresObra.claro.hashCode);
    });

    test('os temas da prancheta carregam a extensão do brilho certo', () {
      expect(TemaPrancheta.claro.extension<CoresObra>(), CoresObra.claro);
      expect(TemaPrancheta.escuro.extension<CoresObra>(), CoresObra.escuro);
    });
  });

  group('context.cores', () {
    Future<CoresObra> ler(
        WidgetTester tester, Widget Function(Widget) em) async {
      late CoresObra lidas;
      await tester.pumpWidget(em(Builder(builder: (context) {
        lidas = context.cores;
        return const SizedBox();
      })));
      return lidas;
    }

    testWidgets('sem Theme nenhum: paleta clara, sem lançar', (tester) async {
      final c = await ler(
        tester,
        (filho) =>
            Directionality(textDirection: TextDirection.ltr, child: filho),
      );
      expect(c, CoresObra.claro);
    });

    testWidgets('tema claro sem a extensão: paleta clara', (tester) async {
      final c = await ler(
        tester,
        (filho) => MaterialApp(theme: ThemeData.light(), home: filho),
      );
      expect(c, CoresObra.claro);
    });

    testWidgets('tema escuro sem a extensão: paleta escura', (tester) async {
      final c = await ler(
        tester,
        (filho) => MaterialApp(theme: ThemeData.dark(), home: filho),
      );
      expect(c, CoresObra.escuro);
    });

    testWidgets('dentro do TemaPrancheta: a extensão do tema', (tester) async {
      final c = await ler(
        tester,
        (filho) => MaterialApp(
          home: TemaPrancheta(brilho: Brightness.dark, child: filho),
        ),
      );
      expect(c, CoresObra.escuro);
    });

    testWidgets('extensão personalizada no tema é respeitada', (tester) async {
      final propria = CoresObra.claro.copyWith(marca: const Color(0xFF00FF00));
      final c = await ler(
        tester,
        (filho) => MaterialApp(
          theme: ThemeData(extensions: [propria]),
          home: filho,
        ),
      );
      expect(c.marca, const Color(0xFF00FF00));
    });

    testWidgets('componentes novos numa tela antiga (AppTheme) não quebram',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                const Folha(child: Text('Folha')),
                const Carimbo(linhas: [
                  [CelulaCarimbo(rotulo: 'Obra', valor: 'Casa')],
                ]),
                const ValorHeroi(valor: 1234.5, rotulo: 'Gasto'),
                const ReguaCota(valor: 0.4, marcador: 0.3, legenda: 'avanço'),
                const SeloStatus(StatusSelo.pendente),
                const NotaRevisao('nota'),
                BotaoPrincipal(rotulo: 'Salvar', aoTocar: () {}),
                const LinhaLista(titulo: 'Linha', valor: 'R\$ 1,00'),
                const EsqueletoFolha(),
              ],
            ),
          ),
        ),
      ));
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
      // O AppTheme antigo é escuro: os componentes pegam a paleta escura.
      final contexto = tester.element(find.byType(Folha).first);
      expect(contexto.cores, CoresObra.escuro);
    });
  });
}
