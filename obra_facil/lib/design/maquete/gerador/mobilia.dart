// Os móveis, as plantas e o carro da maquete. Cada peça é desenhada num
// referencial próprio ([Moldura]): u ao longo da parede (da esquerda de
// quem olha a parede para a direita), v da parede para dentro do cômodo e h
// do piso para cima. A peça ocupa u de 0 a largura e v de 0 a fundo.
//
// Medidas de catálogo (cama de casal 1,38 x 1,88, sofá de 0,90 de fundo,
// bancada a 0,90 m etc.) e quinas chanfradas: de perto, no 360°, a peça
// tem de parecer móvel, não caixa.

import 'dart:math' as math;

import 'gerador_maquete.dart' show MateriaisMaquete;
import 'moldura.dart';

typedef _M = MateriaisMaquete;

abstract final class Mobilia {
  // ------------------------------------------------------------ quarto

  /// Cama com a cabeceira na parede (v = 0). [largura] 0,88 (solteiro),
  /// 1,38 (casal) ou 1,58 (queen); o comprimento é 1,88 ou 1,98.
  static void cama(Moldura m, double largura, double comprimento) {
    final l = largura;
    // Cabeceira estofada, um pouco mais larga que a cama.
    m.caixa(_M.tecido.nome, -0.06, l + 0.06, 0, 0.08, 0, 1.05, chanfro: 0.025);
    // Base (box) e o colchão.
    m.caixa(_M.madeiraClara.nome, 0.02, l - 0.02, 0.08, comprimento - 0.02,
        0.08, 0.3,
        chanfro: 0.01);
    for (final (u, v) in [
      (0.08, 0.16),
      (l - 0.08, 0.16),
      (0.08, comprimento - 0.1),
      (l - 0.08, comprimento - 0.1),
    ]) {
      m.cilindro(_M.metalPreto.nome, u, v, 0, 0.08, 0.025, lados: 8);
    }
    m.caixa(_M.roupaDeCama.nome, 0, l, 0.08, comprimento, 0.3, 0.52,
        chanfro: 0.05);
    // Edredom dobrado nos dois terços de baixo e a manta nos pés.
    m.caixa(_M.tecido.nome, -0.015, l + 0.015, comprimento * 0.42,
        comprimento + 0.015, 0.36, 0.56,
        chanfro: 0.04);
    m.caixa(_M.tecidoAcento.nome, -0.02, l + 0.02, comprimento - 0.48,
        comprimento - 0.16, 0.42, 0.58,
        chanfro: 0.03);
    // Travesseiros.
    final n = l > 1.1 ? 2 : 1;
    final tw = (l - 0.16 - (n - 1) * 0.06) / n;
    for (var i = 0; i < n; i++) {
      final u0 = 0.08 + i * (tw + 0.06);
      m.caixa(_M.roupaDeCama.nome, u0, u0 + tw, 0.12, 0.5, 0.52, 0.66,
          chanfro: 0.06);
    }
    if (n == 2) {
      // Almofada de cor na frente dos travesseiros.
      m.caixa(_M.tecidoAcento.nome, l / 2 - 0.22, l / 2 + 0.22, 0.48, 0.6, 0.52,
          0.8,
          chanfro: 0.05);
    }
  }

  /// Criado-mudo com abajur (0,45 x 0,40).
  static void criadoMudo(Moldura m) {
    m.caixa(_M.madeiraClara.nome, 0, 0.45, 0.02, 0.42, 0.12, 0.55,
        chanfro: 0.012);
    m.caixa(_M.metalPreto.nome, 0.03, 0.42, 0.03, 0.41, 0, 0.12);
    m.caixa(_M.metalPreto.nome, 0.18, 0.27, 0.418, 0.425, 0.4, 0.42);
    // Abajur: pé, haste e cúpula clara.
    m.cilindro(_M.metalPreto.nome, 0.24, 0.2, 0.55, 0.02, 0.07, lados: 14);
    m.cilindro(_M.metalPreto.nome, 0.24, 0.2, 0.57, 0.3, 0.008, lados: 6);
    m.cilindro(_M.roupaDeCama.nome, 0.24, 0.2, 0.8, 0.2, 0.14,
        raioTopo: 0.1, lados: 18);
  }

