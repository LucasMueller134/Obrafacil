// Tema Material 3 da prancheta, claro e escuro.
//
// As telas redesenhadas se envolvem com [TemaPrancheta]; o tema global do
// app continua o antigo até todas as telas mudarem. Regras que valem aqui:
// nenhuma sombra nas superfícies (hierarquia por papel/folha + borda; só a
// folha que sobe de baixo tem uma curta), cantos quase retos e o estado
// pressionado em cor sólida ou forma nos componentes da prancheta e nos
// botões do Material. Os widgets do Material que desenham o toque com
// InkWell (ListTile, chips, item de menu) ficam com um véu neutro e
// discreto, porque o fundo deles varia e uma cor sólida esconderia o texto.

import 'dart:math' as math;
import 'dart:ui' show ClipOp, lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'componentes/tracejado.dart';

import 'movimento.dart';
import 'tipografia.dart';
import 'tokens.dart';

/// Aplica o tema da prancheta à subárvore, claro ou escuro conforme o
/// sistema, e acerta a cor dos ícones da barra de status e de navegação.
class TemaPrancheta extends StatelessWidget {
  const TemaPrancheta({super.key, required this.child, this.brilho});

  final Widget child;

  /// Força claro ou escuro (catálogo, testes). Nulo: segue o sistema.
  final Brightness? brilho;

  static final ThemeData claro = montar(CoresObra.claro);
  static final ThemeData escuro = montar(CoresObra.escuro);

  static ThemeData doBrilho(Brightness brilho) =>
      brilho == Brightness.dark ? escuro : claro;

  /// Barra de status transparente com ícones legíveis sobre o papel, e
  /// barra de navegação da cor do papel.
  static SystemUiOverlayStyle barrasDoSistema(Brightness brilho) {
    final cores = CoresObra.doBrilho(brilho);
    final claroNoFundo = brilho == Brightness.light;
    final icones = claroNoFundo ? Brightness.dark : Brightness.light;
    return SystemUiOverlayStyle(
      statusBarColor: const Color(0x00000000),
      statusBarIconBrightness: icones,
      // iOS: o brilho do fundo, não dos ícones.
      statusBarBrightness: brilho,
      systemNavigationBarColor: cores.papel,
      systemNavigationBarDividerColor: cores.papel,
      systemNavigationBarIconBrightness: icones,
      systemNavigationBarContrastEnforced: false,
      systemStatusBarContrastEnforced: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final b = brilho ??
        MediaQuery.maybePlatformBrightnessOf(context) ??
        Brightness.light;
    final tema = doBrilho(b);
    final cores = tema.extension<CoresObra>()!;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: barrasDoSistema(b),
      child: AnimatedTheme(
        data: tema,
        duration: context.duracao(Movimento.medio),
        curve: Movimento.entrar,
        child: DefaultTextStyle(
          style: Tipografia.corpo.copyWith(color: cores.grafite),
          child: child,
        ),
      ),
    );
  }

