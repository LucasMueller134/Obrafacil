// Tema da prancheta: ThemeData coerente com os tokens, temas de
// componente das regras da spec e o TemaPrancheta seguindo o sistema.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obra_facil/design/design.dart';

void main() {
  setUpAll(() => Tato.ativo = false);

  for (final (nome, tema, cores) in [
    ('claro', TemaPrancheta.claro, CoresObra.claro),
    ('escuro', TemaPrancheta.escuro, CoresObra.escuro),
  ]) {
    group('ThemeData $nome', () {
      test('Material 3, esquema de cores dos tokens', () {
        expect(tema.useMaterial3, isTrue);
        expect(tema.brightness, cores.brilho);
        expect(tema.colorScheme.brightness, cores.brilho);
        expect(tema.colorScheme.primary, cores.grafite);
        expect(tema.colorScheme.onPrimary, cores.sobreGrafite);
        expect(tema.colorScheme.secondary, cores.marca);
        expect(tema.colorScheme.onSecondary, cores.sobreMarca);
        expect(tema.colorScheme.error, cores.revisao);
        expect(tema.colorScheme.surface, cores.papel);
        expect(tema.colorScheme.onSurface, cores.grafite);
        expect(tema.colorScheme.outline, cores.traco);
        expect(tema.scaffoldBackgroundColor, cores.papel);
        expect(tema.textTheme.bodyMedium?.color, cores.grafite);
        expect(tema.textTheme.bodyMedium?.fontFamily, Tipografia.familiaTexto);
        expect(
            tema.textTheme.displayLarge?.fontFamily, Tipografia.familiaTitulo);
      });

      test('sem InkSparkle: respingo discreto', () {
        expect(tema.splashFactory, isNot(InkSparkle.splashFactory));
        expect(tema.splashFactory, InkRipple.splashFactory);
      });

      test('AppBar sem elevação, sem mudar de cor ao rolar', () {
        final a = tema.appBarTheme;
        expect(a.elevation, 0);
        expect(a.scrolledUnderElevation, 0);
        expect(a.surfaceTintColor?.a, 0);
        expect(a.backgroundColor, cores.papel);
        final icones = cores.brilho == Brightness.light
            ? Brightness.dark
            : Brightness.light;
        expect(a.systemOverlayStyle?.statusBarIconBrightness, icones);
        expect(a.systemOverlayStyle?.systemNavigationBarIconBrightness, icones);
        expect(a.systemOverlayStyle?.statusBarBrightness, cores.brilho);
      });

      test('campos: traço 1,5 e 2 grafite no foco, 64 de altura', () {
        final i = tema.inputDecorationTheme;
        final normal = i.enabledBorder! as OutlineInputBorder;
        final foco = i.focusedBorder! as OutlineInputBorder;
        expect(normal.borderSide.width, Traco.fino);
        expect(normal.borderSide.color, cores.traco);
        expect(foco.borderSide.width, Traco.forte);
        expect(foco.borderSide.color, cores.grafite);
        expect(i.constraints?.minHeight, Alvo.mestre);
      });

      test('folha que sobe de baixo: topo de raio 8 e a única sombra', () {
        final b = tema.bottomSheetTheme;
        final forma = b.shape! as RoundedRectangleBorder;
        expect(forma.borderRadius, Raio.topoFolha);
        expect(b.modalElevation, greaterThan(0));
        expect(tema.dialogTheme.elevation, 0);
        expect(tema.popupMenuTheme.elevation, 0);
        expect(tema.cardTheme.elevation, 0);
      });

      test('aviso (SnackBar) grafite com a ação no laranja', () {
        final s = tema.snackBarTheme;
        expect(s.backgroundColor, cores.grafite);
        expect(s.contentTextStyle?.color, cores.sobreGrafite);
        expect(s.actionBackgroundColor, cores.marca);
        expect(s.actionTextColor, cores.sobreMarca);
      });

      test('campo desabilitado como o botão: sem fundo, contorno tracejado',
          () {
        final i = tema.inputDecorationTheme;
        final borda = i.disabledBorder! as OutlineInputBorder;
        // Não é o OutlineInputBorder liso: é a borda tracejada.
        expect(borda.runtimeType, isNot(OutlineInputBorder));
        expect(borda.borderSide.color, cores.traco);
        expect(CoresObra.contraste(borda.borderSide.color, cores.papel),
            greaterThanOrEqualTo(3));
        final fundo = WidgetStateProperty.resolveAs<Color?>(
            i.fillColor, {WidgetState.disabled});
        expect(fundo?.a, 0);
        expect(WidgetStateProperty.resolveAs<Color?>(i.fillColor, {}),
            cores.folha);
      });

      test('relógio e calendário sem raio grande nem dia em círculo', () {
        // O Material traz o relógio com raio 28 e caixas de raio 8, e o
        // dia escolhido num círculo.
        final r = tema.timePickerTheme;
        expect((r.shape! as RoundedRectangleBorder).borderRadius,
            Raio.cantoPadrao);
        expect((r.hourMinuteShape! as RoundedRectangleBorder).borderRadius,
            Raio.cantoPequeno);
        expect((r.dayPeriodShape! as RoundedRectangleBorder).borderRadius,
            Raio.cantoPequeno);
        expect(r.elevation, 0);
        final d = tema.datePickerTheme;
        expect((d.shape! as RoundedRectangleBorder).borderRadius,
            Raio.cantoPadrao);
        for (final forma in [
          d.dayShape!.resolve({WidgetState.selected}),
          d.yearShape!.resolve({WidgetState.selected}),
        ]) {
          expect((forma! as RoundedRectangleBorder).borderRadius,
              Raio.cantoPequeno);
        }
      });

      test('texto de informação com 15 sp ou mais (rótulo flutuante: 75%)', () {
        final i = tema.inputDecorationTheme;
        // O InputDecorator desenha o rótulo que sobe para a borda a 75%.
        final flutuante = WidgetStateProperty.resolveAs<TextStyle?>(
            i.floatingLabelStyle, <WidgetState>{})!;
        expect(flutuante.fontSize! * 0.75, greaterThanOrEqualTo(15));
        for (final estilo in [
          i.labelStyle,
          i.hintStyle,
          i.helperStyle,
          i.errorStyle,
          i.counterStyle,
          tema.datePickerTheme.headerHelpStyle,
          tema.timePickerTheme.helpTextStyle,
          tema.tooltipTheme.textStyle,
          tema.snackBarTheme.contentTextStyle,
        ]) {
          expect(estilo!.fontSize, greaterThanOrEqualTo(15));
        }
      });

      test('foco e item escolhido do dropdown num véu neutro, não laranja', () {
        // O dropdown pinta o item escolhido com o focusColor: o laranja a
        // 30% virava um marrom no escuro.
        expect(tema.focusColor.withValues(alpha: 1), cores.grafite);
        expect(tema.focusColor.a, lessThan(0.2));
      });

      test('progresso: o que falta aparece no papel e contra o feito', () {
        final p = tema.progressIndicatorTheme;
        for (final trilho in [p.linearTrackColor!, p.circularTrackColor!]) {
          expect(CoresObra.contraste(trilho, cores.papel),
              greaterThanOrEqualTo(3));
          expect(
              CoresObra.contraste(trilho, p.color!), greaterThanOrEqualTo(3));
        }
      });

      test('valor à direita do ListTile na Archivo, como na LinhaLista', () {
        expect(tema.listTileTheme.leadingAndTrailingTextStyle?.fontFamily,
            Tipografia.familiaTitulo);
      });

      test('botões do Material sem elevação nem véu translúcido', () {
        for (final estilo in [
          tema.filledButtonTheme.style!,
          tema.elevatedButtonTheme.style!,
          tema.outlinedButtonTheme.style!,
          tema.textButtonTheme.style!,
        ]) {
          expect(estilo.elevation?.resolve({}), 0);
          expect(estilo.overlayColor?.resolve({WidgetState.pressed})?.a, 0);
          expect(estilo.minimumSize?.resolve({})?.height,
              greaterThanOrEqualTo(Alvo.minimo));
          // Desabilitado: sem fundo, texto grafite2.
          expect(estilo.backgroundColor?.resolve({WidgetState.disabled})?.a, 0);
          expect(estilo.foregroundColor?.resolve({WidgetState.disabled}),
              cores.grafite2);
        }
      });
    });
  }

  group('TemaPrancheta', () {
    Future<(ThemeData, SystemUiOverlayStyle)> montarCom(
      WidgetTester tester, {
      Brightness? forcado,
    }) async {
      late ThemeData lido;
      await tester.pumpWidget(MaterialApp(
        home: TemaPrancheta(
          brilho: forcado,
          child: Builder(builder: (context) {
            lido = Theme.of(context);
            return const Scaffold();
          }),
        ),
      ));
      await tester.pump(const Duration(seconds: 1));
      final regiao = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
        find
            .descendant(
              of: find.byType(TemaPrancheta),
              matching: find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
            )
            .first,
      );
      return (lido, regiao.value);
    }

    testWidgets('segue o sistema: claro', (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      final (tema, barras) = await montarCom(tester);
      expect(tema.brightness, Brightness.light);
      expect(tema.extension<CoresObra>(), CoresObra.claro);
      expect(barras.statusBarIconBrightness, Brightness.dark);
    });

    testWidgets('segue o sistema: escuro', (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      final (tema, barras) = await montarCom(tester);
      expect(tema.brightness, Brightness.dark);
      expect(tema.extension<CoresObra>(), CoresObra.escuro);
      expect(barras.statusBarIconBrightness, Brightness.light);
      expect(barras.systemNavigationBarColor, CoresObra.escuro.papel);
    });

    testWidgets('brilho forçado vence o sistema', (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      final (tema, _) = await montarCom(tester, forcado: Brightness.light);
      expect(tema.brightness, Brightness.light);
    });

    testWidgets('o tema global do app não muda fora do TemaPrancheta',
        (tester) async {
      late ThemeData fora;
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(colorSchemeSeed: Colors.blue),
        home: Builder(builder: (context) {
          fora = Theme.of(context);
          return const TemaPrancheta(child: SizedBox());
        }),
      ));
      expect(fora.extension<CoresObra>(), isNull);
    });

    testWidgets('a AppBar não muda de cor ao rolar o conteúdo', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: TemaPrancheta(
          brilho: Brightness.light,
          child: Scaffold(
            appBar: AppBar(title: const Text('Obra')),
            body: ListView(
              children: [
                for (var i = 0; i < 40; i++)
                  LinhaLista(titulo: 'Item $i', valor: 'R\$ $i,00'),
              ],
            ),
          ),
        ),
      ));
      Material materialDaBarra() => tester.widget<Material>(find
          .descendant(of: find.byType(AppBar), matching: find.byType(Material))
          .first);
      final antes = materialDaBarra();
      await tester.drag(find.byType(ListView), const Offset(0, -600));
      await tester.pump(const Duration(seconds: 1));
      final depois = materialDaBarra();
      expect(depois.color, CoresObra.claro.papel);
      expect(depois.color, antes.color);
      expect(depois.elevation, 0);
    });
  });
}