  /// Guarda-roupa de portas lisas até 2,20 m (0,60 de fundo).
  static void guardaRoupa(Moldura m, double largura) {
    const fundo = 0.6;
    m.caixa(_M.laca.nome, 0, largura, 0, fundo, 0.08, 2.2, chanfro: 0.008);
    m.caixa(_M.metalPreto.nome, 0.02, largura - 0.02, 0, fundo - 0.04, 0, 0.08);
    final portas = math.max(2, (largura / 0.5).round());
    final p = largura / portas;
    for (var i = 1; i < portas; i++) {
      // Junta entre as portas.
      m.caixa(_M.metalPreto.nome, i * p - 0.003, i * p + 0.003, fundo,
          fundo + 0.002, 0.1, 2.18);
    }
    for (var i = 0; i < portas; i++) {
      // Puxador vertical perto da junta.
      final u = i.isEven ? (i + 1) * p - 0.06 : i * p + 0.06;
      m.caixa(_M.metalPreto.nome, u - 0.008, u + 0.008, fundo, fundo + 0.025,
          0.9, 1.4,
          chanfro: 0.003);
    }
  }

  /// Escrivaninha com cadeira (1,10 x 0,55).
  static void escrivaninha(Moldura m) {
    m.caixa(_M.madeiraClara.nome, 0, 1.1, 0, 0.55, 0.72, 0.75, chanfro: 0.008);
    for (final u in [0.03, 1.07]) {
      m.caixa(_M.metalPreto.nome, u - 0.02, u + 0.02, 0.04, 0.51, 0, 0.72);
    }
    // Notebook fechado e luminária.
    m.caixa(_M.metalPreto.nome, 0.4, 0.72, 0.12, 0.34, 0.75, 0.77,
        chanfro: 0.004);
    m.cilindro(_M.metalPreto.nome, 0.95, 0.15, 0.75, 0.02, 0.06);
    m.cilindroEntre(
        _M.metalPreto.nome, (0.95, 0.15, 0.77), (0.88, 0.25, 1.15), 0.008,
        lados: 6);
    m.cilindro(_M.metalPreto.nome, 0.88, 0.28, 1.06, 0.1, 0.06,
        raioTopo: 0.03, lados: 12);
    cadeira(m.mover(du: 0.77, dv: 0.58, giro: math.pi), estofada: true);
  }

  // ------------------------------------------------------------ sala

  /// Sofá de [largura] encostado na parede (0,92 de fundo).
  static void sofa(Moldura m, double largura) {
    const fundo = 0.92, braco = 0.18;
    final t = _M.tecido.nome;
    // Base, encosto e braços.
    m.caixa(t, 0, largura, 0.02, fundo, 0.1, 0.4, chanfro: 0.03);
    m.caixa(t, 0, largura, 0.02, 0.24, 0.4, 0.82, chanfro: 0.04);
    m.caixa(t, 0, braco, 0.02, fundo, 0.4, 0.62, chanfro: 0.05);
    m.caixa(t, largura - braco, largura, 0.02, fundo, 0.4, 0.62, chanfro: 0.05);
    // Assentos e almofadas do encosto.
    final n = largura > 2.0 ? 3 : 2;
    final w = (largura - 2 * braco) / n;
    for (var i = 0; i < n; i++) {
      final u0 = braco + i * w;
      m.caixa(t, u0 + 0.008, u0 + w - 0.008, 0.24, fundo - 0.01, 0.4, 0.52,
          chanfro: 0.05);
      m.caixa(t, u0 + 0.01, u0 + w - 0.01, 0.22, 0.4, 0.5, 0.86, chanfro: 0.07);
    }
    // Almofadas de cor nas pontas.
    for (final u in [braco + 0.04, largura - braco - 0.46]) {
      m.caixa(_M.tecidoAcento.nome, u, u + 0.42, 0.34, 0.5, 0.52, 0.9,
          chanfro: 0.06);
    }
    for (final u in [0.08, largura - 0.08]) {
      for (final v in [0.12, fundo - 0.1]) {
        m.cilindro(_M.metalPreto.nome, u, v, 0, 0.1, 0.02,
            raioTopo: 0.025, lados: 8);
      }
    }
  }