  /// Monta o [ThemeData] para uma paleta.
  static ThemeData montar(CoresObra c) {
    final ehClaro = c.brilho == Brightness.light;
    final esquema = ColorScheme(
      brightness: c.brilho,
      primary: c.grafite,
      onPrimary: c.sobreGrafite,
      primaryContainer: c.grafite,
      onPrimaryContainer: c.sobreGrafite,
      secondary: c.marca,
      onSecondary: c.sobreMarca,
      secondaryContainer: c.grafite,
      onSecondaryContainer: c.sobreGrafite,
      tertiary: c.ok,
      onTertiary: ehClaro ? c.folha : c.sobreMarca,
      tertiaryContainer: c.folha,
      onTertiaryContainer: c.ok,
      error: c.revisao,
      onError: ehClaro ? c.folha : c.sobreMarca,
      errorContainer: c.folha,
      onErrorContainer: c.revisao,
      surface: c.papel,
      onSurface: c.grafite,
      onSurfaceVariant: c.grafite2,
      surfaceDim: c.folhaRebaixada,
      surfaceBright: c.folha,
      surfaceContainerLowest: c.folha,
      surfaceContainerLow: c.folha,
      surfaceContainer: c.folha,
      surfaceContainerHigh: c.folha,
      surfaceContainerHighest: c.folhaRebaixada,
      outline: c.traco,
      outlineVariant: c.grade,
      shadow: const Color(0xFF000000),
      scrim: const Color(0xFF000000),
      inverseSurface: c.grafite,
      onInverseSurface: c.sobreGrafite,
      inversePrimary: c.marca,
      surfaceTint: const Color(0x00000000),
    );
    const transparente = Color(0x00000000);
    const semCor = WidgetStatePropertyAll<Color>(transparente);

    BorderSide borda(Color cor, [double largura = Traco.fino]) =>
        BorderSide(color: cor, width: largura);
    OutlineInputBorder bordaCampo(Color cor, double largura) =>
        OutlineInputBorder(
          borderRadius: Raio.cantoPadrao,
          borderSide: borda(cor, largura),
        );

    // Botões do Material: estado pressionado em cor sólida, sem respingo;
    // foco com contorno laranja de 3 dp.
    ButtonStyle botao({
      required Color fundo,
      required Color frente,
      required Color fundoPressionado,
      BorderSide? contorno,
      double altura = Alvo.minimo,
      TextStyle estiloTexto = Tipografia.subtitulo,
      EdgeInsets preenchimento =
          const EdgeInsets.symmetric(horizontal: Espaco.e24),
    }) {
      return ButtonStyle(
        minimumSize: WidgetStatePropertyAll(Size(altura, altura)),
        padding: WidgetStatePropertyAll(preenchimento),
        shape: const WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: Raio.cantoPequeno),
        ),
        textStyle: WidgetStatePropertyAll(estiloTexto),
        elevation: const WidgetStatePropertyAll(0),
        shadowColor: semCor,
        surfaceTintColor: semCor,
        overlayColor: semCor,
        splashFactory: NoSplash.splashFactory,
        iconSize: const WidgetStatePropertyAll(24),
        visualDensity: VisualDensity.standard,
        tapTargetSize: MaterialTapTargetSize.padded,
        animationDuration: Movimento.rapido,
        // Desabilitado: sem fundo, contorno no traço e texto grafite2
        // (7:1 no papel; no fundo recuado ficaria abaixo disso).
        backgroundColor: WidgetStateProperty.resolveWith((s) {
          if (s.contains(WidgetState.disabled)) return transparente;
          if (s.contains(WidgetState.pressed)) return fundoPressionado;
          return fundo;
        }),
        foregroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.disabled) ? c.grafite2 : frente,
        ),
        iconColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.disabled) ? c.grafite2 : frente,
        ),
        side: WidgetStateProperty.resolveWith((s) {
          if (s.contains(WidgetState.focused)) return borda(c.marcaTexto, 3);
          if (s.contains(WidgetState.disabled)) {
            return fundo == transparente && contorno == null
                ? null
                : borda(c.traco);
          }
          return contorno;
        }),
      );
    }

    final principal = botao(
      fundo: c.grafite,
      frente: c.sobreGrafite,
      fundoPressionado: c.grafite2,
      altura: 56,
    );

    final estiloMenu = MenuStyle(
      backgroundColor: WidgetStatePropertyAll(c.folha),
      surfaceTintColor: semCor,
      shadowColor: semCor,
      elevation: const WidgetStatePropertyAll(0),
      side: WidgetStatePropertyAll(borda(c.grafite)),
      shape: const WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: Raio.cantoPadrao),
      ),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(vertical: Espaco.e4),
      ),
    );

    Color corDoChip(Set<WidgetState> s) {
      if (s.contains(WidgetState.selected)) return c.grafite;
      if (s.contains(WidgetState.disabled)) return transparente;
      if (s.contains(WidgetState.pressed)) return c.folhaRebaixada;
      return c.folha;
    }

    final textoDoChip = WidgetStateColor.resolveWith((s) {
      if (s.contains(WidgetState.selected)) return c.sobreGrafite;
      if (s.contains(WidgetState.disabled)) return c.grafite2;
      return c.grafite;
    });

    return ThemeData(
      useMaterial3: true,
      brightness: c.brilho,
      colorScheme: esquema,
      extensions: [c],
      scaffoldBackgroundColor: c.papel,
      canvasColor: c.papel,
      cardColor: c.folha,
      dividerColor: c.grade,
      disabledColor: c.grafite2,
      hintColor: c.grafite2,
      shadowColor: const Color(0xFF000000),
      // Respingo discreto, sem o brilho do InkSparkle.
      splashFactory: InkRipple.splashFactory,
      splashColor: c.grafite.withValues(alpha: 0.10),
      highlightColor: transparente,
      hoverColor: c.grafite.withValues(alpha: 0.04),
      // Neutro: é também o fundo do item escolhido no menu do dropdown (o
      // laranja a 30% virava um marrom sujo no escuro).
      focusColor: c.grafite.withValues(alpha: 0.12),
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
      fontFamily: Tipografia.familiaTexto,
      textTheme: Tipografia.textTheme(c),
      primaryTextTheme: Tipografia.textTheme(
        c.copyWith(grafite: c.sobreGrafite, grafite2: c.sobreGrafite),
      ),
      iconTheme: IconThemeData(color: c.grafite, size: 24),
      primaryIconTheme: IconThemeData(color: c.sobreGrafite, size: 24),
      appBarTheme: AppBarThemeData(
        backgroundColor: c.papel,
        foregroundColor: c.grafite,
        elevation: 0,
        // Sem isso a barra muda de cor ao rolar.
        scrolledUnderElevation: 0,
        surfaceTintColor: transparente,
        shadowColor: transparente,
        centerTitle: false,
        toolbarHeight: Alvo.mestre,
        titleSpacing: Espaco.margem,
        titleTextStyle: Tipografia.titulo.copyWith(color: c.grafite),
        toolbarTextStyle: Tipografia.corpo.copyWith(color: c.grafite),
        iconTheme: IconThemeData(color: c.grafite, size: 24),
        actionsIconTheme: IconThemeData(color: c.grafite, size: 24),
        systemOverlayStyle: barrasDoSistema(c.brilho),
      ),
      filledButtonTheme: FilledButtonThemeData(style: principal),
      elevatedButtonTheme: ElevatedButtonThemeData(style: principal),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: botao(
          fundo: transparente,
          frente: c.grafite,
          fundoPressionado: c.folhaRebaixada,
          contorno: borda(c.grafite, Traco.forte),
          altura: 56,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: botao(
          fundo: transparente,
          frente: c.grafite,
          fundoPressionado: c.folhaRebaixada,
          preenchimento: const EdgeInsets.symmetric(horizontal: Espaco.e12),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: botao(
          fundo: transparente,
          frente: c.grafite,
          fundoPressionado: c.folhaRebaixada,
          preenchimento: EdgeInsets.zero,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: c.marca,
        foregroundColor: c.sobreMarca,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        disabledElevation: 0,
        splashColor: c.sobreMarca.withValues(alpha: 0.12),
        shape: const RoundedRectangleBorder(borderRadius: Raio.cantoPequeno),
        iconSize: 28,
        sizeConstraints: const BoxConstraints.tightFor(
            width: Alvo.mestre, height: Alvo.mestre),
        smallSizeConstraints: const BoxConstraints.tightFor(
            width: Alvo.minimo, height: Alvo.minimo),
        largeSizeConstraints: const BoxConstraints.tightFor(
          width: Alvo.principal,
          height: Alvo.principal,
        ),
        extendedSizeConstraints:
            const BoxConstraints(minHeight: Alvo.mestre, minWidth: Alvo.mestre),
        extendedPadding: const EdgeInsets.symmetric(horizontal: Espaco.e24),
        extendedTextStyle: Tipografia.subtitulo,
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: WidgetStateColor.resolveWith(
          (s) => s.contains(WidgetState.disabled) ? transparente : c.folha,
        ),
        constraints: const BoxConstraints(minHeight: Alvo.mestre),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Espaco.e16,
          vertical: 20,
        ),
        border: bordaCampo(c.traco, Traco.fino),
        enabledBorder: bordaCampo(c.traco, Traco.fino),
        focusedBorder: bordaCampo(c.grafite, Traco.forte),
        errorBorder: bordaCampo(c.revisao, Traco.fino),
        focusedErrorBorder: bordaCampo(c.revisao, Traco.forte),
        // Desabilitado como o botão: sem fundo e contorno tracejado no
        // traço (o grade, 1,2:1, fazia o campo sumir no papel).
        disabledBorder: _BordaTracejada(borderSide: borda(c.traco)),
        labelStyle: Tipografia.corpo.copyWith(color: c.grafite2),
        // O rótulo que sobe para a borda é desenhado a 75%: 20 vira 15 sp,
        // o mínimo para informação (18 viraria 13,5).
        floatingLabelStyle: WidgetStateTextStyle.resolveWith(
          (s) => Tipografia.subtitulo.copyWith(
            fontSize: 20,
            color: s.contains(WidgetState.error)
                ? c.revisao
                : s.contains(WidgetState.disabled)
                    ? c.grafite2
                    : c.grafite,
          ),
        ),
        // Atenção: o texto digitado num campo desabilitado o Material
        // desenha a 38% (2,6:1), e o tema não alcança. Valor que precisa
        // ser lido mas não editado (ex.: lido da nota) vai com
        // `readOnly: true`, não com `enabled: false`.
        hintStyle: Tipografia.corpo.copyWith(color: c.grafite2),
        helperStyle: Tipografia.apoio.copyWith(color: c.grafite2),
        helperMaxLines: 3,
        errorStyle: Tipografia.apoio.copyWith(
          color: c.revisao,
          fontWeight: FontWeight.w700,
        ),
        errorMaxLines: 3,
        prefixStyle: Tipografia.corpo.copyWith(color: c.grafite),
        suffixStyle: Tipografia.corpo.copyWith(color: c.grafite2),
        counterStyle: Tipografia.apoio.copyWith(color: c.grafite2),
        iconColor: c.grafite2,
        prefixIconColor: c.grafite2,
        suffixIconColor: c.grafite2,
        alignLabelWithHint: true,
      ),
      chipTheme: ChipThemeData(
        color: WidgetStateProperty.resolveWith(corDoChip),
        backgroundColor: c.folha,
        selectedColor: c.grafite,
        disabledColor: transparente,
        checkmarkColor: c.sobreGrafite,
        deleteIconColor: c.grafite2,
        showCheckmark: true,
        // 48 dp de altura: linha de 17 + 2 x 14 + as bordas de 1,5.
        labelStyle: Tipografia.corpoForte.copyWith(
          color: textoDoChip,
          height: 1,
        ),
        secondaryLabelStyle: Tipografia.corpoForte.copyWith(
          color: c.sobreGrafite,
          height: 1,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: Espaco.e12,
          vertical: 14,
        ),
        labelPadding: const EdgeInsets.symmetric(horizontal: Espaco.e4),
        side: WidgetStateBorderSide.resolveWith((s) {
          if (s.contains(WidgetState.selected)) return borda(c.grafite);
          return borda(c.traco);
        }),
        shape: const RoundedRectangleBorder(borderRadius: Raio.cantoPequeno),
        brightness: c.brilho,
        elevation: 0,
        pressElevation: 0,
        shadowColor: transparente,
        selectedShadowColor: transparente,
        surfaceTintColor: transparente,
        iconTheme: IconThemeData(color: c.grafite, size: 20),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          minimumSize:
              const WidgetStatePropertyAll(Size(Alvo.minimo, Alvo.opcao)),
          // Archivo, mais estreita. Atenção: no segmento escolhido (com o
          // check) o Material troca este recuo pelo dele (flutter#173944),
          // e três segmentos de seis letras quebram a palavra em 360 dp.
          // Nas telas novas, use o SeletorGrande, que tem o tamanho certo
          // e passa para duas colunas quando falta largura.
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: Espaco.e8),
          ),
          textStyle: const WidgetStatePropertyAll(Tipografia.subtitulo),
          shape: const WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: Raio.cantoPequeno),
          ),
          overlayColor: semCor,
          splashFactory: NoSplash.splashFactory,
          visualDensity: VisualDensity.standard,
          tapTargetSize: MaterialTapTargetSize.padded,
          backgroundColor: WidgetStateProperty.resolveWith((s) {
            if (s.contains(WidgetState.selected)) return c.grafite;
            if (s.contains(WidgetState.disabled)) return transparente;
            if (s.contains(WidgetState.pressed)) return c.folhaRebaixada;
            return c.folha;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((s) {
            if (s.contains(WidgetState.selected)) return c.sobreGrafite;
            if (s.contains(WidgetState.disabled)) return c.grafite2;
            return c.grafite;
          }),
          iconColor: WidgetStateProperty.resolveWith((s) {
            if (s.contains(WidgetState.selected)) return c.sobreGrafite;
            if (s.contains(WidgetState.disabled)) return c.grafite2;
            return c.grafite;
          }),
          side: WidgetStateProperty.resolveWith((s) {
            if (s.contains(WidgetState.focused)) return borda(c.marcaTexto, 3);
            if (s.contains(WidgetState.disabled)) return borda(c.traco);
            return borda(c.grafite);
          }),
        ),
        selectedIcon: const Icon(Icons.check, size: 18),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.grafite,
        contentTextStyle: Tipografia.corpo.copyWith(color: c.sobreGrafite),
        // Ação como marca-texto: laranja com texto preto, nos dois temas.
        actionTextColor: c.sobreMarca,
        actionBackgroundColor: c.marca,
        disabledActionTextColor: c.grafite2,
        closeIconColor: c.sobreGrafite,
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: Raio.cantoPadrao),
        insetPadding: const EdgeInsets.fromLTRB(
          Espaco.margem,
          Espaco.e8,
          Espaco.margem,
          Espaco.e16,
        ),
        dismissDirection: DismissDirection.down,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.folha,
        surfaceTintColor: transparente,
        shadowColor: transparente,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: Raio.cantoPadrao,
          side: borda(c.grafite, Traco.forte),
        ),
        titleTextStyle: Tipografia.titulo.copyWith(color: c.grafite),
        contentTextStyle: Tipografia.corpo.copyWith(color: c.grafite),
        barrierColor: const Color(0x8C000000),
        insetPadding: const EdgeInsets.symmetric(
          horizontal: Espaco.margem,
          vertical: Espaco.e24,
        ),
        actionsPadding: const EdgeInsets.fromLTRB(
          Espaco.e16,
          0,
          Espaco.e16,
          Espaco.e16,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.folha,
        modalBackgroundColor: c.folha,
        surfaceTintColor: transparente,
        // A única sombra do sistema: curta, para separar a folha que sobe.
        elevation: 2,
        modalElevation: 2,
        shadowColor: const Color(0xFF000000),
        shape: RoundedRectangleBorder(
          borderRadius: Raio.topoFolha,
          side: borda(c.grafite),
        ),
        clipBehavior: Clip.antiAlias,
        showDragHandle: true,
        dragHandleColor: c.traco,
        dragHandleSize: const Size(40, 4),
        modalBarrierColor: const Color(0x73000000),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: c.folha,
        surfaceTintColor: transparente,
        shadowColor: transparente,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: Raio.cantoPadrao,
          side: borda(c.grafite),
        ),
        textStyle: Tipografia.corpo.copyWith(color: c.grafite),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => Tipografia.corpo.copyWith(
            color: s.contains(WidgetState.disabled) ? c.grafite2 : c.grafite,
          ),
        ),
        iconColor: c.grafite,
        iconSize: 24,
        position: PopupMenuPosition.under,
        menuPadding: const EdgeInsets.symmetric(vertical: Espaco.e4),
      ),
      menuTheme: MenuThemeData(style: estiloMenu),
      dropdownMenuTheme: DropdownMenuThemeData(
        textStyle: Tipografia.corpo.copyWith(color: c.grafite),
        menuStyle: estiloMenu,
      ),
      menuButtonTheme: MenuButtonThemeData(
        style: ButtonStyle(
          minimumSize:
              const WidgetStatePropertyAll(Size(Alvo.minimo, Alvo.minimo)),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: Espaco.e16),
          ),
          textStyle: const WidgetStatePropertyAll(Tipografia.corpo),
          overlayColor: semCor,
          splashFactory: NoSplash.splashFactory,
          foregroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.disabled) ? c.grafite2 : c.grafite,
          ),
          backgroundColor: WidgetStateProperty.resolveWith((s) {
            if (s.contains(WidgetState.pressed) ||
                s.contains(WidgetState.focused) ||
                s.contains(WidgetState.hovered)) {
              return c.folhaRebaixada;
            }
            return transparente;
          }),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) {
          if (s.contains(WidgetState.disabled)) return c.grade;
          if (s.contains(WidgetState.selected)) return c.sobreGrafite;
          return c.traco;
        }),
        trackColor: WidgetStateProperty.resolveWith((s) {
          if (s.contains(WidgetState.disabled)) return c.folhaRebaixada;
          if (s.contains(WidgetState.selected)) return c.grafite;
          return c.folhaRebaixada;
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith((s) {
          if (s.contains(WidgetState.disabled)) return c.grade;
          if (s.contains(WidgetState.selected)) return c.grafite;
          return c.traco;
        }),
        trackOutlineWidth: const WidgetStatePropertyAll(Traco.forte),
        // Ligado e desligado também pela forma, não só pela cor.
        thumbIcon: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? Icon(Icons.check, size: 16, color: c.grafite)
              : Icon(Icons.close, size: 16, color: c.folha),
        ),
        overlayColor: semCor,
        materialTapTargetSize: MaterialTapTargetSize.padded,
      ),
      sliderTheme: SliderThemeData(
        trackHeight: 6,
        activeTrackColor: c.grafite,
        // O que falta é a linha fina no traço (4:1 no papel), não um
        // trilho claro que some no sol.
        inactiveTrackColor: c.traco,
        disabledActiveTrackColor: c.traco,
        disabledInactiveTrackColor: c.traco,
        thumbColor: c.grafite,
        disabledThumbColor: c.traco,
        overlayColor: transparente,
        activeTickMarkColor: c.sobreGrafite,
        inactiveTickMarkColor: c.traco,
        trackShape: const _TrilhoCota(),
        thumbShape: _PolegarCota(contorno: c.papel),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 24),
        valueIndicatorShape: const RectangularSliderValueIndicatorShape(),
        valueIndicatorColor: c.grafite,
        valueIndicatorTextStyle:
            Tipografia.corpoForte.copyWith(color: c.sobreGrafite),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.grafite,
        // O que falta tem de aparecer (3:1 no papel e contra o grafite),
        // senão não dá para ver onde a barra termina. Para avanço de obra
        // e orçamento, use a ReguaCota.
        linearTrackColor: c.traco,
        circularTrackColor: c.traco,
        refreshBackgroundColor: c.folha,
        linearMinHeight: 6,
        borderRadius: BorderRadius.zero,
        strokeWidth: 3,
      ),
      dividerTheme: DividerThemeData(
        color: c.grade,
        thickness: Traco.fino,
        space: Espaco.e16,
      ),
      listTileTheme: ListTileThemeData(
        minTileHeight: Alvo.principal,
        minVerticalPadding: Espaco.e12,
        contentPadding: const EdgeInsets.symmetric(horizontal: Espaco.margem),
        horizontalTitleGap: Espaco.e16,
        minLeadingWidth: 24,
        iconColor: c.grafite,
        textColor: c.grafite,
        selectedColor: c.grafite,
        // Na folha (não no recuado): o apoio em grafite2 fica em 8:1.
        selectedTileColor: c.folha,
        tileColor: transparente,
        titleTextStyle: Tipografia.corpoForte.copyWith(color: c.grafite),
        subtitleTextStyle: Tipografia.apoio.copyWith(color: c.grafite2),
        // Como o valor da LinhaLista: Archivo, a letra dos números.
        leadingAndTrailingTextStyle:
            Tipografia.subtitulo.copyWith(color: c.grafite),
        visualDensity: VisualDensity.standard,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: c.grafite,
          borderRadius: Raio.cantoPequeno,
        ),
        textStyle: Tipografia.apoio.copyWith(color: c.sobreGrafite),
        padding: const EdgeInsets.symmetric(
          horizontal: Espaco.e12,
          vertical: Espaco.e8,
        ),
        margin: const EdgeInsets.symmetric(horizontal: Espaco.margem),
        preferBelow: false,
        waitDuration: const Duration(milliseconds: 500),
        showDuration: const Duration(seconds: 3),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: c.grafite,
        // Marca-texto de verdade: o laranja passa por baixo do texto.
        selectionColor: c.marca.withValues(alpha: 0.40),
        selectionHandleColor: c.grafite,
      ),
      cardTheme: CardThemeData(
        color: c.folha,
        surfaceTintColor: transparente,
        shadowColor: transparente,
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: Raio.cantoPadrao,
          side: borda(c.traco),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((s) {
          if (s.contains(WidgetState.disabled)) {
            return s.contains(WidgetState.selected) ? c.grade : transparente;
          }
          if (s.contains(WidgetState.selected)) return c.grafite;
          return transparente;
        }),
        checkColor: WidgetStatePropertyAll(c.sobreGrafite),
        side: WidgetStateBorderSide.resolveWith(
          (s) => s.contains(WidgetState.disabled)
              ? borda(c.grade, Traco.forte)
              : borda(c.grafite, Traco.forte),
        ),
        shape: const RoundedRectangleBorder(borderRadius: Raio.cantoPequeno),
        overlayColor: semCor,
        materialTapTargetSize: MaterialTapTargetSize.padded,
        visualDensity: VisualDensity.standard,
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((s) {
          if (s.contains(WidgetState.disabled)) return c.grade;
          if (s.contains(WidgetState.selected)) return c.grafite;
          return c.traco;
        }),
        overlayColor: semCor,
        materialTapTargetSize: MaterialTapTargetSize.padded,
        visualDensity: VisualDensity.standard,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: c.grafite,
        unselectedLabelColor: c.grafite2,
        labelStyle: Tipografia.subtitulo,
        unselectedLabelStyle: Tipografia.subtitulo,
        indicator: UnderlineTabIndicator(
          borderSide: BorderSide(color: c.grafite, width: 3),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: c.grade,
        dividerHeight: Traco.fino,
        overlayColor: semCor,
        splashFactory: NoSplash.splashFactory,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: c.papel,
        surfaceTintColor: transparente,
        shadowColor: transparente,
        elevation: 0,
        height: Alvo.principal,
        indicatorColor: c.grafite,
        indicatorShape:
            const RoundedRectangleBorder(borderRadius: Raio.cantoPequeno),
        overlayColor: semCor,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => Tipografia.apoio.copyWith(
            fontWeight: FontWeight.w700,
            color: s.contains(WidgetState.selected) ? c.grafite : c.grafite2,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(
            size: 24,
            color:
                s.contains(WidgetState.selected) ? c.sobreGrafite : c.grafite,
          ),
        ),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: c.folha,
        surfaceTintColor: transparente,
        shadowColor: transparente,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: Raio.cantoPadrao,
          side: borda(c.grafite, Traco.forte),
        ),
        headerBackgroundColor: c.papel,
        headerForegroundColor: c.grafite,
        headerHeadlineStyle: Tipografia.tituloTela,
        // Não é caixa alta: 15 sp, não os 13 do rótulo.
        headerHelpStyle: Tipografia.apoio.copyWith(fontWeight: FontWeight.w700),
        dividerColor: c.grade,
        weekdayStyle: Tipografia.apoio.copyWith(color: c.grafite2),
        dayStyle: Tipografia.corpo,
        yearStyle: Tipografia.corpo,
        todayBorder: borda(c.grafite),
        // Dia e ano escolhidos em quadrado de canto pequeno, não em
        // círculo ou pílula.
        dayShape: const WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: Raio.cantoPequeno),
        ),
        yearShape: const WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: Raio.cantoPequeno),
        ),
      ),
      // Relógio: o Material vem com raio 28 e caixas de raio 8.
      timePickerTheme: TimePickerThemeData(
        backgroundColor: c.folha,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: Raio.cantoPadrao,
          side: borda(c.grafite, Traco.forte),
        ),
        hourMinuteShape: RoundedRectangleBorder(
          borderRadius: Raio.cantoPequeno,
          side: borda(c.traco),
        ),
        dayPeriodShape: const RoundedRectangleBorder(
          borderRadius: Raio.cantoPequeno,
        ),
        dayPeriodBorderSide: borda(c.traco),
        hourMinuteColor: WidgetStateColor.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.grafite : c.folha,
        ),
        hourMinuteTextColor: WidgetStateColor.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.sobreGrafite : c.grafite,
        ),
        dayPeriodColor: WidgetStateColor.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.grafite : transparente,
        ),
        dayPeriodTextColor: WidgetStateColor.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.sobreGrafite : c.grafite,
        ),
        dialBackgroundColor: c.folhaRebaixada,
        dialHandColor: c.grafite,
        dialTextColor: WidgetStateColor.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.sobreGrafite : c.grafite,
        ),
        entryModeIconColor: c.grafite,
        helpTextStyle: Tipografia.apoio.copyWith(
          fontWeight: FontWeight.w700,
          color: c.grafite2,
        ),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStatePropertyAll(c.traco),
        thickness: const WidgetStatePropertyAll(4),
        radius: Radius.zero,
      ),
    );
  }
}

