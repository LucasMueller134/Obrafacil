import 'dart:math' as math;
import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';

import 'progresso_maquete.dart';

/// O que a maquete 3D mostra para um avanço: quais peças do `maquete.glb`
/// ficam visíveis, com que escala, e quais fantasmas (o desenho tracejado do
/// que falta) aparecem.
///
/// É Dart puro, sem Flutter GPU, para poder ser testado sem aparelho. Os
/// nomes dos nós, os pivôs e a câmera vêm do manifesto
/// (`assets/3d/maquete.json`) e do `ferramentas/maquete_3d/LEIA-ME.md`.
///
/// Regra por fase (a mesma das imagens de reserva):
/// * concluída (1): todas as peças inteiras, fantasma escondido;
/// * não começada (0): peças escondidas, fantasma visível;
/// * em andamento: as peças aparecem em etapas ([EtapaPeca]) e o fantasma
///   continua visível (o LEIA-ME manda mostrar o fantasma de toda fase não
///   concluída).
@immutable
class PlanoMaquete {
  /// Estado de cada peça, pelo nome do nó no glb.
  final Map<String, EstadoPeca> pecas;

  /// Visibilidade de cada fantasma (`fantasma_fase_00` ... `_09`).
  final Map<String, bool> fantasmas;

  const PlanoMaquete._(this.pecas, this.fantasmas);

  /// Calcula o plano para o avanço de cada fase (0 a 1, 10 itens).
  factory PlanoMaquete.calcular(List<double> avancoPorFase) {
    final pecas = <String, EstadoPeca>{};
    final fantasmas = <String, bool>{};
    for (var fase = 0; fase < ProgressoMaquete.totalFases; fase++) {
      final t = fase < avancoPorFase.length
          ? avancoPorFase[fase].clamp(0.0, 1.0)
          : 0.0;
      fantasmas[NosMaquete.fantasma(fase)] = t < 1;
      for (final etapa in etapasPorFase[fase]) {
        pecas[etapa.no] = t >= 1
            ? EstadoPeca.inteira
            : t <= 0
                ? EstadoPeca.escondida
                : etapa.estadoEm(t);
      }
    }
    return PlanoMaquete._(
      Map.unmodifiable(pecas),
      Map.unmodifiable(fantasmas),
    );
  }

  /// Todos os nós que o plano mexe (peças + fantasmas), para conferir se o
  /// glb carregado tem todos.
  static List<String> get todosOsNos => [
        for (final etapas in etapasPorFase)
          for (final e in etapas) e.no,
        for (var i = 0; i < ProgressoMaquete.totalFases; i++)
          NosMaquete.fantasma(i),
      ];