  /// Poltrona (0,78 x 0,82).
  static void poltrona(Moldura m) {
    final t = _M.tecido.nome;
    m.caixa(t, 0, 0.78, 0, 0.82, 0.18, 0.42, chanfro: 0.03);
    m.caixa(t, 0, 0.78, 0, 0.2, 0.42, 0.85, chanfro: 0.04);
    m.caixa(t, 0, 0.13, 0, 0.82, 0.42, 0.6, chanfro: 0.04);
    m.caixa(t, 0.65, 0.78, 0, 0.82, 0.42, 0.6, chanfro: 0.04);
    m.caixa(t, 0.14, 0.64, 0.2, 0.8, 0.42, 0.52, chanfro: 0.05);
    for (final u in [0.06, 0.72]) {
      for (final v in [0.06, 0.76]) {
        m.cilindro(_M.madeiraClara.nome, u, v, 0, 0.18, 0.02, lados: 8);
      }
    }
  }

  /// Mesa de centro baixa com um livro e um vaso.
  static void mesaDeCentro(Moldura m, double largura, double fundo) {
    m.caixa(_M.madeiraClara.nome, 0, largura, 0, fundo, 0.34, 0.38,
        chanfro: 0.01);
    m.caixa(
        _M.metalPreto.nome, 0.04, largura - 0.04, 0.04, fundo - 0.04, 0, 0.04);
    for (final u in [0.06, largura - 0.06]) {
      m.caixa(_M.metalPreto.nome, u - 0.015, u + 0.015, 0.06, fundo - 0.06,
          0.04, 0.34);
    }
    m.caixa(_M.tecidoAcento.nome, largura * 0.2, largura * 0.2 + 0.24, 0.12,
        0.3, 0.38, 0.41,
        chanfro: 0.004);
    m.cilindro(_M.louca.nome, largura * 0.7, fundo / 2, 0.38, 0.16, 0.05,
        raioTopo: 0.035);
  }

  /// Rack baixo com a TV na parede (TV de 55").
  static void rackComTv(Moldura m, double largura) {
    m.caixa(_M.madeiraClara.nome, 0, largura, 0, 0.42, 0.18, 0.52,
        chanfro: 0.008);
    m.caixa(_M.metalPreto.nome, 0.05, largura - 0.05, 0.02, 0.38, 0, 0.18);
    final portas = math.max(2, (largura / 0.6).round());
    for (var i = 1; i < portas; i++) {
      final u = largura * i / portas;
      m.caixa(_M.metalPreto.nome, u - 0.002, u + 0.002, 0.42, 0.423, 0.2, 0.5);
    }
    final tv = math.min(1.24, largura - 0.2);
    final u0 = (largura - tv) / 2;
    m.caixa(_M.metalPreto.nome, u0, u0 + tv, 0.02, 0.06, 0.95, 0.95 + tv * 0.57,
        chanfro: 0.004);
    m.caixa(_M.tela.nome, u0 + 0.012, u0 + tv - 0.012, 0.06, 0.062, 0.962,
        0.95 + tv * 0.57 - 0.012);
    // Caixa de som e um vaso em cima do rack.
    m.caixa(_M.metalPreto.nome, largura / 2 - 0.4, largura / 2 + 0.4, 0.12, 0.3,
        0.52, 0.6,
        chanfro: 0.01);
    vasoComPlanta(m.mover(du: largura - 0.25, dv: 0.21, dh: 0.52), 0.25);
  }

  /// Mesa de jantar de [largura] x [fundo] (centrada na moldura) com
  /// cadeiras dos dois lados compridos.
  static void mesaDeJantar(Moldura m, double largura, double fundo) {
    m.caixa(_M.madeiraClara.nome, 0, largura, 0, fundo, 0.72, 0.76,
        chanfro: 0.008);
    for (final u in [0.08, largura - 0.08]) {
      for (final v in [0.08, fundo - 0.08]) {
        m.caixa(_M.madeiraClara.nome, u - 0.025, u + 0.025, v - 0.025,
            v + 0.025, 0, 0.72);
      }
    }
    final n = largura >= 1.5 ? 3 : 2;
    for (var i = 0; i < n; i++) {
      final u = largura * (i + 0.5) / n;
      cadeira(m.mover(du: u - 0.22, dv: -0.18));
      cadeira(m.mover(du: u + 0.22, dv: fundo + 0.18, giro: math.pi));
    }
    vasoComPlanta(m.mover(du: largura / 2, dv: fundo / 2, dh: 0.76), 0.2);
  }

