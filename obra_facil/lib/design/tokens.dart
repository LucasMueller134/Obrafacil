// Tokens do design system "Prancheta" (docs/redesign/design-system.md).
//
// Cores, espaço, raio, traço e alvos de toque. As telas leem as cores com
// `context.cores`; os números de espaço e forma são constantes.

import 'package:flutter/material.dart';

/// Paleta da prancheta: papel, grafite e o laranja como marca-texto.
///
/// Fica no tema como [ThemeExtension]; leia com `context.cores`. Os nomes
/// e valores são os da seção 2 da especificação.
@immutable
class CoresObra extends ThemeExtension<CoresObra> {
  const CoresObra({
    required this.brilho,
    required this.papel,
    required this.folha,
    required this.folhaRebaixada,
    required this.grafite,
    required this.grafite2,
    required this.traco,
    required this.grade,
    required this.marca,
    required this.sobreMarca,
    required this.marcaTexto,
    required this.revisao,
    required this.ok,
    required this.aviso,
    required this.sobreGrafite,
  });

  /// Claro ou escuro: os componentes não precisam perguntar ao tema.
  final Brightness brilho;

  /// Fundo das telas.
  final Color papel;

  /// Superfícies: cartões, campos, folhas.
  final Color folha;

  /// Áreas recuadas e trilho de barras. Não leva texto: o contraste do
  /// texto secundário cai abaixo de 7:1 aqui.
  final Color folhaRebaixada;

  /// Texto principal, botão principal, traço forte.
  final Color grafite;

  /// Texto secundário.
  final Color grafite2;

  /// Bordas e ícones (no mínimo 3:1).
  final Color traco;

  /// Divisórias decorativas; nunca carrega informação.
  final Color grade;

  /// Laranja de preenchimento (destaque). Texto em cima: [sobreMarca].
  final Color marca;

  /// Texto e ícone sobre a [marca] e sobre o [aviso]. Sempre preto.
  final Color sobreMarca;

  /// Laranja como texto ou traço fino.
  final Color marcaTexto;

  /// Erro, recusa, alerta de orçamento.
  final Color revisao;

  /// Aprovado, concluído.
  final Color ok;

  /// Atenção; sempre com texto preto ([sobreAviso]).
  final Color aviso;

  /// Texto sobre o botão grafite.
  final Color sobreGrafite;

  /// Texto sobre o [aviso] (o mesmo preto da marca).
  Color get sobreAviso => sobreMarca;

  bool get ehEscuro => brilho == Brightness.dark;

  /// A [marca] pressionada: mais clara, nunca mais escura. Escurecer o
  /// laranja derruba o preto em cima para menos de 5:1; clareando, fica
  /// acima de 8:1 nos dois temas.
  Color get marcaPressionada =>
      // Arredonda para 8 bits por canal, como os outros tokens.
      Color(Color.lerp(marca, const Color(0xFFFFFFFF), 0.25)!.toARGB32());

  static const CoresObra claro = CoresObra(
    brilho: Brightness.light,
    papel: Color(0xFFF4F5F3),
    folha: Color(0xFFFFFFFF),
    folhaRebaixada: Color(0xFFEBECE8),
    grafite: Color(0xFF1A1C1F),
    grafite2: Color(0xFF4B5058),
    traco: Color(0xFF6E737B),
    grade: Color(0xFFDCDFDB),
    marca: Color(0xFFF97316),
    sobreMarca: Color(0xFF15120F),
    marcaTexto: Color(0xFFC2410C),
    revisao: Color(0xFFB42318),
    ok: Color(0xFF0B6E4F),
    aviso: Color(0xFFFFC400),
    sobreGrafite: Color(0xFFF4F5F3),
  );

  static const CoresObra escuro = CoresObra(
    brilho: Brightness.dark,
    papel: Color(0xFF121315),
    folha: Color(0xFF1A1C1F),
    folhaRebaixada: Color(0xFF23262A),
    grafite: Color(0xFFECEDE9),
    grafite2: Color(0xFFA9ADB3),
    traco: Color(0xFF7A7F87),
    grade: Color(0xFF2C2F34),
    marca: Color(0xFFFF8A3D),
    sobreMarca: Color(0xFF15120F),
    marcaTexto: Color(0xFFFF8A3D),
    revisao: Color(0xFFFF6B5B),
    ok: Color(0xFF3FBF8A),
    aviso: Color(0xFFFFC400),
    sobreGrafite: Color(0xFF121315),
  );

  /// Paleta padrão para um brilho.
  static CoresObra doBrilho(Brightness brilho) =>
      brilho == Brightness.dark ? escuro : claro;

  /// O mesmo que `context.cores`.
  static CoresObra de(BuildContext context) => context.cores;

  /// Razão de contraste WCAG 2.2 entre duas cores opacas (de 1 a 21).
  static double contraste(Color a, Color b) {
    final la = a.computeLuminance();
    final lb = b.computeLuminance();
    final (claro, escuro) = la >= lb ? (la, lb) : (lb, la);
    return (claro + 0.05) / (escuro + 0.05);
  }