  /// Como cada fase em andamento se revela, na ordem do canteiro.
  ///
  /// `inicio` e `fim` são frações do avanço da fase. Pivôs (manifesto):
  /// radier e laje na borda dos fundos (escala em Z concreta de trás para a
  /// frente); pilares no piso; vigas no fundo da viga; terças e telhas no
  /// topo da laje; poste e eletroduto no chão; caixa de medição no meio do
  /// poste; base, caixa d'água e tubos sobre a laje; ripado na base.
  ///
  /// Reboco, pintura, calçada, peitoris, esquadrias, porta e árvores têm o
  /// pivô na origem da cena, e escalar casca de parede comprimiria os vãos
  /// para baixo; essas peças só aparecem inteiras quando a fase passa do
  /// limite ([Crescimento.aparecer]).
  static final List<List<EtapaPeca>> etapasPorFase = List.unmodifiable([
    // 00 Fundação: o radier concretado de trás para a frente.
    const [EtapaPeca('fundacao_radier', 0, 1, Crescimento.z)],
    // 01 Estrutura: pilares sobem, depois as vigas, depois a laje.
    const [
      EtapaPeca('estrutura_pilares', 0, 0.45, Crescimento.y),
      EtapaPeca('estrutura_vigas', 0.45, 0.7, Crescimento.y),
      EtapaPeca('estrutura_laje', 0.7, 1, Crescimento.z),
    ],
    // 02 Alvenaria: fiada a fiada (12 de parede + 3 de platibanda). A fiada
    // k aparece quando o avanço passa de (k + 1) / 15.
    [
      for (var k = 0; k < NosMaquete.totalFiadas; k++)
        EtapaPeca(
          NosMaquete.fiada(k),
          k / NosMaquete.totalFiadas,
          (k + 1) / NosMaquete.totalFiadas,
          Crescimento.aparecer,
        ),
    ],
    // 03 Cobertura: terças e pontaletes sobem da laje, depois as telhas se
    // espalham do meio para as beiradas (pivô no centro, escala em X).
    const [
      EtapaPeca('cobertura_tercas', 0, 0.4, Crescimento.y),
      EtapaPeca('cobertura_telhas', 0.4, 1, Crescimento.x),
    ],
    // 04 Instalações elétricas: poste, eletroduto, caixa de medição.
    const [
      EtapaPeca('eletrica_poste', 0, 0.5, Crescimento.y),
      EtapaPeca('eletrica_eletroduto', 0.3, 0.75, Crescimento.y),
      EtapaPeca('eletrica_caixa_medicao', 0.7, 1, Crescimento.uniforme),
    ],
    // 05 Instalações hidráulicas: base, caixa d'água, tubos.
    const [
      EtapaPeca('hidraulica_base', 0, 0.35, Crescimento.y),
      EtapaPeca('hidraulica_caixa_dagua', 0.35, 0.8, Crescimento.y),
      EtapaPeca('hidraulica_tubos', 0.6, 1, Crescimento.y),
    ],
    // 06 Reboco e contrapiso.
    const [
      EtapaPeca('reboco_paredes', 0, 0.5, Crescimento.aparecer),
      EtapaPeca('reboco_contrapiso', 0.5, 0.9, Crescimento.aparecer),
    ],
    // 07 Revestimentos: calçada, ripado, pingadeira, peitoris.
    const [
      EtapaPeca('revestimentos_calcada', 0, 0.25, Crescimento.aparecer),
      EtapaPeca('revestimentos_ripado', 0.3, 0.65, Crescimento.y),
      EtapaPeca('revestimentos_pingadeira', 0.65, 0.75, Crescimento.aparecer),
      EtapaPeca('revestimentos_peitoris', 0.75, 0.9, Crescimento.aparecer),
    ],
    // 08 Pintura: a casca de tinta cobre o reboco.
    const [EtapaPeca('pintura_paredes', 0, 0.5, Crescimento.aparecer)],
    // 09 Acabamento: esquadrias, porta, árvores.
    const [
      EtapaPeca('acabamento_esquadrias', 0, 0.3, Crescimento.aparecer),
      EtapaPeca('acabamento_porta', 0.3, 0.55, Crescimento.aparecer),
      EtapaPeca('acabamento_arvores', 0.55, 0.8, Crescimento.aparecer),
    ],
  ]);
}

/// Como uma peça cresce enquanto a fase dela está em andamento.
enum Crescimento {
  /// Escala só em X a partir do pivô.
  x,

  /// Escala só em Y (de baixo para cima, a partir do pivô).
  y,

  /// Escala só em Z.
  z,

  /// Escala igual nos três eixos.
  uniforme,

  /// Sem escala: escondida até o avanço chegar ao `fim` da etapa, aí inteira.
  aparecer,
}

/// Uma peça (nó do glb) e o trecho do avanço da fase em que ela se revela.
@immutable
class EtapaPeca {
  final String no;
  final double inicio;
  final double fim;
  final Crescimento crescimento;

  const EtapaPeca(this.no, this.inicio, this.fim, this.crescimento);

  /// Estado da peça com a fase em `t` (0 < t < 1).
  EstadoPeca estadoEm(double t) {
    if (crescimento == Crescimento.aparecer) {
      return t >= fim - 1e-9 ? EstadoPeca.inteira : EstadoPeca.escondida;
    }
    final s = _suave(((t - inicio) / (fim - inicio)).clamp(0.0, 1.0));
    if (s <= EstadoPeca.escalaMinima) return EstadoPeca.escondida;
    if (s >= 1 - 1e-6) return EstadoPeca.inteira;
    return switch (crescimento) {
      Crescimento.x => EstadoPeca(true, s, 1, 1),
      Crescimento.y => EstadoPeca(true, 1, s, 1),
      Crescimento.z => EstadoPeca(true, 1, 1, s),
      Crescimento.uniforme => EstadoPeca(true, s, s, s),
      Crescimento.aparecer => EstadoPeca.inteira,
    };
  }

  /// Começa e termina devagar (smoothstep), como no protótipo.
  static double _suave(double t) => t * t * (3 - 2 * t);
}

/// Visibilidade e escala de um nó.
@immutable
class EstadoPeca {
  /// Abaixo disso a peça é escondida em vez de escalada (escala zero
  /// degenera a matriz).
  static const double escalaMinima = 0.001;

  static const inteira = EstadoPeca(true, 1, 1, 1);
  static const escondida = EstadoPeca(false, 1, 1, 1);

  final bool visivel;
  final double escalaX;
  final double escalaY;
  final double escalaZ;

  const EstadoPeca(this.visivel, this.escalaX, this.escalaY, this.escalaZ);

  bool get inteiraNaEscala => escalaX == 1 && escalaY == 1 && escalaZ == 1;