  /// Cadeira (0,44 x 0,46) olhando para +v, com o encosto em v = -0,46.
  static void cadeira(Moldura m, {bool estofada = false}) {
    final assento = estofada ? _M.tecido.nome : _M.madeiraClara.nome;
    m.caixa(assento, 0, 0.44, -0.46, -0.02, 0.43, 0.48, chanfro: 0.012);
    m.caixa(assento, 0.02, 0.42, -0.46, -0.42, 0.48, 0.86, chanfro: 0.012);
    for (final u in [0.03, 0.41]) {
      for (final v in [-0.43, -0.05]) {
        m.cilindro(_M.metalPreto.nome, u, v, 0, 0.43, 0.012, lados: 6);
      }
    }
  }

  /// Aparador do hall com espelho redondo e um vaso.
  static void aparador(Moldura m, double largura) {
    m.caixa(_M.madeiraClara.nome, 0, largura, 0, 0.36, 0.78, 0.82,
        chanfro: 0.006);
    for (final u in [0.04, largura - 0.04]) {
      m.caixa(_M.metalPreto.nome, u - 0.015, u + 0.015, 0.03, 0.33, 0, 0.78);
    }
    m.cilindroEntre(_M.metalPreto.nome, (largura / 2, 0.0, 1.45),
        (largura / 2, 0.02, 1.45), 0.36,
        lados: 28);
    m.cilindroEntre(_M.espelho.nome, (largura / 2, 0.02, 1.45),
        (largura / 2, 0.024, 1.45), 0.34,
        lados: 28);
    vasoComPlanta(m.mover(du: largura * 0.75, dv: 0.18, dh: 0.82), 0.3);
  }

  /// Quadro na parede (moldura, passe-partout e uma gravura abstrata).
  static void quadro(Moldura m, double largura, double altura, double h0) {
    m.caixa(_M.metalPreto.nome, 0, largura, 0, 0.03, h0, h0 + altura,
        chanfro: 0.004);
    m.caixa(_M.roupaDeCama.nome, 0.025, largura - 0.025, 0.03, 0.031,
        h0 + 0.025, h0 + altura - 0.025);
    final b = math.min(largura, altura) * 0.12;
    final u0 = b, u1 = largura - b, a0 = h0 + b, a1 = h0 + altura - b;
    final w = u1 - u0, h = a1 - a0;
    m.caixa(_M.quadro.nome, u0, u1, 0.031, 0.032, a0, a1);
    // Formas soltas: um bloco terracota, um verde e o sol.
    m.caixa(_M.tecidoAcento.nome, u0 + w * 0.08, u0 + w * 0.5, 0.032, 0.033,
        a0 + h * 0.1, a0 + h * 0.62);
    m.caixa(_M.folhagem.nome, u0 + w * 0.42, u0 + w * 0.9, 0.0325, 0.0335,
        a0 + h * 0.08, a0 + h * 0.4);
    m.cilindroEntre(_M.roupaDeCama.nome, (u0 + w * 0.72, 0.032, a0 + h * 0.7),
        (u0 + w * 0.72, 0.034, a0 + h * 0.7), h * 0.16,
        lados: 20);
  }

  // ------------------------------------------------------------ cozinha