/// Borda de campo desabilitado: tracejada, respeitando o vão do rótulo
/// que sobe para a borda.
class _BordaTracejada extends OutlineInputBorder {
  const _BordaTracejada({required super.borderSide})
      : super(borderRadius: Raio.cantoPadrao);

  @override
  _BordaTracejada copyWith({
    BorderSide? borderSide,
    BorderRadius? borderRadius,
    double? gapPadding,
  }) =>
      _BordaTracejada(borderSide: borderSide ?? this.borderSide);

  @override
  void paint(
    Canvas canvas,
    Rect rect, {
    double? gapStart,
    double gapExtent = 0.0,
    double gapPercentage = 0.0,
    TextDirection? textDirection,
  }) {
    final centro =
        borderRadius.toRRect(rect).inflate(borderSide.strokeOffset / 2);
    canvas.save();
    if (gapStart != null && gapExtent > 0 && gapPercentage > 0) {
      // O mesmo vão do OutlineInputBorder, recortado do tracejado.
      final extensao =
          lerpDouble(0, gapExtent + gapPadding * 2, gapPercentage)!;
      final inicio = switch (textDirection ?? TextDirection.ltr) {
        TextDirection.rtl => gapStart + gapPadding - extensao,
        TextDirection.ltr => gapStart - gapPadding,
      };
      final w = borderSide.width;
      canvas.clipRect(
        Rect.fromLTWH(
          rect.left + math.max(0, inicio),
          rect.top - 2 * w,
          extensao,
          4 * w,
        ),
        clipOp: ClipOp.difference,
      );
    }
    pintarTracejado(canvas, Path()..addRRect(centro), borderSide.toPaint());
    canvas.restore();
  }
}