  @override
  CoresObra copyWith({
    Brightness? brilho,
    Color? papel,
    Color? folha,
    Color? folhaRebaixada,
    Color? grafite,
    Color? grafite2,
    Color? traco,
    Color? grade,
    Color? marca,
    Color? sobreMarca,
    Color? marcaTexto,
    Color? revisao,
    Color? ok,
    Color? aviso,
    Color? sobreGrafite,
  }) {
    return CoresObra(
      brilho: brilho ?? this.brilho,
      papel: papel ?? this.papel,
      folha: folha ?? this.folha,
      folhaRebaixada: folhaRebaixada ?? this.folhaRebaixada,
      grafite: grafite ?? this.grafite,
      grafite2: grafite2 ?? this.grafite2,
      traco: traco ?? this.traco,
      grade: grade ?? this.grade,
      marca: marca ?? this.marca,
      sobreMarca: sobreMarca ?? this.sobreMarca,
      marcaTexto: marcaTexto ?? this.marcaTexto,
      revisao: revisao ?? this.revisao,
      ok: ok ?? this.ok,
      aviso: aviso ?? this.aviso,
      sobreGrafite: sobreGrafite ?? this.sobreGrafite,
    );
  }

  @override
  CoresObra lerp(covariant ThemeExtension<CoresObra>? other, double t) {
    if (other is! CoresObra) return this;
    Color m(Color a, Color b) => Color.lerp(a, b, t)!;
    return CoresObra(
      brilho: t < 0.5 ? brilho : other.brilho,
      papel: m(papel, other.papel),
      folha: m(folha, other.folha),
      folhaRebaixada: m(folhaRebaixada, other.folhaRebaixada),
      grafite: m(grafite, other.grafite),
      grafite2: m(grafite2, other.grafite2),
      traco: m(traco, other.traco),
      grade: m(grade, other.grade),
      marca: m(marca, other.marca),
      sobreMarca: m(sobreMarca, other.sobreMarca),
      marcaTexto: m(marcaTexto, other.marcaTexto),
      revisao: m(revisao, other.revisao),
      ok: m(ok, other.ok),
      aviso: m(aviso, other.aviso),
      sobreGrafite: m(sobreGrafite, other.sobreGrafite),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is CoresObra &&
      other.brilho == brilho &&
      other.papel == papel &&
      other.folha == folha &&
      other.folhaRebaixada == folhaRebaixada &&
      other.grafite == grafite &&
      other.grafite2 == grafite2 &&
      other.traco == traco &&
      other.grade == grade &&
      other.marca == marca &&
      other.sobreMarca == sobreMarca &&
      other.marcaTexto == marcaTexto &&
      other.revisao == revisao &&
      other.ok == ok &&
      other.aviso == aviso &&
      other.sobreGrafite == sobreGrafite;

  @override
  int get hashCode => Object.hash(
        brilho,
        papel,
        folha,
        folhaRebaixada,
        grafite,
        grafite2,
        traco,
        grade,
        marca,
        sobreMarca,
        marcaTexto,
        revisao,
        ok,
        aviso,
        sobreGrafite,
      );
}

/// `context.cores`: a paleta do tema atual.
extension CoresDoContexto on BuildContext {
  /// A [CoresObra] do tema. Se o tema não tiver a extensão (tela antiga
  /// usando um componente novo), devolve a paleta padrão do brilho do
  /// tema. Nunca lança.
  CoresObra get cores {
    final tema = Theme.of(this);
    return tema.extension<CoresObra>() ?? CoresObra.doBrilho(tema.brightness);
  }
}

/// Espaçamento: 4 · 8 · 12 · 16 · 24 · 32 · 48 (o número é o dp).
abstract final class Espaco {
  static const double e4 = 4;
  static const double e8 = 8;
  static const double e12 = 12;
  static const double e16 = 16;
  static const double e24 = 24;
  static const double e32 = 32;
  static const double e48 = 48;

  /// Margem lateral das telas.
  static const double margem = 16;

  /// Distância mínima entre dois alvos de toque.
  static const double entreAlvos = 12;
}

/// Raios de canto. Quase tudo é reto: é desenho técnico.
abstract final class Raio {
  static const double nenhum = 0;
  static const double pequeno = 2;
  static const double padrao = 4;

  /// Topo das folhas que sobem de baixo.
  static const double folha = 8;

  /// Só na nota de revisão e no microfone.
  static const double pilula = 999;

  static const BorderRadius cantoPequeno =
      BorderRadius.all(Radius.circular(pequeno));
  static const BorderRadius cantoPadrao =
      BorderRadius.all(Radius.circular(padrao));
  static const BorderRadius topoFolha =
      BorderRadius.vertical(top: Radius.circular(folha));
}

/// Espessuras de traço. Nada abaixo de 1,5 dp: traço fino some no sol.
abstract final class Traco {
  /// Bordas.
  static const double fino = 1.5;

  /// Destaque e botão de contorno.
  static const double forte = 2;
}

/// Alvos de toque (seção 1).
abstract final class Alvo {
  /// Qualquer coisa tocável.
  static const double minimo = 48;

  /// Opção de escolha grande (SeletorGrande).
  static const double opcao = 56;

  /// Ações do mestre.
  static const double mestre = 64;

  /// Ação principal da tela; também a altura mínima de uma linha de lista.
  static const double principal = 72;
}