  /// Bancada com armários embaixo, tampo de granito, cuba e cooktop. [pia]
  /// e [fogao] são o meio de cada um em u (nulos: sem).
  static void bancada(Moldura m, double largura,
      {double? pia,
      double? fogao,
      bool aereos = true,
      double? semAereoDe,
      double? semAereoAte}) {
    // Rodapé recuado, armários e o tampo saindo 3 cm.
    m.caixa(_M.metalPreto.nome, 0, largura, 0, 0.52, 0, 0.1);
    m.caixa(_M.laca.nome, 0, largura, 0, 0.58, 0.1, 0.88, chanfro: 0.004);
    m.caixa(_M.granito.nome, 0, largura, 0, 0.62, 0.88, 0.91, chanfro: 0.004);
    final portas = math.max(1, (largura / 0.45).round());
    final p = largura / portas;
    for (var i = 0; i < portas; i++) {
      if (i > 0) {
        m.caixa(_M.metalPreto.nome, i * p - 0.002, i * p + 0.002, 0.58, 0.582,
            0.12, 0.86);
      }
      m.caixa(
          _M.inox.nome, i * p + 0.05, (i + 1) * p - 0.05, 0.58, 0.6, 0.8, 0.815,
          chanfro: 0.003);
    }
    // Revestimento entre a bancada e os armários de cima.
    m.caixa(_M.azulejo.nome, 0, largura, 0, 0.006, 0.91, 1.5);
    if (pia != null) {
      // Cuba de inox embutida e a torneira gourmet.
      m.caixa(_M.inox.nome, pia - 0.3, pia + 0.3, 0.12, 0.5, 0.91, 0.912);
      m.caixa(
          _M.metalPreto.nome, pia - 0.27, pia + 0.27, 0.15, 0.47, 0.912, 0.913);
      m.cilindro(_M.inox.nome, pia, 0.07, 0.91, 0.32, 0.018, lados: 10);
      m.cilindroEntre(_M.inox.nome, (pia, 0.07, 1.23), (pia, 0.3, 1.16), 0.014,
          lados: 8);
    }
    if (fogao != null) {
      m.caixa(_M.tela.nome, fogao - 0.3, fogao + 0.3, 0.08, 0.56, 0.91, 0.915,
          chanfro: 0.003);
      for (final (du, dv, r) in [
        (-0.14, 0.2, 0.08),
        (0.14, 0.2, 0.06),
        (-0.14, 0.42, 0.06),
        (0.14, 0.42, 0.08),
      ]) {
        m.cilindro(_M.inox.nome, fogao + du, dv, 0.915, 0.006, r, lados: 18);
        m.cilindro(_M.metalPreto.nome, fogao + du, dv, 0.92, 0.012, r * 0.55,
            lados: 12);
      }
    }
    if (!aereos) return;
    // Armários de cima (fora da janela).
    final trechos = <(double, double)>[];
    if (semAereoDe != null && semAereoAte != null) {
      if (semAereoDe > 0.3) trechos.add((0, semAereoDe));
      if (largura - semAereoAte > 0.3) trechos.add((semAereoAte, largura));
    } else {
      trechos.add((0, largura));
    }
    for (final (a, b) in trechos) {
      m.caixa(_M.laca.nome, a, b, 0, 0.35, 1.55, 2.2, chanfro: 0.004);
      final n = math.max(1, ((b - a) / 0.45).round());
      for (var i = 1; i < n; i++) {
        final u = a + (b - a) * i / n;
        m.caixa(
            _M.metalPreto.nome, u - 0.002, u + 0.002, 0.35, 0.352, 1.57, 2.18);
      }
      // Fita de LED embaixo dos armários.
      m.caixa(_M.lampada.nome, a + 0.02, b - 0.02, 0.28, 0.31, 1.545, 1.55);
    }
  }

  /// Geladeira de inox (0,70 x 0,72 x 1,85).
  static void geladeira(Moldura m) {
    m.caixa(_M.inox.nome, 0, 0.7, 0.02, 0.74, 0, 1.85, chanfro: 0.02);
    m.caixa(_M.metalPreto.nome, 0.01, 0.69, 0.74, 0.742, 1.18, 1.185);
    for (final (h0, h1) in [(0.5, 1.1), (1.3, 1.7)]) {
      m.caixa(_M.metalPreto.nome, 0.6, 0.62, 0.74, 0.77, h0, h1,
          chanfro: 0.004);
    }
  }

  // ------------------------------------------------------------ banheiro

  /// Vaso sanitário com caixa acoplada, encostado na parede.
  static void vasoSanitario(Moldura m) {
    final l = _M.louca.nome;
    m.caixa(l, 0.03, 0.39, 0, 0.18, 0.38, 0.78, chanfro: 0.03);
    m.cilindro(l, 0.21, 0.4, 0, 0.38, 0.16, raioTopo: 0.19, lados: 22);
    m.esfera(l, 0.21, 0.44, 0.4, 0.2, escalaH: 0.12, anel: 22, fatias: 6);
    m.caixa(_M.inox.nome, 0.17, 0.25, 0.12, 0.17, 0.78, 0.79, chanfro: 0.003);
  }