  @override
  bool operator ==(Object other) =>
      other is EstadoPeca &&
      other.visivel == visivel &&
      other.escalaX == escalaX &&
      other.escalaY == escalaY &&
      other.escalaZ == escalaZ;

  @override
  int get hashCode => Object.hash(visivel, escalaX, escalaY, escalaZ);

  @override
  String toString() => visivel
      ? 'visível (${escalaX.toStringAsFixed(2)}, ${escalaY.toStringAsFixed(2)}, '
          '${escalaZ.toStringAsFixed(2)})'
      : 'escondida';
}

/// Nomes dos nós do `maquete.glb` (manifesto `assets/3d/maquete.json`).
abstract final class NosMaquete {
  static const String raiz = 'maquete';
  static const String base = 'base';
  static const String cotas = 'cotas';
  static const int totalFiadas = 15;

  static String fiada(int k) => 'alvenaria_fiada_${_dois(k)}';
  static String fantasma(int fase) => 'fantasma_fase_${_dois(fase)}';
  static String _dois(int n) => n.toString().padLeft(2, '0');
}

/// A câmera das imagens de reserva (`camera_reserva` no manifesto), para o
/// 3D e a imagem baterem.
///
/// O manifesto está em coordenadas glTF (frente da casa em +Z). O hook do
/// flutter_scene, ao converter o glb em `.fsceneb`, troca o sinal de Z (o
/// mundo dele é de mão esquerda), então aqui o Z vem invertido. O teste
/// `cena_glb_test.dart` confere isso no `.fsceneb` gerado: o pivô do radier,
/// (0; 0; -3,7) no manifesto, sai (0; 0; 3,7).
abstract final class CameraMaquete {
  /// Posição do olho, já em coordenadas do flutter_scene.
  static const List<double> posicao = [14.54, 14.086, -20.753];

  /// Ponto para onde a câmera olha, já em coordenadas do flutter_scene.
  static const List<double> alvo = [0.199, -0.046, -0.665];

  /// Campo de visão vertical da imagem de 1080x720 (lente de 50 mm).
  static const double fovVerticalGraus = 26.99;

  /// Proporção (largura / altura) das imagens de reserva.
  static const double proporcaoReserva = 1080 / 720;

  /// Radianos de giro por ponto lógico arrastado na horizontal (arrastar a
  /// largura de um celular, ~360 pontos, dá ~165°).
  static const double giroPorPonto = 0.008;

  /// Campo de visão vertical (radianos) para uma caixa com essa proporção,
  /// casando com a imagem de reserva desenhada com `BoxFit.contain`: na
  /// caixa mais larga que 3:2 a imagem ocupa a altura toda (mesmo campo); na
  /// mais estreita ela ocupa a largura e sobra papel em cima e embaixo, então
  /// o campo vertical cresce na mesma razão.
  static double fovVerticalPara(double proporcaoCaixa) {
    final base = fovVerticalGraus * math.pi / 180;
    if (!(proporcaoCaixa > 0) || proporcaoCaixa >= proporcaoReserva) {
      return base;
    }
    final t = math.tan(base / 2) * proporcaoReserva / proporcaoCaixa;
    return 2 * math.atan(t);
  }

  /// Gira um ponto (x, y, z) em volta do eixo vertical que passa pela origem
  /// do tabuleiro. Com ângulo positivo a câmera anda para a esquerda da tela
  /// (a direita da tela, no mundo de mão esquerda do flutter_scene, é
  /// `up × forward`), então a maquete parece girar para a direita,
  /// acompanhando o dedo que arrasta para a direita.
  static List<double> girar(List<double> p, double angulo) {
    final c = math.cos(angulo), s = math.sin(angulo);
    return [p[0] * c + p[2] * s, p[1], -p[0] * s + p[2] * c];
  }
}

/// Cores de tema da maquete (manifesto: `materiais_de_tema` e `fundo`; o
/// fantasma, medido nas imagens de reserva). O fundo é o `papel` do design
/// system.
@immutable
class TemaMaquete {
  final Color papel;
  final Color base;
  final Color grade;
  final Color gradeForte;
  final Color cota;

  /// Cor de tela do traço do fantasma, opaca (no app não se usa alfa: as 3
  /// faces de cada traço se sobrepõem e mancham). Na cena entra como
  /// [fantasmaNaCena].
  ///
  /// É a cor que o traço TEM nas imagens de reserva, medida nelas (mediana
  /// do miolo dos traços em `estado_00`: claro RGB 57/57/53, escuro
  /// 213/216/215; o teste `cor_fantasma_test.dart` mede de novo), e não o
  /// `fantasma_opaco` do manifesto (#7D7D7C / #C0C1BE). O manifesto calcula
  /// uma camada com a opacidade de 0,78/0,62, mas no Cycles as faces do
  /// prisma se somam e o traço sai quase grafite cheio. Com o valor do
  /// manifesto o 3D teria o traço bem mais claro que a imagem que ele
  /// substitui, e a direção B pede traço fino sempre em grafite escuro.
  final Color fantasma;

