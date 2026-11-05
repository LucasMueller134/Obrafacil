// A área coberta da planta (os cômodos com laje, juntos) numa grade fina:
// dela saem a laje e o radier sem sobreposição (faces coplanares
// sobrepostas piscam na GPU), o contorno da platibanda e o telhado recuado.

import 'dart:math' as math;

import '../../../models/planta_obra.dart';

/// Uma borda da área coberta: o segmento (em coordenadas da planta) e o
/// lado de dentro (unitário, perpendicular a ele).
typedef BordaCoberta = ({
  (double, double) de,
  (double, double) ate,
  (double, double) paraDentro,
});

/// Retângulo da planta: (x0, y0, x1, y1).
typedef Ret = (double, double, double, double);

class AreaCoberta {
  AreaCoberta._(this.x0, this.y0, this.passo, this.nx, this.ny, this._c);

  /// Junta os [retangulos], cada um crescido [expandir] m para todos os
  /// lados, numa grade de [passo] m que cobre o terreno com [margem].
  factory AreaCoberta.dos(
    Iterable<RetanguloPlanta> retangulos, {
    required double largura,
    required double profundidade,
    double expandir = 0,
    double passo = 0.025,
    double margem = 0.6,
  }) {
    final x0 = -margem, y0 = -margem;
    final nx = ((largura + 2 * margem) / passo).ceil();
    final ny = ((profundidade + 2 * margem) / passo).ceil();
    final c = List<bool>.filled(nx * ny, false);
    for (final r in retangulos) {
      final i0 = ((r.x - expandir - x0) / passo).round().clamp(0, nx);
      final i1 = ((r.x1 + expandir - x0) / passo).round().clamp(0, nx);
      final j0 = ((r.y - expandir - y0) / passo).round().clamp(0, ny);
      final j1 = ((r.y1 + expandir - y0) / passo).round().clamp(0, ny);
      for (var j = j0; j < j1; j++) {
        for (var i = i0; i < i1; i++) {
          c[j * nx + i] = true;
        }
      }
    }
    return AreaCoberta._(x0, y0, passo, nx, ny, c);
  }

  final double x0;
  final double y0;
  final double passo;
  final int nx;
  final int ny;
  final List<bool> _c;

  bool get vazia => !_c.contains(true);

  bool _em(int i, int j) =>
      i >= 0 && j >= 0 && i < nx && j < ny && _c[j * nx + i];

  /// O ponto (x, y) da planta está dentro.
  bool contem(double x, double y) =>
      _em(((x - x0) / passo).floor(), ((y - y0) / passo).floor());

  /// A mesma área recuada [distancia] m de todas as bordas (o telhado fica
  /// dentro da platibanda).
  AreaCoberta recuada(double distancia) {
    final k = (distancia / passo).round();
    if (k <= 0) return this;
    // Mínimo em linha, depois em coluna (o quadrado de lado 2k + 1).
    final linhas = List<bool>.filled(nx * ny, false);
    for (var j = 0; j < ny; j++) {
      var seguidos = 0;
      final dentro = List<int>.filled(nx, 0);
      for (var i = 0; i < nx; i++) {
        seguidos = _c[j * nx + i] ? seguidos + 1 : 0;
        dentro[i] = seguidos;
      }
      for (var i = 0; i < nx; i++) {
        final fim = i + k;
        if (i - k < 0 || fim >= nx) continue;
        linhas[j * nx + i] = dentro[fim] >= 2 * k + 1;
      }
    }
    final saida = List<bool>.filled(nx * ny, false);
    for (var i = 0; i < nx; i++) {
      var seguidos = 0;
      final dentro = List<int>.filled(ny, 0);
      for (var j = 0; j < ny; j++) {
        seguidos = linhas[j * nx + i] ? seguidos + 1 : 0;
        dentro[j] = seguidos;
      }
      for (var j = 0; j < ny; j++) {
        final fim = j + k;
        if (j - k < 0 || fim >= ny) continue;
        saida[j * nx + i] = dentro[fim] >= 2 * k + 1;
      }
    }
    return AreaCoberta._(x0, y0, passo, nx, ny, saida);
  }