  /// Gabinete suspenso com cuba de apoio e espelho (largura 0,60 a 1,0).
  static void pia(Moldura m, double largura) {
    m.caixa(_M.madeiraClara.nome, 0, largura, 0, 0.46, 0.35, 0.8,
        chanfro: 0.006);
    m.caixa(_M.granito.nome, 0, largura, 0, 0.5, 0.8, 0.83, chanfro: 0.004);
    m.esfera(_M.louca.nome, largura / 2, 0.27, 0.83, 0.2,
        escalaH: 0.38, anel: 22, fatias: 8);
    m.cilindro(_M.inox.nome, largura / 2, 0.06, 0.83, 0.22, 0.014, lados: 10);
    m.cilindroEntre(_M.inox.nome, (largura / 2, 0.06, 1.05),
        (largura / 2, 0.18, 1.04), 0.012,
        lados: 8);
    // Espelho com a luz de cima.
    m.caixa(_M.espelho.nome, 0.02, largura - 0.02, 0, 0.012, 1.0, 1.85);
    m.caixa(_M.lampada.nome, 0.06, largura - 0.06, 0.012, 0.03, 1.88, 1.9);
  }

  /// Box de vidro com chuveiro e ralo, ocupando [largura] x [fundo] no
  /// canto (o vidro corre em v = fundo e, do lado aberto, em u = [lateral]).
  static void box(Moldura m, double largura, double fundo, {double? lateral}) {
    m.caixa(_M.vidro.nome, 0, largura, fundo - 0.01, fundo, 0.02, 1.95);
    if (lateral != null) {
      m.caixa(_M.vidro.nome, lateral - 0.005, lateral + 0.005, 0, fundo, 0.02,
          1.95);
      m.caixa(
          _M.inox.nome, lateral - 0.012, lateral + 0.012, 0, fundo, 1.95, 1.98);
    }
    m.caixa(_M.inox.nome, 0, largura, fundo - 0.02, fundo + 0.01, 1.95, 1.98);
    m.caixa(_M.granito.nome, 0, largura, fundo - 0.04, fundo + 0.02, 0, 0.02);
    m.caixa(_M.metalPreto.nome, largura / 2 - 0.05, largura / 2 + 0.05,
        fundo / 2 - 0.05, fundo / 2 + 0.05, 0, 0.004);
    m.cilindroEntre(
        _M.inox.nome, (largura / 2, 0.0, 2.15), (largura / 2, 0.3, 2.15), 0.012,
        lados: 8);
    m.cilindro(_M.inox.nome, largura / 2, 0.32, 2.12, 0.03, 0.11, lados: 20);
    m.caixa(_M.inox.nome, largura / 2 - 0.04, largura / 2 + 0.04, 0, 0.04, 1.1,
        1.18,
        chanfro: 0.008);
  }

  // ------------------------------------------------------------ serviço

  /// Tanque e máquina de lavar lado a lado (1,25 de largura).
  static void lavanderia(Moldura m) {
    // Máquina de lavar.
    m.caixa(_M.laca.nome, 0, 0.6, 0.02, 0.64, 0, 0.88, chanfro: 0.02);
    m.caixa(_M.metalPreto.nome, 0.04, 0.56, 0.05, 0.16, 0.88, 0.885);
    m.cilindroEntre(
        _M.metalPreto.nome, (0.3, 0.64, 0.5), (0.3, 0.655, 0.5), 0.2,
        lados: 26);
    m.cilindroEntre(
        _M.vidroEscuro.nome, (0.3, 0.655, 0.5), (0.3, 0.66, 0.5), 0.15,
        lados: 26);
    // Tanque de louça sobre coluna.
    m.caixa(_M.louca.nome, 0.66, 1.24, 0.02, 0.56, 0.62, 0.86, chanfro: 0.03);
    m.caixa(_M.louca.nome, 0.86, 1.04, 0.1, 0.4, 0, 0.62, chanfro: 0.02);
    m.cilindro(_M.inox.nome, 0.95, 0.07, 0.86, 0.2, 0.014, lados: 8);
    // Prateleira com produtos.
    m.caixa(_M.madeiraClara.nome, 0, 1.24, 0, 0.28, 1.55, 1.58, chanfro: 0.004);
    for (var i = 0; i < 4; i++) {
      m.cilindro(i.isEven ? _M.louca.nome : _M.tecidoAcento.nome,
          0.15 + i * 0.12, 0.14, 1.58, 0.2, 0.04,
          lados: 10);
    }
  }

