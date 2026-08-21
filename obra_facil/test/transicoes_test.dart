import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:obra_facil/constants/app_colors.dart';
import 'package:obra_facil/router/transicoes.dart';

/// Uma tela cheia qualquer, marcada para ser encontrada no teste.
Widget _tela(String rotulo, Key chave) => Scaffold(
      key: chave,
      backgroundColor: AppColors.fundo,
      body: Center(child: Text(rotulo)),
    );

/// Todas as opacidades aplicadas sobre este widget na árvore.
List<double> _opacidadesSobre(WidgetTester tester, Key chave) {
  final fades = tester.widgetList<FadeTransition>(
    find.ancestor(
      of: find.byKey(chave),
      matching: find.byType(FadeTransition),
    ),
  );
  return [for (final f in fades) f.opacity.value];
}

void main() {
  const chaveA = ValueKey('telaA');
  const chaveB = ValueKey('telaB');

  group('Transição de empilhar (entrar mais fundo)', () {
    testWidgets('nenhuma das duas telas fica transparente no meio do caminho',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            key: chaveA,
            backgroundColor: AppColors.fundo,
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context)
                    .push(rotaSuave(_tela('B', chaveB))),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('abrir'));
      // Meio da transição: é aqui que o fade cruzado deixava as duas
      // telas translúcidas, uma aparecendo através da outra.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      expect(find.byKey(chaveA), findsOneWidget);
      expect(find.byKey(chaveB), findsOneWidget);
      for (final opacidade in [
        ..._opacidadesSobre(tester, chaveA),
        ..._opacidadesSobre(tester, chaveB),
      ]) {
        expect(opacidade, 1.0,
            reason: 'nenhuma tela pode ficar semitransparente');
      }

      await tester.pumpAndSettle();
      expect(find.text('B'), findsOneWidget);
    });

    testWidgets('a tela nova entra pela direita e chega ao lugar',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context)
                    .push(rotaSuave(_tela('B', chaveB))),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      ));
      final largura = tester.getSize(find.byType(MaterialApp)).width;

      await tester.tap(find.text('abrir'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));

      // Ainda a caminho: encostada na borda direita.
      expect(tester.getTopLeft(find.byKey(chaveB)).dx, greaterThan(0));
      expect(tester.getTopLeft(find.byKey(chaveB)).dx, lessThan(largura));

      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.byKey(chaveB)).dx, 0);
    });
  });

  group('Transição de troca de área', () {
    testWidgets('o fundo é opaco desde o começo, então nada aparece atrás',
        (tester) async {
      final router = GoRouter(
        initialLocation: '/a',
        routes: [
          GoRoute(
            path: '/a',
            pageBuilder: (_, state) => paginaRaiz(state, _tela('A', chaveA)),
          ),
          GoRoute(
            path: '/b',
            pageBuilder: (_, state) => paginaRaiz(state, _tela('B', chaveB)),
          ),
        ],
      );
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      router.go('/b');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));

      // O conteúdo da tela nova pode estar surgindo…
      final opacidades = _opacidadesSobre(tester, chaveB);
      expect(opacidades, isNotEmpty);
      // …mas atrás dele existe um fundo opaco cobrindo a tela anterior.
      final fundos = tester.widgetList<ColoredBox>(
        find.ancestor(
          of: find.byKey(chaveB),
          matching: find.byType(ColoredBox),
        ),
      );
      expect(
        fundos.any((c) => c.color.a == 1.0),
        isTrue,
        reason: 'sem fundo opaco, a tela de baixo apareceria através',
      );

      await tester.pumpAndSettle();
      expect(find.text('B'), findsOneWidget);
    });
  });
}