  const TemaMaquete._({
    required this.papel,
    required this.base,
    required this.grade,
    required this.gradeForte,
    required this.cota,
    required this.fantasma,
  });

  static const claro = TemaMaquete._(
    papel: Color(0xFFF4F5F3),
    base: Color(0xFFF2F2EF),
    grade: Color(0xFFDCDDDA),
    gradeForte: Color(0xFFC8C9C6),
    cota: Color(0xFF1A1C1F),
    fantasma: Color(0xFF393935),
  );

  static const escuro = TemaMaquete._(
    papel: Color(0xFF121315),
    base: Color(0xFF2A2D31),
    grade: Color(0xFF393D41),
    gradeForte: Color(0xFF4D5155),
    cota: Color(0xFFECEDE9),
    fantasma: Color(0xFFD5D8D7),
  );

  static TemaMaquete de({required bool escuro}) =>
      escuro ? TemaMaquete.escuro : TemaMaquete.claro;

  /// Cor do material de tema pelo nome do material no glb, ou `null` se o
  /// material não é de tema.
  Color? corDoMaterial(String nome) => switch (nome) {
        'base' => base,
        'grade' => grade,
        'grade_forte' => gradeForte,
        'cota' => cota,
        'fantasma' => fantasma,
        _ => null,
      };

  /// Componentes lineares (0 a 1) de uma cor sRGB, como o flutter_scene
  /// espera em `baseColorFactor`.
  static List<double> linear(Color c) => [
        paraLinear(c.r),
        paraLinear(c.g),
        paraLinear(c.b),
        c.a,
      ];

  /// sRGB (0 a 1) para luz linear.
  static double paraLinear(double v) =>
      v <= 0.04045 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();

  /// Luz linear para sRGB (0 a 1).
  static double paraSrgb(double v) {
    final x = v.clamp(0.0, 1.0);
    return x <= 0.0031308
        ? x * 12.92
        : 1.055 * math.pow(x, 1 / 2.4).toDouble() - 0.055;
  }

  /// Fator linear (cor de cena) do fantasma: o valor que, depois da curva
  /// de tons do flutter_scene (Khronos PBR Neutral com exposição 1, o
  /// padrão da `Scene`), sai na tela como [fantasma]. Assim o traço tem a
  /// cor das imagens de reserva sem passar
  /// pela camada `displayReferred` (que custaria um alvo de desenho e uma
  /// composição a mais por quadro).
  List<double> get fantasmaNaCena {
    final alvo = linear(fantasma);
    return [...antesDaCurva(alvo.sublist(0, 3)), 1];
  }

  /// Curva PBR Neutral, igual à `PBRNeutralToneMapping` do flutter_scene
  /// 0.24.3 (`shaders/tone_mapping.glsl`): luz linear de cena para luz
  /// linear de tela.
  static List<double> pbrNeutral(List<double> rgb) {
    const inicioCompressao = 0.8 - 0.04;
    const dessaturacao = 0.15;
    final x = rgb.reduce(math.min);
    final deslocamento = x < 0.08 ? x - 6.25 * x * x : 0.04;
    var c = [for (final v in rgb) v - deslocamento];
    final pico = c.reduce(math.max);
    if (pico < inicioCompressao) return c;
    const d = 1 - inicioCompressao;
    final novoPico = 1 - d * d / (pico + d - inicioCompressao);
    c = [for (final v in c) v * novoPico / pico];
    final g = 1 - 1 / (dessaturacao * (pico - novoPico) + 1);
    return [for (final v in c) v + (novoPico - v) * g];
  }

  /// Inversa de [pbrNeutral] na faixa sem compressão (pico de tela abaixo
  /// de 0,76, onde ficam as cores do fantasma): a cor de cena que a curva
  /// leva em [tela]. Acima disso o pico é limitado a 0,76.
  static List<double> antesDaCurva(List<double> tela) {
    final y = [for (final v in tela) v.clamp(0.0, 0.76 - 1e-6)];
    final minimo = y.reduce(math.min);
    final double deslocamento;
    if (minimo >= 0.04) {
      // Fora do "pé" da curva: ela só subtrai 0,04.
      deslocamento = 0.04;
    } else {
      // No pé: y_min = 6,25 x_min² e o deslocamento é x_min - y_min.
      final xMin = math.sqrt(minimo / 6.25);
      deslocamento = xMin - minimo;
    }
    return [for (final v in y) v + deslocamento];
  }
}