  /// Estante do closet: montantes, prateleiras e o cabideiro com roupas.
  static void closet(Moldura m, double largura) {
    const fundo = 0.55;
    final n = math.max(1, (largura / 0.8).round());
    final w = largura / n;
    for (var i = 0; i <= n; i++) {
      final u = (i * w).clamp(0.01, largura - 0.01);
      m.caixa(_M.laca.nome, u - 0.01, u + 0.01, 0, fundo, 0, 2.3);
    }
    for (final h in [0.0, 0.3, 1.85, 2.28]) {
      m.caixa(_M.laca.nome, 0, largura, 0, fundo, h, h + 0.02);
    }
    for (var i = 0; i < n; i++) {
      final u0 = i * w + 0.03, u1 = (i + 1) * w - 0.03;
      m.cilindroEntre(
          _M.inox.nome, (u0, fundo / 2, 1.75), (u1, fundo / 2, 1.75), 0.01,
          lados: 6, tampas: false);
      // Roupas penduradas: placas finas de cores alternadas.
      for (var u = u0 + 0.04; u < u1 - 0.03; u += 0.07) {
        final cor = ((u * 100).round() % 3) == 0
            ? _M.tecidoAcento.nome
            : _M.tecido.nome;
        m.caixa(cor, u, u + 0.035, fundo / 2 - 0.2, fundo / 2 + 0.2, 1.0, 1.72,
            chanfro: 0.01);
      }
    }
  }

  // ------------------------------------------------------------ plantas

  /// Vaso com uma planta de [altura] (folhas em bolas), centro em (0, 0).
  static void vasoComPlanta(Moldura m, double altura) {
    final r = math.max(0.06, altura * 0.18);
    m.cilindro(_M.vaso.nome, 0, 0, 0, altura * 0.32, r * 0.75,
        raioTopo: r, lados: 16);
    m.cilindro(_M.tronco.nome, 0, 0, altura * 0.3, 0.012, r * 0.9, lados: 12);
    final copa = altura * 0.68;
    for (final (du, dv, dh, s) in [
      (0.0, 0.0, 0.55, 0.42),
      (-0.3, 0.15, 0.4, 0.3),
      (0.28, -0.12, 0.38, 0.32),
      (0.1, 0.3, 0.3, 0.26),
    ]) {
      m.esfera(s > 0.35 ? _M.folhagem.nome : _M.folhagemClara.nome,
          du * copa * 0.6, dv * copa * 0.6, altura * 0.3 + dh * copa, s * copa,
          anel: 8, fatias: 5, liso: false);
    }
  }

  /// Árvore de [altura] com a copa em bolas facetadas (estilo de maquete),
  /// tronco no ponto (0, 0). [semente] varia a copa.
  static void arvore(Moldura m, double altura, int semente) {
    var s = semente * 7919 + 13;
    double sorteio() {
      s = (s * 1103515245 + 12345) & 0x7fffffff;
      return s / 0x7fffffff;
    }

    final tronco = altura * 0.42;
    m.cilindro(_M.tronco.nome, 0, 0, 0, tronco + altura * 0.15, 0.06,
        raioTopo: 0.035, lados: 9);
    final raio = altura * 0.24;
    // Galhos curtos que somem na copa.
    for (var i = 0; i < 3; i++) {
      final a = 2 * math.pi * (i / 3 + sorteio() * 0.2);
      m.cilindroEntre(
          _M.tronco.nome,
          (0, 0, tronco * 0.9),
          (
            math.cos(a) * raio * 0.6,
            math.sin(a) * raio * 0.6,
            tronco + raio * 0.6
          ),
          0.025,
          raioFim: 0.012,
          lados: 6);
    }
    final bolas = 6;
    for (var i = 0; i < bolas; i++) {
      final a = 2 * math.pi * (i / bolas + sorteio() * 0.15);
      final d = i == 0 ? 0.0 : raio * (0.45 + sorteio() * 0.25);
      final h = tronco + raio * (0.8 + sorteio() * 0.7);
      final r = raio * (i == 0 ? 0.95 : 0.6 + sorteio() * 0.25);
      m.esfera(i.isEven ? _M.folhagem.nome : _M.folhagemClara.nome,
          math.cos(a) * d, math.sin(a) * d, h, r,
          escalaH: 0.85, anel: 9, fatias: 6, liso: false);
    }
  }