/// Polegar do Slider como o marcador da régua de cota: um traço vertical
/// que engrossa enquanto é arrastado.
class _PolegarCota extends SliderComponentShape {
  const _PolegarCota({required this.contorno});

  /// Cor do contorno que separa o polegar do trilho (a do papel).
  final Color contorno;

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) => const Size(10, 32);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final cor = ColorTween(
      begin: sliderTheme.disabledThumbColor,
      end: sliderTheme.thumbColor,
    ).evaluate(enableAnimation)!;
    final largura = 6 + 4 * activationAnimation.value;
    final retangulo =
        Rect.fromCenter(center: center, width: largura, height: 28);
    final canvas = context.canvas;
    canvas.drawRect(
      retangulo.inflate(Traco.fino),
      Paint()..color = contorno,
    );
    canvas.drawRect(retangulo, Paint()..color = cor);
  }
}

/// Trilho do Slider como linha de cota: uma linha fina de ponta a ponta
/// (o que falta), com linhas de chamada nas pontas, e a barra grafite do
/// começo até o polegar (o que já foi).
class _TrilhoCota extends SliderTrackShape with BaseSliderTrackShape {
  const _TrilhoCota();

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isDiscrete = false,
    bool isEnabled = false,
  }) {
    final trilho = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );
    final ativo = ColorTween(
      begin: sliderTheme.disabledActiveTrackColor,
      end: sliderTheme.activeTrackColor,
    ).evaluate(enableAnimation)!;
    final inativo = ColorTween(
      begin: sliderTheme.disabledInactiveTrackColor,
      end: sliderTheme.inactiveTrackColor,
    ).evaluate(enableAnimation)!;
    final canvas = context.canvas;
    final meio = trilho.center.dy;
    final fino = Paint()
      ..color = inativo
      ..strokeWidth = Traco.fino;
    canvas.drawLine(
        Offset(trilho.left, meio), Offset(trilho.right, meio), fino);
    for (final x in [trilho.left, trilho.right]) {
      canvas.drawLine(Offset(x, meio - 8), Offset(x, meio + 8), fino);
    }
    final feito = textDirection == TextDirection.ltr
        ? Rect.fromLTRB(trilho.left, trilho.top, thumbCenter.dx, trilho.bottom)
        : Rect.fromLTRB(
            thumbCenter.dx, trilho.top, trilho.right, trilho.bottom);
    canvas.drawRect(feito, Paint()..color = ativo);
  }
}