  /// A área em retângulos que não se sobrepõem (malha gulosa: corre a
  /// linha, depois desce enquanto as linhas de baixo são iguais).
  List<Ret> retangulos() {
    final usado = List<bool>.filled(nx * ny, false);
    final saida = <Ret>[];
    for (var j = 0; j < ny; j++) {
      var i = 0;
      while (i < nx) {
        if (!_c[j * nx + i] || usado[j * nx + i]) {
          i++;
          continue;
        }
        var i1 = i;
        while (i1 < nx && _c[j * nx + i1] && !usado[j * nx + i1]) {
          i1++;
        }
        var j1 = j + 1;
        bool linhaCheia(int jj) {
          for (var ii = i; ii < i1; ii++) {
            if (!_c[jj * nx + ii] || usado[jj * nx + ii]) return false;
          }
          return true;
        }

        while (j1 < ny && linhaCheia(j1)) {
          j1++;
        }
        for (var jj = j; jj < j1; jj++) {
          for (var ii = i; ii < i1; ii++) {
            usado[jj * nx + ii] = true;
          }
        }
        saida.add((
          x0 + i * passo,
          y0 + j * passo,
          x0 + i1 * passo,
          y0 + j1 * passo,
        ));
        i = i1;
      }
    }
    return saida;
  }

  /// As bordas da área, em trechos retos e contínuos.
  List<BordaCoberta> bordas() {
    final saida = <BordaCoberta>[];
    // Bordas horizontais: entre a linha j - 1 e a j.
    for (var j = 0; j <= ny; j++) {
      int? inicio;
      var lado = 0; // +1: dentro em j (acima); -1: dentro em j - 1
      void fechar(int fim) {
        if (inicio == null) return;
        final y = y0 + j * passo;
        saida.add((
          de: (x0 + inicio! * passo, y),
          ate: (x0 + fim * passo, y),
          paraDentro: (0.0, lado.toDouble()),
        ));
        inicio = null;
      }

      for (var i = 0; i < nx; i++) {
        final cima = _em(i, j), baixo = _em(i, j - 1);
        final l = cima == baixo ? 0 : (cima ? 1 : -1);
        if (l != lado) {
          fechar(i);
          lado = l;
          if (l != 0) inicio = i;
        }
      }
      fechar(nx);
    }
    // Bordas verticais: entre a coluna i - 1 e a i.
    for (var i = 0; i <= nx; i++) {
      int? inicio;
      var lado = 0;
      void fechar(int fim) {
        if (inicio == null) return;
        final x = x0 + i * passo;
        saida.add((
          de: (x, y0 + inicio! * passo),
          ate: (x, y0 + fim * passo),
          paraDentro: (lado.toDouble(), 0.0),
        ));
        inicio = null;
      }

      for (var j = 0; j < ny; j++) {
        final direita = _em(i, j), esquerda = _em(i - 1, j);
        final l = direita == esquerda ? 0 : (direita ? 1 : -1);
        if (l != lado) {
          fechar(j);
          lado = l;
          if (l != 0) inicio = j;
        }
      }
      fechar(ny);
    }
    return saida;
  }

  /// Menor e maior y com área (a frente e o fundo da laje).
  (double, double)? extensaoEmY() {
    double? a, b;
    for (var j = 0; j < ny; j++) {
      for (var i = 0; i < nx; i++) {
        if (!_c[j * nx + i]) continue;
        final y = y0 + j * passo;
        a = a == null ? y : math.min(a, y);
        b = b == null ? y + passo : math.max(b, y + passo);
      }
    }
    return a == null ? null : (a, b!);
  }
}