  /// Arbusto baixo (de 0,4 a 0,9 m), centro em (0, 0).
  static void arbusto(Moldura m, double raio, int semente) {
    var s = semente * 104729 + 7;
    double sorteio() {
      s = (s * 1103515245 + 12345) & 0x7fffffff;
      return s / 0x7fffffff;
    }

    for (var i = 0; i < 3; i++) {
      final a = 2 * math.pi * (i / 3 + sorteio() * 0.2);
      final d = i == 0 ? 0.0 : raio * 0.45;
      m.esfera(
          i.isEven ? _M.folhagem.nome : _M.folhagemClara.nome,
          math.cos(a) * d,
          math.sin(a) * d,
          raio * 0.65,
          raio * (0.75 - i * 0.1),
          escalaH: 0.8,
          anel: 8,
          fatias: 5,
          liso: false);
    }
  }

  // ------------------------------------------------------------ carro

  /// Carro de passeio (4,30 x 1,78) com a frente em u = 0 e o meio da
  /// largura em v = 0.
  static void carro(Moldura m) {
    const w = 1.78;
    final p = _M.pinturaCarro.nome;
    // Corpo: o perfil lateral puxado na largura (para-choques arredondados
    // pelo chanfro dos cantos do polígono).
    m.perfil(
        p,
        const [
          (0.0, 0.32),
          (0.06, 0.56),
          (0.35, 0.72),
          (1.25, 0.8),
          (3.4, 0.82),
          (4.18, 0.78),
          (4.3, 0.62),
          (4.27, 0.32),
          (3.9, 0.22),
          (0.35, 0.22),
        ],
        -w / 2,
        w / 2);
    // Cabine com os vidros.
    m.perfil(
        _M.vidroEscuro.nome,
        const [
          (1.3, 0.8),
          (1.95, 1.26),
          (3.15, 1.3),
          (3.75, 0.84),
        ],
        -w / 2 + 0.11,
        w / 2 - 0.11);
    m.perfil(
        p,
        const [
          (2.0, 1.27),
          (2.05, 1.32),
          (3.1, 1.34),
          (3.15, 1.29),
        ],
        -w / 2 + 0.12,
        w / 2 - 0.12);
    // Colunas do meio.
    for (final v in [-w / 2 + 0.105, w / 2 - 0.105]) {
      m.caixa(p, 2.6, 2.7, v - 0.01, v + 0.01, 0.8, 1.29);
    }
    // Rodas.
    for (final u in [0.82, 3.5]) {
      for (final s in [-1.0, 1.0]) {
        final v0 = s * (w / 2 - 0.22), v1 = s * (w / 2 + 0.005);
        m.cilindroEntre(_M.pneu.nome, (u, v0, 0.31), (u, v1, 0.31), 0.31,
            lados: 22);
        m.cilindroEntre(
            _M.inox.nome, (u, v1, 0.31), (u, v1 + s * 0.006, 0.31), 0.19,
            lados: 22);
      }
    }
    // Faróis e lanternas.
    for (final v in [-w / 2 + 0.2, w / 2 - 0.42]) {
      m.caixa(_M.lampada.nome, 0.03, 0.12, v, v + 0.22, 0.58, 0.65);
      m.caixa(_M.lanterna.nome, 4.2, 4.29, v, v + 0.22, 0.62, 0.7);
    }
    // Retrovisores.
    for (final s in [-1.0, 1.0]) {
      m.caixa(p, 1.45, 1.6, s * (w / 2), s * (w / 2 + 0.12), 0.88, 0.98,
          chanfro: 0.02);
    }
  }
}
